import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels
import QtQuick.Controls as QQC2

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "network"
    // Shared with the website studio; see SectionModels.js.
    readonly property var model: SectionModels.network(monitor, cfg)
    readonly property color dimText: Qt.rgba(monitor.textColor.r, monitor.textColor.g, monitor.textColor.b, 0.42)
    readonly property real preferredHeight: header.implicitHeight + chart.wantedHeight + (legend.visible ? legend.implicitHeight : 0) + totals.implicitHeight + 14
    readonly property real minimumHeight: preferredHeight - chart.slack

    spacing: 4

    component Link: Text {
        id: link
        font.family: section.monitor.fontFamily
        signal activated
        color: area.containsMouse ? section.monitor.textColor : section.dimText
        font.pixelSize: 10
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.activated()
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

        Link {
            anchors.verticalCenter: parent.verticalCenter
            visible: section.monitor.activeIface !== ""
            text: section.monitor.activeIface + " ▾"
            onActivated: ifaceMenu.popup()
            QQC2.Menu {
                id: ifaceMenu
                Repeater {
                    model: section.monitor.availableIfaces
                    QQC2.MenuItem {
                        required property string modelData
                        text: modelData === "auto" ? "Automatic" + (section.monitor.autoIface ? " · " + section.monitor.autoIface : "") : modelData
                        checkable: true
                        checked: (section.cfg.networkInterface || "auto") === modelData
                        onTriggered: section.monitor.writeConfig("networkInterface", modelData)
                    }
                }
            }
        }
        Link {
            id: connectionsLink
            anchors.verticalCenter: parent.verticalCenter
            text: connections.opened ? "● connections" : "○ connections"
            onActivated: {
                if (connections.opened) {
                    connections.close();
                } else {
                    connections.open();
                    connections.refresh();
                }
            }
        }
        Text {
            font.family: section.monitor.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            visible: !!section.cfg.netShowInfo && text !== ""
            text: [section.monitor.netSsid, section.monitor.netIpAddr].filter(Boolean).join(" · ")
            color: section.dimText
            font.pixelSize: 10
        }
    }

    NetworkConnections {
        id: connections
        monitor: section.monitor
        cfg: section.cfg
        anchorItem: connectionsLink
    }

    MetricChart {
        id: chart
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 40
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "network"
        clock: section.monitor.netClock
        maxValue: section.model.maxValue
        ticks: section.model.ticks
        markers: section.model.markers || []
        bands: section.model.bands || []
        gapColor: section.model.gapColor || "#ff4444"
        centerText: section.model.centerText
        centerSubText: section.model.centerSubText
        series: section.model.series(style)
    }

    // Traffic since the widget started.
    RowLayout {
        id: totals
        Layout.fillWidth: true
        Layout.leftMargin: chart.plotLeft
        Repeater {
            model: section.model.totals
            Text {
                font.family: section.monitor.fontFamily
                required property var modelData
                required property int index
                Layout.fillWidth: index === 0
                text: modelData.text
                color: modelData.color
                opacity: 0.8
                font.pixelSize: 10
            }
        }
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
