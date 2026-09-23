import QtQuick
import QtQuick.Effects
import "card"

// The widget's card. "tint" is the classic tinted fill with optional frost
// and four independent corners; the other materials (glass, liquid glass,
// solid, atmosphere) come from the audio visualizer and use one radius.
// Every layer is static: it repaints on size or setting changes only.
Item {
    id: card

    property string material: "tint"
    property color fill: "#800d0f1a"
    property real radiusTL: 12
    property real radiusTR: 12
    property real radiusBR: 12
    property real radiusBL: 12
    property bool frosted: true
    property real frostStrength: 0.55
    property bool border: true

    property string glassTint: "clear"
    property color glassTintColor: "#3daee9"
    property real glassBlur: 0.85
    property real refraction: 0.5
    property bool specular: true
    property real surfaceOpacity: 1
    property string shadow: "none"
    property bool grain: false
    // Atmosphere colours: the first sections' own colours.
    property color color1: "#4aa8ff"
    property color color2: "#b07cff"
    // The wallpaper to blur under glass; null where the host has none.
    property Item backdrop: null

    readonly property real maxRadius: Math.max(radiusTL, radiusTR, radiusBR, radiusBL)
    readonly property bool tinted: material === "tint" || ["glass", "liquid", "solid", "atmosphere"].indexOf(material) === -1
    readonly property bool glassy: material === "glass" || material === "liquid"
    readonly property var shadowLayers: shadow === "lifted" ? [
        {
            y: 24,
            blur: 60,
            color: Qt.rgba(0, 0, 0, 0.45)
        },
        {
            y: 6,
            blur: 16,
            color: Qt.rgba(0, 0, 0, 0.25)
        }
    ] : [
        {
            y: 10,
            blur: 30,
            color: Qt.rgba(0, 0, 0, 0.3)
        },
        {
            y: 2,
            blur: 6,
            color: Qt.rgba(0, 0, 0, 0.2)
        }
    ]

    component Shape: Rectangle {
        anchors.fill: parent
        topLeftRadius: card.radiusTL
        topRightRadius: card.radiusTR
        bottomRightRadius: card.radiusBR
        bottomLeftRadius: card.radiusBL
    }

    // Behind everything, and not faded with the card.
    Loader {
        anchors.fill: parent
        anchors.margins: -90
        active: card.shadow === "soft" || card.shadow === "lifted"
        sourceComponent: CardGlow {
            objectName: "cardShadow"
            margin: 90
            radius: card.maxRadius
            layers: card.shadowLayers
        }
    }

    Item {
        id: surface
        anchors.fill: parent
        opacity: card.surfaceOpacity

        // ── Tint ──
        Shape {
            visible: card.tinted && !card.frosted
            color: card.fill
        }
        // Frost: blur the fill and a vertical sheen together, so the blur
        // smears the sheen into a soft glass gradient, then round it off.
        Shape {
            id: frostSource
            visible: false
            layer.enabled: card.tinted && card.frosted
            color: card.fill
            Shape {
                color: "transparent"
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, 0.10)
                    }
                    GradientStop {
                        position: 0.35
                        color: Qt.rgba(1, 1, 1, 0.025)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(0, 0, 0, 0.06)
                    }
                }
            }
        }
        Shape {
            id: frostMask
            visible: false
            layer.enabled: card.tinted && card.frosted
            color: "black"
        }
        MultiEffect {
            anchors.fill: parent
            visible: card.tinted && card.frosted
            source: frostSource
            blurEnabled: true
            blur: card.frostStrength
            blurMax: 40
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: frostMask
        }
        Loader {
            anchors.fill: parent
            active: card.tinted && card.grain
            sourceComponent: CardGrain {
                radius: card.maxRadius
            }
        }
        // Crisp hairline and top highlight above the blur: the edge is what
        // reads as glass.
        Shape {
            visible: card.tinted && card.border
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.13)
        }
        Rectangle {
            visible: card.tinted && card.border && card.width > 24
            x: 12
            y: 1
            width: card.width - 24
            height: 1
            color: Qt.rgba(1, 1, 1, 0.21)
        }

        // ── Materials ──
        Loader {
            anchors.fill: parent
            active: card.glassy && (card.glassBlur > 0 || card.refraction > 0) && !!card.backdrop && GraphicsInfo.api !== GraphicsInfo.Software
            sourceComponent: BackdropBlur {
                strength: card.glassBlur
                refraction: card.material === "liquid" ? card.refraction : 0
                specular: card.specular
                lightPoint: materialLayer.item ? materialLayer.item.specularPoint : Qt.point(width * 0.22, -height * 0.1)
                sourceItem: card.backdrop
                radius: card.maxRadius
            }
        }
        Loader {
            id: materialLayer
            anchors.fill: parent
            active: !card.tinted
            sourceComponent: CardMaterial {
                material: card.material
                solidColor: card.fill
                radius: card.maxRadius
                grain: card.grain
                glassTint: card.glassTint
                glassTintColor: card.glassTintColor
                specular: card.specular
                edgeHighlight: card.border
                cover1: card.color1
                cover2: card.color2
                cover3: Qt.rgba(card.color1.r * 0.2 + card.color2.r * 0.1, card.color1.g * 0.2 + card.color2.g * 0.1, card.color1.b * 0.2 + card.color2.b * 0.1, 1)
            }
        }
    }
}
