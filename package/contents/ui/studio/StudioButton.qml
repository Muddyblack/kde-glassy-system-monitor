import QtQuick
import QtQuick.Controls as Controls
import "Theme.js" as Theme

// HTML `.ghost` (outlined) and `.primary` (brand) buttons.
Rectangle {
    id: control
    property string icon: ""
    property string text: ""
    property bool primary: false
    property bool compact: false
    property string tooltip: ""
    property string areaName: ""
    signal clicked

    opacity: enabled ? 1.0 : 0.45
    implicitWidth: label.implicitWidth + 24 + (icon ? 20 : 0)
    implicitHeight: compact || primary ? 28 : 36
    radius: compact || primary ? 8 : 10
    color: primary ? Theme.brand : (enabled && area.containsMouse) ? Theme.hover : "transparent"
    border.width: primary ? 0 : 1
    border.color: Theme.line2

    Text {
        id: label
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: control.icon ? 10 : 0
        text: control.text
        color: control.primary ? Theme.brandInk : (control.enabled && area.containsMouse) ? Theme.text : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: control.primary ? Font.DemiBold : Font.Normal
    }
    Canvas {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        visible: control.icon !== ""
        readonly property var signature: [control.icon, label.color]
        onSignatureChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(width / 24, height / 24);
            ctx.strokeStyle = label.color;
            ctx.lineWidth = 1.7;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.path = control.icon;
            ctx.stroke();
        }
    }
    MouseArea {
        id: area
        objectName: control.areaName
        anchors.fill: parent
        enabled: control.enabled
        hoverEnabled: control.enabled
        cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (control.enabled)
            control.clicked()
    }
    Controls.ToolTip {
        visible: control.enabled && area.containsMouse && control.tooltip !== ""
        text: control.tooltip
        delay: 500
    }
}
