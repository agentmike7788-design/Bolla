"""Phase-3 environment (contract docs/PHASE3_DESIGN.md section 8), 'Gemaltes Diorama' style.

Obstacles of the new sections: bramble thicket, tree stump, thorn hedge.  Tending spots:
weeds in three stages (sprouts -> tufts -> wild thistles and dandelions) and leaf litter in
three amounts.  The slender birch of the Birkenhang.
Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m, shared materials only:
leaf masses use mat_foliage (wind, leafy edges), grass-like blades use mat_grass (wind, lit
like the ground), everything else mat_painted.

Run:  python tools/blender/build_all.py asset_env_phase3
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
from asset_environment import _limb as limb  # same gnarled limbs as the approved oak

BARK = P.BARK
BARK_DARK = P.BARK_DARK
MOSS = P.MOSS
EARTH = P.EARTH
END_GRAIN = P.END_GRAIN
WOOD_OLD = P.WOOD_OLD
LEAF_A = P.LEAF_A
LEAF_B = P.LEAF_B
GRASS_TINT = L.hexc("#849355")      # the approved grass tuft colour
GRASS_DRY = L.hexc("#7D7D4E")
SPROUT = L.hexc("#8FA05A")
WEED_LEAF = L.hexc("#6C7F45")
# QA readability (W3): weeds read against the lawn through value contrast - brighter, yellower
# sprouts, dark rank rosettes, dry straw / rust seed stalks and bare soil under them.
SPROUT_BRIGHT = L.hexc("#A9B65B")
WEED_DARK = L.hexc("#4A5B31")
STRAW = L.hexc("#B89E5B")
DOCK_RUST = L.hexc("#8C5734")
BRAMBLE_CANE = L.hexc("#5E3F3A")
BRAMBLE_LEAF = L.hexc("#3F5234")
BERRY = L.hexc("#2E2430")
BERRY_RED = L.hexc("#7A302B")       # unripe: the only red, used sparingly
THORN_LEAF = L.hexc("#394A31")
THORN_WOOD = L.hexc("#3A302C")
SLOE = L.hexc("#3D3A4A")
THISTLE = L.hexc("#8E6A8C")         # muted purple, never a cold saturated blue
DANDELION = L.hexc("#D9A63A")
PUFF = L.hexc("#DCD8CC")
BIRCH_BARK = L.hexc("#CFCABB")
BIRCH_MARK = L.hexc("#3A3530")
BIRCH_LEAF_A = L.hexc("#6B7F44")
BIRCH_LEAF_B = L.hexc("#8C9A52")
LITTER = [L.hexc("#B08A4A"), L.hexc("#8C6A40"), L.hexc("#7A5A3A"), L.hexc("#9A6A3C"), L.hexc("#A89048"),
          L.hexc("#6A5236"), L.hexc("#C8923E"), L.hexc("#B0612F")]   # + bright ochre, rust (QA readability)
MULCH_CORE = L.hexc("#4A3727")
SOIL_CORE = L.mix(EARTH, P.EARTH_FRESH, 0.55)
SOIL_EDGE = L.mix(GRASS_TINT, EARTH, 0.35)


# --- helpers ---------------------------------------------------------------------

def _clump(loc, r: float, color, seed: int, subdiv: int = 2, scale=(1.0, 1.0, 0.8), zr=(0.0, 1.5),
           hue=None, jit: float = 0.3):
    """Leaf mass in mat_foliage (the approved bush/oak recipe)."""
    s = L.prim("ico", loc=loc, radius=r, subdivisions=subdiv, scale=scale)
    L.jitter(s, r * jit, 0.9 / r, seed)
    L.jitter(s, r * 0.1, 2.8 / r, seed + 50)
    L.paint(s, color, var=0.35, ao=0.6, top=0.35, zrange=zr, seed=seed, hue_shift=hue)
    L.set_mat(s, L.MAT_FOLIAGE)
    return s


def _cane(points, r0: float, r1: float, color, seed: int, sides: int = 4, zr=(0.0, 1.2), mat: str = L.MAT_PAINTED):
    """Tapered closed tube along a polyline (canes, stems, twigs)."""
    n = len(points)
    radii = [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]
    o = P._tube(points, radii, sides=sides, hint=(0.3, 0.2, 1.0), caps=(False, True))
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    L.paint(o, color, var=0.2, ao=0.4, zrange=zr, seed=seed)
    L.set_mat(o, mat)
    return o


def _arc(p0, p1, height: float, n: int = 7, wobble: float = 0.03, seed: int = 0):
    """Points of an arching cane from p0 to p1 (both on the ground) peaking at `height`."""
    p0, p1 = Vector(p0), Vector(p1)
    out = []
    for i in range(n):
        t = i / (n - 1)
        p = p0.lerp(p1, t)
        p.z += height * math.sin(math.pi * t ** 0.8)
        p += Vector((noise.noise(Vector((t * 3, seed, 1))), noise.noise(Vector((seed, t * 3, 2))), 0)) * wobble
        out.append(p)
    return out


def _blade(bm, base, direction, height: float, width: float, lean: float, segs: int = 2):
    """One grass-like blade (open strip, 2 tris per segment) into an existing bmesh."""
    d = Vector(direction).normalized()
    side = Vector((-d.y, d.x, 0.0))
    rows = []
    for k in range(segs + 1):
        t = k / segs
        c = Vector(base) + d * (lean * t * t) + Vector((0, 0, height * t))
        w = width * (1.0 - t) + 0.002
        rows.append((bm.verts.new(c - side * w), bm.verts.new(c + side * w)))
    for k in range(segs):
        bm.faces.new((rows[k][0], rows[k][1], rows[k + 1][1], rows[k + 1][0]))


def _blades(tufts, color, seed: int, zr=(0.0, 0.4), hue=GRASS_DRY):
    """Grass-like tufts in mat_grass: tufts = [(centre, count, (hmin, hmax), width, lean)]."""
    bm = bmesh.new()
    for (cx, cy), count, (h0, h1), w, lean in tufts:
        for i in range(count):
            a = i / count * math.tau + random.uniform(-0.4, 0.4)
            base = (cx + math.cos(a) * 0.015, cy + math.sin(a) * 0.015, 0.0)
            _blade(bm, base, (math.cos(a), math.sin(a), 0), random.uniform(h0, h1), w, lean * random.uniform(0.6, 1.2))
    o = P._raw(bm, "blades")
    L.paint(o, color, var=0.18, ao=0.4, top=0.0, zrange=zr, hue_shift=hue, seed=seed)
    L.set_mat(o, L.MAT_GRASS)
    return o


def _rosette(cx: float, cy: float, n: int, length: float, width: float, color, seed: int, lift: float = 0.01,
             serrate: bool = False, mat: str = L.MAT_GRASS):
    """Flat weed rosette (dandelion / plantain / thistle base): n leaves radiating on the ground,
    4 tris each (serrate: 6-vertex jagged outline)."""
    bm = bmesh.new()
    for i in range(n):
        a = i / n * math.tau + random.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        s = Vector((-d.y, d.x, 0.0))
        ln = length * random.uniform(0.75, 1.15)
        c = Vector((cx, cy, lift))
        k = 1.25 if serrate else 1.0
        pts = [c, c + d * ln * 0.3 + s * width * k, c + d * ln * 0.62 + s * width * 0.8,
               c + d * ln + Vector((0, 0, ln * 0.18)), c + d * ln * 0.62 - s * width * 0.8,
               c + d * ln * 0.3 - s * width * k]
        vs = [bm.verts.new(p + Vector((0, 0, 0.012 * (j % 3 != 0)))) for j, p in enumerate(pts)]
        for j in range(1, 5):
            if mat == L.MAT_GRASS:                                 # two-sided grass material
                bm.faces.new((vs[0], vs[j], vs[j + 1]))
            else:                                                  # cull_back: wind to face up
                bm.faces.new((vs[0], vs[j + 1], vs[j]))
    o = P._raw(bm, "rosette")
    L.paint(o, color, var=0.2, ao=0.25, top=0.0, zrange=(0.0, 0.15), hue_shift=GRASS_DRY if mat == L.MAT_GRASS else None,
            seed=seed)
    L.set_mat(o, mat)
    return o


# --- obstacles ----------------------------------------------------------------------

def bramble():
    """Blackberry thicket (~2 x 2 x 1.2 m): a dark, lumpy leafy mound with thorny canes that
    rise out of it and arch down into the grass, a few clusters of black (some unripe red) berries."""
    L.reset(600)
    parts = []
    rnd = random.Random(601)
    mound = [((0.0, 0.0, 0.55), 0.4), ((-0.18, 0.15, 0.78), 0.26), ((0.2, -0.1, 0.8), 0.24)]
    for i in range(10):                                             # lumpy ring around the core
        a = i / 10 * math.tau + rnd.uniform(-0.2, 0.2)
        d = rnd.uniform(0.38, 0.62)
        z = 0.5 - d * 0.45 + rnd.uniform(-0.05, 0.08)
        mound.append(((math.cos(a) * d, math.sin(a) * d, z), rnd.uniform(0.24, 0.32)))
    for i, (c, r) in enumerate(mound):
        shade = rnd.random()
        parts.append(_clump(c, r, L.scale_c(L.mix(BRAMBLE_LEAF, LEAF_B, shade * 0.4), 0.85), 10 + i,
                            scale=(1.15, 1.05, 0.75), zr=(0.0, 1.25), jit=0.38,
                            hue=L.hexc("#5A5A3A") if shade > 0.75 else None))
    for i in range(11):                                             # canes: up over the mound, down into the grass
        a = i / 11 * math.tau + rnd.uniform(-0.2, 0.2)
        r0 = rnd.uniform(0.05, 0.25)
        r1 = rnd.uniform(0.9, 1.0)
        z0 = rnd.uniform(0.5, 0.7)
        peak = rnd.uniform(0.95, 1.18) if i % 3 else rnd.uniform(0.75, 0.9)
        pts = []
        for k in range(8):
            t = k / 7
            rr = r0 + (r1 - r0) * t ** 1.3
            if t < 0.3:
                z = z0 + (peak - z0) * math.sin(t / 0.3 * math.pi / 2)
            else:
                z = peak * math.cos((t - 0.3) / 0.7 * math.pi / 2) ** 1.3
            aa = a + noise.noise(Vector((t * 2, i, 3))) * 0.25
            pts.append(Vector((math.cos(aa) * rr, math.sin(aa) * rr, max(0.01, z))))
        parts.append(_cane(pts, 0.016, 0.008, L.scale_c(BRAMBLE_CANE, rnd.uniform(0.85, 1.1)), 30 + i))
        parts.append(L.part("cone", L.hexc("#8A6A50"), loc=pts[3] + Vector((0, 0, 0.02)), radius1=0.008,
                            depth=0.032, vertices=3, end_fill_type="NOTHING", paint_kw={"ao": 0.0}))  # a thorn
        for k in (2, 5):                                            # leaves along the cane hide most of it
            parts.append(_clump(pts[k] + Vector((0, 0, 0.03)), rnd.uniform(0.11, 0.14),
                                L.scale_c(L.mix(BRAMBLE_LEAF, LEAF_B, rnd.random() * 0.3), 0.9), 80 + i * 2 + k,
                                subdiv=1, scale=(1.3, 1.1, 0.6), zr=(0.0, 1.25)))
    for i in range(5):                                              # berry clusters on the surface
        a = i / 5 * math.tau + 0.4
        d = rnd.uniform(0.35, 0.6)
        base = Vector((math.cos(a) * d, math.sin(a) * d, 0.72 - d * 0.6))
        n = base.normalized()
        for k in range(3):
            col = BERRY_RED if (i % 3 == 0 and k == 0) else BERRY
            off = Vector((rnd.uniform(-0.035, 0.035), rnd.uniform(-0.035, 0.035), rnd.uniform(-0.02, 0.02)))
            parts.append(L.part("ico", col, loc=base + n * 0.16 + off, radius=0.024, subdivisions=1,
                                paint_kw={"ao": 0.1, "var": 0.15, "top": 0.4}))
    obj = L.join(parts, "ph_env_bramble")
    P._center_xy(obj)
    L.finish(obj, "ph_env_bramble", "environment", 50)


def stump():
    """Old sawn tree stump (~0.8 m wide, 0.5 m high): flared, mossy bark, weathered grey end
    grain with rings and a crack, roots diving into the ground, a few bracket fungi."""
    L.reset(610)
    bm = bmesh.new()
    verts, top = 14, 0.5
    rings = []
    for k, (z, r) in enumerate(((-0.06, 0.46), (0.05, 0.4), (0.14, 0.34), (0.26, 0.31), (0.38, 0.3), (top, 0.3))):
        ring = []
        for j in range(verts):
            a = j / verts * math.tau
            f = 1.0 + noise.noise(Vector((math.cos(a) * 1.6, math.sin(a) * 1.6, z * 3.0 + 1.0))) * 0.14
            f *= 1.05 if j % 2 else 0.96
            zz = z + (noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, 5.0))) * 0.03 if k == 5 else 0.0)
            ring.append(bm.verts.new((math.cos(a) * r * f, math.sin(a) * r * f, zz)))
        rings.append(ring)
    grain = []                                                      # concentric rings on the cut
    for f in (0.88, 0.66, 0.44, 0.22):
        grain.append([bm.verts.new((v.co.x * f, v.co.y * f, top + 0.005 + (1 - f) * 0.004)) for v in rings[-1]])
    all_r = rings + grain
    for k in range(len(all_r) - 1):
        for j in range(verts):
            bm.faces.new((all_r[k][j], all_r[k][(j + 1) % verts], all_r[k + 1][(j + 1) % verts], all_r[k + 1][j]))
    c = bm.verts.new((0.0, 0.0, top + 0.008))
    for j in range(verts):
        bm.faces.new((grain[-1][j], grain[-1][(j + 1) % verts], c))
    body = P._link(bm, "stump")
    side = len(rings) * verts

    def col(co, vi):
        if vi >= side:                                              # end grain: weathered, grey, rings
            rr = math.hypot(co.x, co.y) / 0.3
            g = L.mix(END_GRAIN, WOOD_OLD, 0.55 + 0.3 * rr)
            g = L.scale_c(g, 0.85 + 0.15 * math.cos(rr * 14.0))
            crack = abs(co.y + co.x * 0.3) < 0.03 and co.x > -0.05
            return L.scale_c(g, 0.55) if crack else g
        h = max(0.0, min(1.0, (co.z + 0.06) / 0.6))
        b = L.scale_c(L.mix(BARK_DARK, BARK, 0.5 + 0.5 * noise.noise(co * 6.0)), 0.7 + 0.35 * h)
        m = max(0.0, noise.noise(co * 3.0 + Vector((3, 1, 2)))) * (1.0 - h) * 1.6
        return L.mix(b, MOSS, min(0.8, m))
    P._paint_fn(body, col)
    L.set_mat(body, L.MAT_PAINTED)
    parts = [body]
    for i in range(6):                                              # roots
        a = i / 6 * math.tau + random.uniform(-0.2, 0.2)
        root = limb((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.2), (math.cos(a), math.sin(a), -0.15),
                    random.uniform(0.36, 0.56), 0.14, 0.05, 20 + i, segs=4, verts=7, droop=0.5)
        L.paint(root, BARK, var=0.25, ao=0.5, zrange=(-0.1, 0.5), hue_shift=BARK_DARK, seed=20 + i)
        P._tint_up(root, L.mix(MOSS, LEAF_B, 0.3), 0.45, 0.45, seed=21 + i)
        L.set_mat(root, L.MAT_PAINTED)
        parts.append(root)
    for i, (a, z, r) in enumerate(((0.6, 0.3, 0.075), (0.9, 0.22, 0.06), (0.75, 0.13, 0.05))):  # bracket fungi
        fx, fy = math.cos(a) * 0.31, -math.sin(a) * 0.31
        f = L.prim("sphere", loc=(fx, fy, z), radius=r, segments=8, ring_count=4, scale=(1.0, 1.0, 0.3),
                   rot=(0, 0, -math.degrees(a)))
        parts.append(P._finish_obj(f, L.hexc("#B39A6E"), var=0.15, ao=0.3, top=0.3, zrange=(0.0, 0.5),
                                   hue_shift=L.hexc("#8A6A48"), seed=40 + i))
    obj = L.join(parts, "ph_env_stump")
    P._center_xy(obj)
    L.finish(obj, "ph_env_stump", "environment", 45, shift=False)


def hedge_thorn():
    """Thorn hedge (4 x 1 x 1.6 m, along X): a dense, irregular wall of dark blackthorn leaf
    masses on gnarled stems, bare thorny twigs poking out of the silhouette, a few dusky sloes."""
    L.reset(620)
    parts = []
    rnd = random.Random(621)
    for i in range(7):                                              # gnarled stems at the foot
        x = -1.7 + i * 0.57 + rnd.uniform(-0.1, 0.1)
        st = limb((x, rnd.uniform(-0.15, 0.15), -0.05), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.2), 1),
                  rnd.uniform(0.6, 0.8), 0.07, 0.03, 10 + i, segs=3, verts=5)
        L.paint(st, THORN_WOOD, var=0.25, ao=0.5, zrange=(0, 1.6), hue_shift=MOSS, seed=10 + i)
        L.set_mat(st, L.MAT_PAINTED)
        parts.append(st)
    masses = []
    for i in range(8):                                              # lower body: wide masses that merge
        x = -1.4 + i * 2.8 / 7 + rnd.uniform(-0.06, 0.06)
        masses.append(((x, rnd.uniform(-0.1, 0.1), rnd.uniform(0.45, 0.58)), rnd.uniform(0.4, 0.44),
                       (1.3, 0.95, 0.95)))
    for i in range(7):                                              # middle, offset
        x = -1.35 + i * 2.7 / 6 + rnd.uniform(-0.12, 0.12)
        masses.append(((x, rnd.uniform(-0.12, 0.12), rnd.uniform(0.85, 1.0)), rnd.uniform(0.3, 0.38),
                       (1.3, 0.9, 0.9)))
    for i in range(9):                                              # ragged top: few, varied heights
        x = -1.6 + i * 3.2 / 8 + rnd.uniform(-0.1, 0.1)
        if i % 4 == 3:
            continue                                                # dips in the silhouette
        masses.append(((x, rnd.uniform(-0.08, 0.08), rnd.uniform(1.1, 1.3)), rnd.uniform(0.18, 0.28),
                       (1.1, 0.9, 1.0)))
    for i, (c, r, sc) in enumerate(masses):
        shade = rnd.random()
        parts.append(_clump(c, r, L.scale_c(L.mix(THORN_LEAF, LEAF_A, shade * 0.5), 0.85), 30 + i,
                            scale=sc, zr=(0.0, 1.6), jit=0.42,
                            hue=L.hexc("#55603C") if shade > 0.8 else None))
    for i in range(18):                                             # bare thorny twigs out of the top and sides
        x = rnd.uniform(-1.6, 1.6)
        up = i % 3 != 0
        p0 = Vector((x, rnd.uniform(-0.2, 0.2), rnd.uniform(1.05, 1.2) if up else rnd.uniform(0.45, 0.95)))
        if up:
            d = Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.3), rnd.uniform(0.5, 0.9)))
        else:
            d = Vector((rnd.uniform(-0.4, 0.4), rnd.choice((-1, 1)) * rnd.uniform(0.4, 0.7), rnd.uniform(-0.1, 0.3)))
        d.normalize()
        ln = rnd.uniform(0.45, 0.62) if up else rnd.uniform(0.35, 0.5)
        if up:
            p0.z = min(p0.z, 1.58 - d.z * ln)
        pts = [p0, p0 + d * ln * 0.5 + Vector((0, 0, 0.02)), p0 + d * ln]
        parts.append(_cane(pts, 0.017, 0.005, THORN_WOOD, 60 + i, sides=4, zr=(0, 1.6)))
        for t in (0.5, 0.85):                                       # thorns
            p = pts[0].lerp(pts[2], t)
            parts.append(L.part("cone", THORN_WOOD, loc=p + Vector((0, 0, 0.02)), radius1=0.007, depth=0.035,
                                vertices=3, end_fill_type="NOTHING", rot=(rnd.uniform(-40, 40), 0, 0),
                                paint_kw={"ao": 0.0}))
    for i in range(9):                                              # sloes on the surface
        x = rnd.uniform(-1.7, 1.7)
        y = rnd.choice((-1, 1)) * rnd.uniform(0.4, 0.48)
        z = rnd.uniform(0.45, 1.0)
        parts.append(L.part("ico", SLOE, loc=(x, y, z), radius=0.028, subdivisions=1,
                            paint_kw={"ao": 0.0, "var": 0.15, "top": 0.5}))
    obj = L.join(parts, "ph_env_hedge_thorn")
    P._center_xy(obj)
    L.finish(obj, "ph_env_hedge_thorn", "environment", 50)


# --- tending spots ------------------------------------------------------------------

def _soil_patch(radius: float, core, edge, seed: int, segs: int = 16, lift: float = 0.006, squash: float = 0.86):
    """QA readability (W3): flat, irregular patch of trampled / bare soil under a weedy spot.
    Two vertex rings: the core colour in the middle, the edge colour (close to the grass) on the
    ragged outline, so the patch fades into the lawn instead of reading as a decal (mat_painted)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    centre = bm.verts.new((0.0, 0.0, lift + 0.004))
    inner, outer = [], []
    for i in range(segs):
        a = i / segs * math.tau
        r = radius * (0.78 + 0.34 * rnd.random())
        inner.append(bm.verts.new((math.cos(a) * r * 0.55, math.sin(a) * r * 0.55 * squash, lift + 0.003)))
        outer.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r * squash, lift)))
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((centre, inner[i], inner[j]))
        bm.faces.new((inner[i], outer[i], outer[j], inner[j]))
    o = P._raw(bm, "soil_patch")
    me = o.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            t = min(1.0, math.hypot(v.x, v.y / squash) / radius)
            c = L.mix(core, edge, t ** 1.6)
            f = 0.9 + 0.2 * noise.noise(Vector((v.x * 9.0 + seed, v.y * 9.0, 1.0)))
            attr.data[li].color = (*[L._to_lin(min(1.0, ch * f)) for ch in c], 1.0)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _stalk(parts, x: float, y: float, h: float, color, seed: int, head: float = 0.05):
    """QA readability (W3): a dry seed stalk (plantain / dock) – a thin cane with a spiky head
    that stands above the lawn and gives the spot a silhouette (mat_painted, lit on its own)."""
    top = Vector((x + random.uniform(-0.03, 0.03), y + random.uniform(-0.03, 0.03), h))
    parts.append(_cane([Vector((x, y, 0.0)), Vector((x, y, h * 0.5)), top], 0.006, 0.004, color, seed, sides=3,
                       zr=(0.0, h)))
    spike = L.prim("cone", loc=top + Vector((0, 0, head * 0.5)), radius1=0.014, depth=head, vertices=5)
    L.jitter(spike, 0.003, 50.0, seed)
    parts.append(P._finish_obj(spike, L.scale_c(color, 0.8), var=0.2, ao=0.2, top=0.2, seed=seed))


