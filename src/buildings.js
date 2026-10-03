import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { BELT_TIERS, DIRS, ITEMS } from './factory.js';
import { ORES } from './world.js';

const STEEL = 0x3a4046;
const STEEL_DARK = 0x2a2f34;
const SIGNAL = 0xf0a830;
const CHEVRONS_PER_TILE = 3;
const BELT_TOP = 0.075; // height of the moving surface above the tile

const yaw = (dir) => -dir * (Math.PI / 2);

// Centre lines of the three belt shapes in local space: items travel towards -z.
// Curves enter over the left (-x) or right (+x) edge and turn a quarter circle.
const BELT_PATHS = {
  straight: { length: 1, at: (t) => [0, 0.5 - t] },
  left: { length: Math.PI / 4, at: (t) => [-0.5 + 0.5 * Math.sin((t * Math.PI) / 2), -0.5 + 0.5 * Math.cos((t * Math.PI) / 2)] },
  right: { length: Math.PI / 4, at: (t) => [0.5 - 0.5 * Math.sin((t * Math.PI) / 2), -0.5 + 0.5 * Math.cos((t * Math.PI) / 2)] },
};

// Sweeps a rectangular cross-section (u across the belt, y up) along a path.
// v of the top face runs along the path in tile units, so textures scroll with the items.
function sweepBox(path, { u0, u1, y0, y1, top = true, sides = true, caps = true }, segments) {
  const pos = [];
  const uv = [];
  const rings = [];
  for (let i = 0; i <= segments; i++) {
    const t = i / segments;
    const [x, z] = path.at(t);
    const [ax, az] = path.at(Math.max(0, t - 0.001));
    const [bx, bz] = path.at(Math.min(1, t + 0.001));
    const len = Math.hypot(bx - ax, bz - az);
    const tx = (bx - ax) / len;
    const tz = (bz - az) / len;
    const rx = -tz;
    const rz = tx;
    const p = (u, y) => [x + rx * u, y, z + rz * u];
    rings.push({ lt: p(u0, y1), rt: p(u1, y1), lb: p(u0, y0), rb: p(u1, y0), v: t * path.length });
  }
  const tri = (a, b, c, ua = [0, 0], ub = [0, 0], uc = [0, 0]) => {
    pos.push(...a, ...b, ...c);
    uv.push(...ua, ...ub, ...uc);
  };
  // Quad strip between two edges; L -> R crossed with the travel direction is the outward normal.
  const strip = (L, R, withUv) => {
    for (let i = 0; i < segments; i++) {
      const a = rings[i];
      const b = rings[i + 1];
      const uvs = withUv ? [[0, a.v], [1, a.v], [0, b.v], [1, b.v]] : [];
      tri(a[L], a[R], b[L], uvs[0], uvs[1], uvs[2]);
      tri(a[R], b[R], b[L], uvs[1], uvs[3], uvs[2]);
    }
  };
  if (top) strip('lt', 'rt', true);
  if (sides) {
    strip('rt', 'rb');
    strip('lb', 'lt');
  }
  if (caps) {
    const s = rings[0];
    const e = rings[segments];
    tri(s.lb, s.rb, s.rt);
    tri(s.lb, s.rt, s.lt);
    tri(e.lb, e.rt, e.rb);
    tri(e.lb, e.lt, e.rt);
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  geo.computeVertexNormals();
  return geo;
}

function beltGeometries(shape) {
  const path = BELT_PATHS[shape];
  const n = shape === 'straight' ? 1 : 10;
  return {
    bed: sweepBox(path, { u0: -0.34, u1: 0.34, y0: -0.16, y1: 0.06 }, n),
    rails: mergeGeometries([
      sweepBox(path, { u0: -0.42, u1: -0.33, y0: -0.16, y1: 0.12 }, n),
      sweepBox(path, { u0: 0.33, u1: 0.42, y0: -0.16, y1: 0.12 }, n),
    ]),
    surface: sweepBox(path, { u0: -0.31, u1: 0.31, y0: 0, y1: BELT_TOP, sides: false, caps: false }, n),
  };
}

// Dark rubber with light chevrons pointing in travel direction (+v).
function chevronTexture(anisotropy) {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  g.fillStyle = '#3a3f43';
  g.fillRect(0, 0, 64, 64);
  g.strokeStyle = '#80878c';
  g.lineWidth = 9;
  g.lineCap = 'round';
  g.beginPath();
  g.moveTo(12, 46);
  g.lineTo(32, 22);
  g.lineTo(52, 46);
  g.stroke();
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(1, CHEVRONS_PER_TILE);
  tex.anisotropy = anisotropy;
  return tex;
}

const flat = (color, extra) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.25, flatShading: true, ...extra });

