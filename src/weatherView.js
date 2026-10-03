import * as THREE from 'three';
import { TILE } from './world.js';

// Weather you can see: snowflakes, blowing sand or falling ash around the camera,
// steam over the vents, and the volcano that smokes and throws glowing rocks when
// it erupts. The flakes move entirely in the vertex shader: each one wraps round
// inside a box that follows the camera, so the CPU never touches them.

const MOBILE = matchMedia('(pointer: coarse)').matches;
const COUNT = MOBILE ? 1800 : 4500;
const BOX = new THREE.Vector3(56, 22, 56);

// calm: share of the flakes that fall even without a storm.
const KINDS = {
  snow: { color: 0xffffff, size: 0.09, fall: 1.1, wind: [0.9, 0.3], storm: [6, 1.5], calm: 0.22, opacity: 0.9 },
  sand: { color: 0xd8b070, size: 0.075, fall: 0.25, wind: [3, 1], storm: [11, 2.5], calm: 0, opacity: 0.75 },
  ash: { color: 0x4a4440, size: 0.085, fall: 0.8, wind: [0.4, 0.2], storm: [1.5, 0.6], calm: 0.04, opacity: 0.85 },
};
const BIOME_KIND = { snow: 'snow', desert: 'sand', volcano: 'ash' };

const rnd = (a, b) => a + Math.random() * (b - a);

