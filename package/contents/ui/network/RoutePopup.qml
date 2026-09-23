import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Probes.js" as Probes
import "../OsFetch.js" as OsFetch
import ".." as Ui

// One connection's latency (the kernel's RTT, from ss) over the session, and
// a trace route to its address on a click (tracepath / traceroute / mtr,
// no root). Hop names come from the reverse DNS cache as they resolve.
NetDialog {
    id: popup
    property var conn: null
    readonly property var live: conn ? (page.net.connections.find(c => c.key === conn.key) || conn) : null
    readonly property var series: conn ? page.net.rttSeries[conn.key] || [] : []
    property var hops: []
    property bool tracing: false
    property string traceNote: ""

    width: Math.min(640, page.width - 40)
    onOpened: {
        hops = [];
        traceNote = "";
    }
    function trace() {
        tracing = true;
        hops = [];
        traceNote = "Tracing…";
        source.connectSource(OsFetch.shellCmd(Probes.traceCmd(conn.ip)));
    }

    contentItem: ColumnLayout {
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: popup.conn ? popup.conn.app.name + "  →  " + (popup.page.hostOf(popup.conn).site || popup.page.hostOf(popup.conn).host || popup.conn.ip) + ":" + popup.conn.port : ""
            color: popup.theme.text
            elide: Text.ElideRight
            font.family: popup.theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            text: popup.live ? (popup.live.rtt !== null && popup.live.rtt !== undefined ? "Round trip now " + popup.live.rtt.toFixed(1) + " ms · congestion window " + popup.live.cwnd + " segments" : "No round-trip time: UDP, or another user's socket") + (popup.live.via ? " · via " + popup.live.via : "") : ""
            color: popup.theme.muted
            font.family: popup.theme.fontFamily
            font.pixelSize: 11
        }
        NetCard {
            theme: popup.theme
            title: "Latency"
            subtitle: "this session"
            fill: true
            Layout.fillWidth: true
            Layout.preferredHeight: 170
            visible: popup.series.length > 1
            RateChart {
                anchors.fill: parent
                theme: popup.theme
                seriesIn: popup.series
                capacity: popup.page.net.seriesSize
                step: popup.page.net.interval / 1000
                floor: 1
                format: v => v.toFixed(v < 10 ? 1 : 0) + " ms"
                inLabel: "RTT"
            }
        }
        RowLayout {
            Layout.fillWidth: true
            NetButton {
                theme: popup.theme
                primary: true
                text: popup.tracing ? "Tracing…" : "Trace route"
                enabled: !popup.tracing && !!popup.conn && Probes.safeIp(popup.conn.ip)
                tooltip: "tracepath (or traceroute / mtr) to the address, up to 20 hops"
                onClicked: popup.trace()
            }
            Text {
                Layout.fillWidth: true
                text: popup.traceNote
                color: popup.theme.dim
                elide: Text.ElideRight
                font.family: popup.theme.fontFamily
                font.pixelSize: 10
            }
        }
        Repeater {
            model: popup.hops
            RowLayout {
                id: hop
                required property var modelData
                readonly property var name: popup.page.net.hosts[modelData.ip]
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.preferredWidth: 22
                    horizontalAlignment: Text.AlignRight
                    text: hop.modelData.hop
                    color: popup.theme.dim
                    font.family: "monospace"
                    font.pixelSize: 11
                }
                Text {
                    Layout.preferredWidth: 150
                    text: hop.modelData.ip || "* no reply"
                    color: hop.modelData.ip ? popup.page.kindColor(Probes.addressKind(hop.modelData.ip)) : popup.theme.dim
                    font.family: "monospace"
                    font.pixelSize: 11
                }
                Text {
                    Layout.fillWidth: true
                    text: hop.name ? hop.name.name + (hop.name.org ? "  · " + hop.name.org : "") : ""
                    color: popup.theme.muted
                    elide: Text.ElideRight
                    font.family: popup.theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    text: hop.modelData.ms >= 0 ? hop.modelData.ms.toFixed(1) + " ms" : ""
                    color: popup.theme.text
                    font.family: popup.theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
        NetButton {
            Layout.alignment: Qt.AlignRight
            theme: popup.theme
            text: "Close"
            onClicked: popup.close()
        }
    }

    Ui.CommandSource {
        id: source
        sourceComponent: popup.page.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            source.disconnectSource(sourceName);
            const out = String(data["stdout"] || "");
            popup.tracing = false;
            popup.hops = Probes.parseTrace(out);
            popup.traceNote = popup.hops.length ? popup.hops.length + " hops" : out.indexOf("none:") === 0 ? out.slice(6).trim() : "No route information (offline, or the tool is missing)";
            popup.page.net.resolveIps(popup.hops.map(h => h.ip).filter(Boolean));
        }
    }
}
