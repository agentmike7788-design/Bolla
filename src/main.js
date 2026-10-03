import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
import { createFactory, DIRS, DIR_NAMES, BUILDINGS, ITEMS, RECIPES, CONSTRUCTOR_RECIPES, REFINERY_RECIPES, recipesOf, isMachine, usesPower, POWER_USE, POWER_SPEED, POWER_OUTPUT, WIRE_REACH, PUMP_RATE } from './factory.js';
import { RESEARCH } from './research.js';
import { createResearchView } from './researchView.js';
import { createFactoryView, createGhost } from './buildings.js';
import { SCENARIOS, scenarioById, createMissions, starsFor, loadRecords, saveRecord } from './scenarios.js';
import { createMissionView, clock } from './missionView.js';
import { createAudio } from './audio.js';
import { createEffects } from './effects.js';
import { createDayNight } from './daynight.js';
import { listSaves, readSave, writeSave, deleteSave, exportSave, importSave, newSaveId, SAVE_VERSION } from './save.js';
import { createMenu } from './menu.js';
import { createTutorial, tutorialDone, TUTORIAL_SEED } from './tutorial.js';
import './style.css';

const canvas = document.getElementById('scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
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

let slotId = null; // save slot of the running game, see save.js
let savedOnce = false; // an empty new game is only saved once something happened

// Start a map: the free game with a random (or given) seed, or a scenario.
function startGame(next, seed = Math.floor(Math.random() * 99999)) {
  leaveGame();
  tutorial.stop();
  scenario = next;
  slotId = newSaveId();
  savedOnce = false;
  if (scenario.free) loadWorld(seed);
  else loadWorld(scenario.seed, scenario);
  rig.controls.target.set(0, 0, 0);
  camera.position.set(0, 34, 34);
}

function loadWorld(seed, mapScenario = null, saved = null) {
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
  if (saved) {
    factory.load(saved.factory, saved.v);
    missions?.load(saved.missions);
    for (const b of factory.buildings.values()) meshes.setDecorHidden(b.index, true);
  }
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
    else if (r.id === 'oilAge') showToast('Ölzeitalter!', 'Du hast den ganzen Forschungsbaum geschafft. Glückwunsch!');
    else if (r.goal) showToast('Meisterfabrik!', 'Schaltkreise, Stahl und Zahnräder in Massen. Als Nächstes wartet das Öl.');
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

  renderPower();
  renderOil();

  // The oil tools show up once one of them is unlocked.
  const oil = [...toolButtons].some((b) => b.dataset.group === 'oil' && factory.research.unlocked.has(b.dataset.tool));
  for (const b of toolButtons) {
    const type = b.dataset.tool;
    if (!BUILDINGS[type]) continue;
    b.hidden = b.dataset.group === 'oil' && !oil;
    const locked = !factory.research.unlocked.has(type);
    b.classList.toggle('locked', locked);
    b.setAttribute('aria-disabled', String(locked));
    b.title = locked ? `Noch gesperrt: ${unlockHint(type)}` : BUILDINGS[type].name;
  }
}

const powerPanel = document.getElementById('power');
const powerState = document.getElementById('power-state');
const powerFill = document.getElementById('power-fill');
const powerText = document.getElementById('power-text');
const mw = (n) => `${n.toLocaleString('de-DE', { maximumFractionDigits: 1 })} MW`;

// Shown once power is unlocked: how much of the plants' output the machines use.
function renderPower() {
  const s = factory.powerSummary();
  const unlocked = factory.research.unlocked.has('power');
  powerPanel.hidden = !unlocked && !s.nets;
  if (powerPanel.hidden) return;
  const out = s.consumers > 0 && s.capacity <= 0;
  const short = !out && s.demand > s.capacity;
  powerPanel.classList.toggle('out', out);
  powerPanel.classList.toggle('short', short);
  powerFill.style.width = `${s.capacity ? Math.min(100, (s.demand / s.capacity) * 100) : out ? 100 : 0}%`;
  if (!s.nets) {
    powerState.textContent = 'kein Netz';
    powerText.textContent = 'Kraftwerk bauen, Kohle hineinleiten und Masten bis zu den Maschinen setzen.';
  } else if (out) {
    powerState.textContent = s.plants ? 'keine Kohle' : 'kein Kraftwerk';
    powerText.textContent = s.plants ? 'Die Kraftwerke brauchen Kohle vom Band. Die Maschinen am Netz stehen still.' : 'Im Netz fehlt ein Kraftwerk. Die Maschinen am Netz stehen still.';
  } else {
    powerState.textContent = short ? `Mangel · ${Math.round(s.satisfaction * 100)} %` : `${Math.round((s.demand / Math.max(s.capacity, 0.001)) * 100)} % Last`;
    powerText.textContent = `Bedarf ${mw(s.demand)} von ${mw(s.capacity)} · ${s.consumers} Maschinen am Netz · ${s.fuel} Kohle im Kraftwerk`;
  }
}

const oilPanel = document.getElementById('oil');
const oilState = document.getElementById('oil-state');
const oilFill = document.getElementById('oil-fill');
const oilText = document.getElementById('oil-text');

// Shown once pumps are unlocked: how full the pipes are and how much flows.
function renderOil() {
  const s = factory.oilSummary();
  oilPanel.hidden = !factory.research.unlocked.has('pump') && !s.nets;
  if (oilPanel.hidden) return;
  oilFill.style.width = `${s.capacity ? (s.amount / s.capacity) * 100 : 0}%`;
  if (!s.pumps) {
    oilState.textContent = 'keine Pumpe';
    oilText.textContent = 'Ölpumpe auf ein schwarzes Ölfeld setzen, Strommast daneben, Rohre zur Raffinerie.';
  } else if (!s.working && s.amount < 1) {
    oilState.textContent = 'steht still';
    oilText.textContent = 'Die Pumpen brauchen Strom: Kraftwerk und Strommast in ihre Nähe.';
  } else {
    oilState.textContent = `${num(Math.round(s.rate * 60))}/min`;
    oilText.textContent = `${num(Math.round(s.amount))} von ${num(s.capacity)} Öl in den Rohren · ${s.working} von ${s.pumps} Pumpen laufen · ${s.refineries} Raffinerien`;
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
  if (menu.isOpen) closeMenu();
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

// --- Graphics settings --------------------------------------------------------

const GRAPHICS_KEY = 'bolla.graphics';
const MOBILE = matchMedia('(pointer: coarse)').matches;
const graphics = { shadows: 'high', resolution: 'high', particles: true, autosave: 60 };
try {
  Object.assign(graphics, JSON.parse(localStorage.getItem(GRAPHICS_KEY)));
} catch {}

function applyGraphics() {
  sun.castShadow = graphics.shadows !== 'off';
  const size = (graphics.shadows === 'high' ? 4096 : 2048) / (MOBILE ? 2 : 1);
  if (sun.shadow.mapSize.x !== size) {
    sun.shadow.map?.dispose();
    sun.shadow.map = null;
    sun.shadow.mapSize.set(size, size);
  }
  const ratio = { low: 0.75, normal: 1.25, high: 2 }[graphics.resolution] ?? 2;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, ratio));
  effects.group.visible = graphics.particles;
  if (!graphics.particles) effects.clear();
}

function setGraphics(changes) {
  Object.assign(graphics, changes);
  try {
    localStorage.setItem(GRAPHICS_KEY, JSON.stringify(graphics));
  } catch {}
  applyGraphics();
  resize();
}

const clockLabel = document.getElementById('clock');
const clockIcon = document.getElementById('clock-icon');

function toggleMute() {
  audio.set({ muted: !audio.settings.muted });
  menu.refresh();
  showToast(audio.settings.muted ? 'Ton aus' : 'Ton an', 'Taste U schaltet um.');
}

// --- Saving and loading -------------------------------------------------------

const savedLabel = document.getElementById('saved');
const thumbCanvas = Object.assign(document.createElement('canvas'), { width: 240, height: 135 });
let autosaveTimer = 0;
let savedTimer = 0;

const gameName = () => (scenario.free ? `Freies Spiel #${world.seed}` : scenario.name);

// A small picture of the map for the save list, taken right after a render.
function thumbnail() {
  renderer.render(scene, camera);
  const ctx = thumbCanvas.getContext('2d');
  const src = renderer.domElement;
  // Cut the middle of the screen to 16:9.
  const w = Math.min(src.width, (src.height * 16) / 9);
  const h = (w * 9) / 16;
  ctx.drawImage(src, (src.width - w) / 2, (src.height - h) / 2, w, h, 0, 0, thumbCanvas.width, thumbCanvas.height);
  return thumbCanvas.toDataURL('image/jpeg', 0.72);
}

// Writes the running game to its slot. `manual` saves even an untouched map.
function saveGame({ manual = false, quiet = false } = {}) {
  if (!factory || !slotId) return false;
  if (!manual && !savedOnce && !factory.buildings.size) return false;
  const data = {
    v: SAVE_VERSION,
    scenario: scenario.id,
    seed: world.seed,
    factory: factory.save(),
    missions: missions?.save() ?? null,
    dayTime: dayNight.time,
    tutorial: tutorial.save(),
    camera: { position: camera.position.toArray(), target: rig.controls.target.toArray() },
  };
  const meta = { id: slotId, name: gameName(), scenario: scenario.id, savedAt: Date.now(), playTime: factory.time, buildings: factory.buildings.size, thumb: thumbnail() };
  const ok = writeSave(meta, data);
  if (!ok) {
    showToast('Speichern fehlgeschlagen', 'Kein Platz mehr im Browser. Lösche alte Spielstände unter Laden.');
    return false;
  }
  savedOnce = true;
  autosaveTimer = 0;
  savedLabel.textContent = '✓ Gespeichert';
  savedLabel.classList.add('show');
  savedTimer = 2.5;
  if (manual && !quiet) showToast('Gespeichert', `${meta.name} · in diesem Browser`);
  return true;
}

// Before another game replaces the running one.
function leaveGame() {
  if (factory && !inTitle) saveGame();
}

function loadGame(id) {
  const data = readSave(id);
  const next = data && scenarioById(data.scenario);
  if (!next) {
    showToast('Laden fehlgeschlagen', 'Der Spielstand ist beschädigt.');
    return false;
  }
  leaveGame();
  scenario = next;
  slotId = id;
  savedOnce = true;
  loadWorld(data.seed, next.free ? null : next, data);
  dayNight.setTime(data.dayTime ?? 0.02);
  if (data.camera) {
    camera.position.fromArray(data.camera.position);
    rig.controls.target.fromArray(data.camera.target);
  }
  if (data.tutorial != null) tutorial.start(data.tutorial);
  else tutorial.stop();
  return true;
}

// --- Title screen and pause menu ----------------------------------------------

const app = document.getElementById('app');
let inTitle = true;

function closeMenu() {
  menu.close();
  inTitle = false;
  app.classList.remove('in-title');
  rig.setLocked(false);
}

const menu = createMenu({
  root: document.getElementById('menu'),
  audio,
  dayNight,
  graphics,
  onGraphics: setGraphics,
  actions: {
    currentId: () => slotId,
    gameName: () => gameName(),
    continueGame() {
      const latest = listSaves()[0];
      if (latest && latest.id !== slotId && !loadGame(latest.id)) return;
      closeMenu();
    },
    newGame: openMaps,
    tutorial: startTutorial,
    tutorialDone,
    resume: closeMenu,
    save: () => saveGame({ manual: true }),
    toTitle: openTitle,
    load(id) {
      if (loadGame(id)) closeMenu();
    },
    exportSave(id) {
      if (id === slotId && !inTitle) saveGame({ manual: true, quiet: true });
      exportSave(id).then((ok) => !ok && showToast('Nicht exportiert', 'Der Spielstand wurde nicht als Datei gesichert.'));
    },
    importSave(text) {
      try {
        const meta = importSave(text);
        showToast('Spielstand importiert', meta.name);
      } catch (err) {
        showToast('Import fehlgeschlagen', err.message);
      }
    },
    deleteSave(id) {
      deleteSave(id);
      // The title screen keeps showing that map, now as a new unsaved game.
      if (id === slotId) {
        slotId = newSaveId();
        savedOnce = false;
      }
    },
  },
});

function openTitle() {
  leaveGame();
  inTitle = true;
  if (tool) setTool(tool);
  openRecipes(null);
  researchView.close();
  mapsMenu.hidden = winMenu.hidden = true;
  app.classList.add('in-title');
  rig.setLocked(true);
  menu.openTitle();
}

function openPause() {
  rig.setLocked(true);
  menu.openPause();
}

document.getElementById('menu-open').addEventListener('click', openPause);

// --- Tutorial -------------------------------------------------------------------

const tutorial = createTutorial({
  root: app,
  scene,
  game: () => ({ factory, world, tool, rig, audio, target: rig.controls.target, zoom }),
  onFinish: () => menu.refresh(),
});

// The tutorial plays on a fixed free map with iron and copper close together.
function startTutorial() {
  startGame(scenarioById('free'), TUTORIAL_SEED);
  dayNight.setTime(0.02);
  closeMenu();
  tutorial.start();
}

// Leaving the page (tab closed, app switched) saves the game.
window.addEventListener('pagehide', () => leaveGame());
document.addEventListener('visibilitychange', () => document.hidden && leaveGame());

// --- Constructor recipes ----------------------------------------------------

const recipePanel = document.getElementById('recipe');
const recipeList = document.getElementById('recipe-list');
let selected = null; // the constructor whose recipe panel is open

const needsText = (needs) =>
  Object.entries(needs)
    .map(([k, n]) => `${n} ${ITEMS[k].name}`)
    .join(' + ');

const recipeLabel = document.getElementById('recipe-label');

// Recipes of a constructor or refinery; ones that need a locked building stay hidden.
function openRecipes(b) {
  selected = b;
  recipePanel.hidden = !b;
  if (!b) return;
  recipeLabel.textContent = `${BUILDINGS[b.type].name} · Rezept wählen`;
  recipeList.innerHTML = Object.entries(recipesOf(b.type))
    .filter(([, r]) => !r.unlock || factory.research.unlocked.has(r.unlock))
    .map(
      ([id, r]) => `<button type="button" class="recipe-option" data-recipe="${id}" aria-pressed="${b.recipe === id}">
        <span class="swatch" style="--c:${hex(ITEMS[r.makes].color)}"></span>
        <b>${ITEMS[r.makes].name}</b><span>${r.needs ? needsText(r.needs) : `${r.oil} Öl`} · ${r.time} s</span></button>`,
    )
    .join('');
}
const hasRecipes = (b) => !!recipesOf(b?.type);
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

const STATE_TEXT = { work: 'Fördert', blocked: 'Wartet: Ausgang belegt', empty: 'Erschöpft', nopower: 'Kein Strom' };
const MACHINE_TEXT = { work: 'Arbeitet', idle: 'Wartet auf Material', blocked: 'Wartet: Ausgang belegt', nopower: 'Kein Strom' };
const PLANT_TEXT = { work: 'Liefert Strom', idle: 'Bereit, nichts braucht Strom', empty: 'Keine Kohle' };
const PUMP_TEXT = { work: 'Pumpt', blocked: 'Rohre voll', empty: 'Ölfeld erschöpft', nopower: 'Kein Strom: Strommast in die Nähe' };
const REFINERY_TEXT = { work: 'Raffiniert', idle: 'Wartet auf Öl aus den Rohren', blocked: 'Wartet: Ausgang belegt', nopower: 'Kein Strom' };

// How full the pipe network of a fluid building is.
function pipeNote(b) {
  const net = b.pipes;
  if (!net) return '';
  return `${num(Math.round(net.amount))}/${num(net.capacity)} Öl im Netz · ${num(Math.round(net.rate * 60))}/min`;
}

// The power part of a machine's info line.
function powerNote(b) {
  if (!b.net) return ' · ohne Strom (Grundtempo)';
  const pct = Math.round(b.net.satisfaction * 100);
  return ` · Strom ${POWER_USE[b.type]} MW, ${pct < 100 ? `nur ${pct} %` : `Tempo ×${POWER_SPEED}`}`;
}
const itemList = (keys) => keys.map((k) => ITEMS[k].name).join(', ');

function showTile(tile) {
  hovered = tile;
  if (!tile) {
    marker.visible = false;
    ghost.show(null);
    factoryView.showSupply(tool === 'pole' || tool === 'power');
    tileName.textContent = 'Maus über die Karte bewegen';
    tileDetail.textContent = '';
    return;
  }
  const building = factory.get(tile);
  const check = tool === 'remove' ? { ok: !!building, reason: building ? '' : 'Hier steht nichts' } : tool && canBuild(tile);
  const overBelt = check?.ok && tool !== 'remove' && tool !== 'belt' && building?.type === 'belt';
  canvas.style.cursor = !tool && hasRecipes(building) ? 'pointer' : '';
  marker.visible = !tool;
  marker.position.set(tile.position.x, Math.max(tile.height, 0.28) + 0.03, tile.position.z);
  ghost.show(tool, tile, tool === 'remove' || overBelt ? building?.dir ?? 0 : dir, check?.ok);
  factoryView.showSupply(tool === 'pole' || tool === 'power' || usesPower({ type: tool }) || (!tool && (building?.type === 'pole' || building?.type === 'power')));

  const terrain = TERRAIN[tile.terrain];
  if (building?.type === 'drill') {
    tileName.textContent = `Bohrer · ${ORES[tile.ore].name}`;
    tileDetail.textContent = `${STATE_TEXT[building.state]} · ${building.mined} abgebaut · Rest ${tile.amount.toLocaleString('de-DE')}${powerNote(building)}`;
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
    tileDetail.textContent = `${state} · ${have}${powerNote(building)}${tool ? '' : ' · Klick: Rezept'}`;
  } else if (isMachine(building)) {
    const recipe = RECIPES[building.type];
    tileName.textContent = BUILDINGS[building.type].name;
    let state = MACHINE_TEXT[building.state];
    if (building.current) state += `: ${ITEMS[building.current].name} → ${ITEMS[recipe.makes[building.current]].name}`;
    else if (building.refused) state = `Nimmt kein ${ITEMS[building.refused].name} an`;
    else state += ` · nimmt ${itemList(Object.keys(recipe.makes))}`;
    tileDetail.textContent = `${state} · ${building.made} hergestellt${powerNote(building)}`;
  } else if (building?.type === 'power') {
    tileName.textContent = 'Kohlekraftwerk';
    const out = POWER_OUTPUT * factory.research.stats.power;
    const state = building.refused ? `Nimmt kein ${ITEMS[building.refused].name} an` : PLANT_TEXT[building.state];
    tileDetail.textContent = building.net
      ? `${state} · ${mw(out)} · Netz: ${mw(building.net.demand)} Bedarf · Brennstoff ${building.fuel}`
      : `Nicht am Netz: Strommast in die Nähe setzen · Brennstoff ${building.fuel} (Kohle 1, Treibstoff 3)`;
  } else if (building?.type === 'pole') {
    tileName.textContent = 'Strommast';
    const net = building.net;
    tileDetail.textContent = net
      ? `${net.plants.length} Kraftwerke · ${net.consumers.length} Maschinen · ${mw(net.demand)} von ${mw(net.capacity)}`
      : 'Versorgt das Feld 5×5 um sich';
  } else if (building?.type === 'pump') {
    tileName.textContent = 'Ölpumpe';
    const rate = PUMP_RATE * factory.research.stats.pump * 60;
    tileDetail.textContent = `${PUMP_TEXT[building.state]} · bis ${num(Math.round(rate))} Öl/min · Rest ${num(tile.amount)} · ${pipeNote(building)}`;
  } else if (building?.type === 'pipe') {
    tileName.textContent = 'Rohr';
    tileDetail.textContent = building.links?.length ? pipeNote(building) : 'Verbindet sich mit Rohren, Pumpen, Tanks und Raffinerien daneben';
  } else if (building?.type === 'tank') {
    tileName.textContent = 'Öltank';
    tileDetail.textContent = `Speichert 400 Öl · ${pipeNote(building)}`;
  } else if (building?.type === 'refinery') {
    const recipe = REFINERY_RECIPES[building.recipe];
    tileName.textContent = `Raffinerie · ${ITEMS[recipe.makes].name}`;
    const where = building.pipes?.members.length > 1 ? pipeNote(building) : 'Rohr an eine Seite außer vorn';
    tileDetail.textContent = `${REFINERY_TEXT[building.state]} · ${recipe.oil} Öl je Teil · ${where}${powerNote(building)}${tool ? '' : ' · Klick: Rezept'}`;
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
  else if (overBelt) tileDetail.textContent = `Ersetzt das Bandstück · Ausgang nach ${DIR_NAMES[building.dir]}`;
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
  none: [['Esc', 'Menü'], ['Linke Maus', 'verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['WASD', 'bewegen'], ['1–0', 'bauen'], ['O P I K', 'Öl'], ['X', 'abreißen'], ['T', 'Forschung'], ['M', 'Karten'], ['N', 'Tag/Nacht'], ['U', 'Ton']],
  drill: [['Klick', 'Bohrer auf Erz setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  belt: [['Ziehen', 'Band verlegen'], ['R', 'drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  storage: [['Klick', 'Lager setzen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  furnace: [['Klick', 'Schmelzofen setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  assembler: [['Klick', 'Presse setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  splitter: [['Klick', 'Verteiler setzen'], ['R', 'drehen: Eingang hinten'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  merger: [['Klick', 'Zusammenführer setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  constructor: [['Klick', 'Konstruktor setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Ohne Werkzeug klicken', 'Rezept wählen']],
  power: [['Klick', 'Kraftwerk setzen'], ['Kohle', 'per Band von jeder Seite'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  pole: [['Klick / Ziehen', 'Strommasten setzen'], ['Reichweite', '7 Felder'], ['Versorgt', '5×5 Felder'], ['Esc', 'fertig']],
  pump: [['Klick', 'Ölpumpe auf Ölfeld setzen'], ['Strom', 'Mast in die Nähe'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  pipe: [['Ziehen', 'Rohre verlegen'], ['Verbindet', 'alles daneben'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  tank: [['Klick', 'Öltank setzen'], ['Speichert', '400 Öl'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  refinery: [['Klick', 'Raffinerie setzen'], ['R', 'Ausgang drehen'], ['Rohr', 'an jede Seite außer vorn'], ['Ohne Werkzeug klicken', 'Rezept wählen']],
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
  // Dragging a belt over a belt just turns it; a pipe over a pipe changes nothing.
  if ((tool === 'belt' || tool === 'pipe') && existing?.type === tool) return { ok: true, reason: '' };
  // Clicking a machine onto a belt replaces that piece; dragging does not eat belts.
  return factory.canPlace(tool, tile, !(dragging && lastTile));
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
    } else if (tool === 'pipe' && existing?.type === 'pipe') {
      // Already a pipe here.
    } else if (factory.place(tool, tile, existing?.type === 'belt' ? existing.dir : dir, !lastTile)) {
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
  // Dragging poles sets one just before the wire would not reach any further.
  if (tool === 'pole') {
    if (lastTile && Math.hypot(tile.x - lastTile.x, tile.z - lastTile.z) < WIRE_REACH - 1) return;
    buildAt(tile);
    if (!lastTile || factory.get(tile)?.type === 'pole') lastTile = tile;
    return;
  }
  if (!lastTile || (tool !== 'belt' && tool !== 'pipe')) {
    buildAt(tile);
    lastTile = tile;
    return;
  }
  while (lastTile !== tile) {
    const dx = Math.sign(tile.x - lastTile.x);
    const dz = dx ? 0 : Math.sign(tile.z - lastTile.z);
    dir = DIRS.findIndex((d) => d.x === dx && d.z === dz);
    const prev = factory.get(lastTile);
    if (prev?.type === 'belt' && tool === 'belt') factory.setDir(prev, dir);
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
  openRecipes(hasRecipes(b) ? b : null);
});

for (const b of toolButtons) b.addEventListener('click', () => setTool(b.dataset.tool));
document.getElementById('rotate').addEventListener('click', rotate);

// Esc closes whatever is on top; with nothing left open it brings up the pause menu.
function escape() {
  if (!mapsMenu.hidden || !winMenu.hidden) mapsMenu.hidden = winMenu.hidden = true;
  else if (menu.isOpen) menu.back();
  else if (researchView.isOpen) researchView.close();
  else if (selected) openRecipes(null);
  else if (tool) setTool(tool);
  else openPause();
}

window.addEventListener('keydown', (e) => {
  const key = e.key.toLowerCase();
  if ((e.ctrlKey || e.metaKey) && key === 's') {
    e.preventDefault();
    if (!inTitle) saveGame({ manual: true });
    menu.refresh();
    return;
  }
  if (e.repeat && key !== 'r') return;
  if (key === 'escape') return escape();
  if (e.ctrlKey || e.metaKey || e.altKey || menu.isOpen) return;
  if (menuOpen()) {
    if (key === 'm') mapsMenu.hidden = winMenu.hidden = true;
    return;
  }
  if (key === 'm') return openMaps();
  if (key === 'u') return toggleMute();
  if (key === 'n') return dayNight.skipAhead();
  if (key === 't' && missions) return showToast('Missionskarte', 'Hier schalten Missionen neue Gebäude frei, nicht der Forschungsbaum.');
  const numbered = /^[0-9]$/.test(key) && ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'constructor', 'power', 'pole'][(Number(key) + 9) % 10];
  const oilKey = { o: 'pump', p: 'pipe', i: 'refinery', k: 'tank' }[key];
  if (numbered) setTool(numbered);
  else if (oilKey) setTool(oilKey);
  else if (key === 'x' || key === 'delete') setTool('remove');
  else if (key === 'r') rotate();
  else if (key === 't') researchView.toggle();
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
const IDLE = { buildings: new Map() }; // what the machine sounds hear while paused

const timer = new THREE.Timer();
renderer.setAnimationLoop(() => {
  timer.update();
  const dt = Math.min(timer.getDelta(), 0.25);
  // Menus stop the factory; the title screen slowly circles the map.
  const paused = menu.isOpen;
  if (inTitle) rig.orbit(dt * 0.05);
  rig.update(dt);
  sea.update(timer.getElapsed());
  if (!paused) pending += dt;
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
  if (graphics.particles) effects.update(paused ? 0 : dt, factory, focus, zoom, dayNight.night);
  audio.setNight(dayNight.night);
  soundTimer += dt;
  if (soundTimer > 0.1) {
    soundTimer = 0;
    audio.updateMachines(paused ? IDLE : factory, focus, camRight, zoom);
    clockLabel.textContent = dayNight.clock();
    clockIcon.textContent = dayNight.night > 0.5 ? '☾' : '☀';
  }
  if (!paused && graphics.autosave) {
    autosaveTimer += dt;
    if (autosaveTimer >= graphics.autosave) {
      autosaveTimer = 0;
      saveGame();
    }
  }
  if (savedTimer > 0 && (savedTimer -= dt) <= 0) savedLabel.classList.remove('show');
  legendTimer += dt;
  if (legendTimer > 0.5 && !paused) {
    legendTimer = 0;
    renderLegend();
    checkMissions();
    renderProgress();
  }
  tutorial.update(dt, elapsed, !paused && !inTitle && !menuOpen());
  updateHover();
  renderer.render(scene, camera);
});

// The title screen shows the last game behind the menu, or a fresh map.
applyGraphics();
const latest = listSaves()[0];
if (!latest || !loadGame(latest.id)) startGame(scenarioById('free'), 4711);
renderHelp();
resize();
openTitle();

// Handle for poking at the game from the browser console while developing.
if (import.meta.env.DEV) window.bolla = { camera, rig, tutorial, renderer, scene, factoryView, startGame, saveGame, loadGame, menu, dayNight, effects, audio, checkMissions, refresh: () => (shapesDirty = true), get world() { return world; }, get meshes() { return meshes; }, get factory() { return factory; }, get missions() { return missions; } };
