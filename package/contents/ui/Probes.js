.pragma library

// Shell probes and their parsers for network interfaces, storage and
// processes. Plain text in, plain objects out, so the tests, the demo data
// and the website use the same code as MonitorCore.

// ── Network interfaces ───────────────────────────────────────────────────────
// One `if` line per interface (name, state, kind, MAC, link speed), then its
// IPv4 addresses and the default routes with their metrics.
var INTERFACES_CMD = "for d in /sys/class/net/*; do n=${d##*/}; [ \"$n\" = lo ] && continue; k=other; "
    + "if [ -d $d/wireless ]; then k=wifi; elif [ -e $d/device ]; then k=ethernet; fi; [ -d $d/bridge ] && k=bridge; "
    + "case $n in tun*|wg*|tailscale*|zt*|ppp*|nordlynx*|proton*|mullvad*) k=vpn;; "
    + "docker*|veth*|virbr*|br-*|vnet*|lxc*|lxd*|podman*|cni*|flannel*|vmnet*|vboxnet*) k=virtual;; esac; "
    + "s=$(cat $d/operstate 2>/dev/null); a=$(cat $d/address 2>/dev/null); v=$(cat $d/speed 2>/dev/null); "
    + "echo \"if $n ${s:-unknown} $k ${a:--} ${v:--}\"; done; "
    + "ip -o -4 addr show scope global 2>/dev/null | awk '{print \"ip\", $2, $4}'; "
    + "awk 'NR>1 && $2==\"00000000\" {print \"route\", $1, $7}' /proc/net/route 2>/dev/null";

var KIND_LABELS = { wifi: "Wi-Fi", ethernet: "Ethernet", vpn: "VPN", bridge: "Bridge", virtual: "Virtual", other: "Other" };

// [{ name, kind, up, mac, speed (Mbit/s, 0 unknown), ip, route (metric or -1) }]
function parseInterfaces(text) {
    var byName = {}, list = [];
    String(text || "").split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f[0] === "if" && f.length >= 4) {
            var speed = parseInt(f[5]);
            var entry = {
                name: f[1],
                // Tunnels report "unknown" while they carry traffic.
                up: f[2] === "up" || (f[2] === "unknown" && f[3] === "vpn"),
                kind: KIND_LABELS[f[3]] ? f[3] : "other",
                mac: f[4] && f[4] !== "-" ? f[4] : "",
                speed: speed > 0 ? speed : 0,
                ip: "",
                route: -1
            };
            byName[entry.name] = entry;
            list.push(entry);
        } else if (f[0] === "ip" && byName[f[1]] && !byName[f[1]].ip) {
            byName[f[1]].ip = String(f[2] || "").split("/")[0];
        } else if (f[0] === "route" && byName[f[1]]) {
            var metric = parseInt(f[2]) || 0;
            var e = byName[f[1]];
            e.route = e.route < 0 ? metric : Math.min(e.route, metric);
        }
    });
    return list;
}

// The interface "Automatic" means: the default route with the lowest metric
// (where the traffic actually goes), else the busiest connected physical
// link, else whatever received the most.
function autoInterface(list, rates, fallback) {
    var best = null;
    list.forEach(function (e) {
        if (e.up && e.route >= 0 && (!best || e.route < best.route))
            best = e;
    });
    if (best)
        return best.name;
    var busiest = null, top = -1;
    list.forEach(function (e) {
        var physical = e.kind === "wifi" || e.kind === "ethernet";
        var r = rates && rates[e.name] ? rates[e.name].rx + rates[e.name].tx : 0;
        if (e.up && physical && r > top) {
            top = r;
            busiest = e;
        }
    });
    return busiest ? busiest.name : (fallback || "");
}

// ── Storage ──────────────────────────────────────────────────────────────────
// Real filesystems only, sizes in bytes.
var STORAGE_CMD = "df -B1 -P -T -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x ramfs -x fuse.portal -x fuse.gvfsd-fuse 2>/dev/null";

