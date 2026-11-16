"""Windows readings for the Glassy System Monitor, replacing the /proc probes.

On Linux MonitorCore runs shell commands (`cat /proc/stat`, `df`, `ip`, …) and
parses their text. None of that exists on Windows, so a MonitorCore started
with `live: false` is fed finished values instead, through the same sample
functions DemoFeeder uses (windows/qml/WindowsFeeder.qml applies them).

`Collector` does the measuring and has no Qt in it, so tests and --selftest run
it anywhere; `Sampler` is the QObject that runs it on one worker thread.

Memory discipline (this runs for weeks):
  * every cycle builds fresh dicts and keeps only the previous raw counters,
    keyed by device / pid, and each of those is rebuilt from what is alive now,
    so nothing accumulates as processes and interfaces come and go;
  * histories live in MonitorCore (capped by historySize), never here;
  * at most one sample is in flight towards the UI: the worker waits for
    `acknowledge()` before sending the next, so a stalled UI cannot make the
    Qt event queue grow;
  * child processes (ping, nvidia-smi, docker, kubectl) have a hard timeout,
    are killed on it, and never open a console window;
  * slow work (those children, hardware sensors) runs on two pool threads, one
    job per kind at a time, so it can neither stall the fast readings nor
    pile up; the PDH query and the sensor library are closed on stop.

Privileges: everything here works as a normal user (CPU, memory, network,
disk, GPU load and memory for any vendor through the same performance
counters Task Manager reads, ACPI thermal zones, nvidia-smi extras,
containers). Real CPU / board temperatures, fans and power need a kernel
driver and so administrator rights: that is the opt-in `hwSensors` option
(LibreHardwareMonitor through the HardwareMonitor package), off by default.
"""

import ctypes
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
from concurrent.futures import Future, ThreadPoolExecutor

import psutil

try:
    import pdh
except ImportError:  # pragma: no cover - always present next to this file
    pdh = None

# No flashing console for ping.exe / nvidia-smi when frozen without a console.
_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)

# Sections whose readings cost something: only sampled while shown.
ALWAYS = frozenset()


def _run(args: list[str], timeout: float, merge_errors: bool = False, env: dict | None = None) -> str:
    """stdout of a command, or "" if it fails, hangs or is missing.

    `merge_errors` adds stderr to the text, for commands whose complaint
    ("Cannot connect to the Docker daemon") is worth showing.
    """
    try:
        done = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT if merge_errors else subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            creationflags=_NO_WINDOW,
            stdin=subprocess.DEVNULL,
            env=env,
        )
    except (OSError, subprocess.SubprocessError):
        # TimeoutExpired kills the child before it propagates.
        return ""
    return done.stdout or ""


def is_admin() -> bool:
    try:
        return bool(ctypes.windll.shell32.IsUserAnAdmin())
    except (AttributeError, OSError):
        return False


def hardware_package_installed() -> bool:
    import importlib.util

    try:
        return importlib.util.find_spec("HardwareMonitor") is not None
    except (ImportError, ValueError):
        return False


# ── GPU (performance counters; any vendor, no admin) ─────────────────────────
_ENGINE_RE = re.compile(r"luid_(0x[0-9a-f]+_0x[0-9a-f]+)_phys_(\d+).*engtype_(\w+)", re.I)
_ADAPTER_RE = re.compile(r"luid_(0x[0-9a-f]+_0x[0-9a-f]+)_phys_(\d+)", re.I)
_VIDEO_CLASS = r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"


def _vendor_of(name: str) -> str:
    lowered = name.lower()
    if "nvidia" in lowered or "geforce" in lowered or "quadro" in lowered:
        return "nvidia"
    if "amd" in lowered or "radeon" in lowered or "ati " in lowered:
        return "amd"
    if "intel" in lowered:
        return "intel"
    return ""


