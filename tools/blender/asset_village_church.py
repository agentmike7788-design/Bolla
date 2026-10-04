"""G7 round 1: the village church of Hollerbrueck walk-in (St. Gallus am Anger), 'Gemaltes Diorama'.

Like the chapel (asset_interiors_phase6.chapel_room) the room is a diorama for the fixed interior
camera: the south wall (Blender -Y = Godot +Z, towards the camera) is only a low stub with the door
gap, no ceiling (rafter stubs on the wall plates), the cut edges sit on a band of rough stones.
Quiet and warm: lime-washed walls, worn flag floor, a raised chancel, tall windows. Pews, altar and
the candle stand are the chapel's models (ph_int_pew, ph_int_altar, ph_int_candelabrum); the layout
data/world/interiors/church_layout.json places everything.

  ph_int_church_room     nave 6.4 x 9 m, chancel step (0.18 m) at the north end, a tall coloured
                         window behind the altar (light_window_3, warm reds / golds / greens, no
                         figures), one tall clear window in the west and east walls (light_window_1/2,
                         daylight), a hanging iron candle ring over the nave (light_lantern: the shadow
                         light at night). door_inside, spawn_inside
  ph_int_church_pulpit   wooden pulpit on a stone column with a short stair (east wall)
  ph_int_church_font     baptismal font: octagonal stone basin on a pillar, wooden lid with a knob
  ph_int_church_poor_box Opferstock: an iron-bound wooden post with a coin box on top
  ph_int_church_memorial memorial board for the dead of the parish: framed board with blank name
                         plates (no text), a small shelf with a candle; pivot bottom centre, hung

Run:  python tools/blender/build_all.py asset_village_church
"""
import math
import random

import bpy  # must be imported before bmesh  # noqa: F401
from mathutils import Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_buildings_phase6 as B
import asset_interiors_phase6 as I6
from asset_interior import _candle, _flame, _lathe

CAT = "interior"
NX, NY = 3.2, 4.5          # inner half extents of the nave
N_WALL = 4.0               # wall plate height
CH_Y0 = 2.7                # the chancel starts here (to the north wall)
CH_STEP = 0.18
SIDE_WIN = (0.0, 0.8, 1.7, 3.2)          # (y, width, sill, spring) west / east
NORTH_WIN = (0.0, 1.1, 1.9, 3.3)         # (x, width, sill, spring) behind the altar
DOOR_W = 1.2
LIME = L.hexc("#BDB2A0")                 # warm lime wash
LIME_SHADE = L.hexc("#A89C88")
FLAG_A, FLAG_B, FLAG_C = L.hexc("#8E887C"), L.hexc("#837D72"), L.hexc("#958E80")
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
IRON = P.IRON
BRASS = L.hexc("#8E7F55")
STONE_PALE = B.STONE_PALE
STONE_OLD = B.STONE_OLD
PLATE = L.hexc("#CFC4A8")


def _plaster(parts, axis, plane, out, a0, a1, z0, z1, holes=(), seed=0, top=None, arch=True):
    I6._plaster_face(parts, axis, plane, out, a0, a1, z0, z1, holes, seed=seed, top=top, arch=arch)


