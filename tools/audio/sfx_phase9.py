"""Phase 9 „Wer weiß, wann?" (docs/PHASE9_DESIGN.md §8.3; W-Ton): letters, the ledger, the gentleman with the
case, the soil, the sheet at the board, the night watchman at the Siebers' door and a sparing motif for the main
chain. Each function: (rng, sr) -> mono float array. Everything synthesised from noise, sines and filters (synth.py)
– no samples, no recordings, no known melodies.

Tone: paper is dry and close, never crisp like a crisp packet (energy kept under 5 kHz); the burning letter is a
small fire, not a blaze; the watchman rings a hand bell (no song, no words); the motif is four bowed notes that ask
and do not answer – heard three times in the chain and once, answered, at the chapter.
"""
from __future__ import annotations

import numpy as np

import sfx
import sfx_phase8 as p8
import synth as s


# --- paper -------------------------------------------------------------------------------------

def _crackle(rng, sr, dur, rate, lo=700.0, hi=5200.0, decay=0.0025, env=None):
    """Stiff old paper breaking along a fold: sparse sharp impulses (each a tiny decaying noise tick) whose
    loudness varies a lot, band-limited so that it stays papery rather than glassy."""
    n = s.secs(sr, dur)
    out = np.zeros(n)
    count = max(1, int(rate * dur))
    for _ in range(count):
        p = rng.uniform(0.0, 1.0)
        if env is not None and rng.uniform() > env(p):
            continue
        gl = s.secs(sr, decay * rng.uniform(2.0, 5.0))
        g = rng.standard_normal(gl) * s.env_ad(sr, gl, 0.0002, decay * rng.uniform(0.5, 1.4))
        s.mix_at(out, g, int(p * n), rng.uniform(0.15, 1.0) ** 1.6)
    return s.bandpass(out, sr, lo, hi)


def _swish(rng, sr, dur, lo=300.0, hi=2200.0, shape=1.2):
    """The sheet moving through the air: soft band noise under a rounded envelope."""
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** shape
    return s.bandpass(rng.standard_normal(n), sr, lo, hi) * env


def _tame(x, drive=2.5):
    """Soft-limits the loudest crackles so that one sharp tick does not set the whole sound's level."""
    y = s.normalize(x, 1.0)
    return np.tanh(drive * y) / np.tanh(drive)


def _unfold(rng, sr, dur=0.9, folds=2):
    """A folded letter opened: each fold gives with a short crackle, the sheet swings open, settles flat."""
    n = s.secs(sr, dur)
    out = np.zeros(n)
    t0 = 0.02
    for k in range(folds):
        ln = rng.uniform(0.08, 0.14)
        burst = _crackle(rng, sr, ln, rng.uniform(160, 280), env=lambda p: float(np.sin(np.pi * p) ** 0.6))
        s.mix_at(out, burst, s.secs(sr, t0), 1.0 if k == 0 else rng.uniform(0.7, 0.9))
        sw = _swish(rng, sr, rng.uniform(0.18, 0.26), 280, 1700, 1.8)
        s.mix_at(out, sw, s.secs(sr, t0 + ln * 0.6), 0.18)
        t0 += ln + rng.uniform(0.16, 0.24)
        if t0 > dur - 0.25:
            break
    # laid flat: a low, soft pressure of the palm on the sheet and the last little crackles
    flat = _swish(rng, sr, 0.22, 150, 900, 2.0)
    s.mix_at(out, flat, s.secs(sr, min(t0, dur - 0.24)), 0.25)
    s.mix_at(out, _crackle(rng, sr, 0.2, 40, env=lambda p: float(np.exp(-p * 4))), s.secs(sr, min(t0, dur - 0.22)), 0.3)
    return s.lowpass(out, sr, 4800, 4)


def letter_unfold(rng, sr):
    """A letter taken out and unfolded – two folds opening, the sheet laid flat (≈ 0.9 s)."""
    x = _unfold(rng, sr, rng.uniform(0.9, 1.0), 3)
    return s.fade(s.normalize(_tame(x, 2.0), 0.6), sr, 0.002, 0.08)


