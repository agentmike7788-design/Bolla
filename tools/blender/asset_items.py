"""Item models for UI icons (contract section 8): log, stone, linen bolt, coins, shroud;
Phase 3 (docs/PHASE3_DESIGN.md section 8): rake, flower seeds, iron fittings;
Phase 4 (docs/PHASE4_DESIGN.md section 8): root scrub brush, wooden comb, burial gown, juniper,
shears, pliers, hair braid, teeth pouch (a tied linen pouch - nothing visible), elder key.

Small (~0.3 m), centred on the origin, bottom at z = 0, front = -Y.  Rendered to
assets/ui/icons/<id>.png by src/ui/tools/icon_renderer.gd (W2).  Same painted
vertex-colour style and shared materials as every other asset.

Run:  python -c "import sys; sys.path.insert(0, 'tools/blender'); import asset_items as a; a.build()"
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector

import lib_painted as L
import asset_props_slice as P
import asset_props_phase3 as D

GOLD = L.hexc("#A08240")          # warm, dull gold - not emissive
GOLD_DARK = L.hexc("#7C6533")
SHROUD_CLOTH = L.hexc("#DDD5C1")


def _disc(loc, r: float, color, axis: str = "y", depth: float = 0.004, verts: int = 12, seed: int = 0):
    """Thin disc (end grain rings, cloth layers, coin faces)."""
    rot = {"x": (0, 90, 0), "y": (90, 0, 0), "z": (0, 0, 0)}[axis]
    return L.part("cyl", color, loc=loc, rot=rot, radius=r, depth=depth, vertices=verts, seed=seed,
                  paint_kw={"ao": 0.0, "var": 0.12})


def _yaw(obj, deg: float) -> None:
    obj.data.transform(Matrix.Rotation(math.radians(deg), 4, "Z"))


def item_log():
    """One round log with bark, end grain rings and a branch stub."""
    L.reset(400)
    r, half = 0.075, 0.16
    bark = L.prim("cyl", loc=(0, 0, r), rot=(90, 0, 0), radius=r, depth=half * 2, vertices=10)
    L.subdivide(bark, 1)
    L.jitter(bark, 0.006, 8.0, 1)
    L.paint(bark, P.BARK, var=0.25, ao=0.35, zrange=(0, 2 * r), hue_shift=P.BARK_DARK, seed=2)
    P._tint_up(bark, P.MOSS, 0.5, 0.4, freq=6.0, seed=3)
    L.set_mat(bark, L.MAT_PAINTED)
    parts = [bark]
    for sy in (-1, 1):  # end grain: light wood, a darker growth ring, dark pith
        y = sy * (half + 0.002)
        parts.append(_disc((0, y, r), r * 0.9, P.END_GRAIN, seed=4))
        parts.append(_disc((0, y + sy * 0.002, r), r * 0.58, L.scale_c(P.END_GRAIN, 0.82), seed=5))
        parts.append(_disc((0, y + sy * 0.003, r), r * 0.4, P.END_GRAIN, seed=6))
        parts.append(_disc((0, y + sy * 0.004, r), r * 0.1, P.WOOD_DARK, verts=6, seed=7))
    parts.append(P._stick((0.0, 0.04, r + 0.05), (0.03, 0.09, r + 0.13), 0.022, P.BARK, r1=0.016, verts=6, seed=8))
    parts.append(_disc((0.03, 0.09, r + 0.13), 0.016, P.END_GRAIN, axis="z", verts=6, seed=9))
    obj = L.join(parts, "ph_item_log")
    _yaw(obj, -32)  # end grain and bark both face the icon camera
    L.finish(obj, "ph_item_log", "items", 40)


def item_stone():
    """A rough chunk of grey-blue stone with a smaller chip."""
    L.reset(410)
    big = P._stone((0, 0, 0.085), (0.13, 0.1, 0.085), (0, 0, 20), 11, L.hexc("#8A8F94"), cuts=3)
    chip = P._stone((0.15, -0.08, 0.035), (0.05, 0.04, 0.035), (10, 5, 50), 12, L.hexc("#7E8187"))
    obj = L.join([big, chip], "ph_item_stone")
    P._center_xy(obj)
    L.finish(obj, "ph_item_stone", "items", 30)


def item_linen():
    """Rolled bolt of linen with a spiral end, a loose flap and a twine tie."""
    L.reset(420)
    r, half = 0.068, 0.15
    roll = L.prim("cyl", loc=(0, 0, r), rot=(0, 90, 0), radius=r, depth=half * 2, vertices=14)
    L.subdivide(roll, 1)
    L.jitter(roll, 0.003, 10.0, 1)
    L.paint(roll, P.LINEN, var=0.1, ao=0.35, zrange=(0, 2 * r), hue_shift=P.LINEN_DIRTY, seed=2)
    P._modulate(roll, lambda co: 1.0 - 0.1 * max(0.0, math.sin(co.x * 90.0)) ** 6)  # woven bands
    L.set_mat(roll, L.MAT_PAINTED)
    parts = [roll]
    for sx in (-1, 1):  # rolled-up layers at both ends
        for k, (rr, f) in enumerate(((0.92, 1.0), (0.74, 0.8), (0.56, 1.0), (0.38, 0.8), (0.2, 1.0))):
            parts.append(_disc((sx * (half + 0.001 + k * 0.0012), 0, r), r * rr, L.scale_c(P.LINEN, f * 0.97),
                               axis="x", verts=14, seed=3 + k))
        parts.append(_disc((sx * (half + 0.008), 0, r), r * 0.08, P.WOOD_DARK, axis="x", verts=6, seed=9))
    # loose outer layer lying on the ground in front
    flap = L.prim("cube", loc=(0.02, -0.1, 0.004), scale=(0.13, 0.055, 0.003))
    L.subdivide(flap, 2)
    for v in flap.data.vertices:  # curls up into the roll
        t = max(0.0, (v.co.y + 0.05) / 0.01)
        v.co.z += 0.012 * min(1.0, t) + 0.01 * math.sin(v.co.x * 30.0) * 0.2
    L.jitter(flap, 0.003, 12.0, 10)
    parts.append(P._finish_obj(flap, P.LINEN, var=0.1, ao=0.1, hue_shift=P.LINEN_DIRTY, seed=11))
    ring = [(0.03, math.cos(a) * (r + 0.004), r + math.sin(a) * (r + 0.004))
            for a in (j / 14 * math.tau for j in range(14))]
    parts.append(P._finish_obj(P._path_tube(ring, 0.006, 4, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0, seed=12))
    obj = L.join(parts, "ph_item_linen")
    _yaw(obj, 22)
    P._center_xy(obj)
    L.finish(obj, "ph_item_linen", "items", 40)


def _coin(loc, tilt=(0.0, 0.0), seed: int = 0):
    """One coin: dull gold disc, raised darker centre (embossed face)."""
    r, d = 0.055, 0.012
    parts = [L.part("cyl", L.scale_c(GOLD, random.uniform(0.92, 1.08)), loc=(0, 0, d / 2), radius=r, depth=d,
                    vertices=14, seed=seed, paint_kw={"ao": 0.25, "var": 0.18, "hue_shift": GOLD_DARK})]
    parts.append(L.part("cyl", GOLD_DARK, loc=(0, 0, d + 0.0008), radius=r * 0.66, depth=0.0016, vertices=12,
                        paint_kw={"ao": 0.0, "var": 0.2}))
    for o in parts:
        o.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(math.radians(tilt[0]), 4, "X") @
                         Matrix.Rotation(math.radians(tilt[1]), 4, "Y"))
    return parts


def item_coin():
    """A small stack of worn coins with two loose ones (warm dull gold, not emissive)."""
    L.reset(430)
    parts = []
    for i in range(6):
        a = random.uniform(0, math.tau)
        parts += _coin((math.cos(a) * 0.004 * i, math.sin(a) * 0.004 * i, i * 0.0125), seed=i)
    parts += _coin((0.12, -0.04, 0.0), seed=10)
    parts += _coin((-0.088, -0.03, 0.044), tilt=(0.0, -58.0), seed=11)  # leaning against the stack
    obj = L.join(parts, "ph_item_coin")
    P._center_xy(obj)
    L.finish(obj, "ph_item_coin", "items", 30)


def item_shroud():
    """Folded pale burial cloth: three layers, a rolled fold edge, tied with twine."""
    L.reset(440)
    parts = []
    for i in range(3):
        z = 0.012 + i * 0.022
        parts.append(P._rbox((random.uniform(-0.006, 0.006), random.uniform(-0.006, 0.006), z),
                             (0.15, 0.11, 0.011), L.scale_c(SHROUD_CLOTH, 0.94 + i * 0.03), bev=0.009, seg=2,
                             jit=0.004, seed=i, ao=0.3, zrange=(0, 0.075), hue_shift=P.LINEN_DIRTY))
    parts.append(L.part("cyl", SHROUD_CLOTH, loc=(0, -0.11, 0.034), rot=(0, 90, 0), radius=0.034, depth=0.3,
                        vertices=10, jit=0.003, seed=5, paint_kw={"ao": 0.3, "zrange": (0, 0.075)}))  # fold edge
    for x in (-0.07, 0.07):  # twine around the bundle
        loop = [(x, -0.018 + y, max(0.003, 0.036 + z)) for (y, z) in P._superellipse(0.138, 0.038, 18, 4.0)]
        parts.append(P._finish_obj(P._path_tube(loop, 0.005, 4, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0,
                                   seed=6))
    obj = L.join(parts, "ph_item_shroud")
    _yaw(obj, 12)
    P._center_xy(obj)
    L.finish(obj, "ph_item_shroud", "items", 40)


def item_rake():
    """Wooden garden rake lying on its back (icon scale): handle, a crossbar with seven pegged
    tines pointing up, two braces.  Weathered wood, the tines a little lighter."""
    L.reset(450)
    parts = []
    r = 0.011
    parts.append(P._stick((-0.2, 0.0, r), (0.13, 0.0, r), r, L.mix(P.WOOD, P.WOOD_OLD, 0.4), r1=r * 0.95, verts=6, seed=1, ao=0.2,
                          zrange=(0, 0.08)))
    parts.append(L.part("sphere", P.WOOD_DARK, loc=(-0.2, 0.0, r), radius=r * 1.1, segments=6, ring_count=4))
    parts.append(P._rbox((0.15, 0.0, 0.016), (0.016, 0.115, 0.014), P.WOOD_OLD, bev=0.005, seg=1, jit=0.002, seed=2,
                         ao=0.2, zrange=(0, 0.08)))
    for i in range(7):
        y = -0.1 + i * 0.2 / 6
        parts.append(P._stick((0.15, y, 0.026), (0.162, y, 0.07), 0.0055, P.WOOD_FRESH, r1=0.004, verts=5, seed=3 + i,
                              ao=0.1, zrange=(0, 0.08)))
    for sy in (-1, 1):
        parts.append(P._stick((0.07, 0.0, r), (0.145, sy * 0.07, 0.018), 0.006, P.WOOD, verts=5, seed=12, ao=0.1))
    for o in parts[:1]:
        P._tint_up(o, L.hexc("#8C7650"), 0.3, 0.5, seed=4)       # worn grip
    obj = L.join(parts, "ph_item_rake")
    _yaw(obj, -28)
    P._center_xy(obj)
    L.finish(obj, "ph_item_rake", "items", 40)


def item_seeds():
    """Small linen seed pouch tied with twine, a dried amber flower tucked under the tie,
    seeds spilling out in front."""
    L.reset(460)
    prof = [(0.05, 0.0), (0.075, 0.012), (0.085, 0.04), (0.082, 0.075), (0.065, 0.105), (0.035, 0.125),
            (0.03, 0.135), (0.042, 0.148), (0.04, 0.162), (0.022, 0.17)]
    bag = D._lathe(prof, 12, "bag", cap_top=True, wobble=0.08, seed=3)
    L.jitter(bag, 0.006, 25.0, 4)
    L.paint(bag, P.LINEN_DIRTY, var=0.15, ao=0.4, zrange=(0, 0.17), hue_shift=P.EARTH, seed=5)
    P._modulate(bag, lambda co: 1.0 - 0.08 * max(0.0, math.sin(co.z * 160.0)) ** 4)   # coarse weave
    L.set_mat(bag, L.MAT_PAINTED)
    parts = [bag]
    tie = [(math.cos(a) * 0.036, math.sin(a) * 0.036, 0.13) for a in (j / 12 * math.tau for j in range(12))]
    parts.append(P._finish_obj(P._path_tube(tie, 0.006, 4, closed=True), P.ROPE, ao=0.0, seed=6))
    parts.append(P._stick((0.03, -0.02, 0.13), (0.07, -0.05, 0.08), 0.004, P.ROPE, verts=4, seed=7, ao=0.0))
    parts.append(P._stick((0.0, -0.034, 0.125), (-0.035, -0.06, 0.215), 0.003, L.hexc("#7A7A48"), verts=3, seed=8,
                          ao=0.0))
    parts.append(D._flower_head(Vector((-0.035, -0.062, 0.218)), 0.03, D.FLOWER_AMBER, D.FLOWER_EYE["amber"], 9,
                                tilt=(45.0, -10.0)))
    for i in range(9):                                                # spilled seeds
        a = random.uniform(-1.2, 1.2) - math.pi / 2
        d = random.uniform(0.09, 0.15)
        sd = L.prim("ico", loc=(math.cos(a) * d, math.sin(a) * d, 0.004), radius=0.008, subdivisions=1,
                    scale=(1.6, 1.0, 0.6), rot=(0, 0, random.uniform(0, 180)))
        parts.append(P._finish_obj(sd, L.scale_c(L.hexc("#5A4432"), random.uniform(0.85, 1.2)), var=0.1, ao=0.0,
                                   top=0.3, seed=10 + i))
    obj = L.join(parts, "ph_item_seeds")
    P._center_xy(obj)
    L.finish(obj, "ph_item_seeds", "items", 45)


def item_iron_fittings():
    """A few blacksmith-made fittings: two bent corner irons and a flat strap with nail holes,
    three square nails.  Dark iron with rust, not shiny."""
    L.reset(470)
    parts = []

    def strap(p0, p1, w: float, t: float, seed: int):
        d = Vector(p1) - Vector(p0)
        o = L.prim("cube", loc=(0, 0, 0), scale=(d.length / 2, w / 2, t / 2))
        L.bevel(o, t * 0.4, 1)
        L.jitter(o, 0.0015, 40.0, seed)
        rot = Vector((1, 0, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        o.data.transform(Matrix.Translation((Vector(p0) + Vector(p1)) / 2) @ rot)
        return P._finish_obj(o, P.IRON, var=0.3, ao=0.15, top=0.2, hue_shift=P.RUST, seed=seed)
    parts.append(strap((-0.15, -0.06, 0.007), (0.13, -0.045, 0.007), 0.05, 0.012, 1))      # flat strap
    for x in (-0.11, -0.01, 0.09):                                                          # nail holes
        parts.append(L.part("cyl", L.hexc("#1E1E20"), loc=(x, -0.06 + (x + 0.15) * 0.054, 0.0135), radius=0.009,
                            depth=0.002, vertices=6, paint_kw={"ao": 0.0}))
    for k, (x, y, yaw) in enumerate(((-0.03, 0.045, 15.0), (0.1, 0.03, -40.0))):             # corner irons
        a = math.radians(yaw)
        dx, dy = math.cos(a), math.sin(a)
        corner = Vector((x, y, 0.008))
        parts.append(strap(corner - Vector((dx, dy, 0)) * 0.12, corner, 0.04, 0.012, 2 + k))
        parts.append(strap(corner + Vector((0, 0, -0.004)), corner + Vector((0, 0, 0.085)), 0.04, 0.012, 4 + k))
    for i, (x, y, yaw) in enumerate(((0.0, -0.13, 10.0), (0.06, -0.14, 70.0), (0.13, -0.11, 35.0))):  # nails
        a = math.radians(yaw)
        d = Vector((math.cos(a), math.sin(a), 0))
        base = Vector((x, y, 0.006))
        parts.append(P._stick(base - d * 0.035, base + d * 0.035, 0.004, P.IRON, r1=0.0015, verts=4, seed=7 + i,
                              ao=0.0, hue_shift=P.RUST))
        parts.append(L.part("cube", P.IRON, loc=base - d * 0.037, scale=(0.007, 0.007, 0.004), rot=(0, 0, yaw),
                            paint_kw={"ao": 0.0}))
    obj = L.join(parts, "ph_item_iron_fittings")
    P._center_xy(obj)
    L.finish(obj, "ph_item_iron_fittings", "items", 30)


# --- Phase 4 ------------------------------------------------------------------------------

GOWN = L.hexc("#D9CCAE")           # the burial gown: lighter and warmer than the shroud linen
GOWN_SHADE = L.hexc("#BBA987")
BRISTLE = L.hexc("#A98C5C")        # root fibre
IRON_EDGE = L.hexc("#6E7074")      # a worn, lighter edge (dull, not shiny)
JUNIPER = L.hexc("#44543F")
JUNIPER_BERRY = L.hexc("#4A4658")
BRAID = L.hexc("#6E5438")
RIBBON = L.hexc("#7A4A3E")         # muted madder red
POUCH = L.hexc("#A89C82")


def _needle_twig(parts, p0, p1, n: int, length: float, color, seed: int) -> None:
    """A twig with n flat needle sprays along it (juniper): squashed, elongated icospheres."""
    p0, p1 = Vector(p0), Vector(p1)
    parts.append(P._stick(p0, p1, 0.004, L.hexc("#5A4A38"), r1=0.0025, verts=4, seed=seed, ao=0.0))
    d = (p1 - p0).normalized()
    seg = (p1 - p0).length / n
    for i in range(n):
        c = p0.lerp(p1, (i + 0.5) / n) + Vector((0, 0, 0.004))
        sp = L.prim("ico", radius=1.0, subdivisions=1, scale=(seg * 0.62, length * 0.3, 0.004))
        L.jitter(sp, 0.002, 60.0, seed + i)
        sp.data.transform(Matrix.Translation(c) @ Vector((1, 0, 0)).rotation_difference(d).to_matrix().to_4x4()
                          @ Matrix.Rotation(math.radians(18 if i % 2 else -18), 4, "Z"))
        parts.append(P._finish_obj(sp, L.scale_c(color, 0.9 + 0.2 * (i % 2)), var=0.25, ao=0.1, top=0.4, seed=seed + i))


def _strip(p0, p1, w0: float, w1: float, t: float, color, seed: int, bend: float = 0.0):
    """Flat tapering iron strip (blade, handle, ribbon) between two points, lying flat."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    side = Vector((-d.y, d.x, 0)).normalized()
    bm = bmesh.new()
    rows = []
    for i in range(5):
        u = i / 4
        c = p0 + d * u + side * bend * math.sin(u * math.pi)
        w = w0 + (w1 - w0) * u
        rows.append([bm.verts.new(c + side * w * sx + Vector((0, 0, t * sz)))
                     for sx, sz in ((-1, 1), (1, 1), (1, -1), (-1, -1))])
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(4):
            bm.faces.new((r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]))
    bm.faces.new(rows[0])
    bm.faces.new(list(reversed(rows[-1])))
    return P._finish_obj(P._link(bm, "strip"), color, var=0.25, ao=0.1, top=0.35, hue_shift=P.RUST, seed=seed)


