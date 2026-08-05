import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── section flags ─────────────────────────────────────────────────────────
    readonly property bool showPingSection: plasmoid.configuration.activeSection === 0
    readonly property bool showNetworkSpeed: plasmoid.configuration.activeSection === 1
    readonly property bool showCpuSection: plasmoid.configuration.activeSection === 2
    readonly property bool showMemorySection: plasmoid.configuration.activeSection === 3
    readonly property bool showDiskSection: plasmoid.configuration.activeSection === 5
    readonly property bool showCustomSection: plasmoid.configuration.activeSection === 4
    readonly property bool showGpuSection: plasmoid.configuration.activeSection === 6
    readonly property bool showHwSensors: plasmoid.configuration.activeSection === 7
    readonly property bool showOsInfo: plasmoid.configuration.activeSection === 8
    readonly property bool showPowerSection: plasmoid.configuration.activeSection === 9

    // isInPanel: true when Plasma places us on a panel edge, or user forces it.
    readonly property bool isInPanel: plasmoid.configuration.panelMode || Plasmoid.location === PlasmaCore.Types.TopEdge || Plasmoid.location === PlasmaCore.Types.BottomEdge || Plasmoid.location === PlasmaCore.Types.LeftEdge || Plasmoid.location === PlasmaCore.Types.RightEdge
    readonly property bool panelSessionTotalsVisible: plasmoid.configuration.panelShowSessionTotals && root.height >= 34
    readonly property int desktopPreferredWidth: (root.showMemorySection || (root.showCpuSection && !plasmoid.configuration.showCpuCores)) ? 240 : 320

    Layout.minimumWidth: root.isInPanel ? (root.showNetworkSpeed && !root.panelSessionTotalsVisible ? 36 : 60) : 120
    Layout.preferredWidth: root.isInPanel ? (root.showNetworkSpeed ? (root.panelSessionTotalsVisible ? 82 : 46) : (root.showDiskSection ? 82 : 68)) : root.desktopPreferredWidth
    Layout.preferredHeight: {
        if (root.isInPanel)
            return -1;
        const m = 16;
        const title = 24;
        const stats = plasmoid.configuration.showStats && root.showPingSection ? 28 : 0;
        const legend = plasmoid.configuration.showLegend ? 18 : 0;
        const isText = plasmoid.configuration.chartType === 6;
        const graph = isText ? 0 : 90;
        const pingH = isText ? 0 : 100;
        let h = m + title;
        if (root.showPingSection)
            h += 24 + pingH + stats + legend;
        if (root.showNetworkSpeed)
            h += graph + legend;
        if (root.showCpuSection)
            h += graph + legend + (plasmoid.configuration.showCpuCores ? 140 : 0);
        if (root.showMemorySection)
            h += graph + legend;
        if (root.showDiskSection)
            h += graph + legend;
        if (root.showCustomSection)
            h += graph + legend;
        if (root.showGpuSection)
            h += 22 + graph + legend;
        if (root.showHwSensors) {
            const c = hwSensorRowsModel.count;
            h += c > 0 ? c * 22 + 8 : 90;
        }
        if (root.showOsInfo)
            h += 100;
        if (root.showPowerSection)
            h += 180;
        return Math.max(80, h);
    }
    Layout.minimumHeight: root.isInPanel ? 20 : 80

    // Let Plasma decide: in a panel it uses compactRepresentation automatically.
    // We do NOT force fullRepresentation so the panel placement works without
    // any config toggle. The config panelMode override also works on desktop.
    preferredRepresentation: root.isInPanel ? compactRepresentation : fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    // ── colors (pre-resolved, no per-frame allocation) ────────────────────────
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color lineColor: plasmoid.configuration.useSystemAccent ? accentColor : Qt.color(plasmoid.configuration.customColor || "#39ff14")
    readonly property color pingColor: Qt.color(plasmoid.configuration.pingColor || "#39ff14")
    readonly property color pingWarnColor: Qt.color(plasmoid.configuration.pingWarnColor || "#ffaa22")
    readonly property color pingCritColor: Qt.color(plasmoid.configuration.pingCritColor || "#ff4444")
    // Alert styling is suppressed entirely when threshold colouring is off, so
    // the ping section stays on the user's own colour no matter the latency.
    readonly property bool pingAlertActive: plasmoid.configuration.pingThresholdColors && isAlerting
    readonly property color textColor: plasmoid.configuration.useSystemTextColor ? Kirigami.Theme.textColor : Qt.color(plasmoid.configuration.customTextColor || "#ffffff")
    readonly property color dlColor: Qt.color(plasmoid.configuration.dlColor || "#22aaff")
    readonly property color ulColor: Qt.color(plasmoid.configuration.ulColor || "#ff9933")
    readonly property color cpuColor: Qt.color(plasmoid.configuration.cpuColor || "#44ddaa")
    readonly property color memColor: Qt.color(plasmoid.configuration.memColor || "#aa66ff")
    readonly property color swapColor: Qt.color(plasmoid.configuration.swapColor || "#ff6688")
    readonly property var coreColors: (plasmoid.configuration.coreColorsStr || "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff").split(",")

    // ── chart utils singleton ─────────────────────────────────────────────────
    ChartUtils {
        id: cu
        textColor: root.textColor
        glowEnabled: plasmoid.configuration.glowLine
        showGridLines: plasmoid.configuration.showGridLines
        gpuBloom: plasmoid.configuration.gpuBloom && plasmoid.configuration.glowLine
    }

    // ── smooth scroll: timestamp-based, computed at paint time ───────────────
    // Each section reads scrollPhase(start, interval) directly in onPaint via
    // Date.now() — no intermediate property, no signal cascade, no race.
    // The ticker drives requestPaint() at ~60fps so canvases stay animated.
    // On new data the start timestamp is recorded; the canvas computes the
    // current phase itself when it paints.
    property real _pingPhaseStart: 0
    property real _netPhaseStart: 0
    property real _cpuPhaseStart: 0
    property real _memPhaseStart: 0
    property real _dskPhaseStart: 0
    property real _custPhaseStart: 0
    property real _gpuPhaseStart: 0

    // Measured interval (ms) between the last two data updates per channel.
    // Seeded from the nominal/configured cadence and then EMA-smoothed toward
    // the real gap. Using the *actual* gap as the phase divisor makes the
    // scroll finish exactly as the next sample lands — late data slows the
    // scroll instead of freezing, early data speeds it instead of snapping.
    // Computed once per update (in markPhase), so it adds nothing per frame.
    property real _netInterval: 1000
    property real _cpuInterval: 1000
    property real _memInterval: 2000
    property real _dskInterval: 1000
    property real _custInterval: 2000
    property real _pingInterval: 1000
    property real _gpuInterval: 2000

    // Record a new data update: smooth the measured gap toward the real cadence.
    // prevStart is the previous start timestamp; minMs/maxMs clamp out absurd
    // gaps (first sample, system sleep/resume, config change).
    function _measureInterval(prevStart, prevInterval, minMs, maxMs) {
        if (prevStart <= 0)
            return prevInterval;
        const gap = Date.now() - prevStart;
        if (gap < minMs || gap > maxMs)
            return prevInterval;
        // EMA: 70% history + 30% new — absorbs single-sample jitter, still
        // tracks a genuine cadence change within a few updates.
        return prevInterval * 0.7 + gap * 0.3;
    }

    function netScrollPhase() {
        return _netPhaseStart > 0 ? (Date.now() - _netPhaseStart) / _netInterval : 0;
    }
    function cpuScrollPhase() {
        return _cpuPhaseStart > 0 ? (Date.now() - _cpuPhaseStart) / _cpuInterval : 0;
    }
    function memScrollPhase() {
        return _memPhaseStart > 0 ? (Date.now() - _memPhaseStart) / _memInterval : 0;
    }
    function diskScrollPhase() {
        return _dskPhaseStart > 0 ? (Date.now() - _dskPhaseStart) / _dskInterval : 0;
    }
    function custScrollPhase() {
        return _custPhaseStart > 0 ? (Date.now() - _custPhaseStart) / _custInterval : 0;
    }
    function pingScrollPhase() {
        return _pingPhaseStart > 0 ? (Date.now() - _pingPhaseStart) / _pingInterval : 0;
    }
    function gpuScrollPhase() {
        return _gpuPhaseStart > 0 ? (Date.now() - _gpuPhaseStart) / _gpuInterval : 0;
    }

    // Latency band of a single sample: 0 = normal, 1 = warning, 2 = critical.
    // The graph is split into runs of equal band so one spike only recolours
    // itself instead of the whole line. With threshold colouring off every
    // sample reports band 0 and the graph stays on the user's own colour.
    function pingBandFor(ms) {
        if (!plasmoid.configuration.pingThresholdColors)
            return 0;
        const threshold = plasmoid.configuration.latencyThreshold;
        if (ms > threshold * 1.5)
            return 2;
        if (ms > threshold)
            return 1;
        return 0;
    }
    function pingBandColor(band) {
        return band === 2 ? pingCritColor : band === 1 ? pingWarnColor : pingColor;
    }
    function pingColorFor(ms) {
        return pingBandColor(pingBandFor(ms));
    }
    // Colour for the live readout / single-value charts, which react to the
    // alert state (latency *or* packet loss) rather than a raw sample.
    function pingAlertColor() {
        return pingAlertActive ? pingCritColor : pingColor;
    }

    // Scroll animation ticker. Interval is derived from configured targetFps;
    // 30/60/120 fps are the typical values. Only runs while a visible section
    // is within its post-data scroll window, so it auto-pauses when idle —
    // important when multiple instances are placed on the desktop.
    property int scrollTick: 0
    readonly property int _tickInterval: Math.max(8, Math.round(1000 / Math.max(15, plasmoid.configuration.targetFps || 60)))

    // Base sensor poll period in milliseconds; the slower sensors are plain
    // multiples of it (see main.xml). Floored at 250 ms because every tick forks
    // a shell through the executable engine — below that the process spawns cost
    // far more than the extra resolution is worth.
    readonly property int _pollBase: Math.max(250, plasmoid.configuration.updateInterval || 1000)
    // Phase windows are normalised to 1.0 = one full data interval.
    // Keep the threshold just above 1.0 so the animation expires between
    // data updates rather than staying permanently active.
    // NOTE: We deliberately do NOT use a readonly binding for "is anything
    // animating?". The phase functions read Date.now(), which Qt's binding
    // system cannot track, so such a binding would never re-evaluate to
    // false once data arrives, and the ticker would run forever (a major
    // source of constant CPU). Instead the ticker is started on each data
    // update and stops ITSELF once every phase has expired past 1.0.
    function _anyAnimatingNow() {
        if (!plasmoid.configuration.smoothScroll)
            return false;
        if (root.showPingSection && root._pingPhaseStart > 0 && root.pingScrollPhase() < 1.05)
            return true;
        if (root.showNetworkSpeed && root._netPhaseStart > 0 && root.netScrollPhase() < 1.05)
            return true;
        if (root.showCpuSection && root._cpuPhaseStart > 0 && root.cpuScrollPhase() < 1.05)
            return true;
        if (root.showMemorySection && root._memPhaseStart > 0 && root.memScrollPhase() < 1.05)
            return true;
        if (root.showDiskSection && root._dskPhaseStart > 0 && root.diskScrollPhase() < 1.05)
            return true;
        if (root.showCustomSection && root._custPhaseStart > 0 && root.custScrollPhase() < 1.05)
            return true;
        if (root.showGpuSection && root._gpuPhaseStart > 0 && root.gpuScrollPhase() < 1.05)
            return true;
        return false;
    }

    // Start the ticker whenever new data lands on any channel. The ticker
    // then stops itself once all phases have expired (see onTriggered).
    function _ensureScrollTicker() {
        if (plasmoid.configuration.smoothScroll && !scrollTicker.running)
            scrollTicker.start();
    }
    // ── background card ───────────────────────────────────────────────────────
    // Per-corner radii, read as direct property bindings so Qt tracks them and
    // the canvases repaint by themselves (a plasmoid.configuration[name] lookup
    // is opaque to the binding engine and would need manual change handlers).
    readonly property real _radTL: plasmoid.configuration.bgRadiusTL || 0
    readonly property real _radTR: plasmoid.configuration.bgRadiusTR || 0
    readonly property real _radBR: plasmoid.configuration.bgRadiusBR || 0
    readonly property real _radBL: plasmoid.configuration.bgRadiusBL || 0
    readonly property real _radMax: Math.max(_radTL, _radTR, _radBR, _radBL)

    // Rounded-rect path with four independent corners. QtQuick's Rectangle has a
    // single radius, so every card pass (fill, frost source, frost mask, edge)
    // draws through this one builder to stay pixel-identical.
    function _cardPath(ctx, w, h, inset) {
        const i = inset || 0;
        const tl = Math.max(0, root._radTL - i);
        const tr = Math.max(0, root._radTR - i);
        const br = Math.max(0, root._radBR - i);
        const bl = Math.max(0, root._radBL - i);
        const x0 = i, y0 = i, x1 = w - i, y1 = h - i;
        ctx.beginPath();
        ctx.moveTo(x0 + tl, y0);
        ctx.lineTo(x1 - tr, y0);
        ctx.arcTo(x1, y0, x1, y0 + tr, tr);
        ctx.lineTo(x1, y1 - br);
        ctx.arcTo(x1, y1, x1 - br, y1, br);
        ctx.lineTo(x0 + bl, y1);
        ctx.arcTo(x0, y1, x0, y1 - bl, bl);
        ctx.lineTo(x0, y0 + tl);
        ctx.arcTo(x0, y0, x0 + tl, y0, tl);
        ctx.closePath();
    }

    // One canvas type for every card pass; `mode` picks what it draws. Repaints
    // are driven by the bound radii/colour above plus its own geometry.
    component CardCanvas: Canvas {
        id: cardCanvas
        property int mode: 0    // 0 = flat fill, 1 = frost source, 2 = mask, 3 = edge
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Image

        readonly property real rTL: root._radTL
        readonly property real rTR: root._radTR
        readonly property real rBR: root._radBR
        readonly property real rBL: root._radBL
        readonly property color fill: plasmoid.configuration.bgColor || "#800d0f1a"

        onRTLChanged: requestPaint()
        onRTRChanged: requestPaint()
        onRBRChanged: requestPaint()
        onRBLChanged: requestPaint()
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            if (width < 1 || height < 1)
                return;
            const ctx = getContext("2d");
            ctx.reset();

            if (mode === 2) {
                // Opaque mask: rounds off the blurred composite. A Rectangle
                // radius + clip would only clip the square bbox, letting the
                // blur leak past the corners.
                root._cardPath(ctx, width, height);
                ctx.fillStyle = "black";
                ctx.fill();
                return;
            }

            if (mode === 3) {
                // Crisp edge drawn live on top of the blur — blurring it would
                // muddy the very line that sells the glass. Inset by half the
                // stroke so the hairline sits inside the card.
                root._cardPath(ctx, width, height, 0.5);
                ctx.lineWidth = 1;
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.13);
                ctx.stroke();
                // 1px top highlight, inset from the corners like the old card.
                const inset = 12;
                if (width > inset * 2) {
                    ctx.beginPath();
                    ctx.moveTo(inset, 1.5);
                    ctx.lineTo(width - inset, 1.5);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.21);
                    ctx.stroke();
                }
                return;
            }

            root._cardPath(ctx, width, height);
            ctx.fillStyle = fill;
            ctx.fill();

            if (mode === 1) {
                // Vertical sheen baked into the blur source so the blur smears
                // it into a soft glass gradient rather than a flat tint.
                const g = ctx.createLinearGradient(0, 0, 0, height);
                g.addColorStop(0.0, Qt.rgba(1, 1, 1, 0.10));
                g.addColorStop(0.35, Qt.rgba(1, 1, 1, 0.025));
                g.addColorStop(1.0, Qt.rgba(0, 0, 0, 0.06));
                ctx.fillStyle = g;
                ctx.fill();
            }
        }
    }
    Timer {
        id: scrollTicker
        interval: root._tickInterval
        repeat: true
        running: false
        onTriggered: {
            root.scrollTick = (root.scrollTick + 1) & 0x7fffffff;
            // Self-disable: once no phase is still animating, stop the timer so
            // we do not keep repainting canvases (and burning CPU) between updates.
            if (!root._anyAnimatingNow())
                scrollTicker.stop();
        }
    }

    onHistoriesChanged: {
        _pingInterval = _measureInterval(_pingPhaseStart, _pingInterval, 200, 30000);
        _pingPhaseStart = Date.now();
        _ensureScrollTicker();
    }
    onDlHistoryChanged: {
        _netInterval = _measureInterval(_netPhaseStart, _netInterval, 200, 8000);
        _netPhaseStart = Date.now();
        _ensureScrollTicker();
    }
    onCpuHistoryChanged: {
        _cpuInterval = _measureInterval(_cpuPhaseStart, _cpuInterval, 200, 8000);
        _cpuPhaseStart = Date.now();
        _ensureScrollTicker();
    }
    onMemHistoryChanged: {
        _memInterval = _measureInterval(_memPhaseStart, _memInterval, 400, 16000);
        _memPhaseStart = Date.now();
        _ensureScrollTicker();
    }
    onCustomHistoryChanged: {
        _custInterval = _measureInterval(_custPhaseStart, _custInterval, 200, 120000);
        _custPhaseStart = Date.now();
        _ensureScrollTicker();
    }
    onGpuHistoryChanged: {
        _gpuInterval = _measureInterval(_gpuPhaseStart, _gpuInterval, 400, 16000);
        _gpuPhaseStart = Date.now();
        _ensureScrollTicker();
    }

    function restartDiskScroll() {
        _dskInterval = _measureInterval(_dskPhaseStart, _dskInterval, 200, 8000);
        _dskPhaseStart = Date.now();
        _ensureScrollTicker();
    }

    // ── ping state ────────────────────────────────────────────────────────────
    readonly property var targetList: {
        const raw = plasmoid.configuration.targets || "8.8.8.8";
        return raw.split(",").map(s => s.trim()).filter(s => s.length > 0);
    }
    readonly property int activeTarget: Math.max(0, Math.min(plasmoid.configuration.currentTargetIndex, targetList.length - 1))

    property var histories: []
    property real lastPing: -1
    property real avgPing: 0
    property real jitter: 0
    property real lossPercent: 0
    property bool isAlerting: false
    property bool isPinging: false
    property real lastPingTimestamp: 0

    Component.onCompleted: {
        rebuildHistories();
        triggerPing();
    }
    onTargetListChanged: rebuildHistories()

    function rebuildHistories() {
        const h = [];
        for (let i = 0; i < targetList.length; i++)
            h.push(histories[i] || []);
        histories = h;
    }

    P5Support.DataSource {
        id: pingSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isPinging = false;
            pingSource.disconnectSource(sourceName);
            // Support both "time=X" (IPv4) and "time X" (ping6 on some systems)
            const m = (data["stdout"] || "").match(/time[<=\s](\d+(?:[.,]\d+)?)/);
            const ms = m ? parseFloat(m[1].replace(",", ".")) : -1;
            root.lastPingTimestamp = Date.now();
            root.addPingResult(root.activeTarget, ms);
        }
    }

    Timer {
        interval: Math.max(1, plasmoid.configuration.pingInterval) * 1000
        running: root.showPingSection
        repeat: true
        onTriggered: root.triggerPing()
    }

    function triggerPing() {
        if (!root.showPingSection || isPinging || targetList.length === 0)
            return;
        const host = targetList[activeTarget];
        if (!host)
            return;
        isPinging = true;
        // Detect IPv6 address or bracketed IPv6 and use ping6 if available, else ping with -6
        const isIPv6 = host.indexOf(":") !== -1;
        const cmd = isIPv6 ? "ping6 -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host + " 2>/dev/null || ping -6 -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host : "ping -c 1 -W " + plasmoid.configuration.pingTimeout + " " + host;
        pingSource.connectSource(cmd);
    }

    function addPingResult(idx, ms) {
        const maxH = Math.max(10, plasmoid.configuration.historySize);
        if (idx < 0 || idx >= histories.length)
            return;
        const h = histories[idx].slice();
        h.push(ms);
        if (h.length > maxH + 1)
            h.splice(0, h.length - (maxH + 1));
        const newH = histories.slice();
        newH[idx] = h;
        histories = newH;
        if (idx !== activeTarget)
            return;
        lastPing = ms;
        const valid = h.filter(v => v >= 0);
        if (valid.length >= 1)
            avgPing = valid.reduce((a, b) => a + b, 0) / valid.length;
        if (valid.length >= 2) {
            const avg = valid.reduce((a, b) => a + b, 0) / valid.length;
            jitter = Math.sqrt(valid.reduce((s, v) => s + (v - avg) * (v - avg), 0) / valid.length);
        } else {
            jitter = 0;
        }
        lossPercent = h.length > 0 ? (h.filter(v => v < 0).length / h.length) * 100 : 0;
        isAlerting = (ms >= 0 && ms > plasmoid.configuration.latencyThreshold) || lossPercent > plasmoid.configuration.lossThreshold;
    }

    onActiveTargetChanged: {
        const h = histories[activeTarget] || [];
        const valid = h.filter(v => v >= 0);
        lastPing = h.length > 0 ? h[h.length - 1] : -1;
        if (valid.length >= 1)
            avgPing = valid.reduce((a, b) => a + b, 0) / valid.length;
        if (valid.length >= 2) {
            const avg = valid.reduce((a, b) => a + b, 0) / valid.length;
            jitter = Math.sqrt(valid.reduce((s, v) => s + (v - avg) * (v - avg), 0) / valid.length);
        } else {
            jitter = 0;
        }
        lossPercent = h.length > 0 ? (h.filter(v => v < 0).length / h.length) * 100 : 0;
        isAlerting = (lastPing >= 0 && lastPing > plasmoid.configuration.latencyThreshold) || lossPercent > plasmoid.configuration.lossThreshold;
        triggerPing();
    }

    // ── network state ─────────────────────────────────────────────────────────
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var dlHistory: []
    property var ulHistory: []
    property var lastNetBytes: null
    property string activeIface: ""
    property var availableIfaces: ["auto"]
    property bool isReadingNet: false
    property real sessionDlBytes: 0
    property real sessionUlBytes: 0

    P5Support.DataSource {
        id: netSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingNet = false;
            netSource.disconnectSource(sourceName);
            root.parseNetStats(data["stdout"] || "");
        }
    }
    Timer {
        interval: root._pollBase
        running: root.showNetworkSpeed
        repeat: true
        onTriggered: {
            if (!root.isReadingNet) {
                root.isReadingNet = true;
                netSource.connectSource("cat /proc/net/dev");
            }
        }
    }

    // ── Network identity (SSID / IP) ──────────────────────────────────────────
    // Optional, off by default. Polled infrequently (changes rarely). SSID is the
    // Wi-Fi name when on wireless ("" on wired); ip is the iface's primary IPv4.
    property string netSsid: ""
    property string netIpAddr: ""
    property bool isReadingNetInfo: false

    P5Support.DataSource {
        id: netInfoSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingNetInfo = false;
            netInfoSource.disconnectSource(sourceName);
            root.parseNetInfo(data["stdout"] || "");
        }
    }
    Timer {
        interval: root._pollBase * 8
        running: root.showNetworkSpeed && plasmoid.configuration.netShowInfo
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.isReadingNetInfo || !root.activeIface)
                return;
            root.isReadingNetInfo = true;
            const ifc = root.activeIface;
            // Two lines: line0 = SSID, line1 = primary IPv4.
            // SSID: try each tool and emit the FIRST NON-EMPTY result. We can't use
            // `a || b` because some tools (e.g. `iw link` without privileges) exit 0
            // while printing nothing, which would wrongly short-circuit the chain.
            netInfoSource.connectSource("s=$(iwgetid -r 2>/dev/null); [ -z \"$s\" ] && s=$(iw dev " + ifc + " link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p'); [ -z \"$s\" ] && s=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1); echo \"$s\"; ip -o -4 addr show dev " + ifc + " scope global 2>/dev/null | awk '{print $4}' | head -1");
        }
    }
    function parseNetInfo(text) {
        const lines = text.split("\n");
        root.netSsid = (lines[0] || "").trim();
        const ip = (lines[1] || "").trim();
        root.netIpAddr = ip.split("/")[0];   // strip CIDR suffix
    }

    function parseNetStats(text) {
        const cfgIface = plasmoid.configuration.networkInterface || "auto";
        let bestIface = "", bestRx = -1;
        const ifaceData = {};
        const foundIfaces = ["auto"];
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\w+):\s+(\d+)(?:\s+\d+){7}\s+(\d+)/);
            if (!m || m[1] === "lo")
                continue;
            ifaceData[m[1]] = {
                rx: parseInt(m[2]),
                tx: parseInt(m[3])
            };
            foundIfaces.push(m[1]);
            if (ifaceData[m[1]].rx > bestRx) {
                bestRx = ifaceData[m[1]].rx;
                bestIface = m[1];
            }
        }

        // Only update property if array changed (to avoid unnecessary re-renders)
        if (root.availableIfaces.length !== foundIfaces.length || !root.availableIfaces.every((val, index) => val === foundIfaces[index])) {
            root.availableIfaces = foundIfaces;
        }

        const iface = (cfgIface !== "auto" && ifaceData[cfgIface]) ? cfgIface : bestIface;
        if (!iface || !ifaceData[iface])
            return;
        const now = Date.now(), {
            rx,
            tx
        } = ifaceData[iface];
        if (lastNetBytes && lastNetBytes.iface === iface) {
            const dt = (now - lastNetBytes.time) / 1000;
            if (dt > 0.1) {
                downloadSpeed = Math.max(0, (rx - lastNetBytes.rx) / dt);
                uploadSpeed = Math.max(0, (tx - lastNetBytes.tx) / dt);
                sessionDlBytes += downloadSpeed * dt;
                sessionUlBytes += uploadSpeed * dt;
                const maxH = Math.max(10, plasmoid.configuration.historySize);
                const nd = dlHistory.slice();
                nd.push(downloadSpeed);
                if (nd.length > maxH + 1)
                    nd.splice(0, nd.length - (maxH + 1));
                dlHistory = nd;
                const nu = ulHistory.slice();
                nu.push(uploadSpeed);
                if (nu.length > maxH + 1)
                    nu.splice(0, nu.length - (maxH + 1));
                ulHistory = nu;
            }
        }
        lastNetBytes = {
            iface,
            rx,
            tx,
            time: now
        };
        activeIface = iface;
    }

    // ── CPU state ─────────────────────────────────────────────────────────────
    property real cpuPercent: 0
    property var cpuHistory: []
    property var corePercents: []
    property var coreHistories: []
    property var lastCpuStats: null
    property bool isReadingCpu: false

    P5Support.DataSource {
        id: cpuSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingCpu = false;
            cpuSource.disconnectSource(sourceName);
            root.parseCpuStats(data["stdout"] || "");
        }
    }
    Timer {
        interval: root._pollBase
        running: root.showCpuSection
        repeat: true
        onTriggered: {
            if (!root.isReadingCpu) {
                root.isReadingCpu = true;
                cpuSource.connectSource("cat /proc/stat");
            }
        }
    }

    function parseCpuStats(text) {
        const stats = {
            total: null,
            cores: []
        };
        for (const line of text.split("\n")) {
            const m = line.match(/^(cpu\d*)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (!m)
                continue;
            const user = parseInt(m[2]), nice = parseInt(m[3]), sys = parseInt(m[4]), idle = parseInt(m[5]);
            const iow = parseInt(m[6]), irq = parseInt(m[7]), sirq = parseInt(m[8]);
            const active = user + nice + sys + irq + sirq, total = active + idle + iow;
            if (m[1] === "cpu")
                stats.total = {
                    active,
                    total
                };
            else
                stats.cores.push({
                    active,
                    total
                });
        }
        if (!stats.total)
            return;
        if (lastCpuStats?.total) {
            const dt = stats.total.total - lastCpuStats.total.total;
            const da = stats.total.active - lastCpuStats.total.active;
            if (dt > 0)
                cpuPercent = Math.min(100, Math.max(0, da / dt * 100));
            const newCP = [];
            for (let i = 0; i < stats.cores.length; i++) {
                const prev = lastCpuStats.cores[i];
                if (!prev) {
                    newCP.push(0);
                    continue;
                }
                const cdt = stats.cores[i].total - prev.total, cda = stats.cores[i].active - prev.active;
                newCP.push(cdt > 0 ? Math.min(100, Math.max(0, cda / cdt * 100)) : 0);
            }
            corePercents = newCP;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const nh = cpuHistory.slice();
            nh.push(cpuPercent);
            if (nh.length > maxH + 1)
                nh.splice(0, nh.length - (maxH + 1));
            cpuHistory = nh;
            let ch = coreHistories.length === newCP.length ? coreHistories.map(h => h.slice()) : newCP.map(() => []);
            for (let i = 0; i < newCP.length; i++) {
                ch[i].push(newCP[i]);
                if (ch[i].length > maxH + 1)
                    ch[i].splice(0, ch[i].length - (maxH + 1));
            }
            coreHistories = ch;
        }
        lastCpuStats = stats;
    }

    // ── memory state ──────────────────────────────────────────────────────────
    property real memPercent: 0
    property real swapPercent: 0
    property var memHistory: []
    property var swapHistory: []
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real swapUsedGiB: 0
    property bool hasSwap: false
    property bool isReadingMem: false

    P5Support.DataSource {
        id: memSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingMem = false;
            memSource.disconnectSource(sourceName);
            root.parseMemStats(data["stdout"] || "");
        }
    }
    Timer {
        interval: root._pollBase * 2
        running: root.showMemorySection
        repeat: true
        onTriggered: {
            if (!root.isReadingMem) {
                root.isReadingMem = true;
                memSource.connectSource("cat /proc/meminfo");
            }
        }
    }

    function parseMemStats(text) {
        const v = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                v[m[1]] = parseInt(m[2]);
        }
        const total = v["MemTotal"] || 0, avail = v["MemAvailable"] || 0;
        const swapTot = v["SwapTotal"] || 0, swapFree = v["SwapFree"] || 0;
        if (total > 0) {
            const used = total - avail;
            memPercent = used / total * 100;
            memUsedGiB = used / 1048576;
            memTotalGiB = total / 1048576;
        }
        hasSwap = swapTot > 0;
        if (hasSwap) {
            swapPercent = (swapTot - swapFree) / swapTot * 100;
            swapUsedGiB = (swapTot - swapFree) / 1048576;
        }
        const maxH = Math.max(10, plasmoid.configuration.historySize);
        const nm = memHistory.slice();
        nm.push(memPercent);
        if (nm.length > maxH + 1)
            nm.splice(0, nm.length - (maxH + 1));
        memHistory = nm;
        const ns = swapHistory.slice();
        ns.push(swapPercent);
        if (ns.length > maxH + 1)
            ns.splice(0, ns.length - (maxH + 1));
        swapHistory = ns;
    }

    // ── disk state (written by DiskSection, read by CompactRepresentation) ───────
    property real diskReadSpeed: 0
    property real diskWriteSpeed: 0
    readonly property color diskRdColor: Qt.color(plasmoid.configuration.diskRdColor || "#22ddff")
    readonly property color diskWrColor: Qt.color(plasmoid.configuration.diskWrColor || "#ffaa22")

    // ── custom command state ──────────────────────────────────────────────────
    property real customValue: 0
    property var customHistory: []
    property bool isReadingCustom: false

    P5Support.DataSource {
        id: customSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingCustom = false;
            customSource.disconnectSource(sourceName);
            const val = parseFloat((data["stdout"] || "").trim());
            if (!isNaN(val)) {
                root.customValue = val;
                const maxH = Math.max(10, plasmoid.configuration.historySize);
                const nh = root.customHistory.slice();
                nh.push(val);
                if (nh.length > maxH + 1)
                    nh.splice(0, nh.length - (maxH + 1));
                root.customHistory = nh;
            }
        }
    }
    Timer {
        interval: Math.max(1, plasmoid.configuration.customCmdInterval) * 1000
        running: root.showCustomSection && root.visible
        repeat: true
        onTriggered: {
            if (!root.isReadingCustom && plasmoid.configuration.customCmd) {
                root.isReadingCustom = true;
                // Run through an explicit shell so pipes, redirections and
                // shell builtins behave the same regardless of how the
                // executable engine decides to split the string.
                customSource.connectSource("sh -c '" + plasmoid.configuration.customCmd.replace(/'/g, "'\\''") + "'");
            }
        }
    }

    // ── GPU state ─────────────────────────────────────────────────────────────
    // gpuMode: "nvidia" | "amd" | "intel" | "fdinfo" | "none"
    property string gpuMode: ""
    property string gpuVendor: ""   // "nvidia" | "amd" | "intel" | ""
    property real gpuPercent: 0
    property int gpuFreqMhz: 0
    property var gpuHistory: []
    property int gpuNoDataTicks: 0
    property bool isReadingGpu: false
    property bool gpuDetected: false

    // Per-engine + VRAM breakdown (best-effort, vendor-gated). A value < 0 means
    // "this backend can't report it" → the UI hides that row. Engine values are
    // utilisation percentages (0..100); VRAM is in bytes.
    property real gpuEncPercent: -1   // video ENCODE engine util %
    property real gpuDecPercent: -1   // video DECODE (and enhance) engine util %
    property real gpuComputePercent: -1   // render / 3D / compute engine util %
    property real gpuVramUsed: -1     // bytes
    property real gpuVramTotal: -1    // bytes
    // fdinfo engines report cumulative nanoseconds; we diff against the last poll.
    property var _gpuLastEngineNs: null   // { render, compute, video, enhance, copy, t }
    // sysfs dir of the detected card, e.g. "/sys/class/drm/card1". Discovered at
    // detection time so we never hardcode a card index. Only ever assigned a value
    // matching /sys/class/drm/cardN, so it is safe to interpolate into a command.
    property string gpuCardPath: ""
    // Shell helper prepended to the sysfs poll commands: prints exactly one line
    // per file, empty when the file is missing. Plain `cat file; echo` would emit
    // a *blank* line after each value (sysfs files already end in a newline) and
    // shift every field the parser reads by one.
    readonly property string _gpuReadFn: "r() { v=$(cat \"$1\" 2>/dev/null); echo \"$v\"; }; "
    // PCI address of the card being polled, e.g. "0000:03:00.0". Validated before
    // use, since it is interpolated into the nvidia-smi query.
    property string gpuPciId: ""
    // Every GPU the sysfs walk found: [{ card, vendorId, pci, hasTelemetry }].
    property var gpuDevices: []

    readonly property color gpuColor: Qt.color(plasmoid.configuration.gpuColor || "#ff6e40")

    // Enumerates every DRM card: "cardN|vendorId|pciAddress|hasTelemetry".
    // hasTelemetry marks cards exposing a real counter (AMD gpu_busy_percent or
    // Intel gt/gt0), which is what "auto" prefers — a powered-down iGPU has none,
    // so it no longer wins just by sorting first.
    readonly property string _gpuEnumCmd: "sh -c 'for d in /sys/class/drm/card[0-9]*; do v=$(cat \"$d/device/vendor\" 2>/dev/null); [ -n \"$v\" ] || continue; p=$(readlink -f \"$d/device\" 2>/dev/null); p=${p##*/}; b=0; [ -r \"$d/device/gpu_busy_percent\" ] && b=1; [ -d \"$d/gt/gt0\" ] && b=1; echo \"${d##*/}|$v|$p|$b\"; done'"

    // Picks the card to monitor out of the enumeration output, honouring the
    // gpuDevice setting, then selects the backend for its vendor.
    function _chooseGpu(out) {
        const devs = [];
        for (const line of out.split("\n")) {
            const p = line.trim().split("|");
            if (p.length < 4 || !/^card\d+$/.test(p[0]))
                continue;
            devs.push({
                card: p[0],
                vendorId: p[1],
                pci: p[2],
                hasTelemetry: p[3] === "1"
            });
        }
        root.gpuDevices = devs;
        if (devs.length === 0)
            return;

        // The setting stores a PCI address, but accept a plain "cardN" too —
        // the config field is free-text, so people can type either.
        const want = root.gpuDeviceCfg.trim();
        let pick = null;
        if (want !== "" && want.toLowerCase() !== "auto") {
            const w = want.toLowerCase();
            pick = devs.find(d => d.pci.toLowerCase() === w || d.card.toLowerCase() === w) || null;
        }
        // Auto, or the chosen card is gone (eGPU unplugged, renamed, typo).
        if (!pick)
            pick = devs.find(d => d.hasTelemetry) || devs[0];

        root.gpuCardPath = "/sys/class/drm/" + pick.card;
        root.gpuPciId = /^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.\d$/.test(pick.pci) ? pick.pci : "";
        root.gpuDetected = true;

        // vendor id: 0x8086=Intel, 0x1002=AMD, 0x10de=NVIDIA
        if (pick.vendorId === "0x8086") {
            root.gpuVendor = "intel";
            root.gpuMode = "intel";
        } else if (pick.vendorId === "0x1002") {
            root.gpuVendor = "amd";
            root.gpuMode = "amd";
        } else if (pick.vendorId === "0x10de") {
            root.gpuVendor = "nvidia";
            // fdinfo works without the proprietary driver; upgrade to nvidia-smi
            // only if it answers for this specific card.
            root.gpuMode = "fdinfo";
            gpuDetectSource.connectSource("sh -c 'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits" + root._nvidiaTarget() + " 2>/dev/null | head -1'");
        } else {
            root.gpuVendor = "";
            root.gpuMode = "fdinfo";
        }
    }

    // "-i <pci>" so multi-GPU NVIDIA boxes query the selected card, not GPU 0.
    function _nvidiaTarget() {
        return root.gpuPciId ? " -i " + root.gpuPciId : "";
    }

    function detectGpu() {
        root.gpuDetected = false;
        root.gpuMode = "";
        root.gpuVendor = "";
        root.gpuCardPath = "";
        root.gpuPciId = "";
        root.gpuNoDataTicks = 0;
        // Drop the previous card's readings, so switching devices does not leave
        // a graph mixing two GPUs' history.
        root.gpuPercent = 0;
        root.gpuHistory = [];
        root.gpuFreqMhz = 0;
        root.gpuComputePercent = -1;
        root.gpuDecPercent = -1;
        root.gpuEncPercent = -1;
        root.gpuVramUsed = -1;
        root.gpuVramTotal = -1;
        root._gpuLastEngineNs = null;
        root._gpuLastRc6Ms = -1;
        gpuDetectSource.connectSource(root._gpuEnumCmd);
    }

    // Detect GPU backend on startup, and again whenever the device setting changes
    P5Support.DataSource {
        id: gpuDetectSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            gpuDetectSource.disconnectSource(sourceName);
            const out = (data["stdout"] || "").trim();
            if (sourceName.indexOf("nvidia-smi") !== -1) {
                // Probe answer for a card already known to be NVIDIA.
                if (out.length > 0 && !isNaN(parseFloat(out)))
                    root.gpuMode = "nvidia";
            } else if (sourceName.indexOf("drm/card") !== -1) {
                root._chooseGpu(out);
            }
        }
    }

    // plasmoid.configuration is a property map: it drives bindings but emits no
    // per-key change signal, so mirror the setting and re-detect when it moves.
    readonly property string gpuDeviceCfg: plasmoid.configuration.gpuDevice || "auto"
    onGpuDeviceCfgChanged: {
        if (root.showGpuSection)
            root.detectGpu();
    }

    P5Support.DataSource {
        id: gpuSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingGpu = false;
            gpuSource.disconnectSource(sourceName);
            root.parseGpuData(sourceName, data["stdout"] || "");
        }
    }

    Timer {
        id: gpuDetectTimer
        interval: 200
        repeat: false
        running: root.showGpuSection
        onTriggered: root.detectGpu()
    }

    Timer {
        interval: root._pollBase * 2
        running: root.showGpuSection
        repeat: true
        onTriggered: {
            if (!root.isReadingGpu && root.gpuMode !== "") {
                root.isReadingGpu = true;
                if (root.gpuMode === "nvidia") {
                    // util, freq, encode%, decode%, vram used (MiB), vram total (MiB)
                    gpuSource.connectSource("sh -c 'nvidia-smi --query-gpu=utilization.gpu,clocks.current.graphics,utilization.encoder,utilization.decoder,memory.used,memory.total --format=csv,noheader,nounits" + root._nvidiaTarget() + " 2>/dev/null'");
                } else if (root.gpuMode === "amd") {
                    // busy% + VRAM used/total from sysfs, then the fdinfo block.
                    // gpu_busy_percent is absent on RDNA4 (RX 9000), so that line can
                    // come back empty and the fdinfo engines are the fallback — but we
                    // always read both, since sysfs has no per-engine breakdown.
                    gpuSource.connectSource("sh -c '" + root._gpuReadFn + "c=" + root.gpuCardPath + "/device; r \"$c/gpu_busy_percent\"; r \"$c/mem_info_vram_used\"; r \"$c/mem_info_vram_total\"; echo \"---ENG---\"; grep -rhE \"drm-(pdev|engine|resident)\" /proc/*/fdinfo/ 2>/dev/null'");
                } else if (root.gpuMode === "intel") {
                    // Intel: rc6_residency_ms delta → busy %, plus current freq, plus
                    // per-engine ns sums + memory from fdinfo (one combined read).
                    gpuSource.connectSource("sh -c '" + root._gpuReadFn + "g=" + root.gpuCardPath + "/gt/gt0; r \"$g/rc6_residency_ms\"; r \"$g/rps_cur_freq_mhz\"; r \"$g/rps_act_freq_mhz\"; echo \"---ENG---\"; grep -rhE \"drm-(pdev|engine|resident)\" /proc/*/fdinfo/ 2>/dev/null'");
                } else {
                    // fdinfo: sum each engine's cumulative ns across all processes, plus
                    // resident memory. Render≈compute/3D, video≈decode, video-enhance≈encode.
                    gpuSource.connectSource("sh -c 'grep -rhE \"drm-(pdev|engine|resident)\" /proc/*/fdinfo/ 2>/dev/null'");
                }
            } else if (!root.isReadingGpu && root.gpuMode === "" && root.gpuNoDataTicks < 2) {
                // Vendor detection came back empty (unknown vendor id, or sysfs not
                // readable). Give fdinfo a shot anyway rather than staying silent.
                root.gpuNoDataTicks++;
                if (root.gpuNoDataTicks >= 2)
                    root.gpuMode = "fdinfo";
            } else {
                root.isReadingGpu = false;
            }
        }
    }

    property real _gpuLastRc6Ms: -1
    property real _gpuLastPollMs: 0

    // Parse the fdinfo block (the lines after "---ENG---" for intel, or the whole
    // body for the generic fdinfo path). Sums each engine's cumulative nanoseconds
    // and resident memory across every process, then diffs the ns against the last
    // poll to derive a per-engine utilisation %. Updates gpuComputePercent /
    // gpuDecPercent / gpuEncPercent / gpuVramUsed. Returns the busy% of the
    // graphics/compute rings, whichever is higher (or -1 when unavailable).
    function _parseFdinfoEngines(lines) {
        let render = 0, compute = 0, video = 0, enhance = 0, copy = 0, resident = 0;
        let sawEngine = false;
        // grep concatenates the per-process records in order, and drm-pdev always
        // precedes that record's counters — so tracking the most recent one lets
        // us bill each block to its card and ignore the other GPUs. A record with
        // no drm-pdev at all is counted, rather than silently dropped.
        const wantPci = root.gpuPciId;
        let curPdev = "";
        for (const line of lines) {
            const pd = line.match(/^drm-pdev:\s*(\S+)/);
            if (pd) {
                curPdev = pd[1];
                continue;
            }
            if (wantPci !== "" && curPdev !== "" && curPdev !== wantPci)
                continue;
            const m = line.match(/^drm-(engine|resident)-([^:\s]+):\s*(\d+)\s*(\S*)/);
            if (!m)
                continue;
            const val = parseInt(m[3]);
            if (m[1] === "engine") {
                sawEngine = true;
                // Engine names differ per driver: i915 uses render/video/…, amdgpu
                // uses gfx/compute/dec/enc/… and xe uses rcs/ccs/vcs/…. Note that
                // "drm-engine-capacity-*" lands in none of these buckets, as it
                // is a count rather than a nanosecond counter.
                const name = m[2];
                if (name === "render" || name === "gfx" || name === "rcs")
                    render += val;
                else if (name === "compute" || name === "ccs")
                    compute += val;
                else if (name === "video" || name === "dec" || name === "vcs")
                    video += val;
                else if (name === "video-enhance" || name === "enc" || name === "enc_1" || name === "vecs")
                    enhance += val;
                else if (name === "copy" || name === "dma" || name === "bcs")
                    copy += val;
            } else {
                // drm-resident-<region>: <uint> [KiB|MiB] — bytes when unitless.
                const unit = m[4];
                resident += unit === "KiB" ? val * 1024 : unit === "MiB" ? val * 1048576 : val;
            }
        }
        if (resident > 0)
            root.gpuVramUsed = resident;
        if (!sawEngine)
            return -1;

        const now = Date.now();
        const prev = root._gpuLastEngineNs;
        let busyPct = -1;
        if (prev && prev.t > 0) {
            const dtNs = (now - prev.t) * 1e6;   // ms → ns
            if (dtNs > 0) {
                const pct = function (cur, old) {
                    return Math.min(100, Math.max(0, ((cur - old) / dtNs) * 100));
                };
                // Graphics and compute are separate rings; a pure compute load
                // (ROCm/CUDA) never touches gfx, so the busier of the two is what
                // "the GPU is doing something" actually means.
                busyPct = Math.max(pct(render, prev.render), pct(compute, prev.compute));
                root.gpuComputePercent = busyPct;
                // "video" is decode-side; "video-enhance" is the encode/post pipe.
                root.gpuDecPercent = pct(video, prev.video);
                root.gpuEncPercent = pct(enhance, prev.enhance);
            }
        }
        root._gpuLastEngineNs = {
            render,
            compute,
            video,
            enhance,
            copy,
            t: now
        };
        return busyPct;
    }

    function parseGpuData(src, text) {
        // Split before trimming: a missing sysfs file yields an empty line, and
        // trimming the whole blob first would swallow it and shift every
        // subsequent line up by one.
        const lines = text.split("\n").map(s => s.trim());
        const maxH = Math.max(10, plasmoid.configuration.historySize);

        if (root.gpuMode === "nvidia") {
            // "util, freq, enc%, dec%, vramUsedMiB, vramTotalMiB" (one GPU)
            const parts = (lines[0] || "").split(",").map(s => parseFloat(s));
            const util = parts[0], freq = parts[1], enc = parts[2], dec = parts[3];
            const vu = parts[4], vt = parts[5];
            if (!isNaN(util))
                root.gpuPercent = Math.min(100, Math.max(0, util));
            if (!isNaN(freq))
                root.gpuFreqMhz = freq;
            if (!isNaN(enc))
                root.gpuEncPercent = Math.min(100, Math.max(0, enc));
            if (!isNaN(dec))
                root.gpuDecPercent = Math.min(100, Math.max(0, dec));
            if (!isNaN(vu))
                root.gpuVramUsed = vu * 1048576;   // MiB → bytes
            if (!isNaN(vt))
                root.gpuVramTotal = vt * 1048576;
            root.gpuNoDataTicks = 0;
        } else if (root.gpuMode === "amd") {
            // line0: busy%, line1: vram used (bytes), line2: vram total (bytes),
            // then "---ENG---" followed by the fdinfo block.
            const v = parseInt(lines[0]);
            const vu = parseInt(lines[1]);
            const vt = parseInt(lines[2]);
            if (!isNaN(vt) && vt > 0)
                root.gpuVramTotal = vt;
            // Per-engine breakdown first: on RDNA4 it also supplies the overall
            // busy%, since gpu_busy_percent was dropped there.
            const engIdx = lines.indexOf("---ENG---");
            const enginePct = engIdx !== -1 ? root._parseFdinfoEngines(lines.slice(engIdx + 1)) : -1;
            // sysfs reports the real hardware busy%, so prefer it when present;
            // the fdinfo delta only sees engine time booked to a process.
            if (!isNaN(v)) {
                root.gpuPercent = Math.min(100, Math.max(0, v));
                root.gpuNoDataTicks = 0;
            } else if (enginePct >= 0) {
                root.gpuPercent = enginePct;
                root.gpuNoDataTicks = 0;
            } else
                root.gpuNoDataTicks++;
            // mem_info_vram_used is authoritative; overwrite whatever the fdinfo
            // resident sum guessed.
            if (!isNaN(vu))
                root.gpuVramUsed = vu;
        } else if (root.gpuMode === "intel") {
            // line0: rc6_residency_ms, line1: rps_cur_freq_mhz, line2: rps_act_freq_mhz,
            // then "---ENG---" followed by the fdinfo block.
            const rc6Now = parseFloat(lines[0]);
            const cur = parseInt(lines[1]);
            const act = parseInt(lines[2]);
            const now = Date.now();
            if (!isNaN(cur))
                root.gpuFreqMhz = isNaN(act) || act === 0 ? cur : act;
            if (!isNaN(rc6Now) && root._gpuLastRc6Ms >= 0 && root._gpuLastPollMs > 0) {
                const dtMs = now - root._gpuLastPollMs;
                const dRc6 = rc6Now - root._gpuLastRc6Ms;
                // rc6 = idle residency → busy = 1 - (dRc6 / dtMs), clamped
                const busy = Math.min(100, Math.max(0, (1.0 - dRc6 / dtMs) * 100));
                root.gpuPercent = busy;
                root.gpuNoDataTicks = 0;
            }
            root._gpuLastRc6Ms = rc6Now;
            root._gpuLastPollMs = now;
            // per-engine breakdown from the fdinfo block after the marker
            const engIdx = lines.indexOf("---ENG---");
            if (engIdx !== -1)
                root._parseFdinfoEngines(lines.slice(engIdx + 1));
        } else {
            // Generic fdinfo path: derive overall busy% from the render engine delta,
            // and fill the per-engine breakdown.
            const renderPct = root._parseFdinfoEngines(lines);
            if (renderPct >= 0) {
                root.gpuPercent = renderPct;
                root.gpuNoDataTicks = 0;
            } else
                root.gpuNoDataTicks++;
        }

        const nh = root.gpuHistory.slice();
        nh.push(root.gpuPercent);
        if (nh.length > maxH + 1)
            nh.splice(0, nh.length - (maxH + 1));
        root.gpuHistory = nh;
    }

    // ── Hardware Sensors state ────────────────────────────────────────────────
    // Flat ListModel of rows (header + sensor). A stable ListModel (rather
    // than a JS array we reassign every 3s) keeps delegates alive across
    // refreshes — so `Behavior on width` animates from previous width to
    // the new one, instead of recreating delegates that snap to 0.
    ListModel {
        id: hwSensorRowsModel
        dynamicRoles: true
    }
    property alias hwSensorRows: hwSensorRowsModel
    property bool isReadingHwSensors: false
    property real hwMaxTemp: 0
    property real hwMaxTempCrit: 0

    P5Support.DataSource {
        id: hwSensorsSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingHwSensors = false;
            hwSensorsSource.disconnectSource(sourceName);
            root.applyHwSensorUpdate(root.parseHwSensorsJson(data["stdout"] || ""));
        }
    }

    Timer {
        interval: root._pollBase * 3
        running: root.showHwSensors && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.isReadingHwSensors) {
                root.isReadingHwSensors = true;
                hwSensorsSource.connectSource("sensors -j 2>/dev/null");
            }
        }
    }

    function friendlyChipName(n) {
        const s = n.toLowerCase();
        if (s.startsWith("coretemp"))
            return "CPU (Intel)";
        if (s.startsWith("k10temp"))
            return "CPU (AMD)";
        if (s.startsWith("zenpower"))
            return "CPU (AMD Zen)";
        if (s.startsWith("k8temp"))
            return "CPU (AMD K8)";
        if (s.startsWith("nvme"))
            return "NVMe SSD";
        if (s.startsWith("amdgpu"))
            return "GPU (AMD)";
        if (s.startsWith("nouveau"))
            return "GPU (Nouveau)";
        if (s.startsWith("radeon"))
            return "GPU (Radeon)";
        if (s.startsWith("i915"))
            return "GPU (Intel)";
        if (s.startsWith("acpitz"))
            return "ACPI Thermal";
        if (s.startsWith("iwlwifi"))
            return "Wi-Fi";
        if (s.startsWith("drivetemp"))
            return "Drive";
        if (s.startsWith("hddtemp"))
            return "HDD";
        if (s.startsWith("ucsi"))
            return "USB-PD";
        if (s.startsWith("nct") || s.startsWith("it8") || s.startsWith("w83") || s.startsWith("f71") || s.startsWith("nuvoton"))
            return "Motherboard";
        return n;
    }

    function parseHwSensorsJson(text) {
        if (!text || !text.trim())
            return [];
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return [];
        }
        const groups = [];
        for (const chipKey in data) {
            const chipData = data[chipKey];
            if (typeof chipData !== "object")
                continue;
            const sensors = [];
            const cores = [];
            let maxTemp = 0;
            let maxTempCrit = 0;

            for (const sensorKey in chipData) {
                if (sensorKey === "Adapter")
                    continue;
                const sd = chipData[sensorKey];
                if (typeof sd !== "object")
                    continue;

                for (const key in sd) {
                    if (!key.endsWith("_input"))
                        continue;
                    const prefix = key.slice(0, -6);
                    const value = sd[key];
                    if (typeof value !== "number")
                        break;

                    if (prefix.startsWith("temp")) {
                        const crit = sd[prefix + "_crit"] || sd[prefix + "_max"] || 0;
                        if (value > maxTemp) {
                            maxTemp = value;
                            maxTempCrit = crit;
                        }
                        if (/^Core \d+/.test(sensorKey)) {
                            cores.push({
                                label: sensorKey,
                                value: value,
                                crit: crit
                            });
                        } else {
                            let label = sensorKey;
                            if (/^Package id/.test(label))
                                label = "Package";
                            sensors.push({
                                label: label,
                                value: value,
                                crit: crit,
                                type: 'temp'
                            });
                        }
                        break;
                    } else if (prefix.startsWith("fan")) {
                        if (value > 0)
                            sensors.push({
                                label: sensorKey,
                                value: Math.round(value),
                                type: 'fan'
                            });
                        break;
                    }
                }
            }

            // Aggregate cores when there are multiple
            if (cores.length > 1) {
                const values = cores.map(function (c) {
                    return c.value;
                });
                let sum = 0, mn = values[0], mx = values[0];
                for (let i = 0; i < values.length; i++) {
                    sum += values[i];
                    if (values[i] < mn)
                        mn = values[i];
                    if (values[i] > mx)
                        mx = values[i];
                }
                sensors.push({
                    label: cores.length + " cores",
                    value: sum / values.length,
                    min: mn,
                    max: mx,
                    crit: cores[0].crit,
                    coreValues: values,
                    type: 'cores'
                });
            } else if (cores.length === 1) {
                sensors.push({
                    label: cores[0].label,
                    value: cores[0].value,
                    crit: cores[0].crit,
                    type: 'temp'
                });
            }

            if (sensors.length > 0) {
                groups.push({
                    chip: chipKey,
                    chipDisplay: root.friendlyChipName(chipKey),
                    maxTemp: maxTemp,
                    maxTempCrit: maxTempCrit,
                    sensors: sensors
                });
            }
        }
        return groups;
    }

    // Flatten groups into ListModel rows. If row count + key sequence matches
    // the existing model, update values in place (so delegates persist and
    // bar widths animate smoothly). Otherwise, rebuild from scratch.
    function applyHwSensorUpdate(groups) {
        let globalMaxTemp = 0;
        let globalMaxTempCrit = 0;
        const newRows = [];
        for (let gi = 0; gi < groups.length; gi++) {
            const g = groups[gi];
            if (g.maxTemp > globalMaxTemp) {
                globalMaxTemp = g.maxTemp;
                globalMaxTempCrit = g.maxTempCrit;
            }
            newRows.push({
                rowType: 'header',
                key: 'h:' + g.chip,
                chipDisplay: g.chipDisplay,
                maxTemp: g.maxTemp,
                maxTempCrit: g.maxTempCrit || 0,
                // sensor-row fields filled with defaults so ListModel role
                // schema stays uniform across rows
                label: '',
                value: 0,
                sensorKind: '',
                crit: 0,
                coreMin: 0,
                coreMax: 0,
                coreValues: []
            });
            for (let si = 0; si < g.sensors.length; si++) {
                const s = g.sensors[si];
                newRows.push({
                    rowType: 'sensor',
                    key: 's:' + g.chip + ':' + s.label,
                    chipDisplay: '',
                    maxTemp: 0,
                    maxTempCrit: 0,
                    label: s.label,
                    value: s.value,
                    sensorKind: s.type,
                    crit: s.crit || 0,
                    coreMin: s.min || 0,
                    coreMax: s.max || 0,
                    coreValues: s.coreValues || []
                });
            }
        }

        // Does the existing model have the same row structure?
        let same = (hwSensorRowsModel.count === newRows.length);
        if (same) {
            for (let i = 0; i < newRows.length; i++) {
                if (hwSensorRowsModel.get(i).key !== newRows[i].key) {
                    same = false;
                    break;
                }
            }
        }

        if (same) {
            // In-place update — delegates stay alive, Behavior on width animates
            for (let i = 0; i < newRows.length; i++) {
                const r = newRows[i];
                if (r.rowType === 'header') {
                    hwSensorRowsModel.setProperty(i, 'maxTemp', r.maxTemp);
                    hwSensorRowsModel.setProperty(i, 'maxTempCrit', r.maxTempCrit);
                } else {
                    hwSensorRowsModel.setProperty(i, 'value', r.value);
                    hwSensorRowsModel.setProperty(i, 'coreMin', r.coreMin);
                    hwSensorRowsModel.setProperty(i, 'coreMax', r.coreMax);
                    hwSensorRowsModel.setProperty(i, 'coreValues', r.coreValues);
                }
            }
        } else {
            hwSensorRowsModel.clear();
            for (let i = 0; i < newRows.length; i++)
                hwSensorRowsModel.append(newRows[i]);
        }
        root.hwMaxTemp = globalMaxTemp;
        root.hwMaxTempCrit = globalMaxTempCrit;
    }

    // ── OS Info state ─────────────────────────────────────────────────────────
    property string osDistro: ""
    property string osKernel: ""
    property string osHostname: ""
    property string osUptime: ""

    P5Support.DataSource {
        id: osInfoSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            osInfoSource.disconnectSource(sourceName);
            const lines = (data["stdout"] || "").split('\n');
            root.osDistro = (lines[0] || "").trim() || "Linux";
            root.osKernel = (lines[1] || "").trim();
            root.osHostname = (lines[2] || "").trim();
            root.osUptime = (lines[3] || "").trim();
        }
    }

    Timer {
        interval: root._pollBase * 30
        running: root.showOsInfo && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const cmd = "grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'; " + "uname -r 2>/dev/null; " + "cat /etc/hostname 2>/dev/null || hostname 2>/dev/null; " + "awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);" + "if(d>0)printf \"%dd %dh %dm\\n\",d,h,m;" + "else if(h>0)printf \"%dh %dm\\n\",h,m;" + "else printf \"%dm\\n\",m}' /proc/uptime 2>/dev/null";
            osInfoSource.connectSource(cmd);
        }
    }

    // ── Power & Pressure state ────────────────────────────────────────────────
    property int batteryPercent: 0
    property string batteryStatus: ""
    property bool batteryPresent: false
    // Power draw: signed W. Positive = charging, negative = discharging, 0 = idle/full.
    property real batteryPowerW: 0
    property int batteryCycles: -1            // -1 = unknown
    property real batteryHealthPct: 0         // 0 = unknown
    property real batteryTempC: -999          // -999 = unknown
    property real batteryTimeRemainHours: 0   // 0 = unknown / N/A
    property var batteryPowerHistory: []      // |W| samples for sparkline
    property real cpuPressureAvg10: 0
    property real memPressureAvg10: 0
    property bool isReadingPower: false

    P5Support.DataSource {
        id: powerSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            root.isReadingPower = false;
            powerSource.disconnectSource(sourceName);
            root.parsePowerData(data["stdout"] || "");
        }
    }

    Timer {
        interval: root._pollBase * 5
        running: root.showPowerSection && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.isReadingPower) {
                root.isReadingPower = true;
                const cmd = "for p in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1 " + "/sys/class/power_supply/battery /sys/class/power_supply/BATT; do " + "[ -f $p/capacity ] || continue; " + "echo bat=$(cat $p/capacity 2>/dev/null); " + "echo status=$(cat $p/status 2>/dev/null); " + "[ -f $p/cycle_count ] && echo cycles=$(cat $p/cycle_count 2>/dev/null); " + "[ -f $p/temp ] && echo temp=$(cat $p/temp 2>/dev/null); " + "en=$(cat $p/energy_now 2>/dev/null); " + "ef=$(cat $p/energy_full 2>/dev/null); " + "ed=$(cat $p/energy_full_design 2>/dev/null); " + "if [ -n \"$en\" ]; then echo useEnergy=1; else en=$(cat $p/charge_now 2>/dev/null); ef=$(cat $p/charge_full 2>/dev/null); ed=$(cat $p/charge_full_design 2>/dev/null); echo useEnergy=0; fi; " + "echo enow=${en:-0}; echo efull=${ef:-0}; echo edesign=${ed:-0}; " + "pw=$(cat $p/power_now 2>/dev/null); " + "if [ -z \"$pw\" ]; then v=$(cat $p/voltage_now 2>/dev/null); c=$(cat $p/current_now 2>/dev/null); " + "[ -n \"$v\" ] && [ -n \"$c\" ] && pw=$(awk -v v=\"$v\" -v c=\"$c\" 'BEGIN{printf \"%d\", v*c/1000000}'); fi; " + "echo power=${pw:-0}; break; done; " + "[ -f /proc/pressure/cpu ] && sed 's/^/cpu /' /proc/pressure/cpu 2>/dev/null | head -1; " + "[ -f /proc/pressure/memory ] && sed 's/^/mem /' /proc/pressure/memory 2>/dev/null | head -1";
                powerSource.connectSource(cmd);
            }
        }
    }

    function parsePowerData(text) {
        let bat = -1, status = '', powerUW = 0;
        let cycles = -1, tempDeci = -9999;
        let enow = 0, efull = 0, edesign = 0, useEnergy = false;
        let cpuAvg10 = 0, memAvg10 = 0;

        for (const line of text.split('\n')) {
            const t = line.trim();
            if (t.startsWith('bat=')) {
                const v = parseInt(t.slice(4));
                if (!isNaN(v) && v >= 0)
                    bat = v;
            } else if (t.startsWith('status=')) {
                status = t.slice(7);
            } else if (t.startsWith('cycles=')) {
                const v = parseInt(t.slice(7));
                if (!isNaN(v))
                    cycles = v;
            } else if (t.startsWith('temp=')) {
                const v = parseInt(t.slice(5));
                if (!isNaN(v))
                    tempDeci = v;
            } else if (t.startsWith('enow=')) {
                const v = parseInt(t.slice(5));
                if (!isNaN(v))
                    enow = v;
            } else if (t.startsWith('efull=')) {
                const v = parseInt(t.slice(6));
                if (!isNaN(v))
                    efull = v;
            } else if (t.startsWith('edesign=')) {
                const v = parseInt(t.slice(8));
                if (!isNaN(v))
                    edesign = v;
            } else if (t.startsWith('useEnergy=')) {
                useEnergy = t.slice(10) === '1';
            } else if (t.startsWith('power=')) {
                const v = parseInt(t.slice(6));
                if (!isNaN(v))
                    powerUW = v;
            } else if (t.startsWith('cpu some')) {
                const m = t.match(/avg10=(\d+\.?\d*)/);
                if (m)
                    cpuAvg10 = parseFloat(m[1]);
            } else if (t.startsWith('mem some')) {
                const m = t.match(/avg10=(\d+\.?\d*)/);
                if (m)
                    memAvg10 = parseFloat(m[1]);
            }
        }

        root.batteryPresent = bat >= 0;
        if (bat >= 0)
            root.batteryPercent = bat;
        if (status)
            root.batteryStatus = status;

        // Sign convention: + when charging, - when discharging. sysfs power_now
        // is usually unsigned and we infer direction from status.
        let pw = Math.abs(powerUW) / 1000000.0;
        if (status === 'Discharging')
            pw = -pw;
        else if (status !== 'Charging')
            pw = (status === 'Full' || pw < 0.05) ? 0 : pw;
        root.batteryPowerW = pw;

        // History for sparkline (absolute value)
        const maxH = Math.max(10, plasmoid.configuration.historySize);
        const nh = root.batteryPowerHistory.slice();
        nh.push(Math.abs(pw));
        if (nh.length > maxH + 1)
            nh.splice(0, nh.length - (maxH + 1));
        root.batteryPowerHistory = nh;

        // Diagnostics
        root.batteryCycles = cycles;
        root.batteryTempC = tempDeci > -1000 ? tempDeci / 10.0 : -999;
        root.batteryHealthPct = (edesign > 0 && efull > 0) ? (efull / edesign * 100.0) : 0;

        // Time remaining only when units are µWh and we actually have power flow
        if (useEnergy && Math.abs(powerUW) > 1000 && enow > 0 && efull > 0) {
            if (status === 'Discharging')
                root.batteryTimeRemainHours = enow / Math.abs(powerUW);
            else if (status === 'Charging' && efull > enow)
                root.batteryTimeRemainHours = (efull - enow) / Math.abs(powerUW);
            else
                root.batteryTimeRemainHours = 0;
        } else {
            root.batteryTimeRemainHours = 0;
        }

        root.cpuPressureAvg10 = cpuAvg10;
        root.memPressureAvg10 = memAvg10;
    }

    // ── shared interaction state ──────────────────────────────────────────────
    property string hoveredLine: ""
    property int hoveredCore: -1

    function isLineDisabled(key) {
        return (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean).indexOf(key) !== -1;
    }
    function toggleLineDisabled(key) {
        let arr = (plasmoid.configuration.disabledLinesStr || "").split(",").filter(Boolean);
        if (arr.indexOf(key) !== -1)
            arr = arr.filter(k => k !== key);
        else
            arr.push(key);
        plasmoid.configuration.disabledLinesStr = arr.join(",");
    }
    function isCoreDisabled(idx) {
        return (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean).indexOf(idx.toString()) !== -1;
    }
    function toggleCoreDisabled(idx) {
        let arr = (plasmoid.configuration.disabledCoresStr || "").split(",").filter(Boolean);
        if (arr.indexOf(idx.toString()) !== -1)
            arr = arr.filter(k => k !== idx.toString());
        else
            arr.push(idx.toString());
        plasmoid.configuration.disabledCoresStr = arr.join(",");
    }

    // ── representations ───────────────────────────────────────────────────────
    compactRepresentation: CompactRepresentation {}

    fullRepresentation: Item {
        id: container

        readonly property bool _frosted: plasmoid.configuration.frostedGlass

        // Flat card — the plain translucent fill (frosted glass off).
        CardCanvas {
            mode: 0
            visible: !container._frosted
        }

        // ── frosted-glass card (frostedGlass on) ─────────────────────────────
        // Composite the fill + sheen into one hidden source, blur it on the GPU,
        // then round the result with a mask pass. Plasma exposes no backdrop-blur
        // API to QML, so this frosts the card's OWN fill — a soft premium glass
        // look that is GPU-cheap and doesn't touch the CPU canvas path.
        CardCanvas {
            id: frostSource
            mode: 1
            visible: false
            layer.enabled: container._frosted
        }
        CardCanvas {
            id: frostMask
            mode: 2
            visible: false
            layer.enabled: container._frosted
        }
        MultiEffect {
            anchors.fill: parent
            visible: container._frosted
            source: frostSource
            blurEnabled: true
            blur: plasmoid.configuration.frostStrength
            blurMax: 40
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: frostMask
        }

        // Hairline border + top highlight, drawn last so it stays crisp over
        // the blur. The edge is what reads as "glass".
        CardCanvas {
            mode: 3
            visible: plasmoid.configuration.cardBorder
        }

        // alert pulse ring
        Rectangle {
            id: alertRing
            anchors.fill: parent
            radius: root._radMax
            color: "transparent"
            border.color: root.pingCritColor
            border.width: 2
            visible: root.showPingSection && root.pingAlertActive && plasmoid.configuration.pingAlertPulse
            opacity: 0
            SequentialAnimation {
                running: alertRing.visible
                loops: Animation.Infinite
                NumberAnimation {
                    target: alertRing
                    property: "opacity"
                    from: 0
                    to: 0.75
                    duration: 650
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: alertRing
                    property: "opacity"
                    from: 0.75
                    to: 0
                    duration: 650
                    easing.type: Easing.InOutSine
                }
                onRunningChanged: if (!running)
                    alertRing.opacity = 0
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
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
                        if (root.showPingSection)
                            return plasmoid.configuration.pingTitle || "Ping";
                        if (root.showNetworkSpeed)
                            return plasmoid.configuration.networkTitle || "Network Speed";
                        if (root.showCpuSection)
                            return plasmoid.configuration.cpuTitle || "CPU";
                        if (root.showMemorySection)
                            return plasmoid.configuration.memoryTitle || "Memory";
                        if (root.showDiskSection)
                            return plasmoid.configuration.diskTitle || "Disk I/O";
                        if (root.showGpuSection)
                            return plasmoid.configuration.gpuTitle || "GPU";
                        if (root.showHwSensors)
                            return plasmoid.configuration.hwSensorsTitle || "Hardware Sensors";
                        if (root.showOsInfo)
                            return plasmoid.configuration.osInfoTitle || "System Info";
                        if (root.showPowerSection)
                            return plasmoid.configuration.powerTitle || "Power";
                        return plasmoid.configuration.customCmdTitle || "Custom Sensor";
                    }
                    color: root.textColor
                    font.pixelSize: 15
                    font.bold: true
                    font.letterSpacing: 0.3
                    renderType: Text.NativeRendering
                }

                // Network download total — only shown when Network section is active
                Item {
                    visible: root.showNetworkSpeed
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: netDlTotalRow.implicitWidth
                    implicitHeight: netDlTotalRow.implicitHeight
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
                            font.pixelSize: 11
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Network combined speed and upload total — only shown when Network section is active
                Item {
                    visible: root.showNetworkSpeed
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: netRightRow.implicitWidth
                    implicitHeight: netRightRow.implicitHeight
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
                                font.pixelSize: 13
                                font.bold: true
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
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // GPU total — only shown when GPU section is active
                Item {
                    visible: root.showGpuSection
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: gpuTotalRow.implicitWidth
                    implicitHeight: gpuTotalRow.implicitHeight
                    Row {
                        id: gpuTotalRow
                        spacing: 5
                        Rectangle {
                            width: 9
                            height: 9
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.gpuColor
                            border.color: root.gpuColor
                            border.width: 1
                        }
                        Text {
                            text: root.gpuPercent.toFixed(1) + "%"
                            color: root.gpuColor
                            font.pixelSize: 15
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // CPU total — only shown when CPU section is active
                Item {
                    visible: root.showCpuSection
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: cpuTotalRow.implicitWidth
                    implicitHeight: cpuTotalRow.implicitHeight
                    Row {
                        id: cpuTotalRow
                        spacing: 5
                        Rectangle {
                            width: 9
                            height: 9
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: root.isLineDisabled("cpuTotal") ? "transparent" : root.cpuColor
                            border.color: root.cpuColor
                            border.width: 1
                        }
                        Text {
                            text: root.cpuPercent.toFixed(1) + "%"
                            color: root.isLineDisabled("cpuTotal") ? Qt.rgba(root.cpuColor.r, root.cpuColor.g, root.cpuColor.b, 0.3) : root.cpuColor
                            font.pixelSize: 15
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            root.toggleLineDisabled("cpuTotal");
                        }
                        onEntered: {
                            root.hoveredLine = "cpuTotal";
                        }
                        onExited: {
                            root.hoveredLine = "";
                        }
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
                Layout.fillWidth: true
                height: 1
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
                Layout.fillWidth: true
                height: 1
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
                Layout.fillWidth: true
                height: 1
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
                Layout.fillWidth: true
                height: 1
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
                Layout.fillWidth: true
                height: 1
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
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                visible: root.showGpuSection && (root.showPingSection || root.showNetworkSpeed || root.showCpuSection || root.showMemorySection || root.showDiskSection || root.showCustomSection)
            }

            // gpu
            GpuSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showGpuSection
            }

            // hardware sensors
            HwSensorsSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showHwSensors
            }

            // os info
            OsInfoSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showOsInfo
            }

            // power & pressure
            PowerSection {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.showPowerSection
            }
        }
    }
}
