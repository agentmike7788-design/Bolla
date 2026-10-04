import * as THREE from 'three';
import { TERRAIN, ORES, TILE } from './world.js';
import { CHUNK } from './enemies.js';

// The minimap: the whole island from above, north up. Terrain and ore are drawn
// once per map; buildings, smog, nests, creatures, trains and vehicles a few
// times per second, with the part of the map the camera sees as a frame.
// Clicking or dragging on it moves the camera there.

const SIZE = 200; // CSS pixels
const KIND_COLOR = {
  belt: '#8d9399', splitter: '#8d9399', merger: '#8d9399',
  rail: '#8a6a4a', station: '#b38a5a', signal: '#8a6a4a',
  pipe: '#36323f', pump: '#36323f', tank: '#4a4458', refinery: '#5a4f6e',
  power: '#ffd34d', geo: '#ffd34d', pole: '#c9a93a', solar: '#5b8fd6', wind: '#e6edf2', battery: '#7bd36b',
  drill: '#d9a441',
  furnace: '#e07a2e', assembler: '#e07a2e', constructor: '#f0a050',
  storage: '#5ad1c8', provider: '#5ad1c8', requester: '#5ad1c8', dronePort: '#3fb8a4',
  wall: '#cfc8b8', turret: '#ff6b5b', laser: '#ff6b5b', artillery: '#ff6b5b',
  silo: '#ffffff',
};
const FALLBACK = '#cfcfcf';

