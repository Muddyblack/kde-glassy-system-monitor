import QtQuick
import QtQuick.Window
import "../package/contents/ui" as Ui
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Looks.js" as Looks

// `make gallery`: real screenshots for the README. Every scene
// is the actual widget or studio on demo data, grabbed one after another
// into docs/readme/. Run with QT_SCALE_FACTOR=2 for crisp
// images (tools/gallery.sh does).
Window {
    id: win
    width: 1280
    height: 820
    visible: true
    color: "#0e0f10"
    title: "Glassy gallery"

    readonly property string out: {
        const args = Qt.application.arguments;
        const at = args.indexOf("--out");
        return at >= 0 ? args[at + 1] : "docs/readme";
    }
    property var defaults: ({})
    property int step: -1
    property var scene: null
    readonly property var scenes: {
        const list = Looks.BUILT_IN.map(look => ({
                    kind: "look",
                    name: "look-" + look.id,
                    look: look,
                    backdrop: ["sea", "dusk", "breeze", "neon", "olive", "sea", "dusk", "breeze", "olive", "neon"][Looks.BUILT_IN.indexOf(look) % 10]
                }));
        return list.concat([
            {
                kind: "panel",
                name: "panel"
            },
            {
                kind: "studio",
                name: "studio-presets",
                tab: "presets"
            },
            {
                kind: "studio",
                name: "studio-layout",
                tab: "layout",
                look: Looks.BUILT_IN[1]
            },
            {
                kind: "studio",
                name: "studio-charts",
                tab: "charts",
                look: Looks.BUILT_IN[1]
            },
            {
                kind: "studio",
                name: "studio-card",
                tab: "card",
                look: Looks.BUILT_IN.find(l => l.id === "liquid")
            },
            {
                kind: "studio",
                name: "studio-performance",
                tab: "performance"
            },
            {
                kind: "studio",
                name: "studio-info",
                tab: "about"
            }
        ]);
    }

    function loadDefaults() {
        const x = new XMLHttpRequest();
        x.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        x.send();
        const out = {};
        const re = /<entry\s+name="([^"]+)"\s+type="([^"]+)"\s*>\s*<default>([^<]*)<\/default>/g;
        let m;
        while ((m = re.exec(x.responseText)) !== null)
            out[m[1]] = m[2] === "Bool" ? m[3] === "true" : (m[2] === "Int" || m[2] === "Double") ? Number(m[3]) : m[2] === "StringList" ? (m[3] ? m[3].split(",") : []) : m[3];
        return out;
    }
    function settingsFor(sceneData) {
        return Looks.apply(defaults, defaults, sceneData.look ? sceneData.look.s : {});
    }
    function next() {
        step++;
        if (step >= scenes.length) {
            console.log("gallery: wrote " + scenes.length + " images to " + out);
            Qt.quit();
            return;
        }
        scene = scenes[step];
        settle.restart();
    }
    Component.onCompleted: {
        defaults = loadDefaults();
        next();
    }

    Ui.MonitorCore {
        id: sample
        live: false
        cfg: win.scene ? win.settingsFor(win.scene) : win.defaults
        onScreen: false
    }
    Ui.DemoFeeder {
        monitor: sample
        running: false
    }

    Loader {
        id: stage
        active: !!win.scene
        sourceComponent: !win.scene ? null : win.scene.kind === "studio" ? studioScene : win.scene.kind === "panel" ? panelScene : lookScene
    }

    Component {
        id: lookScene
        Item {
            id: lookRoot
            readonly property Item target: lookRoot
            // Every look in the same 16:10 frame, the card scaled to fit, so
            // the website never has to crop one.
            width: 800
            height: 500
            // A sibling of the card, not its parent: glass samples it.
            Studio.Backdrop {
                id: lookWall
                anchors.fill: parent
                kind: win.scene.backdrop
            }
            Ui.MonitorView {
                id: card
                readonly property real fit: Math.min(1.4, (lookRoot.width - 120) / width, (lookRoot.height - 90) / height)
                x: (lookRoot.width - width * fit) / 2
                y: (lookRoot.height - height * fit) / 2
                width: preferredWidth
                height: preferredHeight
                scale: fit
                transformOrigin: Item.TopLeft
                monitor: sample
                cfg: win.settingsFor(win.scene)
                backdrop: lookWall
            }
        }
    }
    Component {
        id: panelScene
        Studio.Backdrop {
            id: panelRoot
            readonly property Item target: panelRoot
            kind: "neon"
            width: 640
            height: 180
            Rectangle {
                anchors.centerIn: parent
                width: 460
                height: 44
                radius: 12
                color: "#e0202326"
                border.color: "#14ffffff"
                Ui.CompactRepresentation {
                    anchors.centerIn: parent
                    width: implicitWidth
                    height: 34
                    monitor: sample
                    cfg: Object.assign({}, win.defaults, {
                        sections: "network"
                    })
                }
            }
        }
    }
    Component {
        id: studioScene
        Studio.Studio {
            id: studioRoot
            readonly property Item target: studioRoot
            // Fixed, not the window's size: a compositor may shrink the window,
            // which would switch the studio to its narrow layout.
            width: 1280
            height: 820
            draft: win.settingsFor(win.scene)
            defaults: win.defaults
            // The Loader keeps this instance across studio scenes, so follow
            // the scene's tab rather than setting it once.
            readonly property string sceneTab: win.scene ? win.scene.tab || "presets" : "presets"
            onSceneTabChanged: selectTab(sceneTab)
            Component.onCompleted: selectTab(sceneTab)
        }
    }

    // Let charts, text and the preview's demo data settle before grabbing.
    Timer {
        id: settle
        interval: 1800
        onTriggered: {
            const item = stage.item ? stage.item.target : null;
            if (!item) {
                win.next();
                return;
            }
            item.grabToImage(result => {
                result.saveToFile(win.out + "/" + win.scene.name + ".png");
                win.next();
            });
        }
    }
}
