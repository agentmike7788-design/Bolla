import { ITEMS } from './factory.js';
import { SCENARIOS, loadRecords } from './scenarios.js';
import { biomeOf } from './biomes.js';

// Achievements: small goals across all games, kept in this browser. Each entry
// has a check that looks at the running game; the first time it holds, the
// achievement is earned for good.
//
//   id/icon/name/desc  key and text for the list and the toast
//   check(ctx)         ctx: { factory, scenario, missions, night, records }
//   secret             shown as ??? until earned
const made = (f, kind) => f.history.total.p[kind] ?? 0;
const madeParts = (f) => Object.entries(f.history.total.p).reduce((n, [k, v]) => (ITEMS[k] ? n + v : n), 0);
const working = (f) => {
  let n = 0;
  for (const b of f.buildings.values()) if (b.state === 'work') n++;
  return n;
};
// A mission map of this biome finished, in this game or any earlier one.
const finishedBiome = (ctx, biome) =>
  SCENARIOS.some((s) => s.map?.biome === biome && ctx.records[s.id]) || (ctx.missions?.finishedAt != null && ctx.factory.biome === biome);
const missionMaps = SCENARIOS.filter((s) => !s.free);

export const ACHIEVEMENTS = [
  { id: 'firstDrill', icon: '⛏️', name: 'Erster Spatenstich', desc: 'Setz deinen ersten Bohrer.', check: ({ factory }) => factory.count('drill') >= 1 },
  { id: 'firstIngot', icon: '🔥', name: 'Feuer und Flamme', desc: 'Schmilz deinen ersten Barren.', check: ({ factory }) => made(factory, 'ironIngot') + made(factory, 'copperIngot') >= 1 },
  { id: 'belts', icon: '🐍', name: 'Bandwurm', desc: '200 Förderbänder in einer Fabrik.', check: ({ factory }) => factory.count('belt') >= 200 },
  { id: 'furnaces', icon: '🏭', name: 'Hochofenstraße', desc: '12 Schmelzöfen in einer Fabrik.', check: ({ factory }) => factory.count('furnace') >= 12 },
  { id: 'gears', icon: '⚙️', name: 'Zahnrädchen', desc: 'Stell 250 Zahnräder her.', check: ({ factory }) => made(factory, 'gear') >= 250 },
  { id: 'circuits', icon: '🟩', name: 'Schaltzentrale', desc: 'Stell 500 Schaltkreise her.', check: ({ factory }) => made(factory, 'circuit') >= 500 },
  { id: 'power', icon: '💡', name: 'Es werde Licht', desc: 'Lass eine Maschine mit Strom laufen.', check: ({ factory }) => factory.powered() >= 1 },
  { id: 'bigGrid', icon: '⚡', name: 'Kraftwerkspark', desc: '100 MW Leistung in deinen Netzen.', check: ({ factory }) => factory.powerSummary().capacity >= 100 },
  { id: 'geo', icon: '♨️', name: 'Erdwärme', desc: 'Drei Erdwärmekraftwerke liefern Strom.', check: ({ factory }) => factory.count('geo') >= 3 && factory.powerSummary().geo >= 3 },
  { id: 'oil', icon: '🛢️', name: 'Schwarzes Gold', desc: 'Pumpe 1.000 Einheiten Öl.', check: ({ factory }) => factory.pumped >= 1000 },
  { id: 'plastic', icon: '🧴', name: 'Plastikwelt', desc: 'Stell 200 Kunststoff her.', check: ({ factory }) => made(factory, 'plastic') >= 200 },
  { id: 'processors', icon: '🧠', name: 'Rechenzentrum', desc: 'Stell 100 Prozessoren her.', check: ({ factory }) => made(factory, 'processor') >= 100 },
  { id: 'trains', icon: '🚂', name: 'Volldampf', desc: 'Züge entladen 1.000 Teile.', check: ({ factory }) => factory.shipped >= 1000 },
  { id: 'signals', icon: '🚦', name: 'Stellwerk', desc: '10 Signale und drei Züge in einer Fabrik.', check: ({ factory }) => factory.count('signal') >= 10 && factory.count('train') >= 3 },
  { id: 'drones', icon: '🚁', name: 'Luftpost', desc: 'Drohnen liefern 1.000 Teile.', check: ({ factory }) => factory.flown >= 1000 },
  { id: 'rocket', icon: '🚀', name: 'Abheben', desc: 'Starte eine Rakete ins All.', check: ({ factory }) => factory.launched >= 1 },
  { id: 'rockets', icon: '🛰️', name: 'Raumfahrtprogramm', desc: 'Starte drei Raketen aus einer Fabrik.', check: ({ factory }) => factory.launched >= 3 },
  { id: 'mega', icon: '🏙️', name: 'Industriegigant', desc: '1.000 Gebäude in einer Fabrik.', check: ({ factory }) => factory.buildings.size >= 1000 },
  { id: 'mass', icon: '📦', name: 'Massenware', desc: 'Stell in einer Fabrik 25.000 Teile her.', check: ({ factory }) => madeParts(factory) >= 25000 },
  { id: 'night', icon: '🌙', name: 'Nachtschicht', desc: '40 Maschinen arbeiten mitten in der Nacht.', check: ({ factory, night }) => night > 0.9 && working(factory) >= 40 },
  { id: 'storm', icon: '🌪️', name: 'Sturmerprobt', desc: 'Liefere während eines Sturms 100 Teile ins Lager.', check: ({ stormDelivered }) => stormDelivered >= 100 },
  { id: 'desert', icon: '🏜️', name: 'Wüstenfuchs', desc: `Schaff eine Karte in der ${biomeOf('desert').name}.`, check: (ctx) => finishedBiome(ctx, 'desert') },
  { id: 'snow', icon: '❄️', name: 'Eisbrecher', desc: 'Schaff eine Schneekarte.', check: (ctx) => finishedBiome(ctx, 'snow') },
  { id: 'volcano', icon: '🌋', name: 'Feuerläufer', desc: 'Schaff eine Vulkankarte.', check: (ctx) => finishedBiome(ctx, 'volcano') },
  { id: 'stars', icon: '⭐', name: 'Sternensammler', desc: 'Hol dir auf fünf Karten drei Sterne.', check: ({ records }) => Object.values(records).filter((r) => r.stars >= 3).length >= 5 },
  { id: 'allMaps', icon: '🗺️', name: 'Weltenbummler', desc: 'Schaff jede Missionskarte.', check: ({ records }) => missionMaps.every((s) => records[s.id]) },
  { id: 'speed', icon: '⏱️', name: 'Blitzstart', desc: 'Schaff eine Karte in der Hälfte der Zeit für drei Sterne.', secret: true, check: ({ scenario, missions }) => missions?.finishedAt != null && missions.finishedAt <= scenario.par * 30 },
];

