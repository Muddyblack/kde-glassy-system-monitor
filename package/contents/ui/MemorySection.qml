import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "memory"
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.memory(monitor, cfg)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + (legend.visible ? legend.implicitHeight : 0) + 12
    readonly property real minimumHeight: preferredHeight - chart.slack

    spacing: 4

    SectionHeader {
        id: header
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        title: section.model.title
        reading: section.model.reading
        readingColor: section.model.readingColor || section.monitor.textColor
        textColor: section.monitor.textColor
        monitor: section.monitor
        lineKey: "ram"
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "memory"
        clock: section.monitor.memClock
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
        indent: chart.plotLeft
        entries: section.model.legend
    }
}
