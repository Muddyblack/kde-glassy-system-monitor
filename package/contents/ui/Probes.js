.pragma library

// Shell probes and their parsers for network interfaces, storage and
// processes. Plain text in, plain objects out, so the tests, the demo data
// and the website use the same code as MonitorCore.

// ── Network interfaces ───────────────────────────────────────────────────────
// One `if` line per interface (name, state, kind, MAC, link speed), then its
// IPv4 addresses and the default routes with their metrics.
var INTERFACES_CMD = "for d in /sys/class/net/*; do n=${d##*/}; [ \"$n\" = lo ] && continue; k=other; "
    + "if [ -d $d/wireless ]; then k=wifi; elif [ -e $d/device ]; then k=ethernet; fi; [ -d $d/bridge ] && k=bridge; "
    + "case $n in tun*|tap*|wg*|tailscale*|zt*|ppp*|nordlynx*|proton*|pvpn*|mullvad*|CloudflareWARP*|wt[0-9]*|cscotun*|ipsec*|vti*|nebula*) k=vpn;; "
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
            row = rows[key] = { name: p.name, pid: Number(pid), pids: [], count: 0, cpu: 0, memory: 0 };
            list.push(row);
        }
        row.pids.push(Number(pid));
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

// POSIX single quotes around any string.
function quote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// Ends a process row: SIGTERM, or SIGKILL when `force`. Only whole pids
// above 1 reach the shell; other users' processes simply refuse.
function killCmd(pids, force) {
    var list = (pids || []).map(Number).filter(function (p) { return p > 1 && Math.floor(p) === p; });
    return list.length ? "kill -" + (force ? "KILL" : "TERM") + " " + list.join(" ") + " 2>&1" : "";
}

// ── Load and uptime ──────────────────────────────────────────────────────────
var LOAD_CMD = "cat /proc/loadavg /proc/uptime; nproc 2>/dev/null || getconf _NPROCESSORS_ONLN";

// { load1, load5, load15, running, tasks, uptime (s), cpus }, or null.
function parseLoad(text) {
    var lines = String(text || "").trim().split("\n");
    var l = (lines[0] || "").trim().split(/\s+/);
    if (l.length < 4 || isNaN(Number(l[0])))
        return null;
    var tasks = l[3].split("/");
    return {
        load1: Number(l[0]) || 0,
        load5: Number(l[1]) || 0,
        load15: Number(l[2]) || 0,
        // The reading itself is one of the running tasks.
        running: Math.max(0, (parseInt(tasks[0]) || 1) - 1),
        tasks: parseInt(tasks[1]) || 0,
        uptime: parseFloat(String(lines[1] || "").split(" ")[0]) || 0,
        cpus: Math.max(1, parseInt(lines[2]) || 1)
    };
}

// ── Sensor chips and fans (lm-sensors JSON) ──────────────────────────────────
function chipName(n) {
    var s = String(n).toLowerCase();
    var names = [["coretemp", "CPU (Intel)"], ["k10temp", "CPU (AMD)"], ["zenpower", "CPU (AMD Zen)"], ["k8temp", "CPU (AMD K8)"], ["nvme", "NVMe SSD"],
        ["amdgpu", "GPU (AMD)"], ["nouveau", "GPU (Nouveau)"], ["radeon", "GPU (Radeon)"], ["i915", "GPU (Intel)"], ["acpitz", "ACPI Thermal"],
        ["iwlwifi", "Wi-Fi"], ["drivetemp", "Drive"], ["hddtemp", "HDD"], ["ucsi", "USB-PD"], ["thinkpad", "ThinkPad"], ["dell_smm", "Dell"],
        ["asus", "ASUS"], ["applesmc", "Apple SMC"], ["nct", "Motherboard"], ["it8", "Motherboard"], ["w83", "Motherboard"], ["f71", "Motherboard"], ["nuvoton", "Motherboard"]];
    for (var i = 0; i < names.length; i++)
        if (s.indexOf(names[i][0]) === 0)
            return names[i][1];
    return String(n);
}

// Every fan in `sensors -j` output: [{ key, chip, label, rpm, max }]. A fan
// reading 0 RPM shows only once it was seen turning (`peaks`, key → highest
// RPM so far, updated in place): boards report every empty header as 0,
// while a GPU fan that stops at idle has spun before.
function parseFans(text, peaks) {
    var data;
    try {
        data = typeof text === "string" ? JSON.parse(text) : text;
    } catch (e) {
        return [];
    }
    var out = [];
    peaks = peaks || {};
    for (var chip in data) {
        var c = data[chip];
        if (!c || typeof c !== "object")
            continue;
        for (var label in c) {
            var sd = c[label];
            if (!sd || typeof sd !== "object")
                continue;
            for (var k in sd) {
                var m = /^(fan\d+)_input$/.exec(k);
                if (!m || typeof sd[k] !== "number")
                    continue;
                var key = chip + ":" + label, rpm = Math.max(0, Math.round(sd[k]));
                peaks[key] = Math.max(peaks[key] || 0, rpm);
                if (peaks[key] > 0)
                    out.push({ key: key, chip: chipName(chip), label: label, rpm: rpm, max: Number(sd[m[1] + "_max"]) > rpm ? Number(sd[m[1] + "_max"]) : 0 });
            }
        }
    }
    return out;
}

// ── systemd units ────────────────────────────────────────────────────────────
// "sshd, docker.service, user:syncthing" → [{ name, user }]; anything that is
// not a plain unit name is dropped before it could reach a shell.
function serviceList(text) {
    var out = [];
    String(text || "").split(",").forEach(function (part) {
        var s = part.trim(), user = false;
        if (s.indexOf("user:") === 0) {
            user = true;
            s = s.slice(5).trim();
        }
        if (/^[A-Za-z0-9@._\\:-]+$/.test(s))
            out.push({ name: s, user: user });
    });
    return out;
}

function servicesCmd(units) {
    var list = serviceList(units);
    var sys = list.filter(function (u) { return !u.user; }).map(function (u) { return quote(u.name); });
    var usr = list.filter(function (u) { return u.user; }).map(function (u) { return quote(u.name); });
    var props = " show --no-pager -p Id,LoadState,ActiveState,SubState,Description ";
    return "echo @@failed; systemctl --failed --no-legend --plain --no-pager 2>/dev/null; "
        + "echo @@ufailed; systemctl --user --failed --no-legend --plain --no-pager 2>/dev/null; "
        + "echo @@running; systemctl list-units --type=service --state=running --no-legend --plain --no-pager 2>/dev/null | wc -l"
        + (sys.length ? "; echo @@show; systemctl" + props + sys.join(" ") + " 2>/dev/null" : "")
        + (usr.length ? "; echo @@ushow; systemctl --user" + props + usr.join(" ") + " 2>/dev/null" : "");
}

// → { failed [{ name, user, desc }], running, units [{ name, user, load,
// active, sub, desc }] }
function parseServices(text) {
    var out = { failed: [], running: 0, units: [] }, part = "", unit = null;
    var flush = function () {
        if (unit && unit.name)
            out.units.push(unit);
        unit = null;
    };
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@(failed|ufailed|running|show|ushow)\s*$/.exec(line);
        if (m) {
            flush();
            part = m[1];
            return;
        }
        var t = line.trim();
        if (part === "failed" || part === "ufailed") {
            var f = t.replace(/^[●*]\s*/, "").split(/\s+/);
            if (f.length >= 4 && f[0])
                out.failed.push({ name: f[0], user: part === "ufailed", desc: f.slice(4).join(" ") });
        } else if (part === "running") {
            if (/^\d+$/.test(t))
                out.running = parseInt(t);
        } else if (part === "show" || part === "ushow") {
            if (!t) {
                flush();
                return;
            }
            var eq = t.indexOf("=");
            if (eq < 0)
                return;
            unit = unit || { name: "", user: part === "ushow", load: "", active: "", sub: "", desc: "" };
            var k = t.slice(0, eq), v = t.slice(eq + 1);
            if (k === "Id")
                unit.name = v;
            else if (k === "LoadState")
                unit.load = v;
            else if (k === "ActiveState")
                unit.active = v;
            else if (k === "SubState")
                unit.sub = v;
            else if (k === "Description")
                unit.desc = v;
        }
    });
    flush();
    return out;
}

