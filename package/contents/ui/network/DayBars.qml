import QtQuick
import "../Format.js" as Format

// Bars per day (or per hour): download above, upload stacked on top in its
// own colour; hover shows the numbers.
Item {
    id: bars
    required property var theme
    // [{ label, in, out }]
    property var entries: []
    property int hovered: -1
    // A bar was clicked (its index): the History page drills in.
    signal activated(int index)
    readonly property real peak: Math.max(1, ...entries.map(e => e["in"] + e.out))
    readonly property real slot: entries.length ? plot.width / entries.length : 0

    Item {
        id: plot
        anchors.fill: parent
        anchors.leftMargin: 64
        anchors.bottomMargin: 18

        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: plot.width
                height: 1
                y: Math.round(plot.height * index / 4)
                color: bars.theme.grid
            }
        }
        Repeater {
            model: bars.entries
            Item {
                id: bar
                required property var modelData
                required property int index
                x: index * bars.slot
                width: bars.slot
                height: plot.height
                readonly property real total: modelData["in"] + modelData.out
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(2, bars.slot * 0.62)
                    height: plot.height * bar.modelData["in"] / bars.peak
                    anchors.bottom: parent.bottom
                    radius: 2
                    color: bars.theme.rx
                    opacity: bars.hovered === -1 || bars.hovered === bar.index ? 0.9 : 0.45
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(2, bars.slot * 0.62)
                    height: plot.height * bar.modelData.out / bars.peak
                    y: plot.height - plot.height * bar.total / bars.peak
                    radius: 2
                    color: bars.theme.tx
                    opacity: bars.hovered === -1 || bars.hovered === bar.index ? 0.95 : 0.45
                }
                Text {
                    // Every label that fits.
                    visible: bars.slot >= 26 || bar.index % Math.ceil(26 / Math.max(1, bars.slot)) === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: plot.height + 4
                    text: bar.modelData.label
                    color: bars.hovered === bar.index ? bars.theme.text : bars.theme.dim
                    font.family: bars.theme.fontFamily
                    font.pixelSize: 9
                }
                Rectangle {
                    // The hover line.
                    visible: bars.hovered === bar.index
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 1
                    height: plot.height
                    color: bars.theme.muted
                    opacity: 0.5
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: bar.modelData.drill ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (bar.modelData.drill)
                        bars.activated(bar.index)
                    onContainsMouseChanged: bars.hovered = containsMouse ? bar.index : (bars.hovered === bar.index ? -1 : bars.hovered)
                }
            }
        }
        Rectangle {
            visible: bars.hovered >= 0 && bars.hovered < bars.entries.length
            readonly property var e: visible ? bars.entries[bars.hovered] : null
            x: Math.min(plot.width - width, Math.max(0, bars.hovered * bars.slot + bars.slot / 2 - width / 2))
            y: 4
            width: tip.implicitWidth + 16
            height: tip.implicitHeight + 10
            radius: 6
            color: bars.theme.popup
            border.color: bars.theme.line2
            Text {
                id: tip
                anchors.centerIn: parent
                text: parent.e ? (parent.e.title || parent.e.label) + "   ↓ " + Format.bytes(parent.e["in"]) + "   ↑ " + Format.bytes(parent.e.out) + (parent.e.drill ? "   · click to open" : "") : ""
                color: bars.theme.text
                font.family: bars.theme.fontFamily
                font.pixelSize: 10
            }
        }
    }
    Repeater {
        model: 5
        Text {
            required property int index
            width: 56
            horizontalAlignment: Text.AlignRight
            y: Math.max(0, Math.min(plot.height - height, plot.height * index / 4 - height / 2))
            text: Format.bytes(bars.peak * (4 - index) / 4)
            color: bars.theme.dim
            font.family: bars.theme.fontFamily
            font.pixelSize: 9
        }
    }
}
