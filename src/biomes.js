// Biomes: the look of a map and its quirks. Each map picks one with `biome` in its
// map options (see world.js and scenarios.js); the free game lets the player choose.
//
//   name/icon/desc  text for the map selection and the HUD
//   frost           speed of machines without power (1 = normal)
//   storm           weather that comes back regularly:
//     name/text     shown in the HUD
//     first/every   seconds until the first storm, then between two starts
//     lasts         seconds it rages
//     effects       multipliers while it rages: drill, belt, geo (geothermal output)
//   sky             colours the day palette is tinted towards, `amount` how much
//   sea             colour of the sea
export const BIOMES = {
  meadow: {
    name: 'Grasland',
    icon: '🌿',
    desc: 'Wiesen, Wälder und Felsen. Kein Wetter, das stört.',
  },
  desert: {
    name: 'Wüste',
    icon: '🏜️',
    desc: 'Sand und Kakteen. Sandstürme bremsen die Bohrer.',
    storm: { name: 'Sandsturm', text: 'Bohrer −40 %', first: 200, every: 260, lasts: 35, effects: { drill: 0.6 } },
    sky: { top: 0x6aa2cc, horizon: 0xf0dcae, fog: 0xead6a6, amount: 0.45 },
    stormSky: 0xd8b070,
  },
  snow: {
    name: 'Schnee',
    icon: '❄️',
    desc: 'Frost: ohne Strom laufen Maschinen nur mit 60 %. Auf gefrorenen Seen kann man bauen. Schneestürme bremsen die Bänder.',
    frost: 0.6,
    storm: { name: 'Schneesturm', text: 'Bänder −40 %', first: 240, every: 300, lasts: 40, effects: { belt: 0.6 } },
    sky: { top: 0x7fa6c8, horizon: 0xe4edf2, fog: 0xdfe8ee, amount: 0.55 },
    stormSky: 0xe8eef2,
    sea: 0x2a6f8c,
  },
  volcano: {
    name: 'Vulkan',
    icon: '🌋',
    desc: 'Asche, Lava und reiche Erze. Dampfende Quellen liefern Erdwärme. Bei Ausbrüchen regnet Asche: Bohrer langsamer, Erdwärme doppelt.',
    storm: { name: 'Ausbruch', text: 'Erdwärme ×2, Bohrer −25 %', first: 260, every: 320, lasts: 30, effects: { geo: 2, drill: 0.75 } },
    sky: { top: 0x6f6a74, horizon: 0xc9a08a, fog: 0xb09486, amount: 0.5 },
    stormSky: 0x6a5048,
    sea: 0x2a6a74,
  },
};

export const biomeOf = (id) => BIOMES[id] ?? BIOMES.meadow;

const RAMP = 4; // seconds a storm takes to build up and to calm down

// Weather of a biome at simulated time `time`. Storms follow a fixed timetable, so
// a save game needs nothing extra to know when the next one comes.
//   active    the storm rages now; `left` seconds to go
//   next      seconds until the next storm starts
//   strength  0 calm … 1 full storm, eased in and out
export function weatherAt(biomeId, time) {
  const storm = biomeOf(biomeId).storm;
  if (!storm) return { storm: null, active: false, strength: 0, next: Infinity, left: 0 };
  if (time < storm.first) return { storm, active: false, strength: 0, next: storm.first - time, left: 0 };
  const phase = (time - storm.first) % storm.every;
  const active = phase < storm.lasts;
  const strength = active ? Math.min(1, phase / RAMP, (storm.lasts - phase) / RAMP) : 0;
  return { storm, active, strength, next: storm.every - phase, left: active ? storm.lasts - phase : 0 };
}

// Multiplier of one effect (drill, belt, geo) right now.
export function weatherEffect(weather, key) {
  const f = weather.storm?.effects[key];
  return f === undefined ? 1 : 1 + (f - 1) * weather.strength;
}

// Average multiplier of one effect over a long time, for the balancing estimate.
export function averageEffect(biomeId, key) {
  const storm = biomeOf(biomeId).storm;
  const f = storm?.effects[key];
  return f === undefined ? 1 : 1 + (f - 1) * (storm.lasts / storm.every);
}
