import QtQuick
import "StudioCatalog.js" as Catalog

// One static image, shared with the browser demo; no repaint loop.
Rectangle {
    id: backdrop
    property string kind: "dusk"
    // Raise for captures grabbed above 1:1; previews stay at 1.
    property real detail: 1
    property int decodeWidth: 1600
    readonly property var wallpaper: Catalog.StudioCatalog.wallpapers.find(item => item.id === kind) || Catalog.StudioCatalog.wallpapers[0]
    color: wallpaper.color
    clip: true
    // Cache the composited backdrop as a GPU texture so that resizing the
    // settings window only scales the texture rather than re-rendering or
    // re-rasterising (SVG) the image on every geometry update.
    layer.enabled: true
    layer.smooth: true
    Image {
        objectName: "wallpaperImage"
        anchors.fill: parent
        source: Qt.resolvedUrl("wallpapers/" + backdrop.wallpaper.file)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        // Resizing only scales the texture. Geometry-dependent decode sizes
        // repeatedly reload the asynchronous image and flash the fallback color.
        sourceSize.width: Math.max(1, Math.ceil(backdrop.decodeWidth * backdrop.detail))
    }
}
