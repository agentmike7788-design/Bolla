"""One-shot sound effects (world + UI). Each function: (rng, sr) -> mono float array.

Tone of the game: quiet, warm, melancholic – "death is a craft, not horror". Bodies are
only hinted at: dull, soft, never wet or sharp.
"""
from __future__ import annotations

import numpy as np

import synth as s


# --- footsteps ---------------------------------------------------------------------------

def step_grass(rng, sr):
    n = s.secs(sr, 0.22)
    swish = s.bandpass(rng.standard_normal(n), sr, 1500, 6500) * s.env_ad(sr, n, 0.012, 0.045)
    crunch = s.grains(rng, sr, 0.22, 260, 2500, 9000, 0.004,
                      density_env=lambda p: float(np.exp(-p * 7)))
    thump = s.lowpass(rng.standard_normal(n), sr, 220) * s.env_ad(sr, n, 0.004, 0.03)
    x = swish * 0.5 + crunch * 0.7 + thump * 0.8
    return s.fade(s.normalize(x, 0.7), sr, 0.002, 0.03)


def step_earth(rng, sr):
    n = s.secs(sr, 0.2)
    thump = s.lowpass(rng.standard_normal(n), sr, 300, 2) * s.env_ad(sr, n, 0.003, 0.035)
    grit = s.grains(rng, sr, 0.2, 180, 900, 4500, 0.006, density_env=lambda p: float(np.exp(-p * 9)))
    x = thump * 1.3 + grit * 0.5
    return s.fade(s.normalize(x, 0.75), sr, 0.001, 0.03)


def step_stone(rng, sr):
    n = s.secs(sr, 0.2)
    click = s.bandpass(rng.standard_normal(n), sr, 1800, 7000) * s.env_ad(sr, n, 0.0008, 0.008)
    knock = s.partials(sr, n, 900 * rng.uniform(0.9, 1.1), [1, 1.7, 2.9], [0.5, 0.3, 0.15],
                       [0.012, 0.008, 0.005], rng)
    scrape = s.grains(rng, sr, 0.2, 260, 2500, 8000, 0.003, density_env=lambda p: float(np.exp(-p * 12)))
    heel = s.lowpass(rng.standard_normal(n), sr, 350) * s.env_ad(sr, n, 0.002, 0.02)
    x = click * 0.6 + knock * 0.5 + scrape * 0.4 + heel * 0.8
    return s.fade(s.normalize(x, 0.7), sr, 0.0005, 0.03)


def step_wood(rng, sr):
    n = s.secs(sr, 0.26)
    exc = rng.standard_normal(n) * s.env_ad(sr, n, 0.001, 0.006)
    f0 = 170 * rng.uniform(0.9, 1.12)
    body = (s.resonator(exc, sr, f0, 6) * 1.6 + s.resonator(exc, sr, f0 * 2.3, 9) * 0.8
            + s.resonator(exc, sr, f0 * 4.1, 12) * 0.35)
    creak = 0.0
    if rng.uniform() < 0.35:
        cn = s.secs(sr, 0.18)
        fm = 420 * rng.uniform(0.8, 1.3) * (1 + 0.04 * np.sin(s.TAU * 31 * s.tline(sr, cn)))
        c = s.sine(sr, cn, fm) * s.env_ad(sr, cn, 0.05, 0.05) * 0.12
        creak = s.fit(s.pad(c, sr, 0.04), n)
    x = body + s.lowpass(exc, sr, 2500) * 0.3 + creak
    return s.fade(s.normalize(x, 0.7), sr, 0.0005, 0.04)


# --- digging & soil ----------------------------------------------------------------------

def dig(rng, sr):
    n = s.secs(sr, 0.75)
    t = s.tline(sr, n)
    # blade pushed into soil: a short gritty scrape, then the clod lifted and dropped
    scrape_env = np.clip((t - 0.0) / 0.03, 0, 1) * np.exp(-np.maximum(t - 0.03, 0) / 0.09) * (t < 0.3)
    scrape = s.bandpass(rng.standard_normal(n), sr, 700, 3800) * scrape_env
    tick = s.partials(sr, n, 1900 * rng.uniform(0.9, 1.1), [1, 2.4], [0.25, 0.1], [0.02, 0.01], rng)
    drop = np.zeros(n)
    k = s.secs(sr, rng.uniform(0.38, 0.46))
    thud = s.lowpass(rng.standard_normal(s.secs(sr, 0.2)), sr, 260) * s.env_ad(sr, s.secs(sr, 0.2), 0.004, 0.05)
    s.mix_at(drop, thud, k, 1.1)
    s.mix_at(drop, s.grains(rng, sr, 0.25, 260, 900, 5000, 0.006, lambda p: float(np.exp(-p * 5))), k, 0.6)
    x = scrape * 0.8 + tick * 0.6 + drop
    return s.fade(s.normalize(x, 0.75), sr, 0.002, 0.05)