export function createWeatherView({ scene, effects }) {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(COUNT * 3);
  const seed = new Float32Array(COUNT);
  for (let i = 0; i < COUNT; i++) {
    pos[i * 3] = Math.random();
    pos[i * 3 + 1] = Math.random();
    pos[i * 3 + 2] = Math.random();
    seed[i] = Math.random();
  }
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  geo.setAttribute('seed', new THREE.BufferAttribute(seed, 1));
  const uniforms = {
    uTime: { value: 0 },
    uFocus: { value: new THREE.Vector3() },
    uBox: { value: BOX },
    uDrift: { value: new THREE.Vector3() }, // how far the wind and the fall have carried every flake
    uAmount: { value: 0 },
    uSize: { value: 0.1 },
    uScale: { value: 400 },
    uColor: { value: new THREE.Color() },
    uOpacity: { value: 1 },
  };
  const mat = new THREE.ShaderMaterial({
    uniforms,
    vertexShader: /* glsl */ `
      attribute float seed;
      uniform float uTime;
      uniform vec3 uFocus;
      uniform vec3 uBox;
      uniform vec3 uDrift;
      uniform float uAmount;
      uniform float uSize;
      uniform float uScale;
      varying float vFade;
      void main() {
        vec3 p = fract(position + uDrift / uBox + vec3(sin(uTime * 0.7 + seed * 40.0), 0.0, cos(uTime * 0.6 + seed * 30.0)) * 0.004);
        vec3 world = uFocus + (p - vec3(0.5, 0.0, 0.5)) * uBox;
        vec4 mv = viewMatrix * vec4(world, 1.0);
        // Thin out towards the edge of the box and the ground, and drop flakes beyond the amount.
        float edge = 1.0 - smoothstep(0.3, 0.5, max(abs(p.x - 0.5), abs(p.z - 0.5)));
        vFade = edge * smoothstep(0.0, 0.05, p.y) * step(seed, uAmount);
        gl_PointSize = vFade > 0.0 ? uSize * uScale / -mv.z * (0.6 + seed * 0.8) : 0.0;
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */ `
      uniform vec3 uColor;
      uniform float uOpacity;
      varying float vFade;
      void main() {
        float d = length(gl_PointCoord - 0.5) * 2.0;
        if (d > 1.0) discard;
        gl_FragColor = vec4(uColor, smoothstep(1.0, 0.4, d) * vFade * uOpacity);
        #include <colorspace_fragment>
      }`,
    transparent: true,
    depthWrite: false,
  });
  const points = new THREE.Points(geo, mat);
  points.frustumCulled = false;
  points.renderOrder = 4;
  points.visible = false;
  scene.add(points);

  let kind = null;
  let world = null;
  let crater = null; // world position of the crater's lava lake
  let vents = [];
  let emitClock = 0;
  const drift = uniforms.uDrift.value;

  function setWorld(next) {
    world = next;
    kind = KINDS[BIOME_KIND[world.biome]] ?? null;
    points.visible = !!kind;
    if (kind) {
      uniforms.uColor.value.set(kind.color);
      uniforms.uSize.value = kind.size;
    }
    vents = world.tiles.filter((t) => t.vent);
    crater = null;
    if (world.crater) {
      const offset = (world.size * TILE) / 2 - TILE / 2;
      crater = new THREE.Vector3(world.crater.x * TILE - offset, 0.3 + world.crater.radius * 0.95 - 0.4, world.crater.z * TILE - offset);
    }
  }

  // weather: see weatherAt() in biomes.js. `particles` is off when the player
  // turned particle effects off; the flakes stay, they are cheap.
  function update(dt, elapsed, focus, weather, night, factory, particles = true) {
    if (!world) return;
    const s = weather.strength;
    if (kind) {
      const wind = kind.wind[0] + (kind.storm[0] - kind.wind[0]) * s;
      const side = kind.wind[1] + (kind.storm[1] - kind.wind[1]) * s;
      drift.x += wind * dt;
      drift.z += side * dt;
      drift.y -= kind.fall * (1 + s) * dt;
      // Keep the numbers small for the GPU: one whole box further looks the same.
      drift.set(drift.x % BOX.x, drift.y % BOX.y, drift.z % BOX.z);
      uniforms.uTime.value = elapsed;
      uniforms.uFocus.value.set(focus.x, Math.max(0, focus.y - 2), focus.z);
      uniforms.uAmount.value = kind.calm + (1 - kind.calm) * s;
      uniforms.uOpacity.value = kind.opacity * (1 - night * 0.55);
      points.visible = uniforms.uAmount.value > 0.001;
    }
    if (!particles || !effects.group.visible) return;
    emitClock += dt;
    if (emitClock < 0.05) return;
    emitClock = 0;
    // Steam over every free vent near the camera; a plant on it vents its own.
    for (const t of vents) {
      if (factory.get(t) || Math.random() > 0.35) continue;
      const dx = t.position.x - focus.x;
      const dz = t.position.z - focus.z;
      if (dx * dx + dz * dz > 900) continue;
      effects.emit({ x: t.position.x + rnd(-0.1, 0.1), y: t.height + 0.05, z: t.position.z + rnd(-0.1, 0.1), vx: rnd(-0.1, 0.1), vy: rnd(0.4, 0.8), vz: rnd(-0.1, 0.1), life: rnd(1.2, 2), size: 0.14, grow: 2.4, color: effects.color(0xeef0f0, 0.03), gravity: 0.1, drag: 1, fade: 0.35 });
    }
    if (!crater) return;
    // The crater always smokes a little; an eruption sends up a column and glowing rocks.
    const puffs = 0.25 + s * 2.5;
    for (let n = puffs; n > 0; n--) {
      if (Math.random() > n) break;
      effects.emit({ x: crater.x + rnd(-0.6, 0.6), y: crater.y + 0.3, z: crater.z + rnd(-0.6, 0.6), vx: rnd(-0.2, 0.2) + s * 0.4, vy: rnd(1, 1.8) + s * 3, vz: rnd(-0.2, 0.2), life: rnd(2.5, 4) + s * 2, size: 0.5 + s * 0.5, grow: 2.5, color: effects.color(s > 0.2 ? 0x3a3432 : 0x6a6260, 0.06), gravity: 0.05, drag: 0.5, fade: 0.55 });
    }
    if (Math.random() < 0.3 + s) {
      effects.emit({ x: crater.x + rnd(-0.4, 0.4), y: crater.y + 0.2, z: crater.z + rnd(-0.4, 0.4), vx: rnd(-0.3, 0.3), vy: rnd(1, 2), vz: rnd(-0.3, 0.3), life: rnd(0.6, 1.2), size: rnd(0.08, 0.14), grow: -0.5, color: effects.color(0xff7a2a, 0.15), gravity: -1, drag: 0.4 }, true);
    }
    if (s > 0.3 && Math.random() < s * 0.8) {
      const a = Math.random() * Math.PI * 2;
      const v = rnd(2, 4.5);
      effects.emit({ x: crater.x, y: crater.y + 0.3, z: crater.z, vx: Math.cos(a) * v, vy: rnd(6, 10), vz: Math.sin(a) * v, life: rnd(1.6, 2.4), size: rnd(0.18, 0.3), grow: -0.3, color: effects.color(0xff5a1a, 0.1), gravity: -9, drag: 0.1, floor: 0.45 }, true);
    }
  }

  return {
    setWorld,
    update,
    resize(height, fov) {
      uniforms.uScale.value = height / (2 * Math.tan((fov * Math.PI) / 360));
    },
  };
}
