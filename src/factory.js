import { ORES, TERRAIN } from './world.js';
import { createResearch } from './research.js';
import { createRailways, isTrack, axisBits, STATION_CAP } from './trains.js';

// Grid directions: 0 north (-z), 1 east (+x), 2 south (+z), 3 west (-x).
export const DIRS = [
  { x: 0, z: -1 },
  { x: 1, z: 0 },
  { x: 0, z: 1 },
  { x: -1, z: 0 },
];
export const DIR_NAMES = ['Nord', 'Ost', 'Süd', 'West'];

// Everything that can travel over a belt. shape picks the 3D model in buildings.js.
export const ITEMS = {
  ...Object.fromEntries(
    Object.entries(ORES)
      .filter(([, o]) => !o.fluid)
      .map(([k, o]) => [k, { name: o.name, color: o.color, shape: 'ore' }]),
  ),
  ironIngot: { name: 'Eisenbarren', color: 0xc4ccd4, shape: 'ingot' },
  copperIngot: { name: 'Kupferbarren', color: 0xe9894a, shape: 'ingot' },
  ironPlate: { name: 'Eisenplatte', color: 0x9fb0bf, shape: 'plate' },
  wire: { name: 'Kupferdraht', color: 0xd8742f, shape: 'wire' },
  concrete: { name: 'Beton', color: 0xd9d4c7, shape: 'block' },
  gear: { name: 'Zahnrad', color: 0xb8bec4, shape: 'gear' },
  circuit: { name: 'Schaltkreis', color: 0x3fae5a, shape: 'chip' },
  steel: { name: 'Stahlträger', color: 0x5d6b7a, shape: 'beam' },
  plastic: { name: 'Kunststoff', color: 0x8fd3ec, shape: 'roll' },
  fuel: { name: 'Treibstoff', color: 0xd8432c, shape: 'canister' },
  processor: { name: 'Prozessor', color: 0x7b5ce6, shape: 'cpu' },
};

// Machines turn one input item into one output item.
export const RECIPES = {
  furnace: { time: 2, makes: { iron: 'ironIngot', copper: 'copperIngot' } },
  assembler: { time: 1.6, makes: { ironIngot: 'ironPlate', copperIngot: 'wire', stone: 'concrete' } },
};

// The constructor combines several items into one; the player picks the recipe.
export const CONSTRUCTOR_RECIPES = {
  gear: { time: 2, needs: { ironPlate: 2 }, makes: 'gear' },
  circuit: { time: 3, needs: { ironPlate: 1, wire: 2 }, makes: 'circuit' },
  steel: { time: 2.5, needs: { ironIngot: 2, coal: 1 }, makes: 'steel' },
  // Shown once the refinery is unlocked: it needs plastic.
  processor: { time: 4, needs: { circuit: 2, plastic: 1 }, makes: 'processor', unlock: 'refinery' },
};

// The refinery turns oil from its pipes into items; the player picks the recipe.
export const REFINERY_RECIPES = {
  plastic: { time: 3, oil: 3, makes: 'plastic' },
  fuel: { time: 2, oil: 2, makes: 'fuel' },
};
const RECIPE_BOOK = { constructor: CONSTRUCTOR_RECIPES, refinery: REFINERY_RECIPES };
export const recipesOf = (type) => RECIPE_BOOK[type] ?? null;

export const BUILDINGS = {
  drill: { name: 'Bohrer' },
  belt: { name: 'Förderband' },
  storage: { name: 'Lager' },
  furnace: { name: 'Schmelzofen' },
  assembler: { name: 'Presse' },
  splitter: { name: 'Verteiler' },
  merger: { name: 'Zusammenführer' },
  constructor: { name: 'Konstruktor' },
  power: { name: 'Kohlekraftwerk' },
  pole: { name: 'Strommast' },
  pump: { name: 'Ölpumpe' },
  pipe: { name: 'Rohr' },
  tank: { name: 'Öltank' },
  refinery: { name: 'Raffinerie' },
  rail: { name: 'Gleis' },
  station: { name: 'Bahnhof' },
  train: { name: 'Zug', vehicle: true }, // not a building: a train on the track, see trains.js
};

export const BELT_SPEED = 1.5; // tiles per second, before research
export const ITEM_SPACING = 0.34; // minimum gap between two items on a belt, in tiles
export const DRILL_TIME = 1.4; // seconds per mined ore
const MACHINE_INPUT = 4; // items a machine buffers on each side
const MACHINE_OUTPUT = 4;
const SPLITTER_BUFFER = 2;

