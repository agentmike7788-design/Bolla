"""G8 Runde 4 (user: „ja die sollen eigene arbeitsbewegungen bekommen"): work clips of the villagers at their
work places, re-exported with the Phase-7 body, faces, materials and every older clip unchanged (the clips and
the child meshes below are added after them; test_assets_phase8 compares the body mesh hash and the old clips).

  ph_chr_v_innkeeper  polish_mug     behind the bar: a mug in the left hand, the rag in the right polishes it
                                     in circles, she holds it up to the light, sets it down again
  ph_chr_v_priest     pray_altar     before the altar (facing it): the hands on the breviary, the arms rise into
                                     the old praying gesture, he bows deeply
                      read_breviary  at the church door: the breviary raised in the left hand, he reads, the
                                     right hand turns a page
  ph_chr_v_mayor      desk_files     at the office desk: the left hand leafs through the files, then the stamp
                                     comes down; the right keeps the staff of office
                      proclaim       at the notice board: a notice held up in the left hand, he reads it out,
                                     looks up over it to the people
  ph_chr_v_surgeon    desk_write     at his desk: bent over, the quill writes in short lines, dips into the ink
                      mix_vial       at his desk: a vial lifted to the eye, swirled, set down; the case stays in
                                     the left hand
  ph_chr_v_washer     wash_brook     at the washing stones of the brook: bent deep, the cloth scrubbed on the
                                     stone, rinsed, wrung out between both fists
                      wash_body      at the table (the corpse wash): the wet cloth in long strokes along the body,
                                     the left hand steadies, wrung out over the basin

Rigid arms without elbows, legs without knees (rig.py): every movement reads with whole arm and leg parts; a
bow is the spine (and the hips sliding back), the feet stay planted (feet rule). Nothing is brought to the face.

Child meshes (Muster lantern_prop / ToolProps): small props on the arm bones, shown only with their clip
(glTF extras "show_with"): prop_mug, prop_rag (innkeeper), prop_stamp, prop_notice (mayor), prop_quill,
prop_vial (surgeon), prop_washcloth (washer). Each is modelled where the hand is in a reference pose of its clip
and carried back into the rest pose of the bone (hold), so it sits in the fist while the clip plays.
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh in the generators)
from mathutils import Euler, Matrix, Vector

import lib_painted as L
import rig
from asset_carter import sweep

PLANT = {"feet": {"leg_l": 0.0, "leg_r": 0.0}}

WOOD = L.hexc("#6E5640")
WOOD_DARK = L.hexc("#4A3A2C")
CLAY = L.hexc("#8A7A62")
CLAY_DARK = L.hexc("#4A3A2A")
LINEN = L.hexc("#C9C0AB")
LINEN_SHADE = L.hexc("#B3AA95")
LINEN_WET = L.hexc("#9C968A")
PAPER = L.hexc("#D2C8AE")
INK = L.hexc("#3A3530")
BRASS = L.hexc("#8C7648")
FEATHER = L.hexc("#D8D2C4")
FEATHER_SHADE = L.hexc("#A8A296")
GLASS = L.hexc("#6E7A5E")         # old green bottle glass, painted (no glow)
GLASS_LIGHT = L.hexc("#93A07E")
CORK = L.hexc("#8A6E4E")


def _p(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _ease(x: float) -> float:
    return rig.ease(x)


def _window(t: float, a: float, b: float, ramp: float = 0.06) -> float:
    """1 inside [a, b], easing to 0 over `ramp` outside (0 at t = 0 / 1 for a loop when a > ramp, b < 1 - ramp)."""
    if t < a:
        return _ease(1.0 - (a - t) / ramp) if t > a - ramp else 0.0
    if t > b:
        return _ease(1.0 - (t - b) / ramp) if t < b + ramp else 0.0
    return 1.0


def _loop(keys, extra=None, breath: float = 0.8):
    """A loop pose function from key poses (wrap) + breathing + planted feet (+ an additive extra(t))."""
    def fn(t: float) -> dict:
        p = rig.add(rig.breathe(t, breath), rig.keyed(t, keys))
        if extra is not None:
            p = rig.add(p, extra(t))
        p["feet"] = {"leg_l": 0.0, "leg_r": 0.0}
        return p
    return fn


# ======================================================================================================
# poses per figure
# ======================================================================================================

# --- Rosine: polishing a mug behind the bar (90 frames = 3 s; the counter top ~1.0 m, 0.3 m in front) ---
INN_HOLD = {"arm_l": (-66.0, 20.0, -18.0), "arm_r": (-62.0, -24.0, 22.0), "spine": (6.0, 0.0, 0.0), "head": (18.0, 0.0, 0.0)}
INN_LOOK = {"arm_l": (-84.0, 18.0, -14.0), "arm_r": (-30.0, -8.0, 6.0), "spine": (1.0, 0.0, 2.0), "head": (-6.0, 0.0, 4.0)}
INN_SET = {"arm_l": (-54.0, 18.0, -14.0), "arm_r": (-52.0, -20.0, 16.0), "spine": (12.0, 0.0, 0.0), "head": (22.0, 0.0, 0.0)}


def polish_mug():
    keys = [(0.0, INN_HOLD), (0.58, INN_HOLD), (0.7, INN_LOOK), (0.8, INN_LOOK), (0.9, INN_SET)]

    def circles(t: float) -> dict:
        w = _window(t, 0.06, 0.52)
        a = rig.TAU * t * 5.0
        return {"arm_r": (5.0 * w * math.sin(a), 0.0, 7.0 * w * math.cos(a) - 7.0 * w),
                "head": (0.0, 0.0, 1.5 * w * math.sin(a))}
    return _loop(keys, circles, 0.9)


# --- Lenz: praying before the altar (90 frames = 3 s; he faces the altar) -------------------------------
# His left forearm is modelled bent, the breviary pressed to the belly; the rest pose already holds it.
PR_FOLD = {"arm_r": (-30.0, -24.0, 18.0), "spine": (4.0, 0.0, 0.0), "head": (14.0, 0.0, 0.0)}
PR_ORANS = {"arm_r": (-72.0, 34.0, -8.0), "arm_l": (-62.0, -46.0, 10.0), "spine": (-4.0, 0.0, 0.0), "head": (-10.0, 0.0, 0.0)}
PR_BOW = {"arm_r": (-24.0, -22.0, 16.0), "arm_l": (8.0, 0.0, 0.0), "spine": (26.0, 0.0, 0.0), "head": (26.0, 0.0, 0.0),
          "hips": (4.0, 0.0, 0.0, 0.0, 0.02, -0.01)}


def pray_altar():
    keys = [(0.0, PR_FOLD), (0.1, PR_FOLD), (0.28, PR_ORANS), (0.5, PR_ORANS), (0.64, PR_FOLD), (0.74, PR_BOW),
            (0.88, PR_BOW)]
    return _loop(keys, None, 0.9)


# --- Lenz: reading the breviary at the church door (90 frames = 3 s) ------------------------------------
PR_READ = {"arm_l": (-26.0, 4.0, 0.0), "arm_r": (-10.0, -4.0, 4.0), "spine": (3.0, 0.0, 0.0), "head": (20.0, 0.0, 4.0)}
PR_PAGE_A = {"arm_l": (-28.0, 4.0, 0.0), "arm_r": (-62.0, -10.0, 30.0), "spine": (4.0, 0.0, 0.0), "head": (22.0, 0.0, 2.0)}
PR_PAGE_B = {"arm_l": (-28.0, 4.0, 0.0), "arm_r": (-58.0, -6.0, 8.0), "spine": (4.0, 0.0, 0.0), "head": (20.0, 0.0, -4.0)}


def read_breviary():
    keys = [(0.0, PR_READ), (0.5, PR_READ), (0.62, PR_PAGE_A), (0.72, PR_PAGE_B), (0.84, PR_READ)]

    def lines(t: float) -> dict:
        w = _window(t, 0.08, 0.46)
        return {"head": (1.5 * w * math.sin(rig.TAU * t * 4.0), 0.0, 4.0 * w * math.sin(rig.TAU * t * 2.0))}
    return _loop(keys, lines, 0.8)


# --- Fenner: files and the stamp at the desk (90 frames = 3 s; desk top 0.8 m; the right hand keeps the staff)
MY_KEEP = (-20.0, 0.0, 0.0)   # the right arm undoes the spine's lean (-spine): the staff stays upright beside him
MY_LEAF_A = {"arm_l": (-34.0, 26.0, -20.0), "arm_r": MY_KEEP, "spine": (20.0, 0.0, 0.0), "head": (14.0, 0.0, -6.0)}
MY_LEAF_B = {"arm_l": (-32.0, 8.0, 10.0), "arm_r": MY_KEEP, "spine": (20.0, 0.0, 2.0), "head": (14.0, 0.0, 6.0)}
MY_STAMP_UP = {"arm_l": (-74.0, 16.0, -8.0), "arm_r": (-8.0, 0.0, 0.0), "spine": (8.0, 0.0, 0.0), "head": (12.0, 0.0, 0.0)}
MY_STAMP_DOWN = {"arm_l": (-30.0, 18.0, -10.0), "arm_r": (-22.0, 0.0, 0.0), "spine": (22.0, 0.0, 0.0), "head": (18.0, 0.0, 0.0)}


def desk_files():
    keys = [(0.0, MY_LEAF_A), (0.12, MY_LEAF_B), (0.24, MY_LEAF_A), (0.36, MY_LEAF_B), (0.48, MY_LEAF_A),
            (0.6, MY_STAMP_UP), (0.66, MY_STAMP_DOWN), (0.74, MY_STAMP_DOWN), (0.82, MY_STAMP_UP), (0.88, MY_STAMP_DOWN)]
    return _loop(keys, None, 0.7)


# --- Fenner: reading out the notices at the board (90 frames = 3 s; he faces the green, the board behind) ---
MY_KEEP_UP = (-2.0, 0.0, 0.0)
MY_READ = {"arm_l": (-60.0, 8.0, -14.0), "arm_r": MY_KEEP_UP, "spine": (-2.0, 0.0, 0.0), "head": (14.0, 0.0, -4.0)}
MY_LOOK = {"arm_l": (-52.0, 8.0, -12.0), "arm_r": MY_KEEP_UP, "spine": (-3.0, 0.0, 4.0), "head": (-4.0, 0.0, 10.0)}
MY_LOOK_B = {"arm_l": (-54.0, 8.0, -12.0), "arm_r": MY_KEEP_UP, "spine": (-3.0, 0.0, -3.0), "head": (-3.0, 0.0, -12.0)}


def proclaim():
    keys = [(0.0, MY_READ), (0.4, MY_READ), (0.52, MY_LOOK), (0.66, MY_LOOK), (0.78, MY_LOOK_B), (0.9, MY_READ)]

    def speak(t: float) -> dict:
        w = _window(t, 0.08, 0.38)
        return {"head": (2.0 * w * math.sin(rig.TAU * t * 6.0), 0.0, 3.0 * w * math.sin(rig.TAU * t * 2.0)),
                "arm_l": (2.0 * w * math.sin(rig.TAU * t * 3.0), 0.0, 0.0)}
    return _loop(keys, speak, 0.9)


# --- Quast: writing at the desk (90 frames = 3 s; desk top 0.85 m; the case hangs from the left hand) -------
SU_LEAN = 18.0
SU_BAG = (-SU_LEAN, 0.0, 0.0)     # the left arm undoes the lean: the case hangs plumb
SU_WRITE = {"arm_r": (-50.0, -18.0, 16.0), "arm_l": SU_BAG, "spine": (SU_LEAN, 0.0, 0.0), "head": (18.0, 0.0, 0.0),
            "hips": (3.0, 0.0, 0.0, 0.0, 0.02, 0.0)}
SU_DIP = {"arm_r": (-58.0, -4.0, -6.0), "arm_l": SU_BAG, "spine": (SU_LEAN, 0.0, -4.0), "head": (16.0, 0.0, -10.0),
          "hips": (3.0, 0.0, 0.0, 0.0, 0.02, 0.0)}


def desk_write():
    keys = [(0.0, SU_WRITE), (0.6, SU_WRITE), (0.7, SU_DIP), (0.78, SU_DIP), (0.88, SU_WRITE)]

    def scribble(t: float) -> dict:
        w = _window(t, 0.08, 0.56)
        line = (t / 0.6) % (1.0 / 3.0) * 3.0     # three lines, each drawn from left to right
        sweep_z = -10.0 * (line - 0.5) * w
        return {"arm_r": (2.0 * w * math.sin(rig.TAU * t * 14.0), 0.0, sweep_z + 1.5 * w * math.sin(rig.TAU * t * 21.0)),
                "head": (0.0, 0.0, 0.4 * sweep_z)}
    return _loop(keys, scribble, 0.6)


# --- Quast: a vial lifted to the eye and swirled (90 frames = 3 s) -----------------------------------------
SU_DOWN = {"arm_r": (-52.0, -16.0, 14.0), "arm_l": (-10.0, 0.0, 0.0), "spine": (10.0, 0.0, 0.0), "head": (16.0, 0.0, 0.0),
           "hips": (2.0, 0.0, 0.0, 0.0, 0.01, 0.0)}
SU_UP = {"arm_r": (-92.0, -14.0, 18.0), "arm_l": (0.0, 0.0, 0.0), "spine": (0.0, 0.0, -2.0), "head": (-4.0, 0.0, -10.0)}


def mix_vial():
    keys = [(0.0, SU_DOWN), (0.14, SU_DOWN), (0.3, SU_UP), (0.66, SU_UP), (0.82, SU_DOWN)]

    def swirl(t: float) -> dict:
        w = _window(t, 0.32, 0.64)
        a = rig.TAU * t * 8.0
        return {"arm_r": (3.0 * w * math.sin(a), 0.0, 4.0 * w * math.cos(a) - 4.0 * w)}
    return _loop(keys, swirl, 0.7)


# --- Liesel: washing at the brook stones (90 frames = 3 s): she kneels on the bank, scrubs the cloth on the
# flat stone in front (~0.3 m), rinses it, straightens on her knees and wrings it out ------------------------
def _kneel(spine: float, head: float, arm_l, arm_r) -> dict:
    p = rig.kneel(0.42, 12.0, spine, head, hands=(0.0, 0.0))
    p["arm_l"] = tuple(arm_l)
    p["arm_r"] = tuple(arm_r)
    return p


WA_SCRUB_A = _kneel(34.0, -14.0, (-46.0, 14.0, -8.0), (-66.0, -12.0, 8.0))
WA_SCRUB_B = _kneel(36.0, -14.0, (-46.0, 14.0, -8.0), (-42.0, -14.0, 10.0))
WA_WRING = _kneel(6.0, 12.0, (-50.0, 24.0, -20.0), (-50.0, -24.0, 20.0))


def wash_brook():
    keys = [(0.0, WA_SCRUB_A), (0.1, WA_SCRUB_B), (0.2, WA_SCRUB_A), (0.3, WA_SCRUB_B), (0.4, WA_SCRUB_A),
            (0.56, WA_WRING), (0.8, WA_WRING), (0.94, WA_SCRUB_A)]

    def wring(t: float) -> dict:
        w = _window(t, 0.6, 0.78, 0.04)
        s = math.sin(rig.TAU * t * 9.0)
        return {"arm_l": (0.0, 0.0, 10.0 * w * s), "arm_r": (0.0, 0.0, 10.0 * w * s), "head": (0.0, 0.0, 2.0 * w * s)}
    return _loop(keys, wring, 0.6)


# --- Liesel: washing the dead at the table (90 frames = 3 s; she stands behind the table) ------------------
WB_STEADY = (-40.0, 20.0, -14.0)
WB_STROKE_A = {"spine": (22.0, 0.0, -6.0), "head": (18.0, 0.0, -8.0), "arm_l": WB_STEADY, "arm_r": (-46.0, -6.0, -12.0),
               "hips": (3.0, 0.0, 0.0, 0.0, 0.02, -0.01)}
WB_STROKE_B = {"spine": (24.0, 0.0, 6.0), "head": (20.0, 0.0, 8.0), "arm_l": WB_STEADY, "arm_r": (-46.0, -26.0, 30.0),
               "hips": (3.0, 0.0, 0.0, 0.0, 0.02, -0.01)}
WB_WRING = {"spine": (8.0, 0.0, 0.0), "head": (14.0, 0.0, 0.0), "arm_l": (-42.0, 24.0, -20.0), "arm_r": (-42.0, -24.0, 20.0)}




def wash_body():
    keys = [(0.0, WB_STROKE_A), (0.22, WB_STROKE_B), (0.32, WB_STROKE_A), (0.54, WB_STROKE_B), (0.66, WB_WRING),
            (0.84, WB_WRING)]

    def wring(t: float) -> dict:
        w = _window(t, 0.7, 0.82, 0.04)
        s = math.sin(rig.TAU * t * 9.0)
        return {"arm_l": (0.0, 0.0, 10.0 * w * s), "arm_r": (0.0, 0.0, 10.0 * w * s)}
    return _loop(keys, wring, 0.6)


# ======================================================================================================
# props (child meshes): modelled in a "hand frame" (grip at the origin, +Z up in the world while the clip's
# reference pose is held), carried back into the bone's rest pose by hold()
# ======================================================================================================

def mug():
    """A stoneware mug (Krug), 0.13 m: body, dark inside, handle. ~110 tris."""
    parts = [_p(L.prim("cyl", loc=(0, 0, 0.0), radius=0.042, depth=0.13, vertices=10), CLAY, var=0.12, ao=0.2, top=0.3, seed=1),
             _p(L.prim("cyl", loc=(0, 0, 0.064), radius=0.036, depth=0.004, vertices=10), CLAY_DARK, var=0.05, ao=0.0),
             _p(L.prim("torus", loc=(0.05, 0, 0.0), rot=(90, 0, 0), major_radius=0.028, minor_radius=0.008, major_segments=8,
                       minor_segments=4), CLAY, ao=0.0)]
    return L.join(parts, "prop_mug")


def rag():
    """The bar rag: a crumpled linen ball with a hanging tail. ~90 tris."""
    ball = L.prim("sphere", loc=(0, 0, 0), radius=1.0, scale=(0.05, 0.04, 0.035), segments=8, ring_count=5)
    L.jitter(ball, 0.008, 30.0, 3)
    tail = sweep([Vector((0.0, -0.01, -0.01)), Vector((0.01, -0.02, -0.08)), Vector((0.0, -0.015, -0.14))], [0.03, 0.028, 0.022],
                 n=5, flat=0.25, name="tail")
    return L.join([_p(ball, LINEN, var=0.12, ao=0.1, top=0.2, seed=4), _p(tail, LINEN_SHADE, var=0.1, ao=0.1, seed=5)], "prop_rag")


def stamp():
    """The office stamp: a turned wooden knob and handle, a brass foot (the grip round the handle). ~60 tris."""
    parts = [_p(L.prim("sphere", loc=(0, 0, 0.045), radius=0.022, segments=6, ring_count=4), WOOD, var=0.12, ao=0.0, top=0.3),
             _p(L.tube(Vector((0, 0, 0.03)), Vector((0, 0, -0.03)), 0.012, 5), WOOD_DARK, var=0.1, ao=0.0),
             _p(L.prim("cyl", loc=(0, 0, -0.042), radius=0.026, depth=0.024, vertices=6), BRASS, var=0.1, ao=0.0, top=0.5)]
    return L.join(parts, "prop_stamp")


def notice():
    """A notice sheet held up at its lower edge: 0.24 x 0.3 m paper (a thin slab, so it reads from both sides),
    a darker band of writing on the side facing him. ~20 tris."""
    sheet = L.prim("cube", loc=(0, 0.0, 0.13), scale=(0.12, 0.003, 0.15))
    _p(sheet, PAPER, var=0.06, ao=0.0, top=0.0, seed=6)
    attr = sheet.data.color_attributes["Col"]
    for poly in sheet.data.polygons:
        if poly.normal.y > 0.5:    # the written side (towards his face)
            for li in poly.loop_indices:
                c = attr.data[li].color
                attr.data[li].color = (c[0] * 0.8, c[1] * 0.8, c[2] * 0.78, 1.0)
    seal = L.prim("cyl", loc=(0.06, -0.004, 0.04), rot=(90, 0, 0), radius=0.016, depth=0.004, vertices=6)
    _p(seal, L.hexc("#6E3A2E"), var=0.08, ao=0.0)    # the red-brown wax seal of the office
    return L.join([sheet, seal], "prop_notice")


def quill():
    """A goose quill held for writing: the shaft through the fist, the vane up and back. ~70 tris."""
    shaft = L.tube(Vector((0, 0, -0.05)), Vector((0, 0.03, 0.17)), 0.0035, 4)
    vane = sweep([Vector((0, 0.008, 0.04)), Vector((0.0, 0.02, 0.11)), Vector((0.0, 0.03, 0.18))], [0.006, 0.016, 0.004], n=4,
                 flat=0.2, name="vane")
    return L.join([_p(shaft, INK, var=0.05, ao=0.0), _p(vane, FEATHER, var=0.08, ao=0.0, top=0.3, hue_shift=FEATHER_SHADE)],
                  "prop_quill")


def vial():
    """A small apothecary vial with a cork, 0.11 m, held round the belly. ~90 tris."""
    body = L.prim("cyl", loc=(0, 0, 0.02), radius=0.022, depth=0.07, vertices=8)
    neck = L.prim("cyl", loc=(0, 0, 0.067), radius=0.009, depth=0.024, vertices=8)
    cork = L.prim("cyl", loc=(0, 0, 0.084), radius=0.01, depth=0.014, vertices=8)
    return L.join([_p(body, GLASS, var=0.1, ao=0.0, top=0.6, hue_shift=GLASS_LIGHT), _p(neck, GLASS, var=0.08, ao=0.0, top=0.5),
                   _p(cork, CORK, var=0.1, ao=0.0)], "prop_vial")


def washcloth():
    """The wet washing cloth: a soaked linen bundle with a dripping tail. ~90 tris."""
    ball = L.prim("sphere", loc=(0, 0, 0), radius=1.0, scale=(0.055, 0.045, 0.04), segments=8, ring_count=5)
    L.jitter(ball, 0.008, 28.0, 8)
    tail = sweep([Vector((0.0, -0.01, -0.02)), Vector((0.012, -0.02, -0.1)), Vector((0.004, -0.018, -0.17))],
                 [0.034, 0.03, 0.02], n=5, flat=0.25, name="tail")
    return L.join([_p(ball, LINEN_WET, var=0.12, ao=0.1, top=0.3, seed=9), _p(tail, LINEN_WET, var=0.1, ao=0.1, seed=10)],
                  "prop_washcloth")


# ======================================================================================================
# per figure: clips (name, frames, pose fn) and props (child name, bone, builder, clip, reference pose,
# offset of the grip from the fist centre in the posed world (m), turn of the prop about the world Z (deg))
# ======================================================================================================

WORK = {
    "ph_chr_v_innkeeper": {
        "clips": [("polish_mug-loop", 90, polish_mug)],
        "props": [("prop_mug", "arm_l", mug, "polish_mug", INN_HOLD, (0.0, -0.01, 0.07), 90.0),
                  ("prop_rag", "arm_r", rag, "polish_mug", INN_HOLD, (0.0, -0.01, 0.0), 0.0)],
    },
    "ph_chr_v_priest": {
        "clips": [("pray_altar-loop", 90, pray_altar), ("read_breviary-loop", 90, read_breviary)],
        "props": [],
    },
    "ph_chr_v_mayor": {
        "clips": [("desk_files-loop", 90, desk_files), ("proclaim-loop", 90, proclaim)],
        "props": [("prop_stamp", "arm_l", stamp, "desk_files", MY_STAMP_DOWN, (0.0, 0.0, 0.0), 0.0),
                  ("prop_notice", "arm_l", notice, "proclaim", MY_READ, (0.0, 0.0, 0.0), 0.0)],
    },
    "ph_chr_v_surgeon": {
        "clips": [("desk_write-loop", 90, desk_write), ("mix_vial-loop", 90, mix_vial)],
        "props": [("prop_quill", "arm_r", quill, "desk_write", SU_WRITE, (0.0, 0.0, 0.0), 0.0),
                  ("prop_vial", "arm_r", vial, "mix_vial", SU_UP, (0.0, 0.0, 0.0), 0.0)],
    },
    "ph_chr_v_washer": {
        "clips": [("wash_brook-loop", 90, wash_brook), ("wash_body-loop", 90, wash_body)],
        "props": [("prop_washcloth", "arm_r", washcloth, "wash_brook,wash_body", WA_SCRUB_A, (0.0, 0.0, -0.02), 0.0)],
    },
}


def clip_names(name: str) -> list:
    cfg = WORK.get(name)
    return [] if cfg is None else [c[0][:-5] if c[0].endswith("-loop") else c[0] for c in cfg["clips"]]


def _pose_matrix(arm, pose: dict, bone: str) -> Matrix:
    """Armature-space transform of `bone` from its rest to `pose` (rig._apply for every bone, no feet rule)."""
    rest = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
    for b in rig.bone_names(arm):
        rig._apply(arm, rest, b, pose.get(b, rig.ZERO))
    bpy.context.view_layer.update()
    m = arm.pose.bones[bone].matrix @ arm.data.bones[bone].matrix_local.inverted()
    rig.reset_pose(arm)
    return m


def fist(mesh, bone: str) -> Vector:
    """The hand of a rigid arm: the centre of its lowest 8 cm (as asset_villagers._fist)."""
    gi = mesh.vertex_groups[bone].index
    vs = [v.co.copy() for v in mesh.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    z0 = min(v.z for v in vs)
    sel = [v for v in vs if v.z < z0 + 0.08]
    return sum(sel, Vector()) / len(sel)


def hold(arm, mesh, obj, bone: str, pose: dict, offset=(0.0, 0.0, 0.0), turn: float = 0.0) -> None:
    """Carry `obj` (hand frame) to the fist of `bone` as it is in `pose`, upright in the world, then back into the
    bone's rest pose: while the clip holds that pose, the prop sits in the fist the way it was modelled."""
    a = _pose_matrix(arm, pose, bone)
    posed = a @ fist(mesh, bone) + Vector(offset)
    world = Matrix.Translation(posed) @ Matrix.Rotation(math.radians(turn), 4, "Z")
    obj.data.transform(a.inverted() @ world)
    obj.data.update()


