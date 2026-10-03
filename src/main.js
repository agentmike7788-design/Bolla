import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
import {
  createFactory,
  DIRS,
  DIR_NAMES,
  BUILDINGS,
  ITEMS,
  RECIPES,
  RESEARCH,
  RESEARCH_BY_ID,
  BELT_TIERS,
  CONSTRUCTOR_RECIPES,
  isMachine,
} from './factory.js';
import { createFactoryView, createGhost } from './buildings.js';
import './style.css';

const canvas = document.getElementById('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.92;

const HORIZON = 0xcfe3ea;
const scene = new THREE.Scene();
scene.background = skyTexture();
scene.fog = new THREE.Fog(HORIZON, 110, 260);
// Soft reflections for water, crystals and metal ore.
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.35;

// Vertical gradient from deep sky blue down to a hazy horizon.
function skyTexture() {
  const c = document.createElement('canvas');
  c.width = 2;
  c.height = 256;
  const g = c.getContext('2d');
  const grad = g.createLinearGradient(0, 0, 0, 256);
  grad.addColorStop(0, '#5f9fcf');
  grad.addColorStop(0.65, '#a9cfe2');
  grad.addColorStop(1, '#cfe3ea');
  g.fillStyle = grad;
  g.fillRect(0, 0, 2, 256);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 400);
const rig = createCameraRig(camera, canvas, (MAP_SIZE * TILE) / 2);

scene.add(new THREE.HemisphereLight(0xd6ecff, 0x5a4a30, 0.85));
const sun = new THREE.DirectionalLight(0xffe2b8, 2.5);
sun.position.set(38, 42, 22);
sun.castShadow = true;
const shadowSize = matchMedia('(pointer: coarse)').matches ? 2048 : 4096;
sun.shadow.mapSize.set(shadowSize, shadowSize);
const half = (MAP_SIZE * TILE) / 2 + 4;
Object.assign(sun.shadow.camera, { left: -half, right: half, top: half, bottom: -half, near: 1, far: 160 });
sun.shadow.bias = -0.0004;
sun.shadow.normalBias = 0.02;
scene.add(sun);

const sea = createSea();
scene.add(sea.group);

// Hover marker: a thin frame that sits on top of the tile under the mouse.
const marker = new THREE.LineSegments(
  new THREE.EdgesGeometry(new THREE.BoxGeometry(TILE, 0.05, TILE)),
  new THREE.LineBasicMaterial({ color: 0xffd34d }),
);
marker.visible = false;
scene.add(marker);

const factoryView = createFactoryView(renderer);
scene.add(factoryView.group);
const ghost = createGhost();
scene.add(ghost.group);

let world;
let meshes;
let factory;

function loadWorld(seed) {
  if (meshes) {
    scene.remove(meshes.group);
    meshes.group.traverse((o) => {
      o.geometry?.dispose();
      o.material?.dispose();
    });
  }
  world = generateWorld(seed);
  meshes = buildWorldMeshes(world);
  scene.add(meshes.group);
  factory = createFactory(world);
  factoryView.clear();
  document.getElementById('seed').textContent = `#${seed}`;
  pinned = null;
  selected = null;
  recipePanel.hidden = true;
  if (tool && tool !== 'remove' && !factory.progress.unlocked.has(tool)) setTool(null);
  renderLegend();
  updateTree();
  renderProgress();
  showTile(null);
}

function renderLegend() {
  const counts = {};
  for (const t of world.tiles) {
    if (!t.ore) continue;
    counts[t.ore] ??= { tiles: 0, amount: 0 };
    counts[t.ore].tiles++;
    counts[t.ore].amount += t.amount;
  }
  const list = document.getElementById('legend');
  list.innerHTML = '';
  for (const [key, ore] of Object.entries(ORES)) {
    const c = counts[key] ?? { tiles: 0, amount: 0 };
    const li = document.createElement('li');
    li.innerHTML = `<span class="swatch" style="--c:${hex(ore.color)}"></span>
      <span class="name">${ore.name}</span>
      <span class="num">${c.amount.toLocaleString('de-DE')}</span>
      <span class="mined">${factory.mined[key] ? `+${factory.mined[key].toLocaleString('de-DE')}` : ''}</span>`;
    li.title = `${c.tiles} Felder · rechts: bisher abgebaut`;
    list.append(li);
  }
}

const hex = (color) => `#${color.toString(16).padStart(6, '0')}`;
const num = (n) => n.toLocaleString('de-DE');

// --- Research, storage and unlocks -----------------------------------------

const goalPanel = document.getElementById('goal');
const storeList = document.getElementById('store');
const toast = document.getElementById('toast');
const researchBtn = document.getElementById('open-research');
let pinned = null; // research the player chose to work towards
let toastTimer = 0;

function showToast(title, text) {
  toast.innerHTML = `<strong>${title}</strong><span>${text}</span>`;
  toast.hidden = false;
  toast.classList.remove('pop');
  void toast.offsetWidth; // restart the animation
  toast.classList.add('pop');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toast.hidden = true), 4200);
}

