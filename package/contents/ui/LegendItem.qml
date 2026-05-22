import QtQuick
import QtQuick.Controls as QQC

Item {
    id: legendItem
    property string text
    property color color
    property bool active: true
    property bool highlighted: false
    property color textColor: Qt.rgba(1,1,1,0.85)
    signal clicked()
    signal hovered(bool isHovered)

    implicitWidth: legendRow.implicitWidth
    implicitHeight: Math.max(12, legendRow.implicitHeight)

    Row {
        id: legendRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Rectangle {
            width: 8; height: 8; radius: 2
            color: legendItem.active ? legendItem.color : "transparent"
            border.color: legendItem.color; border.width: 1
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: legendItem.text
            color: legendItem.active
                ? legendItem.textColor
                : Qt.rgba(legendItem.textColor.r, legendItem.textColor.g, legendItem.textColor.b, 0.3)
            opacity: legendItem.highlighted ? 1.0 : (legendItem.active ? 0.7 : 0.4)
            font.pixelSize: 9
            font.strikeout: !legendItem.active
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: legendItem.clicked()
        onEntered: legendItem.hovered(true)
        onExited:  legendItem.hovered(false)
    }
}
