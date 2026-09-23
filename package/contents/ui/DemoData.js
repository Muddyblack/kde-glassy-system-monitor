.pragma library

// Plausible, always-moving readings for demos: the studio's Demo preview,
// the gallery screenshots and the website studio all draw from this.

function wave(phase, base, swing) {
    return Math.max(0, base + swing * Math.sin(phase) + swing * 0.35 * Math.sin(phase * 2.7 + 1));
}

// Everything the demo shows at step `i`.
function readings(i) {
    var cores = [];
    for (var c = 0; c < 8; c++)
        cores.push(Math.min(100, wave(i / 4 + c, 30 + c * 3, 18 + (c % 3) * 6)));
    return {
        cpu: cores.reduce(function (a, b) { return a + b; }, 0) / cores.length,
        cores: cores,
        mem: 54 + 6 * Math.sin(i / 20),
        swap: 8 + 2 * Math.sin(i / 30),
        dl: wave(i / 3, 2.4e6, 2e6) * (i % 23 > 17 ? 3 : 1),
        ul: wave(i / 5 + 2, 3e5, 2.4e5),
        rd: wave(i / 2.5, 6e6, 5e6) * (i % 11 > 7 ? 4 : 0.3),
        wr: wave(i / 3.2 + 1, 3e6, 2.5e6) * (i % 13 > 9 ? 3 : 0.4),
        ping: i % 29 === 14 ? -1 : wave(i / 3, 22, 6) + (i % 40 > 33 ? 60 : 0),
        gpu: Math.min(100, wave(i / 6, 46, 30)),
        custom: wave(i / 8, 1.6, 0.9),
        watts: wave(i / 7, 11, 4)
    };
}

var MEM_TOTAL = 32 * 1073741824;
var SWAP_TOTAL = 8 * 1073741824;

var SENSORS = [
    { chip: "k10temp", chipDisplay: "CPU (AMD)", maxTemp: 62, maxTempCrit: 95, sensors: [{ label: "Tctl", value: 62, crit: 95, type: "temp" }] },
    { chip: "amdgpu", chipDisplay: "GPU (AMD)", maxTemp: 54, maxTempCrit: 100, sensors: [{ label: "edge", value: 54, crit: 100, type: "temp" }, { label: "fan1", value: 1180, type: "fan" }] },
    { chip: "nvme", chipDisplay: "NVMe SSD", maxTemp: 41, maxTempCrit: 85, sensors: [{ label: "Composite", value: 41, crit: 85, type: "temp" }] }
];

var SYSTEM = { distro: "NixOS 26.05", kernel: "7.2.4", hostname: "glassbox", uptime: "3h 12m" };
var BATTERY = { percent: 76, status: "Discharging", health: 94, cycles: 212, temp: 31, hours: 4.6 };

// `df -B1 -P -T` as Probes.STORAGE_CMD prints it: a btrfs root with a
// subvolume on /home (one row), a data disk, a USB stick and a small /boot
// (dropped by the 256 MiB floor).
var DF = [
    "Filesystem     Type     1-blocks          Used     Available Capacity Mounted on",
    "/dev/nvme0n1p2 btrfs    1998694907904 1215130124288 781453598720 61% /",
    "/dev/nvme0n1p2 btrfs    1998694907904 1215130124288 781453598720 61% /home",
    "/dev/nvme0n1p1 vfat     104857600     31457280      73400320     30% /boot",
    "/dev/sda1      ext4     3936818806784 3521377894400 415440912384 90% /mnt/data",
    "/dev/sdb1      exfat    63999836160   61439868928   2559967232   97% /run/media/usb"
].join("\n");

// Programs for the top-processes demo: [name, helper processes, CPU share of
// one core at rest, swing, resident MiB each].
var PROGRAMS = [
    ["firefox", 9, 1.20, 0.80, 380],
    ["plasmashell", 1, 0.30, 0.20, 520],
    ["kwin_wayland", 1, 0.45, 0.30, 310],
    ["code", 6, 0.70, 0.60, 290],
    ["steam", 3, 0.15, 0.10, 250],
    ["pipewire", 1, 0.10, 0.05, 40],
    ["node", 2, 0.40, 0.90, 210],
    ["systemd", 1, 0.00, 0.00, 18],
    ["dolphin", 1, 0.05, 0.05, 140],
    ["konsole", 2, 0.04, 0.03, 90],
    ["kded6", 1, 0.03, 0.03, 70],
    ["Xwayland", 1, 0.06, 0.05, 110]
];