// What a research gives, in words.
function rewardText(r) {
  const parts = (r.unlocks ?? []).map((t) => BUILDINGS[t].name);
  if (r.belt) parts.push(BELT_TIERS[r.belt].name);
  if (r.speed) parts.push('Tempo');
  if (r.final) parts.push('Spielziel');
  return parts.join(', ');
}

// The research shown in the goal panel: the pinned one, else the first one that is open.
function goalResearch() {
  if (pinned && factory.researchState(RESEARCH_BY_ID[pinned]) === 'open') return RESEARCH_BY_ID[pinned];
  return RESEARCH.find((r) => factory.researchState(r) === 'open') ?? null;
}

function costRows(r) {
  return Object.entries(r.cost)
    .map(([k, need]) => {
      const have = Math.min(factory.stored[k], need);
      return `<li style="--c:${hex(ITEMS[k].color)}" class="${have >= need ? 'met' : ''}">
        <span class="swatch"></span><span class="name">${ITEMS[k].name}</span>
        <span class="num">${have}/${need}</span>
        <span class="bar"><i style="width:${(have / need) * 100}%"></i></span></li>`;
    })
    .join('');
}

function doResearch(id) {
  if (!factory.research(id)) return;
  const r = RESEARCH_BY_ID[id];
  if (pinned === id) pinned = null;
  if (r.final) showToast('Meisterfabrik!', 'Du hast den ganzen Technologie-Baum erforscht. Glückwunsch!');
  else showToast('Erforscht', `${r.name} · ${r.text}`);
  shapesDirty = true;
  updateTree();
  renderProgress();
  renderHelp();
}

goalPanel.addEventListener('click', (e) => {
  const go = e.target.closest('[data-research]');
  if (go) doResearch(go.dataset.research);
  if (e.target.closest('[data-open-tree]')) openResearch(true);
});

