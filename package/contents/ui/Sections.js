.pragma library

// The section catalogue. One widget shows any of these, in the order the
// `sections` setting lists them; older installs stored a single index in
// `activeSection`, which parse() still honours when `sections` is empty.

var ALL = [
    { id: "cpu", stock: "CPU", short: "CPU", colorKey: "cpuColor", label: "CPU", titleKey: "cpuTitle", icon: "M9 4v2M15 4v2M9 18v2M15 18v2M4 9h2M4 15h2M18 9h2M18 15h2M7 6h10a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1zM10 10h4v4h-4z" },
    { id: "memory", stock: "Memory", short: "RAM", colorKey: "memColor", label: "Memory", titleKey: "memoryTitle", icon: "M4 7h16v10H4zM8 7v10M12 7v10M16 7v10M6 17v3M18 17v3" },
    { id: "network", stock: "Network", short: "Net", colorKey: "dlColor", label: "Network", titleKey: "networkTitle", icon: "M7 4v16M4 17l3 3 3-3M17 20V4M14 7l3-3 3 3" },
    { id: "ping", stock: "Ping", short: "Ping", colorKey: "pingColor", label: "Ping", titleKey: "pingTitle", icon: "M3 12h4l3-7 4 14 3-7h4" },
    { id: "disk", stock: "Disk I/O", short: "Disk", colorKey: "diskRdColor", label: "Disk I/O", titleKey: "diskTitle", icon: "M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3zM4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3" },
    { id: "gpu", stock: "GPU", short: "GPU", colorKey: "gpuColor", label: "GPU", titleKey: "gpuTitle", icon: "M3 7h18v10H3zM7 17v3M17 17v3M8 12a2 2 0 1 0 4 0 2 2 0 1 0-4 0M15 10h2M15 14h2" },
    { id: "sensors", stock: "Hardware Sensors", short: "Temp", label: "Sensors", titleKey: "hwSensorsTitle", icon: "M10 14.8V5a2 2 0 1 1 4 0v9.8a4 4 0 1 1-4 0zM12 9v7" },
    { id: "power", stock: "Power", short: "Battery", label: "Power", titleKey: "powerTitle", icon: "M5 7h13a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zM19 10h2v4h-2M12 9l-2 3h4l-2 3" },
    { id: "system", stock: "System Info", short: "Uptime", label: "System", titleKey: "osInfoTitle", icon: "M4 5h16v11H4zM8 20h8M12 16v4" },
    { id: "storage", short: "Space", colorKey: "storageColor", label: "Storage", titleKey: "storageTitle", icon: "M4 14h16v5H4zM4 14l2.5-8h11l2.5 8M7 16.5h3" },
    { id: "processes", short: "Top", colorKey: "processColor", label: "Processes", titleKey: "processesTitle", icon: "M4 6h9M4 12h13M4 18h6M17 5v3M20 9v11M14 15v5" },
    { id: "load", stock: "Load", short: "Load", colorKey: "loadColor", label: "Load & uptime", titleKey: "loadTitle", icon: "M4 19h16M6 16l4-5 3 3 5-7M4 5v14" },
    { id: "fans", stock: "Fans", short: "Fans", colorKey: "fanColor", label: "Fans", titleKey: "fansTitle", icon: "M12 12m-2 0a2 2 0 1 0 4 0 2 2 0 1 0-4 0M12 10c0-4 1-7 4-7 2 0 2 3 0 5l-2 2M14 12c4 0 7 1 7 4 0 2-3 2-5 0l-2-2M12 14c0 4-1 7-4 7-2 0-2-3 0-5l2-2M10 12c-4 0-7-1-7-4 0-2 3-2 5 0l2 2" },
    { id: "services", stock: "Services", short: "Units", colorKey: "serviceColor", label: "Services", titleKey: "servicesTitle", icon: "M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5" },
    { id: "containers", stock: "Containers", short: "Pods", colorKey: "containerColor", label: "Containers", titleKey: "containersTitle", icon: "M3 9h18v10H3zM3 9l2-4h14l2 4M8 9v10M13 9v10M18 9v10" },
    { id: "custom", stock: "Load Average", short: "Load", colorKey: "customCmdColor", label: "Custom", titleKey: "customCmdTitle", icon: "M5 8l4 4-4 4M11 16h8" }
];

