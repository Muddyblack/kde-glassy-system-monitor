import QtQuick
import "Theme.js" as Theme

// Tile grid (HTML `.tiles` / `.tile`): live preview area, label, selected
// state with accent border and 3 px ring, 1 px hover lift.
Flow {
    id: tiles
    required property var rowData
    required property var studio
    property var value
    signal chosen(var value)

    readonly property real minimum: rowData.tw || 112
    readonly property int columns: Math.max(1, Math.floor((width + 8) / (minimum + 8)))
    readonly property real tileWidth: (width - (columns - 1) * 8) / columns
    spacing: 8

    Repeater {
        model: tiles.rowData.opts.length
        Item {
            id: tile
            required property int index
            readonly property var option: tiles.rowData.opts[index]
            readonly property bool pressed: String(option.v) === String(tiles.value)
            objectName: "tile_" + (tiles.rowData.k || tiles.rowData.id) + "_" + option.v
            width: tiles.tileWidth
            height: 50 + 12 + label.implicitHeight + 6

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 15
                visible: tile.pressed
                color: "transparent"
                border.width: 3
                border.color: Theme.tileSelectedRing
            }
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Theme.sunk
                border.width: 1
                border.color: tile.pressed ? Theme.tileSelectedBorder : area.containsMouse ? Theme.tileHoverBorder : Theme.line2
                gradient: tile.pressed ? pressedGradient : null
                transform: Translate {
                    y: area.containsMouse && !tile.pressed ? -1 : 0
                }
                Gradient {
                    id: pressedGradient
                    GradientStop {
                        position: 0
                        color: Theme.chipPressed
                    }
                    GradientStop {
                        position: 1
                        color: Theme.panelBottom
                    }
                }

                Rectangle {
                    x: 6
                    y: 6
                    width: parent.width - 12
                    height: 50
                    radius: 8
                    color: Theme.tilePreview
                    clip: true
                    TilePreview {
                        anchors.fill: parent
                        kind: tile.option.pv
                        value: tile.option.v
                        studio: tiles.studio
                        ink: tile.pressed ? Theme.text : Theme.muted
                    }
                }
                Text {
                    id: label
                    x: 9
                    y: 62
                    width: parent.width - 18
                    text: tile.option.label
                    color: tile.pressed ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tiles.chosen(tile.option.v)
            }
        }
    }
}
