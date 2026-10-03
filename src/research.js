// The research tree. Each entry costs items from the storage and unlocks buildings
// or improves the factory once researched.
//
// To add something new, append an entry:
//   id        unique key, used in `requires` of other entries
//   name/desc text for the tree
//   cost      items taken from the storage, e.g. { ironIngot: 20 }
//   requires  ids that must be researched first ([] = available from the start)
//   unlocks   building types from BUILDINGS in factory.js that become buildable
//   boosts    multipliers for factory stats, see STATS below
//   goal      true marks the end goal of the current game
// The tree view places entries in columns by how deep they sit in the tree.
export const RESEARCH = [
  {
    id: 'smelting',
    name: 'Schmelzen',
    desc: 'Schmelzofen: Erz wird zu Barren.',
    cost: { iron: 20, copper: 20 },
    requires: [],
    unlocks: ['furnace'],
  },
  {
    id: 'drillHeads',
    name: 'Gehärtete Bohrköpfe',
    desc: 'Bohrer fördern 50 % schneller.',
    cost: { iron: 30, stone: 15 },
    requires: [],
    boosts: { drill: 1.5 },
  },
  {
    id: 'fastBelts',
    name: 'Schnelle Bänder',
    desc: 'Alle Förderbänder laufen 60 % schneller.',
    cost: { ironIngot: 20, copperIngot: 10 },
    requires: ['smelting'],
    boosts: { belt: 1.6 },
  },
  {
    id: 'pressing',
    name: 'Pressen',
    desc: 'Presse: Barren werden zu Platten und Draht, Kalkstein zu Beton.',
    cost: { ironIngot: 30, copperIngot: 20 },
    requires: ['smelting'],
    unlocks: ['assembler'],
  },
  {
    id: 'blower',
    name: 'Gebläse',
    desc: 'Schmelzöfen arbeiten doppelt so schnell.',
    cost: { ironPlate: 15, concrete: 10 },
    requires: ['pressing'],
    boosts: { furnace: 2 },
  },
  {
    id: 'expressBelts',
    name: 'Expressbänder',
    desc: 'Förderbänder laufen noch einmal 50 % schneller.',
    cost: { ironPlate: 20, wire: 20 },
    requires: ['fastBelts', 'pressing'],
    boosts: { belt: 1.5 },
  },
  {
    id: 'logistics',
    name: 'Logistik',
    desc: 'Verteiler teilt ein Band in drei, Zusammenführer macht aus drei eins.',
    cost: { ironIngot: 20, stone: 20 },
    requires: ['smelting'],
    unlocks: ['splitter', 'merger'],
  },
  {
    id: 'firstFactory',
    name: 'Erste Fabrik',
    desc: 'Das erste Spielziel: eine Fabrik, die schmilzt und presst.',
    cost: { ironPlate: 25, wire: 25, concrete: 15 },
    requires: ['pressing'],
    goal: true,
  },
  {
    id: 'constructor',
    name: 'Konstruktor',
    desc: 'Baut Zahnräder, Schaltkreise und Stahlträger aus mehreren Teilen. Kohle wird gebraucht!',
    cost: { ironPlate: 40, wire: 30, concrete: 20 },
    requires: ['firstFactory'],
    unlocks: ['constructor'],
  },
  {
    id: 'hydraulics',
    name: 'Hydraulik',
    desc: 'Presse und Konstruktor arbeiten 50 % schneller.',
    cost: { gear: 25, circuit: 10 },
    requires: ['constructor'],
    boosts: { assembler: 1.5, constructor: 1.5 },
  },
  {
    id: 'deepDrill',
    name: 'Tiefbohrer',
    desc: 'Bohrer fördern noch einmal 70 % schneller.',
    cost: { steel: 20, circuit: 15 },
    requires: ['constructor', 'drillHeads'],
    boosts: { drill: 1.7 },
  },
  {
    id: 'maglev',
    name: 'Magnetbänder',
    desc: 'Förderbänder schweben und laufen noch einmal 40 % schneller.',
    cost: { gear: 30, steel: 15 },
    requires: ['constructor', 'expressBelts'],
    boosts: { belt: 1.4 },
  },
  {
    id: 'masterFactory',
    name: 'Meisterfabrik',
    desc: 'Das große Ziel: Schaltkreise, Stahl und Zahnräder in Massen.',
    cost: { circuit: 50, steel: 40, gear: 40 },
    requires: ['hydraulics', 'deepDrill', 'maglev'],
    goal: true,
  },
];

// Factory stats that research can multiply. 1 is the starting value.
export const STATS = ['belt', 'drill', 'furnace', 'assembler', 'constructor'];

export const START_UNLOCKED = ['drill', 'belt', 'storage'];

const byId = Object.fromEntries(RESEARCH.map((r) => [r.id, r]));
export const researchById = (id) => byId[id];

// Column of an entry in the tree: one more than its deepest requirement.
export function depthOf(r) {
  return r.requires.length ? 1 + Math.max(...r.requires.map((id) => depthOf(byId[id]))) : 0;
}

// Research state of one game: what is done and what that gives.
// `start` are the buildings available from the beginning.
export function createResearch(stored, start = START_UNLOCKED) {
  const done = new Set();
  const unlocked = new Set(start);
  const stats = Object.fromEntries(STATS.map((s) => [s, 1]));
  const levels = Object.fromEntries(STATS.map((s) => [s, 0])); // boosts received per stat

  const available = (r) => !done.has(r.id) && r.requires.every((id) => done.has(id));
  const affordable = (r) => Object.entries(r.cost).every(([k, n]) => stored[k] >= n);

  // Unlocks and boosts of a research entry or a mission reward.
  function grant({ unlocks = [], boosts = {} }) {
    for (const type of unlocks) unlocked.add(type);
    for (const [stat, factor] of Object.entries(boosts)) {
      stats[stat] *= factor;
      levels[stat]++;
    }
  }

  function complete(id) {
    const r = byId[id];
    if (!r || !available(r) || !affordable(r)) return false;
    for (const [k, n] of Object.entries(r.cost)) stored[k] -= n;
    done.add(id);
    grant(r);
    return true;
  }

  return {
    done,
    unlocked,
    stats,
    levels,
    available,
    affordable,
    complete,
    grant,
    save: () => ({ done: [...done], unlocked: [...unlocked], stats: { ...stats }, levels: { ...levels } }),
    load(data) {
      if (!data) return;
      done.clear();
      for (const id of data.done ?? []) if (byId[id]) done.add(id);
      unlocked.clear();
      for (const type of data.unlocked ?? start) unlocked.add(type);
      for (const s of STATS) {
        stats[s] = data.stats?.[s] ?? 1;
        levels[s] = data.levels?.[s] ?? 0;
      }
    },
    get won() {
      return RESEARCH.some((r) => r.goal && done.has(r.id));
    },
  };
}
