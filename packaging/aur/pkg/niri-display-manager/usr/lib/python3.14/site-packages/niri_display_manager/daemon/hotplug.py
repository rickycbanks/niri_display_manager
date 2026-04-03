"""
Hotplug daemon for Niri Display Manager.

Watches for DRM connector events via udev, then checks whether a saved profile
matches the newly connected set of monitors. If a match is found, applies the
profile automatically via Niri IPC and KDL config write.

Run as: niri-display-manager --daemon
"""

from __future__ import annotations

import logging
import signal
import sys
import time
from pathlib import Path
from typing import Optional

try:
    import pyudev
    UDEV_AVAILABLE = True
except ImportError:
    UDEV_AVAILABLE = False

from niri_display_manager.ipc.niri_socket import (
    get_outputs,
    set_output_off,
    set_output_on,
    set_output_mode,
    set_output_scale,
    set_output_transform,
    set_output_position,
    set_output_vrr,
    reload_config,
    NiriSocketError,
)
from niri_display_manager.config.kdl_finder import find_output_file
from niri_display_manager.config.kdl_parser import KdlOutputFile, KdlOutputBlock
from niri_display_manager.config import profile_manager as pm

log = logging.getLogger("ndm.daemon")


# How long to wait after a hotplug event before querying Niri
# (give the compositor time to enumerate the new output)
_SETTLE_SECONDS = 2.0

# Polling interval used as fallback when udev is unavailable
_POLL_SECONDS = 5.0


def run_daemon(poll: bool = False) -> None:
    """
    Start the hotplug daemon.

    If pyudev is available and poll=False, uses udev for event-driven detection.
    Otherwise falls back to polling Niri's output list every POLL_SECONDS.
    """
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [ndm-daemon] %(levelname)s %(message)s",
    )

    log.info("Niri Display Manager daemon starting")

    _install_signal_handlers()

    if UDEV_AVAILABLE and not poll:
        _run_udev_loop()
    else:
        if not UDEV_AVAILABLE:
            log.warning("pyudev not available — falling back to polling every %.0fs", _POLL_SECONDS)
        _run_poll_loop()


def _install_signal_handlers() -> None:
    def _handle(sig, _frame):
        log.info("Received signal %s, exiting", sig)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _handle)
    signal.signal(signal.SIGINT, _handle)


def _run_udev_loop() -> None:
    """Event-driven loop using pyudev."""
    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by("drm")

    log.info("Watching udev DRM events")

    # Track last known output set for change detection
    last_names: frozenset[str] = frozenset()

    with pyudev.MonitorObserver(monitor, _make_udev_callback(last_names)) as observer:
        # Also do an initial check at startup
        _check_and_apply(last_names)
        while True:
            time.sleep(60)  # Observer runs on its own thread; main thread just idles


def _make_udev_callback(last_names_ref: frozenset):
    def _on_event(device: "pyudev.Device") -> None:
        if device.action not in ("change", "add", "remove"):
            return
        log.debug("udev event: %s %s", device.action, device.sys_path)
        # Settle then check
        time.sleep(_SETTLE_SECONDS)
        _check_and_apply(last_names_ref)

    return _on_event


def _run_poll_loop() -> None:
    """Polling fallback loop."""
    log.info("Polling Niri outputs every %.0fs", _POLL_SECONDS)
    last_names: frozenset[str] = frozenset()

    while True:
        last_names = _check_and_apply(last_names)
        time.sleep(_POLL_SECONDS)


def _check_and_apply(last_names: frozenset) -> frozenset:
    """
    Query current outputs; if the connected set changed, look for a matching profile
    and apply it. Returns the current set of output names.
    """
    try:
        outputs = get_outputs()
    except NiriSocketError as e:
        log.warning("Could not query Niri outputs: %s", e)
        return last_names

    current_names = frozenset(name for name, out in outputs.items() if out.enabled is not False)

    if current_names == last_names:
        return current_names

    log.info("Output set changed: %s", sorted(current_names))

    profile_name = pm.find_auto_profile(list(current_names))
    if profile_name:
        log.info("Auto-applying profile '%s'", profile_name)
        _apply_profile(profile_name, outputs)
    else:
        log.debug("No matching profile for this output set")

    return current_names


def _apply_profile(profile_name: str, live_outputs) -> None:
    """Apply a named profile to the current display configuration."""
    try:
        profile = pm.load_profile(profile_name)
    except FileNotFoundError:
        log.error("Profile '%s' not found", profile_name)
        return

    # Build a fake staged dict from the live outputs so we can use apply_profile_to_staged
    staged = {}
    for name, out in live_outputs.items():
        logical = out.logical
        mode = out.current_output_mode
        staged[name] = {
            "name": name,
            "enabled": out.enabled,
            "modes": [
                {
                    "width": m.width,
                    "height": m.height,
                    "refresh_hz": m.refresh_hz,
                }
                for m in out.modes
            ],
            "current_mode": out.current_mode,
            "scale": logical.scale if logical else 1.0,
            "transform": logical.transform if logical else "Normal",
            "pos_x": logical.x if logical else 0,
            "pos_y": logical.y if logical else 0,
            "vrr_enabled": out.vrr_enabled,
            "vrr_supported": out.vrr_supported,
            "display_type": "extend",
        }

    merged = pm.apply_profile_to_staged(profile, staged)

    # Apply via IPC
    try:
        _staged_to_ipc(merged, live_outputs)
    except NiriSocketError as e:
        log.error("IPC apply failed: %s", e)
        return

    # Write to KDL config
    try:
        output_file = find_output_file()
        kdl = KdlOutputFile(output_file)
        for name, s in merged.items():
            mode_idx = s.get("current_mode")
            modes = s.get("modes", [])
            mode_str: Optional[str] = None
            if mode_idx is not None and mode_idx < len(modes):
                m = modes[mode_idx]
                mode_str = f"{m['width']}x{m['height']}@{m['refresh_hz']:.3f}"

            block = KdlOutputBlock(
                name=name,
                enabled=s.get("enabled", True),
                mode=mode_str,
                scale=s.get("scale"),
                position_x=s.get("pos_x"),
                position_y=s.get("pos_y"),
                transform=s.get("transform"),
                vrr=s.get("vrr_enabled") if s.get("vrr_supported") else None,
            )
            kdl.upsert(block)
        kdl.write()
        reload_config()
        log.info("Profile '%s' applied and saved to config", profile_name)
    except Exception as e:
        log.error("KDL write failed: %s", e)


def _staged_to_ipc(staged: dict, live_outputs) -> None:
    for name, s in staged.items():
        if not s.get("enabled", True):
            set_output_off(name)
            continue

        live = live_outputs.get(name)
        if live and not live.enabled:
            set_output_on(name)

        mode_idx = s.get("current_mode")
        modes = s.get("modes", [])
        if mode_idx is not None and mode_idx < len(modes):
            m = modes[mode_idx]
            set_output_mode(name, m["width"], m["height"], m["refresh_hz"])

        set_output_scale(name, s.get("scale", 1.0))
        set_output_transform(name, s.get("transform", "Normal"))
        set_output_position(name, s.get("pos_x", 0), s.get("pos_y", 0))

        if s.get("vrr_supported", False):
            set_output_vrr(name, s.get("vrr_enabled", False))