// A /proc snapshot at step `i`, shaped like Probes.parseProcSnapshot's result
// (8 cores, 100 jiffies per core-second). CPU ticks only ever grow.
function procSnapshot(i) {
    var procs = {}, pid = 1000;
    PROGRAMS.forEach(function (p, k) {
        for (var h = 0; h < p[1]; h++) {
            var share = p[2] / p[1], swing = p[3] / p[1];
            var ticks = 100 * (share * i + swing * 0.9 * Math.sin(i / 3 + k + h));
            procs[pid++] = { name: p[0], ticks: Math.max(0, Math.round(ticks + 1e6)), rss: Math.round(p[4] * (h ? 0.45 : 1) * 1048576) };
        }
    });
    return { total: 800 * i, memTotal: MEM_TOTAL, procs: procs };
}

// ── Network window ───────────────────────────────────────────────────────────
// A desktop's sockets at step `i`, as `ss -tunapiH` prints them, so the demo
// runs through the real parsers. [proto, local, remote, process, pid, KiB/s
// in, KiB/s out, alive from step, alive until step (0 = always)].
var NET_LOCAL = "192.168.1.23";
var NET_CONNS = [
    ["tcp", NET_LOCAL + ":48212", "140.82.121.4:443", "firefox", 2211, 6, 1, 0, 0],
    ["tcp", NET_LOCAL + ":48230", "151.101.1.140:443", "Isolated Web Co", 2290, 180, 6, 0, 0],
    ["udp", NET_LOCAL + ":51734", "142.250.185.78:443", "Socket Process", 2301, 0, 0, 0, 0],
    ["tcp", "[2a02:8108:1c0:3e00::23]:40310", "[2a00:1450:4001:82b::200e]:443", "Isolated Web Co", 2291, 420, 12, 0, 0],
    ["tcp", NET_LOCAL + ":48302", "104.16.132.229:443", "Isolated Web Co", 2290, 30, 3, 4, 40],
    ["tcp", NET_LOCAL + ":48344", "185.199.108.153:443", "firefox", 2211, 12, 1, 10, 0],
    ["tcp", NET_LOCAL + ":52110", "162.159.130.234:443", "Discord", 3120, 8, 2, 0, 0],
    ["tcp", NET_LOCAL + ":52188", "162.159.135.232:443", "Discord", 3120, 2, 1, 0, 0],
    ["udp", NET_LOCAL + ":50001", "66.22.196.12:50007", "Discord", 3144, 0, 0, 0, 0],
    ["tcp", NET_LOCAL + ":39012", "155.133.248.39:27033", "steam", 2870, 3, 1, 0, 0],
    ["tcp", NET_LOCAL + ":39044", "23.215.130.70:443", "steamwebhelper", 2910, 900, 8, 0, 30],
    ["tcp", NET_LOCAL + ":41220", "35.186.224.25:443", "spotify", 3310, 40, 2, 0, 0],
    ["tcp", NET_LOCAL + ":22000", "192.168.1.40:51820", "syncthing", 1880, 55, 70, 0, 0],
    ["tcp", NET_LOCAL + ":44012", "20.189.173.10:443", "code", 4102, 1, 1, 0, 0],
    ["tcp", NET_LOCAL + ":44080", "140.82.113.21:443", "code", 4120, 4, 2, 0, 0],
    ["tcp", NET_LOCAL + ":56002", "192.168.1.10:22", "ssh", 5120, 1, 1, 0, 0],
    ["tcp", NET_LOCAL + ":1716", "192.168.1.51:43210", "kdeconnectd", 1702, 1, 1, 0, 0],
    ["udp", NET_LOCAL + "%wlp2s0:68", "192.168.1.1:67", "", 0, 0, 0, 0, 0],
    ["tcp", "127.0.0.1:48888", "127.0.0.1:5173", "firefox", 2211, 20, 2, 0, 0],
    ["tcp", NET_LOCAL + ":45510", "91.189.91.49:80", "", 0, 0, 0, 0, 0],
    ["tcp", "10.8.0.2:51022", "104.18.27.120:443", "Isolated Web Co", 2290, 60, 4, 0, 0],
    ["tcp", "10.8.0.2:51040", "146.75.121.140:443", "spotify", 3310, 25, 1, 0, 0]
];
var NET_LISTEN = [
    ["tcp", "0.0.0.0:22", "", 0],
    ["tcp", "[::]:22", "", 0],
    ["tcp", "127.0.0.1:631", "", 0],
    ["tcp", "0.0.0.0:22000", "syncthing", 1880],
    ["tcp", "127.0.0.1:8384", "syncthing", 1880],
    ["udp", "0.0.0.0:21027", "syncthing", 1880],
    ["tcp", "*:1716", "kdeconnectd", 1702],
    ["udp", "*:1716", "kdeconnectd", 1702],
    ["tcp", "127.0.0.1:5173", "node", 4410],
    ["udp", "0.0.0.0:57621", "spotify", 3310],
    ["udp", "0.0.0.0:5353", "", 0],
    ["udp", "127.0.0.54:53", "", 0],
    ["tcp", "127.0.0.53%lo:53", "", 0],
    ["tcp", "0.0.0.0:8080", "", 0],
    ["tcp", "[::]:8080", "", 0],
    ["tcp", "127.0.0.1:5432", "", 0],
    ["tcp", "127.0.0.1:6379", "rootlessport", 5900]
];
// [pid, ppid, name]
var NET_PROCS = [
    [1, 0, "systemd"], [1400, 1, "systemd"], [1500, 1400, "plasmashell"], [1702, 1400, "kdeconnectd"], [1880, 1400, "syncthing"],
    [2211, 1500, "firefox"], [2290, 2211, "Isolated Web Co"], [2291, 2211, "Isolated Web Co"], [2301, 2211, "Socket Process"],
    [2870, 1500, "steam"], [2910, 2870, "steamwebhelper"], [3120, 1500, "Discord"], [3144, 3120, "Discord"], [3310, 1500, "spotify"],
    [4102, 1500, "code"], [4120, 4102, "code"], [4400, 1500, "konsole"], [4401, 4400, "zsh"], [4410, 4401, "node"], [5120, 4401, "ssh"], [980, 1, "mullvad-daemon"]
];

