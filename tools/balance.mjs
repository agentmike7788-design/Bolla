// Balancing check: runs the real factory simulation (src/factory.js) on a flat test
// world, measures what one production line delivers per minute and how long the
// first part takes to arrive, then estimates how long every mission and every
// research entry takes for a player who builds the obvious lines.
//
//   node tools/balance.mjs
//
// The estimate is play time = building time + waiting for the parts. Building
// time assumes a quick but not perfect player (see BUILD_SECONDS).
import { createFactory, BUILDINGS, CONSTRUCTOR_RECIPES, PUMP_RATE } from '../src/factory.js';
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
  // Oil lines: pump, pipes, refinery, with a pole and a power plant beside them.
  plastic: { refinery: 'plastic' },
  fuel: { refinery: 'fuel' },
  // Built from two finished lines: estimated from those lines and the recipe alone.
  processor: { recipe: 'processor', feeds: ['circuit', 'plastic'] },
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
  } else if (line.refinery) {
    // Pump, two pipes, refinery, two belts. The plant is fed by hand in measure().
    Object.assign(world.at(cx - 5, oy), { ore: 'oil', amount: 1e6 });
    factory.place('pump', world.at(cx - 5, oy), E);
    factory.place('pipe', world.at(cx - 4, oy), E);
    factory.place('pipe', world.at(cx - 3, oy), E);
    factory.setRecipe(factory.place('refinery', world.at(cx - 2, oy), E), line.refinery);
    factory.place('belt', world.at(cx - 1, oy), E);
    factory.place('belt', world.at(cx, oy), E);
    factory.place('pole', world.at(cx - 3, oy + 1), E);
    factory.place('power', world.at(cx - 3, oy + 2), E);
    // Pump, refinery, pole and plant; pipes cost about as much as belts.
    cost.building += 4;
    cost.belt += 2 * BELTS_PER_STEP;
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
  const line = LINES[item];
  if (line.feeds) return measureFed(item, stats);
  const world = flatWorld();
  const factory = createFactory(world, { start: ALL });
  Object.assign(factory.research.stats, stats);
  const cost = buildLine(factory, world, item, 10);
  let first = null;
  const step = 1 / 60;
  let atWarm = 0;
  const plants = [...factory.buildings.values()].filter((b) => b.type === 'power');
  for (let t = 0; t < 240; t += step) {
    for (const p of plants) p.fuel = 5;
    factory.tick(step);
    if (first === null && factory.delivered[item] > 0) first = factory.time;
    if (Math.abs(factory.time - 120) < step / 2) atWarm = factory.delivered[item];
  }
  const perMin = (factory.delivered[item] - atWarm) / 2;
  return { perMin, first: first ?? Infinity, cost };
}

// A constructor fed by two finished lines (lines of their own): as fast as the
// slower of its inputs and its recipe allow.
function measureFed(item, stats) {
  const line = LINES[item];
  const recipe = CONSTRUCTOR_RECIPES[line.recipe];
  const feeds = line.feeds.map((f) => ({ need: recipe.needs[f], ...measure(f, stats) }));
  const own = (60 / recipe.time) * stats.constructor;
  const perMin = Math.min(own, ...feeds.map((f) => f.perMin / f.need));
  const first = Math.max(...feeds.map((f) => f.first)) + recipe.time / stats.constructor + 3;
  const cost = { building: 1, belt: BELTS_PER_STEP };
  for (const f of feeds) {
    cost.building += f.cost.building;
    cost.belt += f.cost.belt;
  }
  return { perMin, first, cost };
}