def video_adapters() -> list[dict]:
    """Installed display adapters: name, vendor, dedicated memory in bytes."""
    if sys.platform != "win32":
        return []
    import winreg

    found = []
    try:
        base = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, _VIDEO_CLASS)
    except OSError:
        return []
    with base:
        index = 0
        while True:
            try:
                sub = winreg.EnumKey(base, index)
            except OSError:
                break
            index += 1
            if not sub.isdigit():
                continue
            try:
                with winreg.OpenKey(base, sub) as key:
                    name = str(winreg.QueryValueEx(key, "DriverDesc")[0])
                    memory = 0
                    for value in ("HardwareInformation.qwMemorySize", "HardwareInformation.MemorySize"):
                        try:
                            raw = winreg.QueryValueEx(key, value)[0]
                        except OSError:
                            continue
                        if isinstance(raw, (bytes, bytearray)):
                            raw = int.from_bytes(raw[:8], "little")
                        memory = max(memory, int(raw))
            except OSError:
                continue
            found.append({"name": name, "vendor": _vendor_of(name), "memory": memory})
    # The biggest dedicated memory first: that is the card a game would use.
    found.sort(key=lambda a: a["memory"], reverse=True)
    return found


def _uptime_text(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, rest = divmod(seconds, 86400)
    hours, rest = divmod(rest, 3600)
    minutes = rest // 60
    if days:
        return f"{days}d {hours}h {minutes}m"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def _windows_name() -> tuple[str, str, str]:
    """(product name, display version, build) from the registry."""
    if sys.platform != "win32":
        return ("Windows", "", "")
    import winreg

    try:
        with winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        ) as key:

            def value(name: str) -> str:
                try:
                    return str(winreg.QueryValueEx(key, name)[0])
                except OSError:
                    return ""

            name, version, build = (
                value("ProductName"),
                value("DisplayVersion") or value("ReleaseId"),
                value("CurrentBuildNumber"),
            )
    except OSError:
        return ("Windows", "", "")
    # Windows 11 still reports "Windows 10 …" as its product name.
    if build.isdigit() and int(build) >= 22000:
        name = name.replace("Windows 10", "Windows 11")
    return (name or "Windows", version, build)


_KINDS = (
    ("vpn", re.compile(r"wireguard|wintun|tap-|openvpn|nord|proton|mullvad|tailscale|zerotier|vpn|ppp", re.I)),
    ("virtual", re.compile(r"vethernet|vmware|virtualbox|hyper-v|loopback|docker|wsl|bluetooth|vmnet|host-only", re.I)),
    ("wifi", re.compile(r"wi-?fi|wireless|wlan|802\.11", re.I)),
    ("ethernet", re.compile(r"ethernet|\blan\b|local area", re.I)),
)


def _interface_kind(name: str) -> str:
    for kind, pattern in _KINDS:
        if pattern.search(name):
            return kind
    return "other"


