import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compact

    readonly property var _root: {
        let p = compact.parent
        while (p && !p.hasOwnProperty("showPingSection")) p = p.parent
        return p
    }
    readonly property bool _valid: _root !== null && _root !== undefined

    // ── helpers ──────────────────────────────────────────────────────────────
    function _fmtSpeed(bps) {
        if (bps >= 1073741824) return (bps / 1073741824).toFixed(1) + "G/s"
        if (bps >= 1048576)    return (bps / 1048576).toFixed(0)    + "M/s"
        if (bps >= 1024)       return (bps / 1024).toFixed(0)       + "K/s"
        return bps.toFixed(0) + "B/s"
    }
    function _fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + "G"
        if (b >= 1048576)    return (b / 1048576).toFixed(0)    + "M"
        if (b >= 1024)       return (b / 1024).toFixed(0)       + "K"
        return b.toFixed(0) + "B"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }

    // ── Panel mode: rich stacked layout ──────────────────────────────────────
    Loader {
        anchors.fill: parent
        sourceComponent: plasmoid.configuration.panelMode ? panelComp : sparkComp
    }

    // ── Sparkline fallback (original compact view) ────────────────────────────
    Component {
        id: sparkComp

        RowLayout {
            anchors { fill: parent; margins: 2 }
            spacing: 4

            Canvas {
                id: sparkCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                antialiasing: true
                renderStrategy: Canvas.Cooperative

                readonly property var _h: {
                    if (!compact._valid) return []
                    if (compact._root.showPingSection)   return compact._root.histories[compact._root.activeTarget] || []
                    if (compact._root.showNetworkSpeed)  return compact._root.dlHistory
                    if (compact._root.showCpuSection)    return compact._root.cpuHistory
                    if (compact._root.showMemorySection) return compact._root.memHistory
                    if (compact._root.showDiskSection)   return []
                    return compact._root.customHistory
                }
                readonly property real _max: {
                    if (!compact._valid) return 100
                    if (compact._root.showPingSection)   return 200
                    if (compact._root.showNetworkSpeed)
                        return Math.max(1024, Math.max.apply(null, [1024].concat(compact._root.dlHistory).concat(compact._root.ulHistory))) * 1.2
                    if (compact._root.showCpuSection)    return 100
                    if (compact._root.showMemorySection) return 100
                    return Math.max(0.1, plasmoid.configuration.customCmdMax)
                }
                readonly property color _c: {
                    if (!compact._valid) return Kirigami.Theme.highlightColor
                    if (compact._root.showPingSection)   return compact._root.isAlerting ? "#ff6666" : compact._root.lineColor
                    if (compact._root.showNetworkSpeed)  return compact._root.dlColor
                    if (compact._root.showCpuSection)    return compact._root.cpuColor
                    if (compact._root.showMemorySection) return compact._root.memColor
                    return Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00")
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const h = _h, n = h.length, c = _c
                    if (n < 2) {
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.3)
                        ctx.lineWidth = 1; ctx.setLineDash([3, 4])
                        ctx.beginPath(); ctx.moveTo(0, height / 2); ctx.lineTo(width, height / 2); ctx.stroke()
                        ctx.setLineDash([])
                        return
                    }
                    const maxVal = _max, pad = 2, uH = height - pad * 2
                    const step = width / Math.max(1, n - 1)
                    function vToY(v) { return height - pad - (Math.max(0, Math.min(maxVal, v < 0 ? 0 : v)) / maxVal) * uH }
                    function iToX(i) { return i * step }
                    if (plasmoid.configuration.glowLine) { ctx.shadowBlur = 6; ctx.shadowColor = c }
                    ctx.strokeStyle = c; ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
                    ctx.beginPath(); ctx.moveTo(iToX(0), vToY(h[0]))
                    for (let i = 1; i < n; i++) {
                        const cx = (iToX(i-1) + iToX(i)) / 2
                        ctx.bezierCurveTo(cx, vToY(h[i-1]), cx, vToY(h[i]), iToX(i), vToY(h[i]))
                    }
                    ctx.stroke(); ctx.shadowBlur = 0
                    ctx.beginPath(); ctx.moveTo(iToX(0), vToY(h[0]))
                    for (let i = 1; i < n; i++) {
                        const cx = (iToX(i-1) + iToX(i)) / 2
                        ctx.bezierCurveTo(cx, vToY(h[i-1]), cx, vToY(h[i]), iToX(i), vToY(h[i]))
                    }
                    ctx.lineTo(iToX(n-1), height); ctx.lineTo(0, height); ctx.closePath()
                    const g = ctx.createLinearGradient(0, 0, 0, height)
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.35))
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                    ctx.fillStyle = g; ctx.fill()
                }
                Connections {
                    target: sparkCanvas
                    function on_hChanged() { sparkCanvas.requestPaint() }
                    function on_cChanged() { sparkCanvas.requestPaint() }
                }
            }

            Text {
                text: {
                    if (!compact._valid) return "…"
                    if (compact._root.showPingSection)   return compact._root.lastPing >= 0 ? compact._root.lastPing.toFixed(0) + "ms" : "—"
                    if (compact._root.showNetworkSpeed)  return compact._fmtSpeed(compact._root.downloadSpeed)
                    if (compact._root.showCpuSection)    return compact._root.cpuPercent.toFixed(0) + "%"
                    if (compact._root.showMemorySection) return compact._root.memPercent.toFixed(0) + "%"
                    return compact._root.customValue.toFixed(1)
                }
                color: {
                    if (!compact._valid) return Kirigami.Theme.highlightColor
                    if (compact._root.showPingSection)   return compact._root.isAlerting ? "#ff6666" : compact._root.lineColor
                    if (compact._root.showNetworkSpeed)  return compact._root.dlColor
                    if (compact._root.showCpuSection)    return compact._root.cpuColor
                    if (compact._root.showMemorySection) return compact._root.memColor
                    return Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00")
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

            // glassy pill background
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                color: plasmoid.configuration.bgColor || "#800d0f1a"
                border.color: Qt.rgba(1, 1, 1, 0.13)
                border.width: 1
                // inner highlight line
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.topMargin: 1
                    height: 1; radius: 0.5
                    color: Qt.rgba(1, 1, 1, 0.22)
                }
            }

            // ── Network section: ↓ on top, ↑ below ───────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showNetworkSpeed
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        // Download row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "↓"
                                color: Qt.rgba(compact._root.dlColor.r, compact._root.dlColor.g, compact._root.dlColor.b, 0.65)
                                font.pixelSize: Math.max(8, compact.height * 0.28)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.downloadSpeed)
                                color: compact._root.dlColor
                                font.pixelSize: Math.max(9, compact.height * 0.32)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }
                            // session total
                            Text {
                                visible: plasmoid.configuration.panelShowSessionTotals && compact.height >= 30
                                text: compact._fmtBytes(compact._root.sessionDlBytes)
                                color: Qt.rgba(compact._root.dlColor.r, compact._root.dlColor.g, compact._root.dlColor.b, 0.5)
                                font.pixelSize: Math.max(7, compact.height * 0.22)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        // Upload row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: "↑"
                                color: Qt.rgba(compact._root.ulColor.r, compact._root.ulColor.g, compact._root.ulColor.b, 0.65)
                                font.pixelSize: Math.max(8, compact.height * 0.28)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: compact._fmtSpeed(compact._root.uploadSpeed)
                                color: compact._root.ulColor
                                font.pixelSize: Math.max(9, compact.height * 0.32)
                                font.bold: true
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: plasmoid.configuration.panelShowSessionTotals && compact.height >= 30
                                text: compact._fmtBytes(compact._root.sessionUlBytes)
                                color: Qt.rgba(compact._root.ulColor.r, compact._root.ulColor.g, compact._root.ulColor.b, 0.5)
                                font.pixelSize: Math.max(7, compact.height * 0.22)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
            }

            // ── CPU section: label + % ────────────────────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showCpuSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: plasmoid.configuration.cpuTitle || "CPU"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.cpuPercent.toFixed(1) + "%"
                            color: compact._root.cpuColor
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        // thin bar
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 1.5
                            color: Qt.rgba(compact._root.cpuColor.r, compact._root.cpuColor.g, compact._root.cpuColor.b, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.cpuPercent / 100)
                                height: parent.height; radius: parent.radius
                                color: compact._root.cpuColor
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            // ── Memory section ────────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showMemorySection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: plasmoid.configuration.memoryTitle || "RAM"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.memPercent.toFixed(1) + "%"
                            color: compact._root.memColor
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 1.5
                            color: Qt.rgba(compact._root.memColor.r, compact._root.memColor.g, compact._root.memColor.b, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.memPercent / 100)
                                height: parent.height; radius: parent.radius
                                color: compact._root.memColor
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            // ── Ping section ──────────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showPingSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: plasmoid.configuration.pingTitle || "Ping"
                            color: compact._root.isAlerting
                                ? "#ff6666"
                                : Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.lastPing >= 0 ? compact._root.lastPing.toFixed(0) + "ms" : "—"
                            color: compact._root.isAlerting ? "#ff6666" : compact._root.lineColor
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ── GPU section ───────────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showGpuSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: plasmoid.configuration.gpuTitle || "GPU"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.gpuPercent.toFixed(1) + "%"
                            color: compact._root.gpuColor
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 3; radius: 1.5
                            color: Qt.rgba(compact._root.gpuColor.r, compact._root.gpuColor.g, compact._root.gpuColor.b, 0.20)
                            Rectangle {
                                width: parent.width * Math.min(1, compact._root.gpuPercent / 100)
                                height: parent.height; radius: parent.radius
                                color: compact._root.gpuColor
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            // ── Custom section ────────────────────────────────────────────────
            Loader {
                anchors.fill: parent
                anchors.margins: 4
                active: compact._valid && compact._root.showCustomSection
                sourceComponent: Component {
                    ColumnLayout {
                        spacing: 1
                        Text {
                            text: plasmoid.configuration.customCmdTitle || "Sensor"
                            color: Qt.rgba(compact._root.textColor.r, compact._root.textColor.g, compact._root.textColor.b, 0.50)
                            font.pixelSize: Math.max(7, compact.height * 0.22)
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            text: compact._root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || "")
                            color: Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00")
                            font.pixelSize: Math.max(10, compact.height * 0.38)
                            font.bold: true
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
