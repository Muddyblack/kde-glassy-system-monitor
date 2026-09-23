[h1]Glassy System Monitor[/h1]

A sleek glassmorphism real-time system monitor for KDE Plasma 6 and Hyprland (via Quickshell).

One widget displays any combination of twelve system metrics — CPU, memory, network, ping, GPU, disk I/O, storage, top processes, power, sensors, system info, and custom commands — in whatever order you like, stacked or side-by-side in up to three columns. Everything is rendered via GPU fragment shaders with an analytic glow, and configured through an interactive studio with a real-time live preview.

[b]Try the studio in your browser:[/b] [url=https://muddyblack.github.io/kde-glassy-system-monitor/]Interactive Studio[/url]

---

[b]Features[/b]
[list]
[*] [b]One Widget, Any Layout:[/b] Toggle any of the 12 sections, drag to reorder, arrange into 1–3 columns, and customize size (S/M/L) and chart style per section.
[*] [b]Interactive Settings Studio:[/b] Full live preview with real or demo data, search, undo ([kbd]Ctrl+Z[/kbd]), and wallpaper picker.
[*] [b]11 Ready-Made Looks:[/b] Liquid Glass, Paper, Atmosphere, Terminal, Neon, Gaming, and more. Save custom looks and share them as JSON.
[*] [b]GPU-Accelerated Charts:[/b] Fragment-shader rendering for silky-smooth line, area, bar, donut, and pie charts with an analytic glow (or fallback canvas).
[*] [b]Card Materials & Theming:[/b] Glass, liquid glass, solid, atmosphere, blur, refraction, and custom corner radii. Matches Plasma accent or custom palettes.
[*] [b]Deep Hardware Monitoring:[/b] Per-core CPU graphs, RAM & swap, multi-target ping with jitter/loss alerts, GPU engine breakdown (NVIDIA, AMD, Intel), per-device disk I/O, storage mounts, battery draw, and temperatures.
[*] [b]Network Window & Diagnostics:[/b] Click ⧉ to inspect connections, active apps, open ports, containers, VPN status, browser tabs, and traffic history — all without root. Wireshark integration ready.
[*] [b]Top Processes & Shell Commands:[/b] Live process list sorted by CPU/RAM and custom shell command polling.
[*] [b]Compact Panel Pill:[/b] Condensed status bar mode for panels and docks.
[*] [b]Plasma 6 & Hyprland:[/b] Native KDE Plasma 6 plasmoid and standalone Quickshell layer on Hyprland.
[/list]

---

[b]Companion Widget[/b]
Looking for a matching desktop audio visualizer with the same glass aesthetic and studio?
Check out [url=https://www.opendesktop.org/p/2359422/][b]Plasma Audio Visualizer[/b][/url]!

---

[b]Requirements[/b]
To run this widget, you will need:
[list]
[*] [b]KDE Plasma 6.2+[/b] (Qt 6.7+) or [b]Quickshell[/b] on Hyprland.
[*] [b]plasma5support[/b] — provides the executable data engine.
[*] [b]ping[/b] (iputils) — for network latency monitoring.
[/list]

[i]Optional for extra stats:[/i] [b]ksystemstats[/b] (Plasma daemon), [b]nvidia-smi[/b] (NVIDIA GPU), [b]lm-sensors[/b] (temperatures), [b]mmdblookup[/b] (GeoIP in network window), [b]wireshark[/b].

---

[b]Quick Install (Terminal)[/b]

[code]
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
kpackagetool6 -t Plasma/Applet -i package
[/code]

To update an existing installation:
[code]
kpackagetool6 -t Plasma/Applet -u package
[/code]

To uninstall:
[code]
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitor
[/code]

---

[b]Configuration[/b]
Right-click the widget and select [b]Configure Glassy System Monitor[/b] to open the studio:
[list]
[*] [b]Presets:[/b] Pick built-in looks, save your own, or import/export as JSON.
[*] [b]Layout:[/b] Choose sections, reorder, set columns, spacing, sizes, and panel pill.
[*] [b]Appearance:[/b] Materials (glass, liquid, solid), glow, curves, palettes, text, and corners.
[*] [b]Sections:[/b] Set ping targets, device filters, thresholds, fetch commands, and custom colors.
[*] [b]Performance:[/b] Toggle GPU shader vs. canvas, update interval, and FPS cap.
[*] [b]Info:[/b] Version check, project stats, and links.
[/list]
