import QtQuick
import QtTest
import "../package/contents/ui" as Ui
import "../package/contents/ui/diagram" as D

// The card: sections in the chosen order and grid, sizes that never cut
// content off, and charts that fall back to the canvas renderer.
Item {
    id: root
    width: 1200
    height: 1600

    property var cfg: ({})
    readonly property var base: ({
            sections: "cpu",
            activeSection: 2,
            chartType: 0,
            chartRenderer: "gpu",
            historySize: 60,
            smoothScroll: false,
            smoothLines: true,
            lineWidth: 2.2,
            glowLine: true,
            bloomStrength: 0.6,
            showYLabels: true,
            showLegend: true,
            showStats: true,
            showCpuCores: false,
            targets: "1.1.1.1,8.8.8.8",
            latencyThreshold: 100,
            pingThresholdColors: true,
            gpuShowEngines: true,
            customCmdMax: 4,
            customCmdTitle: "Load",
            layoutColumns: 1,
            sectionSpans: "",
            sectionSizes: "",
            sectionStyles: "",
            bgColor: "#800d0f1a",
            frostedGlass: false,
            cardBorder: true,
            osUseFetch: false,
            useSystemTextColor: true,
            disabledLinesStr: "",
            disabledCoresStr: ""
        })
    function use(patch) {
        cfg = Object.assign({}, base, patch);
    }

    Ui.MonitorCore {
        id: core
        live: false
        cfg: root.cfg
    }
    Ui.DemoFeeder {
        monitor: core
        running: false
    }

    Component {
        id: viewComponent
        Ui.MonitorView {
            monitor: core
            cfg: root.cfg
        }
    }

    TestCase {
        name: "MonitorView"
        when: windowShown

        function view(patch, height) {
            root.use(patch);
            const v = createTemporaryObject(viewComponent, root, {
                width: 600
            });
            v.height = height === undefined ? Qt.binding(() => v.preferredHeight) : height;
            wait(50);
            return v;
        }
        function sections(v) {
            const out = [];
            const find = item => {
                for (const child of item.children) {
                    if (child.sectionId !== undefined && child.preferredHeight !== undefined)
                        out.push(child);
                    else
                        find(child);
                }
            };
            find(v);
            return out;
        }

        function test_showsChosenSectionsInOrder() {
            const v = view({
                sections: "memory,cpu,network"
            });
            compare(sections(v).map(s => s.sectionId), ["memory", "cpu", "network"]);
            const ys = sections(v).map(s => s.mapToItem(v, 0, 0).y);
            verify(ys[0] < ys[1] && ys[1] < ys[2], "one column stacks in list order");
        }

        function test_monospaceReachesHeaderAndChart() {
            const v = view({
                sections: "cpu",
                fontFamily: "monospace"
            });
            compare(core.fontFamily, "monospace");
            const cpu = sections(v)[0];
            const chart = cpu.children.find(child => child.sectionStyle !== undefined);
            verify(chart);
            compare(chart.fontFamily, "monospace");
            const texts = [];
            const collect = item => {
                for (const child of item.children) {
                    if (child.text !== undefined && child.font !== undefined)
                        texts.push(child);
                    collect(child);
                }
            };
            collect(cpu);
            verify(texts.some(item => item.text === "CPU"));
            verify(texts.every(item => item.font.family === "monospace"));
        }

        function test_twoColumnsPlaceSideBySide() {
            const v = view({
                sections: "cpu,memory,network",
                layoutColumns: 2,
                sectionSpans: "network"
            });
            const [cpu, mem, net] = sections(v).map(s => s.mapToItem(v, 0, 0));
            compare(Math.round(cpu.y), Math.round(mem.y));
            verify(mem.x > cpu.x + 100);
            verify(net.y > cpu.y);
            const netItem = sections(v)[2];
            verify(netItem.width > v.width * 0.8, "a spanning section takes the whole row");
        }

        function test_minimumNeverAbovePreferred() {
            for (const layout of ["cpu", "cpu,memory,network,ping,disk,gpu,sensors,power,system,custom"]) {
                const v = view({
                    sections: layout,
                    showCpuCores: true
                });
                verify(v.minimumHeight <= v.preferredHeight, layout);
                verify(v.minimumHeight >= 80);
            }
        }

        // At its minimum height nothing is cut: every section gets at least
        // its own minimum, only charts shrink, and never below 40 px.
        function test_atMinimumHeightNothingIsCut() {
            const v = view({
                sections: "cpu,sensors,power,system,ping",
                showCpuCores: true
            }, 0);
            v.height = v.minimumHeight;
            wait(80);
            for (const s of sections(v)) {
                verify(s.height >= s.minimumHeight - 1, s.sectionId + " got " + s.height + " < " + s.minimumHeight);
            }
        }

        // The studio sends a new settings object on every edit; unless the
        // section list changes, the sections and their charts must survive.
        function test_editsDoNotRebuildSections() {
            const v = view({
                sections: "cpu,memory"
            });
            const before = sections(v);
            root.cfg = Object.assign({}, root.cfg, {
                bgColor: "#99000000",
                sectionSpans: ""
            });
            wait(30);
            const after = sections(v);
            verify(after[0] === before[0] && after[1] === before[1], "sections were recreated");
            root.cfg = Object.assign({}, root.cfg, {
                sections: "memory,cpu"
            });
            wait(30);
            compare(sections(v).map(s => s.sectionId), ["memory", "cpu"]);
        }

        function test_textSectionsReportTheirContent() {
            const v = view({
                sections: "sensors"
            });
            const s = sections(v)[0];
            verify(s.preferredHeight > 100, "sensor rows must count, not a zero-height list");
        }

        function test_sizeClassGrowsTheChart() {
            const small = view({
                sections: "cpu",
                sectionSizes: "cpu:s"
            }).preferredHeight;
            const large = view({
                sections: "cpu",
                sectionSizes: "cpu:l"
            }).preferredHeight;
            compare(large - small, 150 - 56);
        }

        function test_textStyleHidesChartOnly() {
            // Views share root.cfg, so read each height before the next view.
            // The section, not the card: the card has an 80 px floor.
            const textOnly = sections(view({
                sections: "cpu",
                sectionStyles: "cpu:text"
            }))[0].preferredHeight;
            const withChart = sections(view({
                sections: "cpu"
            }))[0].preferredHeight;
            compare(withChart - textOnly, 90, "only the medium chart's height goes");
        }
    }

    Component {
        id: diagramComponent
        D.Diagram {
            width: 300
            height: 120
            maxValue: 100
            series: [
                {
                    values: [10, 50, 30, 80],
                    color: "#44ddaa"
                }
            ]
        }
    }

    TestCase {
        name: "Diagram"
        when: windowShown

        function test_softwareBackendFallsBackToCanvas() {
            const d = createTemporaryObject(diagramComponent, root, {
                renderer: "gpu"
            });
            wait(50);
            verify(!d.usingShader, "no shaders on the software backend");
        }

        function test_axisLabelsThinOutWhenShort() {
            const d = createTemporaryObject(diagramComponent, root, {
                ticks: [
                    {
                        value: 100,
                        text: "100%"
                    },
                    {
                        value: 75,
                        text: "75%",
                        grid: true
                    },
                    {
                        value: 50,
                        text: "50%",
                        grid: true
                    },
                    {
                        value: 25,
                        text: "25%",
                        grid: true
                    },
                    {
                        value: 0,
                        text: "0%"
                    }
                ]
            });
            d.height = 50;
            const few = d.visibleTicks.map(t => t.text);
            compare(few[0], "100%");
            compare(few[few.length - 1], "0%");
            verify(few.length < 5);
            d.height = 300;
            compare(d.visibleTicks.length, 5);
        }

        function test_emptyUntilTwoSamples() {
            const d = createTemporaryObject(diagramComponent, root, {
                series: [
                    {
                        values: [5],
                        color: "#fff"
                    }
                ]
            });
            verify(d.empty);
            d.series = [
                {
                    values: [5, 6],
                    color: "#fff"
                }
            ];
            verify(!d.empty);
        }
    }
}
