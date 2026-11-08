import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels
import "Sections.js" as Sections

// Load average over time (1, 5 and 15 minutes; the dashed line is every CPU
// busy), with uptime and task counts under the chart.
ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "load"
    // This section's own text and number colours (Colours › Per section).
    readonly property color ink: Sections.sectionColor(cfg, sectionId, "text") || monitor.textColor
    readonly property string numbers: Sections.sectionColor(cfg, sectionId, "value")
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.load(monitor, cfg)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + stats.implicitHeight + (legend.visible ? legend.implicitHeight : 0) + 16
    readonly property real minimumHeight: preferredHeight - chart.slack

    spacing: 4

    SectionHeader {
        id: header
        fontFamily: section.monitor.fontFamily
        textScale: section.monitor.textScale
        Layout.fillWidth: true
        title: section.model.title
        reading: section.model.reading
        readingColor: section.numbers || (section.model.readingColor || section.ink)
        textColor: section.ink
        monitor: section.monitor
        lineKey: "load1"
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "load"
        clock: section.monitor.loadClock
        maxValue: section.model.maxValue
        ticks: section.model.ticks
        markers: section.model.markers || []
        centerText: section.model.centerText
        centerSubText: section.model.centerSubText
        series: section.model.series(style)
    }

    RowLayout {
        id: stats
        Layout.fillWidth: true
        Layout.leftMargin: chart.plotLeft
        spacing: 12
        Repeater {
            model: section.model.stats
            Column {
                required property var modelData
                spacing: 1
                Text {
                    font.family: section.monitor.fontFamily
                    text: parent.modelData.label
                    color: section.ink
                    opacity: 0.38
                    font.pixelSize: Math.round(7 * section.monitor.textScale)
                    font.letterSpacing: 0.8
                }
                Text {
                    font.family: section.monitor.fontFamily
                    text: parent.modelData.value
                    color: section.numbers || parent.modelData.color || section.ink
                    opacity: 0.85
                    font.pixelSize: Math.round(10 * section.monitor.textScale)
                    font.bold: true
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }

    Legend {
        id: legend
        Layout.fillWidth: true
        visible: !!section.cfg.showLegend
        monitor: section.monitor
        ink: section.ink
        numbers: section.numbers
        indent: chart.plotLeft
        entries: section.model.legend
    }
}
