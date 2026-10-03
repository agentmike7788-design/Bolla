import { ORES, TERRAIN } from './world.js';

// Grid directions: 0 north (-z), 1 east (+x), 2 south (+z), 3 west (-x).
export const DIRS = [
  { x: 0, z: -1 },
  { x: 1, z: 0 },
  { x: 0, z: 1 },
  { x: -1, z: 0 },
];
export const DIR_NAMES = ['Nord', 'Ost', 'Süd', 'West'];

export const BUILDINGS = {
  drill: { name: 'Bohrer' },
  belt: { name: 'Förderband' },
};

export const BELT_SPEED = 1.5; // tiles per second
export const ITEM_SPACING = 0.34; // minimum gap between two items on a belt, in tiles
export const DRILL_TIME = 1.4; // seconds per mined ore

const opposite = (dir) => (dir + 2) % 4;

// The factory on top of a world: which building stands on which tile, and the
// simulation that moves ore from drills over belts.
export function createFactory(world) {
  const buildings = new Map(); // tile index -> building
  const mined = Object.fromEntries(Object.keys(ORES).map((k) => [k, 0]));

  const indexOf = (tile) => tile.z * world.size + tile.x;
  const at = (x, z) => (x < 0 || z < 0 || x >= world.size || z >= world.size ? null : buildings.get(z * world.size + x) ?? null);
  const neighbour = (b, dir) => at(b.tile.x + DIRS[dir].x, b.tile.z + DIRS[dir].z);
  // Does building `from` hand its items to building `to`?
  const feeds = (from, to) => from && from.tile.x + DIRS[from.dir].x === to.tile.x && from.tile.z + DIRS[from.dir].z === to.tile.z;

  function canPlace(type, tile) {
    if (!tile) return { ok: false, reason: '' };
    if (buildings.has(indexOf(tile))) return { ok: false, reason: 'Hier steht schon etwas' };
    if (!TERRAIN[tile.terrain].buildable) return { ok: false, reason: 'Hier kann man nicht bauen' };
    if (type === 'drill' && !tile.ore) return { ok: false, reason: 'Bohrer nur auf Erzfeldern' };
    return { ok: true, reason: '' };
  }

  function place(type, tile, dir) {
    if (!canPlace(type, tile).ok) return null;
    const b = { type, tile, dir, index: indexOf(tile) };
    if (type === 'drill') Object.assign(b, { timer: 0, held: null, state: 'work', mined: 0 });
    if (type === 'belt') Object.assign(b, { items: [], shape: 'straight' });
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

  // Put an item onto a belt that it reaches while travelling in direction `dir`.
  function pushTo(target, ore, dir) {
    if (!target || target.type !== 'belt' || target.dir === opposite(dir)) return false;
    const last = target.items[target.items.length - 1];
    if (last && last.p < ITEM_SPACING) return false;
    target.items.push({ ore, p: 0, from: dir, spin: Math.random() * Math.PI * 2 });
    return true;
  }

  function tick(dt) {
    const step = BELT_SPEED * dt;
    for (const b of buildings.values()) {
      if (b.type !== 'belt' || b.items.length === 0) continue;
      // Items are ordered front first; each one stops behind the one ahead of it.
      let limit = Infinity;
      const kept = [];
      for (const item of b.items) {
        let p = Math.min(item.p + step, limit);
        if (p >= 1) {
          if (limit === Infinity && pushTo(neighbour(b, b.dir), item.ore, b.dir)) continue;
          p = 1;
        }
        item.p = Math.max(item.p, p);
        kept.push(item);
        limit = item.p - ITEM_SPACING;
      }
      b.items = kept;
    }

    for (const b of buildings.values()) {
      if (b.type !== 'drill') continue;
      if (b.held) {
        if (pushTo(neighbour(b, b.dir), b.held, b.dir)) b.held = null;
      }
      if (b.held) {
        b.state = 'blocked';
        continue;
      }
      if (b.tile.amount <= 0) {
        b.state = 'empty';
        continue;
      }
      b.state = 'work';
      b.timer += dt;
      if (b.timer >= DRILL_TIME) {
        b.timer -= DRILL_TIME;
        b.tile.amount--;
        b.held = b.tile.ore;
        b.mined++;
        mined[b.tile.ore]++;
      }
    }
  }

  return { buildings, mined, at, canPlace, place, remove, setDir, tick, get: (tile) => buildings.get(indexOf(tile)) ?? null };
}