const opposite = (dir) => (dir + 2) % 4;
export const isMachine = (b) => b?.type === 'furnace' || b?.type === 'assembler';
// Buildings that never hand items on.
const NO_OUTPUT = new Set(['storage', 'power', 'pole', 'pump', 'pipe', 'tank', 'rail', 'station']);

// Power. A coal power plant burns coal from belts and feeds every network it is
// connected to. Poles carry the power: wires reach from pole to pole, and a pole
// supplies every building within its square. Machines run without power at their
// basic speed; on a network they run POWER_SPEED times as fast, but only while the
// network has enough power, and they stop when it has none.
export const POWER_OUTPUT = 8; // MW per power plant, before research
export const POWER_USE = { drill: 1, furnace: 2, assembler: 1.5, constructor: 3, pump: 1.5, refinery: 3 }; // MW while working
export const POWER_SPEED = 2;
export const COAL_SECONDS = 4; // one coal keeps a plant at full output that long
export const WIRE_REACH = 7; // tiles between two poles
export const POLE_SUPPLY = 2; // a pole supplies the tiles up to this far away (5×5)
const COAL_ENERGY = POWER_OUTPUT * COAL_SECONDS;
const PLANT_FUEL = 5; // coal a plant keeps in stock
export const FUEL_VALUE = { coal: 1, fuel: 3 }; // a can of fuel burns as long as three coal
export const usesPower = (b) => !!POWER_USE[b?.type];

// Oil. A pump on an oil field needs power and pushes oil into the pipes next to
// it. Pumps, pipes, tanks and refineries that touch form one pipe network that
// holds the oil together; refineries take it out and make items from it. The
// refinery's output side, where its belt starts, takes no pipe.
export const FLUID_BUILDINGS = new Set(['pump', 'pipe', 'tank', 'refinery']);
export const FLUID_CAPACITY = { pump: 10, pipe: 10, tank: 400, refinery: 20 }; // oil each one holds
export const PUMP_RATE = 2; // oil per second at full power, before research
export const isFluid = (b) => FLUID_BUILDINGS.has(b?.type);

