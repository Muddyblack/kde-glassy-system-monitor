import QtQuick
import QtQuick.Controls.Basic as Controls

// Outlined (or brand) button in the studio's style; focusable, Enter/Space.
Rectangle {
    id: control
    required property var theme
    property string text: ""
    property bool primary: false
    property bool checked: false
    property bool danger: false
    property string tooltip: ""
    signal clicked

    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.45
    implicitWidth: label.implicitWidth + 22
    implicitHeight: 28
    radius: 8
    color: primary ? (danger ? theme.danger : theme.brand) : checked ? theme.segPressed : area.containsMouse ? theme.hover : "transparent"
    border.width: primary ? 0 : 1
    border.color: activeFocus ? theme.brand : theme.line2

    Keys.onReturnPressed: control.clicked()
    Keys.onEnterPressed: control.clicked()
    Keys.onSpacePressed: control.clicked()

    Text {
        id: label
        anchors.centerIn: parent
        text: control.text
        color: control.primary ? control.theme.brandInk : control.checked ? control.theme.segPressedText : area.containsMouse ? control.theme.text : control.theme.muted
        font.family: control.theme.fontFamily
        font.pixelSize: 11
        font.weight: control.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
    Controls.ToolTip {
        visible: area.containsMouse && control.tooltip !== ""
        text: control.tooltip
        delay: 500
    }
}