def item_scrub_brush():
    """Root scrub brush: an oval, hand-carved wooden back with a thumb groove, a thick pad of
    stiff root fibres underneath, a leather loop at one end."""
    L.reset(480)
    parts = []
    back = L.prim("cyl", loc=(0, 0, 0.052), radius=1.0, depth=0.03, vertices=12, scale=(0.12, 0.055, 1.0))
    L.jitter(back, 0.003, 20.0, 1)
    for v in back.data.vertices:  # domed top
        if v.co.z > 0.06:
            v.co.z += 0.012 * (1.0 - (v.co.x / 0.12) ** 2)
    parts.append(P._finish_obj(back, P.WOOD, var=0.2, ao=0.2, top=0.3, hue_shift=P.WOOD_DARK, seed=2))
    pad = L.prim("cyl", loc=(0, 0, 0.022), radius=1.0, depth=0.036, vertices=12, scale=(0.11, 0.048, 1.0))
    L.jitter(pad, 0.004, 40.0, 3)
    for v in pad.data.vertices:  # frayed, splayed fibre ends
        if v.co.z < 0.01:
            v.co.x *= 1.08
            v.co.y *= 1.15
    P._paint_fn(pad, lambda co, vi: L.scale_c(BRISTLE, 0.75 + 0.35 * max(0.0, math.sin(co.x * 260.0 + co.y * 90.0))))
    L.set_mat(pad, L.MAT_PAINTED)
    parts.append(pad)
    parts.append(L.part("cube", P.WOOD_DARK, loc=(0.0, 0.0, 0.08), scale=(0.05, 0.012, 0.003), paint_kw={"ao": 0.0}))
    loop = [(0.12 + math.cos(a) * 0.03, 0.0, 0.055 + math.sin(a) * 0.022) for a in (j / 10 * math.tau for j in range(10))]
    parts.append(P._finish_obj(P._path_tube(loop, 0.005, 4, closed=True, hint=(0, 1, 0)), P.LEATHER, ao=0.0, seed=4))
    obj = L.join(parts, "ph_item_scrub_brush")
    _yaw(obj, -24)
    P._center_xy(obj)
    L.finish(obj, "ph_item_scrub_brush", "items", 40)


