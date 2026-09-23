import QtQuick
import "Theme.js" as Theme
import "../diagram"
import "../Sections.js" as Sections
import ".."

// Tile artwork: a real Diagram for chart styles, section blocks for layouts.
Item {
    id: preview
    property string kind: "line"
    property var value
    property var studio: null
    property color ink: Theme.muted

    readonly property var wave: Array.from({
        length: 24
    }, (_, i) => 45 + 22 * Math.sin(i / 2.6) + 12 * Math.sin(i * 1.3))
    readonly property var low: wave.map(v => v * 0.45)

    Diagram {
        anchors.fill: parent
        anchors.margins: 5
        visible: preview.kind !== "layout" && preview.kind !== "text" && preview.kind !== "material"
        style: preview.kind
        historySize: 24
        axis: false
        smoothScroll: false
        lineWidth: 1.6
        glow: 0.5
        textColor: preview.ink
        onScreen: false
        maxValue: 100
        series: [
            {
                values: preview.wave,
                value: 64,
                color: Theme.brand,
                label: "",
                text: ""
            },
            {
                values: preview.low,
                value: 38,
                color: "#4aa8ff",
                label: "",
                text: ""
            }
        ]
    }
    Text {
        anchors.centerIn: parent
        visible: preview.kind === "text"
        text: "42%"
        color: preview.ink
        font.family: Theme.fontFamily
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }
    Column {
        anchors.fill: parent
        anchors.margins: 6
        visible: preview.kind === "layout"
        spacing: 3
        Repeater {
            model: preview.kind === "layout" ? Sections.parse(preview.value, 2) : []
            Rectangle {
                required property string modelData
                required property int index
                width: parent.width
                height: (parent.height - 3 * (Sections.parse(preview.value, 2).length - 1)) / Sections.parse(preview.value, 2).length
                radius: 3
                color: Qt.alpha(Theme.brand, 0.10 + 0.08 * (index % 2))
                border.color: Qt.alpha(preview.ink, 0.25)
                border.width: 1
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.height >= 9
                    text: Sections.info(parent.modelData).label
                    color: preview.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.min(9, parent.height - 2)
                }
            }
        }
    }

    // Card materials: the real card over a small wallpaper-like gradient.
    Loader {
        anchors.fill: parent
        active: preview.kind === "material"
        sourceComponent: Item {
            Rectangle {
                id: tileWall
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#5b1d6e"
                    }
                    GradientStop {
                        position: 1
                        color: "#1d6e8a"
                    }
                }
                Rectangle {
                    x: parent.width * 0.55
                    y: -parent.height * 0.3
                    width: parent.height
                    height: width
                    radius: width / 2
                    color: "#e0a03c"
                }
            }
            GlassCard {
                anchors.centerIn: parent
                width: parent.width * 0.74
                height: Math.min(34, parent.height - 8)
                material: String(preview.value)
                radiusTL: 9
                radiusTR: 9
                radiusBR: 9
                radiusBL: 9
                fill: "#b30d0f1a"
                frosted: false
                glassBlur: 0.6
                specular: false
                color1: Theme.brand
                color2: "#4aa8ff"
                backdrop: tileWall
            }
        }
    }
}
