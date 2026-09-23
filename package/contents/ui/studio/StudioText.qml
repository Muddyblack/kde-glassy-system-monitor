import QtQuick
import "Theme.js" as Theme

// Sunk single-line field in the style of StudioSelect. Commits on Enter and
// when focus leaves, so a half-typed command never runs.
Rectangle {
    id: control
    property string value: ""
    property string placeholder: ""
    property bool numeric: false
    signal committed(var value)
    // What is typed right now, committed or not.
    readonly property alias text: input.text
    function clear() {
        input.text = "";
    }

    implicitWidth: 220
    implicitHeight: 32
    radius: 8
    color: Theme.sunk
    border.width: 1
    border.color: input.activeFocus ? "#6655ffcc" : area.containsMouse ? "#33ffffff" : Theme.line2

    function commit() {
        const text = input.text.trim();
        if (numeric) {
            const n = Number(text);
            if (text === "" || !isFinite(n)) {
                input.text = control.value;
                return;
            }
            if (String(n) !== String(control.value))
                control.committed(n);
        } else if (text !== String(control.value)) {
            control.committed(text);
        }
    }

    onValueChanged: if (!input.activeFocus)
        input.text = value
    Component.onCompleted: input.text = value

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
    TextInput {
        id: input
        x: 10
        width: parent.width - 20
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
        selectionColor: "#5555ffcc"
        font.family: Theme.fontFamily
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        inputMethodHints: control.numeric ? Qt.ImhFormattedNumbersOnly : Qt.ImhNone
        onAccepted: control.commit()
        onActiveFocusChanged: if (!activeFocus)
            control.commit()
        Keys.onEscapePressed: {
            text = control.value;
            focus = false;
        }
    }
    Text {
        anchors.fill: input
        verticalAlignment: Text.AlignVCenter
        visible: input.text === "" && !input.activeFocus
        text: control.placeholder
        color: Theme.dim
        font: input.font
        elide: Text.ElideRight
    }
}
