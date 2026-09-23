import QtQuick
import Quickshell
import "../package/contents/ui" as Shared

// Bar module for a Quickshell bar: the panel pill, and the full card as a
// popup while it is hovered. A click keeps the card open until the next one.
// Give it the core from GlassyShell, or its own MonitorCore:
//     MonitorPill { monitor: core; cfg: core.cfg; onActivated: … }
Item {
    id: pill

    required property var monitor
    required property var cfg
    // Set in a vertical bar.
    property bool vertical: false
    // Which bar edge the card opens away from.
    property int popupEdge: Edges.Bottom
    property bool pinned: false
    signal activated

    implicitWidth: compact.implicitWidth
    implicitHeight: compact.implicitHeight

    // The core reads the pill's sections too, not only the card's.
    Binding {
        target: pill.monitor
        property: "inPanel"
        value: true
    }

    Shared.CompactRepresentation {
        id: compact
        anchors.fill: parent
        monitor: pill.monitor
        cfg: pill.cfg
        vertical: pill.vertical
        onActivated: {
            pill.pinned = !pill.pinned;
            pill.activated();
        }
    }

    // Brief grace period, so moving from the pill to the card keeps it open.
    Timer {
        id: linger
        interval: 250
    }
    readonly property bool hovering: compact.hovered || cardHover.hovered
    onHoveringChanged: if (!hovering)
        linger.restart()

    PopupWindow {
        visible: pill.cfg.panelHoverCard !== false && (pill.pinned || pill.hovering || linger.running)
        anchor.item: pill
        anchor.edges: pill.popupEdge
        anchor.gravity: pill.popupEdge
        anchor.margins.top: 6
        anchor.margins.bottom: 6
        anchor.margins.left: 6
        anchor.margins.right: 6
        implicitWidth: card.preferredWidth
        implicitHeight: card.preferredHeight
        color: "transparent"

        Shared.MonitorView {
            id: card
            anchors.fill: parent
            monitor: pill.monitor
            cfg: pill.cfg
            HoverHandler {
                id: cardHover
            }
        }
    }
}