// ── Containers and pods ──────────────────────────────────────────────────────
// Docker and Podman containers with their CPU and memory, and Kubernetes pods
// (kubectl, or k3s's bundled one) when a kubeconfig is readable. `namespace`
// empty means all namespaces.
function containersCmd(opts) {
    opts = opts || {};
    var ns = /^[a-z0-9-]+$/.test(String(opts.namespace || "")) ? "-n " + opts.namespace : "-A";
    var sh = "";
    if (opts.containers !== false)
        sh += "for e in docker podman; do command -v $e >/dev/null 2>&1 || continue; echo \"@@ps $e\"; "
            + "timeout 4 $e ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.State}}|{{.Status}}' 2>&1 </dev/null; "
            + "echo \"@@stats $e\"; timeout 6 $e stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}' 2>/dev/null </dev/null; done; ";
    if (opts.kubernetes !== false)
        sh += "K=\"$KUBECONFIG\"; if [ -z \"$K\" ]; then for f in \"$HOME/.kube/config\" /etc/rancher/k3s/k3s.yaml; do [ -r \"$f\" ] && { K=\"$f\"; break; }; done; fi; "
            + "kc=; if command -v kubectl >/dev/null 2>&1; then kc=kubectl; elif command -v k3s >/dev/null 2>&1; then kc=\"k3s kubectl\"; fi; "
            + "if [ -n \"$K\" ] && [ -n \"$kc\" ]; then export KUBECONFIG=\"$K\"; echo \"@@kube $($kc config current-context 2>/dev/null)\"; "
            + "timeout 6 $kc get pods " + ns + " --no-headers --request-timeout=5s -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,WAIT:.status.containerStatuses[*].state.waiting.reason' 2>&1 </dev/null | head -300; "
            + "echo @@top; timeout 6 $kc top pods " + ns + " --no-headers --request-timeout=5s 2>/dev/null </dev/null | head -300; fi";
    return sh;
}

// "5m" (millicores) or "2" (cores) → percent of one core.
function kubeCpu(text) {
    var m = /^([0-9.]+)(m|n|u)?$/.exec(String(text || "").trim());
    if (!m)
        return 0;
    var v = Number(m[1]);
    return m[2] === "m" ? v / 10 : m[2] === "u" ? v / 1e4 : m[2] === "n" ? v / 1e7 : v * 100;
}

// → { engines [names], errors [text], context, list [{ engine, name, image,
// ns, state (running|waiting|failed|stopped|paused), status, cpu, memory,
// restarts }] }
function parseContainerList(text) {
    var out = { engines: [], errors: [], context: "", list: [] };
    var byKey = {}, part = "", engine = "";
    var add = function (c) {
        byKey[c.engine + ":" + (c.ns ? c.ns + "/" : "") + c.name] = c;
        out.list.push(c);
    };
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@(ps|stats) (docker|podman)\s*$/.exec(line);
        if (m) {
            part = m[1];
            engine = m[2];
            if (out.engines.indexOf(engine) === -1)
                out.engines.push(engine);
            return;
        }
        m = /^@@kube ?(.*)$/.exec(line);
        if (m) {
            part = "pods";
            engine = "kubernetes";
            out.context = m[1].trim();
            out.engines.push(engine);
            return;
        }
        if (line.trim() === "@@top") {
            part = "top";
            return;
        }
        var t = line.trim();
        if (!t)
            return;
        var f;
        if (part === "ps") {
            f = t.split("|");
            if (f.length < 5) {
                if (out.errors.indexOf(engine + ": " + t) === -1 && out.errors.length < 4)
                    out.errors.push(engine + ": " + t.slice(0, 160));
                return;
            }
            var st = f[3].toLowerCase();
            add({
                engine: engine, name: f[1].split(",")[0], image: f[2], ns: "",
                state: st === "running" ? "running" : st === "restarting" ? "waiting" : st === "paused" ? "paused" : st === "dead" ? "failed" : "stopped",
                status: f[4], cpu: 0, memory: 0, restarts: 0
            });
        } else if (part === "stats") {
            f = t.split("|");
            var c = byKey[engine + ":" + f[0]];
            if (c && f.length >= 3) {
                c.cpu = parseFloat(f[1]) || 0;
                c.memory = sizeBytes(String(f[2]).split("/")[0]);
            }
        } else if (part === "pods") {
            f = t.split(/\s+/);
            if (f.length < 6 || !/^[A-Za-z]+$/.test(f[2])) {
                if (out.errors.length < 4)
                    out.errors.push("kubernetes: " + t.slice(0, 160));
                return;
            }
            var ready = f[3] === "<none>" ? [] : f[3].split(",");
            var wait = f[5] === "<none>" ? "" : f[5].split(",")[0];
            var phase = f[2];
            var state = /BackOff|Err|Invalid|OOM/.test(wait) || phase === "Failed" ? "failed"
                : phase === "Succeeded" ? "stopped"
                : phase === "Running" && ready.length && ready.every(function (r) { return r === "true"; }) ? "running" : "waiting";
            add({
                engine: engine, name: f[1], image: "", ns: f[0], state: state,
                status: wait || (phase === "Succeeded" ? "Completed" : phase === "Running" && state === "waiting" ? "Not ready" : phase),
                cpu: 0, memory: 0,
                restarts: f[4] === "<none>" ? 0 : f[4].split(",").reduce(function (a, v) { return a + (parseInt(v) || 0); }, 0)
            });
        } else if (part === "top") {
            f = t.split(/\s+/);
            // All namespaces: NS NAME CPU MEM; one namespace: NAME CPU MEM.
            var keyed = f.length >= 4 ? "kubernetes:" + f[0] + "/" + f[1] : null;
            var pod = keyed ? byKey[keyed] : out.list.filter(function (x) { return x.engine === "kubernetes" && x.name === f[0]; })[0];
            if (pod) {
                pod.cpu = kubeCpu(f[f.length - 2]);
                pod.memory = sizeBytes(f[f.length - 1]);
            }
        }
    });
    return out;
}

// ── Power ────────────────────────────────────────────────────────────────────
// The system battery (not a mouse's), the charger, energy counters (RAPL)
// and power sensors (hwmon, e.g. amdgpu), pressure stall info, and the
// power-profiles-daemon profile over D-Bus (either bus name).
var PP_FN = "pp() { gdbus call --system --timeout 2 --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles --method org.freedesktop.DBus.Properties.$1 org.freedesktop.UPower.PowerProfiles \"$2\" $3 2>/dev/null "
    + "|| gdbus call --system --timeout 2 --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.$1 net.hadess.PowerProfiles \"$2\" $3 2>/dev/null; }; ";

function powerCmd(opts) {
    opts = opts || {};
    return "for p in /sys/class/power_supply/*; do t=$(cat $p/type 2>/dev/null); "
        + "if [ \"$t\" = Mains ]; then echo ac=$(cat $p/online 2>/dev/null); continue; fi; "
        + "[ \"$t\" = Battery ] || continue; [ \"$(cat $p/scope 2>/dev/null)\" = Device ] && continue; [ -f $p/capacity ] || continue; "
        + "echo bat=$(cat $p/capacity 2>/dev/null); echo status=$(cat $p/status 2>/dev/null); "
        + "[ -f $p/cycle_count ] && echo cycles=$(cat $p/cycle_count 2>/dev/null); "
        + "[ -f $p/temp ] && echo temp=$(cat $p/temp 2>/dev/null); "
        + "en=$(cat $p/energy_now 2>/dev/null); ef=$(cat $p/energy_full 2>/dev/null); ed=$(cat $p/energy_full_design 2>/dev/null); "
        + "if [ -n \"$en\" ]; then echo useEnergy=1; else en=$(cat $p/charge_now 2>/dev/null); ef=$(cat $p/charge_full 2>/dev/null); ed=$(cat $p/charge_full_design 2>/dev/null); echo useEnergy=0; fi; "
        + "echo enow=${en:-0}; echo efull=${ef:-0}; echo edesign=${ed:-0}; "
        + "pw=$(cat $p/power_now 2>/dev/null); "
        + "if [ -z \"$pw\" ]; then v=$(cat $p/voltage_now 2>/dev/null); c=$(cat $p/current_now 2>/dev/null); "
        + "[ -n \"$v\" ] && [ -n \"$c\" ] && pw=$(awk -v v=\"$v\" -v c=\"$c\" 'BEGIN{printf \"%d\", v*c/1000000}'); fi; "
        + "echo power=${pw:-0}; echo model=$(cat $p/model_name 2>/dev/null); break; done; "
        + "for r in /sys/class/powercap/intel-rapl:[0-9]*; do case ${r##*/} in *:*:*) continue;; esac; [ -r $r/energy_uj ] || continue; "
        + "echo \"rapl ${r##*/} $(cat $r/energy_uj 2>/dev/null) $(cat $r/max_energy_range_uj 2>/dev/null) $(cat $r/name 2>/dev/null)\"; done; "
        + "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); case $n in BAT*|ADP*|AC*|ucsi*|macsmc*) continue;; esac; "
        + "for f in $h/power1_average $h/power1_input; do [ -r $f ] && { echo \"hwmon ${h##*/} $(cat $f 2>/dev/null) $n\"; break; }; done; done; "
        + (opts.nvidia ? "nvidia-smi --query-gpu=index,power.draw --format=csv,noheader,nounits 2>/dev/null | sed 's/^/nvidia /'; " : "")
        + "[ -f /proc/pressure/cpu ] && sed 's/^/cpu /' /proc/pressure/cpu 2>/dev/null | head -1; "
        + "[ -f /proc/pressure/memory ] && sed 's/^/mem /' /proc/pressure/memory 2>/dev/null | head -1; "
        + "if command -v gdbus >/dev/null 2>&1; then " + PP_FN + "echo \"profile $(pp Get ActiveProfile)\"; "
        + (opts.profiles ? "echo \"profiles $(pp Get Profiles)\"; " : "") + "fi";
}

