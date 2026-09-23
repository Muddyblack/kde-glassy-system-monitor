import QtQuick
import "DiagramData.js" as Data

// Canvas renderer: the pre-shader Context2D path, kept for scene graphs that
// cannot run shaders (software rendering) and as a switch in the settings.
CanvasChart {
    id: canvas

    required property Item diagram

    sampleSerial: diagram.sampleSerial
    scrolling: diagram.scrolling
    smoothScroll: diagram.smoothScroll
    plotLeft: diagram.plotLeft
    historySize: diagram.historySize
    bloom: diagram.bloom && diagram.glow > 0 && diagram.scrolling
    bloomStrength: diagram.glow
    onScreen: diagram.onScreen
    scrollPhase: () => diagram.livePhase
    onPaintRequested: diagram.paintRequested()
    onPainted: diagram.painted()

    readonly property var paintInputs: [diagram.normalized, diagram.maxValue, diagram.style, diagram.smoothLines, diagram.ticks, diagram.markers, diagram.textColor, diagram.strongGrid, diagram.glow, diagram.bands, diagram.gapColor]
    onPaintInputsChanged: requestPaint()

    Connections {
        target: canvas.diagram
        function onLivePhaseChanged() {
            canvas.requestScrollPaint();
        }
    }

    CanvasPainter {
        id: painter
        textColor: canvas.diagram.textColor
        bloom: canvas.bloomActive
        glow: canvas.diagram.glow > 0
        bands: canvas.diagram.bands
    }

    paintChrome: function (ctx) {
        const d = canvas.diagram;
        if (!d.scrolling)
            return;
        const h = canvas.height, right = canvas.width;
        if (d.empty) {
            painter.drawIdleLine(ctx, d.plotLeft, d.plotWidth, h);
            return;
        }
        const gridColor = painter.tint(d.textColor, d.strongGrid ? 0.12 : 0.07);
        for (const t of d.ticks)
            if (t.grid)
                painter.drawRule(ctx, d.plotLeft, right, Data.yOf(t.value, d.maxValue, h), gridColor, [3, 5], 0.5);
        for (const m of d.markers) {
            const y = Data.yOf(m.value, d.maxValue, h);
            if (y > 2 && y < h - 2)
                painter.drawRule(ctx, d.plotLeft, right, y, painter.tint(m.color, 0.30), [3, 6], 0.8);
        }
    }

    paint: function (ctx, glowPass) {
        const d = canvas.diagram;
        const series = d.normalized;
        const h = canvas.height;
        if (d.empty)
            return;
        if (!d.scrolling) {
            if (glowPass)
                return;
            const cx = d.plotLeft + d.plotWidth / 2, cy = h / 2;
            const full = Math.min(d.plotWidth, h) * 0.36;
            const lineWidth = Math.max(6, full * 0.22);
            series.forEach((s, k) => {
                const ring = Data.ringOf(s, k);
                const fraction = Data.gaugeValue(s) / d.maxValue;
                if (d.style === "pie")
                    painter.drawPie(ctx, cx, cy, full * ring[0], fraction, s.color, s.alpha, s.glow, k === 0);
                else
                    painter.drawDonut(ctx, cx, cy, full * ring[0], Math.max(2, lineWidth * ring[1]), fraction, s.color, s.alpha, s.glow);
            });
            return;
        }
        const step = canvas.scrollStepPx;
        const sf = canvas.paintPhase;
        const right = d.plotLeft + d.plotWidth;
        const xAt = (i, n) => right - (n - 2 - i + sf) * step;
        const yAt = v => Data.yOf(v, d.maxValue, h);
        const top = h * Data.TOP_PAD, bottom = h - h * Data.TOP_PAD;
        ctx.save();
        ctx.beginPath();
        ctx.rect(d.plotLeft - canvas.scrollPadding, 0, d.plotWidth + 2 * canvas.scrollPadding, h);
        ctx.clip();
        if (!glowPass)
            for (const s of series)
                if (s.gaps)
                    painter.drawGaps(ctx, s, xAt, step, top, bottom, d.gapColor);
        for (const s of series) {
            if (d.style === "bars") {
                if (!glowPass)
                    painter.drawBars(ctx, s, xAt, yAt, step, bottom);
            } else if (!glowPass || s.glow) {
                painter.drawSeries(ctx, s, xAt, yAt, h, d.smoothLines, glowPass);
            }
        }
        ctx.restore();
    }
}