def church_room():
    L.reset(7800)
    random.seed(7800)
    parts = []
    worn = lambda u, v: math.exp(-((u / 0.7) ** 2)) * 0.9  # noqa: E731 - the worn middle aisle
    I6._flags(parts, -NX, NX, -NY, CH_Y0, 0.0, tw=0.55, th=0.5, cols=(FLAG_A, FLAG_B, FLAG_C), worn=worn)
    I6._flags(parts, -NX, NX, CH_Y0 + 0.02, NY, CH_STEP, tw=0.5, th=0.5, cols=(FLAG_A, FLAG_C))
    parts.append(I6._slab((0.0, CH_Y0, CH_STEP / 2), (NX, 0.06, CH_STEP / 2), STONE_PALE, seed=1, var=0.12, ao=0.2, top=0.3))
    # side walls with one tall clear window each, the north wall with the coloured window
    y, w, sill, spring = SIDE_WIN
    for sx in (-1, 1):
        _plaster(parts, "x", sx * NX, -sx, -NY, NY, 0.0, N_WALL, [(y, w, sill, spring)], seed=10 + sx)
        I6._inner_window(parts, "x", sx * NX, -sx, y, w, sill, spring, 7810 + sx * 7)
    x, w2, sill2, spring2 = NORTH_WIN
    _plaster(parts, "y", NY, -1, -NX, NX, CH_STEP, N_WALL + 1.0, [(x, w2, sill2, spring2)], seed=30,
             top=lambda a: N_WALL + 1.0 - 0.6 * (abs(a) / NX) ** 2)
    I6._inner_window(parts, "y", NY, -1, x, w2, sill2, spring2, 7830, stained=True)
    # south stub with the door gap, stone jambs
    _plaster(parts, "y", -NY, 1, -NX, NX, 0.0, 0.45, [(0.0, DOOR_W, 0.0, 0.45)], seed=40, arch=False)
    for sx in (-1, 1):
        parts.append(I6._slab((sx * (DOOR_W / 2 + 0.1), -NY - 0.1, 0.55), (0.1, 0.12, 0.55), STONE_PALE, seed=42 + sx,
                              var=0.14, ao=0.3))
    # a low painted dado band and the wall plates with rafter stubs (the roof is cut away)
    for sx in (-1, 1):
        parts.append(I6._slab((sx * (NX - 0.02), 0.0, 0.55), (0.02, NY - 0.05, 0.55), LIME_SHADE, seed=50 + sx, var=0.1,
                              ao=0.25))
        parts.append(I6._slab((sx * (NX - 0.04), 0.0, 1.12), (0.04, NY - 0.05, 0.025), WOOD_DARK, seed=52 + sx, var=0.12,
                              ao=0.0, top=0.3))
        parts.append(I6._slab((sx * (NX - 0.1), 0.0, N_WALL + 0.06), (0.1, NY, 0.08), WOOD_DARK, cuts=1, seed=54 + sx,
                              var=0.15, ao=0.0))
        for k in range(7):
            yy = -NY + 0.5 + k * (2 * NY - 1.0) / 6
            p0 = Vector((sx * (NX - 0.1), yy, N_WALL + 0.1))
            p1 = p0 + Vector((-sx * math.cos(math.radians(50)), 0, math.sin(math.radians(50)))) * 0.8
            parts.append(P._stick(p0, p1, 0.06, WOOD_DARK, verts=4, seed=56 + k, ao=0.1))
    # the hanging candle ring over the nave (iron ring, six candles, three chains)
    ring_c = Vector((0.0, -0.4, 3.0))
    parts.append(L.part("torus", IRON, loc=ring_c, major_radius=0.45, minor_radius=0.02, major_segments=16, minor_segments=4))
    for k in range(6):
        a = k / 6 * math.tau
        px, py = ring_c.x + math.cos(a) * 0.45, ring_c.y + math.sin(a) * 0.45
        parts.append(L.part("cyl", IRON, loc=(px, py, ring_c.z + 0.02), radius=0.035, depth=0.02, vertices=8))
        fb = _candle(parts, px, py, ring_c.z + 0.03, 0.14, 0.018, seed=60 + k, drips=1)
        _flame(parts, fb, 0.045, 0.012)
    for k in range(3):
        a = k / 3 * math.tau + 0.5
        p0 = ring_c + Vector((math.cos(a) * 0.45, math.sin(a) * 0.45, 0.0))
        parts.append(P._stick(p0, Vector((ring_c.x, ring_c.y, N_WALL + 0.3)), 0.006, IRON, verts=4, seed=70 + k, ao=0.0))
    I6._cut_band(parts, -NX - 0.2, NX + 0.2, -NY - 0.2, NY, 90)
    markers = [("door_inside", (0.0, -NY + 0.3, 0.0)), ("spawn_inside", (0.0, -NY + 0.85, 0.0)),
               ("light_window_1", (-(NX - 0.45), SIDE_WIN[0], (SIDE_WIN[2] + SIDE_WIN[3]) / 2)),
               ("light_window_2", (NX - 0.45, SIDE_WIN[0], (SIDE_WIN[2] + SIDE_WIN[3]) / 2)),
               ("light_window_3", (NORTH_WIN[0], NY - 0.5, (NORTH_WIN[2] + NORTH_WIN[3]) / 2)),
               ("light_lantern", (ring_c.x, ring_c.y, ring_c.z + 0.25))]
    I6._done(parts, "ph_int_church_room", markers, 30)


