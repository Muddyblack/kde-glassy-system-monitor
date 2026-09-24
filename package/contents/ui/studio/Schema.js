.pragma library
.import "StudioCatalog.js" as Catalog
.import "../Sections.js" as Sections

// Every setting the studio edits, for Plasma and Hyprland alike. Hosts pass
// `env` ("kde" or "hypr") to the `when` predicates; `s` is the current draft.

var TABS = Catalog.StudioCatalog.tabs;
// Tabs that share one main tab and switch with a second row of buttons.
var GROUPS = {
    appearance: ["charts", "card", "colors"],
    sections: ["cpu", "memory", "network", "ping", "disk", "gpu", "storage", "processes", "load", "fans", "services", "containers", "sensors", "power", "system", "custom"]
};
var GROUP_LABELS = { appearance: "Appearance", sections: "Sections" };
function tabGroup(id) {
    for (var g in GROUPS)
        if (GROUPS[g].indexOf(id) !== -1)
            return g;
    return id;
}
var MAIN_TABS = [];
(function () {
    var seen = {};
    TABS.forEach(function (t) {
        var g = tabGroup(t.id);
        if (seen[g])
            return;
        seen[g] = true;
        MAIN_TABS.push(g === t.id ? t : { id: g, label: GROUP_LABELS[g], icon: t.icon, first: t.id });
    });
})();
// The Sections group lists only the sections that are switched on.
function subTabs(group, s) {
    var ids = GROUPS[group] || [];
    if (group === "sections" && s) {
        var on = Sections.parse(s.sections, s.activeSection);
        ids = ids.filter(function (id) { return on.indexOf(id) !== -1; });
    }
    return ids.map(function (id) {
        return TABS.filter(function (t) { return t.id === id; })[0];
    });
}
// The tab to open for `id`, moving off a section that is switched off.
function resolveTab(id, s) {
    var group = tabGroup(id);
    if (group !== "sections" || !s)
        return id;
    var list = subTabs(group, s);
    return list.some(function (t) { return t.id === id; }) ? id : (list[0] ? list[0].id : "layout");
}

var REPOSITORY = "https://github.com/Muddyblack/kde-glassy-system-monitor";

// Chart types keep their stored numbers; the order here is the tile order.
var CHARTS = [
    { v: 0, label: "Line", style: "line" },
    { v: 2, label: "Filled area", style: "area" },
    { v: 1, label: "History bars", style: "bars" },
    { v: 3, label: "Donut", style: "donut" },
    { v: 4, label: "Pie", style: "pie" },
    { v: 5, label: "Meters", style: "meter" },
    { v: 6, label: "Numbers only", style: "text" }
];
var STYLE_NAMES = ["line", "bars", "area", "donut", "pie", "meter", "text"];

var SWATCHES = ["#44ddaa", "#22aaff", "#aa66ff", "#ff6688", "#ff9933", "#ffaa22", "#ff6e40", "#39ff14", "#ffffff"];
var GLASS = ["#800d0f1a", "#99000000", "#66101828", "#801a1024", "#6610231d", "#40ffffff", "#00000000"];

