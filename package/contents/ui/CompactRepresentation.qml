import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compact

    implicitWidth: (_valid && _root.isInPanel && mainLoader.item) ? mainLoader.item.implicitWidth : 0
    implicitHeight: (_valid && _root.isInPanel && mainLoader.item) ? mainLoader.item.implicitHeight : 0

    readonly property var _root: {
        let p = compact.parent;
        while (p && !p.hasOwnProperty("showPingSection"))
            p = p.parent;
        return p;
    }
    readonly property bool _valid: _root !== null && _root !== undefined

    // ── helpers ──────────────────────────────────────────────────────────────
    function panelColor(c) {
        return plasmoid.configuration.panelPlainText ? compact._root.textColor : Qt.color(c);
    }
    function panelAlphaColor(c, alpha) {
        const pc = plasmoid.configuration.panelPlainText ? compact._root.textColor : Qt.color(c);
        return Qt.rgba(pc.r, pc.g, pc.b, alpha);
    }
    function hwTempColor(value, crit) {
        const c = crit > 0 ? crit : 90;
        const r = Math.max(0, (value - 30) / Math.max(20, c - 30));
        if (r >= 0.85)
            return "#ff4444";
        if (r >= 0.72)
            return "#ff8844";
        if (r >= 0.55)
            return "#ffaa22";
        return "#44ddaa";
    }
    function powerBatColor(pct) {
        if (pct <= 15)
            return "#ff4444";
        if (pct <= 30)
            return "#ffaa00";
        return "#44dd88";
    }

    function _fmtSpeed(bps) {
        if (bps >= 1073741824)
            return (bps / 1073741824).toFixed(1) + "G/s";
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(0) + "M/s";
        if (bps >= 1024)
            return (bps / 1024).toFixed(0) + "K/s";
        return bps.toFixed(0) + "B/s";
    }
    function _fmtBytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(1) + "G";
        if (b >= 1048576)
            return (b / 1048576).toFixed(0) + "M";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + "K";
        return b.toFixed(0) + "B";
    }

    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }

    // ── Panel mode: rich stacked layout ──────────────────────────────────────
    Loader {
        id: mainLoader
        anchors.fill: parent
        sourceComponent: (_valid && _root.isInPanel) ? panelComp : sparkComp
    }

    // ── Sparkline fallback (original compact view) ────────────────────────────
    Component {
        id: sparkComp

        RowLayout {
            anchors {
                fill: parent
                margins: 2
            }
            spacing: 4

            Canvas {
                id: sparkCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                antialiasing: true
                renderStrategy: Canvas.Cooperative

                readonly property var _h: {
                    if (!compact._valid)
                        return [];
                    if (compact._root.showPingSection)
                        return compact._root.histories[compact._root.activeTarget] || [];
                    if (compact._root.showNetworkSpeed)
                        return compact._root.dlHistory;
                    if (compact._root.showCpuSection)
                        return compact._root.cpuHistory;
                    if (compact._root.showMemorySection)
                        return compact._root.memHistory;
                    if (compact._root.showDiskSection)
                        return [];
                    return compact._root.customHistory;
                }
                readonly property real _max: {
                    if (!compact._valid)
                        return 100;
                    if (compact._root.showPingSection)
                        return 200;
                    if (compact._root.showNetworkSpeed)
                        return Math.max(1024, Math.max.apply(null, [1024].concat(compact._root.dlHistory).concat(compact._root.ulHistory))) * 1.2;
                    if (compact._root.showCpuSection)
                        return 100;
                    if (compact._root.showMemorySection)
                        return 100;
                    return Math.max(0.1, plasmoid.configuration.customCmdMax);
                }
                readonly property color _c: {
                    if (!compact._valid)
                        return Kirigami.Theme.highlightColor;
                    if (compact._root.showPingSection)
                        return compact._root.isAlerting ? "#ff6666" : compact._root.lineColor;
                    if (compact._root.showNetworkSpeed)
                        return compact._root.dlColor;
                    if (compact._root.showCpuSection)
                        return compact._root.cpuColor;
                    if (compact._root.showMemorySection)
                        return compact._root.memColor;
                    return Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00");
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const h = _h, n = h.length, c = _c;
                    if (n < 2) {
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.3);
                        ctx.lineWidth = 1;
                        ctx.setLineDash([3, 4]);
                        ctx.beginPath();
                        ctx.moveTo(0, height / 2);
                        ctx.lineTo(width, height / 2);
                        ctx.stroke();
                        ctx.setLineDash([]);
                        return;
                    }
                    const maxVal = _max, pad = 2, uH = height - pad * 2;
                    const step = width / Math.max(1, n - 1);
                    function vToY(v) {
                        return height - pad - (Math.max(0, Math.min(maxVal, v < 0 ? 0 : v)) / maxVal) * uH;
                    }
                    function iToX(i) {
                        return i * step;
                    }
                    const cc = Qt.color(c);
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.beginPath();
                    ctx.moveTo(iToX(0), vToY(h[0]));
                    for (let i = 1; i < n; i++) {
                        const cx = (iToX(i - 1) + iToX(i)) / 2;
                        ctx.bezierCurveTo(cx, vToY(h[i - 1]), cx, vToY(h[i]), iToX(i), vToY(h[i]));
                    }
                    if (plasmoid.configuration.glowLine) {
                        ctx.lineWidth = 5.5;
                        ctx.strokeStyle = Qt.rgba(cc.r, cc.g, cc.b, 0.22);
                        ctx.stroke();
                    }
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = c;
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(iToX(0), vToY(h[0]));
                    for (let i = 1; i < n; i++) {
                        const cx = (iToX(i - 1) + iToX(i)) / 2;
                        ctx.bezierCurveTo(cx, vToY(h[i - 1]), cx, vToY(h[i]), iToX(i), vToY(h[i]));
                    }
                    ctx.lineTo(iToX(n - 1), height);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    const g = ctx.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.35));
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
                Connections {
                    target: sparkCanvas
                    function on_hChanged() {
                        sparkCanvas.requestPaint();
                    }
                    function on_cChanged() {
                        sparkCanvas.requestPaint();
                    }
                }
            }

            Text {
                text: {
                    if (!compact._valid)
                        return "…";
                    if (compact._root.showPingSection)
                        return compact._root.lastPing >= 0 ? compact._root.lastPing.toFixed(0) + "ms" : "—";
                    if (compact._root.showNetworkSpeed)
                        return compact._fmtSpeed(compact._root.downloadSpeed);
                    if (compact._root.showCpuSection)
                        return compact._root.cpuPercent.toFixed(0) + "%";
                    if (compact._root.showMemorySection)
                        return compact._root.memPercent.toFixed(0) + "%";
                    return compact._root.customValue.toFixed(1);
                }
                color: {
                    if (!compact._valid)
                        return Kirigami.Theme.highlightColor;
                    if (compact._root.showPingSection)
                        return compact._root.isAlerting ? "#ff6666" : compact._root.lineColor;
                    if (compact._root.showNetworkSpeed)
                        return compact._root.dlColor;
                    if (compact._root.showCpuSection)
                        return compact._root.cpuColor;
                    if (compact._root.showMemorySection)
                        return compact._root.memColor;
                    return Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00");
                }
                font.pixelSize: Math.max(9, Math.min(14, compact.height * 0.45))
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ── Panel mode component ──────────────────────────────────────────────────
    Component {
        id: panelComp

        Item {
            id: panelRoot

            // padding around the content, inside the pill
            readonly property int hPad: 5
            readonly property int vPad: 3

            // the currently-active section loader (only one is active at a time)
            readonly property Loader activeLoader: {
                if (netLoader.active)
                    return netLoader;
                if (diskLoader.active)
                    return diskLoader;
                if (cpuLoader.active)
                    return cpuLoader;
                if (memLoader.active)
                    return memLoader;
                if (pingLoader.active)
                    return pingLoader;
                if (gpuLoader.active)
                    return gpuLoader;
                if (customLoader.active)
                    return customLoader;
                if (hwSensorsLoader.active)
                    return hwSensorsLoader;
                if (osInfoLoader.active)
                    return osInfoLoader;
                if (powerLoader.active)
                    return powerLoader;
                return null;
            }
            readonly property real contentW: activeLoader && activeLoader.item ? activeLoader.item.implicitWidth : 0
            readonly property real contentH: activeLoader && activeLoader.item ? activeLoader.item.implicitHeight : 0

            implicitWidth: contentW + hPad * 2
            implicitHeight: contentH + vPad * 2

            // Glass pill tracks the content width. Plasma can keep a wider panel
            // slot around applets; do not paint that slack as empty pill space.
            Rectangle {
                id: pill
                visible: plasmoid.configuration.panelShowBg
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                width: Math.max(16, panelRoot.contentW + panelRoot.hPad * 2)
                height: Math.min(parent.height - 2, Math.max(16, panelRoot.contentH + panelRoot.vPad * 2))
                radius: height / 2
                color: plasmoid.configuration.bgColor || "#800d0f1a"
                border.color: Qt.rgba(1, 1, 1, 0.13)
                border.width: 1
                // inner highlight line
                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 1
                    height: 1
                    radius: 0.5
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
            }

            // ── Network section: ↓ on top, ↑ below ───────────────────────────
            Loader {
                id: netLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showNetworkSpeed
                sourceComponent: Component {
                    // Two stacked rows must fit the panel height, so each row's
                    // font is sized off ~half the height (not the full height) —
                    // otherwise ↓ and ↑ together overflow the pill.
                    ColumnLayout {
                        spacing: 0
                        implicitWidth: Math.max(downloadRow.implicitWidth, uploadRow.implicitWidth)
                        // Download row
                        RowLayout {
                            id: downloadRow
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3
                            Text {
                                text: "↓"
                                color: compact.panelAlphaColor(compact._root.dlColor, 0.65)
                                font.pixelSize: Math.max(7, compact.height * 0.20)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.downloadSpeed)
                                color: compact.panelColor(compact._root.dlColor)
                                font.pixelSize: Math.max(8, compact.height * 0.23)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            // session total
                            Text {
                                visible: compact._root.panelSessionTotalsVisible
                                text: compact._fmtBytes(compact._root.sessionDlBytes)
                                color: compact.panelAlphaColor(compact._root.dlColor, 0.5)
                                font.pixelSize: Math.max(7, compact.height * 0.17)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        // Upload row
                        RowLayout {
                            id: uploadRow
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 3
                            Text {
                                text: "↑"
                                color: compact.panelAlphaColor(compact._root.ulColor, 0.65)
                                font.pixelSize: Math.max(7, compact.height * 0.20)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.uploadSpeed)
                                color: compact.panelColor(compact._root.ulColor)
                                font.pixelSize: Math.max(8, compact.height * 0.23)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                visible: compact._root.panelSessionTotalsVisible
                                text: compact._fmtBytes(compact._root.sessionUlBytes)
                                color: compact.panelAlphaColor(compact._root.ulColor, 0.5)
                                font.pixelSize: Math.max(7, compact.height * 0.17)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }

            // ── CPU section: label + % ────────────────────────────────────────
            Loader {
                id: cpuLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showCpuSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.cpuTitle || "CPU"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.cpuPercent.toFixed(1) + "%"
                            color: compact.panelColor(compact._root.cpuColor)
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        // thin bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1.5
                            color: compact.panelAlphaColor(compact._root.cpuColor, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.cpuPercent / 100)
                                height: parent.height
                                radius: parent.radius
                                color: compact.panelColor(compact._root.cpuColor)
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Memory section ────────────────────────────────────────────────
            Loader {
                id: memLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showMemorySection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.memoryTitle || "RAM"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.memPercent.toFixed(1) + "%"
                            color: compact.panelColor(compact._root.memColor)
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1.5
                            color: compact.panelAlphaColor(compact._root.memColor, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.memPercent / 100)
                                height: parent.height
                                radius: parent.radius
                                color: compact.panelColor(compact._root.memColor)
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Ping section ──────────────────────────────────────────────────
            Loader {
                id: pingLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showPingSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.pingTitle || "Ping"
                            color: compact._root.isAlerting ? "#ff6666" : Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.lastPing >= 0 ? compact._root.lastPing.toFixed(0) + "ms" : "—"
                            color: compact._root.isAlerting ? "#ff6666" : compact.panelColor(compact._root.lineColor)
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── GPU section ───────────────────────────────────────────────────
            Loader {
                id: gpuLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showGpuSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.gpuTitle || "GPU"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.gpuPercent.toFixed(1) + "%"
                            color: compact.panelColor(compact._root.gpuColor)
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1.5
                            color: compact.panelAlphaColor(compact._root.gpuColor, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.gpuPercent / 100)
                                height: parent.height
                                radius: parent.radius
                                color: compact.panelColor(compact._root.gpuColor)
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Disk I/O section: R on top, W below ───────────────────────────
            Loader {
                id: diskLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showDiskSection
                sourceComponent: Component {
                    // Two stacked rows (R / W) — size each off ~half the height
                    // so they fit the pill instead of overflowing.
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(60, compact.height * 2.2)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "R"
                                color: compact.panelAlphaColor(compact._root.diskRdColor, 0.65)
                                font.pixelSize: Math.max(7, compact.height * 0.21)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.diskReadSpeed)
                                color: compact.panelColor(compact._root.diskRdColor)
                                font.pixelSize: Math.max(8, compact.height * 0.24)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "W"
                                color: compact.panelAlphaColor(compact._root.diskWrColor, 0.65)
                                font.pixelSize: Math.max(7, compact.height * 0.21)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.diskWriteSpeed)
                                color: compact.panelColor(compact._root.diskWrColor)
                                font.pixelSize: Math.max(8, compact.height * 0.24)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── Custom section ────────────────────────────────────────────────
            Loader {
                id: customLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showCustomSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.customCmdTitle || "Sensor"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || "")
                            color: compact.panelColor(Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00"))
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── Hardware Sensors section ──────────────────────────────────────
            Loader {
                id: hwSensorsLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showHwSensors
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.hwSensorsTitle || "Temp"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.hwMaxTemp.toFixed(1) + "°C"
                            color: compact.panelColor(compact.hwTempColor(compact._root.hwMaxTemp, compact._root.hwMaxTempCrit))
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1.5
                            color: compact.panelAlphaColor(compact.hwTempColor(compact._root.hwMaxTemp, compact._root.hwMaxTempCrit), 0.20)
                            Rectangle {
                                width: parent.width * Math.max(0.05, Math.min(1, compact._root.hwMaxTemp / (compact._root.hwMaxTempCrit > 0 ? compact._root.hwMaxTempCrit : 90)))
                                height: parent.height
                                radius: parent.radius
                                color: compact.panelColor(compact.hwTempColor(compact._root.hwMaxTemp, compact._root.hwMaxTempCrit))
                            }
                        }
                    }
                }
            }

            // ── OS Info section ───────────────────────────────────────────────
            Loader {
                id: osInfoLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showOsInfo
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(48, compact.height * 1.8)
                        Text {
                            text: plasmoid.configuration.osInfoTitle || "Uptime"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.osUptime || "—"
                            color: compact.panelColor(compact._root.lineColor)
                            font.pixelSize: Math.max(8, compact.height * 0.33)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── Power section ─────────────────────────────────────────────────
            Loader {
                id: powerLoader
                anchors.centerIn: pill
                width: pill.width - panelRoot.hPad * 2
                active: compact._valid && compact._root.showPowerSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        implicitWidth: Math.max(44, compact.height * 1.6)
                        Text {
                            text: plasmoid.configuration.powerTitle || "BAT"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: {
                                if (!compact._root.batteryPresent)
                                    return "No Bat";
                                let isChg = compact._root.batteryStatus === "Charging";
                                return (isChg ? "⚡ " : "") + compact._root.batteryPercent + "%";
                            }
                            color: compact.panelColor(compact.powerBatColor(compact._root.batteryPercent))
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 3
                            radius: 1.5
                            color: compact.panelAlphaColor(compact.powerBatColor(compact._root.batteryPercent), 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.batteryPercent / 100)
                                height: parent.height
                                radius: parent.radius
                                color: compact.panelColor(compact.powerBatColor(compact._root.batteryPercent))
                            }
                        }
                    }
                }
            }
        }
    }
}
