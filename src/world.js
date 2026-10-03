import * as THREE from 'three';

export const MAP_SIZE = 64;
export const TILE = 1;

// Terrain types of the base map.
export const TERRAIN = {
  water: { name: 'Wasser', color: 0x3b6e8f, height: 0.2, buildable: false },
  sand: { name: 'Sand', color: 0xcdb47a, height: 0.35, buildable: true },
  grass: { name: 'Wiese', color: 0x6f9a4a, height: 0.45, buildable: true },
  forest: { name: 'Wald', color: 0x4c7a3a, height: 0.5, buildable: true },
  rock: { name: 'Fels', color: 0x8a8378, height: 0.8, buildable: false },
};

// Ore deposits that drills will mine in a later step.
export const ORES = {
  iron: { name: 'Eisenerz', color: 0x9aa3ad, rock: 0x6d5a52, unit: 'Einheiten' },
  copper: { name: 'Kupfererz', color: 0xd27a3c, rock: 0x7a4a2e, unit: 'Einheiten' },
  coal: { name: 'Kohle', color: 0x2b2b2e, rock: 0x3a3a3d, unit: 'Einheiten' },
  stone: { name: 'Kalkstein', color: 0xe3dccb, rock: 0xb8ae98, unit: 'Einheiten' },
};

