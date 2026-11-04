import QtQuick
import ".."
import "Theme.js" as Theme
import "Looks.js" as Looks

// Built-in and saved looks as tiles showing the real widget, plus saving,
// sharing and importing. Placement, commands and devices are never part of
// a look (see Looks.js). With `cards` it shows card styles instead: looks
// limited to the card, previewed on the current layout.
Column {
    id: gallery
    required property var studio
    property bool cards: false
    readonly property string kind: cards ? "card style" : "look"
    // Through a string property: it only notifies when the text changes, so
    // other edits keep the tile list (and every tile's widget) as it is.
    readonly property string savedJson: studio.draft.userPresets || ""
    readonly property var saved: Looks.parseSaved(savedJson)
    readonly property var all: (cards ? Looks.CARD_STYLES : Looks.BUILT_IN).map(l => Object.assign({
            builtIn: true
        }, l)).concat(saved.map((l, i) => ({
                id: "saved" + i,
                name: l.name,
                note: "Saved " + kind,
                s: l.settings,
                card: !!l.card,
                index: i
            })).filter(l => l.card === cards))
    readonly property int columns: Math.max(1, Math.floor((width + 10) / 178))
    readonly property real tileWidth: (width - (columns - 1) * 10) / columns
    property bool importing: false
    property string message: ""
    spacing: 12

    function storeSaved(list) {
        studio.update({
            userPresets: JSON.stringify(list)
        });
    }
    function save() {
        const name = nameInput.text.trim();
        if (name === "")
            return;
        storeSaved(saved.concat([cards ? {
                name: name,
                card: true,
                settings: Looks.extract(studio.draft, studio.defaults, true)
            } : {
                name: name,
                settings: Looks.extract(studio.draft, studio.defaults)
            }]));
        nameInput.clear();
        message = "Saved “" + name + "”. Apply to keep it.";
    }

    // One still demo reading shared by every tile.
    MonitorCore {
        id: sample
        live: false
        cfg: gallery.studio.draft
        systemTextColor: "#eff0f1"
    }
    DemoFeeder {
        monitor: sample
        running: false
    }

    Flow {
        width: parent.width
        spacing: 10
        Repeater {
            model: gallery.all
            Rectangle {
                id: tile
                required property var modelData
                // Applying a preset resets appearance edits to the same values.
                // Only notify the full preview when those values actually change.
                readonly property string lookJson: JSON.stringify(Looks.apply(gallery.studio.draft, gallery.studio.defaults, modelData.s, gallery.cards))
                readonly property var look: JSON.parse(lookJson)
                readonly property bool current: Looks.matches(gallery.studio.draft, gallery.studio.defaults, modelData.s, gallery.cards)
                objectName: "look_" + modelData.id
                width: gallery.tileWidth
                height: 176
                radius: 12
                color: Theme.sunk
                border.width: 1
                border.color: current ? Theme.tileSelectedBorder : area.containsMouse ? Theme.tileHoverBorder : Theme.line2

                Rectangle {
                    id: stage
                    x: 6
                    y: 6
                    width: parent.width - 12
                    height: 112
                    radius: 8
                    clip: true
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#1d3a4a"
                        }
                        GradientStop {
                            position: 1
                            color: "#0b1620"
                        }
                    }
                    MonitorView {
                        id: thumb
                        readonly property real fit: Math.min((stage.width - 12) / width, (stage.height - 12) / height)
                        width: Math.max(260, preferredWidth)
                        height: preferredHeight
                        x: (stage.width - width * fit) / 2
                        y: (stage.height - height * fit) / 2
                        scale: fit
                        transformOrigin: Item.TopLeft
                        monitor: sample
                        cfg: tile.look
                    }
                }
                Column {
                    x: 10
                    y: stage.y + stage.height + 8
                    width: parent.width - 20
                    spacing: 2
                    Text {
                        width: parent.width
                        text: tile.modelData.name
                        elide: Text.ElideRight
                        color: tile.current ? Theme.text : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: tile.modelData.note
                        elide: Text.ElideRight
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: gallery.studio.edited(Looks.apply(gallery.studio.draft, gallery.studio.defaults, tile.modelData.s, gallery.cards))
                }
                // Saved looks can be deleted.
                Rectangle {
                    visible: !tile.modelData.builtIn && area.containsMouse
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    width: 22
                    height: 22
                    radius: 11
                    color: "#cc0b0c0d"
                    border.color: Theme.line2
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.muted
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gallery.storeSaved(gallery.saved.filter((_, i) => i !== tile.modelData.index))
                    }
                }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 8
        StudioText {
            id: nameInput
            implicitWidth: Math.max(140, Math.min(240, gallery.width - 300))
            placeholder: "Name this " + gallery.kind
        }
        StudioButton {
            primary: true
            text: gallery.cards ? "Save card style" : "Save current"
            areaName: gallery.cards ? "saveCardStyle" : "saveLook"
            onClicked: gallery.save()
        }
        StudioButton {
            compact: true
            text: "Copy as JSON"
            onClicked: {
                clipboard.text = Looks.encode(nameInput.text.trim() || (gallery.cards ? "My card style" : "My look"), Looks.extract(gallery.studio.draft, gallery.studio.defaults, gallery.cards), gallery.studio.defaults, gallery.cards);
                clipboard.selectAll();
                clipboard.copy();
                gallery.message = "Copied. Paste it anywhere to share this " + gallery.kind + ".";
            }
        }
        StudioButton {
            compact: true
            text: gallery.importing ? "Cancel import" : "Import JSON"
            onClicked: gallery.importing = !gallery.importing
        }
    }
    Rectangle {
        visible: gallery.importing
        width: parent.width
        height: 80
        radius: 8
        color: Theme.sunk
        border.color: Theme.line2
        border.width: 1
        TextEdit {
            id: importInput
            objectName: "lookImport"
            anchors.fill: parent
            anchors.margins: 8
            color: Theme.text
            font.family: "monospace"
            font.pixelSize: 11
            wrapMode: TextEdit.WrapAnywhere
            clip: true
        }
    }
    StudioButton {
        visible: gallery.importing
        primary: true
        text: "Import and save"
        onClicked: {
            try {
                const look = Looks.decode(importInput.text, gallery.studio.defaults);
                gallery.storeSaved(gallery.saved.concat([look]));
                importInput.text = "";
                gallery.importing = false;
                gallery.message = "Imported “" + look.name + "”. " + (!!look.card === gallery.cards ? "Click it to use it." : look.card ? "It is a card style: find it under Card styles." : "It is a full look: find it under Looks.");
            } catch (error) {
                gallery.message = error.message || "That is not a valid look.";
            }
        }
    }
    Text {
        visible: gallery.message !== ""
        width: parent.width
        text: gallery.message
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    Text {
        width: parent.width
        text: gallery.cards ? "A card style covers only the card: material, its colours, edges, shadow and corners. Sections, charts and layout stay as they are." : "A look covers layout, charts, card and colours. Commands, ping hosts, devices, thresholds and placement stay as they are, so an imported look can never run anything."
        wrapMode: Text.WordWrap
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }
    TextEdit {
        id: clipboard
        visible: false
    }
}