// Shared geometries and materials of all building models. Every model faces -z,
// the side it hands its items out.
function buildingParts() {
  const box = (w, h, d, x, y, z) => new THREE.BoxGeometry(w, h, d).translate(x, y, z);
  const rbox = (w, h, d, x, y, z, r = 0.05) => new RoundedBoxGeometry(w, h, d, 2, r).translate(x, y, z);
  const g = {
    lamp: new THREE.SphereGeometry(0.045, 10, 8),
    // Drill
    foot: rbox(0.86, 0.14, 0.86, 0, 0.07, 0, 0.04),
    body: rbox(0.62, 0.38, 0.56, 0, 0.33, 0.06),
    roof: box(0.68, 0.05, 0.62, 0, 0.545, 0.06),
    chute: box(0.3, 0.16, 0.34, 0, 0.2, -0.3),
    chuteOre: box(0.2, 0.03, 0.3, 0, 0.285, -0.31),
    panel: box(0.34, 0.12, 0.02, 0, 0.34, -0.23),
    mast: new THREE.CylinderGeometry(0.05, 0.05, 0.42, 8).translate(0, 0.78, 0.06),
    rotor: mergeGeometries([
      new THREE.CylinderGeometry(0.15, 0.15, 0.07, 8),
      new THREE.BoxGeometry(0.46, 0.04, 0.06),
      new THREE.BoxGeometry(0.06, 0.04, 0.46),
    ]),
    piston: new THREE.CylinderGeometry(0.08, 0.1, 0.16, 8),
    // Furnace: a brick kiln with a chimney and a glowing mouth on the output side.
    kilnFoot: rbox(0.9, 0.1, 0.9, 0, 0.05, 0, 0.03),
    kiln: rbox(0.72, 0.46, 0.66, 0, 0.33, 0.06, 0.07),
    kilnBands: mergeGeometries([box(0.75, 0.05, 0.69, 0, 0.2, 0.06), box(0.75, 0.05, 0.69, 0, 0.46, 0.06)]),
    kilnRoof: rbox(0.6, 0.12, 0.56, 0, 0.6, 0.06, 0.04),
    chimney: new THREE.CylinderGeometry(0.08, 0.1, 0.56, 8).translate(0.18, 0.88, 0.2),
    chimneyCap: new THREE.CylinderGeometry(0.12, 0.12, 0.05, 8).translate(0.18, 1.17, 0.2),
    mouthFrame: box(0.42, 0.26, 0.04, 0, 0.3, -0.28),
    mouth: box(0.32, 0.17, 0.03, 0, 0.29, -0.295),
    sideGlow: mergeGeometries([box(0.02, 0.08, 0.34, -0.365, 0.33, 0.06), box(0.02, 0.08, 0.34, 0.365, 0.33, 0.06)]),
    tray: box(0.3, 0.05, 0.16, 0, 0.13, -0.4),
    puff: new THREE.IcosahedronGeometry(0.09, 0),
    // Assembler: an open frame with a press that stamps onto a table.
    posts: mergeGeometries([-1, 1].flatMap((sx) => [-1, 1].map((sz) => box(0.08, 0.6, 0.08, sx * 0.32, 0.4, sz * 0.3 + 0.04)))),
    table: box(0.62, 0.1, 0.6, 0, 0.2, 0.04),
    die: box(0.3, 0.04, 0.3, 0, 0.27, 0.04),
    head: rbox(0.76, 0.18, 0.72, 0, 0.77, 0.04),
    headStripe: box(0.78, 0.04, 0.74, 0, 0.7, 0.04),
    press: box(0.26, 0.2, 0.26, 0, 0, 0),
    ram: new THREE.CylinderGeometry(0.04, 0.04, 0.3, 8).translate(0, 0.25, 0),
    // Storage: a ribbed container with a hatch on top.
    pad: box(0.94, 0.06, 0.94, 0, 0.03, 0),
    crate: rbox(0.84, 0.48, 0.78, 0, 0.3, 0.02, 0.04),
    ribs: mergeGeometries([-0.3, -0.15, 0, 0.15, 0.3].map((x) => box(0.04, 0.44, 0.82, x, 0.3, 0.02))),
    crateStripe: box(0.86, 0.06, 0.8, 0, 0.44, 0.02),
    hatch: box(0.44, 0.04, 0.38, 0, 0.56, 0.02),
    display: box(0.3, 0.12, 0.02, 0, 0.3, -0.38),
    // Splitter and merger: a low hub with a turning diverter and three mouths.
    hubFoot: box(0.9, 0.08, 0.9, 0, 0.04, 0),
    hub: rbox(0.62, 0.3, 0.62, 0, 0.23, 0, 0.06),
    hubRing: new THREE.CylinderGeometry(0.24, 0.24, 0.05, 16).translate(0, 0.4, 0),
    diverter: mergeGeometries([box(0.07, 0.07, 0.28, 0, 0, -0.12), new THREE.CylinderGeometry(0.07, 0.07, 0.1, 10)]),
    mouths: mergeGeometries([box(0.3, 0.16, 0.12, 0, 0.16, -0.38), box(0.12, 0.16, 0.3, -0.38, 0.16, 0), box(0.12, 0.16, 0.3, 0.38, 0.16, 0)]),
    mouth1: box(0.3, 0.16, 0.12, 0, 0.16, -0.38),
    inlets: mergeGeometries([box(0.3, 0.16, 0.12, 0, 0.16, 0.38), box(0.12, 0.16, 0.3, -0.38, 0.16, 0), box(0.12, 0.16, 0.3, 0.38, 0.16, 0)]),
    // Constructor: a big workshop with two hoppers, a gear wheel and a robot arm.
    bigFoot: rbox(0.94, 0.1, 0.94, 0, 0.05, 0, 0.03),
    shop: rbox(0.8, 0.5, 0.64, 0, 0.35, 0.1, 0.06),
    shopRoof: box(0.86, 0.06, 0.7, 0, 0.62, 0.1),
    hoppers: mergeGeometries([-0.2, 0.2].map((x) => new THREE.CylinderGeometry(0.14, 0.06, 0.24, 8).translate(x, 0.77, 0.18))),
    window: box(0.5, 0.16, 0.02, 0, 0.42, -0.225),
    gearWheel: mergeGeometries([
      new THREE.CylinderGeometry(0.15, 0.15, 0.05, 12).rotateZ(Math.PI / 2),
      ...[0, 1, 2, 3].map((i) => new THREE.BoxGeometry(0.05, 0.4, 0.07).rotateX((i * Math.PI) / 4)),
    ]),
    armBase: new THREE.CylinderGeometry(0.06, 0.08, 0.1, 8),
    arm: box(0.05, 0.05, 0.3, 0, 0, -0.15),
  };
  const m = {
    steel: flat(STEEL),
    dark: flat(STEEL_DARK),
    signal: flat(SIGNAL, { roughness: 0.5 }),
    chrome: new THREE.MeshStandardMaterial({ color: 0xc9ced3, roughness: 0.25, metalness: 0.8 }),
    brick: flat(0x9a5b43, { roughness: 0.85, metalness: 0.05 }),
    soot: flat(0x4a4440, { roughness: 0.9, metalness: 0.1 }),
    smoke: new THREE.MeshStandardMaterial({ color: 0xb9b6b0, roughness: 1, transparent: true, opacity: 0.55, depthWrite: false, flatShading: true }),
    container: flat(0x4f7d8c, { roughness: 0.55 }),
    splitter: flat(0x2f8f83, { roughness: 0.5 }),
    merger: flat(0x7a5aa8, { roughness: 0.5 }),
    shop: flat(0x3f6f9e, { roughness: 0.55 }),
    glass: new THREE.MeshStandardMaterial({ color: 0x18323f, emissive: 0x2a8fc0, emissiveIntensity: 0.4, roughness: 0.2 }),
    ore: Object.fromEntries(Object.entries(ORES).map(([k, o]) => [k, flat(o.color, { roughness: 0.4, metalness: 0.3 })])),
  };
  return { g, m };
}

