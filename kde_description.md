# Glassy System Monitor

A sleek glassmorphism real-time system monitor (CPU, Memory, Ping latency, and Network bandwidth) for KDE Plasma 6. Renders latency (ping), stability (jitter), and reliability (packet loss) in a beautiful, custom-colored neon curve over a semi-transparent glassy background.

---

### Features
* **Continuous Ping Graph:** A fluid line chart rendering ping response times in milliseconds, moving dynamically as new samples arrive.
* **Jitter & Packet Loss Alerts:** Visual indicators (color shifts to amber or red, pulsing alert ring around the widget) if latency spikes or packet loss exceeds a threshold.
* **Multi-target Tracking:** Define up to 4 custom hosts (e.g. your home gateway, Cloudflare/Google DNS, or a target lab device) and toggle between them directly using tab buttons in the widget.
* **Aesthetics:** Sleek dark-mode glass card with custom neon line colors, widths, glow effects, customizable background transparency, and corner radiuses.
* **Full Stats Bar:** Live readouts of current jitter, packet loss percentage, and minimum/maximum latency history.

---

### Requirements
* **KDE Plasma 6**
* **plasma5support** (provides the `executable` data engine used for pinging)
* **ping** (standard on almost all Linux distributions)

---

### Quick Install (Terminal)

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
./test_install.sh
```

To uninstall:
```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitorTest
```
