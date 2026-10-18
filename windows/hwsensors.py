"""Real CPU / board / drive temperatures, fans and power, through
LibreHardwareMonitor (the `HardwareMonitor` package, which bundles its DLL).

Opt-in and off by default: reading those sensors loads a kernel driver, which
Windows only allows an administrator to do. Without elevation LibreHardwareMonitor
still opens and returns a few readings, which is the "limited" status. On recent
versions CPU sensors also want the PawnIO driver (`winget install PawnIO`);
that shows up here as "no-sensors".

Everything not needing admin (GPU load, memory, ACPI zones) is read elsewhere
(sampler.py) so the default install never touches any of this.

Open and read on the same pool thread are not required by the library, but one
job at a time is guaranteed by the sampler. `close()` releases the driver.
"""

import ctypes
import re
import sys


def _admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except (AttributeError, OSError):
        return False


_SKIP_TEMP = re.compile(r"max|average|distance|tjmax", re.I)
_CORE_N = re.compile(r"^CPU Core #(\d+)$")


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "chip"


def _cpu_temp_label(name: str) -> str:
    if name == "CPU Package":
        return "Package id 0"
    match = _CORE_N.match(name)
    if match:
        # MonitorCore's "Cores" aggregate keys on "Core <n>", counted from 0.
        return f"Core {int(match.group(1)) - 1}"
    if name.startswith("Core (Tctl"):
        return "Tctl"
    if name.startswith("CPU "):
        return name[4:]
    return name


