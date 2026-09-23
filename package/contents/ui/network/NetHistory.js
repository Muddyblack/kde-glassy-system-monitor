.pragma library

// Traffic history that outlives the session: per day the totals, 24 hourly
// buckets, and bytes per app, domain, country and interface. On disk
// (NetStore, ~/.local/share/glassy-system-monitor/, private):
//   network-today.json      today, a few KB, saved every five minutes
//   network-YYYY-MM.json    one file per month; only the current month is
//                           ever rewritten, once a day
// Days older than FULL_DAYS keep their top COMPACT_ENTRIES and lose the
// hourly buckets (about 1 KB a day), so years stay small and quick to load.

var FORMAT = "glassy-network-history";
var TODAY_FORMAT = "glassy-network-today";
var VERSION = 1;
var MAX_ENTRIES = 40;
var COMPACT_ENTRIES = 10;
var FULL_DAYS = 62;
var DAY = 86400000;

function empty() {
    return { format: FORMAT, version: VERSION, updated: 0, days: {} };
}

function pad(n) {
    return n < 10 ? "0" + n : String(n);
}
// "2026-09-23" in local time.
function dayKey(ms) {
    var d = new Date(ms);
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}
function monthOf(key) {
    return String(key).slice(0, 7);
}
// Noon of a day key, in local time (safe across DST).
function dayStart(key) {
    var p = String(key).split("-").map(Number);
    return new Date(p[0], p[1] - 1, p[2], 12).getTime();
}
// The day key `n` calendar days from `ms`: not n × 24 h, which lands on
// the same date twice (or skips one) across a DST change near midnight.
function dayKeyAdd(ms, n) {
    var d = new Date(ms);
    return dayKey(new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, 12).getTime());
}

function blankHours() {
    var h = [];
    for (var i = 0; i < 24; i++)
        h.push([0, 0]);
    return h;
}
function pairs(map) {
    var out = {};
    if (map && typeof map === "object")
        for (var k in map)
            if (Array.isArray(map[k]))
                out[k] = map[k].map(function (v) { return Number(v) || 0; });
    return out;
}

// One day as stored, checked field by field.
function cleanDay(d) {
    if (!d || typeof d !== "object")
        return null;
    var apps = {};
    if (d.apps && typeof d.apps === "object")
        for (var k in d.apps) {
            var a = d.apps[k];
            if (a && typeof a === "object")
                apps[k] = { name: String(a.name || k), icon: String(a.icon || ""), "in": Number(a["in"]) || 0, out: Number(a.out) || 0, conns: Number(a.conns) || 0 };
        }
    return {
        "in": Number(d["in"]) || 0,
        out: Number(d.out) || 0,
        hours: Array.isArray(d.hours) && d.hours.length === 24 ? d.hours.map(function (h) { return [Number(h[0]) || 0, Number(h[1]) || 0]; }) : d.compact ? null : blankHours(),
        compact: !!d.compact,
        apps: apps,
        domains: pairs(d.domains),
        countries: pairs(d.countries),
        ifaces: pairs(d.ifaces)
    };
}

// A loaded file → { history, writable, error }. Newer formats are read but
// never written back (an older Glassy must not clobber a newer one's data);
// anything that is not our history is refused.
function migrate(value) {
    if (value === null || value === undefined)
        return { history: empty(), writable: true, error: "" };
    if (typeof value !== "object" || value.format !== FORMAT || typeof value.days !== "object" || value.days === null)
        return { history: empty(), writable: false, error: "not a Glassy network history" };
    if (!(value.version >= 1))
        return { history: empty(), writable: false, error: "unknown history version" };
    if (value.version > VERSION)
        return { history: value, writable: false, error: "written by a newer Glassy (format " + value.version + "); shown read-only" };
    var days = {};
    for (var key in value.days) {
        var d = /^\d{4}-\d{2}-\d{2}$/.test(key) ? cleanDay(value.days[key]) : null;
        if (d)
            days[key] = d;
    }
    return { history: { format: FORMAT, version: VERSION, updated: Number(value.updated) || 0, days: days }, writable: true, error: "" };
}

