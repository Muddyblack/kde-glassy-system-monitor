import QtQuick
import "Sections.js" as Sections
import "SectionModels.js" as SectionModels

// The panel pill: the chosen sections side by side, or stacked in a vertical
// panel, each as values, a sparkline or mini bars. Every reading comes from
// SectionModels.pill, which the website's pill draws as well.
Item {
    id: compact

    required property var monitor
    required property var cfg
    // Kept for hosts that still set it; the pill looks the same everywhere.
    property bool inPanel: true
    // A vertical panel: the width is given, the readings stack.
    property bool vertical: false
    // Clicked: the host opens, closes or pins the full card.
    signal activated
    // The pointer is over the pill, for hosts that show the card on hover.
    readonly property bool hovered: hover.hovered

    readonly property var ids: Sections.panelIds(cfg)
    readonly property string style: cfg.panelStyle || "values"
    // Too short for a caption above the value: one line per reading.
    readonly property bool thin: !vertical && height > 0 && height < 30
    readonly property int hPad: vertical ? 3 : 7
    readonly property int vPad: 3
    readonly property int gap: vertical ? 6 : 9
    readonly property string fontFamily: monitor ? monitor.fontFamily : Qt.application.font.family
    readonly property var digits: ({
            "tnum": 1
        })

    implicitWidth: vertical ? 0 : readings.implicitWidth + hPad * 2
    implicitHeight: vertical ? readings.implicitHeight + vPad * 2 + 4 : 0

    function tint(c) {
        return cfg.panelPlainText || !c ? monitor.textColor : Qt.color(c);
    }
    function faded(c, alpha) {
        const t = tint(c);
        return Qt.rgba(t.r, t.g, t.b, alpha);
    }

    HoverHandler {
        id: hover
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: compact.activated()
    }

    // The pill hugs the readings; Plasma can leave a wider slot around them.
    Rectangle {
        visible: !!compact.cfg.panelShowBg
        anchors.centerIn: parent
        width: Math.min(parent.width, readings.width + compact.hPad * 2)
        height: Math.min(parent.height - 2, readings.height + compact.vPad * 2 + (compact.vertical ? 4 : 0))
        radius: Math.min(width, height) / 2
        color: compact.cfg.bgColor || "#800d0f1a"
        border.color: Qt.rgba(1, 1, 1, 0.13)
        border.width: compact.cfg.cardBorder ? 1 : 0
    }

    Grid {
        id: readings
        anchors.centerIn: parent
        columns: compact.vertical ? 1 : compact.ids.length
        rowSpacing: compact.gap
        columnSpacing: compact.gap
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: compact.ids
            Row {
                id: reading
                required property string modelData
                required property int index
                readonly property var model: compact.monitor ? SectionModels.pill(modelData, compact.monitor, compact.cfg) : null
                readonly property bool twoLines: !!model && model.lines.length > 1
                readonly property bool charted: compact.style !== "values" && !!model && model.history.length > 1
                // Room across the panel, and the type sizes that fill it.
                readonly property real across: compact.vertical ? compact.width - compact.hPad * 2 : compact.height - compact.vPad * 2
                readonly property int valuePx: compact.vertical ? Math.max(8, Math.min(14, Math.round(across * 0.26))) : compact.thin ? Math.max(8, Math.round(across * 0.6)) : twoLines ? Math.max(8, Math.floor(across / 2 / 1.25)) : Math.max(10, Math.round(across * 0.42))
                readonly property int labelPx: compact.vertical ? Math.max(7, valuePx - 3) : compact.thin ? valuePx : Math.max(7, Math.round(across * 0.25))
                readonly property bool meter: compact.style === "values" && !compact.thin && !twoLines && !!model && model.ratio >= 0

                spacing: 5
                visible: !!model
                // In a vertical panel a reading is a column; Row keeps one child.
                width: compact.vertical ? reading.across : implicitWidth

                Column {
                    id: text
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    width: compact.vertical ? reading.across : implicitWidth

                    // Caption above one value, or inline before it on a thin panel.
                    Text {
                        visible: !reading.twoLines && !compact.thin
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: compact.vertical ? parent.width : implicitWidth
                        text: reading.model ? reading.model.label : ""
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        color: Qt.rgba(compact.monitor.textColor.r, compact.monitor.textColor.g, compact.monitor.textColor.b, 0.55)
                        font.family: compact.fontFamily
                        font.pixelSize: reading.labelPx
                    }
                    // Two readings stack, or sit side by side on a thin panel.
                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: compact.thin ? 2 : 1
                        columnSpacing: 6
                        Repeater {
                            model: reading.model ? reading.model.lines : []
                            Row {
                                id: line
                                required property var modelData
                                required property int index
                                spacing: 3
                                TextMetrics {
                                    id: widest
                                    font.family: compact.fontFamily
                                    font.pixelSize: reading.valuePx
                                    font.bold: true
                                    font.features: compact.digits
                                    text: reading.model ? reading.model.sample : ""
                                }
                                Text {
                                    visible: compact.thin && !reading.twoLines
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: reading.model ? reading.model.label : ""
                                    color: Qt.rgba(compact.monitor.textColor.r, compact.monitor.textColor.g, compact.monitor.textColor.b, 0.55)
                                    font.family: compact.fontFamily
                                    font.pixelSize: reading.labelPx
                                }
                                Text {
                                    visible: !!line.modelData.mark
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: line.modelData.mark || ""
                                    color: compact.faded(line.modelData.color, 0.65)
                                    font.family: compact.fontFamily
                                    font.pixelSize: reading.valuePx
                                    font.bold: true
                                }
                                // A fixed column measured on the widest reading, so the
                                // pill never changes width and the panel never re-lays out.
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: compact.vertical ? Math.min(Math.ceil(widest.advanceWidth), reading.across - x) : Math.ceil(widest.advanceWidth)
                                    text: line.modelData.text
                                    horizontalAlignment: compact.vertical ? Text.AlignHCenter : Text.AlignRight
                                    fontSizeMode: compact.vertical ? Text.HorizontalFit : Text.FixedSize
                                    minimumPixelSize: 6
                                    color: compact.tint(line.modelData.color)
                                    font.family: compact.fontFamily
                                    font.pixelSize: reading.valuePx
                                    font.bold: true
                                    font.features: compact.digits
                                }
                            }
                        }
                    }
                    // Meter under a percent reading.
                    Item {
                        visible: reading.meter
                        width: parent.width
                        height: 5
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: compact.faded(reading.model ? reading.model.color : "", 0.2)
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, reading.model ? reading.model.ratio : 0))
                                height: parent.height
                                radius: parent.radius
                                color: compact.tint(reading.model ? reading.model.color : "")
                            }
                        }
                    }
                    // Vertical panels put the chart under the value.
                    Loader {
                        active: compact.vertical && reading.charted
                        visible: active
                        width: parent.width
                        height: active ? Math.round(reading.across * 0.45) + 3 : 0
                        sourceComponent: chartComponent
                    }
                }
                Loader {
                    active: !compact.vertical && reading.charted
                    visible: active
                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? Math.round(reading.across * (compact.thin ? 1.9 : 1.3)) : 0
                    height: active ? Math.round(reading.across * (compact.thin ? 0.8 : 0.72)) : 0
                    sourceComponent: chartComponent
                }

                Component {
                    id: chartComponent
                    Canvas {
                        id: chart
                        readonly property var model: reading.model
                        readonly property bool bars: compact.style === "bars"
                        renderStrategy: Canvas.Cooperative
                        onModelChanged: requestPaint()
                        onBarsChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (!model)
                                return;
                            const top = compact.vertical ? 3 : 1, h = height - top;
                            const draw = (values, c, alpha, main) => {
                                const col = compact.tint(c);
                                if (bars) {
                                    // One bar per two pixels and a gap, newest on the right.
                                    const n = Math.max(4, Math.floor(width / 3)), list = values.slice(-n), w = width / n;
                                    ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, alpha);
                                    for (let i = 0; i < list.length; i++) {
                                        const v = Math.max(0, Math.min(1, list[i] / model.max)) * h;
                                        ctx.fillRect(width - (list.length - i) * w, top + h - Math.max(1, v), Math.max(1, w - 1), Math.max(1, v));
                                    }
                                    return;
                                }
                                const list = values.slice(-Math.max(8, Math.floor(width / 2))), step = width / Math.max(1, list.length - 1);
                                const y = v => top + h - Math.max(0, Math.min(1, v / model.max)) * (h - 1);
                                ctx.beginPath();
                                ctx.moveTo(0, y(list[0]));
                                for (let i = 1; i < list.length; i++)
                                    ctx.lineTo(i * step, y(list[i]));
                                ctx.lineWidth = main ? 1.4 : 1;
                                ctx.lineJoin = "round";
                                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, alpha);
                                ctx.stroke();
                                if (!main)
                                    return;
                                ctx.lineTo(width, height);
                                ctx.lineTo(0, height);
                                ctx.closePath();
                                const g = ctx.createLinearGradient(0, top, 0, height);
                                g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.3));
                                g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0));
                                ctx.fillStyle = g;
                                ctx.fill();
                            };
                            if (model.history2.length > 1)
                                draw(model.history2, model.lines[1] ? model.lines[1].color : model.color, 0.55, false);
                            draw(model.history, model.color, 1, true);
                        }
                    }
                }
            }
        }
    }
}
