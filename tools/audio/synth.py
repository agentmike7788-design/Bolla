"""DSP primitives for the procedural sound set (THE LAST GRAVEKEEPER).

Everything is synthesised from noise, sines and simple filters – no samples, no
third-party recordings. All randomness comes from numpy Generators seeded by the
caller, so a build is bit-for-bit repeatable.

Conventions: mono signals are 1-D float64 arrays in [-1, 1]; stereo is (n, 2).
"""
from __future__ import annotations

import numpy as np
from scipy import signal as sps

TAU = 2.0 * np.pi


# --- basics -------------------------------------------------------------------------------

def secs(sr: int, t: float) -> int:
    return max(1, int(round(sr * t)))


def tline(sr: int, n: int) -> np.ndarray:
    return np.arange(n) / sr


def white(rng: np.random.Generator, n: int) -> np.ndarray:
    return rng.standard_normal(n)


def pink(rng: np.random.Generator, n: int) -> np.ndarray:
    """Pink noise by 1/sqrt(f) spectral shaping (circular → loops seamlessly)."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.arange(spec.size, dtype=float)
    f[0] = 1.0
    spec /= np.sqrt(f)
    spec[0] = 0.0
    out = np.fft.irfft(spec, n)
    return out / (np.std(out) + 1e-12)


def brown(rng: np.random.Generator, n: int) -> np.ndarray:
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.arange(spec.size, dtype=float)
    f[0] = 1.0
    spec /= f
    spec[0] = 0.0
    out = np.fft.irfft(spec, n)
    return out / (np.std(out) + 1e-12)


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) + 1e-12
    return x * (peak / m)


def rms_normalize(x: np.ndarray, rms: float) -> np.ndarray:
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    return x * (rms / r)


def db(v: float) -> float:
    return 10.0 ** (v / 20.0)


def pad(x: np.ndarray, sr: int, before: float = 0.0, after: float = 0.0) -> np.ndarray:
    return np.concatenate([np.zeros(secs(sr, before)) if before > 0 else np.zeros(0), x,
                           np.zeros(secs(sr, after)) if after > 0 else np.zeros(0)])


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if x.size >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - x.size)])


def mix_at(dst: np.ndarray, src: np.ndarray, start: int, gain: float = 1.0, wrap: bool = False) -> None:
    """Adds src into dst at sample `start` (wrap = circular, for seamless loops)."""
    if wrap:
        idx = (np.arange(src.size) + start) % dst.size
        np.add.at(dst, idx, src * gain)
        return
    if start >= dst.size:
        return
    end = min(dst.size, start + src.size)
    if start < 0:
        src = src[-start:]
        end = min(dst.size, src.size)
        start = 0
    dst[start:end] += src[: end - start] * gain


# --- envelopes ---------------------------------------------------------------------------

def env_ad(sr: int, n: int, attack: float, decay: float, curve: float = 1.0) -> np.ndarray:
    """Attack (linear) then exponential decay with time constant `decay` seconds."""
    t = tline(sr, n)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0) ** curve
    d = np.exp(-np.maximum(t - attack, 0.0) / max(decay, 1e-5))
    return a * d


def env_asr(sr: int, n: int, attack: float, release: float) -> np.ndarray:
    t = tline(sr, n)
    dur = n / sr
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    r = np.clip((dur - t) / max(release, 1e-5), 0.0, 1.0)
    return np.minimum(a, r) ** 1.5


def fade(x: np.ndarray, sr: int, fin: float = 0.005, fout: float = 0.02) -> np.ndarray:
    y = x.copy()
    a = min(secs(sr, fin), y.size // 2)
    b = min(secs(sr, fout), y.size // 2)
    if a > 0:
        y[:a] *= np.linspace(0.0, 1.0, a)
    if b > 0:
        y[-b:] *= np.linspace(1.0, 0.0, b) ** 2
    return y


def loop_lfo(rng: np.random.Generator, sr: int, n: int, max_cycles: int = 6, depth: float = 1.0,
             components: int = 4) -> np.ndarray:
    """Smooth random modulation in [0, 1] that is periodic over n samples (integer cycles)."""
    t = np.arange(n) / n
    out = np.zeros(n)
    for _ in range(components):
        k = int(rng.integers(1, max_cycles + 1))
        out += rng.uniform(0.3, 1.0) * np.sin(TAU * k * t + rng.uniform(0, TAU))
    out = (out - out.min()) / (out.max() - out.min() + 1e-12)
    return 1.0 - depth + depth * out


# --- filters -----------------------------------------------------------------------------

def _sos(kind: str, sr: int, f, order: int = 2):
    nyq = sr * 0.5
    if isinstance(f, (tuple, list)):
        wn = [min(max(f[0] / nyq, 1e-4), 0.999), min(max(f[1] / nyq, 1e-4), 0.999)]
    else:
        wn = min(max(f / nyq, 1e-4), 0.999)
    return sps.butter(order, wn, btype=kind, output="sos")


def lowpass(x: np.ndarray, sr: int, f: float, order: int = 2) -> np.ndarray:
    return sps.sosfilt(_sos("lowpass", sr, f, order), x)


def highpass(x: np.ndarray, sr: int, f: float, order: int = 2) -> np.ndarray:
    return sps.sosfilt(_sos("highpass", sr, f, order), x)


def bandpass(x: np.ndarray, sr: int, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return sps.sosfilt(_sos("bandpass", sr, (lo, hi), order), x)


def resonator(x: np.ndarray, sr: int, f: float, q: float) -> np.ndarray:
    """Two-pole resonant band (peaking) filter."""
    b, a = sps.iirpeak(min(f, sr * 0.45) / (sr * 0.5), q)
    return sps.lfilter(b, a, x)


def spectral(x: np.ndarray, sr: int, response) -> np.ndarray:
    """Circular FFT filter: response(freqs) → gain. Keeps loops seamless."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(x.size, 1.0 / sr)
    spec *= response(freqs)
    return np.fft.irfft(spec, x.size)


