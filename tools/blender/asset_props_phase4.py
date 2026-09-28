"""Phase-4 props (docs/PHASE4_DESIGN.md section 8), 'Gemaltes Diorama' style.

  ph_prop_layout_sprig        rosemary and elder sprig with a burnt-down candle stub (no light),
                              laid on the chest of a laid-out body (corpse marker `sprig`)
  ph_prop_wash_basin          pewter basin on a wooden trestle, a wash cloth over the rim
  ph_prop_smoke_bowl          clay bowl with smouldering juniper (marker `smoke` = where P4's
                              juniper smoke rises)
  ph_prop_wall_ledge          flat wall stone on a few rubble stones: Ilse's lantern shelf
  ph_prop_gate_small(_open)   the rusty little gate of the Holunderwinkel, 1.2 m wide, closed /
                              swung open (the leaf turns about its hinge on -X, into +Y = back)
  ph_prop_pit_sunken          one of Lorenz' six pits: sunken, overgrown, rotten boards across,
                              footprint = a 1 x 2 m grave plot (long axis Y)

Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m, shared materials only.
Run:  python tools/blender/build_all.py asset_props_phase4
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_env_phase3 as E
from asset_carter import _thicken

WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
IRON = P.IRON
RUST = P.RUST
STONE = P.STONE
STONE_OLD = P.STONE_OLD
MOSS = P.MOSS
EARTH = P.EARTH
EARTH_DARK = P.EARTH_DARK
GRASS = P.GRASS
LINEN = P.LINEN
PEWTER = L.hexc("#7D7D78")        # dull grey metal, a touch warm - never cold and shiny
PEWTER_DARK = L.hexc("#55554F")
CLAY = L.hexc("#8C5E44")
CLAY_DARK = L.hexc("#5E3E2E")
JUNIPER = L.hexc("#4E5E44")
JUNIPER_BERRY = L.hexc("#4A4658")  # dusky blue-violet berries (muted, low saturation)
ASH = L.hexc("#8A857C")
EMBER = L.hexc("#8C4A2E")          # a painted, dull glow - not emissive
WAX = L.hexc("#E0D2B2")
ROSEMARY = L.hexc("#76866A")          # grey-green, silvery underside
ELDER_FLOWER = L.hexc("#DCD3B4")
ROTTEN = L.hexc("#5A4E40")


def _yaw(obj, deg: float) -> None:
    obj.data.transform(Matrix.Rotation(math.radians(deg), 4, "Z"))


def _needles(parts, p0, p1, color, n: int, length: float, seed: int, spread: float = 0.6) -> None:
    """n flat needle sprays along a twig (rosemary, juniper): squashed, elongated icospheres
    angled alternately to both sides (`spread` = how far they splay)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    seg = (p1 - p0).length / n
    for i in range(n):
        c = p0.lerp(p1, (i + 0.5) / n) + Vector((0, 0, 0.004))
        sp = L.prim("ico", radius=1.0, subdivisions=1, scale=(seg * 0.8, length * 0.28, 0.004))
        L.jitter(sp, 0.0015, 60.0, seed + i)
        sp.data.transform(Matrix.Translation(c) @ Vector((1, 0, 0)).rotation_difference(d).to_matrix().to_4x4()
                          @ Matrix.Rotation(spread * (0.4 if i % 2 else -0.4), 4, "Z"))
        L.paint(sp, L.scale_c(color, 0.9 + 0.2 * (i % 2)), var=0.25, ao=0.1, top=0.4, seed=seed + i)
        L.set_mat(sp, L.MAT_PAINTED)
        parts.append(sp)


# --- the laid-out sprig -------------------------------------------------------------------

