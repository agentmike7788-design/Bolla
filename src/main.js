import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { TRAIN_CARGO, STATION_CAP, TRAIN_SPEED } from './trains.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
import { createFactory, DIRS, DIR_NAMES, BUILDINGS, ITEMS, RECIPES, CONSTRUCTOR_RECIPES, REFINERY_RECIPES, recipesOf, isMachine, usesPower, POWER_USE, POWER_SPEED, POWER_OUTPUT, GEO_OUTPUT, SOLAR_OUTPUT, WIND_OUTPUT, BATTERY_RATE, sunlightAt, WIRE_REACH, PUMP_RATE, SILO_STAGES, siloReady } from './factory.js';
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
import { createLaunch } from './launch.js';
import { createStatsView } from './statsView.js';
import { DRONES_PER_PORT, DRONE_RANGE, DRONE_SPEED, PROVIDER_CAP, REQUEST_AMOUNTS } from './drones.js';
import { BIOMES, biomeOf, weatherEffect } from './biomes.js';
import { createWeatherView } from './weatherView.js';
import { createAchievements } from './achievements.js';
import { ENEMY_MODES, CREATURES, TURRET, LASER, ARTILLERY } from './enemies.js';
import { createEnemyView } from './enemyView.js';
import { CHAPTERS, STORY, PERKS, perksFor, loadCampaign, finishCampaignMap, pickPerk, nextCampaignMap, chapterIndexOf, opensChapter } from './campaign.js';
import { createRadio, createCampaignView, showChapterCard, perkChoice } from './campaignView.js';
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
// The shadow and the camera cover the whole map; big maps get a wider box.
function setExtent(size) {
  const half = (size * TILE) / 2 + 4;
  Object.assign(sun.shadow.camera, { left: -half, right: half, top: half, bottom: -half, near: 1, far: 160 + size });
  sun.shadow.camera.updateProjectionMatrix();
  rig.setExtent((size * TILE) / 2);
}
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
const weatherView = createWeatherView({ scene, effects });
// Shots, hits and deaths are heard from where they happen.
const enemyView = createEnemyView({
  effects,
  onFx(f, pos) {
    const s = audio.spot(pos, rig.controls.target, camRight, zoom);
    if (f.type === 'bullet') audio.play.gun(s.pan, s.level);
    else if (f.type === 'laser') audio.play.laser(s.pan, s.level);
    else if (f.type === 'acid') audio.play.acid(s.pan, s.level);
    else if (f.type === 'death') audio.play.squish(s.pan, s.level, f.kind === 'brute');
    else if (f.type === 'boom' || f.type === 'nestDeath') audio.play.boom(s.pan, s.level, f.type === 'nestDeath' || f.big);
    else if (f.type === 'shellFire') audio.play.cannon(s.pan, s.level);
    else if (f.type === 'shellHit') audio.play.boom(s.pan, s.level, true);
    else if (f.type === 'nestBorn') audio.play.acid(s.pan, s.level);
  },
});
scene.add(enemyView.group);
const dayNight = createDayNight({ scene, renderer, sun, hemi });
let zoom = 40; // camera distance to the point it looks at
const camRight = new THREE.Vector3();

let world;
let meshes;
let factory;
let scenario; // the map being played, see scenarios.js
let missions = null; // mission progress, null in the free game
let campaignRun = false; // the map is played as part of the campaign, see campaign.js

let slotId = null; // save slot of the running game, see save.js
let savedOnce = false; // an empty new game is only saved once something happened

// Start a map: the free game with a random (or given) seed, a biome and how
// dangerous the wild is, or a scenario.
function startGame(next, seed = Math.floor(Math.random() * 99999), biome = 'meadow', enemies = 'off', { campaign = false } = {}) {
  leaveGame();
  tutorial.stop();
  scenario = next;
  campaignRun = campaign && !next.free;
  slotId = newSaveId();
  savedOnce = false;
  if (scenario.free) loadWorld(seed, null, null, biome, enemies);
  else loadWorld(scenario.seed, scenario);
  rig.controls.target.set(0, 0, 0);
  camera.position.set(0, 34, 34);
  radio.clear();
  if (campaignRun) startCampaignMap();
}

// A campaign map starts: the keepsakes of the maps before come along, a new
// chapter shows its title card, then the radio tells what this map is about.
function startCampaignMap() {
  const perks = perksFor(scenario.id, loadCampaign());
  for (const p of perks) factory.research.grant(PERKS[p]);
  const chapter = opensChapter(scenario.id);
  if (chapter) showChapterCard(chapterCard, chapterIndexOf(scenario.id));
  radio.say(STORY[scenario.id].intro, { fresh: true, delay: chapter ? 4.5 : 1 });
  if (perks.length) showToast('Mitbringsel dabei', perks.map((p) => `${PERKS[p].icon} ${PERKS[p].text}`).join(' · '));
}

// Landscape of the free game in each biome.
const FREE_MAPS = {
  meadow: {},
  desert: { biome: 'desert', desert: true, forest: 0.72 },
  snow: { biome: 'snow' },
  volcano: { biome: 'volcano', vents: 10, land: 0.02, richness: 1.3 },
};

