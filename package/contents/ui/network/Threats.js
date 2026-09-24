.pragma library
.import "../Probes.js" as Probes

// The Threats page: what looks dangerous among this machine's connections,
// listening ports and the programs behind them. Two sources:
//   • checks on this machine (always, nothing leaves it): programs running
//     from a temporary folder or a deleted file, mining pools, backdoor and
//     IRC ports, unencrypted logins, ports open to the network;
//   • public blocklists (opt-in, off by default): downloaded by curl/wget
//     into ~/.local/share/glassy-system-monitor/threats, once a day while
//     switched on. Only the lists come down; no address is ever sent out.
// Hints, not verdicts: an address on a list can be a shared or reused one.

var LEVELS = ["high", "medium", "low", "info"];
var LEVEL_LABELS = { high: "High", medium: "Medium", low: "Low", info: "Info" };

// Free lists that need no account. `kind` ip: addresses and CIDR ranges
// (IPv4 and IPv6); domain: host names. `on`: part of the default set.
var LISTS = [
    { id: "feodo", name: "Feodo Tracker", by: "abuse.ch", kind: "ip", level: "high", on: true,
      what: "Botnet command server", urls: ["https://feodotracker.abuse.ch/downloads/ipblocklist.txt"] },
    { id: "urlhaus", name: "URLhaus", by: "abuse.ch", kind: "domain", level: "high", on: true,
      what: "Site that spreads malware", urls: ["https://urlhaus.abuse.ch/downloads/hostfile/"] },
    { id: "spamhaus", name: "Spamhaus DROP", by: "Spamhaus", kind: "ip", level: "high", on: true,
      what: "Network run by criminals or hijacked", urls: ["https://www.spamhaus.org/drop/drop_v4.json", "https://www.spamhaus.org/drop/drop_v6.json"] },
    { id: "et", name: "Compromised hosts", by: "Emerging Threats", kind: "ip", level: "medium", on: true,
      what: "Known compromised host", urls: ["https://rules.emergingthreats.net/blockrules/compromised-ips.txt"] },
    { id: "ipsum", name: "IPsum (level 3)", by: "stamparm", kind: "ip", level: "medium", on: true,
      what: "On 3 or more blocklists", urls: ["https://raw.githubusercontent.com/stamparm/ipsum/master/levels/3.txt"] },
    { id: "tor", name: "Tor exit nodes", by: "Tor Project", kind: "ip", level: "info", on: false,
      what: "Tor exit node", urls: ["https://check.torproject.org/torbulkexitlist"] }
];

function list(id) {
    for (var i = 0; i < LISTS.length; i++)
        if (LISTS[i].id === id)
            return LISTS[i];
    return null;
}

// The lists in use: the defaults, changed by the user's { id: bool }.
function enabledIds(choice) {
    choice = choice || {};
    return LISTS.filter(function (l) { return choice[l.id] === undefined ? l.on : !!choice[l.id]; }).map(function (l) { return l.id; });
}

// ── Shell ────────────────────────────────────────────────────────────────────
function dirOf(storeDir) {
    return storeDir + "/threats";
}

