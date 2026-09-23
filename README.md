<p align="center">
  <img src="./package/icon.png" width="160" alt="Glassy System Monitor icon">
</p>

<h1 align="center">Glassy System Monitor</h1>

<p align="center">
  <a href="https://muddyblack.github.io/kde-glassy-system-monitor/">
    <img src="https://img.shields.io/badge/Interactive_Studio-Try_Online-success?style=for-the-badge" alt="Try the studio online" />
  </a>
  <a href="https://www.opendesktop.org/p/2360341">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/KDE_Plasma-6.2%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.2+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-GPL--3.0--or--later-blue?style=for-the-badge" alt="License: GPL-3.0-or-later" />
  </a>
  <a href="https://www.opendesktop.org/p/2360341">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%3Fsearch%3Dglassy%2Bsystem%2Bmonitor%26format%3Djson&query=%24.data%5B0%5D.downloads&label=Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <a href="https://github.com/Muddyblack/kde-glassy-system-monitor/releases">
    <img src="https://img.shields.io/github/downloads/Muddyblack/kde-glassy-system-monitor/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
  </a>
  <img src="https://img.shields.io/badge/Started-May_2026-9c27b0?style=for-the-badge" alt="Project started May 2026" />
</p>

<p align="center">
  <img src="./docs/readme/look-dashboard.png" alt="The Dashboard look: CPU, memory, network, disk and GPU in one card" width="640"/>
</p>

One widget for CPU, memory, network, ping, disk, GPU, storage, processes, sensors, power,
system info and your own commands, in the order and layout you want. Charts run on the GPU,
and everything is set up in a studio with a live preview. Works on KDE Plasma 6 and on
Hyprland through Quickshell.

## Looks

<p align="center">
  <img src="./docs/readme/look-gauges.png" alt="Gauges look" width="45%"/>
  <img src="./docs/readme/look-laptop.png" alt="Laptop look" width="45%"/>
</p>

<details>
  <summary><b>More looks</b></summary>
  <br/>
  <p align="center">
    <img src="./docs/readme/look-liquid.png" alt="Liquid Glass look" width="45%"/>
    <img src="./docs/readme/look-paper.png" alt="Paper look" width="45%"/>
    <img src="./docs/readme/look-atmosphere.png" alt="Atmosphere look" width="45%"/>
    <img src="./docs/readme/look-neon.png" alt="Neon look" width="45%"/>
    <img src="./docs/readme/look-gaming.png" alt="Gaming look" width="45%"/>
    <img src="./docs/readme/look-minimal.png" alt="Minimal look" width="45%"/>
  </p>
</details>

## Studio

<p align="center">
  <img src="./docs/readme/studio-layout.png" alt="Studio, Layout tab with live preview" width="820"/>
</p>

Right-click the widget → *Configure*. Pick a look, drag sections into order, and see the
result on live or demo data. Looks can be shared as JSON with the
[browser studio](https://muddyblack.github.io/kde-glassy-system-monitor/).

## Network window

<p align="center">
  <img src="./docs/readme/network-overview.png" alt="Network window, Overview" width="45%"/>
  <img src="./docs/readme/network-apps.png" alt="Network window, Apps" width="45%"/>
</p>

Which apps talk to what: connections, open ports, interfaces, containers, VPNs and a traffic
history, without root. It opens Wireshark on a connection if you have it.
[More about it](docs/network.md).

## Install

Get it from the [KDE Store](https://www.opendesktop.org/p/2360341), or:

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
kpackagetool6 -t Plasma/Applet -i package
```

NixOS, Hyprland and the optional tools are in the [installation guide](docs/installation.md).

## More

- [Features](docs/features.md)
- [Network window](docs/network.md)
- [How it works](docs/how-it-works.md)
- [Contributing](CONTRIBUTING.md)
