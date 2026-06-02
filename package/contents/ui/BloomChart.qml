// Split-layer chart with GPU bloom.
//
// A section's chart has two visual parts: the *data lines* (which should glow)
// and the *axis / grid / labels / fill* (which must stay crisp — blurring text
// looks broken). To bloom only the lines, we draw the same paint routine onto
// TWO stacked canvases:
//
//   • linesCanvas — draws ONLY the glowable strokes (glowPass === true). It is
//     the source for a MultiEffect blur, composited UNDER the crisp chart to
//     read as a halo, at ~zero CPU cost.
//   • mainCanvas  — draws the full chart (axis, grid, fill, crisp lines) with
//     the CPU shadowBlur glow suppressed, so it sits sharp on top of the bloom.
//
// When gpuBloom is OFF we collapse to a single canvas using the original
// in-canvas shadowBlur glow — zero behavioural change, no extra layer cost.
//
// Usage: give `paint` a function(ctx, glowPass) that runs the section's draw
// logic. Read glowPass to decide whether to emit only the glowing strokes.
// Call `requestPaint()` on this item to repaint.
import QtQuick
import QtQuick.Effects

Item {
    id: chart

    // function(ctx, glowPass): the section's draw routine. glowPass===true means
    // "draw only the strokes that should bloom, nothing else".
    property var paint: null

    // Bloom is active only when the user enabled it AND glow is on at all.
    readonly property bool bloomActive: plasmoid.configuration.gpuBloom && plasmoid.configuration.glowLine
    // 0.25..1.0 mapped from the bloomStrength slider — keeps a visible minimum.
    readonly property real bloomBlur: 0.25 + 0.75 * Math.max(0, Math.min(1, plasmoid.configuration.bloomStrength))

    function requestPaint() {
        mainCanvas.requestPaint();
        if (bloomActive)
            linesCanvas.requestPaint();
    }

    // Toggling bloom on/off (or glow off) changes what BOTH canvases must draw:
    //   • bloom ON  → mainCanvas must SUPPRESS its CPU glow (cu.glowFor → 0) and
    //                 linesCanvas must (re)draw to feed the halo.
    //   • bloom OFF → mainCanvas must redraw WITH the CPU shadowBlur glow back.
    // Without this, the last cached paint sticks and the glow appears to vanish.
    onBloomActiveChanged: {
        mainCanvas.requestPaint();
        linesCanvas.requestPaint();
    }

    // ── bloom halo (GPU), drawn UNDER the crisp chart ─────────────────────────
    // Instead of using a separate MultiEffect sibling item and opacity:0 (which
    // causes layout/positioning drift and initialization bugs in the scene graph),
    // we apply MultiEffect directly as a layer.effect. Since visible is bound to
    // bloomActive, the canvas is only visible/active when needed, ensuring its
    // layout coordinates are perfectly updated and it repaints correctly when toggled.
    Canvas {
        id: linesCanvas
        anchors.fill: parent
        visible: chart.bloomActive
        z: 0
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        layer.enabled: chart.bloomActive
        layer.smooth: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: chart.bloomBlur
            blurMax: 32
            // Keep brightness low so the halo stays the LINE's color instead of
            // washing toward white, and push saturation up so it reads as a vivid
            // neon glow rather than a milky haze.
            brightness: 0.10
            saturation: 0.45
            // autoPadding ON: lets the blur spread past the canvas edges and fade
            // softly. With it off the glow was sliced flat at the chart border.
            autoPaddingEnabled: true
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (chart.bloomActive && chart.paint)
                chart.paint(ctx, true);   // glow pass: strokes only
        }
    }

    // ── crisp chart (CPU), on top of the bloom ────────────────────────────────
    Canvas {
        id: mainCanvas
        anchors.fill: parent
        antialiasing: true
        renderStrategy: Canvas.Cooperative
        z: 1
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (chart.paint)
                chart.paint(ctx, false);  // full pass; CPU glow suppressed if bloomActive
        }
    }
}
