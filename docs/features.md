# Features

## Layout

- **Any sections, any order**: switch sections on in the studio and drag them into order
- **Side by side**: one to three columns; any section can take a full row of its own
- **Per-section size and style**: e.g. CPU as a tall line chart next to memory as a small donut
- **Never cut off**: every section reports the height its content needs; the card cannot be
  sized below it, and only charts give way (never below 40 px)
- **Looks**: eleven built-in looks, including Liquid Glass, Paper, Atmosphere and Terminal; save
  your own or share one as JSON. A look never carries commands, hosts or devices, so an imported
  one cannot run anything
- **Spacing**: compact, normal or roomy padding around the card and between sections

## Sections

- **CPU**: overall usage with optional per-core lines
- **Memory**: RAM and swap
- **Network**: upload / download, session totals, per-interface selection, optional SSID / IP;
  opens the [network window](network.md)
- **Ping**: up to 4 hosts with tabs, RTT chart, jitter, lost pings as red dots, amber / red
  above your latency threshold
- **GPU**: utilization, clock and an optional per-engine breakdown (VRAM, compute, decode,
  encode), best-effort across NVIDIA, AMD and Intel
- **Disk I/O**: read / write per device
- **Storage**: usage bars for chosen mount points, or every real filesystem of at least 256 MiB
- **Top processes**: CPU or memory, row count, optional grouping by name
- **Power**: battery state and draw
- **Sensors**: temperatures with warning / critical thresholds
- **System info**: distro and host details
- **Custom command**: chart the output of any shell command on an interval

## Look and feel

- **GPU charts**: line, area, history bars, donut and pie from one fragment shader with an
  analytic glow; the canvas renderer stays as a switch and is used where there is no GPU
- **Card materials**: tint, glass, liquid glass, solid and atmosphere, with wallpaper blur,
  refraction, pointer light, opacity, shadow and grain
- **Colour by load**: CPU, memory and GPU shift to warning and critical colours at your thresholds
- **Chart styles**: line, area, history bars, donut, pie, meters, or numbers only
- **Theming**: Plasma's accent colour or your own per section, palettes (Glassy, Aurora, Ember,
  Ice, Terminal, Monochrome), each card corner rounded on its own
- **Panel pill**: a compact reading for panels and bars
- **Poll rate**: one base interval drives every sensor

## The studio

Right-click the widget → *Configure*: every setting with a description, search (<kbd>/</kbd>),
undo (<kbd>Ctrl</kbd>+<kbd>Z</kbd>), and the real widget previewed on live or demo data, as a
card or a panel pill, over a choice of wallpapers.

| Tab | What is there |
|---|---|
| **Presets** | Built-in looks, your saved looks, copy and import looks as JSON |
| **Layout** | Sections on/off, drag to reorder, size S/M/L, chart style and full width per section; columns; panel pill; placement on Hyprland |
| **Appearance** | Charts (style, history, curves, glow, labels, colour by load), Card (material, frost, edge, corners), Colours (palettes, text and font) |
| **Sections** | One tab per section: title, colours, hosts, devices, thresholds, commands |
| **Performance** | GPU shader or canvas renderer, update interval, smooth scrolling, frame-rate cap |
| **Info** | Version and update check, project stats, licence, links |

Every setting is also listed on the [website](https://muddyblack.github.io/kde-glassy-system-monitor/),
generated from the studio itself.