// Small deterministic PRNG so a seed always yields the same map.
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Value noise on a lattice, smoothed and layered into fractal noise.
function makeNoise(rand) {
  const size = 256;
  const perm = new Uint8Array(size * 2);
  const values = new Float32Array(size);
  for (let i = 0; i < size; i++) {
    perm[i] = i;
    values[i] = rand();
  }
  for (let i = size - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [perm[i], perm[j]] = [perm[j], perm[i]];
  }
  for (let i = 0; i < size; i++) perm[i + size] = perm[i];

  const lattice = (x, y) => values[perm[(perm[x & 255] + y) & 511]];
  const smooth = (t) => t * t * (3 - 2 * t);

  const noise = (x, y) => {
    const xi = Math.floor(x);
    const yi = Math.floor(y);
    const tx = smooth(x - xi);
    const ty = smooth(y - yi);
    const a = lattice(xi, yi);
    const b = lattice(xi + 1, yi);
    const c = lattice(xi, yi + 1);
    const d = lattice(xi + 1, yi + 1);
    return THREE.MathUtils.lerp(THREE.MathUtils.lerp(a, b, tx), THREE.MathUtils.lerp(c, d, tx), ty);
  };

  return (x, y, octaves = 4) => {
    let sum = 0;
    let amp = 1;
    let freq = 1;
    let norm = 0;
    for (let o = 0; o < octaves; o++) {
      sum += noise(x * freq, y * freq) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return sum / norm;
  };
}

export function generateWorld(seed) {
  const rand = mulberry32(seed);
  const fbm = makeNoise(rand);
  const tiles = [];

  for (let z = 0; z < MAP_SIZE; z++) {
    for (let x = 0; x < MAP_SIZE; x++) {
      const h = fbm(x / 14, z / 14);
      const moisture = fbm(x / 9 + 100, z / 9 + 100, 3);
      let terrain;
      if (h < 0.36) terrain = 'water';
      else if (h < 0.41) terrain = 'sand';
      else if (h > 0.63 && fbm(x / 6 + 300, z / 6 + 300, 2) > 0.52) terrain = 'rock';
      else terrain = moisture > 0.56 ? 'forest' : 'grass';
      tiles.push({ x, z, terrain, ore: null, amount: 0 });
    }
  }

  // Scatter ore patches as blobs on buildable land, away from the map edge.
  const patchCount = { iron: 5, copper: 4, coal: 4, stone: 3 };
  const at = (x, z) => tiles[z * MAP_SIZE + x];
  for (const [ore, count] of Object.entries(patchCount)) {
    let placed = 0;
    let tries = 0;
    while (placed < count && tries < 400) {
      tries++;
      const cx = 4 + Math.floor(rand() * (MAP_SIZE - 8));
      const cz = 4 + Math.floor(rand() * (MAP_SIZE - 8));
      const center = at(cx, cz);
      if (!TERRAIN[center.terrain].buildable || center.ore) continue;
      const radius = 2 + rand() * 2.5;
      const r = Math.ceil(radius);
      for (let dz = -r; dz <= r; dz++) {
        for (let dx = -r; dx <= r; dx++) {
          const x = cx + dx;
          const z = cz + dz;
          if (x < 0 || z < 0 || x >= MAP_SIZE || z >= MAP_SIZE) continue;
          const dist = Math.hypot(dx, dz) + fbm(x / 3 + 50, z / 3 + 50, 2) * 1.5;
          const tile = at(x, z);
          if (dist > radius || !TERRAIN[tile.terrain].buildable || tile.ore) continue;
          tile.ore = ore;
          // Richer in the middle of the patch.
          tile.amount = Math.round((1 - dist / (radius + 1.5)) * 1800 + 200 + rand() * 300);
        }
      }
      placed++;
    }
  }

  return { seed, size: MAP_SIZE, tiles, at };
}

const dummy = new THREE.Object3D();
const color = new THREE.Color();

// Builds the meshes for a world: one instanced mesh for the ground tiles and
// one for the ore rocks sitting on top of deposit tiles.
export function buildWorldMeshes(world) {
  const group = new THREE.Group();
  const offset = (world.size * TILE) / 2 - TILE / 2;

  // Box top sits at y = 0, so an instance placed at tile.height has its top there.
  const tileGeo = new THREE.BoxGeometry(TILE * 0.96, 1, TILE * 0.96);
  tileGeo.translate(0, -0.5, 0);
  const tileMat = new THREE.MeshStandardMaterial({ roughness: 0.9, metalness: 0 });
  const tiles = new THREE.InstancedMesh(tileGeo, tileMat, world.tiles.length);
  tiles.receiveShadow = true;
  tiles.castShadow = true;

  world.tiles.forEach((tile, i) => {
    const t = TERRAIN[tile.terrain];
    const jitter = ((tile.x * 7 + tile.z * 13) % 5) * 0.012;
    tile.height = t.height + jitter;
    dummy.position.set(tile.x * TILE - offset, tile.height, tile.z * TILE - offset);
    dummy.rotation.set(0, 0, 0);
    dummy.scale.set(1, tile.height + 0.5, 1);
    dummy.updateMatrix();
    tiles.setMatrixAt(i, dummy.matrix);
    color.setHex(tile.ore ? ORES[tile.ore].rock : t.color);
    color.offsetHSL(0, 0, (jitter - 0.024) * 1.5);
    tiles.setColorAt(i, color);
    tile.position = new THREE.Vector3(tile.x * TILE - offset, tile.height, tile.z * TILE - offset);
  });
  tiles.instanceMatrix.needsUpdate = true;
  group.add(tiles);

  // Ore chunks: a few low-poly rocks per deposit tile, more for richer tiles.
  const rockGeo = new THREE.DodecahedronGeometry(0.16, 0);
  const rockMat = new THREE.MeshStandardMaterial({ roughness: 0.6, metalness: 0.25, flatShading: true });
  const oreTiles = world.tiles.filter((t) => t.ore);
  const rocksPerTile = (t) => 1 + Math.min(3, Math.floor(t.amount / 600));
  const rockCount = oreTiles.reduce((n, t) => n + rocksPerTile(t), 0);
  const rocks = new THREE.InstancedMesh(rockGeo, rockMat, Math.max(rockCount, 1));
  rocks.castShadow = true;
  let r = 0;
  const rand = mulberry32(world.seed ^ 0x9e3779b9);
  for (const tile of oreTiles) {
    for (let k = 0; k < rocksPerTile(tile); k++) {
      const s = 0.7 + rand() * 0.8;
      dummy.position.set(
        tile.position.x + (rand() - 0.5) * 0.6,
        tile.height + 0.08 * s,
        tile.position.z + (rand() - 0.5) * 0.6,
      );
      dummy.rotation.set(rand() * Math.PI, rand() * Math.PI, rand() * Math.PI);
      dummy.scale.set(s, s * 0.8, s);
      dummy.updateMatrix();
      rocks.setMatrixAt(r, dummy.matrix);
      color.setHex(ORES[tile.ore].color);
      color.offsetHSL(0, 0, (rand() - 0.5) * 0.08);
      rocks.setColorAt(r, color);
      r++;
    }
  }
  rocks.count = rockCount;
  group.add(rocks);

  // Trees on forest tiles so the map reads at a glance.
  const forestTiles = world.tiles.filter((t) => t.terrain === 'forest' && !t.ore);
  const treeGeo = new THREE.ConeGeometry(0.22, 0.6, 6);
  treeGeo.translate(0, 0.3, 0);
  const treeMat = new THREE.MeshStandardMaterial({ color: 0x2f5a2a, roughness: 0.8, flatShading: true });
  const trees = new THREE.InstancedMesh(treeGeo, treeMat, Math.max(forestTiles.length, 1));
  trees.castShadow = true;
  forestTiles.forEach((tile, i) => {
    const s = 0.8 + rand() * 0.5;
    dummy.position.set(tile.position.x + (rand() - 0.5) * 0.4, tile.height, tile.position.z + (rand() - 0.5) * 0.4);
    dummy.rotation.set(0, rand() * Math.PI, 0);
    dummy.scale.set(s, s, s);
    dummy.updateMatrix();
    trees.setMatrixAt(i, dummy.matrix);
  });
  trees.count = forestTiles.length;
  group.add(trees);

  return { group, tiles };
}
