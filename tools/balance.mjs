// Balancing check: runs the real factory simulation (src/factory.js) on a flat test
// world, measures what one production line delivers per minute and how long the
// first part takes to arrive, then estimates how long every mission and every
// research entry takes for a player who builds the obvious lines.
//
//   node tools/balance.mjs
//
// The estimate is play time = building time + waiting for the parts. Building
// time assumes a quick but not perfect player (see BUILD_SECONDS).
import { createFactory, BUILDINGS } from '../src/factory.js';
import { SCENARIOS } from '../src/scenarios.js';
import { RESEARCH, STATS } from '../src/research.js';

const SIZE = 64;
const BUILD_SECONDS = { building: 6, belt: 1.2 }; // per placed building / belt tile
// The test lines have two belt tiles between steps; on a real map the way is longer.
const BELTS_PER_STEP = 5;
// Three stars should need a player who plans well, not a perfect one.
const PAR_FACTOR = 1.6;
const ALL = Object.keys(BUILDINGS);

function flatWorld() {
  const tiles = [];
  for (let z = 0; z < SIZE; z++) for (let x = 0; x < SIZE; x++) tiles.push({ x, z, terrain: 'grass', ore: null, amount: 0, position: { x, z } });
  return { seed: 0, size: SIZE, tiles, at: (x, z) => tiles[z * SIZE + x] };
}

// Lines: how one item is made from ore. Each step stands two belt tiles after the last.
// `inputs` of a constructor line are lines that feed it from the west and the south.
const LINES = {
  iron: { steps: ['drill:iron'] },
  copper: { steps: ['drill:copper'] },
  coal: { steps: ['drill:coal'] },
  stone: { steps: ['drill:stone'] },
  ironIngot: { steps: ['drill:iron', 'furnace'] },
  copperIngot: { steps: ['drill:copper', 'furnace'] },
  ironPlate: { steps: ['drill:iron', 'furnace', 'assembler'] },
  wire: { steps: ['drill:copper', 'furnace', 'assembler'] },
  concrete: { steps: ['drill:stone', 'assembler'] },
  gear: { recipe: 'gear', inputs: ['ironPlate', 'ironPlate'] },
  circuit: { recipe: 'circuit', inputs: ['ironPlate', 'wire'] },
  steel: { recipe: 'steel', inputs: ['ironIngot', 'coal'] },
};

const E = 1;
const N = 0;

// Builds a simple chain that runs in direction `dir` and ends on tile (ex, ez),
// which is then a belt handing its items on in `dir`. Returns the buildings placed.
function chain(factory, world, steps, ex, ez, dir) {
  const back = dir === E ? { x: -1, z: 0 } : { x: 0, z: 1 };
  const kinds = [];
  for (const s of steps) kinds.push(s, 'belt', 'belt');
  kinds.reverse(); // from the end back to the drill
  let x = ex;
  let z = ez;
  for (const k of kinds) {
    const [type, ore] = k.split(':');
    const tile = world.at(x, z);
    if (ore) Object.assign(tile, { ore, amount: 1e6 });
    if (!factory.place(type, tile, dir)) throw new Error(`cannot place ${type} at ${x},${z}`);
    x += back.x;
    z += back.z;
  }
  return kinds.length;
}

// Places one line for `item` with its storage; returns the number of buildings and belts.
function buildLine(factory, world, item, oy) {
  const line = LINES[item];
  const cx = 40;
  const cost = { building: 0, belt: 0 };
  const add = (steps) => {
    cost.building += steps.length;
    cost.belt += steps.length * BELTS_PER_STEP;
  };
  if (line.steps) {
    chain(factory, world, line.steps, cx, oy, E);
    add(line.steps);
  } else {
    const [a, b] = line.inputs.map((i) => LINES[i].steps);
    chain(factory, world, a, cx - 1, oy, E);
    chain(factory, world, b, cx, oy + 1, N);
    add(a);
    add(b);
    const c = factory.place('constructor', world.at(cx, oy), E);
    factory.setRecipe(c, line.recipe);
    cost.building++;
  }
  factory.place('belt', world.at(cx + 1, oy), E);
  factory.place('storage', world.at(cx + 2, oy), E);
  cost.belt += BELTS_PER_STEP;
  cost.building++;
  return cost;
}

