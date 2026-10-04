import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { TILE } from './world.js';
import { CHUNK } from './enemies.js';

// 3D view of the enemies: creatures, nests with their creep, the smog over the
// factory, health bars, tracers and laser beams, and the rubble of torn-down
// buildings. Shots, hits and deaths come from the simulation as events (fx);
// `onFx(event, position)` lets the game play a sound for each.

const KIND_LOOK = {
  crawler: { color: 0x7a3a26, scale: 1.3, sac: false },
  spitter: { color: 0x58702c, scale: 1.45, sac: true },
  brute: { color: 0x3c2a4c, scale: 2.2, sac: false },
};
const MAX_PER_KIND = 300;
const MAX_BARS = 400;
const MAX_LINES = 160;
const MAX_RUINS = 400;
const MAX_SHELLS = 80;
const BIG = new Set(['silo', 'artillery']);
const flat = (color, extra) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.1, flatShading: true, ...extra });

// A beetle facing +z: abdomen, thorax, head with mandibles; legs in two sets of
// three that swing against each other while it walks.
function creatureParts() {
  const sphere = (r, x, y, z, sx = 1, sy = 1, sz = 1) => new THREE.SphereGeometry(r, 9, 7).scale(sx, sy, sz).translate(x, y, z);
  const body = mergeGeometries([
    sphere(0.15, 0, 0.19, -0.13, 1, 0.78, 1.35),
    sphere(0.095, 0, 0.18, 0.07, 1.05, 0.85, 1),
    sphere(0.075, 0, 0.16, 0.19, 1, 0.9, 1),
    ...[-1, 1].map((s) => new THREE.ConeGeometry(0.022, 0.12, 5).rotateX(Math.PI / 2).rotateY(-s * 0.5).translate(s * 0.04, 0.13, 0.28)),
    // Ridges on the back.
    ...[-0.2, -0.1, 0].map((z) => new THREE.BoxGeometry(0.2, 0.025, 0.035).translate(0, 0.3 + z * 0.15, z - 0.05)),
  ]);
  const leg = (side, z, swing) =>
    mergeGeometries([
      new THREE.BoxGeometry(0.2, 0.022, 0.022).translate(0.1, 0, 0).rotateZ(0.5).translate(0, 0, 0),
      new THREE.BoxGeometry(0.2, 0.02, 0.02).translate(0.1, 0, 0).rotateZ(-0.9).translate(0.17, 0.1, 0),
    ])
      .rotateY(swing)
      .scale(side, 1, 1)
      .translate(side * 0.08, 0.15, z);
  const legsA = mergeGeometries([leg(-1, 0.12, -0.35), leg(1, 0.03, 0), leg(-1, -0.08, 0.35)]);
  const legsB = mergeGeometries([leg(1, 0.12, -0.35), leg(-1, 0.03, 0), leg(1, -0.08, 0.35)]);
  const eyes = mergeGeometries([-1, 1].map((s) => new THREE.SphereGeometry(0.022, 6, 4).translate(s * 0.045, 0.2, 0.24)));
  const sac = sphere(0.12, 0, 0.27, -0.2, 1, 0.8, 1.1);
  return { body, legsA, legsB, eyes, sac };
}

