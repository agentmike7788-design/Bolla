"""Ambience beds (seamless loops) and the one-shot "spot" sounds the AudioManager scatters
over them (birds, owl, hammer in the distance, drips). Beds are built circularly
(FFT-shaped noise, wrapped events, integer-cycle modulation) so they loop without a seam.
"""
from __future__ import annotations

import numpy as np

import synth as s

LOOP = 24.0
# Outdoor beds loop over 48 s (G7 Runde 2): the gusts of a 24 s loop were recognisable.
LOOP_OUT = 48.0


# --- building blocks ---------------------------------------------------------------------

def gust_curve(rng, n, sr, gust=0.6, slowest=40.0, fastest=4.0):
    """Irregular gust envelope in [1 - gust, 1], periodic over n samples (seamless loops).

    Sum of many integer-cycle components between periods `slowest` and `fastest` seconds with a
    1/f amplitude fall-off and random phases, then a soft saturation: calm stretches, a few
    stronger gusts at irregular spacing – no regular "breathing", never down to silence.
    """
    dur = n / sr
    t = np.arange(n) / n
    k_lo = max(1, int(round(dur / slowest)))
    k_hi = max(k_lo + 1, int(round(dur / fastest)))
    out = np.zeros(n)
    for k in range(k_lo, k_hi + 1):
        out += rng.uniform(0.2, 1.0) / k ** 0.9 * np.sin(s.TAU * k * t + rng.uniform(0, s.TAU))
    out /= np.std(out) + 1e-12
    shaped = 1.0 / (1.0 + np.exp(-1.6 * (out - 0.3)))           # gusts rise softly, calm is longer
    shaped = (shaped - shaped.min()) / (shaped.max() - shaped.min() + 1e-12)
    return 1.0 - gust + gust * shaped


def _delay(x, sr, seconds):
    return np.roll(x, int(seconds * sr))


def _wind(rng, sr, n, strength=1.0, lo=120.0, hi=900.0, gust=0.6, g=None):
    """Natural wind (G7 Runde 2): broadband filtered noise in three bands with gentle slopes – no
    resonant band (the old "whistle" layer is gone) – and one slow, irregular gust curve. Gusts
    swell the body, brighten it a little (the bright band follows the curve squared and a little
    later, as a gust "arrives") and add a low rumble; calm stays soft but never silent."""
    g = gust_curve(rng, n, sr, gust) if g is None else g
    rumble = s.loop_filter_band(s.brown(rng, n), sr, 35.0, lo * 1.2, 1.0)
    body_dark = s.loop_filter_band(s.pink(rng, n), sr, lo, hi * 0.7, 1.0)
    body_bright = s.loop_filter_band(s.pink(rng, n), sr, lo * 1.4, hi * 1.3, 1.0)
    air = s.loop_filter_band(s.pink(rng, n), sr, hi * 1.2, min(hi * 3.0, 4200.0), 1.0)
    gl = _delay(g, sr, 0.35)
    body = body_dark * (1.0 - gl * 0.5) + body_bright * gl * 0.7
    x = rumble * 0.35 * g + body * g + air * 0.06 * gl ** 2
    return x * strength



def _leaves(rng, sr, n, density=600.0, g=None):
    """Leaf rustle: soft grains 1.2–5 kHz (no hiss above), loud only in the gusts of `g`."""
    dur = n / sr
    if g is None:
        mod = s.loop_lfo(rng, sr, n, 6, 0.9) ** 2
    else:
        mod = np.clip((g - g.min()) / (g.max() - g.min() + 1e-12), 0, 1) ** 2.5
    gr = s.grains(rng, sr, dur, density, 1200, 5000, 0.014, wrap=True)
    gr = s.spectral(gr, sr, s.band_gain(1200, 5000, 1.0))
    return gr * mod


