.pragma library

// Number formatting shared by the widget, the panel pill and the studio.

function speed(bps) {
    if (bps >= 1073741824)
        return (bps / 1073741824).toFixed(2) + " GiB/s";
    if (bps >= 1048576)
        return (bps / 1048576).toFixed(1) + " MiB/s";
    if (bps >= 1024)
        return (bps / 1024).toFixed(1) + " KiB/s";
    return Math.max(0, bps).toFixed(0) + " B/s";
}

function bytes(b) {
    if (b >= 1073741824)
        return (b / 1073741824).toFixed(2) + " GiB";
    if (b >= 1048576)
        return (b / 1048576).toFixed(1) + " MiB";
    if (b >= 1024)
        return (b / 1024).toFixed(1) + " KiB";
    return Math.max(0, b).toFixed(0) + " B";
}

// "1.1 / 1.8 TiB": a part of a whole in the whole's unit, short enough for
// a bar row.
function usage(part, whole) {
    var units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"], u = 0;
    while (u < units.length - 1 && whole >= Math.pow(1024, u + 1))
        u++;
    var short = function (v) {
        v /= Math.pow(1024, u);
        return v > 0 && v < 10 && u > 0 ? v.toFixed(1) : v.toFixed(0);
    };
    return short(Math.max(0, part)) + " / " + short(whole) + " " + units[u];
}

// Axis ticks for a percentage chart.
var PERCENT_TICKS = [
    { value: 100, text: "100%", grid: false },
    { value: 75, text: "75%", grid: true },
    { value: 50, text: "50%", grid: true },
    { value: 25, text: "25%", grid: true },
    { value: 0, text: "0%", grid: false }
];

// Top, middle and zero ticks for an auto-ranged chart.
function rangeTicks(maxValue, format) {
    return [
        { value: maxValue, text: format(maxValue), grid: false },
        { value: maxValue / 2, text: format(maxValue / 2), grid: true },
        { value: 0, text: "0", grid: false }
    ];
}