def letter_seal_break(rng, sr):
    """A wax seal broken: the paper pulled taut, the brittle snap of the wax (a few clicks within 20 ms and a small
    dull body), crumbs of wax falling onto the table, then the letter opened (≈ 1.3 s)."""
    dur = 1.3
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, _swish(rng, sr, 0.16, 500, 2400, 2.0) * 0.5, 0, 0.5)              # the thumb under the flap
    at = s.secs(sr, rng.uniform(0.13, 0.17))
    for k in range(int(rng.integers(3, 5))):
        gl = s.secs(sr, 0.012)
        click = s.bandpass(rng.standard_normal(gl), sr, 1200, 4800) * s.env_ad(sr, gl, 0.0001, rng.uniform(0.0015, 0.003))
        s.mix_at(out, click, at + s.secs(sr, rng.uniform(0.0, 0.018)), rng.uniform(0.5, 1.0))
    body = s.partials(sr, s.secs(sr, 0.06), rng.uniform(520, 640), [1, 1.7, 2.6], [0.6, 0.3, 0.15], [0.012, 0.008, 0.005], rng)
    s.mix_at(out, body, at, 0.5)
    for _ in range(int(rng.integers(3, 7))):                                          # crumbs on the wood
        crumb = sfx.wood(rng, sr, rng.uniform(1400, 2600), 0.004, 0.4, 0.03)
        s.mix_at(out, crumb, at + s.secs(sr, rng.uniform(0.06, 0.26)), rng.uniform(0.08, 0.2))
    s.mix_at(out, _unfold(rng, sr, 0.85, 2), s.secs(sr, 0.38), 0.85)
    return s.fade(s.normalize(s.lowpass(out, sr, 5600), 0.65), sr, 0.002, 0.08)


def book_page(rng, sr):
    """A page of the old ledger turned: lifted at the corner, swung over, laid down with a soft flap (≈ 0.75 s)."""
    dur = 0.75
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, _crackle(rng, sr, 0.08, 220, 800, 4200), s.secs(sr, 0.02), 0.5)
    sw = _swish(rng, sr, rng.uniform(0.26, 0.34), 350, 2600, 1.6)
    s.mix_at(out, sw, s.secs(sr, 0.08), 0.55)
    land = s.lowpass(rng.standard_normal(s.secs(sr, 0.12)), sr, 700) * s.env_ad(sr, s.secs(sr, 0.12), 0.004, 0.025)
    s.mix_at(out, land, s.secs(sr, 0.42), 0.6)
    s.mix_at(out, _crackle(rng, sr, 0.1, 120, 900, 4000, env=lambda p: float(np.exp(-p * 5))), s.secs(sr, 0.43), 0.3)
    return s.fade(s.normalize(s.lowpass(out, sr, 4800), 0.5), sr, 0.002, 0.08)


def quill_scratch(rng, sr):
    """Loop (≈ 4 s, seamless): a quill writing a letter at the desk – strokes of different length with the nib's
    grain, short lifts between words, the odd pause to think. Built circularly (wrapped strokes, FFT filter)."""
    dur = 4.0
    n = s.secs(sr, dur)
    out = np.zeros(n)
    t = rng.uniform(0.0, 0.2)
    while t < dur - 0.05:
        word = rng.uniform(0.35, 0.8)                 # a word: a few strokes close together
        tw = t
        while tw < t + word:
            ln = rng.uniform(0.04, 0.16)
            sn = s.secs(sr, ln)
            stroke = rng.standard_normal(sn) * np.sin(np.pi * np.linspace(0, 1, sn)) ** 0.7
            stroke *= p8._jitter(rng, sr, sn, 90.0)
            s.mix_at(out, stroke, s.secs(sr, tw), rng.uniform(0.45, 1.0), wrap=True)
            tw += ln + rng.uniform(0.01, 0.05)
        t = tw + (rng.uniform(0.5, 0.8) if rng.uniform() < 0.2 else rng.uniform(0.12, 0.26))
    x = s.loop_filter_band(out, sr, 1800.0, 6500.0, 2.0)
    # the paper and the desk under the nib: a little low body circularly mixed in
    body = s.loop_filter_band(np.abs(out), sr, 120.0, 900.0, 1.5)
    x = x + body * 0.25
    return s.normalize(x - np.mean(x), 0.45)