def _spots(n: int, radius: float, min_d: float, seed: int):
    """n points in a disc, roughly evenly spread (dart throwing)."""
    rnd = random.Random(seed)
    pts = []
    tries = 0
    while len(pts) < n and tries < 2000:
        tries += 1
        a, d = rnd.uniform(0, math.tau), radius * math.sqrt(rnd.random())
        p = (math.cos(a) * d, math.sin(a) * d)
        if all(math.hypot(p[0] - q[0], p[1] - q[1]) >= min_d for q in pts):
            pts.append(p)
    return pts


def _seedling(parts, x: float, y: float, h: float, seed: int):
    """Tiny two-leaved seedling: a stem and two small leaves (mat_grass)."""
    bm = bmesh.new()
    top = Vector((x, y, h))
    _blade(bm, (x, y, 0.0), (1, 0, 0), h, 0.004, 0.0, segs=1)
    a = random.uniform(0, math.pi)
    for s in (-1, 1):
        d = Vector((math.cos(a) * s, math.sin(a) * s, 0.25))
        side = Vector((-d.y, d.x, 0)).normalized()
        v0 = bm.verts.new(top)
        v1 = bm.verts.new(top + d * 0.03 + side * 0.012)
        v2 = bm.verts.new(top + d * 0.055)
        v3 = bm.verts.new(top + d * 0.03 - side * 0.012)
        bm.faces.new((v0, v1, v2, v3))
    o = P._raw(bm, "seedling")
    L.paint(o, SPROUT, var=0.15, ao=0.3, top=0.0, zrange=(0.0, 0.12), seed=seed)
    L.set_mat(o, L.MAT_GRASS)
    parts.append(o)


