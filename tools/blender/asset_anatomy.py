"""Phase 7: the anatomy furniture (docs/PHASE7_DESIGN.md sections 2.7 and 8) - kept quiet and tasteful.

Everything is closed, sealed or covered: specimens appear only as cloudy jars with a wax lid and a blank
paper label (the content a dark, undefined shadow), the eye jar is a small, almost black glass with two
seals, the hand only as a tied linen parcel in a wooden box. No organ shapes, no blood, no red, no skull,
no instruments in detail (the dissecting set is a closed leather case). The cloth over a corpse during a
preparation is the existing ph_prop_corpse_shrouded.

  ph_int_pult              Praeparierpult in the crypt (1.3 x 0.65 m): an oak work desk; at its front a slate
                           drawer (the cold drawer, Kuehlfach); on top at the back a row of jars UNDER A CLOTH,
                           a stick of sealing wax, blank labels, a mortar, the recipe book, a row of small bottles.
                           Markers `use` (ground point in front, where the gravekeeper stands) and `cold` (front
                           face of the slate drawer)
  ph_int_collection_shelf  Sammlungsregal (1.5 x 0.4 x 2.0 m): seven compartments (one per organ, the order of
                           AnatomyConfig.ORGANS: heart, lung, stomach, liver, kidneys, eyes, hand), each behind a
                           cloth curtain drawn half aside; a label strip under each. Markers slot_1..slot_7 (floor
                           centre of the uncovered half: a placed jar / box shows only beside the cloth) and `use`

Shared helpers for the jar family (used by asset_items.py and the Wundarztstube cabinet):
  jar(parts, at, h, r, ...)          cloudy glass, wax lid, string, paper label, an undefined dark shadow inside
  eye_jar(parts, at, ...)            small, almost black glass with two wax seals
  bundle(parts, at, ...)             linen parcel tied with string
  bone_box(parts, at, ...)           closed wooden box with a linen parcel and a label

Run:  python tools/blender/build_all.py asset_anatomy
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_village_buildings as VB

CAT = "interior"

GLASS_CLOUDY = L.hexc("#8C8A78")     # cloudy, faintly greenish-amber glass
GLASS_CLOUDY_D = L.hexc("#6E6C5E")
SHADOW_IN = L.hexc("#4A4438")        # the undefined dark shape inside
GLASS_DARK = L.hexc("#26241F")       # the eye jar: almost black
WAX = L.hexc("#7A6A4A")              # brown sealing wax (no red)
WAX_SEAL = L.hexc("#5E4E36")
PAPER = L.hexc("#CBBF9F")
STRING = L.hexc("#B9A77E")
LINEN = L.hexc("#D2C8AE")
LINEN_DIRTY = L.hexc("#B5AA8E")
OAK = L.hexc("#6E5238")
OAK_DARK = L.hexc("#4A3626")
SLATE = L.hexc("#4E5258")
SLATE_LIGHT = L.hexc("#646970")
CLOTH = L.hexc("#A8A08A")            # the cover cloth (unbleached, a little grey)
CLOTH_DARK = L.hexc("#948C78")
IRON = P.IRON
BRASS = L.hexc("#8C7648")
LEATHER = L.hexc("#5A3E2C")
box = VB._box


def _paint(o, color, **kw):
    pk = {"var": 0.12, "ao": 0.15, "top": 0.2}
    pk.update(kw)
    L.paint(o, color, **pk)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _lathe(profile, n: int = 10, name: str = "lathe"):
    """Closed surface of revolution [(r, z)] (r 0 = pole)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-5:
            rings.append(bm.verts.new((0, 0, z)))
        else:
            rings.append([bm.verts.new((math.cos(i / n * math.tau) * r, math.sin(i / n * math.tau) * r, z)) for i in range(n)])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            if not isinstance(a, list):
                bm.faces.new((a, b[i], b[j]))
            elif not isinstance(b, list):
                bm.faces.new((a[j], a[i], b))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    return P._link(bm, name)