def paper_burn(rng, sr):
    """A letter put into the stove: the flame takes it with a soft breath, a low flutter of the small fire, the
    paper crackles and curls – busiest in the first second –, then only a few last crackles (≈ 3.2 s)."""
    dur = rng.uniform(3.0, 3.4)
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    out = np.zeros(n)
    catch = s.lowpass(rng.standard_normal(n), sr, 480, 4) * s.env_ad(sr, n, 0.1, 0.35)
    out += catch * 0.8
    flame_env = np.clip(t / 0.3, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.5, 0) / 0.8)
    flutter = s.bandpass(rng.standard_normal(n), sr, 70, 420) * flame_env * p8._jitter(rng, sr, n, 7.0)
    out += flutter * 0.6
    hiss = s.bandpass(rng.standard_normal(n), sr, 500, 2400) * flame_env * p8._jitter(rng, sr, n, 9.0)
    out += hiss * 0.12
    dens = p8._env_curve([(0.0, 0.0), (0.06, 0.7), (0.25, 1.0), (0.55, 0.35), (1.0, 0.04)])
    crack = _crackle(rng, sr, dur, 75, 900, 5200, 0.002, dens)
    out += crack * (0.35 + 0.65 * flame_env / (np.max(flame_env) + 1e-12)) * 1.1
    curl = s.grains(rng, sr, dur, 110, 700, 3200, 0.02, p8._env_curve([(0.0, 0.0), (0.15, 0.8), (0.5, 0.4), (1.0, 0.0)]))
    out += curl * 0.22
    for _ in range(int(rng.integers(2, 4))):          # a pop of a burning fold
        pop = s.noise_burst(rng, sr, 0.05, 500, 2600, 0.0005, 0.008)
        s.mix_at(out, pop, s.secs(sr, rng.uniform(0.3, dur * 0.6)), rng.uniform(0.5, 0.9))
    out = s.reverb(out, sr, rng, 0.12, 0.5, 0.12)[:n]      # inside the stove's iron box
    out = out * 0.85 + 0.15 * s.resonator(out, sr, 340, 4.0)
    return s.fade(s.normalize(s.lowpass(out, sr, 4800, 4), 0.6), sr, 0.01, 0.5)


def notice_sheet(rng, sr):
    """The large sheet put up at the board: it flaps as it is held up, lies against the planks, is smoothed with the
    palm and pinned with two tacks pressed in by the thumb (≈ 1.1 s)."""
    dur = 1.1
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, _swish(rng, sr, 0.24, 180, 1500, 1.4), 0, 0.6)
    s.mix_at(out, _crackle(rng, sr, 0.12, 260, 600, 4200), s.secs(sr, 0.05), 0.4)
    s.mix_at(out, sfx.wood(rng, sr, rng.uniform(170, 200), 0.03, 0.2, 0.2), s.secs(sr, 0.22), 0.35)   # against the planks
    s.mix_at(out, _swish(rng, sr, 0.22, 200, 1200, 2.0), s.secs(sr, 0.3), 0.35)                      # smoothed
    for k, at in enumerate((rng.uniform(0.6, 0.66), rng.uniform(0.86, 0.92))):
        tack = sfx.wood(rng, sr, rng.uniform(820, 980), 0.012, 0.5, 0.08)
        tack += s.partials(sr, tack.size, rng.uniform(3000, 3400), [1, 1.5], [0.12, 0.05], [0.006, 0.004], rng)
        s.mix_at(out, tack, s.secs(sr, at), 0.7 if k == 0 else 0.6)
    return s.fade(s.normalize(s.lowpass(out, sr, 5000), 0.6), sr, 0.002, 0.08)


# --- the gentleman with the case, the soil ------------------------------------------------------

def _snap(rng, sr, f0):
    """A brass catch springing: a bright click and a short metallic ring."""
    n = s.secs(sr, 0.09)
    ring = s.partials(sr, n, f0, [1, 1.52, 2.33, 3.71], [0.5, 0.3, 0.18, 0.08], [0.022, 0.015, 0.01, 0.006], rng, 0.0003, 0.01)
    click = s.bandpass(rng.standard_normal(n), sr, 1500, 6000) * s.env_ad(sr, n, 0.0002, 0.0022)
    return ring * 0.8 + click


def _case(rng, sr, opening):
    dur = 0.75
    n = s.secs(sr, dur)
    out = np.zeros(n)
    f0 = rng.uniform(2300, 2700)
    if opening:
        s.mix_at(out, _snap(rng, sr, f0), s.secs(sr, 0.03), 1.0)
        s.mix_at(out, _snap(rng, sr, f0 * rng.uniform(1.03, 1.08)), s.secs(sr, rng.uniform(0.15, 0.19)), 0.85)
        s.mix_at(out, sfx._creak(rng, sr, 0.32, 35, 70, 0.5) * 0.25, s.secs(sr, 0.28), 1.0)
        s.mix_at(out, _swish(rng, sr, 0.25, 200, 1400, 1.6), s.secs(sr, 0.33), 0.25)
    else:
        thump = p8._thud(rng, sr, 0.25, 260, 0.04) + s.fit(sfx.wood(rng, sr, 150, 0.035, 0.1, 0.25), s.secs(sr, 0.25)) * 0.6
        s.mix_at(out, thump, s.secs(sr, 0.02), 0.9)
        s.mix_at(out, _snap(rng, sr, f0), s.secs(sr, rng.uniform(0.3, 0.34)), 0.9)
        s.mix_at(out, _snap(rng, sr, f0 * rng.uniform(1.03, 1.08)), s.secs(sr, rng.uniform(0.44, 0.5)), 0.8)
    return s.fade(s.normalize(s.lowpass(out, sr, 6000), 0.65), sr, 0.001, 0.08)


