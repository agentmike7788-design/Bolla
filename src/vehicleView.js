import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { TILE } from './world.js';
import { VEHICLES } from './vehicles.js';

// 3D view of the vehicles: a jeep with a swivelling roof gun and a tank with
// tracks, turret and cannon. Wheels and tracks turn with the speed, the body sits
// on the ground under it, dust flies behind, headlights glow at night and throw a
// pool of light ahead. A ring marks the vehicle that is driven or selected, a
// health bar shows on damaged ones. Tank shells fly as glowing slugs.

const flat = (color, extra) => new THREE.MeshStandardMaterial({ color, roughness: 0.6, metalness: 0.15, flatShading: true, ...extra });
const box = (w, h, d, x = 0, y = 0, z = 0) => new THREE.BoxGeometry(w, h, d).translate(x, y, z);
const MAX_SHOTS = 24;
const DUSTY = new Set(['sand', 'dune', 'gravel', 'ash', 'blacksand', 'grass', 'snow']);

function carParts() {
  const body = mergeGeometries([
    box(0.62, 0.2, 1.06, 0, 0.27, 0),
    // Hood sloping down to the bumper, and the bumpers.
    box(0.58, 0.06, 0.36, 0, 0.39, 0.33).rotateX(0.0),
    box(0.66, 0.08, 0.08, 0, 0.2, 0.55),
    box(0.66, 0.08, 0.08, 0, 0.2, -0.55),
    // Roll cage over the open back.
    box(0.04, 0.26, 0.04, 0.27, 0.5, -0.12),
    box(0.04, 0.26, 0.04, -0.27, 0.5, -0.12),
    box(0.58, 0.04, 0.04, 0, 0.63, -0.12),
    box(0.04, 0.04, 0.42, 0.27, 0.63, -0.33),
    box(0.04, 0.04, 0.42, -0.27, 0.63, -0.33),
    // Spare wheel holder at the back.
    box(0.2, 0.2, 0.05, 0, 0.36, -0.56),
  ]);
  const glass = mergeGeometries([box(0.54, 0.18, 0.03, 0, 0.5, 0.12).rotateX(-0.35).translate(0, 0.04, 0.04)]);
  const dark = mergeGeometries([
    // Seats.
    box(0.2, 0.08, 0.18, 0.13, 0.4, -0.02),
    box(0.2, 0.08, 0.18, -0.13, 0.4, -0.02),
    box(0.2, 0.18, 0.04, 0.13, 0.47, -0.11),
    box(0.2, 0.18, 0.04, -0.13, 0.47, -0.11),
    // Grille.
    box(0.4, 0.1, 0.02, 0, 0.3, 0.535),
    new THREE.CylinderGeometry(0.11, 0.11, 0.07, 10).rotateX(Math.PI / 2).translate(0, 0.36, -0.6),
  ]);
  const wheel = new THREE.CylinderGeometry(0.15, 0.15, 0.12, 12).rotateZ(Math.PI / 2);
  const lamps = mergeGeometries([box(0.1, 0.06, 0.02, 0.2, 0.33, 0.54), box(0.1, 0.06, 0.02, -0.2, 0.33, 0.54)]);
  const rear = mergeGeometries([box(0.08, 0.05, 0.02, 0.24, 0.32, -0.54), box(0.08, 0.05, 0.02, -0.24, 0.32, -0.54)]);
  // The roof gun: a post, the gun with its ammo box, the barrel to +z.
  const gun = mergeGeometries([
    new THREE.CylinderGeometry(0.03, 0.03, 0.14, 6).translate(0, 0.07, 0),
    box(0.08, 0.08, 0.2, 0, 0.16, 0.02),
    box(0.07, 0.07, 0.09, 0.08, 0.15, -0.02),
    new THREE.CylinderGeometry(0.018, 0.018, 0.3, 6).rotateX(Math.PI / 2).translate(0, 0.17, 0.25),
  ]);
  return { body, glass, dark, wheel, lamps, rear, gun };
}

