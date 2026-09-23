.pragma library

// Batched deterministic grain; paint on the same canvas as the material to blend.
function draw(ctx, w, h, overlay) {
    ctx.save();
    if (overlay) ctx.globalCompositeOperation = "qt-overlay";
    let seed = 12345;
    const random = () => {
        seed = (Math.imul(seed, 1664525) + 1013904223) | 0;
        return (seed >>> 0) / 4294967296;
    };
    // One speck per ~3 px², split into 2 shades × 3 strengths.
    const count = Math.round(w * h / 3);
    const groups = [];
    for (let g = 0; g < 6; g++)
        groups.push([]);
    for (let i = 0; i < count; i++) {
        const v = random();
        groups[(v > 0.5 ? 3 : 0) + Math.min(2, Math.floor(Math.abs(v - 0.5) * 6))].push(Math.floor(random() * w), Math.floor(random() * h));
    }
    for (let g = 0; g < 6; g++) {
        const points = groups[g];
        ctx.beginPath();
        for (let i = 0; i < points.length; i += 2)
            ctx.rect(points[i], points[i + 1], 1, 1);
        const shade = g >= 3 ? 1 : 0;
        ctx.fillStyle = Qt.rgba(shade, shade, shade, (g % 3 + 0.5) / 3 * 0.14 * (overlay ? 1 : 0.6));
        ctx.fill();
    }
    ctx.restore();
}
