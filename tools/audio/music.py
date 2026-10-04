"""Procedurally composed music: plucked lute/harp voices over soft pads, modal keys,
slow tempos with rests. Deterministic per seed. Output stereo (n, 2).
"""
from __future__ import annotations

import numpy as np

import synth as s

MODES = {
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}


def midi_hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def degree_midi(root: int, mode: str, degree: int) -> int:
    sc = MODES[mode]
    octave, idx = divmod(degree, 7)
    return root + 12 * octave + sc[idx]


def chord(root: int, mode: str, degree: int) -> list[int]:
    return [degree_midi(root, mode, degree + k) for k in (0, 2, 4)]


def compose(rng, sr, root, mode, bpm, progression, bars, density=0.6, melody=0.5, register=0,
            pad_level=0.22, pluck_level=0.5, bright=0.45, rest_bars=(), arp_patterns=None):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bars * bar + 6.0
    n = s.secs(sr, total)
    left = np.zeros(n)
    right = np.zeros(n)

    def put(x, t, gain, pan):
        st = s.stereo(x * gain, pan)
        i = s.secs(sr, t)
        s.mix_at(left, st[:, 0], i)
        s.mix_at(right, st[:, 1], i)

    patterns = arp_patterns or [[0, 1, 2, 3, 2, 1], [0, 2, 1, 3], [0, 1, 2, 1, 3, 2, 1, 2], [0, 2, 3, 2]]
    last_mel = None
    for b in range(bars):
        deg = progression[b % len(progression)]
        ch = chord(root + 12 * register, mode, deg)
        t_bar = b * bar
        fade_in = min(1.0, (b + 1) / 2.0)
        fade_out = min(1.0, (bars - b) / 2.0)
        bar_gain = fade_in * fade_out
        # pad: every two bars a sustained chord
        if b % 2 == 0:
            pf = [midi_hz(m - 12) for m in ch]
            pad = s.pad_tone(sr, pf, bar * 2 + 1.5, rng, bar * 0.6, bar * 0.8, 0.45)
            put(pad, t_bar, pad_level * bar_gain, rng.uniform(-0.3, 0.3))
        if b in rest_bars:
            continue
        # bass pluck on the root
        put(s.pluck(sr, midi_hz(ch[0] - 12), 4.0, rng, 0.25, 0.4), t_bar, pluck_level * 0.7 * bar_gain, -0.15)
        # arpeggio
        pat = patterns[int(rng.integers(0, len(patterns)))]
        tones = ch + [ch[0] + 12]
        steps = len(pat)
        step_len = bar / max(steps, 1)
        for i, p in enumerate(pat):
            if rng.uniform() > density:
                continue
            t = t_bar + i * step_len + rng.uniform(-0.012, 0.012)
            m = tones[p % len(tones)]
            vel = rng.uniform(0.6, 1.0) * (1.0 if i == 0 else 0.8)
            put(s.pluck(sr, midi_hz(m), 3.2, rng, bright), t, pluck_level * vel * bar_gain * 0.55,
                rng.uniform(-0.45, 0.45))
        # melody: a few long notes from the scale, stepwise
        if rng.uniform() < melody:
            count = int(rng.integers(1, 4))
            for k in range(count):
                if last_mel is None:
                    last_mel = deg + 7 + int(rng.integers(0, 3)) * 2
                last_mel = int(np.clip(last_mel + rng.choice([-2, -1, -1, 1, 1, 2, 0]), 7, 13))
                m = degree_midi(root + 12 * register, mode, last_mel)
                t = t_bar + k * (bar / count) + beat * rng.choice([0.0, 0.5])
                put(s.pluck(sr, midi_hz(m), 4.0, rng, bright + 0.1, 0.2, n_partials=10), t,
                    pluck_level * 0.75 * bar_gain, rng.uniform(-0.2, 0.25))
    mixl = s.reverb(left, sr, rng, 0.45, 3.0, 1.0, 5000)
    mixr = s.reverb(right, sr, rng, 0.45, 3.0, 1.0, 5000)
    m = min(mixl.size, mixr.size)
    out = np.stack([mixl[:m], mixr[:m]], axis=1)
    out = out[: s.secs(sr, total + 1.5)]
    k = s.secs(sr, 4.0)
    out[-k:] *= np.linspace(1.0, 0.0, k)[:, None] ** 2
    out = out / (np.max(np.abs(out)) + 1e-12) * 0.6
    return out


def mus_title(rng, sr):
    return compose(rng, sr, 50, "aeolian", 56, [0, 5, 2, 6], 18, 0.65, 0.55, 0, 0.26, 0.5, 0.4,
                   rest_bars=(8, 17))


def mus_day(rng, sr):
    return compose(rng, sr, 50, "dorian", 66, [0, 3, 0, 6, 0, 3, 4, 0], 22, 0.6, 0.5, 0, 0.2, 0.5, 0.5,
                   rest_bars=(7, 15))


def mus_night(rng, sr):
    return compose(rng, sr, 57, "aeolian", 52, [0, 3, 0, 4], 16, 0.42, 0.45, 0, 0.24, 0.42, 0.35,
                   rest_bars=(4, 9, 13), arp_patterns=[[0, 2, 3], [0, 3, 2, 1], [1, 3]])


def mus_village(rng, sr):
    return compose(rng, sr, 55, "mixolydian", 72, [0, 6, 3, 0, 0, 6, 4, 0], 24, 0.62, 0.55, 0, 0.18, 0.5, 0.5,
                   rest_bars=(11, 23))
