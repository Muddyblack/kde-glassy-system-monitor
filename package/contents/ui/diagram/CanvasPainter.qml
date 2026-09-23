import QtQuick

// Context2D primitives of the canvas renderer: the pre-shader look, drawn from
// the same normalised series the fragment shader reads.
QtObject {
    id: painter

    property color textColor: "white"
    // When the MultiEffect bloom layer owns the halo, strokes draw no halo of
    // their own (see CanvasChart and ChartFrame).
    property bool bloom: false
    property bool glow: true
    property var bands: []

    function tint(c, alpha) {
        const q = Qt.color(c);
        return Qt.rgba(q.r, q.g, q.b, alpha);
    }
    function bandColor(base, band) {
        return band > 0 && bands[band - 1] !== undefined ? bands[band - 1] : base;
    }

    function drawIdleLine(ctx, left, width, height) {
        ctx.lineWidth = 1;
        ctx.strokeStyle = tint(textColor, 0.18);
        ctx.setLineDash([4, 6]);
        ctx.beginPath();
        ctx.moveTo(left, height / 2);
        ctx.lineTo(left + width, height / 2);
        ctx.stroke();
        ctx.setLineDash([]);
    }

    function drawRule(ctx, left, right, y, color, dash, width) {
        ctx.beginPath();
        ctx.lineWidth = width;
        ctx.strokeStyle = color;
        ctx.setLineDash(dash);
        ctx.moveTo(left, y);
        ctx.lineTo(right, y);
        ctx.stroke();
        ctx.setLineDash([]);
    }

    // Trace one smooth or straight run; control points depend only on each
    // edge's own endpoints, so runs traced alone match the whole path.
    function trace(ctx, pts, from, to, smooth) {
        ctx.moveTo(pts[from].x, pts[from].y);
        for (let k = from + 1; k <= to; k++) {
            if (smooth) {
                const cx = (pts[k - 1].x + pts[k].x) / 2;
                ctx.bezierCurveTo(cx, pts[k - 1].y, cx, pts[k].y, pts[k].x, pts[k].y);
            } else {
                ctx.lineTo(pts[k].x, pts[k].y);
            }
        }
    }

    // Runs of edges sharing a colour band. An edge takes the higher band of
    // its two samples, so a spike is drawn fully in its alert colour.
    function runs(pts) {
        const bandAt = k => Math.max(pts[k].band, pts[k + 1].band);
        const out = [];
        let i = 0;
        while (i < pts.length - 1) {
            const band = bandAt(i);
            let j = i + 1;
            while (j < pts.length - 1 && bandAt(j) === band)
                j++;
            out.push({
                band: band,
                from: i,
                to: j
            });
            i = j;
        }
        return out;
    }

    // One series as line or area: gaps split it, bands recolour runs.
    function drawSeries(ctx, s, xAt, yAt, height, smooth, glowPass) {
        const values = s.values;
        const n = values.length;
        const segments = [];
        let current = [];
        for (let i = 0; i < n; i++) {
            const v = values[i];
            if (v === null || v === undefined || v < 0) {
                if (current.length)
                    segments.push(current);
                current = [];
                continue;
            }
            current.push({
                x: xAt(i, n),
                y: yAt(v),
                band: s.bands ? (s.bands[i] || 0) : 0
            });
        }
        if (current.length)
            segments.push(current);

        ctx.save();
        ctx.globalAlpha = s.alpha;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        for (const pts of segments) {
            if (pts.length < 2)
                continue;
            const pieces = runs(pts);
            if (glow && s.glow && !glowPass && !bloom) {
                ctx.lineWidth = s.width * 3.5;
                for (const r of pieces) {
                    ctx.strokeStyle = tint(bandColor(s.color, r.band), 0.22);
                    ctx.beginPath();
                    trace(ctx, pts, r.from, r.to, smooth);
                    ctx.stroke();
                }
            }
            ctx.lineWidth = s.width;
            for (const r of pieces) {
                ctx.strokeStyle = bandColor(s.color, r.band);
                ctx.beginPath();
                trace(ctx, pts, r.from, r.to, smooth);
                ctx.stroke();
            }
            if (s.fill > 0 && !glowPass) {
                for (const r of pieces) {
                    ctx.beginPath();
                    trace(ctx, pts, r.from, r.to, smooth);
                    ctx.lineTo(pts[r.to].x, height);
                    ctx.lineTo(pts[r.from].x, height);
                    ctx.closePath();
                    const g = ctx.createLinearGradient(0, 0, 0, height);
                    g.addColorStop(0, tint(bandColor(s.color, r.band), s.fill));
                    g.addColorStop(1, tint(bandColor(s.color, r.band), 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
            }
        }
        if (s.head && !glowPass && segments.length) {
            const last = segments[segments.length - 1];
            const p = last[last.length - 1];
            const c = bandColor(s.color, p.band);
            if (glow && s.glow && !bloom) {
                ctx.beginPath();
                ctx.arc(p.x, p.y, 8, 0, Math.PI * 2);
                ctx.fillStyle = tint(c, 0.18);
                ctx.fill();
            }
            ctx.beginPath();
            ctx.arc(p.x, p.y, 3.2, 0, Math.PI * 2);
            ctx.fillStyle = c;
            ctx.fill();
        }
        ctx.restore();
    }

    function drawGaps(ctx, s, xAt, step, top, bottom, color) {
        const n = s.values.length;
        for (let i = 0; i < n; i++) {
            const v = s.values[i];
            if (!(v === null || v === undefined || v < 0))
                continue;
            const x = xAt(i, n);
            ctx.fillStyle = tint(color, 0.10);
            ctx.fillRect(x - step / 2, top, step, bottom - top);
            ctx.beginPath();
            ctx.arc(x, bottom, 2, 0, Math.PI * 2);
            ctx.fillStyle = color;
            ctx.fill();
        }
    }

    function drawBars(ctx, s, xAt, yAt, step, bottom) {
        const n = s.values.length;
        const barW = Math.max(2, step * 0.62);
        const r = Math.min(barW / 2, 3);
        ctx.save();
        ctx.globalAlpha = s.alpha;
        for (let i = 0; i < n; i++) {
            const v = s.values[i];
            if (v === null || v === undefined || v < 0)
                continue;
            const x = xAt(i, n);
            const top = Math.min(yAt(v), bottom - 2);
            const bx = x - barW / 2;
            const c = bandColor(s.color, s.bands ? (s.bands[i] || 0) : 0);
            const g = ctx.createLinearGradient(0, top, 0, bottom);
            g.addColorStop(0, tint(c, 0.88));
            g.addColorStop(1, tint(c, 0.28));
            ctx.fillStyle = g;
            ctx.beginPath();
            if (bottom - top > r * 2) {
                ctx.moveTo(bx, bottom);
                ctx.lineTo(bx, top + r);
                ctx.arc(bx + r, top + r, r, Math.PI, 0);
                ctx.lineTo(bx + barW, bottom);
                ctx.lineTo(bx, bottom);
                ctx.closePath();
            } else {
                ctx.arc(bx + r, top + r, r, 0, Math.PI * 2);
            }
            ctx.fill();
        }
        ctx.restore();
    }

    function drawDonut(ctx, cx, cy, radius, lineWidth, fraction, color, alpha, withGlow) {
        ctx.save();
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.lineWidth = lineWidth;
        ctx.strokeStyle = tint(textColor, 0.12);
        ctx.stroke();
        ctx.globalAlpha = alpha;
        if (fraction > 0.001) {
            const end = -Math.PI / 2 + Math.min(1, fraction) * Math.PI * 2;
            if (glow && withGlow) {
                ctx.beginPath();
                ctx.arc(cx, cy, radius, -Math.PI / 2, end);
                ctx.lineWidth = lineWidth + 5;
                ctx.strokeStyle = tint(color, 0.20);
                ctx.stroke();
            }
            ctx.beginPath();
            ctx.arc(cx, cy, radius, -Math.PI / 2, end);
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = color;
            ctx.stroke();
        }
        ctx.restore();
    }

    function drawPie(ctx, cx, cy, radius, fraction, color, alpha, withGlow, track) {
        ctx.save();
        if (track) {
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.fillStyle = tint(textColor, 0.08);
            ctx.fill();
        }
        ctx.globalAlpha = alpha;
        if (fraction > 0.001) {
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.min(1, fraction) * Math.PI * 2);
            ctx.lineTo(cx, cy);
            if (glow && withGlow) {
                ctx.lineJoin = "round";
                ctx.lineWidth = 8;
                ctx.strokeStyle = tint(color, 0.18);
                ctx.stroke();
            }
            ctx.fillStyle = color;
            ctx.fill();
        }
        ctx.restore();
    }
}
