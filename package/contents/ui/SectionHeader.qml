import QtQuick

// Section title on the left, the section's headline reading on the right.
Item {
    id: header

    property string title: ""
    property string reading: ""
    property color readingColor: textColor
    property color textColor: "white"
    // Optional extra content between title and reading (chips, totals).
    default property alias extra: middle.data

    implicitHeight: Math.max(titleText.implicitHeight, readingText.implicitHeight)

    Text {
        id: titleText
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        color: header.textColor
        opacity: 0.85
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 0.3
        elide: Text.ElideRight
        width: Math.min(implicitWidth, header.width - readingText.implicitWidth - 12)
    }
    Row {
        id: middle
        anchors.left: titleText.right
        anchors.leftMargin: 10
        anchors.right: readingText.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        clip: true
    }
    Text {
        id: readingText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: header.reading
        color: header.readingColor
        font.pixelSize: 14
        font.bold: true
        Behavior on color {
            ColorAnimation {
                duration: 300
            }
        }
    }
}
