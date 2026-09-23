# TODO

Open work for Glassy 2.0. After changes run `make test` (90 passing), `make docs` and `make gallery`.
`[x]` done · `[ ]` open · `[~]` started, not finished

## 1. Freeze after a while (plasmoidviewer, studio open)
The log shows `CanvasChart.qml:64 requestScrollPaint ... invalid context`: charts get callbacks after they are destroyed.

- [x] Ruled out: studio edits rebuilding every section (`tst_MonitorView::test_editsDoNotRebuildSections` guards it)
- [ ] Stress test that cycles tabs, sliders and looks; log ms per round and RSS
  - The script is `stress.qml` in the old session's scratchpad; run it via `tools/qml.sh`
  - Its first headless run printed nothing, so check it with a visible window
- [ ] Check suspects:
  - [ ] Charts disconnect callbacks late when destroyed (`CanvasChart` / `DiagramCanvas`)
  - [ ] The live `ShaderEffectSource` in the glass material (`card/BackdropBlur.qml`)
  - [ ] The probes (`ShellProbe.qml`) running on the preview core
- [ ] Fix the `ShaderEffect: Texture ... not a valid texture provider (Shape)` warning: in `GlassCard.qml`, put the frost `MultiEffect` in a Loader

## 2. Network window ("like Portmaster")
A button in the network section header (next to "○ connections") opens a **separate, normal window**: resizable, with a title bar, its own taskbar entry, and closable. The small `NetworkConnections.qml` popup stays for a quick look. The window is read-only: Glassy monitors and never blocks anything.

