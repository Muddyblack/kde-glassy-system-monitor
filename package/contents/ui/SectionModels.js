.pragma library
.import "Sections.js" as Sections
.import "Format.js" as Format
.import "diagram/DiagramData.js" as DiagramData

// What each chart section shows: title, headline reading, chart scale and
// series, legend. The QML sections and the website studio both build from
// these, so a series added here appears in the widget and on the site.
//
// `m` is a MonitorCore (or the website's demo stand-in with the same property
// names), `cfg` the settings, `style` the chart style being drawn.

function color(cfg, key, fallback) {
    return String(cfg[key] || fallback);
}
function hidden(m, key) {
    return m.isLineDisabled ? m.isLineDisabled(key) : false;
}
// Other lines fade while one is hovered in the legend.
function dim(m, key) {
    return m.hoveredLine && m.hoveredLine !== key ? 0.2 : 1;
}
function scrolls(style) {
    return DiagramData.scrolls(style);
}

// Colour by load: 0 normal, 1 past the warning level, 2 past critical.
// Lines recolour per sample (shader bands); gauges and readings by the
// current value.
function loadBand(cfg, percent) {
    if (!cfg.loadColors)
        return 0;
    return percent >= (cfg.loadCrit || 90) ? 2 : percent >= (cfg.loadWarn || 70) ? 1 : 0;
}
function loadTint(cfg, base, percent) {
    return [base, color(cfg, "loadWarnColor", "#ffaa22"), color(cfg, "loadCritColor", "#ff4444")][loadBand(cfg, percent)];
}
function loadBands(cfg, values) {
    return cfg.loadColors ? values.map(function (v) { return loadBand(cfg, v); }) : undefined;
}
// Band colours and the warning line for percent charts.
function loadChart(cfg, model) {
    if (cfg.loadColors) {
        model.bands = [color(cfg, "loadWarnColor", "#ffaa22"), color(cfg, "loadCritColor", "#ff4444")];
        model.markers = [{ value: cfg.loadWarn || 70, color: model.bands[0] }];
    }
    return model;
}

function cpu(m, cfg) {
    var tint = color(cfg, "cpuColor", "#44ddaa");
    var coreColors = String(cfg.coreColorsStr || "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb").split(",");
    var cores = !!cfg.showCpuCores && m.corePercents.length > 0;
    var reading = m.cpuPercent.toFixed(1) + "%";
    return loadChart(cfg, {
        title: Sections.title("cpu", cfg),
        reading: reading,
        readingColor: loadTint(cfg, tint, m.cpuPercent),
        maxValue: 100,
        ticks: Format.PERCENT_TICKS,
        centerText: reading,
        centerSubText: "cpu",
        coreColors: coreColors,
        cores: cores,
        series: function (style) {
            var list = [];
            var scrolling = scrolls(style), meter = style === "meter";
            var coreHover = m.hoveredCore !== undefined && m.hoveredCore !== -1;
            if (!hidden(m, "cpuTotal") && !(meter && cores))
                list.push({
                    values: m.cpuHistory, value: m.cpuPercent, color: scrolling ? tint : loadTint(cfg, tint, m.cpuPercent),
                    bands: scrolling ? loadBands(cfg, m.cpuHistory) : undefined,
                    alpha: coreHover && m.hoveredLine !== "cpuTotal" ? 0.15 : 1,
                    // The cores would cover the fill and muddy the chart.
                    fill: cores && m.hoveredLine !== "cpuTotal" ? 0 : undefined,
                    label: "CPU total", text: reading
                });
            if (cores) {
                // Gauges nest at most eight core rings inside the total.
                var limit = scrolling || meter ? m.coreHistories.length : Math.min(8, m.coreHistories.length);
                var width = Number(cfg.lineWidth || 2.2);
                for (var i = 0; i < limit; i++) {
                    if (m.isCoreDisabled && m.isCoreDisabled(i))
                        continue;
                    var hovered = m.hoveredCore === i;
                    var ring = 1 - (i + 1) * 0.1;
                    if (!scrolling && !meter && ring < 0.25)
                        break;
                    list.push({
                        values: m.coreHistories[i] || [], value: m.corePercents[i] || 0,
                        color: coreColors[i % coreColors.length],
                        alpha: hovered ? 1 : (coreHover || m.hoveredLine === "cpuTotal") ? 0.10 : scrolling ? 0.32 : 0.8,
                        width: hovered ? width : Math.max(0.5, width * 0.45),
                        fill: 0, glow: hovered, ring: [ring, 0.3],
                        label: "C" + (i + 1), text: (m.corePercents[i] || 0).toFixed(0) + "%"
                    });
                }
            }
            return list;
        },
        legend: cores ? [] : [{ key: "cpuTotal", label: "Total", value: reading, color: tint }]
    });
}