const LAMP = { work: 0x6be36b, blocked: 0xffb02e, empty: 0xff5544, idle: 0x5aa9ff };
const GLOW = 0xff7a1f;

// Items on belts: one instanced mesh per item shape, each resting on the belt surface.
function itemShapes() {
  const ingot = new THREE.CylinderGeometry(0.062, 0.085, 0.07, 4).rotateY(Math.PI / 4).scale(1.7, 1, 1);
  return {
    ore: { geo: new THREE.DodecahedronGeometry(0.1, 0), lift: 0.08, tumble: true },
    ingot: { geo: ingot, lift: 0.035 },
    plate: { geo: new THREE.BoxGeometry(0.22, 0.03, 0.22), lift: 0.015 },
    wire: { geo: new THREE.TorusGeometry(0.07, 0.03, 6, 14).rotateX(Math.PI / 2), lift: 0.03 },
    block: { geo: new THREE.BoxGeometry(0.16, 0.14, 0.16), lift: 0.07 },
    gear: {
      geo: mergeGeometries([
        new THREE.CylinderGeometry(0.075, 0.075, 0.05, 10),
        ...[0, 1, 2, 3].map((i) => new THREE.BoxGeometry(0.21, 0.05, 0.04).rotateY((i * Math.PI) / 4)),
      ]),
      lift: 0.025,
    },
    chip: { geo: mergeGeometries([new THREE.BoxGeometry(0.2, 0.025, 0.16), new THREE.BoxGeometry(0.07, 0.03, 0.07).translate(0, 0.025, 0)]), lift: 0.015 },
    beam: { geo: mergeGeometries([new THREE.BoxGeometry(0.08, 0.02, 0.26).translate(0, 0.05, 0), new THREE.BoxGeometry(0.08, 0.02, 0.26).translate(0, -0.05, 0), new THREE.BoxGeometry(0.02, 0.1, 0.26)]), lift: 0.06 },
  };
}

