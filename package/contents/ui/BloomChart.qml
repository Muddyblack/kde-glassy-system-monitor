import QtQuick

Item {
    id: chart

    property var paint: null
    property var paintChrome: null
    property var scrollPhase: function () {
        return 0;
    }
    property int sampleSerial: 0
    property real dataIntervalMs: 1000
    property bool scrolling: (plasmoid.configuration.chartType || 0) < 3

    readonly property bool smoothScrolling: scrolling && plasmoid.configuration.smoothScroll
    readonly property bool chartVisible: visible && root.fullRepVisible
    readonly property real plotLeft: scrolling && plasmoid.configuration.showYLabels ? 38 : 0
    readonly property real scrollStepPx: Math.max(0, width - plotLeft) / Math.max(1, Math.max(10, plasmoid.configuration.historySize) - 1)
    readonly property real scrollPadding: smoothScrolling ? Math.ceil(3 * scrollStepPx + 16) : 0
    readonly property real paintPhase: smoothScrolling ? 0 : 1
    readonly property real scrollOffset: _frontIndex >= 0 ? frames.itemAt(_frontIndex).scrollOffset : 0
    readonly property bool bloomActive: plasmoid.configuration.gpuBloom && plasmoid.configuration.glowLine
    readonly property real bloomBlur: 0.25 + 0.75 * Math.max(0, Math.min(1, plasmoid.configuration.bloomStrength))

    property real _livePhase: 0
    property int _revision: 0
    property int _frontIndex: -1
    property bool _paintPending: false
    property bool _painting: false

    function requestScrollPaint() {
        if (!chartVisible)
            return;
        const phase = scrollPhase();
        _livePhase = isFinite(phase) ? phase : 0;
    }

    function requestPaint() {
        ++_revision;
        _paintPending = true;
        if (chartVisible)
            Qt.callLater(_flushPaint);
    }

    function _flushPaint() {
        if (!chartVisible || !_paintPending || _painting || frames.count < 2)
            return;
        // An empty canvas never paints, so its frame would never publish and
        // _painting would stay stuck. The size change re-requests the paint.
        if (!(width > 0 && height > 0))
            return;
        _paintPending = false;
        _painting = true;
        requestScrollPaint();
        root.notePaintRequested();
        frames.itemAt(_frontIndex === 0 ? 1 : 0).prepare(_revision);
    }

    function publish(frame) {
        _painting = false;
        if (frame.revision === _revision && chartVisible) {
            _frontIndex = frame.bufferIndex;
            root.notePainted();
        } else {
            _paintPending = true;
        }
        if (_paintPending)
            Qt.callLater(_flushPaint);
    }

    onSampleSerialChanged: {
        requestScrollPaint();
        requestPaint();
    }
    onChartVisibleChanged: if (chartVisible)
        requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPlotLeftChanged: requestPaint()
    onScrollStepPxChanged: requestPaint()
    onScrollPaddingChanged: requestPaint()
    onScrollingChanged: requestPaint()
    onPaintPhaseChanged: requestPaint()
    onBloomActiveChanged: requestPaint()
    onBloomBlurChanged: requestPaint()
    Component.onCompleted: requestPaint()

    Repeater {
        id: frames
        model: 2
        delegate: ChartFrame {
            required property int index
            chartRoot: chart
            bufferIndex: index
            opacity: chart._frontIndex === bufferIndex ? 1 : 0
        }
    }
}
