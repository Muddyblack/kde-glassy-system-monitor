import QtQuick
import "diagram"
import "diagram/DiagramData.js" as DiagramData

// A Diagram wired to the widget-wide chart settings. Sections only add their
// series, scale and sample clock. A per-section style from `sectionStyles`
// ("memory:donut,cpu:line") overrides the global chart type.
Diagram {
    id: metric

    required property var monitor
    required property var cfg
    property string sectionId: ""
    property var clock: null

    readonly property string sectionStyle: {
        const pairs = String(cfg.sectionStyles || "").split(",");
        for (const pair of pairs) {
            const parts = pair.split(":");
            if (parts.length === 2 && parts[0].trim() === sectionId && DiagramData.STYLES.indexOf(parts[1].trim()) !== -1)
                return parts[1].trim();
        }
        return "";
    }

    readonly property string sizeClass: {
        for (const pair of String(cfg.sectionSizes || "").split(",")) {
            const parts = pair.split(":");
            if (parts.length === 2 && parts[0].trim() === sectionId)
                return parts[1].trim();
        }
        return "m";
    }
    // Chart height the section asks for, and how much of it may be given up
    // when space is short: a chart never shrinks below 40 px.
    readonly property real wantedHeight: visible ? ({
            s: 56,
            m: 90,
            l: 150
        })[sizeClass] ?? 90 : 0
    readonly property real slack: Math.max(0, wantedHeight - 40)

    style: sectionStyle || DiagramData.styleName(cfg.chartType || 0)
    visible: style !== "text"
    renderer: cfg.chartRenderer === "canvas" ? "canvas" : "gpu"
    historySize: Math.max(10, cfg.historySize || 60)
    sampleSerial: clock ? clock.generation : 0
    livePhase: clock && scrolling && smoothScroll ? monitor.drawPhase(clock) : 0
    smoothScroll: !!cfg.smoothScroll
    smoothLines: cfg.smoothLines !== false
    lineWidth: cfg.lineWidth || 2.2
    glow: cfg.glowLine ? Math.max(0.15, cfg.bloomStrength === undefined ? 0.6 : cfg.bloomStrength) : 0
    bloom: !!cfg.gpuBloom
    axis: !!cfg.showYLabels
    strongGrid: !!cfg.showGridLines
    textColor: monitor.textColor
    fontFamily: monitor.fontFamily
    onScreen: monitor.onScreen
    onPaintRequested: monitor.notePaintRequested()
    onPainted: monitor.notePainted()

    Connections {
        target: metric.monitor
        function onRepaintCharts() {
            metric.repaint();
        }
    }
}
