/* Glassy System Monitor — browser Looks & Studio Lab.
 *
 * Everything that defines the widget comes from the widget's own sources,
 * converted by tools/build_site.mjs into studio/shared.js: the settings
 * (Schema.js), looks (Looks.js), sections (Sections.js), chart data layout
 * (DiagramData.js), formatting (Format.js), demo readings (DemoData.js)
 * and the shell-probe parsers (Probes.js).
 * Charts are drawn by the widget's fragment shader, qsb's GLSL ES build of
 * shaders/diagram.frag, in WebGL. This file lays the widget out in HTML and
 * builds the studio UI from the schema, in the Audio Visualizer site's style.
 */
'use strict';
const { Schema, Looks, Sections, Data, Format, DemoData, Probes, Catalog, Project, SectionModels } = Glassy;
const DEFAULTS = Glassy.defaults;
// Placement exists on Hyprland only (see hyprland/GlassyShell.qml).
const HYPR = { monitor: '', hAnchor: 'right', verticalPosition: 0.08, screenMargin: 24, widgetWidth: 0, desktopLayer: true };
const BASE = { ...DEFAULTS, ...HYPR };
const $ = (s, el = document) => el.querySelector(s);
const $$ = (s, el = document) => [...el.querySelectorAll(s)];
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const TEXT = '#eff0f1';
// Card text inside HTML: the card sets --ink (Sections.textColor).
const INK = 'var(--ink)';
const inkOf = cfg => Sections.textColor(cfg, TEXT);

/* ─── state ────────────────────────────────────────────────────── */
let S = loadState();
let env = 'kde', activeTab = 'presets', query = '', form = 'widget', zoom = 'fit', backdrop = 'sea';
function loadState() {
    try { return { ...BASE, ...JSON.parse(localStorage.getItem('glassy-lab') || '{}') }; } catch (e) { return { ...BASE }; }
}
function changed(state = S) {
    const out = {};
    for (const k of Object.keys(BASE))
        if (JSON.stringify(state[k]) !== JSON.stringify(BASE[k])) out[k] = state[k];
    return out;
}
function save() { try { localStorage.setItem('glassy-lab', JSON.stringify(changed())); } catch (e) { } }

/* ─── demo monitor: the properties MonitorCore gives the sections ── */
const monitor = {
    t: 0, lastSample: performance.now(), interval: 1000,
    fill() {
        const n = Math.max(10, S.historySize || 60) + 1;
        const list = Array.from({ length: n }, (_, k) => DemoData.readings(this.t + k - n + 1));
        this.list = list;
        this.update();
    },
    step() {
        this.t++;
        const n = Math.max(10, S.historySize || 60) + 1;
        this.list = this.list.concat([DemoData.readings(this.t)]).slice(-n);
        this.lastSample = performance.now();
        this.update();
    },
    update() {
        const L = this.list, r = L[L.length - 1];
        Object.assign(this, {
            cpuHistory: L.map(x => x.cpu), cpuPercent: r.cpu,
            coreHistories: r.cores.map((_, c) => L.map(x => x.cores[c])), corePercents: r.cores,
            memHistory: L.map(x => x.mem), memPercent: r.mem, swapHistory: L.map(x => x.swap), swapPercent: r.swap,
            memUsedGiB: r.mem / 100 * 32, memTotalGiB: 32, swapUsedGiB: r.swap / 100 * 8, hasSwap: true,
            dlHistory: L.map(x => x.dl), ulHistory: L.map(x => x.ul), downloadSpeed: r.dl, uploadSpeed: r.ul,
            diskReadHistory: L.map(x => x.rd), diskWriteHistory: L.map(x => x.wr), diskReadSpeed: r.rd, diskWriteSpeed: r.wr,
            pingHistory: L.map(x => x.ping), lastPing: r.ping,
            gpuHistory: L.map(x => x.gpu), gpuPercent: r.gpu,
            customHistory: L.map(x => x.custom), customValue: r.custom,
            batteryPowerHistory: L.map(x => x.watts), batteryPowerW: -r.watts,
            // MonitorCore's names, so SectionModels reads this like the widget's core.
            histories: [L.map(x => x.ping)], activeTarget: 0,
            targetList: String(S.targets || '').split(',').map(t => t.trim()).filter(Boolean),
            sessionDlBytes: 3.4 * 1073741824, sessionUlBytes: 0.6 * 1073741824,
            hwMaxTemp: Math.max(...DemoData.SENSORS.map(c => c.maxTemp)), hwMaxTempCrit: DemoData.SENSORS[0].maxTempCrit,
            batteryPresent: true, batteryPercent: DemoData.BATTERY.percent, batteryStatus: DemoData.BATTERY.status, osUptime: DemoData.SYSTEM.uptime,
            hoveredLine: '', hoveredCore: -1
        });
        const valid = this.pingHistory.filter(v => v >= 0);
        this.avgPing = valid.reduce((a, b) => a + b, 0) / Math.max(1, valid.length);
        this.jitter = Math.sqrt(valid.reduce((s, v) => s + (v - this.avgPing) ** 2, 0) / Math.max(1, valid.length));
        this.lossPercent = (this.pingHistory.length - valid.length) / this.pingHistory.length * 100;
    },
    // Drawn scroll phase, 0 → 1 over one sample interval.
    phase() { return clamp((performance.now() - this.lastSample) / this.interval, 0, 1); }
};
monitor.fill();