def item_comb():
    """Wooden comb carved from one piece: a curved spine, coarse and fine teeth, lying flat."""
    L.reset(490)
    parts = []
    spine = L.prim("cube", loc=(0, 0.03, 0.009), scale=(0.1, 0.02, 0.009))
    L.bevel(spine, 0.006, 1)
    for v in spine.data.vertices:
        v.co.y += 0.012 * (v.co.x / 0.1) ** 2   # a gentle curve
    parts.append(P._finish_obj(spine, P.WOOD_FRESH, var=0.18, ao=0.1, top=0.3, hue_shift=P.WOOD, seed=1))
    for i in range(15):
        x = -0.09 + i * 0.18 / 14
        ln = 0.055 if i < 6 else 0.05
        y0 = 0.012 + 0.012 * (x / 0.1) ** 2
        t = L.prim("cube", loc=(x, y0 - ln / 2, 0.006), scale=(0.0038 if i < 6 else 0.003, ln / 2, 0.005))
        parts.append(P._finish_obj(t, P.WOOD_FRESH, var=0.15, ao=0.1, top=0.3, seed=2 + i))
    obj = L.join(parts, "ph_item_comb")
    _yaw(obj, 18)
    P._center_xy(obj)
    L.finish(obj, "ph_item_comb", "items", 30)


