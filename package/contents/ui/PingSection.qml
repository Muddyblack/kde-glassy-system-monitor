import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "ping"
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.ping(monitor, cfg)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + (stats.visible ? stats.implicitHeight : 0) + 14
    readonly property real minimumHeight: preferredHeight - chart.slack

    spacing: 4

    component Stat: Column {
        property string label
        property string value
        property color tint: section.monitor.textColor
        spacing: 1
        Text {
            font.family: section.monitor.fontFamily
            text: parent.label
            color: section.monitor.textColor
            opacity: 0.38
            font.pixelSize: 7
            font.letterSpacing: 0.8
        }
        Text {
            font.family: section.monitor.fontFamily
            text: parent.value
            color: parent.tint
            opacity: 0.85
            font.pixelSize: 10
            font.bold: true
            Behavior on color {
                ColorAnimation {
                    duration: 300
                }
            }
        }
    }

    SectionHeader {
        id: header
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        title: section.model.title
        reading: section.model.reading
        readingColor: section.model.readingColor || section.monitor.textColor
        textColor: section.monitor.textColor

        // Target chips: pick which host the chart follows.
        Repeater {
            model: section.monitor.targetList
            Rectangle {
                required property string modelData
                required property int index
                readonly property bool current: section.monitor.activeTarget === index
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                width: Math.min(90, chipText.implicitWidth + 14)
                height: 18
                radius: height / 2
                color: current ? Qt.alpha(section.monitor.pingColor, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                border.color: current ? Qt.alpha(section.monitor.pingColor, 0.6) : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
                Text {
                    id: chipText
                    font.family: section.monitor.fontFamily
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, 76)
                    text: parent.modelData
                    color: parent.current ? section.monitor.pingColor : Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.55)
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.monitor.writeConfig("currentTargetIndex", parent.index)
                }
            }
        }
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "ping"
        clock: section.monitor.pingClock
        maxValue: section.model.maxValue
        ticks: section.model.ticks
        markers: section.model.markers || []
        bands: section.model.bands || []
        gapColor: section.model.gapColor || "#ff4444"
        centerText: section.model.centerText
        centerSubText: section.model.centerSubText
        series: section.model.series(style)
    }

    RowLayout {
        id: stats
        Layout.fillWidth: true
        Layout.leftMargin: chart.plotLeft
        visible: !!section.cfg.showStats
        spacing: 12
        Repeater {
            model: section.model.stats
            Stat {
                required property var modelData
                label: modelData.label
                value: modelData.value
                tint: modelData.color || section.monitor.textColor
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }
}