def _grow(obj, f: float) -> None:
    """Uniform scale about the pivot (QA readability: stages 2-3 slightly larger)."""
    for v in obj.data.vertices:
        v.co *= f


def weeds_1():
    """Stage 1 'sprießt': a few bright fresh sprouts and seedlings pushing through scuffed soil
    (~0.8 m patch) - visible, but still quiet."""
    L.reset(630)
    parts = [_soil_patch(0.27, L.mix(SOIL_CORE, SOIL_EDGE, 0.35), SOIL_EDGE, 632)]
    spots = _spots(9, 0.34, 0.14, 630)
    tufts = [(p, random.randint(3, 5), (0.07, 0.13), 0.012, 0.03) for p in spots[:6]]
    parts.append(_blades(tufts, SPROUT_BRIGHT, 1, zr=(0.0, 0.13), hue=None))
    for i, (x, y) in enumerate(spots[4:]):
        _seedling(parts, x, y, random.uniform(0.05, 0.08), 10 + i)
    for i, (x, y) in enumerate(_spots(5, 0.32, 0.18, 631)):
        parts.append(_rosette(x, y, 4, 0.085, 0.026, SPROUT_BRIGHT, 20 + i, lift=0.008, mat=L.MAT_PAINTED))
    obj = L.join(parts, "ph_env_weeds_1")
    P._center_xy(obj)
    L.finish(obj, "ph_env_weeds_1", "environment", 80)