def _default_route_ip() -> str:
    """The local address the default route uses (a UDP connect sends nothing)."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.settimeout(0.2)
        probe.connect(("192.0.2.1", 9))
        return probe.getsockname()[0]
    except OSError:
        return ""
    finally:
        probe.close()


class Collector:
    """Takes readings. Not thread-safe; one thread calls `collect`."""

    def __init__(self) -> None:
        self._tick = 0
        self._last_time = 0.0
        self._net_prev: tuple[float, dict[str, tuple[int, int]]] | None = None
        self._disk_prev: tuple[float, dict[str, tuple[int, int]]] | None = None
        self._ping_at = 0.0
        self._ping_index = -1
        self._gpu_tool = self._find_nvidia_smi()
        self._gpu_at = 0.0
        self._system_at = 0.0
        self._containers_at = 0.0
        # Slow work: at most one job per kind, two threads in all.
        self._pool = ThreadPoolExecutor(max_workers=2, thread_name_prefix="glassy-slow")
        self._jobs: dict[str, Future] = {}
        self._smi: dict | None = None
        self._lhm_state: dict | None = None
        self._lhm = None  # HardwareSensors, only while the option is on
        self.hw_status = "off"
        self._hw_at = 0.0
        self._hw_failed = False
        self._adapters = video_adapters()
        self._pdh = self._open_counters()
        self._ncpu = psutil.cpu_count(logical=True) or 1
        # Prime the CPU counters: the first reading after this call is a real
        # delta, the first call itself returns a meaningless 0.
        psutil.cpu_percent(None)
        psutil.cpu_percent(None, percpu=True)

    ENGINE = r"\GPU Engine(*)\Utilization Percentage"
    GPU_MEMORY = r"\GPU Adapter Memory(*)\Dedicated Usage"
    THERMAL = r"\Thermal Zone Information(*)\Temperature"

    def _open_counters(self):
        if pdh is None or not pdh.available():
            return None
        try:
            query = pdh.Query()
        except OSError:
            return None
        for path in (self.ENGINE, self.GPU_MEMORY, self.THERMAL):
            query.add(path)  # a machine without one simply never reports it
        query.collect()
        return query

    def close(self) -> None:
        """Release the counter query, the sensor driver and the pool."""
        self._pool.shutdown(wait=False, cancel_futures=True)
        for job in list(self._jobs.values()):
            try:
                job.result(timeout=8)
            except Exception:
                pass
        self._jobs.clear()
        if self._lhm is not None:
            self._lhm.close()
            self._lhm = None
        if self._pdh is not None:
            self._pdh.close()
            self._pdh = None

    def _later(self, name: str, function, *args) -> None:
        """Start a slow job unless the last one of its kind is still running."""
        job = self._jobs.get(name)
        if job is not None and not job.done():
            return
        try:
            self._jobs[name] = self._pool.submit(function, *args)
        except RuntimeError:  # pool already shut down
            pass

    def _harvest(self, out: dict) -> None:
        """Fold finished slow jobs into this cycle's readings."""
        for name, job in list(self._jobs.items()):
            if not job.done():
                continue
            del self._jobs[name]
            try:
                result = job.result()
            except Exception:
                continue
            if name == "smi":
                self._smi = result
            elif name == "lhm":
                self._lhm_state = result
                out["hwStatus"] = self.hw_status
            elif result:
                out.update(result)

    @staticmethod
    def _find_nvidia_smi() -> str:
        from shutil import which

        found = which("nvidia-smi")
        if found:
            return found
        system_root = os.environ.get("SystemRoot", r"C:\Windows")
        for path in (
            os.path.join(system_root, "System32", "nvidia-smi.exe"),
            r"C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
        ):
            if os.path.isfile(path):
                return path
        return ""

    # ── pieces ───────────────────────────────────────────────────────────────
    def _cpu(self) -> dict:
        return {
            "cpu": psutil.cpu_percent(None),
            "cores": psutil.cpu_percent(None, percpu=True),
        }

    def _memory(self) -> dict:
        memory = psutil.virtual_memory()
        try:
            swap = psutil.swap_memory()
            swap_used, swap_total = swap.used, swap.total
        except OSError:
            swap_used = swap_total = 0
        return {
            "memUsed": memory.total - memory.available,
            "memTotal": memory.total,
            "swapUsed": swap_used,
            "swapTotal": swap_total,
        }

    def _network(self, now: float) -> dict:
        counters = psutil.net_io_counters(pernic=True)
        current = {n: (c.bytes_recv, c.bytes_sent) for n, c in counters.items()}
        rates: dict[str, dict[str, float]] = {}
        if self._net_prev:
            elapsed = now - self._net_prev[0]
            if elapsed > 0.05:
                for name, (rx, tx) in current.items():
                    before = self._net_prev[1].get(name)
                    if before:
                        rates[name] = {
                            "rx": max(0.0, (rx - before[0]) / elapsed),
                            "tx": max(0.0, (tx - before[1]) / elapsed),
                        }
        # Replaced, not merged: adapters that went away drop out.
        self._net_prev = (now, current)
        return {"ifaceRates": rates}

    def _disk_io(self, now: float) -> dict:
        try:
            counters = psutil.disk_io_counters(perdisk=True) or {}
        except (OSError, RuntimeError):
            counters = {}
        current = {n: (c.read_bytes, c.write_bytes) for n, c in counters.items()}
        rates: dict[str, dict[str, float]] = {}
        if self._disk_prev:
            elapsed = now - self._disk_prev[0]
            if elapsed > 0.05:
                for name, (rd, wr) in current.items():
                    before = self._disk_prev[1].get(name)
                    if before:
                        rates[name] = {
                            "rd": max(0.0, (rd - before[0]) / elapsed),
                            "wr": max(0.0, (wr - before[1]) / elapsed),
                        }
        self._disk_prev = (now, current)
        return {"diskRates": rates}

    def _interfaces(self) -> dict:
        stats = psutil.net_if_stats()
        addresses = psutil.net_if_addrs()
        route_ip = _default_route_ip()
        interfaces = []
        for name, stat in stats.items():
            kind = _interface_kind(name)
            if kind == "virtual" and "loopback" in name.lower():
                continue
            ip = mac = ""
            for address in addresses.get(name, ()):
                if address.family == socket.AF_INET and not ip:
                    ip = address.address
                elif address.family == psutil.AF_LINK and not mac:
                    mac = address.address.replace("-", ":").lower()
            interfaces.append(
                {
                    "name": name,
                    "up": bool(stat.isup),
                    "kind": kind,
                    "mac": mac,
                    "speed": int(stat.speed or 0),
                    "ip": ip,
                    # 0 for the adapter carrying the default route, -1 otherwise
                    # (Probes.autoInterface wants the lowest metric).
                    "route": 0 if ip and ip == route_ip else -1,
                }
            )
        return {"interfaces": interfaces}

    def _storage(self) -> dict:
        rows = []
        for part in psutil.disk_partitions(all=False):
            # Skip empty card readers and optical drives; never touch a
            # network share that may block for its whole timeout.
            if "cdrom" in part.opts or part.fstype == "" or "remote" in part.opts:
                continue
            try:
                usage = psutil.disk_usage(part.mountpoint)
            except OSError:
                continue
            if usage.total <= 0:
                continue
            mount = part.mountpoint.rstrip("\\") or part.mountpoint
            rows.append(
                {
                    "mount": mount,
                    "device": part.device.rstrip("\\"),
                    "fs": part.fstype,
                    "size": usage.total,
                    "used": usage.used,
                    "percent": usage.percent,
                }
            )
        return {"storage": rows}

    def _processes(self) -> dict:
        """A snapshot in the shape Probes.topProcesses reads.

        `total` is all CPU seconds the machine could spend so far and each
        process's `ticks` its own, so (Δticks / Δtotal) is its share of the
        whole machine, as with /proc/stat jiffies.
        """
        times = psutil.cpu_times()
        total = sum(times)
        procs = {}
        for process in psutil.process_iter(["pid", "name", "cpu_times", "memory_info"]):
            info = process.info
            pid = info["pid"]
            cpu, memory = info["cpu_times"], info["memory_info"]
            if pid == 0 or cpu is None or memory is None:
                continue
            name = info["name"] or str(pid)
            if name.lower().endswith(".exe"):
                name = name[:-4]
            procs[str(pid)] = {
                "name": name,
                "ticks": cpu.user + cpu.system,
                "rss": memory.rss,
            }
        return {
            "procSnapshot": {
                "total": total,
                "memTotal": psutil.virtual_memory().total,
                "procs": procs,
            }
        }

    def _load(self) -> dict:
        # psutil emulates the load average on Windows from a sampling thread.
        one, five, fifteen = psutil.getloadavg()
        return {
            "load": {
                "load1": one,
                "load5": five,
                "load15": fifteen,
                "running": 0,
                "tasks": len(psutil.pids()),
                "uptime": time.time() - psutil.boot_time(),
                "cpus": self._ncpu,
            }
        }

    def _battery(self) -> dict:
        try:
            battery = psutil.sensors_battery()
        except (OSError, NotImplementedError):
            battery = None
        if battery is None:
            return {"battery": None}
        if battery.power_plugged:
            status = "Full" if battery.percent >= 99 else "Charging"
        else:
            status = "Discharging"
        seconds = battery.secsleft
        hours = seconds / 3600 if isinstance(seconds, int) and seconds > 0 else 0
        return {
            "battery": {
                "percent": int(battery.percent),
                "status": status,
                "plugged": bool(battery.power_plugged),
                "hours": hours,
            }
        }

    def _system(self) -> dict:
        name, version, build = _windows_name()
        return {
            "system": {
                "distro": name,
                "version": version,
                "kernel": f"10.0.{build}" if build else "",
                "hostname": socket.gethostname(),
                "uptime": _uptime_text(time.time() - psutil.boot_time()),
            }
        }

    # ── GPU ──────────────────────────────────────────────────────────────────
    def _gpu_smi(self) -> dict:
        """nvidia-smi's extras (clock, temperature, power); a slow job."""
        text = _run(
            [
                self._gpu_tool,
                "--query-gpu=utilization.gpu,memory.used,memory.total,clocks.gr,temperature.gpu,fan.speed,power.draw,name",
                "--format=csv,noheader,nounits",
            ],
            timeout=3,
        )
        line = text.strip().splitlines()[0] if text.strip() else ""
        fields = [f.strip() for f in line.split(",")]
        if len(fields) < 8:
            return {}

        def number(value: str) -> float:
            try:
                return float(value)
            except ValueError:
                return -1.0  # "[N/A]" and the like

        mib = 1024 * 1024
        return {
            "vendor": "nvidia",
            "percent": max(0.0, number(fields[0])),
            "vramUsed": number(fields[1]) * mib,
            "vramTotal": number(fields[2]) * mib,
            "freqMhz": int(max(0.0, number(fields[3]))),
            "tempC": number(fields[4]),
            "watts": number(fields[6]),
            "name": fields[7],
        }

    def _gpu_counters(self) -> dict | None:
        """GPU load and memory from the performance counters, any vendor.

        Load is what Task Manager shows: per adapter, the busiest engine type
        (3D, compute, copy, video…) summed over every process using it.
        """
        query = self._pdh
        if query is None:
            return None
        engines = query.values(self.ENGINE)
        memory = {_key.lower(): v for _key, v in query.values(self.GPU_MEMORY).items()}
        if not engines and not memory and not self._adapters:
            return None
        busy: dict[str, dict[str, float]] = {}
        for name, value in engines.items():
            match = _ENGINE_RE.search(name)
            if match:
                adapter = f"luid_{match.group(1)}_phys_{match.group(2)}".lower()
                kinds = busy.setdefault(adapter, {})
                kinds[match.group(3)] = kinds.get(match.group(3), 0.0) + value
        load = {a: min(100.0, max(k.values())) for a, k in busy.items() if k}
        pick = ""
        if load and max(load.values()) > 0:
            pick = max(load, key=load.get)
        elif memory:
            pick = max(memory, key=memory.get)
        primary = self._adapters[0] if self._adapters else {}
        gpu = {
            "vendor": primary.get("vendor", ""),
            "name": primary.get("name", ""),
            "percent": load.get(pick, 0.0),
            "vramUsed": memory.get(pick, 0.0),
            # Integrated GPUs share system memory and report none of their own.
            "vramTotal": float(primary.get("memory") or -1),
            "freqMhz": 0,
        }
        return gpu

    def _acpi_group(self) -> dict | None:
        """ACPI thermal zones (Kelvin): what Windows exposes without admin."""
        if self._pdh is None:
            return None
        sensors = []
        for name, kelvin in self._pdh.values(self.THERMAL).items():
            celsius = kelvin - 273.15
            if -40 < celsius < 150:
                label = name.replace("\\_TZ.", "").replace("\\", "") or "zone"
                sensors.append({"label": label, "value": round(celsius, 1), "crit": 100.0, "type": "temp"})
        if not sensors:
            return None
        return {
            "chip": "acpitz",
            "chipDisplay": "ACPI thermal zone",
            "maxTemp": max(s["value"] for s in sensors),
            "maxTempCrit": 100.0,
            "sensors": sensors,
        }

    def _lhm_job(self, enabled: bool) -> dict | None:
        """Open / read / close the opt-in sensor library; a slow job."""
        if not enabled:
            self._hw_failed = False
            if self._lhm is not None:
                self._lhm.close()
                self._lhm = None
            self.hw_status = "off"
            return None
        if self._lhm is None:
            from hwsensors import HardwareSensors

            reader = HardwareSensors()
            if reader.open() not in ("ok", "limited"):
                self.hw_status = reader.status
                # Not retried until the switch is turned off and on again.
                self._hw_failed = True
                reader.close()
                return {"groups": [], "fans": [], "power": [], "gpu": None}
            self._lhm = reader
        state = self._lhm.read()
        self.hw_status = self._lhm.status
        return state

    def _gpu_and_sensors(self, wanted: frozenset[str], options: dict, out: dict) -> None:
        """Merge every GPU / sensor source into one set of readings."""
        smi = self._smi
        lhm = self._lhm_state or {}
        gpu = self._gpu_counters()
        # More exact where present: the vendor tool, then the sensor library.
        for extra in (smi, lhm.get("gpu")):
            if extra:
                gpu = {**(gpu or {}), **{k: v for k, v in extra.items() if v is not None}}
        out["gpu"] = gpu
        groups = []
        acpi = self._acpi_group()
        if acpi:
            groups.append(acpi)
        groups.extend(lhm.get("groups", []))
        if smi and smi.get("tempC", -1) >= 0 and not any(g["chip"] in ("nvidia", "amdgpu", "i915") for g in groups):
            groups.append(
                {
                    "chip": "nvidia",
                    "chipDisplay": "GPU (NVIDIA)",
                    "maxTemp": smi["tempC"],
                    "maxTempCrit": 100.0,
                    "sensors": [{"label": "edge", "value": smi["tempC"], "crit": 100.0, "type": "temp"}],
                }
            )
        out["hwGroups"] = groups
        out["fans"] = lhm.get("fans", [])
        power = list(lhm.get("power", []))
        if smi and smi.get("watts", -1) > 0 and not any(p["kind"] == "gpu" for p in power):
            power.append({"id": "smi:gpu", "label": "GPU (NVIDIA)", "kind": "gpu", "watts": smi["watts"]})
        out["powerSources"] = power

    # ── ping ─────────────────────────────────────────────────────────────────
    def _ping(self, targets: list[str], index: int, timeout_s: int) -> dict:
        host = targets[index] if 0 <= index < len(targets) else ""
        # A host is a name or an address; never something ping.exe reads as a flag.
        if not host or host.startswith("-") or not re.fullmatch(r"[\w.:\-\[\]%]+", host):
            return {"ping": {"index": index, "ms": -1.0}}
        family = ["-6"] if ":" in host else []
        text = _run(
            ["ping", *family, "-n", "1", "-w", str(max(1, timeout_s) * 1000), host],
            timeout=timeout_s + 2,
        )
        # English "time=12ms" / "time<1ms"; other languages keep the same
        # shape ("Zeit=", "temps=") so match any word before the sign.
        match = re.search(r"[=<]\s*(\d+(?:[.,]\d+)?)\s*ms", text, re.I)
        ms = -1.0
        if match:
            ms = float(match.group(1).replace(",", "."))
            if "<" in match.group(0):
                ms = max(0.5, ms - 0.5)
        return {"ping": {"index": index, "ms": ms}}

    # ── containers and pods ──────────────────────────────────────────────────
    # Tab-separated, then turned into the "|" MonitorCore parses: a `|` in an
    # argument is a pipe to cmd.exe if `docker` is a .cmd/.bat shim.
    PS_FORMAT = "{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}"
    STATS_FORMAT = "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    PODS_COLUMNS = (
        "NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,"
        "READY:.status.containerStatuses[*].ready,"
        "RESTARTS:.status.containerStatuses[*].restartCount,"
        "WAIT:.status.containerStatuses[*].state.waiting.reason"
    )

    @staticmethod
    def _kubeconfig() -> str:
        configured = os.environ.get("KUBECONFIG", "")
        for path in configured.split(os.pathsep) if configured else []:
            if path and os.path.isfile(path):
                return path
        default = os.path.join(os.path.expanduser("~"), ".kube", "config")
        return default if os.path.isfile(default) else ""

    def _containers(self, source: str, namespace: str) -> dict:
        """Docker, Podman and Kubernetes in the text MonitorCore already parses
        (Probes.parseContainerList): `@@ps` / `@@stats` per engine, `@@kube`."""
        text = []
        if source != "kubernetes":
            for engine in ("docker", "podman"):
                tool = shutil.which(engine)
                if not tool:
                    continue
                listing = _run(
                    [tool, "ps", "-a", "--format", self.PS_FORMAT], timeout=4, merge_errors=True
                ).replace("\t", "|")
                text.append(f"@@ps {engine}\n{listing}")
                # A stopped daemon answers with an error line, not rows: do not
                # also wait out the slower `stats` against it.
                if "|" in listing:
                    stats = _run(
                        [tool, "stats", "--no-stream", "--format", self.STATS_FORMAT], timeout=8
                    ).replace("\t", "|")
                    text.append(f"@@stats {engine}\n{stats}")
        if source != "containers":
            kubectl = shutil.which("kubectl") or shutil.which("k3s")
            config = self._kubeconfig()
            if kubectl and config:
                base = [kubectl] + (["kubectl"] if os.path.basename(kubectl).lower().startswith("k3s") else [])
                scope = ["-n", namespace] if re.fullmatch(r"[a-z0-9-]+", namespace or "") else ["-A"]
                env = {**os.environ, "KUBECONFIG": config}
                context = _run(base + ["config", "current-context"], 4, env=env).strip()
                pods = _run(
                    base + ["get", "pods", *scope, "--no-headers", "--request-timeout=5s", "-o", f"custom-columns={self.PODS_COLUMNS}"],
                    8,
                    merge_errors=True,
                    env=env,
                )
                top = _run(base + ["top", "pods", *scope, "--no-headers", "--request-timeout=5s"], 8, env=env)
                head = lambda block: "\n".join(block.splitlines()[:300])  # noqa: E731
                text.append(f"@@kube {context}\n{head(pods)}\n@@top\n{head(top)}")
        return {"containers": "\n".join(text)}

    # ── one cycle ────────────────────────────────────────────────────────────
    def collect(self, wanted: frozenset[str], options: dict) -> dict:
        """Readings for the sections in `wanted`.

        `options` carries what the settings decide: targets, pingInterval,
        pingTimeout, currentTargetIndex, containerSource, kubeNamespace, and
        the host's own `hwSensors` switch.
        """
        now = time.monotonic()
        out: dict = {"dt": now - self._last_time if self._last_time else 0.0}
        self._last_time = now
        tick = self._tick
        self._tick += 1
        self._harvest(out)

        if "cpu" in wanted or "load" in wanted or tick == 0:
            out.update(self._cpu())
        if "memory" in wanted or tick == 0:
            out.update(self._memory())
        if "network" in wanted or tick == 0:
            out.update(self._network(now))
            if tick % 10 == 0:
                out.update(self._interfaces())
        if "disk" in wanted or tick == 0:
            out.update(self._disk_io(now))
        if "storage" in wanted and tick % 15 == 0:
            out.update(self._storage())
        if "processes" in wanted and tick % 3 == 0:
            out.update(self._processes())
        if "load" in wanted and tick % 5 == 0:
            out.update(self._load())
        if "system" in wanted and (tick == 0 or now - self._system_at > 30):
            self._system_at = now
            out.update(self._system())
        if ("power" in wanted or "sensors" in wanted) and tick % 5 == 0:
            out.update(self._battery())

        # Sensor library: opened when the switch goes on, closed when it goes off.
        hw_wanted = bool(options.get("hwSensors")) and bool(
            wanted & {"sensors", "fans", "power", "gpu", "cpu"}
        )
        if (hw_wanted and not self._hw_failed) or (not hw_wanted and self.hw_status != "off"):
            if now - self._hw_at >= 2:
                self._hw_at = now
                self._later("lhm", self._lhm_job, hw_wanted)

        gpu_wanted = bool(wanted & {"gpu", "sensors", "power", "fans"})
        if gpu_wanted and now - self._gpu_at >= 2:
            self._gpu_at = now
            if self._gpu_tool:
                self._later("smi", self._gpu_smi)
            self._gpu_and_sensors(wanted, options, out)

        if "ping" in wanted:
            interval = max(1, int(options.get("pingInterval") or 5))
            if now - self._ping_at >= interval:
                self._ping_at = now
                self._later(
                    "ping",
                    self._ping,
                    list(options.get("targets") or []),
                    int(options.get("currentTargetIndex") or 0),
                    int(options.get("pingTimeout") or 2),
                )
        if "containers" in wanted and now - self._containers_at >= 6:
            self._containers_at = now
            self._later(
                "containers",
                self._containers,
                str(options.get("containerSource") or ""),
                str(options.get("kubeNamespace") or ""),
            )
        return out


