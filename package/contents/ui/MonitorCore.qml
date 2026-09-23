import QtQuick
import "OsFetch.js" as OsFetch
import "Sections.js" as Sections
import "Format.js" as Format
import "Probes.js" as Probes

// Everything Glassy measures, with no UI and no desktop dependency. Hosts
// supply the configuration (Plasma's KConfig map, or a plain object on
// Hyprland), a command runner, and the theme colours; views read the rest.
Item {
    id: core

    // cfg on Plasma; a plain settings object elsewhere.
    property var cfg: ({})
    // Instantiates an executable DataSource-like runner (see CommandSource).
    property Component commandSourceComponent: null
    // function(key, value): persists a setting the widget itself changes.
    property var writeConfig: function (key, value) {}
    // True while the full view is on screen; chart motion stops otherwise.
    property bool onScreen: false
    // False stops the slow optional polls (sensors, OS info, power, custom).
    property bool active: true
    // False for a core fed by DemoFeeder: no daemon subscription, no commands.
    property bool live: true
    property color systemAccent: "#3daee9"
    property color systemTextColor: "#eff0f1"

    // ── sections ──────────────────────────────────────────────────────────────
    readonly property var sectionIds: Sections.parse(cfg.sections, cfg.activeSection)
    readonly property bool showPingSection: sectionIds.indexOf("ping") !== -1
    readonly property bool showNetworkSpeed: sectionIds.indexOf("network") !== -1
    readonly property bool showCpuSection: sectionIds.indexOf("cpu") !== -1
    readonly property bool showMemorySection: sectionIds.indexOf("memory") !== -1
    readonly property bool showDiskSection: sectionIds.indexOf("disk") !== -1
    readonly property bool showCustomSection: sectionIds.indexOf("custom") !== -1
    readonly property bool showGpuSection: sectionIds.indexOf("gpu") !== -1
    readonly property bool showHwSensors: sectionIds.indexOf("sensors") !== -1
    readonly property bool showOsInfo: sectionIds.indexOf("system") !== -1
    readonly property bool showPowerSection: sectionIds.indexOf("power") !== -1
    readonly property bool showStorage: sectionIds.indexOf("storage") !== -1
    readonly property bool showProcesses: sectionIds.indexOf("processes") !== -1

    function sectionTitle(id) {
        return Sections.title(id, cfg);
    }
    readonly property var percentTicks: Format.PERCENT_TICKS

    // ── colors (pre-resolved, no per-frame allocation) ────────────────────────
    readonly property color accentColor: core.systemAccent
    readonly property color lineColor: cfg.useSystemAccent ? accentColor : Qt.color(cfg.customColor || "#39ff14")
    readonly property color pingColor: Qt.color(cfg.pingColor || "#39ff14")
    readonly property color pingWarnColor: Qt.color(cfg.pingWarnColor || "#ffaa22")
    readonly property color pingCritColor: Qt.color(cfg.pingCritColor || "#ff4444")
    // Alert styling is suppressed entirely when threshold colouring is off, so
    // the ping section stays on the user's own colour no matter the latency.
    readonly property bool pingAlertActive: !!cfg.pingThresholdColors && isAlerting
    readonly property color textColor: Qt.color(Sections.textColor(cfg, core.systemTextColor))
    readonly property color dlColor: Qt.color(cfg.dlColor || "#22aaff")
    readonly property color ulColor: Qt.color(cfg.ulColor || "#ff9933")
    readonly property color cpuColor: Qt.color(cfg.cpuColor || "#44ddaa")
    readonly property color memColor: Qt.color(cfg.memColor || "#aa66ff")
    readonly property color swapColor: Qt.color(cfg.swapColor || "#ff6688")
    readonly property var coreColors: (cfg.coreColorsStr || "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff").split(",")

    SampleClock {
        id: pingClock
        sampleInterval: 1000
        minInterval: 200
        maxInterval: 30000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _pingPhaseStart: pingClock.phaseStart
    readonly property real _pingInterval: pingClock.interval
    readonly property int _pingSampleSerial: pingClock.generation

    function pingScrollPhase() {
        return pingClock.phase();
    }

    SampleClock {
        id: netClock
        sampleInterval: 1000
        minInterval: 200
        maxInterval: 8000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _netPhaseStart: netClock.phaseStart
    readonly property real _netInterval: netClock.interval
    readonly property int _netSampleSerial: netClock.generation

    function netScrollPhase() {
        return netClock.phase();
    }

    SampleClock {
        id: cpuClock
        sampleInterval: 1000
        minInterval: 200
        maxInterval: 8000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _cpuPhaseStart: cpuClock.phaseStart
    readonly property real _cpuInterval: cpuClock.interval
    readonly property int _cpuSampleSerial: cpuClock.generation

    function cpuScrollPhase() {
        return cpuClock.phase();
    }

    SampleClock {
        id: memClock
        sampleInterval: 2000
        minInterval: 400
        maxInterval: 16000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _memPhaseStart: memClock.phaseStart
    readonly property real _memInterval: memClock.interval
    readonly property int _memSampleSerial: memClock.generation

    function memScrollPhase() {
        return memClock.phase();
    }

    SampleClock {
        id: diskClock
        sampleInterval: 1000
        minInterval: 200
        maxInterval: 8000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _dskPhaseStart: diskClock.phaseStart
    readonly property real _dskInterval: diskClock.interval
    readonly property int _dskSampleSerial: diskClock.generation

    function diskScrollPhase() {
        return diskClock.phase();
    }

    SampleClock {
        id: custClock
        sampleInterval: 2000
        minInterval: 200
        maxInterval: 120000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _custPhaseStart: custClock.phaseStart
    readonly property real _custInterval: custClock.interval
    readonly property int _custSampleSerial: custClock.generation

    function custScrollPhase() {
        return custClock.phase();
    }

    SampleClock {
        id: gpuClock
        sampleInterval: 2000
        minInterval: 400
        maxInterval: 16000
        smooth: !!cfg.smoothScroll
    }
    readonly property real _gpuPhaseStart: gpuClock.phaseStart
    readonly property real _gpuInterval: gpuClock.interval
    readonly property int _gpuSampleSerial: gpuClock.generation

    function gpuScrollPhase() {
        return gpuClock.phase();
    }

    function _phaseTau(intervalMs) {
        return Math.min(0.5, 250 / Math.max(1, intervalMs));
    }

    function scrollDrawPhase(phase, intervalMs) {
        if (!isFinite(phase))
            return 0;
        if (phase <= 1)
            return phase;
        const tau = core._phaseTau(intervalMs);
        return 1 + tau * (1 - Math.exp(-(phase - 1) / tau));
    }

    function _phaseActive(start, intervalMs) {
        return start > 0 && (Date.now() - start) / intervalMs < 1 + 4 * core._phaseTau(intervalMs);
    }

    // Latency band of a single sample: 0 = normal, 1 = warning, 2 = critical.
    // The graph is split into runs of equal band so one spike only recolours
    // itself instead of the whole line. With threshold colouring off every
    // sample reports band 0 and the graph stays on the user's own colour.
    function pingBandFor(ms) {
        if (!cfg.pingThresholdColors)
            return 0;
        const threshold = cfg.latencyThreshold;
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
    // Sample clocks, one per metric: views take sampleSerial and the drawn
    // scroll phase from these.
    property alias pingClock: pingClock
    property alias netClock: netClock
    property alias cpuClock: cpuClock
    property alias memClock: memClock
    property alias diskClock: diskClock
    property alias customClock: custClock
    property alias gpuClock: gpuClock

    // Scroll phase to draw for a clock this frame. Reading scrollTick makes a
    // binding on it re-evaluate once per ticker frame.
    function drawPhase(clock) {
        scrollTick;
        return scrollDrawPhase(clock.phase(), clock.interval);
    }

    // Colour for the live readout / single-value charts, which react to the
    // alert state (latency *or* packet loss) rather than a raw sample.
    function pingAlertColor() {
        return pingAlertActive ? pingCritColor : pingColor;
    }

    property int scrollTick: 0

    // Keep the first unanswered request so later data cannot reset the timeout.
    property real _lastPaintRequestMs: 0
    property real _lastPaintMs: 0
    property bool _renderStalled: false
    // How often to check whether we are back on screen, while stalled.
    readonly property int _stalledProbeMs: 1000
    // How long unanswered before we call it a stall. Comfortably longer than any
    // single frame, so a slow frame or a busy compositor is not mistaken for one.
    readonly property int _stallAfterMs: 1000

    // Called by BloomChart on both sides of a paint.
    function notePaintRequested() {
        if (_lastPaintRequestMs <= _lastPaintMs)
            _lastPaintRequestMs = Date.now();
    }
    function notePainted() {
        _lastPaintMs = Date.now();
        if (_renderStalled) {
            _renderStalled = false;
            // Whatever moved while we were dark is already in the histories, so
            // one full repaint brings every chart back complete.
            repaintCharts();
        }
    }

    // Emitted when the charts need to be redrawn from scratch regardless of the
    // scroll budget — currently when the popup comes back on screen, where the
    // canvases may still hold the frame from before it was hidden.
    signal repaintCharts

    // Chart types 3-5 are gauges and 6 is text-only: none of them scroll, so the
    // ticker has nothing to animate and never needs to start.
    readonly property bool _chartScrolls: (cfg.chartType || 0) < 3

    // Base sensor poll period in milliseconds; the slower sensors are plain
    // multiples of it (see main.xml). Floored at 250 ms because every tick still
    // spawns a process through the executable engine — below that the spawns
    // cost far more than the extra resolution is worth.
    readonly property int _pollBase: Math.max(250, cfg.updateInterval || 1000)
    // The same setting without that floor. The floor exists to price process
    // spawns, and the sensor backend has none to pay for — it is handed values
    // the daemon has already computed. Below the daemon's own 500 ms tick there
    // is simply nothing more to collect, by us or by anyone else.
    readonly property int updateIntervalMs: Math.max(100, cfg.updateInterval || 1000)

    // ── data backend ──────────────────────────────────────────────────────────
    // Preferred path: subscribe to ksystemstats, the daemon Plasma's own monitor
    // widgets use, and let it push values at its native rate. Fallback path: the
    // combined /proc poll further down. The backend lives behind a Loader
    // because its libksysguard import is fatal to a whole QML file when the
    // module is not installed — the Loader turns that into a status we can read.
    Loader {
        id: sensorLoader
        // setSource rather than a source binding: the backend declares `host` as
        // a required property, which has to be supplied at creation time.
        Component.onCompleted: if (core.live)
            setSource("SensorBackend.qml", {
                host: core
            })
        onStatusChanged: if (status === Loader.Error)
            console.log("glassy: libksysguard sensors unavailable, falling back to /proc polling")
    }
    // Both conditions matter: the module can be present while the daemon is not
    // running, in which case the sensors never leave Loading and we must keep
    // reading /proc ourselves.
    readonly property bool sensorsActive: sensorLoader.status === Loader.Ready && sensorLoader.item !== null && sensorLoader.item.ready
    // The backend object, for sections that take samples from it by signal.
    // Null whenever the fallback path is in charge.
    readonly property var sensorBackend: sensorLoader.status === Loader.Ready ? sensorLoader.item : null

    // Say so once when the daemon takes over, so the choice is visible in the
    // journal rather than something to infer from a process listing. The failure
    // cases are quiet by design: a missing module logs from the Loader above, and
    // a module present with no daemon behind it simply never gets here.
    onSensorsActiveChanged: if (sensorsActive)
        console.log("glassy: using ksystemstats sensors for CPU/memory/network/disk")
    // Phase windows are normalised to 1.0 = one full data interval, plus the
    // overshoot that eases out after it (see _phaseActive).
    // NOTE: We deliberately do NOT use a readonly binding for "is anything
    // animating?". The phase functions read Date.now(), which Qt's binding
    // system cannot track, so such a binding would never re-evaluate to
    // false once data arrives, and the ticker would run forever (a major
    // source of constant CPU). Instead the ticker is started on each data
    // update and stops ITSELF once every phase has come to rest.
    function _anyAnimatingNow() {
        if (!cfg.smoothScroll || !core._chartScrolls || !core.onScreen)
            return false;
        if (core.showPingSection && core._phaseActive(core._pingPhaseStart, core._pingInterval))
            return true;
        if (core.showNetworkSpeed && core._phaseActive(core._netPhaseStart, core._netInterval))
            return true;
        if (core.showCpuSection && core._phaseActive(core._cpuPhaseStart, core._cpuInterval))
            return true;
        if (core.showMemorySection && core._phaseActive(core._memPhaseStart, core._memInterval))
            return true;
        if (core.showDiskSection && core._phaseActive(core._dskPhaseStart, core._dskInterval))
            return true;
        if (core.showCustomSection && core._phaseActive(core._custPhaseStart, core._custInterval))
            return true;
        if (core.showGpuSection && core._phaseActive(core._gpuPhaseStart, core._gpuInterval))
            return true;
        return false;
    }

    // Start the ticker whenever new data lands on any channel. The ticker
    // then stops itself once all phases have expired.
    function _ensureScrollTicker() {
        if (cfg.smoothScroll && core._chartScrolls && core.onScreen && !scrollTicker.running)
            scrollTicker.start();
    }

    // Closing the popup (or switching to a non-scrolling chart type) must stop
    // the ticker right away rather than waiting for the current phase to expire.
    onOnScreenChanged: {
        if (onScreen) {
            repaintCharts();
            _ensureScrollTicker();
        } else {
            scrollTicker.stop();
        }
    }
    on_ChartScrollsChanged: {
        if (_chartScrolls)
            _ensureScrollTicker();
        else
            scrollTicker.stop();
    }

    ScrollTicker {
        id: scrollTicker
        targetFps: core._renderStalled ? 1000 / core._stalledProbeMs : Math.max(15, cfg.targetFps || 60)
        onTick: {
            core._renderStalled = core._lastPaintRequestMs > core._lastPaintMs && Date.now() - core._lastPaintRequestMs > core._stallAfterMs;
            core.scrollTick = (core.scrollTick + 1) & 0x7fffffff;
            if (!core._anyAnimatingNow())
                scrollTicker.stop();
        }
    }

    onHistoriesChanged: {
        pingClock.sample();
        _ensureScrollTicker();
    }
    onDlHistoryChanged: {
        netClock.sample();
        _ensureScrollTicker();
    }
    onCpuHistoryChanged: {
        cpuClock.sample();
        _ensureScrollTicker();
    }
    onMemHistoryChanged: {
        memClock.sample();
        _ensureScrollTicker();
    }
    onCustomHistoryChanged: {
        custClock.sample();
        _ensureScrollTicker();
    }
    onGpuHistoryChanged: {
        gpuClock.sample();
        _ensureScrollTicker();
    }

    // ── ping state ────────────────────────────────────────────────────────────
    readonly property var targetList: {
        const raw = cfg.targets || "8.8.8.8";
        return raw.split(",").map(s => s.trim()).filter(s => s.length > 0);
    }
    readonly property int activeTarget: Math.max(0, Math.min(cfg.currentTargetIndex, targetList.length - 1))

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

    // The "executable" engine does NOT run its source through a shell — it splits
    // the string into argv and execs directly. Any command using pipes, redirection,
    // `;`, `||`, `$(...)`, globs or loops must therefore be handed to an explicit
    // shell, or the metacharacters arrive as literal arguments.
    function shellCmd(cmd) {
        return OsFetch.shellCmd(cmd);
    }

    CommandSource {
        id: pingSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isPinging = false;
            pingSource.disconnectSource(sourceName);
            // Support both "time=X" (IPv4) and "time X" (ping6 on some systems)
            const m = (data["stdout"] || "").match(/time[<=\s](\d+(?:[.,]\d+)?)/);
            const ms = m ? parseFloat(m[1].replace(",", ".")) : -1;
            core.lastPingTimestamp = Date.now();
            core.addPingResult(core.activeTarget, ms);
        }
    }

    Timer {
        interval: Math.max(1, cfg.pingInterval) * 1000
        running: core.showPingSection
        repeat: true
        onTriggered: core.triggerPing()
    }

    function triggerPing() {
        if (!core.showPingSection || isPinging || targetList.length === 0)
            return;
        const host = targetList[activeTarget];
        if (!host)
            return;
        isPinging = true;
        // Detect IPv6 address or bracketed IPv6 and use ping6 if available, else ping with -6
        const isIPv6 = host.indexOf(":") !== -1;
        const cmd = isIPv6 ? "ping6 -c 1 -W " + cfg.pingTimeout + " " + host + " 2>/dev/null || ping -6 -c 1 -W " + cfg.pingTimeout + " " + host : "ping -c 1 -W " + cfg.pingTimeout + " " + host;
        pingSource.connectSource(isIPv6 ? core.shellCmd(cmd) : cmd);
    }

    function addPingResult(idx, ms) {
        if (idx < 0 || idx >= histories.length)
            return;
        const newH = histories.slice();
        newH[idx] = appendHistory(histories[idx], ms);
        histories = newH;
        if (idx === activeTarget)
            refreshPingStats();
    }

    // Readouts for the active target, from its whole visible history.
    function refreshPingStats() {
        const h = histories[activeTarget] || [];
        const valid = h.filter(v => v >= 0);
        lastPing = h.length > 0 ? h[h.length - 1] : -1;
        avgPing = valid.length ? valid.reduce((a, b) => a + b, 0) / valid.length : 0;
        jitter = valid.length >= 2 ? Math.sqrt(valid.reduce((s, v) => s + (v - avgPing) * (v - avgPing), 0) / valid.length) : 0;
        lossPercent = h.length > 0 ? (h.length - valid.length) / h.length * 100 : 0;
        isAlerting = (lastPing >= 0 && lastPing > cfg.latencyThreshold) || lossPercent > cfg.lossThreshold;
    }

    onActiveTargetChanged: {
        refreshPingStats();
        triggerPing();
    }

    // ── combined /proc poll ───────────────────────────────────────────────────
    // /proc/diskstats, /proc/stat, /proc/meminfo and /proc/net/dev used to be
    // read by four independent DataSources on four timers, each forking its own
    // `cat` — four processes every single second, forever. Fork + exec + the
    // page faults that follow are cheap individually and ruinous in aggregate
    // for idle power: they keep waking a core that would otherwise stay parked.
    // The executable engine runs one argv, so a single `cat a b c` reads all of
    // them in one process and the reply is split back apart below.
    property bool isReadingSys: false
    property int _sysTick: 0
    // When the in-flight request was sent, for the watchdog in the timer below.
    property real _sysRequestedAt: 0
    // What the in-flight request asked for, so the reply can be routed. Recorded
    // when the request goes out because the section toggles may change while it
    // is in flight.
    property bool _sysWantDisk: false
    property bool _sysWantCpu: false
    property bool _sysWantMem: false
    property bool _sysWantNet: false

    // True for the first line of /proc/stat, /proc/meminfo and /proc/net/dev.
    // /proc/diskstats has no distinctive first line, which is why it is always
    // requested first: its block is simply everything before the next file
    // starts.
    function _isProcBlockStart(line) {
        return /^cpu\s/.test(line) || /^MemTotal:/.test(line) || /^Inter-\|/.test(line);
    }

    function _parseSysPoll(text) {
        let body = text;
        if (core._sysWantDisk) {
            const lines = text.split("\n");
            let at = 0;
            while (at < lines.length && !core._isProcBlockStart(lines[at]))
                at++;
            parseDiskStats(lines.slice(0, at).join("\n"));
            body = lines.slice(at).join("\n");
        }
        // The remaining three go to their parsers unsplit. Each matches only its
        // own line shape and the shapes do not overlap: parseCpuStats wants
        // "cpu<n> " followed by eight counters (no colon, so no /proc/net/dev
        // line reaches it), parseNetStats wants "<name>:" followed by nine
        // counters (meminfo has one value, /proc/stat has no colons), and
        // parseMemStats only ever looks up MemTotal/MemAvailable/SwapTotal/
        // SwapFree by name.
        if (core._sysWantCpu)
            parseCpuStats(body);
        if (core._sysWantMem)
            parseMemStats(body);
        if (core._sysWantNet)
            parseNetStats(body);
    }

    // Read/write throughput in bytes per second. The sensor backend reports this
    // directly; the /proc/diskstats path derives it from a sector-count delta.
    function applyDiskSample(readBytesPerSec, writeBytesPerSec) {
        diskReadSpeed = Math.max(0, readBytesPerSec);
        diskWriteSpeed = Math.max(0, writeBytesPerSec);
        diskReadHistory = appendHistory(diskReadHistory, diskReadSpeed);
        diskWriteHistory = appendHistory(diskWriteHistory, diskWriteSpeed);
        diskClock.sample();
        _ensureScrollTicker();
    }

    // /proc/diskstats columns (1-based): major minor name rd_ios rd_merges
    // rd_sectors rd_ticks wr_ios wr_merges wr_sectors …; a sector is 512 bytes.
    function parseDiskStats(text) {
        const want = cfg.diskDevice || "auto";
        const diskData = {};
        const found = ["auto"];
        let bestDisk = "", bestActivity = -1;
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (p.length < 14)
                continue;
            const name = p[2];
            // Whole disks only: no loop/ram devices and no partitions
            // (sda1, vda1, nvme0n1p1, mmcblk0p1).
            if (/^(loop|ram|zram)/.test(name) || /[0-9]p[0-9]+$/.test(name) || /^[sv]d[a-z]+[0-9]+$/.test(name))
                continue;
            const rd = parseInt(p[5]) * 512;
            const wr = parseInt(p[9]) * 512;
            diskData[name] = {
                rd,
                wr
            };
            found.push(name);
            if (rd + wr > bestActivity) {
                bestActivity = rd + wr;
                bestDisk = name;
            }
        }
        if (found.join() !== availableDisks.join())
            availableDisks = found;
        autoDisk = bestDisk;
        const disk = (want !== "auto" && diskData[want]) ? want : bestDisk;
        if (!disk)
            return;
        activeDisk = disk;
        // Sensors own the throughput; this pass only refreshes the "auto" pick.
        if (core.sensorsActive)
            return;
        const now = Date.now();
        const {
            rd,
            wr
        } = diskData[disk];
        if (_lastDiskStats && _lastDiskStats.disk === disk) {
            const dt = (now - _lastDiskStats.time) / 1000;
            if (dt > 0.1)
                applyDiskSample((rd - _lastDiskStats.rd) / dt, (wr - _lastDiskStats.wr) / dt);
        }
        _lastDiskStats = {
            disk,
            rd,
            wr,
            time: now
        };
    }

    // Under the sensor backend the throughput arrives from the daemon instead,
    // and the /proc read above degrades to a slow device-enumeration pass.
    Connections {
        target: core.sensorBackend
        ignoreUnknownSignals: true
        enabled: core.sensorsActive
        function onDiskSample(readBytesPerSec, writeBytesPerSec) {
            core.activeDisk = core.resolvedDisk;
            core.applyDiskSample(readBytesPerSec, writeBytesPerSec);
        }
    }
    CommandSource {
        id: sysSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingSys = false;
            sysSource.disconnectSource(sourceName);
            core._parseSysPoll(data["stdout"] || "");
        }
    }

    Timer {
        // With the sensor backend live this drops to a slow discovery pass: the
        // daemon supplies every rate, but it has no say in which interface or
        // disk "auto" should follow, and the in-popup device pickers still want
        // a list. One read every thirty ticks keeps both current for a cost that
        // rounds to nothing.
        interval: core._pollBase * (core.sensorsActive ? 30 : 1)
        // Only the sections that actually need this read. Under the sensor
        // backend that is just network and disk, and only for device discovery —
        // CPU and memory have nothing to enumerate, so a widget showing either of
        // them stops running this timer altogether rather than waking up to
        // build an empty file list.
        running: core.sensorsActive ? (core.showDiskSection || core.showNetworkSpeed) : (core.showDiskSection || core.showCpuSection || core.showMemorySection || core.showNetworkSpeed)
        repeat: true
        onTriggered: {
            if (core.isReadingSys) {
                // A read that never comes back used to stall one section; now it
                // would stall all four, so abandon it rather than queueing behind
                // it forever.
                if (Date.now() - core._sysRequestedAt < core._pollBase * 4)
                    return;
                sysSource.reset();
                core.isReadingSys = false;
            }
            // Memory rides along on every second poll, preserving the half-rate
            // cadence it had as a standalone timer — the memory graph's time span
            // depends on how often a sample is appended to its history.
            // In discovery mode CPU and memory are not wanted at all — nothing
            // about them needs enumerating, and the sensors already have them.
            core._sysWantDisk = core.showDiskSection;
            core._sysWantCpu = core.showCpuSection && !core.sensorsActive;
            core._sysWantMem = core.showMemorySection && !core.sensorsActive && (core._sysTick % 2) === 0;
            core._sysWantNet = core.showNetworkSpeed;
            core._sysTick = (core._sysTick + 1) & 0x7fffffff;

            // /proc/diskstats first — see _isProcBlockStart.
            const files = [];
            if (core._sysWantDisk)
                files.push("/proc/diskstats");
            if (core._sysWantCpu)
                files.push("/proc/stat");
            if (core._sysWantMem)
                files.push("/proc/meminfo");
            if (core._sysWantNet)
                files.push("/proc/net/dev");
            if (files.length === 0)
                return;
            core.isReadingSys = true;
            core._sysRequestedAt = Date.now();
            sysSource.connectSource("cat " + files.join(" "));
        }
    }

    // ── network state ─────────────────────────────────────────────────────────
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var dlHistory: []
    property var ulHistory: []
    property var lastNetBytes: null
    property string activeIface: ""
    property var availableIfaces: ["auto"]
    // What "auto" resolves to: the default-route interface (Probes.autoInterface).
    property string autoIface: ""
    // The interface the section actually follows, and the one the sensor backend
    // subscribes to. Empty until the first enumeration lands, which the backend
    // reads as "use the daemon's aggregate for now".
    readonly property string resolvedIface: {
        const want = (cfg.networkInterface || "auto").trim();
        return (want === "" || want === "auto") ? autoIface : want;
    }
    property real sessionDlBytes: 0
    property real sessionUlBytes: 0

    // ── Network identity (SSID / IP) ──────────────────────────────────────────
    // Optional, off by default. Polled infrequently (changes rarely). SSID is the
    // Wi-Fi name when on wireless ("" on wired); ip is the iface's primary IPv4.
    property string netSsid: ""
    property string netIpAddr: ""
    property bool isReadingNetInfo: false

    CommandSource {
        id: netInfoSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingNetInfo = false;
            netInfoSource.disconnectSource(sourceName);
            core.parseNetInfo(data["stdout"] || "");
        }
    }
    Timer {
        interval: core._pollBase * 8
        running: core.showNetworkSpeed && !!cfg.netShowInfo
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (core.isReadingNetInfo || !core.activeIface)
                return;
            core.isReadingNetInfo = true;
            const ifc = core.activeIface;
            // Two lines: line0 = SSID, line1 = primary IPv4.
            // SSID: try each tool and emit the FIRST NON-EMPTY result. We can't use
            // `a || b` because some tools (e.g. `iw link` without privileges) exit 0
            // while printing nothing, which would wrongly short-circuit the chain.
            netInfoSource.connectSource(core.shellCmd("s=$(iwgetid -r 2>/dev/null); [ -z \"$s\" ] && s=$(iw dev " + ifc + " link 2>/dev/null | sed -n 's/^[[:space:]]*SSID: //p'); [ -z \"$s\" ] && s=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | sed -n 's/^yes://p' | head -1); echo \"$s\"; ip -o -4 addr show dev " + ifc + " scope global 2>/dev/null | awk '{print $4}' | head -1"));
        }
    }
    function parseNetInfo(text) {
        const lines = text.split("\n");
        core.netSsid = (lines[0] || "").trim();
        const ip = (lines[1] || "").trim();
        core.netIpAddr = ip.split("/")[0];   // strip CIDR suffix
    }

    // ── Network interfaces ────────────────────────────────────────────────────
    // Every interface with its kind, state, address and link speed; "auto"
    // follows the default route (Probes.autoInterface).
    property var interfaces: []
    // Bytes per second per interface, from the /proc/net/dev enumeration.
    property var ifaceRates: ({})
    property var _lastIfaceBytes: null
    ShellProbe {
        sourceComponent: core.commandSourceComponent
        command: Probes.INTERFACES_CMD
        interval: core._pollBase * 10
        running: core.showNetworkSpeed && core.live
        onResult: text => core.interfaces = Probes.parseInterfaces(text)
    }

    // ── Storage ───────────────────────────────────────────────────────────────
    property var storage: []
    ShellProbe {
        sourceComponent: core.commandSourceComponent
        command: Probes.STORAGE_CMD
        interval: core._pollBase * 15
        running: core.showStorage && core.active && core.live
        onResult: text => core.storage = Probes.parseStorage(text, cfg.storageMounts)
    }

    // ── Top processes ─────────────────────────────────────────────────────────
    property var processes: []
    property var _procSnapshot: null
    ShellProbe {
        sourceComponent: core.commandSourceComponent
        command: Probes.PROCESSES_CMD
        interval: core._pollBase * 3
        running: core.showProcesses && core.active && core.live
        onResult: text => {
            const next = Probes.parseProcSnapshot(text);
            if (core._procSnapshot)
                core.processes = Probes.topProcesses(core._procSnapshot, next, cfg.processCount || 5, cfg.processSort || "cpu", cfg.processGroup !== false);
            core._procSnapshot = next;
        }
    }

    // Download/upload in bytes per second, plus the seconds those rates covered
    // so the session totals can integrate them. The sensor path knows the rate
    // directly; the /proc path derives it from a counter delta.
    function applyNetSample(dlBytesPerSec, ulBytesPerSec, dtSeconds) {
        downloadSpeed = Math.max(0, dlBytesPerSec);
        uploadSpeed = Math.max(0, ulBytesPerSec);
        if (dtSeconds > 0) {
            sessionDlBytes += downloadSpeed * dtSeconds;
            sessionUlBytes += uploadSpeed * dtSeconds;
        }
        dlHistory = appendHistory(dlHistory, downloadSpeed);
        ulHistory = appendHistory(ulHistory, uploadSpeed);
    }

    function parseNetStats(text) {
        const cfgIface = cfg.networkInterface || "auto";
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
        if (core.availableIfaces.length !== foundIfaces.length || !core.availableIfaces.every((val, index) => val === foundIfaces[index])) {
            core.availableIfaces = foundIfaces;
        }

        // Per-interface rates for the studio's interface cards.
        const now = Date.now();
        if (_lastIfaceBytes && now - _lastIfaceBytes.time > 100) {
            const dt = (now - _lastIfaceBytes.time) / 1000, rates = {};
            for (const name in ifaceData) {
                const before = _lastIfaceBytes.data[name];
                if (before)
                    rates[name] = {
                        rx: Math.max(0, (ifaceData[name].rx - before.rx) / dt),
                        tx: Math.max(0, (ifaceData[name].tx - before.tx) / dt)
                    };
            }
            ifaceRates = rates;
        }
        _lastIfaceBytes = {
            time: now,
            data: ifaceData
        };

        autoIface = Probes.autoInterface(core.interfaces, core.ifaceRates, bestIface);

        const iface = (cfgIface !== "auto" && ifaceData[cfgIface]) ? cfgIface : ifaceData[autoIface] ? autoIface : bestIface;
        if (!iface || !ifaceData[iface])
            return;
        activeIface = iface;
        // Under the sensor backend this pass exists purely to refresh the list
        // above and the "auto" pick; the rates come from the daemon, and a
        // counter delta taken across a thirty-tick gap would be meaningless.
        if (core.sensorsActive)
            return;

        const {
            rx,
            tx
        } = ifaceData[iface];
        if (lastNetBytes && lastNetBytes.iface === iface) {
            const dt = (now - lastNetBytes.time) / 1000;
            if (dt > 0.1)
                applyNetSample((rx - lastNetBytes.rx) / dt, (tx - lastNetBytes.tx) / dt, dt);
        }
        lastNetBytes = {
            iface,
            rx,
            tx,
            time: now
        };
    }

    // ── CPU state ─────────────────────────────────────────────────────────────
    property real cpuPercent: 0
    property var cpuHistory: []
    property var corePercents: []
    property var coreHistories: []
    property var lastCpuStats: null

    // Append one sample to a rolling history, returning the new array. Every
    // section's history is capped at historySize + 1: the extra sample is the
    // one sliding off the left edge, which the scroll animation still needs to
    // draw. Kept in one place because both data paths (the ksystemstats sensors
    // and the /proc fallback) append through it.
    function appendHistory(history, value) {
        const maxH = Math.max(10, cfg.historySize);
        const next = history.slice();
        next.push(value);
        if (next.length > maxH + 1)
            next.splice(0, next.length - (maxH + 1));
        return next;
    }

    // ── sample sinks ──────────────────────────────────────────────────────────
    // Everything below takes *finished* values — percentages, bytes per second —
    // and does the bookkeeping the charts read. Whoever produced the numbers
    // (the sensor daemon, or the /proc parsers further down) is not their
    // concern, which is what lets the two paths stay interchangeable.

    function applyCpuSample(totalPct, corePcts) {
        cpuPercent = Math.min(100, Math.max(0, totalPct));
        // An empty list means "no per-core reading in this sample", not "zero
        // cores": the sensor backend hands one over until the daemon has
        // answered how many cores there are. Overwriting with it would throw
        // away the per-core histories built so far and rebuild them from
        // scratch a moment later.
        if (corePcts && corePcts.length > 0)
            corePercents = corePcts;
        cpuHistory = appendHistory(cpuHistory, cpuPercent);
        const n = corePercents.length;
        let ch = coreHistories.length === n ? coreHistories.map(h => h.slice()) : corePercents.map(() => []);
        for (let i = 0; i < n; i++)
            ch[i] = appendHistory(ch[i], corePercents[i]);
        coreHistories = ch;
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
            applyCpuSample(cpuPercent, newCP);
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

    // usedBytes/totalBytes and the swap pair, in bytes. A zero total means "no
    // such device" — no swap, or a reading that has not arrived yet.
    function applyMemSample(usedBytes, totalBytes, swapUsedBytes, swapTotalBytes) {
        if (totalBytes > 0) {
            memPercent = usedBytes / totalBytes * 100;
            memUsedGiB = usedBytes / 1073741824;
            memTotalGiB = totalBytes / 1073741824;
        }
        hasSwap = swapTotalBytes > 0;
        if (hasSwap) {
            swapPercent = swapUsedBytes / swapTotalBytes * 100;
            swapUsedGiB = swapUsedBytes / 1073741824;
        } else {
            // swapoff while we are running: clear the readings rather than
            // leaving the last ones frozen in the legend and the history.
            swapPercent = 0;
            swapUsedGiB = 0;
        }
        memHistory = appendHistory(memHistory, memPercent);
        swapHistory = appendHistory(swapHistory, swapPercent);
    }

    function parseMemStats(text) {
        const v = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                v[m[1]] = parseInt(m[2]);
        }
        // /proc/meminfo reports KiB; the sink works in bytes, like the sensors do.
        const KiB = 1024;
        const total = (v["MemTotal"] || 0) * KiB, avail = (v["MemAvailable"] || 0) * KiB;
        const swapTot = (v["SwapTotal"] || 0) * KiB, swapFree = (v["SwapFree"] || 0) * KiB;
        applyMemSample(total - avail, total, swapTot - swapFree, swapTot);
    }

    // ── disk state ────────────────────────────────────────────────────────────
    property real diskReadSpeed: 0
    property real diskWriteSpeed: 0
    property var diskReadHistory: []
    property var diskWriteHistory: []
    property var _lastDiskStats: null
    // The disk the numbers belong to, and every whole disk seen.
    property string activeDisk: ""
    property var availableDisks: ["auto"]
    // Busiest whole disk seen by the last enumeration; what "auto" resolves to.
    property string autoDisk: ""
    // The device the section follows, and the one the sensor backend subscribes
    // to. Mirrors resolvedIface, including the empty-until-discovered contract.
    readonly property string resolvedDisk: {
        const want = (cfg.diskDevice || "auto").trim();
        return (want === "" || want === "auto") ? autoDisk : want;
    }
    readonly property color diskRdColor: Qt.color(cfg.diskRdColor || "#22ddff")
    readonly property color diskWrColor: Qt.color(cfg.diskWrColor || "#ffaa22")

    // ── custom command state ──────────────────────────────────────────────────
    property real customValue: 0
    property var customHistory: []
    property bool isReadingCustom: false

    CommandSource {
        id: customSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingCustom = false;
            customSource.disconnectSource(sourceName);
            const val = parseFloat((data["stdout"] || "").trim());
            if (!isNaN(val)) {
                core.customValue = val;
                core.customHistory = core.appendHistory(core.customHistory, val);
            }
        }
    }
    Timer {
        interval: Math.max(1, cfg.customCmdInterval) * 1000
        running: core.showCustomSection && core.active
        repeat: true
        onTriggered: {
            if (!core.isReadingCustom && cfg.customCmd) {
                core.isReadingCustom = true;
                // Run through an explicit shell so pipes, redirections and
                // shell builtins behave the same regardless of how the
                // executable engine decides to split the string.
                customSource.connectSource("sh -c '" + cfg.customCmd.replace(/'/g, "'\\''") + "'");
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

    readonly property color gpuColor: Qt.color(cfg.gpuColor || "#ff6e40")

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
        core.gpuDevices = devs;
        if (devs.length === 0)
            return;

        // The setting stores a PCI address, but accept a plain "cardN" too —
        // the config field is free-text, so people can type either.
        const want = core.gpuDeviceCfg.trim();
        let pick = null;
        if (want !== "" && want.toLowerCase() !== "auto") {
            const w = want.toLowerCase();
            pick = devs.find(d => d.pci.toLowerCase() === w || d.card.toLowerCase() === w) || null;
        }
        // Auto, or the chosen card is gone (eGPU unplugged, renamed, typo).
        if (!pick)
            pick = devs.find(d => d.hasTelemetry) || devs[0];

        core.gpuCardPath = "/sys/class/drm/" + pick.card;
        core.gpuPciId = /^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.\d$/.test(pick.pci) ? pick.pci : "";
        core.gpuDetected = true;

        // vendor id: 0x8086=Intel, 0x1002=AMD, 0x10de=NVIDIA
        if (pick.vendorId === "0x8086") {
            core.gpuVendor = "intel";
            core.gpuMode = "intel";
        } else if (pick.vendorId === "0x1002") {
            core.gpuVendor = "amd";
            core.gpuMode = "amd";
        } else if (pick.vendorId === "0x10de") {
            core.gpuVendor = "nvidia";
            // fdinfo works without the proprietary driver; upgrade to nvidia-smi
            // only if it answers for this specific card.
            core.gpuMode = "fdinfo";
            gpuDetectSource.connectSource("sh -c 'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits" + core._nvidiaTarget() + " 2>/dev/null | head -1'");
        } else {
            core.gpuVendor = "";
            core.gpuMode = "fdinfo";
        }
    }

    // "-i <pci>" so multi-GPU NVIDIA boxes query the selected card, not GPU 0.
    function _nvidiaTarget() {
        return core.gpuPciId ? " -i " + core.gpuPciId : "";
    }

    function detectGpu() {
        core.gpuDetected = false;
        core.gpuMode = "";
        core.gpuVendor = "";
        core.gpuCardPath = "";
        core.gpuPciId = "";
        core.gpuNoDataTicks = 0;
        core.gpuSysfsBusyOk = false;
        core._gpuPollTick = 0;
        // Drop the previous card's readings, so switching devices does not leave
        // a graph mixing two GPUs' history.
        core.gpuPercent = 0;
        core.gpuHistory = [];
        core.gpuFreqMhz = 0;
        core.gpuComputePercent = -1;
        core.gpuDecPercent = -1;
        core.gpuEncPercent = -1;
        core.gpuVramUsed = -1;
        core.gpuVramTotal = -1;
        core._gpuLastEngineNs = null;
        core._gpuLastRc6Ms = -1;
        gpuDetectSource.connectSource(core._gpuEnumCmd);
    }

    // Detect GPU backend on startup, and again whenever the device setting changes
    CommandSource {
        id: gpuDetectSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            gpuDetectSource.disconnectSource(sourceName);
            const out = (data["stdout"] || "").trim();
            if (sourceName.indexOf("nvidia-smi") !== -1) {
                // Probe answer for a card already known to be NVIDIA.
                if (out.length > 0 && !isNaN(parseFloat(out)))
                    core.gpuMode = "nvidia";
            } else if (sourceName.indexOf("drm/card") !== -1) {
                core._chooseGpu(out);
            }
        }
    }

    // cfg is a property map: it drives bindings but emits no
    // per-key change signal, so mirror the setting and re-detect when it moves.
    readonly property string gpuDeviceCfg: cfg.gpuDevice || "auto"
    onGpuDeviceCfgChanged: {
        if (core.showGpuSection && core.live)
            core.detectGpu();
    }

    CommandSource {
        id: gpuSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingGpu = false;
            gpuSource.disconnectSource(sourceName);
            core.parseGpuData(sourceName, data["stdout"] || "");
        }
    }

    Timer {
        id: gpuDetectTimer
        interval: 200
        repeat: false
        running: core.showGpuSection && core.live
        onTriggered: core.detectGpu()
    }

    // ── the fdinfo scan ───────────────────────────────────────────────────────
    // `grep -r` over /proc/[0-9]*/fdinfo/ opens and reads every file descriptor
    // of every process on the machine. On a desktop with a browser and a couple
    // of Electron apps open that is tens of thousands of files per run, and each
    // DRM fd makes the graphics driver generate its stats on the spot — so most
    // of the cost lands in kernel time, attributed to nobody, rather than in
    // plasmashell. It used to run unconditionally every two seconds.
    // It is the only way to get a per-engine breakdown, so it still runs — but
    // only when something actually consumes the result, and far less often.

    // True when sysfs gave us a real gpu_busy_percent, i.e. the fdinfo scan is a
    // nice-to-have rather than the sole source of utilisation. RDNA4 (RX 9000)
    // dropped that file, which is the case this distinguishes.
    property bool gpuSysfsBusyOk: false

    // The scan is the *only* source of utilisation in these cases, so it cannot
    // be skipped — instead the whole GPU poll slows down (see the timer below).
    readonly property bool _gpuScanIsSoleSource: core.gpuMode === "fdinfo" || (core.gpuMode === "amd" && !core.gpuSysfsBusyOk)

    // Counts GPU polls so the scan can ride along on only some of them.
    property int _gpuPollTick: 0
    // One GPU poll in every three carries the scan when it is merely feeding the
    // engine breakdown; engine shares are a coarse readout and reading them at
    // a third of the rate is not noticeable.
    readonly property int _gpuScanEveryNthPoll: 3

    function _gpuScanDue() {
        if (core._gpuScanIsSoleSource)
            return true;
        if (!cfg.gpuShowEngines)
            return false;
        return (core._gpuPollTick % core._gpuScanEveryNthPoll) === 0;
    }

    // The scan command itself. /proc/[0-9]* rather than /proc/* so that the
    // aliases /proc/self and /proc/thread-self are not walked a second time.
    readonly property string _gpuScanCmd: "grep -rhE \"drm-(pdev|engine|resident)\" /proc/[0-9]*/fdinfo/ 2>/dev/null"

    Timer {
        // When the scan is the sole source of utilisation, poll at a third of the
        // usual rate: a slower GPU gauge is a fair trade for not walking every
        // process's file descriptors every two seconds.
        interval: core._pollBase * (core._gpuScanIsSoleSource ? 6 : 2)
        running: core.showGpuSection
        repeat: true
        onTriggered: {
            if (!core.isReadingGpu && core.gpuMode !== "") {
                core.isReadingGpu = true;
                const scan = core._gpuScanDue();
                // Marker + scan, or nothing at all — the parser keys off the
                // "---ENG---" line and leaves the engine readings untouched when
                // it is absent, so a skipped scan simply holds the last values.
                const engBlock = scan ? "; echo \"---ENG---\"; " + core._gpuScanCmd : "";
                core._gpuPollTick++;
                if (core.gpuMode === "nvidia") {
                    // util, freq, encode%, decode%, vram used (MiB), vram total (MiB)
                    gpuSource.connectSource("sh -c 'nvidia-smi --query-gpu=utilization.gpu,clocks.current.graphics,utilization.encoder,utilization.decoder,memory.used,memory.total --format=csv,noheader,nounits" + core._nvidiaTarget() + " 2>/dev/null'");
                } else if (core.gpuMode === "amd") {
                    // busy% + VRAM used/total from sysfs, then the fdinfo block.
                    // gpu_busy_percent is absent on RDNA4 (RX 9000), so that line can
                    // come back empty; there the scan is the fallback and always runs.
                    gpuSource.connectSource("sh -c '" + core._gpuReadFn + "c=" + core.gpuCardPath + "/device; r \"$c/gpu_busy_percent\"; r \"$c/mem_info_vram_used\"; r \"$c/mem_info_vram_total\"" + engBlock + "'");
                } else if (core.gpuMode === "intel") {
                    // Intel: rc6_residency_ms delta → busy %, plus current freq, plus
                    // per-engine ns sums + memory from fdinfo (one combined read).
                    gpuSource.connectSource("sh -c '" + core._gpuReadFn + "g=" + core.gpuCardPath + "/gt/gt0; r \"$g/rc6_residency_ms\"; r \"$g/rps_cur_freq_mhz\"; r \"$g/rps_act_freq_mhz\"" + engBlock + "'");
                } else {
                    // fdinfo: sum each engine's cumulative ns across all processes, plus
                    // resident memory. Render≈compute/3D, video≈decode, video-enhance≈encode.
                    gpuSource.connectSource("sh -c '" + core._gpuScanCmd + "'");
                }
            } else if (!core.isReadingGpu && core.gpuMode === "" && core.gpuNoDataTicks < 2) {
                // Vendor detection came back empty (unknown vendor id, or sysfs not
                // readable). Give fdinfo a shot anyway rather than staying silent.
                core.gpuNoDataTicks++;
                if (core.gpuNoDataTicks >= 2)
                    core.gpuMode = "fdinfo";
            } else {
                core.isReadingGpu = false;
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
        const wantPci = core.gpuPciId;
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
            core.gpuVramUsed = resident;
        if (!sawEngine)
            return -1;

        const now = Date.now();
        const prev = core._gpuLastEngineNs;
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
                core.gpuComputePercent = busyPct;
                // "video" is decode-side; "video-enhance" is the encode/post pipe.
                core.gpuDecPercent = pct(video, prev.video);
                core.gpuEncPercent = pct(enhance, prev.enhance);
            }
        }
        core._gpuLastEngineNs = {
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

        if (core.gpuMode === "nvidia") {
            // "util, freq, enc%, dec%, vramUsedMiB, vramTotalMiB" (one GPU)
            const parts = (lines[0] || "").split(",").map(s => parseFloat(s));
            const util = parts[0], freq = parts[1], enc = parts[2], dec = parts[3];
            const vu = parts[4], vt = parts[5];
            if (!isNaN(util))
                core.gpuPercent = Math.min(100, Math.max(0, util));
            if (!isNaN(freq))
                core.gpuFreqMhz = freq;
            if (!isNaN(enc))
                core.gpuEncPercent = Math.min(100, Math.max(0, enc));
            if (!isNaN(dec))
                core.gpuDecPercent = Math.min(100, Math.max(0, dec));
            if (!isNaN(vu))
                core.gpuVramUsed = vu * 1048576;   // MiB → bytes
            if (!isNaN(vt))
                core.gpuVramTotal = vt * 1048576;
            core.gpuNoDataTicks = 0;
        } else if (core.gpuMode === "amd") {
            // line0: busy%, line1: vram used (bytes), line2: vram total (bytes),
            // then "---ENG---" followed by the fdinfo block.
            const v = parseInt(lines[0]);
            const vu = parseInt(lines[1]);
            const vt = parseInt(lines[2]);
            if (!isNaN(vt) && vt > 0)
                core.gpuVramTotal = vt;
            // Per-engine breakdown first: on RDNA4 it also supplies the overall
            // busy%, since gpu_busy_percent was dropped there.
            const engIdx = lines.indexOf("---ENG---");
            const enginePct = engIdx !== -1 ? core._parseFdinfoEngines(lines.slice(engIdx + 1)) : -1;
            // sysfs reports the real hardware busy%, so prefer it when present;
            // the fdinfo delta only sees engine time booked to a process.
            // Remember whether sysfs answered: that decides whether the fdinfo
            // scan is a luxury or the only thing keeping the gauge alive.
            core.gpuSysfsBusyOk = !isNaN(v);
            if (!isNaN(v)) {
                core.gpuPercent = Math.min(100, Math.max(0, v));
                core.gpuNoDataTicks = 0;
            } else if (enginePct >= 0) {
                core.gpuPercent = enginePct;
                core.gpuNoDataTicks = 0;
            } else
                core.gpuNoDataTicks++;
            // mem_info_vram_used is authoritative; overwrite whatever the fdinfo
            // resident sum guessed.
            if (!isNaN(vu))
                core.gpuVramUsed = vu;
        } else if (core.gpuMode === "intel") {
            // line0: rc6_residency_ms, line1: rps_cur_freq_mhz, line2: rps_act_freq_mhz,
            // then "---ENG---" followed by the fdinfo block.
            const rc6Now = parseFloat(lines[0]);
            const cur = parseInt(lines[1]);
            const act = parseInt(lines[2]);
            const now = Date.now();
            if (!isNaN(cur))
                core.gpuFreqMhz = isNaN(act) || act === 0 ? cur : act;
            if (!isNaN(rc6Now) && core._gpuLastRc6Ms >= 0 && core._gpuLastPollMs > 0) {
                const dtMs = now - core._gpuLastPollMs;
                const dRc6 = rc6Now - core._gpuLastRc6Ms;
                // rc6 = idle residency → busy = 1 - (dRc6 / dtMs), clamped
                const busy = Math.min(100, Math.max(0, (1.0 - dRc6 / dtMs) * 100));
                core.gpuPercent = busy;
                core.gpuNoDataTicks = 0;
            }
            core._gpuLastRc6Ms = rc6Now;
            core._gpuLastPollMs = now;
            // per-engine breakdown from the fdinfo block after the marker
            const engIdx = lines.indexOf("---ENG---");
            if (engIdx !== -1)
                core._parseFdinfoEngines(lines.slice(engIdx + 1));
        } else {
            // Generic fdinfo path: derive overall busy% from the render engine delta,
            // and fill the per-engine breakdown.
            const renderPct = core._parseFdinfoEngines(lines);
            if (renderPct >= 0) {
                core.gpuPercent = renderPct;
                core.gpuNoDataTicks = 0;
            } else
                core.gpuNoDataTicks++;
        }

        core.gpuHistory = core.appendHistory(core.gpuHistory, core.gpuPercent);
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

    CommandSource {
        id: hwSensorsSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingHwSensors = false;
            hwSensorsSource.disconnectSource(sourceName);
            core.applyHwSensorUpdate(core.parseHwSensorsJson(data["stdout"] || ""));
        }
    }

    Timer {
        interval: core._pollBase * 3
        running: core.showHwSensors && core.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!core.isReadingHwSensors) {
                core.isReadingHwSensors = true;
                hwSensorsSource.connectSource(core.shellCmd("sensors -j 2>/dev/null"));
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
                    chipDisplay: core.friendlyChipName(chipKey),
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
        core.hwMaxTemp = globalMaxTemp;
        core.hwMaxTempCrit = globalMaxTempCrit;
    }

    // ── OS Info state ─────────────────────────────────────────────────────────
    property string osDistro: ""
    property string osKernel: ""
    property string osHostname: ""
    property string osUptime: ""

    CommandSource {
        id: osInfoSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            osInfoSource.disconnectSource(sourceName);
            const lines = (data["stdout"] || "").split('\n');
            core.osDistro = (lines[0] || "").trim() || "Linux";
            core.osKernel = (lines[1] || "").trim();
            core.osHostname = (lines[2] || "").trim();
            core.osUptime = (lines[3] || "").trim();
        }
    }

    Timer {
        interval: core._pollBase * 30
        running: core.showOsInfo && core.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const cmd = "grep -m1 PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"'; " + "uname -r 2>/dev/null; " + "cat /etc/hostname 2>/dev/null || hostname 2>/dev/null; " + "awk '{d=int($1/86400);h=int(($1%86400)/3600);m=int(($1%3600)/60);" + "if(d>0)printf \"%dd %dh %dm\\n\",d,h,m;" + "else if(h>0)printf \"%dh %dm\\n\",h,m;" + "else printf \"%dm\\n\",m}' /proc/uptime 2>/dev/null";
            osInfoSource.connectSource(core.shellCmd(cmd));
        }
    }

    // ── OS Info: "fetch" tool integration ─────────────────────────────────────
    // The four values above always come from the cheap built-in reader (the
    // compact representation depends on osUptime). When a fetch tool is present
    // it additionally fills osFetchRows / osFetchRaw, which the section prefers.
    property var osFetchRows: []       // [{lbl, val}] parsed from the tool
    property string osFetchRaw: ""     // ANSI-stripped verbatim output
    property string osFetchTool: ""    // binary that won detection, "" = none
    property string osFetchTitle: ""   // e.g. "user@host" banner line
    property string osLogoIcon: ""     // freedesktop icon name from os-release
    property bool isReadingOsFetch: false
    readonly property bool osFetchActive: !!cfg.osUseFetch && core.osFetchTool !== ""
    // Rows after the user's exclude/reorder rules. Keys the user has never seen
    // are kept and appended in tool order, so a tool update that adds a field
    // surfaces it instead of silently dropping it.
    readonly property var osFetchVisibleRows: OsFetch.applyRules(core.osFetchRows, cfg.osFieldRules || [])

    CommandSource {
        id: osFetchSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingOsFetch = false;
            osFetchSource.disconnectSource(sourceName);
            core.parseOsFetch(data["stdout"] || "");
        }
    }

    Timer {
        // Deliberately slower than the built-in reader: a full fetch run forks a
        // sizeable process (~0.5 s on some distros, package counting dominates).
        interval: core._pollBase * 60
        running: core.showOsInfo && core.active && !!cfg.osUseFetch
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!core.isReadingOsFetch) {
                core.isReadingOsFetch = true;
                osFetchSource.connectSource(OsFetch.probeCmd(cfg.osFetchCmd));
            }
        }
    }

    function parseOsFetch(out) {
        const r = OsFetch.parse(out);
        core.osFetchTool = r.tool;
        core.osFetchRows = r.rows;
        core.osFetchRaw = r.raw;
        core.osFetchTitle = r.title;
        if (r.logo)
            core.osLogoIcon = r.logo;
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

    CommandSource {
        id: powerSource
        sourceComponent: core.commandSourceComponent
        onNewData: function (sourceName, data) {
            core.isReadingPower = false;
            powerSource.disconnectSource(sourceName);
            core.parsePowerData(data["stdout"] || "");
        }
    }

    Timer {
        interval: core._pollBase * 5
        running: core.showPowerSection && core.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!core.isReadingPower) {
                core.isReadingPower = true;
                const cmd = "for p in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1 " + "/sys/class/power_supply/battery /sys/class/power_supply/BATT; do " + "[ -f $p/capacity ] || continue; " + "echo bat=$(cat $p/capacity 2>/dev/null); " + "echo status=$(cat $p/status 2>/dev/null); " + "[ -f $p/cycle_count ] && echo cycles=$(cat $p/cycle_count 2>/dev/null); " + "[ -f $p/temp ] && echo temp=$(cat $p/temp 2>/dev/null); " + "en=$(cat $p/energy_now 2>/dev/null); " + "ef=$(cat $p/energy_full 2>/dev/null); " + "ed=$(cat $p/energy_full_design 2>/dev/null); " + "if [ -n \"$en\" ]; then echo useEnergy=1; else en=$(cat $p/charge_now 2>/dev/null); ef=$(cat $p/charge_full 2>/dev/null); ed=$(cat $p/charge_full_design 2>/dev/null); echo useEnergy=0; fi; " + "echo enow=${en:-0}; echo efull=${ef:-0}; echo edesign=${ed:-0}; " + "pw=$(cat $p/power_now 2>/dev/null); " + "if [ -z \"$pw\" ]; then v=$(cat $p/voltage_now 2>/dev/null); c=$(cat $p/current_now 2>/dev/null); " + "[ -n \"$v\" ] && [ -n \"$c\" ] && pw=$(awk -v v=\"$v\" -v c=\"$c\" 'BEGIN{printf \"%d\", v*c/1000000}'); fi; " + "echo power=${pw:-0}; break; done; " + "[ -f /proc/pressure/cpu ] && sed 's/^/cpu /' /proc/pressure/cpu 2>/dev/null | head -1; " + "[ -f /proc/pressure/memory ] && sed 's/^/mem /' /proc/pressure/memory 2>/dev/null | head -1";
                powerSource.connectSource(core.shellCmd(cmd));
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

        core.batteryPresent = bat >= 0;
        if (bat >= 0)
            core.batteryPercent = bat;
        if (status)
            core.batteryStatus = status;

        // Sign convention: + when charging, - when discharging. sysfs power_now
        // is usually unsigned and we infer direction from status.
        let pw = Math.abs(powerUW) / 1000000.0;
        if (status === 'Discharging')
            pw = -pw;
        else if (status !== 'Charging')
            pw = (status === 'Full' || pw < 0.05) ? 0 : pw;
        core.batteryPowerW = pw;

        // History for sparkline (absolute value)
        core.batteryPowerHistory = core.appendHistory(core.batteryPowerHistory, Math.abs(pw));

        // Diagnostics
        core.batteryCycles = cycles;
        core.batteryTempC = tempDeci > -1000 ? tempDeci / 10.0 : -999;
        core.batteryHealthPct = (edesign > 0 && efull > 0) ? (efull / edesign * 100.0) : 0;

        // Time remaining only when units are µWh and we actually have power flow
        if (useEnergy && Math.abs(powerUW) > 1000 && enow > 0 && efull > 0) {
            if (status === 'Discharging')
                core.batteryTimeRemainHours = enow / Math.abs(powerUW);
            else if (status === 'Charging' && efull > enow)
                core.batteryTimeRemainHours = (efull - enow) / Math.abs(powerUW);
            else
                core.batteryTimeRemainHours = 0;
        } else {
            core.batteryTimeRemainHours = 0;
        }

        core.cpuPressureAvg10 = cpuAvg10;
        core.memPressureAvg10 = memAvg10;
    }

    // ── shared interaction state ──────────────────────────────────────────────
    property string hoveredLine: ""
    property int hoveredCore: -1

    function isLineDisabled(key) {
        return (cfg.disabledLinesStr || "").split(",").filter(Boolean).indexOf(key) !== -1;
    }
    function toggleLineDisabled(key) {
        let arr = (cfg.disabledLinesStr || "").split(",").filter(Boolean);
        if (arr.indexOf(key) !== -1)
            arr = arr.filter(k => k !== key);
        else
            arr.push(key);
        core.writeConfig("disabledLinesStr", arr.join(","));
    }
    function isCoreDisabled(idx) {
        return (cfg.disabledCoresStr || "").split(",").filter(Boolean).indexOf(idx.toString()) !== -1;
    }
    function toggleCoreDisabled(idx) {
        let arr = (cfg.disabledCoresStr || "").split(",").filter(Boolean);
        if (arr.indexOf(idx.toString()) !== -1)
            arr = arr.filter(k => k !== idx.toString());
        else
            arr.push(idx.toString());
        core.writeConfig("disabledCoresStr", arr.join(","));
    }
}
