import * as THREE from 'three';
import { MapControls } from 'three/addons/controls/MapControls.js';

// Strategy-game camera: left mouse pans, right mouse rotates, wheel zooms,
// WASD moves and Q/E rotates. The focus point stays inside the map.
export function createCameraRig(camera, dom, halfExtent) {
  let extent = halfExtent;
  camera.position.set(0, 34, 34);

  const controls = new MapControls(camera, dom);
  controls.enableDamping = true;
  controls.dampingFactor = 0.12;
  controls.screenSpacePanning = false;
  controls.minDistance = 8;
  controls.maxDistance = 90;
  controls.minPolarAngle = 0.15;
  controls.maxPolarAngle = Math.PI / 2.6;
  controls.zoomToCursor = true;
  controls.target.set(0, 0, 0);
  controls.update();

  const keys = new Set();
  let locked = false; // while a menu is open the keys and mouse leave the camera alone
  const isTyping = () => document.activeElement?.tagName === 'INPUT';
  window.addEventListener('keydown', (e) => {
    if (!isTyping() && !locked && !e.ctrlKey && !e.metaKey) keys.add(e.key.toLowerCase());
  });
  window.addEventListener('keyup', (e) => keys.delete(e.key.toLowerCase()));
  window.addEventListener('blur', () => keys.clear());

  const forward = new THREE.Vector3();
  const right = new THREE.Vector3();
  const move = new THREE.Vector3();
  const offset = new THREE.Vector3();
  const up = new THREE.Vector3(0, 1, 0);

  // A short camera flight to a point on the map, see flyTo.
  let flight = null;
  const flightStep = new THREE.Vector3();

  function update(dt) {
    if (flight) {
      flight.t = Math.min(1, flight.t + dt / 0.9);
      const k = flight.t * flight.t * (3 - 2 * flight.t);
      flightStep.lerpVectors(flight.from, flight.to, k).sub(controls.target);
      camera.position.add(flightStep);
      controls.target.add(flightStep);
      if (flight.t >= 1) flight = null;
    }
    move.set(0, 0, 0);
    camera.getWorldDirection(forward);
    forward.y = 0;
    forward.normalize();
    right.crossVectors(forward, up);
    if (keys.has('w') || keys.has('arrowup')) move.add(forward);
    if (keys.has('s') || keys.has('arrowdown')) move.sub(forward);
    if (keys.has('d') || keys.has('arrowright')) move.add(right);
    if (keys.has('a') || keys.has('arrowleft')) move.sub(right);
    if (move.lengthSq() > 0) {
      // Move faster when zoomed out.
      const speed = controls.getDistance() * 0.9 * dt;
      move.normalize().multiplyScalar(speed);
      camera.position.add(move);
      controls.target.add(move);
    }

    const turn = (keys.has('q') ? 1 : 0) - (keys.has('e') ? 1 : 0);
    if (turn) {
      offset.subVectors(camera.position, controls.target).applyAxisAngle(up, turn * 1.6 * dt);
      camera.position.copy(controls.target).add(offset);
    }

    // Keep the focus point on the map.
    const clamped = controls.target.clone();
    clamped.x = THREE.MathUtils.clamp(clamped.x, -extent, extent);
    clamped.z = THREE.MathUtils.clamp(clamped.z, -extent, extent);
    clamped.y = 0;
    camera.position.add(clamped.clone().sub(controls.target));
    controls.target.copy(clamped);

    controls.update();
  }

  function setLocked(on) {
    locked = on;
    controls.enabled = !on;
    if (on) keys.clear();
  }

  // Slowly circle around the focus point, for the title screen.
  function orbit(angle) {
    offset.subVectors(camera.position, controls.target).applyAxisAngle(up, angle);
    camera.position.copy(controls.target).add(offset);
  }

  function flyTo(x, z) {
    flight = { from: controls.target.clone(), to: new THREE.Vector3(x, 0, z), t: 0 };
  }

  // Big maps let the camera go further out.
  function setExtent(half) {
    extent = half;
    controls.maxDistance = Math.max(90, half * 2.6);
  }

  return { controls, update, setLocked, orbit, flyTo, setExtent };
}
