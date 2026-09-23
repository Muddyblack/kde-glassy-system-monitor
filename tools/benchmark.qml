import QtQuick
import QtQuick.Window
import "../package/contents/ui" as Ui

// `make benchmark`: the same four cards drawn by one renderer, on demo data
// at one sample a second with 60 fps smooth scrolling. It measures its own
// CPU time from /proc/self/stat and counts the frames it really rendered —
// a window the compositor stops drawing (covered, other workspace) shows up
// as low fps instead of as a flattering CPU figure. tools/benchmark.sh runs
// it once per renderer.
Window {
    id: win
    width: 1340
    height: 640
    visible: true
    color: "#15171c"
    title: "Glassy benchmark · " + renderer
    readonly property string renderer: {
        const args = Qt.application.arguments;
        const at = args.indexOf("--renderer");
        return at >= 0 ? args[at + 1] : "gpu";
    }
    readonly property bool smooth: Qt.application.arguments.indexOf("--static") === -1
    readonly property var cfg: ({
            sections: "cpu",
            chartType: 0,
            chartRenderer: renderer,
            historySize: 60,
            smoothScroll: win.smooth,
            smoothLines: true,
            lineWidth: 2.2,
            glowLine: true,
            bloomStrength: 0.6,
            gpuBloom: true,
            showYLabels: true,
            showLegend: true,
            autoYRange: true,
            showCpuCores: true,
            targetFps: 60,
            updateInterval: 1000,
            targets: "1.1.1.1",
            useSystemTextColor: true,
            bgColor: "#800d0f1a",
            bgRadiusTL: 12,
            bgRadiusTR: 12,
            bgRadiusBR: 12,
            bgRadiusBL: 12,
            frostedGlass: true,
            frostStrength: 0.55,
            cardBorder: true,
            disabledLinesStr: "",
            disabledCoresStr: ""
        })
    readonly property int seconds: {
        const args = Qt.application.arguments;
        const at = args.indexOf("--seconds");
        return at >= 0 ? Number(args[at + 1]) : 20;
    }
    property int frames: 0
    property var start: null
    onFrameSwapped: ++frames

    function cpuTicks() {
        const x = new XMLHttpRequest();
        x.open("GET", "file:///proc/self/stat", false);
        x.send();
        // Fields after the ")" of the command name; utime and stime are 14 and 15.
        const f = x.responseText.slice(x.responseText.lastIndexOf(")") + 2).split(" ");
        return Number(f[11]) + Number(f[12]);
    }
    // Five seconds to settle, then measure.
    Timer {
        interval: 5000
        running: true
        onTriggered: {
            win.frames = 0;
            win.start = {
                ticks: win.cpuTicks(),
                time: Date.now()
            };
            done.start();
        }
    }
    Timer {
        id: done
        interval: win.seconds * 1000
        onTriggered: {
            const secs = (Date.now() - win.start.time) / 1000;
            // Linux reports CPU time in 1/100 s ticks.
            const cpu = (win.cpuTicks() - win.start.ticks) / 100 / secs * 100;
            const fps = win.frames / secs;
            // Smooth runs should draw near 60 fps; far below means the window
            // was covered or on another workspace and the figure means nothing.
            const valid = !win.smooth || fps > 45;
            console.log("RESULT " + win.renderer + (win.smooth ? "" : " static") + " cpu=" + cpu.toFixed(1) + "% fps=" + fps.toFixed(1) + (win.smooth ? " cpu/frame=" + (cpu / Math.max(1, fps)).toFixed(3) + "%" : "") + (valid ? "" : "  INVALID: window was not being drawn, keep it visible"));
            Qt.quit();
        }
    }

    Ui.MonitorCore {
        id: core
        live: false
        cfg: win.cfg
        onScreen: true
    }
    Ui.DemoFeeder {
        monitor: core
    }
    Row {
        x: 10
        y: 10
        spacing: 10
        Repeater {
            model: ["cpu", "memory", "network", "disk"]
            Ui.MonitorView {
                required property string modelData
                width: 320
                height: 600
                monitor: core
                cfg: Object.assign({}, win.cfg, {
                    sections: modelData
                })
            }
        }
    }
}
