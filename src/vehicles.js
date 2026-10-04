// Vehicles: a jeep and a tank that roam freely over the land instead of
// standing on a tile. The player sets one down like a building, gets in and
// drives it with WASD while the camera follows.
//
// Both carry a machine gun that fires boxes of ammunition at creatures in reach
// on its own; the tank adds a cannon that lobs shells at nests and big beetles.
// Parked next to a storage, a vehicle loads ammunition and shells from it.
// Driving fast into creatures runs them over, the tank flattens trees on its
// way. Creatures that get shot by a vehicle, or that pass close to one on an
// attack, go for it instead of the factory (see `hunt` in enemies.js). A vehicle
// mends itself after a while out of the fight; at zero hit points it is gone.
//
// Positions are in tiles like the creatures: (x, z) floats, heading in radians
// with the forward direction (sin h, cos h).
import { TERRAIN } from './world.js';
import { isSolid } from './enemies.js';

// speed/back: tiles per second forwards and backwards; accel per second; turn:
// radians per second at speed; radius: how wide it is for collisions.
// gun: the machine gun, `per` shots in one box of ammo, `store` boxes it holds.
// cannon (tank): `per` shots from one shell, damage in `radius` tiles round the hit.
export const VEHICLES = {
  car: {
    name: 'Geländewagen',
    hp: 320,
    armor: 0,
    speed: 8,
    back: 3,
    accel: 6,
    turn: 2.3,
    pivot: false,
    radius: 0.42,
    ram: 5,
    gun: { range: 6.5, rate: 6, damage: 5, per: 10, store: 10 },
  },
  panzer: {
    name: 'Panzer',
    hp: 1600,
    armor: 4,
    speed: 4.2,
    back: 2.2,
    accel: 3.2,
    turn: 1.3,
    pivot: true,
    radius: 0.62,
    ram: 14,
    crush: true,
    gun: { range: 7, rate: 7, damage: 6, per: 10, store: 20 },
    cannon: { range: 11, reload: 1.8, damage: 80, radius: 1.6, per: 3, store: 10, flight: 20 },
  },
};
export const isVehicleType = (type) => !!VEHICLES[type];

export const MAX_VEHICLES = 12;
const FOREST = new Set(['forest', 'taiga', 'burnt']);
const FOREST_SLOW = 0.55; // a jeep in the woods; the tank pushes through at 0.85
const LOAD_REACH = 3.5; // tiles to a storage for loading
const REPAIR_AFTER = 8; // seconds without damage before a vehicle mends itself
const REPAIR_RATE = 0.04; // share of its hit points per second
const AIM_TURN = { car: 9, panzer: 2.6 }; // radians per second the gun turns
const RAM_SPEED = 1.6; // tiles per second before running something over hurts it

