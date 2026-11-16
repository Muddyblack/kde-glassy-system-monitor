"""LibreHardwareMonitor readings → the groups / fans / power / gpu MonitorCore
takes, checked with stand-in hardware objects (no driver, no admin).

  python -m pytest tests/windows        or        python tests/windows/test_hwsensors.py
"""

import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "windows"))

import hwsensors  # noqa: E402


def sensor(kind, name, value):
    return SimpleNamespace(SensorType=kind, Name=name, Value=value)


def device(kind, name, sensors, sub=()):
    return SimpleNamespace(
        HardwareType=kind,
        Name=name,
        Sensors=sensors,
        SubHardware=list(sub),
        Update=lambda: None,
    )


def read(*devices):
    reader = hwsensors.HardwareSensors()
    reader._computer = SimpleNamespace(Hardware=list(devices))
    reader.status = "ok"
    return reader.read()


def test_intel_cpu_cores_package_and_power():
    out = read(
        device(
            "Cpu",
            "13th Gen Intel Core i5-13420H",
            [
                sensor("Temperature", "CPU Package", 61.0),
                sensor("Temperature", "CPU Core #1", 55.0),
                sensor("Temperature", "CPU Core #2", 58.0),
                sensor("Temperature", "Core Max", 58.0),
                sensor("Temperature", "Core Average", 56.0),
                sensor("Power", "CPU Package", 14.2),
                sensor("Load", "CPU Total", 20.0),
            ],
        )
    )
    (group,) = out["groups"]
    assert group["chip"] == "coretemp" and group["chipDisplay"] == "CPU (Intel)"
    assert [s["label"] for s in group["sensors"]] == ["Package id 0", "Core 0", "Core 1"]
    assert group["maxTemp"] == 61.0
    assert out["power"] == [{"id": "lhm:cpu", "label": "CPU package", "kind": "cpu", "watts": 14.2}]


def test_amd_cpu_uses_k10temp_and_tctl():
    out = read(device("Cpu", "AMD Ryzen 7 7800X3D", [sensor("Temperature", "Core (Tctl/Tdie)", 48.0)]))
    (group,) = out["groups"]
    assert group["chip"] == "k10temp"
    assert group["sensors"][0]["label"] == "Tctl"


def test_gpu_temps_fan_power_and_reading():
    out = read(
        device(
            "GpuNvidia",
            "NVIDIA GeForce RTX 4070",
            [
                sensor("Temperature", "GPU Core", 52.0),
                sensor("Temperature", "GPU Hot Spot", 61.0),
                sensor("Fan", "GPU Fan", 1180.0),
                sensor("Power", "GPU Package", 33.0),
                sensor("Load", "GPU Core", 17.0),
                sensor("Clock", "GPU Core", 1950.0),
                sensor("SmallData", "GPU Memory Used", 2048.0),
                sensor("SmallData", "GPU Memory Total", 12282.0),
            ],
        )
    )
    (group,) = out["groups"]
    assert group["chip"] == "nvidia"
    assert {s["label"] for s in group["sensors"] if s["type"] == "temp"} == {"edge", "Hot spot"}
    assert out["fans"][0]["rpm"] == 1180
    assert out["power"][0]["kind"] == "gpu"
    gpu = out["gpu"]
    assert gpu["percent"] == 17.0 and gpu["freqMhz"] == 1950 and gpu["tempC"] == 61.0
    assert gpu["vramUsed"] == 2048 * 1024 * 1024


def test_board_sub_hardware_fans_and_storage_temp():
    chip = device(
        "SuperIO",
        "Nuvoton NCT6798D",
        [sensor("Temperature", "CPU Socket", 40.0), sensor("Fan", "Fan #1", 900.0), sensor("Fan", "Fan #2", 0.0)],
    )
    out = read(
        device("Motherboard", "ASUS PRIME B650", [], sub=[chip]),
        device("Storage", "Samsung SSD 980 PRO", [sensor("Temperature", "Temperature", 38.0)]),
    )
    chips = {g["chip"]: g for g in out["groups"]}
    assert "nuvoton-nct6798d" in chips
    assert chips["nvme"]["sensors"][0]["label"] == "Composite"
    # A header at 0 RPM is not listed; the feeder decides by history.
    assert [f["label"] for f in out["fans"]] == ["Fan #1"]


def test_no_sensors_reported_without_the_driver():
    reader = hwsensors.HardwareSensors()
    reader._computer = SimpleNamespace(Hardware=[device("Cpu", "Intel", [sensor("Load", "CPU Total", 5.0)])])
    reader.status = "ok"
    reader.read()
    assert reader.status == "no-sensors"


if __name__ == "__main__":
    for name, test in list(globals().items()):
        if name.startswith("test_"):
            test()
            print("ok", name)
