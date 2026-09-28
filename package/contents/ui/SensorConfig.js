.pragma library
.import "SectionModels.js" as SectionModels

// Individual sensor readings for the Sensors, CPU, GPU and Power sections,
// shared with the website. Every reading has a stable id ("hw:<chip>:<key>",
// "power:<source>", "cpu:power"); `sensorSelection` maps a section to the
// ids it shows (absent = defaults) and `sensorNames` maps an id to a name.

var SECTIONS = ["sensors", "cpu", "gpu", "power"];
var CPU_CHIP = /^(coretemp|k10temp|zenpower|k8temp)/;
var GPU_CHIP = /^(amdgpu|nouveau|radeon|i915|xe|nvidia)/;
var UNITS = { temp: "°C", cores: "°C", fan: "RPM", power: "W", in: "V", curr: "A", humidity: "%" };
var DIGITS = { "°C": 1, RPM: 0, W: 1, V: 2, A: 2, "%": 0 };
var POWER_DEVICE = "Power draw";

function object(text) {
    try {
        var value = JSON.parse(text || "{}");
        return value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch (e) {
        return {};
    }
}

// The ids chosen for `section`, or null when it follows the defaults.
function selection(text, section) {
    var value = object(text)[section];
    return Array.isArray(value) ? value.filter(function (id, i) {
        return typeof id === "string" && value.indexOf(id) === i;
    }) : null;
}

function select(text, section, ids) {
    var map = object(text);
    if (ids === null)
        delete map[section];
    else
        map[section] = ids;
    return JSON.stringify(map);
}

function rename(text, id, name) {
    var map = object(text);
    name = String(name || "").trim();
    if (name)
        map[id] = name;
    else
        delete map[id];
    return JSON.stringify(map);
}

// Adds or removes several ids at once, keeping the rest of the selection.
function toggle(ids, change, on) {
    var out = ids.filter(function (id) { return change.indexOf(id) === -1; });
    return on ? out.concat(change) : out;
}

// ── catalog ─────────────────────────────────────────────────────────────────

function kindOf(chip) {
    return CPU_CHIP.test(chip) ? "cpu" : GPU_CHIP.test(chip) ? "gpu" : "";
}

// MonitorCore.parseHwSensorsJson groups → readings. Chips with several
// "Core N" temperatures also get one "Cores" reading covering them all.
function hardware(groups) {
    var out = [];
    groups.forEach(function (g) {
        var kind = kindOf(g.chip), cores = [];
        g.sensors.forEach(function (s) {
            var core = s.type === "temp" && /^Core \d+/.test(s.label);
            var reading = { id: "hw:" + g.chip + ":" + (s.key || s.label), label: s.label, device: g.chipDisplay, chip: g.chip,
                kind: kind, type: s.type, unit: s.unit || UNITS[s.type] || "", value: s.value, crit: s.crit || 0, source: "hardware" };
            if (core) {
                reading.core = true;
                cores.push(reading);
            }
            out.push(reading);
        });
        if (cores.length > 1) {
            var values = cores.map(function (c) { return c.value; });
            out.splice(out.indexOf(cores[0]), 0, { id: "hw:" + g.chip + ":cores", label: "Cores", device: g.chipDisplay, chip: g.chip, kind: kind,
                type: "cores", unit: "°C", value: Math.max.apply(null, values), min: Math.min.apply(null, values), values: values,
                crit: cores[0].crit, source: "hardware", members: cores.map(function (c) { return c.id; }) });
        }
    });
    return out;
}

// Hardware readings plus Probes.powerSources, and the CPU's total draw
// when anything measures it.
function catalog(hardwareReadings, sources) {
    var cpu = sources.filter(function (s) { return s.kind === "cpu"; });
    // Package counters cover the whole CPU; hwmon may measure it again.
    var packages = cpu.filter(function (s) { return s.counter; });
    if (packages.length)
        cpu = packages;
    var power = sources.map(function (s) {
        return { id: "power:" + s.id, label: s.label, device: POWER_DEVICE, chip: s.id, kind: s.kind || "",
            type: "power", unit: "W", value: s.watts, source: "power" };
    });
    if (cpu.length)
        power.unshift({ id: "cpu:power", label: "CPU power", device: POWER_DEVICE, chip: "all CPU packages", kind: "cpu",
            type: "power", unit: "W", value: cpu.reduce(function (sum, s) { return sum + s.watts; }, 0), source: "aggregate" });
    return hardwareReadings.concat(power);
}

function byId(list) {
    var out = {};
    list.forEach(function (s) { out[s.id] = s; });
    return out;
}

// ── selection ───────────────────────────────────────────────────────────────

function firstTemp(list, kind) {
    var temps = list.filter(function (s) { return s.kind === kind && s.type === "temp" && !s.core; });
    var main = temps.filter(function (s) { return /package|tctl|tdie|edge/i.test(s.label); })[0];
    return main || temps[0];
}

function defaultIds(list, section) {
    var ids = list.filter(function (s) {
        switch (section) {
        case "sensors": return s.source === "hardware" && !s.core && (s.type === "temp" || s.type === "cores" || s.type === "fan");
        case "power": return s.source === "power";
        case "cpu": return false;
        case "gpu": return s.source === "power" && s.kind === "gpu";
        }
        return false;
    }).map(function (s) { return s.id; });
    return ids;
}

function ids(list, text, section) {
    var chosen = selection(text, section);
    return chosen === null ? defaultIds(list, section) : chosen;
}

// Which probes the shown sections need: sensors -j (hardware), the power
// script (power) and nvidia-smi within it. Decided without the catalog,
// which is only filled once the probes run.
function needs(text, sections) {
    var out = { hardware: false, power: false, nvidia: false };
    sections.forEach(function (section) {
        if (SECTIONS.indexOf(section) === -1)
            return;
        var chosen = selection(text, section);
        if (chosen === null) {
            out.hardware = out.hardware || section === "sensors";
            out.power = out.power || section === "gpu" || section === "power";
            out.nvidia = out.nvidia || section === "gpu";
            return;
        }
        chosen.forEach(function (id) {
            out.hardware = out.hardware || id.indexOf("hw:") === 0;
            out.power = out.power || id.indexOf("power:") === 0 || id === "cpu:power";
            out.nvidia = out.nvidia || id.indexOf("power:nvidia") === 0;
        });
    });
    return out;
}

// ── display ─────────────────────────────────────────────────────────────────

function named(sensor, names) {
    var name = names[sensor.id];
    return typeof name === "string" && name.trim() ? Object.assign({}, sensor, { label: name.trim(), original: sensor.label }) : sensor;
}

// What `section` shows, in catalog order, with display names. Readings that
// are not there right now (a first sample, an unplugged device) are left out.
function rows(list, cfg, section) {
    var chosen = ids(list, cfg.sensorSelection, section), names = object(cfg.sensorNames);
    return list.filter(function (s) { return chosen.indexOf(s.id) !== -1; }).map(function (s) { return named(s, names); });
}

// Sensors section rows: a header per device, then its readings.
function grouped(shown) {
    var out = [];
    shown.forEach(function (s, i) {
        if (!i || shown[i - 1].device !== s.device) {
            var temps = shown.filter(function (t) { return t.device === s.device && (t.type === "temp" || t.type === "cores"); });
            var hot = temps.reduce(function (a, t) { return !a || t.value > a.value ? t : a; }, null);
            out.push({ id: "device:" + s.device, header: true, label: s.device, value: hot ? hot.value : 0, crit: hot ? hot.crit : 0 });
        }
        out.push(s);
    });
    return out;
}

function number(value, unit) {
    if (value === null || value === undefined || !isFinite(value))
        return "—";
    if (unit === "W" && value > 0 && value < 1)
        return Math.round(value * 1000) + " mW";
    var d = DIGITS[unit] === undefined ? 1 : DIGITS[unit];
    return Number(value).toFixed(d) + (unit === "°C" ? "°C" : unit ? " " + unit : "");
}

function reading(sensor) {
    if (sensor.type === "cores" && sensor.min !== undefined)
        return sensor.min.toFixed(0) + "–" + sensor.value.toFixed(0) + "°C";
    return number(sensor.value, sensor.unit);
}

// A reading's colour; "" means the card's text colour.
function tint(sensor, cfg) {
    if (sensor.type === "temp" || sensor.type === "cores")
        return SectionModels.tempColor(sensor.value, sensor.crit || cfg.hwTempCrit || 90);
    if (sensor.type === "fan")
        return "#22aaff";
    if (sensor.type === "power")
        return cfg.powerLoadColor || "#ffaa22";
    return "";
}

// Bar fill 0–1: temperatures against their critical point, watts against
// the largest shown draw; other readings have no bar (-1).
function ratio(sensor, cfg, maxWatts) {
    if (sensor.value === null || !isFinite(sensor.value))
        return 0;
    if (sensor.type === "temp" || sensor.type === "cores")
        return Math.max(0.05, Math.min(1, sensor.value / (sensor.crit || cfg.hwTempCrit || 90)));
    if (sensor.type === "power")
        return Math.max(0.03, Math.min(1, sensor.value / Math.max(1, maxWatts || 1)));
    return -1;
}

// ── settings list ───────────────────────────────────────────────────────────

// The picker's structure: one group per device with its readings' ids,
// cores folded under their "Cores" reading, and selected readings that are
// not detected right now in a group of their own so they can be removed.
// Only ids are returned, so new samples do not rebuild the list.
function groups(list, chosen, names, query) {
    query = String(query || "").trim().toLowerCase();
    var matches = function (s) {
        return !query || [s.label, s.device, s.chip, names[s.id] || ""].join(" ").toLowerCase().indexOf(query) !== -1;
    };
    var known = byId(list), folded = {}, out = [], at = {};
    list.forEach(function (s) {
        (s.members || []).forEach(function (id) { folded[id] = true; });
    });
    list.forEach(function (s) {
        if (folded[s.id])
            return;
        var members = (s.members || []).filter(function (id) { return matches(known[id]); });
        if (!matches(s) && !members.length)
            return;
        if (at[s.device] === undefined) {
            at[s.device] = out.length;
            out.push({ key: s.device, title: s.device, detail: s.source === "hardware" ? s.chip : "", items: [] });
        }
        out[at[s.device]].items.push({ id: s.id, members: matches(s) ? s.members || [] : members });
    });
    var missing = chosen.filter(function (id) { return !known[id] && (!query || (id + " " + (names[id] || "")).toLowerCase().indexOf(query) !== -1); });
    if (missing.length)
        out.push({ key: "missing", title: "Not detected now", detail: "", items: missing.map(function (id) { return { id: id, members: [] }; }) });
    return out;
}

// Every id in a picker group, core members included.
function groupIds(group) {
    var out = [];
    group.items.forEach(function (item) {
        out.push(item.id);
        out = out.concat(item.members);
    });
    return out;
}

// A stand-in for a selected reading that is not detected right now.
function placeholder(id) {
    return { id: id, label: id.replace(/^(hw|power):/, ""), device: "", chip: "", type: "", unit: "", value: null, missing: true };
}
