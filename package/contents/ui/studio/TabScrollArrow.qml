import QtQuick
import "Theme.js" as Theme

// Visible edge control for tab rows that extend beyond a narrow settings panel.
Rectangle {
    id: root
    required property Flickable scroller
    property bool forward: true
    property string areaName: ""
    readonly property real limit: Math.max(0, scroller.contentWidth - scroller.width)
    visible: forward ? scroller.contentX < limit - 1 : scroller.contentX > 1
    width: 24
    height: parent?.height ?? 36
    color: Theme.panelTop
    border.color: Theme.line2
    border.width: 1
    radius: 7

    Text {
        anchors.centerIn: parent
        text: root.forward ? "›" : "‹"
        color: Theme.text
        font.pixelSize: 22
    }
    MouseArea {
        objectName: root.areaName
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.scroller.contentX = Math.max(0, Math.min(root.limit, root.scroller.contentX + (root.forward ? 1 : -1) * root.scroller.width * 0.7))
    }
}
