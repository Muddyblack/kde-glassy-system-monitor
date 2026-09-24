import QtQuick
import QtQuick.Layouts

// A section that is a list of labelled bars: storage and top processes.
// `model` comes from SectionModels (shared with the website).
ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    required property string sectionId
    required property var model
    readonly property real rowHeight: 20
    // Rows never scroll or cut: the section is as tall as its rows.
    readonly property real preferredHeight: header.implicitHeight + Math.max(1, model.rows.length) * rowHeight + 10
    readonly property real minimumHeight: preferredHeight

    readonly property color ink: monitor.textColor
    function inkAlpha(a) {
        return Qt.rgba(ink.r, ink.g, ink.b, a);
    }

    spacing: 2

    // The row whose ✕ was clicked once, by label: rows are rebuilt on every
    // poll, so the delegates cannot hold it.
    property string armed: ""
    Timer {
        id: disarm
        interval: 3000
        onTriggered: section.armed = ""
    }

    SectionHeader {
        id: header
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        Layout.bottomMargin: 2
        title: section.model.title
        reading: section.model.reading
        readingColor: section.model.readingColor || section.inkAlpha(0.55)
        textColor: section.ink
    }

    Text {
        font.family: section.monitor.fontFamily
        visible: section.model.rows.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: section.rowHeight
        text: section.model.empty
        color: section.inkAlpha(0.4)
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: section.model.rows
        RowLayout {
            id: row
            required property var modelData
            // Rows without a bar (ratio < 0) show a state dot instead.
            readonly property bool dot: modelData.ratio < 0
            readonly property color tint: modelData.color ? modelData.color : section.inkAlpha(0.45)
            // Process rows: ✕ asks, a second click within three seconds
            // ends them (SIGTERM; with Shift, SIGKILL).
            readonly property bool killable: !!modelData.pids && modelData.pids.length > 0 && !!section.monitor.killProcesses
            readonly property bool armed: section.armed !== "" && section.armed === modelData.label
            Layout.fillWidth: true
            Layout.preferredHeight: section.rowHeight
            spacing: 6

            HoverHandler {
                id: rowHover
            }

            Rectangle {
                visible: row.dot
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: row.tint
            }
            Text {
                font.family: section.monitor.fontFamily
                Layout.preferredWidth: row.dot ? -1 : Math.min(120, section.width * 0.34)
                Layout.maximumWidth: row.dot ? section.width * 0.45 : -1
                text: row.modelData.label
                color: section.inkAlpha(0.72)
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
            Rectangle {
                visible: !row.dot
                Layout.fillWidth: true
                Layout.minimumWidth: 30
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 5
                radius: 2.5
                color: section.inkAlpha(0.10)
                Rectangle {
                    width: Math.max(parent.radius * 2, parent.width * Math.min(1, row.modelData.ratio))
                    height: parent.height
                    radius: parent.radius
                    color: row.tint
                }
            }
            Text {
                font.family: section.monitor.fontFamily
                Layout.fillWidth: row.dot
                text: row.modelData.detail
                color: section.inkAlpha(0.45)
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Text {
                font.family: section.monitor.fontFamily
                Layout.preferredWidth: Math.max(44, implicitWidth)
                horizontalAlignment: Text.AlignRight
                text: row.armed ? "end?" : row.modelData.value
                color: row.armed ? "#ff5555" : row.tint
                font.pixelSize: 11
                font.bold: true
            }
            Text {
                visible: row.killable
                Layout.preferredWidth: 12
                horizontalAlignment: Text.AlignHCenter
                text: "✕"
                opacity: row.armed ? 1 : rowHover.hovered ? 0.7 : 0
                color: row.armed || killArea.containsMouse ? "#ff5555" : section.ink
                font.pixelSize: 10
                MouseArea {
                    id: killArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (!row.armed) {
                            section.armed = row.modelData.label;
                            disarm.restart();
                            return;
                        }
                        section.armed = "";
                        section.monitor.killProcesses(row.modelData.pids, !!(mouse.modifiers & Qt.ShiftModifier));
                    }
                }
            }
        }
    }

    // A taller grid neighbour must not spread the rows apart.
    Item {
        Layout.fillHeight: true
    }
}