def layout_sprig():
    """A rosemary sprig crossed with a small elder twig (three dry cream florets), and a short
    burnt-down candle stub with a black wick. Rests flat on the chest (~0.2 m long)."""
    L.reset(700)
    parts = []
    stem0, stem1 = Vector((-0.1, 0.01, 0.008)), Vector((0.1, -0.012, 0.012))
    parts.append(P._stick(stem0, stem1, 0.0035, L.hexc("#6A5A42"), r1=0.002, verts=4, seed=1, ao=0.0))
    _needles(parts, stem0 + Vector((0.02, 0, 0)), stem1, ROSEMARY, 4, 0.04, 2)
    e0, e1 = Vector((-0.07, -0.05, 0.01)), Vector((0.06, 0.045, 0.014))
    parts.append(P._stick(e0, e1, 0.003, L.hexc("#6E6448"), verts=4, seed=3, ao=0.0))
    for k, (dx, dy) in enumerate(((0.0, 0.0), (0.016, 0.01), (-0.004, 0.018))):
        parts.append(L.part("ico", ELDER_FLOWER, loc=e1 + Vector((dx, dy, 0.008)), radius=0.014, subdivisions=1,
                            scale=(1.0, 1.0, 0.45), paint_kw={"ao": 0.0, "top": 0.3}))
    for k in (-1, 1):  # two elder leaflets
        leaf = L.prim("sphere", radius=1.0, segments=6, ring_count=3, scale=(0.022, 0.009, 0.002))
        leaf.data.transform(Matrix.Translation(e0.lerp(e1, 0.45) + Vector((0, k * 0.012, 0.006)))
                            @ Matrix.Rotation(math.radians(40 + k * 30), 4, "Z"))
        parts.append(P._finish_obj(leaf, L.hexc("#566444"), ao=0.0, top=0.2))
    # the candle stub, never lit here (no light marker)
    cp = Vector((0.0, 0.0, 0.0))
    stub = L.prim("cyl", loc=cp + Vector((-0.06, 0.045, 0.022)), radius=0.017, depth=0.044, vertices=8)
    for v in stub.data.vertices:
        if v.co.z > 0.03:
            v.co.z -= 0.006 * (1.0 + math.sin(v.co.x * 400.0))
    parts.append(P._finish_obj(stub, WAX, ao=0.3, var=0.1))
    parts.append(L.part("cyl", L.hexc("#D6C6A2"), loc=(-0.06, 0.045, 0.003), radius=0.024, depth=0.006, vertices=8,
                        paint_kw={"ao": 0.0}))   # a puddle of dripped wax
    parts.append(P._stick((-0.06, 0.045, 0.04), (-0.058, 0.046, 0.052), 0.0018, L.hexc("#1E1A18"), verts=3, ao=0.0))
    obj = L.join(parts, "ph_prop_layout_sprig")
    P._center_xy(obj)
    L.finish(obj, "ph_prop_layout_sprig", "props", 40)


# --- wash basin -----------------------------------------------------------------------------

