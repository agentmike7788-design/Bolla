import { ITEMS } from './factory.js';
import { ORES } from './world.js';
import { BUCKET } from './stats.js';

// The statistics window (key L): parts made and used per minute over the last ten
// minutes or the last hour as a line chart, one line per resource, and the power
// of all networks. The list next to the chart is the legend: a click shows or
// hides a resource's line.

const RESOURCES = { ...ITEMS, oil: { name: 'Erdöl', color: 0xe0a040 } };
const SIDES = { p: 'Produktion', c: 'Verbrauch', power: 'Strom' };
const RANGES = { 10: '10 Min.', 60: '1 Std.' };
const POWER_SERIES = [
  { key: 'cap', name: 'Leistung', color: '#7fd4ff' },
  { key: 'dem', name: 'Bedarf', color: '#ffd34d' },
];
const num = (n) => n.toLocaleString('de-DE', { maximumFractionDigits: n < 10 ? 1 : 0 });

// Dark items (coal, steel) get a lighter line so they show on the dark panel.
function lineColor(color) {
  let r = (color >> 16) & 255;
  let g = (color >> 8) & 255;
  let b = color & 255;
  const lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
  const k = lum < 0.42 ? (0.42 - lum) / (1 - lum) + 0.12 : 0;
  r = Math.round(r + (255 - r) * k);
  g = Math.round(g + (255 - g) * k);
  b = Math.round(b + (255 - b) * k);
  return `rgb(${r}, ${g}, ${b})`;
}

// Round axis steps: 1, 2, 5, 10, 20 …
function niceMax(v) {
  if (v <= 0) return 10;
  const p = 10 ** Math.floor(Math.log10(v));
  for (const m of [1, 2, 2.5, 5, 10]) if (m * p >= v) return m * p;
  return 10 * p;
}

