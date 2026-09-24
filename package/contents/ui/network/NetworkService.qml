import QtQuick
import "NetHistory.js" as NetHistory
import "NetModel.js" as NetModel
import "NetLock.js" as NetLock
import "../Probes.js" as Probes
import "../DemoData.js" as DemoData
import "../OsFetch.js" as OsFetch
import ".." as Ui

// One per host (Plasma widget, Quickshell shell): the NetworkMonitor, the
// window's saved state, the traffic history and the alerts, kept on disk by
// NetStore in ~/.local/share/glassy-system-monitor/ (private: 700 / 600) so
// they survive reboots, plasmashell restarts, layout rebuilds and updates.
//
// History files: network-today.json (a few KB, every five minutes and when
// the window closes) and network-YYYY-MM.json (a month; only the current
// one is rewritten, once a day). The user decides whether anything is
// recorded, whether it is saved, and for how long.
//
// Several widgets share the files: only the one holding the lease
// (network-history.lock, renewed every 20 s) polls in the background, records and alerts.
Item {
    id: service

    property Component commandSourceComponent: null
    property bool demo: false
    // The host shows the network window.
    property bool windowOpen: false
    // A panel pill shows the network apps: poll every 5 s in the background.
    property bool pillActive: false

    // Saved settings and window state (network-window.json):
    // { tab, dark, width, height, x, y,
    //   record: "on" (also while the window is closed) | "window" | "off",
    //   keep: "session" (memory only) | "30d" | "90d" | "1y" | "2y" | "all",
    //   tabs (bool), alerts { newApp, openPort, vpnDown, limit, threat, notify },
    //   threats { lists (bool, off by default), choice { listId: bool } },
    //   trusted { appKey: name }, limits { appKey: { name, bytes } },
    //   lock { salt, iter, hash } | null }
    property var state: ({})
    property bool stateLoaded: false
    readonly property string recordMode: state.record || (state.history === false ? "off" : "on")
    readonly property string keep: state.keep || NetHistory.DEFAULT_RETENTION
    readonly property bool historyEnabled: recordMode !== "off" && (recordMode === "on" || windowOpen)
    readonly property bool persist: keep !== "session"
    readonly property bool tabsEnabled: state.tabs !== false
    readonly property var alertSettings: Object.assign({
        newApp: true,
        // Off by default: every service that listens would raise one.
        openPort: false,
        vpnDown: true,
        limit: true,
        threat: true,
        notify: true
    }, state.alerts || {})
    readonly property var trusted: state.trusted || ({})
    readonly property var limits: state.limits || ({})
    readonly property bool locked: !!(state.lock && state.lock.hash)

    property var history: NetHistory.empty()
    property bool historyLoaded: false
    // False when a file is damaged or newer: it is never overwritten then.
    property bool historyWritable: false
    property string historyError: ""
    property bool historyFromBackup: false
    property bool recording: false
    property int historyRevision: 0
    property var firstSeen: ({})
    property bool _dirty: false
    property var _dirtyMonths: ({})
    property string _today: ""
    property var _parts: ({})
    readonly property string instanceId: Math.random().toString(36).slice(2, 10)

    // Alerts: the newest first, for the window's bell.
    property var alertLog: []
    property int unreadAlerts: 0
    property var _seenApps: null
    property var _seenPorts: null
    property var _vpnUp: ({})
    property var _limitHit: ({})
    property real _notifiedAt: 0
    property var _seenThreats: null

    readonly property alias monitor: net
    readonly property alias store: store
    readonly property alias threats: threatWatch

    ThreatWatch {
        id: threatWatch
        service: service
    }

    // The "netapps" pill reading (MonitorCore.netApps), only when a pill shows it.
    readonly property var pillApps: {
        if (!pillActive)
            return null;
        const apps = NetModel.apps(net.connections.filter(c => !c.ended));
        return {
            top: apps.length ? {
                name: apps[0].name,
                rateIn: apps[0].rateIn,
                rateOut: apps[0].rateOut
            } : null,
            count: apps.length,
            history: net.historyIn
        };
    }

    function saveState(next) {
        state = Object.assign({}, state, next);
        if (stateLoaded && !demo)
            store.save("network-window", state);
    }
    function setLock(password) {
        saveState({
            lock: password ? NetLock.create(password) : null
        });
    }
    function checkLock(password) {
        return NetLock.check(state.lock, password);
    }
    function trust(app, on) {
        const next = Object.assign({}, trusted);
        if (on)
            next[app.key] = app.name;
        else
            delete next[app.key];
        saveState({
            trusted: next
        });
    }
    function setLimit(app, bytes) {
        const next = Object.assign({}, limits);
        if (bytes > 0)
            next[app.key] = {
                name: app.name,
                bytes: bytes
            };
        else
            delete next[app.key];
        const hit = Object.assign({}, _limitHit);
        delete hit[app.key];
        _limitHit = hit;
        saveState({
            limits: next
        });
    }
    function appToday(key) {
        historyRevision;
        return NetHistory.appToday(history, Date.now(), key);
    }

    // ── Saving ───────────────────────────────────────────────────────────────
    function flush() {
        if (!_dirty || !recording || !historyWritable || demo || !persist)
            return;
        const now = Date.now();
        const pruned = NetHistory.prune(history, now, keep);
        const dirty = Object.assign({}, _dirtyMonths, pruned.changed);
        const files = NetHistory.split(history, now);
        for (const m in dirty)
            if (files.months[m])
                store.save("network-" + m, files.months[m]);
        const gone = Object.keys(pruned.removed).map(m => "network-" + m);
        if (gone.length)
            store.remove(gone);
        store.save("network-today", files.today);
        if (_legacy) {
            // The single file of earlier builds is now in month files.
            store.remove(["network-history"]);
            _legacy = false;
        }
        _dirtyMonths = {};
        _dirty = false;
    }
    property bool _legacy: false
    // Every day goes, and every history file with it.
    function clearHistory() {
        const months = {};
        for (const k in history.days)
            months["network-" + NetHistory.monthOf(k)] = true;
        store.remove(Object.keys(months).concat(["network-today", "network-history"]));
        history = NetHistory.empty();
        firstSeen = {};
        _dirtyMonths = {};
        _dirty = false;
        historyRevision++;
    }
    // Memory only from now on: what was saved is deleted.
    function stopSaving() {
        const keepHistory = history;
        clearHistory();
        history = keepHistory;
        historyRevision++;
        saveState({
            keep: "session"
        });
    }
    // A damaged history: keep it aside (…json.broken-<time>) and start anew.
    function startFresh() {
        store.setAside("network-history");
        store.setAside("network-today");
        history = NetHistory.empty();
        historyError = "";
        historyWritable = true;
        historyRevision++;
    }
    function reloadHistory() {
        if (demo)
            return;
        _parts = {};
        store.load("network-history");
        store.loadMonths();
        store.load("network-today");
    }
    function _joinParts() {
        const p = _parts;
        if (!p["network-history"] || !p.months || !p["network-today"])
            return;
        const error = p["network-history"].error || p.months.error || p["network-today"].error;
        if (error) {
            // Unreadable: leave the files alone and record nothing.
            historyError = error;
            historyWritable = false;
        } else {
            const m = NetHistory.join({
                legacy: p["network-history"].value,
                months: Object.values(p.months.value || {}),
                today: p["network-today"].value
            });
            history = m.history;
            historyWritable = m.writable;
            historyError = m.error;
            const legacy = p["network-history"].value;
            if (m.writable && legacy && legacy.days && Object.keys(legacy.days).length) {
                _legacy = true;
                const dirty = Object.assign({}, _dirtyMonths);
                for (const k in legacy.days)
                    dirty[NetHistory.monthOf(k)] = true;
                _dirtyMonths = dirty;
                _dirty = true;
            }
            // The today file holds an earlier day (nothing ran at midnight).
            const today = p["network-today"].value;
            if (today && today.day && today.day !== NetHistory.dayKey(Date.now())) {
                const dirty = Object.assign({}, _dirtyMonths);
                dirty[NetHistory.monthOf(today.day)] = true;
                _dirtyMonths = dirty;
                _dirty = true;
            }
        }
        historyFromBackup = !!(p["network-history"].fromBackup || p.months.fromBackup || p["network-today"].fromBackup);
        firstSeen = NetHistory.firstSeen(history);
        historyLoaded = true;
        historyRevision++;
    }

    NetStore {
        id: store
        commandSourceComponent: service.commandSourceComponent
        enabled: !service.demo
        onLoaded: (name, value, error, fromBackup) => {
            if (name === "network-window") {
                service.state = value && typeof value === "object" ? value : {};
                service.stateLoaded = true;
                return;
            }
            if (name !== "network-history" && name !== "network-today" && name !== "months")
                return;
            const parts = Object.assign({}, service._parts);
            parts[name] = {
                value: value,
                error: error,
                fromBackup: fromBackup
            };
            service._parts = parts;
            service._joinParts();
        }
    }

    // ── Alerts ───────────────────────────────────────────────────────────────
    function alert(kind, title, body) {
        if (!alertSettings[kind])
            return;
        alertLog = [
            {
                time: Date.now(),
                kind: kind,
                title: title,
                body: body
            }
        ].concat(alertLog).slice(0, 60);
        if (!windowOpen)
            unreadAlerts++;
        // A desktop notification, at most one every five seconds.
        if (alertSettings.notify && !demo && Date.now() - _notifiedAt > 5000) {
            _notifiedAt = Date.now();
            const q = t => "'" + String(t).replace(/[\x00-\x1f\x7f]/g, " ").slice(0, 200).replace(/'/g, "'\\''") + "'";
            notifier.connectSource(OsFetch.shellCmd("notify-send -a 'Glassy System Monitor' -i network-wired " + q(title) + " " + q(body) + " 2>/dev/null || kdialog --title " + q(title) + " --passivepopup " + q(body) + " 6 2>/dev/null"));
        }
    }
    function checkAlerts(now) {
        const active = net.connections.filter(c => !c.ended);
        const apps = NetModel.apps(active);
        const open = net.listening.filter(l => l.exposure === "network");
        // The first look after a start only learns what is there.
        if (_seenApps === null) {
            const seen = Object.assign({}, firstSeen);
            apps.forEach(a => seen[a.key] = true);
            _seenApps = seen;
            const ports = {};
            open.forEach(l => ports[l.proto + ":" + l.port + ":" + l.name] = true);
            _seenPorts = ports;
        } else {
            for (const a of apps) {
                if (_seenApps[a.key])
                    continue;
                _seenApps[a.key] = true;
                if (trusted[a.key] || a.key === "?")
                    continue;
                const c = a.conns[0];
                const d = NetModel.describe(c, net.hosts, net.sites);
                alert("newApp", "New app online: " + a.name, "First connection to " + (d.site || d.host || c.ip) + (d.country ? " (" + d.country + ")" : "") + ", port " + c.port);
            }
            for (const l of open) {
                const key = l.proto + ":" + l.port + ":" + l.name;
                if (_seenPorts[key])
                    continue;
                _seenPorts[key] = true;
                const app = Probes.appFor(l.pid, l.name, net.tree, net.desktopIndex);
                if (trusted[app.key])
                    continue;
                alert("openPort", "Port open to the network: " + l.port + "/" + l.proto, (app.key === "?" ? "A system service" : app.name) + " listens on " + (l.kind === "any" ? "all addresses" : l.ip));
            }
        }
        // VPN tunnels that were up and are gone or down now.
        const up = {};
        for (const v of net.vpns)
            if (v.up)
                up[v.iface] = v.provider;
        for (const iface in _vpnUp)
            if (!up[iface])
                alert("vpnDown", "VPN disconnected: " + _vpnUp[iface], iface + " is down; traffic now leaves directly");
        _vpnUp = up;
        // Something dangerous (Threats page), once per finding. The first
        // look after a start only learns what is there, except the serious
        // ones: those are worth hearing about again after a restart.
        const serious = threatWatch.findings.filter(f => f.level === "high" || (f.level === "medium" && f.kind !== "plain"));
        const firstLook = _seenThreats === null;
        const seenThreats = firstLook ? {} : _seenThreats;
        for (const f of serious) {
            if (seenThreats[f.key])
                continue;
            seenThreats[f.key] = true;
            if (!firstLook || f.level === "high")
                alert("threat", f.title, f.detail);
        }
        _seenThreats = seenThreats;
        // Daily limits, once a day each.
        const today = NetHistory.dayKey(now);
        for (const key in limits) {
            const used = NetHistory.appToday(history, now, key);
            if (used >= limits[key].bytes && _limitHit[key] !== today) {
                _limitHit[key] = today;
                alert("limit", "Daily limit reached: " + limits[key].name, (used / 1073741824).toFixed(2) + " GiB today, limit " + (limits[key].bytes / 1073741824).toFixed(2) + " GiB");
            }
        }
    }
    Ui.CommandSource {
        id: notifier
        sourceComponent: service.commandSourceComponent
        onNewData: sourceName => notifier.disconnectSource(sourceName)
    }

    NetworkMonitor {
        id: net
        commandSourceComponent: service.commandSourceComponent
        demo: service.demo
        tabsEnabled: service.tabsEnabled
        background: !service.windowOpen
        backgroundInterval: service.pillActive ? 5000 : 15000
        running: service.windowOpen || service.pillActive || (service.recordMode === "on" && service.recording)
        onPolled: sample => {
            // Alerts come from the widget that holds the lease (or the
            // window, when no widget records).
            if ((service.recording || service.windowOpen) && !service.demo)
                service.checkAlerts(sample.time);
            if (!service.recording || !service.historyEnabled || !service.historyWritable)
                return;
            const day = NetHistory.dayKey(sample.time);
            // A new day: yesterday's month file is written, once.
            if (service._today !== "" && service._today !== day) {
                const dirty = Object.assign({}, service._dirtyMonths);
                dirty[NetHistory.monthOf(service._today)] = true;
                service._dirtyMonths = dirty;
                service._today = day;
                NetHistory.record(service.history, sample);
                service._dirty = true;
                service.flush();
            } else {
                service._today = day;
                NetHistory.record(service.history, sample);
                service._dirty = true;
            }
            // The window's History page refreshes about every half minute.
            if (!service.windowOpen || sample.time - service._shownAt > 30000) {
                service._shownAt = sample.time;
                service.historyRevision++;
            }
        }
    }
    property real _shownAt: 0

    onWindowOpenChanged: {
        if (windowOpen) {
            unreadAlerts = 0;
            // Another widget may be the one recording: show its latest.
            if (!recording)
                reloadHistory();
        } else {
            net.clearEnded();
            flush();
        }
    }
    onKeepChanged: {
        _dirty = true;
        flush();
    }

    // Saves every five minutes: the today file is a few KB.
    Timer {
        interval: 300000
        repeat: true
        running: service.recording && service.persist
        onTriggered: service.flush()
    }
    // The lease: this instance records while its lock line is the newest
    // (or the lock is older than 50 s, its owner gone: after a plasmashell
    // restart the new one takes over within a minute).
    Timer {
        interval: 20000
        repeat: true
        triggeredOnStart: true
        running: !service.demo && service.recordMode !== "off" && service.historyLoaded && service.historyWritable
        onTriggered: lease.connectSource(OsFetch.shellCmd("umask 077; D=\"" + store.dirExpr + "\"; L=\"$D/network-history.lock\"; now=$(date +%s); mkdir -p \"$D\"; " + "if [ -f \"$L\" ]; then read id at < \"$L\"; else id=; at=0; fi; " + "if [ \"$id\" = \"" + service.instanceId + "\" ] || [ $((now - at)) -gt 50 ]; then echo \"" + service.instanceId + " $now\" > \"$L\"; echo owner; else echo busy; fi"))
    }
    onRecordModeChanged: if (recordMode === "off")
        recording = false
    Ui.CommandSource {
        id: lease
        sourceComponent: service.commandSourceComponent
        onNewData: function (sourceName, data) {
            lease.disconnectSource(sourceName);
            const owner = String(data["stdout"] || "").indexOf("owner") !== -1;
            // Taking over from another widget: start from what it saved.
            if (owner && !service.recording)
                service.reloadHistory();
            service.recording = owner && service.recordMode !== "off";
        }
    }
    Component.onCompleted: {
        if (demo) {
            net.prefillDemo(95);
            stateLoaded = true;
            history = DemoData.netHistory(Date.now());
            firstSeen = NetHistory.firstSeen(history);
            historyLoaded = true;
            historyWritable = true;
            recording = false;
            alertLog = DemoData.netAlerts(Date.now());
            historyRevision++;
            return;
        }
        store.load("network-window");
        reloadHistory();
    }
    Component.onDestruction: flush()
}
