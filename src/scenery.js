import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { ORES, TERRAIN, TILE, mulberry32 } from './world.js';

const dummy = new THREE.Object3D();
const color = new THREE.Color();

// One instanced mesh from a list of { x, y, z, rx, ry, rz, sx, sy, sz, color }.
// With `decor`, every instance is registered under the tile it stands on so
// buildings can hide the trees, flowers and ore lumps beneath them.
function instanced(geometry, material, items, { castShadow = true, receiveShadow = false } = {}, decor = null) {
  const mesh = new THREE.InstancedMesh(geometry, material, Math.max(items.length, 1));
  items.forEach((it, i) => {
    dummy.position.set(it.x, it.y, it.z);
    dummy.rotation.set(it.rx ?? 0, it.ry ?? 0, it.rz ?? 0);
    dummy.scale.set(it.sx ?? 1, it.sy ?? it.sx ?? 1, it.sz ?? it.sx ?? 1);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    mesh.setColorAt(i, color.set(it.color ?? 0xffffff));
    if (decor) (decor[decor.tileAt(it.x, it.z)] ??= []).push([mesh, i]);
  });
  if (decor) mesh.userData.matrices = mesh.instanceMatrix.array.slice();
  mesh.count = items.length;
  mesh.castShadow = castShadow;
  mesh.receiveShadow = receiveShadow;
  return mesh;
}

const shade = (hex, rand, amount) => color.set(hex).offsetHSL((rand() - 0.5) * amount * 0.3, 0, (rand() - 0.5) * amount).getHex();

function pineGeometry() {
  const tiers = [
    [0.3, 0.42, 0.34],
    [0.23, 0.38, 0.56],
    [0.15, 0.32, 0.76],
  ].map(([r, h, y]) => new THREE.ConeGeometry(r, h, 7).translate(0, y, 0));
  return mergeGeometries(tiers);
}

// A saguaro: trunk with two arms bent upwards.
function cactusGeometry() {
  const up = (r, h, x, y) => new THREE.CylinderGeometry(r, r, h, 6).translate(x, y + h / 2, 0);
  const side = (r, w, x, y) => new THREE.CylinderGeometry(r, r, w, 6).rotateZ(Math.PI / 2).translate(x + w / 2, y, 0);
  return mergeGeometries([
    up(0.06, 0.5, 0, 0),
    side(0.035, 0.13, 0, 0.2),
    up(0.035, 0.16, 0.13, 0.2),
    side(0.035, 0.11, -0.11, 0.28),
    up(0.035, 0.12, -0.11, 0.28),
    new THREE.SphereGeometry(0.06, 6, 3, 0, Math.PI * 2, 0, Math.PI / 2).translate(0, 0.5, 0),
  ].map((g) => g.toNonIndexed()));
}

