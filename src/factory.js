import { ORES, TERRAIN } from './world.js';
import { createResearch, researchById } from './research.js';
import { createHistory } from './stats.js';
import { createRailways, isTrack, axisBits, STATION_CAP } from './trains.js';
import { createDrones, isChest } from './drones.js';
import { biomeOf, weatherAt, weatherEffect } from './biomes.js';
import { createEnemies, isTurret } from './enemies.js';
import { createVehicles, isVehicleType } from './vehicles.js';

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
  ammo: { name: 'Munition', color: 0xd9a441, shape: 'ammo' },
  shell: { name: 'Granate', color: 0x6b7a3a, shape: 'shell' },
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
  // Shown once turrets are unlocked: a box of cartridges, ten shots.
  ammo: { time: 1.5, needs: { ironPlate: 1, copperIngot: 1 }, makes: 'ammo', unlock: 'turret' },
  // Shown once artillery is unlocked: a steel case packed with cartridge powder.
  shell: { time: 4, needs: { steel: 1, ammo: 2 }, makes: 'shell', unlock: 'artillery' },
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
  geo: { name: 'Erdwärmekraftwerk' },
  pole: { name: 'Strommast' },
  pump: { name: 'Ölpumpe' },
  pipe: { name: 'Rohr' },
  tank: { name: 'Öltank' },
  refinery: { name: 'Raffinerie' },
  rail: { name: 'Gleis' },
  station: { name: 'Bahnhof' },
  signal: { name: 'Signal' },
  train: { name: 'Zug', vehicle: true }, // not a building: a train on the track, see trains.js
  car: { name: 'Geländewagen', vehicle: true }, // not buildings either: they drive freely, see vehicles.js
  panzer: { name: 'Panzer', vehicle: true },
  silo: { name: 'Raketensilo', size: 3 },
  dronePort: { name: 'Drohnenhafen' },
  provider: { name: 'Angebotskiste' },
  requester: { name: 'Anfragekiste' },
  wall: { name: 'Mauer' },
  turret: { name: 'Geschützturm' },
  laser: { name: 'Laserturm' },
  artillery: { name: 'Artillerie', size: 3 },
  solar: { name: 'Solarpanel' },
  wind: { name: 'Windrad' },
  battery: { name: 'Akku' },
};

// Tiles a building covers along each side; big ones stand on the middle tile.
export const sizeOf = (type) => BUILDINGS[type]?.size ?? 1;

// The rocket silo is the end goal: a launch site built in stages from parts fed in
// by belts on any side. Each stage starts once all its parts are in and then takes
// `time` seconds (faster on power, like a machine). With every stage done the
// rocket is ready and the player starts it; after a launch the pad stays and the
// next rocket needs the other stages again.
export const SILO_STAGES = [
  { id: 'pad', name: 'Startrampe', desc: 'Beton und Stahl für Rampe und Startturm', needs: { concrete: 120, steel: 60 }, time: 20 },
  { id: 'hull', name: 'Raketenrumpf', desc: 'Stahl, Kunststoff und Zahnräder für Rumpf und Triebwerke', needs: { steel: 100, plastic: 60, gear: 40 }, time: 25 },
  { id: 'avionics', name: 'Bordcomputer', desc: 'Prozessoren und Schaltkreise für Steuerung und Nutzlast', needs: { processor: 30, circuit: 60 }, time: 20 },
  { id: 'fuel', name: 'Betankung', desc: 'Treibstoff für den Flug ins All', needs: { fuel: 80 }, time: 15 },
];
export const siloReady = (b) => b?.type === 'silo' && b.stage >= SILO_STAGES.length;

export const BELT_SPEED = 1.5; // tiles per second, before research
export const ITEM_SPACING = 0.34; // minimum gap between two items on a belt, in tiles
export const DRILL_TIME = 1.4; // seconds per mined ore
const MACHINE_INPUT = 4; // items a machine buffers on each side
const MACHINE_OUTPUT = 4;
const SPLITTER_BUFFER = 2;

const opposite = (dir) => (dir + 2) % 4;
export const isMachine = (b) => b?.type === 'furnace' || b?.type === 'assembler';
// Buildings that never hand items on.
const NO_OUTPUT = new Set(['storage', 'power', 'geo', 'pole', 'pump', 'pipe', 'tank', 'rail', 'station', 'signal', 'silo', 'dronePort', 'provider', 'wall', 'turret', 'laser', 'artillery', 'solar', 'wind', 'battery']);