// Switches the power profile; only a plain profile name reaches the shell.
function setProfileCmd(name) {
    if (!/^[a-z-]+$/.test(String(name || "")))
        return "";
    return PP_FN + "pp Set ActiveProfile \"<'" + name + "'>\" || powerprofilesctl set " + name;
}

// Plain values out of powerCmd's reply. Energy counters are left cumulative;
// powerSources() turns two replies into watts.
function parsePower(text) {
    var out = {
        battery: -1, status: "", ac: -1, cycles: -1, tempDeci: -9999, enow: 0, efull: 0, edesign: 0, useEnergy: false, powerUW: 0, model: "",
        rapl: {}, hwmon: [], nvidia: [], cpuPressure: 0, memPressure: 0, profile: "", profiles: null
    };
    String(text || "").split("\n").forEach(function (line) {
        var t = line.trim(), eq = t.indexOf("="), k = eq > 0 ? t.slice(0, eq) : "", v = eq > 0 ? t.slice(eq + 1) : "";
        var n = parseInt(v), f = t.split(/\s+/);
        if (k === "bat" && !isNaN(n) && n >= 0)
            out.battery = n;
        else if (k === "status")
            out.status = v;
        else if (k === "ac" && !isNaN(n))
            out.ac = Math.max(out.ac, n);
        else if (k === "cycles" && !isNaN(n))
            out.cycles = n;
        else if (k === "temp" && !isNaN(n))
            out.tempDeci = n;
        else if (k === "enow" && !isNaN(n))
            out.enow = n;
        else if (k === "efull" && !isNaN(n))
            out.efull = n;
        else if (k === "edesign" && !isNaN(n))
            out.edesign = n;
        else if (k === "useEnergy")
            out.useEnergy = v === "1";
        else if (k === "power" && !isNaN(n))
            out.powerUW = n;
        else if (k === "model")
            out.model = v;
        else if (f[0] === "rapl" && f.length >= 3 && !isNaN(Number(f[2])))
            out.rapl[f[1]] = { energy: Number(f[2]), range: Number(f[3]) || 0, name: f.slice(4).join(" ") || f[1] };
        else if (f[0] === "hwmon" && f.length >= 3 && Number(f[2]) > 0)
            out.hwmon.push({ id: f[1], watts: Number(f[2]) / 1e6, name: f.slice(3).join(" ") || f[1] });
        else if (f[0] === "nvidia" && f.length >= 3 && !isNaN(parseFloat(f[2])))
            out.nvidia.push({ id: "nvidia" + parseInt(f[1]), watts: parseFloat(f[2]), name: "nvidia" });
        else if (t.indexOf("cpu some") === 0 || t.indexOf("mem some") === 0) {
            var a = /avg10=(\d+\.?\d*)/.exec(t);
            if (a)
                out[t.charAt(0) === "c" ? "cpuPressure" : "memPressure"] = parseFloat(a[1]);
        } else if (f[0] === "profile") {
            var p = /'([a-z-]+)'/.exec(t);
            out.profile = p ? p[1] : "";
        } else if (f[0] === "profiles") {
            var list = [], re = /'Profile': <'([a-z-]+)'>/g, mm;
            while ((mm = re.exec(t)) !== null)
                list.push(mm[1]);
            out.profiles = list;
        }
    });
    return out;
}

var RAPL_LABELS = { "package-0": "CPU package", "package-1": "CPU package 2", psys: "Platform", dram: "Memory" };
var HWMON_LABELS = { amdgpu: "GPU (AMD)", zenpower: "CPU (AMD)", nouveau: "GPU (Nouveau)", xe: "GPU (Intel)", i915: "GPU (Intel)" };

// Watts per source between two parsePower() results `dt` seconds apart:
// [{ id, label, watts }], plus `load`, the whole machine where a sensor
// covers it (platform "psys"), else the sum of CPU packages and GPUs.
function powerSources(prev, next, dt) {
    var list = [];
    if (prev && dt > 0)
        for (var id in next.rapl) {
            var a = prev.rapl[id], b = next.rapl[id];
            if (!a)
                continue;
            var d = b.energy - a.energy;
            if (d < 0 && b.range > 0)
                d += b.range;
            if (d >= 0)
                list.push({ id: id, label: RAPL_LABELS[b.name] || b.name, watts: d / dt / 1e6, platform: b.name === "psys" });
        }
    next.hwmon.concat(next.nvidia).forEach(function (h) {
        list.push({ id: h.id, label: HWMON_LABELS[h.name] || (h.name === "nvidia" ? "GPU (NVIDIA)" : h.name), watts: h.watts });
    });
    var platform = list.filter(function (s) { return s.platform; })[0];
    var load = platform ? platform.watts : list.filter(function (s) { return !s.platform && s.label !== "Memory"; }).reduce(function (a, s) { return a + s.watts; }, 0);
    return { list: list, load: load };
}

// ── Remote host ──────────────────────────────────────────────────────────────
// "user@host" or an ~/.ssh/config alias; "" for anything else.
function remoteHost(text) {
    var h = String(text || "").trim();
    return /^[A-Za-z0-9._-]+(@[A-Za-z0-9._:-]+)?$/.test(h) ? h : "";
}

// Runs `command` on `host` over one shared SSH connection (the first call
// opens it, later ones reuse it for two minutes). BatchMode: keys only, a
// password prompt would hang the widget.
function remoteCmd(host, command) {
    return "ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=15 -o ControlMaster=auto "
        + "-o ControlPath=\"${XDG_RUNTIME_DIR:-/tmp}/glassy-ssh-%C\" -o ControlPersist=120 "
        + host + " " + quote("sh -c " + quote(command));
}

// ── Sockets (the network window) ─────────────────────────────────────────────
// Everything `ss` shows without root: every TCP and UDP socket with its
// process (other users' processes stay anonymous), and for TCP the counters
// from `-i` (bytes_sent / bytes_received, rtt, cwnd). The same output lists
// the listening sockets, so one poll serves the Connections and Listening
// pages. The process table (for grouping helpers under their app) and
// /proc/net/dev (for the total rates) ride along.
var CONNECTIONS_CMD = "ss -tunapiH 2>/dev/null; echo @@proc; cat /proc/[0-9]*/stat 2>/dev/null; echo @@dev; cat /proc/net/dev 2>/dev/null";
// The same without the process table, for polls that know every process.
var CONNECTIONS_LIGHT_CMD = "ss -tunapiH 2>/dev/null; echo @@dev; cat /proc/net/dev 2>/dev/null";
// Listening sockets only: which app listens where.
var LISTENING_CMD = "ss -tulpnH 2>/dev/null";

// Splits "@@name" separated output into { "": head, name: text, … }.
function sections(text) {
    var out = {}, name = "", buf = [];
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@(\w+)\s*$/.exec(line);
        if (m) {
            out[name] = buf.join("\n");
            name = m[1];
            buf = [];
        } else {
            buf.push(line);
        }
    });
    out[name] = buf.join("\n");
    return out;
}

// "192.168.1.23:443", "[2a00:1450::1]:443", "[::ffff:10.0.0.2]:22",
// "192.168.1.23%wlp2s0:68", "*:5353", and old ss's bracketless ":::22".
// → { ip, port, scope } with IPv4-mapped IPv6 unwrapped.
function splitAddress(text) {
    var s = String(text || ""), ip = s, port = "";
    var m = /^\[(.*)\]:([^:]*)$/.exec(s);
    if (m) {
        ip = m[1];
        port = m[2];
    } else {
        var at = s.lastIndexOf(":");
        if (at >= 0) {
            ip = s.slice(0, at);
            port = s.slice(at + 1);
        }
    }
    var scope = "", pct = ip.indexOf("%");
    if (pct >= 0) {
        scope = ip.slice(pct + 1);
        ip = ip.slice(0, pct);
    }
    var mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(ip);
    if (mapped)
        ip = mapped[1];
    if (ip === "")
        ip = "*";
    return { ip: ip, port: port, scope: scope };
}

function isWildcard(ip) {
    return ip === "*" || ip === "0.0.0.0" || ip === "::" || ip === "[::]";
}

// users:(("firefox",pid=2211,fd=127),("firefox",pid=2212,fd=5))
function parseUsers(text) {
    var list = [], re = /\("((?:[^"\\]|\\.)*)",pid=(\d+)/g, m;
    while ((m = re.exec(String(text || ""))) !== null)
        list.push({ name: cleanName(m[1]), pid: Number(m[2]) });
    return list;
}

// The `-i` line: "key:value" pairs and a few "key value" ones.
function parseTcpInfo(text) {
    var info = {};
    var num = function (key) {
        var m = new RegExp("(?:^|\\s)" + key + ":([0-9.]+)").exec(text);
        return m ? Number(m[1]) : null;
    };
    info.bytesSent = num("bytes_sent");
    // Older kernels report only bytes_acked.
    if (info.bytesSent === null)
        info.bytesSent = num("bytes_acked");
    info.bytesReceived = num("bytes_received");
    var rtt = /(?:^|\s)rtt:([0-9.]+)/.exec(text);
    info.rtt = rtt ? Number(rtt[1]) : null;
    info.cwnd = num("cwnd");
    return info;
}