def case_latch_open(rng, sr):
    """Cornelius Brenneisen's leather case opened: the two brass catches spring, the lid lifts on its leather hinge
    (≈ 0.75 s)."""
    return _case(rng, sr, True)


def case_latch_close(rng, sr):
    """The case shut: the lid drops with a dull leather thump, the two catches close (≈ 0.75 s)."""
    return _case(rng, sr, False)


def soil_handful(rng, sr):
    """A handful of grave soil taken: fingers push into the loose earth, lift it (crumbs trickle back), it is laid
    into a cloth and the cloth knotted (≈ 1.2 s)."""
    dur = 1.2
    n = s.secs(sr, dur)
    out = np.zeros(n)
    push = s.grains(rng, sr, 0.28, 2200, 140, 1700, 0.01, lambda p: float(np.sin(np.pi * p) ** 0.5))
    s.mix_at(out, push, s.secs(sr, 0.02), 1.0)
    s.mix_at(out, p8._thud(rng, sr, 0.2, 200, 0.03), s.secs(sr, 0.05), 0.4)
    trickle = s.grains(rng, sr, 0.35, 260, 500, 3000, 0.006, lambda p: float(np.exp(-p * 3)))
    s.mix_at(out, trickle, s.secs(sr, 0.32), 0.5)
    s.mix_at(out, sfx.cloth(rng, sr)[: s.secs(sr, 0.5)], s.secs(sr, 0.62), 0.45)
    return s.fade(s.normalize(s.lowpass(out, sr, 4500), 0.6), sr, 0.003, 0.1)


def _gate_stroke(rng, sr, f0, length):
    return s.partials(sr, s.secs(sr, length), f0 * rng.uniform(0.997, 1.003), [1, 2.03, 2.47, 3.11, 4.3, 5.6],
                      [0.6, 0.32, 0.22, 0.12, 0.07, 0.04], [1.1, 0.7, 0.55, 0.4, 0.25, 0.15], rng, attack=0.0015,
                      detune=0.0012)


def gate_bell_short(rng, sr):
    """The gate bell (Phase 8 gate_bell) pulled once, briefly, by a stranger who does not know the place: the cord's
    dry creak, a single stroke, the clapper touching once more, softly (≈ 2.6 s)."""
    n = s.secs(sr, 2.6)
    out = np.zeros(n)
    creak = s.grains(rng, sr, 0.16, 700, 250, 1400, 0.006, lambda p: float(np.sin(np.pi * p)))
    s.mix_at(out, creak, 0, 0.25)
    f0 = 1180.0
    s.mix_at(out, _gate_stroke(rng, sr, f0, 2.3), s.secs(sr, 0.1), 1.0)
    s.mix_at(out, s.bandpass(rng.standard_normal(s.secs(sr, 0.02)), sr, 2500, 7000) * 0.15, s.secs(sr, 0.1), 1.0)
    s.mix_at(out, _gate_stroke(rng, sr, f0, 1.6) * 0.25, s.secs(sr, rng.uniform(0.52, 0.58)), 1.0)
    out = s.reverb(out, sr, rng, 0.25, 1.6, 0.5)[:n]
    return s.fade(s.normalize(out, 0.6), sr, 0.0005, 0.5)


# --- the night watchman (ending C) -------------------------------------------------------------

def lantern_creak(rng, sr):
    """The watchman's lantern on its iron bail, moved by his hand or the wind: a short squeak of iron in the ring,
    the tin housing rattling once (≈ 0.8 s). Quiet, close."""
    dur = 0.8
    n = s.secs(sr, dur)
    out = np.zeros(n)
    sq = rng.uniform(0.28, 0.42)
    m = s.secs(sr, sq)
    t = s.tline(sr, m)
    curve = rng.uniform(70, 110) + rng.uniform(60, 120) * np.sin(np.pi * np.clip(t / sq, 0, 1))
    f = np.maximum(curve * (1.0 + 0.2 * s.lowpass(rng.standard_normal(m), sr, 30) * 4), 8.0)
    ph = np.cumsum(f / sr)
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float) * (1.0 + 0.3 * rng.standard_normal(m))
    squeak = 0.6 * s.resonator(pulses, sr, rng.uniform(1700, 2100), 9) + 0.4 * s.resonator(pulses, sr, rng.uniform(2700, 3100), 10)
    squeak = squeak * np.sin(np.pi * np.clip(t / sq, 0, 1)) ** 1.2
    s.mix_at(out, squeak, s.secs(sr, 0.02), 0.6)
    rattle = s.partials(sr, s.secs(sr, 0.12), rng.uniform(1100, 1400), [1, 1.9, 2.7], [0.3, 0.2, 0.1], [0.02, 0.012, 0.008], rng)
    s.mix_at(out, rattle, s.secs(sr, sq + rng.uniform(0.02, 0.08)), 0.35)
    return s.fade(s.normalize(s.lowpass(out, sr, 4800), 0.5), sr, 0.003, 0.15)


