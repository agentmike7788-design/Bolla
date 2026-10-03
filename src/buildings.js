import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { DIRS, ITEMS, POLE_SUPPLY, isFluid, SILO_STAGES } from './factory.js';
import { trackPoint, isTrack, CAR_GAP, CARS, WAGON_CARGO, STATION_CAP } from './trains.js';
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

// Track pieces in local space, running towards -z: a straight tile, a curve that
// enters over the left edge like a belt curve, and an arm from the middle to the
// front edge for junctions.
const RAIL_PATHS = {
  straight: BELT_PATHS.straight,
  curve: BELT_PATHS.left,
  arm: { length: 0.5, at: (t) => [0, -0.5 * t] },
};
export const RAIL_TOP = 0.11; // top of the rails above the tile

function railGeometries(shape) {
  const path = RAIL_PATHS[shape];
  const n = shape === 'curve' ? 12 : 1;
  const count = Math.max(2, Math.round(path.length * 4));
  const sleepers = [];
  for (let i = 0; i < count; i++) {
    const t = (i + 0.5) / count;
    const [x, z] = path.at(t);
    const [ax, az] = path.at(Math.max(0, t - 0.01));
    const [bx, bz] = path.at(Math.min(1, t + 0.01));
    sleepers.push(new THREE.BoxGeometry(0.64, 0.05, 0.11).rotateY(Math.atan2(-(bx - ax), -(bz - az))).translate(x, 0.05, z));
  }
  return {
    ballast: sweepBox(path, { u0: -0.42, u1: 0.42, y0: -0.06, y1: 0.025 }, n),
    sleepers: mergeGeometries(sleepers),
    rails: mergeGeometries([
      sweepBox(path, { u0: -0.24, u1: -0.18, y0: 0.06, y1: RAIL_TOP }, n),
      sweepBox(path, { u0: 0.18, u1: 0.24, y0: 0.06, y1: RAIL_TOP }, n),
    ]),
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

// The rocket, standing with its engines at y = 0 and its nose about 5 tiles up.
// `hull` is body, boosters and fins, `nose` the payload fairing on top, `flame`
// the exhaust under the engines (hidden until it burns). Used by the silo model
// and by the launch, see launch.js.
const ROCKET_PARTS = (() => {
  let made = null;
  return () => {
    if (made) return made;
    const cyl = (r0, r1, h, y, x = 0, z = 0, seg = 20) => new THREE.CylinderGeometry(r0, r1, h, seg).translate(x, y + h / 2, z);
    const g = {
      body: cyl(0.3, 0.3, 3.2, 0.5),
      skirt: cyl(0.3, 0.37, 0.32, 0.18),
      bells: mergeGeometries([[0, 0.15], [0.13, -0.08], [-0.13, -0.08]].map(([x, z]) => cyl(0.06, 0.12, 0.2, 0, x, z, 10))),
      bands: mergeGeometries([cyl(0.305, 0.305, 0.1, 2.55), cyl(0.305, 0.305, 0.05, 1.2)]),
      stripe: cyl(0.306, 0.306, 0.3, 3.1),
      fins: mergeGeometries([0, 1, 2, 3].map((i) => new THREE.BoxGeometry(0.035, 0.6, 0.32).translate(0, 0.65, 0.42).rotateY((i * Math.PI) / 2 + Math.PI / 4))),
      boosters: mergeGeometries([-1, 1].flatMap((sx) => [cyl(0.14, 0.14, 1.9, 0.35, sx * 0.45), new THREE.ConeGeometry(0.14, 0.4, 14).translate(sx * 0.45, 2.45, 0), cyl(0.08, 0.13, 0.18, 0.17, sx * 0.45)])),
      struts: mergeGeometries([-1, 1].flatMap((sx) => [0.7, 2.0].map((y) => new THREE.BoxGeometry(0.2, 0.04, 0.04).translate(sx * 0.33, y, 0)))),
      fairing: cyl(0.3, 0.3, 0.5, 3.7),
      cone: new THREE.ConeGeometry(0.3, 0.95, 20).translate(0, 4.2 + 0.475, 0),
      tip: cyl(0.015, 0.015, 0.25, 5.1, 0, 0, 6),
      windows: mergeGeometries([0, 1, 2, 3].map((i) => new THREE.BoxGeometry(0.08, 0.08, 0.02).translate(0, 3.95, 0.305).rotateY((i * Math.PI) / 2))),
      flame: new THREE.ConeGeometry(0.28, 1.6, 16, 1, true).rotateX(Math.PI).translate(0, -0.8, 0),
      core: new THREE.ConeGeometry(0.14, 0.9, 12, 1, true).rotateX(Math.PI).translate(0, -0.45, 0),
    };
    const m = {
      white: flat(0xf1eee8, { roughness: 0.45, metalness: 0.15 }),
      black: flat(0x24272b, { roughness: 0.5 }),
      orange: flat(0xff6a3d, { roughness: 0.5 }),
      metal: new THREE.MeshStandardMaterial({ color: 0x8d949b, roughness: 0.3, metalness: 0.85 }),
      window: new THREE.MeshStandardMaterial({ color: 0x0f2a38, emissive: 0x7fd4ff, emissiveIntensity: 0.8, roughness: 0.2 }),
      flame: new THREE.MeshBasicMaterial({ color: 0xff8a2a, transparent: true, opacity: 0.75, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }),
      core: new THREE.MeshBasicMaterial({ color: 0xfff2c0, transparent: true, opacity: 0.95, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }),
    };
    made = { g, m };
    return made;
  };
})();

export function createRocket() {
  const { g, m } = ROCKET_PARTS();
  const group = new THREE.Group();
  const part = (parent, geo, mat, shadow = true) => {
    const mesh = new THREE.Mesh(geo, mat);
    mesh.castShadow = shadow;
    mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  };
  const hull = new THREE.Group();
  const nose = new THREE.Group();
  group.add(hull, nose);
  part(hull, g.body, m.white);
  part(hull, g.skirt, m.black);
  part(hull, g.bells, m.metal);
  part(hull, g.bands, m.black);
  part(hull, g.fins, m.orange);
  part(hull, g.boosters, m.white);
  part(hull, g.struts, m.metal);
  part(nose, g.stripe, m.orange);
  part(nose, g.fairing, m.white);
  part(nose, g.cone, m.white);
  part(nose, g.tip, m.metal);
  part(nose, g.windows, m.window, false);
  const flame = new THREE.Group();
  part(flame, g.flame, m.flame, false);
  part(flame, g.core, m.core, false);
  flame.visible = false;
  group.add(flame);
  return { group, hull, nose, flame };
}

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
    // Coal power plant: a boiler hall with a firebox, a coal bunker, a striped
    // smokestack and a fan on the roof.
    hall: rbox(0.6, 0.5, 0.62, -0.1, 0.35, 0.06, 0.05),
    hallRoof: box(0.66, 0.05, 0.68, -0.1, 0.62, 0.06),
    firebox: box(0.3, 0.16, 0.03, -0.1, 0.27, -0.255),
    fireFrame: box(0.38, 0.24, 0.04, -0.1, 0.27, -0.24),
    stack: new THREE.CylinderGeometry(0.08, 0.12, 1.36, 10).translate(0.3, 0.78, 0.26),
    stackBands: mergeGeometries([1.0, 1.32].map((y) => new THREE.CylinderGeometry(0.093, 0.097, 0.1, 10).translate(0.3, y, 0.26))),
    bunker: new THREE.CylinderGeometry(0.15, 0.07, 0.3, 8).translate(0.3, 0.32, -0.22),
    bunkerLegs: mergeGeometries([-1, 1].map((sx) => box(0.03, 0.2, 0.03, 0.3 + sx * 0.09, 0.12, -0.22))),
    coalHeap: new THREE.ConeGeometry(0.13, 0.09, 8).translate(0.3, 0.5, -0.22),
    fanRing: new THREE.CylinderGeometry(0.17, 0.17, 0.06, 14, 1, true).translate(-0.1, 0.67, 0.06),
    // Power pole: a wooden mast with a crossbar and two insulators.
    poleFoot: rbox(0.26, 0.08, 0.26, 0, 0.04, 0, 0.02),
    mastPole: new THREE.CylinderGeometry(0.035, 0.05, 1.5, 7).translate(0, 0.8, 0),
    crossbar: box(0.56, 0.05, 0.06, 0, 1.46, 0),
    brace: mergeGeometries([-1, 1].map((sx) => box(0.025, 0.26, 0.025, 0, 0, 0).rotateZ(sx * 0.7).translate(sx * 0.08, 1.36, 0))),
    insulators: mergeGeometries([-0.22, 0.22].map((x) => new THREE.CylinderGeometry(0.025, 0.035, 0.09, 8).translate(x, 1.53, 0))),
    // Oil pump: a pumpjack. The walking beam nods on an A-frame, the horse head
    // over the well at the front, the crank with its counterweights at the back.
    jackBase: mergeGeometries([box(0.3, 0.08, 0.9, 0, 0.04, 0), box(0.5, 0.06, 0.22, 0, 0.03, 0.28)]),
    wellhead: mergeGeometries([new THREE.CylinderGeometry(0.07, 0.09, 0.2, 8).translate(0, 0.1, -0.34), new THREE.CylinderGeometry(0.1, 0.1, 0.04, 8).translate(0, 0.2, -0.34)]),
    samson: mergeGeometries([-1, 1].flatMap((sx) => [-1, 1].map((sz) => box(0.04, 0.68, 0.04, 0, 0, 0).rotateX(sz * 0.22).rotateZ(sx * 0.18).translate(sx * 0.07, 0.38, sz * 0.07)))),
    beam: box(0.08, 0.08, 0.86, 0, 0, 0.02),
    horsehead: new THREE.CylinderGeometry(0.17, 0.17, 0.09, 12, 1, false, Math.PI * 0.5, Math.PI).rotateZ(Math.PI / 2).translate(0, -0.02, -0.4),
    gearbox: rbox(0.2, 0.16, 0.18, 0, 0.16, 0.3, 0.03),
    crank: mergeGeometries([box(0.3, 0.05, 0.05, 0, 0, 0), ...[-1, 1].map((sx) => new THREE.CylinderGeometry(0.11, 0.11, 0.05, 10, 1, false, 0, Math.PI).rotateZ(Math.PI / 2).translate(sx * 0.15, 0, 0).rotateX(Math.PI))]),
    pitman: mergeGeometries([-1, 1].map((sx) => box(0.025, 0.36, 0.025, sx * 0.13, -0.18, 0))),
    rod: new THREE.CylinderGeometry(0.012, 0.012, 0.5, 5).translate(0, -0.25, 0),
    // Pipes: a hub with a flange on a small post, and an arm towards each linked side.
    pipeHub: mergeGeometries([new THREE.SphereGeometry(0.105, 10, 8), box(0.05, 0.3, 0.05, 0, -0.17, 0), box(0.18, 0.03, 0.18, 0, -0.31, 0)]),
    pipeArm: mergeGeometries([new THREE.CylinderGeometry(0.075, 0.075, 0.5, 10).rotateX(Math.PI / 2).translate(0, 0, -0.25), new THREE.CylinderGeometry(0.098, 0.098, 0.05, 10).rotateX(Math.PI / 2).translate(0, 0, -0.46)]),
    flowRing: new THREE.CylinderGeometry(0.088, 0.088, 0.09, 10).rotateX(Math.PI / 2),
    // Oil tank: a white drum with a dome, a ladder and a gauge that shows the level.
    tankFoot: new THREE.CylinderGeometry(0.44, 0.46, 0.08, 18).translate(0, 0.04, 0),
    drum: new THREE.CylinderGeometry(0.38, 0.38, 0.62, 18).translate(0, 0.39, 0),
    drumBands: mergeGeometries([0.22, 0.56].map((y) => new THREE.CylinderGeometry(0.39, 0.39, 0.04, 18).translate(0, y, 0))),
    dome: new THREE.SphereGeometry(0.38, 18, 6, 0, Math.PI * 2, 0, Math.PI / 2).scale(1, 0.35, 1).translate(0, 0.7, 0),
    ladder: mergeGeometries([-0.05, 0.05].map((x) => box(0.015, 0.7, 0.015, x, 0.4, 0)).concat([0.15, 0.3, 0.45, 0.6].map((y) => box(0.1, 0.012, 0.012, 0, y, 0)))).translate(0, 0, 0.395),
    gaugeBack: box(0.09, 0.5, 0.02, 0, 0.39, -0.385),
    gauge: box(0.06, 0.46, 0.02, 0, 0.23, 0),
    // Refinery: two distillation columns, a heater box, a flare and a hopper out front.
    refFoot: rbox(0.94, 0.08, 0.94, 0, 0.04, 0, 0.03),
    heater: rbox(0.42, 0.3, 0.36, -0.2, 0.23, 0.18, 0.04),
    columnA: new THREE.CylinderGeometry(0.12, 0.12, 1.1, 12).translate(0.2, 0.63, 0.14),
    columnB: new THREE.CylinderGeometry(0.09, 0.09, 0.8, 12).translate(0.24, 0.48, -0.16),
    columnRings: mergeGeometries([0.4, 0.7, 1.0].map((y) => new THREE.CylinderGeometry(0.135, 0.135, 0.03, 12).translate(0.2, y, 0.14)).concat([0.4, 0.68].map((y) => new THREE.CylinderGeometry(0.105, 0.105, 0.03, 12).translate(0.24, y, -0.16)))),
    caps: mergeGeometries([new THREE.SphereGeometry(0.12, 12, 4, 0, Math.PI * 2, 0, Math.PI / 2).translate(0.2, 1.18, 0.14), new THREE.SphereGeometry(0.09, 12, 4, 0, Math.PI * 2, 0, Math.PI / 2).translate(0.24, 0.88, -0.16)]),
    refPipes: mergeGeometries([
      new THREE.CylinderGeometry(0.025, 0.025, 0.4, 6).rotateZ(Math.PI / 2).translate(0, 0.32, 0.14),
      new THREE.CylinderGeometry(0.025, 0.025, 0.3, 6).rotateX(Math.PI / 2).translate(0.2, 0.92, 0),
      new THREE.CylinderGeometry(0.025, 0.025, 0.1, 6).translate(0.24, 0.92, -0.12),
    ]),
    flare: mergeGeometries([new THREE.CylinderGeometry(0.025, 0.035, 0.95, 6).translate(-0.33, 0.5, -0.3), new THREE.CylinderGeometry(0.045, 0.03, 0.06, 8).translate(-0.33, 0.99, -0.3)]),
    flame: new THREE.ConeGeometry(0.05, 0.16, 7).translate(0, 0.08, 0),
    // Station: a roof over the track on four posts, low platforms along the sides.
    platforms: mergeGeometries([box(0.12, 0.1, 0.96, -0.42, 0.05, 0), box(0.12, 0.1, 0.96, 0.42, 0.05, 0)]),
    posts: mergeGeometries([-1, 1].flatMap((sx) => [-1, 1].map((sz) => new THREE.CylinderGeometry(0.025, 0.025, 1, 6).translate(sx * 0.42, 0.55, sz * 0.38)))),
    roof: rbox(1, 0.06, 0.9, 0, 1.06, 0, 0.02),
    fascia: mergeGeometries([box(1.02, 0.08, 0.03, 0, 1.0, -0.45), box(1.02, 0.08, 0.03, 0, 1.0, 0.45)]),
    crates: mergeGeometries([box(0.1, 0.1, 0.1, 0, 0.05, 0), box(0.1, 0.1, 0.1, 0, 0.05, 0.12), box(0.1, 0.1, 0.1, 0, 0.15, 0.06)]),
    // Train cars face -z, their floor at the top of the rails.
    chassis: box(0.5, 0.07, 0.9, 0, 0.17, 0),
    bogies: mergeGeometries([box(0.36, 0.08, 0.22, 0, 0.13, -0.28), box(0.36, 0.08, 0.22, 0, 0.13, 0.28)]),
    hood: rbox(0.4, 0.26, 0.42, 0, 0.33, -0.22, 0.05),
    cab: rbox(0.48, 0.4, 0.42, 0, 0.4, 0.2, 0.05),
    cabWindows: box(0.5, 0.11, 0.38, 0, 0.5, 0.2),
    cabRoof: box(0.52, 0.04, 0.46, 0, 0.62, 0.2),
    hoodStripe: box(0.41, 0.05, 0.43, 0, 0.3, -0.22),
    headlight: new THREE.SphereGeometry(0.04, 8, 6).translate(0, 0.38, -0.44),
    container: rbox(0.46, 0.36, 0.8, 0, 0.18, 0, 0.03),
    wagonFrame: mergeGeometries([box(0.5, 0.1, 0.03, 0, 0.25, -0.43), box(0.5, 0.1, 0.03, 0, 0.25, 0.43)]),
    // Rocket silo, 3 × 3 tiles: a slab with a skirt down to lower ground, the
    // building site with a fence and a crane, then the launch pad with its
    // flame trench and a lattice service tower with two arms.
    siloSlab: mergeGeometries([box(2.96, 0.12, 2.96, 0, 0.06, 0), box(2.9, 1.2, 2.9, 0, -0.6, 0)]),
    fence: mergeGeometries(
      [-1.35, -0.45, 0.45, 1.35].flatMap((u) => [
        box(0.05, 0.4, 0.05, u, 0.3, -1.35), box(0.05, 0.4, 0.05, u, 0.3, 1.35), box(0.05, 0.4, 0.05, -1.35, 0.3, u), box(0.05, 0.4, 0.05, 1.35, 0.3, u),
      ]),
    ),
    tape: mergeGeometries([box(2.72, 0.05, 0.02, 0, 0.42, -1.35), box(2.72, 0.05, 0.02, 0, 0.42, 1.35), box(0.02, 0.05, 2.72, -1.35, 0.42, 0), box(0.02, 0.05, 2.72, 1.35, 0.42, 0)]),
    craneMast: mergeGeometries([box(0.14, 3, 0.14, -0.95, 1.6, 0.95), box(0.4, 0.12, 0.4, -0.95, 0.18, 0.95)]),
    craneJib: mergeGeometries([box(2.1, 0.1, 0.1, 0.55, 0, 0), box(0.5, 0.18, 0.18, -0.65, -0.05, 0), new THREE.CylinderGeometry(0.008, 0.008, 1.4, 4).translate(1.4, -0.7, 0)]),
    piles: mergeGeometries([box(0.4, 0.2, 0.3, 0.7, 0.22, -0.8), box(0.4, 0.2, 0.3, 0.75, 0.42, -0.78), box(0.3, 0.3, 0.3, -0.75, 0.27, -0.7), box(0.6, 0.08, 0.2, 0.3, 0.16, 0.6), box(0.6, 0.08, 0.2, 0.3, 0.24, 0.62)]),
    pad: mergeGeometries([box(2.4, 0.42, 2.4, 0, 0.33, 0), box(1.8, 0.06, 1.8, 0, 0.57, 0)]),
    trench: box(0.7, 0.05, 1.25, 0, 0.555, -0.6),
    padRing: new THREE.TorusGeometry(0.45, 0.04, 6, 24).rotateX(Math.PI / 2).translate(0, 0.6, 0),
    tower: mergeGeometries([
      ...[-1, 1].flatMap((sx) => [-1, 1].map((sz) => box(0.07, 5.6, 0.07, 0.92 + sx * 0.2, 0.54 + 2.8, 0.92 + sz * 0.2))),
      ...[1, 1.6, 2.2, 2.8, 3.4, 4, 4.6, 5.2, 5.8].flatMap((y) => [box(0.44, 0.04, 0.04, 0.92, y, 0.72), box(0.44, 0.04, 0.04, 0.92, y, 1.12), box(0.04, 0.04, 0.44, 0.72, y, 0.92), box(0.04, 0.04, 0.44, 1.12, y, 0.92)]),
      ...[1.3, 2.5, 3.7, 4.9].flatMap((y) => [-1, 1].map((sx) => box(0.03, 0.75, 0.03, 0, 0, 0).rotateZ(sx * 0.5).translate(0.92, y, 0.72))),
      box(0.56, 0.08, 0.56, 0.92, 6.16, 0.92),
    ]),
    arms: mergeGeometries([2.6, 4.0].map((y) => box(0.1, 0.08, 0.95, 0, 0, 0).rotateY(Math.PI / 4).translate(0.55, y, 0.55))),
    fuelLine: new THREE.CylinderGeometry(0.035, 0.035, 0.64, 6).rotateZ(Math.PI / 2).rotateY(Math.PI / 4).translate(-0.475, 0.66, 0.475),
    fuelTanks: mergeGeometries([new THREE.SphereGeometry(0.22, 14, 10).translate(-0.92, 0.82, 0.55), new THREE.SphereGeometry(0.22, 14, 10).translate(-0.55, 0.82, 0.92)]),
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
    concrete: flat(0xb3ada1, { roughness: 0.85, metalness: 0.05 }),
    white: flat(0xe8e4dc, { roughness: 0.7 }),
    red: flat(0xc8402e, { roughness: 0.6 }),
    wood: flat(0x7a5536, { roughness: 0.9, metalness: 0 }),
    porcelain: new THREE.MeshStandardMaterial({ color: 0x9fd6c0, roughness: 0.25, metalness: 0.1 }),
    jack: flat(0x2f5f8f, { roughness: 0.5 }),
    oilBlack: new THREE.MeshStandardMaterial({ color: 0x15131a, roughness: 0.15, metalness: 0.5 }),
    pipe: flat(0x8a9198, { roughness: 0.4, metalness: 0.6 }),
    tank: flat(0xe6e2d8, { roughness: 0.55 }),
    refinery: flat(0xc9cdd0, { roughness: 0.35, metalness: 0.55 }),
    flame: new THREE.MeshBasicMaterial({ color: 0xffa040, transparent: true, opacity: 0.9, depthWrite: false }),
    ballast: flat(0x8a8178, { roughness: 1, metalness: 0 }),
    sleeper: flat(0x5a4030, { roughness: 0.9, metalness: 0 }),
    rail: new THREE.MeshStandardMaterial({ color: 0xa9b0b6, roughness: 0.3, metalness: 0.85 }),
    platform: flat(0xc9c2b4, { roughness: 0.85, metalness: 0.05 }),
    roof: flat(0x34536b, { roughness: 0.6 }),
    loco: flat(0xc8402e, { roughness: 0.45 }),
    pad: flat(0x6f6a62, { roughness: 0.9, metalness: 0.05 }),
    tower: flat(0xc8402e, { roughness: 0.55, metalness: 0.4 }),
    ore: Object.fromEntries(Object.entries(ORES).map(([k, o]) => [k, flat(o.color, { roughness: 0.4, metalness: 0.3 })])),
  };
  return { g, m };
}

