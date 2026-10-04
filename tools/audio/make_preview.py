#!/usr/bin/env python3
"""Mixes a ~85 s listening sample from the generated files (run build_audio.py first):

    python tools/audio/make_preview.py [out.ogg]

Friedhof am Tag (Wind, Vögel, Schritte im Gras) → Graben und Erde schütten → Weg ins Dorf
(Anger: Stimmen, Hühner, Schmied, Bach, Glocke, Schritte auf Pflaster) → Gaststube (Tür,
Holzboden, Becher, Münzen) → Friedhof in der Nacht (Grillen, Eule, Geist) → Musik-Ausschnitt.
Levels follow the cue catalogue (volume_db) and the default bus volumes, so the balance is
close to the game. Default output: docs/reviews/phase7_round2/audio_preview.ogg
"""
from __future__ import annotations

import os
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_audio as ba  # noqa: E402

SR = 32000
BUS = {"Music": 0.55, "Ambience": 0.8, "SFX": 0.9, "UI": 0.7}
SPECS = {sp.id: sp for sp in ba.CATALOG}
rng = np.random.default_rng(7)


def load(name: str) -> np.ndarray:
    sp = SPECS[name.rsplit("#", 1)[0]]
    i = int(name.rsplit("#", 1)[1]) if "#" in name else int(rng.integers(0, sp.variants))
    path = os.path.join(ba.ASSET_DIR, sp.folder, ba.file_name(sp, i))
    x, sr = sf.read(path, always_2d=True)
    if sr != SR:
        n = int(round(x.shape[0] * SR / sr))
        t_old = np.arange(x.shape[0]) / sr
        t_new = np.arange(n) / SR
        x = np.stack([np.interp(t_new, t_old, x[:, c]) for c in range(x.shape[1])], axis=1)
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    gain = 10 ** (sp.volume_db / 20.0) * BUS.get(sp.bus, 1.0)
    return x * gain


class Mix:
    def __init__(self, seconds: float):
        self.buf = np.zeros((int(seconds * SR), 2))

    def add(self, name: str, t: float, db: float = 0.0, pan: float = 0.0, x: np.ndarray | None = None):
        x = load(name) if x is None else x
        a = (pan + 1.0) * np.pi / 4.0
        x = x * np.array([np.cos(a), np.sin(a)]) * np.sqrt(2) * 10 ** (db / 20.0)
        i = int(t * SR)
        end = min(self.buf.shape[0], i + x.shape[0])
        if end > i:
            self.buf[i:end] += x[: end - i]

    def bed(self, name: str, t0: float, t1: float, fade: float = 1.5, db: float = 0.0, offset: float = 0.0):
        x = load(name)
        n = int((t1 - t0) * SR)
        start = int(offset * SR) % x.shape[0]
        reps = int(np.ceil((n + start) / x.shape[0])) + 1
        tiled = np.tile(x, (reps, 1))[start:start + n]
        k = int(fade * SR)
        env = np.ones(n)
        env[:k] = np.linspace(0, 1, k)
        env[-k:] = np.minimum(env[-k:], np.linspace(1, 0, k))
        self.add(name, t0, db, 0.0, tiled * env[:, None])


def steps(m: Mix, cue: str, t0: float, t1: float, every: float = 0.42, db: float = 0.0):
    t = t0
    while t < t1:
        m.add(cue, t + rng.uniform(-0.02, 0.02), db + rng.uniform(-1.5, 1.0), rng.uniform(-0.1, 0.1))
        t += every


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ba.ROOT, "docs", "reviews", "phase7_round2", "audio_preview.ogg")
    m = Mix(88.0)
    # A · Friedhof am Tag (0–14)
    m.bed("amb_graveyard_day", 0.0, 29.0, 1.5)
    for t, c, p in ((1.5, "bird_a", -0.5), (5.0, "bird_b", 0.6), (9.0, "crow", -0.2), (11.0, "bird_c", 0.4),
                    (17.5, "bird_a", 0.5), (24.0, "bird_b", -0.6)):
        m.add(c, t, 0.0, p)
    steps(m, "step_grass", 2.5, 8.5)
    m.add("pickup", 9.2)
    # B · Graben (12–27)
    for k in range(8):
        m.add("dig", 12.0 + k * 0.95, 0.0, 0.05)
    m.add("corpse_down", 20.2, 0.0)
    m.add("cloth", 20.6, -2.0)
    for k in range(2):
        m.add("dirt_pour", 21.8 + k * 1.5, 0.0)
    m.add("stone_set", 25.0)
    # → Dorf (27–42)
    m.add("door_open", 26.4, -4.0, -0.3)
    m.add("travel", 27.2)
    m.bed("amb_village_day", 28.0, 42.5, 1.5)
    m.bed("loop_brook", 28.0, 41.0, 1.5, -12.0)
    for t in (30.0, 35.5):
        m.add("chicken", t, -2.0, 0.6)
    for t in (29.0, 33.0, 38.0):
        m.add("anvil", t, -10.0, -0.7)
    steps(m, "step_stone", 29.0, 33.5)
    m.add("church_bell", 34.0, -6.0, 0.1)
    m.add("church_bell", 36.6, -6.5, 0.1)
    m.add("remark", 39.5, 0.0, 0.3)
    # Gaststube (41–54)
    m.add("door_open", 40.8, 0.0, 0.2)
    m.add("door_close", 42.0, 0.0, 0.2)
    m.bed("amb_inn", 41.5, 54.0, 1.0)
    steps(m, "step_wood", 42.4, 45.5, 0.45)
    for t in (44.0, 47.5, 51.0):
        m.add("cup_clink", t, 0.0, rng.uniform(-0.6, 0.6))
    m.add("ui_open", 46.0)
    m.add("coins", 48.0)
    m.add("ui_close", 49.8)
    m.add("fire_pop", 50.4, 0.0, -0.5)
    # Nacht auf dem Friedhof (53–70)
    m.add("travel", 53.0)
    m.bed("amb_graveyard_night", 53.8, 73.0, 3.0)
    m.add("owl", 55.5, 0.0, -0.4)
    m.add("ghost_appear", 59.0, 2.0, 0.2)
    m.add("owl_short", 62.5, 0.0, 0.5)
    m.add("ghost_content", 64.5, 2.0, 0.1)
    # Musik (68–88)
    music = load("mus_night")
    seg = music[int(2.0 * SR): int(22.0 * SR)]
    n = seg.shape[0]
    env = np.ones(n)
    env[: 2 * SR] = np.linspace(0, 1, 2 * SR)
    env[-4 * SR:] = np.linspace(1, 0, 4 * SR) ** 2
    m.add("mus_night", 67.5, 4.0, 0.0, seg * env[:, None])
    x = m.buf
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    os.makedirs(os.path.dirname(out), exist_ok=True)
    ba.write_ogg(out, x.astype(np.float32), SR, 0.55)
    print(out, f"{x.shape[0] / SR:.1f} s", f"{os.path.getsize(out) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
