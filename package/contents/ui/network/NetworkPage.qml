import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "NetTheme.js" as NetTheme
import "NetModel.js" as NetModel
import "Wireshark.js" as Wireshark
import "../Probes.js" as Probes
import "../Format.js" as Format

// The network window's content, shared by the Plasma Window and the
// Quickshell FloatingWindow: Overview, Apps, Connections, Listening and
// Interfaces over one NetworkMonitor. Read-only: Glassy watches, it never
// blocks. The one action that changes anything, ending a process, asks first.
Rectangle {
    id: page

    // The host's NetworkService: monitor, saved state, history.
    required property var service
    readonly property var net: service.monitor
    readonly property var savedState: service.state
    // False where no image://icon provider exists (plain `qml`): letters.
    property bool themeIcons: true
    // App keys the Apps page opens with (screenshots).
    property var expandApps: []
    signal closeRequested

    readonly property var tabs: [
        {
            id: "overview",
            label: "Overview"
        },
        {
            id: "apps",
            label: "Apps"
        },
        {
            id: "connections",
            label: "Connections"
        },
        {
            id: "listening",
            label: "Listening"
        },
        {
            id: "interfaces",
            label: "Interfaces"
        },
        {
            id: "containers",
            label: "Containers"
        },
        {
            id: "history",
            label: "History"
        },
        {
            id: "threats",
            label: "Threats"
        }
    ]
    property int currentTab: Math.max(0, tabs.findIndex(t => t.id === savedState.tab))
    property bool dark: savedState.dark !== false
    readonly property var theme: Object.assign({}, dark ? NetTheme.dark : NetTheme.light, {
        icons: themeIcons
    })
    function selectTab(i) {
        currentTab = (i + tabs.length) % tabs.length;
        service.saveState({
            tab: tabs[currentTab].id
        });
    }
    function toggleTheme() {
        dark = !dark;
        service.saveState({
            dark: dark
        });
    }

    // ── Filters ──────────────────────────────────────────────────────────────
    property string query: ""
    property string fApp: ""
    property string fProto: ""
    property string fDirection: ""
    property string fScope: ""
    property string fCountry: ""
    property bool showEnded: true
    readonly property bool filtering: query !== "" || fApp !== "" || fProto !== "" || fDirection !== "" || fScope !== "" || fCountry !== "" || !showEnded
    function clearFilters() {
        query = "";
        fApp = "";
        fProto = "";
        fDirection = "";
        fScope = "";
        fCountry = "";
        showEnded = true;
    }

    readonly property var allApps: NetModel.apps(net.connections)
    readonly property var filtered: NetModel.filter(net.connections, {
        query: query,
        app: fApp,
        proto: fProto,
        direction: fDirection,
        scope: fScope,
        country: fCountry,
        ended: showEnded
    }, net.hosts, net.sites)
    readonly property var appList: NetModel.apps(filtered)
    readonly property var summary: NetModel.overview(net.connections, net.hosts, net.sites)
    readonly property var countryOptions: {
        const seen = {};
        for (const c of net.connections) {
            const cc = net.hosts[c.ip] ? net.hosts[c.ip].country : "";
            if (cc)
                seen[cc] = true;
        }
        return [["", "All countries"]].concat(Object.keys(seen).sort().map(cc => [cc, Probes.flag(cc) + " " + cc]));
    }
    readonly property var appOptions: [["", "All apps"]].concat(allApps.map(a => [a.key, a.name]))
    readonly property real now: net.updatedAt

    // ── Helpers for the pages ────────────────────────────────────────────────
    function hostOf(c) {
        return NetModel.describe(c, net.hosts, net.sites);
    }
    function kindColor(kind) {
        return kind === "internet" ? theme.rx : kind === "lan" ? theme.ok : kind === "multicast" ? theme.warn : theme.muted;
    }
    function since(c) {
        return NetModel.duration((c.ended ? c.endedAt : now) - c.since);
    }
    function copy(text) {
        clipboard.text = text;
        clipboard.selectAll();
        clipboard.copy();
        toast.show("Copied " + text);
    }
    // Actions for a connection (or, with conn null, just the process; with
    // `listen`, a listening socket).
    function showActions(conn, pid, name, item, app, listen) {
        actions.app = app || (conn ? conn.app : null);
        actions.conn = conn;
        actions.listen = listen || null;
        actions.pid = pid || 0;
        actions.procName = name || "";
        if (item) {
            const p = item.mapToItem(page, item.width / 2, item.height / 2);
            actions.popup(page, p.x, p.y);
        } else {
            actions.popup();
        }
    }
    // Wireshark on `iface` with a capture filter; `what` names it in the toast.
    function wireshark(iface, filter, what) {
        if (net.demo)
            toast.show("Demo data: Wireshark opens on a real system");
        else if (net.openWireshark(iface, filter))
            toast.show("Opening Wireshark on " + (iface === "any" ? "all interfaces" : iface) + (what ? " · " + what : ""));
        else
            toast.show("Wireshark is not installed");
    }
    // The dialogs, for tools/network.qml and tests.
    readonly property var dialogs: ({
            capture: capturePopup,
            settings: settingsPopup,
            alerts: alertsPopup,
            limit: limitPopup,
            route: routePopup,
            geo: geoSetup
        })
    // Unlocked for as long as the window stays open.
    property bool unlocked: false
    function openSettings() {
        settingsPopup.open();
    }
    function exportFile(kind) {
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmm");
        if (kind === "connections")
            page.service.store.exportText("glassy-network-connections-" + stamp + ".csv", NetModel.connectionsCsv(filtered, net.hosts, net.sites));
        else if (kind === "historyCsv")
            page.service.store.exportText("glassy-network-history-" + stamp + ".csv", NetModel.historyCsv(page.service.history));
        else
            page.service.store.exportText("glassy-network-history-" + stamp + ".json", JSON.stringify(page.service.history, null, 1));
        toast.show("Exporting…");
    }
    Connections {
        target: page.service.store
        function onExported(path, ok) {
            toast.show(ok ? "Saved " + path : "Could not export");
        }
    }
    function askKill(pid, name) {
        if (!(pid > 1))
            return;
        confirm.pid = pid;
        confirm.procName = name;
        confirm.open();
    }

    color: theme.bg
    focus: true
    // Container stats cost the daemon a second: only while they are shown.
    Binding {
        target: page.net
        property: "firewallShown"
        value: page.visible && (page.tabs[page.currentTab].id === "listening" || page.tabs[page.currentTab].id === "threats")
    }
    Binding {
        target: page.net
        property: "containersShown"
        value: page.visible && page.tabs[page.currentTab].id === "containers"
    }

    Connections {
        target: page.net
        function onKillFinished(pid, ok, message) {
            toast.show(ok ? "Sent the end signal to PID " + pid : "Could not end PID " + pid + (message ? ": " + message : ""));
        }
    }

    // ── Keyboard ─────────────────────────────────────────────────────────────
    Shortcut {
        sequences: ["Ctrl+1"]
        onActivated: page.selectTab(0)
    }
    Shortcut {
        sequences: ["Ctrl+2"]
        onActivated: page.selectTab(1)
    }
    Shortcut {
        sequences: ["Ctrl+3"]
        onActivated: page.selectTab(2)
    }
    Shortcut {
        sequences: ["Ctrl+4"]
        onActivated: page.selectTab(3)
    }
    Shortcut {
        sequences: ["Ctrl+5"]
        onActivated: page.selectTab(4)
    }
    Shortcut {
        sequences: ["Ctrl+6"]
        onActivated: page.selectTab(5)
    }
    Shortcut {
        sequences: ["Ctrl+7"]
        onActivated: page.selectTab(6)
    }
    Shortcut {
        sequences: ["Ctrl+8"]
        onActivated: page.selectTab(7)
    }
    Shortcut {
        sequences: ["Ctrl+Tab", "Ctrl+PgDown"]
        onActivated: page.selectTab(page.currentTab + 1)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]
        onActivated: page.selectTab(page.currentTab - 1)
    }
    Shortcut {
        sequences: [StandardKey.Find, "/"]
        enabled: !search.activeFocus
        onActivated: search.forceActiveFocus()
    }
    Shortcut {
        sequences: ["Ctrl+P"]
        onActivated: net.paused = !net.paused
    }
    Shortcut {
        sequences: [StandardKey.Refresh, "Ctrl+R"]
        onActivated: net.refresh()
    }
    Shortcut {
        sequences: ["Ctrl+Shift+L"]
        onActivated: page.toggleTheme()
    }
    Shortcut {
        sequences: [StandardKey.Close]
        onActivated: page.closeRequested()
    }
    Shortcut {
        sequences: ["Escape"]
        enabled: !actions.visible && !confirm.visible
        onActivated: {
            if (page.query !== "" || search.activeFocus) {
                page.query = "";
                pages.forceActiveFocus();
            } else if (page.filtering) {
                page.clearFilters();
            } else {
                page.closeRequested();
            }
        }
    }

    TextEdit {
        id: clipboard
        visible: false
    }

    // ── Header ───────────────────────────────────────────────────────────────
    Rectangle {
        id: header
        width: parent.width
        height: headerCol.implicitHeight + 20
        color: page.theme.panel
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: page.theme.line2
        }

        ColumnLayout {
            id: headerCol
            x: 18
            y: 12
            width: parent.width - 36
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: net.paused ? page.theme.warn : page.theme.brand
                    SequentialAnimation on opacity {
                        running: !net.paused && page.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.35
                            duration: 900
                        }
                        NumberAnimation {
                            to: 1
                            duration: 900
                        }
                    }
                }
                Column {
                    Text {
                        text: "Network"
                        color: page.theme.text
                        font.family: page.theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Read-only · Glassy shows what talks to the network and never blocks anything"
                        color: page.theme.dim
                        font.family: page.theme.fontFamily
                        font.pixelSize: 10
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                // Search across everything.
                Rectangle {
                    Layout.preferredWidth: Math.min(300, Math.max(160, page.width * 0.24))
                    height: 30
                    radius: 8
                    color: page.theme.sunk
                    border.width: 1
                    border.color: search.activeFocus ? page.theme.brand : page.theme.line2
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        color: page.theme.dim
                        font.pixelSize: 14
                    }
                    TextInput {
                        id: search
                        x: 28
                        width: parent.width - 58
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.query
                        onTextEdited: page.query = text
                        color: page.theme.text
                        selectionColor: page.theme.selected
                        font.family: page.theme.fontFamily
                        font.pixelSize: 12
                        clip: true
                        Keys.onDownPressed: pages.forceActiveFocus()
                        Keys.onReturnPressed: pages.forceActiveFocus()
                        Text {
                            visible: !search.text && !search.activeFocus
                            text: "Search everything…"
                            color: page.theme.dim
                            font: search.font
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: page.theme.line2
                        Text {
                            anchors.centerIn: parent
                            text: page.query !== "" ? "✕" : "/"
                            color: page.theme.dim
                            font.pixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.query = ""
                        }
                    }
                }
                NetButton {
                    theme: page.theme
                    text: page.service.alertLog.length ? "🔔 " + page.service.alertLog.length : "🔔"
                    tooltip: "Alerts"
                    onClicked: alertsPopup.open()
                }
                NetButton {
                    theme: page.theme
                    text: "🦈 Capture"
                    tooltip: "Learn names from traffic with tshark, or open Wireshark"
                    onClicked: capturePopup.open()
                }
                NetButton {
                    id: exportButton
                    theme: page.theme
                    text: "Export ▾"
                    tooltip: "Save the connections or the history as a file in Downloads"
                    onClicked: exportMenu.popup(exportButton, 0, exportButton.height + 4)
                }
                NetButton {
                    theme: page.theme
                    text: "⚙"
                    tooltip: "Alerts, browser sites, password, trusted apps, limits"
                    onClicked: page.openSettings()
                }
                NetButton {
                    theme: page.theme
                    text: net.paused ? "▶ Resume" : "❚❚ Pause"
                    checked: net.paused
                    tooltip: "Freeze the lists (Ctrl+P)"
                    onClicked: net.paused = !net.paused
                }
                NetButton {
                    theme: page.theme
                    text: page.dark ? "☀" : "☾"
                    tooltip: "Light / dark (Ctrl+Shift+L)"
                    onClicked: page.toggleTheme()
                }
            }

            // Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: page.tabs
                    Rectangle {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool on: page.currentTab === index
                        readonly property string count: {
                            switch (modelData.id) {
                            case "apps":
                                return String(page.summary.apps);
                            case "connections":
                                return String(page.summary.active);
                            case "listening":
                                return String(net.listening.length);
                            case "interfaces":
                                return String(net.interfaces.length);
                            case "containers":
                                return String(Object.values(net.containers).reduce((a, e) => a + e.containers.length, 0));
                            case "history":
                                return page.service.recording ? "●" : "";
                            case "threats":
                                return String(page.service.threats.counts.high + page.service.threats.counts.medium);
                            }
                            return "";
                        }
                        implicitWidth: tabRow.implicitWidth + 22
                        implicitHeight: 30
                        radius: 8
                        color: on ? page.theme.selected : tabArea.containsMouse ? page.theme.hover : "transparent"
                        border.width: on ? 1 : 0
                        border.color: page.theme.selectedBorder
                        Row {
                            id: tabRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: tab.modelData.label
                                color: tab.on ? page.theme.text : page.theme.muted
                                font.family: page.theme.fontFamily
                                font.pixelSize: 12
                                font.weight: tab.on ? Font.DemiBold : Font.Normal
                            }
                            Text {
                                visible: tab.count !== "" && tab.count !== "0"
                                text: tab.count
                                color: tab.modelData.id === "threats" ? (page.service.threats.counts.high > 0 ? page.theme.danger : page.theme.warn) : page.theme.dim
                                font.family: page.theme.fontFamily
                                font.pixelSize: 10
                                anchors.baseline: parent.children[0].baseline
                            }
                        }
                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.selectTab(tab.index)
                        }
                        Controls.ToolTip {
                            visible: tabArea.containsMouse
                            text: "Ctrl+" + (tab.index + 1)
                            delay: 700
                        }
                    }
                }
            }

            // Filters, where they apply.
            Flow {
                Layout.fillWidth: true
                visible: page.tabs[page.currentTab].id === "apps" || page.tabs[page.currentTab].id === "connections"
                spacing: 6
                NetSelect {
                    theme: page.theme
                    visible: page.tabs[page.currentTab].id === "connections"
                    options: page.appOptions
                    value: page.fApp
                    onChosen: v => page.fApp = v
                }
                NetSeg {
                    theme: page.theme
                    options: [["", "All"], ["tcp", "TCP"], ["udp", "UDP"]]
                    value: page.fProto
                    onActivated: v => page.fProto = v
                }
                NetSeg {
                    theme: page.theme
                    options: [["", "Both ways"], ["out", "Outgoing"], ["in", "Incoming"]]
                    value: page.fDirection
                    onActivated: v => page.fDirection = v
                }
                NetSeg {
                    theme: page.theme
                    options: [["", "Anywhere"], ["internet", "Internet"], ["local", "Local"]]
                    value: page.fScope
                    onActivated: v => page.fScope = v
                }
                NetSelect {
                    theme: page.theme
                    visible: net.geo.country
                    options: page.countryOptions
                    value: page.fCountry
                    onChosen: v => page.fCountry = v
                }
                NetButton {
                    theme: page.theme
                    text: page.showEnded ? "✓ Ended ones" : "Ended ones"
                    checked: page.showEnded
                    tooltip: "Keep connections that closed this session (greyed)"
                    onClicked: page.showEnded = !page.showEnded
                }
                NetButton {
                    theme: page.theme
                    visible: page.filtering
                    text: "Clear filters"
                    onClicked: page.clearFilters()
                }
            }
        }
    }

    // ── Pages ────────────────────────────────────────────────────────────────
    StackLayout {
        id: pages
        anchors.top: header.bottom
        anchors.bottom: footer.top
        width: parent.width
        currentIndex: page.currentTab
        focus: true
        onCurrentIndexChanged: if (children[currentIndex])
            children[currentIndex].forceActiveFocus()

        OverviewPage {
            page: page
        }
        AppsPage {
            page: page
        }
        ConnectionsPage {
            page: page
        }
        ListeningPage {
            page: page
        }
        InterfacesPage {
            page: page
        }
        ContainersPage {
            page: page
        }
        HistoryPage {
            page: page
        }
        ThreatsPage {
            page: page
        }
    }

    // ── Footer ───────────────────────────────────────────────────────────────
    Rectangle {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        height: 30
        color: page.theme.panel
        Rectangle {
            width: parent.width
            height: 1
            color: page.theme.line2
        }
        Text {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60 - hint.implicitWidth - (geoButton.visible ? geoButton.width + 12 : 0)
            elide: Text.ElideRight
            text: [net.paused ? "Paused" : net.demo ? "Demo data" : "Live · every " + (net.interval / 1000) + " s", page.summary.active + " connections", page.summary.apps + " apps", page.summary.ended > 0 ? page.summary.ended + " ended this session" : "", net.limited ? "Other users' processes (system services) show without a name: ss needs root to see them" : "", "", net.tabs.length ? net.tabs.length + " browser tabs matched" : ""].filter(Boolean).join("  ·  ")
            color: page.theme.dim
            font.family: page.theme.fontFamily
            font.pixelSize: 10
        }
        NetButton {
            id: geoButton
            anchors.right: hint.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            theme: page.theme
            visible: !net.demo
            text: net.geo.country ? "🌍 GeoIP" : "🌍 Show countries…"
            tooltip: "Countries and owners from a local database"
            onClicked: page.openGeoSetup()
        }
        Text {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: "Ctrl+1–8 tabs · / search · ↑↓ rows · Menu actions · Esc"
            color: page.theme.dim
            font.family: page.theme.fontFamily
            font.pixelSize: 10
        }
    }

    // ── Row actions ──────────────────────────────────────────────────────────
    component ActionSeparator: Controls.MenuSeparator {
        padding: 4
        height: visible ? implicitHeight : 0
        contentItem: Rectangle {
            implicitHeight: 1
            color: page.theme.line2
        }
    }
    component ActionItem: Controls.MenuItem {
        id: mi
        implicitHeight: 30
        height: visible ? implicitHeight : 0
        padding: 4
        contentItem: Text {
            text: mi.text
            color: !mi.enabled ? page.theme.dim : mi.text.indexOf("End") === 0 ? page.theme.danger : page.theme.text
            font.family: page.theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8
        }
        background: Rectangle {
            radius: 6
            color: mi.highlighted ? page.theme.hover : "transparent"
        }
    }
    Controls.Menu {
        id: actions
        property var app: null
        property var conn: null
        // { proto, port, name } of a listening socket.
        property var listen: null
        // The app's live connections, whichever page opened the menu.
        readonly property var liveConns: {
            const a = app ? page.allApps.find(x => x.key === app.key) : null;
            return a ? a.conns.filter(c => !c.ended) : [];
        }
        property int pid: 0
        property string procName: ""
        readonly property var info: conn ? page.hostOf(conn) : null
        padding: 4
        background: Rectangle {
            implicitWidth: 260
            radius: 10
            color: page.theme.popup
            border.color: page.theme.line2
        }
        ActionItem {
            text: "Copy IP  " + (actions.conn ? actions.conn.ip : "")
            enabled: !!actions.conn
            onTriggered: page.copy(actions.conn.ip)
        }
        ActionItem {
            text: "Copy domain  " + (actions.info && actions.info.host ? actions.info.host : "")
            enabled: !!actions.info && actions.info.host !== ""
            onTriggered: page.copy(actions.info.host)
        }
        ActionItem {
            text: "Copy address:port"
            enabled: !!actions.conn
            onTriggered: page.copy((actions.conn.ip.indexOf(":") >= 0 ? "[" + actions.conn.ip + "]" : actions.conn.ip) + ":" + actions.conn.port)
        }
        ActionSeparator {}
        ActionItem {
            text: "Whois / owner (bgp.he.net) ↗"
            enabled: !!actions.conn && actions.conn.kind === "internet"
            onTriggered: Qt.openUrlExternally(NetModel.whoisUrl(actions.conn.ip))
        }
        ActionItem {
            text: "Show on a map (ipinfo.io) ↗"
            enabled: !!actions.conn && actions.conn.kind === "internet"
            onTriggered: Qt.openUrlExternally(NetModel.mapUrl(actions.conn.ip))
        }
        ActionItem {
            text: "Latency and route…"
            enabled: !!actions.conn && actions.conn.kind !== "loopback"
            onTriggered: {
                routePopup.conn = actions.conn;
                routePopup.open();
            }
        }
        ActionSeparator {
            visible: net.captureTools.wireshark
        }
        ActionItem {
            text: "Wireshark: this connection ↗"
            visible: net.captureTools.wireshark && !!actions.conn
            enabled: !!actions.conn && !actions.conn.ended && Wireshark.connFilter(actions.conn) !== ""
            onTriggered: page.wireshark(Wireshark.ifaceOf(actions.conn), Wireshark.connFilter(actions.conn), actions.conn.app.name + " → " + actions.conn.ip + ":" + actions.conn.port)
        }
        ActionItem {
            text: "Wireshark: " + (actions.app ? actions.app.name : "") + "'s " + actions.liveConns.length + " connections ↗"
            visible: net.captureTools.wireshark && !!actions.app && !actions.listen
            enabled: actions.liveConns.length > 0
            onTriggered: page.wireshark(Wireshark.commonIface(actions.liveConns), Wireshark.connectionsFilter(actions.liveConns), actions.app.name)
        }
        ActionItem {
            text: actions.listen ? "Wireshark: port " + actions.listen.port + "/" + actions.listen.proto + " ↗" : ""
            visible: net.captureTools.wireshark && !!actions.listen
            onTriggered: page.wireshark("any", Wireshark.portFilter(actions.listen.proto, actions.listen.port), actions.listen.name || "port " + actions.listen.port)
        }
        ActionSeparator {}
        ActionItem {
            text: actions.app && page.service.trusted[actions.app.key] ? "Stop trusting " + actions.app.name : "Trust " + (actions.app ? actions.app.name : "this app")
            enabled: !!actions.app && actions.app.key !== "?"
            onTriggered: page.service.trust(actions.app, !page.service.trusted[actions.app.key])
        }
        ActionItem {
            text: "Daily limit…" + (actions.app && page.service.limits[actions.app.key] ? "  (" + Format.bytes(page.service.limits[actions.app.key].bytes) + ")" : "")
            enabled: !!actions.app && actions.app.key !== "?"
            onTriggered: {
                limitPopup.app = actions.app;
                limitPopup.open();
            }
        }
        ActionSeparator {}
        ActionItem {
            text: actions.pid > 1 ? "End " + actions.procName + " (PID " + actions.pid + ")…" : "End process (unknown PID)"
            enabled: actions.pid > 1
            onTriggered: page.askKill(actions.pid, actions.procName)
        }
    }

    GeoSetup {
        id: geoSetup
        page: page
    }
    AlertsPopup {
        id: alertsPopup
        page: page
    }
    NetSettings {
        id: settingsPopup
        page: page
    }
    LimitPopup {
        id: limitPopup
        page: page
    }
    RoutePopup {
        id: routePopup
        page: page
    }
    CapturePopup {
        id: capturePopup
        page: page
    }
    Controls.Menu {
        id: exportMenu
        padding: 4
        background: Rectangle {
            implicitWidth: 260
            radius: 10
            color: page.theme.popup
            border.color: page.theme.line2
        }
        ActionItem {
            text: "Connections as CSV (" + page.filtered.length + ", as filtered)"
            onTriggered: page.exportFile("connections")
        }
        ActionItem {
            text: "History as CSV (per day and app)"
            onTriggered: page.exportFile("historyCsv")
        }
        ActionItem {
            text: "History as JSON (everything)"
            onTriggered: page.exportFile("historyJson")
        }
    }
    // The optional password, over everything.
    LockScreen {
        anchors.fill: parent
        z: 100
        page: page
        visible: page.service.locked && !page.unlocked
        onUnlocked: page.unlocked = true
    }
    function openGeoSetup() {
        geoSetup.open();
    }

    NetDialog {
        id: confirm
        page: page
        property int pid: 0
        property string procName: ""
        width: 380
        onOpened: cancelButton.forceActiveFocus()
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "End " + confirm.procName + "?"
                color: page.theme.text
                font.family: page.theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Sends SIGTERM to PID " + confirm.pid + ". The program closes and unsaved work in it may be lost. Only your own processes can be ended."
                color: page.theme.muted
                font.family: page.theme.fontFamily
                font.pixelSize: 11
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                NetButton {
                    id: cancelButton
                    theme: page.theme
                    text: "Cancel"
                    onClicked: confirm.close()
                }
                NetButton {
                    theme: page.theme
                    primary: true
                    danger: true
                    text: "End process"
                    onClicked: {
                        net.killProcess(confirm.pid);
                        confirm.close();
                    }
                }
            }
        }
    }

    Rectangle {
        id: toast
        function show(text) {
            toastText.text = text;
            opacity = 1;
            toastTimer.restart();
        }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: footer.top
        anchors.bottomMargin: 14
        width: toastText.implicitWidth + 28
        height: 32
        radius: 16
        color: page.theme.popup
        border.color: page.theme.line2
        opacity: 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
        Text {
            id: toastText
            anchors.centerIn: parent
            color: page.theme.text
            font.family: page.theme.fontFamily
            font.pixelSize: 11
        }
        Timer {
            id: toastTimer
            interval: 2200
            onTriggered: toast.opacity = 0
        }
    }
}
