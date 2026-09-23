import QtQuick
import QtQuick.Layouts

// Covers the window until the password is entered (when one is set). The
// check is a salted, iterated hash (NetLock.js); it locks this window, it
// does not encrypt the files.
Rectangle {
    id: lock
    required property var page
    readonly property var theme: page.theme
    property string error: ""
    signal unlocked

    color: theme.bg
    // Nothing behind it takes clicks or keys.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }
    onVisibleChanged: if (visible) {
        field.text = "";
        error = "";
        field.forceActiveFocus();
    }
    function tryUnlock() {
        if (page.service.checkLock(field.text)) {
            field.text = "";
            error = "";
            unlocked();
        } else {
            error = "Wrong password";
            field.selectAll();
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: 320
        spacing: 12
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "🔒"
            font.pixelSize: 34
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "The network window is locked"
            color: lock.theme.text
            font.family: lock.theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }
        Rectangle {
            Layout.fillWidth: true
            height: 34
            radius: 8
            color: lock.theme.sunk
            border.color: field.activeFocus ? lock.theme.brand : lock.theme.line2
            TextInput {
                id: field
                anchors.fill: parent
                anchors.margins: 9
                echoMode: TextInput.Password
                color: lock.theme.text
                font.family: lock.theme.fontFamily
                font.pixelSize: 13
                focus: true
                Keys.onReturnPressed: lock.tryUnlock()
                Keys.onEnterPressed: lock.tryUnlock()
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: lock.error
            visible: text !== ""
            color: lock.theme.danger
            font.family: lock.theme.fontFamily
            font.pixelSize: 11
        }
        NetButton {
            Layout.alignment: Qt.AlignHCenter
            theme: lock.theme
            primary: true
            text: "Unlock"
            onClicked: lock.tryUnlock()
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: "Forgot it? Remove \"lock\" from ~/.local/share/glassy-system-monitor/network-window.json."
            color: lock.theme.dim
            font.family: lock.theme.fontFamily
            font.pixelSize: 10
        }
    }
}