def watchman_bell(rng, sr):
    """The night watchman's hand bell at the Siebers' door – instead of a call with words: two slow strokes of a
    small, darker iron-bronze bell, the street answering a little (≈ 3.4 s)."""
    n = s.secs(sr, 3.4)
    out = np.zeros(n)
    f0 = rng.uniform(640, 680)
    for k, (at, g) in enumerate(((0.02, 1.0), (rng.uniform(1.05, 1.2), 0.8))):
        ring = s.partials(sr, s.secs(sr, 2.2), f0, [1, 2.0, 2.61, 3.36, 4.62], [0.6, 0.28, 0.2, 0.1, 0.05],
                          [1.0, 0.6, 0.45, 0.3, 0.18], rng, attack=0.002, detune=0.0015)
        s.mix_at(out, ring, s.secs(sr, at), g)
        s.mix_at(out, s.bandpass(rng.standard_normal(s.secs(sr, 0.015)), sr, 1500, 5000) * 0.1, s.secs(sr, at), g)
    out = s.reverb(out, sr, rng, 0.3, 1.8, 0.55)[:n]
    return s.fade(s.normalize(s.lowpass(out, sr, 6000), 0.55), sr, 0.0005, 0.6)


# --- the motif of „Wer weiß, wann?" (sparing; SFX, not a music context) -------------------------

# D minor: A3 – D4 – F4 – E4: it rises, turns and stays on the second – a question.
MOTIF = (220.0, 293.7, 349.2, 329.6)


def motif_when(rng, sr):
    """Four bowed notes over a held low D and A, quiet; the last one hangs (≈ 5.5 s). Played when the chain opens,
    when the mark is seen and when the chain ends."""
    dur = 5.5
    n = s.secs(sr, dur)
    out = s.fit(s.pad_tone(sr, [73.4, 110.0, 146.8], dur, rng, 1.0, 2.0, 0.35), n) * 0.8
    at = 0.35
    for i, f in enumerate(MOTIF):
        ln = 0.72 if i < 3 else 2.6
        note = p8._bowed(rng, sr, f, ln + 0.25, 0.09, 0.0035, 0.35, 0.25 if i < 3 else 1.2)
        s.mix_at(out, note, s.secs(sr, at), 0.3 if i < 3 else 0.27)
        at += ln
    out = s.reverb(out, sr, rng, 0.38, 2.4, 0.8)[:n]
    return s.fade(s.normalize(out, 0.5), sr, 0.03, 1.2)


def chapter_when(rng, sr):
    """Chapter „Wer weiß, wann?": the motif once more on the lute, then the answer – E falls to D, the pad opens from
    D minor to an open D (no third), a low bowed D underneath (≈ 8 s)."""
    dur = 8.0
    n = s.secs(sr, dur)
    out = s.fit(s.pad_tone(sr, [146.8, 220.0, 293.7, 349.2], 3.8, rng, 1.2, 1.8, 0.5), n) * 0.65
    s.mix_at(out, s.pad_tone(sr, [146.8, 220.0, 293.7, 440.0], 4.8, rng, 1.6, 2.6, 0.5), s.secs(sr, 3.0), 0.7)
    at = 0.3
    for i, f in enumerate(MOTIF + (293.7,)):
        p = s.pluck(sr, f, 3.0, rng, 0.42)
        s.mix_at(out, p, s.secs(sr, at), 0.34 if i < 4 else 0.38)
        at += 0.5 if i < 3 else 0.9
    s.mix_at(out, s.fit(p8._bowed(rng, sr, 146.8, 4.8, 1.4, 0.003, 0.35, 1.4), s.secs(sr, 4.8)), s.secs(sr, 2.9), 0.22)
    out = s.reverb(out, sr, rng, 0.35, 2.4, 0.75)[:n]
    return s.fade(s.normalize(out, 0.5), sr, 0.02, 1.4)
