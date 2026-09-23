pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../package/contents/ui" as Shared
import "../package/contents/ui/network" as Network
import "Configuration.js" as Configuration

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
            desktopLayer: true,
            textColor: "#cdd6f4",
            accentColor: "#89b4fa"
        })

    property bool settingsOpen: false
    property var userSettings: ({})
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
                root.userSettings = Configuration.parsePreferences(text());
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

    function saveSettings(overrides) {
        userSettings = overrides;
        Quickshell.execDetached(["mkdir", "-p", root.configPath.replace(/\/[^/]*$/, "")]);
        preferences.setText(JSON.stringify(overrides, null, 2) + "\n");
    }
    // The widget writes a few settings itself (ping target, hidden lines).
    function writeConfig(key, value) {
        const next = Object.assign({}, userSettings);
        next[key] = value;
        saveSettings(Configuration.overrides(baseline, Object.assign({}, configuration, next)));
    }
    function configure() {
        settingsPage.draft = Object.assign({}, configuration);
        settingsOpen = true;
    }

    IpcHandler {
        target: "settings"
        function open(): void {
            root.configure();
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
        cfg: root.configuration
        onScreen: true
        commandSourceComponent: Component {
            CommandProcess {}
        }
        writeConfig: (key, value) => root.writeConfig(key, value)
        systemAccent: root.configuration.accentColor
        systemTextColor: root.configuration.textColor
    }

    Variants {
        model: Configuration.screens(Quickshell.screens, root.configuration.monitor)
        PanelWindow {
            id: panel
            required property var modelData
            readonly property real cardWidth: root.configuration.widgetWidth > 0 ? root.configuration.widgetWidth : view.preferredWidth
            readonly property var place: Configuration.geometry(modelData, root.configuration, cardWidth, view.preferredHeight)
            screen: modelData
            implicitWidth: place.width
            implicitHeight: place.height
            anchors.top: true
            anchors.left: true
            margins.top: place.y
            margins.left: place.x
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: root.configuration.desktopLayer ? WlrLayer.Bottom : WlrLayer.Top
            WlrLayershell.namespace: "glassy-system-monitor"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Shared.MonitorView {
                id: view
                anchors.fill: parent
                monitor: core
                cfg: root.configuration
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.RightButton
                onClicked: root.configure()
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
            savedDraft: root.configuration
            screenNames: Quickshell.screens.map(s => s.name)
            errorMessage: root.settingsError
            commandSourceComponent: Component {
                CommandProcess {}
            }
            onApply: draft => root.saveSettings(Configuration.overrides(root.baseline, draft))
            onReset: {
                root.saveSettings({});
                draft = Object.assign({}, root.baseline);
            }
            onClose: root.settingsOpen = false
        }
    }
}
