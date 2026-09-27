"""Phase-3 decor and props (contract docs/PHASE3_DESIGN.md section 8), 'Gemaltes Diorama' style.

Decor (assets/models/decor): wooden bench, stone bench, flower bed, grave vase, small grave
lantern, two gravel tiles.  Props (assets/models/props): broken fence, fence passage, large
field-stone heap, notice board.
Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m, shared materials only.
Fence pieces follow ph_prop_fence_iron: they run along +X from x = 0.

Markers (glTF nodes, found by name in Godot):
  light_lantern  ph_deco_lantern_small - centre of the glass (warm light, no shadows)
  label_board    ph_prop_notice_board - front face of the board (for a Label3D)

Run:  python tools/blender/build_all.py asset_props_phase3
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P

WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
WOOD_FRESH = P.WOOD_FRESH
IRON = P.IRON
RUST = P.RUST
STONE = P.STONE
STONE_OLD = P.STONE_OLD
STONE_BLUE = P.STONE_BLUE
MOSS = P.MOSS
EARTH = P.EARTH
EARTH_FRESH = P.EARTH_FRESH
LEAF_A = P.LEAF_A
LEAF_B = P.LEAF_B
LINEN = P.LINEN
LINEN_DIRTY = P.LINEN_DIRTY
# wild flowers: amber / pale violet / white - never a cold saturated blue (section 8)
FLOWER_AMBER = L.hexc("#D39A3E")
FLOWER_VIOLET = L.hexc("#A08CB0")
FLOWER_WHITE = L.hexc("#E2DCCB")
GRAVEL = L.hexc("#8A857C")
GRAVEL_DARK = L.hexc("#666560")


# --- helpers ---------------------------------------------------------------------

def _lathe(profile, n: int, name: str = "lathe", cap_top: bool = False, wobble: float = 0.0, seed: int = 0):
    """Surface of revolution from [(radius, z)] (bottom first), bottom closed by a fan."""
    bm = bmesh.new()
    rings = []
    off = Vector((seed * 1.7, seed * 2.9, 0.0))
    for r, z in profile:
        ring = []
        for j in range(n):
            a = j / n * math.tau
            f = 1.0 + wobble * noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, z * 3.0)) + off)
            ring.append(bm.verts.new((math.cos(a) * r * f, math.sin(a) * r * f, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for j in range(n):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % n], rings[k + 1][(j + 1) % n], rings[k + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    return P._link(bm, name)


def _flower_head(loc, r: float, color, centre, seed: int, tilt=(0.0, 0.0)):
    """Five-petal star head (15 tris): flat face with a darker/golden eye, shallow cup below."""
    bm = bmesh.new()
    c = bm.verts.new((0, 0, 0.004))
    ring = []
    for j in range(10):
        a = j / 10 * math.tau
        rr = r if j % 2 == 0 else r * 0.5
        ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, 0.0)))
    apex = bm.verts.new((0, 0, -r * 0.45))
    for j in range(10):
        bm.faces.new((c, ring[j], ring[(j + 1) % 10]))
    for j in range(0, 10, 2):                       # shallow cup under the petal tips only
        bm.faces.new((apex, ring[(j + 2) % 10], ring[j]))
    o = P._link(bm, "flower")
    o.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y") @
                     Matrix.Rotation(math.radians(tilt[0]), 4, "X") @
                     Matrix.Rotation(random.uniform(0, 1.3), 4, "Z"))
    col = L.scale_c(color, random.uniform(0.92, 1.06))

    def fn(co, vi):
        if vi == 0:
            return centre
        return col if vi <= 10 else L.scale_c(col, 0.7)
    P._paint_fn(o, fn)
    L.set_mat(o, L.MAT_PAINTED)
    return o


FLOWER_EYE = {"amber": L.hexc("#6B4A2A"), "other": L.hexc("#C8973A")}


def _flower(parts, base, height: float, color, seed: int, lean=(0.0, 0.0), head_r: float = 0.03,
            stem_color=None):
    """One wild flower: thin 3-sided stem and a small five-petal star head."""
    top = Vector(base) + Vector((lean[0], lean[1], height))
    parts.append(P._stick(base, top, 0.005, stem_color or LEAF_B, r1=0.0035, verts=3, seed=seed, ao=0.3))
    eye = FLOWER_EYE["amber"] if color == FLOWER_AMBER else FLOWER_EYE["other"]
    tilt = (-lean[1] * 250.0, lean[0] * 250.0)
    parts.append(_flower_head(top, head_r, color, eye, seed, tilt))


def _pebble(loc, r: float, seed: int, color=None):
    """Small wedging stone: a squashed, wobbly 20-tri icosphere, a little mossy on top."""
    s = L.prim("ico", loc=loc, radius=r, subdivisions=1, scale=(1.0, random.uniform(0.75, 0.95), 0.6),
               rot=(0, 0, random.uniform(0, 72)))
    L.jitter(s, r * 0.2, 1.2 / r, seed)
    L.paint(s, L.scale_c(color or STONE_OLD, random.uniform(0.85, 1.05)), var=0.2, ao=0.35, top=0.2, seed=seed,
            hue_shift=MOSS)
    P._tint_up(s, MOSS, 0.5, 0.5, seed=seed)
    L.set_mat(s, L.MAT_PAINTED)
    return s


def _leaf_clump(loc, r: float, seed: int, subdiv: int = 2, squash: float = 0.7, color=None, zr=(0.0, 0.5)):
    """Small leafy clump in mat_foliage (the approved bush recipe, scaled down)."""
    s = L.prim("ico", loc=loc, radius=r, subdivisions=subdiv, scale=(1.0, 1.0, squash))
    L.jitter(s, r * 0.28, 2.4 / r * 0.35, seed)
    shade = random.random()
    col = color or L.mix(LEAF_A, LEAF_B, 0.1 + shade * 0.5)
    L.paint(s, col, var=0.35, ao=0.6, top=0.35, zrange=zr, seed=seed,
            hue_shift=L.hexc("#6E7A45") if shade > 0.55 else None)
    L.set_mat(s, L.MAT_FOLIAGE)
    return s


# --- decor -------------------------------------------------------------------------

def bench_wood():
    """Rustic wooden bench (1.4 x 0.45 m, seat at 0.45 m): three weathered, rounded seat boards
    of slightly different lengths on two splayed trestles with a low stretcher and pegs."""
    L.reset(500)
    parts = []
    top = 0.45
    for i, y in enumerate((-0.148, 0.0, 0.148)):
        hl = random.uniform(0.66, 0.7)
        col = L.mix(WOOD, WOOD_OLD, random.uniform(0.35, 0.7))
        b = P._rbox((random.uniform(-0.02, 0.02), y, top - 0.03), (hl, 0.07, 0.03), col, bev=0.014, seg=1,
                    jit=0.0, seed=i, ao=0.2, zrange=(0, top), hue_shift=WOOD_OLD)
        L.jitter(b, 0.006, 2.5, i)
        for v in b.data.vertices:                    # a little sag in the middle
            v.co.z -= 0.008 * max(0.0, 1.0 - abs(v.co.x) / 0.5)
        parts.append(b)
    for sx in (-1, 1):
        x = sx * 0.5
        parts.append(P._rbox((x, 0, top - 0.09), (0.05, 0.215, 0.032), WOOD_DARK, bev=0.012, seg=1, jit=0.005,
                             seed=10 + sx, zrange=(0, top), ao=0.3))
        for sy in (-1, 1):  # splayed legs, mossy at the foot
            parts.append(P._stick((x, sy * 0.13, top - 0.1), (x + sx * 0.06, sy * 0.19, 0.0), 0.036, WOOD_DARK,
                                  r1=0.031, verts=6, seed=12 + sy, ao=0.55, zrange=(0, top), hue_shift=MOSS))
        for sy in (-0.148, 0.148):  # wooden pegs through the seat
            parts.append(L.part("cyl", L.scale_c(WOOD_DARK, 0.8), loc=(x, sy, top + 0.001), radius=0.015, depth=0.01,
                                vertices=6, paint_kw={"ao": 0.0}))
    parts.append(P._stick((-0.52, 0.0, 0.17), (0.52, 0.0, 0.16), 0.03, WOOD_DARK, verts=6, seed=20,
                          zrange=(0, top), ao=0.3))
    obj = L.join(parts, "ph_deco_bench_wood")
    P._center_xy(obj)
    L.finish(obj, "ph_deco_bench_wood", "decor", 35)


def bench_stone():
    """Stone bench (1.4 x 0.45 m): a worn, chipped and mossy slab on two squat rough blocks."""
    L.reset(510)
    top = 0.45
    slab = L.prim("cube", loc=(0, 0, top - 0.055), scale=(0.69, 0.21, 0.055))
    L.bevel(slab, 0.02, 1)
    L.subdivide(slab, 2)
    L.jitter(slab, 0.028, 1.6, 1)
    L.jitter(slab, 0.008, 7.0, 2)
    for v in slab.data.vertices:  # sat-in hollow in the middle of the seat
        if v.co.z > top - 0.03:
            v.co.z -= 0.014 * max(0.0, 1.0 - abs(v.co.x) / 0.6)
    L.paint(slab, L.scale_c(L.mix(STONE, STONE_OLD, 0.6), 0.9), var=0.3, ao=0.35, zrange=(0, top), hue_shift=MOSS,
            seed=2)
    P._tint_up(slab, MOSS, 0.9, 0.3, freq=2.5, seed=3)
    L.set_mat(slab, L.MAT_PAINTED)
    parts = [slab]
    for sx in (-1, 1):
        blk = L.prim("cube", loc=(sx * 0.45, 0, (top - 0.11) / 2), scale=(0.12, 0.165, (top - 0.11) / 2))
        L.bevel(blk, 0.02, 1)
        L.subdivide(blk, 1)
        L.jitter(blk, 0.02, 2.5, 5 + sx)
        for v in blk.data.vertices:  # a little wider at the foot
            if v.co.z < 0.1:
                v.co.x = sx * 0.45 + (v.co.x - sx * 0.45) * 1.1
                v.co.y *= 1.1
        L.paint(blk, L.scale_c(STONE_OLD, 0.9), var=0.3, ao=0.65, zrange=(0, top), hue_shift=MOSS, seed=6 + sx)
        P._tint_up(blk, MOSS, 0.7, 0.3, seed=7)
        L.set_mat(blk, L.MAT_PAINTED)
        parts.append(blk)
    for i in range(4):  # a few pebbles at the feet
        sx = -1 if i < 2 else 1
        parts.append(_pebble((sx * random.uniform(0.3, 0.62), random.uniform(-0.26, 0.26), 0.015), 0.035, 20 + i))
    obj = L.join(parts, "ph_deco_bench_stone")
    P._center_xy(obj)
    L.finish(obj, "ph_deco_bench_stone", "decor", 35)


def flowerbed():
    """1 x 1 m bed: split-log edging with corner stakes, a dark soil mound and painted wild
    flowers (amber, pale violet, white) between low leafy clumps."""
    L.reset(520)
    parts = []
    h = 0.47
    for i, (x, y, sx, sy) in enumerate(((0, -h, 0.5, 0.045), (0, h, 0.5, 0.045),
                                        (-h, 0, 0.045, 0.43), (h, 0, 0.045, 0.43))):
        parts.append(P._rbox((x, y, 0.06), (sx, sy, 0.06), L.scale_c(WOOD_OLD, random.uniform(0.9, 1.1)), bev=0.025,
                             seg=1, jit=0.006, seed=i, ao=0.45, zrange=(0, 0.14), hue_shift=MOSS))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", WOOD_DARK, loc=(sx * h, sy * h, 0.075), scale=(0.03, 0.03, 0.075),
                                rot=(0, 0, 45), jit=0.004, seed=5, paint_kw={"ao": 0.5}))
    soil = P._rings_mesh([(0.43, 0.43, 0.075), (0.36, 0.36, 0.1), (0.24, 0.24, 0.115)], 20, p=4.0, name="soil")
    L.jitter(soil, 0.008, 6.0, 9)
    L.paint(soil, EARTH_FRESH, var=0.3, ao=0.0, noise_freq=5.0, hue_shift=EARTH, seed=9)
    L.set_mat(soil, L.MAT_PAINTED)
    parts.append(soil)
    clumps = [(-0.26, -0.24), (0.06, -0.27), (0.27, -0.16), (-0.08, -0.02), (-0.28, 0.16), (0.2, 0.12),
              (0.02, 0.28)]
    for i, (x, y) in enumerate(clumps):
        parts.append(_leaf_clump((x, y, 0.1), random.uniform(0.075, 0.095), 30 + i, subdiv=2, squash=0.5,
                                 zr=(0.05, 0.2)))
    colours = [FLOWER_AMBER, FLOWER_VIOLET, FLOWER_WHITE]
    k = 0
    for i, (x, y) in enumerate(clumps):  # a few flowers rising out of each clump
        for j in range(3):
            a = random.uniform(0, math.tau)
            d = random.uniform(0.01, 0.08)
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            col = colours[(i + j * 2) % 3]
            _flower(parts, (px, py, 0.1), random.uniform(0.09, 0.17), col, 40 + k,
                    lean=(math.cos(a) * 0.025, math.sin(a) * 0.025), head_r=random.uniform(0.038, 0.048))
            k += 1
    obj = L.join(parts, "ph_deco_flowerbed")
    P._center_xy(obj)
    L.finish(obj, "ph_deco_flowerbed", "decor", 45)


def grave_vase():
    """Small stone urn on a foot with a bunch of wild flowers (~0.3 m high without flowers)."""
    L.reset(530)
    prof = [(0.07, 0.0), (0.075, 0.03), (0.045, 0.05), (0.04, 0.08), (0.075, 0.13), (0.09, 0.2), (0.08, 0.26),
            (0.065, 0.285), (0.085, 0.3), (0.075, 0.315), (0.06, 0.3)]
    urn = _lathe(prof, 8, "urn", wobble=0.04, seed=1)
    L.paint(urn, L.mix(STONE, STONE_OLD, 0.5), var=0.25, ao=0.6, zrange=(0, 0.32), hue_shift=MOSS, seed=2)
    P._tint_up(urn, MOSS, 0.6, 0.35, seed=3)
    L.set_mat(urn, L.MAT_PAINTED)
    parts = [urn]
    parts.append(L.part("cyl", P.EARTH_DARK, loc=(0, 0, 0.29), radius=0.058, depth=0.01, vertices=8,
                        paint_kw={"ao": 0.0}))
    parts.append(_leaf_clump((0.0, 0.0, 0.31), 0.07, 20, subdiv=2, squash=0.55, zr=(0.25, 0.4)))
    cols = [FLOWER_AMBER, FLOWER_WHITE, FLOWER_VIOLET, FLOWER_AMBER, FLOWER_WHITE, FLOWER_VIOLET, FLOWER_WHITE]
    for i, c in enumerate(cols):
        a = i / len(cols) * math.tau + 0.3
        rr = 0.0 if i == 0 else 0.025
        _flower(parts, (math.cos(a) * rr, math.sin(a) * rr, 0.29), random.uniform(0.08, 0.13) + (0.04 if i == 0 else 0),
                c, 10 + i, lean=(math.cos(a) * rr * 1.6, math.sin(a) * rr * 1.6), head_r=0.03)
    obj = L.join(parts, "ph_deco_grave_vase")
    P._center_xy(obj)
    L.finish(obj, "ph_deco_grave_vase", "decor", 50)


def lantern_small():
    """Grave lantern on a stake (0.9 m): weathered post, little iron lantern with a warm glass,
    pyramid roof and a ring on top.  light_lantern sits in the glass."""
    L.reset(540)
    post = L.prim("cube", loc=(0, 0, 0.32), scale=(0.032, 0.032, 0.32))
    L.subdivide(post, 1)
    L.jitter(post, 0.004, 3.0, 1)
    L.paint(post, WOOD_OLD, var=0.2, ao=0.55, zrange=(0, 0.9), hue_shift=MOSS, seed=2)
    L.set_mat(post, L.MAT_PAINTED)
    parts = [post]
    z0 = 0.64
    parts.append(L.part("cube", IRON, loc=(0, 0, z0 + 0.012), scale=(0.07, 0.07, 0.012),
                        paint_kw={"hue_shift": RUST, "var": 0.3}))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(0, 0, z0 + 0.1), scale=(0.048, 0.048, 0.075)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(sx * 0.052, sy * 0.052, z0 + 0.1), scale=(0.008, 0.008, 0.08)))
    parts.append(L.part("cube", IRON, loc=(0, 0, z0 + 0.183), scale=(0.066, 0.066, 0.01)))
    parts.append(L.part("cone", IRON, loc=(0, 0, z0 + 0.225), vertices=4, radius1=0.095, depth=0.075, rot=(0, 0, 45),
                        paint_kw={"hue_shift": RUST, "var": 0.35}))
    parts.append(L.part("torus", IRON, loc=(0, 0, z0 + 0.275), rot=(90, 0, 0), major_radius=0.022, minor_radius=0.006,
                        major_segments=8, minor_segments=3))
    parts.append(L.part("cube", IRON, loc=(0, -0.034, 0.5), scale=(0.036, 0.004, 0.012)))  # iron band on the post
    for i in range(4):  # stones wedging the stake
        a = i / 4 * math.tau + 0.5
        parts.append(_pebble((math.cos(a) * 0.07, math.sin(a) * 0.065, 0.015), 0.038, 10 + i))
    obj = L.join(parts, "ph_deco_lantern_small")
    L.marker(obj, "light_lantern", (0, 0, z0 + 0.1))
    obj.rotation_euler = (math.radians(2.0), math.radians(-1.5), 0.0)
    L.finish(obj, "ph_deco_lantern_small", "decor", 30)


def _gravel_tile(name: str, seed: int, tone: float):
    """0.5 x 0.5 m flush gravel plate (<= 2 cm) that tiles seamlessly on the 0.5 m build grid: a
    square, slightly domed pad of grey grit (edges at the same height and colour on every tile)
    with a dense scatter of open four-sided pebbles (4 tris each)."""
    L.reset(seed)
    off = Vector((seed * 0.37, seed * 0.11, 0))
    pad = L.prim("grid", x_subdivisions=4, y_subdivisions=4, size=0.5)   # 4 x 4 quads, corners at +-0.25
    for v in pad.data.vertices:
        edge = max(abs(v.co.x), abs(v.co.y)) / 0.25
        v.co.z = 0.003 + 0.006 * (1.0 - edge) + (noise.noise(v.co * 20.0 + off) * 0.0015 if edge < 0.99 else 0.0)
    base = L.scale_c(GRAVEL, tone)

    def col(co, vi):
        edge = max(abs(co.x), abs(co.y)) / 0.25
        n = noise.noise(co * 9.0 + off) if edge < 0.99 else 0.0
        return L.mix(base, GRAVEL_DARK, 0.72 + max(0.0, n) * 0.25)
    P._paint_fn(pad, col)
    L.set_mat(pad, L.MAT_PAINTED)
    parts = [pad]
    tones = (GRAVEL, STONE, STONE_BLUE, L.hexc("#A39C8F"), L.hexc("#B0A898"), L.hexc("#8F8A80"))
    for i in range(29):
        r = random.uniform(0.028, 0.044)
        x, y = random.uniform(-0.215, 0.215), random.uniform(-0.215, 0.215)
        peb = L.prim("cone", loc=(x, y, 0.0105), radius1=r, depth=0.014, vertices=4, end_fill_type="NOTHING",
                     rot=(random.uniform(-6, 6), random.uniform(-6, 6), random.uniform(0, 90)),
                     scale=(1.0, random.uniform(0.6, 1.0), 1.0))
        c = L.scale_c(random.choice(tones), tone * random.uniform(0.85, 1.05))
        parts.append(P._finish_obj(peb, c, var=0.1, ao=0.0, top=0.1, seed=i))
    obj = L.join(parts, name)
    L.finish(obj, name, "decor", 30)


def path_gravel():
    _gravel_tile("ph_deco_path_gravel", 550, 1.0)


def path_gravel_02():
    _gravel_tile("ph_deco_path_gravel_02", 551, 0.94)


# --- props -------------------------------------------------------------------------

def _fence_bar(parts, x: float, h: float, lean_x: float = 0.0, lean_y: float = 0.0, bend: float = 0.0):
    """One wrought-iron bar with a spear tip, standing at x (bent: the upper half kinks by `bend` deg)."""
    if bend == 0.0:
        parts.append(L.part("cube", IRON, loc=(x, 0, h / 2), scale=(0.012, 0.012, h / 2), rot=(lean_x, lean_y, 0)))
        tip_rot = Matrix.Rotation(math.radians(lean_y), 4, "Y") @ Matrix.Rotation(math.radians(lean_x), 4, "X")
        tip = tip_rot @ Vector((0, 0, h / 2 + 0.05)) + Vector((x, 0, h / 2))
        parts.append(L.part("cone", IRON, loc=tip, radius1=0.03, depth=0.1, vertices=4, rot=(lean_x, lean_y, 45)))
        return
    k = h * 0.45
    parts.append(L.part("cube", IRON, loc=(x, 0, k / 2), scale=(0.012, 0.012, k / 2)))
    d = Vector((0, -math.sin(math.radians(bend)), math.cos(math.radians(bend))))
    top = Vector((x, 0, k)) + d * (h - k)
    parts.append(P._finish_obj(L.tube((x, 0, k), top, 0.013, 4), IRON))
    parts.append(L.part("cone", IRON, loc=top + d * 0.05, radius1=0.03, depth=0.1, vertices=4, rot=(-bend, 0, 45)))


def fence_iron_broken():
    """2 m fence segment like ph_prop_fence_iron (along +X from x = 0), but caved in: a gap
    without bars in the middle, the top rail snapped with its end hanging into the grass, one
    kinked bar, the right-hand part leaning forward and three bars lying in the grass."""
    L.reset(560)
    parts = []
    parts.append(L.part("cube", IRON, loc=(1.0, 0, 0.18), scale=(1.0, 0.015, 0.02), rot=(0, 1.2, 0)))
    parts.append(L.part("cube", IRON, loc=(0.42, 0, 0.92), scale=(0.42, 0.015, 0.02)))           # top rail, left
    parts.append(P._finish_obj(L.tube((0.83, 0.0, 0.92), (1.08, -0.16, 0.03), 0.018, 4), IRON))  # snapped, hanging
    right = []
    n = 11
    for i in range(n):
        x = (i + 0.5) * 2.0 / n
        h = 1.05 + (0.06 if i % 2 == 0 else 0.0)
        if i in (5, 6, 7):
            continue                                               # the gap
        if i == 4:
            _fence_bar(parts, x, h, bend=38.0)                     # kinked bar at the edge of the gap
        elif i >= 8:
            _fence_bar(right, x, h, lean_y=random.uniform(-2, 2))
        else:
            _fence_bar(parts, x, h, lean_x=random.uniform(-2.5, 2.5), lean_y=random.uniform(-2.5, 2.5))
    right.append(L.part("cube", IRON, loc=(1.72, 0, 0.92), scale=(0.28, 0.015, 0.02)))           # top rail, right
    lean = Matrix.Translation((0, 0, 0.18)) @ Matrix.Rotation(math.radians(-11), 4, "X") @ \
        Matrix.Translation((0, 0, -0.18))
    for o in right:                                                # the right part caves in towards the front
        o.data.transform(lean)
    parts += right
    lying = [((1.02, -0.4, 0.015), 8.0, 1.06), ((1.4, -0.62, 0.015), -24.0, 1.0), ((0.55, -0.55, 0.015), 160.0, 0.62)]
    for (x, y, z), yaw, ln in lying:                               # fallen bars in the grass
        d = Vector((math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), 0.0))
        a = Vector((x, y, z)) - d * ln / 2
        b = Vector((x, y, z)) + d * ln / 2
        parts.append(P._finish_obj(L.tube(a, b, 0.012, 4), IRON))
        parts.append(L.part("cone", IRON, loc=b + d * 0.05, radius1=0.03, depth=0.1, vertices=4,
                            rot=(0, 90, yaw)))
    for o in parts:
        L.paint(o, IRON, var=0.3, ao=0.2, hue_shift=RUST, seed=3)
    obj = L.join(parts, "ph_prop_fence_iron_broken")
    L.finish(obj, "ph_prop_fence_iron_broken", "props", 30)


def _stone_pillar(x: float, h: float, seed: int):
    """Mossy stone pillar in the style of ph_prop_gate_post (a little slimmer)."""
    body = L.prim("cube", loc=(x, 0, h / 2), scale=(0.17, 0.17, h / 2))
    L.subdivide(body, 2)
    L.jitter(body, 0.022, 2.0, seed)
    L.paint(body, L.mix(STONE, STONE_OLD, 0.4), var=0.3, ao=0.6, zrange=(0, h + 0.3), hue_shift=MOSS, seed=seed + 1)
    P._tint_up(body, MOSS, 0.8, 0.25, seed=seed)
    L.set_mat(body, L.MAT_PAINTED)
    cap = L.part("cube", STONE, loc=(x, 0, h + 0.05), scale=(0.21, 0.21, 0.05), jit=0.01, seed=seed + 2,
                 paint_kw={"hue_shift": MOSS, "zrange": (0, h + 0.3), "var": 0.25})
    P._tint_up(cap, MOSS, 0.7, 0.4, seed=seed + 2)
    ball = L.part("sphere", STONE, loc=(x, 0, h + 0.19), radius=0.09, segments=8, ring_count=5, jit=0.008,
                  seed=seed + 3, paint_kw={"hue_shift": MOSS, "var": 0.25})
    return [body, cap, ball]


def fence_passage():
    """Open passage in the fence line (2.4 m along +X from x = 0): two stone pillars in the
    gate-post style, joined by a wrought-iron arch with a small cross at its crown."""
    L.reset(570)
    w, h = 2.4, 1.3
    parts = _stone_pillar(0.17, h, 1) + _stone_pillar(w - 0.17, h, 5)
    arch = []
    for i in range(15):                                             # arch between the caps
        t = i / 14
        x = 0.3 + (w - 0.6) * t
        arch.append((x, 0.0, h + 0.1 + 0.5 * math.sin(math.pi * t) ** 0.8))
    parts.append(P._finish_obj(P._path_tube(arch, 0.018, 4, hint=(0, 1, 0)), IRON))
    inner = [(x, y, z - 0.14 + 0.1 * abs(x - w / 2) / (w / 2)) for (x, y, z) in arch[2:-2]]
    parts.append(P._finish_obj(P._path_tube(inner, 0.011, 4, hint=(0, 1, 0)), IRON))
    for i in range(3, 12, 2):                                       # short uprights between the bows
        p = Vector(arch[i])
        parts.append(P._finish_obj(L.tube(p, Vector(inner[i - 2]), 0.009, 4), IRON))
    crown = Vector(arch[7])
    parts.append(L.part("cube", IRON, loc=crown + Vector((0, 0, 0.12)), scale=(0.012, 0.012, 0.12)))
    parts.append(L.part("cube", IRON, loc=crown + Vector((0, 0, 0.16)), scale=(0.06, 0.012, 0.012)))
    for o in parts[-(len(parts) - 6):]:
        L.paint(o, IRON, var=0.3, ao=0.15, hue_shift=RUST, seed=9)
    obj = L.join(parts, "ph_prop_fence_passage")
    L.finish(obj, "ph_prop_fence_passage", "props", 35)


def rubble_large():
    """Heap of field stones (~1.5 m, 0.7 m high) cleared from a field long ago: lumpy grey,
    brownish and bluish boulders, mossy on top, on a patch of grit and grass."""
    L.reset(580)
    parts = []
    big = [((0.0, 0.05, 0.3), (0.3, 0.26, 0.2)), ((-0.44, -0.08, 0.17), (0.25, 0.22, 0.16)),
           ((0.42, 0.1, 0.16), (0.24, 0.2, 0.15)), ((0.08, -0.38, 0.14), (0.2, 0.17, 0.13)),
           ((-0.2, 0.4, 0.15), (0.22, 0.18, 0.14)), ((-0.14, -0.06, 0.52), (0.18, 0.16, 0.13)),
           ((0.24, 0.02, 0.48), (0.15, 0.13, 0.11)), ((0.05, 0.12, 0.7), (0.11, 0.1, 0.08))]
    tones = [STONE, STONE_OLD, STONE_BLUE, L.hexc("#7D7466"), STONE, L.hexc("#857C6E"), STONE_BLUE, STONE_OLD]
    for i, (loc, size) in enumerate(big):
        s_ = L.prim("cube", loc=(0, 0, 0), scale=size)
        L.bevel(s_, min(size) * 0.35, 1)
        L.jitter(s_, min(size) * 0.28, 1.0 / min(size), 10 + i)
        L.jitter(s_, min(size) * 0.08, 3.0 / min(size), 110 + i)
        s_.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(random.uniform(0, math.tau), 4, "Z") @
                          Matrix.Rotation(math.radians(random.uniform(-12, 12)), 4, "X"))
        L.paint(s_, L.scale_c(L.mix(tones[i], EARTH, 0.15), random.uniform(0.8, 0.92)), var=0.28, ao=0.55,
                zrange=(0.0, 0.85), hue_shift=MOSS, seed=10 + i)
        P._tint_up(s_, MOSS, 0.85, 0.3, freq=2.5, seed=10 + i)
        L.set_mat(s_, L.MAT_PAINTED)
        parts.append(s_)
    for i in range(10):                                             # small stones around the foot
        a = i / 10 * math.tau + random.uniform(-0.2, 0.2)
        d = random.uniform(0.6, 0.8)
        parts.append(_pebble((math.cos(a) * d, math.sin(a) * d * 0.85, 0.02), random.uniform(0.05, 0.09), 40 + i,
                             color=L.scale_c(random.choice(tones), 0.8)))
    base = P._rings_mesh([(0.92, 0.8, 0.003), (0.72, 0.62, 0.014), (0.4, 0.34, 0.02)], 26, p=2.2, name="grit")
    L.jitter(base, 0.006, 5.0, 70)
    L.paint(base, L.scale_c(L.mix(EARTH, P.GRASS, 0.6), 0.78), var=0.3, ao=0.0, noise_freq=3.5,
            hue_shift=P.GRASS_B, seed=71)
    L.set_mat(base, L.MAT_PAINTED)
    parts.append(base)
    obj = L.join(parts, "ph_prop_rubble_large")
    P._center_xy(obj)
    L.finish(obj, "ph_prop_rubble_large", "props", 45, shift=False)


def notice_board():
    """Cemetery notice board at the gate: two weathered posts, a plank board with a frame,
    a small shingled roof, a couple of pinned notes.  The rating text goes on label_board."""
    L.reset(590)
    parts = []
    bw, bz0, bz1, by = 0.55, 0.95, 1.55, 0.0
    for sx in (-1, 1):
        post = L.prim("cube", loc=(sx * 0.6, 0, 0.95), scale=(0.05, 0.05, 0.95))
        L.subdivide(post, 1)
        L.jitter(post, 0.006, 2.5, 1 + sx)
        L.paint(post, WOOD_OLD, var=0.2, ao=0.5, zrange=(0, 2.0), hue_shift=MOSS, seed=2 + sx)
        L.set_mat(post, L.MAT_PAINTED)
        parts.append(post)
    for i in range(4):                                              # board: four horizontal planks
        z = bz0 + (i + 0.5) * (bz1 - bz0) / 4
        parts.append(P._plank((0, by, z), (bw, 0.018, (bz1 - bz0) / 8 - 0.004), L.hexc("#7E6A50"), seed=10 + i,
                              zrange=(bz0, bz1), ao=0.15, hue_shift=WOOD_OLD))
    for z in (bz0 - 0.02, bz1 + 0.02):                              # frame
        parts.append(P._plank((0, by - 0.012, z), (bw + 0.04, 0.026, 0.025), WOOD_DARK, seed=20, zrange=(0, 2.0)))
    for sx in (-1, 1):
        parts.append(P._plank((sx * (bw + 0.015), by - 0.012, (bz0 + bz1) / 2), (0.025, 0.026, (bz1 - bz0) / 2 + 0.02),
                              WOOD_DARK, seed=21 + sx, zrange=(0, 2.0)))
    rz = 1.93
    for sy in (-1, 1):                                              # little gable roof, overhanging to the front
        roof = L.prim("cube", loc=(0, sy * 0.13, rz - 0.1), scale=(0.74, 0.17, 0.022), rot=(-sy * 34, 0, 0))
        L.subdivide(roof, 1)
        L.jitter(roof, 0.008, 3.0, 30 + sy)
        L.paint(roof, WOOD_DARK, var=0.25, ao=0.2, zrange=(1.7, 2.0), hue_shift=MOSS, seed=31)
        P._tint_up(roof, MOSS, 0.7, 0.3, seed=32)
        P._modulate(roof, lambda co: 1.0 - 0.18 * (0.5 + 0.5 * math.sin(co.x * 38.0)) ** 8)  # shingle rows
        L.set_mat(roof, L.MAT_PAINTED)
        parts.append(roof)
    parts.append(P._stick((-0.75, 0, rz + 0.0), (0.75, 0, rz + 0.0), 0.028, L.scale_c(WOOD_DARK, 0.8), verts=5,
                          seed=33, hue_shift=MOSS))
    for sx in (-1, 1):                                              # braces between posts and roof
        parts.append(P._stick((sx * 0.6, 0.0, 1.62), (sx * 0.6, 0.0, rz - 0.02), 0.03, WOOD_OLD, verts=5, seed=34))
    notes = [((-0.4, bz1 - 0.14), (0.085, 0.11), -6, LINEN), ((0.42, bz0 + 0.15), (0.08, 0.09), 8, LINEN_DIRTY),
             ((0.34, bz1 - 0.1), (0.06, 0.075), -3, LINEN_DIRTY)]
    for (x, z), (hx, hz), rot, c in notes:                          # pinned notes at the edges
        parts.append(L.part("cube", c, loc=(x, by - 0.021, z), scale=(hx, 0.002, hz), rot=(0, rot, 0),
                            paint_kw={"ao": 0.0, "var": 0.1}))
        parts.append(L.part("cube", IRON, loc=(x, by - 0.025, z + hz - 0.02), scale=(0.007, 0.003, 0.007)))
    for i in range(5):                                              # stones wedging the posts
        sx = -1 if i < 3 else 1
        a = i * 2.1
        parts.append(_pebble((sx * 0.6 + math.cos(a) * 0.1, math.sin(a) * 0.09, 0.02), 0.055, 40 + i))
    obj = L.join(parts, "ph_prop_notice_board")
    L.marker(obj, "label_board", (0, by - 0.024, (bz0 + bz1) / 2))
    P._center_xy(obj)
    L.finish(obj, "ph_prop_notice_board", "props", 35)


ASSETS = (bench_wood, bench_stone, flowerbed, grave_vase, lantern_small, path_gravel, path_gravel_02,
          fence_iron_broken, fence_passage, rubble_large, notice_board)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
