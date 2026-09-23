# Glassy System Monitor

A sleek glassmorphism real-time system monitor for KDE Plasma 6 (and Hyprland). **One widget shows any of ten sections** — ping, CPU, memory, network, GPU, disk, power, sensors, system info and a custom command — in the order you choose, stacked or side by side, each with its own size and chart style. Charts are drawn by a fragment shader on the GPU, and every setting lives in a settings studio with a live preview.

Try the studio in your browser: https://muddyblack.github.io/kde-glassy-system-monitor/

---

### Features
* **One Widget, Your Layout:** Switch sections on, drag them into order, put them side by side in up to three columns, and give each its own size (S/M/L) and chart style. The card can never be sized so small that content is cut off.
* **Settings Studio:** Tabs, search, visual pickers and the real widget previewed live — on your machine's data or demo data, as a desktop card or a panel pill.
* **Looks:** Seven built-in looks, your own saved looks, and sharing as a JSON snippet. A look never carries commands or hosts, so an imported one cannot run anything.
* **GPU Charts:** Lines, areas, bars, donuts and pies are drawn by one fragment shader with a soft glow; the classic canvas renderer is one switch away.
* **Continuous Ping Graph:** A fluid line chart rendering ping response times in milliseconds, moving dynamically as new samples arrive.
* **Jitter & Packet Loss Alerts:** Visual indicators (color shifts to amber or red, pulsing alert ring around the widget) if latency spikes or packet loss exceeds a threshold.
* **Multi-target Tracking:** Define up to 4 custom hosts (e.g. your home gateway, Cloudflare/Google DNS, or a target lab device) and toggle between them directly using tab buttons in the widget.
* **CPU & Memory:** Overall CPU usage with optional per-core overlays, plus RAM and swap.
* **Network:** Upload/download bandwidth, session totals, per-interface selection, and an optional SSID / IP readout.
* **GPU with Per-Engine Breakdown:** Utilization and clock, plus an optional breakdown of VRAM, compute, decode, and encode engines — best-effort across NVIDIA, AMD, and Intel, showing only what your hardware exposes.
* **Disk, Power & Sensors:** Per-device read/write throughput, battery state and draw, and hardware temperatures with warning/critical thresholds.
* **Custom Command Section:** Chart the output of any shell command on an interval.
* **Chart Styles:** Line, filled area, history bars, donut, pie, meters, or numbers only.
* **Aesthetics:** Sleek dark-mode glass card with custom neon line colors, widths, glow effects, colour palettes, frosted-glass backdrop, customizable background transparency, and corner radiuses.
* **Full Stats Bar:** Live readouts of current jitter, packet loss percentage, and minimum/maximum latency history.
* **System Accent Integration:** Automatically matches your Plasma accent and text colors, or set your own custom colors per section.
* **Compact Panel Mode:** A condensed representation for placing the monitor in a panel.

---

### Requirements
To run this widget, you will need:
1. **KDE Plasma 6.2 or newer** (Qt 6.7+)
2. **plasma5support** — provides the `executable` data engine used for pinging and reading system stats.
3. **ping** (iputils) — standard on almost all Linux distributions.

Optional, for richer data when present (the widget degrades gracefully without them):
* **nvidia-smi** — NVIDIA GPU utilization, encode/decode, and VRAM.
* **sensors** (lm-sensors) — hardware temperature sensors.
* **iwgetid / iw / nmcli** — network SSID readout.

---

### Quick Install (Terminal)

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
kpackagetool6 -t Plasma/Applet -i package
```

To update an existing installation:
```bash
kpackagetool6 -t Plasma/Applet -u package
```

To uninstall:
```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitor
```

---

### Configuration
Right-click the widget and select "Configure Glassy System Monitor" to open the studio:
* **Presets** — built-in and saved looks, copy or import a look as JSON
* **Layout** — which sections show, their order (drag), size, chart style, columns, and the panel pill
* **Appearance** — chart style, history, curves, glow, labels; glass tint, frost, edge and corners; colour palettes and text colour
* **Sections** — per-section titles, colours, ping hosts and thresholds, devices, fetch tool and custom command
* **Performance** — GPU shader or canvas renderer, update interval, smooth scrolling and frame-rate cap
* **Info** — version check, project stats and links
