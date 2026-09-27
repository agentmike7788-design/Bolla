"""The gravekeeper (player). Stylised ~4.5 heads, hunched, long coat, shoulder
cape, wide crooked hat, shovel strapped to the back, lantern on the belt.
Front faces -Y (Blender) = +Z (Godot).
ART STYLE LOCK: the geometry below is the approved Phase-1 model, unchanged –
Phase 2 only adds the shared rig (rig.py, rigid skinning) and the actions
idle-loop, walk-loop, carry_idle-loop, carry_walk-loop, dig-loop, interact."""
import math

import bpy
from mathutils import Vector

import lib_painted as L
import rig

NAME = "ph_chr_gravekeeper"

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
WAIST_Z = 0.95  # coat below -> hips, above -> spine (seam between two coat rings, under the belt)
W = rig.weight


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


def build_mesh():
    """Approved Phase-1 geometry; every part rigidly weighted to one bone.
    Returns (mesh, lantern position) in model space (before grounding)."""
    L.reset(80)
    parts = []
    # boots (big) and thin legs
    for sx in (-1, 1):
        parts.append(W(_side(sx, "leg"), L.part("sphere", BOOT, loc=(sx * 0.11, -0.05, 0.07), scale=(0.085, 0.16, 0.075),
                                                segments=10, ring_count=6, jit=0.008, seed=1 + sx)))
        parts.append(W(_side(sx, "leg"), _painted(L.tube((sx * 0.1, 0, 0.1), (sx * 0.1, 0, 0.56), 0.05), TROUSER, seed=3)))
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
    parts.append(rig.weight_split_z(_painted(coat, COAT, var=0.18, ao=0.35, top=0.15, zrange=(0.36, 1.31), seed=5,
                                             hue_shift=COAT_DARK), WAIST_Z, "hips", "spine"))
    # coat front opening (dark strip) and belt
    parts.append(W("hips", L.part("cube", COAT_DARK, loc=(0, HUNCH * 0.35 - 0.205, 0.66), scale=(0.025, 0.02, 0.3),
                                  rot=(-6, 0, 0))))
    parts.append(W("hips", L.part("torus", L.hexc("#2A2420"), loc=(0, HUNCH * 0.3, 0.86), major_radius=0.265,
                                  minor_radius=0.025, major_segments=16, minor_segments=4, scale=(1, 0.8, 1))))
    # ragged shoulder cape: reads from the top-down camera
    cape = L.prim("cone", loc=(0, HUNCH, 1.2), radius1=0.36, radius2=0.12, depth=0.28, vertices=14)
    for v in cape.data.vertices:
        if v.co.z < 1.1:  # ragged hem
            a = math.atan2(v.co.y - HUNCH, v.co.x)
            v.co.z -= 0.04 * (0.5 + 0.5 * math.sin(a * 5.0))
    L.jitter(cape, 0.015, 3.0, 13)
    parts.append(W("spine", _painted(cape, CAPE, var=0.2, ao=0.25, top=0.2, seed=14)))
    # scarf (the one warm accent on the character)
    parts.append(W("spine", L.part("torus", SCARF, loc=(0, HUNCH - 0.01, 1.36), major_radius=0.12, minor_radius=0.05,
                                   major_segments=14, minor_segments=6, jit=0.01, seed=6)))
    parts.append(W("spine", L.part("cube", SCARF, loc=(0.07, HUNCH - 0.15, 1.2), scale=(0.045, 0.02, 0.14),
                                   rot=(8, 0, -6), jit=0.008, seed=7)))
    # arms hanging slightly forward, sleeves with cuffs, hands
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        sh = Vector((sx * 0.25, HUNCH * 0.9, 1.22))
        wrist = Vector((sx * 0.31, HUNCH - 0.1, 0.8))
        parts.append(W(bone, _painted(L.tube(sh, wrist, 0.065, 8, r_end=0.075), COAT, var=0.15, ao=0.2, seed=8)))
        parts.append(W(bone, L.part("torus", COAT_DARK, loc=wrist, major_radius=0.07, minor_radius=0.02,
                                    major_segments=10, minor_segments=4)))
        parts.append(W(bone, L.part("sphere", SKIN, loc=wrist - Vector((0, 0.01, 0.06)), radius=0.052, segments=10,
                                    ring_count=6, scale=(0.8, 1, 1.15), paint_kw={"ao": 0.2})))
    # head: long nose, beard, eyes in the shadow of the hat
    head_c = Vector((0, HUNCH - 0.07, 1.5))
    parts.append(W("head", L.part("sphere", SKIN, loc=head_c, radius=0.15, segments=14, ring_count=10,
                                  scale=(0.95, 1, 1.08), paint_kw={"ao": 0.15, "var": 0.06})))
    parts.append(W("head", L.part("cone", L.scale_c(SKIN, 0.92), loc=head_c + Vector((0, -0.19, -0.03)), radius1=0.05,
                                  depth=0.18, vertices=10, rot=(78, 0, 0))))
    parts.append(W("head", L.part("sphere", BEARD, loc=head_c + Vector((0, -0.1, -0.13)), radius=0.1, segments=12,
                                  ring_count=8, scale=(0.95, 0.6, 0.8), jit=0.015, seed=9)))
    for sx in (-1, 1):
        parts.append(W("head", L.part("sphere", L.hexc("#1B1715"), loc=head_c + Vector((sx * 0.06, -0.135, 0.03)),
                                      radius=0.02, segments=6, ring_count=4)))
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
        parts.append(W("head", _painted(o, c, var=0.18, ao=0.1, top=0.22, seed=12)))
    # shovel strapped diagonally to the back (blade up behind the left shoulder)
    back_y = 0.24
    parts.append(W("spine", _painted(L.tube((0.24, back_y - 0.04, 0.5), (-0.34, back_y + 0.05, 1.3), 0.022, 6), WOOD,
                                     seed=15)))
    blade = L.prim("cyl", loc=(-0.42, back_y + 0.06, 1.42), radius=0.1, depth=0.02, vertices=12,
                   scale=(1.0, 1.0, 1.35), rot=(90, 36, 0))  # rounded spade
    L.jitter(blade, 0.006, 5.0, 16)
    parts.append(W("spine", _painted(blade, IRON, var=0.3, hue_shift=L.hexc("#6A4A3A"), seed=16)))
    parts.append(W("spine", L.part("torus", L.hexc("#2A2420"), loc=(0, back_y * 0.5 + HUNCH * 0.5, 1.02), rot=(0, 34, 0),
                                   major_radius=0.3, minor_radius=0.014, major_segments=16, minor_segments=4,
                                   scale=(1, 0.75, 1))))
    # lantern on the belt (right hip)
    lp = Vector((0.31, HUNCH * 0.3 - 0.07, 0.72))
    parts.append(W("hips", L.part("cube", IRON, loc=lp + Vector((0, 0, 0.07)), scale=(0.045, 0.045, 0.012))))
    parts.append(W("hips", L.part("cube", IRON, loc=lp - Vector((0, 0, 0.07)), scale=(0.045, 0.045, 0.012))))
    parts.append(W("hips", L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=lp, scale=(0.035, 0.035, 0.06))))
    mesh = L.join(parts, rig.MESH)
    L.smooth(mesh, 55)
    return mesh, lp