// 3D view of the factory: buildings as small animated models, belts and the items
// on them as instanced meshes that are refreshed every frame.
export function createFactoryView(renderer) {
  const group = new THREE.Group();
  const modelsGroup = new THREE.Group();
  group.add(modelsGroup);
  const parts = buildingParts();
  const views = new Map(); // building -> model view

  // Each belt tier has its own rail colour and a chevron texture scrolling at its speed.
  const baseTex = chevronTexture(renderer.capabilities.getMaxAnisotropy());
  const bedMat = new THREE.MeshStandardMaterial({ color: STEEL, roughness: 0.7, metalness: 0.3, flatShading: true });
  const tiers = BELT_TIERS.map((t, i) => {
    const tex = i ? baseTex.clone() : baseTex;
    return {
      speed: t.speed,
      tex,
      mats: {
        bed: bedMat,
        rails: new THREE.MeshStandardMaterial({ color: t.color, roughness: 0.5, metalness: 0.2, flatShading: true }),
        surface: new THREE.MeshStandardMaterial({ map: tex, roughness: 0.9 }),
      },
    };
  });
  const MAX_BELTS = 64 * 64;
  const beltMeshes = {}; // `${shape}${tier}` -> [bed, rails, surface]
  for (const shape of Object.keys(BELT_PATHS)) {
    const geos = beltGeometries(shape);
    tiers.forEach((tier, t) => {
      beltMeshes[shape + t] = Object.entries(geos).map(([part, geo]) => {
        const mesh = new THREE.InstancedMesh(geo, tier.mats[part], MAX_BELTS);
        mesh.count = 0;
        mesh.castShadow = part !== 'surface';
        mesh.receiveShadow = true;
        mesh.frustumCulled = false;
        group.add(mesh);
        return mesh;
      });
    });
  }
  // Drill bodies take the colour of the belt tier that matches their research level.
  const drillMat = flat(SIGNAL, { roughness: 0.5 });

  const MAX_ITEMS = 6000;
  const itemMat = new THREE.MeshStandardMaterial({ roughness: 0.45, metalness: 0.35, flatShading: true });
  const shapes = itemShapes();
  const itemMeshes = Object.fromEntries(
    Object.entries(shapes).map(([k, s]) => {
      const mesh = new THREE.InstancedMesh(s.geo, itemMat, MAX_ITEMS);
      mesh.count = 0;
      mesh.castShadow = true;
      mesh.frustumCulled = false;
      group.add(mesh);
      return [k, mesh];
    }),
  );
  const itemColors = Object.fromEntries(Object.entries(ITEMS).map(([k, it]) => [k, new THREE.Color(it.color)]));

  const dummy = new THREE.Object3D();
  let drillSpeed = 1;

  function makeModel(b) {
    const { g, m } = parts;
    const root = new THREE.Group();
    const add = (geo, mat, shadow = true) => {
      const mesh = new THREE.Mesh(geo, mat);
      mesh.castShadow = shadow;
      mesh.receiveShadow = true;
      root.add(mesh);
      return mesh;
    };
    const view = { root, phase: Math.random() * 10, owned: [] };
    // Materials that animate per building are owned by the view and disposed with it.
    const own = (mat) => (view.owned.push(mat), mat);
    const lamp = (x, y, z) => {
      view.lamp = add(g.lamp, own(new THREE.MeshStandardMaterial({ color: LAMP.idle, emissive: LAMP.idle, emissiveIntensity: 1.2 })), false);
      view.lamp.position.set(x, y, z);
    };

    if (b.type === 'drill') {
      add(g.foot, m.steel);
      add(g.body, drillMat);
      add(g.roof, m.dark);
      add(g.chute, m.dark);
      add(g.chuteOre, m.ore[b.tile.ore]);
      add(g.panel, m.ore[b.tile.ore]);
      add(g.mast, m.chrome);
      view.rotor = add(g.rotor, m.dark);
      view.rotor.position.y = 0.98;
      view.piston = add(g.piston, m.steel);
      view.piston.position.set(0, 0.64, 0.06);
      lamp(0.24, 0.6, 0.28);
    } else if (b.type === 'furnace') {
      add(g.kilnFoot, m.steel);
      add(g.kiln, m.brick);
      add(g.kilnBands, m.dark);
      add(g.kilnRoof, m.soot);
      add(g.chimney, m.soot);
      add(g.chimneyCap, m.dark);
      add(g.mouthFrame, m.dark);
      add(g.tray, m.dark);
      view.glow = own(new THREE.MeshStandardMaterial({ color: 0x3a1a0a, emissive: GLOW, emissiveIntensity: 0.2, roughness: 1 }));
      add(g.mouth, view.glow, false);
      add(g.sideGlow, view.glow, false);
      view.puffs = [0, 1, 2].map((i) => {
        const puff = add(g.puff, m.smoke, false);
        puff.position.set(0.18, 1.2, 0.2);
        puff.userData.offset = i / 3;
        return puff;
      });
      lamp(0.3, 0.52, -0.25);
    } else if (b.type === 'assembler') {
      add(g.kilnFoot, m.steel);
      add(g.posts, m.steel);
      add(g.table, m.dark);
      add(g.die, m.chrome);
      add(g.head, m.signal);
      add(g.headStripe, m.dark);
      add(g.tray, m.dark);
      view.press = add(g.press, m.chrome);
      view.press.add(new THREE.Mesh(g.ram, m.steel));
      view.press.position.set(0, 0.55, 0.04);
      lamp(0.3, 0.9, -0.25);
    } else if (b.type === 'splitter' || b.type === 'merger') {
      const body = b.type === 'splitter' ? m.splitter : m.merger;
      add(g.hubFoot, m.dark);
      add(g.hub, body);
      add(b.type === 'splitter' ? g.mouths : g.inlets, m.dark);
      if (b.type === 'merger') add(g.mouth1, m.signal);
      add(g.hubRing, m.steel);
      view.spinner = add(g.diverter, m.signal);
      view.spinner.position.y = 0.46;
      view.seen = b.passed;
      view.turn = 0;
    } else if (b.type === 'constructor') {
      add(g.bigFoot, m.steel);
      add(g.shop, m.shop);
      add(g.shopRoof, m.dark);
      add(g.hoppers, m.chrome);
      add(g.window, m.glass);
      add(g.tray, m.dark);
      view.gear = add(g.gearWheel, m.signal);
      view.gear.position.set(0.43, 0.38, 0.12);
      const base = add(g.armBase, m.dark);
      base.position.set(-0.22, 0.05, -0.3);
      view.arm = new THREE.Group();
      view.arm.position.set(-0.22, 0.12, -0.3);
      const arm = new THREE.Mesh(g.arm, m.signal);
      arm.castShadow = true;
      view.arm.add(arm);
      root.add(view.arm);
      lamp(0.3, 0.68, -0.15);
    } else if (b.type === 'storage') {
      add(g.pad, m.dark);
      add(g.crate, m.container);
      add(g.ribs, m.container);
      add(g.crateStripe, m.signal);
      add(g.hatch, m.dark);
      add(g.display, m.dark);
      lamp(0, 0.3, -0.4);
      view.seen = b.received;
      view.flash = 0;
    }

    root.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
    root.rotation.y = yaw(b.dir);
    modelsGroup.add(root);
    return view;
  }

  function dropModel(view) {
    modelsGroup.remove(view.root);
    for (const mat of view.owned) mat.dispose();
  }

  // Bring building models and belt instances in line with the factory after a change.
  function rebuild(factory) {
    const alive = new Set();
    const counts = Object.fromEntries(Object.keys(beltMeshes).map((k) => [k, 0]));
    for (const b of factory.buildings.values()) {
      if (b.type === 'belt') {
        const key = b.shape + b.tier;
        const i = counts[key]++;
        dummy.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
        dummy.rotation.set(0, yaw(b.dir), 0);
        dummy.updateMatrix();
        for (const mesh of beltMeshes[key]) mesh.setMatrixAt(i, dummy.matrix);
        continue;
      }
      alive.add(b);
      let view = views.get(b);
      if (!view) views.set(b, (view = makeModel(b)));
      view.root.rotation.y = yaw(b.dir);
    }
    for (const [shape, meshes] of Object.entries(beltMeshes)) {
      for (const mesh of meshes) {
        mesh.count = counts[shape];
        mesh.instanceMatrix.needsUpdate = true;
      }
    }
    for (const [b, view] of views) {
      if (alive.has(b)) continue;
      dropModel(view);
      views.delete(b);
    }
  }

  // World position of an item on a belt, following the belt's shape.
  const itemPos = new THREE.Vector3();
  function placeItem(b, item, lift) {
    const c = b.tile.position;
    const f = DIRS[b.dir];
    const d = DIRS[item.from];
    const p = item.p;
    let x;
    let z;
    let heading = b.dir;
    if (item.from === b.dir) {
      x = c.x + f.x * (p - 0.5);
      z = c.z + f.z * (p - 0.5);
    } else if (b.shape !== 'straight') {
      // Quarter circle around the corner shared by the entry and exit edges.
      const kx = c.x + (f.x - d.x) * 0.5;
      const kz = c.z + (f.z - d.z) * 0.5;
      const a = (p * Math.PI) / 2;
      x = kx + (-f.x * Math.cos(a) + d.x * Math.sin(a)) * 0.5;
      z = kz + (-f.z * Math.cos(a) + d.z * Math.sin(a)) * 0.5;
      heading = item.from + (b.dir - item.from === 1 || b.dir - item.from === -3 ? p : -p);
    } else if (p < 0.5) {
      // Side-loaded onto a straight belt: in from the side, then along the belt.
      x = c.x - d.x * (0.5 - p);
      z = c.z - d.z * (0.5 - p);
      heading = item.from;
    } else {
      x = c.x + f.x * (p - 0.5);
      z = c.z + f.z * (p - 0.5);
    }
    itemPos.set(x, b.tile.height + BELT_TOP + lift, z);
    return heading;
  }

  function update(dt, elapsed, factory) {
    for (const tier of tiers) {
      tier.tex.offset.y -= tier.speed * CHEVRONS_PER_TILE * dt;
      tier.tex.offset.y %= 1;
    }
    const { researched } = factory.progress;
    const drillLevel = researched.has('drill3') ? 2 : researched.has('drill2') ? 1 : 0;
    drillMat.color.setHex(BELT_TIERS[drillLevel].color);
    drillSpeed = factory.progress.speed.drill;

    const n = Object.fromEntries(Object.keys(shapes).map((k) => [k, 0]));
    for (const b of factory.buildings.values()) {
      if (b.type !== 'belt') continue;
      for (const item of b.items) {
        const shape = ITEMS[item.kind].shape;
        const s = shapes[shape];
        if (n[shape] >= MAX_ITEMS) continue;
        const heading = placeItem(b, item, s.lift);
        dummy.position.copy(itemPos);
        if (s.tumble) dummy.rotation.set(item.spin, item.spin * 1.7, 0);
        else dummy.rotation.set(0, yaw(heading), 0);
        dummy.updateMatrix();
        itemMeshes[shape].setMatrixAt(n[shape], dummy.matrix);
        itemMeshes[shape].setColorAt(n[shape], itemColors[item.kind]);
        n[shape]++;
      }
    }
    for (const [shape, mesh] of Object.entries(itemMeshes)) {
      mesh.count = n[shape];
      mesh.instanceMatrix.needsUpdate = true;
      if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    }

    for (const [b, view] of views) animate(b, view, dt, elapsed);
  }

  function setLamp(view, state, elapsed) {
    const col = LAMP[state];
    view.lamp.material.color.setHex(col);
    view.lamp.material.emissive.setHex(col);
    const steady = state === 'work' || state === 'idle';
    view.lamp.material.emissiveIntensity = steady ? 1.2 : 0.8 + Math.sin(elapsed * 6) * 0.6;
  }

  function animate(b, view, dt, elapsed) {
    const working = b.state === 'work';
    if (working) view.phase += dt;
    if (b.type === 'drill') {
      if (working) view.rotor.rotation.y += dt * 7 * drillSpeed;
      view.piston.position.y = 0.64 + (working ? Math.sin(view.phase * 9 * drillSpeed) * 0.035 : 0);
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'furnace') {
      const target = working ? 2.2 + Math.sin(elapsed * 13) * 0.3 + Math.sin(elapsed * 7.3) * 0.25 : 0.25;
      view.glow.emissiveIntensity += (target - view.glow.emissiveIntensity) * Math.min(1, dt * 4);
      for (const puff of view.puffs) {
        const t = (view.phase * 0.5 + puff.userData.offset) % 1;
        puff.visible = working || t > 0.05;
        puff.position.set(0.18 + Math.sin(t * 5 + puff.userData.offset * 9) * 0.05, 1.22 + t * 0.7, 0.2 + t * 0.15);
        puff.scale.setScalar(working ? 0.5 + t * 1.2 : Math.max(0, 1 - t) * 0.6);
        puff.rotation.y = t * 3;
      }
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'assembler') {
      // A quick stamp near the end of each cycle, then lift again.
      const t = working ? (view.phase * 1.25) % 1 : 0;
      const down = t < 0.7 ? 0 : Math.sin(((t - 0.7) / 0.3) * Math.PI);
      view.press.position.y = 0.55 - down * 0.22;
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'splitter' || b.type === 'merger') {
      // The diverter swings towards each exit (or from each inlet) as items pass.
      if (b.passed !== view.seen) {
        view.seen = b.passed;
        view.turn += 1;
      }
      const target = b.type === 'splitter' ? [0, 1, -1][(b.next + 2) % 3] * (Math.PI / 2) : view.turn * (Math.PI / 2);
      view.spinner.rotation.y += (target - view.spinner.rotation.y) * Math.min(1, dt * 12);
    } else if (b.type === 'constructor') {
      if (working) {
        view.gear.rotation.x += dt * 4;
        view.arm.rotation.y = Math.sin(view.phase * 3) * 0.9;
      }
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'storage') {
      if (b.received !== view.seen) {
        view.seen = b.received;
        view.flash = 0.25;
      }
      view.flash = Math.max(0, view.flash - dt);
      setLamp(view, view.flash > 0 ? 'work' : 'idle', elapsed);
      view.lamp.material.emissiveIntensity = view.flash > 0 ? 2 : 0.5;
    }
  }

  function clear() {
    for (const view of views.values()) dropModel(view);
    views.clear();
    for (const meshes of Object.values(beltMeshes)) for (const mesh of meshes) mesh.count = 0;
    for (const mesh of Object.values(itemMeshes)) mesh.count = 0;
  }

  return { group, rebuild, update, clear };
}