def _crickets(rng, sr, n, count=4, level=1.0):
    t = s.tline(sr, n)
    out = np.zeros(n)
    dur = n / sr
    for _ in range(count):
        f = rng.uniform(3900, 5200)
        chirp_rate = round(rng.uniform(1.2, 2.6) * dur) / dur        # chirps per second, loop-exact
        pulse_rate = round(rng.uniform(28, 45) * dur) / dur
        carrier = np.sin(s.TAU * round(f * dur) / dur * t)
        pulses = np.clip(np.sin(s.TAU * pulse_rate * t), 0, 1) ** 3
        gate = (np.sin(s.TAU * chirp_rate * t + rng.uniform(0, 6)) > 0.55).astype(float)
        gate = s.spectral(gate, sr, lambda f_: 1.0 / (1.0 + (f_ / 60.0) ** 4))
        swell = s.loop_lfo(rng, sr, n, 3, 0.7)
        out += carrier * pulses * np.clip(gate, 0, 1) * swell * rng.uniform(0.4, 1.0)
    return out * level


def _murmur(rng, sr, n, voices=6, level=1.0):
    """Abstract distant talk: formant-filtered noise with syllable rhythm – no words."""
    out = np.zeros(n)
    dur = n / sr
    for _ in range(voices):
        src = s.pink(rng, n)
        f1 = rng.uniform(350, 650)
        f2 = rng.uniform(1100, 1900)
        v = s.loop_filter_band(src, sr, f1 * 0.7, f1 * 1.4, 2.0) + 0.5 * s.loop_filter_band(src, sr, f2 * 0.8, f2 * 1.25, 2.5)
        syll = np.zeros(n)
        tcur = rng.uniform(0, dur)
        talk = 0.0
        while talk < dur * rng.uniform(0.35, 0.6):
            phrase = rng.uniform(0.8, 2.6)
            k = 0.0
            while k < phrase:
                ln = rng.uniform(0.09, 0.22)
                sn = s.secs(sr, ln)
                syl = np.sin(np.pi * np.linspace(0, 1, sn)) ** 1.5 * rng.uniform(0.4, 1.0)
                s.mix_at(syll, syl, s.secs(sr, (tcur + k) % dur), 1.0, wrap=True)
                k += ln + rng.uniform(0.0, 0.08)
            talk += phrase
            tcur = (tcur + phrase + rng.uniform(0.6, 3.5)) % dur
        out += v * syll
    out = s.loop_filter_band(out, sr, 200, 2400, 1.5)
    return out * level


def _crackle(rng, sr, n, rate=8.0, level=1.0):
    dur = n / sr
    pops = s.grains(rng, sr, dur, rate * 5, 1200, 9000, 0.0025, wrap=True)
    big = s.grains(rng, sr, dur, rate, 600, 5000, 0.006, wrap=True)
    roar = s.loop_filter_band(s.brown(rng, n), sr, 40, 300) * 0.35 * s.loop_lfo(rng, sr, n, 7, 0.5)
    return (pops * 0.6 + big + roar) * level


def _brook(rng, sr, n, level=1.0):
    dur = n / sr
    bed = s.loop_filter_band(s.pink(rng, n), sr, 350, 4200, 1.5) * s.loop_lfo(rng, sr, n, 11, 0.3)
    bubbles = np.zeros(n)
    for _ in range(int(dur * 38)):
        bn = s.secs(sr, rng.uniform(0.02, 0.06))
        f = rng.uniform(400, 1800)
        b = s.sine(sr, bn, np.linspace(f, f * rng.uniform(1.3, 2.2), bn)) * s.env_ad(sr, bn, 0.002, bn / sr * 0.3)
        s.mix_at(bubbles, b, int(rng.uniform(0, n)), rng.uniform(0.04, 0.2), wrap=True)
    return (bed * 0.8 + bubbles) * level


def _room_tone(rng, sr, n, lo=60.0, hi=400.0, level=1.0):
    return s.loop_filter_band(s.pink(rng, n), sr, lo, hi, 1.5) * level


def _clock(rng, sr, n, level=1.0):
    out = np.zeros(n)
    secs_total = int(round(n / sr))
    for i in range(secs_total):
        tk = s.partials(sr, s.secs(sr, 0.06), 2600 if i % 2 == 0 else 2200, [1, 2.3], [0.5, 0.2], [0.008, 0.005], rng)
        tk += s.bandpass(rng.standard_normal(tk.size), sr, 2500, 7000) * s.env_ad(sr, tk.size, 0.0002, 0.002) * 0.3
        body = s.resonator(tk, sr, 700, 6) * 0.6
        s.mix_at(out, tk + body, s.secs(sr, i * 1.0), 1.0, wrap=True)
    return out * level


