"""Phase 8 „Wer heraufkommt" (docs/PHASE8_DESIGN.md §8.3): the sounds of the living who come up to the
graveyard – visitors, the apprentice, the wanderers, the night, the two feasts. Each function:
(rng, sr) -> mono float array (music: stereo (n, 2)). Everything synthesised from noise, sines and
filters (synth.py) – no samples, no recordings, no known melodies.

Tone: grief is shown, not voiced – no sobbing, no words, no choir. The visitors' sounds sit well
below the footsteps; the robber digs more muffled than the gravekeeper; the feast is lively but in
a minor mode.
"""
from __future__ import annotations

import numpy as np

import sfx
import synth as s


def _env_curve(points):
    """Piecewise-linear density envelope over p in [0, 1]: points = [(p, value), …]."""
    ps = [p for p, _ in points]
    vs = [v for _, v in points]
    return lambda p: float(np.interp(p, ps, vs))


def _thud(rng, sr, dur=0.25, lp=180.0, decay=0.05):
    n = s.secs(sr, dur)
    return s.lowpass(rng.standard_normal(n), sr, lp, 2) * s.env_ad(sr, n, 0.003, decay)


def _jitter(rng, sr, n, rate=30.0):
    """Slow positive roughness in [0.4, 1] (tines catching, bristles)."""
    j = np.abs(s.lowpass(rng.standard_normal(n), sr, rate, 2))
    return 0.4 + 0.6 * j / (np.max(j) + 1e-12)


# --- grave care (player and Jakob) --------------------------------------------------------

def rake_leaves(rng, sr):
    """A rake pulled towards the body: tines land with a light tap, scrape the soil, leaves rustle along."""
    dur = 0.95
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    a, b = rng.uniform(0.06, 0.1), rng.uniform(0.7, 0.82)
    stroke = np.clip((t - a) / 0.12, 0, 1) * np.clip((b - t) / 0.25, 0, 1)
    dens = _env_curve([(0.0, 0.0), (a / dur, 0.2), ((a + 0.12) / dur, 1.0), (b / dur - 0.15, 0.8), (b / dur, 0.0), (1.0, 0.0)])
    leaves = s.grains(rng, sr, dur, 1500, 900, 5200, 0.012, dens)
    scrape = s.bandpass(rng.standard_normal(n), sr, 1800, 5200) * stroke * _jitter(rng, sr, n, 40.0)
    soil = s.grains(rng, sr, dur, 380, 350, 2200, 0.006, dens)
    tap = s.fit(sfx.wood(rng, sr, 520 * rng.uniform(0.9, 1.1), 0.012, 0.15), n)
    tap = np.roll(tap, s.secs(sr, a - 0.01))
    x = leaves * 0.9 + scrape * 0.12 + soil * 0.5 + tap * 0.35 + s.fit(_thud(rng, sr, 0.15, 160, 0.02), n) * 0.3
    return s.fade(s.normalize(s.lowpass(x, sr, 6000), 0.7), sr, 0.002, 0.08)


def weed_pull(rng, sr):
    """Grip in the leaves, the root holds, tears loose, crumbs of soil fall back."""
    dur = 0.85
    n = s.secs(sr, dur)
    out = np.zeros(n)
    grip = s.grains(rng, sr, 0.25, 900, 1200, 5000, 0.01, lambda p: float(np.sin(np.pi * p)))
    s.mix_at(out, grip, 0, 0.6)
    tear_at = rng.uniform(0.3, 0.38)
    strain = s.grains(rng, sr, 0.14, 500, 250, 1600, 0.004, lambda p: float(p ** 1.5))
    s.mix_at(out, strain, s.secs(sr, tear_at - 0.14), 0.5)
    tear = s.grains(rng, sr, 0.08, 4000, 300, 2800, 0.003, lambda p: float(np.exp(-p * 3)))
    s.mix_at(out, tear, s.secs(sr, tear_at), 1.0)
    s.mix_at(out, _thud(rng, sr, 0.2, 200, 0.03), s.secs(sr, tear_at), 0.6)
    crumbs = s.grains(rng, sr, 0.4, 600, 700, 4000, 0.005, lambda p: float(np.exp(-p * 4)))
    s.mix_at(out, crumbs, s.secs(sr, tear_at + 0.06), 0.45)
    return s.fade(s.normalize(s.lowpass(out, sr, 5500), 0.7), sr, 0.002, 0.08)


def water_pour(rng, sr):
    """The watering can's rose: a soft shower on leaves and soil, a few drops at the end."""
    dur = rng.uniform(1.3, 1.5)
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    env = np.clip(t / 0.15, 0, 1) * np.clip((dur - 0.25 - t) / 0.3, 0, 1)
    dens = _env_curve([(0.0, 0.0), (0.15 / dur, 1.0), ((dur - 0.55) / dur, 1.0), ((dur - 0.25) / dur, 0.0), (1.0, 0.0)])
    shower = s.grains(rng, sr, dur, 3200, 700, 4200, 0.004, dens)
    stream = s.bandpass(s.pink(rng, n), sr, 500, 2600) * env * (0.85 + 0.15 * _jitter(rng, sr, n, 6.0))
    out = shower * 0.7 + stream * 0.25
    for _ in range(int(rng.integers(8, 14))):
        bn = s.secs(sr, 0.03)
        f = rng.uniform(1100, 2400)
        drop = s.sine(sr, bn, np.linspace(f, f * 1.5, bn)) * s.env_ad(sr, bn, 0.001, 0.008)
        s.mix_at(out, drop, s.secs(sr, rng.uniform(0.1, dur - 0.1)), rng.uniform(0.03, 0.09))
    tail = s.grains(rng, sr, 0.3, 40, 1200, 4000, 0.004)
    s.mix_at(out, tail, s.secs(sr, dur - 0.32), 0.4)
    return s.fade(s.normalize(s.lowpass(out, sr, 5500), 0.6), sr, 0.03, 0.12)


