import { CHAPTERS, CAMPAIGN, STORY, PERKS, VOICES, loadCampaign, isUnlocked, perksFor, campaignIndex } from './campaign.js';
import { scenarioById, loadRecords } from './scenarios.js';
import { biomeOf } from './biomes.js';
import { ENEMY_MODES } from './enemies.js';
import { listSaves, whenText } from './save.js';
import { clock } from './missionView.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const starText = (n) => '★'.repeat(n) + '☆'.repeat(3 - n);
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

// The radio: story lines from the campaign, one after another in a box at the
// bottom of the screen. Each line types itself out; a click skips ahead.
export function createRadio({ root, audio }) {
  const queue = [];
  const log = []; // lines of the running map, for "Funk wiederholen"
  let line = null;
  let shown = 0; // characters typed so far
  let hold = 0; // seconds the finished line stays up
  let gap = 0; // pause between two lines

  function next() {
    line = queue.shift() ?? null;
    if (!line) {
      root.hidden = true;
      return;
    }
    const v = VOICES[line[0]];
    shown = reducedMotion ? line[1].length : 0;
    hold = 2.4 + line[1].length * 0.035;
    root.style.setProperty('--voice', v.color);
    root.innerHTML = `<span class="radio-icon" aria-hidden="true">${v.icon}</span>
      <span class="radio-body"><span class="radio-who"><b>${v.name}</b> · ${v.role}</span>
      <span class="radio-text" aria-label="${esc(line[1])}"></span></span>
      <span class="radio-more" aria-hidden="true">${queue.length ? `${queue.length} weitere` : ''}</span>`;
    root.hidden = false;
    root.classList.remove('pop');
    void root.offsetWidth;
    root.classList.add('pop');
    audio.play.radio();
    type();
  }

  function type() {
    const el = root.querySelector('.radio-text');
    if (el) el.textContent = line[1].slice(0, Math.ceil(shown));
  }

  root.addEventListener('click', () => {
    if (!line) return;
    if (shown < line[1].length) {
      shown = line[1].length;
      type();
    } else {
      hold = 0;
    }
  });

  return {
    // Queues lines; `fresh` starts the log of a new map, `delay` waits before the first.
    say(lines, { fresh = false, delay = 0 } = {}) {
      if (fresh) this.clear();
      const add = (lines ?? []).filter(Boolean);
      log.push(...add);
      queue.push(...add);
      gap = Math.max(gap, delay);
      if (!line && gap <= 0) next();
    },
    replay() {
      queue.length = 0;
      queue.push(...log.slice(-4));
      line = null;
      next();
    },
    clear() {
      queue.length = 0;
      log.length = 0;
      line = null;
      gap = 0;
      root.hidden = true;
    },
    // Called every frame, also while the game is paused in a menu.
    update(dt) {
      if (!line) {
        if (queue.length && (gap -= dt) <= 0) next();
        return;
      }
      if (shown < line[1].length) {
        shown = Math.min(line[1].length, shown + dt * 48);
        type();
        return;
      }
      if ((hold -= dt) > 0) return;
      line = null;
      gap = 0.35;
      if (!queue.length) root.hidden = true;
    },
    get hasLog() {
      return log.length > 0;
    },
  };
}

// The big title card when a chapter starts.
export function showChapterCard(root, chapterIndex) {
  const c = CHAPTERS[chapterIndex];
  root.innerHTML = `<p class="label">Kapitel ${chapterIndex + 1}</p><h2>${c.name}</h2><p>${c.text}</p>`;
  root.hidden = false;
  root.classList.remove('show');
  void root.offsetWidth;
  root.classList.add('show');
  clearTimeout(root._timer);
  root._timer = setTimeout(() => (root.hidden = true), reducedMotion ? 5000 : 6500);
  root.onclick = () => (root.hidden = true);
}

