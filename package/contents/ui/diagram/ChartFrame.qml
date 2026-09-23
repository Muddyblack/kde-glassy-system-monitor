import QtQuick
import QtQuick.Effects

Item {
    id: frame

    required property var chartRoot
    required property int bufferIndex
    property int revision: -1
    property int sampleSerial: 0
    property real plotLeft: 0
    property real plotStep: 0
    property real padding: 0
    property bool scrolling: false
    property bool bloom: false
    property real blur: 0
    property bool painting: false
    property int readyLayers: 0
    readonly property real scrollOffset: scrolling ? (sampleSerial - chartRoot.sampleSerial - chartRoot._livePhase) * plotStep : 0

    // Prepare the hidden buffer; publish its pixels and generation together.
    function prepare(nextRevision) {
        revision = nextRevision;
        sampleSerial = chartRoot.sampleSerial;
        width = chartRoot.width;
        height = chartRoot.height;
        plotLeft = chartRoot.plotLeft;
        plotStep = chartRoot.scrollStepPx;
        padding = chartRoot.scrollPadding;
        scrolling = chartRoot.smoothScrolling;
        bloom = chartRoot.bloomActive;
        blur = chartRoot.bloomBlur;
        readyLayers = bloom ? 0 : 1;
        painting = true;
        if (bloom)
            linesCanvas.requestPaint();
        chromeCanvas.requestPaint();
        mainCanvas.requestPaint();
    }

    function layerReady(layer) {
        if (!painting)
            return;
        readyLayers |= layer;
        if (readyLayers === 7) {
            painting = false;
            chartRoot.publish(frame);
        }
    }

    Item {
        x: frame.plotLeft
        y: -32
        width: Math.max(0, frame.width - frame.plotLeft)
        height: frame.height + 64
        clip: true
        visible: frame.bloom
        z: 0

        Item {
            x: -frame.plotLeft - frame.padding + frame.scrollOffset
            y: 32
            width: frame.width + 2 * frame.padding
            height: frame.height

            Canvas {
                id: linesCanvas
                anchors.fill: parent
                antialiasing: true
                renderStrategy: Canvas.Cooperative
                layer.enabled: frame.bloom
                layer.smooth: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: frame.blur
                    blurMax: 32
                    brightness: 0.10
                    saturation: 0.45
                    autoPaddingEnabled: true
                }
                onPaint: {
                    if (!frame.painting)
                        return;
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.translate(frame.padding, 0);
                    if (frame.bloom && frame.chartRoot.paint)
                        frame.chartRoot.paint(ctx, true);
                }
                onPainted: frame.layerReady(1)
            }
        }
    }

    Canvas {
        id: chromeCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        z: 1
        onPaint: {
            if (!frame.painting)
                return;
            const ctx = getContext("2d");
            ctx.reset();
            if (frame.chartRoot.paintChrome)
                frame.chartRoot.paintChrome(ctx);
        }
        onPainted: frame.layerReady(2)
    }

    Item {
        x: frame.plotLeft
        width: Math.max(0, frame.width - frame.plotLeft)
        height: frame.height
        clip: true
        z: 2

        Item {
            x: -frame.plotLeft - frame.padding + frame.scrollOffset
            width: frame.width + 2 * frame.padding
            height: frame.height

            Canvas {
                id: mainCanvas
                anchors.fill: parent
                antialiasing: true
                renderStrategy: Canvas.Cooperative
                onPaint: {
                    if (!frame.painting)
                        return;
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.translate(frame.padding, 0);
                    if (frame.chartRoot.paint)
                        frame.chartRoot.paint(ctx, false);
                }
                onPainted: frame.layerReady(4)
            }
        }
    }
}
