.pragma library
.import "../Probes.js" as Probes
.import "BrowserTabs.mjs" as BrowserTabs

// The network window's session: connections tracked across polls (live
// rates from byte counters, ended ones kept greyed), grouped into apps,
// filtered, sorted and summed. Plain objects in and out, so the tests and
// the demo data use exactly what the window uses.

var MAX_ENDED = 400;

function connectionKey(c) {
    return c.proto + " " + c.local.ip + ":" + c.local.port + " " + c.remote.ip + ":" + c.remote.port;
}

// One poll into the session. `prev` is the last result (or null); `ctx`
// carries { tree, index, ports } for app identity and direction.
// → { time, entries: { key: conn }, list: [conn] } with conn =
// { key, proto, state, localIp, localPort, ip, port, scope, kind, direction,
//   pid, proc, app { key, name, icon, pid }, bytesIn, bytesOut, rateIn,
//   rateOut, deltaIn, deltaOut (bytes since the last poll), isNew, rtt,
//   cwnd, since, ended, endedAt }
// ctx.maxEnded limits the ended connections kept (the background history
// poll keeps none).
function track(prev, sockets, now, ctx) {
    ctx = ctx || {};
    var old = prev ? prev.entries : {};
    var dt = prev && now > prev.time ? (now - prev.time) / 1000 : 0;
    var entries = {}, list = [];
    (sockets || []).forEach(function (s) {
        var key = connectionKey(s);
        if (entries[key])
            return;
        var was = old[key];
        var bytesIn = s.bytesReceived, bytesOut = s.bytesSent;
        var delta = function (now, before) {
            return now !== null && before !== null && before !== undefined && now >= before ? now - before : 0;
        };
        var live = was && !was.ended;
        var dIn = live ? delta(bytesIn, was.bytesIn) : bytesIn || 0;
        var dOut = live ? delta(bytesOut, was.bytesOut) : bytesOut || 0;
        var c = {
            key: key,
            proto: s.proto,
            state: s.state,
            localIp: s.local.ip,
            localPort: s.local.port,
            ip: s.remote.ip,
            port: s.remote.port,
            scope: s.remote.scope || s.local.scope,
            // The interface (or tunnel) whose address the connection uses.
            via: ctx.ifaceOf ? ctx.ifaceOf(s.local.ip) : "",
            kind: Probes.addressKind(s.remote.ip),
            direction: Probes.direction(s, ctx.ports),
            pid: s.pid,
            proc: s.name,
            app: ctx.appOf ? ctx.appOf(s.pid, s.name) : Probes.appFor(s.pid, s.name, ctx.tree, ctx.index),
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            rateIn: live && dt > 0 ? dIn / dt : 0,
            rateOut: live && dt > 0 ? dOut / dt : 0,
            // A connection seen for the first time brings everything it
            // moved so far; only once, and not on the session's first poll.
            deltaIn: prev ? dIn : 0,
            deltaOut: prev ? dOut : 0,
            isNew: !live,
            rtt: s.rtt,
            cwnd: s.cwnd,
            since: was && !was.ended ? was.since : now,
            ended: false,
            endedAt: 0
        };
        entries[key] = c;
        list.push(c);
    });
    // Connections that closed stay listed, greyed, for the session.
    var ended = [];
    for (var key in old) {
        if (entries[key])
            continue;
        var o = old[key];
        ended.push(o.ended ? o : Object.assign({}, o, { ended: true, endedAt: now, rateIn: 0, rateOut: 0, deltaIn: 0, deltaOut: 0, isNew: false, state: "CLOSED" }));
    }
    ended.sort(function (a, b) { return b.endedAt - a.endedAt; });
    ended.slice(0, ctx.maxEnded === undefined ? MAX_ENDED : ctx.maxEnded).forEach(function (c) {
        entries[c.key] = c;
        list.push(c);
    });
    return { time: now, entries: entries, list: list };
}

// Resolved names and places, merged in when they arrive. `sites` maps an
// address to the browser tabs it serves (BrowserTabs.siteIndex); a browser
// connection to one of them names the site.
function describe(c, hosts, sites) {
    var h = hosts && hosts[c.ip];
    var tabs = sites && sites[c.ip] && BrowserTabs.isBrowser(c) ? sites[c.ip] : null;
    var host = h ? h.name : "";
    return {
        host: host,
        domain: tabs ? Probes.baseDomain(tabs[0].host) : host ? Probes.baseDomain(host) : "",
        site: tabs ? tabs[0].host : "",
        siteTitle: tabs ? tabs[0].title : "",
        siteMore: tabs ? tabs.length - 1 : 0,
        country: h ? h.country : "",
        asn: h ? h.asn : 0,
        org: h ? h.org : ""
    };
}

