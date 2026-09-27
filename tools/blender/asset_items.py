"""Item models for UI icons (contract section 8): log, stone, linen bolt, coins, shroud.

Small (~0.3 m), centred on the origin, bottom at z = 0, front = -Y.  Rendered to
assets/ui/icons/<id>.png by src/ui/tools/icon_renderer.gd (W2).  Same painted
vertex-colour style and shared materials as every other asset.

Run:  python -c "import sys; sys.path.insert(0, 'tools/blender'); import asset_items as a; a.build()"
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh users)
from mathutils import Matrix

import lib_painted as L
import asset_props_slice as P

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


ITEMS = (item_log, item_stone, item_linen, item_coin, item_shroud)


def build(names=None):
    """Build all item models, or only those whose function name is in `names`."""
    for fn in ITEMS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