class HardwareSensors:
    def __init__(self) -> None:
        self._computer = None
        # off | unsupported | missing-package | error: … | ok | limited | no-sensors
        self.status = "off"

    def open(self) -> str:
        if sys.platform != "win32":
            self.status = "unsupported"
            return self.status
        try:
            from HardwareMonitor.Hardware import Computer
        except Exception:  # package or its .NET runtime missing
            self.status = "missing-package"
            return self.status
        try:
            computer = Computer()
            computer.IsCpuEnabled = True
            computer.IsGpuEnabled = True
            computer.IsMotherboardEnabled = True
            computer.IsStorageEnabled = True
            computer.IsControllerEnabled = True
            computer.Open()
        except Exception as error:
            self.status = f"error: {type(error).__name__}: {error}"
            return self.status
        self._computer = computer
        self.status = "ok" if _admin() else "limited"
        return self.status

    def close(self) -> None:
        computer, self._computer = self._computer, None
        if computer is not None:
            try:
                computer.Close()
            except Exception:
                pass
        if self.status in ("ok", "limited", "no-sensors"):
            self.status = "off"

    # ── reading ──────────────────────────────────────────────────────────────
    def read(self) -> dict:
        """{groups, fans, power, gpu} from one pass over every device."""
        out = {"groups": [], "fans": [], "power": [], "gpu": None}
        if self._computer is None:
            return out
        for hardware in self._computer.Hardware:
            self._visit(hardware, out)
        if self.status == "ok" and not out["groups"]:
            self.status = "no-sensors"
        elif self.status == "no-sensors" and out["groups"]:
            self.status = "ok"
        return out

    def _visit(self, hardware, out: dict) -> None:
        hardware.Update()
        kind = str(hardware.HardwareType)
        name = str(hardware.Name)
        sensors = [(str(s.SensorType), str(s.Name), s.Value) for s in hardware.Sensors if s.Value is not None]
        if kind == "Cpu":
            self._cpu(name, sensors, out)
        elif kind.startswith("Gpu"):
            self._gpu(kind, name, sensors, out)
        elif kind == "Storage":
            self._storage(name, sensors, out)
        elif kind in ("Motherboard", "SuperIO", "EmbeddedController", "Cooler"):
            self._board(name, sensors, out)
        for sub in hardware.SubHardware:
            self._visit(sub, out)

    @staticmethod
    def _group(chip: str, display: str, sensors: list, crit: float, out: dict) -> None:
        temps = [s["value"] for s in sensors if s["type"] == "temp"]
        if not sensors:
            return
        out["groups"].append(
            {
                "chip": chip,
                "chipDisplay": display,
                "maxTemp": max(temps) if temps else 0,
                "maxTempCrit": crit if temps else 0,
                "sensors": sensors,
            }
        )

    def _cpu(self, name: str, sensors: list, out: dict) -> None:
        amd = "amd" in name.lower()
        chip = "k10temp" if amd else "coretemp"
        found = []
        for kind, label, value in sensors:
            if kind == "Temperature" and not _SKIP_TEMP.search(label):
                found.append({"label": _cpu_temp_label(label), "value": float(value), "crit": 100.0, "type": "temp"})
            elif kind == "Power" and label == "CPU Package" and value > 0:
                out["power"].append({"id": "lhm:cpu", "label": "CPU package", "kind": "cpu", "watts": float(value)})
        self._group(chip, "CPU (AMD)" if amd else "CPU (Intel)", found, 100.0, out)

    def _gpu(self, kind: str, name: str, sensors: list, out: dict) -> None:
        vendor, chip, display = {
            "GpuNvidia": ("nvidia", "nvidia", "GPU (NVIDIA)"),
            "GpuAmd": ("amd", "amdgpu", "GPU (AMD)"),
            "GpuIntel": ("intel", "i915", "GPU (Intel)"),
        }.get(kind, ("", "gpu", "GPU"))
        found = []
        gpu = {"vendor": vendor, "name": name}
        used = total = None
        for stype, label, value in sensors:
            if stype == "Temperature":
                nice = {"GPU Core": "edge", "GPU Hot Spot": "Hot spot", "GPU Memory Junction": "Memory"}.get(label, label)
                found.append({"label": nice, "value": float(value), "crit": 100.0, "type": "temp"})
            elif stype == "Fan" and value >= 0:
                found.append({"label": label.replace("GPU ", "").lower() or "fan", "value": float(value), "type": "fan"})
            elif stype == "Power" and label in ("GPU Package", "GPU Power") and value > 0:
                out["power"].append({"id": f"lhm:{chip}", "label": display, "kind": "gpu", "watts": float(value)})
            elif stype == "Load" and label == "GPU Core":
                gpu["percent"] = float(value)
            elif stype == "Clock" and label == "GPU Core":
                gpu["freqMhz"] = int(value)
            elif stype in ("SmallData", "Data") and label == "GPU Memory Used":
                used = float(value)
            elif stype in ("SmallData", "Data") and label == "GPU Memory Total":
                total = float(value)
        if used is not None:
            gpu["vramUsed"] = used * 1024 * 1024
        if total is not None:
            gpu["vramTotal"] = total * 1024 * 1024
        temps = [s for s in found if s["type"] == "temp"]
        if temps:
            gpu["tempC"] = max(s["value"] for s in temps)
        for s in found:
            if s["type"] == "fan":
                out["fans"].append({"key": f"{chip}:{s['label']}", "chip": display, "label": s["label"], "rpm": int(s["value"]), "max": 0})
        self._group(chip, display, found, 100.0, out)
        # The first GPU is the one the section shows.
        if out["gpu"] is None:
            out["gpu"] = gpu

    def _storage(self, name: str, sensors: list, out: dict) -> None:
        nvme = "nvme" in name.lower() or "ssd" in name.lower()
        found = [
            {"label": "Composite" if label == "Temperature" else label, "value": float(value), "crit": 85.0, "type": "temp"}
            for kind, label, value in sensors
            if kind == "Temperature"
        ]
        self._group("nvme" if nvme else "drivetemp", name, found, 85.0, out)

    def _board(self, name: str, sensors: list, out: dict) -> None:
        chip = _slug(name)
        found = []
        for kind, label, value in sensors:
            if kind == "Temperature":
                found.append({"label": label, "value": float(value), "crit": 100.0, "type": "temp"})
            elif kind == "Fan" and value > 0:
                found.append({"label": label, "value": float(value), "type": "fan"})
                out["fans"].append({"key": f"{chip}:{label}", "chip": name, "label": label, "rpm": int(value), "max": 0})
        self._group(chip, name, found, 100.0, out)