def barrel_fill(rng, sr):
    """The can dipped into the rain barrel: a splash, the water gulping in (rising as it fills), a drip."""
    dur = 1.9
    n = s.secs(sr, dur)
    out = np.zeros(n)
    splash = s.noise_burst(rng, sr, 0.3, 300, 3000, 0.003, 0.08)
    s.mix_at(out, splash, 0, 0.8)
    t0 = 0.12
    k = 0
    while t0 < 1.45:
        p = t0 / 1.45
        f = 230 + 330 * p + rng.uniform(-15, 15)
        gn = s.secs(sr, 0.07)
        glug = s.sine(sr, gn, np.linspace(f * 0.9, f * 1.15, gn)) * s.env_ad(sr, gn, 0.004, 0.02)
        glug += s.bandpass(rng.standard_normal(gn), sr, f, f * 3) * s.env_ad(sr, gn, 0.002, 0.01) * 0.3
        s.mix_at(out, glug, s.secs(sr, t0), rng.uniform(0.5, 0.9) * (1.0 - 0.3 * p))
        t0 += rng.uniform(0.08, 0.13)
        k += 1
    bubbles = s.grains(rng, sr, 1.4, 120, 500, 2500, 0.01)
    s.mix_at(out, bubbles, s.secs(sr, 0.1), 0.25)
    drip = s.sine(sr, s.secs(sr, 0.05), np.linspace(900, 1500, s.secs(sr, 0.05))) * s.env_ad(sr, s.secs(sr, 0.05), 0.001, 0.01)
    s.mix_at(out, drip, s.secs(sr, 1.7), 0.25)
    out = out * 0.75 + 0.25 * s.resonator(out, sr, 170, 2.5)
    return s.fade(s.normalize(s.lowpass(out, sr, 5000), 0.65), sr, 0.002, 0.15)


def match_strike(rng, sr):
    """Scrape of the match head, the small flare, a quiet burning – no sizzle."""
    dur = 1.15
    n = s.secs(sr, dur)
    out = np.zeros(n)
    sl = rng.uniform(0.09, 0.13)
    scrape = s.grains(rng, sr, sl, 2800, 1800, 6500, 0.002, lambda p: float(np.sin(np.pi * p) ** 0.5))
    s.mix_at(out, scrape, s.secs(sr, 0.02), 0.6)
    fl = s.secs(sr, 0.5)
    flare = s.bandpass(rng.standard_normal(fl), sr, 900, 5000) * s.env_ad(sr, fl, 0.012, 0.12)
    s.mix_at(out, flare, s.secs(sr, 0.02 + sl * 0.8), 0.55)
    s.mix_at(out, _thud(rng, sr, 0.3, 380, 0.06), s.secs(sr, 0.02 + sl * 0.8), 0.6)
    bn = s.secs(sr, 0.6)
    burn = s.bandpass(rng.standard_normal(bn), sr, 600, 3000) * s.env_asr(sr, bn, 0.05, 0.4) * 0.12
    burn += s.grains(rng, sr, 0.6, 25, 1500, 5000, 0.003) * 0.3
    s.mix_at(out, burn, s.secs(sr, 0.45))
    return s.fade(s.normalize(s.lowpass(out, sr, 7000), 0.6), sr, 0.002, 0.12)


def candle_glass(rng, sr):
    """The grave lantern's little door: a tin hinge, the glass shut with a soft clink, set on the stone."""
    dur = 0.75
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, sfx._creak(rng, sr, 0.16, 140, 220, 0.3), 0, 0.12)
    gl = s.secs(sr, 0.45)
    f0 = rng.uniform(2300, 2700)
    clink = s.partials(sr, gl, f0, [1, 1.52, 2.21, 2.93], [0.4, 0.28, 0.16, 0.08], [0.11, 0.08, 0.05, 0.035], rng)
    s.mix_at(out, clink, s.secs(sr, 0.18), 0.5)
    tap = s.partials(sr, s.secs(sr, 0.2), 640 * rng.uniform(0.9, 1.1), [1, 1.7, 2.6], [0.4, 0.2, 0.08], [0.025, 0.015, 0.01], rng)
    s.mix_at(out, tap, s.secs(sr, 0.36), 0.6)
    s.mix_at(out, _thud(rng, sr, 0.15, 260, 0.02), s.secs(sr, 0.36), 0.5)
    return s.fade(s.normalize(s.lowpass(out, sr, 7000), 0.55), sr, 0.002, 0.1)


def broom_sweep(rng, sr):
    """A birch broom over the gravel path in front of the hut."""
    dur = 0.8
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    stroke = np.sin(np.pi * np.clip((t - 0.05) / 0.6, 0, 1)) ** 1.3
    swish = s.bandpass(rng.standard_normal(n), sr, 1400, 5200) * stroke * _jitter(rng, sr, n, 60.0)
    grit = s.grains(rng, sr, dur, 700, 1500, 6000, 0.003, lambda p: float(np.sin(np.pi * np.clip((p * dur - 0.05) / 0.6, 0, 1))))
    x = swish * 0.35 + grit * 0.6
    return s.fade(s.normalize(s.lowpass(x, sr, 6000), 0.55), sr, 0.01, 0.1)


def mortsafe_set(rng, sr):
    """Iron on earth: the grave grille lowered, a dull clank, a second smaller contact, grit."""
    dur = 1.5
    n = s.secs(sr, dur)
    out = np.zeros(n)
    hit = 0.08
    for k, (at, g) in enumerate(((hit, 1.0), (hit + rng.uniform(0.12, 0.18), 0.45))):
        f0 = 410 * rng.uniform(0.95, 1.05) * (1.0 + 0.12 * k)
        clank = s.partials(sr, s.secs(sr, 1.0), f0, [1, 2.76, 5.4, 8.9], [0.6, 0.35, 0.2, 0.08],
                           [0.28, 0.14, 0.07, 0.04], rng, detune=0.01)
        s.mix_at(out, clank, s.secs(sr, at), g)
        s.mix_at(out, _thud(rng, sr, 0.3, 150, 0.06), s.secs(sr, at), 1.2 * g)
        s.mix_at(out, s.grains(rng, sr, 0.3, 500, 500, 3500, 0.005, lambda p: float(np.exp(-p * 5))), s.secs(sr, at), 0.4 * g)
    out = s.reverb(out, sr, rng, 0.12, 0.6, 0.15)[:n]
    return s.fade(s.normalize(s.lowpass(out, sr, 4500), 0.75), sr, 0.002, 0.2)


