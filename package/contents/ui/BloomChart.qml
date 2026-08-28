// Split-layer chart with GPU bloom.
//
// A section's chart has two visual parts: the *data lines* (which should glow)
// and the *axis / grid / labels / fill* (which must stay crisp — blurring text
// looks broken). To bloom only the lines, we draw the same paint routine onto
// TWO stacked canvases:
//
//   • linesCanvas — draws ONLY the glowable strokes (glowPass === true). It is
//     the source for a MultiEffect blur, composited UNDER the crisp chart to
//     read as a halo, at ~zero CPU cost.
//   • mainCanvas  — draws the full chart (axis, grid, fill, crisp lines) with
//     the in-canvas glow suppressed, so it sits sharp on top of the bloom.
//
// When gpuBloom is OFF we collapse to a single canvas using the in-canvas
// wide-stroke glow — zero behavioural change, no extra layer cost.
//
// Usage: give `paint` a function(ctx, glowPass) that runs the section's draw
// logic. Read glowPass to decide whether to emit only the glowing strokes.
// Bind `dataIntervalMs` to the cadence of the section's data. Call
// `requestPaint()` when the DATA or the styling changed, and
// `requestScrollPaint()` on every scroll tick.
import QtQuick
import QtQuick.Effects

Item {
    id: chart

    // function(ctx, glowPass): the section's draw routine. glowPass===true means
    // "draw only the strokes that should bloom, nothing else".
    property var paint: null

    // Bloom is active only when the user enabled it AND glow is on at all.
    readonly property bool bloomActive: plasmoid.configuration.gpuBloom && plasmoid.configuration.glowLine
    // 0.25..1.0 mapped from the bloomStrength slider — keeps a visible minimum.
    readonly property real bloomBlur: 0.25 + 0.75 * Math.max(0, Math.min(1, plasmoid.configuration.bloomStrength))

    // ── repaint pacing ───────────────────────────────────────────────────────
    // The ticker in main.qml runs at the configured frame rate and this chart
    // repaints on every N-th tick. N is normally 1 — a chart with a visibly
    // moving line paints every frame, which is the only thing that looks
    // properly smooth. N only climbs for a chart whose line moves less than
    // root.scrollPaintStepPx per frame, i.e. one fed so rarely that a frame
    // cannot show its motion anyway (a custom command polled every two minutes
    // crawls at a thousandth of a pixel per frame).
    //
    // N is a whole number of ticks on purpose. Repainting once the line has
    // measurably travelled far enough sounds equivalent and is not: that test
    // falls due after one tick sometimes and two the next, and a repaint
    // cadence alternating between 42 ms and 84 ms reads as stutter even though
    // its average rate is right. An integer share of an even tick is even.

    // Cadence of the data behind this chart, in ms — sections bind their own
    // measured interval. Those are EMA-smoothed and so drift slightly on every
    // update, hence the rounding below: a divisor that flip-flops between two
    // values would be a stutter of its own.
    property real dataIntervalMs: 1000

    // Pixels this chart travels per data interval: exactly one history step,
    // since each update shifts the series along by one sample. Measured on THIS
    // chart's width rather than the popup's, which is what makes a narrow chart
    // pace itself correctly; the axis gutter inside it is not subtracted, so it
    // still reads slightly fast, and a repaint spent early is never wrong.
    readonly property real scrollStepPx: width / Math.max(1, Math.max(10, plasmoid.configuration.historySize) - 1)

    // Chart types 3 (donut), 4 (pie) and 5 (horizontal bars) are gauges: they
    // render the current value rather than a scrolling window, so a scroll tick
    // cannot change a single pixel of them. They repaint on new data like
    // everything else — they just stop paying for frames in between. A section
    // that diverges from the global chart type can override this.
    property bool scrolling: (plasmoid.configuration.chartType || 0) < 3

    // Ticks between repaints. Paced off the frame interval rather than the live
    // one, so dropping to the stall probe (see _renderStalled) cannot silently
    // rescale everyone's share of it.
    readonly property int paintEveryTicks: {
        const tick = root._tickFloorMs;
        if (!(scrollStepPx > 0) || !(tick > 0))
            return 1;
        const data = Math.max(100, Math.round(dataIntervalMs / 100) * 100);
        // Time this chart needs to travel one paint step.
        const ms = root.scrollPaintStepPx * data / scrollStepPx;
        return Math.max(1, Math.round(ms / tick));
    }

    // Called on every scroll tick; draws on this chart's share of them.
    function requestScrollPaint() {
        if (!scrolling || (root.scrollTick % paintEveryTicks) !== 0)
            return;
        root.notePaintRequested();
        mainCanvas.requestPaint();
        // The halo is fed through a blur of up to 32 px and cannot resolve a
        // sub-pixel shift, so it is refreshed on every second repaint: that
        // keeps it within one frame of travel — under a tenth of a pixel at the
        // defaults — of the line it belongs to, and halves the cost of the
        // widget's most expensive layer.
        if (bloomActive && (root.scrollTick % (paintEveryTicks * 2)) === 0)
            linesCanvas.requestPaint();
    }
    // Unconditional repaint: new data, a colour change, a resize. The chrome
    // rides on this one and NOT on the scroll tick — that is the whole point of
    // it, see chromeCanvas.
    function requestPaint() {
        root.notePaintRequested();
        chromeCanvas.requestPaint();
        mainCanvas.requestPaint();
        if (bloomActive)
            linesCanvas.requestPaint();
    }

    // Toggling bloom on/off (or glow off) changes what BOTH canvases must draw:
    //   • bloom ON  → mainCanvas must SUPPRESS its CPU glow (cu.glowFor → 0) and
    //                 linesCanvas must (re)draw to feed the halo.
    //   • bloom OFF → mainCanvas must redraw WITH the in-canvas glow back.
    // Without this, the last cached paint sticks and the glow appears to vanish.
    onBloomActiveChanged: {
        mainCanvas.requestPaint();
        linesCanvas.requestPaint();
    }

    // ── bloom halo (GPU), drawn UNDER the crisp chart ─────────────────────────
    // Instead of using a separate MultiEffect sibling item and opacity:0 (which
    // causes layout/positioning drift and initialization bugs in the scene graph),
    // we apply MultiEffect directly as a layer.effect. Since visible is bound to
    // bloomActive, the canvas is only visible/active when needed, ensuring its
    // layout coordinates are perfectly updated and it repaints correctly when toggled.
    Canvas {
        id: linesCanvas
        anchors.fill: parent
        visible: chart.bloomActive
        z: 0
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        layer.enabled: chart.bloomActive
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: chart.bloomBlur
            blurMax: 32
            // Keep brightness low so the halo stays the LINE's color instead of
            // washing toward white, and push saturation up so it reads as a vivid
            // neon glow rather than a milky haze.
            brightness: 0.10
            saturation: 0.45
            // autoPadding ON: lets the blur spread past the canvas edges and fade
            // softly. With it off the glow was sliced flat at the chart border.
            autoPaddingEnabled: true
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (chart.bloomActive && chart.paint)
                chart.paint(ctx, true);   // glow pass: strokes only
        }
    }

    // ── static chrome, between the halo and the crisp chart ───────────────────
    // Axis labels and grid lines do not move when the chart scrolls, and drawing
    // them was most of the cost of drawing anything: text is the most expensive
    // thing a Context2D does, and five labels a section — each a dashed grid
    // stroke, two font switches and two fillText calls — were being rasterised
    // sixty times a second to come out identical every time.
    //
    // They live on their own canvas now, repainted from requestPaint() only: new
    // data, a colour change, a resize. That is once or twice a second rather
    // than sixty, and it is what buys the frame budget back for the line — which
    // is the part that actually moves. Repainting on DATA rather than on an
    // explicit list of dependencies is deliberate: an auto-ranged axis relabels
    // itself when the data rescales, so tying it to the data covers that for
    // free.
    //
    // Sections opt in by setting paintChrome; one that does not simply keeps
    // drawing its own axis in paint() as before.
    property var paintChrome: null

    Canvas {
        id: chromeCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        z: 1
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (chart.paintChrome)
                chart.paintChrome(ctx);
        }
    }

    // ── crisp chart (CPU), on top of the bloom ────────────────────────────────
    Canvas {
        id: mainCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        z: 2
        onPaint: {
            // Reaching here means a real render pass is happening, which is the
            // other half of the stall detection in main.qml.
            root.notePainted();
            const ctx = getContext("2d");
            ctx.reset();
            if (chart.paint)
                chart.paint(ctx, false);  // full pass; CPU glow suppressed if bloomActive
        }
    }
}
