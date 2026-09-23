import QtQuick

// A tiny download / upload trend: two lines on a shared scale.
Canvas {
    id: spark
    required property var theme
    property var seriesIn: []
    property var seriesOut: []
    property int capacity: 45
    implicitWidth: 90
    implicitHeight: 24
    property var format: v => {
        if (v >= 1048576)
            return (v / 1048576).toFixed(1) + " MiB/s";
        if (v >= 1024)
            return (v / 1024).toFixed(1) + " KiB/s";
        return Math.round(v) + " B/s";
    }
    property int hovered: -1
    readonly property int count: Math.max(seriesIn.length, seriesOut.length)

    readonly property var signature: [seriesIn, seriesOut, theme, width, height, hovered]
    onSignatureChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        let peak = 1;
        for (const v of seriesIn)
            peak = Math.max(peak, v);
        for (const v of seriesOut)
            peak = Math.max(peak, v);
        const step = width / Math.max(1, capacity - 1);
        const line = (data, color, fill) => {
            if (data.length < 2)
                return;
            const x0 = width - (data.length - 1) * step;
            const y = v => height - 1 - v / peak * (height - 2);
            ctx.beginPath();
            ctx.moveTo(x0, y(data[0]));
            for (let k = 1; k < data.length; k++)
                ctx.lineTo(x0 + k * step, y(data[k]));
            if (fill) {
                ctx.lineTo(x0 + (data.length - 1) * step, height);
                ctx.lineTo(x0, height);
                ctx.closePath();
                const c = Qt.color(color);
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.18);
                ctx.fill();
                return;
            }
            ctx.strokeStyle = color;
            ctx.lineWidth = 1.3;
            ctx.lineJoin = "round";
            ctx.stroke();
        };
        line(seriesIn, spark.theme.rx, true);
        line(seriesOut, spark.theme.tx, false);
        line(seriesIn, spark.theme.rx, false);
        if (hovered >= 0) {
            const x = width - (count - 1 - hovered) * step;
            ctx.strokeStyle = spark.theme.muted;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x, 0);
            ctx.lineTo(x, height);
            ctx.stroke();
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => {
            const step = spark.width / Math.max(1, spark.capacity - 1);
            const k = Math.round((mouse.x - (spark.width - (spark.count - 1) * step)) / step);
            spark.hovered = spark.count > 0 && k >= 0 && k < spark.count ? k : -1;
        }
        onExited: spark.hovered = -1
    }
    Rectangle {
        visible: spark.hovered >= 0
        z: 10
        x: Math.min(spark.width - width, Math.max(0, area.mouseX - width / 2))
        y: -height - 4
        width: sparkTip.implicitWidth + 12
        height: sparkTip.implicitHeight + 6
        radius: 5
        color: spark.theme.popup
        border.color: spark.theme.line2
        Text {
            id: sparkTip
            anchors.centerIn: parent
            text: "↓ " + spark.format(spark.seriesIn[spark.hovered] || 0) + "   ↑ " + spark.format(spark.seriesOut[spark.hovered] || 0)
            color: spark.theme.text
            font.family: spark.theme.fontFamily
            font.pixelSize: 9
        }
    }
}
