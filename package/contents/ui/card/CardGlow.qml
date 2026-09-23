import QtQuick

// CSS box-shadow outside a rounded card: card shadows and the alert glow.
// From plasma-audio-visualizer.
// The owner anchors it `margin` px beyond the card. Each layer is a separable
// Gaussian of its offset, spread box (as the shaders compute glow): a
// horizontal gradient multiplied by a vertical one with destination-in, then
// the card interior is cleared. Only native gradient fills run — Canvas
// shadowBlur and per-pixel ImageData loops both took seconds in QML.
// Painted once per size/setting change; animating the glow changes opacity.
Item {
    id: glow

    property real margin: 90
    property real radius: 12
    // [{ y, blur, spread, color }]; blur is the CSS blur radius (sigma = blur / 2).
    property var layers: []
    property color insetColor: "transparent"

    // Abramowitz & Stegun 7.1.27, error below 5e-4.
    function erf(x) {
        const a = Math.abs(x);
        let t = 1 + (0.278393 + (0.230389 + (0.000972 + 0.078108 * a) * a) * a) * a;
        t *= t;
        return Math.sign(x) * (1 - 1 / (t * t));
    }

    // Blurred coverage of [lo, hi] at position p.
    function coverage(p, lo, hi, sigma) {
        const k = Math.SQRT1_2 / Math.max(0.5, sigma);
        return 0.5 * (erf((hi - p) * k) - erf((lo - p) * k));
    }

    // Gradient stops along one axis, dense where the edges ramp.
    function stops(length, lo, hi, sigma) {
        const positions = [0, length];
        for (const edge of [lo, hi])
            for (let k = -3; k <= 3; k += 0.25)
                positions.push(edge + k * Math.max(0.5, sigma));
        return positions.filter(p => p >= 0 && p <= length).sort((a, b) => a - b).filter((p, i, all) => i === 0 || p - all[i - 1] > 0.01).map(p => [p / length, coverage(p, lo, hi, sigma)]);
    }

    function clearCard(ctx) {
        const w = width - 2 * margin, h = height - 2 * margin;
        const r = Math.max(0, Math.min(radius, w / 2, h / 2));
        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "black";
        ctx.beginPath();
        ctx.roundedRect(margin, margin, w, h, r, r);
        ctx.fill();
        ctx.globalCompositeOperation = "source-over";
    }

    Repeater {
        model: glow.layers
        Canvas {
            required property var modelData
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            readonly property var signature: [glow.margin, glow.radius, modelData, width, height]
            onSignatureChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const W = width, H = height, m = glow.margin;
                const w = W - 2 * m, h = H - 2 * m;
                if (w <= 0 || h <= 0)
                    return;
                const layer = modelData;
                const spread = layer.spread || 0, sigma = (layer.blur || 0) / 2, c = layer.color;
                const horizontal = ctx.createLinearGradient(0, 0, W, 0);
                for (const stop of glow.stops(W, m - spread, m + w + spread, sigma))
                    horizontal.addColorStop(stop[0], Qt.rgba(c.r, c.g, c.b, c.a * stop[1]));
                ctx.fillStyle = horizontal;
                ctx.fillRect(0, 0, W, H);
                const vertical = ctx.createLinearGradient(0, 0, 0, H);
                for (const stop of glow.stops(H, m - spread + layer.y, m + h + spread + layer.y, sigma))
                    vertical.addColorStop(stop[0], Qt.rgba(0, 0, 0, stop[1]));
                ctx.globalCompositeOperation = "destination-in";
                ctx.fillStyle = vertical;
                ctx.fillRect(0, 0, W, H);
                // Like box-shadow, nothing is painted underneath the card itself.
                glow.clearCard(ctx);
            }
        }
    }

    Canvas {
        anchors.fill: parent
        visible: glow.insetColor.a > 0
        renderStrategy: Canvas.Cooperative
        readonly property var signature: [glow.margin, glow.radius, glow.insetColor, width, height]
        onSignatureChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const m = glow.margin, w = width - 2 * m, h = height - 2 * m;
            if (w <= 1 || h <= 1 || glow.insetColor.a <= 0)
                return;
            const r = Math.max(0, Math.min(glow.radius, w / 2, h / 2));
            ctx.strokeStyle = glow.insetColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.roundedRect(m + 0.5, m + 0.5, w - 1, h - 1, Math.max(0, r - 0.5), Math.max(0, r - 0.5));
            ctx.stroke();
        }
    }
}
