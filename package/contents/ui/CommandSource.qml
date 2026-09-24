import QtQuick
import "Probes.js" as Probes

// The subset of Plasma's executable DataSource the monitor uses. Hosts supply
// either the real DataSource (Plasma) or a Quickshell Process adapter.
Loader {
    id: source
    readonly property var connectedSources: item ? item.connectedSources : []
    // "user@host": commands run there over SSH (Probes.remoteCmd). Replies
    // name the wrapped command, which disconnectSource takes back as is.
    property string remote: ""
    signal newData(string source, var data)

    function connectSource(command) {
        if (item)
            item.connectSource(remote ? "sh -c " + Probes.quote(Probes.remoteCmd(remote, command)) : command);
    }
    function disconnectSource(command) {
        if (item)
            item.disconnectSource(command);
    }
    // Abandon every command still in flight; late replies are dropped.
    function reset() {
        for (const command of connectedSources.slice())
            disconnectSource(command);
    }

    Connections {
        target: source.item
        function onNewData(command, data) {
            source.newData(command, data);
        }
    }
}