let goalKey = '';
function renderProgress() {
  const r = goalResearch();
  let html;
  if (factory.progress.done) {
    html = `<p class="label">Ziel erreicht</p>
      <p class="goal-name">Meisterfabrik</p>
      <p class="goal-unlock">Alles erforscht. Baue weiter, so groß du willst.</p>`;
  } else if (r) {
    const ready = factory.affordable(r);
    html = `<p class="label">Forschungsziel · Teile ins Lager bringen</p>
      <p class="goal-name">${r.name}</p>
      <ul>${costRows(r)}</ul>
      <p class="goal-unlock">Schaltet frei: <b>${rewardText(r)}</b></p>
      <div class="goal-actions">
        <button type="button" data-research="${r.id}" ${ready ? '' : 'disabled'}>${ready ? 'Jetzt erforschen' : 'Noch nicht genug'}</button>
        <button type="button" class="ghost-btn" data-open-tree>Baum</button>
      </div>`;
  } else {
    html = '';
  }
  // Only touch the DOM when something changed, so the buttons stay clickable.
  if (html !== goalKey) {
    goalPanel.innerHTML = html;
    goalKey = html;
  }

  const kept = Object.entries(factory.stored).filter(([, n]) => n > 0);
  storeList.innerHTML = kept.length
    ? kept
        .map(([k, n]) => `<li><span class="swatch" style="--c:${hex(ITEMS[k].color)}"></span><span class="name">${ITEMS[k].name}</span><span class="num">${num(n)}</span></li>`)
        .join('')
    : '<li class="empty">Noch leer. Lege ein Band in ein Lager.</li>';

  for (const b of toolButtons) {
    const type = b.dataset.tool;
    if (!BUILDINGS[type]) continue;
    const locked = !factory.progress.unlocked.has(type);
    b.classList.toggle('locked', locked);
    b.setAttribute('aria-disabled', String(locked));
    b.title = locked ? `Noch gesperrt: ${unlockHint(type)}` : BUILDINGS[type].name;
  }
  const beltBtn = document.querySelector('.tool[data-tool="belt"]');
  beltBtn.style.setProperty('--tier', hex(BELT_TIERS[factory.progress.beltTier].color));

  const canResearch = RESEARCH.some((x) => factory.researchState(x) === 'open' && factory.affordable(x));
  researchBtn.classList.toggle('ready', canResearch);
  if (!researchEl.hidden) updateTree();
}

function unlockHint(type) {
  const r = RESEARCH.find((x) => x.unlocks?.includes(type));
  return r ? `Forschung „${r.name}“` : '';
}

// --- Research menu --------------------------------------------------------

const researchEl = document.getElementById('research');
const tree = document.getElementById('tree');
const treeLines = document.getElementById('tree-lines');
const NODE_W = 210;
const NODE_H = 148;
const GAP_X = 46;
const GAP_Y = 18;
const nodes = {};

function buildTree() {
  const cols = Math.max(...RESEARCH.map((r) => r.col)) + 1;
  const rows = Math.max(...RESEARCH.map((r) => r.row)) + 1;
  const w = cols * NODE_W + (cols - 1) * GAP_X;
  const h = rows * NODE_H + (rows - 1) * GAP_Y;
  tree.style.width = `${w}px`;
  tree.style.height = `${h}px`;
  treeLines.setAttribute('viewBox', `0 0 ${w} ${h}`);
  treeLines.setAttribute('width', w);
  treeLines.setAttribute('height', h);
  const pos = (r) => ({ x: r.col * (NODE_W + GAP_X), y: r.row * (NODE_H + GAP_Y) });
  let lines = '';
  for (const r of RESEARCH) {
    const to = pos(r);
    for (const id of r.needs) {
      const from = pos(RESEARCH_BY_ID[id]);
      const x1 = from.x + NODE_W;
      const y1 = from.y + NODE_H / 2;
      const x2 = to.x;
      const y2 = to.y + NODE_H / 2;
      const mx = (x1 + x2) / 2;
      lines += `<path data-from="${id}" data-to="${r.id}" d="M${x1} ${y1}C${mx} ${y1} ${mx} ${y2} ${x2} ${y2}" />`;
    }
  }
  treeLines.innerHTML = lines;
  for (const r of RESEARCH) {
    const el = document.createElement('article');
    el.className = 'node';
    el.style.left = `${pos(r).x}px`;
    el.style.top = `${pos(r).y}px`;
    el.style.width = `${NODE_W}px`;
    el.style.height = `${NODE_H}px`;
    el.innerHTML = `<p class="node-name">${r.name}<span class="node-state"></span></p>
      <p class="node-text">${r.text}</p>
      <ul class="node-cost"></ul>
      <div class="node-actions"><button type="button" data-research="${r.id}">Erforschen</button><button type="button" class="ghost-btn" data-pin="${r.id}">Als Ziel</button></div>`;
    el.dataset.id = r.id;
    tree.append(el);
    nodes[r.id] = el;
  }
}