def wash_basin():
    """A wooden trestle (four splayed legs, a top ring) holding a dull pewter basin with water,
    a linen cloth hung over its rim; a brush-shaped shadow of use on the rim."""
    L.reset(710)
    parts = []
    top_z = 0.72
    for sx in (-1, 1):
        for sy in (-1, 1):
            foot = Vector((sx * 0.22, sy * 0.19, 0.0))
            head = Vector((sx * 0.15, sy * 0.13, top_z))
            parts.append(P._stick(foot, head, 0.03, L.scale_c(WOOD, random.uniform(0.9, 1.1)), r1=0.026, verts=5,
                                  seed=1 + sx + sy, ao=0.3, zrange=(0, 0.8)))
    for sy in (-1, 1):  # side stretchers
        parts.append(P._stick((-0.19, sy * 0.165, 0.3), (0.19, sy * 0.165, 0.3), 0.014, WOOD_DARK, verts=4, seed=5,
                              ao=0.2))
    parts.append(P._stick((0.0, -0.165, 0.3), (0.0, 0.165, 0.3), 0.013, WOOD_DARK, verts=4, seed=6, ao=0.2))
    frame = L.prim("torus", loc=(0, 0, top_z), major_radius=0.19, minor_radius=0.02, major_segments=14,
                   minor_segments=4, scale=(1.0, 0.88, 1.0))
    parts.append(P._finish_obj(frame, WOOD, var=0.2, ao=0.1, top=0.3, seed=7))
    # the basin: a shallow lathed bowl with a rolled rim and water inside
    prof = [(0.1, top_z - 0.02), (0.16, top_z + 0.02), (0.2, top_z + 0.08), (0.215, top_z + 0.095),
            (0.2, top_z + 0.098), (0.185, top_z + 0.07)]
    bm = bmesh.new()
    n = 16
    rows = [[bm.verts.new((math.cos(a) * r, math.sin(a) * r * 0.88, z)) for a in (math.tau * k / n for k in range(n))]
            for r, z in prof]
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    c = bm.verts.new((0, 0, top_z - 0.02))
    for k in range(n):
        bm.faces.new((c, rows[0][(k + 1) % n], rows[0][k]))
    bowl = P._link(bm, "basin")
    L.paint(bowl, PEWTER, var=0.25, ao=0.3, top=0.35, hue_shift=PEWTER_DARK, seed=8)
    L.set_mat(bowl, L.MAT_PAINTED)
    parts.append(bowl)
    water = L.prim("cyl", loc=(0, 0, top_z + 0.055), radius=0.188, depth=0.004, vertices=16, scale=(1.0, 0.88, 1.0))
    parts.append(P._finish_obj(water, L.hexc("#5E6660"), var=0.15, ao=0.0, top=0.1, seed=9))
    # the cloth over the front rim, hanging down
    cloth = L.prim("grid", x_subdivisions=4, y_subdivisions=5, size=1.0)
    for v in cloth.data.vertices:
        u, w = v.co.x + 0.5, v.co.y + 0.5            # 0..1 across, 0..1 down
        ang = min(1.0, w * 1.8) * math.pi * 0.55
        r = 0.035
        y = -0.19 - math.sin(ang) * r - max(0.0, w - 0.55) * 0.02
        z = top_z + 0.1 + math.cos(ang) * r - r - max(0.0, w - 0.55) * 0.32
        v.co = Vector(((u - 0.5) * 0.16 + 0.05 + 0.01 * math.sin(w * 9.0), y + 0.006 * math.sin(u * 12.0), z))
    _thicken(cloth, 0.006)
    parts.append(P._finish_obj(cloth, LINEN, var=0.12, ao=0.2, top=0.2, hue_shift=P.LINEN_DIRTY, seed=10))
    obj = L.join(parts, "ph_prop_wash_basin")
    P._center_xy(obj)
    L.finish(obj, "ph_prop_wash_basin", "props", 40)


# --- smoke bowl -----------------------------------------------------------------------------

def smoke_bowl():
    """A small clay bowl on three stubby feet with a heap of juniper twigs smouldering on ash.
    Marker `smoke` sits just above the embers."""
    L.reset(720)
    parts = []
    prof = [(0.045, 0.02), (0.08, 0.03), (0.098, 0.06), (0.104, 0.075), (0.094, 0.078), (0.085, 0.06)]
    bm = bmesh.new()
    n = 10
    rows = [[bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for a in (math.tau * k / n for k in range(n))]
            for r, z in prof]
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    c = bm.verts.new((0, 0, 0.02))
    for k in range(n):
        bm.faces.new((c, rows[0][(k + 1) % n], rows[0][k]))
    bowl = P._link(bm, "bowl")
    L.jitter(bowl, 0.003, 20.0, 1)
    L.paint(bowl, CLAY, var=0.2, ao=0.35, top=0.2, hue_shift=CLAY_DARK, seed=2)
    L.set_mat(bowl, L.MAT_PAINTED)
    parts.append(bowl)
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        parts.append(L.part("cone", CLAY_DARK, loc=(math.cos(a) * 0.05, math.sin(a) * 0.05, 0.012), radius1=0.014,
                            radius2=0.01, depth=0.024, vertices=5, paint_kw={"ao": 0.2}))
    # ash bed with a dull ember glow painted in (P4's smoke brings the life)
    ash = L.prim("cyl", loc=(0, 0, 0.064), radius=0.086, depth=0.006, vertices=8, end_fill_type="TRIFAN")
    P._paint_fn(ash, lambda co, vi: L.mix(L.scale_c(ASH, 0.62), EMBER, max(0.0, 1.0 - Vector((co.x, co.y)).length / 0.1)))
    L.set_mat(ash, L.MAT_PAINTED)
    parts.append(ash)
    for k in range(3):  # juniper twigs lying crossed over the ash
        a = k * 1.1 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0.0))
        p0, p1 = Vector((0, 0, 0.072)) - d * 0.08, Vector((0, 0, 0.078)) + d * 0.075
        parts.append(P._stick(p0, p1, 0.0035, L.hexc("#5A4A38"), verts=3, seed=4 + k, ao=0.0))
        _needles(parts, p0, p1, JUNIPER, 1, 0.045, 7 + k, spread=0.9)
    for k in range(1):
        a = k * 2.6 + 0.5
        parts.append(L.part("ico", JUNIPER_BERRY, loc=(math.cos(a) * 0.04, math.sin(a) * 0.04, 0.08), radius=0.007,
                            subdivisions=1, paint_kw={"ao": 0.0, "top": 0.4}))
    obj = L.join(parts, "ph_prop_smoke_bowl")
    L.marker(obj, "smoke", (0.0, 0.0, 0.095))
    P._center_xy(obj)
    L.finish(obj, "ph_prop_smoke_bowl", "props", 40)


