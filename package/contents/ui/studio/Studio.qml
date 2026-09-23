import QtQuick
import QtQuick.Controls.Basic as Controls
import "Theme.js" as Theme
import "Schema.js" as Schema

// The settings studio for Plasma and Hyprland, in the design of the Plasma
// Audio Visualizer's. Hosts own the draft: every change is emitted through
// `edited(next)` and the host assigns it back to `draft`.
Rectangle {
    // Children bind `studio: studioRoot`: their own `studio` property would
    // shadow an id of the same name.
    id: studioRoot
    property var draft: ({})
    property var defaults: ({})
    // "kde" or "hypr": platform notes.
    property string env: "kde"
    // A MonitorCore reading this machine with the draft settings; drives the
    // preview and the device lists. Null shows no preview.
    property var liveMonitor: null
    // Output names, for Hyprland placement.
    property var screenNames: []
    property color previewAccent: "#3daee9"
    property int currentTabIndex: 0
    property string query: ""
    property bool canDiscard: false
    signal edited(var draft)
    signal discard
    signal undo

    readonly property string currentTab: Schema.TABS[currentTabIndex].id
    readonly property string currentGroup: Schema.tabGroup(currentTab)
    readonly property var subTabs: Schema.subTabs(currentGroup, draft)
    // Nothing renders until the host has supplied a draft.
    readonly property bool ready: !!draft && draft.historySize !== undefined
    // Previews run only while the settings window is actually shown.
    readonly property bool onScreen: visible && !!Window.window && Window.window.visible
    readonly property bool anyResults: Schema.SECTIONS.some(section => section.rows.some(row => Schema.rowVisible(row, section, draft, env, query.trim().toLowerCase())) && (query.trim() !== "" || section.tab === currentTab))
    // Keep the layout from bouncing between modes while the dialog is dragged
    // near a breakpoint.
    property bool wide: false
    property bool compact: false
    function updateLayoutMode() {
        wide = wide ? width >= 960 : width >= 1040;
        compact = !wide && (compact ? height < 660 : height < 620);
    }
    onWidthChanged: updateLayoutMode()
    onHeightChanged: updateLayoutMode()
    Component.onCompleted: updateLayoutMode()
    readonly property int inset: compact ? 10 : 20

    function selectTab(id) {
        id = Schema.resolveTab(id, draft);
        currentTabIndex = Math.max(0, Schema.TABS.findIndex(t => t.id === id));
        query = "";
    }
    function update(patch) {
        edited(Object.assign({}, draft, Schema.normalize(patch)));
    }
    // Choices only this machine knows, plus the saved value if it is gone.
    function dynamicOptions(kind, current) {
        const m = liveMonitor;
        let list = [["auto", "Automatic"]];
        if (kind === "screens")
            list = [["", "First screen"], ["all", "Every screen"]].concat(screenNames.map(n => [n, n]));
        else if (m && kind === "ifaces")
            list = list.concat(m.availableIfaces.filter(i => i !== "auto").map(i => [i, i]));
        else if (m && kind === "disks")
            list = list.concat(m.availableDisks.filter(d => d !== "auto").map(d => [d, d]));
        else if (m && kind === "gpus")
            list = list.concat(m.gpuDevices.map(g => [g.pci || g.card, g.card + (g.pci ? " · " + g.pci : "")]));
        if (current && !list.some(o => String(o[0]) === String(current)))
            list.push([current, current + " (not found)"]);
        return list;
    }

    color: Theme.bg
    onCurrentTabIndexChanged: body.contentY = 0
    // Switching the shown section off moves to the next one that is on.
    onDraftChanged: if (ready && Schema.resolveTab(currentTab, draft) !== currentTab)
        selectTab(currentTab)
    onQueryChanged: {
        body.contentY = 0;
        if (searchInput.text !== query)
            searchInput.text = query;
    }

    Shortcut {
        sequence: "/"
        enabled: !searchInput.activeFocus
        onActivated: searchInput.forceActiveFocus()
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        enabled: studioRoot.canDiscard
        onActivated: studioRoot.undo()
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: studioRoot.inset
        width: Math.max(0, parent.width - studioRoot.inset * 2)
        height: Math.max(0, parent.height - studioRoot.inset * 2)

        PreviewPane {
            id: pane
            objectName: "studioPreviewPane"
            compact: studioRoot.compact
            studio: studioRoot
            visible: studioRoot.ready
            x: studioRoot.wide ? panel.width + 20 : 0
            width: studioRoot.wide ? parent.width - panel.width - 20 : parent.width
            height: !visible ? 0 : studioRoot.wide ? parent.height : Math.min(parent.height * 0.45, Math.max(170, parent.height - 440))
        }

        Rectangle {
            id: panel
            y: studioRoot.wide || !pane.visible ? 0 : pane.height + (studioRoot.compact ? 8 : 14)
            width: studioRoot.wide ? Math.max(380, (parent.width - 20) * 0.54) : parent.width
            height: studioRoot.wide ? parent.height : Math.max(0, parent.height - y)
            radius: 18
            border.color: Theme.line2
            border.width: 1
            clip: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.panelTop
                }
                GradientStop {
                    position: 1
                    color: Theme.panelBottom
                }
            }

            Row {
                id: header
                x: 18
                y: studioRoot.compact ? 8 : 16
                width: parent.width - 36
                spacing: 8
                Rectangle {
                    width: Math.max(80, parent.width - (discardBtn.visible ? discardBtn.width + header.spacing : 0))
                    height: 36
                    radius: 10
                    color: Theme.sunk
                    border.color: searchInput.activeFocus ? "#6655ffcc" : Theme.line2
                    border.width: 1
                    Canvas {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.scale(14 / 24, 14 / 24);
                            ctx.strokeStyle = Theme.dim;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.arc(11, 11, 7, 0, Math.PI * 2);
                            ctx.moveTo(20, 20);
                            ctx.lineTo(16.5, 16.5);
                            ctx.stroke();
                        }
                    }
                    TextInput {
                        id: searchInput
                        objectName: "studioSearch"
                        x: 33
                        width: parent.width - 33 - 34
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        clip: true
                        onTextEdited: studioRoot.query = text
                        Keys.onEscapePressed: studioRoot.query = ""
                    }
                    Text {
                        anchors.fill: searchInput
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === ""
                        text: "Search settings…"
                        color: Theme.dim
                        font: searchInput.font
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 4
                        color: "transparent"
                        border.color: Theme.line2
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "/"
                            color: Theme.dim
                            font.pixelSize: 10
                        }
                    }
                }
                StudioButton {
                    id: discardBtn
                    visible: studioRoot.canDiscard
                    text: typeof i18n === "function" ? i18n("Discard") : "Discard"
                    tooltip: "Discard changes not yet applied"
                    areaName: "discardSettings"
                    onClicked: studioRoot.discard()
                }
            }

            Item {
                id: tabs
                objectName: "studioTabs"
                x: 12
                y: header.y + header.height + (studioRoot.compact ? 4 : 12)
                width: parent.width - 24
                height: 36
                clip: true
                Flickable {
                    id: mainTabScroller
                    anchors.fill: parent
                    Controls.ScrollBar.horizontal: Controls.ScrollBar {
                        policy: Controls.ScrollBar.AsNeeded
                    }
                    contentWidth: tabRow.width
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: tabRow
                        spacing: 2
                        Repeater {
                            model: Schema.MAIN_TABS
                            Item {
                                id: tab
                                required property var modelData
                                readonly property bool selected: studioRoot.query.trim() === "" && studioRoot.currentGroup === modelData.id
                                objectName: "mainTab_" + modelData.id
                                width: tabContent.width + 16
                                height: 36
                                Row {
                                    id: tabContent
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -1
                                    spacing: 6
                                    Canvas {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 15
                                        height: 15
                                        readonly property var signature: [tab.selected, tabArea.containsMouse]
                                        onSignatureChanged: requestPaint()
                                        onPaint: {
                                            const ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.scale(15 / 24, 15 / 24);
                                            ctx.strokeStyle = tab.selected || tabArea.containsMouse ? Theme.text : Theme.muted;
                                            ctx.lineWidth = 1.7;
                                            ctx.lineCap = "round";
                                            ctx.lineJoin = "round";
                                            ctx.path = tab.modelData.icon;
                                            ctx.stroke();
                                        }
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tab.modelData.label
                                        color: tab.selected || tabArea.containsMouse ? Theme.text : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                    }
                                }
                                Rectangle {
                                    x: 8
                                    width: parent.width - 16
                                    height: 2
                                    radius: 1
                                    anchors.bottom: parent.bottom
                                    color: Theme.brand
                                    visible: tab.selected
                                }
                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: studioRoot.selectTab(tab.modelData.first || tab.modelData.id)
                                }
                            }
                        }
                    }
                }
                TabScrollArrow {
                    anchors.left: parent.left
                    scroller: mainTabScroller
                    forward: false
                }
                TabScrollArrow {
                    anchors.right: parent.right
                    scroller: mainTabScroller
                }
            }
            Rectangle {
                y: tabs.y + tabs.height
                width: parent.width
                height: 1
                color: Theme.line
            }

            // Second row for grouped tabs (Appearance, Sections).
            Item {
                id: subNavigation
                objectName: "subNavigation"
                x: 18
                y: tabs.y + tabs.height + 1
                width: parent.width - 36
                height: visible ? 48 : 0
                visible: studioRoot.query.trim() === "" && studioRoot.subTabs.length > 0
                Flickable {
                    id: subScroller
                    anchors.fill: parent
                    contentWidth: subRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: subRow
                        y: 10
                        spacing: 6
                        Repeater {
                            model: studioRoot.subTabs
                            StudioButton {
                                required property var modelData
                                text: modelData.label
                                icon: modelData.icon
                                compact: true
                                primary: studioRoot.currentTab === modelData.id
                                areaName: "subTab_" + modelData.id
                                onClicked: studioRoot.selectTab(modelData.id)
                            }
                        }
                        StudioButton {
                            visible: studioRoot.currentGroup === "sections"
                            text: "+ More sections"
                            tooltip: "Only switched-on sections are listed; switch more on under Layout"
                            compact: true
                            areaName: "moreSections"
                            onClicked: studioRoot.selectTab("layout")
                        }
                    }
                }
                TabScrollArrow {
                    anchors.left: parent.left
                    scroller: subScroller
                    forward: false
                    y: 10
                    height: 28
                }
                TabScrollArrow {
                    anchors.right: parent.right
                    scroller: subScroller
                    y: 10
                    height: 28
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.line
                }
            }

            Flickable {
                id: body
                objectName: "studioBody"
                y: subNavigation.y + subNavigation.height
                width: parent.width
                height: parent.height - y
                contentHeight: sections.height + 28
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: Controls.ScrollBar.AsNeeded
                }

                Column {
                    id: sections
                    x: 18
                    y: 6
                    width: body.width - 36
                    spacing: 18
                    Item {
                        width: 1
                        height: 0
                    }
                    Repeater {
                        model: studioRoot.ready ? Schema.SECTIONS.length : 0
                        StudioSection {
                            required property int index
                            width: sections.width
                            studio: studioRoot
                            sectionIndex: index
                        }
                    }
                    Text {
                        width: sections.width
                        visible: studioRoot.ready && !studioRoot.anyResults
                        topPadding: 30
                        horizontalAlignment: Text.AlignHCenter
                        text: "No settings match that search."
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
