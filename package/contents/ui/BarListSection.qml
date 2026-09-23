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
            Layout.fillWidth: true
            Layout.preferredHeight: section.rowHeight
            spacing: 6

            Text {
                font.family: section.monitor.fontFamily
                Layout.preferredWidth: Math.min(120, section.width * 0.34)
                text: row.modelData.label
                color: section.inkAlpha(0.72)
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
            Rectangle {
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
                    color: row.modelData.color
                }
            }
            Text {
                font.family: section.monitor.fontFamily
                text: row.modelData.detail
                color: section.inkAlpha(0.45)
                font.pixelSize: 10
            }
            Text {
                font.family: section.monitor.fontFamily
                Layout.preferredWidth: Math.max(44, implicitWidth)
                horizontalAlignment: Text.AlignRight
                text: row.modelData.value
                color: row.modelData.color
                font.pixelSize: 11
                font.bold: true
            }
        }
    }

    // A taller grid neighbour must not spread the rows apart.
    Item {
        Layout.fillHeight: true
    }
}