const KEY = 'bolla.achievements';

// Earned achievements: id -> time earned.
export function loadAchievements() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) ?? {};
  } catch {
    return {};
  }
}

// Watches the running game. `onUnlock(achievement)` fires once per new one.
export function createAchievements({ onUnlock }) {
  let earned = loadAchievements();
  let storm = null; // deliveries counted while a storm rages
  let factorySeen = null;

  const totalDelivered = (f) => Object.values(f.delivered).reduce((a, b) => a + b, 0);

  function check(game) {
    const { factory } = game;
    if (factory !== factorySeen) {
      factorySeen = factory;
      storm = null;
    }
    // Deliveries since the current storm started.
    if (factory.weather.active) storm ??= totalDelivered(factory);
    else storm = null;
    const ctx = { ...game, records: loadRecords(), stormDelivered: storm === null ? 0 : totalDelivered(factory) - storm };
    for (const a of ACHIEVEMENTS) {
      if (earned[a.id]) continue;
      let ok = false;
      try {
        ok = a.check(ctx);
      } catch {
        ok = false;
      }
      if (!ok) continue;
      earned[a.id] = Date.now();
      try {
        localStorage.setItem(KEY, JSON.stringify(earned));
      } catch {
        // Storage blocked: earned for this session only.
      }
      onUnlock(a);
    }
  }

  return {
    check,
    get earned() {
      return earned;
    },
    reload() {
      earned = loadAchievements();
    },
  };
}