/* ─── the widget's shader in WebGL ─────────────────────────────── */
const renderer = (() => {
    const gl_canvas = document.createElement('canvas');
    const gl = gl_canvas.getContext('webgl', { premultipliedAlpha: true, preserveDrawingBuffer: true, antialias: false });
    if (!gl) return null;
    let program = null, block = '_123', loc = {};
    const texture = gl.createTexture();
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);
    fetch('studio/diagram.frag').then(r => r.text()).then(src => {
        block = (src.match(/uniform\s+buf\s+(\w+)\s*;/) || [])[1] || block;
        const vs = 'attribute vec2 pos; varying vec2 qt_TexCoord0; void main() { qt_TexCoord0 = pos; gl_Position = vec4(pos.x * 2.0 - 1.0, 1.0 - pos.y * 2.0, 0.0, 1.0); }';
        const compile = (type, code) => { const s = gl.createShader(type); gl.shaderSource(s, code); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.warn(gl.getShaderInfoLog(s)); return s; };
        program = gl.createProgram();
        gl.attachShader(program, compile(gl.VERTEX_SHADER, vs));
        gl.attachShader(program, compile(gl.FRAGMENT_SHADER, src));
        gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) { console.warn(gl.getProgramInfoLog(program)); program = null; }
    });
    const u = name => loc[name] ?? (loc[name] = gl.getUniformLocation(program, block + '.' + name));
    // Qt hands colours to shaders premultiplied; do the same.
    const pm = c => { const q = Qt.color(c); return [q.r * q.a, q.g * q.a, q.b * q.a, q.a]; };
    const rgba = (c, a) => { const q = Qt.color(c); return [q.r * a, q.g * a, q.b * a, a]; };
    function pass(spec, mode, w, h, plot, extra) {
        gl.uniform1f(u('qt_Opacity'), 1);
        gl.uniform2f(u('itemSize'), w, h);
        gl.uniform4f(u('plot'), plot[0], plot[1], plot[2], plot[3]);
        gl.uniform1f(u('mode'), mode);
        gl.uniform1f(u('seriesCount'), extra.series);
        gl.uniform1f(u('stride'), extra.stride);
        gl.uniform1f(u('sampleStep'), spec.step);
        gl.uniform1f(u('phase'), spec.phase);
        gl.uniform1f(u('smoothLines'), spec.smoothLines ? 1 : 0);
        gl.uniform1f(u('glow'), spec.glow);
        gl.uniform1f(u('pixelRatio'), devicePixelRatio || 1);
        gl.uniform2f(u('dataSize'), extra.dw, extra.dh);
        gl.uniform4fv(u('trackColor'), rgba(spec.ink, 0.12));
        gl.uniform4fv(u('gapColor'), pm(spec.gapColor || '#ff4444'));
        const bands = spec.bands || [];
        gl.uniform4fv(u('band1'), pm(bands[0] || '#ffffff'));
        gl.uniform4fv(u('band2'), pm(bands[1] || '#ffffff'));
        gl.uniform4fv(u('band3'), pm(bands[2] || '#ffffff'));
        gl.uniform4fv(u('grid'), extra.grid);
        gl.uniform4fv(u('markers'), extra.markers);
        gl.uniform4fv(u('markerColor'), extra.markerColor);
        gl.uniform4fv(u('gridColor'), rgba(spec.ink, spec.strongGrid ? 0.12 : 0.07));
        gl.uniform1f(u('idle'), extra.idle);
        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }
    function normalised(list, key, max) {
        const out = [-1, -1, -1, -1];
        let n = 0;
        for (const e of list) if (n < 4 && (!key || e[key])) out[n++] = clamp(e.value / max, 0, 1);
        return out;
    }
    return {
        ready: () => !!program,
        draw(canvas, spec) {
            if (!program) return;
            const dpr = devicePixelRatio || 1, w = canvas.clientWidth, h = canvas.clientHeight;
            if (!w || !h) return;
            const W = Math.round(w * dpr), H = Math.round(h * dpr);
            if (canvas.width !== W || canvas.height !== H) { canvas.width = W; canvas.height = H; }
            if (gl_canvas.width !== W || gl_canvas.height !== H) { gl_canvas.width = W; gl_canvas.height = H; }
            const enc = Data.encode(spec.normalized, spec.maxValue, spec.style, 2);
            gl.viewport(0, 0, W, H);
            gl.clearColor(0, 0, 0, 0);
            gl.clear(gl.COLOR_BUFFER_BIT);
            gl.useProgram(program);
            gl.enable(gl.BLEND);
            gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
            gl.activeTexture(gl.TEXTURE0);
            gl.bindTexture(gl.TEXTURE_2D, texture);
            gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
            gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, enc.width, enc.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(enc.bytes));
            for (const p of [gl.TEXTURE_MIN_FILTER, gl.TEXTURE_MAG_FILTER]) gl.texParameteri(gl.TEXTURE_2D, p, gl.NEAREST);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
            gl.uniform1i(gl.getUniformLocation(program, 'dataTex'), 0);
            const attr = gl.getAttribLocation(program, 'pos');
            gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
            gl.enableVertexAttribArray(attr);
            gl.vertexAttribPointer(attr, 2, gl.FLOAT, false, 0, 0);
            const top = h * Data.TOP_PAD, used = h * Data.USED;
            const base = { series: Math.min(64, spec.normalized.length), stride: enc.stride, dw: enc.width, dh: enc.height, grid: [-1, -1, -1, -1], markers: [-1, -1, -1, -1], markerColor: [0, 0, 0, 0], idle: 0 };
            if (spec.scrolling)
                pass(spec, 9, w, h, [spec.plotLeft, top, w - spec.plotLeft, used], {
                    ...base, grid: normalised(spec.ticks, 'grid', spec.maxValue), markers: normalised(spec.markers, '', spec.maxValue),
                    markerColor: spec.markers.length ? rgba(spec.markers[0].color, 0.3) : [0, 0, 0, 0], idle: spec.empty ? 1 : 0
                });
            if (!spec.empty)
                pass(spec, Data.MODES[spec.style] ?? 0, w, h, spec.scrolling ? [spec.plotLeft, top, w - spec.plotLeft, used] : [0, top, w, used], base);
            const ctx = canvas.getContext('2d');
            ctx.clearRect(0, 0, W, H);
            ctx.drawImage(gl_canvas, 0, 0);
        }
    };
})();

/* ─── one chart: the Diagram and MetricChart logic ──────────────── */
function styleFor(cfg, id) {
    const own = Schema.parseStyles(cfg.sectionStyles)[id];
    return own || Data.styleName(cfg.chartType || 0);
}
function sizeFor(cfg, id) {
    for (const pair of Schema.fields(cfg.sectionSizes)) { const p = pair.split(':'); if (p[0] === id) return p[1]; }
    return 'm';
}
const HEIGHTS = { s: 56, m: 90, l: 150 };
function chartSpec(cfg, id, def) {
    const style = def.style || styleFor(cfg, id);
    const scrolling = Data.scrolls(style);
    const plotLeft = scrolling && cfg.showYLabels ? 38 : 0;
    const normalized = def.series.map(s => Data.normalize(s, { lineWidth: cfg.lineWidth || 2.2, fill: style === 'area' ? 0.62 : style === 'line' ? 0.35 : 0 }));
    const empty = normalized.every(s => Data.isGauge(style) || style === 'meter' ? s.value === undefined && !s.values.length : s.values.length < 2);
    return {
        style, scrolling, plotLeft, normalized, empty, maxValue: def.maxValue, ticks: def.ticks || [], markers: def.markers || [], bands: def.bands, gapColor: def.gapColor,
        smoothLines: cfg.smoothLines !== false, strongGrid: !!cfg.showGridLines,
        glow: cfg.glowLine ? Math.max(0.15, cfg.bloomStrength ?? 0.6) : 0,
        historySize: Math.max(10, cfg.historySize || 60),
        phase: scrolling && cfg.smoothScroll ? monitor.phase() : 1,
        ink: inkOf(cfg),
        step: 1
    };
}
const charts = new Map();
let chartSeq = 0;
// HTML for a chart; the canvas is drawn every frame from `make()`.
function chartHTML(cfg, id, make, opts = {}) {
    const style = opts.style || styleFor(cfg, id);
    if (style === 'text') return '';
    const height = opts.height || HEIGHTS[sizeFor(cfg, id)];
    const key = 'c' + (++chartSeq);
    charts.set(key, { cfg, id, make, opts });
    const def = make(style), spec = chartSpec(cfg, id, { ...def, style });
    if (style === 'meter') {
        const cols = spec.normalized.length > 8 ? 4 : spec.normalized.length > 4 ? 2 : 1;
        return `<div class="gw-meters" style="grid-template-columns:repeat(${cols},1fr);min-height:${height}px">${spec.normalized.map(s => {
            const f = clamp(Data.gaugeValue(s) / spec.maxValue, 0, 1);
            return `<div style="opacity:${s.alpha}"><div class="gw-mcap"><span>${esc(s.label)}</span><b>${esc(s.text)}</b></div><div class="gw-mtrack"><i style="width:${Math.max(6, f * 100)}%;background:${s.color};box-shadow:${spec.glow ? `0 0 0 3px ${alpha(s.color, 0.18)}` : 'none'}"></i></div></div>`;
        }).join('')}</div>`;
    }
    let labels = '';
    if (spec.scrolling && opts.axis !== false && cfg.showYLabels && !spec.empty) {
        let lastY = -1e9;
        const sorted = spec.ticks.slice().sort((a, b) => b.value - a.value), shown = [];
        sorted.forEach((t, i) => {
            const y = Data.yOf(t.value, spec.maxValue, height), end = i === 0 || i === sorted.length - 1;
            if (end && i > 0 && y - lastY < 20 && shown.length > 1) shown.pop();
            if (end || y - lastY >= 20) { shown.push([t, y]); lastY = y; }
        });
        labels = shown.map(([t, y]) => { const sp = t.text.lastIndexOf(' '); return `<span class="gw-tick" style="top:${y - 9}px;width:${spec.plotLeft - 4}px"><b>${esc(sp > 0 ? t.text.slice(0, sp) : t.text)}</b>${sp > 0 ? `<small>${esc(t.text.slice(sp + 1))}</small>` : ''}</span>`; }).join('');
    }
    const center = Data.isGauge(style) && def.centerText ? `<div class="gw-center" style="--r:${Math.min(320, height) * 0.36}px"><b>${esc(def.centerText)}</b>${def.centerSubText ? `<small>${esc(def.centerSubText)}</small>` : ''}</div>` : '';
    return `<div class="gw-chart" style="height:${height}px"><canvas data-chart="${key}"></canvas>${labels}${center}</div>`;
}
function alpha(c, a) { const q = Qt.color(c); return `rgba(${q.r * 255 | 0},${q.g * 255 | 0},${q.b * 255 | 0},${a})`; }
function drawCharts(root = document) {
    for (const canvas of $$('canvas[data-chart]', root)) {
        const entry = charts.get(canvas.dataset.chart);
        if (!entry) continue;
        const r = canvas.getBoundingClientRect();
        if (r.bottom < 0 || r.top > innerHeight || !r.width) continue;
        const style = entry.opts.style || styleFor(entry.cfg, entry.id);
        const spec = chartSpec(entry.cfg, entry.id, { ...entry.make(style), style });
        if (entry.opts.axis === false) spec.plotLeft = 0;
        spec.step = (canvas.clientWidth - spec.plotLeft) / Math.max(1, spec.historySize - 1);
        renderer.draw(canvas, spec);
    }
}

