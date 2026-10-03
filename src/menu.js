import { listSaves, whenText, playTimeText } from './save.js';
import { ACHIEVEMENTS, loadAchievements } from './achievements.js';
import { ENEMY_MODES } from './enemies.js';

// The title screen and the pause menu. Both share one overlay: a column of
// big menu entries on the left and the open page (saves, settings, controls)
// next to it. The game behind keeps rendering, paused.

const CONTROLS = [
  ['Kamera', [['Linke Maus ziehen', 'Karte verschieben'], ['Rechte Maus / Q E', 'drehen'], ['Mausrad', 'zoomen'], ['W A S D', 'bewegen']]],
  ['Bauen', [['1 – 9, 0', 'Gebäude wählen (9 Kraftwerk, 0 Mast)'], ['O P I K', 'Ölpumpe, Rohr, Raffinerie, Tank'], ['G B Z J', 'Gleis, Bahnhof, Zug, Signal'], ['F V C', 'Drohnenhafen, Angebots-, Anfragekiste'], ['H', 'Raketensilo'], [', . -', 'Mauer, Geschützturm, Laserturm'], ['Klick / Ziehen', 'bauen, Bänder und Rohre ziehen'], ['R', 'drehen'], ['X', 'abreißen'], ['Klick auf Konstruktor oder Raffinerie', 'Rezept wählen'], ['Klick auf Bahnhof oder Zug', 'Betriebsart, Fahrplan'], ['Klick auf Signal oder Anfragekiste', 'Art und Richtung, gewünschtes Teil'], ['Klick auf Raketensilo', 'Etappen, Raketenstart'], ['Esc', 'Werkzeug weglegen']]],
  ['Spiel', [['Y', 'Erdwärmekraftwerk (Vulkan)'], ['Ö Ä #', 'Solarpanel, Windrad, Akku'], ['T', 'Forschungsbaum'], ['L', 'Statistik'], ['Leertaste', 'zum letzten Angriff'], ['M', 'Karten'], ['N', 'nächste Tageszeit'], ['U', 'Ton an / aus'], ['Strg S', 'speichern'], ['Esc', 'Menü']]],
  ['Touch', [['Ein Finger', 'verschieben oder bauen'], ['Zwei Finger', 'zoomen und drehen']]],
];

const segmented = (key, value, options) =>
  `<div class="segmented" role="radiogroup">${options
    .map(([v, label]) => `<button type="button" role="radio" data-set="${key}" data-value="${v}" aria-checked="${String(v) === String(value)}">${label}</button>`)
    .join('')}</div>`;

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

function saveMeta(s) {
  return `${whenText(s.savedAt)} · ${playTimeText(s.playTime)} · ${s.buildings} Gebäude`;
}

