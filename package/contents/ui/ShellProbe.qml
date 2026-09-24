import QtQuick
import "OsFetch.js" as OsFetch

// Runs `command` every `interval` ms while `running`, one read at a time,
// and hands the output to `result`. A read that never returns is abandoned
// after four intervals so the probe cannot stall.
Item {
    id: probe

    property string command: ""
    property int interval: 5000
    property bool running: false
    property alias sourceComponent: source.sourceComponent
    property alias remote: source.remote
    signal result(string text)

    property bool busy: false
    property real _sentAt: 0

    function poll() {
        if (busy) {
            if (Date.now() - _sentAt < interval * 4)
                return;
            source.reset();
        }
        busy = true;
        _sentAt = Date.now();
        source.connectSource(OsFetch.shellCmd(command));
    }

    CommandSource {
        id: source
        onNewData: function (sourceName, data) {
            probe.busy = false;
            source.disconnectSource(sourceName);
            probe.result(data["stdout"] || "");
        }
    }
    Timer {
        interval: probe.interval
        running: probe.running && !!probe.command
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.poll()
    }
}
