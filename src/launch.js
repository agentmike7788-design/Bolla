import * as THREE from 'three';
import { createRocket } from './buildings.js';

// The rocket launch: a short film that takes over the camera. Ten seconds of
// countdown while the camera circles the pad, ignition with smoke rolling out of
// the flame trench, lift-off, and the camera on the ground follows the rocket up
// until it is a spark in the sky. `onDone` runs at the end, also when skipped.

const COUNT = 10; // seconds of countdown
const IGNITE = COUNT; // the engines light at zero
const LIFT = IGNITE + 1.6; // and the clamps let go a moment later
const END = LIFT + 11;
const PAD = 0.6; // top of the launch pad above the silo's tile

const rnd = (a, b) => a + Math.random() * (b - a);
const smooth = (t) => t * t * (3 - 2 * t);
const clamp01 = (t) => Math.min(1, Math.max(0, t));

// Height of the rocket over the pad, `s` seconds after lift-off.
const climb = (s) => (s <= 0 ? 0 : 0.8 * s * s + 0.12 * s * s * s);

export function createLaunch({ scene, camera, rig, audio, effects, root, onDone }) {
  const overlay = document.createElement('div');
  overlay.className = 'launch';
  overlay.hidden = true;
  overlay.innerHTML = `<div class="launch-bar top"></div><div class="launch-bar bottom"></div>
    <p class="launch-label">Raketenstart</p>
    <p class="launch-count" aria-live="assertive"></p>
    <p class="launch-caption"></p>
    <button type="button" class="link launch-skip">Überspringen <kbd>Esc</kbd></button>`;
  root.append(overlay);
  const countEl = overlay.querySelector('.launch-count');
  const captionEl = overlay.querySelector('.launch-caption');
  overlay.querySelector('.launch-skip').addEventListener('click', () => finish());

  let run = null;
  const look = new THREE.Vector3();
  const aim = new THREE.Vector3();
  const tmp = new THREE.Vector3();

  function start(silo) {
    if (run) return;
    const base = new THREE.Vector3(silo.tile.position.x, silo.tile.height + PAD, silo.tile.position.z);
    const rocket = createRocket();
    rocket.group.position.copy(base);
    rocket.group.rotation.y = -silo.dir * (Math.PI / 2);
    scene.add(rocket.group);
    const light = new THREE.PointLight(0xff8a3a, 0, 0, 1.4);
    light.position.copy(base);
    scene.add(light);
    // Start the circle on the side the camera already looks from.
    const from = Math.atan2(camera.position.x - base.x, camera.position.z - base.z);
    run = {
      silo,
      base,
      rocket,
      light,
      t: 0,
      beat: -1,
      from,
      roar: null,
      saved: { position: camera.position.clone(), target: rig.controls.target.clone(), fog: scene.fog?.far },
      ground: null,
    };
    if (scene.fog) scene.fog.far *= 3;
    camera.far = 1200;
    camera.updateProjectionMatrix();
    rig.setLocked(true);
    root.classList.add('cinematic');
    overlay.hidden = false;
    audio.duck(true);
    look.copy(base).y += 2.6;
    countEl.textContent = '';
    captionEl.textContent = 'Alle Systeme bereit';
  }

  function finish() {
    if (!run) return;
    const r = run;
    run = null;
    r.roar?.stop(3);
    scene.remove(r.rocket.group);
    scene.remove(r.light);
    r.light.dispose();
    if (scene.fog) scene.fog.far = r.saved.fog;
    camera.far = 400;
    camera.updateProjectionMatrix();
    camera.position.copy(r.saved.position);
    rig.controls.target.copy(r.saved.target);
    camera.lookAt(r.saved.target);
    rig.setLocked(false);
    root.classList.remove('cinematic');
    overlay.hidden = true;
    audio.duck(false);
    onDone?.(r.silo, r.base);
  }

  function update(dt) {
    if (!run) return;
    const r = run;
    r.t += dt;
    const t = r.t;
    const s = t - LIFT;
    const h = climb(s);
    r.rocket.group.position.set(r.base.x, r.base.y + h, r.base.z);

    // Countdown, captions and sound on each whole second.
    const beat = Math.floor(t);
    if (beat !== r.beat) {
      r.beat = beat;
      if (beat < COUNT) {
        countEl.textContent = String(COUNT - beat);
        countEl.classList.remove('tick');
        void countEl.offsetWidth;
        countEl.classList.add('tick');
        audio.play.beep(beat === COUNT - 1);
        captionEl.textContent = ['Alle Systeme bereit', 'Treibstoff unter Druck', 'Startturm frei', 'Bordcomputer übernimmt'][Math.min(3, Math.floor(beat / 3))];
      } else if (beat === IGNITE) {
        countEl.textContent = 'Zündung';
        captionEl.textContent = '';
        audio.play.ignition();
        r.roar = audio.rocket();
        r.roar.set(0.6);
      } else if (beat === Math.ceil(LIFT)) {
        countEl.textContent = 'Abheben!';
      } else if (beat === Math.ceil(LIFT) + 3) {
        countEl.textContent = '';
        captionEl.textContent = 'Die Rakete steigt';
      } else if (beat === Math.floor(END) - 3) {
        captionEl.textContent = 'Auf dem Weg ins All';
      }
    }
    if (r.roar && s > 0) r.roar.set(1 / (1 + h / 70), clamp01(h / 150));

    // The engines: flame, light, smoke and sparks.
    const burning = t >= IGNITE;
    const flame = r.rocket.flame;
    flame.visible = burning;
    if (burning) {
      const k = clamp01((t - IGNITE) / 0.6);
      const flick = 1 + Math.sin(t * 61) * 0.08 + Math.sin(t * 37) * 0.06;
      flame.scale.set(k * flick, k * (1 + clamp01(s / 3) * 1.6) * flick, k * flick);
      r.light.position.set(r.base.x, r.base.y + h - 0.4, r.base.z);
      r.light.intensity = k * (90 + Math.sin(t * 43) * 20) / (1 + h / 40);
    }
    emitParticles(r, t, s, h, dt);

    // Camera: a slow circle during the countdown, then down on the ground
    // looking up after the rocket, shaken by the roar.
    if (t < IGNITE) {
      const k = smooth(t / IGNITE);
      const a = r.from + 0.2 + k * 1.1;
      const radius = 13 - k * 4;
      camera.position.set(r.base.x + Math.sin(a) * radius, r.base.y + 4.2 - k * 2.4, r.base.z + Math.cos(a) * radius);
      look.set(r.base.x, r.base.y + 2.4, r.base.z);
    } else {
      if (!r.ground) {
        const a = r.from + 1.5;
        r.ground = new THREE.Vector3(r.base.x + Math.sin(a) * 9.5, r.base.y + 1, r.base.z + Math.cos(a) * 9.5);
      }
      const rise = smooth(clamp01(s / 9));
      camera.position.copy(r.ground);
      camera.position.y += rise * 5;
      // Pull back a little as it climbs, so the trail stays in view.
      tmp.subVectors(r.ground, r.base).setY(0).normalize().multiplyScalar(rise * 6);
      camera.position.add(tmp);
      aim.set(r.base.x, r.base.y + 2.4 + h, r.base.z);
      look.lerp(aim, Math.min(1, dt * 5));
      const shake = burning ? 0.14 * clamp01((t - IGNITE) * 2) / (1 + h / 25) : 0;
      camera.position.x += (Math.random() - 0.5) * shake;
      camera.position.y += (Math.random() - 0.5) * shake;
    }
    camera.lookAt(look);
    rig.controls.target.copy(look);

    if (t >= END) finish();
  }

  function emitParticles(r, t, s, h, dt) {
    const { x, y, z } = r.base;
    const n = (perSecond) => {
      const f = perSecond * dt;
      return Math.floor(f) + (Math.random() < f % 1 ? 1 : 0);
    };
    // Cold vapour off the rocket during the countdown.
    if (t < IGNITE) {
      for (let i = n(18); i--; ) {
        const a = Math.random() * Math.PI * 2;
        effects.emit({ x: x + Math.cos(a) * 0.32, y: y + rnd(1, 3.6), z: z + Math.sin(a) * 0.32, vx: Math.cos(a) * rnd(0.3, 0.8), vy: rnd(-0.4, 0), vz: Math.sin(a) * rnd(0.3, 0.8), life: rnd(1, 1.8), size: 0.25, grow: 2.5, color: effects.color(0xf4f8fa, 0.03), gravity: -0.2, drag: 1.2, fade: 0.5 });
      }
      return;
    }
    // Ignition and lift-off: smoke rolls out over the ground from under the pad.
    if (s < 4) {
      for (let i = n(110); i--; ) {
        const a = Math.random() * Math.PI * 2;
        const v = rnd(3, 7);
        effects.emit({ x, y: y - 0.2, z, vx: Math.cos(a) * v, vy: rnd(0.4, 1.6), vz: Math.sin(a) * v, life: rnd(2.5, 4.5), size: rnd(0.7, 1.1), grow: 3.5, color: effects.color(0xe2ddd4, 0.06), gravity: 0.15, drag: 1.1, fade: 0.75 });
      }
    }
    // Fire and sparks straight out of the engines.
    for (let i = n(220); i--; ) {
      effects.emit({ x: x + rnd(-0.15, 0.15), y: y + h - 0.2, z: z + rnd(-0.15, 0.15), vx: rnd(-1, 1), vy: rnd(-14, -8), vz: rnd(-1, 1), life: rnd(0.15, 0.35), size: rnd(0.25, 0.45), grow: 1.2, color: effects.color(Math.random() < 0.4 ? 0xffe6a0 : 0xff7a2a, 0.1), gravity: 0, drag: 2, floor: y - 0.1 }, true);
    }
    // A thick white trail behind the climbing rocket.
    if (s > 0) {
      for (let i = n(70); i--; ) {
        effects.emit({ x: x + rnd(-0.3, 0.3), y: y + h - rnd(0.5, 2), z: z + rnd(-0.3, 0.3), vx: rnd(-0.4, 0.4), vy: rnd(-1, 0), vz: rnd(-0.4, 0.4), life: rnd(3, 5), size: rnd(0.9, 1.3) + h * 0.01, grow: 2.5, color: effects.color(0xf0ede8, 0.04), gravity: 0.05, drag: 0.6, fade: 0.7 });
      }
    }
  }

  return {
    start,
    update,
    skip: finish,
    get active() {
      return !!run;
    },
  };
}
