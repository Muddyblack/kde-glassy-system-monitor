import QtQuick
import QtQuick.Controls.Basic as Controls

// A modal dialog centred over the network window, in its theme.
Controls.Popup {
    id: dialog
    required property var page
    readonly property var theme: page.theme

    parent: page
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 20
    background: Rectangle {
        radius: 14
        color: dialog.theme.popup
        border.color: dialog.theme.line2
    }
}