# --- wall ledge -----------------------------------------------------------------------------

def wall_ledge():
    """A flat, mossy capstone resting on two rounded rubble stones: a shelf about knee high on
    which Ilse sets down her lantern (top at ~0.5 m, ~0.55 x 0.35 m)."""
    L.reset(730)
    parts = []
    for k, (x, sz) in enumerate(((-0.14, (0.15, 0.15, 0.21)), (0.15, (0.14, 0.16, 0.2)))):
        s = L.prim("ico", loc=(x, 0.0, sz[2]), radius=1.0, subdivisions=2, scale=sz)
        L.jitter(s, 0.02, 6.0, 1 + k)
        parts.append(P._finish_obj(s, L.scale_c(STONE_OLD, 0.85 + 0.1 * k), var=0.3, ao=0.55, hue_shift=MOSS,
                                   seed=2 + k, zrange=(0, 0.45)))
    cap = L.prim("cube", loc=(0.0, 0.0, 0.45), scale=(0.28, 0.18, 0.045))
    L.subdivide(cap, 1)
    L.jitter(cap, 0.012, 4.0, 4)
    parts.append(P._finish_obj(cap, L.mix(STONE, STONE_OLD, 0.5), var=0.28, ao=0.25, top=0.15, seed=5,
                               zrange=(0.38, 0.5), hue_shift=L.hexc("#6E6A60")))
    P._tint_up(parts[-1], MOSS, 0.55, 0.5, freq=5.0, seed=6)
    parts.append(L.part("ico", STONE_OLD, loc=(0.2, -0.16, 0.05), radius=0.06, subdivisions=1, jit=0.015, seed=7,
                        paint_kw={"ao": 0.4, "hue_shift": MOSS}))
    obj = L.join(parts, "ph_prop_wall_ledge")
    P._center_xy(obj)
    L.finish(obj, "ph_prop_wall_ledge", "props", 35)


# --- the small gate ------------------------------------------------------------------------

GATE_W = 1.2          # total width, posts included (same for both states)
POST_X = 0.55         # post centres (outer faces of the finials at +-0.6)
HINGE = Vector((-POST_X + 0.03, 0.0, 0.0))


