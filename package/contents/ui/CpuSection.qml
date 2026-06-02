import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cpuSection
    spacing: 3

    // No separate header row — total% lives in the legend below the graph

    BloomChart {
        id: cpuGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6

        Connections {
            target: root
            function onCpuHistoryChanged() {
                cpuGraph.requestPaint();
            }
            function onCoreHistoriesChanged() {
                cpuGraph.requestPaint();
            }
            function onTextColorChanged() {
                cpuGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._cpuPhaseStart > 0 && root.cpuScrollPhase() < 2)
                    cpuGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onGlowLineChanged() {
                cpuGraph.requestPaint();
            }
            function onLineWidthChanged() {
                cpuGraph.requestPaint();
            }
            function onShowCpuCoresChanged() {
                cpuGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                cpuGraph.requestPaint();
            }
            function onCpuColorChanged() {
                cpuGraph.requestPaint();
            }
            function onCoreColorsStrChanged() {
                cpuGraph.requestPaint();
            }
            function onChartTypeChanged() {
                cpuGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                cpuGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                cpuGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                cpuGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                cpuGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                cpuGraph.requestPaint();
            }
        }

        // glowPass===true → draw ONLY glowable colored primitives (for the GPU
        // bloom source canvas); false → draw the full chart (axis/grid/fill +
        // crisp lines) with CPU glow suppressed when bloom owns it.
        paint: function (ctx, glowPass) {
            const width = cpuGraph.width, height = cpuGraph.height;
            const h = root.cpuHistory, n = h.length;
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

            // Donut/pie/bar keep their own (cheap, small-shape) in-helper glow;
            // the GPU bloom layer is for the line/area charts only, so the glow
            // pass has nothing to contribute for those types.
            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            const tPad = height * 0.06, uH = height * 0.88;
            const step = gW / Math.max(1, maxH - 1);
            const sf = root.cpuScrollPhase();
            function pToY(p) {
                return height - tPad - (p / 100) * uH;
            }
            function iToX(i, len) {
                return yLW + gW - (len - 2 - i + sf) * step;
            }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36, lw = Math.max(6, rad * 0.22);
                if (!root.isLineDisabled("cpuTotal"))
                    cu.drawDonut(ctx, cx, cy, rad, lw, root.cpuPercent, root.cpuColor, root.cpuPercent.toFixed(1) + "%", "cpu");
                if (plasmoid.configuration.showCpuCores) {
                    for (let ci = 0; ci < Math.min(root.corePercents.length, 8); ci++) {
                        if (root.isCoreDisabled(ci))
                            continue;
                        const cr = rad * (1.0 - (ci + 1) * 0.10);
                        if (cr < rad * 0.25)
                            break;
                        cu.drawDonut(ctx, cx, cy, cr, Math.max(2, lw * 0.30), root.corePercents[ci] || 0, root.coreColors[ci % root.coreColors.length] || "#888888", null, null);
                    }
                }
                return;
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.36;
                if (!root.isLineDisabled("cpuTotal"))
                    cu.drawPie(ctx, cx, cy, rad, root.cpuPercent, root.cpuColor, root.cpuPercent.toFixed(1) + "%", "cpu");
                if (plasmoid.configuration.showCpuCores) {
                    for (let ci = 0; ci < Math.min(root.corePercents.length, 8); ci++) {
                        if (root.isCoreDisabled(ci))
                            continue;
                        const cr = rad * (1.0 - (ci + 1) * 0.10);
                        if (cr < rad * 0.25)
                            break;
                        cu.drawPie(ctx, cx, cy, cr, root.corePercents[ci] || 0, root.coreColors[ci % root.coreColors.length] || "#888888", null, null);
                    }
                }
                return;
            }
            if (ct === 5) {
                const bx = yLW + 10, bw = gW - 20;
                if (plasmoid.configuration.showCpuCores) {
                    const nc = root.corePercents.length;
                    const cols = nc > 8 ? 4 : (nc > 4 ? 2 : 1);
                    const rows = Math.ceil(nc / cols);
                    const barH = Math.max(6, Math.min(10, (height - 10 - (rows - 1) * 6) / rows));
                    const colW = (bw - (cols - 1) * 8) / cols;
                    for (let ci = 0; ci < nc; ci++) {
                        if (root.isCoreDisabled(ci))
                            continue;
                        const col = ci % cols, row = Math.floor(ci / cols);
                        cu.drawHorizontalBar(ctx, "C" + (ci + 1), root.corePercents[ci] || 0, (root.corePercents[ci] || 0).toFixed(0) + "%", root.coreColors[ci % root.coreColors.length] || "#888888", bx + col * (colW + 8), 5 + row * (barH + 6) + 8, colW, barH);
                    }
                } else if (!root.isLineDisabled("cpuTotal")) {
                    cu.drawHorizontalBar(ctx, "CPU Total", root.cpuPercent, root.cpuPercent.toFixed(1) + "%", root.cpuColor, bx, height / 2 - 7, bw, 14);
                }
                return;
            }
            if (ct === 1) {
                if (plasmoid.configuration.showCpuCores) {
                    for (let ci = 0; ci < root.coreHistories.length; ci++) {
                        if (root.isCoreDisabled(ci) || root.coreHistories[ci].length < 1)
                            continue;
                        ctx.globalAlpha = root.hoveredCore === ci ? 1.0 : (root.hoveredCore !== -1 ? 0.18 : 0.55);
                        cu.drawHistoryBars(ctx, root.coreHistories[ci], root.coreColors[ci % root.coreColors.length] || "#888888", yLW, gW, height, maxH, 100, sf);
                    }
                    ctx.globalAlpha = 1.0;
                } else if (!root.isLineDisabled("cpuTotal")) {
                    cu.drawHistoryBars(ctx, h, root.cpuColor, yLW, gW, height, maxH, 100, sf);
                }
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
                        y: pToY(75),
                        text: "75%",
                        grid: true
                    },
                    {
                        y: pToY(50),
                        text: "50%",
                        grid: true
                    },
                    {
                        y: pToY(25),
                        text: "25%",
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
            // No area fill on the glow pass — only the strokes feed the bloom.
            const fillA = glowPass ? 0 : (ct === 2 ? 0.62 : 0.35);

            const coresVisible = plasmoid.configuration.showCpuCores;

            // Draw CPU total first (behind cores). The total is the hero line:
            // keep it at full strength even when cores are shown, so it reads
            // clearly above the faint per-core lines. Only fade it right back
            // when the user is hovering a specific core to inspect it.
            if (n >= 2 && !root.isLineDisabled("cpuTotal")) {
                const isHov = root.hoveredLine === "cpuTotal";
                const anyCorHov = root.hoveredCore !== -1;
                ctx.globalAlpha = (!isHov && anyCorHov) ? 0.15 : 1.0;
                ctx.lineWidth = plasmoid.configuration.lineWidth;
                // No area fill when cores overlay — they'd cover it and it muddies the chart.
                const totalFill = (coresVisible && !isHov) ? 0 : fillA;
                // Glow: on the GPU-bloom crisp pass this resolves to 0 (the bloom
                // layer owns the halo); otherwise it's the CPU shadowBlur value.
                cu.drawLine(ctx, h, root.cpuColor, iToX, pToY, height, smooth, totalFill, plasmoid.configuration.glowLine ? cu.glowFor(isHov ? 7 : 5) : 0);
                ctx.globalAlpha = 1.0;
            }

            if (coresVisible) {
                for (let ci = 0; ci < root.coreHistories.length; ci++) {
                    if (root.isCoreDisabled(ci))
                        continue;
                    const ch = root.coreHistories[ci];
                    if (ch.length < 2)
                        continue;
                    const isHov = root.hoveredCore === ci;
                    const anyHov = root.hoveredCore !== -1;
                    const totHov = root.hoveredLine === "cpuTotal";
                    // Cores are faint background context behind the total line —
                    // unless one is hovered, in which case it pops to full.
                    ctx.globalAlpha = isHov ? 1.0 : ((anyHov || totHov) ? 0.10 : 0.32);
                    ctx.lineWidth = isHov ? plasmoid.configuration.lineWidth : Math.max(0.5, plasmoid.configuration.lineWidth * 0.45);
                    cu.drawLine(ctx, ch, root.coreColors[ci % root.coreColors.length] || "#888888", iToX, pToY, height, smooth, 0, 0);
                    ctx.globalAlpha = 1.0;
                }
            }
            ctx.restore();
        }
    }

    // per-core stats grid
    GridLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showCpuCores && root.corePercents.length > 0
        columns: 2
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
            model: root.corePercents.length
            delegate: Item {
                id: coreItem
                Layout.fillWidth: true
                implicitHeight: 22
                readonly property bool coreActive: !root.isCoreDisabled(index)
                readonly property color coreColor: root.coreColors[index % root.coreColors.length] || "#888888"
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: root.hoveredCore = index
                    onExited: if (root.hoveredCore === index)
                        root.hoveredCore = -1
                    onClicked: {
                        root.toggleCoreDisabled(index);
                        cpuGraph.requestPaint();
                    }
                }
                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: plasmoid.configuration.showYLabels ? 40 : 6
                        rightMargin: 4
                    }
                    spacing: 5
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 2
                        color: coreItem.coreActive ? coreItem.coreColor : "transparent"
                        border.color: coreItem.coreColor
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Core " + (index + 1)
                        color: root.textColor
                        opacity: coreItem.coreActive ? 0.70 : 0.35
                        font.pixelSize: 11
                        font.strikeout: !coreItem.coreActive
                        elide: Text.ElideRight
                    }
                    Text {
                        text: (root.corePercents[index] || 0).toFixed(1) + "%"
                        color: coreItem.coreActive ? coreItem.coreColor : Qt.rgba(coreItem.coreColor.r, coreItem.coreColor.g, coreItem.coreColor.b, 0.4)
                        font.pixelSize: 11
                        font.bold: true
                        Layout.minimumWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
