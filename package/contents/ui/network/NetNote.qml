import QtQuick

// A tinted note in the warning colour: missing tools, permissions, exposure.
Rectangle {
    id: box
    required property var theme
    property alias text: label.text

    implicitHeight: label.implicitHeight + 20
    radius: 10
    color: Qt.rgba(theme.warn.r, theme.warn.g, theme.warn.b, 0.08)
    border.color: Qt.rgba(theme.warn.r, theme.warn.g, theme.warn.b, 0.3)
    Text {
        id: label
        x: 12
        y: 10
        width: parent.width - 24
        wrapMode: Text.WordWrap
        color: box.theme.muted
        font.family: box.theme.fontFamily
        font.pixelSize: 11
    }
}