// Downloads the given lists. Each is reduced to one address, range or host
// per line before it replaces the old file, and only when it is not empty,
// so a failed or half download keeps yesterday's list. Prints
// "<id> ok <count>" or "<id> failed" per list.
function downloadCmd(storeDir, ids) {
    var ip4 = "([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?";
    var ip6 = "[0-9a-fA-F]{0,4}(:[0-9a-fA-F]{0,4}){2,7}(/[0-9]{1,3})?";
    var sh = "umask 077; D=\"" + dirOf(storeDir) + "\"; mkdir -p \"$D\" || exit 1; "
        + "get() { if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 60 -A glassy-system-monitor -o \"$2\" \"$1\"; "
        + "elif command -v wget >/dev/null 2>&1; then wget -q -T 60 -O \"$2\" \"$1\"; else return 9; fi; }; ";
    (ids || []).forEach(function (id) {
        var l = list(id);
        if (!l)
            return;
        var pick = l.kind === "domain"
            ? "tr -d '\\r' | awk '!/^#/ && NF >= 2 { print tolower($2) } NF == 1 && !/^#/ { print tolower($1) }' | grep -E '^[a-z0-9._-]+\\.[a-z0-9-]+$'"
            : "grep -v '^[#;]' | grep -oE '" + ip4 + "|" + ip6 + "'";
        sh += "rm -f \"$D/." + id + "\"; ok=1; "
            + l.urls.map(function (u) { return "get '" + u + "' \"$D/." + id + ".raw\" && { " + pick + "; } < \"$D/." + id + ".raw\" >> \"$D/." + id + "\" || ok=0; "; }).join("")
            + "rm -f \"$D/." + id + ".raw\"; "
            + "if [ $ok = 1 ] && [ -s \"$D/." + id + "\" ]; then sort -u \"$D/." + id + "\" > \"$D/" + id + ".txt\"; echo \"" + id + " ok $(wc -l < \"$D/" + id + ".txt\")\"; "
            + "else echo \"" + id + " failed\"; fi; rm -f \"$D/." + id + "\"; ";
    });
    return sh;
}

// Reads the downloaded lists: "@@<id> <mtime>" and the list's lines.
function loadCmd(storeDir, ids) {
    return "D=\"" + dirOf(storeDir) + "\"; for id in " + (ids || []).filter(function (id) { return /^[a-z0-9]+$/.test(id); }).join(" ")
        + "; do f=\"$D/$id.txt\"; [ -r \"$f\" ] || continue; echo \"@@$id $(stat -c %Y \"$f\")\"; cat \"$f\"; done";
}

// Switching the lists off removes every downloaded one.
function removeCmd(storeDir) {
    return "rm -rf \"" + dirOf(storeDir) + "\"";
}

// { id: { time (ms), lines [] } }
function parseLoad(text) {
    var out = {}, cur = null;
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@([a-z0-9]+) (\d+)\s*$/.exec(line);
        if (m) {
            cur = out[m[1]] = { time: Number(m[2]) * 1000, lines: [] };
            return;
        }
        var t = line.trim();
        if (cur && t)
            cur.lines.push(t);
    });
    return out;
}

// "<id> ok <n>" / "<id> failed" → { ok: [ids], failed: [ids] }
function parseDownload(text) {
    var out = { ok: [], failed: [] };
    String(text || "").split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f.length >= 2 && list(f[0]))
            (f[1] === "ok" ? out.ok : out.failed).push(f[0]);
    });
    return out;
}

// ── Addresses ────────────────────────────────────────────────────────────────
function ip4Number(ip) {
    var p = Probes.ipv4Parts(ip);
    if (!p || p.some(function (n) { return n > 255; }))
        return -1;
    return ((p[0] * 256 + p[1]) * 256 + p[2]) * 256 + p[3];
}

// An IPv6 address as 32 hex digits, "" when it is not one.
function expand6(ip) {
    var s = String(ip || "").toLowerCase();
    if (s.indexOf(":") < 0 || /[^0-9a-f:]/.test(s))
        return "";
    var halves = s.split("::");
    if (halves.length > 2)
        return "";
    var head = halves[0] ? halves[0].split(":") : [], tail = halves.length > 1 && halves[1] ? halves[1].split(":") : [];
    var fill = 8 - head.length - tail.length;
    if (fill < 0 || (halves.length === 1 && fill !== 0))
        return "";
    var groups = head.concat(new Array(fill + 1).join("0,").split(",").slice(0, fill), tail);
    if (groups.some(function (g) { return g.length > 4; }))
        return "";
    return groups.map(function (g) { return ("0000" + g).slice(-4); }).join("");
}

function hexBits(hex, bits) {
    var out = "";
    for (var i = 0; i < Math.ceil(bits / 4); i++)
        out += ("000" + parseInt(hex.charAt(i), 16).toString(2)).slice(-4);
    return out.slice(0, bits);
}

