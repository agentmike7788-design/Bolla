"""Phase-5 environment (docs/PHASE5_DESIGN.md sections 2.2, 4.2, 4.3, 8): gather nodes of the
Schlag and of Am Bruch, the quarry walls, the boulders.

  ph_env_alder_coppice / _alder_stump / _alder_sapling
                               coppiced alder: a multi-stemmed tree on its stool / the stool with fresh,
                               light cut faces / the stool with young shoots (Stockausschlag)
  ph_env_flax_bed / _flax_bed_empty
                               ripe flax bed (straw-yellow stalks, seed capsules, no blue: the bloom is
                               over) / pulled (bare earth rows, tiny shoots)
  ph_env_clay_pit              clay pit with spade-cut edges and a matt puddle
  ph_env_quarry_face / _quarry_edge
                               9 m rock face / 3 m edge piece, painted bedding in the #8A8F94 family
  ph_env_ore_vein / _ore_vein_empty
                               outcrop with rust-brown veins / hacked out
  ph_env_workstone_ledge / _ledge_empty
                               squared bedrock ledge with a row of wedge holes / the block taken out
  ph_env_rubble_face           broken rubble wall with a heap of loose stones
  ph_env_boulder / _boulder_broken
                               mossy erratic ~2 x 1.6 m / broken into chunks with fresh faces
  ph_env_herb_patch / _herb_patch_cut
                               tansy (yellow buttons) and mugwort / cut back to stubble

Leaf masses use mat_foliage, stalks and blades mat_grass, everything else mat_painted.
Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m.
Run:  python tools/blender/build_all.py asset_env_phase5
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_env_phase3 as E
from asset_environment import _limb as limb

STONE = L.hexc("#8A8F94")
STONE_MID = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_WARM = L.hexc("#8F877A")
STONE_OCHRE = L.hexc("#948266")
STONE_FRESH = L.hexc("#A7AAAB")    # freshly broken face
MOSS = P.MOSS
MOSS_LIGHT = L.hexc("#71804F")
EARTH = P.EARTH
EARTH_FRESH = P.EARTH_FRESH
EARTH_DARK = P.EARTH_DARK
GRASS = P.GRASS
ALDER_BARK = L.hexc("#5C544C")     # dark grey-brown
ALDER_BARK_DARK = L.hexc("#3E3833")
ALDER_LEAF_A = L.hexc("#3C5234")   # dark, deep green
ALDER_LEAF_B = L.hexc("#566B40")
ALDER_CUT = L.hexc("#D0A878")      # fresh cut: light, warm (alder wood turns orange)
ALDER_CUT_EDGE = L.hexc("#B8844E")
STRAW = L.hexc("#B39A56")
STRAW_DARK = L.hexc("#8A7440")
CAPSULE = L.hexc("#9C7E44")
CLAY = L.hexc("#8E7A5C")
CLAY_WET = L.hexc("#6E5640")
PUDDLE = L.hexc("#5C5A4E")
RUST_VEIN = L.hexc("#8A5234")
RUST_DARK = L.hexc("#5E3A28")
TANSY = L.hexc("#D2A93A")
TANSY_LEAF = L.hexc("#4E6234")
MUGWORT = L.hexc("#687A52")        # grey-green, silvery
STUBBLE = L.hexc("#8A8452")


# --- helpers ---------------------------------------------------------------------------------

def _rock(loc, size, seed: int, color=STONE, subdiv: int = 2, moss: float = 0.6, flat: float = 1.0, rot=(0, 0, 0),
          zr=None, angular: float = 0.3):
    """Angular, weathered rock: jittered icosphere, facets flattened, mossy on top."""
    if angular >= 0.5:                           # broken stone: a battered, skewed block
        s = L.prim("cube", scale=(0.85, 0.85, 0.85))
        L.subdivide(s, 1 if subdiv <= 1 else 2)
        L.jitter(s, 0.32, 0.9, seed)
        L.jitter(s, 0.07, 3.0, seed + 50)
    else:
        s = L.prim("ico", radius=1.0, subdivisions=subdiv)
        for v in s.data.vertices:                # facet it: snap towards a few planes
            v.co = v.co.normalized() * (1.0 - angular * 0.5 + angular * max(abs(v.co.x), abs(v.co.y), abs(v.co.z)))
        L.jitter(s, 0.18, 1.3, seed)
        L.jitter(s, 0.05, 4.0, seed + 50)
    s.data.transform(Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
                     @ Matrix.Rotation(math.radians(rot[0]), 4, "X") @ Matrix.Diagonal((size[0], size[1], size[2] * flat, 1)))
    L.paint(s, color, var=0.22, ao=0.45, top=0.15, zrange=zr or (0.0, loc[2] + size[2]), hue_shift=STONE_DARK, seed=seed)
    if moss:
        P._tint_up(s, MOSS, moss, 0.45, freq=2.5, seed=seed)
    L.set_mat(s, L.MAT_PAINTED)
    return s


def _stool(parts, r: float, h: float, seed: int, n: int = 10):
    """Coppice stool: a low, gnarled, mossy base swollen from many cuts."""
    prof = [(r * 1.25, -0.04), (r * 1.1, 0.06), (r, h * 0.6), (r * 0.92, h)]
    o = E_lathe(prof, n, seed)
    L.jitter(o, r * 0.12, 3.0 / r, seed)
    L.paint(o, L.scale_c(ALDER_BARK, 1.15), var=0.3, ao=0.3, zrange=(0, h + 0.3), hue_shift=ALDER_BARK_DARK, seed=seed)
    P._tint_up(o, MOSS, 0.7, 0.2, freq=4.0, seed=seed)
    L.set_mat(o, L.MAT_PAINTED)
    parts.append(o)
    return o


def E_lathe(profile, n: int, seed: int, cap: bool = True):
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((math.cos(j / n * math.tau) * r, math.sin(j / n * math.tau) * r, z)) for j in range(n)])
    for a, b in zip(rings, rings[1:]):
        for j in range(n):
            bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if cap:
        bm.faces.new(rings[-1])
    return P._link(bm, "lathe")


def _cut_stem(parts, base, direction, length: float, r: float, seed: int, cut_color=ALDER_CUT) -> None:
    """A stem stub sawn off at a slant: bark sides, a light fresh cut face with a darker ring."""
    d = Vector(direction).normalized()
    end = Vector(base) + d * length
    st = L.tube(base, end, r, 7, r_end=r * 0.9)
    L.paint(st, ALDER_BARK, var=0.25, ao=0.3, hue_shift=ALDER_BARK_DARK, seed=seed)
    L.set_mat(st, L.MAT_PAINTED)
    parts.append(st)
    face = L.prim("cyl", radius=r * 0.92, depth=0.012, vertices=7)
    face.data.transform(Matrix.Translation(end + Vector((0, 0, 0.004))) @ Matrix.Rotation(math.radians(12), 4, "X"))
    P._paint_fn(face, lambda co, vi: L.mix(cut_color, ALDER_CUT_EDGE, min(1.0, (co - end).length / (r * 0.9)) ** 2))
    L.set_mat(face, L.MAT_PAINTED)
    parts.append(face)


# --- the coppiced alder -----------------------------------------------------------------------

STOOL_R = 0.34


def alder_coppice():
    """Schlag-Erle (~6 m): five straight, slightly splaying stems out of one mossy stool, dark
    grey-brown bark, a narrow crown of deep green leaf masses, a few dark cones (strobili)."""
    L.reset(2200)
    rnd = random.Random(2201)
    parts = []
    _stool(parts, STOOL_R, 0.28, 1)
    tops = []
    for i in range(5):
        a = i / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        h = rnd.uniform(4.8, 6.0)
        sp = rnd.uniform(0.1, 0.17)
        lean = (math.cos(a) * sp, math.sin(a) * sp, 0.0)
        tr = E._straight_trunk(h, rnd.uniform(0.1, 0.13), 0.035, 12, 6, lean, 10 + i)
        base = Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.12))
        tr.data.transform(Matrix.Translation(base))

        def bark(co, vi):
            c = L.scale_c(L.mix(ALDER_BARK_DARK, ALDER_BARK, 0.5 + 0.5 * noise.noise(co * 4.0)), 0.85 + 0.25 * min(1.0, co.z / 4.0))
            if math.sin(co.z * 17.0 + noise.noise(co * 2.0) * 4.0) > 0.85:       # light lenticel dashes
                c = L.mix(c, L.hexc("#8A8278"), 0.6)
            return L.mix(c, MOSS, max(0.0, 0.7 - co.z * 0.6) * max(0.0, noise.noise(co * 3.0 + Vector((2, 2, 2))) + 0.3))
        P._paint_fn(tr, bark)
        L.set_mat(tr, L.MAT_PAINTED)
        parts.append(tr)
        tops.append((base, Vector(lean), a, h))
    k = 0
    for base, lean, a, h in tops:                 # leaf masses up the upper half of every stem
        for j, (t, r, out) in enumerate(((0.5, 0.62, 0.32), (0.7, 0.7, 0.42), (0.88, 0.6, 0.3), (1.0, 0.42, 0.1))):
            z = h * t
            c = base + lean * z + Vector((0, 0, z)) + Vector((math.cos(a + j * 0.7), math.sin(a + j * 0.7), 0.0)) * out
            shade = rnd.random()
            parts.append(E._clump(c, r, L.mix(ALDER_LEAF_A, ALDER_LEAF_B, 0.1 + shade * 0.6), 40 + k,
                                  subdiv=2, scale=(1.0, 1.0, 0.9), zr=(1.8, 6.5), jit=0.3,
                                  hue=L.hexc("#687A44") if shade > 0.7 else None))
            k += 1
        br = limb(base + lean * h * 0.45 + Vector((0, 0, h * 0.45)), (math.cos(a), math.sin(a), 0.6), 0.9, 0.035, 0.01,
                  60 + k, segs=3, verts=4, droop=0.2)
        L.paint(br, ALDER_BARK, var=0.2, ao=0.1, seed=61 + k)
        L.set_mat(br, L.MAT_PAINTED)
        parts.append(br)
    for i in range(6):                            # strobili clusters hanging at the crown rim
        base, lean, a, h = tops[i % 5]
        p = base + lean * h * 0.75 + Vector((math.cos(a + 0.5) * 0.95, math.sin(a + 0.5) * 0.95, h * 0.72))
        parts.append(L.part("ico", L.hexc("#3A2E26"), loc=p, radius=0.05, subdivisions=1, scale=(1.0, 1.0, 1.4),
                            paint_kw={"ao": 0.0, "top": 0.3}))
    parts.append(E._blades([((0.0, 0.0), 12, (0.18, 0.32), 0.014, 0.14)], E.GRASS_TINT, 80))
    obj = L.join(parts, "ph_env_alder_coppice")
    P._center_xy(obj)
    L.finish(obj, "ph_env_alder_coppice", "environment", 50, shift=False)


def alder_stump():
    """The stool just after felling: five sawn stem stubs with fresh light faces, chips around."""
    L.reset(2210)
    rnd = random.Random(2211)
    parts = []
    _stool(parts, STOOL_R, 0.28, 1, n=9)
    for i in range(5):
        a = i / 5 * math.tau + rnd.uniform(-0.3, 0.3)
        base = Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.2))
        _cut_stem(parts, base, (math.cos(a) * 0.25, math.sin(a) * 0.25, 1.0), rnd.uniform(0.14, 0.24),
                  rnd.uniform(0.1, 0.125), 10 + i)
    for i in range(7):                            # fresh chips on the ground
        parts.append(L.part("cube", L.mix(ALDER_CUT, ALDER_CUT_EDGE, rnd.random()),
                            loc=(rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.6), 0.008), scale=(0.035, 0.02, 0.006),
                            rot=(0, 0, rnd.uniform(0, 180)), paint_kw={"ao": 0.0, "top": 0.2}))
    obj = L.join(parts, "ph_env_alder_stump")
    P._center_xy(obj)
    L.finish(obj, "ph_env_alder_stump", "environment", 45, shift=False)


def alder_sapling():
    """Stockausschlag: the stool with the old cut faces greyed, a dozen whippy young shoots
    (1-1.8 m) and small leaf tufts along them."""
    L.reset(2220)
    rnd = random.Random(2221)
    parts = []
    _stool(parts, STOOL_R, 0.28, 1, n=9)
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        _cut_stem(parts, Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.2)), (math.cos(a) * 0.2, math.sin(a) * 0.2, 1.0),
                  0.1, 0.075, 10 + i, cut_color=L.hexc("#8A7E6E"))
    for i in range(9):
        a = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        base = Vector((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.24))
        h = rnd.uniform(1.0, 1.8)
        tip = base + Vector((math.cos(a) * h * 0.28, math.sin(a) * h * 0.28, h))
        mid = base.lerp(tip, 0.5) + Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 0.0))
        parts.append(E._cane([base, mid, tip], 0.014, 0.005, L.hexc("#6A5A48"), 20 + i, sides=3, zr=(0, 2.0)))
        if i % 3 != 2:
            parts.append(E._clump(tip - Vector((0, 0, 0.22)), rnd.uniform(0.2, 0.28),
                                  L.mix(ALDER_LEAF_A, ALDER_LEAF_B, 0.3 + rnd.random() * 0.5), 40 + i, subdiv=2,
                                  scale=(1.0, 1.0, 1.3), zr=(0.3, 2.0), jit=0.3))
    parts.append(E._blades([((0.0, 0.0), 10, (0.15, 0.3), 0.014, 0.12)], E.GRASS_TINT, 80))
    obj = L.join(parts, "ph_env_alder_sapling")
    P._center_xy(obj)
    L.finish(obj, "ph_env_alder_sapling", "environment", 45, shift=False)


# --- flax -------------------------------------------------------------------------------------

BED_X, BED_Y = 0.7, 0.5       # half size of a bed (1.4 x 1.0 m)


def _bed_soil(seed: int, furrows: bool):
    """Raised, slightly mounded bed of dark worked earth with a ragged grass rim."""
    o = L.prim("grid", x_subdivisions=10, y_subdivisions=8, size=1.0, scale=(BED_X * 2.2, BED_Y * 2.3, 1.0))
    for v in o.data.vertices:
        u, w = abs(v.co.x) / (BED_X * 1.1), abs(v.co.y) / (BED_Y * 1.15)
        e = max(u, w)
        v.co.z = 0.07 * max(0.0, 1.0 - e ** 4) + 0.012 * noise.noise(v.co * 6.0)
    ring = [max(abs(v.co.x) / (BED_X * 1.1), abs(v.co.y) / (BED_Y * 1.15)) for v in o.data.vertices]

    def col(co, vi):
        e = ring[vi]
        c = L.mix(EARTH_FRESH, EARTH, 0.35 + 0.3 * noise.noise(co * 5.0))
        if furrows:
            c = L.scale_c(c, 0.85 + 0.2 * math.cos(co.y / BED_Y * math.pi * 3))
        return L.mix(c, L.mix(GRASS, EARTH, 0.3), max(0.0, (e - 0.8) / 0.2))
    P._paint_fn(o, col)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def flax_bed():
    """Ripe flax (1.4 x 1.0 m): a dense stand of straw-yellow stalks ~0.7 m, a few leaning,
    topped with little brown seed capsules. The blue bloom is long over."""
    L.reset(2300)
    rnd = random.Random(2301)
    parts = [_bed_soil(1, False)]
    tufts = []
    heads = []
    for i in range(44):
        x, y = rnd.uniform(-BED_X * 0.95, BED_X * 0.95), rnd.uniform(-BED_Y * 0.9, BED_Y * 0.9)
        tufts.append(((x, y), 5, (0.5, 0.78), 0.016, 0.1))
        if i % 2 == 0:
            heads.append((x, y))
    bl = E._blades(tufts, STRAW, 10, zr=(0.0, 0.8), hue=STRAW_DARK)
    bl.data.transform(Matrix.Translation((0, 0, 0.05)))
    parts.append(bl)
    for i, (x, y) in enumerate(heads):           # capsule clusters at the stalk tops
        for k in range(1 + (i % 3 == 0)):
            p = (x + rnd.uniform(-0.05, 0.05), y + rnd.uniform(-0.05, 0.05), 0.05 + rnd.uniform(0.6, 0.78))
            parts.append(L.part("cube", L.scale_c(CAPSULE, rnd.uniform(0.85, 1.1)), loc=p, scale=(0.012, 0.012, 0.014),
                                rot=(45, 35, rnd.uniform(0, 90)), paint_kw={"ao": 0.0, "top": 0.4}))
    obj = L.join(parts, "ph_env_flax_bed")
    P._center_xy(obj)
    L.finish(obj, "ph_env_flax_bed", "environment", 40, shift=False)


def flax_bed_empty():
    """Pulled flax bed: raked earth in rows, a scatter of tiny shoots, one forgotten stalk tuft."""
    L.reset(2310)
    rnd = random.Random(2311)
    parts = [_bed_soil(2, True)]
    tufts = [((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.4, 0.4)), 3, (0.04, 0.08), 0.006, 0.02) for _ in range(8)]
    bl = E._blades(tufts, E.SPROUT_BRIGHT, 20, zr=(0.0, 0.2))
    bl.data.transform(Matrix.Translation((0, 0, 0.06)))
    parts.append(bl)
    st = E._blades([((0.55, -0.3), 4, (0.35, 0.5), 0.008, 0.2)], STRAW, 21, zr=(0.0, 0.6), hue=STRAW_DARK)
    st.data.transform(Matrix.Translation((0, 0, 0.05)))
    parts.append(st)
    obj = L.join(parts, "ph_env_flax_bed_empty")
    P._center_xy(obj)
    L.finish(obj, "ph_env_flax_bed_empty", "environment", 40, shift=False)


# --- clay pit ---------------------------------------------------------------------------------

def clay_pit():
    """A dug clay pit (1.9 x 1.5 m). It cannot go below the ground mesh, so the depth is painted
    (as the grave pit): a raised rim of dug-out clay with spade-cut inner faces, the bottom in
    dark wet clay with a matt puddle, a heap of dug clay beside it."""
    L.reset(2400)
    rnd = random.Random(2401)
    rings = [(0.98, 0.78, 0.0), (0.86, 0.68, 0.1), (0.76, 0.6, 0.14), (0.66, 0.52, 0.06), (0.54, 0.42, 0.02),
             (0.34, 0.26, 0.012), (0.14, 0.1, 0.01)]
    n = 24

    def shape(k, x, y):
        f = 1.0 + 0.06 * noise.noise(Vector((x * 3, y * 3, k)))
        dz = 0.0
        if 1 <= k <= 2:
            dz = 0.05 * noise.noise(Vector((x * 4, y * 4, 5))) - (0.07 if y < -0.3 else 0.0)   # low front: the ramp
        return f, dz
    pit = P._rings_mesh(rings, n, shape, p=3.0, name="pit")
    ring = P._ring_of(pit, n)

    def col(co, vi):
        k = ring[vi]
        if k == 0:
            return L.mix(GRASS, EARTH, 0.4)
        if k <= 2:
            return L.scale_c(L.mix(CLAY, EARTH, 0.25), 1.0 + 0.1 * noise.noise(co * 6.0))
        # inside: darker the deeper it reads, the far wall (+Y) lit, spade strata
        d = min(1.0, (k - 2) / 3.0)
        far = max(0.0, co.y / 0.6)
        c = L.mix(L.mix(CLAY, CLAY_WET, d), CLAY, far * 0.5)
        c = L.scale_c(c, (1.0 - 0.45 * d * (1.0 - far)) * (0.93 + 0.1 * math.sin(math.atan2(co.y, co.x) * 9.0)))
        return c
    P._paint_fn(pit, col)
    L.set_mat(pit, L.MAT_PAINTED)
    parts = [pit]
    puddle = P._rings_mesh([(0.3, 0.2, 0.016), (0.18, 0.12, 0.018)], 14,
                           lambda k, x, y: (1.0 + 0.15 * noise.noise(Vector((x * 6, y * 6, 1))), 0.0), p=2.0, name="puddle")
    puddle.data.transform(Matrix.Translation((0.06, -0.04, 0.0)))
    parts.append(P._finish_obj(puddle, PUDDLE, var=0.08, ao=0.0, top=0.0, seed=5))
    for i in range(5):                               # spade-cut sods of clay on the far rim (flat faces)
        a = math.radians(40 + i * 25)
        b = L.prim("cube", loc=(math.cos(a) * 0.78, math.sin(a) * 0.62, 0.12), scale=(0.12, 0.06, 0.07),
                   rot=(0, 0, math.degrees(a) + 90))
        L.jitter(b, 0.006, 6.0, 10 + i)
        parts.append(P._finish_obj(b, L.mix(CLAY, CLAY_WET, 0.2), var=0.15, ao=0.2, top=0.25, seed=10 + i))
    heap = L.prim("ico", loc=(1.0, 0.3, 0.0), radius=1.0, subdivisions=2, scale=(0.36, 0.3, 0.26))
    L.jitter(heap, 0.04, 6.0, 20)
    parts.append(P._finish_obj(heap, CLAY, var=0.25, ao=0.35, top=0.2, hue_shift=CLAY_WET, seed=20))
    for i in range(5):
        parts.append(L.part("ico", L.scale_c(CLAY, rnd.uniform(0.85, 1.1)),
                            loc=(0.9 + rnd.uniform(-0.3, 0.3), 0.0 + rnd.uniform(-0.4, 0.3), 0.03), radius=0.05,
                            subdivisions=1, jit=0.01, seed=21 + i, paint_kw={"ao": 0.2}))
    parts.append(P._stick((-0.95, 0.35, 0.0), (-0.75, 0.55, 0.95), 0.018, P.WOOD, verts=5, seed=25, ao=0.1))   # a spade
    parts.append(L.part("cube", P.IRON, loc=(-0.97, 0.33, 0.1), scale=(0.08, 0.012, 0.11), rot=(0, 12, 45),
                        paint_kw={"hue_shift": P.RUST}))
    parts.append(E._blades([((-0.9, 0.5), 6, (0.1, 0.22), 0.012, 0.05), ((0.2, 0.9), 5, (0.1, 0.2), 0.012, 0.05),
                            ((-0.6, -0.8), 5, (0.1, 0.2), 0.012, 0.05)], E.GRASS_TINT, 30))
    obj = L.join(parts, "ph_env_clay_pit")
    P._center_xy(obj)
    L.finish(obj, "ph_env_clay_pit", "environment", 45, shift=False)


# --- quarry walls -----------------------------------------------------------------------------

def _strata(co, seed: int):
    """Painted bedding: horizontal bands of grey-blue, warm grey and ochre, cracks, moss on ledges."""
    z = co.z + 0.25 * noise.noise(Vector((co.x * 0.3, seed, 0)))
    b = math.sin(z * 4.2) * 0.5 + 0.5
    band = int((z + 10.0) * 2.1) % 4
    c = L.mix((STONE, STONE_MID, STONE_WARM, STONE_OCHRE)[band], STONE, 0.3)
    c = L.scale_c(c, 0.86 + 0.16 * b + 0.1 * noise.noise(co * 2.5))
    if abs(noise.noise(Vector((co.x * 1.4, co.z * 0.4, seed)))) < 0.035:       # vertical cracks
        c = L.scale_c(c, 0.62)
    return c


def _hash(i: int, j: int, seed: int) -> float:
    return noise.noise(Vector((i * 1.618 + 0.5, j * 2.414 + 0.5, seed * 0.77 + 0.5)))


def _wall(width: float, height: float, nx: int, nz: int, seed: int, taper_ends: bool, top_depth: float = 1.4):
    """Quarry face (front at y ~ 0): three benches stepping back, each broken into blocks along
    vertical joints, a ragged top edge, a grassy lip running back over the top.
    Returns (object, top(x) -> (y, z) of the lip's front edge)."""
    bm = bmesh.new()
    rows = []
    benches = 3
    heights = []
    for i in range(nx + 1):
        u = i / nx
        x = (u - 0.5) * width
        end = min(1.0, 0.5 + 1.6 * min(u, 1.0 - u)) if taper_ends else 1.0
        col = math.floor((x + 0.35 * noise.noise(Vector((x * 0.3, seed, 7.0)))) / 1.15)
        notch = 0.28 if _hash(col, 9, seed) > 0.25 else 0.0
        heights.append(height * end * (1.0 + 0.08 * noise.noise(Vector((x * 0.45, seed, 1.0)))) - notch * end)
    for k in range(nz + 1):
        t = k / nz
        row = []
        for i in range(nx + 1):
            x = (i / nx - 0.5) * width
            z = t * heights[i]
            bench = min(benches - 1, int(t * benches + 0.15 * noise.noise(Vector((x * 0.6, seed, 2.0)))))
            col = math.floor((x + 0.35 * noise.noise(Vector((x * 0.3, seed, 7.0 + bench)))) / 1.15)
            y = -0.55 + 0.32 * bench + 0.24 * _hash(col, bench, seed) \
                + 0.07 * noise.noise(Vector((x * 2.5, z * 2.5, seed + 5))) + 0.05 * t
            if k == 0:
                y -= 0.12
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    top = []
    for j in range(1, 4):                                # the lip: back over the top
        s = j / 3
        row = []
        for i in range(nx + 1):
            v = rows[-1][i].co
            row.append(bm.verts.new((v.x, v.y + 0.08 + top_depth * s, v.z + 0.1 * math.sin(s * math.pi) - 0.05 * s
                                     + 0.05 * noise.noise(Vector((v.x, s * 3, seed))))))
        top.append(row)
    back = [bm.verts.new((rows[-1][i].co.x, top[-1][i].co.y, -0.2)) for i in range(nx + 1)]
    grid = rows + top + [back]
    for a, b in zip(grid, grid[1:]):
        for i in range(nx):
            bm.faces.new((a[i], a[i + 1], b[i + 1], b[i]))
    for side in (0, nx):                                # close the two ends
        c = [g[side] for g in grid]
        bm.faces.new(c if side == nx else list(reversed(c)))
    lip = [(rows[-1][i].co.x, top[0][i].co.y, top[0][i].co.z) for i in range(nx + 1)]
    o = P._link(bm, "wall")
    n_face = (nz + 1) * (nx + 1)

    def col(co, vi):
        if vi < n_face:
            return _strata(co, seed)
        return L.mix(GRASS, EARTH, 0.25 + 0.3 * noise.noise(co * 2.0)) if vi < n_face + 3 * (nx + 1) else EARTH_DARK
    P._paint_fn(o, col)
    P._tint_up(o, MOSS, 0.9, 0.35, freq=1.5, seed=seed)
    L.set_mat(o, L.MAT_PAINTED)

    def top_at(x: float):
        i = min(nx, max(0, round((x / width + 0.5) * nx)))
        return lip[i][1], lip[i][2]
    return o, top_at


def _talus(parts, width: float, n: int, seed: int) -> None:
    rnd = random.Random(seed)
    for i in range(n):
        x = rnd.uniform(-width / 2, width / 2)
        s = rnd.uniform(0.12, 0.3)
        parts.append(_rock((x, -0.85 - rnd.uniform(0.0, 0.4), s * 0.45), (s * 1.3, s, s * 0.8), seed + i, subdiv=1,
                           color=L.mix(STONE, STONE_WARM, rnd.random()), moss=0.4, angular=0.5))


def quarry_face():
    """Bruchkante: a 9 m quarry face, ~3.6 m high, three benches of jointed blocks with painted
    bedding, moss on the ledges, a grassy lip with a few bushes, loose talus at the foot."""
    L.reset(2500)
    wall, top_at = _wall(9.0, 3.6, 36, 15, 1, False)
    parts = [wall]
    _talus(parts, 8.4, 14, 20)
    for k, x in enumerate((-3.3, -0.4, 1.6, 3.9)):
        y, z = top_at(x)
        parts.append(E._clump((x, y + 0.45, z + 0.05), 0.42, L.mix(P.LEAF_A, P.LEAF_B, 0.2 + 0.2 * k), 50 + k,
                              subdiv=2, scale=(1.25, 1.0, 0.6), zr=(z - 0.3, z + 0.5)))
    obj = L.join(parts, "ph_env_quarry_face")
    P._center_xy(obj)
    L.finish(obj, "ph_env_quarry_face", "environment", 40, shift=False)


def quarry_edge():
    """Kantenstuck: 3 m of the same face, lower towards both ends so pieces chain round a corner."""
    L.reset(2510)
    wall, top_at = _wall(3.0, 3.0, 12, 12, 7, True, top_depth=1.2)
    parts = [wall]
    _talus(parts, 2.6, 5, 30)
    y, z = top_at(0.3)
    parts.append(E._clump((0.3, y + 0.4, z + 0.05), 0.36, L.mix(P.LEAF_A, P.LEAF_B, 0.3), 60, subdiv=2,
                          scale=(1.2, 1.0, 0.6), zr=(z - 0.3, z + 0.5)))
    obj = L.join(parts, "ph_env_quarry_edge")
    P._center_xy(obj)
    L.finish(obj, "ph_env_quarry_edge", "environment", 40, shift=False)


# --- quarry gather spots ------------------------------------------------------------------------

def _veins(obj, strength: float, seed: int) -> None:
    """Rust-brown ore veins as painted streaks across the rock."""
    me = obj.data
    attr = me.color_attributes["Col"]
    lin = [L._to_lin(c) for c in RUST_VEIN]
    lin2 = [L._to_lin(c) for c in RUST_DARK]
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            v = abs(math.sin(co.x * 5.0 + co.z * 3.0 + 2.0 * noise.noise(co * 1.8 + Vector((seed, 0, 0)))))
            t = strength * max(0.0, 1.0 - v / 0.35)
            tgt = lin if noise.noise(co * 6.0) > -0.1 else lin2
            c = attr.data[li].color
            attr.data[li].color = tuple(c[k] + (tgt[k] - c[k]) * t for k in range(3)) + (1.0,)


def _ore(name: str, mined: bool) -> None:
    L.reset(2600)
    parts = [_rock((0.0, 0.0, 0.42), (0.62, 0.42, 0.5), 1, color=STONE_MID, moss=0.35, angular=0.55, subdiv=3),
             _rock((0.42, -0.12, 0.2), (0.3, 0.26, 0.24), 2, color=STONE_WARM, moss=0.3, subdiv=1, angular=0.6),
             _rock((-0.45, 0.1, 0.18), (0.26, 0.24, 0.2), 3, color=STONE_MID, moss=0.4, subdiv=1, angular=0.6)]
    for i, o in enumerate(parts):
        _veins(o, 0.35 if mined else 0.95, i)
    if mined:
        # hacked-out grooves: darker, fresh broken patches and rubble with a few rusty lumps
        for i, (x, z) in enumerate(((-0.1, 0.55), (0.2, 0.35), (-0.3, 0.3))):
            parts.append(L.part("cube", L.mix(STONE_DARK, RUST_DARK, 0.4), loc=(x, -0.36, z), scale=(0.14, 0.05, 0.06),
                                rot=(0, 20 - i * 15, 0), paint_kw={"ao": 0.0}))
    rnd = random.Random(2601)
    for i in range(5 if mined else 3):
        s = rnd.uniform(0.05, 0.09)
        parts.append(_rock((rnd.uniform(-0.6, 0.6), -0.45 - rnd.uniform(0, 0.2), s * 0.5), (s, s * 0.8, s * 0.7), 10 + i,
                           subdiv=1, color=RUST_VEIN if i % 2 == 0 else STONE_FRESH, moss=0.0, angular=0.6))
    obj = L.join(parts, name)
    P._center_xy(obj)
    L.finish(obj, name, "environment", 35, shift=False)


def ore_vein():
    """Erzader: a rock outcrop (1.2 m) with rust-brown veins running through it."""
    _ore("ph_env_ore_vein", False)


def ore_vein_empty():
    """Mined out: the veins hacked away, grooves and loose chips, only traces of rust left."""
    _ore("ph_env_ore_vein_empty", True)


def _ledge(name: str, taken: bool) -> None:
    """Werksteinbank: squared bedrock ledge 1.6 x 0.9 x 0.7 m with clean bedding; a block marked
    off by a row of wedge holes; taken = the block is gone (stepped cut, chips)."""
    L.reset(2700)
    parts = []
    base = L.prim("cube", loc=(0, 0.1, 0.2), scale=(0.8, 0.45, 0.2))
    L.subdivide(base, 2)
    L.jitter(base, 0.02, 3.0, 1)
    L.paint(base, STONE, var=0.18, ao=0.35, top=0.12, zrange=(0, 0.7), hue_shift=STONE_DARK, seed=1)
    P._tint_up(base, MOSS, 0.5, 0.5, seed=1)
    L.set_mat(base, L.MAT_PAINTED)
    parts.append(base)
    back = L.prim("cube", loc=(0.3, 0.3, 0.55), scale=(0.5, 0.25, 0.16))
    L.subdivide(back, 1)
    L.jitter(back, 0.02, 3.0, 2)
    L.paint(back, STONE_MID, var=0.2, ao=0.3, zrange=(0, 0.75), hue_shift=STONE_DARK, seed=2)
    P._tint_up(back, MOSS, 0.7, 0.4, seed=2)
    L.set_mat(back, L.MAT_PAINTED)
    parts.append(back)
    if not taken:
        blk = L.prim("cube", loc=(-0.38, -0.05, 0.54), scale=(0.34, 0.26, 0.14))
        L.bevel(blk, 0.01, 1)
        L.jitter(blk, 0.006, 4.0, 3)
        L.paint(blk, L.mix(STONE, STONE_WARM, 0.3), var=0.15, ao=0.2, top=0.15, zrange=(0.4, 0.7), seed=3)
        P._tint_up(blk, MOSS, 0.3, 0.6, seed=3)
        L.set_mat(blk, L.MAT_PAINTED)
        parts.append(blk)
        for k in range(5):            # wedge holes along the split line on the top and the front
            parts.append(L.part("cube", L.hexc("#26282C"), loc=(-0.66 + k * 0.14, -0.05 + 0.2, 0.682),
                                scale=(0.022, 0.012, 0.006), paint_kw={"ao": 0.0}))
        for k in range(3):
            parts.append(L.part("cube", L.hexc("#26282C"), loc=(-0.04, -0.28 + k * 0.1 + 0.08, 0.682),
                                scale=(0.012, 0.022, 0.006), paint_kw={"ao": 0.0}))
        for k in range(2):            # two iron wedges still in
            parts.append(L.part("cone", P.IRON, loc=(-0.52 + k * 0.28, 0.15, 0.71), radius1=0.02, depth=0.06,
                                vertices=4, rot=(0, 0, 45), paint_kw={"hue_shift": P.RUST, "top": 0.4}))
    else:
        # the fresh, light bed where the block was split off, a half wedge hole row on the edge
        bed = L.prim("cube", loc=(-0.38, -0.05, 0.402), scale=(0.33, 0.25, 0.004))
        parts.append(P._finish_obj(bed, STONE_FRESH, var=0.12, ao=0.0, top=0.2, seed=4))
        for k in range(5):
            parts.append(L.part("cube", L.hexc("#3A3C40"), loc=(-0.66 + k * 0.14, 0.2, 0.41),
                                scale=(0.02, 0.006, 0.02), paint_kw={"ao": 0.0}))
    rnd = random.Random(2701)
    for i in range(6):
        s = rnd.uniform(0.04, 0.08)
        parts.append(_rock((rnd.uniform(-0.8, 0.8), -0.45 - rnd.uniform(0, 0.25), s * 0.4), (s, s * 0.8, s * 0.6), 20 + i,
                           subdiv=1, color=STONE_FRESH, moss=0.0, angular=0.7))
    obj = L.join(parts, name)
    P._center_xy(obj)
    L.finish(obj, name, "environment", 35, shift=False)


def workstone_ledge():
    _ledge("ph_env_workstone_ledge", False)


def workstone_ledge_empty():
    _ledge("ph_env_workstone_ledge_empty", True)


def rubble_face():
    """Bruchsteinwand: a shattered, fissured wall piece (1.8 x 1.3 m) with a heap of broken rubble."""
    L.reset(2800)
    parts = [_rock((0.0, 0.25, 0.6), (0.9, 0.35, 0.66), 1, color=STONE_MID, moss=0.5, angular=0.7),
             _rock((-0.55, 0.3, 0.35), (0.4, 0.3, 0.4), 2, color=STONE_WARM, moss=0.5, subdiv=1, angular=0.7)]
    rnd = random.Random(2801)
    for i in range(9):
        s = rnd.uniform(0.09, 0.2)
        parts.append(_rock((rnd.uniform(-0.7, 0.8), -0.2 - rnd.uniform(0, 0.35), s * 0.5 + (0.08 if i < 3 else 0.0)),
                           (s * 1.2, s, s * 0.75), 10 + i, subdiv=1,
                           color=L.mix(STONE, STONE_FRESH, rnd.random() * 0.6), moss=0.15, angular=0.7))
    obj = L.join(parts, "ph_env_rubble_face")
    P._center_xy(obj)
    L.finish(obj, "ph_env_rubble_face", "environment", 35, shift=False)


def boulder():
    """Findling: a big, rounded erratic, 2.0 m across and 1.6 m high, thick moss on top, grass round
    its foot, a smaller companion stone."""
    L.reset(2900)
    b = _rock((0.0, 0.0, 0.72), (1.0, 0.85, 0.9), 1, color=L.mix(STONE, STONE_WARM, 0.3), moss=0.0, angular=0.15,
              subdiv=3)
    P._tint_up(b, MOSS, 1.0, 0.1, freq=1.8, seed=1)
    P._tint_up(b, MOSS_LIGHT, 0.5, 0.6, freq=3.0, seed=2)
    parts = [b, _rock((0.85, -0.55, 0.14), (0.24, 0.2, 0.18), 3, subdiv=1, moss=0.7, angular=0.3)]
    parts.append(E._blades([((math.cos(a) * 0.95, math.sin(a) * 0.82), 5, (0.12, 0.3), 0.014, 0.1)
                            for a in (i / 9 * math.tau for i in range(9))], E.GRASS_TINT, 10))
    obj = L.join(parts, "ph_env_boulder")
    P._center_xy(obj)
    L.finish(obj, "ph_env_boulder", "environment", 40, shift=False)


def boulder_broken():
    """The erratic broken with the pick: four mossy chunks with light fresh fracture faces, grit."""
    L.reset(2910)
    parts = []
    rnd = random.Random(2911)
    for i, (x, y, s) in enumerate(((-0.45, 0.1, 0.42), (0.35, 0.2, 0.36), (0.05, -0.45, 0.3), (0.62, -0.42, 0.2))):
        r = _rock((x, y, s * 0.55), (s * 1.2, s, s * 0.9), 10 + i, subdiv=1, color=L.mix(STONE, STONE_WARM, 0.3),
                  moss=0.0, angular=0.6)
        # fresh fracture: faces pointing to the old centre are light and clean, the rest mossy
        me = r.data
        attr = me.color_attributes["Col"]
        lf = [L._to_lin(c) for c in STONE_FRESH]
        lm = [L._to_lin(c) for c in MOSS]
        for poly in me.polygons:
            inward = -poly.normal.dot(Vector((x, y, 0)).normalized())
            for li in poly.loop_indices:
                c = attr.data[li].color
                if inward > 0.3:
                    tgt, t = lf, 0.8
                elif poly.normal.z > 0.4:
                    tgt, t = lm, 0.7
                else:
                    continue
                attr.data[li].color = tuple(c[k] + (tgt[k] - c[k]) * t for k in range(3)) + (1.0,)
        parts.append(r)
    for i in range(6):
        s = rnd.uniform(0.04, 0.08)
        parts.append(_rock((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.7, 0.6), s * 0.4), (s, s, s * 0.6), 30 + i,
                           subdiv=1, color=STONE_FRESH, moss=0.0, angular=0.7))
    obj = L.join(parts, "ph_env_boulder_broken")
    P._center_xy(obj)
    L.finish(obj, "ph_env_boulder_broken", "environment", 40, shift=False)


