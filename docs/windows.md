# Windows

`windows/app.py` hosts the same render tree the Plasma widget and the Hyprland
panel draw (`windows/qml/Monitor.qml`): a borderless card pinned to the desktop,
a tray icon, and the shared settings studio. On Linux `MonitorCore` runs shell
probes (`/proc`, `df`, `ip`, …); Windows has none of those, so the core runs
with `live: false` and `windows/sampler.py` (psutil) feeds it finished values
through the same sample functions `DemoFeeder` uses.

```
pip install -r windows/requirements.txt
python windows/app.py
```

Right-click the card or the tray icon for *Settings…*, *Move / resize…*,
*Reset position*. Holding the middle mouse button drags the card. Settings live
in `%APPDATA%\glassy-system-monitor\settings.json` (same format as the Hyprland
`hyprland.json`).

## What is measured

Everything in the first table works as a normal user.

| section | source | |
|---|---|---|
| CPU, per core | `psutil.cpu_percent` | |
| Memory, swap | `psutil.virtual_memory`, `swap_memory` (page file) | |
| Network, interfaces | `psutil.net_io_counters`, `net_if_*`; the default route is the adapter a UDP `connect` picks | |
| Disk I/O | `psutil.disk_io_counters(perdisk=True)` | |
| Storage | `psutil.disk_partitions` / `disk_usage` | local drives only |
| Processes | `psutil.process_iter`, ranked by `Probes.topProcesses` | |
| Load | `psutil.getloadavg` (emulated on Windows) | |
| Ping | `ping.exe`, with a hard timeout | |
| System | registry (`ProductName`, build), hostname, uptime | |
| Power | `psutil.sensors_battery` | battery level and state |
| **GPU** load, memory | the performance counters Task Manager reads (`GPU Engine`, `GPU Adapter Memory`), through PDH | **any vendor**: NVIDIA, AMD, Intel |
| GPU clock, temperature, power | `nvidia-smi` when present | NVIDIA |
| Temperatures | ACPI thermal zones (`Thermal Zone Information`) | what the firmware exposes; often one zone, absent on some machines |
| **Containers** | `docker` and `podman` (`ps -a`, `stats`) | Docker Desktop, Podman machine, any `docker.exe` on PATH |
| **Kubernetes pods** | `kubectl` (or `k3s kubectl`) with `%USERPROFILE%\.kube\config` or `KUBECONFIG` | |

Dedicated GPU memory total comes from the display driver's registry entry;
integrated GPUs share system memory and report none, so only usage shows.
With two GPUs the load follows the busiest one and the total is the larger
card's.

### Hardware sensors (opt-in, administrator)

Real CPU, board and drive temperatures, fans and power draw need a kernel
driver, so Windows only gives them to an administrator. That is why this is
**off by default**: tray menu ▸ *Hardware sensors (needs administrator)*.

* Turning it on checks that the `HardwareMonitor` package (LibreHardwareMonitor
  with its DLLs; listed in `windows/requirements.txt`, bundled in the `.exe`) is
  there, and when the monitor is not elevated explains why and offers
  *Restart as administrator* (UAC), *Turn on anyway (limited)* or Cancel.
* The menu then shows the state: reading, limited (not elevated), none found, or
  the package missing. Recent LibreHardwareMonitor also wants the PawnIO driver
  for CPU sensors: `winget install PawnIO`.
* A failed open is not retried every few seconds; switch it off and on again.
* It feeds the Sensors, Fans and Power sections (and the CPU / GPU sensor
  pickers) in the same shape lm-sensors does on Linux.

Not available: systemd units (the Services section stays empty on Windows),
ending a process from the Processes section, the network window, and extra
cards (a second card saved on Linux stays in the file, untouched, but only the
first is drawn).

## Memory

The monitor runs for weeks, so leaks are tested, not assumed:

* the sampler keeps only the previous raw counters per device / pid, rebuilt
  from what is alive each cycle; histories exist only in `MonitorCore`, capped
  by `historySize`;
* the worker sends one reading at a time and waits for the UI to acknowledge it,
  so a stalled UI cannot grow the event queue;
* `ping`, `nvidia-smi`, `docker`, `podman` and `kubectl` have a timeout and are
  killed on it, and run on two pool threads, one job per kind at a time, so a
  hung daemon cannot stall the fast readings or pile up requests;
* the performance-counter query and the sensor driver are closed when the
  sampler stops;
* `python windows/app.py --soak 300` runs every section at a 250 ms pace
  headless, prints RSS, thread and handle counts, checks that data reached
  every section, and exits 1 if memory grows more than 15 MiB after the first
  third (`GLASSY_SOAK_LIMIT_MIB` changes the limit).

## Tests

```
python windows/app.py --selftest          # QML loads, settings studio opens, no warnings
python windows/app.py --selftest-sampler  # one real round of readings
python windows/app.py --soak 120
python windows/app.py --shot card.png
python tests/windows/test_hwsensors.py    # sensor mapping, no driver needed
```

## Building and installing

```
pip install -r windows/requirements.txt -r windows/build-requirements.txt
pyinstaller --noconfirm windows/glassy-system-monitor.spec      # dist/Glassy System Monitor/
windows/build-installer.ps1 -Version 2.1.0                       # Glassy-System-Monitor-Setup-2.1.0.exe
```

The installer (Inno Setup 6.3+, `windows/installer.iss`) installs per user
into `%LOCALAPPDATA%\Programs`, needs no administrator rights, updates an
existing install in place (stopping a running copy first), and offers
*Start when I sign in* on a first install. `/VERYSILENT` works for scripted
installs. Verified here: silent install, the installed exe passing
`--selftest`, and an uninstall that removes the folder and the registry entry.

`.github/workflows/windows.yml` runs the tests and the soak on every relevant
pull request, and builds the zip and installer on `master` and by hand (the
artifact is kept 14 days). It is not attached to GitHub releases yet.