def dirt_pour(rng, sr):
    dur = 1.3
    x = s.grains(rng, sr, dur, 2600, 400, 5200, 0.008,
                 density_env=lambda p: float(min(1.0, p * 8) * np.exp(-max(p - 0.25, 0) * 3.2)))
    n = x.size
    rumble = s.lowpass(rng.standard_normal(n), sr, 180) * s.env_asr(sr, n, 0.08, 0.9) * 0.5
    return s.fade(s.normalize(x + rumble, 0.7), sr, 0.01, 0.2)


def stone_set(rng, sr):
    n = s.secs(sr, 1.1)
    t = s.tline(sr, n)
    grind = s.bandpass(rng.standard_normal(n), sr, 150, 1500) * (np.clip(t / 0.1, 0, 1) * (t < 0.6)) * 0.4
    grind *= 0.7 + 0.3 * np.sin(s.TAU * 9 * t)
    thud = np.zeros(n)
    th = s.lowpass(rng.standard_normal(s.secs(sr, 0.4)), sr, 160) * s.env_ad(sr, s.secs(sr, 0.4), 0.003, 0.08)
    s.mix_at(thud, th, s.secs(sr, 0.62), 1.4)
    s.mix_at(thud, s.partials(sr, s.secs(sr, 0.3), 620, [1, 1.6, 2.7], [0.2, 0.1, 0.05], [0.04, 0.03, 0.02], rng),
             s.secs(sr, 0.62))
    return s.fade(s.normalize(grind + thud, 0.8), sr, 0.02, 0.08)


# --- crafts & stations -------------------------------------------------------------------

def _wood_hit(rng, sr, dur, f0, decay, bright):
    n = s.secs(sr, dur)
    exc = rng.standard_normal(n) * s.env_ad(sr, n, 0.0005, 0.004)
    modes = [1.0, 2.1, 3.3, 5.2]
    out = np.zeros(n)
    for i, m in enumerate(modes):
        out += s.resonator(exc, sr, f0 * m * rng.uniform(0.97, 1.03), 10 + i * 4) * (0.9 / (i + 1))
    out *= s.env_ad(sr, n, 0.0, decay)
    return out + s.highpass(exc, sr, 2000) * bright


def chop(rng, sr):
    n = s.secs(sr, 0.55)
    hit = s.fit(_wood_hit(rng, sr, 0.5, 260 * rng.uniform(0.9, 1.1), 0.09, 0.5), n)
    split = s.grains(rng, sr, 0.55, 300, 1500, 6000, 0.005, lambda p: float(np.exp(-p * 10)))
    x = hit + split * 0.35
    return s.fade(s.normalize(x, 0.8), sr, 0.0005, 0.06)


def saw(rng, sr):
    """Two strokes of a hand saw (pull, push)."""
    n = s.secs(sr, 1.0)
    t = s.tline(sr, n)
    out = np.zeros(n)
    for k, (st, ln) in enumerate(((0.0, 0.42), (0.48, 0.42))):
        m = (t >= st) & (t < st + ln)
        ph = np.clip((t - st) / ln, 0, 1)
        env = np.sin(np.pi * ph) ** 0.8 * m
        teeth = 0.5 + 0.5 * np.sign(np.sin(s.TAU * (95 + 30 * k) * t))
        rasp = s.bandpass(rng.standard_normal(n), sr, 1800 + 500 * k, 6500) * teeth
        out += rasp * env * (0.9 if k == 0 else 0.75)
    out = out + s.resonator(out, sr, 700, 4) * 0.3
    return s.fade(s.normalize(out, 0.55), sr, 0.01, 0.05)


def hammer(rng, sr):
    n = s.secs(sr, 0.4)
    hit = s.fit(_wood_hit(rng, sr, 0.4, 420 * rng.uniform(0.92, 1.08), 0.05, 0.3), n)
    nail = s.partials(sr, n, 2400 * rng.uniform(0.95, 1.05), [1, 1.5, 2.8], [0.2, 0.1, 0.05],
                      [0.03, 0.02, 0.012], rng)
    return s.fade(s.normalize(hit + nail, 0.8), sr, 0.0005, 0.05)


def anvil(rng, sr):
    n = s.secs(sr, 1.4)
    f0 = 980 * rng.uniform(0.96, 1.04)
    ring = s.partials(sr, n, f0, [1, 2.76, 5.4, 8.9, 1.52], [0.6, 0.35, 0.18, 0.08, 0.25],
                      [0.45, 0.25, 0.12, 0.06, 0.3], rng)
    click = s.bandpass(rng.standard_normal(n), sr, 2500, 9000) * s.env_ad(sr, n, 0.0003, 0.004)
    x = ring + click * 0.6
    return s.fade(s.normalize(s.lowpass(x, sr, 7000), 0.7), sr, 0.0005, 0.2)