// Every socket in `ss -tunapiH` (or -tulpnH) output:
// [{ proto, state, local {ip, port, scope}, remote, recvQ, sendQ,
//    procs [{name, pid}], name, pid, bytesSent, bytesReceived, rtt, cwnd }]
// bytes/rtt/cwnd are null where ss has none (UDP, other users' sockets).
function parseSockets(text) {
    var list = [], last = null;
    String(text || "").split("\n").forEach(function (line) {
        if (/^\s/.test(line)) {
            // `-i` continuation of the socket above.
            if (last && line.trim() !== "") {
                var info = parseTcpInfo(line);
                for (var k in info)
                    if (info[k] !== null)
                        last[k] = info[k];
            }
            return;
        }
        var f = line.trim().split(/\s+/);
        if (f.length < 6 || !/^(tcp|udp)/i.test(f[0])) {
            last = null;
            return;
        }
        var procs = parseUsers(f.slice(6).join(" "));
        last = {
            proto: f[0].toLowerCase().replace(/[0-9]/g, ""),
            state: f[1],
            recvQ: Number(f[2]) || 0,
            sendQ: Number(f[3]) || 0,
            local: splitAddress(f[4]),
            remote: splitAddress(f[5]),
            procs: procs,
            name: procs.length ? procs[0].name : "",
            pid: procs.length ? procs[0].pid : 0,
            bytesSent: null,
            bytesReceived: null,
            rtt: null,
            cwnd: null
        };
        list.push(last);
    });
    return list;
}

function isListening(s) {
    return s.state === "LISTEN" || (s.proto === "udp" && s.state === "UNCONN" && (isWildcard(s.remote.ip) || s.remote.port === "*"));
}

// Sockets with a peer: established TCP, connected UDP, closing states.
function parseConnections(text) {
    return parseSockets(text).filter(function (s) {
        return !isListening(s) && s.remote.port !== "*" && s.remote.port !== "0" && !isWildcard(s.remote.ip);
    });
}

// Listening sockets: [{ proto, ip, port, scope, name, pid, procs,
// exposure ("local" | "network"), address kind }]. Loopback addresses are
// reachable from this machine only; wildcards and real addresses are open
// to the network (whatever the firewall then allows).
function parseListening(text) {
    var seen = {}, list = [];
    parseSockets(text).filter(isListening).forEach(function (s) {
        var key = s.proto + " " + s.local.ip + " " + s.local.port + " " + s.pid;
        if (seen[key])
            return;
        seen[key] = true;
        var kind = isWildcard(s.local.ip) ? "any" : addressKind(s.local.ip);
        list.push({
            proto: s.proto,
            ip: s.local.ip,
            port: s.local.port,
            scope: s.local.scope,
            name: s.name,
            pid: s.pid,
            procs: s.procs,
            kind: kind,
            exposure: kind === "loopback" ? "local" : "network"
        });
    });
    list.sort(function (a, b) {
        return (a.exposure === b.exposure ? 0 : a.exposure === "network" ? -1 : 1) || (Number(a.port) || 0) - (Number(b.port) || 0);
    });
    return list;
}

// Local ports something listens on, per protocol: { tcp: {port: true}, udp }.
function listenPorts(sockets) {
    var out = { tcp: {}, udp: {} };
    sockets.forEach(function (s) {
        if (isListening(s))
            out[s.proto][s.local.port] = true;
    });
    return out;
}

// "in" when the peer reached one of our listening ports, else "out".
function direction(conn, ports) {
    var p = ports && ports[conn.proto];
    if (!p || !p[conn.local.port])
        return "out";
    // An ephemeral local port that happens to also listen (UDP) is still ours.
    return conn.proto === "udp" && Number(conn.local.port) >= 32768 ? "out" : "in";
}

// ── Addresses ────────────────────────────────────────────────────────────────
var ADDRESS_LABELS = { loopback: "Loopback", local: "Link-local", lan: "LAN", multicast: "Multicast", internet: "Internet", any: "All addresses" };

function ipv4Parts(ip) {
    var m = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(ip);
    return m ? [Number(m[1]), Number(m[2]), Number(m[3]), Number(m[4])] : null;
}

// "loopback", "local" (link-local), "lan" (private, CGNAT, ULA),
// "multicast" (and broadcast), or "internet".
function addressKind(ip) {
    ip = String(ip || "").toLowerCase().replace(/^\[|\]$/g, "");
    var mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(ip);
    if (mapped)
        ip = mapped[1];
    var v4 = ipv4Parts(ip);
    if (v4) {
        var a = v4[0], b = v4[1];
        if (a === 127)
            return "loopback";
        if (a === 169 && b === 254)
            return "local";
        if (a === 10 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127))
            return "lan";
        if ((a >= 224 && a <= 239) || ip === "255.255.255.255")
            return "multicast";
        if (a === 0)
            return "local";
        return "internet";
    }
    if (ip === "::1")
        return "loopback";
    if (/^fe[89ab]/.test(ip))
        return "local";
    if (/^f[cd]/.test(ip))
        return "lan";
    if (/^ff/.test(ip))
        return "multicast";
    if (ip === "::" || ip === "*" || ip === "")
        return "local";
    return "internet";
}

// Only plain addresses ever reach a shell command.
function safeIp(ip) {
    return /^[0-9a-fA-F:.]{2,45}$/.test(String(ip || ""));
}

// ── Reverse DNS and GeoIP ────────────────────────────────────────────────────
// Local GeoIP databases, first readable one wins: $GLASSY_GEOIP_COUNTRY /
// $GLASSY_GEOIP_ASN (the Nix module sets them), the one-click download
// (~/.local/share/GeoIP), Nix profiles (nixpkgs dbip-*-lite), the usual
// system places, Portmaster's copy. Nothing is ever looked up online.
var GEO_DIRS = ["$HOME/.local/share/GeoIP", "/run/current-system/sw/share/dbip", "$HOME/.nix-profile/share/dbip", "/etc/profiles/per-user/$USER/share/dbip",
    "/usr/share/GeoIP", "/var/lib/GeoIP", "/usr/local/share/GeoIP"];
var GEO_COUNTRY_DBS = ["$GLASSY_GEOIP_COUNTRY"].concat([].concat.apply([], GEO_DIRS.map(function (d) {
    return [d + "/dbip-country-lite.mmdb", d + "/dbip-city-lite.mmdb", d + "/GeoLite2-Country.mmdb", d + "/GeoLite2-City.mmdb", d + "/dbip-country.mmdb"];
})));
var GEO_ASN_DBS = ["$GLASSY_GEOIP_ASN"].concat(GEO_DIRS.map(function (d) { return d + "/dbip-asn-lite.mmdb"; }), GEO_DIRS.map(function (d) { return d + "/GeoLite2-ASN.mmdb"; }));

// Sets MM (mmdblookup), C (country database) and A (ASN database).
function geoPickCmd() {
    var pick = function (v, dbs) {
        return v + "=; for f in " + dbs.map(function (d) { return "\"" + d + "\""; }).join(" ") + "; do [ -z \"$" + v + "\" ] && [ -n \"$f\" ] && [ -r \"$f\" ] && " + v + "=$f; done; ";
    };
    return "MM=$(command -v mmdblookup 2>/dev/null); " + pick("C", GEO_COUNTRY_DBS) + pick("A", GEO_ASN_DBS)
        + "PM=/var/lib/portmaster/updates/all/intel/geoip; [ -z \"$C\" ] && C=$(ls -1t \"$PM\"/geoipv4_*.mmdb 2>/dev/null | head -1); ";
}

// What the GeoIP setup shows: "mm <path>", "country <path> <mtime>",
// "asn <path> <mtime>", "fetch curl|wget|".
var GEO_STATUS_CMD = geoPickCmd() + "echo \"mm $MM\"; echo \"country $C $([ -n \"$C\" ] && stat -c %Y \"$C\")\"; echo \"asn $A $([ -n \"$A\" ] && stat -c %Y \"$A\")\"; "
    + "echo \"fetch $(command -v curl >/dev/null 2>&1 && echo curl || { command -v wget >/dev/null 2>&1 && echo wget; })\"";

function parseGeoStatus(text) {
    var out = { mmdblookup: "", country: "", countryTime: 0, asn: "", asnTime: 0, fetch: "" };
    String(text || "").split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f[0] === "mm")
            out.mmdblookup = f[1] || "";
        else if (f[0] === "country" || f[0] === "asn") {
            out[f[0]] = f.length > 2 ? f.slice(1, -1).join(" ") : (f[1] || "");
            out[f[0] + "Time"] = f.length > 2 ? Number(f[f.length - 1]) * 1000 || 0 : 0;
        } else if (f[0] === "fetch")
            out.fetch = f[1] || "";
    });
    return out;
}

