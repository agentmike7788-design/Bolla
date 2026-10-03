import { ITEMS, BUILDINGS } from './factory.js';

const hex = (color) => `#${color.toString(16).padStart(6, '0')}`;
const SIGNAL = 0xffd34d;
const POWER = 0x7fd4ff;
const OIL = 0xe0a040;
const RAIL = 0xe07a2e;

export const clock = (seconds) => {
  const s = Math.floor(seconds);
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;
};

function goalRow(p) {
  const name = p.oil
    ? 'Öl pumpen'
    : p.shipped
    ? 'Teile per Zug liefern'
    : p.powered
    ? 'Maschinen mit Strom'
    : p.building
      ? `${BUILDINGS[p.building].name} bauen`
      : `${ITEMS[p.item].name}${p.rate ? ' pro Minute' : ''}`;
  const color = p.oil ? OIL : p.shipped ? RAIL : p.powered ? POWER : p.building ? SIGNAL : ITEMS[p.item].color;
  const have = Math.min(p.have, p.need);
  const done = p.have >= p.need;
  return `<li style="--c:${hex(color)}" class="${done ? 'met' : ''}${p.rate ? ' rate' : ''}">
    <span class="swatch"></span><span class="name">${name}</span>
    <span class="num">${done ? '✓' : `${have}/${p.need}`}</span>
    <span class="bar"><i style="width:${(have / p.need) * 100}%"></i></span></li>`;
}

// The mission panel in the corner, used instead of the research panel on scenario maps.
export function createMissionView({ panel, getGame }) {
  let shown = null; // mission the panel was built for

  function render() {
    const { scenario, missions } = getGame();
    const m = missions.current;
    shown = m;
    if (!m) {
      panel.innerHTML = `<p class="label">${scenario.name} · geschafft</p>
        <p class="goal-name">Alle Missionen erfüllt</p>
        <p class="goal-unlock">Baue weiter, so groß du willst, oder nimm dir die nächste Karte vor.</p>
        <div class="goal-actions"><button type="button" class="link" data-maps>Karten <kbd>M</kbd></button></div>`;
      return;
    }
    const total = scenario.missions.length;
    panel.innerHTML = `<p class="label mission-head"><span>Mission ${missions.index + 1}/${total}${missions.index + 1 === total ? ' · Finale' : ''}</span><span class="clock"></span></p>
      <p class="goal-name">${m.name}</p>
      <p class="goal-desc">${m.desc}</p>
      <ul class="goals"></ul>
      <p class="goal-unlock">Belohnung: <b>${m.reward.text}</b></p>
      <ol class="steps">${scenario.missions.map((_, i) => `<li class="${i < missions.index ? 'done' : i === missions.index ? 'now' : ''}"></li>`).join('')}</ol>`;
    update();
  }

  function update() {
    const { missions, factory } = getGame();
    if (missions.current !== shown) return render();
    if (!shown) return;
    panel.querySelector('.goals').innerHTML = missions.goals().map(goalRow).join('');
    panel.querySelector('.clock').textContent = clock(factory.time);
  }

  return { render, update };
}
