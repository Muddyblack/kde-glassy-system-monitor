import QtQuick
import ".." as Ui

// The app's theme icon (by .desktop Icon= or process name), else a letter.
Item {
    id: icon
    required property var theme
    property string iconName: ""
    property string name: ""
    property real size: 20
    implicitWidth: size
    implicitHeight: size

    // Only created for rows that name an icon; no fallback, so a name the
    // theme lacks leaves it not ready and the letter shows instead.
    Loader {
        id: image
        anchors.fill: parent
        active: icon.iconName !== "" && !!icon.theme.icons
        readonly property bool ready: !!item && item.ready
        sourceComponent: Ui.ThemeIcon {
            name: icon.iconName
            fallback: ""
            opacity: ready ? 1 : 0
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: !image.ready
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
