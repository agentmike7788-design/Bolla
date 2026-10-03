// Enemies and defence: creature nests in the wild, the smog of the factory that
// draws them in, attack waves, walls and turrets.
//
// Working machines blow smog into the air. It drifts over the map in chunks of
// CHUNK × CHUNK tiles and the land swallows it slowly, forests faster. A nest
// that sits in smog soaks it up and gets angry; once it is angry enough (and the
// grace period of the mode is over) it sends a wave of creatures at the nearest
// polluting building. Creatures walk around water and rock, over belts, rails
// and pipes' ends, and bite through whatever else stands in their way. Walls are
// cheap to bite through slowly; turrets shoot ammunition from belts, laser
// turrets fire on power. Turrets in reach of a nest shoot it too, and a nest
// under fire sends defenders out. The creatures grow stronger over time, with
// the smog they swallow and with every nest that falls (evolution).
//
// In the mode 'off' nothing of this exists. 'peaceful' keeps the nests quiet
// until someone shoots at them.
import { TERRAIN, mulberry32 } from './world.js';

export const ENEMY_MODES = {
  off: { name: 'Aus', desc: 'Keine Nester und keine Angriffe' },
  peaceful: { name: 'Friedlich', desc: 'Nester wehren sich nur, wenn man auf sie schießt', attacks: false, grace: 0, evo: 0.5, nests: 1, absorb: 1 },
  normal: { name: 'Normal', desc: 'Smog lockt Angriffe an, frühestens nach 15 Minuten', attacks: true, grace: 900, evo: 1, nests: 1, absorb: 1 },
  hard: { name: 'Schwer', desc: 'Mehr Nester, frühere und größere Angriffe, schnellere Evolution', attacks: true, grace: 480, evo: 1.8, nests: 1.5, absorb: 1.5 },
};

// cost: anger a nest spends on one; evo: evolution from which a nest sends them.
export const CREATURES = {
  crawler: { name: 'Krabbler', hp: 18, speed: 1.7, damage: 8, rate: 1.2, reach: 0.95, cost: 5, evo: 0, armor: 0 },
  spitter: { name: 'Speier', hp: 30, speed: 1.35, damage: 9, rate: 0.7, reach: 3.2, cost: 12, evo: 0.15, armor: 0 },
  brute: { name: 'Panzerkäfer', hp: 140, speed: 1.05, damage: 35, rate: 0.8, reach: 1.05, cost: 30, evo: 0.32, armor: 3 },
};

export const CHUNK = 4; // tiles per smog chunk side
// Smog per minute while working.
export const POLLUTION = { drill: 10, furnace: 5, assembler: 2, constructor: 3, power: 24, refinery: 8, pump: 6, silo: 12 };
const SPREAD = 0.05; // share of a chunk's smog that drifts to each neighbour per second
const SPREAD_MIN = 0.5; // thinner smog stays where it is
// Share of the smog over a tile the ground swallows per second (a chunk takes the
// average of its tiles): forests clean the air, rock and water hardly.
const ABSORB = { forest: 0.0055, taiga: 0.005, burnt: 0.0015, water: 0.0008, lava: 0.006, rock: 0.0008, crag: 0.0008, basalt: 0.0008, cone: 0.0005 };
const ABSORB_LAND = 0.002;

export const NEST_HP = 450;
const NEST_ABSORB = 0.04; // share of the smog in its chunk a nest soaks up per second, half that around it
const NEST_CLEAR = 2; // nothing can be built this close to a nest
const WAVE_ANGER = 45; // anger before a nest sends a wave
const MAX_ANGER = 400;
const DEFENDERS = 6; // defenders a nest keeps out at once while it is shot
const MAX_CREATURES = 260;

// Evolution per second, per unit of smog swallowed and per fallen nest.
const EVO_TIME = 1 / (60 * 60 * 7);
const EVO_SMOG = 1 / 30000;
const EVO_NEST = 0.025;

// Defences.
export const TURRET_RANGE = 7.5;
export const LASER_RANGE = 9.5;
export const TURRET = { range: TURRET_RANGE, rate: 4, damage: 6, shots: 10, store: 20 }; // shots per ammo, ammo kept
export const LASER = { range: LASER_RANGE, rate: 2.2, damage: 14 };
export const isTurret = (b) => b?.type === 'turret' || b?.type === 'laser';
const TURN = 7; // radians per second a turret head turns

