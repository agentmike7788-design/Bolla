import * as THREE from 'three';
import { ORES } from './world.js';

// Particle effects: dust and debris when building, sparks and embers at the
// furnaces, ore chips at the drills, steam at the constructors and fireworks
// for a finished map. Everything lives in two point clouds (one glowing, one
// solid), so hundreds of particles cost just two draw calls.

const MOBILE = matchMedia('(pointer: coarse)').matches;

function pool(max, additive) {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(max * 3);
  const col = new Float32Array(max * 3);
  const size = new Float32Array(max);
  const alpha = new Float32Array(max);
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('size', new THREE.BufferAttribute(size, 1).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('alpha', new THREE.BufferAttribute(alpha, 1).setUsage(THREE.DynamicDrawUsage));
  geo.setDrawRange(0, 0);
  const mat = new THREE.ShaderMaterial({
    uniforms: { uScale: { value: 400 }, uLight: { value: 1 } },
    vertexShader: /* glsl */ `
      attribute float size;
      attribute float alpha;
      attribute vec3 color;
      uniform float uScale;
      varying vec3 vColor;
      varying float vAlpha;
      void main() {
        vec4 mv = modelViewMatrix * vec4(position, 1.0);
        gl_PointSize = size * uScale / -mv.z;
        gl_Position = projectionMatrix * mv;
        vColor = color;
        vAlpha = alpha;
      }`,
    fragmentShader: /* glsl */ `
      uniform float uLight;
      varying vec3 vColor;
      varying float vAlpha;
      void main() {
        vec2 c = gl_PointCoord - 0.5;
        float d = length(c) * 2.0;
        if (d > 1.0) discard;
        float a = ${additive ? 'pow(1.0 - d, 1.6)' : 'smoothstep(1.0, 0.55, d)'} * vAlpha;
        gl_FragColor = vec4(vColor * ${additive ? '1.0' : 'uLight'}, a);
        #include <colorspace_fragment>
      }`,
    transparent: true,
    depthWrite: false,
    blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
  });
  const points = new THREE.Points(geo, mat);
  points.frustumCulled = false;
  points.renderOrder = additive ? 3 : 2;
  const parts = [];
  return { points, geo, mat, parts, max, pos, col, size, alpha };
}

const tmpColor = new THREE.Color();
const rnd = (a, b) => a + Math.random() * (b - a);

export function createEffects({ onMade } = {}) {
  const group = new THREE.Group();
  const glow = pool(MOBILE ? 500 : 1200, true);
  const solid = pool(MOBILE ? 400 : 900, false);
  group.add(solid.points, glow.points);
  const seen = new WeakMap(); // building -> last count of made parts
  let emitClock = 0;

  // p: { x, y, z, vx, vy, vz, life, size, grow, color, gravity, drag, fade }
  function spawn(target, p) {
    if (target.parts.length >= target.max) return;
    p.age = 0;
    target.parts.push(p);
  }

  function color(hex, jitter = 0) {
    tmpColor.set(hex);
    if (jitter) tmpColor.offsetHSL((Math.random() - 0.5) * jitter * 0.2, 0, (Math.random() - 0.5) * jitter);
    return [tmpColor.r, tmpColor.g, tmpColor.b];
  }

  const world = (b, lx, ly, lz) => {
    // Same rotation as the building models: yaw = -dir * 90°.
    const a = -b.dir * (Math.PI / 2);
    const c = Math.cos(a);
    const s = Math.sin(a);
    const p = b.tile.position;
    return [p.x + lx * c + lz * s, b.tile.height + ly, p.z - lx * s + lz * c];
  };

  const effects = {
    // Dust ring on the ground plus a few sparks for machines.
    build(tile, machine) {
      const [x, y, z] = [tile.position.x, tile.height + 0.05, tile.position.z];
      const n = machine ? 18 : 6;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + Math.random() * 0.3;
        const v = rnd(0.8, 1.6);
        spawn(solid, { x, y, z, vx: Math.cos(a) * v, vy: rnd(0.3, 0.9), vz: Math.sin(a) * v, life: rnd(0.5, 0.9), size: rnd(0.12, 0.2), grow: 1.8, color: color(0xb8a98c, 0.15), gravity: -0.6, drag: 3.5 });
      }
      if (!machine) return;
      for (let i = 0; i < 10; i++) {
        spawn(glow, { x, y: y + 0.3, z, vx: rnd(-1.5, 1.5), vy: rnd(1.5, 3), vz: rnd(-1.5, 1.5), life: rnd(0.3, 0.6), size: 0.07, grow: -0.5, color: color(0xffc860), gravity: -7, drag: 0.5 });
      }
    },
    // Broken pieces jump up and fall, with a puff of dust.
    remove(tile, kind) {
      const [x, y, z] = [tile.position.x, tile.height + 0.2, tile.position.z];
      const pieces = kind === 'belt' ? 5 : 14;
      for (let i = 0; i < pieces; i++) {
        spawn(solid, { x: x + rnd(-0.3, 0.3), y, z: z + rnd(-0.3, 0.3), vx: rnd(-1.6, 1.6), vy: rnd(1.5, 3.2), vz: rnd(-1.6, 1.6), life: rnd(0.6, 1), size: rnd(0.07, 0.13), grow: 0, color: color(i % 3 ? 0x3a4046 : 0xf0a830, 0.1), gravity: -9, drag: 0.3, floor: tile.height });
      }
      for (let i = 0; i < 8; i++) {
        spawn(solid, { x, y: y - 0.1, z, vx: rnd(-1, 1), vy: rnd(0.2, 0.7), vz: rnd(-1, 1), life: rnd(0.6, 1.1), size: 0.18, grow: 2, color: color(0x9d9585, 0.1), gravity: -0.3, drag: 3, fade: 0.6 });
      }
    },
    // Colourful bursts over the spot the camera looks at.
    fireworks(center, zoom = 40) {
      const colors = [0xff5a4a, 0xffd34d, 0x6be36b, 0x5aa9ff, 0xd77bff, 0xffffff];
      for (let k = 0; k < 6; k++) {
        const delay = k * 0.35 + Math.random() * 0.2;
        const spread = 2 + zoom * 0.18;
        const cx = center.x + rnd(-spread, spread);
        const cz = center.z + rnd(-spread, spread);
        const cy = zoom * 0.22 + rnd(1, 4);
        const col = colors[k % colors.length];
        const n = MOBILE ? 50 : 90;
        for (let i = 0; i < n; i++) {
          const u = Math.random() * 2 - 1;
          const a = Math.random() * Math.PI * 2;
          const r = Math.sqrt(1 - u * u);
          const v = rnd(3.5, 5);
          spawn(glow, { x: cx, y: cy, z: cz, vx: r * Math.cos(a) * v, vy: u * v, vz: r * Math.sin(a) * v, life: rnd(1.1, 1.8), size: 0.22, grow: -0.4, color: color(col, 0.1), gravity: -2.2, drag: 1.4, delay });
        }
      }
    },

    update(dt, factory, focus, zoom, night) {
      solid.mat.uniforms.uLight.value = 1 - night * 0.7;
      emitClock += dt;
      const emit = emitClock > 0.05;
      if (emit) emitClock = 0;
      const reach = (12 + zoom * 0.6) ** 2;
      // Fewer machine particles when far away or on a phone.
      const rate = (MOBILE ? 0.5 : 1) * Math.min(1, 30 / zoom);

      for (const b of factory.buildings.values()) {
        if (b.type === 'belt' || b.type === 'storage' || b.type === 'pole') continue;
        const dx = b.tile.position.x - focus.x;
        const dz = b.tile.position.z - focus.z;
        const close = dx * dx + dz * dz < reach;
        const made = b.made ?? b.mined ?? 0;
        const last = seen.get(b);
        seen.set(b, made);
        if (!close) continue;
        const finished = last !== undefined && made > last;
        const working = b.state === 'work';
        if (finished) onMade?.(b);

        if (b.type === 'furnace') {
          if (working && emit && Math.random() < 0.7 * rate) {
            // Embers out of the chimney.
            const [x, y, z] = world(b, 0.18 + rnd(-0.04, 0.04), 1.2, 0.2 + rnd(-0.04, 0.04));
            spawn(glow, { x, y, z, vx: rnd(-0.2, 0.2), vy: rnd(0.8, 1.5), vz: rnd(-0.2, 0.2), life: rnd(0.8, 1.6), size: rnd(0.04, 0.07), grow: -0.6, color: color(0xff8a2a, 0.2), gravity: 0.2, drag: 0.6, wobble: 3 });
          }
          if (working && emit && Math.random() < 0.35 * rate) {
            const [x, y, z] = world(b, rnd(-0.12, 0.12), 0.28, -0.31);
            const [fx, , fz] = world(b, 0, 0, -1);
            spawn(glow, { x, y, z, vx: (fx - b.tile.position.x) * rnd(0.6, 1.4) + rnd(-0.4, 0.4), vy: rnd(0.6, 1.6), vz: (fz - b.tile.position.z) * rnd(0.6, 1.4) + rnd(-0.4, 0.4), life: rnd(0.3, 0.6), size: 0.045, grow: -0.6, color: color(0xffd070), gravity: -5, drag: 0.4 });
          }
          if (finished) {
            for (let i = 0; i < 8; i++) {
              const [x, y, z] = world(b, 0, 0.29, -0.32);
              spawn(glow, { x, y, z, vx: rnd(-1.2, 1.2), vy: rnd(0.8, 2.2), vz: rnd(-1.2, 1.2), life: rnd(0.25, 0.5), size: 0.05, grow: -0.6, color: color(0xffe090), gravity: -6, drag: 0.4 });
            }
          }
        } else if (b.type === 'power') {
          if (working && emit && Math.random() < 0.45 * rate) {
            // Dark coal smoke out of the stack, and a few embers.
            const [x, y, z] = world(b, 0.3 + rnd(-0.04, 0.04), 1.48, 0.26 + rnd(-0.04, 0.04));
            spawn(solid, { x, y, z, vx: rnd(-0.12, 0.12), vy: rnd(0.6, 1), vz: rnd(-0.12, 0.12), life: rnd(1.4, 2.2), size: 0.14, grow: 2.2, color: color(0x77736e, 0.08), gravity: 0.15, drag: 0.8, fade: 0.5 });
          }
          if (working && emit && Math.random() < 0.2 * rate) {
            const [x, y, z] = world(b, 0.3, 1.46, 0.26);
            spawn(glow, { x, y, z, vx: rnd(-0.2, 0.2), vy: rnd(0.8, 1.4), vz: rnd(-0.2, 0.2), life: rnd(0.6, 1.2), size: rnd(0.04, 0.06), grow: -0.6, color: color(0xff8a2a, 0.2), gravity: 0.2, drag: 0.6, wobble: 3 });
          }
        } else if (b.type === 'drill') {
          if (working && emit && Math.random() < 0.5 * rate) {
            // Chips of the ore being mined, kicked up around the foot.
            const a = Math.random() * Math.PI * 2;
            const [x, y, z] = [b.tile.position.x + Math.cos(a) * 0.38, b.tile.height + 0.08, b.tile.position.z + Math.sin(a) * 0.38];
            spawn(solid, { x, y, z, vx: Math.cos(a) * rnd(0.4, 1), vy: rnd(0.8, 1.8), vz: Math.sin(a) * rnd(0.4, 1), life: rnd(0.4, 0.7), size: rnd(0.04, 0.07), grow: 0, color: color(ORES[b.tile.ore]?.color ?? 0x888888, 0.15), gravity: -8, drag: 0.5, floor: b.tile.height });
          }
          if (working && emit && Math.random() < 0.15 * rate) {
            spawn(solid, { x: b.tile.position.x + rnd(-0.3, 0.3), y: b.tile.height + 0.05, z: b.tile.position.z + rnd(-0.3, 0.3), vx: rnd(-0.3, 0.3), vy: rnd(0.2, 0.5), vz: rnd(-0.3, 0.3), life: rnd(0.7, 1.2), size: 0.16, grow: 1.6, color: color(0xa89a80, 0.1), gravity: 0, drag: 1.5, fade: 0.45 });
          }
        } else if (b.type === 'assembler' && finished) {
          // Sparks squirt out under the press head.
          for (let i = 0; i < 12; i++) {
            const a = Math.random() * Math.PI * 2;
            const [x, y, z] = world(b, 0, 0.32, 0.04);
            spawn(glow, { x, y, z, vx: Math.cos(a) * rnd(1, 2.5), vy: rnd(0.3, 1.5), vz: Math.sin(a) * rnd(1, 2.5), life: rnd(0.2, 0.45), size: 0.04, grow: -0.7, color: color(0xfff0b0), gravity: -7, drag: 0.6 });
          }
        } else if (b.type === 'constructor') {
          if (working && emit && Math.random() < 0.18 * rate) {
            const [x, y, z] = world(b, rnd(-0.2, 0.2), 0.9, 0.1);
            spawn(solid, { x, y, z, vx: rnd(-0.1, 0.1), vy: rnd(0.5, 0.8), vz: rnd(-0.1, 0.1), life: rnd(1, 1.6), size: 0.12, grow: 2.4, color: color(0xe8eef0, 0.05), gravity: 0.1, drag: 1, fade: 0.45 });
          }
          if (finished) {
            for (let i = 0; i < 6; i++) {
              const [x, y, z] = world(b, rnd(-0.15, 0.15), 0.25, -0.4);
              spawn(glow, { x, y, z, vx: rnd(-0.6, 0.6), vy: rnd(0.8, 1.6), vz: rnd(-0.6, 0.6), life: rnd(0.3, 0.6), size: 0.06, grow: -0.5, color: color(0x8fd8ff), gravity: -4, drag: 0.6 });
            }
          }
        }
      }

      step(glow, dt);
      step(solid, dt);
    },

    // Called on resize so points keep their world size.
    resize(height, fov) {
      const scale = height / (2 * Math.tan((fov * Math.PI) / 360));
      glow.mat.uniforms.uScale.value = scale;
      solid.mat.uniforms.uScale.value = scale;
    },

    clear() {
      glow.parts.length = 0;
      solid.parts.length = 0;
      glow.geo.setDrawRange(0, 0);
      solid.geo.setDrawRange(0, 0);
    },
  };

  function step(target, dt) {
    const { parts, pos, col, size, alpha } = target;
    let n = 0;
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      if (p.delay > 0) {
        p.delay -= dt;
        parts[n++] = p;
        continue;
      }
      p.age += dt;
      if (p.age >= p.life) continue;
      const k = Math.exp(-p.drag * dt);
      p.vx *= k;
      p.vz *= k;
      p.vy = p.vy * k + p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.z += p.vz * dt;
      if (p.wobble) p.x += Math.sin(p.age * p.wobble + i) * 0.003;
      if (p.floor !== undefined && p.y < p.floor + 0.03) {
        p.y = p.floor + 0.03;
        p.vy *= -0.3;
        p.vx *= 0.5;
        p.vz *= 0.5;
      }
      parts[n++] = p;
    }
    parts.length = n;

    let drawn = 0;
    for (const p of parts) {
      if (p.delay > 0) continue;
      const t = p.age / p.life;
      pos[drawn * 3] = p.x;
      pos[drawn * 3 + 1] = p.y;
      pos[drawn * 3 + 2] = p.z;
      col[drawn * 3] = p.color[0];
      col[drawn * 3 + 1] = p.color[1];
      col[drawn * 3 + 2] = p.color[2];
      size[drawn] = p.size * Math.max(0.05, 1 + p.grow * t);
      alpha[drawn] = (p.fade ?? 1) * Math.min(1, t * 8) * (1 - t * t);
      drawn++;
    }
    target.geo.setDrawRange(0, drawn);
    for (const name of ['position', 'color', 'size', 'alpha']) {
      const attr = target.geo.attributes[name];
      attr.clearUpdateRanges();
      attr.addUpdateRange(0, drawn * attr.itemSize);
      attr.needsUpdate = true;
    }
  }

  return { group, ...effects };
}
