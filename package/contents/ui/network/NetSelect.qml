import QtQuick
import QtQuick.Controls.Basic as Controls

// Dropdown in the studio's style: [[value, label], …].
Controls.ComboBox {
    id: control
    required property var theme
    property var options: []
    property var value
    signal chosen(var value)

    model: options
    currentIndex: Math.max(0, options.findIndex(o => String(o[0]) === String(value)))
    displayText: options.length ? (options[currentIndex] || options[0])[1] : ""
    implicitWidth: Math.max(130, Math.min(220, contentItem.implicitWidth + 36))
    implicitHeight: 28
    font.family: theme.fontFamily
    font.pixelSize: 11
    onActivated: index => control.chosen(options[index][0])

    background: Rectangle {
        radius: 8
        color: control.theme.sunk
        border.color: control.activeFocus ? control.theme.brand : control.theme.line2
        border.width: 1
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 22
        text: control.displayText
        color: control.theme.text
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - width - 9
        anchors.verticalCenter: parent.verticalCenter
        text: "▾"
        color: control.theme.muted
        font.pixelSize: 11
    }
    delegate: Controls.ItemDelegate {
        id: item
        required property var modelData
        required property int index
        width: control.width
        height: 28
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: item.modelData[1]
            color: item.index === control.currentIndex ? control.theme.brand : control.theme.text
            font: control.font
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: item.hovered || item.highlighted ? control.theme.hover : "transparent"
            radius: 6
        }
    }
    popup: Controls.Popup {
        y: control.height + 4
        width: Math.max(control.width, 180)
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 340)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
        background: Rectangle {
            radius: 10
            color: control.theme.popup
            border.color: control.theme.line2
            border.width: 1
        }
    }
}