export function createMenu({ root, audio, dayNight, graphics, onGraphics, actions }) {
  let mode = null; // 'title', 'pause' or null when closed
  let page = 'main';
  let confirmDelete = null;
  let introTimer = 0;

  const file = document.createElement('input');
  file.type = 'file';
  file.accept = '.json,application/json';
  file.hidden = true;
  root.after(file);

  function nav() {
    const latest = listSaves()[0];
    const items =
      mode === 'title'
        ? [
            latest && ['continue', 'Weiterspielen', latest.name],
            ['new', 'Neues Spiel', 'Karte wählen'],
            ['tutorial', 'Tutorial', actions.tutorialDone() ? 'noch mal ansehen' : 'erste Schritte, 5 Minuten'],
            ['load', 'Laden', `${listSaves().length || 'keine'} Spielstände`],
            ['achievements', 'Erfolge', achievementCount()],
            ['settings', 'Einstellungen', 'Ton und Grafik'],
            ['controls', 'Steuerung', 'Tasten und Maus'],
          ]
        : [
            ['resume', 'Weiterspielen', 'Esc'],
            ['save', 'Speichern', 'Strg S'],
            ['load', 'Laden', ''],
            ['achievements', 'Erfolge', achievementCount()],
            ['settings', 'Einstellungen', ''],
            ['controls', 'Steuerung', ''],
            ['title', 'Hauptmenü', 'speichert vorher'],
          ];
    return items
      .filter(Boolean)
      .map(
        ([act, label, hint]) =>
          `<button type="button" class="gm-item" data-act="${act}" aria-current="${act === page}"><span>${label}</span>${hint ? `<small>${esc(hint)}</small>` : ''}</button>`,
      )
      .join('');
  }

  function mainPage() {
    if (mode !== 'title') return '';
    const latest = listSaves()[0];
    if (!latest || !actions.tutorialDone()) {
      return `<div class="gm-card gm-hello">
        <p class="label">Willkommen</p>
        <h3>Deine erste Fabrik</h3>
        <p>Setz Bohrer auf Erz, leg Bänder zu einem Lager und arbeite dich vom Erz bis zum Schaltkreis vor. Das Tutorial zeigt dir in ein paar Minuten, wie es geht.</p>
        <div class="goal-actions"><button type="button" data-act="tutorial">Tutorial starten</button>
          <button type="button" class="link" data-act="${latest ? 'continue' : 'new'}">${latest ? 'Weiterspielen' : 'Ohne Tutorial'}</button></div>
      </div>`;
    }
    return `<button type="button" class="gm-card gm-continue" data-act="continue">
      ${latest.thumb ? `<img src="${latest.thumb}" alt="" />` : '<span class="gm-thumb"></span>'}
      <span class="label">Zuletzt gespielt</span>
      <span class="gm-name">${esc(latest.name)}</span>
      <span class="gm-meta">${saveMeta(latest)}</span>
    </button>`;
  }

  function loadPage() {
    const saves = listSaves();
    const current = actions.currentId();
    const rows = saves
      .map((s) => {
        const running = s.id === current && mode === 'pause';
        return `<li class="gm-save${running ? ' current' : ''}">
          ${s.thumb ? `<img src="${s.thumb}" alt="" />` : '<span class="gm-thumb"></span>'}
          <div class="gm-save-text">
            <span class="gm-name">${esc(s.name)}${running ? ' <span class="tag">Läuft</span>' : ''}</span>
            <span class="gm-meta">${saveMeta(s)}</span>
          </div>
          <div class="gm-save-actions">
            ${running ? '' : `<button type="button" data-act="load-slot" data-id="${s.id}">Laden</button>`}
            <button type="button" class="link" data-act="export" data-id="${s.id}" title="Als Datei sichern">Export</button>
            ${running ? '' : `<button type="button" class="link danger" data-act="delete" data-id="${s.id}">${confirmDelete === s.id ? 'Wirklich löschen?' : 'Löschen'}</button>`}
          </div>
        </li>`;
      })
      .join('');
    return `<header class="gm-head"><h2>Spielstände</h2>
        <button type="button" class="link" data-act="import">Datei importieren</button></header>
      <p class="gm-note">Gespeichert wird in diesem Browser, automatisch und mit Strg S. Mit Export nimmst du einen Spielstand als Datei mit.</p>
      ${saves.length ? `<ul class="gm-saves">${rows}</ul>` : '<p class="gm-empty">Noch keine Spielstände. Sie entstehen, sobald du baust.</p>'}`;
  }

  function settingsPage() {
    const a = audio.settings;
    return `<header class="gm-head"><h2>Einstellungen</h2></header>
      <div class="gm-settings">
        <section>
          <p class="label">Ton</p>
          <label class="slider"><span>Lautstärke</span><input type="range" data-audio="volume" min="0" max="1" step="0.05" value="${a.volume}" /></label>
          <label class="slider"><span>Musik</span><input type="range" data-audio="music" min="0" max="1" step="0.05" value="${a.music}" /></label>
          <label class="check"><input type="checkbox" data-audio="muted" ${a.muted ? 'checked' : ''} /> Stumm <kbd>U</kbd></label>
        </section>
        <section>
          <p class="label">Grafik</p>
          <div class="gm-row"><span>Schatten</span>${segmented('shadows', graphics.shadows, [['off', 'Aus'], ['normal', 'Normal'], ['high', 'Hoch']])}</div>
          <div class="gm-row"><span>Auflösung</span>${segmented('resolution', graphics.resolution, [['low', 'Sparsam'], ['normal', 'Mittel'], ['high', 'Scharf']])}</div>
          <div class="gm-row"><span>Partikel</span>${segmented('particles', graphics.particles, [[false, 'Aus'], [true, 'An']])}</div>
          <div class="gm-row"><span>Tageszeit</span>${segmented('daymode', dayNight.mode, [['cycle', 'Wechselt'], ['day', 'Tag'], ['night', 'Nacht']])}</div>
        </section>
        <section>
          <p class="label">Spiel</p>
          <div class="gm-row"><span>Autospeichern</span>${segmented('autosave', graphics.autosave, [[0, 'Aus'], [60, 'Jede Minute'], [300, 'Alle 5 Min.']])}</div>
          ${mode === 'pause' ? `<div class="gm-row"><span>Gegner in diesem Spiel</span>${segmented('enemies', actions.enemyMode(), Object.entries(ENEMY_MODES).map(([id, m]) => [id, m.name]))}</div>
          <p class="gm-note">${ENEMY_MODES[actions.enemyMode()].desc}. Neue Nester entstehen nur fern von deinen Gebäuden.</p>` : ''}
        </section>
      </div>`;
  }

  function achievementCount() {
    const earned = loadAchievements();
    return `${ACHIEVEMENTS.filter((a) => earned[a.id]).length} von ${ACHIEVEMENTS.length}`;
  }

  function achievementsPage() {
    const earned = loadAchievements();
    const cards = ACHIEVEMENTS.map((a) => {
      const when = earned[a.id];
      const hidden = a.secret && !when;
      return `<li class="gm-ach${when ? ' earned' : ''}">
        <span class="gm-ach-icon" aria-hidden="true">${hidden ? '❔' : a.icon}</span>
        <span class="gm-ach-text"><b>${hidden ? '???' : a.name}</b><small>${hidden ? 'Ein geheimer Erfolg' : a.desc}</small>
        ${when ? `<small class="gm-ach-when">${whenText(when)}</small>` : ''}</span>
      </li>`;
    }).join('');
    return `<header class="gm-head"><h2>Erfolge</h2><span class="gm-note">${achievementCount()}</span></header>
      <p class="gm-note">Erfolge gelten für alle Spiele in diesem Browser.</p>
      <ul class="gm-achs">${cards}</ul>`;
  }

  function controlsPage() {
    return `<header class="gm-head"><h2>Steuerung</h2></header>
      <div class="gm-controls">${CONTROLS.map(
        ([group, rows]) => `<section><p class="label">${group}</p><dl>${rows.map(([k, t]) => `<dt><kbd>${k}</kbd></dt><dd>${t}</dd>`).join('')}</dl></section>`,
      ).join('')}</div>`;
  }

  function render() {
    root.dataset.mode = mode ?? '';
    const head =
      mode === 'title'
        ? `<h1 class="gm-logo"><span>Bolla</span><span>Fabrik</span></h1>
           <p class="gm-tag">Erz abbauen. Bänder legen. Eine Fabrik bauen, die nie stillsteht.</p>`
        : `<p class="label">Spiel angehalten</p><h2 class="gm-logo gm-pause">Pause</h2>
           <p class="gm-tag">${esc(actions.gameName())}</p>`;
    const body = { main: mainPage, load: loadPage, settings: settingsPage, controls: controlsPage, achievements: achievementsPage }[page]();
    root.innerHTML = `<div class="gm-side">${head}<nav class="gm-nav">${nav()}</nav>
        <p class="gm-foot">${page === 'main' ? (mode === 'pause' ? '<kbd>Esc</kbd> weiter' : '<kbd>↑ ↓</kbd> wählen · <kbd>Enter</kbd> los') : '<kbd>Esc</kbd> zurück'}</p></div>
      <section class="gm-page" ${body ? '' : 'hidden'}>${body}</section>`;
  }

  function open(next) {
    mode = next;
    page = 'main';
    confirmDelete = null;
    root.hidden = false;
    // The title screen slides in once; later page changes redraw without it.
    root.classList.toggle('intro', next === 'title');
    clearTimeout(introTimer);
    introTimer = setTimeout(() => root.classList.remove('intro'), 1200);
    render();
    root.querySelector('.gm-item')?.focus({ preventScroll: true });
  }

  function close() {
    mode = null;
    root.hidden = true;
  }

  function show(next) {
    page = next;
    confirmDelete = null;
    render();
    root.querySelector(`.gm-item[data-act="${next}"]`)?.focus({ preventScroll: true });
  }

  root.addEventListener('click', (e) => {
    const el = e.target.closest('[data-act], [data-set]');
    if (!el) return;
    audio.play.click();
    if (el.dataset.set) return setOption(el.dataset.set, el.dataset.value);
    const { act, id } = el.dataset;
    if (act === 'delete' && confirmDelete !== id) {
      confirmDelete = id;
      return render();
    }
    if (['load', 'settings', 'controls', 'achievements'].includes(act)) return show(page === act ? 'main' : act);
    if (act === 'import') return file.click();
    const run = {
      continue: actions.continueGame,
      new: actions.newGame,
      tutorial: actions.tutorial,
      resume: actions.resume,
      save: actions.save,
      title: actions.toTitle,
      'load-slot': () => actions.load(id),
      export: () => actions.exportSave(id),
      delete: () => actions.deleteSave(id),
    }[act];
    run?.();
    confirmDelete = null;
    if (mode && act !== 'title') render();
  });

  root.addEventListener('input', (e) => {
    const key = e.target.dataset.audio;
    if (!key) return;
    if (key === 'muted') audio.set({ muted: e.target.checked });
    else audio.set({ [key]: Number(e.target.value), ...(key === 'volume' ? { muted: false } : {}) });
  });
  root.addEventListener('change', (e) => {
    if (e.target.dataset.audio === 'volume') {
      audio.play.build('drill');
      render();
    }
  });

  file.addEventListener('change', async () => {
    const f = file.files[0];
    file.value = '';
    if (!f) return;
    actions.importSave(await f.text());
    if (mode) show('load');
  });

  function setOption(key, value) {
    if (key === 'daymode') dayNight.setMode(value);
    else if (key === 'enemies') actions.setEnemyMode(value);
    else if (key === 'particles') onGraphics({ particles: value === 'true' });
    else if (key === 'autosave') onGraphics({ autosave: Number(value) });
    else onGraphics({ [key]: value });
    render();
  }

  // Up and down walk through the menu entries.
  root.addEventListener('keydown', (e) => {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    const items = [...root.querySelectorAll('.gm-item')];
    const i = items.indexOf(document.activeElement);
    if (i < 0 && !e.target.closest('.gm-nav')) return;
    e.preventDefault();
    const next = items[(i + (e.key === 'ArrowDown' ? 1 : items.length - 1)) % items.length];
    next?.focus();
  });

  return {
    openTitle: () => open('title'),
    openPause: () => open('pause'),
    close,
    refresh: () => mode && render(),
    // Esc: close the open page first, then leave the pause menu.
    back() {
      if (page !== 'main') show('main');
      else if (mode === 'pause') actions.resume();
    },
    get mode() {
      return mode;
    },
    get isOpen() {
      return !!mode;
    },
  };
}