function loadWorld(seed, mapScenario = null, saved = null, biome = 'meadow', enemies = 'off') {
  if (meshes) {
    scene.remove(meshes.group);
    meshes.group.traverse((o) => {
      o.geometry?.dispose();
      o.material?.dispose();
    });
  }
  world = generateWorld(seed, mapScenario?.map ?? FREE_MAPS[biome] ?? {});
  setExtent(world.size);
  meshes = buildWorldMeshes(world);
  scene.add(meshes.group);
  const look = biomeOf(world.biome);
  sea.setColor(look.sea ?? 0x2f8fb3);
  dayNight.setBiome(look);
  weatherView.setWorld(world);
  stormSeen = null;
  // A loaded game brings its own enemies; a new map gets the chosen mode.
  factory = createFactory(world, { start: mapScenario?.start, enemies: saved ? 'off' : (mapScenario?.enemies ?? enemies), grace: mapScenario?.grace ?? null });
  enemyView.setWorld(world, factory.enemies.chunks);
  missions = mapScenario ? createMissions(mapScenario, factory) : null;
  if (saved) {
    factory.load(saved.factory, saved.v);
    missions?.load(saved.missions);
    for (const b of factory.buildings.values()) for (const i of factory.footprint(b)) meshes.setDecorHidden(i, true);
  }
  factoryView.clear();
  effects.clear();
  shapesDirty = true;
  if (tool) setTool(tool);
  document.getElementById('seed').textContent = `${mapScenario ? mapScenario.name : `#${seed}`}${world.biome !== 'meadow' ? ` · ${look.icon} ${look.name}` : ''}`;
  document.getElementById('new-map').hidden = !!mapScenario;
  renderLegend();
  researchView.setEnabled(!missions);
  if (missions) missionView.render();
  else researchView.reset();
  openPanel(null);
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

const missionView = createMissionView({ panel: document.getElementById('goal'), getGame: () => ({ scenario, missions, factory, chapter: campaignRun ? chapterIndexOf(scenario.id) + 1 : 0 }) });

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
  renderRail();
  renderDrones();
  renderEnemies();
  renderRocket();
  if (selected?.type === 'silo') renderSiloNote();
  const chestNote = (selected?.type === 'requester' || selected?.type === 'provider') && document.getElementById('chest-note');
  if (chestNote) chestNote.textContent = chestLine(selected);
  // The train panel's status line follows the train; the rest stays clickable.
  const note = selected?.path && document.getElementById('train-note');
  if (note) note.innerHTML = `${trainLine(selected)}${selected.total ? `<br>${cargoText(selected.cargo)}` : ''}`;

  // The oil and railway tools show up once one of their group is unlocked.
  const shown = new Set([...toolButtons].filter((b) => b.dataset.group && factory.research.unlocked.has(b.dataset.tool)).map((b) => b.dataset.group));
  for (const b of toolButtons) {
    const type = b.dataset.tool;
    if (!BUILDINGS[type]) continue;
    b.hidden = !!b.dataset.group && !shown.has(b.dataset.group);
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
const powerMix = document.getElementById('power-mix');
const batteryBar = document.getElementById('battery-bar');
const batteryFill = document.getElementById('battery-fill');
const mw = (n) => `${n.toLocaleString('de-DE', { maximumFractionDigits: 1 })} MW`;

// Shown once power is unlocked: how much of the plants' output the machines use,
// where it comes from, and how full the batteries are.
const POWER_TOOLS = ['power', 'geo', 'solar', 'wind'];
function renderPower() {
  const s = factory.powerSummary();
  const unlocked = POWER_TOOLS.some((t) => factory.research.unlocked.has(t));
  powerPanel.hidden = !unlocked && !s.nets;
  if (powerPanel.hidden) return;
  const stored = s.charge > 0.5 && s.flow <= 0;
  const out = s.consumers > 0 && s.capacity <= 0 && !stored;
  const short = !out && s.consumers > 0 && s.satisfaction < 0.999 && s.demand > 0;
  const green = s.solar + s.wind + s.geo > 0;
  powerPanel.classList.toggle('out', out);
  powerPanel.classList.toggle('short', short);
  powerPanel.classList.toggle('clean', !out && !short && s.used > 0 && s.coal <= 0.01);
  const supply = s.capacity + Math.max(0, -s.flow);
  powerFill.style.width = `${supply ? Math.min(100, (s.demand / supply) * 100) : out ? 100 : 0}%`;
  if (!s.nets) {
    powerState.textContent = 'kein Netz';
    powerText.textContent = factory.research.unlocked.has('power')
      ? 'Kraftwerk bauen, Kohle hineinleiten und Masten bis zu den Maschinen setzen.'
      : factory.research.unlocked.has('solar')
        ? 'Solarpanels (Ö) oder Windräder (Ä) aufstellen und Masten bis zu den Maschinen setzen.'
        : 'Erdwärmekraftwerk (Y) auf eine dampfende Quelle setzen und Masten bis zu den Maschinen.';
  } else if (out) {
    powerState.textContent = !s.plants ? 'kein Kraftwerk' : s.coalPlants && !green ? 'keine Kohle' : s.solar && !s.wind && !s.coalPlants ? 'keine Sonne' : 'kein Strom';
    powerText.textContent = !s.plants
      ? 'Im Netz fehlt ein Kraftwerk. Die Maschinen am Netz stehen still.'
      : s.coalPlants && !green
        ? 'Die Kraftwerke brauchen Kohle vom Band. Die Maschinen am Netz stehen still.'
        : 'Sonne und Wind liefern gerade nichts. Akkus speichern den Strom vom Tag für die Nacht.';
  } else {
    powerState.textContent = short ? `Mangel · ${Math.round(s.satisfaction * 100)} %` : `${Math.round((s.demand / Math.max(supply, 0.001)) * 100)} % Last`;
    const sources = [s.coalPlants && `${s.fuel} Kohle`, s.geo && `${s.geo} Erdwärme`, s.solar && `${s.solar} Solar`, s.wind && `${s.wind} Wind`].filter(Boolean).join(', ');
    powerText.textContent = `Bedarf ${mw(s.demand)} von ${mw(supply)} · ${s.consumers} Maschinen am Netz${sources ? ` · ${sources}` : ''}`;
  }
  // The mix: clean power, coal, and the sun and wind right now.
  powerMix.hidden = !green && !s.batteries;
  if (!powerMix.hidden) {
    const parts = [];
    if (s.solar) parts.push(`<span title="Sonne">☀ <b>${pct(Math.min(1, s.sun))}</b></span>`);
    if (s.wind) parts.push(`<span title="Wind">🌬 <b>${pct(s.windSpeed)}</b></span>`);
    if (s.used > 0) parts.push(`<span class="clean" title="Anteil ohne Kohle">Sauber <b class="clean">${pct(s.clean / s.used)}</b></span>`);
    if (s.batteries) parts.push(`<span title="Akkus">🔋 <b>${pct(s.storage ? s.charge / s.storage : 0)}</b>${s.flow > 0.05 ? ' lädt' : s.flow < -0.05 ? ' entlädt' : ''}</span>`);
    powerMix.innerHTML = parts.join('');
  }
  batteryBar.hidden = !s.batteries;
  if (s.batteries) batteryFill.style.width = `${s.storage ? (s.charge / s.storage) * 100 : 0}%`;
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

const railPanel = document.getElementById('rail');
const railState = document.getElementById('rail-state');
const railText = document.getElementById('rail-text');

// Shown once the railway is unlocked: trains, stations and what they deliver.
function renderRail() {
  const s = factory.railways.summary();
  railPanel.hidden = !factory.research.unlocked.has('rail') && !s.stations;
  if (railPanel.hidden) return;
  const perMin = factory.shippedPerMinute();
  if (s.stations < 2) {
    railState.textContent = 'kein Netz';
    railText.textContent = 'Zwei Bahnhöfe bauen, Gleise dazwischen ziehen, dann einen Zug auf die Schienen setzen.';
  } else if (!s.trains) {
    railState.textContent = 'kein Zug';
    railText.textContent = `${s.stations} Bahnhöfe. Wähle den Zug (Z) und klicke auf einen Bahnhof.`;
  } else {
    railState.textContent = `${num(perMin)}/min`;
    railText.textContent = `${s.trains} ${s.trains === 1 ? 'Zug' : 'Züge'} · ${s.running} ${s.running === 1 ? 'fährt' : 'fahren'}${s.waiting ? ` · ${s.waiting} warten` : ''} · ${s.stations} Bahnhöfe · ${num(factory.shipped)} Teile geliefert`;
  }
}

const dronePanel = document.getElementById('drone');
const droneState = document.getElementById('drone-state');
const droneText = document.getElementById('drone-text');

// Shown once drones are unlocked: ports, drones in the air and what they carried.
function renderDrones() {
  const s = factory.drones.summary();
  dronePanel.hidden = !factory.research.unlocked.has('dronePort') && !s.ports;
  if (dronePanel.hidden) return;
  if (!s.ports) {
    droneState.textContent = 'kein Hafen';
    droneText.textContent = 'Drohnenhafen (F) mit Strom bauen, Angebotskisten (V) mit Bändern füllen, Anfragekisten (C) vor die Maschinen.';
  } else if (!s.chests) {
    droneState.textContent = 'keine Kisten';
    droneText.textContent = `${s.drones} Drohnen warten. Angebots- und Anfragekisten in den Bereich des Hafens stellen.`;
  } else {
    droneState.textContent = `${num(factory.flownPerMinute())}/min`;
    droneText.textContent = `${s.flying} von ${s.drones} Drohnen fliegen · ${s.chests} Kisten${s.uncovered ? ` (${s.uncovered} außer Reichweite)` : ''} · ${num(factory.flown)} Teile geflogen`;
  }
}

const enemyPanel = document.getElementById('enemy');
const enemyState = document.getElementById('enemy-state');
const enemyFill = document.getElementById('enemy-fill');
const enemyText = document.getElementById('enemy-text');
const enemyActions = document.getElementById('enemy-actions');
const pct = (n) => `${Math.round(n * 100)} %`;

// Shown when the map has enemies: nests, evolution, attacks and what they cost.
function renderEnemies() {
  const s = factory.enemies.summary();
  enemyPanel.hidden = s.mode === 'off';
  if (enemyPanel.hidden) return;
  const attack = s.attacking > 0;
  enemyPanel.classList.toggle('attack', attack);
  enemyFill.style.width = pct(s.evo);
  const smog = `Smog ${num(Math.round(s.smog))}/min`;
  if (attack) {
    enemyState.textContent = `Angriff! ${s.attacking} ${s.attacking === 1 ? 'Gegner' : 'Gegner'}`;
    enemyText.textContent = `${s.empty ? `${s.empty} Türme ohne Munition oder Strom · ` : ''}${num(s.killed)} besiegt · ${s.lost} Gebäude verloren`;
  } else if (!s.nests) {
    enemyState.textContent = 'alle Nester zerstört';
    enemyText.textContent = `${num(s.killed)} Gegner besiegt, ${s.nestsKilled} Nester ausgeräuchert. Die Insel gehört dir.`;
  } else {
    enemyState.textContent = s.settlers ? 'Siedler unterwegs' : s.mode === 'peaceful' ? 'friedlich' : s.graceLeft > 0 ? `ruhig · ${clock(s.graceLeft)}` : 'ruhig';
    const why = s.settlers
      ? 'Ein Trupp sucht einen Platz für ein neues Nest. Abfangen, bevor er ankommt!'
      : s.mode === 'peaceful'
      ? 'Nester wehren sich nur, wenn Türme auf sie schießen.'
      : s.graceLeft > 0
      ? `Bis dahin greift niemand an. Smog aus Bohrern, Öfen und Kraftwerken lockt die Nester an${s.expands ? ', und wo er hinzieht, breiten sie sich aus' : ''}.`
      : `Smog lockt Angriffe an: Mauern und Türme um die Fabrik!${s.expands ? ' Wo er hinzieht, gründen Siedler neue Nester.' : ''}`;
    enemyText.textContent = `${s.nests} Nester · Evolution ${pct(s.evo)} · ${smog} · ${why}`;
  }
  const actions = `${s.ruins ? `<button type="button" data-rebuild>Trümmer aufbauen (${s.ruins})</button>` : ''}${factory.enemies.lastAttack ? '<button type="button" class="link" data-look>Hinsehen <kbd>Leertaste</kbd></button>' : ''}`;
  // Redrawn only on change, so a click is never lost.
  if (enemyActions.dataset.html !== actions) enemyActions.innerHTML = enemyActions.dataset.html = actions;
}

// The camera jumps to the last attack.
function lookAtAttack() {
  const a = factory.enemies.lastAttack;
  if (!a) return;
  const t = world.at(Math.round(a.x), Math.round(a.z));
  if (!t) return;
  const offset = camera.position.clone().sub(rig.controls.target);
  rig.controls.target.set(t.position.x, 0, t.position.z);
  camera.position.copy(rig.controls.target).add(offset);
}

// Buildings creatures tore down come back where it is safe again.
function rebuildRuins() {
  const n = factory.enemies.rebuild((r) => {
    const tile = world.tiles[r.index];
    const b = factory.place(r.type, tile, r.dir);
    if (!b) return false;
    for (const k of ['recipe', 'mode', 'chain', 'oneway', 'request', 'want']) if (r[k] !== undefined) b[k] = r[k];
    for (const i of factory.footprint(b)) meshes.setDecorHidden(i, true);
    effects.build(tile, true);
    return true;
  });
  shapesDirty = true;
  if (n) audio.play.build('drill');
  showToast(n ? 'Wiederaufgebaut' : 'Noch nicht sicher', n ? `${n} Gebäude stehen wieder.` : 'Wo noch Gegner sind, wird nicht gebaut.');
  renderEnemies();
}

enemyActions.addEventListener('click', (e) => {
  if (e.target.closest('[data-rebuild]')) rebuildRuins();
  if (e.target.closest('[data-look]')) lookAtAttack();
});

let lossToastAt = -99;

// Toasts and the alarm for new waves and buildings lost.
function watchEnemies() {
  const e = factory.enemies;
  for (const a of e.alerts) {
    if (inTitle) continue;
    if (a.type === 'settlers') {
      showToast('Siedler unterwegs', `${a.count} Käfer ziehen in den ${compass(a.x, a.z)}, um ein neues Nest zu gründen. Fang sie ab! Leertaste: hinsehen.`);
      continue;
    }
    if (a.type === 'nest') {
      showToast('Neues Nest', `Im ${compass(a.x, a.z)} ist ein neues Nest entstanden. Noch ist es klein und schwach.`);
      continue;
    }
    const where = compass(a.nest.x, a.nest.z);
    audio.play.alarm();
    if (a.type === 'counter') showToast('Gegenangriff!', `${a.count} ${a.count === 1 ? 'Gegner stürmt' : 'Gegner stürmen'} aus dem ${where} auf deine Artillerie. Leertaste: hinsehen.`);
    else showToast('Angriff!', `${a.count} ${a.count === 1 ? 'Gegner kommt' : 'Gegner kommen'} aus dem ${where}. Ziel: ${BUILDINGS[a.target.type].name}. Leertaste: hinsehen.`);
  }
  e.alerts.length = 0;
  if (e.destroyed.length) {
    for (const b of e.destroyed) {
      if (!factory.get(b.tile)) for (const i of factory.footprint(b)) meshes.setDecorHidden(i, false);
      if (b === selected) openPanel(null);
    }
    if (!inTitle && factory.time - lossToastAt > 8) {
      lossToastAt = factory.time;
      showToast(`${BUILDINGS[e.destroyed[0].type].name} zerstört`, 'Die Trümmer lassen sich im Gegner-Fenster wieder aufbauen.');
    }
    e.destroyed.length = 0;
    shapesDirty = true;
  }
}

// Rough direction of a spot as seen from the middle of the map.
function compass(x, z) {
  const c = (world.size - 1) / 2;
  const a = Math.atan2(x - c, -(z - c)); // 0 = north, clockwise
  const names = ['Norden', 'Nordosten', 'Osten', 'Südosten', 'Süden', 'Südwesten', 'Westen', 'Nordwesten'];
  return names[(Math.round(a / (Math.PI / 4)) + 8) % 8];
}

const rocketPanel = document.getElementById('rocket');
const rocketState = document.getElementById('rocket-state');
const rocketFill = document.getElementById('rocket-fill');
const rocketText = document.getElementById('rocket-text');

// Parts of a silo's current stage, as delivered/needed.
const siloParts = (b, stage) =>
  Object.entries(stage.needs)
    .map(([k, n]) => `${ITEMS[k].name} ${b.have[k] ?? 0}/${n}`)
    .join(' · ');
// How far the silo is: whole stages plus the share of parts and build time of the current one.
function siloProgress(b) {
  const stage = SILO_STAGES[b.stage];
  if (!stage) return 1;
  const needed = Object.values(stage.needs).reduce((a, n) => a + n, 0);
  const got = Object.entries(stage.needs).reduce((a, [k, n]) => a + Math.min(b.have[k] ?? 0, n), 0);
  const part = b.busy ? 0.8 + 0.2 * (b.timer / stage.time) : (got / needed) * 0.8;
  return (b.stage + part) / SILO_STAGES.length;
}

const siloSeen = new WeakMap(); // silo -> stages finished when last looked

// Shown once the silo is unlocked: the stages of the silo furthest along.
function renderRocket() {
  for (const b of factory.buildings.values()) {
    if (b.type !== 'silo') continue;
    const last = siloSeen.get(b);
    siloSeen.set(b, b.made);
    if (last === undefined || b.made <= last || inTitle) continue;
    const done = SILO_STAGES[b.stage - 1];
    audio.play.success();
    showToast(`Etappe geschafft: ${done.name}`, siloReady(b) ? 'Die Rakete ist betankt und startklar. Klick das Silo an!' : `Als Nächstes: ${SILO_STAGES[b.stage].name}.`);
  }
  const s = factory.siloSummary();
  rocketPanel.hidden = !factory.research.unlocked.has('silo') && !s.silos;
  if (rocketPanel.hidden) return;
  const b = s.best;
  rocketPanel.classList.toggle('ready', siloReady(b));
  rocketFill.style.width = `${b ? siloProgress(b) * 100 : 0}%`;
  if (!b) {
    rocketState.textContent = s.launched ? `${s.launched} gestartet` : 'kein Silo';
    rocketText.textContent = 'Raketensilo (H) auf 3 × 3 freie Felder setzen und Bänder an seine Seiten führen.';
  } else if (siloReady(b)) {
    rocketState.textContent = 'startklar';
    rocketText.textContent = 'Die Rakete ist betankt. Klick das Silo an und starte sie!';
  } else {
    const stage = SILO_STAGES[b.stage];
    rocketState.textContent = `Etappe ${b.stage + 1}/${SILO_STAGES.length}`;
    rocketText.textContent = `${stage.name}: ${b.busy ? `wird gebaut, ${Math.round((b.timer / stage.time) * 100)} %` : siloParts(b, stage)}${s.launched ? ` · ${s.launched} gestartet` : ''}`;
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
    if (campaignRun) radio.say(STORY[scenario.id].missions[missions.index], { delay: 1.5 });
  } else {
    if (campaignRun) {
      finishCampaignMap(scenario.id);
      radio.say(STORY[scenario.id].outro, { delay: 1 });
    }
    audio.play.fanfare();
    effects.fireworks(rig.controls.target, zoom);
    showWin();
  }
}

// How dangerous the free game is, remembered in this browser.
const ENEMY_KEY = 'bolla.enemies';
let freeEnemies = 'normal';
try {
  freeEnemies = ENEMY_MODES[localStorage.getItem(ENEMY_KEY)] ? localStorage.getItem(ENEMY_KEY) : 'normal';
} catch {}
function setFreeEnemies(mode) {
  freeEnemies = mode;
  try {
    localStorage.setItem(ENEMY_KEY, mode);
  } catch {}
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
    const look = biomeOf(s.map?.biome);
    const biomes = s.free
      ? `<span class="map-biomes">${Object.entries(BIOMES)
          .map(([id, b]) => `<span role="button" tabindex="0" class="biome-pick" data-biome="${id}" title="${b.desc}">${b.icon} ${b.name}</span>`)
          .join('')}</span>
        <span class="map-biomes enemy-modes"><span class="enemy-label">🪲 Gegner</span>${Object.entries(ENEMY_MODES)
          .map(([id, m]) => `<span role="radio" tabindex="0" class="enemy-pick" data-enemy="${id}" aria-checked="${id === freeEnemies}" title="${m.desc}">${m.name}</span>`)
          .join('')}</span>`
      : `${s.map?.biome ? `<span class="map-biome" title="${look.desc}">${look.icon} ${look.name}</span>` : ''}${s.enemies ? `<span class="map-biome enemy" title="${ENEMY_MODES[s.enemies].desc}">🪲 Gegner</span>` : ''}`;
    return `<button type="button" class="map-card${s === scenario ? ' current' : ''}" data-map="${s.id}">
      <span class="map-name">${s.name}${s === scenario ? ' <span class="tag">Läuft</span>' : ''}</span>
      <span class="map-meta">${meta}</span>
      <span class="map-desc">${s.desc}</span>
      <span class="map-ores">${oreSwatches(s)}${biomes}</span>
    </button>`;
  }).join('');
  mapsMenu.hidden = false;
}

function showWin() {
  const seconds = missions.finishedAt;
  const stars = starsFor(scenario, seconds);
  const best = saveRecord(scenario.id, stars, seconds);
  const next = campaignRun ? nextCampaignMap(scenario.id) : SCENARIOS[SCENARIOS.indexOf(scenario) + 1];
  const chapter = CHAPTERS[chapterIndexOf(scenario.id)];
  document.getElementById('win-label').textContent = !campaignRun
    ? 'Alle Missionen erfüllt'
    : next
      ? `Kapitel ${chapterIndexOf(scenario.id) + 1} · ${chapter.name}`
      : 'Kampagne abgeschlossen';
  document.getElementById('win-title').textContent = scenario.name;
  document.getElementById('win-stars').textContent = starText(stars);
  document.getElementById('win-time').textContent =
    `Zeit ${clock(seconds)} · drei Sterne unter ${scenario.par} Minuten · Bestzeit ${clock(best.time)}`;
  const nextBtn = document.getElementById('win-next');
  nextBtn.hidden = !next;
  nextBtn.onclick = () => {
    winMenu.hidden = true;
    startGame(next, undefined, undefined, undefined, { campaign: campaignRun });
  };
  winCampaign.hidden = !campaignRun;
  document.getElementById('win-to-campaign').hidden = !campaignRun;
  if (campaignRun) renderWinCampaign();
  winMenu.hidden = false;
}

// On a campaign map the win screen offers keepsakes; the next map waits for the pick.
const winCampaign = document.getElementById('win-campaign');
function renderWinCampaign() {
  const progress = loadCampaign();
  const offers = STORY[scenario.id].perks;
  winCampaign.innerHTML = offers.length
    ? perkChoice(scenario.id, progress)
    : '<p class="win-epilogue">Das Leuchtfeuer sendet. Alle Inseln sind wieder verbunden. Danke fürs Spielen!</p>';
  document.getElementById('win-next').disabled = offers.length > 0 && !progress.perks[scenario.id];
}
winCampaign.addEventListener('click', (e) => {
  const offer = e.target.closest('[data-perk]');
  if (!offer || offer.disabled) return;
  pickPerk(scenario.id, offer.dataset.perk);
  audio.play.success();
  renderWinCampaign();
  document.getElementById('win-next').focus();
});

mapsList.addEventListener('click', (e) => {
  // The enemies of the free game are picked first, then the biome starts it.
  const pick = e.target.closest('[data-enemy]');
  if (pick) {
    setFreeEnemies(pick.dataset.enemy);
    audio.play.click();
    for (const el of mapsList.querySelectorAll('[data-enemy]')) el.setAttribute('aria-checked', String(el === pick));
    return;
  }
  const card = e.target.closest('[data-map]');
  if (!card) return;
  mapsMenu.hidden = true;
  // On the free game's card a biome can be picked; the card itself is grassland.
  const biome = e.target.closest('[data-biome]')?.dataset.biome ?? 'meadow';
  startGame(scenarioById(card.dataset.map), undefined, biome, freeEnemies);
  if (menu.isOpen) closeMenu();
});
for (const menu of [mapsMenu, winMenu]) {
  menu.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]') || e.target === menu) menu.hidden = true;
    if (e.target.closest('[data-maps]')) openMaps();
    if (e.target.closest('[data-campaign]')) openCampaign();
  });
}
document.getElementById('goal').addEventListener('click', (e) => {
  if (e.target.closest('[data-maps]')) openMaps();
  if (e.target.closest('[data-campaign]')) openCampaign();
  if (e.target.closest('[data-radio]')) radio.replay();
});

