import QtQuick

// A small tag: protocol, address kind, direction, exposure.
Rectangle {
    id: badge
    required property var theme
    property string text: ""
    property color tint: theme.muted
    implicitWidth: label.implicitWidth + 10
    implicitHeight: 16
    radius: 4
    color: Qt.rgba(tint.r, tint.g, tint.b, theme.dark ? 0.16 : 0.12)
    border.width: 1
    border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.3)
    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.tint
        font.family: badge.theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.DemiBold
    }
}
