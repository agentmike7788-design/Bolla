"""Gravestones (4 variants) and grave mounds (3 variants)."""
import math
import random

import bpy
from mathutils import Vector

import lib_painted as L

STONE = L.hexc("#767B81")
STONE_OLD = L.hexc("#686B64")
MOSS = L.hexc("#5E7148")
EARTH = L.hexc("#6B5A48")
EARTH_FRESH = L.hexc("#4E3B2C")
GRASS = L.hexc("#5E7148")

MOSSY = {"hue_shift": MOSS, "var": 0.14, "ao": 0.45}


def base_plinth(w, d, h, seed):
    return L.part("cube", STONE_OLD, loc=(0, 0, h / 2), scale=(w / 2, d / 2, h / 2),
                  jit=0.012, seed=seed, paint_kw={"ao": 0.5})


def stone_cross():
    L.reset(11)
    parts = [base_plinth(0.5, 0.34, 0.16, 1)]
    beam = L.prim("cube", loc=(0, 0, 0.72), scale=(0.075, 0.065, 0.58))
    bar = L.prim("cube", loc=(0, 0, 0.98), scale=(0.3, 0.06, 0.07))
    ring = L.prim("torus", loc=(0, 0, 0.98), rot=(90, 0, 0), major_radius=0.17,
                  minor_radius=0.03, major_segments=20, minor_segments=6)
    for i, o in enumerate((beam, bar, ring)):
        L.bevel(o, 0.012) if o is not ring else None
        L.subdivide(o, 1) if o is not ring else None
        L.jitter(o, 0.01, 4.0, i)
        L.paint(o, STONE, zrange=(0, 1.3), seed=i, **MOSSY)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    obj = L.join(parts, "ph_prop_gravestone_cross")
    obj.rotation_euler.y = math.radians(3)
    L.finish(obj, "ph_prop_gravestone_cross", "props")


def stone_round():
    L.reset(12)
    body = L.prim("cube", loc=(0, 0, 0.36), scale=(0.33, 0.08, 0.3))
    top = L.prim("cyl", loc=(0, 0, 0.66), rot=(90, 0, 0), radius=0.33, depth=0.16, vertices=20)
    for o in (body, top):
        L.jitter(o, 0.012, 3.0, 2)
        L.paint(o, STONE, zrange=(0, 1.0), seed=3, **MOSSY)
        L.set_mat(o, L.MAT_PAINTED)
    parts = [base_plinth(0.78, 0.3, 0.1, 4), body, top]
    # carved plaque (darker inset)
    plaque = L.part("cube", L.scale_c(STONE, 0.72), loc=(0, -0.083, 0.55), scale=(0.2, 0.005, 0.16))
    parts.append(plaque)
    L.finish(L.join(parts, "ph_prop_gravestone_round"), "ph_prop_gravestone_round", "props")


def stone_obelisk():
    L.reset(13)
    parts = [base_plinth(0.62, 0.62, 0.22, 5),
             L.part("cube", STONE_OLD, loc=(0, 0, 0.32), scale=(0.24, 0.24, 0.1), jit=0.01, seed=6)]
    shaft = L.prim("cube", loc=(0, 0, 1.12), scale=(0.15, 0.15, 0.7))
    L.subdivide(shaft, 3)
    L.taper(shaft, 0.42, 1.82, 0.62)
    L.jitter(shaft, 0.01, 3.0, 7)
    tip = L.prim("cone", loc=(0, 0, 1.93), vertices=4, radius1=0.13, depth=0.22, rot=(0, 0, 45))
    for i, o in enumerate((shaft, tip)):
        L.paint(o, STONE, zrange=(0, 2.1), seed=8 + i, **MOSSY)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    L.finish(L.join(parts, "ph_prop_gravestone_obelisk"), "ph_prop_gravestone_obelisk", "props", 30)


