"""Glassy System Monitor for Windows — a glass system monitor on the desktop.

Hosts the same QML the Plasma widget and the Hyprland panel draw (see
windows/qml/Monitor.qml) in a borderless window, plus a tray icon and the
shared settings studio. Readings come from windows/sampler.py, which replaces
the /proc and shell probes.

Run it:
  pip install -r windows/requirements.txt
  python windows/app.py

  python windows/app.py --selftest        load Monitor.qml headless, exit 1 on
                                          any QML warning/error — what CI runs
  python windows/app.py --selftest-sampler  one real round of readings
  python windows/app.py --soak 120        run every section at a fast pace
                                          headless and fail if memory grows
  python windows/app.py --shot card.png   save a picture of the card and exit
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

# Frozen by PyInstaller the bundled tree is rooted at _MEIPASS, which is where
# the spec lays out package/, hyprland/ and windows/qml/.
ROOT = Path(getattr(sys, "_MEIPASS", None) or Path(__file__).resolve().parent.parent)

# Must happen before PySide6 is imported: the QPA platform plugin is chosen at
# import time, so a headless run has to say so first.
if (
    any(flag in sys.argv for flag in ("--selftest", "--soak"))
    and not os.environ.get("QT_QPA_PLATFORM")
):
    os.environ["QT_QPA_PLATFORM"] = "offscreen"

try:
    from PySide6.QtCore import (
        Property,
        QEvent,
        QObject,
        QPoint,
        QRect,
        QSize,
        Qt,
        QTimer,
        QUrl,
        Signal,
        Slot,
    )
    from PySide6.QtGui import QColor, QCursor, QIcon, QImage, QPainter
    from PySide6.QtQml import QJSValue
    from PySide6.QtQuick import QQuickImageProvider, QQuickView, QQuickWindow
    from PySide6.QtWidgets import QApplication, QMenu, QMessageBox, QSystemTrayIcon
except ImportError:  # pragma: no cover - dev-time hint only
    print(
        "Missing PySide6. Run: pip install -r windows/requirements.txt", file=sys.stderr
    )
    raise

import sampler as sampling

APP_DIR = "glassy-system-monitor"


def data_dir() -> Path:
    base = os.environ.get("APPDATA") or os.environ.get("XDG_CONFIG_HOME")
    return Path(base or Path.home() / ".config") / APP_DIR


def local_dir() -> Path:
    """Caches (compiled shaders) — not roaming settings."""
    base = os.environ.get("LOCALAPPDATA") or os.environ.get("XDG_CACHE_HOME")
    path = Path(base or Path.home() / ".cache") / APP_DIR
    path.mkdir(parents=True, exist_ok=True)
    return path


def settings_path() -> Path:
    return data_dir() / "settings.json"


def settings_json() -> str:
    """The user's saved settings, if any — parsed QML-side by Configuration.js."""
    path = settings_path()
    try:
        return path.read_text(encoding="utf-8") if path.is_file() else ""
    except OSError:
        return ""


class HostPrefs:
    """Choices that belong to this host, not to the shared settings: today,
    whether the opt-in hardware sensors (admin) are on. host.json next to
    settings.json."""

    def __init__(self) -> None:
        self.path = data_dir() / "host.json"
        try:
            self.values = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            self.values = {}
        if not isinstance(self.values, dict):
            self.values = {}

    @property
    def hw_sensors(self) -> bool:
        return bool(self.values.get("hwSensors", False))

    def set_hw_sensors(self, enabled: bool) -> None:
        self.values["hwSensors"] = enabled
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self.path.with_suffix(f".json.{os.getpid()}.tmp")
            tmp.write_text(json.dumps(self.values), encoding="utf-8")
            os.replace(tmp, self.path)
        except OSError:
            pass


def relaunch_as_admin() -> bool:
    """Start this program again through the UAC prompt; False if declined."""
    import ctypes

    if getattr(sys, "frozen", False):
        program, arguments = sys.executable, sys.argv[1:]
    else:
        program, arguments = sys.executable, [str(Path(__file__).resolve()), *sys.argv[1:]]
    result = ctypes.windll.shell32.ShellExecuteW(
        None, "runas", program, subprocess.list2cmdline(arguments), None, 1
    )
    return result > 32


