pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../package/contents/ui" as Widget

Item {
    id: root
    width: 400
    height: 240

    property bool fullRepVisible: true
    property int scrollTick: 0
    property real phase: 0
    property real _cpuInterval: 1000
    property real _cpuPhaseStart: 1
    property int _cpuSampleSerial: 0
    property int paintCompletions: 0
    property var cpuHistory: []
    property var coreHistories: []
    property var corePercents: []
    property var coreColors: ["#66aaff", "#ffee88"]
    property real cpuPercent: 55
    property color cpuColor: "#ff6666"
    property color textColor: "white"
    property int hoveredCore: -1
    property string hoveredLine: ""
    signal repaintCharts

    function notePaintRequested() {
    }
    function notePainted() {
        ++paintCompletions;
    }
    function _phaseActive(start, interval) {
        return true;
    }
    function cpuScrollPhase() {
        return phase;
    }
    function scrollDrawPhase(value, interval) {
        return value;
    }
    function isLineDisabled(key) {
        return false;
    }
    function isCoreDisabled(index) {
        return false;
    }
    function toggleCoreDisabled(index) {
    }

    QtObject {
        id: plasmoid
        property QtObject configuration: QtObject {
            id: settings
            property bool gpuBloom: false
            property bool glowLine: true
            property real bloomStrength: 0.5
            property int historySize: 17
            property int chartType: 0
            property bool showYLabels: false
            property bool smoothScroll: true
            property bool smoothLines: true
            property bool showCpuCores: false
            property bool showGridLines: true
            property bool autoYRange: false
            property real lineWidth: 2
        }
    }

    Widget.ChartUtils {
        id: cu
        textColor: root.textColor
        glowEnabled: settings.glowLine
        showGridLines: settings.showGridLines
        gpuBloom: settings.gpuBloom
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Component {
        id: sectionComponent
        Widget.CpuSection {
            anchors.fill: parent
        }
    }

    TestCase {
        id: tests
        name: "CpuSection"
        when: windowShown
        property var section: null

        function init() {
            root.phase = 0;
            root.scrollTick = 0;
            root._cpuSampleSerial = 0;
            root.paintCompletions = 0;
            plasmoid.configuration.chartType = 0;
            plasmoid.configuration.gpuBloom = false;
            plasmoid.configuration.smoothScroll = true;
            plasmoid.configuration.showYLabels = false;
            plasmoid.configuration.showCpuCores = false;
            root.cpuHistory = [15, 20, 55, 70, 25, 15, 20, 50, 75, 20, 20, 35, 65, 15, 25, 20, 55];
            root.coreHistories = [root.cpuHistory, root.cpuHistory.map(value => value * 0.7)];
            root.corePercents = [55, 38.5];
            section = createTemporaryObject(sectionComponent, root);
            verify(section !== null);
            tryVerify(() => root.paintCompletions > 0);
            wait(40);
        }

        function tick(value) {
            root.phase = value;
            ++root.scrollTick;
            wait(20);
        }

        function test_scrollMovesActualCpuChartWithoutPainting() {
            const initial = grabImage(root);
            const before = root.paintCompletions;
            for (let i = 1; i <= 24; ++i)
                tick(i / 24);
            compare(root.paintCompletions, before);
            verify(!initial.equals(grabImage(root)), "Actual CPU graph must move while its Canvas remains cached");
        }

        function test_dataUpdatesActualCpuChart() {
            const initial = grabImage(root);
            const before = root.paintCompletions;
            root.cpuHistory = root.cpuHistory.slice(1).concat([95]);
            root.cpuPercent = 95;
            ++root._cpuSampleSerial;
            tryVerify(() => root.paintCompletions > before);
            verify(!initial.equals(grabImage(root)));
        }

        function featureX(image) {
            let weight = 0;
            let total = 0;
            for (let y = 20; y < 100; ++y) {
                for (let x = 50; x < 350; ++x) {
                    const strength = image.red(x, y) - image.green(x, y);
                    if (strength > 80) {
                        weight += strength;
                        total += x * strength;
                    }
                }
            }
            verify(weight > 0, "The CPU spike must be visible");
            return total / weight;
        }

        function test_sampleHandoffDoesNotMoveBackwards_data() {
            return [
                {
                    tag: "early",
                    phase: 0.9
                },
                {
                    tag: "on-time",
                    phase: 1
                },
                {
                    tag: "late",
                    phase: 1.1
                }
            ];
        }

        function test_sampleHandoffDoesNotMoveBackwards(data) {
            root.cpuHistory = [0, 0, 0, 0, 0, 0, 0, 80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            root.repaintCharts();
            wait(40);
            tick(data.phase);
            let previous = featureX(grabImage(root));
            root.cpuHistory = root.cpuHistory.slice(1).concat([0]);
            root.phase = data.phase - 1;
            ++root._cpuSampleSerial;
            ++root.scrollTick;
            for (let frame = 0; frame < 4; ++frame) {
                const current = featureX(grabImage(root));
                verify(current <= previous + 1, "Sample handoff frame " + frame + " moved backwards from " + previous + " to " + current);
                previous = current;
                wait(17);
                root.phase += 0.017;
                ++root.scrollTick;
            }
        }

        function test_scrollingAndStaticSampleMatch_data() {
            return [
                {
                    tag: "line",
                    chartType: 0
                },
                {
                    tag: "history-bars",
                    chartType: 1
                },
                {
                    tag: "area",
                    chartType: 2
                }
            ];
        }

        function test_scrollingAndStaticSampleMatch(data) {
            plasmoid.configuration.chartType = data.chartType;
            root.repaintCharts();
            wait(40);
            tick(1);
            const scrolled = grabImage(root);
            plasmoid.configuration.smoothScroll = false;
            root.repaintCharts();
            wait(40);
            verify(scrolled.equals(grabImage(root)), "Finishing a scroll must show the same sample as static mode");
        }

        function test_allGaugeTypesStayStill_data() {
            return [
                {
                    tag: "donut",
                    chartType: 3
                },
                {
                    tag: "pie",
                    chartType: 4
                },
                {
                    tag: "horizontal-bars",
                    chartType: 5
                }
            ];
        }

        function test_allGaugeTypesStayStill(data) {
            plasmoid.configuration.chartType = data.chartType;
            root.repaintCharts();
            wait(40);
            const initial = grabImage(root);
            const before = root.paintCompletions;
            tick(1);
            compare(root.paintCompletions, before);
            verify(initial.equals(grabImage(root)));
        }

        function test_coreOverlayScrollsWithoutPainting() {
            plasmoid.configuration.showCpuCores = true;
            root.repaintCharts();
            wait(40);
            const before = root.paintCompletions;
            const initial = grabImage(root);
            tick(1);
            compare(root.paintCompletions, before);
            verify(!initial.equals(grabImage(root)));
        }
    }
}