# --- herbs ------------------------------------------------------------------------------------

def herb_patch():
    """Kräuterrain (~0.9 m): tansy stalks with flat clusters of golden button flowers over dark,
    feathery leaves, beside tall grey-green mugwort."""
    L.reset(3000)
    rnd = random.Random(3001)
    parts = []
    for i, (x, y) in enumerate(((-0.15, 0.05), (0.1, -0.1), (0.0, 0.2), (-0.3, -0.15), (0.25, 0.15))):
        h = rnd.uniform(0.55, 0.8)
        top = Vector((x + rnd.uniform(-0.05, 0.05), y + rnd.uniform(-0.05, 0.05), h))
        parts.append(P._stick((x, y, 0.0), top, 0.008, TANSY_LEAF, r1=0.005, verts=3, seed=i, ao=0.2))
        for k in range(4):                        # the flat button cluster
            a = k / 4 * math.tau
            parts.append(L.part("cyl", L.scale_c(TANSY, rnd.uniform(0.9, 1.08)),
                                loc=top + Vector((math.cos(a) * 0.035, math.sin(a) * 0.035, 0.006 * (k % 2))),
                                radius=0.02, depth=0.012, vertices=5, paint_kw={"ao": 0.0, "top": 0.3}))
    parts.append(E._clump((-0.05, 0.02, 0.22), 0.28, TANSY_LEAF, 20, subdiv=2, scale=(1.3, 1.1, 0.8), zr=(0.0, 0.6)))
    for i, (x, y) in enumerate(((0.35, -0.25), (0.42, 0.05), (-0.42, 0.22))):   # mugwort: tall, grey-green
        h = rnd.uniform(0.75, 0.95)
        parts.append(P._stick((x, y, 0.0), (x + 0.04, y, h), 0.009, L.hexc("#6E5A4A"), r1=0.005, verts=3, seed=30 + i,
                              ao=0.2))
        parts.append(E._clump((x + 0.02, y + 0.02, h * 0.62), 0.13, MUGWORT, 30 + i, subdiv=2, scale=(1.1, 1.1, 1.7),
                              zr=(0.0, 1.0), hue=L.hexc("#8A9474")))
    parts.append(E._blades([((0.0, 0.0), 10, (0.15, 0.3), 0.014, 0.14), ((0.3, -0.3), 5, (0.1, 0.25), 0.012, 0.08)],
                           E.GRASS_TINT, 40))
    obj = L.join(parts, "ph_env_herb_patch")
    P._center_xy(obj)
    L.finish(obj, "ph_env_herb_patch", "environment", 45, shift=False)


