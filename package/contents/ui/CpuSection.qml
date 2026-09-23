import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "cpu"
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.cpu(monitor, cfg)
    readonly property bool coresShown: model.cores
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + legend.implicitHeight + (coresShown ? coreGrid.implicitHeight : 0) + 12
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
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "cpu"
        clock: section.monitor.cpuClock
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

    // Per-core readings; click hides a core, hover singles it out.
    GridLayout {
        id: coreGrid
        Layout.fillWidth: true
        visible: section.coresShown
        columns: section.width > 360 ? 3 : 2
        columnSpacing: 10
        rowSpacing: 0

        Repeater {
            model: section.monitor.corePercents.length
            Item {
                id: coreItem
                required property int index
                readonly property bool shown: !section.monitor.isCoreDisabled(index)
                readonly property color tint: section.model.coreColors[index % section.model.coreColors.length]
                Layout.fillWidth: true
                implicitHeight: 20

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: chart.plotLeft > 0 ? 2 : 0
                    spacing: 5
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 2
                        color: coreItem.shown ? coreItem.tint : "transparent"
                        border.color: coreItem.tint
                        border.width: 1
                    }
                    Text {
                        font.family: section.monitor.fontFamily
                        Layout.fillWidth: true
                        text: "Core " + (coreItem.index + 1)
                        color: section.monitor.textColor
                        opacity: coreItem.shown ? 0.7 : 0.35
                        font.pixelSize: 10
                        font.strikeout: !coreItem.shown
                        elide: Text.ElideRight
                    }
                    Text {
                        font.family: section.monitor.fontFamily
                        text: (section.monitor.corePercents[coreItem.index] || 0).toFixed(0) + "%"
                        color: coreItem.tint
                        opacity: coreItem.shown ? 1 : 0.4
                        font.pixelSize: 10
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.minimumWidth: 30
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: section.monitor.toggleCoreDisabled(coreItem.index)
                    onEntered: section.monitor.hoveredCore = coreItem.index
                    onExited: if (section.monitor.hoveredCore === coreItem.index)
                        section.monitor.hoveredCore = -1
                }
            }
        }
    }
}
