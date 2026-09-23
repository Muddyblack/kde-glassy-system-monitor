# TODO

Open work for Glassy 2.0. Run `make test` (90 passing), `make docs` and `make gallery` after changes.

## 1. Freeze after a while (plasmoidviewer, studio open): not fixed
- The log shows `CanvasChart.qml:64 requestScrollPaint ... invalid context`: charts get callbacks after they are destroyed.
- Ruled out: studio edits rebuilding every section. `tst_MonitorView::test_editsDoNotRebuildSections` guards this.
- Next step: run a stress test that cycles tabs, sliders and looks, and watch ms per round and RSS.
  - The script is in the old session's scratchpad (`stress.qml`); run it via `tools/qml.sh`.
  - Its first headless run printed nothing. Check it with a visible window.
- Suspects:
  - Charts disconnect callbacks late when destroyed (`CanvasChart` / `DiagramCanvas`).
  - The live `ShaderEffectSource` in the glass material (`card/BackdropBlur.qml`).
  - The new probes (`ShellProbe.qml`) running on the preview core.
- Also fix the `ShaderEffect: Texture ... not a valid texture provider (Shape)` warning: in `GlassCard.qml`, put the frost `MultiEffect` in a Loader.

## 2. Network details popup ("like Portmaster"): not started
- Clicking the network section opens a detail page (Plasma popup / Quickshell window) with:
  - Every interface as a card: kind, state, IP, MAC, link speed, current rates (`MonitorCore.interfaces`, `ifaceRates`).
  - Active connections per app: `ss -tupnH` gives process, remote host:port and protocol, grouped by app (reuse `NetworkConnections.qml`).
  - Optionally reverse DNS / country, and per-app traffic (needs `nethogs` or eBPF, so it may not be possible without root).
- The studio's Network tab should show interface cards instead of the plain select. `networkInterface` currently uses `opts: "ifaces"` in `Schema.js`.

## 3. Terminal style: half done
- Done: a "Terminal" palette in `Schema.js`.
- Missing:
  - A monospace font option. Every `Text` in the widget needs `font.family` from `monitor.fontFamily`, and `Diagram` needs a `fontFamily` prop for the axis labels.
  - A "Terminal" built-in look: black solid card, square corners, mono font, green palette, bars.
  - Website support: a `--font` variable on `.gw`.

## 4. Better panel pill
- Today the pill (`CompactRepresentation.qml`) shows only the first section, and clicking opens the full card.
- Wanted:
  - A small pill that can show several sections at once (tiny sparklines or values next to each other); the user picks which.
  - Hovering the pill shows the full desktop card as a popup (Plasma `toolTipItem` / a hover popup; on Quickshell a `PopupWindow`), the same `MonitorView` with the same look. Clicking pins it open.
  - Pill styles: values only, mini sparkline, mini bars. Also a size that fits thin panels, and vertical panels.
- The studio's panel preview (`PreviewPane.qml`, "Panel" form) should show the hover card too, and the website's panel preview needs to match.
- The widget pill has no value for storage / processes (it falls back to the custom value). The website pill already uses the section model's reading for them.

## 5. Smaller
- Interface detection: "Automatic" now follows the default route (`Probes.autoInterface`). Show it in the widget header menu as well ("Automatic · wlp2s0").
- README: mention the materials, the new looks (Liquid Glass, Paper, Atmosphere), colour by load, spacing, storage, processes. Update the Hyprland blur rule note in `Schema.js` NOTES for the new `layerrule` syntax if needed.
- Nothing is committed yet.

## Done this session
- Storage + Top processes finished:
  - Demo data goes through the real parsers: `DemoData.DF` (raw `df` output) and `DemoData.procSnapshot(i)` (/proc-shaped), ranked by `Probes.topProcesses`, in `DemoFeeder.qml` and on the website. Mount filter, sort, row count and grouping all show in the preview.
  - Website: `Probes.js` is in the site build; `SECTION.storage/processes` render the `SectionModels` rows (`barList` in `app.js`, `.gw-brow` in `glassy.css`).
  - `Format.usage` ("1.1 / 1.8 TiB") keeps storage rows short enough for the bar; the value column grows to fit "942.5 MiB"; rows stay packed next to a taller grid neighbour.
  - Tests: 9 new in `tst_SharedLogic.qml` (interfaces, auto interface, storage, mount list, wrapper names, /proc snapshot, ranking, demo plausibility, `Format.usage`).
  - Checked visually: widget (2 columns, CPU and memory sort) and website studio.
- Card materials from the audio visualizer: tint / glass / liquid glass / solid / atmosphere, with blur, refraction, pointer light, glass tint, opacity, shadow and grain. They work in the widget, the studio tiles and the website. Solid switches the text to dark ink (`Sections.textColor`).
- Colour by load (CPU / RAM / GPU), spacing (compact / normal / roomy).
- Sections sub-tabs list only the enabled sections.
- Palette chips bug fixed (single-choice chips).
- `make config` / `tools/config_keys.py`: the Plasma settings page's key list is generated from main.xml. It had been missing `layoutColumns`, `sectionSpans`, `sectionSizes` and `userPresets`, so those were not saving on KDE.
- `make shaders` builds every `.frag`.
- `gallery.qml`: studio shots now show the right tab.
