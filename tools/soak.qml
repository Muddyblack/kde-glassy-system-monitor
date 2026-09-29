import QtQuick
import QtQuick.Window
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Looks.js" as Looks

// `make soak`: the studio in a real window, a built-in look applied every
// 250 ms. Fails (exit 1) when one edit blocks the GUI thread for over a
// second. Only a real window on the GPU catches the freeze this guards
// against (createImageData's memory accounting in Qt 6.11 underflows when
// the buffers are collected, causing ~30 s per edit). Reusing buffers only
// delayed the stall until the 59th edit, so run well past that point.
// Offscreen or software runs never stalled; `make test` cannot replace this.
//   tools/qml.sh tools/soak.qml -- [--edits N] [--tab presets] [--limit-ms 1000]
Window {
    id: win
    width: 1280
    height: 820
    visible: true
    color: "#0e0f10"
    title: "Glassy soak"

    function arg(name, fallback) {
        const args = Qt.application.arguments;
        const at = args.indexOf(name);
        return at >= 0 && at + 1 < args.length ? args[at + 1] : fallback;
    }
    readonly property int editCount: Number(arg("--edits", 120))
    readonly property int limitMs: Number(arg("--limit-ms", 1000))
    property var defaults: ({})
    property int edits: 0
    property real slowest: 0
    property real lastFrame: 0
    property real frameGap: 0

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
    Component.onCompleted: {
        defaults = loadDefaults();
        studio.draft = Object.assign({}, defaults);
        studio.selectTab(arg("--tab", "presets"));
        console.log("soak: graphics api " + GraphicsInfo.api + (GraphicsInfo.api === GraphicsInfo.Software ? " (software: this run proves nothing)" : ""));
    }

    Studio.Studio {
        id: studio
        anchors.fill: parent
        defaults: win.defaults
        onEdited: next => draft = next
    }

    FrameAnimation {
        running: true
        onTriggered: {
            const now = Date.now();
            if (win.lastFrame > 0)
                win.frameGap = Math.max(win.frameGap, now - win.lastFrame);
            win.lastFrame = now;
        }
    }
    Timer {
        interval: 250
        repeat: true
        running: win.edits < win.editCount
        onTriggered: {
            const look = Looks.BUILT_IN[win.edits % Looks.BUILT_IN.length];
            const start = Date.now();
            studio.edited(Looks.apply(studio.draft, win.defaults, look.s));
            const took = Date.now() - start;
            win.slowest = Math.max(win.slowest, took);
            console.log("soak: edit " + win.edits + " (" + look.id + ") " + took + " ms, longest frame gap " + win.frameGap + " ms");
            win.frameGap = 0;
            if (++win.edits < win.editCount && took <= win.limitMs)
                return;
            const ok = win.slowest <= win.limitMs;
            console.log("soak: " + (ok ? "PASS" : "FAIL") + ", " + win.edits + " edits, slowest " + win.slowest + " ms (limit " + win.limitMs + " ms)");
            Qt.exit(ok ? 0 : 1);
        }
    }
}