// Translucent preview of the building under the cursor: footprint, direction arrow
// and a rough silhouette, green when it can be built and red when not.
export function createGhost() {
  const group = new THREE.Group();
  group.visible = false;
  const mat = (opacity) => new THREE.MeshBasicMaterial({ color: 0x7ee08a, transparent: true, opacity, depthWrite: false });
  const footMat = mat(0.32);
  const bodyMat = mat(0.28);
  const arrowMat = mat(0.9);

  const foot = new THREE.Mesh(new THREE.PlaneGeometry(0.96, 0.96).rotateX(-Math.PI / 2), footMat);
  foot.position.y = 0.02;
  group.add(foot);

  const arrowShape = new THREE.Shape();
  arrowShape.moveTo(0, 0.36);
  arrowShape.lineTo(0.24, 0.08);
  arrowShape.lineTo(0.09, 0.08);
  arrowShape.lineTo(0.09, -0.3);
  arrowShape.lineTo(-0.09, -0.3);
  arrowShape.lineTo(-0.09, 0.08);
  arrowShape.lineTo(-0.24, 0.08);
  arrowShape.closePath();
  // The shape points to +y; lying flat it points to -z, the local forward.
  const arrow = new THREE.Mesh(new THREE.ShapeGeometry(arrowShape).rotateX(-Math.PI / 2), arrowMat);
  arrow.renderOrder = 2;
  const pivot = new THREE.Group();
  pivot.add(arrow);
  group.add(pivot);

  const box = (w, h, d, z = 0) => new THREE.BoxGeometry(w, h, d).translate(0, h / 2, z);
  const shapes = {
    drill: { geo: box(0.66, 0.6, 0.62, 0.04), arrow: 0.64 },
    belt: { geo: box(0.84, 0.12, 1), arrow: 0.16 },
    storage: { geo: box(0.86, 0.58, 0.8), arrow: null },
    furnace: { geo: mergeGeometries([box(0.74, 0.66, 0.68, 0.06), box(0.2, 1.2, 0.2).translate(0.18, 0, 0.2)]), arrow: 0.7 },
    assembler: { geo: box(0.76, 0.86, 0.72, 0.04), arrow: 0.9 },
    splitter: { geo: box(0.86, 0.4, 0.86), arrow: 0.5 },
    merger: { geo: box(0.86, 0.4, 0.86), arrow: 0.5 },
    constructor: { geo: mergeGeometries([box(0.84, 0.66, 0.7, 0.1), box(0.5, 0.25, 0.2).translate(0, 0.66, 0.18)]), arrow: 0.95 },
  };
  const meshes = Object.fromEntries(Object.entries(shapes).map(([k, s]) => [k, new THREE.Mesh(s.geo, bodyMat)]));
  for (const s of Object.values(meshes)) pivot.add(s);

  function show(tool, tile, dir, ok) {
    if (!tool || !tile) {
      group.visible = false;
      return;
    }
    group.visible = true;
    group.position.set(tile.position.x, tile.height, tile.position.z);
    pivot.rotation.y = yaw(dir);
    for (const [k, s] of Object.entries(meshes)) s.visible = k === tool;
    const arrowY = shapes[tool]?.arrow ?? null;
    arrow.visible = arrowY !== null;
    arrow.position.y = arrowY ?? 0;
    const col = tool === 'remove' ? (ok ? 0xff6b5b : 0x9aa0a6) : ok ? 0x7ee08a : 0xff6b5b;
    for (const m of [footMat, bodyMat, arrowMat]) m.color.setHex(col);
  }

  return { group, show };
}
