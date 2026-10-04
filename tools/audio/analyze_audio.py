#!/usr/bin/env python3
"""Objective check of every generated sound (G7 Runde 2 – nobody here can listen):

    python tools/audio/analyze_audio.py [--json out.json] [--md docs/reviews/phase7_round2/audio_list.md]
                                        [--spectro <cue_id> <out.png> [seconds]]

Per file: length, sample peak (dBFS) and clipped samples, DC offset, loudness (ITU-R BS.1770 /
EBU R128 – integrated for beds and music, max. momentary (400 ms) for one-shots), the loudness in
the game (+ the cue's volume_db), first/last sample (clicks), loop seam (jump at the wrap point
against the signal's usual sample step, level step across the seam), energy share 2–5 kHz (harsh),
the strongest narrow spectral peak above the smoothed spectrum (whistle / metallic ring in noise),
the noise floor and the tail (time below -40 dB of the peak at the end). Each row is checked
against the targets in build_audio.TARGETS; the problems column names what fails.
Needs numpy, scipy, soundfile, pyloudnorm (and matplotlib for --spectro).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal as sps

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build_audio as ba  # noqa: E402

try:
    import pyloudnorm as pyln
except ImportError:  # pragma: no cover
    pyln = None

EDGE_CLICK = 0.01            # first / last sample of a one-shot above this = audible click
SEAM_RATIO = 6.0             # wrap jump > this × the 99.9th percentile of |diff| = seam click
SEAM_LEVEL_DB = 1.5          # RMS of the last vs the first 250 ms of a loop
HARSH_SHARE = 0.35           # energy share 2–5 kHz
RING_DB = {"Ambience": 18.0, "Music": 99.0, "SFX": 30.0, "UI": 99.0}   # narrow peak above smoothed spectrum
TAIL_MAX = 1.5               # seconds below -40 dB of peak at the end of a one-shot


def db(v: float) -> float:
    return 20.0 * np.log10(max(v, 1e-9))


def loudness(x: np.ndarray, sr: int, integrated: bool) -> float:
    """LUFS: integrated (beds, music) or max. momentary 400 ms (one-shots)."""
    if pyln is None:
        return db(np.sqrt(np.mean(x ** 2))) - 0.691
    meter = pyln.Meter(sr)
    y = x if x.ndim == 1 else x.mean(axis=1)
    if integrated and y.size >= sr:
        return float(meter.integrated_loudness(y))
    n = int(0.4 * sr)
    if y.size < n:
        y = np.concatenate([y, np.zeros(n - y.size)])
    # K-weighting of pyloudnorm's meter, then the loudest 400 ms window (100 ms hop).
    k = y.copy()
    for f in meter._filters.values():
        k = f.apply_filter(k)
    p = np.convolve(k ** 2, np.ones(n) / n, mode="valid")[:: max(1, int(0.1 * sr))]
    return float(-0.691 + 10.0 * np.log10(max(np.max(p), 1e-12)))


def ring_db(x: np.ndarray, sr: int) -> tuple[float, float]:
    f, p = sps.welch(x, sr, nperseg=min(8192, x.size))
    p = np.maximum(p, 1e-20)
    lp = 10 * np.log10(p)
    sel = (f > 150) & (f < 9000)
    if not np.any(sel):
        return 0.0, 0.0
    win = max(9, int(len(f) / 120) | 1)
    smooth = sps.medfilt(lp, win)
    prom = lp - smooth
    i = int(np.argmax(np.where(sel, prom, -99)))
    return float(prom[i]), float(f[i])


def analyse(sp, i: int) -> dict:
    path = os.path.join(ba.ASSET_DIR, sp.folder, ba.file_name(sp, i))
    x, sr = sf.read(path, always_2d=False)
    if x.ndim > 1:
        x = x.mean(axis=1)
    peak = float(np.max(np.abs(x))) + 1e-12
    integrated = sp.loop or sp.bus == "Music"
    lufs = loudness(x, sr, integrated)
    f, p = sps.welch(x, sr, nperseg=min(4096, x.size))
    total = float(np.sum(p)) + 1e-20
    harsh = float(np.sum(p[(f >= 2000) & (f <= 5000)])) / total
    ring, ring_f = ring_db(x, sr)
    fr = max(1, int(0.05 * sr))
    frames = np.sqrt(np.array([np.mean(x[k:k + fr] ** 2) for k in range(0, max(1, x.size - fr), fr)]) + 1e-20)
    floor = db(float(np.percentile(frames, 10)))
    above = np.nonzero(np.abs(x) > peak * 0.01)[0]
    tail = (x.size - 1 - above[-1]) / sr if above.size else 0.0
    d = np.abs(np.diff(x))
    usual = float(np.percentile(d, 99.9)) + 1e-9
    seam = float(abs(x[0] - x[-1])) / usual
    q = int(0.25 * sr)
    seam_level = abs(db(np.sqrt(np.mean(x[-q:] ** 2))) - db(np.sqrt(np.mean(x[:q] ** 2)))) if x.size > 2 * q else 0.0
    row = {
        "file": ba.file_name(sp, i), "id": sp.id, "bus": sp.bus, "loop": sp.loop, "secs": x.size / sr, "sr": sr,
        "peak_db": db(peak), "clipped": int(np.sum(np.abs(x) >= 0.999)), "dc": float(np.mean(x)),
        "lufs": lufs, "volume_db": sp.volume_db, "game_lufs": lufs + sp.volume_db,
        "first": float(abs(x[0])), "last": float(abs(x[-1])), "seam": seam, "seam_level_db": seam_level,
        "harsh": harsh, "ring_db": ring, "ring_hz": ring_f, "floor_db": floor, "tail": tail,
    }
    row["target"] = ba.target_of(sp)
    row["problems"] = problems(row, sp)
    return row


def problems(r: dict, sp) -> list[str]:
    out = []
    if r["clipped"] > 0 or r["peak_db"] > -0.3:
        out.append("clip")
    if abs(r["dc"]) > 0.002:
        out.append("dc")
    if r["loop"]:
        if r["seam"] > SEAM_RATIO:
            out.append("seam")
        if r["seam_level_db"] > SEAM_LEVEL_DB:
            out.append("seam-level")
    else:
        if r["first"] > EDGE_CLICK or r["last"] > EDGE_CLICK:
            out.append("edge-click")
        if r["tail"] > TAIL_MAX:
            out.append("long-tail")
    if r["harsh"] > HARSH_SHARE and sp.bus != "UI":
        out.append("harsh")
    if r["ring_db"] > RING_DB.get(sp.bus, 99.0):
        out.append("ring@%d" % r["ring_hz"])
    lo, hi = r["target"]
    if not lo <= r["game_lufs"] <= hi:
        out.append("level")
    return out


def all_rows(only: str = "") -> list[dict]:
    rows = []
    for sp in ba.CATALOG:
        if only and only not in sp.id:
            continue
        for i in range(sp.variants):
            rows.append(analyse(sp, i))
    return rows


def markdown(rows: list[dict]) -> str:
    head = ("| Datei | Bus | s | Peak dBFS | DC | LUFS Datei | Lautheit im Spiel | Ziel | 2–5 kHz | Spitze dB@Hz | "
            "Rauschboden | Ausklang s | Naht | Befund |")
    lines = [head, "|" + "---|" * 14]
    for r in rows:
        seam = f"{r['seam']:.1f} / {r['seam_level_db']:.1f} dB" if r["loop"] else f"{r['first']:.3f} / {r['last']:.3f}"
        lines.append(
            f"| {r['file']} | {r['bus']} | {r['secs']:.2f} | {r['peak_db']:.1f} | {r['dc']:+.4f} | {r['lufs']:.1f} | "
            f"{r['game_lufs']:.1f} | {r['target'][0]:.0f}…{r['target'][1]:.0f} | {r['harsh'] * 100:.0f} % | "
            f"{r['ring_db']:.0f}@{r['ring_hz']:.0f} | {r['floor_db']:.0f} | {r['tail']:.2f} | {seam} | "
            f"{', '.join(r['problems']) or 'ok'} |")
    return "\n".join(lines) + "\n"


def spectrogram(cue: str, out: str, seconds: float = 24.0, title: str = "") -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    sp = {s.id: s for s in ba.CATALOG}[cue]
    x, sr = sf.read(os.path.join(ba.ASSET_DIR, sp.folder, ba.file_name(sp, 0)))
    if x.ndim > 1:
        x = x.mean(axis=1)
    x = np.tile(x, int(np.ceil(seconds * sr / x.size)) + 1)[: int(seconds * sr)]   # two loop passes show the seam
    fig, ax = plt.subplots(2, 1, figsize=(11, 6), gridspec_kw={"height_ratios": [3, 1]})
    f, t, s = sps.spectrogram(x, sr, nperseg=2048, noverlap=1536)
    ax[0].pcolormesh(t, f, 10 * np.log10(s + 1e-14), shading="auto", cmap="magma", vmin=-130, vmax=-50)
    ax[0].set_ylim(0, 8000)
    ax[0].set_ylabel("Hz")
    ax[0].set_title(title or f"{cue} – Spektrogramm ({seconds:.0f} s, Loop wiederholt)")
    fr = int(0.05 * sr)
    env = [db(np.sqrt(np.mean(x[k:k + fr] ** 2))) for k in range(0, x.size - fr, fr)]
    ax[1].plot(np.arange(len(env)) * 0.05, env, lw=0.8)
    ax[1].set_ylabel("dBFS (50 ms)")
    ax[1].set_xlabel("s")
    ax[1].set_ylim(-70, 0)
    fig.tight_layout()
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    fig.savefig(out, dpi=90)
    plt.close(fig)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", default="")
    ap.add_argument("--md", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--spectro", nargs="+", default=None, help="<cue_id> <out.png> [seconds]")
    args = ap.parse_args()
    if args.spectro:
        spectrogram(args.spectro[0], args.spectro[1], float(args.spectro[2]) if len(args.spectro) > 2 else 24.0)
        return 0
    rows = all_rows(args.only)
    bad = [r for r in rows if r["problems"]]
    for r in rows:
        print(f"{r['file']:32s} {r['bus']:8s} {r['secs']:6.2f}s peak {r['peak_db']:6.1f} lufs {r['lufs']:6.1f} "
              f"game {r['game_lufs']:6.1f} {','.join(r['problems'])}")
    print(f"{len(rows)} files, {len(bad)} with findings")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(rows, fh, indent=1)
    if args.md:
        with open(args.md, "w", encoding="utf-8") as fh:
            fh.write(markdown(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
