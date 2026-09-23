pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// Quickshell's Process behind the executable-DataSource API CommandSource
// expects: connectSource(command) runs `sh -c command` once and reports its
// stdout through newData, unless the command was disconnected first.
Item {
    id: root
    property var connectedSources: []
    signal newData(string source, var data)

    function connectSource(source) {
        if (connectedSources.indexOf(source) !== -1)
            return;
        connectedSources = connectedSources.concat([source]);
        command.createObject(root, {
            source: source
        }).running = true;
    }
    function disconnectSource(source) {
        connectedSources = connectedSources.filter(value => value !== source);
    }

    Component {
        id: command
        Process {
            id: process
            required property string source
            command: ["sh", "-c", source]
            stdout: StdioCollector {}
            stderr: StdioCollector {}
            onExited: exitCode => {
                // A disconnected command was abandoned; drop its late reply.
                if (root.connectedSources.indexOf(source) !== -1) {
                    root.disconnectSource(source);
                    root.newData(source, {
                        stdout: stdout.text,
                        stderr: stderr.text,
                        "exit code": exitCode
                    });
                }
                process.destroy();
            }
        }
    }
}
