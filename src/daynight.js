import * as THREE from 'three';

// Day and night: the sun travels over the map, the sky, fog and light colours
// follow it through sunset into a starry night, and at night the machines
// light up the ground around them. A small pool of real point lights goes to
// the machines nearest the camera; every other machine gets a cheap glowing
// patch on the ground instead.

const MOBILE = matchMedia('(pointer: coarse)').matches;
export const DAY_SECONDS = 8 * 60; // one full day and night
const MODE_KEY = 'bolla-daynight';

const C = (hex) => new THREE.Color(hex);
const PALETTES = {
  day: { top: C(0x5f9fcf), horizon: C(0xcfe3ea), fog: C(0xcfe3ea), sun: C(0xffe2b8), sunI: 2.5, sky: C(0xd6ecff), ground: C(0x5a4a30), hemiI: 0.85, exposure: 0.92, env: 0.35 },
  dusk: { top: C(0x3a5590), horizon: C(0xf09060), fog: C(0xd29070), sun: C(0xff8040), sunI: 1.5, sky: C(0xffb890), ground: C(0x4a3424), hemiI: 0.55, exposure: 0.95, env: 0.25 },
  night: { top: C(0x040816), horizon: C(0x141f3e), fog: C(0x111a32), sun: C(0x8fa8ff), sunI: 0.38, sky: C(0x4a5c96), ground: C(0x14141e), hemiI: 0.34, exposure: 1.0, env: 0.08 },
};

const smooth = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};

function radialTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, 'rgba(255,255,255,1)');
  grad.addColorStop(0.35, 'rgba(255,255,255,0.45)');
  grad.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 64, 64);
  return new THREE.CanvasTexture(c);
}

// Light colour and strength per building type at night.
const GLOWS = {
  furnace: { color: 0xff7a26, size: 3.2, light: 1 },
  power: { color: 0xff8a3a, size: 3.4, light: 1 },
  drill: { color: 0xffd9a0, size: 1.8, light: 0.5 },
  assembler: { color: 0xffe2b0, size: 2.2, light: 0.6 },
  constructor: { color: 0x9fd8ff, size: 2.6, light: 0.7 },
  storage: { color: 0x9fd8ff, size: 1.6, light: 0.3 },
  splitter: { color: 0xa0ffd8, size: 1.2, light: 0.2 },
  merger: { color: 0xd8b0ff, size: 1.2, light: 0.2 },
  pump: { color: 0xffd9a0, size: 1.4, light: 0.3 },
  refinery: { color: 0xffa040, size: 3, light: 0.9 },
  station: { color: 0xffe2b0, size: 2.4, light: 0.6 },
};

