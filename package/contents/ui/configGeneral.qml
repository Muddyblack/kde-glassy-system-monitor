import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: root

    // ── cfg_ bindings ─────────────────────────────────────────────────────────
    property int cfg_activeSection: 0
    property alias cfg_showCpuCores: showCpuCoresCB.checked

    property alias cfg_pingTitle: pingTitleField.text
    property alias cfg_networkTitle: networkTitleField.text
    property alias cfg_cpuTitle: cpuTitleField.text
    property alias cfg_memoryTitle: memoryTitleField.text
    property alias cfg_customCmdTitle: customCmdTitleField.text

    property alias cfg_customCmd: customCmdField.text
    property alias cfg_customCmdUnit: customCmdUnitField.text
    property alias cfg_customCmdMax: customCmdMaxSpin.value
    property alias cfg_customCmdInterval: customCmdIntervalSpin.value
    property alias cfg_customCmdColor: customCmdColorButton.color

    property alias cfg_targets: targetsField.text
    property alias cfg_pingInterval: pingIntervalSpin.value
    property alias cfg_pingTimeout: pingTimeoutSpin.value
    property alias cfg_historySize: historySizeSpin.value
    property alias cfg_latencyThreshold: latencyThresholdSpin.value
    property alias cfg_lossThreshold: lossThresholdSpin.value

    property string cfg_networkInterface: "auto"

    property alias cfg_useSystemAccent: useSystemAccentCB.checked
    property alias cfg_customColor: customColorButton.color
    property alias cfg_useSystemTextColor: useSystemTextColorCB.checked
    property alias cfg_customTextColor: customTextColorButton.color

    property alias cfg_dlColor: dlColorButton.color
    property alias cfg_ulColor: ulColorButton.color
    property alias cfg_cpuColor: cpuColorButton.color
    property alias cfg_memColor: memColorButton.color
    property alias cfg_swapColor: swapColorButton.color

    property string cfg_coreColorsStr: "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff"

    property alias cfg_chartType: chartTypeCombo.currentIndex
    property alias cfg_lineWidth: lineWidthSlider.value
    property alias cfg_glowLine: glowLineCB.checked
    property alias cfg_showStats: showStatsCB.checked
    property alias cfg_showLegend: showLegendCB.checked
    property alias cfg_showYLabels: showYLabelsCB.checked
    property alias cfg_showGridLines: showGridLinesCB.checked
    property alias cfg_autoYRange: autoYRangeCB.checked
    property alias cfg_smoothLines: smoothLinesCB.checked
    property alias cfg_smoothScroll: smoothScrollCB.checked
    property alias cfg_accurateGeo: accurateGeoCB.checked
    property alias cfg_targetFps: targetFpsSpin.value
    property string cfg_disabledCoresStr: ""
    property string cfg_diskDevice: "auto"
    property string cfg_diskTitle: "Disk I/O"
    property alias cfg_diskRdColor: diskRdColorButton.color
    property alias cfg_diskWrColor: diskWrColorButton.color
    property string cfg_gpuTitle: "GPU"
    property alias cfg_gpuColor: gpuColorButton.color
    property alias cfg_gpuShowEngines: gpuShowEnginesCB.checked
    property alias cfg_netShowInfo: netShowInfoCB.checked
    property alias cfg_showBg: showBgCB.checked
    property alias cfg_bgColor: bgColorButton.color
    property alias cfg_bgRadius: bgRadiusSlider.value
    property alias cfg_frostedGlass: frostedGlassCB.checked
    property alias cfg_frostStrength: frostStrengthSlider.value
    property alias cfg_gpuBloom: gpuBloomCB.checked
    property alias cfg_bloomStrength: bloomStrengthSlider.value
    property alias cfg_panelMode: panelModeCB.checked
    property alias cfg_panelShowSessionTotals: panelShowSessionTotalsCB.checked
    property alias cfg_panelPlainText: panelPlainTextCB.checked
    property alias cfg_panelShowBg: panelShowBgCB.checked

    property alias cfg_hwSensorsTitle: hwSensorsTitleField.text
    property alias cfg_hwTempWarn: hwTempWarnSpin.value
    property alias cfg_hwTempCrit: hwTempCritSpin.value
    property alias cfg_osInfoTitle: osInfoTitleField.text
    property alias cfg_powerTitle: powerTitleField.text

    // Hidden fields for new section title aliases
    QQC.TextField {
        id: hwSensorsTitleField
        visible: false
    }
    QQC.TextField {
        id: osInfoTitleField
        visible: false
    }
    QQC.TextField {
        id: powerTitleField
        visible: false
    }
    QQC.SpinBox {
        id: hwTempWarnSpin
        from: 30
        to: 120
        stepSize: 1
        visible: false
    }
    QQC.SpinBox {
        id: hwTempCritSpin
        from: 30
        to: 120
        stepSize: 1
        visible: false
    }

    // Silence SimpleKCM warnings about missing default properties
    property var cfg_swapColorDefault
    property var cfg_targetsDefault
    property var cfg_ulColorDefault
    property var cfg_useSystemAccentDefault
    property var cfg_useSystemTextColorDefault

    // ── helpers ───────────────────────────────────────────────────────────────
    property var detectedIfaces: []
    property var detectedDisks: []

    // Hidden fields so aliases don't break
    QQC.TextField {
        id: pingTitleField
        visible: false
    }
    QQC.TextField {
        id: networkTitleField
        visible: false
    }
    QQC.TextField {
        id: cpuTitleField
        visible: false
    }
    QQC.TextField {
        id: memoryTitleField
        visible: false
    }
    QQC.TextField {
        id: customCmdTitleField
        visible: false
    }

    KQuickControls.ColorButton {
        id: dlColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: ulColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: cpuColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: memColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: swapColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: diskRdColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: diskWrColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: gpuColorButton
        visible: false
        showAlphaChannel: false
    }

    P5Support.DataSource {
        id: ifaceSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            ifaceSource.disconnectSource(sourceName);
            const ifaces = ["auto"];
            for (const line of (data["stdout"] || "").split("\n")) {
                const m = line.trim().match(/^(\w+):/);
                if (m && m[1] !== "lo")
                    ifaces.push(m[1]);
            }
            root.detectedIfaces = ifaces;
            const idx = ifaces.indexOf(root.cfg_networkInterface);
            ifaceCombo.currentIndex = idx >= 0 ? idx : 0;
        }
    }
    P5Support.DataSource {
        id: diskDetectSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            diskDetectSource.disconnectSource(sourceName);
            const disks = ["auto"];
            for (const line of (data["stdout"] || "").split("\n")) {
                const p = line.trim().split(/\s+/);
                if (p.length < 3)
                    continue;
                const name = p[2];
                if (/^(loop|ram|zram)/.test(name))
                    continue;
                if (/[0-9]p[0-9]+$/.test(name))
                    continue;
                if (/^sd[a-z]+[0-9]+$/.test(name))
                    continue;
                if (/^vd[a-z]+[0-9]+$/.test(name))
                    continue;
                if (/^mmcblk[0-9]+p[0-9]+$/.test(name))
                    continue;
                disks.push(name);
            }
            root.detectedDisks = disks;
        }
    }
    Component.onCompleted: {
        ifaceSource.connectSource("cat /proc/net/dev");
        diskDetectSource.connectSource("cat /proc/diskstats");
    }

    function coreColorAt(i) {
        const parts = cfg_coreColorsStr.split(",");
        return parts[i] || "#888888";
    }
    function setCoreColor(i, color) {
        const parts = cfg_coreColorsStr.split(",");
        while (parts.length <= i)
            parts.push("#888888");
        parts[i] = color;
        cfg_coreColorsStr = parts.join(",");
    }

    function titleForSection(s) {
        if (s === 0)
            return cfg_pingTitle;
        if (s === 1)
            return cfg_networkTitle;
        if (s === 2)
            return cfg_cpuTitle;
        if (s === 3)
            return cfg_memoryTitle;
        if (s === 4)
            return cfg_customCmdTitle;
        if (s === 5)
            return cfg_diskTitle;
        if (s === 6)
            return cfg_gpuTitle;
        if (s === 7)
            return cfg_hwSensorsTitle;
        if (s === 8)
            return cfg_osInfoTitle;
        if (s === 9)
            return cfg_powerTitle;
        return "";
    }
    function setTitleForSection(s, v) {
        if (s === 0)
            cfg_pingTitle = v;
        else if (s === 1)
            cfg_networkTitle = v;
        else if (s === 2)
            cfg_cpuTitle = v;
        else if (s === 3)
            cfg_memoryTitle = v;
        else if (s === 4)
            cfg_customCmdTitle = v;
        else if (s === 5)
            cfg_diskTitle = v;
        else if (s === 6)
            cfg_gpuTitle = v;
        else if (s === 7)
            cfg_hwSensorsTitle = v;
        else if (s === 8)
            cfg_osInfoTitle = v;
        else if (s === 9)
            cfg_powerTitle = v;
    }

    readonly property var sensorCategories: [
        {
            icon: "cpu-symbolic",
            label: i18n("CPUs"),
            section: 2
        },
        {
            icon: "drive-harddisk-symbolic",
            label: i18n("Disks"),
            section: 5
        },
        {
            icon: "video-display-symbolic",
            label: i18n("GPU"),
            section: 6
        },
        {
            icon: "sensor-symbolic",
            label: i18n("Hardware Sensors"),
            section: 7
        },
        {
            icon: "media-flash-symbolic",
            label: i18n("Memory"),
            section: 3
        },
        {
            icon: "network-wired-symbolic",
            label: i18n("Network Devices"),
            section: 1
        },
        {
            icon: "network-workgroup-symbolic",
            label: i18n("Network / Ping"),
            section: 0
        },
        {
            icon: "system-run-symbolic",
            label: i18n("Operating System"),
            section: 8
        },
        {
            icon: "battery-symbolic",
            label: i18n("Power & Pressure"),
            section: 9
        },
        {
            icon: "utilities-terminal-symbolic",
            label: i18n("Custom Command"),
            section: 4
        }
    ]

    // ── Root layout ───────────────────────────────────────────────────────────
    header: QQC.TabBar {
        id: tabBar
        QQC.TabButton {
            text: i18n("Style")
        }
        QQC.TabButton {
            text: i18n("Chart")
        }
        QQC.TabButton {
            text: i18n("Sections")
        }
    }

    ColumnLayout {
        spacing: 0

        // ── TAB CONTENT ───────────────────────────────────────────────────────
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            // Height follows the CURRENT tab's content so SimpleKCM's scroll view
            // gets a real content height and can scroll when a tab is taller than
            // the window. A fixed height (was 520) clipped tall tabs with no scroll.
            // Tabs whose children all use fillHeight (the Sensor Details tab) have
            // implicitHeight 0, so honor their Layout.preferredHeight hint instead —
            // without it that tab collapses to zero height and renders blank.
            Layout.preferredHeight: {
                var it = itemAt(currentIndex);
                if (!it)
                    return 0;
                var pref = it.Layout.preferredHeight;
                return pref > 0 ? pref : it.implicitHeight;
            }
            currentIndex: tabBar.currentIndex

            // ══════════════════════════════════════════════════════════════════
            // TAB 1 — STYLE
            // ══════════════════════════════════════════════════════════════════
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 380

                // Widget ───────────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Widget")
                }

                QQC.ComboBox {
                    id: chartTypeCombo
                    Kirigami.FormData.label: i18n("Chart type:")
                    Layout.minimumWidth: 220
                    model: ListModel {
                        ListElement {
                            text: "Line  —  smooth curve"
                        }
                        ListElement {
                            text: "Bars  —  vertical bars"
                        }
                        ListElement {
                            text: "Filled Area"
                        }
                        ListElement {
                            text: "Donut / Ring"
                        }
                        ListElement {
                            text: "Pie Chart"
                        }
                        ListElement {
                            text: "Horizontal Bars"
                        }
                        ListElement {
                            text: "Text Only  —  no graph"
                        }
                    }
                    textRole: "text"
                }
                QQC.Label {
                    text: i18n("Applies to all sections.")
                    opacity: 0.45
                    font.pixelSize: 10
                    Layout.fillWidth: true
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("History length:")
                    QQC.SpinBox {
                        id: historySizeSpin
                        from: 10
                        to: 300
                        stepSize: 10
                    }
                    QQC.Label {
                        text: i18n("data points")
                        opacity: 0.55
                    }
                }

                // Background ──────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Background")
                }

                QQC.CheckBox {
                    id: showBgCB
                    Kirigami.FormData.label: i18n("Glassy card:")
                    text: i18n("Show background card behind widget")
                }
                KQuickControls.ColorButton {
                    id: bgColorButton
                    Kirigami.FormData.label: i18n("Card color:")
                    visible: showBgCB.checked
                    showAlphaChannel: true
                }
                QQC.Label {
                    text: i18n("Use the alpha slider to control transparency.")
                    visible: showBgCB.checked
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: showBgCB.checked
                    Kirigami.FormData.label: i18n("Corner radius:")
                    QQC.Slider {
                        id: bgRadiusSlider
                        from: 0
                        to: 30
                        stepSize: 1
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: bgRadiusSlider.value.toFixed(0) + " px"
                        Layout.minimumWidth: 36
                    }
                }
                QQC.CheckBox {
                    id: frostedGlassCB
                    visible: showBgCB.checked
                    Kirigami.FormData.label: i18n("Frosted glass:")
                    text: i18n("Soft GPU-blurred glass card")
                }
                QQC.Label {
                    text: i18n("Blurs the card's own fill for a premium frosted look (GPU-accelerated). Plasma can't blur the desktop behind the widget, so this frosts the card itself.")
                    visible: showBgCB.checked && frostedGlassCB.checked
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: showBgCB.checked && frostedGlassCB.checked
                    Kirigami.FormData.label: i18n("Frost amount:")
                    QQC.Slider {
                        id: frostStrengthSlider
                        from: 0
                        to: 1
                        stepSize: 0.05
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: Math.round(frostStrengthSlider.value * 100) + "%"
                        Layout.minimumWidth: 36
                    }
                }

                // Colors ──────────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Colors")
                }

                QQC.CheckBox {
                    id: useSystemTextColorCB
                    Kirigami.FormData.label: i18n("Text color:")
                    text: i18n("Use system text color")
                }
                KQuickControls.ColorButton {
                    id: customTextColorButton
                    Kirigami.FormData.label: i18n("Custom:")
                    visible: !useSystemTextColorCB.checked
                    showAlphaChannel: false
                }

                QQC.CheckBox {
                    id: useSystemAccentCB
                    Kirigami.FormData.label: i18n("Accent color:")
                    text: i18n("Use system accent color")
                }
                KQuickControls.ColorButton {
                    id: customColorButton
                    Kirigami.FormData.label: i18n("Custom:")
                    visible: !useSystemAccentCB.checked
                    showAlphaChannel: false
                }

                // Panel Mode ──────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Panel Mode")
                }

                QQC.CheckBox {
                    id: panelModeCB
                    Kirigami.FormData.label: i18n("Panel mode:")
                    text: i18n("Compact inline widget for the panel bar")
                }
                QQC.Label {
                    text: i18n("Shrinks the widget to a compact pill that fits in the panel. Add multiple instances — one per metric — and pick a different sensor for each in the Sections tab.")
                    visible: panelModeCB.checked
                    opacity: 0.55
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                QQC.CheckBox {
                    id: panelShowBgCB
                    visible: panelModeCB.checked
                    Kirigami.FormData.label: i18n("Background:")
                    text: i18n("Show background pill")
                }
                QQC.CheckBox {
                    id: panelShowSessionTotalsCB
                    visible: panelModeCB.checked
                    Kirigami.FormData.label: i18n("Session totals:")
                    text: i18n("Show session ↓/↑ byte totals next to speed (network only)")
                }
                QQC.CheckBox {
                    id: panelPlainTextCB
                    visible: panelModeCB.checked
                    Kirigami.FormData.label: i18n("Text style:")
                    text: i18n("Plain white text (no per-metric accent colors)")
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 2 — CHART
            // ══════════════════════════════════════════════════════════════════
            Kirigami.FormLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 380

                // Lines & Effects ──────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Lines & Effects")
                }

                QQC.CheckBox {
                    id: smoothLinesCB
                    Kirigami.FormData.label: i18n("Smooth lines:")
                    text: i18n("Bézier curve interpolation")
                }
                QQC.CheckBox {
                    id: glowLineCB
                    Kirigami.FormData.label: i18n("Glow effect:")
                    text: i18n("Neon glow on lines")
                }
                QQC.CheckBox {
                    id: gpuBloomCB
                    visible: glowLineCB.checked
                    Kirigami.FormData.label: i18n("GPU bloom:")
                    text: i18n("Render glow as a GPU bloom halo")
                }
                QQC.Label {
                    text: i18n("Moves the line glow from the CPU to a GPU bloom pass — a softer halo that costs far less CPU. Recommended.")
                    visible: glowLineCB.checked && gpuBloomCB.checked
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: glowLineCB.checked && gpuBloomCB.checked
                    Kirigami.FormData.label: i18n("Bloom amount:")
                    QQC.Slider {
                        id: bloomStrengthSlider
                        from: 0
                        to: 1
                        stepSize: 0.05
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: Math.round(bloomStrengthSlider.value * 100) + "%"
                        Layout.minimumWidth: 36
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Line width:")
                    QQC.Slider {
                        id: lineWidthSlider
                        from: 0.8
                        to: 6.0
                        stepSize: 0.2
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: lineWidthSlider.value.toFixed(1) + " px"
                        Layout.minimumWidth: 36
                    }
                }

                // Animation ───────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Animation")
                }

                QQC.CheckBox {
                    id: smoothScrollCB
                    Kirigami.FormData.label: i18n("Smooth scroll:")
                    text: i18n("Slide chart between data updates")
                }
                QQC.Label {
                    text: i18n("Disable to save CPU when running alongside other animated widgets.")
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: smoothScrollCB.checked
                    Kirigami.FormData.label: i18n("Target FPS:")
                    QQC.SpinBox {
                        id: targetFpsSpin
                        from: 15
                        to: 144
                        stepSize: 5
                    }
                    QQC.Label {
                        text: i18n("fps")
                        opacity: 0.55
                    }
                }

                // Display ─────────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Display")
                }

                QQC.CheckBox {
                    id: showLegendCB
                    Kirigami.FormData.label: i18n("Legend:")
                    text: i18n("Color-coded legend below graph")
                }
                QQC.CheckBox {
                    id: gpuShowEnginesCB
                    Kirigami.FormData.label: i18n("GPU engines:")
                    text: i18n("Per-engine breakdown (VRAM, compute, decode, encode)")
                }
                QQC.Label {
                    text: i18n("Best-effort — only the metrics your GPU backend exposes are shown. NVIDIA reports encode/decode + VRAM; AMD/Intel report what's available via DRM fdinfo.")
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                QQC.CheckBox {
                    id: netShowInfoCB
                    Kirigami.FormData.label: i18n("Network info:")
                    text: i18n("Show current SSID / IP address")
                }
                QQC.CheckBox {
                    id: showGridLinesCB
                    Kirigami.FormData.label: i18n("Grid lines:")
                    text: i18n("Horizontal grid lines")
                }
                QQC.CheckBox {
                    id: accurateGeoCB
                    Kirigami.FormData.label: i18n("Country flags:")
                    text: i18n("Accurate GeoIP for connection flags")
                }
                QQC.Label {
                    text: i18n("Uses a MaxMind database (auto-detected from Portmaster) when available; otherwise falls back to a hostname-based guess. Needs the 'mmdblookup' tool and a readable database.")
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                QQC.CheckBox {
                    id: showYLabelsCB
                    Kirigami.FormData.label: i18n("Y-axis labels:")
                    text: i18n("Scale labels on the left")
                }
                QQC.CheckBox {
                    id: autoYRangeCB
                    Kirigami.FormData.label: i18n("Auto Y-range:")
                    text: i18n("Fit axis to visible data")
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 3 — SENSOR DETAILS
            // ══════════════════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                // This tab uses an internal Flickable (no natural implicit height),
                // so give the stack an explicit height for it instead of collapsing.
                Layout.preferredHeight: 520
                spacing: 0

                // ── Left: category list ──────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.04)
                    border.color: Qt.rgba(0, 0, 0, 0.10)

                    ListView {
                        id: sensorCatList
                        anchors {
                            fill: parent
                            margins: 4
                        }
                        clip: true
                        model: root.sensorCategories
                        currentIndex: {
                            for (let i = 0; i < root.sensorCategories.length; i++) {
                                if (root.sensorCategories[i].section === cfg_activeSection)
                                    return i;
                            }
                            return 0;
                        }

                        delegate: QQC.ItemDelegate {
                            id: catDelegate
                            width: sensorCatList.width
                            height: 38
                            highlighted: ListView.isCurrentItem
                            enabled: modelData.section >= 0

                            contentItem: RowLayout {
                                spacing: 8

                                Kirigami.Icon {
                                    source: modelData.icon
                                    implicitWidth: 16
                                    implicitHeight: 16
                                    opacity: catDelegate.enabled ? 1.0 : 0.35
                                }
                                QQC.Label {
                                    text: modelData.label
                                    font.pixelSize: 13
                                    color: catDelegate.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                    opacity: catDelegate.enabled ? 1.0 : 0.35
                                    Layout.fillWidth: true
                                }
                                QQC.Label {
                                    visible: !catDelegate.enabled
                                    text: i18n("soon")
                                    font.pixelSize: 9
                                    opacity: 0.30
                                }
                            }

                            onClicked: {
                                if (modelData.section >= 0) {
                                    cfg_activeSection = modelData.section;
                                }
                            }
                        }
                    }
                }

                // ── Right: detail panel ──────────────────────────────────────
                Flickable {
                    id: sensorDetailFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: sensorDetailForm.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    QQC.ScrollBar.vertical: QQC.ScrollBar {
                        policy: QQC.ScrollBar.AsNeeded
                    }

                    Kirigami.FormLayout {
                        id: sensorDetailForm
                        anchors.left: parent.left
                        anchors.right: parent.right

                        // Section title ───────────────────────────────────────
                        QQC.TextField {
                            id: titleEditField
                            Kirigami.FormData.label: i18n("Section title:")
                            Layout.fillWidth: true
                            text: root.titleForSection(cfg_activeSection)
                            onTextEdited: root.setTitleForSection(cfg_activeSection, text)
                            Connections {
                                target: root
                                function onCfg_activeSectionChanged() {
                                    if (!titleEditField.activeFocus)
                                        titleEditField.text = root.titleForSection(root.cfg_activeSection);
                                }
                            }
                        }

                        // CPU ─────────────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 2
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("CPU")
                        }
                        KQuickControls.ColorButton {
                            id: cpuColorDetail
                            visible: cfg_activeSection === 2
                            Kirigami.FormData.label: i18n("CPU total color:")
                            showAlphaChannel: false
                            color: cpuColorButton.color
                            onColorChanged: cpuColorButton.color = color
                        }
                        QQC.CheckBox {
                            id: showCpuCoresCB
                            visible: cfg_activeSection === 2
                            Kirigami.FormData.label: i18n("Per-core lines:")
                            text: i18n("Overlay individual core lines on graph")
                        }

                        // ── Core visibility range ─────────────────────────────
                        RowLayout {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            Kirigami.FormData.label: i18n("Visible cores:")
                            spacing: 6

                            QQC.TextField {
                                id: coreRangeField
                                Layout.minimumWidth: 160
                                placeholderText: "e.g. 1-8, 10, 13-16"

                                // Parse "1-8, 10, 13-16" → set of 0-based disabled indices
                                function applyRange(txt) {
                                    const total = 16;
                                    const enabled = new Set();
                                    const parts = txt.split(",");
                                    for (const part of parts) {
                                        const t = part.trim();
                                        const rng = t.match(/^(\d+)\s*-\s*(\d+)$/);
                                        if (rng) {
                                            const lo = Math.max(1, parseInt(rng[1]));
                                            const hi = Math.min(total, parseInt(rng[2]));
                                            for (let i = lo; i <= hi; i++)
                                                enabled.add(i);
                                        } else {
                                            const n = parseInt(t);
                                            if (!isNaN(n) && n >= 1 && n <= total)
                                                enabled.add(n);
                                        }
                                    }
                                    // disabled = all cores NOT in the enabled set
                                    const disabled = [];
                                    for (let i = 1; i <= total; i++) {
                                        if (!enabled.has(i))
                                            disabled.push(i - 1); // 0-based
                                    }
                                    cfg_disabledCoresStr = disabled.join(",");
                                }

                                // Reflect current cfg back to the field
                                function refreshFromCfg() {
                                    const dis = new Set((cfg_disabledCoresStr || "").split(",").filter(Boolean).map(Number));
                                    // Build compact range string for enabled cores
                                    const enabled = [];
                                    for (let i = 0; i < 16; i++) {
                                        if (!dis.has(i))
                                            enabled.push(i + 1);
                                    }
                                    if (enabled.length === 0) {
                                        text = "";
                                        return;
                                    }
                                    if (enabled.length === 16) {
                                        text = "1-16";
                                        return;
                                    }
                                    const ranges = [];
                                    let start = enabled[0], end = enabled[0];
                                    for (let j = 1; j < enabled.length; j++) {
                                        if (enabled[j] === end + 1) {
                                            end = enabled[j];
                                        } else {
                                            ranges.push(start === end ? String(start) : start + "-" + end);
                                            start = end = enabled[j];
                                        }
                                    }
                                    ranges.push(start === end ? String(start) : start + "-" + end);
                                    text = ranges.join(", ");
                                }

                                Component.onCompleted: refreshFromCfg()
                                onEditingFinished: applyRange(text)

                                Connections {
                                    target: root
                                    function onCfg_disabledCoresStrChanged() {
                                        if (!coreRangeField.activeFocus)
                                            coreRangeField.refreshFromCfg();
                                    }
                                }
                            }

                            QQC.Button {
                                text: i18n("All")
                                implicitWidth: 48
                                onClicked: {
                                    cfg_disabledCoresStr = "";
                                    coreRangeField.text = "1-16";
                                }
                            }
                            QQC.Button {
                                text: i18n("None")
                                implicitWidth: 52
                                onClicked: {
                                    const all = [];
                                    for (let i = 0; i < 16; i++)
                                        all.push(i);
                                    cfg_disabledCoresStr = all.join(",");
                                    coreRangeField.text = "";
                                }
                            }
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            text: i18n("Range syntax: 1-8, 10, 13-16  (press Enter to apply)")
                            opacity: 0.50
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Kirigami.Separator {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Core Colors  (C1 – C16)")
                        }
                        GridLayout {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            Kirigami.FormData.label: i18n("Core colors:")
                            columns: 4
                            columnSpacing: 8
                            rowSpacing: 6
                            Repeater {
                                model: 16
                                delegate: RowLayout {
                                    spacing: 4
                                    KQuickControls.ColorButton {
                                        showAlphaChannel: false
                                        implicitWidth: 36
                                        implicitHeight: 28
                                        color: root.coreColorAt(index)
                                        onColorChanged: root.setCoreColor(index, color.toString())
                                    }
                                    QQC.Label {
                                        text: "C" + (index + 1)
                                        font.pixelSize: 9
                                        opacity: 0.65
                                    }
                                }
                            }
                        }

                        // MEMORY ──────────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 3
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Memory")
                        }
                        KQuickControls.ColorButton {
                            id: memColorDetail
                            visible: cfg_activeSection === 3
                            Kirigami.FormData.label: i18n("RAM color:")
                            showAlphaChannel: false
                            color: memColorButton.color
                            onColorChanged: memColorButton.color = color
                        }
                        KQuickControls.ColorButton {
                            id: swapColorDetail
                            visible: cfg_activeSection === 3
                            Kirigami.FormData.label: i18n("Swap color:")
                            showAlphaChannel: false
                            color: swapColorButton.color
                            onColorChanged: swapColorButton.color = color
                        }

                        // NETWORK DEVICES ─────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 1
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Network Devices")
                        }
                        QQC.ComboBox {
                            id: ifaceCombo
                            visible: cfg_activeSection === 1
                            Kirigami.FormData.label: i18n("Interface:")
                            model: root.detectedIfaces.length > 0 ? root.detectedIfaces : [root.cfg_networkInterface || "auto"]
                            onActivated: root.cfg_networkInterface = currentText
                            function syncFromConfig() {
                                const idx = model.indexOf(root.cfg_networkInterface);
                                currentIndex = idx >= 0 ? idx : 0;
                            }
                            Component.onCompleted: syncFromConfig()
                            Connections {
                                target: root
                                function onDetectedIfacesChanged() {
                                    ifaceCombo.syncFromConfig();
                                }
                            }
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 1
                            text: i18n("\"auto\" picks the busiest non-loopback interface.")
                            opacity: 0.55
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        KQuickControls.ColorButton {
                            id: dlColorDetail
                            visible: cfg_activeSection === 1
                            Kirigami.FormData.label: i18n("Download color:")
                            showAlphaChannel: false
                            color: dlColorButton.color
                            onColorChanged: dlColorButton.color = color
                        }
                        KQuickControls.ColorButton {
                            id: ulColorDetail
                            visible: cfg_activeSection === 1
                            Kirigami.FormData.label: i18n("Upload color:")
                            showAlphaChannel: false
                            color: ulColorButton.color
                            onColorChanged: ulColorButton.color = color
                        }

                        // PING ────────────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Ping Targets")
                        }
                        QQC.TextField {
                            id: targetsField
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Hosts:")
                            placeholderText: "8.8.8.8, 1.1.1.1, 192.168.1.1"
                            Layout.fillWidth: true
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 0
                            text: i18n("Comma-separated — each becomes a selectable tab.")
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        Kirigami.Separator {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Ping Settings")
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Interval:")
                            QQC.SpinBox {
                                id: pingIntervalSpin
                                from: 1
                                to: 60
                                stepSize: 1
                            }
                            QQC.Label {
                                text: i18n("seconds")
                                opacity: 0.55
                            }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Timeout:")
                            QQC.SpinBox {
                                id: pingTimeoutSpin
                                from: 1
                                to: 10
                                stepSize: 1
                            }
                            QQC.Label {
                                text: i18n("seconds")
                                opacity: 0.55
                            }
                        }
                        Kirigami.Separator {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Alert Thresholds")
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Latency warning:")
                            QQC.SpinBox {
                                id: latencyThresholdSpin
                                from: 10
                                to: 2000
                                stepSize: 10
                            }
                            QQC.Label {
                                text: i18n("ms")
                                opacity: 0.55
                            }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Loss warning:")
                            QQC.SpinBox {
                                id: lossThresholdSpin
                                from: 0
                                to: 100
                                stepSize: 1
                            }
                            QQC.Label {
                                text: "%"
                                opacity: 0.55
                            }
                        }
                        KQuickControls.ColorButton {
                            id: pingColorDetail
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Ping line color:")
                            showAlphaChannel: false
                            color: customColorButton.color
                            onColorChanged: customColorButton.color = color
                        }
                        QQC.CheckBox {
                            id: showStatsCB
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Stats bar:")
                            text: i18n("Show AVG / jitter / loss / min-max")
                        }

                        // CUSTOM COMMAND ──────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Custom Command")
                        }
                        QQC.TextField {
                            id: customCmdField
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Shell command:")
                            placeholderText: "cat /proc/loadavg | awk '{print $1}'"
                            Layout.fillWidth: true
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 4
                            text: i18n("Must print a single number to stdout.")
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        QQC.TextField {
                            id: customCmdUnitField
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Unit suffix:")
                            placeholderText: "°C, %, RPM …"
                        }
                        RowLayout {
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Max value (Y-axis):")
                            QQC.SpinBox {
                                id: customCmdMaxSpin
                                from: 1
                                to: 100000
                                stepSize: 1
                            }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Poll interval:")
                            QQC.SpinBox {
                                id: customCmdIntervalSpin
                                from: 1
                                to: 3600
                                stepSize: 1
                            }
                            QQC.Label {
                                text: i18n("seconds")
                                opacity: 0.55
                            }
                        }
                        KQuickControls.ColorButton {
                            id: customCmdColorButton
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Graph color:")
                            showAlphaChannel: false
                        }

                        // DISK I/O ────────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 5
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Disk I/O")
                        }
                        QQC.ComboBox {
                            id: diskCombo
                            visible: cfg_activeSection === 5
                            Kirigami.FormData.label: i18n("Device:")
                            model: root.detectedDisks.length > 0 ? root.detectedDisks : [root.cfg_diskDevice || "auto"]
                            onActivated: root.cfg_diskDevice = currentText
                            function syncFromConfig() {
                                const idx = model.indexOf(root.cfg_diskDevice);
                                currentIndex = idx >= 0 ? idx : 0;
                            }
                            Component.onCompleted: syncFromConfig()
                            Connections {
                                target: root
                                function onDetectedDisksChanged() {
                                    diskCombo.syncFromConfig();
                                }
                            }
                        }
                        KQuickControls.ColorButton {
                            id: diskRdColorDetail
                            visible: cfg_activeSection === 5
                            Kirigami.FormData.label: i18n("Read color:")
                            showAlphaChannel: false
                            color: diskRdColorButton.color
                            onColorChanged: diskRdColorButton.color = color
                        }
                        KQuickControls.ColorButton {
                            id: diskWrColorDetail
                            visible: cfg_activeSection === 5
                            Kirigami.FormData.label: i18n("Write color:")
                            showAlphaChannel: false
                            color: diskWrColorButton.color
                            onColorChanged: diskWrColorButton.color = color
                        }

                        // GPU ─────────────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 6
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("GPU")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 6
                            text: i18n("Auto-detects NVIDIA (nvidia-smi), AMD (rocm-smi / sysfs), or Intel (i915 RC6). Falls back to kernel fdinfo on any GPU.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        KQuickControls.ColorButton {
                            id: gpuColorDetail
                            visible: cfg_activeSection === 6
                            Kirigami.FormData.label: i18n("GPU color:")
                            showAlphaChannel: false
                            color: gpuColorButton.color
                            onColorChanged: gpuColorButton.color = color
                        }

                        // HARDWARE SENSORS ────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 7
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Hardware Sensors")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 7
                            text: i18n("Reads lm-sensors output. Run sudo sensors-detect once to configure chip drivers.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            visible: cfg_activeSection === 7
                            Kirigami.FormData.label: i18n("Warn above:")
                            QQC.SpinBox {
                                id: hwTempWarnSpinVisible
                                from: 30
                                to: 120
                                stepSize: 1
                                value: hwTempWarnSpin.value
                                onValueModified: hwTempWarnSpin.value = value
                                Connections {
                                    target: hwTempWarnSpin
                                    function onValueChanged() {
                                        hwTempWarnSpinVisible.value = hwTempWarnSpin.value;
                                    }
                                }
                            }
                            QQC.Label {
                                text: "°C"
                                opacity: 0.55
                            }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 7
                            Kirigami.FormData.label: i18n("Critical above:")
                            QQC.SpinBox {
                                id: hwTempCritSpinVisible
                                from: 30
                                to: 120
                                stepSize: 1
                                value: hwTempCritSpin.value
                                onValueModified: hwTempCritSpin.value = value
                                Connections {
                                    target: hwTempCritSpin
                                    function onValueChanged() {
                                        hwTempCritSpinVisible.value = hwTempCritSpin.value;
                                    }
                                }
                            }
                            QQC.Label {
                                text: "°C"
                                opacity: 0.55
                            }
                        }

                        // OPERATING SYSTEM ────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 8
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Operating System")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 8
                            text: i18n("Shows OS name, kernel version, hostname, and uptime. Refreshes every 30 seconds.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }

                        // POWER & PRESSURE ────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection === 9
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Power & Pressure")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 9
                            text: i18n("Shows battery level and status, plus CPU and memory PSI pressure (avg10). Pressure bars scale to 20% = full.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
