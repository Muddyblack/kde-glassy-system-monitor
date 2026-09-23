import QtQuick
import "DemoData.js" as DemoData
import "Probes.js" as Probes

// Plausible, always-moving readings for a MonitorCore with `live: false`:
// the studio's Demo preview and the website screenshots. Everything goes in
// through the same sample functions the real sensors use.
QtObject {
    id: feeder

    required property var monitor
    property bool running: true
    property int intervalMs: 1000
    property int t: 0

    function readings(i) {
        return DemoData.readings(i);
    }
    function push(i) {
        const m = monitor;
        const r = readings(i);
        m.applyCpuSample(r.cpu, r.cores);
        if (i % 2 === 0)
            m.applyMemSample(r.mem / 100 * DemoData.MEM_TOTAL, DemoData.MEM_TOTAL, r.swap / 100 * DemoData.SWAP_TOTAL, DemoData.SWAP_TOTAL);
        m.applyNetSample(r.dl, r.ul, intervalMs / 1000);
        m.ifaceRates = {
            wlp2s0: {
                rx: r.dl,
                tx: r.ul
            },
            wg0: {
                rx: r.dl * 0.01,
                tx: r.ul * 0.05
            }
        };
        m.applyDiskSample(r.rd, r.wr);
        m.addPingResult(m.activeTarget, r.ping);
        m.gpuVendor = "amd";
        m.gpuPercent = r.gpu;
        m.gpuFreqMhz = Math.round(1200 + r.gpu * 12);
        m.gpuVramUsed = 5.2 * 1073741824;
        m.gpuVramTotal = 16 * 1073741824;
        m.gpuComputePercent = r.gpu;
        m.gpuDecPercent = 4;
        m.gpuEncPercent = 0;
        m.gpuHistory = m.appendHistory(m.gpuHistory, r.gpu);
        m.customValue = r.custom;
        m.customHistory = m.appendHistory(m.customHistory, r.custom);
        m.batteryPresent = true;
        m.batteryPercent = DemoData.BATTERY.percent;
        m.batteryStatus = DemoData.BATTERY.status;
        m.batteryPowerW = -r.watts;
        m.batteryHealthPct = DemoData.BATTERY.health;
        m.batteryCycles = DemoData.BATTERY.cycles;
        m.batteryTempC = DemoData.BATTERY.temp;
        m.batteryTimeRemainHours = DemoData.BATTERY.hours;
        m.batteryPowerHistory = m.appendHistory(m.batteryPowerHistory, r.watts);
        m.cpuPressureAvg10 = r.cpu / 12;
        m.memPressureAvg10 = 0.4;
        // Storage and processes go through the real parsers and ranking, so
        // the mount filter, sort, row count and grouping all show.
        const cfg = m.cfg;
        m.storage = Probes.parseStorage(DemoData.DF, cfg.storageMounts);
        m.processes = Probes.topProcesses(DemoData.procSnapshot(i - 1), DemoData.procSnapshot(i), cfg.processCount || 5, cfg.processSort || "cpu", cfg.processGroup !== false);
    }
    // Full charts from the first frame: histories are filled directly, so the
    // sample clocks see one sample rather than a burst.
    function prefill() {
        const m = monitor;
        const n = Math.max(10, m.cfg.historySize || 60) + 1;
        const list = Array.from({
            length: n
        }, (_, k) => readings(k - n));
        m.cpuHistory = list.map(r => r.cpu);
        m.coreHistories = list[0].cores.map((_, c) => list.map(r => r.cores[c]));
        m.corePercents = list[n - 1].cores;
        m.memHistory = list.map(r => r.mem);
        m.swapHistory = list.map(r => r.swap);
        m.dlHistory = list.map(r => r.dl);
        m.ulHistory = list.map(r => r.ul);
        m.diskReadHistory = list.map(r => r.rd);
        m.diskWriteHistory = list.map(r => r.wr);
        m.histories = m.targetList.map(() => list.map(r => r.ping));
        m.gpuHistory = list.map(r => r.gpu);
        m.customHistory = list.map(r => r.custom);
        m.batteryPowerHistory = list.map(r => r.watts);
        m.activeIface = "wlp2s0";
        m.autoIface = "wlp2s0";
        m.availableIfaces = ["auto", "wlp2s0", "enp5s0", "wg0", "docker0"];
        m.interfaces = Probes.parseInterfaces(DemoData.NET_INTERFACES);
        m.activeDisk = "nvme0n1";
        m.availableDisks = ["auto", "nvme0n1", "sda"];
        m.sessionDlBytes = 3.4 * 1073741824;
        m.sessionUlBytes = 0.6 * 1073741824;
        m.osDistro = DemoData.SYSTEM.distro;
        m.osKernel = DemoData.SYSTEM.kernel;
        m.osHostname = DemoData.SYSTEM.hostname;
        m.osUptime = DemoData.SYSTEM.uptime;
        m.applyHwSensorUpdate(DemoData.SENSORS);
        push(0);
    }

    property Timer ticker: Timer {
        interval: feeder.intervalMs
        repeat: true
        running: feeder.running
        onTriggered: feeder.push(++feeder.t)
    }
    Component.onCompleted: prefill()
}