# --- visitors ----------------------------------------------------------------------------

def cloth_kneel(rng, sr):
    """A long skirt or coat folding as someone kneels down (or rises): cloth, a soft knee on earth."""
    dur = 0.9
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    env = np.sin(np.pi * np.clip(t / 0.7, 0, 1)) ** 1.4
    base = s.bandpass(rng.standard_normal(n), sr, 400, 2600) * env
    fold = s.grains(rng, sr, dur, 220, 900, 3800, 0.018, lambda p: float(np.sin(np.pi * np.clip(p * dur / 0.7, 0, 1))))
    out = base * 0.5 + fold * 0.5
    s.mix_at(out, _thud(rng, sr, 0.25, 140, 0.05), s.secs(sr, rng.uniform(0.32, 0.42)), 1.2)
    return s.fade(s.normalize(s.lowpass(out, sr, 3500), 0.5), sr, 0.03, 0.12)


def flowers_lay(rng, sr):
    """Dry heather or straw flowers laid on the grave: crisp stems, paper-thin petals, set down softly."""
    dur = 0.85
    n = s.secs(sr, dur)
    out = s.grains(rng, sr, dur, 700, 1600, 6000, 0.008, _env_curve([(0, 0), (0.1, 1), (0.55, 0.7), (0.8, 0), (1, 0)]))
    for _ in range(int(rng.integers(3, 6))):
        c = s.noise_burst(rng, sr, 0.02, 2500, 7000, 0.0005, 0.003)
        s.mix_at(out, c, s.secs(sr, rng.uniform(0.05, 0.5)), rng.uniform(0.2, 0.5))
    s.mix_at(out, _thud(rng, sr, 0.2, 200, 0.025), s.secs(sr, 0.55), 0.5)
    return s.fade(s.normalize(s.lowpass(out, sr, 6500), 0.45), sr, 0.01, 0.1)


def mourn_breath(rng, sr):
    """Hinted only: one slow, unvoiced breath out (air, no voice, no pitch) – never a sob."""
    dur = rng.uniform(2.0, 2.4)
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    env = np.clip(t / 0.35, 0, 1) ** 1.5 * np.exp(-np.maximum(t - 0.35, 0) / 0.55)
    air = s.pink(rng, n)
    x = s.bandpass(air, sr, 250, 1600) * 0.6 + 0.4 * s.resonator(s.bandpass(air, sr, 300, 2500), sr, 650, 2.0)
    x = x * env
    return s.fade(s.normalize(s.lowpass(x, sr, 2200), 0.35), sr, 0.1, 0.4)


def coins_stone(rng, sr):
    """A few coins laid on the grave stone (or taken from it): short clicks on stone, barely ringing."""
    dur = 0.85
    n = s.secs(sr, dur)
    out = np.zeros(n)
    t0 = 0.02
    for i in range(int(rng.integers(2, 4))):
        t0 += rng.uniform(0.07, 0.17)
        cn = s.secs(sr, 0.2)
        f0 = rng.uniform(3600, 5000)
        ring = s.partials(sr, cn, f0, [1, 1.47, 2.09], [0.35, 0.22, 0.1], [0.035, 0.025, 0.015], rng)
        click = s.noise_burst(rng, sr, 0.03, 1500, 7000, 0.0003, 0.003)
        stone = s.partials(sr, cn, 1150 * rng.uniform(0.9, 1.1), [1, 1.8], [0.3, 0.1], [0.012, 0.008], rng)
        s.mix_at(out, ring + s.fit(click, cn) * 0.8 + stone, s.secs(sr, t0), rng.uniform(0.6, 1.0))
    slide = s.bandpass(rng.standard_normal(s.secs(sr, 0.12)), sr, 2500, 7000) * s.env_asr(sr, s.secs(sr, 0.12), 0.03, 0.06)
    s.mix_at(out, slide, s.secs(sr, t0 + 0.05), 0.08)
    return s.fade(s.normalize(s.lowpass(out, sr, 8500), 0.5), sr, 0.0005, 0.1)


def chatter_murmur(rng, sr):
    """Two people talking a few steps away – formant-filtered air in syllables, no words."""
    dur = rng.uniform(1.3, 1.7)
    n = s.secs(sr, dur)
    out = np.zeros(n)
    tcur = 0.05
    for voice in range(2):
        f1 = rng.uniform(380, 600) * (1.0 if voice == 0 else 0.8)
        f2 = rng.uniform(1100, 1700)
        src = s.pink(rng, n)
        v = s.bandpass(src, sr, f1 * 0.7, f1 * 1.4) + 0.45 * s.bandpass(src, sr, f2 * 0.8, f2 * 1.25)
        syll = np.zeros(n)
        k = tcur
        end = tcur + rng.uniform(0.45, 0.7)
        while k < min(end, dur - 0.15):
            ln = rng.uniform(0.08, 0.2)
            sn = s.secs(sr, ln)
            syll_shape = np.sin(np.pi * np.linspace(0, 1, sn)) ** 1.5 * rng.uniform(0.4, 1.0)
            s.mix_at(syll, syll_shape, s.secs(sr, k))
            k += ln + rng.uniform(0.0, 0.07)
        out += v * syll
        tcur = k + rng.uniform(0.1, 0.25)
    return s.fade(s.normalize(s.lowpass(out, sr, 2600), 0.4), sr, 0.02, 0.15)


# --- the apprentice ----------------------------------------------------------------------