def item_burial_gown():
    """The burial gown folded: warm-white linen in three layers (lighter than the shroud), a
    folded sleeve with a gathered cuff on top, the neckline with its drawstring bow."""
    L.reset(500)
    parts = []
    for i in range(3):
        z = 0.012 + i * 0.02
        parts.append(P._rbox((random.uniform(-0.005, 0.005), random.uniform(-0.005, 0.005), z),
                             (0.15, 0.11, 0.01), L.scale_c(GOWN, 0.94 + i * 0.03), bev=0.009, seg=2, jit=0.004,
                             seed=i, ao=0.3, zrange=(0, 0.075), hue_shift=GOWN_SHADE))
    sleeve = L.prim("cyl", loc=(0.02, 0.0, 0.07), rot=(0, 90, 20), radius=0.022, depth=0.2, vertices=8)
    L.jitter(sleeve, 0.003, 20.0, 5)
    parts.append(P._finish_obj(sleeve, GOWN, var=0.12, ao=0.2, top=0.3, hue_shift=GOWN_SHADE, seed=5))
    parts.append(L.part("torus", GOWN_SHADE, loc=(0.114, 0.034, 0.07), rot=(0, 90, 20), major_radius=0.024,
                        minor_radius=0.006, major_segments=8, minor_segments=4))   # gathered cuff
    neck = [(math.cos(a) * 0.05 - 0.06, 0.08 - math.sin(a) * 0.02, 0.066) for a in (j / 8 * math.pi for j in range(9))]
    parts.append(P._finish_obj(P._path_tube(neck, 0.008, 4, hint=(0, 0, 1)), GOWN_SHADE, ao=0.0, seed=6))
    bow = Vector((-0.06, 0.056, 0.074))
    for sy in (-1, 1):
        parts.append(L.part("sphere", P.ROPE, loc=bow + Vector((sy * 0.014, 0, 0)), radius=1.0,
                            scale=(0.014, 0.008, 0.004), segments=6, ring_count=3, paint_kw={"ao": 0.0, "top": 0.3}))
        parts.append(P._stick(bow, bow + Vector((sy * 0.02, -0.04, -0.004)), 0.0025, P.ROPE, verts=3, seed=7, ao=0.0))
    obj = L.join(parts, "ph_item_burial_gown")
    _yaw(obj, 12)
    P._center_xy(obj)
    L.finish(obj, "ph_item_burial_gown", "items", 40)


