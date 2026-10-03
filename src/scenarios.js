// Maps to play. The free game has a random map with every ore and the research tree;
// every other map has its own landscape, only some ores and a chain of missions.
//
// To add a map, append an entry:
//   id/name/desc  key and text for the map selection
//   level         difficulty 1..4 (dots on the card)
//   seed          fixed seed, so everyone plays the same map
//   map           landscape and ores, see DEFAULT_MAP in world.js
//   start         buildings available from the beginning
//   par           minutes for three stars (twice that for two)
//   missions      played one after another; each has
//     name/desc   text for the mission panel
//     goals       all must be met:
//                   { deliver: item, count }   put `count` more into storage
//                   { build: type, count }      have `count` of a building
//                   { rate: item, perMin }      that many into storage within one minute
//     reward      { unlocks, boosts, text } like a research entry, see research.js
export const SCENARIOS = [
  {
    id: 'free',
    name: 'Freies Spiel',
    desc: 'Zufällige Insel mit allen Erzen. Du schaltest alles über den Forschungsbaum frei.',
    free: true,
  },
  {
    id: 'ironHills',
    name: 'Eisenberge',
    desc: 'Felsige Berge voller Eisen und Kalkstein. Der Einstieg: vom ersten Bohrer zum Zahnradwerk.',
    level: 1,
    seed: 2207,
    map: { ores: { iron: 7, stone: 4 }, rock: 0.7, forest: 0.5, land: 0.07 },
    start: ['drill', 'belt', 'storage'],
    par: 12,
    missions: [
      {
        name: 'Erster Abstich',
        desc: 'Setze Bohrer auf das Eisen und leite das Erz über Bänder in ein Lager.',
        goals: [{ build: 'drill', count: 2 }, { deliver: 'iron', count: 30 }],
        reward: { unlocks: ['furnace'], text: 'Schmelzofen' },
      },
      {
        name: 'Glühendes Eisen',
        desc: 'Ein Band ins Ofenmaul, Barren hinten raus und ab ins Lager.',
        goals: [{ deliver: 'ironIngot', count: 30 }],
        reward: { unlocks: ['assembler'], text: 'Presse' },
      },
      {
        name: 'Platten und Beton',
        desc: 'Die Presse macht aus Barren Platten und aus Kalkstein Beton.',
        goals: [{ deliver: 'ironPlate', count: 25 }, { deliver: 'concrete', count: 15 }],
        reward: { unlocks: ['constructor'], boosts: { drill: 1.5 }, text: 'Konstruktor, Bohrer +50 %' },
      },
      {
        name: 'Zahnradwerk',
        desc: 'Zwei Platten ergeben ein Zahnrad. Klick den Konstruktor an, um das Rezept zu wählen.',
        goals: [{ deliver: 'gear', count: 20 }],
        reward: { unlocks: ['splitter', 'merger'], boosts: { belt: 1.5 }, text: 'Verteiler, Zusammenführer, Bänder +50 %' },
      },
      {
        name: 'Am laufenden Band',
        desc: 'Ein Ofen reicht nicht mehr. Teile das Erz mit Verteilern auf mehrere Öfen auf.',
        goals: [{ rate: 'gear', perMin: 20 }],
        reward: { text: 'Die Eisenberge gehören dir' },
      },
    ],
  },
  {
    id: 'copperDesert',
    name: 'Kupferwüste',
    desc: 'Heißer Sand, Kakteen, Kupfer und Kalkstein. Nur wer viele Öfen verteilt, schafft das Drahtziel.',
    level: 2,
    seed: 8128,
    map: { ores: { copper: 5, stone: 3 }, desert: true, forest: 0.74, rock: 0.4, land: 0.04 },
    start: ['drill', 'belt', 'storage', 'furnace'],
    par: 15,
    missions: [
      {
        name: 'Kupferrausch',
        desc: 'Der Ofen ist schon da. Schmelz das Kupfererz zu Barren.',
        goals: [{ build: 'furnace', count: 2 }, { deliver: 'copperIngot', count: 30 }],
        reward: { unlocks: ['assembler'], text: 'Presse' },
      },
      {
        name: 'Draht und Stein',
        desc: 'Die Presse zieht Kupferdraht und gießt Beton für die Wüstenstadt.',
        goals: [{ deliver: 'wire', count: 40 }, { deliver: 'concrete', count: 20 }],
        reward: { unlocks: ['splitter', 'merger'], boosts: { furnace: 1.5 }, text: 'Verteiler, Zusammenführer, Öfen +50 %' },
      },
      {
        name: 'Sandsturm',
        desc: 'Halte die Leitung am Laufen: 30 Draht in einer Minute.',
        goals: [{ rate: 'wire', perMin: 30 }],
        reward: { boosts: { belt: 1.6, drill: 1.4 }, text: 'Bänder +60 %, Bohrer +40 %' },
      },
      {
        name: 'Kupferkönig',
        desc: 'Die große Lieferung: viel Draht und Beton gleichzeitig.',
        goals: [{ rate: 'wire', perMin: 60 }, { rate: 'concrete', perMin: 20 }],
        reward: { text: 'Die Wüste glänzt kupferrot' },
      },
    ],
  },
  {
    id: 'coalIsland',
    name: 'Kohleinsel',
    desc: 'Eine kleine Insel mit Kohle und etwas Eisen. Wenig Platz, aber genug für ein Stahlwerk.',
    level: 3,
    seed: 3301,
    map: { ores: { coal: 5, iron: 3 }, coast: 0.3, land: -0.02, rock: 0.4, forest: 0.6, richness: 1.4 },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler'],
    par: 15,
    missions: [
      {
        name: 'Landung',
        desc: 'Grabe Kohle und Eisen ab. Platz ist knapp, plane deine Bänder.',
        goals: [{ deliver: 'coal', count: 20 }, { deliver: 'ironIngot', count: 20 }],
        reward: { unlocks: ['constructor'], text: 'Konstruktor' },
      },
      {
        name: 'Stahl kochen',
        desc: 'Zwei Eisenbarren und eine Kohle ergeben einen Stahlträger.',
        goals: [{ deliver: 'steel', count: 15 }],
        reward: { unlocks: ['splitter', 'merger'], boosts: { drill: 1.5 }, text: 'Verteiler, Zusammenführer, Bohrer +50 %' },
      },
      {
        name: 'Schwerindustrie',
        desc: 'Stahl und Zahnräder für die Hafenkräne.',
        goals: [{ deliver: 'steel', count: 30 }, { deliver: 'gear', count: 20 }],
        reward: { boosts: { belt: 1.6, constructor: 1.5 }, text: 'Bänder +60 %, Konstruktor +50 %' },
      },
      {
        name: 'Stahlwerk',
        desc: 'Die Insel exportiert: 20 Stahlträger in einer Minute.',
        goals: [{ rate: 'steel', perMin: 20 }],
        reward: { text: 'Die Kohleinsel raucht' },
      },
    ],
  },
  {
    id: 'mainland',
    name: 'Großes Festland',
    desc: 'Alle Erze, weite Wege. Die Meisterprüfung: Schaltkreise und Stahl in Massen.',
    level: 4,
    seed: 6060,
    map: { ores: { iron: 5, copper: 4, coal: 3, stone: 3 }, land: 0.06, coast: 0.85, richness: 1.2 },
    start: ['drill', 'belt', 'storage'],
    par: 25,
    missions: [
      {
        name: 'Erkundung',
        desc: 'Bring von jedem Erz eine Probe ins Lager.',
        goals: [{ deliver: 'iron', count: 20 }, { deliver: 'copper', count: 20 }, { deliver: 'coal', count: 10 }, { deliver: 'stone', count: 10 }],
        reward: { unlocks: ['furnace', 'assembler'], text: 'Schmelzofen, Presse' },
      },
      {
        name: 'Grundstoffe',
        desc: 'Platten und Draht, das Brot jeder Fabrik.',
        goals: [{ deliver: 'ironPlate', count: 30 }, { deliver: 'wire', count: 30 }],
        reward: { unlocks: ['constructor', 'splitter', 'merger'], text: 'Konstruktor, Verteiler, Zusammenführer' },
      },
      {
        name: 'Erste Schaltkreise',
        desc: 'Eine Platte und zwei Draht ergeben einen Schaltkreis.',
        goals: [{ deliver: 'circuit', count: 20 }],
        reward: { boosts: { belt: 1.6, drill: 1.5 }, text: 'Bänder +60 %, Bohrer +50 %' },
      },
      {
        name: 'Bauprogramm',
        desc: 'Zahnräder, Stahl und Beton für die große Halle.',
        goals: [{ deliver: 'gear', count: 20 }, { deliver: 'steel', count: 20 }, { deliver: 'concrete', count: 20 }],
        reward: { boosts: { furnace: 2, assembler: 1.5, constructor: 1.5 }, text: 'Öfen ×2, Presse und Konstruktor +50 %' },
      },
      {
        name: 'Meisterprüfung',
        desc: 'Schaltkreise und Stahl gleichzeitig im Minutentakt.',
        goals: [{ rate: 'circuit', perMin: 15 }, { rate: 'steel', perMin: 15 }],
        reward: { text: 'Du bist Meister der Fabrik' },
      },
    ],
  },
];