class Sampler:
    """Runs a Collector on a daemon thread and hands each result to `deliver`.

    `deliver(readings)` is called on the worker thread; the Qt wrapper turns
    it into a queued signal. The next cycle does not start until
    `acknowledge()` says the previous one was applied (or a few seconds pass),
    which bounds the number of readings alive at once to one.
    """

    ACK_TIMEOUT = 5.0

    def __init__(self, deliver) -> None:
        self._deliver = deliver
        self._collector: Collector | None = None
        self._wanted: frozenset[str] = frozenset()
        self._options: dict = {}
        self._interval = 1.0
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._wake = threading.Event()
        self._applied = threading.Event()
        self._applied.set()
        self._thread: threading.Thread | None = None

    def configure(self, wanted, options: dict, interval_ms: int) -> None:
        with self._lock:
            self._wanted = frozenset(wanted)
            self._options = dict(options)
            self._interval = max(0.25, interval_ms / 1000)
        self._wake.set()

    def acknowledge(self) -> None:
        self._applied.set()

    def hw_status(self) -> str:
        collector = self._collector
        return collector.hw_status if collector else "off"

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="glassy-sampler", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._wake.set()
        self._applied.set()
        thread = self._thread
        if thread and thread is not threading.current_thread():
            thread.join(timeout=8)
        self._thread = None

    def _run(self) -> None:
        self._collector = Collector()
        while not self._stop.is_set():
            started = time.monotonic()
            with self._lock:
                wanted, options, interval = self._wanted, self._options, self._interval
            try:
                readings = self._collector.collect(wanted, options)
            except Exception as error:  # a bad counter must not end sampling
                readings = {"error": f"{type(error).__name__}: {error}"}
            if self._applied.wait(self.ACK_TIMEOUT) and not self._stop.is_set():
                self._applied.clear()
                self._deliver(readings)
            self._wake.clear()
            remaining = interval - (time.monotonic() - started)
            if remaining > 0:
                self._wake.wait(remaining)
        collector, self._collector = self._collector, None
        collector.close()
