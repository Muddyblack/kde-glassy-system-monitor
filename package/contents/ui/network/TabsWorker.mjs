import * as BrowserTabs from "BrowserTabs.mjs";

// Decodes browser session files off the UI thread: Firefox's can be
// megabytes of compressed JSON.
WorkerScript.onMessage = function (message) {
    const results = [];
    for (const s of message.sessions) {
        const key = s.path + ":" + s.mtime;
        try {
            const browser = BrowserTabs.browserName(s.path);
            const tabs = s.kind === "gecko" ? BrowserTabs.geckoTabs(BrowserTabs.mozlz4(BrowserTabs.base64Bytes(s.body)), browser) : BrowserTabs.chromiumTabs(s.body, browser);
            results.push({ key: key, tabs: tabs, error: "" });
        } catch (e) {
            results.push({ key: key, tabs: [], error: String(e) });
        }
    }
    WorkerScript.sendMessage({ results: results });
};