def church_pulpit():
    """Pulpit: a panelled wooden tub (top 1.95 m) on a stone column, four steps up its west side."""
    L.reset(7820)
    random.seed(7820)
    parts = []
    col = _lathe([(0.24, 0.0), (0.24, 0.08), (0.14, 0.14), (0.12, 1.0), (0.2, 1.08), (0.0, 1.08)], 8, "col")
    parts.append(B._paint(col, STONE_PALE, var=0.14, ao=0.35, top=0.2, hue_shift=STONE_OLD))
    tub_r, z0, z1 = 0.48, 1.08, 1.95
    for k in range(8):
        a = k / 8 * math.tau
        c = Vector((math.cos(a) * tub_r, math.sin(a) * tub_r, (z0 + z1) / 2))
        parts.append(I6._slab(c, (0.19, 0.03, (z1 - z0) / 2), L.scale_c(WOOD, random.uniform(0.92, 1.06)),
                              rot=(0, 0, math.degrees(a) + 90), seed=k, var=0.12, ao=0.2))
        parts.append(I6._slab(c * Vector((1.06, 1.06, 1.0)), (0.13, 0.008, (z1 - z0) / 2 - 0.1), WOOD_DARK,
                              rot=(0, 0, math.degrees(a) + 90), seed=10 + k, var=0.1, ao=0.0))
    parts.append(L.part("cyl", WOOD_DARK, loc=(0, 0, z0 + 0.02), radius=tub_r + 0.04, depth=0.05, vertices=8))
    parts.append(L.part("torus", WOOD_DARK, loc=(0, 0, z1 + 0.02), major_radius=tub_r + 0.02, minor_radius=0.035,
                        major_segments=8, minor_segments=4))
    # book rest towards the nave (-Y) with a pale cloth
    parts.append(I6._slab((0.0, -tub_r - 0.02, z1 - 0.02), (0.22, 0.1, 0.02), WOOD, rot=(-15, 0, 0), seed=20, var=0.1, ao=0.0))
    parts.append(I6._slab((0.0, -tub_r - 0.09, z1 - 0.14), (0.14, 0.006, 0.12), L.hexc("#6E5A3C"), seed=21, var=0.1, ao=0.0))
    # the stair (west side, rising north)
    for k in range(4):
        zz = 0.27 * (k + 1)
        parts.append(P._plank((-0.75, -0.55 + k * 0.28, zz - 0.02), (0.22, 0.14, 0.025), WOOD, seed=30 + k, top=0.35))
        parts.append(P._plank((-0.75, -0.55 + k * 0.28 - 0.13, zz - 0.14), (0.21, 0.012, 0.12), WOOD_DARK, seed=40 + k))
    for sx in (-1, 1):
        parts.append(P._stick((-0.75 + sx * 0.24, -0.7, 0.0), (-0.75 + sx * 0.24, 0.35, 1.1), 0.03, WOOD_DARK, verts=4, seed=50 + sx))
    parts.append(P._stick((-0.99, -0.7, 0.95), (-0.99, 0.3, 2.0), 0.02, WOOD, verts=4, seed=55))
    I6._done(parts, "ph_int_church_pulpit", [], 35)


def church_font():
    """Taufstein: octagonal stone basin on a stepped base, a wooden lid with an iron knob."""
    L.reset(7830)
    parts = []
    p = _lathe([(0.34, 0.0), (0.34, 0.1), (0.26, 0.14), (0.16, 0.2), (0.14, 0.62), (0.3, 0.72), (0.36, 0.96), (0.32, 0.98),
                (0.0, 0.98)], 8, "font")
    parts.append(B._paint(p, STONE_PALE, var=0.15, ao=0.35, top=0.2, hue_shift=STONE_OLD))
    lid = _lathe([(0.34, 0.98), (0.34, 1.02), (0.22, 1.08), (0.06, 1.14), (0.0, 1.15)], 8, "lid")
    parts.append(B._paint(lid, WOOD, var=0.12, ao=0.2, top=0.35))
    parts.append(L.part("sphere", IRON, loc=(0, 0, 1.18), radius=0.04, segments=6, ring_count=4))
    for k in range(4):   # four iron straps over the lid
        a = k / 4 * math.tau + math.pi / 8
        parts.append(P._stick((math.cos(a) * 0.33, math.sin(a) * 0.33, 1.02), (math.cos(a) * 0.07, math.sin(a) * 0.07, 1.14),
                              0.01, IRON, verts=4, seed=k, ao=0.0))
    I6._done(parts, "ph_int_church_font", [], 40)


