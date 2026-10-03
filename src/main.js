import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
import { createFactory, DIRS, DIR_NAMES, BUILDINGS, ITEMS, RECIPES, CONSTRUCTOR_RECIPES, isMachine } from './factory.js';
import { RESEARCH } from './research.js';
import { createResearchView } from './researchView.js';
import { createFactoryView, createGhost } from './buildings.js';
import { SCENARIOS, scenarioById, createMissions, starsFor, loadRecords, saveRecord } from './scenarios.js';
import { createMissionView, clock } from './missionView.js';
import { createAudio } from './audio.js';
import { createEffects } from './effects.js';
import { createDayNight } from './daynight.js';
import './style.css';

const canvas = document.getElementById('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.92;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xcfe3ea, 110, 260);
// Soft reflections for water, crystals and metal ore.
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.35;

const camera = new THREE.PerspectiveCamera(45, 1, 0.1, 400);
const rig = createCameraRig(camera, canvas, (MAP_SIZE * TILE) / 2);

const hemi = new THREE.HemisphereLight(0xd6ecff, 0x5a4a30, 0.85);
scene.add(hemi);
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

const audio = createAudio();
const effects = createEffects({
  // A soft ding when a machine nearby finishes a part.
  onMade(b) {
    if (b.type === 'drill') return;
    const s = audio.spot(b.tile.position, rig.controls.target, camRight, zoom);
    audio.play.ding(s.pan, s.level);
  },
});
scene.add(effects.group);
const dayNight = createDayNight({ scene, renderer, sun, hemi });
let zoom = 40; // camera distance to the point it looks at
const camRight = new THREE.Vector3();

let world;
let meshes;
let factory;
let scenario; // the map being played, see scenarios.js
let missions = null; // mission progress, null in the free game

// Start a map: the free game with a random (or given) seed, or a scenario.
function startGame(next, seed = Math.floor(Math.random() * 99999)) {
  scenario = next;
  if (scenario.free) loadWorld(seed);
  else loadWorld(scenario.seed, scenario);
}

function loadWorld(seed, mapScenario = null) {
  if (meshes) {
    scene.remove(meshes.group);
    meshes.group.traverse((o) => {
      o.geometry?.dispose();
      o.material?.dispose();
    });
  }
  world = generateWorld(seed, mapScenario?.map);
  meshes = buildWorldMeshes(world);
  scene.add(meshes.group);
  factory = createFactory(world, { start: mapScenario?.start });
  missions = mapScenario ? createMissions(mapScenario, factory) : null;
  factoryView.clear();
  effects.clear();
  shapesDirty = true;
  if (tool) setTool(tool);
  document.getElementById('seed').textContent = mapScenario ? mapScenario.name : `#${seed}`;
  document.getElementById('new-map').hidden = !!mapScenario;
  renderLegend();
  researchView.setEnabled(!missions);
  if (missions) missionView.render();
  else researchView.reset();
  openRecipes(null);
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
    const c = counts[key];
    if (!c) continue;
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
    audio.play.success();
    if (r.id === 'firstFactory') showToast('Spielziel geschafft!', 'Deine Fabrik schmilzt und presst. Weiter geht es mit dem Konstruktor!');
    else if (r.goal) showToast('Meisterfabrik!', 'Du hast den ganzen Forschungsbaum geschafft. Glückwunsch!');
    else showToast(`Erforscht: ${r.name}`, r.desc);
    renderProgress();
  },
});

const missionView = createMissionView({ panel: document.getElementById('goal'), getGame: () => ({ scenario, missions, factory }) });

function renderProgress() {
  if (missions) missionView.update();
  else researchView.update();

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
  if (missions) {
    const m = scenario.missions.find((x) => x.reward.unlocks?.includes(type));
    return m ? `Belohnung der Mission „${m.name}“` : 'auf dieser Karte nicht verfügbar';
  }
  const r = RESEARCH.find((x) => x.unlocks?.includes(type));
  return r ? `im Forschungsbaum „${r.name}“ erforschen` : '';
}

// --- Missions, map selection and the win screen ------------------------------

function checkMissions() {
  const done = missions?.check();
  if (!done) return;
  renderProgress();
  if (missions.current) {
    audio.play.success();
    showToast(`Mission geschafft: ${done.name}`, `Belohnung: ${done.reward.text}`);
  } else {
    audio.play.fanfare();
    effects.fireworks(rig.controls.target, zoom);
    showWin();
  }
}

const mapsMenu = document.getElementById('maps');
const mapsList = document.getElementById('maps-list');
const winMenu = document.getElementById('win');
const oreSwatches = (s) =>
  Object.keys(s.map?.ores ?? ORES)
    .map((k) => `<span class="ore-chip"><span class="swatch" style="--c:${hex(ORES[k].color)}"></span>${ORES[k].name}</span>`)
    .join('');