# Three short tunes of his own (D major pentatonic, no known song): (semitones above A5, beats).
WHISTLE_TUNES = (
    [(0, 1), (2, 1), (5, 0.5), (2, 0.5), (0, 1), (-3, 1), (0, 2)],
    [(-3, 0.5), (0, 0.5), (2, 1), (4, 1), (2, 0.5), (0, 0.5), (2, 2)],
    [(5, 1), (4, 0.5), (2, 0.5), (0, 1), (2, 0.5), (-3, 0.5), (-5, 1), (-3, 2)],
)


def _whistle(rng, sr, tune, beat=0.24):
    total = sum(b for _, b in tune) * beat + 0.4
    n = s.secs(sr, total)
    f = np.zeros(n)
    amp = np.zeros(n)
    tcur = 0.05
    base = 880.0 * rng.uniform(0.97, 1.03)
    for semi, b in tune:
        i0 = s.secs(sr, tcur)
        i1 = min(n, s.secs(sr, tcur + b * beat))
        f[i0:i1] = base * 2 ** (semi / 12.0)
        seg = i1 - i0
        a = np.ones(seg)
        k = min(seg // 3, s.secs(sr, 0.03))
        a[:k] = np.linspace(0.35, 1.0, k)
        a[-k:] = np.linspace(1.0, 0.55, k)
        amp[i0:i1] = a
        tcur += b * beat
    f[: s.secs(sr, 0.05)] = f[s.secs(sr, 0.05)]
    f[s.secs(sr, tcur):] = f[s.secs(sr, tcur) - 1]
    f = s.lowpass(f, sr, 28, 2)                     # glides between the notes
    t = s.tline(sr, n)
    f *= 1.0 + 0.006 * np.sin(s.TAU * 5.4 * t)
    amp = s.lowpass(amp, sr, 40, 2)
    tone = s.sine(sr, n, f) + 0.04 * s.sine(sr, n, 2 * f)
    breath = s.bandpass(rng.standard_normal(n), sr, 700, 3000) * 0.08
    x = (tone * 0.9 + breath) * np.clip(amp, 0, 1)
    x = s.reverb(x, sr, rng, 0.18, 0.8, 0.2)[:n]
    return s.fade(s.normalize(x, 0.4), sr, 0.03, 0.2)


# Jakob whistling to himself: build_audio gives each of the three variants its own tune.
def whistle_tune_a(rng, sr):
    return _whistle(rng, sr, WHISTLE_TUNES[0])


def whistle_tune_b(rng, sr):
    return _whistle(rng, sr, WHISTLE_TUNES[1])


def whistle_tune_c(rng, sr):
    return _whistle(rng, sr, WHISTLE_TUNES[2])


def _tin(rng, sr, f0, dur=0.6, g=1.0):
    return s.partials(sr, s.secs(sr, dur), f0, [1, 1.59, 2.37, 3.11, 4.4], [0.5, 0.35, 0.22, 0.12, 0.06],
                      [0.16, 0.11, 0.07, 0.05, 0.03], rng, detune=0.01) * g


def _coin_drop(rng, sr, into_f, hits=3):
    """A coin dropping into a tin vessel: the first hit, two or three smaller bounces."""
    n = s.secs(sr, 0.9)
    out = np.zeros(n)
    t0 = 0.02
    gap = rng.uniform(0.09, 0.13)
    for k in range(hits):
        g = 0.85 ** k * (1.0 if k == 0 else 0.5)
        s.mix_at(out, _tin(rng, sr, into_f * rng.uniform(0.98, 1.02)), s.secs(sr, t0), g)
        coin = s.partials(sr, s.secs(sr, 0.15), rng.uniform(3800, 5000), [1, 1.47], [0.3, 0.15], [0.03, 0.02], rng)
        s.mix_at(out, coin, s.secs(sr, t0), 0.4 * g)
        s.mix_at(out, s.noise_burst(rng, sr, 0.02, 2000, 7000, 0.0003, 0.002), s.secs(sr, t0), 0.5 * g)
        t0 += gap
        gap *= 0.65
    return out


def tin_cup(rng, sr):
    """Alms: a coin into Veit's tin cup."""
    out = _coin_drop(rng, sr, rng.uniform(1650, 1900), int(rng.integers(3, 5)))
    return s.fade(s.normalize(s.lowpass(out, sr, 8000), 0.5), sr, 0.0005, 0.12)


def wage_tin(rng, sr):
    """Jakob's wage: three coins counted into the tin box, the lid snaps shut."""
    n = s.secs(sr, 1.3)
    out = np.zeros(n)
    t0 = 0.0
    for _ in range(3):
        s.mix_at(out, _coin_drop(rng, sr, rng.uniform(1250, 1400), 2), s.secs(sr, t0), 0.8)
        t0 += rng.uniform(0.2, 0.26)
    lid = s.partials(sr, s.secs(sr, 0.3), 2350, [1, 1.6, 2.5], [0.4, 0.25, 0.1], [0.04, 0.025, 0.015], rng)
    s.mix_at(out, lid + s.fit(_thud(rng, sr, 0.15, 300, 0.015), lid.size) * 0.6, s.secs(sr, t0 + 0.2), 0.8)
    return s.fade(s.normalize(s.lowpass(out, sr, 8000), 0.5), sr, 0.0005, 0.12)


def chalk_write(rng, sr):
    """Chalk on the slate board: a touch, three or four short strokes – dry, never squeaking."""
    dur = 0.9
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, s.partials(sr, s.secs(sr, 0.05), 2600, [1, 2.2], [0.3, 0.1], [0.008, 0.004], rng), s.secs(sr, 0.02), 0.6)
    t0 = 0.05
    for _ in range(int(rng.integers(3, 5))):
        ln = rng.uniform(0.09, 0.17)
        sn = s.secs(sr, ln)
        stroke = s.bandpass(rng.standard_normal(sn), sr, 1400, 4800) * np.sin(np.pi * np.linspace(0, 1, sn)) ** 0.8
        stroke *= _jitter(rng, sr, sn, 120.0)
        s.mix_at(out, stroke, s.secs(sr, t0), rng.uniform(0.5, 1.0))
        t0 += ln + rng.uniform(0.04, 0.1)
        if t0 > dur - 0.2:
            break
    return s.fade(s.normalize(s.lowpass(out, sr, 5500), 0.4), sr, 0.002, 0.08)


