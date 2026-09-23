# Tests

Run from the repository root:

```sh
make test
```

That runs `qmltestrunner` through `tools/qml.sh`, which keeps the desktop
session's Qt build out of the process (on NixOS, mixing it with the dev
shell's Qt fails to load), on the software backend and offscreen.

- `tst_CanvasChart.qml` — the canvas renderer's frame cache: cached scrolling,
  paint coalescing, chart edges, axis clipping, bloom layers, visibility,
  resizing, gauges and the smooth-scroll switch.
- `tst_MonitorView.qml` — sections in the chosen order and grid, spanning
  rows, size classes, the numbers-only style, and the sizing guarantee: at the
  card's minimum height every section still gets its own minimum. Also the
  `Diagram` fallback to canvas without a GPU and axis-label thinning.
- `tst_Studio.qml` — tabs and search, the section list (keeping one section,
  drag-and-drop slots, sizes, spans, styles) and saving looks.
- `tst_SharedLogic.qml` — the JavaScript shared with the website: section
  parsing and grid placement, the shader's data-texture encoding, looks
  (commands and hosts are never imported), the studio schema against
  `main.xml`, the section models, and the shell-probe parsers (`Probes.js`:
  interfaces, `df`, `/proc`) with the demo data that runs through them. The
  network window's parsers and session model too: real `ss -tunapiH` output,
  listening ports and their exposure, address kinds, reverse DNS / GeoIP
  lines, .desktop matching and helper grouping, live rates and ended
  connections, filters, DNS counters and interface details; the traffic
  history (recording, summaries, refusing foreign or newer files, pruning)
  and the browser-tab matching (a real mozlz4 session, Chromium lists,
  shell-safe commands).
- `tst_SampleClock.qml`, `tst_ScrollTicker.qml` — sample timing and the
  frame-rate cap.

The software backend cannot run the fragment shader. `make parity` shows the
GPU and canvas renderers side by side on a real GPU; `make benchmark`
measures their CPU use.
