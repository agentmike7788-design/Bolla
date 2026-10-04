#!/usr/bin/env python3
"""Builds every sound of THE LAST GRAVEKEEPER procedurally (no samples, no downloads).

    python tools/audio/build_audio.py [--only <substring>] [--no-write-data]

Needs numpy, scipy, soundfile (libsndfile with Vorbis). Deterministic: every file has its
own seed derived from its id, so a rebuild produces the same audio.

Writes
  assets/audio/{sfx,ui,ambience,music}/ph_<id>[_<n>].ogg   (placeholder prefix ph_)
  data/audio/cues_{sfx,ui,ambience,music}.tres             (AudioCueLibrary, read by Audio)

The catalog below is the single source for files AND cue settings (bus, volume, pitch
jitter, loop, positional range, cooldown, voices). Ambience profiles, the event map and
the audio config are hand-written data in data/audio/ and only reference cue ids.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys
from dataclasses import dataclass, field

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import ambience as amb  # noqa: E402
import music  # noqa: E402
import sfx  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ASSET_DIR = os.path.join(ROOT, "assets", "audio")
DATA_DIR = os.path.join(ROOT, "data", "audio")

SR_SFX = 44100
SR_AMB = 32000
SR_MUS = 32000


@dataclass
class Spec:
    id: str
    gen: object
    variants: int = 1
    bus: str = "SFX"
    folder: str = "sfx"
    volume_db: float = 0.0
    volume_jitter_db: float = 1.5
    pitch_jitter: float = 0.05
    loop: bool = False
    positional: bool = False
    max_distance: float = 24.0
    unit_size: float = 4.0
    cooldown: float = 0.0
    max_voices: int = 3
    sr: int = SR_SFX
    quality: float = 0.45          # libsndfile compression_level: 0 = best quality, 1 = smallest
    library: str = "sfx"
    extra: dict = field(default_factory=dict)


def S(id, gen, v=1, **kw):
    return Spec(id, gen, v, **kw)


def UI(id, gen, v=1, **kw):
    kw.setdefault("bus", "UI")
    kw.setdefault("folder", "ui")
    kw.setdefault("library", "ui")
    kw.setdefault("max_voices", 2)
    return Spec(id, gen, v, **kw)


def AMB(id, gen, v=1, **kw):
    kw.setdefault("bus", "Ambience")
    kw.setdefault("folder", "ambience")
    kw.setdefault("library", "ambience")
    kw.setdefault("sr", SR_AMB)
    kw.setdefault("quality", 0.85)
    kw.setdefault("pitch_jitter", 0.0)
    kw.setdefault("volume_jitter_db", 0.0)
    return Spec(id, gen, v, **kw)


def SPOT(id, gen, v=1, **kw):
    kw.setdefault("pitch_jitter", 0.06)
    kw.setdefault("volume_jitter_db", 3.0)
    kw.setdefault("quality", 0.7)
    return AMB(id, gen, v, **kw)


def MUS(id, gen, **kw):
    kw.setdefault("bus", "Music")
    kw.setdefault("folder", "music")
    kw.setdefault("library", "music")
    kw.setdefault("sr", SR_MUS)
    kw.setdefault("quality", 0.85)
    kw.setdefault("pitch_jitter", 0.0)
    kw.setdefault("volume_jitter_db", 0.0)
    kw.setdefault("max_voices", 1)
    return Spec(id, gen, 1, **kw)


CATALOG: list[Spec] = [
    # footsteps (player 2D; villagers through Audio.play_at → 3D)
    S("step_grass", sfx.step_grass, 4, volume_db=-15, pitch_jitter=0.08, max_voices=4, max_distance=14),
    S("step_earth", sfx.step_earth, 4, volume_db=-14, pitch_jitter=0.08, max_voices=4, max_distance=14),
    S("step_stone", sfx.step_stone, 4, volume_db=-16, pitch_jitter=0.07, max_voices=4, max_distance=14),
    S("step_wood", sfx.step_wood, 4, volume_db=-13, pitch_jitter=0.07, max_voices=4, max_distance=14),
    # grave work
    S("dig", sfx.dig, 3, volume_db=-7, pitch_jitter=0.07),
    S("dirt_pour", sfx.dirt_pour, 2, volume_db=-8),
    S("stone_set", sfx.stone_set, 1, volume_db=-7, cooldown=0.5),
    # stations & gathering
    S("chop", sfx.chop, 3, volume_db=-8),
    S("saw", sfx.saw, 2, volume_db=-12),
    S("hammer", sfx.hammer, 3, volume_db=-10),
    S("anvil", sfx.anvil, 2, volume_db=-12, positional=True, max_distance=40, unit_size=6),
    S("chisel", sfx.chisel, 3, volume_db=-11),
    S("pick_stone", sfx.pick_stone, 3, volume_db=-10),
    S("loom", sfx.loom, 2, volume_db=-10),
    S("bellows", sfx.bellows, 1, volume_db=-10, cooldown=1.0),
    S("rustle", sfx.rustle, 3, volume_db=-12),
    S("cloth", sfx.cloth, 3, volume_db=-11, cooldown=0.15),
    S("wash", sfx.wash, 2, volume_db=-12),
    S("scrub", sfx.scrub, 2, volume_db=-14),
    S("snip", sfx.snip, 2, volume_db=-12),
    S("quill", sfx.quill, 2, volume_db=-14),
    S("smoke_hiss", sfx.smoke_hiss, 1, volume_db=-14),
    # objects
    S("door_open", sfx.door_open, 2, volume_db=-9, cooldown=0.3),
    S("door_close", sfx.door_close, 2, volume_db=-9, cooldown=0.3),
    S("chest_open", sfx.chest_open, 2, volume_db=-10, cooldown=0.2),
    S("chest_close", sfx.chest_close, 2, volume_db=-10, cooldown=0.2),
    S("crate", sfx.crate, 2, volume_db=-10),
    S("coins", sfx.coins, 3, volume_db=-10, cooldown=0.25),
    S("pickup", sfx.pickup, 2, volume_db=-12, cooldown=0.1),
    S("putdown", sfx.putdown, 2, volume_db=-11, cooldown=0.1),
    S("corpse_down", sfx.corpse_down, 2, volume_db=-8, cooldown=0.3),
    S("glass_seal", sfx.glass_seal, 2, volume_db=-11, cooldown=0.3),
    S("anatomy_tool", sfx.anatomy_tool, 2, volume_db=-18, cooldown=0.5),
    S("cart_roll", sfx.cart_roll, 1, volume_db=-12, loop=True, positional=True, max_distance=30, unit_size=5,
      pitch_jitter=0.0, volume_jitter_db=0.0, max_voices=1),
    # bells, spirits, story
    S("church_bell", sfx.church_bell, 1, volume_db=-8, positional=True, max_distance=120, unit_size=30,
      pitch_jitter=0.0, volume_jitter_db=0.0, max_voices=2),
    S("small_bell", sfx.small_bell, 1, volume_db=-12, pitch_jitter=0.0, cooldown=1.0),
    S("ghost_appear", sfx.ghost_appear, 1, volume_db=-14, pitch_jitter=0.03, cooldown=4.0, max_voices=2),
    S("ghost_content", sfx.ghost_content, 1, volume_db=-12, pitch_jitter=0.0, cooldown=2.0, max_voices=1),
    S("ghost_restless", sfx.ghost_restless, 1, volume_db=-14, pitch_jitter=0.0, cooldown=2.0, max_voices=1),
    S("ghost_night", sfx.ghost_night, 1, volume_db=-12, pitch_jitter=0.0, cooldown=10.0, max_voices=1),
    S("chapter", sfx.chapter, 1, volume_db=-8, pitch_jitter=0.0, volume_jitter_db=0.0, cooldown=5.0, max_voices=1),
    S("travel", sfx.travel, 1, volume_db=-12, pitch_jitter=0.03, cooldown=0.5, max_voices=1),
    S("remark", sfx.remark, 2, volume_db=-18, cooldown=0.6, max_voices=1),
    S("build_place", sfx.build_place, 2, volume_db=-10),
    S("build_remove", sfx.build_remove, 1, volume_db=-11),
    S("sleep", sfx.sleep, 1, volume_db=-12, cooldown=2.0),
    # UI
    UI("ui_click", sfx.ui_click, 2, volume_db=-14, pitch_jitter=0.04, cooldown=0.03),
    UI("ui_hover", sfx.ui_hover, 1, volume_db=-24, pitch_jitter=0.05, cooldown=0.06, max_voices=1),
    UI("ui_open", sfx.ui_open, 1, volume_db=-14, cooldown=0.1),
    UI("ui_close", sfx.ui_close, 1, volume_db=-15, cooldown=0.1),
    UI("ui_error", sfx.ui_error, 1, volume_db=-13, cooldown=0.25),
    UI("ui_page", sfx.ui_page, 3, volume_db=-13, cooldown=0.08),
    UI("ui_notify", sfx.ui_notify, 1, volume_db=-18, cooldown=0.4),
    UI("ui_reward", sfx.ui_reward, 1, volume_db=-15, cooldown=0.4),
    # ambience beds (loops)
    AMB("amb_graveyard_day", amb.amb_graveyard_day, loop=True, volume_db=-10),
    AMB("amb_graveyard_dusk", amb.amb_graveyard_dusk, loop=True, volume_db=-10),
    AMB("amb_graveyard_night", amb.amb_graveyard_night, loop=True, volume_db=-11),
    AMB("amb_forest_edge", amb.amb_forest_edge, loop=True, volume_db=-11),
    AMB("amb_village_day", amb.amb_village_day, loop=True, volume_db=-11),
    AMB("amb_village_night", amb.amb_village_night, loop=True, volume_db=-11),
    AMB("amb_hut", amb.amb_hut, loop=True, volume_db=-12),
    AMB("amb_inn", amb.amb_inn, loop=True, volume_db=-11),
    AMB("amb_surgery", amb.amb_surgery, loop=True, volume_db=-14),
    AMB("amb_office", amb.amb_office, loop=True, volume_db=-13),
    AMB("amb_chapel", amb.amb_chapel, loop=True, volume_db=-12),
    AMB("amb_crypt", amb.amb_crypt, loop=True, volume_db=-12),
    AMB("amb_shed", amb.amb_shed, loop=True, volume_db=-14),
    AMB("amb_title", amb.amb_title, loop=True, volume_db=-12),
    # positional world loops
    AMB("loop_brook", amb.loop_brook, loop=True, positional=True, volume_db=-8, max_distance=22, unit_size=4),
    AMB("loop_forge", amb.loop_forge, loop=True, positional=True, volume_db=-10, max_distance=16, unit_size=3),
    # spots
    SPOT("bird_a", amb.bird_a, 2, volume_db=-17),
    SPOT("bird_b", amb.bird_b, 2, volume_db=-18),
    SPOT("bird_c", amb.bird_c, 2, volume_db=-19),
    SPOT("crow", amb.crow, 2, volume_db=-20),
    SPOT("owl", amb.owl, 2, volume_db=-14, pitch_jitter=0.03),
    SPOT("owl_short", amb.owl_short, 1, volume_db=-16, pitch_jitter=0.03),
    SPOT("chicken", amb.chicken, 3, volume_db=-20),
    SPOT("hammer_far", amb.hammer_far, 2, volume_db=-18, pitch_jitter=0.02),
    SPOT("cup_clink", amb.cup_clink, 3, volume_db=-16),
    SPOT("drip_spot", amb.drip_spot, 3, volume_db=-16),
    SPOT("wood_creak", amb.wood_creak, 2, volume_db=-18),
    SPOT("page_turn_far", amb.page_turn_far, 1, volume_db=-20),
    SPOT("fire_pop", amb.fire_pop, 2, volume_db=-18),
    SPOT("wind_gust", amb.wind_gust, 2, volume_db=-14, pitch_jitter=0.04),
    # music
    MUS("mus_title", music.mus_title, volume_db=-5),
    MUS("mus_day", music.mus_day, volume_db=-6),
    MUS("mus_night", music.mus_night, volume_db=-6),
    MUS("mus_village", music.mus_village, volume_db=-6),
]


def seed_for(name: str) -> int:
    return int.from_bytes(hashlib.sha256(name.encode()).digest()[:8], "little")


def file_name(spec: Spec, i: int) -> str:
    suffix = f"_{i + 1}" if spec.variants > 1 else ""
    return f"ph_{spec.id}{suffix}.ogg"


def res_path(spec: Spec, i: int) -> str:
    return f"res://assets/audio/{spec.folder}/{file_name(spec, i)}"


def render(spec: Spec, i: int) -> np.ndarray:
    rng = np.random.default_rng(seed_for(f"{spec.id}#{i}"))
    x = spec.gen(rng, spec.sr)
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    peak = np.max(np.abs(x)) + 1e-12
    if peak > 0.98:
        x = x * (0.98 / peak)
    return x.astype(np.float32)


def write_ogg(path: str, x: np.ndarray, sr: int, quality: float) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    channels = 1 if x.ndim == 1 else x.shape[1]
    # Written in blocks: libsndfile 1.2's Vorbis encoder overflows its stack on long buffers.
    with sf.SoundFile(path, "w", sr, channels, subtype="VORBIS", format="OGG",
                      compression_level=quality) as fh:
        for i in range(0, x.shape[0], 4096):
            fh.write(x[i:i + 4096])


# --- data -------------------------------------------------------------------------------

def _f(v: float) -> str:
    r = repr(float(v))
    return r[:-2] if r.endswith(".0") else r


def library_tres(lib: str, specs: list[Spec]) -> str:
    lines = [
        f'[gd_resource type="Resource" script_class="AudioCueLibrary" load_steps={len(specs) + 3} format=3]',
        "",
        '[ext_resource type="Script" path="res://src/systems/audio/audio_cue.gd" id="1_cue"]',
        '[ext_resource type="Script" path="res://src/systems/audio/audio_cue_library.gd" id="2_lib"]',
        "",
    ]
    for sp in specs:
        files = ", ".join(f'"{res_path(sp, i)}"' for i in range(sp.variants))
        lines += [
            f'[sub_resource type="Resource" id="cue_{sp.id}"]',
            'script = ExtResource("1_cue")',
            f'id = &"{sp.id}"',
            f"files = PackedStringArray({files})",
            f'bus = &"{sp.bus}"',
            f"volume_db = {_f(sp.volume_db)}",
            f"volume_jitter_db = {_f(sp.volume_jitter_db)}",
            f"pitch_jitter = {_f(sp.pitch_jitter)}",
            f"loop = {'true' if sp.loop else 'false'}",
            f"positional = {'true' if sp.positional else 'false'}",
            f"max_distance = {_f(sp.max_distance)}",
            f"unit_size = {_f(sp.unit_size)}",
            f"cooldown = {_f(sp.cooldown)}",
            f"max_voices = {sp.max_voices}",
            "",
        ]
    refs = ", ".join(f'SubResource("cue_{sp.id}")' for sp in specs)
    lines += [
        "[resource]",
        'script = ExtResource("2_lib")',
        f'library_id = &"{lib}"',
        f'cues = Array[ExtResource("1_cue")]([{refs}])',
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="only render ids containing this text")
    ap.add_argument("--no-write-data", action="store_true")
    args = ap.parse_args()
    total = 0
    for sp in CATALOG:
        if args.only and args.only not in sp.id:
            continue
        for i in range(sp.variants):
            x = render(sp, i)
            path = os.path.join(ASSET_DIR, sp.folder, file_name(sp, i))
            write_ogg(path, x, sp.sr, sp.quality)
            size = os.path.getsize(path)
            total += size
            dur = x.shape[0] / sp.sr
            print(f"{sp.folder:9s} {file_name(sp, i):34s} {dur:6.2f} s {size / 1024:7.1f} KB")
    print(f"rendered {total / 1024 / 1024:.2f} MB")
    if not args.no_write_data:
        os.makedirs(DATA_DIR, exist_ok=True)
        for lib in ("sfx", "ui", "ambience", "music"):
            specs = [sp for sp in CATALOG if sp.library == lib]
            with open(os.path.join(DATA_DIR, f"cues_{lib}.tres"), "w", encoding="utf-8") as fh:
                fh.write(library_tres(lib, specs))
        print("wrote data/audio/cues_*.tres")
    return 0


if __name__ == "__main__":
    sys.exit(main())
