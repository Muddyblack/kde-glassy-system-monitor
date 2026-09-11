import QtQuick

QtObject {
    property real sampleInterval: 1000
    property real interval: sampleInterval
    property real phaseStart: 0
    property real lastSampleTime: 0
    property int generation: 0
    property bool smooth: true
    property real minInterval: 200
    property real maxInterval: 120000
    property bool _measured: false

    function phase(now) {
        if (now === undefined)
            now = Date.now();
        return generation > 0 ? (now - phaseStart) / interval : 0;
    }

    function drawnPhase(now) {
        const value = phase(now);
        if (!isFinite(value))
            return 0;
        if (value <= 1)
            return value;
        const tau = Math.min(0.5, 250 / Math.max(1, interval));
        return 1 + tau * (1 - Math.exp(-(value - 1) / tau));
    }

    function sample(now) {
        if (now === undefined)
            now = Date.now();
        if (!isFinite(now))
            return;
        const carry = generation > 0 && smooth ? drawnPhase(now) - 1 : 0;
        const gap = now - lastSampleTime;
        if (generation > 0 && gap >= minInterval && gap <= maxInterval) {
            sampleInterval = _measured ? sampleInterval * 0.7 + gap * 0.3 : gap;
            _measured = true;
        }
        lastSampleTime = now;
        interval = Math.max(1, sampleInterval) / (1 - carry);
        phaseStart = now - carry * interval;
        ++generation;
    }
}
