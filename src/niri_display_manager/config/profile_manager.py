"""
Profile management for Niri Display Manager.

Profiles are stored as JSON files in ~/.config/niri/ndm-profiles/.
Each profile captures the full display configuration for a set of connected outputs.
Auto-match: when the set of connected output names matches a saved profile's connector key,
that profile can be applied automatically.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Optional


PROFILES_DIR = Path.home() / ".config" / "niri" / "ndm-profiles"


def _ensure_dir() -> None:
    PROFILES_DIR.mkdir(parents=True, exist_ok=True)


def _profile_path(name: str) -> Path:
    safe = re.sub(r"[^\w\- ]", "_", name).strip().replace(" ", "_")
    return PROFILES_DIR / f"{safe}.json"


def list_profiles() -> list[str]:
    """Return a sorted list of profile names (without extension)."""
    _ensure_dir()
    return sorted(
        p.stem for p in PROFILES_DIR.glob("*.json") if p.is_file()
    )


def save_profile(name: str, staged: dict[str, dict]) -> None:
    """
    Save the current staged configuration as a named profile.

    staged: mapping of output_name → staged output dict (from DisplayBridge._staged)
    """
    _ensure_dir()
    connector_key = sorted(staged.keys())

    outputs = {}
    for output_name, data in staged.items():
        mode_idx = data.get("current_mode")
        modes = data.get("modes", [])
        mode_str: str | None = None
        if mode_idx is not None and 0 <= mode_idx < len(modes):
            m = modes[mode_idx]
            mode_str = f"{m['width']}x{m['height']}@{m['refresh_hz']:.3f}"

        outputs[output_name] = {
            "enabled": data.get("enabled", True),
            "mode": mode_str,
            "scale": data.get("scale", 1.0),
            "transform": data.get("transform", "Normal"),
            "vrr": data.get("vrr_enabled", False),
            "position": {
                "x": data.get("pos_x", 0),
                "y": data.get("pos_y", 0),
            },
            "display_type": data.get("display_type", "extend"),
        }

    profile = {
        "name": name,
        "connector_key": connector_key,
        "outputs": outputs,
    }

    path = _profile_path(name)
    path.write_text(json.dumps(profile, indent=2), encoding="utf-8")


def load_profile(name: str) -> dict:
    """
    Load a profile by name. Returns the raw profile dict.
    Raises FileNotFoundError if the profile does not exist.
    """
    path = _profile_path(name)
    if not path.exists():
        raise FileNotFoundError(f"Profile '{name}' not found")
    return json.loads(path.read_text(encoding="utf-8"))


def delete_profile(name: str) -> None:
    """Delete a profile by name. Silent if not found."""
    path = _profile_path(name)
    if path.exists():
        path.unlink()


def rename_profile(old_name: str, new_name: str) -> None:
    """Rename a profile."""
    data = load_profile(old_name)
    data["name"] = new_name
    new_path = _profile_path(new_name)
    new_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    _profile_path(old_name).unlink()


def find_auto_profile(connected_names: list[str]) -> Optional[str]:
    """
    Find the first saved profile whose connector_key matches the given set of output names.
    Returns the profile name, or None if no match.
    """
    key = sorted(connected_names)
    for pname in list_profiles():
        try:
            profile = load_profile(pname)
            if sorted(profile.get("connector_key", [])) == key:
                return pname
        except Exception:
            continue
    return None


def apply_profile_to_staged(profile: dict, current_staged: dict[str, dict]) -> dict[str, dict]:
    """
    Merge a profile's settings into the current staged dict.

    Only updates outputs that are both in the profile and currently connected.
    Preserves the current mode list (from live IPC) but picks the best matching
    mode index from the profile's stored mode string.

    Returns the updated staged dict (a copy).
    """
    import copy
    staged = copy.deepcopy(current_staged)
    p_outputs = profile.get("outputs", {})

    for output_name, p_out in p_outputs.items():
        if output_name not in staged:
            continue
        s = staged[output_name]

        s["enabled"] = p_out.get("enabled", True)
        s["scale"] = p_out.get("scale", 1.0)
        s["transform"] = p_out.get("transform", "Normal")
        s["vrr_enabled"] = p_out.get("vrr", False)
        s["display_type"] = p_out.get("display_type", "extend")

        pos = p_out.get("position", {})
        s["pos_x"] = pos.get("x", 0)
        s["pos_y"] = pos.get("y", 0)

        # Try to match saved mode string to a mode index
        profile_mode = p_out.get("mode")
        if profile_mode:
            best_idx = _find_mode_index(s.get("modes", []), profile_mode)
            if best_idx is not None:
                s["current_mode"] = best_idx

    return staged


def _find_mode_index(modes: list[dict], mode_str: str) -> Optional[int]:
    """
    Find the index of the closest matching mode.

    mode_str format: "WIDTHxHEIGHT@REFRESH" e.g. "2560x1440@143.856"
    """
    try:
        res_part, refresh_part = mode_str.split("@")
        w, h = res_part.split("x")
        target_w, target_h = int(w), int(h)
        target_r = float(refresh_part)
    except (ValueError, AttributeError):
        return None

    # First pass: exact match
    for i, m in enumerate(modes):
        if m["width"] == target_w and m["height"] == target_h:
            if abs(m["refresh_hz"] - target_r) < 0.1:
                return i

    # Second pass: same resolution, closest refresh
    best_i: Optional[int] = None
    best_diff = float("inf")
    for i, m in enumerate(modes):
        if m["width"] == target_w and m["height"] == target_h:
            diff = abs(m["refresh_hz"] - target_r)
            if diff < best_diff:
                best_diff = diff
                best_i = i

    return best_i