export function createStatsView({ root, getFactory, onClose }) {
  const overlay = document.createElement('div');
  overlay.className = 'tree stats';
  overlay.hidden = true;
  overlay.innerHTML = `<section class="tree-box stats-box" role="dialog" aria-label="Statistik">
      <header class="tree-head">
        <h2>Statistik</h2>
        <div class="segmented stats-side" role="radiogroup" aria-label="Ansicht">${Object.entries(SIDES)
          .map(([k, t]) => `<button type="button" role="radio" data-side="${k}">${t}</button>`)
          .join('')}</div>
        <div class="segmented stats-range" role="radiogroup" aria-label="Zeitraum">${Object.entries(RANGES)
          .map(([k, t]) => `<button type="button" role="radio" data-range="${k}">${t}</button>`)
          .join('')}</div>
        <button type="button" class="link" data-close>Schließen <kbd>Esc</kbd></button>
      </header>
      <div class="stats-body">
        <div class="stats-chart">
          <p class="stats-title"></p>
          <svg aria-hidden="true"></svg>
          <div class="stats-tip" hidden></div>
        </div>
        <div class="stats-list" role="table"></div>
      </div>
    </section>`;
  root.append(overlay);
  const svg = overlay.querySelector('svg');
  const chart = overlay.querySelector('.stats-chart');
  const tip = overlay.querySelector('.stats-tip');
  const list = overlay.querySelector('.stats-list');
  const title = overlay.querySelector('.stats-title');

  let side = 'p';
  let range = 10;
  let hidden = new Set(); // resources the player switched off
  let picked = null; // resources shown before the player changed anything: the biggest ones
  let seen = -1; // history version drawn
  let points = []; // { t, values } of the drawn chart, for the tooltip
  let series = [];
  let layout = null;

  // Per-minute values over the chosen range, oldest first. The bucket being
  // filled counts once it has a few seconds in it.
  function sample(history, read) {
    const per = range === 60 ? 6 : 1; // buckets per point
    const buckets = [...history.buckets];
    if (history.currentTime >= 2) buckets.push({ ...history.current, partial: history.currentTime });
    const out = [];
    for (let end = buckets.length; end > 0 && out.length < 60; end -= per) {
      const group = buckets.slice(Math.max(0, end - per), end);
      const seconds = group.reduce((s, b) => s + (b.partial ?? BUCKET), 0);
      out.unshift({ ago: (buckets.length - end) * BUCKET, value: (key) => (group.reduce((s, b) => s + read(b, key), 0) / seconds) * 60, seconds });
    }
    return out;
  }

  function render() {
    const factory = getFactory();
    const h = factory.history;
    seen = h.version;
    for (const b of overlay.querySelectorAll('[data-side]')) b.setAttribute('aria-checked', String(b.dataset.side === side));
    for (const b of overlay.querySelectorAll('[data-range]')) b.setAttribute('aria-checked', String(Number(b.dataset.range) === range));

    if (side === 'power') {
      const pts = sample(h, (b, key) => b[key] / 60); // MW·s per second → MW, per-minute scaling undone
      points = pts.map((p) => ({ ago: p.ago, values: Object.fromEntries(POWER_SERIES.map((s) => [s.key, p.value(s.key)])) }));
      series = POWER_SERIES;
      title.textContent = 'Stromnetz in MW';
      const s = factory.powerSummary();
      list.innerHTML = `<div class="stats-row head" role="row"><span></span><span>Stromnetz</span><span>jetzt</span></div>
        ${POWER_SERIES.map((p) => `<div class="stats-row static" role="row"><span class="swatch" style="--c:${p.color}"></span><span>${p.name}</span><span class="v">${num(p.key === 'cap' ? s.capacity : s.demand)} MW</span></div>`).join('')}
        <div class="stats-row static" role="row"><span></span><span>Versorgt</span><span class="v">${s.demand ? Math.round(s.satisfaction * 100) : 100} %</span></div>
        <div class="stats-row static" role="row"><span></span><span>Netze · Kraftwerke</span><span class="v">${s.nets} · ${s.plants}</span></div>
        <div class="stats-row static" role="row"><span></span><span>Maschinen am Netz</span><span class="v">${s.consumers}</span></div>
        <p class="panel-note">Leistung ist, was die Kraftwerke mit ihrem Brennstoff liefern können; Bedarf, was die Maschinen am Netz gerade brauchen.</p>`;
    } else {
      const pts = sample(h, (b, key) => b[side][key] ?? 0);
      // Every resource that moved at all, biggest first by its total in the range.
      const keys = Object.keys(RESOURCES).filter((k) => (h.total.p[k] ?? 0) + (h.total.c[k] ?? 0) > 0);
      const sum = (k) => pts.reduce((s, p) => s + p.value(k) * p.seconds, 0);
      keys.sort((a, b) => sum(b) - sum(a));
      if (!picked) hidden = new Set(keys.slice(6));
      series = keys.filter((k) => !hidden.has(k) && sum(k) > 0).map((k) => ({ key: k, name: RESOURCES[k].name, color: lineColor(RESOURCES[k].color) }));
      points = pts.map((p) => ({ ago: p.ago, values: Object.fromEntries(series.map((s) => [s.key, p.value(s.key)])) }));
      title.textContent = `${side === 'p' ? 'Hergestellt' : 'Verbraucht'} pro Minute`;
      list.innerHTML = keys.length
        ? `<div class="stats-row head" role="row"><span></span><span>Pro Minute</span><span>her</span><span>ver</span><span>Bilanz</span></div>` +
          keys
            .map((k) => {
              const made = h.perMinute(k, 'p');
              const used = h.perMinute(k, 'c');
              const net = made - used;
              const off = hidden.has(k);
              return `<button type="button" class="stats-row${off ? ' off' : ''}" role="row" data-key="${k}" aria-pressed="${!off}" title="Linie ${off ? 'zeigen' : 'ausblenden'}">
                <span class="swatch" style="--c:${lineColor(RESOURCES[k].color)}"></span><span class="n">${RESOURCES[k].name}</span>
                <span class="v">${num(made)}</span><span class="v">${num(used)}</span>
                <span class="v ${net > 0.05 ? 'plus' : net < -0.05 ? 'minus' : ''}">${net > 0.05 ? '+' : ''}${num(net)}</span></button>`;
            })
            .join('')
        : '<p class="panel-note">Noch nichts hergestellt. Sobald Bohrer und Maschinen laufen, erscheinen ihre Teile hier.</p>';
    }
    draw();
  }

  function draw() {
    const w = Math.max(280, chart.clientWidth);
    const hgt = Math.max(180, Math.min(320, w * 0.5));
    svg.setAttribute('width', w);
    svg.setAttribute('height', hgt);
    svg.setAttribute('viewBox', `0 0 ${w} ${hgt}`);
    const pad = { l: 44, r: 12, t: 10, b: 24 };
    const span = range * 60; // seconds shown
    const x = (ago) => pad.l + (1 - ago / span) * (w - pad.l - pad.r);
    let max = 0;
    for (const p of points) for (const s of series) max = Math.max(max, p.values[s.key]);
    max = niceMax(max * 1.08);
    const y = (v) => pad.t + (1 - v / max) * (hgt - pad.t - pad.b);
    layout = { x, y, pad, w, hgt, span };

    let out = '';
    for (let i = 0; i <= 4; i++) {
      const v = (max / 4) * i;
      out += `<line class="grid" x1="${pad.l}" x2="${w - pad.r}" y1="${y(v)}" y2="${y(v)}"/><text class="tick" x="${pad.l - 6}" y="${y(v) + 4}" text-anchor="end">${num(v)}</text>`;
    }
    const marks = range === 60 ? [60, 45, 30, 15, 0] : [10, 8, 6, 4, 2, 0];
    for (const m of marks) out += `<text class="tick" x="${x(m * 60)}" y="${hgt - 6}" text-anchor="${m ? 'middle' : 'end'}">${m ? `−${m} min` : 'jetzt'}</text>`;
    if (points.length > 1) {
      for (const s of series) {
        const d = points.map((p, i) => `${i ? 'L' : 'M'}${x(p.ago).toFixed(1)},${y(p.values[s.key]).toFixed(1)}`).join('');
        out += `<path class="line" data-line="${s.key}" d="${d}" stroke="${s.color}"/>`;
      }
    } else {
      out += `<text class="tick empty" x="${(pad.l + w - pad.r) / 2}" y="${hgt / 2}" text-anchor="middle">Die ersten Werte kommen nach ${BUCKET} Sekunden Spielzeit.</text>`;
    }
    out += `<line class="cross" x1="0" x2="0" y1="${pad.t}" y2="${hgt - pad.b}" visibility="hidden"/>`;
    svg.innerHTML = out;
  }

  // Crosshair and tooltip: the values of every shown line at the nearest point.
  function hover(e) {
    if (!layout || points.length < 2) return;
    const rect = svg.getBoundingClientRect();
    const mx = e.clientX - rect.left;
    const ago = (1 - (mx - layout.pad.l) / (layout.w - layout.pad.l - layout.pad.r)) * layout.span;
    let best = null;
    for (const p of points) if (!best || Math.abs(p.ago - ago) < Math.abs(best.ago - ago)) best = p;
    if (!best || mx < layout.pad.l - 8) return leave();
    const cx = layout.x(best.ago);
    const cross = svg.querySelector('.cross');
    cross.setAttribute('x1', cx);
    cross.setAttribute('x2', cx);
    cross.setAttribute('visibility', 'visible');
    const unit = side === 'power' ? ' MW' : '/min';
    const when = best.ago < 30 ? 'gerade eben' : `vor ${num(Math.round(best.ago / 6) / 10)} min`;
    const rows = [...series].sort((a, b) => best.values[b.key] - best.values[a.key]);
    tip.innerHTML = `<p class="label">${when}</p>${rows
      .map((s) => `<p><span class="swatch" style="--c:${s.color}"></span>${s.name}<b>${num(best.values[s.key])}${unit}</b></p>`)
      .join('')}`;
    tip.hidden = false;
    const left = cx + 14 + tip.offsetWidth > layout.w ? cx - 14 - tip.offsetWidth : cx + 14;
    tip.style.left = `${left}px`;
  }
  function leave() {
    tip.hidden = true;
    svg.querySelector('.cross')?.setAttribute('visibility', 'hidden');
  }
  svg.addEventListener('pointermove', hover);
  // Pointing at a row of the list brings its line to the front; the others fade.
  list.addEventListener('pointerover', (e) => {
    const k = e.target.closest('[data-key]')?.dataset.key;
    for (const path of svg.querySelectorAll('[data-line]')) path.classList.toggle('dim', !!k && path.dataset.line !== k);
    const line = k && svg.querySelector(`[data-line="${k}"]`);
    if (line) svg.insertBefore(line, svg.querySelector('.cross'));
  });
  list.addEventListener('pointerleave', () => svg.querySelectorAll('.dim').forEach((p) => p.classList.remove('dim')));
  svg.addEventListener('pointerleave', leave);

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay || e.target.closest('[data-close]')) return close();
    const s = e.target.closest('[data-side]');
    const r = e.target.closest('[data-range]');
    const row = e.target.closest('[data-key]');
    if (s) side = s.dataset.side;
    else if (r) range = Number(r.dataset.range);
    else if (row) {
      picked = true;
      const k = row.dataset.key;
      if (hidden.has(k)) hidden.delete(k);
      else hidden.add(k);
    } else return;
    leave();
    render();
  });
  window.addEventListener('resize', () => !overlay.hidden && draw());

  function open() {
    overlay.hidden = false;
    picked = null;
    render();
  }
  function close() {
    overlay.hidden = true;
    leave();
    onClose?.();
  }

  return {
    open,
    close,
    toggle: () => (overlay.hidden ? open() : close()),
    get isOpen() {
      return !overlay.hidden;
    },
    // Redraws when a new bucket is finished.
    update() {
      if (!overlay.hidden && getFactory().history.version !== seen) render();
    },
  };
}