# --- the wanderers -----------------------------------------------------------------------

def _kiepe_bells(rng, sr, n, at, gain, wrap=False, dst=None):
    """The little bells on Hanne's basket, struck once: two or three of four bells."""
    out = dst if dst is not None else np.zeros(n)
    tunes = (2637.0, 3136.0, 3520.0, 3951.0)
    for f in rng.choice(tunes, size=int(rng.integers(2, 4)), replace=False):
        bell = s.partials(sr, s.secs(sr, 0.5), f * rng.uniform(0.995, 1.005), [1, 2.1, 2.9], [0.5, 0.18, 0.08],
                          [0.18, 0.08, 0.05], rng)
        s.mix_at(out, bell, int(at + rng.uniform(0, 0.03) * sr), gain * rng.uniform(0.4, 1.0), wrap)
    return out


def kiepe_bells(rng, sr):
    """Loop while Hanne walks: the bells jingle with her steps, the wicker basket creaks along."""
    steps = 12                      # two steps a second; an even count keeps the strong/weak steps across the seam
    period = 0.5
    n = s.secs(sr, steps * period)
    out = np.zeros(n)
    for k in range(steps):
        at = s.secs(sr, k * period + rng.uniform(0.0, 0.02)) % n
        _kiepe_bells(rng, sr, n, at, 0.35 if k % 2 else 0.5, True, out)
        creak = s.grains(rng, sr, 0.12, 900, 300, 1800, 0.004, lambda p: float(np.sin(np.pi * p)))
        s.mix_at(out, creak, (at + s.secs(sr, 0.02)) % n, 0.5, True)
    out = s.loop_filter_band(out, sr, 120, 7000, 1.5)
    return s.normalize(out, 0.5)


def kiepe_set(rng, sr):
    """Hanne sets down (or shoulders) her basket: wicker creak, a thump, the bells shaken."""
    dur = 1.3
    n = s.secs(sr, dur)
    out = np.zeros(n)
    creak = s.grains(rng, sr, 0.45, 1300, 300, 2000, 0.005, lambda p: float(np.sin(np.pi * p)))
    s.mix_at(out, creak, 0, 0.6)
    s.mix_at(out, _thud(rng, sr, 0.35, 170, 0.07), s.secs(sr, 0.42), 1.3)
    for k in range(3):
        _kiepe_bells(rng, sr, n, s.secs(sr, 0.4 + k * 0.09), 0.5 * 0.7 ** k, False, out)
    return s.fade(s.normalize(s.lowpass(out, sr, 8000), 0.6), sr, 0.002, 0.15)


# --- the night ---------------------------------------------------------------------------

def spade_night(rng, sr):
    """The robber's spade: the gravekeeper's dig, but hasty, muffled and further off."""
    x = sfx.dig(rng, sr)
    x = s.lowpass(x, sr, 1900, 2)
    x = x * 0.8 + 0.2 * s.resonator(x, sr, 240, 1.5)
    return s.fade(s.normalize(x, 0.7), sr, 0.002, 0.05)


def run_gravel(rng, sr):
    """A hurried step on the gravel path: harder heel, a spray of grit."""
    n = s.secs(sr, 0.22)
    heel = s.lowpass(rng.standard_normal(n), sr, 320, 2) * s.env_ad(sr, n, 0.002, 0.025)
    grit = s.grains(rng, sr, 0.22, 1300, 1200, 6500, 0.004, lambda p: float(np.exp(-p * 7)))
    spray = s.grains(rng, sr, 0.22, 300, 2000, 7000, 0.003, lambda p: float(np.exp(-abs(p - 0.25) * 10)))
    x = heel * 1.2 + grit * 0.75 + spray * 0.35
    return s.fade(s.normalize(s.lowpass(x, sr, 6500), 0.75), sr, 0.0005, 0.03)


def climb_wall(rng, sr):
    """Over the wall: hands grip the stone, boots scrape, cloth, a drop on the other side."""
    dur = 1.9
    n = s.secs(sr, dur)
    out = np.zeros(n)
    for at in (0.02, 0.28):
        grip = s.grains(rng, sr, 0.18, 1500, 800, 5000, 0.004, lambda p: float(np.exp(-p * 4)))
        s.mix_at(out, grip, s.secs(sr, at), 0.6)
        s.mix_at(out, _thud(rng, sr, 0.15, 400, 0.02), s.secs(sr, at), 0.4)
    scr = s.secs(sr, 0.5)
    scrape = s.bandpass(rng.standard_normal(scr), sr, 600, 3500) * s.env_asr(sr, scr, 0.08, 0.2) * _jitter(rng, sr, scr, 25)
    s.mix_at(out, scrape, s.secs(sr, 0.45), 0.35)
    s.mix_at(out, sfx.cloth(rng, sr), s.secs(sr, 0.6), 0.5)
    land = 1.35 + rng.uniform(-0.05, 0.05)
    s.mix_at(out, _thud(rng, sr, 0.4, 150, 0.08), s.secs(sr, land), 1.6)
    s.mix_at(out, s.grains(rng, sr, 0.3, 700, 800, 4500, 0.006, lambda p: float(np.exp(-p * 6))), s.secs(sr, land), 0.5)
    return s.fade(s.normalize(s.lowpass(out, sr, 5500), 0.7), sr, 0.002, 0.15)