class SettingsStore(QObject):
    """Saves what the settings window applies; reports where the card was put."""

    changed = Signal()
    # x, y, width, height of a hand-placed window (Move / resize, middle-drag).
    placed = Signal(int, int, int, int)
    placementReset = Signal()

    def __init__(self):
        super().__init__()
        self._error = ""

    settingsError = Property(str, lambda self: self._error, notify=changed)

    @Slot(str)
    def saveSettings(self, text: str) -> None:
        path = settings_path()
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            tmp = path.with_suffix(f".json.{os.getpid()}.tmp")
            tmp.write_text(text, encoding="utf-8")
            os.replace(tmp, path)
            self._error = ""
        except OSError as error:
            self._error = f"Could not save settings to {path}: {error.strerror}"
        self.changed.emit()


class SamplerBridge(QObject):
    """Qt face of sampler.Sampler: readings in as a signal, config out as a slot."""

    sampled = Signal(dict)

    def __init__(self, enabled: bool = True, hw_sensors: bool = False):
        super().__init__()
        # Disabled (--selftest): no thread, no readings.
        self._enabled = enabled
        self._hw_sensors = hw_sensors
        self._last: tuple | None = None
        # Emitted from the worker thread; Qt queues it onto this object's thread.
        self._sampler = sampling.Sampler(self.sampled.emit)

    @Slot("QVariantList", "QVariantMap", int)
    def configure(self, wanted, options, interval_ms) -> None:
        if not self._enabled:
            return
        self._last = ([str(w) for w in wanted], dict(options), int(interval_ms))
        self._apply()

    def _apply(self) -> None:
        if self._last is None:
            return
        wanted, options, interval_ms = self._last
        self._sampler.configure(
            wanted, {**options, "hwSensors": self._hw_sensors}, interval_ms
        )
        self._sampler.start()

    def set_hw_sensors(self, enabled: bool) -> None:
        self._hw_sensors = enabled
        self._apply()

    def hw_status(self) -> str:
        return self._sampler.hw_status()

    @Slot()
    def acknowledge(self) -> None:
        self._sampler.acknowledge()

    def stop(self) -> None:
        self._sampler.stop()


