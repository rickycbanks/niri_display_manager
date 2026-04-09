# Niri Display Manager

A GUI display manager for the [Niri](https://github.com/YaLTeR/niri) window manager.
Built with Python + PySide6 + QML.

[![AUR version](https://img.shields.io/aur/version/niri-display-manager)](https://aur.archlinux.org/packages/niri-display-manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- 🖥️ **Visual monitor canvas** — drag-and-drop positioning; scrollable/pannable when monitors extend off-screen
- ⚙️ **Per-monitor settings** — resolution, refresh rate, scale, rotation, VRR
- 🔢 **Snap-to-grid** — toggle between freeform drag and grid-aligned positioning (100 logical px grid)
- ⌨️ **Keyboard movement** — arrow keys nudge the selected monitor (1 px freeform / grid step when snapping); Esc deselects
- 👁️ **Preview mode** — apply changes temporarily with 10-second auto-revert
- 🔍 **Monitor identification** — flash number overlay on each physical display
- 💾 **Profiles** — save/load named configurations; auto-apply on monitor hotplug
- 🔌 **Disabled monitor support** — disabled monitors remain visible on canvas (faded) and can be re-enabled
- 📁 **Respects KDL includes** — edits the file where your `output` blocks actually live
- 📦 **Flatpak-safe** — communicates via Niri's IPC socket directly (no `niri msg` subprocess)

## Installation

### Arch Linux (AUR)

```bash
# Using an AUR helper
paru -S niri-display-manager
# or yay -S niri-display-manager

# Manually
git clone https://aur.archlinux.org/niri-display-manager.git
cd niri-display-manager
makepkg -si
```

### Debian / Ubuntu

Download the `.deb` from the [latest release](https://github.com/rickycbanks/niri_display_manager/releases/latest):

```bash
sudo dpkg -i niri-display-manager_<version>_amd64.deb
sudo apt-get install -f   # install any missing dependencies
```

### Fedora / RPM-based

Download the `.rpm` from the [latest release](https://github.com/rickycbanks/niri_display_manager/releases/latest):

```bash
sudo dnf install niri-display-manager-<version>-1.x86_64.rpm
```

## Running from Source

```bash
git clone https://github.com/rickycbanks/niri_display_manager
cd niri_display_manager

# Install dependencies and run (requires uv)
uv run niri-display-manager

# Run in daemon mode (auto-applies profiles on monitor hotplug)
uv run niri-display-manager --daemon
```

[UV](https://docs.astral.sh/uv/) automatically creates a virtual environment and installs all dependencies on first run.

## Hotplug Daemon

A systemd user service auto-applies matching profiles when monitors are connected/disconnected:

```bash
systemctl --user enable --now niri-display-manager-daemon
```

## Configuration & Profiles

Profiles are stored in `~/.config/niri/ndm-profiles/` as JSON files.
The app reads and writes the `output` block in whichever KDL file it finds them —
respecting `include` chains. If no output config is found, it creates
`~/.config/niri/outputs.kdl` and adds an `include` for it.

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
  ui/theme_bridge.py        # XDG portal accent colour detection

qml/                        # QML UI
  main.qml
  components/               # MonitorCanvas, MonitorBlock, MonitorSettings, etc.
  theme/Theme.qml           # Colour token system (inherits host accent via XDG portal)

packaging/
  aur/PKGBUILD              # Arch Linux — live on AUR
  systemd/                  # Hotplug daemon service unit
  io.github.rickycbanks.NiriDisplayManager.desktop  # Shared desktop entry

.github/workflows/
  release.yml               # Tag push → GitHub Release (tarball + .deb + .rpm + AUR)
```

## Releasing

Releases are fully automated via GitHub Actions. Pushing a version tag triggers four independent jobs — a failure in one does not block the others:

1. **tarball** — source archive attached to the GitHub Release
2. **deb** — `.deb` package for Debian/Ubuntu
3. **rpm** — `.rpm` package for Fedora/RPM-based distros
4. **aur** — updates `pkgver`/`sha256sums` in the PKGBUILD and pushes to AUR

```bash
git tag v0.x.y
git push origin v0.x.y
```

## Local Builds

A `Makefile` at the repo root builds packages locally (requires `fpm`: `gem install fpm`):

```bash
make build-tarball   # dist/niri-display-manager-<version>.tar.gz
make build-deb       # dist/niri-display-manager_<version>_amd64.deb
make build-rpm       # dist/niri-display-manager-<version>-1.x86_64.rpm
make build-all       # all three
make clean           # remove dist/
```

## Roadmap

- [x] AUR package
- [x] Automated releases via GitHub Actions
- [x] `.deb` and `.rpm` packages
- [ ] Flathub / additional distro repositories

## License

MIT