def band_gain(lo: float, hi: float, slope: float = 2.0):
    def r(f):
        f = np.maximum(f, 1.0)
        g = 1.0 / (1.0 + (lo / f) ** (2 * slope)) / (1.0 + (f / hi) ** (2 * slope))
        return np.sqrt(g)
    return r


def loop_filter_band(x: np.ndarray, sr: int, lo: float, hi: float, slope: float = 2.0) -> np.ndarray:
    return spectral(x, sr, band_gain(lo, hi, slope))


# --- reverb ------------------------------------------------------------------------------

def impulse(rng: np.random.Generator, sr: int, length: float, decay: float, damp: float = 4000.0,
            predelay: float = 0.01) -> np.ndarray:
    n = secs(sr, length)
    ir = rng.standard_normal(n) * np.exp(-tline(sr, n) / decay)
    ir = lowpass(ir, sr, damp, 1)
    ir = np.concatenate([np.zeros(secs(sr, predelay)), ir])
    ir[0] = 0.0
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12)


def reverb(x: np.ndarray, sr: int, rng: np.random.Generator, wet: float = 0.3, length: float = 1.5,
           decay: float = 0.4, damp: float = 4000.0, circular: bool = False) -> np.ndarray:
    ir = impulse(rng, sr, length, decay, damp)
    if circular:
        n = x.size
        irn = fit(ir, n)
        w = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irn), n)
        return x * (1.0 - wet * 0.5) + w * wet
    w = sps.fftconvolve(x, ir)
    y = np.concatenate([x, np.zeros(w.size - x.size)])
    return y * (1.0 - wet * 0.5) + w * wet


def tail_trim(x: np.ndarray, sr: int, threshold_db: float = -60.0, min_len: float = 0.05) -> np.ndarray:
    thr = db(threshold_db) * (np.max(np.abs(x)) + 1e-12)
    idx = np.nonzero(np.abs(x) > thr)[0]
    end = max(int(idx[-1]) + secs(sr, 0.01) if idx.size else x.size, secs(sr, min_len))
    return fade(x[: min(end, x.size)], sr, 0.0, 0.02)


# --- tones -------------------------------------------------------------------------------

def sine(sr: int, n: int, f, phase: float = 0.0) -> np.ndarray:
    """f: float or per-sample array (Hz)."""
    if np.isscalar(f):
        return np.sin(TAU * f * tline(sr, n) + phase)
    return np.sin(np.cumsum(TAU * np.asarray(f) / sr) + phase)


def partials(sr: int, n: int, f0: float, ratios, amps, decays, rng: np.random.Generator | None = None,
             attack: float = 0.002, detune: float = 0.0) -> np.ndarray:
    """Sum of exponentially decaying sines (bells, glass, wood, metal)."""
    t = tline(sr, n)
    out = np.zeros(n)
    for r, a, d in zip(ratios, amps, decays):
        f = f0 * r * (1.0 + (rng.uniform(-detune, detune) if rng is not None and detune > 0 else 0.0))
        if f >= sr * 0.48:
            continue
        ph = rng.uniform(0, TAU) if rng is not None else 0.0
        out += a * np.sin(TAU * f * t + ph) * np.exp(-t / d)
    out *= np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return out


