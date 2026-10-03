// Railways: tracks, stations and the trains that run between them.
//
// Track tiles (rails and stations) keep a bit per side they connect on; two
// neighbours are linked when both point at each other. Dragging a rail links
// each new tile to the last one, so lines can curve and branch. A station is a
// straight piece of track: belts load it from its two sides, and in unload mode
// it hands the cargo out to belts on those sides.
//
// A train is two locomotives with two wagons between them. It drives tile by
// tile along the track to the next stop of its schedule, loads or unloads there
// and goes on. With a locomotive at each end it can reverse at any station, so a
// single line between two stations is enough. Trains wait for each other; two
// that would wait for ever let one pass.

const D = [
  { x: 0, z: -1 },
  { x: 1, z: 0 },
  { x: 0, z: 1 },
  { x: -1, z: 0 },
];
const opposite = (d) => (d + 2) % 4;
const bit = (d) => 1 << d;
export const axisBits = (dir) => bit(dir) | bit(opposite(dir));

export const TRAIN_SPEED = 5; // tiles per second at full speed, before research
export const TRAIN_ACCEL = 2.2; // tiles per second², for speeding up and braking
export const CARS = 4; // a locomotive at each end, two wagons between
export const CAR_GAP = 1; // tiles between the middles of two cars
export const TRAIN_LENGTH = (CARS - 1) * CAR_GAP;
export const WAGON_CARGO = 40;
export const TRAIN_CARGO = WAGON_CARGO * (CARS - 2);
export const STATION_CAP = 80; // parts a station holds
export const TRANSFER_RATE = 12; // parts per second between station and train
const LOAD_WAIT = 3; // a train with some cargo leaves when nothing came for this long
const UNLOAD_WAIT = 5; // and leaves a full station after this long
const MIN_STOP = 1.2; // seconds every stop takes at least
const PASS_AFTER = 1.5; // seconds two trains wait for each other before one passes
export const isTrack = (b) => b?.type === 'rail' || b?.type === 'station';

// Point and heading at distance `s` along a path of tile indices; whole numbers
// are tile middles. Curves follow a quarter circle like the rails do.
export function trackPoint(world, path, s, out = {}) {
  const last = path.length - 1;
  const k = Math.min(last, Math.max(0, Math.round(s)));
  const tile = world.tiles[path[k]];
  const step = (i, j) => {
    const d = j - i;
    return d === -world.size ? 0 : d === 1 ? 1 : d === world.size ? 2 : 3;
  };
  const din = k > 0 ? step(path[k - 1], path[k]) : null;
  const dout = k < last ? step(path[k], path[k + 1]) : null;
  const a = din ?? dout ?? 0;
  const b = dout ?? din ?? 0;
  const t = Math.min(1, Math.max(0, s - k + 0.5));
  const c = tile.position;
  let hx;
  let hz;
  if (a === b) {
    out.x = c.x + D[a].x * (t - 0.5);
    out.z = c.z + D[a].z * (t - 0.5);
    hx = D[a].x;
    hz = D[a].z;
  } else {
    // Around the corner shared by the entry and the exit edge.
    const kx = c.x + (D[b].x - D[a].x) * 0.5;
    const kz = c.z + (D[b].z - D[a].z) * 0.5;
    const ang = (t * Math.PI) / 2;
    out.x = kx + (-D[b].x * Math.cos(ang) + D[a].x * Math.sin(ang)) * 0.5;
    out.z = kz + (-D[b].z * Math.cos(ang) + D[a].z * Math.sin(ang)) * 0.5;
    hx = D[b].x * Math.sin(ang) + D[a].x * Math.cos(ang);
    hz = D[b].z * Math.sin(ang) + D[a].z * Math.cos(ang);
  }
  // Tiles differ a little in height: ease over the edges.
  const h = tile.height;
  const hPrev = k > 0 ? world.tiles[path[k - 1]].height : h;
  const hNext = k < last ? world.tiles[path[k + 1]].height : h;
  out.y = t < 0.5 ? (hPrev + h) / 2 + (h - (hPrev + h) / 2) * t * 2 : h + ((h + hNext) / 2 - h) * (t - 0.5) * 2;
  out.heading = Math.atan2(-hx, -hz);
  return out;
}