def joints(dz: float) -> dict:
    """Bone head/tail from the model's proportions (dz = grounding shift)."""
    def p(x, y, z):
        return (x, y, z - dz)
    j = {
        "root": (p(0, 0, dz), p(0, 0, dz + 0.3)),
        "hips": (p(0, 0, 0.74), p(0, HUNCH * 0.1, 0.9)),
        "spine": (p(0, HUNCH * 0.1, 0.9), p(0, HUNCH * 0.95, 1.36)),
        "head": (p(0, HUNCH - 0.03, 1.37), p(0, HUNCH - 0.07, 1.72)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (p(sx * 0.25, HUNCH * 0.9, 1.22), p(sx * 0.31, HUNCH - 0.1, 0.8))
        j[_side(sx, "leg")] = (p(sx * 0.1, 0, 0.8), p(sx * 0.1, 0, 0.08))  # hip joint hidden in the coat
    return j


# --- actions (pose functions, see rig.py for the conventions) ---------------------

def idle(t: float) -> dict:
    """~2 s: slow breathing, the head sinks a little into the scarf."""
    return rig.breathe(t, 1.2)


def walk(t: float) -> dict:
    """16 frames = 0.53 s per cycle; 2 steps of ~0.8 m -> ~3 m/s (PlayerConfig 3.2). Hunched, brisk."""
    return rig.gait(t, leg=36.0, lift=0.06, arm=24.0, bob=0.03, roll=3.0, yaw=5.0, lean=7.0)


def _carry_arms(bounce: float) -> dict:
    """Both arms forward/down as if a body lies across the forearms in front."""
    return {"arm_l": (-50.0 + bounce, 14.0, 0.0), "arm_r": (-50.0 + bounce, -14.0, 0.0)}


def carry_idle(t: float) -> dict:
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.4), {"spine": (-5.0, 0.0, 0.0), "head": (3.0, 0.0, 0.0)},
                   _carry_arms(1.5 * s))


