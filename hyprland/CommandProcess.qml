pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// Quickshell's Process behind the executable-DataSource API CommandSource
// expects: connectSource(command) runs `sh -c command` once and reports its
// stdout through newData, unless the command was disconnected first.
Item {
    id: root
    property var connectedSources: []
    property var _processes: Object.create(null)
    signal newData(string source, var data)

    function connectSource(source) {
        if (_processes[source])
            return;
        const process = command.createObject(root, {
            source: source
        });
        _processes[source] = process;
        connectedSources = connectedSources.concat([source]);
        process.running = true;
    }
    function disconnectSource(source) {
        const process = _processes[source];
        delete _processes[source];
        connectedSources = connectedSources.filter(value => value !== source);
        // Destroying a Process kills it and releases its stdout/stderr buffers.
        // Merely removing its name left hung commands alive after every retry.
        if (process) {
            stopGroup(process);
            process.destroy();
        }
    }

    function stopGroup(process) {
        if (!(process.processId > 0))
            return;
        // Probes contain pipelines and nested shells. Killing only the outer
        // shell leaves those children running. Under setsid each command has
        // its own group; without setsid no group matches and this does nothing.
        groupKiller.command = ["sh", "-c", 'kill -KILL -- -"$1" 2>/dev/null', "glassy-cancel", String(process.processId)];
        groupKiller.startDetached();
    }
    Process {
        id: groupKiller
    }
    Component.onDestruction: {
        for (const source of connectedSources)
            stopGroup(_processes[source]);
    }

    Component {
        id: command
        Process {
            id: process
            required property string source
            // setsid (util-linux) is optional, as in Wireshark.js: with it the
            // command gets its own group for stopGroup; without it destroy()
            // still kills the outer shell. exec keeps the pid equal to the group.
            command: ["sh", "-c", 'command -v setsid >/dev/null 2>&1 && exec setsid sh -c "$1"; exec sh -c "$1"', "glassy", source]
            stdout: StdioCollector {}
            stderr: StdioCollector {}
            function finish(exitCode, error) {
                // An older instance must not complete a retry of the same command.
                if (root._processes[source] === process) {
                    delete root._processes[source];
                    root.connectedSources = root.connectedSources.filter(value => value !== source);
                    root.newData(source, {
                        stdout: stdout.text,
                        stderr: error || stderr.text,
                        "exit code": exitCode
                    });
                }
                process.destroy();
            }
            onExited: exitCode => finish(exitCode, "")
            // FailedToStart changes running without emitting exited.
            onRunningChanged: if (!running && root._processes[source] === process)
                finish(127, "Could not start command; check that sh is installed.")
        }
    }
}
