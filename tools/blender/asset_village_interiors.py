"""Phase 7: the three village interiors (docs/PHASE7_DESIGN.md sections 4.3 and 8), 'Gemaltes Diorama'.

Like the Phase-6 rooms every room is a diorama for the fixed interior camera: the south wall (Blender -Y
= Godot +Z, towards the camera) is only a low stub with the door gap, there is no ceiling (beam stubs),
the cut edges sit on a band of rough stones. Furniture are separate models (pivot bottom centre, front
-Y = Godot +Z); data/world/interiors/<room>_layout.json (W-Welt) places them.

GASTSTUBE (inn, 8 x 6 m)
  ph_int_inn_room     board floor, wainscot and warm lime walls, two north windows and one east window
                      (light_window_1..3, inside the panes), the hanging lantern over the middle
                      (light_lantern, the shadow light at night), ceiling beam stubs. door_inside, spawn_inside
  ph_int_inn_bar      the counter (2.4 m) with mugs and a jug, a shelf of mugs behind; marker `bar` (where
                      Rosine stands, behind the counter)
  ph_int_inn_table    a scrubbed table with two benches; markers seat_1, seat_2 (floor under the bench
                      middles: seat_1 south facing north, seat_2 north facing south)
  ph_int_inn_stove    the tiled stove (Kachelofen) with a stove bench; marker light_stove (fire door)
  ph_int_inn_barrels  two barrels on a cradle with a tap
  ph_int_inn_stairs   a plain wooden stair rising along a wall to the cut (backdrop)
WUNDARZTSTUBE (surgery, 6 x 5 m)
  ph_int_surgery_room     pale lime walls, flag floor, a north window with cool daylight (light_window_1),
                          a wall lamp (light_lamp, the shadow light at night), herbs drying on a rail.
                          door_inside, spawn_inside
  ph_int_surgery_table    the treatment table under a white sheet, empty
  ph_int_surgery_cabinet  the glass cabinet: cloudy, SEALED jars with blank paper labels behind the panes,
                          nothing recognisable; no skeleton
  ph_int_surgery_desk     the writing desk: books, the cabinet book (open, blank), ink and quill, a wash bowl
  ph_int_surgery_bag      the closed leather case
  ph_int_surgery_lectern  the lecture lectern: a high desk with a cloth; marker jar_spot (top, where the
                          jar of the evening stands)
  ph_int_surgery_bench    a student bench (1.6 m); markers seat_1..3 (floor under each seat, facing -Y)
  ph_int_surgery_shutters closed window shutters (fits the north window, 1.0 x 1.3 m), pivot bottom centre
AMTSSTUBE (office, 6 x 5 m)
  ph_int_office_room      panelled walls, board floor, a north window (light_window_1), the parish shield.
                          door_inside, spawn_inside
  ph_int_office_desk      the clerk's desk: the seal, a candle (light_candle), papers, sand box
  ph_int_office_shelf     the file shelf: tied bundles, ledgers, boxes
  ph_int_office_poor_box  the poor box: an iron-bound chest with a coin slot and a padlock
  ph_int_office_lectern   the reading desk with the copy of the death register (a big closed book with clasps)

Run:  python tools/blender/build_all.py asset_village_interiors
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_buildings_phase6 as B6
import asset_interiors_phase6 as I6
import asset_village_buildings as VB
import asset_anatomy as A
from asset_interior import _candle, _flame

CAT = "interior"
box = VB._box
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
FLOOR = L.hexc("#6E5640")
FLOOR_DARK = L.hexc("#4E3C2C")
PANEL = L.hexc("#5E4632")
LIME_WARM = L.hexc("#B0A48C")
LIME_PALE = L.hexc("#B8B2A4")
LIME_OFFICE = L.hexc("#A89C86")
TILE_GREEN = L.hexc("#5E6A50")      # stove tiles: muted green-olive glaze
TILE_BROWN = L.hexc("#6E5A44")
IRON = P.IRON
BRASS = L.hexc("#8C7648")
PAPER = L.hexc("#CBBF9F")
LINEN_WHITE = L.hexc("#D6D0C0")
LINEN_SHADE = L.hexc("#B8B09C")
MUG = L.hexc("#8A7A62")
HERB = L.hexc("#6E7448")
LEATHER = L.hexc("#5A3E2C")
STONE = L.hexc("#7E8187")


def _paint(o, color, **kw):
    pk = {"var": 0.12, "ao": 0.15, "top": 0.2}
    pk.update(kw)
    L.paint(o, color, **pk)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _done(parts, name: str, markers=(), smooth: float = 40.0):
    obj = L.join(parts, name)
    for m, loc in markers:
        L.marker(obj, m, tuple(loc))
    L.finish(obj, name, CAT, smooth, shift=False)
    return obj


def _boards(parts, x0, x1, y0, y1, color=FLOOR):
    def fcol(u, v, r):
        return L.scale_c(random.choice((color, WOOD, FLOOR_DARK, color)), random.uniform(0.85, 1.08))
    parts += I6._tiled(lambda u, v: Vector((u, v, 0.0)), x0, x1, y0, y1, 1.4, 0.24, fcol, gap=0.012, relief=0.003,
                       backing=L.hexc("#1E1712"))


def _shell(parts, X: float, Y: float, H: float, wall, door_x: float, holes_n=(), holes_e=(), holes_w=(), seed: int = 0,
           wainscot=None, stub: float = 0.45):
    """North, east, west walls (inner faces), the south stub with the door gap, beam stubs, the cut band.
    holes_*: windows [(centre, width, sill, head)] in that wall."""
    # inner faces: north wall faces south (S) at y = Y, east wall faces west (W) at x = X, west faces east (E)
    VB._wall(parts, "S", Y, -X - 0.3, X + 0.3, 0.0, H, holes_n, base=wall, thick=0.3, seed=seed, stones=0.05, dirty=0.4)
    VB._wall(parts, "W", X, -Y, Y, 0.0, H, holes_e, base=wall, thick=0.3, seed=seed + 1, stones=0.05, dirty=0.4)
    VB._wall(parts, "E", -X, -Y, Y, 0.0, H, holes_w, base=wall, thick=0.3, seed=seed + 2, stones=0.05, dirty=0.4)
    VB._wall(parts, "N", -Y, -X - 0.3, X + 0.3, 0.0, stub, [(door_x, 1.1, 0.0, stub + 0.1)], base=wall, thick=0.3, seed=seed + 3,
             stones=0.05)
    if wainscot is not None:
        for face, plane, a0, a1, holes in (("S", Y, -X, X, holes_n), ("W", X, -Y, Y, holes_e), ("E", -X, -Y, Y, holes_w)):
            for k in range(int((a1 - a0) / 0.5)):
                a = a0 + 0.25 + k * 0.5
                if any(abs(a - c) < w / 2 + 0.05 and s < 1.1 for c, w, s, h in holes):
                    continue
                parts.append(box(VB._pt(face, plane, a, 0.015, 0.55), VB._half(face, 0.24, 0.015, 0.55),
                                 L.scale_c(wainscot, random.uniform(0.88, 1.1)), jit=0.003, seed=seed + 10 + k, ao=0.3, var=0.15))
            parts.append(box(VB._pt(face, plane, (a0 + a1) / 2, 0.03, 1.12), VB._half(face, (a1 - a0) / 2, 0.03, 0.025), WOOD_DARK,
                             top=0.3, ao=0.0))
    for k in range(int(2 * X / 1.2) + 1):        # ceiling beam stubs from the north wall
        x = -X + 0.6 + k * 1.2
        if x > X - 0.3:
            break
        parts.append(box((x, Y - 0.6, H - 0.12), (0.09, 0.6, 0.11), WOOD_DARK, seed=seed + 40 + k, ao=0.1))
    parts.append(box((0.0, Y - 0.08, H - 0.12), (X, 0.08, 0.11), WOOD_DARK, seed=seed + 60, ao=0.1))
    I6._cut_band(parts, -X - 0.3, X + 0.3, -Y - 0.3, Y, seed + 70, depth=0.35)


def _inner_win(parts, face: str, plane: float, a: float, sill: float, w: float, h: float, seed: int, cool: bool = False) -> Vector:
    lp = VB._win(parts, face, plane, a, sill, w, h, seed=seed, frame=WOOD_DARK, recess=0.18)
    if cool:   # pale daylight glass (the north light of the surgery) - a blue-grey, not saturated
        g = parts[-7] if False else None
        del g
    return lp


# ===================================================================================================
# GASTSTUBE
# ===================================================================================================

def inn_room():
    random.seed(7500)
    L.reset(7500)
    parts = []
    X, Y, H = 4.0, 3.0, 3.0
    door_x = 1.6
    _boards(parts, -X, X, -Y, Y)
    hn = [(-2.0, 0.8, 1.0, 2.2), (1.4, 0.8, 1.0, 2.2)]
    he = [(-0.4, 0.8, 1.0, 2.2)]
    _shell(parts, X, Y, H, LIME_WARM, door_x, hn, he, [], seed=1, wainscot=PANEL)
    lps = []
    for k, (c, w, s, hh) in enumerate(hn):
        lps.append(_inner_win(parts, "S", Y, c, s, w, hh - s, seed=100 + k))
    lps.append(_inner_win(parts, "W", X, he[0][0], he[0][2], he[0][1], he[0][3] - he[0][2], seed=110))
    # the hanging lantern over the middle, a crooked picture (a painted landscape), a hat rack
    sub = []
    lc = B6._wall_lantern(sub, Vector((0.0, 0.6, 2.2)), 0.6, seed=120)
    parts += sub
    parts.append(VB._beam((0.0, 0.6, 2.47), (0.0, 0.6, H - 0.05), 0.008, IRON, seed=121))
    parts.append(box((-0.4, Y - 0.04, 1.75), (0.32, 0.02, 0.22), WOOD_DARK, rot=(0, 3, 0), ao=0.0))
    parts.append(box((-0.4, Y - 0.06, 1.75), (0.27, 0.01, 0.17), L.hexc("#6E7A5A"), rot=(0, 3, 0), ao=0.0, var=0.3))
    parts.append(box((-X + 0.05, -1.0, 1.7), (0.03, 0.6, 0.04), WOOD_DARK, ao=0.0))
    for k in range(4):
        parts.append(VB._beam((-X + 0.07, -1.45 + k * 0.3, 1.7), (-X + 0.2, -1.45 + k * 0.3, 1.78), 0.012, WOOD, seed=130 + k))
    markers = [("door_inside", (door_x, -Y + 0.25, 0.0)), ("spawn_inside", (door_x, -Y + 0.85, 0.0)),
               ("light_window_1", lps[0]), ("light_window_2", lps[1]), ("light_window_3", lps[2]),
               ("light_lantern", lc)]
    _done(parts, "ph_int_inn_room", markers, 30)


def _mug(parts, at, seed: int = 0):
    at = Vector(at)
    parts.append(_paint(L.prim("cyl", loc=at + Vector((0, 0, 0.06)), radius=0.04, depth=0.12, vertices=8), MUG, ao=0.2, top=0.3))
    parts.append(L.part("torus", MUG, loc=at + Vector((0.046, 0, 0.06)), rot=(90, 0, 0), major_radius=0.025, minor_radius=0.007,
                        major_segments=6, minor_segments=3, paint_kw={"ao": 0.0}))


def inn_bar():
    random.seed(7510)
    L.reset(7510)
    parts = []
    hl, hd, h = 1.2, 0.3, 1.05
    parts.append(box((0.0, 0.0, h / 2), (hl, hd, h / 2), PANEL, jit=0.004, seed=1, ao=0.3))
    for k in range(6):
        x = -hl + 0.2 + k * 0.4
        parts.append(box((x, -hd - 0.012, h / 2), (0.16, 0.012, h / 2 - 0.08), L.scale_c(PANEL, 1.12), ao=0.2, var=0.12))
    parts.append(box((0.0, 0.0, h + 0.03), (hl + 0.06, hd + 0.06, 0.035), WOOD, jit=0.003, seed=2, top=0.4))
    parts.append(box((0.0, -hd - 0.02, 0.06), (hl + 0.02, 0.03, 0.06), WOOD_DARK, ao=0.0))
    for k, x in enumerate((-0.8, -0.55, 0.2)):
        _mug(parts, (x, -0.05, h + 0.065), seed=k)
    jug = A._lathe([(0.0, 0.0), (0.07, 0.01), (0.08, 0.1), (0.05, 0.2), (0.055, 0.26), (0.0, 0.26)], n=8, name="jug")
    jug.data.transform(Matrix.Translation((0.7, 0.0, h + 0.065)))
    parts.append(_paint(jug, L.hexc("#7A6E5A"), ao=0.2, top=0.3))
    # a shelf behind with mugs
    parts.append(box((0.0, 0.85, 1.55), (hl, 0.12, 0.02), WOOD, ao=0.0, top=0.3))
    for k in range(6):
        _mug(parts, (-1.0 + k * 0.4, 0.85, 1.57), seed=10 + k)
    for sx in (-1, 1):
        parts.append(box((sx * (hl - 0.05), 0.85, 0.78), (0.04, 0.1, 0.78), WOOD_DARK, ao=0.3))
    _done(parts, "ph_int_inn_bar", [("bar", (0.0, 0.5, 0.0))])


def inn_table():
    random.seed(7520)
    L.reset(7520)
    parts = [box((0.0, 0.0, 0.76), (0.7, 0.4, 0.035), L.hexc("#8C7458"), jit=0.003, seed=1, top=0.4)]
    for sx in (-1, 1):
        parts.append(box((sx * 0.58, 0.0, 0.37), (0.05, 0.3, 0.37), WOOD_DARK, seed=2, ao=0.3))
    parts.append(box((0.0, 0.0, 0.18), (0.55, 0.03, 0.03), WOOD_DARK, seed=3))
    for sy in (-1, 1):
        parts.append(box((0.0, sy * 0.68, 0.43), (0.7, 0.14, 0.03), WOOD, jit=0.003, seed=4 + sy, top=0.35))
        for sx in (-1, 1):
            parts.append(box((sx * 0.55, sy * 0.68, 0.2), (0.035, 0.11, 0.2), WOOD_DARK, seed=6, ao=0.3))
    _done(parts, "ph_int_inn_table", [("seat_1", (0.0, -0.68, 0.0)), ("seat_2", (0.0, 0.68, 0.0))])


def inn_stove():
    random.seed(7530)
    L.reset(7530)
    parts = []
    parts.append(box((0.0, 0.0, 0.22), (0.65, 0.5, 0.22), STONE, jit=0.01, seed=1, ao=0.4, cuts=1))
    def tcol(u, v, r):
        return L.scale_c(TILE_GREEN if r < 0.75 else TILE_BROWN, random.uniform(0.85, 1.1))
    bx, by = 0.55, 0.42
    for face, plane, a0, a1 in (("S", -by, -bx, bx), ("E", bx, -by, by), ("W", -bx, -by, by)):
        if face == "S":
            fn = lambda u, v: Vector((u, -by, v))   # noqa: E731
        elif face == "E":
            fn = lambda u, v: Vector((bx, u, v))    # noqa: E731
        else:
            fn = lambda u, v: Vector((-bx, -u, v))  # noqa: E731
        u0, u1 = (a0, a1) if face != "W" else (-a1, -a0)
        parts += I6._tiled(fn, u0, u1, 0.44, 1.5, 0.22, 0.2, tcol, gap=0.014, relief=0.01, backing=L.hexc("#2A2622"))
    parts.append(box((0.0, 0.0, 0.97), (bx - 0.01, by - 0.01, 0.53), L.hexc("#2A2622"), ao=0.0, var=0.0, top=0.0))
    parts.append(box((0.0, 0.0, 1.55), (bx + 0.05, by + 0.05, 0.05), TILE_BROWN, top=0.35))
    parts.append(box((0.0, 0.0, 1.75), (0.38, 0.3, 0.15), TILE_GREEN, jit=0.004, seed=3, top=0.3))
    parts.append(box((0.0, 0.0, 1.93), (0.42, 0.34, 0.03), TILE_BROWN, top=0.35))
    # the fire door (dark iron) and the bench round two sides
    parts.append(box((0.0, -by - 0.015, 0.68), (0.14, 0.012, 0.1), IRON, ao=0.0, top=0.3))
    parts.append(box((0.0, -by - 0.02, 0.68), (0.1, 0.008, 0.012), L.hexc("#5A4A3A"), ao=0.0))
    parts.append(box((0.0, -0.75, 0.42), (0.75, 0.2, 0.03), WOOD, seed=4, top=0.35))
    for sx in (-1, 1):
        parts.append(box((sx * 0.62, -0.75, 0.2), (0.04, 0.16, 0.2), WOOD_DARK, ao=0.3))
    _done(parts, "ph_int_inn_stove", [("light_stove", (0.0, -by - 0.25, 0.7))])


def _barrel(parts, at, r: float = 0.3, l: float = 0.75, seed: int = 0):
    at = Vector(at)
    o = L.prim("cyl", loc=(0, 0, 0), radius=r, depth=l, vertices=12, rot=(0, 90, 0))
    for v in o.data.vertices:
        t = v.co.x / (l / 2)
        k = 1.0 + 0.1 * (1 - t * t)
        v.co.y *= k
        v.co.z *= k
    o.data.transform(Matrix.Translation(at))
    parts.append(_paint(o, WOOD, ao=0.3, var=0.2, hue_shift=WOOD_OLD, seed=seed))
    for x in (-l * 0.35, l * 0.35):
        parts.append(L.part("torus", IRON, loc=at + Vector((x, 0, 0)), rot=(0, 90, 0), major_radius=r * 1.06, minor_radius=0.014,
                            major_segments=12, minor_segments=3, paint_kw={"ao": 0.0}))
    parts.append(_paint(L.prim("cyl", loc=at + Vector((-l / 2 - 0.004, 0, 0)), rot=(0, 90, 0), radius=r * 0.92, depth=0.01, vertices=12),
                        L.hexc("#8A7050"), ao=0.0))
    parts.append(VB._beam(at + Vector((-l / 2 - 0.01, 0, -r * 0.5)), at + Vector((-l / 2 - 0.12, 0, -r * 0.5)), 0.02, BRASS, seed=seed))


def inn_barrels():
    random.seed(7540)
    L.reset(7540)
    parts = []
    for sy in (-1, 1):
        parts.append(box((0.0, sy * 0.36, 0.12), (0.45, 0.05, 0.12), WOOD_DARK, seed=1, ao=0.3))
    _barrel(parts, (0.0, -0.18, 0.52), seed=2)
    _barrel(parts, (0.0, 0.42, 0.52), seed=3)
    _done(parts, "ph_int_inn_barrels")


def inn_stairs():
    random.seed(7550)
    L.reset(7550)
    parts = []
    n = 9
    for k in range(n):
        z = (k + 1) * 0.29
        y = -1.3 + k * 0.29
        parts.append(box((0.0, y, z - 0.02), (0.45, 0.15, 0.025), WOOD, jit=0.003, seed=k, top=0.35))
        parts.append(box((0.0, y - 0.14, z - 0.15), (0.43, 0.012, 0.12), WOOD_DARK, ao=0.3))
    for sx in (-1, 1):
        p0, p1 = Vector((sx * 0.47, -1.45, 0.0)), Vector((sx * 0.47, 1.25, n * 0.29))
        parts.append(VB._beam(p0, p1, 0.05, WOOD_DARK, seed=20 + sx, hd=0.15))
    parts.append(VB._beam((-0.5, -1.4, 0.0), (-0.5, -1.4, 1.0), 0.04, WOOD_DARK, seed=30))
    parts.append(VB._beam((-0.5, -1.4, 1.0), (-0.5, 1.2, 1.0 + n * 0.29 - 0.3), 0.03, WOOD, seed=31))
    _done(parts, "ph_int_inn_stairs")


# ===================================================================================================
# WUNDARZTSTUBE
# ===================================================================================================

SU_WIN = (0.4, 1.0, 1.0, 2.3)   # north window (centre x, width, sill, head) - the shutters model fits it


def surgery_room():
    random.seed(7600)
    L.reset(7600)
    parts = []
    X, Y, H = 3.0, 2.5, 3.0
    door_x = -1.5

    def fcol(u, v, r):
        return L.scale_c(random.choice((L.hexc("#8C8A84"), L.hexc("#7E7C74"), L.hexc("#96928A"))), random.uniform(0.85, 1.05))
    parts += I6._tiled(lambda u, v: Vector((u, v, 0.0)), -X, X, -Y, Y, 0.5, 0.45, fcol, gap=0.02, relief=0.004,
                       backing=L.hexc("#1C1A18"))
    _shell(parts, X, Y, H, LIME_PALE, door_x, [SU_WIN], [], [(0.0, 0.7, 1.1, 2.1)], seed=1)
    lp = _inner_win(parts, "S", Y, SU_WIN[0], SU_WIN[2], SU_WIN[1], SU_WIN[3] - SU_WIN[2], seed=100)
    _inner_win(parts, "E", -X, 0.0, 1.1, 0.7, 1.0, seed=101)
    # wall lamp (oil) on a bracket by the cabinet wall, herbs drying on a rail
    sub = []
    ll = B6._wall_lantern(sub, Vector((X - 0.3, 0.6, 1.8)), X - 0.02, seed=110) if False else None
    del sub, ll
    lamp_at = Vector((X - 0.25, -0.6, 1.85))
    parts.append(box((X - 0.03, -0.6, 1.75), (0.02, 0.06, 0.12), IRON, ao=0.0))
    parts.append(VB._beam((X - 0.03, -0.6, 1.72), (X - 0.22, -0.6, 1.72), 0.01, IRON, seed=111))
    oil = A._lathe([(0.0, 0.0), (0.05, 0.01), (0.055, 0.05), (0.02, 0.08), (0.0, 0.08)], n=8, name="oil")
    oil.data.transform(Matrix.Translation((X - 0.25, -0.6, 1.72)))
    parts.append(_paint(oil, BRASS, ao=0.1, top=0.4))
    chim = A._lathe([(0.03, 0.08), (0.045, 0.13), (0.03, 0.22), (0.028, 0.24)], n=8, name="chimney")
    chim.data.transform(Matrix.Translation((X - 0.25, -0.6, 1.72)))
    parts.append(chim)
    L.set_mat(chim, L.MAT_EMISSIVE)
    parts.append(VB._beam((-X + 0.1, 1.2, 2.3), (-X + 0.1, -1.2, 2.3), 0.012, WOOD_DARK, seed=120))
    for k in range(5):
        y = 1.0 - k * 0.5
        bn = L.prim("cone", loc=(-X + 0.12, y, 2.15), radius1=0.06, radius2=0.015, depth=0.28, vertices=6, rot=(180, 0, 0))
        L.jitter(bn, 0.012, 20.0, k)
        parts.append(_paint(bn, L.mix(HERB, L.hexc("#8A7E58"), random.random() * 0.5), var=0.3, ao=0.2))
    markers = [("door_inside", (door_x, -Y + 0.25, 0.0)), ("spawn_inside", (door_x, -Y + 0.8, 0.0)), ("light_window_1", lp),
               ("light_lamp", (lamp_at.x, lamp_at.y, 1.72 - 0.05))]
    _done(parts, "ph_int_surgery_room", markers, 30)


def surgery_table():
    random.seed(7610)
    L.reset(7610)
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((sx * 0.85, sy * 0.3, 0.38), (0.04, 0.04, 0.38), WOOD_DARK, seed=1, ao=0.3))
    parts.append(box((0.0, 0.0, 0.79), (0.95, 0.37, 0.04), WOOD, seed=2))
    parts.append(box((0.0, 0.0, 0.2), (0.85, 0.3, 0.015), WOOD_DARK, seed=3))
    sh = A._cloth_over(parts, -1.0, 1.0, -0.42, 0.42, 0.835, 0.55, seed=4, nx=10, ny=4)
    L.paint(sh, LINEN_WHITE, var=0.08, ao=0.25, top=0.25, hue_shift=LINEN_SHADE)
    parts.append(box((0.8, 0.0, 0.88), (0.12, 0.22, 0.04), LINEN_WHITE, jit=0.01, seed=5, top=0.3))   # a folded bolster
    parts.append(box((-0.4, 0.0, 0.25), (0.3, 0.2, 0.04), LINEN_SHADE, jit=0.008, seed=6))           # folded linen below
    _done(parts, "ph_int_surgery_table")


def surgery_cabinet():
    random.seed(7620)
    L.reset(7620)
    parts = []
    W, D, H = 0.6, 0.22, 1.9
    parts.append(box((0.0, 0.0, 0.4), (W, D, 0.4), WOOD_DARK, jit=0.003, seed=1, ao=0.3))
    for sx in (-1, 1):
        parts.append(box((sx * 0.3, -D - 0.01, 0.4), (0.27, 0.012, 0.34), L.scale_c(WOOD_DARK, 1.15), ao=0.1))
        parts.append(_paint(L.prim("sphere", loc=(sx * 0.05, -D - 0.03, 0.45), radius=0.015, segments=6, ring_count=4), BRASS, ao=0.0))
    # upper glass case: frame, back, shelves with jars
    for sx in (-1, 1):
        parts.append(box((sx * (W - 0.03), 0.0, 0.8 + (H - 0.8) / 2), (0.03, D - 0.03, (H - 0.8) / 2), WOOD_DARK, ao=0.2))
    parts.append(box((0.0, D - 0.04, 0.8 + (H - 0.8) / 2), (W - 0.03, 0.015, (H - 0.8) / 2), L.hexc("#3A2E24"), ao=0.4))
    parts.append(box((0.0, 0.0, H), (W + 0.04, D + 0.02, 0.04), WOOD, top=0.3))
    for z in (0.83, 1.2, 1.55):
        parts.append(box((0.0, 0.0, z), (W - 0.05, D - 0.05, 0.012), WOOD, ao=0.0, top=0.3))
        x = -W + 0.15
        k = 0
        if z > 1.5:   # top shelf: closed boxes and a stack of papers
            for kk, xx in enumerate((-0.38, -0.05, 0.3)):
                parts.append(box((xx, 0.0, z + 0.08), (0.12, 0.12, 0.07), random.choice((WOOD_OLD, L.hexc("#5E4A3A"))), ao=0.2, top=0.3))
            continue
        while x < W - 0.12:
            h = random.uniform(0.14, 0.22) if z < 1.5 else random.uniform(0.12, 0.18)
            r = random.uniform(0.045, 0.06)
            A.jar(parts, (x, 0.0, z + 0.012), h=h, r=r, seed=int(z * 100) + k, n=6, label=True, string=False)
            x += 2 * r + 0.07
            k += 1
    # glass doors: thin frames and pale panes (painted, cloudy) over the shelves
    for sx in (-1, 1):
        for z in (0.82, H - 0.02, 1.36):
            parts.append(box((sx * 0.3, -D - 0.002, z), (0.29, 0.012, 0.018), WOOD_DARK, ao=0.0))
        parts.append(box((sx * 0.58, -D - 0.002, 1.35), (0.018, 0.012, 0.55), WOOD_DARK, ao=0.0))
        parts.append(box((sx * 0.02, -D - 0.002, 1.35), (0.018, 0.012, 0.55), WOOD_DARK, ao=0.0))
    obj = _done(parts, "ph_int_surgery_cabinet")
    del obj


def _glass_panes_translucent() -> None:
    """(The cabinet panes are painted pale grey: the jars read through the frame gaps; no glass shader.)"""


def surgery_desk():
    random.seed(7630)
    L.reset(7630)
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((sx * 0.55, sy * 0.25, 0.37), (0.04, 0.04, 0.37), WOOD_DARK, seed=1, ao=0.3))
    parts.append(box((0.0, 0.0, 0.76), (0.62, 0.32, 0.03), WOOD, seed=2, top=0.35))
    parts.append(box((0.0, -0.3, 0.66), (0.55, 0.012, 0.07), WOOD_DARK, ao=0.1))
    parts.append(box((0.0, 0.27, 0.95), (0.6, 0.06, 0.2), WOOD_DARK, ao=0.3))      # a book shelf on the back
    for k in range(8):
        h = random.uniform(0.14, 0.2)
        parts.append(box((-0.5 + k * 0.13, 0.27, 1.15 + h / 2), (0.05, 0.08, h / 2),
                         random.choice((LEATHER, L.hexc("#4A4436"), L.hexc("#5E4A3A"), L.hexc("#6E5A44"))), ao=0.2, top=0.3))
    # the cabinet book: open, blank pages; ink, quill; a wash bowl with a jug at the side
    parts.append(box((-0.15, -0.05, 0.81), (0.26, 0.17, 0.02), LEATHER, rot=(0, 0, -5), top=0.3))
    for sx in (-1, 1):
        pg = L.prim("cube", loc=(-0.15 + sx * 0.12, -0.05, 0.835), scale=(0.12, 0.15, 0.01))
        pg.data.transform(Matrix.Translation((0, 0, 0)))
        parts.append(_paint(pg, PAPER, ao=0.0, var=0.05))
    parts.append(_paint(L.prim("cyl", loc=(0.25, -0.1, 0.81), radius=0.025, depth=0.05, vertices=8), L.hexc("#2A2A33"), top=0.3))
    parts.append(VB._beam((0.25, -0.1, 0.83), (0.3, -0.02, 1.0), 0.006, L.hexc("#C8C0AC"), seed=3))
    bowl = A._lathe([(0.0, 0.0), (0.08, 0.005), (0.15, 0.07), (0.14, 0.072), (0.0, 0.03)], n=12, name="bowl")
    bowl.data.transform(Matrix.Translation((0.45, 0.05, 0.79)))
    parts.append(_paint(bowl, L.hexc("#B8B0A0"), ao=0.2, top=0.3))
    _done(parts, "ph_int_surgery_desk")


def surgery_bag():
    random.seed(7640)
    L.reset(7640)
    parts = []
    bag = L.prim("cube", loc=(0, 0, 0.13), scale=(0.2, 0.09, 0.13))
    L.bevel(bag, 0.05, 2)
    for v in bag.data.vertices:
        if v.co.z > 0.18:
            v.co.y *= 0.55
    parts.append(_paint(bag, LEATHER, ao=0.3, top=0.3, var=0.15))
    parts.append(box((0, 0, 0.255), (0.17, 0.035, 0.008), BRASS, ao=0.0, top=0.5))
    parts.append(L.part("torus", L.hexc("#3E2A1E"), loc=(0, 0, 0.3), rot=(90, 0, 0), major_radius=0.06, minor_radius=0.01,
                        major_segments=8, minor_segments=4))
    _done(parts, "ph_int_surgery_bag")


def surgery_lectern():
    random.seed(7650)
    L.reset(7650)
    parts = [box((0.0, 0.0, 0.03), (0.3, 0.25, 0.03), WOOD_DARK, seed=1)]
    parts.append(box((0.0, 0.0, 0.55), (0.08, 0.08, 0.5), WOOD_DARK, seed=2, ao=0.3))
    parts.append(box((0.0, 0.0, 1.07), (0.32, 0.24, 0.03), WOOD, seed=3, top=0.35))
    A._cloth_over(parts, -0.36, 0.36, -0.28, 0.28, 1.105, 0.95, seed=4, nx=6, ny=4)
    _done(parts, "ph_int_surgery_lectern", [("jar_spot", (0.0, 0.0, 1.115))])


def surgery_bench():
    random.seed(7660)
    L.reset(7660)
    parts = [box((0.0, 0.0, 0.43), (0.8, 0.16, 0.03), WOOD, jit=0.003, seed=1, top=0.35)]
    for sx in (-1, 1):
        parts.append(box((sx * 0.66, 0.0, 0.2), (0.04, 0.14, 0.2), WOOD_DARK, seed=2, ao=0.3))
    parts.append(box((0.0, 0.0, 0.12), (0.62, 0.025, 0.025), WOOD_DARK, seed=3))
    _done(parts, "ph_int_surgery_bench", [("seat_1", (-0.52, 0.0, 0.0)), ("seat_2", (0.0, 0.0, 0.0)), ("seat_3", (0.52, 0.0, 0.0))])


def surgery_shutters():
    random.seed(7670)
    L.reset(7670)
    parts = []
    w, h = SU_WIN[1], SU_WIN[3] - SU_WIN[2]
    for sx in (-1, 1):
        for k in range(3):
            parts.append(box((sx * (w / 4) + (k - 1) * w / 6 * 0.98, 0.0, h / 2), (w / 12 - 0.004, 0.02, h / 2), L.scale_c(WOOD_DARK,
                             random.uniform(0.9, 1.1)), jit=0.003, seed=k + sx * 5, ao=0.2))
        for z in (h * 0.2, h * 0.8):
            parts.append(box((sx * w / 4, -0.025, z), (w / 4 - 0.02, 0.008, 0.03), IRON, ao=0.0))
    parts.append(box((0.0, -0.03, h / 2), (0.05, 0.01, 0.02), IRON, ao=0.0))   # the bar
    parts.append(box((0.0, -0.035, h / 2), (w / 2 - 0.04, 0.01, 0.015), IRON, ao=0.0))
    _done(parts, "ph_int_surgery_shutters")


# ===================================================================================================
# AMTSSTUBE
# ===================================================================================================

def office_room():
    random.seed(7700)
    L.reset(7700)
    parts = []
    X, Y, H = 3.0, 2.5, 3.0
    door_x = 1.2
    _boards(parts, -X, X, -Y, Y, color=L.hexc("#6A5442"))
    hn = [(-0.8, 0.9, 1.0, 2.3)]
    _shell(parts, X, Y, H, LIME_OFFICE, door_x, hn, [], [], seed=1, wainscot=L.hexc("#4E3C2C"))
    lp = _inner_win(parts, "S", Y, hn[0][0], hn[0][2], hn[0][1], hn[0][3] - hn[0][2], seed=100)
    # the parish shield on the north wall and a framed map (painted blotches, no text)
    sh = L.prim("cube", loc=(1.2, Y - 0.05, 2.0), scale=(0.24, 0.02, 0.3))
    for v in sh.data.vertices:
        if v.co.z < 1.85:
            v.co.x = 1.2 + (v.co.x - 1.2) * 0.45
    parts.append(_paint(sh, L.hexc("#B8AE94"), top=0.3))
    parts.append(_paint(L.prim("sphere", loc=(1.2, Y - 0.08, 2.0), radius=1.0, scale=(0.09, 0.01, 0.13), segments=8, ring_count=5),
                        L.hexc("#4E6440")))
    parts.append(box((X - 0.04, 0.4, 1.8), (0.02, 0.5, 0.35), WOOD_DARK, ao=0.0))
    parts.append(box((X - 0.06, 0.4, 1.8), (0.01, 0.45, 0.3), L.hexc("#B0A482"), ao=0.0, var=0.3))
    markers = [("door_inside", (door_x, -Y + 0.25, 0.0)), ("spawn_inside", (door_x, -Y + 0.8, 0.0)), ("light_window_1", lp)]
    _done(parts, "ph_int_office_room", markers, 30)


def office_desk():
    random.seed(7710)
    L.reset(7710)
    parts = []
    parts.append(box((-0.42, 0.0, 0.37), (0.2, 0.32, 0.37), WOOD_DARK, jit=0.003, seed=1, ao=0.3))   # drawer pedestal
    for k in range(3):
        parts.append(box((-0.42, -0.325, 0.15 + k * 0.22), (0.17, 0.01, 0.09), L.scale_c(WOOD_DARK, 1.15), ao=0.1))
    for sy in (-1, 1):
        parts.append(box((0.6, sy * 0.27, 0.37), (0.04, 0.04, 0.37), WOOD_DARK, seed=2, ao=0.3))
    parts.append(box((0.0, 0.0, 0.76), (0.7, 0.36, 0.03), WOOD, seed=3, top=0.35))
    parts.append(box((0.0, -0.05, 0.795), (0.4, 0.22, 0.004), L.hexc("#3E4A3A"), ao=0.0))   # a green desk cloth
    for k in range(4):
        parts.append(box((-0.15 + k * 0.03, -0.05 + k * 0.01, 0.8 + k * 0.003), (0.1, 0.14, 0.002), PAPER, rot=(0, 0, k * 6 - 6),
                         ao=0.0, var=0.05))
    seal = A._lathe([(0.0, 0.0), (0.03, 0.002), (0.03, 0.02), (0.012, 0.03), (0.016, 0.08), (0.0, 0.085)], n=8, name="seal")
    seal.data.transform(Matrix.Translation((0.35, -0.12, 0.79)))
    parts.append(_paint(seal, BRASS, ao=0.1, top=0.5))
    parts.append(box((0.45, 0.1, 0.81), (0.06, 0.04, 0.02), WOOD_DARK, ao=0.1))      # sand box
    parts.append(_paint(L.prim("cyl", loc=(0.3, 0.15, 0.81), radius=0.025, depth=0.05, vertices=8), L.hexc("#2A2A33"), top=0.3))
    parts.append(VB._beam((0.3, 0.15, 0.83), (0.36, 0.22, 1.0), 0.006, L.hexc("#C8C0AC"), seed=4))
    holder = A._lathe([(0.0, 0.0), (0.05, 0.004), (0.05, 0.012), (0.015, 0.02), (0.015, 0.04), (0.0, 0.04)], n=8, name="holder")
    holder.data.transform(Matrix.Translation((-0.5, 0.18, 0.79)))
    parts.append(_paint(holder, BRASS, ao=0.1, top=0.5))
    fb = _candle(parts, -0.5, 0.18, 0.83, 0.12, seed=5)
    _flame(parts, fb)
    _done(parts, "ph_int_office_desk", [("light_candle", (fb.x, fb.y, fb.z + 0.08))])


def office_shelf():
    random.seed(7720)
    L.reset(7720)
    parts = []
    W, D = 0.75, 0.2
    for sx in (-1, 1):
        parts.append(box((sx * (W - 0.02), 0.0, 0.95), (0.025, D, 0.95), WOOD_DARK, ao=0.3))
    parts.append(box((0.0, D - 0.01, 0.95), (W - 0.02, 0.012, 0.94), L.hexc("#3A2E24"), ao=0.4))
    for z in (0.08, 0.5, 0.92, 1.34, 1.76):
        parts.append(box((0.0, 0.0, z), (W - 0.03, D - 0.01, 0.015), WOOD, ao=0.0, top=0.3))
        if z > 1.7:
            continue
        x = -W + 0.06
        while x < W - 0.12:
            kind = random.random()
            if kind < 0.45:   # tied file bundles
                w = random.uniform(0.06, 0.1)
                parts.append(box((x + w, 0.0, z + 0.015 + 0.14), (w, 0.14, 0.14), L.scale_c(PAPER, random.uniform(0.8, 0.95)), ao=0.2))
                parts.append(box((x + w, -0.142, z + 0.15), (w + 0.002, 0.003, 0.008), L.hexc("#6A3A30") if False else L.hexc("#6E5A44"),
                                 ao=0.0))
            elif kind < 0.8:  # ledgers
                w = random.uniform(0.03, 0.05)
                parts.append(box((x + w, 0.0, z + 0.015 + 0.17), (w, 0.13, 0.17), random.choice((LEATHER, L.hexc("#4A4436"),
                                                                                                   L.hexc("#5E4A3A"))), ao=0.2, top=0.3))
            else:             # a box
                w = 0.1
                parts.append(box((x + w, 0.0, z + 0.015 + 0.1), (w, 0.14, 0.1), WOOD_OLD, ao=0.2, top=0.3))
            x += 2 * w + 0.01
    parts.append(box((0.0, 0.0, 1.9), (W + 0.04, D + 0.03, 0.03), WOOD, top=0.3))
    _done(parts, "ph_int_office_shelf")


def office_poor_box():
    random.seed(7730)
    L.reset(7730)
    parts = []
    parts.append(box((0.0, 0.0, 0.22), (0.36, 0.24, 0.2), L.hexc("#5A4232"), jit=0.004, seed=1, ao=0.3, top=0.3))
    lid = L.prim("cyl", loc=(0.0, 0.0, 0.42), rot=(0, 90, 0), radius=0.24, depth=0.72, vertices=12)
    bm = bmesh.new()
    bm.from_mesh(lid.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.415], context="VERTS")
    bm.to_mesh(lid.data)
    bm.free()
    for v in lid.data.vertices:
        v.co.z = 0.42 + (v.co.z - 0.42) * 0.55
    parts.append(_paint(lid, L.hexc("#5E4636"), ao=0.2, top=0.3))
    for x in (-0.3, -0.1, 0.1, 0.3):   # iron bands over body and lid
        parts.append(box((x, 0.0, 0.22), (0.025, 0.245, 0.205), IRON, ao=0.0, top=0.3, hue_shift=P.RUST))
        band = L.prim("torus", loc=(x, 0.0, 0.42), rot=(0, 90, 0), major_radius=0.243, minor_radius=0.014, major_segments=12,
                      minor_segments=3)
        bm = bmesh.new()
        bm.from_mesh(band.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.41], context="VERTS")
        bm.to_mesh(band.data)
        bm.free()
        for v in band.data.vertices:
            v.co.z = 0.42 + (v.co.z - 0.42) * 0.55
        parts.append(_paint(band, IRON, ao=0.0, top=0.3))
    parts.append(box((0.0, -0.06, 0.555), (0.07, 0.012, 0.006), L.hexc("#141210"), ao=0.0, var=0.0, top=0.0))   # coin slot
    parts.append(box((0.0, -0.245, 0.3), (0.05, 0.012, 0.06), IRON, ao=0.0, top=0.4))
    parts.append(L.part("torus", IRON, loc=(0.0, -0.27, 0.26), rot=(90, 0, 0), major_radius=0.035, minor_radius=0.008,
                        major_segments=8, minor_segments=3))
    parts.append(box((0.0, -0.275, 0.21), (0.035, 0.012, 0.03), IRON, ao=0.0, top=0.4))
    _done(parts, "ph_int_office_poor_box")


def office_lectern():
    random.seed(7740)
    L.reset(7740)
    parts = [box((0.0, 0.0, 0.03), (0.3, 0.26, 0.03), WOOD_DARK, seed=1)]
    parts.append(box((0.0, 0.0, 0.5), (0.07, 0.07, 0.47), WOOD_DARK, seed=2, ao=0.3))
    top = L.prim("cube", scale=(0.34, 0.25, 0.025))
    top.data.transform(Matrix.Translation((0.0, 0.0, 1.06)) @ Matrix.Rotation(math.radians(18), 4, "X"))
    parts.append(_paint(top, WOOD, top=0.35))
    bk = L.prim("cube", scale=(0.28, 0.2, 0.045))
    bk.data.transform(Matrix.Translation((0.0, 0.0, 1.12)) @ Matrix.Rotation(math.radians(18), 4, "X"))
    parts.append(_paint(bk, LEATHER, top=0.35))
    pg = L.prim("cube", scale=(0.27, 0.19, 0.04))
    pg.data.transform(Matrix.Translation((0.004, 0.006, 1.12)) @ Matrix.Rotation(math.radians(18), 4, "X"))
    parts.append(_paint(pg, PAPER, ao=0.0))
    for x in (-0.15, 0.15):
        cl = L.prim("cube", scale=(0.025, 0.03, 0.05))
        cl.data.transform(Matrix.Translation((x, -0.19, 1.07)) @ Matrix.Rotation(math.radians(18), 4, "X"))
        parts.append(_paint(cl, BRASS, ao=0.0, top=0.5))
    _done(parts, "ph_int_office_lectern")


ASSETS = [inn_room, inn_bar, inn_table, inn_stove, inn_barrels, inn_stairs,
          surgery_room, surgery_table, surgery_cabinet, surgery_desk, surgery_bag, surgery_lectern, surgery_bench,
          surgery_shutters, office_room, office_desk, office_shelf, office_poor_box, office_lectern]


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
