pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../package/contents/ui" as Widget

Item {
    id: root
    width: 320
    height: 180

    property int scrollTick: 0
    property real phase: 0
    property bool fullRepVisible: true
    readonly property real scrollPaintStepPx: 0.05
    readonly property int _tickFloorMs: 42
    property int mainPaints: 0
    property int glowPaints: 0
    property int chromePaints: 0
    property int paintRequests: 0
    property int paintCompletions: 0

    function notePaintRequested() {
        ++paintRequests;
    }
    function notePainted() {
        ++paintCompletions;
    }
    function scrollDrawPhase(value, interval) {
        return value;
    }

    QtObject {
        id: plasmoid
        property QtObject configuration: QtObject {
            property bool gpuBloom: false
            property bool glowLine: true
            property real bloomStrength: 0.5
            property int historySize: 17
            property int chartType: 0
            property bool showYLabels: false
            property bool smoothScroll: true
            property real lineWidth: 2
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Component {
        id: chartComponent
        Widget.BloomChart {
            id: sampleChart
            width: root.width
            height: root.height
            dataIntervalMs: 1000
            scrollPhase: () => root.phase
            paintChrome: function (ctx) {
                ++root.chromePaints;
                ctx.fillStyle = "blue";
                ctx.fillRect(20, 20, 4, 40);
            }
            paint: function (ctx, glowPass) {
                if (glowPass)
                    ++root.glowPaints;
                else
                    ++root.mainPaints;
                const offset = sampleChart.paintPhase * sampleChart.scrollStepPx;
                ctx.fillStyle = "red";
                ctx.fillRect(140 - offset, 20, 4, 40);
                ctx.fillStyle = "lime";
                ctx.fillRect(sampleChart.width + sampleChart.scrollStepPx / 2 - offset, 80, 4, 20);
                ctx.fillStyle = "yellow";
                ctx.fillRect(sampleChart.plotLeft + sampleChart.scrollStepPx / 2 - offset, 120, 4, 20);
                ctx.fillStyle = "magenta";
                ctx.fillRect(sampleChart.plotLeft - sampleChart.scrollStepPx / 2 - offset, 150, 4, 20);
            }
        }
    }

    TestCase {
        id: tests
        name: "BloomChart"
        when: windowShown
        property var chart: null

        function init() {
            root.phase = 0;
            root.scrollTick = 0;
            plasmoid.configuration.gpuBloom = false;
            plasmoid.configuration.chartType = 0;
            plasmoid.configuration.showYLabels = false;
            plasmoid.configuration.smoothScroll = true;
            root.width = 320;
            root.mainPaints = 0;
            root.glowPaints = 0;
            root.chromePaints = 0;
            root.paintRequests = 0;
            root.paintCompletions = 0;
            chart = createTemporaryObject(chartComponent, root);
            verify(chart !== null);
            chart.requestPaint();
            tryVerify(() => root.mainPaints > 0);
            wait(40);
        }

        function tick(value) {
            root.phase = value;
            ++root.scrollTick;
            chart.requestScrollPaint();
            wait(20);
        }

        function test_dataRepaints() {
            const before = root.mainPaints;
            const beforeChrome = root.chromePaints;
            chart.requestPaint();
            tryVerify(() => root.mainPaints > before);
            verify(root.chromePaints > beforeChrome);
        }

        function test_burstCoalescesPaints() {
            const before = root.mainPaints;
            chart.requestPaint();
            chart.requestPaint();
            chart.requestPaint();
            tryVerify(() => root.mainPaints > before);
            wait(40);
            compare(root.mainPaints, before + 1);
        }

        function test_scrollUsesCachedPixels() {
            const before = root.mainPaints;
            const beforeChrome = root.chromePaints;
            for (let i = 1; i <= 24; ++i)
                tick(i / 24);
            console.log("24 scroll ticks: main=" + (root.mainPaints - before) + ", chrome=" + (root.chromePaints - beforeChrome));
            compare(root.mainPaints, before, "Scrolling must not rasterize the cached chart");
            compare(root.chromePaints, beforeChrome, "Scrolling must not redraw labels");
        }

        function test_pixelsMoveAndChromeStaysFixed() {
            const initial = grabImage(root);
            compare(initial.red(141, 30), 255);
            compare(initial.blue(21, 30), 255);
            tick(1);
            const scrolled = grabImage(root);
            compare(scrolled.red(121, 30), 255);
            compare(scrolled.red(141, 30), 0);
            compare(scrolled.blue(21, 30), 255);
        }

        function test_rightEdgeRevealsCachedSample() {
            tick(1);
            const scrolled = grabImage(root);
            compare(scrolled.green(311, 90), 255, "The offscreen sample must scroll into view");
        }

        function test_earlySampleRevealsCachedLeftEdge() {
            tick(-0.75);
            const scrolled = grabImage(root);
            compare(scrolled.red(6, 160), 255);
            compare(scrolled.blue(6, 160), 255);
        }

        function test_scrollingDoesNotPaintOverAxis() {
            plasmoid.configuration.showYLabels = true;
            chart.requestPaint();
            wait(40);
            tick(1);
            const scrolled = grabImage(root);
            for (let x = 0; x < chart.plotLeft; ++x)
                compare(scrolled.red(x, 130), 0, "Data leaked into the axis gutter at x=" + x);
            compare(scrolled.blue(21, 30), 255);
        }

        function test_disablingSmoothShowsCurrentSample() {
            tick(0.5);
            plasmoid.configuration.smoothScroll = false;
            chart.requestPaint();
            wait(40);
            const still = grabImage(root);
            compare(still.red(121, 30), 255);
            const before = root.mainPaints;
            tick(0.75);
            compare(root.mainPaints, before);
            verify(still.equals(grabImage(root)));
            plasmoid.configuration.smoothScroll = true;
            chart.requestPaint();
            wait(40);
            compare(grabImage(root).red(126, 30), 255);
        }

        function test_hiddenChartDoesNotRasterize() {
            chart.visible = false;
            wait(40);
            const before = root.mainPaints;
            chart.requestPaint();
            for (let i = 1; i <= 5; ++i)
                tick(i / 5);
            compare(root.mainPaints, before);
            chart.visible = true;
            chart.requestPaint();
            tryVerify(() => root.mainPaints > before);
        }

        function test_zeroSizeStartPublishesOnceSized() {
            const empty = createTemporaryObject(chartComponent, root, {
                width: 0,
                height: 0
            });
            verify(empty !== null);
            empty.requestPaint();
            wait(60);
            compare(empty._frontIndex, -1);
            empty.width = root.width;
            empty.height = root.height;
            tryVerify(() => empty._frontIndex >= 0, 1000, "A chart first laid out at 0x0 must publish once sized");
        }

        function test_resizeRepaintsAtNewWidth() {
            const before = root.mainPaints;
            root.width = 480;
            chart.requestPaint();
            tryVerify(() => root.mainPaints > before);
            tick(1);
            compare(grabImage(root).red(111, 30), 255);
        }

        function test_gaugeDoesNotScroll() {
            chart.scrolling = false;
            chart.requestPaint();
            wait(40);
            const before = root.mainPaints;
            for (let i = 1; i <= 5; ++i)
                tick(i / 5);
            compare(root.mainPaints, before);
        }

        function test_bloomDataRepaints() {
            plasmoid.configuration.gpuBloom = true;
            chart.requestPaint();
            tryVerify(() => root.glowPaints > 0);
            const beforeMain = root.mainPaints;
            const beforeGlow = root.glowPaints;
            chart.requestPaint();
            tryVerify(() => root.mainPaints > beforeMain && root.glowPaints > beforeGlow);
        }

        function test_bloomScrollUsesBothCachedLayers() {
            plasmoid.configuration.gpuBloom = true;
            chart.requestPaint();
            tryVerify(() => root.glowPaints > 0);
            wait(40);
            const beforeMain = root.mainPaints;
            const beforeGlow = root.glowPaints;
            for (let i = 1; i <= 24; ++i)
                tick(i / 24);
            compare(root.mainPaints, beforeMain);
            compare(root.glowPaints, beforeGlow);
        }
    }
}
