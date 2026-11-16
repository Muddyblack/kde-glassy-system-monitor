import QtQuick
import "../../package/contents/ui/Probes.js" as Probes

// Applies windows/sampler.py's readings to a MonitorCore started with
// `live: false`, through the same sample functions the Linux probes and
// DemoFeeder end in. Nothing here keeps history: MonitorCore caps its own, and
// the one thing held between readings (the last process snapshot) is replaced
// on every update.
QtObject {
    id: feeder

    required property var monitor
    // The Sampler, or null (--selftest): the feeder then does nothing.
    property var sampler: null

    property var _processes: null

    // The adapter the section follows: the configured one, else the default
    // route's, else whichever moved the most bytes.
    function _network(d) {
        const m = monitor;
        const rates = d.ifaceRates || {};
        const names = Object.keys(rates);
        let busiest = "", most = -1;
        for (const name of names) {
            const total = rates[name].rx + rates[name].tx;
            if (total > most) {
                most = total;
                busiest = name;
            }
        }
        if (d.interfaces)
            m.interfaces = d.interfaces;
        m.ifaceRates = rates;
        const wanted = ["auto"].concat(names);
        if (wanted.length !== m.availableIfaces.length || wanted.some((n, i) => n !== m.availableIfaces[i]))
            m.availableIfaces = wanted;
        m.autoIface = Probes.autoInterface(m.interfaces, rates, busiest);
        const chosen = (m.cfg.networkInterface || "auto");
        const iface = chosen !== "auto" && rates[chosen] ? chosen : rates[m.autoIface] ? m.autoIface : busiest;
        if (!iface)
            return;
        m.activeIface = iface;
        m.applyNetSample(rates[iface].rx, rates[iface].tx, d.dt);
    }

    function _disk(d) {
        const m = monitor;
        const rates = d.diskRates || {};
        const names = Object.keys(rates);
        let busiest = "", most = -1;
        for (const name of names) {
            const total = rates[name].rd + rates[name].wr;
            if (total > most) {
                most = total;
                busiest = name;
            }
        }
        const wanted = ["auto"].concat(names);
        if (wanted.length !== m.availableDisks.length || wanted.some((n, i) => n !== m.availableDisks[i]))
            m.availableDisks = wanted;
        m.autoDisk = busiest;
        const chosen = (m.cfg.diskDevice || "auto");
        const disk = chosen !== "auto" && rates[chosen] ? chosen : busiest;
        if (!disk)
            return;
        m.activeDisk = disk;
        m.applyDiskSample(rates[disk].rd, rates[disk].wr);
    }

    function _storage(rows) {
        const wanted = String(monitor.cfg.storageMounts || "").split(",").map(s => s.trim()).filter(s => s);
        let list = rows.filter(r => wanted.length ? wanted.indexOf(r.mount) !== -1 : r.size >= 256 * 1024 * 1024);
        if (wanted.length)
            list.sort((a, b) => wanted.indexOf(a.mount) - wanted.indexOf(b.mount));
        else
            list.sort((a, b) => a.mount < b.mount ? -1 : 1);
        monitor.storage = list;
    }

    function _gpu(g) {
        const m = monitor;
        if (!g)
            return;
        m.gpuDetected = true;
        m.gpuVendor = g.vendor || "";
        m.gpuPercent = g.percent || 0;
        m.gpuComputePercent = g.percent || 0;
        m.gpuFreqMhz = g.freqMhz || 0;
        m.gpuVramUsed = g.vramUsed !== undefined ? g.vramUsed : -1;
        m.gpuVramTotal = g.vramTotal !== undefined ? g.vramTotal : -1;
        m.gpuHistory = m.appendHistory(m.gpuHistory, m.gpuPercent);
    }

    // Fans: a header reading 0 RPM shows only once it has been seen turning,
    // as Probes.parseFans does for lm-sensors.
    function _fans(list) {
        const m = monitor;
        const peaks = Object.assign({}, m.fanPeaks);
        const shown = [];
        for (const f of list) {
            peaks[f.key] = Math.max(peaks[f.key] || 0, f.rpm);
            if (peaks[f.key] > 0)
                shown.push(f);
        }
        m.fans = shown;
        m.fanPeaks = peaks;
        m.fansRead = true;
    }

    function _power(list) {
        const m = monitor;
        m.powerSources = list;
        if (!list.length)
            return;
        m.powerLoadW = list.reduce((sum, x) => sum + x.watts, 0);
        m.powerLoadHistory = m.appendHistory(m.powerLoadHistory, m.powerLoadW);
    }

    function _battery(b) {
        const m = monitor;
        m.batteryPresent = !!b;
        if (!b)
            return;
        m.batteryPercent = b.percent;
        m.batteryStatus = b.status;
        m.acOnline = b.plugged ? 1 : 0;
        m.batteryTimeRemainHours = b.hours;
        m.batteryPercentHistory = m.appendHistory(m.batteryPercentHistory, b.percent);
    }

    function _system(s) {
        const m = monitor;
        m.osDistro = s.distro;
        m.osVersion = s.version;
        m.osKernel = s.kernel;
        m.osHostname = s.hostname;
        m.osUptime = s.uptime;
    }

    function apply(d) {
        const m = monitor;
        if (d.error !== undefined)
            console.warn("glassy sampler:", d.error);
        if (d.cpu !== undefined)
            m.applyCpuSample(d.cpu, d.cores);
        if (d.memTotal !== undefined)
            m.applyMemSample(d.memUsed, d.memTotal, d.swapUsed, d.swapTotal);
        if (d.ifaceRates !== undefined)
            _network(d);
        else if (d.interfaces !== undefined)
            m.interfaces = d.interfaces;
        if (d.diskRates !== undefined)
            _disk(d);
        if (d.storage !== undefined)
            _storage(d.storage);
        if (d.procSnapshot !== undefined) {
            const cfg = m.cfg;
            if (_processes)
                m.processes = Probes.topProcesses(_processes, d.procSnapshot, cfg.processCount || 5, cfg.processSort || "cpu", cfg.processGroup !== false);
            _processes = d.procSnapshot;
        }
        if (d.load !== undefined) {
            m.applyLoadSample(d.load);
        }
        if (d.system !== undefined)
            _system(d.system);
        if (d.battery !== undefined)
            _battery(d.battery);
        if (d.gpu !== undefined)
            _gpu(d.gpu);
        if (d.hwGroups !== undefined)
            m.applyHwSensorUpdate(d.hwGroups);
        if (d.fans !== undefined)
            _fans(d.fans);
        if (d.powerSources !== undefined)
            _power(d.powerSources);
        if (d.containers !== undefined) {
            m.containerInfo = Probes.parseContainerList(d.containers);
            m.containersRead = true;
        }
        if (d.ping !== undefined) {
            m.lastPingTimestamp = Date.now();
            m.addPingResult(d.ping.index, d.ping.ms);
        }
        if (sampler)
            sampler.acknowledge();
    }

    // Stop holding the last snapshot when no process section needs it.
    function release() {
        _processes = null;
    }
}