tree.addEventListener('click', (e) => {
  const go = e.target.closest('[data-research]');
  if (go) return doResearch(go.dataset.research);
  const pin = e.target.closest('[data-pin]');
  if (pin) {
    pinned = pin.dataset.pin;
    updateTree();
    renderProgress();
  }
});

function updateTree() {
  if (!factory) return;
  for (const r of RESEARCH) {
    const el = nodes[r.id];
    const state = factory.researchState(r);
    const ready = state === 'open' && factory.affordable(r);
    el.className = `node ${state}${ready ? ' ready' : ''}${goalResearch() === r ? ' pinned' : ''}${r.final ? ' final' : ''}`;
    el.querySelector('.node-state').textContent = state === 'done' ? 'Erforscht' : state === 'locked' ? 'Gesperrt' : ready ? 'Bereit' : '';
    el.querySelector('.node-cost').innerHTML = Object.entries(r.cost)
      .map(([k, n]) => {
        const have = state === 'done' ? n : Math.min(factory.stored[k], n);
        return `<li class="${have >= n ? 'met' : ''}"><span class="swatch" style="--c:${hex(ITEMS[k].color)}"></span>${ITEMS[k].name}<span class="num">${have}/${n}</span></li>`;
      })
      .join('');
    const go = el.querySelector('[data-research]');
    go.disabled = !ready;
    go.hidden = state !== 'open';
    el.querySelector('[data-pin]').hidden = state !== 'open' || goalResearch() === r;
  }
  for (const path of treeLines.children) {
    path.classList.toggle('done', factory.progress.researched.has(path.dataset.from));
  }
}

function openResearch(open) {
  researchEl.hidden = !open;
  if (open) {
    updateTree();
    if (tool) setTool(tool);
  }
}
researchBtn.addEventListener('click', () => openResearch(researchEl.hidden));
document.getElementById('research-close').addEventListener('click', () => openResearch(false));
researchEl.addEventListener('click', (e) => {
  if (e.target === researchEl) openResearch(false);
});

// --- Constructor recipes ----------------------------------------------------

const recipePanel = document.getElementById('recipe');
const recipeList = document.getElementById('recipe-list');
let selected = null; // the constructor whose recipe panel is open

function needsText(needs) {
  return Object.entries(needs)
    .map(([k, n]) => `${n} ${ITEMS[k].name}`)
    .join(' + ');
}

function openRecipes(b) {
  selected = b;
  recipePanel.hidden = !b;
  if (!b) return;
  recipeList.innerHTML = Object.entries(CONSTRUCTOR_RECIPES)
    .map(
      ([id, r]) => `<button type="button" class="recipe-option" data-recipe="${id}" aria-pressed="${b.recipe === id}">
        <span class="swatch" style="--c:${hex(ITEMS[r.makes].color)}"></span>
        <b>${ITEMS[r.makes].name}</b><span>${needsText(r.needs)} · ${r.time} s</span></button>`,
    )
    .join('');
}
recipeList.addEventListener('click', (e) => {
  const opt = e.target.closest('[data-recipe]');
  if (!opt || !selected) return;
  factory.setRecipe(selected, opt.dataset.recipe);
  openRecipes(selected);
  showTile(hovered);
});
document.getElementById('recipe-close').addEventListener('click', () => openRecipes(null));

const tileName = document.getElementById('tile-name');
const tileDetail = document.getElementById('tile-detail');

const STATE_TEXT = { work: 'Fördert', blocked: 'Wartet: Ausgang belegt', empty: 'Erschöpft' };
const MACHINE_TEXT = { work: 'Arbeitet', idle: 'Wartet auf Material', blocked: 'Wartet: Ausgang belegt' };
const itemList = (keys) => keys.map((k) => ITEMS[k].name).join(', ');

