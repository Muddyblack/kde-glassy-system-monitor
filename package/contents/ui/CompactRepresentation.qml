import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: compact

    // Resolved after creation by Plasma — walk up to PlasmoidItem
    readonly property var _root: {
        let p = compact.parent
        while (p && !p.hasOwnProperty("showPingSection")) p = p.parent
        return p
    }

    readonly property bool _valid: _root !== null && _root !== undefined

    readonly property var activeHistory: {
        if (!_valid) return []
        if (_root.showPingSection)   return _root.histories[_root.activeTarget] || []
        if (_root.showNetworkSpeed)  return _root.dlHistory
        if (_root.showCpuSection)    return _root.cpuHistory
        if (_root.showMemorySection) return _root.memHistory
        if (_root.showDiskSection)   return []
        return _root.customHistory
    }

    readonly property real activeMax: {
        if (!_valid) return 100
        if (_root.showPingSection)   return 200
        if (_root.showNetworkSpeed)  return Math.max(1024, Math.max.apply(null, [1024].concat(_root.dlHistory).concat(_root.ulHistory))) * 1.2
        if (_root.showCpuSection)    return 100
        if (_root.showMemorySection) return 100
        return Math.max(0.1, plasmoid.configuration.customCmdMax)
    }

    readonly property string activeLabel: {
        if (!_valid) return "…"
        if (_root.showPingSection)   return _root.lastPing >= 0 ? _root.lastPing.toFixed(0) + "ms" : "—"
        if (_root.showNetworkSpeed)  return _formatSpeed(_root.downloadSpeed)
        if (_root.showCpuSection)    return _root.cpuPercent.toFixed(0) + "%"
        if (_root.showMemorySection) return _root.memPercent.toFixed(0) + "%"
        return _root.customValue.toFixed(1)
    }

    readonly property color activeColor: {
        if (!_valid) return Kirigami.Theme.highlightColor
        if (_root.showPingSection)   return _root.isAlerting ? "#ff6666" : _root.lineColor
        if (_root.showNetworkSpeed)  return _root.dlColor
        if (_root.showCpuSection)    return _root.cpuColor
        if (_root.showMemorySection) return _root.memColor
        return Qt.color(plasmoid.configuration.customCmdColor || "#ffaa00")
    }

    function _formatSpeed(bps) {
        if (bps >= 1073741824) return (bps / 1073741824).toFixed(1) + "G/s"
        if (bps >= 1048576)    return (bps / 1048576).toFixed(0)    + "M/s"
        if (bps >= 1024)       return (bps / 1024).toFixed(0)       + "K/s"
        return bps.toFixed(0) + "B/s"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: plasmoid.expanded = !plasmoid.expanded
    }

    RowLayout {
        anchors { fill: parent; margins: 2 }
        spacing: 4

        Canvas {
            id: sparkCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            antialiasing: true
            renderStrategy: Canvas.Cooperative

            Connections {
                target: compact
                function onActiveHistoryChanged() { sparkCanvas.requestPaint() }
                function onActiveColorChanged()   { sparkCanvas.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d"); ctx.reset()
                const h = compact.activeHistory
                const n = h.length
                const c = compact.activeColor

                if (n < 2) {
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.3)
                    ctx.lineWidth = 1; ctx.setLineDash([3, 4])
                    ctx.beginPath(); ctx.moveTo(0, height / 2); ctx.lineTo(width, height / 2); ctx.stroke()
                    ctx.setLineDash([])
                    return
                }

                const maxVal = compact.activeMax
                const pad    = 2
                const uH     = height - pad * 2
                const step   = width / Math.max(1, n - 1)

                function vToY(v) { return height - pad - (Math.max(0, Math.min(maxVal, v < 0 ? 0 : v)) / maxVal) * uH }
                function iToX(i) { return i * step }

                if (plasmoid.configuration.glowLine) {
                    ctx.shadowBlur = 6; ctx.shadowColor = c
                }
                ctx.strokeStyle = c
                ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
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
        }

        Text {
            text: compact.activeLabel
            color: compact.activeColor
            font.pixelSize: Math.max(9, Math.min(14, compact.height * 0.45))
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
