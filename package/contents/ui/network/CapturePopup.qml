import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "Wireshark.js" as Wireshark
import "../DemoData.js" as DemoData
import "../Probes.js" as Probes
import "../OsFetch.js" as OsFetch
import ".." as Ui

// Names for addresses that only show a number: tshark listens for a few
// seconds, on request, to DNS answers and TLS / QUIC server names. Only
// names and addresses leave tshark; nothing is saved. Wireshark itself
// opens from here and from the row menus for everything else.
Controls.Popup {
    id: popup
    required property var page
    readonly property var theme: page.theme
    readonly property var net: page.net
    readonly property var tools: net.captureTools
    property int seconds: 10
    property bool running: false
    property int left: 0
    property string error: ""
    // [{ ip, name, source, fresh, app }] of the last capture.
    property var found: []
    property int dnsCount: 0
    property int tlsCount: 0
    // A capture has finished (the "nothing heard" note).
    property bool done: false

    parent: page
    anchors.centerIn: parent
    modal: true
    focus: true
    padding: 20
    width: Math.min(620, page.width - 40)
    background: Rectangle {
        radius: 14
        color: popup.theme.popup
        border.color: popup.theme.line2
    }

    function start() {
        error = "";
        found = [];
        running = true;
        left = seconds;
        countdown.restart();
        if (!net.demo)
            source.connectSource(OsFetch.shellCmd(Wireshark.sniffCmd(seconds)));
    }
    function finish(stdout, stderr, code) {
        running = false;
        done = true;
        countdown.stop();
        const problem = Wireshark.sniffError(stderr, code);
        error = problem === "permission" ? Wireshark.PERMISSION_HELP : problem === "missing" ? Wireshark.INSTALL_HELP : problem;
        const r = Wireshark.parseSniff(stdout);
        dnsCount = r.dns;
        tlsCount = r.tls;
        // Which app talks to each address, and which had no name before.
        const byIp = {};
        for (const c of net.connections)
            if (!byIp[c.ip])
                byIp[c.ip] = c.app.name;
        const rows = [];
        for (const ip in r.names) {
            const before = net.hosts[ip];
            rows.push({
                ip: ip,
                name: r.names[ip].name,
                source: r.names[ip].source,
                fresh: !before || !before.name || before.name !== r.names[ip].name,
                app: byIp[ip] || ""
            });
        }
        // Addresses in use first, then the rest by name.
        rows.sort((a, b) => (b.app !== "") - (a.app !== "") || a.name.localeCompare(b.name));
        found = rows;
        if (rows.length)
            net.learnNames(r.names);
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            popup.left = Math.max(0, popup.left - 1);
            if (popup.left === 0 && popup.net.demo)
                popup.finish(DemoData.NET_CAPTURE, "", 0);
        }
    }
    Ui.CommandSource {
        id: source
        sourceComponent: popup.page.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            source.disconnectSource(sourceName);
            popup.finish(String(data["stdout"] || ""), String(data["stderr"] || ""), Number(data["exit code"] || 0));
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        Text {
            text: "Learn names from traffic"
            color: popup.theme.text
            font.family: popup.theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "tshark listens on all interfaces for a few seconds to DNS answers and to the server names apps ask for when a TLS or QUIC connection starts. The names go to the Domain column for this session; nothing is saved and no contents are read."
            color: popup.theme.muted
            font.family: popup.theme.fontFamily
            font.pixelSize: 11
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            NetSeg {
                theme: popup.theme
                options: [[5, "5 s"], [10, "10 s"], [30, "30 s"]]
                value: popup.seconds
                enabled: !popup.running
                onActivated: v => popup.seconds = v
            }
            NetButton {
                theme: popup.theme
                primary: true
                enabled: popup.tools.tshark && !popup.running
                text: popup.running ? "Listening… " + popup.left + " s" : "Listen"
                tooltip: "tshark -i any, DNS and TLS / QUIC client hellos only"
                onClicked: popup.start()
            }
            Item {
                Layout.fillWidth: true
            }
            NetButton {
                theme: popup.theme
                visible: popup.tools.wireshark
                text: "Open Wireshark ↗"
                tooltip: "All interfaces, no filter"
                onClicked: {
                    popup.page.wireshark("any", "", "all interfaces");
                    popup.close();
                }
            }
        }
        // Not installed, no permission, or tshark's own complaint.
        Rectangle {
            Layout.fillWidth: true
            visible: helpText.text !== ""
            implicitHeight: helpText.implicitHeight + 20
            radius: 10
            color: Qt.rgba(popup.theme.warn.r, popup.theme.warn.g, popup.theme.warn.b, 0.08)
            border.color: Qt.rgba(popup.theme.warn.r, popup.theme.warn.g, popup.theme.warn.b, 0.3)
            Text {
                id: helpText
                x: 12
                y: 10
                width: parent.width - 24
                wrapMode: Text.WordWrap
                text: !popup.tools.tshark && !popup.net.demo ? "tshark is not installed. " + Wireshark.INSTALL_HELP : popup.error
                color: popup.theme.muted
                font.family: popup.theme.fontFamily
                font.pixelSize: 11
            }
        }
        Text {
            visible: !popup.running && popup.error === "" && (popup.dnsCount + popup.tlsCount > 0 || popup.found.length > 0)
            text: popup.found.length + " addresses named · " + popup.dnsCount + " DNS answers · " + popup.tlsCount + " server names · " + popup.found.filter(f => f.fresh && f.app).length + " new for live connections"
            color: popup.theme.dim
            font.family: popup.theme.fontFamily
            font.pixelSize: 10
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 260)
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: popup.found
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            delegate: RowLayout {
                id: hit
                required property var modelData
                width: list.width - 10
                height: 26
                spacing: 10
                NetBadge {
                    Layout.preferredWidth: 34
                    theme: popup.theme
                    text: hit.modelData.source === "tls" ? "SNI" : "DNS"
                    tint: hit.modelData.source === "tls" ? popup.theme.brand : popup.theme.rx
                }
                Text {
                    Layout.preferredWidth: 170
                    text: hit.modelData.ip
                    color: popup.page.kindColor(Probes.addressKind(hit.modelData.ip))
                    elide: Text.ElideRight
                    font.family: "monospace"
                    font.pixelSize: 10
                }
                Text {
                    Layout.fillWidth: true
                    text: hit.modelData.name
                    color: hit.modelData.fresh ? popup.theme.text : popup.theme.muted
                    elide: Text.ElideLeft
                    font.family: popup.theme.fontFamily
                    font.pixelSize: 11
                }
                Text {
                    Layout.preferredWidth: 110
                    horizontalAlignment: Text.AlignRight
                    text: hit.modelData.app
                    color: popup.theme.dim
                    elide: Text.ElideRight
                    font.family: popup.theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
        Text {
            visible: !popup.running && popup.error === "" && popup.found.length === 0 && popup.dnsCount + popup.tlsCount === 0 && popup.done
            text: "Nothing heard: no new connections started while listening. Open a page or an app and listen again."
            color: popup.theme.dim
            font.family: popup.theme.fontFamily
            font.pixelSize: 11
        }
        NetButton {
            Layout.alignment: Qt.AlignRight
            theme: popup.theme
            text: "Close"
            onClicked: popup.close()
        }
    }
}