def chisel(rng, sr):
    n = s.secs(sr, 0.5)
    ting = s.partials(sr, n, 2900 * rng.uniform(0.95, 1.05), [1, 1.9, 3.1], [0.4, 0.2, 0.1],
                      [0.05, 0.03, 0.02], rng)
    grit = s.grains(rng, sr, 0.5, 500, 1500, 7000, 0.003, lambda p: float(np.exp(-p * 14)))
    thump = s.lowpass(rng.standard_normal(n), sr, 400) * s.env_ad(sr, n, 0.001, 0.02)
    return s.fade(s.normalize(ting + grit * 0.6 + thump * 0.5, 0.75), sr, 0.0005, 0.05)


def pick_stone(rng, sr):
    n = s.secs(sr, 0.6)
    clang = s.partials(sr, n, 1500 * rng.uniform(0.9, 1.1), [1, 2.2, 3.7], [0.4, 0.25, 0.1],
                       [0.08, 0.05, 0.03], rng)
    crack = s.grains(rng, sr, 0.6, 600, 900, 6000, 0.005, lambda p: float(np.exp(-p * 9)))
    thump = s.lowpass(rng.standard_normal(n), sr, 300) * s.env_ad(sr, n, 0.001, 0.04)
    return s.fade(s.normalize(clang + crack * 0.7 + thump * 0.6, 0.8), sr, 0.0005, 0.06)


def loom(rng, sr):
    """Shuttle swish and the beater's wooden clack."""
    n = s.secs(sr, 0.9)
    sw = s.bandpass(rng.standard_normal(n), sr, 900, 4000) * s.env_ad(sr, n, 0.12, 0.08) * 0.3
    clack = np.zeros(n)
    s.mix_at(clack, _wood_hit(rng, sr, 0.3, 600, 0.03, 0.4), s.secs(sr, 0.45), 1.0)
    s.mix_at(clack, _wood_hit(rng, sr, 0.25, 520, 0.025, 0.3), s.secs(sr, 0.58), 0.6)
    return s.fade(s.normalize(sw + clack, 0.7), sr, 0.01, 0.06)


def bellows(rng, sr):
    n = s.secs(sr, 1.4)
    env = s.env_asr(sr, n, 0.35, 0.8)
    air = s.bandpass(rng.standard_normal(n), sr, 150, 1400) * env
    roar = s.lowpass(rng.standard_normal(n), sr, 120) * env * 0.8
    crack = s.grains(rng, sr, 1.4, 60, 1500, 6000, 0.004)
    return s.fade(s.normalize(air + roar + crack * 0.3, 0.6), sr, 0.05, 0.3)


def rustle(rng, sr, dur=0.6, lo=1200.0, hi=7000.0):
    x = s.grains(rng, sr, dur, 900, lo, hi, 0.01, lambda p: float(np.sin(np.pi * p) ** 0.7))
    return s.fade(s.normalize(x, 0.5), sr, 0.02, 0.1)


def cloth(rng, sr):
    n = s.secs(sr, 0.7)
    t = s.tline(sr, n)
    env = np.sin(np.pi * np.clip(t / 0.7, 0, 1)) ** 1.2
    base = s.bandpass(rng.standard_normal(n), sr, 500, 3500) * env
    fold = s.grains(rng, sr, 0.7, 260, 1500, 5000, 0.015, lambda p: float(np.sin(np.pi * p)))
    return s.fade(s.normalize(s.lowpass(base * 0.6 + fold * 0.5, sr, 4000), 0.45), sr, 0.03, 0.12)


def wash(rng, sr):
    """Water lifted with a cloth and wrung softly – a calm basin sound."""
    n = s.secs(sr, 1.3)
    t = s.tline(sr, n)
    slosh = s.bandpass(rng.standard_normal(n), sr, 300, 2200) * np.sin(np.pi * np.clip(t / 1.3, 0, 1)) ** 2 * 0.4
    out = slosh
    for _ in range(int(rng.integers(10, 16))):
        bn = s.secs(sr, 0.05)
        f = rng.uniform(500, 1400)
        b = s.sine(sr, bn, np.linspace(f, f * 1.7, bn)) * s.env_ad(sr, bn, 0.002, 0.012)
        s.mix_at(out, b, int(rng.uniform(0.05, 1.1) * sr), rng.uniform(0.05, 0.18))
    drips = s.grains(rng, sr, 1.3, 40, 1500, 5000, 0.006, lambda p: float(p > 0.6))
    return s.fade(s.normalize(s.lowpass(out + drips * 0.3, sr, 5000), 0.5), sr, 0.05, 0.2)


