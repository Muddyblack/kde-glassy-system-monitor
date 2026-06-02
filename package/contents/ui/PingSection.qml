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
                    color: active ? Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: active ? Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.60) : Qt.rgba(1, 1, 1, 0.14)
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
                        color: parent.active ? root.lineColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
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
            color: root.isAlerting ? "#ff6666" : root.lineColor
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

        Connections {
            target: root
            function onHistoriesChanged() {
                pingGraph.requestPaint();
            }
            function onIsAlertingChanged() {
                pingGraph.requestPaint();
            }
            function onLineColorChanged() {
                pingGraph.requestPaint();
            }
            function onTextColorChanged() {
                pingGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._pingPhaseStart > 0 && root.pingScrollPhase() < 2)
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

            // Donut/pie/bar keep their own in-helper glow; GPU bloom is for the
            // line/area chart only.
            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            // Donut
            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawDonut(ctx, cx, cy, rad, Math.max(6, rad * 0.22), pct, root.isAlerting ? "#ff6666" : root.lineColor, root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency");
                return;
            }
            // Pie
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawPie(ctx, cx, cy, rad, pct, root.isAlerting ? "#ff6666" : root.lineColor, root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency");
                return;
            }
            // Horizontal bar
            if (ct === 5) {
                const barH = 14, bx = yLW + 10, bw = gW - 20;
                const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0;
                cu.drawHorizontalBar(ctx, root.targetList[root.activeTarget] || "Latency", pct, root.lastPing >= 0 ? root.lastPing.toFixed(0) + " ms" : "— ms", root.isAlerting ? "#ff6666" : root.lineColor, bx, height / 2 - barH / 2, bw, barH);
                return;
            }

            const step = gW / Math.max(1, maxH - 1);
            const tPad = height * 0.06, uH = height * 0.88;
            const sf = root.pingScrollPhase();

            // OPTIMIZATION: Precalculate coordinate functions
            function msToY(ms) {
                return height - tPad - (ms / maxMs) * uH;
            }
            function iToX(i) {
                return yLW + gW - (n - 2 - i + sf) * step;
            }

            if (!glowPass && plasmoid.configuration.showYLabels) {
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
                        ctx.fillStyle = Qt.rgba(1, 0.15, 0.15, 0.08);
                        ctx.fillRect(x - step / 2, tPad, step, height - tPad * 2);
                        ctx.beginPath();
                        ctx.arc(x, height - tPad, 1.8, 0, Math.PI * 2);
                        ctx.fillStyle = "#ff4444";
                        ctx.fill();
                        continue;
                    }
                    const bh = Math.max(2, (h[i] / maxMs) * uH);
                    const bx = x - barW / 2, by = height - tPad - bh;
                    const sc = h[i] > threshold * 1.5 ? "#ff4444" : h[i] > threshold ? "#ffaa22" : root.lineColor;
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
                            ctx.fillStyle = Qt.rgba(1, 0.15, 0.15, 0.08);
                            ctx.fillRect(x - step / 2, tPad, step, height - tPad * 2);
                            ctx.beginPath();
                            ctx.arc(x, height - tPad, 2, 0, Math.PI * 2);
                            ctx.fillStyle = "#ff4444";
                            ctx.fill();
                        }
                    }
                }

            for (const pts of segments) {
                if (pts.length < 2)
                    continue;
                const sMax = Math.max.apply(null, pts.map(p => p.ms));
                const sc = sMax > threshold * 1.5 ? "#ff4444" : sMax > threshold ? "#ffaa22" : root.lineColor;
                const plw = plasmoid.configuration.lineWidth;
                const pc = Qt.color(sc);
                ctx.save();
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // Build path once, stroke twice for glow (no shadowBlur)
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                for (let i = 1; i < pts.length; i++) {
                    if (smooth) {
                        const cx = (pts[i - 1].x + pts[i].x) / 2;
                        ctx.bezierCurveTo(cx, pts[i - 1].y, cx, pts[i].y, pts[i].x, pts[i].y);
                    } else {
                        ctx.lineTo(pts[i].x, pts[i].y);
                    }
                }
                // Manual wide-stroke glow only when GPU bloom isn't owning the
                // halo (it already double-strokes instead of using shadowBlur).
                if (plasmoid.configuration.glowLine && !glowPass && !cu.gpuBloom) {
                    ctx.lineWidth = plw * 3.5;
                    ctx.strokeStyle = Qt.rgba(pc.r, pc.g, pc.b, 0.22);
                    ctx.stroke();
                }
                ctx.lineWidth = plw;
                ctx.strokeStyle = sc;
                ctx.stroke();
                // area fill — full pass only (the bloom source carries no fill)
                if (!glowPass) {
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x, pts[0].y);
                    for (let i = 1; i < pts.length; i++) {
                        if (smooth) {
                            const cx = (pts[i - 1].x + pts[i].x) / 2;
                            ctx.bezierCurveTo(cx, pts[i - 1].y, cx, pts[i].y, pts[i].x, pts[i].y);
                        } else {
                            ctx.lineTo(pts[i].x, pts[i].y);
                        }
                    }
                    ctx.lineTo(pts[pts.length - 1].x, height);
                    ctx.lineTo(pts[0].x, height);
                    ctx.closePath();
                    const c = Qt.color(sc);
                    const g = ctx.createLinearGradient(0, pts[0].y, 0, height);
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, ct === 2 ? 0.65 : 0.38));
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
                ctx.restore();
            }

            // endpoint dot
            if (segments.length > 0) {
                const last = segments[segments.length - 1];
                const lp = last[last.length - 1];
                if (lp) {
                    const dc = root.lineColor;
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
                color: root.jitter > 20 ? "#ffaa22" : root.textColor
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
                color: root.lossPercent > plasmoid.configuration.lossThreshold ? "#ff4444" : root.textColor
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
            color: root.lineColor
            textColor: root.textColor
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
