import QtQuick
import "Theme.js" as Theme
import "../Sections.js" as Sections

// Manual arrangement: exact x, y and width per section, one line each.
// Dragging in the preview writes the same numbers.
Column {
    id: editor
    required property var studio
    readonly property var positions: Sections.positions(studio.draft.sectionPositions)
    spacing: 6

    Text {
        width: parent.width
        text: "Drag a section in the preview to move it; drag its right edge, bottom edge or corner to resize it. Positions are in pixels from the card's top-left corner and snap to 4 px. An empty H follows the content; a section never gets shorter than it needs."
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
    Repeater {
        model: Sections.parse(editor.studio.draft.sections, editor.studio.draft.activeSection)
        Row {
            id: line
            required property string modelData
            readonly property var place: editor.positions[modelData] || {}
            readonly property real field: (width - name.width - 4 * 22) / 4
            width: editor.width
            height: 32
            Text {
                id: name
                width: Math.min(130, editor.width * 0.3)
                anchors.verticalCenter: parent.verticalCenter
                text: Sections.title(line.modelData, editor.studio.draft)
                textFormat: Text.PlainText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Repeater {
                model: [["x", "X"], ["y", "Y"], ["width", "W"], ["height", "H"]]
                Row {
                    required property var modelData
                    Text {
                        width: 22
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData[1]
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    StudioText {
                        objectName: "position_" + line.modelData + "_" + modelData[0]
                        width: line.field
                        height: 30
                        numeric: true
                        value: line.place[modelData[0]] === undefined ? "" : String(line.place[modelData[0]])
                        placeholder: "auto"
                        onCommitted: value => editor.studio.update({
                                sectionPositions: Sections.position(editor.studio.draft.sectionPositions, line.modelData, {
                                    [modelData[0]]: Number(value)
                                })
                            })
                    }
                }
            }
        }
    }
    StudioButton {
        compact: true
        text: "Start again from the grid"
        tooltip: "Place every section where the automatic layout has it"
        onClicked: editor.studio.regrid()
    }
}
