import QtQuick

// Section title on the left, the section's headline reading on the right.
Item {
    id: header

    property string title: ""
    property string reading: ""
    property color readingColor: textColor
    property color textColor: "white"
    property string fontFamily: Qt.application.font.family
    // Optional extra content between title and reading (chips, totals).
    default property alias extra: middle.data
    // Width left for that extra content between title and reading.
    readonly property real room: middle.width
    // With a monitor and a line key the reading acts as that line's legend
    // entry: hover highlights the line, click hides it.
    property var monitor: null
    property string lineKey: ""
    readonly property bool lineShown: !monitor || lineKey === "" || !monitor.isLineDisabled(lineKey)

    implicitHeight: Math.max(titleText.implicitHeight, readingText.implicitHeight)

    Text {
        id: titleText
        font.family: header.fontFamily
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
        font.family: header.fontFamily
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: header.reading
        color: header.readingColor
        opacity: header.lineShown ? 1 : 0.3
        font.pixelSize: 14
        font.bold: true
        font.strikeout: !header.lineShown
        Behavior on color {
            ColorAnimation {
                duration: 300
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !!header.monitor && header.lineKey !== ""
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: header.monitor.toggleLineDisabled(header.lineKey)
            onEntered: header.monitor.hoveredLine = header.lineKey
            onExited: if (header.monitor.hoveredLine === header.lineKey)
                header.monitor.hoveredLine = ""
        }
    }
}