function memory(m, cfg) {
    var mem = color(cfg, "memColor", "#aa66ff"), swap = color(cfg, "swapColor", "#ff6688");
    var used = m.memUsedGiB.toFixed(1) + " / " + m.memTotalGiB.toFixed(1) + " GiB";
    return loadChart(cfg, {
        title: Sections.title("memory", cfg),
        reading: m.memPercent.toFixed(0) + "%",
        readingColor: loadTint(cfg, mem, m.memPercent),
        maxValue: 100,
        ticks: Format.PERCENT_TICKS,
        centerText: m.memUsedGiB.toFixed(1) + " GiB",
        centerSubText: "of " + m.memTotalGiB.toFixed(1) + " GiB",
        series: function (style) {
            var list = [];
            // Swap first: behind RAM in line charts, inside it in gauges.
            if (m.hasSwap && !hidden(m, "swap"))
                list.push({ values: m.swapHistory, value: m.swapPercent, color: swap, alpha: dim(m, "swap"), width: Number(cfg.lineWidth || 2.2) * 0.8, fill: 0, glow: false, label: "Swap", text: m.swapUsedGiB.toFixed(1) + " GiB" });
            if (!hidden(m, "ram"))
                list.push({ values: m.memHistory, value: m.memPercent, color: scrolls(style) ? mem : loadTint(cfg, mem, m.memPercent), bands: scrolls(style) ? loadBands(cfg, m.memHistory) : undefined, alpha: dim(m, "ram"), label: "RAM", text: used });
            // Gauges draw the first series as the outer ring.
            return scrolls(style) ? list : list.reverse();
        },
        legend: [{ key: "ram", label: "RAM", value: used, color: mem }].concat(m.hasSwap ? [{ key: "swap", label: "Swap", value: m.swapPercent.toFixed(0) + "%", color: swap }] : [])
    });
}

function network(m, cfg) {
    var dl = color(cfg, "dlColor", "#22aaff"), ul = color(cfg, "ulColor", "#ff9933");
    var max = DiagramData.autoMax([m.dlHistory, m.ulHistory], 1024, cfg.autoYRange ? 1.10 : 1.20);
    return {
        title: Sections.title("network", cfg),
        reading: "↕ " + Format.speed(m.downloadSpeed + m.uploadSpeed),
        readingColor: "",
        maxValue: max,
        ticks: Format.rangeTicks(max, Format.speed),
        centerText: "↓ " + Format.speed(m.downloadSpeed),
        centerSubText: "↑ " + Format.speed(m.uploadSpeed),
        series: function () {
            var list = [];
            if (!hidden(m, "dl"))
                list.push({ values: m.dlHistory, value: m.downloadSpeed, color: dl, alpha: dim(m, "dl"), label: "Download", text: Format.speed(m.downloadSpeed) });
            if (!hidden(m, "ul"))
                list.push({ values: m.ulHistory, value: m.uploadSpeed, color: ul, alpha: dim(m, "ul"), label: "Upload", text: Format.speed(m.uploadSpeed) });
            return list;
        },
        legend: [{ key: "dl", label: "Download", value: Format.speed(m.downloadSpeed), color: dl }, { key: "ul", label: "Upload", value: Format.speed(m.uploadSpeed), color: ul }],
        totals: [{ text: "↓ " + Format.bytes(m.sessionDlBytes), color: dl }, { text: "↑ " + Format.bytes(m.sessionUlBytes), color: ul }]
    };
}

// Latency band: 0 normal, 1 warning, 2 critical (half again past the threshold).
function pingBand(cfg, ms) {
    if (!cfg.pingThresholdColors || ms < 0)
        return 0;
    var threshold = cfg.latencyThreshold || 100;
    return ms > threshold * 1.5 ? 2 : ms > threshold ? 1 : 0;
}

