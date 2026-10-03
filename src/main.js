import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
import { createFactory, DIRS, DIR_NAMES, BUILDINGS, ITEMS, RECIPES, isMachine } from './factory.js';
import { RESEARCH } from './research.js';
import { createResearchView } from './researchView.js';
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
  renderLegend();
  researchView.reset();
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

const storeList = document.getElementById('store');
const toast = document.getElementById('toast');
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

const researchView = createResearchView({
  getFactory: () => factory,
  onResearch(r) {
    if (r.goal) showToast('Spielziel geschafft!', 'Deine Fabrik schmilzt, presst und liefert. Glückwunsch!');
    else showToast(`Erforscht: ${r.name}`, r.desc);
    renderProgress();
  },
});

function renderProgress() {
  researchView.update();

  const kept = Object.entries(factory.stored).filter(([, n]) => n > 0);
  storeList.innerHTML = kept.length
    ? kept
        .map(([k, n]) => `<li><span class="swatch" style="--c:${hex(ITEMS[k].color)}"></span><span class="name">${ITEMS[k].name}</span><span class="num">${num(n)}</span></li>`)
        .join('')
    : '<li class="empty">Noch leer. Lege ein Band in ein Lager.</li>';

  for (const b of toolButtons) {
    const type = b.dataset.tool;
    if (!BUILDINGS[type]) continue;
    const locked = !factory.research.unlocked.has(type);
    b.classList.toggle('locked', locked);
    b.setAttribute('aria-disabled', String(locked));
    b.title = locked ? `Noch gesperrt: ${unlockHint(type)}` : BUILDINGS[type].name;
  }
}

function unlockHint(type) {
  const r = RESEARCH.find((x) => x.unlocks?.includes(type));
  return r ? `im Forschungsbaum „${r.name}“ erforschen` : '';
}

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
  marker.visible = !tool;
  marker.position.set(tile.position.x, Math.max(tile.height, 0.28) + 0.03, tile.position.z);
  ghost.show(tool, tile, tool === 'remove' ? building?.dir ?? 0 : dir, check?.ok);

  const terrain = TERRAIN[tile.terrain];
  if (building?.type === 'drill') {
    tileName.textContent = `Bohrer · ${ORES[tile.ore].name}`;
    tileDetail.textContent = `${STATE_TEXT[building.state]} · ${building.mined} abgebaut · Rest ${tile.amount.toLocaleString('de-DE')}`;
  } else if (building?.type === 'belt') {
    tileName.textContent = 'Förderband';
    tileDetail.textContent = `Richtung ${DIR_NAMES[building.dir]} · ${building.items.length} Teile drauf`;
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
  none: [['Linke Maus', 'verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['WASD', 'bewegen'], ['1–5', 'bauen'], ['X', 'abreißen'], ['T', 'Forschung']],
  drill: [['Klick', 'Bohrer auf Erz setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  belt: [['Ziehen', 'Band verlegen'], ['R', 'drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  storage: [['Klick', 'Lager setzen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  furnace: [['Klick', 'Schmelzofen setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  assembler: [['Klick', 'Presse setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  remove: [['Klick / Ziehen', 'abreißen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
};

function renderHelp() {
  help.innerHTML = HELP[tool ?? 'none'].map(([k, t]) => `<span><kbd>${k}</kbd> ${t}</span>`).join('');
}

function setTool(next) {
  if (next && BUILDINGS[next] && !factory.research.unlocked.has(next)) {
    showToast(`${BUILDINGS[next].name} gesperrt`, unlockHint(next));
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
    if (factory.remove(tile)) meshes.setDecorHidden(tile.z * world.size + tile.x, false);
  } else {
    const existing = factory.get(tile);
    if (tool === 'belt' && existing?.type === 'belt') factory.setDir(existing, dir);
    else if (factory.place(tool, tile, dir)) meshes.setDecorHidden(tile.z * world.size + tile.x, true);
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
  if (!tool || e.button !== 0) return;
  setPointer(e);
  dragging = true;
  lastTile = null;
  buildAlong(pickTile());
});
window.addEventListener('pointerup', () => {
  dragging = false;
});

for (const b of toolButtons) b.addEventListener('click', () => setTool(b.dataset.tool));
document.getElementById('rotate').addEventListener('click', rotate);

window.addEventListener('keydown', (e) => {
  if (e.repeat && e.key.toLowerCase() !== 'r') return;
  const key = e.key.toLowerCase();
  const numbered = ['drill', 'belt', 'storage', 'furnace', 'assembler'][Number(key) - 1];
  if (numbered) setTool(numbered);
  else if (key === 'x' || key === 'delete') setTool('remove');
  else if (key === 'r') rotate();
  else if (key === 't') researchView.toggle();
  else if (key === 'escape' && researchView.isOpen) researchView.close();
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

loadWorld(4711);
renderHelp();
resize();

// Handle for poking at the game from the browser console while developing.
if (import.meta.env.DEV) window.bolla = { camera, rig, refresh: () => (shapesDirty = true), get world() { return world; }, get factory() { return factory; } };