function netSs(i) {
    var lines = [];
    NET_LISTEN.forEach(function (l) {
        var users = l[2] ? " users:((\"" + l[2] + "\",pid=" + l[3] + ",fd=12))" : "";
        var peer = l[1].charAt(0) === "[" ? "[::]:*" : "0.0.0.0:*";
        lines.push(l[0] + " " + (l[0] === "tcp" ? "LISTEN" : "UNCONN") + " 0      4096   " + l[1] + " " + peer + users);
        if (l[0] === "tcp")
            lines.push("\t cubic cwnd:10");
    });
    NET_CONNS.forEach(function (c, k) {
        if (i < c[7] || (c[8] && i >= c[8]))
            return;
        var age = Math.max(1, i - c[7] + 20);
        var inRate = c[5] * 1024 * (0.6 + 0.4 * Math.sin(i / 3 + k)), outRate = c[6] * 1024 * (0.7 + 0.3 * Math.cos(i / 4 + k));
        var users = c[3] ? " users:((\"" + c[3] + "\",pid=" + c[4] + ",fd=" + (40 + k) + "))" : "";
        lines.push(c[0] + " ESTAB  0      0      " + c[1] + " " + c[2] + users);
        if (c[0] === "tcp" && c[3])
            lines.push("\t cubic wscale:7,7 rto:204 rtt:" + (12 + k * 3.1 + 5 * Math.abs(Math.sin(i / 2 + k))).toFixed(3) + "/2.4 ato:40 mss:1448 pmtu:1500 rcvmss:1448 advmss:1448 cwnd:" + (10 + k)
                + " bytes_sent:" + Math.round(age * c[6] * 1024 + outRate) + " bytes_acked:" + Math.round(age * c[6] * 1024 + outRate)
                + " bytes_received:" + Math.round(age * c[5] * 1024 + inRate) + " segs_out:" + (age * 4) + " segs_in:" + (age * 6) + " send 5.24Mbps lastsnd:120 lastrcv:80");
    });
    return lines.join("\n");
}

function netProcStat() {
    return NET_PROCS.map(function (p) { return p[0] + " (" + p[2] + ") S " + p[1] + " " + p[0] + " 0 0 -1 4194560 0 0 0 0 0 0 0 0 20 0 1 0 100 0 0"; }).join("\n");
}

