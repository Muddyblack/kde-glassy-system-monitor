[h1]Glassy System Monitor[/h1]


Glassy is a glassy, [b]riceable[/b] system monitor for KDE Plasma 6, and now also for Hyprland through Quickshell. Pick the stats you care about, drag them into order, put them side by side, and style the card however you like. Charts are drawn on the GPU, and everything is set up in a studio with a live preview.

[b]Try the studio in your browser:[/b] [url=https://muddyblack.github.io/kde-glassy-system-monitor/]Interactive Studio[/url]

---

[b]Features[/b]
[list]
[*] [b]Pick Your Stats:[/b] CPU, memory, network, ping, disk I/O, storage, GPU, processes, load & uptime, fans, temperatures, power & battery, systemd services, containers & Kubernetes pods, system info, and your own commands.
[*] [b]Any Layout:[/b] One to three columns, any order, and a size and chart style per section.
[*] [b]Live Settings Studio:[/b] Every change previews instantly, on your real data or demo data.
[*] [b]Ready-Made Looks:[/b] Liquid Glass, Paper, Neon, Terminal, Gaming and more. Save your own and share them as JSON.
[*] [b]GPU Charts:[/b] Line, area, bars, donut, pie and meters, with an optional glow.
[*] [b]Glass Materials:[/b] Tint, glass, liquid glass, solid and atmosphere, with wallpaper blur and refraction.
[*] [b]Power & Battery:[/b] Charge, time left, health, cycles, real watts from CPU and GPU sensors, and one-click power profiles.
[*] [b]Network Window:[/b] Connections per app, open ports, containers, VPN, traffic history and a Threats page (opt-in blocklists), all without root.
[*] [b]Panel Pill:[/b] Values, sparklines or mini bars in your panel, or tray mode that cycles through them.
[*] [b]Remote Machines:[/b] Watch a server or another PC over SSH with the same card.
[*] [b]Plasma and Hyprland:[/b] A Plasma 6 widget, or a desktop layer and bar pill with Quickshell.
[/list]

---

[b]Companion Widget[/b]
Want a matching audio visualizer with the same glass look and studio? Check out [url=https://www.opendesktop.org/p/2359422/][b]Plasma Audio Visualizer[/b][/url]!

---

[b]Requirements[/b]
To run the widget, you will need:
[list]
[*] [b]KDE Plasma 6.2+[/b] with [b]kpackagetool6[/b], or [b]Quickshell[/b] for the Hyprland version.
[*] [b]plasma5support[/b] (the executable data engine) and [b]ping[/b] (iputils).
[/list]

Optional, for the sections that use them: [b]lm-sensors[/b] (temperatures and fans), [b]power-profiles-daemon[/b] (profile buttons), [b]nvidia-smi[/b] (NVIDIA GPUs), [b]docker[/b], [b]podman[/b] or [b]kubectl[/b] (containers), and a [b]fetch tool[/b] such as fastfetch (system info). Everything else works without them.

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

---

[b]Configuration[/b]
Right-click the widget to open its settings studio and customize:
[list]
[*] Looks: choose a ready-made look, save your own, or share one as JSON
[*] Sections, their order, columns, sizes and chart styles
[*] The panel pill: which stats, style, tray mode and icons
[*] Card materials, glass, shadows, corners, colours and fonts
[*] Per section: ping hosts, devices, thresholds, watched services, container sources and more
[*] A remote machine to monitor over SSH
[*] Renderer, update interval and frame rate
[/list]
