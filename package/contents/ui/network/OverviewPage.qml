import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "../Probes.js" as Probes

// Totals, the live chart, and who uses the network most right now.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var net: page.net
    readonly property var s: page.summary
    readonly property int columns: width > 1100 ? 4 : width > 760 ? 2 : 1
    // One measure per list, for every row alike: live rate while anything
    // moves, else bytes so far, else the number of connections.
    function measure(rows, rate, bytes, count) {
        const r = rows.some(x => rate(x) > 0) ? rate : rows.some(x => bytes(x) > 0) ? bytes : count;
        return rows.map(x => r(x));
    }

    contentHeight: grid.implicitHeight + 36
    clip: true
    activeFocusOnTab: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    Keys.onUpPressed: flick(0, 800)
    Keys.onDownPressed: flick(0, -800)

    component Stat: NetCard {
        id: stat
        property string value: ""
        property string note: ""
        property color accent: view.theme.text
        theme: view.theme
        fill: true
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        Column {
            spacing: 4
            Text {
                text: stat.value
                color: stat.accent
                font.family: view.theme.fontFamily
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                text: stat.note
                color: view.theme.dim
                font.family: view.theme.fontFamily
                font.pixelSize: 10
            }
        }
    }

    GridLayout {
        id: grid
        x: 18
        y: 18
        width: view.width - 36
        columns: view.columns
        columnSpacing: 14
        rowSpacing: 14

        Stat {
            title: "Download"
            value: Format.speed(view.net.rateIn)
            accent: view.theme.rx
            note: "all physical links"
        }
        Stat {
            title: "Upload"
            value: Format.speed(view.net.rateOut)
            accent: view.theme.tx
            note: "all physical links"
        }
        Stat {
            title: "Connections"
            value: String(view.s.active)
            note: view.s.internet + " to the internet" + (view.s.ended ? " · " + view.s.ended + " ended" : "")
        }
        Stat {
            title: "Apps online"
            value: String(view.s.apps)
            note: view.net.listening.filter(l => l.exposure === "network").length + " ports open to the network"
        }

        NetCard {
            theme: view.theme
            title: "Traffic"
            fill: true
            subtitle: "last " + view.net.historySize * view.net.interval / 1000 / 60 + " min"
            Layout.columnSpan: view.columns
            Layout.fillWidth: true
            Layout.preferredHeight: 230
            RateChart {
                anchors.fill: parent
                anchors.bottomMargin: 18
                theme: view.theme
                seriesIn: view.net.historyIn
                seriesOut: view.net.historyOut
                capacity: view.net.historySize
            }
            Row {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                spacing: 14
                Text {
                    text: "● Download " + Format.speed(view.net.rateIn)
                    color: view.theme.rx
                    font.family: view.theme.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    text: "● Upload " + Format.speed(view.net.rateOut)
                    color: view.theme.tx
                    font.family: view.theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }

        // VPN: which tunnel, and what goes through it or around it.
        Repeater {
            model: view.net.vpns
            NetCard {
                id: vpnCard
                required property var modelData
                readonly property var v: modelData
                theme: view.theme
                title: "VPN"
                subtitle: vpnCard.v.iface
                Layout.columnSpan: view.columns
                Layout.fillWidth: true
                RowLayout {
                    width: parent.width
                    spacing: 16
                    Text {
                        text: vpnCard.v.up ? "⛨" : "⚠"
                        color: vpnCard.v.up ? view.theme.ok : view.theme.warn
                        font.pixelSize: 22
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: vpnCard.v.provider + (vpnCard.v.up ? " · connected" : " · down") + (vpnCard.v.ip ? " · " + vpnCard.v.ip : "")
                            color: view.theme.text
                            font.family: view.theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: !vpnCard.v.up ? "The tunnel is down: everything leaves directly." : vpnCard.v.of === 0 ? "No internet connections right now." : vpnCard.v.conns === vpnCard.v.of ? "All " + vpnCard.v.of + " internet connections go through the tunnel." : vpnCard.v.conns + " of " + vpnCard.v.of + " internet connections go through the tunnel. Directly: " + vpnCard.v.direct.join(", ") + "."
                            color: vpnCard.v.up && vpnCard.v.conns === vpnCard.v.of ? view.theme.muted : view.theme.warn
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 180
                        visible: vpnCard.v.of > 0
                        height: 6
                        radius: 3
                        color: Qt.rgba(view.theme.warn.r, view.theme.warn.g, view.theme.warn.b, 0.35)
                        clip: true
                        Rectangle {
                            width: parent.width * vpnCard.v.conns / Math.max(1, vpnCard.v.of)
                            height: parent.height
                            radius: 3
                            color: view.theme.ok
                        }
                    }
                }
            }
        }

        NetCard {
            theme: view.theme
            title: "Top apps"
            subtitle: "by live traffic"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                readonly property var values: view.measure(view.s.topApps, a => a.rateIn + a.rateOut, a => a.bytesIn + a.bytesOut, a => a.active)
                rows: view.s.topApps.map((a, i) => ({
                            label: a.name,
                            icon: a.icon,
                            value: values[i],
                            text: "↓ " + Format.speed(a.rateIn) + "  ↑ " + Format.speed(a.rateOut)
                        }))
                empty: "No app has a connection open"
            }
        }
        NetCard {
            theme: view.theme
            title: "Top domains"
            subtitle: "reverse DNS"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                readonly property var values: view.measure(view.s.topDomains, d => d.rate, d => d.bytes, d => d.count)
                rows: view.s.topDomains.map((d, i) => ({
                            label: d.key,
                            value: values[i],
                            text: d.count + (d.count === 1 ? " connection · " : " connections · ") + Format.speed(d.rate)
                        }))
                empty: "Names appear as they resolve"
            }
        }
        NetCard {
            theme: view.theme
            visible: view.net.geo.country
            title: "Top countries"
            subtitle: "local GeoIP"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                readonly property var values: view.measure(view.s.topCountries, d => d.rate, d => d.bytes, d => d.count)
                rows: view.s.topCountries.map((d, i) => ({
                            label: d.key,
                            flag: d.key,
                            value: values[i],
                            text: d.count + " · " + Format.speed(d.rate)
                        }))
            }
        }
        NetCard {
            theme: view.theme
            visible: !view.net.geo.country && !view.net.demo
            title: "Countries"
            subtitle: "local GeoIP"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            ColumnLayout {
                width: parent.width
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Where your connections go, and who owns the servers, from a database on this machine. Nothing is looked up online."
                    color: view.theme.muted
                    font.family: view.theme.fontFamily
                    font.pixelSize: 11
                }
                NetButton {
                    theme: view.theme
                    text: "Set up countries…"
                    onClicked: view.page.openGeoSetup()
                }
            }
        }
        NetCard {
            id: dnsCard
            theme: view.theme
            title: "DNS"
            subtitle: view.net.dns.resolved || view.net.dns.viaResolved ? "systemd-resolved" : "resolv.conf"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            readonly property var st: view.net.dns.stats
            readonly property var servers: {
                const out = view.net.dns.global.map(ip => ["Global", ip]);
                for (const link in view.net.dns.links)
                    for (const ip of view.net.dns.links[link])
                        out.push([link, ip]);
                return out;
            }
            ColumnLayout {
                width: parent.width
                spacing: 6
                Repeater {
                    model: dnsCard.servers
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: modelData[1]
                            color: view.theme.text
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData[0]
                            color: view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
                Repeater {
                    model: view.net.dns.resolved ? [["Queries", dnsCard.st["Total Transactions"]], ["Cache hits", dnsCard.st["Cache Hits"]], ["Cache misses", dnsCard.st["Cache Misses"]], ["Cached names", dnsCard.st["Current Cache Size"]]] : []
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: modelData[0]
                            color: view.theme.muted
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData[1] === undefined ? "–" : Number(modelData[1]).toLocaleString(Qt.locale(), "f", 0)
                            color: view.theme.text
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: view.net.dns.resolved ? "Hit rate " + Math.round(100 * (dnsCard.st["Cache Hits"] || 0) / Math.max(1, (dnsCard.st["Cache Hits"] || 0) + (dnsCard.st["Cache Misses"] || 0))) + " %. Single queries are not listed: logging them needs root." : view.net.dns.viaResolved ? "systemd-resolved keeps its counters for admins (Glassy never asks for a password). Single queries are not listed: that needs root too." : "Without systemd-resolved there are no counters; single queries are not listed (that needs root)."
                    color: view.theme.dim
                    font.family: view.theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
