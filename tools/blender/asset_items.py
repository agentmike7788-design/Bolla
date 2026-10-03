"""Item models for UI icons (contract section 8): log, stone, linen bolt, coins, shroud;
Phase 3 (docs/PHASE3_DESIGN.md section 8): rake, flower seeds, iron fittings;
Phase 4 (docs/PHASE4_DESIGN.md section 8): root scrub brush, wooden comb, burial gown, juniper,
shears, pliers, hair braid, teeth pouch (a tied linen pouch - nothing visible), elder key;
Phase 5 (docs/PHASE5_DESIGN.md section 8): the tool tiers (iron / master shovel, axe, pickaxe - also
shown on the tool belt), flax, yarn, clay, iron ore, iron bar, charcoal, workstone, elderberries,
herbs, ink, herb bundle, gold leaf, steel rod;
Phase 6 (docs/PHASE6_DESIGN.md section 8): altar candle, bone box, bone box (full: tied, blank tag);
Phase 7 (docs/PHASE7_DESIGN.md section 8): preparation jars, spirits, beeswax, the closed dissecting case, the
specimens (cloudy sealed jar, the dark eye glass variant, linen bundle, display bell, bone box), the medicines
(labelled bottles, tins, a crock, powder papers), honey cake, elder wine (PHASE7_ITEMS).
Only the new ones (build_all rebuilds every item):
    python -c "import sys; sys.path.insert(0, 'tools/blender'); import asset_items as a; a.build(a.PHASE5_ITEMS)"

Small (~0.3 m), centred on the origin, bottom at z = 0, front = -Y.  Rendered to
assets/ui/icons/<id>.png by src/ui/tools/icon_renderer.gd (W2).  Same painted
vertex-colour style and shared materials as every other asset.

Run:  python -c "import sys; sys.path.insert(0, 'tools/blender'); import asset_items as a; a.build()"
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector, noise

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


# --- Phase 5 (docs/PHASE5_DESIGN.md section 8) --------------------------------------------------
# Tool tiers: iron (tier 1) = dark iron with a worn light edge; master (tier 2) = blued blade
# (dusky blue-grey, low saturation - never a cold saturated blue) and a warm brass ring on the haft.

BLUED = L.hexc("#434C5A")
BLUED_EDGE = L.hexc("#6A7280")
BRASS = L.hexc("#B08A48")
HAFT = L.hexc("#7A5E40")
HAFT_OLD = L.hexc("#6B5E50")
FLAX_STRAW = L.hexc("#B39A56")
FLAX_CAPSULE = L.hexc("#8C6E3E")
YARN = L.hexc("#D6CAA6")
CLAY_ITEM = L.hexc("#8E7A5C")
ORE = L.hexc("#4E3C32")
ORE_RUST = L.hexc("#8A5234")
CHARCOAL_ITEM = L.hexc("#2A2624")
WORKSTONE = L.hexc("#8C9094")
ELDERBERRY = L.hexc("#3B2D40")      # ink-violet as in Phase 4
ELDER_STALK = L.hexc("#6E3E48")
TANSY_ITEM = L.hexc("#D2A93A")
HERB_LEAF = L.hexc("#566A40")
MUGWORT_ITEM = L.hexc("#7E8A6C")
INK_DARK = L.hexc("#221A26")
GLASS = L.hexc("#4E5448")           # dull green-brown bottle glass
CORK = L.hexc("#A08058")
PAPER = L.hexc("#D8CCAE")
GOLD_LEAF = L.hexc("#C9A24A")
STEEL_ROD = L.hexc("#6E7278")


def _haft(parts, p0, p1, r: float, color, seed: int, ring=None) -> None:
    """Wooden tool handle lying on the ground; `ring` = position (0..1) of a brass ring."""
    parts.append(P._stick(p0, p1, r, color, r1=r * 0.9, verts=6, seed=seed, ao=0.15, zrange=(0, 0.06)))
    P._tint_up(parts[-1], L.hexc("#9A7A52"), 0.35, 0.5, seed=seed)      # worn grip
    if ring is not None:
        c = Vector(p0).lerp(Vector(p1), ring)
        d = (Vector(p1) - Vector(p0)).normalized()
        rg = L.prim("cyl", radius=r * 1.3, depth=0.03, vertices=8)
        rg.data.transform(Matrix.Translation(c) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
        parts.append(P._finish_obj(rg, BRASS, var=0.15, ao=0.0, top=0.4, hue_shift=L.hexc("#8A6A34"), seed=seed + 1))


def _blade_colors(master: bool):
    return (BLUED, BLUED_EDGE) if master else (P.IRON, IRON_EDGE)


def _shovel(name: str, master: bool) -> None:
    """Spade lying on its back: haft with a D-grip, a flat blade with a lighter worn edge."""
    L.reset(600)
    parts = []
    body, edge = _blade_colors(master)
    r = 0.012
    _haft(parts, (-0.16, 0.0, r), (0.08, 0.0, r), r, HAFT, 1, ring=0.85 if master else None)
    grip = [(-0.19 + math.cos(a) * 0.03, math.sin(a) * 0.035, r) for a in (j / 10 * math.tau for j in range(10))]
    parts.append(P._finish_obj(P._path_tube(grip, 0.007, 4, closed=True), HAFT, ao=0.0, seed=2))
    parts.append(_strip((0.07, 0.0, 0.012), (0.1, 0.0, 0.012), 0.014, 0.02, 0.006, body, 3))        # socket
    bl = L.prim("cube", loc=(0.17, 0.0, 0.006), scale=(0.075, 0.06, 0.004))
    L.subdivide(bl, 1)
    for v in bl.data.vertices:                     # rounded, slightly tapered spade point, a little dished
        u = (v.co.x - 0.095) / 0.15
        v.co.y *= 1.0 - 0.25 * max(0.0, u - 0.6) ** 1.5
        v.co.z += 0.008 * abs(v.co.y) / 0.06
    P._paint_fn(bl, lambda co, vi: L.mix(body, edge, max(0.0, (co.x - 0.2) / 0.045)))
    L.set_mat(bl, L.MAT_PAINTED)
    parts.append(bl)
    if not master:
        P._tint_up(bl, P.RUST, 0.35, 0.5, freq=30.0, seed=4)
    obj = L.join(parts, name)
    _yaw(obj, -28)
    P._center_xy(obj)
    L.finish(obj, name, "items", 35)


def item_shovel_iron():
    """Eisenschaufel: forged iron spade on an ash haft with a D-grip."""
    _shovel("ph_item_shovel_iron", False)


def item_shovel_master():
    """Meisterschaufel: the same spade with a blued blade and a brass ring below the grip."""
    _shovel("ph_item_shovel_master", True)


def _axe(name: str, master: bool) -> None:
    """Felling axe lying flat: a long, slightly curved haft, a wedge head with a flared bit."""
    L.reset(610)
    parts = []
    body, edge = _blade_colors(master)
    r = 0.012
    haft = [(-0.2, 0.0, r), (-0.05, 0.008, r), (0.1, 0.0, r), (0.16, -0.006, r)]
    parts.append(P._finish_obj(P._tube(haft, [r * 0.95, r, r * 0.9, r * 0.85], sides=8), HAFT, var=0.15, ao=0.1,
                               seed=1))
    if master:
        rg = L.prim("cyl", loc=(0.1, 0.0, r), rot=(0, 90, 0), radius=r * 1.3, depth=0.028, vertices=8)
        parts.append(P._finish_obj(rg, BRASS, var=0.15, ao=0.0, top=0.4, seed=2))
    parts.append(P._rbox((0.15, 0.0, 0.016), (0.022, 0.024, 0.016), body, bev=0.004, seg=1, jit=0.0, seed=3, ao=0.0))
    bm = bmesh.new()
    prof = [(0.132, -0.02), (0.168, -0.02), (0.19, -0.09), (0.11, -0.095)]
    lo = [bm.verts.new((x, y, 0.004)) for x, y in prof]
    hi = [bm.verts.new((x, y, 0.024 if y > -0.03 else 0.012)) for x, y in prof]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(4):
        bm.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]))
    head = P._link(bm, "bit")
    P._paint_fn(head, lambda co, vi: L.mix(body, edge, max(0.0, (-co.y - 0.07) / 0.025)))
    L.set_mat(head, L.MAT_PAINTED)
    parts.append(head)
    if not master:
        P._tint_up(parts[-2], P.RUST, 0.3, 0.5, freq=30.0, seed=4)
    obj = L.join(parts, name)
    _yaw(obj, -25)
    P._center_xy(obj)
    L.finish(obj, name, "items", 35)


def item_axe_iron():
    """Holzfälleraxt: an iron felling axe, dark head, bright worn bit."""
    _axe("ph_item_axe_iron", False)


def item_axe_master():
    """Meisteraxt: blued head, a brass ring round the haft."""
    _axe("ph_item_axe_master", True)


def _pick(name: str, master: bool) -> None:
    """Pickaxe lying flat: haft and a two-pointed curved head (pick and chisel end)."""
    L.reset(620)
    parts = []
    body, edge = _blade_colors(master)
    r = 0.012
    _haft(parts, (-0.2, 0.0, r), (0.14, 0.0, r), r, HAFT if master else HAFT_OLD, 1, ring=0.8 if master else None)
    parts.append(P._rbox((0.145, 0.0, 0.016), (0.02, 0.022, 0.016), body, bev=0.004, seg=1, jit=0.0, seed=2, ao=0.0))
    for sgn in (-1, 1):
        pts = [(0.145, 0.0, 0.016), (0.135, sgn * 0.06, 0.016), (0.11, sgn * 0.12, 0.014)]
        tip = P._tube(pts, [0.014, 0.01, 0.003 if sgn < 0 else 0.006], sides=4, hint=(0, 0, 1))
        P._paint_fn(tip, lambda co, vi: L.mix(body, edge, max(0.0, (abs(co.y) - 0.08) / 0.04)))
        L.set_mat(tip, L.MAT_PAINTED)
        parts.append(tip)
    if not master:
        for o in parts[-3:]:
            P._tint_up(o, P.RUST, 0.6, 0.3, freq=25.0, seed=3)      # Osric's old pick: rusty
    obj = L.join(parts, name)
    _yaw(obj, -22)
    P._center_xy(obj)
    L.finish(obj, name, "items", 35)


def item_pickaxe_iron():
    """Alte Spitzhacke: Osric's old pick, a weathered haft, rust on the head."""
    _pick("ph_item_pickaxe_iron", False)


