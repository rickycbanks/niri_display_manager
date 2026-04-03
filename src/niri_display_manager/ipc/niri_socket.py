"""
Direct communication with the Niri compositor over its Unix IPC socket.

Protocol: newline-delimited JSON over $NIRI_SOCKET.
- Send a JSON request + newline
- Receive a JSON reply + newline
- For EventStream requests, subsequent newline-delimited events keep flowing
"""

from __future__ import annotations

import json
import os
import socket
from dataclasses import dataclass, field
from typing import Any, Callable, Generator


SOCKET_ENV = "NIRI_SOCKET"


class NiriSocketError(Exception):
    """Raised when communication with the Niri socket fails."""


def _get_socket_path() -> str:
    path = os.environ.get(SOCKET_ENV)
    if not path:
        raise NiriSocketError(
            f"${SOCKET_ENV} is not set. Is Niri running?"
        )
    return path


def _send_request(sock: socket.socket, request: Any) -> None:
    data = json.dumps(request).encode("utf-8") + b"\n"
    sock.sendall(data)


def _recv_line(sock: socket.socket, buf: bytearray) -> tuple[bytes, bytearray]:
    """Read bytes from sock until a newline, returning (line, remaining_buf)."""
    while b"\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            raise NiriSocketError("Socket closed unexpectedly")
        buf.extend(chunk)
    idx = buf.index(b"\n")
    line = bytes(buf[:idx])
    remaining = bytearray(buf[idx + 1:])
    return line, remaining


def _parse_reply(line: bytes) -> Any:
    reply = json.loads(line)
    if isinstance(reply, dict) and "Err" in reply:
        raise NiriSocketError(f"Niri error: {reply['Err']}")
    if isinstance(reply, dict) and "Ok" in reply:
        return reply["Ok"]
    return reply


def request(req: Any) -> Any:
    """Send a single request to Niri and return the response payload."""
    path = _get_socket_path()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(path)
        _send_request(sock, req)
        buf = bytearray()
        line, _ = _recv_line(sock, buf)
        return _parse_reply(line)


def event_stream(callback: Callable[[dict], None]) -> None:
    """
    Subscribe to the Niri event stream.
    Calls callback(event_dict) for each event received.
    Blocks indefinitely — run in a thread.
    """
    path = _get_socket_path()
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(path)
        _send_request(sock, "EventStream")
        buf = bytearray()
        # First line is the reply to the EventStream request itself
        line, buf = _recv_line(sock, buf)
        _parse_reply(line)  # Should be {"Ok": "Handled"}
        # Subsequent lines are events
        while True:
            line, buf = _recv_line(sock, buf)
            event = json.loads(line)
            callback(event)


# ---------------------------------------------------------------------------
# Convenience typed wrappers
# ---------------------------------------------------------------------------

def get_outputs() -> dict[str, "Output"]:
    """Return a dict mapping output name → Output for all connected outputs."""
    raw = request("Outputs")
    outputs_raw = raw.get("Outputs", {})
    return {name: Output.from_dict(name, data) for name, data in outputs_raw.items()}


def set_output_off(output_name: str) -> None:
    request({"Output": {"output": output_name, "action": "Off"}})


def set_output_on(output_name: str) -> None:
    request({"Output": {"output": output_name, "action": "On"}})


def set_output_mode(output_name: str, width: int, height: int, refresh: float | None = None) -> None:
    mode: dict = {"width": width, "height": height}
    if refresh is not None:
        mode["refresh"] = refresh
    request({
        "Output": {
            "output": output_name,
            "action": {"Mode": {"mode": {"Specific": mode}}},
        }
    })


def set_output_mode_auto(output_name: str) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Mode": {"mode": "Automatic"}},
        }
    })


def set_output_scale(output_name: str, scale: float) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Scale": {"scale": {"Specific": scale}}},
        }
    })


def set_output_scale_auto(output_name: str) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Scale": {"scale": "Automatic"}},
        }
    })


