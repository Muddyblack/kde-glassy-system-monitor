import QtQuick
import QtQuick.Layouts
import "SensorConfig.js" as Sensors

// The sensor readings chosen for one section (see SensorConfig.js):
// "grouped" rows under a header per device (Sensors), "bars" (Power's
// where-the-power-goes) or a compact "grid" (CPU, GPU).
ColumnLayout {
    id: readings
    required property var monitor
    required property var cfg
    required property string targetSection
    property string layout: "grid"

    readonly property var shown: Sensors.rows(monitor.sensorCatalog, cfg, targetSection)
    readonly property var rows: layout === "grouped" ? Sensors.grouped(shown) : shown
    readonly property real maxWatts: Math.max.apply(null, [1].concat(shown.filter(s => s.type === "power").map(s => s.value || 0)))
    // Delegates follow the ids only, so a new sample updates them in place
    // and the bars animate.
    readonly property string rowKeys: JSON.stringify(rows.map(s => s.id))
    readonly property int count: shown.length

    function ink(alpha) {
        return Qt.rgba(monitor.textColor.r, monitor.textColor.g, monitor.textColor.b, alpha);
    }
    function tint(sensor) {
        const c = Sensors.tint(sensor, cfg);
        return c ? Qt.color(c) : monitor.textColor;
    }

    visible: count > 0
    spacing: 1

    GridLayout {
        Layout.fillWidth: true
        visible: readings.layout === "grid"
        columns: readings.width > 360 ? 3 : 2
        columnSpacing: 10
        rowSpacing: 0
        Repeater {
            model: readings.layout === "grid" ? JSON.parse(readings.rowKeys) : []
            RowLayout {
                id: cell
                required property int index
                readonly property var sensor: readings.rows[index] || {}
                readonly property color tint: readings.tint(sensor)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 20
                spacing: 5
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 2
                    color: cell.tint
                }
                Text {
                    Layout.fillWidth: true
                    font.family: readings.monitor.fontFamily
                    font.pixelSize: 10
                    text: cell.sensor.label || ""
                    textFormat: Text.PlainText
                    color: readings.monitor.textColor
                    opacity: 0.7
                    elide: Text.ElideRight
                }
                Text {
                    font.family: readings.monitor.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    text: Sensors.reading(cell.sensor)
                    color: cell.tint
                }
            }
        }
    }

    Repeater {
        model: readings.layout === "grid" ? [] : JSON.parse(readings.rowKeys)
        Item {
            id: row
            required property int index
            readonly property var sensor: readings.rows[index] || {}
            readonly property color tint: readings.tint(sensor)
            readonly property real fill: Sensors.ratio(sensor, readings.cfg, readings.maxWatts)
            Layout.fillWidth: true
            Layout.topMargin: sensor.header && index > 0 ? 5 : 0
            implicitHeight: sensor.header ? 16 : 20

            // Device header: name, rule, hottest reading.
            RowLayout {
                visible: !!row.sensor.header
                anchors.fill: parent
                spacing: 6
                Text {
                    font.family: readings.monitor.fontFamily
                    text: row.sensor.label || ""
                    textFormat: Text.PlainText
                    color: readings.ink(0.85)
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 0.4
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: readings.ink(0.10)
                }
                Text {
                    font.family: readings.monitor.fontFamily
                    visible: row.sensor.value > 0
                    text: "max " + (row.sensor.value || 0).toFixed(0) + "°C"
                    color: Sensors.tint({
                        type: "temp",
                        value: row.sensor.value,
                        crit: row.sensor.crit
                    }, readings.cfg)
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            // Reading: label, bar (or per-core bars, or a fan line), value.
            Item {
                visible: !row.sensor.header
                anchors.fill: parent
                Text {
                    id: label
                    font.family: readings.monitor.fontFamily
                    anchors.left: parent.left
                    anchors.leftMargin: readings.layout === "grouped" ? 4 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(readings.layout === "grouped" ? 90 : 110, parent.width * 0.34)
                    text: row.sensor.label || ""
                    textFormat: Text.PlainText
                    color: readings.ink(0.62)
                    font.pixelSize: readings.layout === "grouped" ? 11 : 10
                    elide: Text.ElideRight
                }
                Item {
                    anchors.left: label.right
                    anchors.leftMargin: 6
                    anchors.right: value.left
                    anchors.rightMargin: 6
                    height: parent.height
                    Rectangle {
                        visible: row.fill >= 0 && row.sensor.type !== "cores"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: readings.layout === "grouped" ? 5 : 4
                        radius: height / 2
                        color: readings.ink(0.10)
                        Rectangle {
                            width: Math.max(parent.radius * 2, parent.width * Math.max(0, row.fill))
                            height: parent.height
                            radius: parent.radius
                            color: row.tint
                            opacity: 0.9
                            Behavior on width {
                                NumberAnimation {
                                    duration: 600
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                    Row {
                        visible: row.sensor.type === "cores"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 12
                        spacing: 1
                        Repeater {
                            model: row.sensor.type === "cores" ? row.sensor.values.length : 0
                            Item {
                                required property int index
                                readonly property real temp: (row.sensor.values || [])[index] || 0
                                readonly property var reading: ({
                                        type: "temp",
                                        value: temp,
                                        crit: row.sensor.crit
                                    })
                                width: Math.max(2, (parent.width - (row.sensor.values.length - 1)) / row.sensor.values.length)
                                height: 12
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 2
                                    radius: 1
                                    color: readings.ink(0.10)
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, 12 * Sensors.ratio(parent.reading, readings.cfg, 0))
                                    radius: 1
                                    color: Sensors.tint(parent.reading, readings.cfg)
                                    opacity: 0.92
                                    Behavior on height {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: row.sensor.type === "fan"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 2
                        radius: 1
                        color: Qt.alpha(row.tint, 0.35)
                    }
                }
                Text {
                    id: value
                    font.family: readings.monitor.fontFamily
                    anchors.right: parent.right
                    anchors.rightMargin: readings.layout === "grouped" ? 4 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    horizontalAlignment: Text.AlignRight
                    text: Sensors.reading(row.sensor)
                    color: row.tint
                    font.pixelSize: readings.layout === "grouped" ? 11 : 10
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
