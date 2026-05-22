import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: gpuSection
    spacing: 3

    // Header row: GPU name chip + util% badge
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }

        // Vendor badge
        Rectangle {
            visible: root.gpuVendor !== ""
            radius: 3
            color: {
                if (root.gpuVendor === "nvidia") return Qt.rgba(0.11, 0.73, 0.33, 0.22)
                if (root.gpuVendor === "amd")    return Qt.rgba(0.92, 0.16, 0.22, 0.22)
                return Qt.rgba(0.0, 0.47, 0.90, 0.20)   // intel
            }
            implicitWidth: vendorLabel.implicitWidth + 10
            implicitHeight: vendorLabel.implicitHeight + 4

            Text {
                id: vendorLabel
                anchors.centerIn: parent
                text: root.gpuVendor === "nvidia" ? "NVIDIA"
                    : root.gpuVendor === "amd"    ? "AMD"
                    : root.gpuVendor === "intel"   ? "Intel"
                    : "GPU"
                color: {
                    if (root.gpuVendor === "nvidia") return "#1dbb55"
                    if (root.gpuVendor === "amd")    return "#eb2929"
                    return "#0078e5"
                }
                font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.5
            }
        }

        Item { Layout.fillWidth: true }

        // Freq badge (only when available)
        Text {
            visible: root.gpuFreqMhz > 0
            text: root.gpuFreqMhz + " MHz"
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
            font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        // Util %
        Text {
            text: root.gpuPercent.toFixed(1) + "%"
            color: root.gpuColor
            font.pixelSize: 13; font.bold: true
        }
    }

    Canvas {
        id: gpuGraph
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6
        antialiasing: true; renderStrategy: Canvas.Cooperative

        Connections {
            target: root
            function onGpuHistoryChanged()  { gpuGraph.requestPaint() }
            function onTextColorChanged()   { gpuGraph.requestPaint() }
            function onScrollTickChanged()  { if (root._gpuPhaseStart > 0 && root.gpuScrollPhase() < 2) gpuGraph.requestPaint() }
        }
        Connections {
            target: plasmoid.configuration; ignoreUnknownSignals: true
            function onGlowLineChanged()      { gpuGraph.requestPaint() }
            function onLineWidthChanged()     { gpuGraph.requestPaint() }
            function onShowYLabelsChanged()   { gpuGraph.requestPaint() }
            function onGpuColorChanged()      { gpuGraph.requestPaint() }
            function onChartTypeChanged()     { gpuGraph.requestPaint() }
            function onShowGridLinesChanged() { gpuGraph.requestPaint() }
            function onAutoYRangeChanged()    { gpuGraph.requestPaint() }
            function onSmoothLinesChanged()   { gpuGraph.requestPaint() }
        }

        onPaint: {
            const ctx  = getContext("2d"); ctx.reset()
            const h    = root.gpuHistory, n = h.length
            const maxH = Math.max(10, plasmoid.configuration.historySize)
            const yLW  = plasmoid.configuration.showYLabels ? 38 : 0
            const gW   = width - yLW
            const smooth = plasmoid.configuration.smoothLines
            const ct   = plasmoid.configuration.chartType || 0
            const col  = root.gpuColor

            if (n < 1) { cu.drawIdleLine(ctx, yLW, gW, height); return }
            ctx.setLineDash([])

            const tPad = height * 0.06, uH = height * 0.88
            const step = gW / Math.max(1, maxH - 1)
            const sf   = root.gpuScrollPhase()
            function pToY(p)      { return height - tPad - (p / 100) * uH }
            function iToX(i, len) { return yLW + gW - (len - 2 - i + sf) * step }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2
                const rad = Math.min(gW, height) * 0.36, lw = Math.max(6, rad * 0.22)
                cu.drawDonut(ctx, cx, cy, rad, lw, root.gpuPercent, col,
                    root.gpuPercent.toFixed(1) + "%", "GPU")
                return
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2
                const rad = Math.min(gW, height) * 0.36
                cu.drawPie(ctx, cx, cy, rad, root.gpuPercent, col,
                    root.gpuPercent.toFixed(1) + "%", "GPU")
                return
            }
            if (ct === 5) {
                cu.drawHorizontalBar(ctx, "GPU", root.gpuPercent,
                    root.gpuPercent.toFixed(1) + "%", col,
                    yLW + 10, height / 2 - 7, gW - 20, 14)
                return
            }
            if (ct === 1) {
                cu.drawHistoryBars(ctx, h, col, yLW, gW, height, maxH, 100, 0)
                return
            }

            if (plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    { y: pToY(100), text: "100%", grid: false },
                    { y: pToY(75),  text: "75%",  grid: true  },
                    { y: pToY(50),  text: "50%",  grid: true  },
                    { y: pToY(25),  text: "25%",  grid: true  },
                    { y: pToY(0),   text: "0%",   grid: false }
                ])
            }

            ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()
            const fillA = ct === 2 ? 0.62 : 0.35
            if (n >= 2) {
                ctx.lineWidth = plasmoid.configuration.lineWidth
                cu.drawLine(ctx, h, col, iToX, pToY, height, smooth, fillA,
                    plasmoid.configuration.glowLine ? 8 : 0)
            }
            ctx.restore()
        }
    }

    // Legend
    RowLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showLegend
        spacing: 12
        Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
        LegendItem {
            text: "GPU"
            color: root.gpuColor; textColor: root.textColor
            active: true; highlighted: false
            onClicked: {}
            onHovered: function(h) {}
        }
        Item { Layout.fillWidth: true }
        // No-GPU fallback notice
        Text {
            visible: root.gpuVendor === "" && root.gpuNoDataTicks > 3
            text: "No GPU data"
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
            font.pixelSize: 10
        }
    }
}