def weeds_2():
    """Stage 2 'verunkrautet': weedy tufts, dark broad rosettes (dock, plantain) and dry straw
    seed stalks over bare soil, ~1 m."""
    L.reset(640)
    parts = [_soil_patch(0.36, SOIL_CORE, SOIL_EDGE, 642)]
    spots = _spots(10, 0.4, 0.18, 640)
    tufts = [(p, random.randint(5, 7), (0.14, 0.24), 0.014, 0.08) for p in spots[:5]]
    parts.append(_blades(tufts, L.mix(GRASS_TINT, SPROUT_BRIGHT, 0.4), 1, zr=(0.0, 0.26)))
    for i, (x, y) in enumerate(spots[5:]):
        parts.append(_rosette(x, y, random.randint(5, 6), random.uniform(0.1, 0.14), 0.034, WEED_DARK, 20 + i,
                              mat=L.MAT_PAINTED))
    for i, (x, y) in enumerate(_spots(3, 0.28, 0.2, 643)):
        _stalk(parts, x, y, random.uniform(0.2, 0.24), STRAW, 40 + i, head=0.045)
    for i, (x, y) in enumerate(_spots(2, 0.3, 0.2, 641)):
        _seedling(parts, x, y, random.uniform(0.05, 0.08), 30 + i)
    obj = L.join(parts, "ph_env_weeds_2")
    P._center_xy(obj)
    _grow(obj, 1.1)
    L.finish(obj, "ph_env_weeds_2", "environment", 80)