// Builds every mesh that depends on the generated world: ground tiles, trees,
// bushes, flowers, boulders and the ore deposits.
export function buildWorldMeshes(world) {
  const group = new THREE.Group();
  const rand = mulberry32(world.seed ^ 0x9e3779b9);
  const offset = (world.size * TILE) / 2 - TILE / 2;

  // Ground tiles: soft rounded blocks whose top sits at tile.height.
  const tileItems = world.tiles.map((tile) => {
    const t = TERRAIN[tile.terrain];
    tile.height = t.height + rand() * 0.03;
    tile.position = new THREE.Vector3(tile.x * TILE - offset, tile.height, tile.z * TILE - offset);
    const base = tile.ore ? ORES[tile.ore].rock : t.color;
    return { x: tile.position.x, y: tile.height, z: tile.position.z, color: shade(base, rand, 0.07) };
  });
  const tileGeo = new RoundedBoxGeometry(TILE, 2, TILE, 2, 0.06).translate(0, -1, 0);
  const tiles = instanced(tileGeo, new THREE.MeshStandardMaterial({ roughness: 0.95 }), tileItems, { receiveShadow: true });
  group.add(tiles);

  const trunks = [];
  const pines = [];
  const leafy = [];
  const bushes = [];
  const flowers = [];
  const boulders = [];
  const oreChunks = [];
  const crystals = [];
  const cacti = [];
  const puddles = [];
  const caps = []; // snow on the pines
  const drifts = []; // snow drifts and ice floes
  const snags = []; // dead, burnt trees
  const ventRocks = [];
  const ventGlow = [];
  const lavaTiles = [];
  const jitter = (spread) => (rand() - 0.5) * spread;

  const addTrunk = (x, y, z, s) => trunks.push({ x, y, z, sx: s, color: shade(0x6b4a2f, rand, 0.1) });

  for (const tile of world.tiles) {
    const { x, z } = tile.position;
    const y = tile.height;

    if (tile.vent) {
      // A ring of dark stones round a glowing crack.
      for (let k = 0; k < 7; k++) {
        const a = (k / 7) * Math.PI * 2 + rand() * 0.4;
        const s = 0.5 + rand() * 0.5;
        ventRocks.push({ x: x + Math.cos(a) * 0.3, y: y + 0.03, z: z + Math.sin(a) * 0.3, rx: rand() * 3, ry: rand() * 3, sx: s, sy: s * 0.7, sz: s, color: shade(0x2e2a28, rand, 0.1) });
      }
      ventGlow.push({ x, y: y + 0.012, z, ry: rand() * 6, color: 0xffffff });
      continue;
    }
    if (tile.terrain === 'lava') {
      lavaTiles.push({ x, y: y + 0.012, z, ry: Math.floor(rand() * 4) * (Math.PI / 2), color: 0xffffff });
      continue;
    }

    if (tile.ore && ORES[tile.ore].fluid) {
      // Oil seeps up in glossy black puddles.
      const n = 2 + Math.floor(rand() * 2);
      for (let k = 0; k < n; k++) {
        const s = 0.6 + rand() * 0.7;
        puddles.push({ x: x + jitter(0.5), y: y + 0.005 + k * 0.002, z: z + jitter(0.5), ry: rand() * 6, sx: s * (1 + rand() * 0.5), sy: 1, sz: s, color: shade(ORES[tile.ore].color, rand, 0.08) });
      }
      continue;
    }
    if (tile.ore) {
      const ore = ORES[tile.ore];
      const chunkCount = 2 + Math.min(4, Math.floor(tile.amount / 450));
      for (let k = 0; k < chunkCount; k++) {
        const s = 0.6 + rand() * 0.9;
        oreChunks.push({
          x: x + jitter(0.7), y: y + 0.05 * s, z: z + jitter(0.7),
          rx: rand() * 3, ry: rand() * 3, rz: rand() * 3,
          sx: s, sy: s * (0.6 + rand() * 0.4), sz: s,
          color: shade(ore.color, rand, 0.12),
        });
      }
      if (ore.crystal && rand() < 0.75) {
        const cx = x + jitter(0.5);
        const cz = z + jitter(0.5);
        const shards = 2 + Math.floor(rand() * 3);
        for (let k = 0; k < shards; k++) {
          const s = 0.7 + rand() * 0.7;
          crystals.push({
            x: cx + jitter(0.15), y: y + 0.06, z: cz + jitter(0.15),
            rx: jitter(0.9), ry: rand() * 3, rz: jitter(0.9),
            sx: s, sy: s * (1.8 + rand()), sz: s,
            color: shade(ore.crystal, rand, 0.1),
          });
        }
      }
      continue;
    }

    if (tile.terrain === 'forest') {
      const count = 1 + Math.floor(rand() * 3);
      for (let k = 0; k < count; k++) {
        const tx = x + jitter(0.65);
        const tz = z + jitter(0.65);
        const s = 0.75 + rand() * 0.55;
        addTrunk(tx, y, tz, s);
        if (rand() < 0.75) {
          pines.push({ x: tx, y, z: tz, ry: rand() * 6, sx: s, color: shade(0x2f6b3a, rand, 0.12) });
        } else {
          leafy.push({ x: tx, y: y + 0.42 * s, z: tz, ry: rand() * 6, sx: s, sy: s * 0.9, color: shade(0x4f9a3c, rand, 0.15) });
        }
      }
    } else if (tile.terrain === 'grass') {
      if (rand() < 0.05) {
        const s = 0.8 + rand() * 0.5;
        addTrunk(x + jitter(0.4), y, z + jitter(0.4), s);
        const last = trunks[trunks.length - 1];
        leafy.push({ x: last.x, y: y + 0.42 * s, z: last.z, ry: rand() * 6, sx: s, sy: s * 0.9, color: shade(0x6aa83f, rand, 0.15) });
      }
      if (rand() < 0.18) {
        bushes.push({ x: x + jitter(0.7), y: y + 0.04, z: z + jitter(0.7), ry: rand() * 6, sx: 0.7 + rand() * 0.6, color: shade(0x4d8a34, rand, 0.15) });
      }
      if (rand() < 0.3) {
        const palette = [0xfff6e0, 0xffd447, 0xf28bb0, 0xa98bf0];
        const tint = palette[Math.floor(rand() * palette.length)];
        const n = 2 + Math.floor(rand() * 4);
        const fx = x + jitter(0.6);
        const fz = z + jitter(0.6);
        for (let k = 0; k < n; k++) flowers.push({ x: fx + jitter(0.25), y: y + 0.025, z: fz + jitter(0.25), sx: 0.8 + rand() * 0.6, color: tint });
      }
    } else if (tile.terrain === 'dune') {
      if (rand() < 0.07) {
        const s = 0.7 + rand() * 0.6;
        cacti.push({ x: x + jitter(0.5), y, z: z + jitter(0.5), ry: rand() * 6, sx: s, sy: s * (0.8 + rand() * 0.5), sz: s, color: shade(0x5f8f4a, rand, 0.12) });
      } else if (rand() < 0.12) {
        bushes.push({ x: x + jitter(0.7), y: y + 0.03, z: z + jitter(0.7), ry: rand() * 6, sx: 0.5 + rand() * 0.4, color: shade(0x9a8a4a, rand, 0.15) });
      } else if (rand() < 0.08) {
        boulders.push({ x: x + jitter(0.6), y: y + 0.03, z: z + jitter(0.6), rx: rand() * 3, ry: rand() * 3, sx: 0.6, sy: 0.4, sz: 0.6, color: shade(0xc39a62, rand, 0.1) });
      }
    } else if (tile.terrain === 'taiga') {
      // Snowy pines: darker needles, a white cap on top.
      const count = 1 + Math.floor(rand() * 3);
      for (let k = 0; k < count; k++) {
        const tx = x + jitter(0.65);
        const tz = z + jitter(0.65);
        const s = 0.75 + rand() * 0.55;
        addTrunk(tx, y, tz, s);
        pines.push({ x: tx, y, z: tz, ry: rand() * 6, sx: s, color: shade(0x2c5a44, rand, 0.12) });
        caps.push({ x: tx, y: y + 0.7 * s, z: tz, ry: rand() * 6, sx: s, color: shade(0xf4f8fa, rand, 0.04) });
      }
    } else if (tile.terrain === 'snow') {
      if (rand() < 0.22) drifts.push({ x: x + jitter(0.6), y: y + 0.01, z: z + jitter(0.6), ry: rand() * 6, sx: 0.8 + rand() * 0.8, sy: 0.35, sz: 0.6 + rand() * 0.5, color: shade(0xf6fafc, rand, 0.04) });
      if (rand() < 0.04) {
        const s = 0.6 + rand() * 0.4;
        addTrunk(x, y, z, s);
        pines.push({ x, y, z, ry: rand() * 6, sx: s, color: shade(0x2c5a44, rand, 0.12) });
        caps.push({ x, y: y + 0.7 * s, z, ry: rand() * 6, sx: s, color: 0xf4f8fa });
      }
    } else if (tile.terrain === 'ice') {
      if (rand() < 0.08) drifts.push({ x: x + jitter(0.6), y: y + 0.005, z: z + jitter(0.6), ry: rand() * 6, sx: 0.6 + rand() * 0.6, sy: 0.12, sz: 0.5 + rand() * 0.4, color: shade(0xe8f4fa, rand, 0.04) });
    } else if (tile.terrain === 'burnt') {
      const count = Math.floor(rand() * 3);
      for (let k = 0; k < count; k++) {
        const s = 0.8 + rand() * 0.7;
        snags.push({ x: x + jitter(0.65), y, z: z + jitter(0.65), rx: jitter(0.25), ry: rand() * 6, rz: jitter(0.25), sx: s, sy: s * (0.9 + rand() * 0.6), sz: s, color: shade(0x2a2420, rand, 0.12) });
      }
      if (rand() < 0.15) bushes.push({ x: x + jitter(0.7), y: y + 0.03, z: z + jitter(0.7), ry: rand() * 6, sx: 0.5 + rand() * 0.4, color: shade(0x6a6040, rand, 0.15) });
    } else if (tile.terrain === 'ash') {
      if (rand() < 0.04) snags.push({ x: x + jitter(0.5), y, z: z + jitter(0.5), rx: jitter(0.3), ry: rand() * 6, rz: jitter(0.3), sx: 0.8, sy: 0.9, sz: 0.8, color: shade(0x2a2420, rand, 0.12) });
      else if (rand() < 0.08) boulders.push({ x: x + jitter(0.6), y: y + 0.03, z: z + jitter(0.6), rx: rand() * 3, ry: rand() * 3, sx: 0.6, sy: 0.45, sz: 0.6, color: shade(0x2f2b29, rand, 0.1) });
    } else if ((tile.terrain === 'basalt' || tile.terrain === 'blacksand' || tile.terrain === 'gravel') && rand() < 0.3) {
      const s = tile.terrain === 'basalt' ? 0.8 + rand() * 1.2 : 0.5;
      const base = tile.terrain === 'gravel' ? 0x8e8a82 : 0x2b2826;
      boulders.push({ x: x + jitter(0.5), y: y + 0.04 * s, z: z + jitter(0.5), rx: rand() * 3, ry: rand() * 3, sx: s, sy: s * 0.7, sz: s, color: shade(base, rand, 0.1) });
    } else if (tile.terrain === 'crag' && rand() < 0.35) {
      const s = 0.8 + rand() * 1.2;
      boulders.push({ x: x + jitter(0.5), y: y + 0.05 * s, z: z + jitter(0.5), rx: rand() * 3, ry: rand() * 3, sx: s, sy: s * 0.7, sz: s, color: shade(0xdfe4e6, rand, 0.06) });
    } else if (tile.terrain === 'rock' && rand() < 0.35) {
      const s = 0.8 + rand() * 1.2;
      boulders.push({ x: x + jitter(0.5), y: y + 0.05 * s, z: z + jitter(0.5), rx: rand() * 3, ry: rand() * 3, sx: s, sy: s * 0.7, sz: s, color: shade(0x8d877d, rand, 0.1) });
    } else if (tile.terrain === 'sand' && rand() < 0.06) {
      boulders.push({ x: x + jitter(0.6), y: y + 0.02, z: z + jitter(0.6), rx: rand() * 3, ry: rand() * 3, sx: 0.5, sy: 0.35, sz: 0.5, color: shade(0xb9ad98, rand, 0.1) });
    }
  }

  const flat = (opts) => new THREE.MeshStandardMaterial({ flatShading: true, ...opts });

  // Decorations per tile index, so a building can clear the spot it stands on.
  const decor = [];
  decor.tileAt = (x, z) => Math.round((z + offset) / TILE) * world.size + Math.round((x + offset) / TILE);
  const deco = (geometry, material, items, opts) => group.add(instanced(geometry, material, items, opts, decor));

  deco(new THREE.CylinderGeometry(0.035, 0.05, 0.3, 5).translate(0, 0.15, 0), flat({ roughness: 0.9 }), trunks);
  deco(pineGeometry(), flat({ roughness: 0.85 }), pines);
  deco(new THREE.IcosahedronGeometry(0.24, 0), flat({ roughness: 0.8 }), leafy);
  deco(new THREE.IcosahedronGeometry(0.11, 0), flat({ roughness: 0.85 }), bushes);
  deco(new THREE.OctahedronGeometry(0.025, 0), flat({ roughness: 0.6 }), flowers, { castShadow: false });
  deco(new THREE.DodecahedronGeometry(0.17, 0), flat({ roughness: 0.9 }), boulders);
  deco(cactusGeometry(), flat({ roughness: 0.8 }), cacti);
  deco(new THREE.CylinderGeometry(0.22, 0.24, 0.02, 12), new THREE.MeshStandardMaterial({ roughness: 0.05, metalness: 0.6, envMapIntensity: 2 }), puddles, { castShadow: false, receiveShadow: true });
  deco(new THREE.DodecahedronGeometry(0.13, 0), flat({ roughness: 0.55, metalness: 0.35 }), oreChunks);
  deco(
    new THREE.OctahedronGeometry(0.06, 0).translate(0, 0.06, 0),
    flat({ roughness: 0.12, metalness: 0.2, emissive: 0x223030, envMapIntensity: 1.6 }),
    crystals,
  );

  deco(new THREE.ConeGeometry(0.17, 0.2, 7).translate(0, 0.08, 0), flat({ roughness: 0.9 }), caps);
  deco(new THREE.IcosahedronGeometry(0.2, 0), flat({ roughness: 1 }), drifts, { castShadow: false, receiveShadow: true });
  deco(snagGeometry(), flat({ roughness: 1 }), snags);
  deco(new THREE.DodecahedronGeometry(0.09, 0), flat({ roughness: 0.95 }), ventRocks);

  // Glowing things: lava and vents share one animated material.
  const glowUniforms = { uTime: { value: 0 }, uHeat: { value: 0 } };
  const ventMat = lavaMaterial(glowUniforms, 0.6);
  deco(new THREE.CircleGeometry(0.22, 10).rotateX(-Math.PI / 2), ventMat, ventGlow, { castShadow: false });
  if (lavaTiles.length) {
    group.add(instanced(new THREE.PlaneGeometry(TILE * 0.98, TILE * 0.98).rotateX(-Math.PI / 2), lavaMaterial(glowUniforms, 1), lavaTiles, { castShadow: false }));
  }
  if (world.crater) group.add(volcanoMesh(world, offset, glowUniforms));

  const hidden = new THREE.Matrix4().makeScale(0, 0, 0);
  // Hide (or bring back) everything that grows or lies on one tile.
  function setDecorHidden(tileIndex, hide) {
    for (const [mesh, i] of decor[tileIndex] ?? []) {
      if (hide) mesh.setMatrixAt(i, hidden);
      else mesh.instanceMatrix.array.set(mesh.userData.matrices.subarray(i * 16, i * 16 + 16), i * 16);
      mesh.instanceMatrix.needsUpdate = true;
    }
  }

  // `heat` 0 … 1 makes lava and vents flare up, e.g. while the volcano erupts.
  function update(t, heat = 0) {
    glowUniforms.uTime.value = t;
    glowUniforms.uHeat.value = heat;
  }

  return { group, tiles, setDecorHidden, update };
}

