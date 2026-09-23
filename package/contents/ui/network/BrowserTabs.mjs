
// Which site a browser connection belongs to, without an extension or root:
// read the open tabs from the browser's own session file (Firefox and its
// forks: sessionstore-backups/recovery.jsonlz4; Chromium and its forks: the
// newest Sessions/Session_* file), resolve each tab's host with getent, and
// match the browser's connections by remote address. Best effort: shared CDN
// addresses give several candidates, and a page's third-party requests match
// nothing. Only host names and titles are kept, only in memory.

export var GECKO_ROOTS = ["$HOME/.mozilla/firefox", "$HOME/.zen", "$HOME/.librewolf", "$HOME/.floorp", "$HOME/.waterfox",
    "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox", "$HOME/.var/app/io.gitlab.librewolf-community/.librewolf", "$HOME/.var/app/app.zen_browser.zen/.zen"];
export var CHROMIUM_ROOTS = ["$HOME/.config/google-chrome", "$HOME/.config/chromium", "$HOME/.config/BraveSoftware/Brave-Browser", "$HOME/.config/vivaldi",
    "$HOME/.config/microsoft-edge", "$HOME/.var/app/com.google.Chrome/config/google-chrome", "$HOME/.var/app/org.chromium.Chromium/config/chromium",
    "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"];

export var BROWSER_RE = /firefox|zen|librewolf|floorp|waterfox|isolated web|socket process|chrom|brave|vivaldi|msedge|edge|opera/i;

export function isBrowser(conn) {
    return BROWSER_RE.test(conn.app.name) || BROWSER_RE.test(conn.proc || "");
}

// `known` is "path:mtime" of session files already read: those print
// "same" instead of their contents. Only recently written sessions count
// (a browser that is running saves every few seconds).
export function tabsCmd(known) {
    var safe = (known || []).filter(function (k) { return /^[\w\/.\- ]+:\d+$/.test(k); }).join("|");
    return "K='|" + safe + "|'; find " + GECKO_ROOTS.map(function (r) { return "\"" + r + "\""; }).join(" ")
        + " -maxdepth 4 -path '*sessionstore-backups/recovery.jsonlz4' -mmin -30 2>/dev/null | while IFS= read -r f; do "
        + "m=$(stat -c %Y \"$f\"); echo \"@@gecko $m $f\"; case \"$K\" in *\"|$f:$m|\"*) echo same;; *) base64 -w0 \"$f\"; echo;; esac; done; "
        + "for d in " + CHROMIUM_ROOTS.map(function (r) { return "\"" + r + "\""; }).join(" ") + "; do for p in \"$d\"/*/Sessions; do "
        + "s=$(ls -1t \"$p\"/Session_* 2>/dev/null | head -1); [ -n \"$s\" ] && [ -n \"$(find \"$s\" -mmin -60 2>/dev/null)\" ] && { echo \"@@chromium 0 $s\"; "
        + "grep -a -o -E 'https?://[A-Za-z0-9.-]+' \"$s\" | sort | uniq -c | sort -rn | head -40; }; done; done";
}

// → [{ kind: "gecko" | "chromium", mtime, path, body }]
export function parseTabsOutput(text) {
    var out = [], cur = null;
    String(text || "").split("\n").forEach(function (line) {
        var m = /^@@(gecko|chromium) (\d+) (.+)$/.exec(line);
        if (m) {
            cur = { kind: m[1], mtime: Number(m[2]), path: m[3], body: [] };
            out.push(cur);
        } else if (cur && line !== "") {
            cur.body.push(line);
        }
    });
    out.forEach(function (s) { s.body = s.body.join("\n"); });
    return out;
}

// ── mozlz4 ───────────────────────────────────────────────────────────────────
export var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

export function base64Bytes(text) {
    var s = String(text || "").replace(/[^A-Za-z0-9+\/]/g, "");
    var map = {};
    for (var k = 0; k < 64; k++)
        map[B64.charAt(k)] = k;
    var out = new Uint8Array(Math.floor(s.length * 3 / 4));
    var o = 0;
    for (var i = 0; i + 1 < s.length; i += 4) {
        var a = map[s.charAt(i)], b = map[s.charAt(i + 1)], c = map[s.charAt(i + 2)], d = map[s.charAt(i + 3)];
        out[o++] = (a << 2) | (b >> 4);
        if (c !== undefined && i + 2 < s.length)
            out[o++] = ((b & 15) << 4) | (c >> 2);
        if (d !== undefined && i + 3 < s.length)
            out[o++] = ((c & 3) << 6) | d;
    }
    return out.subarray(0, o);
}