// The campaign screen: chapters as a route of map nodes, details of the picked map.
export function createCampaignView({ root, audio, onStart, onLoad }) {
  const route = root.querySelector('.cp-route');
  const detail = root.querySelector('.cp-detail');
  const summary = root.querySelector('.cp-summary');
  let selected = null;

  // The latest campaign save of a map, if there is one.
  const saveOf = (id) => listSaves().find((s) => s.scenario === id && s.campaign);

  function render() {
    const progress = loadCampaign();
    const records = loadRecords();
    const done = CAMPAIGN.filter((m) => progress.done[m.id]).length;
    const stars = CAMPAIGN.reduce((n, m) => n + (records[m.id]?.stars ?? 0), 0);
    summary.textContent = `${done} von ${CAMPAIGN.length} Karten · ${stars} von ${CAMPAIGN.length * 3} ★`;
    // Default: the first open map not yet done.
    selected ??= (CAMPAIGN.find((m) => isUnlocked(m.id, progress, records) && !progress.done[m.id]) ?? CAMPAIGN[CAMPAIGN.length - 1]).id;

    route.innerHTML = CHAPTERS.map((c, ci) => {
      const open = isUnlocked(c.maps[0], progress, records);
      const nodes = c.maps
        .map((id) => {
          const s = scenarioById(id);
          const unlocked = isUnlocked(id, progress, records);
          const r = records[id];
          const state = progress.done[id] ? 'done' : unlocked ? 'open' : 'locked';
          return `<button type="button" class="cp-node ${state}" data-map="${id}" aria-pressed="${id === selected}" ${unlocked ? '' : 'aria-disabled="true"'}>
            <span class="cp-dot">${state === 'locked' ? '🔒' : campaignIndex(id) + 1}</span>
            <span class="cp-node-name">${s.name}</span>
            <span class="cp-node-stars">${r ? starText(r.stars) : state === 'open' ? 'neu' : ''}</span>
          </button>`;
        })
        .join('<span class="cp-link" aria-hidden="true"></span>');
      return `<section class="cp-chapter${open ? '' : ' locked'}">
        <p class="label">Kapitel ${ci + 1}</p><h3>${c.name}</h3>
        <div class="cp-nodes">${nodes}</div>
      </section>`;
    }).join('');

    renderDetail(progress, records);
  }

  function renderDetail(progress, records) {
    const s = scenarioById(selected);
    const story = STORY[selected];
    const ci = CAMPAIGN[campaignIndex(selected)].chapter;
    const unlocked = isUnlocked(selected, progress, records);
    const r = records[selected];
    const perks = perksFor(selected, progress);
    const save = saveOf(selected);
    const look = biomeOf(s.map?.biome);
    const picked = progress.perks[selected];
    const prev = CAMPAIGN[campaignIndex(selected) - 1];
    detail.innerHTML = `<p class="label">Kapitel ${ci + 1} · ${CHAPTERS[ci].name}</p>
      <h3>${s.name}</h3>
      <p class="cp-tags">${'●'.repeat(s.level)}${'○'.repeat(4 - s.level)} · ${s.missions.length} Missionen${s.map?.biome ? ` · ${look.icon} ${look.name}` : ''}${s.enemies ? ` · 🪲 ${ENEMY_MODES[s.enemies].name}` : ''}</p>
      <p class="cp-brief">${story.brief}</p>
      <p class="cp-best">${r ? `${starText(r.stars)} Bestzeit ${clock(r.time)} · drei Sterne unter ${s.par} Minuten` : `Drei Sterne unter ${s.par} Minuten`}</p>
      <p class="label cp-perk-label">Mitbringsel für diese Karte</p>
      ${perks.length ? `<ul class="cp-perks">${perks.map((p) => `<li title="${PERKS[p].text}"><span aria-hidden="true">${PERKS[p].icon}</span>${PERKS[p].name}<small>${PERKS[p].text}</small></li>`).join('')}</ul>` : '<p class="cp-none">Noch keine. Nach jeder Karte wählst du eins aus.</p>'}
      ${picked ? `<p class="cp-picked">Hier verdient: ${PERKS[picked].icon} ${PERKS[picked].name}</p>` : ''}
      <div class="goal-actions">
        ${unlocked
          ? `${save ? `<button type="button" data-load="${save.id}">Fortsetzen</button>` : ''}
             <button type="button" ${save ? 'class="link"' : ''} data-start="${selected}">${save ? 'Neu beginnen' : progress.done[selected] ? 'Noch mal spielen' : 'Starten'}</button>`
          : `<p class="cp-none">Öffnet sich, wenn ${scenarioById(prev.id).name} geschafft ist.</p>`}
      </div>
      ${save ? `<p class="cp-save">Spielstand ${whenText(save.savedAt)}</p>` : ''}`;
  }

  root.addEventListener('click', (e) => {
    if (e.target.closest('[data-close]') || e.target === root) return close();
    const node = e.target.closest('[data-map]');
    if (node) {
      audio.play.click();
      selected = node.dataset.map;
      return render();
    }
    const start = e.target.closest('[data-start]');
    if (start) {
      audio.play.click();
      close();
      return onStart(start.dataset.start);
    }
    const load = e.target.closest('[data-load]');
    if (load) {
      audio.play.click();
      close();
      onLoad(load.dataset.load);
    }
  });

  function open(id = null) {
    if (id) selected = id;
    render();
    root.hidden = false;
    root.querySelector('.cp-node[aria-pressed="true"]')?.focus({ preventScroll: true });
  }
  function close() {
    root.hidden = true;
  }

  return {
    open,
    close,
    get isOpen() {
      return !root.hidden;
    },
  };
}

// The keepsake choice on the win screen of a campaign map.
export function perkChoice(id, progress) {
  const picked = progress.perks[id];
  const offers = STORY[id]?.perks ?? [];
  if (!offers.length) return '';
  return `<p class="label">${picked ? 'Dein Mitbringsel' : 'Wähle ein Mitbringsel für die nächsten Karten'}</p>
    <div class="cp-choice">${offers
      .map((p) => {
        const k = PERKS[p];
        return `<button type="button" class="cp-offer" data-perk="${p}" aria-pressed="${p === picked}" ${picked ? 'disabled' : ''}>
          <span class="cp-offer-icon" aria-hidden="true">${k.icon}</span><b>${k.name}</b><small>${k.text}</small></button>`;
      })
      .join('')}</div>`;
}
