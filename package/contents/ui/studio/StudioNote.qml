import QtQuick
import "Theme.js" as Theme

// Tinted platform note (HTML `.note`).
Rectangle {
    id: note
    property string title: ""
    property string text: ""

    implicitHeight: body.implicitHeight + 24
    radius: 12
    color: Theme.noteBg
    border.color: Theme.noteBorder
    border.width: 1

    Row {
        x: 13
        y: 12
        width: parent.width - 26
        spacing: 10
        Text {
            text: "◇"
            color: Theme.noteText
            font.pixelSize: 14
        }
        Text {
            id: body
            width: parent.width - 24
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            text: (note.title !== "" ? "<b><font color=\"#ffffff\">" + note.title + "</font></b> — " : "") + note.text
            color: Theme.noteText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            lineHeight: 1.25
        }
    }
}
