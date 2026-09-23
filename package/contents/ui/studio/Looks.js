.pragma library

// Looks: named sets of appearance and layout settings — built in, saved by
// the user, or shared as a JSON snippet. A look never carries commands,
// hosts, devices, thresholds or placement: importing a snippet from someone
// else must not be able to run anything on this machine.

var FORMAT = "glassy-system-monitor-look";
var NOT_LOOK = ["customCmd", "osFetchCmd", "targets", "pingInterval", "pingTimeout", "networkInterface", "diskDevice", "gpuDevice",
    "customCmdUnit", "customCmdMax", "customCmdInterval", "osUseFetch", "updateInterval", "chartRenderer", "currentTargetIndex",
    "disabledLinesStr", "disabledCoresStr", "userPresets", "activeSection", "latencyThreshold", "lossThreshold", "jitterThreshold",
    "hwTempWarn", "hwTempCrit", "accurateGeo", "panelMode", "monitor", "hAnchor", "verticalPosition", "screenMargin", "widgetWidth",
    "desktopLayer", "cpuTitle", "memoryTitle", "networkTitle", "pingTitle", "diskTitle", "gpuTitle", "hwSensorsTitle", "powerTitle",
    "osInfoTitle", "customCmdTitle", "storageTitle", "processesTitle", "storageMounts", "osFieldRules", "osPlainText", "osShowLogo"];

function isLookKey(key) {
    return NOT_LOOK.indexOf(key) === -1 && key !== "__proto__" && key !== "constructor" && key !== "prototype";
}

var BUILT_IN = [
    { id: "glassy", name: "Glassy", note: "The defaults: one CPU line on frosted glass.", s: {} },
    { id: "dashboard", name: "Dashboard", note: "Four metrics in two columns, network across the middle.",
      s: { sections: "cpu,memory,network,disk,gpu", layoutColumns: 2, sectionSpans: "network", sectionStyles: "memory:donut", sectionSizes: "network:l" } },
    { id: "neon", name: "Neon", note: "Bright lines and full glow on a dark tint.",
      s: { sections: "cpu,network,ping", bgColor: "#cc05060a", frostedGlass: false, glowLine: true, bloomStrength: 1, lineWidth: 2.6,
           cpuColor: "#39ff14", dlColor: "#00e5ff", ulColor: "#ff2bd6", pingColor: "#fff200" } },
    { id: "gauges", name: "Gauges", note: "Donuts in three columns, no axes.",
      s: { sections: "cpu,memory,gpu", layoutColumns: 3, chartType: 3, showLegend: false } },
    { id: "minimal", name: "Minimal", note: "Thin monochrome lines, no card, no labels.",
      s: { sections: "cpu,memory,network", bgColor: "#00000000", cardBorder: false, frostedGlass: false, glowLine: false, showYLabels: false,
           showLegend: false, lineWidth: 1.4, cpuColor: "#f2f2f2", memColor: "#c8c8c8", dlColor: "#f2f2f2", ulColor: "#9a9a9a" } },
    { id: "terminal", name: "Terminal", note: "Phosphor bars and monospace text on a square black card.",
      s: { sections: "cpu,memory,network", surfaceStyle: "solid", bgColor: "#ff060907", bgRadiusTL: 0, bgRadiusTR: 0, bgRadiusBR: 0, bgRadiusBL: 0,
           cardBorder: false, cardShadow: "none", grain: false, chartType: 1, historySize: 36, glowLine: true, bloomStrength: 0.3,
           showGridLines: true, fontFamily: "monospace", useSystemTextColor: false, customTextColor: "#b8f5c4",
           cpuColor: "#39ff7a", memColor: "#2de2e6", swapColor: "#ffb000", dlColor: "#39ff7a", ulColor: "#ffb000",
           diskRdColor: "#2de2e6", diskWrColor: "#ffb000", gpuColor: "#39ff7a", pingColor: "#2de2e6",
           customCmdColor: "#ffb000", storageColor: "#39ff7a", processColor: "#39ff7a" } },
    { id: "gaming", name: "Gaming", note: "CPU, GPU and temperatures side by side.",
      s: { sections: "cpu,gpu,sensors", layoutColumns: 2, sectionSpans: "sensors", sectionStyles: "gpu:area", gpuColor: "#ff4f81", cpuColor: "#ffc36b" } },
    { id: "laptop", name: "Laptop", note: "Battery, pressure and sensors at a glance.",
      s: { sections: "power,cpu,sensors", sectionSizes: "cpu:s" } },
    { id: "liquid", name: "Liquid Glass", note: "Clear glass that bends the wallpaper; light follows the pointer.",
      s: { sections: "cpu,memory,network", surfaceStyle: "liquid", glassTint: "clear", bgRadiusTL: 22, bgRadiusTR: 22, bgRadiusBR: 22, bgRadiusBL: 22,
           cardShadow: "soft", cpuColor: "#5ef2c1", memColor: "#b57bff", dlColor: "#4aa8ff", ulColor: "#8f6bff" } },
    { id: "paper", name: "Paper", note: "A light, solid card with ink-coloured charts.",
      s: { sections: "cpu,memory,network", surfaceStyle: "solid", cardShadow: "lifted", glowLine: false, lineWidth: 1.8, bgRadiusTL: 16, bgRadiusTR: 16, bgRadiusBR: 16, bgRadiusBL: 16,
           cpuColor: "#0b8a66", memColor: "#6b3fc4", swapColor: "#c4365e", dlColor: "#1c64c8", ulColor: "#c8641c" } },
    { id: "atmosphere", name: "Atmosphere", note: "A deep card lit by the charts' own colours.",
      s: { sections: "cpu,gpu,network", layoutColumns: 2, sectionSpans: "network", surfaceStyle: "atmosphere", grain: true, cardShadow: "soft",
           bgRadiusTL: 20, bgRadiusTR: 20, bgRadiusBR: 20, bgRadiusBL: 20, cpuColor: "#ff4f81", gpuColor: "#7a5cff", dlColor: "#4aa8ff", ulColor: "#ff9e4a" } }
];

