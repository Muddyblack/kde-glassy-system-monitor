import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: powerSection
    spacing: 6

    // helper: pick a sign + color for power draw text
    function fmtPower(w) {
        if (Math.abs(w) < 0.05)
            return "0.0W";
        return (w > 0 ? "+" : "") + w.toFixed(1) + "W";
    }
    function powerColor(w) {
        if (w > 0.05)
            return Qt.color("#44dd88");        // charging
        if (w < -0.05)
            return Qt.color("#ffaa22");       // discharging
        return Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55);
    }
    function fmtTime(hours) {
        if (hours <= 0)
            return "—";
        const totalMin = Math.floor(hours * 60);
        const h = Math.floor(totalMin / 60), m = totalMin % 60;
        if (h <= 0)
            return m + "m";
        return h + "h " + (m < 10 ? "0" + m : m) + "m";
    }

    // ── Battery row: bar • status • power ────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.batteryPresent

        // bar
        Item {
            Layout.fillWidth: true
            height: 18

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)

                Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * Math.min(1, root.batteryPercent / 100))
                    height: parent.height
                    radius: parent.radius
                    color: root.batteryPercent <= 15 ? "#ff4444" : root.batteryPercent <= 30 ? "#ffaa00" : "#44dd88"
                    Behavior on width {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 400
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.batteryPercent + "%"
                    font.pixelSize: 9
                    font.bold: true
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }

        // signed power draw
        Text {
            text: powerSection.fmtPower(root.batteryPowerW)
            color: powerSection.powerColor(root.batteryPowerW)
            font.pixelSize: 10
            font.bold: true
            Layout.alignment: Qt.AlignVCenter
            Behavior on color {
                ColorAnimation {
                    duration: 400
                }
            }
        }

        // status
        Text {
            text: root.batteryStatus
            color: root.batteryStatus === "Charging" ? "#44dd88" : root.batteryStatus === "Full" ? "#88ffaa" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
            font.pixelSize: 10
            font.bold: root.batteryStatus === "Charging"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Text {
        visible: !root.batteryPresent
        Layout.fillWidth: true
        text: "No battery"
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.28)
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Power-draw sparkline ─────────────────────────────────────────────────
    Canvas {
        id: powerSpark
        visible: root.batteryPresent
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        readonly property color sparkColor: Qt.color("#88ddff")

        Connections {
            target: root
            function onBatteryPowerHistoryChanged() {
                powerSpark.requestPaint();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const h = root.batteryPowerHistory;
            const n = h.length;

            // baseline zero line
            ctx.strokeStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10);
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, height - 1);
            ctx.lineTo(width, height - 1);
            ctx.stroke();

            if (n < 2) {
                ctx.strokeStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25);
                ctx.lineWidth = 1;
                ctx.setLineDash([3, 4]);
                ctx.beginPath();
                ctx.moveTo(0, height / 2);
                ctx.lineTo(width, height / 2);
                ctx.stroke();
                ctx.setLineDash([]);
                return;
            }

            // auto-scale Y with sensible floor (10W) so idle draw stays visible
            let mx = 10;
            for (let i = 0; i < n; i++)
                if (h[i] > mx)
                    mx = h[i];
            mx *= 1.15;

            const step = width / Math.max(1, n - 1);
            function vx(i) {
                return i * step;
            }
            function vy(v) {
                return height - 2 - (Math.max(0, v) / mx) * (height - 4);
            }

            const cc = powerSpark.sparkColor;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // path
            ctx.beginPath();
            ctx.moveTo(vx(0), vy(h[0]));
            for (let i = 1; i < n; i++) {
                const cx = (vx(i - 1) + vx(i)) / 2;
                ctx.bezierCurveTo(cx, vy(h[i - 1]), cx, vy(h[i]), vx(i), vy(h[i]));
            }

            // glow stroke (double-stroke technique)
            if (plasmoid.configuration.glowLine) {
                ctx.lineWidth = 5;
                ctx.strokeStyle = Qt.rgba(cc.r, cc.g, cc.b, 0.22);
                ctx.stroke();
            }
            // main stroke
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = cc;
            ctx.stroke();

            // fill
            ctx.lineTo(vx(n - 1), height);
            ctx.lineTo(0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(cc.r, cc.g, cc.b, 0.30));
            g.addColorStop(1, Qt.rgba(cc.r, cc.g, cc.b, 0));
            ctx.fillStyle = g;
            ctx.fill();

            // current value badge top-right
            const cur = h[n - 1];
            ctx.fillStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.60);
            ctx.font = "9px sans-serif";
            ctx.textAlign = "right";
            ctx.fillText(cur.toFixed(1) + "W", width - 3, 10);
        }
    }

    // ── Diagnostic stat row: Health · Temp · Cycles · ETA ────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: root.batteryPresent

        // each "chip" takes equal share
        Repeater {
            model: [
                {
                    lbl: "Health",
                    val: root.batteryHealthPct > 0 ? root.batteryHealthPct.toFixed(0) + "%" : "—",
                    tint: root.batteryHealthPct >= 90 ? "#44dd88" : root.batteryHealthPct >= 75 ? "#ffaa22" : root.batteryHealthPct > 0 ? "#ff8844" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
                },
                {
                    lbl: "Temp",
                    val: root.batteryTempC > -100 ? root.batteryTempC.toFixed(0) + "°C" : "—",
                    tint: root.batteryTempC <= -100 ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55) : root.batteryTempC >= 45 ? "#ff8844" : root.batteryTempC >= 35 ? "#ffaa22" : "#44ddaa"
                },
                {
                    lbl: "Cycles",
                    val: root.batteryCycles >= 0 ? root.batteryCycles.toString() : "—",
                    tint: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.85)
                },
                {
                    lbl: root.batteryPowerW > 0.05 ? "Until full" : root.batteryPowerW < -0.05 ? "Remaining" : "Time",
                    val: powerSection.fmtTime(root.batteryTimeRemainHours),
                    tint: root.batteryTimeRemainHours > 0 ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.85) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
                }
            ]

            Item {
                Layout.fillWidth: true
                implicitHeight: 26

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05)
                    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.07)
                    border.width: 1
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        text: modelData.lbl
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.42)
                        font.pixelSize: 8
                        font.letterSpacing: 0.3
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: modelData.val
                        color: modelData.tint
                        font.pixelSize: 11
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: 400
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Pressure section ─────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 3
        height: 1
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
    }

    component PressureRow: Item {
        property string label: ""
        property real value: 0
        property color barColor: root.textColor
        readonly property real _fill: Math.min(1, value / 20)

        Layout.fillWidth: true
        height: 20

        Text {
            id: _lbl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
            font.pixelSize: 11
            width: 90
        }

        Item {
            anchors.left: _lbl.right
            anchors.leftMargin: 6
            anchors.right: _val.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * _fill)
                    height: parent.height
                    radius: parent.radius
                    color: barColor
                    opacity: 0.85
                    Behavior on width {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Text {
            id: _val
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: value.toFixed(2) + "%"
            color: value >= 10 ? barColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.65)
            font.pixelSize: 11
            font.bold: value >= 5
            width: 48
            horizontalAlignment: Text.AlignRight
        }
    }

    PressureRow {
        label: "CPU pressure"
        value: root.cpuPressureAvg10
        barColor: "#ff6644"
    }

    PressureRow {
        label: "MEM pressure"
        value: root.memPressureAvg10
        barColor: "#aa66ff"
    }

    Item {
        Layout.fillHeight: true
    }
}