// A charred tree: a bare trunk with two stubby branches.
function snagGeometry() {
  return mergeGeometries([
    new THREE.CylinderGeometry(0.025, 0.045, 0.6, 5).translate(0, 0.3, 0),
    new THREE.CylinderGeometry(0.015, 0.02, 0.22, 4).rotateZ(0.9).translate(0.07, 0.38, 0),
    new THREE.CylinderGeometry(0.012, 0.018, 0.18, 4).rotateZ(-1).translate(-0.06, 0.48, 0),
  ].map((g) => g.toNonIndexed()));
}

// Molten rock: a dark crust with bright cracks that crawl slowly and pulse.
function lavaMaterial(uniforms, strength) {
  const mat = new THREE.MeshStandardMaterial({ color: 0x1a0a06, roughness: 0.9, emissive: 0xff4a10, emissiveIntensity: strength });
  mat.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = uniforms.uTime;
    shader.uniforms.uHeat = uniforms.uHeat;
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec2 vLavaPos;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\n#ifdef USE_INSTANCING\nvLavaPos = (modelMatrix * instanceMatrix * vec4(position, 1.0)).xz;\n#else\nvLavaPos = (modelMatrix * vec4(position, 1.0)).xz;\n#endif');
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform float uTime;\nuniform float uHeat;\nvarying vec2 vLavaPos;')
      .replace(
        '#include <emissivemap_fragment>',
        `#include <emissivemap_fragment>
        vec2 q = vLavaPos * 2.3;
        float n = sin(q.x * 1.7 + uTime * 0.4) * sin(q.y * 1.9 - uTime * 0.3) + sin((q.x + q.y) * 3.1 + uTime * 0.7) * 0.5;
        float crack = smoothstep(0.15, 0.9, abs(n));
        float pulse = 0.75 + 0.25 * sin(uTime * 1.3 + q.x * 0.5);
        totalEmissiveRadiance *= mix(1.6, 0.25, crack) * pulse * (1.0 + uHeat * 1.5);
        diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.9, 0.35, 0.08), (1.0 - crack) * 0.4);`,
      );
  };
  return mat;
}

