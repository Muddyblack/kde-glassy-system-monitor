import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: pingSection
    spacing: 3

    // ── target tabs + live value row ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Row {
            spacing: 4
            Repeater {
                model: root.targetList
                delegate: Rectangle {
                    readonly property bool active: root.activeTarget === index
                    width: Math.min(90, Math.max(36, (pingSection.width - root.targetList.length * 4 - 80) / root.targetList.length))
                    height: 20
                    radius: height / 2
                    color: active ? Qt.rgba(root.pingColor.r, root.pingColor.g, root.pingColor.b, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: active ? Qt.rgba(root.pingColor.r, root.pingColor.g, root.pingColor.b, 0.60) : Qt.rgba(1, 1, 1, 0.14)
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        text: modelData
                        color: parent.active ? root.pingColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: plasmoid.configuration.currentTargetIndex = index
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: root.lastPing >= 0 ? root.lastPing.toFixed(0) + " ms" : "— ms"
            color: root.pingAlertColor()
            font.pixelSize: 15
            font.bold: true
            Behavior on color {
                ColorAnimation {
                    duration: 400
                }
            }
        }
    }

    // ── graph ────────────────────────────────────────────────────────────────
    BloomChart {
        id: pingGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6
        dataIntervalMs: root._pingInterval

        Connections {
            target: root
            function onHistoriesChanged() {
                pingGraph.requestPaint();
            }
            function onIsAlertingChanged() {
                pingGraph.requestPaint();
            }
            function onPingColorChanged() {
                pingGraph.requestPaint();
            }
            function onPingWarnColorChanged() {
                pingGraph.requestPaint();
            }
            function onPingCritColorChanged() {
                pingGraph.requestPaint();
            }
            function onTextColorChanged() {
                pingGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._phaseActive(root._pingPhaseStart, root._pingInterval))
                    pingGraph.requestScrollPaint();
            }
            function onRepaintCharts() {
                pingGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onLineWidthChanged() {
                pingGraph.requestPaint();
            }
            function onGlowLineChanged() {
                pingGraph.requestPaint();
            }
            function onLatencyThresholdChanged() {
                pingGraph.requestPaint();
            }
            function onPingThresholdColorsChanged() {
                pingGraph.requestPaint();
            }
            function onHistorySizeChanged() {
                pingGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                pingGraph.requestPaint();
            }
            function onChartTypeChanged() {
                pingGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                pingGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                pingGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                pingGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                pingGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                pingGraph.requestPaint();
            }
        }

        // Axis and grid — the part of the chart that does not move. Painted on
        // BloomChart's chrome canvas, which repaints on data rather than on every
        // scroll frame; the range is recomputed here because an auto-ranged axis
        // relabels itself whenever the data rescales.
        paintChrome: function (ctx) {
            const h = root.histories[root.activeTarget] || [];
            if (h.length === 0 || !plasmoid.configuration.showYLabels)
                return;
            // Only the gauges drop the axis here — the bar chart keeps it, which
            // is what paint() below does too.
            if ((plasmoid.configuration.chartType || 0) >= 3)
                return;
            const height = pingGraph.height, yLW = 38;
            const valid = h.filter(v => v >= 0);
            const vMax = valid.length > 0 ? Math.max.apply(null, valid) : 0;
            const maxMs = Math.max(vMax * 1.5 + 2, 15);
            const tPad = height * 0.06, uH = height * 0.88;
            const msToY = ms => height - tPad - (ms / maxMs) * uH;
            cu.drawYAxis(ctx, yLW, height, [
                {
                    y: msToY(maxMs),
                    text: maxMs.toFixed(0) + "ms",
                    grid: false
                },
                {
                    y: msToY(maxMs * 0.5),
                    text: (maxMs * 0.5).toFixed(0) + "ms",
                    grid: true
                },
                {
                    y: msToY(0),
                    text: "0",
                    grid: false
                }
            ]);
        }

        paint: function (ctx, glowPass) {
            const width = pingGraph.width, height = pingGraph.height;
            const h = root.histories[root.activeTarget] || [];
            const n = h.length;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const yLW = plasmoid.configuration.showYLabels ? 38 : 0;
            const gW = width - yLW;
            const smooth = plasmoid.configuration.smoothLines;

            if (n === 0) {
                if (!glowPass)
                    cu.drawIdleLine(ctx, yLW, gW, height);
                return;
            }
            ctx.setLineDash([]);

            const ct = plasmoid.configuration.chartType || 0;
            const valid = h.filter(v => v >= 0);
            const vMax = valid.length > 0 ? Math.max.apply(null, valid) : 0;
            const maxMs = Math.max(vMax * 1.5 + 2, 15);
            const threshold = plasmoid.configuration.latencyThreshold;
            // Packet-loss markers share the critical colour so the whole ping
            // palette stays user-configurable.
            const lossC = root.pingCritColor;
            const lossFill = Qt.rgba(lossC.r, lossC.g, lossC.b, 0.10);

            // Donut/pie/bar keep their own in-helper glow; GPU bloom is for the
            // line/area chart only.
            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            // Donut
            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawDonut(ctx, cx, cy, rad, Math.max(6, rad * 0.22), pct, root.pingAlertColor(), root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency");
                return;
            }
            // Pie
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawPie(ctx, cx, cy, rad, pct, root.pingAlertColor(), root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency");
                return;
            }
            // Horizontal bar
            if (ct === 5) {
                const barH = 14, bx = yLW + 10, bw = gW - 20;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawHorizontalBar(ctx, root.targetList[root.activeTarget] || "Latency", pct, root.lastPing >= 0 ? root.lastPing.toFixed(0) + " ms" : "— ms", root.pingAlertColor(), bx, height / 2 - barH / 2, bw, barH);
                return;
            }

            const step = gW / Math.max(1, maxH - 1);
            const tPad = height * 0.06, uH = height * 0.88;
            const sf = root.scrollDrawPhase(root.pingScrollPhase(), root._pingInterval);

            // OPTIMIZATION: Precalculate coordinate functions
            function msToY(ms) {
                return height - tPad - (ms / maxMs) * uH;
            }
            function iToX(i) {
                return yLW + gW - (n - 2 - i + sf) * step;
            }

            // threshold line (not glow content)
            const ty = msToY(threshold);
            if (!glowPass && ty > 2 && ty < height - 2) {
                ctx.save();
                ctx.lineWidth = 0.8;
                ctx.strokeStyle = Qt.rgba(1, 0.45, 0.1, 0.30);
                ctx.setLineDash([3, 6]);
                ctx.beginPath();
                ctx.moveTo(yLW, ty);
                ctx.lineTo(width, ty);
                ctx.stroke();
                ctx.setLineDash([]);
                ctx.restore();
            }

            // vertical bars chart
            if (ct === 1) {
                const barW = Math.max(2, step * 0.62);
                ctx.save();
                ctx.beginPath();
                ctx.rect(yLW, 0, gW, height);
                ctx.clip();
                for (let i = 0; i < n; i++) {
                    const x = iToX(i);
                    if (x + barW / 2 < yLW || x - barW / 2 > width)
                        continue;
                    if (h[i] < 0) {
                        ctx.fillStyle = lossFill;
                        ctx.fillRect(x - step / 2, tPad, step, height - tPad * 2);
                        ctx.beginPath();
                        ctx.arc(x, height - tPad, 1.8, 0, Math.PI * 2);
                        ctx.fillStyle = lossC;
                        ctx.fill();
                        continue;
                    }
                    const bh = Math.max(2, (h[i] / maxMs) * uH);
                    const bx = x - barW / 2, by = height - tPad - bh;
                    const sc = root.pingColorFor(h[i]);
                    const c = Qt.color(sc), r = Math.min(barW / 2, 3);
                    const gr = ctx.createLinearGradient(0, by, 0, height - tPad);
                    gr.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.88));
                    gr.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.28));
                    ctx.fillStyle = gr;
                    ctx.beginPath();
                    if (bh > r * 2) {
                        ctx.moveTo(bx + r, by);
                        ctx.arc(bx + r, by + r, r, Math.PI, 0);
                        ctx.lineTo(bx + barW, height - tPad);
                        ctx.lineTo(bx, height - tPad);
                        ctx.closePath();
                    } else {
                        ctx.arc(bx + r, by + r, r, 0, Math.PI * 2);
                    }
                    ctx.fill();
                }
                ctx.restore();
                return;
            }

            // line / filled-area
            // OPTIMIZATION: Precalculate segments with coordinates
            const segments = [];
            let seg = [];
            for (let i = 0; i < n; i++) {
                const x = iToX(i);
                if (x < yLW - step)
                    continue;
                if (h[i] < 0) {
                    if (seg.length) {
                        segments.push(seg);
                        seg = [];
                    }
                } else
                    seg.push({
                        x,
                        y: msToY(h[i]),
                        ms: h[i]
                    });
            }
            if (seg.length)
                segments.push(seg);

            ctx.save();
            ctx.beginPath();
            ctx.rect(yLW, 0, gW, height);
            ctx.clip();

            // packet-loss columns (alert markers, not glow content)
            if (!glowPass)
                for (let i = 0; i < n; i++) {
                    if (h[i] < 0) {
                        const x = iToX(i);
                        if (x >= yLW - step / 2 && x <= width + step / 2) {
                            ctx.fillStyle = lossFill;
                            ctx.fillRect(x - step / 2, tPad, step, height - tPad * 2);
                            ctx.beginPath();
                            ctx.arc(x, height - tPad, 2, 0, Math.PI * 2);
                            ctx.fillStyle = lossC;
                            ctx.fill();
                        }
                    }
                }

            // Runs of consecutive edges that share a latency band. An edge takes
            // the HIGHER band of its two samples, so a spike is drawn fully in
            // the alert colour rather than half of it. Runs are cut at data
            // points and share endpoints, so the line stays continuous and each
            // colour is anchored to its samples — nothing drifts while it
            // scrolls, and no two colours blend into each other.
            function edgeRuns(pts) {
                const bandAt = k => Math.max(root.pingBandFor(pts[k].ms), root.pingBandFor(pts[k + 1].ms));
                const runs = [];
                let i = 0;
                while (i < pts.length - 1) {
                    const band = bandAt(i);
                    let j = i + 1;
                    while (j < pts.length - 1 && bandAt(j) === band)
                        j++;
                    runs.push({
                        band,
                        i,
                        j
                    });
                    i = j;
                }
                return runs;
            }
            // Trace pts[i..j] into the current path. Control points depend only
            // on each edge's own endpoints, so tracing a run in isolation gives
            // exactly the curve the full-segment path would have produced.
            function tracePath(pts, i, j) {
                ctx.moveTo(pts[i].x, pts[i].y);
                for (let k = i + 1; k <= j; k++) {
                    if (smooth) {
                        const cx = (pts[k - 1].x + pts[k].x) / 2;
                        ctx.bezierCurveTo(cx, pts[k - 1].y, cx, pts[k].y, pts[k].x, pts[k].y);
                    } else {
                        ctx.lineTo(pts[k].x, pts[k].y);
                    }
                }
            }

            for (const pts of segments) {
                if (pts.length < 2)
                    continue;
                const plw = plasmoid.configuration.lineWidth;
                const runs = edgeRuns(pts);
                ctx.save();
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // Manual wide-stroke glow only when GPU bloom isn't owning the
                // halo (it already double-strokes instead of using shadowBlur).
                if (plasmoid.configuration.glowLine && !glowPass && !cu.gpuBloom) {
                    ctx.lineWidth = plw * 3.5;
                    for (const r of runs) {
                        const c = root.pingBandColor(r.band);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.beginPath();
                        tracePath(pts, r.i, r.j);
                        ctx.stroke();
                    }
                }
                ctx.lineWidth = plw;
                for (const r of runs) {
                    ctx.strokeStyle = root.pingBandColor(r.band);
                    ctx.beginPath();
                    tracePath(pts, r.i, r.j);
                    ctx.stroke();
                }
                // area fill — full pass only (the bloom source carries no fill).
                // One closed area per run; neighbours share a boundary x so the
                // fills tile exactly, with no seam and no overlap.
                if (!glowPass) {
                    // Shared gradient origin so every run fades identically.
                    const topY = Math.min.apply(null, pts.map(p => p.y));
                    const a0 = ct === 2 ? 0.65 : 0.38;
                    for (const r of runs) {
                        const c = root.pingBandColor(r.band);
                        ctx.beginPath();
                        tracePath(pts, r.i, r.j);
                        ctx.lineTo(pts[r.j].x, height);
                        ctx.lineTo(pts[r.i].x, height);
                        ctx.closePath();
                        const g = ctx.createLinearGradient(0, topY, 0, height);
                        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, a0));
                        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                        ctx.fillStyle = g;
                        ctx.fill();
                    }
                }
                ctx.restore();
            }

            // endpoint dot
            if (segments.length > 0) {
                const last = segments[segments.length - 1];
                const lp = last[last.length - 1];
                if (lp) {
                    // Match the dot to its own sample so it doesn't sit on a
                    // recoloured line in the base colour.
                    const dc = root.pingColorFor(lp.ms);
                    if (plasmoid.configuration.glowLine && !glowPass && !cu.gpuBloom) {
                        ctx.beginPath();
                        ctx.arc(lp.x, lp.y, 8, 0, Math.PI * 2);
                        ctx.fillStyle = Qt.rgba(dc.r, dc.g, dc.b, 0.18);
                        ctx.fill();
                    }
                    ctx.beginPath();
                    ctx.arc(lp.x, lp.y, 3.2, 0, Math.PI * 2);
                    ctx.fillStyle = dc;
                    ctx.fill();
                }
            }
            ctx.restore();
        }
    }

    // ── stats bar ─────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showStats
        spacing: 10
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }
        Column {
            spacing: 1
            Text {
                text: "AVG"
                color: root.textColor
                opacity: 0.38
                font.pixelSize: 7
                font.letterSpacing: 0.8
            }
            Text {
                text: root.avgPing > 0 ? root.avgPing.toFixed(1) + " ms" : "— ms"
                color: root.textColor
                opacity: 0.85
                font.pixelSize: 10
                font.bold: true
            }
        }
        Column {
            spacing: 1
            Text {
                text: "JITTER"
                color: root.textColor
                opacity: 0.38
                font.pixelSize: 7
                font.letterSpacing: 0.8
            }
            Text {
                readonly property var vh: (root.histories[root.activeTarget] || []).filter(v => v >= 0)
                text: vh.length >= 2 ? root.jitter.toFixed(1) + " ms" : "— ms"
                color: root.jitter > plasmoid.configuration.jitterThreshold ? root.pingWarnColor : root.textColor
                opacity: 0.85
                font.pixelSize: 10
                font.bold: true
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }
        }
        Column {
            spacing: 1
            Text {
                text: "LOSS"
                color: root.textColor
                opacity: 0.38
                font.pixelSize: 7
                font.letterSpacing: 0.8
            }
            Text {
                text: root.lossPercent.toFixed(1) + "%"
                color: root.lossPercent > plasmoid.configuration.lossThreshold ? root.pingCritColor : root.textColor
                opacity: 0.85
                font.pixelSize: 10
                font.bold: true
                Behavior on color {
                    ColorAnimation {
                        duration: 300
                    }
                }
            }
        }
        Column {
            spacing: 1
            visible: (root.histories[root.activeTarget] || []).filter(v => v >= 0).length > 0
            Text {
                text: "MIN / MAX"
                color: root.textColor
                opacity: 0.38
                font.pixelSize: 7
                font.letterSpacing: 0.8
            }
            Text {
                readonly property var vh: (root.histories[root.activeTarget] || []).filter(v => v >= 0)
                text: vh.length > 0 ? Math.min.apply(null, vh).toFixed(0) + " / " + Math.max.apply(null, vh).toFixed(0) + " ms" : "—"
                color: root.textColor
                opacity: 0.80
                font.pixelSize: 10
                font.bold: true
            }
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: root.targetList[root.activeTarget] || ""
            color: root.textColor
            opacity: 0.28
            font.pixelSize: 8
            elide: Text.ElideLeft
            Layout.maximumWidth: 70
        }
    }

    // ── legend ────────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showLegend
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }
        LegendItem {
            text: "Latency"
            color: root.pingColor
            textColor: root.textColor
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
