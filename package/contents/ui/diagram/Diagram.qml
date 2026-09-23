import QtQuick
import "DiagramData.js" as Data

// One chart, whatever it shows. Sections hand over series and a scale; the
// diagram picks a renderer and lays out its own labels. Text (axis labels,
// gauge readouts, meter captions) is always QML Text, never shader or canvas.
//
//   series: [{ values, value, color, alpha, width, fill, glow, head, gaps,
//              bands, ring, label, text }]
//   values are raw numbers scaled by maxValue; a negative or null value is a
//   gap (lost ping), `value` is the current reading gauges and meters show.
Item {
    id: chart

    property string style: "line"
    property var series: []
    property real maxValue: 100
    property int historySize: 60
    property int sampleSerial: 0
    // Drawn scroll phase from the metric's SampleClock; ignored when static.
    property real livePhase: 0
    property bool smoothScroll: true
    property bool smoothLines: true
    property real lineWidth: 2.2
    // 0 disables glow; up to 1 for the full halo.
    property real glow: 0.6
    // Canvas renderer only: blur the halo on the GPU instead of stroking it.
    property bool bloom: true
    property bool axis: true
    property bool strongGrid: false
    property var ticks: []
    property var markers: []
    property var bands: []
    property color gapColor: "#ff4444"
    property color textColor: "white"
    // "gpu" (fragment shader) or "canvas" (Context2D, the pre-shader path).
    property string renderer: "gpu"
    property bool onScreen: true
    property string centerText: ""
    property string centerSubText: ""

    readonly property bool scrolling: Data.scrolls(style)
    readonly property bool meter: style === "meter"
    readonly property real plotLeft: scrolling && axis ? 38 : 0
    readonly property real plotWidth: Math.max(0, width - plotLeft)
    readonly property real step: plotWidth / Math.max(1, Math.max(10, historySize) - 1)
    readonly property var normalized: series.map(s => Data.normalize(s, {
            lineWidth: chart.lineWidth,
            fill: chart.style === "area" ? 0.62 : chart.style === "line" ? 0.35 : 0
        }))
    readonly property bool empty: normalized.every(s => Data.isGauge(style) || meter ? s.value === undefined && s.values.length === 0 : s.values.length < (style === "bars" ? 1 : 2))
    // The API is Unknown until the window is exposed; assume a GPU until then.
    readonly property bool shaderCapable: GraphicsInfo.api !== GraphicsInfo.Software
    readonly property bool usingShader: renderer === "gpu" && shaderCapable && !(gpuLoader.item && gpuLoader.item.failed)
    // Labels at least 20 px apart: the ends always, middle ones when there's room.
    readonly property var visibleTicks: {
        const out = [];
        let lastY = -1e9;
        const sorted = ticks.slice().sort((a, b) => b.value - a.value);
        sorted.forEach((t, i) => {
            const y = Data.yOf(t.value, maxValue, height);
            const end = i === 0 || i === sorted.length - 1;
            if (end && i > 0 && y - lastY < 20 && out.length > 1)
                out.pop();
            if (end || y - lastY >= 20) {
                out.push(t);
                lastY = y;
            }
        });
        return out;
    }

    // Canvas renderer only: both sides of a paint, for stall detection.
    signal paintRequested
    signal painted

    // Redraw from scratch, e.g. after the widget was off screen.
    function repaint() {
        if (canvasLoader.item)
            canvasLoader.item.requestPaint();
    }

    Loader {
        id: gpuLoader
        anchors.fill: parent
        active: !chart.meter && chart.renderer === "gpu" && chart.shaderCapable
        visible: chart.usingShader
        sourceComponent: DiagramShader {
            diagram: chart
        }
    }
    Loader {
        id: canvasLoader
        anchors.fill: parent
        active: !chart.meter && !chart.usingShader
        sourceComponent: DiagramCanvas {
            diagram: chart
        }
    }

    // Axis labels: a bold number, the unit small beneath it.
    Repeater {
        model: chart.scrolling && chart.axis && !chart.empty ? chart.visibleTicks : []
        Column {
            required property var modelData
            readonly property int split: modelData.text.lastIndexOf(" ")
            x: chart.plotLeft - 4 - width
            y: Data.yOf(modelData.value, chart.maxValue, chart.height) - 9
            Text {
                anchors.right: parent.right
                text: parent.split > 0 ? parent.modelData.text.slice(0, parent.split) : parent.modelData.text
                color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.65)
                font.pixelSize: 10
                font.bold: true
            }
            Text {
                anchors.right: parent.right
                visible: parent.split > 0
                text: parent.modelData.text.slice(parent.split + 1)
                color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.38)
                font.pixelSize: 8
            }
        }
    }

    // Gauge readout in the ring's centre.
    Column {
        readonly property real radius: Math.min(chart.plotWidth, chart.height) * 0.36
        visible: Data.isGauge(chart.style) && chart.centerText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: chart.centerText
            color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.92)
            font.pixelSize: Math.max(8, Math.round(parent.radius * 0.40))
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: chart.centerSubText !== ""
            text: chart.centerSubText
            color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.42)
            font.pixelSize: Math.max(7, Math.round(parent.radius * 0.22))
        }
    }

    // Meters are plain rounded rectangles in both renderers.
    Grid {
        id: meters
        visible: chart.meter
        readonly property int count: chart.normalized.length
        columns: count > 8 ? 4 : count > 4 ? 2 : 1
        readonly property int rowCount: Math.max(1, Math.ceil(count / columns))
        readonly property real barHeight: count > 4 ? Math.max(6, Math.min(10, (chart.height - 10 - (rowCount - 1) * 18) / rowCount)) : 12
        x: 10
        width: chart.width - 20
        anchors.verticalCenter: parent.verticalCenter
        columnSpacing: 8
        rowSpacing: 6
        Repeater {
            model: chart.meter ? chart.normalized : []
            Column {
                required property var modelData
                readonly property real fraction: Math.max(0, Math.min(1, Data.gaugeValue(modelData) / chart.maxValue))
                width: (meters.width - (meters.columns - 1) * meters.columnSpacing) / meters.columns
                spacing: 2
                opacity: modelData.alpha
                Item {
                    width: parent.width
                    height: caption.implicitHeight
                    Text {
                        id: caption
                        width: parent.width - reading.implicitWidth - 6
                        text: parent.parent.modelData.label
                        elide: Text.ElideRight
                        color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.65)
                        font.pixelSize: 9
                    }
                    Text {
                        id: reading
                        anchors.right: parent.right
                        text: parent.parent.modelData.text
                        color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.9)
                        font.pixelSize: 9
                        font.bold: true
                    }
                }
                Rectangle {
                    width: parent.width
                    height: meters.barHeight
                    radius: height / 2
                    color: Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.08)
                    Rectangle {
                        visible: chart.glow > 0 && parent.parent.modelData.glow && parent.parent.fraction > 0
                        x: -3
                        y: -3
                        width: fill.width + 6
                        height: parent.height + 6
                        radius: height / 2
                        color: Qt.alpha(parent.parent.modelData.color, 0.18)
                    }
                    Rectangle {
                        id: fill
                        visible: parent.parent.fraction > 0
                        width: Math.max(parent.height, parent.width * parent.parent.fraction)
                        height: parent.height
                        radius: height / 2
                        color: parent.parent.modelData.color
                    }
                }
            }
        }
    }
}
