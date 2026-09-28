import QtQuick
import QtTest
import "../package/contents/ui" as Ui
import "../package/contents/ui/diagram" as D
import "../package/contents/ui/Sections.js" as Sections

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

        function test_manualPositionsAndReturnToGrid() {
            const v = view({
                sections: "cpu,gpu",
                layoutMode: "manual",
                sectionPositions: '{"cpu":{"x":20,"y":30,"width":250},"gpu":{"x":400,"y":80,"width":300}}'
            });
            const [cpu, gpu] = sections(v);
            compare(cpu.mapToItem(v, 0, 0).x, v.margin + 20);
            compare(cpu.mapToItem(v, 0, 0).y, v.margin + 30);
            compare(cpu.width, 250);
            compare(gpu.mapToItem(v, 0, 0).x, v.margin + 400);
            compare(gpu.mapToItem(v, 0, 0).y, v.margin + 80);
            compare(v.minimumWidth, 700 + 2 * v.margin);
            verify(v.minimumHeight >= 80 + gpu.minimumHeight + 2 * v.margin);
            root.cfg = Object.assign({}, root.cfg, {
                layoutMode: "auto",
                layoutColumns: 2
            });
            wait(50);
            const automatic = sections(v);
            compare(automatic[0].mapToItem(v, 0, 0).y, automatic[1].mapToItem(v, 0, 0).y);
            verify(automatic[0].width > 250);
        }

        function find(item, name) {
            if (item.objectName === name)
                return item;
            for (const child of item.children) {
                const hit = find(child, name);
                if (hit)
                    return hit;
            }
            return null;
        }
        // What the hosts do with a drag: save it, so the card follows.
        function drag(v, from, to) {
            const moves = [];
            const save = (id, place) => {
                moves.push([id, place]);
                root.cfg = Object.assign({}, root.cfg, {
                    sectionPositions: Sections.position(root.cfg.sectionPositions, id, place)
                });
            };
            v.sectionMoved.connect(save);
            mousePress(v, from.x, from.y);
            for (let i = 1; i <= 4; ++i)
                mouseMove(v, from.x + (to.x - from.x) * i / 4, from.y + (to.y - from.y) * i / 4, -1, Qt.LeftButton);
            mouseRelease(v, to.x, to.y);
            v.sectionMoved.disconnect(save);
            wait(30);
            return moves;
        }
        function test_arrangingDragsAndResizesWithTheMouse() {
            const v = view({
                sections: "cpu,memory",
                layoutMode: "manual",
                sectionPositions: '{"cpu":{"x":0,"y":0,"width":300},"memory":{"x":320,"y":0,"width":260}}'
            });
            v.arranging = true;
            wait(30);
            const m = v.margin;
            // Move: grab the middle of CPU.
            let moves = drag(v, Qt.point(m + 100, m + 30), Qt.point(m + 140, m + 70));
            compare(moves.length, 1);
            compare(moves[0][0], "cpu");
            compare(moves[0][1], {
                x: 40,
                y: 40,
                width: 300
            }, "moved by the drag, no height set");
            const [cpu, memory] = sections(v);
            compare(cpu.parent.mapToItem(v, 0, 0).x, m + 40, "the card follows the saved position");
            // Corner: width and height at once.
            const h = memory.parent.height;
            moves = drag(v, Qt.point(m + 320 + 260 - 1, m + h - 1), Qt.point(m + 320 + 300 - 1, m + h + 59));
            compare(moves.length, 1);
            compare(moves[0][0], "memory");
            compare(moves[0][1].width, 300);
            compare(moves[0][1].height, Math.round((h + 60) / 4) * 4);
            compare(memory.parent.height, moves[0][1].height);
            // Bottom edge: height only, and never below what the section needs.
            const least = memory.minimumHeight;
            const h2 = memory.parent.height;
            moves = drag(v, Qt.point(m + 400, m + h2 - 1), Qt.point(m + 400, m + 5));
            compare(moves[0][1].width, 300, "width unchanged");
            compare(memory.parent.height, Math.max(40, least), "never shorter than it needs");
            // Not arranging: the same press is the section's own again.
            v.arranging = false;
            wait(30);
            compare(drag(v, Qt.point(m + 100, m + 60), Qt.point(m + 200, m + 90)).length, 0);
        }
        function test_arrangeFreelyStartsFromTheGrid() {
            const v = view({
                sections: "cpu,memory",
                layoutColumns: 2,
                sectionPositions: '{"gpu":{"x":500,"y":500,"width":300}}'
            });
            v.arranging = true;
            wait(30);
            const button = find(v, "arrangeFreely");
            verify(button && button.visible);
            let asked = null;
            v.manualRequested.connect(p => asked = JSON.parse(p));
            const c = button.mapToItem(v, button.width / 2, button.height / 2);
            mouseClick(v, c.x, c.y);
            verify(asked);
            compare(Object.keys(asked).sort(), ["cpu", "memory"], "only this card's sections, not another's saved ones");
            compare(asked.cpu.y, asked.memory.y, "side by side, as in the grid");
        }

        function test_manualHeightNeverCutsOff() {
            const v = view({
                sections: "cpu,memory",
                layoutMode: "manual",
                sectionPositions: '{"cpu":{"x":0,"y":0,"width":300,"height":400},"memory":{"x":320,"y":0,"width":300,"height":40}}'
            });
            const [cpu, memory] = sections(v);
            compare(cpu.parent.height, 400, "a set height is kept");
            compare(memory.parent.height, Math.max(40, memory.minimumHeight), "but never below what the section needs");
            verify(v.minimumHeight >= 400 + 2 * v.margin);
        }

        function test_sensorRowsUseDraftAndUpdateImmediately() {
            const v = view({
                sections: "cpu",
                sensorSelection: '{"cpu":[]}'
            });
            const height = v.preferredHeight;
            root.cfg = Object.assign({}, root.cfg, {
                sensorSelection: '{"cpu":["cpu:power"]}',
                sensorNames: '{"cpu:power":"Package watts"}'
            });
            wait(50);
            verify(v.preferredHeight > height);
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
            for (const layout of ["cpu", "cpu,memory,network,ping,disk,gpu,sensors,power,system,custom", "load,fans,services,containers,storage,processes,power"]) {
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
                sections: "cpu,sensors,power,system,ping,load,fans,services,containers",
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
