# TODO

Open work for Glassy 2.0. After changes run `make test` (96 passing), `make docs` and `make gallery`.
`[x]` done · `[ ]` open · `[~]` started, not finished

## 1. Freeze after a while (plasmoidviewer, studio open)
The log shows `CanvasChart.qml:64 requestScrollPaint ... invalid context`: charts get callbacks after they are destroyed.

- [x] Stress script: `tools/stress.qml` cycles tabs, edits and looks and logs timings/RSS (set `QML_XHR_ALLOW_FILE_READ=1`).
- [x] Confirm the gallery guards in a visible window: **they do NOT fix it.** A visible window still stalls on edit 6 (one `update()` took 35.5 s).
- [x] **Only GPU rendering reproduces it** (2026-09-23, same repro `--mode edits-lw --period 250 --per 1`):
  - xcb + GPU: stalls ~30 s per edit · Wayland + GPU: stalls
  - Wayland + `QT_QUICK_BACKEND=software`: fine · offscreen + GPU: fine · offscreen + software (all earlier tests + `make test`): fine
  - So every headless run so far proved nothing. Always test with a real window and the GPU (`QT_QPA_PLATFORM=xcb`, no software backend).
- [x] **Culprit: `diagram/DiagramShader.qml`** (the GPU chart renderer, `Diagram.qml:54` `shaderCapable`)
  - `shaderCapable: false` (canvas renderer) → 40 edits, max 25 ms. Fixed.
  - Stubbing `BackdropBlur.geometrySignature` → still stalls (not it)
  - Inside DiagramShader: `data` Canvas `onInputsChanged: {}` (no repaint) → fixed; `chrome` `visible: false` → fixed (max 130 ms); `content` `layer.enabled: false` → still stalls
  - So: repainting the `data` Canvas while the **visible `chrome` ShaderEffect** samples it (`dataTex: data`) → a synchronous JS cascade (gdb: GC + JIT'd `Array.push`, allocating nonstop)
- [ ] **Next:** find the exact binding. Run `qmlprofiler --attach localhost -p 3768` against `tools/qml.sh -qmljsdebugger=port:3768,block ... tools/stress.qml -- ... --limit 8` (not run yet). Suspects: chrome's `grid`/`markers` (`normalised` `for…of` over `ticks`/`markers`), `plot` (`plotLeft`/`plotWidth`), and `onPaint` writing `gpu.encoded` (→ `data` width/height → repaint)
- [ ] Then fix it in DiagramShader and add a regression that runs with a real GPU window (the headless test can't catch it)
- [ ] Check whether the gallery guards (`LookGallery.qml` `savedJson` / `lookJson`) are still needed after the real fix; they only cut notifications
- [ ] Fix the `ShaderEffect: Texture ... not a valid texture provider (Shape)` warning: in `GlassCard.qml`, put the frost `MultiEffect` in a Loader

JS stack in gdb: `qt_v4StackTraceForEngine($rdi caught at QV4::ExecutionEngine::ExecutionEngine)` crashed (SIGSEGV, interrupted during GC). Use qmlprofiler instead.

gdb recipe (ptrace_scope=1, so gdb must launch the process): copy `tools/qml.sh`, replace the final `"$qml_bin" "$@"` with `gdb -q -batch -x "$GDBCMDS" --args "$qml_bin" "$@"`, and interrupt with `pkill -INT -x qml` from a background shell. Use `set print elements 0` to see the whole JS stack.

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

## Done
- [x] Better panel pill
  - [x] Several sections at once: `panelSections` chips under Layout › In a panel (none picked = the card's first section, `Sections.panelIds`); the core also samples pill sections the card leaves out (`MonitorCore.inPanel` → `sampledIds`)
  - [x] One shared reading per section, `SectionModels.pill` (label, one or two lines, widest sample, meter ratio, history): `CompactRepresentation.qml` rewritten on it (824 → ~270 lines, no per-section copies) and the website pill draws the same model
  - [x] Pill styles (`panelStyle`): values (with a meter for percentages), mini sparkline, mini bars
  - [x] Thin panels (< 30 px) put caption and value on one line, ↓/↑ side by side; vertical panels stack the readings and fit the text to the width (Plasma `formFactor`)
  - [x] Readings in fixed-width columns (`Format.short`, `SHORT_WIDEST`), so the panel never re-lays out as numbers change
  - [x] Short captions (CPU, RAM, Net, Temp, Uptime…) unless the user renamed the section (`Sections.shortTitle`)
  - [x] Values for every section, including storage (fullest mount), processes (top app), sensors, power and uptime
  - [x] Card on hover (`panelHoverCard`), click pins it: Plasma `toolTipItem` (charts run while it shows), Quickshell `MonitorPill` `PopupWindow`, studio panel preview, website panel preview
  - [x] "Shown in panels" badges follow the pill's sections (studio and website)
  - [x] Website: panel colours were Qt `#AARRGGBB` in CSS (cyan slots); panel sits near the top so the card fits below
  - [x] 4 tests in `tst_SharedLogic.qml`; checked in the studio, the website and a real Quickshell bar
- [x] Ruled out studio edits rebuilding every section (`tst_MonitorView::test_editsDoNotRebuildSections` guards it)
- [x] Terminal style
  - [x] "Terminal" palette in `Schema.js`
  - [x] Monospace font option: every `Text` in the widget takes `font.family` from `monitor.fontFamily`; `Diagram` needs a `fontFamily` prop for the axis labels
  - [x] "Terminal" built-in look: black solid card, square corners, mono font, green palette, bars
  - [x] Website: a `--font` variable on `.gw`
- [x] Smaller fixes
  - [x] Interface "Automatic" follows the default route (`Probes.autoInterface`)
  - [x] Show it in the widget header menu too ("Automatic · wlp2s0")
  - [x] README: materials, the new looks (Liquid Glass, Paper, Atmosphere), colour by load, spacing, storage, processes
  - [x] Hyprland blur rule note in `Schema.js` NOTES: check it against the new `layerrule` syntax
  - [x] `NetworkConnections.qml`: garbled characters in the comments at the popup's `y` (a UTF-8 arrow saved wrongly)
- [x] Freeze investigation findings (2026-09-23)
  - [x] **Reproducible.** Stress script: `tools/stress.qml` (with `--mode`, `--period`, `--per`, `--limit` flags). Run it with `QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/stress.qml -- --mode edits-lw --period 250 --per 1`. Without that env var, its XHR reads of `main.xml` and `/proc/self/status` throw, which is why the first run printed nothing.
  - [x] **Trigger:** studio edits (`studio.update({...})` → host sets `draft`). Tab switching alone and look changes alone do not hang. Either key alone hangs it (`lineWidth` or `bgRadiusTL`), so it is not about one setting.
  - [x] **Count-based, not time-based:** it stops after about 8–11 edits, whether they are 16 ms or 250 ms apart. RSS stays flat (~250 MB), so it is not a leak.
  - [x] **One `update()` call never returns.** The log shows "before update N" with no "after". It is a synchronous endless loop on the GUI thread (main thread at 100% CPU; the render and other threads idle). Not a deadlock.
  - [x] **Not the JIT** (hangs the same with `QV4_FORCE_INTERPRETER=1`) and **not the incremental GC** (`QV4_GC_TIMELIMIT=0` hangs too). The GC shows up in every stack only because the loop allocates nonstop.
  - [x] **C++ stack during the hang** (gdb, interpreter mode): Timer → `studio.update` → `edited` → host sets `draft` → **six nested `QQmlBinding::slowWrite → emitNotify` levels** (the draft handed down through the studio and preview into the views) → one binding that runs an **array `for…of` loop that never ends** (`ArrayIteratorPrototype::method_next` → `createIterResultObject`, allocating every step).
  - [x] JS stack samples (via `qt_v4StackTraceForEngine` in gdb) landed in bindings reached straight from that draft assignment: `MonitorView.qml:19` (`sectionIds` → `Sections.parse`), `DiagramShader.qml:104` (`markers` → `normalised`), `DiagramShader.qml:48` (`inputs`). These are candidates for the looping `for…of`, not yet confirmed.
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


## Freeze investigation follow-up (2026-09-23)

- The existing `savedJson` guard prevents unrelated draft edits from recreating the gallery model. Kept it.
- Added a second guard at each tile: `Looks.apply` creates a fresh object even when applying that preset produces identical settings. `lookJson` compares the values before publishing a new `look` object to the full chart preview. Device and other retained settings still propagate when changed.
- Added `Studio::test_presetTilesSurviveRepeatedEdits`: 100 edits preserve the gallery model, tiles and unchanged preview settings; device changes propagate; saved looks can still be added and removed. In a temporary copy, the original saved binding fails the model check; the prior savedJson-only fix fails the preview-settings check. Both pass with the two guards.
- `make test`: 92 passed, 0 failed. Presets stress: 300 rounds / 900 edits completed, final RSS about 181 MB, using Qt 6.11.1 with the offscreen/software backend.
- Mixed stress also completed: 300 rounds of tab switches, 900 edits and periodic look changes; final RSS about 185 MB.
- **Superseded (see section 1):** with a real GPU window the patched code still stalls; the cause is `DiagramShader.qml`.
- **Limit:** the original code also completes with this headless backend. These tests establish removal of unnecessary notifications, not proof that the desktop freeze is resolved. The sandbox denies access to the Wayland/X11 display; visible Plasma/GPU confirmation remains open.
- Earlier references above to a single infinite `for…of` loop are historical hypotheses, not a confirmed diagnosis. Different binding samples support repeated binding evaluation, but do not identify its complete cause.
