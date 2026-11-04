import QtQuick
import "GrainDraw.js" as GrainDraw
import "../Sections.js" as Sections

// Static card material from the HTML `.surf` recipes: glass, liquid, solid and
// atmosphere, plus the edge line and optional edge highlight. It repaints only
// when size, settings, cover colours or the liquid pointer light change — never
// per audio frame. CardSurface separately blurs a supplied wallpaper item;
// this layer draws the tint and fallback highlights. BackdropBlur refracts
// the captured wallpaper and uses specularPoint for its Fresnel lighting.
Canvas {
    id: card
    objectName: "cardMaterial"

    // glass · liquid · solid · atmosphere · gradient · outline · "" (edge highlight only)
    property string material: ""
    property real radius: 12
    property string glassTint: "clear"
    property color glassTintColor: "#3daee9"
    // The Custom tint's far end; transparent repeats glassTintColor.
    property color glassTintColor2: "transparent"
    property color accent: "#3daee9"
    // Scales the glass tint's opacity; 1 is the stock look.
    property real tintStrength: 1
    // The edge lines and rim light, and the liquid pointer light; their
    // opacity stays the material's own.
    property color edgeColor: "white"
    property color highlightColor: "white"
    // Atmosphere glows: size and strength, 1 = stock.
    property real glowSize: 1
    property real glowStrength: 1
    // Gradient: two or three colours at a CSS angle (0 = upwards, 90 = right).
    property var gradientColors: ["#2b1055", "#1c4f7a"]
    property real gradientAngle: 135
    // Outline: the edge line's width.
    property real outlineWidth: 1.5
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
    readonly property var signature: [material, grain, radius, glassTint, glassTintColor, glassTintColor2, accent, tintStrength, edgeColor, highlightColor, glowSize, glowStrength, gradientColors, gradientAngle, outlineWidth, solidColor, specular, edgeHighlight, cover1, cover2, cover3, width, height]
    onSignatureChanged: requestPaint()
    onSpecularPointChanged: {
        if (material === "liquid" && specular)
            requestPaint();
    }

    function edgeTone(alpha) {
        return Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, alpha / 255);
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

    // The glass and liquid tint (Sections.glassTint, shared with the website).
    function tint(ctx, w, h) {
        const stops = Sections.glassTint(material, glassTint, String(glassTintColor), tintStrength, String(cover1), String(cover2), glassTintColor2.a > 0 ? String(glassTintColor2) : "", String(accent));
        diagonal(ctx, w, h, stops.map(s => [s[0], Qt.rgba(s[1].r, s[1].g, s[1].b, s[1].a)]));
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
            tint(ctx, w, h);
            break;
        case "liquid":
            {
                tint(ctx, w, h);
                // Inner top glow and bottom shade (the inset box-shadows).
                const top = ctx.createLinearGradient(0, 0, 0, 12);
                top.addColorStop(0, edgeTone(0x40));
                top.addColorStop(1, edgeTone(0));
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
                    light.addColorStop(0, withAlpha(highlightColor, 0x59 / 255));
                    light.addColorStop(0.62, withAlpha(highlightColor, 0));
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
                const k = Math.max(0.1, glowSize), a = Math.max(0, glowStrength);
                ellipse(ctx, w, h, w, 0, w * 1.3 * k, h * 1.5 * k, withAlpha(cover1, Math.min(1, 0.75 * a)), 0.58);
                ellipse(ctx, w, h, 0, h, w * 1.2 * k, h * 1.3 * k, withAlpha(cover2, Math.min(1, 0.8 * a)), 0.62);
                const shade = ctx.createLinearGradient(0, 0, 0, h);
                shade.addColorStop(0, Qt.rgba(0, 0, 0, 0));
                shade.addColorStop(1, Qt.rgba(0, 0, 0, 0x4d / 255));
                ctx.fillStyle = shade;
                ctx.fillRect(0, 0, w, h);
                break;
            }
        case "gradient":
            {
                // CSS linear-gradient(angle, …): the line through the centre
                // long enough that the corners get the end colours.
                const a = gradientAngle * Math.PI / 180, dx = Math.sin(a), dy = -Math.cos(a);
                const half = (Math.abs(w * dx) + Math.abs(h * dy)) / 2;
                const fill = ctx.createLinearGradient(w / 2 - dx * half, h / 2 - dy * half, w / 2 + dx * half, h / 2 + dy * half);
                const list = gradientColors.length ? gradientColors : ["#2b1055", "#1c4f7a"];
                list.forEach((c, i) => fill.addColorStop(list.length > 1 ? i / (list.length - 1) : 0, c));
                ctx.fillStyle = fill;
                ctx.fillRect(0, 0, w, h);
                break;
            }
        }

        if (grain && material !== "outline")
            GrainDraw.draw(ctx, w, h, true);

        if (edgeHighlight && material !== "outline") {
            ctx.fillStyle = edgeTone(0x2e);
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
            const sides = [[edgeTone(0x99), [0, 0, w, 0]], [edgeTone(0x33), [0, h, w, h]], [edgeTone(0x40), [0, 0, 0, h]], [edgeTone(0x26), [w, 0, w, h]]];
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
        } else if (material === "outline") {
            const lw = Math.max(0.5, outlineWidth);
            ctx.lineWidth = lw;
            ctx.strokeStyle = edgeTone(0xbf);
            ctx.beginPath();
            ctx.roundedRect(lw / 2, lw / 2, w - lw, h - lw, Math.max(0, r - lw / 2), Math.max(0, r - lw / 2));
            ctx.stroke();
        } else {
            ctx.strokeStyle = material === "solid" ? edgeTone(0x99) : edgeTone(0x1f);
            edge();
        }
    }
}
