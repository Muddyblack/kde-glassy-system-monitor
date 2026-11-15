import QtQuick
import QtQuick.Dialogs
import "Theme.js" as Theme

// 22 px colour swatches plus a conic "any colour" button (HTML `.swatches`).
Flow {
    id: control
    property var swatches: []
    property string value: ""
    // When set, a crossed-out first swatch stands for "" (inherit); this is
    // its tooltip-style name.
    property string autoLabel: ""
    signal activated(string value)

    spacing: 7

    Item {
        id: autoSwatch
        objectName: "swatchAuto"
        visible: control.autoLabel !== ""
        width: 22
        height: 22
        readonly property bool pressed: control.value === ""
        Rectangle {
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: 15
            visible: autoSwatch.pressed
            color: "transparent"
            border.width: 2
            border.color: "#e9efe4"
        }
        Rectangle {
            anchors.fill: parent
            radius: 11
            color: "transparent"
            border.width: 1
            border.color: "#80ffffff"
            clip: true
            Rectangle {
                anchors.centerIn: parent
                width: 1.5
                height: 26
                rotation: 45
                color: "#c0ff6b6b"
                antialiasing: true
            }
        }
        MouseArea {
            id: autoArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: control.activated("")
        }
        Text {
            visible: autoArea.containsMouse
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.autoLabel
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 10
            z: 2
        }
    }

    Repeater {
        model: control.swatches
        Item {
            id: swatch
            required property var modelData
            readonly property bool pressed: String(control.value).toLowerCase() === String(modelData).toLowerCase()
            width: 22
            height: 22
            Rectangle {
                anchors.centerIn: parent
                width: 30
                height: 30
                radius: 15
                visible: swatch.pressed
                color: "transparent"
                border.width: 2
                border.color: "#e9efe4"
            }
            Rectangle {
                anchors.fill: parent
                radius: 11
                color: swatch.modelData
                border.width: 1
                border.color: "#26ffffff"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: control.activated(swatch.modelData)
            }
        }
    }

    Item {
        width: 22
        height: 22
        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const colors = ["#ff5555", "#ffdd55", "#55ff88", "#55ddff", "#8855ff", "#ff55cc", "#ff5555"];
                const conic = ctx.createConicalGradient(11, 11, Math.PI / 2);
                colors.forEach((c, i) => conic.addColorStop(1 - i / (colors.length - 1), c));
                ctx.fillStyle = conic;
                ctx.beginPath();
                ctx.arc(11, 11, 11, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = "#40ffffff";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(11, 11, 10.5, 0, Math.PI * 2);
                ctx.stroke();
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: picker.open()
        }
        ColorDialog {
            id: picker
            selectedColor: control.value
            onAccepted: control.activated(selectedColor.toString())
        }
    }
}
