"""
Resolves the Niri KDL include chain to find the file that contains output blocks.

Strategy:
  1. Parse ~/.config/niri/config.kdl
  2. Follow `include` directives recursively (BFS)
  3. Return the first file that contains an `output "..."` block
  4. If none found: create ~/.config/niri/outputs.kdl and insert
     `include "outputs.kdl"` into the main config
"""

from __future__ import annotations

import re
from pathlib import Path


_INCLUDE_RE = re.compile(r'^\s*include\s+"([^"]+)"', re.MULTILINE)
_OUTPUT_RE = re.compile(r'^\s*(?:/-\s*)?output\s+"[^"]+"', re.MULTILINE)

NIRI_CONFIG_DIR = Path.home() / ".config" / "niri"
MAIN_CONFIG = NIRI_CONFIG_DIR / "config.kdl"
OUTPUTS_FILE = NIRI_CONFIG_DIR / "outputs.kdl"


def find_output_file() -> Path:
    """
    Walk the include tree starting from the main config.
    Return the Path to the first file containing output blocks.
    If no file has outputs, create outputs.kdl and wire it in.
    """
    if not MAIN_CONFIG.exists():
        raise FileNotFoundError(f"Niri config not found: {MAIN_CONFIG}")

    visited: set[Path] = set()
    queue: list[Path] = [MAIN_CONFIG]

    while queue:
        current = queue.pop(0)
        current = current.resolve()
        if current in visited:
            continue
        visited.add(current)

        if not current.exists():
            continue

        text = current.read_text(encoding="utf-8")

        if _OUTPUT_RE.search(text):
            return current

        # Enqueue included files (relative to the file containing the include)
        for match in _INCLUDE_RE.finditer(text):
            include_path_str = match.group(1)
            include_path = Path(include_path_str)
            if not include_path.is_absolute():
                include_path = current.parent / include_path
            queue.append(include_path.resolve())

    return _create_outputs_file()


def _create_outputs_file() -> Path:
    """Create a new outputs.kdl and add its include to the main config."""
    NIRI_CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUTS_FILE.write_text(
        "// Output configuration managed by Niri Display Manager\n",
        encoding="utf-8",
    )

    main_text = MAIN_CONFIG.read_text(encoding="utf-8")
    include_line = '\ninclude "outputs.kdl"\n'
    if 'include "outputs.kdl"' not in main_text:
        main_text += include_line
        MAIN_CONFIG.write_text(main_text, encoding="utf-8")

    return OUTPUTS_FILE