function tankParts() {
  const hull = mergeGeometries([
    box(0.66, 0.2, 1.2, 0, 0.3, 0),
    // Sloped front plate and the engine deck.
    box(0.66, 0.06, 0.3, 0, 0.36, 0.62).rotateX(0),
    box(0.5, 0.05, 0.36, 0, 0.42, -0.36),
  ]);
  const track = mergeGeometries([box(0.2, 0.26, 1.34, 0.42, 0.17, 0), box(0.2, 0.26, 1.34, -0.42, 0.17, 0)]);
  const fenders = mergeGeometries([box(0.24, 0.03, 1.38, 0.42, 0.315, 0), box(0.24, 0.03, 1.38, -0.42, 0.315, 0)]);
  const wheel = new THREE.CylinderGeometry(0.1, 0.1, 0.22, 10).rotateZ(Math.PI / 2);
  // Turret around its own pivot, the gun to +z.
  const turret = mergeGeometries([
    new THREE.CylinderGeometry(0.3, 0.34, 0.2, 8).translate(0, 0.1, -0.02),
    box(0.36, 0.12, 0.2, 0, 0.12, 0.25),
    box(0.16, 0.08, 0.16, 0.14, 0.24, -0.12),
    box(0.3, 0.1, 0.12, 0, 0.1, -0.36),
  ]);
  const barrel = mergeGeometries([
    new THREE.CylinderGeometry(0.045, 0.05, 0.7, 8).rotateX(Math.PI / 2).translate(0, 0, 0.35),
    new THREE.CylinderGeometry(0.065, 0.065, 0.12, 8).rotateX(Math.PI / 2).translate(0, 0, 0.66),
  ]);
  const mg = mergeGeometries([new THREE.CylinderGeometry(0.015, 0.015, 0.22, 5).rotateX(Math.PI / 2).translate(-0.14, 0.28, 0.06), box(0.06, 0.06, 0.1, -0.14, 0.27, -0.06)]);
  const lamps = mergeGeometries([box(0.08, 0.06, 0.03, 0.24, 0.36, 0.62), box(0.08, 0.06, 0.03, -0.24, 0.36, 0.62)]);
  const rear = mergeGeometries([box(0.08, 0.05, 0.02, 0.26, 0.34, -0.61), box(0.08, 0.05, 0.02, -0.26, 0.34, -0.61)]);
  return { hull, track, fenders, wheel, turret, barrel, mg, lamps, rear };
}

