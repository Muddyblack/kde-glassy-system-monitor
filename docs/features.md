# Features

## Layout

- **Any sections, any order**: switch sections on in the studio and drag them into order
- **Manual positions**: under Layout › Section positions, switch to Manual and drag sections
  around the preview (right edge, bottom edge or corner to resize), or type exact x, y, width
  and height. Manual starts from where the grid had each section; an unset height follows the
  content, and a section never gets shorter than it needs. Switching back to Automatic keeps
  the saved positions for next time
- **Arrange on the desktop**: on Plasma, right-click the widget › Arrange sections; on
  Quickshell, Arrange on desktop in the settings window (or `qs ipc call settings arrange`).
  Drag and resize sections on the card itself; an automatic layout offers "Arrange sections
  freely". On Quickshell each card also gets a bar to drag the card, and its right edge,
  bottom edge and corner set its width and height; it then stays at that exact spot
  (Placement › Side › Exact)
- **Side by side**: one to three columns; any section can take a full row of its own
- **Per-section size and style**: e.g. CPU as a tall line chart next to memory as a small donut
- **Never cut off**: every section reports the height its content needs; the card cannot be
  sized below it, and only charts give way (never below 40 px)
- **Looks**: eleven built-in looks, including Liquid Glass, Paper, Atmosphere and Terminal; save
  your own or share one as JSON. A look never carries commands, hosts or devices, so an imported
  one cannot run anything
- **Spacing**: compact, normal or roomy padding around the card and between sections

## Sections

- **CPU**: overall usage with optional per-core lines, plus optional readings such as measured CPU power
  from readable RAPL package counters or supported CPU hwmon power sensors
- **Memory**: RAM and swap
- **Network**: upload / download, session totals, per-interface selection, optional SSID / IP;
  opens the [network window](network.md)
- **Ping**: up to 4 hosts with tabs, RTT chart, jitter, lost pings as red dots, amber / red
  above your latency threshold
- **GPU**: utilization, clock and an optional per-engine breakdown (VRAM, compute, decode,
  encode), best-effort across NVIDIA, AMD and Intel
- **Disk I/O**: read / write per device
- **Storage**: usage bars for chosen mount points, or every real filesystem of at least 256 MiB
- **Top processes**: CPU or memory, row count, optional grouping by name; hover a row and click
  ✕ twice to end it (the whole group when grouped; Shift sends SIGKILL)
- **Power**: battery charge, flow, time left, health, cycles and temperature; the machine's
  measured draw from RAPL energy counters and hwmon power sensors (CPU package, platform,
  amdgpu, NVIDIA); a chart of power, charge or temperature; power-profile buttons
  (power-profiles-daemon); CPU and memory pressure
- **Load & uptime**: 1, 5 and 15 minute load against the number of CPUs, uptime, running and
  total tasks
- **Fans**: RPM per fan from lm-sensors against its reported (or fastest seen) speed; empty
  headers stay hidden, a GPU fan that stops at idle shows "stopped"
- **Services**: failed systemd units (system and user) plus any units you watch, with their state
- **Containers**: Docker and Podman containers with CPU and memory, and Kubernetes pods
  (kubectl, or k3s's bundled one) with status, restarts and `kubectl top` usage
- **Sensors**: individual temperatures (including each CPU core), fans, voltage, current,
  power and humidity reported by lm-sensors; temperature bars use critical thresholds
- **System info**: distro logo, distro and host details, or a fetch tool's output
- **Custom command**: chart the output of any shell command on an interval

## Choose and name sensors

Under **Sections › Sensors, CPU, GPU or Power** each of these sections has its own list of
readings, grouped by device (CPU, GPU, NVMe, board, power draw). A device's checkbox takes all of
it; a CPU's cores fold into one **Cores** row (the range, with a bar per core) that unfolds to
pick single cores. Filter by name or device, and rename a reading with the pencil or a
double-click: the new name shows in every section. **Defaults** goes back to the automatic
choice, **Clear** empties the list.

Defaults: Sensors lists temperatures (cores as one row) and fans; CPU shows nothing extra;
GPU shows GPU power; Power lists every measured source under **Where the power goes**. CPU power
comes from RAPL package counters or a CPU power sensor readable without root; the first reading
appears after the second sample. A chosen reading keeps its probe running even if its usual
section is hidden, and one that is not detected right now stays in the list so it can be removed.

## Panel pill

- **Values, sparkline or mini bars** for the sections you pick
- **Tray mode**: one section at a time, turning over every few seconds; scroll to step. The pill
  keeps the width of the widest reading, so the panel never re-lays out
- **Icons** in place of the captions

## Another machine

Set **Layout › Machine › Remote host** (`user@host` or an alias from `~/.ssh/config`) and every
section reads that machine instead: the probes run there over one shared SSH connection
(`ControlMaster`, kept open for two minutes). It needs key login, since a password prompt cannot
be answered. The network window stays local.

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
| **Layout** | Sections on/off, drag to reorder, size S/M/L, chart style and full width per section; columns or exact section coordinates; panel pill; placement on Hyprland |
| **Appearance** | Charts (style, history, curves, glow, labels, colour by load), Card (material, frost, edge, corners), Colours (palettes, text and font) |
| **Sections** | One tab per section: title, colours, hosts, devices, thresholds, commands; sensor selection and names |
| **Performance** | GPU shader or canvas renderer, update interval, smooth scrolling, frame-rate cap |
| **Info** | Version and update check, project stats, licence, links |

Every setting is also listed on the [website](https://muddyblack.github.io/kde-glassy-system-monitor/),
generated from the studio itself.