var IDS = ALL.map(function (s) { return s.id; });

// Readings only a panel pill shows (no card section of their own): the
// network window's busiest app, from the host's NetworkService.
var PILL_ONLY = [
    { id: "netapps", short: "Apps", colorKey: "dlColor", label: "Network apps", icon: "M4 6h16v12H4zM4 10h16M8 14h3" }
];
var PILL_IDS = IDS.concat(PILL_ONLY.map(function (s) { return s.id; }));

// Order of the legacy activeSection indices.
var LEGACY = ["ping", "network", "cpu", "memory", "custom", "disk", "gpu", "sensors", "system", "power"];

function parse(value, legacyIndex, known) {
    var ids = known || IDS;
    var out = [];
    var list = Array.isArray(value) ? value : String(value || "").split(",");
    for (var i = 0; i < list.length; i++) {
        var id = String(list[i]).trim();
        if (ids.indexOf(id) !== -1 && out.indexOf(id) === -1)
            out.push(id);
    }
    if (out.length)
        return out;
    return [LEGACY[legacyIndex] || "cpu"];
}

// What a panel pill shows: `panelSections` when set, else the card's first
// section. The pill may show sections the card does not.
function panelIds(cfg) {
    var picked = String(cfg.panelSections || "").trim() ? parse(cfg.panelSections, undefined, PILL_IDS) : [];
    return picked.length ? picked : [parse(cfg.sections, cfg.activeSection)[0]];
}

function info(id) {
    for (var i = 0; i < ALL.length; i++)
        if (ALL[i].id === id)
            return ALL[i];
    for (var k = 0; k < PILL_ONLY.length; k++)
        if (PILL_ONLY[k].id === id)
            return PILL_ONLY[k];
    return ALL[0];
}

// The first two colours of the shown sections, for colour-led materials.
function colors(ids, cfg, fallback) {
    var out = [];
    ids.forEach(function (id) {
        var key = info(id).colorKey;
        var c = key ? String(cfg[key] || "") : "";
        if (c && out.indexOf(c) === -1)
            out.push(c);
    });
    while (out.length < 2)
        out.push(out[0] || fallback);
    return out.slice(0, 2);
}

// The chart colours each section draws with, for the per-section colour grid.
var CHART_COLORS = {
    cpu: [["cpuColor", "Line"]],
    memory: [["memColor", "RAM"], ["swapColor", "Swap"]],
    network: [["dlColor", "Down"], ["ulColor", "Up"]],
    ping: [["pingColor", "Normal"], ["pingWarnColor", "Slow"], ["pingCritColor", "Critical"]],
    disk: [["diskRdColor", "Read"], ["diskWrColor", "Write"]],
    gpu: [["gpuColor", "Line"]],
    power: [["powerColor", "Battery"], ["powerLoadColor", "Load"]],
    storage: [["storageColor", "Bars"]],
    processes: [["processColor", "Bars"]],
    load: [["loadColor", "Line"]],
    fans: [["fanColor", "Bars"]],
    services: [["serviceColor", "Dots"]],
    containers: [["containerColor", "Bars"]],
    custom: [["customCmdColor", "Line"]]
};

