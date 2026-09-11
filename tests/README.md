Run from the repository root with Qt 6's `qmltestrunner` available:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmltestrunner -input tests
```

The rendering tests use the actual `BloomChart.qml`, `CpuSection.qml`, and
`ChartUtils.qml` with deterministic samples and mock configuration. They check
cached scrolling, canvas paint counts, sample handoffs, chart edges, axis
clipping, bloom layer updates, visibility, resizing, gauges, and smooth-scroll
toggling.

`SampleClock` tests cover a 500ms sensor stream, arrival jitter, and continuous
motion through early and late samples. `ScrollTicker` tests cover 15/24/60/140
FPS caps, variable frame timing, and delayed frames without catch-up bursts.

The software backend verifies pixel placement and paint scheduling; it does
not measure GPU bloom appearance, desktop CPU usage, or power consumption.