// Everything CONNECTIONS_CMD prints at step `i` (1 s per step).
function netPoll(i) {
    var rx = Math.round(i * 2.4e6 + 3e9), tx = Math.round(i * 1.8e5 + 4e8);
    return netSs(i) + "\n@@proc\n" + netProcStat() + "\n@@dev\n"
        + "Inter-|   Receive                                                |  Transmit\n"
        + " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
        + "    lo: 91234 812 0 0 0 0 0 0 91234 812 0 0 0 0 0 0\n"
        + "wlp2s0: " + Math.round(rx + 2e6 * Math.sin(i / 3)) + " 1 0 0 0 0 0 0 " + Math.round(tx + 1.2e5 * Math.cos(i / 4)) + " 1 0 0 0 0 0 0\n"
        + "enp5s0: 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0\n"
        + "wg0: " + Math.round(i * 2e4) + " 1 0 0 0 0 0 0 " + Math.round(i * 1e4) + " 1 0 0 0 0 0 0";
}

var NET_DESKTOP = [
    "@ org.mozilla.firefox.desktop", "Name=Firefox", "Icon=firefox", "Exec=firefox %u", "StartupWMClass=firefox",
    "@ steam.desktop", "Name=Steam", "Icon=steam", "Exec=/usr/bin/steam %U",
    "@ discord.desktop", "Name=Discord", "Icon=discord", "Exec=/usr/bin/Discord", "StartupWMClass=discord",
    "@ spotify.desktop", "Name=Spotify", "Icon=spotify-client", "Exec=spotify %U",
    "@ syncthing-start.desktop", "Name=Syncthing", "Icon=syncthing", "Exec=/usr/bin/syncthing serve --no-browser",
    "@ code.desktop", "Name=Visual Studio Code", "Icon=vscode", "Exec=/usr/share/code/code --unity-launch %F",
    "@ org.kde.kdeconnect.daemon.desktop", "Name=KDE Connect", "Icon=kdeconnect", "Exec=/usr/lib/kdeconnectd", "NoDisplay=true",
    "@ org.kde.konsole.desktop", "Name=Konsole", "Icon=utilities-terminal", "Exec=konsole"
].join("\n");

// Reverse DNS, country and owner, as a local GeoIP database would give them.
var NET_HOSTS = {
    "140.82.121.4": { name: "lb-140-82-121-4-fra.github.com", country: "DE", asn: 36459, org: "GITHUB" },
    "151.101.1.140": { name: "reddit.map.fastly.net", country: "US", asn: 54113, org: "FASTLY" },
    "142.250.185.78": { name: "fra16s48-in-f14.1e100.net", country: "DE", asn: 15169, org: "GOOGLE" },
    "2a00:1450:4001:82b::200e": { name: "fra24s06-in-x0e.1e100.net", country: "DE", asn: 15169, org: "GOOGLE" },
    "104.16.132.229": { name: "", country: "US", asn: 13335, org: "CLOUDFLARENET" },
    "185.199.108.153": { name: "cdn-185-199-108-153.github.com", country: "NL", asn: 54113, org: "FASTLY" },
    "162.159.130.234": { name: "", country: "US", asn: 13335, org: "CLOUDFLARENET" },
    "162.159.135.232": { name: "", country: "US", asn: 13335, org: "CLOUDFLARENET" },
    "66.22.196.12": { name: "", country: "DE", asn: 49544, org: "i3D.net B.V" },
    "155.133.248.39": { name: "", country: "AT", asn: 32590, org: "Valve Corporation" },
    "23.215.130.70": { name: "a23-215-130-70.deploy.static.akamaitechnologies.com", country: "NL", asn: 20940, org: "Akamai International B.V." },
    "35.186.224.25": { name: "25.224.186.35.bc.googleusercontent.com", country: "US", asn: 396982, org: "GOOGLE-CLOUD-PLATFORM" },
    "20.189.173.10": { name: "", country: "US", asn: 8075, org: "MICROSOFT-CORP-MSN-AS-BLOCK" },
    "140.82.113.21": { name: "lb-140-82-113-21-iad.github.com", country: "US", asn: 36459, org: "GITHUB" },
    "91.189.91.49": { name: "archive.ubuntu.com", country: "GB", asn: 41231, org: "Canonical Group Limited" },
    "192.168.1.10": { name: "nas.lan", country: "", asn: 0, org: "" },
    "192.168.1.40": { name: "desktop.lan", country: "", asn: 0, org: "" },
    "192.168.1.51": { name: "pixel-8.lan", country: "", asn: 0, org: "" },
    "192.168.1.1": { name: "fritz.box", country: "", asn: 0, org: "" },
    "104.18.27.120": { name: "", country: "US", asn: 13335, org: "CLOUDFLARENET" },
    "146.75.121.140": { name: "", country: "SE", asn: 54113, org: "FASTLY" }
};

