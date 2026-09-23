import QtQuick
import "GrainDraw.js" as GrainDraw

// Static card material from the HTML `.surf` recipes: glass, liquid, solid and
// atmosphere, plus the edge line and optional edge highlight. It repaints only
// when size, settings, cover colours or the liquid pointer light change — never
// per audio frame. CardSurface separately blurs a supplied wallpaper item;
// this layer draws the tint and fallback highlights. BackdropBlur refracts
// the captured wallpaper and uses specularPoint for its Fresnel lighting.
Canvas {
    id: card
    objectName: "cardMaterial"

    // glass · liquid · solid · atmosphere · "" (edge highlight only)
    property string material: ""
    property real radius: 12
    property string glassTint: "clear"
    property color glassTintColor: "#3daee9"
    property color solidColor: "transparent"
    property bool grain: false
    property bool specular: true
    property bool edgeHighlight: false
    property color cover1: "#6c7086"
    property color cover2: "#45475a"
    property color cover3: "#11111b"

    antialiasing: true
    renderStrategy: Canvas.Cooperative

    HoverHandler {
        id: hover
        enabled: card.material === "liquid" && card.specular
    }
    readonly property point specularPoint: hover.hovered ? hover.point.position : Qt.point(width * 0.22, -height * 0.1)
    readonly property var signature: [material, grain, radius, glassTint, glassTintColor, solidColor, specular, edgeHighlight, cover1, cover2, cover3, width, height]
    onSignatureChanged: requestPaint()
    onSpecularPointChanged: {
        if (material === "liquid" && specular)
            requestPaint();
    }

    function white(alpha) {
        return Qt.rgba(1, 1, 1, alpha / 255);
    }
    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    // CSS linear-gradient(135deg, …) over the whole card.
    function diagonal(ctx, w, h, stops) {
        const half = (w + h) * Math.SQRT1_2 / 2 * Math.SQRT1_2;
        const gradient = ctx.createLinearGradient(w / 2 - half, h / 2 - half, w / 2 + half, h / 2 + half);
        for (const stop of stops)
            gradient.addColorStop(stop[0], stop[1]);
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, w, h);
    }

    // CSS radial-gradient(rx ry at x y, color, transparent end).
    function ellipse(ctx, w, h, x, y, rx, ry, color, end) {
        ctx.save();
        ctx.translate(x, y);
        ctx.scale(rx, ry);
        const gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, 1);
        gradient.addColorStop(0, color);
        gradient.addColorStop(end, withAlpha(color, 0));
        ctx.fillStyle = gradient;
        ctx.fillRect(-x / rx - 1, -y / ry - 1, w / rx + 2, h / ry + 2);
        ctx.restore();
    }

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

        switch (material) {
        case "glass":
            if (glassTint === "frost")
                diagonal(ctx, w, h, [[0, white(0x42)], [0.55, white(0x24)], [1, white(0x30)]]);
            else if (glassTint === "smoke")
                diagonal(ctx, w, h, [[0, Qt.rgba(0.07, 0.09, 0.12, 0.64)], [1, Qt.rgba(0.03, 0.04, 0.07, 0.4)]]);
            else if (glassTint === "cover")
                diagonal(ctx, w, h, [[0, withAlpha(cover1, 0.38)], [1, withAlpha(cover2, 0.22)]]);
            else if (glassTint === "custom")
                diagonal(ctx, w, h, [[0, withAlpha(glassTintColor, 0.4)], [1, withAlpha(glassTintColor, 0.22)]]);
            else
                diagonal(ctx, w, h, [[0, white(0x24)], [0.55, white(0x08)], [1, white(0x12)]]);
            break;
        case "liquid":
            {
                if (glassTint === "frost")
                    diagonal(ctx, w, h, [[0, white(0x2e)], [0.5, white(0x10)], [1, white(0x22)]]);
                else if (glassTint === "cover")
                    diagonal(ctx, w, h, [[0, withAlpha(cover1, 0.38)], [1, withAlpha(cover2, 0.22)]]);
                else if (glassTint === "smoke")
                    diagonal(ctx, w, h, [[0, Qt.rgba(0.07, 0.09, 0.12, 0.64)], [1, Qt.rgba(0.03, 0.04, 0.07, 0.4)]]);
                else if (glassTint === "custom")
                    diagonal(ctx, w, h, [[0, withAlpha(glassTintColor, 0.4)], [1, withAlpha(glassTintColor, 0.22)]]);
                else
                    diagonal(ctx, w, h, [[0, white(0x1c)], [0.45, white(0x04)], [1, white(0x12)]]);
                // Inner top glow and bottom shade (the inset box-shadows).
                const top = ctx.createLinearGradient(0, 0, 0, 12);
                top.addColorStop(0, white(0x40));
                top.addColorStop(1, white(0));
                ctx.fillStyle = top;
                ctx.fillRect(0, 0, w, 12);
                const bottom = ctx.createLinearGradient(0, h - 16, 0, h);
                bottom.addColorStop(0, Qt.rgba(0, 0, 0, 0));
                bottom.addColorStop(1, Qt.rgba(0, 0, 0, 0.14));
                ctx.fillStyle = bottom;
                ctx.fillRect(0, h - 16, w, 16);
                if (specular) {
                    // Qt exposes the native blend mode under its vendor-prefixed name.
                    ctx.save();
                    ctx.globalCompositeOperation = "qt-soft-light";
                    const p = specularPoint;
                    const light = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, 180);
                    light.addColorStop(0, white(0x59));
                    light.addColorStop(0.62, white(0));
                    ctx.fillStyle = light;
                    ctx.fillRect(0, 0, w, h);
                    ctx.restore();
                }
                break;
            }
        case "solid":
            if (solidColor.a >= 1) {
                ctx.fillStyle = solidColor;
                ctx.fillRect(0, 0, w, h);
            } else {
                diagonal(ctx, w, h, [[0, "#efefe6"], [1, "#d8dece"]]);
            }
            break;
        case "atmosphere":
            {
                ctx.fillStyle = cover3;
                ctx.fillRect(0, 0, w, h);
                ellipse(ctx, w, h, w, 0, w * 1.3, h * 1.5, withAlpha(cover1, 0.75), 0.58);
                ellipse(ctx, w, h, 0, h, w * 1.2, h * 1.3, withAlpha(cover2, 0.8), 0.62);
                const shade = ctx.createLinearGradient(0, 0, 0, h);
                shade.addColorStop(0, Qt.rgba(0, 0, 0, 0));
                shade.addColorStop(1, Qt.rgba(0, 0, 0, 0x4d / 255));
                ctx.fillStyle = shade;
                ctx.fillRect(0, 0, w, h);
                break;
            }
        }

        if (grain)
            GrainDraw.draw(ctx, w, h, true);

        if (edgeHighlight) {
            ctx.fillStyle = white(0x2e);
            ctx.fillRect(0, 0, w, 1);
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0x26 / 255);
            ctx.fillRect(0, h - 1, w, 1);
        }
        ctx.restore();

        if (material === "" || (material === "solid" && solidColor.a >= 1 && !edgeHighlight))
            return;
        ctx.lineWidth = 1;
        const edge = () => {
            ctx.beginPath();
            ctx.roundedRect(0.5, 0.5, w - 1, h - 1, Math.max(0, r - 0.5), Math.max(0, r - 0.5));
            ctx.stroke();
        };
        if (material === "liquid") {
            // Rim light: brighter top, dimmer bottom and sides.
            const sides = [[white(0x99), [0, 0, w, 0]], [white(0x33), [0, h, w, h]], [white(0x40), [0, 0, 0, h]], [white(0x26), [w, 0, w, h]]];
            for (const side of sides) {
                const q = side[1];
                ctx.save();
                ctx.beginPath();
                ctx.moveTo(q[0], q[1]);
                ctx.lineTo(q[2], q[3]);
                ctx.lineTo(w / 2, h / 2);
                ctx.closePath();
                ctx.clip();
                ctx.strokeStyle = side[0];
                edge();
                ctx.restore();
            }
        } else {
            ctx.strokeStyle = material === "solid" ? white(0x99) : white(0x1f);
            edge();
        }
    }
}
