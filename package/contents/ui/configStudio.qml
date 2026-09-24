import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import "studio" as Studio

// Plasma settings page hosting the studio. Plasma sets every cfg_* property
// (and its *Default) from main.xml and applies them on OK/Apply, so Cancel
// still reverts. The key list is generated from main.xml: keep them in step.
Kirigami.Page {
    id: root
    padding: 0
    implicitWidth: Kirigami.Units.gridUnit * 60
    implicitHeight: Kirigami.Units.gridUnit * 40

    property string cfg_sections
    property string cfg_sectionsDefault
    property int cfg_layoutColumns
    property int cfg_layoutColumnsDefault
    property string cfg_sectionSpans
    property string cfg_sectionSpansDefault
    property string cfg_sectionSizes
    property string cfg_sectionSizesDefault
    property string cfg_userPresets
    property string cfg_userPresetsDefault
    property string cfg_sectionStyles
    property string cfg_sectionStylesDefault
    property string cfg_chartRenderer
    property string cfg_chartRendererDefault
    property int cfg_activeSection
    property int cfg_activeSectionDefault
    property bool cfg_showCpuCores
    property bool cfg_showCpuCoresDefault
    property string cfg_targets
    property string cfg_targetsDefault
    property int cfg_currentTargetIndex
    property int cfg_currentTargetIndexDefault
    property int cfg_pingInterval
    property int cfg_pingIntervalDefault
    property int cfg_pingTimeout
    property int cfg_pingTimeoutDefault
    property int cfg_historySize
    property int cfg_historySizeDefault
    property int cfg_updateInterval
    property int cfg_updateIntervalDefault
    property int cfg_latencyThreshold
    property int cfg_latencyThresholdDefault
    property int cfg_lossThreshold
    property int cfg_lossThresholdDefault
    property int cfg_jitterThreshold
    property int cfg_jitterThresholdDefault
    property bool cfg_pingAlertPulse
    property bool cfg_pingAlertPulseDefault
    property bool cfg_pingThresholdColors
    property bool cfg_pingThresholdColorsDefault
    property string cfg_networkInterface
    property string cfg_networkInterfaceDefault
    property bool cfg_useSystemAccent
    property bool cfg_useSystemAccentDefault
    property string cfg_customColor
    property string cfg_customColorDefault
    property string cfg_pingColor
    property string cfg_pingColorDefault
    property string cfg_pingWarnColor
    property string cfg_pingWarnColorDefault
    property string cfg_pingCritColor
    property string cfg_pingCritColorDefault
    property string cfg_dlColor
    property string cfg_dlColorDefault
    property string cfg_ulColor
    property string cfg_ulColorDefault
    property string cfg_cpuColor
    property string cfg_cpuColorDefault
    property string cfg_memColor
    property string cfg_memColorDefault
    property string cfg_swapColor
    property string cfg_swapColorDefault
    property string cfg_coreColorsStr
    property string cfg_coreColorsStrDefault
    property real cfg_lineWidth
    property real cfg_lineWidthDefault
    property bool cfg_glowLine
    property bool cfg_glowLineDefault
    property int cfg_targetFps
    property int cfg_targetFpsDefault
    property bool cfg_smoothScroll
    property bool cfg_smoothScrollDefault
    property bool cfg_showStats
    property bool cfg_showStatsDefault
    property bool cfg_showLegend
    property bool cfg_showLegendDefault
    property bool cfg_showYLabels
    property bool cfg_showYLabelsDefault
    property string cfg_bgColor
    property string cfg_bgColorDefault
    property string cfg_fontFamily
    property string cfg_fontFamilyDefault
    property real cfg_bgRadiusTL
    property real cfg_bgRadiusTLDefault
    property real cfg_bgRadiusTR
    property real cfg_bgRadiusTRDefault
    property real cfg_bgRadiusBR
    property real cfg_bgRadiusBRDefault
    property real cfg_bgRadiusBL
    property real cfg_bgRadiusBLDefault
    property bool cfg_loadColors
    property bool cfg_loadColorsDefault
    property int cfg_loadWarn
    property int cfg_loadWarnDefault
    property int cfg_loadCrit
    property int cfg_loadCritDefault
    property string cfg_loadWarnColor
    property string cfg_loadWarnColorDefault
    property string cfg_loadCritColor
    property string cfg_loadCritColorDefault
    property string cfg_density
    property string cfg_densityDefault
    property string cfg_storageTitle
    property string cfg_storageTitleDefault
    property string cfg_storageMounts
    property string cfg_storageMountsDefault
    property string cfg_storageColor
    property string cfg_storageColorDefault
    property string cfg_processesTitle
    property string cfg_processesTitleDefault
    property string cfg_processSort
    property string cfg_processSortDefault
    property int cfg_processCount
    property int cfg_processCountDefault
    property bool cfg_processGroup
    property bool cfg_processGroupDefault
    property string cfg_processColor
    property string cfg_processColorDefault
    property string cfg_loadTitle
    property string cfg_loadTitleDefault
    property string cfg_loadColor
    property string cfg_loadColorDefault
    property string cfg_fansTitle
    property string cfg_fansTitleDefault
    property string cfg_fanColor
    property string cfg_fanColorDefault
    property string cfg_servicesTitle
    property string cfg_servicesTitleDefault
    property string cfg_serviceColor
    property string cfg_serviceColorDefault
    property string cfg_serviceUnits
    property string cfg_serviceUnitsDefault
    property string cfg_containersTitle
    property string cfg_containersTitleDefault
    property string cfg_containerColor
    property string cfg_containerColorDefault
    property string cfg_containerSource
    property string cfg_containerSourceDefault
    property string cfg_kubeNamespace
    property string cfg_kubeNamespaceDefault
    property bool cfg_containerShowStopped
    property bool cfg_containerShowStoppedDefault
    property string cfg_containerSort
    property string cfg_containerSortDefault
    property int cfg_containerCount
    property int cfg_containerCountDefault
    property string cfg_powerChart
    property string cfg_powerChartDefault
    property bool cfg_powerShowProfiles
    property bool cfg_powerShowProfilesDefault
    property bool cfg_powerShowSources
    property bool cfg_powerShowSourcesDefault
    property bool cfg_powerShowPressure
    property bool cfg_powerShowPressureDefault
    property string cfg_powerColor
    property string cfg_powerColorDefault
    property string cfg_powerLoadColor
    property string cfg_powerLoadColorDefault
    property bool cfg_panelCycle
    property bool cfg_panelCycleDefault
    property int cfg_panelCycleSeconds
    property int cfg_panelCycleSecondsDefault
    property bool cfg_panelIcons
    property bool cfg_panelIconsDefault
    property string cfg_remoteHost
    property string cfg_remoteHostDefault
    property string cfg_surfaceStyle
    property string cfg_surfaceStyleDefault
    property string cfg_glassTint
    property string cfg_glassTintDefault
    property string cfg_glassTintColor
    property string cfg_glassTintColorDefault
    property real cfg_glassBlur
    property real cfg_glassBlurDefault
    property real cfg_glassRefraction
    property real cfg_glassRefractionDefault
    property bool cfg_glassSpecular
    property bool cfg_glassSpecularDefault
    property bool cfg_compositorGlass
    property bool cfg_compositorGlassDefault
    property real cfg_cardOpacity
    property real cfg_cardOpacityDefault
    property string cfg_cardShadow
    property string cfg_cardShadowDefault
    property bool cfg_grain
    property bool cfg_grainDefault
    property bool cfg_frostedGlass
    property bool cfg_frostedGlassDefault
    property real cfg_frostStrength
    property real cfg_frostStrengthDefault
    property bool cfg_cardBorder
    property bool cfg_cardBorderDefault
    property bool cfg_gpuBloom
    property bool cfg_gpuBloomDefault
    property real cfg_bloomStrength
    property real cfg_bloomStrengthDefault
    property bool cfg_showGridLines
    property bool cfg_showGridLinesDefault
    property bool cfg_accurateGeo
    property bool cfg_accurateGeoDefault
    property bool cfg_autoYRange
    property bool cfg_autoYRangeDefault
    property int cfg_chartType
    property int cfg_chartTypeDefault
    property bool cfg_smoothLines
    property bool cfg_smoothLinesDefault
    property string cfg_disabledCoresStr
    property string cfg_disabledCoresStrDefault
    property string cfg_disabledLinesStr
    property string cfg_disabledLinesStrDefault
    property bool cfg_useSystemTextColor
    property bool cfg_useSystemTextColorDefault
    property string cfg_customTextColor
    property string cfg_customTextColorDefault
    property string cfg_pingTitle
    property string cfg_pingTitleDefault
    property string cfg_networkTitle
    property string cfg_networkTitleDefault
    property string cfg_cpuTitle
    property string cfg_cpuTitleDefault
    property string cfg_memoryTitle
    property string cfg_memoryTitleDefault
    property string cfg_customCmd
    property string cfg_customCmdDefault
    property string cfg_customCmdTitle
    property string cfg_customCmdTitleDefault
    property string cfg_customCmdUnit
    property string cfg_customCmdUnitDefault
    property int cfg_customCmdMax
    property int cfg_customCmdMaxDefault
    property int cfg_customCmdInterval
    property int cfg_customCmdIntervalDefault
    property string cfg_customCmdColor
    property string cfg_customCmdColorDefault
    property string cfg_gpuTitle
    property string cfg_gpuTitleDefault
    property string cfg_gpuColor
    property string cfg_gpuColorDefault
    property bool cfg_gpuShowEngines
    property bool cfg_gpuShowEnginesDefault
    property string cfg_gpuDevice
    property string cfg_gpuDeviceDefault
    property bool cfg_netShowInfo
    property bool cfg_netShowInfoDefault
    property bool cfg_panelMode
    property bool cfg_panelModeDefault
    property bool cfg_panelShowSessionTotals
    property bool cfg_panelShowSessionTotalsDefault
    property bool cfg_panelPlainText
    property bool cfg_panelPlainTextDefault
    property bool cfg_panelShowBg
    property bool cfg_panelShowBgDefault
    property string cfg_panelSections
    property string cfg_panelSectionsDefault
    property string cfg_panelStyle
    property string cfg_panelStyleDefault
    property bool cfg_panelHoverCard
    property bool cfg_panelHoverCardDefault
    property string cfg_diskTitle
    property string cfg_diskTitleDefault
    property string cfg_diskDevice
    property string cfg_diskDeviceDefault
    property string cfg_diskRdColor
    property string cfg_diskRdColorDefault
    property string cfg_diskWrColor
    property string cfg_diskWrColorDefault
    property string cfg_hwSensorsTitle
    property string cfg_hwSensorsTitleDefault
    property int cfg_hwTempWarn
    property int cfg_hwTempWarnDefault
    property int cfg_hwTempCrit
    property int cfg_hwTempCritDefault
    property string cfg_osInfoTitle
    property string cfg_osInfoTitleDefault
    property bool cfg_osUseFetch
    property bool cfg_osUseFetchDefault
    property string cfg_osFetchCmd
    property string cfg_osFetchCmdDefault
    property bool cfg_osPlainText
    property bool cfg_osPlainTextDefault
    property bool cfg_osShowLogo
    property bool cfg_osShowLogoDefault
    property var cfg_osFieldRules
    property var cfg_osFieldRulesDefault
    property string cfg_powerTitle
    property string cfg_powerTitleDefault

    property var configKeys: []
    readonly property var draft: configValues(false)
    readonly property var defaults: configValues(true)

    // Reading each cfg_ property here keeps both snapshots reactive to Plasma.
    function configValues(useDefaults) {
        const values = {};
        for (const key of configKeys)
            values[key] = root["cfg_" + key + (useDefaults ? "Default" : "")];
        return values;
    }

    property var savedDraft: null
    property var history: []
    property bool isReverting: false

    function same(a, b) {
        return Array.isArray(a) || Array.isArray(b) ? JSON.stringify(a) === JSON.stringify(b) : String(a) === String(b);
    }
    readonly property bool hasChanges: !!savedDraft && Object.keys(savedDraft).some(key => !same(draft[key], savedDraft[key]))

    Component.onCompleted: {
        // Enumerate outside a binding: Qt can evaluate unrelated getters while
        // listing QObject properties, including draft and defaults themselves.
        configKeys = Object.keys(root).filter(key => key.startsWith("cfg_") && key.endsWith("Default")).map(key => key.slice(4, -7));
        snapshotBaseline();
    }

    function snapshotBaseline() {
        savedDraft = Object.assign({}, draft);
        history = [];
    }

    // Plasma calls this when Apply or OK saves the cfg_ properties.
    function saveConfig() {
        snapshotBaseline();
    }

    function discard() {
        if (!savedDraft)
            return;
        isReverting = true;
        assign(savedDraft);
        history = [];
        isReverting = false;
    }

    function undo() {
        if (history.length === 0)
            return discard();
        isReverting = true;
        assign(history.pop());
        isReverting = false;
    }

    function assign(next) {
        if (!isReverting) {
            history.push(Object.assign({}, draft));
            if (history.length > 30)
                history.shift();
        }
        for (const key in next) {
            const property = "cfg_" + key;
            if (root[property] !== undefined && !same(next[key], root[property]))
                root[property] = next[key];
        }
    }

    // Reads this machine with the draft settings, for the preview and the
    // device lists. Nothing runs while the settings window is hidden.
    MonitorCore {
        id: previewMonitor
        cfg: root.draft
        onScreen: studio.onScreen
        active: studio.onScreen
        commandSourceComponent: Component {
            P5Support.DataSource {
                engine: "executable"
            }
        }
        writeConfig: (key, value) => root.assign({
                [key]: value
            })
        systemAccent: Kirigami.Theme.highlightColor
        systemTextColor: "#eff0f1"
    }

    Studio.Studio {
        id: studio
        anchors.fill: parent
        env: "kde"
        draft: root.draft
        defaults: root.defaults
        canDiscard: root.hasChanges
        liveMonitor: previewMonitor
        previewAccent: Kirigami.Theme.highlightColor
        onEdited: next => root.assign(next)
        onDiscard: root.discard()
        onUndo: root.undo()
    }
}
