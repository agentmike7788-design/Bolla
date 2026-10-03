import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { BELT_SPEED, DIRS } from './factory.js';
import { ORES } from './world.js';

const STEEL = 0x3a4046;
const STEEL_DARK = 0x2a2f34;
const SIGNAL = 0xf0a830;
const CHEVRONS_PER_TILE = 3;
const BELT_TOP = 0.075; // height of the moving surface above the tile
const ITEM_LIFT = 0.08;

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

function drillParts() {
  const g = {
    foot: new RoundedBoxGeometry(0.86, 0.14, 0.86, 2, 0.04).translate(0, 0.07, 0),
    body: new RoundedBoxGeometry(0.62, 0.38, 0.56, 2, 0.05).translate(0, 0.33, 0.06),
    roof: new THREE.BoxGeometry(0.68, 0.05, 0.62).translate(0, 0.545, 0.06),
    chute: new THREE.BoxGeometry(0.3, 0.16, 0.34).translate(0, 0.2, -0.3),
    chuteOre: new THREE.BoxGeometry(0.2, 0.03, 0.3).translate(0, 0.285, -0.31),
    panel: new THREE.BoxGeometry(0.34, 0.12, 0.02).translate(0, 0.34, -0.23),
    mast: new THREE.CylinderGeometry(0.05, 0.05, 0.42, 8).translate(0, 0.78, 0.06),
    rotor: mergeGeometries([
      new THREE.CylinderGeometry(0.15, 0.15, 0.07, 8),
      new THREE.BoxGeometry(0.46, 0.04, 0.06),
      new THREE.BoxGeometry(0.06, 0.04, 0.46),
    ]),
    piston: new THREE.CylinderGeometry(0.08, 0.1, 0.16, 8),
    lamp: new THREE.SphereGeometry(0.045, 10, 8),
  };
  const flat = (color, extra) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.25, flatShading: true, ...extra });
  const m = {
    steel: flat(STEEL),
    dark: flat(STEEL_DARK),
    signal: flat(SIGNAL, { roughness: 0.5 }),
    chrome: new THREE.MeshStandardMaterial({ color: 0xc9ced3, roughness: 0.25, metalness: 0.8 }),
    ore: Object.fromEntries(Object.entries(ORES).map(([k, o]) => [k, flat(o.color, { roughness: 0.4, metalness: 0.3 })])),
  };
  return { g, m };
}

const LAMP = { work: 0x6be36b, blocked: 0xffb02e, empty: 0xff5544 };