def scrub(rng, sr):
    n = s.secs(sr, 0.9)
    t = s.tline(sr, n)
    strokes = np.abs(np.sin(s.TAU * 2.4 * t)) ** 1.5
    x = s.bandpass(rng.standard_normal(n), sr, 2000, 7500) * strokes
    return s.fade(s.normalize(x, 0.4), sr, 0.03, 0.1)


def snip(rng, sr):
    n = s.secs(sr, 0.25)
    blade = s.partials(sr, n, 3600, [1, 1.4, 2.2], [0.3, 0.2, 0.1], [0.02, 0.015, 0.01], rng)
    cut = s.bandpass(rng.standard_normal(n), sr, 3000, 9000) * s.env_ad(sr, n, 0.001, 0.01)
    leaf = s.grains(rng, sr, 0.25, 300, 1500, 6000, 0.006, lambda p: float(np.exp(-p * 8)))
    return s.fade(s.normalize(blade + cut * 0.5 + leaf * 0.5, 0.6), sr, 0.0005, 0.04)


def quill(rng, sr):
    n = s.secs(sr, 0.8)
    t = s.tline(sr, n)
    strokes = (np.sin(s.TAU * 3.1 * t + rng.uniform(0, 6)) > 0.2).astype(float)
    strokes = s.lowpass(strokes, sr, 40)
    x = s.bandpass(rng.standard_normal(n), sr, 3000, 9000) * strokes
    return s.fade(s.normalize(x, 0.3), sr, 0.02, 0.1)


def smoke_hiss(rng, sr):
    n = s.secs(sr, 1.4)
    x = s.bandpass(rng.standard_normal(n), sr, 1500, 6000) * s.env_asr(sr, n, 0.3, 0.8) * 0.4
    crack = s.grains(rng, sr, 1.4, 50, 1500, 7000, 0.004)
    return s.fade(s.normalize(x + crack * 0.5, 0.4), sr, 0.05, 0.2)


# --- objects -----------------------------------------------------------------------------

def _creak(rng, sr, dur, f_lo, f_hi, rough=0.4):
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    curve = f_lo + (f_hi - f_lo) * (0.5 - 0.5 * np.cos(np.pi * np.clip(t / dur, 0, 1)))
    jitter = 1.0 + 0.06 * s.lowpass(rng.standard_normal(n), sr, 30) * 3
    f = curve * jitter
    # stick-slip friction: pulse train through wood resonances
    ph = np.cumsum(f / sr)
    pulses = (np.diff(np.floor(ph), prepend=0.0) > 0).astype(float)
    pulses *= 1.0 + rough * rng.standard_normal(n)
    body = s.resonator(pulses, sr, 900, 5) + s.resonator(pulses, sr, 1700, 7) * 0.6 + s.resonator(pulses, sr, 380, 4) * 0.5
    return body * s.env_asr(sr, n, dur * 0.2, dur * 0.3)


def _latch(rng, sr):
    n = s.secs(sr, 0.12)
    return s.partials(sr, n, 2100 * rng.uniform(0.95, 1.05), [1, 1.6, 2.5], [0.4, 0.25, 0.1],
                      [0.02, 0.012, 0.008], rng) + s.bandpass(rng.standard_normal(n), sr, 2000, 8000) * s.env_ad(sr, n, 0.0003, 0.003) * 0.5


def door_open(rng, sr):
    n = s.secs(sr, 1.3)
    out = np.zeros(n)
    s.mix_at(out, _latch(rng, sr), 0, 0.8)
    s.mix_at(out, _creak(rng, sr, 0.9, 30, 75), s.secs(sr, 0.12), 0.25)
    s.mix_at(out, s.lowpass(rng.standard_normal(s.secs(sr, 0.9)), sr, 600) * s.env_asr(sr, s.secs(sr, 0.9), 0.2, 0.4) * 0.15,
             s.secs(sr, 0.15))
    return s.fade(s.normalize(out, 0.6), sr, 0.001, 0.15)


def door_close(rng, sr):
    n = s.secs(sr, 0.9)
    out = np.zeros(n)
    s.mix_at(out, _creak(rng, sr, 0.35, 70, 40), 0, 0.15)
    th = s.lowpass(rng.standard_normal(s.secs(sr, 0.5)), sr, 220) * s.env_ad(sr, s.secs(sr, 0.5), 0.002, 0.07)
    s.mix_at(out, th + s.fit(_wood_hit(rng, sr, 0.5, 140, 0.08, 0.1), th.size), s.secs(sr, 0.33), 1.0)
    s.mix_at(out, _latch(rng, sr), s.secs(sr, 0.38), 0.5)
    return s.fade(s.normalize(out, 0.7), sr, 0.002, 0.15)


