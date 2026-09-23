import QtQuick
import "../Format.js" as Format

// Download and upload over time: two filled lines on an auto scale.
Item {
    id: chart
    required property var theme
    property var seriesIn: []
    property var seriesOut: []
    property int capacity: 90
    // Seconds between samples, for "12 s ago" on hover; and the value format.
    property real step: 2
    property var format: Format.speed
    property string inLabel: "↓"
    property string outLabel: "↑"
    property int hovered: -1
    // The scale never goes below this (1 KiB/s; 1 ms for latency).
    property real floor: 1024
    readonly property real peak: {
        let m = chart.floor;
        for (const v of seriesIn)
            m = Math.max(m, v);
        for (const v of seriesOut)
            m = Math.max(m, v);
        return m * 1.15;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.leftMargin: 64
        readonly property var signature: [chart.seriesIn, chart.seriesOut, chart.theme, width, height]
        onSignatureChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            ctx.strokeStyle = chart.theme.grid;
            ctx.lineWidth = 1;
            for (let g = 0; g <= 4; g++) {
                const y = Math.round(h * g / 4) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(w, y);
                ctx.stroke();
            }
            const draw = (data, color) => {
                if (data.length < 2)
                    return;
                const step = w / (chart.capacity - 1);
                const x0 = w - (data.length - 1) * step;
                const pt = k => [x0 + k * step, h - Math.min(1, data[k] / chart.peak) * (h - 2) - 1];
                ctx.beginPath();
                ctx.moveTo(pt(0)[0], h);
                for (let k = 0; k < data.length; k++)
                    ctx.lineTo(pt(k)[0], pt(k)[1]);
                ctx.lineTo(pt(data.length - 1)[0], h);
                ctx.closePath();
                const c = Qt.color(color);
                const grad = ctx.createLinearGradient(0, 0, 0, h);
                grad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.32));
                grad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.02));
                ctx.fillStyle = grad;
                ctx.fill();
                ctx.beginPath();
                for (let k = 0; k < data.length; k++)
                    k === 0 ? ctx.moveTo(pt(k)[0], pt(k)[1]) : ctx.lineTo(pt(k)[0], pt(k)[1]);
                ctx.strokeStyle = color;
                ctx.lineWidth = 1.8;
                ctx.lineJoin = "round";
                ctx.stroke();
            };
            draw(chart.seriesOut, chart.theme.tx);
            draw(chart.seriesIn, chart.theme.rx);
        }
    }
    Repeater {
        model: 5
        Text {
            required property int index
            x: 0
            width: 56
            horizontalAlignment: Text.AlignRight
            y: Math.max(0, Math.min(chart.height - height, chart.height * index / 4 - height / 2))
            text: chart.format(chart.peak * (4 - index) / 4)
            color: chart.theme.dim
            font.family: chart.theme.fontFamily
            font.pixelSize: 9
        }
    }

    // Hover: a line at the sample under the pointer, dots on both series,
    // and the values with how long ago they were.
    MouseArea {
        id: hover
        anchors.fill: canvas
        hoverEnabled: true
        readonly property int count: Math.max(chart.seriesIn.length, chart.seriesOut.length)
        readonly property real stepX: canvas.width / Math.max(1, chart.capacity - 1)
        onPositionChanged: mouse => {
            const n = count;
            const k = Math.round((mouse.x - (canvas.width - (n - 1) * stepX)) / stepX);
            chart.hovered = n > 0 && k >= 0 && k < n ? k : -1;
        }
        onExited: chart.hovered = -1
    }
    Item {
        visible: chart.hovered >= 0
        x: canvas.x + canvas.width - (hover.count - 1 - chart.hovered) * hover.stepX
        y: canvas.y
        height: canvas.height
        readonly property real vin: chart.seriesIn[chart.hovered] || 0
        readonly property real vout: chart.seriesOut[chart.hovered] || 0
        Rectangle {
            width: 1
            height: parent.height
            color: chart.theme.muted
            opacity: 0.6
        }
        Rectangle {
            visible: chart.seriesIn.length > 0
            x: -3.5
            y: parent.height - 1 - Math.min(1, parent.vin / chart.peak) * (parent.height - 2) - 3.5
            width: 7
            height: 7
            radius: 3.5
            color: chart.theme.rx
            border.color: chart.theme.bg
        }
        Rectangle {
            visible: chart.seriesOut.length > 0
            x: -3.5
            y: parent.height - 1 - Math.min(1, parent.vout / chart.peak) * (parent.height - 2) - 3.5
            width: 7
            height: 7
            radius: 3.5
            color: chart.theme.tx
            border.color: chart.theme.bg
        }
        Rectangle {
            readonly property bool flip: parent.x + width + 12 > chart.width
            x: flip ? -width - 8 : 8
            y: 2
            width: tip.implicitWidth + 16
            height: tip.implicitHeight + 10
            radius: 6
            color: chart.theme.popup
            border.color: chart.theme.line2
            Text {
                id: tip
                anchors.centerIn: parent
                readonly property real ago: (hover.count - 1 - chart.hovered) * chart.step
                text: (ago < 1 ? "now" : ago < 120 ? Math.round(ago) + " s ago" : Math.round(ago / 60) + " min ago") + (chart.seriesIn.length ? "\n" + chart.inLabel + " " + chart.format(parent.parent.vin) : "") + (chart.seriesOut.length ? "\n" + chart.outLabel + " " + chart.format(parent.parent.vout) : "")
                color: chart.theme.text
                font.family: chart.theme.fontFamily
                font.pixelSize: 10
                lineHeight: 1.15
            }
        }
    }
}
