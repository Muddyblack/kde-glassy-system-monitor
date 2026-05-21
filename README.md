# Glassy System Monitor

A glassy, real-time **ping · CPU · Memory · Network** diagnostic widget for KDE Plasma 6.

Unlike built-in network widgets that only show bandwidth, this widget gives you live connection *quality* metrics and system stats.

---

## Features

- **Continuous ping graph** — smooth Bézier line chart rendering RTT in milliseconds, scrolling as new samples arrive
- **Multi-target tabs** — monitor up to 4 hosts simultaneously (e.g. `8.8.8.8`, `1.1.1.1`, your router, a lab server) and switch between them with a single click
- **System monitoring graphs** — displays CPU usage (with core overlays), Memory usage (RAM + swap), and Network bandwidth
- **Jitter display** — standard deviation across the rolling history window
- **Packet-loss counter** — lost packets shown as red dots on the graph floor; loss % in the stats bar
- **Alert indicators** — the graph line shifts amber above the latency threshold, red at 1.5×; a pulsing red border rings the widget when actively alerting
- **Glassy aesthetics** — semi-transparent dark glass card, neon glow on the line, matching the [Plasma Audio Visualizer](https://github.com/muddyblack/plasma-audio-visualizer) style

---

## Preview

```
┌────────────────────────────────────────────────────────┐
│ [8.8.8.8]  [1.1.1.1]  [192.168.1.1]          23 ms   │
│                                                        │
│   ╭────────────────── neon line graph ───────────╮    │
│   │      ╭╮   ╭──╮                               │    │
│   │  ────╯ ╰──╯   ╰───────────────────────────── │    │
│   │  CPU [■■■■■■■■■□ 85%]   RAM [■■■■■□□□□□ 50%]  │
│   ╰────────────────────────────────────────────────╯    │
│                                                        │
│  JITTER  3.2 ms    LOSS  0.0%    MIN/MAX  18/31 ms    │
└────────────────────────────────────────────────────────┘
```

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6 | `X-Plasma-API-Minimum-Version: 6.0` |
| `plasma5support` | Provides the `executable` DataEngine used for ping |
| `ping` (iputils) | Standard on all Linux distros |

---

## Install

### From `.plasmoid` release

```bash
kpackagetool6 -t Plasma/Applet -i glassy-system-monitor-1.0.0.plasmoid
```

### From source (test install)

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor
cd kde-glassy-system-monitor
./test_install.sh
```

Then right-click your desktop → *Add Widgets* → search **"Glassy System Monitor (Test)"**.

To uninstall the test copy:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitorTest
```

---

## Build a release `.plasmoid`

```bash
./pack.sh
```

## Tag & publish

```bash
./tag.sh   # bumps version in metadata.json, packs, commits, tags, pushes
```

---

## Configuration

| Setting | Default | Description |
|---|---|---|
| Hosts | `8.8.8.8,1.1.1.1,192.168.1.1` | Comma-separated ping targets |
| Ping every | 2 s | Interval between pings |
| Timeout | 2 s | Per-ping timeout (counts as packet loss) |
| History points | 60 | Points kept per target |
| Latency warning | 100 ms | Line turns amber above this |
| Loss warning | 5 % | Alert border activates above this |
| Line color | system accent | Or pick a custom neon colour |
| Glow | on | Neon shadow on the line |
| Stats bar | on | Shows jitter, loss, min/max |
| Background card | on | Semi-transparent glass card |

---

## License

MIT — see [LICENSE](LICENSE)