// Settings of `from` that belong to a look and differ from `defaults`.
function extract(from, defaults) {
    var out = {};
    for (var key in from)
        if (isLookKey(key) && defaults[key] !== undefined && JSON.stringify(from[key]) !== JSON.stringify(defaults[key]))
            out[key] = from[key];
    return out;
}

// The draft with a look applied: every look setting back to its default,
// then the look on top. Everything else in the draft stays.
function apply(draft, defaults, settings) {
    var next = Object.assign({}, draft);
    for (var key in defaults)
        if (isLookKey(key))
            next[key] = defaults[key];
    for (key in settings)
        if (isLookKey(key) && defaults[key] !== undefined)
            next[key] = settings[key];
    return next;
}

function matches(draft, defaults, settings) {
    var target = apply(draft, defaults, settings);
    for (var key in defaults)
        if (isLookKey(key) && JSON.stringify(target[key]) !== JSON.stringify(draft[key]))
            return false;
    return true;
}

// Only known look keys with the type the default has.
function clean(settings, defaults) {
    var out = {};
    Object.keys(settings).forEach(function (key) {
        if (!isLookKey(key) || defaults[key] === undefined)
            return;
        var value = settings[key];
        if (typeof value !== typeof defaults[key] || (typeof value === "number" && !isFinite(value)) || (value !== null && typeof value === "object"))
            throw new Error("Invalid value for " + key + ".");
        out[key] = value;
    });
    return out;
}

function encode(name, settings, defaults) {
    return JSON.stringify({ format: FORMAT, version: 1, name: String(name || "Shared look"), settings: clean(settings, defaults) });
}

function decode(text, defaults) {
    var data = JSON.parse(text);
    if (!data || typeof data !== "object" || Array.isArray(data))
        throw new Error("Paste a look object.");
    if (data.format !== undefined && (data.format !== FORMAT || data.version !== 1))
        throw new Error("That is not a Glassy look.");
    var settings = data.settings === undefined ? data : data.settings;
    if (!settings || typeof settings !== "object" || Array.isArray(settings))
        throw new Error("Settings must be an object.");
    return { name: typeof data.name === "string" && data.name.trim() ? data.name.trim() : "Imported look", settings: clean(settings, defaults) };
}

// The saved list lives in the userPresets setting as JSON.
function parseSaved(text) {
    try {
        var list = JSON.parse(text || "[]");
        return Array.isArray(list) ? list.filter(function (p) { return p && typeof p.name === "string" && p.settings && typeof p.settings === "object"; }) : [];
    } catch (error) {
        return [];
    }
}
