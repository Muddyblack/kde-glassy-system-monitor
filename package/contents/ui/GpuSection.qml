import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels
import "Format.js" as Format

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "gpu"
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.gpu(monitor, cfg)
    readonly property bool enginesShown: !!cfg.gpuShowEngines && (monitor.gpuComputePercent >= 0 || monitor.gpuDecPercent >= 0 || monitor.gpuEncPercent >= 0 || monitor.gpuVramUsed >= 0)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + (enginesShown ? engines.implicitHeight : 0) + 12
    readonly property real minimumHeight: preferredHeight - chart.slack
    readonly property color dimText: Qt.rgba(monitor.textColor.r, monitor.textColor.g, monitor.textColor.b, 0.55)
    readonly property var vendor: ({
            nvidia: ["NVIDIA", "#1dbb55"],
            amd: ["AMD", "#eb2929"],
            intel: ["Intel", "#0078e5"]
        })[monitor.gpuVendor] || null

    spacing: 4

    SectionHeader {
        id: header
        Layout.fillWidth: true
        title: section.model.title
        reading: section.model.reading
        readingColor: section.model.readingColor || section.monitor.textColor
        textColor: section.monitor.textColor
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!section.vendor
            radius: 3
            color: section.vendor ? Qt.alpha(section.vendor[1], 0.2) : "transparent"
            implicitWidth: vendorLabel.implicitWidth + 10
            implicitHeight: vendorLabel.implicitHeight + 4
            Text {
                id: vendorLabel
                anchors.centerIn: parent
                text: section.vendor ? section.vendor[0] : ""
                color: section.vendor ? section.vendor[1] : "transparent"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 0.5
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: section.monitor.gpuFreqMhz > 0
            text: section.monitor.gpuFreqMhz + " MHz"
            color: section.dimText
            font.pixelSize: 10
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: section.monitor.gpuVendor === "" && section.monitor.gpuNoDataTicks > 3
            text: "No GPU data"
            color: section.dimText
            font.pixelSize: 10
        }
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "gpu"
        clock: section.monitor.gpuClock
        maxValue: section.model.maxValue
        ticks: section.model.ticks
        markers: section.model.markers || []
        bands: section.model.bands || []
        gapColor: section.model.gapColor || "#ff4444"
        centerText: section.model.centerText
        centerSubText: section.model.centerSubText
        series: section.model.series(style)
    }

    // VRAM bar and engine shares, when the backend can tell.
    ColumnLayout {
        id: engines
        Layout.fillWidth: true
        Layout.leftMargin: chart.plotLeft
        visible: section.enginesShown
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            visible: section.monitor.gpuVramUsed >= 0
            spacing: 6
            Text {
                text: "VRAM"
                color: section.dimText
                font.pixelSize: 10
                font.bold: true
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: section.monitor.gpuVramTotal > 0
                implicitHeight: 6
                radius: 3
                color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.12)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.max(0, Math.min(1, section.monitor.gpuVramTotal > 0 ? section.monitor.gpuVramUsed / section.monitor.gpuVramTotal : 0))
                    color: section.monitor.gpuColor
                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
            Item {
                Layout.fillWidth: section.monitor.gpuVramTotal <= 0
            }
            Text {
                text: section.monitor.gpuVramTotal > 0 ? Format.bytes(section.monitor.gpuVramUsed) + " / " + Format.bytes(section.monitor.gpuVramTotal) : Format.bytes(section.monitor.gpuVramUsed)
                color: section.dimText
                font.pixelSize: 10
            }
        }

        Row {
            spacing: 10
            Repeater {
                model: [["Compute", section.monitor.gpuComputePercent], ["Decode", section.monitor.gpuDecPercent], ["Encode", section.monitor.gpuEncPercent]].filter(e => e[1] >= 0)
                Row {
                    required property var modelData
                    readonly property bool busy: modelData[1] > 1
                    spacing: 4
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Qt.alpha(section.monitor.gpuColor, parent.busy ? 0.95 : 0.35)
                    }
                    Text {
                        text: parent.modelData[0]
                        color: section.dimText
                        font.pixelSize: 10
                    }
                    Text {
                        text: parent.modelData[1].toFixed(0) + "%"
                        color: parent.busy ? section.monitor.gpuColor : section.dimText
                        font.pixelSize: 10
                        font.bold: parent.busy
                    }
                }
            }
        }
    }
}
