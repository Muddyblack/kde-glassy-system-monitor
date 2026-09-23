import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Plasma host: hands KConfig, the executable engine and the theme to the
// shared MonitorCore, and shows MonitorView (desktop) or the pill (panel).
PlasmoidItem {
    id: root

    readonly property bool isInPanel: plasmoid.configuration.panelMode || [PlasmaCore.Types.TopEdge, PlasmaCore.Types.BottomEdge, PlasmaCore.Types.LeftEdge, PlasmaCore.Types.RightEdge].indexOf(Plasmoid.location) !== -1
    property bool fullShown: false

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
        onScreen: root.fullShown
        active: root.visible
        systemAccent: Kirigami.Theme.highlightColor
        systemTextColor: Kirigami.Theme.textColor
    }

    compactRepresentation: CompactRepresentation {
        monitor: core
        cfg: plasmoid.configuration
        inPanel: root.isInPanel
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
        Layout.preferredWidth: preferredWidth
        Layout.preferredHeight: preferredHeight
        // In a panel this is created on first expand and then only hidden, so
        // visibility, not existence, says whether anything is worth drawing.
        onVisibleChanged: root.fullShown = visible
        Component.onCompleted: root.fullShown = visible
        Component.onDestruction: root.fullShown = false
    }
}