/* ─── the widget, section by section (MonitorView in HTML) ─────── */
const title = (cfg, id) => Sections.title(id, cfg);
const head = (t, reading, color, extra = '') => `<div class="gw-head"><b>${esc(t)}</b><span class="gw-extra">${extra}</span><em style="color:${color || INK}">${esc(reading)}</em></div>`;
const legend = (cfg, plotLeft, entries) => cfg.showLegend ? `<div class="gw-legend" style="padding-left:${plotLeft}px">${entries.map(e => `<span><i style="background:${e.color}"></i>${esc(e.label)}<b style="color:${e.color}">${esc(e.value)}</b></span>`).join('')}</div>` : '';
const pl = (cfg, id) => Data.scrolls(styleFor(cfg, id)) && cfg.showYLabels ? 38 : 0;
const colorOf = (cfg, key, fallback) => cfg[key] || fallback;
const m = monitor;

// A chart section straight from SectionModels.js, plus what only that
// section shows below its chart.
function modelSection(cfg, id, below = '', extra = '') {
    const model = SectionModels[id](m, cfg);
    const plotLeft = pl(cfg, id);
    return head(model.title, model.reading, model.readingColor || INK, extra) +
        chartHTML(cfg, id, style => ({ ...model, series: model.series(style) })) + below(model, plotLeft) +
        legend(cfg, plotLeft, model.legend);
}
// BarListSection in HTML: storage and processes. The rows go through the
// widget's parsers and ranking with this card's settings, as DemoFeeder does.
function barLists(cfg) {
    return {
        ...m,
        storage: Probes.parseStorage(DemoData.DF, cfg.storageMounts),
        processes: Probes.topProcesses(DemoData.procSnapshot(m.t - 1), DemoData.procSnapshot(m.t), cfg.processCount || 5, cfg.processSort || 'cpu', cfg.processGroup !== false)
    };
}
function barList(cfg, id) {
    const model = SectionModels[id](barLists(cfg), cfg);
    const rows = model.rows.length ? model.rows.map(r => `<div class="gw-brow"><span>${esc(r.label)}</span><span class="gw-mtrack"><i style="width:${Math.min(1, r.ratio) * 100}%;background:${r.color}"></i></span><small>${esc(r.detail)}</small><b style="color:${r.color}">${esc(r.value)}</b></div>`).join('') : `<div class="gw-brow gw-dim">${esc(model.empty)}</div>`;
    return head(model.title, model.reading, model.readingColor || INK) + `<div class="gw-bars">${rows}</div>`;
}
const SECTION = {
    cpu: cfg => modelSection(cfg, 'cpu', model => model.cores
        ? `<div class="gw-cores">${m.corePercents.map((p, i) => { const c = model.coreColors[i % model.coreColors.length]; return `<span><i style="background:${c}"></i>Core ${i + 1}<b style="color:${c}">${p.toFixed(0)}%</b></span>`; }).join('')}</div>` : ''),
    memory: cfg => modelSection(cfg, 'memory', () => ''),
    network: cfg => modelSection(cfg, 'network', (model, left) => `<div class="gw-totals" style="padding-left:${left}px">${model.totals.map(t => `<span style="color:${t.color}">${esc(t.text)}</span>`).join('')}</div>`, '<span class="gw-dim">wlan0 ▾</span><span class="gw-dim">○ connections</span>'),
    ping: cfg => modelSection(cfg, 'ping', (model, left) => cfg.showStats ? `<div class="gw-stats" style="padding-left:${left}px">${model.stats.map(st => `<span><small>${st.label}</small><b style="color:${st.color || INK}">${esc(st.value)}</b></span>`).join('')}</div>` : '',
        m.targetList.map((h, i) => `<span class="gw-chip${i === 0 ? ' on' : ''}" style="--c:${colorOf(cfg, 'pingColor', '#39ff14')}">${esc(h)}</span>`).join('')),
    disk: cfg => modelSection(cfg, 'disk', () => '', '<span class="gw-dim">nvme0n1</span>'),
    gpu: cfg => { const c = colorOf(cfg, 'gpuColor', '#ff6e40'); return modelSection(cfg, 'gpu', (model, left) => cfg.gpuShowEngines ? `<div class="gw-engines" style="padding-left:${left}px"><div class="gw-vram"><b>VRAM</b><span class="gw-mtrack"><i style="width:32%;background:${c}"></i></span><span>5.20 GiB / 16.00 GiB</span></div><div class="gw-eng"><span><i style="background:${c}"></i>Compute <b style="color:${c}">${m.gpuPercent.toFixed(0)}%</b></span><span><i style="background:${c}"></i>Decode <b style="color:${c}">4%</b></span><span><i style="background:${alpha(c, 0.35)}"></i>Encode 0%</span></div></div>` : '', `<span class="gw-badge">AMD</span><span class="gw-dim">${Math.round(1200 + m.gpuPercent * 12)} MHz</span>`); },
    custom: cfg => modelSection(cfg, 'custom', () => ''),
    sensors(cfg) {
        const col = (v, crit) => { const r = Math.max(0, (v - 30) / Math.max(20, (crit || cfg.hwTempCrit || 90) - 30)); return r >= 0.85 ? '#ff4444' : r >= 0.72 ? '#ff8844' : r >= 0.55 ? '#ffaa22' : '#44ddaa'; };
        return head(title(cfg, 'sensors'), '62°C', INK) + `<div class="gw-sensors">${DemoData.SENSORS.map(g => `<div class="gw-chipname"><b>${esc(g.chipDisplay)}</b><i></i><small style="color:${col(g.maxTemp, g.maxTempCrit)}">max ${g.maxTemp}°C</small></div>${g.sensors.map(s => s.type === 'fan'
            ? `<div class="gw-srow"><span>${esc(s.label)}</span><span class="gw-mtrack"><i style="width:100%;background:#22aaff55"></i></span><b style="color:#22aaff">${s.value} RPM</b></div>`
            : `<div class="gw-srow"><span>${esc(s.label)}</span><span class="gw-mtrack"><i style="width:${s.value / s.crit * 100}%;background:${col(s.value, s.crit)}"></i></span><b style="color:${col(s.value, s.crit)}">${s.value.toFixed(1)}°C</b></div>`).join('')}`).join('')}</div>`;
    },
    power(cfg) {
        const b = DemoData.BATTERY;
        return head(title(cfg, 'power'), b.percent + '%', '#44dd88') +
            `<div class="gw-battery"><span class="gw-bar"><i style="width:${b.percent}%"></i><b>${b.percent}%</b></span><em style="color:#ffaa22">${m.batteryPowerW.toFixed(1)}W</em><span class="gw-dim">${b.status}</span></div>` +
            chartHTML(cfg, 'power', () => SectionModels.power(m), { style: 'area', axis: false, height: 38 }) +
            `<div class="gw-pchips">${[['Health', b.health + '%', '#44dd88'], ['Temp', b.temp + '°C', '#44ddaa'], ['Cycles', b.cycles, INK], ['Remaining', '4h 36m', INK]].map(([k, v, c]) => `<span><small>${k}</small><b style="color:${c}">${v}</b></span>`).join('')}</div>` +
            `<div class="gw-srow"><span>CPU pressure</span><span class="gw-mtrack"><i style="width:${m.cpuPercent / 2.4}%;background:#ff6644"></i></span><b>${(m.cpuPercent / 12).toFixed(2)}%</b></div><div class="gw-srow"><span>MEM pressure</span><span class="gw-mtrack"><i style="width:2%;background:#aa66ff"></i></span><b>0.40%</b></div>`;
    },
    storage: cfg => barList(cfg, 'storage'),
    processes: cfg => barList(cfg, 'processes'),
    system(cfg) {
        const s = DemoData.SYSTEM;
        return head(title(cfg, 'system'), s.uptime, INK) + `<div class="gw-kv">${[['OS', s.distro], ['Kernel', s.kernel], ['Host', s.hostname], ['Uptime', s.uptime]].map(([k, v]) => `<span>${k}</span><b>${esc(v)}</b>`).join('')}</div>`;
    }
};

