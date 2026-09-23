import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "NetHistory.js" as NetHistory

// Traffic over time, recorded while the widget runs (with "Record" on
// "Always", also while this window is closed): a day by hour, a week or a
// month by day, a year or everything by month. ◀ ▶ step through time, a
// click on a bar opens it. Settings for recording and keeping are here too.
Flickable {
    id: view
    required property var page
    readonly property var theme: page.theme
    readonly property var service: page.service
    property string kind: "week"
    property real anchor: Date.now()
    readonly property var p: {
        service.historyRevision;
        return NetHistory.period(service.history, kind, anchor, Date.now());
    }
    readonly property var s: {
        service.historyRevision;
        return NetHistory.summarize(service.history, p.keys);
    }
    readonly property int columns: width > 1100 ? 4 : width > 760 ? 2 : 1
    readonly property string status: {
        if (service.historyError !== "")
            return service.historyError;
        if (service.recordMode === "off")
            return "Recording is off.";
        if (service.monitor.demo)
            return "Demo history";
        const where = service.persist ? "saved" : "in memory only (gone after a restart)";
        if (service.recording)
            return "Recording" + (service.recordMode === "window" ? " while this window is open" : service.windowOpen ? "" : " in the background") + " · " + where + (service.historyFromBackup ? " · restored from a backup copy" : "");
        return service.recordMode === "window" ? "Records while this window is open." : "Another Glassy widget records the history; this one shows it.";
    }
    function go(k, a) {
        kind = k;
        anchor = a === undefined ? Date.now() : a;
    }

    contentHeight: grid.implicitHeight + 36
    clip: true
    activeFocusOnTab: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: Controls.ScrollBar {}
    Keys.onUpPressed: flick(0, 800)
    Keys.onDownPressed: flick(0, -800)
    Keys.onLeftPressed: if (kind !== "all")
        anchor = NetHistory.shift(kind, anchor, -1)
    Keys.onRightPressed: if (p.canForward)
        anchor = NetHistory.shift(kind, anchor, 1)

    GridLayout {
        id: grid
        x: 18
        y: 18
        width: view.width - 36
        columns: view.columns
        columnSpacing: 14
        rowSpacing: 14

        // Period, stepping, recording and keeping.
        Flow {
            Layout.columnSpan: view.columns
            Layout.fillWidth: true
            spacing: 8
            NetSeg {
                theme: view.theme
                options: [["day", "Day"], ["week", "Week"], ["month", "Month"], ["year", "Year"], ["all", "All time"]]
                value: view.kind
                onActivated: v => view.go(v, view.anchor)
            }
            NetButton {
                theme: view.theme
                text: "◀"
                enabled: view.kind !== "all"
                tooltip: "Earlier (←)"
                onClicked: view.anchor = NetHistory.shift(view.kind, view.anchor, -1)
            }
            Text {
                height: 28
                verticalAlignment: Text.AlignVCenter
                text: view.p.title
                color: view.theme.text
                font.family: view.theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            NetButton {
                theme: view.theme
                text: "▶"
                enabled: view.p.canForward
                tooltip: "Later (→)"
                onClicked: view.anchor = NetHistory.shift(view.kind, view.anchor, 1)
            }
            NetButton {
                theme: view.theme
                text: "Now"
                onClicked: view.go(view.kind)
            }
            Item {
                width: 16
                height: 1
            }
            NetSelect {
                theme: view.theme
                options: [["on", "Record: always"], ["window", "Record: while open"], ["off", "Record: off"]]
                value: view.service.recordMode
                onChosen: v => view.service.saveState({
                        record: v
                    })
            }
            NetSelect {
                theme: view.theme
                options: [["session", "Keep: memory only"], ["30d", "Keep: 30 days"], ["90d", "Keep: 90 days"], ["1y", "Keep: 1 year"], ["2y", "Keep: 2 years"], ["all", "Keep: forever"]]
                value: view.service.keep
                onChosen: v => v === "session" && view.service.keep !== "session" ? sessionConfirm.open() : view.service.saveState({
                        keep: v
                    })
            }
            NetButton {
                theme: view.theme
                text: "Clear…"
                enabled: view.service.historyWritable
                onClicked: clearConfirm.open()
            }
        }
        Text {
            Layout.columnSpan: view.columns
            Layout.fillWidth: true
            text: view.status
            color: view.service.historyError !== "" ? view.theme.warn : view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        NetButton {
            Layout.columnSpan: view.columns
            visible: view.service.historyError !== "" && !view.service.historyWritable
            theme: view.theme
            text: "Start a new history"
            tooltip: "The unreadable files are kept as ….json.broken-<time>"
            onClicked: view.service.startFresh()
        }

        NetCard {
            theme: view.theme
            title: view.kind === "day" ? "By hour" : view.kind === "week" || view.kind === "month" ? "By day" : "By month"
            subtitle: "↓ " + Format.bytes(view.s.total["in"]) + "   ↑ " + Format.bytes(view.s.total.out) + "   · " + view.s.total.conns + " connections · " + view.s.total.days + (view.s.total.days === 1 ? " day recorded" : " days recorded")
            fill: true
            Layout.columnSpan: view.columns
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            DayBars {
                anchors.fill: parent
                theme: view.theme
                entries: view.p.buckets
                onActivated: index => {
                    const d = view.p.buckets[index].drill;
                    if (d)
                        view.go(d.kind, d.anchor);
                }
            }
            Text {
                anchors.centerIn: parent
                visible: view.kind === "day" && view.s.total.days > 0 && !(view.service.history.days[view.p.keys[0]] || {}).hours
                text: "Hours are kept for the last " + NetHistory.FULL_DAYS + " days; older days keep their totals."
                color: view.theme.dim
                font.family: view.theme.fontFamily
                font.pixelSize: 11
            }
        }

        NetCard {
            theme: view.theme
            title: "Apps"
            subtitle: "bytes in + out"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                rows: view.s.apps.slice(0, 8).map(a => ({
                            label: a.name,
                            icon: a.icon,
                            value: a["in"] + a.out,
                            text: "↓ " + Format.bytes(a["in"]) + "  ↑ " + Format.bytes(a.out)
                        }))
                empty: "Nothing recorded here"
            }
        }
        NetCard {
            theme: view.theme
            title: "Domains"
            subtitle: "tab sites, else reverse DNS"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                rows: view.s.domains.slice(0, 8).map(d => ({
                            label: d.key,
                            value: d["in"] + d.out,
                            text: Format.bytes(d["in"] + d.out)
                        }))
                empty: "Nothing recorded here"
            }
        }
        NetCard {
            theme: view.theme
            title: "Countries"
            subtitle: "local GeoIP"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                rows: view.s.countries.slice(0, 8).map(c => ({
                            label: c.key,
                            flag: c.key,
                            value: c["in"] + c.out,
                            text: Format.bytes(c["in"] + c.out)
                        }))
                empty: "Needs a local GeoIP database"
            }
        }
        // #9: what each link carried (metered and mobile connections).
        NetCard {
            theme: view.theme
            title: "Interfaces"
            subtitle: "all traffic, per link"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            TopList {
                width: parent.width
                theme: view.theme
                rows: view.s.ifaces.slice(0, 8).map(i => ({
                            label: i.key,
                            value: i["in"] + i.out,
                            text: "↓ " + Format.bytes(i["in"]) + "  ↑ " + Format.bytes(i.out)
                        }))
                empty: "Recorded from now on"
            }
        }
        Text {
            Layout.columnSpan: view.columns
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Kept in ~/.local/share/glassy-system-monitor/ (private to you): one file per month plus today's, with a backup of each. " + view.s.recorded + " days recorded. Updates, plasmashell restarts and layout rebuilds leave them alone. Totals count the physical links; per-app bytes are TCP (UDP has no per-socket counters without root)."
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 10
        }
    }

    component Confirm: Controls.Popup {
        id: dialog
        property string title: ""
        property string text: ""
        property string action: ""
        signal accepted
        parent: view.page
        anchors.centerIn: parent
        modal: true
        padding: 20
        width: 380
        background: Rectangle {
            radius: 14
            color: view.theme.popup
            border.color: view.theme.line2
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                text: dialog.title
                color: view.theme.text
                font.family: view.theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: dialog.text
                color: view.theme.muted
                font.family: view.theme.fontFamily
                font.pixelSize: 11
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                NetButton {
                    theme: view.theme
                    text: "Cancel"
                    onClicked: dialog.close()
                }
                NetButton {
                    theme: view.theme
                    primary: true
                    danger: true
                    text: dialog.action
                    onClicked: {
                        dialog.accepted();
                        dialog.close();
                    }
                }
            }
        }
    }
    Confirm {
        id: clearConfirm
        title: "Clear the traffic history?"
        text: "Every recorded day goes, and every history file with it."
        action: "Clear history"
        onAccepted: view.service.clearHistory()
    }
    Confirm {
        id: sessionConfirm
        title: "Keep the history in memory only?"
        text: "Nothing is saved any more, and what was saved is deleted now. Recording goes on until the widget restarts."
        action: "Stop saving"
        onAccepted: view.service.stopSaving()
    }
}
