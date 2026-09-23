import QtQuick
import QtQuick.Controls.Basic as Controls
import "Theme.js" as Theme

// Dropdown (HTML `select.sel`): sunk field, 8 px radius, 170 px minimum.
Controls.ComboBox {
    id: control
    // [[value, label], …]
    property var options: []
    property var value
    signal chosen(var value)

    model: options
    textRole: "label"
    currentIndex: Math.max(0, options.findIndex(o => String(o[0]) === String(value)))
    displayText: options.length ? (options[currentIndex] ?? options[0])[1] : ""
    implicitWidth: Math.max(170, contentItem.implicitWidth + 40)
    implicitHeight: 32
    font.family: Theme.fontFamily
    font.pixelSize: 12
    onActivated: index => control.chosen(options[index][0])

    background: Rectangle {
        radius: 8
        color: Theme.sunk
        border.color: control.hovered ? "#33ffffff" : Theme.line2
        border.width: 1
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 24
        text: control.displayText
        color: Theme.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        color: Theme.muted
        font.pixelSize: 11
    }
    delegate: Controls.ItemDelegate {
        id: item
        required property var modelData
        required property int index
        width: control.width
        height: 30
        contentItem: Text {
            text: item.modelData[1]
            color: item.index === control.currentIndex ? Theme.brand : Theme.text
            font: control.font
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: item.hovered ? "#1affffff" : "transparent"
            radius: 6
        }
    }
    popup: Controls.Popup {
        y: control.height + 4
        width: control.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
        }
        background: Rectangle {
            radius: 10
            color: "#1a1c1e"
            border.color: Theme.line2
            border.width: 1
        }
    }
}