// Everything read from disk → one history. parts: { legacy (the single
// network-history.json of earlier builds), months: [values], today }.
// Later sources win for the same day: legacy < months < today.
function join(parts) {
    var out = migrate(parts.legacy);
    if (!out.writable)
        return out;
    var months = parts.months || [];
    for (var i = 0; i < months.length; i++) {
        var m = migrate(months[i]);
        if (!m.writable)
            return { history: out.history, writable: false, error: "a month file: " + m.error };
        for (var k in m.history.days)
            out.history.days[k] = m.history.days[k];
    }
    var t = parts.today;
    if (t !== null && t !== undefined) {
        if (typeof t !== "object" || t.format !== TODAY_FORMAT || !(t.version >= 1))
            return { history: out.history, writable: false, error: "network-today.json is not a Glassy file" };
        if (t.version > VERSION)
            return { history: out.history, writable: false, error: "network-today.json was written by a newer Glassy; shown read-only" };
        var d = /^\d{4}-\d{2}-\d{2}$/.test(t.day) ? cleanDay(t.data) : null;
        if (d)
            out.history.days[t.day] = d;
    }
    return out;
}

// → { today: file, months: { "2026-09": file } } (today excluded from months).
function split(history, now) {
    var key = dayKey(now), months = {};
    for (var k in history.days) {
        if (k === key)
            continue;
        var m = monthOf(k);
        var file = months[m] || (months[m] = { format: FORMAT, version: VERSION, month: m, updated: history.updated, days: {} });
        file.days[k] = history.days[k];
    }
    return {
        today: { format: TODAY_FORMAT, version: VERSION, day: key, data: history.days[key] || null },
        months: months
    };
}

function day(history, key) {
    return history.days[key] || (history.days[key] = { "in": 0, out: 0, hours: blankHours(), compact: false, apps: {}, domains: {}, countries: {}, ifaces: {} });
}

// One poll into the history (mutates and returns it).
// sample: { time, totalIn, totalOut (bytes on the physical links since the
// last poll), ifaces { name: { in, out } }, conns: [{ app {key, name, icon},
// domain, country, deltaIn, deltaOut, isNew }] }
function record(history, sample) {
    var d = day(history, dayKey(sample.time));
    if (!d.hours)
        d.hours = blankHours();
    var hour = new Date(sample.time).getHours();
    var tin = Math.max(0, sample.totalIn || 0), tout = Math.max(0, sample.totalOut || 0);
    d["in"] += tin;
    d.out += tout;
    d.hours[hour][0] += tin;
    d.hours[hour][1] += tout;
    if (!d.ifaces)
        d.ifaces = {};
    for (var n in sample.ifaces || {}) {
        var v = sample.ifaces[n];
        if (!(v["in"] > 0 || v.out > 0))
            continue;
        var f = d.ifaces[n] || (d.ifaces[n] = [0, 0]);
        f[0] += Math.max(0, v["in"] || 0);
        f[1] += Math.max(0, v.out || 0);
    }
    (sample.conns || []).forEach(function (c) {
        var i = Math.max(0, c.deltaIn || 0), o = Math.max(0, c.deltaOut || 0);
        if (!i && !o && !c.isNew)
            return;
        var a = d.apps[c.app.key] || (d.apps[c.app.key] = { name: c.app.name, icon: c.app.icon, "in": 0, out: 0, conns: 0 });
        a.name = c.app.name;
        a.icon = c.app.icon;
        a["in"] += i;
        a.out += o;
        if (c.isNew)
            a.conns++;
        if (c.domain) {
            var dm = d.domains[c.domain] || (d.domains[c.domain] = [0, 0, 0]);
            dm[0] += i;
            dm[1] += o;
            if (c.isNew)
                dm[2]++;
        }
        if (c.country) {
            var cc = d.countries[c.country] || (d.countries[c.country] = [0, 0]);
            cc[0] += i;
            cc[1] += o;
        }
    });
    history.updated = sample.time;
    return history;
}

function keepTop(map, total, count) {
    var keys = Object.keys(map);
    if (keys.length <= count)
        return map;
    keys.sort(function (a, b) { return total(map[b]) - total(map[a]); });
    var out = {};
    keys.slice(0, count).forEach(function (k) { out[k] = map[k]; });
    return out;
}
function appTotal(a) {
    return a["in"] + a.out;
}
function pairTotal(x) {
    return x[0] + x[1];
}

// How long the history is kept (the user's choice; default a year).
var RETENTION = { "30d": 30, "90d": 90, "1y": 366, "2y": 731, all: 0 };
var DEFAULT_RETENTION = "1y";

