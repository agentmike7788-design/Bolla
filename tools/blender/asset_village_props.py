"""Phase 7: props and environment of Hollerbrueck and the Lindenacker (docs/PHASE7_DESIGN.md sections 4.2, 4.6, 8).

  ph_prop_v_well        Ziehbrunnen (<= 3 m): round rubble wall, a little shingle roof on two posts, a crank
                        windlass with rope and bucket
  ph_prop_v_bridge      Holderbruecke: a 6 m stone arch (east-west, deck 2.6 m wide, low parapets); the deck
                        rises to 0.55 m over the brook; the arch opening is north-south (the brook runs N-S)
  ph_prop_v_board       Gemeindetafel: a roofed notice board on two posts, blank papers pinned (no text)
  ph_prop_v_shrine      Bildstock: a sandstone pillar with a niche (a dark little figure, a dried wreath)
  ph_prop_v_sign        Ortstafel: a board on a post, blank face for the Label3D "Hollerbrueck" (label_board)
  ph_prop_v_ribbon      Trauerflor: black ribbon with a bow, no text; pivot = the knot (hang it at a `ribbon`
                        marker), the tails hang down to -0.42 m
  ph_prop_v_bench       a plank bench (seat 0.45 m)
  ph_prop_v_wash_stones Waschplatz: flat stones at the east bank, a washing board leaning on one
  ph_env_linden_old     the old linden (village and Lindenacker): leaning trunk, crown r ~4.5 m, <= 9 m,
                        painted_foliage like the oak
  ph_env_brook          Hollerbach: flat painted water (vertex colour on mat_painted, no new shader) with
                        stony banks; runs north-south, 44 m long, ~3.2 m wide with banks, pivot = centre, water 0.02 m over the ground
  ph_env_garden_fence   one 2 m section of a garden fence (pickets on two rails), pivot = middle bottom
  ph_prop_milestone     Wegstein "Hollerbrueck - 3 Meilen": a rounded stone, label_board on the face
  ph_prop_corpse_poppy  D1: the posy of dried poppy as a child mesh `poppy` for look 1 (ph_prop_corpse_02):
                        in that model's coordinates (head at +X Godot, face up), resting on the bodice

The handcart in the coach house reuses ph_prop_handcart (ph_prop_v_cart_rest is not a new model).

Run:  python tools/blender/build_all.py asset_village_props
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
from asset_environment import _limb
import asset_village_buildings as VB

STONE = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_OLD = L.hexc("#686B64")
SAND = VB.SAND
SAND_DARK = VB.SAND_DARK
MOSS = L.hexc("#5E7148")
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
IRON = P.IRON
ROPE = P.ROPE
PAPER = L.hexc("#CBBF9F")
BARK = L.hexc("#5A4A3C")
BARK_DARK = L.hexc("#3E3229")
LEAF_A = L.hexc("#4A5E3A")
LEAF_B = L.hexc("#647A48")
LEAF_C = L.hexc("#768A50")
WATER = L.hexc("#4A5654")
WATER_DEEP = L.hexc("#323C3E")
WATER_LIGHT = L.hexc("#7A8682")
BANK = L.hexc("#5E5444")
RIBBON = L.hexc("#1E1C1D")
RIBBON_SHEEN = L.hexc("#3A3638")
box = VB._box


def _done(parts, name: str, cat: str = "props", markers=(), smooth: float = 40.0, shift: bool = True):
    obj = L.join(parts, name)
    for m, loc in markers:
        L.marker(obj, m, tuple(loc))
    L.finish(obj, name, cat, smooth, shift=shift)
    return obj


def _stone(loc, half, color=STONE, rot=(0, 0, 0), seed: int = 0, moss: float = 0.0, jit: float = 0.015):
    o = L.prim("cube", loc=loc, scale=half, rot=rot)
    L.jitter(o, jit, 5.0, seed)
    L.paint(o, L.scale_c(color, random.uniform(0.85, 1.05)), var=0.22, ao=0.25, top=0.15, seed=seed)
    if moss:
        P._tint_up(o, MOSS, moss, 0.3, seed=seed)
    L.set_mat(o, L.MAT_PAINTED)
    return o


# --- well ----------------------------------------------------------------------------------------

def well():
    random.seed(7200)
    L.reset(7200)
    parts = []
    r = 0.72
    n = 14
    for row in range(4):
        z = 0.05 + row * 0.19
        for k in range(n):
            a = (k + 0.5 * (row % 2)) / n * math.tau
            parts.append(_stone((math.cos(a) * r, math.sin(a) * r, z + 0.09), (0.17, 0.1, 0.09), STONE if k % 3 else STONE_OLD,
                                rot=(0, 0, math.degrees(a) + 90), seed=k + row * 20, moss=0.8 if row == 3 else 0.0, jit=0.012))
    cap = L.prim("cyl", loc=(0, 0, 0.84), radius=r + 0.1, depth=0.08, vertices=16)
    hole = None
    del hole
    parts.append(VB._box_paint(cap, SAND, ao=0.0, top=0.3, var=0.2))
    parts.append(VB._box_paint(L.prim("cyl", loc=(0, 0, 0.885), radius=r - 0.12, depth=0.012, vertices=14), L.hexc("#141210"),
                               var=0.0, top=0.0))
    for sx in (-1, 1):
        parts.append(VB._beam((sx * (r + 0.02), 0.0, 0.0), (sx * (r + 0.02), 0.0, 2.3), 0.07, WOOD_DARK, seed=10 + sx))
    # windlass with a crank, rope, bucket
    parts.append(VB._beam((-r - 0.05, 0.0, 1.55), (r + 0.05, 0.0, 1.55), 0.06, WOOD, seed=12))
    parts.append(VB._box_paint(L.prim("cyl", loc=(0, 0, 1.55), rot=(0, 90, 0), radius=0.1, depth=0.5, vertices=10), ROPE, var=0.2))
    parts.append(VB._beam((r + 0.08, 0.0, 1.55), (r + 0.08, -0.25, 1.55), 0.015, IRON, seed=13))
    parts.append(VB._beam((r + 0.08, -0.25, 1.55), (r + 0.2, -0.25, 1.45), 0.015, IRON, seed=14))
    parts.append(VB._beam((0.0, -0.1, 1.55), (0.0, -0.1, 1.08), 0.01, ROPE, seed=15))
    bucket = L.prim("cyl", loc=(0.0, -0.1, 0.96), radius=0.13, depth=0.2, vertices=10)
    L.taper(bucket, 0.86, 1.06, 1.15)
    parts.append(VB._box_paint(bucket, WOOD_OLD, ao=0.3, var=0.2))
    parts.append(L.part("torus", IRON, loc=(0.0, -0.1, 1.03), major_radius=0.145, minor_radius=0.01, major_segments=10, minor_segments=3))
    # little roof
    VB._roof(parts, "x", 0.0, 0.0, 0.62, 0.78, 2.3, 2.85, VB.SHINGLE, over=0.18, row=0.24, seg=0.4, seed=20, mossy=0.5, end_over=0.1)
    _done(parts, "ph_prop_v_well", shift=False)


# --- bridge --------------------------------------------------------------------------------------

def bridge():
    random.seed(7210)
    L.reset(7210)
    parts = []
    hl, hw = 3.0, 1.3      # half length (x) and half width (y)
    top = 0.55

    def deck_z(x):
        return top * (1.0 - (x / hl) ** 2) ** 0.7 if abs(x) < hl else 0.0
    # deck: cobbles on a smooth hump, as a strip of cubes along x
    nx = 12
    for i in range(nx):
        x0 = -hl + i * 2 * hl / nx
        x1 = x0 + 2 * hl / nx
        za, zb = deck_z(x0) if i else 0.0, deck_z(x1) if i < nx - 1 else 0.0
        p0, p1 = Vector((x0, 0, za)), Vector((x1, 0, zb))
        d = p1 - p0
        o = L.prim("cube", scale=(d.length / 2 + 0.01, hw, 0.06))
        ang = math.atan2(d.z, d.x)
        o.data.transform(Matrix.Translation((p0 + p1) / 2 - Vector((0, 0, 0.05))) @ Matrix.Rotation(-ang, 4, "Y"))
        L.jitter(o, 0.01, 4.0, i)
        L.paint(o, L.mix(STONE, L.hexc("#6E6A60"), random.random()), var=0.3, ao=0.0, top=0.1, seed=i)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    # side walls (spandrels) with the arch opening north-south, parapets on top
    for sy in (-1, 1):
        poly = [(-hl, -0.3), (hl, -0.3)]
        for k in range(9):
            x = hl - k * hl / 4
            poly.append((x, deck_z(x) + 0.0))
        poly = [(-hl - 0.2, -0.3), (hl + 0.2, -0.3), (hl + 0.2, 0.0)] + [(hl - k * 2 * hl / 12, deck_z(hl - k * 2 * hl / 12))
                                                                          for k in range(1, 12)] + [(-hl - 0.2, 0.0)]
        # cut the arch: build the spandrel as two halves around a semicircle of r 1.1 springing at -0.3
        r = 1.15
        left = [(-hl - 0.2, -0.3), (-r, -0.3)] + [(-r * math.cos(a), -0.3 + 0.75 * math.sin(a)) for a in
                                                   (math.pi / 2 * k / 5 for k in range(1, 6))]
        left += [(0.0, deck_z(0.0) - 0.08)] + [(x, deck_z(x) - 0.08) for x in (-0.8, -1.6, -2.4)] + [(-hl - 0.2, 0.0)]
        right = [(-x, z) for x, z in reversed(left)]
        del poly
        for pl in (left, right):
            o = VB.B6._prism(pl, "y", sy * hw - 0.15 if sy > 0 else sy * hw, sy * hw if sy > 0 else sy * hw + 0.15, "spandrel")
            L.subdivide(o, 1)
            L.jitter(o, 0.012, 3.0, 30 + sy)
            P._paint_fn(o, lambda co, vi: L.scale_c(L.mix(STONE, STONE_OLD, 0.5 + 0.5 * noise.noise(co * 2.5)),
                                                    0.8 + 0.25 * min(1.0, (co.z + 0.3) / 0.9)))
            L.set_mat(o, L.MAT_PAINTED)
            parts.append(o)
        # voussoirs round the arch
        for k in range(9):
            a = math.pi * (k + 0.5) / 9
            c = Vector((-r * math.cos(a) * 1.04, sy * (hw - 0.07), -0.3 + 0.78 * math.sin(a)))
            parts.append(_stone(c, (0.12, 0.09, 0.06), SAND_DARK, rot=(0, -math.degrees(a) + 90, 0), seed=40 + k, jit=0.006))
        # parapet: a low wall of capped blocks following the hump
        for i in range(8):
            x = -hl + 0.37 + i * (2 * hl - 0.74) / 7
            z = deck_z(x)
            parts.append(_stone((x, sy * (hw - 0.08), z + 0.22), (0.36, 0.1, 0.22), STONE, seed=60 + i + sy * 10, moss=0.3, jit=0.01))
            parts.append(_stone((x, sy * (hw - 0.08), z + 0.47), (0.38, 0.13, 0.05), SAND, seed=80 + i + sy * 10, jit=0.006))
    # dark water shadow under the arch
    parts.append(box((0.0, 0.0, 0.035), (1.1, hw - 0.05, 0.01), L.hexc("#1E2224"), var=0.0, ao=0.0, top=0.0))
    # end posts (where the portal / lantern stand)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_stone((sx * (hl + 0.05), sy * (hw - 0.05), 0.4), (0.15, 0.15, 0.4), SAND_DARK, seed=90 + sx + sy, jit=0.006))
    obj = _done(parts, "ph_prop_v_bridge", shift=False)
    del obj


# --- board, shrine, sign, ribbon, bench, wash stones -----------------------------------------------

def board():
    random.seed(7220)
    L.reset(7220)
    parts = []
    for sx in (-1, 1):
        parts.append(VB._beam((sx * 0.62, 0.0, -0.05), (sx * 0.62, 0.0, 2.05), 0.055, WOOD_DARK, seed=sx))
    parts.append(box((0.0, 0.0, 1.35), (0.58, 0.03, 0.42), WOOD, jit=0.004, seed=3, top=0.2))
    parts.append(box((0.0, -0.035, 1.35), (0.6, 0.012, 0.45), WOOD_DARK, ao=0.0))
    parts.append(box((0.0, -0.032, 1.35), (0.56, 0.008, 0.40), WOOD, ao=0.0, var=0.2))
    for k, (x, z, w, h, rot) in enumerate(((-0.33, 1.5, 0.14, 0.18, 4), (-0.05, 1.42, 0.12, 0.16, -3), (0.25, 1.52, 0.15, 0.2, 2),
                                           (0.3, 1.18, 0.12, 0.13, -5), (-0.28, 1.15, 0.12, 0.15, 3))):
        parts.append(box((x, -0.05, z), (w, 0.004, h), L.scale_c(PAPER, random.uniform(0.85, 1.05)), rot=(0, rot, 0), ao=0.0, var=0.08))
        parts.append(box((x, -0.056, z + h - 0.02), (0.01, 0.004, 0.01), IRON, ao=0.0))
    VB._roof(parts, "x", 0.0, 0.0, 0.18, 0.66, 1.85, 2.08, VB.SHINGLE, over=0.12, row=0.15, seg=0.3, seed=10, mossy=0.4, end_over=0.08)
    _done(parts, "ph_prop_v_board", shift=False)


def shrine():
    random.seed(7230)
    L.reset(7230)
    parts = [_stone((0, 0, 0.1), (0.3, 0.3, 0.1), STONE_OLD, seed=1, moss=0.6)]
    shaft = L.prim("cube", loc=(0, 0, 0.9), scale=(0.13, 0.13, 0.7))
    L.taper(shaft, 0.2, 1.6, 0.85)
    L.jitter(shaft, 0.008, 3.0, 2)
    parts.append(VB._box_paint(shaft, SAND, ao=0.4, var=0.2, top=0.1))
    parts.append(box((0, 0, 1.78), (0.22, 0.18, 0.2), SAND, jit=0.006, seed=3, top=0.2))
    parts.append(box((0, -0.12, 1.78), (0.14, 0.08, 0.15), L.hexc("#2A2622"), var=0.1, ao=0.0, top=0.0))
    parts.append(box((0, -0.1, 1.76), (0.035, 0.03, 0.09), L.hexc("#5A4E44"), ao=0.0))
    parts.append(VB._box_paint(L.prim("ico", loc=(0, -0.1, 1.86), radius=0.03, subdivisions=1), L.hexc("#5A4E44")))
    pyr = L.prim("cone", loc=(0, 0, 2.08), vertices=4, radius1=0.32, radius2=0.02, depth=0.22, rot=(0, 0, 45))
    parts.append(VB._box_paint(pyr, STONE_DARK, top=0.3))
    VB.B6._cross(parts, Vector((0, 0, 2.18)), 0.2, color=IRON, seed=4)
    wr = L.prim("torus", loc=(0, -0.15, 1.35), rot=(90, 0, 0), major_radius=0.09, minor_radius=0.02, major_segments=10, minor_segments=3)
    L.jitter(wr, 0.008, 20.0, 5)
    parts.append(VB._box_paint(wr, L.hexc("#7C6A48"), var=0.3))
    _done(parts, "ph_prop_v_shrine")


def sign():
    random.seed(7240)
    L.reset(7240)
    parts = [VB._beam((-0.5, 0.0, -0.05), (-0.5, 0.0, 1.9), 0.05, WOOD_OLD, seed=1),
             VB._beam((0.5, 0.0, -0.05), (0.5, 0.0, 1.9), 0.05, WOOD_OLD, seed=2)]
    parts.append(box((0.0, -0.04, 1.55), (0.62, 0.025, 0.2), L.hexc("#8A7254"), jit=0.004, seed=3, top=0.2))
    parts.append(box((0.0, -0.068, 1.55), (0.56, 0.004, 0.15), L.hexc("#A89A7A"), ao=0.0, top=0.0))
    _done(parts, "ph_prop_v_sign", markers=[("label_board", (0.0, -0.075, 1.55))])


def ribbon():
    """Mourning ribbon: a black bow with two tails, pivot at the knot (top)."""
    L.reset(7250)
    parts = []
    parts.append(VB._box_paint(L.prim("sphere", loc=(0, 0, 0), radius=1.0, scale=(0.03, 0.02, 0.028), segments=6, ring_count=4),
                               RIBBON))
    for sx in (-1, 1):
        loop = L.prim("sphere", loc=(sx * 0.07, 0.0, 0.01), radius=1.0, scale=(0.06, 0.012, 0.035), segments=6, ring_count=4,
                      rot=(0, sx * 15, 0))
        parts.append(VB._box_paint(loop, RIBBON, top=0.4))
        tail = L.prim("cube", scale=(0.022, 0.004, 0.2))
        tail.data.transform(Matrix.Translation((sx * 0.04, 0.0, -0.21)) @ Matrix.Rotation(math.radians(sx * 8), 4, "Y"))
        parts.append(VB._box_paint(tail, RIBBON, top=0.3, var=0.1))
    obj = L.join(parts, "ph_prop_v_ribbon")
    attr = obj.data.color_attributes["Col"]
    for li, co, nr in ((li, obj.data.vertices[obj.data.loops[li].vertex_index].co, None) for li in range(len(obj.data.loops))):
        if co.z > -0.01:
            c = attr.data[li].color
            attr.data[li].color = (c[0] * 1.3, c[1] * 1.3, c[2] * 1.3, 1.0)
    L.finish(obj, "ph_prop_v_ribbon", "props", 40, shift=False)


def bench():
    random.seed(7260)
    L.reset(7260)
    parts = [box((0.0, 0.0, 0.43), (0.8, 0.17, 0.03), WOOD, jit=0.004, seed=1, top=0.3)]
    for sx in (-1, 1):
        parts.append(box((sx * 0.62, 0.0, 0.2), (0.04, 0.15, 0.2), WOOD_DARK, jit=0.004, seed=2 + sx))
    parts.append(box((0.0, 0.0, 0.12), (0.6, 0.025, 0.025), WOOD_DARK, seed=5))
    _done(parts, "ph_prop_v_bench")


def wash_stones():
    random.seed(7270)
    L.reset(7270)
    parts = []
    for k, (x, y, sx, sy) in enumerate(((0.0, 0.0, 0.5, 0.35), (-0.7, 0.3, 0.4, 0.3), (0.6, 0.45, 0.35, 0.28),
                                       (-0.3, -0.55, 0.38, 0.25))):
        parts.append(_stone((x, y, 0.06), (sx, sy, 0.07), STONE if k % 2 else STONE_OLD, rot=(0, 0, k * 23), seed=k, moss=0.4))
    wb = L.prim("cube", scale=(0.18, 0.02, 0.3))
    wb.data.transform(Matrix.Translation((0.1, 0.2, 0.36)) @ Matrix.Rotation(math.radians(-25), 4, "X"))
    parts.append(VB._box_paint(wb, WOOD_OLD, var=0.2))
    for k in range(6):
        parts.append(box((0.1, 0.18 - k * 0.0, 0.18 + k * 0.07), (0.17, 0.035, 0.008), L.scale_c(WOOD_OLD, 0.8), rot=(-25, 0, 0), ao=0.0))
    parts.append(VB._box_paint(L.prim("cyl", loc=(-0.6, -0.1, 0.22), radius=0.22, depth=0.16, vertices=10), WOOD, var=0.2, ao=0.3))
    parts.append(box((-0.6, -0.1, 0.31), (0.16, 0.16, 0.012), L.hexc("#C8C0AC"), ao=0.0, var=0.2))
    _done(parts, "ph_prop_v_wash_stones")


# --- linden ----------------------------------------------------------------------------------------

def linden():
    """The old linden: a thick, slightly leaning, furrowed trunk that splits low into three leaders,
    a broad, dense crown (r ~4.5 m, top <= 9 m) of fresh mid-green clumps, lighter than the oak."""
    random.seed(7280)
    L.reset(7280)
    parts = []
    trunk = _limb((0, 0, -0.3), (0.1, 0.06, 1), 3.2, 0.6, 0.42, 1, segs=8, verts=12)
    parts.append(trunk)
    for i in range(5):
        a = i / 5 * math.tau + 0.3
        parts.append(_limb((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.5), (math.cos(a), math.sin(a), -0.8),
                           random.uniform(0.9, 1.2), 0.25, 0.08, 10 + i, segs=3, verts=6))
    top = Vector((0.3, 0.2, 2.8))
    leaders = [((0.9, 0.3, 1.0), 3.2), ((-0.8, 0.4, 1.0), 3.0), ((0.1, -0.9, 1.0), 2.8), ((0.2, 0.9, 1.1), 3.0)]
    tips = []
    for i, (d, ln) in enumerate(leaders):
        parts.append(_limb(top, d, ln, 0.26, 0.08, 20 + i, segs=4, verts=7, droop=0.05))
        tips.append(top + Vector(d).normalized() * ln)
    for p in parts:
        L.paint(p, BARK, var=0.25, ao=0.5, zrange=(0, 6.0), seed=3, hue_shift=MOSS if p is trunk else BARK_DARK)
        # furrows: vertical dark lines
        attr = p.data.color_attributes["Col"]
        for li in range(len(p.data.loops)):
            co = p.data.vertices[p.data.loops[li].vertex_index].co
            if math.sin(math.atan2(co.y, co.x) * 9.0 + co.z * 0.6) > 0.6:
                c = attr.data[li].color
                attr.data[li].color = (c[0] * 0.7, c[1] * 0.7, c[2] * 0.7, 1.0)
        L.set_mat(p, L.MAT_PAINTED)
    leaves = []
    centres = tips + [top + Vector((0, 0, 4.6)), top + Vector((1.6, 1.2, 3.6)), top + Vector((-1.8, -0.6, 3.7)),
                      top + Vector((0.4, -2.2, 3.2)), top + Vector((-0.8, 2.2, 3.4)), top + Vector((2.6, -0.8, 2.4)),
                      top + Vector((-2.8, 1.0, 2.4))]
    for i, t in enumerate(centres):
        for j in range(4):
            r = random.uniform(0.9, 1.4)
            off = Vector((random.uniform(-1.0, 1.0), random.uniform(-1.0, 1.0), random.uniform(-0.4, 0.6)))
            c = t + off
            c.z = min(c.z, 8.9 - r * 0.7)
            s_ = L.prim("ico", loc=c, radius=r, subdivisions=2, scale=(1, 1, 0.72))
            L.jitter(s_, 0.28, 1.6, i * 5 + j)
            shade = random.random()
            L.paint(s_, L.mix(LEAF_A, LEAF_B, 0.3 + shade * 0.7), var=0.35, ao=0.6, top=0.4, zrange=(3.0, 9.0), seed=i * 5 + j,
                    hue_shift=LEAF_C if shade > 0.5 else None)
            L.set_mat(s_, L.MAT_FOLIAGE)
            leaves.append(s_)
    obj = L.join(parts + leaves, "ph_env_linden_old")
    zmax = max(v.co.z for v in obj.data.vertices)
    if zmax > 8.95:
        for v in obj.data.vertices:
            if v.co.z > 2.5:
                v.co.z = 2.5 + (v.co.z - 2.5) * (6.45 / (zmax - 2.5))
    L.finish(obj, "ph_env_linden_old", "environment", 50, shift=False)


# --- brook, garden fence, milestone ------------------------------------------------------------------

def _brook_x(y: float) -> float:
    return 0.35 * math.sin(y * 0.16 + 0.6) + 0.15 * math.sin(y * 0.41)


def brook():
    random.seed(7290)
    L.reset(7290)
    parts = []
    hl = 22.0
    ny = 44
    bm = bmesh.new()
    rows = []
    us = (-1.6, -1.25, -0.9, -0.3, 0.3, 0.9, 1.25, 1.6)
    zs = (0.0, 0.07, 0.025, 0.02, 0.02, 0.025, 0.07, 0.0)   # flat painted water a hair over the ground, a bank lip
    for j in range(ny + 1):
        y = -hl + 2 * hl * j / ny
        cx = _brook_x(y)
        w = 1.0 + 0.08 * math.sin(y * 0.7)
        rows.append([bm.verts.new((cx + u * w, y, z)) for u, z in zip(us, zs)])
    for j in range(ny):
        for i in range(len(us) - 1):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    me = bpy.data.meshes.new("brook")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("brook", me)
    bpy.context.collection.objects.link(o)

    def fn(co, vi):
        u = abs(co.x - _brook_x(co.y))
        n = noise.noise(Vector((co.x * 0.8, co.y * 0.35, 3.0)))
        streak = max(0.0, math.sin(co.y * 2.2 + co.x * 1.3 + n * 3.0)) ** 6
        if u > 1.2:
            return L.mix(BANK, MOSS, 0.4 + 0.3 * n)
        c = L.mix(WATER, WATER_DEEP, max(0.0, 1.0 - u / 0.9) * 0.6 + 0.2 * n)
        return L.mix(c, WATER_LIGHT, 0.35 * streak)
    P._paint_fn(o, fn)
    L.set_mat(o, L.MAT_PAINTED)
    parts.append(o)
    for k in range(40):   # stones along the banks and a few in the water
        y = random.uniform(-hl + 0.5, hl - 0.5)
        side = random.choice((-1, 1))
        u = side * random.uniform(0.9, 1.4) if k < 32 else random.uniform(-0.6, 0.6)
        x = _brook_x(y) + u
        r = random.uniform(0.08, 0.22)
        parts.append(_stone((x, y, 0.02 if k >= 32 else 0.04), (r, r * 0.8, r * 0.45), random.choice((STONE, STONE_OLD, STONE_DARK)),
                            rot=(0, 0, random.uniform(0, 90)), seed=100 + k, moss=0.5, jit=0.02))
    _done(parts, "ph_env_brook", "environment", shift=False)


def garden_fence():
    random.seed(7300)
    L.reset(7300)
    parts = []
    for sx in (-1, 1):
        parts.append(VB._beam((sx * 0.98, 0.0, -0.05), (sx * 0.98, 0.0, 0.95), 0.04, WOOD_DARK, seed=sx))
    for z in (0.3, 0.72):
        parts.append(VB._beam((-1.0, 0.03, z), (1.0, 0.03, z + random.uniform(-0.02, 0.02)), 0.025, WOOD_OLD, seed=3))
    for k in range(9):
        x = -0.85 + k * 0.212
        h = 0.85 + random.uniform(-0.05, 0.05)
        p = L.prim("cube", loc=(x, -0.0, h / 2), scale=(0.035, 0.012, h / 2), rot=(0, random.uniform(-3, 3), 0))
        parts.append(VB._box_paint(p, L.scale_c(WOOD_OLD, random.uniform(0.85, 1.1)), ao=0.3, var=0.2))
    _done(parts, "ph_env_garden_fence", "environment")


def milestone():
    random.seed(7310)
    L.reset(7310)
    st = L.prim("cube", loc=(0, 0, 0.42), scale=(0.24, 0.14, 0.46))
    L.subdivide(st, 2)
    for v in st.data.vertices:
        if v.co.z > 0.6:
            k = (v.co.z - 0.6) / 0.28
            v.co.x *= 1.0 - 0.45 * k * k
            v.co.z -= 0.08 * (abs(v.co.x) / 0.24) ** 2
    L.jitter(st, 0.012, 3.0, 1)
    L.paint(st, SAND_DARK, var=0.25, ao=0.45, top=0.2, seed=2, hue_shift=STONE_OLD)
    P._tint_up(st, MOSS, 0.6, 0.45, seed=3)
    L.set_mat(st, L.MAT_PAINTED)
    parts = [st]
    parts.append(box((0.0, -0.145, 0.52), (0.16, 0.006, 0.12), L.scale_c(SAND_DARK, 0.85), ao=0.0, var=0.1))
    for k in range(5):
        a = k / 5 * math.tau
        parts.append(_stone((math.cos(a) * 0.3, math.sin(a) * 0.22, 0.03), (0.07, 0.05, 0.04), STONE_OLD, seed=10 + k, moss=0.5))
    _done(parts, "ph_prop_milestone", markers=[("label_board", (0.0, -0.152, 0.52))])


# --- D1: the poppy posy on corpse look 1 ---------------------------------------------------------------

POSY_AT = (0.3, -0.08, 0.245)   # Blender coords of ph_prop_corpse_02 (head +X): on the bodice, left of the sternum


def corpse_poppy():
    """Dried poppy posy for look 1 (the old woman): lies on the bodice, stems towards the feet."""
    L.reset(7320)
    parts = []
    import asset_villagers as V
    base = Vector(POSY_AT)
    tmp = []
    V._posy(tmp, Vector((0, 0, 0)), Vector((0, -1, 0.2)).normalized(), "spine", seed=5, scale=1.15)
    # lying flat: the posy's up (stems -> heads) points to the head (+X), its front faces up (+Z)
    rot = Matrix(((0.0, 0.0, 1.0), (-1.0, 0.0, 0.0), (0.0, -1.0, 0.0))).to_4x4()
    m = Matrix.Translation(base) @ rot
    for o in tmp[12:14]:          # one seed pod fewer than on her bodice in life (budget 300)
        bpy.data.objects.remove(o)
    tmp = tmp[:12] + tmp[14:]
    for o in tmp:
        for g in list(o.vertex_groups):
            o.vertex_groups.remove(g)
        o.data.transform(m)
        parts.append(o)
    obj = L.join(parts, "ph_prop_corpse_poppy")
    obj.name = "ph_prop_corpse_poppy"
    L.finish(obj, "ph_prop_corpse_poppy", "props", 40, shift=False)


ASSETS = [well, bridge, board, shrine, sign, ribbon, bench, wash_stones, linden, brook, garden_fence, milestone, corpse_poppy]


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
