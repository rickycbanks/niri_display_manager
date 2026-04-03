"""Entry point for Niri Display Manager."""

import argparse
import sys
from pathlib import Path

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="niri-display-manager",
        description="GUI display manager for the Niri window manager",
    )
    parser.add_argument(
        "--daemon",
        action="store_true",
        help="Run in daemon mode: watch for monitor hotplug events and auto-apply profiles",
    )
    parser.add_argument(
        "--apply-profile",
        metavar="NAME",
        help="Apply a named profile and exit",
    )
    parser.add_argument(
        "--version",
        action="version",
        version="niri-display-manager 0.1.0",
    )
    args = parser.parse_args()

    if args.daemon:
        _run_daemon()
        return

    if args.apply_profile:
        _apply_profile(args.apply_profile)
        return

    _run_gui()


def _run_gui() -> None:
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Niri Display Manager")
    app.setOrganizationName("rickycbanks")
    app.setOrganizationDomain("io.github.rickycbanks")

    from niri_display_manager.ui.bridge import DisplayBridge

    bridge = DisplayBridge()
    engine = QQmlApplicationEngine()

    # Register QML module paths
    qml_dir = Path(__file__).parent.parent.parent / "qml"
    engine.addImportPath(str(qml_dir))

    # Expose bridge to QML as a context property
    engine.rootContext().setContextProperty("DisplayBridge", bridge)

    qml_path = qml_dir / "main.qml"
    engine.load(qml_path)

    if not engine.rootObjects():
        sys.exit(1)

    sys.exit(app.exec())


def _run_daemon() -> None:
    from niri_display_manager.daemon.hotplug import run_daemon
    run_daemon()


def _apply_profile(name: str) -> None:
    from niri_display_manager.config import profile_manager as pm
    from niri_display_manager.daemon.hotplug import _apply_profile as apply_profile
    from niri_display_manager.ipc.niri_socket import get_outputs

    try:
        outputs = get_outputs()
        apply_profile(name, outputs)
    except Exception as e:
        print(f"Error applying profile '{name}': {e}", file=sys.stderr)
        sys.exit(1)