def knock_door(rng, sr):
    """Three knocks at a house door at night – knuckles on oak, the door panel answering."""
    dur = 1.2
    n = s.secs(sr, dur)
    out = np.zeros(n)
    f0 = rng.uniform(120, 140)
    gaps = (0.0, rng.uniform(0.24, 0.28), rng.uniform(0.5, 0.56))
    for k, at in enumerate(gaps):
        hit = s.fit(sfx.wood(rng, sr, f0 * rng.uniform(0.97, 1.03), 0.05, 0.35, 0.4), s.secs(sr, 0.4))
        hit += _thud(rng, sr, 0.4, 240, 0.03)[: hit.size] * 0.8
        s.mix_at(out, hit, s.secs(sr, 0.03 + at), (1.0, 0.85, 0.95)[k])
    out = out * 0.7 + 0.3 * s.resonator(out, sr, 95, 3.0)
    out = s.reverb(out, sr, rng, 0.2, 0.9, 0.25)[:n]
    return s.fade(s.normalize(s.lowpass(out, sr, 4500), 0.75), sr, 0.002, 0.2)


def _horn(rng, sr, f0, dur, swell=0.35):
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    bend = 1.0 - 0.04 * np.exp(-t / 0.08)
    f = f0 * bend * (1.0 + 0.003 * np.sin(s.TAU * 4.5 * t))
    ph = np.cumsum(s.TAU * f / sr)
    x = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.55), (3, 0.35), (4, 0.18), (5, 0.1), (6, 0.05)):
        x += a * np.sin(k * ph)
    x += s.bandpass(rng.standard_normal(n), sr, f0 * 2, f0 * 6) * 0.05
    env = np.clip(t / swell, 0, 1) ** 1.3 * np.clip((dur - t) / 0.35, 0, 1)
    return x * env


def watchman_call(rng, sr):
    """The night watchman's horn from the village far below: two long notes (no voice)."""
    dur = 4.6
    n = s.secs(sr, dur)
    out = np.zeros(n)
    s.mix_at(out, _horn(rng, sr, 196.0, 1.3), s.secs(sr, 0.05), 0.9)
    s.mix_at(out, _horn(rng, sr, 293.7, 1.8, 0.25), s.secs(sr, 1.55), 1.0)
    out = s.lowpass(out, sr, 1500, 2)
    out = s.reverb(out, sr, rng, 0.55, 3.0, 0.9, 3000)[:n]
    return s.fade(s.normalize(out, 0.5), sr, 0.05, 0.8)


# --- story -------------------------------------------------------------------------------

def chapter_who(rng, sr):
    """Chapter „Wer heraufkommt": a line that climbs step by step (someone coming up the hill), a pad
    opening from D to G, a quiet bowed tone underneath (the lights) – then rest."""
    dur = 7.5
    n = s.secs(sr, dur)
    out = s.fit(s.pad_tone(sr, [146.8, 220.0, 293.7], 3.6, rng, 1.2, 1.8, 0.5), n) * 0.7
    s.mix_at(out, s.pad_tone(sr, [196.0, 246.9, 293.7, 392.0], 4.4, rng, 1.6, 2.4, 0.5), s.secs(sr, 2.9), 0.75)
    line = (293.7, 329.6, 370.0, 440.0, 493.9, 587.3)
    for i, f in enumerate(line):
        p = s.pluck(sr, f, 3.0, rng, 0.42)
        s.mix_at(out, p, s.secs(sr, 0.3 + i * 0.42 + (0.15 if i == 5 else 0.0)), 0.34 if i < 5 else 0.3)
    s.mix_at(out, s.fit(_bowed(rng, sr, 196.0, 4.6, 1.4, 0.003, 0.35), s.secs(sr, 4.6)), s.secs(sr, 2.9), 0.22)
    out = s.reverb(out, sr, rng, 0.35, 2.4, 0.75)[:n]
    return s.fade(s.normalize(out, 0.5), sr, 0.02, 1.2)


# --- bowed strings (fiddle at the dance, slow strings at the lights) ---------------------

def _bowed(rng, sr, f0, dur, attack=0.06, vib=0.004, bright=0.5, release=0.12, vib_delay=0.18):
    """A bowed string: saw-like partials, delayed vibrato, a little bow noise, wooden body resonances."""
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    vdepth = vib * np.clip((t - vib_delay) / 0.25, 0, 1)
    f = f0 * (1.0 + vdepth * np.sin(s.TAU * rng.uniform(5.2, 5.9) * t + rng.uniform(0, 6)))
    ph = np.cumsum(s.TAU * f / sr) + rng.uniform(0, 6)
    x = np.zeros(n)
    for k in range(1, 16):
        if f0 * k > sr * 0.42:
            break
        x += (1.0 / k ** (1.5 - bright * 0.6)) * np.sin(k * ph)
    bow = s.bandpass(rng.standard_normal(n), sr, 1800, 5500) * 0.03 * (0.6 + 0.4 * _jitter(rng, sr, n, 15))
    x = x + bow
    body = 0.55 * x + 0.3 * s.resonator(x, sr, 290, 2.5) + 0.2 * s.resonator(x, sr, 480, 3.0) + 0.12 * s.resonator(x, sr, 2900, 2.0)
    env = np.clip(t / max(attack, 1e-3), 0, 1) ** 1.2 * np.clip((dur - t) / max(release, 1e-3), 0, 1)
    return s.lowpass(body * env, sr, 5200, 2)


def _clap(rng, sr, g=1.0):
    """One soft hand clap of a few people (slightly spread)."""
    n = s.secs(sr, 0.12)
    out = np.zeros(n)
    for _ in range(int(rng.integers(3, 6))):
        b = s.noise_burst(rng, sr, 0.08, 900, 3200, 0.0008, 0.012)
        s.mix_at(out, b, s.secs(sr, rng.uniform(0.0, 0.025)), rng.uniform(0.4, 1.0))
    return out * g


def _stomp(rng, sr, g=1.0):
    n = s.secs(sr, 0.3)
    x = s.lowpass(rng.standard_normal(n), sr, 140, 2) * s.env_ad(sr, n, 0.004, 0.05)
    x += s.fit(sfx.wood(rng, sr, 105 * rng.uniform(0.95, 1.05), 0.05, 0.2, 0.3), n) * 0.5
    return x * g


