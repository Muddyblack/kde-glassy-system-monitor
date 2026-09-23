import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Probes.js" as Probes
import "NetModel.js" as NetModel

// Open ports per app. Ports reachable from other machines get the warning
// colour; loopback-only ones are this machine's business.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var groups: {
        const q = page.query.trim().toLowerCase();
        const rows = page.net.listening.filter(r => !q || [r.name, r.ip, r.port, r.proto].some(v => String(v).toLowerCase().indexOf(q) !== -1));
        return NetModel.listeningByApp(rows, page.net.tree, page.net.desktopIndex, page.net.containers);
    }
    readonly property int openCount: page.net.listening.filter(l => l.exposure === "network").length
    readonly property var fw: page.net.firewall
    readonly property string fwText: {
        if (!fw)
            return "Checking the firewall…";
        switch (fw.kind) {
        case "firewalld":
            return "firewalld is active, zone \"" + fw.zone + "\": it lets in " + (fw.services.concat(fw.ports.filter(p => !fw.services.length).map(p => p.from + "/" + p.proto)).join(", ") || "nothing extra") + ". Ports marked blocked are not reachable from outside.";
        case "nixos":
            return "The NixOS firewall is active and lets in " + (fw.ports.map(p => (p.from === p.to ? p.from : p.from + "–" + p.to) + "/" + p.proto).filter((x, i, a) => a.indexOf(x) === i).join(", ") || "nothing") + " (networking.firewall). Everything else is blocked from outside.";
        case "ufw":
            return "ufw is active. Its rules are only readable as root, and Glassy never asks for a password: check with sudo ufw status.";
        case "nftables":
        case "iptables":
            return fw.kind + " rules are active but only readable as root; Glassy never asks for a password.";
        }
        return "No firewall service is running: every port open to the network is reachable from it.";
    }

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
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: note.implicitHeight + 20
            radius: 10
            color: Qt.rgba(view.theme.warn.r, view.theme.warn.g, view.theme.warn.b, 0.08)
            border.color: Qt.rgba(view.theme.warn.r, view.theme.warn.g, view.theme.warn.b, 0.3)
            Text {
                id: note
                x: 12
                y: 10
                width: parent.width - 24
                wrapMode: Text.WordWrap
                text: view.openCount + " of " + page.net.listening.length + " listening sockets accept connections from the network (0.0.0.0, :: or a real address). Loopback ones (127.0.0.1, ::1) only take connections from this machine.\n🛡 " + view.fwText
                color: view.theme.muted
                font.family: view.theme.fontFamily
                font.pixelSize: 11
            }
        }

        Text {
            visible: view.groups.length === 0
            text: "Nothing is listening" + (page.query ? " that matches" : "")
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 12
        }

        Repeater {
            model: view.groups
            NetCard {
                id: group
                required property var modelData
                theme: view.theme
                Layout.fillWidth: true
                padding: 12
                ColumnLayout {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        spacing: 10
                        AppIcon {
                            theme: view.theme
                            size: 24
                            iconName: group.modelData.icon
                            name: group.modelData.name
                        }
                        Text {
                            Layout.fillWidth: true
                            text: group.modelData.name
                            color: view.theme.text
                            font.family: view.theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        NetBadge {
                            visible: group.modelData.open > 0
                            theme: view.theme
                            text: group.modelData.open + " OPEN TO NETWORK"
                            tint: view.theme.warn
                        }
                    }
                    Repeater {
                        model: group.modelData.rows
                        Rectangle {
                            id: port
                            required property var modelData
                            readonly property bool open: modelData.exposure === "network"
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: 6
                            color: portArea.containsMouse ? view.theme.hover : "transparent"
                            MouseArea {
                                id: portArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: page.showActions(null, port.modelData.pid, port.modelData.name || group.modelData.name, port, null, {
                                    proto: port.modelData.proto,
                                    port: port.modelData.port,
                                    name: group.modelData.name
                                })
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 34
                                anchors.rightMargin: 8
                                spacing: 12
                                NetBadge {
                                    Layout.preferredWidth: 34
                                    theme: view.theme
                                    text: port.modelData.proto.toUpperCase()
                                    tint: port.modelData.proto === "tcp" ? view.theme.rx : view.theme.ok
                                }
                                Text {
                                    Layout.preferredWidth: 90
                                    text: ":" + port.modelData.port
                                    color: view.theme.text
                                    font.family: "monospace"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: port.modelData.ip + (port.modelData.scope ? "%" + port.modelData.scope : "")
                                    color: view.theme.muted
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: port.modelData.container ? "→ container :" + port.modelData.containerPort : port.modelData.pid ? "PID " + port.modelData.pid : "other user"
                                    color: view.theme.dim
                                    font.family: view.theme.fontFamily
                                    font.pixelSize: 10
                                }
                                // What the firewall does with it, when that is known.
                                NetBadge {
                                    readonly property string verdict: port.open ? Probes.firewallVerdict(view.fw, port.modelData.proto, port.modelData.port) : ""
                                    visible: verdict !== "" && verdict !== "open"
                                    theme: view.theme
                                    text: verdict === "allowed" ? "FIREWALL ALLOWS" : "FIREWALL BLOCKS"
                                    tint: verdict === "allowed" ? view.theme.warn : view.theme.ok
                                }
                                NetBadge {
                                    Layout.preferredWidth: 150
                                    theme: view.theme
                                    text: port.open ? (port.modelData.kind === "any" ? "OPEN · ALL ADDRESSES" : "OPEN · " + Probes.ADDRESS_LABELS[port.modelData.kind].toUpperCase()) : "THIS MACHINE ONLY"
                                    tint: port.open ? view.theme.warn : view.theme.ok
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