// [{ mount, device, fs, size, used, percent }], one row per device (btrfs
// subvolumes and bind mounts share the shortest mount point).
function parseStorage(text, only) {
    var wanted = String(only || "").split(",").map(function (s) { return s.trim(); }).filter(function (s) { return s; });
    var byDevice = {}, list = [];
    String(text || "").split("\n").slice(1).forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f.length < 7)
            return;
        var size = Number(f[2]), used = Number(f[3]), avail = Number(f[4]);
        var mount = f.slice(6).join(" ");
        if (!(size > 0))
            return;
        if (wanted.length ? wanted.indexOf(mount) === -1 : size < 256 * 1024 * 1024)
            return;
        var row = { mount: mount, device: f[0], fs: f[1], size: size, used: used, percent: used + avail > 0 ? used / (used + avail) * 100 : 0 };
        var seen = byDevice[f[0]];
        if (seen) {
            if (mount.length < seen.mount.length)
                list[list.indexOf(seen)] = byDevice[f[0]] = row;
            return;
        }
        byDevice[f[0]] = row;
        list.push(row);
    });
    if (wanted.length)
        list.sort(function (a, b) { return wanted.indexOf(a.mount) - wanted.indexOf(b.mount); });
    else
        list.sort(function (a, b) { return a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount < b.mount ? -1 : 1; });
    return list;
}

// ── Processes ────────────────────────────────────────────────────────────────
// Total CPU time, memory total, then every process's stat line.
var PROCESSES_CMD = "head -1 /proc/stat; grep -m1 MemTotal /proc/meminfo; cat /proc/[0-9]*/stat 2>/dev/null";

// NixOS runs many programs through ".name-wrapped" launchers, which the
// kernel's 15-character comm cuts to ".plasmashell-wr".
function cleanName(comm) {
    return comm.charAt(0) === "." ? comm.slice(1).replace(/-w(r(a(p(p(e(d)?)?)?)?)?)?$/, "") : comm;
}

// Reads one poll: { total (jiffies), memTotal (bytes), procs: { pid: { name, ticks, rss } } }.
function parseProcSnapshot(text) {
    var out = { total: 0, memTotal: 0, procs: {} };
    String(text || "").split("\n").forEach(function (line) {
        if (line.indexOf("cpu ") === 0) {
            out.total = line.trim().split(/\s+/).slice(1, 9).reduce(function (a, v) { return a + (Number(v) || 0); }, 0);
            return;
        }
        if (line.indexOf("MemTotal:") === 0) {
            out.memTotal = (parseInt(line.replace(/\D+/g, " ").trim()) || 0) * 1024;
            return;
        }
        // pid (comm) state …: comm may hold spaces and parentheses.
        var open = line.indexOf("("), close = line.lastIndexOf(")");
        if (open < 0 || close < open)
            return;
        var f = line.slice(close + 2).split(" ");
        // After comm: state=0 … utime=11 stime=12 … rss=21 (pages).
        if (f.length < 22)
            return;
        out.procs[line.slice(0, open).trim()] = {
            name: cleanName(line.slice(open + 1, close)),
            ticks: (Number(f[11]) || 0) + (Number(f[12]) || 0),
            rss: (Number(f[21]) || 0) * 4096
        };
    });
    return out;
}

// Top `count` by `sort` ("cpu" or "memory") between two snapshots. CPU is the
// share of the whole machine, like the CPU section. `group` merges processes
// with the same name (a browser's many helpers become one row).
function topProcesses(prev, next, count, sort, group) {
    var dTotal = prev && next.total > prev.total ? next.total - prev.total : 0;
    var rows = {}, list = [];
    for (var pid in next.procs) {
        var p = next.procs[pid];
        var before = prev && prev.procs[pid];
        var cpu = dTotal > 0 && before && p.ticks >= before.ticks ? (p.ticks - before.ticks) / dTotal * 100 : 0;
        var key = group ? p.name : pid;
        var row = rows[key];
        if (!row) {
            row = rows[key] = { name: p.name, pid: Number(pid), count: 0, cpu: 0, memory: 0 };
            list.push(row);
        }
        row.count++;
        row.cpu += cpu;
        row.memory += p.rss;
    }
    list.forEach(function (r) {
        r.memPercent = next.memTotal > 0 ? r.memory / next.memTotal * 100 : 0;
    });
    list.sort(sort === "memory" ? function (a, b) { return b.memory - a.memory; } : function (a, b) { return b.cpu - a.cpu || b.memory - a.memory; });
    return list.slice(0, Math.max(1, count || 5));
}