def carry_walk(t: float) -> dict:
    """20 frames = 0.67 s per cycle, shorter heavy steps (~2 m/s), waddling under the load."""
    c2 = math.cos(2.0 * rig.TAU * t)
    g = rig.gait(t, leg=29.0, lift=0.035, arm=0.0, bob=0.03, roll=5.0, yaw=3.0, lean=-4.0)
    return rig.add(g, _carry_arms(3.0 * c2), {"head": (4.0, 0.0, 0.0)})


def _stance() -> dict:
    return {"leg_l": (-9.0, 0.0, 0.0), "leg_r": (9.0, 0.0, 0.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}


def dig(t: float) -> dict:
    """36 frames = 1.2 s: jab the blade in, lever, lift, toss the earth to the right.
    (Arms hang from the spine: a forward bend swings them back, so they rotate
    further forward to keep the hands low in front.)"""
    wind = {"spine": (10.0, 0.0, 6.0), "head": (-4.0, 0.0, 0.0),
            "arm_l": (-62.0, 16.0, 0.0), "arm_r": (-48.0, -10.0, 0.0), "hips": (0, 0, 0, 0, 0.01, 0)}
    jab = {"spine": (32.0, 0.0, 0.0), "head": (-16.0, 0.0, 0.0),
           "arm_l": (-66.0, 14.0, 0.0), "arm_r": (-56.0, -8.0, 0.0), "hips": (4.0, 0, 0, 0, -0.02, -0.015)}
    lever = {"spine": (26.0, 0.0, 2.0), "head": (-12.0, 0.0, 0.0),
             "arm_l": (-44.0, 14.0, 0.0), "arm_r": (-62.0, -8.0, 0.0), "hips": (2.0, 0, 0, 0, -0.01, -0.01)}
    lift = {"spine": (14.0, 0.0, -4.0), "head": (-6.0, 0.0, 0.0),
            "arm_l": (-74.0, 18.0, 0.0), "arm_r": (-58.0, -6.0, 0.0)}
    toss = {"spine": (14.0, 0.0, -24.0), "head": (-2.0, 0.0, -10.0),
            "arm_l": (-88.0, 22.0, -14.0), "arm_r": (-60.0, 0.0, -20.0), "hips": (0, 0, -6.0, 0, 0.0, 0)}
    keys = [(0.0, wind), (0.28, jab), (0.45, lever), (0.62, lift), (0.8, toss)]
    return rig.add(_stance(), rig.keyed(t, keys))


def interact(t: float) -> dict:
    """24 frames = 0.8 s one-shot: lean in, reach forward with the right hand, back."""
    reach = {"spine": (14.0, 0.0, 4.0), "head": (-6.0, 0.0, 0.0),
             "arm_r": (-68.0, 10.0, 0.0), "arm_l": (-8.0, 0.0, 0.0), "hips": (0, 0, 0, 0, -0.03, 0)}
    return rig.add(rig.keyed(t, [(0.0, {}), (0.45, reach), (0.6, reach), (1.0, {})], wrap=False),
                   {"feet": {"leg_l": 0.0, "leg_r": 0.0}})


ACTIONS = (  # (name, frames at 30 fps, pose function)
    ("idle-loop", 60, idle),
    ("walk-loop", 16, walk),
    ("carry_idle-loop", 60, carry_idle),
    ("carry_walk-loop", 20, carry_walk),
    ("dig-loop", 36, dig),
    ("interact", 24, interact),
)


def build():
    mesh, lp = build_mesh()
    dz = rig.ground(mesh)
    arm = rig.build_armature(joints(dz))
    rig.bind(mesh, arm)
    rig.bone_marker(arm, "hips", "light_lantern", lp - Vector((0, 0, dz)))
    for name, frames, fn in ACTIONS:
        rig.add_action(arm, mesh, name, frames, fn)
    L.export_rigged(arm, NAME, "characters")


if __name__ == "__main__":
    build()