def chest_open(rng, sr):
    n = s.secs(sr, 0.9)
    out = np.zeros(n)
    s.mix_at(out, _latch(rng, sr), 0, 0.6)
    s.mix_at(out, _creak(rng, sr, 0.55, 45, 110, 0.6), s.secs(sr, 0.1), 0.25)
    return s.fade(s.normalize(out, 0.55), sr, 0.001, 0.1)


def chest_close(rng, sr):
    n = s.secs(sr, 0.6)
    out = np.zeros(n)
    th = _wood_hit(rng, sr, 0.4, 190, 0.06, 0.2)
    s.mix_at(out, th, s.secs(sr, 0.05), 1.0)
    s.mix_at(out, s.lowpass(rng.standard_normal(s.secs(sr, 0.3)), sr, 200) * s.env_ad(sr, s.secs(sr, 0.3), 0.002, 0.05),
             s.secs(sr, 0.05), 0.8)
    s.mix_at(out, _latch(rng, sr), s.secs(sr, 0.14), 0.35)
    return s.fade(s.normalize(out, 0.6), sr, 0.001, 0.1)


def crate(rng, sr):
    n = s.secs(sr, 0.5)
    x = s.fit(_wood_hit(rng, sr, 0.5, 230, 0.06, 0.25), n)
    x += s.lowpass(rng.standard_normal(n), sr, 200) * s.env_ad(sr, n, 0.002, 0.04) * 0.8
    return s.fade(s.normalize(x, 0.6), sr, 0.001, 0.06)


def coins(rng, sr):
    n = s.secs(sr, 0.9)
    out = np.zeros(n)
    count = int(rng.integers(4, 7))
    t0 = 0.0
    for i in range(count):
        t0 += rng.uniform(0.03, 0.11)
        f0 = rng.uniform(3200, 5200)
        c = s.partials(sr, s.secs(sr, 0.35), f0, [1, 1.47, 2.09, 2.76], [0.4, 0.3, 0.2, 0.1],
                       [0.09, 0.06, 0.04, 0.03], rng)
        s.mix_at(out, c, s.secs(sr, t0), rng.uniform(0.4, 1.0) * (0.9 ** i))
    return s.fade(s.normalize(s.lowpass(out, sr, 9000), 0.45), sr, 0.0005, 0.1)


def pickup(rng, sr):
    n = s.secs(sr, 0.3)
    t = s.tline(sr, n)
    sw = s.bandpass(rng.standard_normal(n), sr, 600, 3500) * np.sin(np.pi * np.clip(t / 0.25, 0, 1)) ** 2
    return s.fade(s.normalize(sw, 0.35), sr, 0.01, 0.05)


def putdown(rng, sr):
    n = s.secs(sr, 0.35)
    th = s.lowpass(rng.standard_normal(n), sr, 350) * s.env_ad(sr, n, 0.002, 0.03)
    tap = s.fit(_wood_hit(rng, sr, 0.3, 320, 0.03, 0.1), n) * 0.4
    return s.fade(s.normalize(th + tap, 0.5), sr, 0.001, 0.05)


def corpse_down(rng, sr):
    """Dull and soft: a heavy linen bundle set down, no wetness, no bones."""
    n = s.secs(sr, 0.9)
    th = s.lowpass(rng.standard_normal(n), sr, 140, 2) * s.env_ad(sr, n, 0.008, 0.09)
    cl = np.zeros(n)
    s.mix_at(cl, cloth(rng, sr) * 0.6, s.secs(sr, 0.04))
    wood = s.fit(_wood_hit(rng, sr, 0.4, 120, 0.06, 0.0), n) * 0.25
    return s.fade(s.normalize(th * 1.4 + cl * 0.5 + wood, 0.6), sr, 0.004, 0.15)


def glass_seal(rng, sr):
    """A jar closed and sealed: gentle clink, a cork pressed in, a wax brush."""
    n = s.secs(sr, 1.2)
    out = np.zeros(n)
    clink = s.partials(sr, s.secs(sr, 0.8), 2350 * rng.uniform(0.97, 1.03), [1, 2.32, 4.1, 5.9],
                       [0.4, 0.2, 0.1, 0.05], [0.35, 0.18, 0.09, 0.05], rng)
    s.mix_at(out, clink, 0, 0.5)
    cn = s.secs(sr, 0.22)
    squeak = s.sine(sr, cn, np.linspace(700, 1100, cn) * (1 + 0.03 * np.sin(s.TAU * 60 * s.tline(sr, cn))))
    s.mix_at(out, squeak * s.env_asr(sr, cn, 0.05, 0.08) * 0.12, s.secs(sr, 0.35))
    s.mix_at(out, s.partials(sr, s.secs(sr, 0.4), 1800, [1, 2.4], [0.2, 0.08], [0.1, 0.05], rng), s.secs(sr, 0.62), 0.4)
    return s.fade(s.normalize(s.reverb(out, sr, rng, 0.25, 1.0, 0.25)[:n], 0.45), sr, 0.0005, 0.2)