def church_poor_box():
    """Opferstock: a square oak post (0.85 m) with iron bands, the coin box on top with a slot and a lock."""
    L.reset(7840)
    parts = [I6._slab((0.0, 0.0, 0.42), (0.11, 0.11, 0.42), L.hexc("#5E4636"), cuts=1, seed=1, var=0.14, ao=0.3, top=0.3)]
    for z in (0.15, 0.55):
        parts.append(I6._slab((0.0, 0.0, z), (0.116, 0.116, 0.02), IRON, seed=2, var=0.08, ao=0.0, top=0.3, hue_shift=P.RUST))
    parts.append(I6._slab((0.0, 0.0, 0.95), (0.17, 0.15, 0.11), L.hexc("#5A4232"), seed=3, var=0.12, ao=0.25, top=0.35))
    for x in (-0.12, 0.12):
        parts.append(I6._slab((x, 0.0, 0.95), (0.02, 0.155, 0.115), IRON, seed=4, var=0.08, ao=0.0, top=0.3))
    parts.append(I6._slab((0.0, 0.0, 1.065), (0.07, 0.012, 0.004), L.hexc("#141210"), seed=5, var=0.0, ao=0.0, top=0.0))
    parts.append(I6._slab((0.0, -0.155, 0.93), (0.035, 0.01, 0.045), IRON, seed=6, var=0.05, ao=0.0, top=0.4))
    I6._done(parts, "ph_int_church_poor_box", [], 40)


def church_memorial():
    """Gedenkbrett: a framed board (1.1 x 0.8 m) with three rows of blank name plates, a small cross on
    top, a shelf below with a candle in a holder. Pivot bottom centre (the shelf), front -Y."""
    L.reset(7850)
    random.seed(7850)
    parts = []
    bw, bh, z0 = 0.55, 0.8, 0.12
    parts.append(I6._slab((0.0, 0.0, z0 + bh / 2), (bw, 0.02, bh / 2), L.hexc("#4E3C2C"), seed=1, var=0.1, ao=0.2))
    for sx in (-1, 1):
        parts.append(I6._slab((sx * (bw + 0.02), -0.01, z0 + bh / 2), (0.03, 0.03, bh / 2 + 0.03), WOOD, seed=2, var=0.1, ao=0.1))
    for sz in (0, 1):
        parts.append(I6._slab((0.0, -0.01, z0 + sz * bh), (bw + 0.05, 0.03, 0.03), WOOD, seed=3, var=0.1, ao=0.1, top=0.3))
    for r in range(3):
        for c in range(2):
            parts.append(I6._slab((-0.25 + c * 0.5, -0.025, z0 + bh - 0.17 - r * 0.24), (0.21, 0.006, 0.07),
                                  L.scale_c(PLATE, random.uniform(0.94, 1.04)), seed=10 + r * 2 + c, var=0.05, ao=0.0))
    parts.append(I6._slab((0.0, -0.01, z0 + bh + 0.16), (0.015, 0.015, 0.13), WOOD_DARK, seed=20, var=0.1, ao=0.0))
    parts.append(I6._slab((0.0, -0.01, z0 + bh + 0.2), (0.07, 0.015, 0.015), WOOD_DARK, seed=21, var=0.1, ao=0.0))
    parts.append(I6._slab((0.0, -0.1, z0 - 0.02), (0.3, 0.1, 0.018), WOOD, seed=22, var=0.1, ao=0.0, top=0.3))
    holder = _lathe([(0.0, 0.0), (0.04, 0.004), (0.04, 0.012), (0.012, 0.02), (0.012, 0.035), (0.0, 0.035)], 8, "holder")
    holder.data.transform(__import__("mathutils").Matrix.Translation((0.18, -0.1, z0)))
    parts.append(B._paint(holder, BRASS, var=0.1, ao=0.1, top=0.5))
    fb = _candle(parts, 0.18, -0.1, z0 + 0.035, 0.1, 0.016, seed=30, drips=1)
    _flame(parts, fb, 0.04, 0.011)
    I6._done(parts, "ph_int_church_memorial", [], 35)


ASSETS = [church_room, church_pulpit, church_font, church_poor_box, church_memorial]


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