// Connections → apps, busiest first.
// [{ key, name, icon, pids [], active, ended, rateIn, rateOut, bytesIn, bytesOut, conns [] }]
function apps(list) {
    var byKey = {}, out = [];
    (list || []).forEach(function (c) {
        var a = byKey[c.app.key];
        if (!a) {
            a = byKey[c.app.key] = { key: c.app.key, name: c.app.name, icon: c.app.icon, pid: c.app.pid, pids: [], active: 0, ended: 0, rateIn: 0, rateOut: 0, bytesIn: 0, bytesOut: 0, conns: [] };
            out.push(a);
        }
        if (c.pid && a.pids.indexOf(c.pid) === -1)
            a.pids.push(c.pid);
        if (c.ended)
            a.ended++;
        else
            a.active++;
        a.rateIn += c.rateIn;
        a.rateOut += c.rateOut;
        a.bytesIn += c.bytesIn || 0;
        a.bytesOut += c.bytesOut || 0;
        a.conns.push(c);
    });
    out.sort(function (a, b) {
        return (b.active > 0) - (a.active > 0) || (b.rateIn + b.rateOut) - (a.rateIn + a.rateOut) || b.active - a.active || (a.name < b.name ? -1 : 1);
    });
    return out;
}

// f: { query, app, proto, direction, scope ("local" | "internet"), country, ended (bool) }
function filter(list, f, hosts, sites) {
    f = f || {};
    var q = String(f.query || "").trim().toLowerCase();
    return (list || []).filter(function (c) {
        if (f.ended === false && c.ended)
            return false;
        if (f.app && c.app.key !== f.app)
            return false;
        if (f.proto && c.proto !== f.proto)
            return false;
        if (f.direction && c.direction !== f.direction)
            return false;
        if (f.scope === "internet" && c.kind !== "internet")
            return false;
        if (f.scope === "local" && c.kind === "internet")
            return false;
        var d = describe(c, hosts, sites);
        if (f.country && d.country !== f.country)
            return false;
        if (!q)
            return true;
        return [c.app.name, c.proc, c.ip, c.port, c.localPort, c.proto, c.state, d.host, d.site, d.siteTitle, d.country, d.org, Probes.ADDRESS_LABELS[c.kind]].some(function (v) {
            return String(v || "").toLowerCase().indexOf(q) !== -1;
        });
    });
}

// Sort by a column of the Connections table.
function sorted(list, column, descending, hosts, sites) {
    var val = function (c) {
        switch (column) {
        case "app": return c.app.name.toLowerCase();
        case "domain": var d = describe(c, hosts, sites); return (d.site || d.host || "~" + c.ip).toLowerCase();
        case "ip": return c.ip;
        case "port": return Number(c.port) || 0;
        case "proto": return c.proto;
        case "direction": return c.direction;
        case "state": return c.state;
        case "country": return describe(c, hosts, sites).country || "~";
        case "bytes": return (c.bytesIn || 0) + (c.bytesOut || 0);
        case "rate": return c.rateIn + c.rateOut;
        case "since": return c.since;
        case "rtt": return c.rtt === null || c.rtt === undefined ? 1e9 : c.rtt;
        case "via": return c.via || "~";
        }
        return 0;
    };
    var sign = descending ? -1 : 1;
    return (list || []).slice().sort(function (a, b) {
        if (a.ended !== b.ended)
            return a.ended ? 1 : -1;
        var x = val(a), y = val(b);
        return x < y ? -sign : x > y ? sign : 0;
    });
}

// The Overview page: counts and the top five apps, countries and domains
// by traffic this session (rate breaks ties while bytes are still zero).
function overview(list, hosts, sites) {
    var active = (list || []).filter(function (c) { return !c.ended; });
    var appList = apps(active);
    var top = function (keyOf) {
        var sums = {}, out = [];
        active.forEach(function (c) {
            var k = keyOf(c);
            if (!k)
                return;
            var s = sums[k];
            if (!s) {
                s = sums[k] = { key: k, bytes: 0, rate: 0, count: 0 };
                out.push(s);
            }
            s.bytes += (c.bytesIn || 0) + (c.bytesOut || 0);
            s.rate += c.rateIn + c.rateOut;
            s.count++;
        });
        out.sort(function (a, b) { return b.rate - a.rate || b.bytes - a.bytes || b.count - a.count; });
        return out.slice(0, 5);
    };
    return {
        active: active.length,
        ended: (list || []).length - active.length,
        internet: active.filter(function (c) { return c.kind === "internet"; }).length,
        apps: appList.length,
        topApps: appList.slice(0, 5),
        topCountries: top(function (c) { return describe(c, hosts).country; }),
        topDomains: top(function (c) { return describe(c, hosts, sites).domain || (c.kind === "internet" ? "" : Probes.ADDRESS_LABELS[c.kind]); })
    };
}