// Only on a click in the GeoIP setup: db-ip's free Lite databases
// (CC BY 4.0, about 8 + 9 MB) into ~/.local/share/GeoIP, this month's or
// last month's; each replaces the old file only once it is complete.
var GEO_DOWNLOAD_CMD = "D=\"$HOME/.local/share/GeoIP\"; mkdir -p \"$D\" || exit 1; "
    + "get() { if command -v curl >/dev/null 2>&1; then curl -fsSL --max-time 180 -o \"$2\" \"$1\"; elif command -v wget >/dev/null 2>&1; then wget -q -T 180 -O \"$2\" \"$1\"; else return 9; fi; }; "
    + "this=$(date +%Y-%m); prev=$(date -d \"$(date +%Y-%m-01) -1 day\" +%Y-%m 2>/dev/null); "
    + "for db in country asn; do ok=; for m in $this $prev; do "
    + "get \"https://download.db-ip.com/free/dbip-$db-lite-$m.mmdb.gz\" \"$D/.dbip-$db.gz\" && gzip -dc \"$D/.dbip-$db.gz\" > \"$D/.dbip-$db.mmdb\" && [ -s \"$D/.dbip-$db.mmdb\" ] "
    + "&& mv -f \"$D/.dbip-$db.mmdb\" \"$D/dbip-$db-lite.mmdb\" && ok=$m && break; done; rm -f \"$D/.dbip-$db.gz\" \"$D/.dbip-$db.mmdb\"; echo \"$db ${ok:-failed}\"; done";

// One shell run for a batch of addresses, every lookup in parallel with a
// one-second limit each. Prints "geo<TAB>countryDb<TAB>asnDb" once, then
// "host<TAB>ip<TAB>name<TAB>country<TAB>asn<TAB>org" per address.
function resolveCmd(ips) {
    var list = (ips || []).filter(safeIp);
    var str = "sed -n 's/^ *\"\\(.*\\)\" <utf8_string>.*/\\1/p' | head -1";
    return geoPickCmd()
        + "[ -z \"$MM\" ] && C= && A=; printf 'geo\\t%s\\t%s\\n' \"$C\" \"$A\"; "
        + "q() { h=$(timeout 1 getent hosts \"$1\" 2>/dev/null | awk '{print $2; exit}'); c=; a=; o=; "
        + "[ -n \"$C\" ] && c=$(timeout 1 \"$MM\" --file \"$C\" --ip \"$1\" country iso_code 2>/dev/null | " + str + "); "
        + "[ -n \"$A\" ] && a=$(timeout 1 \"$MM\" --file \"$A\" --ip \"$1\" autonomous_system_number 2>/dev/null | awk '/<uint/{print $1; exit}') "
        + "&& o=$(timeout 1 \"$MM\" --file \"$A\" --ip \"$1\" autonomous_system_organization 2>/dev/null | " + str + "); "
        + "printf 'host\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$1\" \"$h\" \"$c\" \"$a\" \"$o\"; }; "
        + list.map(function (ip) { return "q " + ip + " &"; }).join(" ") + " wait";
}

// → { geo: { country: bool, asn: bool } | null, hosts: { ip: { name, country, asn, org } } }
function parseResolve(text) {
    var out = { geo: null, hosts: {} };
    String(text || "").split("\n").forEach(function (line) {
        var f = line.split("\t");
        if (f[0] === "geo")
            out.geo = { country: !!(f[1] || "").trim(), asn: !!(f[2] || "").trim() };
        else if (f[0] === "host" && f[1]) {
            var name = (f[2] || "").trim();
            out.hosts[f[1]] = {
                name: name === f[1] ? "" : name,
                country: /^[A-Za-z]{2}$/.test((f[3] || "").trim()) ? f[3].trim().toUpperCase() : "",
                asn: Number(f[4]) || 0,
                org: (f[5] || "").trim()
            };
        }
    });
    return out;
}

// ISO 3166 alpha-2 → emoji flag.
function flag(cc) {
    if (!/^[A-Z]{2}$/.test(cc || ""))
        return "";
    return String.fromCodePoint(0x1F1E6 + cc.charCodeAt(0) - 65) + String.fromCodePoint(0x1F1E6 + cc.charCodeAt(1) - 65);
}

// "fra16s52-in-f14.1e100.net" → "1e100.net"; keeps "bbc.co.uk".
function baseDomain(host) {
    var parts = String(host || "").toLowerCase().replace(/\.$/, "").split(".");
    if (parts.length <= 2)
        return parts.join(".");
    var n = /^(co|com|net|org|ac|gov|edu|ne|or)$/.test(parts[parts.length - 2]) && parts[parts.length - 1].length === 2 ? 3 : 2;
    return parts.slice(-n).join(".");
}

// ── App identity ─────────────────────────────────────────────────────────────
// The Name, Icon, Exec and StartupWMClass of every .desktop file, one awk
// run over all of them.
var DESKTOP_CMD = "IFS=:; for d in ${XDG_DATA_HOME:-$HOME/.local/share} ${XDG_DATA_DIRS:-/usr/local/share:/usr/share} "
    + "/var/lib/flatpak/exports/share $HOME/.local/share/flatpak/exports/share /run/current-system/sw/share $HOME/.nix-profile/share; do "
    + "for f in \"$d\"/applications/*.desktop; do [ -r \"$f\" ] && set -- \"$@\" \"$f\"; done; done; unset IFS; "
    + "[ $# -gt 0 ] && awk 'FNR==1{n=split(FILENAME,p,\"/\"); print \"@ \" p[n]; s=0} /^\\[/{s=($0==\"[Desktop Entry]\")} "
    + "s && /^(Name|Icon|Exec|StartupWMClass|NoDisplay)=/' \"$@\" 2>/dev/null";

// Process names that start other programs: an app is never grouped under
// these (a terminal's children are their own apps).
var LAUNCHERS = ["systemd", "init", "plasmashell", "kwin_wayland", "kwin_x11", "hyprland", "sway", "gnome-shell", "startplasma-way", "startplasma-x11",
    "sddm", "gdm", "login", "sshd", "krunner", "dbus-daemon", "dbus-broker", "kded6", "kded5", "quickshell", "qs", "bash", "zsh", "fish", "sh", "dash", "nu",
    "tmux", "screen", "konsole", "kitty", "alacritty", "foot", "gnome-terminal-", "wezterm-gui", "xterm", "ghostty", "tilix", "yakuake", "terminator",
    "flatpak-session", "bwrap", "sudo", "doas", "su", "code", "nvim", "vim", "emacs"];

// Process names whose .desktop entry is named differently.
var APP_ALIASES = { chrome: "google-chrome", "chromium-browse": "chromium", thunderbird: "thunderbird", "firefox-bin": "firefox", "steamwebhelper": "steam" };

function execName(exec) {
    var words = String(exec || "").split(/\s+/).filter(function (w) { return w && w.indexOf("=") === -1 && w !== "env"; });
    if (!words.length)
        return "";
    var flatpak = words[0].split("/").pop() === "flatpak" && words.indexOf("run") !== -1;
    if (flatpak) {
        var id = words.filter(function (w) { return w.charAt(0) !== "-" && w !== "run" && w.split("/").pop() !== "flatpak"; })[0] || "";
        return id.split(".").pop();
    }
    return words[0].replace(/^"|"$/g, "").split("/").pop();
}

// [{ id, name, icon, exec, wmclass, hidden }]
function parseDesktopEntries(text) {
    var list = [], e = null;
    String(text || "").split("\n").forEach(function (line) {
        if (line.indexOf("@ ") === 0) {
            e = { id: line.slice(2).trim().replace(/\.desktop$/, ""), name: "", icon: "", exec: "", wmclass: "", hidden: false };
            list.push(e);
            return;
        }
        var eq = line.indexOf("=");
        if (!e || eq < 0)
            return;
        var key = line.slice(0, eq), value = line.slice(eq + 1).trim();
        if (key === "Name" && !e.name)
            e.name = value;
        else if (key === "Icon" && !e.icon)
            e.icon = value;
        else if (key === "Exec" && !e.exec)
            e.exec = execName(value);
        else if (key === "StartupWMClass" && !e.wmclass)
            e.wmclass = value;
        else if (key === "NoDisplay")
            e.hidden = value === "true";
    });
    return list.filter(function (x) { return x.name; });
}

// Lower-cased lookup keys → entry. Visible entries and stronger keys
// (the binary, then the file name) win.
function appIndex(entries) {
    var index = {}, rank = {};
    var put = function (key, entry, strength) {
        key = String(key || "").toLowerCase();
        if (!key)
            return;
        var score = strength + (entry.hidden ? 0 : 10);
        if (rank[key] === undefined || score > rank[key]) {
            index[key] = entry;
            rank[key] = score;
        }
    };
    (entries || []).forEach(function (e) {
        put(e.exec, e, 5);
        put(e.id, e, 4);
        put(e.id.split(".").pop(), e, 3);
        put(e.wmclass, e, 2);
        put(e.icon && e.icon.indexOf("/") === -1 ? e.icon : "", e, 1);
    });
    return index;
}

// The desktop entry for a process name, or null. The kernel cuts names to
// 15 characters, so a full-length name also matches as a prefix.
function matchApp(index, name) {
    var n = String(name || "").toLowerCase();
    if (!n || !index)
        return null;
    var candidates = [n, APP_ALIASES[n] || "", n.replace(/(-bin|\.bin|-wrapped|-stable)$/, "")];
    for (var i = 0; i < candidates.length; i++)
        if (candidates[i] && index[candidates[i]])
            return index[candidates[i]];
    if (n.length >= 15)
        for (var key in index)
            if (key.indexOf(n) === 0)
                return index[key];
    return null;
}