// What Wireshark.sniffCmd() prints for ten seconds of traffic: DNS answers
// (from the local resolver on lo) and TLS / QUIC server names.
var NET_CAPTURE = [
    "127.0.0.1\t\tdiscord.com\t162.159.130.234,162.159.135.232\t\t",
    "127.0.0.1\t\twww.youtube.com\t142.250.185.78\t2a00:1450:4001:82b::200e\t",
    "162.159.135.232\t\t\t\t\tgateway.discord.gg",
    "104.16.132.229\t\t\t\t\tcdn.jsdelivr.net",
    "127.0.0.1\t\tcdn.jsdelivr.net\t104.16.132.229\t\t",
    "20.189.173.10\t\t\t\t\tmobile.events.data.microsoft.com",
    "127.0.0.1\t\tsteamcdn-a.akamaihd.net\t\t\t",
    "146.75.121.140\t\t\t\t\ti.redd.it"
].join("\n");

// What Probes.INTERFACES_CMD and IFACE_DETAILS_CMD print.
var NET_INTERFACES = [
    "if wlp2s0 up wifi 3c:a6:2f:9a:10:42 -",
    "if enp5s0 down ethernet 04:42:1a:0e:33:7c -",
    "if wg0 unknown vpn - -",
    "if docker0 down virtual 02:42:5c:11:aa:01 -",
    "ip wlp2s0 192.168.1.23/24",
    "ip wg0 10.8.0.2/32",
    "ip docker0 172.17.0.1/16",
    "route wlp2s0 600"
].join("\n");
var NET_IFACE_DETAILS = [
    "3: wlp2s0    inet 192.168.1.23/24 brd 192.168.1.255 scope global dynamic noprefixroute wlp2s0\\       valid_lft 80000sec preferred_lft 80000sec",
    "3: wlp2s0    inet6 2a02:8108:1c0:3e00::23/128 scope global dynamic noprefixroute \\       valid_lft 7000sec preferred_lft 3000sec",
    "3: wlp2s0    inet6 fe80::3ea6:2fff:fe9a:1042/64 scope link noprefixroute \\       valid_lft forever preferred_lft forever",
    "5: wg0    inet 10.8.0.2/32 scope global wg0\\       valid_lft forever preferred_lft forever",
    "6: docker0    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0\\       valid_lft forever preferred_lft forever",
    "@@route",
    "default via 192.168.1.1 dev wlp2s0 proto dhcp src 192.168.1.23 metric 600",
    "default via fe80::1 dev wlp2s0 proto ra metric 600 pref medium",
    "@@dns",
    "Global:",
    "Link 2 (enp5s0):",
    "Link 3 (wlp2s0): 192.168.1.1 fd00::1",
    "Link 5 (wg0): 10.8.0.1",
    "@@wifi",
    "iface wlp2s0",
    "Connected to 3c:a6:2f:11:22:33 (on wlp2s0)",
    "\tSSID: Lighthouse",
    "\tfreq: 5180",
    "\tRX: 2918342 bytes (4012 packets)",
    "\tTX: 402113 bytes (1920 packets)",
    "\tsignal: -52 dBm",
    "\trx bitrate: 866.7 MBit/s VHT-MCS 9 80MHz short GI VHT-NSS 2",
    "\ttx bitrate: 780.0 MBit/s VHT-MCS 8 80MHz short GI VHT-NSS 2"
].join("\n");
var NET_DNS = [
    "DNSSEC supported by current servers: no",
    "",
    "Transactions",
    "Current Transactions: 0",
    "  Total Transactions: 12838",
    "",
    "Cache",
    "  Current Cache Size: 245",
    "          Cache Hits: 3431",
    "        Cache Misses: 9402",
    "@@servers",
    "Global:",
    "Link 3 (wlp2s0): 192.168.1.1 fd00::1",
    "Link 5 (wg0): 10.8.0.1"
].join("\n");

