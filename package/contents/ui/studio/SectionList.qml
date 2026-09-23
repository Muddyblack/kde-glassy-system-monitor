import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema
import "../Sections.js" as Sections

// Which sections the widget shows, in which order, and each one's chart
// style. Shown sections come first, in display order; the rest follow.
Column {
    id: list
    required property var studio

    readonly property var enabledIds: Sections.parse(studio.draft.sections, studio.draft.activeSection)
    readonly property var order: enabledIds.concat(Sections.IDS.filter(id => enabledIds.indexOf(id) === -1))
    readonly property var styles: Schema.parseStyles(studio.draft.sectionStyles)
    readonly property var styleOptions: [["", "Default"]].concat(Schema.CHARTS.map(c => [c.style, c.label]))
    readonly property var chartSections: ["cpu", "memory", "network", "ping", "disk", "gpu", "custom"]
    readonly property var spans: Schema.fields(studio.draft.sectionSpans)
    readonly property bool gridded: (studio.draft.layoutColumns || 1) > 1
    readonly property real rowStep: 46 + spacing
    readonly property var sizes: {
        const out = {};
        for (const pair of Schema.fields(studio.draft.sectionSizes)) {
            const p = pair.split(":");
            if (p.length === 2)
                out[p[0].trim()] = p[1].trim();
        }
        return out;
    }

    spacing: 6

    function commit(ids, styleMap) {
        list.studio.update({
            sections: ids.join(","),
            sectionStyles: Schema.formatStyles(styleMap)
        });
    }
    function toggle(id) {
        const on = enabledIds.indexOf(id) !== -1;
        // At least one section stays on.
        if (on && enabledIds.length === 1)
            return;
        commit(on ? enabledIds.filter(x => x !== id) : enabledIds.concat([id]), styles);
    }
    function moveSection(id, delta) {
        const ids = enabledIds.slice();
        const at = ids.indexOf(id);
        const to = at + delta;
        if (at < 0 || to < 0 || to >= ids.length)
            return;
        ids.splice(at, 1);
        ids.splice(to, 0, id);
        commit(ids, styles);
    }
    // Drop a dragged section at the slot nearest to where it was let go.
    function dropSection(id, y) {
        const at = enabledIds.indexOf(id);
        const to = Math.max(0, Math.min(enabledIds.length - 1, Math.round(y / rowStep)));
        if (at >= 0 && to !== at)
            moveSection(id, to - at);
    }
    function toggleSpan(id) {
        const next = spans.indexOf(id) === -1 ? spans.concat([id]) : spans.filter(x => x !== id);
        list.studio.update({
            sectionSpans: next.join(",")
        });
    }
    function setSize(id, size) {
        const next = Object.assign({}, sizes);
        next[id] = size === "m" ? "" : size;
        list.studio.update({
            sectionSizes: Object.keys(next).filter(k => next[k]).map(k => k + ":" + next[k]).join(",")
        });
    }
    function setStyle(id, style) {
        const next = Object.assign({}, styles);
        next[id] = style;
        commit(enabledIds, next);
    }

    Repeater {
        model: list.order
        Rectangle {
            id: row
            required property string modelData
            required property int index
            readonly property var info: Sections.info(modelData)
            readonly property bool on: list.enabledIds.indexOf(modelData) !== -1
            readonly property int position: list.enabledIds.indexOf(modelData)
            objectName: "sectionRow_" + modelData
            width: list.width
            height: 46
            radius: 11
            color: on ? Theme.sunk : "transparent"
            border.color: dragArea.drag.active ? Theme.tileSelectedBorder : on ? Theme.line2 : Theme.line
            border.width: 1
            z: dragArea.drag.active ? 10 : 0

            // Grip: drag a shown section up or down to reorder.
            Text {
                id: grip
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "⠿"
                color: row.on ? (dragArea.containsMouse || dragArea.drag.active ? Theme.text : Theme.dim) : "transparent"
                font.pixelSize: 16
                MouseArea {
                    id: dragArea
                    objectName: "sectionDrag_" + row.modelData
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: row.on && list.enabledIds.length > 1
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: row
                    drag.axis: Drag.YAxis
                    drag.minimumY: 0
                    drag.maximumY: (list.enabledIds.length - 1) * list.rowStep
                    onReleased: if (drag.active || row.y !== row.position * list.rowStep)
                        list.dropSection(row.modelData, row.y)
                }
            }
            StudioSwitch {
                id: toggle
                objectName: "sectionToggle_" + row.modelData
                x: 26
                anchors.verticalCenter: parent.verticalCenter
                checked: row.on
                onToggled: list.toggle(row.modelData)
            }
            Canvas {
                id: icon
                anchors.left: toggle.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                readonly property var signature: [row.on]
                onSignatureChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(width / 24, height / 24);
                    ctx.strokeStyle = row.on ? Theme.text : Theme.dim;
                    ctx.lineWidth = 1.7;
                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";
                    ctx.path = row.info.icon;
                    ctx.stroke();
                }
            }
            Column {
                anchors.left: icon.right
                anchors.leftMargin: 9
                anchors.right: controls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: Sections.title(row.modelData, list.studio.draft)
                    elide: Text.ElideRight
                    color: row.on ? Theme.text : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                Text {
                    visible: row.on && row.position === 0
                    text: "Shown in panels"
                    color: Theme.dim
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: row.on
                StudioButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: list.gridded
                    compact: true
                    primary: list.spans.indexOf(row.modelData) !== -1
                    text: "Full width"
                    tooltip: "Give this section a row of its own"
                    areaName: "sectionSpan_" + row.modelData
                    onClicked: list.toggleSpan(row.modelData)
                }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: list.chartSections.indexOf(row.modelData) !== -1
                    width: sizeSeg.implicitWidth
                    height: sizeSeg.implicitHeight
                    StudioSeg {
                        id: sizeSeg
                        objectName: "sectionSize_" + row.modelData
                        options: [["s", "S"], ["m", "M"], ["l", "L"]]
                        value: list.sizes[row.modelData] || "m"
                        onActivated: value => list.setSize(row.modelData, value)
                    }
                }
                StudioSelect {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: list.chartSections.indexOf(row.modelData) !== -1 && list.width > (list.gridded ? 520 : 430)
                    implicitWidth: 132
                    options: list.styleOptions
                    value: list.styles[row.modelData] || ""
                    onChosen: value => list.setStyle(row.modelData, value)
                }
            }
        }
    }
}
