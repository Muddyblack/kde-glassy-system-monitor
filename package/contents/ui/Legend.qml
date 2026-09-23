import QtQuick

// Chart legend: swatch, name and live value per line. Clicking an entry hides
// its line, hovering highlights it; both are the monitor's shared state.
//   entries: [{ key, label, value, color }]
Flow {
    id: legend

    required property var monitor
    property var entries: []
    property real indent: 0

    leftPadding: indent
    spacing: 12

    Repeater {
        model: legend.entries
        Item {
            id: entry
            required property var modelData
            readonly property bool shown: !legend.monitor.isLineDisabled(modelData.key)
            readonly property color tint: modelData.color
            readonly property color ink: legend.monitor.textColor
            implicitWidth: row.implicitWidth
            implicitHeight: row.implicitHeight
            opacity: legend.monitor.hoveredLine !== "" && legend.monitor.hoveredLine !== modelData.key ? 0.55 : 1

            Row {
                id: row
                spacing: 5
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 2
                    color: entry.shown ? entry.tint : "transparent"
                    border.color: entry.tint
                    border.width: 1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.modelData.label
                    color: Qt.rgba(entry.ink.r, entry.ink.g, entry.ink.b, entry.shown ? 0.7 : 0.3)
                    font.pixelSize: 10
                    font.strikeout: !entry.shown
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: entry.modelData.value || ""
                    color: entry.shown ? entry.tint : Qt.rgba(entry.tint.r, entry.tint.g, entry.tint.b, 0.3)
                    font.pixelSize: 11
                    font.bold: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: legend.monitor.toggleLineDisabled(entry.modelData.key)
                onEntered: legend.monitor.hoveredLine = entry.modelData.key
                onExited: if (legend.monitor.hoveredLine === entry.modelData.key)
                    legend.monitor.hoveredLine = ""
            }
        }
    }
}