// Named colour sets for every metric at once.
var PALETTES = {
    glassy: { label: "Glassy", colors: { cpuColor: "#44ddaa", memColor: "#aa66ff", swapColor: "#ff6688", dlColor: "#22aaff", ulColor: "#ff9933", diskRdColor: "#22ddff", diskWrColor: "#ffaa22", gpuColor: "#ff6e40", pingColor: "#39ff14", customCmdColor: "#ffaa00", storageColor: "#44ddaa", processColor: "#22aaff" } },
    aurora: { label: "Aurora", colors: { cpuColor: "#5ef2c1", memColor: "#b57bff", swapColor: "#ff7ad9", dlColor: "#4aa8ff", ulColor: "#8f6bff", diskRdColor: "#86d6ff", diskWrColor: "#cdb8ff", gpuColor: "#5ef2c1", pingColor: "#5ef2c1", customCmdColor: "#4aa8ff", storageColor: "#5ef2c1", processColor: "#4aa8ff" } },
    ember: { label: "Ember", colors: { cpuColor: "#ffc36b", memColor: "#ff6a3d", swapColor: "#d6246e", dlColor: "#ffc36b", ulColor: "#ff6a3d", diskRdColor: "#ffd6b8", diskWrColor: "#ff8a7a", gpuColor: "#ff4f81", pingColor: "#ffc36b", customCmdColor: "#ff6a3d", storageColor: "#ffc36b", processColor: "#ffc36b" } },
    ice: { label: "Ice", colors: { cpuColor: "#86d6ff", memColor: "#e6f9ff", swapColor: "#3a7bd5", dlColor: "#86d6ff", ulColor: "#3a7bd5", diskRdColor: "#e6f9ff", diskWrColor: "#86d6ff", gpuColor: "#3a7bd5", pingColor: "#86d6ff", customCmdColor: "#e6f9ff", storageColor: "#86d6ff", processColor: "#86d6ff" } },
    terminal: { label: "Terminal", colors: { cpuColor: "#33ff66", memColor: "#33ff66", swapColor: "#ffb000", dlColor: "#33ff66", ulColor: "#ffb000", diskRdColor: "#33ff66", diskWrColor: "#ffb000", gpuColor: "#33ff66", pingColor: "#33ff66", customCmdColor: "#ffb000", storageColor: "#33ff66", processColor: "#33ff66" } },
    mono: { label: "Monochrome", colors: { cpuColor: "#f2f2f2", memColor: "#c8c8c8", swapColor: "#8a8a8a", dlColor: "#f2f2f2", ulColor: "#9a9a9a", diskRdColor: "#f2f2f2", diskWrColor: "#9a9a9a", gpuColor: "#dcdcdc", pingColor: "#f2f2f2", customCmdColor: "#dcdcdc" } }
};

// Card materials; "tint" is the classic tinted card, the rest come from the
// audio visualizer.
var MATERIALS = [["tint", "Tint"], ["glass", "Glass"], ["liquid", "Liquid glass"], ["solid", "Solid"], ["atmosphere", "Atmosphere"]];
function tint(s) {
    return !s.surfaceStyle || s.surfaceStyle === "tint";
}
function glassy(s) {
    return s.surfaceStyle === "glass" || s.surfaceStyle === "liquid";
}

function tab(id, title, rows, when) {
    return { tab: id, title: title, rows: rows, when: when };
}
function shown(id) {
    return function (s) { return Sections.parse(s.sections, s.activeSection).indexOf(id) !== -1; };
}
function title(key, fallback) {
    return { k: key, type: "text", label: "Title", desc: "Shown above the section. Leave empty for “" + fallback + "”.", placeholder: fallback };
}
function color(key, label, desc) {
    return { k: key, type: "color", label: label, desc: desc || "", swatches: SWATCHES };
}