// Lists' lines → { id: { v4: { starts, ends }, v6: [{ bits, prefix }],
// domains: {}, count, time } }. IPv4 ranges are sorted and merged for a
// binary search; the few IPv6 ranges are scanned.
function buildIndex(loaded) {
    var index = {};
    for (var id in loaded) {
        var l = list(id);
        if (!l)
            continue;
        var entry = { v4: { starts: [], ends: [] }, v6: [], domains: {}, count: 0, time: loaded[id].time };
        var ranges = [];
        loaded[id].lines.forEach(function (line) {
            if (l.kind === "domain") {
                entry.domains[line.toLowerCase()] = true;
                entry.count++;
                return;
            }
            var slash = line.indexOf("/"), addr = slash < 0 ? line : line.slice(0, slash);
            var n = ip4Number(addr);
            if (n >= 0) {
                var bits = slash < 0 ? 32 : Number(line.slice(slash + 1));
                if (!(bits >= 0 && bits <= 32))
                    return;
                var size = Math.pow(2, 32 - bits), start = Math.floor(n / size) * size;
                ranges.push([start, start + size - 1]);
                entry.count++;
                return;
            }
            var hex = expand6(addr);
            if (hex) {
                var b6 = slash < 0 ? 128 : Number(line.slice(slash + 1));
                if (b6 >= 0 && b6 <= 128) {
                    entry.v6.push({ bits: b6, prefix: hexBits(hex, b6) });
                    entry.count++;
                }
            }
        });
        ranges.sort(function (a, b) { return a[0] - b[0]; });
        ranges.forEach(function (r) {
            var n = entry.v4.ends.length;
            if (n && r[0] <= entry.v4.ends[n - 1] + 1)
                entry.v4.ends[n - 1] = Math.max(entry.v4.ends[n - 1], r[1]);
            else {
                entry.v4.starts.push(r[0]);
                entry.v4.ends.push(r[1]);
            }
        });
        index[id] = entry;
    }
    return index;
}

function inV4(v4, n) {
    var lo = 0, hi = v4.starts.length - 1;
    while (lo <= hi) {
        var mid = (lo + hi) >> 1;
        if (v4.starts[mid] > n)
            hi = mid - 1;
        else if (v4.ends[mid] < n)
            lo = mid + 1;
        else
            return true;
    }
    return false;
}

// The lists an address (or one of the host names) is on: [list ids].
function lookup(index, ip, names) {
    var out = [];
    var mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip || "");
    var n = ip4Number(mapped ? mapped[1] : ip);
    var hex = n < 0 ? expand6(ip) : "";
    var bits = hex ? hexBits(hex, 128) : "";
    var hosts = (names || []).filter(Boolean).map(function (h) { return String(h).toLowerCase().replace(/\.$/, ""); });
    for (var id in index) {
        var e = index[id], hit = false;
        if (n >= 0)
            hit = inV4(e.v4, n);
        else if (bits)
            hit = e.v6.some(function (r) { return bits.indexOf(r.prefix) === 0; });
        // A host or any domain above it (a.b.evil.com → evil.com).
        for (var k = 0; !hit && k < hosts.length; k++) {
            var parts = hosts[k].split(".");
            for (var j = 0; !hit && j < parts.length - 1; j++)
                hit = !!e.domains[parts.slice(j).join(".")];
        }
        if (hit)
            out.push(id);
    }
    return out;
}

// ── Checks on this machine ───────────────────────────────────────────────────
// Ports malware favours, and ports of mining pools (stratum).
var BACKDOOR_PORTS = { 1337: true, 4444: true, 5554: true, 6666: true, 12345: true, 31337: true };
var IRC_PORTS = { 6660: true, 6661: true, 6662: true, 6663: true, 6664: true, 6665: true, 6667: true, 6668: true, 6669: true, 6697: true, 7000: true };
var MINING_PORTS = { 3333: true, 3334: true, 4545: true, 5730: true, 7777: true, 14433: true, 14444: true, 45560: true, 45700: true };
var MINING_HOST = /(^|[.-])(pool|xmr|monero|moneroocean|nanopool|2miners|f2pool|minexmr|hashvault|supportxmr|nicehash|ethermine|herominers|c3pool|unmineable|kryptex)([.-]|\d|$)/;
var TOR_PORTS = { 9001: true, 9030: true };
var PLAIN_LOGIN = { 21: "FTP", 23: "Telnet", 110: "POP3", 143: "IMAP", 512: "rexec", 513: "rlogin" };