// Power. A coal power plant burns coal from belts and feeds every network it is
// connected to. Poles carry the power: wires reach from pole to pole, and a pole
// supplies every building within its square. Machines run without power at their
// basic speed; on a network they run POWER_SPEED times as fast, but only while the
// network has enough power, and they stop when it has none.
export const POWER_OUTPUT = 8; // MW per power plant, before research
export const POWER_USE = { drill: 1, furnace: 2, assembler: 1.5, constructor: 3, pump: 1.5, refinery: 3, silo: 4, dronePort: 2, laser: 3 }; // MW while working
export const POWER_SPEED = 2;
export const COAL_SECONDS = 4; // one coal keeps a plant at full output that long
export const WIRE_REACH = 7; // tiles between two poles
export const POLE_SUPPLY = 2; // a pole supplies the tiles up to this far away (5×5)
const COAL_ENERGY = POWER_OUTPUT * COAL_SECONDS;
const PLANT_FUEL = 5; // coal a plant keeps in stock
export const FUEL_VALUE = { coal: 1, fuel: 3 }; // a can of fuel burns as long as three coal
export const usesPower = (b) => !!POWER_USE[b?.type];
// A geothermal plant stands on a steaming vent and needs no fuel at all.
export const GEO_OUTPUT = 12; // MW per geothermal plant, before research

// Renewable power. Solar panels follow the sun of the day-night cycle, wind
// turbines the wind, which rises and falls over time and blows harder in storms;
// turbines close together take each other's wind. Neither needs fuel nor makes
// smog. Batteries on a network store what the sun and wind give beyond the
// demand and hand it back when they fall short (at night, in a lull).
// A network takes renewable power first, then batteries, and burns coal last.
export const SOLAR_OUTPUT = 3; // MW per panel in full sun, before research
export const WIND_OUTPUT = 5; // MW per turbine in full wind, before research
export const WIND_WAKE = 2; // turbines this close (in tiles) take each other's wind…
export const WAKE_LOSS = 0.2; // …this share for each neighbour
export const BATTERY_CAPACITY = 600; // MJ (MW for a second) per battery, before research
export const BATTERY_RATE = 6; // MW a battery takes or gives at most
const PLANTS = new Set(['power', 'geo', 'solar', 'wind']);
export const isPlant = (b) => PLANTS.has(b?.type);
export const isRenewable = (b) => b?.type === 'solar' || b?.type === 'wind';

// Sunlight at time of day `t` (0…1, as in daynight.js): the sun is up for about
// two thirds of the day; 0 at night, 1 around noon.
export function sunlightAt(t) {
  const e = Math.sin(t * Math.PI * 2) + 0.3;
  const x = Math.min(1, Math.max(0, e / 0.9));
  return x * x * (3 - 2 * x);
}