// --- Campaign -------------------------------------------------------------------

const radioBox = document.getElementById('radio');
const radio = createRadio({ root: radioBox, audio });
const chapterCard = document.getElementById('chapter-card');
const campaignView = createCampaignView({
  root: document.getElementById('campaign'),
  audio,
  onStart(id) {
    startGame(scenarioById(id), undefined, undefined, undefined, { campaign: true });
    if (menu.isOpen) closeMenu();
  },
  onLoad(id) {
    if (loadGame(id) && menu.isOpen) closeMenu();
  },
});
function openCampaign() {
  mapsMenu.hidden = winMenu.hidden = true;
  campaignView.open(campaignRun ? scenario.id : null);
}
document.getElementById('maps-open').addEventListener('click', openMaps);
const menuOpen = () => !mapsMenu.hidden || !winMenu.hidden || campaignView.isOpen || stats.isOpen || launch.active;

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

const gameName = () => (scenario.free ? `Freies Spiel #${world.seed}${world.biome !== 'meadow' ? ` · ${biomeOf(world.biome).name}` : ''}` : `${scenario.name}${campaignRun ? ' · Kampagne' : ''}`);

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
    biome: world.biome,
    factory: factory.save(),
    missions: missions?.save() ?? null,
    campaign: campaignRun,
    dayTime: dayNight.time,
    tutorial: tutorial.save(),
    camera: { position: camera.position.toArray(), target: rig.controls.target.toArray() },
  };
  const meta = { id: slotId, name: gameName(), scenario: scenario.id, campaign: campaignRun, savedAt: Date.now(), playTime: factory.time, buildings: factory.buildings.size, thumb: thumbnail() };
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
  campaignRun = !!data.campaign && !next.free;
  slotId = id;
  savedOnce = true;
  radio.clear();
  loadWorld(data.seed, next.free ? null : next, data, data.biome ?? 'meadow');
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
    campaign: openCampaign,
    tutorial: startTutorial,
    tutorialDone,
    resume: closeMenu,
    enemyMode: () => factory.enemies.mode,
    setEnemyMode(mode) {
      factory.enemies.setMode(mode);
      shapesDirty = true;
      renderEnemies();
    },
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
  openPanel(null);
  researchView.close();
  mapsMenu.hidden = winMenu.hidden = true;
  campaignView.close();
  radio.clear();
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
let selected = null; // the building or train whose panel is open

