// Maps to play. The free game has a random map with every ore and the research tree;
// every other map has its own landscape, only some ores and a chain of missions.
//
// To add a map, append an entry:
//   id/name/desc  key and text for the map selection
//   level         difficulty 1..4 (dots on the card)
//   seed          fixed seed, so everyone plays the same map
//   map           landscape and ores, see DEFAULT_MAP in world.js
//   start         buildings available from the beginning
//   par           minutes for three stars (twice that for two); `npm run balance`
//                 estimates play times, par is about 1.6 times that
//   missions      played one after another; each has
//     name/desc   text for the mission panel
//     goals       all must be met:
//                   { deliver: item, count }   put `count` more into storage
//                   { build: type, count }      have `count` of a building
//                   { rate: item, perMin }      that many into storage within one minute
//                   { powered: count }          that many machines working on power at once
//                   { oil: count }              pump that much more oil
//                   { shipped: count }          unload that many more parts from trains
//                   { silo: stages }            a rocket silo with that many stages built
//                   { launched: count }         start that many more rockets
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
    par: 13,
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
        desc: 'Ein Ofen reicht nicht mehr. Teile das Erz mit Verteilern auf mehrere Öfen auf, und der Beton muss nebenher weiterlaufen.',
        goals: [{ rate: 'gear', perMin: 20 }, { rate: 'concrete', perMin: 15 }],
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
    par: 12,
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
        desc: 'Eine Linie schafft das nicht: 45 Draht in einer Minute.',
        goals: [{ rate: 'wire', perMin: 45 }],
        reward: { boosts: { belt: 1.6, drill: 1.4 }, text: 'Bänder +60 %, Bohrer +40 %' },
      },
      {
        name: 'Kupferkönig',
        desc: 'Die große Lieferung: drei Drahtlinien und dazu Beton.',
        goals: [{ rate: 'wire', perMin: 90 }, { rate: 'concrete', perMin: 30 }],
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
    par: 14,
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
        reward: { unlocks: ['splitter', 'merger', 'power', 'pole'], boosts: { drill: 1.5 }, text: 'Verteiler, Zusammenführer, Bohrer +50 %, Kohlekraftwerk' },
      },
      {
        name: 'Unter Strom',
        desc: 'Kohle aufs Band ins Kraftwerk, Strommasten daneben und zu den Maschinen. Am Netz arbeiten sie doppelt so schnell.',
        goals: [{ build: 'power', count: 1 }, { powered: 4 }],
        reward: { boosts: { power: 1.5 }, text: 'Kraftwerke +50 %' },
      },
      {
        name: 'Schwerindustrie',
        desc: 'Stahl und Zahnräder für die Hafenkräne.',
        goals: [{ deliver: 'steel', count: 25 }, { deliver: 'gear', count: 20 }],
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
    par: 23,
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
        reward: { unlocks: ['power', 'pole'], boosts: { belt: 1.6, drill: 1.5 }, text: 'Kohlekraftwerk, Strommasten, Bänder +60 %, Bohrer +50 %' },
      },
      {
        name: 'Bauprogramm',
        desc: 'Zahnräder, Stahl und Beton für die große Halle. Hol dir Strom dazu, dann geht es doppelt so schnell.',
        goals: [{ deliver: 'gear', count: 20 }, { deliver: 'steel', count: 20 }, { deliver: 'concrete', count: 20 }, { powered: 6 }],
        reward: { boosts: { furnace: 2, assembler: 1.5, constructor: 1.5 }, text: 'Öfen ×2, Presse und Konstruktor +50 %' },
      },
      {
        name: 'Meisterprüfung',
        desc: 'Schaltkreise und Stahl im Minutentakt. Für die Schaltkreise brauchst du zwei Linien.',
        goals: [{ rate: 'circuit', perMin: 30 }, { rate: 'steel', perMin: 25 }],
        reward: { text: 'Du bist Meister der Fabrik' },
      },
    ],
  },
  {
    id: 'oilCoast',
    name: 'Ölküste',
    desc: 'Schwarze Pfützen an der Küste. Strom, Pumpen, Rohre und eine Raffinerie: Kunststoff für die Prozessoren.',
    level: 4,
    seed: 4242,
    map: { ores: { iron: 4, copper: 3, coal: 3, stone: 2, oil: 4 }, land: 0.05, coast: 0.82, forest: 0.62, richness: 1.2 },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'constructor', 'splitter', 'merger', 'power', 'pole'],
    par: 19,
    missions: [
      {
        name: 'Strom fürs Ölfeld',
        desc: 'Ohne Strom keine Pumpe. Kohle ins Kraftwerk, Masten zu den Maschinen.',
        goals: [{ build: 'power', count: 1 }, { powered: 3 }],
        reward: { unlocks: ['pump', 'pipe', 'tank'], text: 'Ölpumpe, Rohre, Öltank' },
      },
      {
        name: 'Schwarzes Gold',
        desc: 'Pumpen auf die schwarzen Felder, ein Strommast daneben und Rohre zu einem Tank.',
        goals: [{ build: 'pump', count: 2 }, { oil: 150 }],
        reward: { unlocks: ['refinery'], text: 'Raffinerie' },
      },
      {
        name: 'Raffiniert',
        desc: 'Ein Rohr hinten in die Raffinerie, ein Band vorn heraus. Klick sie an, um Kunststoff oder Treibstoff zu wählen.',
        goals: [{ deliver: 'plastic', count: 30 }, { deliver: 'fuel', count: 15 }],
        reward: { boosts: { pump: 1.5, power: 1.5 }, text: 'Pumpen +50 %, Kraftwerke +50 %' },
      },
      {
        name: 'Prozessoren',
        desc: 'Zwei Schaltkreise und ein Kunststoff ergeben einen Prozessor.',
        goals: [{ deliver: 'processor', count: 15 }],
        reward: { boosts: { constructor: 1.5, refinery: 1.5, belt: 1.6 }, text: 'Konstruktor und Raffinerie +50 %, Bänder +60 %' },
      },
      {
        name: 'Petrochemie',
        desc: 'Die Küste liefert: Kunststoff und Prozessoren im Minutentakt.',
        goals: [{ rate: 'plastic', perMin: 30 }, { rate: 'processor', perMin: 8 }],
        reward: { text: 'Das Öl fließt' },
      },
    ],
  },
  {
    id: 'railLands',
    name: 'Weites Land',
    desc: 'Eine große Insel. Eisen und Kohle im Nordwesten, Kupfer und Kalkstein im Südosten. Ohne Eisenbahn geht hier nichts.',
    level: 4,
    seed: 9150,
    map: {
      size: 96,
      ores: { iron: 4, coal: 3, copper: 4, stone: 3 },
      zones: { iron: [0, 0, 0.32, 0.32], coal: [0, 0, 0.36, 0.36], copper: [0.68, 0.68, 1, 1], stone: [0.64, 0.64, 1, 1] },
      land: 0.07,
      coast: 0.86,
      rock: 0.35,
      richness: 1.3,
    },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'constructor', 'splitter', 'merger', 'power', 'pole', 'rail', 'station'],
    par: 24,
    missions: [
      {
        name: 'Gleisbau',
        desc: 'Die Erze liegen weit auseinander. Setz einen Bahnhof an jedes Ende und zieh die Gleise dazwischen.',
        goals: [{ build: 'station', count: 2 }, { build: 'rail', count: 30 }],
        reward: { unlocks: ['train'], text: 'Zug' },
      },
      {
        name: 'Erste Fracht',
        desc: 'Setz einen Zug auf einen Bahnhof. Bänder füllen den Bahnhof von der Seite, am anderen Ende stellst du auf Entladen.',
        goals: [{ build: 'train', count: 1 }, { shipped: 80 }],
        reward: { boosts: { drill: 1.5 }, text: 'Bohrer +50 %' },
      },
      {
        name: 'Fernverkehr',
        desc: 'Eisen aus dem Nordwesten, Kupfer aus dem Südosten: Schaltkreise brauchen beides.',
        goals: [{ deliver: 'circuit', count: 20 }],
        reward: { boosts: { train: 1.5, belt: 1.5 }, text: 'Züge +50 %, Bänder +50 %' },
      },
      {
        name: 'Stahlexpress',
        desc: 'Stahl und Zahnräder für neue Strecken. Die Kohle liegt beim Eisen.',
        goals: [{ deliver: 'steel', count: 25 }, { deliver: 'gear', count: 20 }],
        reward: { boosts: { furnace: 2, constructor: 1.5 }, text: 'Öfen ×2, Konstruktor +50 %' },
      },
      {
        name: 'Güterverkehr',
        desc: 'Das ganze Land arbeitet zusammen: Schaltkreise im Minutentakt und volle Züge.',
        goals: [{ rate: 'circuit', perMin: 20 }, { shipped: 400 }],
        reward: { text: 'Das Land ist verbunden' },
      },
    ],
  },
  {
    id: 'starport',
    name: 'Sternenhafen',
    desc: 'Das Finale: eine weite Küste mit allem, was die Erde hergibt. Hier baust du das Raketensilo und schickst eine Rakete ins All.',
    level: 4,
    seed: 3141,
    map: { size: 80, ores: { iron: 5, copper: 4, coal: 4, stone: 4, oil: 4 }, land: 0.06, coast: 0.86, forest: 0.45, rock: 0.4, richness: 1.4 },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'constructor', 'splitter', 'merger', 'power', 'pole', 'pump', 'pipe', 'tank', 'refinery', 'rail', 'station', 'train'],
    par: 37,
    missions: [
      {
        name: 'Grundstein',
        desc: 'Ein Raumhafen braucht Stahl und Beton, und zwar viel. Bau die ersten Linien und gleich ein Kraftwerk dazu.',
        goals: [{ deliver: 'steel', count: 30 }, { deliver: 'concrete', count: 40 }, { powered: 4 }],
        reward: { boosts: { drill: 1.5, furnace: 2 }, text: 'Bohrer +50 %, Öfen ×2' },
      },
      {
        name: 'Hightech',
        desc: 'Öl pumpen, Kunststoff raffinieren, Prozessoren bauen. Ohne sie fliegt nichts.',
        goals: [{ deliver: 'plastic', count: 30 }, { deliver: 'processor', count: 10 }],
        reward: { unlocks: ['silo'], boosts: { constructor: 1.5 }, text: 'Raketensilo, Konstruktor +50 %' },
      },
      {
        name: 'Startrampe',
        desc: 'Das Silo braucht 3 × 3 freie Felder. Bänder von jeder Seite bringen Beton und Stahl für die erste Etappe.',
        goals: [{ build: 'silo', count: 1 }, { silo: 1 }],
        reward: { boosts: { belt: 1.6, assembler: 1.5 }, text: 'Bänder +60 %, Presse +50 %' },
      },
      {
        name: 'Die Rakete',
        desc: 'Rumpf und Bordcomputer: Stahl, Kunststoff, Zahnräder, Prozessoren und Schaltkreise ins Silo.',
        goals: [{ silo: 3 }],
        reward: { boosts: { refinery: 1.5, pump: 1.5 }, text: 'Raffinerie und Pumpen +50 %' },
      },
      {
        name: 'Countdown',
        desc: 'Treibstoff in die Tanks, dann klick das Silo an und drück auf Start.',
        goals: [{ launched: 1 }],
        reward: { text: 'Die Rakete fliegt' },
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
  let basePumped = factory.pumped;
  let baseShipped = factory.shipped;
  let baseLaunched = factory.launched;
  let reached = new Set(); // rate goals met once stay met
  let finishedAt = null;

  function progress(goal, i) {
    if (goal.deliver) return { item: goal.deliver, have: factory.delivered[goal.deliver] - base[goal.deliver], need: goal.count };
    if (goal.build) return { building: goal.build, have: factory.count(goal.build), need: goal.count };
    if (goal.oil) return { oil: true, have: Math.floor(factory.pumped - basePumped), need: goal.oil };
    if (goal.silo) return { silo: true, have: Math.min(factory.count('siloStage'), goal.silo), need: goal.silo };
    if (goal.launched) return { launched: true, have: factory.launched - baseLaunched, need: goal.launched };
    if (goal.shipped) return { shipped: true, have: factory.shipped - baseShipped, need: goal.shipped };
    if (goal.powered) return { powered: true, have: reached.has(i) ? goal.powered : factory.powered(), need: goal.powered };
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
      all.forEach((p, i) => (p.rate || p.powered) && p.have >= p.need && reached.add(i));
      if (!all.every((p) => p.have >= p.need)) return null;
      factory.research.grant(m.reward);
      index++;
      base = { ...factory.delivered };
      basePumped = factory.pumped;
      baseShipped = factory.shipped;
      baseLaunched = factory.launched;
      reached = new Set();
      if (!this.current) finishedAt = factory.time;
      return m;
    },
    save: () => ({ index, base, basePumped, baseShipped, baseLaunched, reached: [...reached], finishedAt }),
    load(data) {
      if (!data) return;
      index = Math.min(data.index ?? 0, scenario.missions.length);
      base = { ...base, ...data.base };
      basePumped = data.basePumped ?? 0;
      baseShipped = data.baseShipped ?? 0;
      baseLaunched = data.baseLaunched ?? 0;
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
