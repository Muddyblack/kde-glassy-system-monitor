# Glassy System Monitor

A sleek glassmorphism real-time system monitor for KDE Plasma 6. Tracks ping, CPU, memory, network, GPU, disk, power, and sensors in one place — rendered as fluid, custom-colored neon curves over a semi-transparent glassy card. What sets it apart from the built-in monitors is the ping section: live RTT graphs with jitter and packet loss, not just bandwidth.

---

### Features
* **Continuous Ping Graph:** A fluid line chart rendering ping response times in milliseconds, moving dynamically as new samples arrive.
* **Jitter & Packet Loss Alerts:** Visual indicators (color shifts to amber or red, pulsing alert ring around the widget) if latency spikes or packet loss exceeds a threshold.
* **Multi-target Tracking:** Define up to 4 custom hosts (e.g. your home gateway, Cloudflare/Google DNS, or a target lab device) and toggle between them directly using tab buttons in the widget.
* **CPU & Memory:** Overall CPU usage with optional per-core overlays, plus RAM and swap.
* **Network:** Upload/download bandwidth, session totals, per-interface selection, and an optional SSID / IP readout.
* **GPU with Per-Engine Breakdown:** Utilization and clock, plus an optional breakdown of VRAM, compute, decode, and encode engines — best-effort across NVIDIA, AMD, and Intel, showing only what your hardware exposes.
* **Disk, Power & Sensors:** Per-device read/write throughput, battery state and draw, and hardware temperatures with warning/critical thresholds.
* **Custom Command Section:** Chart the output of any shell command on an interval.
* **Multiple Chart Styles:** Line, bars, donut, pie, and horizontal bar.
* **Aesthetics:** Sleek dark-mode glass card with custom neon line colors, widths, glow effects, optional GPU-accelerated bloom, frosted-glass backdrop, customizable background transparency, and corner radiuses.
* **Full Stats Bar:** Live readouts of current jitter, packet loss percentage, and minimum/maximum latency history.
* **System Accent Integration:** Automatically matches your Plasma accent and text colors, or set your own custom colors per section.
* **Compact Panel Mode:** A condensed representation for placing the monitor in a panel.

---

### Requirements
To run this widget, you will need:
1. **KDE Plasma 6**
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
Right-click the widget and select "Configure Glassy System Monitor" to customize:
* Ping hosts (up to 4), interval, timeout, and history length
* Latency and packet-loss alert thresholds
* Which sections are shown, their titles, and per-section colors
* GPU per-engine breakdown (VRAM, compute, decode, encode)
* Network SSID / IP readout
* Chart style, line width, smoothing, and glow / GPU bloom
* Background card visibility, transparency, corner radius, and frosted glass
* System accent integration or custom colors and text color
