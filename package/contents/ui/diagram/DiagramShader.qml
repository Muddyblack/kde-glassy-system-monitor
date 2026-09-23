import QtQuick
import "DiagramData.js" as Data

// GPU renderer. The samples go into a small data texture once per sample; the
// shader draws them into a cached layer, and scrolling only slides that layer,
// so a scroll frame costs what the canvas renderer's cached frame costs while
// a new sample costs one texture write instead of three canvas rasters and a
// blur. Grid and threshold lines are a separate, unscrolled pass.
Item {
    id: gpu

    required property Item diagram

    readonly property bool failed: content.status === ShaderEffect.Error || chrome.status === ShaderEffect.Error
    readonly property bool sliding: diagram.scrolling && diagram.smoothScroll
    readonly property real pad: sliding ? Math.ceil(3 * diagram.step + 16) : 0
    // Serial of the samples the texture holds; the layer slides relative to it.
    property int shownSerial: 0
    readonly property real offset: sliding ? (shownSerial - diagram.sampleSerial - diagram.livePhase) * diagram.step : 0

    // Filled in at paint time: one sample updates several series properties
    // one after another, and encoding on each would repeat the work.
    property var encoded: ({
            width: Data.ROW,
            height: 2,
            stride: 1
        })
    readonly property real topPad: height * Data.TOP_PAD
    readonly property real usedHeight: height * Data.USED
    readonly property color textColor: diagram.textColor

    function band(index) {
        const c = diagram.bands[index];
        return c !== undefined ? Qt.color(c) : Qt.rgba(1, 1, 1, 1);
    }
    function normalised(list, key) {
        const out = [-1, -1, -1, -1];
        let n = 0;
        for (const entry of list) {
            if (n < 4 && (key === "" || entry[key]))
                out[n++] = Math.max(0, Math.min(1, entry.value / diagram.maxValue));
        }
        return Qt.vector4d(out[0], out[1], out[2], out[3]);
    }

    Canvas {
        id: data
        readonly property var inputs: [gpu.diagram.normalized, gpu.diagram.maxValue, gpu.diagram.style]
        property int pendingSerial: gpu.diagram.sampleSerial
        property int paintedSerial: 0
        // One ImageData per texture size, refilled on every paint. A fresh one
        // per paint froze the GPU path: after a few dozen studio edits the JS
        // engine ran a full garbage collection on every allocation, stalling
        // the GUI thread for ~30 s per edit.
        property var image: null
        width: gpu.encoded.width
        height: gpu.encoded.height
        visible: false
        // Nearest sampling: every texel is a number, not a colour to blend.
        smooth: false
        onInputsChanged: requestPaint()
        onPaint: {
            // Read now, not when the data changed: the sample clock ticks just
            // after its history does.
            paintedSerial = pendingSerial;
            const next = Data.encode(gpu.diagram.normalized, gpu.diagram.maxValue, gpu.diagram.style, 2);
            // A new size resizes the canvas, which paints again.
            if (next.width !== width || next.height !== height) {
                gpu.encoded = next;
                return;
            }
            gpu.encoded = next;
            const ctx = getContext("2d");
            if (!image || image.width !== next.width || image.height !== next.height)
                image = ctx.createImageData(next.width, next.height);
            const bytes = next.bytes;
            const pixels = image.data;
            for (let i = 0; i < bytes.length; i++)
                pixels[i] = bytes[i];
            ctx.drawImage(image, 0, 0);
        }
        // Publish the serial together with the pixels, so the slide offset and
        // the texture it applies to change in the same frame.
        onPainted: gpu.shownSerial = paintedSerial
    }

    ShaderEffect {
        id: chrome
        anchors.fill: parent
        visible: gpu.diagram.scrolling
        fragmentShader: Qt.resolvedUrl("../../shaders/diagram.frag.qsb")
        property var dataTex: data
        property size dataSize: Qt.size(data.width, data.height)
        property size itemSize: Qt.size(width, height)
        property rect plot: Qt.rect(gpu.diagram.plotLeft, gpu.topPad, gpu.diagram.plotWidth, gpu.usedHeight)
        property real mode: 9
        property real seriesCount: 0
        property real stride: 1
        property real sampleStep: gpu.diagram.step
        property real phase: 1
        property real smoothLines: 0
        property real glow: 0
        property real pixelRatio: 1
        property color trackColor: "transparent"
        property color gapColor: "transparent"
        property color band1: "transparent"
        property color band2: "transparent"
        property color band3: "transparent"
        property vector4d grid: gpu.normalised(gpu.diagram.ticks, "grid")
        property vector4d markers: gpu.normalised(gpu.diagram.markers, "")
        property color markerColor: gpu.diagram.markers.length ? Qt.alpha(gpu.diagram.markers[0].color, 0.30) : "transparent"
        property color gridColor: Qt.rgba(gpu.textColor.r, gpu.textColor.g, gpu.textColor.b, gpu.diagram.strongGrid ? 0.12 : 0.07)
        property real idle: gpu.diagram.empty ? 1 : 0
    }

    Item {
        id: viewport
        x: gpu.diagram.scrolling ? gpu.diagram.plotLeft : 0
        width: gpu.diagram.scrolling ? gpu.diagram.plotWidth : gpu.width
        height: gpu.height
        clip: gpu.diagram.scrolling

        ShaderEffect {
            id: content
            x: -gpu.pad + gpu.offset
            width: viewport.width + 2 * gpu.pad
            height: viewport.height
            visible: !gpu.diagram.empty
            // Rendered once per change of data or settings, then only moved.
            layer.enabled: true
            layer.smooth: true
            fragmentShader: Qt.resolvedUrl("../../shaders/diagram.frag.qsb")
            property var dataTex: data
            property size dataSize: Qt.size(data.width, data.height)
            property size itemSize: Qt.size(width, height)
            property rect plot: Qt.rect(gpu.pad, gpu.topPad, viewport.width, gpu.usedHeight)
            property real mode: Data.MODES[gpu.diagram.style] ?? 0
            property real seriesCount: Math.min(64, gpu.diagram.normalized.length)
            property real stride: gpu.encoded.stride
            property real sampleStep: gpu.diagram.step
            property real phase: gpu.sliding ? 0 : 1
            property real smoothLines: gpu.diagram.smoothLines ? 1 : 0
            property real glow: gpu.diagram.glow
            property real pixelRatio: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
            property color trackColor: Qt.rgba(gpu.textColor.r, gpu.textColor.g, gpu.textColor.b, 0.12)
            property color gapColor: gpu.diagram.gapColor
            property color band1: gpu.band(0)
            property color band2: gpu.band(1)
            property color band3: gpu.band(2)
            property vector4d grid: Qt.vector4d(-1, -1, -1, -1)
            property vector4d markers: Qt.vector4d(-1, -1, -1, -1)
            property color markerColor: "transparent"
            property color gridColor: "transparent"
            property real idle: 0
        }
    }
}