function ping(m, cfg) {
    var ok = color(cfg, "pingColor", "#39ff14"), warn = color(cfg, "pingWarnColor", "#ffaa22"), crit = color(cfg, "pingCritColor", "#ff4444");
    var history = m.histories[m.activeTarget] || [];
    var valid = history.filter(function (v) { return v >= 0; });
    var max = Math.max(15, (valid.length ? Math.max.apply(null, valid) : 0) * 1.5 + 2);
    var reading = m.lastPing >= 0 ? m.lastPing.toFixed(0) + " ms" : "— ms";
    var alerting = !!cfg.pingThresholdColors && ((m.lastPing >= 0 && m.lastPing > (cfg.latencyThreshold || 100)) || m.lossPercent > (cfg.lossThreshold || 5));
    return {
        title: Sections.title("ping", cfg),
        reading: reading,
        readingColor: alerting ? crit : ok,
        maxValue: max,
        ticks: [{ value: max, text: max.toFixed(0) + " ms", grid: false }, { value: max / 2, text: (max / 2).toFixed(0) + " ms", grid: true }, { value: 0, text: "0", grid: false }],
        markers: [{ value: cfg.latencyThreshold || 100, color: warn }],
        bands: [warn, crit],
        gapColor: crit,
        centerText: reading,
        centerSubText: "latency",
        series: function (style) {
            return [{
                values: history, value: Math.max(0, m.lastPing),
                color: scrolls(style) ? ok : alerting ? crit : ok,
                bands: history.map(function (ms) { return pingBand(cfg, ms); }),
                gaps: true, head: true,
                label: m.targetList[m.activeTarget] || "Latency", text: reading
            }];
        },
        legend: [],
        stats: [
            { label: "AVG", value: m.avgPing > 0 ? m.avgPing.toFixed(1) + " ms" : "— ms", color: "" },
            { label: "JITTER", value: valid.length >= 2 ? m.jitter.toFixed(1) + " ms" : "— ms", color: m.jitter > (cfg.jitterThreshold || 20) ? warn : "" },
            { label: "LOSS", value: m.lossPercent.toFixed(1) + "%", color: m.lossPercent > (cfg.lossThreshold || 5) ? crit : "" },
            { label: "MIN / MAX", value: valid.length ? Math.min.apply(null, valid).toFixed(0) + " / " + Math.max.apply(null, valid).toFixed(0) + " ms" : "—", color: "" }
        ]
    };
}

function disk(m, cfg) {
    var rd = color(cfg, "diskRdColor", "#22ddff"), wr = color(cfg, "diskWrColor", "#ffaa22");
    var max = DiagramData.autoMax([m.diskReadHistory, m.diskWriteHistory], 1024 * 1024, cfg.autoYRange ? 1.10 : 1.20);
    return {
        title: Sections.title("disk", cfg),
        reading: Format.speed(m.diskReadSpeed + m.diskWriteSpeed),
        readingColor: "",
        maxValue: max,
        ticks: Format.rangeTicks(max, Format.speed),
        centerText: "R " + Format.speed(m.diskReadSpeed),
        centerSubText: "W " + Format.speed(m.diskWriteSpeed),
        series: function () {
            var list = [];
            if (!hidden(m, "diskRd"))
                list.push({ values: m.diskReadHistory, value: m.diskReadSpeed, color: rd, alpha: dim(m, "diskRd"), label: "Read", text: Format.speed(m.diskReadSpeed) });
            if (!hidden(m, "diskWr"))
                list.push({ values: m.diskWriteHistory, value: m.diskWriteSpeed, color: wr, alpha: dim(m, "diskWr"), label: "Write", text: Format.speed(m.diskWriteSpeed) });
            return list;
        },
        legend: [{ key: "diskRd", label: "Read", value: Format.speed(m.diskReadSpeed), color: rd }, { key: "diskWr", label: "Write", value: Format.speed(m.diskWriteSpeed), color: wr }]
    };
}

function gpu(m, cfg) {
    var tint = color(cfg, "gpuColor", "#ff6e40");
    var reading = m.gpuPercent.toFixed(1) + "%";
    return loadChart(cfg, {
        title: Sections.title("gpu", cfg),
        reading: reading,
        readingColor: loadTint(cfg, tint, m.gpuPercent),
        maxValue: 100,
        ticks: Format.PERCENT_TICKS,
        centerText: reading,
        centerSubText: "gpu",
        series: function (style) {
            var scrolling = scrolls(style);
            return [{ values: m.gpuHistory, value: m.gpuPercent, color: scrolling ? tint : loadTint(cfg, tint, m.gpuPercent), bands: scrolling ? loadBands(cfg, m.gpuHistory) : undefined, label: "GPU", text: reading }];
        },
        legend: []
    });
}