// The cone in the middle of a volcano map, with a lava lake in its crater.
function volcanoMesh(world, offset, uniforms) {
  const { radius } = world.crater;
  const cx = world.crater.x * TILE - offset;
  const cz = world.crater.z * TILE - offset;
  const top = radius * 0.95;
  const rim = radius * 0.32;
  const profile = [
    [radius + 0.6, 0.2],
    [radius * 0.85, top * 0.18],
    [radius * 0.62, top * 0.48],
    [rim * 1.15, top * 0.92],
    [rim, top],
    [rim * 0.82, top - 0.5],
    [0, top - 0.55],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const geo = new THREE.LatheGeometry(profile, 36).toNonIndexed();
  // Rough it up: every vertex moves in and out a little with the angle.
  const pos = geo.attributes.position;
  const rand = mulberry32(world.seed ^ 0x51ed);
  const bumps = Array.from({ length: 36 }, () => 0.85 + rand() * 0.3);
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i);
    const z = pos.getZ(i);
    const r = Math.hypot(x, z);
    if (r < 0.01) continue;
    const a = Math.atan2(z, x);
    const k = bumps[Math.floor(((a + Math.PI) / (Math.PI * 2)) * 36) % 36];
    const f = 1 + (k - 1) * Math.min(1, r / rim) * 0.6;
    pos.setX(i, x * f);
    pos.setZ(i, z * f);
  }
  geo.computeVertexNormals();
  const group = new THREE.Group();
  const cone = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: 0x3a3330, roughness: 0.95, flatShading: true }));
  cone.castShadow = true;
  cone.receiveShadow = true;
  group.add(cone);
  const lake = new THREE.Mesh(new THREE.CircleGeometry(rim * 0.85, 24).rotateX(-Math.PI / 2), lavaMaterial(uniforms, 1.4));
  lake.position.y = top - 0.5;
  group.add(lake);
  group.position.set(cx, 0.3, cz);
  return group;
}

