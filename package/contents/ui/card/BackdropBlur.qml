pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Only capture the supplied wallpaper, never the widget's foreground or an
// ancestor containing this effect (which would create a recursive texture).
Item {
    id: root
    property Item sourceItem: null
    property real radius: 16
    property real strength: 0.85
    property real refraction: 0.5
    property bool specular: true
    property point lightPoint: Qt.point(width * 0.22, -height * 0.1)
    readonly property bool safeSource: {
        if (!sourceItem)
            return false;
        for (let item = root; item; item = item.parent)
            if (item === sourceItem)
                return false;
        return true;
    }
    readonly property bool available: safeSource && sourceItem.Window.window === root.Window.window && GraphicsInfo.api !== GraphicsInfo.Software

    // mapToItem alone doesn't subscribe to ancestor movement. Read the geometry
    // of both chains so dragging/resizing/scaling the widget updates the crop.
    readonly property var geometrySignature: {
        const geometry = [];
        for (const start of [root, sourceItem])
            for (let item = start; item; item = item.parent)
                geometry.push(item.x, item.y, item.width, item.height, item.scale, item.rotation);
        return geometry;
    }
    readonly property rect sampleRect: {
        const geometry = geometrySignature;
        return sourceItem && geometry.length ? root.mapToItem(sourceItem, 0, 0, width, height) : Qt.rect(0, 0, 0, 0);
    }

    Loader {
        anchors.fill: parent
        active: (root.strength > 0 || root.refraction > 0) && root.available && root.visible && root.width > 0 && root.height > 0
        sourceComponent: Item {
            ShaderEffectSource {
                id: wallpaperTexture
                width: root.width
                height: root.height
                sourceItem: root.sourceItem
                sourceRect: root.sampleRect
                // Round up to the next 8-pixel boundary so the GPU texture is
                // not reallocated on every resize pixel, which causes flicker.
                textureSize: Qt.size(Math.max(1, Math.ceil(root.width / 8) * 8), Math.max(1, Math.ceil(root.height / 8) * 8))
                live: true
                hideSource: false
                visible: false
            }
            MultiEffect {
                id: blurred
                visible: false
                objectName: "wallpaperBlurEffect"
                anchors.fill: parent
                source: wallpaperTexture
                blurEnabled: root.strength > 0
                blurMax: 48
                blur: Math.max(0, Math.min(1, root.strength))
                autoPaddingEnabled: false
                maskEnabled: false
            }
            ShaderEffectSource {
                id: blurredTexture
                sourceItem: blurred
                hideSource: true
                live: true
                visible: false
            }
            ShaderEffect {
                objectName: "glassRefractionEffect"
                anchors.fill: parent
                property var source: blurredTexture
                property size canvasSize: Qt.size(width, height)
                property real radius: root.radius
                property real refraction: Math.max(0, Math.min(1, root.refraction))
                property real specular: root.specular ? 1 : 0
                property point lightPoint: root.lightPoint
                fragmentShader: Qt.resolvedUrl("../../shaders/glass_refraction.frag.qsb")
            }
        }
    }
}
