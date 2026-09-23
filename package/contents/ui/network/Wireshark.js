.pragma library
.import "../Probes.js" as Probes

// Wireshark and tshark, when installed. Glassy itself never captures: it
// opens Wireshark on the right interface with a capture filter, or runs
// tshark for a few seconds when asked, to learn the names behind addresses
// from DNS answers and TLS / QUIC server names (SNI). Capturing needs the
// user's own permission (the wireshark group); nothing asks for a password.

var TOOLS_CMD = "for t in wireshark tshark; do command -v $t >/dev/null 2>&1 && echo $t; done; "
    + "command -v flatpak >/dev/null 2>&1 && flatpak info org.wireshark.Wireshark >/dev/null 2>&1 && echo flatpak; true";

// → { wireshark, tshark, flatpak }: Wireshark opens natively or as the Flatpak.
function parseTools(text) {
    var lines = String(text || "").split("\n").map(function (l) { return l.trim(); });
    return {
        wireshark: lines.indexOf("wireshark") !== -1 || lines.indexOf("flatpak") !== -1,
        tshark: lines.indexOf("tshark") !== -1,
        flatpak: lines.indexOf("wireshark") === -1 && lines.indexOf("flatpak") !== -1
    };
}

// Only what a filter or an interface name can hold reaches the shell.
var safeIp = Probes.safeIp;
function safePort(port) {
    return /^[0-9]{1,5}$/.test(String(port || "")) && Number(port) > 0 && Number(port) < 65536;
}
function safeIface(name) {
    return /^[A-Za-z0-9_.:@-]{1,15}$/.test(String(name || ""));
}

// The interface a connection uses: its link, loopback, or all of them.
function ifaceOf(c) {
    if (!c)
        return "any";
    if (c.kind === "loopback")
        return "lo";
    return safeIface(c.via) ? c.via : "any";
}
// One interface when every connection shares it, otherwise all.
function commonIface(conns) {
    var ifs = {};
    (conns || []).forEach(function (c) { ifs[ifaceOf(c)] = true; });
    var names = Object.keys(ifs);
    return names.length === 1 ? names[0] : "any";
}

// BPF for one connection: both ends, both ports.
function connFilter(c) {
    if (!c || !safeIp(c.ip) || !safePort(c.port))
        return "";
    var proto = c.proto === "udp" ? "udp" : "tcp";
    var f = proto + " and host " + c.ip + " and port " + c.port;
    if (safeIp(c.localIp) && c.localIp !== "0.0.0.0" && c.localIp !== "::")
        f += " and host " + c.localIp;
    if (safePort(c.localPort))
        f += " and port " + c.localPort;
    return f;
}

// BPF for an app's live connections: every remote end (proto, address,
// port), at most `max`; beyond that the addresses alone.
function connectionsFilter(conns, max) {
    max = max || 24;
    var ends = [], seen = {}, ips = [];
    (conns || []).forEach(function (c) {
        if (c.ended || !safeIp(c.ip) || !safePort(c.port))
            return;
        var proto = c.proto === "udp" ? "udp" : "tcp";
        var key = proto + " " + c.ip + " " + c.port;
        if (!seen[key]) {
            seen[key] = true;
            ends.push("(" + proto + " and host " + c.ip + " and port " + c.port + ")");
        }
        if (ips.indexOf(c.ip) === -1)
            ips.push(c.ip);
    });
    if (ends.length <= max)
        return ends.join(" or ");
    return ips.slice(0, max).map(function (ip) { return "host " + ip; }).join(" or ");
}

function portFilter(proto, port) {
    return safePort(port) ? (proto === "udp" ? "udp" : "tcp") + " port " + port : "";
}

// A container's addresses on its networks.
function hostsFilter(ips) {
    return (ips || []).filter(safeIp).map(function (ip) { return "host " + ip; }).join(" or ");
}

