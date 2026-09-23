.pragma library

// Shared by both diagram renderers: chart style names, the value mapping, and
// the data texture the fragment shader reads (layout in shaders/diagram.frag).

var STYLES = ["line", "bars", "area", "donut", "pie", "meter", "text"];
var MODES = { line: 0, bars: 1, area: 2, donut: 3, pie: 4 };
var ROW = 256;
var HEADER = 4;
var FLAG_GLOW = 1, FLAG_HEAD = 2, FLAG_GAPS = 4;

function styleName(chartType) {
    return STYLES[chartType] || "line";
}

function scrolls(style) {
    return style === "line" || style === "bars" || style === "area";
}

function isGauge(style) {
    return style === "donut" || style === "pie";
}

// Fraction of the chart height above the top value and below zero.
var TOP_PAD = 0.06;
var USED = 0.88;

function yOf(value, maxValue, height) {
    return height - height * TOP_PAD - Math.max(0, Math.min(1, value / maxValue)) * height * USED;
}

// A series as sections declare it, with every optional field resolved.
function normalize(entry, defaults) {
    return {
        values: entry.values || [],
        value: entry.value,
        color: entry.color || "#ffffff",
        alpha: entry.alpha === undefined ? 1 : entry.alpha,
        width: entry.width === undefined ? defaults.lineWidth : entry.width,
        fill: entry.fill === undefined ? defaults.fill : entry.fill,
        glow: entry.glow === undefined ? true : !!entry.glow,
        head: !!entry.head,
        gaps: !!entry.gaps,
        bands: entry.bands || null,
        ring: entry.ring || null,
        label: entry.label || "",
        text: entry.text || ""
    };
}

// Gauges draw one current value per series.
function gaugeValue(s) {
    if (s.value !== undefined && s.value !== null)
        return s.value;
    return s.values.length ? s.values[s.values.length - 1] : 0;
}

// Outer ring first; later series nest inside it the way the canvas charts did.
function ringOf(s, index) {
    if (s.ring)
        return s.ring;
    return index === 0 ? [1, 1] : [0.58, 0.72];
}

function byte(v) {
    return Math.max(0, Math.min(255, Math.round(v)));
}

// Returns { width, height, stride, bytes }: bytes is RGBA, row-major.
function encode(series, maxValue, style, minRows) {
    var gauge = isGauge(style);
    var count = series.length;
    var stride = 1;
    for (var s = 0; s < count; s++)
        stride = Math.max(stride, gauge ? 1 : series[s].values.length);
    var rows = Math.max(minRows || 2, 1 + Math.ceil(count * stride / ROW));
    var bytes = new Array(ROW * rows * 4);
    for (var k = 0; k < bytes.length; k += 4) {
        bytes[k] = 0;
        bytes[k + 1] = 0;
        bytes[k + 2] = 0;
        bytes[k + 3] = 255;
    }
    var limit = Math.max(1e-9, maxValue);
    for (s = 0; s < count && s < ROW / HEADER; s++) {
        var e = series[s];
        var c = Qt.color(e.color);
        var h = s * HEADER * 4;
        var ring = ringOf(e, s);
        var values = gauge ? [gaugeValue(e)] : e.values;
        var flags = (e.glow ? FLAG_GLOW : 0) | (e.head ? FLAG_HEAD : 0) | (e.gaps ? FLAG_GAPS : 0);
        bytes[h] = byte(c.r * 255);
        bytes[h + 1] = byte(c.g * 255);
        bytes[h + 2] = byte(c.b * 255);
        bytes[h + 4] = byte(e.alpha * c.a * 255);
        bytes[h + 5] = byte(e.width * 16);
        bytes[h + 6] = byte(e.fill * 255);
        bytes[h + 8] = flags;
        bytes[h + 9] = byte(ring[0] * 255);
        bytes[h + 10] = byte(ring[1] * 255);
        bytes[h + 12] = values.length >> 8;
        bytes[h + 13] = values.length & 255;
        for (var i = 0; i < values.length; i++) {
            var v = values[i];
            var at = (ROW + s * stride + i) * 4;
            var q = v === null || v === undefined || v < 0 || !isFinite(v) ? 65535 : Math.round(Math.min(1, v / limit) * 65534);
            bytes[at] = q >> 8;
            bytes[at + 1] = q & 255;
            bytes[at + 2] = e.bands ? byte(e.bands[i] || 0) : 0;
        }
    }
    return { width: ROW, height: rows, stride: stride, bytes: bytes };
}

// Upper value bound for auto-ranged charts: data maximum plus headroom, never
// below `floor` so an idle line does not fill the chart.
function autoMax(lists, floor, headroom) {
    var top = 0;
    for (var l = 0; l < lists.length; l++) {
        var list = lists[l] || [];
        for (var i = 0; i < list.length; i++)
            if (list[i] > top)
                top = list[i];
    }
    return Math.max(floor, top * headroom);
}

// Axis ticks as { value, text, grid }; `format` renders a value.
function ticks(maxValue, fractions, format) {
    return fractions.map(function (f, i) {
        return {
            value: maxValue * f,
            text: format(maxValue * f),
            grid: i > 0 && i < fractions.length - 1
        };
    });
}
