import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema

// One settings row (HTML `.row`): label and description left, control right;
// full-width controls and narrow rows stack the control underneath.
Item {
    id: row
    required property var studio
    required property int sectionIndex
    required property int rowIndex
    property bool first: false

    readonly property var section: Schema.SECTIONS[sectionIndex]
    readonly property var rowData: section.rows[rowIndex]
    readonly property var value: Schema.rowValue(rowData, studio.draft)
    readonly property bool disabledRow: !!rowData.disabled && rowData.disabled(studio.draft)
    readonly property bool hasHead: !!rowData.label
    readonly property real controlWidth: control.item ? control.item.implicitWidth : 0
    readonly property bool stacked: !!rowData.full || width - controlWidth - 18 < 190

    function commit(value) {
        studio.update(Schema.rowPatch(rowData, value, studio.draft));
    }

    objectName: "row_" + (rowData.k || rowData.id)
    visible: Schema.rowVisible(rowData, section, studio.draft, studio.env, studio.query.trim().toLowerCase())
    height: visible ? content.height + 26 : 0
    opacity: disabledRow ? 0.4 : 1
    enabled: !disabledRow

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.line
        visible: !row.first
    }

    Item {
        id: content
        y: 13
        width: parent.width
        height: row.stacked ? head.height + (row.hasHead ? 11 : 0) + control.height : Math.max(head.height, control.height)

        Column {
            id: head
            visible: row.hasHead
            width: row.stacked ? parent.width : parent.width - row.controlWidth - 18
            height: row.hasHead ? implicitHeight : 0
            y: row.stacked ? 0 : (parent.height - height) / 2
            spacing: 2
            Text {
                width: parent.width
                text: row.rowData.label || ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                visible: !!row.rowData.desc
                text: row.rowData.desc || ""
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                lineHeight: 1.2
                wrapMode: Text.WordWrap
            }
        }

        Loader {
            id: control
            active: row.visible
            x: row.stacked ? 0 : parent.width - width
            y: row.stacked ? head.height + (row.hasHead ? 11 : 0) : (parent.height - height) / 2
            width: row.stacked ? parent.width : row.controlWidth
            height: item ? item.implicitHeight : 0
            sourceComponent: ({
                    switch: switchComponent,
                    range: rangeComponent,
                    seg: segComponent,
                    chips: chipsComponent,
                    color: colorComponent,
                    select: selectComponent,
                    tiles: tilesComponent,
                    note: noteComponent,
                    text: textComponent,
                    number: numberComponent,
                    sections: sectionsComponent,
                    looks: looksComponent,
                    ifaces: ifacesComponent,
                    projectInfo: projectInfoComponent
                })[row.rowData.type] ?? null
        }
    }

    Component {
        id: projectInfoComponent
        ProjectInfoPane {
            studio: row.studio
        }
    }

    Component {
        id: switchComponent
        Item {
            implicitWidth: 36
            implicitHeight: 21
            height: 21
            StudioSwitch {
                objectName: "switch_" + (row.rowData.k || row.rowData.id)
                anchors.right: row.stacked ? undefined : parent.right
                checked: !!row.value
                onToggled: checked => row.commit(checked)
            }
        }
    }
    Component {
        id: rangeComponent
        StudioRange {
            from: row.rowData.min
            to: row.rowData.max
            stepSize: row.rowData.step
            value: Number(row.value)
            display: Schema.format(row.rowData.fmt, Number(row.value))
            onMoved: value => row.commit(value)
        }
    }
    Component {
        id: segComponent
        Item {
            implicitWidth: seg.implicitWidth
            implicitHeight: seg.height
            height: seg.height
            StudioSeg {
                id: seg
                anchors.right: row.stacked ? undefined : parent.right
                options: row.rowData.opts
                value: row.value
                onActivated: value => row.commit(value)
            }
        }
    }
    Component {
        id: chipsComponent
        StudioChips {
            options: row.rowData.opts
            value: row.value
            single: row.rowData.single === true
            onActivated: value => row.commit(value)
        }
    }
    Component {
        id: colorComponent
        // One row wide, so an unstacked row does not wrap after every swatch.
        Item {
            implicitWidth: (row.rowData.swatches.length + 1) * 29 - 7
            implicitHeight: swatches.implicitHeight
            StudioSwatches {
                id: swatches
                width: parent.width
                swatches: row.rowData.swatches
                value: String(row.value)
                onActivated: value => row.commit(value)
            }
        }
    }
    Component {
        id: selectComponent
        Item {
            implicitWidth: select.implicitWidth
            implicitHeight: select.implicitHeight
            height: select.implicitHeight
            StudioSelect {
                id: select
                anchors.right: row.stacked ? undefined : parent.right
                options: typeof row.rowData.opts === "string" ? row.studio.dynamicOptions(row.rowData.opts, row.value) : row.rowData.opts
                value: row.value
                onChosen: value => row.commit(value)
            }
        }
    }
    Component {
        id: tilesComponent
        StudioTiles {
            rowData: row.rowData
            studio: row.studio
            value: row.value
            onChosen: value => row.commit(value)
        }
    }
    Component {
        id: noteComponent
        StudioNote {
            title: row.studio.env === "kde" ? "On Plasma" : "On Hyprland"
            text: Schema.NOTES[row.rowData.note][row.studio.env] || ""
        }
    }
    Component {
        id: textComponent
        StudioText {
            implicitWidth: row.stacked ? row.width : 240
            value: String(row.value ?? "")
            placeholder: row.rowData.placeholder || ""
            onCommitted: value => row.commit(value)
        }
    }
    Component {
        id: numberComponent
        StudioText {
            implicitWidth: 120
            numeric: true
            value: String(row.value ?? "")
            onCommitted: value => row.commit(value)
        }
    }
    Component {
        id: ifacesComponent
        InterfaceCards {
            studio: row.studio
            value: row.value
            onChosen: value => row.commit(value)
        }
    }
    Component {
        id: looksComponent
        LookGallery {
            studio: row.studio
        }
    }
    Component {
        id: sectionsComponent
        SectionList {
            studio: row.studio
        }
    }
}
