"""
Reads and writes Niri `output` blocks in a KDL file.

Handles the format:
    output "name" {
        mode "WxH@R.RRR"
        scale S
        position x=X y=Y
        transform "T"
        vrr
    }

Disabled outputs use a `/-` prefix:
    /- output "name" { ... }

Design principles:
  - Only modifies output blocks; all other content is preserved verbatim.
  - Changes are staged in memory; call write() to commit to disk.
  - A backup copy (.bak) is written before any disk write.
"""

from __future__ import annotations

import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Output block representation
# ---------------------------------------------------------------------------

@dataclass
class KdlOutputBlock:
    """Parsed representation of one output block in a KDL file."""
    name: str
    enabled: bool           # False if the block starts with `/-`
    mode: Optional[str]     # e.g. "1920x1080@60.020" or None (auto)
    scale: Optional[float]  # None = auto
    position_x: Optional[int]
    position_y: Optional[int]
    transform: Optional[str]   # "Normal", "90", etc.
    vrr: Optional[bool]
    extra_lines: list[str] = field(default_factory=list)  # unrecognised lines preserved

    def to_kdl(self) -> str:
        prefix = "/- " if not self.enabled else ""
        lines = [f'{prefix}output "{self.name}" {{']
        if self.mode is not None:
            lines.append(f'    mode "{self.mode}"')
        if self.scale is not None:
            # Format: integer if whole number, otherwise decimal
            scale_str = str(int(self.scale)) if self.scale == int(self.scale) else str(self.scale)
            lines.append(f'    scale {scale_str}')
        if self.position_x is not None and self.position_y is not None:
            lines.append(f'    position x={self.position_x} y={self.position_y}')
        if self.transform is not None and self.transform != "Normal":
            lines.append(f'    transform "{self.transform}"')
        if self.vrr is True:
            lines.append('    vrr')
        for extra in self.extra_lines:
            lines.append(f'    {extra}')
        lines.append("}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# Regex patterns
# ---------------------------------------------------------------------------

# Matches start of an output block: optional /- prefix, then output "name" {
_BLOCK_START_RE = re.compile(
    r'^(?P<disabled>/-\s*)?output\s+"(?P<name>[^"]+)"\s*\{',
    re.MULTILINE,
)

_MODE_RE = re.compile(r'^\s*mode\s+"([^"]+)"')
_SCALE_RE = re.compile(r'^\s*scale\s+([\d.]+)')
_POSITION_RE = re.compile(r'^\s*position\s+x=([-\d]+)\s+y=([-\d]+)')
_TRANSFORM_RE = re.compile(r'^\s*transform\s+"([^"]+)"')
_VRR_RE = re.compile(r'^\s*vrr\b')


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

class KdlOutputFile:
    """
    Manages reading and writing output blocks in a single KDL file.
    All mutations are staged until write() is called.
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self._original_text: str = ""
        self._outputs: dict[str, KdlOutputBlock] = {}
        self._load()

    def _load(self) -> None:
        if self.path.exists():
            self._original_text = self.path.read_text(encoding="utf-8")
        else:
            self._original_text = ""
        self._outputs = _parse_outputs(self._original_text)

    def outputs(self) -> dict[str, KdlOutputBlock]:
        return dict(self._outputs)

    def get(self, name: str) -> Optional[KdlOutputBlock]:
        return self._outputs.get(name)

    def upsert(self, block: KdlOutputBlock) -> None:
        """Add or replace an output block (staged)."""
        self._outputs[block.name] = block

    def remove(self, name: str) -> None:
        """Remove an output block if it exists (staged)."""
        self._outputs.pop(name, None)

    def write(self) -> None:
        """Commit staged changes to disk. Writes a .bak backup first."""
        new_text = _render(self._original_text, self._outputs)
        if self.path.exists():
            shutil.copy2(self.path, self.path.with_suffix(".kdl.bak"))
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(new_text, encoding="utf-8")
        self._original_text = new_text

    def reload(self) -> None:
        """Discard staged changes and re-read from disk."""
        self._load()


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def _find_block_extents(text: str) -> list[tuple[int, int, str, bool]]:
    """
    Find all output block extents in text.
    Returns list of (start, end, name, disabled) where text[start:end] is the full block.
    """
    results = []
    for m in _BLOCK_START_RE.finditer(text):
        start = m.start()
        # Walk forward counting braces to find the closing }
        brace_pos = text.index("{", m.start())
        depth = 0
        i = brace_pos
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1
                    results.append((start, end, m.group("name"), bool(m.group("disabled"))))
                    break
            i += 1
    return results


def _parse_block(block_text: str, name: str, disabled: bool) -> KdlOutputBlock:
    mode = None
    scale = None
    pos_x = None
    pos_y = None
    transform = None
    vrr = None
    extra_lines: list[str] = []

    # Extract lines inside the braces
    inner = block_text[block_text.index("{") + 1: block_text.rindex("}")]
    for line in inner.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        if m := _MODE_RE.match(line):
            mode = m.group(1)
        elif m := _SCALE_RE.match(line):
            scale = float(m.group(1))
        elif m := _POSITION_RE.match(line):
            pos_x = int(m.group(1))
            pos_y = int(m.group(2))
        elif m := _TRANSFORM_RE.match(line):
            transform = m.group(1)
        elif _VRR_RE.match(line):
            vrr = True
        else:
            extra_lines.append(stripped)

    return KdlOutputBlock(
        name=name,
        enabled=not disabled,
        mode=mode,
        scale=scale,
        position_x=pos_x,
        position_y=pos_y,
        transform=transform,
        vrr=vrr,
        extra_lines=extra_lines,
    )


def _parse_outputs(text: str) -> dict[str, KdlOutputBlock]:
    outputs: dict[str, KdlOutputBlock] = {}
    for start, end, name, disabled in _find_block_extents(text):
        block_text = text[start:end]
        outputs[name] = _parse_block(block_text, name, disabled)
    return outputs


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

def _render(original_text: str, outputs: dict[str, KdlOutputBlock]) -> str:
    """
    Rebuild the file text: replace existing output blocks with new versions,
    append any new blocks, preserve everything else.
    """
    extents = _find_block_extents(original_text)

    # Names that exist in the original file
    original_names = {name for _, _, name, _ in extents}
    # Names in the new outputs dict
    new_names = set(outputs.keys())

    # Build replacement map: original block range → new text
    replacements: list[tuple[int, int, str]] = []
    for start, end, name, _ in extents:
        if name in outputs:
            replacements.append((start, end, outputs[name].to_kdl()))
        else:
            # Block was removed — replace with empty string
            replacements.append((start, end, ""))

    # Apply replacements in reverse order so offsets stay valid
    result = original_text
    for start, end, replacement in sorted(replacements, reverse=True):
        # Trim surrounding blank lines for removed blocks
        if replacement == "":
            # Also eat one trailing newline if present
            if end < len(result) and result[end] == "\n":
                end += 1
        result = result[:start] + replacement + result[end:]

    # Append blocks that are new (not in original file)
    added_names = new_names - original_names
    for name in sorted(added_names):
        block = outputs[name]
        if result and not result.endswith("\n"):
            result += "\n"
        result += "\n" + block.to_kdl() + "\n"

    return result
