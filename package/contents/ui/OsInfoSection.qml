import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: osSection
    spacing: 0

    readonly property var _rows: [
        {
            lbl: "OS",
            val: root.osDistro
        },
        {
            lbl: "Kernel",
            val: root.osKernel
        },
        {
            lbl: "Host",
            val: root.osHostname
        },
        {
            lbl: "Uptime",
            val: root.osUptime
        }
    ]

    Repeater {
        model: osSection._rows

        Item {
            Layout.fillWidth: true
            height: 22

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, index % 2 === 0 ? 0.0 : 0.04)
                radius: 2
            }

            Text {
                id: lblText
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.lbl
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.40)
                font.pixelSize: 10
                width: 46
            }
            Text {
                anchors.left: lblText.right
                anchors.leftMargin: 4
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.val || "…"
                color: root.textColor
                font.pixelSize: 11
                font.bold: modelData.val !== ""
                elide: Text.ElideRight
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