// `readlink /proc/PID/exe` for the given processes: "pid<TAB>path".
function exeCmd(pids) {
    var list = (pids || []).map(Number).filter(function (p) { return p > 0 && Math.floor(p) === p; });
    if (!list.length)
        return "";
    return "for p in " + list.join(" ") + "; do printf '%s\\t%s\\n' \"$p\" \"$(readlink /proc/$p/exe 2>/dev/null)\"; done";
}

function parseExe(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var t = line.indexOf("\t");
        if (t > 0)
            out[line.slice(0, t)] = line.slice(t + 1).trim();
    });
    return out;
}

// What a program's path says about it: "" (nothing), "temp" or "deleted".
function exeVerdict(path) {
    var p = String(path || "");
    if (!p)
        return "";
    // AppImages mount under /tmp/.mount_*: they run from there by design.
    if (/^\/(tmp|var\/tmp|dev\/shm)\//.test(p) && !/^\/tmp\/\.mount_/.test(p))
        return "temp";
    if (/ \(deleted\)$/.test(p))
        return "deleted";
    return "";
}

// Everything worth a look, the most serious first.
// ctx: { conns, listening, exes { pid: path }, index, lookup (a cached
//        lookup(index, …), optional), firewall,
//        trusted { appKey }, describe(conn) → { host, site, country, org },
//        appOf(pid, name) → { key, name, icon, pid } }
// → [{ key, level, kind, title, detail, app, conn, pid, lists [], count }]
function findings(ctx) {
    var out = [], byKey = {};
    var add = function (f) {
        var had = byKey[f.key];
        if (had) {
            had.count++;
            if (!had.conn || (had.conn.ended && f.conn && !f.conn.ended))
                had.conn = f.conn;
            return;
        }
        f.count = 1;
        byKey[f.key] = f;
        out.push(f);
    };
    var trusted = ctx.trusted || {};
    var seenPids = {};
    (ctx.conns || []).forEach(function (c) {
        if (c.kind !== "internet")
            return;
        var d = ctx.describe ? ctx.describe(c) : { host: "", site: "", country: "", org: "" };
        var where = (d.site || d.host || c.ip) + ":" + c.port + (d.country ? " · " + d.country : "") + (d.org ? " · " + d.org : "");
        var mine = trusted[c.app.key];
        var lists = !ctx.index ? [] : ctx.lookup ? ctx.lookup(c.ip, [d.host, d.site]) : lookup(ctx.index, c.ip, [d.host, d.site]);
        if (lists.length) {
            var worst = lists.map(list).sort(function (a, b) { return LEVELS.indexOf(a.level) - LEVELS.indexOf(b.level); })[0];
            add({ key: "list:" + c.app.key + ":" + c.ip, level: worst.level, kind: "listed", title: worst.what, detail: c.app.name + " → " + where,
                  app: c.app, conn: c, pid: c.pid, lists: lists });
        }
        if (mine)
            return;
        var port = Number(c.port);
        var host = String(d.host || d.site || "").toLowerCase();
        if (MINING_HOST.test(host))
            add({ key: "mining:" + c.app.key, level: "high", kind: "mining", title: "Talks to a crypto-mining pool", detail: c.app.name + " → " + where, app: c.app, conn: c, pid: c.pid, lists: [] });
        else if (MINING_PORTS[port] && c.direction !== "in")
            add({ key: "miningport:" + c.app.key + ":" + port, level: "medium", kind: "mining", title: "Uses a port of mining pools (" + port + ")", detail: c.app.name + " → " + where, app: c.app, conn: c, pid: c.pid, lists: [] });
        if (BACKDOOR_PORTS[port] && c.direction !== "in")
            add({ key: "backdoor:" + c.app.key + ":" + port, level: "medium", kind: "port", title: "Port used by backdoors (" + port + ")", detail: c.app.name + " → " + where, app: c.app, conn: c, pid: c.pid, lists: [] });
        if (IRC_PORTS[port] && c.direction !== "in")
            add({ key: "irc:" + c.app.key, level: "low", kind: "port", title: "IRC connection", detail: c.app.name + " → " + where + ". Fine for a chat app; botnets use IRC too.", app: c.app, conn: c, pid: c.pid, lists: [] });
        if (PLAIN_LOGIN[port] && c.direction !== "in")
            add({ key: "plain:" + c.app.key + ":" + port, level: "medium", kind: "plain", title: PLAIN_LOGIN[port] + " without encryption", detail: c.app.name + " → " + where + ". Passwords go over the network readable.", app: c.app, conn: c, pid: c.pid, lists: [] });
        else if (port === 80 && c.direction !== "in")
            add({ key: "http:" + c.app.key, level: "info", kind: "plain", title: "Unencrypted web (HTTP)", detail: c.app.name + " → " + where, app: c.app, conn: c, pid: c.pid, lists: [] });
        if (TOR_PORTS[port] && c.direction !== "in")
            add({ key: "tor:" + c.app.key, level: "info", kind: "tor", title: "Looks like Tor", detail: c.app.name + " → " + where, app: c.app, conn: c, pid: c.pid, lists: [] });
    });
    // The programs behind sockets: where they run from.
    var procs = [];
    (ctx.conns || []).forEach(function (c) { if (c.pid && !c.ended) procs.push({ pid: c.pid, app: c.app, conn: c }); });
    (ctx.listening || []).forEach(function (l) { if (l.pid) procs.push({ pid: l.pid, app: ctx.appOf ? ctx.appOf(l.pid, l.name) : { key: "proc:" + l.name, name: l.name, icon: "", pid: l.pid }, conn: null }); });
    procs.forEach(function (p) {
        if (seenPids[p.pid])
            return;
        seenPids[p.pid] = true;
        var path = ctx.exes ? ctx.exes[p.pid] : "";
        var v = exeVerdict(path);
        if (trusted[p.app.key])
            return;
        if (v === "temp")
            add({ key: "temp:" + p.pid, level: "high", kind: "exe", title: "Runs from a temporary folder", detail: p.app.name + " (PID " + p.pid + ") · " + path, app: p.app, conn: p.conn, pid: p.pid, lists: [] });
        else if (v === "deleted")
            add({ key: "deleted:" + p.pid, level: "low", kind: "exe", title: "Runs from a deleted file", detail: p.app.name + " (PID " + p.pid + ") · " + path.replace(/ \(deleted\)$/, "") + ". Normal after an update until the app restarts; malware does it to hide.", app: p.app, conn: p.conn, pid: p.pid, lists: [] });
    });
    // Ports other machines can reach, unless a firewall is known to block them.
    (ctx.listening || []).forEach(function (l) {
        if (l.exposure !== "network")
            return;
        // Not read yet: unknown, not "no firewall".
        var verdict = ctx.firewall ? Probes.firewallVerdict(ctx.firewall, l.proto, l.port) : "";
        if (verdict === "blocked")
            return;
        var app = ctx.appOf ? ctx.appOf(l.pid, l.name) : { key: "?", name: l.name || "A system service", icon: "", pid: l.pid };
        if (trusted[app.key])
            return;
        add({ key: "open:" + l.proto + ":" + l.port, level: verdict === "allowed" || verdict === "open" ? "low" : "info", kind: "open",
              title: "Port " + l.port + "/" + l.proto + " open to the network", detail: (app.key === "?" ? "A system service" : app.name) + " listens on " + (l.kind === "any" ? "all addresses" : l.ip)
                  + (verdict === "allowed" ? "; the firewall lets it in" : verdict === "open" ? "; no firewall is running" : ""),
              app: app, conn: null, pid: l.pid, lists: [] });
    });
    out.sort(function (a, b) {
        var d = LEVELS.indexOf(a.level) - LEVELS.indexOf(b.level);
        return d !== 0 ? d : (a.conn && a.conn.ended ? 1 : 0) - (b.conn && b.conn.ended ? 1 : 0);
    });
    return out;
}

// { high, medium, low, info } counts.
function counts(list) {
    var out = { high: 0, medium: 0, low: 0, info: 0 };
    (list || []).forEach(function (f) { out[f.level]++; });
    return out;
}
