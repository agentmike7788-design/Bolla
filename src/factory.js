import { ORES, TERRAIN } from './world.js';

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
  ...Object.fromEntries(Object.entries(ORES).map(([k, o]) => [k, { name: o.name, color: o.color, shape: 'ore' }])),
  ironIngot: { name: 'Eisenbarren', color: 0xc4ccd4, shape: 'ingot' },
  copperIngot: { name: 'Kupferbarren', color: 0xe9894a, shape: 'ingot' },
  ironPlate: { name: 'Eisenplatte', color: 0x9fb0bf, shape: 'plate' },
  wire: { name: 'Kupferdraht', color: 0xd8742f, shape: 'wire' },
  concrete: { name: 'Beton', color: 0xd9d4c7, shape: 'block' },
  gear: { name: 'Zahnrad', color: 0xb8bec4, shape: 'gear' },
  circuit: { name: 'Schaltkreis', color: 0x3fae5a, shape: 'chip' },
  steel: { name: 'Stahlträger', color: 0x5d6b7a, shape: 'beam' },
};

// Furnace and press turn one input item into one output item.
export const RECIPES = {
  furnace: { time: 2, makes: { iron: 'ironIngot', copper: 'copperIngot' } },
  assembler: { time: 1.6, makes: { ironIngot: 'ironPlate', copperIngot: 'wire', stone: 'concrete' } },
};

// The constructor combines several items into one; the player picks the recipe.
export const CONSTRUCTOR_RECIPES = {
  gear: { time: 2, needs: { ironPlate: 2 }, makes: 'gear' },
  circuit: { time: 3, needs: { ironPlate: 1, wire: 2 }, makes: 'circuit' },
  steel: { time: 2.5, needs: { ironIngot: 2, coal: 1 }, makes: 'steel' },
};

export const BUILDINGS = {
  drill: { name: 'Bohrer' },
  belt: { name: 'Förderband' },
  storage: { name: 'Lager' },
  furnace: { name: 'Schmelzofen' },
  assembler: { name: 'Presse' },
  splitter: { name: 'Verteiler' },
  merger: { name: 'Zusammenführer' },
  constructor: { name: 'Konstruktor' },
};

// Belt tiers: the belt tool always lays the best researched tier, and dragging over
// an older belt upgrades it.
export const BELT_TIERS = [
  { name: 'Förderband', speed: 1.5, color: 0xf0a830 },
  { name: 'Schnellband', speed: 2.6, color: 0xe2483a },
  { name: 'Expressband', speed: 4, color: 0x3b8fe6 },
];

// The research tree. Research is paid with items from the storages. col/row place
// the node in the research menu; needs are the nodes that must be done first.
// unlocks adds buildings, belt raises the belt tier, speed multiplies machine speed.
export const RESEARCH = [
  { id: 'smelting', name: 'Schmelzen', col: 0, row: 1, needs: [], cost: { iron: 20, copper: 20 }, unlocks: ['furnace'], text: 'Schmelzofen: Erz wird zu Barren.' },
  { id: 'pressing', name: 'Pressen', col: 1, row: 0, needs: ['smelting'], cost: { ironIngot: 30, copperIngot: 20 }, unlocks: ['assembler'], text: 'Presse: Platten, Draht und Beton.' },
  { id: 'logistics', name: 'Logistik', col: 1, row: 2, needs: ['smelting'], cost: { ironIngot: 20, stone: 20 }, unlocks: ['splitter', 'merger'], text: 'Verteiler und Zusammenführer für Bänder.' },
  { id: 'drill2', name: 'Schnellbohrer', col: 2, row: 0, needs: ['pressing'], cost: { ironPlate: 20, concrete: 10 }, speed: { drill: 1.6 }, text: 'Alle Bohrer fördern 60 % schneller.' },
  { id: 'kiln', name: 'Hochofen', col: 2, row: 1, needs: ['pressing'], cost: { ironPlate: 15, concrete: 25 }, speed: { furnace: 1.5 }, text: 'Alle Schmelzöfen arbeiten 50 % schneller.' },
  { id: 'belt2', name: 'Schnellband', col: 2, row: 2, needs: ['pressing', 'logistics'], cost: { ironPlate: 30, wire: 20 }, belt: 1, text: 'Rote Bänder, fast doppelt so schnell.' },
  { id: 'constructor', name: 'Konstruktor', col: 2, row: 3, needs: ['pressing'], cost: { ironPlate: 40, wire: 30, concrete: 20 }, unlocks: ['constructor'], text: 'Baut Zahnräder, Schaltkreise und Stahl aus mehreren Teilen.' },
  { id: 'drill3', name: 'Tiefbohrer', col: 3, row: 0, needs: ['drill2', 'constructor'], cost: { steel: 20, circuit: 15 }, speed: { drill: 1.7 }, text: 'Bohrer fördern noch einmal 70 % schneller.' },
  { id: 'hydraulics', name: 'Hydraulik', col: 3, row: 1, needs: ['constructor'], cost: { gear: 25, circuit: 10 }, speed: { assembler: 1.5, constructor: 1.5 }, text: 'Presse und Konstruktor arbeiten 50 % schneller.' },
  { id: 'belt3', name: 'Expressband', col: 3, row: 2, needs: ['belt2', 'constructor'], cost: { gear: 30, steel: 15 }, belt: 2, text: 'Blaue Bänder, die schnellsten der Fabrik.' },
  { id: 'master', name: 'Meisterfabrik', col: 4, row: 1, needs: ['drill3', 'hydraulics', 'belt3'], cost: { circuit: 50, steel: 40, gear: 40 }, final: true, text: 'Das große Ziel: eine Fabrik, die alles kann.' },
];
export const RESEARCH_BY_ID = Object.fromEntries(RESEARCH.map((r) => [r.id, r]));
const START_UNLOCKED = ['drill', 'belt', 'storage'];

