import QtQuick
import "Theme.js" as Theme

// Segmented choice (HTML `.seg`): sunk group, the pressed segment raised.
Rectangle {
    id: control
    // [[value, label], …]
    property var options: []
    property var value
    signal activated(var value)

    implicitWidth: segmentRepeater.count ? Array.from({
        length: segmentRepeater.count
    }, (_, i) => segmentRepeater.itemAt(i)?.width ?? 0).reduce((a, b) => a + b, 0) + (segmentRepeater.count - 1) * flow.spacing + 8 : 8
    implicitHeight: flow.implicitHeight + 8
    width: Math.min(implicitWidth, parent ? parent.width : implicitWidth)
    height: flow.height + 8
    radius: 9
    color: Theme.sunk
    border.color: Theme.line2
    border.width: 1

    Flow {
        id: flow
        x: 4
        y: 4
        width: control.width - 8
        spacing: 2
        Repeater {
            id: segmentRepeater
            model: control.options
            Rectangle {
                id: segment
                required property var modelData
                readonly property bool pressed: String(modelData[0]) === String(control.value)
                width: segmentLabel.implicitWidth + 20
                height: segmentLabel.implicitHeight + 10
                radius: 6
                color: pressed ? Theme.segPressed : segmentArea.containsMouse ? Theme.hover : "transparent"
                Text {
                    id: segmentLabel
                    anchors.centerIn: parent
                    text: segment.modelData[1]
                    color: segment.pressed ? Theme.segPressedText : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                MouseArea {
                    id: segmentArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.activated(segment.modelData[0])
                }
            }
        }
    }
}