// Wind strength 0.1…1 at simulated time `time`: slow gusts and lulls, the same for
// a given seed, so a save game needs nothing extra.
export function windAt(time, seed = 0) {
  const s = (seed % 1000) * 0.37;
  const w = 0.55 + 0.25 * Math.sin(time / 41 + s) + 0.14 * Math.sin(time / 13.3 + s * 2.1) + 0.06 * Math.sin(time / 4.7 + s * 3.3);
  return Math.min(1, Math.max(0.1, w));
}
// Direction the wind blows from, in radians: it turns slowly over the day.
export const windDirAt = (time, seed = 0) => Math.sin(time / 180 + seed) * 1.2 + (seed % 7);

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
export function createFactory(world, { start, enemies: enemyMode = 'off', grace = null } = {}) {
  const buildings = new Map(); // tile index -> building
  const mined = Object.fromEntries(Object.keys(ORES).map((k) => [k, 0]));
  const stored = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, 0])); // in all storages together
  const delivered = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, 0])); // ever put into storage
  const recent = Object.fromEntries(Object.keys(ITEMS).map((k) => [k, []])); // delivery times of the last minute
  const research = createResearch(stored, start);
  const history = createHistory(); // production and use per resource, see stats.js
  // Research takes its cost out of the storage: that counts as used up.
  const completeResearch = research.complete;
  research.complete = (id) => {
    if (!completeResearch(id)) return false;
    for (const [k, n] of Object.entries(researchById(id).cost)) history.consume(k, n);
    return true;
  };
  let time = 0; // simulated seconds since the start
  let pumped = 0; // oil ever pumped
  let shipped = 0; // parts ever unloaded from trains
  const shipLog = []; // unload times of the last minute
  let flown = 0; // parts ever delivered by drones
  const flyLog = []; // drone delivery times of the last minute
  let weather = weatherAt(world.biome, 0); // storms of the biome, see biomes.js
  let launched = 0; // rockets started
  const launches = []; // silos that just started a rocket, for the view to show
  const footprint = new Map(); // tile index -> big building covering it beside its own tile

  const indexOf = (tile) => tile.z * world.size + tile.x;
  const at = (x, z) => {
    if (x < 0 || z < 0 || x >= world.size || z >= world.size) return null;
    const i = z * world.size + x;
    return buildings.get(i) ?? footprint.get(i) ?? null;
  };
  // Tiles a building of `type` covers when it stands on `tile`; null where the map ends.
  function tilesOf(type, tile) {
    const r = (sizeOf(type) - 1) / 2;
    const list = [];
    for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) list.push(tileAt(tile.x + dx, tile.z + dz));
    return list;
  }
  const tileAt = (x, z) => (x < 0 || z < 0 || x >= world.size || z >= world.size ? null : world.tiles[z * world.size + x]);
  const cover = (b) => {
    if (sizeOf(b.type) > 1) for (const t of tilesOf(b.type, b.tile)) if (indexOf(t) !== b.index) footprint.set(indexOf(t), b);
  };
  const neighbour = (b, dir) => at(b.tile.x + DIRS[dir].x, b.tile.z + DIRS[dir].z);
  // Does building `from` hand its items to building `to`?
  const feeds = (from, to) =>
    from && !NO_OUTPUT.has(from.type) && from.tile.x + DIRS[from.dir].x === to.tile.x && from.tile.z + DIRS[from.dir].z === to.tile.z;

  // `overBelt`: a building other than a belt may replace a belt standing there.
  function canPlace(type, tile, overBelt = false) {
    if (!tile) return { ok: false, reason: '' };
    if (!research.unlocked.has(type)) return { ok: false, reason: 'Noch nicht freigeschaltet' };
    if (BUILDINGS[type]?.vehicle) return { ok: false, reason: '' };
    if (sizeOf(type) > 1) {
      const n = sizeOf(type);
      for (const t of tilesOf(type, tile)) {
        if (!t || !TERRAIN[t.terrain].buildable) return { ok: false, reason: `Braucht ${n} × ${n} freie Felder an Land` };
        if (at(t.x, t.z)) return { ok: false, reason: `Braucht ${n} × ${n} freie Felder: hier steht schon etwas` };
        if (enemies.blocks(t)) return { ok: false, reason: 'Zu nah an einem Nest' };
      }
      return { ok: true, reason: '' };
    }
    const existing = at(tile.x, tile.z);
    // A signal goes onto a straight piece of rail, or anywhere a station could.
    if (type === 'signal' && existing?.type === 'rail') return railAxis(existing) === null ? { ok: false, reason: 'Signale nur auf gerade Gleise' } : { ok: true, reason: '' };
    if (existing && !(overBelt && existing.type === 'belt' && type !== 'belt')) return { ok: false, reason: 'Hier steht schon etwas' };
    if (!TERRAIN[tile.terrain].buildable) return { ok: false, reason: 'Hier kann man nicht bauen' };
    if (type === 'drill' && (!tile.ore || ORES[tile.ore].fluid)) return { ok: false, reason: tile.ore ? 'Auf Öl gehört eine Ölpumpe' : 'Bohrer nur auf Erzfeldern' };
    if (type === 'pump' && !ORES[tile.ore]?.fluid) return { ok: false, reason: 'Ölpumpe nur auf Ölfeldern' };
    if (type === 'geo' && !tile.vent) return { ok: false, reason: 'Erdwärmekraftwerk nur auf dampfende Quellen' };
    if (enemies.blocks(tile)) return { ok: false, reason: 'Zu nah an einem Nest' };
    return { ok: true, reason: '' };
  }

  // Direction of a straight rail (0 or 1), or null for curves and junctions.
  function railAxis(b) {
    const conn = (b.links?.length ? b.links.reduce((c, d) => c | (1 << d), 0) : b.conn) || axisBits(b.dir);
    if ((conn & ~axisBits(0)) === 0) return 0;
    if ((conn & ~axisBits(1)) === 0) return 1;
    return null;
  }

  function place(type, tile, dir, overBelt = false) {
    if (!canPlace(type, tile, overBelt).ok) return null;
    const under = at(tile.x, tile.z);
    // On a rail the signal follows the track, facing the way the player chose if it fits.
    if (type === 'signal' && under?.type === 'rail' && dir % 2 !== railAxis(under)) dir = railAxis(under);
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
    if (type === 'geo') Object.assign(b, { state: 'idle', made: 0 });
    if (type === 'pump') Object.assign(b, { acc: 0, state: 'nopower', pumped: 0 });
    if (type === 'refinery') Object.assign(b, { recipe: 'plastic', output: [], busy: false, timer: 0, state: 'idle', made: 0 });
    if (isFluid(b)) b.oil = 0;
    if (type === 'rail') b.conn = 0;
    if (type === 'station') Object.assign(b, { conn: axisBits(dir), mode: 'load', name: stationName(), items: {}, total: 0, received: 0, sent: 0 });
    if (type === 'signal') Object.assign(b, { conn: axisBits(dir), chain: false, oneway: false });
    if (type === 'silo') Object.assign(b, { stage: 0, have: {}, busy: false, timer: 0, state: 'idle', made: 0, launched: 0, refused: null });
    if (type === 'dronePort') Object.assign(b, { state: 'nopower', out: 0 });
    if (type === 'provider') Object.assign(b, { items: {}, total: 0, filled: 0, sent: 0 });
    if (type === 'requester') Object.assign(b, { items: {}, total: 0, request: null, want: 25, received: 0, handed: 0 });
    if (type === 'turret') Object.assign(b, { ammo: 0, shots: 0, aim: 0, state: 'empty', fired: 0 });
    if (type === 'laser') Object.assign(b, { aim: 0, state: 'idle', fired: 0 });
    if (type === 'artillery') Object.assign(b, { shells: 0, aim: 0, state: 'empty', fired: 0 });
    if (type === 'solar' || type === 'wind') Object.assign(b, { state: 'idle', made: 0 });
    if (type === 'battery') Object.assign(b, { charge: 0, state: 'idle' });
    buildings.set(b.index, b);
    cover(b);
    if (isTrack(b)) railways.join(b);
    updateShapes();
    return b;
  }

  // A vehicle or a train standing on the tile goes first, the track under it with the next click.
  function remove(tile) {
    const vehicle = tile && vehicles.near(tile.x, tile.z, 0.3);
    if (vehicle) {
      vehicles.remove(vehicle);
      return { type: vehicle.kind, tile, vehicle };
    }
    const train = railways.trainOn(tile);
    if (train) {
      railways.removeTrain(train);
      return { type: 'train', tile, train };
    }
    const b = tile && at(tile.x, tile.z);
    if (!b) return null;
    return demolish(b);
  }

  function demolish(b) {
    const tile = b.tile;
    buildings.delete(b.index);
    // A signal leaves the rail it stood on.
    if (b.type === 'signal') {
      buildings.set(b.index, { type: 'rail', tile, dir: b.dir, index: b.index, conn: b.conn });
      railways.markDirty();
      updateShapes();
      return b;
    }
    for (const [i, big] of footprint) if (big === b) footprint.delete(i);
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

  // --- Logistics drones ------------------------------------------------------------

  const drones = createDrones({
    buildings,
    research,
    neighbour,
    pushTo,
    onFly(kind, n) {
      flown += n;
      for (let i = 0; i < n; i++) flyLog.push(time);
    },
  });

  // --- Enemies and defence ----------------------------------------------------------

  const enemies = createEnemies({
    world,
    buildings,
    research,
    at,
    demolish,
    sizeOf,
    now: () => time,
    mode: enemyMode,
    grace,
    vehicles: () => vehicles.list,
    hurtVehicle: (v, damage) => vehicles.hurt(v, damage),
  });
  enemies.start();

  // --- Vehicles -----------------------------------------------------------------------

  const vehicles = createVehicles({
    world,
    buildings,
    at,
    research,
    stored,
    enemies,
    // Ammunition a vehicle loads leaves the storage: that counts as used up.
    consume(kind, n) {
      stored[kind] -= n;
      history.consume(kind, n);
    },
  });

  // Parts drones delivered during the last minute.
  function flownPerMinute() {
    while (flyLog.length && flyLog[0] < time - 60) flyLog.shift();
    return flyLog.length;
  }

  // Parts unloaded from trains during the last minute.
  function shippedPerMinute() {
    while (shipLog.length && shipLog[0] < time - 60) shipLog.shift();
    return shipLog.length;
  }

  function setMode(b, mode) {
    if (b.type === 'station' && (mode === 'load' || mode === 'unload')) b.mode = mode;
    if (b.type === 'signal' && (mode === 'block' || mode === 'chain')) b.chain = mode === 'chain';
    if (b.type === 'signal' && (mode === 'both' || mode === 'oneway')) {
      b.oneway = mode === 'oneway';
      railways.markDirty();
    }
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
        const net = { id: grid.nets.length + 1, poles: [], plants: [], consumers: [], batteries: [], capacity: 0, demand: 0, satisfaction: 0, used: 0, clean: 0, coal: 0, flow: 0 };
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
      if (!isPlant(b) && !usesPower(b) && b.type !== 'battery') continue;
      // Big buildings are supplied by a pole that reaches any of their tiles.
      const reach = POLE_SUPPLY + (sizeOf(b.type) - 1) / 2;
      for (let dz = -reach; dz <= reach && !b.net; dz++) {
        for (let dx = -reach; dx <= reach; dx++) {
          const p = at(b.tile.x + dx, b.tile.z + dz);
          if (p?.type !== 'pole') continue;
          b.net = p.net;
          (isPlant(b) ? p.net.plants : b.type === 'battery' ? p.net.batteries : p.net.consumers).push(b);
          break;
        }
      }
    }
    // Turbines close together take each other's wind.
    const turbines = [...buildings.values()].filter((b) => b.type === 'wind');
    for (const t of turbines) {
      const near = turbines.filter((o) => o !== t && Math.max(Math.abs(o.tile.x - t.tile.x), Math.abs(o.tile.z - t.tile.z)) <= WIND_WAKE).length;
      t.wake = Math.max(0.2, 1 - near * WAKE_LOSS);
    }
  }

  // Speed factor of a machine from its power: 1 off the grid (less in the frost),
  // up to POWER_SPEED on it.
  const frost = biomeOf(world.biome).frost ?? 1;
  const powerFactor = (b) => (b.net ? POWER_SPEED * b.net.satisfaction : frost);

  // Sunlight on the panels, set from the day-night cycle (see main.js); the
  // balancing tool leaves it at full sun or sets it itself.
  let daylight = 1;
  const biomeInfo = biomeOf(world.biome);
  const sunNow = () => daylight * (biomeInfo.sun ?? 1) * weatherEffect(weather, 'solar');
  const windNow = () => Math.min(1.5, windAt(time, world.seed ?? 0) * (biomeInfo.wind ?? 1) * weatherEffect(weather, 'wind'));
  const batteryCapacity = () => BATTERY_CAPACITY * research.stats.battery;

  // Output of one plant right now: coal plants while they burn, geothermal always,
  // solar with the sun and wind turbines with the wind.
  function plantOutput(p) {
    if (p.type === 'geo') return GEO_OUTPUT * research.stats.power * weatherEffect(weather, 'geo');
    if (p.type === 'solar') return SOLAR_OUTPUT * research.stats.renewable * sunNow();
    if (p.type === 'wind') return WIND_OUTPUT * research.stats.renewable * windNow() * (p.wake ?? 1);
    return p.burn > 0 ? POWER_OUTPUT * research.stats.power : 0;
  }

  // Shares the power of each network's plants among its working machines:
  // renewable and geothermal power first, then the batteries, coal last. What the
  // clean plants give beyond the demand charges the batteries.
  function tickPower(dt) {
    for (const b of buildings.values()) {
      if ((b.type === 'geo' || isRenewable(b)) && !b.net) b.state = plantOutput(b) > 0 ? 'idle' : 'empty';
      if (b.type === 'battery' && !b.net) b.state = 'idle';
      if (b.type !== 'power') continue;
      // Load the next coal before the current one is used up.
      if (b.burn <= 0 && b.fuel > 0) {
        b.fuel--;
        b.burn += COAL_ENERGY * research.stats.power;
      }
      if (!b.net) b.state = b.burn > 0 || b.fuel > 0 ? 'idle' : 'empty';
    }
    const cap = batteryCapacity();
    for (const net of grid.nets) {
      let clean = 0;
      let coal = 0;
      for (const p of net.plants) {
        const out = plantOutput(p);
        p.out = out;
        if (p.type === 'power') coal += out;
        else clean += out;
      }
      net.capacity = clean + coal;
      // Machines that are working or waiting for power ask for it.
      net.demand = 0;
      for (const b of net.consumers) if (b.state === 'work' || b.state === 'nopower') net.demand += POWER_USE[b.type];
      let canGive = 0;
      let canTake = 0;
      for (const b of net.batteries) {
        b.charge = Math.min(cap, b.charge ?? 0);
        canGive += Math.min(BATTERY_RATE, b.charge / dt);
        canTake += Math.min(BATTERY_RATE, (cap - b.charge) / dt);
      }
      const fromClean = Math.min(clean, net.demand);
      const fromBattery = Math.min(canGive, net.demand - fromClean);
      const fromCoal = Math.min(coal, net.demand - fromClean - fromBattery);
      const charging = Math.min(canTake, clean - fromClean);
      // Batteries share the flow by what each can take or give.
      const flow = charging > 0 ? charging : -fromBattery;
      for (const b of net.batteries) {
        const share = flow > 0 ? (canTake ? Math.min(BATTERY_RATE, (cap - b.charge) / dt) / canTake : 0) : canGive ? Math.min(BATTERY_RATE, b.charge / dt) / canGive : 0;
        b.flow = flow * share;
        b.charge = Math.min(cap, Math.max(0, b.charge + b.flow * dt));
        b.state = b.flow > 0.01 ? 'charge' : b.flow < -0.01 ? 'discharge' : 'idle';
      }
      const supply = fromClean + fromBattery + fromCoal;
      net.satisfaction = net.demand > 0 ? supply / net.demand : net.capacity > 0 || canGive > 0 ? 1 : 0;
      net.used = supply;
      net.clean = fromClean + fromBattery;
      net.coal = fromCoal;
      net.flow = flow;
      // The clean plants run at the share they are needed (machines and charging),
      // coal plants at what is left for them.
      const cleanLoad = clean ? (fromClean + charging) / clean : 0;
      const coalLoad = coal ? fromCoal / coal : 0;
      for (const p of net.plants) {
        if (p.out <= 0) {
          p.state = 'empty';
          p.load = 0;
          continue;
        }
        const load = p.type === 'power' ? coalLoad : cleanLoad;
        if (p.type === 'power') p.burn -= p.out * load * dt;
        p.load = load;
        p.state = load > 0 ? 'work' : 'idle';
      }
    }
  }

  // Totals over all networks, for the HUD.
  function powerSummary() {
    const s = { nets: grid.nets.length, plants: 0, capacity: 0, demand: 0, used: 0, consumers: 0, short: 0, fuel: 0, geo: 0, solar: 0, wind: 0, coalPlants: 0, clean: 0, coal: 0, batteries: 0, charge: 0, storage: 0, flow: 0 };
    for (const net of grid.nets) {
      s.plants += net.plants.length;
      s.capacity += net.capacity;
      s.demand += net.demand;
      s.used += net.used;
      s.clean += net.clean;
      s.coal += net.coal;
      s.flow += net.flow;
      s.consumers += net.consumers.length;
      if (net.consumers.length && net.satisfaction < 1) s.short++;
      for (const p of net.plants) {
        if (p.type === 'power') {
          s.coalPlants++;
          s.fuel += p.fuel + (p.burn > 0 ? 1 : 0);
        } else s[p.type]++;
      }
      for (const b of net.batteries) {
        s.batteries++;
        s.charge += b.charge;
      }
    }
    s.storage = s.batteries * batteryCapacity();
    s.satisfaction = s.demand ? s.used / s.demand : s.capacity > 0 || s.charge > 0 ? 1 : 0;
    s.sun = sunNow();
    s.windSpeed = windNow();
    return s;
  }

  // MJ stored in every battery, on a network or not.
  function storedEnergy() {
    let n = 0;
    for (const b of buildings.values()) if (b.type === 'battery') n += b.charge ?? 0;
    return n;
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
    history.produce('oil', n);
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
      history.consume('oil', recipe.oil);
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
    history.produce(recipe.makes);
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
    // A station or signal turns its track with it.
    if (b.type === 'station' || b.type === 'signal') {
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
    drones.markDirty();
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
      history.consume(kind);
      target.refused = null;
      return true;
    }
    if (target.type === 'silo') {
      // Parts of the stage being built, from any side, up to what it needs.
      const need = SILO_STAGES[target.stage]?.needs[kind];
      if (!need) {
        if (!SILO_STAGES[target.stage]?.needs) return false;
        target.refused = kind;
        return false;
      }
      if ((target.have[kind] ?? 0) >= need) return false;
      target.have[kind] = (target.have[kind] ?? 0) + 1;
      target.refused = null;
      history.consume(kind);
      return true;
    }
    if (target.type === 'provider') return drones.accept(target, kind);
    if (target.type === 'turret' || target.type === 'artillery') {
      if (!enemies.accept(target, kind)) return false;
      history.consume(kind);
      return true;
    }
    if (target.type === 'wall' || target.type === 'laser') return false;
    if (target.type === 'requester') return false;
    if (target.type === 'station') {
      // Loading stations take parts over their two sides, not along the track.
      if (target.mode !== 'load' || dir % 2 === target.dir % 2 || target.total >= STATION_CAP) return false;
      target.items[kind] = (target.items[kind] ?? 0) + 1;
      target.total++;
      target.received++;
      return true;
    }
    if (target.type === 'drill' || target.type === 'pole' || isTrack(target) || target.type === 'dronePort' || isFluid(target) || target.dir === opposite(dir)) return false;
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
      history.consume(b.current);
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
    history.produce(recipe.makes[b.current]);
    b.current = null;
    b.made++;
  }

  function tickConstructor(b, dt) {
    const recipe = CONSTRUCTOR_RECIPES[b.recipe];
    const time = recipe.time / research.stats.constructor;
    if (b.output.length && pushTo(neighbour(b, b.dir), b.output[0], b.dir)) b.output.shift();
    if (!b.busy && Object.entries(recipe.needs).every(([k, n]) => (b.input[k] ?? 0) >= n)) {
      for (const [k, n] of Object.entries(recipe.needs)) {
        b.input[k] -= n;
        history.consume(k, n);
      }
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
    history.produce(recipe.makes);
    b.busy = false;
    b.made++;
  }

  // Building the stages of a rocket silo, one after another.
  function tickSilo(b, dt) {
    const stage = SILO_STAGES[b.stage];
    if (!stage) {
      b.state = 'ready';
      return;
    }
    if (!b.busy && Object.entries(stage.needs).every(([k, n]) => (b.have[k] ?? 0) >= n)) {
      b.busy = true;
      b.timer = 0;
    }
    if (!b.busy) {
      b.state = 'idle';
      return;
    }
    const speed = powerFactor(b);
    b.state = speed > 0 ? 'work' : 'nopower';
    b.timer = Math.min(b.timer + dt * speed, stage.time);
    if (b.timer < stage.time) return;
    b.stage++;
    b.have = {};
    b.busy = false;
    b.timer = 0;
    b.made++;
    b.state = b.stage >= SILO_STAGES.length ? 'ready' : 'idle';
  }

  // Starts the rocket of a ready silo. The launch pad stays; the next rocket
  // needs every stage after it again.
  function launch(b) {
    if (!siloReady(b)) return false;
    b.stage = 1;
    b.have = {};
    b.launched++;
    launched++;
    launches.push(b);
    return true;
  }

  // The silo furthest along, for the HUD.
  function siloSummary() {
    let best = null;
    let silos = 0;
    for (const b of buildings.values()) {
      if (b.type !== 'silo') continue;
      silos++;
      if (!best || b.stage > best.stage || (b.stage === best.stage && b.busy && !best.busy)) best = b;
    }
    return { silos, best, launched };
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
    b.timer += dt * research.stats.drill * speed * weatherEffect(weather, 'drill');
    if (b.timer >= DRILL_TIME) {
      b.timer -= DRILL_TIME;
      b.tile.amount--;
      b.held = b.tile.ore;
      history.produce(b.tile.ore);
      b.mined++;
      mined[b.tile.ore]++;
    }
  }

  const beltSpeed = () => BELT_SPEED * research.stats.belt * weatherEffect(weather, 'belt');

  // Items of one kind put into storage during the last minute.
  function perMinute(kind) {
    const log = recent[kind];
    while (log.length && log[0] < time - 60) log.shift();
    return log.length;
  }

  const count = (type) => {
    if (type === 'train') return railways.trains.length;
    if (isVehicleType(type)) return vehicles.count(type);
    if (type === 'siloStage') {
      let best = 0;
      for (const b of buildings.values()) if (b.type === 'silo') best = Math.max(best, b.stage);
      return best;
    }
    let n = 0;
    for (const b of buildings.values()) if (b.type === type) n++;
    return n;
  };

  function tick(dt) {
    if (gridDirty) updateGrid();
    if (pipesDirty) updatePipes();
    if (railways.dirty) derailed.push(...railways.update());
    time += dt;
    weather = weatherAt(world.biome, time);
    tickPower(dt);
    let capacity = 0;
    let demand = 0;
    for (const net of grid.nets) {
      capacity += net.capacity;
      demand += net.demand;
    }
    history.tick(dt, capacity, demand);
    tickFluids(dt);
    railways.tick(dt);
    drones.tick(dt);
    const step = beltSpeed() * dt;
    for (const b of buildings.values()) if (b.type === 'belt' && b.items.length) tickBelt(b, step);
    for (const b of buildings.values()) {
      if (isMachine(b)) tickMachine(b, dt);
      else if (b.type === 'constructor') tickConstructor(b, dt);
      else if (b.type === 'splitter') tickSplitter(b);
      else if (b.type === 'merger') tickMerger(b);
      else if (b.type === 'silo') tickSilo(b, dt);
    }
    for (const b of buildings.values()) if (b.type === 'drill') tickDrill(b, dt);
    enemies.tick(dt, (b) => (b.net ? b.net.satisfaction : 0));
    vehicles.tick(dt);
  }

  // Plain data for a save game. The world itself is rebuilt from its seed,
  // only the ore left in each field is stored.
  function save() {
    settleOil();
    return {
      time,
      pumped,
      shipped,
      flown,
      flyLog: [...flyLog],
      drones: drones.save(),
      enemies: enemies.save(),
      vehicles: vehicles.save(),
      launched,
      history: history.save(),
      shipLog: [...shipLog],
      trains: railways.save(),
      mined,
      stored,
      delivered,
      recent: Object.fromEntries(Object.entries(recent).filter(([, log]) => log.length)),
      research: research.save(),
      amounts: world.tiles.filter((t) => t.ore).map((t) => t.amount),
      buildings: [...buildings.values()].map(({ tile, index, net, load, pipes, links, depth, green, dnet, out, aim, wake, flow, ...rest }) => ({ ...rest, index })),
    };
  }

  // `version` is the save format (see save.js); before 3 there was no oil on the map.
  function load(data, version = Infinity) {
    time = data.time ?? 0;
    weather = weatherAt(world.biome, time);
    pumped = data.pumped ?? 0;
    shipped = data.shipped ?? 0;
    launched = data.launched ?? 0;
    flown = data.flown ?? 0;
    flyLog.length = 0;
    flyLog.push(...(data.flyLog ?? []));
    history.load(data.history);
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
    footprint.clear();
    pipes.nets = [];
    for (const b of data.buildings ?? []) {
      const tile = world.tiles[b.index];
      if (!tile || !BUILDINGS[b.type] || BUILDINGS[b.type].vehicle) continue;
      const loaded = { ...b, tile };
      buildings.set(b.index, loaded);
      cover(loaded);
    }
    railways.load(data.trains);
    drones.load(data.drones);
    // Before version 8 there were no enemies: old games stay peaceful.
    enemies.load(data.enemies ?? { mode: 'off' });
    vehicles.load(data.vehicles);
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
    storedEnergy,
    setDaylight: (v) => (daylight = v),
    get daylight() {
      return daylight;
    },
    batteryCapacity,
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
    get launched() {
      return launched;
    },
    get flown() {
      return flown;
    },
    flownPerMinute,
    drones,
    enemies,
    vehicles,
    addVehicle: (kind, tile, dir) => vehicles.add(kind, tile, Math.atan2(DIRS[dir].x, DIRS[dir].z)),
    canAddVehicle: (kind, tile) => vehicles.canAdd(kind, tile),
    setRequest: (b, kind, want) => drones.setRequest(b, kind, want),
    history,
    launches,
    launch,
    siloSummary,
    // Indices of every tile a building stands on.
    footprint: (b) => tilesOf(b.type, b.tile).map(indexOf),
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
    get weather() {
      return weather;
    },
    biome: world.biome ?? 'meadow',
    frost,
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
    get: (tile) => at(tile.x, tile.z),
  };
}
