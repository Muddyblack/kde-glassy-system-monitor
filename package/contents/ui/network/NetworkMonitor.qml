import QtQuick
import "../Probes.js" as Probes
import "../DemoData.js" as DemoData
import "../OsFetch.js" as OsFetch
import "NetModel.js" as NetModel
import "BrowserTabs.mjs" as BrowserTabs
import "Wireshark.js" as Wireshark
import ".." as Ui

// Everything the network window shows, read without root: `ss` for sockets,
// /proc for the process tree and traffic, .desktop files for app names and
// icons, getent (and a local GeoIP database, if any) for names and places,
// resolvectl for DNS, the browsers' session files for open tabs.
//
// Two speeds: `background` (window closed) polls slowly and only what the
// traffic history needs; otherwise everything, every `interval`. Each poll
// emits `polled(sample)` for NetHistory.
Item {
    id: net

    property Component commandSourceComponent: null
    property bool running: false
    property bool paused: false
    property bool background: false
    // Demo data through the same parsers: the preview, the website shots.
    property bool demo: false
    property int interval: 2000
    property int backgroundInterval: 15000
    readonly property int pollInterval: background ? backgroundInterval : interval
    // Match browser connections to open tabs (BrowserTabs.mjs).
    property bool tabsEnabled: true

    signal polled(var sample)

    // The session, see NetModel.track().
    property var session: null
    readonly property var connections: session ? session.list : []
    property var listening: []
    property var tree: ({})
    property var desktopIndex: ({})
    property var hosts: ({})
    // { country, asn } once the first lookup reported the local databases.
    property var geo: ({
            country: false,
            asn: false
        })
    // Some sockets belong to other users' processes, which ss cannot name.
    readonly property bool limited: connections.some(c => !c.pid && !c.ended) || listening.some(l => !l.pid)
    property var interfaces: []
    property var ifaceDetails: ({})
    property var ifaceRates: ({})
    property var dns: ({
            resolved: false,
            stats: {},
            global: [],
            links: {}
        })
    property real rateIn: 0
    property real rateOut: 0
    property var historyIn: []
    property var historyOut: []
    property int historySize: 90
    // Live rate series for sparklines: key → { in: [], out: [] }.
    property var appSeries: ({})
    property var ifaceSeries: ({})
    property int seriesSize: 45
    // Browser tabs: [{ host, title, browser }], their addresses, and the
    // address → tabs index NetModel.describe() reads.
    property var tabs: []
    property var tabAddresses: ({})
    property var sites: ({})
    property string tabsError: ""
    // Docker / Podman (Probes.parseContainers); stats only while the
    // Containers page is shown, they cost a second of daemon time.
    property var containers: ({})
    property bool containersShown: false
    property var containerRates: ({})
    property var containerSeries: ({})
    // Connection key → its last RTTs in ms (TCP, while the window is open).
    property var rttSeries: ({})
    // VPN tunnels (Probes.vpnInfo) and the firewall (Probes.parseFirewall).
    readonly property var vpns: Probes.vpnInfo(interfaces, ifaceDetails, tree, connections)
    property var firewall: null
    property bool firewallShown: false
    // Wireshark / tshark on this machine (Wireshark.parseTools).
    property var captureTools: ({
            wireshark: false,
            tshark: false,
            flatpak: false
        })
    // Address → { name, source } learned from a tshark capture; these
    // names win over reverse DNS for the rest of the session.
    property var learned: ({})
    property var _containerBytes: null
    property real _containerBytesAt: 0
    property real updatedAt: 0

    property var _dev: null
    property real _devTime: 0
    property var _pending: ({})
    property int _demoStep: 0
    property var _sessionFiles: ({})
    property real _forwardAt: 0

    function reset() {
        session = null;
        listening = [];
        _pending = {};
        _dev = null;
        historyIn = [];
        historyOut = [];
        appSeries = {};
        ifaceSeries = {};
        rateIn = 0;
        rateOut = 0;
    }
    // Leaving the window: drop what only the window shows, keep polling.
    function clearEnded() {
        if (session) {
            const list = session.list.filter(c => !c.ended);
            const entries = {};
            for (const c of list)
                entries[c.key] = c;
            session = {
                time: session.time,
                entries: entries,
                list: list
            };
        }
        appSeries = {};
        ifaceSeries = {};
    }
    function refresh() {
        if (demo)
            demoTick();
        else
            connProbe.poll();
    }

    function pushSeries(map, key, a, b) {
        const s = map[key] || {
            "in": [],
            out: []
        };
        return {
            "in": s["in"].concat([a]).slice(-seriesSize),
            out: s.out.concat([b]).slice(-seriesSize)
        };
    }

    // ── Polls ────────────────────────────────────────────────────────────────
    // The process table is read only when a socket's process is unknown or
    // the table is a minute old: most polls skip the hundreds of /proc
    // files. App identities are cached until the table or the .desktop
    // index changes.
    // Local address → interface: which link (or tunnel) a connection uses.
    readonly property var _addresses: Probes.addressIndex(interfaces, ifaceDetails)
    property bool _needTree: true
    property real _treeAt: 0
    property var _appCache: ({})
    onDesktopIndexChanged: _appCache = {}
    function appOf(pid, name) {
        const key = pid + "|" + name;
        return _appCache[key] || (_appCache[key] = Probes.appFor(pid, name, tree, desktopIndex));
    }

    function applyPoll(text, now) {
        const parts = Probes.sections(text);
        const sockets = Probes.parseSockets(parts[""]);
        if (parts.proc !== undefined) {
            tree = Probes.parseProcTree(parts.proc);
            _treeAt = now;
            _appCache = {};
        }
        _needTree = now - _treeAt > 60000 || sockets.some(s => s.pid && !tree[s.pid]);
        const ctx = {
            tree: tree,
            index: desktopIndex,
            appOf: appOf,
            ifaceOf: ip => _addresses[ip] || "",
            ports: Probes.listenPorts(sockets),
            maxEnded: background ? 0 : undefined
        };
        session = NetModel.track(session, Probes.parseConnections(parts[""]), now, ctx);
        listening = Probes.parseListening(parts[""]);
        const dev = Probes.parseNetDev(parts.dev);
        const dt = _dev ? (now - _devTime) / 1000 : 0;
        const totals = NetModel.totalRates(_dev, dev, dt, interfaces);
        _dev = dev;
        _devTime = now;
        if (dt > 0) {
            ifaceRates = totals.perIface;
            rateIn = totals.rx;
            rateOut = totals.tx;
            historyIn = historyIn.concat([rateIn]).slice(-historySize);
            historyOut = historyOut.concat([rateOut]).slice(-historySize);
            if (!background) {
                const apps = {};
                for (const a of NetModel.apps(connections))
                    if (a.active)
                        apps[a.key] = pushSeries(appSeries, a.key, a.rateIn, a.rateOut);
                appSeries = apps;
                const ifs = {};
                for (const name in totals.perIface)
                    ifs[name] = pushSeries(ifaceSeries, name, totals.perIface[name].rx, totals.perIface[name].tx);
                ifaceSeries = ifs;
                const rtts = {};
                for (const c of connections)
                    if (!c.ended && c.rtt !== null && c.rtt !== undefined)
                        rtts[c.key] = (rttSeries[c.key] || []).concat([c.rtt]).slice(-seriesSize);
                rttSeries = rtts;
            }
        }
        updatedAt = now;
        polled(NetModel.historySample(connections, now, dt > 0 ? totals : {
            inBytes: 0,
            outBytes: 0
        }, hosts, sites));
        resolveNew();
    }

    // Look these up too (trace route hops).
    property var _extraIps: []
    function resolveIps(ips) {
        _extraIps = _extraIps.concat(ips.filter(ip => !hosts[ip] && Probes.safeIp(ip)));
        resolveNew();
    }
    // Names for addresses not seen yet, a batch at a time; the UI never waits.
    function resolveNew() {
        if (demo)
            return;
        // A widget that runs for weeks must not collect every address it met.
        if (Object.keys(hosts).length > 3000)
            hosts = {};
        const fresh = [];
        const known = ip => hosts[ip] && !hosts[ip].lookup;
        for (const ip of _extraIps)
            if (fresh.length < 24 && !known(ip) && !_pending[ip] && fresh.indexOf(ip) === -1)
                fresh.push(ip);
        for (const c of connections) {
            if (fresh.length >= 24)
                break;
            if (known(c.ip) || _pending[c.ip] || fresh.indexOf(c.ip) !== -1)
                continue;
            if (c.kind === "loopback" || c.kind === "multicast" || !Probes.safeIp(c.ip))
                continue;
            fresh.push(c.ip);
        }
        if (!fresh.length || resolver.connectedSources.length)
            return;
        _extraIps = _extraIps.filter(ip => fresh.indexOf(ip) === -1);
        const pending = Object.assign({}, _pending);
        fresh.forEach(ip => pending[ip] = true);
        _pending = pending;
        resolver.connectSource(OsFetch.shellCmd(Probes.resolveCmd(fresh)));
    }

    // Open tabs → their addresses, looked up again every five minutes.
    function updateTabs(list) {
        tabs = list;
        const hosts = [];
        for (const t of list)
            if (hosts.indexOf(t.host) === -1 && BrowserTabs.safeHost(t.host))
                hosts.push(t.host);
        const stale = Date.now() - _forwardAt > 300000;
        const missing = hosts.filter(h => !tabAddresses[h]);
        const ask = (stale ? hosts : missing).slice(0, 40);
        if (ask.length && !forward.connectedSources.length) {
            if (stale)
                _forwardAt = Date.now();
            forward.connectSource(OsFetch.shellCmd(BrowserTabs.forwardCmd(ask)));
        }
        sites = BrowserTabs.siteIndex(tabs, tabAddresses);
    }

    function demoTick() {
        const i = ++_demoStep;
        if (Object.keys(desktopIndex).length === 0) {
            desktopIndex = Probes.appIndex(Probes.parseDesktopEntries(DemoData.NET_DESKTOP));
            interfaces = Probes.parseInterfaces(DemoData.NET_INTERFACES);
            ifaceDetails = Probes.parseIfaceDetails(DemoData.NET_IFACE_DETAILS);
            dns = Probes.parseDns(DemoData.NET_DNS);
            hosts = DemoData.NET_HOSTS;
            geo = {
                country: true,
                asn: true
            };
            containers = Probes.parseContainers(DemoData.NET_CONTAINERS);
            captureTools = Wireshark.parseTools("wireshark\ntshark");
            firewall = Probes.parseFirewall(DemoData.NET_FIREWALL);
            tabs = DemoData.NET_TABS;
            tabAddresses = DemoData.NET_TAB_ADDRESSES;
            sites = BrowserTabs.siteIndex(tabs, tabAddresses);
        }
        applyPoll(DemoData.netPoll(i), i * 1000 + 1.7e12);
        applyContainerStats(Probes.parseContainerStats(DemoData.netContainerStats(i)), i * 1000 + 1.7e12);
    }
    // A demo session that already has history, ended connections and rates.
    function prefillDemo(steps) {
        for (let k = 0; k < steps; k++)
            demoTick();
    }

    // End a process (the only action that changes anything; confirmed first).
    signal killFinished(int pid, bool ok, string message)
    function killProcess(pid) {
        if (!(pid > 1))
            return;
        if (demo) {
            killFinished(pid, true, "");
            return;
        }
        killSource.connectSource("kill -TERM " + Math.round(pid));
    }

    // Wireshark on an interface with a capture filter; it runs on its own.
    function openWireshark(iface, filter) {
        if (demo || !captureTools.wireshark)
            return false;
        launcher.connectSource(OsFetch.shellCmd(Wireshark.launchCmd(captureTools, iface, filter)));
        return true;
    }
    // Addresses not looked up yet keep `lookup` so resolveNew() still
    // fetches their country and owner.
    function learnNames(names) {
        learned = Object.assign(Object.keys(learned).length > 3000 ? {} : Object.assign({}, learned), names);
        const h = Object.assign({}, hosts);
        for (const ip in names)
            h[ip] = h[ip] ? Object.assign({}, h[ip], {
                name: names[ip].name
            }) : {
                name: names[ip].name,
                country: "",
                asn: 0,
                org: "",
                lookup: true
            };
        hosts = h;
        resolveNew();
    }

    Ui.ShellProbe {
        id: connProbe
        sourceComponent: net.commandSourceComponent
        command: net._needTree || net.demo ? Probes.CONNECTIONS_CMD : Probes.CONNECTIONS_LIGHT_CMD
        interval: net.pollInterval
        running: net.running && !net.paused && !net.demo
        onResult: text => net.applyPoll(text, Date.now())
    }
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Probes.DESKTOP_CMD
        interval: 300000
        running: net.running && !net.demo
        onResult: text => net.desktopIndex = Probes.appIndex(Probes.parseDesktopEntries(text))
    }
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Probes.INTERFACES_CMD + "; echo @@details; " + Probes.IFACE_DETAILS_CMD
        interval: net.background ? 60000 : net.interval * 3
        running: net.running && !net.paused && !net.demo
        onResult: text => {
            const at = text.indexOf("@@details\n");
            net.interfaces = Probes.parseInterfaces(at < 0 ? text : text.slice(0, at));
            net.ifaceDetails = Probes.parseIfaceDetails(at < 0 ? "" : text.slice(at + 10));
        }
    }
    // Counters once; when they come back empty (no resolved, or polkit said
    // no) only the servers are read from then on.
    property bool _dnsStats: true
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: net._dnsStats ? Probes.DNS_CMD : Probes.DNS_SERVERS_CMD
        interval: 30000
        running: net.running && !net.paused && !net.demo && !net.background
        onResult: text => {
            const dns = Probes.parseDns(text);
            if (net._dnsStats && !dns.resolved)
                net._dnsStats = false;
            net.dns = net._dnsStats || !net.dns.resolved ? dns : Object.assign({}, dns, {
                resolved: true,
                stats: net.dns.stats
            });
        }
    }
    // Browser tabs: session files that changed since the last read go to
    // the worker; unchanged ones keep their tabs.
    Ui.ShellProbe {
        id: tabsProbe
        sourceComponent: net.commandSourceComponent
        // Chromium files (mtime 0) are always read again: only Firefox's
        // decoded sessions are worth skipping.
        command: BrowserTabs.tabsCmd(Object.keys(net._sessionFiles).filter(k => !/:0$/.test(k)))
        interval: 30000
        running: net.running && !net.paused && !net.demo && !net.background && net.tabsEnabled
        onResult: text => {
            const sessions = BrowserTabs.parseTabsOutput(text);
            const keep = {}, changed = [];
            for (const s of sessions) {
                const key = s.path + ":" + s.mtime;
                if (s.body === "same" && net._sessionFiles[key])
                    keep[key] = net._sessionFiles[key];
                else if (s.body !== "same")
                    changed.push(s);
            }
            net._sessionFiles = keep;
            if (changed.length)
                tabsWorker.sendMessage({
                    sessions: changed
                });
            else
                net.updateTabs([].concat(...Object.values(keep)));
        }
    }
    WorkerScript {
        id: tabsWorker
        source: "TabsWorker.mjs"
        onMessage: message => {
            const files = Object.assign({}, net._sessionFiles);
            let error = "";
            for (const r of message.results) {
                files[r.key] = r.tabs;
                error = error || r.error;
            }
            net._sessionFiles = files;
            net.tabsError = error;
            net.updateTabs([].concat(...Object.values(files)));
        }
    }
    Ui.CommandSource {
        id: forward
        sourceComponent: net.commandSourceComponent
        onNewData: function (sourceName, data) {
            forward.disconnectSource(sourceName);
            net.tabAddresses = Object.assign({}, net.tabAddresses, BrowserTabs.parseForward(data["stdout"] || ""));
            net.sites = BrowserTabs.siteIndex(net.tabs, net.tabAddresses);
        }
    }
    // The firewall, only while the Listening page shows it.
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Probes.FIREWALL_CMD
        interval: 60000
        running: net.running && !net.paused && !net.demo && !net.background && net.firewallShown
        onResult: text => net.firewall = Probes.parseFirewall(text)
    }
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Wireshark.TOOLS_CMD
        interval: 300000
        running: net.running && !net.demo && !net.background
        onResult: text => net.captureTools = Wireshark.parseTools(text)
    }
    Ui.CommandSource {
        id: launcher
        sourceComponent: net.commandSourceComponent
        onNewData: sourceName => launcher.disconnectSource(sourceName)
    }
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Probes.CONTAINERS_CMD
        interval: 10000
        running: net.running && !net.paused && !net.demo && !net.background
        onResult: text => net.containers = Probes.parseContainers(text)
    }
    Ui.ShellProbe {
        sourceComponent: net.commandSourceComponent
        command: Probes.CONTAINER_STATS_CMD
        interval: 5000
        running: net.running && !net.paused && !net.demo && !net.background && net.containersShown && Object.keys(net.containers).length > 0
        onResult: text => net.applyContainerStats(Probes.parseContainerStats(text), Date.now())
    }
    function applyContainerStats(bytes, now) {
        const dt = _containerBytes ? (now - _containerBytesAt) / 1000 : 0;
        const rates = {}, series = {};
        for (const key in bytes) {
            const before = _containerBytes && _containerBytes[key];
            const r = {
                rx: before && dt > 0 && bytes[key].rx >= before.rx ? (bytes[key].rx - before.rx) / dt : 0,
                tx: before && dt > 0 && bytes[key].tx >= before.tx ? (bytes[key].tx - before.tx) / dt : 0,
                totalRx: bytes[key].rx,
                totalTx: bytes[key].tx
            };
            rates[key] = r;
            series[key] = pushSeries(containerSeries, key, r.rx, r.tx);
        }
        _containerBytes = bytes;
        _containerBytesAt = now;
        containerRates = rates;
        containerSeries = series;
    }
    onTabsEnabledChanged: if (!tabsEnabled) {
        tabs = [];
        sites = {};
        _sessionFiles = {};
    }
    Ui.CommandSource {
        id: resolver
        sourceComponent: net.commandSourceComponent
        onNewData: function (sourceName, data) {
            resolver.disconnectSource(sourceName);
            const r = Probes.parseResolve(data["stdout"] || "");
            if (r.geo)
                net.geo = r.geo;
            const next = Object.assign({}, net.hosts);
            const pending = Object.assign({}, net._pending);
            for (const ip in r.hosts) {
                next[ip] = net.learned[ip] ? Object.assign({}, r.hosts[ip], {
                    name: net.learned[ip].name
                }) : r.hosts[ip];
                delete pending[ip];
            }
            // Addresses that timed out get an empty entry, not another try.
            for (const ip in pending)
                if (sourceName.indexOf("q " + ip + " ") !== -1) {
                    next[ip] = {
                        name: net.learned[ip] ? net.learned[ip].name : "",
                        country: "",
                        asn: 0,
                        org: ""
                    };
                    delete pending[ip];
                }
            net.hosts = next;
            net._pending = pending;
            net.resolveNew();
        }
    }
    Ui.CommandSource {
        id: killSource
        sourceComponent: net.commandSourceComponent
        onNewData: function (sourceName, data) {
            killSource.disconnectSource(sourceName);
            const pid = Number(sourceName.split(" ").pop());
            const err = String(data["stderr"] || "").trim();
            net.killFinished(pid, err === "" && Number(data["exit code"] || 0) === 0, err);
            net.refresh();
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: net.running && !net.paused && net.demo
        onTriggered: net.demoTick()
    }
}
