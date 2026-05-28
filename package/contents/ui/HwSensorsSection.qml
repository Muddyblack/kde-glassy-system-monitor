import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: hwSection
    spacing: 1

    readonly property bool _empty: root.hwSensorRows.count === 0

    // Per-sensor crit-based color. (value - 30) / (crit - 30) ratio keeps
    // colors meaningful across different crit thresholds (CPU 100, NVMe 85).
    function tempColor(value, crit) {
        const c = crit > 0 ? crit : (plasmoid.configuration.hwTempCrit || 90);
        const r = Math.max(0, (value - 30) / Math.max(20, c - 30));
        if (r >= 0.85)
            return Qt.color("#ff4444");
        if (r >= 0.72)
            return Qt.color("#ff8844");
        if (r >= 0.55)
            return Qt.color("#ffaa22");
        return Qt.color("#44ddaa");
    }

    // Linear bar fill: value / crit, with a small minimum so cold sensors
    // remain visible.
    function barRatio(value, crit) {
        const c = crit > 0 ? crit : (plasmoid.configuration.hwTempCrit || 90);
        return Math.max(0.05, Math.min(1, value / c));
    }

    // Empty-state hint
    Text {
        visible: hwSection._empty
        Layout.fillWidth: true
        Layout.fillHeight: true
        text: "No sensor data.\nRun: sudo sensors-detect\nor install lm-sensors."
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.40)
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }

    // Flat list of rows — headers and sensors mixed, dispatched by rowType.
    Flickable {
        visible: !hwSection._empty
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: rowCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: rowCol
            width: parent.width
            spacing: 1

            Repeater {
                model: root.hwSensorRows

                Item {
                    Layout.fillWidth: true
                    Layout.topMargin: rowType === 'header' && index > 0 ? 5 : 0
                    height: rowType === 'header' ? 16 : 20

                    // ── Chip header ───────────────────────────────────────────
                    RowLayout {
                        visible: rowType === 'header'
                        anchors.fill: parent
                        spacing: 6

                        Text {
                            text: chipDisplay
                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.85)
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.4
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            height: 1
                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                        }
                        Text {
                            visible: maxTemp > 0
                            text: "max " + maxTemp.toFixed(0) + "°C"
                            color: hwSection.tempColor(maxTemp, maxTempCrit)
                            font.pixelSize: 9
                            font.bold: true
                            Behavior on color {
                                ColorAnimation {
                                    duration: 400
                                }
                            }
                        }
                    }

                    // ── Sensor row (temp / cores / fan) ───────────────────────
                    Item {
                        id: sensorRowItem
                        visible: rowType === 'sensor'
                        anchors.fill: parent

                        readonly property color _vc: sensorKind === 'fan' ? Qt.color("#22aaff") : hwSection.tempColor(value, crit)

                        // Label (left, capped width)
                        Text {
                            id: lblText
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(90, parent.width * 0.30)
                            text: label
                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.62)
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        // Center — bar / cores / fan
                        Item {
                            id: midArea
                            anchors.left: lblText.right
                            anchors.leftMargin: 6
                            anchors.right: valText.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height

                            // Single temp bar
                            Rectangle {
                                visible: sensorKind === 'temp'
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 5
                                radius: 2.5
                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                Rectangle {
                                    width: Math.max(parent.radius * 2, parent.width * hwSection.barRatio(value, crit))
                                    height: parent.height
                                    radius: parent.radius
                                    color: sensorRowItem._vc
                                    opacity: 0.90
                                    // Smooth grow/shrink between refreshes
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 600
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 400
                                        }
                                    }
                                }
                            }

                            // Per-core bars. model is the count (stable), and
                            // each delegate reads coreValues[index]. So the
                            // delegates persist across refreshes and Behavior
                            // animates the new height.
                            Row {
                                visible: sensorKind === 'cores'
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 12
                                spacing: 1

                                Repeater {
                                    model: coreValues ? coreValues.length : 0

                                    Item {
                                        readonly property real _v: (coreValues && index < coreValues.length) ? coreValues[index] : 0
                                        readonly property real _critRef: crit
                                        width: {
                                            const n = coreValues ? coreValues.length : 1;
                                            return Math.max(2, (parent.width - (n - 1)) / Math.max(1, n));
                                        }
                                        height: 12

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 2
                                            radius: 1
                                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        }
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: Math.max(2, 12 * hwSection.barRatio(_v, _critRef))
                                            radius: 1
                                            color: hwSection.tempColor(_v, _critRef)
                                            opacity: 0.92
                                            Behavior on height {
                                                NumberAnimation {
                                                    duration: 600
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: 400
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Fan: subtle tinted line
                            Rectangle {
                                visible: sensorKind === 'fan'
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 2
                                radius: 1
                                color: Qt.rgba(0.13, 0.67, 1.0, 0.35)
                            }
                        }

                        // Value (right, fixed width)
                        Text {
                            id: valText
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64
                            horizontalAlignment: Text.AlignRight
                            text: {
                                if (sensorKind === 'fan')
                                    return value + " RPM";
                                if (sensorKind === 'cores')
                                    return coreMin.toFixed(0) + "–" + coreMax.toFixed(0) + "°C";
                                return value.toFixed(1) + "°C";
                            }
                            color: sensorRowItem._vc
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            Behavior on color {
                                ColorAnimation {
                                    duration: 400
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
