// Data from the ksystemstats daemon instead of our own subprocesses.
//
// ksystemstats is the C++ daemon behind Plasma's own system monitor widgets. It
// reads /proc in-process on a fixed 500 ms tick and pushes values to every
// subscriber over D-Bus, so the reading happens once for the whole machine no
// matter how many widgets want it. Subscribing costs us a handful of floats per
// frame — no fork, no exec, no shell, no parsing.
//
// That is the whole point of this file: it replaces the per-second `cat` with
// values somebody else has already computed, which is why it can run *faster*
// than the polling it replaces while costing less. 500 ms is the floor, and it
// is the same floor Plasma's own widgets hit when set to "No Limit".
//
// IMPORTANT: this is a separate file on purpose. A QML import that cannot be
// resolved is a fatal error for the entire file, so importing libksysguard in
// main.qml would break the widget outright on a system without it. Kept here,
// main.qml loads it through a Loader and falls back to the /proc path when the
// module is missing — see sensorLoader in main.qml.
import QtQuick
import org.kde.ksysguard.sensors as KSysGuard

Item {
    id: backend

    // The root PlasmoidItem. Passed in rather than leaning on the `root` id, so
    // this file has exactly one declared connection to the rest of the widget.
    required property var host

    // ── sampling ──────────────────────────────────────────────────────────────
    // The daemon reads on a fixed 500 ms tick and pushes over D-Bus. We take one
    // sample per delivery — the daemon's tick is our clock — and the only reason
    // that needs explaining is that the obvious alternative, our own timer at the
    // user's interval, is subtly and badly wrong.
    //
    // A free-running timer beats against the daemon. At an interval of exactly
    // 500 ms the two run at the same rate with an arbitrary relative phase, and
    // event-loop jitter of a few milliseconds walks our read back and forth
    // across the daemon's update boundary: land just before it and we read the
    // previous value a second time, land just after and the frame we skipped is
    // gone for good. A duplicated sample draws a flat step and a skipped one
    // draws a double-height jump, so the line judders in place while scrolling
    // perfectly evenly — the scroll is fine, the DATA is aliased. Doubling the
    // interval hides it (two daemon frames per sample leaves a quarter second of
    // margin on either side) which is exactly why 1000 ms looked smooth and
    // 500 ms did not. Sampling on delivery cannot alias at any interval: there
    // is one sample per frame by construction.
    //
    // What a timer did buy — and what the two guards below buy back — is that a
    // delivery carries only what CHANGED. An idle interface reports the same
    // 0 B/s forever and emits nothing at all, so arrivals alone would leave that
    // graph frozen until traffic resumed.
    readonly property int daemonTickMs: 500

    // Deliveries can only land on the daemon's tick, so the achievable rates are
    // whole multiples of it; anything else the user asks for rounds to the
    // nearest one rather than pretending to a cadence the data cannot have.
    readonly property int daemonFramesPerSample: Math.max(1, Math.round(host.updateIntervalMs / daemonTickMs))
    readonly property int sampleIntervalMs: daemonFramesPerSample * daemonTickMs

    // Set half a frame UNDER the target: the rate limiter drops a delivery whose
    // gap since the last one is below this, and asking for the gap exactly would
    // put the test on a knife edge that a millisecond of jitter tips the wrong
    // way — dropping a frame we wanted and delivering at double the interval.
    // One frame per sample needs no limiter at all.
    readonly property int rateLimit: daemonFramesPerSample > 1 ? sampleIntervalMs - Math.floor(daemonTickMs / 2) : 0

    // ── readiness ─────────────────────────────────────────────────────────────
    // Sensors resolve asynchronously: the object exists at once but carries no
    // status until the daemon answers a metadata request. Until one reports
    // Ready we do not claim the backend works, which is what catches
    // "libksysguard is installed but ksystemstats is not running" — there the
    // import succeeds and nothing ever answers.
    readonly property bool ready: cpuTotal.status === KSysGuard.Sensor.Ready

    readonly property bool wanted: backend.host.showCpuSection || backend.host.showMemorySection || backend.host.showNetworkSpeed || backend.host.showDiskSection

    // Any value arriving means the daemon has ticked. Which value it was does not
    // matter — one tick becomes one sample for every group, so a network that has
    // not moved still gets its 0 appended on the frame the CPU moved.
    function _noteFrame() {
        frameCollapse.restart();
    }

    // A frame arrives as several D-Bus signals. Collapsing them through a
    // zero-interval timer turns however many land into the single sample that
    // runs once the engine returns to the event loop, by which point the whole
    // frame is in.
    Timer {
        id: frameCollapse
        interval: 0
        onTriggered: backend._takeSample()
    }

    // Upper bound on the gap. If every value we subscribe to holds still — an
    // idle link on a widget showing nothing but network — no delivery is made at
    // all, and this keeps the sample cadence going so the graph scrolls on flat
    // instead of freezing. Restarted by every sample, so it only ever fires when
    // the deliveries themselves have stopped.
    Timer {
        id: watchdog
        interval: backend.sampleIntervalMs * 2
        repeat: true
        running: backend.ready && backend.wanted
        onTriggered: backend._takeSample()
    }

    property real _lastSampleMs: 0
    // Counts samples so memory can ride on every second one, the half-rate
    // cadence it had as a standalone poll — the memory graph's time span depends
    // on how often a sample is appended to it.
    property int _sampleTick: 0

    function _takeSample() {
        const now = Date.now();
        // Lower bound on the gap, and the mirror of the watchdog above. Two
        // deliveries dispatched in separate event-loop turns would otherwise
        // collapse into two samples instead of one and scroll the charts at
        // double their real rate; half an interval is well clear of the jitter
        // on a real frame and well under a genuine one.
        if (backend._lastSampleMs > 0 && now - backend._lastSampleMs < backend.sampleIntervalMs * 0.5)
            return;
        backend._lastSampleMs = now;
        watchdog.restart();
        // Each _push is a no-op for a section that is not shown, and drops the
        // sample if the daemon has not answered for it yet.
        backend._pushCpu();
        if ((backend._sampleTick % 2) === 0)
            backend._pushMem();
        backend._pushNet();
        backend._pushDisk();
        backend._sampleTick = (backend._sampleTick + 1) & 0x7fffffff;
    }

    // Sensor ids are "<container>/<object>/<property>".

    // ── CPU ───────────────────────────────────────────────────────────────────
    // Doubles as the availability probe behind `ready`, and is still gated on the
    // section. Both work at once because libksysguard requests a sensor's
    // metadata whether or not it is enabled, and only the *value* subscription
    // follows `enabled`. So the status below proves the daemon is answering,
    // while a widget showing some other section never makes it read /proc/stat.
    KSysGuard.Sensor {
        id: cpuTotal
        sensorId: "cpu/all/usage"
        enabled: backend.host.showCpuSection
        onValueChanged: backend._noteFrame()
        updateRateLimit: backend.rateLimit
    }

    // How many per-core objects the daemon exposes, used to build the sensor
    // list once.
    //
    // This must be coreCount, NOT cpuCount. The daemon fills cpuCount from the
    // "physical id" field of /proc/cpuinfo, so it counts *sockets* — 1 on any
    // ordinary desktop — while coreCount is the number of cpuN objects it
    // actually created, which is the logical CPU count and the range that
    // "cpu/cpuN/usage" is valid over.
    KSysGuard.Sensor {
        id: coreCount
        sensorId: "cpu/all/coreCount"
        enabled: backend.host.showCpuSection && plasmoid.configuration.showCpuCores
    }

    // Per-core usage as one model rather than N Sensor objects: a single
    // subscription for the whole set, and one place to read a row of values
    // from. Columns follow the order of `sensors`; the model is a table whose
    // single row carries the current frame.
    KSysGuard.SensorDataModel {
        id: coreModel
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showCpuSection && plasmoid.configuration.showCpuCores
        // The section check is repeated here rather than left to `enabled` above,
        // because SensorDataModel subscribes the moment `sensors` is assigned and
        // does not consult `enabled` when it does so. An empty list is the only
        // thing that reliably means "subscribe to nothing".
        sensors: {
            if (!backend.host.showCpuSection || !plasmoid.configuration.showCpuCores)
                return [];
            const n = parseInt(coreCount.value);
            if (!(n > 0))
                return [];
            const ids = [];
            for (let i = 0; i < n; i++)
                ids.push("cpu/cpu" + i + "/usage");
            return ids;
        }
    }

    // Total and cores are read in the same call, so one append covers both and
    // the two can never drift apart in the history.
    function _pushCpu() {
        if (!backend.host.showCpuSection)
            return;
        const total = parseFloat(cpuTotal.value);
        if (isNaN(total))
            return;
        const cores = [];
        // Read the raw numbers: the default display role returns a *formatted*
        // string ("42 %"), which parseFloat would mangle on some locales.
        if (coreModel.rowCount() > 0) {
            for (let c = 0; c < coreModel.columnCount(); c++) {
                const v = parseFloat(coreModel.data(coreModel.index(0, c), KSysGuard.SensorDataModel.Value));
                cores.push(isNaN(v) ? 0 : v);
            }
        }
        backend.host.applyCpuSample(total, cores);
    }

    // ── memory ────────────────────────────────────────────────────────────────
    // Reported in bytes, which is what applyMemSample takes.
    KSysGuard.Sensor {
        id: memUsed
        sensorId: "memory/physical/used"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showMemorySection
        onValueChanged: backend._noteFrame()
    }
    KSysGuard.Sensor {
        id: memTotal
        sensorId: "memory/physical/total"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showMemorySection
        onValueChanged: backend._noteFrame()
    }
    KSysGuard.Sensor {
        id: swapUsed
        sensorId: "memory/swap/used"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showMemorySection
        onValueChanged: backend._noteFrame()
    }
    KSysGuard.Sensor {
        id: swapTotal
        sensorId: "memory/swap/total"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showMemorySection
        onValueChanged: backend._noteFrame()
    }
    // A sample taken before the total has landed is dropped rather than divided
    // by zero; the next tick simply takes it again. The swap totals are read
    // fresh every time for the same reason they are here at all — they move on a
    // swapon/swapoff, and the section has to follow that.
    function _pushMem() {
        if (!backend.host.showMemorySection)
            return;
        const used = parseFloat(memUsed.value), total = parseFloat(memTotal.value);
        if (isNaN(used) || isNaN(total))
            return;
        const sUsed = parseFloat(swapUsed.value), sTotal = parseFloat(swapTotal.value);
        backend.host.applyMemSample(used, total, isNaN(sUsed) ? 0 : sUsed, isNaN(sTotal) ? 0 : sTotal);
    }

    // ── network ───────────────────────────────────────────────────────────────
    // The daemon reports a rate directly, so there is no counter delta to take.
    // The device name comes from the host, which still enumerates interfaces on
    // a slow timer so that "auto" and the interface picker keep working; until
    // that lands we ride the daemon's own aggregate.
    readonly property string netObject: backend.host.resolvedIface || "all"

    KSysGuard.Sensor {
        id: netDown
        sensorId: "network/" + backend.netObject + "/download"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showNetworkSpeed
        onValueChanged: backend._noteFrame()
    }
    KSysGuard.Sensor {
        id: netUp
        sensorId: "network/" + backend.netObject + "/upload"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showNetworkSpeed
        onValueChanged: backend._noteFrame()
    }
    // Interface identity, which used to cost a shell pipeline through
    // iwgetid / iw / nmcli / ip. The daemon's aggregate object has no identity
    // of its own, so this only applies to a named device.
    readonly property bool netIdentityUsable: backend.host.showNetworkSpeed && plasmoid.configuration.netShowInfo && backend.netObject !== "all"

    KSysGuard.Sensor {
        id: netSsid
        sensorId: "network/" + backend.netObject + "/network"
        enabled: backend.netIdentityUsable
        onValueChanged: if (backend.netIdentityUsable)
            backend.host.netSsid = (value === undefined ? "" : value).toString()
    }
    KSysGuard.Sensor {
        id: netIp
        sensorId: "network/" + backend.netObject + "/ipv4address"
        enabled: backend.netIdentityUsable
        onValueChanged: if (backend.netIdentityUsable)
            backend.host.netIpAddr = (value === undefined ? "" : value).toString()
    }

    property real _lastNetPushMs: 0

    function _pushNet() {
        if (!backend.host.showNetworkSpeed)
            return;
        const dl = parseFloat(netDown.value), ul = parseFloat(netUp.value);
        if (isNaN(dl) || isNaN(ul))
            return;
        // Session totals integrate the rate, so they need the span each rate
        // stood for — measured, because a dropped frame makes it longer than the
        // nominal tick. The first sample has nothing to integrate over.
        const now = Date.now();
        const dt = backend._lastNetPushMs > 0 ? (now - backend._lastNetPushMs) / 1000 : 0;
        backend._lastNetPushMs = now;
        backend.host.applyNetSample(dl, ul, dt);
    }

    // ── disk ──────────────────────────────────────────────────────────────────
    readonly property string diskObject: backend.host.resolvedDisk || "all"

    KSysGuard.Sensor {
        id: diskRead
        sensorId: "disk/" + backend.diskObject + "/read"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showDiskSection
        onValueChanged: backend._noteFrame()
    }
    KSysGuard.Sensor {
        id: diskWrite
        sensorId: "disk/" + backend.diskObject + "/write"
        updateRateLimit: backend.rateLimit
        enabled: backend.host.showDiskSection
        onValueChanged: backend._noteFrame()
    }
    // DiskSection owns its own state, so the sample is handed over by signal,
    // exactly as the /proc/diskstats block is.
    signal diskSample(real readBytesPerSec, real writeBytesPerSec)

    function _pushDisk() {
        if (!backend.host.showDiskSection)
            return;
        const rd = parseFloat(diskRead.value), wr = parseFloat(diskWrite.value);
        if (isNaN(rd) || isNaN(wr))
            return;
        diskSample(rd, wr);
    }
}