var SECTIONS = [
    tab("presets", "Looks", [
        { id: "looks", type: "looks", full: true, label: "", desc: "presets looks save import export json share neon dashboard minimal gauges gaming laptop" }
    ]),
    tab("layout", "Sections", [
        { id: "sections", type: "sections", full: true, label: "What the widget shows", desc: "Switch sections on, drag them into order by the grip, and give each chart section its own size and style. One widget shows them all; a panel pill shows the first, or the ones picked under Layout › In a panel." },
        { k: "density", type: "seg", label: "Spacing", desc: "Room around and between sections.", opts: [["compact", "Compact"], ["normal", "Normal"], ["roomy", "Roomy"]] },
        { k: "layoutColumns", type: "seg", label: "Columns", desc: "Sections fill the columns left to right. Mark a section full width to give it a row of its own.", opts: [[1, "One"], [2, "Two"], [3, "Three"]] }
    ]),
    tab("layout", "Placement", [
        { k: "monitor", type: "select", label: "Screen", opts: "screens" },
        { k: "hAnchor", type: "seg", label: "Side", opts: [["left", "Left"], ["center", "Centre"], ["right", "Right"]] },
        { k: "verticalPosition", type: "range", label: "Height on screen", desc: "Distance of the top edge from the top of the screen.", min: 0, max: 0.9, step: 0.01, fmt: "pct" },
        { k: "screenMargin", type: "range", label: "Edge margin", min: 0, max: 120, step: 2, fmt: "px" },
        { k: "widgetWidth", type: "range", label: "Width", desc: "0 sizes the card to its sections.", min: 0, max: 800, step: 10, fmt: "px" },
        { k: "desktopLayer", type: "switch", label: "Below windows", desc: "Off keeps the card above application windows." }
    ], function (s, env) { return env === "hypr"; }),
    tab("layout", "In a panel", [
        { id: "panelNote", type: "note", full: true, note: "panel" },
        { k: "panelSections", type: "chips", full: true, label: "Sections in the pill", desc: "None picked: the card's first section.",
          opts: Sections.ALL.concat(Sections.PILL_ONLY).map(function (x) { return [x.id, x.label]; }),
          set: function (v) { return { panelSections: v.join(",") }; } },
        { k: "panelStyle", type: "seg", label: "Pill style", opts: [["values", "Values"], ["spark", "Sparkline"], ["bars", "Mini bars"]] },
        { k: "panelCycle", type: "switch", label: "Tray mode", desc: "One section at a time, turning over on its own; scroll over the pill to step through them." },
        { k: "panelCycleSeconds", type: "range", label: "Turn every", min: 2, max: 30, step: 1, fmt: "s", when: function (s) { return s.panelCycle; } },
        { k: "panelIcons", type: "switch", label: "Icons", desc: "Each section's icon in place of its caption." },
        { k: "panelHoverCard", type: "switch", label: "Card on hover", desc: "Hovering the pill shows the full card; a click keeps it open." },
        { k: "panelMode", type: "switch", label: "Always compact", desc: "Show the panel pill even on the desktop." },
        { k: "panelShowBg", type: "switch", label: "Pill background" },
        { k: "panelPlainText", type: "switch", label: "Plain text", desc: "Use the text colour instead of each metric's colour." },
        { k: "panelShowSessionTotals", type: "switch", label: "Network totals", desc: "Traffic since login, when the panel is tall enough." }
    ]),

    tab("layout", "Machine", [
        { k: "remoteHost", type: "text", label: "Remote host", desc: "Show another machine: user@host or an alias from ~/.ssh/config. Needs key login (no password prompt); the probes run there over one shared SSH connection. Empty shows this machine.", placeholder: "me@server" }
    ]),

    tab("charts", "Chart", [
        { k: "chartType", type: "tiles", full: true, label: "Style", desc: "The default for every section. Sections can override it under Layout.", tw: 96,
          opts: CHARTS.map(function (c) { return { v: c.v, label: c.label, pv: c.style }; }) },
        { k: "historySize", type: "range", label: "History", desc: "Samples across the chart. More shows a longer span.", min: 10, max: 300, step: 10, fmt: "samples" },
        { k: "smoothLines", type: "switch", label: "Smooth curves" },
        { k: "lineWidth", type: "range", label: "Line weight", min: 0.8, max: 6, step: 0.2, fmt: "fixed1" }
    ]),
    tab("charts", "Glow", [
        { k: "glowLine", type: "switch", label: "Glow", desc: "A soft halo around lines and rings." },
        { k: "bloomStrength", type: "range", label: "Glow strength", min: 0.15, max: 1, step: 0.05, fmt: "pct", when: function (s) { return s.glowLine; } }
    ]),
    tab("charts", "Colour by load", [
        { k: "loadColors", type: "switch", label: "Colour by load", desc: "CPU, RAM and GPU lines turn amber, then red, while the load is high; a dashed line marks the warning level." },
        { k: "loadWarn", type: "range", label: "Warning from", min: 30, max: 95, step: 5, fmt: "percent", when: function (s) { return s.loadColors; } },
        { k: "loadCrit", type: "range", label: "Critical from", min: 40, max: 100, step: 5, fmt: "percent", when: function (s) { return s.loadColors; } },
        { k: "loadWarnColor", type: "color", label: "Warning colour", swatches: ["#ffaa22", "#ffd166", "#ff9933", "#eebb00"], when: function (s) { return s.loadColors; } },
        { k: "loadCritColor", type: "color", label: "Critical colour", swatches: ["#ff4444", "#ff2266", "#e63946", "#ff00aa"], when: function (s) { return s.loadColors; } }
    ]),
    tab("charts", "Labels", [
        { k: "showYLabels", type: "switch", label: "Axis labels" },
        { k: "showGridLines", type: "switch", label: "Stronger grid lines" },
        { k: "showLegend", type: "switch", label: "Legend", desc: "Click an entry in the widget to hide that line; hover to highlight it." },
        { k: "autoYRange", type: "switch", label: "Tight auto range", desc: "Network and disk charts scale closer to their peak." }
    ]),

    tab("card", "Material", [
        { k: "surfaceStyle", type: "tiles", full: true, label: "Material", tw: 84,
          opts: MATERIALS.map(function (m) { return { v: m[0], label: m[1], pv: "material" }; }) },
        { id: "cardNote", type: "note", full: true, note: "glass", when: glassy },
        { k: "bgColor", type: "color", label: "Tint", desc: "Colour and opacity of the card. The last swatch removes the card.", swatches: GLASS, when: tint },
        { k: "frostedGlass", type: "switch", label: "Frosted", desc: "Blur the tint into a soft glass gradient.", when: tint },
        { k: "frostStrength", type: "range", label: "Frost", min: 0, max: 1, step: 0.05, fmt: "pct", when: function (s) { return tint(s) && s.frostedGlass; } },
        { k: "glassBlur", type: "range", label: "Wallpaper blur", desc: "How frosted the glass looks. 0% turns blur off; text and charts stay sharp.", min: 0, max: 1, step: 0.01, fmt: "pct", when: glassy },
        { k: "compositorGlass", type: "switch", label: "Compositor glass", desc: "Asks Plasma for its translucent background with native blur.", when: function (s, env) { return glassy(s) && env !== "hypr"; } },
        { k: "cardOpacity", type: "range", label: "Card opacity", desc: "Only the card fades; text and charts stay solid.", min: 0, max: 1, step: 0.02, fmt: "pct" }
    ]),
    tab("card", "Glass colour", [
        { k: "glassTint", type: "seg", label: "Glass tint", opts: [["clear", "Clear"], ["frost", "Frost"], ["smoke", "Smoke"], ["cover", "Section colours"], ["custom", "Custom"]] },
        { k: "glassTintColor", type: "color", label: "Custom glass colour", swatches: SWATCHES, when: function (s) { return s.glassTint === "custom"; } }
    ], glassy),
    tab("card", "Liquid glass", [
        { k: "glassRefraction", type: "range", label: "Refraction", desc: "Bends the wallpaper at the edges with a subtle colour fringe.", min: 0, max: 1, step: 0.05, fmt: "pct" },
        { k: "glassSpecular", type: "switch", label: "Light follows pointer", desc: "A soft highlight tracks the mouse." }
    ], function (s) { return s.surfaceStyle === "liquid"; }),
    tab("card", "Depth & finish", [
        { k: "cardShadow", type: "seg", label: "Shadow", opts: [["none", "None"], ["soft", "Soft"], ["lifted", "Lifted"]] },
        { k: "cardBorder", type: "switch", label: "Glass edge", desc: "Hairline border and a line of light along the top." },
        { k: "grain", type: "switch", label: "Film grain", desc: "Stops gradients from banding." }
    ]),
    tab("card", "Corners", [
        { id: "radius", type: "range", label: "Corner radius", desc: "Glass, solid and atmosphere use one radius for all corners.", min: 0, max: 30, step: 1, fmt: "px",
          get: function (s) { return s.bgRadiusTL; },
          set: function (v) { return { bgRadiusTL: v, bgRadiusTR: v, bgRadiusBR: v, bgRadiusBL: v }; } },
        { k: "bgRadiusTL", type: "range", label: "Top left", min: 0, max: 30, step: 1, fmt: "px", when: tint },
        { k: "bgRadiusTR", type: "range", label: "Top right", min: 0, max: 30, step: 1, fmt: "px", when: tint },
        { k: "bgRadiusBL", type: "range", label: "Bottom left", min: 0, max: 30, step: 1, fmt: "px", when: tint },
        { k: "bgRadiusBR", type: "range", label: "Bottom right", min: 0, max: 30, step: 1, fmt: "px", when: tint }
    ]),

    tab("colors", "Palette", [
        { id: "palette", type: "chips", single: true, full: true, label: "Metric colours", desc: "Recolours every section at once. Each section's tab can change its own colours after.",
          opts: Object.keys(PALETTES).map(function (k) { return [k, PALETTES[k].label]; }),
          get: function (s) {
              for (var k in PALETTES) {
                  var c = PALETTES[k].colors, all = true;
                  for (var key in c) if (String(s[key]).toLowerCase() !== c[key]) all = false;
                  if (all) return [k];
              }
              return [];
          },
          set: function (v) { var k = v[v.length - 1]; return k ? PALETTES[k].colors : {}; } }
    ]),
    tab("colors", "Text", [
        { k: "fontFamily", type: "seg", label: "Font", opts: [["system", "System"], ["monospace", "Monospace"]] },
        { k: "useSystemTextColor", type: "seg", label: "Text colour", opts: [[true, "Follow theme"], [false, "Custom"]] },
        { k: "customTextColor", type: "color", label: "Custom text colour", swatches: ["#ffffff", "#eef1f5", "#c8d0da", "#1e241d", "#000000"], when: function (s) { return !s.useSystemTextColor; } }
    ]),

    tab("cpu", "CPU", [
        title("cpuTitle", "CPU"),
        color("cpuColor", "Colour"),
        { k: "showCpuCores", type: "switch", label: "Per-core lines", desc: "Every thread as a faint line with a readout grid. Click a core in the widget to hide it." },
        { k: "coreColorsStr", type: "text", label: "Core colours", desc: "Comma-separated, reused in order for more cores.", when: function (s) { return s.showCpuCores; } }
    ]),
    tab("memory", "Memory", [
        title("memoryTitle", "Memory"),
        color("memColor", "RAM colour"),
        color("swapColor", "Swap colour")
    ]),
    tab("network", "Network", [
        title("networkTitle", "Network"),
        { k: "networkInterface", type: "ifaces", label: "Interface", desc: "Automatic follows the default route, falling back to an active link. The network window (⧉ in the section header) shows every interface in detail.", full: true },
        { k: "netShowInfo", type: "switch", label: "Wi-Fi name and IP" },
        color("dlColor", "Download colour"),
        color("ulColor", "Upload colour"),
        { k: "accurateGeo", type: "switch", label: "GeoIP flags in connections", desc: "Uses a local MaxMind database when one is installed; otherwise flags are guessed from host names." }
    ]),
    tab("ping", "Ping", [
        title("pingTitle", "Ping"),
        { k: "targets", type: "text", label: "Hosts", desc: "Comma-separated. Click a host in the widget to switch.", placeholder: "1.1.1.1, 8.8.8.8" },
        { k: "pingInterval", type: "range", label: "Every", min: 1, max: 30, step: 1, fmt: "s" },
        { k: "pingTimeout", type: "range", label: "Timeout", min: 1, max: 10, step: 1, fmt: "s" },
        { k: "showStats", type: "switch", label: "Average, jitter and loss" }
    ]),
    tab("ping", "Alerts", [
        { k: "latencyThreshold", type: "range", label: "Slow above", desc: "Warning colour from here, critical from half again as much.", min: 10, max: 500, step: 5, fmt: "ms" },
        { k: "lossThreshold", type: "range", label: "Loss alert above", min: 0, max: 50, step: 1, fmt: "percent" },
        { k: "jitterThreshold", type: "range", label: "Jitter warning above", min: 0, max: 200, step: 5, fmt: "ms" },
        { k: "pingThresholdColors", type: "switch", label: "Colour by latency" },
        { k: "pingAlertPulse", type: "switch", label: "Pulse the card on alerts" },
        color("pingColor", "Normal"),
        color("pingWarnColor", "Warning"),
        color("pingCritColor", "Critical and lost packets")
    ]),
    tab("disk", "Disk I/O", [
        title("diskTitle", "Disk I/O"),
        { k: "diskDevice", type: "select", label: "Disk", desc: "Automatic follows the busiest one.", opts: "disks" },
        color("diskRdColor", "Read colour"),
        color("diskWrColor", "Write colour")
    ]),
    tab("gpu", "GPU", [
        title("gpuTitle", "GPU"),
        { k: "gpuDevice", type: "select", label: "Card", desc: "Automatic prefers a card that reports its load.", opts: "gpus" },
        { k: "gpuShowEngines", type: "switch", label: "VRAM and engines", desc: "Compute, decode and encode shares where the driver reports them." },
        color("gpuColor", "Colour")
    ]),
    tab("sensors", "Hardware sensors", [
        title("hwSensorsTitle", "Hardware Sensors"),
        { id: "sensorsNote", type: "note", full: true, note: "sensors" },
        { k: "hwTempWarn", type: "range", label: "Warm from", min: 40, max: 110, step: 1, fmt: "celsius" },
        { k: "hwTempCrit", type: "range", label: "Hot from", min: 50, max: 120, step: 1, fmt: "celsius" }
    ]),
    tab("power", "Power", [
        title("powerTitle", "Power"),
        { id: "powerNote", type: "note", full: true, note: "power" },
        { k: "powerChart", type: "seg", label: "Chart", desc: "Also switchable in the widget.", opts: [["power", "Power (W)"], ["battery", "Battery %"], ["temp", "Temperature"]] },
        { k: "powerShowProfiles", type: "switch", label: "Power profile buttons", desc: "Balanced, performance and saver, through power-profiles-daemon." },
        { k: "powerShowSources", type: "switch", label: "Where the power goes", desc: "CPU package, GPU and platform draw from energy counters and power sensors." },
        { k: "powerShowPressure", type: "switch", label: "Pressure", desc: "How long tasks waited for CPU and memory (PSI)." },
        color("powerColor", "Battery flow colour"),
        color("powerLoadColor", "Load colour")
    ]),
    tab("system", "System info", [
        title("osInfoTitle", "System Info"),
        { k: "osUseFetch", type: "switch", label: "Use a fetch tool", desc: "fastfetch, neofetch and friends, when installed." },
        { k: "osFetchCmd", type: "text", label: "Fetch command", desc: "Empty tries the known tools in turn.", placeholder: "fastfetch", when: function (s) { return s.osUseFetch; } },
        { k: "osPlainText", type: "switch", label: "Show the tool's own output", when: function (s) { return s.osUseFetch; } },
        { k: "osShowLogo", type: "switch", label: "Distro logo", when: function (s) { return s.osUseFetch; } }
    ]),
    tab("storage", "Storage", [
        title("storageTitle", "Storage"),
        { k: "storageMounts", type: "text", label: "Mount points", desc: "Comma-separated, in order. Empty shows every real filesystem of 256 MiB or more.", placeholder: "/, /home, /mnt/data" },
        color("storageColor", "Colour", "Bars turn amber past 85% full and red past 95%.")
    ]),
    tab("processes", "Top processes", [
        title("processesTitle", "Processes"),
        { k: "processSort", type: "seg", label: "Sort by", opts: [["cpu", "CPU"], ["memory", "Memory"]] },
        { k: "processCount", type: "range", label: "Rows", min: 3, max: 10, step: 1, fmt: "samples" },
        { k: "processGroup", type: "switch", label: "Group by name", desc: "A browser's many helper processes become one row." },
        color("processColor", "Colour")
    ]),
    tab("load", "Load & uptime", [
        title("loadTitle", "Load"),
        color("loadColor", "Colour", "The 5 and 15 minute averages are fainter lines of the same colour; the dashed line marks every CPU busy.")
    ]),
    tab("fans", "Fans", [
        title("fansTitle", "Fans"),
        { id: "fansNote", type: "note", full: true, note: "sensors" },
        color("fanColor", "Colour")
    ]),
    tab("services", "Services", [
        title("servicesTitle", "Services"),
        { k: "serviceUnits", type: "text", label: "Watch units", desc: "Comma-separated; prefix user units with user:. Failed units always show.", placeholder: "sshd, docker, user:syncthing" },
        color("serviceColor", "Colour")
    ]),
    tab("containers", "Containers", [
        title("containersTitle", "Containers"),
        { k: "containerSource", type: "seg", label: "Show", opts: [["all", "Everything"], ["containers", "Docker & Podman"], ["kubernetes", "Kubernetes"]] },
        { k: "kubeNamespace", type: "text", label: "Namespace", desc: "Kubernetes pods (kubectl or k3s) from ~/.kube/config, $KUBECONFIG or a readable /etc/rancher/k3s/k3s.yaml. Empty shows every namespace.", placeholder: "default", when: function (s) { return s.containerSource !== "containers"; } },
        { k: "containerSort", type: "seg", label: "Sort by", opts: [["cpu", "CPU"], ["memory", "Memory"], ["name", "Name"]] },
        { k: "containerCount", type: "range", label: "Rows", min: 3, max: 20, step: 1, fmt: "samples" },
        { k: "containerShowStopped", type: "switch", label: "Stopped ones too" },
        color("containerColor", "Colour")
    ]),
    tab("custom", "Custom sensor", [
        title("customCmdTitle", "Custom"),
        { k: "customCmd", type: "text", label: "Command", desc: "Runs through sh and must print one number.", placeholder: "cat /proc/loadavg | awk '{print $1}'" },
        { k: "customCmdUnit", type: "text", label: "Unit", placeholder: "°C" },
        { k: "customCmdMax", type: "number", label: "Chart maximum" },
        { k: "customCmdInterval", type: "range", label: "Every", min: 1, max: 60, step: 1, fmt: "s" },
        color("customCmdColor", "Colour")
    ]),

    tab("performance", "Rendering", [
        { k: "chartRenderer", type: "seg", label: "Renderer", opts: [["gpu", "GPU shader"], ["canvas", "Canvas (classic)"]] },
        { id: "rendererNote", type: "note", full: true, note: "renderer" },
        { k: "gpuBloom", type: "switch", label: "Blurred glow", desc: "Canvas renderer only: a GPU blur pass instead of a stroked halo.", when: function (s) { return s.chartRenderer === "canvas"; } }
    ]),
    tab("performance", "Motion and sampling", [
        { k: "updateInterval", type: "range", label: "Update every", desc: "How often CPU, memory, network and disk are read.", min: 250, max: 5000, step: 250, fmt: "ms" },
        { k: "smoothScroll", type: "switch", label: "Smooth scrolling", desc: "Glide between samples instead of stepping." },
        { k: "targetFps", type: "range", label: "Frame rate cap", desc: "Lower saves power; 24–30 already glides.", min: 15, max: 144, step: 1, fmt: "hz", when: function (s) { return s.smoothScroll; } }
    ]),

    tab("about", "About the project", [{ id: "projectInfo", type: "projectInfo", full: true, label: "", desc: "Muddyblack GitHub KDE Store downloads stars support project version license" }])
];