def herb_patch_cut():
    """Cut back: short stubble of stalks, low leaf rosettes, two forgotten yellow buttons."""
    L.reset(3010)
    parts = [E._blades([((0.0, 0.0), 12, (0.05, 0.12), 0.01, 0.02), ((0.3, -0.2), 6, (0.04, 0.1), 0.01, 0.02)],
                       STUBBLE, 1, zr=(0.0, 0.15))]
    parts.append(E._rosette(-0.2, 0.1, 5, 0.12, 0.03, TANSY_LEAF, 2))
    for k in range(2):
        parts.append(L.part("cyl", TANSY, loc=(0.1 + k * 0.05, 0.1, 0.1), radius=0.018, depth=0.012, vertices=6,
                            paint_kw={"ao": 0.0}))
    obj = L.join(parts, "ph_env_herb_patch_cut")
    P._center_xy(obj)
    L.finish(obj, "ph_env_herb_patch_cut", "environment", 45, shift=False)


ASSETS = (alder_coppice, alder_stump, alder_sapling, flax_bed, flax_bed_empty, clay_pit, quarry_face, quarry_edge,
          ore_vein, ore_vein_empty, workstone_ledge, workstone_ledge_empty, rubble_face, boulder, boulder_broken,
          herb_patch, herb_patch_cut)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