Host:
- [ ] One shared `NetworkWindow.qml` (a QtQuick `Window` with the studio's look and theme)
- [ ] Plasma: open it from the plasmoid; a `Window` created from the widget works in plasmashell
- [ ] Quickshell: `FloatingWindow`, plus an IPC call `network open` like `settings open`
- [ ] Remember the window's size, position and last tab

Data (no root; what `ss` shows for other users' processes is limited, so say so in the UI):
- [ ] `Probes.CONNECTIONS_CMD` + parser: `ss -tunapiH` gives protocol, state, local and remote address:port, process + PID, and for TCP `bytes_sent` / `bytes_received`, rtt and cwnd
- [ ] Per-connection traffic: the difference in bytes between polls = the live rate per connection and per app
- [ ] Listening ports: `ss -tulpnH`, which app listens where, and whether it is local only (127.0.0.1 / ::1) or open to the network (0.0.0.0 / ::)
- [ ] Reverse DNS with a cache (`getent hosts`; never block the UI; time limit per lookup)
- [ ] Country + ASN / owner: from a local GeoIP database if one is installed (db-ip / MaxMind mmdb via `mmdblookup`), otherwise hidden. No online lookups by default
- [ ] Recognise local, LAN, multicast and loopback addresses and label them
- [ ] App identity: process name → `.desktop` file → icon and nice name; group helpers under the app (Portmaster-style "Firefox" instead of 9 processes)
- [ ] DNS view where possible: `resolvectl statistics` / cache; per-query logging needs root, so optional or skipped
- [ ] Session history: connections that ended stay listed (greyed) until the window closes
- [ ] Parser tests in `tst_SharedLogic.qml` with real `ss` output; demo data for the preview and website

Window pages:
- [ ] **Overview**: total up / down live chart, active connection count, apps online, top apps and top countries / domains by traffic
- [ ] **Apps**: list of apps with icon, connection count and live rate; expand for each connection (domain, IP, port, protocol, country, state, bytes in/out, duration)
- [ ] **Connections**: flat sortable and filterable table (app, domain, IP, port, protocol, direction, state, country, bytes, since)
- [ ] **Listening**: open ports per app, warning colour for ports open to the network
- [ ] **Interfaces**: one card per interface: kind, state, IPv4/IPv6, MAC, link speed, gateway, DNS servers, Wi-Fi SSID / signal / band where available, live rates (`MonitorCore.interfaces`, `ifaceRates`)
- [ ] Search across everything, filters (app, protocol, direction, local/internet, country), pause / resume
- [ ] Per-row actions: copy IP / domain, open the address in a whois / map page (only on click), end the process (with confirmation)
- [ ] Same look as the studio, dark / light, keyboard navigation

Also:
- [ ] The studio's Network tab shows interface cards instead of the plain select (`networkInterface` uses `opts: "ifaces"` in `Schema.js`)
- [ ] Website: a screenshot or demo of the window

## 3. Terminal style
- [x] "Terminal" palette in `Schema.js`
- [ ] Monospace font option: every `Text` in the widget takes `font.family` from `monitor.fontFamily`; `Diagram` needs a `fontFamily` prop for the axis labels
- [ ] "Terminal" built-in look: black solid card, square corners, mono font, green palette, bars
- [ ] Website: a `--font` variable on `.gw`

## 4. Better panel pill
Today the pill (`CompactRepresentation.qml`) shows only the first section, and clicking opens the full card.

- [ ] Several sections at once (tiny sparklines or values side by side); the user picks which
- [ ] Hovering shows the full desktop card as a popup (Plasma `toolTipItem` / hover popup; Quickshell `PopupWindow`): the same `MonitorView` with the same look. Clicking pins it open
- [ ] Pill styles: values only, mini sparkline, mini bars
- [ ] Sizes that fit thin panels, and vertical panels
- [ ] Values for storage / processes (the widget falls back to the custom value; the website pill already uses the section model's reading)
- [ ] Studio panel preview (`PreviewPane.qml`, "Panel" form) shows the hover card too; the website's panel preview matches

## 5. Smaller
- [x] Interface "Automatic" follows the default route (`Probes.autoInterface`)
- [ ] Show it in the widget header menu too ("Automatic · wlp2s0")
- [ ] README: materials, the new looks (Liquid Glass, Paper, Atmosphere), colour by load, spacing, storage, processes
- [ ] Hyprland blur rule note in `Schema.js` NOTES: check it against the new `layerrule` syntax
- [ ] `NetworkConnections.qml`: garbled characters in the comments at the popup's `y` (a UTF-8 arrow saved wrongly)

## Done
- [x] Storage + Top processes sections
  - [x] Parsers in `Probes.js`, checked against real output; `ShellProbe.qml`, core `storage` / `processes`, `BarListSection.qml`, `SectionModels.storage/processes`, Sections.js entries, config keys, Schema tabs
  - [x] Demo data goes through the real parsers (`DemoData.DF`, `DemoData.procSnapshot`) in `DemoFeeder.qml` and on the website
  - [x] Website: `Probes.js` in the site build, `SECTION.storage/processes`
  - [x] `Format.usage` ("1.1 / 1.8 TiB"); value column fits "942.5 MiB"; rows stay packed next to a taller neighbour
  - [x] 9 tests in `tst_SharedLogic.qml`; checked visually in the widget and on the website
- [x] qmlformat pre-commit hook: it fails silently on ids starting with `_`; renamed them in `PowerSection.qml`
- [x] Card materials from the audio visualizer: tint / glass / liquid glass / solid / atmosphere, with blur, refraction, pointer light, glass tint, opacity, shadow and grain (widget, studio tiles, website). Solid switches the text to dark ink (`Sections.textColor`)
- [x] Colour by load (CPU / RAM / GPU), spacing (compact / normal / roomy)
- [x] Sections sub-tabs list only the enabled sections
- [x] Palette chips bug (single-choice chips)
- [x] `make config` / `tools/config_keys.py`: the Plasma settings key list is generated from main.xml (`layoutColumns`, `sectionSpans`, `sectionSizes`, `userPresets` were not saving on KDE)
- [x] `make shaders` builds every `.frag`
- [x] `gallery.qml`: studio shots show the right tab
- [x] First 2.0 commit (`c60037c`)