// A nest: a lumpy mound with holes, glowing egg sacs and bone spikes, on a
// circle of purple creep.
function nestModel(seed) {
  let r = seed * 1000;
  const rand = () => ((r = (r * 9301 + 49297) % 233280) / 233280);
  const group = new THREE.Group();
  const mound = new THREE.SphereGeometry(0.95, 14, 9, 0, Math.PI * 2, 0, Math.PI / 2);
  const pos = mound.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    const k = 0.85 + rand() * 0.3;
    pos.setXYZ(i, pos.getX(i) * k, pos.getY(i) * (0.55 + rand() * 0.15), pos.getZ(i) * k);
  }
  mound.computeVertexNormals();
  const mat = flat(0x4a3044, { roughness: 0.85 });
  const mesh = new THREE.Mesh(mound, mat);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  group.add(mesh);
  const creep = new THREE.Mesh(new THREE.CircleGeometry(2.4, 24).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x5a2f58, roughness: 1, transparent: true, opacity: 0.55, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2 }));
  creep.position.y = 0.05;
  creep.receiveShadow = true;
  group.add(creep);
  const holes = new THREE.MeshBasicMaterial({ color: 0x0d0709 });
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * Math.PI * 2 + rand();
    const hole = new THREE.Mesh(new THREE.CircleGeometry(0.15, 10), holes);
    hole.position.set(Math.cos(a) * 0.62, 0.32, Math.sin(a) * 0.62);
    hole.lookAt(Math.cos(a) * 3, 1.4, Math.sin(a) * 3);
    group.add(hole);
  }
  const eggMat = new THREE.MeshStandardMaterial({ color: 0x3a1450, emissive: 0xb04dff, emissiveIntensity: 1, roughness: 0.3 });
  for (let i = 0; i < 6; i++) {
    const a = rand() * Math.PI * 2;
    const d = 0.25 + rand() * 0.55;
    const egg = new THREE.Mesh(new THREE.SphereGeometry(0.1 + rand() * 0.07, 8, 6).scale(1, 1.3, 1), eggMat);
    egg.position.set(Math.cos(a) * d, 0.42 - d * 0.35, Math.sin(a) * d);
    group.add(egg);
  }
  const bone = flat(0xd6c8aa, { roughness: 0.7 });
  for (let i = 0; i < 7; i++) {
    const a = (i / 7) * Math.PI * 2 + rand() * 0.5;
    const spike = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.55 + rand() * 0.35, 5), bone);
    spike.position.set(Math.cos(a) * 0.8, 0.25, Math.sin(a) * 0.8);
    spike.rotation.set(Math.sin(a) * 0.6, 0, -Math.cos(a) * 0.6);
    spike.castShadow = true;
    group.add(spike);
  }
  return { group, eggMat, mat, owned: [mound, mat, creep.geometry, creep.material, eggMat] };
}