def _thistle(parts, x: float, y: float, h: float, seed: int):
    """Tall thistle: stem with jagged leaves, two or three muted purple heads on spiky cups."""
    top = Vector((x + random.uniform(-0.04, 0.04), y + random.uniform(-0.04, 0.04), h))
    stem = [Vector((x, y, 0.0)), Vector((x, y, h * 0.5)) + (top - Vector((x, y, h))) * 0.4, top]
    parts.append(_cane(stem, 0.012, 0.007, WEED_LEAF, seed, sides=4, zr=(0.0, h)))
    bm = bmesh.new()
    for k, z in enumerate((0.22, 0.42, 0.62)):                      # jagged stem leaves
        p = Vector(stem[0]).lerp(top, z)
        a = k * 2.3 + seed
        d = Vector((math.cos(a), math.sin(a), 0.35)).normalized()
        s = Vector((-d.y, d.x, 0.0))
        ln = h * 0.28 * (1.0 - z * 0.5)
        vs = [bm.verts.new(p), bm.verts.new(p + d * ln * 0.3 + s * 0.035), bm.verts.new(p + d * ln * 0.55 + s * 0.012),
              bm.verts.new(p + d * ln * 0.75 + s * 0.03), bm.verts.new(p + d * ln),
              bm.verts.new(p + d * ln * 0.75 - s * 0.03), bm.verts.new(p + d * ln * 0.55 - s * 0.012),
              bm.verts.new(p + d * ln * 0.3 - s * 0.035)]
        for j in range(1, 7):
            bm.faces.new((vs[0], vs[j], vs[j + 1]))
    lv = P._raw(bm, "thistle_leaves")
    L.paint(lv, WEED_LEAF, var=0.2, ao=0.3, top=0.0, zrange=(0.0, h), hue_shift=GRASS_DRY, seed=seed)
    L.set_mat(lv, L.MAT_GRASS)
    parts.append(lv)
    heads = [top] + [top + Vector((math.cos(seed + k * 2.5) * 0.06, math.sin(seed + k * 2.5) * 0.06, -0.06 - k * 0.03))
                     for k in range(2)]
    for k, hp in enumerate(heads):
        if k:
            parts.append(_cane([top - Vector((0, 0, 0.1)), hp], 0.006, 0.005, WEED_LEAF, seed + 10 + k, sides=3))
        cup = L.prim("ico", loc=hp, radius=0.034, subdivisions=1, scale=(1.0, 1.0, 0.95))
        L.jitter(cup, 0.008, 40.0, seed + k)
        parts.append(P._finish_obj(cup, L.hexc("#6E7A4A"), var=0.2, ao=0.1, top=0.1, seed=seed + k))
        tuft = L.prim("cone", loc=hp + Vector((0, 0, 0.038)), radius1=0.03, depth=0.045, vertices=6,
                      rot=(180, 0, 0))                              # the purple brush opening upwards
        parts.append(P._finish_obj(tuft, L.scale_c(THISTLE, random.uniform(0.95, 1.1)), var=0.15, ao=0.0, top=0.3,
                                   seed=seed + k))


