import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "../Probes.js" as Probes

// One row per app (helpers grouped under it); expand for its connections.
ListView {
    id: view
    required property var page
    readonly property var theme: page.theme
    property var expanded: {
        const open = {};
        for (const key of page.expandApps)
            open[key] = true;
        return open;
    }
    function toggle(key, open) {
        const next = Object.assign({}, expanded);
        next[key] = open === undefined ? !next[key] : open;
        expanded = next;
    }

    model: KeyedModel {
        rows: page.appList
    }
    clip: true
    spacing: 6
    topMargin: 14
    bottomMargin: 14
    leftMargin: 18
    rightMargin: 18
    activeFocusOnTab: true
    keyNavigationEnabled: true
    highlightFollowsCurrentItem: false
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}

    function currentApp() {
        return currentIndex >= 0 && currentIndex < page.appList.length ? page.appList[currentIndex] : null;
    }
    Keys.onReturnPressed: if (currentApp())
        toggle(currentApp().key)
    Keys.onSpacePressed: if (currentApp())
        toggle(currentApp().key)
    Keys.onRightPressed: if (currentApp())
        toggle(currentApp().key, true)
    Keys.onLeftPressed: if (currentApp())
        toggle(currentApp().key, false)
    Keys.onMenuPressed: if (currentApp() && currentItem)
        page.showActions(null, currentApp().pid, currentApp().name, currentItem, currentApp())
    Keys.onDeletePressed: if (currentApp())
        page.askKill(currentApp().pid, currentApp().name)

    Text {
        anchors.centerIn: parent
        visible: view.count === 0
        text: page.filtering ? "No app matches the filters" : "No app has a connection open"
        color: view.theme.dim
        font.family: view.theme.fontFamily
        font.pixelSize: 12
    }

    delegate: Rectangle {
        id: card
        required property var row
        required property int index
        readonly property var app: row
        readonly property bool trusted: !!page.service.trusted[app.key]
        // First seen in the last three days (or never recorded before).
        readonly property bool isNew: !trusted && app.key !== "?" && (() => {
                const first = page.service.firstSeen[app.key];
                return !first || Date.now() - new Date(first + "T12:00:00").getTime() < 3 * 86400000;
            })() && page.service.historyLoaded && Object.keys(page.service.history.days).length > 3
        // With a VPN up: do the app's internet connections go through it?
        readonly property string vpnState: {
            const tunnels = page.net.vpns.filter(v => v.up).map(v => v.iface);
            if (!tunnels.length)
                return "";
            const inet = app.conns.filter(c => !c.ended && c.kind === "internet" && c.via);
            if (!inet.length)
                return "";
            const through = inet.filter(c => tunnels.indexOf(c.via) !== -1).length;
            return through === inet.length ? "vpn" : through === 0 ? "direct" : "mixed";
        }
        readonly property var limit: page.service.limits[app.key] || null
        readonly property real usedToday: limit ? page.service.appToday(app.key) : 0
        readonly property bool open: !!view.expanded[app.key]
        readonly property bool current: view.currentIndex === index && view.activeFocus
        width: view.width - view.leftMargin - view.rightMargin
        height: head.height + (open ? appChart.height + conns.implicitHeight + 16 : 0)
        radius: 12
        color: current ? view.theme.selected : view.theme.card
        border.width: 1
        border.color: current ? view.theme.selectedBorder : view.theme.line2
        opacity: app.active ? 1 : 0.55
        clip: true

        Item {
            id: head
            width: parent.width
            height: card.limit ? 66 : 54
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    view.currentIndex = card.index;
                    view.forceActiveFocus();
                    if (mouse.button === Qt.RightButton)
                        page.showActions(null, card.app.pid, card.app.name, head, card.app);
                    else
                        view.toggle(card.app.key);
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12
                Text {
                    text: card.open ? "▾" : "▸"
                    color: view.theme.dim
                    font.pixelSize: 12
                }
                AppIcon {
                    theme: view.theme
                    size: 28
                    iconName: card.app.icon
                    name: card.app.name
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Row {
                        spacing: 6
                        Text {
                            text: card.app.name
                            color: view.theme.text
                            font.family: view.theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        NetBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.trusted
                            theme: view.theme
                            text: "✓ TRUSTED"
                            tint: view.theme.ok
                        }
                        NetBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.isNew
                            theme: view.theme
                            text: "NEW"
                            tint: view.theme.brand
                        }
                        NetBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.vpnState !== ""
                            theme: view.theme
                            text: card.vpnState === "vpn" ? "VPN" : card.vpnState === "mixed" ? "PARTLY VPN" : "DIRECT"
                            tint: card.vpnState === "vpn" ? view.theme.ok : view.theme.warn
                        }
                    }
                    Text {
                        width: parent.width
                        text: [card.app.pids.length > 1 ? card.app.pids.length + " processes" : card.app.pids.length ? "PID " + card.app.pids[0] : "process hidden (other user)", card.app.active + " open", card.app.ended ? card.app.ended + " ended" : ""].filter(Boolean).join(" · ")
                        color: view.theme.dim
                        elide: Text.ElideRight
                        font.family: view.theme.fontFamily
                        font.pixelSize: 10
                    }
                    Row {
                        visible: !!card.limit
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140
                            height: 4
                            radius: 2
                            clip: true
                            color: view.theme.sunk
                            Rectangle {
                                width: card.limit ? parent.width * Math.min(1, card.usedToday / card.limit.bytes) : 0
                                height: parent.height
                                radius: 2
                                color: card.limit && card.usedToday >= card.limit.bytes ? view.theme.danger : view.theme.brand
                            }
                        }
                        Text {
                            text: card.limit ? Format.bytes(card.usedToday) + " of " + Format.bytes(card.limit.bytes) + " today" : ""
                            color: card.limit && card.usedToday >= card.limit.bytes ? view.theme.danger : view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
                Sparkline {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 26
                    visible: view.width > 820
                    theme: view.theme
                    seriesIn: (page.net.appSeries[card.app.key] || {})["in"] || []
                    seriesOut: (page.net.appSeries[card.app.key] || {}).out || []
                    capacity: page.net.seriesSize
                }
                Column {
                    Layout.preferredWidth: 110
                    Text {
                        anchors.right: parent.right
                        text: "↓ " + Format.speed(card.app.rateIn)
                        color: card.app.rateIn > 0 ? view.theme.rx : view.theme.dim
                        font.family: view.theme.fontFamily
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        text: "↑ " + Format.speed(card.app.rateOut)
                        color: card.app.rateOut > 0 ? view.theme.tx : view.theme.dim
                        font.family: view.theme.fontFamily
                        font.pixelSize: 11
                    }
                }
                Text {
                    Layout.preferredWidth: 150
                    horizontalAlignment: Text.AlignRight
                    text: card.app.bytesIn + card.app.bytesOut > 0 ? Format.bytes(card.app.bytesIn) + " in · " + Format.bytes(card.app.bytesOut) + " out" : "UDP / no counters"
                    color: view.theme.muted
                    font.family: view.theme.fontFamily
                    font.pixelSize: 10
                }
                NetButton {
                    id: menuButton
                    theme: view.theme
                    text: "⋯"
                    tooltip: "Actions"
                    activeFocusOnTab: false
                    onClicked: page.showActions(null, card.app.pid, card.app.name, menuButton, card.app)
                }
            }
        }

        RateChart {
            id: appChart
            visible: card.open
            x: 46
            y: head.height
            width: parent.width - 60
            height: card.open ? 110 : 0
            theme: view.theme
            seriesIn: (page.net.appSeries[card.app.key] || {})["in"] || []
            seriesOut: (page.net.appSeries[card.app.key] || {}).out || []
            capacity: page.net.seriesSize
        }
        Column {
            id: conns
            y: head.height + appChart.height + 8
            x: 12
            width: parent.width - 24
            visible: card.open
            spacing: 2
            Repeater {
                model: card.open ? card.app.conns : []
                Rectangle {
                    id: connRow
                    required property var modelData
                    readonly property var c: modelData
                    readonly property var info: page.hostOf(c)
                    width: conns.width
                    height: 30
                    radius: 6
                    color: rowArea.containsMouse ? view.theme.hover : "transparent"
                    opacity: c.ended ? 0.45 : 1
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: page.showActions(connRow.c, connRow.c.pid, connRow.c.proc || card.app.name, connRow)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 34
                        anchors.rightMargin: 8
                        spacing: 10
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: connRow.c.ended ? view.theme.dim : page.kindColor(connRow.c.kind)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (connRow.info.site || connRow.info.host || connRow.c.ip) + (connRow.info.site || connRow.info.host ? "  " : "")
                            color: view.theme.text
                            elide: Text.ElideMiddle
                            font.family: view.theme.fontFamily
                            font.pixelSize: 11
                            Text {
                                x: parent.contentWidth + 2
                                anchors.baseline: parent.baseline
                                visible: (connRow.info.site || connRow.info.host) !== "" && x + implicitWidth < parent.width
                                text: connRow.info.site ? "tab · " + connRow.info.siteTitle + (connRow.info.siteMore ? " (+" + connRow.info.siteMore + ")" : "") : connRow.c.ip
                                color: connRow.info.site ? view.theme.brand : view.theme.dim
                                font.family: connRow.info.site ? view.theme.fontFamily : "monospace"
                                elide: Text.ElideRight
                                width: Math.max(0, parent.width - x)
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            Layout.preferredWidth: 52
                            text: ":" + connRow.c.port
                            color: view.theme.muted
                            font.family: "monospace"
                            font.pixelSize: 10
                        }
                        NetBadge {
                            Layout.preferredWidth: 34
                            theme: view.theme
                            text: connRow.c.proto.toUpperCase()
                            tint: connRow.c.proto === "tcp" ? view.theme.rx : view.theme.ok
                        }
                        Row {
                            Layout.preferredWidth: 60
                            spacing: 4
                            Flag {
                                anchors.verticalCenter: parent.verticalCenter
                                country: connRow.info.country
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: connRow.info.country || Probes.ADDRESS_LABELS[connRow.c.kind]
                                color: view.theme.muted
                                font.family: view.theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            Layout.preferredWidth: 64
                            text: connRow.c.state
                            color: view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.preferredWidth: 150
                            horizontalAlignment: Text.AlignRight
                            text: connRow.c.bytesIn === null ? "–" : "↓ " + Format.bytes(connRow.c.bytesIn) + "  ↑ " + Format.bytes(connRow.c.bytesOut)
                            color: view.theme.muted
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                        Text {
                            Layout.preferredWidth: 70
                            horizontalAlignment: Text.AlignRight
                            text: page.since(connRow.c)
                            color: view.theme.dim
                            font.family: view.theme.fontFamily
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
