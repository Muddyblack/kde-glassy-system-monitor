import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: netSection
    spacing: 3


    // iface badge above graph
    Text {
        Layout.leftMargin: plasmoid.configuration.showYLabels ? 42 : 4
        text: root.activeIface || ""
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
        font.pixelSize: 9; visible: root.activeIface !== ""
    }

    Canvas {
        id: netGraph
        Layout.fillWidth: true; Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6
        antialiasing: true; renderStrategy: Canvas.Cooperative

        Connections {
            target: root
            function onDlHistoryChanged()     { netGraph.requestPaint() }
            function onUlHistoryChanged()     { netGraph.requestPaint() }
            function onTextColorChanged()     { netGraph.requestPaint() }
            function onScrollTickChanged()    { if (root._netPhaseStart > 0 && root.netScrollPhase() < 2) netGraph.requestPaint() }
        }
        Connections {
            target: plasmoid.configuration; ignoreUnknownSignals: true
            function onGlowLineChanged()     { netGraph.requestPaint() }
            function onLineWidthChanged()    { netGraph.requestPaint() }
            function onShowYLabelsChanged()  { netGraph.requestPaint() }
            function onDlColorChanged()      { netGraph.requestPaint() }
            function onUlColorChanged()      { netGraph.requestPaint() }
            function onChartTypeChanged()    { netGraph.requestPaint() }
            function onShowGridLinesChanged(){ netGraph.requestPaint() }
            function onAutoYRangeChanged()   { netGraph.requestPaint() }
            function onSmoothLinesChanged()  { netGraph.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const dl = root.dlHistory, ul = root.ulHistory
            const maxH  = Math.max(10, plasmoid.configuration.historySize)
            const yLW   = plasmoid.configuration.showYLabels ? 38 : 0
            const gW    = width - yLW
            const smooth = plasmoid.configuration.smoothLines
            const ct    = plasmoid.configuration.chartType || 0

            if (dl.length < 1 && ul.length < 1) { cu.drawIdleLine(ctx, yLW, gW, height); return }
            ctx.setLineDash([])

            const allVals = dl.concat(ul)
            const dataMax = allVals.length > 0 ? Math.max.apply(null, allVals) : 0
            const maxBps  = Math.max(1024, dataMax * (plasmoid.configuration.autoYRange ? 1.10 : 1.20))
            const tPad    = height * 0.06, uH = height * 0.88
            const step    = gW / Math.max(1, maxH - 1)
            const sf      = root.netScrollPhase()
            function bToY(b)       { return height - tPad - (b / maxBps) * uH }
            function iToX(i, len)  { return yLW + gW - (len - 2 - i + sf) * step }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2
                const rad = Math.min(gW, height) * 0.33, lw = Math.max(6, rad * 0.22)
                const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100)
                const ulPct = Math.min(100, (root.uploadSpeed  / maxBps) * 100)
                if (!root.isLineDisabled("dl"))
                    cu.drawDonut(ctx, cx, cy, rad, lw, dlPct, root.dlColor,
                        "↓ " + cu.formatSpeed(root.downloadSpeed), "↑ " + cu.formatSpeed(root.uploadSpeed))
                if (!root.isLineDisabled("ul"))
                    cu.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, ulPct, root.ulColor, null, null)
                return
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2
                const rad = Math.min(gW, height) * 0.33
                const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100)
                const ulPct = Math.min(100, (root.uploadSpeed  / maxBps) * 100)
                if (!root.isLineDisabled("dl"))
                    cu.drawPie(ctx, cx, cy, rad, dlPct, root.dlColor,
                        "↓ " + cu.formatSpeed(root.downloadSpeed), "↑ " + cu.formatSpeed(root.uploadSpeed))
                if (!root.isLineDisabled("ul"))
                    cu.drawPie(ctx, cx, cy, rad * 0.58, ulPct, root.ulColor, null, null)
                return
            }
            if (ct === 5) {
                const barH = 10, gap = 8, bx = yLW + 10, bw = gW - 20
                let activeCount = (!root.isLineDisabled("dl") ? 1 : 0) + (!root.isLineDisabled("ul") ? 1 : 0)
                let y = height / 2 - (activeCount * barH + (activeCount - 1) * gap) / 2
                if (!root.isLineDisabled("dl")) {
                    cu.drawHorizontalBar(ctx, "Download",
                        (root.downloadSpeed / maxBps) * 100, cu.formatSpeed(root.downloadSpeed), root.dlColor, bx, y, bw, barH)
                    y += barH + gap
                }
                if (!root.isLineDisabled("ul"))
                    cu.drawHorizontalBar(ctx, "Upload",
                        (root.uploadSpeed / maxBps) * 100, cu.formatSpeed(root.uploadSpeed), root.ulColor, bx, y, bw, barH)
                return
            }
            if (ct === 1) {
                if (!root.isLineDisabled("dl")) cu.drawHistoryBars(ctx, dl, root.dlColor, yLW, gW, height, maxH, maxBps, 0)
                if (!root.isLineDisabled("ul")) {
                    ctx.globalAlpha = 0.65
                    cu.drawHistoryBars(ctx, ul, root.ulColor, yLW, gW, height, maxH, maxBps, 0)
                    ctx.globalAlpha = 1.0
                }
                return
            }

            if (plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    { y: bToY(maxBps),     text: cu.formatSpeed(maxBps),     grid: false },
                    { y: bToY(maxBps*0.5), text: cu.formatSpeed(maxBps*0.5), grid: true  },
                    { y: bToY(0),          text: "0",                         grid: false }
                ])
            }

            const fillA = ct === 2 ? 0.60 : 0.35
            function drawLine(history, color, key) {
                if (history.length < 2 || root.isLineDisabled(key)) return
                const len = history.length
                const isHov  = root.hoveredLine === key
                const dimOth = (root.hoveredLine === "dl" || root.hoveredLine === "ul") && !isHov
                ctx.save()
                ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()
                ctx.globalAlpha = dimOth ? 0.15 : 1.0
                ctx.lineWidth   = plasmoid.configuration.lineWidth
                cu.drawLine(ctx, history, color, iToX, bToY, height, smooth, fillA,
                    plasmoid.configuration.glowLine ? (isHov ? 12 : 6) : 0)
                ctx.restore()
            }
            drawLine(ul, root.ulColor, "ul")
            drawLine(dl, root.dlColor, "dl")
        }
    }

    // Session traffic totals
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
        Text {
            text: "↓ " + cu.formatBytes(root.sessionDlBytes)
            color: root.dlColor; font.pixelSize: 10; opacity: 0.80
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "↑ " + cu.formatBytes(root.sessionUlBytes)
            color: root.ulColor; font.pixelSize: 10; opacity: 0.80
        }
    }

    // Combined legend + live values (single row, no duplication)
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }

        // Download legend chip
        Item {
            implicitWidth: dlRow.implicitWidth; implicitHeight: dlRow.implicitHeight
            Row {
                id: dlRow
                spacing: 5
                Rectangle {
                    width: 8; height: 8; radius: 2; anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("dl") ? "transparent" : root.dlColor
                    border.color: root.dlColor; border.width: 1
                }
                Text {
                    text: "Download"
                    color: root.isLineDisabled("dl")
                        ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3)
                        : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("dl")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(root.downloadSpeed)
                    color: root.isLineDisabled("dl")
                        ? Qt.rgba(root.dlColor.r, root.dlColor.g, root.dlColor.b, 0.3)
                        : root.dlColor
                    font.pixelSize: 12; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                onClicked: { root.toggleLineDisabled("dl"); netGraph.requestPaint() }
                onEntered: { root.hoveredLine = "dl"; netGraph.requestPaint() }
                onExited:  { root.hoveredLine = "";   netGraph.requestPaint() }
            }
        }

        Item { Layout.fillWidth: true }

        // Upload legend chip
        Item {
            implicitWidth: ulRow.implicitWidth; implicitHeight: ulRow.implicitHeight
            Row {
                id: ulRow
                spacing: 5
                Rectangle {
                    width: 8; height: 8; radius: 2; anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("ul") ? "transparent" : root.ulColor
                    border.color: root.ulColor; border.width: 1
                }
                Text {
                    text: "Upload"
                    color: root.isLineDisabled("ul")
                        ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3)
                        : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("ul")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(root.uploadSpeed)
                    color: root.isLineDisabled("ul")
                        ? Qt.rgba(root.ulColor.r, root.ulColor.g, root.ulColor.b, 0.3)
                        : root.ulColor
                    font.pixelSize: 12; font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                onClicked: { root.toggleLineDisabled("ul"); netGraph.requestPaint() }
                onEntered: { root.hoveredLine = "ul"; netGraph.requestPaint() }
                onExited:  { root.hoveredLine = "";   netGraph.requestPaint() }
            }
        }
    }
}
