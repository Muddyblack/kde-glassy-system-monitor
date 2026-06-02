import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasma5support as P5Support

ColumnLayout {
    id: diskSection
    spacing: 3

    // ── state ─────────────────────────────────────────────────────────────────
    property real readSpeed: 0
    property real writeSpeed: 0
    property var rdHistory: []
    property var wrHistory: []
    property var lastDiskStats: null
    property bool isReading: false
    property string activeDisk: ""

    // cached Qt.color objects so we don't allocate on every paint
    readonly property color rdColor: plasmoid.configuration.diskRdColor || "#22ddff"
    readonly property color wrColor: plasmoid.configuration.diskWrColor || "#ffaa22"

    // ── data source ───────────────────────────────────────────────────────────
    P5Support.DataSource {
        id: diskSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            diskSection.isReading = false;
            diskSource.disconnectSource(sourceName);
            diskSection.parseDiskStats(data["stdout"] || "");
        }
    }

    Timer {
        interval: 1000
        running: root.showDiskSection
        repeat: true
        onTriggered: {
            if (!diskSection.isReading) {
                diskSection.isReading = true;
                diskSource.connectSource("cat /proc/diskstats");
            }
        }
    }

    function parseDiskStats(text) {
        // /proc/diskstats columns (1-based): major minor name rd_ios rd_merges rd_sectors rd_ticks
        //   wr_ios wr_merges wr_sectors wr_ticks ...
        // We use rd_sectors(col6) and wr_sectors(col10); 1 sector = 512 bytes
        const cfgDisk = plasmoid.configuration.diskDevice || "auto";
        const diskData = {};
        let bestDisk = "", bestActivity = -1;

        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p.length < 14)
                continue;
            const name = p[2];
            // skip partitions (end in digit AND parent name exists) and loop/ram devices
            if (/^(loop|ram|zram)/.test(name))
                continue;
            // only keep whole disks: no trailing digit after letters (sda, nvme0n1, vda, mmcblk0)
            if (/[0-9]p[0-9]+$/.test(name))
                // nvme0n1p1
                continue;
            if (/^sd[a-z]+[0-9]+$/.test(name))
                // sda1
                continue;
            if (/^vd[a-z]+[0-9]+$/.test(name))
                // vda1
                continue;
            if (/^mmcblk[0-9]+p[0-9]+$/.test(name))
                continue;
            const rd = parseInt(p[5]) * 512;  // sectors → bytes
            const wr = parseInt(p[9]) * 512;
            diskData[name] = {
                rd,
                wr
            };
            const activity = rd + wr;
            if (activity > bestActivity) {
                bestActivity = activity;
                bestDisk = name;
            }
        }

        const disk = (cfgDisk !== "auto" && diskData[cfgDisk]) ? cfgDisk : bestDisk;
        if (!disk || !diskData[disk])
            return;
        const now = Date.now();
        const {
            rd,
            wr
        } = diskData[disk];

        if (lastDiskStats && lastDiskStats.disk === disk) {
            const dt = (now - lastDiskStats.time) / 1000;
            if (dt > 0.1) {
                readSpeed = Math.max(0, (rd - lastDiskStats.rd) / dt);
                writeSpeed = Math.max(0, (wr - lastDiskStats.wr) / dt);
                root.diskReadSpeed = readSpeed;
                root.diskWriteSpeed = writeSpeed;
                const maxH = Math.max(10, plasmoid.configuration.historySize);
                const nr = rdHistory.slice();
                nr.push(readSpeed);
                if (nr.length > maxH + 1)
                    nr.splice(0, nr.length - (maxH + 1));
                rdHistory = nr;
                const nw = wrHistory.slice();
                nw.push(writeSpeed);
                if (nw.length > maxH + 1)
                    nw.splice(0, nw.length - (maxH + 1));
                wrHistory = nw;
            }
        }
        lastDiskStats = {
            disk,
            rd,
            wr,
            time: now
        };
        activeDisk = disk;
        root.restartDiskScroll();
    }

    // ── disk name badge ───────────────────────────────────────────────────────
    Text {
        Layout.leftMargin: plasmoid.configuration.showYLabels ? 42 : 4
        text: diskSection.activeDisk || ""
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
        font.pixelSize: 9
        visible: diskSection.activeDisk !== ""
    }

    // ── graph ─────────────────────────────────────────────────────────────────
    BloomChart {
        id: diskGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6

        Connections {
            target: diskSection
            function onRdHistoryChanged() {
                diskGraph.requestPaint();
            }
            function onWrHistoryChanged() {
                diskGraph.requestPaint();
            }
        }
        Connections {
            target: root
            function onTextColorChanged() {
                diskGraph.requestPaint();
            }
            function onHoveredLineChanged() {
                diskGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._dskPhaseStart > 0 && root.diskScrollPhase() < 2)
                    diskGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onGlowLineChanged() {
                diskGraph.requestPaint();
            }
            function onLineWidthChanged() {
                diskGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                diskGraph.requestPaint();
            }
            function onDiskRdColorChanged() {
                diskGraph.requestPaint();
            }
            function onDiskWrColorChanged() {
                diskGraph.requestPaint();
            }
            function onChartTypeChanged() {
                diskGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                diskGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                diskGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                diskGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                diskGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                diskGraph.requestPaint();
            }
        }

        paint: function (ctx, glowPass) {
            const width = diskGraph.width, height = diskGraph.height;
            const rd = diskSection.rdHistory, wr = diskSection.wrHistory;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const yLW = plasmoid.configuration.showYLabels ? 38 : 0;
            const gW = width - yLW;
            const smooth = plasmoid.configuration.smoothLines;
            const ct = plasmoid.configuration.chartType || 0;

            if (rd.length < 1 && wr.length < 1) {
                if (!glowPass)
                    cu.drawIdleLine(ctx, yLW, gW, height);
                return;
            }
            ctx.setLineDash([]);

            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            const allVals = rd.concat(wr);
            const dataMax = allVals.length > 0 ? Math.max.apply(null, allVals) : 0;
            const maxBps = Math.max(1024, dataMax * (plasmoid.configuration.autoYRange ? 1.10 : 1.20));
            const tPad = height * 0.06, uH = height * 0.88;
            const step = gW / Math.max(1, maxH - 1);
            const sf = root.diskScrollPhase();
            function bToY(b) {
                return height - tPad - (b / maxBps) * uH;
            }
            function iToX(i, len) {
                return yLW + gW - (len - 2 - i + sf) * step;
            }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.33, lw = Math.max(6, rad * 0.22);
                if (!root.isLineDisabled("diskRd"))
                    cu.drawDonut(ctx, cx, cy, rad, lw, Math.min(100, (diskSection.readSpeed / maxBps) * 100), diskSection.rdColor, "R " + cu.formatSpeed(diskSection.readSpeed), "W " + cu.formatSpeed(diskSection.writeSpeed));
                if (!root.isLineDisabled("diskWr"))
                    cu.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, Math.min(100, (diskSection.writeSpeed / maxBps) * 100), diskSection.wrColor, null, null);
                return;
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.33;
                if (!root.isLineDisabled("diskRd"))
                    cu.drawPie(ctx, cx, cy, rad, Math.min(100, (diskSection.readSpeed / maxBps) * 100), diskSection.rdColor, "R " + cu.formatSpeed(diskSection.readSpeed), "W " + cu.formatSpeed(diskSection.writeSpeed));
                if (!root.isLineDisabled("diskWr"))
                    cu.drawPie(ctx, cx, cy, rad * 0.58, Math.min(100, (diskSection.writeSpeed / maxBps) * 100), diskSection.wrColor, null, null);
                return;
            }
            if (ct === 5) {
                const barH = 10, gap = 8, bx = yLW + 10, bw = gW - 20;
                let activeCount = (!root.isLineDisabled("diskRd") ? 1 : 0) + (!root.isLineDisabled("diskWr") ? 1 : 0);
                let y = height / 2 - (activeCount * barH + (activeCount - 1) * gap) / 2;
                if (!root.isLineDisabled("diskRd")) {
                    cu.drawHorizontalBar(ctx, "Read", (diskSection.readSpeed / maxBps) * 100, cu.formatSpeed(diskSection.readSpeed), diskSection.rdColor, bx, y, bw, barH);
                    y += barH + gap;
                }
                if (!root.isLineDisabled("diskWr"))
                    cu.drawHorizontalBar(ctx, "Write", (diskSection.writeSpeed / maxBps) * 100, cu.formatSpeed(diskSection.writeSpeed), diskSection.wrColor, bx, y, bw, barH);
                return;
            }
            if (ct === 1) {
                if (!root.isLineDisabled("diskRd"))
                    cu.drawHistoryBars(ctx, rd, diskSection.rdColor, yLW, gW, height, maxH, maxBps, sf);
                if (!root.isLineDisabled("diskWr")) {
                    ctx.globalAlpha = 0.65;
                    cu.drawHistoryBars(ctx, wr, diskSection.wrColor, yLW, gW, height, maxH, maxBps, sf);
                    ctx.globalAlpha = 1.0;
                }
                return;
            }

            if (!glowPass && plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    {
                        y: bToY(maxBps),
                        text: cu.formatSpeed(maxBps),
                        grid: false
                    },
                    {
                        y: bToY(maxBps * 0.5),
                        text: cu.formatSpeed(maxBps * 0.5),
                        grid: true
                    },
                    {
                        y: bToY(0),
                        text: "0",
                        grid: false
                    }
                ]);
            }

            const fillA = glowPass ? 0 : (ct === 2 ? 0.60 : 0.35);
            function drawLine(history, color, key) {
                if (history.length < 2 || root.isLineDisabled(key))
                    return;
                const isHov = root.hoveredLine === key;
                const dimOth = (root.hoveredLine === "diskRd" || root.hoveredLine === "diskWr") && !isHov;
                ctx.save();
                ctx.beginPath();
                ctx.rect(yLW, 0, gW, height);
                ctx.clip();
                ctx.globalAlpha = dimOth ? 0.15 : 1.0;
                ctx.lineWidth = plasmoid.configuration.lineWidth;
                // Glow resolves to 0 on the GPU-bloom crisp pass (bloom owns it).
                cu.drawLine(ctx, history, color, iToX, bToY, height, smooth, fillA, plasmoid.configuration.glowLine ? cu.glowFor(isHov ? 7 : 4) : 0);
                ctx.restore();
            }
            drawLine(wr, diskSection.wrColor, "diskWr");
            drawLine(rd, diskSection.rdColor, "diskRd");
        }
    }

    // ── legend + live values ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: plasmoid.configuration.showLegend
        spacing: 6
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }

        Item {
            implicitWidth: rdRow.implicitWidth
            implicitHeight: rdRow.implicitHeight
            Row {
                id: rdRow
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("diskRd") ? "transparent" : diskSection.rdColor
                    border.color: diskSection.rdColor
                    border.width: 1
                }
                Text {
                    text: "Read"
                    color: root.isLineDisabled("diskRd") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("diskRd")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(diskSection.readSpeed)
                    color: root.isLineDisabled("diskRd") ? Qt.rgba(diskSection.rdColor.r, diskSection.rdColor.g, diskSection.rdColor.b, 0.3) : diskSection.rdColor
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("diskRd");
                    diskGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "diskRd";
                    diskGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    diskGraph.requestPaint();
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Item {
            implicitWidth: wrRow.implicitWidth
            implicitHeight: wrRow.implicitHeight
            Row {
                id: wrRow
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("diskWr") ? "transparent" : diskSection.wrColor
                    border.color: diskSection.wrColor
                    border.width: 1
                }
                Text {
                    text: "Write"
                    color: root.isLineDisabled("diskWr") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("diskWr")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(diskSection.writeSpeed)
                    color: root.isLineDisabled("diskWr") ? Qt.rgba(diskSection.wrColor.r, diskSection.wrColor.g, diskSection.wrColor.b, 0.3) : diskSection.wrColor
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("diskWr");
                    diskGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "diskWr";
                    diskGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    diskGraph.requestPaint();
                }
            }
        }
    }
}