// `cat /proc/[0-9]*/stat` → { pid: { name, ppid } }
function parseProcTree(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var open = line.indexOf("("), close = line.lastIndexOf(")");
        if (open < 0 || close < open)
            return;
        var f = line.slice(close + 2).split(" ");
        out[line.slice(0, open).trim()] = { name: cleanName(line.slice(open + 1, close)), ppid: Number(f[1]) || 0 };
    });
    return out;
}

// The app a process belongs to, Portmaster-style: itself when it has a
// .desktop entry, else the nearest ancestor that has one (a browser's
// helpers become the browser), stopping at shells, terminals and the
// session. Unknown programs group by name. → { key, name, icon, pid }
function appFor(pid, name, tree, index) {
    if (!pid && !name)
        return { key: "?", name: "System / other users", icon: "", pid: 0 };
    var self = tree && tree[pid] ? tree[pid].name : name;
    var own = matchApp(index, self || name);
    if (own)
        return { key: "app:" + own.id, name: own.name, icon: own.icon, pid: pid };
    var cur = tree && tree[pid] ? tree[tree[pid].ppid] : null, curPid = tree && tree[pid] ? tree[pid].ppid : 0;
    for (var hops = 0; cur && curPid > 1 && hops < 32; hops++) {
        if (LAUNCHERS.indexOf(cur.name.toLowerCase()) !== -1)
            break;
        var app = matchApp(index, cur.name);
        if (app)
            return { key: "app:" + app.id, name: app.name, icon: app.icon, pid: curPid };
        curPid = cur.ppid;
        cur = tree[curPid];
    }
    var n = self || name;
    return { key: "proc:" + n, name: n, icon: n.toLowerCase(), pid: pid };
}

// ── Traffic counters ─────────────────────────────────────────────────────────
// /proc/net/dev → { iface: { rx, tx } } (bytes), loopback left out.
function parseNetDev(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var m = /^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/.exec(line);
        if (m && m[1] !== "lo")
            out[m[1]] = { rx: Number(m[2]), tx: Number(m[3]) };
    });
    return out;
}

// ── DNS ──────────────────────────────────────────────────────────────────────
// systemd-resolved's counters and the servers per link; plain resolv.conf
// otherwise. Per-query logging would need root, so there is none.
// --no-ask-password everywhere: newer systemd guards the counters with
// polkit, and an interactive query would pop up a password dialog on every
// poll. Denied counters just stay empty (DNS_SERVERS_CMD from then on).
var DNS_SERVERS_CMD = "echo @@servers; resolvectl --no-ask-password dns 2>/dev/null </dev/null || grep '^nameserver' /etc/resolv.conf 2>/dev/null";
var DNS_CMD = "resolvectl --no-ask-password statistics 2>/dev/null </dev/null; " + DNS_SERVERS_CMD;

// → { resolved: bool, stats: { "Cache Hits": 3431, … }, global: [ips], links: { iface: [ips] } }
function parseDns(text) {
    var parts = sections(text), out = { resolved: false, viaResolved: false, stats: {}, global: [], links: {} };
    String(parts[""] || "").split("\n").forEach(function (line) {
        var m = /^\s*([A-Za-z][A-Za-z ]+?):\s*(\d+)\s*$/.exec(line);
        if (m) {
            out.stats[m[1]] = Number(m[2]);
            out.resolved = true;
        }
    });
    String(parts.servers || "").split("\n").forEach(function (line) {
        var ns = /^nameserver\s+(\S+)/.exec(line);
        if (ns) {
            out.global.push(ns[1]);
            return;
        }
        var link = /^Link \d+ \(([^)]+)\):\s*(.*)$/.exec(line);
        if (link || /^Global:/.test(line))
            out.viaResolved = true;
        if (link) {
            var ips = link[2].trim().split(/\s+/).filter(Boolean);
            if (ips.length)
                out.links[link[1]] = ips;
            return;
        }
        var g = /^Global:\s*(.*)$/.exec(line);
        if (g)
            out.global = out.global.concat(g[1].trim().split(/\s+/).filter(Boolean));
    });
    return out;
}

// ── Interface details ────────────────────────────────────────────────────────
// Addresses (v4 and v6), default gateways, DNS servers per link and, for
// Wi-Fi, the `iw` link (SSID, signal, frequency, bit rate), else iwgetid and
// /proc/net/wireless. Nothing here goes through polkit: no password prompts.
var IFACE_DETAILS_CMD = "ip -o addr show 2>/dev/null; echo @@route; ip -o route show default 2>/dev/null; ip -o -6 route show default 2>/dev/null; "
    + "echo @@dns; resolvectl --no-ask-password dns 2>/dev/null </dev/null; echo @@wifi; for d in /sys/class/net/*; do [ -d $d/wireless ] || continue; n=${d##*/}; "
    + "echo \"iface $n\"; iw dev $n link 2>/dev/null || { s=$(iwgetid -r $n 2>/dev/null); [ -n \"$s\" ] && echo \"SSID: $s\"; "
    + "awk -v n=\"$n:\" '$1 == n { gsub(/\\./, \"\", $4); print \"signal: \" $4 \" dBm\" }' /proc/net/wireless 2>/dev/null; }; done";

function band(mhz) {
    return !mhz ? "" : mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz";
}

// → { iface: { ipv4 [], ipv6 [], gateway, gateway6, dns [], wifi: { ssid, signal (dBm), quality (%), freq, band, bitrate } | null } }
function parseIfaceDetails(text) {
    var parts = sections(text), out = {};
    var get = function (n) {
        return out[n] || (out[n] = { ipv4: [], ipv6: [], gateway: "", gateway6: "", dns: [], wifi: null });
    };
    String(parts[""] || "").split("\n").forEach(function (line) {
        var m = /^\d+:\s+(\S+)\s+(inet6?)\s+(\S+)/.exec(line);
        if (!m || m[1] === "lo")
            return;
        var e = get(m[1]);
        if (m[2] === "inet")
            e.ipv4.push(m[3]);
        else
            e.ipv6.push(m[3]);
    });
    String(parts.route || "").split("\n").forEach(function (line) {
        var m = /^default via (\S+) dev (\S+)/.exec(line.trim());
        if (!m)
            return;
        var e = get(m[2]);
        if (m[1].indexOf(":") >= 0)
            e.gateway6 = e.gateway6 || m[1];
        else
            e.gateway = e.gateway || m[1];
    });
    var dns = parseDns("@@servers\n" + (parts.dns || ""));
    for (var n in dns.links)
        get(n).dns = dns.links[n];
    var cur = null;
    String(parts.wifi || "").split("\n").forEach(function (line) {
        var t = line.trim(), m;
        if ((m = /^iface (\S+)/.exec(t))) {
            cur = get(m[1]);
            return;
        }
        if (!cur)
            return;
        var w = cur.wifi || (cur.wifi = { ssid: "", signal: 0, quality: 0, freq: 0, band: "", bitrate: "" });
        if ((m = /^SSID: (.*)$/.exec(t)))
            w.ssid = m[1];
        else if ((m = /^freq: ([0-9.]+)/.exec(t)))
            w.freq = Math.round(Number(m[1]));
        else if ((m = /^signal: (-?\d+)/.exec(t))) {
            w.signal = Number(m[1]);
            w.quality = Math.max(0, Math.min(100, 2 * (w.signal + 100)));
        } else if ((m = /^tx bitrate: ([0-9.]+ \S+)/.exec(t)))
            w.bitrate = m[1];
        w.band = band(w.freq);
    });
    for (var k in out)
        if (out[k].wifi && !out[k].wifi.ssid && !out[k].wifi.freq && !out[k].wifi.signal)
            out[k].wifi = null;
    return out;
}

// ── Containers ───────────────────────────────────────────────────────────────
// Docker and Podman as the user can see them (docker needs the docker
// group; rootless podman just works): running containers with their
// published ports, networks and addresses, and the networks with the bridge
// each uses. Every call has a time limit, so a stopped daemon cannot hang
// the poll. Containers talk inside their own network namespaces, which ss
// here cannot see; their traffic comes from `stats` (CONTAINER_STATS_CMD).
var CONTAINERS_CMD = "for e in docker podman; do command -v $e >/dev/null 2>&1 || continue; echo \"@@engine $e\"; "
    + "if [ $e = docker ]; then timeout 3 docker ps --format '{{json .}}' 2>&1 </dev/null; else timeout 3 podman ps --format json 2>&1 </dev/null; fi; "
    + "ids=$(timeout 3 $e ps -q 2>/dev/null </dev/null); echo \"@@inspect $e\"; [ -n \"$ids\" ] && timeout 3 $e inspect -f '{{.Name}}|{{range $k, $v := .NetworkSettings.Networks}}{{$k}}={{$v.IPAddress}} {{end}}' $ids 2>/dev/null </dev/null; "
    + "echo \"@@networks $e\"; if [ $e = docker ]; then timeout 3 docker network ls --format '{{json .}}' 2>/dev/null </dev/null; else timeout 3 podman network ls --format json 2>/dev/null </dev/null; fi; done";
