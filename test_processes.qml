import QtQuick
import Quickshell
import "hyprland" as Hypr

// QML_XHR_ALLOW_FILE_READ=1 qs -p test_processes.qml
// Kept at the config root so Quickshell can import hyprland/.
// Real subprocess cancellation, including children, and same-command retries.
// Uses no windows, system probes, or persistent files.
Scope {
    id: test
    property int round: 0
    property int stage: 0
    property var pids: []
    property int replies: 0
    property real started: Date.now()
    property var disposable: null
    // The final ':' prevents the shell from replacing itself with sleep.
    readonly property string slow: "sleep 30; :"

    function read(path) {
        const request = new XMLHttpRequest();
        request.open("GET", "file://" + path, false);
        request.send();
        return request.responseText;
    }
    function fail(reason) {
        console.error("process lifecycle: FAIL: " + reason);
        Qt.exit(1);
    }
    function alive(pid) {
        const stat = read("/proc/" + pid + "/stat");
        // An exited child may briefly await reaping by init.
        return !!stat && stat.slice(stat.lastIndexOf(")") + 2, stat.lastIndexOf(")") + 3) !== "Z";
    }
    Hypr.CommandProcess {
        id: runner
        onNewData: (source, data) => {
            if (source !== "printf done" || data.stdout !== "done")
                test.fail("a cancelled command delivered a reply");
            ++test.replies;
        }
    }
    Component {
        id: disposableRunner
        Hypr.CommandProcess {}
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (Date.now() - test.started > 15000) {
                test.fail("timed out at stage " + test.stage);
                return;
            }
            if (test.stage === 0) {
                runner.connectSource(test.slow);
                test.stage = 1;
            } else if (test.stage === 1) {
                const process = runner._processes[test.slow];
                const pid = process.processId;
                if (!(pid > 0))
                    return;
                const children = test.read("/proc/" + pid + "/task/" + pid + "/children").trim();
                if (!children)
                    return;
                test.pids = [pid].concat(children.split(/\s+/).map(Number));
                runner.disconnectSource(test.slow);
                // Reconnect before deferred destruction of the old Process.
                runner.connectSource(test.slow);
                test.stage = 2;
            } else if (test.stage === 2) {
                if (test.pids.some(pid => test.alive(pid)))
                    return;
                const process = runner._processes[test.slow];
                if (!process || !(process.processId > 0)) {
                    test.fail("old command removed its replacement");
                    return;
                }
                const pid = process.processId;
                const children = test.read("/proc/" + pid + "/task/" + pid + "/children").trim();
                test.pids = [pid].concat(children ? children.split(/\s+/).map(Number) : []);
                runner.disconnectSource(test.slow);
                test.stage = 3;
            } else if (test.stage === 3) {
                if (test.pids.some(pid => test.alive(pid)))
                    return;
                if (runner.connectedSources.length || Object.keys(runner._processes).length) {
                    test.fail("cancelled commands are still retained");
                    return;
                }
                if (++test.round < 50) {
                    test.stage = 0;
                } else {
                    runner.connectSource("printf done");
                    test.stage = 4;
                }
            } else if (test.stage === 4 && test.replies === 1) {
                if (runner.connectedSources.length || Object.keys(runner._processes).length) {
                    test.fail("completed command is still retained");
                    return;
                }
                test.disposable = disposableRunner.createObject(test);
                test.disposable.connectSource(test.slow);
                test.stage = 5;
            } else if (test.stage === 5) {
                const pid = test.disposable._processes[test.slow].processId;
                if (!(pid > 0))
                    return;
                const children = test.read("/proc/" + pid + "/task/" + pid + "/children").trim();
                if (!children)
                    return;
                test.pids = [pid].concat(children.split(/\s+/).map(Number));
                test.disposable.destroy();
                test.disposable = null;
                test.stage = 6;
            } else if (test.stage === 6 && !test.pids.some(pid => test.alive(pid))) {
                console.log("process lifecycle: PASS: 100 cancellations, child cleanup, retries, normal completion and owner destruction");
                Qt.quit();
            }
        }
    }
}