// Open browser tabs and their addresses (BrowserTabs.siteIndex).
var NET_TABS = [
    { host: "www.reddit.com", title: "r/kde – the KDE community", browser: "Firefox" },
    { host: "github.com", title: "Muddyblack/kde-glassy-system-monitor", browser: "Firefox" },
    { host: "www.youtube.com", title: "lofi beats to code to", browser: "Firefox" }
];
var NET_TAB_ADDRESSES = {
    "www.reddit.com": ["151.101.1.140"],
    "github.com": ["140.82.121.4", "185.199.108.153"],
    "www.youtube.com": ["142.250.185.78", "2a00:1450:4001:82b::200e"]
};

// About fourteen months of NetHistory in its file format, ending the day of
// `now`; days beyond two months are compact (no hours), like real ones.
function netHistory(now) {
    var apps = [["app:org.mozilla.firefox", "Firefox", "firefox", 1.6e9], ["app:steam", "Steam", "steam", 2.4e9], ["app:spotify", "Spotify", "spotify-client", 3.1e8],
        ["app:discord", "Discord", "discord", 2.2e8], ["app:syncthing-start", "Syncthing", "syncthing", 4.4e8], ["app:code", "Visual Studio Code", "vscode", 9e7], ["proc:ssh", "ssh", "ssh", 2e7]];
    var domains = [["youtube.com", 9e8], ["reddit.com", 2.1e8], ["github.com", 1.2e8], ["steamcontent.com", 2.2e9], ["spotify.com", 3e8], ["discord.gg", 2e8], ["desktop.lan", 4e8]];
    var countries = [["DE", 1.9e9], ["US", 1.4e9], ["NL", 6e8], ["AT", 1.5e8], ["GB", 5e7]];
    var pad = function (n) { return n < 10 ? "0" + n : String(n); };
    var days = {}, today = new Date(now);
    for (var k = 419; k >= 0; k--) {
        // By calendar day at noon: 24 h steps from midnight hit one date
        // twice across a DST change.
        var t = new Date(today.getFullYear(), today.getMonth(), today.getDate() - k, 12);
        var key = t.getFullYear() + "-" + pad(t.getMonth() + 1) + "-" + pad(t.getDate());
        var weekend = t.getDay() === 0 || t.getDay() === 6;
        var f = (0.55 + 0.45 * Math.abs(Math.sin(k * 1.7))) * (weekend ? 1.6 : 1) * (k === 0 ? 0.6 : 1);
        var season = 0.75 + 0.25 * Math.sin(k / 58);
        f *= season;
        var d = { "in": 0, out: 0, hours: [], apps: {}, domains: {}, countries: {}, ifaces: {} };
        for (var h = 0; h < 24; h++) {
            var busy = h < 7 ? 0.05 : h < 9 ? 0.4 : h < 18 ? 0.8 + 0.2 * Math.sin(h) : 1.2;
            var hin = k === 0 && h > new Date(now).getHours() ? 0 : Math.round(2.4e8 * busy * f);
            d.hours.push([hin, Math.round(hin * 0.08)]);
            d["in"] += hin;
            d.out += Math.round(hin * 0.08);
        }
        apps.forEach(function (a, i) {
            var v = a[3] * f * (0.6 + 0.4 * Math.abs(Math.cos(k + i)));
            d.apps[a[0]] = { name: a[1], icon: a[2], "in": Math.round(v), out: Math.round(v * 0.06), conns: Math.round(40 + 30 * Math.abs(Math.sin(k * i + 1))) };
        });
        domains.forEach(function (x, i) {
            var v = x[1] * f * (0.6 + 0.4 * Math.abs(Math.sin(k + i)));
            d.domains[x[0]] = [Math.round(v), Math.round(v * 0.05), Math.round(12 + 9 * Math.abs(Math.cos(k * i)))];
        });
        countries.forEach(function (x) {
            d.countries[x[0]] = [Math.round(x[1] * f), Math.round(x[1] * f * 0.05)];
        });
        d.ifaces = { wlp2s0: [Math.round(d["in"] * 0.82), Math.round(d.out * 0.8)], wg0: [Math.round(d["in"] * 0.12), Math.round(d.out * 0.15)], docker0: [Math.round(d["in"] * 0.03), Math.round(d.out * 0.02)] };
        if (k > 62) {
            d.hours = null;
            d.compact = true;
        }
        days[key] = d;
    }
    return { format: "glassy-network-history", version: 1, updated: now, days: days };
}

