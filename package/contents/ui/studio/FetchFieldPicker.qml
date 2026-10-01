import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme
import "Schema.js" as Schema
import "../OsFetch.js" as OsFetch

// Lists available built-in and fetch-tool fields, allowing the user to
// toggle visibility and reorder them. Saves into draft.osFieldRules.
ColumnLayout {
    id: picker
    required property var studio

    readonly property var monitor: studio.liveMonitor || studio.sensorMonitor
    objectName: "systemFieldPicker"
    readonly property var liveRows: OsFetch.systemRows(monitor, !!studio.draft.osUseFetch)

    // Merge saved rules with detected rows
    readonly property var fieldItems: OsFetch.mergeRules(liveRows, studio.draft.osFieldRules || [])

    spacing: 6
    Layout.fillWidth: true

    function commitRules(items) {
        const rules = [];
        for (let i = 0; i < items.length; i++) {
            rules.push(OsFetch.makeRule(items[i].key, items[i].enabled));
        }
        studio.update({
            osFieldRules: rules
        });
    }

    function toggleField(index) {
        const items = picker.fieldItems.slice();
        if (index >= 0 && index < items.length) {
            items[index] = Object.assign({}, items[index], {
                enabled: !items[index].enabled
            });
            commitRules(items);
        }
    }

    function moveField(from, to) {
        if (from === to || from < 0 || to < 0 || from >= picker.fieldItems.length || to >= picker.fieldItems.length)
            return;
        const items = picker.fieldItems.slice();
        const moved = items.splice(from, 1)[0];
        items.splice(to, 0, moved);
        commitRules(items);
    }

    function resetOrder() {
        studio.update({
            osFieldRules: []
        });
    }

    function setAll(enabled) {
        const items = picker.fieldItems.map(it => Object.assign({}, it, {
                enabled: enabled
            }));
        commitRules(items);
    }

    // ── Header Actions ────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: picker.fieldItems.length > 0 ? picker.fieldItems.length + " system fields" : "No system fields detected yet"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        StudioButton {
            visible: (studio.draft.osFieldRules || []).length > 0
            text: "Reset order"
            compact: true
            onClicked: picker.resetOrder()
        }

        StudioButton {
            visible: picker.fieldItems.length > 0
            text: "All"
            compact: true
            onClicked: picker.setAll(true)
        }

        StudioButton {
            visible: picker.fieldItems.length > 0
            text: "None"
            compact: true
            onClicked: picker.setAll(false)
        }
    }

    // ── Fields List ───────────────────────────────────────────────────────────
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: picker.fieldItems.length > 0

        Repeater {
            model: picker.fieldItems

            Rectangle {
                id: itemCard
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: 34
                radius: 6
                color: modelData.enabled ? Theme.sunk : "transparent"
                border.width: 1
                border.color: modelData.enabled ? Theme.line2 : Theme.line
                opacity: modelData.present ? 1.0 : 0.55

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    StudioCheck {
                        checked: itemCard.modelData.enabled
                        onToggled: picker.toggleField(itemCard.index)
                    }

                    Text {
                        text: itemCard.modelData.key
                        color: itemCard.modelData.enabled ? Theme.text : Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        Layout.preferredWidth: 130
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: itemCard.modelData.present ? itemCard.modelData.sample : "(not currently available)"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.italic: !itemCard.modelData.present
                        elide: Text.ElideRight
                    }

                    // Up button
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 4
                        color: upArea.containsMouse ? Theme.hover : "transparent"
                        opacity: itemCard.index > 0 ? 1.0 : 0.25

                        Text {
                            anchors.centerIn: parent
                            text: "▲"
                            font.pixelSize: 9
                            color: Theme.text
                        }

                        MouseArea {
                            id: upArea
                            anchors.fill: parent
                            hoverEnabled: itemCard.index > 0
                            enabled: itemCard.index > 0
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: picker.moveField(itemCard.index, itemCard.index - 1)
                        }
                    }

                    // Down button
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 4
                        color: downArea.containsMouse ? Theme.hover : "transparent"
                        opacity: itemCard.index < picker.fieldItems.length - 1 ? 1.0 : 0.25

                        Text {
                            anchors.centerIn: parent
                            text: "▼"
                            font.pixelSize: 9
                            color: Theme.text
                        }

                        MouseArea {
                            id: downArea
                            anchors.fill: parent
                            hoverEnabled: itemCard.index < picker.fieldItems.length - 1
                            enabled: itemCard.index < picker.fieldItems.length - 1
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: picker.moveField(itemCard.index, itemCard.index + 1)
                        }
                    }
                }
            }
        }
    }
}