// A switched-off section's settings stay out of the way, search included.
SECTIONS.forEach(function (section) {
    if (GROUPS.sections.indexOf(section.tab) === -1)
        return;
    var own = section.when;
    section.when = function (s, env) {
        return shown(section.tab)(s) && (!own || own(s, env));
    };
});

var NOTES = {
    glass: {
        kde: "Glass blurs and bends the desktop wallpaper behind the card. A panel popup has no wallpaper to sample, so only the tint shows there.",
        hypr: "Quickshell cannot sample the wallpaper. For Hyprland 0.53 hyprland.conf, add `layerrule = blur on, ignore_alpha 0, match:namespace glassy-system-monitor`. For newer Lua configs, use `hl.layer_rule({ match = { namespace = \"glassy-system-monitor\" }, blur = true, ignore_alpha = 0 })`."
    },
    panel: {
        kde: "Placed in a panel, the widget shows a pill; hovering it shows the full card, and a click keeps the card open.",
        hypr: "Add hyprland/MonitorPill.qml to a Quickshell bar for the pill; hovering it shows the full card, and a click keeps it open."
    },
    sensors: {
        kde: "Reads lm-sensors (`sensors -j`). If nothing shows, install lm-sensors and run sensors-detect once.",
        hypr: "Reads lm-sensors (`sensors -j`). If nothing shows, install lm-sensors and run sensors-detect once."
    },
    power: {
        kde: "Battery from /sys/class/power_supply, draw from RAPL energy counters and hwmon power sensors (amdgpu; nvidia-smi when the GPU section uses it), pressure from /proc/pressure. Some distributions make RAPL root-only; then only GPU sensors and the battery show.",
        hypr: "Battery from /sys/class/power_supply, draw from RAPL energy counters and hwmon power sensors (amdgpu; nvidia-smi when the GPU section uses it), pressure from /proc/pressure. Some distributions make RAPL root-only; then only GPU sensors and the battery show."
    },
    renderer: {
        kde: "The GPU shader draws each new sample once and slides it while scrolling; the canvas renderer is the original Context2D path, kept as a fallback. Software rendering always uses the canvas.",
        hypr: "The GPU shader draws each new sample once and slides it while scrolling; the canvas renderer is the original Context2D path, kept as a fallback. Software rendering always uses the canvas."
    }
};