def _gate_leaf(open_deg: float):
    """The gate leaf between the posts: frame, bars with spikes, an arched top rail, a lock
    plate with keyhole (the elder key), hinge rings. Rotated open about the -X hinge."""
    parts = []
    x0, x1 = -POST_X + 0.04, POST_X - 0.04
    w = x1 - x0
    for z in (0.14, 0.86):
        parts.append(L.part("cube", IRON, loc=((x0 + x1) / 2, 0, z), scale=(w / 2, 0.013, 0.02)))
    for x in (x0 + 0.01, x1 - 0.01):
        parts.append(L.part("cube", IRON, loc=(x, 0, 0.55), scale=(0.018, 0.018, 0.45)))
    n = 7
    for i in range(n):
        x = x0 + w * (i + 1) / (n + 1)
        h = 0.92 + 0.12 * math.sin(math.pi * (i + 1) / (n + 1))       # arched top
        parts.append(L.part("cube", IRON, loc=(x, 0, 0.1 + h / 2), scale=(0.01, 0.01, h / 2)))
        parts.append(L.part("cone", IRON, loc=(x, 0, 0.1 + h + 0.04), radius1=0.024, depth=0.08, vertices=4,
                            rot=(0, 0, 45)))
    arc = [(x0 + w * t, 0.0, 0.1 + 0.9 + 0.12 * math.sin(math.pi * t)) for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)]
    parts.append(P._path_tube(arc, 0.012, 4, hint=(0, 1, 0), name="arc"))
    # lock plate + keyhole on the free (+X) side, at hand height
    parts.append(L.part("cube", IRON, loc=(x1 - 0.07, -0.02, 0.6), scale=(0.05, 0.012, 0.07)))
    parts.append(L.part("cube", L.hexc("#141414"), loc=(x1 - 0.07, -0.034, 0.595), scale=(0.006, 0.003, 0.018)))
    parts.append(L.part("cyl", L.hexc("#141414"), loc=(x1 - 0.07, -0.034, 0.617), rot=(90, 0, 0), radius=0.009,
                        depth=0.004, vertices=6))
    # a small iron scroll between the rails (hand-forged, a leaf shape)
    sc = [(-0.12, 0.0, 0.3), (-0.06, 0.0, 0.26), (0.0, 0.0, 0.3), (0.06, 0.0, 0.26), (0.12, 0.0, 0.3)]
    parts.append(P._path_tube(sc, 0.008, 4, hint=(0, 1, 0), name="scroll"))
    for z in (0.22, 0.8):  # hinge rings round the post
        parts.append(L.part("torus", IRON, loc=(-POST_X, 0, z), major_radius=0.03, minor_radius=0.008,
                            major_segments=8, minor_segments=4))
    for o in parts:
        L.paint(o, IRON, var=0.3, ao=0.2, top=0.2, hue_shift=RUST, seed=3)
        L.set_mat(o, L.MAT_PAINTED)
        P._tint_up(o, L.hexc("#7A4E34"), 0.5, 0.2, freq=9.0, seed=4)   # rust bloom on the top faces
    leaf = L.join(parts, "leaf")
    m = Matrix.Translation(HINGE) @ Matrix.Rotation(math.radians(open_deg), 4, "Z") @ Matrix.Translation(-HINGE)
    leaf.data.transform(m)
    return leaf


def _gate(name: str, open_deg: float) -> None:
    L.reset(740)
    parts = [_gate_leaf(open_deg)]
    for sx in (-1, 1):  # square iron posts with ball finials, rust at the foot
        x = sx * POST_X
        post = L.prim("cube", loc=(x, 0, 0.66), scale=(0.035, 0.035, 0.66))
        L.subdivide(post, 1)
        L.jitter(post, 0.003, 4.0, 5 + sx)
        parts.append(P._finish_obj(post, IRON, var=0.3, ao=0.4, hue_shift=RUST, seed=6, zrange=(0, 1.35)))
        parts.append(L.part("cube", IRON, loc=(x, 0, 1.34), scale=(0.045, 0.045, 0.015)))
        parts.append(L.part("sphere", IRON, loc=(x, 0, 1.39), radius=0.042, segments=8, ring_count=5,
                            paint_kw={"hue_shift": RUST, "top": 0.3}))
    # a tuft of grass at each post foot
    parts.append(E._blades([((-POST_X + 0.02, 0.03), 7, (0.12, 0.22), 0.012, 0.02),
                            ((POST_X - 0.02, -0.03), 6, (0.1, 0.2), 0.012, 0.02)], E.GRASS_TINT, 8))
    obj = L.join(parts, name)
    L.finish(obj, name, "props", 30)


def gate_small():
    """Closed: the leaf in the fence line between its posts (1.2 m along X)."""
    _gate("ph_prop_gate_small", 0.0)


def gate_small_open():
    """Open: the leaf swung 100 degrees about its hinge post (-X) into +Y (the Holunderwinkel
    side, away from the model front); same posts, same 1.2 m width."""
    _gate("ph_prop_gate_small_open", 100.0)


# --- sunken pit ----------------------------------------------------------------------------