// Card size the widget asks for, as MonitorView.preferredWidth does.
function cardWidth(cfg) {
    const ids = Sections.parse(cfg.sections, cfg.activeSection), cols = clamp(cfg.layoutColumns || 1, 1, 3);
    if (env === 'hypr' && cfg.widgetWidth > 0) return cfg.widgetWidth;
    return cols > 1 ? cols * 290 : ids.length === 1 && ids[0] === 'memory' ? 240 : 320;
}
// The card's material, as GlassCard draws it. Glass and liquid reuse the
// Audio Visualizer's surface classes from style.css.
function surfaceHTML(cfg, ids) {
    const material = Schema.MATERIALS.some(([v]) => v === cfg.surfaceStyle) ? cfg.surfaceStyle || 'tint' : 'tint';
    const bg = Qt.color(cfg.bgColor || '#800d0f1a');
    const [p1, p2] = Sections.colors(ids, cfg, '#4aa8ff').map(c => Qt.color(c));
    const hex = c => `rgb(${c.r * 255 | 0},${c.g * 255 | 0},${c.b * 255 | 0})`;
    const p3 = `rgb(${(p1.r * 0.2 + p2.r * 0.1) * 255 | 0},${(p1.g * 0.2 + p2.g * 0.1) * 255 | 0},${(p1.b * 0.2 + p2.b * 0.1) * 255 | 0})`;
    const liquid = material === 'liquid', glass = liquid || material === 'glass';
    const cls = material === 'tint' ? 's-color' + (cfg.frostedGlass ? ' frost' : '') : `s-${material}` + (material === 'solid' && bg.a >= 1 ? ' flat' : '') + (glass ? ` t-${cfg.glassTint || 'clear'}${liquid && cfg.glassRefraction > 0.02 ? ' refract' : ''}` : '');
    const edge = (material !== 'tint' && !(material === 'solid' && bg.a >= 1)) || cfg.cardBorder ? `<i class="edge${cfg.cardBorder ? ' hl' : ''}"></i>` : '';
    const vars = `opacity:${cfg.cardOpacity ?? 1};--bgc:rgba(${bg.r * 255 | 0},${bg.g * 255 | 0},${bg.b * 255 | 0},${bg.a});--frost:${(cfg.frostStrength ?? 0.55) * 24}px;--glass-blur:${((cfg.glassBlur ?? 0.85) * 24).toFixed(1)}px;--glass-color:${cfg.glassTintColor || '#3daee9'};--p1:${hex(p1)};--p2:${hex(p2)};--p3:${p3}`;
    return `<div class="surf ${cls}" style="${vars}">${liquid && cfg.glassSpecular !== false ? '<i class="spec"></i>' : ''}${edge}${cfg.grain ? '<i class="grain"></i>' : ''}</div>`;
}
function widgetHTML(cfg) {
    const ids = Sections.parse(cfg.sections, cfg.activeSection), cols = clamp(cfg.layoutColumns || 1, 1, 3);
    const place = Sections.placement(ids, cols, Schema.fields(cfg.sectionSpans));
    const material = cfg.surfaceStyle || 'tint';
    // Materials use one radius, the tint all four corners.
    const r = material === 'tint' ? [cfg.bgRadiusTL, cfg.bgRadiusTR, cfg.bgRadiusBR, cfg.bgRadiusBL].map(v => (v ?? 12) + 'px').join(' ') : Math.max(cfg.bgRadiusTL ?? 12, cfg.bgRadiusTR ?? 12, cfg.bgRadiusBR ?? 12, cfg.bgRadiusBL ?? 12) + 'px';
    const pad = ({ compact: 6, roomy: 14 })[cfg.density] || 10;
    const shadow = cfg.cardShadow === 'soft' || cfg.cardShadow === 'lifted' ? ' sh-' + cfg.cardShadow : '';
    const specular = material === 'liquid' && cfg.glassSpecular !== false ? ' specular' : '';
    return `<div class="gw${shadow}${specular}" style="width:${cardWidth(cfg)}px;border-radius:${r};--ink:${inkOf(cfg)};--font:${cfg.fontFamily === 'monospace' ? 'ui-monospace,monospace' : 'Noto Sans,Inter,system-ui,sans-serif'};padding:${pad}px;gap:${pad}px 16px;grid-template-columns:repeat(${cols},1fr)">${surfaceHTML(cfg, ids)}${ids.map((id, i) => `<section class="gw-sec" style="grid-row:${place[i].row + 1};grid-column:${place[i].column + 1} / span ${place[i].span}">${SECTION[id](cfg)}</section>`).join('')}</div>`;
}
// The panel pill from SectionModels.pill, like CompactRepresentation, and
// the card it shows on hover (pinned by a click) under the panel.
let pillHover = false, pillPinned = false;
function pillChart(p, style, tint) {
    const W = 34, H = 16;
    const draw = (values, c, alpha, main) => {
        const col = tint(c);
        if (style === 'bars') {
            const n = Math.floor(W / 3), list = values.slice(-n), w = W / n;
            return list.map((v, i) => { const h = Math.max(1, Math.min(1, v / p.max) * H); return `<rect x="${(W - (list.length - i) * w).toFixed(1)}" y="${(H - h).toFixed(1)}" width="${(w - 1).toFixed(1)}" height="${h.toFixed(1)}" fill="${col}" opacity="${alpha}"/>`; }).join('');
        }
        const list = values.slice(-Math.floor(W / 2)), step = W / Math.max(1, list.length - 1);
        const pts = list.map((v, i) => `${(i * step).toFixed(1)},${(H - Math.min(1, Math.max(0, v / p.max)) * (H - 1)).toFixed(1)}`).join(' ');
        return (main ? `<polygon points="0,${H} ${pts} ${W},${H}" fill="${col}" opacity=".22"/>` : '') + `<polyline points="${pts}" fill="none" stroke="${col}" stroke-width="${main ? 1.4 : 1}" stroke-linejoin="round" opacity="${alpha}"/>`;
    };
    return `<svg class="gw-pspark" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">${p.history2.length > 1 ? draw(p.history2, p.lines[1] ? p.lines[1].color : p.color, 0.55, false) : ''}${draw(p.history, p.color, 1, true)}</svg>`;
}
function pillHTML(cfg) {
    const style = cfg.panelStyle || 'values', lists = barLists(cfg);
    const tint = c => cfg.panelPlainText || !c ? TEXT : c;
    const readings = Sections.panelIds(cfg).map(id => {
        const p = SectionModels.pill(id, lists, cfg), two = p.lines.length > 1;
        const lines = p.lines.map(l => `<b style="color:${tint(l.color)}">${l.mark ? `<i>${esc(l.mark)}</i>` : ''}${esc(l.text)}</b>`).join('');
        const meter = style === 'values' && !two && p.ratio >= 0 ? `<span class="gw-pmeter" style="background:${tint(p.color)}33"><i style="width:${Math.min(1, p.ratio) * 100}%;background:${tint(p.color)}"></i></span>` : '';
        return `<span class="gw-pr"><span class="gw-pv${two ? ' two' : ''}">${two ? '' : `<small>${esc(p.label)}</small>`}${lines}${meter}</span>${style !== 'values' && p.history.length > 1 ? pillChart(p, style, tint) : ''}</span>`;
    }).join('');
    const card = cfg.panelHoverCard !== false && (pillHover || pillPinned) ? `<div class="gw-hover">${widgetHTML(cfg)}</div>` : '';
    return `<div class="gw-pwrap" style="--font:${cfg.fontFamily === 'monospace' ? 'ui-monospace,monospace' : '"Noto Sans"'}"><div class="gw-panel ${env}"><span class="gw-slot"></span><span class="gw-slot"></span><div class="gw-pill${cfg.panelShowBg ? ' bg' : ''}" title="Hover for the card, click to pin it">${readings}</div><span class="gw-slot"></span></div>${card}</div>`;
}
$('#mainWidget').addEventListener('pointerover', e => { const on = !!e.target.closest('.gw-pill, .gw-hover'); if (on !== pillHover) { pillHover = on; renderMain(); } });
$('#mainWidget').addEventListener('pointerleave', () => { if (pillHover) { pillHover = false; renderMain(); } });
$('#mainWidget').addEventListener('click', e => { if (e.target.closest('.gw-pill')) { pillPinned = !pillPinned; renderMain(); } });