class WindowsLogo(QQuickImageProvider):
    """`image://icon/<name>` for ThemeIcon, which has no Kirigami here.

    The only theme icon the monitor asks for on its own is the OS logo; on
    Windows that is the four panes, drawn at the size requested so it stays
    sharp at any scale.
    """

    PANES = ((0, 0), (1, 0), (0, 1), (1, 1))

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(self, name, size, requested):
        side = max(16, requested.width() if requested.width() > 0 else 64)
        image = QImage(side, side, QImage.Format.Format_ARGB32_Premultiplied)
        image.fill(Qt.GlobalColor.transparent)
        painter = QPainter(image)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor("#4cc2ff"))
        gap = max(1, side // 16)
        pane = (side - gap) // 2
        for column, row in self.PANES:
            painter.drawRect(column * (pane + gap), row * (pane + gap), pane, pane)
        painter.end()
        size.setWidth(side)
        size.setHeight(side)
        return image


def _cache_pipelines(window: QQuickWindow, path: Path) -> None:
    """Keep the window's compiled shaders on disk between runs."""
    configuration = window.graphicsConfiguration()
    configuration.setPipelineCacheLoadFile(str(path))
    configuration.setPipelineCacheSaveFile(str(path))
    window.setGraphicsConfiguration(configuration)


def _qml_value(root, name: str):
    """A QML `var` property as Python data (it arrives as a QJSValue)."""
    value = root.property(name)
    return value.toVariant() if isinstance(value, QJSValue) else value


def _pin_to_bottom(view: QQuickView) -> None:
    """Re-park the window below every other top-level window.

    Qt's WindowStaysOnBottomHint sets the style once; Windows restacks
    HWND_BOTTOM windows above newly created ones, so it is reasserted.
    """
    if sys.platform != "win32":
        return
    import ctypes
    from ctypes import wintypes

    # HWND is pointer-sized; ctypes otherwise converts it to a 32-bit int.
    set_window_pos = ctypes.windll.user32.SetWindowPos
    set_window_pos.argtypes = [
        wintypes.HWND,
        wintypes.HWND,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        wintypes.UINT,
    ]
    set_window_pos.restype = wintypes.BOOL

    HWND_BOTTOM, SWP_NOSIZE, SWP_NOMOVE, SWP_NOACTIVATE = 1, 0x0001, 0x0002, 0x0010
    set_window_pos(
        int(view.winId()),
        HWND_BOTTOM,
        0,
        0,
        0,
        0,
        SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE,
    )


PINNED_FLAGS = (
    Qt.WindowType.FramelessWindowHint
    | Qt.WindowType.Tool
    | Qt.WindowType.WindowDoesNotAcceptFocus
)
# A normal window with a title bar, so Windows itself provides dragging, edge
# resizing and snapping; on top, so it is not lost behind what it overlays.
ADJUST_FLAGS = Qt.WindowType.Window | Qt.WindowType.WindowStaysOnTopHint


class Placement:
    """Where the card sits: pinned to the desktop, or being moved/resized.

    By default the window goes where Monitor.qml's cardRect says (the
    settings' placement), above or behind windows per `desktopLayer`.
    Move / resize hands the geometry back to the settings (`placed`), so it
    survives restarts and the settings studio shows it.
    """

    def __init__(self, view: QQuickView, app: QApplication, store: SettingsStore):
        self.view = view
        self.app = app
        self.store = store
        self.root = view.rootObject()
        self.adjusting = False
        self.changed = lambda: None

    def _rect(self) -> QRect:
        rect = _qml_value(self.root, "cardRect") or {}
        return QRect(
            int(rect.get("x", 0)),
            int(rect.get("y", 0)),
            max(120, int(rect.get("width", 320))),
            max(80, int(rect.get("height", 240))),
        )

    def _behind(self) -> bool:
        configuration = _qml_value(self.root, "configuration") or {}
        return bool(configuration.get("desktopLayer", True))

    def _pinned_flags(self):
        return PINNED_FLAGS | (
            Qt.WindowType.WindowStaysOnBottomHint
            if self._behind()
            else Qt.WindowType.WindowStaysOnTopHint
        )

    def refresh(self) -> None:
        """Follow a settings change (placement, size, layer) while pinned."""
        if self.adjusting or not self.view.isVisible():
            return
        if self.view.flags() != self._pinned_flags():
            self.pin()
        else:
            self.view.setGeometry(self._rect())

    def _finish_adjusting(self) -> None:
        if self.adjusting:
            self.remember()
        self.adjusting = False

    def _reachable(self, geometry: QRect) -> QRect:
        """Room for the title bar and resize edges Move/resize adds."""
        screen = self.view.screen() or self.app.primaryScreen()
        area = screen.availableGeometry().adjusted(8, 40, -8, -8)
        if geometry.width() >= area.width() or geometry.height() >= area.height():
            size = QSize(area.width() * 3 // 5, area.height() * 2 // 5)
            geometry = QRect(QPoint(0, 0), size)
            geometry.moveCenter(area.center())
            return geometry
        geometry = QRect(geometry)
        geometry.moveLeft(
            max(area.left(), min(geometry.left(), area.right() - geometry.width()))
        )
        geometry.moveTop(
            max(area.top(), min(geometry.top(), area.bottom() - geometry.height()))
        )
        return geometry

    def toggle_visible(self) -> None:
        if self.view.isVisible():
            self._finish_adjusting()
            self.view.hide()
            self.root.setProperty("shown", False)
            self.changed()
        else:
            # Through pin(), not a bare show(): showing raises the window to
            # the top of the Z-order, over everything it is meant to sit under.
            self.pin()

    def pin(self) -> None:
        self._finish_adjusting()
        geometry = self._rect()
        # Flags only take effect on a hidden window.
        self.view.hide()
        self.view.setFlags(self._pinned_flags())
        self.view.setTitle("")
        self.view.setColor(QColor(Qt.GlobalColor.transparent))
        self.view.setGeometry(geometry)
        self.view.show()
        self.root.setProperty("shown", True)
        self.restack()
        self.changed()

    def adjust(self) -> None:
        self.adjusting = True
        geometry = self._reachable(self.view.geometry())
        self.view.hide()
        self.view.setFlags(ADJUST_FLAGS)
        self.view.setTitle(
            "Glassy System Monitor — drag, resize, then close (×) or Enter to lock"
        )
        # Tinted, so the window's extent is visible against a busy desktop.
        self.view.setColor(QColor(20, 20, 30, 140))
        self.view.setGeometry(geometry)
        self.view.show()
        self.view.requestActivate()
        self.changed()

    def remember(self) -> None:
        """Keep the current geometry in the settings."""
        g = self.view.geometry()
        self.store.placed.emit(g.x(), g.y(), g.width(), g.height())

    def reset(self) -> None:
        """Back to the settings' placement, dropping the hand-placed one."""
        self.adjusting = False
        self.store.placementReset.emit()
        self.pin()

    def restack(self) -> None:
        if not self.adjusting and self._behind():
            _pin_to_bottom(self.view)


class OverlayEvents(QObject):
    """Right-click menu, middle-button drag, and ways out of Move/resize."""

    def __init__(self, menu: QMenu, placement: Placement):
        super().__init__()
        self.menu = menu
        self.placement = placement
        self._grab: QPoint | None = None

    def eventFilter(self, watched, event) -> bool:
        kind = event.type()
        if (
            kind == QEvent.Type.MouseButtonPress
            and event.button() == Qt.MouseButton.RightButton
        ):
            self.menu.popup(QCursor.pos())
            return True
        # Hold the middle button to drag the card anywhere — the quick way,
        # without Move / resize. Left clicks stay with the card.
        if (
            kind == QEvent.Type.MouseButtonPress
            and event.button() == Qt.MouseButton.MiddleButton
        ):
            self._grab = event.globalPosition().toPoint() - watched.position()
            return True
        if kind == QEvent.Type.MouseMove and self._grab is not None:
            watched.setPosition(event.globalPosition().toPoint() - self._grab)
            return True
        if (
            kind == QEvent.Type.MouseButtonRelease
            and event.button() == Qt.MouseButton.MiddleButton
            and self._grab is not None
        ):
            self._grab = None
            if not self.placement.adjusting:
                self.placement.remember()
            return True
        if not self.placement.adjusting:
            return False
        # The title bar's × would otherwise hide the card with no obvious way
        # back; while adjusting it means "done", as Enter and Esc do.
        if kind == QEvent.Type.Close or (
            kind == QEvent.Type.KeyPress
            and event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter, Qt.Key.Key_Escape)
        ):
            event.ignore()
            QTimer.singleShot(0, self.placement.pin)
            return True
        return False


# MonitorCore tries its KDE sensor backend first, and ThemeIcon tries Kirigami;
# both fall back when the module is missing, which on Windows is the normal path.
EXPECTED_WARNINGS = (
    'module "org.kde.ksysguard.sensors" is not installed',
    'module "org.kde.kirigami" is not installed',
)


def expected_warning(text: str) -> bool:
    return any(known in text for known in EXPECTED_WARNINGS)


def selftest_sampler() -> int:
    """One real round of readings from every collector."""
    collector = sampling.Collector()
    everything = frozenset(
        "cpu memory network disk storage processes load system power sensors gpu".split()
    )
    time.sleep(1.1)
    collector.collect(everything, {})
    time.sleep(1.1)
    readings = collector.collect(everything, {})
    missing = [k for k in ("cpu", "memTotal", "ifaceRates", "diskRates") if k not in readings]
    for key, value in readings.items():
        text = repr(value)
        print(f"{key}: {text[:100]}{'…' if len(text) > 100 else ''}")
    if missing:
        print("missing:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


SOAK_SETTINGS = (
    '{"sections": "cpu,memory,network,disk,storage,processes,load,gpu,system,ping,power,sensors,fans,containers",'
    ' "updateInterval": 250, "pingInterval": 1, "processCount": 8}'
)


def main(argv: list[str]) -> int:
    if "--selftest-sampler" in argv:
        return selftest_sampler()

    selftest = "--selftest" in argv
    soak = int(argv[argv.index("--soak") + 1]) if "--soak" in argv else 0
    headless = selftest or soak

    app = QApplication(argv)
    app.setQuitOnLastWindowClosed(False)
    app.setWindowIcon(QIcon(str(ROOT / "package" / "icon.png")))

    warnings = []
    view = QQuickView()
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)
    view.engine().warnings.connect(lambda errors: warnings.extend(errors))
    # The engine owns the provider once added; keep a name for it regardless.
    logo_provider = WindowsLogo()
    view.engine().addImageProvider("icon", logo_provider)
    store = SettingsStore()
    # --selftest must not depend on the machine it runs on: a bridge that
    # never measures.
    prefs = HostPrefs()
    bridge = SamplerBridge(enabled=not selftest, hw_sensors=prefs.hw_sensors or bool(soak))

    view.setInitialProperties(
        {
            "defaultsXml": (
                ROOT / "package" / "contents" / "config" / "main.xml"
            ).read_text(encoding="utf-8"),
            "settingsJson": SOAK_SETTINGS if soak else settings_json(),
            "sampler": bridge,
            "host": store,
        }
    )
    view.setSource(QUrl.fromLocalFile(str(ROOT / "windows" / "qml" / "Monitor.qml")))

    if selftest:
        # Open the settings window too: it loads the whole shared studio.
        if view.status() == QQuickView.Status.Ready:
            view.rootObject().setProperty("settingsOpen", True)
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                app.processEvents()
                time.sleep(0.01)
        warnings = [w for w in warnings if not expected_warning(w.toString())]
        ok = (
            view.status() == QQuickView.Status.Ready
            and not warnings
            and not view.errors()
        )
        for error in view.errors():
            print(error.toString(), file=sys.stderr)
        for warning in warnings:
            print(warning.toString(), file=sys.stderr)
        return 0 if ok else 1

    if view.errors():
        for error in view.errors():
            print(error.toString(), file=sys.stderr)
        return 1

    root = view.rootObject()
    cache_dir = local_dir()
    _cache_pipelines(view, cache_dir / "card.pipelines")
    _cache_pipelines(
        root.findChild(QQuickWindow, "settingsWindow"),
        cache_dir / "settings.pipelines",
    )

    placement = Placement(view, app, store)
    placement.pin()
    root.cardRectChanged.connect(placement.refresh)
    root.configurationChanged.connect(placement.refresh)
    restack = QTimer(view)
    restack.timeout.connect(placement.restack)
    restack.start(2000)

    if soak:
        return run_soak(app, view, root, bridge, soak, warnings)

    if "--shot" in argv:
        path = argv[argv.index("--shot") + 1]

        def shoot() -> None:
            view.grabWindow().save(path)
            app.quit()

        QTimer.singleShot(4000, shoot)
        try:
            app.exec()
        finally:
            bridge.stop()
        return 0

    tray = QSystemTrayIcon()
    tray.setIcon(QIcon(str(ROOT / "package" / "icon.png")))
    tray.setToolTip("Glassy System Monitor")

    menu = QMenu()
    toggle_action = menu.addAction("Hide")
    toggle_action.triggered.connect(placement.toggle_visible)
    adjust_action = menu.addAction("Move / resize…")
    adjust_action.triggered.connect(
        lambda: placement.pin() if placement.adjusting else placement.adjust()
    )

    def update_menu() -> None:
        toggle_action.setText("Hide" if view.isVisible() else "Show")
        adjust_action.setText(
            "Lock in place" if placement.adjusting else "Move / resize…"
        )

    placement.changed = update_menu
    menu.aboutToShow.connect(update_menu)
    # Left-clicking the tray icon toggles, so a hidden card is one click away.
    tray.activated.connect(
        lambda reason: (
            placement.toggle_visible()
            if reason == QSystemTrayIcon.ActivationReason.Trigger
            else None
        )
    )
    reset_action = menu.addAction("Reset position")
    reset_action.triggered.connect(placement.reset)

    hw_action = menu.addAction("Hardware sensors (needs administrator)")
    hw_action.setCheckable(True)
    hw_action.setChecked(prefs.hw_sensors)
    hw_status_action = menu.addAction("")
    hw_status_action.setEnabled(False)

    def hw_status_text() -> str:
        status = bridge.hw_status()
        return {
            "off": "",
            "ok": "   Sensors: reading (LibreHardwareMonitor)",
            "limited": "   Sensors: limited — not running as administrator",
            "no-sensors": "   Sensors: none found — install the PawnIO driver (winget install PawnIO)",
            "missing-package": "   Sensors: the HardwareMonitor package is missing",
            "unsupported": "   Sensors: Windows only",
        }.get(status, f"   Sensors: {status}")

    def set_hw(enabled: bool) -> None:
        prefs.set_hw_sensors(enabled)
        bridge.set_hw_sensors(enabled)
        hw_action.setChecked(enabled)

    def toggle_hw(checked: bool) -> None:
        if not checked:
            set_hw(False)
            return
        if not sampling.hardware_package_installed():
            QMessageBox.warning(
                None,
                "Hardware sensors",
                "The HardwareMonitor package is not installed.\n\n"
                "Install it with:  pip install HardwareMonitor\n"
                "(the packaged .exe includes it).",
            )
            hw_action.setChecked(False)
            return
        if sampling.is_admin():
            set_hw(True)
            return
        box = QMessageBox(
            QMessageBox.Icon.Warning,
            "Hardware sensors need administrator rights",
            "Reading CPU and board temperatures, fans and power loads a "
            "driver, which Windows only allows an administrator to do.\n\n"
            "GPU load, memory and the basic thermal zones already work "
            "without it.\n\nRestart the monitor as administrator?",
        )
        restart = box.addButton("Restart as administrator", QMessageBox.ButtonRole.AcceptRole)
        limited = box.addButton("Turn on anyway (limited)", QMessageBox.ButtonRole.ActionRole)
        box.addButton(QMessageBox.StandardButton.Cancel)
        box.exec()
        clicked = box.clickedButton()
        if clicked is restart:
            set_hw(True)
            if relaunch_as_admin():
                app.quit()
            else:
                set_hw(False)  # the UAC prompt was declined
        elif clicked is limited:
            set_hw(True)
        else:
            hw_action.setChecked(False)

    hw_action.toggled.connect(lambda checked: toggle_hw(checked) if checked != prefs.hw_sensors else None)
    menu.aboutToShow.connect(lambda: hw_status_action.setText(hw_status_text()))
    settings_action = menu.addAction("Settings…")
    settings_action.triggered.connect(lambda: root.setProperty("settingsOpen", True))
    menu.addSeparator()
    quit_action = menu.addAction("Quit")
    quit_action.triggered.connect(app.quit)
    tray.setContextMenu(menu)
    tray.show()
    overlay_events = OverlayEvents(menu, placement)
    view.installEventFilter(overlay_events)

    try:
        return app.exec()
    finally:
        tray.hide()
        bridge.stop()


def run_soak(app, view, root, bridge, seconds: int, warnings: list) -> int:
    """Run every section at a fast pace and compare memory early vs late.

    The first third is warm-up (caches, JIT, the first process snapshot); the
    check is the growth from the end of it to the end of the run. Exits 1 on
    growth beyond what a steady state explains, or on any QML warning.
    """
    import psutil

    me = psutil.Process()
    samples: list[tuple[float, int]] = []
    started = time.monotonic()

    def note() -> None:
        samples.append((time.monotonic() - started, me.memory_info().rss))
        print(
            f"{samples[-1][0]:6.0f}s  rss {samples[-1][1] / 1048576:8.1f} MiB  "
            f"threads {me.num_threads()}  handles {me.num_handles()}",
            flush=True,
        )

    ticker = QTimer()
    ticker.timeout.connect(note)
    ticker.start(max(1000, seconds * 1000 // 24))
    QTimer.singleShot(seconds * 1000, app.quit)
    app.exec()
    bridge.stop()
    note()

    core = root.findChild(QObject, "core")
    arrived = {
        name: len(_qml_value(core, name) or [])
        for name in (
            "cpuHistory",
            "memHistory",
            "dlHistory",
            "diskReadHistory",
            "processes",
            "storage",
            "interfaces",
            "load1History",
            "histories",
            "gpuHistory",
        )
    }
    arrived["containerInfo"] = len((_qml_value(core, "containerInfo") or {}).get("list", []))
    arrived["hwSensors"] = len(_qml_value(core, "hardwareSensors") or [])
    print("arrived:", arrived)
    # Containers need a docker/podman on this machine and hardware sensors an
    # admin session with the driver: absent ones are reported, not failures.
    optional = {"containerInfo", "hwSensors"}
    starved = [name for name, count in arrived.items() if count == 0 and name not in optional]
    if starved:
        print("no data reached:", ", ".join(starved), file=sys.stderr)

    warm = [s for s in samples if s[0] >= seconds / 3]
    growth = (warm[-1][1] - warm[0][1]) / 1048576 if len(warm) > 1 else 0.0
    peak_growth = (max(r for _, r in warm) - warm[0][1]) / 1048576 if warm else 0.0
    print(f"growth after warm-up: {growth:+.1f} MiB (peak {peak_growth:+.1f} MiB)")
    warnings = [w for w in warnings if not expected_warning(w.toString())]
    for warning in warnings:
        print(warning.toString(), file=sys.stderr)
    # A steady monitor wobbles by a few MiB as the GC and Qt's allocator
    # settle; sustained leaks show up as a straight line far above that.
    limit = float(os.environ.get("GLASSY_SOAK_LIMIT_MIB", "15"))
    return 1 if growth > limit or warnings or starved else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
