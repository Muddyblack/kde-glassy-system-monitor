import QtQuick
import QtQuick.Controls.Basic as Controls
import ".."
import "Theme.js" as Theme
import "StudioCatalog.js" as Catalog

// Live preview: the real widget, reading this machine, with the draft
// settings, over a choice of wallpapers — as a desktop card or a panel pill.
Rectangle {
    id: pane
    required property var studio
    property string backdrop: "sea"
    property string form: "widget"
    property string zoom: "fit"
    property bool compact: false

    readonly property var draft: studio.draft
    // Live reads this machine; Demo plays full, moving sample data.
    property bool live: !!studio.liveMonitor
    readonly property var monitor: live && studio.liveMonitor ? studio.liveMonitor : demoMonitor

    MonitorCore {
        id: demoMonitor
        live: false
        cfg: pane.draft
        onScreen: !pane.live && pane.studio.onScreen
        systemAccent: pane.studio.previewAccent
        systemTextColor: "#eff0f1"
        writeConfig: (key, value) => pane.studio.update({
                [key]: value
            })
    }
    DemoFeeder {
        monitor: demoMonitor
        running: !pane.live && pane.studio.onScreen
    }
    readonly property real cardWidth: Math.max(220, card.preferredWidth)
    readonly property real cardHeight: card.preferredHeight
    readonly property real stageTop: topOptions.y + topOptions.height + 10
    readonly property real stageBottom: bottomOptions.height + 22
    readonly property real fitScale: Math.max(0.25, Math.min(1, (width - 40) / cardWidth, Math.max(0, height - stageTop - stageBottom) / cardHeight))
    readonly property real zoomScale: zoom === "fit" ? fitScale : Number(zoom)

    radius: 18
    color: Theme.panel
    border.color: Theme.line2
    border.width: 1
    clip: true

    Backdrop {
        id: backdropImage
        anchors.fill: parent
        anchors.margins: 1
        kind: pane.backdrop
    }

    // Desktop form: the card, scaled to fit.
    Flickable {
        id: stage
        x: 0
        y: pane.stageTop
        width: pane.width
        height: pane.height - pane.stageTop - pane.stageBottom
        visible: pane.form === "widget"
        contentWidth: Math.max(width, pane.cardWidth * pane.zoomScale)
        contentHeight: Math.max(height, pane.cardHeight * pane.zoomScale)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: pane.zoom !== "fit"
        Item {
            x: Math.max(0, (stage.width - width) / 2)
            y: Math.max(0, (stage.height - height) / 2)
            width: pane.cardWidth * pane.zoomScale
            height: pane.cardHeight * pane.zoomScale
            MonitorView {
                id: card
                objectName: "previewWidget"
                width: pane.cardWidth
                height: pane.cardHeight
                scale: pane.zoomScale
                transformOrigin: Item.TopLeft
                monitor: pane.monitor
                cfg: pane.draft
                backdrop: backdropImage
            }
        }
    }

    // Panel form: a floating panel with the pill in it.
    Rectangle {
        visible: pane.form === "panel"
        anchors.horizontalCenter: parent.horizontalCenter
        y: pane.stageTop + (pane.height - pane.stageTop - pane.stageBottom - height) / 2
        width: Math.min(pane.width - 40, pill.implicitWidth + 220)
        height: 44
        radius: pane.studio.env === "kde" ? 12 : 14
        color: pane.studio.env === "kde" ? "#e0202326" : "#e611111b"
        border.width: pane.studio.env === "kde" ? 1 : 2
        border.color: pane.studio.env === "kde" ? "#14ffffff" : "#5589b4fa"
        Row {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: 3
                Rectangle {
                    width: 22
                    height: 22
                    radius: 6
                    color: "#1affffff"
                }
            }
        }
        CompactRepresentation {
            id: pill
            anchors.centerIn: parent
            width: implicitWidth
            height: 34
            monitor: pane.monitor
            cfg: pane.draft
            inPanel: true
        }
    }

    component Chip: Rectangle {
        default property alias content: chipRow.data
        width: chipRow.implicitWidth + 8
        height: 30
        radius: 10
        color: "#cc0b0c0d"
        border.color: "#1fffffff"
        border.width: 1
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
        }
    }
    component ChipLabel: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        leftPadding: 6
        rightPadding: 2
        color: "#8a9187"
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 0.5
    }
    component ChipButton: Rectangle {
        id: chipButton
        property string label: ""
        property bool pressed: false
        signal clicked
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: buttonLabel.implicitWidth + 16
        height: 22
        radius: 7
        color: pressed ? "#1affffff" : "transparent"
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: chipButton.label
            color: chipButton.pressed ? "#ffffff" : "#aab1a7"
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chipButton.clicked()
        }
    }

    Flow {
        id: topOptions
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 8
        Chip {
            ChipLabel {
                text: "WALLPAPER"
            }
            Repeater {
                model: Catalog.StudioCatalog.wallpapers
                Item {
                    id: backdropButton
                    required property var modelData
                    objectName: "wallpaper_" + modelData.id
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 20
                    Controls.ToolTip.visible: wallpaperArea.containsMouse
                    Controls.ToolTip.text: modelData.label
                    Controls.ToolTip.delay: 400
                    Backdrop {
                        anchors.fill: parent
                        kind: backdropButton.modelData.id
                        decodeWidth: 96
                    }
                    Rectangle {
                        readonly property bool current: pane.backdrop === backdropButton.modelData.id
                        anchors.fill: parent
                        anchors.margins: current ? -2 : 0
                        radius: 6
                        color: "transparent"
                        border.width: current ? 2 : 1
                        border.color: current ? "#ffffff" : "#30ffffff"
                    }
                    MouseArea {
                        id: wallpaperArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.backdrop = backdropButton.modelData.id
                    }
                }
            }
        }
        Chip {
            ChipLabel {
                text: "DATA"
            }
            Repeater {
                model: [[true, "Live"], [false, "Demo"]]
                ChipButton {
                    required property var modelData
                    objectName: "previewData_" + (modelData[0] ? "live" : "demo")
                    visible: !modelData[0] || !!pane.studio.liveMonitor
                    label: modelData[1]
                    pressed: pane.live === modelData[0]
                    onClicked: pane.live = modelData[0]
                }
            }
        }
        Chip {
            ChipLabel {
                text: "SHOW AS"
            }
            Repeater {
                model: [["widget", "Desktop widget"], ["panel", "Panel"]]
                ChipButton {
                    required property var modelData
                    label: modelData[1]
                    pressed: pane.form === modelData[0]
                    onClicked: pane.form = modelData[0]
                }
            }
        }
    }

    Flow {
        id: bottomOptions
        x: 12
        width: parent.width - 24
        y: parent.height - height - 12
        spacing: 8
        layoutDirection: Qt.RightToLeft
        Chip {
            visible: pane.form === "widget"
            Repeater {
                model: [["1", "1×"], ["2", "2×"], ["fit", "Fit"]]
                ChipButton {
                    required property var modelData
                    label: modelData[1]
                    pressed: pane.zoom === modelData[0]
                    onClicked: pane.zoom = modelData[0]
                }
            }
        }
        Rectangle {
            width: sizeInfo.implicitWidth + 18
            height: 26
            radius: 8
            color: "#cc0b0c0d"
            border.color: "#1affffff"
            border.width: 1
            Text {
                id: sizeInfo
                anchors.centerIn: parent
                text: (pane.live ? "live" : "demo") + (pane.form === "panel" ? " · first section" : " · " + Math.round(pane.cardWidth) + " × " + Math.round(pane.cardHeight) + " px")
                color: "#b0e6ebe3"
                font.family: "monospace"
                font.pixelSize: 10
            }
        }
    }
}
