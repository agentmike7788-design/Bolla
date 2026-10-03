import * as THREE from 'three';

export const MAP_SIZE = 64;
export const TILE = 1;

// Terrain types of the base map.
export const TERRAIN = {
  water: { name: 'Wasser', color: 0x7d8f6e, height: 0.05, buildable: false },
  sand: { name: 'Sand', color: 0xdcc58a, height: 0.36, buildable: true },
  grass: { name: 'Wiese', color: 0x6faa3e, height: 0.45, buildable: true },
  forest: { name: 'Wald', color: 0x4f8a38, height: 0.5, buildable: true },
  dune: { name: 'Wüste', color: 0xd9b46c, height: 0.42, buildable: true },
  rock: { name: 'Fels', color: 0x8c857a, height: 0.85, buildable: false },
};

// Deposits on the map. Drills mine ores; oil is a fluid that only pumps get out.
// color: the deposit itself, rock: the ground it sits in, crystal: shiny veins,
// patch: size of a field (1 = normal), rich: how much each tile holds.
export const ORES = {
  iron: { name: 'Eisenerz', color: 0x8c96a3, rock: 0x6a5d58, crystal: 0xb9c7d6 },
  copper: { name: 'Kupfererz', color: 0xc8682c, rock: 0x6e4a36, crystal: 0x3fb8a4 },
  coal: { name: 'Kohle', color: 0x26262a, rock: 0x403c3a, crystal: null },
  stone: { name: 'Kalkstein', color: 0xe6dcc6, rock: 0xb3a88f, crystal: null },
  oil: { name: 'Erdöl', color: 0x17141c, rock: 0x6b5638, crystal: null, fluid: true, patch: 0.55, rich: 3 },
};

// Small deterministic PRNG so a seed always yields the same map.
export function mulberry32(seed) {
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

// Default shape of a map. Scenarios override parts of it (see scenarios.js):
//   ores     ore patches per kind; kinds left out do not appear at all
//   land     raises (or lowers) the whole terrain: more or less sea
//   coast    where the island starts sinking into the sea, 0 centre .. 1 edge
//   rock     share of high ground that turns to rock, 0 none .. 1 all
//   forest   how dry it may be for trees to grow, 1 no forest at all
//   desert   grass turns into desert sand
//   richness multiplies the ore in each patch
//   size     tiles along each side
//   zones    where the patches of one kind may lie, as fractions of the map:
//            { iron: [x0, z0, x1, z1] }; kinds left out lie anywhere
export const DEFAULT_MAP = {
  size: MAP_SIZE,
  ores: { iron: 5, copper: 4, coal: 4, stone: 3, oil: 3 },
  land: 0,
  coast: 0.78,
  rock: 0.48,
  forest: 0.56,
  desert: false,
  richness: 1,
};

export function generateWorld(seed, options = {}) {
  const map = { ...DEFAULT_MAP, ...options };
  const rand = mulberry32(seed);
  const fbm = makeNoise(rand);
  const tiles = [];
  const size = map.size;

  for (let z = 0; z < size; z++) {
    for (let x = 0; x < size; x++) {
      // Fade the land into the sea towards the edge so the map reads as an island.
      const edge = Math.max(Math.abs((x / (size - 1)) * 2 - 1), Math.abs((z / (size - 1)) * 2 - 1));
      const h = fbm(x / 14, z / 14) + map.land - THREE.MathUtils.smoothstep(edge, map.coast, 1) * 0.3;
      const moisture = fbm(x / 9 + 100, z / 9 + 100, 3);
      let terrain;
      if (h < 0.36) terrain = 'water';
      else if (h < 0.41) terrain = 'sand';
      else if (h > 0.63 && fbm(x / 6 + 300, z / 6 + 300, 2) > 1 - map.rock) terrain = 'rock';
      else if (moisture > map.forest) terrain = 'forest';
      else terrain = map.desert ? 'dune' : 'grass';
      tiles.push({ x, z, terrain, ore: null, amount: 0 });
    }
  }

  // Scatter ore patches as blobs on buildable land, away from the map edge.
  const at = (x, z) => tiles[z * size + x];
  for (const [ore, count] of Object.entries(map.ores)) {
    let placed = 0;
    let tries = 0;
    const [x0, z0, x1, z1] = map.zones?.[ore] ?? [0, 0, 1, 1];
    while (placed < count && tries < 400) {
      tries++;
      const cx = 4 + Math.floor((x0 + rand() * (x1 - x0)) * (size - 8));
      const cz = 4 + Math.floor((z0 + rand() * (z1 - z0)) * (size - 8));
      const center = at(cx, cz);
      if (!TERRAIN[center.terrain].buildable || center.ore) continue;
      const radius = (2 + rand() * 2.5) * (ORES[ore].patch ?? 1);
      const r = Math.ceil(radius);
      for (let dz = -r; dz <= r; dz++) {
        for (let dx = -r; dx <= r; dx++) {
          const x = cx + dx;
          const z = cz + dz;
          if (x < 0 || z < 0 || x >= size || z >= size) continue;
          const dist = Math.hypot(dx, dz) + fbm(x / 3 + 50, z / 3 + 50, 2) * 1.5;
          const tile = at(x, z);
          if (dist > radius || !TERRAIN[tile.terrain].buildable || tile.ore) continue;
          tile.ore = ore;
          // Richer in the middle of the patch.
          tile.amount = Math.round(((1 - dist / (radius + 1.5)) * 1800 + 200 + rand() * 300) * map.richness * (ORES[ore].rich ?? 1));
        }
      }
      placed++;
    }
  }

  return { seed, size, tiles, at };
}