def pluck(sr: int, f0: float, dur: float, rng: np.random.Generator, bright: float = 0.5,
          body: float = 0.3, inharm: float = 0.0004, n_partials: int = 14) -> np.ndarray:
    """Lute/harp-like plucked string: harmonic partials, faster decay up the series, soft pick noise."""
    n = secs(sr, dur)
    t = tline(sr, n)
    out = np.zeros(n)
    base_decay = 1.1 + 2.2 * (220.0 / max(f0, 60.0)) ** 0.5
    for k in range(1, n_partials + 1):
        f = f0 * k * np.sqrt(1.0 + inharm * k * k)
        if f > sr * 0.45:
            break
        amp = (1.0 / k ** (1.6 - bright)) * (1.0 + 0.3 * np.sin(k * 1.7))
        d = base_decay / (1.0 + 0.55 * (k - 1) ** 1.15)
        out += amp * np.sin(TAU * f * t + rng.uniform(0, TAU)) * np.exp(-t / d)
    pick = lowpass(rng.standard_normal(secs(sr, 0.012)), sr, 2500.0 + 3000.0 * bright) * 0.08
    out[: pick.size] += pick * np.linspace(1.0, 0.0, pick.size)
    if body > 0:
        out = out * (1.0 - body) + body * resonator(out, sr, 280.0, 3.0) * 1.5
    out *= np.clip(t / 0.003, 0.0, 1.0)
    return out


def pad_tone(sr: int, freqs, dur: float, rng: np.random.Generator, attack: float = 2.0,
             release: float = 3.0, warmth: float = 0.5, chorus: float = 0.003) -> np.ndarray:
    """Soft additive pad (a few detuned voices per note, gentle odd/even partials)."""
    n = secs(sr, dur)
    t = tline(sr, n)
    out = np.zeros(n)
    for f0 in freqs:
        for v in range(3):
            det = 1.0 + chorus * (v - 1) + rng.uniform(-0.0006, 0.0006)
            vib = 1.0 + 0.0015 * np.sin(TAU * rng.uniform(0.15, 0.35) * t + rng.uniform(0, TAU))
            ph = np.cumsum(TAU * f0 * det * vib / sr)
            for k, a in ((1, 1.0), (2, 0.35 * warmth), (3, 0.18 * warmth), (4, 0.06 * warmth)):
                if f0 * k < sr * 0.45:
                    out += a * np.sin(k * ph + rng.uniform(0, TAU))
    out *= env_asr(sr, n, attack, release)
    return out / max(1, len(freqs) * 3)


def chirp(sr: int, f_start: float, f_end: float, dur: float, curve: float = 1.0) -> np.ndarray:
    n = secs(sr, dur)
    x = np.linspace(0.0, 1.0, n) ** curve
    f = f_start + (f_end - f_start) * x
    return sine(sr, n, f)


def noise_burst(rng: np.random.Generator, sr: int, dur: float, lo: float, hi: float, attack: float = 0.002,
                decay: float = 0.05) -> np.ndarray:
    n = secs(sr, dur)
    x = bandpass(rng.standard_normal(n), sr, lo, hi)
    return x * env_ad(sr, n, attack, decay)


def grains(rng: np.random.Generator, sr: int, dur: float, rate: float, lo: float, hi: float,
           grain_len: float = 0.012, density_env=None, wrap: bool = False) -> np.ndarray:
    """Poisson cloud of tiny filtered noise grains (soil, gravel, rustle, crackle)."""
    n = secs(sr, dur)
    out = np.zeros(n)
    count = int(rate * dur)
    for _ in range(count):
        pos = rng.uniform(0.0, 1.0)
        if density_env is not None and rng.uniform() > density_env(pos):
            continue
        gl = grain_len * rng.uniform(0.5, 1.6)
        g = rng.standard_normal(secs(sr, gl)) * env_ad(sr, secs(sr, gl), 0.0005, gl * 0.3)
        mix_at(out, g * rng.uniform(0.2, 1.0), int(pos * n), 1.0, wrap)
    return bandpass(out, sr, lo, hi) if not wrap else loop_filter_band(out, sr, lo, hi)


def stereo(x: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """Constant-power pan, pan in [-1, 1]."""
    a = (pan + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def seamless(x: np.ndarray, sr: int, overlap: float = 1.0) -> np.ndarray:
    """Crossfades the tail into the head so a non-circular buffer loops without a seam."""
    k = min(secs(sr, overlap), x.size // 3)
    head = x[:k].copy()
    tail = x[-k:].copy()
    w = np.linspace(0.0, 1.0, k)
    out = x[:-k].copy()
    out[:k] = head * np.sqrt(w) + tail * np.sqrt(1.0 - w)
    return out