def pit_sunken():
    """An old grave pit dug long ago and never used: the ground has sunk into a soft, mossy
    hollow (faked by paint and a low rim, like the open pit), grass creeping over the edge,
    three rotten boards lying across it, one broken into the hollow. 1 x 2 m (long axis Y)."""
    L.reset(750)
    rings = [(0.55, 1.05, 0.0), (0.5, 1.0, 0.035), (0.45, 0.94, 0.03), (0.38, 0.84, 0.012), (0.24, 0.6, 0.006),
             (0.1, 0.32, 0.005)]
    off = Vector((3.0, 1.0, 0.0))

    def lumpy(k, x, y):
        return 1.0 + 0.05 * noise.noise(Vector((x * 2.2, y * 2.2, k)) + off), 0.012 * noise.noise(Vector((x, y, 2)) * 4.0)
    ground = P._rings_mesh(rings, 28, lumpy, p=4.0, name="hollow")
    ring = P._ring_of(ground, 28)

    def col(co, vi):
        k = ring[vi]
        if k <= 1:
            c = L.mix(GRASS, P.GRASS_B, 0.5 + 0.5 * noise.noise(co * 2.0))
        else:
            v = max(-1.0, min(1.0, co.y / 1.0))
            wall = max(0.0, (v + 0.2) / 1.2) ** 1.5              # far side catches the light
            base = L.mix(L.mix(EARTH_DARK, P.EARTH_FRESH, 0.4), L.mix(EARTH, MOSS, 0.4), wall)
            c = L.mix(base, MOSS, 0.45 * max(0.0, noise.noise(co * 3.0 + off)) + 0.15)
        return L.scale_c(c, 1.0 + noise.noise(co * 6.0) * 0.1)
    P._paint_fn(ground, col)
    L.set_mat(ground, L.MAT_PAINTED)
    parts = [ground]
    # rotten boards: two across, one broken and sagging into the hollow
    for k, (y, yaw, sag, broken) in enumerate(((-0.55, 4.0, 0.0, False), (0.15, -7.0, 0.012, True),
                                              (0.62, 2.0, 0.0, False))):
        if broken:
            for s in (-1, 1):
                b = L.prim("cube", loc=(s * 0.24, 0, 0.0), scale=(0.25, 0.08, 0.012))
                L.jitter(b, 0.006, 6.0, 20 + s)
                b.data.transform(Matrix.Translation((0.0, y, 0.03)) @ Matrix.Rotation(math.radians(s * 9.0), 4, "Y"))
                _yaw(b, yaw)
                parts.append(P._finish_obj(b, ROTTEN, var=0.3, ao=0.3, top=0.2, hue_shift=MOSS, seed=21 + s))
        else:
            b = L.prim("cube", loc=(0, y, 0.045), scale=(0.52, 0.085, 0.013))
            L.subdivide(b, 1)
            L.jitter(b, 0.007, 5.0, 23 + k)
            for v in b.data.vertices:
                v.co.z -= sag * (1.0 - (v.co.x / 0.52) ** 2)
            _yaw(b, yaw)
            parts.append(P._finish_obj(b, L.scale_c(ROTTEN, 1.0 + 0.08 * k), var=0.3, ao=0.25, top=0.25,
                                       hue_shift=MOSS, seed=24 + k))
        P._tint_up(parts[-1], MOSS, 0.6, 0.4, freq=7.0, seed=30 + k)
    # grass and a few weeds creeping in over the rim
    tufts = []
    rnd = random.Random(751)
    for i in range(12):
        a = i / 12 * math.tau + rnd.uniform(-0.2, 0.2)
        tufts.append(((math.cos(a) * 0.52, math.sin(a) * 1.0), 4, (0.08, 0.2), 0.012, 0.07))
    parts.append(E._blades(tufts, E.GRASS_TINT, 40))
    parts.append(E._rosette(0.2, -0.3, 5, 0.12, 0.03, E.WEED_DARK, 41, lift=0.012))
    obj = L.join(parts, "ph_prop_pit_sunken")
    L.finish(obj, "ph_prop_pit_sunken", "props", 45, shift=False)


ASSETS = (layout_sprig, wash_basin, smoke_bowl, wall_ledge, gate_small, gate_small_open, pit_sunken)


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