def stone_slab_old():
    L.reset(14)
    slab = L.prim("cube", loc=(0, 0, 0.36), scale=(0.3, 0.1, 0.42))
    L.subdivide(slab, 3)
    # broken, uneven top edge
    for v in slab.data.vertices:
        if v.co.z > 0.7:
            v.co.z -= 0.08 * (0.5 + 0.5 * math.sin(v.co.x * 17.0)) + (0.12 if v.co.x > 0.12 else 0)
    L.jitter(slab, 0.025, 2.5, 9)
    L.paint(slab, STONE_OLD, zrange=(0, 0.8), seed=10, hue_shift=MOSS, var=0.2, ao=0.5)
    L.set_mat(slab, L.MAT_PAINTED)
    slab.rotation_euler = (math.radians(-11), math.radians(7), 0)
    L.finish(slab, "ph_prop_gravestone_slab_old", "props", 40)


def _mound(color, height, sink, seed, grass_mix=0.0, plateau=0.8):
    """Heaped earth over a 1 x 2 m plot: rectangular heightfield with rounded
    shoulders, a slightly flattened top and a lumpy surface (not an egg)."""
    m = L.prim("grid", x_subdivisions=10, y_subdivisions=18, size=1.0, scale=(1.0, 2.0, 1.0), loc=(0, 0.1, 0))
    for v in m.data.vertices:
        u = min(1.0, abs(v.co.x) / 0.5)
        w = min(1.0, abs(v.co.y - 0.1) / 1.0)
        shoulder = (1.0 - u ** 3) * (1.0 - w ** 3)
        z = height * min(1.0, shoulder / plateau) ** 0.7
        v.co.z = max(0.0, z) - sink
        v.co.x *= 0.92
        v.co.y = 0.1 + (v.co.y - 0.1) * 0.92
    L.jitter(m, 0.035, 3.2, seed)
    L.jitter(m, 0.022, 9.0, seed + 100)  # clumpy earth
    c = L.mix(color, GRASS, grass_mix)
    L.paint(m, c, var=0.28, ao=0.35, top=0.08, noise_freq=3.0, seed=seed,
            hue_shift=EARTH if grass_mix > 0 else L.hexc("#3E2F24"))
    L.set_mat(m, L.MAT_PAINTED)
    return m


def _kerb(seed):
    """Low stone border around a 1 x 2 m plot."""
    parts = []
    for (x, y, sx, sy) in ((0, 1.02, 0.54, 0.06), (0, -0.82, 0.54, 0.06),
                           (0.5, 0.1, 0.06, 0.92), (-0.5, 0.1, 0.06, 0.92)):
        parts.append(L.part("cube", STONE_OLD, loc=(x, y, 0.05), scale=(sx, sy, 0.07),
                            jit=0.015, seed=seed + len(parts), paint_kw={"hue_shift": MOSS, "ao": 0.4}))
    return parts


def mounds():
    L.reset(20)
    fresh = _mound(EARTH_FRESH, 0.32, 0.0, 21, plateau=0.7)
    clods = [L.part("ico", EARTH_FRESH, loc=(random.uniform(-0.55, 0.55), random.uniform(-0.9, 1.1), 0.03),
                    radius=random.uniform(0.04, 0.08), subdivisions=1, jit=0.02, seed=30 + i)
             for i in range(24)]
    L.finish(L.join([fresh] + clods, "ph_prop_grave_mound_fresh"), "ph_prop_grave_mound_fresh", "props", 60)

    L.reset(22)
    grassy = _mound(EARTH, 0.16, 0.02, 23, grass_mix=0.85)
    L.finish(L.join([grassy] + _kerb(40), "ph_prop_grave_mound_grassy"), "ph_prop_grave_mound_grassy", "props", 60)

    L.reset(24)
    sunk = L.prim("grid", x_subdivisions=6, y_subdivisions=12, size=1.0, scale=(0.92, 1.8, 1), loc=(0, 0.1, 0.02))
    L.jitter(sunk, 0.02, 3.0, 25)
    L.paint(sunk, L.mix(EARTH, GRASS, 0.35), var=0.2, ao=0.0, seed=26, hue_shift=MOSS)
    L.set_mat(sunk, L.MAT_PAINTED)
    L.finish(L.join([sunk] + _kerb(50), "ph_prop_grave_mound_sunken"), "ph_prop_grave_mound_sunken", "props", 60)


def build():
    stone_cross()
    stone_round()
    stone_obelisk()
    stone_slab_old()
    mounds()


if __name__ == "__main__":
    build()
