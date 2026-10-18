#!/usr/bin/env python3
"""Phase 9 listening sample (≈ 66 s) from the generated files (run build_audio.py first):

    python tools/audio/make_preview_p9.py [out.ogg]

Hütte am Abend (Lorenz' Kladde am Pult: Seiten, das Motiv; ein Brief ohne Namen mit der Feder; ein Taschenbrief
entfaltet, ein gesiegelter aufgebrochen; ein Brief im Ofen verbrannt) → Am Grab in der Dämmerung (Schritte, Knien,
der Brief vorgelesen, eine Handvoll Erde ins Tuch) → Am Tor am Nachmittag (Brenneisen zieht einmal kurz an der
Torglocke, stellt den Koffer ab, lüftet den Hut; der große Bogen wird an die Torafel geheftet) → Dorf in der Nacht
(an Siebers Tür klopfen; später der Nachtwächter mit Laterne und Handglocke, der Brief steckt in der Tür) →
Kapitel „Wer weiß, wann?". Levels as make_preview.py (measured volume_db, default bus volumes); distance as a few dB
less. Default output: docs/reviews/phase9_round1/ton/audio_preview_p9.ogg
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


def loop_for(m: mp.Mix, cue: str, t0: float, t1: float, db: float = 0.0, fade: float = 0.25):
    """A looping work cue (the quill) for as long as the action runs – as AudioEvents' WorkLoop plays it."""
    m.bed(cue, t0, t1, fade, db)


def main() -> int:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ba.ROOT, "docs", "reviews", "phase9_round1", "ton",
                                                             "audio_preview_p9.ogg")
    m = mp.Mix(67.0)
    # A · Hütte am Abend (0–19)
    m.bed("amb_hut", 0.0, 19.5, 1.2)
    mp.steps(m, "step_wood", 0.6, 2.4, 0.45)
    for t in (3.0, 6.6, 10.2):                                       # „Lorenz' Kladde lesen" (book_page alle 4,5 s)
        m.add("book_page", t, 0.0, -0.1)
    m.add("motif_when", 4.2, 0.0)                                    # the chain opens (quest_changed … opened)
    loop_for(m, "quill_scratch", 11.0, 15.0)                         # „Brief ohne Namen schreiben"
    m.add("letter_unfold", 15.6, 0.0, 0.1)                           # a pocket letter read
    m.add("letter_seal_break", 17.0, 0.0, 0.1)                       # a sealed one opened
    m.add("fire_pop", 18.4, -2.0, 0.5)
    # B · Am Ofen und am Grab (19–33)
    m.add("paper_burn", 19.0, 0.0, 0.4)                              # „Brief verbrennen" (Ofen)
    m.add("door_open", 22.4, -2.0, -0.3)
    m.bed("amb_graveyard_dusk", 23.0, 34.0, 1.5)
    mp.steps(m, "step_stone", 23.4, 26.6, 0.5)
    m.add("cloth_kneel", 27.0, 6.0, 0.0)                             # he kneels (the visitors' cue, close)
    m.add("letter_unfold", 27.8, -1.0, 0.0)                          # „Brief vorlesen" at the grave
    m.add("soil_handful", 31.4, 0.0, 0.0)                            # „Erde nehmen"
    # C · Am Tor, Nachmittag (34–47)
    m.add("travel", 33.6)
    m.bed("amb_graveyard_day", 34.0, 47.0, 1.5)
    m.add("bird_b", 35.0, 0.0, 0.5)
    m.add("gate_bell_short", 35.6, -3.0, 0.4)                        # he pulls the gate bell once (14:10)
    mp.steps(m, "step_stone", 38.0, 40.6, 0.55, -7.0)                # his steps by the gate
    m.add("case_latch#1", 40.9, -6.0, 0.4)                           # wait_gate: the case set down
    m.add("cloth", 42.2, -8.0, 0.4)                                  # tip_hat
    m.add("notice_sheet", 44.4, -2.0, -0.3)                          # the large sheet at the gate board
    # D · Dorf in der Nacht (47–58)
    m.add("travel", 46.8)
    m.bed("amb_village_night", 47.4, 59.5, 2.0)
    mp.steps(m, "step_stone", 47.8, 50.2, 0.45)
    m.add("knock_door", 50.6, 0.0, 0.1)                              # „Bei den Siebers anklopfen"
    for t in (53.2, 55.6, 58.0):
        m.add("lantern_creak", t, -2.0, -0.4)                        # the watchman's lantern (ending C)
    m.add("watchman_bell", 54.0, -3.0, -0.4)
    m.add("letter_unfold", 56.8, -3.0, 0.2)                          # the letter slipped into the door (ending A)
    # Kapitel „Wer weiß, wann?"
    m.add("chapter_when", 58.8, 0.0)
    x = m.buf
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    os.makedirs(os.path.dirname(out), exist_ok=True)
    ba.write_ogg(out, x.astype(np.float32), SR, 0.85)
    print(out, f"{x.shape[0] / SR:.1f} s", f"{os.path.getsize(out) / 1024:.0f} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