// Animated sea around and inside the island, with a sandy seabed below it.
export function createSea() {
  const group = new THREE.Group();

  const seabed = new THREE.Mesh(
    new THREE.PlaneGeometry(800, 800).rotateX(-Math.PI / 2),
    new THREE.MeshStandardMaterial({ color: 0x5f7a6a, roughness: 1 }),
  );
  seabed.position.y = -0.4;
  seabed.receiveShadow = true;
  group.add(seabed);

  const uniforms = { uTime: { value: 0 } };
  const material = new THREE.MeshStandardMaterial({
    color: 0x2f8fb3,
    roughness: 0.12,
    metalness: 0.05,
    transparent: true,
    opacity: 0.78,
  });
  // Waves live only in the lighting: the fragment shader tilts the normal with
  // a few moving sine waves, so the surface itself can stay a flat quad.
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uTime = uniforms.uTime;
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec2 vSeaPos;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvSeaPos = (modelMatrix * vec4(position, 1.0)).xz;');
    shader.fragmentShader = shader.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform float uTime;\nvarying vec2 vSeaPos;')
      .replace(
        '#include <normal_fragment_begin>',
        `#include <normal_fragment_begin>
        vec2 p = vSeaPos;
        float dx = cos(p.x * 1.3 + uTime * 1.2) * 0.06 + cos((p.x + p.y) * 2.7 + uTime * 2.1) * 0.035;
        float dz = cos(p.y * 1.1 - uTime * 1.0) * 0.06 + cos((p.x - p.y) * 3.1 + uTime * 1.7) * 0.03;
        normal = normalize((viewMatrix * vec4(normalize(vec3(-dx, 1.0, -dz)), 0.0)).xyz);`,
      );
  };
  const water = new THREE.Mesh(new THREE.PlaneGeometry(800, 800), material);
  water.rotation.x = -Math.PI / 2;
  water.position.y = 0.28;
  water.receiveShadow = true;
  group.add(water);

  return { group, update: (t) => (uniforms.uTime.value = t), setColor: (hex) => material.color.setHex(hex) };
}
