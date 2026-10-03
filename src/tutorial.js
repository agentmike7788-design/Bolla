import * as THREE from 'three';
import { DIRS } from './factory.js';
import { TERRAIN } from './world.js';

// The guided first game: a card with one step at a time, a glowing outline on the
// button or panel the step is about, and a beacon over the field to build on.
// Every step checks the game itself, so it does not matter how the player gets there.

export const TUTORIAL_SEED = 2915; // iron and copper right in the middle of the island
const DONE_KEY = 'bolla.tutorial';
const TOUCH = matchMedia('(pointer: coarse)').matches;

export function tutorialDone() {
  try {
    return localStorage.getItem(DONE_KEY) === 'done';
  } catch {
    return false;
  }
}

function markDone() {
  try {
    localStorage.setItem(DONE_KEY, 'done');
  } catch {}
}

const buildable = (tile, factory) => tile && TERRAIN[tile.terrain].buildable && !factory.get(tile);
const step = (tile, dir, k, world) => world.at(tile.x + DIRS[dir].x * k, tile.z + DIRS[dir].z * k);
const dist = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);
const firstOf = (factory, test) => {
  for (const b of factory.buildings.values()) if (test(b)) return b;
  return null;
};
const drillOn = (factory, ore) => firstOf(factory, (b) => b.type === 'drill' && b.tile.ore === ore);

// Free ore of a kind closest to the point `from` (world coordinates), preferring
// fields with room to the east, where a fresh drill puts its ore.
function oreField(world, factory, ore, from) {
  let best = null;
  let bestScore = Infinity;
  for (const t of world.tiles) {
    if (t.ore !== ore || factory.get(t)) continue;
    let room = 0;
    while (room < 4 && buildable(step(t, 1, room + 1, world), factory) && !step(t, 1, room + 1, world).ore) room++;
    const score = dist(t.position, from) + (4 - room) * 3;
    if (score < bestScore) {
      best = t;
      bestScore = score;
    }
  }
  return best;
}

// The steps. `done` gets the game state and says whether the step is reached;
// `info` steps wait for the button instead. `focus` is a CSS selector to make glow,
// `beacon` a field to point at.
const STEPS = [
  {
    title: 'Willkommen, Fabrikchef!',
    text: 'Auf dieser Insel liegt Erz. Du baust Bohrer, Bänder und Maschinen, bis aus Erz Zahnräder und Schaltkreise werden. Ich zeig dir die ersten Handgriffe.',
    info: 'Los geht’s',
  },
  {
    title: 'Schau dich um',
    text: TOUCH
      ? 'Wisch mit einem Finger, um die Karte zu verschieben. Mit zwei Fingern zoomst und drehst du.'
      : 'Zieh die Karte mit der linken Maustaste oder lauf mit <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd>. Das Mausrad zoomt, die rechte Maustaste dreht.',
    checks: (g) => [
      ['Karte verschoben', g.cam.moved >= 3],
      ['Gezoomt', g.cam.zoomed >= 4],
    ],
    done: (g) => g.cam.moved >= 3 && g.cam.zoomed >= 4,
  },
  {
    title: 'Der erste Bohrer',
    text: 'Wähl unten rechts den Bohrer, mit der Taste <kbd>1</kbd> geht es schneller.',
    focus: '.tool[data-tool="drill"]',
    enter: (g) => g.flyTo(g.spot.iron),
    beacon: (g) => g.spot.iron,
    done: (g) => g.tool === 'drill' || !!drillOn(g.factory, 'iron'),
  },
  {
    title: 'Bohrer aufs Eisen',
    text: 'Setz ihn auf das markierte Eisenerz, das graublaue Feld. Der gelbe Pfeil zeigt, wo das Erz herauskommt; <kbd>R</kbd> dreht ihn.',
    focus: (g) => (g.tool === 'drill' ? null : '.tool[data-tool="drill"]'),
    beacon: (g) => g.spot.iron,
    done: (g) => !!drillOn(g.factory, 'iron'),
  },
  {
    title: 'Ein Lager',
    text: 'Wähl das Lager (<kbd>3</kbd>) und stell es ein paar Felder vor den Pfeil des Bohrers. Das Lager sammelt alles, was du herstellst.',
    focus: (g) => (g.tool === 'storage' ? null : '.tool[data-tool="storage"]'),
    beacon: (g) => storageSpot(g),
    done: (g) => g.factory.count('storage') > 0,
  },
  {
    title: 'Band ziehen',
    text: 'Wähl das Band (<kbd>2</kbd>) und zieh es mit gedrückter Maustaste vom Bohrer bis ans Lager. Es läuft in die Richtung, in die du ziehst.',
    hint: 'Klappt es nicht? Das Band muss direkt vor dem Pfeil des Bohrers anfangen. Ohne Werkzeug dreht <kbd>R</kbd> den Bohrer unter der Maus.',
    focus: (g) => (g.tool === 'belt' ? null : '.tool[data-tool="belt"]'),
    beacon: (g) => {
      const d = drillOn(g.factory, 'iron');
      return d && step(d.tile, d.dir, 1, g.world);
    },
    done: (g) => g.factory.delivered.iron > 0,
  },
  {
    title: 'Es läuft!',
    text: 'Das Erz kommt im Lager an. Was dort liegt, ist dein Kapital: damit bezahlst du die Forschung.',
    focus: '.hud-store',
    done: (g) => g.factory.stored.iron >= 6 || g.factory.research.done.has('smelting'),
  },
  {
    title: 'Kupfer dazu',
    text: 'Die erste Forschung braucht auch Kupfererz, das orange Feld. Setz einen Bohrer drauf und leg ein Band zu einem Lager. Lager nehmen von allen Seiten an.',
    enter: (g) => g.flyTo(g.copperSpot()),
    beacon: (g) => (drillOn(g.factory, 'copper') ? null : g.copperSpot()),
    done: (g) => g.factory.delivered.copper > 0 || g.factory.research.done.has('smelting'),
  },
  {
    title: 'Erste Forschung',
    text: 'Links oben steht, was du als Nächstes erforschen kannst. Sobald 20 Eisenerz und 20 Kupfererz im Lager liegen, klick auf <b>Erforschen</b>. Mit <kbd>T</kbd> siehst du den ganzen Baum.',
    focus: (g) => (g.factory.research.affordable({ cost: { iron: 20, copper: 20 } }) ? '#goal [data-research], .node[data-id="smelting"] [data-research]' : '#goal'),
    done: (g) => g.factory.research.done.has('smelting'),
  },
  {
    title: 'Ofen ins Band',
    text: 'Wähl den Schmelzofen (<kbd>4</kbd>) und setz ihn direkt auf das Band vom Eisenbohrer. Er ersetzt das Bandstück: Erz geht rein, Barren kommen raus.',
    focus: (g) => (g.tool === 'furnace' ? null : '.tool[data-tool="furnace"]'),
    beacon: (g) => ironBelt(g),
    done: (g) => g.factory.delivered.ironIngot > 0,
  },
  {
    title: 'Deine erste Produktionskette',
    text: 'Erz, Ofen, Barren, Lager: so funktioniert jede Fabrik. Links oben geht es weiter mit Pressen, Platten und dem Konstruktor bis zur Meisterfabrik. Alle Tasten findest du im Menü unter <kbd>Esc</kbd>.',
    info: 'Weiterbauen',
  },
];