export function createDayNight({ scene, renderer, sun, hemi, mapHalf }) {
  let mode = 'cycle';
  try {
    mode = localStorage.getItem(MODE_KEY) || 'cycle';
  } catch {}
  let time = 0.02; // fraction of the day, starts in the morning
  let skip = 0; // seconds of fast-forward left
  let night = 0;
  let skyTimer = 0;
  const current = {};
  for (const [k, v] of Object.entries(PALETTES.day)) current[k] = v instanceof THREE.Color ? v.clone() : v;

  // Sky: the same 2×256 vertical gradient as before, redrawn as the light changes.
  const skyCanvas = document.createElement('canvas');
  skyCanvas.width = 2;
  skyCanvas.height = 256;
  const skyCtx = skyCanvas.getContext('2d');
  const skyTex = new THREE.CanvasTexture(skyCanvas);
  skyTex.colorSpace = THREE.SRGBColorSpace;
  scene.background = skyTex;
  const mid = new THREE.Color();
  function drawSky() {
    const grad = skyCtx.createLinearGradient(0, 0, 0, 256);
    mid.copy(current.top).lerp(current.horizon, 0.55);
    grad.addColorStop(0, `#${current.top.getHexString()}`);
    grad.addColorStop(0.65, `#${mid.getHexString()}`);
    grad.addColorStop(1, `#${current.horizon.getHexString()}`);
    skyCtx.fillStyle = grad;
    skyCtx.fillRect(0, 0, 2, 256);
    skyTex.needsUpdate = true;
  }

  // Stars on a dome that travels with the camera.
  const starGeo = new THREE.BufferGeometry();
  const starPos = [];
  for (let i = 0; i < (MOBILE ? 500 : 900); i++) {
    const u = Math.random() * 0.9 + 0.08;
    const a = Math.random() * Math.PI * 2;
    const r = Math.sqrt(1 - u * u);
    starPos.push(Math.cos(a) * r * 300, u * 300, Math.sin(a) * r * 300);
  }
  starGeo.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3));
  const starMat = new THREE.PointsMaterial({ color: 0xdfe8ff, size: MOBILE ? 1.6 : 1.8, sizeAttenuation: false, fog: false, transparent: true, opacity: 0, depthWrite: false });
  const stars = new THREE.Points(starGeo, starMat);
  stars.frustumCulled = false;
  stars.renderOrder = -1;
  scene.add(stars);

  // Glowing patches on the ground under every machine.
  const MAX_GLOWS = 1500;
  const glowMat = new THREE.MeshBasicMaterial({ map: radialTexture(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0, fog: false });
  const glows = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), glowMat, MAX_GLOWS);
  glows.count = 0;
  glows.frustumCulled = false;
  glows.renderOrder = 1;
  scene.add(glows);
  let glowList = []; // [{ b, base: Color }]
  const dummy = new THREE.Object3D();
  const tmp = new THREE.Color();

  function rebuild(factory) {
    glowList = [];
    for (const b of factory.buildings.values()) {
      const kind = GLOWS[b.type];
      if (!kind || glowList.length >= MAX_GLOWS) continue;
      dummy.position.set(b.tile.position.x, b.tile.height + 0.02, b.tile.position.z);
      dummy.scale.setScalar(kind.size);
      dummy.updateMatrix();
      glows.setMatrixAt(glowList.length, dummy.matrix);
      glowList.push({ b, base: new THREE.Color(kind.color), level: 0 });
    }
    glows.count = glowList.length;
    glows.instanceMatrix.needsUpdate = true;
  }

  // A few real lights for the machines closest to the camera.
  const lights = Array.from({ length: MOBILE ? 3 : 6 }, () => {
    const l = new THREE.PointLight(0xffaa66, 0, 7, 2);
    scene.add(l);
    return l;
  });
  let pickTimer = 0;
  let picked = [];

  function pickLights(focus) {
    const scored = [];
    for (const g of glowList) {
      const kind = GLOWS[g.b.type];
      if (kind.light < 0.3) continue;
      const dx = g.b.tile.position.x - focus.x;
      const dz = g.b.tile.position.z - focus.z;
      const work = g.b.state === 'work' ? 1 : 0.4;
      scored.push({ g, score: (dx * dx + dz * dz) / (kind.light * work) });
    }
    scored.sort((a, b) => a.score - b.score);
    picked = scored.slice(0, lights.length).map((s) => s.g);
  }

  function blend(e) {
    // e: the sun's height, -1 … 1.
    const a = PALETTES.dusk;
    const b = e >= 0 ? PALETTES.day : PALETTES.night;
    const k = e >= 0 ? smooth(0, 0.35, e) : smooth(0, -0.22, e);
    for (const key of Object.keys(current)) {
      if (current[key] instanceof THREE.Color) current[key].copy(a[key]).lerp(b[key], k);
      else current[key] = a[key] + (b[key] - a[key]) * k;
    }
  }

  const sunDir = new THREE.Vector3();
  function update(dt, elapsed, focus, camera, factory) {
    if (skip > 0) {
      const fast = Math.min(skip, dt * 40);
      skip -= fast;
      time = (time + fast / DAY_SECONDS) % 1;
    } else if (mode === 'cycle') {
      time = (time + dt / DAY_SECONDS) % 1;
    } else if (mode === 'day') {
      time += (0.25 - time) * Math.min(1, dt * 2);
    } else if (mode === 'night') {
      time += (0.75 - time) * Math.min(1, dt * 2);
    }

    // The sun is up for about two thirds of the day.
    const angle = time * Math.PI * 2;
    const e = Math.max(-1, Math.min(1, Math.sin(angle) + 0.3));
    blend(e);
    night = smooth(0.12, -0.15, e);

    // Sunlight fades out at the horizon, then the moon takes over from the other side.
    const sunUp = e > 0;
    const h = Math.max(0.35, Math.abs(e));
    sunDir.set(Math.cos(angle) * (sunUp ? 1 : -1), h, 0.45).normalize();
    sun.position.copy(sunDir).multiplyScalar(60);
    sun.color.copy(current.sun);
    sun.intensity = current.sunI * (sunUp ? smooth(0, 0.12, e) : smooth(0, -0.15, e));
    hemi.color.copy(current.sky);
    hemi.groundColor.copy(current.ground);
    hemi.intensity = current.hemiI;
    scene.fog.color.copy(current.fog);
    renderer.toneMappingExposure = current.exposure;
    scene.environmentIntensity = current.env;

    skyTimer -= dt;
    if (skyTimer <= 0) {
      skyTimer = 0.2;
      drawSky();
    }

    stars.position.copy(camera.position);
    starMat.opacity = night * 0.9;
    stars.visible = night > 0.01;
    stars.rotation.y = elapsed * 0.003;

    // Ground glows: brighter while a machine works, furnaces flicker.
    glowMat.opacity = night;
    glows.visible = night > 0.01 && glowList.length > 0;
    if (glows.visible) {
      glowList.forEach((g, i) => {
        const working = g.b.state === 'work';
        let target = working ? 0.9 : 0.35;
        if (g.b.type === 'furnace' && working) target = 0.85 + Math.sin(elapsed * 11 + i) * 0.1 + Math.sin(elapsed * 6.3 + i * 2) * 0.08;
        g.level += (target - g.level) * Math.min(1, dt * 4);
        glows.setColorAt(i, tmp.copy(g.base).multiplyScalar(g.level * 0.55));
      });
      if (glows.instanceColor) glows.instanceColor.needsUpdate = true;
    }

    pickTimer -= dt;
    if (pickTimer <= 0) {
      pickTimer = 0.4;
      pickLights(focus);
    }
    lights.forEach((l, i) => {
      const g = picked[i];
      if (!g || night < 0.01) {
        l.intensity = 0;
        return;
      }
      const kind = GLOWS[g.b.type];
      const flicker = g.b.type === 'furnace' ? 0.85 + Math.sin(elapsed * 13 + i) * 0.1 + Math.sin(elapsed * 7.1) * 0.06 : 1;
      l.color.setHex(kind.color);
      l.position.set(g.b.tile.position.x, g.b.tile.height + (g.b.type === 'furnace' ? 0.55 : 0.9), g.b.tile.position.z);
      l.intensity = night * 3.2 * kind.light * (0.4 + g.level * 0.7) * flicker;
    });
  }

  return {
    update,
    rebuild,
    get night() {
      return night;
    },
    get mode() {
      return mode;
    },
    setMode(next) {
      mode = next;
      try {
        localStorage.setItem(MODE_KEY, mode);
      } catch {}
    },
    get time() {
      return time;
    },
    setTime(t) {
      time = t;
    },
    // Fast-forward to the next dusk or dawn.
    skipAhead() {
      const target = night > 0.5 ? 0.98 : 0.6;
      skip = (((target - time + 1) % 1) || 1) * DAY_SECONDS;
    },
    // Clock time for the HUD, with sunrise at 6:00.
    clock() {
      const minutes = Math.floor(((time * 24 + 7.2) % 24) * 60);
      return `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
    },
  };
}
