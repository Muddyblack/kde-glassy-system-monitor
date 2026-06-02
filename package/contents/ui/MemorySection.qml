import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: memSection
    spacing: 3
    implicitWidth: 0

    BloomChart {
        id: memGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6

        Connections {
            target: root
            function onMemHistoryChanged() {
                memGraph.requestPaint();
            }
            function onSwapHistoryChanged() {
                memGraph.requestPaint();
            }
            function onTextColorChanged() {
                memGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._memPhaseStart > 0 && root.memScrollPhase() < 2)
                    memGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onGlowLineChanged() {
                memGraph.requestPaint();
            }
            function onLineWidthChanged() {
                memGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                memGraph.requestPaint();
            }
            function onMemColorChanged() {
                memGraph.requestPaint();
            }
            function onSwapColorChanged() {
                memGraph.requestPaint();
            }
            function onChartTypeChanged() {
                memGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                memGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                memGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                memGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                memGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                memGraph.requestPaint();
            }
        }

        paint: function (ctx, glowPass) {
            const width = memGraph.width, height = memGraph.height;
            const h = root.memHistory, n = h.length;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const yLW = plasmoid.configuration.showYLabels ? 38 : 0;
            const gW = width - yLW;
            const smooth = plasmoid.configuration.smoothLines;
            const ct = plasmoid.configuration.chartType || 0;

            if (n < 1) {
                if (!glowPass)
                    cu.drawIdleLine(ctx, yLW, gW, height);
                return;
            }
            ctx.setLineDash([]);

            // Donut/pie/bar keep their own in-helper glow; GPU bloom is for the
            // line/area charts only.
            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            const tPad = height * 0.06, uH = height * 0.88;
            const step = gW / Math.max(1, maxH - 1);
            const sf = root.memScrollPhase();
            function pToY(p) {
                return height - tPad - (p / 100) * uH;
            }
            function iToX(i, len) {
                return yLW + gW - (len - 2 - i + sf) * step;
            }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36, lw = Math.max(6, rad * 0.22);
                if (!root.isLineDisabled("ram"))
                    cu.drawDonut(ctx, cx, cy, rad, lw, root.memPercent, root.memColor, root.memUsedGiB.toFixed(1) + " GiB", root.memTotalGiB.toFixed(1) + " GiB total");
                if (root.hasSwap && !root.isLineDisabled("swap"))
                    cu.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, root.swapPercent, root.swapColor, null, null);
                return;
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                if (!root.isLineDisabled("ram"))
                    cu.drawPie(ctx, cx, cy, rad, root.memPercent, root.memColor, root.memUsedGiB.toFixed(1) + " GiB", root.memTotalGiB.toFixed(1) + " GiB total");
                if (root.hasSwap && !root.isLineDisabled("swap"))
                    cu.drawPie(ctx, cx, cy, rad * 0.58, root.swapPercent, root.swapColor, null, null);
                return;
            }
            if (ct === 5) {
                const barH = 10, gap = 8, bx = yLW + 10, bw = gW - 20;
                let activeCount = (!root.isLineDisabled("ram") ? 1 : 0) + (root.hasSwap && !root.isLineDisabled("swap") ? 1 : 0);
                let y = height / 2 - (activeCount * barH + (activeCount - 1) * gap) / 2;
                if (!root.isLineDisabled("ram")) {
                    cu.drawHorizontalBar(ctx, "RAM", root.memPercent, root.memUsedGiB.toFixed(1) + " / " + root.memTotalGiB.toFixed(1) + " GiB", root.memColor, bx, y, bw, barH);
                    y += barH + gap;
                }
                if (root.hasSwap && !root.isLineDisabled("swap"))
                    cu.drawHorizontalBar(ctx, "Swap", root.swapPercent, root.swapUsedGiB.toFixed(1) + " GiB", root.swapColor, bx, y, bw, barH);
                return;
            }
            if (ct === 1) {
                const sw2 = root.swapHistory;
                if (root.hasSwap && sw2.length > 0 && !root.isLineDisabled("swap")) {
                    ctx.globalAlpha = 0.55;
                    cu.drawHistoryBars(ctx, sw2, root.swapColor, yLW, gW, height, maxH, 100, sf);
                    ctx.globalAlpha = 1.0;
                }
                if (!root.isLineDisabled("ram"))
                    cu.drawHistoryBars(ctx, h, root.memColor, yLW, gW, height, maxH, 100, sf);
                return;
            }

            if (!glowPass && plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    {
                        y: pToY(100),
                        text: "100%",
                        grid: false
                    },
                    {
                        y: pToY(50),
                        text: "50%",
                        grid: true
                    },
                    {
                        y: pToY(0),
                        text: "0%",
                        grid: false
                    }
                ]);
            }

            ctx.save();
            ctx.beginPath();
            ctx.rect(yLW, 0, gW, height);
            ctx.clip();
            const fillA = glowPass ? 0 : (ct === 2 ? 0.62 : 0.35);
            const sw = root.swapHistory, swLen = sw.length;

            if (root.hasSwap && swLen >= 2 && !root.isLineDisabled("swap")) {
                const isHov = root.hoveredLine === "swap";
                const dimOth = (root.hoveredLine === "ram" || root.hoveredLine === "swap") && !isHov;
                ctx.globalAlpha = dimOth ? 0.15 : (isHov ? 0.9 : 0.55);
                ctx.lineWidth = Math.max(0.8, plasmoid.configuration.lineWidth * 0.65);
                cu.drawLine(ctx, sw, root.swapColor, iToX, pToY, height, smooth, 0, 0);
                ctx.globalAlpha = 1.0;
            }
            if (n >= 2 && !root.isLineDisabled("ram")) {
                const isHov = root.hoveredLine === "ram";
                const dimOth = (root.hoveredLine === "ram" || root.hoveredLine === "swap") && !isHov;
                ctx.globalAlpha = dimOth ? 0.15 : 1.0;
                ctx.lineWidth = plasmoid.configuration.lineWidth;
                // Glow resolves to 0 on the GPU-bloom crisp pass (bloom owns it).
                cu.drawLine(ctx, h, root.memColor, iToX, pToY, height, smooth, fillA, plasmoid.configuration.glowLine ? cu.glowFor(isHov ? 7 : 5) : 0);
                ctx.globalAlpha = 1.0;
            }
            ctx.restore();
        }
    }

    // ── legend + live values ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitWidth: 0
        visible: plasmoid.configuration.showLegend
        spacing: 6
        clip: true
        Item {
            Layout.preferredWidth: plasmoid.configuration.showYLabels ? 38 : 0
            Layout.minimumWidth: 0
        }

        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            implicitHeight: ramRow.implicitHeight
            RowLayout {
                id: ramRow
                anchors.fill: parent
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    Layout.alignment: Qt.AlignVCenter
                    color: root.isLineDisabled("ram") ? "transparent" : root.memColor
                    border.color: root.memColor
                    border.width: 1
                }
                Text {
                    text: "RAM"
                    color: root.isLineDisabled("ram") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("ram")
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: root.memUsedGiB.toFixed(1) + " / " + root.memTotalGiB.toFixed(1) + " GiB"
                    color: root.isLineDisabled("ram") ? Qt.rgba(root.memColor.r, root.memColor.g, root.memColor.b, 0.3) : root.memColor
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("ram");
                    memGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "ram";
                    memGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    memGraph.requestPaint();
                }
            }
        }

        Item {
            visible: root.hasSwap
            Layout.minimumWidth: 0
            Layout.preferredWidth: Math.min(swapRow.implicitWidth, 58)
            implicitHeight: swapRow.implicitHeight
            clip: true
            Row {
                id: swapRow
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("swap") ? "transparent" : root.swapColor
                    border.color: root.swapColor
                    border.width: 1
                }
                Text {
                    text: "Swap"
                    color: root.isLineDisabled("swap") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("swap")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.swapPercent.toFixed(0) + "%"
                    color: root.isLineDisabled("swap") ? Qt.rgba(root.swapColor.r, root.swapColor.g, root.swapColor.b, 0.3) : root.swapColor
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("swap");
                    memGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "swap";
                    memGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    memGraph.requestPaint();
                }
            }
        }
    }
}
