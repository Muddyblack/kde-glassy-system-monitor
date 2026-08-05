import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: osSection
    spacing: 0

    // Built-in fallback rows, used when no fetch tool is available (or the
    // integration is switched off). Kept in sync by the cheap /etc/os-release
    // reader in main.qml, which runs regardless of the fetch setting.
    readonly property var _builtinRows: [
        {
            lbl: "OS",
            val: root.osDistro
        },
        {
            lbl: "Kernel",
            val: root.osKernel
        },
        {
            lbl: "Host",
            val: root.osHostname
        },
        {
            lbl: "Uptime",
            val: root.osUptime
        }
    ]

    readonly property bool _fetch: root.osFetchActive
    readonly property bool _plain: _fetch && plasmoid.configuration.osPlainText
    readonly property var _rows: _fetch ? root.osFetchVisibleRows : _builtinRows
    readonly property bool _showLogo: plasmoid.configuration.osShowLogo && _fetch

    // Label column. Fetch tools emit far longer keys than the built-in four
    // ("Display (AUOE48D)", "Battery (L20L2PF0)"), so the column scales with the
    // widget instead of being fixed at the built-in 46 px.
    readonly property int _labelW: _fetch ? Math.max(52, Math.min(118, Math.round(width * 0.40))) : 46

    // ── Header: distro logo + banner ──────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        visible: osSection._showLogo
        spacing: 8

        Kirigami.Icon {
            source: root.osLogoIcon || "computer"
            fallback: "computer"
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.osFetchTitle || root.osDistro
                color: root.textColor
                font.pixelSize: 12
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.osFetchTool
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.40)
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    // ── Plain-text mode ───────────────────────────────────────────────────────
    Flickable {
        visible: osSection._plain
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: rawText.implicitWidth
        contentHeight: rawText.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Text {
            id: rawText
            text: root.osFetchRaw
            color: root.textColor
            font.family: "monospace"
            font.pixelSize: 10
            textFormat: Text.PlainText
            lineHeight: 1.15
        }
    }

    // ── Parsed rows ───────────────────────────────────────────────────────────
    Flickable {
        visible: !osSection._plain
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: rowCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: rowCol
            width: parent.width
            spacing: 0

            Repeater {
                model: osSection._rows

                Item {
                    Layout.fillWidth: true
                    height: 22

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, index % 2 === 0 ? 0.0 : 0.04)
                        radius: 2
                    }

                    Text {
                        id: lblText
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.lbl
                        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.40)
                        font.pixelSize: 10
                        width: osSection._labelW
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.left: lblText.right
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.val || "…"
                        color: root.textColor
                        font.pixelSize: 11
                        font.bold: modelData.val !== ""
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