def jar(parts, at, h: float = 0.2, r: float = 0.07, seed: int = 0, n: int = 10, label: bool = True, shadow: bool = True,
        empty: bool = False, string: bool = True):
    """A cloudy specimen jar: shoulder, neck, a brown wax lid with a string, a blank paper label; inside
    only a darker, undefined shadow in the lower half (or clear-ish when empty)."""
    at = Vector(at)
    prof = [(0.0, 0.0), (r * 0.92, 0.004), (r, 0.02), (r, h * 0.72), (r * 0.82, h * 0.84), (r * 0.7, h * 0.88), (r * 0.72, h * 0.93),
            (0.0, h * 0.93)]
    g = _lathe([(a, b) for a, b in prof], n=n, name="jar")
    g.data.transform(Matrix.Translation(at))
    base = L.mix(GLASS_CLOUDY, L.hexc("#A6A490"), 0.4) if empty else GLASS_CLOUDY

    def fn(co, vi):
        z = (co.z - at.z) / h
        c = L.mix(base, GLASS_CLOUDY_D, 0.3 + 0.3 * noise.noise(co * 25.0 + Vector((seed, 0, 0))))
        if shadow and not empty and 0.06 < z < 0.6:
            k = max(0.0, 1.0 - abs(z - 0.32) / 0.3)
            c = L.mix(c, SHADOW_IN, 0.55 * k * (0.7 + 0.3 * noise.noise(co * 18.0 + Vector((0, seed, 0)))))
        if z > 0.66:
            c = L.scale_c(c, 1.12)       # the shoulder catches the light
        return c
    P._paint_fn(g, fn)
    L.set_mat(g, L.MAT_PAINTED)
    parts.append(g)
    lid = L.prim("cyl", loc=at + Vector((0, 0, h * 0.95)), radius=r * 0.8, depth=h * 0.09, vertices=n)
    for v in lid.data.vertices:
        if v.co.z < at.z + h * 0.93:
            v.co.x = at.x + (v.co.x - at.x) * 1.06
            v.co.y = at.y + (v.co.y - at.y) * 1.06
    L.jitter(lid, r * 0.03, 30.0, seed)
    parts.append(_paint(lid, WAX, var=0.18, ao=0.0, top=0.35))
    if string:
        parts.append(L.part("torus", STRING, loc=at + Vector((0, 0, h * 0.86)), major_radius=r * 0.74, minor_radius=0.0035,
                            major_segments=n, minor_segments=3, paint_kw={"ao": 0.0}))
    if label:
        # a paper band on the front (-Y), blank
        lb = L.prim("cyl", loc=at + Vector((0, 0, h * 0.45)), radius=r * 1.015, depth=h * 0.22, vertices=n)
        bm = bmesh.new()
        bm.from_mesh(lb.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y - at.y > -r * 0.45 or abs(f.normal.z) > 0.5],
                         context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bm.to_mesh(lb.data)
        bm.free()
        parts.append(_paint(lb, PAPER, var=0.06, ao=0.0, top=0.0))
    return at + Vector((0, 0, h))


def eye_jar(parts, at, h: float = 0.11, r: float = 0.042, seed: int = 0):
    """Small, almost black glass with a wax lid and two seals on strings - nothing can be seen."""
    at = Vector(at)
    prof = [(0.0, 0.0), (r, 0.01), (r, h * 0.7), (r * 0.72, h * 0.82), (r * 0.72, h * 0.9), (0.0, h * 0.9)]
    g = _lathe(prof, n=10, name="eyejar")
    g.data.transform(Matrix.Translation(at))
    P._paint_fn(g, lambda co, vi: L.scale_c(GLASS_DARK, 1.0 + 0.25 * max(0.0, (co.z - at.z) / h - 0.6)))
    L.set_mat(g, L.MAT_PAINTED)
    parts.append(g)
    parts.append(_paint(L.prim("cyl", loc=at + Vector((0, 0, h * 0.93)), radius=r * 0.82, depth=h * 0.1, vertices=10), WAX,
                        var=0.18, ao=0.0, top=0.35))
    for sx in (-1, 1):   # two seals hanging from the lid string
        sp = at + Vector((sx * r * 0.65, -r * 0.75, h * 0.5))
        parts.append(_paint(L.prim("cyl", loc=sp, rot=(90, 0, 0), radius=r * 0.34, depth=0.008, vertices=8), WAX_SEAL, ao=0.0,
                            top=0.3))
        parts.append(VB._beam(at + Vector((sx * r * 0.5, -r * 0.55, h * 0.88)), sp + Vector((0, 0, r * 0.3)), 0.0025, STRING,
                              seed=seed + sx))
    return at + Vector((0, 0, h))


