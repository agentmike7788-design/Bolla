// Every sound in the game is made right here with the Web Audio API: short
// synthesized effects, looping machine noises that swell as the camera gets
// close, and a slow generative background tune. No audio files needed.

const SETTINGS_KEY = 'bolla-audio';
const MACHINE_TYPES = ['drill', 'furnace', 'assembler', 'constructor', 'belt', 'power', 'pump', 'refinery', 'train'];
const LOOP_SECONDS = 2.4;

function loadSettings() {
  try {
    return { volume: 0.7, music: 0.5, muted: false, ...JSON.parse(localStorage.getItem(SETTINGS_KEY) ?? '{}') };
  } catch {
    return { volume: 0.7, music: 0.5, muted: false };
  }
}

export function createAudio() {
  const settings = loadSettings();
  let ctx = null;
  let master;
  let sfx;
  let machineBus;
  let musicBus;
  let noise; // one second of white noise, shared by all effects
  const loops = {}; // machine type -> { gain, pan }
  let music = null;
  const lastTick = {};
  let night = 0;

  // Browsers only allow audio after a user gesture, so the context starts on the first one.
  function unlock() {
    if (ctx) {
      if (ctx.state === 'suspended') ctx.resume();
      return;
    }
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return;
    ctx = new AC();
    master = ctx.createGain();
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -14;
    comp.ratio.value = 4;
    master.connect(comp).connect(ctx.destination);
    sfx = bus(1);
    machineBus = bus(0.55);
    musicBus = bus(1);
    applySettings();
    noise = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const d = noise.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    for (const type of MACHINE_TYPES) startLoop(type);
    music = createMusic();
  }
  for (const ev of ['pointerdown', 'keydown', 'touchend']) window.addEventListener(ev, unlock, { passive: true });
  document.addEventListener('visibilitychange', () => {
    if (!ctx) return;
    if (document.hidden) ctx.suspend();
    else ctx.resume();
  });

  function bus(level) {
    const g = ctx.createGain();
    g.gain.value = level;
    g.connect(master);
    return g;
  }

  function applySettings() {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    } catch {}
    if (!ctx) return;
    const t = ctx.currentTime;
    master.gain.setTargetAtTime(settings.muted ? 0 : settings.volume, t, 0.05);
    musicBus.gain.setTargetAtTime(settings.music * 0.6, t, 0.2);
  }

  // --- Small building blocks ------------------------------------------------

  const now = () => ctx.currentTime;

  function env(gain, t, attack, peak, decay) {
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(peak, t + attack);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + attack + decay);
  }

  function tone({ type = 'sine', freq, to, t = now(), attack = 0.005, decay = 0.2, peak = 0.3, out = sfx, pan = 0 }) {
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (to) osc.frequency.exponentialRampToValueAtTime(to, t + attack + decay);
    env(g, t, attack, peak, decay);
    let node = osc.connect(g);
    if (pan) {
      const p = ctx.createStereoPanner();
      p.pan.value = pan;
      node = node.connect(p);
    }
    node.connect(out);
    osc.start(t);
    osc.stop(t + attack + decay + 0.05);
  }

  function hiss({ t = now(), attack = 0.003, decay = 0.15, peak = 0.3, filter = 'bandpass', freq = 1200, to, q = 1, out = sfx }) {
    const src = ctx.createBufferSource();
    src.buffer = noise;
    src.playbackRate.value = 0.8 + Math.random() * 0.4;
    const f = ctx.createBiquadFilter();
    f.type = filter;
    f.frequency.setValueAtTime(freq, t);
    if (to) f.frequency.exponentialRampToValueAtTime(to, t + attack + decay);
    f.Q.value = q;
    const g = ctx.createGain();
    env(g, t, attack, peak, decay);
    src.connect(f).connect(g).connect(out);
    src.start(t, Math.random() * 0.5);
    src.stop(t + attack + decay + 0.05);
  }

  // Skip a sound that already played a moment ago (dragging belts fires many).
  function throttle(key, gap) {
    const t = performance.now();
    if (t - (lastTick[key] ?? 0) < gap) return true;
    lastTick[key] = t;
    return false;
  }

  // --- Effects ----------------------------------------------------------------

  const play = {
    build(type) {
      if (!ctx) return;
      if (type === 'belt') {
        if (throttle('belt', 45)) return;
        tone({ type: 'triangle', freq: 520 + Math.random() * 60, to: 380, decay: 0.06, peak: 0.12 });
        hiss({ freq: 3000, decay: 0.04, peak: 0.08 });
        return;
      }
      const t = now();
      // A heavy thud, a metallic clank and a little dust.
      tone({ freq: 140, to: 50, decay: 0.25, peak: 0.55, t });
      hiss({ filter: 'lowpass', freq: 900, to: 200, decay: 0.3, peak: 0.35, t });
      tone({ type: 'square', freq: 880, to: 840, decay: 0.12, peak: 0.05, t: t + 0.03 });
      tone({ type: 'triangle', freq: 1320, to: 1300, decay: 0.25, peak: 0.08, t: t + 0.03 });
      tone({ type: 'sine', freq: 660, decay: 0.08, peak: 0.12, t: t + 0.12 });
      tone({ type: 'sine', freq: 990, decay: 0.12, peak: 0.1, t: t + 0.19 });
      // Power buildings crackle when they join the grid.
      if (type === 'pole' || type === 'power') {
        for (let i = 0; i < 4; i++) hiss({ filter: 'highpass', freq: 4000, decay: 0.03, peak: 0.12, t: t + 0.22 + i * 0.035 + Math.random() * 0.02 });
        tone({ type: 'sawtooth', freq: 100, decay: 0.25, peak: 0.05, t: t + 0.22 });
      }
    },
    remove() {
      if (!ctx || throttle('remove', 60)) return;
      const t = now();
      hiss({ filter: 'bandpass', freq: 2200, to: 300, decay: 0.28, peak: 0.4, q: 0.8, t });
      tone({ type: 'sawtooth', freq: 300, to: 70, decay: 0.22, peak: 0.12, t });
      for (let i = 0; i < 3; i++) tone({ type: 'square', freq: 200 + Math.random() * 300, decay: 0.03, peak: 0.06, t: t + 0.08 + i * 0.05 });
    },
    rotate() {
      if (!ctx || throttle('rotate', 40)) return;
      tone({ type: 'triangle', freq: 700, to: 900, decay: 0.07, peak: 0.12 });
    },
    deny() {
      if (!ctx || throttle('deny', 200)) return;
      const t = now();
      tone({ type: 'square', freq: 150, decay: 0.09, peak: 0.08, t });
      tone({ type: 'square', freq: 118, decay: 0.14, peak: 0.08, t: t + 0.1 });
    },
    click() {
      if (!ctx || throttle('click', 30)) return;
      tone({ type: 'sine', freq: 1500, to: 1100, decay: 0.04, peak: 0.08 });
    },
    // Research or one mission done: a bright rising arpeggio with a bell on top.
    success() {
      if (!ctx) return;
      const t = now();
      [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => {
        tone({ type: 'triangle', freq: f, attack: 0.01, decay: 0.5, peak: 0.18, t: t + i * 0.09 });
        tone({ type: 'sine', freq: f * 2, attack: 0.01, decay: 0.3, peak: 0.05, t: t + i * 0.09 });
      });
      tone({ type: 'sine', freq: 2093, attack: 0.01, decay: 1.2, peak: 0.1, t: t + 0.38 });
    },
    // A whole map done: a short fanfare and a few fireworks pops.
    fanfare() {
      if (!ctx) return;
      const t = now();
      const notes = [[392, 0], [523.25, 0.15], [659.25, 0.3], [783.99, 0.45], [659.25, 0.62], [1046.5, 0.78]];
      for (const [f, d] of notes) {
        tone({ type: 'sawtooth', freq: f, attack: 0.02, decay: d === 0.78 ? 1.4 : 0.3, peak: 0.07, t: t + d });
        tone({ type: 'triangle', freq: f, attack: 0.01, decay: d === 0.78 ? 1.6 : 0.35, peak: 0.16, t: t + d });
      }
      for (let i = 0; i < 5; i++) {
        const d = 1 + i * 0.32 + Math.random() * 0.1;
        hiss({ filter: 'lowpass', freq: 2500, to: 300, decay: 0.5, peak: 0.25, t: t + d });
        tone({ freq: 90, to: 40, decay: 0.3, peak: 0.25, t: t + d });
      }
    },
    // A two-tone horn when a train is put on the track or leaves near the camera.
    horn(pan = 0, level = 1) {
      if (!ctx || level < 0.05 || throttle('horn', 400)) return;
      const t = now();
      for (const [f, d] of [[311, 0], [392, 0]]) {
        tone({ type: 'sawtooth', freq: f, attack: 0.04, decay: 0.55, peak: 0.05 * level, t: t + d, pan });
        tone({ type: 'square', freq: f * 0.5, attack: 0.04, decay: 0.5, peak: 0.025 * level, t: t + d, pan });
      }
    },
    // One second of the launch countdown; the last one is higher and longer.
    beep(last = false) {
      if (!ctx) return;
      const t = now();
      tone({ type: 'sine', freq: last ? 1320 : 880, attack: 0.005, decay: last ? 0.9 : 0.16, peak: 0.16, t });
      tone({ type: 'square', freq: last ? 660 : 440, attack: 0.005, decay: 0.08, peak: 0.03, t });
    },
    // Ignition: a deep thump and a crack before the roar takes over.
    ignition() {
      if (!ctx) return;
      const t = now();
      tone({ freq: 70, to: 28, attack: 0.01, decay: 1.6, peak: 0.9, t });
      hiss({ filter: 'lowpass', freq: 1800, to: 120, attack: 0.01, decay: 1.8, peak: 0.7, t });
      hiss({ filter: 'highpass', freq: 3000, attack: 0.002, decay: 0.25, peak: 0.25, t });
    },
    // The furnace or press finished a part.
    ding(pan = 0, level = 1) {
      if (!ctx || level < 0.05 || throttle('ding', 90)) return;
      tone({ type: 'sine', freq: 1760 + Math.random() * 40, decay: 0.25, peak: 0.04 * level, pan });
    },
  };

  // --- Machine loops ----------------------------------------------------------

  // Renders a looping buffer sample by sample; the last 0.2 s are blended into
  // the start so random noise does not click at the loop point.
  function renderLoop(fn) {
    const rate = ctx.sampleRate;
    const len = Math.floor(LOOP_SECONDS * rate);
    const fade = Math.floor(0.2 * rate);
    const raw = new Float32Array(len + fade);
    const state = {};
    for (let i = 0; i < raw.length; i++) raw[i] = fn(i / rate, state);
    const buffer = ctx.createBuffer(1, len, rate);
    const out = buffer.getChannelData(0);
    for (let i = 0; i < len; i++) {
      const tail = i < fade ? raw[len + i] * (1 - i / fade) : 0;
      out[i] = raw[i] * (i < fade ? i / fade : 1) + tail;
    }
    return buffer;
  }

  const TAU = Math.PI * 2;
  // One-pole filters over white noise: brown-ish rumble and hissy highs.
  const low = (s, key, k) => (s[key] = (s[key] ?? 0) + k * (Math.random() * 2 - 1 - (s[key] ?? 0)));
  const pulse = (t, period, sharp) => Math.exp(-((t % period) / period) * sharp);

  const LOOP_SOUNDS = {
    // Chugging motor with a gritty grinding layer.
    drill: (t, s) => {
      const chug = 0.55 + 0.45 * Math.sin(TAU * 7.5 * t) ** 2;
      const motor = Math.sin(TAU * 75 * t) * 0.35 + Math.sin(TAU * 150 * t + Math.sin(TAU * 7.5 * t)) * 0.18;
      const grind = low(s, 'g', 0.25) * 1.6;
      return (motor + grind) * chug * 0.6;
    },
    // A roaring fire with crackles.
    furnace: (t, s) => {
      const roar = low(s, 'r', 0.04) * 4 + low(s, 'r2', 0.15) * 0.6;
      if (Math.random() < 0.0009) s.crack = 1;
      s.crack = (s.crack ?? 0) * 0.993;
      const crack = s.crack * (Math.random() * 2 - 1) * 0.6;
      return (roar * (0.8 + 0.2 * Math.sin(TAU * 0.83 * t)) + crack) * 0.55;
    },
    // A press stamping three times per loop, with an air hiss after each hit.
    assembler: (t, s) => {
      const p = t % 0.8;
      const thump = Math.sin(TAU * 55 * p) * Math.exp(-p * 18) * 0.9;
      const air = p > 0.1 && p < 0.45 ? low(s, 'a', 0.6) * Math.exp(-(p - 0.1) * 9) * 0.35 : 0;
      return thump + air;
    },
    // A whirring servo with ticking gears.
    constructor: (t, s) => {
      const whir = Math.sin(TAU * 220 * t + Math.sin(TAU * 2.5 * t) * 3) * 0.12 + Math.sin(TAU * 330 * t) * 0.05;
      const tick = pulse(t, 0.125, 40) * low(s, 'k', 0.7) * 0.5;
      return whir * (0.6 + 0.4 * Math.sin(TAU * 1.25 * t)) + tick;
    },
    // The power plant: a turbine hum at mains frequency with a breathing fire under it.
    power: (t, s) => {
      const hum = Math.sin(TAU * 50 * t) * 0.3 + Math.sin(TAU * 100 * t) * 0.16 + Math.sin(TAU * 150 * t) * 0.06;
      const whine = Math.sin(TAU * 410 * t + Math.sin(TAU * 0.5 * t) * 2) * 0.03;
      const fire = low(s, 'p', 0.05) * 2.5;
      return (hum + whine) * (0.85 + 0.15 * Math.sin(TAU * 0.42 * t)) + fire * 0.4;
    },
    // The pumpjack: a slow creak up and a heavy thud down, with a motor under it.
    pump: (t, s) => {
      const p = t % 1.2;
      const thud = Math.sin(TAU * 45 * p) * Math.exp(-p * 9) * 0.6;
      const creak = p > 0.5 && p < 0.8 ? Math.sin(TAU * (300 + (p - 0.5) * 400) * t) * 0.05 : 0;
      return thud + creak + Math.sin(TAU * 60 * t) * 0.08 + low(s, 'm', 0.3) * 0.2;
    },
    // Bubbling columns and the hiss of the flare.
    refinery: (t, s) => {
      if (Math.random() < 0.004) s.bub = 1;
      s.bub = (s.bub ?? 0) * 0.995;
      const bubble = Math.sin(TAU * (180 + s.bub * 220) * t) * s.bub * 0.25;
      return low(s, 'f', 0.08) * 2.2 + bubble + Math.sin(TAU * 90 * t) * 0.06;
    },
    // Wheels over rail joints: two quick knocks, a pause, two more.
    train: (t, s) => {
      const p = t % 0.6;
      const knock = (p < 0.08 ? Math.exp(-p * 60) : 0) + (p > 0.12 && p < 0.2 ? Math.exp(-(p - 0.12) * 60) : 0);
      return low(s, 'r', 0.15) * 0.9 + knock * Math.sin(TAU * 140 * t) * 0.7 + Math.sin(TAU * 55 * t) * 0.05;
    },
    // A soft rattle of rollers.
    belt: (t, s) => {
      const roll = low(s, 'b', 0.5) * (0.4 + 0.6 * pulse(t, 0.1, 12));
      return roll * 0.35 + Math.sin(TAU * 100 * t) * 0.03;
    },
  };

  function startLoop(type) {
    const src = ctx.createBufferSource();
    src.buffer = renderLoop(LOOP_SOUNDS[type]);
    src.loop = true;
    src.playbackRate.value = 0.96 + Math.random() * 0.08;
    const gain = ctx.createGain();
    gain.gain.value = 0;
    const pan = ctx.createStereoPanner();
    src.connect(gain).connect(pan).connect(machineBus);
    src.start(ctx.currentTime + Math.random() * 0.3);
    loops[type] = { gain, pan };
  }

  // Machines are heard by how close they are to the spot the camera looks at.
  // One loop per machine type is mixed from all working machines, so a big
  // factory costs no more than a small one.
  const LEVEL = { drill: 0.5, furnace: 0.75, assembler: 0.7, constructor: 0.6, belt: 0.25, power: 0.6, pump: 0.55, refinery: 0.55, train: 0.7 };
  function updateMachines(factory, focus, right, zoom) {
    if (!ctx || ctx.state !== 'running') return;
    const radius = 3 + zoom * 0.18;
    const near = Math.min(1, 26 / zoom);
    const sum = Object.create(null); // no prototype: "constructor" is a machine type here
    const panSum = Object.create(null);
    for (const b of factory.buildings.values()) {
      const type = b.type === 'belt' ? (b.items.length ? 'belt' : null) : b.state === 'work' ? b.type : null;
      if (!LOOP_SOUNDS[type]) continue;
      const dx = b.tile.position.x - focus.x;
      const dz = b.tile.position.z - focus.z;
      const d2 = (dx * dx + dz * dz) / (radius * radius);
      if (d2 > 30) continue;
      const w = 1 / (1 + d2);
      sum[type] = (sum[type] ?? 0) + w;
      panSum[type] = (panSum[type] ?? 0) + w * Math.max(-1, Math.min(1, (dx * right.x + dz * right.z) / (radius * 2)));
    }
    // Running trains rattle where their head is.
    for (const tr of factory.trains ?? []) {
      if (tr.state !== 'run' || tr.speed < 0.3) continue;
      const pos = factory.world.tiles[tr.path[Math.round(tr.s)]].position;
      const dx = pos.x - focus.x;
      const dz = pos.z - focus.z;
      const d2 = (dx * dx + dz * dz) / (radius * radius);
      if (d2 > 30) continue;
      const w = Math.min(1, tr.speed / 3) / (1 + d2);
      sum.train = (sum.train ?? 0) + w;
      panSum.train = (panSum.train ?? 0) + w * Math.max(-1, Math.min(1, (dx * right.x + dz * right.z) / (radius * 2)));
    }
    const t = ctx.currentTime;
    for (const type of MACHINE_TYPES) {
      const s = sum[type] ?? 0;
      // Many machines get louder, but slower than they add up.
      const level = Math.min(1.4, Math.sqrt(s)) * LEVEL[type] * near;
      loops[type].gain.gain.setTargetAtTime(level, t, 0.25);
      loops[type].pan.pan.setTargetAtTime(s ? (panSum[type] / s) * 0.7 : 0, t, 0.25);
    }
  }

  // Distance weight and stereo position of one spot, for one-shot machine sounds.
  function spot(pos, focus, right, zoom) {
    const radius = 3 + zoom * 0.18;
    const dx = pos.x - focus.x;
    const dz = pos.z - focus.z;
    const level = Math.min(1, 26 / zoom) / (1 + (dx * dx + dz * dz) / (radius * radius));
    return { level, pan: Math.max(-1, Math.min(1, (dx * right.x + dz * right.z) / (radius * 2))) * 0.7 };
  }

  // --- Background music -------------------------------------------------------

  // Slow pad chords with a few pentatonic plucks on top. At night the filter
  // closes and the plucks get sparser.
  function createMusic() {
    const out = ctx.createBiquadFilter();
    out.type = 'lowpass';
    out.frequency.value = 1800;
    const delay = ctx.createDelay(1);
    delay.delayTime.value = 0.42;
    const feedback = ctx.createGain();
    feedback.gain.value = 0.32;
    out.connect(musicBus);
    out.connect(delay).connect(feedback).connect(delay);
    delay.connect(musicBus);

    // Am – F – C – G, voiced low and soft.
    const chords = [
      [220, 261.63, 329.63, 110],
      [174.61, 220, 261.63, 87.31],
      [196, 261.63, 329.63, 130.81],
      [196, 246.94, 293.66, 98],
    ];
    const scale = [440, 493.88, 523.25, 587.33, 659.25, 783.99, 880];
    const BAR = 6;
    let next = ctx.currentTime + 0.5;
    let bar = 0;

    function padVoice(freq, t, gain) {
      for (const detune of [-6, 6]) {
        const osc = ctx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.value = freq;
        osc.detune.value = detune;
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.linearRampToValueAtTime(gain, t + 2.2);
        g.gain.setValueAtTime(gain, t + BAR - 1.5);
        g.gain.linearRampToValueAtTime(0.0001, t + BAR + 1.2);
        osc.connect(g).connect(out);
        osc.start(t);
        osc.stop(t + BAR + 1.3);
      }
    }

    function pluck(freq, t, gain) {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq;
      const g = ctx.createGain();
      env(g, t, 0.01, gain, 1.4);
      osc.connect(g).connect(out);
      osc.start(t);
      osc.stop(t + 1.5);
    }

    function schedule() {
      if (ctx.state !== 'running') return;
      while (next < ctx.currentTime + 1.5) {
        const chord = chords[bar % chords.length];
        chord.forEach((f, i) => padVoice(f, next, i === 3 ? 0.05 : 0.028));
        const plucks = night > 0.5 ? 2 : 4;
        for (let i = 0; i < plucks; i++) {
          if (Math.random() < 0.35) continue;
          const f = scale[Math.floor(Math.random() * scale.length)];
          pluck(f, next + 0.75 + i * (BAR / plucks) + Math.random() * 0.2, 0.035);
        }
        next += BAR;
        bar++;
      }
      out.frequency.setTargetAtTime(1900 - night * 1100, ctx.currentTime, 2);
    }
    const timer = setInterval(schedule, 500);
    schedule();
    return { stop: () => clearInterval(timer) };
  }

  // The roar of a rocket engine: low rumble, a rushing mid band and crackle. The
  // returned handle sets its level (0..1) and lets it die away.
  function rocket() {
    if (!ctx) return { set() {}, stop() {} };
    const t = now();
    const out = ctx.createGain();
    out.gain.value = 0.0001;
    out.connect(sfx);
    const layer = (type, freq, q, gain) => {
      const src = ctx.createBufferSource();
      src.buffer = noise;
      src.loop = true;
      src.playbackRate.value = 0.7 + Math.random() * 0.2;
      const f = ctx.createBiquadFilter();
      f.type = type;
      f.frequency.value = freq;
      f.Q.value = q;
      const g = ctx.createGain();
      g.gain.value = gain;
      src.connect(f).connect(g).connect(out);
      src.start(t);
      return { src, f };
    };
    const rumble = layer('lowpass', 140, 0.7, 1.4);
    const rush = layer('bandpass', 700, 0.6, 0.5);
    const crackle = layer('highpass', 2500, 0.5, 0.12);
    const sub = ctx.createOscillator();
    sub.type = 'sine';
    sub.frequency.value = 38;
    const subGain = ctx.createGain();
    subGain.gain.value = 0.6;
    sub.connect(subGain).connect(out);
    sub.start(t);
    const sources = [rumble.src, rush.src, crackle.src, sub];
    return {
      // `far` 0..1 muffles the sound as the rocket climbs away.
      set(level, far = 0) {
        const n = now();
        out.gain.setTargetAtTime(Math.max(0.0001, level * 0.8), n, 0.15);
        rush.f.frequency.setTargetAtTime(700 - far * 450, n, 0.3);
        crackle.f.frequency.setTargetAtTime(2500 + far * 4000, n, 0.3);
      },
      stop(fade = 2) {
        const n = now();
        out.gain.cancelScheduledValues(n);
        out.gain.setTargetAtTime(0.0001, n, fade / 4);
        for (const s of sources) s.stop(n + fade + 0.5);
      },
    };
  }

  return {
    play,
    rocket,
    // Music and machines go quiet while the rocket starts.
    duck(on) {
      if (!ctx) return;
      musicBus.gain.setTargetAtTime(on ? 0.0001 : settings.music * 0.6, now(), 0.6);
      machineBus.gain.setTargetAtTime(on ? 0.15 : 0.55, now(), 0.6);
    },
    updateMachines,
    spot,
    settings,
    setNight(n) {
      night = n;
    },
    set(changes) {
      Object.assign(settings, changes);
      applySettings();
    },
  };
}
