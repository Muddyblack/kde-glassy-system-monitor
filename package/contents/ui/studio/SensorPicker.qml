import QtQuick
import QtQuick.Controls as Controls
import "Theme.js" as Theme
import "../SensorConfig.js" as Sensors

// Which sensor readings one section shows, and their display names. One
// collapsible group per device with a checkbox for all of it; a chip's
// cores fold under one "Cores" reading.
Column {
    id: picker
    required property var studio
    required property string targetSection
    objectName: "sensorPicker_" + targetSection

    readonly property var catalog: studio.sensorMonitor ? studio.sensorMonitor.sensorCatalog : []
    readonly property var known: Sensors.byId(catalog)
    readonly property var selected: Sensors.ids(catalog, studio.draft.sensorSelection, targetSection)
    readonly property bool automatic: Sensors.selection(studio.draft.sensorSelection, targetSection) === null
    readonly property var names: Sensors.object(studio.draft.sensorNames)
    property string query: ""
    // Only the structure rebuilds the list, so new samples keep the rows
    // (and a name being typed) in place.
    readonly property string structure: JSON.stringify(Sensors.groups(catalog, selected, names, query))
    readonly property var groups: JSON.parse(structure)
    // Groups and core lists the user opened or closed.
    property var opened: ({})
    property string editing: ""

    function sensor(id) {
        return known[id] || Sensors.placeholder(id);
    }
    function choose(ids) {
        studio.update({
            sensorSelection: Sensors.select(studio.draft.sensorSelection, targetSection, ids)
        });
    }
    function setChosen(ids, on) {
        choose(Sensors.toggle(selected, ids, on));
    }
    // Emptying the name, or typing the original back, drops the new name.
    function rename(id, name) {
        studio.update({
            sensorNames: Sensors.rename(studio.draft.sensorNames, id, name === sensor(id).label ? "" : name)
        });
    }
    function isOpen(key, fallback) {
        return query !== "" || (opened[key] !== undefined ? opened[key] : fallback);
    }
    function setOpen(key, value) {
        opened = Object.assign({}, opened, {
            [key]: value
        });
    }

    spacing: 8

    Row {
        width: parent.width
        spacing: 6
        StudioText {
            id: filter
            width: parent.width - defaultsButton.width - clearButton.width - 12
            placeholder: "Filter by name or device"
            onTextChanged: picker.query = text.toLowerCase()
        }
        StudioButton {
            id: defaultsButton
            compact: true
            anchors.verticalCenter: parent.verticalCenter
            text: "Defaults"
            tooltip: "Follow the automatic choice again"
            enabled: !picker.automatic
            onClicked: picker.choose(null)
        }
        StudioButton {
            id: clearButton
            compact: true
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear"
            enabled: picker.selected.length > 0
            onClicked: picker.choose([])
        }
    }
    Text {
        width: parent.width
        text: (picker.automatic ? "Automatic choice" : picker.selected.length + " chosen") + " · double-click a name or use the pencil to rename it everywhere it shows"
        color: Theme.dim
        font.family: Theme.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: picker.groups
        Rectangle {
            id: group
            required property var modelData
            readonly property var ids: Sensors.groupIds(modelData)
            readonly property int chosen: ids.filter(id => picker.selected.indexOf(id) !== -1).length
            // Groups with chosen readings start open; after that only the
            // user opens and closes them.
            property bool startOpen: false
            readonly property bool open: picker.isOpen(modelData.key, startOpen)
            Component.onCompleted: startOpen = chosen > 0 || picker.groups.length === 1
            width: picker.width
            height: body.height
            radius: 10
            color: Theme.card
            border.width: 1
            border.color: Theme.line

            Column {
                id: body
                width: parent.width

                Item {
                    width: parent.width
                    height: 36
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.setOpen(group.modelData.key, !group.open)
                    }
                    Text {
                        id: chevron
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        rotation: group.open ? 90 : 0
                        color: Theme.muted
                        font.pixelSize: 15
                        Behavior on rotation {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                    StudioCheck {
                        id: groupCheck
                        objectName: "sensorGroup_" + group.modelData.key
                        x: 28
                        anchors.verticalCenter: parent.verticalCenter
                        checked: group.chosen > 0 && group.chosen === group.ids.length
                        partial: group.chosen > 0
                        onToggled: checked => picker.setChosen(group.ids, checked)
                    }
                    Text {
                        id: groupTitle
                        anchors.left: groupCheck.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.title
                        textFormat: Text.PlainText
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.left: groupTitle.right
                        anchors.leftMargin: 8
                        anchors.right: count.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.modelData.detail
                        textFormat: Text.PlainText
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        id: count
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: group.chosen + " / " + group.ids.length
                        color: group.chosen ? Theme.brand : Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Column {
                    width: parent.width
                    visible: group.open
                    bottomPadding: 6
                    Repeater {
                        model: group.open ? group.modelData.items : []
                        Column {
                            id: item
                            required property var modelData
                            readonly property bool coresOpen: picker.isOpen(modelData.id, false)
                            width: parent.width
                            SensorLine {
                                sensorId: item.modelData.id
                                members: item.modelData.members
                                membersOpen: item.coresOpen
                            }
                            Repeater {
                                model: item.coresOpen ? item.modelData.members : []
                                SensorLine {
                                    required property string modelData
                                    sensorId: modelData
                                    indent: 22
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: picker.groups.length === 0
        text: picker.query ? "No reading matches “" + filter.text + "”." : "Waiting for sensors. Temperatures and fans need lm-sensors (sensors -j); CPU power needs readable RAPL counters or a CPU power sensor."
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }

    // One reading: checkbox, name (renamed ones keep the original in grey),
    // live value, rename button; a Cores reading can unfold its cores.
    component SensorLine: Item {
        id: line
        property string sensorId
        property var members: []
        property bool membersOpen: false
        property real indent: 0
        readonly property var sensor: picker.sensor(sensorId)
        readonly property bool chosen: picker.selected.indexOf(sensorId) !== -1
        readonly property string custom: picker.names[sensorId] || ""
        readonly property bool editing: picker.editing === sensorId
        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: 6
            color: hover.hovered ? Theme.hover : "transparent"
        }
        HoverHandler {
            id: hover
        }
        StudioCheck {
            id: check
            objectName: "sensor_" + line.sensorId
            x: 28 + line.indent
            anchors.verticalCenter: parent.verticalCenter
            checked: line.chosen
            partial: line.members.some(id => picker.selected.indexOf(id) !== -1)
            onToggled: checked => picker.setChosen([line.sensorId], checked)
        }
        Item {
            id: nameArea
            anchors.left: check.right
            anchors.leftMargin: 10
            anchors.right: coresToggle.visible ? coresToggle.left : value.left
            anchors.rightMargin: 8
            height: parent.height
            Text {
                id: name
                visible: !line.editing
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width)
                text: line.custom || line.sensor.label
                textFormat: Text.PlainText
                color: line.sensor.missing ? Theme.muted : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                elide: Text.ElideRight
            }
            Text {
                visible: !line.editing && (line.custom !== "" || !!line.sensor.missing)
                anchors.left: name.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: line.sensor.missing ? "not detected" : line.sensor.label
                textFormat: Text.PlainText
                color: Theme.dim
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            MouseArea {
                visible: !line.editing
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.setChosen([line.sensorId], !line.chosen)
                onDoubleClicked: picker.editing = line.sensorId
            }
            StudioText {
                id: nameField
                visible: line.editing
                width: parent.width
                height: 26
                anchors.verticalCenter: parent.verticalCenter
                value: line.custom || line.sensor.label
                placeholder: line.sensor.label
                onCommitted: value => picker.rename(line.sensorId, value)
                onFinished: if (picker.editing === line.sensorId)
                    picker.editing = ""
                onVisibleChanged: if (visible)
                    edit()
            }
        }
        Text {
            id: coresToggle
            visible: line.members.length > 0
            anchors.right: value.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: line.members.length + " cores " + (line.membersOpen ? "▴" : "▾")
            color: coresArea.containsMouse ? Theme.text : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            MouseArea {
                id: coresArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.setOpen(line.sensorId, !line.membersOpen)
            }
        }
        Text {
            id: value
            anchors.right: pencil.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 70
            horizontalAlignment: Text.AlignRight
            text: Sensors.reading(line.sensor)
            color: line.chosen ? Theme.outputText : Theme.dim
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.features: {
                "tnum": 1
            }
        }
        Canvas {
            id: pencil
            objectName: "rename_" + line.sensorId
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            opacity: pencilArea.containsMouse || line.editing ? 1 : hover.hovered || line.custom ? 0.7 : 0.3
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 24, height / 24);
                ctx.strokeStyle = Theme.text;
                ctx.lineWidth = 1.8;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.path = "M4 20h4L19 9l-4-4L4 16v4zM13.5 6.5l4 4";
                ctx.stroke();
            }
            MouseArea {
                id: pencilArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.editing = line.editing ? "" : line.sensorId
            }
            Controls.ToolTip.visible: pencilArea.containsMouse
            Controls.ToolTip.text: "Rename"
            Controls.ToolTip.delay: 500
        }
    }
}