def bundle(parts, at, size=(0.12, 0.08, 0.06), seed: int = 0):
    """Linen parcel, softly rounded, tied crosswise with string."""
    at = Vector(at)
    o = L.prim("cube", loc=at + Vector((0, 0, size[2])), scale=size)
    L.bevel(o, min(size) * 0.45, 2)
    L.jitter(o, min(size) * 0.08, 18.0, seed)
    parts.append(_paint(o, LINEN, var=0.12, ao=0.3, top=0.25, hue_shift=LINEN_DIRTY, seed=seed))
    for ax in ("x", "y"):
        half = (size[0] + 0.004, 0.006, size[2] + 0.004) if ax == "x" else (0.006, size[1] + 0.004, size[2] + 0.004)
        parts.append(box(at + Vector((0, 0, size[2])), half, STRING, ao=0.0, var=0.1))
    parts.append(_paint(L.prim("ico", loc=at + Vector((0, 0, size[2] * 2 + 0.004)), radius=0.012, subdivisions=1), STRING, ao=0.0))
    return at + Vector((0, 0, size[2] * 2))


def bone_box(parts, at, size=(0.16, 0.1, 0.07), seed: int = 0, open_lid: bool = False):
    """Closed wooden box (the hand: a linen parcel inside), a blank label on the front, a hasp."""
    at = Vector(at)
    parts.append(box(at + Vector((0, 0, size[2])), size, OAK, jit=0.002, seed=seed, ao=0.3, top=0.3))
    parts.append(box(at + Vector((0, 0, size[2] * 2 + 0.008)), (size[0] + 0.008, size[1] + 0.008, 0.01), OAK_DARK, ao=0.0, top=0.35))
    parts.append(box(at + Vector((0, -size[1] - 0.002, size[2])), (size[0] * 0.45, 0.002, size[2] * 0.35), PAPER, ao=0.0, var=0.05))
    parts.append(box(at + Vector((0, -size[1] - 0.004, size[2] * 1.75)), (0.012, 0.003, 0.02), IRON, ao=0.0))
    return at + Vector((0, 0, size[2] * 2 + 0.02))


def _cloth_over(parts, x0, x1, y0, y1, z_top: float, z_drop: float, seed: int = 0, nx: int = 10, ny: int = 5, bumps=()):
    """A cloth laid over objects: a sheet over the rectangle, raised over `bumps` [(x, y, h, r)], hanging
    down at the front and sides to z_drop."""
    bm = bmesh.new()
    vs = []
    for i in range(nx + 1):
        row = []
        for j in range(ny + 1):
            x = x0 + (x1 - x0) * i / nx
            y = y0 + (y1 - y0) * j / ny
            z = z_top
            for bx, by, bh, br in bumps:
                d = math.hypot(x - bx, y - by)
                z = max(z, z_top + bh * max(0.0, 1.0 - (d / br) ** 2))
            edge = min(i, nx - i, j)
            if edge == 0:
                z = z_drop + 0.02 * math.sin(x * 23.0 + y * 7.0)
            row.append(bm.verts.new((x, y, z + 0.006 * noise.noise(Vector((x * 9, y * 9, seed))))))
        vs.append(row)
    for i in range(nx):
        for j in range(ny):
            f = bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    o = P._link(bm, "cloth")
    for poly in o.data.polygons:
        if poly.normal.z < -0.1:
            poly.flip()
    from asset_carter import _thicken
    _thicken(o, 0.008)
    parts.append(_paint(o, CLOTH, var=0.14, ao=0.3, top=0.3, hue_shift=CLOTH_DARK, seed=seed))
    return o


def _curtain(x0: float, x1: float, y: float, z_top: float, z_bot: float, seed: int = 0, n: int = 10):
    """A cloth curtain on a rod: a grid sheet with vertical folds (deeper towards the gathered side)."""
    from asset_carter import _thicken
    bm = bmesh.new()
    rows = []
    for j, z in enumerate((z_top, (z_top + z_bot) / 2, z_bot)):
        row = []
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t
            fold = (0.012 + 0.012 * t) * math.sin(t * math.pi * 7.0 + seed)
            row.append(bm.verts.new((x, y + fold - 0.004 * j, z + (0.01 * t * j if j else 0.0))))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[i + 1], r1[i + 1], r1[i]))
    o = P._link(bm, "curtain")
    _thicken(o, 0.006)
    _paint(o, CLOTH, var=0.14, ao=0.25, top=0.2, hue_shift=CLOTH_DARK, seed=seed)

    def shade(co, nr):
        t = (co.x - x0) / max(1e-6, x1 - x0)
        return 1.0 - 0.18 * max(0.0, math.sin(t * math.pi * 7.0 + seed + 1.2)), None, 0.0
    from asset_carter import _tint
    _tint(o, shade)
    return o