def item_pickaxe_master():
    """Meisterhacke: blued head, a fresh haft with a brass ring."""
    _pick("ph_item_pickaxe_master", True)


def item_flax():
    """A bundle of pulled flax: straw-yellow stalks tied in the middle, seed capsules at one end."""
    L.reset(630)
    rnd = random.Random(631)
    parts = []
    for k in range(9):
        y = (k - 4) * 0.009
        z = 0.012 + 0.008 * (k % 3)
        yaw = math.radians(rnd.uniform(-5, 5))
        d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        p0 = Vector((-0.16, y, z))
        parts.append(P._stick(p0, p0 + d * 0.3, 0.0045, L.scale_c(FLAX_STRAW, rnd.uniform(0.85, 1.1)), verts=3, seed=k,
                              ao=0.0))
        if k % 2 == 0:
            parts.append(L.part("ico", FLAX_CAPSULE, loc=p0 + d * 0.31 + Vector((0, rnd.uniform(-0.01, 0.01), 0.004)),
                                radius=0.009, subdivisions=1, paint_kw={"ao": 0.0, "top": 0.4}))
    tie = [(-0.02, math.cos(a) * 0.045, 0.022 + math.sin(a) * 0.02) for a in (j / 8 * math.tau for j in range(8))]
    parts.append(P._finish_obj(P._path_tube(tie, 0.005, 4, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0, seed=20))
    obj = L.join(parts, "ph_item_flax")
    _yaw(obj, -24)
    P._center_xy(obj)
    L.finish(obj, "ph_item_flax", "items", 35)


def item_yarn():
    """A ball of linen yarn wound in crossing bands, a loose end, and a small twisted hank."""
    L.reset(640)
    ball = L.prim("sphere", loc=(0.02, 0.0, 0.075), radius=0.075, segments=12, ring_count=8)
    L.jitter(ball, 0.003, 30.0, 1)
    P._paint_fn(ball, lambda co, vi: L.scale_c(YARN, 0.9 + 0.1 * math.sin((co.x + co.z * 0.6) * 150.0)
                                               * math.sin((co.y - co.z * 0.5) * 60.0 + 1.0)))
    L.set_mat(ball, L.MAT_PAINTED)
    parts = [ball]
    end = [(0.09, -0.02, 0.07), (0.12, -0.05, 0.02), (0.14, -0.1, 0.004), (0.1, -0.14, 0.004)]
    parts.append(P._finish_obj(P._path_tube(end, 0.003, 3), YARN, ao=0.0, seed=2))
    for k in range(3):     # a twisted hank lying beside the ball
        pts = [(-0.16 + i * 0.03, -0.07 + 0.01 * math.sin(i * 1.2 + k * 2.1), 0.01 + 0.004 * math.cos(i * 1.2 + k * 2.1))
               for i in range(7)]
        parts.append(P._finish_obj(P._path_tube(pts, 0.008, 4), L.scale_c(YARN, 0.95 + 0.04 * k), ao=0.0, seed=3 + k))
    obj = L.join(parts, "ph_item_yarn")
    P._center_xy(obj)
    L.finish(obj, "ph_item_yarn", "items", 40)


def item_clay():
    """A lump of grey-ochre clay, pressed flat on top with a thumb print, a smaller lump beside."""
    L.reset(650)
    big = L.prim("ico", loc=(0.0, 0.0, 0.06), radius=1.0, subdivisions=3, scale=(0.12, 0.1, 0.065))
    L.jitter(big, 0.012, 12.0, 1)
    for v in big.data.vertices:
        if v.co.z > 0.1:
            v.co.z = 0.1 + (v.co.z - 0.1) * 0.3 - 0.012 * math.exp(-((v.co.x - 0.02) ** 2 + v.co.y ** 2) / 0.0012)
    parts = [P._finish_obj(big, CLAY_ITEM, var=0.18, ao=0.3, top=0.2, hue_shift=L.hexc("#6E5640"), seed=2)]
    small = L.prim("ico", loc=(0.13, -0.07, 0.03), radius=1.0, subdivisions=1, scale=(0.045, 0.04, 0.03))
    L.jitter(small, 0.006, 20.0, 3)
    parts.append(P._finish_obj(small, CLAY_ITEM, var=0.18, ao=0.3, top=0.2, seed=3))
    obj = L.join(parts, "ph_item_clay")
    P._center_xy(obj)
    L.finish(obj, "ph_item_clay", "items", 40)


def item_iron_ore():
    """Three rough lumps of iron ore: dark brown rock with a rust-orange crust."""
    L.reset(660)
    parts = []
    for k, (x, y, r) in enumerate(((0.0, 0.0, 0.07), (0.1, -0.05, 0.045), (-0.09, -0.06, 0.04))):
        o = L.prim("cube", loc=(x, y, r * 0.8), scale=(r, r * 0.85, r * 0.75))
        L.subdivide(o, 1)
        L.jitter(o, r * 0.35, 1.2 / r, 10 + k)
        L.paint(o, ORE, var=0.3, ao=0.3, top=0.2, hue_shift=ORE_RUST, noise_freq=20.0, seed=10 + k)
        P._tint_up(o, ORE_RUST, 0.45, 0.4, freq=25.0, seed=k)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    obj = L.join(parts, "ph_item_iron_ore")
    P._center_xy(obj)
    L.finish(obj, "ph_item_iron_ore", "items", 30)


def item_iron_bar():
    """Two forged iron bars, crossed: square section, hammered ends, faint hammer facets."""
    L.reset(670)
    parts = []
    for k, (yaw, z) in enumerate(((-12.0, 0.013), (20.0, 0.037))):
        o = L.prim("cube", scale=(0.15, 0.018, 0.012))
        L.subdivide(o, 2)
        for v in o.data.vertices:
            if abs(v.co.x) > 0.12:
                v.co.y *= 0.8
                v.co.z *= 0.75
        L.jitter(o, 0.0015, 50.0, k)
        o.data.transform(Matrix.Translation((0.0, 0.0, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z"))
        parts.append(P._finish_obj(o, P.IRON, var=0.3, ao=0.1, top=0.4, hue_shift=L.hexc("#4E4A48"), seed=k))
    obj = L.join(parts, "ph_item_iron_bar")
    P._center_xy(obj)
    L.finish(obj, "ph_item_iron_bar", "items", 30)


def item_charcoal():
    """A small heap of charcoal sticks: black, cracked, the split ends showing the grain."""
    L.reset(680)
    rnd = random.Random(681)
    parts = []
    for k in range(6):
        yaw = math.radians(rnd.uniform(-60, 60))
        d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
        c = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 0.022 + 0.02 * (k // 3)))
        ln = rnd.uniform(0.1, 0.16)
        o = L.tube(c - d * ln / 2, c + d * ln / 2, rnd.uniform(0.018, 0.024), 6)
        L.jitter(o, 0.003, 40.0, k)
        P._paint_fn(o, lambda co, vi: L.scale_c(CHARCOAL_ITEM, 0.8 + 0.5 * abs(math.sin(co.x * 90.0 + co.y * 70.0))))
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    obj = L.join(parts, "ph_item_charcoal")
    P._center_xy(obj)
    L.finish(obj, "ph_item_charcoal", "items", 25)


def item_workstone():
    """A squared, dressed block of workstone (ashlar): clean edges, fine chisel lines on top."""
    L.reset(690)
    o = L.prim("cube", loc=(0.0, 0.0, 0.065), scale=(0.13, 0.085, 0.065))
    L.bevel(o, 0.008, 1)
    L.subdivide(o, 1)
    L.jitter(o, 0.002, 10.0, 1)
    P._paint_fn(o, lambda co, vi: L.scale_c(WORKSTONE, (0.92 + 0.08 * math.sin(co.x * 180.0 + co.y * 40.0))
                                           * (1.08 if co.z > 0.12 else 0.9)))
    L.set_mat(o, L.MAT_PAINTED)
    parts = [o]
    for k in range(3):
        parts.append(L.part("ico", L.hexc("#A7AAAB"), loc=(0.16 + 0.02 * k, -0.06 + 0.04 * k, 0.008), radius=0.012,
                            subdivisions=1, paint_kw={"ao": 0.0}))
    obj = L.join(parts, "ph_item_workstone")
    _yaw(obj, -20)
    P._center_xy(obj)
    L.finish(obj, "ph_item_workstone", "items", 30)


def item_elderberries():
    """An umbel of ripe elderberries laid down: reddish stalks, ink-violet berries, a leaflet."""
    L.reset(700)
    rnd = random.Random(701)
    parts = []
    c = Vector((0.0, 0.0, 0.02))
    parts.append(P._stick((-0.17, 0.02, 0.012), c, 0.005, ELDER_STALK, verts=4, seed=1, ao=0.0))
    for k in range(6):
        a = k / 6 * math.tau
        tip = c + Vector((math.cos(a) * 0.07 + 0.05, math.sin(a) * 0.07, 0.01))
        parts.append(P._stick(c, tip, 0.003, ELDER_STALK, verts=3, seed=2 + k, ao=0.0))
        for j in range(3):
            parts.append(L.part("ico", L.scale_c(ELDERBERRY, rnd.uniform(0.85, 1.15)),
                                loc=tip + Vector((rnd.uniform(-0.018, 0.018), rnd.uniform(-0.018, 0.018), 0.008)),
                                radius=0.012, subdivisions=1, paint_kw={"ao": 0.1, "top": 0.5, "noise_freq": 30.0}))
    leaf = L.prim("sphere", loc=(-0.1, -0.05, 0.008), radius=1.0, segments=6, ring_count=3, scale=(0.05, 0.02, 0.004),
                  rot=(0, 0, 30))
    parts.append(P._finish_obj(leaf, L.hexc("#566444"), ao=0.0, top=0.3, seed=9))
    obj = L.join(parts, "ph_item_elderberries")
    P._center_xy(obj)
    L.finish(obj, "ph_item_elderberries", "items", 30)


def _herb_sprig(parts, p0, p1, color, head, seed: int, buttons: int = 0) -> None:
    p0, p1 = Vector(p0), Vector(p1)
    parts.append(P._stick(p0, p1, 0.003, L.hexc("#5A5A3A"), verts=3, seed=seed, ao=0.0))
    d = (p1 - p0).normalized()
    for i in range(3):   # small leaves along the stalk
        c = p0.lerp(p1, 0.3 + i * 0.22) + Vector((0, 0, 0.004))
        lf = L.prim("sphere", radius=1.0, segments=5, ring_count=3, scale=(0.022, 0.009, 0.003))
        lf.data.transform(Matrix.Translation(c) @ Vector((1, 0, 0)).rotation_difference(d).to_matrix().to_4x4()
                          @ Matrix.Rotation(math.radians(40 if i % 2 else -40), 4, "Z") @ Matrix.Translation((0.018, 0, 0)))
        parts.append(P._finish_obj(lf, color, ao=0.0, top=0.3, var=0.2, seed=seed + i))
    for k in range(buttons):
        parts.append(L.part("cyl", head, loc=p1 + Vector((0.008 * (k % 2), 0.012 * (k - 1), 0.006)), radius=0.011,
                            depth=0.008, vertices=5, paint_kw={"ao": 0.0, "top": 0.3}))


def item_herbs():
    """A loose handful of fresh herbs: tansy with golden buttons and grey-green mugwort."""
    L.reset(710)
    parts = []
    for k, (yaw, col, btn) in enumerate(((-10, HERB_LEAF, 3), (8, MUGWORT_ITEM, 0), (22, HERB_LEAF, 3),
                                         (-24, MUGWORT_ITEM, 0))):
        a = math.radians(yaw)
        p0 = Vector((-0.14, 0.0, 0.006 + 0.003 * k))
        _herb_sprig(parts, p0, p0 + Vector((math.cos(a), math.sin(a), 0.03)) * 0.27, col, TANSY_ITEM, 10 + k * 5, btn)
    obj = L.join(parts, "ph_item_herbs")
    P._center_xy(obj)
    L.finish(obj, "ph_item_herbs", "items", 30)


def item_ink():
    """Elder ink: a squat bottle of dull glass with a cork, an ink-dark drip and stain, a quill."""
    L.reset(720)
    prof = [(0.04, 0.0), (0.05, 0.01), (0.052, 0.06), (0.04, 0.08), (0.018, 0.09), (0.017, 0.11), (0.021, 0.115)]
    bottle = D._lathe(prof, 10, "bottle", cap_top=True, wobble=0.03, seed=1)
    P._paint_fn(bottle, lambda co, vi: INK_DARK if (co.z > 0.07 and -1.9 < math.atan2(co.y, co.x) < -1.2)
                else L.scale_c(GLASS, 0.9 + 0.3 * co.z / 0.1))
    L.set_mat(bottle, L.MAT_PAINTED)
    parts = [bottle]
    parts.append(L.part("cyl", CORK, loc=(0.0, 0.0, 0.125), radius=0.016, depth=0.022, vertices=8,
                        paint_kw={"ao": 0.0, "top": 0.3}))
    parts.append(L.part("cyl", INK_DARK, loc=(0.03, -0.075, 0.001), radius=0.028, depth=0.002, vertices=8,
                        scale=(1.3, 1.0, 1.0), paint_kw={"ao": 0.0, "var": 0.05}))
    parts.append(P._stick((0.02, 0.02, 0.1), (0.2, 0.08, 0.004), 0.003, L.hexc("#D8D0BC"), verts=3, seed=3, ao=0.0))
    q0, q1 = Vector((0.02, 0.02, 0.1)), Vector((0.2, 0.08, 0.004))
    vane = L.prim("sphere", radius=1.0, segments=6, ring_count=3, scale=(0.055, 0.014, 0.003))
    vane.data.transform(Matrix.Translation(q0.lerp(q1, 0.45) + Vector((0, 0, 0.004)))
                        @ Vector((1, 0, 0)).rotation_difference((q1 - q0).normalized()).to_matrix().to_4x4())
    parts.append(P._finish_obj(vane, L.hexc("#D8D0BC"), ao=0.0, top=0.3, seed=4))
    obj = L.join(parts, "ph_item_ink")
    P._center_xy(obj)
    L.finish(obj, "ph_item_ink", "items", 35)


def item_herb_bundle():
    """Räucherkräuter: a tight bundle of dried mugwort and tansy wound round with twine."""
    L.reset(730)
    body = L.prim("cyl", loc=(0.0, 0.0, 0.035), rot=(0, 90, 0), radius=0.032, depth=0.24, vertices=8)
    L.subdivide(body, 2)
    for v in body.data.vertices:          # thicker at the flower end
        f = 1.0 + 0.35 * max(0.0, v.co.x / 0.12)
        v.co.y *= f
        v.co.z = 0.035 + (v.co.z - 0.035) * f
    L.jitter(body, 0.004, 30.0, 1)
    P._paint_fn(body, lambda co, vi: L.scale_c(L.mix(L.hexc("#76805E"), L.hexc("#9A9470"), 0.5 + 0.5 * math.sin(co.x * 90.0)),
                                               0.85 + 0.25 * max(0.0, co.z / 0.07)))
    L.set_mat(body, L.MAT_PAINTED)
    parts = [body]
    wind = [(-0.1 + i * 0.006, math.cos(i * 0.7) * 0.036, 0.035 + math.sin(i * 0.7) * 0.036) for i in range(28)]
    parts.append(P._finish_obj(P._path_tube(wind, 0.0035, 3), P.ROPE, ao=0.0, seed=2))
    for k in range(4):
        parts.append(L.part("cyl", L.scale_c(TANSY_ITEM, 0.8), loc=(0.125, -0.03 + k * 0.02, 0.04 + 0.012 * (k % 2)),
                            rot=(0, 90, 0), radius=0.01, depth=0.008, vertices=5, paint_kw={"ao": 0.0}))
    obj = L.join(parts, "ph_item_herb_bundle")
    _yaw(obj, -24)
    P._center_xy(obj)
    L.finish(obj, "ph_item_herb_bundle", "items", 35)


def item_gold_leaf():
    """A little booklet of gold leaf: paper leaves, dull gold sheets showing between them."""
    L.reset(740)
    parts = []
    for k in range(5):
        z = 0.004 + k * 0.005
        col = PAPER if k % 2 == 0 else GOLD_LEAF
        sheet = L.prim("cube", loc=(0.0, 0.0, z), scale=(0.08, 0.08, 0.0022), rot=(0, 0, k * 3 - 6))
        L.subdivide(sheet, 1)
        if k == 4:                          # the top leaf folded back a little
            for v in sheet.data.vertices:
                if v.co.x > 0.02:
                    v.co.z += (v.co.x - 0.02) * 0.4
        parts.append(P._finish_obj(sheet, col, var=0.12, ao=0.0, top=0.3,
                                   hue_shift=GOLD_DARK if col == GOLD_LEAF else P.LINEN_DIRTY, seed=k))
    obj = L.join(parts, "ph_item_gold_leaf")
    _yaw(obj, -15)
    P._center_xy(obj)
    L.finish(obj, "ph_item_gold_leaf", "items", 30)


def item_steel_rod():
    """Two lengths of bright bar steel, square section, tied at one end with twine and a paper tag."""
    L.reset(750)
    parts = []
    for k, (y, yaw) in enumerate(((-0.02, -4.0), (0.02, 5.0))):
        o = L.prim("cube", loc=(0.0, y, 0.009 + 0.012 * k), scale=(0.2, 0.008, 0.008), rot=(0, 0, yaw))
        L.subdivide(o, 1)
        parts.append(P._finish_obj(o, STEEL_ROD, var=0.15, ao=0.0, top=0.45, hue_shift=IRON_EDGE, seed=k))
    tie = [(-0.14, math.cos(a) * 0.035, 0.015 + math.sin(a) * 0.022) for a in (j / 8 * math.tau for j in range(8))]
    parts.append(P._finish_obj(P._path_tube(tie, 0.004, 4, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0, seed=5))
    parts.append(L.part("cube", PAPER, loc=(-0.16, -0.06, 0.004), scale=(0.025, 0.018, 0.002), rot=(0, 0, 25),
                        paint_kw={"ao": 0.0}))
    obj = L.join(parts, "ph_item_steel_rod")
    _yaw(obj, -25)
    P._center_xy(obj)
    L.finish(obj, "ph_item_steel_rod", "items", 30)


# --- Phase 6 (docs/PHASE6_DESIGN.md section 8) ---------------------------------------------------

CANDLE_WAX = L.hexc("#E8DEC6")      # altar candle: pale beeswax-white, not pure white
BOX_WOOD = L.hexc("#7C5B3D")
TAG = L.hexc("#D8CCAA")


def item_altar_candle():
    """Two tall altar candles lying side by side, tied with a thread; a paper band round them."""
    L.reset(760)
    parts = []
    for k, (y, ln) in enumerate(((-0.024, 0.3), (0.024, 0.28))):
        c = L.prim("cyl", loc=(0.0, y, 0.022), rot=(0, 90, 0), radius=0.022, depth=ln, vertices=8)
        L.jitter(c, 0.001, 20.0, k)
        parts.append(P._finish_obj(c, CANDLE_WAX, var=0.06, ao=0.1, top=0.3, hue_shift=L.hexc("#D8C9A4"), seed=k))
        parts.append(L.part("cyl", L.hexc("#2A2420"), loc=(ln / 2 + 0.004, y, 0.022), rot=(0, 90, 0), radius=0.003,
                            depth=0.014, vertices=4))
    band = L.prim("cube", loc=(-0.03, 0.0, 0.022), scale=(0.02, 0.05, 0.025))
    L.bevel(band, 0.012, 1)
    parts.append(P._finish_obj(band, TAG, var=0.05, ao=0.0, top=0.2))
    tie = [(0.08, math.cos(a) * 0.05, 0.022 + math.sin(a) * 0.026) for a in (j / 8 * math.tau for j in range(8))]
    parts.append(P._finish_obj(P._path_tube(tie, 0.003, 3, closed=True, hint=(1, 0, 0)), P.ROPE, ao=0.0, seed=5))
    obj = L.join(parts, "ph_item_altar_candle")
    _yaw(obj, -25)
    P._center_xy(obj)
    L.finish(obj, "ph_item_altar_candle", "items", 35)


def _bone_box(name: str, full: bool) -> None:
    """A small plank box with a lid (the empty one open, lid leaning); full: closed, tied crosswise
    with a cord and a blank name tag hanging from it."""
    L.reset(770 if full else 771)
    parts = []
    hx, hy, h = 0.15, 0.09, 0.13
    for sy in (-1, 1):
        parts.append(P._plank((0.0, sy * (hy - 0.006), h / 2), (hx, 0.007, h / 2), BOX_WOOD, seed=1 + sy, ao=0.25))
    for sx in (-1, 1):
        parts.append(P._plank((sx * (hx - 0.007), 0.0, h / 2), (0.007, hy - 0.012, h / 2), P.WOOD, seed=3 + sx, ao=0.25))
    parts.append(P._plank((0.0, 0.0, 0.006), (hx, hy - 0.006, 0.006), P.WOOD_DARK, seed=6))
    if full:
        lid = L.prim("cube", loc=(0.0, 0.0, h + 0.009), scale=(hx + 0.012, hy + 0.012, 0.009))
        L.bevel(lid, 0.004, 1)
        parts.append(P._finish_obj(lid, L.scale_c(BOX_WOOD, 0.95), var=0.12, ao=0.0, top=0.25))
        for axis in (0, 1):    # the cord crosswise over the lid and round the box
            if axis == 0:
                pts = [(x, 0.0, h + 0.02) for x in (-hx - 0.003, hx + 0.003)]
                loop = [(-hx - 0.004, 0.0, h + 0.02), (hx + 0.004, 0.0, h + 0.02), (hx + 0.004, 0.0, 0.0),
                        (-hx - 0.004, 0.0, 0.0)]
            else:
                loop = [(0.0, -hy - 0.004, h + 0.02), (0.0, hy + 0.004, h + 0.02), (0.0, hy + 0.004, 0.0),
                        (0.0, -hy - 0.004, 0.0)]
            parts.append(P._finish_obj(P._path_tube(loop, 0.003, 3, closed=True), P.ROPE, ao=0.0, seed=10 + axis))
        tag = L.prim("cube", loc=(0.06, -hy - 0.012, h - 0.02), scale=(0.028, 0.002, 0.018), rot=(0, 12, 0))
        parts.append(P._finish_obj(tag, TAG, var=0.05, ao=0.0))
        parts.append(P._stick((0.05, -hy - 0.01, h + 0.0), (0.0, -hy - 0.004, h + 0.02), 0.0015, P.ROPE, verts=3, ao=0.0))
    else:
        parts.append(L.part("cube", L.hexc("#2E241C"), loc=(0.0, 0.0, h - 0.004), scale=(hx - 0.014, hy - 0.014, 0.002),
                            paint_kw={"ao": 0.0}))
        lid = L.prim("cube", loc=(0.0, hy + 0.03, h * 0.62), scale=(hx + 0.012, 0.009, hy + 0.012), rot=(-14, 0, 0))
        parts.append(P._finish_obj(lid, L.scale_c(BOX_WOOD, 0.95), var=0.12, ao=0.2, top=0.25))
    obj = L.join(parts, name)
    _yaw(obj, -22)
    P._center_xy(obj)
    L.finish(obj, name, "items", 35)


def item_bone_box():
    _bone_box("ph_item_bone_box", False)


def item_bone_box_full():
    _bone_box("ph_item_bone_box_full", True)


# --- Phase 7 (docs/PHASE7_DESIGN.md sections 2.8 and 8) -------------------------------------------------
# Specimens only as cloudy, sealed jars (an undefined dark shadow inside), the eyes as a small, almost black
# glass with two seals, linen bundles, a closed wooden box; medicines as labelled bottles and powder papers.
# No red, no organ shapes.

def _p7(parts, name: str, yaw: float = -22.0, smooth: float = 35.0) -> None:
    obj = L.join(parts, name)
    _yaw(obj, yaw)
    P._center_xy(obj)
    L.finish(obj, name, "items", smooth)


def _bottle(parts, at, h: float, r: float, glass, neck: float = 0.35, label=True, seed: int = 0, n: int = 8, cork=None):
    """Bottle: body, shoulder, neck, a cork (or wax), an optional blank label on the front."""
    import asset_anatomy as A
    at = Vector(at)
    prof = [(0.0, 0.0), (r, 0.004), (r, h * (1 - neck)), (r * 0.4, h * (1 - neck * 0.45)), (r * 0.32, h * 0.92), (r * 0.36, h * 0.96),
            (0.0, h * 0.96)]
    b = A._lathe(prof, n=n, name="bottle")
    b.data.transform(Matrix.Translation(at))
    P._paint_fn(b, lambda co, vi: L.scale_c(glass, 0.85 + 0.35 * max(0.0, (co.z - at.z) / h - 0.5)))
    L.set_mat(b, L.MAT_PAINTED)
    parts.append(b)
    parts.append(L.part("cyl", cork or L.hexc("#8A7050"), loc=at + Vector((0, 0, h * 0.99)), radius=r * 0.3, depth=h * 0.08, vertices=6,
                        paint_kw={"ao": 0.0, "top": 0.3}))
    if label:
        parts.append(L.part("cube", A.PAPER, loc=at + Vector((0, -r - 0.002, h * 0.4)), scale=(r * 0.75, 0.002, h * 0.16),
                            paint_kw={"ao": 0.0, "var": 0.05}))


def item_prep_jar():
    """An empty preparation jar: clear-ish glass, a wax lid on a string, no label yet; a second lid beside it."""
    import asset_anatomy as A
    L.reset(780)
    parts = []
    A.jar(parts, (0.0, 0.0, 0.0), h=0.2, r=0.07, seed=1, n=10, label=False, empty=True)
    parts.append(L.part("cyl", A.WAX, loc=(0.11, -0.03, 0.01), radius=0.05, depth=0.02, vertices=10, paint_kw={"ao": 0.0, "top": 0.3}))
    _p7(parts, "ph_item_prep_jar")


def item_prep_jar_small():
    """The small, dark preparation glass with two seals (for the eyes), empty - two of them."""
    import asset_anatomy as A
    L.reset(781)
    parts = []
    A.eye_jar(parts, (0.0, 0.0, 0.0), h=0.12, r=0.05, seed=2)
    A.eye_jar(parts, (0.1, 0.05, 0.0), h=0.1, r=0.04, seed=3)
    _p7(parts, "ph_item_prep_jar_small")


def item_spirits():
    """A flask of spirits (Branntwein): brown-green glass, a cork, a blank label; a little cup beside it."""
    L.reset(782)
    parts = []
    _bottle(parts, (0.0, 0.0, 0.0), 0.27, 0.055, L.hexc("#5E5A3E"), seed=1)
    cup = L.prim("cyl", loc=(0.09, -0.04, 0.025), radius=0.03, depth=0.05, vertices=8)
    L.taper(cup, 0.0, 0.05, 1.2)
    parts.append(P._finish_obj(cup, L.hexc("#8A8A84"), var=0.1, ao=0.2, top=0.3))
    _p7(parts, "ph_item_spirits")


def item_beeswax():
    """Two cakes of beeswax, rounded, honey-brown."""
    L.reset(783)
    parts = []
    for k, (x, y, r, h) in enumerate(((0.0, 0.0, 0.09, 0.05), (0.1, 0.06, 0.07, 0.04))):
        c = L.prim("cyl", loc=(x, y, h / 2), radius=r, depth=h, vertices=12)
        L.bevel(c, 0.01, 1)
        L.jitter(c, 0.003, 12.0, k)
        parts.append(P._finish_obj(c, L.hexc("#B08C48"), var=0.12, ao=0.2, top=0.35, hue_shift=L.hexc("#8C6A34"), seed=k))
    _p7(parts, "ph_item_beeswax")


def item_anatomy_case():
    """The dissecting set: a CLOSED leather case with a strap and a brass clasp - nothing of the instruments shows."""
    L.reset(784)
    parts = []
    case = L.prim("cube", loc=(0.0, 0.0, 0.035), scale=(0.17, 0.08, 0.035))
    L.bevel(case, 0.02, 2)
    parts.append(P._finish_obj(case, L.hexc("#5A3E2C"), var=0.14, ao=0.25, top=0.35, hue_shift=L.hexc("#3E2A1E")))
    parts.append(L.part("cube", L.hexc("#3E2A1E"), loc=(0.05, 0.0, 0.035), scale=(0.018, 0.083, 0.037), paint_kw={"ao": 0.0}))
    parts.append(L.part("cube", L.hexc("#8C7648"), loc=(0.05, -0.084, 0.04), scale=(0.022, 0.004, 0.016), paint_kw={"ao": 0.0, "top": 0.5}))
    _p7(parts, "ph_item_anatomy_case")


def item_specimen_jar():
    """A specimen in its jar: cloudy glass, a wax lid on a string, a paper label; inside only a dark, undefined shadow."""
    import asset_anatomy as A
    L.reset(785)
    parts = []
    A.jar(parts, (0.0, 0.0, 0.0), h=0.21, r=0.072, seed=4, n=10)
    _p7(parts, "ph_item_specimen_jar")


def item_specimen_jar_eyes():
    """(Variant icon) the eyes: the small, almost black glass with two seals and a label - nothing recognisable."""
    import asset_anatomy as A
    L.reset(786)
    parts = []
    A.eye_jar(parts, (0.0, 0.0, 0.0), h=0.13, r=0.055, seed=5)
    parts.append(L.part("cube", A.PAPER, loc=(0.0, -0.057, 0.05), scale=(0.035, 0.002, 0.018), paint_kw={"ao": 0.0}))
    parts.append(L.part("cyl", A.WAX, loc=(0.07, 0.03, 0.006), radius=0.022, depth=0.012, vertices=8, paint_kw={"ao": 0.0}))
    _p7(parts, "ph_item_specimen_jar_eyes")


def item_specimen_bundle():
    """A specimen in linen: a soft parcel tied crosswise, a paper tag on the string."""
    import asset_anatomy as A
    L.reset(787)
    parts = []
    A.bundle(parts, (0.0, 0.0, 0.0), size=(0.11, 0.08, 0.05), seed=6)
    parts.append(L.part("cube", A.PAPER, loc=(0.08, -0.08, 0.04), scale=(0.025, 0.002, 0.015), rot=(0, 10, 0), paint_kw={"ao": 0.0}))
    _p7(parts, "ph_item_specimen_bundle")


def item_display_specimen():
    """A display specimen: a cloudy glass bell on a turned wooden base, sealed with wax; inside a dark shadow."""
    import asset_anatomy as A
    L.reset(788)
    parts = []
    base = A._lathe([(0.0, 0.0), (0.1, 0.004), (0.105, 0.02), (0.09, 0.035), (0.0, 0.035)], n=12, name="base")
    parts.append(P._finish_obj(base, A.OAK, var=0.12, ao=0.2, top=0.35))
    bell = A._lathe([(0.0, 0.035), (0.075, 0.035), (0.078, 0.15), (0.06, 0.2), (0.02, 0.225), (0.0, 0.228)], n=12, name="bell")

    def fn(co, vi):
        z = co.z / 0.23
        c = L.mix(A.GLASS_CLOUDY, A.GLASS_CLOUDY_D, 0.3 + 0.3 * noise.noise(co * 25.0))
        if 0.2 < z < 0.65:
            c = L.mix(c, A.SHADOW_IN, 0.5 * max(0.0, 1.0 - abs(z - 0.42) / 0.23))
        return c
    P._paint_fn(bell, fn)
    L.set_mat(bell, L.MAT_PAINTED)
    parts.append(bell)
    parts.append(L.part("torus", A.WAX, loc=(0.0, 0.0, 0.04), major_radius=0.08, minor_radius=0.008, major_segments=12, minor_segments=3,
                        paint_kw={"ao": 0.0}))
    parts.append(L.part("cyl", A.WAX_SEAL, loc=(0.0, -0.085, 0.045), rot=(90, 0, 0), radius=0.018, depth=0.006, vertices=8,
                        paint_kw={"ao": 0.0}))
    parts.append(L.part("cube", A.PAPER, loc=(0.0, -0.1, 0.018), scale=(0.04, 0.002, 0.01), paint_kw={"ao": 0.0}))
    _p7(parts, "ph_item_display_specimen")


def item_bone_specimen():
    """The bone specimen: a tied linen parcel lying in a wooden box with a blank label - nothing else shows."""
    import asset_anatomy as A
    L.reset(789)
    parts = []
    hx, hy, h = 0.16, 0.08, 0.06
    for sy in (-1, 1):
        parts.append(P._plank((0.0, sy * (hy - 0.006), h / 2), (hx, 0.007, h / 2), A.OAK, seed=1 + sy, ao=0.25))
    for sx in (-1, 1):
        parts.append(P._plank((sx * (hx - 0.007), 0.0, h / 2), (0.007, hy - 0.012, h / 2), A.OAK_DARK, seed=3 + sx, ao=0.25))
    parts.append(P._plank((0.0, 0.0, 0.006), (hx, hy - 0.006, 0.006), A.OAK_DARK, seed=6))
    A.bundle(parts, (0.0, 0.0, 0.01), size=(0.13, 0.06, 0.035), seed=7)
    parts.append(L.part("cube", A.PAPER, loc=(0.0, -hy - 0.002, h * 0.5), scale=(0.05, 0.002, 0.018), paint_kw={"ao": 0.0}))
    _p7(parts, "ph_item_bone_specimen")


def _powder_papers(parts, at, n: int = 3, seed: int = 0):
    """Folded powder papers (Pulverbriefchen), stacked a little askew, a thread round each."""
    import asset_anatomy as A
    at = Vector(at)
    for k in range(n):
        p = L.prim("cube", loc=at + Vector((0.01 * k, 0.006 * k, 0.006 + k * 0.012)), scale=(0.06, 0.04, 0.005), rot=(0, 0, k * 11 - 8))
        L.bevel(p, 0.003, 1)
        parts.append(P._finish_obj(p, L.scale_c(A.PAPER, 0.95 + 0.04 * k), var=0.05, ao=0.1, top=0.3, seed=seed + k))
        parts.append(L.part("cube", L.hexc("#6E5A44"), loc=at + Vector((0.01 * k, 0.006 * k, 0.012 + k * 0.012)),
                            scale=(0.008, 0.041, 0.002), rot=(0, 0, k * 11 - 8), paint_kw={"ao": 0.0}))


def item_fever_tincture():
    """Fever tincture: a small brown bottle with a paper label and a cork, a second one behind."""
    L.reset(790)
    parts = []
    _bottle(parts, (0.0, 0.0, 0.0), 0.15, 0.045, L.hexc("#5A4A34"), seed=1)
    _bottle(parts, (0.075, 0.05, 0.0), 0.13, 0.038, L.hexc("#5A4A34"), seed=2)
    _p7(parts, "ph_item_fever_tincture")


def item_wound_salve():
    """Wound salve: two little round tins of ointment, one open (pale yellow salve)."""
    L.reset(791)
    parts = []
    for k, (x, y, op) in enumerate(((0.0, 0.0, False), (0.1, 0.04, True))):
        t = L.prim("cyl", loc=(x, y, 0.02), radius=0.05, depth=0.04, vertices=12)
        parts.append(P._finish_obj(t, L.hexc("#7C8187"), var=0.1, ao=0.2, top=0.4))
        if op:
            parts.append(L.part("cyl", L.hexc("#C8B880"), loc=(x, y, 0.041), radius=0.044, depth=0.004, vertices=12,
                                paint_kw={"ao": 0.0, "var": 0.1}))
        else:
            parts.append(L.part("cyl", L.hexc("#6A6E74"), loc=(x, y, 0.043), radius=0.052, depth=0.008, vertices=12,
                                paint_kw={"ao": 0.0, "top": 0.4}))
    _p7(parts, "ph_item_wound_salve")


def item_corpse_balm():
    """Corpse balm: a clay crock covered with a cloth tied with string, a paper tag."""
    import asset_anatomy as A
    L.reset(792)
    parts = []
    crock = A._lathe([(0.0, 0.0), (0.05, 0.003), (0.065, 0.06), (0.055, 0.1), (0.05, 0.11), (0.0, 0.11)], n=10, name="crock")
    parts.append(P._finish_obj(crock, L.hexc("#7A6450"), var=0.14, ao=0.25, top=0.3))
    cl = L.prim("sphere", loc=(0.0, 0.0, 0.11), radius=1.0, scale=(0.065, 0.065, 0.025), segments=10, ring_count=4)
    L.jitter(cl, 0.006, 20.0, 1)
    parts.append(P._finish_obj(cl, A.LINEN, var=0.12, ao=0.1, top=0.3))
    parts.append(L.part("torus", A.STRING, loc=(0.0, 0.0, 0.1), major_radius=0.053, minor_radius=0.003, major_segments=10, minor_segments=3))
    parts.append(L.part("cube", A.PAPER, loc=(0.075, -0.04, 0.005), scale=(0.03, 0.02, 0.003), paint_kw={"ao": 0.0}))
    _p7(parts, "ph_item_corpse_balm")


def item_antidote():
    """Antidote "nach Quast": two squat, square-shouldered bottles with broad labels and wax-sealed corks."""
    import asset_anatomy as A
    L.reset(793)
    parts = []
    _bottle(parts, (0.0, 0.0, 0.0), 0.14, 0.05, L.hexc("#4E5246"), neck=0.25, seed=1, n=6, cork=A.WAX)
    _bottle(parts, (0.08, 0.05, 0.0), 0.12, 0.04, L.hexc("#4E5246"), neck=0.25, seed=2, n=6, cork=A.WAX)
    _p7(parts, "ph_item_antidote")


def item_bitter_drops():
    """Bitter drops "nach Quast": two slim dark dropper bottles with labels."""
    L.reset(794)
    parts = []
    _bottle(parts, (0.0, 0.0, 0.0), 0.16, 0.036, L.hexc("#3A3428"), neck=0.45, seed=1)
    _bottle(parts, (0.065, 0.055, 0.0), 0.15, 0.033, L.hexc("#3A3428"), neck=0.45, seed=2)
    _p7(parts, "ph_item_bitter_drops")


def item_dropsy_powder():
    """Dropsy powder "nach Quast": three folded powder papers, each tied with a thread."""
    L.reset(795)
    parts = []
    _powder_papers(parts, (0.0, 0.0, 0.0), 3, seed=1)
    _p7(parts, "ph_item_dropsy_powder")


def item_honey_cake():
    """Honigkuchen: a square brown cake with blanched almonds on top, a broken-off piece."""
    L.reset(796)
    parts = []
    c = L.prim("cube", loc=(0.0, 0.0, 0.025), scale=(0.11, 0.08, 0.025))
    L.bevel(c, 0.01, 1)
    L.jitter(c, 0.003, 10.0, 1)
    parts.append(P._finish_obj(c, L.hexc("#7A4E2C"), var=0.12, ao=0.2, top=0.35, hue_shift=L.hexc("#5E3A22")))
    for k in range(6):
        a = k / 6 * math.tau
        parts.append(L.part("sphere", L.hexc("#D8C8A0"), loc=(math.cos(a) * 0.06, math.sin(a) * 0.04, 0.051), radius=1.0,
                            scale=(0.014, 0.008, 0.004), segments=6, ring_count=3, paint_kw={"ao": 0.0}))
    piece = L.prim("cube", loc=(0.15, -0.06, 0.02), scale=(0.035, 0.03, 0.02), rot=(0, 0, 30))
    parts.append(P._finish_obj(piece, L.hexc("#7A4E2C"), var=0.12, ao=0.2, top=0.35))
    _p7(parts, "ph_item_honey_cake")


def item_elder_wine():
    """Holunderwein: a dark bottle with a cork and a label painted with a little elder sprig (no text), a spare cork."""
    L.reset(797)
    parts = []
    _bottle(parts, (0.0, 0.0, 0.0), 0.28, 0.058, L.hexc("#2E2830"), seed=1)
    for k in range(4):
        parts.append(L.part("cube", L.hexc("#4E6440") if k < 2 else L.hexc("#D8CEAE"),
                            loc=(-0.02 + k * 0.013, -0.063, 0.11 + (k % 2) * 0.01), scale=(0.006, 0.002, 0.006), paint_kw={"ao": 0.0}))
    parts.append(L.part("cyl", L.hexc("#8A7050"), loc=(0.09, -0.02, 0.012), rot=(0, 90, 20), radius=0.012, depth=0.035, vertices=6))
    _p7(parts, "ph_item_elder_wine")


PHASE7_ITEMS = ("item_prep_jar", "item_prep_jar_small", "item_spirits", "item_beeswax", "item_anatomy_case", "item_specimen_jar",
                "item_specimen_jar_eyes", "item_specimen_bundle", "item_display_specimen", "item_bone_specimen",
                "item_fever_tincture", "item_wound_salve", "item_corpse_balm", "item_antidote", "item_bitter_drops",
                "item_dropsy_powder", "item_honey_cake", "item_elder_wine")


ITEMS = (item_log, item_stone, item_linen, item_coin, item_shroud, item_rake, item_seeds, item_iron_fittings,
         item_scrub_brush, item_comb, item_burial_gown, item_juniper, item_shears, item_pliers, item_hair_braid,
         item_teeth_pouch, item_elder_key,
         item_shovel_iron, item_shovel_master, item_axe_iron, item_axe_master, item_pickaxe_iron, item_pickaxe_master,
         item_flax, item_yarn, item_clay, item_iron_ore, item_iron_bar, item_charcoal, item_workstone,
         item_elderberries, item_herbs, item_ink, item_herb_bundle, item_gold_leaf, item_steel_rod,
         item_altar_candle, item_bone_box, item_bone_box_full,
         item_prep_jar, item_prep_jar_small, item_spirits, item_beeswax, item_anatomy_case, item_specimen_jar,
         item_specimen_jar_eyes, item_specimen_bundle, item_display_specimen, item_bone_specimen, item_fever_tincture,
         item_wound_salve, item_corpse_balm, item_antidote, item_bitter_drops, item_dropsy_powder, item_honey_cake,
         item_elder_wine)
PHASE6_ITEMS = ("item_altar_candle", "item_bone_box", "item_bone_box_full")
PHASE5_ITEMS = ("item_shovel_iron", "item_shovel_master", "item_axe_iron", "item_axe_master", "item_pickaxe_iron",
                "item_pickaxe_master", "item_flax", "item_yarn", "item_clay", "item_iron_ore", "item_iron_bar",
                "item_charcoal", "item_workstone", "item_elderberries", "item_herbs", "item_ink", "item_herb_bundle",
                "item_gold_leaf", "item_steel_rod")
PHASE4_ITEMS = ("item_scrub_brush", "item_comb", "item_burial_gown", "item_juniper", "item_shears", "item_pliers",
                "item_hair_braid", "item_teeth_pouch", "item_elder_key")


def build(names=None):
    """Build all item models, or only those whose function name is in `names`."""
    for fn in ITEMS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
