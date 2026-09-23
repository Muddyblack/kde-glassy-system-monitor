import QtQuick
import "../OsFetch.js" as OsFetch
import ".." as Ui

// JSON files in ${XDG_DATA_HOME:-~/.local/share}/glassy-system-monitor/:
// outside the plasmoid package (replaced by updates) and outside the applet
// config (reset by layout rebuilds), so they survive reboots, plasmashell
// restarts, `plasma-layout-rebuild` and updates.
//
// Writes are safe: the text goes to name.json.tmp in base64 chunks, its size
// is checked, the old file becomes name.json.bak, and only then does the new
// one move into place (a rename, atomic). The first write of a day also
// keeps name.json.YYYY-MM-DD (the last three). Reads fall back to the .bak
// when the main file is missing or damaged.
Item {
    id: store

    property Component commandSourceComponent: null
    // Nothing touches the disk (demo data, tests).
    property bool enabled: true
    readonly property string dirExpr: "${XDG_DATA_HOME:-$HOME/.local/share}/glassy-system-monitor"
    // name → { value, error, fromBackup } once read.
    signal loaded(string name, var value, string error, bool fromBackup)
    signal saved(string name, bool ok)

    property var _queue: []
    property bool _busy: false

    function load(name) {
        if (!enabled) {
            loaded(name, null, "", false);
            return;
        }
        _push({
            kind: "load",
            name: name,
            cmd: "D=\"" + dirExpr + "\"; f=\"$D/" + name + ".json\"; echo \"@@path $f\"; echo @@main; cat \"$f\" 2>/dev/null; echo; echo @@bak; cat \"$f.bak\" 2>/dev/null; echo"
        });
    }

    // Every month file (network-YYYY-MM.json, or its .bak when the main one
    // is damaged) → loaded("months", { "2026-09": value }, error, fromBackup).
    function loadMonths() {
        if (!enabled) {
            loaded("months", {}, "", false);
            return;
        }
        _push({
            kind: "months",
            name: "months",
            cmd: "D=\"" + dirExpr + "\"; for f in \"$D\"/network-[0-9][0-9][0-9][0-9]-[0-9][0-9].json; do [ -e \"$f\" ] || continue; " + "b=${f##*/}; echo \"@@file ${b%.json}\"; cat \"$f\"; echo; echo @@bak; cat \"$f.bak\" 2>/dev/null; echo; done"
        });
    }
    // Deletes files (and their backups) for good: names like "network-2025-08".
    function remove(names) {
        const safe = names.filter(n => /^network-[\w-]+$/.test(n));
        if (!enabled || !safe.length)
            return;
        _push({
            kind: "remove",
            name: "remove",
            cmd: "D=\"" + dirExpr + "\"; " + safe.map(n => "rm -f \"$D/" + n + ".json\" \"$D/" + n + ".json\".*").join("; ") + "; echo done"
        });
    }
    // Writes an export into the Downloads folder (or home) and reports its
    // path through exported(path).
    signal exported(string path, bool ok)
    function exportText(fileName, text) {
        if (!enabled || !/^[\w.-]+$/.test(fileName))
            return;
        const b64 = base64Utf8(text);
        const steps = ["D=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$D\" ] || D=\"$HOME\"; : > \"$D/" + fileName + ".part\""];
        for (let i = 0; i < b64.length; i += 60000)
            steps.push("D=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$D\" ] || D=\"$HOME\"; printf %s " + b64.slice(i, i + 60000) + " | base64 -d >> \"$D/" + fileName + ".part\"");
        steps.push("D=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$D\" ] || D=\"$HOME\"; mv -f \"$D/" + fileName + ".part\" \"$D/" + fileName + "\" && echo \"exported $D/" + fileName + "\"");
        _push({
            kind: "export",
            name: fileName,
            steps: steps,
            step: 0
        });
    }
    // UTF-8 bytes in base64 (Qt.btoa's encoding of non-Latin text is not
    // specified), so exports keep every character.
    function base64Utf8(text) {
        const A = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        const bytes = [];
        for (let i = 0; i < text.length; i++) {
            let c = text.charCodeAt(i);
            if (c >= 0xd800 && c < 0xdc00 && i + 1 < text.length) {
                c = 0x10000 + ((c - 0xd800) << 10) + (text.charCodeAt(++i) - 0xdc00);
            }
            if (c < 0x80)
                bytes.push(c);
            else if (c < 0x800)
                bytes.push(0xc0 | c >> 6, 0x80 | c & 63);
            else if (c < 0x10000)
                bytes.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
            else
                bytes.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        }
        const out = [];
        for (let i = 0; i < bytes.length; i += 3) {
            const n = bytes[i] << 16 | (bytes[i + 1] || 0) << 8 | (bytes[i + 2] || 0);
            out.push(A[n >> 18 & 63], A[n >> 12 & 63], i + 1 < bytes.length ? A[n >> 6 & 63] : "=", i + 2 < bytes.length ? A[n & 63] : "=");
        }
        return out.join("");
    }

    // Saves `value` as JSON. Replaces a save of the same file that has not
    // started yet.
    function save(name, value) {
        if (!enabled)
            return;
        // ASCII only (\uXXXX escapes), so the byte count check is exact.
        const text = JSON.stringify(value).replace(/[\u007f-\uffff]/g, ch => "\\u" + ("000" + ch.charCodeAt(0).toString(16)).slice(-4));
        const b64 = base64Utf8(text);
        // umask 077: the directory and every file are private to the user
        // (the history lists the domains you visit).
        const steps = ["umask 077; D=\"" + dirExpr + "\"; mkdir -p \"$D\" && chmod 700 \"$D\" && : > \"$D/" + name + ".json.tmp\""];
        for (let i = 0; i < b64.length; i += 60000)
            steps.push("umask 077; D=\"" + dirExpr + "\"; printf %s " + b64.slice(i, i + 60000) + " | base64 -d >> \"$D/" + name + ".json.tmp\"");
        steps.push("umask 077; D=\"" + dirExpr + "\"; f=\"$D/" + name + ".json\"; t=\"$f.tmp\"; day=$(date +%F); " + "if [ \"$(wc -c < \"$t\")\" -eq " + text.length + " ]; then " +
        // Only a complete old file (it ends with "}") becomes the backup.
        "if [ -s \"$f\" ] && [ \"$(tail -c 1 \"$f\")\" = \"}\" ]; then cp -f \"$f\" \"$f.bak\"; [ -e \"$f.$day\" ] || cp -f \"$f\" \"$f.$day\"; " + "ls -1 \"$f\".20* 2>/dev/null | sort -r | tail -n +4 | while IFS= read -r o; do rm -f \"$o\"; done; fi; " + "mv -f \"$t\" \"$f\" && chmod 600 \"$f\" \"$f\".* 2>/dev/null; echo saved; else rm -f \"$t\"; echo short; fi");
        // Small files (today's) go in one shell run.
        if (b64.length < 90000)
            steps.splice(0, steps.length, steps.join("; "));
        _queue = _queue.filter(job => !(job.kind === "save" && job.name === name && !job.started));
        _push({
            kind: "save",
            name: name,
            steps: steps,
            step: 0
        });
    }

    // Moves a damaged file aside (name.json.broken-<time>) so a fresh one can start.
    function setAside(name) {
        if (!enabled)
            return;
        _push({
            kind: "aside",
            name: name,
            cmd: "D=\"" + dirExpr + "\"; f=\"$D/" + name + ".json\"; [ -e \"$f\" ] && mv -f \"$f\" \"$f.broken-$(date +%Y%m%d-%H%M%S)\"; rm -f \"$f.bak\"; echo done"
        });
    }

    function _push(job) {
        _queue = _queue.concat([job]);
        _next();
    }
    function _next() {
        if (_busy || !_queue.length)
            return;
        // Asked during start-up, before the host's command source exists.
        if (!source.item) {
            retry.start();
            return;
        }
        const job = _queue[0];
        job.started = true;
        _busy = true;
        watchdog.restart();
        source.connectSource(OsFetch.shellCmd(job.steps ? job.steps[job.step] : job.cmd));
    }
    function _done(stdout) {
        const job = _queue[0];
        _busy = false;
        watchdog.stop();
        if (job.steps && job.step < job.steps.length - 1) {
            job.step++;
            _next();
            return;
        }
        _queue = _queue.slice(1);
        if (job.kind === "load")
            _parseLoad(job.name, stdout);
        else if (job.kind === "months")
            _parseMonths(stdout);
        else if (job.kind === "export") {
            const m = /exported (.*)/.exec(stdout);
            exported(m ? m[1].trim() : job.name, !!m);
        } else if (job.kind === "save")
            saved(job.name, stdout.indexOf("saved") !== -1);
        _next();
    }
    function _parseMonths(text) {
        const out = {};
        let error = "", fromBackup = false;
        const files = text.split(/^@@file /m).slice(1);
        for (const chunk of files) {
            const nl = chunk.indexOf("\n"), name = chunk.slice(0, nl).trim(), rest = chunk.slice(nl + 1);
            const bak = rest.lastIndexOf("@@bak\n");
            const parts = [rest.slice(0, bak).trim(), rest.slice(bak + 6).trim()];
            let ok = false;
            for (let i = 0; i < 2 && !ok; i++) {
                if (!parts[i])
                    continue;
                try {
                    out[name.replace(/^network-/, "")] = JSON.parse(parts[i]);
                    ok = true;
                    fromBackup = fromBackup || i === 1;
                } catch (e) {}
            }
            if (!ok)
                error = error || "cannot read " + name + ".json";
        }
        loaded("months", out, error, fromBackup);
    }
    function _parseLoad(name, text) {
        const main = text.indexOf("@@main\n"), bak = text.lastIndexOf("@@bak\n");
        const parts = [text.slice(main + 7, bak).trim(), text.slice(bak + 6).trim()];
        let error = "";
        for (let i = 0; i < 2; i++) {
            if (!parts[i])
                continue;
            try {
                loaded(name, JSON.parse(parts[i]), "", i === 1);
                return;
            } catch (e) {
                error = error || String(e);
            }
        }
        loaded(name, null, error ? "cannot read " + name + ".json: " + error : "", false);
    }

    Timer {
        id: retry
        interval: 250
        onTriggered: store._next()
    }
    // A command that never answers must not stall every later save.
    Timer {
        id: watchdog
        interval: 20000
        onTriggered: {
            source.reset();
            store._busy = false;
            const job = store._queue[0];
            store._queue = store._queue.slice(1);
            if (job && job.kind === "load")
                store.loaded(job.name, null, "timed out reading " + job.name + ".json", false);
            else if (job && job.kind === "months")
                store.loaded("months", {}, "timed out reading the month files", false);
            store._next();
        }
    }

    Ui.CommandSource {
        id: source
        sourceComponent: store.commandSourceComponent
        onNewData: function (sourceName, data) {
            source.disconnectSource(sourceName);
            store._done(String(data["stdout"] || ""));
        }
    }
}