function custom(m, cfg) {
    var tint = color(cfg, "customCmdColor", "#ffaa00");
    var unit = String(cfg.customCmdUnit || "");
    var max = Math.max(0.1, cfg.customCmdMax || 1);
    var name = Sections.title("custom", cfg);
    return {
        title: name,
        reading: m.customValue.toFixed(2) + (unit ? " " + unit : ""),
        readingColor: tint,
        maxValue: max,
        ticks: Format.rangeTicks(max, function (v) { return v.toFixed(1) + (unit ? " " + unit : ""); }),
        centerText: m.customValue.toFixed(1) + unit,
        centerSubText: name,
        series: function () {
            return [{ values: m.customHistory, value: m.customValue, color: tint, head: true, label: name, text: m.customValue.toFixed(2) + unit }];
        },
        legend: []
    };
}

// Bar lists (storage, processes): rows of { label, detail, value, ratio, color }.

function storage(m, cfg) {
    var tint = color(cfg, "storageColor", "#44ddaa");
    var rows = (m.storage || []).map(function (d) {
        var band = d.percent >= 95 ? 2 : d.percent >= 85 ? 1 : 0;
        return {
            label: d.mount,
            detail: Format.usage(d.used, d.size),
            value: d.percent.toFixed(0) + "%",
            ratio: d.percent / 100,
            color: [tint, color(cfg, "loadWarnColor", "#ffaa22"), color(cfg, "loadCritColor", "#ff4444")][band]
        };
    });
    var fullest = rows.reduce(function (a, r) { return !a || r.ratio > a.ratio ? r : a; }, null);
    return {
        title: Sections.title("storage", cfg),
        reading: fullest ? fullest.value : "",
        readingColor: fullest ? fullest.color : "",
        empty: "No filesystems found.",
        rows: rows
    };
}

function processes(m, cfg) {
    var tint = color(cfg, "processColor", "#4aa8ff");
    var byMemory = cfg.processSort === "memory";
    var list = m.processes || [];
    var top = list.reduce(function (a, p) { return Math.max(a, byMemory ? p.memory : p.cpu); }, 0);
    return {
        title: Sections.title("processes", cfg),
        reading: byMemory ? "by memory" : "by CPU",
        readingColor: "",
        empty: "Reading processes…",
        rows: list.map(function (p) {
            var cpu = p.cpu.toFixed(1) + "%", mem = Format.bytes(p.memory);
            return {
                label: p.name + (p.count > 1 ? " ×" + p.count : ""),
                detail: byMemory ? cpu : mem,
                value: byMemory ? mem : cpu,
                ratio: top > 0 ? (byMemory ? p.memory : p.cpu) / top : 0,
                color: tint,
                // The row's ✕ ends these (the whole group when grouped).
                pids: p.pids || [p.pid]
            };
        })
    };
}

// Load average: 1, 5 and 15 minutes against the number of CPUs (the dashed
// line: every CPU busy), with uptime and task counts below.
function load(m, cfg) {
    var tint = color(cfg, "loadColor", "#ffb347");
    var l = m.loadInfo || { load1: 0, load5: 0, load15: 0, running: 0, tasks: 0, uptime: 0, cpus: 1 };
    var peak = Math.max.apply(null, [0].concat(m.load1History || [], m.load15History || []));
    var max = Math.max(l.cpus, peak * 1.2, 1);
    var warn = color(cfg, "loadWarnColor", "#ffaa22"), crit = color(cfg, "loadCritColor", "#ff4444");
    var share = l.load1 / l.cpus * 100;
    var reading = l.load1.toFixed(2);
    var fmt = function (v) { return v.toFixed(v < 10 ? 1 : 0); };
    return {
        title: Sections.title("load", cfg),
        reading: reading,
        readingColor: share >= 100 ? crit : share >= 70 ? warn : tint,
        maxValue: max,
        ticks: Format.rangeTicks(max, fmt),
        markers: [{ value: l.cpus, color: warn }],
        centerText: reading,
        centerSubText: l.cpus + " CPUs",
        series: function () {
            var list = [], width = Number(cfg.lineWidth || 2.2);
            if (!hidden(m, "load15"))
                list.push({ values: m.load15History || [], value: l.load15, color: tint, alpha: dim(m, "load15") * 0.35, width: width * 0.6, fill: 0, glow: false, label: "15 min", text: l.load15.toFixed(2) });
            if (!hidden(m, "load5"))
                list.push({ values: m.load5History || [], value: l.load5, color: tint, alpha: dim(m, "load5") * 0.6, width: width * 0.75, fill: 0, glow: false, label: "5 min", text: l.load5.toFixed(2) });
            if (!hidden(m, "load1"))
                list.push({ values: m.load1History || [], value: l.load1, color: tint, alpha: dim(m, "load1"), label: "1 min", text: reading });
            return list;
        },
        legend: [
            { key: "load1", label: "1 min", value: l.load1.toFixed(2), color: tint },
            { key: "load5", label: "5 min", value: l.load5.toFixed(2), color: tint },
            { key: "load15", label: "15 min", value: l.load15.toFixed(2), color: tint }
        ],
        stats: [
            { label: "UPTIME", value: l.uptime > 0 ? Format.duration(l.uptime) : "—", color: "" },
            { label: "PER CPU", value: (l.load1 / l.cpus).toFixed(2), color: share >= 100 ? crit : "" },
            { label: "RUNNING", value: String(l.running), color: "" },
            { label: "TASKS", value: String(l.tasks), color: "" }
        ]
    };
}

