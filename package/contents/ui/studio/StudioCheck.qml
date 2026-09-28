import QtQuick
import "Theme.js" as Theme

// 16 px checkbox; `partial` shows a dash (some of a group chosen).
Rectangle {
    id: control
    property bool checked: false
    property bool partial: false
    signal toggled(bool checked)

    implicitWidth: 16
    implicitHeight: 16
    radius: 4
    color: checked || partial ? Theme.brand : area.containsMouse ? Theme.hover : "transparent"
    border.width: checked || partial ? 0 : 1
    border.color: area.containsMouse ? Theme.muted : Theme.line2

    Canvas {
        anchors.fill: parent
        visible: control.checked
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Theme.brandInk;
            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(4, 8.5);
            ctx.lineTo(7, 11.5);
            ctx.lineTo(12, 5);
            ctx.stroke();
        }
    }
    Rectangle {
        visible: control.partial && !control.checked
        anchors.centerIn: parent
        width: 8
        height: 2
        radius: 1
        color: Theme.brandInk
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled(!control.checked)
    }
}