def _dandelion(parts, x: float, y: float, h: float, seed: int, puff: bool):
    """Dandelion: flat rosette, a thin stalk and a golden head - or a white seed puff."""
    parts.append(_rosette(x, y, 6, 0.1, 0.022, WEED_LEAF, seed, serrate=True))
    top = Vector((x + random.uniform(-0.02, 0.02), y + random.uniform(-0.02, 0.02), h))
    parts.append(_cane([Vector((x, y, 0.01)), top], 0.005, 0.004, SPROUT, seed + 1, sides=3, zr=(0, h)))
    if puff:
        ball = L.prim("ico", loc=top + Vector((0, 0, 0.03)), radius=0.036, subdivisions=1)
        parts.append(P._finish_obj(ball, PUFF, var=0.08, ao=0.0, top=0.3, seed=seed))
    else:
        head = L.prim("cyl", loc=top + Vector((0, 0, 0.008)), radius=0.032, depth=0.018, vertices=8)
        L.jitter(head, 0.004, 40.0, seed)
        parts.append(P._finish_obj(head, DANDELION, var=0.12, ao=0.0, top=0.3, seed=seed))


def weeds_3():
    """Stage 3 'verwildert' (clearly readable): tall thistles with purple heads, dandelions in
    flower and in seed, rust dock stalks, rank grass and dark rosettes on trampled bare soil
    (~1.1 m patch)."""
    L.reset(650)
    parts = [_soil_patch(0.42, L.scale_c(SOIL_CORE, 0.92), SOIL_EDGE, 652, segs=12)]
    _thistle(parts, -0.12, 0.08, 0.62, 1)
    _thistle(parts, 0.24, -0.18, 0.48, 2)
    _dandelion(parts, 0.28, 0.24, 0.2, 3, False)
    _dandelion(parts, -0.34, -0.2, 0.24, 4, True)
    _dandelion(parts, 0.02, -0.34, 0.17, 5, False)
    _stalk(parts, -0.3, 0.22, 0.42, DOCK_RUST, 7, head=0.09)
    _stalk(parts, 0.1, 0.3, 0.36, DOCK_RUST, 8, head=0.08)
    spots = _spots(10, 0.42, 0.18, 650)
    tufts = [(p, random.randint(5, 7), (0.2, 0.34), 0.016, 0.1) for p in spots[:6]]
    parts.append(_blades(tufts, L.mix(GRASS_TINT, GRASS_DRY, 0.45), 6, zr=(0.0, 0.36)))
    for i, (x, y) in enumerate(spots[5:]):
        parts.append(_rosette(x, y, 6, random.uniform(0.11, 0.15), 0.036, WEED_DARK, 20 + i, mat=L.MAT_PAINTED))
    obj = L.join(parts, "ph_env_weeds_3")
    P._center_xy(obj)
    _grow(obj, 1.15)
    L.finish(obj, "ph_env_weeds_3", "environment", 80)