const needsText = (needs) =>
  Object.entries(needs)
    .map(([k, n]) => `${n} ${ITEMS[k].name}`)
    .join(' + ');

const recipeLabel = document.getElementById('recipe-label');

const TRAIN_TEXT = {
  run: 'Fährt',
  blocked: 'Wartet auf freie Strecke',
  load: 'Lädt',
  unload: 'Lädt aus',
  stop: 'Hält',
  nopath: 'Kein Weg zum nächsten Halt',
  noschedule: 'Kein Fahrplan: Halte hinzufügen',
  signal: 'Wartet am roten Signal',
};
const stationOf = (i) => {
  const b = factory.buildings.get(i);
  return b?.type === 'station' ? b : null;
};
const cargoText = (cargo) =>
  Object.entries(cargo)
    .filter(([, n]) => n > 0)
    .map(([k, n]) => `${n} ${ITEMS[k].name}`)
    .join(', ');

function trainLine(t) {
  const target = stationOf(t.schedule[t.stop]);
  const where = t.at !== null ? `in Bahnhof ${stationOf(t.at)?.name ?? '?'}` : target ? `nach ${target.name}` : '';
  return `${TRAIN_TEXT[t.state] ?? ''} ${where} · Ladung ${t.total}/${TRAIN_CARGO}`;
}

// The side panel: recipes of a constructor or refinery, the mode of a station or
// the schedule of a train.
function openPanel(b) {
  selected = b;
  recipePanel.hidden = !b;
  if (b) renderPanel();
}

