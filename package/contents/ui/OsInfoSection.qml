import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: section

    required property var monitor
    required property var cfg
    readonly property string sectionId: "system"
    readonly property real preferredHeight: implicitHeight + 8
    readonly property real minimumHeight: preferredHeight

    spacing: 0

    SectionHeader {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        title: section.monitor.sectionTitle("system")
        reading: section.monitor.osUptime
        textColor: section.monitor.textColor
    }

    // Built-in fallback rows, used when no fetch tool is available (or the
    // integration is switched off). Kept in sync by the cheap /etc/os-release
    // reader in main.qml, which runs regardless of the fetch setting.
    readonly property var _builtinRows: [
        {
            lbl: "OS",
            val: section.monitor.osDistro
        },
        {
            lbl: "Kernel",
            val: section.monitor.osKernel
        },
        {
            lbl: "Host",
            val: section.monitor.osHostname
        },
        {
            lbl: "Uptime",
            val: section.monitor.osUptime
        }
    ]

    readonly property bool _fetch: section.monitor.osFetchActive
    readonly property bool _plain: _fetch && section.cfg.osPlainText
    readonly property var _rows: _fetch ? section.monitor.osFetchVisibleRows : _builtinRows
    readonly property bool _showLogo: section.cfg.osShowLogo === true && _fetch

    // Label column. Fetch tools emit far longer keys than the built-in four
    // ("Display (AUOE48D)", "Battery (L20L2PF0)"), so the column scales with the
    // widget instead of being fixed at the built-in 46 px.
    readonly property int _labelW: _fetch ? Math.max(52, Math.min(118, Math.round(width * 0.40))) : 46

    // ── Header: distro logo + banner ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        visible: section._showLogo
        spacing: 8

        // Distro logo from the icon theme.
        Image {
            source: section._showLogo ? "image://icon/" + (section.monitor.osLogoIcon || "computer") : ""
            sourceSize: Qt.size(68, 68)
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: section.monitor.osFetchTitle || section.monitor.osDistro
                color: section.monitor.textColor
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: section.monitor.osFetchTool
                color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.40)
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    // ── Plain-text mode ───────────────────────────────────────────────────────
    Flickable {
        visible: section._plain
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: rawText.implicitWidth
        contentHeight: rawText.implicitHeight
        // Long fetch output scrolls instead of growing the card without end.
        implicitHeight: Math.min(contentHeight, 320)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Text {
            id: rawText
            text: section.monitor.osFetchRaw
            color: section.monitor.textColor
            font.family: "monospace"
            font.pixelSize: 10
            textFormat: Text.PlainText
            lineHeight: 1.15
        }
    }

    // ── Parsed rows ───────────────────────────────────────────────────────────
    Flickable {
        visible: !section._plain
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: rowCol.implicitHeight
        implicitHeight: contentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: rowCol
            width: parent.width
            spacing: 0

            Repeater {
                model: section._rows

                Item {
                    Layout.fillWidth: true
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, index % 2 === 0 ? 0.0 : 0.04)
                        radius: 2
                    }

                    Text {
                        id: lblText
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.lbl
                        color: Qt.rgba(section.monitor.textColor.r, section.monitor.textColor.g, section.monitor.textColor.b, 0.40)
                        font.pixelSize: 10
                        width: section._labelW
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.left: lblText.right
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.val || "…"
                        color: section.monitor.textColor
                        font.pixelSize: 11
                        font.bold: modelData.val !== ""
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