def _leaf(bm, x: float, y: float, z: float, size: float, yaw: float, curl: float):
    """One fallen leaf: 6-vertex outline (stem end, two lobes each side, tip), 4 tris, slightly curled."""
    d = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    s = Vector((-d.y, d.x, 0.0))
    c = Vector((x, y, z))
    pts = [c - d * size * 0.5, c - d * size * 0.15 + s * size * 0.32, c + d * size * 0.22 + s * size * 0.26,
           c + d * size * 0.55, c + d * size * 0.22 - s * size * 0.26, c - d * size * 0.15 - s * size * 0.32]
    vs = [bm.verts.new(p + Vector((0, 0, curl * (abs((p - c).dot(s)) / size)))) for p in pts]
    for j in range(1, 5):
        bm.faces.new((vs[0], vs[j + 1], vs[j]))           # counter-clockwise from above: faces up


def _litter(name: str, count: int, radius: float, heaps: int, seed: int, size=(0.05, 0.08), mulch: float = 0.0):
    """Leaf litter spot: `count` flat leaves in ochre and browns, denser in the middle; with heaps,
    a quarter of them is piled on low dark cores where the wind drifted them together."""
    L.reset(seed)
    bm = bmesh.new()
    cols = []
    piles = [(math.cos(i / max(1, heaps) * math.tau + 0.7) * radius * 0.42,
              math.sin(i / max(1, heaps) * math.tau + 0.7) * radius * 0.36) for i in range(heaps)]
    on_piles = count // 4 if heaps else 0
    for i in range(count):
        if i < on_piles:
            px, py = piles[i % heaps]
            a, d = random.uniform(0, math.tau), 0.11 * random.random() ** 0.6
            x, y = px + math.cos(a) * d * 1.3, py + math.sin(a) * d
            z = 0.012 + 0.03 * (1.0 - d / 0.11)
        else:
            a = random.uniform(0, math.tau)
            d = radius * random.random() ** 0.75
            x, y = math.cos(a) * d, math.sin(a) * d * 0.85
            z = 0.004 + random.uniform(0.0, 0.012) * (1.0 - d / radius)
        _leaf(bm, x, y, z, random.uniform(*size), random.uniform(0, math.tau), random.uniform(0.006, 0.018))
        cols.append(L.scale_c(random.choice(LITTER), random.uniform(0.85, 1.12)))
    o = P._raw(bm, "litter")
    me = o.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for pi, poly in enumerate(me.polygons):
        c = cols[pi // 4]
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            f = 0.88 + 0.12 * noise.noise(v * 20.0) + 0.1 * (v.z / 0.02)
            attr.data[li].color = (*[L._to_lin(min(1.0, ch * f)) for ch in c], 1.0)
    L.set_mat(o, L.MAT_PAINTED)
    parts = [o]
    if mulch > 0.0:                                                # QA readability: rotting leaves darken the ground
        parts.append(_soil_patch(mulch, MULCH_CORE, L.mix(GRASS_TINT, LITTER[1], 0.45), seed + 7, segs=14, lift=0.002))
    for i, (px, py) in enumerate(piles):                           # dark cores under the piled leaves
        h = L.prim("ico", loc=(px, py, -0.005), radius=0.1, subdivisions=1, scale=(1.3, 1.0, 0.33))
        L.jitter(h, 0.012, 12.0, seed + i)
        parts.append(P._finish_obj(h, L.scale_c(L.mix(LITTER[1], LITTER[2], 0.5), 0.9), var=0.35, ao=0.4, top=0.0,
                                   noise_freq=14.0, hue_shift=LITTER[0], seed=seed + i))
    obj = L.join(parts, name)
    P._center_xy(obj)
    L.finish(obj, name, "environment", 30, shift=False)


def leaves_1():
    _litter("ph_env_leaves_1", 40, 0.5, 0, 660, size=(0.06, 0.09))


def leaves_2():
    _litter("ph_env_leaves_2", 74, 0.62, 2, 661, size=(0.065, 0.1))


def leaves_3():
    _litter("ph_env_leaves_3", 88, 0.7, 3, 662, size=(0.07, 0.11), mulch=0.5)


# --- birch --------------------------------------------------------------------------

def _straight_trunk(height: float, r0: float, r1: float, rings: int, verts: int, lean, seed: int):
    """Slender, nearly straight trunk (a birch is no gnarled oak): small wobble, slight lean."""
    bm = bmesh.new()
    rr = []
    lean = Vector(lean)
    for k in range(rings + 1):
        t = k / rings
        z = -0.15 + (height + 0.15) * t
        r = (r0 + (r1 - r0) * t) * (1.0 + 0.5 * max(0.0, 1.0 - t * 12.0) ** 2)   # small flare at the foot
        c = lean * z + Vector((noise.noise(Vector((t * 2.0, seed, 0))), noise.noise(Vector((seed, t * 2.0, 0))), 0)) * 0.07
        ring = []
        for j in range(verts):
            a = j / verts * math.tau
            f = 1.0 + noise.noise(Vector((math.cos(a), math.sin(a), t * 9.0 + seed))) * 0.08
            ring.append(bm.verts.new(c + Vector((math.cos(a) * r * f, math.sin(a) * r * f, z))))
        rr.append(ring)
    for k in range(rings):
        for j in range(verts):
            bm.faces.new((rr[k][j], rr[k][(j + 1) % verts], rr[k + 1][(j + 1) % verts], rr[k + 1][j]))
    bm.faces.new(list(reversed(rr[0])))
    bm.faces.new(rr[-1])
    return P._link(bm, "trunk")


def birch():
    """Slender birch (~7.5 m): straight white trunk with dark lenticel dashes and a blackened,
    fissured foot, thin up-swept branches with drooping tips, a light and airy crown of small
    pale-green leaf masses in the upper half."""
    L.reset(670)
    rnd = random.Random(671)
    height = 7.0
    lean = (0.025, 0.015, 0.0)
    trunk = _straight_trunk(height, 0.13, 0.03, 34, 8, lean, 1)

    def bark(co, vi):
        h = co.z
        a = math.atan2(co.y - lean[1] * h, co.x - lean[0] * h)
        c = L.scale_c(BIRCH_BARK, 0.96 + 0.06 * noise.noise(co * 5.0))
        band = math.sin(h * 11.0 + noise.noise(Vector((math.cos(a), math.sin(a), h))) * 3.0)
        side = noise.noise(Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, h * 1.3 + 4.0)))
        if band > 0.72 and side > -0.1:                             # dark horizontal dashes
            c = L.mix(c, BIRCH_MARK, 0.85)
        foot = 1.0 - h / 1.3 + 0.35 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, h * 3.0)))
        c = L.mix(c, BIRCH_MARK, max(0.0, min(0.9, foot * 1.3)))
        return L.mix(c, L.hexc("#8A7A6A"), min(0.5, max(0.0, (h - 5.8) / 1.5)))
    P._paint_fn(trunk, bark)
    L.set_mat(trunk, L.MAT_PAINTED)
    parts = [trunk]
    lv = Vector(lean)
    tips = []
    for i in range(12):                                             # up-swept branches, drooping tips
        z = 2.8 + i * 0.33 + rnd.uniform(-0.1, 0.1)
        a = i * 2.4 + rnd.uniform(-0.3, 0.3)
        ln = 1.55 - (z - 2.8) * 0.2 + rnd.uniform(-0.1, 0.1)
        start = lv * z + Vector((0, 0, z))
        d = (math.cos(a), math.sin(a), 0.85)
        br = limb(start, d, ln, 0.035, 0.01, 20 + i, segs=4, verts=4, droop=0.45)
        P._paint_fn(br, lambda co, vi: L.scale_c(L.mix(BIRCH_BARK, BIRCH_MARK, 0.4 +
                                                        0.3 * max(0.0, noise.noise(co * 3.0))), 0.85))
        L.set_mat(br, L.MAT_PAINTED)
        parts.append(br)
        tips.append((start + Vector(d).normalized() * ln * 0.7 - Vector((0, 0, 0.35)), ln))
    k = 0
    for bi, (c, ln) in enumerate(tips):                             # small, loose masses along each branch
        for j in range(4 if bi % 2 else 3):
            off = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(-0.5, 0.3)))
            shade = rnd.random()
            parts.append(_clump(c + off * (0.5 + j * 0.3), rnd.uniform(0.18, 0.3),
                                L.mix(BIRCH_LEAF_A, BIRCH_LEAF_B, shade * 0.8), 70 + k, scale=(1.0, 1.0, 1.15),
                                zr=(2.5, 7.8), jit=0.4, hue=L.hexc("#9A9A58") if shade > 0.7 else None))
            k += 1
    top = lv * height + Vector((0, 0, height))
    for j in range(3):                                              # the leader
        parts.append(_clump(top + Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), -0.35 * j)), 0.3,
                            L.mix(BIRCH_LEAF_A, BIRCH_LEAF_B, 0.5), 150 + j, scale=(1.0, 1.0, 1.2), zr=(2.5, 7.8)))
    obj = L.join(parts, "ph_env_birch")
    L.finish(obj, "ph_env_birch", "environment", 50, shift=False)


ASSETS = (bramble, stump, hedge_thorn, weeds_1, weeds_2, weeds_3, leaves_1, leaves_2, leaves_3, birch)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
