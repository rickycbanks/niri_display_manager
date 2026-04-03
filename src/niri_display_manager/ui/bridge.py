"""
QML ↔ Python bridge.

Exposes the display manager state to QML via a QObject with properties and slots.
All mutations are staged — nothing writes to disk or Niri IPC until applyChanges() is called.
"""

from __future__ import annotations

import json
import copy
from dataclasses import asdict
from typing import Optional

from PySide6.QtCore import (
    QObject,
    Qt,
    Signal,
    Slot,
    Property,
    QTimer,
)
from PySide6.QtQml import QmlElement

from niri_display_manager.ipc.niri_socket import (
    Output,
    get_outputs,
    set_output_off,
    set_output_on,
    set_output_mode,
    set_output_mode_auto,
    set_output_scale,
    set_output_transform,
    set_output_position,
    set_output_position_auto,
    set_output_vrr,
    reload_config,
    NiriSocketError,
    TRANSFORMS,
    TRANSFORM_LABELS,
)
from niri_display_manager.config.kdl_finder import find_output_file
from niri_display_manager.config.kdl_parser import KdlOutputFile, KdlOutputBlock


QML_IMPORT_NAME = "NiriDisplayManager"
QML_IMPORT_MAJOR_VERSION = 1


@QmlElement
class DisplayBridge(QObject):
    """
    Main bridge object registered as a QML singleton.

    Properties read by QML:
      - outputs (list[dict])  — current staged output data
      - hasChanges (bool)     — whether there are staged changes
      - errorMessage (str)    — last error, empty if none
      - previewActive (bool)  — whether preview mode is counting down
      - previewSecondsLeft (int)

    Signals:
      - outputsChanged
      - hasChangesChanged
      - errorMessageChanged
      - previewActiveChanged
      - previewSecondsLeftChanged
    """

    outputsChanged = Signal()
    hasChangesChanged = Signal()
    errorMessageChanged = Signal()
    previewActiveChanged = Signal()
    previewSecondsLeftChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._live_outputs: dict[str, Output] = {}
        self._staged: dict[str, dict] = {}   # name → staged output dict
        self._has_changes = False
        self._error_message = ""

        # Preview mode state
        self._preview_active = False
        self._preview_seconds_left = 10
        self._preview_saved_state: dict[str, dict] = {}
        self._preview_timer = QTimer(self)
        self._preview_timer.setInterval(1000)
        self._preview_timer.timeout.connect(self._on_preview_tick)

        self._kdl_file: KdlOutputFile | None = None
        self.refresh()

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @Property(list, notify=outputsChanged)
    def outputs(self) -> list:
        return list(self._staged.values())

    @Property(bool, notify=hasChangesChanged)
    def hasChanges(self) -> bool:
        return self._has_changes

    @Property(str, notify=errorMessageChanged)
    def errorMessage(self) -> str:
        return self._error_message

    @Property(bool, notify=previewActiveChanged)
    def previewActive(self) -> bool:
        return self._preview_active

    @Property(int, notify=previewSecondsLeftChanged)
    def previewSecondsLeft(self) -> int:
        return self._preview_seconds_left

    # ------------------------------------------------------------------
    # Slots — called from QML
    # ------------------------------------------------------------------

    @Slot()
    def refresh(self) -> None:
        """Reload live output state from Niri IPC and reset staged changes."""
        self._clear_error()
        try:
            self._live_outputs = get_outputs()
        except NiriSocketError as e:
            self._set_error(str(e))
            return

        try:
            output_file = find_output_file()
            self._kdl_file = KdlOutputFile(output_file)
        except Exception as e:
            self._set_error(f"Config error: {e}")
            return

        # Build staged dict from live state
        self._staged = {
            name: self._output_to_dict(out)
            for name, out in self._live_outputs.items()
        }
        self._set_has_changes(False)
        self.outputsChanged.emit()

    @Slot(str, bool)
    def setEnabled(self, output_name: str, enabled: bool) -> None:
        self._stage(output_name, "enabled", enabled)

    @Slot(str, int)
    def setModeIndex(self, output_name: str, mode_index: int) -> None:
        """Set mode by index into the output's modes list."""
        if output_name not in self._staged:
            return
        modes = self._staged[output_name].get("modes", [])
        if 0 <= mode_index < len(modes):
            self._stage(output_name, "current_mode", mode_index)

    @Slot(str, float)
    def setScale(self, output_name: str, scale: float) -> None:
        self._stage(output_name, "scale", round(scale, 4))

    @Slot(str, str)
    def setTransform(self, output_name: str, transform: str) -> None:
        self._stage(output_name, "transform", transform)

    @Slot(str, bool)
    def setVrr(self, output_name: str, enabled: bool) -> None:
        self._stage(output_name, "vrr_enabled", enabled)

    @Slot(str, int, int)
    def setPosition(self, output_name: str, x: int, y: int) -> None:
        if output_name not in self._staged:
            return
        staged = self._staged[output_name]
        staged["pos_x"] = x
        staged["pos_y"] = y
        self._set_has_changes(True)
        self.outputsChanged.emit()

    @Slot(str, str)
    def setDisplayType(self, output_name: str, display_type: str) -> None:
        """
        Set the display type for an output.
        Values: "extend", "mirror:<target>", "single", "disabled"
        """
        self._stage(output_name, "display_type", display_type)

    @Slot()
    def applyChanges(self) -> None:
        """Apply all staged changes via IPC and write to KDL config."""
        self._clear_error()
        try:
            self._apply_to_ipc()
            self._apply_to_kdl()
            # Re-read live state to confirm
            self._live_outputs = get_outputs()
            self._staged = {
                name: self._output_to_dict(out)
                for name, out in self._live_outputs.items()
            }
            self._set_has_changes(False)
            self.outputsChanged.emit()
        except Exception as e:
            self._set_error(f"Apply failed: {e}")

    @Slot()
    def revertChanges(self) -> None:
        """Discard all staged changes and reload from live state."""
        self._staged = {
            name: self._output_to_dict(out)
            for name, out in self._live_outputs.items()
        }
        self._set_has_changes(False)
        self.outputsChanged.emit()

    @Slot()
    def previewChanges(self) -> None:
        """Apply changes via IPC only (no KDL write). Start 10s countdown."""
        if self._preview_active:
            return
        self._clear_error()
        try:
            # Save current live state for revert
            self._preview_saved_state = {
                name: self._output_to_dict(out)
                for name, out in self._live_outputs.items()
            }
            self._apply_to_ipc()
            self._preview_active = True
            self._preview_seconds_left = 10
            self._preview_timer.start()
            self.previewActiveChanged.emit()
            self.previewSecondsLeftChanged.emit()
        except Exception as e:
            self._set_error(f"Preview failed: {e}")

    @Slot()
    def keepPreview(self) -> None:
        """User chose to keep the preview — write to KDL config."""
        self._stop_preview()
        try:
            self._apply_to_kdl()
            self._live_outputs = get_outputs()
            self._staged = {
                name: self._output_to_dict(out)
                for name, out in self._live_outputs.items()
            }
            self._set_has_changes(False)
            self.outputsChanged.emit()
        except Exception as e:
            self._set_error(f"Save failed: {e}")

    @Slot()
    def revertPreview(self) -> None:
        """User chose to revert — restore saved IPC state."""
        self._stop_preview()
        try:
            self._apply_state_to_ipc(self._preview_saved_state)
            self._staged = copy.deepcopy(self._preview_saved_state)
            self._set_has_changes(True)  # Still have unsaved staged changes
            self.outputsChanged.emit()
        except Exception as e:
            self._set_error(f"Revert failed: {e}")

    @Slot(result=list)
    def getTransformOptions(self) -> list:
        return [{"value": t, "label": TRANSFORM_LABELS.get(t, t)} for t in TRANSFORMS]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _stage(self, output_name: str, key: str, value) -> None:
        if output_name not in self._staged:
            return
        self._staged[output_name][key] = value
        self._set_has_changes(True)
        self.outputsChanged.emit()

    def _set_has_changes(self, val: bool) -> None:
        if self._has_changes != val:
            self._has_changes = val
            self.hasChangesChanged.emit()

    def _set_error(self, msg: str) -> None:
        self._error_message = msg
        self.errorMessageChanged.emit()

    def _clear_error(self) -> None:
        if self._error_message:
            self._error_message = ""
            self.errorMessageChanged.emit()

    def _on_preview_tick(self) -> None:
        self._preview_seconds_left -= 1
        self.previewSecondsLeftChanged.emit()
        if self._preview_seconds_left <= 0:
            self.revertPreview()

    def _stop_preview(self) -> None:
        self._preview_timer.stop()
        self._preview_active = False
        self.previewActiveChanged.emit()

    def _output_to_dict(self, output: Output) -> dict:
        logical = output.logical
        mode = output.current_output_mode
        return {
            "name": output.name,
            "displayName": output.display_name(),
            "enabled": output.enabled,
            "make": output.make,
            "model": output.model,
            "serial": output.serial,
            "physical_size": list(output.physical_size) if output.physical_size else None,
            "modes": [
                {
                    "width": m.width,
                    "height": m.height,
                    "refresh_rate": m.refresh_rate,
                    "refresh_hz": round(m.refresh_hz, 3),
                    "is_preferred": m.is_preferred,
                    "label": m.label(),
                }
                for m in output.modes
            ],
            "current_mode": output.current_mode,
            "vrr_supported": output.vrr_supported,
            "vrr_enabled": output.vrr_enabled,
            "scale": logical.scale if logical else 1.0,
            "transform": logical.transform if logical else "Normal",
            "pos_x": logical.x if logical else 0,
            "pos_y": logical.y if logical else 0,
            "logical_width": logical.width if logical else (mode.width if mode else 0),
            "logical_height": logical.height if logical else (mode.height if mode else 0),
            "display_type": "extend",  # Default; profiles can override
        }

    def _apply_to_ipc(self) -> None:
        """Send all staged changes to Niri via IPC."""
        for name, staged in self._staged.items():
            live = self._live_outputs.get(name)

            if not staged.get("enabled", True):
                set_output_off(name)
                continue
            else:
                if live and not live.enabled:
                    set_output_on(name)

            # Mode
            mode_idx = staged.get("current_mode")
            modes = staged.get("modes", [])
            if mode_idx is not None and mode_idx < len(modes):
                m = modes[mode_idx]
                set_output_mode(name, m["width"], m["height"], m["refresh_hz"])

            # Scale
            set_output_scale(name, staged.get("scale", 1.0))

            # Transform
            transform = staged.get("transform", "Normal")
            set_output_transform(name, transform)

            # Position
            set_output_position(name, staged.get("pos_x", 0), staged.get("pos_y", 0))

            # VRR
            if staged.get("vrr_supported", False):
                set_output_vrr(name, staged.get("vrr_enabled", False))

    def _apply_state_to_ipc(self, state: dict) -> None:
        """Restore a saved state dict to Niri IPC (used by preview revert)."""
        for name, staged in state.items():
            if not staged.get("enabled", True):
                set_output_off(name)
                continue
            set_output_on(name)
            mode_idx = staged.get("current_mode")
            modes = staged.get("modes", [])
            if mode_idx is not None and mode_idx < len(modes):
                m = modes[mode_idx]
                set_output_mode(name, m["width"], m["height"], m["refresh_hz"])
            set_output_scale(name, staged.get("scale", 1.0))
            set_output_transform(name, staged.get("transform", "Normal"))
            set_output_position(name, staged.get("pos_x", 0), staged.get("pos_y", 0))
            if staged.get("vrr_supported", False):
                set_output_vrr(name, staged.get("vrr_enabled", False))

    def _apply_to_kdl(self) -> None:
        """Write all staged changes to the KDL config file."""
        if self._kdl_file is None:
            return

        for name, staged in self._staged.items():
            mode_idx = staged.get("current_mode")
            modes = staged.get("modes", [])
            mode_str: str | None = None
            if mode_idx is not None and mode_idx < len(modes):
                m = modes[mode_idx]
                refresh = m["refresh_hz"]
                mode_str = f"{m['width']}x{m['height']}@{refresh:.3f}"

            block = KdlOutputBlock(
                name=name,
                enabled=staged.get("enabled", True),
                mode=mode_str,
                scale=staged.get("scale"),
                position_x=staged.get("pos_x"),
                position_y=staged.get("pos_y"),
                transform=staged.get("transform"),
                vrr=staged.get("vrr_enabled") if staged.get("vrr_supported") else None,
            )
            self._kdl_file.upsert(block)

        self._kdl_file.write()
        reload_config()
