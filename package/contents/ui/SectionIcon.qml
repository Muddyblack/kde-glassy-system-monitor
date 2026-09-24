import QtQuick

// A section's line icon (the 24×24 SVG path in Sections.js), stroked.
Canvas {
    id: icon
    property string path: ""
    property color color: "white"
    property real lineWidth: 1.8
    onPathChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = icon.getContext("2d");
        ctx.reset();
        if (!icon.path || icon.width <= 0)
            return;
        ctx.scale(icon.width / 24, icon.height / 24);
        ctx.strokeStyle = icon.color;
        ctx.lineWidth = icon.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.path = icon.path;
        ctx.stroke();
    }
}
