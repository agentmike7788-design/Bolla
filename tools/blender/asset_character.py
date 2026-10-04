"""The gravekeeper (player). Stylised ~4.5 heads, hunched, long coat, shoulder
cape, wide crooked hat, shovel strapped to the back, lantern on the belt.
Front faces -Y (Blender) = +Z (Godot).
ART STYLE LOCK: identity, silhouette, proportions and palette are the approved
Phase-1 design. Gate G2 round 1 (user: "den main charackter ... verschönern")
refines the forms only: rounder, more segments where the eye lands, a readable
melancholic-kind face, layered ragged cape, scarf knot with fringe, coat seams,
buttons, pockets and back slit, a proper lantern cage, D-grip shovel, laced
boots with soles and richer painted colour. The shared rig (rig.py, rigid
skinning), the joints and the actions idle-loop, walk-loop, carry_idle-loop,
carry_walk-loop, dig-loop, interact are unchanged."""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Quaternion, Vector

import lib_painted as L
import lib_faces as F
import rig

NAME = "ph_chr_gravekeeper"

COAT = L.hexc("#4B4038")
COAT_DARK = L.hexc("#352D28")
COAT_WARM = L.hexc("#5A463A")    # subtle warm hue shift on the coat's upper back
CAPE = L.hexc("#3E4640")
CAPE_MOSS = L.hexc("#4A5642")    # greener top layer
SCARF = L.hexc("#B08A3E")
SCARF_DARK = L.hexc("#8A6A2E")
HAT = L.hexc("#3B3430")
HAT_DUST = L.hexc("#5A524A")     # worn / dusty crown edges and brim rim
HAT_BAND = L.hexc("#6A4A2F")
PATCH = L.hexc("#4E4A40")
THREAD = L.hexc("#857B6A")
SKIN = L.hexc("#C8A383")
BLUSH = L.hexc("#C0806A")
BOOT = L.hexc("#2F2722")
SOLE = L.hexc("#221C19")
LACE = L.hexc("#7A6A55")
TROUSER = L.hexc("#3F4441")
IRON = L.hexc("#3A3C40")
BRASS = L.hexc("#6E6250")        # dull, dark buckle metal (no second warm accent)
WOOD = L.hexc("#6E5238")
LEATHER = L.hexc("#2A2420")
BEARD = L.hexc("#A39A8C")
BROW = L.hexc("#C2BAAE")
EYE = L.hexc("#1E1714")
FEATHER = L.hexc("#454C4A")
MUD = L.hexc("#6B5A48")          # palette: earth / paths (dusty hem, boots)

HUNCH = -0.09   # forward lean of the upper body (towards -Y)
WAIST_Z = 0.86  # coat below -> hips, above -> spine (the seam hides under the belt)
SHOVEL = "Shovel"
TOOL = "tool"
SHOVEL_G0 = Vector((0.25, 0.2, 0.49))     # shaft end at the D-grip (left hip, on the back)
SHOVEL_G1 = Vector((-0.34, 0.31, 1.3))    # shaft end at the blade socket (behind the right shoulder)
LANTERN = Vector((0.31, HUNCH * 0.3 - 0.07, 0.727772))  # approved belt-lantern light position
TAU = 2.0 * math.pi
W = rig.weight


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


# --- private mesh helpers (rig.py / lib_painted.py stay untouched) ------------------

