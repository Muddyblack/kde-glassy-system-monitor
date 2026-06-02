import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: netSection
    spacing: 3

    // ── connection info popup ────────────────────────────────────────────────
    QQC2.Popup {
        id: connDialog

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
            const gp = connInfoIcon.mapToItem(netSection, 0, 0);
            return Math.max(0, Math.min(gp.x + connInfoIcon.width / 2 - width / 2, netSection.width - width));
        }
        y: {
            const gp = connInfoIcon.mapToItem(netSection, 0, 0);
            const screenMid = netSection.mapToGlobal(0, netSection.height / 2).y;
            const screenH = Qt.application.screens[0] ? Qt.application.screens[0].height : 1080;
            return screenMid < screenH / 2 ? gp.y + connInfoIcon.height + 4   // panel at top → open downward
            : gp.y - height - 4;                // panel at bottom → open upward
        }

        background: Rectangle {
            color: Qt.rgba(root.textColor.r * 0.05 + 0.05, root.textColor.g * 0.05 + 0.05, root.textColor.b * 0.05 + 0.05, 0.96)
            radius: 6
            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15)
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 6

            // header
            RowLayout {
                id: headerRow
                Layout.fillWidth: true
                spacing: 6

                Kirigami.Icon {
                    source: "network-connect"
                    width: 16
                    height: 16
                    color: root.textColor
                }
                Text {
                    text: "Active Connections"
                    color: root.textColor
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    visible: connDialog.connections.length > 0
                    text: connDialog.connections.length + ""
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
                    font.pixelSize: 10
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: connDialog.refresh()
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "window-close"
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: connDialog.close()
                }
            }

            Rectangle {
                id: divider
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
            }

            Text {
                visible: connDialog.loading && connDialog.connections.length === 0
                Layout.fillWidth: true
                text: "Fetching connections…"
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                visible: !connDialog.loading && connDialog.connections.length === 0
                Layout.fillWidth: true
                text: "No external connections"
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.4)
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
                    color: connRowMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06) : "transparent"
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

                        Kirigami.Icon {
                            source: modelData.procName
                            fallback: "application-x-executable"
                            width: 18
                            height: 18
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 4
                                Text {
                                    text: modelData.procName
                                    color: root.textColor
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 110
                                }
                                Rectangle {
                                    visible: modelData.proto !== ""
                                    height: 14
                                    width: protoLabel.implicitWidth + 6
                                    radius: 3
                                    color: modelData.proto === "tcp" ? Qt.rgba(0.2, 0.6, 1.0, 0.25) : Qt.rgba(0.4, 0.8, 0.4, 0.25)
                                    Text {
                                        id: protoLabel
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
                                    text: ":" + modelData.port
                                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.45)
                                    font.pixelSize: 10
                                    font.family: "monospace"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    visible: modelData.flag !== ""
                                    text: modelData.flag
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: modelData.hostname !== "" ? modelData.hostname : modelData.remoteHost
                                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.6)
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: modelData.hostname !== "" && modelData.remoteHost !== modelData.hostname
                                    text: modelData.remoteHost
                                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3)
                                    font.pixelSize: 8
                                    font.family: "monospace"
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
            ssSource.connectSource("ss -tunp 2>/dev/null | awk 'NR>1{remote=$6;proc=\"\";for(i=7;i<=NF;i++)proc=proc\" \"$i;match(proc,/\"([^\"]+)\"/,m);if(m[1]!=\"\")print $1\"|\"remote\"|\"m[1]}'");
        }

        // Coarse, offline country guess derived from the reverse-DNS hostname.
        // NOT a GeoIP database — just TLDs and common airport/city codes that
        // many CDNs embed in PTR records. Returns {flag, code} or empty.
        // Intentionally conservative: unknown → no flag rather than a wrong one.
        function geoFromHost(host) {
            if (!host)
                return {
                    flag: "",
                    code: ""
                };
            const h = host.toLowerCase();
            // 1) ccTLD on the end (.de, .co.uk → uk, etc.)
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
        //   • hostname  — reverse DNS via getent (always)
        //   • countrycode — MaxMind GeoIP via mmdblookup, only when accurateGeo
        //     is on AND a readable .mmdb + mmdblookup are present. Otherwise the
        //     field is blank and QML falls back to the hostname heuristic.
        // The DB is auto-detected (newest Portmaster geoip file, IPv4/IPv6),
        // never hardcoded — absent Portmaster just means no DB and graceful
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
            const useGeo = plasmoid.configuration.accurateGeo;

            // Shell preamble: locate newest readable Portmaster v4/v6 DBs and
            // confirm mmdblookup exists. DB4/DB6/MM stay empty if unavailable.
            const preamble = useGeo ? "GD=/var/lib/portmaster/updates/all/intel/geoip; " + "DB4=$(ls -1t \"$GD\"/geoipv4_*.mmdb 2>/dev/null | head -1); " + "DB6=$(ls -1t \"$GD\"/geoipv6_*.mmdb 2>/dev/null | head -1); " + "MM=$(command -v mmdblookup 2>/dev/null); " : "MM=''; DB4=''; DB6=''; ";

            // Per-IP: reverse DNS, then (if MM+DB present and IP readable) a
            // country lookup choosing v6 DB for colon-bearing addresses.
            const perIp = list.map(function (ip) {
                const safe = ip.replace(/'/g, "");
                return "ip='" + safe + "'; " + "h=$(timeout 1 getent hosts \"$ip\" 2>/dev/null | awk '{print $2; exit}'); " + "cc=''; " + "if [ -n \"$MM\" ]; then " + "case \"$ip\" in *:*) DB=\"$DB6\";; *) DB=\"$DB4\";; esac; " + "if [ -n \"$DB\" ] && [ -r \"$DB\" ]; then " + "cc=$(timeout 1 \"$MM\" --file \"$DB\" --ip \"$ip\" country iso_code 2>/dev/null | grep -o '\"[A-Za-z][A-Za-z]\"' | head -1 | tr -d '\"');" + "fi; fi; " + "printf '%s\\t%s\\t%s\\n' \"$ip\" \"$h\" \"$cc\"";
            }).join("; ");

            resolveSource.connectSource(preamble + perIp);
        }

        // ISO-3166 alpha-2 → emoji flag via regional indicator symbols.
        function _flag(cc) {
            if (!cc || cc.length !== 2)
                return "";
            const base = 0x1F1E6;
            return String.fromCodePoint(base + cc.charCodeAt(0) - 65) + String.fromCodePoint(base + cc.charCodeAt(1) - 65);
        }
    }

    P5Support.DataSource {
        id: ssSource
        engine: "executable"
        connectedSources: []
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

                // split host:port — handle IPv6 [::]:port
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
    // on popup refresh → one extra subprocess per open, no polling, no daemon.
    P5Support.DataSource {
        id: resolveSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            resolveSource.disconnectSource(sourceName);
            const out = (data["stdout"] || "").trim();
            if (out === "")
                return;
            // Build ip → {hostname, cc} map.
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

    // ── iface badge above graph ──────────────────────────────────────────────
    Item {
        Layout.leftMargin: plasmoid.configuration.showYLabels ? 42 : 4
        implicitWidth: ifaceBadge.implicitWidth
        implicitHeight: ifaceBadge.implicitHeight
        visible: root.activeIface !== ""

        Row {
            id: ifaceBadge
            spacing: 8

            Item {
                id: ifaceWrapper
                implicitWidth: ifaceRow.implicitWidth
                implicitHeight: ifaceRow.implicitHeight

                Row {
                    id: ifaceRow
                    spacing: 4
                    anchors.fill: parent

                    Text {
                        id: ifaceText
                        text: root.activeIface || ""
                        color: ifaceMouseArea.containsMouse ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
                        font.pixelSize: 10
                        font.bold: ifaceMouseArea.containsMouse
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }

                    Text {
                        text: "▾"
                        color: ifaceMouseArea.containsMouse ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
                        font.pixelSize: 10
                        anchors.verticalCenter: ifaceText.verticalCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                MouseArea {
                    id: ifaceMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ifaceMenu.popup()
                }
            }

            Kirigami.Icon {
                id: connInfoIcon
                source: connDialog.opened ? "network-connect" : "network-disconnect"
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                color: connInfoMouse.containsMouse || connDialog.opened ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.38)
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                MouseArea {
                    id: connInfoMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (connDialog.opened) {
                            connDialog.close();
                        } else {
                            connDialog.open();
                            connDialog.refresh();
                        }
                    }
                }
            }

            // SSID / IP chip — inline on the iface badge row (optional, off by
            // default). SSID shows only on Wi-Fi; IP is the primary IPv4.
            Row {
                id: netInfoChip
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: plasmoid.configuration.netShowInfo && (root.netSsid !== "" || root.netIpAddr !== "")

                Row {
                    spacing: 3
                    visible: root.netSsid !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    Kirigami.Icon {
                        source: "network-wireless"
                        width: 11
                        height: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.5)
                    }
                    Text {
                        text: root.netSsid
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.55)
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: root.netIpAddr
                    visible: root.netIpAddr !== ""
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.42)
                    font.pixelSize: 10
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        PlasmaComponents3.Menu {
            id: ifaceMenu

            Repeater {
                model: root.availableIfaces
                delegate: PlasmaComponents3.MenuItem {
                    text: modelData
                    checkable: true
                    checked: (plasmoid.configuration.networkInterface || "auto") === modelData
                    onTriggered: {
                        plasmoid.configuration.networkInterface = modelData;
                    }
                }
            }
        }
    }

    // ── network graph ────────────────────────────────────────────────────────
    BloomChart {
        id: netGraph
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: plasmoid.configuration.chartType !== 6

        Connections {
            target: root
            function onDlHistoryChanged() {
                netGraph.requestPaint();
            }
            function onUlHistoryChanged() {
                netGraph.requestPaint();
            }
            function onTextColorChanged() {
                netGraph.requestPaint();
            }
            function onScrollTickChanged() {
                if (root._netPhaseStart > 0 && root.netScrollPhase() < 2)
                    netGraph.requestPaint();
            }
        }
        Connections {
            target: plasmoid.configuration
            ignoreUnknownSignals: true
            function onGlowLineChanged() {
                netGraph.requestPaint();
            }
            function onLineWidthChanged() {
                netGraph.requestPaint();
            }
            function onShowYLabelsChanged() {
                netGraph.requestPaint();
            }
            function onDlColorChanged() {
                netGraph.requestPaint();
            }
            function onUlColorChanged() {
                netGraph.requestPaint();
            }
            function onChartTypeChanged() {
                netGraph.requestPaint();
            }
            function onShowGridLinesChanged() {
                netGraph.requestPaint();
            }
            function onAutoYRangeChanged() {
                netGraph.requestPaint();
            }
            function onSmoothLinesChanged() {
                netGraph.requestPaint();
            }
            function onGpuBloomChanged() {
                netGraph.requestPaint();
            }
            function onBloomStrengthChanged() {
                netGraph.requestPaint();
            }
        }

        paint: function (ctx, glowPass) {
            const width = netGraph.width, height = netGraph.height;
            const dl = root.dlHistory, ul = root.ulHistory;
            const maxH = Math.max(10, plasmoid.configuration.historySize);
            const yLW = plasmoid.configuration.showYLabels ? 38 : 0;
            const gW = width - yLW;
            const smooth = plasmoid.configuration.smoothLines;
            const ct = plasmoid.configuration.chartType || 0;

            if (dl.length < 1 && ul.length < 1) {
                if (!glowPass)
                    cu.drawIdleLine(ctx, yLW, gW, height);
                return;
            }
            ctx.setLineDash([]);

            if (glowPass && (ct === 3 || ct === 4 || ct === 5))
                return;

            const allVals = dl.concat(ul);
            const dataMax = allVals.length > 0 ? Math.max.apply(null, allVals) : 0;
            const maxBps = Math.max(1024, dataMax * (plasmoid.configuration.autoYRange ? 1.10 : 1.20));
            const tPad = height * 0.06, uH = height * 0.88;
            const step = gW / Math.max(1, maxH - 1);
            const sf = root.netScrollPhase();
            function bToY(b) {
                return height - tPad - (b / maxBps) * uH;
            }
            function iToX(i, len) {
                return yLW + gW - (len - 2 - i + sf) * step;
            }

            if (ct === 3) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.33, lw = Math.max(6, rad * 0.22);
                const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100);
                const ulPct = Math.min(100, (root.uploadSpeed / maxBps) * 100);
                if (!root.isLineDisabled("dl"))
                    cu.drawDonut(ctx, cx, cy, rad, lw, dlPct, root.dlColor, "↓ " + cu.formatSpeed(root.downloadSpeed), "↑ " + cu.formatSpeed(root.uploadSpeed));
                if (!root.isLineDisabled("ul"))
                    cu.drawDonut(ctx, cx, cy, rad * 0.58, lw * 0.72, ulPct, root.ulColor, null, null);
                return;
            }
            if (ct === 4) {
                const cx = yLW + gW / 2, cy = height / 2;
                const rad = Math.min(gW, height) * 0.33;
                const dlPct = Math.min(100, (root.downloadSpeed / maxBps) * 100);
                const ulPct = Math.min(100, (root.uploadSpeed / maxBps) * 100);
                if (!root.isLineDisabled("dl"))
                    cu.drawPie(ctx, cx, cy, rad, dlPct, root.dlColor, "↓ " + cu.formatSpeed(root.downloadSpeed), "↑ " + cu.formatSpeed(root.uploadSpeed));
                if (!root.isLineDisabled("ul"))
                    cu.drawPie(ctx, cx, cy, rad * 0.58, ulPct, root.ulColor, null, null);
                return;
            }
            if (ct === 5) {
                const barH = 10, gap = 8, bx = yLW + 10, bw = gW - 20;
                let activeCount = (!root.isLineDisabled("dl") ? 1 : 0) + (!root.isLineDisabled("ul") ? 1 : 0);
                let y = height / 2 - (activeCount * barH + (activeCount - 1) * gap) / 2;
                if (!root.isLineDisabled("dl")) {
                    cu.drawHorizontalBar(ctx, "Download", (root.downloadSpeed / maxBps) * 100, cu.formatSpeed(root.downloadSpeed), root.dlColor, bx, y, bw, barH);
                    y += barH + gap;
                }
                if (!root.isLineDisabled("ul"))
                    cu.drawHorizontalBar(ctx, "Upload", (root.uploadSpeed / maxBps) * 100, cu.formatSpeed(root.uploadSpeed), root.ulColor, bx, y, bw, barH);
                return;
            }
            if (ct === 1) {
                if (!root.isLineDisabled("dl"))
                    cu.drawHistoryBars(ctx, dl, root.dlColor, yLW, gW, height, maxH, maxBps, sf);
                if (!root.isLineDisabled("ul")) {
                    ctx.globalAlpha = 0.65;
                    cu.drawHistoryBars(ctx, ul, root.ulColor, yLW, gW, height, maxH, maxBps, sf);
                    ctx.globalAlpha = 1.0;
                }
                return;
            }

            if (!glowPass && plasmoid.configuration.showYLabels) {
                cu.drawYAxis(ctx, yLW, height, [
                    {
                        y: bToY(maxBps),
                        text: cu.formatSpeed(maxBps),
                        grid: false
                    },
                    {
                        y: bToY(maxBps * 0.5),
                        text: cu.formatSpeed(maxBps * 0.5),
                        grid: true
                    },
                    {
                        y: bToY(0),
                        text: "0",
                        grid: false
                    }
                ]);
            }

            const fillA = glowPass ? 0 : (ct === 2 ? 0.60 : 0.35);
            function drawLine(history, color, key) {
                if (history.length < 2 || root.isLineDisabled(key))
                    return;
                const len = history.length;
                const isHov = root.hoveredLine === key;
                const dimOth = (root.hoveredLine === "dl" || root.hoveredLine === "ul") && !isHov;

                // OPTIMIZATION: Precalculate all coordinates before drawing
                const coords = new Array(len);
                for (let i = 0; i < len; i++) {
                    coords[i] = {
                        x: iToX(i, len),
                        y: bToY(history[i])
                    };
                }

                ctx.save();
                ctx.beginPath();
                ctx.rect(yLW, 0, gW, height);
                ctx.clip();
                ctx.globalAlpha = dimOth ? 0.15 : 1.0;
                const lw = plasmoid.configuration.lineWidth;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                // Build path once, stroke twice for glow (no shadowBlur)
                const nc = Qt.color(color);
                ctx.beginPath();
                ctx.moveTo(coords[0].x, coords[0].y);
                for (let i = 1; i < len; i++) {
                    if (smooth) {
                        const cx = (coords[i - 1].x + coords[i].x) / 2;
                        ctx.bezierCurveTo(cx, coords[i - 1].y, cx, coords[i].y, coords[i].x, coords[i].y);
                    } else {
                        ctx.lineTo(coords[i].x, coords[i].y);
                    }
                }
                // Manual wide-stroke glow only when GPU bloom isn't owning the halo.
                if (plasmoid.configuration.glowLine && !glowPass && !cu.gpuBloom) {
                    ctx.lineWidth = lw * (isHov ? 4.5 : 3.5);
                    ctx.strokeStyle = Qt.rgba(nc.r, nc.g, nc.b, 0.22);
                    ctx.stroke();
                }
                ctx.lineWidth = lw;
                ctx.strokeStyle = color;
                ctx.stroke();

                // Draw fill
                if (fillA > 0) {
                    ctx.beginPath();
                    ctx.moveTo(coords[0].x, coords[0].y);
                    for (let i = 1; i < len; i++) {
                        if (smooth) {
                            const cx = (coords[i - 1].x + coords[i].x) / 2;
                            ctx.bezierCurveTo(cx, coords[i - 1].y, cx, coords[i].y, coords[i].x, coords[i].y);
                        } else {
                            ctx.lineTo(coords[i].x, coords[i].y);
                        }
                    }
                    ctx.lineTo(coords[len - 1].x, height);
                    ctx.lineTo(coords[0].x, height);
                    ctx.closePath();
                    const c = Qt.color(color);
                    const g = ctx.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, fillA));
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
                ctx.restore();
            }
            drawLine(ul, root.ulColor, "ul");
            drawLine(dl, root.dlColor, "dl");
        }
    }

    // ── session traffic totals ───────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }
        Text {
            text: "↓ " + cu.formatBytes(root.sessionDlBytes)
            color: root.dlColor
            font.pixelSize: 10
            opacity: 0.80
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            text: "↑ " + cu.formatBytes(root.sessionUlBytes)
            color: root.ulColor
            font.pixelSize: 10
            opacity: 0.80
        }
    }

    // ── legend + live values ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Item {
            width: plasmoid.configuration.showYLabels ? 38 : 0
        }

        Item {
            implicitWidth: dlRow.implicitWidth
            implicitHeight: dlRow.implicitHeight
            Row {
                id: dlRow
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("dl") ? "transparent" : root.dlColor
                    border.color: root.dlColor
                    border.width: 1
                }
                Text {
                    text: "Download"
                    color: root.isLineDisabled("dl") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("dl")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(root.downloadSpeed)
                    color: root.isLineDisabled("dl") ? Qt.rgba(root.dlColor.r, root.dlColor.g, root.dlColor.b, 0.3) : root.dlColor
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("dl");
                    netGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "dl";
                    netGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    netGraph.requestPaint();
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Item {
            implicitWidth: ulRow.implicitWidth
            implicitHeight: ulRow.implicitHeight
            Row {
                id: ulRow
                spacing: 5
                Rectangle {
                    width: 8
                    height: 8
                    radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.isLineDisabled("ul") ? "transparent" : root.ulColor
                    border.color: root.ulColor
                    border.width: 1
                }
                Text {
                    text: "Upload"
                    color: root.isLineDisabled("ul") ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.7)
                    font.pixelSize: 10
                    font.strikeout: root.isLineDisabled("ul")
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cu.formatSpeed(root.uploadSpeed)
                    color: root.isLineDisabled("ul") ? Qt.rgba(root.ulColor.r, root.ulColor.g, root.ulColor.b, 0.3) : root.ulColor
                    font.pixelSize: 12
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    root.toggleLineDisabled("ul");
                    netGraph.requestPaint();
                }
                onEntered: {
                    root.hoveredLine = "ul";
                    netGraph.requestPaint();
                }
                onExited: {
                    root.hoveredLine = "";
                    netGraph.requestPaint();
                }
            }
        }
    }
}
