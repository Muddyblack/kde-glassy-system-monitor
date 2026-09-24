#version 440
// Every Glassy diagram in one fragment shader: line, history bars, filled
// area, donut, pie, and the fixed chrome (grid, threshold markers, idle line).
//
// Series and samples arrive in a small RGBA data texture written by
// DiagramData.qml, so any number of lines (a 32-thread CPU included) costs the
// same uniform block. Texture layout, 256 texels per row:
//   row 0      four header texels per series
//              0: rgb colour
//              1: r alpha, g line width * 16, b fill alpha
//              2: r flags, g ring radius, b ring width (gauges)
//              3: rg sample count (16 bit)
//   row 1…     samples, series s sample i at texel 256 + s * stride + i
//              rg value 0…65534 (65535 = gap), b colour band
// Text never goes through here; labels and legends stay QML Text.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // logical px of this item
    vec4 plot;         // plot rect in item px: x, y (top of value 1), w, h
    float mode;        // 0 line, 1 bars, 2 area, 3 donut, 4 pie, 9 chrome
    float seriesCount;
    float stride;
    float sampleStep;  // px between two samples
    float phase;       // 0 when the host slides the cached layer, 1 when static
    float smoothLines;
    float glow;        // 0 off … 1 full halo
    float pixelRatio;
    vec2 dataSize;
    vec4 trackColor;   // unfilled gauge track (text colour at low alpha)
    vec4 gapColor;     // packet loss columns
    vec4 band1;        // colour bands 1-3; band 0 is the series colour
    vec4 band2;
    vec4 band3;
    vec4 grid;         // up to four normalised grid values, < 0 = unused
    vec4 markers;      // up to four normalised threshold values, < 0 = unused
    vec4 markerColor;
    vec4 gridColor;
    float idle;        // 1 draws the dashed "no data yet" line
};
layout(binding = 1) uniform sampler2D dataTex;

const float GAP = -1.0;
const float FLAG_GLOW = 1.0;
const float FLAG_HEAD = 2.0;
const float FLAG_GAPS = 4.0;

vec4 texel(float index)
{
    vec2 cell = vec2(mod(index, dataSize.x), floor(index / dataSize.x));
    return texture(dataTex, (cell + 0.5) / dataSize);
}

float byteOf(float channel)
{
    return floor(channel * 255.0 + 0.5);
}

bool hasFlag(float flags, float flag)
{
    return mod(floor(flags / flag), 2.0) > 0.5;
}

// x: normalised value or GAP, y: colour band
vec2 sampleAt(float s, float i)
{
    vec4 t = texel(256.0 + s * stride + i);
    float q = byteOf(t.r) * 256.0 + byteOf(t.g);
    return vec2(q > 65534.5 ? GAP : q / 65534.0, byteOf(t.b));
}

float yOf(float v)
{
    return plot.y + plot.w * (1.0 - v);
}

// Bottom of the value axis; the plot rect's last component is its height.
float baseY()
{
    return plot.y + plot.w;
}

// Qt hands colour uniforms over premultiplied; the helpers below want them
// straight, with alpha applied once.
vec3 straight(vec4 c)
{
    return c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
}

vec4 bandColor(float band, vec4 base)
{
    return band > 2.5 ? vec4(straight(band3), 1.0) : band > 1.5 ? vec4(straight(band2), 1.0) : band > 0.5 ? vec4(straight(band1), 1.0) : base;
}

// Premultiplied "over".
vec4 over(vec4 dst, vec3 rgb, float a)
{
    return vec4(rgb * a, a) + dst * (1.0 - a);
}

float coverage(float d, float halfWidth)
{
    float aa = 0.75 / max(pixelRatio, 1.0);
    return clamp((halfWidth - d) / aa + 0.5, 0.0, 1.0);
}

