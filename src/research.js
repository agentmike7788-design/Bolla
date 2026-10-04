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
    id: 'electricity',
    name: 'Elektrizität',
    desc: 'Kohlekraftwerk und Strommasten. Maschinen am Netz arbeiten doppelt so schnell, solange der Strom reicht.',
    cost: { ironPlate: 20, wire: 30, coal: 20 },
    requires: ['pressing'],
    unlocks: ['power', 'pole'],
  },
  {
    id: 'turbines',
    name: 'Dampfturbinen',
    desc: 'Kohlekraftwerke liefern 50 % mehr Strom aus jeder Kohle.',
    cost: { gear: 25, steel: 20 },
    requires: ['electricity', 'constructor'],
    boosts: { power: 1.5 },
  },
  {
    id: 'geothermal',
    name: 'Erdwärme',
    desc: 'Erdwärmekraftwerk: 12 MW ohne Kohle, direkt auf einer dampfenden Quelle. Quellen gibt es nur auf Vulkaninseln.',
    cost: { ironPlate: 40, concrete: 40, wire: 30 },
    requires: ['electricity'],
    unlocks: ['geo'],
  },
  {
    id: 'firstFactory',
    name: 'Erste Fabrik',
    desc: 'Das erste Spielziel: eine Fabrik, die schmilzt und presst.',
    cost: { ironPlate: 40, wire: 40, concrete: 25 },
    requires: ['pressing'],
    goal: true,
  },
  {
    id: 'constructor',
    name: 'Konstruktor',
    desc: 'Baut Zahnräder, Schaltkreise und Stahlträger aus mehreren Teilen. Kohle wird gebraucht!',
    cost: { ironPlate: 60, wire: 50, concrete: 30 },
    requires: ['firstFactory'],
    unlocks: ['constructor'],
  },
  {
    id: 'hydraulics',
    name: 'Hydraulik',
    desc: 'Presse und Konstruktor arbeiten 50 % schneller.',
    cost: { gear: 30, circuit: 20 },
    requires: ['constructor'],
    boosts: { assembler: 1.5, constructor: 1.5 },
  },
  {
    id: 'deepDrill',
    name: 'Tiefbohrer',
    desc: 'Bohrer fördern noch einmal 70 % schneller.',
    cost: { steel: 30, circuit: 20 },
    requires: ['constructor', 'drillHeads'],
    boosts: { drill: 1.7 },
  },
  {
    id: 'maglev',
    name: 'Magnetbänder',
    desc: 'Förderbänder schweben und laufen noch einmal 40 % schneller.',
    cost: { gear: 40, steel: 30 },
    requires: ['constructor', 'expressBelts'],
    boosts: { belt: 1.4 },
  },
  {
    id: 'masterFactory',
    name: 'Meisterfabrik',
    desc: 'Das große Ziel: Schaltkreise, Stahl und Zahnräder in Massen.',
    cost: { circuit: 120, steel: 100, gear: 100 },
    requires: ['hydraulics', 'deepDrill', 'maglev'],
    goal: true,
  },
  {
    id: 'oilDrilling',
    name: 'Ölförderung',
    desc: 'Ölpumpe, Rohre und Öltank. Pumpen laufen nur am Stromnetz.',
    cost: { circuit: 30, steel: 20, concrete: 30 },
    requires: ['electricity', 'constructor'],
    unlocks: ['pump', 'pipe', 'tank'],
  },
  {
    id: 'refining',
    name: 'Raffinerie',
    desc: 'Macht aus Öl Kunststoff oder Treibstoff. Mit Kunststoff baut der Konstruktor Prozessoren.',
    cost: { gear: 30, circuit: 30, steel: 20 },
    requires: ['oilDrilling'],
    unlocks: ['refinery'],
  },
  {
    id: 'catalysts',
    name: 'Katalysatoren',
    desc: 'Raffinerien und Ölpumpen arbeiten 50 % schneller.',
    cost: { plastic: 40, fuel: 20 },
    requires: ['refining'],
    boosts: { refinery: 1.5, pump: 1.5 },
  },
  {
    id: 'railways',
    name: 'Eisenbahn',
    desc: 'Gleise, Bahnhöfe und Züge. Ein Zug holt die Teile von weit weg und lädt sie am Ziel wieder aufs Band.',
    cost: { steel: 30, gear: 30, concrete: 40 },
    requires: ['constructor', 'logistics'],
    unlocks: ['rail', 'station', 'train'],
  },
  {
    id: 'expressTrains',
    name: 'Schnellzüge',
    desc: 'Züge fahren 60 % schneller.',
    cost: { steel: 40, circuit: 40 },
    requires: ['railways'],
    boosts: { train: 1.6 },
  },
  {
    id: 'signals',
    name: 'Zugsignale',
    desc: 'Signale teilen die Strecke in Blöcke: in jeden Block fährt nur ein Zug. Kettensignale halten Züge vor Kreuzungen, bis der Weg hindurch frei ist.',
    cost: { circuit: 30, steel: 20 },
    requires: ['railways'],
    unlocks: ['signal'],
  },
  {
    id: 'drones',
    name: 'Logistikdrohnen',
    desc: 'Drohnenhafen, Angebots- und Anfragekisten. Drohnen fliegen Teile ohne Band von Kiste zu Kiste, solange der Hafen Strom hat.',
    cost: { circuit: 60, gear: 40, steel: 40 },
    requires: ['hydraulics', 'electricity'],
    unlocks: ['dronePort', 'provider', 'requester'],
  },
  {
    id: 'droneRotors',
    name: 'Leichtbau-Rotoren',
    desc: 'Drohnen fliegen 60 % schneller.',
    cost: { plastic: 30, processor: 15 },
    requires: ['drones', 'refining'],
    boosts: { drone: 1.6 },
  },
  {
    id: 'defense',
    name: 'Verteidigung',
    desc: 'Mauern und Geschütztürme. Der Konstruktor baut Munition aus Eisenplatte und Kupferbarren, Bänder bringen sie zu den Türmen.',
    cost: { ironPlate: 40, concrete: 40, copperIngot: 20 },
    requires: ['firstFactory'],
    unlocks: ['wall', 'turret'],
  },
  {
    id: 'hardAmmo',
    name: 'Hartkernmunition',
    desc: 'Geschütz- und Lasertürme richten 50 % mehr Schaden an.',
    cost: { steel: 30, ammo: 40 },
    requires: ['defense', 'constructor'],
    boosts: { weapons: 1.5 },
  },
  {
    id: 'lasers',
    name: 'Lasertürme',
    desc: 'Lasertürme brauchen keine Munition, nur Strom (3 MW, solange sie feuern), und reichen weiter.',
    cost: { circuit: 50, steel: 40, ammo: 30 },
    requires: ['hardAmmo', 'electricity'],
    unlocks: ['laser'],
  },
  {
    id: 'focusLens',
    name: 'Fokuslinsen',
    desc: 'Alle Türme richten noch einmal 40 % mehr Schaden an.',
    cost: { processor: 20, circuit: 40 },
    requires: ['lasers', 'refining'],
    boosts: { weapons: 1.4 },
  },
  {
    id: 'artillery',
    name: 'Artillerie',
    desc: 'Ein schweres Geschütz (3 × 3) mit 30 Feldern Reichweite, das Nester von weitem beschießt. Der Konstruktor baut Granaten aus Stahl und Munition. Beschossene Nester greifen das Geschütz an.',
    cost: { steel: 60, gear: 40, ammo: 40 },
    requires: ['hardAmmo'],
    unlocks: ['artillery'],
  },
  {
    id: 'longBarrels',
    name: 'Lange Rohre',
    desc: 'Artillerie schießt 40 % weiter.',
    cost: { steel: 50, circuit: 40, shell: 20 },
    requires: ['artillery'],
    boosts: { artillery: 1.4 },
  },
  {
    id: 'solarPower',
    name: 'Solarenergie',
    desc: 'Solarpanels: bis zu 3 MW, solange die Sonne scheint. Kein Brennstoff, kein Smog, aber nachts nichts.',
    cost: { circuit: 20, ironPlate: 30, wire: 30 },
    requires: ['electricity', 'constructor'],
    unlocks: ['solar'],
  },
  {
    id: 'windPower',
    name: 'Windkraft',
    desc: 'Windräder: bis zu 5 MW, Tag und Nacht, je nach Wind. Stehen sie zu dicht, nehmen sie sich den Wind.',
    cost: { gear: 30, ironPlate: 30, wire: 20 },
    requires: ['electricity', 'constructor'],
    unlocks: ['wind'],
  },
  {
    id: 'batteries',
    name: 'Akkus',
    desc: 'Akkus speichern überschüssigen Sonnen- und Windstrom (600 MJ, 6 MW) und geben ihn nachts zurück, bevor Kohle verbrannt wird.',
    cost: { circuit: 30, copperIngot: 40, steel: 20 },
    requires: ['solarPower'],
    unlocks: ['battery'],
  },
  {
    id: 'thinFilm',
    name: 'Dünnschichtzellen',
    desc: 'Solarpanels und Windräder liefern 50 % mehr Strom.',
    cost: { processor: 15, plastic: 30 },
    requires: ['solarPower', 'windPower', 'refining'],
    boosts: { renewable: 1.5 },
  },
  {
    id: 'gridStorage',
    name: 'Großspeicher',
    desc: 'Akkus fassen doppelt so viel.',
    cost: { plastic: 40, circuit: 40, steel: 30 },
    requires: ['batteries', 'refining'],
    boosts: { battery: 2 },
  },
  {
    id: 'oilAge',
    name: 'Ölzeitalter',
    desc: 'Das letzte Ziel: Prozessoren, Kunststoff und Treibstoff für die Zukunft.',
    cost: { processor: 50, plastic: 80, fuel: 40 },
    requires: ['catalysts', 'masterFactory'],
    goal: true,
  },
  {
    id: 'spaceflight',
    name: 'Raumfahrt',
    desc: 'Das Raketensilo: Startrampe, Rumpf, Bordcomputer und Treibstoff in vier Etappen, dann geht die Rakete ins All.',
    cost: { processor: 30, steel: 60, concrete: 80 },
    requires: ['oilAge', 'expressTrains'],
    unlocks: ['silo'],
  },
];

// Factory stats that research can multiply. 1 is the starting value.
export const STATS = ['belt', 'drill', 'furnace', 'assembler', 'constructor', 'power', 'pump', 'refinery', 'train', 'drone', 'weapons', 'renewable', 'battery', 'artillery'];

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
