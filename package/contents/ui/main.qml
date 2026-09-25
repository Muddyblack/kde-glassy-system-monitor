import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "network" as Network

// Plasma host: hands KConfig, the executable engine and the theme to the
// shared MonitorCore, and shows MonitorView (desktop) or the pill (panel).
PlasmoidItem {
    id: root

    readonly property bool isInPanel: plasmoid.configuration.panelMode || [PlasmaCore.Types.TopEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge].indexOf(Plasmoid.location) !== -1
    property bool fullShown: false
    // The hover card lives in Plasma's tooltip window while it is open.
    readonly property bool hoverShown: !!hoverCard.Window.window && hoverCard.Window.window.visible

    // Hovering the pill shows the card as its tooltip; a click opens it as
    // the popup, which stays until closed.
    toolTipItem: isInPanel && plasmoid.configuration.panelHoverCard ? hoverCard : null
    // Not a child of the applet: the tooltip window takes it when it opens.
    property Item hoverCard: MonitorView {
        monitor: core
        cfg: plasmoid.configuration
        width: preferredWidth
        height: preferredHeight
        implicitWidth: preferredWidth
        implicitHeight: preferredHeight
        Layout.minimumWidth: preferredWidth
        Layout.minimumHeight: preferredHeight
        Layout.preferredWidth: preferredWidth
        Layout.preferredHeight: preferredHeight
    }

    preferredRepresentation: isInPanel ? compactRepresentation : fullRepresentation
    // Plasma's own blur behind glass, when asked for; otherwise no frame.
    Plasmoid.backgroundHints: plasmoid.configuration.compositorGlass && ["glass", "liquid"].indexOf(plasmoid.configuration.surfaceStyle) !== -1 ? "TranslucentBackground" : "NoBackground"

    // The desktop wallpaper is a separate scene item, safe for glass to
    // sample; panel popups live in another window and get none.
    readonly property Item desktopWallpaper: {
        if (isInPanel)
            return null;
        for (let item = root.parent; item; item = item.parent)
            if (item instanceof ContainmentItem)
                return item.wallpaper;
        return null;
    }

    MonitorCore {
        id: core
        cfg: plasmoid.configuration
        commandSourceComponent: Component {
            P5Support.DataSource {
                engine: "executable"
            }
        }
        writeConfig: (key, value) => plasmoid.configuration[key] = value
        onScreen: root.fullShown || root.hoverShown
        active: root.visible
        inPanel: root.isInPanel
        systemAccent: Kirigami.Theme.highlightColor
        systemTextColor: Kirigami.Theme.textColor
    }

    compactRepresentation: CompactRepresentation {
        monitor: core
        cfg: plasmoid.configuration
        inPanel: root.isInPanel
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        // Across a horizontal panel the pill sets the width; down a vertical
        // one, the height.
        Layout.minimumWidth: vertical ? -1 : implicitWidth
        Layout.preferredWidth: vertical ? -1 : implicitWidth
        Layout.minimumHeight: vertical ? implicitHeight : -1
        Layout.preferredHeight: vertical ? implicitHeight : -1
        onActivated: root.expanded = !root.expanded
    }

    fullRepresentation: MonitorView {
        id: view
        monitor: core
        cfg: plasmoid.configuration
        backdrop: root.desktopWallpaper
        // Plasma never sizes the card below what its sections need.
        Layout.minimumWidth: minimumWidth
        Layout.minimumHeight: minimumHeight
        // The desktop grows a widget to its preferred size whenever that hint
        // changes (it does on every load), overriding the size the user gave
        // it. There the preferred size is just the minimum; the popup keeps
        // the roomier one.
        Layout.preferredWidth: root.isInPanel ? preferredWidth : minimumWidth
        Layout.preferredHeight: root.isInPanel ? preferredHeight : minimumHeight
        // In a panel this is created on first expand and then only hidden, so
        // visibility, not existence, says whether anything is worth drawing.
        onVisibleChanged: root.fullShown = visible
        Component.onCompleted: root.fullShown = visible
        Component.onDestruction: root.fullShown = false
    }

    // The network window: a normal top-level window (own taskbar entry),
    // created when the network section's "window" link is clicked and
    // destroyed when it closes. The service outlives it: it keeps the saved
    // state and, with the history on, records traffic in the background.
    Network.NetworkService {
        id: networkService
        commandSourceComponent: Component {
            P5Support.DataSource {
                engine: "executable"
            }
        }
        windowOpen: networkWindow.active
        pillActive: core.showNetApps
    }
    Binding {
        target: core
        property: "netApps"
        value: networkService.pillApps
    }
    function openNetworkWindow() {
        if (networkWindow.item) {
            networkWindow.item.show();
            networkWindow.item.raise();
            networkWindow.item.requestActivate();
            return;
        }
        networkWindow.active = true;
    }
    Connections {
        target: core
        function onNetworkWindowRequested() {
            root.openNetworkWindow();
        }
    }
    Loader {
        id: networkWindow
        active: false
        sourceComponent: Network.NetworkWindow {
            visible: true
            service: networkService
            onClosing: Qt.callLater(() => networkWindow.active = false)
        }
    }
}