// Fans: RPM against the fan's own maximum (reported, else the fastest seen).
function fans(m, cfg) {
    var tint = color(cfg, "fanColor", "#66ccff");
    var peaks = m.fanPeaks || {};
    var list = m.fans || [];
    var fastest = list.reduce(function (a, f) { return !a || f.rpm > a.rpm ? f : a; }, null);
    return {
        title: Sections.title("fans", cfg),
        reading: fastest ? fastest.rpm + " RPM" : "",
        readingColor: "",
        empty: m.fansRead ? "No fan speeds reported (lm-sensors)." : "Reading fans…",
        rows: list.map(function (f) {
            var top = f.max > 0 ? f.max : Math.max(peaks[f.key] || 0, 1);
            return {
                label: f.label,
                detail: f.chip,
                value: f.rpm > 0 ? f.rpm + " RPM" : "stopped",
                ratio: f.rpm / top,
                color: f.rpm > 0 ? tint : ""
            };
        })
    };
}

// State colours shared by services and containers.
function stateColor(cfg, state) {
    return state === "failed" ? color(cfg, "loadCritColor", "#ff4444")
        : state === "waiting" || state === "paused" ? color(cfg, "loadWarnColor", "#ffaa22")
        : state === "stopped" ? "" : null;
}

// systemd: failed units first, then the watched ones, each with a state dot.
function services(m, cfg) {
    var tint = color(cfg, "serviceColor", "#44dd88");
    var s = m.services || { failed: [], running: 0, units: [] };
    var rows = [], seen = {};
    var unitName = function (n) { return String(n).replace(/\.service$/, ""); };
    s.failed.forEach(function (u) {
        seen[(u.user ? "u:" : "s:") + u.name] = true;
        rows.push({ label: unitName(u.name), detail: (u.user ? "user · " : "") + u.desc, value: "failed", ratio: -1, color: stateColor(cfg, "failed") });
    });
    s.units.forEach(function (u) {
        if (seen[(u.user ? "u:" : "s:") + u.name])
            return;
        var state = u.load === "not-found" ? "stopped" : u.active === "active" ? "running" : u.active === "failed" ? "failed" : /activating|deactivating|reloading/.test(u.active) ? "waiting" : "stopped";
        rows.push({
            label: unitName(u.name),
            detail: (u.user ? "user · " : "") + (u.load === "not-found" ? "not found" : u.desc),
            value: u.load === "not-found" ? "—" : u.sub || u.active,
            ratio: -1,
            color: state === "running" ? tint : stateColor(cfg, state)
        });
    });
    var failed = s.failed.length;
    return {
        title: Sections.title("services", cfg),
        reading: failed ? failed + " failed" : m.servicesRead ? s.running + " running" : "",
        readingColor: failed ? stateColor(cfg, "failed") : tint,
        empty: m.servicesRead ? "No failed units." : "Reading systemd…",
        rows: rows
    };
}

