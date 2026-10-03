import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { generateWorld, ORES, TERRAIN, MAP_SIZE, TILE } from './world.js';
import { buildWorldMeshes, createSea } from './scenery.js';
import { createCameraRig } from './camera.js';
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

let world;
let meshes;

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
  document.getElementById('seed').textContent = `#${seed}`;
  renderLegend();
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
    li.innerHTML = `<span class="swatch" style="--c:#${ore.color.toString(16).padStart(6, '0')}"></span>
      <span class="name">${ore.name}</span>
      <span class="num">${c.amount.toLocaleString('de-DE')}</span>`;
    li.title = `${c.tiles} Felder`;
    list.append(li);
  }
}

const tileName = document.getElementById('tile-name');
const tileDetail = document.getElementById('tile-detail');

function showTile(tile) {
  if (!tile) {
    marker.visible = false;
    tileName.textContent = 'Maus über die Karte bewegen';
    tileDetail.textContent = '';
    return;
  }
  marker.visible = true;
  marker.position.set(tile.position.x, Math.max(tile.height, 0.28) + 0.03, tile.position.z);
  const terrain = TERRAIN[tile.terrain];
  if (tile.ore) {
    tileName.textContent = ORES[tile.ore].name;
    tileDetail.textContent = `${tile.amount.toLocaleString('de-DE')} Einheiten · Feld ${tile.x}, ${tile.z}`;
  } else {
    tileName.textContent = terrain.name;
    tileDetail.textContent = `${terrain.buildable ? 'Bebaubar' : 'Nicht bebaubar'} · Feld ${tile.x}, ${tile.z}`;
  }
}

const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let pointerInside = false;
const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.4);
const planeHit = new THREE.Vector3();

canvas.addEventListener('pointermove', (e) => {
  const rect = canvas.getBoundingClientRect();
  pointer.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1);
  pointerInside = true;
});
canvas.addEventListener('pointerleave', () => {
  pointerInside = false;
  showTile(null);
});

function updateHover() {
  if (!pointerInside) return;
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.intersectObject(meshes.tiles, false)[0];
  if (hit) {
    showTile(world.tiles[hit.instanceId]);
    return;
  }
  // The ray slipped through the thin gap between two tiles: pick by grid cell instead.
  const point = raycaster.ray.intersectPlane(groundPlane, planeHit);
  const offset = (MAP_SIZE * TILE) / 2;
  const x = point && Math.floor((point.x + offset) / TILE);
  const z = point && Math.floor((point.z + offset) / TILE);
  const inside = point && x >= 0 && z >= 0 && x < MAP_SIZE && z < MAP_SIZE;
  showTile(inside ? world.at(x, z) : null);
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

const timer = new THREE.Timer();
renderer.setAnimationLoop(() => {
  timer.update();
  rig.update(timer.getDelta());
  sea.update(timer.getElapsed());
  updateHover();
  renderer.render(scene, camera);
});

loadWorld(4711);
resize();
