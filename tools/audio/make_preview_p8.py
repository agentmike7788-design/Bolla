#!/usr/bin/env python3
"""Phase 8 listening sample (≈ 100 s) from the generated files (run build_audio.py first):

    python tools/audio/make_preview_p8.py [out.ogg]

Besuch am Grab (Schritte auf dem Kiesweg, Knien, ein Atemzug, Heidekraut abgelegt, Aufstehen, Münzen auf dem
Stein) → Jakob harkt und gießt (Kreidetafel, Rechen im Takt, Hanne mit der Kiepe zieht vorbei, Regenfass,
Gießkanne, Pfeifen) → Kathreintanz in der Gaststube (Fiedel im Dreiertakt, Stimmengewirr, Stampfen) →
Lichtgang (gestrichene Töne, Schritte des Zugs, Grabkerze, Handglocke 17:40) → Nacht mit dem Grabräuber
(gedämpfter Spaten, der Totengräber kommt näher, Flucht über den Kies, über die Mauer, das Horn des
Nachtwächters fern) → Kapitel „Wer heraufkommt". Levels as make_preview.py (measured volume_db, default bus
volumes); distance as a few dB less. Default output: docs/reviews/phase8_round1/audio_preview_p8.ogg
"""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_audio as ba  # noqa: E402
import make_preview as mp  # noqa: E402

SR = mp.SR
rng = np.random.default_rng(8)


def music(m: mp.Mix, cue: str, t: float, start: float, length: float, db: float = 0.0, fin: float = 2.0, fout: float = 3.0):
    x = mp.load(cue)
    seg = x[int(start * SR): int((start + length) * SR)]
    n = seg.shape[0]
    env = np.ones(n)
    env[: int(fin * SR)] = np.linspace(0, 1, int(fin * SR))
    env[-int(fout * SR):] = np.linspace(1, 0, int(fout * SR)) ** 2
    m.add(cue, t, db, 0.0, seg * env[:, None])


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ba.ROOT, "docs", "reviews", "phase8_round1", "audio_preview_p8.ogg")
    m = mp.Mix(104.0)
    # A · Besuch am Grab (0–21): Martha Kehr kommt den Kiesweg herauf, kniet, legt Heidekraut ab, geht wieder.
    m.bed("amb_graveyard_day", 0.0, 22.0, 1.5)
    for t, c, p in ((1.0, "bird_a", -0.5), (6.0, "bird_b", 0.6), (12.5, "crow", -0.3), (18.0, "bird_c", 0.4)):
        m.add(c, t, 0.0, p)
    mp.steps(m, "step_stone", 1.5, 7.0, 0.5, -7.0)                 # her steps (an Npc: −5 dB, a little away)
    m.add("cloth_kneel", 7.6, 0.0, 0.15)
    m.add("mourn_breath", 10.4, 0.0, 0.15)
    m.add("flowers_lay", 13.0, 0.0, 0.1)
    m.add("cloth_kneel", 16.2, 0.0, 0.15)
    mp.steps(m, "step_stone", 17.2, 21.0, 0.5, -9.0)
    m.add("coins_stone", 20.4, -2.0, 0.0)                            # the gravekeeper takes the tip from the stone
    # B · Jakob harkt und gießt (21–39)
    m.add("chalk_write", 21.6, 0.0)
    m.bed("amb_graveyard_day", 21.0, 39.5, 1.0, 0.0, 9.0)
    for k in range(6):
        m.add("rake_leaves", 23.0 + k * 1.33, -3.0, -0.35)
    m.bed("kiepe_bells", 25.0, 30.5, 1.5, -6.0)                      # Hanne passes at the gate
    m.add("kiepe_set", 30.6, -6.0, 0.6)
    mp.steps(m, "step_grass", 31.0, 32.6, 0.45, -6.0)
    m.add("barrel_fill", 32.8, -2.0, -0.2)
    for k in range(3):
        m.add("water_pour", 35.0 + k * 1.33, -3.0, -0.25)
    m.add("whistle_tune#1", 37.6, -4.0, -0.3)
    # C · Kathreintanz in der Gaststube (40–59)
    m.add("travel", 39.6)
    m.add("door_open", 40.6, -2.0, 0.2)
    m.add("door_close", 41.6, -2.0, 0.2)
    m.bed("amb_inn_fest", 41.0, 59.0, 1.2)
    music(m, "mus_dance", 42.0, 3.0, 17.0, 0.0, 1.5, 3.0)
    m.add("cup_clink", 47.0, 0.0, 0.5)
    m.add("cup_clink", 53.2, 0.0, -0.4)
    # D · Lichtgang (59–77)
    m.add("travel", 59.0)
    m.bed("amb_graveyard_dusk", 59.5, 77.5, 2.0)
    music(m, "mus_lights", 60.0, 7.0, 17.0, 0.0, 2.5, 3.5)
    mp.steps(m, "step_stone", 60.5, 64.0, 0.55, -10.0)              # the procession on the gravel
    mp.steps(m, "step_grass", 61.0, 64.5, 0.6, -12.0)
    m.add("match_strike#0", 64.6, -1.0, 0.0)
    m.add("candle_glass#0", 65.8, -1.0, 0.0)
    for k in range(3):
        m.add("small_bell", 68.0 + k * 2.4, -6.0, 0.3)               # Lenz's hand bell, 17:40
    # E · Nacht mit dem Grabräuber (77–97)
    m.add("travel", 77.0)
    m.bed("amb_graveyard_night", 77.5, 98.0, 2.5)
    m.add("owl", 78.5, 0.0, 0.5)
    for k in range(7):
        m.add("spade_night", 80.0 + k * 1.3, -7.0 + k * 0.6, -0.5)
    mp.steps(m, "step_grass", 85.0, 89.0, 0.48, 0.0)                 # the gravekeeper comes closer
    m.add("cloth", 89.3, -2.0, -0.4)                                 # he startles
    t = 89.6
    for k in range(9):
        m.add("run_gravel", t, -2.0 - k * 1.2, -0.4 - k * 0.04)
        t += 0.3
    m.add("climb_wall", 92.4, -8.0, -0.75)
    m.add("owl_short", 94.6, 0.0, 0.4)
    m.add("watchman_call", 95.0, -4.0, 0.2)                          # far below in the village
    # Kapitel „Wer heraufkommt"
    m.add("chapter_who", 97.0, 0.0)
    x = m.buf
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    os.makedirs(os.path.dirname(out), exist_ok=True)
    ba.write_ogg(out, x.astype(np.float32), SR, 0.55)
    print(out, f"{x.shape[0] / SR:.1f} s", f"{os.path.getsize(out) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