# D dorian degrees from D4: 0 D4 1 E4 2 F4 3 G4 4 A4 5 B4 6 C5 7 D5 8 E5 9 F5. (degree, beats); 3/4.
_DANCE_A = [
    [(4, 1), (7, 1), (6, 0.5), (5, 0.5)], [(4, 2), (2, 1)], [(3, 1), (4, 1), (5, 1)], [(4, 3)],
    [(4, 1), (7, 1), (8, 0.5), (7, 0.5)], [(6, 1), (5, 1), (4, 1)], [(3, 1), (2, 0.5), (1, 0.5), (2, 1)], [(0, 3)],
]
_DANCE_A2 = _DANCE_A[:4] + [
    [(4, 1), (7, 1), (9, 0.5), (8, 0.5)], [(7, 1.5), (6, 0.5), (5, 1)], [(4, 1), (3, 1), (1, 1)], [(0, 2), (4, 1)],
]
_DANCE_B = [
    [(2, 1), (4, 1), (6, 1)], [(7, 2), (6, 1)], [(5, 1), (6, 0.5), (5, 0.5), (4, 1)], [(3, 3)],
    [(2, 1), (4, 1), (6, 1)], [(9, 2), (8, 1)], [(7, 1), (6, 1), (5, 1)], [(4, 2), (None, 1)],
]
_DANCE_CODA = [[(4, 1), (3, 1), (2, 1)], [(1, 1), (2, 1), (1, 1)], [(0, 3)], [(0, 3)]]
# Chord roots (MIDI) and qualities per bar.
_CH = {"Dm": (50, (0, 3, 7)), "C": (48, (0, 4, 7)), "Am": (45, (0, 3, 7)), "G": (43, (0, 4, 7)), "F": (41, (0, 4, 7))}
_CH_A = ["Dm", "Dm", "C", "Am", "Dm", "C", "G", "Dm"]
_CH_B = ["F", "Dm", "C", "G", "F", "Dm", "C", "Am"]
_CH_CODA = ["Dm", "G", "Dm", "Dm"]
_DORIAN = [0, 2, 3, 5, 7, 9, 10]


def _deg_hz(d: int, root: int = 62) -> float:
    o, i = divmod(d, 7)
    return 440.0 * 2 ** ((root + 12 * o + _DORIAN[i] - 69) / 12.0)


def mus_dance(rng, sr):
    """Kathreintanz: a fiddle tune of our own in 3/4 (D dorian, 120 bpm) – lively, but in a minor mode –
    over an open-string drone, a lute on the beats and the room clapping on two and three."""
    beat = 0.5
    bar = beat * 3
    form = [(_DANCE_A, _CH_A), (_DANCE_A2, _CH_A), (_DANCE_B, _CH_B), (_DANCE_A2, _CH_A), (_DANCE_CODA, _CH_CODA)]
    bars = sum(len(m) for m, _ in form)
    total = bars * bar + 4.0
    n = s.secs(sr, total)
    left = np.zeros(n)
    right = np.zeros(n)

    def put(x, t, gain, pan):
        st = s.stereo(x * gain, pan)
        i = s.secs(sr, t)
        s.mix_at(left, st[:, 0], i)
        s.mix_at(right, st[:, 1], i)

    b = 0
    for section, (melody, chords) in enumerate(form):
        for k, notes in enumerate(melody):
            t_bar = b * bar
            last = b == bars - 1
            fade_in = min(1.0, (b + 1) / 1.5)
            # fiddle
            tc = t_bar
            for deg, beats in notes:
                d = beats * beat
                if deg is not None:
                    f = _deg_hz(deg)
                    note = _bowed(rng, sr, f, d + 0.06, 0.035, 0.0045, 0.55, 0.06, 0.12)
                    accent = 1.0 if abs(tc - t_bar) < 1e-6 else 0.8
                    put(note, tc + rng.uniform(-0.006, 0.006), 0.42 * accent * fade_in, -0.15)
                tc += d
            # drone (open D and A, low) every bar, swelling a little on the downbeat
            if not last:
                dr = _bowed(rng, sr, 146.83, bar + 0.1, 0.12, 0.0015, 0.3, 0.15, 0.4)
                dr += _bowed(rng, sr, 220.0, bar + 0.1, 0.12, 0.0015, 0.3, 0.15, 0.4) * 0.6
                put(dr, t_bar, 0.12 * fade_in, 0.05)
            # lute: bass on one, chord on two and three
            root, q = _CH[chords[k]]
            put(s.pluck(sr, 440.0 * 2 ** ((root - 12 - 69) / 12.0) * 2, 1.6, rng, 0.35, 0.4), t_bar, 0.5 * fade_in, 0.3)
            if not last:
                for bt in (1, 2):
                    for j, iv in enumerate(q):
                        m = root + 12 + iv
                        p = s.pluck(sr, 440.0 * 2 ** ((m - 69) / 12.0), 0.9, rng, 0.45)
                        put(p, t_bar + bt * beat + j * 0.012, 0.16 * fade_in, 0.35)
            # the room: a stomp on one, claps on two and three (not in the first two bars and the end)
            if 2 <= b < bars - 2:
                put(_stomp(rng, sr), t_bar + rng.uniform(-0.01, 0.01), 0.35, rng.uniform(-0.3, 0.3))
                for bt in (1, 2):
                    put(_clap(rng, sr), t_bar + bt * beat + rng.uniform(-0.012, 0.012), 0.12, rng.uniform(-0.6, 0.6))
            b += 1
    mixl = s.reverb(left, sr, rng, 0.25, 1.4, 0.4, 5000)
    mixr = s.reverb(right, sr, rng, 0.25, 1.4, 0.4, 5000)
    m = min(mixl.size, mixr.size)
    out = np.stack([mixl[:m], mixr[:m]], axis=1)[: s.secs(sr, total)]
    k = s.secs(sr, 3.0)
    out[-k:] *= np.linspace(1.0, 0.0, k)[:, None] ** 2
    return out / (np.max(np.abs(out)) + 1e-12) * 0.6