export function createMinimap({ root, onPick }) {
  const canvas = root.querySelector('canvas');
  const ctx = canvas.getContext('2d');
  const base = document.createElement('canvas');
  const baseCtx = base.getContext('2d');
  const built = document.createElement('canvas');
  const builtCtx = built.getContext('2d');
  let world = null;
  let origin = { x: 0, z: 0 };
  let scale = 1;
  let builtKey = '';
  const raycaster = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.4);
  const hit = new THREE.Vector3();
  const rgb = (hex) => [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255];

  function resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = canvas.height = Math.round(SIZE * dpr);
    canvas.style.width = canvas.style.height = `${SIZE}px`;
  }
  resize();
  window.addEventListener('resize', resize);

  // Terrain and ore, one pixel per tile, shaded a little by height.
  function setWorld(next) {
    world = next;
    origin = { x: world.tiles[0].position.x, z: world.tiles[0].position.z };
    base.width = base.height = built.width = built.height = world.size;
    const img = baseCtx.createImageData(world.size, world.size);
    for (const t of world.tiles) {
      const [r, g, b] = rgb(t.ore ? ORES[t.ore].color : TERRAIN[t.terrain].color);
      const water = t.terrain === 'water';
      const k = water ? 0.55 : 0.8 + (t.height ?? 0.45) * 0.3;
      const i = (t.z * world.size + t.x) * 4;
      img.data[i] = water ? 40 : r * k;
      img.data[i + 1] = water ? 110 : g * k;
      img.data[i + 2] = water ? 150 : b * k;
      img.data[i + 3] = 255;
    }
    baseCtx.putImageData(img, 0, 0);
    builtKey = '';
  }

  // Buildings, redrawn when the factory changes.
  function drawBuilt(factory) {
    const key = `${factory.buildings.size}:${factory.enemies.ruins.length}:${factory.vehicles.flattened.size}`;
    if (key === builtKey) return;
    builtKey = key;
    builtCtx.clearRect(0, 0, world.size, world.size);
    for (const i of factory.vehicles.flattened) {
      const t = world.tiles[i];
      if (t.terrain !== 'forest' && t.terrain !== 'taiga' && t.terrain !== 'burnt') continue;
      builtCtx.fillStyle = 'rgba(120, 100, 60, 0.45)';
      builtCtx.fillRect(t.x, t.z, 1, 1);
    }
    for (const b of factory.buildings.values()) {
      builtCtx.fillStyle = KIND_COLOR[b.type] ?? FALLBACK;
      for (const i of factory.footprint(b)) builtCtx.fillRect(i % world.size, Math.floor(i / world.size), 1, 1);
    }
    builtCtx.fillStyle = 'rgba(60, 40, 30, 0.85)';
    for (const r of factory.enemies.ruins) builtCtx.fillRect(r.index % world.size, Math.floor(r.index / world.size), 1, 1);
  }

  // Where the camera looks: the four corners of the screen on the ground.
  // Far corners near the horizon are pulled in to a sensible distance.
  function viewFrame(camera, focus) {
    const reach = camera.position.distanceTo(focus) * 1.4;
    const pts = [];
    for (const [x, y] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) {
      raycaster.setFromCamera(ndc.set(x, y), camera);
      const dir = raycaster.ray.direction;
      if (dir.y > -0.03) dir.y = -0.03;
      dir.normalize();
      if (!raycaster.ray.intersectPlane(ground, hit)) return null;
      const d = Math.hypot(hit.x - focus.x, hit.z - focus.z);
      if (d > reach) hit.set(focus.x + ((hit.x - focus.x) * reach) / d, 0, focus.z + ((hit.z - focus.z) * reach) / d);
      pts.push([(hit.x - origin.x) / TILE, (hit.z - origin.z) / TILE]);
    }
    return pts;
  }

  const px = (x) => (x + 0.5) * scale;

  function draw(factory, camera, focus, highlight, time) {
    if (!world || root.hidden || root.classList.contains('closed')) return;
    const W = canvas.width;
    scale = W / world.size;
    drawBuilt(factory);
    ctx.imageSmoothingEnabled = false;
    ctx.clearRect(0, 0, W, W);
    ctx.drawImage(base, 0, 0, W, W);
    const enemies = factory.enemies;
    // Smog as a brown haze where it is thick.
    if (enemies.active) {
      const smog = enemies.smog();
      const chunks = enemies.chunks;
      for (let i = 0; i < smog.length; i++) {
        const a = Math.min(0.45, smog[i] / 40);
        if (a < 0.03) continue;
        ctx.fillStyle = `rgba(110, 80, 40, ${a})`;
        ctx.fillRect((i % chunks) * CHUNK * scale, Math.floor(i / chunks) * CHUNK * scale, CHUNK * scale, CHUNK * scale);
      }
    }
    ctx.drawImage(built, 0, 0, W, W);
    const dot = Math.max(2, scale * 0.9);
    // Trains: a bright block where each one is.
    ctx.fillStyle = '#ffffff';
    for (const t of factory.trains) {
      const i = t.path[Math.round(t.s)];
      if (i === undefined) continue;
      ctx.fillRect(px(i % world.size) - dot, px(Math.floor(i / world.size)) - dot, dot * 2, dot * 2);
    }
    if (enemies.active) {
      // Nests with a dark rim, creatures as red dots.
      for (const n of enemies.nests) {
        ctx.beginPath();
        ctx.arc(px(n.x), px(n.z), Math.max(3, scale * 1.4) * (n.born !== undefined ? 0.75 : 1), 0, Math.PI * 2);
        ctx.fillStyle = '#b04dff';
        ctx.fill();
        ctx.lineWidth = Math.max(1, scale * 0.35);
        ctx.strokeStyle = '#2a1030';
        ctx.stroke();
      }
      ctx.fillStyle = '#ff3b2a';
      for (const c of enemies.creatures) ctx.fillRect(px(c.x) - dot / 2, px(c.z) - dot / 2, dot, dot);
      // A pulsing ring where the last attack was, for a while.
      const last = enemies.lastAttack;
      if (last && factory.time - last.time < 12) {
        const k = (time * 1.4) % 1;
        ctx.beginPath();
        ctx.arc(px(last.x), px(last.z), scale * (2 + k * 6), 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(255, 70, 50, ${1 - k})`;
        ctx.lineWidth = Math.max(1.5, scale * 0.5);
        ctx.stroke();
      }
    }
    // Vehicles: arrows in their heading, the driven one in the signal colour.
    const driving = factory.vehicles.driving;
    for (const v of factory.vehicles.list) {
      const s = Math.max(4, scale * (v.kind === 'panzer' ? 1.6 : 1.3));
      ctx.save();
      ctx.translate(px(v.x), px(v.z));
      ctx.rotate(-v.heading + Math.PI);
      ctx.beginPath();
      ctx.moveTo(0, -s);
      ctx.lineTo(s * 0.7, s * 0.8);
      ctx.lineTo(0, s * 0.4);
      ctx.lineTo(-s * 0.7, s * 0.8);
      ctx.closePath();
      ctx.fillStyle = v === driving || v === highlight ? '#ffd34d' : '#e9f4ff';
      ctx.fill();
      ctx.lineWidth = Math.max(1, scale * 0.3);
      ctx.strokeStyle = '#1d2328';
      ctx.stroke();
      ctx.restore();
    }
    // The camera's view.
    const frame = viewFrame(camera, focus);
    if (frame) {
      ctx.beginPath();
      frame.forEach(([x, z], k) => (k ? ctx.lineTo(px(x), px(z)) : ctx.moveTo(px(x), px(z))));
      ctx.closePath();
      ctx.lineWidth = Math.max(1.5, W / 160);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.85)';
      ctx.stroke();
    }
  }

  // Clicking and dragging moves the camera.
  let dragging = false;
  function pick(e) {
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * world.size - 0.5;
    const z = ((e.clientY - rect.top) / rect.height) * world.size - 0.5;
    onPick(origin.x + x * TILE, origin.z + z * TILE);
  }
  canvas.addEventListener('pointerdown', (e) => {
    if (!world || e.button !== 0) return;
    dragging = true;
    canvas.setPointerCapture(e.pointerId);
    pick(e);
  });
  canvas.addEventListener('pointermove', (e) => dragging && pick(e));
  canvas.addEventListener('pointerup', () => (dragging = false));
  canvas.addEventListener('pointercancel', () => (dragging = false));

  return { setWorld, draw };
}