const starText = (n) => '★'.repeat(n) + '☆'.repeat(3 - n);

function openMaps() {
  const records = loadRecords();
  winMenu.hidden = true;
  mapsList.innerHTML = SCENARIOS.map((s) => {
    const r = records[s.id];
    const meta = s.free
      ? 'Forschungsbaum · Zufallskarte'
      : `${s.missions.length} Missionen · ${'●'.repeat(s.level)}${'○'.repeat(4 - s.level)}${r ? ` · <span class="best">${starText(r.stars)} ${clock(r.time)}</span>` : ''}`;
    return `<button type="button" class="map-card${s === scenario ? ' current' : ''}" data-map="${s.id}">
      <span class="map-name">${s.name}${s === scenario ? ' <span class="tag">Läuft</span>' : ''}</span>
      <span class="map-meta">${meta}</span>
      <span class="map-desc">${s.desc}</span>
      <span class="map-ores">${oreSwatches(s)}</span>
    </button>`;
  }).join('');
  mapsMenu.hidden = false;
}

function showWin() {
  const seconds = missions.finishedAt;
  const stars = starsFor(scenario, seconds);
  const best = saveRecord(scenario.id, stars, seconds);
  const next = SCENARIOS[SCENARIOS.indexOf(scenario) + 1];
  document.getElementById('win-title').textContent = scenario.name;
  document.getElementById('win-stars').textContent = starText(stars);
  document.getElementById('win-time').textContent =
    `Zeit ${clock(seconds)} · drei Sterne unter ${scenario.par} Minuten · Bestzeit ${clock(best.time)}`;
  const nextBtn = document.getElementById('win-next');
  nextBtn.hidden = !next;
  nextBtn.onclick = () => {
    winMenu.hidden = true;
    startGame(next);
  };
  winMenu.hidden = false;
}

mapsList.addEventListener('click', (e) => {
  const card = e.target.closest('[data-map]');
  if (!card) return;
  mapsMenu.hidden = true;
  startGame(scenarioById(card.dataset.map));
});
for (const menu of [mapsMenu, winMenu]) {
  menu.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]') || e.target === menu) menu.hidden = true;
    if (e.target.closest('[data-maps]')) openMaps();
  });
}
document.getElementById('goal').addEventListener('click', (e) => e.target.closest('[data-maps]') && openMaps());
document.getElementById('maps-open').addEventListener('click', openMaps);
const menuOpen = () => !mapsMenu.hidden || !winMenu.hidden;

// --- Sound and daylight settings ---------------------------------------------

const settingsPanel = document.getElementById('settings');
const settingsOpen = document.getElementById('settings-open');
const clockLabel = document.getElementById('clock');
const clockIcon = document.getElementById('clock-icon');
const volInput = document.getElementById('vol');
const musicInput = document.getElementById('music');
const muteInput = document.getElementById('mute');
const dayModes = document.querySelectorAll('#daymode [data-mode]');

function renderSettings() {
  volInput.value = audio.settings.volume;
  musicInput.value = audio.settings.music;
  muteInput.checked = audio.settings.muted;
  for (const b of dayModes) b.setAttribute('aria-checked', String(b.dataset.mode === dayNight.mode));
}
function toggleSettings(open = settingsPanel.hidden) {
  settingsPanel.hidden = !open;
  settingsOpen.setAttribute('aria-expanded', String(open));
  if (open) renderSettings();
}
function toggleMute() {
  audio.set({ muted: !audio.settings.muted });
  renderSettings();
  showToast(audio.settings.muted ? 'Ton aus' : 'Ton an', 'Taste U schaltet um.');
}
settingsOpen.addEventListener('click', () => toggleSettings());
volInput.addEventListener('input', () => audio.set({ volume: Number(volInput.value), muted: false }));
volInput.addEventListener('change', () => {
  renderSettings();
  audio.play.build('drill');
});
musicInput.addEventListener('input', () => audio.set({ music: Number(musicInput.value) }));
muteInput.addEventListener('change', () => audio.set({ muted: muteInput.checked }));
for (const b of dayModes) {
  b.addEventListener('click', () => {
    dayNight.setMode(b.dataset.mode);
    renderSettings();
  });
}
document.getElementById('skip-time').addEventListener('click', () => dayNight.skipAhead());

// --- Constructor recipes ----------------------------------------------------

const recipePanel = document.getElementById('recipe');
const recipeList = document.getElementById('recipe-list');
let selected = null; // the constructor whose recipe panel is open

