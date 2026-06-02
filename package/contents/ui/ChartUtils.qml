// Stateless canvas drawing helpers. Instantiate once in root and call via root.cu.*
import QtQuick

QtObject {
    id: cu

    // Set by parent before any draw call
    required property color textColor
    required property bool glowEnabled
    required property bool showGridLines

    // When true, chart glow is rendered by a GPU MultiEffect bloom pass on a
    // separate lines-only canvas (see BloomChart.qml), so the in-canvas
    // Context2D shadowBlur is suppressed — the bloom replaces it. When false,
    // glow falls back to the per-stroke shadowBlur drawn here on the CPU.
    property bool gpuBloom: false

    // Effective shadowBlur for a stroke: 0 when GPU bloom owns the glow (it is
    // drawn separately), otherwise the caller's requested value. Sections pass
    // their desired glow through this so the two paths stay in one place.
    function glowFor(requested) {
        return gpuBloom ? 0 : requested;
    }

    function drawIdleLine(ctx, gLeft, gW, h) {
        ctx.lineWidth = 1;
        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.18);
        ctx.setLineDash([4, 6]);
        ctx.beginPath();
        ctx.moveTo(gLeft, h / 2);
        ctx.lineTo(gLeft + gW, h / 2);
        ctx.stroke();
        ctx.setLineDash([]);
    }

    function drawYAxis(ctx, yLW, height, labels) {
        ctx.textAlign = "right";
        for (const l of labels) {
            if (showGridLines || l.grid) {
                ctx.beginPath();
                ctx.lineWidth = 0.5;
                ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, showGridLines ? 0.12 : 0.07);
                ctx.setLineDash([3, 5]);
                ctx.moveTo(yLW, l.y);
                ctx.lineTo(9999, l.y);
                ctx.stroke();
                ctx.setLineDash([]);
            }
            const spaceIdx = l.text.lastIndexOf(" ");
            if (spaceIdx > 0) {
                const numPart = l.text.slice(0, spaceIdx);
                const unitPart = l.text.slice(spaceIdx + 1);
                ctx.font = "bold 10px sans-serif";
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65);
                const numW = ctx.measureText(numPart).width;
                ctx.fillText(numPart, yLW - 4, l.y + 3);
                ctx.font = "8px sans-serif";
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.38);
                ctx.fillText(unitPart, yLW - 4, l.y + 11);
            } else {
                ctx.font = "bold 10px sans-serif";
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65);
                ctx.fillText(l.text, yLW - 4, l.y + 3);
            }
        }
    }

    function formatSpeed(bps) {
        if (bps >= 1073741824)
            return (bps / 1073741824).toFixed(2) + " GiB/s";
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MiB/s";
        if (bps >= 1024)
            return (bps / 1024).toFixed(1) + " KiB/s";
        return bps.toFixed(0) + " B/s";
    }

    function formatBytes(b) {
        if (b >= 1073741824)
            return (b / 1073741824).toFixed(2) + " GiB";
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + " MiB";
        if (b >= 1024)
            return (b / 1024).toFixed(1) + " KiB";
        return b.toFixed(0) + " B";
    }

    function roundedRectPath(ctx, x, y, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y);
        ctx.arcTo(x + w, y, x + w, y + r, r);
        ctx.lineTo(x + w, y + h - r);
        ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
        ctx.lineTo(x + r, y + h);
        ctx.arcTo(x, y + h, x, y + h - r, r);
        ctx.lineTo(x, y + r);
        ctx.arcTo(x, y, x + r, y, r);
        ctx.closePath();
    }

    function drawDonut(ctx, cx, cy, radius, lineW, percent, color, label, sublabel) {
        ctx.lineCap = "round";
        ctx.beginPath();
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.lineWidth = lineW;
        ctx.strokeStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.12);
        ctx.stroke();
        if (percent > 0.1) {
            const a1 = -Math.PI / 2 + Math.min(1, percent / 100) * Math.PI * 2;
            if (glowEnabled) {
                ctx.shadowBlur = 6;
                ctx.shadowColor = color;
            }
            ctx.beginPath();
            ctx.arc(cx, cy, radius, -Math.PI / 2, a1);
            ctx.lineWidth = lineW;
            ctx.strokeStyle = color;
            ctx.stroke();
            ctx.shadowBlur = 0;
        }
        if (label) {
            ctx.textAlign = "center";
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.92);
            ctx.font = "bold " + Math.round(radius * 0.44) + "px sans-serif";
            ctx.fillText(label, cx, cy + radius * 0.15);
            if (sublabel) {
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.42);
                ctx.font = Math.round(radius * 0.22) + "px sans-serif";
                ctx.fillText(sublabel, cx, cy + radius * 0.52);
            }
        }
    }

    function drawPie(ctx, cx, cy, radius, percent, color, label, sublabel) {
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08);
        ctx.fill();
        if (percent > 0.1) {
            const a1 = -Math.PI / 2 + Math.min(1, percent / 100) * Math.PI * 2;
            if (glowEnabled) {
                ctx.shadowBlur = 5;
                ctx.shadowColor = color;
            }
            ctx.beginPath();
            ctx.moveTo(cx, cy);
            ctx.arc(cx, cy, radius, -Math.PI / 2, a1);
            ctx.lineTo(cx, cy);
            ctx.fillStyle = color;
            ctx.fill();
            ctx.shadowBlur = 0;
        }
        if (label) {
            ctx.textAlign = "center";
            ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.92);
            ctx.font = "bold " + Math.round(radius * 0.44) + "px sans-serif";
            ctx.fillText(label, cx, cy + radius * 0.15);
            if (sublabel) {
                ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.42);
                ctx.font = Math.round(radius * 0.22) + "px sans-serif";
                ctx.fillText(sublabel, cx, cy + radius * 0.52);
            }
        }
    }

    function drawHorizontalBar(ctx, label, percent, valStr, color, x, y, w, h) {
        const r = h / 2;
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.08);
        roundedRectPath(ctx, x, y, w, h, r);
        ctx.fill();
        if (percent > 0) {
            const filledW = Math.max(h, (Math.min(100, percent) / 100) * w);
            if (glowEnabled) {
                ctx.shadowBlur = 4;
                ctx.shadowColor = color;
            }
            ctx.fillStyle = color;
            roundedRectPath(ctx, x, y, filledW, h, r);
            ctx.fill();
            ctx.shadowBlur = 0;
        }
        ctx.font = "8px sans-serif";
        ctx.textAlign = "left";
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65);
        ctx.fillText(label, x + 2, y - 3);
        ctx.textAlign = "right";
        ctx.font = "bold 9px sans-serif";
        ctx.fillStyle = Qt.rgba(textColor.r, textColor.g, textColor.b, 0.9);
        ctx.fillText(valStr, x + w - 2, y - 3);
    }

    function drawHistoryBars(ctx, history, color, gLeft, gW, h, maxH, maxVal, sf) {
        const n = history.length;
        if (n < 1)
            return;
        // Clamp the phase so the newest bar lands exactly on the right edge and
        // never overshoots into a visible gap between data updates.
        sf = Math.max(0, Math.min(1, sf));
        const step = gW / Math.max(1, maxH - 1);
        const barW = Math.max(2, step * 0.62);
        const tPad = h * 0.06, uH = h * 0.88;
        const r = Math.min(barW / 2, 3);
        const c = Qt.color(color);
        ctx.save();
        ctx.beginPath();
        ctx.rect(gLeft, 0, gW, h);
        ctx.clip();
        // Mirror the line path's phase model: the newest bar (i = n-1) enters
        // from just off the right edge at sf=0 and slides to the right edge as
        // sf→1, while the oldest bar slides off the left. With a non-zero sf the
        // history holds one extra (off-screen) sample so removal happens behind
        // the clip rect instead of popping. sf=0 keeps the old static layout.
        const off = sf > 0 ? 2 : 1;
        for (let i = 0; i < n; i++) {
            const x = gLeft + gW - (n - off - i + sf) * step;
            if (x + barW / 2 < gLeft || x - barW / 2 > gLeft + gW)
                continue;
            const v = Math.max(0, Math.min(1, history[i] / maxVal));
            const bh = Math.max(2, v * uH);
            const bx = x - barW / 2;
            const by = h - tPad - bh;
            // Fade out the oldest bar as it slides off the left edge, mirroring
            // how the newest bar smoothly appears on the right.
            const edgeDist = (x + barW / 2) - gLeft;
            const fadeAlpha = Math.max(0, Math.min(1, edgeDist / barW));
            const gr = ctx.createLinearGradient(0, by, 0, h - tPad);
            gr.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.88 * fadeAlpha));
            gr.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.28 * fadeAlpha));
            ctx.fillStyle = gr;
            ctx.beginPath();
            if (bh > r * 2) {
                ctx.moveTo(bx + r, by);
                ctx.arc(bx + r, by + r, r, Math.PI, 0);
                ctx.lineTo(bx + barW, h - tPad);
                ctx.lineTo(bx, h - tPad);
                ctx.closePath();
            } else {
                ctx.arc(bx + r, by + r, r, 0, Math.PI * 2);
            }
            ctx.fill();
        }
        ctx.restore();
    }

    // Flat reusable coordinate arrays — avoids allocating Array<{x,y}> objects
    // on every paint frame. Grown lazily, never shrunk.
    property var _xs: []
    property var _ys: []

    // Trace the line path into the current context using the pre-filled _xs/_ys.
    function _traceLinePath(ctx, len, smooth) {
        ctx.beginPath();
        ctx.moveTo(_xs[0], _ys[0]);
        for (let i = 1; i < len; i++) {
            if (smooth) {
                const cx = (_xs[i - 1] + _xs[i]) / 2;
                ctx.bezierCurveTo(cx, _ys[i - 1], cx, _ys[i], _xs[i], _ys[i]);
            } else {
                ctx.lineTo(_xs[i], _ys[i]);
            }
        }
    }

    // Draw a smooth bezier line + optional fill. Returns nothing.
    // smooth=true → bezier, false → straight segments
    function drawLine(ctx, history, color, iToX, valToY, height, smooth, fillAlpha, glowStr, lineWidth) {
        const len = history.length;
        if (len < 2)
            return;

        // Fill flat reusable arrays — no per-point object allocation.
        if (_xs.length < len) {
            _xs = new Array(len);
            _ys = new Array(len);
        }
        for (let i = 0; i < len; i++) {
            _xs[i] = iToX(i, len);
            _ys[i] = valToY(history[i]);
        }

        ctx.save();

        const c = Qt.color(color);
        const lw = lineWidth !== undefined ? lineWidth : 2;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (glowStr) {
            ctx.shadowBlur = Math.min(12, glowStr);
            ctx.shadowColor = color;
        }

        // Core stroke
        _traceLinePath(ctx, len, smooth);
        ctx.strokeStyle = color;
        ctx.lineWidth = lw;
        ctx.stroke();
        ctx.shadowBlur = 0;

        if (fillAlpha > 0) {
            _traceLinePath(ctx, len, smooth);
            ctx.lineTo(_xs[len - 1], height);
            ctx.lineTo(_xs[0], height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, fillAlpha));
            g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
            ctx.fillStyle = g;
            ctx.fill();
        }
        ctx.restore();
    }
}
