import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../Format.js" as Format
import "../Probes.js" as Probes
import "NetModel.js" as NetModel

// Every connection in one sortable table; ended ones greyed at the end.
Item {
    id: view
    required property var page
    readonly property var theme: page.theme
    property string sortColumn: "rate"
    property bool descending: true
    readonly property var rows: NetModel.sorted(page.filtered, sortColumn, descending, page.net.hosts)

    // Column widths: fixed, or a share of what is left ("flex"). Narrow
    // windows drop the columns with `below` first.
    readonly property var columns: [
        {
            id: "app",
            label: "App",
            w: 170
        },
        {
            id: "domain",
            label: "Domain",
            flex: 1
        },
        {
            id: "ip",
            label: "IP",
            w: 190,
            below: 1040
        },
        {
            id: "port",
            label: "Port",
            w: 58
        },
        {
            id: "proto",
            label: "Proto",
            w: 52
        },
        {
            id: "direction",
            label: "Dir",
            w: 44,
            below: 1100
        },
        {
            id: "state",
            label: "State",
            w: 84,
            below: 1270
        },
        {
            id: "country",
            label: "Country",
            w: 72,
            geo: true
        },
        {
            id: "bytes",
            label: "In / out",
            w: 150,
            below: 840
        },
        {
            id: "rate",
            label: "Rate",
            w: 92
        },
        {
            id: "rtt",
            label: "RTT",
            w: 62,
            below: 1400
        },
        {
            id: "via",
            label: "Via",
            w: 76,
            below: 1480
        },
        {
            id: "since",
            label: "Since",
            w: 70,
            below: 1190
        }
    ].filter(c => (!c.geo || page.net.geo.country) && !(view.width < (c.below || 0)))
    readonly property real flexWidth: Math.max(140, list.width - 36 - columns.reduce((a, c) => a + (c.w || 0), 0) - 10 * columns.length)
    function widthOf(c) {
        return c.flex ? flexWidth : c.w;
    }
    function sortBy(id) {
        if (sortColumn === id)
            descending = !descending;
        else {
            sortColumn = id;
            descending = ["bytes", "rate", "since"].indexOf(id) !== -1;
        }
    }
    onActiveFocusChanged: if (activeFocus)
        list.forceActiveFocus()

    Rectangle {
        id: head
        width: parent.width
        height: 32
        color: view.theme.panelBottom
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: view.theme.line2
        }
        Row {
            x: 18
            height: parent.height
            spacing: 10
            Repeater {
                model: view.columns
                Item {
                    id: col
                    required property var modelData
                    width: view.widthOf(modelData)
                    height: parent.height
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        horizontalAlignment: ["bytes", "rate", "since", "rtt"].indexOf(col.modelData.id) !== -1 ? Text.AlignRight : Text.AlignLeft
                        text: col.modelData.label + (view.sortColumn === col.modelData.id ? (view.descending ? " ▾" : " ▴") : "")
                        color: view.sortColumn === col.modelData.id ? view.theme.text : view.theme.muted
                        font.family: view.theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sortBy(col.modelData.id)
                    }
                }
            }
        }
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        model: KeyedModel {
            rows: view.rows
        }
        clip: true
        activeFocusOnTab: true
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        reuseItems: true
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        readonly property var current: currentIndex >= 0 && currentIndex < view.rows.length ? view.rows[currentIndex] : null
        Keys.onMenuPressed: if (current)
            page.showActions(current, current.pid, current.proc || current.app.name, currentItem)
        Keys.onReturnPressed: if (current)
            page.showActions(current, current.pid, current.proc || current.app.name, currentItem)
        Keys.onDeletePressed: if (current)
            page.askKill(current.pid, current.proc)
        Keys.onPressed: event => {
            if (event.matches(StandardKey.Copy) && current) {
                page.copy(current.ip);
                event.accepted = true;
            }
        }

        Text {
            anchors.centerIn: parent
            visible: list.count === 0
            text: page.filtering ? "No connection matches the filters" : "No connections"
            color: view.theme.dim
            font.family: view.theme.fontFamily
            font.pixelSize: 12
        }

        delegate: Rectangle {
            id: rowItem
            required property var row
            required property int index
            readonly property var c: row
            readonly property var info: page.hostOf(c)
            readonly property bool current: ListView.isCurrentItem && list.activeFocus
            width: list.width
            height: 30
            color: current ? view.theme.selected : rowArea.containsMouse ? view.theme.hover : index % 2 ? view.theme.card : "transparent"
            opacity: c.ended ? 0.45 : 1
            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    list.currentIndex = rowItem.index;
                    list.forceActiveFocus();
                    if (mouse.button === Qt.RightButton)
                        page.showActions(rowItem.c, rowItem.c.pid, rowItem.c.proc || rowItem.c.app.name, rowItem);
                }
                onDoubleClicked: page.showActions(rowItem.c, rowItem.c.pid, rowItem.c.proc || rowItem.c.app.name, rowItem)
            }
            Row {
                x: 18
                height: parent.height
                spacing: 10
                Repeater {
                    model: view.columns
                    Item {
                        id: cell
                        required property var modelData
                        readonly property string columnId: modelData.id
                        width: view.widthOf(modelData)
                        height: rowItem.height
                        Row {
                            visible: cell.columnId === "app"
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            AppIcon {
                                theme: view.theme
                                size: 16
                                iconName: rowItem.c.app.icon
                                name: rowItem.c.app.name
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: cell.width - 24
                                text: rowItem.c.app.name
                                color: view.theme.text
                                elide: Text.ElideRight
                                font.family: view.theme.fontFamily
                                font.pixelSize: 11
                            }
                        }
                        NetBadge {
                            visible: cell.columnId === "domain" && rowItem.info.site !== ""
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            theme: view.theme
                            text: rowItem.info.siteMore ? "TAB +" + rowItem.info.siteMore : "TAB"
                            tint: view.theme.brand
                        }
                        Flag {
                            visible: cell.columnId === "country"
                            anchors.verticalCenter: parent.verticalCenter
                            country: rowItem.info.country
                        }
                        NetBadge {
                            visible: cell.columnId === "proto" || cell.columnId === "direction"
                            anchors.verticalCenter: parent.verticalCenter
                            theme: view.theme
                            text: cell.columnId === "proto" ? rowItem.c.proto.toUpperCase() : rowItem.c.direction === "in" ? "IN" : "OUT"
                            tint: cell.columnId === "proto" ? (rowItem.c.proto === "tcp" ? view.theme.rx : view.theme.ok) : rowItem.c.direction === "in" ? view.theme.warn : view.theme.muted
                        }
                        Text {
                            visible: ["app", "proto", "direction"].indexOf(cell.columnId) === -1
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            leftPadding: cell.columnId === "country" && rowItem.info.country ? 20 : 0
                            rightPadding: cell.columnId === "domain" && rowItem.info.site ? 44 : 0
                            elide: cell.columnId === "domain" ? Text.ElideLeft : Text.ElideRight
                            horizontalAlignment: ["bytes", "rate", "since", "rtt"].indexOf(cell.columnId) !== -1 ? Text.AlignRight : Text.AlignLeft
                            font.family: cell.columnId === "ip" || cell.columnId === "port" ? "monospace" : view.theme.fontFamily
                            font.pixelSize: cell.columnId === "ip" || cell.columnId === "port" ? 10 : 11
                            color: {
                                switch (cell.columnId) {
                                case "domain":
                                    return rowItem.info.site ? view.theme.brand : rowItem.info.host ? view.theme.text : view.theme.dim;
                                case "ip":
                                    return page.kindColor(rowItem.c.kind);
                                case "rate":
                                    return rowItem.c.rateIn + rowItem.c.rateOut > 0 ? view.theme.text : view.theme.dim;
                                case "via":
                                    return page.net.vpns.some(v => v.iface === rowItem.c.via) ? view.theme.ok : view.theme.muted;
                                case "rtt":
                                    return rowItem.c.rtt > 150 ? view.theme.warn : view.theme.muted;
                                }
                                return view.theme.muted;
                            }
                            text: {
                                switch (cell.columnId) {
                                case "domain":
                                    return rowItem.info.site || rowItem.info.host || (rowItem.c.kind === "internet" ? "—" : Probes.ADDRESS_LABELS[rowItem.c.kind]);
                                case "ip":
                                    return rowItem.c.ip + (rowItem.c.scope ? "%" + rowItem.c.scope : "");
                                case "port":
                                    return rowItem.c.port;
                                case "state":
                                    return rowItem.c.state;
                                case "country":
                                    return rowItem.info.country;
                                case "bytes":
                                    return rowItem.c.bytesIn === null ? "–" : Format.bytes(rowItem.c.bytesIn) + " / " + Format.bytes(rowItem.c.bytesOut);
                                case "rate":
                                    return rowItem.c.ended ? "ended" : Format.speed(rowItem.c.rateIn + rowItem.c.rateOut);
                                case "since":
                                    return page.since(rowItem.c);
                                case "rtt":
                                    return rowItem.c.rtt === null || rowItem.c.rtt === undefined ? "" : rowItem.c.rtt.toFixed(rowItem.c.rtt < 10 ? 1 : 0) + " ms";
                                case "via":
                                    return rowItem.c.via || "";
                                }
                                return "";
                            }
                        }
                    }
                }
            }
        }
    }
}
