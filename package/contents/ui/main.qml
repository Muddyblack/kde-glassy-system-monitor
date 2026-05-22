import QtQuick 2.15
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── section flags ─────────────────────────────────────────────────────────
    readonly property bool showPingSection:   plasmoid.configuration.activeSection === 0
    readonly property bool showNetworkSpeed:  plasmoid.configuration.activeSection === 1
    readonly property bool showCpuSection:    plasmoid.configuration.activeSection === 2
    readonly property bool showMemorySection: plasmoid.configuration.activeSection === 3
    readonly property bool showDiskSection:   plasmoid.configuration.activeSection === 5
    readonly property bool showCustomSection: plasmoid.configuration.activeSection === 4
    readonly property bool showGpuSection:    plasmoid.configuration.activeSection === 6

    Layout.minimumWidth:  260
    Layout.preferredWidth: 400
    Layout.preferredHeight: {
        const m      = plasmoid.configuration.showBg ? 20 : 4
        const title  = 28
        const stats  = plasmoid.configuration.showStats && root.showPingSection ? 32 : 0
        const legend = plasmoid.configuration.showLegend ? 20 : 0
        const isText = plasmoid.configuration.chartType === 6
        const graph  = isText ? 0 : 160
        const pingH  = isText ? 0 : 160
        let h = m + title
        if (root.showPingSection)   h += 28 + pingH + stats + legend
        if (root.showNetworkSpeed)  h += graph + legend
        if (root.showCpuSection)    h += graph + legend + (plasmoid.configuration.showCpuCores ? 180 : 0)
        if (root.showMemorySection) h += graph + legend
        if (root.showDiskSection)   h += graph + legend
        if (root.showCustomSection) h += graph + legend
        if (root.showGpuSection)    h += 22 + graph + legend
        return Math.max(120, h)
    }
    Layout.minimumHeight: 120

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ── colors (pre-resolved, no per-frame allocation) ────────────────────────
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color lineColor:  plasmoid.configuration.useSystemAccent
                                            ? accentColor
                                            : Qt.color(plasmoid.configuration.customColor || "#39ff14")
    readonly property color textColor:  plasmoid.configuration.useSystemTextColor
                                            ? Kirigami.Theme.textColor
                                            : Qt.color(plasmoid.configuration.customTextColor || "#ffffff")
    readonly property color dlColor:    Qt.color(plasmoid.configuration.dlColor   || "#22aaff")
    readonly property color ulColor:    Qt.color(plasmoid.configuration.ulColor   || "#ff9933")
    readonly property color cpuColor:   Qt.color(plasmoid.configuration.cpuColor  || "#44ddaa")
    readonly property color memColor:   Qt.color(plasmoid.configuration.memColor  || "#aa66ff")
    readonly property color swapColor:  Qt.color(plasmoid.configuration.swapColor || "#ff6688")
    readonly property var coreColors:   (plasmoid.configuration.coreColorsStr ||
        "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff"
        ).split(",")

    // ── chart utils singleton ─────────────────────────────────────────────────
    ChartUtils {
        id: cu
        textColor:    root.textColor
        glowEnabled:  plasmoid.configuration.glowLine
        showGridLines: plasmoid.configuration.showGridLines
    }

    // ── smooth scroll: timestamp-based, computed at paint time ───────────────
    // Each section reads scrollPhase(start, interval) directly in onPaint via
    // Date.now() — no intermediate property, no signal cascade, no race.
    // The ticker drives requestPaint() at ~60fps so canvases stay animated.
    // On new data the start timestamp is recorded; the canvas computes the
    // current phase itself when it paints.
    property real _pingPhaseStart: 0
    property real _netPhaseStart:  0
    property real _cpuPhaseStart:  0
    property real _memPhaseStart:  0
    property real _dskPhaseStart:  0
    property real _custPhaseStart: 0
    property real _gpuPhaseStart:  0

    function netScrollPhase()  { return _netPhaseStart  > 0 ? (Date.now() - _netPhaseStart)  / 1000  : 0 }
    function cpuScrollPhase()  { return _cpuPhaseStart  > 0 ? (Date.now() - _cpuPhaseStart)  / 1000  : 0 }
    function memScrollPhase()  { return _memPhaseStart  > 0 ? (Date.now() - _memPhaseStart)  / 2000  : 0 }
    function diskScrollPhase() { return _dskPhaseStart  > 0 ? (Date.now() - _dskPhaseStart)  / 1000  : 0 }
    function custScrollPhase() { return _custPhaseStart > 0 ? (Date.now() - _custPhaseStart) / Math.max(500, plasmoid.configuration.customCmdInterval * 1000) : 0 }
    function pingScrollPhase() { return _pingPhaseStart > 0 ? (Date.now() - _pingPhaseStart) / Math.max(500, plasmoid.configuration.pingInterval * 1000) : 0 }
    function gpuScrollPhase()  { return _gpuPhaseStart  > 0 ? (Date.now() - _gpuPhaseStart)  / 2000  : 0 }

    // Bumps every 16ms; sections connect to this to call requestPaint().
    property int scrollTick: 0
    Timer {
        id: scrollTicker
        interval: 16; repeat: true; running: true
        onTriggered: root.scrollTick = (root.scrollTick + 1) & 0x7fffffff
    }

    onHistoriesChanged:     { _pingPhaseStart = Date.now() }
    onDlHistoryChanged:     { _netPhaseStart  = Date.now() }
    onCpuHistoryChanged:    { _cpuPhaseStart  = Date.now() }
    onMemHistoryChanged:    { _memPhaseStart  = Date.now() }
    onCustomHistoryChanged: { _custPhaseStart = Date.now() }
    onGpuHistoryChanged:    { _gpuPhaseStart  = Date.now() }

    function restartDiskScroll() { _dskPhaseStart = Date.now() }

    // ── ping state ────────────────────────────────────────────────────────────
    readonly property var targetList: {
        const raw = plasmoid.configuration.targets || "8.8.8.8"
        return raw.split(",").map(s => s.trim()).filter(s => s.length > 0)
    }
    readonly property int activeTarget: Math.max(0,
        Math.min(plasmoid.configuration.currentTargetIndex, targetList.length - 1))

    property var  histories:       []
    property real lastPing:        -1
    property real avgPing:         0
    property real jitter:          0
    property real lossPercent:     0
    property bool isAlerting:      false
    property bool isPinging:       false
    property real lastPingTimestamp: 0

    Component.onCompleted: { rebuildHistories(); triggerPing() }
    onTargetListChanged:    rebuildHistories()

    function rebuildHistories() {
        const h = []
        for (let i = 0; i < targetList.length; i++) h.push(histories[i] || [])
        histories = h
    }

    P5Support.DataSource {
        id: pingSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isPinging = false
            pingSource.disconnectSource(sourceName)
            // Support both "time=X" (IPv4) and "time X" (ping6 on some systems)
            const m  = (data["stdout"] || "").match(/time[<=\s](\d+(?:[.,]\d+)?)/)
            const ms = m ? parseFloat(m[1].replace(",", ".")) : -1
            root.lastPingTimestamp = Date.now()
            root.addPingResult(root.activeTarget, ms)
        }
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.pingInterval) * 1000
        running: root.showPingSection; repeat: true
        onTriggered: root.triggerPing()
    }

    function triggerPing() {
        if (!root.showPingSection || isPinging || targetList.length === 0) return
        const host = targetList[activeTarget]
        if (!host) return
        isPinging = true
        // Detect IPv6 address or bracketed IPv6 and use ping6 if available, else ping with -6
        const isIPv6 = host.indexOf(":") !== -1
        const cmd = isIPv6
            ? "ping6 -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host
              + " 2>/dev/null || ping -6 -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host
            : "ping -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host
        pingSource.connectSource(cmd)
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

    // ── network state ─────────────────────────────────────────────────────────
    property real downloadSpeed:    0
    property real uploadSpeed:      0
    property var  dlHistory:        []
    property var  ulHistory:        []
    property var  lastNetBytes:     null
    property string activeIface:    ""
    property var  availableIfaces:  ["auto"]
    property bool isReadingNet:     false
    property real sessionDlBytes:   0
    property real sessionUlBytes:   0

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
        let bestIface = "", bestRx = -1; const ifaceData = {}
        const foundIfaces = ["auto"]
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\w+):\s+(\d+)(?:\s+\d+){7}\s+(\d+)/)
            if (!m || m[1] === "lo") continue
            ifaceData[m[1]] = { rx: parseInt(m[2]), tx: parseInt(m[3]) }
            foundIfaces.push(m[1])
            if (ifaceData[m[1]].rx > bestRx) { bestRx = ifaceData[m[1]].rx; bestIface = m[1] }
        }
        
        // Only update property if array changed (to avoid unnecessary re-renders)
        if (root.availableIfaces.length !== foundIfaces.length || !root.availableIfaces.every((val, index) => val === foundIfaces[index])) {
            root.availableIfaces = foundIfaces
        }

        const iface = (cfgIface !== "auto" && ifaceData[cfgIface]) ? cfgIface : bestIface
        if (!iface || !ifaceData[iface]) return
        const now = Date.now(), { rx, tx } = ifaceData[iface]
        if (lastNetBytes && lastNetBytes.iface === iface) {
            const dt = (now - lastNetBytes.time) / 1000
            if (dt > 0.1) {
                downloadSpeed = Math.max(0, (rx - lastNetBytes.rx) / dt)
                uploadSpeed   = Math.max(0, (tx - lastNetBytes.tx) / dt)
                sessionDlBytes += downloadSpeed * dt
                sessionUlBytes += uploadSpeed   * dt
                const maxH = Math.max(10, plasmoid.configuration.historySize)
                const nd = dlHistory.slice(); nd.push(downloadSpeed)
                if (nd.length > maxH) nd.splice(0, nd.length - maxH); dlHistory = nd
                const nu = ulHistory.slice(); nu.push(uploadSpeed)
                if (nu.length > maxH) nu.splice(0, nu.length - maxH); ulHistory = nu
            }
        }
        lastNetBytes = { iface, rx, tx, time: now }; activeIface = iface
    }

    // ── CPU state ─────────────────────────────────────────────────────────────
    property real cpuPercent:    0
    property var  cpuHistory:    []
    property var  corePercents:  []
    property var  coreHistories: []
    property var  lastCpuStats:  null
    property bool isReadingCpu:  false

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
            const active=user+nice+sys+irq+sirq, total=active+idle+iow
            if (m[1]==="cpu") stats.total={active,total}; else stats.cores.push({active,total})
        }
        if (!stats.total) return
        if (lastCpuStats?.total) {
            const dt=stats.total.total-lastCpuStats.total.total
            const da=stats.total.active-lastCpuStats.total.active
            if (dt>0) cpuPercent=Math.min(100,Math.max(0,da/dt*100))
            const newCP=[]
            for (let i=0;i<stats.cores.length;i++) {
                const prev=lastCpuStats.cores[i]
                if (!prev){newCP.push(0);continue}
                const cdt=stats.cores[i].total-prev.total,cda=stats.cores[i].active-prev.active
                newCP.push(cdt>0?Math.min(100,Math.max(0,cda/cdt*100)):0)
            }
            corePercents=newCP
            const maxH=Math.max(10,plasmoid.configuration.historySize)
            const nh=cpuHistory.slice();nh.push(cpuPercent)
            if(nh.length>maxH)nh.splice(0,nh.length-maxH);cpuHistory=nh
            let ch=coreHistories.length===newCP.length?coreHistories.map(h=>h.slice()):newCP.map(()=>[])
            for(let i=0;i<newCP.length;i++){ch[i].push(newCP[i]);if(ch[i].length>maxH)ch[i].splice(0,ch[i].length-maxH)}
            coreHistories=ch
        }
        lastCpuStats=stats
    }

    // ── memory state ──────────────────────────────────────────────────────────
    property real memPercent:   0
    property real swapPercent:  0
    property var  memHistory:   []
    property var  swapHistory:  []
    property real memUsedGiB:   0
    property real memTotalGiB:  0
    property real swapUsedGiB:  0
    property bool hasSwap:      false
    property bool isReadingMem: false

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
        const v={}
        for(const line of text.split("\n")){const m=line.match(/^(\w+):\s+(\d+)/);if(m)v[m[1]]=parseInt(m[2])}
        const total=v["MemTotal"]||0,avail=v["MemAvailable"]||0
        const swapTot=v["SwapTotal"]||0,swapFree=v["SwapFree"]||0
        if(total>0){const used=total-avail;memPercent=used/total*100;memUsedGiB=used/1048576;memTotalGiB=total/1048576}
        hasSwap=swapTot>0
        if(hasSwap){swapPercent=(swapTot-swapFree)/swapTot*100;swapUsedGiB=(swapTot-swapFree)/1048576}
        const maxH=Math.max(10,plasmoid.configuration.historySize)
        const nm=memHistory.slice();nm.push(memPercent);if(nm.length>maxH)nm.splice(0,nm.length-maxH);memHistory=nm
        const ns=swapHistory.slice();ns.push(swapPercent);if(ns.length>maxH)ns.splice(0,ns.length-maxH);swapHistory=ns
    }

    // ── custom command state ──────────────────────────────────────────────────
    property real customValue:       0
    property var  customHistory:     []
    property bool isReadingCustom:   false

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

    // ── GPU state ─────────────────────────────────────────────────────────────
    // gpuMode: "nvidia" | "amd" | "intel" | "fdinfo" | "none"
    property string gpuMode:       ""
    property string gpuVendor:     ""   // "nvidia" | "amd" | "intel" | ""
    property real   gpuPercent:    0
    property int    gpuFreqMhz:    0
    property var    gpuHistory:    []
    property int    gpuNoDataTicks: 0
    property bool   isReadingGpu:  false
    property bool   gpuDetected:   false

    readonly property color gpuColor: Qt.color(plasmoid.configuration.gpuColor || "#ff6e40")

    // Detect GPU backend once on startup
    P5Support.DataSource {
        id: gpuDetectSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            gpuDetectSource.disconnectSource(sourceName)
            const out = (data["stdout"] || "").trim()
            if (sourceName.indexOf("nvidia-smi") !== -1 && out.length > 0) {
                root.gpuMode   = "nvidia"
                root.gpuVendor = "nvidia"
                root.gpuDetected = true
            } else if (sourceName.indexOf("rocm-smi") !== -1 && out.length > 0 && !root.gpuDetected) {
                root.gpuMode   = "amd"
                root.gpuVendor = "amd"
                root.gpuDetected = true
            } else if (sourceName.indexOf("vendor") !== -1 && !root.gpuDetected) {
                // sysfs vendor id: 0x8086=Intel, 0x1002=AMD, 0x10de=NVIDIA
                if (out === "0x8086") { root.gpuVendor = "intel"; root.gpuMode = "intel"; root.gpuDetected = true }
                else if (out === "0x1002") { root.gpuVendor = "amd"; root.gpuMode = "fdinfo"; root.gpuDetected = true }
                else if (out === "0x10de") { root.gpuVendor = "nvidia"; root.gpuMode = "fdinfo"; root.gpuDetected = true }
                else if (out.length > 0)  { root.gpuVendor = ""; root.gpuMode = "fdinfo"; root.gpuDetected = true }
            }
        }
    }

    P5Support.DataSource {
        id: gpuSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            root.isReadingGpu = false
            gpuSource.disconnectSource(sourceName)
            root.parseGpuData(sourceName, data["stdout"] || "")
        }
    }

    Timer {
        id: gpuDetectTimer; interval: 200; repeat: false; running: root.showGpuSection
        onTriggered: {
            // Try nvidia-smi first, then rocm-smi, then sysfs vendor
            gpuDetectSource.connectSource("nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1")
            gpuDetectSource.connectSource("cat /sys/class/drm/card0/device/vendor 2>/dev/null || cat /sys/class/drm/card1/device/vendor 2>/dev/null")
        }
    }

    Timer {
        interval: 2000; running: root.showGpuSection; repeat: true
        onTriggered: {
            if (!root.isReadingGpu && root.gpuMode !== "") {
                root.isReadingGpu = true
                if (root.gpuMode === "nvidia") {
                    gpuSource.connectSource("nvidia-smi --query-gpu=utilization.gpu,clocks.current.graphics --format=csv,noheader,nounits 2>/dev/null")
                } else if (root.gpuMode === "amd") {
                    gpuSource.connectSource("cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null")
                } else if (root.gpuMode === "intel") {
                    // Intel: rc6_residency_ms delta → busy %, plus current freq
                    gpuSource.connectSource("cat /sys/class/drm/card1/gt/gt0/rc6_residency_ms 2>/dev/null || cat /sys/class/drm/card0/gt/gt0/rc6_residency_ms 2>/dev/null; echo; cat /sys/class/drm/card1/gt/gt0/rps_cur_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/gt/gt0/rps_cur_freq_mhz 2>/dev/null; echo; cat /sys/class/drm/card1/gt/gt0/rps_act_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/gt/gt0/rps_act_freq_mhz 2>/dev/null")
                } else {
                    // fdinfo fallback: sum drm-engine-render across all processes
                    gpuSource.connectSource("grep -r 'drm-engine-render' /proc/*/fdinfo/ 2>/dev/null | awk '{sum+=$2} END{print sum}'")
                }
            } else if (!root.isReadingGpu && root.gpuMode === "" && root.gpuNoDataTicks < 2) {
                root.isReadingGpu = true
                gpuSource.connectSource("cat /sys/class/drm/card1/gt/gt0/rps_act_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo ''")
                root.gpuNoDataTicks++
            } else {
                root.isReadingGpu = false
            }
        }
    }

    property real _gpuLastRc6Ms: -1
    property real _gpuLastPollMs: 0

    function parseGpuData(src, text) {
        const lines = text.trim().split("\n")
        const maxH  = Math.max(10, plasmoid.configuration.historySize)

        if (root.gpuMode === "nvidia") {
            // "util, freq" per line (one GPU)
            const parts = lines[0] ? lines[0].split(",") : []
            const util  = parseFloat(parts[0])
            const freq  = parseInt(parts[1])
            if (!isNaN(util)) root.gpuPercent = Math.min(100, Math.max(0, util))
            if (!isNaN(freq)) root.gpuFreqMhz = freq
            root.gpuNoDataTicks = 0
        } else if (root.gpuMode === "amd") {
            // gpu_busy_percent sysfs → single int
            const v = parseInt(lines[0])
            if (!isNaN(v)) { root.gpuPercent = Math.min(100, Math.max(0, v)); root.gpuNoDataTicks = 0 }
            else root.gpuNoDataTicks++
        } else if (root.gpuMode === "intel") {
            // line0: rc6_residency_ms, line1: rps_cur_freq_mhz, line2: rps_act_freq_mhz
            const rc6Now = parseFloat(lines[0])
            const cur    = parseInt(lines[1])
            const act    = parseInt(lines[2])
            const now    = Date.now()
            if (!isNaN(cur))  root.gpuFreqMhz = isNaN(act) || act === 0 ? cur : act
            if (!isNaN(rc6Now) && root._gpuLastRc6Ms >= 0 && root._gpuLastPollMs > 0) {
                const dtMs  = now - root._gpuLastPollMs
                const dRc6  = rc6Now - root._gpuLastRc6Ms
                // rc6 = idle residency → busy = 1 - (dRc6 / dtMs), clamped
                const busy  = Math.min(100, Math.max(0, (1.0 - dRc6 / dtMs) * 100))
                root.gpuPercent = busy
                root.gpuNoDataTicks = 0
            }
            root._gpuLastRc6Ms  = rc6Now
            root._gpuLastPollMs = now
        } else {
            // fdinfo sum of nanoseconds — compare delta, approximate %
            const ns = parseFloat(lines[0])
            if (!isNaN(ns) && ns > 0) { root.gpuPercent = Math.min(100, ns / 20000000); root.gpuNoDataTicks = 0 }
            else root.gpuNoDataTicks++
        }

        const nh = root.gpuHistory.slice(); nh.push(root.gpuPercent)
        if (nh.length > maxH) nh.splice(0, nh.length - maxH)
        root.gpuHistory = nh
    }

    // ── shared interaction state ──────────────────────────────────────────────
    property string hoveredLine: ""
    property int    hoveredCore: -1

    function isLineDisabled(key) {
        return (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean).indexOf(key) !== -1
    }
    function toggleLineDisabled(key) {
        let arr = (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean)
        if (arr.indexOf(key) !== -1) arr = arr.filter(k => k !== key); else arr.push(key)
        plasmoid.configuration.disabledLinesStr = arr.join(",")
    }
    function isCoreDisabled(idx) {
        return (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean).indexOf(idx.toString()) !== -1
    }
    function toggleCoreDisabled(idx) {
        let arr = (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean)
        if (arr.indexOf(idx.toString()) !== -1) arr = arr.filter(k => k !== idx.toString()); else arr.push(idx.toString())
        plasmoid.configuration.disabledCoresStr = arr.join(",")
    }

    // ── representations ───────────────────────────────────────────────────────
    compactRepresentation: CompactRepresentation {}

    fullRepresentation: Item {
        id: container

        // glassy background card
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

        // alert pulse ring
        Rectangle {
            id: alertRing; anchors.fill: parent; radius: plasmoid.configuration.bgRadius
            color: "transparent"; border.color: "#ff4444"; border.width: 2
            visible: root.showPingSection && root.isAlerting
            opacity: 0
            SequentialAnimation {
                running: root.isAlerting && root.showPingSection; loops: Animation.Infinite
                NumberAnimation { target: alertRing; property: "opacity"; from: 0; to: 0.75; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { target: alertRing; property: "opacity"; from: 0.75; to: 0; duration: 650; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) alertRing.opacity = 0
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: plasmoid.configuration.showBg ? 10 : 2
            spacing: 4

            // title row — centered label + optional CPU total on the right
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 2
                implicitHeight: titleLabel.implicitHeight

                Text {
                    id: titleLabel
                    anchors.centerIn: parent
                    text: {
                        if (root.showPingSection)   return plasmoid.configuration.pingTitle    || "Ping"
                        if (root.showNetworkSpeed)  return plasmoid.configuration.networkTitle || "Network Speed"
                        if (root.showCpuSection)    return plasmoid.configuration.cpuTitle     || "CPU"
                        if (root.showMemorySection) return plasmoid.configuration.memoryTitle  || "Memory"
                        if (root.showDiskSection)   return plasmoid.configuration.diskTitle    || "Disk I/O"
                        if (root.showGpuSection)    return plasmoid.configuration.gpuTitle     || "GPU"
                        return plasmoid.configuration.customCmdTitle || "Custom Sensor"
                    }
                    color: root.textColor
                    font.pixelSize: 15; font.bold: true; font.letterSpacing: 0.3
                    renderType: Text.NativeRendering
                }

                // Network download total — only shown when Network section is active
                Item {
                    visible: root.showNetworkSpeed
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    implicitWidth: netDlTotalRow.implicitWidth; implicitHeight: netDlTotalRow.implicitHeight
                    Row {
                        id: netDlTotalRow
                        spacing: 4
                        Text {
                            text: "↓"
                            color: Qt.rgba(root.dlColor.r, root.dlColor.g, root.dlColor.b, 0.6)
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: cu.formatBytes(root.sessionDlBytes)
                            color: root.dlColor
                            font.pixelSize: 11; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Network combined speed and upload total — only shown when Network section is active
                Item {
                    visible: root.showNetworkSpeed
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    implicitWidth: netRightRow.implicitWidth; implicitHeight: netRightRow.implicitHeight
                    Row {
                        id: netRightRow
                        spacing: 10
                        Row {
                            spacing: 4
                            Text {
                                text: "↕"
                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: cu.formatSpeed(root.downloadSpeed + root.uploadSpeed)
                                color: root.textColor
                                font.pixelSize: 13; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Row {
                            spacing: 4
                            Text {
                                text: "↑"
                                color: Qt.rgba(root.ulColor.r, root.ulColor.g, root.ulColor.b, 0.6)
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: cu.formatBytes(root.sessionUlBytes)
                                color: root.ulColor
                                font.pixelSize: 11; font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // GPU total — only shown when GPU section is active
                Item {
                    visible: root.showGpuSection
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    implicitWidth: gpuTotalRow.implicitWidth; implicitHeight: gpuTotalRow.implicitHeight
                    Row {
                        id: gpuTotalRow
                        spacing: 5
                        Rectangle {
                            width: 9; height: 9; radius: 2; anchors.verticalCenter: parent.verticalCenter
                            color: root.gpuColor
                            border.color: root.gpuColor; border.width: 1
                        }
                        Text {
                            text: root.gpuPercent.toFixed(1) + "%"
                            color: root.gpuColor
                            font.pixelSize: 15; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // CPU total — only shown when CPU section is active
                Item {
                    visible: root.showCpuSection
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    implicitWidth: cpuTotalRow.implicitWidth; implicitHeight: cpuTotalRow.implicitHeight
                    Row {
                        id: cpuTotalRow
                        spacing: 5
                        Rectangle {
                            width: 9; height: 9; radius: 2; anchors.verticalCenter: parent.verticalCenter
                            color: root.isLineDisabled("cpuTotal") ? "transparent" : root.cpuColor
                            border.color: root.cpuColor; border.width: 1
                        }
                        Text {
                            text: root.cpuPercent.toFixed(1) + "%"
                            color: root.isLineDisabled("cpuTotal")
                                ? Qt.rgba(root.cpuColor.r, root.cpuColor.g, root.cpuColor.b, 0.3)
                                : root.cpuColor
                            font.pixelSize: 15; font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked:  { root.toggleLineDisabled("cpuTotal") }
                        onEntered:  { root.hoveredLine = "cpuTotal" }
                        onExited:   { root.hoveredLine = "" }
                    }
                }
            }

            // ping
            PingSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showPingSection
            }

            // network separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showNetworkSpeed && root.showPingSection
            }

            // network
            NetworkSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showNetworkSpeed
            }

            // cpu separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showCpuSection && (root.showPingSection || root.showNetworkSpeed)
            }

            // cpu
            CpuSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showCpuSection
            }

            // memory separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showMemorySection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection)
            }

            // memory
            MemorySection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showMemorySection
            }

            // disk separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showDiskSection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection || root.showMemorySection)
            }

            // disk
            DiskSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showDiskSection
            }

            // custom separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showCustomSection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection || root.showMemorySection || root.showDiskSection)
            }

            // custom
            CustomSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showCustomSection
            }

            // gpu separator
            Rectangle {
                Layout.fillWidth: true; height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showGpuSection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection || root.showMemorySection || root.showDiskSection || root.showCustomSection)
            }

            // gpu
            GpuSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showGpuSection
            }
        }
    }
}
