import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels
import "Format.js" as Format

// Battery and power: charge and flow, the machine's measured draw (energy
// counters and power sensors), a chart of power / charge / temperature, the
// power profile, battery diagnostics and pressure stall info.
ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "power"
    readonly property real preferredHeight: implicitHeight + 8
    readonly property real minimumHeight: preferredHeight

    readonly property color ink: monitor.textColor
    function inkAlpha(a) {
        return Qt.rgba(ink.r, ink.g, ink.b, a);
    }

    readonly property bool battery: monitor.batteryPresent
    readonly property color chargeColor: monitor.batteryPercent <= 15 ? "#ff4444" : monitor.batteryPercent <= 30 ? "#ffaa00" : "#44dd88"
    // Chart tabs with something to draw.
    readonly property var tabs: [["power", "Power (W)", battery || monitor.hasPowerSensors], ["battery", "Battery %", battery], ["temp", "Temp (°C)", battery && monitor.batteryTempC > -100]].filter(t => t[2])
    readonly property string tab: tabs.some(t => t[0] === cfg.powerChart) ? cfg.powerChart : tabs.length ? tabs[0][0] : ""
    readonly property var chartModel: SectionModels.power(monitor, cfg, tab)
    readonly property var profiles: SectionModels.profiles(monitor)

    function fmtTime(hours) {
        if (hours <= 0)
            return "";
        const totalMin = Math.floor(hours * 60);
        const h = Math.floor(totalMin / 60), m = totalMin % 60;
        return h <= 0 ? m + "m" : h + "h " + (m < 10 ? "0" + m : m) + "m";
    }
    readonly property string statusText: {
        const s = monitor.batteryStatus;
        const plugged = monitor.acOnline === 1;
        const left = fmtTime(monitor.batteryTimeRemainHours);
        if (s === "Discharging")
            return left ? left + " left" : "On battery";
        if (s === "Charging")
            return left ? "Charging · full in " + left : "Charging";
        if (s === "Full")
            return plugged ? "Full · plugged in" : "Full";
        if (s === "Not charging")
            return "Plugged in, not charging";
        return plugged ? "Plugged in" : s;
    }

    spacing: 6

    SectionHeader {
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        title: section.monitor.sectionTitle("power")
        reading: section.battery ? section.monitor.batteryPercent + "%" : section.monitor.hasPowerSensors ? Format.watts(section.monitor.powerLoadW) : ""
        readingColor: section.battery ? section.chargeColor : section.monitor.textColor
        textColor: section.ink
    }

    // ── Battery / draw at a glance ───────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: section.battery || section.monitor.hasPowerSensors

        // Battery glyph filled to the charge.
        Item {
            visible: section.battery
            implicitWidth: 30
            implicitHeight: 16
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                id: cell
                width: 27
                height: 16
                radius: 3
                color: "transparent"
                border.color: section.inkAlpha(0.6)
                border.width: 1.5
                Rectangle {
                    x: 2.5
                    y: 2.5
                    height: parent.height - 5
                    width: Math.max(1, (parent.width - 5) * Math.min(1, section.monitor.batteryPercent / 100))
                    radius: 1.5
                    color: section.chargeColor
                    Behavior on width {
                        NumberAnimation {
                            duration: 600
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: section.monitor.batteryStatus === "Charging"
                    text: "⚡"
                    color: "#ffffff"
                    font.pixelSize: 10
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }
            }
            Rectangle {
                anchors.left: cell.right
                anchors.verticalCenter: cell.verticalCenter
                width: 2.5
                height: 6
                radius: 1
                color: section.inkAlpha(0.6)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                font.family: section.monitor.fontFamily
                text: section.battery ? (section.monitor.batteryModel || "Battery") : "Measured draw"
                color: section.ink
                opacity: 0.85
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                font.family: section.monitor.fontFamily
                text: section.battery ? section.statusText : section.monitor.powerSources.map(s => s.label).join(" · ")
                color: section.inkAlpha(0.55)
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        ColumnLayout {
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignRight
                font.family: section.monitor.fontFamily
                readonly property real w: section.battery ? section.monitor.batteryPowerW : section.monitor.powerLoadW
                text: (section.battery && w > 0.05 ? "+" : "") + Math.abs(w).toFixed(1) + "W"
                color: section.battery ? (w > 0.05 ? "#44dd88" : w < -0.05 ? "#ffaa22" : section.ink) : SectionModels.color(section.cfg, "powerLoadColor", "#ffaa22")
                font.pixelSize: 20
                font.bold: true
                font.features: ({
                        "tnum": 1
                    })
            }
            Text {
                Layout.alignment: Qt.AlignRight
                visible: section.battery && section.monitor.hasPowerSensors
                font.family: section.monitor.fontFamily
                text: Format.watts(section.monitor.powerLoadW) + " load"
                color: section.inkAlpha(0.5)
                font.pixelSize: 9
            }
        }
    }

    Text {
        font.family: section.monitor.fontFamily
        visible: !section.battery && !section.monitor.hasPowerSensors
        Layout.fillWidth: true
        text: "No battery or power sensors"
        color: section.inkAlpha(0.3)
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Chart tabs ───────────────────────────────────────────────────────────
    component Seg: Rectangle {
        id: seg
        property string label
        property bool on: false
        signal picked
        Layout.fillWidth: true
        implicitHeight: 20
        radius: 5
        color: on ? section.inkAlpha(0.14) : segArea.containsMouse ? section.inkAlpha(0.06) : "transparent"
        Text {
            anchors.centerIn: parent
            font.family: section.monitor.fontFamily
            text: seg.label
            color: section.ink
            opacity: seg.on ? 0.95 : 0.55
            font.pixelSize: 10
            font.bold: seg.on
        }
        MouseArea {
            id: segArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.picked()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: section.tabs.length > 1
        spacing: 2
        Repeater {
            model: section.tabs
            Seg {
                required property var modelData
                label: modelData[1]
                on: section.tab === modelData[0]
                onPicked: section.monitor.writeConfig("powerChart", modelData[0])
            }
        }
    }

    MetricChart {
        id: chart
        visible: section.tab !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: wantedHeight
        monitor: section.monitor
        cfg: section.cfg
        sectionId: "power"
        style: sectionStyle || "area"
        smoothScroll: false
        maxValue: section.chartModel.maxValue
        ticks: section.chartModel.ticks
        series: section.chartModel.series
    }

    Legend {
        Layout.fillWidth: true
        visible: !!section.cfg.showLegend && section.chartModel.legend.length > 0
        monitor: section.monitor
        indent: chart.plotLeft
        entries: section.chartModel.legend
    }

    // ── Power profile ────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        visible: section.profiles.length > 1 && section.cfg.powerShowProfiles !== false
        spacing: 2
        Text {
            font.family: section.monitor.fontFamily
            text: "Profile"
            color: section.inkAlpha(0.45)
            font.pixelSize: 10
            Layout.rightMargin: 4
        }
        Repeater {
            model: section.profiles
            Seg {
                required property var modelData
                label: modelData.label
                on: section.monitor.powerProfile === modelData.id
                onPicked: section.monitor.setPowerProfile(modelData.id)
            }
        }
    }

    // ── Battery diagnostics ──────────────────────────────────────────────────
    component Tile: Rectangle {
        property string label
        property string value
        property color tint: section.ink
        Layout.fillWidth: true
        implicitHeight: 22
        radius: 4
        color: section.inkAlpha(0.05)
        border.color: section.inkAlpha(0.08)
        border.width: 1
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            font.family: section.monitor.fontFamily
            text: parent.label
            color: section.inkAlpha(0.55)
            font.pixelSize: 10
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            font.family: section.monitor.fontFamily
            text: parent.value
            color: parent.tint
            font.pixelSize: 10
            font.bold: true
        }
    }

    GridLayout {
        Layout.fillWidth: true
        visible: section.battery
        columns: 2
        rowSpacing: 3
        columnSpacing: 3
        Tile {
            label: "Battery"
            value: section.monitor.batteryPercent + "%"
            tint: section.chargeColor
        }
        Tile {
            label: "Status"
            value: section.monitor.acOnline === 1 && section.monitor.batteryStatus !== "Charging" ? "Plugged in" : section.monitor.batteryStatus || "—"
        }
        Tile {
            label: "Temperature"
            value: section.monitor.batteryTempC > -100 ? section.monitor.batteryTempC.toFixed(0) + "°C" : "N/A"
        }
        Tile {
            label: "Cycle count"
            value: section.monitor.batteryCycles >= 0 ? String(section.monitor.batteryCycles) : "—"
        }
    }

    // Health: full charge against the design capacity.
    ColumnLayout {
        Layout.fillWidth: true
        visible: section.battery && section.monitor.batteryHealthPct > 0
        spacing: 2
        readonly property real health: section.monitor.batteryHealthPct
        readonly property color tint: health >= 80 ? "#44dd88" : health >= 60 ? "#ffaa22" : "#ff6644"
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                font.family: section.monitor.fontFamily
                text: "Battery health"
                color: section.inkAlpha(0.55)
                font.pixelSize: 10
            }
            Text {
                font.family: section.monitor.fontFamily
                text: parent.parent.health.toFixed(1) + "%"
                color: parent.parent.tint
                font.pixelSize: 10
                font.bold: true
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: section.inkAlpha(0.10)
            Rectangle {
                width: parent.width * Math.min(1, parent.parent.health / 100)
                height: parent.height
                radius: 2
                color: parent.parent.tint
            }
        }
    }

    // ── Where the power goes ─────────────────────────────────────────────────
    Repeater {
        model: section.cfg.powerShowSources === false ? [] : section.monitor.powerSources
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.preferredWidth: 90
                font.family: section.monitor.fontFamily
                text: parent.modelData.label
                color: section.inkAlpha(0.55)
                font.pixelSize: 10
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: section.inkAlpha(0.10)
                Rectangle {
                    width: Math.max(4, parent.width * Math.min(1, parent.parent.modelData.watts / Math.max(1, section.chartModel.maxValue || 1)))
                    height: parent.height
                    radius: 2
                    color: SectionModels.color(section.cfg, "powerLoadColor", "#ffaa22")
                    opacity: 0.85
                }
            }
            Text {
                Layout.preferredWidth: 52
                horizontalAlignment: Text.AlignRight
                font.family: section.monitor.fontFamily
                text: Format.watts(parent.modelData.watts)
                color: section.ink
                opacity: 0.8
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    // ── Pressure stall info ──────────────────────────────────────────────────
    component PressureRow: RowLayout {
        property string label: ""
        property real value: 0
        property color barColor: section.ink
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.preferredWidth: 90
            font.family: section.monitor.fontFamily
            text: parent.label
            color: section.inkAlpha(0.45)
            font.pixelSize: 10
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: section.inkAlpha(0.10)
            Rectangle {
                width: Math.max(4, parent.width * Math.min(1, parent.parent.value / 20))
                height: parent.height
                radius: 2
                color: parent.parent.barColor
                opacity: 0.85
                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
        Text {
            Layout.preferredWidth: 52
            horizontalAlignment: Text.AlignRight
            font.family: section.monitor.fontFamily
            text: parent.value.toFixed(2) + "%"
            color: parent.value >= 10 ? parent.barColor : section.inkAlpha(0.65)
            font.pixelSize: 10
            font.bold: parent.value >= 5
        }
    }

    PressureRow {
        visible: section.cfg.powerShowPressure !== false
        label: "CPU pressure"
        value: section.monitor.cpuPressureAvg10
        barColor: "#ff6644"
    }
    PressureRow {
        visible: section.cfg.powerShowPressure !== false
        label: "Memory pressure"
        value: section.monitor.memPressureAvg10
        barColor: "#aa66ff"
    }

    Item {
        Layout.fillHeight: true
    }
}
