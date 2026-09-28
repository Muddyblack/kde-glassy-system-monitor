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
    readonly property bool manual: cfg.layoutMode === "manual"
    readonly property var positions: Sections.positions(cfg.sectionPositions)
    function manualRect(index) {
        const p = positions[sectionIds[index]] || {};
        // Unpositioned sections start below every preceding section.
        let y = 0;
        for (let i = 0; i < index; ++i) {
            const item = sectionRepeater.itemAt(i);
            const saved = positions[sectionIds[i]] || {};
            y = Math.max(y, (saved.y ?? y) + (item ? item.spot.height : 0) + gap);
        }
        // No height: as tall as the content wants.
        return {
            x: p.x ?? 0,
            y: p.y ?? y,
            width: p.width ?? 300,
            height: p.height
        };
    }
    // Where each section is right now, in either arrangement: manual
    // positions start from this when the studio switches to Manual.
    function geometry() {
        const out = {};
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const item = sectionRepeater.itemAt(i);
            if (item)
                out[sectionIds[i]] = {
                    x: Math.round(item.x),
                    y: Math.round(item.y),
                    width: Math.round(item.width)
                };
        }
        return out;
    }
    // The studio preview lets sections be dragged and resized in Manual.
    // Hosts turn it on for arranging on the desktop too; in Automatic the
    // card offers to switch to Manual (`positions`: where to start from).
    property bool arranging: false
    // `place`: the section's new { x, y, width } and, once its height was
    // dragged, `height`.
    signal sectionMoved(string id, var place)
    signal manualRequested(string positions)
    // On the desktop a Done button ends arranging.
    property bool offerDone: false
    signal arrangeDone
    function manualExtent(horizontal) {
        let extent = 0;
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const item = sectionRepeater.itemAt(i);
            const rect = manualRect(i);
            extent = Math.max(extent, horizontal ? rect.x + rect.width : rect.y + (item ? item.spot.height : 0));
        }
        return Math.ceil(extent + margin * 2);
    }
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
    readonly property real preferredHeight: Math.max(80, manual ? manualExtent(false) : stackedHeight("wanted"))
    // Below this something would be cut off; hosts must not go smaller.
    readonly property real minimumHeight: Math.max(80, manual ? manualExtent(false) : stackedHeight("least"))
    readonly property real minimumWidth: manual ? manualExtent(true) : columns * 180
    // Wider when a section has more to show side by side.
    readonly property real preferredWidth: manual ? manualExtent(true) : columns > 1 ? columns * 290 : sectionIds.length === 1 && sectionIds[0] === "memory" ? 240 : 320

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
    Component {
        id: loadSection
        LoadSection {
            monitor: view.monitor
            cfg: view.cfg
        }
    }
    Component {
        id: fansSection
        BarListSection {
            monitor: view.monitor
            cfg: view.cfg
            sectionId: "fans"
            model: SectionModels.fans(view.monitor, view.cfg)
        }
    }
    Component {
        id: servicesSection
        BarListSection {
            monitor: view.monitor
            cfg: view.cfg
            sectionId: "services"
            model: SectionModels.services(view.monitor, view.cfg)
        }
    }
    Component {
        id: containersSection
        BarListSection {
            monitor: view.monitor
            cfg: view.cfg
            sectionId: "containers"
            model: SectionModels.containers(view.monitor, view.cfg)
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
            processes: processesSection,
            load: loadSection,
            fans: fansSection,
            services: servicesSection,
            containers: containersSection
        })

    Item {
        id: manualCanvas
        anchors.fill: parent
        anchors.margins: view.margin
    }
    GridLayout {
        id: grid
        anchors.fill: parent
        anchors.margins: view.margin
        columns: view.columns
        rowSpacing: view.gap
        columnSpacing: view.gap * 1.6

        Repeater {
            id: sectionRepeater
            parent: view.manual ? manualCanvas : grid
            model: view.sectionIds
            Item {
                id: slot
                required property string modelData
                required property int index
                readonly property var rect: view.manualRect(index)
                // Drag in progress (studio preview), committed on release.
                property point shift: Qt.point(0, 0)
                property real stretch: 0
                property real stretchDown: 0
                // What is dragged snaps to 4 px; typed positions stay exact.
                function snap(v, by) {
                    return by ? Math.round((v + by) / 4) * 4 : v;
                }
                readonly property var spot: ({
                        x: Math.max(0, snap(rect.x, shift.x)),
                        y: Math.max(0, snap(rect.y, shift.y)),
                        width: Math.max(180, snap(rect.width, stretch)),
                        // Never below what the section needs.
                        height: rect.height === undefined && !stretchDown ? wanted : Math.max(least, snap(rect.height ?? wanted, stretchDown)),
                        sized: rect.height !== undefined || !!stretchDown
                    })
                function commit() {
                    const t = spot;
                    shift = Qt.point(0, 0);
                    stretch = 0;
                    stretchDown = 0;
                    const place = {
                        x: t.x,
                        y: t.y,
                        width: t.width
                    };
                    if (t.sized)
                        place.height = Math.round(t.height);
                    view.sectionMoved(modelData, place);
                }
                Binding {
                    target: slot
                    property: "x"
                    value: slot.spot.x
                    when: view.manual
                }
                Binding {
                    target: slot
                    property: "y"
                    value: slot.spot.y
                    when: view.manual
                }
                Binding {
                    target: slot
                    property: "width"
                    value: slot.spot.width
                    when: view.manual
                }
                Binding {
                    target: slot
                    property: "height"
                    value: slot.spot.height
                    when: view.manual
                }
                readonly property real wanted: loader.item ? loader.item.preferredHeight : 0
                readonly property real least: loader.item ? loader.item.minimumHeight : 0
                readonly property var place: view.placement[index] || {
                    row: index,
                    column: 0,
                    span: 1
                }
                // Charts share the spare height; text sections keep theirs.
                readonly property bool grows: ["sensors", "power", "system", "fans", "services", "containers"].indexOf(modelData) === -1
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
                    visible: !view.manual && slot.place.row > 0
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
                // Manual arrangement in the studio: drag to move, drag the
                // right edge to resize; the section's own clicks pause.
                Rectangle {
                    visible: view.arranging && view.manual
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 6
                    color: move.pressed || resize.pressed ? Qt.rgba(1, 1, 1, 0.10) : move.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, move.containsMouse || move.pressed || resize.containsMouse || resize.pressed ? 0.7 : 0.25)
                    MouseArea {
                        id: move
                        property point from
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => from = mapToItem(view, mouse.x, mouse.y)
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const p = mapToItem(view, mouse.x, mouse.y);
                            slot.shift = Qt.point(p.x - from.x, p.y - from.y);
                        }
                        onReleased: slot.commit()
                    }
                    MouseArea {
                        id: resize
                        property real from
                        anchors.right: parent.right
                        width: 10
                        height: parent.height - 12
                        hoverEnabled: true
                        cursorShape: Qt.SizeHorCursor
                        onPressed: mouse => from = mapToItem(view, mouse.x, 0).x
                        onPositionChanged: mouse => {
                            if (pressed)
                                slot.stretch = mapToItem(view, mouse.x, 0).x - from;
                        }
                        onReleased: slot.commit()
                        Rectangle {
                            anchors.centerIn: parent
                            width: 3
                            height: Math.min(28, parent.height / 3)
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, resize.containsMouse || resize.pressed ? 0.9 : 0.4)
                        }
                    }
                    // Bottom edge: height; corner: both.
                    MouseArea {
                        id: resizeDown
                        property real from
                        anchors.bottom: parent.bottom
                        width: parent.width - 12
                        height: 10
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        onPressed: mouse => from = mapToItem(view, 0, mouse.y).y
                        onPositionChanged: mouse => {
                            if (pressed)
                                slot.stretchDown = mapToItem(view, 0, mouse.y).y - from;
                        }
                        onReleased: slot.commit()
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(28, parent.width / 3)
                            height: 3
                            radius: 1.5
                            color: Qt.rgba(1, 1, 1, resizeDown.containsMouse || resizeDown.pressed ? 0.9 : 0.4)
                        }
                    }
                    MouseArea {
                        property point from
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 14
                        height: 14
                        hoverEnabled: true
                        cursorShape: Qt.SizeFDiagCursor
                        onPressed: mouse => from = mapToItem(view, mouse.x, mouse.y)
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const p = mapToItem(view, mouse.x, mouse.y);
                            slot.stretch = p.x - from.x;
                            slot.stretchDown = p.y - from.y;
                        }
                        onReleased: slot.commit()
                    }
                    Text {
                        visible: move.containsMouse && !move.pressed
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        text: slot.spot.x + ", " + slot.spot.y + " · " + slot.spot.width + " × " + Math.round(slot.spot.height) + " px"
                        color: "white"
                        style: Text.Outline
                        styleColor: "#aa000000"
                        font.pixelSize: 10
                    }
                    Text {
                        visible: move.pressed || resize.pressed
                        anchors.centerIn: parent
                        text: slot.spot.x + ", " + slot.spot.y + " · " + slot.spot.width + " × " + Math.round(slot.spot.height) + " px"
                        color: "white"
                        style: Text.Outline
                        styleColor: "#aa000000"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }
        }
    }

    // Arranging an automatic layout: one click switches it to Manual.
    Rectangle {
        objectName: "arrangeFreely"
        visible: view.arranging && !view.manual
        anchors.centerIn: parent
        width: freely.implicitWidth + 24
        height: 30
        radius: 15
        color: freelyArea.containsMouse ? "#e0202428" : "#c0202428"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.35)
        Text {
            id: freely
            anchors.centerIn: parent
            text: "Arrange sections freely"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        MouseArea {
            id: freelyArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.manualRequested(Sections.seedPositions(view.cfg.sectionPositions, view.geometry()))
        }
    }

    Rectangle {
        objectName: "arrangeDone"
        visible: view.arranging && view.offerDone
        z: 20
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: doneText.implicitWidth + 22
        height: 26
        radius: 13
        color: doneArea.containsMouse ? "#ff3daee9" : "#e03daee9"
        Text {
            id: doneText
            anchors.centerIn: parent
            text: "Done"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        MouseArea {
            id: doneArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.arrangeDone()
        }
    }

    // A remote host that does not answer says so over the card.
    Rectangle {
        visible: !!view.monitor.remoteError
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: view.margin
        height: remoteText.implicitHeight + 10
        radius: 6
        color: Qt.rgba(0.6, 0.1, 0.1, 0.85)
        Text {
            id: remoteText
            anchors.centerIn: parent
            width: parent.width - 12
            text: view.monitor.remoteError || ""
            color: "#ffffff"
            font.family: view.monitor.fontFamily
            font.pixelSize: 10
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