function renderPanel() {
  const b = selected;
  if (b.path) return renderSchedule(b);
  if (b.type === 'silo') return renderSilo(b);
  if (b.type === 'requester' || b.type === 'provider') return renderChest(b);
  if (b.type === 'signal') {
    recipeLabel.textContent = 'Signal · Art';
    const modes = [
      ['block', 'Blocksignal', 'Lässt einen Zug durch, wenn der Block dahinter frei ist'],
      ['chain', 'Kettensignal', 'Lässt einen Zug erst durch, wenn sein Weg bis zum nächsten Blocksignal frei ist. Vor Weichen und Kreuzungen setzen'],
    ];
    recipeList.innerHTML =
      modes
        .map(
          ([id, name, text]) => `<button type="button" class="recipe-option" data-mode="${id}" aria-pressed="${(id === 'chain') === !!b.chain}">
        <span class="swatch" style="--c:${id === 'chain' ? '#8a5ae0' : '#3ef06a'}"></span><b>${name}</b><span>${text}</span></button>`,
        )
        .join('') +
      `<p class="panel-note">Richtung:</p>
      <div class="stop-add"><button type="button" data-mode="both" aria-pressed="${!b.oneway}">Beide Richtungen</button><button type="button" data-mode="oneway" aria-pressed="${!!b.oneway}">Einbahn nach ${DIR_NAMES[b.dir]}</button></div>
      <p class="panel-note">Grün: der Block hinter dem Signal ist frei. Einbahnsignale lassen Züge nur in Pfeilrichtung durch (R dreht), so fahren auf Ringen und Doppelgleisen alle Züge gleich herum.</p>`;
    return;
  }
  if (b.type === 'station') {
    recipeLabel.textContent = `Bahnhof ${b.name} · Betriebsart`;
    const modes = [
      ['load', 'Beladen', 'Bänder von der Seite füllen den Bahnhof, Züge laden ein'],
      ['unload', 'Entladen', 'Züge laden aus, der Bahnhof gibt alles auf Bänder an den Seiten'],
    ];
    recipeList.innerHTML =
      modes
        .map(
          ([id, name, text]) => `<button type="button" class="recipe-option" data-mode="${id}" aria-pressed="${b.mode === id}">
        <span class="swatch" style="--c:${id === 'load' ? '#3fae5a' : '#e07a2e'}"></span><b>${name}</b><span>${text}</span></button>`,
        )
        .join('') + `<p class="panel-note">${b.total}/${STATION_CAP} Teile im Bahnhof${b.total ? `: ${cargoText(b.items)}` : ''}</p>`;
    return;
  }
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

// What a drone chest holds, for its panel.
function chestLine(b) {
  const what = b.total ? cargoText(b.items) : 'leer';
  const reach = b.dnet ? '' : ' · Kein Drohnenhafen in Reichweite';
  if (b.type === 'provider') return `${b.total}/${PROVIDER_CAP} Teile: ${what} · ${num(b.sent)} von Drohnen abgeholt${reach}`;
  return `${b.request ? `${b.items[b.request] ?? 0}/${b.want} ${ITEMS[b.request].name}` : 'Noch kein Teil gewählt'} · ${num(b.received)} geliefert, ${num(b.handed)} weitergegeben${reach}`;
}

// A requester chest picks the part and how many it keeps; a provider shows its stock.
function renderChest(b) {
  recipeLabel.textContent = b.type === 'provider' ? 'Angebotskiste' : 'Anfragekiste · Teil wählen';
  if (b.type === 'provider') {
    recipeList.innerHTML = `<p class="panel-note" id="chest-note">${chestLine(b)}</p>
      <p class="panel-note">Bänder von jeder Seite füllen die Kiste. Drohnen holen die Teile für Anfragekisten im selben Netz ab.</p>`;
    return;
  }
  recipeList.innerHTML = `<div class="wish-grid">${Object.entries(ITEMS)
    .map(([k, it]) => `<button type="button" data-wish="${k}" aria-pressed="${b.request === k}"><span class="swatch" style="--c:${hex(it.color)}"></span><span>${it.name}</span></button>`)
    .join('')}</div>
    <p class="panel-note">Vorrat halten:</p>
    <div class="stop-add">${REQUEST_AMOUNTS.map((n) => `<button type="button" data-want="${n}" aria-pressed="${b.want === n}">${n}</button>`).join('')}</div>
    <p class="panel-note" id="chest-note">${chestLine(b)}</p>
    <p class="panel-note">Gibt die Teile nach ${DIR_NAMES[b.dir]} an ein Band oder eine Maschine weiter (R dreht).</p>`;
}

// The silo's stages with their parts, and the start button once the rocket is ready.
function renderSilo(b) {
  recipeLabel.textContent = `Raketensilo${b.launched ? ` · ${b.launched} gestartet` : ''}`;
  recipeList.innerHTML = `<ol class="stages">${SILO_STAGES.map((st, i) => `<li data-stage="${i}"><b>${i + 1}. ${st.name}</b><span></span></li>`).join('')}</ol>
    <p class="panel-note" id="silo-note"></p>
    <button type="button" class="launch-go" data-launch>Rakete starten</button>`;
  renderSiloNote();
}

// The changing part of the silo panel, refreshed with the HUD.
function renderSiloNote() {
  const b = selected;
  const note = document.getElementById('silo-note');
  if (!note) return;
  for (const li of recipeList.querySelectorAll('[data-stage]')) {
    const i = Number(li.dataset.stage);
    const st = SILO_STAGES[i];
    li.className = i < b.stage ? 'done' : i === b.stage ? 'now' : '';
    li.querySelector('span').textContent =
      i < b.stage ? 'fertig' : i === b.stage ? (b.busy ? `wird gebaut · ${Math.round((b.timer / st.time) * 100)} %` : siloParts(b, st)) : needsText(st.needs);
  }
  const ready = siloReady(b);
  const state = ready ? 'Startklar! Alle Systeme bereit.' : b.refused ? `Nimmt kein ${ITEMS[b.refused].name} an` : b.state === 'nopower' ? 'Kein Strom' : b.busy ? `Baut: ${SILO_STAGES[b.stage].desc}` : 'Bänder von jeder Seite liefern die Teile';
  note.textContent = `${state}${b.net ? '' : ready ? '' : ' · ohne Strom halb so schnell'}`;
  const go = recipeList.querySelector('[data-launch]');
  go.disabled = !ready;
  go.textContent = ready ? 'Rakete starten' : 'Start erst nach allen Etappen';
}

function startLaunch(b) {
  if (!factory.launch(b)) return;
  openPanel(null);
  if (tool) setTool(tool);
  researchView.close();
  stats.close();
  launch.start(b);
}

// A train's stops in order, and every station it could stop at.
function renderSchedule(t) {
  const reach = new Set(factory.railways.reachable(t.path[Math.round(t.s)]));
  const all = [...factory.buildings.values()].filter((b) => b.type === 'station').sort((a, b) => a.name.localeCompare(b.name, 'de', { numeric: true }));
  recipeLabel.textContent = `Zug ${t.id} · Fahrplan`;
  const stops = t.schedule
    .map((i, n) => {
      const st = stationOf(i);
      if (!st) return '';
      const now = n === t.stop ? ' now' : '';
      return `<li class="stop${now}"><span class="stop-name">${n + 1}. Bahnhof ${st.name}</span><span class="stop-mode ${st.mode}">${st.mode === 'load' ? 'beladen' : 'entladen'}</span>
        <button type="button" class="link" data-unstop="${n}" aria-label="Halt entfernen">✕</button></li>`;
    })
    .join('');
  recipeList.innerHTML = `<p class="panel-note" id="train-note">${trainLine(t)}${t.total ? `<br>${cargoText(t.cargo)}` : ''}</p>
    <ol class="stops">${stops || '<li class="stop empty">Noch keine Halte</li>'}</ol>
    <p class="panel-note">Halt hinzufügen:</p>
    <div class="stop-add">${
      all.length
        ? all.map((st) => `<button type="button" data-stop="${st.index}"${reach.has(st.index) ? '' : ' class="unreachable" title="Nicht über Gleise erreichbar"'}>${st.name}</button>`).join('')
        : '<span>Kein Bahnhof gebaut</span>'
    }</div>`;
}

const hasRecipes = (b) => !!recipesOf(b?.type) || ['station', 'silo', 'signal', 'requester', 'provider'].includes(b?.type);
recipeList.addEventListener('click', (e) => {
  if (!selected) return;
  const opt = e.target.closest('[data-recipe]');
  const mode = e.target.closest('[data-mode]');
  const add = e.target.closest('[data-stop]');
  const drop = e.target.closest('[data-unstop]');
  const wish = e.target.closest('[data-wish]');
  const want = e.target.closest('[data-want]');
  if (e.target.closest('[data-launch]')) return startLaunch(selected);
  if (opt) factory.setRecipe(selected, opt.dataset.recipe);
  else if (mode) factory.setMode(selected, mode.dataset.mode);
  else if (add) factory.railways.setSchedule(selected, [...selected.schedule, Number(add.dataset.stop)]);
  else if (drop) factory.railways.setSchedule(selected, selected.schedule.filter((_, n) => n !== Number(drop.dataset.unstop)));
  else if (wish) factory.setRequest(selected, wish.dataset.wish);
  else if (want) factory.setRequest(selected, selected.request, Number(want.dataset.want));
  else return;
  audio.play.click();
  renderPanel();
  showTile(hovered);
});
document.getElementById('recipe-close').addEventListener('click', () => openPanel(null));

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
  if (!b.net) return factory.frost < 1 ? ` · ohne Strom: Frost, nur ${Math.round(factory.frost * 100)} %` : ' · ohne Strom (Grundtempo)';
  const pct = Math.round(b.net.satisfaction * 100);
  return ` · Strom ${POWER_USE[b.type]} MW, ${pct < 100 ? `nur ${pct} %` : `Tempo ×${POWER_SPEED}`}`;
}
const itemList = (keys) => keys.map((k) => ITEMS[k].name).join(', ');
const hpText = (b) => `${Math.ceil(b.hp ?? factory.enemies.maxHp(b))}/${factory.enemies.maxHp(b)} Lebenspunkte`;

const TERRAIN_NOTE = { ice: 'Gefrorener See: bebaubar', lava: 'Glühende Lava: nicht bebaubar', cone: 'Der Vulkan: nicht bebaubar' };

