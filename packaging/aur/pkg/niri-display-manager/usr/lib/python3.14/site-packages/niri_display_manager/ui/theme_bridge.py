"""
Dynamic theme detection for Niri Display Manager.

Reads host color preferences from the XDG Desktop Portal (org.freedesktop.portal.Settings).
Uses gdbus CLI for reliable nested-variant extraction (falls back gracefully if unavailable).

Falls back to Noctalia warm lavender palette if the portal is unavailable.
"""

from __future__ import annotations

import logging
import re
import subprocess

from PySide6.QtCore import QObject, Signal, Property, Slot
from PySide6.QtGui import QColor

log = logging.getLogger("ndm.theme")

# Noctalia fallback palette
_FALLBACK_ACCENT = "#7c6af0"
_FALLBACK_ACCENT_DIM = "#5b4cc4"
_FALLBACK_ACCENT_GLOW = "#9d8ff5"


def _gdbus_read(namespace: str, key: str) -> str | None:
    """
    Read a portal setting via gdbus CLI.
    Returns raw stdout string or None on failure.
    This is a read-only startup call; falls back silently if gdbus is not found.
    """
    try:
        result = subprocess.run(
            [
                "gdbus", "call", "--session",
                "--dest", "org.freedesktop.portal.Desktop",
                "--object-path", "/org/freedesktop/portal/desktop",
                "--method", "org.freedesktop.portal.Settings.Read",
                namespace, key,
            ],
            capture_output=True,
            text=True,
            timeout=2,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    return None


def _detect_accent_color() -> QColor:
    """
    Try to read accent color from XDG portal via gdbus.
    Returns a QColor (fallback to Noctalia purple if unavailable).
    """
    raw = _gdbus_read("org.freedesktop.appearance", "accent-color")
    if raw:
        # gdbus output: (<<(0.20784313976764679, 0.51764708757400513, 0.89411765336990356)>>,)
        m = re.search(r'\(([\d.]+),\s*([\d.]+),\s*([\d.]+)\)', raw)
        if m:
            try:
                r, g, b = float(m.group(1)), float(m.group(2)), float(m.group(3))
                if 0.0 <= r <= 1.0 and 0.0 <= g <= 1.0 and 0.0 <= b <= 1.0:
                    color = QColor.fromRgbF(r, g, b)
                    if color.lightness() > 10:
                        log.info(
                            "Portal accent: rgb(%.3f, %.3f, %.3f) → %s",
                            r, g, b, color.name(),
                        )
                        return color
            except (ValueError, AttributeError):
                pass

    log.debug("Using Noctalia fallback accent color")
    return QColor(_FALLBACK_ACCENT)


def _detect_color_scheme() -> str:
    """
    Read color-scheme preference from XDG portal.
    Returns 'dark', 'light', or 'no-preference'.
    """
    raw = _gdbus_read("org.freedesktop.appearance", "color-scheme")
    if raw:
        m = re.search(r'uint32\s+(\d+)', raw)
        if not m:
            # Try plain integer
            m = re.search(r'\b([012])\b', raw)
        if m:
            v = int(m.group(1))
            return {0: "no-preference", 1: "dark", 2: "light"}.get(v, "no-preference")
    return "no-preference"


def _make_glow(base: QColor) -> QColor:
    """Lighter/more saturated version of base for glow effect."""
    h, s, v, a = base.getHsvF()
    return QColor.fromHsvF(h, max(0.0, s - 0.1), min(1.0, v + 0.15), a)


def _make_dim(base: QColor) -> QColor:
    """Darker version of base for pressed/dim state."""
    h, s, v, a = base.getHsvF()
    return QColor.fromHsvF(h, min(1.0, s + 0.05), max(0.0, v - 0.2), a)


class ThemeBridge(QObject):
    """
    Exposes dynamic theme colors to QML as a context property 'ThemeDyn'.

    QML Theme.qml reads ThemeDyn.available; if true, uses ThemeDyn.accent/accentDim/accentGlow
    instead of the hardcoded Noctalia fallbacks.
    """

    accentChanged = Signal()
    accentDimChanged = Signal()
    accentGlowChanged = Signal()
    colorSchemeChanged = Signal()
    availableChanged = Signal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._available = False
        self._accent = QColor(_FALLBACK_ACCENT)
        self._accent_dim = QColor(_FALLBACK_ACCENT_DIM)
        self._accent_glow = QColor(_FALLBACK_ACCENT_GLOW)
        self._color_scheme = "no-preference"
        self._detect()

    def _detect(self) -> None:
        accent = _detect_accent_color()
        scheme = _detect_color_scheme()

        self._accent = accent
        self._accent_dim = _make_dim(accent)
        self._accent_glow = _make_glow(accent)
        self._color_scheme = scheme

        # Mark available if the color is meaningfully non-default
        default = QColor(_FALLBACK_ACCENT)
        self._available = accent.name() != default.name() and accent.lightness() > 10

    @Property(bool, notify=availableChanged)
    def available(self) -> bool:
        return self._available

    @Property(QColor, notify=accentChanged)
    def accent(self) -> QColor:
        return self._accent

    @Property(QColor, notify=accentDimChanged)
    def accentDim(self) -> QColor:
        return self._accent_dim

    @Property(QColor, notify=accentGlowChanged)
    def accentGlow(self) -> QColor:
        return self._accent_glow

    @Property(str, notify=colorSchemeChanged)
    def colorScheme(self) -> str:
        return self._color_scheme

    @Slot()
    def refresh(self) -> None:
        """Re-detect host colors (e.g. after portal settings change)."""
        self._detect()
        self.accentChanged.emit()
        self.accentDimChanged.emit()
        self.accentGlowChanged.emit()
        self.colorSchemeChanged.emit()
        self.availableChanged.emit()
