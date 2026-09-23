import QtQuick
import QtQuick.Effects

// A remote picture rounded off by a mask; `ready` once it has loaded.
Item {
    id: avatar
    property url source
    property real radius: 12
    readonly property bool ready: image.status === Image.Ready

    Image {
        id: image
        anchors.fill: parent
        source: avatar.source
        sourceSize: Qt.size(avatar.width * 2, avatar.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: avatar.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: avatar.ready
        source: image
        maskEnabled: true
        maskSource: mask
    }
}
