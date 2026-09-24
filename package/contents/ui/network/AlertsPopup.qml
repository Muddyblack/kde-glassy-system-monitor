import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls

// The bell: recent alerts, newest first.
Controls.Popup {
    id: popup
    required property var page
    readonly property var theme: page.theme
    readonly property var icons: ({
            newApp: "✦",
            openPort: "⚠",
            vpnDown: "⛨",
            limit: "◔",
            threat: "⛔"
        })
    parent: page
    x: page.width - width - 18
    y: 56
    width: Math.min(420, page.width - 36)
    padding: 12
    modal: false
    focus: true
    background: Rectangle {
        radius: 12
        color: popup.theme.popup
        border.color: popup.theme.line2
    }
    contentItem: ColumnLayout {
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Alerts"
                color: popup.theme.text
                font.family: popup.theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            NetButton {
                theme: popup.theme
                text: "Settings…"
                onClicked: {
                    popup.close();
                    popup.page.openSettings();
                }
            }
        }
        Text {
            visible: popup.page.service.alertLog.length === 0
            text: "Nothing yet. New apps, ports opened to the network, a dropped VPN and reached limits show up here and as desktop notifications."
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: popup.theme.dim
            font.family: popup.theme.fontFamily
            font.pixelSize: 11
        }
        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            clip: true
            spacing: 6
            model: popup.page.service.alertLog
            delegate: RowLayout {
                id: entry
                required property var modelData
                width: ListView.view.width
                spacing: 10
                Text {
                    Layout.alignment: Qt.AlignTop
                    text: popup.icons[entry.modelData.kind] || "•"
                    color: entry.modelData.kind === "newApp" ? popup.theme.brand : popup.theme.warn
                    font.pixelSize: 14
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        width: parent.width
                        text: entry.modelData.title
                        color: popup.theme.text
                        wrapMode: Text.WordWrap
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: entry.modelData.body + "  ·  " + Qt.formatDateTime(new Date(entry.modelData.time), "ddd hh:mm")
                        color: popup.theme.muted
                        wrapMode: Text.WordWrap
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