export function createVehicleView({ effects }) {
  const group = new THREE.Group();
  const car = carParts();
  const tank = tankParts();
  const mats = {
    car: flat(0xd8b04a, { roughness: 0.5 }),
    tank: flat(0x5f6e3c, { roughness: 0.75 }),
    tankDark: flat(0x48542c, { roughness: 0.8 }),
    metal: flat(0x3a3d40, { metalness: 0.5, roughness: 0.45 }),
    rubber: flat(0x1e1f20, { roughness: 0.95 }),
    tread: flat(0x2b2a27, { roughness: 1 }),
    glass: new THREE.MeshStandardMaterial({ color: 0x9ec8dc, roughness: 0.1, metalness: 0.3, transparent: true, opacity: 0.55 }),
    lamp: new THREE.MeshStandardMaterial({ color: 0xfff4d0, emissive: 0xffe6a0, emissiveIntensity: 0.3 }),
    rear: new THREE.MeshStandardMaterial({ color: 0x601010, emissive: 0xff2010, emissiveIntensity: 0.3 }),
  };
  // Pool of light in front of the headlights, only seen at night.
  const beamGeo = new THREE.CircleGeometry(1, 24).scale(0.7, 1, 1).rotateX(-Math.PI / 2).translate(0, 0.03, 1.55);
  const beamMat = new THREE.MeshBasicMaterial({ color: 0xffe6a0, transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false });
  const ringGeo = new THREE.RingGeometry(0.72, 0.82, 36).rotateX(-Math.PI / 2);
  const ringMat = new THREE.MeshBasicMaterial({ color: 0xffd34d, transparent: true, opacity: 0.85, depthWrite: false });
  const barGeo = new THREE.PlaneGeometry(1, 1);
  const barBackMat = new THREE.MeshBasicMaterial({ color: 0x111111, transparent: true, opacity: 0.7, depthWrite: false });
  const shotGeo = new THREE.SphereGeometry(0.06, 8, 6).scale(1, 1, 2.4);
  const shotMat = new THREE.MeshBasicMaterial({ color: 0xffc070 });
  const shots = [];
  for (let i = 0; i < MAX_SHOTS; i++) {
    const m = new THREE.Mesh(shotGeo, shotMat);
    m.visible = false;
    group.add(m);
    shots.push(m);
  }

  const mesh = (geo, mat, shadow = true) => {
    const m = new THREE.Mesh(geo, mat);
    m.castShadow = shadow;
    return m;
  };

  function makeCar() {
    const root = new THREE.Group();
    const body = new THREE.Group();
    root.add(body);
    body.add(mesh(car.body, mats.car), mesh(car.glass, mats.glass, false), mesh(car.dark, mats.rubber), mesh(car.lamps, mats.lamp, false), mesh(car.rear, mats.rear, false));
    const wheels = [];
    for (const [x, z] of [[0.33, 0.33], [-0.33, 0.33], [0.33, -0.33], [-0.33, -0.33]]) {
      const w = mesh(car.wheel, mats.rubber);
      w.rotation.order = 'YXZ'; // steer first, then roll
      w.position.set(x, 0.15, z);
      body.add(w);
      wheels.push(w);
    }
    const gun = mesh(car.gun, mats.metal);
    gun.position.set(0, 0.62, -0.3);
    body.add(gun);
    return { root, body, wheels, front: wheels.slice(0, 2), gun, barrel: null };
  }

  function makeTank() {
    const root = new THREE.Group();
    const body = new THREE.Group();
    root.add(body);
    body.add(mesh(tank.hull, mats.tank), mesh(tank.track, mats.tread), mesh(tank.fenders, mats.tankDark), mesh(tank.lamps, mats.lamp, false), mesh(tank.rear, mats.rear, false));
    const wheels = [];
    for (const z of [-0.45, -0.15, 0.15, 0.45]) {
      for (const x of [0.42, -0.42]) {
        const w = mesh(tank.wheel, mats.metal, false);
        w.position.set(x, 0.14, z);
        body.add(w);
        wheels.push(w);
      }
    }
    const gun = new THREE.Group();
    gun.position.set(0, 0.42, -0.05);
    gun.add(mesh(tank.turret, mats.tank), mesh(tank.mg, mats.metal));
    const barrel = mesh(tank.barrel, mats.tankDark);
    barrel.position.set(0, 0.12, 0.3);
    gun.add(barrel);
    body.add(gun);
    return { root, body, wheels, front: [], gun, barrel };
  }

  const views = new Map(); // vehicle -> view
  let world = null;
  let origin = { x: 0, z: 0 };

  function setWorld(next) {
    clear();
    world = next;
    origin = { x: world.tiles[0].position.x, z: world.tiles[0].position.z };
  }

  const wx = (x) => origin.x + x * TILE;
  const wz = (z) => origin.z + z * TILE;
  const tileAt = (x, z) => world.tiles[Math.max(0, Math.min(world.size - 1, Math.round(z))) * world.size + Math.max(0, Math.min(world.size - 1, Math.round(x)))];

  function makeView(v) {
    const view = v.kind === 'panzer' ? makeTank() : makeCar();
    const beam = new THREE.Mesh(beamGeo, beamMat);
    beam.renderOrder = 2;
    view.body.add(beam);
    view.ring = new THREE.Mesh(ringGeo, ringMat);
    view.ring.renderOrder = 2;
    view.root.add(view.ring);
    view.ring.scale.setScalar(v.kind === 'panzer' ? 1.05 : 0.85);
    view.bar = new THREE.Group();
    const back = new THREE.Mesh(barGeo, barBackMat);
    view.fillMat = new THREE.MeshBasicMaterial({ color: 0x6be36b, depthWrite: false });
    view.fill = new THREE.Mesh(barGeo, view.fillMat);
    view.fill.position.z = 0.001;
    back.renderOrder = view.fill.renderOrder = 3;
    view.bar.add(back, view.fill);
    group.add(view.bar);
    view.y = tileAt(v.x, v.z).height;
    view.roll = 0;
    view.dust = 0;
    group.add(view.root);
    return view;
  }

  const barColor = new THREE.Color();
  function update(dt, factory, camera, night, highlight) {
    const vehicles = factory.vehicles;
    const alive = new Set(vehicles.list);
    for (const [v, view] of views) {
      if (alive.has(v)) continue;
      group.remove(view.root, view.bar);
      view.fillMat.dispose();
      views.delete(v);
    }
    beamMat.opacity = night * 0.32;
    mats.lamp.emissiveIntensity = 0.3 + night * 2.2;
    mats.rear.emissiveIntensity = 0.3 + night * 1.2;
    ringMat.opacity = 0.55 + Math.sin(performance.now() / 260) * 0.25;
    for (const v of vehicles.list) {
      let view = views.get(v);
      if (!view) views.set(v, (view = makeView(v)));
      const spec = VEHICLES[v.kind];
      const tile = tileAt(v.x, v.z);
      // Glide over the steps between tiles instead of jumping.
      view.y += (tile.height - view.y) * Math.min(1, dt * 9);
      view.root.position.set(wx(v.x), view.y, wz(v.z));
      view.root.rotation.y = v.heading;
      // The body leans a little when braking or speeding up.
      const lean = Math.max(-0.06, Math.min(0.06, ((v.speed - (view.lastSpeed ?? v.speed)) / Math.max(dt, 1e-3)) * -0.01));
      view.lastSpeed = v.speed;
      view.roll += (lean - view.roll) * Math.min(1, dt * 6);
      view.body.rotation.x = view.roll;
      // Wheels roll with the ground; the jeep's front wheels steer.
      const spin = (v.speed * dt) / (v.kind === 'panzer' ? 0.1 : 0.15);
      for (const w of view.wheels) w.rotation.x += spin;
      const steer = v === vehicles.driving ? vehicles.input.steer * 0.45 : 0;
      for (const w of view.front) w.rotation.y += (steer - w.rotation.y) * Math.min(1, dt * 8);
      view.gun.rotation.y = v.aim - v.heading;
      if (view.barrel) view.barrel.position.z = 0.3 - (v.recoil ?? 0) * 0.16;
      view.ring.visible = v === highlight || v === vehicles.driving;
      // Health bar over a damaged one, turned to the camera.
      const frac = v.hp / spec.hp;
      view.bar.visible = frac < 0.999;
      if (view.bar.visible) {
        view.bar.position.set(wx(v.x), view.y + (v.kind === 'panzer' ? 1.05 : 0.95), wz(v.z));
        view.bar.quaternion.copy(camera.quaternion);
        const w = v.kind === 'panzer' ? 0.9 : 0.7;
        view.bar.children[0].scale.set(w + 0.04, 0.12, 1);
        view.fill.scale.set(w * frac, 0.08, 1);
        view.fill.position.x = -(w * (1 - frac)) / 2;
        view.fillMat.color.copy(barColor.setHSL(frac * 0.33, 0.85, 0.5));
      }
      // Dust behind it and a puff from the exhaust.
      const fast = Math.abs(v.speed);
      if (fast > 1.5 && DUSTY.has(tile.terrain)) {
        view.dust += dt * fast * 3;
        while (view.dust > 1) {
          view.dust -= 1;
          const back = v.speed > 0 ? -0.55 : 0.55;
          const side = (Math.random() - 0.5) * 0.6;
          const s = Math.sin(v.heading);
          const c = Math.cos(v.heading);
          const color = tile.terrain === 'snow' ? 0xf2f6f8 : tile.terrain === 'grass' ? 0x8a7a55 : 0xcdb68a;
          effects.emit({ x: wx(v.x + s * back + c * side), y: view.y + 0.08, z: wz(v.z + c * back - s * side), vx: (Math.random() - 0.5) * 0.6, vy: 0.3 + Math.random() * 0.4, vz: (Math.random() - 0.5) * 0.6, life: 0.6 + Math.random() * 0.5, size: 0.18 + Math.random() * 0.14, grow: 1.6, color: effects.color(color, 0.08), gravity: 0, drag: 1.5, fade: 0.55 });
        }
      }
      if (Math.random() < dt * (fast > 0.5 ? 6 : 1.5)) {
        const s = Math.sin(v.heading);
        const c = Math.cos(v.heading);
        const back = v.kind === 'panzer' ? -0.55 : -0.58;
        const side = v.kind === 'panzer' ? 0.2 : 0.22;
        effects.emit({ x: wx(v.x + s * back + c * side), y: view.y + (v.kind === 'panzer' ? 0.42 : 0.24), z: wz(v.z + c * back - s * side), vx: -s * 0.3, vy: 0.4, vz: -c * 0.3, life: 0.8, size: 0.08, grow: 1.4, color: effects.color(0x55524e, 0.1), gravity: 0, drag: 1, fade: 0.5 });
      }
    }
    // Tank shells on a flat arc.
    let n = 0;
    for (const s of vehicles.shots) {
      if (n >= MAX_SHOTS) break;
      const t = Math.min(1, s.t / s.dur);
      const m = shots[n++];
      const y0 = tileAt(s.x, s.z).height + 0.55;
      const y1 = tileAt(s.x2, s.z2).height + 0.1;
      m.position.set(wx(s.x + (s.x2 - s.x) * t), y0 + (y1 - y0) * t + Math.sin(t * Math.PI) * 0.6, wz(s.z + (s.z2 - s.z) * t));
      m.rotation.y = Math.atan2(s.x2 - s.x, s.z2 - s.z);
      m.visible = true;
    }
    for (let i = n; i < MAX_SHOTS; i++) shots[i].visible = false;
  }

  // World position of a vehicle, for the camera and sounds.
  function positionOf(v, out) {
    const view = views.get(v);
    return out.set(wx(v.x), view ? view.y : tileAt(v.x, v.z).height, wz(v.z));
  }

  function clear() {
    for (const view of views.values()) {
      group.remove(view.root, view.bar);
      view.fillMat.dispose();
    }
    views.clear();
    for (const m of shots) m.visible = false;
  }

  return { group, setWorld, update, clear, positionOf };
}
