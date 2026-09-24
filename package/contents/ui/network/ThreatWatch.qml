import QtQuick
import "Threats.js" as Threats
import "NetModel.js" as NetModel
import "../DemoData.js" as DemoData
import "../OsFetch.js" as OsFetch
import ".." as Ui

// The Threats page's data, kept by the NetworkService so its alerts also
// come with the window closed. The checks on this machine always run (one
// readlink per new process); the blocklists only when switched on in the
// page, and switching them off deletes them. Saved as state.threats =
// { lists: bool, choice: { listId: bool } }.
Item {
    id: watch

    required property var service
    readonly property var net: service.monitor
    readonly property var settings: service.state.threats || ({})
    readonly property bool listsOn: service.demo || !!settings.lists
    readonly property var ids: Threats.enabledIds(settings.choice)

    // Built from the downloaded lists: see Threats.buildIndex().
    property var index: ({})
    property bool downloading: false
    property string error: ""
    // The oldest list in use, 0 when none is there.
    readonly property real listsTime: {
        let t = 0;
        for (const id of ids)
            if (index[id])
                t = t === 0 ? index[id].time : Math.min(t, index[id].time);
        return t;
    }
    readonly property int entries: ids.reduce((a, id) => a + (index[id] ? index[id].count : 0), 0)
    // PID → the program's path, for the processes behind sockets.
    property var exes: ({})

    readonly property var findings: Threats.findings({
        conns: net.connections,
        listening: net.listening,
        exes: exes,
        index: listsOn ? _usedIndex : null,
        lookup: lookup,
        firewall: net.firewall,
        trusted: service.trusted,
        describe: c => NetModel.describe(c, net.hosts, net.sites),
        appOf: (pid, name) => net.appOf(pid, name)
    })
    readonly property var counts: Threats.counts(findings)
    readonly property var _usedIndex: {
        const out = {};
        for (const id of ids)
            if (index[id])
                out[id] = index[id];
        return out;
    }
    // Each address is looked up once per set of lists, not on every poll.
    // A plain object changed in place: filling it from inside the findings
    // binding must not notify anything.
    property var _memo: ({
            map: {},
            size: 0
        })
    on_UsedIndexChanged: _memo = {
        map: {},
        size: 0
    }
    function lookup(ip, names) {
        const key = ip + "|" + names.join("|");
        let hit = _memo.map[key];
        if (hit === undefined) {
            if (_memo.size > 5000) {
                _memo.map = {};
                _memo.size = 0;
            }
            hit = _memo.map[key] = Threats.lookup(_usedIndex, ip, names);
            _memo.size++;
        }
        return hit;
    }

    function setListsOn(on) {
        service.saveState({
            threats: Object.assign({}, settings, {
                lists: on
            })
        });
        if (service.demo)
            return;
        if (on) {
            load();
        } else {
            index = {};
            error = "";
            remover.connectSource(OsFetch.shellCmd(Threats.removeCmd(service.store.dirExpr)));
        }
    }
    function setList(id, on) {
        const choice = Object.assign({}, settings.choice || {});
        choice[id] = on;
        service.saveState({
            threats: Object.assign({}, settings, {
                choice: choice
            })
        });
        if (on && listsOn && !index[id])
            download([id]);
    }
    function load() {
        if (!service.demo && listsOn)
            loader.connectSource(OsFetch.shellCmd(Threats.loadCmd(service.store.dirExpr, Threats.LISTS.map(l => l.id))));
    }
    function download(which) {
        if (service.demo || !listsOn || downloading)
            return;
        downloading = true;
        _triedAt = Date.now();
        error = "";
        fetcher.connectSource(OsFetch.shellCmd(Threats.downloadCmd(service.store.dirExpr, which || ids)));
    }
    // Once a day while the lists are on and something watches; after a
    // failed try, not again within the hour.
    property real _triedAt: 0
    function refreshIfOld() {
        if (!listsOn || service.demo || downloading || Date.now() - _triedAt < 3600000)
            return;
        const missing = ids.filter(id => !index[id]);
        if (missing.length || Date.now() - listsTime > 86400000)
            download(missing.length && listsTime > 0 && Date.now() - listsTime < 86400000 ? missing : ids);
    }

    // New processes behind sockets: where they run from.
    function checkExes() {
        if (service.demo)
            return;
        const pids = {};
        for (const c of net.connections)
            if (c.pid && !c.ended)
                pids[c.pid] = true;
        for (const l of net.listening)
            if (l.pid)
                pids[l.pid] = true;
        const keep = {}, fresh = [];
        for (const pid in pids) {
            if (exes[pid] !== undefined)
                keep[pid] = exes[pid];
            else
                fresh.push(pid);
        }
        if (Object.keys(keep).length !== Object.keys(exes).length)
            exes = keep;
        if (fresh.length && !exeSource.connectedSources.length)
            exeSource.connectSource(OsFetch.shellCmd(Threats.exeCmd(fresh.slice(0, 200))));
    }

    Connections {
        target: watch.net
        function onPolled() {
            watch.checkExes();
        }
    }
    Connections {
        target: watch.service
        function onStateLoadedChanged() {
            watch.load();
        }
    }
    Timer {
        interval: 3600000
        repeat: true
        running: watch.listsOn && !watch.service.demo && (watch.service.windowOpen || watch.service.recording)
        onTriggered: watch.refreshIfOld()
    }

    Ui.CommandSource {
        id: exeSource
        sourceComponent: watch.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            exeSource.disconnectSource(sourceName);
            watch.exes = Object.assign({}, watch.exes, Threats.parseExe(data["stdout"] || ""));
        }
    }
    Ui.CommandSource {
        id: loader
        sourceComponent: watch.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            loader.disconnectSource(sourceName);
            if (!watch.listsOn)
                return;
            watch.index = Threats.buildIndex(Threats.parseLoad(data["stdout"] || ""));
            watch.refreshIfOld();
        }
    }
    Ui.CommandSource {
        id: fetcher
        sourceComponent: watch.service.commandSourceComponent
        onNewData: function (sourceName, data) {
            fetcher.disconnectSource(sourceName);
            watch.downloading = false;
            const r = Threats.parseDownload(data["stdout"] || "");
            watch.error = r.failed.length ? "Could not download " + r.failed.map(id => Threats.list(id).name).join(", ") + (r.ok.length ? "" : " (offline, or curl / wget missing?)") : "";
            // Switched off while it ran: what came down goes again.
            if (!watch.listsOn)
                remover.connectSource(OsFetch.shellCmd(Threats.removeCmd(watch.service.store.dirExpr)));
            else
                watch.load();
        }
    }
    Ui.CommandSource {
        id: remover
        sourceComponent: watch.service.commandSourceComponent
        onNewData: sourceName => remover.disconnectSource(sourceName)
    }

    Component.onCompleted: {
        if (service.demo) {
            index = Threats.buildIndex(Threats.parseLoad(DemoData.netThreatLists(Date.now())));
            exes = DemoData.NET_EXES;
        }
    }
}
