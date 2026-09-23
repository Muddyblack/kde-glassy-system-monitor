import QtQuick
import "../package/contents/ui/network" as Net

// `make network`: the network window on demo data, without Plasma or
// Quickshell. `-- --save file.png [--tab apps] [--expand app:id] [--light]` grabs one shot
// and quits (the website and README screenshot).
Net.NetworkWindow {
    id: win
    readonly property var args: Qt.application.arguments
    function arg(name) {
        const at = args.indexOf(name);
        return at >= 0 ? args[at + 1] : "";
    }
    readonly property string savePath: arg("--save")
    service: Net.NetworkService {
        demo: true
        windowOpen: true
    }
    themeIcons: false
    visible: true
    width: 1280
    height: 800
    expandApps: arg("--expand") ? arg("--expand").split(",") : []
    Component.onCompleted: service.state = {
        tab: arg("--tab") || "overview",
        dark: args.indexOf("--light") === -1
    }

    Timer {
        running: win.savePath !== ""
        interval: 2500
        // At the screen's scale (QT_SCALE_FACTOR=2 in make gallery).
        onTriggered: win.contentItem.grabToImage(result => {
            result.saveToFile(win.savePath);
            console.log("network: saved " + win.savePath);
            Qt.quit();
        }, Qt.size(win.width * win.screen.devicePixelRatio, win.height * win.screen.devicePixelRatio))
    }
}