// Cumulative network bytes per container (slow: a second or two).
var CONTAINER_STATS_CMD = "for e in docker podman; do command -v $e >/dev/null 2>&1 || continue; echo \"@@stats $e\"; "
    + "if [ $e = docker ]; then timeout 6 docker stats --no-stream --format '{{json .}}' 2>/dev/null </dev/null; else timeout 6 podman stats --no-stream --format json 2>/dev/null </dev/null; fi; done";

// "1.45kB", "3.4MiB", "12B" → bytes (docker uses SI units, podman either).
function sizeBytes(text) {
    var m = /^\s*([0-9.]+)\s*([kKMGTP]?)(i?)B?\s*$/.exec(String(text || ""));
    if (!m)
        return 0;
    var power = " KMGTP".indexOf(m[2].toUpperCase());
    return Number(m[1]) * Math.pow(m[3] ? 1024 : 1000, Math.max(0, power));
}

// Lines of JSON objects, or one JSON array → objects. Anything else is an
// error message ("permission denied", "Cannot connect to the Docker daemon").
function jsonRows(text) {
    var t = String(text || "").trim(), rows = [], errors = [];
    if (t.charAt(0) === "[") {
        try {
            return { rows: JSON.parse(t), error: "" };
        } catch (e) {
            return { rows: [], error: t.split("\n")[0] };
        }
    }
    t.split("\n").forEach(function (line) {
        line = line.trim();
        if (!line)
            return;
        if (line.charAt(0) === "{") {
            try {
                rows.push(JSON.parse(line));
                return;
            } catch (e) {}
        }
        errors.push(line);
    });
    return { rows: rows, error: rows.length ? "" : errors.join(" ").slice(0, 200) };
}

// "0.0.0.0:8080->80/tcp, [::]:8080->80/tcp, 9000/tcp" → published ports.
function dockerPorts(text) {
    var out = [];
    String(text || "").split(",").forEach(function (part) {
        var m = /^\s*(.*):([\d-]+)->([\d-]+)\/(\w+)\s*$/.exec(part);
        if (m)
            out.push({ hostIp: m[1].replace(/^\[|\]$/g, "") || "0.0.0.0", hostPort: m[2], containerPort: m[3], proto: m[4] });
    });
    return out;
}

// → { docker: { error, containers [...], networks [...] }, podman: … }
// container: { engine, id, name, image, state, status, ports [{ hostIp,
// hostPort, containerPort, proto }], networks [names], ips { net: ip } }
function parseContainers(text) {
    var engines = {}, cur = null, part = "", buf = [];
    var flush = function () {
        if (!cur)
            return;
        var e = engines[cur] || (engines[cur] = { error: "", containers: [], networks: [] });
        var body = buf.join("\n");
        if (part === "engine") {
            var r = jsonRows(body);
            e.error = r.error;
            e.containers = r.rows.map(function (c) {
                var names = Array.isArray(c.Names) ? c.Names : String(c.Names || "").split(",");
                var ports = Array.isArray(c.Ports) ? c.Ports.filter(function (p) { return p.host_port; }).map(function (p) {
                    var range = p.range > 1 ? "-" + (p.host_port + p.range - 1) : "";
                    return { hostIp: p.host_ip || "0.0.0.0", hostPort: String(p.host_port) + range, containerPort: String(p.container_port) + (p.range > 1 ? "-" + (p.container_port + p.range - 1) : ""), proto: p.protocol || "tcp" };
                }) : dockerPorts(c.Ports);
                return {
                    engine: cur,
                    id: String(c.ID || c.Id || "").slice(0, 12),
                    name: String(names[0] || "").replace(/^\//, ""),
                    image: c.Image || "",
                    state: String(c.State || "").toLowerCase(),
                    status: c.Status || "",
                    ports: ports,
                    networks: Array.isArray(c.Networks) ? c.Networks : String(c.Networks || "").split(",").filter(Boolean),
                    ips: {}
                };
            });
        } else if (part === "inspect") {
            body.split("\n").forEach(function (line) {
                var bar = line.indexOf("|");
                if (bar < 0)
                    return;
                var name = line.slice(0, bar).replace(/^\//, "").trim();
                var c = e.containers.filter(function (x) { return x.name === name; })[0];
                if (!c)
                    return;
                line.slice(bar + 1).trim().split(/\s+/).forEach(function (pair) {
                    var eq = pair.indexOf("=");
                    if (eq > 0 && pair.slice(eq + 1))
                        c.ips[pair.slice(0, eq)] = pair.slice(eq + 1);
                });
            });
        } else if (part === "networks") {
            e.networks = jsonRows(body).rows.map(function (n) {
                var id = String(n.ID || n.id || "").slice(0, 12), name = n.Name || n.name || "";
                var iface = n.network_interface || (name === "bridge" ? "docker0" : (n.Driver || n.driver) === "bridge" && cur === "docker" ? "br-" + id : "");
                return { engine: cur, id: id, name: name, driver: n.Driver || n.driver || "", iface: iface };
            });
        }
    };
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@(engine|inspect|networks) (docker|podman)\s*$/.exec(line);
        if (m) {
            flush();
            part = m[1];
            cur = m[2];
            buf = [];
        } else {
            buf.push(line);
        }
    });
    flush();
    return engines;
}

// → { "docker:name": { rx, tx } } (cumulative bytes)
function parseContainerStats(text) {
    var out = {}, cur = "", buf = [];
    var flush = function () {
        if (!cur)
            return;
        jsonRows(buf.join("\n")).rows.forEach(function (r) {
            var name = String(r.Name || r.name || "").replace(/^\//, "");
            var io = String(r.NetIO || r.net_io || "").split("/");
            if (name && io.length === 2)
                out[cur + ":" + name] = { rx: sizeBytes(io[0]), tx: sizeBytes(io[1]) };
        });
    };
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@stats (docker|podman)\s*$/.exec(line);
        if (m) {
            flush();
            cur = m[1];
            buf = [];
        } else {
            buf.push(line);
        }
    });
    flush();
    return out;
}

// The container publishing a host port: { container, containerPort } or null.
function containerForPort(engines, proto, port) {
    for (var e in engines)
        for (var i = 0; i < engines[e].containers.length; i++) {
            var c = engines[e].containers[i];
            for (var k = 0; k < c.ports.length; k++) {
                var p = c.ports[k], range = String(p.hostPort).split("-").map(Number);
                var n = Number(port);
                if (p.proto === proto && (n === range[0] || (range.length === 2 && n >= range[0] && n <= range[1])))
                    return { container: c, containerPort: p.containerPort };
            }
        }
    return null;
}


// ── VPN ──────────────────────────────────────────────────────────────────────
// Which VPN an interface belongs to, from its name and the daemons running
// (the process table): NordVPN, Proton VPN, Mullvad, Tailscale, WireGuard,
// OpenVPN, Cloudflare WARP, ZeroTier, NetBird, AnyConnect and friends.
var VPN_DAEMONS = [["nordvpnd", "NordVPN"], ["protonvpn", "Proton VPN"], ["proton-vpn", "Proton VPN"], ["mullvad-daemon", "Mullvad"], ["expressvpnd", "ExpressVPN"],
    ["warp-svc", "Cloudflare WARP"], ["tailscaled", "Tailscale"], ["openvpn", "OpenVPN"], ["netbird", "NetBird"], ["zerotier-one", "ZeroTier"], ["vpnagentd", "Cisco AnyConnect"],
    ["openconnect", "OpenConnect"], ["charon", "strongSwan (IPsec)"], ["nebula", "Nebula"], ["surfshark", "Surfshark"], ["pia-daemon", "Private Internet Access"], ["windscribe", "Windscribe"]];

function vpnProvider(iface, daemons) {
    var n = String(iface || "");
    var has = function (name) { return daemons.indexOf(name) !== -1; };
    if (/^nordlynx/.test(n))
        return "NordVPN (NordLynx)";
    if (/^tailscale/.test(n))
        return "Tailscale";
    if (/^(proton|pvpn)/.test(n))
        return "Proton VPN";
    if (/mullvad/.test(n))
        return "Mullvad";
    if (/^CloudflareWARP/i.test(n))
        return "Cloudflare WARP";
    if (/^zt/.test(n))
        return "ZeroTier";
    if (/^wt\d/.test(n))
        return "NetBird";
    if (/^cscotun/.test(n))
        return "Cisco AnyConnect";
    if (/^nebula/.test(n))
        return "Nebula";
    if (/^(ipsec|vti)/.test(n))
        return "IPsec";
    if (/^ppp/.test(n))
        return "PPP";
    for (var i = 0; i < VPN_DAEMONS.length; i++)
        if (has(VPN_DAEMONS[i][0]) && !/Tailscale|ZeroTier|NetBird/.test(VPN_DAEMONS[i][1]))
            return VPN_DAEMONS[i][1] + (/^wg/.test(n) ? " (WireGuard)" : /^tun|^tap/.test(n) ? " (OpenVPN)" : "");
    if (/^wg/.test(n))
        return "WireGuard";
    if (/^(tun|tap)/.test(n))
        return "OpenVPN / tunnel";
    return "VPN";
}

