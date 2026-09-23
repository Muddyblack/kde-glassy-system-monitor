import QtQuick

// A panel in the studio's look: soft gradient, hairline border, title.
Rectangle {
    id: card
    required property var theme
    property string title: ""
    property string subtitle: ""
    default property alias content: body.data
    property real padding: 14
    // The content fills a fixed-height card (a chart) instead of sizing it.
    property bool fill: false

    radius: 14
    border.width: 1
    border.color: theme.line2
    gradient: Gradient {
        GradientStop {
            position: 0
            color: card.theme.panelTop
        }
        GradientStop {
            position: 1
            color: card.theme.panelBottom
        }
    }
    implicitHeight: fill ? 0 : body.childrenRect.height + body.y + padding

    Text {
        id: titleText
        x: card.padding
        y: card.padding - 2
        visible: card.title !== ""
        text: card.title
        color: card.theme.muted
        font.family: card.theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: card.padding
        anchors.baseline: titleText.baseline
        visible: card.subtitle !== ""
        text: card.subtitle
        color: card.theme.dim
        font.family: card.theme.fontFamily
        font.pixelSize: 10
    }
    Item {
        id: body
        x: card.padding
        y: card.title !== "" ? titleText.y + titleText.implicitHeight + 10 : card.padding
        width: card.width - card.padding * 2
        height: card.fill ? Math.max(0, card.height - y - card.padding) : childrenRect.height
    }
}