def _obj(bm, name: str):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _lathe(rings, n: int, name: str = "lathe", ring_fn=None, loop: bool = False):
    """Surface of revolution around Z. rings: [(rx, ry, z, cy[, cx])] bottom -> top.
    ring_fn(a, i) -> (dr, dz) shapes single vertices (folds, tatters, notches).
    loop=False: capped at both ends (closed tube); loop=True: the profile is a closed
    cross-section (a shell with thickness, e.g. the cape or the brim)."""
    bm = bmesh.new()
    vs = []
    for i, ring in enumerate(rings):
        rx, ry, z, cy = ring[:4]
        cx = ring[4] if len(ring) > 4 else 0.0
        row = []
        for k in range(n):
            a = TAU * k / n
            dr, dz = ring_fn(a, i) if ring_fn else (0.0, 0.0)
            row.append(bm.verts.new((cx + math.cos(a) * (rx + dr), cy + math.sin(a) * (ry + dr), z + dz)))
        vs.append(row)
    m = len(vs)
    for i in range(m if loop else m - 1):
        a, b = vs[i], vs[(i + 1) % m]
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    if not loop:
        for row in (vs[0], vs[-1]):
            c = bm.verts.new(sum((v.co for v in row), Vector()) / n)
            for k in range(n):
                bm.faces.new((c, row[k], row[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(bm, name)


def _xf(obj, m: Matrix):
    obj.data.transform(m)
    return obj


def _frame(origin, fwd, up) -> Matrix:
    """Matrix mapping local X/Y/Z to (side, fwd, up) at origin (fwd, up need not be orthogonal)."""
    y = Vector(fwd).normalized()
    x = y.cross(Vector(up)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def _tint(obj, fn) -> None:
    """Post-paint pass: fn(co, normal) -> None | (rgb multiplier) | (target sRGB, weight)."""
    me = obj.data
    attr = me.color_attributes["Col"]
    for poly in me.polygons:
        for li in poly.loop_indices:
            r = fn(me.vertices[me.loops[li].vertex_index].co, poly.normal)
            if r is None:
                continue
            c = attr.data[li].color
            if len(r) == 2:
                tgt, w = r
                w = min(1.0, max(0.0, w))
                t = [L._to_lin(x) for x in tgt]
                attr.data[li].color = (c[0] + (t[0] - c[0]) * w, c[1] + (t[1] - c[1]) * w,
                                       c[2] + (t[2] - c[2]) * w, 1.0)
            else:
                attr.data[li].color = (c[0] * r[0], c[1] * r[1], c[2] * r[2], 1.0)


def _tri(x: float) -> float:
    """Triangle wave: 0 at integers, 1 halfway."""
    f = x - math.floor(x)
    return 1.0 - abs(2.0 * f - 1.0)


def _smooth01(x: float) -> float:
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def _adiff(a: float, b: float) -> float:
    return abs((a - b + math.pi) % TAU - math.pi)


# --- the long coat ---------------------------------------------------------------------

def coat_r(z: float) -> tuple:
    """(rx, ry, centre y) of the coat at height z (approved Phase-1 profile)."""
    t = (z - 0.36) / 0.95
    r = 0.34 - 0.12 * t
    return r * (1.0 + 0.1 * (1 - t)), r * 0.78, HUNCH * t * t


def _coat():
    zs = [0.36, 0.41, 0.48, 0.56, 0.65, 0.75, 0.83, 0.855, 0.865, 0.9, 0.99, 1.08, 1.17,
          1.25, 1.3, 1.345]
    rings = []
    for z in zs:
        rx, ry, cy = coat_r(min(z, 1.31))
        if z > 1.31:  # round the shoulders in under the cape
            s = 1.0 - (z - 1.31) * 9.0
            rx, ry = rx * s, ry * s
        rings.append((rx, ry, z, cy))
    front, back = -math.pi / 2, math.pi / 2
    tatter = [random.uniform(-1, 1) for _ in range(64)]

    def fn(a, i):
        z = zs[i]
        skirt = max(0.0, (0.86 - z) / 0.5)
        dr = 0.012 * math.sin(a * 7.0 + 0.6) * skirt + 0.006 * math.sin(a * 13.0) * skirt   # soft folds
        aa = a - TAU if a > math.pi else a
        if z < 0.86 and -math.pi / 2 < aa < -math.pi / 2 + 0.42:  # the left panel overlaps the right
            dr += 0.01
        dz = 0.0
        if i == 0:  # worn, slightly uneven hem; the coat opens at the front, slit at the back
            dz = 0.012 * tatter[int(a / TAU * 32) % 64]
            dz += 0.06 * max(0.0, 1.0 - _adiff(a, front) / 0.26)
            dz += 0.05 * max(0.0, 1.0 - _adiff(a, back) / 0.2)
        return dr, dz

    coat = _lathe(rings, 32, "coat", fn)
    L.jitter(coat, 0.01, 3.0, 4)
    _painted(coat, COAT, var=0.18, ao=0.35, top=0.15, zrange=(0.36, 1.31), seed=5, hue_shift=COAT_DARK)

    def shade(co, n):
        a = math.atan2(co.y - coat_r(co.z)[2], co.x)
        if co.z < 0.86 and _adiff(a, front) < 0.09:
            return (0.5, 0.5, 0.5)                         # front opening seam
        if co.z < 0.62 and _adiff(a, back) < 0.08:
            return (0.45, 0.45, 0.45)                      # back slit
        if _adiff(a, back) < 0.05 and co.z > 0.86:
            return (0.8, 0.8, 0.8)                         # centre back seam
        if co.z < 0.45:
            return MUD, 0.35 * (0.45 - co.z) / 0.09        # dusty hem
        if co.z > 1.0 and n.y > 0.2:
            return COAT_WARM, 0.25                         # warm back under the cape
        return None
    _tint(coat, shade)
    return coat


def _on_coat(x_sign: float, z: float, a_deg: float, out: float = 0.0) -> Vector:
    """Point on the coat surface at height z and angle a (0 = +X, -90 = front)."""
    rx, ry, cy = coat_r(z)
    a = math.radians(a_deg)
    return Vector((math.cos(a) * (rx + out) * x_sign, cy + math.sin(a) * (ry + out), z))


def build_shovel():
    """The D-grip shovel as its own mesh "Shovel" (G7 Runde 2: drawn from the back for digging),
    modelled in its approved place strapped diagonally to the back, blade up behind the right
    shoulder. Bone-parented to the "tool" bone in build()."""
    g0, g1 = SHOVEL_G0, SHOVEL_G1
    d = (g1 - g0).normalized()
    sp = []
    sp.append((_painted(L.tube(g0, g1, 0.021, 10), WOOD, var=0.22, seed=15, hue_shift=L.hexc("#5A4230"))))
    # D-grip at the lower end
    sm = _frame(g0, d, (0, 1, 0))
    grip = L.prim("torus", loc=(0, -0.05, 0), major_radius=0.04, minor_radius=0.011, major_segments=12,
                  minor_segments=4, rot=(0, 90, 0), scale=(1, 1.1, 1))
    sp.append((_painted(_xf(grip, sm), WOOD, var=0.2, ao=0.0, top=0.3, seed=16)))
    sp.append((_painted(_xf(L.tube((0, -0.012, 0), (0, 0.03, 0), 0.024, 8), sm), IRON, var=0.2, ao=0.0,
                                     seed=16)))
    # iron socket and a rounded spade blade (normal facing out of his back)
    bm_ = _frame(g1, d, (0, 1, 0.0))
    sp.append((_painted(_xf(L.tube((0, -0.02, 0), (0, 0.08, 0), 0.024, 10, r_end=0.03), bm_), IRON,
                                     var=0.25, ao=0.0, seed=17)))
    outline = []
    for k in range(17):
        t = k / 16.0
        a = math.pi * (1.0 - t)
        outline.append((math.cos(a) * 0.1, 0.2 + math.sin(a) * 0.14))   # rounded point
    outline = [(-0.105, 0.075), (-0.1, 0.2)] + outline[1:-1] + [(0.1, 0.2), (0.105, 0.075), (0.03, 0.07),
                                                                  (-0.03, 0.07)]
    bmb = bmesh.new()
    top = [bmb.verts.new((x, y, 0.006)) for x, y in outline]
    bot = [bmb.verts.new((x, y, -0.006)) for x, y in outline]
    bmb.faces.new(top)
    bmb.faces.new(list(reversed(bot)))
    n_ = len(outline)
    for k in range(n_):
        bmb.faces.new((top[k], bot[k], bot[(k + 1) % n_], top[(k + 1) % n_]))
    bmesh.ops.recalc_face_normals(bmb, faces=bmb.faces[:])
    blade = _obj(bmb, "blade")
    for v in blade.data.vertices:  # dished
        v.co.z += 0.9 * v.co.x ** 2
    L.jitter(blade, 0.003, 8.0, 16)
    _xf(blade, bm_)
    _painted(blade, IRON, var=0.3, ao=0.0, top=0.25, hue_shift=L.hexc("#6A4A3A"), seed=16)
    sp.append(blade)
    obj = L.join(sp, SHOVEL)
    L.smooth(obj, 55)
    return obj


def build_mesh():
    """Every part rigidly weighted to one bone. Returns (mesh, lantern position) in
    model space; the soles stand exactly on z = 0 (grounding shift ~0)."""
    L.reset(80)
    parts = []

    # --- boots with soles, laces, cuffs; thin trouser legs --------------------------
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x = sx * 0.11
        foot = L.prim("sphere", loc=(x, -0.06, 0.075), scale=(0.085, 0.16, 0.07), segments=14, ring_count=8)
        for v in foot.data.vertices:  # flat underside, round toe cap turning up a little
            v.co.z = max(v.co.z, 0.03)
            if v.co.y < -0.12:
                v.co.z += (-(v.co.y + 0.12)) * 0.25
        L.jitter(foot, 0.005, 4.0, 1 + sx)
        parts.append(W(leg, _painted(foot, BOOT, var=0.14, top=0.3, seed=1 + sx)))
        sole = L.prim("sphere", loc=(x, -0.057, 0.03), scale=(0.093, 0.168, 0.03), segments=14, ring_count=6)
        for v in sole.data.vertices:
            v.co.z = min(max(0.0, v.co.z), 0.036)
            if v.co.y < -0.13:
                v.co.z += (-(v.co.y + 0.13)) * 0.22     # sole follows the toe spring
        parts.append(W(leg, _painted(sole, SOLE, var=0.1, ao=0.0, seed=2)))
        shaft = L.prim("cyl", loc=(x, 0.0, 0.125), radius=0.058, depth=0.15, vertices=12)
        L.taper(shaft, 0.05, 0.2, 1.12)
        parts.append(W(leg, _painted(shaft, BOOT, var=0.14, ao=0.2, seed=3 + sx)))
        parts.append(W(leg, L.part("torus", L.scale_c(BOOT, 1.25), loc=(x, 0.0, 0.2), major_radius=0.064,
                                   minor_radius=0.014, major_segments=12, minor_segments=4, jit=0.004, seed=4)))
        for k in range(2):  # criss-cross laces on the instep
            ly, lz = -0.08 - 0.035 * k, 0.116 - 0.014 * k
            for s in (-1, 1):
                lace = L.prim("cube", loc=(x, ly, lz), scale=(0.035, 0.005, 0.004), rot=(-22, 0, s * 28))
                parts.append(W(leg, _painted(lace, LACE, var=0.1, ao=0.0, top=0.3, seed=5)))
        tr = L.tube((sx * 0.1, 0, 0.19), (sx * 0.1, 0, 0.62), 0.052, 12, r_end=0.058)
        parts.append(W(leg, _painted(tr, TROUSER, var=0.15, seed=3)))

    # --- long coat, belt with buckle, buttons, pockets ------------------------------
    parts.append(rig.weight_split_z(_coat(), WAIST_Z, "hips", "spine"))
    # front edge strip + back slit (a little proud, dark)
    for z0, z1, a in ((0.4, 0.84, -90.0), (0.42, 0.62, 90.0)):
        p0, p1 = _on_coat(1, z0, a, 0.004), _on_coat(1, z1, a, 0.004)
        parts.append(W("hips", _painted(L.tube(p0, p1, 0.009, 6), COAT_DARK, var=0.1, ao=0.0, seed=17)))
    belt_rings = []
    for z, out in ((0.832, 0.010), (0.842, 0.018), (0.878, 0.018), (0.888, 0.010)):
        rx, ry, cy = coat_r(z)
        belt_rings.append((rx + out, ry + out, z, cy))
    belt = _lathe(belt_rings, 40, "belt")
    parts.append(W("hips", _painted(belt, LEATHER, var=0.2, ao=0.0, top=0.3, seed=18)))
    bp = _on_coat(1, 0.86, -96, 0.026)
    buckle = L.prim("torus", major_radius=0.034, minor_radius=0.007, major_segments=4, minor_segments=4,
                    rot=(90, 45, 0), scale=(1.0, 1.0, 1.25))
    _xf(buckle, Matrix.Translation(bp))
    parts.append(W("hips", _painted(buckle, BRASS, var=0.25, ao=0.0, top=0.4, seed=19)))
    for z in (0.52, 0.64, 0.76, 0.94, 1.02):  # buttons along the overlapping left panel
        bone = "hips" if z < WAIST_Z else "spine"
        p = _on_coat(1, z, -80, 0.012)
        parts.append(W(bone, L.part("sphere", BRASS, loc=p, radius=0.014, segments=6, ring_count=4,
                                    scale=(1, 0.55, 1), paint_kw={"ao": 0.0, "top": 0.5})))
    for sx in (-1, 1):  # flap pockets on the hips (behind the lantern on the left)
        a = -50.0 if sx < 0 else -40.0
        p = _on_coat(sx, 0.7, a, 0.01)
        flap = L.prim("cube", scale=(0.075, 0.012, 0.03))
        L.bevel(flap, 0.006, 1)
        nrm = Vector((p.x, (p.y - coat_r(0.7)[2]) * 1.6, 0.0)).normalized()
        _xf(flap, Matrix.Translation(p) @ Vector((0, -1, 0)).rotation_difference(nrm).to_matrix().to_4x4()
            @ Matrix.Rotation(math.radians(-8), 4, "X"))
        parts.append(W("hips", _painted(flap, COAT_DARK, var=0.15, ao=0.0, top=0.3, seed=20)))

    # --- ragged shoulder cape, two layers (reads from the top-down camera) ------------
    cape_prof = ((1.05, 0.39), (1.12, 0.375), (1.19, 0.345), (1.25, 0.3), (1.3, 0.235), (1.335, 0.165),
                 (1.355, 0.125))
    cape_sy = 0.8

    def cape_r(z):
        """Outer x radius of the lower cape: draped over the shoulders, closing at the neck."""
        for (z0, r0), (z1, r1) in zip(cape_prof, cape_prof[1:]):
            if z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return cape_prof[-1][1]

    def cape(zs, extra, n_tat, depth, seed, name, n=40):
        th = 0.016
        prof = [(cape_r(z) + extra, z) for z in zs] + [(0.125 + extra * 0.3, 1.355)]
        outer = [(r, r * cape_sy, z, HUNCH) for r, z in prof]
        inner = [(r - th, (r - th) * cape_sy, z - th * 0.5, HUNCH) for r, z in reversed(prof)]
        rings = outer + inner
        m = len(rings)
        rnd = random.Random(seed)
        lens = [rnd.uniform(0.5, 1.0) for _ in range(n_tat)]
        phase = rnd.uniform(0, 1)
        z_hem = zs[0]

        def fold(a, z):
            return math.sin(a * 8.0 + seed) * max(0.0, 1.0 - (z - z_hem) / 0.22)

        def fn(a, i):
            f = 0.012 * fold(a, rings[i][2])   # draped folds
            if i not in (0, m - 1):
                return f, 0.0
            u = a / TAU * n_tat + phase
            k = int(math.floor(u)) % n_tat
            v = _tri(u)                      # 0 between tatters, 1 at a tatter's point
            return f + 0.01 * v, -depth * lens[k] * v ** 1.5
        obj = _lathe(rings, n, name, fn, loop=True)
        L.jitter(obj, 0.008, 3.5, seed)
        return obj, fold

    def cape_shade(fold, z_tip):
        def fn(co, n):
            f = 1.0 + 0.12 * fold(math.atan2(co.y - HUNCH, co.x), co.z)   # painted fold light/shadow
            if co.z < z_tip:
                f *= 0.74                                                  # frayed, darker tips
            return (f, f, f * 1.02)
        return fn
    cape_lo, fold_lo = cape([1.05, 1.12, 1.19, 1.25, 1.3, 1.335], 0.0, 11, 0.075, 13, "cape")
    _painted(cape_lo, CAPE, var=0.2, ao=0.3, top=0.2, seed=14, zrange=(0.98, 1.36))
    _tint(cape_lo, cape_shade(fold_lo, 1.03))
    parts.append(W("spine", cape_lo))
    cape_hi, fold_hi = cape([1.17, 1.23, 1.29, 1.325], 0.02, 9, 0.05, 21, "capelet", 36)
    _painted(cape_hi, CAPE_MOSS, var=0.22, ao=0.2, top=0.25, seed=22, zrange=(1.1, 1.36), hue_shift=CAPE)
    _tint(cape_hi, cape_shade(fold_hi, 1.15))
    parts.append(W("spine", cape_hi))

    def on_cape(x, z, side, out=0.014):
        """Point on the capelet surface (side -1 = front, +1 = back) + outward normal."""
        rx = cape_r(z) + 0.02 + out
        ry = rx * cape_sy
        y = HUNCH + side * ry * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2))
        nrm = Vector((x / rx ** 2, (y - HUNCH) / ry ** 2, 0.25)).normalized()
        return Vector((x, y, z)), nrm

    # --- scarf: wrapped twice, knot and two fringed tails (the one warm accent) -------
    for k, (rz, tilt, mr) in enumerate(((1.355, 6, 0.125), (1.39, -5, 0.115))):
        ring = L.prim("torus", loc=(0, HUNCH - 0.01, rz), rot=(tilt, 3 * k, 0), major_radius=mr, minor_radius=0.05,
                      major_segments=16, minor_segments=6, scale=(1.0, 0.92, 1.0))
        L.jitter(ring, 0.008, 5.0, 6 + k)
        parts.append(W("spine", _painted(ring, SCARF, var=0.14, ao=0.25, top=0.2, seed=6 + k,
                                         hue_shift=L.mix(SCARF, SCARF_DARK, 0.6))))
    knot_p = Vector((0.09, HUNCH - 0.115, 1.335))
    knot = L.prim("sphere", loc=knot_p, radius=0.045, segments=12, ring_count=8, scale=(1.0, 0.8, 0.9))
    L.jitter(knot, 0.006, 6.0, 8)
    parts.append(W("spine", _painted(knot, SCARF, var=0.12, ao=0.0, top=0.25, seed=8)))

    def tail(path, width, seed, fringe_col):
        """A cloth strip along a polyline (list of points + side vector) with a fringe."""
        bm = bmesh.new()
        rows = []
        for p, side, nrm in path:
            p, side, nrm = Vector(p), Vector(side).normalized(), Vector(nrm).normalized()
            rows.append([bm.verts.new(p + side * width * s + nrm * 0.008 * t)
                         for s, t in ((-1, 1), (1, 1), (1, -1), (-1, -1))])
        for a, b in zip(rows, rows[1:]):
            for k in range(4):
                bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
        bm.faces.new(rows[0])
        bm.faces.new(list(reversed(rows[-1])))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        obj = _obj(bm, "scarf_tail")
        L.jitter(obj, 0.004, 8.0, seed)
        _painted(obj, SCARF, var=0.14, ao=0.0, top=0.2, seed=seed, hue_shift=L.mix(SCARF, SCARF_DARK, 0.5))
        _tint(obj, lambda co, n: ((0.8, 0.8, 0.8) if int((co.x + co.y) * 60) % 3 == 0 else None))
        out = [obj]
        end, side, nrm = (Vector(x) for x in path[-1])
        prev = Vector(path[-2][0])
        down = (end - prev).normalized()
        for f in range(5):  # fringe
            s = (f / 4.0 - 0.5) * 2 * width * 0.85
            a = end + side.normalized() * s
            out.append(_painted(L.tube(a, a + down * (0.035 + 0.01 * (f % 2)), 0.0055, 4, r_end=0.003),
                                fringe_col, var=0.1, ao=0.0, seed=seed + f))
        return out
    # front tail hangs from the knot over the cape, swinging a little to his left
    front_path = [((0.1, HUNCH - 0.15, 1.315), (1, 0.1, 0.2), (0.2, -1, 0))]
    for x, z in ((0.13, 1.25), (0.16, 1.18), (0.185, 1.115)):
        p, nrm = on_cape(x, z, -1)
        front_path.append((p, (1, -0.2, 0.1), nrm))
    for o in tail(front_path, 0.04, 23, SCARF_DARK):
        parts.append(W("spine", o))
    # second tail tossed back over the left shoulder (reads when he walks away)
    back_path = [((0.1, HUNCH + 0.05, 1.41), (0.3, -1, 0), (0.3, 0.2, 1))]
    for x, z in ((0.13, 1.345), (0.15, 1.3), (0.165, 1.24), (0.175, 1.18), (0.18, 1.12)):
        p, nrm = on_cape(x, z, 1)
        back_path.append((p, (1, -0.3, 0), nrm))
    for o in tail(back_path, 0.038, 24, SCARF_DARK):
        parts.append(W("spine", o))

    # --- arms: sleeves with turned-up cuffs, knobbly bare hands with thumbs -----------
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        sh = Vector((sx * 0.25, HUNCH * 0.9, 1.22))
        wrist = Vector((sx * 0.31, HUNCH - 0.1, 0.8))
        elbow = sh.lerp(wrist, 0.5) + Vector((sx * 0.012, 0.025, 0))
        parts.append(W(bone, _painted(L.tube(sh - Vector((sx * 0.02, 0, 0.0)), elbow, 0.066, 12, r_end=0.066),
                                      COAT, var=0.15, ao=0.2, seed=8)))
        parts.append(W(bone, _painted(L.tube(elbow, wrist, 0.066, 12, r_end=0.076), COAT, var=0.15, ao=0.2, seed=9)))
        parts.append(W(bone, L.part("sphere", COAT, loc=elbow, radius=0.066, segments=10, ring_count=5,
                                    paint_kw={"ao": 0.2})))
        cuff = L.tube(wrist + (wrist - elbow).normalized() * -0.02, wrist + (wrist - elbow).normalized() * 0.015,
                      0.083, 12, r_end=0.088)
        parts.append(W(bone, _painted(cuff, COAT_DARK, var=0.15, ao=0.0, top=0.3, seed=10)))
        hand_c = wrist - Vector((0, 0.012, 0.062))
        palm = L.prim("sphere", loc=hand_c, radius=0.05, segments=10, ring_count=7, scale=(0.72, 1.0, 1.12))
        L.jitter(palm, 0.004, 12.0, 11 + sx)
        parts.append(W(bone, _painted(palm, SKIN, ao=0.25, var=0.08, seed=11)))
        fingers = L.prim("sphere", loc=hand_c + Vector((0, -0.012, -0.045)), radius=0.036, segments=8,
                         ring_count=5, scale=(0.78, 1.1, 0.9))
        L.jitter(fingers, 0.004, 14.0, 12 + sx)
        parts.append(W(bone, _painted(fingers, L.mix(SKIN, BLUSH, 0.25), ao=0.2, var=0.08, seed=12)))
        thumb = L.tube(hand_c + Vector((-sx * 0.022, -0.03, 0.02)), hand_c + Vector((-sx * 0.03, -0.06, -0.025)),
                       0.015, 8, r_end=0.012)
        parts.append(W(bone, _painted(thumb, SKIN, ao=0.0, var=0.06, seed=13)))
        parts.append(W(bone, L.part("sphere", SKIN, loc=hand_c + Vector((-sx * 0.03, -0.06, -0.025)), radius=0.013,
                                    segments=6, ring_count=4, paint_kw={"ao": 0.0})))

    # --- head: melancholic-kind, weathered face under the brim (G7 Änderungsrunde 1: the shared
    # sculpted head of lib_faces - awake eyes under heavy tired lids, raised inner brows, a long soft
    # nose, grey hair and a full grey beard as shells over the skull, painted age lines) -------------
    head_c = Vector((0, HUNCH - 0.07, 1.5))
    s = Vector((0.142, 0.148, 0.163))
    pts = F._head(parts, head_c, s, SKIN, seed=30, nose="long", nose_s=1.55, brow=BROW, brow_w=1.7, brow_tilt=0.75,
                  brow_arch=0.7, mouth="kind", smile=0.5, cheeks=0.7, cheek_col=BLUSH, jaw=1.0, chin=0.0,
                  age=0.7, lids=0.34, iris=F.IRIS_GREY, muzzle=1.05, seg=22, rings=14, res=0.72,
                  cull=lambda n: n.z > 0.62 or (n.z < -0.55 and n.y < -0.1), nose_wings=True)
    face = pts["face"]
    # grey hair: a ragged fringe from in front of the ears round the back, below the hat band
    hair_c = L.mix(BEARD, BROW, 0.2)
    F._hair(parts, face, hair_c, L.scale_c(BEARD, 0.8), [(1.05, -0.06), (1.5, -0.24), (2.1, -0.32), (math.pi, -0.38)],
            top=[(1.05, 0.3), (1.5, 0.42), (math.pi, 0.5)], phi=(1.05, TAU - 1.05), out=0.009, crown=0.0,
            tuft=0.022, seed=31, n=20, m=4)
    # full grey beard: a shell from the cheeks over the jaw, a gentle point at the chin
    beard, _, _ = F._shell(face, [(0.0, -1.0)], top=[(0.0, -0.64), (0.3, -0.52), (0.55, -0.4), (0.9, -0.28),
                                                     (1.3, -0.16), (1.6, -0.1)],
                           phi=(-1.6, 1.6), out=lambda ph, w: 0.008 + 0.06 * F._s01((-w - 0.42) / 0.5) *
                           (0.4 + 0.6 * max(0.0, math.cos(ph))), crown=0.0, n=22, m=6, tuck=0.003, lumps=0.007,
                           seed=32, name="beard")
    for v in beard.data.vertices:   # a soft point at the chin
        d = v.co - head_c
        if d.z < -0.12 and d.y < 0.0:
            v.co.z -= 0.035 * max(0.0, 1.0 - abs(d.x) / 0.07) * F._s01((-d.z - 0.12) / 0.08)
    L.jitter(beard, 0.006, 9.0, 32)
    _painted(beard, L.mix(BEARD, BROW, 0.35), var=0.12, ao=0.0, top=0.25, seed=33, hue_shift=BEARD)
    F._tint(beard, lambda co, nr: (1.0 - 0.14 * max(0.0, math.sin(co.x * 160.0 + F._n(co, 9.0) * 3.0)), BROW,
                                   0.35 * max(0.0, nr.z) + 0.2 * max(0.0, F._n(co, 14.0, 2.0))))
    parts.append(W("head", beard))
    for sx in (-1, 1):   # the drooping moustache: two soft lobes from under the nose down past the mouth
        uw = ((sx * 0.02, -0.33), (sx * 0.16, -0.39), (sx * 0.27, -0.52), (sx * 0.3, -0.64))
        mo = F.sweep([face.pt(u, w, o) for (u, w), o in zip(uw, (0.012, 0.017, 0.015, 0.01))], [0.013, 0.018, 0.014, 0.008],
                     n=6, flat=0.75, name="moustache", normals=[face.nrm(u, w) for u, w in uw])
        L.jitter(mo, 0.002, 30.0, 40 + sx)
        parts.append(W("head", _painted(mo, L.scale_c(BROW, 1.02), ao=0.0, var=0.12, top=0.3, seed=41, hue_shift=BEARD)))

    # --- wide, floppy, crooked hat with pinched crown, worn brim, patch and feather ------
    hat_parts = []

    def droop(x, y):
        d = math.hypot(x, y) / 0.39
        a = math.atan2(y, x)
        return -0.072 * d * d * (0.6 + 0.4 * math.sin(a * 2.0 + 0.7)) + 0.008 * math.sin(a * 3.0 + 1.0) * d

    brim_prof = [(0.15, 0.0), (0.27, 0.0), (0.365, 0.0), (0.385, 0.006), (0.396, 0.0), (0.39, -0.012),
                 (0.36, -0.016), (0.27, -0.016), (0.15, -0.016)]
    notch = [random.uniform(0, 1) for _ in range(64)]

    def brim_fn(a, i):
        if i in (3, 4, 5):  # worn edge: a few nicks and a wavy rim
            k = int(a / TAU * 48) % 64
            return -0.012 * max(0.0, notch[k] - 0.8) * 5.0, 0.0
        return 0.0, 0.0
    brim = _lathe([(r, r, z, 0.0) for r, z in brim_prof], 48, "brim", brim_fn, loop=True)
    for v in brim.data.vertices:
        v.co.z += droop(v.co.x, v.co.y)
    L.jitter(brim, 0.006, 3.0, 10)
    _painted(brim, HAT, var=0.18, ao=0.0, top=0.22, seed=12)
    _tint(brim, lambda co, n: (HAT_DUST, 0.55 * _smooth01((math.hypot(co.x, co.y) - 0.33) / 0.06))
          if math.hypot(co.x, co.y) > 0.33 else None)
    hat_parts.append(brim)
    crown_prof = [(r, z * 0.93) for r, z in ((0.172, -0.01), (0.17, 0.04), (0.163, 0.09), (0.15, 0.13),
                                              (0.135, 0.16), (0.118, 0.178), (0.09, 0.186), (0.05, 0.178),
                                              (0.02, 0.17))]
    pinch = (-math.pi / 2 - 0.5, -math.pi / 2 + 0.5)

    def crown_fn(a, i):
        top = max(0.0, (crown_prof[i][1] - 0.08) / 0.1)
        dr = sum(-0.03 * top * max(0.0, 1.0 - _adiff(a, p) / 0.45) for p in pinch)
        dz = -0.03 * top * math.sin(a) ** 2 * (crown_prof[i][0] < 0.1)  # front-to-back crease
        return dr, dz
    crown = _lathe([(r, r * 0.97, z, 0.01) for r, z in crown_prof], 32, "crown", crown_fn)
    L.bend(crown, 0.08, 0.0, 0.19)
    L.jitter(crown, 0.008, 4.0, 11)
    _painted(crown, HAT, var=0.18, ao=0.12, top=0.05, seed=12, zrange=(0.0, 0.19))  # low top: no faceting
    _tint(crown, lambda co, n: (HAT_DUST, 0.4) if n.z > 0.75 and co.z > 0.15 else None)
    hat_parts.append(crown)
    band = _lathe([(0.174, 0.169, 0.003, 0.01), (0.177, 0.172, 0.02, 0.01), (0.176, 0.171, 0.042, 0.01),
                   (0.172, 0.167, 0.05, 0.01)], 32, "band")
    L.bend(band, 0.08, 0.0, 0.19)
    hat_parts.append(_painted(band, HAT_BAND, var=0.16, ao=0.0, top=0.3, seed=25))
    # stitched patch on the front-right brim
    px, py = -0.24, -0.16
    pz = droop(px, py) + 0.009
    slope = Vector((droop(px + 0.01, py) - droop(px - 0.01, py), droop(px, py + 0.01) - droop(px, py - 0.01))) / 0.02
    pm = Matrix.Translation((px, py, pz)) @ Vector((0, 0, 1)).rotation_difference(
        Vector((-slope.x, -slope.y, 1)).normalized()).to_matrix().to_4x4() @ Matrix.Rotation(0.4, 4, "Z")
    patch = L.prim("cube", scale=(0.05, 0.042, 0.004))
    hat_parts.append(_painted(_xf(patch, pm), PATCH, var=0.2, ao=0.0, top=0.2, seed=26))
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in (-1, 1):
            if sx:
                loc = (sx * 0.05, k * 0.022, 0.005)
                rot = 0
            else:
                loc = (k * 0.026, sy * 0.042, 0.005)
                rot = 90
            st = L.prim("cube", loc=loc, scale=(0.003, 0.009, 0.0025), rot=(0, 0, rot))
            hat_parts.append(_painted(_xf(st, pm), THREAD, var=0.05, ao=0.0, top=0.0, seed=27))
    # a crow feather tucked into the band on his left, sweeping back
    fp = Vector((0.16, 0.06, 0.03))
    fm = _frame(fp, (0.4, 1.0, 0.1), (0.3, -0.1, 1.0))
    vane = L.prim("sphere", loc=(0, 0.11, 0), radius=1.0, segments=10, ring_count=8, scale=(0.028, 0.12, 0.006))
    for v in vane.data.vertices:  # asymmetric, slightly curved vane
        v.co.x += 0.25 * (v.co.y - 0.11) ** 2 * 3.0
    hat_parts.append(_painted(_xf(vane, fm), FEATHER, var=0.2, ao=0.0, top=0.3, seed=28,
                              hue_shift=L.hexc("#5E6660")))
    _tint(hat_parts[-1], lambda co, n: (1.5, 1.5, 1.45) if (fm.inverted() @ co).y > 0.2 else None)
    hat_parts.append(_painted(_xf(L.tube((0, -0.03, 0), (0, 0.23, 0), 0.0035, 4), fm), THREAD, var=0.05, ao=0.0,
                              seed=29))
    # the whole hat sits a little crooked on the head
    hm = (Matrix.Translation(head_c + Vector((0, 0, 0.11))) @ Matrix.Rotation(math.radians(-8), 4, "X")
          @ Matrix.Rotation(math.radians(4), 4, "Y"))
    for o in hat_parts:
        parts.append(W("head", _xf(o, hm)))

    # --- shovel strapped diagonally to the back (blade up behind the right shoulder) --------
    # G7 Runde 2: its own mesh "Shovel" on the "tool" bone (build_shovel), drawn for digging
    back_y = 0.25
    shovel = build_shovel()
    # leather strap across the back and chest
    strap = L.prim("torus", loc=(0, back_y * 0.5 + HUNCH * 0.5, 1.02), rot=(0, 34, 0), major_radius=0.3,
                   minor_radius=0.012, major_segments=16, minor_segments=4, scale=(1, 0.76, 1))  # G7 R2: 24 -> 16 segments (tri budget)
    parts.append(W("spine", _painted(strap, LEATHER, var=0.2, ao=0.0, top=0.3, seed=18)))

    # --- lantern on the belt: caged glass, roof, handle, hook ------------------------------
    lp = LANTERN
    for dz_, sc in ((-0.068, (0.047, 0.047, 0.009)), (0.068, (0.047, 0.047, 0.009))):
        plate = L.prim("cube", loc=lp + Vector((0, 0, dz_)), scale=sc)
        L.bevel(plate, 0.004, 1)
        parts.append(W("hips", _painted(plate, IRON, var=0.25, ao=0.0, top=0.35, seed=42)))
    parts.append(W("hips", L.part("cone", IRON, loc=lp + Vector((0, 0, 0.095)), radius1=0.046, radius2=0.012,
                                  depth=0.04, vertices=4, rot=(0, 0, 45), paint_kw={"ao": 0.0, "top": 0.4})))
    parts.append(W("hips", L.part("cyl", IRON, loc=lp + Vector((0, 0, 0.12)), radius=0.013, depth=0.012,
                                  vertices=8)))
    for cx, cy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        parts.append(W("hips", _painted(L.tube(lp + Vector((cx * 0.039, cy * 0.039, -0.062)),
                                               lp + Vector((cx * 0.039, cy * 0.039, 0.062)), 0.0055, 5), IRON,
                                        var=0.2, ao=0.0, seed=43)))
    for dz_ in (-0.02, 0.025):  # thin cage bars across the glass
        for cx in (1, -1):
            parts.append(W("hips", _painted(L.tube(lp + Vector((cx * 0.041, -0.039, dz_)),
                                                   lp + Vector((cx * 0.041, 0.039, dz_)), 0.0035, 4), IRON,
                                            var=0.2, ao=0.0, seed=44)))
            parts.append(W("hips", _painted(L.tube(lp + Vector((-0.039, cx * 0.041, dz_)),
                                                   lp + Vector((0.039, cx * 0.041, dz_)), 0.0035, 4), IRON,
                                            var=0.2, ao=0.0, seed=44)))
    parts.append(W("hips", L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=lp, scale=(0.035, 0.035, 0.06))))
    parts.append(W("hips", L.part("torus", IRON, loc=lp + Vector((0, 0, 0.15)), rot=(90, 0, 90), major_radius=0.026,
                                  minor_radius=0.004, major_segments=10, minor_segments=4)))
    hook0 = _on_coat(1, 0.86, -18, 0.02)
    parts.append(W("hips", _painted(L.tube(hook0, lp + Vector((0, 0, 0.165)), 0.005, 5), IRON, var=0.2, ao=0.0,
                                    seed=45)))

    mesh = L.join(parts, rig.MESH)
    L.smooth(mesh, 55)
    return mesh, lp, shovel


def joints(dz: float) -> dict:
    """Bone head/tail from the model's proportions (dz = grounding shift)."""
    def p(x, y, z):
        return (x, y, z - dz)
    j = {
        "root": (p(0, 0, dz), p(0, 0, dz + 0.3)),
        "hips": (p(0, 0, 0.74), p(0, HUNCH * 0.1, 0.9)),
        "spine": (p(0, HUNCH * 0.1, 0.9), p(0, HUNCH * 0.95, 1.36)),
        "head": (p(0, HUNCH - 0.03, 1.37), p(0, HUNCH - 0.07, 1.72)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (p(sx * 0.25, HUNCH * 0.9, 1.22), p(sx * 0.31, HUNCH - 0.1, 0.8))
        j[_side(sx, "leg")] = (p(sx * 0.1, 0, 0.8), p(sx * 0.1, 0, 0.08))  # hip joint hidden in the coat
    j[TOOL] = (p(*SHOVEL_G0), p(*SHOVEL_G1))  # G7 Runde 2: the shovel's own bone (child of spine)
    return j


# --- actions (pose functions, see rig.py for the conventions) ---------------------

def idle(t: float) -> dict:
    """~2 s: slow breathing, the head sinks a little into the scarf."""
    return rig.breathe(t, 1.2)


def walk(t: float) -> dict:
    """16 frames = 0.53 s per cycle; 2 steps of ~0.8 m -> ~3 m/s (PlayerConfig 3.2). Hunched, brisk."""
    return rig.gait(t, leg=36.0, lift=0.06, arm=24.0, bob=0.03, roll=3.0, yaw=5.0, lean=7.0)


def _carry_arms(bounce: float) -> dict:
    """Both arms forward/down as if a body lies across the forearms in front."""
    return {"arm_l": (-50.0 + bounce, 14.0, 0.0), "arm_r": (-50.0 + bounce, -14.0, 0.0)}


def carry_idle(t: float) -> dict:
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.4), {"spine": (-5.0, 0.0, 0.0), "head": (3.0, 0.0, 0.0)},
                   _carry_arms(1.5 * s))


def carry_walk(t: float) -> dict:
    """20 frames = 0.67 s per cycle, shorter heavy steps (~2 m/s), waddling under the load."""
    c2 = math.cos(2.0 * rig.TAU * t)
    g = rig.gait(t, leg=29.0, lift=0.035, arm=0.0, bob=0.03, roll=5.0, yaw=3.0, lean=-4.0)
    return rig.add(g, _carry_arms(3.0 * c2), {"head": (4.0, 0.0, 0.0)})


def _stance() -> dict:
    return {"leg_l": (-9.0, 0.0, 0.0), "leg_r": (9.0, 0.0, 0.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}


def dig_bare(t: float) -> dict:
    """36 frames = 1.2 s, empty hands (the old dig; G7 Runde 2: now for axe / pickaxe / bare-handed
    work until those tools get their own clips): jab, lever, lift, toss to the right.
    (Arms hang from the spine: a forward bend swings them back, so they rotate
    further forward to keep the hands low in front.)"""
    wind = {"spine": (10.0, 0.0, 6.0), "head": (-4.0, 0.0, 0.0),
            "arm_l": (-62.0, 16.0, 0.0), "arm_r": (-48.0, -10.0, 0.0), "hips": (0, 0, 0, 0, 0.01, 0)}
    jab = {"spine": (32.0, 0.0, 0.0), "head": (-16.0, 0.0, 0.0),
           "arm_l": (-66.0, 14.0, 0.0), "arm_r": (-56.0, -8.0, 0.0), "hips": (4.0, 0, 0, 0, -0.02, -0.015)}
    lever = {"spine": (26.0, 0.0, 2.0), "head": (-12.0, 0.0, 0.0),
             "arm_l": (-44.0, 14.0, 0.0), "arm_r": (-62.0, -8.0, 0.0), "hips": (2.0, 0, 0, 0, -0.01, -0.01)}
    lift = {"spine": (14.0, 0.0, -4.0), "head": (-6.0, 0.0, 0.0),
            "arm_l": (-74.0, 18.0, 0.0), "arm_r": (-58.0, -6.0, 0.0)}
    toss = {"spine": (14.0, 0.0, -24.0), "head": (-2.0, 0.0, -10.0),
            "arm_l": (-88.0, 22.0, -14.0), "arm_r": (-60.0, 0.0, -20.0), "hips": (0, 0, -6.0, 0, 0.0, 0)}
    keys = [(0.0, wind), (0.28, jab), (0.45, lever), (0.62, lift), (0.8, toss)]
    return rig.add(_stance(), rig.keyed(t, keys))


def interact(t: float) -> dict:
    """24 frames = 0.8 s one-shot: lean in, reach forward with the right hand, back."""
    reach = {"spine": (14.0, 0.0, 4.0), "head": (-6.0, 0.0, 0.0),
             "arm_r": (-68.0, 10.0, 0.0), "arm_l": (-8.0, 0.0, 0.0), "hips": (0, 0, 0, 0, -0.03, 0)}
    return rig.add(rig.keyed(t, [(0.0, {}), (0.45, reach), (0.6, reach), (1.0, {})], wrap=False),
                   {"feet": {"leg_l": 0.0, "leg_r": 0.0}})


# --- G7 Runde 2: the shovel in the hands ----------------------------------------------
# The shovel hangs on its own bone "tool" (child of spine; rest = strapped to the back), so every
# other clip leaves it on the back. The shovel clips key it like every other bone: a pose may carry
#   "shovel": (tip x, y, z, elev, az, 0) - armature space: the blade's point and the direction from
#             it up the shaft to the D-grip (elev above the horizon, az: 0 = towards +Y (behind),
#             +90 = towards -X (his right); degrees)
#   "face":   (x, y, z)                  - which way the hollow of the blade faces (hint)
#   "grab":   (attach, w_r, w_l, s_r, s_l) - attach 0 = on the back .. 1 = at the "shovel" pose;
#             w_* = how firmly each hand holds the shaft (0 = the free arm pose, 1 = fist on the
#             shaft), s_* = where along the shaft (m from the D-grip end) it wants to hold.
# _hold() (rig.add_action post hook) places the tool bone and turns each holding arm so its fist
# sits on the shaft: the arms are rigid, so the fist stays at arm's length from the shoulder and
# slides along the shaft to the reachable point nearest s_*. The key poses were searched offline
# for both fists on the shaft, the right one near the D-grip, and the shaft clear of hat and body.

GRIP_BACK = 0.05                                  # D-grip centre behind the shaft end SHOVEL_G0
SHAFT = (SHOVEL_G1 - SHOVEL_G0).length            # shaft end to the blade socket
TIP = SHAFT + 0.34                                # shaft end to the blade's point
BLADE_MID = SHAFT + 0.2                           # centre of the blade (the earth clods leave here)
FIST = {sx: Vector((sx * 0.31, HUNCH - 0.122, 0.718)) for sx in (-1, 1)}   # fist centre at rest
_D0 = (SHOVEL_G1 - SHOVEL_G0).normalized()
SHOVEL_NORMAL = _frame(SHOVEL_G0, _D0, (0, 1, 0)).col[2].to_3d()            # blade hollow at rest
_DEBUG = None


def _up(elev: float, az: float) -> Vector:
    e, a = math.radians(elev), math.radians(az)
    return Vector((-math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))


def _spec(grip, aim) -> tuple:
    """(tip, elev, az) form of a shovel with its D-grip at `grip`, the shaft pointing at `aim`."""
    d = (Vector(aim) - Vector(grip)).normalized()
    tip = Vector(grip) + d * (GRIP_BACK + TIP)
    up = -d
    return (tip.x, tip.y, tip.z, math.degrees(math.asin(max(-1.0, min(1.0, up.z)))),
            math.degrees(math.atan2(-up.x, up.y)), 0.0)


def _spec_matrix(sv, face) -> Matrix:
    up = _up(sv[3], sv[4])
    return _frame(Vector(sv[:3]) + up * TIP, -up, Vector(face[:3]))


def _rest_tool(arm) -> Matrix:
    """The tool bone where the spine carries it (on the back) in the current pose."""
    sp = arm.pose.bones["spine"]
    return sp.matrix @ arm.data.bones["spine"].matrix_local.inverted() @ arm.data.bones[TOOL].matrix_local


def _mix(a: Matrix, b: Matrix, w: float) -> Matrix:
    if w <= 0.0:
        return a.copy()
    if w >= 1.0:
        return b.copy()
    m = a.to_quaternion().slerp(b.to_quaternion(), w).to_matrix().to_4x4()
    m.translation = a.translation.lerp(b.translation, w)
    return m


def _shaft_point(origin: Vector, d: Vector, centre: Vector, radius: float, s_pref: float, s_last=None) -> tuple:
    """Where along the shaft (origin + s d) a fist at `radius` from `centre` holds it: of the (up to
    two) reachable points the one nearest to where it held last frame (s_last; the hand slides, it
    never jumps) and to s_pref, clamped to the shaft [-GRIP_BACK, SHAFT + 0.06] (the iron socket);
    out of reach: the nearest shaft point. Returns (s, miss in m)."""
    lo, hi = -GRIP_BACK, SHAFT + 0.06
    o = origin - centre
    b = d.dot(o)
    disc = b * b - (o.dot(o) - radius * radius)
    roots = [-b] if disc < 0.0 else [-b - math.sqrt(disc), -b + math.sqrt(disc)]
    ref = s_pref if s_last is None else s_last

    def cost(x):
        return abs(x - ref) + 0.3 * abs(x - s_pref)
    s = min(max(min(roots, key=cost), lo), hi)
    return s, abs((o + d * s).length - radius)


def _fist(arm, bone: str) -> Vector:
    pb = arm.pose.bones[bone]
    return pb.matrix @ arm.data.bones[bone].matrix_local.inverted() @ FIST[1 if bone == "arm_l" else -1]


def _aim_arm(arm, bone: str, target: Vector, w: float) -> None:
    pb = arm.pose.bones[bone]
    head = pb.head.copy()
    q = Quaternion().slerp((_fist(arm, bone) - head).rotation_difference(target - head), w)
    pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def _hold(pose_fn):
    """rig.add_action post hook for the shovel clips (see above)."""
    last = {}

    def post(arm, t):
        if t <= 0.0:
            last.clear()
        pose = pose_fn(t)
        if "grab" not in pose:
            return
        attach, w_r, w_l, s_r, s_l = tuple(pose["grab"])[:5]
        # the right fist leads: it reaches for the shaft point s_r of the wanted placement, and the
        # shovel then sits in the fist where it actually arrived (rigid arms cannot always reach
        # exactly; the shovel follows the hand instead of the hand missing the shaft)
        m = _mix(_rest_tool(arm), _spec_matrix(pose["shovel"], pose["face"]), attach)
        d = m.col[1].to_3d().normalized()
        if w_r > 0.001:
            _aim_arm(arm, "arm_r", m.translation + d * s_r, w_r)
            held = m.copy()
            held.translation = _fist(arm, "arm_r") - d * s_r
            m = _mix(m, held, attach * w_r)
        arm.pose.bones[TOOL].matrix = m
        bpy.context.view_layer.update()
        origin = m.translation.copy()
        if w_l > 0.001:
            radius = (FIST[1] - arm.data.bones["arm_l"].head_local).length
            s, miss = _shaft_point(origin, d, arm.pose.bones["arm_l"].head, radius, s_l, last.get("arm_l"))
            last["arm_l"] = s
            _aim_arm(arm, "arm_l", origin + d * s, w_l)
            if _DEBUG is not None:
                _DEBUG.append((t, "arm_l", round(s, 3), round(miss, 3)))
        else:
            last.pop("arm_l", None)
    return post


def _sh(spec, face, grab) -> dict:
    return {"shovel": tuple(spec), "face": tuple(face), "grab": tuple(grab) + (0.0,)}


_REST = _spec(SHOVEL_G0 - _D0 * GRIP_BACK, SHOVEL_G1)
_TWO = (1.0, 1.0, 1.0, 0.0, 0.45)                 # both fists: right at the D-grip, left lower down
_TOWARDS_HIM = (0.0, 1.0, 0.25)                   # hollow towards him (the earth stays on when levering)


def _body(spine: float, twist: float = 0.0, head: float = None, **more) -> dict:
    """Upper-body bend (rx) and twist (rz) of the spine, the head counter-bending to keep the gaze."""
    pose = {"spine": (spine, 0.0, twist), "head": (-(spine * 0.55) if head is None else head, 0.0, -twist * 0.4)}
    pose.update(more)
    return pose


def _dig_ready() -> dict:
    return rig.add(_body(14.0), {"arm_r": (-70.0, 0.0, 0.0), "arm_l": (-60.0, 0.0, 0.0)},
                   _sh((0.3, -0.42, 0.05, 70.0, 120.0, 0.0), _TOWARDS_HIM, _TWO))


def dig(t: float) -> dict:
    """39 frames = 1.3 s, the shovel in both hands: the blade jabs into the earth beside his left
    foot, the left foot treads it in, the scoop lifts the earth and throws it off to the left
    (the earth clods leave at DIG_TOSS of the cycle, the jab sounds at DIG_JAB)."""
    ready = _dig_ready()
    jab = rig.add(_body(22.0), {"hips": (3.0, 0, 0, 0, -0.01, -0.02)},
                  _sh((0.25, -0.4, -0.08, 75.0, 135.0, 0.0), _TOWARDS_HIM, _TWO))
    tread = rig.add(_body(20.0, -10.0), {"hips": (3.0, 0, 0, 0, -0.01, -0.01), "leg_l": (-18.0, -6.0, 0.0),
                                         "feet": {"leg_l": 0.11, "leg_r": 0.0}},
                    _sh((0.3, -0.4, -0.2, 75.0, 120.0, 0.0), _TOWARDS_HIM, _TWO))
    pry = rig.add(_body(18.0, -6.0), {"hips": (1.0, 0, 0, 0, 0.0, -0.01)},
                  _sh((0.42, -0.5, 0.12, 60.0, 100.0, 0.0), (0.0, 0.6, 1.0), _TWO))
    lift = rig.add(_body(14.0, -10.0),
                   _sh((0.55, -0.6, 0.4, 45.0, 90.0, 0.0), (0.0, 0.0, 1.0), _TWO))
    toss = rig.add(_body(14.0, 20.0), {"hips": (0, 0, 6.0, 0, 0.0, 0)},
                   _sh((0.65, -0.5, 0.8, 10.0, 75.0, 0.0), (1.0, 0.0, 0.6), _TWO))
    back = rig.add(_body(14.0, 6.0),
                   _sh((0.45, -0.48, 0.4, 50.0, 100.0, 0.0), (0.0, 0.3, 1.0), _TWO))
    keys = [(0.0, ready), (DIG_JAB, jab), (0.32, tread), (0.46, pry), (0.6, lift), (DIG_TOSS, toss), (0.9, back)]
    return rig.add(_stance(), rig.keyed(t, keys))


DIG_JAB = 0.16
DIG_TOSS = 0.78


def _draw_keys() -> list:
    """Back -> hands: the right hand reaches back over the shoulder to the socket, pulls the shovel up
    and round the right side (blade up like a staff), tips the blade forward and down while the left
    hand catches the shaft (= the first dig pose)."""
    st = _stance()
    rest = rig.add(st, {"leg_l": (9.0, 0.0, 0.0), "leg_r": (-9.0, 0.0, 0.0)},   # feet together as at rest
                   _sh(_REST, SHOVEL_NORMAL, (0.0, 0.0, 0.0, 0.95, 0.45)))
    reach = rig.add(st, _body(4.0, 8.0, head=2.0), {"arm_r": (30.0, 0.0, 20.0)},
                    _sh(_REST, SHOVEL_NORMAL, (0.0, 1.0, 0.0, SHAFT + 0.03, 0.45)))
    staff = rig.add(st, _body(6.0, 4.0), {"arm_l": (-20.0, 0.0, 0.0)},
                    _sh(_spec((-0.42, 0.05, 0.62), (-0.42, -0.15, 2.0)), (0.0, -1.0, 0.0), (1.0, 1.0, 0.0, 0.5, 0.45)))
    tip = rig.add(st, _body(10.0), {"arm_l": (-45.0, 0.0, 0.0)},
                  _sh(_spec((-0.3, -0.2, 1.05), (-0.05, -1.2, 0.25)), (0.0, 0.3, 1.0), (1.0, 1.0, 0.6, 0.25, 0.6)))
    return [rest, reach, staff, tip, rig.add(st, _dig_ready())]


def shovel_draw(t: float) -> dict:
    """15 frames = 0.5 s one-shot: from the back into both hands (ends in the first dig pose)."""
    rest, reach, staff, tip, ready = _draw_keys()
    return rig.keyed(t, [(0.0, rest), (0.32, reach), (0.58, staff), (0.8, tip), (1.0, ready)], wrap=False)


def shovel_stow(t: float) -> dict:
    """12 frames = 0.4 s one-shot: the draw backwards (first dig pose -> on the back, at rest)."""
    rest, reach, staff, tip, ready = _draw_keys()
    return rig.keyed(t, [(0.0, ready), (0.22, tip), (0.45, staff), (0.72, reach), (1.0, rest)], wrap=False)


def shovel_stow_walk(t: float) -> dict:
    """16 frames = one walk cycle (0.53 s) one-shot: stowing while already walking off (the action was
    cancelled by moving). Ends exactly in walk's first frame, so walk continues seamlessly."""
    g = walk(t)
    upper = shovel_stow(min(1.0, t / 0.85))
    out = dict(g)
    fade = rig.ease((t - 0.7) / 0.3)   # the arms settle into the walk swing at the end
    for bone in ("arm_l", "arm_r"):
        a = tuple(upper.get(bone, rig.ZERO)) + rig.ZERO[len(upper.get(bone, rig.ZERO)):]
        b = tuple(g.get(bone, rig.ZERO)) + rig.ZERO[len(g.get(bone, rig.ZERO)):]
        out[bone] = tuple(x + (y - x) * fade for x, y in zip(a, b))
    out["shovel"], out["face"] = upper["shovel"], upper["face"]
    out["grab"] = tuple(v * (1.0 - fade) if i in (1, 2) else v for i, v in enumerate(upper["grab"]))
    return out


# --- G7 Runde 2 (Bestatten): laying the dead into the grave ---------------------------------
# The corpse itself is moved by code (PlayerBurial): from the arms down onto the pit floor while
# the hands go down with it. Rigid arms, no knees: he bows from the hips (the hips sink and slide
# back, the planted legs read as bent knees), the arms swing down in front of him.

def _lower_keys() -> tuple:
    carry = carry_idle(0.0)
    lean = rig.add(_stance(), _body(14.0), {"arm_l": (-62.0, 14.0, 0.0), "arm_r": (-62.0, -14.0, 0.0)})
    bow = rig.add(_stance(), {"spine": (50.0, 0.0, 0.0), "head": (-20.0, 0.0, 0.0),
                              "hips": (6.0, 0.0, 0.0, 0.0, 0.03, -0.09),
                              "arm_l": (-64.0, 12.0, 0.0), "arm_r": (-64.0, -12.0, 0.0)})
    let = rig.add(_stance(), {"spine": (54.0, 0.0, 0.0), "head": (-12.0, 0.0, 0.0),
                              "hips": (6.0, 0.0, 0.0, 0.0, 0.03, -0.1),
                              "arm_l": (-52.0, 8.0, 0.0), "arm_r": (-52.0, -8.0, 0.0)})
    return carry, lean, bow, let


def corpse_lower(t: float) -> dict:
    """54 frames = 1.8 s one-shot (ToolAnimConfig.burial_lower_seconds): from carrying, he leans
    over the open grave and bows deep with the dead on his lowered arms, lets go and stays bowed
    (the corpse sinks onto the pit floor, PlayerBurial)."""
    carry, lean, bow, let = _lower_keys()
    return rig.keyed(t, [(0.0, carry), (0.22, lean), (0.58, bow), (0.82, let), (1.0, let)], wrap=False)


def mourn(t: float) -> dict:
    """30 frames = 1.0 s one-shot (burial_silence_seconds): a moment of silence - he straightens up
    from the bow, the hands folded low in front, the head bowed; ends at rest (the shovel draw
    starts from there)."""
    let = _lower_keys()[3]
    bowed = {"spine": (6.0, 0.0, 0.0), "head": (22.0, 0.0, 0.0),
             "arm_l": (-24.0, 16.0, 0.0), "arm_r": (-24.0, -16.0, 0.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    rest = {"feet": {"leg_l": 0.0, "leg_r": 0.0}}
    return rig.keyed(t, [(0.0, let), (0.35, bowed), (0.82, bowed), (1.0, rest)], wrap=False)


ACTIONS = (  # (name, frames at 30 fps, pose function[, post hook])
    ("idle-loop", 60, idle),
    ("walk-loop", 16, walk),
    ("carry_idle-loop", 60, carry_idle),
    ("carry_walk-loop", 20, carry_walk),
    ("dig-loop", 39, dig, _hold(dig)),
    ("dig_bare-loop", 36, dig_bare),
    ("shovel_draw", 15, shovel_draw, _hold(shovel_draw)),
    ("shovel_stow", 12, shovel_stow, _hold(shovel_stow)),
    ("shovel_stow_walk", 16, shovel_stow_walk, _hold(shovel_stow_walk)),
    ("interact", 24, interact),
    ("corpse_lower", 54, corpse_lower),
    ("mourn", 30, mourn),
)


def _attach_shovel(arm, shovel) -> None:
    """The shovel mesh follows the tool bone (glTF: a node below the joint -> BoneAttachment3D)."""
    shovel.parent = arm
    shovel.parent_type = "BONE"
    shovel.parent_bone = TOOL
    bpy.context.view_layer.update()
    shovel.matrix_world = Matrix.Identity(4)


def build(debug: bool = False):
    global _DEBUG
    _DEBUG = [] if debug else None
    mesh, lp, shovel = build_mesh()
    dz = rig.ground(mesh)
    assert abs(dz) < 1e-3, f"soles should stand on z = 0 (shift {dz})"  # keeps the approved lantern position
    arm = rig.build_armature(joints(dz), extra={TOOL: ("spine", SHOVEL_NORMAL)})
    rig.bind(mesh, arm)
    _attach_shovel(arm, shovel)
    rig.bone_marker(arm, "hips", "light_lantern", lp - Vector((0, 0, dz)))
    rig.bone_marker(arm, TOOL, "shovel_blade", SHOVEL_G0 + _D0 * BLADE_MID)
    import asset_character_tools as T  # G7 Runde 2 Werkzeuge (imports this module)
    tools = T.build_tools()
    T.attach(arm, tools)
    for entry in ACTIONS + tuple(T.actions()):
        name, frames, fn = entry[:3]
        rig.add_action(arm, mesh, name, frames, fn, entry[3] if len(entry) > 3 else None)
    if debug:
        return arm, mesh, shovel, tools
    L.export_rigged(arm, NAME, "characters")
    F._stable_glb(L.os.path.join(L.ROOT, "assets", "models", "characters", NAME + ".glb"))


if __name__ == "__main__":
    build()