// Local address → interface, from the details (CIDR stripped).
function addressIndex(interfaces, details) {
    var out = {};
    (interfaces || []).forEach(function (i) {
        if (i.ip)
            out[i.ip] = i.name;
    });
    for (var n in details || {})
        details[n].ipv4.concat(details[n].ipv6).forEach(function (a) { out[a.split("/")[0]] = n; });
    return out;
}

// → [{ iface, provider, up, ip, conns (internet connections through it),
//      of (internet connections in all), direct [app names outside it] }]
function vpnInfo(interfaces, details, tree, connections) {
    var daemons = [];
    for (var pid in tree || {})
        if (daemons.indexOf(tree[pid].name) === -1)
            daemons.push(tree[pid].name);
    var internet = (connections || []).filter(function (c) { return !c.ended && c.kind === "internet"; });
    var list = (interfaces || []).filter(function (i) { return i.kind === "vpn"; }).map(function (i) {
        var through = internet.filter(function (c) { return c.via === i.name; });
        var direct = [];
        internet.forEach(function (c) {
            if (c.via && c.via !== i.name && direct.indexOf(c.app.name) === -1)
                direct.push(c.app.name);
        });
        var d = details && details[i.name];
        return { iface: i.name, provider: vpnProvider(i.name, daemons), up: i.up, ip: d && d.ipv4.length ? d.ipv4[0] : i.ip, conns: through.length, of: internet.length, direct: direct };
    });
    return list;
}

// ── Firewall (read-only) ─────────────────────────────────────────────────────
// What protects the open ports, as far as a normal user may look: which
// firewall runs, firewalld's zone (its D-Bus queries need no password on a
// desktop session), and on NixOS the allowed ports from the generated
// firewall script in the (world-readable) store. ufw, plain nftables and
// iptables keep their rules for root: Glassy says so and never asks.
var FIREWALL_CMD = "for u in firewalld ufw nftables iptables firewall; do echo \"unit $u $(systemctl is-active $u 2>/dev/null)\"; done; "
    + "if [ \"$(systemctl is-active firewalld 2>/dev/null)\" = active ] && command -v firewall-cmd >/dev/null 2>&1; then "
    + "z=$(timeout 3 firewall-cmd --get-default-zone 2>/dev/null </dev/null); echo \"zone $z\"; "
    + "echo \"services $(timeout 3 firewall-cmd --zone=\"$z\" --list-services 2>/dev/null </dev/null)\"; "
    + "echo \"ports $(timeout 3 firewall-cmd --zone=\"$z\" --list-ports 2>/dev/null </dev/null)\"; fi; "
    + "if [ -e /etc/NIXOS ]; then echo nixos; for u in firewall nftables; do x=$(systemctl show -p ExecStart --value $u.service 2>/dev/null | grep -o '/nix/store/[^ ;]*' | head -1); "
    + "[ -n \"$x\" ] || continue; for f in \"$x\" $(grep -o '/nix/store/[^ \"]*' \"$x\" 2>/dev/null | sort -u | head -30); do [ -f \"$f\" ] || continue; "
    + "grep -o -E -e '-p (tcp|udp) (-m (tcp|udp) )?--dport [0-9:]+' -e '(tcp|udp) dport (\\{[^}]*\\}|[0-9-]+)' \"$f\" 2>/dev/null; done; done; fi";

// Ports of firewalld's common services.
var FIREWALLD_SERVICES = { ssh: [["tcp", 22]], http: [["tcp", 80]], https: [["tcp", 443]], mdns: [["udp", 5353]], "dhcpv6-client": [["udp", 546]],
    kdeconnect: [["tcp", 1714, 1764], ["udp", 1714, 1764]], "samba-client": [["udp", 137, 138]], samba: [["tcp", 139], ["tcp", 445], ["udp", 137, 138]],
    cockpit: [["tcp", 9090]], syncthing: [["tcp", 22000], ["udp", 22000], ["udp", 21027]], "syncthing-gui": [["tcp", 8384]], ipp: [["tcp", 631]], "ipp-client": [["udp", 631]],
    dns: [["tcp", 53], ["udp", 53]], "steam-streaming": [["udp", 27031, 27036], ["tcp", 27036, 27037]], spotify: [["tcp", 57621], ["udp", 57621]] };

// → { kind: "firewalld" | "nixos" | "ufw" | "nftables" | "iptables" | "none",
//     readable (rules known), zone, services [], ports [{ proto, from, to }] }
function parseFirewall(text) {
    var units = {}, out = { kind: "none", readable: false, zone: "", services: [], ports: [] };
    var nixos = false;
    var addPort = function (proto, spec) {
        String(spec).split(/[,\s]+/).forEach(function (p) {
            var r = p.replace(/[{}]/g, "").split(/[:-]/).map(Number);
            if (r[0] > 0)
                out.ports.push({ proto: proto, from: r[0], to: r[1] > 0 ? r[1] : r[0] });
        });
    };
    String(text || "").split("\n").forEach(function (line) {
        var m;
        if ((m = /^unit (\S+) (\S*)/.exec(line)))
            units[m[1]] = m[2] === "active";
        else if ((m = /^zone (\S*)/.exec(line)))
            out.zone = m[1];
        else if ((m = /^services (.*)$/.exec(line)))
            out.services = m[1].trim().split(/\s+/).filter(Boolean);
        else if ((m = /^ports (.*)$/.exec(line)))
            m[1].trim().split(/\s+/).filter(Boolean).forEach(function (p) {
                var q = p.split("/");
                addPort(q[1] || "tcp", q[0]);
            });
        else if (line.trim() === "nixos")
            nixos = true;
        else if ((m = /-p (tcp|udp) (?:-m (?:tcp|udp) )?--dport ([0-9:]+)/.exec(line)))
            addPort(m[1], m[2]);
        else if ((m = /(tcp|udp) dport (\{[^}]*\}|[0-9-]+)/.exec(line)))
            addPort(m[1], m[2]);
    });
    if (units.firewalld) {
        out.kind = "firewalld";
        out.readable = out.zone !== "";
        out.services.forEach(function (svc) {
            (FIREWALLD_SERVICES[svc] || []).forEach(function (p) { out.ports.push({ proto: p[0], from: p[1], to: p[2] || p[1] }); });
        });
    } else if (nixos && (units.firewall || units.nftables)) {
        out.kind = "nixos";
        out.readable = true;
    } else if (units.ufw) {
        out.kind = "ufw";
    } else if (units.nftables) {
        out.kind = "nftables";
    } else if (units.iptables) {
        out.kind = "iptables";
    }
    return out;
}

// "allowed", "blocked" or "" (rules not readable, or no firewall: "open").
function firewallVerdict(fw, proto, port) {
    if (!fw || fw.kind === "none")
        return "open";
    if (!fw.readable)
        return "";
    var n = Number(port);
    return fw.ports.some(function (p) { return p.proto === proto && n >= p.from && n <= p.to; }) ? "allowed" : "blocked";
}

// ── Route ────────────────────────────────────────────────────────────────────
// A quick route to one address, without root: tracepath, else traceroute
// (UDP), else mtr; about 20 hops, a second each at most.
function traceCmd(ip) {
    if (!safeIp(ip))
        return "echo bad address";
    return "if command -v tracepath >/dev/null 2>&1; then timeout 30 tracepath -n -m 20 " + ip + "; "
        + "elif command -v traceroute >/dev/null 2>&1; then timeout 30 traceroute -n -q 1 -w 1 -m 20 " + ip + "; "
        + "elif command -v mtr >/dev/null 2>&1; then timeout 30 mtr -n -r -c 1 " + ip + "; else echo 'none: install iputils (tracepath) or traceroute'; fi 2>&1";
}

// → [{ hop, ip, ms }] (ip "" for a silent hop); lines of any of the three tools.
function parseTrace(text) {
    var hops = {}, order = [];
    String(text || "").split("\n").forEach(function (line) {
        var m = /^\s*(\d+)[?:.]?(?:\|--)?\s+(.*)$/.exec(line);
        if (!m)
            return;
        var hop = Number(m[1]), rest = m[2];
        if (/^(Resume|pmtu|Too many)/i.test(rest))
            return;
        var ip = (/([0-9]{1,3}(?:\.[0-9]{1,3}){3}|[0-9a-f]*:[0-9a-f:]+)/i.exec(rest) || [""])[0];
        if (ip.indexOf(":") !== -1 && ip.replace(/:/g, "").length < 2)
            ip = "";
        var ms = /([0-9.]+)\s*ms/.exec(rest);
        if (!hops[hop]) {
            hops[hop] = { hop: hop, ip: ip, ms: ms ? Number(ms[1]) : -1 };
            order.push(hop);
        } else if (!hops[hop].ip && ip) {
            hops[hop].ip = ip;
            hops[hop].ms = ms ? Number(ms[1]) : hops[hop].ms;
        }
    });
    return order.map(function (h) { return hops[h]; });
}