def _done(parts, name: str, markers=(), smooth: float = 40.0):
    obj = L.join(parts, name)
    for m, loc in markers:
        L.marker(obj, m, tuple(loc))
    L.finish(obj, name, CAT, smooth, shift=False)
    return obj


def pult():
    random.seed(7400)
    L.reset(7400)
    parts = []
    W, D, H = 0.65, 0.32, 0.86      # half width, half depth, top height
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box((sx * (W - 0.05), sy * (D - 0.05), H / 2), (0.045, 0.045, H / 2), OAK_DARK, seed=1, ao=0.3))
    parts.append(box((0.0, 0.0, H), (W + 0.03, D + 0.03, 0.035), OAK, jit=0.003, seed=2, top=0.35))
    parts.append(box((0.0, D - 0.02, H * 0.55), (W - 0.06, 0.015, H * 0.38), OAK_DARK, seed=3, ao=0.3))
    for sx in (-1, 1):
        parts.append(box((sx * (W - 0.02), 0.0, H * 0.55), (0.015, D - 0.06, H * 0.38), OAK_DARK, seed=4, ao=0.3))
    # the slate drawer: a stone-faced box under the top, an iron pull; a lower shelf
    parts.append(box((0.0, -D + 0.02, H - 0.17), (W - 0.08, 0.03, 0.12), SLATE, jit=0.003, seed=5, top=0.2, var=0.2,
                     hue_shift=SLATE_LIGHT))
    parts.append(L.part("torus", IRON, loc=(0.0, -D - 0.025, H - 0.17), rot=(90, 0, 0), major_radius=0.03, minor_radius=0.006,
                        major_segments=8, minor_segments=3))
    parts.append(box((0.0, 0.0, 0.16), (W - 0.06, D - 0.06, 0.018), OAK, seed=6, ao=0.2))
    for k in range(3):    # a little cold mist rim: pale slate edge with frost-grey (no blue)
        parts.append(box((-0.3 + k * 0.3, -D - 0.01, H - 0.29), (0.1, 0.006, 0.008), L.hexc("#8A8C8A"), ao=0.0, var=0.1))
    # on the lower shelf: a closed crate of bottles, a jug
    parts.append(box((-0.3, 0.0, 0.26), (0.18, 0.14, 0.08), OAK_DARK, seed=7, ao=0.3))
    parts.append(_paint(L.prim("cyl", loc=(0.3, 0.0, 0.3), radius=0.08, depth=0.24, vertices=8), L.hexc("#7A6A54"), ao=0.3))
    # at the back of the top: a row of jars under the cloth
    zt = H + 0.035
    xs = (-0.48, -0.3, -0.12, 0.06)
    for k, x in enumerate(xs):
        jar(parts, (x, 0.17, zt), h=0.17, r=0.06, seed=10 + k, n=8, label=False)
    _cloth_over(parts, -0.6, 0.18, 0.06, 0.3, zt + 0.02, zt, seed=20, nx=10, ny=4,
                bumps=[(x, 0.17, 0.22, 0.12) for x in xs])
    # front of the top: sealing wax stick, blank labels, mortar, the recipe book, a row of little vials
    parts.append(VB._beam((0.32, -0.15, zt + 0.012), (0.46, -0.1, zt + 0.012), 0.01, WAX, seed=30))
    for k in range(3):
        parts.append(box((0.16 + k * 0.03, -0.18 + k * 0.012, zt + 0.002 + k * 0.002), (0.04, 0.025, 0.0015), PAPER,
                         rot=(0, 0, k * 9), ao=0.0, var=0.05))
    mort = _lathe([(0.0, 0.0), (0.05, 0.004), (0.065, 0.05), (0.06, 0.07), (0.045, 0.072), (0.0, 0.05)], n=10, name="mortar")
    mort.data.transform(Matrix.Translation((-0.42, -0.14, zt)))
    parts.append(_paint(mort, L.hexc("#8A8A84"), ao=0.2, top=0.3))
    parts.append(VB._beam((-0.42, -0.14, zt + 0.06), (-0.37, -0.1, zt + 0.15), 0.012, L.hexc("#8A8A84"), seed=31))
    parts.append(box((-0.16, -0.12, zt + 0.025), (0.12, 0.09, 0.025), LEATHER, rot=(0, 0, -8), top=0.35))
    parts.append(box((-0.16, -0.12, zt + 0.024), (0.115, 0.085, 0.02), PAPER, rot=(0, 0, -8), ao=0.0))
    for k in range(5):
        x = 0.3 + k * 0.065
        v = _lathe([(0.0, 0.0), (0.02, 0.003), (0.02, 0.06), (0.009, 0.075), (0.009, 0.09), (0.0, 0.09)], n=6, name="vial")
        v.data.transform(Matrix.Translation((x, 0.18, zt)))
        parts.append(_paint(v, L.mix(GLASS_CLOUDY, L.hexc("#5E5A48"), 0.3 * (k % 2)), ao=0.1, top=0.3))
        parts.append(_paint(L.prim("cyl", loc=(x, 0.18, zt + 0.094), radius=0.01, depth=0.012, vertices=6), WAX, ao=0.0))
    markers = [("use", (0.0, -D - 0.55, 0.0)), ("cold", (0.0, -D - 0.03, H - 0.17))]
    _done(parts, "ph_int_pult", markers)