// Busy days keep their top entries; days older than FULL_DAYS shrink to
// their top COMPACT_ENTRIES without hours; days beyond the retention go.
// → { changed: { month: true }, removed: { month: true } } (months whose
// file must be rewritten, and months with no day left to delete).
function prune(history, now, retention) {
    var cutoff = dayKeyAdd(now, -FULL_DAYS), changed = {}, removed = {};
    var keep = RETENTION[retention === undefined ? DEFAULT_RETENTION : retention] || 0;
    var oldest = keep ? dayKeyAdd(now, -(keep - 1)) : "";
    for (var k in history.days) {
        if (oldest && k < oldest) {
            delete history.days[k];
            changed[monthOf(k)] = true;
            continue;
        }
        var d = history.days[k];
        var old = k < cutoff;
        var n = old ? COMPACT_ENTRIES : MAX_ENTRIES;
        var before = Object.keys(d.apps).length + Object.keys(d.domains).length + Object.keys(d.countries).length;
        d.apps = keepTop(d.apps, appTotal, n);
        d.domains = keepTop(d.domains, pairTotal, n);
        d.countries = keepTop(d.countries, pairTotal, n);
        var after = Object.keys(d.apps).length + Object.keys(d.domains).length + Object.keys(d.countries).length;
        if (old && !d.compact) {
            d.compact = true;
            d.hours = null;
            changed[monthOf(k)] = true;
        } else if (after !== before) {
            changed[monthOf(k)] = true;
        }
    }
    var alive = {};
    for (var key in history.days)
        alive[monthOf(key)] = true;
    for (var m in changed)
        if (!alive[m]) {
            removed[m] = true;
            delete changed[m];
        }
    return { changed: changed, removed: removed };
}

// Today's bytes (in + out) of one app, for daily limits.
function appToday(history, now, key) {
    var d = history.days[dayKey(now)];
    var a = d && d.apps[key];
    return a ? a["in"] + a.out : 0;
}

// The first day each app appears: { key: "2026-09-01" }.
function firstSeen(history) {
    var out = {};
    Object.keys(history.days).sort().forEach(function (k) {
        for (var a in history.days[k].apps)
            if (!out[a])
                out[a] = k;
    });
    return out;
}

// ── Timeline ─────────────────────────────────────────────────────────────────
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// Move a period's anchor one step back (-1) or forward (+1).
function shift(kind, anchor, dir) {
    var d = new Date(anchor);
    if (kind === "day")
        d.setDate(d.getDate() + dir);
    else if (kind === "week")
        d.setDate(d.getDate() + 7 * dir);
    else if (kind === "month")
        d.setMonth(d.getMonth() + dir, 1);
    else if (kind === "year")
        d.setFullYear(d.getFullYear() + dir, 0, 1);
    d.setHours(12, 0, 0, 0);
    return d.getTime();
}

function sumDays(history, keys) {
    var s = { "in": 0, out: 0 };
    keys.forEach(function (k) {
        var d = history.days[k];
        if (d) {
            s["in"] += d["in"];
            s.out += d.out;
        }
    });
    return s;
}
function daysBetween(fromKey, toKey) {
    var out = [];
    for (var t = dayStart(fromKey); dayKey(t) <= toKey && out.length < 400; t += DAY)
        out.push(dayKey(t));
    return out;
}