def anatomy_tool(rng, sr):
    """Barely there: a cloth fold and a soft metal tick, both muffled under the shroud."""
    n = s.secs(sr, 1.0)
    out = cloth(rng, sr)
    out = s.fit(out, n) * 0.7
    tick = s.partials(sr, s.secs(sr, 0.2), 2600, [1, 1.8], [0.15, 0.06], [0.03, 0.02], rng)
    s.mix_at(out, tick, s.secs(sr, rng.uniform(0.35, 0.55)), 0.5)
    return s.fade(s.normalize(s.lowpass(out, sr, 2600), 0.35), sr, 0.02, 0.2)


def cart_roll(rng, sr):
    """Loop (3 s): wooden wheels on the gravel road, a soft axle squeak each turn."""
    n = s.secs(sr, 3.0)
    gravel = s.grains(rng, sr, 3.0, 1600, 500, 4500, 0.008, wrap=True)
    gravel *= s.loop_lfo(rng, sr, n, 6, 0.4)
    rumble = s.loop_filter_band(s.brown(rng, n), sr, 40, 220) * 0.6
    out = gravel * 0.6 + rumble
    for k in range(3):
        sq = _creak(rng, sr, 0.35, 110, 85, 0.3) * 0.08
        s.mix_at(out, sq, s.secs(sr, k * 1.0 + 0.2), 1.0, wrap=True)
        bump = s.lowpass(rng.standard_normal(s.secs(sr, 0.15)), sr, 200) * s.env_ad(sr, s.secs(sr, 0.15), 0.002, 0.03)
        s.mix_at(out, bump, s.secs(sr, k * 1.0 + rng.uniform(0.5, 0.9)), 0.5, wrap=True)
    return s.normalize(out, 0.5)


# --- bells -------------------------------------------------------------------------------

def church_bell(rng, sr):
    """A village bell, D3-ish strike tone with the classic minor-third tierce."""
    n = s.secs(sr, 7.0)
    f0 = 293.0
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.51, 2.66, 3.01, 4.07]
    amps = [0.45, 0.6, 0.45, 0.25, 0.4, 0.15, 0.1, 0.08, 0.05]
    decays = [3.5, 2.6, 1.9, 1.4, 1.2, 0.7, 0.6, 0.45, 0.3]
    x = s.partials(sr, n, f0, ratios, amps, decays, rng, attack=0.003, detune=0.001)
    beat = 1.0 + 0.08 * np.sin(s.TAU * 1.3 * s.tline(sr, n))
    strike = s.bandpass(rng.standard_normal(n), sr, 800, 4000) * s.env_ad(sr, n, 0.0005, 0.01) * 0.3
    x = x * beat + strike
    return s.fade(s.normalize(s.reverb(x, sr, rng, 0.35, 2.5, 0.8)[:n], 0.7), sr, 0.0005, 0.6)


def small_bell(rng, sr):
    n = s.secs(sr, 3.5)
    x = s.partials(sr, n, 880, [1, 2.0, 2.4, 3.0, 4.2, 5.4], [0.6, 0.3, 0.25, 0.15, 0.08, 0.05],
                   [1.6, 1.0, 0.8, 0.6, 0.35, 0.2], rng, detune=0.001)
    return s.fade(s.normalize(s.reverb(x, sr, rng, 0.35, 2.0, 0.6)[:n], 0.55), sr, 0.0005, 0.4)


# --- spirits, story, travel --------------------------------------------------------------

def _glass_pad(rng, sr, freqs, dur, attack, release, shimmer=0.4):
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    out = np.zeros(n)
    for f in freqs:
        for v in (-1, 0, 1):
            ff = f * (1.0 + 0.0025 * v)
            trem = 1.0 + shimmer * 0.3 * np.sin(s.TAU * rng.uniform(3, 6) * t + rng.uniform(0, 6))
            out += np.sin(s.TAU * ff * t + rng.uniform(0, 6)) * trem
            out += 0.25 * np.sin(s.TAU * ff * 2.0 * t) * trem
    out *= s.env_asr(sr, n, attack, release)
    return out


def ghost_appear(rng, sr):
    x = _glass_pad(rng, sr, [740.0, 1108.7, 1480.0], 3.2, 1.0, 1.8)
    x = s.reverb(x, sr, rng, 0.5, 2.5, 0.8)[: s.secs(sr, 3.6)]
    return s.fade(s.normalize(s.lowpass(x, sr, 6000), 0.35), sr, 0.2, 0.6)


