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
    { id: "custom", stock: "Load Average", short: "Load", colorKey: "customCmdColor", label: "Custom", titleKey: "customCmdTitle", icon: "M5 8l4 4-4 4M11 16h8" }
];

var IDS = ALL.map(function (s) { return s.id; });

// Order of the legacy activeSection indices.
var LEGACY = ["ping", "network", "cpu", "memory", "custom", "disk", "gpu", "sensors", "system", "power"];

function parse(value, legacyIndex) {
    var out = [];
    var list = Array.isArray(value) ? value : String(value || "").split(",");
    for (var i = 0; i < list.length; i++) {
        var id = String(list[i]).trim();
        if (IDS.indexOf(id) !== -1 && out.indexOf(id) === -1)
            out.push(id);
    }
    if (out.length)
        return out;
    return [LEGACY[legacyIndex] || "cpu"];
}

// What a panel pill shows: `panelSections` when set, else the card's first
// section. The pill may show sections the card does not.
function panelIds(cfg) {
    var picked = String(cfg.panelSections || "").trim() ? parse(cfg.panelSections) : [];
    return picked.length ? picked : [parse(cfg.sections, cfg.activeSection)[0]];
}

function info(id) {
    for (var i = 0; i < ALL.length; i++)
        if (ALL[i].id === id)
            return ALL[i];
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

// Text colour of the card: the user's, dark ink on the light "solid"
// material, otherwise the theme's.
function textColor(cfg, system) {
    if (!cfg.useSystemTextColor)
        return String(cfg.customTextColor || "#ffffff");
    return cfg.surfaceStyle === "solid" ? "#1e241d" : String(system);
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
