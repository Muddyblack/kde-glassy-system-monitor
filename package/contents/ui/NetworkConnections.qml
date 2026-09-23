import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import "OsFetch.js" as OsFetch

// Active connections of this machine with reverse DNS and, when available,
// GeoIP flags. Opened from the network section; runs `ss` only on refresh.
QQC2.Popup {
    id: connDialog

    required property var monitor
    required property var cfg
    // The item the popup opens next to.
    property Item anchorItem: null
    property var connections: []
    property bool loading: false

    width: 340
    height: Math.min(connList.contentHeight + headerRow.implicitHeight + divider.height + 36, 420)
    padding: 10
    modal: false
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    // position relative to the info icon, opening above or below depending on panel edge
    x: {
        if (!anchorItem || !parent)
            return 0;
        const gp = anchorItem.mapToItem(parent, 0, 0);
        return Math.max(0, Math.min(gp.x + anchorItem.width / 2 - width / 2, parent.width - width));
    }
    y: {
        if (!anchorItem || !parent)
            return 0;
        const gp = anchorItem.mapToItem(parent, 0, 0);
        const screenMid = parent.mapToGlobal(0, parent.height / 2).y;
        const screenH = Qt.application.screens[0] ? Qt.application.screens[0].height : 1080;
        return screenMid < screenH / 2 ? gp.y + anchorItem.height + 4   // panel at top → open downward
        : gp.y - height - 4;                // panel at bottom → open upward
    }

    background: Rectangle {
        color: Qt.rgba(connDialog.monitor.textColor.r * 0.05 + 0.05, connDialog.monitor.textColor.g * 0.05 + 0.05, connDialog.monitor.textColor.b * 0.05 + 0.05, 0.96)
        radius: 6
        border.color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.15)
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 6

        // header
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 6

            Text {
                font.family: connDialog.monitor.fontFamily
                text: "Active Connections"
                color: connDialog.monitor.textColor
                font.pixelSize: 12
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                font.family: connDialog.monitor.fontFamily
                visible: connDialog.connections.length > 0
                text: connDialog.connections.length + ""
                color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.45)
                font.pixelSize: 10
            }
            QQC2.ToolButton {
                text: "↻"
                implicitWidth: 22
                implicitHeight: 22
                onClicked: connDialog.refresh()
            }
            QQC2.ToolButton {
                text: "✕"
                implicitWidth: 22
                implicitHeight: 22
                onClicked: connDialog.close()
            }
        }

        Rectangle {
            id: divider
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.12)
        }

        Text {
            font.family: connDialog.monitor.fontFamily
            visible: connDialog.loading && connDialog.connections.length === 0
            Layout.fillWidth: true
            text: "Fetching connectionsâ¦"
            color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.5)
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            font.family: connDialog.monitor.fontFamily
            visible: !connDialog.loading && connDialog.connections.length === 0
            Layout.fillWidth: true
            text: "No external connections"
            color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.4)
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: connList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: connDialog.connections

            delegate: Rectangle {
                width: connList.width
                height: connRow.implicitHeight + 8
                color: connRowMouse.containsMouse ? Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.06) : "transparent"
                radius: 3

                RowLayout {
                    id: connRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: 7

                    // Application icon by process name, where the theme has one.
                    Image {
                        source: "image://icon/" + modelData.procName
                        sourceSize: Qt.size(36, 36)
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        visible: status === Image.Ready
                    }

                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true

                        RowLayout {
                            spacing: 4
                            Text {
                                font.family: connDialog.monitor.fontFamily
                                text: modelData.procName
                                color: connDialog.monitor.textColor
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.maximumWidth: 110
                            }
                            Rectangle {
                                visible: modelData.proto !== ""
                                implicitHeight: 14
                                implicitWidth: protoLabel.implicitWidth + 6
                                radius: 3
                                color: modelData.proto === "tcp" ? Qt.rgba(0.2, 0.6, 1.0, 0.25) : Qt.rgba(0.4, 0.8, 0.4, 0.25)
                                Text {
                                    id: protoLabel
                                    font.family: connDialog.monitor.fontFamily
                                    anchors.centerIn: parent
                                    text: modelData.proto.toUpperCase()
                                    color: modelData.proto === "tcp" ? Qt.rgba(0.4, 0.8, 1.0, 0.9) : Qt.rgba(0.5, 1.0, 0.5, 0.9)
                                    font.pixelSize: 8
                                    font.bold: true
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                font.family: connDialog.monitor.fontFamily
                                text: ":" + modelData.port
                                color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.45)
                                font.pixelSize: 10
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                font.family: connDialog.monitor.fontFamily
                                visible: modelData.flag !== ""
                                text: modelData.flag
                                font.pixelSize: 11
                            }
                            Text {
                                font.family: connDialog.monitor.fontFamily
                                text: modelData.hostname !== "" ? modelData.hostname : modelData.remoteHost
                                color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.6)
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                font.family: connDialog.monitor.fontFamily
                                visible: modelData.hostname !== "" && modelData.remoteHost !== modelData.hostname
                                text: modelData.remoteHost
                                color: Qt.rgba(connDialog.monitor.textColor.r, connDialog.monitor.textColor.g, connDialog.monitor.textColor.b, 0.3)
                                font.pixelSize: 8
                                elide: Text.ElideLeft
                                Layout.maximumWidth: 90
                            }
                        }
                    }
                }

                MouseArea {
                    id: connRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }

    function refresh() {
        connDialog.loading = true;
        connDialog.connections = [];
        ssSource.connectSource(OsFetch.shellCmd("ss -tunp 2>/dev/null | awk 'NR>1{remote=$6;proc=\"\";for(i=7;i<=NF;i++)proc=proc\" \"$i;match(proc,/\"([^\"]+)\"/,m);if(m[1]!=\"\")print $1\"|\"remote\"|\"m[1]}'"));
    }

    // Coarse, offline country guess derived from the reverse-DNS hostname.
    // NOT a GeoIP database â just TLDs and common airport/city codes that
    // many CDNs embed in PTR records. Returns {flag, code} or empty.
    // Intentionally conservative: unknown â no flag rather than a wrong one.
    function geoFromHost(host) {
        if (!host)
            return {
                flag: "",
                code: ""
            };
        const h = host.toLowerCase();
        // 1) ccTLD on the end (.de, .co.uk â uk, etc.)
        const tldMap = {
            de: "DE",
            fr: "FR",
            uk: "GB",
            nl: "NL",
            us: "US",
            ca: "CA",
            jp: "JP",
            cn: "CN",
            au: "AU",
            br: "BR",
            in: "IN",
            ru: "RU",
            se: "SE",
            no: "NO",
            fi: "FI",
            dk: "DK",
            pl: "PL",
            es: "ES",
            it: "IT",
            ch: "CH",
            at: "AT",
            be: "BE",
            ie: "IE",
            sg: "SG",
            kr: "KR",
            hk: "HK",
            tw: "TW",
            za: "ZA",
            mx: "MX"
        };
        const tldM = h.match(/\.([a-z]{2})$/);
        if (tldM && tldMap[tldM[1]])
            return {
                flag: _flag(tldMap[tldM[1]]),
                code: tldMap[tldM[1]]
            };
        // 2) airport/city codes commonly embedded by CDNs
        const cityMap = {
            fra: "DE",
            muc: "DE",
            ber: "DE",
            dus: "DE",
            ham: "DE",
            ams: "NL",
            lhr: "GB",
            lon: "GB",
            man: "GB",
            cdg: "FR",
            par: "FR",
            mrs: "FR",
            iad: "US",
            sjc: "US",
            lax: "US",
            ord: "US",
            dfw: "US",
            atl: "US",
            sea: "US",
            nyc: "US",
            mia: "US",
            den: "US",
            yyz: "CA",
            yvr: "CA",
            nrt: "JP",
            hnd: "JP",
            kix: "JP",
            sin: "SG",
            hkg: "HK",
            syd: "AU",
            gru: "BR",
            icn: "KR",
            arn: "SE",
            waw: "PL",
            mad: "ES",
            mxp: "IT",
            zrh: "CH",
            vie: "AT",
            bru: "BE",
            dub: "IE",
            hel: "FI",
            cph: "DK"
        };
        const m = h.match(/(^|[.\-])([a-z]{3})[0-9]*([.\-])/g);
        if (m) {
            for (let i = 0; i < m.length; i++) {
                const code = m[i].replace(/[^a-z]/g, "").slice(0, 3);
                if (cityMap[code])
                    return {
                        flag: _flag(cityMap[code]),
                        code: cityMap[code]
                    };
            }
        }
        return {
            flag: "",
            code: ""
        };
    }

    // Batched per-IP resolve in ONE subprocess. For every unique remote IP
    // it emits "ip<TAB>hostname<TAB>countrycode" (any field may be empty):
    //   â¢ hostname  â reverse DNS via getent (always)
    //   â¢ countrycode â MaxMind GeoIP via mmdblookup, only when accurateGeo
    //     is on AND a readable .mmdb + mmdblookup are present. Otherwise the
    //     field is blank and QML falls back to the hostname heuristic.
    // The DB is auto-detected (newest Portmaster geoip file, IPv4/IPv6),
    // never hardcoded â absent Portmaster just means no DB and graceful
    // fallback. Runs once per popup refresh: one extra process, no daemon.
    function resolveHosts(conns) {
        const ips = {};
        for (let i = 0; i < conns.length; i++) {
            const ip = conns[i].remoteHost;
            if (ip && /[0-9a-fA-F:.]/.test(ip) && !ips[ip])
                ips[ip] = true;
        }
        const list = Object.keys(ips);
        if (list.length === 0)
            return;
        const useGeo = connDialog.cfg.accurateGeo;

        // Shell preamble: locate newest readable Portmaster v4/v6 DBs and
        // confirm mmdblookup exists. DB4/DB6/MM stay empty if unavailable.
        const preamble = useGeo ? "GD=/var/lib/portmaster/updates/all/intel/geoip; " + "DB4=$(ls -1t \"$GD\"/geoipv4_*.mmdb 2>/dev/null | head -1); " + "DB6=$(ls -1t \"$GD\"/geoipv6_*.mmdb 2>/dev/null | head -1); " + "MM=$(command -v mmdblookup 2>/dev/null); " : "MM=''; DB4=''; DB6=''; ";

        // Per-IP: reverse DNS, then (if MM+DB present and IP readable) a
        // country lookup choosing v6 DB for colon-bearing addresses.
        const perIp = list.map(function (ip) {
            const safe = ip.replace(/'/g, "");
            return "ip='" + safe + "'; " + "h=$(timeout 1 getent hosts \"$ip\" 2>/dev/null | awk '{print $2; exit}'); " + "cc=''; " + "if [ -n \"$MM\" ]; then " + "case \"$ip\" in *:*) DB=\"$DB6\";; *) DB=\"$DB4\";; esac; " + "if [ -n \"$DB\" ] && [ -r \"$DB\" ]; then " + "cc=$(timeout 1 \"$MM\" --file \"$DB\" --ip \"$ip\" country iso_code 2>/dev/null | grep -o '\"[A-Za-z][A-Za-z]\"' | head -1 | tr -d '\"');" + "fi; fi; " + "printf '%s\\t%s\\t%s\\n' \"$ip\" \"$h\" \"$cc\"";
        }).join("; ");

        resolveSource.connectSource(OsFetch.shellCmd(preamble + perIp));
    }

    // ISO-3166 alpha-2 â emoji flag via regional indicator symbols.
    function _flag(cc) {
        if (!cc || cc.length !== 2)
            return "";
        const base = 0x1F1E6;
        return String.fromCodePoint(base + cc.charCodeAt(0) - 65) + String.fromCodePoint(base + cc.charCodeAt(1) - 65);
    }

    CommandSource {
        id: ssSource
        sourceComponent: connDialog.monitor.commandSourceComponent
        onNewData: function (sourceName, data) {
            ssSource.disconnectSource(sourceName);
            connDialog.loading = false;
            const out = (data["stdout"] || "").trim();
            if (out === "") {
                connDialog.connections = [];
                return;
            }

            const lines = out.split("\n");
            const seen = {};
            const result = [];

            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].split("|");
                if (parts.length < 3)
                    continue;
                const proto = parts[0].trim().toLowerCase().replace(/[0-9]/g, "");  // tcp/udp
                const remote = parts[1].trim();
                let procName = parts[2].trim();

                // filter loopback
                if (remote.startsWith("127.") || remote.startsWith("[::1]") || remote === "")
                    continue;

                // clean up process names
                if (procName === ".zen-wrapped")
                    procName = "zen";
                procName = procName.replace(/^\./, "");

                // split host:port â handle IPv6 [::]:port
                let remoteHost = remote, port = "";
                const ipv6m = remote.match(/^\[(.+)\]:(\d+)$/);
                const ipv4m = remote.match(/^([^:]+):(\d+)$/);
                if (ipv6m) {
                    remoteHost = ipv6m[1];
                    port = ipv6m[2];
                } else if (ipv4m) {
                    remoteHost = ipv4m[1];
                    port = ipv4m[2];
                }

                // deduplicate by proc+host
                const key = procName + "|" + remoteHost;
                if (seen[key])
                    continue;
                seen[key] = true;

                result.push({
                    procName: procName,
                    remoteHost: remoteHost,
                    port: port,
                    proto: proto,
                    hostname: "",
                    flag: "",
                    countryCode: ""
                });
            }

            // sort by procName
            result.sort(function (a, b) {
                return a.procName < b.procName ? -1 : a.procName > b.procName ? 1 : 0;
            });
            // Show rows now; hostname/flag fill in asynchronously after one
            // batched reverse-DNS lookup (single subprocess for all unique IPs).
            connDialog.connections = result;
            connDialog.resolveHosts(result);
        }
    }

    // One batched resolve for every unique remote IP. Each line is
    // "ip<TAB>hostname<TAB>countrycode" (hostname/cc may be empty). Runs only
    // on popup refresh â one extra subprocess per open, no polling, no daemon.
    CommandSource {
        id: resolveSource
        sourceComponent: connDialog.monitor.commandSourceComponent
        onNewData: function (sourceName, data) {
            resolveSource.disconnectSource(sourceName);
            const out = (data["stdout"] || "").trim();
            if (out === "")
                return;
            // Build ip â {hostname, cc} map.
            const map = {};
            const lines = out.split("\n");
            for (let i = 0; i < lines.length; i++) {
                const f = lines[i].split("\t");
                if (f.length < 1 || f[0] === "")
                    continue;
                map[f[0]] = {
                    hostname: (f[1] || "").trim(),
                    cc: (f[2] || "").trim().toUpperCase()
                };
            }
            // Merge into the existing rows without rebuilding from scratch.
            const conns = connDialog.connections.slice();
            let changed = false;
            for (let j = 0; j < conns.length; j++) {
                const e = map[conns[j].remoteHost];
                if (!e)
                    continue;
                const hn = (e.hostname && e.hostname !== conns[j].remoteHost) ? e.hostname : "";
                // Prefer the GeoIP country code; fall back to the hostname
                // heuristic only when the DB gave us nothing.
                let flag = "", code = "";
                if (e.cc && /^[A-Z]{2}$/.test(e.cc)) {
                    code = e.cc;
                    flag = connDialog._flag(e.cc);
                } else if (hn) {
                    const geo = connDialog.geoFromHost(hn);
                    flag = geo.flag;
                    code = geo.code;
                }
                if (!hn && !flag)
                    continue;
                conns[j] = Object.assign({}, conns[j], {
                    hostname: hn,
                    flag: flag,
                    countryCode: code
                });
                changed = true;
            }
            if (changed)
                connDialog.connections = conns;
        }
    }
}