/* ─── mounting and fitting ─────────────────────────────────────── */
function mount(el, html) { el.innerHTML = html; drawCharts(el); }
function fit(box, inner, max = 1) {
    const W = inner.offsetWidth, H = inner.offsetHeight;
    if (!W || !H) return 1;
    return Math.max(0.05, Math.min(max, (box.clientWidth - 32) / W, (box.clientHeight - 28) / H));
}

/* ─── Looks page ───────────────────────────────────────────────── */
function lookState(look) { return { ...Looks.apply(S, BASE, look.s) }; }
function renderPresets() {
    const saved = savedLooks();
    const all = Looks.BUILT_IN.concat(saved.map((l, i) => ({ id: 'mine' + i, name: l.name, note: 'Saved in this browser', s: l.settings })));
    $('#presets').innerHTML = all.map((look, i) => `<article class="pcard${Looks.matches(S, BASE, look.s) ? ' active' : ''}" data-look="${i}">
      <div class="pv" title="Use ${esc(look.name)}"><span class="bd bd-${['sea', 'dusk', 'breeze', 'neon', 'olive', 'sea', 'dusk'][i % 7]}"></span><div class="fit"><div class="fi"></div></div></div>
      <div class="meta"><div><h3>${esc(look.name)}</h3><p>${esc(look.note)}</p></div><button class="use">Use</button></div></article>`).join('');
    $$('.pcard').forEach(card => { card._look = all[card.dataset.look]; mount($('.fi', card), widgetHTML(lookState(card._look))); });
    fitCards();
}
// Scale every mounted widget (hero, preset cards, studio look tiles) to fit
// its frame. Hidden pages measure zero, so this runs again when one is shown.
const FIT = { '.hero-card': [1.2, 40], '.pv': [0.9, 32], '.ppv': [0.5, 12] };
function fitCards() {
    for (const fi of $$('.fit > .fi')) {
        const gw = fi.firstElementChild, box = fi.closest('.hero-card, .pv, .ppv');
        if (!gw || !box || !box.clientWidth) continue;
        const [max, pad] = FIT[Object.keys(FIT).find(sel => box.matches(sel))];
        const k = Math.max(0.05, Math.min(max, (box.clientWidth - pad) / gw.offsetWidth, (box.clientHeight - pad) / gw.offsetHeight));
        fi.parentElement.style.cssText = `width:${gw.offsetWidth * k}px;height:${gw.offsetHeight * k}px`;
        fi.style.cssText = `width:${gw.offsetWidth}px;transform:scale(${k});transform-origin:0 0`;
    }
}
$('#presets').addEventListener('click', e => {
    const card = e.target.closest('.pcard'); if (!card || !(e.target.closest('.use') || e.target.closest('.pv'))) return;
    applyLook(card._look); showPage('studio');
});
function applyLook(look) { S = Looks.apply(S, BASE, look.s); onChange(); toast(`Applied “${look.name}”`); }

/* ─── Studio: preview stage ────────────────────────────────────── */
function renderMain() {
    mount($('#mainWidget'), form === 'panel' ? pillHTML(S) : widgetHTML(S));
    fitStage();
}
function fitStage() {
    const stage = $('#stage'), inner = $('#mainWidget').firstElementChild;
    if (!inner) return;
    const top = 60, bottom = 50;
    const k = zoom === 'fit' ? Math.min(1, (stage.clientWidth - 40) / inner.offsetWidth, (stage.clientHeight - top - bottom) / inner.offsetHeight) : Number(zoom);
    $('#mainWidget').style.transform = `scale(${k})`;
    const sc = $('#scaler');
    sc.style.left = Math.max(20, (stage.clientWidth - inner.offsetWidth * k) / 2) + 'px';
    // A panel sits near the top, leaving room for the card it shows on hover.
    sc.style.top = (form === 'panel' ? top + 24 : Math.max(top, top + (stage.clientHeight - top - bottom - inner.offsetHeight * k) / 2)) + 'px';
    $('#sizeInfo').textContent = `demo · ${inner.offsetWidth} × ${inner.offsetHeight} px · ${k.toFixed(2)}×`;
}
$('#bdPicker').insertAdjacentHTML('beforeend', Catalog.StudioCatalog.wallpapers.map(w => `<button class="bdsw" data-bd="${w.id}" title="${esc(w.label)}" aria-label="${esc(w.label)} wallpaper" aria-pressed="${w.id === backdrop}"><span class="bd bd-${w.id}" aria-hidden="true"></span></button>`).join(''));
$('#bdPicker').addEventListener('click', e => { const b = e.target.closest('[data-bd]'); if (!b) return; backdrop = b.dataset.bd; $('#stageBd').className = 'bd bd-' + backdrop; $$('[data-bd]').forEach(x => x.setAttribute('aria-pressed', x === b)); });
$('#formPicker').addEventListener('click', e => { const b = e.target.closest('[data-form]'); if (!b) return; form = b.dataset.form; $$('[data-form]').forEach(x => x.setAttribute('aria-pressed', x === b)); renderMain(); });
$('#zoomPicker').addEventListener('click', e => { const b = e.target.closest('[data-z]'); if (!b) return; zoom = b.dataset.z; $$('[data-z]').forEach(x => x.setAttribute('aria-pressed', x === b)); fitStage(); });
$('#envPicker').addEventListener('click', e => { const b = e.target.closest('[data-env]'); if (!b) return; env = b.dataset.env; $$('[data-env]').forEach(x => x.setAttribute('aria-pressed', x === b)); syncSettings(); renderConfig(); renderMain(); });

