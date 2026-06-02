import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: customSection
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: root.customValue.toFixed(2) + " " + (plasmoid.configuration.customCmdUnit || "")
            color: plasmoid.configuration.customCmdColor || "#ffaa00"
            font.pixelSize: 15
            font.bold: true
            opacity: 0.95
        }
    }

    BloomChart {
        id: customGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6

        Connections {
            target: root
            function onCustomHistoryChanged() {
                customGraph.requestPaint();
            }
            function onTextColorChanged() {
                customGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._custPhaseStart > 0 && root.custScrollPhase() < 2)
                    customGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onGlowLineChanged() {
                customGraph.requestPaint();
            }
            function onLineWidthChanged() {
                customGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                customGraph.requestPaint();
            }
            function onCustomCmdColorChanged() {
                customGraph.requestPaint();
            }
            function onChartTypeChanged() {
                customGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                customGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                customGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                customGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                customGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                customGraph.requestPaint();
            }
        }

        paint: function (ctx, glowPass) {
            const width = customGraph.width, height = customGraph.height;
            const h = root.customHistory, n = h.length;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const yLW = plasmoid.configuration.showYLabels ? 38 : 0;
            const gW = width - yLW;
            const smooth = plasmoid.configuration.smoothLines;
            const ct = plasmoid.configuration.chartType || 0;
            const color = plasmoid.configuration.customCmdColor || "#ffaa00";
            const maxVal = Math.max(0.1, plasmoid.configuration.customCmdMax);

            if (n < 1) {
                if (!glowPass)
                    cu.drawIdleLine(ctx, yLW, gW, height);
                return;
            }
            ctx.setLineDash([]);

            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            const tPad = height * 0.06, uH = height * 0.88;
            const step = gW / Math.max(1, maxH - 1);
            const sf = root.custScrollPhase();
            function valToY(v) {
                return height - tPad - (Math.min(maxVal, Math.max(0, v)) / maxVal) * uH;
            }
            function iToX(i, len) {
                return yLW + gW - (len - 2 - i + sf) * step;
            }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2, rad = Math.min(gW, height) * 0.36;
                cu.drawDonut(ctx, cx, cy, rad, Math.max(6, rad * 0.22), Math.min(100, (root.customValue / maxVal) * 100), color, root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""), plasmoid.configuration.customCmdTitle || "value");
                return;
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2, rad = Math.min(gW, height) * 0.36;
                cu.drawPie(ctx, cx, cy, rad, Math.min(100, (root.customValue / maxVal) * 100), color, root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""), plasmoid.configuration.customCmdTitle || "value");
                return;
            }
            if (ct === 5) {
                const barH = 14, bx = yLW + 10, bw = gW - 20;
                cu.drawHorizontalBar(ctx, plasmoid.configuration.customCmdTitle || "Value", (root.customValue / maxVal) * 100, root.customValue.toFixed(2) + (plasmoid.configuration.customCmdUnit || ""), color, bx, height / 2 - barH / 2, bw, barH);
                return;
            }
            if (ct === 1) {
                cu.drawHistoryBars(ctx, h, color, yLW, gW, height, maxH, maxVal, sf);
                return;
            }

            if (!glowPass && plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    {
                        y: valToY(maxVal),
                        text: maxVal.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""),
                        grid: false
                    },
                    {
                        y: valToY(maxVal * 0.5),
                        text: (maxVal * 0.5).toFixed(1),
                        grid: true
                    },
                    {
                        y: valToY(0),
                        text: "0",
                        grid: false
                    }
                ]);
            }

            ctx.save();
            ctx.beginPath();
            ctx.rect(yLW, 0, gW, height);
            ctx.clip();
            ctx.lineWidth = plasmoid.configuration.lineWidth;
            const fillA = glowPass ? 0 : (ct === 2 ? 0.65 : 0.38);
            cu.drawLine(ctx, h, color, iToX, valToY, height, smooth, fillA, plasmoid.configuration.glowLine ? cu.glowFor(5) : 0);

            // endpoint dot
            if (n > 0) {
                const lp = {
                    x: iToX(n - 1, n),
                    y: valToY(h[n - 1])
                };
                const ec = Qt.color(color);
                // Manual soft halo only when GPU bloom isn't already adding one.
                if (plasmoid.configuration.glowLine && !glowPass && !cu.gpuBloom) {
                    ctx.beginPath();
                    ctx.arc(lp.x, lp.y, 14, 0, Math.PI * 2);
                    ctx.fillStyle = Qt.rgba(ec.r, ec.g, ec.b, 0.18);
                    ctx.fill();
                }
                ctx.beginPath();
                ctx.arc(lp.x, lp.y, 3.2, 0, Math.PI * 2);
                ctx.fillStyle = color;
                ctx.fill();
            }
            ctx.restore();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showLegend
        spacing: 12
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }
        LegendItem {
            text: plasmoid.configuration.customCmdTitle || "Value"
            color: plasmoid.configuration.customCmdColor || "#ffaa00"
            textColor: root.textColor
            active: true
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