export function createEnemyView({ effects, onFx }) {
  const group = new THREE.Group();
  const dummy = new THREE.Object3D();
  const parts = creatureParts();
  const kinds = {};
  const eyeMat = new THREE.MeshStandardMaterial({ color: 0x220000, emissive: 0xff4a1a, emissiveIntensity: 2 });
  const sacMat = new THREE.MeshStandardMaterial({ color: 0x2a4a10, emissive: 0x9cff3a, emissiveIntensity: 0.9, roughness: 0.3 });
  const instanced = (geo, mat, max, shadow = true) => {
    const mesh = new THREE.InstancedMesh(geo, mat, max);
    mesh.count = 0;
    mesh.castShadow = shadow;
    mesh.frustumCulled = false;
    group.add(mesh);
    return mesh;
  };
  for (const [kind, look] of Object.entries(KIND_LOOK)) {
    const mat = flat(look.color, { roughness: 0.45, metalness: 0.25 });
    kinds[kind] = {
      body: instanced(parts.body, mat, MAX_PER_KIND),
      legsA: instanced(parts.legsA, mat, MAX_PER_KIND),
      legsB: instanced(parts.legsB, mat, MAX_PER_KIND),
    };
  }
  const eyes = instanced(parts.eyes, eyeMat, MAX_PER_KIND * 3, false);
  const sacs = instanced(parts.sac, sacMat, MAX_PER_KIND, false);

  // Health bars: a dark back and a coloured fill, turned to the camera.
  const barGeo = new THREE.PlaneGeometry(1, 1);
  const barBack = instanced(barGeo, new THREE.MeshBasicMaterial({ color: 0x111111, transparent: true, opacity: 0.7, depthWrite: false }), MAX_BARS, false);
  const barFill = instanced(barGeo, new THREE.MeshBasicMaterial({ color: 0xffffff, depthWrite: false }), MAX_BARS, false);
  barBack.renderOrder = barFill.renderOrder = 3;
  const barColor = new THREE.Color();

  // Tracers and beams: thin boxes from muzzle to target, gone after a blink.
  const lineGeo = new THREE.BoxGeometry(1, 1, 1).translate(0, 0, 0.5);
  const tracers = instanced(lineGeo, new THREE.MeshBasicMaterial({ color: 0xffd27a, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }), MAX_LINES, false);
  const beams = instanced(lineGeo, new THREE.MeshBasicMaterial({ color: 0xff4030, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false }), MAX_LINES, false);
  const lines = []; // { laser, from, to, life }

  // Artillery shells in the air, on a high arc with a smoke trail.
  const shellGeo = new THREE.SphereGeometry(0.11, 8, 6).scale(1, 1, 2.2);
  const shellMesh = instanced(shellGeo, new THREE.MeshStandardMaterial({ color: 0x2a2a24, emissive: 0xff7a2a, emissiveIntensity: 0.6, roughness: 0.5 }), MAX_SHELLS, false);
  const shellPos = new THREE.Vector3();
  const shellNext = new THREE.Vector3();

  // Rubble where creatures tore a building down, until it is rebuilt.
  const rubbleGeo = mergeGeometries([
    new THREE.CircleGeometry(0.55, 12).rotateX(-Math.PI / 2).translate(0, 0.02, 0),
    new THREE.BoxGeometry(0.3, 0.12, 0.22).rotateY(0.4).translate(-0.15, 0.08, 0.1),
    new THREE.BoxGeometry(0.22, 0.18, 0.2).rotateY(-0.7).translate(0.18, 0.1, -0.08),
    new THREE.BoxGeometry(0.4, 0.05, 0.08).rotateY(1.1).rotateZ(0.3).translate(0.05, 0.1, -0.2),
    new THREE.DodecahedronGeometry(0.09).translate(-0.1, 0.07, -0.18),
  ].map((g) => (g.index ? g.toNonIndexed() : g)));
  const rubble = instanced(rubbleGeo, flat(0x3a3633, { roughness: 1 }), MAX_RUINS);
  rubble.receiveShadow = true;

  // Smog: a hazy brown layer over the chunks, thicker where the factory works.
  let smogTex = null;
  let smogMesh = null;
  let smogData = null;
  let smogTimer = 0;
  let strongSmog = false;

  let world = null;
  let origin = { x: 0, z: 0 };
  const nestViews = new Map(); // nest id -> view
  let ruinsSeen = -1;

  function setWorld(next, chunks) {
    clear();
    world = next;
    origin = { x: world.tiles[0].position.x, z: world.tiles[0].position.z };
    if (smogMesh) {
      group.remove(smogMesh);
      smogMesh.geometry.dispose();
      smogMesh.material.dispose();
      smogTex.dispose();
    }
    smogData = new Uint8Array(chunks * chunks * 4);
    smogTex = new THREE.DataTexture(smogData, chunks, chunks, THREE.RGBAFormat);
    smogTex.magFilter = smogTex.minFilter = THREE.LinearFilter;
    smogTex.needsUpdate = true;
    const span = chunks * CHUNK * TILE;
    smogMesh = new THREE.Mesh(
      new THREE.PlaneGeometry(span, span).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color: 0x6e5c3e, alphaMap: smogTex, transparent: true, opacity: 1, depthWrite: false }),
    );
    smogMesh.position.set(origin.x - TILE / 2 + span / 2, 1.45, origin.z - TILE / 2 + span / 2);
    smogMesh.renderOrder = 2;
    group.add(smogMesh);
  }

  const wx = (x) => origin.x + x * TILE;
  const wz = (z) => origin.z + z * TILE;
  const groundAt = (x, z) => {
    const t = world.tiles[Math.max(0, Math.min(world.size - 1, Math.round(z))) * world.size + Math.max(0, Math.min(world.size - 1, Math.round(x)))];
    return t?.height ?? 0.4;
  };

  function updateSmog(enemies) {
    const smog = enemies.smog();
    const n = enemies.chunks;
    const k = strongSmog ? 1.6 : 1;
    for (let cz = 0; cz < n; cz++) {
      for (let cx = 0; cx < n; cx++) {
        const v = smog[cz * n + cx];
        // The texture's first row is the south edge of the plane.
        const o = ((n - 1 - cz) * n + cx) * 4;
        const a = v < 0.5 ? 0 : Math.min(1, v / 18) ** 0.8 * 0.55 * k;
        smogData[o] = smogData[o + 1] = smogData[o + 2] = Math.round(Math.min(1, a) * 255);
        smogData[o + 3] = 255;
      }
    }
    smogTex.needsUpdate = true;
  }

  function syncNests(enemies, elapsed, night) {
    const alive = new Set();
    for (const n of enemies.nests) {
      alive.add(n.id);
      let v = nestViews.get(n.id);
      if (!v) {
        v = nestModel(n.seed ?? 0.5);
        v.group.position.set(wx(n.x), groundAt(n.x, n.z) - 0.02, wz(n.z));
        v.group.rotation.y = (n.seed ?? 0) * 10;
        group.add(v.group);
        nestViews.set(n.id, v);
      }
      // Eggs pulse; faster and redder while the nest is angry or under fire.
      const angry = Math.min(1, n.anger / 45);
      const hurt = n.hp < n.max;
      v.eggMat.emissiveIntensity = (0.6 + angry * 0.8 + Math.sin(elapsed * (2 + angry * 4) + n.id) * 0.4) * (1 + night);
      v.mat.emissive.setHex(hurt ? 0x401010 : 0x000000);
      // A young nest grows as it heals into its full size.
      v.group.scale.setScalar(n.born !== undefined ? 0.45 + 0.55 * Math.min(1, n.hp / n.max) : 1);
    }
    for (const [id, v] of nestViews) {
      if (alive.has(id)) continue;
      group.remove(v.group);
      for (const o of v.owned) o.dispose();
      nestViews.delete(id);
    }
  }

  function drawCreatures(enemies, elapsed) {
    const counts = Object.fromEntries(Object.keys(kinds).map((k) => [k, 0]));
    let e = 0;
    let s = 0;
    for (const c of enemies.creatures) {
      const look = KIND_LOOK[c.kind];
      const set = kinds[c.kind];
      const i = counts[c.kind];
      if (!set || i >= MAX_PER_KIND) continue;
      counts[c.kind]++;
      const biting = c.bite !== null;
      const lunge = biting ? Math.max(0, Math.sin(elapsed * 9 + c.id)) * 0.08 : 0;
      dummy.position.set(wx(c.x) + Math.sin(c.heading) * lunge, groundAt(c.x, c.z) + (biting ? 0 : Math.abs(Math.sin(c.walk)) * 0.02), wz(c.z) + Math.cos(c.heading) * lunge);
      dummy.rotation.set(biting ? 0.12 : 0, c.heading, 0);
      dummy.scale.setScalar(look.scale);
      dummy.updateMatrix();
      set.body.setMatrixAt(i, dummy.matrix);
      eyes.setMatrixAt(e++, dummy.matrix);
      if (look.sac) sacs.setMatrixAt(s++, dummy.matrix);
      // The legs: one set forward while the other swings back.
      const swing = Math.sin(c.walk) * 0.35 + (biting ? Math.sin(elapsed * 14) * 0.15 : 0);
      dummy.rotateY(swing);
      dummy.updateMatrix();
      set.legsA.setMatrixAt(i, dummy.matrix);
      dummy.rotateY(-swing * 2);
      dummy.updateMatrix();
      set.legsB.setMatrixAt(i, dummy.matrix);
    }
    for (const [k, set] of Object.entries(kinds)) {
      for (const mesh of Object.values(set)) {
        mesh.count = counts[k];
        mesh.instanceMatrix.needsUpdate = true;
      }
    }
    eyes.count = e;
    sacs.count = s;
    eyes.instanceMatrix.needsUpdate = sacs.instanceMatrix.needsUpdate = true;
    sacMat.emissiveIntensity = 0.7 + Math.sin(elapsed * 5) * 0.3;
  }

  function drawBars(factory, camera) {
    let n = 0;
    const bar = (x, y, z, frac, width) => {
      if (n >= MAX_BARS) return;
      dummy.quaternion.copy(camera.quaternion);
      dummy.position.set(x, y, z);
      dummy.scale.set(width + 0.04, 0.11, 1);
      dummy.updateMatrix();
      barBack.setMatrixAt(n, dummy.matrix);
      // The fill shrinks towards the left end of the bar.
      dummy.translateX((-(1 - frac) * width) / 2);
      dummy.translateZ(0.001);
      dummy.scale.set(Math.max(0.001, width * frac), 0.07, 1);
      dummy.updateMatrix();
      barFill.setMatrixAt(n, dummy.matrix);
      barColor.setHSL(frac * 0.33, 0.85, 0.5);
      barFill.setColorAt(n, barColor);
      n++;
    };
    const enemies = factory.enemies;
    for (const b of enemies.damaged) {
      if (b.hp === undefined || factory.at(b.tile.x, b.tile.z) !== b) continue;
      const big = BIG.has(b.type);
      bar(b.tile.position.x, b.tile.height + (big ? 3.5 : 1.25), b.tile.position.z, Math.max(0, b.hp / enemies.maxHp(b)), big ? 1.6 : 0.8);
    }
    for (const nest of enemies.nests) if (nest.hp < nest.max) bar(wx(nest.x), groundAt(nest.x, nest.z) + 1.3, wz(nest.z), nest.hp / nest.max, 1.4);
    for (const c of enemies.creatures) if (c.hp < c.max) bar(wx(c.x), groundAt(c.x, c.z) + 0.45 * KIND_LOOK[c.kind].scale, wz(c.z), c.hp / c.max, 0.4 * KIND_LOOK[c.kind].scale);
    barBack.count = barFill.count = n;
    barBack.instanceMatrix.needsUpdate = barFill.instanceMatrix.needsUpdate = true;
    if (barFill.instanceColor) barFill.instanceColor.needsUpdate = true;
  }

  const rnd = (a, b) => a + Math.random() * (b - a);
  const from = new THREE.Vector3();
  const to = new THREE.Vector3();

  // Turns the simulation's events into tracers, beams and particles.
  function playFx(enemies, factory) {
    for (const f of enemies.fx) {
      const x = wx(f.x);
      const z = wz(f.z);
      const y = groundAt(f.x, f.z);
      if (f.type === 'bullet' || f.type === 'laser') {
        const laser = f.type === 'laser';
        const aim = f.from?.aim ?? 0;
        // From the muzzle, which sits in front of the turning head.
        from.set(x - Math.sin(aim) * (laser ? 0.4 : 0.6), y + (laser ? 0.86 : 0.6), z - Math.cos(aim) * (laser ? 0.4 : 0.6));
        to.set(wx(f.x2) + rnd(-0.08, 0.08), groundAt(f.x2, f.z2) + 0.2, wz(f.z2) + rnd(-0.08, 0.08));
        if (lines.length < MAX_LINES) lines.push({ laser, from: from.clone(), to: to.clone(), life: laser ? 0.12 : 0.06 });
        // Sparks or a sizzle where it hits.
        for (let i = 0; i < (laser ? 3 : 2); i++) {
          effects.emit({ x: to.x, y: to.y, z: to.z, vx: rnd(-1.5, 1.5), vy: rnd(0.5, 2), vz: rnd(-1.5, 1.5), life: rnd(0.15, 0.3), size: 0.06, grow: -0.5, color: effects.color(laser ? 0xff6040 : 0xffd27a), gravity: -6, drag: 1 }, true);
        }
      } else if (f.type === 'acid') {
        // A glob of acid in an arc.
        const T = 0.4;
        const dx = wx(f.x2) - x;
        const dz = wz(f.z2) - z;
        effects.emit({ x, y: y + 0.3, z, vx: dx / T, vy: 4, vz: dz / T, life: T, size: 0.16, grow: -0.2, color: effects.color(0x9cff3a), gravity: -20, drag: 0 }, true);
      } else if (f.type === 'death') {
        // Green goo and bits of shell.
        const big = f.kind === 'brute';
        for (let i = 0; i < (big ? 22 : 12); i++) {
          effects.emit({ x, y: y + 0.15, z, vx: rnd(-1.6, 1.6), vy: rnd(0.8, 2.6), vz: rnd(-1.6, 1.6), life: rnd(0.5, 0.9), size: rnd(0.06, 0.12) * (big ? 1.4 : 1), grow: 0, color: effects.color(i % 3 ? 0x6fbf2a : 0x3a2a20, 0.2), gravity: -9, drag: 0.4, floor: y });
        }
      } else if (f.type === 'shellFire') {
        // Fire and a cloud of smoke out of the muzzle, high above the gun.
        const aim = f.from?.aim ?? 0;
        const mx = x - Math.sin(aim) * 1.9 * TILE;
        const mz = z - Math.cos(aim) * 1.9 * TILE;
        const my = y + 2.2;
        for (let i = 0; i < 14; i++) {
          effects.emit({ x: mx, y: my, z: mz, vx: -Math.sin(aim) * rnd(2, 5) + rnd(-0.6, 0.6), vy: rnd(1, 3), vz: -Math.cos(aim) * rnd(2, 5) + rnd(-0.6, 0.6), life: rnd(0.15, 0.3), size: rnd(0.2, 0.35), grow: 1.5, color: effects.color(i % 2 ? 0xff9a2a : 0xffe080, 0.15), gravity: 0, drag: 4 }, true);
        }
        for (let i = 0; i < 16; i++) {
          effects.emit({ x: mx + rnd(-0.2, 0.2), y: my, z: mz + rnd(-0.2, 0.2), vx: -Math.sin(aim) * rnd(0.5, 2.5) + rnd(-0.8, 0.8), vy: rnd(0.2, 1.4), vz: -Math.cos(aim) * rnd(0.5, 2.5) + rnd(-0.8, 0.8), life: rnd(1.4, 2.6), size: rnd(0.35, 0.6), grow: 2.2, color: effects.color(0x8a8478, 0.1), gravity: 0.15, drag: 1.4, fade: 0.6 });
        }
        // Dust kicked up around the pad.
        for (let i = 0; i < 10; i++) {
          const a = rnd(0, Math.PI * 2);
          effects.emit({ x: x + Math.cos(a) * 1.3, y: y + 0.15, z: z + Math.sin(a) * 1.3, vx: Math.cos(a) * rnd(1, 2), vy: rnd(0.1, 0.5), vz: Math.sin(a) * rnd(1, 2), life: rnd(0.8, 1.4), size: rnd(0.25, 0.4), grow: 1.5, color: effects.color(0xb5a27a, 0.1), gravity: 0, drag: 2, fade: 0.5 });
        }
      } else if (f.type === 'tankFire') {
        // The tank's cannon: a flash and a puff of smoke at the muzzle.
        const mx = x + Math.sin(f.aim) * 0.95;
        const mz = z + Math.cos(f.aim) * 0.95;
        for (let i = 0; i < 10; i++) {
          effects.emit({ x: mx, y: y + 0.55, z: mz, vx: Math.sin(f.aim) * rnd(2, 4) + rnd(-0.5, 0.5), vy: rnd(0.2, 1), vz: Math.cos(f.aim) * rnd(2, 4) + rnd(-0.5, 0.5), life: rnd(0.1, 0.22), size: rnd(0.15, 0.25), grow: 1.5, color: effects.color(i % 2 ? 0xff9a2a : 0xffe080, 0.15), gravity: 0, drag: 4 }, true);
        }
        for (let i = 0; i < 8; i++) {
          effects.emit({ x: mx, y: y + 0.55, z: mz, vx: Math.sin(f.aim) * rnd(0.3, 1.5) + rnd(-0.4, 0.4), vy: rnd(0.2, 0.8), vz: Math.cos(f.aim) * rnd(0.3, 1.5) + rnd(-0.4, 0.4), life: rnd(0.9, 1.5), size: rnd(0.22, 0.38), grow: 1.8, color: effects.color(0x8a8478, 0.1), gravity: 0.1, drag: 1.5, fade: 0.6 });
        }
      } else if (f.type === 'bump') {
        // A vehicle crashed into something: dust and a few bits.
        for (let i = 0; i < 10; i++) {
          effects.emit({ x, y: y + 0.25, z, vx: rnd(-1.2, 1.2), vy: rnd(0.4, 1.6), vz: rnd(-1.2, 1.2), life: rnd(0.5, 0.9), size: rnd(0.12, 0.22), grow: 1.4, color: effects.color(0x9d9585, 0.1), gravity: -1, drag: 2, fade: 0.6 });
        }
      } else if (f.type === 'nestBorn') {
        // The ground bursts open: purple goo and egg shells.
        for (let i = 0; i < 26; i++) {
          effects.emit({ x, y: y + 0.2, z, vx: rnd(-2, 2), vy: rnd(1, 3.5), vz: rnd(-2, 2), life: rnd(0.6, 1.1), size: rnd(0.08, 0.16), grow: 0, color: effects.color(i % 3 ? 0xb04dff : 0x4a3044, 0.2), gravity: -9, drag: 0.4, floor: y });
        }
      } else if (f.type === 'nestDeath' || f.type === 'boom' || f.type === 'shellHit') {
        // Fire, smoke and flying debris.
        const big = (f.type !== 'boom' || f.big) && !f.small;
        if (f.type === 'shellHit') {
          // A shell digs in: a fountain of earth and a flash.
          for (let i = 0; i < 26; i++) {
            effects.emit({ x: x + rnd(-0.3, 0.3), y: y + 0.2, z: z + rnd(-0.3, 0.3), vx: rnd(-2.2, 2.2), vy: rnd(3, 7), vz: rnd(-2.2, 2.2), life: rnd(0.8, 1.4), size: rnd(0.08, 0.18), grow: 0, color: effects.color(0x4a3a28, 0.15), gravity: -12, drag: 0.3, floor: y });
          }
          for (let i = 0; i < 8; i++) {
            effects.emit({ x, y: y + 0.4, z, vx: rnd(-1, 1), vy: rnd(0, 1), vz: rnd(-1, 1), life: 0.18, size: rnd(0.8, 1.3), grow: 3, color: effects.color(0xfff0b0, 0.05), gravity: 0, drag: 3 }, true);
          }
        }
        for (let i = 0; i < (big ? 40 : 22); i++) {
          effects.emit({ x, y: y + 0.3, z, vx: rnd(-2.5, 2.5), vy: rnd(1, 4), vz: rnd(-2.5, 2.5), life: rnd(0.3, 0.7), size: rnd(0.12, 0.25) * (big ? 1.4 : 1), grow: 1, color: effects.color(i % 2 ? 0xff9a2a : 0xffd060, 0.2), gravity: -2, drag: 2.5 }, true);
        }
        for (let i = 0; i < (big ? 18 : 10); i++) {
          effects.emit({ x: x + rnd(-0.3, 0.3), y: y + 0.4, z: z + rnd(-0.3, 0.3), vx: rnd(-0.6, 0.6), vy: rnd(0.6, 1.6), vz: rnd(-0.6, 0.6), life: rnd(1.2, 2.2), size: rnd(0.3, 0.5), grow: 2.5, color: effects.color(f.type === 'nestDeath' ? 0x4a2a44 : 0x3a3633, 0.1), gravity: 0.2, drag: 1.2, fade: 0.7 });
        }
        for (let i = 0; i < 12; i++) {
          effects.emit({ x, y: y + 0.3, z, vx: rnd(-3, 3), vy: rnd(2, 5), vz: rnd(-3, 3), life: rnd(0.7, 1.2), size: rnd(0.06, 0.12), grow: 0, color: effects.color(f.type === 'nestDeath' ? 0xd6c8aa : 0x2a2f34, 0.1), gravity: -10, drag: 0.2, floor: y });
        }
      }
      onFx?.(f, { x, y, z });
    }
    enemies.fx.length = 0;
  }

  function drawLines(dt) {
    let t = 0;
    let b = 0;
    for (const l of lines) l.life -= dt;
    for (let i = lines.length - 1; i >= 0; i--) if (lines[i].life <= 0) lines.splice(i, 1);
    for (const l of lines) {
      dummy.position.copy(l.from);
      dummy.scale.set(1, 1, 1);
      dummy.lookAt(l.to);
      const len = l.from.distanceTo(l.to);
      const w = l.laser ? 0.05 : 0.025;
      dummy.scale.set(w, w, len);
      dummy.updateMatrix();
      if (l.laser) beams.setMatrixAt(b++, dummy.matrix);
      else tracers.setMatrixAt(t++, dummy.matrix);
    }
    tracers.count = t;
    beams.count = b;
    tracers.instanceMatrix.needsUpdate = beams.instanceMatrix.needsUpdate = true;
  }

  // Height of a shell over the ground on its arc, t from 0 to 1.
  function shellPoint(s, t, out) {
    const d = Math.hypot(s.x2 - s.x, s.z2 - s.z);
    const x = s.x + (s.x2 - s.x) * t;
    const z = s.z + (s.z2 - s.z) * t;
    const base = groundAt(s.x, s.z) + 2.2 + (groundAt(s.x2, s.z2) - groundAt(s.x, s.z) - 2.2) * t;
    return out.set(wx(x), base + 4 * (2 + d * 0.32) * t * (1 - t), wz(z));
  }

  function drawShells(enemies) {
    let n = 0;
    for (const s of enemies.flying) {
      if (n >= MAX_SHELLS) break;
      const t = Math.min(1, s.t / s.dur);
      shellPoint(s, t, shellPos);
      shellPoint(s, Math.min(1, t + 0.02), shellNext);
      dummy.position.copy(shellPos);
      dummy.scale.set(1, 1, 1);
      dummy.lookAt(shellNext);
      dummy.updateMatrix();
      shellMesh.setMatrixAt(n++, dummy.matrix);
      if (Math.random() < 0.6) effects.emit({ x: shellPos.x, y: shellPos.y, z: shellPos.z, vx: rnd(-0.1, 0.1), vy: rnd(0, 0.2), vz: rnd(-0.1, 0.1), life: rnd(0.5, 0.9), size: rnd(0.12, 0.2), grow: 1.4, color: effects.color(0x9a948a, 0.1), gravity: 0, drag: 1, fade: 0.5 });
    }
    shellMesh.count = n;
    shellMesh.instanceMatrix.needsUpdate = true;
  }

  function drawRuins(enemies) {
    const list = enemies.ruins;
    // Rebuilt only when the list changes.
    const key = list.length + (list[0]?.index ?? 0) * 7 + (list[list.length - 1]?.index ?? 0) * 13;
    if (key === ruinsSeen) return;
    ruinsSeen = key;
    let n = 0;
    for (const r of list) {
      if (n >= MAX_RUINS) break;
      const x = r.index % world.size;
      const z = Math.floor(r.index / world.size);
      dummy.position.set(wx(x), groundAt(x, z), wz(z));
      dummy.rotation.set(0, (r.index * 2.399) % (Math.PI * 2), 0);
      dummy.scale.setScalar(BIG.has(r.type) ? 2.6 : 1);
      dummy.updateMatrix();
      rubble.setMatrixAt(n++, dummy.matrix);
    }
    rubble.count = n;
    rubble.instanceMatrix.needsUpdate = true;
  }

  function update(dt, elapsed, factory, camera, night) {
    const enemies = factory.enemies;
    group.visible = enemies.active;
    if (!enemies.active || !world) {
      enemies.fx.length = 0;
      return;
    }
    syncNests(enemies, elapsed, night);
    drawCreatures(enemies, elapsed);
    playFx(enemies, factory);
    drawLines(dt);
    drawShells(enemies);
    drawBars(factory, camera);
    drawRuins(enemies);
    eyeMat.emissiveIntensity = 1.6 * (1 + night * 1.5);
    smogTimer -= dt;
    if (smogTimer <= 0) {
      smogTimer = 0.5;
      updateSmog(enemies);
    }
  }

  function clear() {
    for (const v of nestViews.values()) {
      group.remove(v.group);
      for (const o of v.owned) o.dispose();
    }
    nestViews.clear();
    lines.length = 0;
    ruinsSeen = -1;
    for (const set of Object.values(kinds)) for (const mesh of Object.values(set)) mesh.count = 0;
    eyes.count = sacs.count = barBack.count = barFill.count = tracers.count = beams.count = rubble.count = shellMesh.count = 0;
  }

  return {
    group,
    setWorld,
    update,
    clear,
    // Thicker smog while building defences, so it shows where attacks come from.
    showSmog(on) {
      if (strongSmog === on) return;
      strongSmog = on;
      smogTimer = 0;
    },
  };
}
