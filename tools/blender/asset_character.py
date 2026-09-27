"""The gravekeeper (player). Stylised ~4.5 heads, hunched, long coat, shoulder
cape, wide crooked hat, shovel strapped to the back, lantern on the belt.
Front faces -Y (Blender) = +Z (Godot). Static pose for the art-direction
prototype; rig + animation come in a later phase."""
import math

import bpy
from mathutils import Vector

import lib_painted as L

COAT = L.hexc("#4B4038")
COAT_DARK = L.hexc("#352D28")
CAPE = L.hexc("#3E4640")
SCARF = L.hexc("#B08A3E")
HAT = L.hexc("#3B3430")
HAT_BAND = L.hexc("#6A4A2F")
SKIN = L.hexc("#C8A383")
BOOT = L.hexc("#2F2722")
TROUSER = L.hexc("#3F4441")
IRON = L.hexc("#3A3C40")
WOOD = L.hexc("#6E5238")
BEARD = L.hexc("#A39A8C")

HUNCH = -0.09   # forward lean of the upper body (towards -Y)


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def build():
    L.reset(80)
    parts = []
    # boots (big) and thin legs
    for sx in (-1, 1):
        parts.append(L.part("sphere", BOOT, loc=(sx * 0.11, -0.05, 0.07), scale=(0.085, 0.16, 0.075),
                            segments=10, ring_count=6, jit=0.008, seed=1 + sx))
        parts.append(_painted(L.tube((sx * 0.1, 0, 0.1), (sx * 0.1, 0, 0.56), 0.05), TROUSER, seed=3))
    # long coat: tapered tube, flared hem, hunched forward
    coat = L.prim("cyl", loc=(0, 0, 0.88), radius=1.0, depth=1.0, vertices=16)
    L.subdivide(coat, 3)
    for v in coat.data.vertices:
        t = v.co.z - 0.38  # 0 at hem, 1 at shoulders
        v.co.z = 0.36 + t * 0.95
        r = 0.34 - 0.12 * t
        v.co.x *= r * (1.0 + 0.1 * (1 - t))
        v.co.y *= r * 0.78
        v.co.y += HUNCH * t * t
    L.jitter(coat, 0.018, 3.0, 4)
    parts.append(_painted(coat, COAT, var=0.18, ao=0.35, top=0.15, zrange=(0.36, 1.31), seed=5, hue_shift=COAT_DARK))
    # coat front opening (dark strip) and belt
    parts.append(L.part("cube", COAT_DARK, loc=(0, HUNCH * 0.35 - 0.205, 0.66), scale=(0.025, 0.02, 0.3), rot=(-6, 0, 0)))
    parts.append(L.part("torus", L.hexc("#2A2420"), loc=(0, HUNCH * 0.3, 0.86), major_radius=0.265,
                        minor_radius=0.025, major_segments=16, minor_segments=4, scale=(1, 0.8, 1)))
    # ragged shoulder cape: reads from the top-down camera
    cape = L.prim("cone", loc=(0, HUNCH, 1.2), radius1=0.36, radius2=0.12, depth=0.28, vertices=14)
    for v in cape.data.vertices:
        if v.co.z < 1.1:  # ragged hem
            a = math.atan2(v.co.y - HUNCH, v.co.x)
            v.co.z -= 0.04 * (0.5 + 0.5 * math.sin(a * 5.0))
    L.jitter(cape, 0.015, 3.0, 13)
    parts.append(_painted(cape, CAPE, var=0.2, ao=0.25, top=0.2, seed=14))
    # scarf (the one warm accent on the character)
    parts.append(L.part("torus", SCARF, loc=(0, HUNCH - 0.01, 1.36), major_radius=0.12, minor_radius=0.05,
                        major_segments=14, minor_segments=6, jit=0.01, seed=6))
    parts.append(L.part("cube", SCARF, loc=(0.07, HUNCH - 0.15, 1.2), scale=(0.045, 0.02, 0.14),
                        rot=(8, 0, -6), jit=0.008, seed=7))
    # arms hanging slightly forward, sleeves with cuffs, hands
    for sx in (-1, 1):
        sh = Vector((sx * 0.25, HUNCH * 0.9, 1.22))
        wrist = Vector((sx * 0.31, HUNCH - 0.1, 0.8))
        parts.append(_painted(L.tube(sh, wrist, 0.065, 8, r_end=0.075), COAT, var=0.15, ao=0.2, seed=8))
        parts.append(L.part("torus", COAT_DARK, loc=wrist, major_radius=0.07, minor_radius=0.02,
                            major_segments=10, minor_segments=4))
        parts.append(L.part("sphere", SKIN, loc=wrist - Vector((0, 0.01, 0.06)), radius=0.052, segments=10,
                            ring_count=6, scale=(0.8, 1, 1.15), paint_kw={"ao": 0.2}))
    # head: long nose, beard, eyes in the shadow of the hat
    head_c = Vector((0, HUNCH - 0.07, 1.5))
    parts.append(L.part("sphere", SKIN, loc=head_c, radius=0.15, segments=14, ring_count=10,
                        scale=(0.95, 1, 1.08), paint_kw={"ao": 0.15, "var": 0.06}))
    parts.append(L.part("cone", L.scale_c(SKIN, 0.92), loc=head_c + Vector((0, -0.19, -0.03)), radius1=0.05,
                        depth=0.18, vertices=10, rot=(78, 0, 0)))
    parts.append(L.part("sphere", BEARD, loc=head_c + Vector((0, -0.1, -0.13)), radius=0.1, segments=12,
                        ring_count=8, scale=(0.95, 0.6, 0.8), jit=0.015, seed=9))
    for sx in (-1, 1):
        parts.append(L.part("sphere", L.hexc("#1B1715"), loc=head_c + Vector((sx * 0.06, -0.135, 0.03)),
                            radius=0.02, segments=6, ring_count=4))
    # wide, floppy, crooked hat (low crown)
    brim = L.prim("cyl", loc=head_c + Vector((0, 0, 0.11)), radius=0.38, depth=0.025, vertices=24)
    L.subdivide(brim, 1)
    for v in brim.data.vertices:
        rel = Vector((v.co.x - head_c.x, v.co.y - head_c.y))
        d = rel.length / 0.38
        a = math.atan2(rel.y, rel.x)
        v.co.z -= 0.07 * d * d * (0.6 + 0.4 * math.sin(a * 2.0 + 0.7))   # floppy droop
    L.jitter(brim, 0.012, 3.0, 10)
    crown = L.prim("cyl", loc=head_c + Vector((0, 0.01, 0.2)), radius=0.17, depth=0.18, vertices=12)
    L.subdivide(crown, 2)
    L.taper(crown, head_c.z + 0.11, head_c.z + 0.29, 0.72)
    L.bend(crown, 0.08, head_c.z + 0.11, head_c.z + 0.3)
    for v in crown.data.vertices:  # dented top
        if v.co.z > head_c.z + 0.27:
            v.co.z -= 0.03
    L.jitter(crown, 0.012, 3.0, 11)
    band = L.prim("cyl", loc=head_c + Vector((0, 0.01, 0.145)), radius=0.172, depth=0.045, vertices=12)
    for o, c in ((brim, HAT), (crown, HAT), (band, HAT_BAND)):
        parts.append(_painted(o, c, var=0.18, ao=0.1, top=0.22, seed=12))
    # shovel strapped diagonally to the back (blade up behind the left shoulder)
    back_y = 0.24
    parts.append(_painted(L.tube((0.24, back_y - 0.04, 0.5), (-0.34, back_y + 0.05, 1.3), 0.022, 6), WOOD, seed=15))
    blade = L.prim("cyl", loc=(-0.42, back_y + 0.06, 1.42), radius=0.1, depth=0.02, vertices=12,
                   scale=(1.0, 1.0, 1.35), rot=(90, 36, 0))  # rounded spade
    L.jitter(blade, 0.006, 5.0, 16)
    parts.append(_painted(blade, IRON, var=0.3, hue_shift=L.hexc("#6A4A3A"), seed=16))
    parts.append(L.part("torus", L.hexc("#2A2420"), loc=(0, back_y * 0.5 + HUNCH * 0.5, 1.02), rot=(0, 34, 0),
                        major_radius=0.3, minor_radius=0.014, major_segments=16, minor_segments=4, scale=(1, 0.75, 1)))
    # lantern on the belt (right hip)
    lp = Vector((0.31, HUNCH * 0.3 - 0.07, 0.72))
    parts.append(L.part("cube", IRON, loc=lp + Vector((0, 0, 0.07)), scale=(0.045, 0.045, 0.012)))
    parts.append(L.part("cube", IRON, loc=lp - Vector((0, 0, 0.07)), scale=(0.045, 0.045, 0.012)))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=lp, scale=(0.035, 0.035, 0.06)))
    obj = L.join(parts, "ph_chr_gravekeeper")
    L.marker(obj, "light_lantern", tuple(lp))
    L.finish(obj, "ph_chr_gravekeeper", "characters", 55)


if __name__ == "__main__":
    build()