// Wireshark in its own session, so it outlives the widget's shell and the
// command returns at once.
function launchCmd(tools, iface, filter) {
    var args = " -k -i " + (safeIface(iface) ? iface : "any") + (filter ? " -f \"" + String(filter).replace(/[^A-Za-z0-9 .:()]/g, "") + "\"" : "");
    var app = tools && tools.flatpak ? "flatpak run org.wireshark.Wireshark" : "wireshark";
    return "S=; command -v setsid >/dev/null 2>&1 && S=setsid; ($S " + app + args + " </dev/null >/dev/null 2>&1 &)";
}

// ── Learning names with tshark ───────────────────────────────────────────────
// Plain DNS (the local resolver's answers on lo too) and TLS / QUIC client
// hellos, for `seconds`; only names and addresses are printed, nothing of
// the payload is kept.
var SNIFF_FILTER = "port 53 or tcp port 443 or udp port 443 or port 5353";
var SNIFF_DISPLAY = "dns.flags.response == 1 or tls.handshake.extensions_server_name";

function sniffCmd(seconds) {
    var s = Math.max(2, Math.min(60, Math.round(Number(seconds) || 10)));
    return "command -v tshark >/dev/null 2>&1 || { echo 'missing: tshark' >&2; exit 127; }; "
        + "timeout " + (s + 8) + " tshark -n -l -i any -a duration:" + s
        + " -f \"" + SNIFF_FILTER + "\" -Y \"" + SNIFF_DISPLAY + "\""
        + " -T fields -E separator=/t -E occurrence=a -E aggregator=,"
        + " -e ip.dst -e ipv6.dst -e dns.qry.name -e dns.a -e dns.aaaa -e tls.handshake.extensions_server_name";
}

function cleanName(name) {
    var n = String(name || "").trim().toLowerCase().replace(/\.$/, "");
    return /^[a-z0-9_.-]{1,253}$/.test(n) && n.indexOf(".") > 0 ? n : "";
}

// tshark's fields → { names: { ip: { name, source: "dns" | "tls" } },
// dns: answers seen, tls: hellos seen }. A server name beats a DNS answer:
// it is the name the app asked that very server for.
function parseSniff(text) {
    var out = { names: {}, dns: 0, tls: 0 };
    String(text || "").split("\n").forEach(function (line) {
        var f = line.split("\t");
        if (f.length < 6)
            return;
        var sni = cleanName(f[5].split(",")[0]);
        if (sni) {
            var dst = safeIp(f[0]) ? f[0] : safeIp(f[1]) ? f[1] : "";
            if (dst) {
                out.tls++;
                out.names[dst] = { name: sni, source: "tls" };
            }
            return;
        }
        var q = cleanName(f[2].split(",")[0]);
        if (!q)
            return;
        var addrs = (f[3] ? f[3].split(",") : []).concat(f[4] ? f[4].split(",") : []).filter(safeIp);
        if (addrs.length)
            out.dns++;
        addrs.forEach(function (ip) {
            if (!out.names[ip] || out.names[ip].source !== "tls")
                out.names[ip] = { name: q, source: "dns" };
        });
    });
    return out;
}

// What went wrong, in words, or "" when the capture ran.
function sniffError(stderr, code) {
    var e = String(stderr || "");
    if (/missing: tshark/.test(e) || code === 127)
        return "missing";
    if (/permission|CAP_NET_RAW|Operation not permitted|couldn't run .*dumpcap/i.test(e))
        return "permission";
    if (code && code !== 124) {
        var line = e.split("\n").filter(function (l) { return l.trim() && !/^Capturing on/.test(l); })[0];
        return line ? line.trim() : "tshark stopped (exit " + code + ")";
    }
    return "";
}

var PERMISSION_HELP = "Capturing needs permission, and Glassy never asks for a password. Add yourself to the wireshark group "
    + "(sudo usermod -aG wireshark $USER, then log in again; on NixOS: programs.wireshark.enable = true and the group), "
    + "or on Debian and Ubuntu: sudo dpkg-reconfigure wireshark-common.";
var INSTALL_HELP = "tshark comes with Wireshark: pacman -S wireshark-cli · apt install tshark · dnf install wireshark-cli · "
    + "NixOS: programs.wireshark.enable = true";