// `docker ps` / `podman ps` output (Probes.CONTAINERS_CMD) and growing stats.
var NET_CONTAINERS = [
    "@@engine docker",
    '{"ID":"4f1c2a9be0d1","Image":"nginx:1.27-alpine","Names":"web","Networks":"bridge,front","Ports":"0.0.0.0:8080->80/tcp, [::]:8080->80/tcp","State":"running","Status":"Up 3 hours"}',
    '{"ID":"9ab7d2c4f310","Image":"postgres:16","Names":"db","Networks":"front","Ports":"127.0.0.1:5432->5432/tcp","State":"running","Status":"Up 3 hours (healthy)"}',
    '{"ID":"c1d2e3f4a5b6","Image":"ghcr.io/home-assistant/home-assistant:stable","Names":"homeassistant","Networks":"host","Ports":"","State":"running","Status":"Up 2 days"}',
    "@@inspect docker",
    "/web|bridge=172.17.0.2 front=172.20.0.3 ",
    "/db|front=172.20.0.4 ",
    "/homeassistant|host= ",
    "@@networks docker",
    '{"ID":"0b6e2f7d8c91","Name":"bridge","Driver":"bridge"}',
    '{"ID":"5d3a9c0e1f22","Name":"front","Driver":"bridge"}',
    '{"ID":"77aa33bb11cc","Name":"host","Driver":"host"}',
    "@@engine podman",
    '[{"Id":"e8f9a0b1c2d3e4f5","Image":"docker.io/library/redis:7","Names":["cache"],"Networks":["podman"],"Ports":[{"host_ip":"127.0.0.1","container_port":6379,"host_port":6379,"range":1,"protocol":"tcp"}],"State":"running","Status":"Up 40 minutes"}]',
    "@@inspect podman",
    "cache|podman=10.88.0.5 ",
    "@@networks podman",
    '[{"name":"podman","id":"2f259bab93aa","driver":"bridge","network_interface":"podman0"}]'
].join("\n");
function netContainerStats(i) {
    var kb = function (v) { return (v / 1000).toFixed(1) + "kB"; };
    var mb = function (v) { return (v / 1e6).toFixed(2) + "MB"; };
    return "@@stats docker\n" + JSON.stringify({ Name: "web", NetIO: mb(4e6 + i * 2.1e5 * (1 + 0.5 * Math.sin(i / 3))) + " / " + mb(9e6 + i * 6e5) })
        + "\n" + JSON.stringify({ Name: "db", NetIO: mb(1e6 + i * 3e4) + " / " + mb(2e6 + i * 9e4 * (1 + 0.6 * Math.cos(i / 4))) })
        + "\n" + JSON.stringify({ Name: "homeassistant", NetIO: "0B / 0B" })
        + "\n@@stats podman\n" + JSON.stringify([{ name: "cache", net_io: kb(4e5 + i * 8e3) + " / " + kb(6e5 + i * 1.1e4) }]);
}

// FIREWALL_CMD on a NixOS machine with the default firewall.
var NET_FIREWALL = ["unit firewalld inactive", "unit ufw inactive", "unit nftables inactive", "unit iptables inactive", "unit firewall active", "nixos",
    "-p tcp --dport 22", "-p tcp --dport 22000", "-p udp --dport 21027", "-p tcp --dport 1714:1764", "-p udp --dport 1714:1764"].join("\n");

// A few alerts for the demo's bell.
function netAlerts(now) {
    return [
        { time: now - 4 * 60000, kind: "newApp", title: "New app online: Discord", body: "First connection to discord.gg (US), port 443" },
        { time: now - 52 * 60000, kind: "openPort", title: "Port open to the network: 8080/tcp", body: "web · Docker listens on all addresses" },
        { time: now - 3 * 3600000, kind: "limit", title: "Daily limit reached: Steam", body: "5.12 GiB today, limit 5.00 GiB" },
        { time: now - 26 * 3600000, kind: "vpnDown", title: "VPN disconnected: Mullvad (WireGuard)", body: "wg0 is down; traffic now leaves directly" }
    ];
}