/* ─── Studio: settings built from Schema.SECTIONS ──────────────── */
const SWATCHES = Schema.SWATCHES;
const DEMO_OPTIONS = { ifaces: [['auto', 'Automatic'], ['wlan0', 'wlan0'], ['enp5s0', 'enp5s0']], disks: [['auto', 'Automatic'], ['nvme0n1', 'nvme0n1'], ['sda', 'sda']], gpus: [['auto', 'Automatic'], ['0000:03:00.0', 'card1 · 0000:03:00.0']], screens: [['', 'First screen'], ['all', 'Every screen'], ['DP-1', 'DP-1'], ['HDMI-A-1', 'HDMI-A-1']] };
let rows = [];
function tilePreview(style, value) {
    if (style === 'material') return `<span class="tpv-mat"><i class="sp sp-${value === 'tint' ? 'color' : esc(value)}"></i></span>`;
    return style === 'text' ? '<b class="tpv-text">42%</b>' : `<canvas data-tile="${style}"></canvas>`;
}
function buildRow(r) {
    const el = document.createElement('div');
    el.className = 'row' + (r.full ? ' full' : '');
    const get = s => Schema.rowValue(r, s);
    const set = v => Schema.rowPatch(r, v, S);
    const isHypr = r.k && HYPR.hasOwnProperty(r.k);
    const headHTML = r.label ? `<div class="rh"><div class="rt">${esc(r.label)}${isHypr ? '<span class="new hypr">Hyprland</span>' : ''}</div>${r.desc ? `<div class="rd">${esc(r.desc)}</div>` : ''}</div>` : '';
    let sync = () => { };
    if (r.type === 'switch') {
        el.innerHTML = headHTML + `<div class="rc"><input type="checkbox" class="switch" aria-label="${esc(r.label)}"></div>`;
        const inp = $('input', el);
        inp.onchange = () => update(set(inp.checked));
        sync = s => { inp.checked = !!get(s); };
    } else if (r.type === 'range') {
        el.innerHTML = headHTML + `<div class="rc range"><input type="range" min="${r.min}" max="${r.max}" step="${r.step}" aria-label="${esc(r.label)}"><output></output></div>`;
        const inp = $('input', el), out = $('output', el);
        inp.oninput = () => update(set(Number(inp.value)));
        sync = s => { const v = Number(get(s)); if (document.activeElement !== inp) inp.value = v; out.textContent = Schema.format(r.fmt, v); inp.style.setProperty('--f', (v - r.min) / (r.max - r.min) * 100 + '%'); };
    } else if (r.type === 'seg') {
        el.innerHTML = headHTML + `<div class="rc"><div class="seg" role="group" aria-label="${esc(r.label)}">${r.opts.map(([, l], i) => `<button data-i="${i}">${esc(l)}</button>`).join('')}</div></div>`;
        const btns = $$('button', el);
        btns.forEach(b => b.onclick = () => update(set(r.opts[b.dataset.i][0])));
        sync = s => btns.forEach(b => b.setAttribute('aria-pressed', String(r.opts[b.dataset.i][0]) === String(get(s))));
    } else if (r.type === 'chips') {
        el.innerHTML = headHTML + `<div class="chips">${r.opts.map(([v, l]) => `<button data-v="${v}">${esc(l)}</button>`).join('')}</div>`;
        const btns = $$('button', el);
        btns.forEach(b => b.onclick = () => { const cur = Schema.fields(get(S)), v = b.dataset.v; update(set(cur.includes(v) ? cur.filter(x => x !== v) : r.single ? [v] : cur.concat([v]))); });
        sync = s => { const cur = Schema.fields(get(s)); btns.forEach(b => b.setAttribute('aria-pressed', cur.includes(b.dataset.v))); };
    } else if (r.type === 'select') {
        const options = typeof r.opts === 'string' ? DEMO_OPTIONS[r.opts] : r.opts;
        el.innerHTML = headHTML + `<div class="rc"><select class="sel" aria-label="${esc(r.label)}">${options.map(([v, l]) => `<option value="${esc(v)}">${esc(l)}</option>`).join('')}</select></div>`;
        const sel = $('select', el);
        sel.onchange = () => update(set(sel.value));
        sync = s => { sel.value = get(s); };
    } else if (r.type === 'color') {
        const sws = r.swatches || SWATCHES;
        el.innerHTML = headHTML + `<div class="rc swatches">${sws.map(c => { const q = Qt.color(c); return `<button class="sw" data-c="${c}" style="background:rgba(${q.r * 255 | 0},${q.g * 255 | 0},${q.b * 255 | 0},${q.a})" aria-label="${c}"></button>`; }).join('')}<label class="swc" title="Pick any colour"><input type="color" aria-label="${esc(r.label)}"></label></div>`;
        const btns = $$('.sw', el), inp = $('input', el);
        btns.forEach(b => b.onclick = () => update(set(b.dataset.c)));
        inp.oninput = () => update(set(inp.value));
        sync = s => { const v = String(get(s) || '').toLowerCase(); btns.forEach(b => b.setAttribute('aria-pressed', b.dataset.c.toLowerCase() === v)); if (document.activeElement !== inp && /^#[0-9a-f]{6}$/.test(v)) inp.value = v; };
    } else if (r.type === 'tiles') {
        el.innerHTML = headHTML + `<div class="tiles" style="--tw:${r.tw || 104}px">${r.opts.map((o, i) => `<button class="tile" data-i="${i}"><span class="tpv">${tilePreview(o.pv, o.v)}</span><span class="tl">${esc(o.label)}</span></button>`).join('')}</div>`;
        const btns = $$('.tile', el);
        btns.forEach(b => b.onclick = () => update(set(r.opts[b.dataset.i].v)));
        sync = s => btns.forEach(b => b.setAttribute('aria-pressed', String(r.opts[b.dataset.i].v) === String(get(s))));
    } else if (r.type === 'text' || r.type === 'number') {
        el.innerHTML = headHTML + `<div class="rc"><input class="sel txt" ${r.type === 'number' ? 'type="number"' : 'type="text"'} placeholder="${esc(r.placeholder || '')}" aria-label="${esc(r.label)}"></div>`;
        const inp = $('input', el);
        inp.onchange = () => update(set(r.type === 'number' ? Number(inp.value) : inp.value.trim()));
        sync = s => { if (document.activeElement !== inp) inp.value = get(s) ?? ''; };
    } else if (r.type === 'note') {
        el.innerHTML = '<div class="nt"></div>';
        sync = () => { $('.nt', el).innerHTML = `<div class="note"><i>◇</i><div><b>${env === 'kde' ? 'On Plasma' : 'On Hyprland'}</b> — ${esc(Schema.NOTES[r.note][env] || '')}</div></div>`; };
    } else if (r.type === 'sections') {
        sync = renderSectionList(el, headHTML);
    } else if (r.type === 'looks') {
        sync = renderLookGallery(el);
    } else if (r.type === 'projectInfo') {
        sync = renderProjectInfo(el);
    }
    return { el, r, sync };
}

// Layout › sections: switch, drag grip, size, style, full width.
function renderSectionList(el, headHTML) {
    el.innerHTML = headHTML + '<div class="gs-list"></div>';
    const list = $('.gs-list', el);
    let dragging = null;
    const styles = [['', 'Default']].concat(Schema.CHARTS.map(c => [c.style, c.label]));
    const chartSections = ['cpu', 'memory', 'network', 'ping', 'disk', 'gpu', 'custom'];
    function commit(ids, patch = {}) { update({ sections: ids.join(','), ...patch }); }
    list.addEventListener('dragstart', e => { const row = e.target.closest('[data-id]'); dragging = row && row.dataset.id; e.dataTransfer.effectAllowed = 'move'; });
    list.addEventListener('dragover', e => { if (dragging) e.preventDefault(); });
    list.addEventListener('drop', e => {
        e.preventDefault();
        const target = e.target.closest('[data-id]'), ids = Sections.parse(S.sections, S.activeSection);
        if (!dragging || !target || ids.indexOf(target.dataset.id) === -1 || target.dataset.id === dragging) return;
        const next = ids.filter(x => x !== dragging);
        next.splice(ids.indexOf(target.dataset.id), 0, dragging);
        commit(next); dragging = null;
    });
    list.addEventListener('click', e => {
        const row = e.target.closest('[data-id]'); if (!row) return;
        const id = row.dataset.id, ids = Sections.parse(S.sections, S.activeSection);
        if (e.target.closest('.switch')) {
            const on = ids.includes(id);
            if (on && ids.length === 1) { e.preventDefault(); return; }
            commit(on ? ids.filter(x => x !== id) : ids.concat([id]));
        } else if (e.target.closest('[data-size]')) {
            const sizes = {}; Schema.fields(S.sectionSizes).forEach(p => { const [k, v] = p.split(':'); sizes[k] = v; });
            sizes[id] = e.target.closest('[data-size]').dataset.size === 'm' ? '' : e.target.closest('[data-size]').dataset.size;
            update({ sectionSizes: Object.keys(sizes).filter(k => sizes[k]).map(k => k + ':' + sizes[k]).join(',') });
        } else if (e.target.closest('[data-span]')) {
            const spans = Schema.fields(S.sectionSpans);
            update({ sectionSpans: (spans.includes(id) ? spans.filter(x => x !== id) : spans.concat([id])).join(',') });
        }
    });
    list.addEventListener('change', e => {
        const sel = e.target.closest('select'), row = e.target.closest('[data-id]'); if (!sel || !row) return;
        const map = Schema.parseStyles(S.sectionStyles); map[row.dataset.id] = sel.value; update({ sectionStyles: Schema.formatStyles(map) });
    });
    return s => {
        const ids = Sections.parse(s.sections, s.activeSection), spans = Schema.fields(s.sectionSpans), grid = (s.layoutColumns || 1) > 1;
        const styleMap = Schema.parseStyles(s.sectionStyles), sizes = {};
        Schema.fields(s.sectionSizes).forEach(p => { const [k, v] = p.split(':'); sizes[k] = v; });
        const order = ids.concat(Sections.IDS.filter(x => !ids.includes(x)));
        list.innerHTML = order.map(id => {
            const on = ids.includes(id), info = Sections.info(id);
            return `<div class="gs-row${on ? ' on' : ''}" data-id="${id}" draggable="${on}">
              <span class="gs-grip" title="Drag to reorder">${on ? '⠿' : ''}</span>
              <input type="checkbox" class="switch" ${on ? 'checked' : ''} aria-label="Show ${esc(info.label)}">
              <svg viewBox="0 0 24 24"><path d="${info.icon}"/></svg>
              <span class="gs-name">${esc(Sections.title(id, s))}${on && Sections.panelIds(s).includes(id) ? '<small>Shown in panels</small>' : ''}</span>
              ${on ? `<span class="gs-ctl">${grid ? `<button class="ghost small${spans.includes(id) ? ' on' : ''}" data-span>Full width</button>` : ''}${chartSections.includes(id) ? `<span class="seg small">${['s', 'm', 'l'].map(z => `<button data-size="${z}" aria-pressed="${(sizes[id] || 'm') === z}">${z.toUpperCase()}</button>`).join('')}</span><select class="sel">${styles.map(([v, l]) => `<option value="${v}" ${(styleMap[id] || '') === v ? 'selected' : ''}>${l}</option>`).join('')}</select>` : ''}</span>` : ''}
            </div>`;
        }).join('');
    };
}

// Presets tab: the looks, plus saving, copying and importing.
const savedLooks = () => { try { return Looks.parseSaved(localStorage.getItem('glassy-looks')); } catch (e) { return []; } };
const storeLooks = list => { try { localStorage.setItem('glassy-looks', JSON.stringify(list)); } catch (e) { } };
function renderLookGallery(el) {
    el.innerHTML = `<div class="pp-grid"></div>
      <div class="gl-tools"><input class="sel txt" placeholder="Name this look" aria-label="Look name"><button class="primary" data-act="save">Save current</button><button class="ghost" data-act="copy">Copy as JSON</button><button class="ghost" data-act="import">Import JSON</button></div>
      <div class="gl-import" hidden><textarea class="sel" rows="4" placeholder="Paste a look"></textarea><button class="primary" data-act="doimport">Import and save</button></div>
      <p class="rd">A look covers layout, charts, card and colours. Commands, ping hosts, devices, thresholds and placement stay as they are, so an imported look can never run anything. Looks saved here stay in this browser; <em>Copy as JSON</em> and paste it into the widget's Presets › Import JSON.</p>`;
    const grid = $('.pp-grid', el), name = $('input', el);
    el.addEventListener('click', e => {
        const act = e.target.closest('[data-act]');
        const tile = e.target.closest('.pp');
        if (tile && !act) { applyLook(tile._look); return; }
        if (!act) return;
        const a = act.dataset.act;
        if (a === 'save' && name.value.trim()) { storeLooks(savedLooks().concat([{ name: name.value.trim(), settings: Looks.extract(S, BASE) }])); toast('Saved “' + name.value.trim() + '”'); name.value = ''; syncSettings(); renderPresets(); }
        if (a === 'copy') { navigator.clipboard.writeText(Looks.encode(name.value.trim() || 'My look', Looks.extract(S, BASE), DEFAULTS)); toast('Look copied'); }
        if (a === 'import') $('.gl-import', el).hidden = !$('.gl-import', el).hidden;
        if (a === 'doimport') {
            try { const look = Looks.decode($('textarea', el).value, DEFAULTS); storeLooks(savedLooks().concat([look])); $('textarea', el).value = ''; $('.gl-import', el).hidden = true; toast('Imported “' + look.name + '”'); syncSettings(); renderPresets(); }
            catch (err) { toast(err.message || 'That is not a valid look.'); }
        }
        if (a === 'delete') { const i = Number(act.dataset.i); storeLooks(savedLooks().filter((_, k) => k !== i)); syncSettings(); renderPresets(); }
    });
    let signature = '';
    return s => {
        const all = Looks.BUILT_IN.concat(savedLooks().map((l, i) => ({ id: 'mine' + i, name: l.name, note: 'Saved in this browser', s: l.settings, mine: i })));
        const sig = JSON.stringify(all.map(l => l.name)) + JSON.stringify(changed(s));
        if (sig === signature) return;
        signature = sig;
        grid.innerHTML = all.map((l, i) => `<div class="pp" role="button" tabindex="0" data-i="${i}" aria-pressed="${Looks.matches(s, BASE, l.s)}"><div class="ppv"><span class="bd bd-${['sea', 'dusk', 'breeze', 'neon', 'olive', 'sea', 'dusk'][i % 7]}"></span><div class="fit"><div class="fi"></div></div></div><div class="tl"><span>${esc(l.name)}</span>${l.mine !== undefined ? `<button class="del" data-act="delete" data-i="${l.mine}" title="Delete" aria-label="Delete ${esc(l.name)}">×</button>` : ''}</div></div>`).join('');
        $$('.pp', grid).forEach((t, i) => {
            t._look = all[i];
            mount($('.fi', t), widgetHTML(Looks.apply(s, BASE, all[i].s)));
        });
        fitCards();
    };
}

// Info tab.
function renderProjectInfo(el) {
    el.innerHTML = `<div class="gi">
      <div class="gi-head"><img src="assets/studio/icon.png" alt=""><div><h3>${esc(Project.name)}</h3><a href="${Project.profile}" target="_blank" rel="noopener">By ${esc(Project.author)} ↗</a></div></div>
      <p class="rd">An open-source system monitor for Plasma and Hyprland: CPU, memory, network, ping, disks, GPU, sensors and power in one glass card.</p>
      <div class="gi-stats">${Project.statistics.map(st => `<a href="${st.href}" target="_blank" rel="noopener"><b data-count="${st.id}">—</b><span>${esc(st.label)} ↗</span></a>`).join('')}</div>
      <div class="gi-card"><b>License · ${esc(Project.license)}</b><span class="rd">${esc(Project.licenseId)}</span></div>
      <h4>Support the project</h4>
      <div class="gi-stats">${Project.funding.map(f => `<a href="${f.url}" target="_blank" rel="noopener"><img src="assets/studio/icons/${f.icon}" alt=""><span>${esc(f.label)}</span></a>`).join('')}</div>
      <div class="btnrow"><a class="ghost" href="${Project.repository}" target="_blank" rel="noopener">View source on GitHub ↗</a><a class="ghost" href="${Project.repository}/issues" target="_blank" rel="noopener">Report an issue ↗</a></div>
    </div>`;
    loadCounts();
    return () => { };
}

function renderSettings() {
    $('#tabs').innerHTML = Schema.MAIN_TABS.map(t => `<button role="tab" data-tab="${t.first || t.id}" data-group="${t.id}"><svg viewBox="0 0 24 24"><path d="${t.icon}"/></svg>${esc(t.label)}</button>`).join('');
    if (!$('#subtabs')) $('#tabs').insertAdjacentHTML('afterend', '<div id="subtabs" class="studio-subtabs"></div>');
    const body = $('#pbody');
    body.innerHTML = '';
    rows = [];
    for (const sec of Schema.SECTIONS) {
        const wrap = document.createElement('div');
        wrap.className = 'sec'; wrap.dataset.tab = sec.tab; wrap._sec = sec;
        wrap.innerHTML = `${sec.tab === 'presets' ? '' : `<h4>${esc(sec.title)}</h4>`}<div class="card"></div>`;
        for (const r of sec.rows) { const row = buildRow(r); $('.card', wrap).appendChild(row.el); rows.push(row); }
        body.appendChild(wrap);
    }
    body.insertAdjacentHTML('beforeend', '<div class="empty-search" hidden>No settings match that search.</div>');
}
function syncSettings() {
    const q = query.trim().toLowerCase();
    for (const row of rows) {
        row.el.hidden = !Schema.rowVisible(row.r, {}, S, env, q);
        if (!row.el.hidden) row.sync(S);
    }
    let any = false;
    $$('.sec', $('#pbody')).forEach(sec => {
        const vis = $$('.row', sec).filter(r => !r.hidden);
        sec.hidden = !(q || sec.dataset.tab === activeTab) || !vis.length || (sec._sec.when && !sec._sec.when(S, env));
        $$('.row', sec).forEach(r => r.classList.remove('first'));
        if (vis[0]) vis[0].classList.add('first');
        if (!sec.hidden) any = true;
    });
    $('.empty-search').hidden = any;
    const group = Schema.tabGroup(activeTab);
    $$('#tabs [data-tab]').forEach(b => b.setAttribute('aria-selected', !q && b.dataset.group === group));
    if (Schema.resolveTab(activeTab, S) !== activeTab) activeTab = Schema.resolveTab(activeTab, S);
    const sub = $('#subtabs'), subs = Schema.subTabs(group, S);
    sub.hidden = !!q || !subs.length;
    sub.innerHTML = `<div class="seg">${subs.map(t => `<button data-sub="${t.id}" aria-pressed="${t.id === activeTab}"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="${t.icon}"/></svg>${esc(t.label)}</button>`).join('')}</div>${group === 'sections' ? '<button class="ghost small" data-sub="layout" title="Only switched-on sections are listed">+ More sections</button>' : ''}`;
    drawTiles();
}
function drawTiles() {
    for (const c of $$('canvas[data-tile]')) {
        const style = c.dataset.tile, wave = Array.from({ length: 24 }, (_, i) => 45 + 22 * Math.sin(i / 2.6) + 12 * Math.sin(i * 1.3));
        const spec = chartSpec({ ...S, showYLabels: false, smoothScroll: false }, '', { style, series: [{ values: wave, value: 64, color: '#55ffcc' }, { values: wave.map(v => v * 0.45), value: 38, color: '#4aa8ff' }], maxValue: 100 });
        spec.historySize = 24; spec.plotLeft = 0; spec.step = c.clientWidth / 23; spec.phase = 1;
        if (style !== 'meter') renderer && renderer.draw(c, spec);
    }
}
$('#subtabs') || null;
document.addEventListener('click', e => {
    const tab = e.target.closest('#tabs [data-tab]');
    if (tab) { activeTab = Schema.resolveTab(tab.dataset.tab, S); query = ''; $('#search').value = ''; $('#pbody').scrollTop = 0; syncSettings(); }
    const sub = e.target.closest('#subtabs [data-sub]');
    if (sub) { activeTab = sub.dataset.sub; $('#pbody').scrollTop = 0; syncSettings(); }
});
$('#search').addEventListener('input', e => { query = e.target.value; syncSettings(); });
document.addEventListener('keydown', e => { if (e.key === '/' && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) { e.preventDefault(); $('#search').focus(); } });

/* ─── changed settings and export ──────────────────────────────── */
function renderConfig() {
    const list = Object.entries(changed()).filter(([k]) => env === 'hypr' || !HYPR.hasOwnProperty(k));
    $('#cfg').innerHTML = list.length ? list.map(([k, v]) => `<span class="kv${HYPR.hasOwnProperty(k) ? ' ishypr' : ''}"><b>${esc(k)}</b>${esc(typeof v === 'number' && !Number.isInteger(v) ? Math.round(v * 100) / 100 : v)}</span>`).join('') : '<span class="none">Everything is at its default.</span>';
    $('#cfgTitle').innerHTML = `Changed settings <span>· ${list.length}</span>`;
    $('#copyCfg').textContent = env === 'hypr' ? 'Copy hyprland.json' : 'Copy config';
}
$('#copyCfg').onclick = () => {
    const out = Object.fromEntries(Object.entries(changed()).filter(([k]) => env === 'hypr' || !HYPR.hasOwnProperty(k)));
    navigator.clipboard.writeText(env === 'hypr' ? JSON.stringify(out, null, 2) + '\n' : Object.entries(out).map(([k, v]) => `${k}=${v}`).join('\n'));
    toast(env === 'hypr' ? 'Copied — save it as ~/.config/glassy-system-monitor/hyprland.json' : 'Copied the changed keys');
};
$('#copyLook').onclick = () => { navigator.clipboard.writeText(Looks.encode('My look', Looks.extract(S, BASE), DEFAULTS)); toast('Look copied — paste it under Presets › Import JSON in the widget'); };
$('#resetAll').onclick = () => { S = { ...BASE }; onChange(); toast('Back to defaults'); };

/* ─── pages, updates, animation ────────────────────────────────── */
let toastTimer;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('on'), 2200); }
function update(patch) { S = { ...S, ...patch }; onChange(); }
function onChange() { save(); charts.clear(); syncSettings(); renderConfig(); renderMain(); renderPresets(); renderHero(); }
function renderHero() { mount($('#heroFi'), widgetHTML(lookState(Looks.BUILT_IN[1]))); fitCards(); }
function showPage(page) {
    $$('main > [data-page]').forEach(p => p.hidden = p.dataset.page !== page);
    $$('nav.jump [data-page]').forEach(a => a.toggleAttribute('aria-current', a.dataset.page === page));
    scrollTo({ top: 0 });
    requestAnimationFrame(() => { fitStage(); fitCards(); drawTiles(); });
}
document.addEventListener('click', e => { const a = e.target.closest('a[data-page]'); if (a) { e.preventDefault(); showPage(a.dataset.page); } });
// A new sample each second: refresh the numbers; charts scroll every frame.
setInterval(() => { monitor.step(); charts.clear(); renderMain(); renderHero(); for (const card of $$('.pcard')) mount($('.fi', card), widgetHTML(lookState(card._look))); fitCards(); }, 1000);
(function frame() { if (renderer) drawCharts(); requestAnimationFrame(frame); })();
addEventListener('resize', () => { fitStage(); fitCards(); });

// Project numbers from shields.io badges.
let counted = false;
function loadCounts() {
    if (counted) return; counted = true;
    for (const st of Project.statistics)
        fetch(st.url).then(r => r.json()).then(b => { const v = Project.count(JSON.stringify(b)); if (v) $$(`[data-count="${st.id}"]`).forEach(el => el.textContent = v); }).catch(() => { });
}
loadCounts();

renderSettings();
onChange();

// Liquid glass: the highlight follows the pointer, as in the widget.
document.addEventListener('pointermove', e => {
    const card = e.target.closest && e.target.closest('.gw.specular');
    if (!card) return;
    const r = card.getBoundingClientRect();
    card.style.setProperty('--mx', ((e.clientX - r.left) / r.width * 100).toFixed(1) + '%');
    card.style.setProperty('--my', ((e.clientY - r.top) / r.height * 100).toFixed(1) + '%');
});
