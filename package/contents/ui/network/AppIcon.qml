import QtQuick

// The app's theme icon (by .desktop Icon= or process name), else a letter.
Item {
    id: icon
    required property var theme
    property string iconName: ""
    property string name: ""
    property real size: 20
    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: icon.iconName === "" || !icon.theme.icons ? "" : icon.iconName.charAt(0) === "/" ? "file://" + icon.iconName : "image://icon/" + icon.iconName
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: image.status !== Image.Ready
        radius: icon.size * 0.28
        readonly property real hue: {
            let h = 0;
            for (let i = 0; i < icon.name.length; i++)
                h = (h * 31 + icon.name.charCodeAt(i)) % 360;
            return h / 360;
        }
        color: Qt.hsla(hue, 0.45, icon.theme.dark ? 0.32 : 0.8, 1)
        Text {
            anchors.centerIn: parent
            text: (icon.name.replace(/[^A-Za-z0-9]/g, "").charAt(0) || "?").toUpperCase()
            color: icon.theme.dark ? "#ffffff" : "#1b2224"
            font.family: icon.theme.fontFamily
            font.pixelSize: icon.size * 0.52
            font.weight: Font.DemiBold
        }
    }
}
