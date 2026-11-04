import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels
import "Sections.js" as Sections

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "disk"
    // This section's own text and number colours (Colours › Per section).
    readonly property color ink: Sections.sectionColor(cfg, sectionId, "text") || monitor.textColor
    readonly property string numbers: Sections.sectionColor(cfg, sectionId, "value")
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.disk(monitor, cfg)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + (legend.visible ? legend.implicitHeight : 0) + 12
    readonly property real minimumHeight: preferredHeight - chart.slack

    spacing: 4

    SectionHeader {
        id: header
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        title: section.model.title
        reading: section.model.reading
        readingColor: section.numbers || (section.model.readingColor || section.ink)
        textColor: section.ink
        Text {
            font.family: section.monitor.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            text: section.monitor.activeDisk
            color: section.ink
            opacity: 0.38
            font.pixelSize: 9
        }
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "disk"
        clock: section.monitor.diskClock
        maxValue: section.model.maxValue
        ticks: section.model.ticks
        markers: section.model.markers || []
        bands: section.model.bands || []
        gapColor: section.model.gapColor || "#ff4444"
        centerText: section.model.centerText
        centerSubText: section.model.centerSubText
        series: section.model.series(style)
    }

    Legend {
        id: legend
        Layout.fillWidth: true
        visible: !!section.cfg.showLegend && section.model.legend.length > 0
        monitor: section.monitor
        ink: section.ink
        numbers: section.numbers
        indent: chart.plotLeft
        entries: section.model.legend
    }
}