export const scenarioById = (id) => SCENARIOS.find((s) => s.id === id);

// Stars for a finished map: three under par, two under twice par, else one.
export const starsFor = (scenario, seconds) => (seconds <= scenario.par * 60 ? 3 : seconds <= scenario.par * 120 ? 2 : 1);

// Mission progress of one game.
export function createMissions(scenario, factory) {
  let index = 0;
  let base = { ...factory.delivered }; // deliveries count from the start of each mission
  let reached = new Set(); // rate goals met once stay met
  let finishedAt = null;

  function progress(goal, i) {
    if (goal.deliver) return { item: goal.deliver, have: factory.delivered[goal.deliver] - base[goal.deliver], need: goal.count };
    if (goal.build) return { building: goal.build, have: factory.count(goal.build), need: goal.count };
    const have = reached.has(i) ? goal.perMin : factory.perMinute(goal.rate);
    return { item: goal.rate, rate: true, have, need: goal.perMin };
  }

  return {
    get index() {
      return index;
    },
    get current() {
      return scenario.missions[index] ?? null;
    },
    get finishedAt() {
      return finishedAt;
    },
    goals() {
      const m = this.current;
      return m ? m.goals.map(progress) : [];
    },
    // Advances when every goal of the current mission is met; returns that mission.
    check() {
      const m = this.current;
      if (!m) return null;
      const all = m.goals.map(progress);
      all.forEach((p, i) => p.rate && p.have >= p.need && reached.add(i));
      if (!all.every((p) => p.have >= p.need)) return null;
      factory.research.grant(m.reward);
      index++;
      base = { ...factory.delivered };
      reached = new Set();
      if (!this.current) finishedAt = factory.time;
      return m;
    },
    save: () => ({ index, base, reached: [...reached], finishedAt }),
    load(data) {
      if (!data) return;
      index = Math.min(data.index ?? 0, scenario.missions.length);
      base = { ...base, ...data.base };
      reached = new Set(data.reached ?? []);
      finishedAt = data.finishedAt ?? null;
    },
  };
}

// Best results per map, kept in this browser.
const KEY = 'bolla.scenarios';
export function loadRecords() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) ?? {};
  } catch {
    return {};
  }
}
export function saveRecord(id, stars, seconds) {
  const records = loadRecords();
  const old = records[id];
  records[id] = { stars: Math.max(stars, old?.stars ?? 0), time: Math.min(seconds, old?.time ?? Infinity) };
  try {
    localStorage.setItem(KEY, JSON.stringify(records));
  } catch {
    // Private mode or storage blocked: the record is just not kept.
  }
  return records[id];
}