def set_output_transform(output_name: str, transform: str) -> None:
    """
    Set output transform.
    Valid values: "Normal", "90", "180", "270", "Flipped",
                  "Flipped90", "Flipped180", "Flipped270"
    """
    request({
        "Output": {
            "output": output_name,
            "action": {"Transform": {"transform": transform}},
        }
    })


def set_output_position(output_name: str, x: int, y: int) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Position": {"position": {"Specific": {"x": x, "y": y}}}},
        }
    })


def set_output_position_auto(output_name: str) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Position": {"position": "Automatic"}},
        }
    })


def set_output_vrr(output_name: str, enabled: bool, on_demand: bool = False) -> None:
    request({
        "Output": {
            "output": output_name,
            "action": {"Vrr": {"vrr": {"vrr": enabled, "on_demand": on_demand}}},
        }
    })


def reload_config() -> None:
    """Ask Niri to reload its config file from disk."""
    request({"Action": {"LoadConfigFile": {}}})


# ---------------------------------------------------------------------------
# Data classes mirroring the Niri IPC types
# ---------------------------------------------------------------------------

@dataclass
class OutputMode:
    width: int
    height: int
    refresh_rate: int   # in millihertz
    is_preferred: bool

    @property
    def refresh_hz(self) -> float:
        return self.refresh_rate / 1000.0

    def label(self) -> str:
        return f"{self.width}×{self.height} @ {self.refresh_hz:.3f} Hz"

    @classmethod
    def from_dict(cls, d: dict) -> "OutputMode":
        return cls(
            width=d["width"],
            height=d["height"],
            refresh_rate=d["refresh_rate"],
            is_preferred=d.get("is_preferred", False),
        )


@dataclass
class LogicalOutput:
    x: int
    y: int
    width: int
    height: int
    scale: float
    transform: str  # "Normal", "90", "180", "270", "Flipped", etc.

    @classmethod
    def from_dict(cls, d: dict) -> "LogicalOutput":
        return cls(
            x=d["x"],
            y=d["y"],
            width=d["width"],
            height=d["height"],
            scale=d["scale"],
            transform=d.get("transform", "Normal"),
        )


@dataclass
class Output:
    name: str
    make: str
    model: str
    serial: str | None
    physical_size: tuple[int, int] | None
    modes: list[OutputMode]
    current_mode: int | None      # index into modes, None if disabled
    is_custom_mode: bool
    vrr_supported: bool
    vrr_enabled: bool
    logical: LogicalOutput | None  # None if disabled

    @property
    def enabled(self) -> bool:
        return self.logical is not None

    @property
    def current_output_mode(self) -> OutputMode | None:
        if self.current_mode is not None and self.current_mode < len(self.modes):
            return self.modes[self.current_mode]
        return None

    def display_name(self) -> str:
        parts = [p for p in (self.make, self.model) if p and p != "Unknown"]
        label = " ".join(parts) if parts else self.name
        return f"{label} ({self.name})"

    @classmethod
    def from_dict(cls, name: str, d: dict) -> "Output":
        return cls(
            name=name,
            make=d.get("make", "Unknown"),
            model=d.get("model", "Unknown"),
            serial=d.get("serial"),
            physical_size=tuple(d["physical_size"]) if d.get("physical_size") else None,
            modes=[OutputMode.from_dict(m) for m in d.get("modes", [])],
            current_mode=d.get("current_mode"),
            is_custom_mode=d.get("is_custom_mode", False),
            vrr_supported=d.get("vrr_supported", False),
            vrr_enabled=d.get("vrr_enabled", False),
            logical=LogicalOutput.from_dict(d["logical"]) if d.get("logical") else None,
        )


# Valid transform values (matching Niri's serde names)
TRANSFORMS = [
    "Normal",
    "90",
    "180",
    "270",
    "Flipped",
    "Flipped90",
    "Flipped180",
    "Flipped270",
]

TRANSFORM_LABELS = {
    "Normal": "Normal (0°)",
    "90": "90° CCW",
    "180": "180°",
    "270": "270° CCW",
    "Flipped": "Flipped",
    "Flipped90": "Flipped + 90° CCW",
    "Flipped180": "Flipped + 180°",
    "Flipped270": "Flipped + 270° CCW",
}
