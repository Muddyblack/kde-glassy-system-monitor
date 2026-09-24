import QtQuick

// A theme icon by name (or an absolute file path). Plasma draws it with
// Kirigami.Icon, which follows the platform icon theme and shares Qt's icon
// cache; without Kirigami the image://icon provider is tried (Quickshell has
// one). The import sits behind a Loader so a missing Kirigami is a status
// here, not an error for the whole file.
Item {
    id: icon

    property string name: ""
    property string fallback: "computer"
    // Something was drawn: the icon or its fallback.
    readonly property bool ready: kirigami.status === Loader.Ready ? !!kirigami.item && kirigami.item.status === 1 : image.status === Image.Ready

    Loader {
        id: kirigami
        anchors.fill: parent
        Component.onCompleted: setSource("KirigamiIcon.qml", {
            host: icon
        })
    }
    Image {
        id: image
        anchors.fill: parent
        visible: kirigami.status === Loader.Error
        source: !visible || !(icon.name || icon.fallback) ? "" : (icon.name || icon.fallback).charAt(0) === "/" ? "file://" + (icon.name || icon.fallback) : "image://icon/" + (icon.name || icon.fallback)
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }
}
