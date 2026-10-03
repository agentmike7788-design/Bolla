// Production statistics: what the factory makes and uses up, per resource, and
// how much power its networks have and need. Counts are collected in buckets of
// BUCKET seconds of play; the last hour is kept for the statistics window.

export const BUCKET = 10; // seconds of play per bucket
export const KEEP = 360; // buckets kept: one hour

const fresh = () => ({ p: {}, c: {}, cap: 0, dem: 0 });
const add = (into, kind, n) => (into[kind] = (into[kind] ?? 0) + n);
const round = (o) => Object.fromEntries(Object.entries(o).map(([k, n]) => [k, Math.round(n * 100) / 100]));

export function createHistory() {
  let buckets = []; // finished buckets, oldest first
  let cur = fresh(); // the bucket being filled
  let curTime = 0; // seconds in the current bucket
  let version = 0; // counts finished buckets, so the view knows when to redraw
  const total = { p: {}, c: {} }; // since the start of the game

  return {
    produce(kind, n = 1) {
      add(cur.p, kind, n);
      add(total.p, kind, n);
    },
    consume(kind, n = 1) {
      add(cur.c, kind, n);
      add(total.c, kind, n);
    },
    // `capacity` and `demand` in MW, summed over all networks.
    tick(dt, capacity, demand) {
      cur.cap += capacity * dt;
      cur.dem += demand * dt;
      curTime += dt;
      if (curTime < BUCKET) return;
      curTime -= BUCKET;
      buckets.push(cur);
      if (buckets.length > KEEP) buckets.shift();
      cur = fresh();
      version++;
    },
    get buckets() {
      return buckets;
    },
    get current() {
      return cur;
    },
    get currentTime() {
      return curTime;
    },
    get version() {
      return version;
    },
    total,
    // Parts per minute over the last minute (fewer finished buckets at the start of a game).
    perMinute(kind, side = 'p') {
      const last = buckets.slice(-6);
      const seconds = last.length * BUCKET + curTime;
      if (seconds < 1) return 0;
      let n = cur[side][kind] ?? 0;
      for (const b of last) n += b[side][kind] ?? 0;
      return (n / seconds) * 60;
    },
    save: () => ({
      buckets: buckets.map((b) => ({ p: round(b.p), c: round(b.c), cap: Math.round(b.cap), dem: Math.round(b.dem) })),
      cur: { p: round(cur.p), c: round(cur.c), cap: Math.round(cur.cap), dem: Math.round(cur.dem) },
      curTime,
      total: { p: round(total.p), c: round(total.c) },
    }),
    load(data) {
      buckets = (data?.buckets ?? []).map((b) => ({ ...fresh(), ...b }));
      cur = { ...fresh(), ...data?.cur };
      curTime = data?.curTime ?? 0;
      total.p = { ...data?.total?.p };
      total.c = { ...data?.total?.c };
      version++;
    },
  };
}
