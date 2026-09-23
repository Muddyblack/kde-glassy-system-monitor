import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "../Probes.js" as Probes
import "NetHistory.js" as NetHistory

// One card per interface: kind, state, addresses, gateway, DNS, Wi-Fi.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var net: page.net
    readonly property string defaultIface: Probes.autoInterface(net.interfaces, net.ifaceRates, "")
    readonly property int columns: Math.max(1, Math.floor((width - 36 + 14) / 360))
    // #9: this month and today per interface, from the history.
    readonly property var usage: {
        page.service.historyRevision;
        const now = Date.now(), today = NetHistory.dayKey(now), month = today.slice(0, 7), out = {};
        for (const k in page.service.history.days) {
            if (k.slice(0, 7) !== month)
                continue;
            const ifs = page.service.history.days[k].ifaces || {};
            for (const n in ifs) {
                const u = out[n] || (out[n] = {
                        monthIn: 0,
                        monthOut: 0,
                        todayIn: 0,
                        todayOut: 0
                    });
                u.monthIn += ifs[n][0];
                u.monthOut += ifs[n][1];
                if (k === today) {
                    u.todayIn += ifs[n][0];
                    u.todayOut += ifs[n][1];
                }
            }
        }
        return out;
    }

    contentHeight: grid.implicitHeight + 36
    clip: true
    activeFocusOnTab: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    Keys.onUpPressed: flick(0, 800)
    Keys.onDownPressed: flick(0, -800)

    GridLayout {
        id: grid
        x: 18
        y: 18
        width: view.width - 36
        columns: view.columns
        columnSpacing: 14
        rowSpacing: 14

        Text {
            visible: view.net.interfaces.length === 0
            text: "Reading interfaces…"
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 12
        }

        Repeater {
            model: view.net.interfaces
            NetCard {
                id: card
                required property var modelData
                readonly property var i: modelData
                readonly property var d: view.net.ifaceDetails[i.name] || ({
                        ipv4: [],
                        ipv6: [],
                        gateway: "",
                        gateway6: "",
                        dns: [],
                        wifi: null
                    })
                readonly property var r: view.net.ifaceRates[i.name] || ({
                        rx: 0,
                        tx: 0
                    })
                // A bridge a container network uses.
                readonly property var bridgeOf: {
                    for (const e in view.net.containers)
                        for (const n of view.net.containers[e].networks)
                            if (n.iface === i.name)
                                return n;
                    return null;
                }
                readonly property var use: view.usage[i.name] || null
                readonly property var vpn: view.net.vpns.find(v => v.iface === i.name) || null
                readonly property var facts: [["VPN", vpn ? vpn.provider : ""], ["Today", use ? "↓ " + Format.bytes(use.todayIn) + "   ↑ " + Format.bytes(use.todayOut) : ""], ["This month", use ? "↓ " + Format.bytes(use.monthIn) + "   ↑ " + Format.bytes(use.monthOut) : ""], ["Containers", bridgeOf ? (bridgeOf.engine === "docker" ? "Docker" : "Podman") + " network \"" + bridgeOf.name + "\"" : ""], ["IPv4", d.ipv4.length ? d.ipv4.join("\n") : i.ip], ["IPv6", d.ipv6.join("\n")], ["MAC", i.mac], ["Link speed", i.speed > 0 ? (i.speed >= 1000 ? i.speed / 1000 + " Gbit/s" : i.speed + " Mbit/s") : ""], ["Gateway", [d.gateway, d.gateway6].filter(Boolean).join("\n")], ["DNS", d.dns.join("\n")], ["Wi-Fi", d.wifi ? d.wifi.ssid : ""], ["Signal", d.wifi && (d.wifi.signal || d.wifi.quality) ? (d.wifi.signal ? d.wifi.signal + " dBm · " : "") + d.wifi.quality + " %" : ""], ["Band", d.wifi && d.wifi.freq ? d.wifi.band + " · " + d.wifi.freq + " MHz" : ""], ["Bit rate", d.wifi ? d.wifi.bitrate : ""]].filter(f => f[1])
                theme: view.theme
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 340
                opacity: i.up ? 1 : 0.6
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 10
                            color: view.theme.sunk
                            border.color: view.theme.line2
                            Text {
                                anchors.centerIn: parent
                                text: ({
                                        wifi: "📶",
                                        ethernet: "🔌",
                                        vpn: "🔒",
                                        bridge: "🌉",
                                        virtual: "▣"
                                    })[card.i.kind] || "◇"
                                color: view.theme.muted
                                font.pixelSize: 15
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: card.i.name
                                color: view.theme.text
                                font.family: view.theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: Probes.KIND_LABELS[card.i.kind] || "Other"
                                color: view.theme.dim
                                font.family: view.theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                        NetBadge {
                            visible: card.i.name === view.defaultIface
                            theme: view.theme
                            text: "DEFAULT ROUTE"
                            tint: view.theme.brand
                        }
                        NetButton {
                            visible: view.net.captureTools.wireshark && card.i.up
                            implicitHeight: 22
                            theme: view.theme
                            text: "🦈"
                            tooltip: "Capture " + card.i.name + " in Wireshark"
                            onClicked: view.page.wireshark(card.i.name, "", "")
                        }
                        NetBadge {
                            theme: view.theme
                            text: card.i.up ? "UP" : "DOWN"
                            tint: card.i.up ? view.theme.ok : view.theme.dim
                        }
                    }
                    Sparkline {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        visible: card.i.up
                        theme: view.theme
                        seriesIn: (view.net.ifaceSeries[card.i.name] || {})["in"] || []
                        seriesOut: (view.net.ifaceSeries[card.i.name] || {}).out || []
                        capacity: view.net.seriesSize
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: card.i.up
                        spacing: 16
                        Text {
                            text: "↓ " + Format.speed(card.r.rx)
                            color: view.theme.rx
                            font.family: view.theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "↑ " + Format.speed(card.r.tx)
                            color: view.theme.tx
                            font.family: view.theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 5
                        Repeater {
                            model: card.facts.length * 2
                            Text {
                                required property int index
                                readonly property var fact: card.facts[Math.floor(index / 2)]
                                readonly property bool key: index % 2 === 0
                                Layout.fillWidth: !key
                                Layout.alignment: Qt.AlignTop
                                text: key ? fact[0] : fact[1]
                                color: key ? view.theme.dim : view.theme.text
                                font.family: !key && ["IPv4", "IPv6", "MAC", "Gateway", "DNS"].indexOf(fact[0]) !== -1 ? "monospace" : view.theme.fontFamily
                                font.pixelSize: key ? 10 : 11
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }
        }
    }
}