function format(kind, v) {
    switch (kind) {
    case "pct": return Math.round(v * 100) + "%";
    case "px": return Math.round(v) + " px";
    case "percent": return Math.round(v) + "%";
    case "fixed1": return Number(v).toFixed(1);
    case "ms": return Math.round(v) + " ms";
    case "hz": return Math.round(v) + " Hz";
    case "s": return Number(v) + " s";
    case "samples": return Math.round(v) + "";
    case "celsius": return Math.round(v) + " °C";
    default: return String(v);
    }
}
function fields(value) {
    return (Array.isArray(value) ? value : String(value || "").split(",")).map(function (v) { return String(v).trim(); }).filter(Boolean);
}
function normalize(patch) {
    return patch;
}
function rowValue(row, s) {
    return row.get ? row.get(s) : s[row.k];
}
function rowPatch(row, value, state) {
    if (row.set)
        return row.set(value, state);
    var patch = {};
    patch[row.k] = value;
    return patch;
}
function optionLabels(row) {
    return Array.isArray(row.opts) ? row.opts.map(function (o) { return Array.isArray(o) ? o[1] : o.label; }).join(" ") : "";
}
function searchText(row, section) {
    return [row.label || "", row.desc || "", row.k || "", optionLabels(row), section.title].join(" ").toLowerCase();
}
function rowVisible(row, section, s, env, query) {
    if (section.when && !section.when(s, env))
        return false;
    if (row.when && !row.when(s, env))
        return false;
    return query === "" || searchText(row, section).indexOf(query) !== -1;
}

// Per-section chart styles, "memory:donut,cpu:line" ⇄ { memory: "donut" }.
function parseStyles(text) {
    var out = {};
    String(text || "").split(",").forEach(function (pair) {
        var p = pair.split(":");
        if (p.length === 2 && STYLE_NAMES.indexOf(p[1].trim()) !== -1)
            out[p[0].trim()] = p[1].trim();
    });
    return out;
}
function formatStyles(map) {
    return Object.keys(map).filter(function (k) { return map[k]; }).map(function (k) { return k + ":" + map[k]; }).join(",");
}