// 3D view of the factory: drills as small animated models, belts and the ore on
// them as instanced meshes that are refreshed every frame.
export function createFactoryView(renderer) {
  const group = new THREE.Group();
  const drillsGroup = new THREE.Group();
  group.add(drillsGroup);
  const parts = drillParts();
  const drillViews = new Map(); // building -> { root, rotor, piston, lamp }

  const beltTex = chevronTexture(renderer.capabilities.getMaxAnisotropy());
  const beltMats = {
    bed: new THREE.MeshStandardMaterial({ color: STEEL, roughness: 0.7, metalness: 0.3, flatShading: true }),
    rails: new THREE.MeshStandardMaterial({ color: SIGNAL, roughness: 0.5, metalness: 0.2, flatShading: true }),
    surface: new THREE.MeshStandardMaterial({ map: beltTex, roughness: 0.9 }),
  };
  const MAX_BELTS = 64 * 64;
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
  const items = new THREE.InstancedMesh(
    new THREE.DodecahedronGeometry(0.1, 0),
    new THREE.MeshStandardMaterial({ roughness: 0.5, metalness: 0.3, flatShading: true }),
    MAX_ITEMS,
  );
  items.count = 0;
  items.castShadow = true;
  items.frustumCulled = false;
  group.add(items);
  const oreColors = Object.fromEntries(Object.entries(ORES).map(([k, o]) => [k, new THREE.Color(o.color)]));

  const dummy = new THREE.Object3D();

  function makeDrill(b) {
    const { g, m } = parts;
    const root = new THREE.Group();
    const add = (geo, mat, parent = root) => {
      const mesh = new THREE.Mesh(geo, mat);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      parent.add(mesh);
      return mesh;
    };
    add(g.foot, m.steel);
    add(g.body, m.signal);
    add(g.roof, m.dark);
    add(g.chute, m.dark);
    add(g.chuteOre, m.ore[b.tile.ore]);
    add(g.panel, m.ore[b.tile.ore]);
    add(g.mast, m.chrome);
    const rotor = add(g.rotor, m.dark);
    rotor.position.y = 0.98;
    const piston = add(g.piston, m.steel);
    piston.position.set(0, 0.64, 0.06);
    const lamp = add(g.lamp, new THREE.MeshStandardMaterial({ color: LAMP.work, emissive: LAMP.work, emissiveIntensity: 1.2 }));
    lamp.castShadow = false;
    lamp.position.set(0.24, 0.6, 0.28);
    root.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
    root.rotation.y = yaw(b.dir);
    drillsGroup.add(root);
    return { root, rotor, piston, lamp, phase: Math.random() * 10 };
  }

  // Bring drill models and belt instances in line with the factory after a change.
  function rebuild(factory) {
    const alive = new Set();
    const counts = { straight: 0, left: 0, right: 0 };
    for (const b of factory.buildings.values()) {
      if (b.type === 'drill') {
        alive.add(b);
        let view = drillViews.get(b);
        if (!view) drillViews.set(b, (view = makeDrill(b)));
        view.root.rotation.y = yaw(b.dir);
      } else if (b.type === 'belt') {
        const i = counts[b.shape]++;
        dummy.position.set(b.tile.position.x, b.tile.height, b.tile.position.z);
        dummy.rotation.set(0, yaw(b.dir), 0);
        dummy.updateMatrix();
        for (const mesh of beltMeshes[b.shape]) mesh.setMatrixAt(i, dummy.matrix);
      }
    }
    for (const [shape, meshes] of Object.entries(beltMeshes)) {
      for (const mesh of meshes) {
        mesh.count = counts[shape];
        mesh.instanceMatrix.needsUpdate = true;
      }
    }
    for (const [b, view] of drillViews) {
      if (alive.has(b)) continue;
      drillsGroup.remove(view.root);
      view.lamp.material.dispose();
      drillViews.delete(b);
    }
  }

  // World position of an item on a belt, following the belt's shape.
  const itemPos = new THREE.Vector3();
  function placeItem(b, item) {
    const c = b.tile.position;
    const f = DIRS[b.dir];
    const d = DIRS[item.from];
    const p = item.p;
    let x;
    let z;
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
    } else if (p < 0.5) {
      // Side-loaded onto a straight belt: in from the side, then along the belt.
      x = c.x - d.x * (0.5 - p);
      z = c.z - d.z * (0.5 - p);
    } else {
      x = c.x + f.x * (p - 0.5);
      z = c.z + f.z * (p - 0.5);
    }
    return itemPos.set(x, b.tile.height + BELT_TOP + ITEM_LIFT, z);
  }

  function update(dt, elapsed, factory) {
    beltTex.offset.y -= BELT_SPEED * CHEVRONS_PER_TILE * dt;
    beltTex.offset.y %= 1;

    let n = 0;
    for (const b of factory.buildings.values()) {
      if (b.type !== 'belt') continue;
      for (const item of b.items) {
        if (n >= MAX_ITEMS) break;
        dummy.position.copy(placeItem(b, item));
        dummy.rotation.set(item.spin, item.spin * 1.7, 0);
        dummy.scale.setScalar(1);
        dummy.updateMatrix();
        items.setMatrixAt(n, dummy.matrix);
        items.setColorAt(n, oreColors[item.ore]);
        n++;
      }
    }
    items.count = n;
    items.instanceMatrix.needsUpdate = true;
    if (items.instanceColor) items.instanceColor.needsUpdate = true;

    for (const [b, view] of drillViews) {
      const working = b.state === 'work';
      if (working) {
        view.phase += dt;
        view.rotor.rotation.y += dt * 7;
      }
      view.piston.position.y = 0.64 + (working ? Math.sin(view.phase * 9) * 0.035 : 0);
      const col = LAMP[b.state];
      view.lamp.material.color.setHex(col);
      view.lamp.material.emissive.setHex(col);
      view.lamp.material.emissiveIntensity = b.state === 'work' ? 1.2 : 0.8 + Math.sin(elapsed * 6) * 0.6;
    }
  }

  function clear() {
    for (const view of drillViews.values()) {
      drillsGroup.remove(view.root);
      view.lamp.material.dispose();
    }
    drillViews.clear();
    for (const meshes of Object.values(beltMeshes)) for (const mesh of meshes) mesh.count = 0;
    items.count = 0;
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

  const shapes = {
    drill: new THREE.Mesh(new THREE.BoxGeometry(0.66, 0.6, 0.62).translate(0, 0.3, 0.04), bodyMat),
    belt: new THREE.Mesh(new THREE.BoxGeometry(0.84, 0.12, 1).translate(0, 0.06, 0), bodyMat),
  };
  for (const s of Object.values(shapes)) pivot.add(s);

  function show(tool, tile, dir, ok) {
    if (!tool || !tile) {
      group.visible = false;
      return;
    }
    group.visible = true;
    group.position.set(tile.position.x, tile.height, tile.position.z);
    pivot.rotation.y = yaw(dir);
    for (const [k, s] of Object.entries(shapes)) s.visible = k === tool;
    arrow.visible = tool !== 'remove';
    arrow.position.y = tool === 'drill' ? 0.64 : 0.16;
    const col = tool === 'remove' ? (ok ? 0xff6b5b : 0x9aa0a6) : ok ? 0x7ee08a : 0xff6b5b;
    for (const m of [footMat, bodyMat, arrowMat]) m.color.setHex(col);
  }

  return { group, show };
}
