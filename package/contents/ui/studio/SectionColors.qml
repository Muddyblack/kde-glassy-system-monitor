import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema
import "../Sections.js" as Sections

// Colours › Per section: one line per shown section with a dot for its text,
// its numbers and each chart colour. Clicking a dot opens the swatches right
// under that line; picking one applies it at once and keeps the strip open,
// so a whole section is recoloured without leaving the line.
Column {
    id: grid
    objectName: "sectionColorGrid"
    required property var studio

    readonly property var draft: studio.draft
    readonly property var ids: Sections.parse(draft.sections, draft.activeSection)
    readonly property var own: Sections.sectionColors(draft.sectionColors)
    readonly property string cardInk: Sections.textColor(draft, "#eff0f1", String(studio.previewAccent))
    // "cpu|text", "cpu|value" or "cpu|chart|cpuColor"; "" when closed.
    property string open: ""
    readonly property real labelWidth: Math.min(130, width * 0.3)
    readonly property real cellWidth: 64

    function chartColors(id) {
        return Sections.CHART_COLORS[id] || [];
    }
    // What a dot shows: the colour in use, and whether it is the section's own.
    function current(id, part, key) {
        if (part === "chart")
            return {
                color: String(draft[key] || "#ffffff"),
                own: true
            };
        const mine = own[id] && own[id][part];
        if (mine)
            return {
                color: mine,
                own: true
            };
        const chart = chartColors(id)[0];
        return {
            color: part === "value" && chart ? String(draft[chart[0]] || cardInk) : (own[id] && own[id].text) || cardInk,
            own: false
        };
    }
    function pick(spec, value) {
        const p = spec.split("|");
        if (p[1] === "chart") {
            const patch = {};
            patch[p[2]] = value;
            studio.update(patch);
        } else {
            studio.update({
                sectionColors: Sections.withSectionColor(draft.sectionColors, p[0], p[1], value)
            });
        }
    }

    spacing: 0

    component Dot: Item {
        id: dot
        property string spec: ""
        property var info: ({
                color: "#fff",
                own: false
            })
        property string tip: ""
        readonly property bool active: grid.open === spec
        width: 22
        height: 22
        Rectangle {
            anchors.centerIn: parent
            width: 30
            height: 30
            radius: 15
            color: "transparent"
            border.width: 2
            border.color: Theme.tileSelectedBorder
            visible: dot.active
        }
        Rectangle {
            anchors.fill: parent
            radius: 11
            color: dot.info.color
            // Inherited colours show as a hollow ring of what they follow.
            opacity: dot.info.own ? 1 : 0.35
            border.width: 1
            border.color: "#40ffffff"
        }
        Rectangle {
            anchors.centerIn: parent
            visible: !dot.info.own
            width: 12
            height: 12
            radius: 6
            color: Theme.panel
        }
        MouseArea {
            id: dotArea
            objectName: "dot_" + dot.spec.split("|").join("_")
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: grid.open = dot.active ? "" : dot.spec
        }
        Rectangle {
            visible: dotArea.containsMouse && dot.tip !== ""
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: tipText.implicitWidth + 12
            height: tipText.implicitHeight + 6
            radius: 5
            color: Theme.card
            border.color: Theme.line2
            z: 3
            Text {
                id: tipText
                anchors.centerIn: parent
                text: dot.tip
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }
    }

    // Column heads.
    Row {
        height: 22
        Item {
            width: grid.labelWidth
            height: 1
        }
        Repeater {
            model: ["Text", "Numbers", "Chart"]
            Text {
                required property string modelData
                width: grid.cellWidth
                text: modelData
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 0.4
            }
        }
    }

    Repeater {
        model: grid.ids
        Column {
            id: line
            required property string modelData
            required property int index
            readonly property string sid: modelData
            readonly property string openPart: grid.open.split("|")[0] === sid ? grid.open : ""
            width: grid.width

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }
            Row {
                height: 40
                Text {
                    width: grid.labelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sections.title(line.sid, grid.draft)
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
                Item {
                    width: grid.cellWidth
                    height: 40
                    Dot {
                        anchors.verticalCenter: parent.verticalCenter
                        spec: line.sid + "|text"
                        info: grid.current(line.sid, "text")
                        tip: info.own ? "Own text colour" : "Follows the card"
                    }
                }
                Item {
                    width: grid.cellWidth
                    height: 40
                    Dot {
                        anchors.verticalCenter: parent.verticalCenter
                        spec: line.sid + "|value"
                        info: grid.current(line.sid, "value")
                        tip: info.own ? "Own number colour" : "Default number colours"
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Repeater {
                        model: grid.chartColors(line.sid)
                        Dot {
                            required property var modelData
                            spec: line.sid + "|chart|" + modelData[0]
                            info: grid.current(line.sid, "chart", modelData[0])
                            tip: modelData[1]
                        }
                    }
                    Text {
                        visible: grid.chartColors(line.sid).length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "—"
                        color: Theme.dim
                        font.pixelSize: 11
                    }
                }
            }
            // The open dot's swatches, under its own line.
            Item {
                visible: line.openPart !== ""
                width: parent.width
                height: visible ? strip.implicitHeight + 16 : 0
                StudioSwatches {
                    id: strip
                    y: 6
                    x: grid.labelWidth
                    width: parent.width - grid.labelWidth
                    readonly property var p: line.openPart.split("|")
                    swatches: p[1] === "text" ? Schema.INK : Schema.SWATCHES
                    autoLabel: p[1] === "text" ? "Card text" : p[1] === "value" ? "Default" : ""
                    value: p[1] === "chart" ? String(grid.draft[p[2]] || "") : (grid.own[line.sid] && grid.own[line.sid][p[1]]) || ""
                    onActivated: value => grid.pick(line.openPart, value)
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.line
    }
    Item {
        width: parent.width
        height: Object.keys(grid.own).length ? 44 : 0
        visible: height > 0
        StudioButton {
            objectName: "resetSectionColors"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            text: "Reset text and number colours"
            onClicked: {
                grid.open = "";
                grid.studio.update({
                    sectionColors: ""
                });
            }
        }
    }
}