// Runs one line alone: parts per minute once it is full, seconds until the first part.
function measure(item, stats) {
  const world = flatWorld();
  const factory = createFactory(world, { start: ALL });
  Object.assign(factory.research.stats, stats);
  const cost = buildLine(factory, world, item, 10);
  let first = null;
  const step = 1 / 60;
  let atWarm = 0;
  for (let t = 0; t < 240; t += step) {
    factory.tick(step);
    if (first === null && factory.delivered[item] > 0) first = factory.time;
    if (Math.abs(factory.time - 120) < step / 2) atWarm = factory.delivered[item];
  }
  const perMin = (factory.delivered[item] - atWarm) / 2;
  return { perMin, first: first ?? Infinity, cost };
}

const baseStats = () => Object.fromEntries(STATS.map((s) => [s, 1]));
const fmt = (sec) => {
  const s = Math.round(sec);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
};
const buildTime = (c) => c.building * BUILD_SECONDS.building + c.belt * BUILD_SECONDS.belt;

// --- Line throughput at the start -------------------------------------------------

console.log('\nLeistung einer Linie (ohne Verbesserungen)');
const base = baseStats();
for (const item of Object.keys(LINES)) {
  const m = measure(item, base);
  console.log(`  ${item.padEnd(12)} ${m.perMin.toFixed(1).padStart(5)} /min  erstes Teil nach ${m.first.toFixed(1)} s`);
}

// --- Missions ---------------------------------------------------------------------
//
// For every mission the player builds one line per item it needs (lines that already
// stand from earlier missions are reused), and as many lines as a rate goal needs.

function planScenario(s) {
  const stats = baseStats();
  const lines = {}; // item -> lines standing
  let total = 0;
  const rows = [];
  for (const m of s.missions) {
    let build = 0;
    let wait = 0;
    for (const g of m.goals) {
      if (g.build) {
        const have = g.build === 'drill' ? Object.keys(lines).length : 0;
        build += Math.max(0, g.count - have) * BUILD_SECONDS.building;
        continue;
      }
      const item = g.deliver ?? g.rate;
      const line = measure(item, stats);
      const need = g.deliver ? 1 : Math.ceil(g.perMin / line.perMin);
      const have = lines[item] ?? 0;
      if (need > have) {
        build += (need - have) * buildTime(line.cost);
        lines[item] = need;
      }
      const n = lines[item];
      // Deliveries: the lines fill, then deliver at their rate. Rates: a full minute.
      const t = g.deliver ? line.first + (g.count / (line.perMin * n)) * 60 : line.first + 60;
      wait = Math.max(wait, t);
    }
    // Earlier lines keep running while the player builds, so waiting overlaps building a bit.
    const time = build + wait * 0.8;
    total += time;
    rows.push(`    ${m.name.padEnd(20)} bauen ${fmt(build).padStart(5)}  warten ${fmt(wait).padStart(5)}  → ${fmt(time).padStart(5)}  (gesamt ${fmt(total)})`);
    for (const [stat, f] of Object.entries(m.reward.boosts ?? {})) stats[stat] *= f;
  }
  const suggest = Math.round((total * PAR_FACTOR) / 60);
  console.log(`\n${s.name}: geschätzt ${fmt(total)}, drei Sterne unter ${s.par}:00 (Vorschlag ${suggest}:00)`);
  rows.forEach((r) => console.log(r));
  return total;
}

console.log('\nMissionen');
for (const s of SCENARIOS) if (!s.free) planScenario(s);

// --- Research tree ----------------------------------------------------------------
//
// The free game: research in tree order. For each entry the player has one line per
// cost item, and adds a second line once a cost reaches 60 parts.

console.log('\nForschungsbaum (freies Spiel)');
{
  const stats = baseStats();
  const lines = {};
  let total = 0;
  const done = new Set();
  const order = [];
  while (order.length < RESEARCH.length) {
    const r = RESEARCH.find((x) => !done.has(x.id) && x.requires.every((id) => done.has(id)));
    order.push(r);
    done.add(r.id);
  }
  for (const r of order) {
    let build = 0;
    let wait = 0;
    for (const [item, n] of Object.entries(r.cost)) {
      const line = measure(item, stats);
      const want = n >= 60 ? 2 : 1;
      if ((lines[item] ?? 0) < want) {
        build += (want - (lines[item] ?? 0)) * buildTime(line.cost);
        lines[item] = want;
      }
      wait = Math.max(wait, line.first + (n / (line.perMin * lines[item])) * 60);
    }
    const time = build + wait * 0.8;
    total += time;
    console.log(`    ${r.name.padEnd(22)} bauen ${fmt(build).padStart(5)}  warten ${fmt(wait).padStart(5)}  → ${fmt(time).padStart(5)}  (gesamt ${fmt(total)})`);
    for (const [stat, f] of Object.entries(r.boosts ?? {})) stats[stat] *= f;
  }
}