// A free field three or four steps in front of the iron drill.
function storageSpot(g) {
  const d = drillOn(g.factory, 'iron');
  if (!d) return null;
  for (const k of [4, 3, 5, 2]) {
    const t = step(d.tile, d.dir, k, g.world);
    if (buildable(t, g.factory) && !t.ore) return t;
  }
  return null;
}

// The second belt behind the iron drill (or the first one), for the furnace.
function ironBelt(g) {
  const d = drillOn(g.factory, 'iron');
  if (!d) return null;
  let tile = null;
  let b = d;
  for (let i = 0; i < 2; i++) {
    const next = g.factory.at(b.tile.x + DIRS[b.dir].x, b.tile.z + DIRS[b.dir].z);
    if (next?.type !== 'belt') break;
    tile = next.tile;
    b = next;
  }
  return tile;
}

// The beacon: a ring on the field and an arrow bobbing above it.
function createBeacon() {
  const group = new THREE.Group();
  const mat = new THREE.MeshBasicMaterial({ color: 0xffd34d, transparent: true, opacity: 0.9, depthWrite: false });
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.42, 0.52, 32), mat);
  ring.rotation.x = -Math.PI / 2;
  const arrow = new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.5, 4), mat);
  arrow.rotation.x = Math.PI;
  group.add(ring, arrow);
  group.visible = false;
  group.renderOrder = 5;
  return {
    group,
    show(tile, t) {
      group.visible = !!tile;
      if (!tile) return;
      const y = Math.max(tile.height ?? 0.4, 0.28) + 0.06;
      group.position.set(tile.position.x, y, tile.position.z);
      const s = 1 + Math.sin(t * 4) * 0.08;
      ring.scale.set(s, s, s);
      arrow.position.y = 1.5 + Math.sin(t * 3) * 0.2;
      arrow.rotation.y = t * 1.5;
    },
  };
}