function showTile(tile) {
  hovered = tile;
  if (!tile) {
    marker.visible = false;
    ghost.show(null);
    tileName.textContent = 'Maus über die Karte bewegen';
    tileDetail.textContent = '';
    return;
  }
  const building = factory.get(tile);
  const check = tool === 'remove' ? { ok: !!building, reason: building ? '' : 'Hier steht nichts' } : tool && canBuild(tile);
  canvas.style.cursor = !tool && building?.type === 'constructor' ? 'pointer' : '';
  marker.visible = !tool;
  marker.position.set(tile.position.x, Math.max(tile.height, 0.28) + 0.03, tile.position.z);
  ghost.show(tool, tile, tool === 'remove' ? building?.dir ?? 0 : dir, check?.ok);

  const terrain = TERRAIN[tile.terrain];
  if (building?.type === 'drill') {
    tileName.textContent = `Bohrer · ${ORES[tile.ore].name}`;
    tileDetail.textContent = `${STATE_TEXT[building.state]} · ${building.mined} abgebaut · Rest ${tile.amount.toLocaleString('de-DE')}`;
  } else if (building?.type === 'belt') {
    const tier = BELT_TIERS[building.tier];
    tileName.textContent = tier.name;
    tileDetail.textContent = `Richtung ${DIR_NAMES[building.dir]} · ${num(tier.speed)} Felder/s · ${building.items.length} Teile drauf`;
  } else if (building?.type === 'splitter') {
    tileName.textContent = 'Verteiler';
    tileDetail.textContent = `Nimmt von hinten, gibt abwechselnd nach vorn, links, rechts · ${num(building.passed)} verteilt`;
  } else if (building?.type === 'merger') {
    tileName.textContent = 'Zusammenführer';
    tileDetail.textContent = `Nimmt von drei Seiten, gibt nach ${DIR_NAMES[building.dir]} ab · ${num(building.passed)} durch`;
  } else if (building?.type === 'constructor') {
    const recipe = CONSTRUCTOR_RECIPES[building.recipe];
    tileName.textContent = `Konstruktor · ${ITEMS[recipe.makes].name}`;
    const have = Object.entries(recipe.needs)
      .map(([k, n]) => `${ITEMS[k].name} ${Math.min(building.input[k] ?? 0, n)}/${n}`)
      .join(' · ');
    const state = building.refused ? `Nimmt kein ${ITEMS[building.refused].name} an` : MACHINE_TEXT[building.state];
    tileDetail.textContent = `${state} · ${have} · ${building.made} hergestellt${tool ? '' : ' · Klick: Rezept'}`;
  } else if (isMachine(building)) {
    const recipe = RECIPES[building.type];
    tileName.textContent = BUILDINGS[building.type].name;
    let state = MACHINE_TEXT[building.state];
    if (building.current) state += `: ${ITEMS[building.current].name} → ${ITEMS[recipe.makes[building.current]].name}`;
    else if (building.refused) state = `Nimmt kein ${ITEMS[building.refused].name} an`;
    else state += ` · nimmt ${itemList(Object.keys(recipe.makes))}`;
    tileDetail.textContent = `${state} · ${building.made} hergestellt`;
  } else if (building?.type === 'storage') {
    tileName.textContent = 'Lager';
    tileDetail.textContent = building.received
      ? `${num(building.received)} eingelagert · zuletzt ${ITEMS[building.last].name}`
      : 'Nimmt alles von Bändern auf allen Seiten';
  } else if (tile.ore) {
    tileName.textContent = ORES[tile.ore].name;
    tileDetail.textContent = `${tile.amount.toLocaleString('de-DE')} Einheiten · Feld ${tile.x}, ${tile.z}`;
  } else {
    tileName.textContent = terrain.name;
    tileDetail.textContent = `${terrain.buildable ? 'Bebaubar' : 'Nicht bebaubar'} · Feld ${tile.x}, ${tile.z}`;
  }
  if (check && !check.ok && check.reason) tileDetail.textContent = check.reason;
}

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let pointerInside = false;
const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.4);
const planeHit = new THREE.Vector3();

function setPointer(e) {
  const rect = canvas.getBoundingClientRect();
  pointer.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1);
}

