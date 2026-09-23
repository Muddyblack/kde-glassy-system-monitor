import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema

// Toggle chips with ✓ (HTML `.chips`); the value is a list of keys.
Flow {
    id: control
    property var options: []
    property var value: []
    // One choice at a time: a click selects only that chip.
    property bool single: false
    signal activated(var value)

    readonly property var selected: Schema.fields(value)
    spacing: 6

    Repeater {
        model: control.options
        Rectangle {
            id: chip
            required property var modelData
            readonly property bool pressed: control.selected.indexOf(modelData[0]) !== -1
            width: chipLabel.implicitWidth + 22
            height: chipLabel.implicitHeight + 10
            radius: height / 2
            color: pressed ? Theme.chipPressed : Theme.sunk
            border.color: pressed ? Theme.chipPressedBorder : Theme.line2
            border.width: 1
            Text {
                id: chipLabel
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: (chip.pressed ? "<font color=\"" + Theme.brand + "\">✓ </font>" : "") + chip.modelData[1]
                color: chip.pressed ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const key = chip.modelData[0];
                    const current = control.selected;
                    const next = chip.pressed ? current.filter(k => k !== key) : control.single ? [key] : control.options.map(o => o[0]).filter(k => current.indexOf(k) !== -1 || k === key);
                    control.activated(next);
                }
            }
        }
    }
}