const MODE_COLOR = { load: 0x3fae5a, unload: 0xe07a2e };
const LAMP = { work: 0x6be36b, blocked: 0xffb02e, empty: 0xff5544, idle: 0x5aa9ff, nopower: 0xb46bff };
const WIRE_HEIGHT = 1.53; // insulators above the tile
const INSULATOR = 0.22; // insulators sideways from the mast
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
    beam: {
      geo: mergeGeometries([
        new THREE.BoxGeometry(0.08, 0.02, 0.26).translate(0, 0.05, 0),
        new THREE.BoxGeometry(0.08, 0.02, 0.26).translate(0, -0.05, 0),
        new THREE.BoxGeometry(0.02, 0.1, 0.26),
      ]),
      lift: 0.06,
    },
    roll: { geo: mergeGeometries([new THREE.CylinderGeometry(0.075, 0.075, 0.2, 10).rotateZ(Math.PI / 2), new THREE.CylinderGeometry(0.03, 0.03, 0.22, 6).rotateZ(Math.PI / 2)]), lift: 0.075 },
    canister: {
      geo: mergeGeometries([
        new RoundedBoxGeometry(0.15, 0.18, 0.09, 2, 0.02).translate(0, 0.09, 0),
        new THREE.CylinderGeometry(0.02, 0.02, 0.04, 6).translate(0.04, 0.19, 0),
        new THREE.BoxGeometry(0.07, 0.025, 0.025).translate(-0.03, 0.19, 0),
      ].map((g) => g.toNonIndexed())),
      lift: 0,
    },
    cpu: {
      geo: mergeGeometries([
        new THREE.BoxGeometry(0.2, 0.025, 0.2),
        new THREE.BoxGeometry(0.12, 0.03, 0.12).translate(0, 0.025, 0),
        ...[-1, 1].map((s) => new THREE.BoxGeometry(0.24, 0.01, 0.02).translate(0, -0.005, s * 0.06)),
      ]),
      lift: 0.015,
    },
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

  const beltTex = chevronTexture(renderer.capabilities.getMaxAnisotropy());
  const beltMats = {
    bed: new THREE.MeshStandardMaterial({ color: STEEL, roughness: 0.7, metalness: 0.3, flatShading: true }),
    rails: new THREE.MeshStandardMaterial({ color: SIGNAL, roughness: 0.5, metalness: 0.2, flatShading: true }),
    surface: new THREE.MeshStandardMaterial({ map: beltTex, roughness: 0.9 }),
  };
  const MAX_BELTS = 96 * 96;
  const beltMeshes = {};
  for (const shape of Object.keys(BELT_PATHS)) {
    const geos = beltGeometries(shape);
    beltMeshes[shape] = Object.entries(geos).map(([part, geo]) => {
      const mesh = new THREE.InstancedMesh(geo, beltMats[part], MAX_BELTS);
      mesh.count = 0;
      mesh.castShadow = part !== 'surface';
      mesh.receiveShadow = true;
      mesh.frustumCulled = false;
      group.add(mesh);
      return mesh;
    });
  }

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

  // Power lines between poles, sagging a little, rebuilt when the grid changes.
  const wireMat = new THREE.MeshStandardMaterial({ color: 0x2b2826, roughness: 0.6, metalness: 0.4 });
  const wires = new THREE.Mesh(new THREE.BufferGeometry(), wireMat);
  wires.castShadow = true;
  wires.frustumCulled = false;
  group.add(wires);
  let gridVersion = -1;

  // The squares poles supply, shown while building power and machines.
  const MAX_AREAS = 1024;
  const areaSize = POLE_SUPPLY * 2 + 1;
  const areaMat = new THREE.MeshBasicMaterial({ color: 0x7fd4ff, transparent: true, opacity: 0.13, depthWrite: false });
  const areas = new THREE.InstancedMesh(new THREE.PlaneGeometry(areaSize - 0.06, areaSize - 0.06).rotateX(-Math.PI / 2), areaMat, MAX_AREAS);
  areas.count = 0;
  areas.visible = false;
  areas.frustumCulled = false;
  areas.renderOrder = 1;
  group.add(areas);

  // Pipes: hubs and arms as instances, rebuilt when the pipe networks change, and
  // glowing rings that run along them with the oil, away from the pumps.
  const PIPE_Y = 0.34;
  const MAX_PIPES = 96 * 96;
  const pipeHubs = new THREE.InstancedMesh(parts.g.pipeHub, parts.m.pipe, MAX_PIPES);
  const pipeArms = new THREE.InstancedMesh(parts.g.pipeArm, parts.m.pipe, MAX_PIPES * 4);
  const ringMat = new THREE.MeshStandardMaterial({ color: 0x4a2a08, emissive: 0xffb347, emissiveIntensity: 1.6, roughness: 0.4 });
  const flowRings = new THREE.InstancedMesh(parts.g.flowRing, ringMat, MAX_PIPES * 4);
  for (const mesh of [pipeHubs, pipeArms, flowRings]) {
    mesh.count = 0;
    mesh.frustumCulled = false;
    mesh.castShadow = mesh !== flowRings;
    mesh.receiveShadow = true;
    group.add(mesh);
  }
  let pipesVersion = -1;
  let flowArms = []; // { b, d, out }: an arm the oil runs along, out of or into its tile
  const flowPhase = new WeakMap(); // pipe network -> where its rings are, 0..1

  function rebuildPipes(factory) {
    let hubs = 0;
    let arms = 0;
    flowArms = [];
    for (const b of factory.buildings.values()) {
      if (!isFluid(b)) continue;
      const y = b.tile.height + PIPE_Y;
      if (b.type === 'pipe') {
        dummy.position.set(b.tile.position.x, y, b.tile.position.z);
        dummy.rotation.set(0, 0, 0);
        dummy.updateMatrix();
        pipeHubs.setMatrixAt(hubs++, dummy.matrix);
      }
      // A pipe on its own lies along its build direction.
      const sides = b.links.length || b.type !== 'pipe' ? b.links : [b.dir, (b.dir + 2) % 4];
      for (const d of sides) {
        dummy.position.set(b.tile.position.x, y, b.tile.position.z);
        dummy.rotation.set(0, yaw(d), 0);
        dummy.updateMatrix();
        pipeArms.setMatrixAt(arms++, dummy.matrix);
        const n = factory.at(b.tile.x + DIRS[d].x, b.tile.z + DIRS[d].z);
        if (n && n.depth !== b.depth && Number.isFinite(Math.min(n.depth, b.depth))) flowArms.push({ b, d, out: n.depth > b.depth });
      }
    }
    pipeHubs.count = hubs;
    pipeArms.count = arms;
    pipeHubs.instanceMatrix.needsUpdate = true;
    pipeArms.instanceMatrix.needsUpdate = true;
  }

  function updateFlow(dt, factory) {
    for (const net of factory.pipes.nets) {
      // Faster rings for more oil per second; still rings in a full, idle network.
      const speed = net.rate > 0.05 ? Math.min(2.4, 0.5 + net.rate * 0.45) : 0;
      flowPhase.set(net, ((flowPhase.get(net) ?? 0) + dt * speed) % 1);
    }
    let n = 0;
    for (const { b, d, out } of flowArms) {
      const net = b.pipes;
      if (!net || net.amount < 0.5) continue;
      // Out of the tile: from the middle to the edge; into it: from the edge to the middle.
      const u = flowPhase.get(net) ?? 0;
      const t = 0.5 * (out ? u : 1 - u);
      dummy.position.set(b.tile.position.x + DIRS[d].x * t, b.tile.height + PIPE_Y, b.tile.position.z + DIRS[d].z * t);
      dummy.rotation.set(0, yaw(d), 0);
      dummy.updateMatrix();
      flowRings.setMatrixAt(n++, dummy.matrix);
    }
    flowRings.count = n;
    flowRings.instanceMatrix.needsUpdate = true;
    ringMat.emissiveIntensity = 1.6 + night;
  }

  // Track: sleepers, rails and ballast as instances per piece, rebuilt with the factory.
  const MAX_RAILS = { straight: 96 * 96, curve: 4096, arm: 4096 };
  const railParts = { ballast: parts.m.ballast, sleepers: parts.m.sleeper, rails: parts.m.rail };
  const railMeshes = {};
  for (const shape of Object.keys(RAIL_PATHS)) {
    railMeshes[shape] = Object.entries(railGeometries(shape)).map(([part, geo]) => {
      const mesh = new THREE.InstancedMesh(geo, railParts[part], MAX_RAILS[shape]);
      mesh.count = 0;
      mesh.castShadow = part !== 'ballast';
      mesh.receiveShadow = true;
      mesh.frustumCulled = false;
      group.add(mesh);
      return mesh;
    });
  }

  // Which pieces draw a track tile: [shape, direction] pairs.
  function trackPieces(b) {
    if (b.type === 'station') return [['straight', b.dir]];
    let sides = b.links ?? [];
    if (!sides.length) sides = [0, 1, 2, 3].filter((d) => b.conn & (1 << d));
    if (!sides.length) sides = [b.dir];
    if (sides.length === 1) return [['straight', sides[0]]];
    if (sides.length === 2) {
      const [a, c] = sides;
      if ((a + 2) % 4 === c) return [['straight', a]];
      // A curve leaves towards `exit` and comes in over its left edge.
      return [['curve', c === (a + 3) % 4 ? a : c]];
    }
    return sides.map((d) => ['arm', d]);
  }

  function rebuildRails(factory) {
    const counts = { straight: 0, curve: 0, arm: 0 };
    for (const b of factory.buildings.values()) {
      if (!isTrack(b)) continue;
      for (const [shape, d] of trackPieces(b)) {
        if (counts[shape] >= MAX_RAILS[shape]) continue;
        dummy.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
        dummy.rotation.set(0, yaw(d), 0);
        dummy.updateMatrix();
        for (const mesh of railMeshes[shape]) mesh.setMatrixAt(counts[shape], dummy.matrix);
        counts[shape]++;
      }
    }
    for (const [shape, meshes] of Object.entries(railMeshes)) {
      for (const mesh of meshes) {
        mesh.count = counts[shape];
        mesh.instanceMatrix.needsUpdate = true;
      }
    }
  }

  // Trains: a few cars each, moved along their track every frame.
  const trainViews = new Map(); // train -> { root, cars: [{ root, container }], owned }
  const carPoint = {};

  function makeTrain() {
    const { g, m } = parts;
    const root = new THREE.Group();
    const owned = [];
    const cars = [];
    const add = (car, geo, mat) => {
      const mesh = new THREE.Mesh(geo, mat);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      car.add(mesh);
      return mesh;
    };
    for (let j = 0; j < CARS; j++) {
      const car = new THREE.Group();
      const entry = { root: car };
      add(car, g.chassis, m.dark);
      add(car, g.bogies, m.steel);
      if (j === 0 || j === CARS - 1) {
        add(car, g.hood, m.loco);
        add(car, g.hoodStripe, m.signal);
        add(car, g.cab, m.loco);
        add(car, g.cabWindows, m.glass);
        add(car, g.cabRoof, m.dark);
        const lampMat = new THREE.MeshStandardMaterial({ color: 0xfff2c0, emissive: 0xfff2c0, emissiveIntensity: 1 });
        owned.push(lampMat);
        entry.lamp = add(car, g.headlight, lampMat);
        entry.lamp.castShadow = false;
      } else {
        add(car, g.wagonFrame, m.steel);
        const mat = flat(0x888888, { roughness: 0.55 });
        owned.push(mat);
        entry.container = add(car, g.container, mat);
        entry.container.position.y = 0.205;
      }
      root.add(car);
      cars.push(entry);
    }
    modelsGroup.add(root);
    return { root, cars, owned };
  }

  function dropTrain(view) {
    modelsGroup.remove(view.root);
    for (const mat of view.owned) mat.dispose();
  }

  function updateTrains(factory) {
    const alive = new Set(factory.trains);
    for (const [t, view] of trainViews) {
      if (alive.has(t)) continue;
      dropTrain(view);
      trainViews.delete(t);
    }
    // Cargo fills the wagons one after the other, in the colour of what most of it is.
    for (const t of factory.trains) {
      let view = trainViews.get(t);
      if (!view) trainViews.set(t, (view = makeTrain()));
      let main = null;
      for (const k in t.cargo) if (t.cargo[k] > 0 && (!main || t.cargo[k] > t.cargo[main])) main = k;
      for (let j = 0; j < CARS; j++) {
        const car = view.cars[j];
        trackPoint(factory.world, t.path, t.s - j * CAR_GAP, carPoint);
        car.root.position.set(carPoint.x, carPoint.y + RAIL_TOP - 0.11, carPoint.z);
        car.root.rotation.y = carPoint.heading + (j === CARS - 1 ? Math.PI : 0);
        if (car.container) {
          const fill = Math.min(1, Math.max(0, (t.total - (j - 1) * WAGON_CARGO) / WAGON_CARGO));
          car.container.visible = fill > 0;
          car.container.scale.y = Math.max(0.05, fill);
          if (main) car.container.material.color.setHex(ITEMS[main].color);
        }
        if (car.lamp) {
          // The leading lamp shines while the train runs.
          const lead = j === 0 && t.state === 'run';
          car.lamp.material.emissiveIntensity = (lead ? 1.6 : 0.25) * (1 + night * 2);
        }
      }
    }
  }

  // Where the wire hangs on a pole: the left or right insulator.
  const insulator = (b, side) => {
    const a = yaw(b.dir);
    return new THREE.Vector3(b.tile.position.x + Math.cos(a) * INSULATOR * side, b.tile.height + WIRE_HEIGHT, b.tile.position.z - Math.sin(a) * INSULATOR * side);
  };

  function rebuildWires(factory) {
    const geos = [];
    for (const [a, b] of factory.grid.wires) {
      // Join left to left or crossed, whichever keeps the two wires apart.
      const straight = insulator(a, 1).distanceTo(insulator(b, 1)) + insulator(a, -1).distanceTo(insulator(b, -1));
      const crossed = insulator(a, 1).distanceTo(insulator(b, -1)) + insulator(a, -1).distanceTo(insulator(b, 1));
      const flip = crossed < straight ? -1 : 1;
      for (const side of [1, -1]) {
        const from = insulator(a, side);
        const to = insulator(b, side * flip);
        const sag = 0.06 + from.distanceTo(to) * 0.035;
        const points = [];
        for (let i = 0; i <= 10; i++) {
          const t = i / 10;
          points.push(from.clone().lerp(to, t).setY(from.y + (to.y - from.y) * t - sag * 4 * t * (1 - t)));
        }
        geos.push(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points), 10, 0.014, 4, false));
      }
    }
    wires.geometry.dispose();
    wires.geometry = geos.length ? mergeGeometries(geos) : new THREE.BufferGeometry();
    for (const g of geos) g.dispose();

    let n = 0;
    for (const b of factory.buildings.values()) {
      if (b.type !== 'pole' || n >= MAX_AREAS) continue;
      dummy.position.set(b.tile.position.x, b.tile.height + 0.04, b.tile.position.z);
      dummy.rotation.set(0, 0, 0);
      dummy.updateMatrix();
      areas.setMatrixAt(n++, dummy.matrix);
    }
    areas.count = n;
    areas.instanceMatrix.needsUpdate = true;
  }

  const dummy = new THREE.Object3D();
  let drillSpeed = 1;
  let night = 0; // 0 by day, 1 at night: lamps and windows shine brighter
  // Belt rails and drill bodies change colour with each speed boost.
  const drillMat = flat(SIGNAL, { roughness: 0.5 });
  const TIER_COLORS = [SIGNAL, 0xe2483a, 0x3b8fe6, 0xa05ae0];
  const tier = (n) => TIER_COLORS[Math.min(n, TIER_COLORS.length - 1)];

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
      add(g.hubFoot, m.dark);
      add(g.hub, b.type === 'splitter' ? m.splitter : m.merger);
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
      add(g.armBase, m.dark).position.set(-0.22, 0.05, -0.3);
      view.arm = new THREE.Group();
      view.arm.position.set(-0.22, 0.12, -0.3);
      const arm = new THREE.Mesh(g.arm, m.signal);
      arm.castShadow = true;
      view.arm.add(arm);
      root.add(view.arm);
      lamp(0.3, 0.68, -0.15);
    } else if (b.type === 'power') {
      add(g.bigFoot, m.steel);
      add(g.hall, m.concrete);
      add(g.hallRoof, m.dark);
      add(g.fireFrame, m.dark);
      view.glow = own(new THREE.MeshStandardMaterial({ color: 0x3a1a0a, emissive: GLOW, emissiveIntensity: 0.2, roughness: 1 }));
      add(g.firebox, view.glow, false);
      add(g.stack, m.white);
      add(g.stackBands, m.red);
      add(g.bunker, m.dark);
      add(g.bunkerLegs, m.steel);
      view.coal = add(g.coalHeap, m.ore.coal);
      add(g.fanRing, m.steel);
      view.rotor = add(g.rotor, m.signal);
      view.rotor.position.set(-0.1, 0.67, 0.06);
      lamp(0.06, 0.52, -0.26);
    } else if (b.type === 'pole') {
      add(g.poleFoot, m.concrete);
      add(g.mastPole, m.wood);
      add(g.crossbar, m.wood);
      add(g.brace, m.wood);
      add(g.insulators, m.porcelain);
    } else if (b.type === 'pump') {
      add(g.jackBase, m.steel);
      add(g.wellhead, m.dark);
      add(g.samson, m.jack);
      add(g.gearbox, m.jack);
      view.beam = new THREE.Group();
      view.beam.position.set(0, 0.72, 0.02);
      root.add(view.beam);
      for (const [geo, mat] of [[g.beam, m.jack], [g.horsehead, m.signal], [g.rod, m.chrome]]) {
        const mesh = new THREE.Mesh(geo, mat);
        mesh.castShadow = true;
        if (geo === g.rod) mesh.position.set(0, -0.1, -0.4);
        view.beam.add(mesh);
      }
      const pitman = new THREE.Mesh(g.pitman, m.steel);
      pitman.position.set(0, 0, 0.42);
      view.beam.add(pitman);
      view.crank = add(g.crank, m.dark);
      view.crank.position.set(0, 0.3, 0.3);
      lamp(0.12, 0.26, 0.4);
    } else if (b.type === 'tank') {
      add(g.tankFoot, m.concrete);
      add(g.drum, m.tank);
      add(g.drumBands, m.red);
      add(g.dome, m.tank);
      add(g.ladder, m.steel);
      add(g.gaugeBack, m.dark);
      view.gauge = add(g.gauge, own(new THREE.MeshStandardMaterial({ color: 0x3a2a10, emissive: 0xffa53a, emissiveIntensity: 0.9 })), false);
      view.gauge.position.set(0, 0.16, -0.4);
    } else if (b.type === 'refinery') {
      add(g.refFoot, m.steel);
      add(g.heater, m.brick);
      add(g.columnA, m.refinery);
      add(g.columnB, m.refinery);
      add(g.columnRings, m.dark);
      add(g.caps, m.refinery);
      add(g.refPipes, m.pipe);
      add(g.flare, m.dark);
      add(g.tray, m.dark);
      view.flame = add(g.flame, m.flame, false);
      view.flame.position.set(-0.33, 1.02, -0.3);
      lamp(-0.05, 0.42, -0.02);
    } else if (b.type === 'station') {
      add(g.platforms, m.platform);
      add(g.posts, m.steel);
      add(g.roof, m.roof);
      view.fascia = add(g.fascia, own(flat(MODE_COLOR.load, { roughness: 0.5 })));
      view.crates = [-1, 1].map((sx) => {
        const c = add(g.crates, m.container);
        c.position.set(sx * 0.42, 0.1, 0.22);
        return c;
      });
      // A round sign with the station's letter above the roof.
      const c = document.createElement('canvas');
      c.width = c.height = 64;
      const ctx = c.getContext('2d');
      ctx.fillStyle = '#1d3b52';
      ctx.beginPath();
      ctx.arc(32, 32, 29, 0, Math.PI * 2);
      ctx.fill();
      ctx.lineWidth = 4;
      ctx.strokeStyle = '#ffffff';
      ctx.stroke();
      ctx.fillStyle = '#ffffff';
      ctx.font = `700 ${b.name.length > 1 ? 26 : 36}px "Saira Condensed", sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(b.name, 32, 34);
      const tex = own(new THREE.CanvasTexture(c));
      tex.colorSpace = THREE.SRGBColorSpace;
      const sign = new THREE.Sprite(own(new THREE.SpriteMaterial({ map: tex })));
      sign.scale.setScalar(0.42);
      sign.position.set(0, 1.38, 0);
      root.add(sign);
      lamp(0, 1.0, -0.47);
    } else if (b.type === 'silo') {
      add(g.siloSlab, m.concrete);
      view.site = new THREE.Group();
      root.add(view.site);
      for (const [geo, mat] of [[g.fence, m.steel], [g.tape, m.signal], [g.craneMast, m.signal], [g.piles, m.container]]) {
        const mesh = new THREE.Mesh(geo, mat);
        mesh.castShadow = true;
        view.site.add(mesh);
      }
      view.jib = new THREE.Mesh(g.craneJib, m.signal);
      view.jib.castShadow = true;
      view.jib.position.set(-0.95, 3.1, 0.95);
      view.site.add(view.jib);
      view.pad = new THREE.Group();
      root.add(view.pad);
      for (const [geo, mat] of [[g.pad, m.pad], [g.trench, m.dark], [g.padRing, m.steel], [g.tower, m.tower], [g.arms, m.steel], [g.fuelTanks, m.white]]) {
        const mesh = new THREE.Mesh(geo, mat);
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        view.pad.add(mesh);
      }
      view.fuel = own(new THREE.MeshStandardMaterial({ color: 0x3a1a0a, emissive: 0xff6a3d, emissiveIntensity: 0, roughness: 0.4 }));
      view.pad.add(new THREE.Mesh(g.fuelLine, view.fuel));
      view.rocket = createRocket();
      view.rocket.group.position.y = 0.6;
      root.add(view.rocket.group);
      // A red beacon on top of the tower.
      view.beacon = add(g.lamp, own(new THREE.MeshStandardMaterial({ color: 0xff3020, emissive: 0xff3020, emissiveIntensity: 1 })), false);
      view.beacon.scale.setScalar(1.6);
      view.beacon.position.set(0.92, 6.28, 0.92);
      lamp(0, 0.5, -1.25);
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
    const counts = { straight: 0, left: 0, right: 0 };
    for (const b of factory.buildings.values()) {
      if (b.type === 'belt') {
        const i = counts[b.shape]++;
        dummy.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
        dummy.rotation.set(0, yaw(b.dir), 0);
        dummy.updateMatrix();
        for (const mesh of beltMeshes[b.shape]) mesh.setMatrixAt(i, dummy.matrix);
        continue;
      }
      if (b.type === 'rail') continue;
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
    factory.updateGrid();
    if (factory.grid.version !== gridVersion) {
      gridVersion = factory.grid.version;
      rebuildWires(factory);
    }
    factory.updatePipes();
    if (factory.pipes.version !== pipesVersion) {
      pipesVersion = factory.pipes.version;
      rebuildPipes(factory);
    }
    factory.updateTracks();
    rebuildRails(factory);
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
    beltTex.offset.y -= factory.beltSpeed() * CHEVRONS_PER_TILE * dt;
    beltTex.offset.y %= 1;
    const { levels } = factory.research;
    beltMats.rails.color.setHex(tier(levels.belt));
    drillMat.color.setHex(tier(levels.drill));
    drillSpeed = factory.research.stats.drill;

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

    updateFlow(dt, factory);
    updateTrains(factory);
    for (const [b, view] of views) animate(b, view, dt, elapsed);
  }

  function setLamp(view, state, elapsed) {
    const col = LAMP[state];
    view.lamp.material.color.setHex(col);
    view.lamp.material.emissive.setHex(col);
    const steady = state === 'work' || state === 'idle';
    if (state === 'nopower') {
      // Short purple blinks: the machine waits for power.
      view.lamp.material.emissiveIntensity = (Math.sin(elapsed * 9) > 0.2 ? 2 : 0.15) * (1 + night * 1.5);
      return;
    }
    view.lamp.material.emissiveIntensity = (steady ? 1.2 : 0.8 + Math.sin(elapsed * 6) * 0.6) * (1 + night * 1.5);
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
      // The splitter's diverter points at the exit that got the last item; the merger's spins on.
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
    } else if (b.type === 'power') {
      const load = working ? 0.4 + 0.6 * (b.load ?? 1) : 0;
      const target = working ? 1 + load * 1.6 + Math.sin(elapsed * 11) * 0.25 : b.state === 'idle' ? 0.45 : 0.08;
      view.glow.emissiveIntensity += (target - view.glow.emissiveIntensity) * Math.min(1, dt * 4);
      view.rotor.rotation.y += dt * (working ? 4 + load * 10 : 0);
      view.coal.visible = b.fuel > 0;
      view.coal.scale.setScalar(0.5 + Math.min(1, b.fuel / 5) * 0.5);
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'pump') {
      // The beam nods while the crank turns; it slows down to rest when the pump stops.
      view.speed = (view.speed ?? 0) + ((working ? 1 : 0) - (view.speed ?? 0)) * Math.min(1, dt * 2);
      view.crankAngle = (view.crankAngle ?? 0) + dt * 3.2 * view.speed;
      view.crank.rotation.x = view.crankAngle;
      view.beam.rotation.x = Math.sin(view.crankAngle) * 0.2 * Math.min(1, view.speed * 2);
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'tank') {
      const net = b.pipes;
      const fill = net?.capacity ? net.amount / net.capacity : 0;
      view.fill = (view.fill ?? fill) + (fill - (view.fill ?? fill)) * Math.min(1, dt * 3);
      view.gauge.scale.y = Math.max(0.02, view.fill);
      view.gauge.material.emissiveIntensity = (0.5 + view.fill * 0.8) * (1 + night);
    } else if (b.type === 'refinery') {
      // A pilot flame on the flare; it roars while the refinery works.
      const target = working ? 1.6 + Math.sin(elapsed * 17 + view.phase) * 0.25 + Math.sin(elapsed * 9.3) * 0.2 : 0.45;
      view.flare = (view.flare ?? 0.45) + (target - (view.flare ?? 0.45)) * Math.min(1, dt * 5);
      view.flame.scale.set(0.8 + view.flare * 0.3, view.flare, 0.8 + view.flare * 0.3);
      setLamp(view, b.state, elapsed);
    } else if (b.type === 'station') {
      view.fascia.material.color.setHex(MODE_COLOR[b.mode]);
      const fill = b.total / STATION_CAP;
      view.crates.forEach((c, i) => {
        c.visible = fill > i * 0.5;
        c.scale.setScalar(0.6 + Math.min(1, fill * 2 - i) * 0.5);
      });
      setLamp(view, b.state === 'work' ? 'work' : 'idle', elapsed);
    } else if (b.type === 'silo') {
      // Each stage grows out of the ground while it is being built.
      const grow = b.busy ? Math.max(0.03, b.timer / SILO_STAGES[b.stage].time) : 0;
      const shown = (stage) => (b.stage > stage ? 1 : b.stage === stage ? grow : 0);
      view.site.visible = b.stage === 0;
      if (working && b.stage === 0) view.jib.rotation.y = Math.sin(view.phase * 0.6) * 1.2;
      const pad = shown(0);
      view.pad.visible = pad > 0;
      view.pad.scale.y = pad;
      const hull = shown(1);
      const nose = shown(2);
      view.rocket.group.visible = hull > 0;
      view.rocket.hull.scale.y = hull;
      view.rocket.nose.visible = nose > 0;
      view.rocket.nose.scale.set(1, nose, 1);
      view.rocket.nose.position.y = 3.7 * (1 - nose); // grows up from the top of the hull
      // The fuel line glows while the rocket is fuelled and pulses once it is ready.
      const fuel = b.stage >= SILO_STAGES.length ? 1.2 + Math.sin(elapsed * 3) * 0.6 : b.stage === 3 && b.busy ? 0.4 + grow * 1.2 : 0;
      view.fuel.emissiveIntensity = fuel * (1 + night);
      view.beacon.material.emissiveIntensity = (Math.sin(elapsed * 4) > 0.3 ? 2.2 : 0.2) * (1 + night * 1.5);
      setLamp(view, b.state === 'ready' ? 'work' : b.state, elapsed);
    } else if (b.type === 'storage') {
      if (b.received !== view.seen) {
        view.seen = b.received;
        view.flash = 0.25;
      }
      view.flash = Math.max(0, view.flash - dt);
      setLamp(view, view.flash > 0 ? 'work' : 'idle', elapsed);
      view.lamp.material.emissiveIntensity = (view.flash > 0 ? 2 : 0.5) * (1 + night * 1.5);
    }
  }

  function clear() {
    for (const view of views.values()) dropModel(view);
    views.clear();
    for (const meshes of Object.values(beltMeshes)) for (const mesh of meshes) mesh.count = 0;
    for (const mesh of Object.values(itemMeshes)) mesh.count = 0;
    wires.geometry.dispose();
    wires.geometry = new THREE.BufferGeometry();
    areas.count = 0;
    gridVersion = -1;
    pipeHubs.count = pipeArms.count = flowRings.count = 0;
    flowArms = [];
    pipesVersion = -1;
    for (const meshes of Object.values(railMeshes)) for (const mesh of meshes) mesh.count = 0;
    for (const view of trainViews.values()) dropTrain(view);
    trainViews.clear();
  }

  function setNight(n) {
    night = n;
    parts.m.glass.emissiveIntensity = 0.4 + n * 1.4;
  }

  const showSupply = (on) => (areas.visible = on);

  return { group, rebuild, update, clear, setNight, showSupply };
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
    power: { geo: mergeGeometries([box(0.66, 0.66, 0.68, 0.06).translate(-0.1, 0, 0), new THREE.CylinderGeometry(0.1, 0.12, 1.4, 8).translate(0.3, 0.7, 0.26)]), arrow: null },
    pole: { geo: mergeGeometries([new THREE.CylinderGeometry(0.05, 0.05, 1.5, 6).translate(0, 0.75, 0), box(0.56, 0.06, 0.06).translate(0, 1.43, 0)]), arrow: null },
    pump: { geo: mergeGeometries([box(0.3, 0.1, 0.9), box(0.1, 0.7, 0.1), box(0.1, 0.1, 0.9).translate(0, 0.68, 0)]), arrow: null },
    pipe: { geo: mergeGeometries([new THREE.CylinderGeometry(0.1, 0.1, 1, 8).rotateZ(Math.PI / 2).translate(0, 0.34, 0), new THREE.CylinderGeometry(0.1, 0.1, 1, 8).rotateX(Math.PI / 2).translate(0, 0.34, 0)]), arrow: null },
    tank: { geo: new THREE.CylinderGeometry(0.4, 0.42, 0.82, 14).translate(0, 0.41, 0), arrow: null },
    rail: { geo: box(0.84, 0.1, 1), arrow: 0.14 },
    station: { geo: mergeGeometries([box(1, 0.06, 0.9).translate(0, 1.03, 0), box(0.05, 1, 0.05).translate(-0.42, 0, -0.38), box(0.05, 1, 0.05).translate(0.42, 0, -0.38), box(0.05, 1, 0.05).translate(-0.42, 0, 0.38), box(0.05, 1, 0.05).translate(0.42, 0, 0.38), box(0.84, 0.1, 1)]), arrow: 0.14 },
    train: { geo: mergeGeometries([box(0.48, 0.5, 0.9).translate(0, 0.12, 0), box(0.48, 0.5, 0.9).translate(0, 0.12, 1)]), arrow: 0.75 },
    silo: { geo: mergeGeometries([box(2.9, 0.6, 2.9), box(0.44, 6, 0.44).translate(0.92, 0, 0.92), new THREE.CylinderGeometry(0.3, 0.3, 4.4, 12).translate(0, 2.8, 0)]), arrow: null },
    refinery: { geo: mergeGeometries([box(0.86, 0.36, 0.86), new THREE.CylinderGeometry(0.13, 0.13, 1.2, 8).translate(0.2, 0.6, 0.14), new THREE.CylinderGeometry(0.03, 0.03, 1, 6).translate(-0.33, 0.5, -0.3)]), arrow: 0.45 },
  };
  const meshes = Object.fromEntries(Object.entries(shapes).map(([k, s]) => [k, new THREE.Mesh(s.geo, bodyMat)]));
  for (const s of Object.values(meshes)) pivot.add(s);

  // The square a new pole will supply.
  const reach = POLE_SUPPLY * 2 + 1;
  const supply = new THREE.Mesh(new THREE.PlaneGeometry(reach, reach).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x7fd4ff, transparent: true, opacity: 0.18, depthWrite: false }));
  supply.position.y = 0.05;
  group.add(supply);

  function show(tool, tile, dir, ok) {
    if (!tool || !tile) {
      group.visible = false;
      return;
    }
    group.visible = true;
    group.position.set(tile.position.x, tile.height, tile.position.z);
    pivot.rotation.y = yaw(dir);
    for (const [k, s] of Object.entries(meshes)) s.visible = k === tool;
    supply.visible = tool === 'pole';
    foot.scale.setScalar(tool === 'silo' ? 3 : 1);
    const arrowY = shapes[tool]?.arrow ?? null;
    arrow.visible = arrowY !== null;
    arrow.position.y = arrowY ?? 0;
    const col = tool === 'remove' ? (ok ? 0xff6b5b : 0x9aa0a6) : ok ? 0x7ee08a : 0xff6b5b;
    for (const m of [footMat, bodyMat, arrowMat]) m.color.setHex(col);
  }

  return { group, show };
}