// Docker, Podman and Kubernetes: running ones first, busiest on top.
function containers(m, cfg) {
    var tint = color(cfg, "containerColor", "#2496ed");
    var info = m.containerInfo || { engines: [], errors: [], context: "", list: [] };
    var sort = cfg.containerSort || "cpu";
    var list = info.list.filter(function (c) { return cfg.containerShowStopped || c.state !== "stopped"; });
    var order = { failed: 0, running: 1, waiting: 2, paused: 3, stopped: 4 };
    list.sort(function (a, b) {
        var live = (a.state === "running" ? 0 : 1) - (b.state === "running" ? 0 : 1);
        if (live)
            return live;
        if (sort === "name" || a.state !== "running")
            return (order[a.state] - order[b.state]) || (a.name < b.name ? -1 : 1);
        return sort === "memory" ? b.memory - a.memory : b.cpu - a.cpu || b.memory - a.memory;
    });
    var byMemory = sort === "memory";
    var top = list.reduce(function (a, c) { return Math.max(a, byMemory ? c.memory : c.cpu); }, 0);
    var running = info.list.filter(function (c) { return c.state === "running"; }).length;
    var failing = info.list.filter(function (c) { return c.state === "failed"; }).length;
    var image = function (c) {
        return c.engine === "kubernetes" ? c.ns + (c.restarts ? " · ↻" + c.restarts : "") : String(c.image).replace(/^[^/]+\.[^/]+\//, "").replace(/^library\//, "");
    };
    return {
        title: Sections.title("containers", cfg),
        reading: m.containersRead ? running + " running" + (failing ? " · " + failing + " failing" : "") : "",
        readingColor: failing ? stateColor(cfg, "failed") : tint,
        empty: !m.containersRead ? "Looking for containers…"
            : info.errors.length ? info.errors[0]
            : info.engines.length ? "No " + (cfg.containerShowStopped ? "" : "running ") + "containers."
            : "No Docker, Podman or Kubernetes found.",
        rows: list.slice(0, Math.max(1, cfg.containerCount || 8)).map(function (c) {
            var live = c.state === "running";
            return {
                label: c.name,
                detail: image(c),
                value: live ? (byMemory ? Format.bytes(c.memory) : c.cpu.toFixed(1) + "%") : String(c.status).split(" (")[0].replace(/ ago$/, "").slice(0, 18),
                ratio: live ? (top > 0 ? (byMemory ? c.memory : c.cpu) / top : 0) : -1,
                color: live ? tint : stateColor(cfg, c.state)
            };
        })
    };
}

// Power: the chart picked by `tab` ("power", "battery" or "temp").
// Power draws the battery's flow and, where sensors exist, the machine's
// measured load; Battery the charge; Temp the battery temperature.
function power(m, cfg, tab) {
    var flow = color(cfg, "powerColor", "#88ddff"), loadTint = color(cfg, "powerLoadColor", "#ffaa22");
    var batteryTint = batteryColor(m.batteryPercent);
    var fmtW = function (v) { return v.toFixed(v < 10 ? 1 : 0) + " W"; };
    if (tab === "battery")
        return { maxValue: 100, ticks: Format.PERCENT_TICKS, series: [{ values: m.batteryPercentHistory || [], value: m.batteryPercent, color: batteryTint, fill: 0.3, label: "Battery", text: m.batteryPercent + "%" }], legend: [] };
    if (tab === "temp") {
        var temps = m.batteryTempHistory || [];
        var tmax = Math.max(50, Math.max.apply(null, [0].concat(temps)) * 1.15);
        return { maxValue: tmax, ticks: Format.rangeTicks(tmax, function (v) { return v.toFixed(0) + "°C"; }), series: [{ values: temps, value: m.batteryTempC, color: tempColor(m.batteryTempC, 60), fill: 0.3, label: "Temp", text: m.batteryTempC.toFixed(0) + "°C" }], legend: [] };
    }
    var flowH = m.batteryPresent ? m.batteryPowerHistory || [] : [];
    var loadH = m.hasPowerSensors ? m.powerLoadHistory || [] : [];
    var max = Math.max(10, Math.max.apply(null, [0].concat(flowH, loadH))) * 1.15;
    var series = [], legend = [];
    if (loadH.length && !hidden(m, "powerLoad")) {
        series.push({ values: loadH, value: m.powerLoadW, color: loadTint, alpha: dim(m, "powerLoad"), fill: flowH.length ? 0 : 0.3, label: "Load", text: fmtW(m.powerLoadW) });
    }
    if (flowH.length && !hidden(m, "powerFlow"))
        series.push({ values: flowH, value: Math.abs(m.batteryPowerW), color: flow, alpha: dim(m, "powerFlow"), fill: 0.3, label: "Battery", text: fmtW(Math.abs(m.batteryPowerW)) });
    if (loadH.length)
        legend.push({ key: "powerLoad", label: "Load", value: fmtW(m.powerLoadW), color: loadTint });
    if (flowH.length)
        legend.push({ key: "powerFlow", label: m.batteryPowerW > 0.05 ? "Charging" : "Battery", value: fmtW(Math.abs(m.batteryPowerW)), color: flow });
    return { maxValue: max, ticks: Format.rangeTicks(max, fmtW), series: series, legend: legend.length > 1 ? legend : [] };
}

// The power profile buttons: [{ id, label }] for the profiles offered.
var PROFILE_LABELS = { "power-saver": "Saver", balanced: "Balanced", performance: "Performance" };
function profiles(m) {
    return (m.powerProfiles || []).map(function (p) { return { id: p, label: PROFILE_LABELS[p] || p }; });
}

// ── Panel pill ────────────────────────────────────────────────────────────
// One section as the pill draws it:
//   label   short caption ("CPU")
//   lines   one or two readings, [{ text, color, mark }]; `mark` is "↓" etc.
//   sample  the widest text a reading can take, so the pill never changes
//           width with the numbers and the panel never re-lays out
//   ratio   0–1 for a meter, or -1
//   history [values] and `max` for the sparkline and mini bars; `history2`
//           a second series drawn behind (upload, write)
// Colours are "" where the text colour should be used.

function tempColor(value, crit) {
    var c = crit > 0 ? crit : 90;
    var r = Math.max(0, (value - 30) / Math.max(20, c - 30));
    return r >= 0.85 ? "#ff4444" : r >= 0.72 ? "#ff8844" : r >= 0.55 ? "#ffaa22" : "#44ddaa";
}
function batteryColor(percent) {
    return percent <= 15 ? "#ff4444" : percent <= 30 ? "#ffaa00" : "#44dd88";
}

function pillPercent(m, cfg, id, key, value, history) {
    var tint = loadTint(cfg, color(cfg, key, "#44ddaa"), value);
    return { label: Sections.shortTitle(id, cfg), lines: [{ text: value.toFixed(0) + "%", color: tint }], sample: "100%", ratio: value / 100, history: history, max: 100, color: tint };
}
function pillRates(cfg, label, marks, keys, values, histories, floor) {
    var colors = [color(cfg, keys[0], "#22aaff"), color(cfg, keys[1], "#ff9933")];
    return {
        label: label,
        lines: [0, 1].map(function (i) { return { mark: marks[i], text: Format.short(values[i], "/s"), color: colors[i] }; }),
        sample: Format.SHORT_WIDEST + "/s",
        ratio: -1,
        history: histories[0], history2: histories[1],
        max: DiagramData.autoMax(histories, floor, 1.15),
        color: colors[0]
    };
}

function pill(id, m, cfg) {
    var out;
    switch (id) {
    case "cpu":
        out = pillPercent(m, cfg, id, "cpuColor", m.cpuPercent, m.cpuHistory);
        break;
    case "memory":
        out = pillPercent(m, cfg, id, "memColor", m.memPercent, m.memHistory);
        break;
    case "gpu":
        out = pillPercent(m, cfg, id, "gpuColor", m.gpuPercent, m.gpuHistory);
        break;
    case "network":
        out = pillRates(cfg, Sections.shortTitle(id, cfg), ["↓", "↑"], ["dlColor", "ulColor"], [m.downloadSpeed, m.uploadSpeed], [m.dlHistory, m.ulHistory], 1024);
        break;
    case "disk":
        out = pillRates(cfg, Sections.shortTitle(id, cfg), ["R", "W"], ["diskRdColor", "diskWrColor"], [m.diskReadSpeed, m.diskWriteSpeed], [m.diskReadHistory, m.diskWriteHistory], 1024 * 1024);
        break;
    case "ping": {
        var model = ping(m, cfg);
        var history = m.histories[m.activeTarget] || [];
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: m.lastPing >= 0 ? m.lastPing.toFixed(0) + "ms" : "—", color: model.readingColor }], sample: "888ms", ratio: -1, history: history.map(function (v) { return Math.max(0, v); }), max: model.maxValue, color: model.readingColor };
        break;
    }
    case "custom": {
        var max = Math.max(0.1, cfg.customCmdMax || 1), tint = color(cfg, "customCmdColor", "#ffaa00");
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: m.customValue.toFixed(1) + String(cfg.customCmdUnit || ""), color: tint }], sample: "888.8" + String(cfg.customCmdUnit || ""), ratio: m.customValue / max, history: m.customHistory, max: max, color: tint };
        break;
    }
    case "sensors": {
        var hot = tempColor(m.hwMaxTemp, m.hwMaxTempCrit);
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: m.hwMaxTemp > 0 ? m.hwMaxTemp.toFixed(0) + "°C" : "—", color: hot }], sample: "188°C", ratio: m.hwMaxTemp / (m.hwMaxTempCrit > 0 ? m.hwMaxTempCrit : 90), color: hot };
        break;
    }
    case "power": {
        var charge = batteryColor(m.batteryPercent), draw = power(m, cfg, "power");
        out = m.batteryPresent
            ? { label: Sections.shortTitle(id, cfg), lines: [{ mark: m.batteryStatus === "Charging" ? "⚡" : "", text: m.batteryPercent + "%", color: charge }], sample: "100%", ratio: m.batteryPercent / 100, history: m.batteryPowerHistory, max: draw.maxValue, color: charge }
            : m.hasPowerSensors
            ? { label: "Power", lines: [{ text: m.powerLoadW.toFixed(m.powerLoadW < 10 ? 1 : 0) + "W", color: color(cfg, "powerLoadColor", "#ffaa22") }], sample: "888W", ratio: -1, history: m.powerLoadHistory, max: draw.maxValue, color: color(cfg, "powerLoadColor", "#ffaa22") }
            : { label: Sections.shortTitle(id, cfg), lines: [{ text: "—", color: "" }], sample: "100%", ratio: -1 };
        break;
    }
    case "load": {
        var lm = load(m, cfg), li = m.loadInfo;
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: li ? li.load1.toFixed(2) : "—", color: lm.readingColor }], sample: "88.88", ratio: li ? Math.min(1, li.load1 / li.cpus) : -1, history: m.load1History || [], max: lm.maxValue, color: lm.readingColor };
        break;
    }
    case "fans": {
        var fm = fans(m, cfg), fast = (m.fans || []).reduce(function (a, f) { return !a || f.rpm > a.rpm ? f : a; }, null);
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: fast ? String(fast.rpm) : "—", color: color(cfg, "fanColor", "#66ccff") }], sample: "8888", ratio: fm.rows.length ? fm.rows.reduce(function (a, r) { return Math.max(a, r.ratio); }, 0) : -1, color: color(cfg, "fanColor", "#66ccff") };
        break;
    }
    case "services": {
        var sm = services(m, cfg), nf = (m.services || { failed: [] }).failed.length;
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: nf ? nf + " ✕" : "OK", color: sm.readingColor }], sample: "88 ✕", ratio: -1, color: sm.readingColor };
        break;
    }
    case "containers": {
        var cm = containers(m, cfg), ci = m.containerInfo;
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: ci ? String(ci.list.filter(function (c) { return c.state === "running"; }).length) : "—", color: cm.readingColor }], sample: "888", ratio: -1, color: cm.readingColor };
        break;
    }
    case "system":
        out = { label: Sections.shortTitle(id, cfg), lines: [{ text: m.osUptime || "—", color: "" }], sample: "88d 88h", ratio: -1 };
        break;
    case "netapps": {
        // The host's NetworkService: { top: { name, rateIn, rateOut }, count, history }.
        var apps = m.netApps, tint2 = color(cfg, "dlColor", "#22aaff");
        out = apps && apps.top
            ? { label: Sections.shortTitle(id, cfg), lines: [{ text: String(apps.top.name).slice(0, 12), color: tint2 }, { mark: "↓", text: Format.short(apps.top.rateIn, "/s") + " · " + apps.count, color: "" }], sample: "WWWWWWWWWWWW", ratio: -1, history: apps.history || [], max: DiagramData.autoMax([apps.history || []], 1024, 1.15), color: tint2 }
            : { label: Sections.shortTitle(id, cfg), lines: [{ text: apps ? "idle" : "—", color: "" }], sample: "WWWWWWWWWWWW", ratio: -1 };
        break;
    }
    case "storage": {
        var disks = storage(m, cfg), full = disks.rows.reduce(function (a, r) { return !a || r.ratio > a.ratio ? r : a; }, null);
        out = { label: full ? (full.label.split("/").filter(Boolean).pop() || "/") : Sections.shortTitle(id, cfg), lines: [{ text: full ? full.value : "—", color: full ? full.color : "" }], sample: "100%", ratio: full ? full.ratio : -1, color: full ? full.color : "" };
        break;
    }
    case "processes": {
        var top = processes(m, cfg).rows[0];
        out = { label: top ? top.label : Sections.shortTitle(id, cfg), lines: [{ text: top ? top.value : "—", color: top ? top.color : "" }], sample: cfg.processSort === "memory" ? "888.8 MiB" : "88.8%", ratio: top && cfg.processSort !== "memory" ? parseFloat(top.value) / 100 : -1, color: top ? top.color : "" };
        break;
    }
    default:
        return pill("cpu", m, cfg);
    }
    out.id = id;
    out.color = out.color || "";
    out.history = out.history || [];
    out.history2 = out.history2 || [];
    out.max = out.max || 1;
    return out;
}