# Lichtgang: (chord tones MIDI, seconds) – D aeolian, slow.
_LIGHTS = [((50, 57, 62, 65), 7.0), ((46, 53, 58, 62), 7.0), ((41, 53, 57, 60), 7.0), ((48, 55, 60, 64), 7.0),
           ((50, 57, 62, 65), 7.0), ((43, 55, 58, 62), 7.0), ((45, 52, 57, 61), 8.0), ((50, 57, 62, 69), 10.0)]
# A slow line above (MIDI, start within the chord, length) – a few long notes, no tune to hum.
_LIGHTS_LINE = {1: [(70, 1.0, 5.0)], 2: [(69, 0.5, 5.5)], 3: [(67, 1.0, 3.0), (64, 4.0, 2.8)], 5: [(70, 1.5, 4.5)],
                6: [(69, 0.5, 4.0), (73, 4.5, 3.2)], 7: [(74, 1.0, 7.5)]}


def mus_lights(rng, sr):
    """Lichtgang (16:30–18:30): slow bowed tones, quiet, no choir – long string chords in D minor with a
    few sustained notes above, the bow changes softened."""
    total = sum(d for _, d in _LIGHTS) + 6.0
    n = s.secs(sr, total)
    left = np.zeros(n)
    right = np.zeros(n)

    def put(x, t, gain, pan):
        st = s.stereo(x * gain, pan)
        i = s.secs(sr, t)
        s.mix_at(left, st[:, 0], i)
        s.mix_at(right, st[:, 1], i)

    tc = 0.5
    for idx, (tones, d) in enumerate(_LIGHTS):
        for j, m in enumerate(tones):
            f = 440.0 * 2 ** ((m - 69) / 12.0)
            note = _bowed(rng, sr, f, d + 2.0, 1.6, 0.0025, 0.25, 2.0, 0.8)
            put(note, tc + j * 0.15, (0.26 if j == 0 else 0.18), (-0.45, -0.15, 0.15, 0.45)[j])
        for m, at, ln in _LIGHTS_LINE.get(idx, []):
            f = 440.0 * 2 ** ((m - 69) / 12.0)
            put(_bowed(rng, sr, f, ln + 1.2, 0.9, 0.0035, 0.4, 1.2, 0.6), tc + at, 0.2, 0.1)
        tc += d
    mixl = s.reverb(left, sr, rng, 0.45, 3.5, 1.2, 4000)
    mixr = s.reverb(right, sr, rng, 0.45, 3.5, 1.2, 4000)
    m = min(mixl.size, mixr.size)
    out = np.stack([mixl[:m], mixr[:m]], axis=1)[: s.secs(sr, total)]
    k = s.secs(sr, 5.0)
    out[-k:] *= np.linspace(1.0, 0.0, k)[:, None] ** 2
    k = s.secs(sr, 1.5)
    out[:k] *= np.linspace(0.0, 1.0, k)[:, None]
    return out / (np.max(np.abs(out)) + 1e-12) * 0.55


# --- ambience ----------------------------------------------------------------------------

def amb_inn_fest(rng, sr):
    """Gaststube am Kathreintanz (loop, 30 s = 20 bars of 3/4 at 120 bpm): a full room talking without
    words, feet stamping on one, now and then a clap, the fire – the fiddle itself is the music."""
    import ambience as amb
    bar = 1.5
    bars = 20
    n = s.secs(sr, bars * bar)
    x = amb._murmur(rng, sr, n, 15, 1.0) + amb._crackle(rng, sr, n, 4, 0.3) + amb._room_tone(rng, sr, n, 60, 300, 0.35)
    feet = np.zeros(n)
    for b in range(bars):
        at = s.secs(sr, b * bar)
        for _ in range(int(rng.integers(3, 6))):
            st = _stomp(rng, sr, rng.uniform(0.3, 0.8))
            s.mix_at(feet, st, (at + s.secs(sr, rng.uniform(-0.02, 0.03))) % n, 1.0, True)
        if rng.uniform() < 0.35:
            for bt in (1, 2):
                s.mix_at(feet, _clap(rng, sr, 0.25), (at + s.secs(sr, bt * 0.5 + rng.uniform(-0.01, 0.01))) % n, 1.0, True)
    feet = s.loop_filter_band(feet, sr, 40, 5000, 1.5)
    x = x / (np.std(x) + 1e-12) + feet / (np.std(feet) + 1e-12) * 0.55
    return amb._finish(x, sr, rng, 0.5, 0.2, 0.8, 0.25)


def gate_bell(rng, sr):
    """G8 Runde 1 (B8-1): the little bronze bell at the graveyard gate, pulled on its cord when a visitor comes up:
    a dry creak of the cord, then three strokes of a swinging bell (the second a little weaker, the clapper
    catching), each a slightly inharmonic small-bell spectrum, the tail in the open air. ≈ 3.4 s."""
    n = s.secs(sr, 3.4)
    out = np.zeros(n)
    creak = s.grains(rng, sr, 0.18, 700, 250, 1400, 0.006, lambda p: float(np.sin(np.pi * p)))
    s.mix_at(out, creak, 0, 0.25)
    f0 = 1180.0
    for k, (at, gain) in enumerate(((0.12, 1.0), (0.62, 0.7), (1.1, 0.85))):
        ring = s.partials(sr, s.secs(sr, 2.2), f0 * rng.uniform(0.997, 1.003), [1, 2.03, 2.47, 3.11, 4.3, 5.6],
                          [0.6, 0.32, 0.22, 0.12, 0.07, 0.04], [1.1, 0.7, 0.55, 0.4, 0.25, 0.15], rng, attack=0.0015,
                          detune=0.0012)
        tick = s.bandpass(rng.standard_normal(s.secs(sr, 0.02)), sr, 2500, 7000) * 0.15
        s.mix_at(out, ring, s.secs(sr, at), gain)
        s.mix_at(out, tick, s.secs(sr, at), gain)
    out = s.reverb(out, sr, rng, 0.25, 1.6, 0.5)[:n]
    return s.fade(s.normalize(out, 0.6), sr, 0.0005, 0.5)
