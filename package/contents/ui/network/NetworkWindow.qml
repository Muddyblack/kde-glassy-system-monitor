import QtQuick
import QtQuick.Window

// The network window as a normal, top-level window: title bar, its own
// taskbar entry, resizable, closable. Plasma creates it from the plasmoid;
// Quickshell wraps NetworkPage in a FloatingWindow instead. Size, position
// and the last tab live in the service's state (a file, see NetStore).
Window {
    id: win

    required property var service
    property bool themeIcons: true
    property var expandApps: []
    readonly property var savedState: service.state

    title: "Network — Glassy System Monitor"
    flags: Qt.Window
    transientParent: null
    minimumWidth: 720
    minimumHeight: 480
    // Set once from the saved state (a binding would snap back on every save).
    width: 1180
    height: 760
    color: content.theme.bg

    function saveGeometry() {
        service.saveState({
            width: win.width,
            height: win.height,
            x: win.x,
            y: win.y
        });
    }
    Component.onCompleted: {
        if (savedState.width >= minimumWidth && savedState.height >= minimumHeight) {
            width = savedState.width;
            height = savedState.height;
        }
        // Wayland compositors place windows themselves; X11 takes the spot.
        if (savedState.x !== undefined && savedState.y !== undefined) {
            x = savedState.x;
            y = savedState.y;
        }
    }
    onClosing: saveGeometry()

    NetworkPage {
        id: content
        anchors.fill: parent
        service: win.service
        themeIcons: win.themeIcons
        expandApps: win.expandApps
        onCloseRequested: win.close()
    }
}