// The factory on top of a world: which building stands on which tile, and the
// simulation that moves items from drills over belts through machines into storage.
// `start` lists the buildings that can be built from the beginning.
export function createFactory(world, { start } = {}) {
  const buildings = new Map(); // tile index -> building
  const mined = Object.fromEntries(Object.keys(ORES).map((k) => [k, 0]));
  const stored = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, 0])); // in all storages together
  const delivered = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, 0])); // ever put into storage
  const recent = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, []])); // delivery times of the last minute
  const research = createResearch(stored, start);
  let time = 0; // simulated seconds since the start
  let pumped = 0; // oil ever pumped
  let shipped = 0; // parts ever unloaded from trains
  const shipLog = []; // unload times of the last minute

  const indexOf = (tile) => tile.z * world.size + tile.x;
  const at = (x, z) => (x < 0 || z < 0 || x >= world.size || z >= world.size ? null : buildings.get(z * world.size + x) ?? null);
  const neighbour = (b, dir) => at(b.tile.x + DIRS[dir].x, b.tile.z + DIRS[dir].z);
  // Does building `from` hand its items to building `to`?
  const feeds = (from, to) =>
    from && !NO_OUTPUT.has(from.type) && from.tile.x + DIRS[from.dir].x === to.tile.x && from.tile.z + DIRS[from.dir].z === to.tile.z;

  // `overBelt`: a building other than a belt may replace a belt standing there.
  function canPlace(type, tile, overBelt = false) {
    if (!tile) return { ok: false, reason: '' };
    if (!research.unlocked.has(type)) return { ok: false, reason: 'Noch nicht freigeschaltet' };
    if (BUILDINGS[type]?.vehicle) return { ok: false, reason: '' };
    const existing = buildings.get(indexOf(tile));
    if (existing && !(overBelt && existing.type === 'belt' && type !== 'belt')) return { ok: false, reason: 'Hier steht schon etwas' };
    if (!TERRAIN[tile.terrain].buildable) return { ok: false, reason: 'Hier kann man nicht bauen' };
    if (type === 'drill' && (!tile.ore || ORES[tile.ore].fluid)) return { ok: false, reason: tile.ore ? 'Auf Öl gehört eine Ölpumpe' : 'Bohrer nur auf Erzfeldern' };
    if (type === 'pump' && !ORES[tile.ore]?.fluid) return { ok: false, reason: 'Ölpumpe nur auf Ölfeldern' };
    return { ok: true, reason: '' };
  }

  function place(type, tile, dir, overBelt = false) {
    if (!canPlace(type, tile, overBelt).ok) return null;
    const b = { type, tile, dir, index: indexOf(tile) };
    buildings.delete(b.index); // a belt it replaces
    if (type === 'drill') Object.assign(b, { timer: 0, held: null, state: 'work', mined: 0 });
    if (type === 'belt') Object.assign(b, { items: [], shape: 'straight' });
    if (type === 'storage') Object.assign(b, { received: 0, last: 0 });
    if (isMachine(b)) Object.assign(b, { input: [], output: [], current: null, timer: 0, state: 'idle', made: 0, refused: null });
    if (type === 'constructor') Object.assign(b, { recipe: 'gear', input: {}, output: [], busy: false, timer: 0, state: 'idle', made: 0, refused: null });
    if (type === 'splitter') Object.assign(b, { items: [], next: 0, passed: 0 });
    if (type === 'merger') Object.assign(b, { slots: [[], [], [], []], next: 0, passed: 0 });
    if (type === 'power') Object.assign(b, { fuel: 0, burn: 0, state: 'idle', made: 0, refused: null });
    if (type === 'pump') Object.assign(b, { acc: 0, state: 'nopower', pumped: 0 });
    if (type === 'refinery') Object.assign(b, { recipe: 'plastic', output: [], busy: false, timer: 0, state: 'idle', made: 0 });
    if (isFluid(b)) b.oil = 0;
    if (type === 'rail') b.conn = 0;
    if (type === 'station') Object.assign(b, { conn: axisBits(dir), mode: 'load', name: stationName(), items: {}, total: 0, received: 0, sent: 0 });
    buildings.set(b.index, b);
    if (isTrack(b)) railways.join(b);
    updateShapes();
    return b;
  }

  // A train standing on the tile goes first, the track under it with the next click.
  function remove(tile) {
    const train = railways.trainOn(tile);
    if (train) {
      railways.removeTrain(train);
      return { type: 'train', tile, train };
    }
    const b = tile && buildings.get(indexOf(tile));
    if (!b) return null;
    buildings.delete(b.index);
    if (isTrack(b)) railways.markDirty();
    updateShapes();
    return b;
  }

  // Stations are named A, B, C … in the order they are built; free letters are reused.
  function stationName() {
    const used = new Set();
    for (const b of buildings.values()) if (b.type === 'station') used.add(b.name);
    for (let i = 0; ; i++) {
      const name = String.fromCharCode(65 + (i % 26)) + (i >= 26 ? Math.floor(i / 26) + 1 : '');
      if (!used.has(name)) return name;
    }
  }

  // --- Railways -------------------------------------------------------------------

  const railways = createRailways({
    world,
    buildings,
    neighbour,
    research,
    pushTo,
    onShip() {
      shipped++;
      shipLog.push(time);
    },
  });

  // Parts unloaded from trains during the last minute.
  function shippedPerMinute() {
    while (shipLog.length && shipLog[0] < time - 60) shipLog.shift();
    return shipLog.length;
  }

  function setMode(b, mode) {
    if (b.type === 'station' && (mode === 'load' || mode === 'unload')) b.mode = mode;
  }

  // --- Power grid ---------------------------------------------------------------

  const derailed = []; // trains lost because their track was torn up, for the view to report
  const grid = { nets: [], wires: [], version: 0 };
  let gridDirty = true;

  // Poles within reach form networks. The wires drawn between them are the shortest
  // links that join each network (a spanning tree), so the view stays tidy.
  function updateGrid() {
    gridDirty = false;
    grid.version++;
    const poles = [...buildings.values()].filter((b) => b.type === 'pole');
    const pairs = [];
    for (let i = 0; i < poles.length; i++) {
      for (let j = i + 1; j < poles.length; j++) {
        const d = Math.hypot(poles[i].tile.x - poles[j].tile.x, poles[i].tile.z - poles[j].tile.z);
        if (d <= WIRE_REACH) pairs.push([d, poles[i], poles[j]]);
      }
    }
    pairs.sort((a, b) => a[0] - b[0]);
    const root = new Map(poles.map((p) => [p, p]));
    const find = (p) => (root.get(p) === p ? p : find(root.get(p)));
    grid.wires = [];
    for (const [, a, b] of pairs) {
      const ra = find(a);
      const rb = find(b);
      if (ra === rb) continue;
      root.set(ra, rb);
      grid.wires.push([a, b]);
    }
    const byRoot = new Map();
    grid.nets = [];
    for (const p of poles) {
      const r = find(p);
      if (!byRoot.has(r)) {
        const net = { id: grid.nets.length + 1, poles: [], plants: [], consumers: [], capacity: 0, demand: 0, satisfaction: 0, used: 0 };
        byRoot.set(r, net);
        grid.nets.push(net);
      }
      const net = byRoot.get(r);
      net.poles.push(p);
      p.net = net;
    }
    // Every plant and machine joins the network of the first pole that covers it.
    for (const b of buildings.values()) {
      if (b.type === 'pole') continue;
      b.net = null;
      if (b.type !== 'power' && !usesPower(b)) continue;
      for (let dz = -POLE_SUPPLY; dz <= POLE_SUPPLY && !b.net; dz++) {
        for (let dx = -POLE_SUPPLY; dx <= POLE_SUPPLY; dx++) {
          const p = at(b.tile.x + dx, b.tile.z + dz);
          if (p?.type !== 'pole') continue;
          b.net = p.net;
          (b.type === 'power' ? p.net.plants : p.net.consumers).push(b);
          break;
        }
      }
    }
  }

  // Speed factor of a machine from its power: 1 off the grid, up to POWER_SPEED on it.
  const powerFactor = (b) => (b.net ? POWER_SPEED * b.net.satisfaction : 1);

  // Shares the power of each network's plants among its working machines.
  function tickPower(dt) {
    const out = POWER_OUTPUT * research.stats.power;
    for (const b of buildings.values()) {
      if (b.type !== 'power') continue;
      // Load the next coal before the current one is used up.
      if (b.burn <= 0 && b.fuel > 0) {
        b.fuel--;
        b.burn += COAL_ENERGY * research.stats.power;
      }
      if (!b.net) b.state = b.burn > 0 || b.fuel > 0 ? 'idle' : 'empty';
    }
    for (const net of grid.nets) {
      const fed = net.plants.filter((p) => p.burn > 0);
      net.capacity = fed.length * out;
      // Machines that are working or waiting for power ask for it.
      net.demand = 0;
      for (const b of net.consumers) if (b.state === 'work' || b.state === 'nopower') net.demand += POWER_USE[b.type];
      net.satisfaction = net.capacity <= 0 ? 0 : net.demand <= 0 ? 1 : Math.min(1, net.capacity / net.demand);
      net.used = Math.min(net.capacity, net.demand);
      for (const p of net.plants) {
        if (p.burn <= 0) {
          p.state = 'empty';
          continue;
        }
        const share = net.used / fed.length;
        p.burn -= share * dt;
        p.load = net.capacity ? net.used / net.capacity : 0;
        p.state = share > 0 ? 'work' : 'idle';
      }
    }
  }

  // Totals over all networks, for the HUD.
  function powerSummary() {
    const s = { nets: grid.nets.length, plants: 0, capacity: 0, demand: 0, used: 0, consumers: 0, short: 0, fuel: 0 };
    for (const net of grid.nets) {
      s.plants += net.plants.length;
      s.capacity += net.capacity;
      s.demand += net.demand;
      s.used += net.used;
      s.consumers += net.consumers.length;
      if (net.consumers.length && net.satisfaction < 1) s.short++;
      for (const p of net.plants) s.fuel += p.fuel + (p.burn > 0 ? 1 : 0);
    }
    s.satisfaction = s.demand ? s.used / s.demand : s.capacity > 0 ? 1 : 0;
    return s;
  }

  // Machines currently running on power from a network.
  function powered() {
    let n = 0;
    for (const net of grid.nets) if (net.satisfaction > 0) for (const b of net.consumers) if (b.state === 'work') n++;
    return n;
  }

  // --- Pipes and oil -------------------------------------------------------------

  const pipes = { nets: [], version: 0 };
  let pipesDirty = true;

  // Does fluid building `a` connect to its neighbour in direction `d`?
  function fluidLink(a, d) {
    const b = neighbour(a, d);
    if (!isFluid(b)) return null;
    if (a.type === 'refinery' && a.dir === d) return null;
    if (b.type === 'refinery' && b.dir === opposite(d)) return null;
    return b;
  }

  // Each member keeps its share of the network's oil, so oil survives a rebuild
  // and a save game.
  function settleOil() {
    for (const net of pipes.nets) for (const m of net.members) m.oil = net.capacity ? (net.amount * FLUID_CAPACITY[m.type]) / net.capacity : 0;
  }

  // Touching fluid buildings form networks. Every member also learns which sides
  // it connects on and how many steps it is from the nearest pump, so the view can
  // draw the oil flowing away from the pumps.
  function updatePipes() {
    settleOil();
    pipesDirty = false;
    pipes.version++;
    pipes.nets = [];
    const members = [...buildings.values()].filter(isFluid);
    for (const b of members) {
      b.pipes = null;
      b.links = [0, 1, 2, 3].filter((d) => fluidLink(b, d));
      b.depth = Infinity;
    }
    for (const first of members) {
      if (first.pipes) continue;
      const net = { id: pipes.nets.length + 1, members: [], amount: 0, capacity: 0, rate: 0, in: 0, out: 0, pumps: 0, tanks: 0 };
      pipes.nets.push(net);
      const todo = [first];
      first.pipes = net;
      while (todo.length) {
        const b = todo.pop();
        net.members.push(b);
        net.amount += b.oil ?? 0;
        net.capacity += FLUID_CAPACITY[b.type];
        if (b.type === 'pump') net.pumps++;
        if (b.type === 'tank') net.tanks++;
        for (const d of b.links) {
          const n = neighbour(b, d);
          if (n.pipes) continue;
          n.pipes = net;
          todo.push(n);
        }
      }
      net.amount = Math.min(net.amount, net.capacity);
      // Steps from the pumps, breadth first.
      let ring = net.members.filter((b) => b.type === 'pump');
      for (const b of ring) b.depth = 0;
      while (ring.length) {
        const next = [];
        for (const b of ring) {
          for (const d of b.links) {
            const n = neighbour(b, d);
            if (n.depth <= b.depth + 1) continue;
            n.depth = b.depth + 1;
            next.push(n);
          }
        }
        ring = next;
      }
    }
  }

  function tickPump(b, dt) {
    if (b.tile.amount <= 0) {
      b.state = 'empty';
      return;
    }
    // Pumps only run on power, and only as fast as the network supplies it.
    const speed = b.net ? b.net.satisfaction : 0;
    if (speed <= 0) {
      b.state = 'nopower';
      return;
    }
    const net = b.pipes;
    const room = net.capacity - net.amount;
    if (room < 0.01) {
      b.state = 'blocked';
      return;
    }
    b.state = 'work';
    const n = Math.min(PUMP_RATE * research.stats.pump * speed * dt, room);
    net.amount += n;
    net.in += n;
    b.acc += n;
    while (b.acc >= 1) {
      b.acc--;
      b.tile.amount--;
      b.pumped++;
      mined[b.tile.ore]++;
      pumped++;
    }
  }

  function tickRefinery(b, dt) {
    const recipe = REFINERY_RECIPES[b.recipe];
    const time = recipe.time / research.stats.refinery;
    if (b.output.length && pushTo(neighbour(b, b.dir), b.output[0], b.dir)) b.output.shift();
    const net = b.pipes;
    if (!b.busy && net && net.amount >= recipe.oil - 1e-6) {
      net.amount = Math.max(0, net.amount - recipe.oil);
      net.out += recipe.oil;
      b.busy = true;
      b.timer = 0;
    }
    if (!b.busy) {
      b.state = 'idle';
      return;
    }
    const speed = powerFactor(b);
    b.state = speed > 0 ? 'work' : 'nopower';
    b.timer = Math.min(b.timer + dt * speed, time);
    if (b.timer < time) return;
    if (b.output.length >= MACHINE_OUTPUT) {
      b.state = 'blocked';
      return;
    }
    b.output.push(recipe.makes);
    b.busy = false;
    b.made++;
  }

  function tickFluids(dt) {
    for (const net of pipes.nets) net.in = net.out = 0;
    for (const b of buildings.values()) if (b.type === 'pump') tickPump(b, dt);
    for (const b of buildings.values()) if (b.type === 'refinery') tickRefinery(b, dt);
    // Oil per second through each network, smoothed for the view.
    for (const net of pipes.nets) net.rate += (Math.max(net.in, net.out) / dt - net.rate) * Math.min(1, dt * 1.5);
  }

  // Totals over all pipe networks, for the HUD.
  function oilSummary() {
    const s = { nets: 0, pumps: 0, amount: 0, capacity: 0, rate: 0, refineries: 0, working: 0 };
    for (const net of pipes.nets) {
      s.nets++;
      s.pumps += net.pumps;
      s.amount += net.amount;
      s.capacity += net.capacity;
      s.rate += net.rate;
    }
    for (const b of buildings.values()) {
      if (b.type === 'refinery') s.refineries++;
      if (b.type === 'pump' && b.state === 'work') s.working++;
    }
    return s;
  }

  function setDir(b, dir) {
    if (b.dir === dir || b.type === 'rail') return;
    b.dir = dir;
    // A station turns its track with it.
    if (b.type === 'station') {
      b.conn = axisBits(dir);
      railways.join(b);
    }
    updateShapes();
  }

  function setRecipe(b, recipe) {
    if (b.recipe === recipe || !recipesOf(b.type)?.[recipe]) return;
    b.recipe = recipe;
    // Keep buffered parts the new recipe can use, drop the rest.
    if (b.type === 'constructor') {
      const needs = CONSTRUCTOR_RECIPES[recipe].needs;
      b.input = Object.fromEntries(Object.entries(b.input).filter(([k]) => needs[k]));
    }
    b.busy = false;
    b.timer = 0;
    b.refused = null;
  }

  // A belt curves when exactly one side feeds into it and nothing comes from behind.
  // 'left' means items enter over the left edge (seen in travel direction).
  function updateShapes() {
    gridDirty = true;
    pipesDirty = true;
    for (const b of buildings.values()) {
      if (b.type !== 'belt') continue;
      const back = neighbour(b, opposite(b.dir));
      const left = neighbour(b, (b.dir + 3) % 4);
      const right = neighbour(b, (b.dir + 1) % 4);
      const fromLeft = feeds(left, b);
      const fromRight = feeds(right, b);
      if (feeds(back, b) || fromLeft === fromRight) b.shape = 'straight';
      else b.shape = fromLeft ? 'left' : 'right';
    }
  }

  // Hand an item to the building it reaches while travelling in direction `dir`.
  // Belts and machines never take items through their own output side.
  function pushTo(target, kind, dir) {
    if (!target) return false;
    if (target.type === 'storage') {
      stored[kind]++;
      delivered[kind]++;
      recent[kind].push(time);
      target.received++;
      target.last = kind;
      return true;
    }
    if (target.type === 'power') {
      // Coal or fuel from any side.
      if (!FUEL_VALUE[kind]) {
        target.refused = kind;
        return false;
      }
      if (target.fuel >= PLANT_FUEL) return false;
      target.fuel += FUEL_VALUE[kind];
      target.refused = null;
      return true;
    }
    if (target.type === 'station') {
      // Loading stations take parts over their two sides, not along the track.
      if (target.mode !== 'load' || dir % 2 === target.dir % 2 || target.total >= STATION_CAP) return false;
      target.items[kind] = (target.items[kind] ?? 0) + 1;
      target.total++;
      target.received++;
      return true;
    }
    if (target.type === 'drill' || target.type === 'pole' || target.type === 'rail' || isFluid(target) || target.dir === opposite(dir)) return false;
    if (target.type === 'belt') {
      const last = target.items[target.items.length - 1];
      if (last && last.p < ITEM_SPACING) return false;
      target.items.push({ kind, p: 0, from: dir, spin: Math.random() * Math.PI * 2 });
      return true;
    }
    if (target.type === 'splitter') {
      // Only from behind; it hands out to the front and both sides.
      if (dir !== target.dir || target.items.length >= SPLITTER_BUFFER) return false;
      target.items.push(kind);
      return true;
    }
    if (target.type === 'merger') {
      const slot = target.slots[dir];
      if (slot.length >= SPLITTER_BUFFER) return false;
      slot.push(kind);
      return true;
    }
    if (target.type === 'constructor') {
      const need = CONSTRUCTOR_RECIPES[target.recipe].needs[kind];
      if (!need) {
        target.refused = kind;
        return false;
      }
      if ((target.input[kind] ?? 0) >= need * 2) return false;
      target.input[kind] = (target.input[kind] ?? 0) + 1;
      target.refused = null;
      return true;
    }
    if (isMachine(target)) {
      if (!RECIPES[target.type].makes[kind]) {
        target.refused = kind;
        return false;
      }
      if (target.input.length >= MACHINE_INPUT) return false;
      target.input.push(kind);
      target.refused = null;
      return true;
    }
    return false;
  }

  function tickBelt(b, step) {
    // Items are ordered front first; each one stops behind the one ahead of it.
    let limit = Infinity;
    const kept = [];
    for (const item of b.items) {
      let p = Math.min(item.p + step, limit);
      if (p >= 1) {
        if (limit === Infinity && pushTo(neighbour(b, b.dir), item.kind, b.dir)) continue;
        p = 1;
      }
      item.p = Math.max(item.p, p);
      kept.push(item);
      limit = item.p - ITEM_SPACING;
    }
    b.items = kept;
  }

  function tickMachine(b, dt) {
    const recipe = RECIPES[b.type];
    const time = recipe.time / research.stats[b.type];
    if (b.output.length && pushTo(neighbour(b, b.dir), b.output[0], b.dir)) b.output.shift();
    if (!b.current && b.input.length) {
      b.current = b.input.shift();
      b.timer = 0;
      b.refused = null;
    }
    if (!b.current) {
      b.state = 'idle';
      return;
    }
    const speed = powerFactor(b);
    b.state = speed > 0 ? 'work' : 'nopower';
    b.timer = Math.min(b.timer + dt * speed, time);
    if (b.timer < time) return;
    if (b.output.length >= MACHINE_OUTPUT) {
      b.state = 'blocked';
      return;
    }
    b.output.push(recipe.makes[b.current]);
    b.current = null;
    b.made++;
  }

  function tickConstructor(b, dt) {
    const recipe = CONSTRUCTOR_RECIPES[b.recipe];
    const time = recipe.time / research.stats.constructor;
    if (b.output.length && pushTo(neighbour(b, b.dir), b.output[0], b.dir)) b.output.shift();
    if (!b.busy && Object.entries(recipe.needs).every(([k, n]) => (b.input[k] ?? 0) >= n)) {
      for (const [k, n] of Object.entries(recipe.needs)) b.input[k] -= n;
      b.busy = true;
      b.timer = 0;
    }
    if (!b.busy) {
      b.state = 'idle';
      return;
    }
    const speed = powerFactor(b);
    b.state = speed > 0 ? 'work' : 'nopower';
    b.timer = Math.min(b.timer + dt * speed, time);
    if (b.timer < time) return;
    if (b.output.length >= MACHINE_OUTPUT) {
      b.state = 'blocked';
      return;
    }
    b.output.push(recipe.makes);
    b.busy = false;
    b.made++;
  }

  // Front, left, right in turn; a blocked exit is skipped.
  function tickSplitter(b) {
    if (!b.items.length) return;
    const exits = [b.dir, (b.dir + 3) % 4, (b.dir + 1) % 4];
    for (let k = 0; k < 3; k++) {
      const i = (b.next + k) % 3;
      if (pushTo(neighbour(b, exits[i]), b.items[0], exits[i])) {
        b.items.shift();
        b.next = (i + 1) % 3;
        b.passed++;
        return;
      }
    }
  }

  // Takes turns between the incoming sides so every lane gets through.
  function tickMerger(b) {
    for (let k = 0; k < 4; k++) {
      const i = (b.next + k) % 4;
      const slot = b.slots[i];
      if (!slot.length) continue;
      if (pushTo(neighbour(b, b.dir), slot[0], b.dir)) {
        slot.shift();
        b.next = (i + 1) % 4;
        b.passed++;
      }
      return;
    }
  }

  function tickDrill(b, dt) {
    if (b.held && pushTo(neighbour(b, b.dir), b.held, b.dir)) b.held = null;
    if (b.held) {
      b.state = 'blocked';
      return;
    }
    if (b.tile.amount <= 0) {
      b.state = 'empty';
      return;
    }
    const speed = powerFactor(b);
    b.state = speed > 0 ? 'work' : 'nopower';
    b.timer += dt * research.stats.drill * speed;
    if (b.timer >= DRILL_TIME) {
      b.timer -= DRILL_TIME;
      b.tile.amount--;
      b.held = b.tile.ore;
      b.mined++;
      mined[b.tile.ore]++;
    }
  }

  const beltSpeed = () => BELT_SPEED * research.stats.belt;

  // Items of one kind put into storage during the last minute.
  function perMinute(kind) {
    const log = recent[kind];
    while (log.length && log[0] < time - 60) log.shift();
    return log.length;
  }

  const count = (type) => {
    if (type === 'train') return railways.trains.length;
    let n = 0;
    for (const b of buildings.values()) if (b.type === type) n++;
    return n;
  };

  function tick(dt) {
    if (gridDirty) updateGrid();
    if (pipesDirty) updatePipes();
    if (railways.dirty) derailed.push(...railways.update());
    time += dt;
    tickPower(dt);
    tickFluids(dt);
    railways.tick(dt);
    const step = beltSpeed() * dt;
    for (const b of buildings.values()) if (b.type === 'belt' && b.items.length) tickBelt(b, step);
    for (const b of buildings.values()) {
      if (isMachine(b)) tickMachine(b, dt);
      else if (b.type === 'constructor') tickConstructor(b, dt);
      else if (b.type === 'splitter') tickSplitter(b);
      else if (b.type === 'merger') tickMerger(b);
    }
    for (const b of buildings.values()) if (b.type === 'drill') tickDrill(b, dt);
  }

  // Plain data for a save game. The world itself is rebuilt from its seed,
  // only the ore left in each field is stored.
  function save() {
    settleOil();
    return {
      time,
      pumped,
      shipped,
      shipLog: [...shipLog],
      trains: railways.save(),
      mined,
      stored,
      delivered,
      recent: Object.fromEntries(Object.entries(recent).filter(([, log]) => log.length)),
      research: research.save(),
      amounts: world.tiles.filter((t) => t.ore).map((t) => t.amount),
      buildings: [...buildings.values()].map(({ tile, index, net, load, pipes, links, depth, ...rest }) => ({ ...rest, index })),
    };
  }

  // `version` is the save format (see save.js); before 3 there was no oil on the map.
  function load(data, version = Infinity) {
    time = data.time ?? 0;
    pumped = data.pumped ?? 0;
    shipped = data.shipped ?? 0;
    shipLog.length = 0;
    shipLog.push(...(data.shipLog ?? []));
    for (const [target, from] of [[mined, data.mined], [stored, data.stored], [delivered, data.delivered]]) {
      for (const k of Object.keys(target)) target[k] = from?.[k] ?? 0;
    }
    for (const k of Object.keys(recent)) recent[k] = data.recent?.[k] ?? [];
    research.load(data.research);
    let n = 0;
    for (const t of world.tiles) if (t.ore && (version >= 3 || !ORES[t.ore].fluid)) t.amount = data.amounts?.[n++] ?? t.amount;
    buildings.clear();
    pipes.nets = [];
    for (const b of data.buildings ?? []) {
      const tile = world.tiles[b.index];
      if (tile && BUILDINGS[b.type] && !BUILDINGS[b.type].vehicle) buildings.set(b.index, { ...b, tile });
    }
    railways.load(data.trains);
    updateShapes();
  }

  return {
    buildings,
    mined,
    stored,
    delivered,
    research,
    grid,
    perMinute,
    count,
    powerFactor,
    powerSummary,
    powered,
    pipes,
    oilSummary,
    updateGrid: () => gridDirty && updateGrid(),
    updatePipes: () => pipesDirty && updatePipes(),
    get pumped() {
      return pumped;
    },
    get shipped() {
      return shipped;
    },
    world,
    trains: railways.trains,
    derailed,
    railways,
    shippedPerMinute,
    setMode,
    addTrain: (tile) => railways.addTrain(tile),
    canAddTrain: (tile) => (research.unlocked.has('train') ? railways.startPath(tile) : { ok: false, reason: 'Noch nicht freigeschaltet' }),
    trainOn: (tile) => railways.trainOn(tile),
    linkTrack: (a, b) => railways.link(a, b) && (updateShapes(), true),
    updateTracks: () => derailed.push(...railways.update()),
    get time() {
      return time;
    },
    beltSpeed,
    at,
    canPlace,
    place,
    remove,
    setDir,
    setRecipe,
    tick,
    save,
    load,
    get: (tile) => buildings.get(indexOf(tile)) ?? null,
  };
}