export function createVehicles({ world, buildings, at, research, stored, consume, enemies }) {
  const size = world.size;
  let list = [];
  let shots = []; // tank shells in the air
  let nextId = 1;
  let driver = null; // id of the vehicle the player drives
  const input = { throttle: 0, steer: 0, brake: false };
  const flattened = new Set(); // tiles whose trees a tank ran over
  const fresh = []; // tiles flattened since the view last looked
  const events = []; // lost vehicles and the like, for the HUD
  let driven = 0; // tiles ever driven
  let crushed = 0; // creatures ever run over
  let kills = 0; // creatures and nests vehicles destroyed
  let loadTimer = 0;
  const memo = new WeakMap(); // vehicle -> { target, cannonTarget, cool, ccool, scan }
  const rammed = new WeakMap(); // creature -> time it was last run over
  let clock = 0;

  const tileAt = (x, z) => {
    const ix = Math.round(x);
    const iz = Math.round(z);
    return ix < 0 || iz < 0 || ix >= size || iz >= size ? null : world.tiles[iz * size + ix];
  };
  const byId = (id) => list.find((v) => v.id === id) ?? null;
  const unlocked = (kind) => research.unlocked.has(kind);
  const weapons = () => research.stats.weapons ?? 1;

  // Land without anything solid on it; belts, rails and pipes' flat bits are fine.
  function free(x, z, r) {
    for (const [dx, dz] of [[0, 0], [r, 0], [-r, 0], [0, r], [0, -r], [r * 0.7, r * 0.7], [-r * 0.7, r * 0.7], [r * 0.7, -r * 0.7], [-r * 0.7, -r * 0.7]]) {
      const t = tileAt(x + dx, z + dz);
      if (!t || !TERRAIN[t.terrain].buildable) return false;
      if (isSolid(at(t.x, t.z))) return false;
    }
    return true;
  }

  function canAdd(kind, tile) {
    if (!tile) return { ok: false, reason: '' };
    if (!unlocked(kind)) return { ok: false, reason: 'Noch nicht freigeschaltet' };
    if (list.length >= MAX_VEHICLES) return { ok: false, reason: `Höchstens ${MAX_VEHICLES} Fahrzeuge` };
    if (!TERRAIN[tile.terrain].buildable) return { ok: false, reason: 'Nur an Land' };
    if (isSolid(at(tile.x, tile.z))) return { ok: false, reason: 'Hier steht schon etwas' };
    if (enemies.blocks(tile)) return { ok: false, reason: 'Zu nah an einem Nest' };
    if (!free(tile.x, tile.z, VEHICLES[kind].radius * 0.8)) return { ok: false, reason: 'Zu eng hier' };
    if (list.some((v) => Math.hypot(v.x - tile.x, v.z - tile.z) < 1.3)) return { ok: false, reason: 'Hier steht schon ein Fahrzeug' };
    return { ok: true, reason: '' };
  }

  function add(kind, tile, heading = 0) {
    if (!canAdd(kind, tile).ok) return null;
    const spec = VEHICLES[kind];
    const n = list.filter((v) => v.kind === kind).length + 1;
    const v = { id: nextId++, vehicle: true, kind, name: `${spec.name} ${n}`, x: tile.x, z: tile.z, heading, speed: 0, hp: spec.hp, aim: heading, ammo: 0, shots: 0, shells: 0, rounds: 0, odo: 0, kills: 0 };
    list.push(v);
    return v;
  }

  function remove(v) {
    list = list.filter((o) => o !== v);
    if (driver === v.id) driver = null;
  }

  // The vehicle at a spot on the map, or null.
  function near(x, z, reach = 0.8) {
    let best = null;
    let bestD = Infinity;
    for (const v of list) {
      const d = Math.hypot(v.x - x, v.z - z) - VEHICLES[v.kind].radius;
      if (d < reach && d < bestD) {
        bestD = d;
        best = v;
      }
    }
    return best;
  }

  function hurt(v, damage) {
    if (v.dead) return;
    v.hp -= Math.max(1, damage - VEHICLES[v.kind].armor);
    v.hitAt = clock;
    if (v.hp > 0) return;
    v.dead = true;
    enemies.fx.push({ type: 'boom', x: v.x, z: v.z, big: v.kind === 'panzer' });
    events.push({ type: 'lost', vehicle: v });
    remove(v);
  }

  // --- Driving ------------------------------------------------------------------

  function drive(v, dt) {
    const spec = VEHICLES[v.kind];
    const me = v.id === driver;
    const throttle = me ? input.throttle : 0;
    const steer = me ? input.steer : 0;
    const brake = !me || input.brake;
    const ground = tileAt(v.x, v.z);
    const top = spec.speed * (FOREST.has(ground?.terrain) ? (spec.crush ? 0.85 : FOREST_SLOW) : 1);
    const want = throttle > 0 ? top * throttle : throttle < 0 ? -spec.back * -throttle : 0;
    // Brakes and turning round bite harder than the engine pulls.
    let rate = spec.accel;
    if (brake || (want !== 0 && Math.sign(want) !== Math.sign(v.speed) && Math.abs(v.speed) > 0.2)) rate = spec.accel * 2.4;
    else if (want === 0) rate = spec.accel * 0.7;
    const target = brake && throttle === 0 ? 0 : want;
    const diff = target - v.speed;
    v.speed += Math.sign(diff) * Math.min(Math.abs(diff), rate * dt);
    // Wheels steer only while rolling; tracks turn on the spot.
    const grip = spec.pivot ? 1 : Math.min(1, Math.abs(v.speed) / 2) * Math.sign(v.speed || 1);
    v.heading += steer * spec.turn * dt * grip;
    if (Math.abs(v.speed) < 1e-3) {
      v.speed = 0;
      return;
    }
    const nx = v.x + Math.sin(v.heading) * v.speed * dt;
    const nz = v.z + Math.cos(v.heading) * v.speed * dt;
    // Bodies are drawn wider than they collide, so a tank fits down a one-tile lane.
    const r = Math.min(spec.radius, 0.45);
    let moved = true;
    if (free(nx, nz, r)) {
      v.x = nx;
      v.z = nz;
    } else if (free(nx, v.z, r)) {
      v.x = nx;
      v.speed *= 1 - 2 * dt;
    } else if (free(v.x, nz, r)) {
      v.z = nz;
      v.speed *= 1 - 2 * dt;
    } else {
      // Hit a wall: bounce back a little, hard knocks hurt.
      if (Math.abs(v.speed) > 4) {
        hurt(v, Math.abs(v.speed) * 4);
        enemies.fx.push({ type: 'bump', x: v.x + Math.sin(v.heading) * r, z: v.z + Math.cos(v.heading) * r });
      }
      v.speed *= -0.2;
      moved = false;
    }
    if (!moved) return;
    const step = Math.abs(v.speed) * dt;
    v.odo += step;
    driven += step;
    // A tank flattens the trees and bushes it drives over.
    if (spec.crush) {
      const t = tileAt(v.x, v.z);
      const i = t && t.z * size + t.x;
      if (t && !flattened.has(i)) {
        flattened.add(i);
        fresh.push(i);
      }
    }
    // Running creatures over.
    if (Math.abs(v.speed) > RAM_SPEED && enemies.active) {
      for (const c of enemies.creatures) {
        if (c.dead || Math.hypot(c.x - v.x, c.z - v.z) > spec.radius + 0.35) continue;
        if (clock - (rammed.get(c) ?? -9) < 0.5) continue;
        rammed.set(c, clock);
        enemies.hurtCreature(c, spec.ram * Math.abs(v.speed), v);
        if (c.dead) {
          crushed++;
          kills++;
          v.kills++;
        }
        v.speed *= spec.crush ? 0.97 : 0.85;
      }
    }
  }

  // --- Weapons ------------------------------------------------------------------

  // Machine gun at the nearest creature; a vehicle someone drives also shoots nests.
  function shoot(v, dt) {
    const spec = VEHICLES[v.kind];
    let s = memo.get(v);
    if (!s) memo.set(v, (s = { target: null, big: null, cool: 0, ccool: 0, scan: Math.random() * 0.2 }));
    s.cool -= dt;
    s.ccool -= dt;
    s.scan -= dt;
    const me = v.id === driver;
    const dist = (o) => Math.hypot(o.x - v.x, o.z - v.z);
    const gun = spec.gun;
    if (s.target && (s.target.dead || dist(s.target) > gun.range + (s.target.kind ? 0 : 1.2))) s.target = null;
    if (s.big && (s.big.dead || dist(s.big) > spec.cannon.range + 1.2)) s.big = null;
    if (s.scan <= 0) {
      s.scan = 0.2;
      if (!s.target) {
        let bestD = gun.range;
        for (const c of enemies.creatures) {
          const d = dist(c);
          if (!c.dead && d < bestD) {
            bestD = d;
            s.target = c;
          }
        }
        if (!s.target && me) for (const n of enemies.nests) if (!n.dead && dist(n) < gun.range + 1.2) s.target = n;
      }
      // The cannon: nests first, then the toughest beetle in reach.
      if (spec.cannon && !s.big) {
        if (me) for (const n of enemies.nests) if (!n.dead && dist(n) < spec.cannon.range + 1.2) s.big = n;
        if (!s.big) {
          let most = 60;
          for (const c of enemies.creatures) if (!c.dead && c.hp > most && dist(c) < spec.cannon.range) {
            most = c.hp;
            s.big = c;
          }
        }
      }
    }
    // The turret turns towards what the cannon wants, else the machine gun.
    const look = s.big ?? s.target;
    if (look) {
      const want = Math.atan2(look.x - v.x, look.z - v.z);
      let diff = ((want - v.aim + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      const turn = Math.min(Math.abs(diff), AIM_TURN[v.kind] * dt) * Math.sign(diff);
      v.aim += turn;
      diff -= turn;
      if (s.big && Math.abs(diff) < 0.08 && s.ccool <= 0 && (v.rounds || v.shells)) {
        s.ccool = spec.cannon.reload;
        if (!v.rounds) {
          v.shells--;
          v.rounds = spec.cannon.per;
        }
        v.rounds--;
        const d = dist(s.big);
        const spread = 0.15 + d * 0.02;
        shots.push({ x: v.x, z: v.z, x2: s.big.x + (Math.random() - 0.5) * spread, z2: s.big.z + (Math.random() - 0.5) * spread, t: 0, dur: d / spec.cannon.flight, from: v.id });
        enemies.fx.push({ type: 'tankFire', x: v.x, z: v.z, aim: v.aim });
        v.recoil = 1;
      }
    } else {
      // Nothing to shoot: the gun drifts back to the front.
      let diff = ((v.heading - v.aim + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      v.aim += Math.min(Math.abs(diff), AIM_TURN[v.kind] * 0.4 * dt) * Math.sign(diff);
    }
    // The machine gun swivels freely on the jeep, on the tank it rides with the turret.
    const t = s.target;
    if (!t || s.cool > 0 || (!v.shots && !v.ammo)) return;
    if (v.kind === 'car') {
      const want = Math.atan2(t.x - v.x, t.z - v.z);
      const diff = ((want - v.aim + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
      if (Math.abs(diff) > 0.3) return;
    }
    s.cool = 1 / gun.rate;
    if (!v.shots) {
      v.ammo--;
      v.shots = gun.per;
    }
    v.shots--;
    enemies.fx.push({ type: 'bullet', x: v.x, z: v.z, x2: t.x, z2: t.z, from: { aim: Math.atan2(-(t.x - v.x), -(t.z - v.z)) }, vehicle: true });
    hit(v, t, gun.damage * weapons());
  }

  function hit(v, target, damage) {
    const wasDead = target.dead;
    if (target.kind) enemies.hurtCreature(target, damage, v);
    else enemies.hurtNest(target, damage, v);
    if (!wasDead && target.dead) {
      kills++;
      v.kills++;
    }
  }

  // Tank shells land: a blast that hurts nests and creatures around.
  function tickShots(dt) {
    for (const s of shots) {
      s.t += dt;
      if (s.t < s.dur) continue;
      s.done = true;
      const v = byId(s.from) ?? { id: s.from, x: s.x, z: s.z, kills: 0, vehicle: true };
      const spec = VEHICLES.panzer.cannon;
      const damage = spec.damage * weapons();
      for (const n of enemies.nests) {
        const d = Math.hypot(n.x - s.x2, n.z - s.z2);
        if (!n.dead && d < spec.radius + 1) hit(v, n, damage * (1 - (0.4 * d) / (spec.radius + 1)));
      }
      for (const c of enemies.creatures) {
        const d = Math.hypot(c.x - s.x2, c.z - s.z2);
        if (!c.dead && d < spec.radius) hit(v, c, damage * (1 - (0.6 * d) / spec.radius));
      }
      enemies.fx.push({ type: 'shellHit', x: s.x2, z: s.z2, small: true });
    }
    if (shots.some((s) => s.done)) shots = shots.filter((s) => !s.done);
  }

  // Parked by a storage, vehicles fill up with ammunition and shells from it.
  function reload() {
    const stores = [];
    for (const b of buildings.values()) if (b.type === 'storage') stores.push(b);
    if (!stores.length) return;
    for (const v of list) {
      if (Math.abs(v.speed) > 0.5 || !stores.some((b) => Math.hypot(b.tile.x - v.x, b.tile.z - v.z) <= LOAD_REACH)) continue;
      const spec = VEHICLES[v.kind];
      const ammo = Math.min(spec.gun.store - v.ammo, stored.ammo ?? 0);
      if (ammo > 0) {
        v.ammo += ammo;
        consume('ammo', ammo);
      }
      if (spec.cannon) {
        const shells = Math.min(spec.cannon.store - v.shells, stored.shell ?? 0);
        if (shells > 0) {
          v.shells += shells;
          consume('shell', shells);
        }
      }
    }
  }
  function tick(dt) {
    clock += dt;
    for (const v of list) drive(v, dt);
    if (enemies.active) {
      for (const v of list) shoot(v, dt);
      if (shots.length) tickShots(dt);
    }
    for (const v of list) {
      if (v.recoil) v.recoil = Math.max(0, v.recoil - dt * 3);
      // Mending after a while without hits.
      const max = VEHICLES[v.kind].hp;
      if (v.hp < max && clock - (v.hitAt ?? -99) > REPAIR_AFTER) v.hp = Math.min(max, v.hp + max * REPAIR_RATE * dt);
    }
    loadTimer += dt;
    if (loadTimer >= 1) {
      loadTimer = 0;
      reload();
    }
  }

  function save() {
    return {
      nextId,
      driven: Math.round(driven),
      crushed,
      kills,
      flattened: [...flattened],
      list: list.map(({ dead, recoil, hitAt, ...v }) => ({ ...v, x: Math.round(v.x * 100) / 100, z: Math.round(v.z * 100) / 100, speed: 0 })),
    };
  }

  function load(data) {
    list = [];
    shots = [];
    driver = null;
    flattened.clear();
    fresh.length = 0;
    if (!data) return;
    nextId = data.nextId ?? 1;
    driven = data.driven ?? 0;
    crushed = data.crushed ?? 0;
    kills = data.kills ?? 0;
    for (const i of data.flattened ?? []) {
      flattened.add(i);
      fresh.push(i);
    }
    list = (data.list ?? []).filter((v) => VEHICLES[v.kind]).map((v) => ({ ...v, vehicle: true, speed: 0 }));
  }

  return {
    tick,
    canAdd,
    add,
    remove,
    near,
    hurt,
    byId,
    save,
    load,
    input,
    events,
    fresh,
    flattened,
    // Gets the player into a vehicle (or out with null).
    drive(v) {
      driver = v && list.includes(v) ? v.id : null;
      input.throttle = input.steer = 0;
    },
    get driving() {
      return driver === null ? null : byId(driver);
    },
    get list() {
      return list;
    },
    get shots() {
      return shots;
    },
    get driven() {
      return driven;
    },
    get crushed() {
      return crushed;
    },
    get kills() {
      return kills;
    },
    count: (kind) => list.filter((v) => v.kind === kind).length,
  };
}
