import QtQuick
import "GrainDraw.js" as GrainDraw

// Film grain (HTML `.grain`, noise at .14 in overlay blending). This separate
// layer has no backdrop texture, so its specks use reduced normal blending.
// CardMaterial paints grain directly with native overlay blending instead.
// Specks are batched into a few paths by shade and strength: per-pixel
// ImageData loops are very slow in QML after their first run.
Canvas {
    id: grain
    objectName: "cardGrain"
    property real radius: 12

    renderStrategy: Canvas.Cooperative
    readonly property var signature: [radius, width, height]
    onSignatureChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;
        if (w <= 0 || h <= 0)
            return;
        const r = Math.max(0, Math.min(radius, w / 2, h / 2));
        ctx.save();
        ctx.beginPath();
        ctx.roundedRect(0, 0, w, h, r, r);
        ctx.clip();
        GrainDraw.draw(ctx, w, h, false);
        ctx.restore();
    }
}