// The railway part of a factory. `ctx` hands in what it needs from factory.js.
export function createRailways({ world, buildings, neighbour, research, pushTo, onShip }) {
  const trains = [];
  let nextId = 1;
  let dirty = true;
  let occupied = new Map(); // tile index -> train covering it
  let stations = [];

  const size = world.size;
  const indexStep = (d) => D[d].z * size + D[d].x;
  const fits = (b, d) => b.type !== 'station' || d % 2 === b.dir % 2;

  function trackLink(a, d) {
    const n = neighbour(a, d);
    return isTrack(n) && a.conn & bit(d) && n.conn & bit(opposite(d)) ? n : null;
  }
  const realLinks = (b) => [0, 1, 2, 3].filter((d) => trackLink(b, d));

  // A rail forgets the sides it points to without a partner there.
  function tidy(b) {
    if (b.type !== 'rail') return;
    let conn = 0;
    for (const d of realLinks(b)) conn |= bit(d);
    b.conn = conn;
  }

  function connect(a, n, d) {
    if (!fits(a, d) || !fits(n, opposite(d))) return false;
    tidy(a);
    tidy(n);
    a.conn |= bit(d);
    n.conn |= bit(opposite(d));
    dirty = true;
    return true;
  }

  // A new track tile joins neighbours that point at it and open rail ends. A
  // rail on its own lies along its build direction, ready to be joined.
  function join(b) {
    for (let d = 0; d < 4; d++) {
      const n = neighbour(b, d);
      if (!isTrack(n)) continue;
      const pointsHere = n.conn & bit(opposite(d));
      const open = n.type === 'rail' && realLinks(n).length < 2;
      if (pointsHere || open) connect(b, n, d);
    }
    if (b.type === 'rail' && !b.conn) b.conn = axisBits(b.dir);
    dirty = true;
  }

  // Dragging a rail from tile a to its neighbour b.
  function link(a, b) {
    if (!isTrack(a) || !isTrack(b)) return false;
    const d = D.findIndex((v) => v.x === b.tile.x - a.tile.x && v.z === b.tile.z - a.tile.z);
    return d >= 0 && connect(a, b, d);
  }

  // Every track tile learns its linked sides, and trains whose track is gone derail.
  function update() {
    dirty = false;
    stations = [];
    for (const b of buildings.values()) {
      if (!isTrack(b)) continue;
      b.links = realLinks(b);
      if (b.type === 'station') stations.push(b);
    }
    const lost = [];
    for (const t of [...trains]) {
      const [from, to] = covered(t);
      let ok = true;
      for (let i = from; i <= to && ok; i++) {
        const b = buildings.get(t.path[i]);
        if (!isTrack(b)) ok = false;
        else if (i < to && !b.links.some((d) => t.path[i] + indexStep(d) === t.path[i + 1])) ok = false;
      }
      if (!ok) {
        lost.push(t);
        removeTrain(t);
      } else if (t.at === null || t.state === 'nopath') plan(t);
    }
    return lost;
  }

  // Path indices the cars of a train stand on, tail to head.
  function covered(t) {
    const last = t.path.length - 1;
    return [Math.max(0, Math.ceil(t.s - TRAIN_LENGTH - 0.5)), Math.min(last, Math.floor(t.s + 0.5))];
  }

  function rebuildOccupied() {
    occupied = new Map();
    for (const t of trains) {
      const [from, to] = covered(t);
      for (let i = from; i <= to; i++) occupied.set(t.path[i], t);
    }
  }

  // Shortest way over the track from tile `from` to tile `to`, as tile indices.
  // The first step may not go back to `back`, so trains do not turn on the spot.
  function route(from, back, to) {
    const prev = new Map([[from, -1]]);
    const queue = [from];
    for (let q = 0; q < queue.length && !prev.has(to); q++) {
      const i = queue[q];
      const b = buildings.get(i);
      if (!b?.links) continue;
      for (const d of b.links) {
        const j = i + indexStep(d);
        if (prev.has(j) || (i === from && j === back)) continue;
        prev.set(j, i);
        queue.push(j);
      }
    }
    if (!prev.has(to)) return null;
    const path = [];
    for (let i = to; i !== -1; i = prev.get(i)) path.push(i);
    return path.reverse();
  }

  // The train turns around: the last locomotive leads now.
  function reverse(t) {
    const k = Math.round(t.s);
    t.path = t.path.slice(0, k + 1).reverse();
    t.s = t.path.length - 1 - (t.s - TRAIN_LENGTH);
  }

  const stationAt = (i) => {
    const b = buildings.get(i);
    return b?.type === 'station' ? b : null;
  };

  // Finds the way to the current stop, turning the train around if it has to.
  function plan(t) {
    t.schedule = t.schedule.filter(stationAt);
    if (!t.schedule.length) {
      t.state = 'noschedule';
      t.speed = 0;
      return;
    }
    t.stop %= t.schedule.length;
    const target = t.schedule[t.stop];
    const tryRoute = () => {
      const k = Math.round(t.s);
      const r = route(t.path[k], t.path[k - 1] ?? -1, target);
      if (!r) return false;
      const keep = Math.max(0, Math.floor(t.s - TRAIN_LENGTH) - 1);
      t.path = t.path.slice(keep, k).concat(r);
      t.s -= keep;
      return true;
    };
    let found = tryRoute();
    if (!found && t.speed < 0.05) {
      reverse(t);
      found = tryRoute();
      if (!found) reverse(t);
    }
    t.retry = 0;
    if (!found) {
      t.state = 'nopath';
      t.speed = 0;
      return;
    }
    t.at = null;
    t.state = 'run';
    if (Math.round(t.s) >= t.path.length - 1) arrive(t);
  }

  function arrive(t) {
    t.s = t.path.length - 1;
    t.speed = 0;
    t.at = t.path[t.path.length - 1];
    t.timer = 0;
    t.idle = 0;
    t.acc = 0;
    t.ghost = null;
    t.state = stationAt(t.at)?.mode ?? 'stop';
  }

  function depart(t) {
    if (t.schedule.length > 1) t.stop = (t.stop + 1) % t.schedule.length;
    plan(t);
  }

  const firstKind = (counts) => {
    for (const k in counts) if (counts[k] > 0) return k;
    return null;
  };

  function work(t, dt) {
    const st = stationAt(t.at);
    if (!st) return plan(t);
    t.state = st.mode;
    t.blockedBy = null;
    t.timer += dt;
    t.acc += TRANSFER_RATE * dt;
    let moved = false;
    while (t.acc >= 1) {
      t.acc--;
      if (st.mode === 'load') {
        const k = t.total < TRAIN_CARGO && firstKind(st.items);
        if (!k) break;
        st.items[k]--;
        st.total--;
        t.cargo[k] = (t.cargo[k] ?? 0) + 1;
        t.total++;
      } else {
        const k = st.total < STATION_CAP && firstKind(t.cargo);
        if (!k) break;
        t.cargo[k]--;
        t.total--;
        st.items[k] = (st.items[k] ?? 0) + 1;
        st.total++;
        st.received++;
        t.shipped++;
        onShip(k);
      }
      moved = true;
      st.state = 'work';
    }
    if (t.acc > 1) t.acc = 1;
    t.idle = moved ? 0 : t.idle + dt;
    if (t.schedule.length < 2 || t.timer < MIN_STOP) return;
    const ready = st.mode === 'load' ? t.total >= TRAIN_CARGO || (t.total > 0 && t.idle >= LOAD_WAIT) : t.total === 0 || t.idle >= UNLOAD_WAIT;
    if (ready) {
      t.trips++;
      depart(t);
    }
  }

  function drive(t, dt) {
    const end = t.path.length - 1;
    const vmax = TRAIN_SPEED * research.stats.train;
    let limit = end;
    let blocker = null;
    const k = Math.round(t.s);
    const look = Math.ceil((t.speed * t.speed) / (2 * TRAIN_ACCEL)) + 2;
    for (let m = 1; m <= look && k + m <= end; m++) {
      const o = occupied.get(t.path[k + m]);
      if (!o || o === t || o === t.ghost) continue;
      blocker = o;
      limit = Math.min(limit, k + m - 1);
      break;
    }
    t.blockedBy = null;
    if (blocker && t.s >= limit - 0.05) {
      t.blockedBy = blocker;
      t.blockedFor = (t.blockedFor ?? 0) + dt;
      // Waiting for each other: the older train passes.
      if (blocker.blockedBy === t && t.blockedFor > PASS_AFTER && t.id < blocker.id) t.ghost = blocker;
    } else t.blockedFor = 0;
    const dist = Math.max(0, limit - t.s);
    const target = Math.min(vmax, Math.sqrt(2 * TRAIN_ACCEL * dist));
    t.speed = t.speed < target ? Math.min(target, t.speed + TRAIN_ACCEL * dt) : target;
    if (t.s < limit) t.s = Math.min(limit, t.s + t.speed * dt);
    else t.speed = 0;
    t.state = t.blockedBy ? 'blocked' : 'run';
    if (t.s >= end - 1e-3) arrive(t);
  }

  function tick(dt) {
    rebuildOccupied();
    for (const st of stations) st.state = 'idle';
    for (const t of trains) {
      if (t.at !== null) work(t, dt);
      else if (t.state === 'nopath' || t.state === 'noschedule') {
        t.retry = (t.retry ?? 0) + dt;
        if (t.retry > 2) plan(t);
      } else drive(t, dt);
    }
    // Unloading stations hand their cargo to belts on their sides.
    for (const st of stations) {
      if (st.mode !== 'unload' || !st.total) continue;
      for (const side of [(st.dir + 1) % 4, (st.dir + 3) % 4]) {
        const k = firstKind(st.items);
        if (!k) break;
        if (pushTo(neighbour(st, side), k, side)) {
          st.items[k]--;
          st.total--;
          st.sent++;
        }
      }
    }
  }

  // Could a train be put onto this tile? It needs four tiles of track in a row.
  function startPath(tile) {
    const idx = tile.z * size + tile.x;
    const b = buildings.get(idx);
    if (!isTrack(b)) return { ok: false, reason: 'Züge nur auf Gleise oder Bahnhöfe setzen' };
    if (dirty) update();
    rebuildOccupied();
    for (const first of b.links) {
      const walk = [idx];
      let back = -1;
      let cur = idx;
      let d = first;
      while (walk.length < CARS) {
        const next = cur + indexStep(d);
        back = cur;
        cur = next;
        walk.push(cur);
        const nb = buildings.get(cur);
        const on = nb?.links?.filter((x) => cur + indexStep(x) !== back) ?? [];
        if (walk.length < CARS && !on.length) break;
        d = on[0];
      }
      if (walk.length < CARS) continue;
      if (walk.some((i) => occupied.has(i))) return { ok: false, reason: 'Hier steht schon ein Zug' };
      return { ok: true, reason: '', path: walk.reverse() };
    }
    return { ok: false, reason: 'Zu wenig Gleis: ein Zug braucht 4 Felder am Stück' };
  }

  // Stations a train can reach from a tile, nearest first.
  function reachable(from) {
    const seen = new Set([from]);
    const queue = [from];
    const found = [];
    for (let q = 0; q < queue.length; q++) {
      const i = queue[q];
      const b = buildings.get(i);
      if (b?.type === 'station') found.push(i);
      for (const d of b?.links ?? []) {
        const j = i + indexStep(d);
        if (seen.has(j)) continue;
        seen.add(j);
        queue.push(j);
      }
    }
    return found;
  }

  function addTrain(tile) {
    const check = startPath(tile);
    if (!check.ok) return null;
    const head = check.path[check.path.length - 1];
    const near = reachable(head);
    const t = {
      id: nextId++,
      path: check.path,
      s: CARS - 1,
      speed: 0,
      state: 'stop',
      schedule: near.slice(0, 2),
      stop: 0,
      cargo: {},
      total: 0,
      timer: 0,
      idle: 0,
      acc: 0,
      at: null,
      shipped: 0,
      trips: 0,
    };
    trains.push(t);
    if (stationAt(head)) {
      arrive(t);
    } else plan(t);
    return t;
  }

  function removeTrain(t) {
    const i = trains.indexOf(t);
    if (i >= 0) trains.splice(i, 1);
    for (const o of trains) {
      if (o.ghost === t) o.ghost = null;
      if (o.blockedBy === t) o.blockedBy = null;
    }
    rebuildOccupied();
  }

  function trainOn(tile) {
    if (!tile) return null;
    const idx = tile.z * size + tile.x;
    for (const t of trains) {
      const [from, to] = covered(t);
      for (let i = from; i <= to; i++) if (t.path[i] === idx) return t;
    }
    return null;
  }

  function setSchedule(t, schedule) {
    t.schedule = schedule.filter(stationAt);
    t.stop = 0;
    if (t.at !== null && t.schedule[0] === t.at) return;
    // Head for the first stop of the new schedule, unless it waits at it already.
    if (t.at !== null) {
      t.at = null;
      t.state = 'run';
    }
    if (t.speed < 0.05 || t.state === 'nopath' || t.state === 'noschedule') plan(t);
    else {
      // A running train finds the new way from where it is.
      const k = Math.round(t.s);
      const r = t.schedule.length ? route(t.path[k], t.path[k - 1] ?? -1, t.schedule[0]) : null;
      if (r) {
        t.path = t.path.slice(0, k).concat(r);
      } else plan(t);
    }
  }

  function summary() {
    let running = 0;
    let waiting = 0;
    for (const t of trains) {
      if (t.state === 'run') running++;
      if (t.state === 'nopath' || t.state === 'noschedule' || t.state === 'blocked') waiting++;
    }
    return { trains: trains.length, running, waiting, stations: stations.length };
  }

  return {
    trains,
    tick,
    join,
    link,
    update: () => (dirty ? update() : []),
    markDirty: () => (dirty = true),
    get dirty() {
      return dirty;
    },
    startPath,
    addTrain,
    removeTrain,
    trainOn,
    setSchedule,
    reachable,
    summary,
    save: () => trains.map(({ blockedBy, ghost, blockedFor, retry, ...t }) => ({ ...t, cargo: { ...t.cargo }, path: [...t.path], schedule: [...t.schedule] })),
    load(list) {
      trains.length = 0;
      for (const t of list ?? []) trains.push({ ...t, cargo: { ...t.cargo } });
      nextId = Math.max(0, ...trains.map((t) => t.id)) + 1;
      dirty = true;
    },
  };
}
