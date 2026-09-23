import QtQuick
import ".."
import "Theme.js" as Theme
import "Looks.js" as Looks

// Built-in and saved looks as tiles showing the real widget, plus saving,
// sharing and importing. Placement, commands and devices are never part of
// a look (see Looks.js).
Column {
    id: gallery
    required property var studio
    readonly property var saved: Looks.parseSaved(studio.draft.userPresets)
    readonly property var all: Looks.BUILT_IN.map(l => Object.assign({
            builtIn: true
        }, l)).concat(saved.map((l, i) => ({
                id: "saved" + i,
                name: l.name,
                note: "Saved look",
                s: l.settings,
                index: i
            })))
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
        storeSaved(saved.concat([
            {
                name: name,
                settings: Looks.extract(studio.draft, studio.defaults)
            }
        ]));
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
                readonly property var look: Looks.apply(gallery.studio.draft, gallery.studio.defaults, modelData.s)
                readonly property bool current: Looks.matches(gallery.studio.draft, gallery.studio.defaults, modelData.s)
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
                    onClicked: gallery.studio.edited(Looks.apply(gallery.studio.draft, gallery.studio.defaults, tile.modelData.s))
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
            placeholder: "Name this look"
        }
        StudioButton {
            primary: true
            text: "Save current"
            areaName: "saveLook"
            onClicked: gallery.save()
        }
        StudioButton {
            compact: true
            text: "Copy as JSON"
            onClicked: {
                clipboard.text = Looks.encode(nameInput.text.trim() || "My look", Looks.extract(gallery.studio.draft, gallery.studio.defaults), gallery.studio.defaults);
                clipboard.selectAll();
                clipboard.copy();
                gallery.message = "Copied. Paste it anywhere to share this look.";
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
                gallery.message = "Imported “" + look.name + "”. Click it to use it.";
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
        text: "A look covers layout, charts, card and colours. Commands, ping hosts, devices, thresholds and placement stay as they are, so an imported look can never run anything."
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