def ghost_content(rng, sr):
    """Warm and settling: a rising major sixth, then a soft fifth below."""
    n = s.secs(sr, 3.6)
    out = np.zeros(n)
    for i, f in enumerate((587.3, 987.8, 880.0)):
        tone = _glass_pad(rng, sr, [f], 2.6 - i * 0.3, 0.25, 1.2, 0.2)
        s.mix_at(out, tone, s.secs(sr, i * 0.45), 0.8)
    out = s.reverb(out, sr, rng, 0.45, 2.2, 0.7)[:n]
    return s.fade(s.normalize(s.lowpass(out, sr, 5500), 0.35), sr, 0.05, 0.6)


def ghost_restless(rng, sr):
    """Uneasy, never scary: two glass tones a semitone apart, slowly beating, falling a little."""
    n = s.secs(sr, 3.4)
    t = s.tline(sr, n)
    out = np.zeros(n)
    for f in (622.3, 659.3):
        glide = f * (1.0 - 0.02 * np.clip(t / 3.4, 0, 1))
        out += np.sin(np.cumsum(s.TAU * glide / sr)) + 0.2 * np.sin(np.cumsum(s.TAU * 2 * glide / sr))
    out *= s.env_asr(sr, n, 1.0, 1.4)
    out += s.bandpass(rng.standard_normal(n), sr, 400, 1200) * s.env_asr(sr, n, 1.2, 1.2) * 0.15
    out = s.reverb(out, sr, rng, 0.5, 2.2, 0.7)[:n]
    return s.fade(s.normalize(s.lowpass(out, sr, 5000), 0.3), sr, 0.2, 0.6)


def ghost_night(rng, sr):
    """The hour the graves begin to speak: a low, slow breath of pad."""
    n = s.secs(sr, 5.0)
    x = s.pad_tone(sr, [146.8, 220.0, 293.7], 5.0, rng, 1.8, 2.5, 0.4)
    x += _glass_pad(rng, sr, [880.0], 5.0, 2.2, 2.2, 0.2) * 0.12
    x = s.reverb(x, sr, rng, 0.4, 2.5, 0.8)[:n]
    return s.fade(s.normalize(x, 0.35), sr, 0.3, 1.0)


def chapter(rng, sr):
    """Quiet fanfare: lute arpeggio D–F#–A–D over a slowly opening pad."""
    n = s.secs(sr, 6.0)
    out = s.fit(s.pad_tone(sr, [146.8, 220.0, 293.7, 370.0], 6.0, rng, 1.5, 2.5, 0.5), n) * 0.8
    for i, f in enumerate((293.7, 370.0, 440.0, 587.3, 740.0)):
        p = s.pluck(sr, f, 3.0, rng, 0.45)
        s.mix_at(out, p, s.secs(sr, 0.25 + i * 0.32), 0.35 if i < 4 else 0.28)
    out = s.reverb(out, sr, rng, 0.35, 2.2, 0.7)[:n]
    return s.fade(s.normalize(out, 0.5), sr, 0.02, 1.0)


def travel(rng, sr):
    n = s.secs(sr, 1.6)
    t = s.tline(sr, n)
    env = np.sin(np.pi * np.clip(t / 1.6, 0, 1)) ** 2
    lo = 300 + 900 * np.sin(np.pi * np.clip(t / 1.6, 0, 1))
    x = s.bandpass(rng.standard_normal(n), sr, 200, 2500) * env
    x = s.lowpass(x, sr, 1600) * 0.7 + s.lowpass(rng.standard_normal(n), sr, 150) * env * 0.4
    del lo
    return s.fade(s.normalize(x, 0.35), sr, 0.05, 0.2)


def remark(rng, sr):
    """Speech-bubble cue: two muted wooden tones, barely there."""
    n = s.secs(sr, 0.35)
    out = np.zeros(n)
    for i, f in enumerate((660.0, 880.0)):
        tone = s.partials(sr, s.secs(sr, 0.2), f, [1, 3.9], [0.5, 0.08], [0.05, 0.02], rng)
        s.mix_at(out, tone, s.secs(sr, i * 0.07), 0.6)
    return s.fade(s.normalize(out, 0.25), sr, 0.001, 0.05)


def build_place(rng, sr):
    n = s.secs(sr, 0.7)
    out = np.zeros(n)
    s.mix_at(out, crate(rng, sr), 0, 1.0)
    s.mix_at(out, rustle(rng, sr, 0.3) * 0.4, s.secs(sr, 0.1))
    return s.fade(s.normalize(out, 0.6), sr, 0.001, 0.1)


def build_remove(rng, sr):
    n = s.secs(sr, 0.6)
    out = np.zeros(n)
    s.mix_at(out, pickup(rng, sr) * 0.8, 0)
    s.mix_at(out, rustle(rng, sr, 0.35) * 0.5, s.secs(sr, 0.05))
    return s.fade(s.normalize(out, 0.5), sr, 0.001, 0.1)


