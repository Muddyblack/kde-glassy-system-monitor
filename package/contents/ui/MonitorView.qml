import QtQuick
import QtQuick.Layouts
import "card"
import "Sections.js" as Sections
import "SectionModels.js" as SectionModels

// The full widget: glass card with the chosen sections in the chosen order.
// Plasma, Hyprland and the settings preview all show this same item.
Item {
    id: view

    required property var monitor
    required property var cfg
    // Wallpaper item that glass materials blur; hosts without one leave it null.
    property Item backdrop: null

    // This view's sections, from its own settings (a preview may show a
    // layout the core it reads from was not configured for).
    readonly property var sectionIds: Sections.parse(cfg.sections, cfg.activeSection)
    readonly property var materialColors: Sections.colors(sectionIds, cfg, String(monitor.accentColor || "#4aa8ff"))
    readonly property int margin: ({
            compact: 6,
            roomy: 14
        })[cfg.density] || 10
    readonly property int gap: margin
    readonly property int columns: Math.max(1, Math.min(3, cfg.layoutColumns || 1))
    readonly property var spans: String(cfg.sectionSpans || "").split(",").map(s => s.trim())
    // Row and column of each section: they fill rows left to right, and a
    // spanning section (or one alone at the end) takes the whole row.
    readonly property var placement: Sections.placement(sectionIds, columns, spans)
    // Height of the card from its sections: each row as tall as its tallest
    // section, rows stacked. `key` picks preferred or minimum heights.
    function stackedHeight(key) {
        const rows = [];
        for (let i = 0; i < sectionRepeater.count; i++) {
            const item = sectionRepeater.itemAt(i);
            const place = placement[i];
            if (item && place)
                rows[place.row] = Math.max(rows[place.row] || 0, item[key]);
        }
        const used = rows.filter(h => h !== undefined);
        return Math.ceil(margin * 2 + used.reduce((a, b) => a + b, 0) + Math.max(0, used.length - 1) * gap);
    }
    readonly property real preferredHeight: Math.max(80, stackedHeight("wanted"))
    // Below this something would be cut off; hosts must not go smaller.
    readonly property real minimumHeight: Math.max(80, stackedHeight("least"))
    readonly property real minimumWidth: columns * 180
    // Wider when a section has more to show side by side.
    readonly property real preferredWidth: columns > 1 ? columns * 290 : sectionIds.length === 1 && sectionIds[0] === "memory" ? 240 : 320

    GlassCard {
        id: glass
        anchors.fill: parent
        material: view.cfg.surfaceStyle || "tint"
        fill: view.cfg.bgColor || "#800d0f1a"
        radiusTL: view.cfg.bgRadiusTL ?? 12
        radiusTR: view.cfg.bgRadiusTR ?? 12
        radiusBR: view.cfg.bgRadiusBR ?? 12
        radiusBL: view.cfg.bgRadiusBL ?? 12
        frosted: view.cfg.frostedGlass !== false
        frostStrength: view.cfg.frostStrength ?? 0.55
        border: view.cfg.cardBorder !== false
        glassTint: view.cfg.glassTint || "clear"
        glassTintColor: view.cfg.glassTintColor || "#3daee9"
        glassBlur: view.cfg.glassBlur ?? 0.85
        refraction: view.cfg.glassRefraction ?? 0.5
        specular: view.cfg.glassSpecular !== false
        surfaceOpacity: view.cfg.cardOpacity ?? 1
        shadow: view.cfg.cardShadow || "none"
        grain: view.cfg.grain === true
        color1: view.materialColors[0]
        color2: view.materialColors[1]
        backdrop: view.backdrop
    }

    // Glows around the card while ping is over its thresholds. Painted once;
    // the pulse only animates opacity.
    Loader {
        id: alertGlow
        anchors.fill: parent
        anchors.margins: -40
        active: view.monitor.showPingSection && view.monitor.pingAlertActive && view.cfg.pingAlertPulse !== false
        sourceComponent: CardGlow {
            margin: 40
            radius: glass.maxRadius
            layers: [
                {
                    y: 0,
                    blur: 22,
                    spread: 2,
                    color: view.monitor.pingCritColor
                }
            ]
            insetColor: view.monitor.pingCritColor
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: 0.8
                    duration: 650
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.8
                    to: 0
                    duration: 650
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    Component {
        id: cpuSection
        CpuSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: memorySection
        MemorySection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: networkSection
        NetworkSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: pingSection
        PingSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: diskSection
        DiskSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: gpuSection
        GpuSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: sensorsSection
        HwSensorsSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: powerSection
        PowerSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: systemSection
        OsInfoSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: customSection
        CustomSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: storageSection
        BarListSection {
            monitor: view.monitor
            cfg: view.cfg
            sectionId: "storage"
            model: SectionModels.storage(view.monitor, view.cfg)
        }
    }
    Component {
        id: processesSection
        BarListSection {
            monitor: view.monitor
            cfg: view.cfg
            sectionId: "processes"
            model: SectionModels.processes(view.monitor, view.cfg)
        }
    }
    readonly property var components: ({
            cpu: cpuSection,
            memory: memorySection,
            network: networkSection,
            ping: pingSection,
            disk: diskSection,
            gpu: gpuSection,
            sensors: sensorsSection,
            power: powerSection,
            system: systemSection,
            custom: customSection,
            storage: storageSection,
            processes: processesSection
        })

    GridLayout {
        anchors.fill: parent
        anchors.margins: view.margin
        columns: view.columns
        rowSpacing: view.gap
        columnSpacing: view.gap * 1.6

        Repeater {
            id: sectionRepeater
            model: view.sectionIds
            Item {
                id: slot
                required property string modelData
                required property int index
                readonly property real wanted: loader.item ? loader.item.preferredHeight : 0
                readonly property real least: loader.item ? loader.item.minimumHeight : 0
                readonly property var place: view.placement[index] || {
                    row: index,
                    column: 0,
                    span: 1
                }
                // Charts share the spare height; text sections keep theirs.
                readonly property bool grows: ["sensors", "power", "system"].indexOf(modelData) === -1
                Layout.row: place.row
                Layout.column: place.column
                Layout.columnSpan: place.span
                Layout.fillWidth: true
                // Equal columns, whatever their content.
                Layout.preferredWidth: place.span
                Layout.fillHeight: grows
                Layout.preferredHeight: wanted
                // Only charts give way when space is short, and only to 40 px.
                Layout.minimumHeight: least

                Rectangle {
                    visible: slot.place.row > 0
                    y: -view.gap / 2
                    width: parent.width
                    height: 1
                    color: Qt.rgba(view.monitor.textColor.r, view.monitor.textColor.g, view.monitor.textColor.b, 0.10)
                }
                Loader {
                    id: loader
                    anchors.fill: parent
                    clip: true
                    sourceComponent: view.components[slot.modelData] || null
                }
            }
        }
    }
}
