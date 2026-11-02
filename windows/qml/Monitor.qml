// The Windows monitor: the shared MonitorCore / MonitorView / settings studio
// hosted by a plain QQuickView, as hyprland/GlassyShell.qml hosts them in
// Quickshell. Settings merge exactly as there (main.xml defaults, then the
// host's placement defaults, then the user's file); only the data source
// differs: windows/sampler.py feeds a core started with `live: false`.
//
// One card is drawn. Further cards saved by the Linux hosts are kept in the
// settings file untouched.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "../../package/contents/ui" as Shared
import "../../hyprland" as Hyprland
import "../../hyprland/Configuration.js" as Configuration
import "../../package/contents/ui/Sections.js" as Sections

Item {
    id: root

    // Set by app.py before the view loads.
    property string defaultsXml: ""
    property string settingsJson: ""
    // SettingsStore (saves, placement signals) and the Sampler bridge.
    property var host: null
    property var sampler: null
    // False while the window is hidden: charts then stop animating.
    property bool shown: true
    property bool settingsOpen: false

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
    // What shell.qml sets for the Linux overlay.
    readonly property var hostDefaults: ({
            sections: "cpu,memory,network,disk"
        })

    readonly property var defaults: Configuration.defaults(defaultsXml)
    property var saved: {
        if (!settingsJson)
            return ({
                    main: {},
                    cards: []
                });
        try {
            return Configuration.split(Configuration.parsePreferences(settingsJson));
        } catch (error) {
            console.warn("Ignoring invalid settings:", error);
            return ({
                    main: {},
                    cards: []
                });
        }
    }
    readonly property var userSettings: saved.main
    readonly property var cardSettings: saved.cards
    readonly property var settingsBaseline: Object.assign({}, defaults, placementDefaults, hostDefaults)
    readonly property var configuration: Object.assign({}, settingsBaseline, userSettings)
    readonly property var allCards: Configuration.cards(configuration, cardSettings)
    readonly property var coreConfiguration: Configuration.coreConfig(allCards)

    function persist(main, cards) {
        saved = {
            main: main,
            cards: cards
        };
        if (host)
            host.saveSettings(JSON.stringify(Configuration.join(main, cards), null, 2) + "\n");
    }
    function setCard(patch) {
        persist(Configuration.overrides(settingsBaseline, Object.assign({}, configuration, patch)), cardSettings);
    }
    function writeConfig(key, value) {
        setCard({
            [key]: value
        });
    }

    // ── where the card goes ───────────────────────────────────────────────────
    readonly property var screen: Configuration.screens(Qt.application.screens, configuration.monitor)[0] || null
    readonly property real cardWidth: Math.max(view.minimumWidth, configuration.widgetWidth > 0 ? configuration.widgetWidth : view.preferredWidth)
    readonly property real cardHeight: Math.max(view.minimumHeight, configuration.widgetHeight > 0 ? configuration.widgetHeight : view.preferredHeight)
    readonly property var cardRect: {
        if (!screen)
            return ({
                    x: 0,
                    y: 0,
                    width: cardWidth,
                    height: cardHeight
                });
        const place = Configuration.geometry(screen, configuration, cardWidth, cardHeight);
        return ({
                x: Math.round(screen.virtualX + place.x),
                y: Math.round(screen.virtualY + place.y),
                width: Math.round(place.width),
                height: Math.round(place.height)
            });
    }

    // The window was dragged / resized by hand (Move / resize, or middle-drag):
    // keep it where it is, as the Linux "arrange" mode does.
    function placed(x, y, width, height) {
        const sx = screen ? screen.virtualX : 0, sy = screen ? screen.virtualY : 0;
        const patch = {
            hAnchor: "free",
            cardX: Math.round(x - sx),
            cardY: Math.round(y - sy)
        };
        if (width > 0 && Math.round(width) !== Math.round(cardWidth))
            patch.widgetWidth = Math.round(width);
        if (height > 0 && Math.round(height) !== Math.round(cardHeight))
            patch.widgetHeight = Math.round(height);
        setCard(patch);
    }
    function resetPlacement() {
        const next = Object.assign({}, userSettings);
        for (const key of ["hAnchor", "cardX", "cardY", "widgetWidth", "widgetHeight"])
            delete next[key];
        persist(next, cardSettings);
    }
    Connections {
        target: root.host
        function onPlaced(x, y, width, height) {
            root.placed(x, y, width, height);
        }
        function onPlacementReset() {
            root.resetPlacement();
        }
    }

    // ── measuring ─────────────────────────────────────────────────────────────
    // MonitorCore asks its command source for shell commands on Linux. With
    // live: false it asks for none; this only has to be a valid runner.
    Component {
        id: nullCommandSource
        QtObject {
            property var connectedSources: []
            signal newData(string source, var data)
            function connectSource(source) {
            }
            function disconnectSource(source) {
            }
        }
    }

    Shared.MonitorCore {
        id: core
        objectName: "core" // app.py --soak reads what arrived
        live: false
        cfg: root.coreConfiguration
        onScreen: root.shown
        commandSourceComponent: nullCommandSource
        writeConfig: (key, value) => root.writeConfig(key, value)
        systemAccent: root.configuration.accentColor
        systemTextColor: root.configuration.textColor
    }

    WindowsFeeder {
        id: feeder
        monitor: core
        sampler: root.sampler
    }
    Connections {
        target: root.sampler
        function onSampled(readings) {
            feeder.apply(readings);
        }
    }

    // Tell the sampler what to measure: only the shown sections, at the
    // configured pace. Re-sent when either changes.
    readonly property var wantedSections: core.sampledIds.slice()
    readonly property var samplerOptions: ({
            targets: core.targetList,
            currentTargetIndex: core.activeTarget,
            pingInterval: coreConfiguration.pingInterval || 5,
            pingTimeout: coreConfiguration.pingTimeout || 2,
            containerSource: coreConfiguration.containerSource || "",
            kubeNamespace: coreConfiguration.kubeNamespace || ""
        })
    function configureSampler() {
        if (sampler)
            sampler.configure(wantedSections, samplerOptions, core.updateIntervalMs);
        if (wantedSections.indexOf("processes") === -1)
            feeder.release();
    }
    onWantedSectionsChanged: configureSampler()
    onSamplerOptionsChanged: configureSampler()
    Connections {
        target: core
        function onUpdateIntervalMsChanged() {
            root.configureSampler();
        }
    }
    Component.onCompleted: configureSampler()

    Shared.MonitorView {
        id: view
        anchors.fill: parent
        monitor: core
        cfg: root.configuration
    }

    Window {
        objectName: "settingsWindow" // app.py gives it a shader cache
        visible: root.settingsOpen
        title: "Glassy System Monitor Settings"
        width: Math.min(1220, Screen.desktopAvailableWidth - 40)
        height: Math.min(820, Screen.desktopAvailableHeight - 60)
        x: Screen.virtualX + (Screen.desktopAvailableWidth - width) / 2
        y: Screen.virtualY + Math.max(40, (Screen.desktopAvailableHeight - height) / 2)
        color: "#0e0f10"
        onVisibleChanged: if (!visible)
            root.settingsOpen = false
        Loader {
            anchors.fill: parent
            active: root.settingsOpen
            sourceComponent: Component {
                Hyprland.SettingsPage {
                    id: settingsPage
                    anchors.fill: parent
                    defaults: root.settingsBaseline
                    screenNames: Qt.application.screens.map(s => s.name)
                    errorMessage: root.host ? root.host.settingsError : ""
                    commandSourceComponent: nullCommandSource
                    Component.onCompleted: open(root.allCards, 0)
                    onApply: drafts => {
                        root.persist(Configuration.overrides(root.settingsBaseline, drafts[0]), drafts.slice(1).map(d => Configuration.cardChanges(drafts[0], d)));
                        savedCards = root.allCards;
                    }
                    onReset: {
                        root.persist({}, []);
                        open(root.allCards, 0);
                    }
                    onClose: root.settingsOpen = false
                }
            }
        }
    }
}
