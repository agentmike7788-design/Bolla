"""Loudness after ITU-R BS.1770 / EBU R128 (pyloudnorm's K-weighting), shared by build_audio.py
(levels every cue to its target) and analyze_audio.py (checks them).

Beds and music: integrated loudness (LUFS, gated). One-shots: the loudest 400 ms window
("max. momentary", 100 ms hop) – integrated loudness of a 0.1 s click is not meaningful.
Without pyloudnorm both fall back to plain RMS (−0.691 dB offset), which is only roughly comparable.
"""
from __future__ import annotations

import numpy as np

try:
    import pyloudnorm as pyln
except ImportError:  # pragma: no cover
    pyln = None


def _mono(x: np.ndarray) -> np.ndarray:
    return x if x.ndim == 1 else x.mean(axis=1)


def integrated(x: np.ndarray, sr: int) -> float:
    y = _mono(x)
    if pyln is None or y.size < sr:
        return momentary_max(y, sr)
    return float(pyln.Meter(sr).integrated_loudness(y))


def momentary_max(x: np.ndarray, sr: int) -> float:
    y = _mono(x)
    n = int(0.4 * sr)
    if y.size < n:
        y = np.concatenate([y, np.zeros(n - y.size)])
    if pyln is None:
        k = y
    else:
        k = y.copy()
        for f in pyln.Meter(sr)._filters.values():
            k = f.apply_filter(k)
    p = np.convolve(k ** 2, np.ones(n) / n, mode="valid")[:: max(1, int(0.1 * sr))]
    return float(-0.691 + 10.0 * np.log10(max(float(np.max(p)), 1e-12)))


def of(x: np.ndarray, sr: int, long_form: bool) -> float:
    """Loudness used for levelling: integrated for beds / music (`long_form`), else max. momentary."""
    return integrated(x, sr) if long_form else momentary_max(x, sr)
