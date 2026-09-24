import QtQuick

// A theme icon by name. Plasma draws it with Kirigami.Icon, which follows
// the platform icon theme; without Kirigami the image://icon provider is
// tried (Quickshell has one). The import sits behind a Loader so a missing
// Kirigami is a status here, not an error for the whole file.
Item {
    id: icon

    property string name: ""
    property string fallback: "computer"

    Loader {
        id: kirigami
        anchors.fill: parent
        Component.onCompleted: setSource("KirigamiIcon.qml", {
            host: icon
        })
    }
    Image {
        anchors.fill: parent
        visible: kirigami.status === Loader.Error
        source: visible ? "image://icon/" + (icon.name || icon.fallback) : ""
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }
}