// A railway: two drill lines load a station from its sides, the train runs
// RAIL_TILES of track (with a curve) to a station that unloads into a storage.
const RAIL_TILES = 40;
function measureTrain(stats) {
  const world = flatWorld();
  const factory = createFactory(world, { start: ALL });
  Object.assign(factory.research.stats, stats);
  const at = world.at;
  const z = 20;
  const A = factory.place('station', at(5, z), E);
  let prev = A;
  const turn = 5 + RAIL_TILES / 2;
  for (let x = 6; x <= turn; x++) prev = link(factory, prev, factory.place('rail', at(x, z), E));
  for (let zz = z + 1; zz <= z + 4; zz++) prev = link(factory, prev, factory.place('rail', at(turn, zz), E));
  for (let x = turn + 1; x < turn + RAIL_TILES / 2 - 4; x++) prev = link(factory, prev, factory.place('rail', at(x, z + 4), E));
  const bx = turn + RAIL_TILES / 2 - 4;
  const B = link(factory, prev, factory.place('station', at(bx, z + 4), E));
  factory.setMode(B, 'unload');
  for (const [dz, dir] of [[-3, 2], [3, 0]]) {
    Object.assign(at(5, z + dz), { ore: 'iron', amount: 1e6 });
    factory.place('drill', at(5, z + dz), dir);
    factory.place('belt', at(5, z + dz / 1.5), dir);
    factory.place('belt', at(5, z + dz / 3), dir);
  }
  factory.place('belt', at(bx, z + 5), 2);
  factory.place('storage', at(bx, z + 6), 2);
  factory.addTrain(at(5, z));
  let first = null;
  const step = 1 / 60;
  let atWarm = 0;
  for (let t = 0; t < 360; t += step) {
    factory.tick(step);
    if (first === null && factory.shipped > 0) first = factory.time;
    if (Math.abs(factory.time - 120) < step / 2) atWarm = factory.shipped;
  }
  const perMin = (factory.shipped - atWarm) / 4;
  return { perMin, first: first ?? Infinity, cost: { building: 6, belt: RAIL_TILES + 4 * 2 + 2 } };
}
function link(factory, a, b) {
  factory.linkTrack(a, b);
  return b;
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
{
  const m = measureTrain(base);
  console.log(`  ${'Zug'.padEnd(12)} ${m.perMin.toFixed(1).padStart(5)} /min  erste Lieferung nach ${m.first.toFixed(1)} s (${RAIL_TILES} Felder Gleis, zwei Bohrer)`);
}

// --- Missions ---------------------------------------------------------------------
//
// For every mission the player builds one line per item it needs (lines that already
// stand from earlier missions are reused), and as many lines as a rate goal needs.

function planScenario(s) {
  const stats = baseStats();
  const lines = {}; // item -> lines standing
  let pumps = 0;
  let total = 0;
  const rows = [];
  for (const m of s.missions) {
    let build = 0;
    let wait = 0;
    for (const g of m.goals) {
      if (g.powered) {
        // A plant fed by a coal line (reused when one stands) and a pole per three machines.
        // The speed bonus of the grid is left out, so later missions are estimated a bit slow.
        build += (2 + Math.ceil(g.powered / 3)) * BUILD_SECONDS.building + (lines.coal ? 0 : buildTime(measure('coal', stats).cost));
        lines.coal ??= 1;
        continue;
      }
      if (g.build) {
        const have = g.build === 'drill' ? Object.keys(lines).length : 0;
        // Rails are laid like belts; a train is set onto the track with one click.
        const each = g.build === 'rail' ? BUILD_SECONDS.belt : g.build === 'train' ? 2 : BUILD_SECONDS.building;
        build += Math.max(0, g.count - have) * each;
        if (g.build === 'rail') lines.train = 1;
        if (g.build === 'pump') {
          // A pole beside the pumps and a few pipes to a tank.
          build += BUILD_SECONDS.building * 2 + BELTS_PER_STEP * BUILD_SECONDS.belt;
          pumps = Math.max(pumps, g.count);
        }
        continue;
      }
      if (g.shipped) {
        // One railway with two drill lines; built in an earlier mission or now.
        const train = measureTrain(stats);
        if (!lines.train) build += buildTime(train.cost);
        lines.train = 1;
        wait = Math.max(wait, train.first + (g.shipped / train.perMin) * 60);
        continue;
      }
      if (g.oil) {
        wait = Math.max(wait, 3 + g.oil / (PUMP_RATE * stats.pump * Math.max(1, pumps)));
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