// "#rrggbb" or Qt's "#aarrggbb"; anything else counts as unset.
function isColor(value) {
    return /^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(String(value || ""));
}
// Perceived brightness 0–1 and opacity 0–1 of a hex colour.
function rgba(hex) {
    var h = String(hex).slice(1), a = 1;
    if (h.length === 8) {
        a = parseInt(h.slice(0, 2), 16) / 255;
        h = h.slice(2);
    }
    return { r: parseInt(h.slice(0, 2), 16) / 255, g: parseInt(h.slice(2, 4), 16) / 255, b: parseInt(h.slice(4, 6), 16) / 255, a: a };
}
function luminance(hex) {
    var c = rgba(hex);
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

// Per-section text and number colours, `sectionColors` as JSON:
// {"cpu":{"text":"#ffffff","value":"#44ddaa"}}. A missing part inherits.
var COLOR_PARTS = ["text", "value"];
function sectionColors(text) {
    var out = {};
    try {
        var data = JSON.parse(text || "{}");
        if (!data || typeof data !== "object" || Array.isArray(data))
            return out;
        IDS.forEach(function (id) {
            var own = data[id], clean = {};
            if (!own || typeof own !== "object")
                return;
            COLOR_PARTS.forEach(function (part) {
                if (isColor(own[part]))
                    clean[part] = String(own[part]).toLowerCase();
            });
            if (Object.keys(clean).length)
                out[id] = clean;
        });
    } catch (e) {}
    return out;
}
function sectionColor(cfg, id, part) {
    var own = sectionColors(cfg.sectionColors)[id];
    return own && own[part] || "";
}
// `sectionColors` with one part changed; "" goes back to inheriting.
function withSectionColor(text, id, part, value) {
    var map = sectionColors(text);
    var own = Object.assign({}, map[id] || {});
    if (isColor(value))
        own[part] = String(value).toLowerCase();
    else
        delete own[part];
    if (Object.keys(own).length)
        map[id] = own;
    else
        delete map[id];
    return Object.keys(map).length ? JSON.stringify(map) : "";
}

// The solid card's own colour, or "" for the paper default. Older settings
// gave solid an opaque `bgColor`, which still counts.
function solidColor(cfg) {
    if (isColor(cfg.solidColor))
        return String(cfg.solidColor);
    var bg = String(cfg.bgColor || "");
    return isColor(bg) && rgba(bg).a >= 1 ? bg : "";
}

// Text colour of the card: the user's; on the solid material dark ink on a
// light card and light ink on a dark one; otherwise the theme's.
function textColor(cfg, system) {
    if (!cfg.useSystemTextColor)
        return String(cfg.customTextColor || "#ffffff");
    if (cfg.surfaceStyle !== "solid")
        return String(system);
    var solid = solidColor(cfg);
    return solid && luminance(solid) < 0.45 ? "#eef1f5" : "#1e241d";
}
// One section's text colour: its own, else the card's.
function sectionInk(cfg, id, system) {
    return sectionColor(cfg, id, "text") || textColor(cfg, system);
}

// The colours that light the colour-led materials: the atmosphere's own
// when set (the top light can follow the accent, which is also the
// fallback), else the first two section colours; the third is the
// atmosphere's depth, its own or a dark mix of the two lights.
function materialColors(ids, cfg, fallback) {
    var out = colors(ids, cfg, fallback);
    var atmosphere = cfg.surfaceStyle === "atmosphere";
    if (atmosphere && cfg.atmosphereFollowAccent && isColor(fallback))
        out[0] = String(fallback);
    else if (atmosphere && isColor(cfg.atmosphereColor1))
        out[0] = String(cfg.atmosphereColor1);
    if (atmosphere && isColor(cfg.atmosphereColor2))
        out[1] = String(cfg.atmosphereColor2);
    out.push(atmosphere && isColor(cfg.atmosphereColor3) ? String(cfg.atmosphereColor3) : depthColor(out[0], out[1]));
    return out;
}
function depthColor(c1, c2) {
    var a = rgba(c1), b = rgba(c2);
    var hex = function (v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); };
    return "#" + hex(a.r * 0.2 + b.r * 0.1) + hex(a.g * 0.2 + b.g * 0.1) + hex(a.b * 0.2 + b.b * 0.1);
}

