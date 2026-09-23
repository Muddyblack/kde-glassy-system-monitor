import QtQuick
import QtQuick.Layouts

// Ranked rows with a bar: top apps, countries or domains.
ColumnLayout {
    id: list
    required property var theme
    // [{ label, icon, flag, value (for the bar), text }]
    property var rows: []
    property string empty: "Nothing yet"
    spacing: 8

    Text {
        visible: list.rows.length === 0
        text: list.empty
        color: list.theme.dim
        font.family: list.theme.fontFamily
        font.pixelSize: 11
    }
    Repeater {
        model: list.rows
        ColumnLayout {
            id: entry
            required property var modelData
            required property int index
            // The largest row, whatever the order (rows can rank by rate while
            // the bar shows bytes); bars never leave their track.
            readonly property real peak: Math.max(1e-9, ...list.rows.map(r => r.value || 0))
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                AppIcon {
                    visible: entry.modelData.icon !== undefined
                    theme: list.theme
                    size: 16
                    iconName: entry.modelData.icon || ""
                    name: entry.modelData.label
                }
                Flag {
                    country: entry.modelData.flag || ""
                    font.pixelSize: 13
                }
                Text {
                    Layout.fillWidth: true
                    text: entry.modelData.label
                    color: list.theme.text
                    elide: Text.ElideRight
                    font.family: list.theme.fontFamily
                    font.pixelSize: 12
                }
                Text {
                    text: entry.modelData.text
                    color: list.theme.muted
                    font.family: list.theme.fontFamily
                    font.pixelSize: 11
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                clip: true
                color: list.theme.sunk
                Rectangle {
                    width: parent.width * Math.max(0.02, Math.min(1, (entry.modelData.value || 0) / entry.peak))
                    height: parent.height
                    radius: 2
                    color: list.theme.brand
                    opacity: 0.85 - entry.index * 0.12
                    Behavior on width {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