// A period of the timeline: kind "day" (24 hours), "week" (Mon–Sun),
// "month", "year" (12 months) or "all" (every recorded month).
// → { kind, title, keys (its days), buckets [{ label, in, out, drill }],
//     canForward } where drill is { kind, anchor } or null.
function period(history, kind, anchor, now) {
    var a = new Date(anchor), today = dayKey(now), buckets = [], keys = [], title = "";
    if (kind === "day") {
        var key = dayKey(anchor), d = history.days[key];
        keys = [key];
        title = WEEKDAYS[a.getDay()] + " " + a.getDate() + " " + MONTHS[a.getMonth()] + " " + a.getFullYear();
        for (var h = 0; h < 24; h++)
            buckets.push({ label: h % 3 === 0 ? pad(h) : "", "in": d && d.hours ? d.hours[h][0] : 0, out: d && d.hours ? d.hours[h][1] : 0, drill: null });
    } else if (kind === "week" || kind === "month") {
        var start;
        if (kind === "week") {
            start = new Date(a);
            start.setDate(a.getDate() - (a.getDay() + 6) % 7);
            keys = daysBetween(dayKey(start.getTime()), dayKeyAdd(start.getTime(), 6));
            title = "Week of " + start.getDate() + " " + MONTHS[start.getMonth()] + " " + start.getFullYear();
        } else {
            start = new Date(a.getFullYear(), a.getMonth(), 1, 12);
            var last = new Date(a.getFullYear(), a.getMonth() + 1, 0, 12);
            keys = daysBetween(dayKey(start.getTime()), dayKey(last.getTime()));
            title = MONTHS[a.getMonth()] + " " + a.getFullYear();
        }
        keys.forEach(function (k) {
            var t = dayStart(k), s = sumDays(history, [k]);
            buckets.push({ label: kind === "week" ? WEEKDAYS[new Date(t).getDay()] + " " + new Date(t).getDate() : String(new Date(t).getDate()), "in": s["in"], out: s.out, drill: { kind: "day", anchor: t } });
        });
    } else {
        var months = [];
        if (kind === "year") {
            for (var m = 0; m < 12; m++)
                months.push([a.getFullYear(), m]);
            title = String(a.getFullYear());
        } else {
            var first = Object.keys(history.days).sort()[0] || today;
            var y = Number(first.slice(0, 4)), mm = Number(first.slice(5, 7)) - 1;
            var end = new Date(now);
            while ((y < end.getFullYear() || (y === end.getFullYear() && mm <= end.getMonth())) && months.length < 600) {
                months.push([y, mm]);
                if (++mm === 12) {
                    mm = 0;
                    y++;
                }
            }
            title = "All time";
        }
        months.forEach(function (ym) {
            var from = ym[0] + "-" + pad(ym[1] + 1) + "-01";
            var to = dayKey(new Date(ym[0], ym[1] + 1, 0, 12).getTime());
            var ks = daysBetween(from, to);
            keys = keys.concat(ks);
            var s = sumDays(history, ks);
            buckets.push({ label: kind === "year" ? MONTHS[ym[1]] : MONTHS[ym[1]] + (ym[1] === 0 || months.length <= 12 ? " " + String(ym[0]).slice(2) : ""), "in": s["in"], out: s.out, drill: { kind: "month", anchor: new Date(ym[0], ym[1], 1, 12).getTime() } });
        });
    }
    var lastKey = keys.length ? keys[keys.length - 1] : today;
    return { kind: kind, title: title, keys: keys, buckets: buckets, canForward: kind !== "all" && lastKey < today };
}

// Totals and rankings over a list of day keys.
function summarize(history, keys) {
    var apps = {}, domains = {}, countries = {}, ifaces = {};
    var total = { "in": 0, out: 0, conns: 0, days: 0 };
    keys.forEach(function (key) {
        var d = history.days[key];
        if (!d)
            return;
        total.days++;
        total["in"] += d["in"];
        total.out += d.out;
        for (var a in d.apps) {
            var x = apps[a] || (apps[a] = { key: a, name: d.apps[a].name, icon: d.apps[a].icon, "in": 0, out: 0, conns: 0 });
            x["in"] += d.apps[a]["in"];
            x.out += d.apps[a].out;
            x.conns += d.apps[a].conns;
            total.conns += d.apps[a].conns;
        }
        var add = function (map, src) {
            for (var k in src) {
                var y = map[k] || (map[k] = { key: k, "in": 0, out: 0, conns: 0 });
                y["in"] += src[k][0];
                y.out += src[k][1];
                y.conns += src[k][2] || 0;
            }
        };
        add(domains, d.domains);
        add(countries, d.countries);
        add(ifaces, d.ifaces || {});
    });
    var ranked = function (map) {
        return Object.keys(map).map(function (k) { return map[k]; }).sort(function (a, b) { return (b["in"] + b.out) - (a["in"] + a.out); });
    };
    return { total: total, apps: ranked(apps), domains: ranked(domains), countries: ranked(countries), ifaces: ranked(ifaces), recorded: Object.keys(history.days).length };
}

// The last `count` days up to `now` (oldest first) with the rankings over
// them; kept for the pill and tests. count 1 = today, with hourly buckets.
function summary(history, now, count) {
    var keys = [];
    for (var k = count - 1; k >= 0; k--)
        keys.push(dayKeyAdd(now, -k));
    var s = summarize(history, keys);
    var today = history.days[dayKey(now)];
    s.days = keys.map(function (key) { var d = history.days[key]; return { day: key, "in": d ? d["in"] : 0, out: d ? d.out : 0 }; });
    s.hours = today && today.hours ? today.hours : blankHours();
    return s;
}
