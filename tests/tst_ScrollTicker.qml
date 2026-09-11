pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../package/contents/ui" as Widget

TestCase {
    id: tests
    name: "ScrollTicker"
    property var ticker: null

    Component {
        id: tickerComponent
        Widget.ScrollTicker {
            running: false
        }
    }

    SignalSpy {
        id: ticks
        target: tests.ticker
        signalName: "tick"
    }

    function init() {
        ticker = createTemporaryObject(tickerComponent, tests);
        verify(ticker !== null);
        verify(ticks.valid);
        ticks.clear();
    }

    function test_caps_data() {
        return [
            {
                tag: "60-on-60Hz",
                fps: 60,
                refresh: 60,
                expected: 60
            },
            {
                tag: "24-on-60Hz",
                fps: 24,
                refresh: 60,
                expected: 24
            },
            {
                tag: "15-on-60Hz",
                fps: 15,
                refresh: 60,
                expected: 15
            },
            {
                tag: "140-on-280Hz",
                fps: 140,
                refresh: 280,
                expected: 140
            },
            {
                tag: "140-on-60Hz",
                fps: 140,
                refresh: 60,
                expected: 60
            }
        ];
    }

    function test_caps(data) {
        ticker.targetFps = data.fps;
        for (let frame = 0; frame < data.refresh; ++frame) {
            const before = ticks.count;
            ticker.advance(1 / data.refresh);
            verify(ticks.count - before <= 1, "A rendered frame may trigger at most one update");
        }
        compare(ticks.count, data.expected);
    }

    function test_variableFrameTimesRespectCap() {
        ticker.targetFps = 24;
        for (let pair = 0; pair < 30; ++pair) {
            ticker.advance(1 / 80);
            ticker.advance(1 / 48);
        }
        compare(ticks.count, 24);
    }

    function test_jitteredVsyncAtCapTicksEveryFrame_data() {
        return [
            {
                tag: "60Hz ±0.4ms",
                refresh: 60,
                jitter: 0.0004
            },
            {
                tag: "60.03Hz panel",
                refresh: 60.03,
                jitter: 0
            },
            {
                tag: "59.94Hz ±0.2ms",
                refresh: 59.94,
                jitter: 0.0002
            }
        ];
    }

    function test_jitteredVsyncAtCapTicksEveryFrame(data) {
        ticker.targetFps = 60;
        const frames = 600;
        for (let frame = 0; frame < frames; ++frame) {
            const before = ticks.count;
            ticker.advance(1 / data.refresh + (frame % 2 ? data.jitter : -data.jitter));
            // Every frame after the first must tick: a skipped one is a visible freeze.
            if (frame > 0)
                compare(ticks.count - before, 1, "Frame " + frame + " was skipped");
        }
    }

    function test_60fpsOn144HzHoldsAverage() {
        ticker.targetFps = 60;
        for (let frame = 0; frame < 144; ++frame)
            ticker.advance(1 / 144);
        verify(Math.abs(ticks.count - 60) <= 1, "Expected ~60 ticks, got " + ticks.count);
    }

    function test_longFrameDoesNotQueueCatchupBurst() {
        ticker.targetFps = 60;
        ticker.advance(0.5);
        compare(ticks.count, 1);
        for (let frame = 0; frame < 10; ++frame)
            ticker.advance(0.001);
        compare(ticks.count, 1, "A delayed frame must not leave a backlog of animation updates");
    }

    function test_zeroFrameTimeDoesNotTick() {
        ticker.advance(0);
        compare(ticks.count, 0);
    }
}