float segDist(vec2 p, vec2 a, vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// The canvas renderer's smooth edge: a cubic with both control points at the
// mid x, which makes x = 1.5t(1-t) + t³ and y a smoothstep.
vec2 curvePoint(vec2 a, vec2 b, float t)
{
    float tx = 1.5 * t * (1.0 - t) + t * t * t;
    float ty = t * t * (3.0 - 2.0 * t);
    return vec2(a.x + (b.x - a.x) * tx, a.y + (b.y - a.y) * ty);
}

float edgeDist(vec2 p, vec2 a, vec2 b)
{
    if (smoothLines < 0.5)
        return segDist(p, a, b);
    float d = 1e9;
    vec2 prev = a;
    for (int k = 1; k <= 8; k++) {
        vec2 q = curvePoint(a, b, float(k) / 8.0);
        d = min(d, segDist(p, prev, q));
        prev = q;
    }
    return d;
}

// The edge's y at x; x(t) is monotonic, so a few Newton steps settle it.
float edgeY(vec2 a, vec2 b, float x)
{
    float s = clamp((x - a.x) / max(b.x - a.x, 1e-6), 0.0, 1.0);
    if (smoothLines < 0.5)
        return mix(a.y, b.y, s);
    float t = s;
    for (int k = 0; k < 5; k++) {
        float f = 1.5 * t * (1.0 - t) + t * t * t - s;
        float df = 1.5 - 3.0 * t + 3.0 * t * t;
        t = clamp(t - f / df, 0.0, 1.0);
    }
    return mix(a.y, b.y, t * t * (3.0 - 2.0 * t));
}

float sampleX(float n, float i)
{
    return plot.x + plot.z - (n - 2.0 - i + phase) * sampleStep;
}

vec4 lineSeries(vec2 p, float s, vec4 dst)
{
    vec4 h0 = texel(s * 4.0);
    vec4 h1 = texel(s * 4.0 + 1.0);
    vec4 h2 = texel(s * 4.0 + 2.0);
    vec4 h3 = texel(s * 4.0 + 3.0);
    float n = byteOf(h3.r) * 256.0 + byteOf(h3.g);
    if (n < 1.0)
        return dst;
    vec4 base = vec4(h0.rgb, 1.0);
    float alpha = h1.r;
    float halfWidth = max(0.5, byteOf(h1.g) / 16.0) * 0.5;
    float fill = h1.b;
    float flags = byteOf(h2.r);
    bool glows = hasFlag(flags, FLAG_GLOW) && glow > 0.0;
    float sigma = 1.6 + halfWidth * 1.4;
    float reach = halfWidth + (glows ? 3.0 * sigma : 1.0);

    float fi = (n - 2.0 + phase) - (plot.x + plot.z - p.x) / max(sampleStep, 1e-3);
    float first = max(0.0, floor(fi - reach / max(sampleStep, 1e-3)) - 1.0);
    float last = min(n - 2.0, floor(fi + reach / max(sampleStep, 1e-3)) + 1.0);

    float dist = 1e9;
    float band = 0.0;
    float fillY = -1.0;
    float fillBand = 0.0;
    vec2 prev = vec2(GAP, 0.0);
    float prevIndex = -2.0;
    for (int k = 0; k < 24; k++) {
        float j = first + float(k);
        if (j > last)
            break;
        vec2 va = prevIndex == j ? prev : sampleAt(s, j);
        vec2 vb = sampleAt(s, j + 1.0);
        prev = vb;
        prevIndex = j + 1.0;
        if (va.x < 0.0 || vb.x < 0.0)
            continue;
        vec2 a = vec2(sampleX(n, j), yOf(va.x));
        vec2 b = vec2(sampleX(n, j + 1.0), yOf(vb.x));
        float edgeBand = max(va.y, vb.y);
        if (p.x >= a.x && p.x < b.x) {
            fillY = edgeY(a, b, p.x);
            fillBand = edgeBand;
        }
        if (p.y < min(a.y, b.y) - reach || p.y > max(a.y, b.y) + reach)
            continue;
        float d = edgeDist(p, a, b);
        if (d < dist) {
            dist = d;
            band = edgeBand;
        }
    }

    if (fill > 0.0 && fillY >= 0.0 && p.y >= fillY) {
        vec4 fc = bandColor(fillBand, base);
        // Same vertical fade the canvas gradient gives: full at the top edge.
        float fade = fill * (1.0 - p.y / max(itemSize.y, 1.0));
        dst = over(dst, fc.rgb, clamp(fade, 0.0, 1.0) * alpha);
    }
    vec4 lc = bandColor(band, base);
    if (glows && dist < 1e8) {
        float outside = max(0.0, dist - halfWidth);
        float halo = 0.42 * glow * exp(-outside * outside / (2.0 * sigma * sigma));
        dst = over(dst, lc.rgb, halo * alpha);
    }
    // Hairlines (the per-core lines) are stroked at least 1.5 device px wide
    // with the same total ink. At ~1 px the layer's sub-pixel slide flips them
    // between crisp and smeared every frame, which reads as flicker.
    float px = 1.0 / max(pixelRatio, 1.0);
    float strokeHalf = max(halfWidth, 0.75 * px);
    float ink = halfWidth / strokeHalf;
    // Box-filtered coverage: a column sums to the same ink wherever the line
    // falls between pixels.
    float cover = clamp((min(dist + 0.5 * px, strokeHalf) - max(dist - 0.5 * px, -strokeHalf)) / px, 0.0, 1.0);
    dst = over(dst, lc.rgb, cover * ink * alpha);

    if (hasFlag(flags, FLAG_HEAD)) {
        vec2 head = sampleAt(s, n - 1.0);
        if (head.x >= 0.0) {
            vec2 c = vec2(sampleX(n, n - 1.0), yOf(head.x));
            vec4 hc = bandColor(head.y, base);
            float d = length(p - c);
            if (glows)
                dst = over(dst, hc.rgb, 0.18 * coverage(d, 8.0) * alpha);
            dst = over(dst, hc.rgb, coverage(d, 3.2) * alpha);
        }
    }
    return dst;
}

vec4 gapColumns(vec2 p, float s, vec4 dst)
{
    vec4 h2 = texel(s * 4.0 + 2.0);
    vec4 h3 = texel(s * 4.0 + 3.0);
    if (!hasFlag(byteOf(h2.r), FLAG_GAPS))
        return dst;
    float n = byteOf(h3.r) * 256.0 + byteOf(h3.g);
    float i = floor((n - 2.0 + phase) - (plot.x + plot.z - p.x) / max(sampleStep, 1e-3) + 0.5);
    if (i < 0.0 || i > n - 1.0 || sampleAt(s, i).x >= 0.0)
        return dst;
    float x = sampleX(n, i);
    if (abs(p.x - x) <= sampleStep * 0.5 && p.y >= plot.y && p.y <= baseY())
        dst = over(dst, straight(gapColor), 0.10);
    return over(dst, straight(gapColor), coverage(length(p - vec2(x, baseY())), 2.0));
}

vec4 barSeries(vec2 p, float s, vec4 dst)
{
    vec4 h0 = texel(s * 4.0);
    vec4 h1 = texel(s * 4.0 + 1.0);
    vec4 h3 = texel(s * 4.0 + 3.0);
    float n = byteOf(h3.r) * 256.0 + byteOf(h3.g);
    float i = floor((n - 2.0 + phase) - (plot.x + plot.z - p.x) / max(sampleStep, 1e-3) + 0.5);
    if (n < 1.0 || i < 0.0 || i > n - 1.0)
        return dst;
    vec2 v = sampleAt(s, i);
    if (v.x < 0.0)
        return dst;
    float x = sampleX(n, i);
    float w = max(2.0, sampleStep * 0.62);
    float r = min(w * 0.5, 3.0);
    float height = max(2.0, v.x * plot.w);
    float top = baseY() - height;
    // Rounded top corners only: distance to a rect whose top is inset by r.
    vec2 q = vec2(abs(p.x - x) - (w * 0.5 - r), max(top + r - p.y, p.y - baseY()));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float a = coverage(d, 0.0);
    if (a <= 0.0)
        return dst;
    float t = clamp((p.y - top) / height, 0.0, 1.0);
    vec4 c = bandColor(v.y, vec4(h0.rgb, 1.0));
    return over(dst, c.rgb, a * mix(0.88, 0.28, t) * h1.r);
}

// Angle from 12 o'clock, clockwise, 0…2π.
float clockAngle(vec2 d)
{
    float a = atan(d.x, -d.y);
    return a < 0.0 ? a + 6.28318530718 : a;
}

vec4 gauge(vec2 p, float s, vec4 dst, bool pie)
{
    vec4 h0 = texel(s * 4.0);
    vec4 h1 = texel(s * 4.0 + 1.0);
    vec4 h2 = texel(s * 4.0 + 2.0);
    vec4 h3 = texel(s * 4.0 + 3.0);
    float n = byteOf(h3.r) * 256.0 + byteOf(h3.g);
    if (n < 1.0)
        return dst;
    float v = max(0.0, sampleAt(s, n - 1.0).x);
    vec2 c = vec2(plot.x + plot.z * 0.5, itemSize.y * 0.5);
    float full = min(plot.z, itemSize.y) * 0.36;
    float radius = full * h2.g;
    float lineWidth = max(2.0, max(6.0, full * 0.22) * h2.b);
    vec2 d = p - c;
    float len = length(d);
    float ang = clockAngle(d);
    float end = min(v, 1.0) * 6.28318530718;
    vec3 rgb = h0.rgb;
    float alpha = h1.r;
    bool glows = hasFlag(byteOf(h2.r), FLAG_GLOW) && glow > 0.0;
    if (pie) {
        if (s < 0.5)
            dst = over(dst, straight(trackColor), trackColor.a * 0.66 * coverage(len - radius, 0.0));
        if (v > 0.001) {
            float inside = ang <= end ? len - radius : 1e9;
            // Distance to the two straight wedge edges.
            vec2 e1 = vec2(0.0, -radius);
            vec2 e2 = vec2(sin(end), -cos(end)) * radius;
            float edge = min(segDist(d, vec2(0.0), e1), segDist(d, vec2(0.0), e2));
            float outline = ang <= end ? abs(len - radius) : edge;
            outline = min(outline, edge);
            if (glows)
                dst = over(dst, rgb, 0.18 * coverage(outline, 4.0) * alpha);
            dst = over(dst, rgb, coverage(inside, 0.0) * alpha);
        }
        return dst;
    }
    float ring = abs(len - radius);
    dst = over(dst, straight(trackColor), trackColor.a * coverage(ring, lineWidth * 0.5));
    if (v > 0.001) {
        vec2 startCap = vec2(0.0, -radius);
        vec2 endCap = vec2(sin(end), -cos(end)) * radius;
        float arc = ang <= end ? ring : min(length(d - startCap), length(d - endCap));
        if (glows)
            dst = over(dst, rgb, 0.20 * coverage(arc, lineWidth * 0.5 + 2.5) * alpha);
        dst = over(dst, rgb, coverage(arc, lineWidth * 0.5) * alpha);
    }
    return dst;
}

vec4 chrome(vec2 p)
{
    vec4 dst = vec4(0.0);
    if (idle > 0.5) {
        float dash = mod(p.x - plot.x, 10.0) < 4.0 ? 1.0 : 0.0;
        if (p.x >= plot.x)
            dst = over(dst, straight(gridColor), 0.18 * dash * coverage(abs(p.y - itemSize.y * 0.5), 0.5));
        return dst;
    }
    if (p.x < plot.x)
        return dst;
    float gridDash = mod(p.x - plot.x, 8.0) < 3.0 ? 1.0 : 0.0;
    for (int k = 0; k < 4; k++) {
        float g = grid[k];
        if (g >= 0.0)
            dst = over(dst, straight(gridColor), gridColor.a * gridDash * coverage(abs(p.y - yOf(g)), 0.35));
    }
    float markDash = mod(p.x - plot.x, 9.0) < 3.0 ? 1.0 : 0.0;
    for (int k = 0; k < 4; k++) {
        float m = markers[k];
        if (m >= 0.0 && m <= 1.0)
            dst = over(dst, straight(markerColor), markerColor.a * markDash * coverage(abs(p.y - yOf(m)), 0.4));
    }
    return dst;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    vec4 dst = vec4(0.0);
    if (mode > 8.5) {
        dst = chrome(p);
    } else if (mode > 3.5) {
        for (int s = 0; s < 64; s++) {
            if (float(s) >= seriesCount)
                break;
            dst = gauge(p, float(s), dst, true);
        }
    } else if (mode > 2.5) {
        for (int s = 0; s < 64; s++) {
            if (float(s) >= seriesCount)
                break;
            dst = gauge(p, float(s), dst, false);
        }
    } else if (mode > 0.5 && mode < 1.5) {
        for (int s = 0; s < 64; s++) {
            if (float(s) >= seriesCount)
                break;
            dst = gapColumns(p, float(s), dst);
            dst = barSeries(p, float(s), dst);
        }
    } else {
        for (int s = 0; s < 64; s++) {
            if (float(s) >= seriesCount)
                break;
            dst = gapColumns(p, float(s), dst);
        }
        for (int s = 0; s < 64; s++) {
            if (float(s) >= seriesCount)
                break;
            dst = lineSeries(p, float(s), dst);
        }
    }
    fragColor = dst * qt_Opacity;
}
