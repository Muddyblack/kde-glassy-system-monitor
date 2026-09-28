import QtQuick
import QtQuick.Layouts
import "SectionModels.js" as SectionModels

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "sensors"
    readonly property real preferredHeight: implicitHeight + 8
    readonly property real minimumHeight: preferredHeight
    // Hottest of the readings shown, for the header.
    readonly property var hottest: readings.shown.filter(s => s.type === "temp" || s.type === "cores").reduce((a, s) => !a || s.value > a.value ? s : a, null)

    spacing: 1

    SectionHeader {
        fontFamily: section.monitor.fontFamily
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        title: section.monitor.sectionTitle("sensors")
        reading: section.hottest ? section.hottest.value.toFixed(0) + "°C" : ""
        readingColor: section.hottest ? SectionModels.tempColor(section.hottest.value, section.hottest.crit || section.cfg.hwTempCrit || 90) : section.monitor.textColor
        textColor: section.monitor.textColor
    }
    SensorReadings {
        id: readings
        Layout.fillWidth: true
        monitor: section.monitor
        cfg: section.cfg
        targetSection: "sensors"
        layout: "grouped"
    }
    Text {
        font.family: section.monitor.fontFamily
        visible: readings.count === 0
        Layout.fillWidth: true
        text: section.monitor.hardwareSensors.length ? "No sensors chosen.\nPick them in the settings under Sections › Sensors." : "No sensor data.\nRun: sudo sensors-detect\nor install lm-sensors."
        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.40)
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }
}