// `game` hands over what the steps read: factory, world, tool, camera rig, sounds.
export function createTutorial({ root, scene, game, onFinish }) {
  const beacon = createBeacon();
  scene.add(beacon.group);
  const card = document.createElement('aside');
  card.className = 'tut';
  card.hidden = true;
  card.setAttribute('aria-live', 'polite');
  root.append(card);

  let index = -1; // -1: not running
  let spot = {}; // fields picked when the step starts
  let since = 0; // seconds in this step
  let focused = [];
  let shownKey = '';
  const cam = { moved: 0, zoomed: 0, last: null, lastZoom: 0 };

  const running = () => index >= 0;

  function context() {
    const g = game();
    return {
      ...g,
      cam,
      spot,
      copperSpot: () => (spot.copper ??= oreField(g.world, g.factory, 'copper', storageSpotFrom(g)?.position ?? g.target)),
      flyTo: (tile) => tile && g.rig.flyTo(tile.position.x, tile.position.z),
    };
  }
  const storageSpotFrom = (g) => firstOf(g.factory, (b) => b.type === 'storage')?.tile;

  function enter(i) {
    index = i;
    since = 0;
    shownKey = '';
    const g = context();
    if (!spot.iron) spot.iron = oreField(g.world, g.factory, 'iron', g.target);
    cam.moved = 0;
    cam.zoomed = 0;
    cam.last = null;
    STEPS[i].enter?.(g);
    render(g);
  }

  function render(g) {
    const s = STEPS[index];
    const checks = s.checks?.(g) ?? [];
    const hint = s.hint && since > 40;
    const key = `${index}|${checks.map((c) => c[1]).join()}|${hint}`;
    if (key === shownKey) return;
    const fresh = !shownKey.startsWith(`${index}|`);
    shownKey = key;
    card.hidden = false;
    card.innerHTML = `<p class="label"><span>Tutorial · ${index + 1}/${STEPS.length}</span>
        <button type="button" class="link" data-tut="skip">${index === STEPS.length - 1 ? 'Schließen' : 'Überspringen'}</button></p>
      <h3>${s.title}</h3>
      <p>${s.text}</p>
      ${checks.length ? `<ul class="tut-checks">${checks.map(([t, ok]) => `<li class="${ok ? 'ok' : ''}">${t}</li>`).join('')}</ul>` : ''}
      ${hint ? `<p class="tut-hint">${s.hint}</p>` : ''}
      ${s.info ? `<div class="goal-actions"><button type="button" data-tut="next">${s.info}</button></div>` : ''}
      <ol class="steps">${STEPS.map((_, i) => `<li class="${i < index ? 'done' : i === index ? 'now' : ''}"></li>`).join('')}</ol>`;
    if (fresh) {
      card.classList.remove('pop');
      void card.offsetWidth;
      card.classList.add('pop');
    }
  }

  function setFocus(selector) {
    const els = selector ? [...document.querySelectorAll(selector)] : [];
    if (els.length === focused.length && els.every((el, i) => el === focused[i])) return;
    for (const el of focused) el.classList.remove('tut-focus');
    for (const el of els) el.classList.add('tut-focus');
    focused = els;
  }

  function hide() {
    card.hidden = true;
    beacon.group.visible = false;
    setFocus(null);
    document.body.classList.remove('tutorial-on');
  }

  function finish() {
    index = -1;
    hide();
    markDone();
    onFinish?.();
  }

  card.addEventListener('click', (e) => {
    const act = e.target.closest('[data-tut]')?.dataset.tut;
    if (act === 'skip') finish();
    if (act === 'next') next();
  });

  function next() {
    game().audio.play.success();
    if (index + 1 >= STEPS.length) finish();
    else enter(index + 1);
  }

  return {
    get running() {
      return running();
    },
    start(at = 0) {
      spot = {};
      document.body.classList.add('tutorial-on');
      enter(Math.min(at, STEPS.length - 1));
    },
    stop() {
      index = -1;
      hide();
    },
    // `visible` is false while a menu covers the game: the card waits hidden.
    update(dt, elapsed, visible) {
      if (!running()) return;
      if (card.hidden !== !visible) {
        card.hidden = !visible;
        if (!visible) {
          beacon.group.visible = false;
          setFocus(null);
        }
      }
      if (!visible) return;
      since += dt;
      const g = context();
      // Camera: count how far the view moved and zoomed during this step.
      if (cam.last) {
        cam.moved += cam.last.distanceTo(g.target);
        cam.zoomed += Math.abs(g.zoom - cam.lastZoom);
      }
      cam.last = (cam.last ?? new THREE.Vector3()).copy(g.target);
      cam.lastZoom = g.zoom;

      const s = STEPS[index];
      if (!s.info && s.done(g)) return next();
      render(g);
      setFocus(typeof s.focus === 'function' ? s.focus(g) : s.focus);
      beacon.show(s.beacon?.(g) ?? null, elapsed);
    },
    save: () => (running() ? index : null),
  };
}
