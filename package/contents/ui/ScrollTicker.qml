// Scroll ticker, driven by the window's own frames rather than a Timer: a Timer
// is not vsync-aligned, and its beat against the display is exactly the uneven
// spacing that reads as stutter. targetFps caps how many of those frames emit
// a tick; it never adds frames the display is not already drawing.
import QtQuick

FrameAnimation {
    id: ticker
    property real targetFps: 60
    property real _accumulator: 0
    signal tick

    function advance(deltaSeconds) {
        if (!isFinite(deltaSeconds) || deltaSeconds <= 0)
            return;
        const period = 1 / Math.max(1, targetFps);
        _accumulator += deltaSeconds;
        // Tick on the frame NEAREST to when one is due, not the first frame at
        // or past it. Vsync deltas jitter both ways around the display period,
        // so with the cap at the refresh rate a strict ">= period" test skipped
        // a frame every time one landed a hair early — a random one-frame freeze
        // every few seconds. The epsilon settles exact ties (24 fps on 60 Hz is
        // 2.5 frames a tick) toward ticking.
        if (_accumulator + 1e-6 < period - deltaSeconds / 2)
            return;
        // A frame early leaves a small negative remainder and a late one a small
        // positive remainder; both are kept so the average holds the cap. More
        // than half a period left over means a stalled frame, and carrying that
        // would only buy a burst of catch-up ticks.
        const surplus = _accumulator - period;
        _accumulator = surplus > period / 2 ? 0 : surplus;
        tick();
    }

    onTriggered: advance(frameTime)
    onRunningChanged: _accumulator = 0
    onTargetFpsChanged: _accumulator = 0
}
