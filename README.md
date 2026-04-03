# Niri Display Manager

A GUI display manager for the [Niri](https://github.com/YaLTeR/niri) window manager.
Built with Python + PySide6 + QML, designed to eventually become a [Noctalia](https://github.com/noctalia-dev/noctalia-shell) plugin.

## Features

- 🖥️ **Visual monitor layout** — drag-and-drop monitor positioning
- ⚙️ **Per-monitor settings** — resolution, refresh rate, scale, rotation, VRR
- 🔀 **Display modes** — Extend, Clone/Mirror, Single, Primary designation
- 👁️ **Preview mode** — apply changes temporarily with 10-second auto-revert
- 🔍 **Monitor identification** — flash number overlay on each physical display
- 💾 **Profiles** — save/load configurations; auto-apply on monitor hotplug
- 📁 **Respects KDL includes** — edits the file where your `output` blocks actually live
- 📦 **Flatpak-safe** — communicates via Niri's IPC socket directly (no `niri msg` subprocess)

## Prerequisites

- [Niri](https://github.com/YaLTeR/niri) window manager (running, with `$NIRI_SOCKET` set)
- Python ≥ 3.12
- [UV](https://docs.astral.sh/uv/) for dependency management

## Running Locally (Development)

```bash
git clone https://github.com/rickycbanks/niri_display_manager
cd niri_display_manager

# Install dependencies and run
uv run niri-display-manager

# Run in daemon mode (auto-applies profiles on monitor hotplug)
uv run niri-display-manager --daemon
```

UV automatically creates a virtual environment and installs all dependencies on first run.

## Project Structure

```
src/niri_display_manager/   # Python backend
  main.py                   # Entry point + argparse
  ipc/niri_socket.py        # Direct Niri IPC socket communication
  config/kdl_finder.py      # Resolves KDL include chain
  config/kdl_parser.py      # Reads/writes output blocks in KDL
  config/profile_manager.py # Profile save/load/match
  daemon/hotplug.py         # Hotplug event watcher
  ui/bridge.py              # QML ↔ Python bridge

qml/                        # QML UI (portable to Noctalia plugin)
  main.qml
  components/               # MonitorCanvas, MonitorSettings, etc.
  theme/Theme.qml           # Color token system

packaging/
  aur/PKGBUILD
  flatpak/io.github.rickycbanks.NiriDisplayManager.json
```

## Configuration & Profiles

Profiles are stored in `~/.config/niri/ndm-profiles/` as JSON files.
The app reads and writes the `output` block in whichever KDL file it finds them —
respecting `include` chains. If no output config is found, it creates
`~/.config/niri/outputs.kdl` and adds an `include` for it.

## Building for Distribution

### Arch Linux (AUR)

```bash
cd packaging/aur
makepkg -si
```

### Flatpak

```bash
flatpak-builder --install --user build-dir \
  packaging/flatpak/io.github.rickycbanks.NiriDisplayManager.json
flatpak run io.github.rickycbanks.NiriDisplayManager
```

Flatpak permissions required:
- `--socket=wayland` — GUI display
- `--filesystem=xdg-run/niri` — Niri IPC socket
- `--filesystem=xdg-config/niri:rw` — config files and profiles

## Noctalia Plugin (Future)

The QML files under `qml/` are structured to slot directly into a Noctalia plugin.
When ready, they become `Panel.qml`, `Settings.qml`, etc. per the
[plugin spec](https://github.com/noctalia-dev/noctalia-plugins).

## License

MIT