const needsText = (needs) =>
  Object.entries(needs)
    .map(([k, n]) => `${n} ${ITEMS[k].name}`)
    .join(' + ');

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
    tileName.textContent = 'Förderband';
    tileDetail.textContent = `Richtung ${DIR_NAMES[building.dir]} · ${building.items.length} Teile drauf`;
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
    tileDetail.textContent = `${state} · ${have}${tool ? '' : ' · Klick: Rezept'}`;
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
  none: [['Linke Maus', 'verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['WASD', 'bewegen'], ['1–8', 'bauen'], ['X', 'abreißen'], ['T', 'Forschung'], ['M', 'Karten'], ['N', 'Tag/Nacht'], ['U', 'Ton']],
  drill: [['Klick', 'Bohrer auf Erz setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  belt: [['Ziehen', 'Band verlegen'], ['R', 'drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
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
  if (next && BUILDINGS[next] && !factory.research.unlocked.has(next)) {
    audio.play.deny();
    showToast(`${BUILDINGS[next].name} gesperrt`, unlockHint(next));
    return;
  }
  tool = next === tool ? null : next;
  audio.play.click();
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
  audio.play.rotate();
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
    if (removed) {
      meshes.setDecorHidden(tile.z * world.size + tile.x, false);
      audio.play.remove();
      effects.remove(tile, removed.type);
    }
    if (removed && removed === selected) openRecipes(null);
  } else {
    const existing = factory.get(tile);
    if (tool === 'belt' && existing?.type === 'belt') {
      if (existing.dir !== dir) audio.play.rotate();
      factory.setDir(existing, dir);
    } else if (factory.place(tool, tile, dir)) {
      meshes.setDecorHidden(tile.z * world.size + tile.x, true);
      audio.play.build(tool);
      effects.build(tile, tool !== 'belt');
    } else if (!lastTile) audio.play.deny();
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
  if (menuOpen()) {
    if (key === 'escape' || key === 'm') mapsMenu.hidden = winMenu.hidden = true;
    return;
  }
  if (key === 'm') return openMaps();
  if (key === 'u') return toggleMute();
  if (key === 'n') return dayNight.skipAhead();
  if (key === 't' && missions) return showToast('Missionskarte', 'Hier schalten Missionen neue Gebäude frei, nicht der Forschungsbaum.');
  const numbered = ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'constructor'][Number(key) - 1];
  if (numbered) setTool(numbered);
  else if (key === 'x' || key === 'delete') setTool('remove');
  else if (key === 'r') rotate();
  else if (key === 't') researchView.toggle();
  else if (key === 'escape' && researchView.isOpen) researchView.close();
  else if (key === 'escape' && !settingsPanel.hidden) toggleSettings(false);
  else if (key === 'escape' && tool) setTool(tool);
  else if (key === 'escape' && selected) openRecipes(null);
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
  effects.resize(h * renderer.getPixelRatio(), camera.fov);
}
window.addEventListener('resize', resize);

document.getElementById('new-map').addEventListener('click', () => startGame(scenarioById('free')));

// The simulation runs in fixed steps so belts behave the same at any frame rate.
const STEP = 1 / 60;
let pending = 0;
let legendTimer = 0;
let soundTimer = 0;

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
    dayNight.rebuild(factory);
    shapesDirty = false;
  }
  const elapsed = timer.getElapsed();
  const focus = rig.controls.target;
  zoom = camera.position.distanceTo(focus);
  camRight.setFromMatrixColumn(camera.matrixWorld, 0);
  dayNight.update(dt, elapsed, focus, camera, factory);
  factoryView.setNight(dayNight.night);
  factoryView.update(dt, elapsed, factory);
  effects.update(dt, factory, focus, zoom, dayNight.night);
  audio.setNight(dayNight.night);
  soundTimer += dt;
  if (soundTimer > 0.1) {
    soundTimer = 0;
    audio.updateMachines(factory, focus, camRight, zoom);
    clockLabel.textContent = dayNight.clock();
    clockIcon.textContent = dayNight.night > 0.5 ? '☾' : '☀';
  }
  legendTimer += dt;
  if (legendTimer > 0.5) {
    legendTimer = 0;
    renderLegend();
    checkMissions();
    renderProgress();
  }
  updateHover();
  renderer.render(scene, camera);
});

startGame(scenarioById('free'), 4711);
renderHelp();
resize();
openMaps();

// Handle for poking at the game from the browser console while developing.
if (import.meta.env.DEV) window.bolla = { camera, rig, renderer, scene, startGame, dayNight, effects, audio, checkMissions, refresh: () => (shapesDirty = true), get world() { return world; }, get factory() { return factory; }, get missions() { return missions; } };