// The tile under the pointer, or null.
function pickTile() {
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObject(meshes.tiles, false)[0];
  if (hit) return world.tiles[hit.instanceId];
  // The ray slipped through the thin gap between two tiles: pick by grid cell instead.
  const point = raycaster.ray.intersectPlane(groundPlane, planeHit);
  const offset = (MAP_SIZE * TILE) / 2;
  const x = point && Math.floor((point.x + offset) / TILE);
  const z = point && Math.floor((point.z + offset) / TILE);
  const inside = point && x >= 0 && z >= 0 && x < MAP_SIZE && z < MAP_SIZE;
  return inside ? world.at(x, z) : null;
}

canvas.addEventListener('pointermove', (e) => {
  if (!e.isPrimary) return;
  setPointer(e);
  pointerInside = true;
  if (dragging) buildAlong(pickTile());
});
canvas.addEventListener('pointerleave', () => {
  pointerInside = false;
  showTile(null);
});

// --- Building -------------------------------------------------------------

let tool = null; // a building type, 'remove' or null
let dir = 1; // direction for the next building, see DIRS
let hovered = null;
let dragging = false;
let lastTile = null;
let shapesDirty = false;

const toolButtons = document.querySelectorAll('.tool[data-tool]');
const help = document.getElementById('help');
const HELP = {
  none: [['Linke Maus', 'verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['WASD', 'bewegen'], ['1–8', 'bauen'], ['X', 'abreißen'], ['T', 'Forschung']],
  drill: [['Klick', 'Bohrer auf Erz setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  belt: [['Ziehen', 'Band verlegen'], ['Über altes Band ziehen', 'aufrüsten'], ['R', 'drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  storage: [['Klick', 'Lager setzen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  furnace: [['Klick', 'Schmelzofen setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  assembler: [['Klick', 'Presse setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  splitter: [['Klick', 'Verteiler setzen'], ['R', 'drehen: Eingang hinten'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  merger: [['Klick', 'Zusammenführer setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  constructor: [['Klick', 'Konstruktor setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Ohne Werkzeug klicken', 'Rezept wählen']],
  remove: [['Klick / Ziehen', 'abreißen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
};

function renderHelp() {
  help.innerHTML = HELP[tool ?? 'none'].map(([k, t]) => `<span><kbd>${k}</kbd> ${t}</span>`).join('');
}

function setTool(next) {
  if (next && BUILDINGS[next] && !factory.progress.unlocked.has(next)) {
    showToast(`${BUILDINGS[next].name} gesperrt`, `Erforsche ${unlockHint(next)}`);
    return;
  }
  tool = next === tool ? null : next;
  for (const b of toolButtons) b.setAttribute('aria-pressed', String(b.dataset.tool === tool));
  // While a tool is active, the left mouse button and a single finger build
  // instead of moving the map.
  rig.controls.mouseButtons.LEFT = tool ? null : THREE.MOUSE.PAN;
  rig.controls.mouseButtons.MIDDLE = tool ? THREE.MOUSE.PAN : THREE.MOUSE.DOLLY;
  rig.controls.touches.ONE = tool ? null : THREE.TOUCH.PAN;
  renderHelp();
  showTile(hovered);
}

function canBuild(tile) {
  const existing = factory.get(tile);
  // Dragging a belt over a belt just turns it.
  if (tool === 'belt' && existing?.type === 'belt') return { ok: true, reason: '' };
  return factory.canPlace(tool, tile);
}

function rotate() {
  const building = !tool && hovered && factory.get(hovered);
  if (building) {
    factory.setDir(building, (building.dir + 1) % 4);
    shapesDirty = true;
  } else {
    dir = (dir + 1) % 4;
  }
  showTile(hovered);
}

function buildAt(tile) {
  if (!tile) return;
  if (tool === 'remove') {
    const removed = factory.remove(tile);
    if (removed) meshes.setDecorHidden(tile.z * world.size + tile.x, false);
    if (removed && removed === selected) openRecipes(null);
  } else {
    const existing = factory.get(tile);
    if (tool === 'belt' && existing?.type === 'belt') {
      factory.setDir(existing, dir);
      factory.upgradeBelt(existing);
    } else if (factory.place(tool, tile, dir)) meshes.setDecorHidden(tile.z * world.size + tile.x, true);
  }
  shapesDirty = true;
}

// Belts follow the drag: each step turns the previous belt towards the new one.
function buildAlong(tile) {
  if (!tile || tile === lastTile) return;
  if (!lastTile || tool !== 'belt') {
    buildAt(tile);
    lastTile = tile;
    return;
  }
  while (lastTile !== tile) {
    const dx = Math.sign(tile.x - lastTile.x);
    const dz = dx ? 0 : Math.sign(tile.z - lastTile.z);
    dir = DIRS.findIndex((d) => d.x === dx && d.z === dz);
    const prev = factory.get(lastTile);
    if (prev?.type === 'belt') factory.setDir(prev, dir);
    lastTile = world.at(lastTile.x + dx, lastTile.z + dz);
    buildAt(lastTile);
  }
}

canvas.addEventListener('pointerdown', (e) => {
  if (!e.isPrimary) {
    // A second finger means pinch or rotate, not building.
    dragging = false;
    return;
  }
  if (e.button === 0) downAt = { x: e.clientX, y: e.clientY };
  if (!tool || e.button !== 0) return;
  setPointer(e);
  dragging = true;
  lastTile = null;
  buildAlong(pickTile());
});
// A click (no drag) on a constructor without a tool opens its recipes.
let downAt = null;
window.addEventListener('pointerup', (e) => {
  dragging = false;
  if (!downAt || e.target !== canvas) return;
  const moved = Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y);
  downAt = null;
  if (tool || moved > 6) return;
  setPointer(e);
  const tile = pickTile();
  const b = tile && factory.get(tile);
  openRecipes(b?.type === 'constructor' ? b : null);
});

for (const b of toolButtons) b.addEventListener('click', () => setTool(b.dataset.tool));
document.getElementById('rotate').addEventListener('click', rotate);

window.addEventListener('keydown', (e) => {
  if (e.repeat && e.key.toLowerCase() !== 'r') return;
  const key = e.key.toLowerCase();
  if (key === 't') return openResearch(researchEl.hidden);
  if (key === 'escape' && !researchEl.hidden) return openResearch(false);
  if (key === 'escape' && selected && !tool) return openRecipes(null);
  if (!researchEl.hidden) return;
  const numbered = ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'constructor'][Number(key) - 1];
  if (numbered) setTool(numbered);
  else if (key === 'x' || key === 'delete') setTool('remove');
  else if (key === 'r') rotate();
  else if (key === 'escape' && tool) setTool(tool);
});

function updateHover() {
  if (!pointerInside) return;
  showTile(pickTile());
}

function resize() {
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);

document.getElementById('new-map').addEventListener('click', () => {
  loadWorld(Math.floor(Math.random() * 99999));
});

// The simulation runs in fixed steps so belts behave the same at any frame rate.
const STEP = 1 / 60;
let pending = 0;
let legendTimer = 0;

const timer = new THREE.Timer();
renderer.setAnimationLoop(() => {
  timer.update();
  const dt = Math.min(timer.getDelta(), 0.25);
  rig.update(dt);
  sea.update(timer.getElapsed());
  pending += dt;
  while (pending >= STEP) {
    factory.tick(STEP);
    pending -= STEP;
  }
  if (shapesDirty) {
    factoryView.rebuild(factory);
    shapesDirty = false;
  }
  factoryView.update(dt, timer.getElapsed(), factory);
  legendTimer += dt;
  if (legendTimer > 0.5) {
    legendTimer = 0;
    renderLegend();
    renderProgress();
  }
  updateHover();
  renderer.render(scene, camera);
});

buildTree();
loadWorld(4711);
renderHelp();
resize();

// Handle for poking at the game from the browser console while developing.
if (import.meta.env.DEV) window.bolla = { camera, rig, refresh: () => (shapesDirty = true), get world() { return world; }, get factory() { return factory; } };