def item_juniper():
    """A bundle of juniper twigs tied with twine, a few dusky blue-violet berries."""
    L.reset(510)
    parts = []
    for k, (dy, yaw, ln) in enumerate(((0.0, 0.0, 0.3), (0.02, 8.0, 0.26), (-0.02, -9.0, 0.27), (0.01, 16.0, 0.22))):
        a = math.radians(yaw)
        d = Vector((math.cos(a), math.sin(a), 0.08))
        p0 = Vector((-0.13, dy, 0.02 + 0.006 * k))
        _needle_twig(parts, p0, p0 + d * ln, 7, 0.034, L.scale_c(JUNIPER, 0.9 + 0.08 * k), 10 + k)
    ring = [(-0.07, math.cos(a) * 0.022, 0.026 + math.sin(a) * 0.018) for a in (j / 8 * math.tau for j in range(8))]
    parts.append(P._finish_obj(P._path_tube(ring, 0.004, 4, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0, seed=20))
    for k in range(5):
        parts.append(L.part("ico", JUNIPER_BERRY, loc=(0.02 + k * 0.03, (-1) ** k * 0.02, 0.04), radius=0.009,
                            subdivisions=1, paint_kw={"ao": 0.0, "top": 0.4}))
    obj = L.join(parts, "ph_item_juniper")
    _yaw(obj, -20)
    P._center_xy(obj)
    L.finish(obj, "ph_item_juniper", "items", 30)


def item_shears():
    """Old iron scissors with round finger loops, crossed at a rivet, lying flat and a little
    open; the cutting edges worn lighter."""
    L.reset(520)
    parts = []
    piv = Vector((0.03, 0.0, 0.008))
    for k, sgn in enumerate((-1, 1)):
        a = math.radians(sgn * 9.0)
        d = Vector((math.cos(a), math.sin(a), 0))
        z = Vector((0, 0, 0.004 * k))
        parts.append(_strip(piv + z, piv + z + d * 0.13, 0.013, 0.002, 0.003, P.IRON, 1 + k))
        parts.append(_strip(piv + z + d * 0.015, piv + z + d * 0.12, 0.004, 0.001, 0.0035, IRON_EDGE, 3 + k))
        hd = Vector((-math.cos(a), -math.sin(a) * 2.6, 0)).normalized()
        h1 = piv + z + hd * 0.09
        parts.append(_strip(piv + z, h1, 0.006, 0.005, 0.003, P.IRON, 5 + k))
        loop = [(h1.x - 0.022 + math.cos(t) * 0.022, h1.y + math.sin(t) * 0.018, h1.z)
                for t in (j / 10 * math.tau for j in range(10))]
        parts.append(P._finish_obj(P._path_tube(loop, 0.0045, 4, closed=True), P.IRON, var=0.25, ao=0.0,
                                   hue_shift=P.RUST, seed=7 + k))
    parts.append(L.part("cyl", IRON_EDGE, loc=piv + Vector((0, 0, 0.006)), radius=0.007, depth=0.008, vertices=6,
                        paint_kw={"ao": 0.0, "top": 0.4}))
    obj = L.join(parts, "ph_item_shears")
    _yaw(obj, 30)
    P._center_xy(obj)
    L.finish(obj, "ph_item_shears", "items", 30)


def item_pliers():
    """Forged pliers (the tooth-breaker's kind): two long handles bowed apart, short curved
    jaws meeting at a heavy rivet. Dark iron, a little rust."""
    L.reset(530)
    parts = []
    piv = Vector((0.07, 0.0, 0.01))
    for k, sgn in enumerate((-1, 1)):
        z = Vector((0, 0, 0.005 * k))
        parts.append(_strip(piv + z, piv + z + Vector((0.05, sgn * 0.004, 0.0)), 0.012, 0.007, 0.005, P.IRON, 1 + k,
                            bend=sgn * 0.006))
        parts.append(_strip(piv + z, piv + z + Vector((-0.21, sgn * 0.045, 0.0)), 0.008, 0.006, 0.004, P.IRON, 3 + k,
                            bend=sgn * 0.012))
    parts.append(L.part("cyl", IRON_EDGE, loc=piv + Vector((0, 0, 0.008)), radius=0.011, depth=0.012, vertices=8,
                        paint_kw={"ao": 0.0, "top": 0.4, "hue_shift": P.RUST}))
    obj = L.join(parts, "ph_item_pliers")
    _yaw(obj, -26)
    P._center_xy(obj)
    L.finish(obj, "ph_item_pliers", "items", 30)


def item_hair_braid():
    """A cut braid lying in a soft S-curve: three-strand plait as overlapping lobes tilted
    alternately left and right, a muted red ribbon at the top, a thread at the tip and the
    loose end fanning out."""
    L.reset(540)
    parts = []
    n = 16
    pts = [Vector((-0.13 + 0.26 * t, 0.035 * math.sin(t * math.pi * 1.6), 0.016)) for t in (i / n for i in range(n + 1))]
    for i, c in enumerate(pts[:-1]):
        d = (pts[i + 1] - c).normalized()
        side = Vector((-d.y, d.x, 0.0))
        r = 0.02 * (1.0 - 0.4 * i / n)
        sgn = 1 if i % 2 else -1
        lobe = L.prim("sphere", radius=1.0, segments=6, ring_count=4, scale=(r * 1.7, r * 0.66, r * 0.78))
        lobe.data.transform(Matrix.Translation(c + side * r * 0.35 * sgn + Vector((0, 0, 0.002 * (i % 2))))
                            @ Vector((1, 0, 0)).rotation_difference(d + side * 0.7 * sgn).to_matrix().to_4x4())
        parts.append(P._finish_obj(lobe, L.scale_c(BRAID, 0.9 + 0.08 * (i % 3)), var=0.18, ao=0.15, top=0.4,
                                   hue_shift=L.hexc("#8A6A48"), seed=1 + i))
    tip = pts[-1]
    for k in range(4):  # the loose end
        a = (k - 1.5) * 0.25
        parts.append(P._stick(tip, tip + Vector((math.cos(a), math.sin(a), 0)) * 0.04, 0.005, BRAID, r1=0.001, verts=4,
                              seed=20 + k, ao=0.0))
    parts.append(L.part("cyl", L.scale_c(BRAID, 0.6), loc=tip, rot=(0, 90, 0), radius=0.008, depth=0.008, vertices=6))
    top = pts[0]
    parts.append(L.part("cyl", RIBBON, loc=top, rot=(0, 90, 0), radius=0.024, depth=0.02, vertices=8,
                        paint_kw={"ao": 0.0, "top": 0.3}))
    for sy in (-1, 1):  # ribbon ends
        parts.append(_strip(top, top + Vector((-0.05, sy * 0.035, -0.008)), 0.008, 0.007, 0.002, RIBBON, 30 + sy))
    obj = L.join(parts, "ph_item_hair_braid")
    _yaw(obj, 16)
    P._center_xy(obj)
    L.finish(obj, "ph_item_hair_braid", "items", 45)


def item_teeth_pouch():
    """A small linen pouch tied shut with dark twine - nothing of its contents is visible;
    a paper tag hangs from the tie."""
    L.reset(550)
    prof = [(0.04, 0.0), (0.062, 0.012), (0.07, 0.035), (0.064, 0.06), (0.045, 0.08), (0.024, 0.092),
            (0.02, 0.1), (0.032, 0.112), (0.03, 0.124), (0.016, 0.13)]
    bag = D._lathe(prof, 10, "pouch", cap_top=True, wobble=0.1, seed=4)
    L.jitter(bag, 0.006, 28.0, 5)
    L.paint(bag, POUCH, var=0.16, ao=0.4, zrange=(0, 0.13), hue_shift=P.LINEN_DIRTY, seed=6)
    P._modulate(bag, lambda co: 1.0 - 0.08 * max(0.0, math.sin(co.z * 170.0)) ** 4)
    L.set_mat(bag, L.MAT_PAINTED)
    parts = [bag]
    tie = [(math.cos(a) * 0.024, math.sin(a) * 0.024, 0.098) for a in (j / 10 * math.tau for j in range(10))]
    parts.append(P._finish_obj(P._path_tube(tie, 0.005, 4, closed=True), L.hexc("#3E3228"), ao=0.0, seed=7))
    parts.append(P._stick((0.02, -0.01, 0.098), (0.06, -0.05, 0.05), 0.003, L.hexc("#3E3228"), verts=3, seed=8, ao=0.0))
    parts.append(L.part("cube", P.STRING, loc=(0.066, -0.056, 0.042), scale=(0.018, 0.002, 0.012), rot=(0, 0, 40),
                        paint_kw={"ao": 0.0, "var": 0.08}))
    obj = L.join(parts, "ph_item_teeth_pouch")
    P._center_xy(obj)
    L.finish(obj, "ph_item_teeth_pouch", "items", 45)


def item_elder_key():
    """Jost Hemmerling's key: a long rusty key on a leather cord, an elder leaf filed into its
    bit (not in the section-8 list; model for journal cards / debug)."""
    L.reset(560)
    parts = []
    parts.append(P._stick((-0.06, 0.0, 0.008), (0.08, 0.0, 0.008), 0.006, P.IRON, verts=6, seed=1, ao=0.0,
                          hue_shift=P.RUST, var=0.3))
    bow = [(-0.085 + math.cos(a) * 0.026, math.sin(a) * 0.026, 0.008) for a in (j / 12 * math.tau for j in range(12))]
    parts.append(P._finish_obj(P._path_tube(bow, 0.006, 4, closed=True), P.IRON, var=0.3, ao=0.0, hue_shift=P.RUST,
                               seed=2))
    leaf = L.prim("cyl", loc=(0.068, -0.025, 0.008), radius=1.0, depth=0.006, vertices=10, scale=(0.012, 0.024, 1.0))
    for v in leaf.data.vertices:  # pointed leaf tip
        if v.co.y < -0.03:
            v.co.y -= 0.01
    parts.append(P._finish_obj(leaf, P.IRON, var=0.3, ao=0.0, top=0.3, hue_shift=P.RUST, seed=3))
    parts.append(P._stick((0.068, -0.012, 0.012), (0.068, -0.045, 0.012), 0.0015, L.hexc("#1E1C1A"), verts=3, ao=0.0))
    cord = [(-0.11 + math.cos(a) * 0.05, -0.02 + math.sin(a) * 0.07, 0.004) for a in (j / 12 * math.tau for j in range(12))]
    parts.append(P._finish_obj(P._path_tube(cord, 0.0035, 4, closed=True), P.LEATHER, ao=0.0, seed=4))
    obj = L.join(parts, "ph_item_elder_key")
    _yaw(obj, 20)
    P._center_xy(obj)
    L.finish(obj, "ph_item_elder_key", "items", 30)


ITEMS = (item_log, item_stone, item_linen, item_coin, item_shroud, item_rake, item_seeds, item_iron_fittings,
         item_scrub_brush, item_comb, item_burial_gown, item_juniper, item_shears, item_pliers, item_hair_braid,
         item_teeth_pouch, item_elder_key)
PHASE4_ITEMS = ("item_scrub_brush", "item_comb", "item_burial_gown", "item_juniper", "item_shears", "item_pliers",
                "item_hair_braid", "item_teeth_pouch", "item_elder_key")


def build(names=None):
    """Build all item models, or only those whose function name is in `names`."""
    for fn in ITEMS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