// Hit points of buildings; everything else has DEFAULT_HP.
export const BUILDING_HP = { wall: 600, turret: 350, laser: 420, silo: 3000, storage: 260, power: 300, geo: 320, refinery: 300, tank: 300, constructor: 260, furnace: 220, assembler: 220, drill: 160, pump: 160, pole: 110, pipe: 90, dronePort: 220, solar: 120, wind: 200, battery: 260 };
const DEFAULT_HP = 150;
export const maxHp = (b) => BUILDING_HP[b.type] ?? DEFAULT_HP;
// Creatures walk over these and never bite them.
const FLAT = new Set(['belt', 'rail', 'station', 'signal']);
export const isSolid = (b) => !!b && !FLAT.has(b.type);
const REPAIR_AFTER = 8; // seconds without damage before a building mends itself
const REPAIR_RATE = 0.03; // share of its hit points per second
const MAX_RUINS = 400;

const SQRT2 = Math.SQRT2;
const NEIGHBOURS = [
  [1, 0, 1],
  [-1, 0, 1],
  [0, 1, 1],
  [0, -1, 1],
  [1, 1, SQRT2],
  [1, -1, SQRT2],
  [-1, 1, SQRT2],
  [-1, -1, SQRT2],
];

// `at(x, z)` is the building on a tile, `demolish(b)` takes one away for good,
// `now()` the factory clock. `onKill(kind)` and friends feed the statistics.
export function createEnemies({ world, buildings, research, at, demolish, sizeOf = () => 1, now, mode: startMode = 'off', grace = null }) {
  const size = world.size;
  const chunks = Math.ceil(size / CHUNK);
  let smog = new Float32Array(chunks * chunks);
  const absorb = new Float32Array(chunks * chunks);
  for (const t of world.tiles) absorb[Math.floor(t.z / CHUNK) * chunks + Math.floor(t.x / CHUNK)] += (ABSORB[t.terrain] ?? ABSORB_LAND) / (CHUNK * CHUNK);

  let mode = ENEMY_MODES[startMode] ? startMode : 'off';
  let graceTime = grace; // a map can start the attacks sooner than its mode
  let evo = 0;
  let nests = [];
  let creatures = [];
  let groups = [];
  let ruins = [];
  let nextId = 1;
  let killed = 0; // creatures killed
  let nestsKilled = 0;
  let lost = 0; // buildings destroyed
  let waves = 0;
  let smogMade = 0; // smog per minute, smoothed
  let lastAttack = null; // { x, z, time } of the last wave or bite
  let clock = 0;
  const damaged = new Set(); // buildings below full hit points
  const fx = []; // shots, hits and deaths for the view
  const destroyed = []; // buildings creatures tore down, for the view
  const alerts = []; // waves that just set off, for the HUD
  const aim = new WeakMap(); // turret -> { target, cool }
  const rand = mulberry32((world.seed ?? 1) * 7919 + 17);

  const active = () => mode !== 'off';
  const params = () => ENEMY_MODES[mode];
  const walkable = (t) => !!t && TERRAIN[t.terrain].buildable;
  const tileAt = (x, z) => (x < 0 || z < 0 || x >= size || z >= size ? null : world.tiles[z * size + x]);
  const chunkOf = (x, z) => Math.floor(Math.max(0, Math.min(size - 1, z)) / CHUNK) * chunks + Math.floor(Math.max(0, Math.min(size - 1, x)) / CHUNK);
  const push = (list, item, max = 600) => {
    list.push(item);
    if (list.length > max) list.splice(0, list.length - max);
  };

  // --- Nests ---------------------------------------------------------------------

  // Nests sit in small colonies far from the middle of the map and from anything
  // built already, on free land without ore.
  function placeNests() {
    nests = [];
    const p = params();
    const want = Math.max(3, Math.round(((size * size) / 820) * (p.nests ?? 1)));
    const c = (size - 1) / 2;
    const away = Math.max(16, size * 0.3);
    const built = [...buildings.values()];
    const free = (x, z) => {
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
        const t = tileAt(x + dx, z + dz);
        if (!walkable(t) || t.ore || t.vent || at(x + dx, z + dz)) return false;
      }
      return true;
    };
    const fits = (x, z) =>
      x > 2 && z > 2 && x < size - 3 && z < size - 3 && free(x, z) &&
      Math.hypot(x - c, z - c) >= away &&
      !nests.some((n) => Math.hypot(n.x - x, n.z - z) < 3.2) &&
      !built.some((b) => Math.hypot(b.tile.x - x, b.tile.z - z) < 14);
    for (let tries = 0; nests.length < want && tries < 3000; tries++) {
      const x = Math.floor(rand() * size);
      const z = Math.floor(rand() * size);
      if (!fits(x, z)) continue;
      // A colony of one to three nests.
      const colony = 1 + Math.floor(rand() * 3);
      addNest(x, z);
      for (let k = 1, t2 = 0; k < colony && t2 < 30 && nests.length < want; t2++) {
        const nx = x + Math.round((rand() - 0.5) * 8);
        const nz = z + Math.round((rand() - 0.5) * 8);
        if (!fits(nx, nz)) continue;
        addNest(nx, nz);
        k++;
      }
    }
  }

  function addNest(x, z) {
    const max = Math.round(NEST_HP * (1 + evo));
    nests.push({ id: nextId++, x, z, hp: max, max, anger: 0, cool: 40 + rand() * 80, hurtAt: -99, shooter: null, seed: rand() });
  }

  // Building is not allowed right next to a nest.
  const blocks = (tile) => active() && nests.some((n) => Math.abs(n.x - tile.x) <= NEST_CLEAR && Math.abs(n.z - tile.z) <= NEST_CLEAR);
  const nestAt = (tile) => (active() ? nests.find((n) => Math.abs(n.x - tile.x) <= 1 && Math.abs(n.z - tile.z) <= 1) ?? null : null);

  function setMode(next) {
    if (!ENEMY_MODES[next] || next === mode) return;
    mode = next;
    if (mode === 'off') {
      creatures = [];
      groups = [];
      return;
    }
    if (!nests.length) placeNests();
  }

  // --- Smog ----------------------------------------------------------------------

  function tickSmog(dt) {
    let made = 0;
    for (const b of buildings.values()) {
      const rate = POLLUTION[b.type];
      if (!rate || b.state !== 'work') continue;
      // A power plant smokes as hard as it burns: renewable power on the same
      // network lets it idle.
      const n = (rate / 60) * dt * (b.type === 'power' ? Math.max(0.15, b.load ?? 1) : 1);
      smog[chunkOf(b.tile.x, b.tile.z)] += n;
      made += n;
    }
    smogMade += ((made / dt) * 60 - smogMade) * Math.min(1, dt * 0.1);
    const next = smog.slice();
    for (let cz = 0; cz < chunks; cz++) {
      for (let cx = 0; cx < chunks; cx++) {
        const i = cz * chunks + cx;
        const s = smog[i];
        if (s < SPREAD_MIN) continue;
        const share = s * SPREAD * dt;
        for (const [dx, dz] of NEIGHBOURS.slice(0, 4)) {
          const x = cx + dx;
          const z = cz + dz;
          next[i] -= share;
          if (x >= 0 && z >= 0 && x < chunks && z < chunks) next[z * chunks + x] += share;
        }
      }
    }
    for (let i = 0; i < next.length; i++) next[i] = Math.max(0, next[i] * (1 - absorb[i] * dt) - 0.002 * dt);
    smog = next;
  }

  const smogAt = (x, z) => smog[chunkOf(Math.round(x), Math.round(z))];

  // --- Waves -----------------------------------------------------------------------

  // The building a wave from this nest goes for: the nearest one that makes smog,
  // or the nearest solid one.
  function targetFor(x, z, polluting = true) {
    let best = null;
    let bestD = Infinity;
    for (const b of buildings.values()) {
      if (!isSolid(b) || (polluting && !POLLUTION[b.type])) continue;
      const d = Math.hypot(b.tile.x - x, b.tile.z - z);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best ?? (polluting ? targetFor(x, z, false) : null);
  }

  function tickNests(dt) {
    const p = params();
    const graceOver = now() >= (graceTime ?? p.grace ?? 0);
    for (const n of nests) {
      // Soak up the smog in the chunks around the nest.
      let take = 0;
      const cx = Math.floor(n.x / CHUNK);
      const cz = Math.floor(n.z / CHUNK);
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
        if (cx + dx < 0 || cz + dz < 0 || cx + dx >= chunks || cz + dz >= chunks) continue;
        const i = (cz + dz) * chunks + cx + dx;
        const t = smog[i] * Math.min(1, NEST_ABSORB * dt * (dx || dz ? 0.5 : 1));
        smog[i] -= t;
        take += t;
      }
      evo += (1 - evo) * take * EVO_SMOG * (p.evo ?? 1);
      n.anger = Math.min(MAX_ANGER, n.anger + take * (p.absorb ?? 1));
      n.cool -= dt;
      if (n.hp < n.max && clock - n.hurtAt > 10) n.hp = Math.min(n.max, n.hp + 3 * dt);
      // Under fire, the nest and its colony send defenders at the turret that shoots.
      const alarm = nests.find((m) => clock - m.hurtAt < 4 && m.shooter != null && Math.hypot(m.x - n.x, m.z - n.z) < 9);
      if (alarm && creatures.length < MAX_CREATURES) {
        const out = creatures.filter((c) => c.nest === n.id && c.defend).length;
        if (out < DEFENDERS && (n.spawnCool = (n.spawnCool ?? 0) - dt) <= 0) {
          n.spawnCool = alarm === n ? 1.2 : 2.4;
          spawn(pickKind(n.anger + 30), n, null, alarm.shooter);
        }
      }
      if (!p.attacks || !graceOver || n.cool > 0 || n.anger < WAVE_ANGER) continue;
      sendWave(n);
    }
    evo += (1 - evo) * EVO_TIME * dt * (p.evo ?? 1);
  }

  function pickKind(budget) {
    const kinds = Object.entries(CREATURES).filter(([, c]) => c.evo <= evo && c.cost <= budget);
    if (!kinds.length) return 'crawler';
    // Stronger kinds get likelier the further evolution goes.
    const weights = kinds.map(([, c]) => (c.evo === 0 ? 1.2 - evo : 0.4 + (evo - c.evo) * 2));
    let r = rand() * weights.reduce((a, w) => a + Math.max(0.05, w), 0);
    for (let k = 0; k < kinds.length; k++) {
      r -= Math.max(0.05, weights[k]);
      if (r <= 0) return kinds[k][0];
    }
    return kinds[0][0];
  }

  function sendWave(n) {
    if (creatures.length >= MAX_CREATURES) return;
    const target = targetFor(n.x, n.z);
    if (!target) return;
    const group = { id: nextId++, nest: n.id, target: target.index, path: null, home: false };
    let budget = Math.min(n.anger, 50 + 600 * evo);
    const most = 4 + Math.floor(evo * 22);
    let count = 0;
    while (count < most && creatures.length < MAX_CREATURES) {
      const kind = pickKind(budget);
      const cost = CREATURES[kind].cost;
      if (cost > budget) break;
      budget -= cost;
      n.anger -= cost;
      spawn(kind, n, group.id);
      count++;
    }
    if (!count) return;
    groups.push(group);
    n.cool = (60 + rand() * 70) / (mode === 'hard' ? 1.6 : 1);
    waves++;
    lastAttack = { x: target.tile.x, z: target.tile.z, time: now() };
    push(alerts, { nest: n, target, count }, 20);
  }

  function spawn(kind, n, groupId, goal = null) {
    const c = CREATURES[kind];
    const a = rand() * Math.PI * 2;
    const hp = Math.round(c.hp * (1 + evo * 1.6));
    creatures.push({
      id: nextId++,
      kind,
      x: n.x + Math.cos(a) * 1.2,
      z: n.z + Math.sin(a) * 1.2,
      hp,
      max: hp,
      nest: n.id,
      group: groupId,
      step: 0,
      ox: (rand() - 0.5) * 0.7,
      oz: (rand() - 0.5) * 0.7,
      cool: rand(),
      goal, // a building index it heads for directly (defenders, angry creatures)
      defend: goal !== null,
      bite: null,
      heading: a,
      walk: rand() * 10,
    });
  }

  // --- Paths -----------------------------------------------------------------------

  // A* over the tiles, eight ways. Buildings cost more the longer they take to bite
  // through, so creatures walk around a wall when the way round is short.
  function findPath(sx, sz, goal) {
    const start = Math.round(sz) * size + Math.round(sx);
    const gx = goal.tile.x;
    const gz = goal.tile.z;
    const reach = (sizeOf(goal.type) - 1) / 2 + 1.5;
    const g = new Float32Array(size * size).fill(Infinity);
    const from = new Int32Array(size * size).fill(-1);
    const open = [];
    const pushHeap = (i, f) => {
      open.push([f, i]);
      let k = open.length - 1;
      while (k > 0) {
        const up = (k - 1) >> 1;
        if (open[up][0] <= open[k][0]) break;
        [open[up], open[k]] = [open[k], open[up]];
        k = up;
      }
    };
    const popHeap = () => {
      const top = open[0];
      const last = open.pop();
      if (open.length) {
        open[0] = last;
        let k = 0;
        for (;;) {
          const l = k * 2 + 1;
          const r = l + 1;
          let m = k;
          if (l < open.length && open[l][0] < open[m][0]) m = l;
          if (r < open.length && open[r][0] < open[m][0]) m = r;
          if (m === k) break;
          [open[m], open[k]] = [open[k], open[m]];
          k = m;
        }
      }
      return top;
    };
    const h = (x, z) => Math.hypot(x - gx, z - gz);
    g[start] = 0;
    pushHeap(start, h(start % size, Math.floor(start / size)));
    let end = -1;
    let budget = size * size * 3;
    while (open.length && budget-- > 0) {
      const [f, i] = popHeap();
      const x = i % size;
      const z = (i - x) / size;
      if (f - h(x, z) > g[i] + 1e-6) continue;
      if (Math.max(Math.abs(x - gx), Math.abs(z - gz)) <= reach) {
        end = i;
        break;
      }
      for (const [dx, dz, step] of NEIGHBOURS) {
        const nx = x + dx;
        const nz = z + dz;
        const t = tileAt(nx, nz);
        if (!walkable(t)) continue;
        // No cutting corners past rock or water.
        if (dx && dz && (!walkable(tileAt(x + dx, z)) || !walkable(tileAt(x, z + dz)))) continue;
        const b = at(nx, nz);
        let cost = step;
        if (isSolid(b) && b !== goal) cost += ((b.hp ?? maxHp(b)) / 40) * (dx && dz ? 1.6 : 1);
        const j = nz * size + nx;
        const ng = g[i] + cost;
        if (ng >= g[j]) continue;
        g[j] = ng;
        from[j] = i;
        pushHeap(j, ng + h(nx, nz));
      }
    }
    if (end < 0) return null;
    const path = [];
    for (let i = end; i >= 0 && i !== start; i = from[i]) path.push(i);
    path.reverse();
    return path;
  }

  // --- Creatures -------------------------------------------------------------------

  const groupById = (id) => groups.find((g) => g.id === id) ?? null;
  const nestById = (id) => nests.find((n) => n.id === id) ?? null;

  // Where a group goes next after its target fell: something solid close by, or home.
  function retarget(group, x, z) {
    let best = null;
    let bestD = 12;
    for (const b of buildings.values()) {
      if (!isSolid(b)) continue;
      const d = Math.hypot(b.tile.x - x, b.tile.z - z);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    // Nothing close: on to the next building that makes smog.
    best ??= targetFor(x, z);
    group.path = null;
    if (best) group.target = best.index;
    else group.home = true;
  }

  function hurtBuilding(b, damage) {
    if (at(b.tile.x, b.tile.z) !== b) return;
    b.hp = (b.hp ?? maxHp(b)) - damage;
    b.hitAt = now();
    damaged.add(b);
    lastAttack = { x: b.tile.x, z: b.tile.z, time: now() };
    if (b.hp > 0) return;
    // Down it goes; the ruin remembers it for rebuilding.
    damaged.delete(b);
    const ruin = { type: b.type, index: b.index, dir: b.dir };
    for (const k of ['recipe', 'mode', 'chain', 'oneway', 'request', 'want']) if (b[k] !== undefined) ruin[k] = b[k];
    push(ruins, ruin, MAX_RUINS);
    lost++;
    demolish(b);
    push(destroyed, b, 200);
    push(fx, { type: 'boom', x: b.tile.x, z: b.tile.z, big: b.type === 'silo' || isTurret(b) });
  }

  function moveCreature(c, dt) {
    const kind = CREATURES[c.kind];
    c.cool -= dt;
    // Biting: stay and chew until the building falls.
    if (c.bite !== null) {
      const there = at(c.bite % size, Math.floor(c.bite / size));
      if (!there || !isSolid(there)) {
        c.bite = null;
      } else {
        c.heading = Math.atan2(there.tile.x - c.x, there.tile.z - c.z);
        if (c.cool <= 0) {
          c.cool = 1 / kind.rate;
          if (kind.reach > 2) push(fx, { type: 'acid', x: c.x, z: c.z, x2: there.tile.x, z2: there.tile.z });
          else c.lunge = 0.25;
          hurtBuilding(there, kind.damage * (1 + evo));
        }
        return;
      }
    }
    // Where to: straight to a goal building, along the group path, or home.
    let tx;
    let tz;
    let goalB = null;
    if (c.goal !== null) {
      goalB = at(c.goal % size, Math.floor(c.goal / size));
      if (!isSolid(goalB)) {
        c.goal = null;
        if (c.defend) {
          c.group = null;
          c.home = true;
        }
        return;
      }
      tx = goalB.tile.x;
      tz = goalB.tile.z;
    } else {
      const group = c.group !== null ? groupById(c.group) : null;
      if (!group || group.home || c.home) {
        const n = nestById(c.nest);
        if (!n || Math.hypot(n.x - c.x, n.z - c.z) < 2.2) {
          // Back home: it rejoins the nest.
          if (n) n.anger = Math.min(MAX_ANGER, n.anger + kind.cost * 0.5);
          c.dead = true;
          return;
        }
        tx = n.x;
        tz = n.z;
        if (group && !group.path) group.path = findPath(c.x, c.z, { tile: { x: n.x, z: n.z } }) ?? [];
        if (group?.path?.length) {
          const k = Math.min(c.step, group.path.length - 1);
          const i = group.path[k];
          tx = (i % size) + c.ox;
          tz = Math.floor(i / size) + c.oz;
          if (Math.hypot(tx - c.x, tz - c.z) < 0.4 && c.step < group.path.length - 1) c.step++;
        }
      } else {
        goalB = buildings.get(group.target) ?? null;
        if (!isSolid(goalB)) {
          retarget(group, c.x, c.z);
          for (const m of creatures) if (m.group === group.id) m.step = 0;
          return;
        }
        if (!group.path) {
          group.path = findPath(c.x, c.z, goalB);
          for (const m of creatures) if (m.group === group.id) m.step = 0;
          if (!group.path) {
            group.home = true;
            return;
          }
        }
        if (c.step < group.path.length) {
          const i = group.path[c.step];
          tx = (i % size) + c.ox;
          tz = Math.floor(i / size) + c.oz;
          if (Math.hypot(tx - c.x, tz - c.z) < 0.45) c.step++;
        } else {
          tx = goalB.tile.x;
          tz = goalB.tile.z;
        }
      }
    }
    // In reach of the goal: bite it (or spit at it).
    if (goalB) {
      const r = (sizeOf(goalB.type) - 1) / 2;
      const d = Math.max(0, Math.hypot(goalB.tile.x - c.x, goalB.tile.z - c.z) - r);
      if (d <= kind.reach + 0.05) {
        c.bite = goalB.index;
        return;
      }
    }
    const dx = tx - c.x;
    const dz = tz - c.z;
    const len = Math.hypot(dx, dz);
    if (len < 1e-3) return;
    const step = Math.min(len, kind.speed * dt);
    const nx = c.x + (dx / len) * step;
    const nz = c.z + (dz / len) * step;
    // Something solid in the way: bite through it (spitters spit from a distance).
    const ix = Math.round(nx);
    const iz = Math.round(nz);
    const blocker = at(ix, iz);
    if (isSolid(blocker)) {
      c.bite = blocker.index;
      return;
    }
    if (!walkable(tileAt(ix, iz))) {
      // Slipped off the path: slide along instead of walking into water.
      if (walkable(tileAt(ix, Math.round(c.z)))) c.x = nx;
      else if (walkable(tileAt(Math.round(c.x), iz))) c.z = nz;
      return;
    }
    c.heading = Math.atan2(dx, dz);
    c.walk += step * 6;
    c.x = nx;
    c.z = nz;
  }

  // --- Turrets ---------------------------------------------------------------------

  // Ammunition from belts (and requester chests) on any side.
  function accept(b, kind) {
    if (b.type !== 'turret' || kind !== 'ammo') return false;
    if ((b.ammo ?? 0) >= TURRET.store) return false;
    b.ammo = (b.ammo ?? 0) + 1;
    return true;
  }

  function hurtCreature(c, damage, from) {
    c.hp -= Math.max(1, damage - CREATURES[c.kind].armor);
    // Shot from close by: go for the shooter.
    if (from && c.goal === null && c.bite === null && Math.hypot(from.tile.x - c.x, from.tile.z - c.z) < 6) c.goal = from.index;
    if (c.hp > 0) return;
    c.dead = true;
    killed++;
    push(fx, { type: 'death', x: c.x, z: c.z, kind: c.kind });
  }

  function hurtNest(n, damage, from) {
    n.hp -= damage;
    n.hurtAt = clock;
    n.shooter = from?.index ?? null;
    if (n.hp > 0) return;
    n.dead = true;
    nestsKilled++;
    evo += (1 - evo) * EVO_NEST * (params().evo ?? 1);
    push(fx, { type: 'nestDeath', x: n.x, z: n.z });
    for (const c of creatures) if (c.nest === n.id && c.goal === null) c.home = true;
  }

  function tickTurret(b, dt, speed) {
    const laser = b.type === 'laser';
    const spec = laser ? LASER : TURRET;
    const range = spec.range;
    let s = aim.get(b);
    if (!s) aim.set(b, (s = { target: null, cool: 0, scan: 0 }));
    s.cool -= dt;
    s.scan -= dt;
    // Keep a live target in range, look for a new one now and then.
    let target = s.target;
    if (target && (target.dead || Math.hypot(target.x - b.tile.x, target.z - b.tile.z) > range + (target.max && !target.kind ? 1.2 : 0))) target = null;
    if (!target && s.scan <= 0) {
      s.scan = 0.2;
      let bestD = range;
      for (const c of creatures) {
        const d = Math.hypot(c.x - b.tile.x, c.z - b.tile.z);
        if (d < bestD) {
          bestD = d;
          target = c;
        }
      }
      // No creature close: a nest in reach.
      if (!target) for (const n of nests) if (!n.dead && Math.hypot(n.x - b.tile.x, n.z - b.tile.z) < range + 1.2) target = n;
    }
    s.target = target;
    if (!target) {
      b.state = laser || b.ammo || b.shots ? 'idle' : 'empty';
      return;
    }
    // Turn towards it, fire when lined up.
    const want = Math.atan2(-(target.x - b.tile.x), -(target.z - b.tile.z));
    const cur = b.aim ?? 0;
    let diff = ((want - cur + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
    const turn = Math.min(Math.abs(diff), TURN * dt) * Math.sign(diff);
    b.aim = cur + turn;
    diff -= turn;
    if (laser && speed <= 0) {
      b.state = 'nopower';
      return;
    }
    if (!laser && !b.shots && !b.ammo) {
      b.state = 'empty';
      return;
    }
    b.state = 'work';
    if (Math.abs(diff) > 0.25 || s.cool > 0) return;
    s.cool = 1 / (spec.rate * (laser ? speed : 1));
    if (!laser) {
      if (!b.shots) {
        b.ammo--;
        b.shots = TURRET.shots;
      }
      b.shots--;
    }
    const damage = spec.damage * research.stats.weapons;
    push(fx, { type: laser ? 'laser' : 'bullet', x: b.tile.x, z: b.tile.z, x2: target.x, z2: target.z, from: b });
    b.fired = (b.fired ?? 0) + 1;
    if (target.kind) hurtCreature(target, damage, b);
    else hurtNest(target, damage, b);
  }

  // --- Tick ------------------------------------------------------------------------

  let slow = 0;
  function tick(dt, laserSpeed) {
    if (!active()) {
      // Turrets still turn idle so they do not look broken.
      for (const b of buildings.values()) if (isTurret(b)) b.state = b.type === 'laser' || b.ammo || b.shots ? 'idle' : 'empty';
      return;
    }
    clock += dt;
    slow += dt;
    if (slow >= 0.5) {
      tickSmog(slow);
      tickNests(slow);
      slow = 0;
    }
    for (const c of creatures) moveCreature(c, dt);
    for (const b of buildings.values()) if (isTurret(b)) tickTurret(b, dt, b.type === 'laser' ? laserSpeed(b) : 1);
    if (creatures.some((c) => c.dead)) creatures = creatures.filter((c) => !c.dead);
    if (nests.some((n) => n.dead)) nests = nests.filter((n) => !n.dead);
    // Groups without members are done.
    if (groups.length) {
      const alive = new Set(creatures.map((c) => c.group));
      groups = groups.filter((g) => alive.has(g.id));
    }
    // Buildings mend themselves after a while without bites.
    const t = now();
    for (const b of damaged) {
      if (t - (b.hitAt ?? 0) < REPAIR_AFTER) continue;
      b.hp = Math.min(maxHp(b), b.hp + maxHp(b) * REPAIR_RATE * dt);
      if (b.hp >= maxHp(b)) {
        delete b.hp;
        delete b.hitAt;
        damaged.delete(b);
      }
    }
  }

  // Ruins whose spot is free and safe again; `place(ruin)` builds one back.
  function rebuild(place) {
    let n = 0;
    ruins = ruins.filter((r) => {
      const x = r.index % size;
      const z = Math.floor(r.index / size);
      if (creatures.some((c) => Math.hypot(c.x - x, c.z - z) < 6)) return true;
      if (at(x, z)) return false; // something else stands there now
      if (place(r)) n++;
      return false;
    });
    return n;
  }

  // Totals for the HUD.
  function summary() {
    let attacking = 0;
    for (const c of creatures) if (c.group !== null || c.goal !== null) attacking++;
    let turrets = 0;
    let empty = 0;
    for (const b of buildings.values()) {
      if (!isTurret(b)) continue;
      turrets++;
      if (b.state === 'empty' || b.state === 'nopower') empty++;
    }
    const p = params();
    const graceLeft = Math.max(0, (graceTime ?? p.grace ?? 0) - now());
    return { mode, nests: nests.length, creatures: creatures.length, attacking, evo, killed, nestsKilled, lost, waves, smog: smogMade, turrets, empty, ruins: ruins.length, graceLeft, attacks: !!p.attacks };
  }

  function save() {
    return {
      mode,
      grace: graceTime,
      evo,
      killed,
      nestsKilled,
      lost,
      waves,
      nextId,
      clock,
      smog: Array.from(smog, (s) => Math.round(s * 10) / 10),
      nests: nests.map(({ shooter, spawnCool, ...n }) => n),
      creatures: creatures.map(({ lunge, ...c }) => c),
      groups: groups.map(({ path, ...g }) => g),
      ruins: [...ruins],
      lastAttack,
    };
  }

  function load(data) {
    if (!data) return;
    mode = ENEMY_MODES[data.mode] ? data.mode : 'off';
    graceTime = data.grace ?? graceTime;
    evo = data.evo ?? 0;
    killed = data.killed ?? 0;
    nestsKilled = data.nestsKilled ?? 0;
    lost = data.lost ?? 0;
    waves = data.waves ?? 0;
    nextId = data.nextId ?? 1;
    clock = data.clock ?? 0;
    if (data.smog?.length === smog.length) smog = Float32Array.from(data.smog);
    nests = (data.nests ?? []).map((n) => ({ ...n, shooter: null }));
    creatures = (data.creatures ?? []).map((c) => ({ ...c }));
    groups = (data.groups ?? []).map((g) => ({ ...g, path: null }));
    ruins = [...(data.ruins ?? [])];
    lastAttack = data.lastAttack ?? null;
    damaged.clear();
    for (const b of buildings.values()) if (b.hp !== undefined) damaged.add(b);
  }

  // Called once a factory is set up: a new game in a mode with enemies gets its nests.
  function start() {
    if (active() && !nests.length) placeNests();
  }

  return {
    tick,
    accept,
    blocks,
    nestAt,
    setMode,
    start,
    rebuild,
    summary,
    save,
    load,
    smogAt,
    hurtBuilding,
    // Sends a wave from a nest right away, for testing.
    attack(n, anger = 100) {
      n.anger = Math.max(n.anger, anger);
      sendWave(n);
    },
    maxHp,
    get mode() {
      return mode;
    },
    get active() {
      return active();
    },
    get evo() {
      return evo;
    },
    get killed() {
      return killed;
    },
    get nestsKilled() {
      return nestsKilled;
    },
    get nests() {
      return nests;
    },
    get creatures() {
      return creatures;
    },
    get ruins() {
      return ruins;
    },
    get lastAttack() {
      return lastAttack;
    },
    smog: () => smog,
    chunks,
    fx,
    destroyed,
    alerts,
    damaged,
  };
}