// One LZ4 block (no frame), as Firefox writes it after its 12-byte header.
export function lz4Block(src, start, size) {
    var out = new Uint8Array(size);
    var i = start, o = 0, b;
    while (i < src.length) {
        var token = src[i++];
        var lit = token >> 4;
        if (lit === 15)
            do {
                b = src[i++];
                lit += b;
            } while (b === 255);
        if (o + lit > size)
            throw new Error("lz4: output overrun");
        for (var k = 0; k < lit; k++)
            out[o++] = src[i++];
        if (i >= src.length)
            break;
        var offset = src[i] | (src[i + 1] << 8);
        i += 2;
        var len = token & 15;
        if (len === 15)
            do {
                b = src[i++];
                len += b;
            } while (b === 255);
        len += 4;
        var from = o - offset;
        if (offset === 0 || from < 0 || o + len > size)
            throw new Error("lz4: bad match");
        for (var n = 0; n < len; n++)
            out[o++] = out[from++];
    }
    return out.subarray(0, o);
}

export function utf8(bytes) {
    var parts = [], chunk = [];
    for (var i = 0; i < bytes.length;) {
        var c = bytes[i++];
        if (c >= 0xf0) {
            var cp = ((c & 7) << 18) | ((bytes[i++] & 63) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63);
            cp -= 0x10000;
            chunk.push(0xd800 + (cp >> 10), 0xdc00 + (cp & 1023));
        } else if (c >= 0xe0) {
            chunk.push(((c & 15) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63));
        } else if (c >= 0xc0) {
            chunk.push(((c & 31) << 6) | (bytes[i++] & 63));
        } else {
            chunk.push(c);
        }
        if (chunk.length >= 8192) {
            parts.push(String.fromCharCode.apply(null, chunk));
            chunk = [];
        }
    }
    parts.push(String.fromCharCode.apply(null, chunk));
    return parts.join("");
}

// "mozLz40\0", little-endian size, LZ4 block → the JSON text.
export function mozlz4(bytes) {
    var magic = "mozLz40";
    for (var i = 0; i < 7; i++)
        if (bytes[i] !== magic.charCodeAt(i))
            throw new Error("not a mozlz4 file");
    var size = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24) >>> 0;
    return utf8(lz4Block(bytes, 12, size));
}

export function hostOf(url) {
    var m = /^https?:\/\/(?:[^@\/]*@)?(\[[^\]]+\]|[^:\/?#]+)/i.exec(String(url || ""));
    return m ? m[1].toLowerCase() : "";
}

// Firefox's session JSON → the current page of every open tab.
export function geckoTabs(json, browser) {
    var session = typeof json === "string" ? JSON.parse(json) : json;
    var tabs = [];
    (session.windows || []).forEach(function (w) {
        (w.tabs || []).forEach(function (t) {
            var entries = t.entries || [];
            var e = entries[Math.max(0, Math.min(entries.length, t.index || entries.length) - 1)];
            var host = e ? hostOf(e.url) : "";
            if (host)
                tabs.push({ host: host, title: e.title || host, browser: browser });
        });
    });
    return tabs;
}

// Chromium: "  12 https://example.com" lines (hosts in the session file).
export function chromiumTabs(body, browser) {
    return String(body || "").split("\n").map(function (line) {
        var m = /^\s*\d+\s+(https?:\/\/\S+)/.exec(line);
        return m ? { host: hostOf(m[1]), title: "", browser: browser } : null;
    }).filter(function (t) { return t && t.host; });
}

export function browserName(path) {
    var names = [["zen", "Zen"], ["librewolf", "LibreWolf"], ["floorp", "Floorp"], ["waterfox", "Waterfox"], ["firefox", "Firefox"],
        ["brave", "Brave"], ["vivaldi", "Vivaldi"], ["edge", "Edge"], ["google-chrome", "Chrome"], ["chromium", "Chromium"]];
    var p = String(path || "").toLowerCase();
    for (var i = 0; i < names.length; i++)
        if (p.indexOf(names[i][0]) !== -1)
            return names[i][1];
    return "Browser";
}

// Plain host names only reach the shell.
export function safeHost(h) {
    return /^[A-Za-z0-9.-]{1,253}$/.test(String(h || "")) && /[A-Za-z]/.test(h);
}

// Forward lookups for tab hosts, in parallel, one second each:
// "addr<TAB>host<TAB>ip" lines.
export function forwardCmd(hosts) {
    return "f() { timeout 1 getent ahosts \"$1\" 2>/dev/null | awk -v h=\"$1\" '{print \"addr\\t\" h \"\\t\" $1}' | sort -u; }; "
        + (hosts || []).filter(safeHost).map(function (h) { return "f " + h + " &"; }).join(" ") + " wait";
}

// → { host: [ips] }
export function parseForward(text) {
    var out = {};
    String(text || "").split("\n").forEach(function (line) {
        var f = line.split("\t");
        if (f[0] === "addr" && f[1] && f[2]) {
            var list = out[f[1]] || (out[f[1]] = []);
            if (list.indexOf(f[2]) === -1)
                list.push(f[2]);
        }
    });
    return out;
}

// ip → [{ host, title, browser }] from the tabs and their addresses.
export function siteIndex(tabs, addresses) {
    var index = {};
    (tabs || []).forEach(function (t) {
        (addresses[t.host] || []).forEach(function (ip) {
            var list = index[ip] || (index[ip] = []);
            if (!list.some(function (x) { return x.host === t.host; }))
                list.push(t);
        });
    });
    return index;
}
