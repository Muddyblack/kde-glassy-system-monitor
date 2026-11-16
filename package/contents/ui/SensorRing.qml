import QtQuick

// A small gauge: a track and an arc filled to `ratio` (0..1). A software-painted
// canvas that repaints only when the value or the colour changes.
Canvas {
    id: ring
    property real ratio: 0
    property color color: "white"
    property color track: Qt.rgba(1, 1, 1, 0.12)
    property real thickness: 2.5

    implicitWidth: 16
    implicitHeight: 16
    renderTarget: Canvas.Image
    renderStrategy: Canvas.Cooperative
    onRatioChanged: requestPaint()
    onColorChanged: requestPaint()
    onTrackChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const r = (Math.min(width, height) - thickness) / 2, cx = width / 2, cy = height / 2;
        ctx.lineWidth = thickness;
        ctx.lineCap = "round";
        ctx.strokeStyle = track;
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.stroke();
        const fill = Math.max(0, Math.min(1, ratio));
        if (fill <= 0)
            return;
        ctx.strokeStyle = color;
        ctx.beginPath();
        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * fill);
        ctx.stroke();
    }
}
