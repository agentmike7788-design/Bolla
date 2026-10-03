// Maps to play. The free game has a random map with every ore and the research tree;
// every other map has its own landscape, only some ores and a chain of missions.
//
// To add a map, append an entry:
//   id/name/desc  key and text for the map selection
//   level         difficulty 1..4 (dots on the card)
//   seed          fixed seed, so everyone plays the same map
//   map           landscape and ores, see DEFAULT_MAP in world.js; `biome` picks
//                 look, weather and quirks (see biomes.js)
//   start         buildings available from the beginning
//   enemies       creature nests on the map, see ENEMY_MODES in enemies.js
//   grace         seconds before the first attack, instead of the mode's
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
//                   { flown: count }            drones deliver that many more parts
//                   { kills: count }            defeat that many more creatures
//                   { nests: count }            destroy that many more nests
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
    map: { ores: { copper: 5, stone: 3 }, desert: true, biome: 'desert', forest: 0.74, rock: 0.4, land: 0.04 },
    start: ['drill', 'belt', 'storage', 'furnace'],
    par: 13,
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
    id: 'frostFjord',
    name: 'Frostfjord',
    desc: 'Schnee, gefrorene Seen und klirrende Kälte. Ohne Strom laufen die Maschinen nur mit 60 %, und Schneestürme bremsen die Bänder.',
    level: 3,
    seed: 7311,
    map: { size: 72, biome: 'snow', ores: { iron: 5, copper: 4, coal: 4, stone: 2 }, land: 0.03, coast: 0.8, forest: 0.6, rock: 0.45, richness: 1.3 },
    start: ['drill', 'belt', 'storage', 'furnace'],
    par: 17,
    missions: [
      {
        name: 'Eisige Ankunft',
        desc: 'Der Frost bremst alles ohne Strom. Grab Kohle und schmilz die ersten Eisenbarren.',
        goals: [{ deliver: 'ironIngot', count: 25 }, { deliver: 'coal', count: 20 }],
        reward: { unlocks: ['power', 'pole', 'assembler'], text: 'Kohlekraftwerk, Strommasten, Presse' },
      },
      {
        name: 'Warme Hallen',
        desc: 'Kohle ins Kraftwerk, Masten zu den Maschinen. Am Netz ist der Frost vergessen und sie laufen doppelt so schnell.',
        goals: [{ build: 'power', count: 1 }, { powered: 4 }],
        reward: { unlocks: ['constructor', 'splitter', 'merger'], boosts: { drill: 1.5 }, text: 'Konstruktor, Verteiler, Zusammenführer, Bohrer +50 %' },
      },
      {
        name: 'Über das Eis',
        desc: 'Die gefrorenen Seen tragen ganze Fabriken. Platten und Draht für die Station.',
        goals: [{ deliver: 'ironPlate', count: 40 }, { deliver: 'wire', count: 40 }],
        reward: { boosts: { belt: 1.5, furnace: 1.5 }, text: 'Bänder +50 %, Öfen +50 %' },
      },
      {
        name: 'Polarlicht',
        desc: 'Schaltkreise und Stahl für die Funkstation. Plane Reserve ein, im Schneesturm laufen die Bänder langsamer.',
        goals: [{ deliver: 'circuit', count: 25 }, { deliver: 'steel', count: 15 }],
        reward: { boosts: { power: 1.5, constructor: 1.5 }, text: 'Kraftwerke +50 %, Konstruktor +50 %' },
      },
      {
        name: 'Polarstation',
        desc: 'Die Station ruft: Schaltkreise und Stahl im Minutentakt, Sturm hin oder her.',
        goals: [{ rate: 'circuit', perMin: 15 }, { rate: 'steel', perMin: 10 }],
        reward: { text: 'Die Station leuchtet im Eis' },
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
        reward: { unlocks: ['signal'], boosts: { train: 1.5, belt: 1.5 }, text: 'Signale, Züge +50 %, Bänder +50 %' },
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
    id: 'hub',
    name: 'Drehkreuz',
    desc: 'Vier Erze in vier Ecken, die Fabrik in der Mitte. Viele Züge brauchen Signale, und für die letzten Meter kommen die Drohnen.',
    level: 4,
    seed: 5150,
    map: {
      size: 88,
      ores: { iron: 3, copper: 3, coal: 3, stone: 3 },
      zones: { iron: [0, 0, 0.3, 0.3], copper: [0.7, 0, 1, 0.3], coal: [0, 0.7, 0.3, 1], stone: [0.7, 0.7, 1, 1] },
      land: 0.08,
      coast: 0.88,
      rock: 0.35,
      forest: 0.55,
      richness: 1.4,
    },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'constructor', 'splitter', 'merger', 'power', 'pole', 'rail', 'station', 'train'],
    par: 24,
    missions: [
      {
        name: 'Vier Ecken',
        desc: 'Bahnhöfe an die Erze, ein Bahnhof in der Mitte und zwei Züge auf die Gleise.',
        goals: [{ build: 'station', count: 3 }, { build: 'rail', count: 60 }, { build: 'train', count: 2 }],
        reward: { unlocks: ['signal'], text: 'Signale' },
      },
      {
        name: 'Grüne Welle',
        desc: 'Zwei Züge auf einer Strecke stehen sich im Weg. Signale teilen sie in Blöcke, Kettensignale gehören vor jede Weiche.',
        goals: [{ build: 'signal', count: 4 }, { shipped: 240 }],
        reward: { unlocks: ['dronePort', 'provider', 'requester'], boosts: { train: 1.5 }, text: 'Drohnenhafen, Angebots- und Anfragekisten, Züge +50 %' },
      },
      {
        name: 'Luftbrücke',
        desc: 'Bänder in eine Angebotskiste, eine Anfragekiste vor die Maschine, ein Drohnenhafen mit Strom dazwischen.',
        goals: [{ build: 'dronePort', count: 1 }, { flown: 100 }],
        reward: { boosts: { drone: 1.5, drill: 1.5 }, text: 'Drohnen +50 %, Bohrer +50 %' },
      },
      {
        name: 'Schaltzentrale',
        desc: 'Platten aus dem Nordwesten, Draht aus dem Nordosten: Schaltkreise für das ganze Netz.',
        goals: [{ deliver: 'circuit', count: 30 }, { flown: 300 }],
        reward: { boosts: { furnace: 2, constructor: 1.5, belt: 1.5 }, text: 'Öfen ×2, Konstruktor +50 %, Bänder +50 %' },
      },
      {
        name: 'Drehkreuz',
        desc: 'Das ganze Netz läuft: Schaltkreise im Minutentakt, Züge und Drohnen in Bewegung.',
        goals: [{ rate: 'circuit', perMin: 20 }, { shipped: 400 }],
        reward: { text: 'Alle Signale auf Grün' },
      },
    ],
  },
  {
    id: 'volcano',
    name: 'Glutkessel',
    desc: 'Eine Vulkaninsel mit reichen Erzen. Dampfende Quellen liefern Strom ohne Kohle, und wenn der Berg ausbricht, regnet es Asche.',
    level: 4,
    seed: 6661,
    map: { size: 76, biome: 'volcano', vents: 9, ores: { iron: 5, copper: 4, coal: 4, stone: 4 }, land: 0.02, coast: 0.8, forest: 0.6, rock: 0.35, richness: 1.7 },
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'pole'],
    par: 21,
    missions: [
      {
        name: 'Heiße Erde',
        desc: 'Der Boden ist reich. Schmilz Eisen und Kupfer, solange der Berg ruhig ist. Lava und Vulkan kann man nicht bebauen.',
        goals: [{ deliver: 'ironIngot', count: 30 }, { deliver: 'copperIngot', count: 30 }],
        reward: { unlocks: ['geo', 'constructor'], text: 'Erdwärmekraftwerk, Konstruktor' },
      },
      {
        name: 'Erdwärme',
        desc: 'Setz Erdwärmekraftwerke auf die dampfenden Quellen und Masten zu den Maschinen. Kohle braucht hier niemand.',
        goals: [{ build: 'geo', count: 2 }, { powered: 6 }],
        reward: { boosts: { drill: 1.5 }, text: 'Bohrer +50 %' },
      },
      {
        name: 'Vulkanstahl',
        desc: 'Stahl und Beton für Hallen, die einen Ausbruch aushalten.',
        goals: [{ deliver: 'steel', count: 30 }, { deliver: 'concrete', count: 30 }],
        reward: { boosts: { furnace: 2, constructor: 1.5 }, text: 'Öfen ×2, Konstruktor +50 %' },
      },
      {
        name: 'Glutschaltkreise',
        desc: 'Schaltkreise und Zahnräder. Bei einem Ausbruch liefert die Erdwärme doppelt, nutze den Schub.',
        goals: [{ deliver: 'circuit', count: 30 }, { deliver: 'gear', count: 30 }],
        reward: { boosts: { belt: 1.6, power: 1.5 }, text: 'Bänder +60 %, Kraftwerke +50 %' },
      },
      {
        name: 'Feuerberg',
        desc: 'Der Vulkan arbeitet für dich: Schaltkreise und Stahl im Minutentakt.',
        goals: [{ rate: 'circuit', perMin: 25 }, { rate: 'steel', perMin: 20 }],
        reward: { text: 'Der Berg glüht, die Fabrik auch' },
      },
    ],
  },
  {
    id: 'bugLands',
    name: 'Käferland',
    desc: 'Grüne Hügel, reiche Erze und überall Nester. Jeder Bohrer macht Smog, und Smog lockt die Krabbler an. Mauern und Türme bauen, bevor die erste Welle kommt.',
    level: 3,
    seed: 1717,
    map: { size: 72, ores: { iron: 5, copper: 4, coal: 3, stone: 3 }, land: 0.05, coast: 0.82, forest: 0.55, rock: 0.45, richness: 1.4 },
    enemies: 'normal',
    grace: 420,
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'splitter', 'merger', 'wall', 'turret'],
    par: 33,
    missions: [
      {
        name: 'Brückenkopf',
        desc: 'Erz abbauen, Platten pressen, Kupfer schmelzen. Die Nester schlafen noch, aber nicht mehr lange: oben rechts steht, wann.',
        goals: [{ deliver: 'ironPlate', count: 30 }, { deliver: 'copperIngot', count: 30 }],
        reward: { unlocks: ['constructor'], text: 'Konstruktor, der auch Munition baut' },
      },
      {
        name: 'Scharf geladen',
        desc: 'Der Konstruktor macht aus Eisenplatte und Kupferbarren Munition. Stell Geschütztürme an den Rand der Fabrik und führ ein Munitionsband an ihnen vorbei. Etwas Vorrat im Lager schadet nicht.',
        goals: [{ build: 'turret', count: 3 }, { deliver: 'ammo', count: 20 }],
        reward: { unlocks: ['power', 'pole'], boosts: { drill: 1.5 }, text: 'Kohlekraftwerk, Strommasten, Bohrer +50 %' },
      },
      {
        name: 'Die Welle',
        desc: 'Der Smog hat sie geweckt. Halte stand, bis 30 Gegner gefallen sind. Mauern vor den Türmen halten sie auf, zerstörte Gebäude baust du im Gegner-Fenster wieder auf.',
        goals: [{ kills: 30 }],
        reward: { unlocks: ['laser'], boosts: { weapons: 1.5 }, text: 'Laserturm, Türme +50 % Schaden' },
      },
      {
        name: 'Gegenangriff',
        desc: 'Rück mit Mauern und Türmen an die Nester heran, bis sie in Reichweite sind. Unter Beschuss schicken sie Verteidiger. Drei Nester müssen weg.',
        goals: [{ nests: 3 }],
        reward: { text: 'Das Käferland ist sicher' },
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
    start: ['drill', 'belt', 'storage', 'furnace', 'assembler', 'constructor', 'splitter', 'merger', 'power', 'pole', 'pump', 'pipe', 'tank', 'refinery', 'rail', 'station', 'train', 'signal', 'dronePort', 'provider', 'requester'],
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
  let baseFlown = factory.flown;
  let baseKills = factory.enemies.killed;
  let baseNests = factory.enemies.nestsKilled;
  let reached = new Set(); // rate goals met once stay met
  let finishedAt = null;

  function progress(goal, i) {
    if (goal.deliver) return { item: goal.deliver, have: factory.delivered[goal.deliver] - base[goal.deliver], need: goal.count };
    if (goal.build) return { building: goal.build, have: factory.count(goal.build), need: goal.count };
    if (goal.oil) return { oil: true, have: Math.floor(factory.pumped - basePumped), need: goal.oil };
    if (goal.silo) return { silo: true, have: Math.min(factory.count('siloStage'), goal.silo), need: goal.silo };
    if (goal.launched) return { launched: true, have: factory.launched - baseLaunched, need: goal.launched };
    if (goal.shipped) return { shipped: true, have: factory.shipped - baseShipped, need: goal.shipped };
    if (goal.flown) return { flown: true, have: factory.flown - baseFlown, need: goal.flown };
    if (goal.kills) return { kills: true, have: factory.enemies.killed - baseKills, need: goal.kills };
    if (goal.nests) return { nests: true, have: factory.enemies.nestsKilled - baseNests, need: goal.nests };
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
      baseFlown = factory.flown;
      baseKills = factory.enemies.killed;
      baseNests = factory.enemies.nestsKilled;
      reached = new Set();
      if (!this.current) finishedAt = factory.time;
      return m;
    },
    save: () => ({ index, base, basePumped, baseShipped, baseLaunched, baseFlown, baseKills, baseNests, reached: [...reached], finishedAt }),
    load(data) {
      if (!data) return;
      index = Math.min(data.index ?? 0, scenario.missions.length);
      base = { ...base, ...data.base };
      basePumped = data.basePumped ?? 0;
      baseShipped = data.baseShipped ?? 0;
      baseLaunched = data.baseLaunched ?? 0;
      baseFlown = data.baseFlown ?? 0;
      baseKills = data.baseKills ?? 0;
      baseNests = data.baseNests ?? 0;
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