def build_for(name: str, arm, mesh):
    """(actions, child meshes [(name, bone, obj, show tuple)]) for figure `name` (empty if it has no work clips).
    Call after rig.bind (mesh grounded, armature built)."""
    cfg = WORK.get(name)
    if cfg is None:
        return [], []
    actions = [(n, f, fn()) for n, f, fn in cfg["clips"]]
    kids = []
    for cname, bone, maker, show, pose, off, turn in cfg["props"]:
        obj = maker()
        hold(arm, mesh, obj, bone, pose, off, turn)
        L.smooth(obj, 55)
        kids.append((cname, bone, obj, tuple(show.split(","))))
    return actions, kids


def probe(name: str, arm, mesh) -> None:
    """Debug (VW_PROBE=1): posed fist and head positions of every key pose (Blender axes: -Y = front)."""
    cfg = WORK.get(name)
    if cfg is None:
        return
    import sys
    mod = sys.modules[__name__]
    for key in dir(mod):
        val = getattr(mod, key)
        if not (key.isupper() and isinstance(val, dict) and ("arm_l" in val or "arm_r" in val)):
            continue
        out = []
        for b in ("arm_l", "arm_r"):
            m = _pose_matrix(arm, val, b)
            p = m @ fist(mesh, b)
            out.append("%s(%.2f %.2f %.2f)" % (b, p.x, p.y, p.z))
        h = _pose_matrix(arm, val, "head") @ Vector(arm.data.bones["head"].head_local)
        print("[probe] %s %-12s %s head(%.2f %.2f %.2f)" % (name, key, " ".join(out), h.x, h.y, h.z))
