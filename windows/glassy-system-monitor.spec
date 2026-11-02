# PyInstaller spec for the Windows monitor. From the repository root:
#
#   pip install -r windows/requirements.txt pyinstaller
#   pyinstaller --noconfirm windows/glassy-system-monitor.spec
#
# Produces dist/Glassy System Monitor/Glassy System Monitor.exe (one folder:
# starts faster than a one-file build, which unpacks itself on every launch).
#
# Monitor.qml imports the shared render tree by relative path, so package/ and
# hyprland/ keep their layout relative to windows/qml inside the bundle —
# app.py resolves them from _MEIPASS.

import os

from PyInstaller.utils.hooks import collect_all

ROOT = os.path.abspath(os.path.join(SPECPATH, ".."))  # noqa: F821 — set by PyInstaller

datas = [
    (os.path.join(ROOT, "windows", "qml"), os.path.join("windows", "qml")),
    # The whole widget package: QML, the JS the QML imports, shaders, and
    # main.xml, which app.py reads for the configuration defaults.
    (os.path.join(ROOT, "package", "contents"), os.path.join("package", "contents")),
    (os.path.join(ROOT, "package", "icon.png"), "package"),
    # The settings parser and the settings window (plain QtQuick around the
    # shared studio); the rest of hyprland/ is Quickshell-only.
    (os.path.join(ROOT, "hyprland", "Configuration.js"), "hyprland"),
    (os.path.join(ROOT, "hyprland", "SettingsPage.qml"), "hyprland"),
]

binaries = []
hiddenimports = ["sampler", "pdh", "hwsensors", "psutil"]
# The opt-in sensor library: its LibreHardwareMonitor DLLs and the .NET bridge
# (pythonnet / clr_loader) load by file at run time, which PyInstaller cannot see.
for package in ("HardwareMonitor", "pythonnet", "clr_loader"):
    try:
        found_datas, found_binaries, found_hidden = collect_all(package)
    except Exception:
        continue
    datas += found_datas
    binaries += found_binaries
    hiddenimports += found_hidden

a = Analysis(  # noqa: F821
    [os.path.join(ROOT, "windows", "app.py")],
    pathex=[os.path.join(ROOT, "windows")],
    binaries=binaries,
    hiddenimports=hiddenimports,
    datas=datas,
    excludes=["tkinter"],
)
pyz = PYZ(a.pure)  # noqa: F821
exe = EXE(  # noqa: F821
    pyz,
    a.scripts,
    # UTF-8 mode: without it Windows' default text encoding is the ANSI code
    # page (cp1252), for open() and subprocess output alike.
    [("X utf8", None, "OPTION")],
    exclude_binaries=True,
    name="Glassy System Monitor",
    console=False,
    icon=os.path.join(ROOT, "package", "icon.png"),
)
coll = COLLECT(exe, a.binaries, a.datas, name="Glassy System Monitor")  # noqa: F821
