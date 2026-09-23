import QtQuick
import QtQuick.Layouts
import "diagram"
import "SectionModels.js" as SectionModels

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "power"
    readonly property real preferredHeight: implicitHeight + 8
    readonly property real minimumHeight: preferredHeight

    spacing: 6

    SectionHeader {
        Layout.fillWidth: true
        title: section.monitor.sectionTitle("power")
        reading: section.monitor.batteryPresent ? section.monitor.batteryPercent + "%" : ""
        readingColor: section.monitor.batteryPercent <= 15 ? "#ff4444" : section.monitor.batteryPercent <= 30 ? "#ffaa00" : "#44dd88"
        textColor: section.monitor.textColor
    }

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
        return Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.55);
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
        visible: section.monitor.batteryPresent

        // bar
        Item {
            Layout.fillWidth: true
            implicitHeight: 18

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.10)

                Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * Math.min(1, section.monitor.batteryPercent / 100))
                    height: parent.height
                    radius: parent.radius
                    color: section.monitor.batteryPercent <= 15 ? "#ff4444" : section.monitor.batteryPercent <= 30 ? "#ffaa00" : "#44dd88"
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
                    text: section.monitor.batteryPercent + "%"
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
            text: section.fmtPower(section.monitor.batteryPowerW)
            color: section.powerColor(section.monitor.batteryPowerW)
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
            text: section.monitor.batteryStatus
            color: section.monitor.batteryStatus === "Charging" ? "#44dd88" : section.monitor.batteryStatus === "Full" ? "#88ffaa" : Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.55)
            font.pixelSize: 10
            font.bold: section.monitor.batteryStatus === "Charging"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Text {
        visible: !section.monitor.batteryPresent
        Layout.fillWidth: true
        text: "No battery"
        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.28)
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Power-draw history ───────────────────────────────────────────────────
    Diagram {
        id: spark
        visible: section.monitor.batteryPresent
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        style: "area"
        axis: false
        renderer: section.cfg.chartRenderer === "canvas" ? "canvas" : "gpu"
        historySize: Math.max(10, section.cfg.historySize || 60)
        smoothScroll: false
        lineWidth: 1.5
        glow: section.cfg.glowLine ? 0.5 : 0
        textColor: section.monitor.textColor
        onScreen: section.monitor.onScreen
        maxValue: SectionModels.power(section.monitor).maxValue
        series: SectionModels.power(section.monitor).series
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 3
            y: 1
            visible: section.monitor.batteryPowerHistory.length > 0
            text: Math.abs(section.monitor.batteryPowerW).toFixed(1) + "W"
            color: section.monitor.textColor
            opacity: 0.6
            font.pixelSize: 9
        }
    }

    // ── Diagnostic stat row: Health · Temp · Cycles · ETA ────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: section.monitor.batteryPresent

        // each "chip" takes equal share
        Repeater {
            model: [
                {
                    lbl: "Health",
                    val: section.monitor.batteryHealthPct > 0 ? section.monitor.batteryHealthPct.toFixed(0) + "%" : "—",
                    tint: section.monitor.batteryHealthPct >= 90 ? "#44dd88" : section.monitor.batteryHealthPct >= 75 ? "#ffaa22" : section.monitor.batteryHealthPct > 0 ? "#ff8844" : Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.55)
                },
                {
                    lbl: "Temp",
                    val: section.monitor.batteryTempC > -100 ? section.monitor.batteryTempC.toFixed(0) + "°C" : "—",
                    tint: section.monitor.batteryTempC <= -100 ? Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.55) : section.monitor.batteryTempC >= 45 ? "#ff8844" : section.monitor.batteryTempC >= 35 ? "#ffaa22" : "#44ddaa"
                },
                {
                    lbl: "Cycles",
                    val: section.monitor.batteryCycles >= 0 ? section.monitor.batteryCycles.toString() : "—",
                    tint: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.85)
                },
                {
                    lbl: section.monitor.batteryPowerW > 0.05 ? "Until full" : section.monitor.batteryPowerW < -0.05 ? "Remaining" : "Time",
                    val: section.fmtTime(section.monitor.batteryTimeRemainHours),
                    tint: section.monitor.batteryTimeRemainHours > 0 ? Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.85) : Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.45)
                }
            ]

            Item {
                Layout.fillWidth: true
                implicitHeight: 26

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.05)
                    border.color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.07)
                    border.width: 1
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        text: modelData.lbl
                        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.42)
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
        implicitHeight: 1
        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.10)
    }

    component PressureRow: Item {
        property string label: ""
        property real value: 0
        property color barColor: section.monitor.textColor
        readonly property real _fill: Math.min(1, value / 20)

        Layout.fillWidth: true
        implicitHeight: 20

        Text {
            id: labelText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.45)
            font.pixelSize: 11
            width: 90
        }

        Item {
            anchors.left: labelText.right
            anchors.leftMargin: 6
            anchors.right: valueText.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: 4

            Rectangle {
                anchors.fill: parent
                radius: 2
                color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.10)
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
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: value.toFixed(2) + "%"
            color: value >= 10 ? barColor : Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.65)
            font.pixelSize: 11
            font.bold: value >= 5
            width: 48
            horizontalAlignment: Text.AlignRight
        }
    }

    PressureRow {
        label: "CPU pressure"
        value: section.monitor.cpuPressureAvg10
        barColor: "#ff6644"
    }

    PressureRow {
        label: "MEM pressure"
        value: section.monitor.memPressureAvg10
        barColor: "#aa66ff"
    }

    Item {
        Layout.fillHeight: true
    }
}
