import QtQuick
import "Theme.js" as Theme

// 36 × 21 pill switch with a springy 15 px knob (HTML `.switch`).
Item {
    id: control
    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 36
    implicitHeight: 21

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.switchOff
        gradient: control.checked ? onGradient : null
        Gradient {
            id: onGradient
            GradientStop {
                position: 0
                color: Theme.switchOnTop
            }
            GradientStop {
                position: 1
                color: Theme.switchOnBottom
            }
        }
    }
    Rectangle {
        width: 15
        height: 15
        radius: 7.5
        y: 3
        x: control.checked ? 18 : 3
        color: control.checked ? Theme.brandInk : Theme.knob
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled(!control.checked)
    }
}
