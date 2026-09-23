import QtQuick
import QtQuick.Window
import "../package/contents/ui" as Ui
import "../package/contents/ui/diagram" as D

// `make parity`: every chart style drawn by the fragment shader (left) and the
// canvas renderer (right) from the same live, scrolling synthetic data.
// `make parity SAVE=/path.png` writes one screenshot and exits.
Window {
    id: win
    width: 1000
    height: 1000
    visible: true
    color: "#15171c"
    title: "Glassy diagrams · GPU shader vs Canvas"

    readonly property string savePath: {
        const args = Qt.application.arguments;
        const at = args.indexOf("--save");
        return at >= 0 && at + 1 < args.length ? args[at + 1] : "";
    }
    readonly property var styles: ["line", "area", "bars", "donut", "pie", "meter"]
    property int history: 60
    property var cpu: []
    property var swap: []
    property var ping: []
    property bool smoothScroll: true
    property int tick: 0
    property int frame: 0

    function sample(t, prefill) {
        const push = (list, v) => list.concat([v]).slice(-(win.history + 1));
        cpu = push(cpu, 35 + 25 * Math.sin(t / 5) + 15 * Math.sin(t * 1.7));
        swap = push(swap, 20 + 15 * Math.cos(t / 4));
        ping = push(ping, t % 17 === 5 ? -1 : 18 + 10 * Math.sin(t / 3) + (t % 60 > 40 && t % 60 < 46 ? 70 : 0));
        if (!prefill)
            clock.sample();
    }
    Component.onCompleted: {
        for (let t = 0; t <= history; t++)
            sample(t, true);
        tick = history;
    }

    Ui.SampleClock {
        id: clock
        sampleInterval: 1000
        smooth: win.smoothScroll
    }
    Timer {
        interval: 1000
        running: win.savePath === ""
        repeat: true
        onTriggered: win.sample(++win.tick)
    }
    Ui.ScrollTicker {
        id: ticker
        running: win.savePath === "" && win.smoothScroll
        targetFps: 60
        onTick: ++win.frame
    }
    readonly property real phase: {
        win.frame;
        return clock.drawnPhase();
    }

    Text {
        x: 12
        y: 8
        text: "left: fragment shader · right: canvas (legacy) · click to toggle smooth scrolling (" + (win.smoothScroll ? "on" : "off") + ")"
        color: "#8a9187"
        font.pixelSize: 11
        MouseArea {
            anchors.fill: parent
            onClicked: win.smoothScroll = !win.smoothScroll
        }
    }

    Grid {
        x: 12
        y: 28
        columns: 2
        spacing: 12
        Repeater {
            model: win.styles.length * 2
            Column {
                id: cell
                required property int index
                readonly property string style: win.styles[Math.floor(index / 2)]
                readonly property string renderer: index % 2 ? "canvas" : "gpu"
                spacing: 2
                Text {
                    text: cell.style + " · " + cell.renderer
                    color: "#aaa"
                    font.pixelSize: 11
                }
                Rectangle {
                    width: (win.width - 36) / 2
                    height: (win.height - 28 - 6 * 30) / 6
                    color: "#0d0f14"
                    radius: 8
                    D.Diagram {
                        anchors.fill: parent
                        anchors.margins: 6
                        style: cell.style
                        renderer: cell.renderer
                        maxValue: 100
                        historySize: win.history
                        sampleSerial: clock.generation
                        livePhase: win.phase
                        smoothScroll: win.smoothScroll
                        textColor: "white"
                        ticks: [
                            {
                                value: 100,
                                text: "100%",
                                grid: false
                            },
                            {
                                value: 50,
                                text: "50%",
                                grid: true
                            },
                            {
                                value: 0,
                                text: "0%",
                                grid: false
                            }
                        ]
                        markers: [
                            {
                                value: 80,
                                color: "#ff8833"
                            }
                        ]
                        bands: ["#ffaa22", "#ff4444"]
                        centerText: Math.round(win.cpu[win.cpu.length - 1] || 0) + "%"
                        centerSubText: "cpu"
                        series: [
                            {
                                values: win.cpu,
                                color: "#44ddaa",
                                head: true,
                                label: "CPU",
                                text: Math.round(win.cpu[win.cpu.length - 1] || 0) + "%"
                            },
                            {
                                values: win.swap,
                                color: "#aa66ff",
                                alpha: 0.7,
                                width: 1.2,
                                glow: false,
                                label: "Swap",
                                text: Math.round(win.swap[win.swap.length - 1] || 0) + "%"
                            },
                            {
                                values: win.ping,
                                color: "#22aaff",
                                gaps: true,
                                bands: win.ping.map(v => v > 80 ? 2 : v > 25 ? 1 : 0),
                                label: "Ping",
                                text: Math.round(win.ping[win.ping.length - 1] || 0) + " ms"
                            }
                        ]
                    }
                }
            }
        }
    }

    Timer {
        interval: 900
        running: win.savePath !== ""
        onTriggered: win.contentItem.grabToImage(result => {
            result.saveToFile(win.savePath);
            console.log("parity: wrote " + win.savePath);
            Qt.quit();
        })
    }
}
