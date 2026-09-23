<p align="center">
  <img src="./package/icon.png" width="200" alt="Glassy System Monitor Logo">
</p>

<h1 align="center">Glassy System Monitor</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2360341">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.2%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.2+" />
  <img src="https://img.shields.io/badge/Hyprland-Quickshell-58e1ff?style=for-the-badge" alt="Hyprland via Quickshell" />
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

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#requirements">Requirements</a> ·
  <a href="#install">Install</a> ·
  <a href="#the-studio">Studio</a> ·
  <a href="#hyprland">Hyprland</a> ·
  <a href="#how-it-works">How it works</a>
</p>

---

A glassy real-time system monitor for KDE Plasma 6 and Hyprland. **One widget shows any of ten sections** — CPU, memory, network, ping, disk, GPU, sensors, power, system info and a custom command — in the order you choose, stacked or side by side. Charts are drawn by a fragment shader on the GPU, and every setting lives in a settings studio with a live preview, in the style of the [Plasma Audio Visualizer](https://github.com/Muddyblack/audio-wave-visualizer).

Try the studio in your browser: **[muddyblack.github.io/kde-glassy-system-monitor](https://muddyblack.github.io/kde-glassy-system-monitor/)**.

<p align="center">
  <img src="./docs/readme/look-gauges.png" alt="Gauges look: CPU, memory and GPU donuts side by side" width="45%"/>
  <img src="./docs/readme/look-laptop.png" alt="Laptop look: battery, CPU and sensors" width="45%"/>
</p>

## Features

### One widget, your layout

- **Any sections, any order** — switch sections on in the studio and drag them into order; no more one widget per metric
- **Side by side** — one to three columns; any section can take a full row of its own
- **Per-section size and style** — e.g. CPU as a tall line chart next to memory as a small donut
- **Never cut off** — every section reports the height its content needs; the card cannot be sized below it, and only charts give way (never below 40 px)
- **Looks** — seven built-in looks, your own saved looks, and sharing as a JSON snippet. A look never carries commands, hosts or devices, so an imported one cannot run anything

### Monitoring sections

- **Ping graph** — smooth Bézier chart scrolling in real time, RTT in milliseconds
- **Multi-target tabs** — monitor up to 4 hosts at once (e.g. `8.8.8.8`, `1.1.1.1`, your router), switch with one click
- **CPU** — overall usage with optional per-core overlays
- **Memory** — RAM + swap
- **Network** — upload/download bandwidth, session totals, per-interface selection, and an optional SSID / IP readout
- **GPU** — utilization, clock, and an optional **per-engine breakdown** (VRAM, compute, decode, encode) — best-effort across NVIDIA, AMD, and Intel
- **Disk I/O** — read/write throughput per device
- **Power** — battery state and draw
- **Hardware sensors** — temperatures with warning/critical thresholds
- **OS info** — distro and host details
- **Custom command** — chart the output of any shell command on an interval

### Network insight

- **Jitter** — standard deviation over the rolling history window
- **Packet loss** — lost pings shown as red dots on the graph; loss % in the stats bar
- **Alert indicators** — line turns amber above the latency threshold, red at 1.5×; a pulsing border when alerting

### Look & feel

- **Glassy look** — semi-transparent dark card with neon glow, same aesthetic as the [Plasma Audio Visualizer](https://github.com/muddyblack/plasma-audio-visualizer)
- **GPU charts** — line, area, history bars, donut and pie are drawn by one fragment shader with an analytic glow; the original canvas renderer stays available as a switch and is used automatically where there is no GPU
- **Frosted glass** — blurred card with adjustable strength (on by default; turn it off for a flat translucent card)
- **Chart styles** — line, filled area, history bars, donut, pie, meters, or numbers only
- **Theming** — honors the active Plasma accent color (or set custom colors per section), system text color, configurable background color, and each of the four card corners rounded independently
- **Palettes** — recolour every section at once (Glassy, Aurora, Ember, Ice, Monochrome)
- **Tunable poll rate** — one base interval drives every sensor, so you can trade update smoothness for CPU
- **Compact panel mode** — condensed representation for panel placement

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.2+ (Qt 6.7+) | Per-corner card radii use Qt 6.7's `Rectangle` corners |
| `plasma5support` | Provides the `executable` DataEngine used for ping and the fallback stats |
| `ping` (iputils) | Standard on all Linux distros |

Optional, for richer data when present (the widget degrades gracefully without them):

| Tool | Enables |
|---|---|
| `ksystemstats` + `libksysguard` | CPU / memory / network / disk without any polling of our own — ships with Plasma, so this is normally already there. Missing it only means the widget reads `/proc` itself |
| `nvidia-smi` | NVIDIA GPU utilization, encode/decode, VRAM |
| `sensors` (lm-sensors) | Hardware temperature sensors |
| `iwgetid` / `iw` / `nmcli` | Network SSID readout on the `/proc` fallback path (ksystemstats reports it directly) |

---

## Install

<details open>
  <summary><b>Manual (any distro)</b></summary>

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

</details>

<details>
  <summary><b>Development / test install</b></summary>

```bash
./test_install.sh
```

To remove the test copy:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitorTest
```

</details>

<details>
  <summary><b>NixOS (flake)</b></summary>

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

</details>

<details>
  <summary><b>Package as <code>.plasmoid</code> (for the KDE Store)</b></summary>

```bash
./pack.sh
# produces glassy-system-monitor-<version>.plasmoid
```

</details>

---

## The studio

Right-click the widget → *Configure* opens the studio: every setting with a description,
search (<kbd>/</kbd>), undo (<kbd>Ctrl</kbd>+<kbd>Z</kbd>), and the real widget previewed on
the right — on this machine's live data or on demo data, as a desktop card or a panel pill,
over a choice of wallpapers.

<p align="center">
  <img src="./docs/readme/studio-layout.png" alt="Studio, Layout tab: sections with drag handles, sizes and chart styles, live preview" width="820"/>
</p>

| Tab | What is there |
|---|---|
| **Presets** | Built-in looks, your saved looks, copy and import looks as JSON |
| **Layout** | Sections on/off, drag to reorder, size S/M/L, chart style and full width per section; columns; panel pill; placement on Hyprland |
| **Appearance** | Charts (style, history, curves, glow, labels), Card (tint, frost, edge, corners), Colours (palettes, text) |
| **Sections** | One tab per section: title, colours, hosts, devices, thresholds, commands |
| **Performance** | GPU shader or canvas renderer, update interval, smooth scrolling, frame-rate cap |
| **Info** | Version and update check, project stats, licence, links |

Every setting and its description is also listed on the [website](https://muddyblack.github.io/kde-glassy-system-monitor/),
generated from the studio itself.

---

## Hyprland

The same widget runs as a desktop layer on Hyprland (or any compositor with wlr-layer-shell)
through [Quickshell](https://quickshell.outfoxxed.me/), with the same studio:

```bash
make view-hyprland      # run it (Ctrl+C stops)
make settings-hyprland  # open the studio of the running widget
```

Defaults go in [`shell.qml`](shell.qml) under their Plasma names; the studio's Apply saves your
changes to `~/.config/glassy-system-monitor/hyprland.json`. Placement (screen, side, height,
margin, width, layer) is set in the studio's Layout tab. For a bar, put
[`hyprland/MonitorPill.qml`](hyprland/MonitorPill.qml) in your Quickshell bar.

---

## How it works

The widget has no compiled backend — it reads from the system through the `executable`
DataEngine, parses the output in QML, and pushes it into a rolling history buffer that
the charts draw.

- **CPU / memory / network / disk** come from **ksystemstats**, the same daemon Plasma's
  own system monitor widgets use. It reads `/proc` in-process every 500 ms and pushes
  values over D-Bus, so the reading happens once for the whole machine however many
  widgets ask for it — no subprocess of ours. That 500 ms tick is both the floor on the
  update rate and the clock the widget samples on: one sample per delivery, and update
  intervals round to a whole number of daemon frames. Sampling on a timer of our own
  instead would beat against it — at an interval of exactly 500 ms the two run at the same
  rate with a drifting phase, and a read landing either side of the daemon's update
  duplicates a value or skips one. Two guards cover what a delivery cannot say on its own:
  a push carries only what *changed*, so an idle interface reporting the same 0 B/s emits
  nothing at all, and a watchdog keeps that graph scrolling flat instead of freezing.
- **Without that daemon** the widget falls back to reading `/proc` itself: `/proc/stat`,
  `/proc/meminfo`, `/proc/net/dev` and `/proc/diskstats` fetched by a single `cat` per
  poll and split back apart in QML, so the four busiest sections still share one process
  rather than forking one each.
- **Ping** runs `ping` per target and parses RTT / loss.
- **Network identity** — SSID / IP come from `iwgetid` / `iw` / `nmcli` and `ip`.
- **GPU** uses `nvidia-smi` on NVIDIA, sysfs on AMD, and DRM `fdinfo` on Intel/others —
  the per-engine breakdown sums each engine's counters across processes and diffs them
  between polls to derive utilization. Each metric appears only when the backend reports it.
  That `fdinfo` scan reads every process's open file descriptors, so it only runs when the
  per-engine breakdown is switched on, or when it is the card's only source of utilization.
- **Sensors** parse `sensors -j`.

### Chart rendering

All charts go through one `Diagram` component with two renderers:

- **GPU (default)** — [`shaders/diagram.frag`](package/contents/shaders/diagram.frag) draws
  lines, areas, bars, donuts and pies with analytic anti-aliasing and glow. Samples reach
  the shader in a small data texture (16-bit values, any number of lines — a 32-thread CPU
  costs the same as one line), so a new sample is one texture upload and one pass into a
  cached layer; scrolling only slides that layer. Grid and threshold lines are a separate,
  unscrolled pass. Text never goes through the shader.
- **Canvas** — the original Context2D renderer with its GPU bloom, kept as a switch under
  Performance and used automatically on software rendering.

Measured with `make benchmark` (four cards, twelve core lines, 60 fps smooth scrolling, on
the author's machine): the shader path used **about 20–25 % less CPU per rendered frame**
(0.28–0.30 % vs 0.35–0.40 %); without animation the two are within noise. Most of what a
scrolling widget costs is Qt redrawing the window every frame, which no renderer avoids —
the frame-rate cap and turning smooth scrolling off remain the big levers.

`make parity` shows every chart style from both renderers side by side.

Between data updates the charts scroll, and they do it at the frame rate — a line that is
visibly moving is redrawn every frame, which is the only thing that reads as smooth. The
saving is elsewhere: a chart whose data arrives so rarely that a frame cannot show its
motion (a custom command polled every couple of minutes crawls at a thousandth of a pixel
per frame) redraws on every N-th frame instead, N being how many frames it needs to travel
a twentieth of a pixel. Whole frames, never a "has it moved far enough yet" test — that
one falls due after one frame sometimes and two the next, and an uneven cadence looks like
stutter even when its average rate is right. The ticker stops entirely when there is
nothing to animate: while the popup is closed, for the chart types that do not scroll
(donut, pie, horizontal bars, text), and while the widget is covered by another window.

That last one has no API behind it — nothing tells a plasmoid it has been covered up. But
a `Canvas` only runs its paint handler during a real render pass, so a paint that was
requested and never arrived means nothing is drawing us. The widget watches for that and
drops to one probe per second until a paint lands again. Data collection carries on
throughout, so uncovering the widget shows a complete chart rather than a gap.

Data never arrives exactly on time, and the scroll is built so that this never shows. Each
chart slides by one history step per update, so a sample landing *early* would otherwise
snap the line forward and a *late* one would leave it stranded — the widget carries the
difference into the next cycle instead, and the line keeps the speed it already had
straight through the update. When a sample is late enough to run the scroll off the end of
its step, the motion eases to a stop over a quarter second rather than halting on a frame,
and picks up from exactly there when the data lands. The upshot is that no update interval
looks different from any other: the line glides at a near-constant rate whether the samples
behind it are early, late, or missing.

---

## Development

```bash
nix develop            # Qt, qsb, plasmoidviewer, Quickshell tools
make view              # the widget in plasmoidviewer
make view-hyprland     # the widget on Quickshell
make test              # 77 tests: charts, layout, studio, shared logic
make lint              # qmllint
make parity            # GPU shader vs canvas, every chart style
make benchmark         # CPU of both renderers (keep the windows visible)
make shaders           # rebuild diagram.frag.qsb after editing the shader
make gallery           # README screenshots into docs/readme
make docs              # website into docs/website
```

Most of what defines the widget is plain JavaScript shared by the QML widget, both studios
and the website: settings ([`studio/Schema.js`](package/contents/ui/studio/Schema.js)),
looks ([`studio/Looks.js`](package/contents/ui/studio/Looks.js)), sections
([`Sections.js`](package/contents/ui/Sections.js),
[`SectionModels.js`](package/contents/ui/SectionModels.js)) and chart data
([`diagram/DiagramData.js`](package/contents/ui/diagram/DiagramData.js)). `make docs` bundles
them for the browser together with the shader, so a change there reaches the website with no
website edit; the Pages workflow rebuilds it on every push.
