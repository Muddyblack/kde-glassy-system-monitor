import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.plasma5support as P5Support
import "OsFetch.js" as OsFetch

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
    property alias cfg_customCmdColor: customCmdColorRow.color

    property alias cfg_targets: targetsField.text
    property alias cfg_pingInterval: pingIntervalSpin.value
    property alias cfg_pingTimeout: pingTimeoutSpin.value
    property alias cfg_historySize: historySizeSpin.value
    property alias cfg_updateInterval: updateIntervalSpin.value
    property alias cfg_latencyThreshold: latencyThresholdSpin.value
    property alias cfg_lossThreshold: lossThresholdSpin.value
    property alias cfg_jitterThreshold: jitterThresholdSpin.value
    property alias cfg_pingAlertPulse: pingAlertPulseCB.checked
    property alias cfg_pingThresholdColors: pingThresholdColorsCB.checked

    property string cfg_networkInterface: "auto"
    property string cfg_gpuDevice: "auto"

    property alias cfg_useSystemAccent: useSystemAccentCB.checked
    property alias cfg_customColor: customColorRow.color
    property alias cfg_useSystemTextColor: useSystemTextColorCB.checked
    property alias cfg_customTextColor: customTextColorRow.color

    property alias cfg_pingColor: pingColorButton.color
    property alias cfg_pingWarnColor: pingWarnColorButton.color
    property alias cfg_pingCritColor: pingCritColorButton.color
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
    property alias cfg_bgColor: bgColorRow.color
    property alias cfg_bgRadiusTL: bgRadiusTLSlider.value
    property alias cfg_bgRadiusTR: bgRadiusTRSlider.value
    property alias cfg_bgRadiusBR: bgRadiusBRSlider.value
    property alias cfg_bgRadiusBL: bgRadiusBLSlider.value
    property alias cfg_cardBorder: cardBorderCB.checked
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
    property alias cfg_osUseFetch: osUseFetchCB.checked
    property alias cfg_osFetchCmd: osFetchCmdField.text
    property alias cfg_osPlainText: osPlainTextCB.checked
    property alias cfg_osShowLogo: osShowLogoCB.checked
    // StringList — bound directly rather than via an alias, since there is no
    // single control backing it.
    property var cfg_osFieldRules: []
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
    property var detectedGpus: []
    property var detectedDisks: []

    // KDE's colour dialog only ever shows #RRGGBB and hides the alpha byte
    // behind a percentage slider, so an exact translucency can't be copied
    // between widgets. These render/parse the full #AARRGGBB form that the
    // config actually stores, for the hex field next to the card colour.
    function argbHex(c) {
        function hex2(v) {
            return ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2);
        }
        return "#" + hex2(c.a) + hex2(c.r) + hex2(c.g) + hex2(c.b);
    }

    // Accepts #AARRGGBB, #RRGGBB and #RGB (with or without the #);
    // returns null when the text isn't a valid colour so the caller can revert.
    function parseArgbHex(s) {
        var t = String(s).trim().replace(/^#/, "");
        if (!/^[0-9a-fA-F]+$/.test(t))
            return null;
        if (t.length === 3)
            t = "ff" + t[0] + t[0] + t[1] + t[1] + t[2] + t[2];
        else if (t.length === 6)
            t = "ff" + t;
        else if (t.length !== 8)
            return null;
        function chan(i) {
            return parseInt(t.substr(i * 2, 2), 16) / 255;
        }
        return Qt.rgba(chan(1), chan(2), chan(3), chan(0));
    }

    // #aarrggbb for colours where transparency is configurable, #rrggbb for the
    // opaque graph colours (an always-ff alpha byte would just be noise there).
    function hexOf(c, withAlpha) {
        return withAlpha ? argbHex(c) : "#" + argbHex(c).substr(3);
    }

    // Colour button + editable hex field + copy button. KDE's dialog shows no
    // hex code at all and buries alpha behind a percent slider, so the exact
    // value can't be copied between stacked widgets; this puts it in reach
    // without replacing the picker itself.
    component ColorHexRow: RowLayout {
        id: chr

        property alias color: chrButton.color
        property bool showAlpha: false
        property string label: ""

        Kirigami.FormData.label: chr.label
        spacing: Kirigami.Units.smallSpacing

        KQuickControls.ColorButton {
            id: chrButton
            showAlphaChannel: chr.showAlpha
            // Title is only applied when the dialog opens, so it must not carry
            // the hex code — it would freeze at the value the picker started
            // from while the field below updates live.
            dialogTitle: String(chr.label).replace(/:$/, "")
            onColorChanged: {
                if (!chrField.activeFocus)
                    chrField.text = root.hexOf(color, chr.showAlpha);
            }
        }
        QQC.TextField {
            id: chrField
            Layout.minimumWidth: chr.showAlpha ? 105 : 92
            maximumLength: 9
            font.family: "monospace"
            placeholderText: chr.showAlpha ? "#aarrggbb" : "#rrggbb"
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            Component.onCompleted: text = root.hexOf(chrButton.color, chr.showAlpha)
            // Apply on Enter/focus-loss, then re-render from the colour so
            // partial or invalid input snaps back to the real value.
            onEditingFinished: {
                const c = root.parseArgbHex(text);
                if (c)
                    chrButton.color = chr.showAlpha ? c : Qt.rgba(c.r, c.g, c.b, 1);
                text = root.hexOf(chrButton.color, chr.showAlpha);
            }
        }
        QQC.Button {
            icon.name: "edit-copy"
            display: QQC.AbstractButton.IconOnly
            flat: true
            QQC.ToolTip.visible: hovered
            QQC.ToolTip.text: i18n("Copy hex code")
            onClicked: {
                chrField.selectAll();
                chrField.copy();
                chrField.deselect();
            }
        }
    }

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
        id: pingColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: pingWarnColorButton
        visible: false
        showAlphaChannel: false
    }
    KQuickControls.ColorButton {
        id: pingCritColorButton
        visible: false
        showAlphaChannel: false
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
    P5Support.DataSource {
        id: gpuDetectSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            gpuDetectSource.disconnectSource(sourceName);
            const gpus = [
                {
                    value: "auto",
                    label: i18n("auto — first GPU reporting telemetry")
                }
            ];
            for (const line of (data["stdout"] || "").split("\n")) {
                const p = line.trim().split("|");
                if (p.length < 4 || !/^card\d+$/.test(p[0]))
                    continue;
                // lspci is optional; fall back to the vendor name when absent.
                const vendor = p[1] === "0x10de" ? "NVIDIA" : p[1] === "0x1002" ? "AMD" : p[1] === "0x8086" ? "Intel" : i18n("Unknown vendor");
                const name = (p[4] || "").trim() || vendor;
                gpus.push({
                    value: p[2],
                    label: p[0] + " — " + name + " (" + p[2] + ")"
                });
            }
            root.detectedGpus = gpus;
        }
    }
    // ── OS Info field detection ───────────────────────────────────────────────
    // Runs the same probe main.qml uses, so what the list shows is exactly what
    // the widget would render.
    property bool osProbing: false
    property string osProbeTool: ""
    property string osProbeError: ""
    ListModel {
        id: osFieldModel
    }

    P5Support.DataSource {
        id: osProbeSource
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            osProbeSource.disconnectSource(sourceName);
            root.osProbing = false;
            const r = OsFetch.parse(data["stdout"] || "");
            root.osProbeTool = r.tool;
            if (!r.tool) {
                root.osProbeError = i18n("No fetch tool found. Install fastfetch or neofetch, or set a custom command above.");
                return;
            }
            root.osProbeError = "";
            const merged = OsFetch.mergeRules(r.rows, root.cfg_osFieldRules);
            osFieldModel.clear();
            for (let i = 0; i < merged.length; i++)
                osFieldModel.append(merged[i]);
        }
    }

    function osProbe() {
        if (root.osProbing)
            return;
        root.osProbing = true;
        root.osProbeError = "";
        osProbeSource.connectSource(OsFetch.probeCmd(root.cfg_osFetchCmd));
    }

    // Serialises the model back into the "key" / "!key" rule list.
    function osSaveFields() {
        const out = [];
        for (let i = 0; i < osFieldModel.count; i++) {
            const it = osFieldModel.get(i);
            out.push(OsFetch.makeRule(it.key, it.enabled));
        }
        root.cfg_osFieldRules = out;
    }

    function osMoveField(from, to) {
        if (to < 0 || to >= osFieldModel.count || from === to)
            return;
        osFieldModel.move(from, to, 1);
        root.osSaveFields();
    }

    Component.onCompleted: {
        // Show any saved rules straight away so they stay editable without
        // paying for a probe run (a full fetch is ~0.5 s). "Run test" fills in
        // live sample values and picks up newly reported fields.
        const saved = OsFetch.mergeRules([], root.cfg_osFieldRules);
        for (let i = 0; i < saved.length; i++)
            osFieldModel.append(saved[i]);

        ifaceSource.connectSource("cat /proc/net/dev");
        diskDetectSource.connectSource("cat /proc/diskstats");
        // Same enumeration main.qml uses, plus an lspci lookup for a readable name.
        gpuDetectSource.connectSource("sh -c 'for d in /sys/class/drm/card[0-9]*; do v=$(cat \"$d/device/vendor\" 2>/dev/null); [ -n \"$v\" ] || continue; p=$(readlink -f \"$d/device\" 2>/dev/null); p=${p##*/}; b=0; [ -r \"$d/device/gpu_busy_percent\" ] && b=1; [ -d \"$d/gt/gt0\" ] && b=1; n=$(lspci -mm -s \"$p\" 2>/dev/null | cut -d\\\" -f6); echo \"${d##*/}|$v|$p|$b|$n\"; done'");
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

                ColorHexRow {
                    id: bgColorRow
                    label: i18n("Card color:")
                    showAlpha: true
                }
                QQC.Label {
                    text: i18n("Alpha is the first byte of the hex code (#aarrggbb) — copy it to give stacked widgets an identical transparency. Editable: paste a code and press Enter. Set alpha to 00 for no card at all.")
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Top Left:")
                    QQC.Slider {
                        id: bgRadiusTLSlider
                        from: 0
                        to: 30
                        stepSize: 1
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: bgRadiusTLSlider.value.toFixed(0) + " px"
                        Layout.minimumWidth: 36
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Top Right:")
                    QQC.Slider {
                        id: bgRadiusTRSlider
                        from: 0
                        to: 30
                        stepSize: 1
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: bgRadiusTRSlider.value.toFixed(0) + " px"
                        Layout.minimumWidth: 36
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Bottom Right:")
                    QQC.Slider {
                        id: bgRadiusBRSlider
                        from: 0
                        to: 30
                        stepSize: 1
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: bgRadiusBRSlider.value.toFixed(0) + " px"
                        Layout.minimumWidth: 36
                    }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Bottom Left:")
                    QQC.Slider {
                        id: bgRadiusBLSlider
                        from: 0
                        to: 30
                        stepSize: 1
                        Layout.minimumWidth: 130
                    }
                    QQC.Label {
                        text: bgRadiusBLSlider.value.toFixed(0) + " px"
                        Layout.minimumWidth: 36
                    }
                }

                QQC.CheckBox {
                    id: cardBorderCB
                    Kirigami.FormData.label: i18n("Card edge:")
                    text: i18n("Hairline border and top highlight")
                }
                QQC.CheckBox {
                    id: frostedGlassCB
                    Kirigami.FormData.label: i18n("Frosted glass:")
                    text: i18n("Soft GPU-blurred glass card")
                }
                QQC.Label {
                    text: i18n("Blurs the card's own fill for a premium frosted look (GPU-accelerated). Plasma can't blur the desktop behind the widget, so this frosts the card itself. Off gives a flat translucent card.")
                    visible: frostedGlassCB.checked
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: frostedGlassCB.checked
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
                ColorHexRow {
                    id: customTextColorRow
                    label: i18n("Custom:")
                    visible: !useSystemTextColorCB.checked
                }

                QQC.CheckBox {
                    id: useSystemAccentCB
                    Kirigami.FormData.label: i18n("Accent color:")
                    text: i18n("Use system accent color")
                }
                ColorHexRow {
                    id: customColorRow
                    label: i18n("Custom:")
                    visible: !useSystemAccentCB.checked
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
                    Kirigami.FormData.label: i18n("Polling")
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Update interval:")
                    QQC.SpinBox {
                        id: updateIntervalSpin
                        from: 250
                        to: 60000
                        stepSize: 250
                        editable: true
                    }
                    QQC.Label {
                        text: i18n("ms (%1 s)", (updateIntervalSpin.value / 1000).toFixed(2))
                        opacity: 0.55
                    }
                }
                QQC.Label {
                    text: i18n("Base polling rate for all sensors. CPU, Network and Disk poll at this rate; Memory and GPU at 2x; Network info at 8x; Hardware Sensors at 3x; Power at 5x; OS Info at 30x. Higher values use less CPU — every poll forks a shell, so below ~500 ms the process spawns cost more than the extra detail is worth.")
                    opacity: 0.50
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

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
                // It has to follow the form's real height rather than a fixed value:
                // a constant clipped tall sections (the OS field list runs to ~700 px)
                // at a fixed point regardless of window size. Growing with the content
                // lets SimpleKCM's own scroll view do the scrolling, so there is no
                // nested scroll area. The floor keeps the category list usable when a
                // section's settings are short.
                Layout.preferredHeight: Math.max(520, sensorDetailForm.implicitHeight + Kirigami.Units.largeSpacing * 2)
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
                        ColorHexRow {
                            id: cpuColorDetail
                            visible: cfg_activeSection === 2
                            label: i18n("CPU total color:")
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
                        ColorHexRow {
                            id: memColorDetail
                            visible: cfg_activeSection === 3
                            label: i18n("RAM color:")
                            color: memColorButton.color
                            onColorChanged: memColorButton.color = color
                        }
                        ColorHexRow {
                            id: swapColorDetail
                            visible: cfg_activeSection === 3
                            label: i18n("Swap color:")
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
                        ColorHexRow {
                            id: dlColorDetail
                            visible: cfg_activeSection === 1
                            label: i18n("Download color:")
                            color: dlColorButton.color
                            onColorChanged: dlColorButton.color = color
                        }
                        ColorHexRow {
                            id: ulColorDetail
                            visible: cfg_activeSection === 1
                            label: i18n("Upload color:")
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
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Jitter warning:")
                            QQC.SpinBox {
                                id: jitterThresholdSpin
                                from: 1
                                to: 1000
                                stepSize: 1
                            }
                            QQC.Label {
                                text: i18n("ms")
                                opacity: 0.55
                            }
                        }
                        ColorHexRow {
                            id: pingColorDetail
                            visible: cfg_activeSection === 0
                            label: i18n("Ping line color:")
                            color: pingColorButton.color
                            onColorChanged: pingColorButton.color = color
                        }
                        QQC.CheckBox {
                            id: pingAlertPulseCB
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Alert pulse:")
                            text: i18n("Pulse a border while over the thresholds")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 0
                            text: i18n("Turn off if latency sits near the threshold — the border strobes as the alert flips on and off.")
                            opacity: 0.55
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        QQC.CheckBox {
                            id: pingThresholdColorsCB
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Threshold colors:")
                            text: i18n("Recolor the graph above the warning thresholds")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 0
                            text: i18n("Off keeps the graph on your ping color at any latency. Packet loss is always marked in the critical color.")
                            opacity: 0.55
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ColorHexRow {
                            id: pingWarnColorDetail
                            visible: cfg_activeSection === 0 && pingThresholdColorsCB.checked
                            label: i18n("Warning color:")
                            color: pingWarnColorButton.color
                            onColorChanged: pingWarnColorButton.color = color
                        }
                        ColorHexRow {
                            id: pingCritColorDetail
                            visible: cfg_activeSection === 0
                            label: i18n("Critical color:")
                            color: pingCritColorButton.color
                            onColorChanged: pingCritColorButton.color = color
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
                        ColorHexRow {
                            id: customCmdColorRow
                            visible: cfg_activeSection === 4
                            label: i18n("Graph color:")
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
                        ColorHexRow {
                            id: diskRdColorDetail
                            visible: cfg_activeSection === 5
                            label: i18n("Read color:")
                            color: diskRdColorButton.color
                            onColorChanged: diskRdColorButton.color = color
                        }
                        ColorHexRow {
                            id: diskWrColorDetail
                            visible: cfg_activeSection === 5
                            label: i18n("Write color:")
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
                            text: i18n("Auto-detects NVIDIA (nvidia-smi), AMD (sysfs busy% / VRAM), or Intel (i915 RC6). Falls back to kernel fdinfo on any GPU.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        QQC.ComboBox {
                            id: gpuCombo
                            visible: cfg_activeSection === 6
                            Kirigami.FormData.label: i18n("Device:")
                            Layout.minimumWidth: 260
                            // Editable so an unlisted card can still be entered by
                            // hand — detection needs sysfs, which is not guaranteed.
                            editable: true
                            model: root.detectedGpus
                            textRole: "label"
                            valueRole: "value"
                            onActivated: root.cfg_gpuDevice = currentValue
                            // Track every edit rather than onAccepted alone: that
                            // only fires on Enter, so text typed and then applied
                            // straight away would otherwise be dropped.
                            onEditTextChanged: {
                                if (!activeFocus)
                                    return;   // programmatic sync, not the user typing
                                // Store the entry's value when the text is a label we
                                // know, so picking from the list never stores a label.
                                const hit = root.detectedGpus.find(g => g.label === editText);
                                root.cfg_gpuDevice = hit ? hit.value : editText.trim();
                            }
                            function syncFromConfig() {
                                const idx = indexOfValue(root.cfg_gpuDevice);
                                if (idx >= 0)
                                    currentIndex = idx;
                                else
                                    editText = root.cfg_gpuDevice;   // unlisted / hand-typed
                            }
                            Component.onCompleted: syncFromConfig()
                            Connections {
                                target: root
                                function onDetectedGpusChanged() {
                                    gpuCombo.syncFromConfig();
                                }
                            }
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 6
                            text: i18n("\"auto\" prefers a GPU that actually reports counters, so a dormant iGPU is skipped. You can also type a PCI address (0000:03:00.0) or a card name (card1).")
                            opacity: 0.55
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        ColorHexRow {
                            id: gpuColorDetail
                            visible: cfg_activeSection === 6
                            label: i18n("GPU color:")
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
                        QQC.CheckBox {
                            id: osUseFetchCB
                            visible: cfg_activeSection === 8
                            text: i18n("Use a system fetch tool when available")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 8
                            text: i18n("Looks for fastfetch, neofetch, screenfetch, macchina or hyfetch (in that order) and shows everything the first one found reports. Falls back to the four built-in rows when none is installed.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        QQC.TextField {
                            id: osFetchCmdField
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked
                            Kirigami.FormData.label: i18n("Custom command:")
                            placeholderText: "fastfetch --logo none --pipe true"
                            Layout.fillWidth: true
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked
                            text: i18n("Optional. Must print \"Key: Value\" lines to stdout. Auto-detection takes over if this command is not installed.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        QQC.CheckBox {
                            id: osShowLogoCB
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked
                            text: i18n("Show distribution logo")
                        }
                        QQC.CheckBox {
                            id: osPlainTextCB
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked
                            text: i18n("Plain text output")
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked
                            text: i18n("Renders the tool output verbatim in a monospace block instead of aligned rows.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }

                        // FIELD PICKER ────────────────────────────────────────
                        // Plain-text mode prints the tool output verbatim, so
                        // per-field rules do not apply there.
                        Kirigami.Separator {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked && !osPlainTextCB.checked
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Fields")
                        }
                        RowLayout {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked && !osPlainTextCB.checked
                            Layout.fillWidth: true
                            spacing: 8

                            QQC.Button {
                                text: root.osProbing ? i18n("Running…") : i18n("Run test")
                                enabled: !root.osProbing
                                icon.name: "system-run"
                                onClicked: root.osProbe()
                            }
                            QQC.Button {
                                text: i18n("Reset order")
                                icon.name: "edit-undo"
                                visible: osFieldModel.count > 0
                                onClicked: {
                                    root.cfg_osFieldRules = [];
                                    root.osProbe();
                                }
                            }
                            QQC.Label {
                                Layout.fillWidth: true
                                text: root.osProbeError ? root.osProbeError : root.osProbeTool ? i18n("%1 — %2 fields", root.osProbeTool, osFieldModel.count) : i18n("Run the detected command and list the fields it reports.")
                                color: root.osProbeError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                                opacity: root.osProbeError ? 1.0 : 0.55
                                wrapMode: Text.WordWrap
                                font.pixelSize: 10
                            }
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked && !osPlainTextCB.checked && osFieldModel.count > 0
                            text: i18n("Uncheck to hide a field, or reorder with the arrows. Fields a future tool version adds are shown automatically at the end.")
                            wrapMode: Text.WordWrap
                            opacity: 0.55
                            font.pixelSize: 10
                            Layout.fillWidth: true
                        }
                        // Rendered as a plain ColumnLayout of natural-height rows
                        // rather than a fixed-height ListView. Kirigami.FormLayout
                        // never assigns its children a height (FormLayout.qml syncs
                        // "item.width = width" with no height counterpart), so any
                        // box relying on Layout.preferredHeight gets squeezed and
                        // clips its contents. Letting the rows size themselves and
                        // the settings page scroll also avoids a nested scroll area
                        // that steals wheel events from the form.
                        ColumnLayout {
                            visible: cfg_activeSection === 8 && osUseFetchCB.checked && !osPlainTextCB.checked && osFieldModel.count > 0
                            Layout.fillWidth: true
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            spacing: 0

                            Repeater {
                                model: osFieldModel

                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    color: index % 2 === 0 ? "transparent" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
                                    radius: 2

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        anchors.rightMargin: 2
                                        spacing: 4

                                        QQC.CheckBox {
                                            checked: model.enabled
                                            onToggled: {
                                                osFieldModel.setProperty(index, "enabled", checked);
                                                root.osSaveFields();
                                            }
                                        }
                                        QQC.Label {
                                            text: model.key
                                            // A key kept from the saved rules that the
                                            // tool no longer reports — still editable,
                                            // just not currently in the output.
                                            opacity: model.present ? 1.0 : 0.5
                                            font.italic: !model.present
                                            Layout.preferredWidth: 150
                                            elide: Text.ElideRight
                                        }
                                        QQC.Label {
                                            text: model.present ? model.sample : i18n("not reported")
                                            opacity: 0.5
                                            font.pixelSize: 10
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        QQC.ToolButton {
                                            icon.name: "arrow-up"
                                            enabled: index > 0
                                            implicitWidth: 24
                                            onClicked: root.osMoveField(index, index - 1)
                                        }
                                        QQC.ToolButton {
                                            icon.name: "arrow-down"
                                            enabled: index < osFieldModel.count - 1
                                            implicitWidth: 24
                                            onClicked: root.osMoveField(index, index + 1)
                                        }
                                    }
                                }
                            }
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
