pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import "../package/contents/ui" as Widget

TestCase {
    id: tests
    name: "SampleClock"
    property var clock: null

    Component {
        id: clockComponent
        Widget.SampleClock {
            sampleInterval: 1000
            minInterval: 250
            maxInterval: 5000
            smooth: true
        }
    }

    function init() {
        clock = createTemporaryObject(clockComponent, tests);
        verify(clock !== null);
    }

    function close(actual, expected, message) {
        verify(Math.abs(actual - expected) < 0.000001, message + ": " + actual + " vs " + expected);
    }

    function test_firstSampleStartsAtZero() {
        clock.sample(10000);
        compare(clock.generation, 1);
        compare(clock.lastSampleTime, 10000);
        close(clock.phase(10000), 0, "First sample phase");
    }

    function test_500msStreamUsesActualArrivalTimes() {
        clock.sample(10000);
        for (let sample = 1; sample <= 20; ++sample) {
            const now = 10000 + sample * 500;
            const position = clock.generation + clock.drawnPhase(now);
            clock.sample(now);
            close(clock.sampleInterval, 500, "Actual sensor cadence must remain 500ms");
            close(clock.generation + clock.drawnPhase(now), position, "Sample handoff must preserve position");
            close(clock.phase(now + clock.sampleInterval), 1, "The newest sample must reach the edge at the predicted arrival");
        }
    }

    function test_jitteredSamplesPreservePosition() {
        const intervals = [500, 480, 540, 500, 750, 1000, 350, 500];
        let now = 10000;
        let expectedCadence = 500;
        clock.sample(now);
        for (let i = 0; i < intervals.length; ++i) {
            now += intervals[i];
            const position = clock.generation + clock.drawnPhase(now);
            clock.sample(now);
            if (i > 0)
                expectedCadence = 0.7 * expectedCadence + 0.3 * intervals[i];
            close(clock.sampleInterval, expectedCadence, "Cadence must use real arrivals");
            close(clock.generation + clock.drawnPhase(now), position, "Early or late samples must not jump");
            close(clock.phase(now + clock.sampleInterval), 1, "Prediction must use the corrected phase interval");
        }
    }

    function test_staticModeDoesNotCarryPhase() {
        clock.smooth = false;
        clock.sample(10000);
        clock.sample(10500);
        close(clock.phase(10500), 0, "Static samples start at zero");
        close(clock.interval, 500, "Static cadence");
    }
}
