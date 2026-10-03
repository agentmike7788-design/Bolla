// Logistics drones: drone ports, provider chests and requester chests.
//
// A drone port keeps a few drones and covers the square around it. Ports whose
// squares overlap form one logistics network. Belts fill provider chests; a
// requester chest asks for one kind of part and hands what it gets to the
// building in front of it. Whenever a requester has less than it wants, a drone
// from a port of the same network flies to a provider with that part, picks it
// up, drops it at the requester and flies home. Drones only start from ports on
// a powered grid.

export const DRONES_PER_PORT = 4;
export const DRONE_RANGE = 12; // tiles a port covers in every direction (25 × 25)
export const DRONE_SPEED = 4; // tiles per second, before research
export const DRONE_CARGO = 4; // parts per flight
export const PROVIDER_CAP = 48; // parts a provider chest holds
export const REQUEST_AMOUNTS = [10, 25, 50];
const ASSIGN_EVERY = 0.25; // seconds between looking for work
const HOVER = 0.35; // seconds a drone hovers over a chest to pick up or drop

export const isChest = (b) => b?.type === 'provider' || b?.type === 'requester';
const isLogistic = (b) => b?.type === 'dronePort' || isChest(b);

export function createDrones({ buildings, research, neighbour, pushTo, onFly }) {
  const drones = [];
  let nextId = 1;
  let dirty = true;
  let nets = [];
  let assignTimer = 0;

  const span = (a, b) => Math.max(Math.abs(a.tile.x - b.tile.x), Math.abs(a.tile.z - b.tile.z));
  const dist = (d, b) => Math.hypot(b.tile.position.x - d.x, b.tile.position.z - d.z);
  const powered = (port) => !!port.net && port.net.satisfaction > 0;

  // Ports with overlapping squares join one network; chests join the network of
  // the first port that covers them.
  function update() {
    dirty = false;
    const ports = [];
    for (const b of buildings.values()) {
      if (b.type === 'dronePort') ports.push(b);
      if (isLogistic(b)) b.dnet = null;
    }
    nets = [];
    for (const first of ports) {
      if (first.dnet) continue;
      const net = { id: nets.length + 1, ports: [], chests: [] };
      nets.push(net);
      first.dnet = net;
      const todo = [first];
      while (todo.length) {
        const p = todo.pop();
        net.ports.push(p);
        for (const q of ports) {
          if (q.dnet || span(p, q) > DRONE_RANGE * 2) continue;
          q.dnet = net;
          todo.push(q);
        }
      }
    }
    for (const b of buildings.values()) {
      if (!isChest(b)) continue;
      const port = ports.find((p) => span(p, b) <= DRONE_RANGE);
      if (!port) continue;
      b.dnet = port.dnet;
      port.dnet.chests.push(b);
    }
  }

  // Drones out of each port, parts on the way to each requester and parts a
  // provider has promised to drones already.
  function tally() {
    const out = new Map();
    const incoming = new Map();
    const promised = new Map();
    for (const d of drones) {
      out.set(d.port, (out.get(d.port) ?? 0) + 1);
      if (d.phase === 'home') continue;
      const key = d.to;
      incoming.set(key, (incoming.get(key) ?? 0) + (d.phase === 'pick' ? d.want : d.n));
      if (d.phase === 'pick') {
        const p = `${d.from}:${d.kind}`;
        promised.set(p, (promised.get(p) ?? 0) + d.want);
      }
    }
    return { out, incoming, promised };
  }

  function launch(port, from, to, kind, n) {
    const p = port.tile.position;
    drones.push({ id: nextId++, port: port.index, phase: 'pick', from: from.index, to: to.index, kind, want: n, n: 0, x: p.x, z: p.z, sx: p.x, sz: p.z, wait: 0 });
  }

  // Sends idle drones to requesters that want more than they have and get.
  function assign() {
    const { out, incoming, promised } = tally();
    for (const net of nets) {
      const ports = net.ports.filter(powered);
      if (!ports.length) continue;
      for (const r of net.chests) {
        if (r.type !== 'requester' || !r.request) continue;
        let deficit = r.want - (r.items[r.request] ?? 0) - (incoming.get(r.index) ?? 0);
        // Full loads where possible; a single part only when nothing is on the way.
        let idle = !incoming.get(r.index);
        while (deficit > 0) {
          const least = idle ? 1 : Math.min(DRONE_CARGO, deficit);
          let best = null;
          for (const p of net.chests) {
            if (p.type !== 'provider') continue;
            const avail = (p.items[r.request] ?? 0) - (promised.get(`${p.index}:${r.request}`) ?? 0);
            if (avail < least) continue;
            for (const q of ports) {
              if ((out.get(q.index) ?? 0) >= DRONES_PER_PORT) continue;
              const cost = span(q, p) + span(p, r);
              if (!best || cost < best.cost) best = { p, q, cost, avail };
            }
          }
          if (!best) break;
          const n = Math.min(DRONE_CARGO, deficit, best.avail);
          launch(best.q, best.p, r, r.request, n);
          out.set(best.q.index, (out.get(best.q.index) ?? 0) + 1);
          const key = `${best.p.index}:${r.request}`;
          promised.set(key, (promised.get(key) ?? 0) + n);
          deficit -= n;
          idle = false;
        }
      }
    }
  }

  // The port a drone flies back to: its own, or the nearest one left.
  function homeOf(d) {
    const own = buildings.get(d.port);
    if (own?.type === 'dronePort') return own;
    let best = null;
    for (const b of buildings.values()) if (b.type === 'dronePort' && (!best || dist(d, b) < dist(d, best))) best = b;
    if (best) d.port = best.index;
    return best;
  }

  function goHome(d) {
    d.phase = 'home';
    d.sx = d.x;
    d.sz = d.z;
  }

  function fly(d, dt) {
    const target = d.phase === 'pick' ? buildings.get(d.from) : d.phase === 'drop' ? buildings.get(d.to) : homeOf(d);
    const valid = d.phase === 'pick' ? target?.type === 'provider' : d.phase === 'drop' ? target?.type === 'requester' : !!target;
    if (!valid) {
      if (d.phase === 'home') return false; // no port left
      // The chest is gone: a drone with cargo looks for another requester of it.
      if (d.phase === 'drop') {
        const other = [...buildings.values()].find((b) => b.type === 'requester' && b.request === d.kind);
        if (other) {
          d.to = other.index;
          return true;
        }
      }
      goHome(d);
      return true;
    }
    const tx = target.tile.position.x;
    const tz = target.tile.position.z;
    const left = Math.hypot(tx - d.x, tz - d.z);
    const step = DRONE_SPEED * research.stats.drone * dt;
    if (left > step) {
      d.x += ((tx - d.x) / left) * step;
      d.z += ((tz - d.z) / left) * step;
      return true;
    }
    d.x = tx;
    d.z = tz;
    if (d.phase === 'home') return false; // landed
    d.wait += dt;
    if (d.wait < HOVER) return true;
    d.wait = 0;
    if (d.phase === 'pick') {
      const n = Math.min(d.want, target.items[d.kind] ?? 0);
      if (n <= 0) {
        goHome(d);
        return true;
      }
      target.items[d.kind] -= n;
      target.total -= n;
      target.sent += n;
      d.n = n;
      d.phase = 'drop';
      d.sx = d.x;
      d.sz = d.z;
    } else {
      target.items[d.kind] = (target.items[d.kind] ?? 0) + d.n;
      target.total += d.n;
      target.received += d.n;
      onFly(d.kind, d.n);
      d.n = 0;
      goHome(d);
    }
    return true;
  }

  function tick(dt) {
    if (dirty) update();
    for (let i = drones.length - 1; i >= 0; i--) if (!fly(drones[i], dt)) drones.splice(i, 1);
    assignTimer += dt;
    if (assignTimer >= ASSIGN_EVERY) {
      assignTimer = 0;
      assign();
    }
    const out = new Map();
    for (const d of drones) out.set(d.port, (out.get(d.port) ?? 0) + 1);
    for (const b of buildings.values()) {
      if (b.type === 'dronePort') {
        b.out = out.get(b.index) ?? 0;
        b.state = !powered(b) ? 'nopower' : b.out ? 'work' : 'idle';
      } else if (b.type === 'requester' && b.total > 0) {
        // Hands one part at a time to the building in front.
        const kind = Object.keys(b.items).find((k) => b.items[k] > 0);
        if (kind && pushTo(neighbour(b, b.dir), kind, b.dir)) {
          b.items[kind]--;
          b.total--;
          b.handed++;
        }
      }
    }
  }

  // A provider chest takes any part from any side until it is full.
  function accept(b, kind) {
    if (b.total >= PROVIDER_CAP) return false;
    b.items[kind] = (b.items[kind] ?? 0) + 1;
    b.total++;
    b.filled++;
    return true;
  }

  function setRequest(b, kind, want = b.want) {
    if (b.type !== 'requester') return;
    b.request = kind;
    b.want = want;
  }

  function summary() {
    let ports = 0;
    let chests = 0;
    let uncovered = 0;
    for (const b of buildings.values()) {
      if (b.type === 'dronePort') ports++;
      if (isChest(b)) {
        chests++;
        if (!b.dnet) uncovered++;
      }
    }
    const flying = drones.filter((d) => d.phase !== 'home').length;
    return { ports, drones: ports * DRONES_PER_PORT, flying, out: drones.length, chests, uncovered, nets: nets.length };
  }

  return {
    drones,
    tick,
    accept,
    setRequest,
    summary,
    markDirty: () => (dirty = true),
    update: () => dirty && update(),
    save: () => drones.map((d) => ({ ...d })),
    load(list) {
      drones.length = 0;
      for (const d of list ?? []) drones.push({ ...d });
      nextId = Math.max(0, ...drones.map((d) => d.id)) + 1;
      dirty = true;
    },
  };
}
