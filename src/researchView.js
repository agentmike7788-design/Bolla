import { ITEMS } from './factory.js';
import { RESEARCH, depthOf, researchById } from './research.js';

const hex = (color) => `#${color.toString(16).padStart(6, '0')}`;

function costRows(r, stored) {
  return Object.entries(r.cost)
    .map(([k, need]) => {
      const have = Math.min(stored[k], need);
      return `<li style="--c:${hex(ITEMS[k].color)}" data-item="${k}">
        <span class="swatch"></span><span class="name">${ITEMS[k].name}</span>
        <span class="num">${have}/${need}</span>
        <span class="bar"><i style="width:${(have / need) * 100}%"></i></span></li>`;
    })
    .join('');
}

function updateCostRows(list, r, stored) {
  for (const li of list.querySelectorAll('li[data-item]')) {
    const k = li.dataset.item;
    const need = r.cost[k];
    const have = Math.min(stored[k], need);
    li.querySelector('.num').textContent = `${have}/${need}`;
    li.querySelector('.bar i').style.width = `${(have / need) * 100}%`;
  }
}

// The research panel in the corner (the entry you are working towards) and the
// full tree as an overlay. `onResearch` is called after an entry was completed.
export function createResearchView({ getFactory, onResearch }) {
  const panel = document.getElementById('goal');
  const overlay = document.getElementById('tree');
  const columns = overlay.querySelector('.tree-cols');
  const scroller = overlay.querySelector('.tree-scroll');
  const lines = overlay.querySelector('.tree-lines');
  let pinned = null; // id the player chose to work towards
  let panelId; // id the panel currently shows
  let enabled = true; // off on mission maps, where the panel shows the mission

  const factory = () => getFactory();

  function research(id) {
    if (!factory().research.complete(id)) return;
    if (pinned === id) pinned = null;
    onResearch(researchById(id));
    update();
  }

  // What the corner panel shows: the pinned entry, else the first one that can be researched.
  function target() {
    const rs = factory().research;
    if (pinned && !rs.done.has(pinned)) return researchById(pinned);
    return RESEARCH.find((r) => rs.available(r)) ?? null;
  }

  function stateOf(r) {
    const rs = factory().research;
    if (rs.done.has(r.id)) return 'done';
    if (!rs.available(r)) return 'locked';
    return rs.affordable(r) ? 'ready' : 'open';
  }

  function renderPanel() {
    const r = target();
    panelId = r?.id ?? null;
    if (!r) {
      panel.innerHTML = `<p class="label">Forschung</p>
        <p class="goal-name">Alles erforscht</p>
        <p class="goal-unlock">Baue weiter, so groß du willst.</p>
        <button type="button" class="link" data-open>Forschungsbaum <kbd>T</kbd></button>`;
      return;
    }
    panel.innerHTML = `<p class="label">Forschung${r.goal ? ' · Spielziel' : ''}</p>
      <p class="goal-name">${r.name}</p>
      <p class="goal-desc">${r.desc}</p>
      <ul>${costRows(r, factory().stored)}</ul>
      <div class="goal-actions">
        <button type="button" data-research="${r.id}">Erforschen</button>
        <button type="button" class="link" data-open>Forschungsbaum <kbd>T</kbd></button>
      </div>`;
  }

  // Build the tree from scratch: one column per depth, then lines between entries.
  function renderTree() {
    const byDepth = [];
    for (const r of RESEARCH) (byDepth[depthOf(r)] ??= []).push(r);
    columns.innerHTML = byDepth
      .map(
        (col) => `<div class="tree-col">${col
          .map(
            (r) => `<article class="node" data-id="${r.id}">
              <p class="node-name">${r.name}${r.goal ? ' <span class="tag">Ziel</span>' : ''}</p>
              <p class="node-desc">${r.desc}</p>
              <ul>${costRows(r, factory().stored)}</ul>
              <p class="node-state"></p>
              <div class="node-actions">
                <button type="button" data-research="${r.id}">Erforschen</button>
                <button type="button" class="link" data-pin="${r.id}">Anzeigen</button>
              </div>
            </article>`,
          )
          .join('')}</div>`,
      )
      .join('');
    update();
  }

  function drawLines() {
    const box = scroller.getBoundingClientRect();
    const dx = scroller.scrollLeft - box.left;
    const dy = scroller.scrollTop - box.top;
    lines.setAttribute('width', scroller.scrollWidth);
    lines.setAttribute('height', scroller.scrollHeight);
    const nodeRect = (id) => columns.querySelector(`[data-id="${id}"]`).getBoundingClientRect();
    const paths = [];
    for (const r of RESEARCH) {
      const to = nodeRect(r.id);
      for (const id of r.requires) {
        const from = nodeRect(id);
        const x1 = from.right + dx;
        const y1 = from.top + from.height / 2 + dy;
        const x2 = to.left + dx;
        const y2 = to.top + to.height / 2 + dy;
        const mid = (x1 + x2) / 2;
        const done = factory().research.done.has(id) ? ' done' : '';
        paths.push(`<path class="line${done}" d="M${x1} ${y1} C${mid} ${y1} ${mid} ${y2} ${x2} ${y2}" />`);
      }
    }
    lines.innerHTML = paths.join('');
  }

  const STATE_TEXT = { done: 'Erforscht', locked: 'Braucht erst: ', ready: 'Bereit', open: 'Material ins Lager bringen' };

  // Refresh numbers and states without rebuilding the DOM, so clicks are not lost.
  function update() {
    if (!enabled) return;
    const f = factory();
    if (target()?.id !== panelId) renderPanel();
    const r = target();
    if (r) {
      updateCostRows(panel, r, f.stored);
      panel.querySelector('[data-research]').disabled = !f.research.affordable(r);
    }
    if (overlay.hidden) return;
    for (const node of columns.querySelectorAll('.node')) {
      const entry = researchById(node.dataset.id);
      const state = stateOf(entry);
      node.dataset.state = state;
      node.classList.toggle('pinned', entry.id === target()?.id);
      updateCostRows(node, entry, f.stored);
      const missing = entry.requires.filter((id) => !f.research.done.has(id)).map((id) => researchById(id).name);
      node.querySelector('.node-state').textContent = STATE_TEXT[state] + (state === 'locked' ? missing.join(', ') : '');
      node.querySelector('[data-research]').hidden = state !== 'ready';
      node.querySelector('[data-pin]').hidden = state === 'done' || state === 'ready' || entry.id === target()?.id;
    }
    drawLines();
  }

  function open() {
    if (!enabled) return;
    overlay.hidden = false;
    renderTree();
  }
  function close() {
    overlay.hidden = true;
  }

  for (const root of [panel, overlay]) {
    root.addEventListener('click', (e) => {
      const el = e.target.closest('button');
      if (!el) return;
      if (el.dataset.research) research(el.dataset.research);
      else if (el.dataset.pin) {
        pinned = el.dataset.pin;
        update();
      } else if ('open' in el.dataset) open();
      else if ('close' in el.dataset) close();
    });
  }
  overlay.addEventListener('pointerdown', (e) => {
    if (e.target === overlay) close();
  });
  window.addEventListener('resize', () => !overlay.hidden && drawLines());

  return {
    reset() {
      pinned = null;
      if (!enabled) return;
      panelId = undefined;
      renderPanel();
      if (!overlay.hidden) renderTree();
      else update();
    },
    update,
    setEnabled(on) {
      enabled = on;
      if (!on) close();
    },
    get enabled() {
      return enabled;
    },
    toggle: () => (overlay.hidden ? open() : close()),
    close,
    get isOpen() {
      return !overlay.hidden;
    },
  };
}
