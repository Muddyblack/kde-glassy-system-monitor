pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../package/contents/ui" as Shared
import "../package/contents/ui/network" as Network
import "Configuration.js" as Configuration
import "../package/contents/ui/Sections.js" as Sections

// Quickshell host: the same MonitorCore, MonitorView and studio the Plasma
// widget uses, as a desktop layer on Hyprland (or any wlroots compositor).
// Defaults come from the Plasma main.xml; GUI changes are saved as overrides
// in ~/.config/glassy-system-monitor/hyprland.json.
ShellRoot {
    id: root

    // Declarative defaults from shell.qml, below GUI overrides.
    property var settings: ({})
    // Placement is Hyprland-only; Plasma places widgets itself.
    readonly property var placementDefaults: ({
            monitor: "",
            hAnchor: "right",
            verticalPosition: 0.08,
            screenMargin: 24,
            widgetWidth: 0,
            widgetHeight: 0,
            desktopLayer: true,
            cardX: 0,
            cardY: 0,
            textColor: "#cdd6f4",
            accentColor: "#89b4fa"
        })

    property bool settingsOpen: false
    property var userSettings: ({})
    // The other cards, each only what it changes from the first.
    property var cardSettings: []
    property string settingsError: ""
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/glassy-system-monitor/hyprland.json"

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("../package/contents/config/main.xml").toString().replace(/^file:\/\//, "")
        blockLoading: true
    }
    FileView {
        id: preferences
        path: root.configPath
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const saved = Configuration.split(Configuration.parsePreferences(text()));
                root.userSettings = saved.main;
                root.cardSettings = saved.cards;
                root.settingsError = "";
            } catch (error) {
                root.settingsError = "Cannot read settings: " + error;
            }
        }
        onSaveFailed: root.settingsError = "Could not save settings to " + root.configPath
        onSaved: root.settingsError = ""
    }

    readonly property var baseline: Object.assign({}, Configuration.defaults(defaultsFile.text()), placementDefaults, settings)
    readonly property var configuration: Object.assign({}, baseline, userSettings)
    // Every card's full settings; the first is `configuration`.
    readonly property var allCards: Configuration.cards(configuration, cardSettings)

    function saveSettings(overrides, cards) {
        userSettings = overrides;
        if (cards !== undefined)
            cardSettings = cards;
        Quickshell.execDetached(["mkdir", "-p", root.configPath.replace(/\/[^/]*$/, "")]);
        preferences.setText(JSON.stringify(Configuration.join(overrides, cardSettings), null, 2) + "\n");
    }
    // The widget writes a few settings itself (ping target, hidden lines).
    function writeConfig(key, value) {
        const next = Object.assign({}, userSettings);
        next[key] = value;
        saveSettings(Configuration.overrides(baseline, Object.assign({}, configuration, next)));
    }
    function configure(card) {
        arranging = false;
        settingsPage.open(allCards, card || 0);
        settingsOpen = true;
    }
    // Saves a few of one card's own settings (arranging on the desktop).
    function setCard(index, patch) {
        if (index === 0) {
            saveSettings(Configuration.overrides(baseline, Object.assign({}, configuration, patch)));
            return;
        }
        const cards = cardSettings.slice();
        cards[index - 1] = Object.assign({}, cards[index - 1], Configuration.pickCard(patch));
        saveSettings(userSettings, cards);
    }

    // Arranging on the desktop: drag cards by their bar, resize them by the
    // right edge, and drag their sections. `qs ipc call settings arrange`.
    property bool arranging: false
    function arrange() {
        settingsOpen = false;
        arranging = true;
    }
    // A card being dragged: card number → { x, y, width }, saved on release.
    property var livePlace: ({})
    function startDrag(index, card) {
        dragTo(index, {
            x: card.cardX,
            y: card.cardY,
            width: card.cardWidth,
            height: card.cardHeight
        });
    }
    function dragTo(index, place) {
        livePlace = Object.assign({}, livePlace, {
            [index]: place
        });
    }
    function endDrag(index, widened, heightened) {
        const place = livePlace[index];
        const next = Object.assign({}, livePlace);
        delete next[index];
        if (place) {
            const patch = {
                hAnchor: "free",
                cardX: Math.round(place.x),
                cardY: Math.round(place.y)
            };
            if (widened)
                patch.widgetWidth = Math.round(place.width);
            if (heightened)
                patch.widgetHeight = Math.round(place.height);
            setCard(index, patch);
        }
        livePlace = next;
    }

    IpcHandler {
        target: "settings"
        function open(): void {
            root.configure();
        }
        function arrange(): void {
            root.arrange();
        }
        function done(): void {
            root.arranging = false;
        }
    }

    // The network window: `qs ipc call network open`, or the network
    // section's "window" link. Its probes run only while it is open.
    property bool networkOpen: false
    IpcHandler {
        target: "network"
        function open(): void {
            root.networkOpen = true;
        }
        function close(): void {
            root.networkOpen = false;
        }
        function toggle(): void {
            root.networkOpen = !root.networkOpen;
        }
    }
    Connections {
        target: core
        function onNetworkWindowRequested() {
            root.networkOpen = true;
        }
    }
    // Saved state and the traffic history live in files (NetStore), shared
    // with the Plasma widget.
    Network.NetworkService {
        id: networkService
        commandSourceComponent: Component {
            CommandProcess {}
        }
        windowOpen: root.networkOpen
        pillActive: core.showNetApps
    }
    Binding {
        target: core
        property: "netApps"
        value: networkService.pillApps
    }
    LazyLoader {
        active: root.networkOpen
        FloatingWindow {
            id: networkWindow
            function saveSize() {
                networkService.saveState({
                    width: networkWindow.width,
                    height: networkWindow.height
                });
            }
            visible: true
            title: "Network — Glassy System Monitor"
            // Wayland leaves placement to the compositor; the size comes back.
            implicitWidth: networkService.state.width > 0 ? networkService.state.width : 1180
            implicitHeight: networkService.state.height > 0 ? networkService.state.height : 760
            color: networkPage.theme.bg
            onVisibleChanged: if (!visible) {
                saveSize();
                root.networkOpen = false;
            }
            Network.NetworkPage {
                id: networkPage
                anchors.fill: parent
                service: networkService
                onCloseRequested: {
                    networkWindow.saveSize();
                    root.networkOpen = false;
                }
            }
        }
    }

    Shared.MonitorCore {
        id: core
        // One core for every card: it samples what any of them shows.
        cfg: Configuration.coreConfig(root.allCards)
        onScreen: true
        commandSourceComponent: Component {
            CommandProcess {}
        }
        writeConfig: (key, value) => root.writeConfig(key, value)
        systemAccent: root.configuration.accentColor
        systemTextColor: root.configuration.textColor
    }

    // Each card on its screens. The model is the card numbers, so a settings
    // change updates the windows instead of making new ones.
    Variants {
        model: root.allCards.map((card, index) => index)
        Scope {
            id: cardScope
            required property int modelData
            readonly property var card: root.allCards[modelData] || root.configuration
            Variants {
                model: Configuration.screens(Quickshell.screens, cardScope.card.monitor)
                Scope {
                    id: onScreen
                    required property var modelData
                    readonly property var card: cardScope.card
                    readonly property int index: cardScope.modelData
                    // While the card is dragged or resized: where it is now.
                    readonly property var live: root.livePlace[index] || null
                    readonly property real cardWidth: live ? live.width : Math.max(view.minimumWidth, card.widgetWidth > 0 ? card.widgetWidth : view.preferredWidth)
                    readonly property real cardHeight: live ? live.height : Math.max(view.minimumHeight, card.widgetHeight > 0 ? card.widgetHeight : view.preferredHeight)
                    readonly property var place: Configuration.geometry(modelData, card, cardWidth, cardHeight)
                    // Resizing in screen coordinates, never below what the
                    // sections need.
                    function resizeTo(p, horizontal, vertical) {
                        root.dragTo(index, {
                            x: cardX,
                            y: cardY,
                            width: horizontal ? Math.max(view.minimumWidth, Math.min(modelData.width - cardX, p.x - cardX)) : cardWidth,
                            height: vertical ? Math.max(view.minimumHeight, Math.min(modelData.height - cardY, p.y - cardY)) : cardHeight
                        });
                    }
                    readonly property real cardX: live ? live.x : place.x
                    readonly property real cardY: live ? live.y : place.y

                    PanelWindow {
                        id: panel
                        screen: onScreen.modelData
                        implicitWidth: onScreen.place.width
                        implicitHeight: onScreen.place.height
                        anchors.top: true
                        anchors.left: true
                        margins.top: onScreen.cardY
                        margins.left: onScreen.cardX
                        exclusionMode: ExclusionMode.Ignore
                        color: "transparent"
                        // Above windows while arranging, so it can be seen.
                        WlrLayershell.layer: onScreen.card.desktopLayer && !root.arranging ? WlrLayer.Bottom : WlrLayer.Top
                        WlrLayershell.namespace: "glassy-system-monitor"
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                        Shared.MonitorView {
                            id: view
                            anchors.fill: parent
                            monitor: core
                            cfg: onScreen.card
                            arranging: root.arranging
                            onManualRequested: positions => root.setCard(onScreen.index, {
                                    layoutMode: "manual",
                                    sectionPositions: positions
                                })
                            onSectionMoved: (id, place) => root.setCard(onScreen.index, {
                                    sectionPositions: Sections.position(onScreen.card.sectionPositions, id, place)
                                })
                        }
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            acceptedButtons: Qt.RightButton
                            onClicked: root.arranging ? root.arranging = false : root.configure(onScreen.index)
                        }
                    }

                    // Arranging: a screen-wide layer that only takes input on
                    // the card's bar and right edge (the rest reaches the card
                    // below), so drags are in screen coordinates.
                    LazyLoader {
                        active: root.arranging
                        PanelWindow {
                            screen: onScreen.modelData
                            anchors.top: true
                            anchors.bottom: true
                            anchors.left: true
                            anchors.right: true
                            exclusionMode: ExclusionMode.Ignore
                            color: "transparent"
                            WlrLayershell.layer: WlrLayer.Overlay
                            WlrLayershell.namespace: "glassy-system-monitor-arrange"
                            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                            mask: Region {
                                item: bar
                                Region {
                                    item: edge
                                }
                                Region {
                                    item: bottomEdge
                                }
                                Region {
                                    item: corner
                                }
                            }

                            // Drag here to move the card; Done ends arranging.
                            Rectangle {
                                id: bar
                                x: onScreen.cardX
                                y: Math.max(0, onScreen.cardY - height - 4)
                                width: onScreen.place.width
                                height: 26
                                radius: 8
                                color: mover.pressed ? "#f02b3a4a" : "#e0202428"
                                border.width: 1
                                border.color: "#553daee9"
                                Text {
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - done.width - 30
                                    text: onScreen.live ? Math.round(onScreen.cardX) + ", " + Math.round(onScreen.cardY) + " · " + Math.round(onScreen.cardWidth) + " × " + Math.round(onScreen.cardHeight) + " px" : "⠿  Card " + (onScreen.index + 1) + " · drag to move, edges to resize"
                                    color: "white"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: mover
                                    property point from
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    onPressed: mouse => {
                                        from = Qt.point(mouse.x + bar.x - onScreen.cardX, mouse.y + bar.y - onScreen.cardY);
                                        root.startDrag(onScreen.index, onScreen);
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed)
                                            return;
                                        const p = mapToItem(null, mouse.x, mouse.y);
                                        const s = onScreen.modelData;
                                        root.dragTo(onScreen.index, {
                                            x: Math.max(0, Math.min(s.width - onScreen.cardWidth, p.x - from.x)),
                                            y: Math.max(0, Math.min(s.height - onScreen.place.height, p.y - from.y)),
                                            width: onScreen.cardWidth,
                                            height: onScreen.cardHeight
                                        });
                                    }
                                    onReleased: root.endDrag(onScreen.index, false, false)
                                }
                                Rectangle {
                                    id: done
                                    anchors.right: parent.right
                                    anchors.rightMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: doneText.implicitWidth + 18
                                    height: 20
                                    radius: 6
                                    color: doneArea.containsMouse ? "#ff3daee9" : "#d03daee9"
                                    Text {
                                        id: doneText
                                        anchors.centerIn: parent
                                        text: "Done"
                                        color: "white"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: doneArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.arranging = false
                                    }
                                }
                            }
                            // Drag the right edge for the width, the bottom edge for
                            // the height, the corner for both.
                            Rectangle {
                                id: edge
                                x: onScreen.cardX + onScreen.place.width - 5
                                y: onScreen.cardY
                                width: 10
                                height: onScreen.place.height - 8
                                radius: 3
                                color: sizer.pressed || sizer.containsMouse ? "#903daee9" : "#403daee9"
                                MouseArea {
                                    id: sizer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeHorCursor
                                    onPressed: root.startDrag(onScreen.index, onScreen)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            onScreen.resizeTo(mapToItem(null, mouse.x, mouse.y), true, false);
                                    }
                                    onReleased: root.endDrag(onScreen.index, true, false)
                                }
                            }
                            Rectangle {
                                id: bottomEdge
                                x: onScreen.cardX
                                y: onScreen.cardY + onScreen.place.height - 5
                                width: onScreen.place.width - 8
                                height: 10
                                radius: 3
                                color: heightSizer.pressed || heightSizer.containsMouse ? "#903daee9" : "#403daee9"
                                MouseArea {
                                    id: heightSizer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeVerCursor
                                    onPressed: root.startDrag(onScreen.index, onScreen)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            onScreen.resizeTo(mapToItem(null, mouse.x, mouse.y), false, true);
                                    }
                                    onReleased: root.endDrag(onScreen.index, false, true)
                                }
                            }
                            Rectangle {
                                id: corner
                                x: onScreen.cardX + onScreen.place.width - 8
                                y: onScreen.cardY + onScreen.place.height - 8
                                width: 16
                                height: 16
                                radius: 4
                                color: cornerSizer.pressed || cornerSizer.containsMouse ? "#d03daee9" : "#803daee9"
                                MouseArea {
                                    id: cornerSizer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeFDiagCursor
                                    onPressed: root.startDrag(onScreen.index, onScreen)
                                    onPositionChanged: mouse => {
                                        if (pressed)
                                            onScreen.resizeTo(mapToItem(null, mouse.x, mouse.y), true, true);
                                    }
                                    onReleased: root.endDrag(onScreen.index, true, true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindow {
        visible: root.settingsOpen
        title: "Glassy System Monitor Settings"
        implicitWidth: 1220
        implicitHeight: 820
        color: "#0e0f10"
        onVisibleChanged: if (!visible)
            root.settingsOpen = false
        SettingsPage {
            id: settingsPage
            anchors.fill: parent
            defaults: root.baseline
            screenNames: Quickshell.screens.map(s => s.name)
            errorMessage: root.settingsError
            commandSourceComponent: Component {
                CommandProcess {}
            }
            // The first card saves as before; the others as what they change.
            onApply: drafts => {
                root.saveSettings(Configuration.overrides(root.baseline, drafts[0]), drafts.slice(1).map(d => Configuration.cardChanges(drafts[0], d)));
                savedCards = root.allCards;
            }
            onReset: {
                root.saveSettings({}, []);
                open(root.allCards, 0);
            }
            onClose: root.settingsOpen = false
            onArrange: root.arrange()
        }
    }
}
