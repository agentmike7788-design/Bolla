"""Phase-4 environment (docs/PHASE4_DESIGN.md section 8): the elders of the Holunderwinkel.

  ph_env_elder_bush     a big old elder (~3 m): arching grey-brown, corky stems from the root,
                        loose leaf masses, flat cream-white umbels and hanging clusters of dark,
                        ink-violet berries (no cold saturated blue)
  ph_env_elder_thicket  a dense tangle of young elder (~2 x 2 x 1.6 m, obstacle): many shoots,
                        low leaf mounds, a few umbels

Leaf masses use mat_foliage (wind, leafy edges) as the approved bush/oak recipe, stems,
blossoms and berries mat_painted. Front = -Y (Blender) = +Z (Godot), pivot bottom centre.
Run:  python tools/blender/build_all.py asset_env_phase4
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh users)
from mathutils import Euler, Matrix, Vector

import lib_painted as L
import asset_props_slice as P
from asset_env_phase3 import _clump, _cane, _blades, GRASS_TINT
from asset_environment import _limb as limb

ELDER_BARK = L.hexc("#76695A")        # light grey-brown, corky
ELDER_BARK_DARK = L.hexc("#54493E")
ELDER_LEAF_A = L.hexc("#465A38")
ELDER_LEAF_B = L.hexc("#61744A")
UMBEL = L.hexc("#DCD4B6")             # cream-white flat umbels
UMBEL_SHADE = L.hexc("#B9B08E")
BERRY = L.hexc("#3B2D40")             # ink-violet, dark and muted
BERRY_STALK = L.hexc("#6E3E48")       # the reddish stalks of ripe elder clusters (muted)


def _umbel(parts, loc, r: float, seed: int, tilt=(0.0, 0.0)) -> None:
    """A flat-topped cream umbel: a squashed icosphere with a bumpy painted top."""
    u = L.prim("ico", loc=(0, 0, 0), radius=r, subdivisions=1, scale=(1.0, 1.0, 0.32))
    L.jitter(u, r * 0.12, 3.0 / r, seed)
    u.data.transform(Matrix.Translation(Vector(loc))
                     @ Euler((math.radians(tilt[0]), math.radians(tilt[1]), 0.0)).to_matrix().to_4x4())
    L.paint(u, UMBEL, var=0.22, ao=0.0, top=0.25, noise_freq=12.0, hue_shift=UMBEL_SHADE, seed=seed)
    L.set_mat(u, L.MAT_PAINTED)
    parts.append(u)


def _berries(parts, loc, seed: int, n: int = 3) -> None:
    """A hanging cluster of dark elderberries on a reddish stalk."""
    rnd = random.Random(seed)
    top = Vector(loc)
    bottom = top + Vector((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), -0.1))
    parts.append(P._stick(top, bottom, 0.006, BERRY_STALK, verts=3, seed=seed, ao=0.0))
    for k in range(n):
        off = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), rnd.uniform(-0.03, 0.02)))
        parts.append(L.part("ico", L.scale_c(BERRY, rnd.uniform(0.85, 1.15)), loc=bottom + off, radius=0.055,
                            subdivisions=1, scale=(1.0, 1.0, 0.8), jit=0.01, seed=seed + k,
                            paint_kw={"ao": 0.2, "var": 0.25, "top": 0.45, "noise_freq": 20.0}))


def elder_bush():
    """Big old elder, ~3 m wide and high: five arching stems out of one root, leaf masses along
    and over them, nine umbels on the sunny top, six berry clusters hanging at the sides."""
    L.reset(800)
    rnd = random.Random(801)
    parts = []
    tips = []
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        d = Vector((math.cos(a) * 0.55, math.sin(a) * 0.5, 1.0))
        ln = rnd.uniform(1.7, 2.2)
        st = limb((math.cos(a) * 0.06, math.sin(a) * 0.06, -0.05), d, ln, 0.07, 0.03, 810 + i, segs=5, verts=6,
                  droop=0.18)
        L.paint(st, ELDER_BARK, var=0.3, ao=0.5, zrange=(0, 2.4), hue_shift=ELDER_BARK_DARK, seed=820 + i)
        P._tint_up(st, P.MOSS, 0.35, 0.3, freq=5.0, seed=830 + i)
        L.set_mat(st, L.MAT_PAINTED)
        parts.append(st)
        tips.append(Vector((math.cos(a) * 0.06, math.sin(a) * 0.06, 0.0)) + d.normalized() * ln
                    - Vector((0, 0, 0.18 * ln)))
    masses = [((0.0, 0.0, 2.15), 0.75), ((-0.75, 0.2, 1.8), 0.62), ((0.75, -0.1, 1.75), 0.62),
              ((0.2, 0.75, 1.7), 0.58), ((-0.2, -0.7, 1.65), 0.58), ((0.55, 0.55, 1.25), 0.45),
              ((-0.6, -0.45, 1.2), 0.45), ((-0.6, 0.62, 1.1), 0.42)]
    for i, (c, r) in enumerate(masses):
        shade = rnd.random()
        parts.append(_clump(c, r, L.mix(ELDER_LEAF_A, ELDER_LEAF_B, 0.1 + shade * 0.5), 840 + i, subdiv=3,
                            scale=(1.15, 1.1, 0.72), zr=(0.3, 2.7), jit=0.34,
                            hue=L.hexc("#737D48") if shade > 0.7 else None))
    for i in range(14):  # umbels sitting on the sunlit upper surface of the leaf masses
        c, r = masses[i % 8]
        a = rnd.uniform(0, math.tau)
        k = rnd.uniform(0.45, 0.8)                       # how far out from the top
        p = Vector(c) + Vector((math.cos(a) * r * 1.1 * k, math.sin(a) * r * 1.05 * k,
                                r * 0.72 * math.sqrt(max(0.0, 1.0 - k * k)) + 0.06))
        _umbel(parts, p, rnd.uniform(0.13, 0.17), 850 + i, tilt=(math.cos(a) * 25.0 * k, -math.sin(a) * 25.0 * k))
    for i in range(7):  # berry clusters hanging out under the rim of the leaf masses
        c, r = masses[1 + i % 7]
        a = i / 7 * math.tau + 0.5
        p = Vector(c) + Vector((math.cos(a) * r * 1.12, math.sin(a) * r * 1.05, -r * 0.15))
        _berries(parts, p, 870 + i * 5, n=4)
    parts.append(_blades([((0.0, 0.0), 10, (0.15, 0.3), 0.014, 0.12)], GRASS_TINT, 880))
    obj = L.join(parts, "ph_env_elder_bush")
    P._center_xy(obj)
    L.finish(obj, "ph_env_elder_bush", "environment", 50)


def elder_thicket():
    """A tangle of young elder, ~2 x 2 x 1.6 m: a dozen straight shoots, low lumpy leaf mounds,
    four small umbels and two berry clusters - clearly a mass to cut back, not a tree."""
    L.reset(900)
    rnd = random.Random(901)
    parts = []
    for i in range(10):
        a = i / 10 * math.tau + rnd.uniform(-0.3, 0.3)
        r0 = rnd.uniform(0.05, 0.5)
        base = Vector((math.cos(a) * r0, math.sin(a) * r0, 0.0))
        top = base + Vector((math.cos(a) * rnd.uniform(0.2, 0.45), math.sin(a) * rnd.uniform(0.2, 0.45),
                             rnd.uniform(1.15, 1.55)))
        mid = base.lerp(top, 0.5) + Vector((rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06), 0.0))
        parts.append(_cane([base, mid, top], 0.03, 0.012, L.scale_c(ELDER_BARK, rnd.uniform(0.85, 1.1)), 910 + i,
                           sides=4, zr=(0, 1.6)))
    mounds = [((0.0, 0.0, 1.05), 0.55), ((-0.55, 0.3, 0.85), 0.46), ((0.55, -0.25, 0.85), 0.46),
              ((0.25, 0.55, 0.75), 0.42), ((-0.35, -0.55, 0.7), 0.4), ((0.6, 0.45, 0.5), 0.34),
              ((-0.7, -0.15, 0.45), 0.34)]
    for i, (c, r) in enumerate(mounds):
        shade = rnd.random()
        parts.append(_clump(c, r, L.mix(ELDER_LEAF_A, ELDER_LEAF_B, 0.05 + shade * 0.5), 930 + i,
                            subdiv=3 if i < 4 else 2,
                            scale=(1.2, 1.1, 0.78), zr=(0.0, 1.6), jit=0.36,
                            hue=L.hexc("#737D48") if shade > 0.7 else None))
    for i in range(6):
        c, r = mounds[i]
        a = rnd.uniform(0, math.tau)
        p = Vector(c) + Vector((math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, r * 0.78 * 0.85 + 0.05))
        _umbel(parts, p, rnd.uniform(0.07, 0.09), 950 + i, tilt=(rnd.uniform(-15, 15), rnd.uniform(-15, 15)))
    for i in range(2):
        c, r = mounds[1 + i * 2]
        p = Vector(c) + Vector((r * 1.1 * (1 if i else -1), -r * 0.45, -r * 0.1))
        _berries(parts, p, 960 + i * 5, n=3)
    obj = L.join(parts, "ph_env_elder_thicket")
    P._center_xy(obj)
    L.finish(obj, "ph_env_elder_thicket", "environment", 50)


ASSETS = (elder_bush, elder_thicket)


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
