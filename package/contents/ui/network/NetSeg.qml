import QtQuick

// Segmented choice: [[value, label], …]; arrow keys move when focused.
Rectangle {
    id: seg
    required property var theme
    property var options: []
    property var value
    signal activated(var value)

    activeFocusOnTab: true
    implicitWidth: row.implicitWidth + 6
    implicitHeight: 28
    radius: 8
    color: theme.sunk
    border.width: 1
    border.color: activeFocus ? theme.brand : theme.line2

    readonly property int index: Math.max(0, options.findIndex(o => String(o[0]) === String(value)))
    Keys.onLeftPressed: activated(options[Math.max(0, index - 1)][0])
    Keys.onRightPressed: activated(options[Math.min(options.length - 1, index + 1)][0])

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: seg.options
            Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: String(modelData[0]) === String(seg.value)
                width: optLabel.implicitWidth + 16
                height: 22
                radius: 6
                color: on ? seg.theme.segPressed : optArea.containsMouse ? seg.theme.hover : "transparent"
                Text {
                    id: optLabel
                    anchors.centerIn: parent
                    text: opt.modelData[1]
                    color: opt.on ? seg.theme.segPressedText : seg.theme.muted
                    font.family: seg.theme.fontFamily
                    font.pixelSize: 11
                }
                MouseArea {
                    id: optArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.activated(opt.modelData[0])
                }
            }
        }
    }
}