// Total rates from /proc/net/dev between two polls, summed over the
// physical links (VPN and bridge traffic also crosses one of them).
function totalRates(prev, next, dt, interfaces) {
    var kinds = {};
    (interfaces || []).forEach(function (i) { kinds[i.name] = i.kind; });
    var physical = Object.keys(next).filter(function (n) { return kinds[n] === "wifi" || kinds[n] === "ethernet"; });
    var names = physical.length ? physical : Object.keys(next).filter(function (n) { return kinds[n] !== "virtual" && kinds[n] !== "bridge"; });
    var out = { rx: 0, tx: 0, perIface: {}, perIfaceBytes: {} };
    Object.keys(next).forEach(function (n) {
        var a = prev && prev[n], b = next[n];
        var r = { rx: a && dt > 0 && b.rx >= a.rx ? (b.rx - a.rx) / dt : 0, tx: a && dt > 0 && b.tx >= a.tx ? (b.tx - a.tx) / dt : 0 };
        out.perIface[n] = r;
        out.perIfaceBytes[n] = { "in": r.rx * dt, out: r.tx * dt };
        if (names.indexOf(n) !== -1) {
            out.rx += r.rx;
            out.tx += r.tx;
        }
    });
    out.inBytes = out.rx * dt;
    out.outBytes = out.tx * dt;
    return out;
}

// The Listening page, one group per app, open-to-network ones first. A
// port a container publishes (docker-proxy, rootlessport, pasta) groups
// under the container.
function listeningByApp(rows, tree, index, containers) {
    var byKey = {}, out = [];
    (rows || []).forEach(function (r) {
        var owner = containers ? Probes.containerForPort(containers, r.proto, r.port) : null;
        if (owner)
            r = Object.assign({}, r, { container: owner.container.name, containerPort: owner.containerPort });
        var app = owner ? { key: "container:" + owner.container.engine + ":" + owner.container.name, name: owner.container.name + " · " + (owner.container.engine === "docker" ? "Docker" : "Podman"), icon: owner.container.engine, pid: 0 }
            : Probes.appFor(r.pid, r.name, tree, index);
        var g = byKey[app.key];
        if (!g) {
            g = byKey[app.key] = { key: app.key, name: app.name, icon: app.icon, pid: app.pid, open: 0, rows: [] };
            out.push(g);
        }
        if (r.exposure === "network")
            g.open++;
        g.rows.push(r);
    });
    out.sort(function (a, b) { return (b.open > 0) - (a.open > 0) || (a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1); });
    return out;
}

// One poll for NetHistory.record: what each connection moved since the last.
function historySample(list, now, totals, hosts, sites) {
    var conns = [];
    (list || []).forEach(function (c) {
        if (c.ended || (!c.deltaIn && !c.deltaOut && !c.isNew))
            return;
        var d = describe(c, hosts, sites);
        conns.push({
            app: c.app,
            domain: d.domain || (c.kind === "internet" ? c.ip : Probes.ADDRESS_LABELS[c.kind]),
            country: d.country,
            deltaIn: c.deltaIn,
            deltaOut: c.deltaOut,
            isNew: c.isNew
        });
    });
    return { time: now, totalIn: totals.inBytes, totalOut: totals.outBytes, ifaces: totals.perIfaceBytes || {}, conns: conns };
}

// "3 s", "4 min", "2 h 5 min"
function duration(ms) {
    var s = Math.max(0, Math.round(ms / 1000));
    if (s < 60)
        return s + " s";
    if (s < 3600)
        return Math.floor(s / 60) + " min";
    return Math.floor(s / 3600) + " h " + Math.floor(s % 3600 / 60) + " min";
}

// Web pages for one address, opened only on click.
function whoisUrl(ip) {
    return "https://bgp.he.net/ip/" + encodeURIComponent(ip);
}
function mapUrl(ip) {
    return "https://ipinfo.io/" + encodeURIComponent(ip);
}

// ── Export ───────────────────────────────────────────────────────────────────
function csvCell(v) {
    var s = v === null || v === undefined ? "" : String(v);
    return /[",\n;]/.test(s) ? "\"" + s.replace(/"/g, "\"\"") + "\"" : s;
}
function csv(rows) {
    return rows.map(function (r) { return r.map(csvCell).join(","); }).join("\n") + "\n";
}
function connectionsCsv(list, hosts, sites) {
    var rows = [["app", "process", "pid", "protocol", "direction", "state", "local", "remote_ip", "remote_port", "site", "host", "country", "asn", "owner", "via", "bytes_in", "bytes_out", "rtt_ms", "since", "ended"]];
    (list || []).forEach(function (c) {
        var d = describe(c, hosts, sites);
        rows.push([c.app.name, c.proc, c.pid || "", c.proto, c.direction, c.state, c.localIp + ":" + c.localPort, c.ip, c.port, d.site, d.host, d.country, d.asn || "", d.org, c.via || "",
            c.bytesIn === null ? "" : c.bytesIn, c.bytesOut === null ? "" : c.bytesOut, c.rtt === null ? "" : c.rtt, new Date(c.since).toISOString(), c.ended ? new Date(c.endedAt).toISOString() : ""]);
    });
    return csv(rows);
}
// One row per day and app (plus a "(total)" row per day).
function historyCsv(history) {
    var rows = [["day", "app", "bytes_in", "bytes_out", "connections"]];
    Object.keys(history.days).sort().forEach(function (k) {
        var d = history.days[k];
        rows.push([k, "(total)", d["in"], d.out, ""]);
        Object.keys(d.apps).forEach(function (a) { rows.push([k, d.apps[a].name, d.apps[a]["in"], d.apps[a].out, d.apps[a].conns]); });
    });
    return csv(rows);
}
