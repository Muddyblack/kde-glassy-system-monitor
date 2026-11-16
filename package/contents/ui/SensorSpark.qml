import QtQuick
import "SensorConfig.js" as Sensors

// One reading's recent history as a small line. A software-painted canvas that
// repaints only when a sample arrives: no shader, no animation, a few KB.
Canvas {
    id: spark
    property var values: []
    property real least: 1
    property color color: "white"
    property real lineWidth: 1.5

    // Redrawn on a new sample, a resize or a colour change only.
    readonly property var points: Sensors.sparkPoints(values, least)
    onPointsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()

    renderTarget: Canvas.Image
    renderStrategy: Canvas.Cooperative
    implicitHeight: 14

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const p = points, pad = 1.5, w = width, h = height - pad * 2;
        if (p.length < 2 || w <= 0 || h <= 0) {
            // Until two samples exist: a faint baseline, so the row is not empty.
            ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.25);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, height / 2);
            ctx.lineTo(w, height / 2);
            ctx.stroke();
            return;
        }
        ctx.beginPath();
        for (let i = 0; i < p.length; ++i) {
            const x = p[i].x * w, y = pad + (1 - p[i].y) * h;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.lineJoin = "round";
        ctx.lineWidth = lineWidth;
        ctx.strokeStyle = color;
        ctx.stroke();
        // A soft fill under the line.
        ctx.lineTo(w, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.16);
        ctx.fill();
    }
}
