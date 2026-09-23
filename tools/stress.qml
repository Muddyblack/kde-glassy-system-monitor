// Freeze repro: studio edits at slider speed. See TODO.md "Freeze investigation".
// QML_XHR_ALLOW_FILE_READ=1 tools/qml.sh tools/stress.qml -- --mode edits-lw --period 250 --per 1 --limit 100
import QtQuick
import QtQuick.Window
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Schema.js" as Schema
import "../package/contents/ui/studio/Looks.js" as Looks

Window {
    id: win
    width: 1280
    height: 820
    visible: true
    property var draft: ({})
    property var defaults: ({})
    function loadDefaults() {
        const x = new XMLHttpRequest();
        x.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        x.send();
        const out = {};
        const re = /<entry\s+name="([^"]+)"\s+type="([^"]+)"\s*>\s*<default>([^<]*)<\/default>/g;
        let m;
        while ((m = re.exec(x.responseText)) !== null)
            out[m[1]] = m[2] === "Bool" ? m[3] === "true" : (m[2] === "Int" || m[2] === "Double") ? Number(m[3]) : m[3];
        return out;
    }
    function rss() {
        const x = new XMLHttpRequest();
        x.open("GET", "file:///proc/self/status", false);
        x.send();
        return (x.responseText.match(/VmRSS:\s+(\d+)/) || [0, 0])[1] / 1024;
    }
    Studio.Studio {
        id: studio
        anchors.fill: parent
        draft: win.draft
        defaults: win.defaults
        onEdited: next => win.draft = next
    }
    property int i: 0
    property real work: 0
    readonly property int perTick: {
        const a = Qt.application.arguments;
        const at = a.indexOf("--per");
        return at >= 0 ? Number(a[at + 1]) : 3;
    }
    readonly property int period: {
        const a = Qt.application.arguments;
        const at = a.indexOf("--period");
        return at >= 0 ? Number(a[at + 1]) : 16;
    }
    property real last: Date.now()
    readonly property string mode: {
        const a = Qt.application.arguments;
        const at = a.indexOf("--mode");
        return at >= 0 ? a[at + 1] : "tabs,edits,looks";
    }
    readonly property int limit: {
        const a = Qt.application.arguments;
        const at = a.indexOf("--limit");
        return at >= 0 ? Number(a[at + 1]) : 200;
    }
    property real t0: Date.now()
    Timer {
        interval: win.period
        repeat: true
        running: true
        onTriggered: {
            const tabs = Schema.TABS;
            const t = Date.now();
            if (win.mode.indexOf("tabs") >= 0)
                studio.selectTab(tabs[win.i % tabs.length].id);
            if (win.mode.indexOf("edits") >= 0)
                for (let k = 0; k < win.perTick; k++) {
                    if (win.i < 40)
                        console.log("before update", win.i, k, Date.now() - t);
                    studio.update(win.mode.indexOf("lw") >= 0 ? {
                        lineWidth: 1 + ((win.i * 3 + k) % 40) / 10
                    } : win.mode.indexOf("radius") >= 0 ? {
                        bgRadiusTL: (win.i + k) % 30
                    } : {
                        lineWidth: 1 + ((win.i * 3 + k) % 40) / 10,
                        bgRadiusTL: (win.i + k) % 30
                    });
                    if (win.i < 40)
                        console.log("after update", win.i, k, Date.now() - t);
                }
            if (win.mode.indexOf("looks") >= 0 && win.i % 25 === 0)
                studio.update(Looks.apply(win.draft, win.defaults, Looks.BUILT_IN[(win.i / 25) % Looks.BUILT_IN.length].s));
            win.work += Date.now() - t;
            win.i++;
            if (win.mode.indexOf("edits") >= 0 && win.i < 30)
                console.log("edit", win.i, "handler", Date.now() - t, "since last", Date.now() - win.last);
            win.last = Date.now();
            if (win.i % 20 === 0) {
                console.log(win.mode, "iter", win.i, "wall ms/20:", Date.now() - win.t0, "handler ms:", win.work, "rss MB:", win.rss().toFixed(0));
                win.t0 = Date.now();
                win.work = 0;
            }
            if (win.i >= win.limit)
                Qt.quit();
        }
    }
    Component.onCompleted: {
        defaults = loadDefaults();
        draft = Object.assign({}, defaults, {
            sections: Schema.GROUPS.sections.join(",")
        });
    }
}
