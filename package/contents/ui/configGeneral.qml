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
    property int    cfg_activeSection:      0
    property alias  cfg_showCpuCores:       showCpuCoresCB.checked

    property alias  cfg_pingTitle:          pingTitleField.text
    property alias  cfg_networkTitle:       networkTitleField.text
    property alias  cfg_cpuTitle:           cpuTitleField.text
    property alias  cfg_memoryTitle:        memoryTitleField.text
    property alias  cfg_customCmdTitle:     customCmdTitleField.text

    property alias  cfg_customCmd:          customCmdField.text
    property alias  cfg_customCmdUnit:      customCmdUnitField.text
    property alias  cfg_customCmdMax:       customCmdMaxSpin.value
    property alias  cfg_customCmdInterval:  customCmdIntervalSpin.value
    property alias  cfg_customCmdColor:     customCmdColorButton.color

    property alias  cfg_targets:            targetsField.text
    property alias  cfg_pingInterval:       pingIntervalSpin.value
    property alias  cfg_pingTimeout:        pingTimeoutSpin.value
    property alias  cfg_historySize:        historySizeSpin.value
    property alias  cfg_latencyThreshold:   latencyThresholdSpin.value
    property alias  cfg_lossThreshold:      lossThresholdSpin.value

    property string cfg_networkInterface:   "auto"

    property alias  cfg_useSystemAccent:    useSystemAccentCB.checked
    property alias  cfg_customColor:        customColorButton.color
    property alias  cfg_useSystemTextColor: useSystemTextColorCB.checked
    property alias  cfg_customTextColor:    customTextColorButton.color

    property alias  cfg_dlColor:            dlColorButton.color
    property alias  cfg_ulColor:            ulColorButton.color
    property alias  cfg_cpuColor:           cpuColorButton.color
    property alias  cfg_memColor:           memColorButton.color
    property alias  cfg_swapColor:          swapColorButton.color

    property string cfg_coreColorsStr: "#ff4466,#ff8833,#eebb00,#88dd00,#00ddbb,#22aaff,#9955ff,#ff44bb,#ff7744,#aaff44,#44ffdd,#4499ff,#ffaa44,#ccff44,#44ffcc,#aa44ff"

    property alias  cfg_chartType:         chartTypeCombo.currentIndex
    property alias  cfg_lineWidth:         lineWidthSlider.value
    property alias  cfg_glowLine:          glowLineCB.checked
    property alias  cfg_showStats:         showStatsCB.checked
    property alias  cfg_showLegend:        showLegendCB.checked
    property alias  cfg_showYLabels:       showYLabelsCB.checked
    property alias  cfg_showGridLines:     showGridLinesCB.checked
    property alias  cfg_autoYRange:        autoYRangeCB.checked
    property alias  cfg_fillOpacity:       fillOpacitySlider.value
    property alias  cfg_smoothLines:       smoothLinesCB.checked
    property alias  cfg_showBg:            showBgCB.checked
    property alias  cfg_bgColor:           bgColorButton.color
    property alias  cfg_bgRadius:          bgRadiusSlider.value

    // ── helpers ───────────────────────────────────────────────────────────────
    property var detectedIfaces: []

    // Hidden fields so aliases don't break
    QQC.TextField { id: pingTitleField;      visible: false }
    QQC.TextField { id: networkTitleField;   visible: false }
    QQC.TextField { id: cpuTitleField;       visible: false }
    QQC.TextField { id: memoryTitleField;    visible: false }
    QQC.TextField { id: customCmdTitleField; visible: false }

    KQuickControls.ColorButton { id: dlColorButton;   visible: false; showAlphaChannel: false }
    KQuickControls.ColorButton { id: ulColorButton;   visible: false; showAlphaChannel: false }
    KQuickControls.ColorButton { id: cpuColorButton;  visible: false; showAlphaChannel: false }
    KQuickControls.ColorButton { id: memColorButton;  visible: false; showAlphaChannel: false }
    KQuickControls.ColorButton { id: swapColorButton; visible: false; showAlphaChannel: false }

    P5Support.DataSource {
        id: ifaceSource; engine: "executable"; connectedSources: []
        onNewData: function(sourceName, data) {
            ifaceSource.disconnectSource(sourceName)
            const ifaces = ["auto"]
            for (const line of (data["stdout"] || "").split("\n")) {
                const m = line.trim().match(/^(\w+):/)
                if (m && m[1] !== "lo") ifaces.push(m[1])
            }
            root.detectedIfaces = ifaces
            const idx = ifaces.indexOf(root.cfg_networkInterface)
            ifaceCombo.currentIndex = idx >= 0 ? idx : 0
        }
    }
    Component.onCompleted: ifaceSource.connectSource("cat /proc/net/dev")

    function coreColorAt(i) {
        const parts = cfg_coreColorsStr.split(",")
        return parts[i] || "#888888"
    }
    function setCoreColor(i, color) {
        const parts = cfg_coreColorsStr.split(",")
        while (parts.length <= i) parts.push("#888888")
        parts[i] = color
        cfg_coreColorsStr = parts.join(",")
    }

    function titleForSection(s) {
        if (s === 0) return cfg_pingTitle
        if (s === 1) return cfg_networkTitle
        if (s === 2) return cfg_cpuTitle
        if (s === 3) return cfg_memoryTitle
        if (s === 4) return cfg_customCmdTitle
        return ""
    }
    function setTitleForSection(s, v) {
        if (s === 0) cfg_pingTitle = v
        else if (s === 1) cfg_networkTitle = v
        else if (s === 2) cfg_cpuTitle = v
        else if (s === 3) cfg_memoryTitle = v
        else if (s === 4) cfg_customCmdTitle = v
    }

    readonly property var sensorCategories: [
        { icon: "cpu-symbolic",                label: i18n("CPUs"),               section: 2  },
        { icon: "drive-harddisk-symbolic",     label: i18n("Disks"),              section: -1 },
        { icon: "video-display-symbolic",      label: i18n("GPU"),                section: -1 },
        { icon: "sensor-symbolic",             label: i18n("Hardware Sensors"),   section: -1 },
        { icon: "media-flash-symbolic",        label: i18n("Memory"),             section: 3  },
        { icon: "network-wired-symbolic",      label: i18n("Network Devices"),    section: 1  },
        { icon: "network-workgroup-symbolic",  label: i18n("Network / Ping"),     section: 0  },
        { icon: "system-run-symbolic",         label: i18n("Operating System"),   section: -1 },
        { icon: "battery-symbolic",            label: i18n("Power & Pressure"),   section: -1 },
        { icon: "utilities-terminal-symbolic", label: i18n("Custom Command"),     section: 4  }
    ]

    // ── Root layout ───────────────────────────────────────────────────────────
    header: QQC.TabBar {
        id: tabBar
        QQC.TabButton { text: i18n("Appearance") }
        QQC.TabButton { text: i18n("Chart Details") }
        QQC.TabButton { text: i18n("Sensor Details") }
    }

    ColumnLayout {
        spacing: 0

        // ── TAB CONTENT ───────────────────────────────────────────────────────
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: {
                let m = 400
                for (let i = 0; i < tabStack.children.length; i++) {
                    const c = tabStack.children[i]
                    if (c && c.implicitHeight > m) m = c.implicitHeight
                }
                return m
            }
            currentIndex: tabBar.currentIndex

            // ══════════════════════════════════════════════════════════════════
            // TAB 1 — APPEARANCE
            // ══════════════════════════════════════════════════════════════════
            Kirigami.FormLayout {
                Layout.fillWidth: true

                // Title ────────────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Title")
                }

                QQC.TextField {
                    id: titleEditField
                    Kirigami.FormData.label: i18n("Widget title:")
                    Layout.fillWidth: true
                    text: root.titleForSection(cfg_activeSection)
                    onTextEdited: root.setTitleForSection(cfg_activeSection, text)
                }

                QQC.CheckBox {
                    id: showBgCB
                    Kirigami.FormData.label: i18n("Background card:")
                    text: i18n("Show glassy background")
                }

                // Display Style ───────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Display Style")
                }

                QQC.ComboBox {
                    id: chartTypeCombo
                    Kirigami.FormData.label: i18n("Chart type:")
                    Layout.minimumWidth: 220
                    model: ListModel {
                        ListElement { text: "Line  —  smooth curve"   }
                        ListElement { text: "Bars  —  vertical bars"  }
                        ListElement { text: "Filled Area"             }
                        ListElement { text: "Donut / Ring"            }
                        ListElement { text: "Pie Chart"               }
                        ListElement { text: "Horizontal Bars"         }
                        ListElement { text: "Text Only  —  no graph"  }
                    }
                    textRole: "text"
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Min. update interval:")
                    QQC.SpinBox { id: historySizeSpin; from: 10; to: 300; stepSize: 10 }
                    QQC.Label { text: i18n("history points"); opacity: 0.55 }
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
                    Kirigami.FormData.label: i18n("Custom text color:")
                    visible: !useSystemTextColorCB.checked
                    showAlphaChannel: false
                }

                QQC.CheckBox {
                    id: useSystemAccentCB
                    Kirigami.FormData.label: i18n("Accent / ping color:")
                    text: i18n("Use system accent color")
                }
                KQuickControls.ColorButton {
                    id: customColorButton
                    Kirigami.FormData.label: i18n("Custom accent color:")
                    visible: !useSystemAccentCB.checked
                    showAlphaChannel: false
                }

                // Background Card ─────────────────────────────────────────────
                Kirigami.Separator {
                    visible: showBgCB.checked
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Background Card")
                }

                KQuickControls.ColorButton {
                    id: bgColorButton
                    Kirigami.FormData.label: i18n("Card color + opacity:")
                    visible: showBgCB.checked
                    showAlphaChannel: true
                }
                QQC.Label {
                    text: i18n("Use the alpha slider to control transparency.")
                    visible: showBgCB.checked
                    opacity: 0.55; font.pixelSize: 10; wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                RowLayout {
                    visible: showBgCB.checked
                    Kirigami.FormData.label: i18n("Corner radius:")
                    QQC.Slider { id: bgRadiusSlider; from: 0; to: 30; stepSize: 1; Layout.minimumWidth: 130 }
                    QQC.Label { text: bgRadiusSlider.value.toFixed(0) + " px"; Layout.minimumWidth: 36 }
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 2 — CHART DETAILS
            // ══════════════════════════════════════════════════════════════════
            Kirigami.FormLayout {
                Layout.fillWidth: true

                // Chart Style ──────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Chart Style")
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
                RowLayout {
                    Kirigami.FormData.label: i18n("Line width:")
                    QQC.Slider { id: lineWidthSlider; from: 0.8; to: 6.0; stepSize: 0.2; Layout.minimumWidth: 130 }
                    QQC.Label { text: lineWidthSlider.value.toFixed(1) + " px"; Layout.minimumWidth: 36 }
                }
                RowLayout {
                    Kirigami.FormData.label: i18n("Area fill opacity:")
                    QQC.Slider { id: fillOpacitySlider; from: 0.0; to: 1.0; stepSize: 0.05; Layout.minimumWidth: 130 }
                    QQC.Label { text: (fillOpacitySlider.value * 100).toFixed(0) + "%"; Layout.minimumWidth: 36 }
                }

                // Legend & Axes ───────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Legend & Axes")
                }

                QQC.CheckBox {
                    id: showLegendCB
                    Kirigami.FormData.label: i18n("Legend:")
                    text: i18n("Show color-coded legend below graph")
                }
                QQC.CheckBox {
                    id: showGridLinesCB
                    Kirigami.FormData.label: i18n("Grid lines:")
                    text: i18n("Horizontal grid lines on graph")
                }
                QQC.CheckBox {
                    id: showYLabelsCB
                    Kirigami.FormData.label: i18n("Y-axis labels:")
                    text: i18n("Show scale labels on the left")
                }

                // Data Ranges ─────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Data Ranges")
                }

                QQC.CheckBox {
                    id: autoYRangeCB
                    Kirigami.FormData.label: i18n("Auto Y-range:")
                    text: i18n("Fit axis to visible data")
                }

                // Ping Stats ───────────────────────────────────────────────────
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Ping Stats")
                }

                QQC.CheckBox {
                    id: showStatsCB
                    Kirigami.FormData.label: i18n("Stats bar:")
                    text: i18n("Show AVG / jitter / loss / min-max")
                }
            }

            // ══════════════════════════════════════════════════════════════════
            // TAB 3 — SENSOR DETAILS
            // ══════════════════════════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                // ── Left: category list ──────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth: 180
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.04)
                    border.color: Qt.rgba(0, 0, 0, 0.10)

                    ListView {
                        id: sensorCatList
                        anchors { fill: parent; margins: 4 }
                        clip: true
                        model: root.sensorCategories
                        currentIndex: {
                            for (let i = 0; i < root.sensorCategories.length; i++) {
                                if (root.sensorCategories[i].section === cfg_activeSection) return i
                            }
                            return 0
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
                                    implicitWidth: 16; implicitHeight: 16
                                    opacity: catDelegate.enabled ? 1.0 : 0.35
                                }
                                QQC.Label {
                                    text: modelData.label
                                    font.pixelSize: 13
                                    color: catDelegate.highlighted
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Kirigami.Theme.textColor
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
                                    cfg_activeSection = modelData.section
                                }
                            }
                        }
                    }
                }

                // ── Right: detail panel ──────────────────────────────────────
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 300
                    contentWidth: width
                    contentHeight: sensorDetailForm.implicitHeight
                    clip: true

                    Kirigami.FormLayout {
                        id: sensorDetailForm
                        width: parent.width
                        anchors.left: parent.left
                        anchors.right: parent.right

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
                        Kirigami.Separator {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Core Colors  (C1 – C16)")
                        }
                        GridLayout {
                            visible: cfg_activeSection === 2 && showCpuCoresCB.checked
                            Kirigami.FormData.label: i18n("Core colors:")
                            columns: 4; columnSpacing: 8; rowSpacing: 6
                            Repeater {
                                model: 16
                                delegate: RowLayout {
                                    spacing: 4
                                    KQuickControls.ColorButton {
                                        showAlphaChannel: false
                                        implicitWidth: 36; implicitHeight: 28
                                        color: root.coreColorAt(index)
                                        onColorChanged: root.setCoreColor(index, color.toString())
                                    }
                                    QQC.Label { text: "C" + (index + 1); font.pixelSize: 9; opacity: 0.65 }
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
                                const idx = model.indexOf(root.cfg_networkInterface)
                                currentIndex = idx >= 0 ? idx : 0
                            }
                            Component.onCompleted: syncFromConfig()
                            Connections {
                                target: root
                                function onDetectedIfacesChanged() { ifaceCombo.syncFromConfig() }
                            }
                        }
                        QQC.Label {
                            visible: cfg_activeSection === 1
                            text: i18n("\"auto\" picks the busiest non-loopback interface.")
                            opacity: 0.55; font.pixelSize: 10; wrapMode: Text.WordWrap
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
                            opacity: 0.55; font.pixelSize: 10
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
                            QQC.SpinBox { id: pingIntervalSpin; from: 1; to: 60; stepSize: 1 }
                            QQC.Label { text: i18n("seconds"); opacity: 0.55 }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Timeout:")
                            QQC.SpinBox { id: pingTimeoutSpin; from: 1; to: 10; stepSize: 1 }
                            QQC.Label { text: i18n("seconds"); opacity: 0.55 }
                        }
                        Kirigami.Separator {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Alert Thresholds")
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Latency warning:")
                            QQC.SpinBox { id: latencyThresholdSpin; from: 10; to: 2000; stepSize: 10 }
                            QQC.Label { text: i18n("ms"); opacity: 0.55 }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Loss warning:")
                            QQC.SpinBox { id: lossThresholdSpin; from: 0; to: 100; stepSize: 1 }
                            QQC.Label { text: "%"; opacity: 0.55 }
                        }
                        KQuickControls.ColorButton {
                            id: pingColorDetail
                            visible: cfg_activeSection === 0
                            Kirigami.FormData.label: i18n("Ping line color:")
                            showAlphaChannel: false
                            color: customColorButton.color
                            onColorChanged: customColorButton.color = color
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
                            opacity: 0.55; font.pixelSize: 10
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
                            QQC.SpinBox { id: customCmdMaxSpin; from: 1; to: 100000; stepSize: 1 }
                        }
                        RowLayout {
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Poll interval:")
                            QQC.SpinBox { id: customCmdIntervalSpin; from: 1; to: 3600; stepSize: 1 }
                            QQC.Label { text: i18n("seconds"); opacity: 0.55 }
                        }
                        KQuickControls.ColorButton {
                            id: customCmdColorButton
                            visible: cfg_activeSection === 4
                            Kirigami.FormData.label: i18n("Graph color:")
                            showAlphaChannel: false
                        }

                        // COMING SOON ─────────────────────────────────────────
                        Kirigami.Separator {
                            visible: cfg_activeSection < 0
                            Kirigami.FormData.isSection: true
                            Kirigami.FormData.label: i18n("Coming soon")
                        }
                        QQC.Label {
                            visible: cfg_activeSection < 0
                            text: i18n("This sensor category will be available in a future version.")
                            wrapMode: Text.WordWrap; opacity: 0.55
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
