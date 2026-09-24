import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format

// The window's own settings: alerts, desktop notifications, browser tabs,
// the optional password, trusted apps and daily limits. Recording and
// keeping the history live on the History page.
NetDialog {
    id: popup
    readonly property var service: page.service
    readonly property var alerts: service.alertSettings
    property string lockMessage: ""

    padding: 22
    width: Math.min(560, page.width - 40)
    height: Math.min(page.height - 40, body.implicitHeight + 44)
    function setAlert(key, on) {
        const next = Object.assign({}, service.state.alerts || {});
        next[key] = on;
        service.saveState({
            alerts: next
        });
    }

    component Toggle: RowLayout {
        id: toggle
        property string label: ""
        property string detail: ""
        property bool checked: false
        signal toggled(bool on)
        Layout.fillWidth: true
        spacing: 12
        Column {
            Layout.fillWidth: true
            Text {
                width: parent.width
                text: toggle.label
                color: popup.theme.text
                font.family: popup.theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                width: parent.width
                visible: toggle.detail !== ""
                text: toggle.detail
                wrapMode: Text.WordWrap
                color: popup.theme.dim
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }
        }
        NetSeg {
            theme: popup.theme
            options: [[false, "Off"], [true, "On"]]
            value: toggle.checked
            onActivated: v => toggle.toggled(v)
        }
    }
    component Heading: Text {
        Layout.topMargin: 6
        color: popup.theme.muted
        font.family: popup.theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }

    contentItem: Flickable {
        clip: true
        contentHeight: body.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 10
            Text {
                text: "Network window settings"
                color: popup.theme.text
                font.family: popup.theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Heading {
                text: "Alerts"
            }
            Toggle {
                label: "A new app goes online"
                detail: "The first connection of an app never seen before (trusted apps stay quiet)."
                checked: popup.alerts.newApp
                onToggled: on => popup.setAlert("newApp", on)
            }
            Toggle {
                label: "A port opens to the network"
                detail: "Something starts listening on an address other machines can reach."
                checked: popup.alerts.openPort
                onToggled: on => popup.setAlert("openPort", on)
            }
            Toggle {
                label: "A VPN drops"
                checked: popup.alerts.vpnDown
                onToggled: on => popup.setAlert("vpnDown", on)
            }
            Toggle {
                label: "An app reaches its daily limit"
                detail: "Set limits from an app's ⋯ menu on the Apps page."
                checked: popup.alerts.limit
                onToggled: on => popup.setAlert("limit", on)
            }
            Toggle {
                label: "Something looks dangerous"
                detail: "A serious finding on the Threats page: a listed address, a mining pool, a program running from a temporary folder."
                checked: popup.alerts.threat
                onToggled: on => popup.setAlert("threat", on)
            }
            Toggle {
                label: "Desktop notifications"
                detail: "Through notify-send; off keeps alerts in the window's bell only."
                checked: popup.alerts.notify
                onToggled: on => popup.setAlert("notify", on)
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: popup.service.recordMode === "on" ? "Alerts come while the widget runs, also with this window closed." : "With \"Record: always\" off (History page), alerts only come while this window is open."
                color: popup.theme.dim
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }

            Heading {
                text: "Browser sites"
            }
            Toggle {
                label: "Match connections to open browser tabs"
                detail: "Reads open tab addresses from Firefox- and Chromium-family session files: host names and titles only, kept in memory."
                checked: popup.service.tabsEnabled
                onToggled: on => popup.service.saveState({
                        tabs: on
                    })
            }

            Heading {
                text: "Password"
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: (popup.service.locked ? "The window asks for a password when it opens." : "No password: the window opens right away.") + " It locks the window only; the history files stay readable by your user account (they are private to it)."
                color: popup.theme.dim
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: 8
                    color: popup.theme.sunk
                    border.color: pw.activeFocus ? popup.theme.brand : popup.theme.line2
                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        color: popup.theme.text
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 12
                        Text {
                            visible: !pw.text
                            text: popup.service.locked ? "New password" : "Password"
                            color: popup.theme.dim
                            font: pw.font
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 30
                    radius: 8
                    color: popup.theme.sunk
                    border.color: pw2.activeFocus ? popup.theme.brand : popup.theme.line2
                    TextInput {
                        id: pw2
                        anchors.fill: parent
                        anchors.margins: 8
                        echoMode: TextInput.Password
                        color: popup.theme.text
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 12
                        Text {
                            visible: !pw2.text
                            text: "Again"
                            color: popup.theme.dim
                            font: pw2.font
                        }
                    }
                }
                NetButton {
                    theme: popup.theme
                    primary: true
                    text: popup.service.locked ? "Change" : "Set"
                    enabled: pw.text.length >= 4 && pw.text === pw2.text
                    tooltip: "At least 4 characters, typed twice"
                    onClicked: {
                        popup.service.setLock(pw.text);
                        pw.text = "";
                        pw2.text = "";
                        popup.lockMessage = "Password set.";
                    }
                }
                NetButton {
                    theme: popup.theme
                    visible: popup.service.locked
                    text: "Remove"
                    onClicked: {
                        popup.service.setLock("");
                        popup.lockMessage = "Password removed.";
                    }
                }
            }
            Text {
                visible: popup.lockMessage !== ""
                text: popup.lockMessage
                color: popup.theme.ok
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }

            Heading {
                text: "Trusted apps"
            }
            Text {
                visible: Object.keys(popup.service.trusted).length === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "None. Trust an app from its ⋯ menu: it gets a ✓ and raises no alerts."
                color: popup.theme.dim
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Object.keys(popup.service.trusted)
                    NetButton {
                        required property string modelData
                        theme: popup.theme
                        text: "✓ " + popup.service.trusted[modelData] + "  ✕"
                        tooltip: "Stop trusting"
                        onClicked: popup.service.trust({
                            key: modelData,
                            name: ""
                        }, false)
                    }
                }
            }

            Heading {
                text: "Daily limits"
            }
            Text {
                visible: Object.keys(popup.service.limits).length === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "None. Set one from an app's ⋯ menu. Limits count the app's TCP traffic of the day and need the history (Record not off)."
                color: popup.theme.dim
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }
            Repeater {
                model: Object.keys(popup.service.limits)
                RowLayout {
                    id: limitRow
                    required property string modelData
                    readonly property var l: popup.service.limits[modelData]
                    readonly property real used: popup.service.appToday(modelData)
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        Layout.preferredWidth: 150
                        text: limitRow.l.name
                        color: popup.theme.text
                        elide: Text.ElideRight
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 12
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 5
                        radius: 2.5
                        color: popup.theme.sunk
                        clip: true
                        Rectangle {
                            width: parent.width * Math.min(1, limitRow.used / limitRow.l.bytes)
                            height: parent.height
                            radius: 2.5
                            color: limitRow.used >= limitRow.l.bytes ? popup.theme.danger : popup.theme.brand
                        }
                    }
                    Text {
                        text: Format.bytes(limitRow.used) + " / " + Format.bytes(limitRow.l.bytes)
                        color: popup.theme.muted
                        font.family: popup.theme.fontFamily
                        font.pixelSize: 10
                    }
                    NetButton {
                        theme: popup.theme
                        text: "✕"
                        tooltip: "Remove the limit"
                        onClicked: popup.service.setLimit({
                            key: limitRow.modelData,
                            name: ""
                        }, 0)
                    }
                }
            }
            NetButton {
                Layout.alignment: Qt.AlignRight
                theme: popup.theme
                text: "Close"
                onClicked: popup.close()
            }
        }
    }
}
