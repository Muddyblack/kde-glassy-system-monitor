import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Section selection (0=Ping, 1=Network, 2=CPU, 3=Memory, 4=Custom Command) ───────────────
    readonly property bool showPingSection:   plasmoid.configuration.activeSection === 0
    readonly property bool showNetworkSpeed:  plasmoid.configuration.activeSection === 1
    readonly property bool showCpuSection:    plasmoid.configuration.activeSection === 2
    readonly property bool showMemorySection: plasmoid.configuration.activeSection === 3
    readonly property bool showCustomSection: plasmoid.configuration.activeSection === 4

    Layout.minimumWidth: 260
    Layout.preferredWidth: 400
    Layout.preferredHeight: {
        const m = plasmoid.configuration.showBg ? 20 : 4
        const title = 26
        const pingRow = 26
        const stats = plasmoid.configuration.showStats && root.showPingSection ? 28 : 0
        const legend = plasmoid.configuration.showLegend ? 18 : 0
        const isTextOnly = plasmoid.configuration.chartType === 6
        let h = m + title
        if (root.showPingSection)   h += pingRow + (isTextOnly ? 24 : 98) + stats + legend
        if (root.showNetworkSpeed)  h += (isTextOnly ? 24 : 78) + legend
        if (root.showCpuSection)    h += (isTextOnly ? 24 : 78) + legend + (!isTextOnly && plasmoid.configuration.showCpuCores ? 100 : 0)
        if (root.showMemorySection) h += (isTextOnly ? 24 : 78) + legend
        if (root.showCustomSection) h += (isTextOnly ? 24 : 78) + legend
        return Math.max(80, h)
    }
    Layout.minimumHeight: 80

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color lineColor: plasmoid.configuration.useSystemAccent ? accentColor : (plasmoid.configuration.customColor || "#39ff14")
    readonly property color textColor: plasmoid.configuration.useSystemTextColor ? Kirigami.Theme.textColor : (plasmoid.configuration.customTextColor || "#ffffff")
    readonly property color dlColor:   plasmoid.configuration.dlColor || "#22aaff"
    readonly property color ulColor:   plasmoid.configuration.ulColor || "#ff9933"
    readonly property color cpuColor:  plasmoid.configuration.cpuColor || "#44ddaa"
    readonly property color memColor:  plasmoid.configuration.memColor || "#aa66ff"
    readonly property color swapColor: plasmoid.configuration.swapColor || "#ff6688"
    readonly property var coreColors:  (plasmoid.configuration.coreColorsStr || "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff").split(",")

    property real renderClock: 0
    Timer {
        interval: 33; repeat: true; running: true
        onTriggered: root.renderClock = Date.now()
    }

    readonly property var targetList: {
        const raw = plasmoid.configuration.targets || "8.8.8.8"
        return raw.split(",").map(s => s.trim()).filter(s => s.length > 0)
    }
    readonly property int activeTarget: Math.max(0, Math.min(plasmoid.configuration.currentTargetIndex, targetList.length - 1))

    property string hoveredLine: ""
    property int hoveredCore: -1

    function isLineDisabled(key) {
        return (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean).indexOf(key) !== -1
    }
    function toggleLineDisabled(key) {
        let arr = (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean)
        if (arr.indexOf(key) !== -1) arr = arr.filter(k => k !== key)
        else arr.push(key)
        plasmoid.configuration.disabledLinesStr = arr.join(",")
    }

    function isCoreDisabled(idx) {
        return (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean).indexOf(idx.toString()) !== -1
    }
    function toggleCoreDisabled(idx) {
        let arr = (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean)
        if (arr.indexOf(idx.toString()) !== -1) arr = arr.filter(k => k !== idx.toString())
        else arr.push(idx.toString())
        plasmoid.configuration.disabledCoresStr = arr.join(",")
    }

    property var histories: []
    property real lastPing: -1
    property real avgPing: 0
    property real jitter: 0
    property real lossPercent: 0
    property bool isAlerting: false
    property bool isPinging: false
    property real lastPingTimestamp: 0

    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var dlHistory: []
    property var ulHistory: []
    property var lastNetBytes: null
    property string activeIface: ""
    property bool isReadingNet: false
    property real lastNetTimestamp: 0

    property real cpuPercent: 0
    property var cpuHistory: []
    property var corePercents: []
    property var coreHistories: []
    property var lastCpuStats: null
    property bool isReadingCpu: false
    property real lastCpuTimestamp: 0

    property real memPercent: 0
    property real swapPercent: 0
    property var memHistory: []
    property var swapHistory: []
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property bool hasSwap: false
    property bool isReadingMem: false
    property real lastMemTimestamp: 0

    Component.onCompleted: { rebuildHistories(); triggerPing() }
    onTargetListChanged: rebuildHistories()

    function rebuildHistories() {
        const h = []
        for (let i = 0; i < targetList.length; i++) h.push(histories[i] || [])
        histories = h
    }

    function drawIdleLine(ctx, gLeft, gW, h) {
        ctx.lineWidth = 1
        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.18)
        ctx.setLineDash([4, 6])
        ctx.beginPath(); ctx.moveTo(gLeft, h / 2); ctx.lineTo(gLeft + gW, h / 2); ctx.stroke()
        ctx.setLineDash([])
    }

    function drawYAxis(ctx, yLW, height, labels) {
        ctx.font = "10px sans-serif"
        ctx.textAlign = "right"
        const showGrid = plasmoid.configuration.showGridLines
        for (const l of labels) {
            if (showGrid || l.grid) {
                ctx.beginPath(); ctx.lineWidth = 0.5
                ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, showGrid ? 0.12 : 0.07)
                ctx.setLineDash([3, 5])
                ctx.moveTo(yLW, l.y); ctx.lineTo(9999, l.y); ctx.stroke()
                ctx.setLineDash([])
            }
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.50)
            ctx.fillText(l.text, yLW - 4, l.y + 3)
        }
    }

    function formatSpeed(bps) {
        if (bps >= 1073741824) return (bps / 1073741824).toFixed(2) + " GiB/s"
        if (bps >= 1048576)    return (bps / 1048576).toFixed(1) + " MiB/s"
        if (bps >= 1024)       return (bps / 1024).toFixed(1) + " KiB/s"
        return bps.toFixed(0) + " B/s"
    }

    // ── Chart helpers ─────────────────────────────────────────────────────────

    function drawDonut(ctx, cx, cy, radius, lineW, percent, color, label, sublabel) {
        ctx.lineCap = "round"
        ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.lineWidth = lineW
        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.12)
        ctx.stroke()
        if (percent > 0.1) {
            const a1 = -Math.PI / 2 + Math.min(1, percent / 100) * Math.PI * 2
            if (plasmoid.configuration.glowLine) { ctx.shadowBlur = 10; ctx.shadowColor = color }
            ctx.beginPath(); ctx.arc(cx, cy, radius, -Math.PI / 2, a1)
            ctx.lineWidth = lineW; ctx.strokeStyle = color; ctx.stroke()
            ctx.shadowBlur = 0
        }
        if (label) {
            ctx.textAlign = "center"
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.92)
            ctx.font = "bold " + Math.round(radius * 0.44) + "px sans-serif"
            ctx.fillText(label, cx, cy + radius * 0.15)
            if (sublabel) {
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.42)
                ctx.font = Math.round(radius * 0.22) + "px sans-serif"
                ctx.fillText(sublabel, cx, cy + radius * 0.52)
            }
        }
    }

    function roundedRectPath(ctx, x, y, w, h, r) {
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.arcTo(x + w, y, x + w, y + r, r)
        ctx.lineTo(x + w, y + h - r)
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r)
        ctx.lineTo(x + r, y + h)
        ctx.arcTo(x, y + h, x, y + h - r, r)
        ctx.lineTo(x, y + r)
        ctx.arcTo(x, y, x + r, y, r)
        ctx.closePath()
    }

    function drawPie(ctx, cx, cy, radius, percent, color, label, sublabel) {
        ctx.beginPath()
        ctx.moveTo(cx, cy)
        ctx.arc(cx, cy, radius, 0, Math.PI * 2)
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08)
        ctx.fill()

        if (percent > 0.1) {
            const a1 = -Math.PI / 2 + Math.min(1, percent / 100) * Math.PI * 2
            if (plasmoid.configuration.glowLine) { ctx.shadowBlur = 8; ctx.shadowColor = color }
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.arc(cx, cy, radius, -Math.PI / 2, a1)
            ctx.lineTo(cx, cy)
            ctx.fillStyle = color
            ctx.fill()
            ctx.shadowBlur = 0
        }

        if (label) {
            ctx.textAlign = "center"
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.92)
            ctx.font = "bold " + Math.round(radius * 0.44) + "px sans-serif"
            ctx.fillText(label, cx, cy + radius * 0.15)
            if (sublabel) {
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.42)
                ctx.font = Math.round(radius * 0.22) + "px sans-serif"
                ctx.fillText(sublabel, cx, cy + radius * 0.52)
            }
        }
    }

    function drawHorizontalBar(ctx, label, percent, valStr, color, x, y, w, h) {
        const r = h / 2
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08)
        roundedRectPath(ctx, x, y, w, h, r)
        ctx.fill()

        if (percent > 0) {
            const filledW = Math.max(h, (Math.min(100, percent) / 100) * w)
            if (plasmoid.configuration.glowLine) { ctx.shadowBlur = 6; ctx.shadowColor = color }
            ctx.fillStyle = color
            roundedRectPath(ctx, x, y, filledW, h, r)
            ctx.fill()
            ctx.shadowBlur = 0
        }

        ctx.font = "8px sans-serif"
        ctx.textAlign = "left"
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65)
        ctx.fillText(label, x + 2, y - 3)

        ctx.textAlign = "right"
        ctx.font = "bold 9px sans-serif"
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.9)
        ctx.fillText(valStr, x + w - 2, y - 3)
    }

    function drawHistoryBars(ctx, history, color, gLeft, gW, h, maxH, maxVal, sf) {
        const n = history.length
        if (n < 1) return
        const step = gW / Math.max(1, maxH - 1)
        const barW = Math.max(2, step * 0.62)
        const tPad = h * 0.06, uH = h * 0.88
        const r = Math.min(barW / 2, 3)
        const c = Qt.color(color)
        ctx.save(); ctx.beginPath(); ctx.rect(gLeft, 0, gW, h); ctx.clip()
        for (let i = 0; i < n; i++) {
            const x = gLeft + gW - (n - 1 - i + sf) * step
            if (x + barW / 2 < gLeft || x - barW / 2 > gLeft + gW) continue
            const v = Math.max(0, Math.min(1, history[i] / maxVal))
            const bh = Math.max(2, v * uH)
            const bx = x - barW / 2
            const by = h - tPad - bh
            const gr = ctx.createLinearGradient(0, by, 0, h - tPad)
            gr.addColorStop(0, Qt.rgba(c.r,c.g,c.b,0.88)); gr.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0.28))
            ctx.fillStyle = gr
            ctx.beginPath()
            if (bh > r*2) { ctx.moveTo(bx+r,by); ctx.arc(bx+r,by+r,r,Math.PI,0); ctx.lineTo(bx+barW,h-tPad); ctx.lineTo(bx,h-tPad); ctx.closePath() }
            else { ctx.arc(bx+r,by+r,r,0,Math.PI*2) }
            ctx.fill()
        }
        ctx.restore()
    }

    property real customValue: 0
    property var customHistory: []
    property bool isReadingCustom: false
    property real lastCustomTimestamp: 0

    P5Support.DataSource {
        id: customSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isReadingCustom = false
            customSource.disconnectSource(sourceName)
            const val = parseFloat((data["stdout"] || "").trim())
            if (!isNaN(val)) {
                root.customValue = val
                const maxH = Math.max(10, plasmoid.configuration.historySize)
                const nh = root.customHistory.slice(); nh.push(val)
                if (nh.length > maxH) nh.splice(0, nh.length - maxH)
                root.customHistory = nh
                root.lastCustomTimestamp = Date.now()
            }
        }
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.customCmdInterval) * 1000
        running: root.showCustomSection; repeat: true
        onTriggered: {
            if (!root.isReadingCustom && plasmoid.configuration.customCmd) {
                root.isReadingCustom = true
                customSource.connectSource(plasmoid.configuration.customCmd)
            }
        }
    }

    P5Support.DataSource {
        id: pingSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            root.isPinging = false
            const m = (data["stdout"] || "").match(/time[<=](\d+(?:[.,]\d+)?)/)
            const ms = m ? parseFloat(m[1].replace(",", ".")) : -1
            root.lastPingTimestamp = Date.now()
            root.addPingResult(root.activeTarget, ms)
            pingSource.disconnectSource(sourceName)
        }
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.pingInterval) * 1000
        running: root.showPingSection
        repeat: true
        onTriggered: root.triggerPing()
    }

    function triggerPing() {
        if (!root.showPingSection || isPinging || targetList.length === 0) return
        const host = targetList[activeTarget]
        if (!host) return
        isPinging = true
        pingSource.connectSource("ping -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host)
    }

    function addPingResult(idx, ms) {
        const maxH = Math.max(10, plasmoid.configuration.historySize)
        if (idx < 0 || idx >= histories.length) return
        const h = histories[idx].slice(); h.push(ms)
        if (h.length > maxH) h.splice(0, h.length - maxH)
        const newH = histories.slice(); newH[idx] = h; histories = newH
        if (idx !== activeTarget) return
        lastPing = ms
        const valid = h.filter(v => v >= 0)
        if (valid.length >= 1) avgPing = valid.reduce((a, b) => a + b, 0) / valid.length
        if (valid.length >= 2) {
            const avg = valid.reduce((a, b) => a + b, 0) / valid.length
            jitter = Math.sqrt(valid.reduce((s, v) => s + (v - avg) * (v - avg), 0) / valid.length)
        } else { jitter = 0 }
        lossPercent = h.length > 0 ? (h.filter(v => v < 0).length / h.length) * 100 : 0
        isAlerting = (ms >= 0 && ms > plasmoid.configuration.latencyThreshold)
            || lossPercent > plasmoid.configuration.lossThreshold
    }

    onActiveTargetChanged: {
        const h = histories[activeTarget] || []
        const valid = h.filter(v => v >= 0)
        lastPing = h.length > 0 ? h[h.length - 1] : -1
        if (valid.length >= 1) avgPing = valid.reduce((a, b) => a + b, 0) / valid.length
        if (valid.length >= 2) {
            const avg = valid.reduce((a, b) => a + b, 0) / valid.length
            jitter = Math.sqrt(valid.reduce((s, v) => s + (v - avg) * (v - avg), 0) / valid.length)
        } else { jitter = 0 }
        lossPercent = h.length > 0 ? (h.filter(v => v < 0).length / h.length) * 100 : 0
        isAlerting = (lastPing >= 0 && lastPing > plasmoid.configuration.latencyThreshold)
            || lossPercent > plasmoid.configuration.lossThreshold
        triggerPing()
    }

    P5Support.DataSource {
        id: netSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isReadingNet = false
            netSource.disconnectSource(sourceName)
            root.parseNetStats(data["stdout"] || "")
        }
    }

    Timer {
        interval: 1000; running: root.showNetworkSpeed; repeat: true
        onTriggered: { if (!root.isReadingNet) { root.isReadingNet = true; netSource.connectSource("cat /proc/net/dev") } }
    }

    function parseNetStats(text) {
        const cfgIface = plasmoid.configuration.networkInterface || "auto"
        let bestIface = ""; let bestRx = -1; const ifaceData = {}
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\w+):\s+(\d+)(?:\s+\d+){7}\s+(\d+)/)
            if (!m || m[1] === "lo") continue
            ifaceData[m[1]] = { rx: parseInt(m[2]), tx: parseInt(m[3]) }
            if (ifaceData[m[1]].rx > bestRx) { bestRx = ifaceData[m[1]].rx; bestIface = m[1] }
        }
        const iface = (cfgIface !== "auto" && ifaceData[cfgIface]) ? cfgIface : bestIface
        if (!iface || !ifaceData[iface]) return
        const now = Date.now()
        const { rx, tx } = ifaceData[iface]
        if (lastNetBytes && lastNetBytes.iface === iface) {
            const dt = (now - lastNetBytes.time) / 1000
            if (dt > 0.1) {
                downloadSpeed = Math.max(0, (rx - lastNetBytes.rx) / dt)
                uploadSpeed   = Math.max(0, (tx - lastNetBytes.tx) / dt)
                lastNetTimestamp = now
                const maxH = Math.max(10, plasmoid.configuration.historySize)
                const nd = dlHistory.slice(); nd.push(downloadSpeed)
                if (nd.length > maxH) nd.splice(0, nd.length - maxH); dlHistory = nd
                const nu = ulHistory.slice(); nu.push(uploadSpeed)
                if (nu.length > maxH) nu.splice(0, nu.length - maxH); ulHistory = nu
            }
        }
        lastNetBytes = { iface, rx, tx, time: now }; activeIface = iface
    }

    P5Support.DataSource {
        id: cpuSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isReadingCpu = false
            cpuSource.disconnectSource(sourceName)
            root.parseCpuStats(data["stdout"] || "")
        }
    }

    Timer {
        interval: 1000; running: root.showCpuSection; repeat: true
        onTriggered: { if (!root.isReadingCpu) { root.isReadingCpu = true; cpuSource.connectSource("cat /proc/stat") } }
    }

    function parseCpuStats(text) {
        const stats = { total: null, cores: [] }
        for (const line of text.split("\n")) {
            const m = line.match(/^(cpu\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (!m) continue
            const user=parseInt(m[2]),nice=parseInt(m[3]),sys=parseInt(m[4]),idle=parseInt(m[5])
            const iow=parseInt(m[6]),irq=parseInt(m[7]),sirq=parseInt(m[8])
            const active = user+nice+sys+irq+sirq, total = active+idle+iow
            if (m[1] === "cpu") stats.total = { active, total }
            else stats.cores.push({ active, total })
        }
        if (!stats.total) return
        const now = Date.now()
        if (lastCpuStats && lastCpuStats.total) {
            const dt = stats.total.total - lastCpuStats.total.total
            const da = stats.total.active - lastCpuStats.total.active
            if (dt > 0) cpuPercent = Math.min(100, Math.max(0, da / dt * 100))

            const newCP = []
            for (let i = 0; i < stats.cores.length; i++) {
                const prev = lastCpuStats.cores[i]
                if (!prev) { newCP.push(0); continue }
                const cdt = stats.cores[i].total - prev.total
                const cda = stats.cores[i].active - prev.active
                newCP.push(cdt > 0 ? Math.min(100, Math.max(0, cda / cdt * 100)) : 0)
            }
            corePercents = newCP

            const maxH = Math.max(10, plasmoid.configuration.historySize)
            const nh = cpuHistory.slice(); nh.push(cpuPercent)
            if (nh.length > maxH) nh.splice(0, nh.length - maxH); cpuHistory = nh

            let ch = coreHistories.length === newCP.length
                ? coreHistories.map(h => h.slice())
                : newCP.map(() => [])
            for (let i = 0; i < newCP.length; i++) {
                ch[i].push(newCP[i])
                if (ch[i].length > maxH) ch[i].splice(0, ch[i].length - maxH)
            }
            coreHistories = ch
            lastCpuTimestamp = now
        }
        lastCpuStats = stats
    }

    P5Support.DataSource {
        id: memSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isReadingMem = false
            memSource.disconnectSource(sourceName)
            root.parseMemStats(data["stdout"] || "")
        }
    }

    Timer {
        interval: 2000; running: root.showMemorySection; repeat: true
        onTriggered: { if (!root.isReadingMem) { root.isReadingMem = true; memSource.connectSource("cat /proc/meminfo") } }
    }

    function parseMemStats(text) {
        const v = {}
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/); if (m) v[m[1]] = parseInt(m[2])
        }
        const total = v["MemTotal"] || 0, avail = v["MemAvailable"] || 0
        const swapTot = v["SwapTotal"] || 0, swapFree = v["SwapFree"] || 0
        if (total > 0) {
            const used = total - avail
            memPercent = used / total * 100; memUsedGiB = used / 1048576; memTotalGiB = total / 1048576
        }
        hasSwap = swapTot > 0
        if (hasSwap) {
            swapPercent = (swapTot - swapFree) / swapTot * 100
            swapUsedGiB = (swapTot - swapFree) / 1048576
        }
        const maxH = Math.max(10, plasmoid.configuration.historySize)
        const nm = memHistory.slice(); nm.push(memPercent)
        if (nm.length > maxH) nm.splice(0, nm.length - maxH); memHistory = nm
        const ns = swapHistory.slice(); ns.push(swapPercent)
        if (ns.length > maxH) ns.splice(0, ns.length - maxH); swapHistory = ns
        lastMemTimestamp = Date.now()
    }

    component LegendItem : Item {
        id: legendItem
        property string text
        property color color
        property bool active: true
        property bool highlighted: false
        signal clicked()
        signal hovered(bool isHovered)

        implicitWidth: legendRow.implicitWidth
        implicitHeight: Math.max(12, legendRow.implicitHeight)

        Row {
            id: legendRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Rectangle {
                width: 8; height: 8; radius: 2
                color: legendItem.active ? legendItem.color : "transparent"
                border.color: legendItem.color; border.width: 1
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: legendItem.text
                color: legendItem.active ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3)
                opacity: legendItem.highlighted ? 1.0 : (legendItem.active ? 0.7 : 0.4)
                font.pixelSize: 9
                font.strikeout: !legendItem.active
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: legendItem.clicked()
            onEntered: legendItem.hovered(true)
            onExited: legendItem.hovered(false)
        }
    }

    fullRepresentation: Item {
        id: container

        Rectangle {
            anchors.fill: parent; radius: plasmoid.configuration.bgRadius
            visible: plasmoid.configuration.showBg
            color: plasmoid.configuration.bgColor
            border.color: Qt.rgba(1,1,1,0.12); border.width: 1
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 1
                height: 1; radius: 0.5; color: Qt.rgba(1,1,1,0.20)
            }
        }

        Rectangle {
            id: alertRing; anchors.fill: parent; radius: plasmoid.configuration.bgRadius
            color: "transparent"; border.color: "#ff4444"; border.width: 2
            visible: root.showPingSection && root.isAlerting
            opacity: 0
            SequentialAnimation {
                running: root.isAlerting && root.showPingSection; loops: Animation.Infinite
                NumberAnimation { target: alertRing; property: "opacity"; from: 0; to: 0.75; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { target: alertRing; property: "opacity"; from: 0.75; to: 0; duration: 650; easing.type: Easing.InOutSine }
                onRunningChanged: {
                    if (!running) {
                        alertRing.opacity = 0
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: plasmoid.configuration.showBg ? 10 : 2
            spacing: 4

            // ════════ CENTERED TITLE ══════════════════════════════════════
            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (root.showPingSection)   return plasmoid.configuration.pingTitle   || "Ping"
                    if (root.showNetworkSpeed)  return plasmoid.configuration.networkTitle || "Network Speed"
                    if (root.showCpuSection)    return plasmoid.configuration.cpuTitle    || "CPU Cores"
                    if (root.showMemorySection) return plasmoid.configuration.memoryTitle  || "Memory"
                    return plasmoid.configuration.customCmdTitle || "Custom Sensor"
                }
                color: root.textColor
                font.pixelSize: 15
                font.bold: true
                font.letterSpacing: 0.3
                renderType: Text.NativeRendering
            }

            // ════════════════ PING SECTION ════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                visible: root.showPingSection
                spacing: 6

                Text {
                    text: plasmoid.configuration.pingTitle || "Ping"
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60)
                    font.pixelSize: 10; font.letterSpacing: 0.5
                    Layout.alignment: Qt.AlignVCenter
                }

                Row {
                    spacing: 4
                    Repeater {
                        model: root.targetList
                        delegate: Rectangle {
                            readonly property bool active: root.activeTarget === index
                            width: Math.min(90, Math.max(36, (container.width - (plasmoid.configuration.showBg ? 20 : 4) - root.targetList.length * 4 - 80) / root.targetList.length))
                            height: 20; radius: height / 2
                            color: active ? Qt.rgba(root.lineColor.r,root.lineColor.g,root.lineColor.b,0.22) : Qt.rgba(1,1,1,0.06)
                            border.color: active ? Qt.rgba(root.lineColor.r,root.lineColor.g,root.lineColor.b,0.60) : Qt.rgba(1,1,1,0.14)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text {
                                anchors.centerIn: parent; width: parent.width - 8
                                text: modelData
                                color: parent.active ? root.lineColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
                                font.pixelSize: 9; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: plasmoid.configuration.currentTargetIndex = index
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.lastPing >= 0 ? root.lastPing.toFixed(0) + " ms" : "— ms"
                    color: root.isAlerting ? "#ff6666" : root.lineColor
                    font.pixelSize: 15; font.bold: true
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
            }

            Canvas {
                id: pingGraph
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showPingSection
                antialiasing: true; renderStrategy: Canvas.Cooperative

                Connections {
                    target: root
                    function onRenderClockChanged()  { if (pingGraph.visible) pingGraph.requestPaint() }
                    function onLineColorChanged()    { if (pingGraph.visible) pingGraph.requestPaint() }
                    function onIsAlertingChanged()   { if (pingGraph.visible) pingGraph.requestPaint() }
                    function onTextColorChanged()    { if (pingGraph.visible) pingGraph.requestPaint() }
                }
                Connections {
                    target: plasmoid.configuration; ignoreUnknownSignals: true
                    function onLineWidthChanged()        { pingGraph.requestPaint() }
                    function onGlowLineChanged()         { pingGraph.requestPaint() }
                    function onLatencyThresholdChanged() { pingGraph.requestPaint() }
                    function onHistorySizeChanged()      { pingGraph.requestPaint() }
                    function onShowYLabelsChanged()      { pingGraph.requestPaint() }
                    function onChartTypeChanged()        { pingGraph.requestPaint() }
                    function onShowGridLinesChanged()     { pingGraph.requestPaint() }
                    function onAutoYRangeChanged()        { pingGraph.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const h = root.histories[root.activeTarget] || []
                    const n = h.length
                    const maxH = Math.max(10, plasmoid.configuration.historySize)
                    const yLW = plasmoid.configuration.showYLabels ? 38 : 0
                    const gW = width - yLW

                    if (n === 0) { root.drawIdleLine(ctx, yLW, gW, height); return }
                    ctx.setLineDash([])

                    const ct = plasmoid.configuration.chartType || 0
                    const valid = h.filter(v => v >= 0)
                    const vMax = valid.length > 0 ? Math.max.apply(null, valid) : 0
                    const maxMs = Math.max(vMax * 1.5 + 2, 15)
                    const threshold = plasmoid.configuration.latencyThreshold

                    if (ct === 3) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0
                        root.drawDonut(ctx, cx, cy, rad, Math.max(6, rad * 0.22), pct,
                            root.isAlerting ? "#ff6666" : root.lineColor,
                            root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency")
                        return
                    }

                    if (ct === 4) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0
                        root.drawPie(ctx, cx, cy, rad, pct,
                            root.isAlerting ? "#ff6666" : root.lineColor,
                            root.lastPing >= 0 ? root.lastPing.toFixed(0) + "ms" : "—", "latency")
                        return
                    }

                    if (ct === 5) {
                        const barH = 14
                        const bx = yLW + 10, bw = gW - 20
                        const by = height / 2 - barH / 2
                        const pct = root.lastPing >= 0 ? Math.min(100, (root.lastPing / maxMs) * 100) : 0
                        root.drawHorizontalBar(ctx, targetList[activeTarget] || "Latency", pct,
                            root.lastPing >= 0 ? root.lastPing.toFixed(0) + " ms" : "— ms",
                            root.isAlerting ? "#ff6666" : root.lineColor, bx, by, bw, barH)
                        return
                    }

                    const pingIntervalMs = Math.max(1, plasmoid.configuration.pingInterval) * 1000
                    const elapsed = root.lastPingTimestamp > 0 ? root.renderClock - root.lastPingTimestamp : pingIntervalMs
                    const sf = Math.max(0, Math.min(1, elapsed / pingIntervalMs))
                    const step = gW / Math.max(1, maxH - 1)
                    const tPad = height * 0.06, uH = height * 0.88

                    function msToY(ms) { return height - tPad - (ms / maxMs) * uH }
                    function iToX(i)   { return yLW + gW - (n - 1 - i + sf) * step }

                    if (plasmoid.configuration.showYLabels) {
                        root.drawYAxis(ctx, yLW, height, [
                            { y: msToY(maxMs),     text: maxMs.toFixed(0) + "ms", grid: false },
                            { y: msToY(maxMs*0.5), text: (maxMs*0.5).toFixed(0) + "ms", grid: true },
                            { y: msToY(0),         text: "0", grid: false }
                        ])
                    }

                    const ty = msToY(threshold)
                    if (ty > 2 && ty < height - 2) {
                        ctx.save(); ctx.lineWidth = 0.8
                        ctx.strokeStyle = Qt.rgba(1,0.45,0.1,0.30); ctx.setLineDash([3,6])
                        ctx.beginPath(); ctx.moveTo(yLW, ty); ctx.lineTo(width, ty); ctx.stroke()
                        ctx.setLineDash([]); ctx.restore()
                    }

                    if (ct === 1) {
                        const barW = Math.max(2, step * 0.62)
                        ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()
                        for (let i = 0; i < n; i++) {
                            const x = iToX(i)
                            if (x + barW / 2 < yLW || x - barW / 2 > width) continue
                            if (h[i] < 0) {
                                // Draw a subtle vertical red column for the lost packet
                                ctx.fillStyle = Qt.rgba(1, 0.15, 0.15, 0.08)
                                ctx.fillRect(x - step/2, tPad, step, height - tPad*2)
                                ctx.beginPath()
                                ctx.arc(x, height - tPad, 1.8, 0, Math.PI*2)
                                ctx.fillStyle = "#ff4444"
                                ctx.fill()
                                continue
                            }
                            const bh = Math.max(2, (h[i] / maxMs) * uH)
                            const bx = x - barW / 2, by = height - tPad - bh
                            const sc = h[i] > threshold*1.5 ? "#ff4444" : h[i] > threshold ? "#ffaa22" : root.lineColor
                            const c = Qt.color(sc), r = Math.min(barW / 2, 3)
                            const gr = ctx.createLinearGradient(0, by, 0, height - tPad)
                            gr.addColorStop(0, Qt.rgba(c.r,c.g,c.b,0.88)); gr.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0.28))
                            ctx.fillStyle = gr
                            ctx.beginPath()
                            if (bh > r*2) { ctx.moveTo(bx+r,by); ctx.arc(bx+r,by+r,r,Math.PI,0); ctx.lineTo(bx+barW,height-tPad); ctx.lineTo(bx,height-tPad); ctx.closePath() }
                            else { ctx.arc(bx+r,by+r,r,0,Math.PI*2) }
                            ctx.fill()
                        }
                        ctx.restore(); return
                    }

                    const segments = []; let seg = []
                    for (let i = 0; i < n; i++) {
                        const x = iToX(i)
                        if (x < yLW - step) continue
                        if (h[i] < 0) {
                            if (seg.length > 0) { segments.push(seg); seg = [] }
                        } else { seg.push({ x, y: msToY(h[i]), ms: h[i] }) }
                    }
                    if (seg.length > 0) segments.push(seg)

                    ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()

                    // Draw packet loss indicators as clean translucent vertical columns & baseline dots
                    for (let i = 0; i < n; i++) {
                        if (h[i] < 0) {
                            const x = iToX(i)
                            if (x >= yLW - step/2 && x <= width + step/2) {
                                ctx.fillStyle = Qt.rgba(1, 0.15, 0.15, 0.08)
                                ctx.fillRect(x - step/2, tPad, step, height - tPad*2)
                                ctx.beginPath()
                                ctx.arc(x, height - tPad, 2, 0, Math.PI*2)
                                ctx.fillStyle = "#ff4444"
                                ctx.fill()
                            }
                        }
                    }

                    for (const pts of segments) {
                        if (pts.length < 2) continue
                        const sMax = Math.max.apply(null, pts.map(p => p.ms))
                        const sc = sMax > threshold * 1.5 ? "#ff4444" : sMax > threshold ? "#ffaa22" : root.lineColor
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? 8 : 0; ctx.shadowColor = sc
                        ctx.beginPath(); ctx.lineWidth = plasmoid.configuration.lineWidth
                        ctx.strokeStyle = sc; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(pts[0].x, pts[0].y)
                        for (let i = 1; i < pts.length; i++) {
                            const cx = (pts[i-1].x + pts[i].x) / 2
                            ctx.bezierCurveTo(cx, pts[i-1].y, cx, pts[i].y, pts[i].x, pts[i].y)
                        }
                        ctx.stroke(); ctx.shadowBlur = 0
                        ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y)
                        for (let i = 1; i < pts.length; i++) {
                            const cx = (pts[i-1].x + pts[i].x) / 2
                            ctx.bezierCurveTo(cx, pts[i-1].y, cx, pts[i].y, pts[i].x, pts[i].y)
                        }
                        ctx.lineTo(pts[pts.length-1].x, height); ctx.lineTo(pts[0].x, height); ctx.closePath()
                        const c = Qt.color(sc)
                        const g = ctx.createLinearGradient(0, pts[0].y, 0, height)
                        g.addColorStop(0, Qt.rgba(c.r,c.g,c.b,ct === 2 ? 0.58 : 0.28)); g.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
                        ctx.fillStyle = g; ctx.fill()
                    }
                    if (segments.length > 0) {
                        const lp = segments[segments.length-1][segments[segments.length-1].length-1]
                        if (lp) {
                            ctx.shadowBlur = plasmoid.configuration.glowLine ? 14 : 0; ctx.shadowColor = root.lineColor
                            ctx.beginPath(); ctx.arc(lp.x, lp.y, 3.2, 0, Math.PI*2)
                            ctx.fillStyle = root.lineColor; ctx.fill(); ctx.shadowBlur = 0
                        }
                    }
                    ctx.restore()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showPingSection && plasmoid.configuration.showStats
                spacing: 10
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                Column {
                    spacing: 1
                    Text { text: "AVG"; color: root.textColor; opacity: 0.38; font.pixelSize: 7; font.letterSpacing: 0.8 }
                    Text { text: root.avgPing > 0 ? root.avgPing.toFixed(1) + " ms" : "— ms"
                           color: root.textColor; opacity: 0.85; font.pixelSize: 10; font.bold: true }
                }
                Column {
                    spacing: 1
                    Text { text: "JITTER"; color: root.textColor; opacity: 0.38; font.pixelSize: 7; font.letterSpacing: 0.8 }
                    Text {
                        readonly property var vh: (root.histories[root.activeTarget] || []).filter(v => v >= 0)
                        text: vh.length >= 2 ? root.jitter.toFixed(1) + " ms" : "— ms"
                        color: root.jitter > 20 ? "#ffaa22" : root.textColor
                        opacity: 0.85; font.pixelSize: 10; font.bold: true
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
                Column {
                    spacing: 1
                    Text { text: "LOSS"; color: root.textColor; opacity: 0.38; font.pixelSize: 7; font.letterSpacing: 0.8 }
                    Text {
                        text: root.lossPercent.toFixed(1) + "%"
                        color: root.lossPercent > plasmoid.configuration.lossThreshold ? "#ff4444" : root.textColor
                        opacity: 0.85; font.pixelSize: 10; font.bold: true
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
                Column {
                    spacing: 1
                    visible: (root.histories[root.activeTarget] || []).filter(v => v >= 0).length > 0
                    Text { text: "MIN / MAX"; color: root.textColor; opacity: 0.38; font.pixelSize: 7; font.letterSpacing: 0.8 }
                    Text {
                        readonly property var vh: (root.histories[root.activeTarget] || []).filter(v => v >= 0)
                        text: vh.length > 0 ? Math.min.apply(null,vh).toFixed(0) + " / " + Math.max.apply(null,vh).toFixed(0) + " ms" : "—"
                        color: root.textColor; opacity: 0.80; font.pixelSize: 10; font.bold: true
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.targetList[root.activeTarget] || ""
                    color: root.textColor; opacity: 0.28; font.pixelSize: 8
                    elide: Text.ElideLeft; Layout.maximumWidth: 70
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showPingSection && plasmoid.configuration.showLegend
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                LegendItem { text: "Latency"; color: root.lineColor }
                Item { Layout.fillWidth: true }
            }

            // ════════════════ NETWORK SECTION ═════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showNetworkSpeed && root.showPingSection
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showNetworkSpeed
                spacing: 6
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                Text { 
                    text: (plasmoid.configuration.networkTitle || "Network") + (root.activeIface ? " (" + root.activeIface + ")" : "")
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60); font.pixelSize: 10; font.letterSpacing: 0.5 
                }
                Item { Layout.fillWidth: true }
                Rectangle { width: 8; height: 8; radius: 2; color: root.dlColor; opacity: 0.90 }
                Text { text: "↓ " + root.formatSpeed(root.downloadSpeed); color: root.dlColor; font.pixelSize: 13; font.bold: true }
                Item { width: 6 }
                Rectangle { width: 8; height: 8; radius: 2; color: root.ulColor; opacity: 0.90 }
                Text { text: "↑ " + root.formatSpeed(root.uploadSpeed); color: root.ulColor; font.pixelSize: 13; font.bold: true }
            }

            Canvas {
                id: netGraph
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showNetworkSpeed && plasmoid.configuration.chartType !== 6
                antialiasing: true; renderStrategy: Canvas.Cooperative

                Connections {
                    target: root
                    function onRenderClockChanged()  { if (netGraph.visible) netGraph.requestPaint() }
                    function onDlHistoryChanged()    { if (netGraph.visible) netGraph.requestPaint() }
                    function onUlHistoryChanged()    { if (netGraph.visible) netGraph.requestPaint() }
                    function onTextColorChanged()    { if (netGraph.visible) netGraph.requestPaint() }
                }
                Connections {
                    target: plasmoid.configuration; ignoreUnknownSignals: true
                    function onGlowLineChanged()    { netGraph.requestPaint() }
                    function onLineWidthChanged()   { netGraph.requestPaint() }
                    function onShowYLabelsChanged() { netGraph.requestPaint() }
                    function onDlColorChanged()     { netGraph.requestPaint() }
                    function onUlColorChanged()     { netGraph.requestPaint() }
                    function onChartTypeChanged()   { netGraph.requestPaint() }
                    function onShowGridLinesChanged() { netGraph.requestPaint() }
                    function onAutoYRangeChanged()    { netGraph.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const dl = root.dlHistory, ul = root.ulHistory
                    const maxH = Math.max(10, plasmoid.configuration.historySize)
                    const yLW = plasmoid.configuration.showYLabels ? 38 : 0
                    const gW = width - yLW
                    if (dl.length < 1 && ul.length < 1) { root.drawIdleLine(ctx, yLW, gW, height); return }
                    ctx.setLineDash([])
                    const ct = plasmoid.configuration.chartType || 0
                    const allVals = dl.concat(ul)
                    const dataMax = allVals.length > 0 ? Math.max.apply(null, allVals) : 0
                    const maxBps = plasmoid.configuration.autoYRange
                        ? Math.max(1024, dataMax * 1.10)
                        : Math.max(1024, dataMax * 1.20)
                    const tPad = height * 0.06, uH = height * 0.88
                    const elapsed = root.lastNetTimestamp > 0 ? root.renderClock - root.lastNetTimestamp : 1000
                    const sf = Math.max(0, Math.min(1, elapsed / 1000))
                    const step = gW / Math.max(1, maxH - 1)
                    function bToY(b) { return height - tPad - (b / maxBps) * uH }
                    function iToX(i, len) { return yLW + gW - (len - 1 - i + sf) * step }

                    if (ct === 3) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.33
                        const lw = Math.max(6, rad * 0.22)
                        const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100)
                        const ulPct = Math.min(100, (root.uploadSpeed / maxBps) * 100)
                        if (!root.isLineDisabled("dl"))
                            root.drawDonut(ctx, cx, cy, rad, lw, dlPct, root.dlColor,
                                "↓ " + root.formatSpeed(root.downloadSpeed), "↑ " + root.formatSpeed(root.uploadSpeed))
                        if (!root.isLineDisabled("ul"))
                            root.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, ulPct, root.ulColor, null, null)
                        return
                    }

                    if (ct === 4) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.33
                        const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100)
                        const ulPct = Math.min(100, (root.uploadSpeed / maxBps) * 100)
                        if (!root.isLineDisabled("dl"))
                            root.drawPie(ctx, cx, cy, rad, dlPct, root.dlColor,
                                "↓ " + root.formatSpeed(root.downloadSpeed), "↑ " + root.formatSpeed(root.uploadSpeed))
                        if (!root.isLineDisabled("ul"))
                            root.drawPie(ctx, cx, cy, rad * 0.58, ulPct, root.ulColor, null, null)
                        return
                    }

                    if (ct === 5) {
                        const barH = 10, gap = 8
                        const bx = yLW + 10, bw = gW - 20
                        const cy = height / 2
                        let activeCount = 0
                        if (!root.isLineDisabled("dl")) activeCount++
                        if (!root.isLineDisabled("ul")) activeCount++

                        let y = cy - (activeCount * barH + (activeCount - 1) * gap) / 2
                        if (!root.isLineDisabled("dl")) {
                            const pct = (root.downloadSpeed / maxBps) * 100
                            root.drawHorizontalBar(ctx, "Download", pct, root.formatSpeed(root.downloadSpeed), root.dlColor, bx, y, bw, barH)
                            y += barH + gap
                        }
                        if (!root.isLineDisabled("ul")) {
                            const pct = (root.uploadSpeed / maxBps) * 100
                            root.drawHorizontalBar(ctx, "Upload", pct, root.formatSpeed(root.uploadSpeed), root.ulColor, bx, y, bw, barH)
                        }
                        return
                    }

                    if (ct === 1) {
                        if (!root.isLineDisabled("dl")) root.drawHistoryBars(ctx, dl, root.dlColor, yLW, gW, height, maxH, maxBps, sf)
                        if (!root.isLineDisabled("ul")) {
                            ctx.globalAlpha = 0.65
                            root.drawHistoryBars(ctx, ul, root.ulColor, yLW, gW, height, maxH, maxBps, sf)
                            ctx.globalAlpha = 1.0
                        }
                        return
                    }

                    if (plasmoid.configuration.showYLabels) {
                        root.drawYAxis(ctx, yLW, height, [
                            { y: bToY(maxBps),     text: root.formatSpeed(maxBps),     grid: false },
                            { y: bToY(maxBps*0.5), text: root.formatSpeed(maxBps*0.5), grid: true  },
                            { y: bToY(0),          text: "0",                           grid: false }
                        ])
                    }

                    const fillA = ct === 2 ? 0.52 : 0.18
                    function drawLine(history, color, key) {
                        if (history.length < 2 || root.isLineDisabled(key)) return
                        const len = history.length
                        const isHovered = (root.hoveredLine === key)
                        const dimOthers = (root.hoveredLine === "dl" || root.hoveredLine === "ul") && !isHovered

                        ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()
                        ctx.globalAlpha = dimOthers ? 0.15 : 1.0
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? (isHovered ? 12 : 6) : 0
                        ctx.shadowColor = color
                        ctx.beginPath(); ctx.lineWidth = plasmoid.configuration.lineWidth
                        ctx.strokeStyle = color; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(iToX(0,len), bToY(history[0]))
                        for (let i = 1; i < len; i++) {
                            const cx = (iToX(i-1,len) + iToX(i,len)) / 2
                            ctx.bezierCurveTo(cx, bToY(history[i-1]), cx, bToY(history[i]), iToX(i,len), bToY(history[i]))
                        }
                        ctx.stroke(); ctx.shadowBlur = 0
                        ctx.beginPath(); ctx.moveTo(iToX(0,len), bToY(history[0]))
                        for (let i = 1; i < len; i++) {
                            const cx = (iToX(i-1,len) + iToX(i,len)) / 2
                            ctx.bezierCurveTo(cx, bToY(history[i-1]), cx, bToY(history[i]), iToX(i,len), bToY(history[i]))
                        }
                        ctx.lineTo(iToX(len-1,len), height); ctx.lineTo(iToX(0,len), height); ctx.closePath()
                        const c = Qt.color(color)
                        const g = ctx.createLinearGradient(0, 0, 0, height)
                        g.addColorStop(0, Qt.rgba(c.r,c.g,c.b,fillA)); g.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
                        ctx.fillStyle = g; ctx.fill(); ctx.restore()
                    }
                    drawLine(ul, root.ulColor, "ul")
                    drawLine(dl, root.dlColor, "dl")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showNetworkSpeed && plasmoid.configuration.showLegend
                spacing: 12
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                LegendItem { 
                    text: "Download"; color: root.dlColor
                    active: !root.isLineDisabled("dl")
                    highlighted: root.hoveredLine === "dl"
                    onClicked: { root.toggleLineDisabled("dl"); netGraph.requestPaint() }
                    onHovered: function(h) { root.hoveredLine = h ? "dl" : ""; netGraph.requestPaint() }
                }
                LegendItem { 
                    text: "Upload"; color: root.ulColor
                    active: !root.isLineDisabled("ul")
                    highlighted: root.hoveredLine === "ul"
                    onClicked: { root.toggleLineDisabled("ul"); netGraph.requestPaint() }
                    onHovered: function(h) { root.hoveredLine = h ? "ul" : ""; netGraph.requestPaint() }
                }
                Item { Layout.fillWidth: true }
            }

            // ════════════════ CPU SECTION ══════════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showCpuSection && (root.showPingSection || root.showNetworkSpeed)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showCpuSection
                spacing: 6
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                Text { text: plasmoid.configuration.cpuTitle || "CPU"; color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60); font.pixelSize: 10; font.letterSpacing: 0.5 }
                Item { Layout.fillWidth: true }
                Text { text: root.cpuPercent.toFixed(1) + "%"; color: root.cpuColor; font.pixelSize: 13; font.bold: true }
            }

            Canvas {
                id: cpuGraph
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showCpuSection && plasmoid.configuration.chartType !== 6
                antialiasing: true; renderStrategy: Canvas.Cooperative

                Connections {
                    target: root
                    function onRenderClockChanged()   { if (cpuGraph.visible) cpuGraph.requestPaint() }
                    function onCpuHistoryChanged()    { if (cpuGraph.visible) cpuGraph.requestPaint() }
                    function onCoreHistoriesChanged() { if (cpuGraph.visible) cpuGraph.requestPaint() }
                    function onTextColorChanged()     { if (cpuGraph.visible) cpuGraph.requestPaint() }
                }
                Connections {
                    target: plasmoid.configuration; ignoreUnknownSignals: true
                    function onGlowLineChanged()      { cpuGraph.requestPaint() }
                    function onLineWidthChanged()     { cpuGraph.requestPaint() }
                    function onShowCpuCoresChanged()  { cpuGraph.requestPaint() }
                    function onShowYLabelsChanged()   { cpuGraph.requestPaint() }
                    function onCpuColorChanged()      { cpuGraph.requestPaint() }
                    function onCoreColorsStrChanged() { cpuGraph.requestPaint() }
                    function onChartTypeChanged()     { cpuGraph.requestPaint() }
                    function onShowGridLinesChanged() { cpuGraph.requestPaint() }
                    function onAutoYRangeChanged()    { cpuGraph.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const h = root.cpuHistory, n = h.length
                    const maxH = Math.max(10, plasmoid.configuration.historySize)
                    const yLW = plasmoid.configuration.showYLabels ? 38 : 0
                    const gW = width - yLW
                    if (n < 1) { root.drawIdleLine(ctx, yLW, gW, height); return }
                    ctx.setLineDash([])
                    const ct = plasmoid.configuration.chartType || 0
                    const tPad = height * 0.06, uH = height * 0.88
                    const elapsed = root.lastCpuTimestamp > 0 ? root.renderClock - root.lastCpuTimestamp : 1000
                    const sf = Math.max(0, Math.min(1, elapsed / 1000))
                    const step = gW / Math.max(1, maxH - 1)
                    function pToY(p) { return height - tPad - (p / 100) * uH }
                    function iToX(i, len) { return yLW + gW - (len - 1 - i + sf) * step }

                    if (ct === 3) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const lw = Math.max(6, rad * 0.22)
                        if (!root.isLineDisabled("cpuTotal"))
                            root.drawDonut(ctx, cx, cy, rad, lw, root.cpuPercent, root.cpuColor,
                                root.cpuPercent.toFixed(1) + "%", "cpu")
                        if (plasmoid.configuration.showCpuCores) {
                            const nc = root.corePercents.length
                            for (let ci = 0; ci < Math.min(nc, 8); ci++) {
                                if (root.isCoreDisabled(ci)) continue
                                const cr = rad * (1.0 - (ci + 1) * 0.10)
                                if (cr < rad * 0.25) break
                                root.drawDonut(ctx, cx, cy, cr, Math.max(2, lw * 0.30),
                                    root.corePercents[ci] || 0,
                                    root.coreColors[ci % root.coreColors.length] || "#888888",
                                    null, null)
                            }
                        }
                        return
                    }

                    if (ct === 4) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        if (!root.isLineDisabled("cpuTotal"))
                            root.drawPie(ctx, cx, cy, rad, root.cpuPercent, root.cpuColor,
                                root.cpuPercent.toFixed(1) + "%", "cpu")
                        if (plasmoid.configuration.showCpuCores) {
                            const nc = root.corePercents.length
                            for (let ci = 0; ci < Math.min(nc, 8); ci++) {
                                if (root.isCoreDisabled(ci)) continue
                                const cr = rad * (1.0 - (ci + 1) * 0.10)
                                if (cr < rad * 0.25) break
                                root.drawPie(ctx, cx, cy, cr,
                                    root.corePercents[ci] || 0,
                                    root.coreColors[ci % root.coreColors.length] || "#888888",
                                    null, null)
                            }
                        }
                        return
                    }

                    if (ct === 5) {
                        const bx = yLW + 10, bw = gW - 20
                        if (plasmoid.configuration.showCpuCores) {
                            const nc = root.corePercents.length
                            const cols = nc > 8 ? 4 : (nc > 4 ? 2 : 1)
                            const rows = Math.ceil(nc / cols)
                            const barH = Math.max(6, Math.min(10, (height - 10 - (rows - 1) * 6) / rows))
                            const colW = (bw - (cols - 1) * 8) / cols
                            const gapY = 6

                            for (let ci = 0; ci < nc; ci++) {
                                if (root.isCoreDisabled(ci)) continue
                                const col = ci % cols
                                const row = Math.floor(ci / cols)
                                const x = bx + col * (colW + 8)
                                const y = 5 + row * (barH + gapY)
                                const pct = root.corePercents[ci] || 0
                                root.drawHorizontalBar(ctx, "C" + (ci + 1), pct, pct.toFixed(0) + "%",
                                    root.coreColors[ci % root.coreColors.length] || "#888888",
                                    x, y + 8, colW, barH)
                            }
                        } else if (!root.isLineDisabled("cpuTotal")) {
                            root.drawHorizontalBar(ctx, "CPU Total", root.cpuPercent, root.cpuPercent.toFixed(1) + "%", root.cpuColor, bx, height / 2 - 7, bw, 14)
                        }
                        return
                    }

                    if (ct === 1) {
                        if (plasmoid.configuration.showCpuCores) {
                            const nc = root.coreHistories.length
                            for (let ci = 0; ci < nc; ci++) {
                                if (root.isCoreDisabled(ci) || root.coreHistories[ci].length < 1) continue
                                ctx.globalAlpha = root.hoveredCore === ci ? 1.0 : (root.hoveredCore !== -1 ? 0.18 : 0.55)
                                root.drawHistoryBars(ctx, root.coreHistories[ci],
                                    root.coreColors[ci % root.coreColors.length] || "#888888",
                                    yLW, gW, height, maxH, 100, sf)
                            }
                            ctx.globalAlpha = 1.0
                        } else if (!root.isLineDisabled("cpuTotal")) {
                            root.drawHistoryBars(ctx, h, root.cpuColor, yLW, gW, height, maxH, 100, sf)
                        }
                        return
                    }

                    if (plasmoid.configuration.showYLabels) {
                        root.drawYAxis(ctx, yLW, height, [
                            { y: pToY(100), text: "100%", grid: false },
                            { y: pToY(75),  text: "75%",  grid: true  },
                            { y: pToY(50),  text: "50%",  grid: true  },
                            { y: pToY(25),  text: "25%",  grid: true  },
                            { y: pToY(0),   text: "0%",   grid: false }
                        ])
                    }

                    ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()

                    if (plasmoid.configuration.showCpuCores) {
                        for (let ci = 0; ci < root.coreHistories.length; ci++) {
                            if (root.isCoreDisabled(ci)) continue;
                            const ch = root.coreHistories[ci]
                            if (ch.length < 2) continue
                            
                            const isHovered = (root.hoveredCore === ci)
                            const isAnyCoreHovered = (root.hoveredCore !== -1)
                            const isTotalHovered = (root.hoveredLine === "cpuTotal")
                            
                            ctx.beginPath()
                            ctx.lineWidth = isHovered ? plasmoid.configuration.lineWidth : Math.max(0.6, plasmoid.configuration.lineWidth * 0.45)
                            ctx.strokeStyle = root.coreColors[ci % root.coreColors.length] || "#888888"
                            ctx.globalAlpha = isHovered ? 1.0 : ((isAnyCoreHovered || isTotalHovered) ? 0.10 : 0.50)
                            ctx.lineCap = "round"; ctx.lineJoin = "round"
                            ctx.moveTo(iToX(0, ch.length), pToY(ch[0]))
                            for (let i = 1; i < ch.length; i++) {
                                const cx = (iToX(i-1,ch.length) + iToX(i,ch.length)) / 2
                                ctx.bezierCurveTo(cx, pToY(ch[i-1]), cx, pToY(ch[i]), iToX(i,ch.length), pToY(ch[i]))
                            }
                            ctx.stroke(); ctx.globalAlpha = 1.0
                        }
                    }

                    if (n >= 2 && !root.isLineDisabled("cpuTotal")) {
                        const isHovered = (root.hoveredLine === "cpuTotal")
                        const isAnyCoreHovered = (root.hoveredCore !== -1)
                        
                        ctx.globalAlpha = (!isHovered && isAnyCoreHovered) ? 0.15 : 1.0
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? (isHovered ? 12 : 8) : 0
                        ctx.shadowColor = root.cpuColor
                        ctx.beginPath(); ctx.lineWidth = plasmoid.configuration.lineWidth
                        ctx.strokeStyle = root.cpuColor; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(iToX(0,n), pToY(h[0]))
                        for (let i = 1; i < n; i++) {
                            const cx = (iToX(i-1,n) + iToX(i,n)) / 2
                            ctx.bezierCurveTo(cx, pToY(h[i-1]), cx, pToY(h[i]), iToX(i,n), pToY(h[i]))
                        }
                        ctx.stroke(); ctx.shadowBlur = 0
                        ctx.beginPath(); ctx.moveTo(iToX(0,n), pToY(h[0]))
                        for (let i = 1; i < n; i++) {
                            const cx = (iToX(i-1,n) + iToX(i,n)) / 2
                            ctx.bezierCurveTo(cx, pToY(h[i-1]), cx, pToY(h[i]), iToX(i,n), pToY(h[i]))
                        }
                        ctx.lineTo(iToX(n-1,n), height); ctx.lineTo(iToX(0,n), height); ctx.closePath()
                        const c = Qt.color(root.cpuColor)
                        const g = ctx.createLinearGradient(0, pToY(100), 0, height)
                        g.addColorStop(0, Qt.rgba(c.r,c.g,c.b,ct === 2 ? 0.55 : 0.25)); g.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
                        ctx.fillStyle = g; ctx.fill()
                    }
                    ctx.restore()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showCpuSection && plasmoid.configuration.showLegend
                spacing: 8
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                LegendItem {
                    text: "Total"; color: root.cpuColor
                    active: !root.isLineDisabled("cpuTotal")
                    highlighted: root.hoveredLine === "cpuTotal"
                    onClicked: { root.toggleLineDisabled("cpuTotal"); cpuGraph.requestPaint() }
                    onHovered: function(h) { root.hoveredLine = h ? "cpuTotal" : ""; cpuGraph.requestPaint() }
                }
                Item { Layout.fillWidth: true }
            }

            // ── Per-core stats grid ────────────────────────────────────────
            GridLayout {
                id: coreStatsGrid
                Layout.fillWidth: true
                visible: root.showCpuSection && plasmoid.configuration.showCpuCores && root.corePercents.length > 0
                columns: 2
                columnSpacing: 0
                rowSpacing: 0

                Repeater {
                    model: root.corePercents.length
                    delegate: Item {
                        id: coreStatItem
                        Layout.fillWidth: true
                        implicitHeight: 17

                        readonly property bool coreActive: !root.isCoreDisabled(index)
                        readonly property color coreColor: root.coreColors[index % root.coreColors.length] || "#888888"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: root.hoveredCore = index
                            onExited: if (root.hoveredCore === index) root.hoveredCore = -1
                            onClicked: { root.toggleCoreDisabled(index); cpuGraph.requestPaint() }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: plasmoid.configuration.showYLabels ? 40 : 6
                            anchors.rightMargin: 4
                            spacing: 4

                            Rectangle {
                                width: 7; height: 7; radius: 2
                                color: coreStatItem.coreActive ? coreStatItem.coreColor : "transparent"
                                border.color: coreStatItem.coreColor; border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Core " + (index + 1) + " Total Usage"
                                color: root.textColor
                                opacity: coreStatItem.coreActive ? 0.65 : 0.35
                                font.pixelSize: 9
                                font.strikeout: !coreStatItem.coreActive
                                elide: Text.ElideRight
                            }

                            Text {
                                text: (root.corePercents[index] || 0).toFixed(1) + "%"
                                color: coreStatItem.coreActive
                                    ? coreStatItem.coreColor
                                    : Qt.rgba(coreStatItem.coreColor.r, coreStatItem.coreColor.g, coreStatItem.coreColor.b, 0.4)
                                font.pixelSize: 9
                                font.bold: true
                                Layout.minimumWidth: 38
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

            // ════════════════ MEMORY SECTION ══════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showMemorySection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showMemorySection
                spacing: 6
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                Text { text: plasmoid.configuration.memoryTitle || "Memory"; color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60); font.pixelSize: 10; font.letterSpacing: 0.5 }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.memUsedGiB.toFixed(1) + " / " + root.memTotalGiB.toFixed(1) + " GiB"
                    color: root.memColor; font.pixelSize: 13; font.bold: true
                }
                Item { width: 6; visible: root.hasSwap }
                Rectangle { width: 8; height: 8; radius: 2; color: root.swapColor; opacity: 0.85; visible: root.hasSwap }
                Text {
                    visible: root.hasSwap
                    text: "SWAP " + root.swapPercent.toFixed(0) + "%"
                    color: root.swapColor; font.pixelSize: 13; font.bold: true
                }
            }

            Canvas {
                id: memGraph
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showMemorySection && plasmoid.configuration.chartType !== 6
                antialiasing: true; renderStrategy: Canvas.Cooperative

                Connections {
                    target: root
                    function onRenderClockChanged()  { if (memGraph.visible) memGraph.requestPaint() }
                    function onMemHistoryChanged()   { if (memGraph.visible) memGraph.requestPaint() }
                    function onSwapHistoryChanged()  { if (memGraph.visible) memGraph.requestPaint() }
                    function onTextColorChanged()    { if (memGraph.visible) memGraph.requestPaint() }
                }
                Connections {
                    target: plasmoid.configuration; ignoreUnknownSignals: true
                    function onGlowLineChanged()    { memGraph.requestPaint() }
                    function onLineWidthChanged()   { memGraph.requestPaint() }
                    function onShowYLabelsChanged() { memGraph.requestPaint() }
                    function onMemColorChanged()    { memGraph.requestPaint() }
                    function onSwapColorChanged()   { memGraph.requestPaint() }
                    function onChartTypeChanged()   { memGraph.requestPaint() }
                    function onShowGridLinesChanged() { memGraph.requestPaint() }
                    function onAutoYRangeChanged()    { memGraph.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const h = root.memHistory, n = h.length
                    const maxH = Math.max(10, plasmoid.configuration.historySize)
                    const yLW = plasmoid.configuration.showYLabels ? 38 : 0
                    const gW = width - yLW
                    if (n < 1) { root.drawIdleLine(ctx, yLW, gW, height); return }
                    ctx.setLineDash([])
                    const ct = plasmoid.configuration.chartType || 0
                    const tPad = height * 0.06, uH = height * 0.88
                    const elapsed = root.lastMemTimestamp > 0 ? root.renderClock - root.lastMemTimestamp : 2000
                    const sf = Math.max(0, Math.min(1, elapsed / 2000))
                    const step = gW / Math.max(1, maxH - 1)
                    function pToY(p) { return height - tPad - (p / 100) * uH }
                    function iToX(i, len) { return yLW + gW - (len - 1 - i + sf) * step }

                    if (ct === 3) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const lw = Math.max(6, rad * 0.22)
                        if (!root.isLineDisabled("ram"))
                            root.drawDonut(ctx, cx, cy, rad, lw, root.memPercent, root.memColor,
                                root.memUsedGiB.toFixed(1) + " GiB",
                                root.memTotalGiB.toFixed(1) + " GiB total")
                        if (root.hasSwap && !root.isLineDisabled("swap"))
                            root.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, root.swapPercent, root.swapColor, null, null)
                        return
                    }

                    if (ct === 4) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        if (!root.isLineDisabled("ram"))
                            root.drawPie(ctx, cx, cy, rad, root.memPercent, root.memColor,
                                root.memUsedGiB.toFixed(1) + " GiB",
                                root.memTotalGiB.toFixed(1) + " GiB total")
                        if (root.hasSwap && !root.isLineDisabled("swap"))
                            root.drawPie(ctx, cx, cy, rad * 0.58, root.swapPercent, root.swapColor, null, null)
                        return
                    }

                    if (ct === 5) {
                        const barH = 10, gap = 8
                        const bx = yLW + 10, bw = gW - 20
                        let cy = height / 2
                        let activeCount = 0
                        if (!root.isLineDisabled("ram")) activeCount++
                        if (root.hasSwap && !root.isLineDisabled("swap")) activeCount++

                        let y = cy - (activeCount * barH + (activeCount - 1) * gap) / 2
                        if (!root.isLineDisabled("ram")) {
                            root.drawHorizontalBar(ctx, "RAM", root.memPercent, root.memUsedGiB.toFixed(1) + " / " + root.memTotalGiB.toFixed(1) + " GiB", root.memColor, bx, y, bw, barH)
                            y += barH + gap
                        }
                        if (root.hasSwap && !root.isLineDisabled("swap")) {
                            root.drawHorizontalBar(ctx, "Swap", root.swapPercent, root.swapUsedGiB.toFixed(1) + " GiB", root.swapColor, bx, y, bw, barH)
                        }
                        return
                    }

                    if (ct === 1) {
                        const sw2 = root.swapHistory
                        if (root.hasSwap && sw2.length > 0 && !root.isLineDisabled("swap")) {
                            ctx.globalAlpha = 0.55
                            root.drawHistoryBars(ctx, sw2, root.swapColor, yLW, gW, height, maxH, 100, sf)
                            ctx.globalAlpha = 1.0
                        }
                        if (!root.isLineDisabled("ram"))
                            root.drawHistoryBars(ctx, h, root.memColor, yLW, gW, height, maxH, 100, sf)
                        return
                    }

                    if (plasmoid.configuration.showYLabels) {
                        root.drawYAxis(ctx, yLW, height, [
                            { y: pToY(100), text: "100%", grid: false },
                            { y: pToY(50),  text: "50%",  grid: true  },
                            { y: pToY(0),   text: "0%",   grid: false }
                        ])
                    }

                    ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()

                    const sw = root.swapHistory, swLen = sw.length
                    if (root.hasSwap && swLen >= 2 && !root.isLineDisabled("swap")) {
                        const isHovered = (root.hoveredLine === "swap")
                        const dimOthers = (root.hoveredLine === "ram" || root.hoveredLine === "swap") && !isHovered
                        ctx.beginPath()
                        ctx.lineWidth = Math.max(0.8, plasmoid.configuration.lineWidth * 0.65)
                        ctx.strokeStyle = root.swapColor
                        ctx.globalAlpha = dimOthers ? 0.15 : (isHovered ? 0.9 : 0.55)
                        ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(iToX(0,swLen), pToY(sw[0]))
                        for (let i = 1; i < swLen; i++) {
                            const cx = (iToX(i-1,swLen) + iToX(i,swLen)) / 2
                            ctx.bezierCurveTo(cx, pToY(sw[i-1]), cx, pToY(sw[i]), iToX(i,swLen), pToY(sw[i]))
                        }
                        ctx.stroke(); ctx.globalAlpha = 1.0
                    }

                    if (n >= 2 && !root.isLineDisabled("ram")) {
                        const isHovered = (root.hoveredLine === "ram")
                        const dimOthers = (root.hoveredLine === "ram" || root.hoveredLine === "swap") && !isHovered
                        ctx.globalAlpha = dimOthers ? 0.15 : 1.0
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? (isHovered ? 12 : 8) : 0
                        ctx.shadowColor = root.memColor
                        ctx.beginPath(); ctx.lineWidth = plasmoid.configuration.lineWidth
                        ctx.strokeStyle = root.memColor; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(iToX(0,n), pToY(h[0]))
                        for (let i = 1; i < n; i++) {
                            const cx = (iToX(i-1,n) + iToX(i,n)) / 2
                            ctx.bezierCurveTo(cx, pToY(h[i-1]), cx, pToY(h[i]), iToX(i,n), pToY(h[i]))
                        }
                        ctx.stroke(); ctx.shadowBlur = 0
                        ctx.beginPath(); ctx.moveTo(iToX(0,n), pToY(h[0]))
                        for (let i = 1; i < n; i++) {
                            const cx = (iToX(i-1,n) + iToX(i,n)) / 2
                            ctx.bezierCurveTo(cx, pToY(h[i-1]), cx, pToY(h[i]), iToX(i,n), pToY(h[i]))
                        }
                        ctx.lineTo(iToX(n-1,n), height); ctx.lineTo(iToX(0,n), height); ctx.closePath()
                        const c = Qt.color(root.memColor)
                        const g = ctx.createLinearGradient(0, pToY(100), 0, height)
                        g.addColorStop(0, Qt.rgba(c.r,c.g,c.b,ct === 2 ? 0.55 : 0.25)); g.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
                        ctx.fillStyle = g; ctx.fill()
                    }
                    ctx.restore()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showMemorySection && plasmoid.configuration.showLegend
                spacing: 12
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                LegendItem { 
                    text: "RAM"; color: root.memColor 
                    active: !root.isLineDisabled("ram")
                    highlighted: root.hoveredLine === "ram"
                    onClicked: { root.toggleLineDisabled("ram"); memGraph.requestPaint() }
                    onHovered: function(h) { root.hoveredLine = h ? "ram" : ""; memGraph.requestPaint() }
                }
                LegendItem { 
                    text: "Swap"; color: root.swapColor; visible: root.hasSwap 
                    active: !root.isLineDisabled("swap")
                    highlighted: root.hoveredLine === "swap"
                    onClicked: { root.toggleLineDisabled("swap"); memGraph.requestPaint() }
                    onHovered: function(h) { root.hoveredLine = h ? "swap" : ""; memGraph.requestPaint() }
                }
                Item { Layout.fillWidth: true }
            }

            // ════════════════ CUSTOM SECTION ══════════════════════════════
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showCustomSection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection || root.showMemorySection)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showCustomSection
                spacing: 6
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                Text {
                    text: plasmoid.configuration.customCmdTitle || "Custom Sensor"
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60); font.pixelSize: 10; font.letterSpacing: 0.5
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.customValue.toFixed(2) + " " + (plasmoid.configuration.customCmdUnit || "")
                    color: plasmoid.configuration.customCmdColor || "#ffaa00"
                    font.pixelSize: 15; font.bold: true; opacity: 0.95
                }
            }

            Canvas {
                id: customGraph
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: root.showCustomSection && plasmoid.configuration.chartType !== 6
                antialiasing: true; renderStrategy: Canvas.Cooperative

                Connections {
                    target: root
                    function onRenderClockChanged()  { if (customGraph.visible) customGraph.requestPaint() }
                    function onCustomHistoryChanged() { if (customGraph.visible) customGraph.requestPaint() }
                    function onTextColorChanged()    { if (customGraph.visible) customGraph.requestPaint() }
                }
                Connections {
                    target: plasmoid.configuration; ignoreUnknownSignals: true
                    function onGlowLineChanged()      { customGraph.requestPaint() }
                    function onLineWidthChanged()     { customGraph.requestPaint() }
                    function onShowYLabelsChanged()   { customGraph.requestPaint() }
                    function onCustomCmdColorChanged() { customGraph.requestPaint() }
                    function onChartTypeChanged()     { customGraph.requestPaint() }
                    function onShowGridLinesChanged() { customGraph.requestPaint() }
                    function onAutoYRangeChanged()    { customGraph.requestPaint() }
                }

                onPaint: {
                    const ctx = getContext("2d"); ctx.reset()
                    const h = root.customHistory, n = h.length
                    const maxH = Math.max(10, plasmoid.configuration.historySize)
                    const yLW = plasmoid.configuration.showYLabels ? 38 : 0
                    const gW = width - yLW
                    if (n < 1) { root.drawIdleLine(ctx, yLW, gW, height); return }
                    ctx.setLineDash([])
                    const ct = plasmoid.configuration.chartType || 0
                    const maxVal = Math.max(0.1, plasmoid.configuration.customCmdMax)
                    const tPad = height * 0.06, uH = height * 0.88
                    const elapsed = root.lastCustomTimestamp > 0 ? root.renderClock - root.lastCustomTimestamp : 1000
                    const sf = Math.max(0, Math.min(1, elapsed / 1000))
                    const step = gW / Math.max(1, maxH - 1)
                    function valToY(v) { return height - tPad - (Math.min(maxVal, Math.max(0, v)) / maxVal) * uH }
                    function iToX(i, len) { return yLW + gW - (len - 1 - i + sf) * step }

                    const color = plasmoid.configuration.customCmdColor || "#ffaa00"

                    if (ct === 3) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const lw = Math.max(6, rad * 0.22)
                        const pct = Math.min(100, (root.customValue / maxVal) * 100)
                        root.drawDonut(ctx, cx, cy, rad, lw, pct, color,
                            root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""),
                            plasmoid.configuration.customCmdTitle || "value")
                        return
                    }

                    if (ct === 4) {
                        const cx = yLW + gW / 2, cy = height / 2
                        const rad = Math.min(gW, height) * 0.36
                        const pct = Math.min(100, (root.customValue / maxVal) * 100)
                        root.drawPie(ctx, cx, cy, rad, pct, color,
                            root.customValue.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""),
                            plasmoid.configuration.customCmdTitle || "value")
                        return
                    }

                    if (ct === 5) {
                        const barH = 14
                        const bx = yLW + 10, bw = gW - 20
                        const by = height / 2 - barH / 2
                        const pct = (root.customValue / maxVal) * 100
                        root.drawHorizontalBar(ctx, plasmoid.configuration.customCmdTitle || "Value", pct,
                            root.customValue.toFixed(2) + (plasmoid.configuration.customCmdUnit || ""),
                            color, bx, by, bw, barH)
                        return
                    }

                    if (ct === 1) {
                        root.drawHistoryBars(ctx, h, color, yLW, gW, height, maxH, maxVal, sf)
                        return
                    }

                    if (plasmoid.configuration.showYLabels) {
                        root.drawYAxis(ctx, yLW, height, [
                            { y: valToY(maxVal),     text: maxVal.toFixed(1) + (plasmoid.configuration.customCmdUnit || ""), grid: false },
                            { y: valToY(maxVal*0.5), text: (maxVal*0.5).toFixed(1), grid: true },
                            { y: valToY(0),          text: "0", grid: false }
                        ])
                    }

                    ctx.save(); ctx.beginPath(); ctx.rect(yLW, 0, gW, height); ctx.clip()
                    const segments = [[]]
                    for (let i = 0; i < n; i++) {
                        const x = iToX(i, n)
                        if (x < yLW - step) continue
                        segments[0].push({ x, y: valToY(h[i]) })
                    }

                    for (const pts of segments) {
                        if (pts.length < 2) continue
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? 8 : 0; ctx.shadowColor = color
                        ctx.beginPath(); ctx.lineWidth = plasmoid.configuration.lineWidth
                        ctx.strokeStyle = color; ctx.lineCap = "round"; ctx.lineJoin = "round"
                        ctx.moveTo(pts[0].x, pts[0].y)
                        for (let i = 1; i < pts.length; i++) {
                            const cx = (pts[i-1].x + pts[i].x) / 2
                            ctx.bezierCurveTo(cx, pts[i-1].y, cx, pts[i].y, pts[i].x, pts[i].y)
                        }
                        ctx.stroke(); ctx.shadowBlur = 0
                        ctx.beginPath(); ctx.moveTo(pts[0].x, pts[0].y)
                        for (let i = 1; i < pts.length; i++) {
                            const cx = (pts[i-1].x + pts[i].x) / 2
                            ctx.bezierCurveTo(cx, pts[i-1].y, cx, pts[i].y, pts[i].x, pts[i].y)
                        }
                        ctx.lineTo(pts[pts.length-1].x, height); ctx.lineTo(pts[0].x, height); ctx.closePath()
                        const c = Qt.color(color)
                        const g = ctx.createLinearGradient(0, pts[0].y, 0, height)
                        g.addColorStop(0, Qt.rgba(c.r,c.g,c.b,ct === 2 ? 0.58 : 0.28)); g.addColorStop(1, Qt.rgba(c.r,c.g,c.b,0))
                        ctx.fillStyle = g; ctx.fill()
                    }
                    if (segments[0].length > 0) {
                        const lp = segments[0][segments[0].length-1]
                        ctx.shadowBlur = plasmoid.configuration.glowLine ? 14 : 0; ctx.shadowColor = color
                        ctx.beginPath(); ctx.arc(lp.x, lp.y, 3.2, 0, Math.PI*2)
                        ctx.fillStyle = color; ctx.fill(); ctx.shadowBlur = 0
                    }
                    ctx.restore()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.showCustomSection && plasmoid.configuration.showLegend
                spacing: 12
                Item { width: plasmoid.configuration.showYLabels ? 38 : 0 }
                LegendItem {
                    text: plasmoid.configuration.customCmdTitle || "Value"
                    color: plasmoid.configuration.customCmdColor || "#ffaa00"
                    active: true
                }
                Item { Layout.fillWidth: true }
            }

        }
    }
}