def _finish(x, sr, rng, peak, reverb_wet=0.0, reverb_len=1.5, reverb_decay=0.5):
    if reverb_wet > 0:
        x = s.reverb(x, sr, rng, reverb_wet, reverb_len, reverb_decay, circular=True)
    x = s.highpass(np.concatenate([x, x]), sr, 30)[x.size:]          # settled filter state → still seamless
    return s.normalize(x, peak)


# --- beds --------------------------------------------------------------------------------

def amb_graveyard_day(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    g = gust_curve(rng, n, sr, 0.55)
    x = _wind(rng, sr, n, 1.0, 110, 800, g=g) + _leaves(rng, sr, n, 260, g) * 0.12
    return _finish(x, sr, rng, 0.5)


def amb_graveyard_dusk(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    g = gust_curve(rng, n, sr, 0.5)
    x = _wind(rng, sr, n, 0.8, 100, 700, g=g) + _leaves(rng, sr, n, 140, g) * 0.08 + _crickets(rng, sr, n, 2, 0.035)
    return _finish(x, sr, rng, 0.45)


def amb_graveyard_night(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    x = _wind(rng, sr, n, 0.6, 90, 600, 0.5) + _crickets(rng, sr, n, 3, 0.06)
    return _finish(x, sr, rng, 0.45)


def amb_forest_edge(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    g = gust_curve(rng, n, sr, 0.6)
    x = _wind(rng, sr, n, 0.9, 160, 1200, g=g) + _leaves(rng, sr, n, 700, g) * 0.3
    creak = np.zeros(n)
    for _ in range(3):
        cn = s.secs(sr, 1.2)
        f = np.linspace(rng.uniform(140, 200), rng.uniform(110, 160), cn)
        c = s.sine(sr, cn, f) * s.env_asr(sr, cn, 0.4, 0.5) * 0.03
        s.mix_at(creak, s.lowpass(c, sr, 800), int(rng.uniform(0, n)), 1.0, wrap=True)
    return _finish(x + creak, sr, rng, 0.5)


def amb_village_day(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    g = gust_curve(rng, n, sr, 0.45)
    x = (_wind(rng, sr, n, 0.35, 120, 700, g=g) + _murmur(rng, sr, n, 9, 0.3)
         + _brook(rng, sr, n, 0.1) + _leaves(rng, sr, n, 120, g) * 0.06)
    return _finish(x, sr, rng, 0.5, 0.15, 1.2, 0.4)


def amb_village_night(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    x = _wind(rng, sr, n, 0.45, 90, 600, 0.5) + _crickets(rng, sr, n, 3, 0.05) + _brook(rng, sr, n, 0.08)
    return _finish(x, sr, rng, 0.45)


def amb_hut(rng, sr):
    n = s.secs(sr, LOOP)
    x = _crackle(rng, sr, n, 6, 0.9) + _room_tone(rng, sr, n, 50, 250, 0.4) + _wind(rng, sr, n, 0.12, 80, 300, 0.7)
    return _finish(x, sr, rng, 0.45, 0.1, 0.6, 0.2)


def amb_inn(rng, sr):
    n = s.secs(sr, LOOP)
    x = _murmur(rng, sr, n, 9, 0.9) + _crackle(rng, sr, n, 4, 0.35) + _room_tone(rng, sr, n, 60, 300, 0.3)
    return _finish(x, sr, rng, 0.5, 0.2, 0.8, 0.25)


def amb_surgery(rng, sr):
    n = s.secs(sr, LOOP)
    x = _room_tone(rng, sr, n, 60, 500, 0.6) + _crackle(rng, sr, n, 2, 0.15) + _wind(rng, sr, n, 0.1, 80, 300, 0.6)
    return _finish(x, sr, rng, 0.3, 0.15, 0.7, 0.25)


def amb_office(rng, sr):
    n = s.secs(sr, LOOP)
    x = _clock(rng, sr, n, 0.5) + _room_tone(rng, sr, n, 60, 400, 0.35)
    return _finish(x, sr, rng, 0.35, 0.18, 0.8, 0.25)


def amb_chapel(rng, sr):
    n = s.secs(sr, LOOP)
    air = _room_tone(rng, sr, n, 70, 600, 0.6) * s.loop_lfo(rng, sr, n, 3, 0.3)
    hum = sum(np.sin(s.TAU * round(f * LOOP) / LOOP * s.tline(sr, n)) * a for f, a in ((110, 0.02), (165, 0.012), (220, 0.008)))
    x = air + hum + _wind(rng, sr, n, 0.15, 80, 400, 0.6)
    return _finish(x, sr, rng, 0.3, 0.5, 3.0, 1.2)


def amb_crypt(rng, sr):
    n = s.secs(sr, LOOP)
    t = s.tline(sr, n)
    drone = _room_tone(rng, sr, n, 35, 180, 0.8) * s.loop_lfo(rng, sr, n, 2, 0.4)
    drone += np.sin(s.TAU * round(55 * LOOP) / LOOP * t) * 0.02
    drips = np.zeros(n)
    for _ in range(9):
        d = drip(rng, sr)
        s.mix_at(drips, d, int(rng.uniform(0, n)), rng.uniform(0.08, 0.25), wrap=True)
    x = drone + drips
    return _finish(x, sr, rng, 0.35, 0.55, 2.5, 0.9)


def amb_shed(rng, sr):
    n = s.secs(sr, LOOP)
    x = _room_tone(rng, sr, n, 60, 400, 0.4) + _wind(rng, sr, n, 0.35, 90, 500, 0.7)
    return _finish(x, sr, rng, 0.3, 0.1, 0.6, 0.2)


def amb_title(rng, sr):
    n = s.secs(sr, LOOP_OUT)
    x = _wind(rng, sr, n, 0.6, 90, 500, 0.5) + _crickets(rng, sr, n, 2, 0.03)
    return _finish(x, sr, rng, 0.35)


# --- world loops (positional emitters) ---------------------------------------------------

def loop_brook(rng, sr):
    n = s.secs(sr, 12.0)
    return _finish(_brook(rng, sr, n, 1.0), sr, rng, 0.55)


def loop_forge(rng, sr):
    n = s.secs(sr, 10.0)
    x = _crackle(rng, sr, n, 10, 1.0) + s.loop_filter_band(s.brown(rng, n), sr, 30, 160) * 0.5 * s.loop_lfo(rng, sr, n, 4, 0.6)
    return _finish(x, sr, rng, 0.5)


def loop_stove(rng, sr):
    n = s.secs(sr, 10.0)
    return _finish(_crackle(rng, sr, n, 6, 1.0), sr, rng, 0.45)


# --- spots (one-shots scattered by the manager) ------------------------------------------

def bird(rng, sr, kind=0):
    """Small songbird phrases (three kinds), soft and a little distant."""
    out = []
    if kind == 0:   # descending trill
        f = rng.uniform(3600, 4400)
        for i in range(int(rng.integers(5, 9))):
            ln = 0.05
            out.append(s.chirp(sr, f * (1 - 0.03 * i), f * (1 - 0.03 * i) * 0.82, ln, 0.6) * s.env_ad(sr, s.secs(sr, ln), 0.004, 0.02))
            out.append(np.zeros(s.secs(sr, 0.025)))
    elif kind == 1:  # two-note call
        f = rng.uniform(2800, 3400)
        for g in (1.0, 0.84, 1.0, 0.84):
            ln = 0.14
            seg = s.sine(sr, s.secs(sr, ln), f * g * (1 + 0.02 * np.sin(s.TAU * 30 * s.tline(sr, s.secs(sr, ln)))))
            out.append(seg * s.env_asr(sr, seg.size, 0.02, 0.05))
            out.append(np.zeros(s.secs(sr, 0.09)))
    else:            # warble
        ln = rng.uniform(0.7, 1.1)
        nn = s.secs(sr, ln)
        t = s.tline(sr, nn)
        f = 3200 + 700 * np.sin(s.TAU * rng.uniform(9, 14) * t) + 400 * np.sin(s.TAU * 2.1 * t)
        out.append(s.sine(sr, nn, f) * s.env_asr(sr, nn, 0.05, 0.2) * (0.6 + 0.4 * np.abs(np.sin(s.TAU * 6 * t))))
    x = np.concatenate(out)
    x = x + 0.2 * np.roll(x, s.secs(sr, 0.0005)) ** 2
    x = s.reverb(x, sr, rng, 0.3, 1.0, 0.25)
    return s.fade(s.normalize(s.bandpass(x, sr, 1500, 8000), 0.4), sr, 0.002, 0.1)


def bird_a(rng, sr):
    return bird(rng, sr, 0)


def bird_b(rng, sr):
    return bird(rng, sr, 1)


def bird_c(rng, sr):
    return bird(rng, sr, 2)


def crow(rng, sr):
    """A far crow: two hoarse calls, low-passed by distance."""
    parts = []
    for _ in range(int(rng.integers(2, 4))):
        ln = rng.uniform(0.28, 0.36)
        n = s.secs(sr, ln)
        t = s.tline(sr, n)
        f0 = 520 * (1 - 0.15 * t / ln)
        src = np.sign(np.sin(np.cumsum(s.TAU * f0 / sr))) * (1 + 0.6 * rng.standard_normal(n))
        v = s.resonator(src, sr, 1100, 4) + s.resonator(src, sr, 1700, 5) * 0.6
        parts.append(v * s.env_asr(sr, n, 0.03, 0.12))
        parts.append(np.zeros(s.secs(sr, rng.uniform(0.18, 0.3))))
    x = np.concatenate(parts)
    x = s.lowpass(x, sr, 2600)
    x = s.reverb(x, sr, rng, 0.35, 1.5, 0.4)
    return s.fade(s.normalize(x, 0.3), sr, 0.005, 0.2)


def owl(rng, sr):
    """Tawny-owl-like: a long hoo, a pause, then a quavering hu-hoooo. Soft and round."""
    def hoot(ln, f, vib=0.0):
        n = s.secs(sr, ln)
        t = s.tline(sr, n)
        ff = f * (1 + 0.04 * np.sin(np.pi * np.clip(t / ln, 0, 1))) * (1 + vib * np.sin(s.TAU * 9 * t))
        x = s.sine(sr, n, ff) + 0.15 * s.sine(sr, n, ff * 2)
        return x * s.env_asr(sr, n, 0.06, ln * 0.45)
    x = np.concatenate([hoot(0.55, 400), np.zeros(s.secs(sr, 0.9)), hoot(0.14, 380), np.zeros(s.secs(sr, 0.12)),
                        hoot(1.05, 395, 0.025)])
    x += s.lowpass(rng.standard_normal(x.size), sr, 900) * 0.01
    x = s.reverb(x, sr, rng, 0.45, 2.0, 0.6)
    return s.fade(s.normalize(s.lowpass(x, sr, 2000), 0.45), sr, 0.01, 0.4)


def owl_short(rng, sr):
    n = s.secs(sr, 0.7)
    t = s.tline(sr, n)
    x = s.sine(sr, n, 410 * (1 + 0.03 * np.sin(np.pi * t / 0.7))) * s.env_asr(sr, n, 0.07, 0.35)
    x = s.reverb(x, sr, rng, 0.45, 1.8, 0.6)
    return s.fade(s.normalize(s.lowpass(x, sr, 1800), 0.4), sr, 0.01, 0.3)


def chicken(rng, sr):
    parts = []
    for _ in range(int(rng.integers(3, 6))):
        ln = rng.uniform(0.06, 0.12)
        n = s.secs(sr, ln)
        f0 = rng.uniform(380, 520)
        src = np.sign(np.sin(np.cumsum(s.TAU * np.linspace(f0, f0 * 1.15, n) / sr)))
        v = s.resonator(src, sr, 1400, 5) + s.resonator(src, sr, 2600, 6) * 0.5 + s.resonator(src, sr, 700, 4) * 0.4
        parts.append(v * s.env_ad(sr, n, 0.008, ln * 0.4))
        parts.append(np.zeros(s.secs(sr, rng.uniform(0.05, 0.2))))
    x = s.lowpass(np.concatenate(parts), sr, 3500)
    x = s.reverb(x, sr, rng, 0.25, 0.8, 0.25)
    return s.fade(s.normalize(x, 0.3), sr, 0.002, 0.1)


def hammer_far(rng, sr):
    """The smith at work, heard across the green: three anvil strikes, softened by distance."""
    import sfx
    n = s.secs(sr, 2.6)
    out = np.zeros(n)
    t0 = 0.0
    for i in range(int(rng.integers(2, 5))):
        out_hit = sfx.anvil(rng, sr)
        s.mix_at(out, out_hit, s.secs(sr, t0), 1.0 if i % 2 == 0 else 0.7)
        t0 += rng.uniform(0.45, 0.6)
    out = s.lowpass(out, sr, 3000)
    out = s.reverb(out, sr, rng, 0.4, 1.5, 0.4)[:n]
    return s.fade(s.normalize(out, 0.35), sr, 0.001, 0.4)


def cup_clink(rng, sr):
    n = s.secs(sr, 0.6)
    out = np.zeros(n)
    for i in range(int(rng.integers(1, 3))):
        c = s.partials(sr, s.secs(sr, 0.4), rng.uniform(1500, 2400), [1, 2.2, 3.6], [0.4, 0.2, 0.1],
                       [0.08, 0.05, 0.03], rng)
        c += s.lowpass(rng.standard_normal(c.size), sr, 600) * s.env_ad(sr, c.size, 0.001, 0.015) * 0.5
        s.mix_at(out, c, s.secs(sr, i * rng.uniform(0.08, 0.2)), 0.8)
    return s.fade(s.normalize(s.reverb(out, sr, rng, 0.25, 0.8, 0.25)[:n], 0.3), sr, 0.001, 0.1)


def drip(rng, sr):
    n = s.secs(sr, 0.12)
    f = rng.uniform(900, 1600)
    x = s.sine(sr, n, np.linspace(f, f * 2.0, n)) * s.env_ad(sr, n, 0.001, 0.02)
    return s.fade(s.normalize(x, 0.5), sr, 0.0005, 0.02)


def drip_spot(rng, sr):
    x = drip(rng, sr)
    x = s.reverb(x, sr, rng, 0.6, 2.0, 0.7)
    return s.fade(s.normalize(x, 0.3), sr, 0.0005, 0.3)


def wood_creak(rng, sr):
    import sfx
    x = sfx._creak(rng, sr, rng.uniform(0.6, 1.0), 35, 60, 0.5)
    x = s.reverb(x, sr, rng, 0.2, 0.6, 0.2)
    return s.fade(s.normalize(s.lowpass(x, sr, 3000), 0.25), sr, 0.02, 0.2)


def page_turn_far(rng, sr):
    import sfx
    return s.normalize(s.lowpass(sfx.ui_page(rng, sr), sr, 4000), 0.2)


def fire_pop(rng, sr):
    n = s.secs(sr, 0.15)
    x = s.bandpass(rng.standard_normal(n), sr, 800, 6000) * s.env_ad(sr, n, 0.0003, 0.01)
    return s.fade(s.normalize(x, 0.35), sr, 0.0003, 0.03)


def wind_gust(rng, sr):
    """One gust passing (G7 Runde 2): the bed's wind bands under a slow asymmetric swell (rise 2.2 s,
    fall 3.3 s), a little brighter at the top – no grain hiss."""
    dur = 5.5
    n = s.secs(sr, dur)
    t = s.tline(sr, n)
    rise = 2.2
    env = np.where(t < rise, np.sin(np.pi * 0.5 * t / rise) ** 2,
                   np.cos(np.pi * 0.5 * np.clip((t - rise) / (dur - rise), 0, 1)) ** 2)
    body = s.bandpass(s.pink(rng, n), sr, 150, 900, 1)
    bright = s.bandpass(s.pink(rng, n), sr, 400, 1800, 1)
    x = body * env + bright * env ** 3 * 0.35
    return s.fade(s.normalize(x, 0.35), sr, 0.2, 0.5)
