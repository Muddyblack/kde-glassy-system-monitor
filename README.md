<p align="center">
  <img src="./package/icon.png" width="200" alt="Glassy System Monitor Logo">
</p>

<h1 align="center">Glassy System Monitor</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2360341">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  </a>
  <a href="https://www.opendesktop.org/p/2360341">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%2F2360341%3Fformat%3Djson&query=%24.data%5B0%5D.downloads&label=Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <a href="https://github.com/Muddyblack/kde-glassy-system-monitor/releases">
    <img src="https://img.shields.io/github/downloads/Muddyblack/kde-glassy-system-monitor/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
  </a>
</p>

<p align="center">
  <img src="./readme/network.svg" alt="Widget demo" width="680"/>
</p>

A glassy real-time system monitor for KDE Plasma 6. Tracks **ping · CPU · memory · network** in one place. The main thing that makes it different from built-in widgets is the ping section — you get live RTT graphs, jitter, and packet loss, not just bandwidth.

---

## Features

- **Ping graph** — smooth Bézier chart scrolling in real time, RTT in milliseconds
- **Multi-target tabs** — monitor up to 4 hosts at once (e.g. `8.8.8.8`, `1.1.1.1`, your router), switch with one click
- **CPU, memory, and network graphs** — CPU with optional per-core overlays, RAM + swap, upload/download bandwidth
- **Jitter** — standard deviation over the rolling history window
- **Packet loss** — lost pings shown as red dots on the graph; loss % in the stats bar
- **Alert indicators** — line turns amber above the latency threshold, red at 1.5×; a pulsing border when alerting
- **Glassy look** — semi-transparent dark card with neon glow, same aesthetic as the [Plasma Audio Visualizer](https://github.com/muddyblack/plasma-audio-visualizer)

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.0+ | `X-Plasma-API-Minimum-Version: 6.0` |
| `plasma5support` | Provides the `executable` DataEngine used for ping |
| `ping` (iputils) | Standard on all Linux distros |

---

## Install

### Manual (any distro)

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
kpackagetool6 -t Plasma/Applet -i package
# or to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then right-click your desktop → *Add Widgets* → search **"Glassy System Monitor"**.

To remove:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitor
```

### Development / test install

```bash
./test_install.sh
```

To remove the test copy:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitorTest
```

### NixOS (flake)

```nix
# flake.nix
{
  inputs.glassy-monitor.url = "github:Muddyblack/kde-glassy-system-monitor";

  outputs = { self, nixpkgs, glassy-monitor, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            glassy-monitor.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

### Package as `.plasmoid`

```bash
./pack.sh
# produces glassy-system-monitor-<version>.plasmoid
```

---

## Configuration

Right-click the widget → *Configure*:

| Setting | Default | Description |
|---|---|---|
| **Hosts** | `8.8.8.8,1.1.1.1,192.168.1.1` | Comma-separated ping targets (max 4) |
| **Ping interval** | `2 s` | Time between pings |
| **Timeout** | `2 s` | Per-ping timeout, counts as packet loss |
| **History points** | `60` | Rolling sample count per target |
| **Latency warning** | `100 ms` | Line turns amber above this |
| **Loss warning** | `5 %` | Alert border activates above this loss rate |
| **Line color** | system accent | Or pick a custom color |
| **Glow** | on | Neon shadow on graph lines |
| **Stats bar** | on | Jitter, loss, min/max below the graph |
| **Background card** | on | Semi-transparent glass card behind the widget |