def collection_shelf():
    random.seed(7410)
    L.reset(7410)
    parts = []
    W, D = 0.75, 0.2
    rows = (0.3, 0.72, 1.14, 1.56)        # shelf boards (z of the top face)
    cols = {0: (-1, 1), 1: (-1, 1), 2: (-1, 1), 3: (0,)}   # compartments per row: 2, 2, 2, 1 (bottom to top)
    # frame
    for sx in (-1, 1):
        parts.append(box((sx * (W - 0.02), 0.0, 1.0), (0.025, D, 1.0), OAK_DARK, seed=1, ao=0.3))
    parts.append(box((0.0, D - 0.01, 1.0), (W - 0.02, 0.012, 0.99), OAK_DARK, seed=2, ao=0.4, var=0.2))
    parts.append(box((0.0, 0.0, 2.0), (W + 0.04, D + 0.03, 0.03), OAK, seed=3, top=0.3))
    parts.append(box((0.0, 0.0, 0.05), (W, D, 0.05), OAK_DARK, seed=4))
    for z in rows:
        parts.append(box((0.0, 0.0, z - 0.012), (W - 0.03, D - 0.01, 0.012), OAK, seed=5, top=0.3))
    slots = []
    for r, z in enumerate(rows):
        for c in cols[r]:
            cx = c * W / 2 if len(cols[r]) > 1 else 0.0
            cw = W / 2 - 0.04 if len(cols[r]) > 1 else W - 0.05
            if len(cols[r]) > 1:
                parts.append(box((0.0, 0.0, z + 0.2), (0.012, D - 0.02, 0.2), OAK_DARK, seed=6, ao=0.3))
            # rod and a curtain drawn half aside (covers the left part), the label strip below
            parts.append(VB._beam((cx - cw, -D + 0.02, z + 0.38), (cx + cw, -D + 0.02, z + 0.38), 0.006, IRON, seed=7))
            cl = _curtain(cx - cw, cx - cw + cw * 1.1, -D + 0.025, z + 0.37, z + 0.02, seed=8 + len(slots))
            parts.append(cl)
            parts.append(box((cx, -D + 0.005, z - 0.03), (cw * 0.5, 0.004, 0.016), PAPER, ao=0.0, var=0.05))
            slots.append(Vector((cx + cw * 0.45, 0.0, z)))
    # slot order bottom-left first; seven compartments
    markers = [("slot_%d" % (i + 1), s) for i, s in enumerate(slots)]
    markers.append(("use", (0.0, -D - 0.55, 0.0)))
    _done(parts, "ph_int_collection_shelf", markers)


ASSETS = [pult, collection_shelf]


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