def sleep(rng, sr):
    """Lying down: blanket and straw, then quiet."""
    n = s.secs(sr, 1.4)
    out = s.fit(cloth(rng, sr), n) * 0.8
    s.mix_at(out, rustle(rng, sr, 0.6, 800, 4000) * 0.4, s.secs(sr, 0.4))
    return s.fade(s.normalize(s.lowpass(out, sr, 3500), 0.4), sr, 0.05, 0.3)


# --- UI ----------------------------------------------------------------------------------

def ui_click(rng, sr):
    n = s.secs(sr, 0.09)
    x = s.partials(sr, n, 1250, [1, 2.7], [0.6, 0.15], [0.018, 0.008], rng)
    x += s.bandpass(rng.standard_normal(n), sr, 2000, 6000) * s.env_ad(sr, n, 0.0003, 0.002) * 0.2
    return s.fade(s.normalize(x, 0.4), sr, 0.0003, 0.02)


def ui_hover(rng, sr):
    n = s.secs(sr, 0.06)
    x = s.partials(sr, n, 1900, [1], [0.5], [0.012], rng)
    return s.fade(s.normalize(x, 0.18), sr, 0.0005, 0.02)


def ui_open(rng, sr):
    """A book cover lifted / a ledger opened."""
    n = s.secs(sr, 0.35)
    t = s.tline(sr, n)
    sw = s.bandpass(rng.standard_normal(n), sr, 700, 4500) * np.sin(np.pi * np.clip(t / 0.3, 0, 1)) ** 2
    tap = s.fit(_wood_hit(rng, sr, 0.2, 380, 0.025, 0.05), n)
    tap = np.roll(tap, s.secs(sr, 0.2)) * 0.25
    return s.fade(s.normalize(sw * 0.6 + tap, 0.35), sr, 0.005, 0.05)


def ui_close(rng, sr):
    n = s.secs(sr, 0.3)
    t = s.tline(sr, n)
    sw = s.bandpass(rng.standard_normal(n), sr, 500, 3000) * np.sin(np.pi * np.clip(t / 0.18, 0, 1)) ** 2 * (t < 0.18)
    tap = np.zeros(n)
    s.mix_at(tap, _wood_hit(rng, sr, 0.15, 300, 0.02, 0.05), s.secs(sr, 0.15), 0.35)
    return s.fade(s.normalize(sw * 0.5 + tap, 0.32), sr, 0.005, 0.05)


def ui_error(rng, sr):
    """Gently 'locked': two low muted wood knocks, the second a little lower."""
    n = s.secs(sr, 0.35)
    out = np.zeros(n)
    s.mix_at(out, _wood_hit(rng, sr, 0.2, 240, 0.03, 0.05), 0, 0.8)
    s.mix_at(out, _wood_hit(rng, sr, 0.2, 200, 0.035, 0.05), s.secs(sr, 0.11), 0.7)
    return s.fade(s.normalize(out, 0.35), sr, 0.0005, 0.05)


def ui_page(rng, sr):
    n = s.secs(sr, 0.45)
    t = s.tline(sr, n)
    env = np.sin(np.pi * np.clip(t / 0.4, 0, 1)) ** 1.5
    flutter = 0.6 + 0.4 * np.abs(np.sin(s.TAU * 14 * t))
    x = s.bandpass(rng.standard_normal(n), sr, 1500, 8000) * env * flutter
    snap = s.bandpass(rng.standard_normal(n), sr, 2000, 6000) * s.env_ad(sr, n, 0.001, 0.008)
    snap = np.roll(snap, s.secs(sr, 0.33)) * 0.3
    return s.fade(s.normalize(x * 0.6 + snap, 0.3), sr, 0.005, 0.05)


def ui_notify(rng, sr):
    n = s.secs(sr, 1.0)
    x = s.partials(sr, n, 1174.7, [1, 2.0, 3.0], [0.5, 0.15, 0.05], [0.35, 0.15, 0.08], rng)
    return s.fade(s.normalize(s.reverb(x, sr, rng, 0.25, 0.8, 0.25)[:n], 0.25), sr, 0.001, 0.2)


def ui_reward(rng, sr):
    n = s.secs(sr, 1.3)
    out = np.zeros(n)
    for i, f in enumerate((880.0, 1318.5)):
        s.mix_at(out, s.partials(sr, s.secs(sr, 1.0), f, [1, 2.0, 3.0], [0.5, 0.15, 0.05], [0.4, 0.15, 0.08], rng),
                 s.secs(sr, i * 0.12), 0.7)
    return s.fade(s.normalize(s.reverb(out, sr, rng, 0.25, 0.9, 0.3)[:n], 0.3), sr, 0.001, 0.25)
