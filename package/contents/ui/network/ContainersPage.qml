import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "../Probes.js" as Probes

// Docker and Podman: every running container with its published ports
// (open to the network or not), networks, addresses and live traffic.
// Containers live in their own network namespaces, so their connections do
// not show on the other pages; their traffic comes from the engines' stats.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var net: page.net
    readonly property var engines: net.containers
    readonly property var list: {
        const q = page.query.trim().toLowerCase();
        const out = [];
        for (const e in engines)
            for (const c of engines[e].containers)
                if (!q || [c.name, c.image, c.engine, c.networks.join(" "), Object.values(c.ips).join(" "), c.ports.map(p => p.hostPort).join(" ")].some(v => String(v).toLowerCase().indexOf(q) !== -1))
                    out.push(c);
        return out;
    }
    readonly property var networks: {
        const out = [];
        for (const e in engines)
            for (const n of engines[e].networks)
                out.push(n);
        return out;
    }
    readonly property int columns: Math.max(1, Math.floor((width - 36 + 14) / 380))

    contentHeight: col.implicitHeight + 36
    clip: true
    activeFocusOnTab: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    Keys.onUpPressed: flick(0, 800)
    Keys.onDownPressed: flick(0, -800)

    ColumnLayout {
        id: col
        x: 18
        y: 18
        width: view.width - 36
        spacing: 14

        // Engines that are missing or refuse this user.
        Repeater {
            model: Object.keys(view.engines).filter(e => view.engines[e].error !== "")
            Rectangle {
                id: problem
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: problemText.implicitHeight + 20
                radius: 10
                color: Qt.rgba(view.theme.warn.r, view.theme.warn.g, view.theme.warn.b, 0.08)
                border.color: Qt.rgba(view.theme.warn.r, view.theme.warn.g, view.theme.warn.b, 0.3)
                Text {
                    id: problemText
                    x: 12
                    y: 10
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    readonly property string message: view.engines[problem.modelData].error
                    text: (problem.modelData === "docker" ? "Docker" : "Podman") + ": " + message + (/permission denied/i.test(message) ? "\nGlassy runs without root: add yourself to the docker group (sudo usermod -aG docker $USER, then log in again), or use rootless Podman." : "")
                    color: view.theme.muted
                    font.family: view.theme.fontFamily
                    font.pixelSize: 11
                }
            }
        }
        Text {
            visible: Object.keys(view.engines).length === 0
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Neither docker nor podman is installed (or on the PATH of the desktop session)."
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 12
        }
        Text {
            visible: Object.keys(view.engines).length > 0 && view.list.length === 0 && Object.keys(view.engines).every(e => view.engines[e].error === "")
            text: page.query ? "No container matches" : "No container is running"
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 12
        }

        GridLayout {
            Layout.fillWidth: true
            columns: view.columns
            columnSpacing: 14
            rowSpacing: 14
            Repeater {
                model: view.list
                NetCard {
                    id: card
                    required property var modelData
                    readonly property var c: modelData
                    readonly property string key: c.engine + ":" + c.name
                    readonly property var rate: view.net.containerRates[key] || null
                    readonly property var series: view.net.containerSeries[key] || ({
                            "in": [],
                            out: []
                        })
                    theme: view.theme
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 360
                    ColumnLayout {
                        width: parent.width
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            AppIcon {
                                theme: view.theme
                                size: 28
                                iconName: card.c.engine
                                name: card.c.name
                            }
                            Column {
                                Layout.fillWidth: true
                                Text {
                                    width: parent.width
                                    text: card.c.name
                                    color: view.theme.text
                                    elide: Text.ElideRight
                                    font.family: view.theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: card.c.image
                                    color: view.theme.dim
                                    elide: Text.ElideMiddle
                                    font.family: "monospace"
                                    font.pixelSize: 10
                                }
                            }
                            NetBadge {
                                theme: view.theme
                                text: card.c.engine.toUpperCase()
                                tint: card.c.engine === "docker" ? view.theme.rx : view.theme.tx
                            }
                            NetBadge {
                                theme: view.theme
                                text: card.c.state.toUpperCase()
                                tint: card.c.state === "running" ? view.theme.ok : view.theme.dim
                            }
                        }
                        Sparkline {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            visible: !!card.rate
                            theme: view.theme
                            seriesIn: card.series["in"]
                            seriesOut: card.series.out
                            capacity: view.net.seriesSize
                        }
                        Text {
                            text: card.rate ? "↓ " + Format.speed(card.rate.rx) + "   ↑ " + Format.speed(card.rate.tx) + "   · " + Format.bytes(card.rate.totalRx) + " in, " + Format.bytes(card.rate.totalTx) + " out" : card.c.networks.indexOf("host") !== -1 ? "Host network: its traffic counts as this machine's" : "Traffic appears after the next stats read"
                            color: card.rate ? view.theme.muted : view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                        }
                        Repeater {
                            model: card.c.ports
                            RowLayout {
                                id: port
                                required property var modelData
                                readonly property string kind: Probes.isWildcard(modelData.hostIp) ? "any" : Probes.addressKind(modelData.hostIp)
                                readonly property bool open: kind !== "loopback"
                                Layout.fillWidth: true
                                spacing: 8
                                NetBadge {
                                    Layout.preferredWidth: 34
                                    theme: view.theme
                                    text: port.modelData.proto.toUpperCase()
                                    tint: port.modelData.proto === "tcp" ? view.theme.rx : view.theme.ok
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: port.modelData.hostIp + ":" + port.modelData.hostPort + "  →  :" + port.modelData.containerPort
                                    color: view.theme.text
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                NetBadge {
                                    theme: view.theme
                                    text: port.open ? "OPEN TO NETWORK" : "THIS MACHINE ONLY"
                                    tint: port.open ? view.theme.warn : view.theme.ok
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WrapAnywhere
                            text: card.c.networks.map(n => card.c.ips[n] ? n + " " + card.c.ips[n] : n).join("   ·   ") + "   ·   " + card.c.status
                            color: view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        NetCard {
            theme: view.theme
            visible: view.networks.length > 0
            title: "Networks"
            subtitle: "bridge interface on this machine"
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 4
                Repeater {
                    model: view.networks
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        NetBadge {
                            Layout.preferredWidth: 60
                            theme: view.theme
                            text: modelData.engine.toUpperCase()
                            tint: modelData.engine === "docker" ? view.theme.rx : view.theme.tx
                        }
                        Text {
                            Layout.preferredWidth: 180
                            text: modelData.name
                            color: view.theme.text
                            font.family: view.theme.fontFamily
                            font.pixelSize: 12
                        }
                        Text {
                            Layout.preferredWidth: 80
                            text: modelData.driver
                            color: view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.iface ? modelData.iface + (view.net.ifaceRates[modelData.iface] ? "   ↓ " + Format.speed(view.net.ifaceRates[modelData.iface].rx) + "  ↑ " + Format.speed(view.net.ifaceRates[modelData.iface].tx) : "") : "—"
                            color: view.theme.muted
                            font.family: "monospace"
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
