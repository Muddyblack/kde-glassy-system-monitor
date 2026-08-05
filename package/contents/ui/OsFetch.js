.pragma library

// Shared "fetch tool" plumbing, used by both main.qml (to populate the OS Info
// section) and configGeneral.qml (to preview and let the user pick/reorder
// fields). Kept here so the candidate list and the parser can never drift apart
// between the widget and its settings page.

// Candidates in priority order, each already forced to plain, logo-less,
// colourless output. First one that EXISTS and produces "Key: Value" output
// wins — validating the output means a wrong flag on some future version
// demotes that tool instead of rendering garbage.
var CANDIDATES = ["fastfetch --logo none --pipe true", "neofetch --stdout", "screenfetch -nN", "macchina --no-ascii --no-box", "hyfetch --backend neofetch --args --stdout"];

// The "executable" engine does NOT run its source through a shell — it splits
// the string into argv and execs directly. Any command using pipes, redirection,
// `;`, `||`, `$(...)`, globs or loops must therefore be handed to an explicit
// shell, or the metacharacters arrive as literal arguments. Single quotes in the
// payload are escaped the POSIX way ('\'').
function shellCmd(cmd) {
    return "sh -c '" + cmd.replace(/'/g, "'\\''") + "'";
}

// Builds the detection+run probe. A custom command is tried first but still has
// to pass the same existence + output check, so a stale entry falls back to
// auto-detection instead of blanking the section.
function probeCmd(customCmd) {
    var custom = (customCmd || "").trim();
    var list = custom ? [custom].concat(CANDIDATES) : CANDIDATES;
    // Logo first: the tool loop exits early on a match, so anything emitted
    // after it would be unreachable whenever detection succeeds.
    var sh = "printf '__LOGO__%s\\n' \"$(. /etc/os-release 2>/dev/null; echo \"${LOGO:-$ID}\")\"; ";
    for (var i = 0; i < list.length; i++) {
        var c = list[i];
        var bin = c.split(" ")[0];
        sh += "if command -v " + bin + " >/dev/null 2>&1; then " + "o=$(" + c + " 2>/dev/null); " + "case \"$o\" in *:*) printf '__TOOL__%s\\n%s\\n' " + bin + " \"$o\"; exit 0;; esac; " + "fi; ";
    }
    return shellCmd(sh);
}

// Fetch tools colour their output even when told not to, and some emit
// cursor-positioning sequences. Strip CSI/OSC escapes and CRs defensively so
// the text never reaches the UI with control codes in it.
function stripAnsi(s) {
    return s.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "").replace(/\x1b\[[0-9;?]*[ -\/]*[@-~]/g, "").replace(/\x1b[@-Z\\-_]/g, "").replace(/\r/g, "");
}

// -> {tool, logo, title, rows:[{lbl,val}], raw}
// A result with fewer than two rows is treated as "no tool", so a binary that
// exists but prints something unexpected never wins detection.
function parse(out) {
    var text = stripAnsi(out || "");
    var lines = text.split("\n");
    var rows = [];
    var tool = "";
    var title = "";
    var logo = "";
    var body = [];

    for (var i = 0; i < lines.length; i++) {
        var ln = lines[i];
        if (ln.indexOf("__TOOL__") === 0) {
            tool = ln.slice(8).trim();
            continue;
        }
        if (ln.indexOf("__LOGO__") === 0) {
            logo = ln.slice(8).trim();
            continue;
        }
        body.push(ln);
    }

    for (var j = 0; j < body.length; j++) {
        var b = body[j].trim();
        if (!b)
            continue;
        // Separator rules ("-----", "=====") carry no information.
        if (/^[-=_~*]{3,}$/.test(b))
            continue;
        var ci = b.indexOf(":");
        if (ci <= 0) {
            // First colon-less line is the "user@host" banner most tools print.
            if (!title)
                title = b;
            continue;
        }
        var lbl = b.slice(0, ci).trim();
        var val = b.slice(ci + 1).trim();
        if (!lbl || !val)
            continue;
        rows.push({
            lbl: lbl,
            val: val
        });
    }

    var ok = rows.length >= 2;
    return {
        tool: ok ? tool : "",
        logo: logo,
        title: title,
        rows: ok ? rows : [],
        raw: ok ? body.join("\n").trim() : ""
    };
}

// ── Field rules ───────────────────────────────────────────────────────────────
// A rule list is an ordered array of keys; a leading "!" means hidden. Keys the
// user has never seen are NOT in the list and default to visible, appended in
// the tool's own order — so a tool upgrade that adds a field shows it rather
// than silently swallowing it.

function ruleKey(rule) {
    return rule.charAt(0) === "!" ? rule.slice(1) : rule;
}

function ruleEnabled(rule) {
    return rule.charAt(0) !== "!";
}

function makeRule(key, enabled) {
    return enabled ? key : "!" + key;
}

// Applies saved rules to freshly parsed rows: known keys first in the user's
// order, then any unknown keys in tool order. Duplicate keys (fastfetch emits
// one "Display (…)" per monitor) stay grouped and keep their relative order.
function applyRules(rows, rules) {
    if (!rules || rules.length === 0)
        return rows;

    var hidden = {};
    var rank = {};
    for (var i = 0; i < rules.length; i++) {
        var k = ruleKey(rules[i]);
        rank[k] = i;
        if (!ruleEnabled(rules[i]))
            hidden[k] = true;
    }

    var known = [];
    var unknown = [];
    for (var j = 0; j < rows.length; j++) {
        var r = rows[j];
        if (hidden[r.lbl])
            continue;
        if (rank[r.lbl] !== undefined)
            known.push({
                row: r,
                rank: rank[r.lbl],
                seq: j
            });
        else
            unknown.push(r);
    }
    known.sort(function (a, b) {
        return a.rank !== b.rank ? a.rank - b.rank : a.seq - b.seq;
    });

    var out = [];
    for (var m = 0; m < known.length; m++)
        out.push(known[m].row);
    for (var n = 0; n < unknown.length; n++)
        out.push(unknown[n]);
    return out;
}

// Merges saved rules with a fresh probe for the settings list: every key the
// user has ever configured stays listed (so an exclusion is not lost just
// because a tool stopped reporting that field this run), flagged with whether
// it is currently reported and a sample value.
// -> [{key, enabled, present, sample}]
function mergeRules(rows, rules) {
    var sample = {};
    var order = [];
    for (var i = 0; i < rows.length; i++) {
        if (sample[rows[i].lbl] === undefined) {
            sample[rows[i].lbl] = rows[i].val;
            order.push(rows[i].lbl);
        }
    }

    var out = [];
    var seen = {};
    for (var j = 0; j < (rules || []).length; j++) {
        var k = ruleKey(rules[j]);
        if (seen[k])
            continue;
        seen[k] = true;
        out.push({
            key: k,
            enabled: ruleEnabled(rules[j]),
            present: sample[k] !== undefined,
            sample: sample[k] !== undefined ? sample[k] : ""
        });
    }
    for (var m = 0; m < order.length; m++) {
        if (seen[order[m]])
            continue;
        out.push({
            key: order[m],
            enabled: true,
            present: true,
            sample: sample[order[m]]
        });
    }
    return out;
}
