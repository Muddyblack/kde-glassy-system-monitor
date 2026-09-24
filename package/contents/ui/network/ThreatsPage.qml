import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "Threats.js" as Threats
import "NetModel.js" as NetModel

// What looks dangerous: checks on this machine, and (opt-in) public
// blocklists matched locally. Hints for a closer look, never a verdict:
// Glassy blocks nothing.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var watch: page.service.threats
    readonly property var rows: {
        const q = page.query.trim().toLowerCase();
        return watch.findings.filter(f => !q || [f.title, f.detail, f.app.name].some(v => String(v).toLowerCase().indexOf(q) !== -1));
    }
    readonly property int columns: width > 900 ? 4 : 2
    function levelColor(level) {
        return level === "high" ? theme.danger : level === "medium" ? theme.warn : level === "low" ? theme.rx : theme.dim;
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
        spacing: 14

        GridLayout {
            Layout.fillWidth: true
            columns: view.columns
            columnSpacing: 14
            rowSpacing: 14
            Repeater {
                model: Threats.LEVELS
                NetCard {
                    id: stat
                    required property string modelData
                    readonly property int n: view.watch.counts[modelData]
                    theme: view.theme
                    title: Threats.LEVEL_LABELS[modelData]
                    fill: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    Text {
                        text: String(stat.n)
                        color: stat.n > 0 ? view.levelColor(stat.modelData) : view.theme.dim
                        font.family: view.theme.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        NetCard {
            theme: view.theme
            title: "Findings"
            subtitle: page.net.connections.filter(c => !c.ended).length + " connections · " + page.net.listening.length + " listening sockets · " + Object.keys(view.watch.exes).length + " programs checked"
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 2

                Text {
                    visible: view.rows.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    text: page.query ? "Nothing matches the search" : "✓ Nothing suspicious right now"
                    color: page.query ? view.theme.dim : view.theme.ok
                    font.family: view.theme.fontFamily
                    font.pixelSize: 13
                }

                Repeater {
                    model: view.rows
                    Rectangle {
                        id: row
                        required property var modelData
                        readonly property var f: modelData
                        readonly property bool ended: !!f.conn && f.conn.ended
                        Layout.fillWidth: true
                        implicitHeight: rowLayout.implicitHeight + 14
                        radius: 8
                        color: rowArea.containsMouse ? view.theme.hover : "transparent"
                        opacity: ended ? 0.6 : 1
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.showActions(row.f.conn, row.f.pid, row.f.app.name, row, row.f.app.key === "?" ? null : row.f.app)
                        }
                        RowLayout {
                            id: rowLayout
                            x: 8
                            width: parent.width - 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            NetBadge {
                                Layout.preferredWidth: 58
                                theme: view.theme
                                text: Threats.LEVEL_LABELS[row.f.level].toUpperCase()
                                tint: view.levelColor(row.f.level)
                            }
                            AppIcon {
                                theme: view.theme
                                size: 22
                                iconName: row.f.app.icon
                                name: row.f.app.name
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: row.f.title + (row.f.count > 1 ? "  ×" + row.f.count : "")
                                    color: view.theme.text
                                    font.family: view.theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: row.f.detail
                                    color: view.theme.muted
                                    font.family: view.theme.fontFamily
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }
                            Repeater {
                                model: row.f.lists
                                NetBadge {
                                    required property string modelData
                                    theme: view.theme
                                    text: Threats.list(modelData).name.toUpperCase()
                                    tint: view.levelColor(Threats.list(modelData).level)
                                }
                            }
                            NetBadge {
                                visible: row.ended
                                theme: view.theme
                                text: "ENDED"
                            }
                            Text {
                                text: "⋯"
                                color: view.theme.dim
                                font.pixelSize: 16
                            }
                        }
                    }
                }
            }
        }

        // The opt-in part: public lists, matched on this machine.
        NetCard {
            theme: view.theme
            title: "Blocklists"
            subtitle: !view.watch.listsOn ? "off" : view.watch.downloading ? "downloading…" : view.watch.listsTime > 0 ? view.watch.entries.toLocaleString(Qt.locale(), "f", 0) + " entries · updated " + NetModel.duration(Math.max(page.now, Date.now()) - view.watch.listsTime) + " ago" : "none downloaded yet"
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: view.watch.listsOn ? "Addresses and sites are checked against these lists on this machine. They are downloaded once a day while this is on; nothing about your connections is sent anywhere." : "Off: only the checks on this machine run, and Glassy downloads nothing. On, it fetches public lists of botnet servers, malware sites and hijacked networks (under 1 MB, once a day) from abuse.ch, Spamhaus, Emerging Threats and IPsum, and checks against them locally. Turning it off deletes them."
                        color: view.theme.muted
                        font.family: view.theme.fontFamily
                        font.pixelSize: 11
                    }
                    NetSeg {
                        theme: view.theme
                        options: [[false, "Off"], [true, "On"]]
                        value: view.watch.listsOn
                        enabled: !page.net.demo
                        onActivated: v => view.watch.setListsOn(v)
                    }
                }

                Repeater {
                    model: view.watch.listsOn ? Threats.LISTS : []
                    RowLayout {
                        id: listRow
                        required property var modelData
                        readonly property bool on: view.watch.ids.indexOf(modelData.id) !== -1
                        readonly property var entry: view.watch.index[modelData.id]
                        Layout.fillWidth: true
                        spacing: 12
                        NetButton {
                            Layout.preferredWidth: 30
                            theme: view.theme
                            text: listRow.on ? "✓" : ""
                            checked: listRow.on
                            tooltip: listRow.on ? "Stop using this list" : "Use this list"
                            onClicked: view.watch.setList(listRow.modelData.id, !listRow.on)
                        }
                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: listRow.modelData.name + "  ·  " + listRow.modelData.by
                                color: listRow.on ? view.theme.text : view.theme.dim
                                font.family: view.theme.fontFamily
                                font.pixelSize: 12
                            }
                            Text {
                                text: listRow.modelData.what + (listRow.entry ? " · " + listRow.entry.count.toLocaleString(Qt.locale(), "f", 0) + (listRow.entry.count === 1 ? " entry" : " entries") : listRow.on ? " · not downloaded yet" : "")
                                color: view.theme.dim
                                font.family: view.theme.fontFamily
                                font.pixelSize: 10
                            }
                        }
                        NetBadge {
                            theme: view.theme
                            text: Threats.LEVEL_LABELS[listRow.modelData.level].toUpperCase()
                            tint: view.levelColor(listRow.modelData.level)
                        }
                    }
                }

                RowLayout {
                    visible: view.watch.listsOn
                    Layout.fillWidth: true
                    spacing: 12
                    NetButton {
                        theme: view.theme
                        text: view.watch.downloading ? "Downloading…" : "Update now"
                        enabled: !view.watch.downloading && !page.net.demo
                        onClicked: view.watch.download()
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: view.watch.error || "Into ~/.local/share/glassy-system-monitor/threats"
                        color: view.watch.error ? view.theme.warn : view.theme.dim
                        font.family: view.theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Hints, not verdicts: an address on a list can be shared hosting or passed on to someone new, and a program runs from a deleted file after every update until it restarts. Click a finding for whois, Wireshark, trust or ending the process. Trusted apps only show up when they are on a list."
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 10
        }
    }
}