export const ITEM_SPACING = 0.34; // minimum gap between two items on a belt, in tiles
export const DRILL_TIME = 1.4; // seconds per mined ore
const MACHINE_INPUT = 4; // items a machine buffers on each side
const MACHINE_OUTPUT = 4;
const SPLITTER_BUFFER = 2;

const opposite = (dir) => (dir + 2) % 4;
export const isMachine = (b) => b?.type === 'furnace' || b?.type === 'assembler';

// The factory on top of a world: which building stands on which tile, and the
// simulation that moves items from drills over belts through machines into storage.
export function createFactory(world) {
  const buildings = new Map(); // tile index -> building
  const mined = Object.fromEntries(Object.keys(ORES).map((k) => [k, 0]));
  const stored = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, 0])); // in all storages, spent on research
  const progress = {
    researched: new Set(),
    unlocked: new Set(START_UNLOCKED),
    beltTier: 0,
    speed: { drill: 1, furnace: 1, assembler: 1, constructor: 1 },
    done: false,
  };

  const indexOf = (tile) => tile.z * world.size + tile.x;
  const at = (x, z) => (x < 0 || z < 0 || x >= world.size || z >= world.size ? null : buildings.get(z * world.size + x) ?? null);
  const neighbour = (b, dir) => at(b.tile.x + DIRS[dir].x, b.tile.z + DIRS[dir].z);
  // Does building `from` hand its items to building `to`?
  const feeds = (from, to) =>
    from && from.type !== 'storage' && from.tile.x + DIRS[from.dir].x === to.tile.x && from.tile.z + DIRS[from.dir].z === to.tile.z;

  function canPlace(type, tile) {
    if (!tile) return { ok: false, reason: '' };
    if (!progress.unlocked.has(type)) return { ok: false, reason: 'Noch nicht erforscht' };
    if (buildings.has(indexOf(tile))) return { ok: false, reason: 'Hier steht schon etwas' };
    if (!TERRAIN[tile.terrain].buildable) return { ok: false, reason: 'Hier kann man nicht bauen' };
    if (type === 'drill' && !tile.ore) return { ok: false, reason: 'Bohrer nur auf Erzfeldern' };
    return { ok: true, reason: '' };
  }

  function place(type, tile, dir) {
    if (!canPlace(type, tile).ok) return null;
    const b = { type, tile, dir, index: indexOf(tile) };
    if (type === 'drill') Object.assign(b, { timer: 0, held: null, state: 'work', mined: 0 });
    if (type === 'belt') Object.assign(b, { items: [], shape: 'straight', tier: progress.beltTier });
    if (type === 'storage') Object.assign(b, { received: 0, last: 0 });
    if (isMachine(b)) Object.assign(b, { input: [], output: [], current: null, timer: 0, state: 'idle', made: 0, refused: null });
    if (type === 'constructor') Object.assign(b, { recipe: 'gear', input: {}, output: [], busy: false, timer: 0, state: 'idle', made: 0, refused: null });
    if (type === 'splitter') Object.assign(b, { items: [], next: 0, passed: 0 });
    if (type === 'merger') Object.assign(b, { slots: [[], [], [], []], next: 0, passed: 0 });
    buildings.set(b.index, b);
    updateShapes();
    return b;
  }

  function remove(tile) {
    const b = tile && buildings.get(indexOf(tile));
    if (!b) return null;
    buildings.delete(b.index);
    updateShapes();
    return b;
  }

  function setDir(b, dir) {
    if (b.dir === dir) return;
    b.dir = dir;
    updateShapes();
  }

  // Lay the best researched belt tier over an older belt. Items stay on it.
  function upgradeBelt(b) {
    if (b.type !== 'belt' || b.tier >= progress.beltTier) return false;
    b.tier = progress.beltTier;
    return true;
  }

  function setRecipe(b, recipe) {
    if (b.type !== 'constructor' || b.recipe === recipe || !CONSTRUCTOR_RECIPES[recipe]) return;
    b.recipe = recipe;
    // Keep buffered parts the new recipe can use, drop the rest.
    const needs = CONSTRUCTOR_RECIPES[recipe].needs;
    b.input = Object.fromEntries(Object.entries(b.input).filter(([k]) => needs[k]));
    b.busy = false;
    b.timer = 0;
    b.refused = null;
  }

  // A belt curves when exactly one side feeds into it and nothing comes from behind.
  // 'left' means items enter over the left edge (seen in travel direction).
  function updateShapes() {
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
      target.received++;
      target.last = kind;
      return true;
    }
    if (target.type === 'drill' || target.dir === opposite(dir)) return false;
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
    return false;
  }

  // Research ----------------------------------------------------------------

  const researchState = (r) => {
    if (progress.researched.has(r.id)) return 'done';
    return r.needs.every((id) => progress.researched.has(id)) ? 'open' : 'locked';
  };
  const affordable = (r) => Object.entries(r.cost).every(([k, n]) => stored[k] >= n);

  function research(id) {
    const r = RESEARCH_BY_ID[id];
    if (!r || researchState(r) !== 'open' || !affordable(r)) return false;
    for (const [k, n] of Object.entries(r.cost)) stored[k] -= n;
    progress.researched.add(id);
    for (const type of r.unlocks ?? []) progress.unlocked.add(type);
    if (r.belt) progress.beltTier = Math.max(progress.beltTier, r.belt);
    for (const [k, f] of Object.entries(r.speed ?? {})) progress.speed[k] *= f;
    if (r.final) progress.done = true;
    return true;
  }

  // Simulation ----------------------------------------------------------------

  function tickBelt(b, dt) {
    const step = BELT_TIERS[b.tier].speed * dt;
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
    const time = recipe.time / progress.speed[b.type];
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
    b.state = 'work';
    b.timer = Math.min(b.timer + dt, time);
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
    const time = recipe.time / progress.speed.constructor;
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
    b.state = 'work';
    b.timer = Math.min(b.timer + dt, time);
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
    b.state = 'work';
    b.timer += dt;
    const time = DRILL_TIME / progress.speed.drill;
    if (b.timer >= time) {
      b.timer -= time;
      b.tile.amount--;
      b.held = b.tile.ore;
      b.mined++;
      mined[b.tile.ore]++;
    }
  }

  function tick(dt) {
    for (const b of buildings.values()) if (b.type === 'belt' && b.items.length) tickBelt(b, dt);
    for (const b of buildings.values()) {
      if (isMachine(b)) tickMachine(b, dt);
      else if (b.type === 'constructor') tickConstructor(b, dt);
      else if (b.type === 'splitter') tickSplitter(b);
      else if (b.type === 'merger') tickMerger(b);
    }
    for (const b of buildings.values()) if (b.type === 'drill') tickDrill(b, dt);
  }

  return {
    buildings,
    mined,
    stored,
    progress,
    at,
    canPlace,
    place,
    remove,
    setDir,
    upgradeBelt,
    setRecipe,
    research,
    researchState,
    affordable,
    tick,
    get: (tile) => buildings.get(indexOf(tile)) ?? null,
  };
}
