import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format

// A daily data limit for one app: presets or any number of GiB.
NetDialog {
    id: popup
    property var app: null
    readonly property var current: app ? page.service.limits[app.key] : null
    width: 380
    function set(bytes) {
        page.service.setLimit(app, bytes);
        close();
    }
    contentItem: ColumnLayout {
        spacing: 10
        Text {
            text: "Daily limit for " + (popup.app ? popup.app.name : "")
            color: popup.theme.text
            font.family: popup.theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Glassy never blocks anything: at the limit you get an alert, and the Apps page shows it red. Today so far: " + (popup.app ? Format.bytes(popup.page.service.appToday(popup.app.key)) : "") + "."
            color: popup.theme.muted
            font.family: popup.theme.fontFamily
            font.pixelSize: 11
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [[100, "100 MiB"], [500, "500 MiB"], [1024, "1 GiB"], [5120, "5 GiB"], [10240, "10 GiB"], [51200, "50 GiB"]]
                NetButton {
                    required property var modelData
                    theme: popup.theme
                    text: modelData[1]
                    checked: !!popup.current && popup.current.bytes === modelData[0] * 1048576
                    onClicked: popup.set(modelData[0] * 1048576)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 8
                color: popup.theme.sunk
                border.color: gib.activeFocus ? popup.theme.brand : popup.theme.line2
                TextInput {
                    id: gib
                    anchors.fill: parent
                    anchors.margins: 8
                    color: popup.theme.text
                    font.family: popup.theme.fontFamily
                    font.pixelSize: 12
                    validator: DoubleValidator {
                        bottom: 0.01
                        top: 100000
                    }
                    Text {
                        visible: !gib.text
                        text: "Other, in GiB"
                        color: popup.theme.dim
                        font: gib.font
                    }
                    Keys.onReturnPressed: if (acceptableInput)
                        popup.set(Number(text) * 1073741824)
                }
            }
            NetButton {
                theme: popup.theme
                primary: true
                text: "Set"
                enabled: gib.acceptableInput
                onClicked: popup.set(Number(gib.text) * 1073741824)
            }
            NetButton {
                theme: popup.theme
                visible: !!popup.current
                text: "Remove"
                onClicked: popup.set(0)
            }
        }
    }
}
