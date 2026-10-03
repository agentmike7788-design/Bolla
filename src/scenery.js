import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { ORES, TERRAIN, TILE, mulberry32 } from './world.js';

const dummy = new THREE.Object3D();
const color = new THREE.Color();

// One instanced mesh from a list of { x, y, z, rx, ry, rz, sx, sy, sz, color }.
function instanced(geometry, material, items, { castShadow = true, receiveShadow = false } = {}) {
  const mesh = new THREE.InstancedMesh(geometry, material, Math.max(items.length, 1));
  items.forEach((it, i) => {
    dummy.position.set(it.x, it.y, it.z);
    dummy.rotation.set(it.rx ?? 0, it.ry ?? 0, it.rz ?? 0);
    dummy.scale.set(it.sx ?? 1, it.sy ?? it.sx ?? 1, it.sz ?? it.sx ?? 1);
    dummy.updateMatrix();
    mesh.setMatrixAt(i, dummy.matrix);
    mesh.setColorAt(i, color.set(it.color ?? 0xffffff));
  });
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
  const jitter = (spread) => (rand() - 0.5) * spread;

  const addTrunk = (x, y, z, s) => trunks.push({ x, y, z, sx: s, color: shade(0x6b4a2f, rand, 0.1) });

  for (const tile of world.tiles) {
    const { x, z } = tile.position;
    const y = tile.height;

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
    } else if (tile.terrain === 'rock' && rand() < 0.35) {
      const s = 0.8 + rand() * 1.2;
      boulders.push({ x: x + jitter(0.5), y: y + 0.05 * s, z: z + jitter(0.5), rx: rand() * 3, ry: rand() * 3, sx: s, sy: s * 0.7, sz: s, color: shade(0x8d877d, rand, 0.1) });
    } else if (tile.terrain === 'sand' && rand() < 0.06) {
      boulders.push({ x: x + jitter(0.6), y: y + 0.02, z: z + jitter(0.6), rx: rand() * 3, ry: rand() * 3, sx: 0.5, sy: 0.35, sz: 0.5, color: shade(0xb9ad98, rand, 0.1) });
    }
  }

  const flat = (opts) => new THREE.MeshStandardMaterial({ flatShading: true, ...opts });

  group.add(instanced(new THREE.CylinderGeometry(0.035, 0.05, 0.3, 5).translate(0, 0.15, 0), flat({ roughness: 0.9 }), trunks));
  group.add(instanced(pineGeometry(), flat({ roughness: 0.85 }), pines));
  group.add(instanced(new THREE.IcosahedronGeometry(0.24, 0), flat({ roughness: 0.8 }), leafy));
  group.add(instanced(new THREE.IcosahedronGeometry(0.11, 0), flat({ roughness: 0.85 }), bushes));
  group.add(instanced(new THREE.OctahedronGeometry(0.025, 0), flat({ roughness: 0.6 }), flowers, { castShadow: false }));
  group.add(instanced(new THREE.DodecahedronGeometry(0.17, 0), flat({ roughness: 0.9 }), boulders));
  group.add(instanced(new THREE.DodecahedronGeometry(0.13, 0), flat({ roughness: 0.55, metalness: 0.35 }), oreChunks));
  group.add(
    instanced(
      new THREE.OctahedronGeometry(0.06, 0).translate(0, 0.06, 0),
      flat({ roughness: 0.12, metalness: 0.2, emissive: 0x223030, envMapIntensity: 1.6 }),
      crystals,
    ),
  );

  return { group, tiles };
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

  return { group, update: (t) => (uniforms.uTime.value = t) };
}