function showTile(tile) {
  hovered = tile;
  if (!tile) {
    marker.visible = false;
    ghost.show(null);
    factoryView.showSupply(tool === 'pole' || POWER_TOOLS.includes(tool) || tool === 'battery');
    factoryView.showDroneRange(DRONE_TOOLS.has(tool));
    tileName.textContent = 'Maus über die Karte bewegen';
    tileDetail.textContent = '';
    return;
  }
  const building = factory.get(tile);
  const train = factory.trainOn(tile);
  const check = tool === 'remove' ? { ok: !!(building || train), reason: building || train ? '' : 'Hier steht nichts' } : tool && canBuild(tile);
  const overBelt = check?.ok && tool !== 'remove' && tool !== 'belt' && building?.type === 'belt';
  canvas.style.cursor = !tool && (train || hasRecipes(building)) ? 'pointer' : '';
  marker.visible = !tool;
  marker.position.set(tile.position.x, Math.max(tile.height, 0.28) + 0.03, tile.position.z);
  ghost.show(tool, tile, tool === 'remove' || overBelt ? building?.dir ?? 0 : dir, check?.ok, tool === 'artillery' ? factory.enemies.artilleryRange() : null);
  factoryView.showSupply(tool === 'pole' || POWER_TOOLS.includes(tool) || tool === 'battery' || usesPower({ type: tool }) || (!tool && (building?.type === 'pole' || POWER_TOOLS.includes(building?.type) || building?.type === 'battery')));
  factoryView.showDroneRange(DRONE_TOOLS.has(tool) || (!tool && DRONE_TOOLS.has(building?.type)));

  const terrain = TERRAIN[tile.terrain];
  if (train) {
    tileName.textContent = `Zug ${train.id}`;
    const stops = train.schedule.map((i) => stationOf(i)?.name ?? '?').join(' → ');
    tileDetail.textContent = `${trainLine(train)} · Fahrplan ${stops || 'leer'}${tool ? '' : ' · Klick: Fahrplan'}`;
  } else if (building?.type === 'rail') {
    tileName.textContent = 'Gleis';
    const n = building.links?.length ?? 0;
    tileDetail.textContent = n ? `${n === 1 ? 'Gleisende' : n === 2 ? 'Strecke' : 'Weiche'} · Züge fahren bis ${num(Math.round(TRAIN_SPEED * factory.research.stats.train * 60))} Felder/min` : 'Noch nicht verbunden: Gleis von hier weiterziehen';
  } else if (building?.type === 'signal') {
    tileName.textContent = building.chain ? 'Kettensignal' : 'Blocksignal';
    const g = building.green ?? [false, false];
    const ahead = DIR_NAMES[building.dir];
    const free = building.oneway ? `Einbahn nach ${ahead} · ${g[0] ? 'Grün' : 'Rot'}` : g[0] && g[1] ? 'Beide Seiten frei' : g[0] || g[1] ? `Frei nach ${DIR_NAMES[g[0] ? building.dir : (building.dir + 2) % 4]}` : 'Rot: Blöcke belegt oder reserviert';
    tileDetail.textContent = `${free}${tool ? '' : ' · Klick: Art und Richtung'}`;
  } else if (building?.type === 'dronePort') {
    tileName.textContent = 'Drohnenhafen';
    const state = building.state === 'nopower' ? 'Kein Strom: Drohnen bleiben am Boden' : `${building.out ?? 0} von ${DRONES_PER_PORT} Drohnen unterwegs`;
    tileDetail.textContent = `${state} · Reichweite ${DRONE_RANGE * 2 + 1} × ${DRONE_RANGE * 2 + 1} Felder · ${num(Math.round(DRONE_SPEED * factory.research.stats.drone * 60))} Felder/min${powerNote(building)}`;
  } else if (building?.type === 'provider' || building?.type === 'requester') {
    tileName.textContent = building.type === 'provider' ? 'Angebotskiste' : `Anfragekiste${building.request ? ` · ${ITEMS[building.request].name}` : ''}`;
    tileDetail.textContent = `${chestLine(building)}${tool ? '' : building.type === 'requester' ? ' · Klick: Teil wählen' : ''}`;
  } else if (building?.type === 'station') {
    tileName.textContent = `Bahnhof ${building.name} · ${building.mode === 'load' ? 'Beladen' : 'Entladen'}`;
    const side = building.mode === 'load' ? 'Bänder von der Seite liefern zu' : 'gibt an Bänder an den Seiten ab';
    tileDetail.textContent = `${building.total}/${STATION_CAP} Teile · ${side}${tool ? '' : ' · Klick: Betriebsart'}`;
  } else if (building?.type === 'drill') {
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
  } else if (building?.type === 'geo') {
    tileName.textContent = 'Erdwärmekraftwerk';
    const out = GEO_OUTPUT * factory.research.stats.power * weatherEffect(factory.weather, 'geo');
    tileDetail.textContent = building.net
      ? `${building.state === 'work' ? 'Liefert Strom' : 'Bereit, nichts braucht Strom'} · ${mw(out)} ohne Kohle · Netz: ${mw(building.net.demand)} Bedarf`
      : `Nicht am Netz: Strommast in die Nähe setzen · ${mw(out)} ohne Kohle`;
  } else if (building?.type === 'solar' || building?.type === 'wind') {
    const solar = building.type === 'solar';
    tileName.textContent = solar ? 'Solarpanel' : 'Windrad';
    const s = factory.powerSummary();
    const peak = (solar ? SOLAR_OUTPUT : WIND_OUTPUT) * factory.research.stats.renewable;
    const now = building.out ?? 0;
    const why = solar ? `Sonne ${pct(Math.min(1, s.sun))}` : `Wind ${pct(s.windSpeed)}${(building.wake ?? 1) < 1 ? ` · Nachbarn nehmen ${pct(1 - building.wake)} Wind` : ''}`;
    const state = now <= 0.01 ? (solar ? 'Nacht: keine Sonne' : 'Flaute') : building.state === 'work' ? 'Liefert Strom' : 'Bereit, nichts braucht Strom';
    tileDetail.textContent = building.net
      ? `${state} · ${mw(now)} von ${mw(peak)} · ${why} · kein Smog`
      : `Nicht am Netz: Strommast in die Nähe setzen · ${mw(now)} von ${mw(peak)} · ${why}`;
  } else if (building?.type === 'battery') {
    tileName.textContent = 'Akku';
    const cap = factory.batteryCapacity();
    const flow = building.flow ?? 0;
    const state = !building.net ? 'Nicht am Netz: Strommast in die Nähe setzen' : flow > 0.01 ? `Lädt mit ${mw(flow)}` : flow < -0.01 ? `Gibt ${mw(-flow)} ab` : building.charge >= cap - 0.5 ? 'Voll' : 'Wartet auf Sonne oder Wind';
    tileDetail.textContent = `${state} · ${Math.round(building.charge)} von ${Math.round(cap)} MJ (${pct(building.charge / cap)}) · höchstens ${mw(BATTERY_RATE)}`;
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
  } else if (building?.type === 'silo') {
    const stage = SILO_STAGES[building.stage];
    tileName.textContent = `Raketensilo · ${stage ? `Etappe ${building.stage + 1}: ${stage.name}` : 'startklar'}`;
    tileDetail.textContent = stage
      ? `${building.busy ? `Wird gebaut, ${Math.round((building.timer / stage.time) * 100)} %` : siloParts(building, stage)}${powerNote(building)}${tool ? '' : ' · Klick: Etappen'}`
      : `Die Rakete ist betankt${tool ? '' : ' · Klick: Start'}`;
  } else if (building?.type === 'wall') {
    tileName.textContent = 'Mauer';
    tileDetail.textContent = `${hpText(building)} · Gegner müssen sich durchbeißen oder außen herum laufen`;
  } else if (building?.type === 'turret') {
    tileName.textContent = 'Geschützturm';
    const state = { work: 'Feuert', idle: 'Wachsam', empty: 'Keine Munition: Band oder Anfragekiste mit Munition anschließen' }[building.state] ?? '';
    tileDetail.textContent = `${state} · Munition ${building.ammo ?? 0}/${TURRET.store} (${(building.ammo ?? 0) * TURRET.shots + (building.shots ?? 0)} Schuss) · Reichweite ${TURRET.range} · ${hpText(building)}`;
  } else if (building?.type === 'laser') {
    tileName.textContent = 'Laserturm';
    const state = { work: 'Feuert', idle: 'Wachsam', nopower: 'Kein Strom: feuert nicht' }[building.state] ?? '';
    tileDetail.textContent = `${state} · Reichweite ${LASER.range} · ${building.net ? `Strom ${POWER_USE.laser} MW beim Feuern` : 'Braucht einen Strommast in der Nähe'} · ${hpText(building)}`;
  } else if (building?.type === 'artillery') {
    tileName.textContent = 'Artillerie';
    const state = { work: 'Feuert', idle: 'Kein Nest in Reichweite', empty: 'Keine Granaten: Band oder Anfragekiste mit Granaten anschließen' }[building.state] ?? '';
    tileDetail.textContent = `${state} · Granaten ${building.shells ?? 0}/${ARTILLERY.store} · Reichweite ${Math.round(factory.enemies.artilleryRange())} · ${hpText(building)}`;
  } else if (building?.type === 'storage') {
    tileName.textContent = 'Lager';
    tileDetail.textContent = building.received
      ? `${num(building.received)} eingelagert · zuletzt ${ITEMS[building.last].name}`
      : 'Nimmt alles von Bändern auf allen Seiten';
  } else if (!building && factory.enemies.nestAt(tile)) {
    const nest = factory.enemies.nestAt(tile);
    tileName.textContent = 'Nest';
    tileName.textContent = nest.born !== undefined && nest.hp < nest.max ? 'Junges Nest' : 'Nest';
    tileDetail.textContent = `${Math.ceil(nest.hp)}/${nest.max} Lebenspunkte · ${nest.anger >= 45 ? 'Wütend: bald kommt eine Welle' : 'Saugt Smog auf und wird wütend'} · Türme und Artillerie in Reichweite schießen darauf`;
  } else if (!building && factory.enemies.ruins.some((r) => r.index === tile.z * world.size + tile.x)) {
    const r = factory.enemies.ruins.find((x) => x.index === tile.z * world.size + tile.x);
    tileName.textContent = `Trümmer · ${BUILDINGS[r.type].name}`;
    tileDetail.textContent = 'Von Gegnern zerstört. Im Gegner-Fenster lässt es sich wieder aufbauen.';
  } else if (tile.vent && !building) {
    tileName.textContent = 'Erdwärmequelle';
    tileDetail.textContent = `Heißer Dampf aus der Tiefe: Platz für ein Erdwärmekraftwerk · Feld ${tile.x}, ${tile.z}`;
  } else if (tile.ore) {
    tileName.textContent = ORES[tile.ore].name;
    tileDetail.textContent = `${tile.amount.toLocaleString('de-DE')} Einheiten · Feld ${tile.x}, ${tile.z}`;
  } else {
    tileName.textContent = terrain.name;
    tileDetail.textContent = `${TERRAIN_NOTE[tile.terrain] ?? (terrain.buildable ? 'Bebaubar' : 'Nicht bebaubar')} · Feld ${tile.x}, ${tile.z}`;
  }
  if (building?.hp !== undefined && !['wall', 'turret', 'laser', 'artillery'].includes(building.type)) tileDetail.textContent += ` · beschädigt: ${hpText(building)}`;
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
  const offset = (world.size * TILE) / 2;
  const x = point && Math.floor((point.x + offset) / TILE);
  const z = point && Math.floor((point.z + offset) / TILE);
  const inside = point && x >= 0 && z >= 0 && x < world.size && z < world.size;
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
const DRONE_TOOLS = new Set(['dronePort', 'provider', 'requester']);
const DEFENSE_TOOLS = new Set(['wall', 'turret', 'laser', 'artillery']);
const help = document.getElementById('help');
const HELP = {
  none: [['Esc', 'Menü'], ['Linke Maus', 'verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['WASD', 'bewegen'], ['1–0', 'bauen'], ['Y', 'Erdwärme'], ['Ö Ä #', 'Ökostrom'], ['O P I K', 'Öl'], ['G B Z J', 'Bahn'], ['F V C', 'Drohnen'], ['H', 'Silo'], [', . - Ü', 'Abwehr'], ['X', 'abreißen'], ['T', 'Forschung'], ['L', 'Statistik'], ['M', 'Karten'], ['N', 'Tag/Nacht'], ['U', 'Ton']],
  drill: [['Klick', 'Bohrer auf Erz setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  belt: [['Ziehen', 'Band verlegen'], ['R', 'drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  storage: [['Klick', 'Lager setzen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  furnace: [['Klick', 'Schmelzofen setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  assembler: [['Klick', 'Presse setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  splitter: [['Klick', 'Verteiler setzen'], ['R', 'drehen: Eingang hinten'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  merger: [['Klick', 'Zusammenführer setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen'], ['WASD', 'bewegen']],
  constructor: [['Klick', 'Konstruktor setzen'], ['R', 'Ausgang drehen'], ['Esc', 'fertig'], ['Ohne Werkzeug klicken', 'Rezept wählen']],
  power: [['Klick', 'Kraftwerk setzen'], ['Kohle', 'per Band von jeder Seite'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  geo: [['Klick auf Quelle', 'Erdwärmekraftwerk setzen'], ['Liefert', `${GEO_OUTPUT} MW ohne Kohle`], ['Mast', 'in die Nähe'], ['Esc', 'fertig']],
  solar: [['Klick / Ziehen', 'Solarpanels setzen'], ['Liefert', `bis ${SOLAR_OUTPUT} MW bei Sonne`], ['Mast', 'in die Nähe'], ['Esc', 'fertig']],
  wind: [['Klick', 'Windrad setzen'], ['Liefert', `bis ${WIND_OUTPUT} MW bei Wind`], ['Abstand', 'mehr als 2 Felder'], ['Esc', 'fertig']],
  battery: [['Klick', 'Akku setzen'], ['Speichert', 'Sonnen- und Windstrom'], ['Mast', 'in die Nähe'], ['Esc', 'fertig']],
  pole: [['Klick / Ziehen', 'Strommasten setzen'], ['Reichweite', '7 Felder'], ['Versorgt', '5×5 Felder'], ['Esc', 'fertig']],
  pump: [['Klick', 'Ölpumpe auf Ölfeld setzen'], ['Strom', 'Mast in die Nähe'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  pipe: [['Ziehen', 'Rohre verlegen'], ['Verbindet', 'alles daneben'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  tank: [['Klick', 'Öltank setzen'], ['Speichert', '400 Öl'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  refinery: [['Klick', 'Raffinerie setzen'], ['R', 'Ausgang drehen'], ['Rohr', 'an jede Seite außer vorn'], ['Ohne Werkzeug klicken', 'Rezept wählen']],
  rail: [['Ziehen', 'Gleise verlegen'], ['Ecken', 'werden Kurven'], ['Von einem Gleis ziehen', 'Abzweig'], ['Esc', 'fertig']],
  signal: [['Klick auf Gleis', 'Signal setzen'], ['Blöcke', 'je ein Zug'], ['Ohne Werkzeug klicken', 'Block- / Kettensignal'], ['Esc', 'fertig']],
  dronePort: [['Klick', 'Drohnenhafen setzen'], ['Strom', 'Mast in die Nähe'], ['Reichweite', `${DRONE_RANGE * 2 + 1} × ${DRONE_RANGE * 2 + 1}`], ['Esc', 'fertig']],
  provider: [['Klick', 'Angebotskiste setzen'], ['Bänder', 'füllen sie'], ['Im Bereich', 'eines Hafens'], ['Esc', 'fertig']],
  requester: [['Klick', 'Anfragekiste setzen'], ['R', 'Ausgang drehen'], ['Ohne Werkzeug klicken', 'Teil wählen'], ['Esc', 'fertig']],
  station: [['Klick', 'Bahnhof setzen'], ['R', 'Gleisrichtung drehen'], ['Bänder', 'an die Seiten'], ['Ohne Werkzeug klicken', 'Beladen / Entladen']],
  train: [['Klick auf Bahnhof', 'Zug einsetzen'], ['Braucht', '4 Felder Gleis'], ['Ohne Werkzeug klicken', 'Fahrplan'], ['Esc', 'fertig']],
  wall: [['Klick / Ziehen', 'Mauer bauen'], ['Gegner', 'beißen sich langsam durch'], ['Esc', 'fertig'], ['Rechte Maus', 'Kamera drehen']],
  turret: [['Klick', 'Geschützturm setzen'], ['Munition', 'per Band oder Anfragekiste'], ['Reichweite', `${TURRET.range} Felder`], ['Esc', 'fertig']],
  laser: [['Klick', 'Laserturm setzen'], ['Strom', `${POWER_USE.laser} MW beim Feuern`], ['Reichweite', `${LASER.range} Felder`], ['Esc', 'fertig']],
  artillery: [['Klick', 'Artillerie setzen (3 × 3)'], ['Granaten', 'per Band oder Anfragekiste'], ['Ziel', 'Nester in Reichweite'], ['Esc', 'fertig']],
  silo: [['Klick', 'Raketensilo setzen'], ['Braucht', '3 × 3 freie Felder'], ['Bänder', 'an jede Seite'], ['Ohne Werkzeug klicken', 'Etappen, Start']],
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
  enemyView.showSmog(DEFENSE_TOOLS.has(tool));
  showTile(hovered);
}

function canBuild(tile) {
  const existing = factory.get(tile);
  if (tool === 'train') return factory.canAddTrain(tile);
  // Dragging a rail over track joins it.
  if (tool === 'rail' && (existing?.type === 'rail' || existing?.type === 'station')) return { ok: true, reason: '' };
  // Dragging a belt over a belt just turns it; a pipe over a pipe changes nothing.
  if ((tool === 'belt' || tool === 'pipe') && existing?.type === tool) return { ok: true, reason: '' };
  // Clicking a machine onto a belt replaces that piece; dragging does not eat belts.
  return factory.canPlace(tool, tile, !(dragging && lastTile));
}

function rotate() {
  audio.play.rotate();
  const building = !tool && hovered && factory.get(hovered);
  if (building) {
    // A signal turns round on its track; everything else turns a quarter.
    factory.setDir(building, (building.dir + (building.type === 'signal' ? 2 : 1)) % 4);
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
      // A signal leaves its rail behind, which keeps the ground clear.
      if (!factory.get(tile)) for (const i of factory.footprint(removed)) meshes.setDecorHidden(i, false);
      audio.play.remove();
      effects.remove(tile, removed.type);
    }
    if (removed && (removed === selected || removed.train === selected)) openPanel(null);
  } else {
    const existing = factory.get(tile);
    if (tool === 'belt' && existing?.type === 'belt') {
      if (existing.dir !== dir) audio.play.rotate();
      factory.setDir(existing, dir);
    } else if (tool === 'pipe' && existing?.type === 'pipe') {
      // Already a pipe here.
    } else if (tool === 'rail' && (existing?.type === 'rail' || existing?.type === 'station')) {
      // Track is here already; the drag links it.
    } else if (tool === 'train') {
      const t = factory.addTrain(tile);
      if (t) {
        audio.play.horn();
        effects.build(tile, true);
        const stops = t.schedule.map((i) => stationOf(i).name);
        showToast('Zug auf den Schienen', stops.length > 1 ? `Fahrplan ${stops.join(' → ')}. Klick den Zug an, um ihn zu ändern.` : 'Klick den Zug an und gib ihm einen Fahrplan.');
      } else {
        audio.play.deny();
        showToast('Hier passt kein Zug', factory.canAddTrain(tile).reason);
      }
    } else if (factory.place(tool, tile, existing?.type === 'belt' ? existing.dir : dir, !lastTile)) {
      for (const i of factory.footprint(factory.get(tile))) meshes.setDecorHidden(i, true);
      if (tool === 'silo') for (const i of factory.footprint(factory.get(tile))) effects.build(world.tiles[i], i % 2 === 0);
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
  if (tool === 'train') {
    if (!lastTile) buildAt(tile);
    lastTile = tile;
    return;
  }
  if (!lastTile || (tool !== 'belt' && tool !== 'pipe' && tool !== 'rail' && tool !== 'wall')) {
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
    const from = lastTile;
    lastTile = world.at(lastTile.x + dx, lastTile.z + dz);
    buildAt(lastTile);
    if (tool === 'rail' && factory.linkTrack(factory.get(from), factory.get(lastTile))) shapesDirty = true;
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
  if (!downAt || e.target !== canvas || launch.active) return;
  const moved = Math.hypot(e.clientX - downAt.x, e.clientY - downAt.y);
  downAt = null;
  if (tool || moved > 6) return;
  setPointer(e);
  const tile = pickTile();
  const b = tile && (factory.trainOn(tile) ?? factory.get(tile));
  openPanel(b?.path || hasRecipes(b) ? b : null);
});

for (const b of toolButtons) b.addEventListener('click', () => setTool(b.dataset.tool));
document.getElementById('rotate').addEventListener('click', rotate);

// Esc closes whatever is on top; with nothing left open it brings up the pause menu.
function escape() {
  if (launch.active) return launch.skip();
  if (stats.isOpen) return stats.close();
  if (campaignView.isOpen) campaignView.close();
  else if (!mapsMenu.hidden || !winMenu.hidden) mapsMenu.hidden = winMenu.hidden = true;
  else if (menu.isOpen) menu.back();
  else if (researchView.isOpen) researchView.close();
  else if (selected) openPanel(null);
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
  if (launch.active) return;
  if (e.ctrlKey || e.metaKey || e.altKey || menu.isOpen) return;
  if (menuOpen()) {
    if (key === 'm') {
      mapsMenu.hidden = winMenu.hidden = true;
      campaignView.close();
    }
    if (key === 'l' && stats.isOpen) stats.close();
    return;
  }
  if (key === 'm') return openMaps();
  if (key === 'l') return stats.toggle();
  if (key === 'u') return toggleMute();
  if (key === 'n') return dayNight.skipAhead();
  if (key === 't' && missions) return showToast('Missionskarte', 'Hier schalten Missionen neue Gebäude frei, nicht der Forschungsbaum.');
  const numbered = /^[0-9]$/.test(key) && ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'constructor', 'power', 'pole'][(Number(key) + 9) % 10];
  const oilKey = { y: 'geo', o: 'pump', p: 'pipe', i: 'refinery', k: 'tank', g: 'rail', b: 'station', z: 'train', j: 'signal', f: 'dronePort', v: 'provider', c: 'requester', h: 'silo' }[key];
  // Artillery on Ü, or [ in the same place on other keyboards.
  const defenseKey = { ',': 'wall', '.': 'turret', '-': 'laser', 'ü': 'artillery', '[': 'artillery' }[key];
  // Renewables: Ö Ä # on a German keyboard, ; ' \ in the same places on others.
  const greenKey = { 'ö': 'solar', ';': 'solar', 'ä': 'wind', "'": 'wind', '#': 'battery', '\\': 'battery' }[key];
  if (key === ' ') {
    e.preventDefault();
    return lookAtAttack();
  }
  if (numbered) setTool(numbered);
  else if (oilKey) setTool(oilKey);
  else if (defenseKey) setTool(defenseKey);
  else if (greenKey) setTool(greenKey);
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
  weatherView.resize(h * renderer.getPixelRatio(), camera.fov);
}
window.addEventListener('resize', resize);

document.getElementById('new-map').addEventListener('click', () => startGame(scenarioById('free'), undefined, world.biome, factory.enemies.mode));
document.getElementById('stats-open').addEventListener('click', () => stats.toggle());

// --- Statistics and the rocket launch -------------------------------------------

const stats = createStatsView({ root: app, getFactory: () => factory });

const launch = createLaunch({
  scene,
  camera,
  rig,
  audio,
  effects,
  root: app,
  onDone(silo, base) {
    shapesDirty = true;
    audio.play.fanfare();
    effects.fireworks(base, 30);
    // A mission map ends with its own win screen; in the free game the first rocket is the end goal.
    if (missions) return checkMissions();
    showRocketWin();
  },
});

function showRocketWin() {
  const made = Object.entries(factory.history.total.p)
    .filter(([k]) => ITEMS[k])
    .reduce((n, [, v]) => n + v, 0);
  document.getElementById('win-label').textContent = 'Raketenstart geglückt';
  document.getElementById('win-title').textContent = factory.launched > 1 ? `${factory.launched}. Rakete im All` : 'Rakete im All!';
  document.getElementById('win-stars').textContent = '🚀';
  document.getElementById('win-time').textContent = `Spielzeit ${clock(factory.time)} · ${num(Math.round(made))} Teile hergestellt · ${num(factory.buildings.size)} Gebäude`;
  document.getElementById('win-next').hidden = true;
  winMenu.hidden = false;
}

// --- Weather and achievements ------------------------------------------------------

const weatherLabel = document.getElementById('weather');
let stormSeen = null; // 'warned' or 'raging' for the storm the HUD last announced

// The biome's weather in the top bar, with a toast when a storm is coming and when it breaks.
function renderWeather() {
  const w = factory.weather;
  weatherLabel.hidden = !w.storm;
  if (!w.storm) return;
  const icon = biomeOf(factory.biome).icon;
  const mmss = (t) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;
  weatherLabel.classList.toggle('raging', w.active);
  weatherLabel.textContent = w.active ? `${icon} ${w.storm.name}! ${w.storm.text} · ${mmss(w.left)}` : `${icon} ${w.storm.name} in ${mmss(w.next)}`;
  weatherLabel.title = biomeOf(factory.biome).desc;
  if (inTitle || menu.isOpen) return;
  if (w.active && stormSeen !== 'raging') {
    if (stormSeen === 'warned') {
      showToast(`${w.storm.name}!`, `${w.storm.text} für ${Math.round(w.storm.lasts)} Sekunden.`);
      audio.play.storm(factory.biome);
    }
    stormSeen = 'raging';
  } else if (!w.active && w.next <= 15 && stormSeen !== 'warned') {
    showToast(`${w.storm.name} zieht auf`, `In ${Math.ceil(w.next)} Sekunden: ${w.storm.text}.`);
    stormSeen = 'warned';
  } else if (!w.active && w.next > 15) stormSeen = null;
}

// Earned achievements pop up one after another in their own golden toast.
const achievementToast = document.getElementById('achievement');
const achievementQueue = [];
let achievementTimer = 0;
const achievements = createAchievements({
  onUnlock(a) {
    achievementQueue.push(a);
    if (achievementQueue.length === 1) showAchievement();
  },
});
function showAchievement() {
  const a = achievementQueue[0];
  if (!a) return;
  achievementToast.innerHTML = `<span class="ach-icon" aria-hidden="true">${a.icon}</span><span><small>Erfolg freigeschaltet</small><strong>${a.name}</strong><span>${a.desc}</span></span>`;
  achievementToast.hidden = false;
  achievementToast.classList.remove('pop');
  void achievementToast.offsetWidth;
  achievementToast.classList.add('pop');
  audio.play.achievement();
  clearTimeout(achievementTimer);
  achievementTimer = setTimeout(() => {
    achievementQueue.shift();
    achievementToast.hidden = true;
    if (achievementQueue.length) setTimeout(showAchievement, 300);
  }, 3800);
}

// The simulation runs in fixed steps so belts behave the same at any frame rate.
const STEP = 1 / 60;
let pending = 0;
let legendTimer = 0;
let soundTimer = 0;
const IDLE = { buildings: new Map() }; // what the machine sounds hear while paused
const hornTrips = new WeakMap(); // train -> trips when its horn last sounded

const timer = new THREE.Timer();
renderer.setAnimationLoop(() => {
  timer.update();
  const dt = Math.min(timer.getDelta(), 0.25);
  // Menus stop the factory; the title screen slowly circles the map.
  const paused = menu.isOpen;
  if (inTitle) rig.orbit(dt * 0.05);
  if (launch.active) launch.update(dt);
  else rig.update(dt);
  sea.update(timer.getElapsed());
  const weather = factory.weather;
  const erupting = weather.storm && weather.storm.effects.geo ? weather.strength : 0;
  meshes.update(timer.getElapsed(), erupting);
  dayNight.setStorm(weather.strength);
  if (!paused) pending += dt;
  factory.setDaylight(sunlightAt(dayNight.time));
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
  weatherView.update(paused ? 0 : dt, elapsed, focus, weather, dayNight.night, factory, graphics.particles && !paused);
  enemyView.update(paused ? 0 : dt, elapsed, factory, camera, dayNight.night);
  watchEnemies();
  audio.setNight(dayNight.night);
  soundTimer += dt;
  if (soundTimer > 0.1) {
    soundTimer = 0;
    audio.updateMachines(paused ? IDLE : factory, focus, camRight, zoom);
    // A horn when a train leaves a station near the camera.
    for (const t of factory.trains) {
      if (t.trips !== hornTrips.get(t)) {
        if (hornTrips.has(t)) {
          const sp = audio.spot(world.tiles[t.path[Math.round(t.s)]].position, focus, camRight, zoom);
          audio.play.horn(sp.pan, sp.level);
        }
        hornTrips.set(t, t.trips);
      }
    }
    renderWeather();
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
    if (!launch.active) checkMissions();
    if (!inTitle && !launch.active) achievements.check({ factory, scenario, missions, campaignRun, night: dayNight.night });
    renderProgress();
    stats.update();
    if (factory.derailed.length) {
      showToast('Zug entgleist', 'Unter dem Zug fehlt jetzt ein Gleis. Er wurde abgeräumt.');
      factory.derailed.length = 0;
      if (selected?.path && !factory.trains.includes(selected)) openPanel(null);
    }
  }
  tutorial.update(dt, elapsed, !paused && !inTitle && !menuOpen());
  radio.update(paused ? 0 : dt);
  radioBox.classList.toggle('muted', paused);
  if (!launch.active) updateHover();
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
if (import.meta.env.DEV) window.bolla = { closeMenu, enemyView, lookAtAttack, achievements, weatherView, launch, stats, camera, rig, tutorial, renderer, scene, factoryView, startGame, saveGame, loadGame, menu, dayNight, effects, audio, checkMissions, radio, campaignView, openCampaign, refresh: () => (shapesDirty = true), get world() { return world; }, get meshes() { return meshes; }, get factory() { return factory; }, get missions() { return missions; }, get campaignRun() { return campaignRun; } };
