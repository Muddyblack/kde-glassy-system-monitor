import QtQuick
import "Theme.js" as Theme

// 168 px slider with accent fill, 15 px thumb and a value pill (HTML `.range`).
Row {
    id: control
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    property real value: 0
    property string display: String(value)
    signal moved(real value)

    spacing: 10

    Item {
        id: track
        width: 168
        height: 21
        readonly property real fraction: control.to > control.from ? Math.max(0, Math.min(1, (control.value - control.from) / (control.to - control.from))) : 0

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.rangeTrack
            Rectangle {
                width: parent.width * track.fraction
                height: parent.height
                radius: 2
                color: Theme.brand
            }
        }
        Rectangle {
            x: track.fraction * (track.width - 15)
            anchors.verticalCenter: parent.verticalCenter
            width: 23
            height: 23
            radius: 11.5
            color: Theme.rangeRing
            anchors.verticalCenterOffset: 0
            transform: Translate {
                x: -4
            }
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 7.5
                color: Theme.rangeThumb
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function update(mouseX) {
                const raw = control.from + Math.max(0, Math.min(1, mouseX / width)) * (control.to - control.from);
                const stepped = control.stepSize > 0 ? Math.round((raw - control.from) / control.stepSize) * control.stepSize + control.from : raw;
                const value = Math.max(control.from, Math.min(control.to, Number(stepped.toFixed(4))));
                if (value !== control.value)
                    control.moved(value);
            }
            onPressed: mouse => update(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    update(mouse.x);
            }
        }
        WheelHandler {
            onWheel: event => {
                const delta = event.angleDelta.y > 0 ? control.stepSize : -control.stepSize;
                control.moved(Math.max(control.from, Math.min(control.to, Number((control.value + delta).toFixed(4)))));
            }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(54, label.implicitWidth + 14)
        height: label.implicitHeight + 6
        radius: 6
        color: Theme.hover
        border.color: Theme.line
        border.width: 1
        Text {
            id: label
            anchors.centerIn: parent
            text: control.display
            color: Theme.outputText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.features: {
                "tnum": 1
            }
        }
    }
}
