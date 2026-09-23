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
