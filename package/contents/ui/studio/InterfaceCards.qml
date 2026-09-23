import QtQuick
import "Theme.js" as Theme
import "../Format.js" as Format
import "../Probes.js" as Probes

// Network › Interface: one card per interface (kind, state, address, live
// rates) plus Automatic, which shows where the default route goes now.
Flow {
    id: cards
    required property var studio
    property var value
    signal chosen(var value)

    readonly property var monitor: studio.liveMonitor
    readonly property var interfaces: {
        const m = monitor;
        if (m && m.interfaces && m.interfaces.length)
            return m.interfaces;
        // Before the first enumeration: the names /proc/net/dev lists.
        return (m ? m.availableIfaces : []).filter(n => n !== "auto").map(n => ({
                    name: n,
                    kind: "other",
                    up: true,
                    ip: "",
                    speed: 0,
                    mac: "",
                    route: -1
                }));
    }
    readonly property string current: String(value || "auto")
    readonly property var options: {
        const list = [
            {
                name: "auto",
                auto: true
            }
        ].concat(interfaces);
        if (current !== "auto" && !interfaces.some(i => i.name === current))
            list.push({
                name: current,
                missing: true
            });
        return list;
    }
    readonly property int columns: Math.max(1, Math.floor((width + 8) / 188))
    readonly property real cardWidth: (width - (columns - 1) * 8) / columns
    spacing: 8

    Repeater {
        model: cards.options
        Rectangle {
            id: card
            required property var modelData
            readonly property var i: modelData
            readonly property bool pressed: cards.current === i.name
            readonly property var rate: cards.monitor && cards.monitor.ifaceRates ? cards.monitor.ifaceRates[i.auto ? (cards.monitor.autoIface || "") : i.name] : null
            objectName: "iface_" + i.name
            width: cards.cardWidth
            height: 78
            radius: 12
            color: Theme.sunk
            border.width: 1
            border.color: pressed ? Theme.tileSelectedBorder : area.containsMouse ? Theme.tileHoverBorder : Theme.line2
            gradient: pressed ? pressedGradient : null
            opacity: i.missing || (!i.auto && !i.up) ? 0.55 : 1
            Gradient {
                id: pressedGradient
                GradientStop {
                    position: 0
                    color: Theme.chipPressed
                }
                GradientStop {
                    position: 1
                    color: Theme.panelBottom
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 15
                visible: card.pressed
                color: "transparent"
                border.width: 3
                border.color: Theme.tileSelectedRing
            }
            Column {
                x: 12
                y: 10
                width: parent.width - 24
                spacing: 3
                Row {
                    width: parent.width
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: card.i.auto ? Theme.brand : card.i.up ? Theme.ok : Theme.dim
                    }
                    Text {
                        width: parent.width - 13
                        text: card.i.auto ? "Automatic" : card.i.name
                        color: card.pressed ? Theme.text : Theme.outputText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
                Text {
                    width: parent.width
                    text: card.i.auto ? "Default route" + (cards.monitor && cards.monitor.autoIface ? " · " + cards.monitor.autoIface : "") : card.i.missing ? "Not found" : [Probes.KIND_LABELS[card.i.kind] || "Other", card.i.up ? card.i.ip : "down", card.i.speed > 0 ? (card.i.speed >= 1000 ? card.i.speed / 1000 + " Gbit/s" : card.i.speed + " Mbit/s") : ""].filter(Boolean).join(" · ")
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: !!card.rate
                    text: card.rate ? "↓ " + Format.speed(card.rate.rx) + "   ↑ " + Format.speed(card.rate.tx) : ""
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cards.chosen(card.i.name)
            }
        }
    }
}