// The glass and liquid tint as a 135° gradient: [[position, {r,g,b,a}], …]
// with every alpha scaled by `strength` (1 = the stock look). `custom`,
// `custom2` (the Custom tint's far end, "" = `custom`), `cover1`, `cover2`
// and `accent` are hex colours.
function glassTint(material, tint, custom, strength, cover1, cover2, custom2, accent) {
    var k = Math.max(0, Number(strength === undefined ? 1 : strength));
    var white = function (a) { return { r: 1, g: 1, b: 1, a: a / 255 }; };
    var tone = function (hex, a) { var c = rgba(hex); return { r: c.r, g: c.g, b: c.b, a: a }; };
    var liquid = material === "liquid", stops;
    if (tint === "frost")
        stops = liquid ? [[0, white(0x2e)], [0.5, white(0x10)], [1, white(0x22)]] : [[0, white(0x42)], [0.55, white(0x24)], [1, white(0x30)]];
    else if (tint === "smoke")
        stops = [[0, { r: 0.07, g: 0.09, b: 0.12, a: 0.64 }], [1, { r: 0.03, g: 0.04, b: 0.07, a: 0.4 }]];
    else if (tint === "cover")
        stops = [[0, tone(cover1, 0.38)], [1, tone(cover2, 0.22)]];
    else if (tint === "custom")
        stops = [[0, tone(custom, 0.4)], [1, tone(isColor(custom2) ? custom2 : custom, 0.22)]];
    else if (tint === "accent")
        stops = [[0, tone(accent || "#3daee9", 0.4)], [1, tone(accent || "#3daee9", 0.22)]];
    else
        stops = liquid ? [[0, white(0x1c)], [0.45, white(0x04)], [1, white(0x12)]] : [[0, white(0x24)], [0.55, white(0x08)], [1, white(0x12)]];
    stops.forEach(function (s) { s[1].a = Math.min(1, s[1].a * k); });
    return stops;
}

// The tint card's fill: its own colour, or, following the accent (Material
// You and the like), that colour tinted towards the accent at its own
// opacity, so a bright accent still leaves a card the text reads on.
var ACCENT_MIX = 0.4;
function tintFill(cfg, accent) {
    var fill = isColor(cfg.bgColor) ? String(cfg.bgColor) : "#800d0f1a";
    if (!cfg.tintFollowAccent || !isColor(accent))
        return fill;
    var f = rgba(fill), c = rgba(accent);
    var hex = function (v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); };
    var mix = function (a, b) { return hex(a + (b - a) * ACCENT_MIX); };
    return "#" + hex(f.a) + mix(f.r, c.r) + mix(f.g, c.g) + mix(f.b, c.b);
}
// A colour setting, or `fallback` while it is empty.
function ownColor(value, fallback) {
    return isColor(value) ? String(value) : fallback;
}

// The pill's caption: a title the user changed, else a short name. `stock`
// is the default title in main.xml, which counts as unchanged.
function shortTitle(id, cfg) {
    var s = info(id), own = String(cfg[s.titleKey] || "");
    return own && own !== s.stock ? own : s.short;
}

function title(id, cfg) {
    var s = info(id);
    return String(cfg[s.titleKey] || s.label);
}

// Grid cell of each section: they fill rows left to right, and a spanning
// section takes a whole row. Shared by MonitorView and the website studio.
function placement(ids, columns, spans) {
    var out = [];
    var row = 0, col = 0;
    ids.forEach(function (id) {
        var span = columns > 1 && spans.indexOf(id) !== -1;
        if (span && col > 0) {
            row++;
            col = 0;
        }
        var width = span ? columns : 1;
        out.push({ row: row, column: col, span: width });
        col += width;
        if (col >= columns) {
            row++;
            col = 0;
        }
    });
    return out;
}

// Manual coordinates are in logical pixels from the dashboard's content edge.
function positions(text) {
    var out = {};
    try {
        var data = JSON.parse(text || "{}");
        if (!data || typeof data !== "object" || Array.isArray(data))
            return out;
        IDS.forEach(function (id) {
            var p = data[id];
            if (!p || typeof p !== "object")
                return;
            var clean = {};
            ["x", "y", "width", "height"].forEach(function (key) {
                if (typeof p[key] === "number" && isFinite(p[key]))
                    clean[key] = Math.round(Math.max(({ width: 180, height: 40 })[key] || 0, Math.min(16384, p[key])));
            });
            out[id] = clean;
        });
    } catch (e) {}
    return out;
}

// `sectionPositions` with some of one section's x, y and width changed.
function position(text, id, change) {
    var map = positions(text);
    map[id] = Object.assign({}, map[id] || {}, change);
    return JSON.stringify(positions(JSON.stringify(map)));
}

// Positions to switch to Manual with, for the sections in `geometry` (from
// MonitorView.geometry(): where the grid has each one now): a section's
// saved position where it has one, else its place in the grid.
function seedPositions(text, geometry) {
    var saved = positions(text), out = {};
    Object.keys(geometry).forEach(function (id) {
        out[id] = saved[id] || geometry[id];
    });
    return JSON.stringify(positions(JSON.stringify(out)));
}
