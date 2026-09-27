"""Osric Faulhaber, the corpse carter (NPC). Same painted style and palette as
the gravekeeper, but the opposite silhouette: short (~1.65 m), stout and broad,
upright. Flat cap, leather apron over a muted linen shirt with rolled sleeves,
dark trousers, big boots, bushy grey-brown beard, a pipe.
Front faces -Y (Blender) = +Z (Godot). Shared rig (rig.py); actions
idle-loop, walk-loop, push_cart-loop, talk-loop.
Change round 1 (G2): same identity, bones, poses and proportions, refined forms:
smooth lofted body, face with brows/cheeks/ears, lobed beard with strands and a
drooping moustache, a real pipe bowl with a tiny ember, flat cap with a stiff
peak and a stitched patch, apron with pocket, buckled belt and back straps,
faded-blue neckerchief, chunky laced boots and mitten hands."""
import math

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Vector, noise

import lib_painted as L
import rig

NAME = "ph_chr_carter"

SHIRT = L.hexc("#9A907A")
SHIRT_DARK = L.hexc("#7C735F")
SHIRT_WARM = L.hexc("#A89A78")
APRON = L.hexc("#5E4433")
APRON_DARK = L.hexc("#3F2E24")
APRON_WORN = L.hexc("#806148")
TROUSER = L.hexc("#3A3733")
TROUSER_COOL = L.hexc("#30353B")
BOOT = L.hexc("#2E251F")
BOOT_WORN = L.hexc("#4E3E31")
SOLE = L.hexc("#1D1815")
SKIN = L.hexc("#C99D7E")
SKIN_ROSY = L.hexc("#C98470")
NOSE = L.hexc("#C4866F")
NOSE_TIP = L.hexc("#B86F5E")
BEARD = L.hexc("#7D6D5B")
BEARD_GREY = L.hexc("#9A9284")
BEARD_LIGHT = L.hexc("#ADA597")
BEARD_MID = L.hexc("#8C8171")
LIP = L.hexc("#A86A5C")
MOUSTACHE = L.hexc("#A0937A")   # yellowed by pipe smoke
CAP = L.hexc("#5A5044")
CAP_DARK = L.hexc("#3A3530")
CAP_PATCH = L.hexc("#74674F")
STITCH = L.hexc("#26221F")
PIPE = L.hexc("#4A3324")
PIPE_DARK = L.hexc("#2A1E17")
ASH = L.hexc("#4A4644")
STRAP = L.hexc("#2C231D")
BRASS = L.hexc("#8C7648")
NECKERCHIEF = L.hexc("#5E6F7C")   # faded blue (muted – cold saturation is reserved for the supernatural)
NECKERCHIEF_DARK = L.hexc("#4A5763")
RAG = L.hexc("#B39463")
PAPER = L.hexc("#CBBF9F")
EYE = L.hexc("#1B1715")
GLEAM = L.hexc("#E9E2D2")

WAIST_Z = 0.86   # shirt and apron below -> hips, above -> spine (under the belt)
HEAD_C = Vector((0.0, -0.035, 1.435))
W = rig.weight

# torso profile: (height, x radius, y radius, forward belly offset) – smooth (Catmull-Rom) in between
TORSO = ((0.60, 0.235, 0.20, -0.01), (0.70, 0.285, 0.238, -0.03), (0.80, 0.308, 0.257, -0.045),
         (0.92, 0.318, 0.268, -0.05), (1.02, 0.314, 0.262, -0.04), (1.12, 0.300, 0.250, -0.012),
         (1.20, 0.272, 0.226, 0.0), (1.27, 0.222, 0.186, 0.01), (1.31, 0.15, 0.13, 0.01))


# --- helpers ------------------------------------------------------------------------

def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _thicken(obj, thickness: float) -> None:
    """Give a sheet (apron, pocket, peak) a closed back side and rim."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
    bm.to_mesh(obj.data)
    bm.free()


def _obj(bm, name: str):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _fan(bm, ring, centre, flip: bool) -> None:
    c = bm.verts.new(centre)
    n = len(ring)
    for k in range(n):
        a, b = ring[k], ring[(k + 1) % n]
        bm.faces.new((c, b, a) if flip else (c, a, b))


def _bridge(bm, r0, r1) -> None:
    n = len(r0)
    for k in range(n):
        bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))


def loft(rings, n: int = 24, p: float = 2.0, caps=(True, True), name: str = "loft"):
    """Closed body from horizontal (super)ellipse rings [(z, rx, ry, cx, cy), ...]."""
    bm = bmesh.new()
    rows = []
    for z, rx, ry, cx, cy in rings:
        row = []
        for k in range(n):
            a = math.tau * k / n
            c, s = math.cos(a), math.sin(a)
            x = math.copysign(abs(c) ** (2.0 / p), c)
            y = math.copysign(abs(s) ** (2.0 / p), s)
            row.append(bm.verts.new((cx + rx * x, cy + ry * y, z)))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        _bridge(bm, r0, r1)
    if caps[0]:
        z, _, _, cx, cy = rings[0]
        _fan(bm, rows[0], (cx, cy, z), True)
    if caps[-1]:
        z, _, _, cx, cy = rings[-1]
        _fan(bm, rows[-1], (cx, cy, z), False)
    return _obj(bm, name)


def sweep(pts, radius, n: int = 8, normals=None, flat: float = 1.0, closed: bool = False, name: str = "sweep"):
    """Tube along a polyline. radius: float or one per point; normals (optional, one per
    point) orient flat straps (flat < 1 = thickness along the normal)."""
    pts = [Vector(q) for q in pts]
    m = len(pts)
    rs = list(radius) if isinstance(radius, (list, tuple)) else [radius] * m
    bm = bmesh.new()
    rows = []
    prev = None
    for i, q in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % m] - pts[(i - 1) % m]).normalized()
        else:
            t = (pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]).normalized()
        if normals is not None:
            nv = Vector(normals[i])
        else:
            nv = prev if prev is not None else t.orthogonal()
        nv = (nv - t * nv.dot(t)).normalized()
        prev = nv
        b = t.cross(nv)
        rows.append([bm.verts.new(q + nv * math.cos(a) * rs[i] * flat + b * math.sin(a) * rs[i])
                     for a in (math.tau * k / n for k in range(n))])
    for r0, r1 in zip(rows, rows[1:]):
        _bridge(bm, r0, r1)
    if closed:
        _bridge(bm, rows[-1], rows[0])
    else:
        _fan(bm, rows[0], pts[0], True)
        _fan(bm, rows[-1], pts[-1], False)
    return _obj(bm, name)


def _loops(obj):
    """(loop index, vertex co, polygon normal) of every face corner."""
    me = obj.data
    for poly in me.polygons:
        for li in poly.loop_indices:
            yield li, me.vertices[me.loops[li].vertex_index].co, poly.normal


def _tint(obj, fn) -> None:
    """Post-paint: fn(co, normal) -> (brightness factor, colour or None, mix amount)."""
    attr = obj.data.color_attributes["Col"]
    for li, co, nrm in _loops(obj):
        f, col, amt = fn(co, nrm)
        c = attr.data[li].color
        rgb = [c[0] * f, c[1] * f, c[2] * f]
        if col is not None and amt > 0.0:
            lin = [L._to_lin(x) for x in col]
            rgb = [a + (b - a) * min(1.0, amt) for a, b in zip(rgb, lin)]
        attr.data[li].color = (min(1.0, rgb[0]), min(1.0, rgb[1]), min(1.0, rgb[2]), 1.0)


def _n(co, freq: float, seed: float = 0.0) -> float:
    return noise.noise(co * freq + Vector((seed, seed * 0.7, seed * 1.3)))


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


def _profile(z: float) -> tuple:
    """Torso radii/offset at height z (Catmull-Rom through the TORSO rings)."""
    if z <= TORSO[0][0]:
        return TORSO[0][1:]
    if z >= TORSO[-1][0]:
        return TORSO[-1][1:]
    for i in range(len(TORSO) - 1):
        z0, z1 = TORSO[i][0], TORSO[i + 1][0]
        if z <= z1:
            t = (z - z0) / (z1 - z0)
            p0, p1 = TORSO[max(0, i - 1)][1:], TORSO[i][1:]
            p2, p3 = TORSO[i + 1][1:], TORSO[min(len(TORSO) - 1, i + 2)][1:]
            return tuple(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                                + (-a + 3 * b - 3 * c + d) * t ** 3) for a, b, c, d in zip(p0, p1, p2, p3))
    return TORSO[-1][1:]


def _front_y(x: float, z: float) -> float:
    """y of the torso's front surface at (x, z)."""
    rx, ry, off = _profile(z)
    k = min(0.98, abs(x) / rx)
    return off - ry * math.sqrt(1.0 - k * k)


def _back_y(x: float, z: float) -> float:
    rx, ry, off = _profile(z)
    k = min(0.98, abs(x) / rx)
    return off + ry * math.sqrt(1.0 - k * k)


def _out(x: float, z: float) -> Vector:
    """Outward horizontal normal of the torso at (x, z) (front side)."""
    rx, ry, off = _profile(z)
    y = _front_y(x, z) - off
    return Vector((x / (rx * rx), y / (ry * ry), 0.0)).normalized()


# --- body parts ---------------------------------------------------------------------

def _boots_and_legs(parts) -> None:
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.13
        # thick sole with a heel step, rounded toe (superellipse)
        sole = loft([(-0.005, 0.098, 0.19, x0, -0.07), (0.012, 0.104, 0.196, x0, -0.07),
                     (0.03, 0.1, 0.19, x0, -0.07)], n=20, p=2.6, name="sole")
        parts.append(W(leg, _painted(sole, SOLE, var=0.1, ao=0.0, top=0.05, seed=20 + sx)))
        # chunky foot with a bulbous toe cap
        foot = L.part("sphere", BOOT, loc=(x0, -0.08, 0.075), scale=(0.1, 0.18, 0.075), segments=14, ring_count=8,
                      jit=0.006, seed=21 + sx, paint_kw={"var": 0.14, "ao": 0.1, "top": 0.2})
        for v in foot.data.vertices:  # flat underside on the sole, higher toe box
            v.co.z = max(v.co.z, 0.03)
            if v.co.y < -0.12:
                v.co.z += 0.012 * (-0.12 - v.co.y) / 0.14
        _tint(foot, lambda co, nr: (1.0, BOOT_WORN, 0.55 * max(0.0, (-co.y - 0.17) / 0.08) * (0.6 + 0.4 * _n(co, 20))))
        parts.append(W(leg, foot))
        # boot shaft around the ankle
        shaft = loft([(0.05, 0.086, 0.09, x0, 0.0), (0.13, 0.082, 0.086, x0, -0.005),
                      (0.22, 0.086, 0.088, x0, 0.0), (0.245, 0.09, 0.092, x0, 0.0)], n=16, name="shaft")
        parts.append(W(leg, _painted(shaft, BOOT, var=0.16, ao=0.25, top=0.1, seed=22, hue_shift=BOOT_WORN)))
        # tongue + criss-cross laces on the instep
        tongue = L.part("cube", BOOT_WORN, loc=(x0, -0.095, 0.14), scale=(0.035, 0.012, 0.075), rot=(-28, 0, 0))
        parts.append(W(leg, tongue))
        for k in range(3):
            z = 0.1 + k * 0.042
            y = -0.083 - 0.022 * (2 - k) - 0.012
            for d in (-1, 1):
                parts.append(W(leg, L.part("cube", STRAP, loc=(x0, y, z), scale=(0.038, 0.006, 0.006),
                                           rot=(-28, 0, d * 24))))
        # sturdy trouser leg, a little bulge at the knee, bunched over the boot
        top = Vector((sx * 0.12, 0.0, 0.74))
        pts = [Vector((x0, 0.0, 0.2)), Vector((sx * 0.128, -0.005, 0.32)), Vector((sx * 0.126, -0.012, 0.44)),
               Vector((sx * 0.123, -0.006, 0.58)), top]
        trouser = sweep(pts, [0.088, 0.086, 0.09, 0.092, 0.098], n=14, name="trouser")
        parts.append(W(leg, _painted(trouser, TROUSER, var=0.15, ao=0.3, top=0.1, seed=23, hue_shift=TROUSER_COOL)))
        cuff = L.part("torus", TROUSER, loc=(x0, 0.0, 0.225), major_radius=0.09, minor_radius=0.022,
                      major_segments=14, minor_segments=5, jit=0.006, seed=24 + sx,
                      paint_kw={"var": 0.16, "ao": 0.0, "hue_shift": TROUSER_COOL})
        parts.append(W(leg, cuff))
    # seat of the trousers
    parts.append(W("hips", L.part("sphere", TROUSER, loc=(0, 0.0, 0.645), scale=(0.245, 0.175, 0.12), segments=14,
                                  ring_count=8, jit=0.008, seed=24, paint_kw={"hue_shift": TROUSER_COOL})))


def _torso(parts) -> None:
    rings = []
    z = 0.6
    while z < 1.305:
        rx, ry, off = _profile(z)
        rings.append((z, rx, ry, 0.0, off))
        z += 0.045
    rings.append((1.33, 0.08, 0.07, 0.0, 0.01))
    torso = loft(rings, n=26, name="torso")
    L.jitter(torso, 0.008, 3.0, 25)

    def folds(co, nr):
        # soft shirt folds gathered at the belt and under the arms
        a = math.atan2(co.y, co.x)
        near = max(0.0, 1.0 - abs(co.z - WAIST_Z - 0.06) / 0.12)
        f = 1.0 - 0.07 * near * max(0.0, math.sin(a * 11.0 + co.z * 9.0))
        # back yoke seam and a few long drag folds from the shoulder blades to the belt
        if co.y > 0.05:
            if abs(co.z - (1.18 - 0.12 * (co.x / 0.3) ** 2)) < 0.007:
                f *= 0.8
            f *= 1.0 - 0.06 * max(0.0, math.sin(co.x * 38.0 + co.z * 4.0)) * max(0.0, min(1.0, (1.12 - co.z) / 0.2))
        return f, SHIRT_WARM, 0.25 * max(0.0, nr.z) + 0.1 * max(0.0, _n(co, 5.0, 3.0))
    _painted(torso, SHIRT, var=0.14, ao=0.3, top=0.12, zrange=(0.6, 1.3), seed=26, hue_shift=SHIRT_DARK)
    _tint(torso, folds)
    parts.append(rig.weight_split_z(torso, WAIST_Z, "hips", "spine"))
    parts.append(W("spine", L.part("sphere", SHIRT, loc=(0, 0.02, 1.2), scale=(0.25, 0.21, 0.14), segments=16,
                                   ring_count=8, jit=0.006, seed=45, paint_kw={"ao": 0.2, "hue_shift": SHIRT_DARK})))
    for sx in (-1, 1):  # shoulders
        parts.append(W("spine", L.part("sphere", SHIRT, loc=(sx * 0.26, 0.0, 1.22), radius=0.11, segments=14,
                                       ring_count=8, scale=(1.0, 0.95, 0.85), jit=0.006, seed=27,
                                       paint_kw={"top": 0.18, "hue_shift": SHIRT_WARM})))
    # shirt collar under the beard
    collar = sweep([Vector((0.1 * math.cos(a), -0.02 + 0.095 * math.sin(a), 1.315)) for a in
                    (math.tau * k / 12 for k in range(12))], 0.022, n=5, closed=True, name="collar")
    parts.append(W("spine", _painted(collar, SHIRT_WARM, var=0.1, ao=0.0, seed=46)))


def _neckerchief(parts) -> None:
    ring = [Vector((0.12 * math.cos(a), -0.025 + 0.112 * math.sin(a), 1.3 - 0.014 * math.sin(a)))
            for a in (math.tau * k / 16 for k in range(16))]
    nk = sweep(ring, 0.034, n=8, closed=True, name="neckerchief")
    L.jitter(nk, 0.008, 6.0, 47)
    parts.append(W("spine", _painted(nk, NECKERCHIEF, var=0.2, ao=0.1, top=0.2, seed=47, hue_shift=NECKERCHIEF_DARK)))
    knot = Vector((0.118, -0.118, 1.268))
    parts.append(W("spine", L.part("sphere", NECKERCHIEF, loc=knot, radius=0.038, segments=10, ring_count=6,
                                   scale=(0.9, 0.8, 0.95), jit=0.007, jfreq=6.0, seed=48,
                                   paint_kw={"hue_shift": NECKERCHIEF_DARK, "var": 0.2, "top": 0.25})))
    for dx, dz, w, sd in ((0.022, -0.078, 0.027, 49), (-0.012, -0.07, 0.023, 50)):  # two tails over the chest
        x1 = knot.x + dx
        z1 = knot.z + dz
        xm, zm = knot.x + dx * 0.5, knot.z + dz * 0.55
        pts = [knot + Vector((0.0, -0.01, 0.0)), Vector((xm, _front_y(xm, zm) - 0.04, zm)),
               Vector((x1, _front_y(x1, z1) - 0.042, z1))]
        tail = sweep(pts, [w, w * 0.95, w * 0.4], n=6,
                     normals=[_out(knot.x, knot.z), _out(xm, zm), _out(x1, z1)], flat=0.5, name="tail")
        parts.append(W("spine", _painted(tail, NECKERCHIEF, var=0.2, ao=0.1, top=0.2, seed=sd,
                                         hue_shift=NECKERCHIEF_DARK)))


def _apron_sheet(u0, u1, w0, w1, nu, nw, lift: float, name: str):
    """Grid on the apron surface (u across 0..1, w bottom->top 0..1), lifted outwards by `lift`."""
    bm = bmesh.new()
    rows = []
    for j in range(nw + 1):
        w = w0 + (w1 - w0) * j / nw
        row = []
        for i in range(nu + 1):
            u = u0 + (u1 - u0) * i / nu
            row.append(bm.verts.new(_apron_point(u, w, lift)))
        rows.append(row)
    for j in range(nw):
        for i in range(nu):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    return _obj(bm, name)


def _apron_point(u: float, w: float, lift: float = 0.0) -> Vector:
    z = 0.44 + w * (1.2 - 0.44)
    half = 0.29 - 0.12 * max(0.0, (z - 0.95) / 0.25)   # the bib is narrower than the skirt
    x = (u - 0.5) * 2.0 * half
    if z > 1.17:  # rounded bib corners
        x *= 1.0 - 0.25 * ((z - 1.17) / 0.03) ** 2 * abs(u - 0.5) * 2.0
    zs = max(z, 0.7)                                    # below the belly the leather hangs straight down
    y = _front_y(x, zs) - 0.018 - (0.022 * (0.7 - z) / 0.26 if z < 0.7 else 0.0)
    if z < 0.7:  # gentle vertical waves in the hanging skirt
        y += 0.008 * math.sin(u * math.tau * 2.0 + 0.6) * (0.7 - z) / 0.26
    y -= lift
    return Vector((x, y, z))


def _apron(parts) -> None:
    apron = _apron_sheet(0.0, 1.0, 0.0, 1.0, 12, 18, 0.0, "apron")
    for v in apron.data.vertices:  # a slightly uneven, worn hem
        if v.co.z < 0.46:
            v.co.z += 0.01 * noise.noise(Vector((v.co.x * 9.0, 0.0, 2.0)))
    L.jitter(apron, 0.004, 4.0, 28)
    _thicken(apron, 0.014)
    L.paint(apron, APRON, var=0.22, ao=0.25, top=0.15, hue_shift=APRON_DARK, seed=29)

    def wear(co, nr):
        rx = _profile(max(co.z, 0.7))[0]
        half = 0.29 - 0.12 * max(0.0, (co.z - 0.95) / 0.25)
        edge = max(0.0, 1.0 - (half - abs(co.x)) / 0.035) if co.z < 1.2 else 0.0
        hem = max(0.0, 1.0 - (co.z - 0.44) / 0.05)
        top = max(0.0, 1.0 - (1.2 - co.z) / 0.03)
        scuff = max(0.0, _n(co, 14.0, 5.0) - 0.25) * 1.2
        amt = min(0.8, (max(edge, hem, top) * 0.7 + scuff * 0.4) * (0.7 + 0.3 * _n(co, 30.0, 2.0)))
        del rx
        return 1.0, APRON_WORN, amt
    _tint(apron, wear)
    L.set_mat(apron, L.MAT_PAINTED)
    parts.append(rig.weight_split_z(apron, WAIST_Z, "hips", "spine"))
    # patch pocket on his left, with a folded delivery note sticking out
    pocket = _apron_sheet(0.56, 0.84, 0.18, 0.36, 5, 5, 0.012, "pocket")
    _thicken(pocket, 0.008)
    L.paint(pocket, APRON_DARK, var=0.2, ao=0.0, top=0.2, hue_shift=APRON, seed=51)
    pz0, pz1 = 0.44 + 0.18 * 0.76, 0.44 + 0.36 * 0.76

    def pocket_rim(co, nr):
        rim = max(0.0, 1.0 - (pz1 - co.z) / 0.015)
        dash = 1.0 if math.sin(co.x * 260.0) > 0.3 and abs(co.z - (pz1 - 0.018)) < 0.004 else 0.0
        return 1.0 - 0.45 * dash, APRON_WORN, 0.6 * rim
    _tint(pocket, pocket_rim)
    L.set_mat(pocket, L.MAT_PAINTED)
    parts.append(W("hips", pocket))
    note = _apron_point(0.66, 0.36, 0.02)
    parts.append(W("hips", L.part("cube", PAPER, loc=note + Vector((0, 0.004, 0.012)), scale=(0.028, 0.004, 0.034),
                                  rot=(0, -12, 0), paint_kw={"var": 0.08, "ao": 0.2})))
    # buckled leather belt over the apron
    rx, ry, off = _profile(WAIST_Z)
    belt_pts = []
    for k in range(24):
        a = math.tau * k / 24
        s = math.sin(a)
        grow = 0.043 if s < 0 else 0.014     # outside the apron in front, snug at the back
        belt_pts.append(Vector(((rx + 0.02) * math.cos(a), off + (ry + grow) * s, WAIST_Z)))
    belt_n = [Vector((q.x, q.y - off, 0.0)) for q in belt_pts]
    belt = sweep(belt_pts, 0.03, n=6, normals=belt_n, flat=0.3, closed=True, name="belt")
    parts.append(W("hips", _painted(belt, STRAP, var=0.2, ao=0.0, top=0.25, seed=52, hue_shift=APRON_DARK)))
    bx = 0.07
    by = off - (ry + 0.043) * math.sqrt(max(0.0, 1.0 - (bx / (rx + 0.02)) ** 2)) - 0.012
    parts.append(W("hips", L.part("torus", BRASS, loc=(bx, by, WAIST_Z), major_radius=0.034, minor_radius=0.007,
                                  major_segments=4, minor_segments=4, rot=(90, 45, 12),
                                  paint_kw={"var": 0.25, "ao": 0.0, "top": 0.3})))
    parts.append(W("hips", L.part("cube", BRASS, loc=(bx, by - 0.002, WAIST_Z), scale=(0.022, 0.004, 0.004),
                                  rot=(0, 0, 12))))
    # a linen rag tucked into the belt on his right hip
    rag = _apron_sheet(0.02, 0.2, 0.28, 0.56, 3, 6, 0.05, "rag")
    for v in rag.data.vertices:
        v.co.x -= 0.05
        v.co.y += 0.012 * math.sin(v.co.x * 90.0)
    L.jitter(rag, 0.006, 8.0, 53)
    _thicken(rag, 0.006)
    L.paint(rag, RAG, var=0.22, ao=0.3, top=0.15, hue_shift=L.hexc("#9A7A52"), seed=53)
    L.set_mat(rag, L.MAT_PAINTED)
    parts.append(W("hips", rag))
    # neck straps: from the bib over the shoulders, crossing on the back down to the belt
    for sx in (-1, 1):
        bx0 = sx * 0.158
        lift = 0.004 if sx > 0 else 0.0
        front = [Vector((bx0, _front_y(bx0, 1.175) - 0.034, 1.175)),
                 Vector((sx * 0.162, _front_y(sx * 0.162, 1.24) - 0.024, 1.24)),
                 Vector((sx * 0.162, -0.135, 1.305)), Vector((sx * 0.155, -0.03, 1.35))]
        back = [Vector((sx * 0.145, 0.1, 1.33))]
        for x, z in ((sx * 0.1, 1.22), (sx * 0.035, 1.1), (-sx * 0.05, 0.99), (-sx * 0.13, 0.9)):
            back.append(Vector((x, _back_y(x, z) + 0.01 + lift, z)))
        pts = front + back
        nrm = [(q - Vector((0.0, _profile(q.z)[2], 1.18))).normalized() for q in pts]
        strap = sweep(pts, 0.021, n=6, normals=nrm, flat=0.28, name="strap")
        parts.append(W("spine", _painted(strap, STRAP, var=0.2, ao=0.0, top=0.25, seed=30, hue_shift=APRON_DARK)))
        parts.append(W("spine", L.part("sphere", BRASS, loc=front[0] - Vector((0, 0.006, 0.0)), radius=0.011,
                                       segments=8, ring_count=5, paint_kw={"ao": 0.0, "top": 0.4})))


def _arms(parts) -> None:
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        sh = Vector((sx * 0.3, 0.0, 1.22))
        elbow = Vector((sx * 0.37, -0.02, 1.0))
        wrist = Vector((sx * 0.39, -0.07, 0.8))
        ax = (elbow - sh).normalized()
        sleeve = sweep([sh, sh.lerp(elbow, 0.35), sh.lerp(elbow, 0.7), elbow], [0.085, 0.09, 0.086, 0.078], n=14,
                       name="sleeve")

        def creases(co, nr, sh=sh, ax=ax):
            d = co - sh
            t = d.dot(ax)
            r = d - ax * t
            a = math.atan2(r.y, r.x)
            f = 1.0 - 0.14 * max(0.0, math.sin(a * 3.0 + t * 30.0)) * min(1.0, t / 0.12)
            return f, SHIRT_WARM, 0.3 * max(0.0, nr.z)
        _painted(sleeve, SHIRT, var=0.14, ao=0.15, seed=31, hue_shift=SHIRT_DARK)
        _tint(sleeve, creases)
        parts.append(W(bone, sleeve))
        # rolled-up sleeve: two bulky, uneven rolls
        for off, mr, mn, sd in ((0.0, 0.074, 0.033, 32), (0.035, 0.078, 0.022, 33)):
            c = elbow + (sh - elbow).normalized() * off
            roll = L.part("torus", SHIRT_WARM, loc=c, major_radius=mr, minor_radius=mn, major_segments=10,
                          minor_segments=5, rot=(-10, sx * -5, 0), jit=0.007, jfreq=5.0, seed=sd + sx,
                          paint_kw={"var": 0.16, "ao": 0.1, "hue_shift": SHIRT_DARK})
            parts.append(W(bone, roll))
        # bare, sturdy forearm
        fore = sweep([elbow, elbow.lerp(wrist, 0.3), elbow.lerp(wrist, 0.7), wrist], [0.06, 0.063, 0.056, 0.048],
                     n=12, name="forearm")
        _painted(fore, SKIN, var=0.08, ao=0.15, seed=34, hue_shift=SKIN_ROSY)
        parts.append(W(bone, fore))
        # big mitten hand: palm block, curled fingers, thumb in front
        c = wrist - Vector((0.0, 0.008, 0.052))
        parts.append(W(bone, L.part("sphere", SKIN, loc=c, radius=1.0, scale=(0.044, 0.06, 0.06), segments=12,
                                    ring_count=7, jit=0.003, seed=35, paint_kw={"ao": 0.15, "var": 0.08})))
        parts.append(W(bone, L.part("sphere", SKIN, loc=c + Vector((-sx * 0.01, 0.002, -0.05)), radius=1.0,
                                    scale=(0.042, 0.057, 0.043), rot=(0, sx * -12, 0), segments=12, ring_count=7,
                                    jit=0.003, seed=36, paint_kw={"ao": 0.25, "var": 0.1, "hue_shift": SKIN_ROSY})))
        thumb = sweep([c + Vector((-sx * 0.012, -0.03, 0.02)), c + Vector((-sx * 0.02, -0.052, -0.012)),
                       c + Vector((-sx * 0.018, -0.056, -0.042))], [0.019, 0.017, 0.014], n=8, name="thumb")
        parts.append(W(bone, _painted(thumb, SKIN, var=0.08, ao=0.1, seed=37, hue_shift=SKIN_ROSY)))


def _head(parts) -> None:
    h = HEAD_C
    head = L.part("sphere", SKIN, loc=h, radius=0.15, segments=20, ring_count=14, scale=(1.05, 1.0, 0.98),
                  paint_kw={"ao": 0.15, "var": 0.06})
    cheek_c = [h + Vector((sx * 0.08, -0.12, -0.03)) for sx in (-1, 1)]
    _tint(head, lambda co, nr: (1.0, SKIN_ROSY, max(0.0, 0.7 - min((co - c).length for c in cheek_c) / 0.07)))
    parts.append(W("head", head))
    for sx in (-1, 1):
        # round cheeks pushing the eyes into a friendly squint
        parts.append(W("head", L.part("sphere", SKIN, loc=h + Vector((sx * 0.075, -0.112, -0.022)), radius=0.046,
                                      segments=10, ring_count=7, scale=(1.0, 0.8, 0.82),
                                      paint_kw={"hue_shift": SKIN_ROSY, "var": 0.1, "ao": 0.1})))
        # ears peeking out under the cap
        ear = L.part("sphere", SKIN, loc=h + Vector((sx * 0.155, 0.005, -0.012)), radius=1.0,
                     scale=(0.016, 0.034, 0.046), rot=(0, 0, sx * -18), segments=10, ring_count=6,
                     paint_kw={"hue_shift": SKIN_ROSY, "ao": 0.3})
        parts.append(W("head", ear))
        # eyes: dark, slightly squinted, a tiny gleam
        e = h + Vector((sx * 0.055, -0.139, 0.022))
        parts.append(W("head", L.part("sphere", EYE, loc=e, radius=1.0, scale=(0.019, 0.011, 0.015), segments=8,
                                      ring_count=5, paint_kw={"ao": 0.0, "var": 0.0, "top": 0.0})))
        parts.append(W("head", L.part("sphere", GLEAM, loc=e + Vector((sx * -0.005, -0.009, 0.005)), radius=0.0045,
                                      segments=6, ring_count=4, paint_kw={"ao": 0.0, "var": 0.0, "top": 0.0})))
        # bushy brows: heavy inner end (gruff), tufts sticking out at the side
        brow = sweep([h + Vector((sx * 0.02, -0.162, 0.048)), h + Vector((sx * 0.05, -0.16, 0.06)),
                      h + Vector((sx * 0.085, -0.142, 0.064)), h + Vector((sx * 0.118, -0.11, 0.056))],
                     [0.018, 0.023, 0.018, 0.008], n=8, name="brow")
        L.jitter(brow, 0.004, 40.0, 38 + sx)
        parts.append(W("head", _painted(brow, BEARD_LIGHT, var=0.18, ao=0.0, top=0.3, seed=38 + sx,
                                        hue_shift=BEARD_GREY)))
        # sideburns joining the beard
        parts.append(W("head", L.part("sphere", BEARD_MID, loc=h + Vector((sx * 0.128, -0.055, -0.045)), radius=1.0,
                                      scale=(0.045, 0.06, 0.075), segments=10, ring_count=7, jit=0.01, jfreq=8.0,
                                      seed=40 + sx, paint_kw={"hue_shift": BEARD_GREY, "var": 0.12})))
    # round, ruddy bulb nose
    nose = L.part("sphere", NOSE, loc=h + Vector((0, -0.165, -0.006)), radius=0.055, segments=14, ring_count=9,
                  scale=(1.0, 0.88, 0.9), paint_kw={"ao": 0.1, "var": 0.06, "top": 0.25})
    tip = h + Vector((0, -0.21, 0.0))
    _tint(nose, lambda co, nr: (1.0, NOSE_TIP, max(0.0, 0.6 - (co - tip).length / 0.06)))
    parts.append(W("head", nose))
    # hair at the back of the head under the cap
    hair = L.prim("sphere", loc=h + Vector((0, 0.012, -0.012)), radius=0.158, segments=18, ring_count=12,
                  scale=(1.06, 1.0, 0.92))
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < h.y - 0.03 or v.co.z > h.z + 0.065
                               or v.co.z < h.z - 0.11], context="VERTS")
    bm.to_mesh(hair.data)
    bm.free()
    for v in hair.data.vertices:  # tufty lower edge
        a = math.atan2(v.co.y - h.y, v.co.x)
        if v.co.z < h.z - 0.04:
            v.co.z -= 0.012 * (0.5 + 0.5 * math.sin(a * 9.0))
    L.jitter(hair, 0.006, 12.0, 54)
    parts.append(W("head", _painted(hair, BEARD_GREY, var=0.25, ao=0.25, top=0.2, seed=54, hue_shift=BEARD)))
    _beard(parts)
    _pipe(parts)
    _cap(parts)


def _beard(parts) -> None:
    h = HEAD_C
    bc = h + Vector((0, -0.1, -0.11))
    beard = L.prim("sphere", loc=bc, radius=0.14, segments=22, ring_count=12, scale=(0.97, 0.64, 0.84))
    for v in beard.data.vertices:  # lobes hanging from the chin -> bushy, slightly pointed
        rel = v.co - bc
        if rel.z < 0.02:
            a = math.atan2(rel.y, rel.x)
            depth = (0.02 - rel.z) / 0.14
            v.co.z -= depth * (0.03 + 0.02 * math.sin(a * 7.0) + 0.035 * max(0.0, -math.sin(a)) ** 3)
    L.jitter(beard, 0.012, 7.0, 55)

    def strands(co, nr):
        s = math.sin(co.x * 150.0 + _n(co, 9.0, 1.0) * 3.0)
        return 1.0 - 0.07 * max(0.0, s), BEARD_LIGHT, 0.3 * max(0.0, nr.z) + 0.18 * max(0.0, -s)
    _painted(beard, BEARD_MID, var=0.12, ao=0.18, top=0.25, seed=56, hue_shift=BEARD_GREY)
    _tint(beard, strands)
    parts.append(W("head", beard))
    # strand clumps growing out of the mass: they break up the beard's lower edge
    for k, (x, z, dx, dz) in enumerate(((-0.075, -0.17, -0.012, -0.06), (-0.025, -0.19, -0.004, -0.075),
                                        (0.03, -0.19, 0.006, -0.072), (0.08, -0.17, 0.014, -0.058),
                                        (-0.115, -0.12, -0.012, -0.06), (0.115, -0.12, 0.012, -0.06))):
        p0 = h + Vector((x, -0.15 + abs(x) * 0.45, z))
        p1 = p0 + Vector((dx * 0.55, -0.018, dz * 0.55))
        p2 = p0 + Vector((dx, -0.008, dz))
        clump = sweep([p0, p1, p2], [0.034, 0.024, 0.005], n=8, name="clump")
        L.jitter(clump, 0.003, 30.0, 57 + k)
        parts.append(W("head", _painted(clump, BEARD_MID, var=0.12, ao=0.2, top=0.25, seed=57 + k,
                                        hue_shift=(BEARD_GREY, BEARD_LIGHT)[k % 2])))
    # a hint of the lower lip under the moustache (friendly, not grim)
    parts.append(W("head", L.part("sphere", LIP, loc=h + Vector((0.0, -0.19, -0.09)), radius=1.0,
                                  scale=(0.024, 0.012, 0.011), segments=10, ring_count=6,
                                  paint_kw={"ao": 0.0, "var": 0.05, "top": 0.3})))
    # drooping walrus moustache over the mouth
    for sx in (-1, 1):
        pts = [h + Vector((sx * 0.006, -0.194, -0.047)), h + Vector((sx * 0.036, -0.19, -0.056)),
               h + Vector((sx * 0.058, -0.175, -0.08)), h + Vector((sx * 0.066, -0.16, -0.11))]
        m = sweep(pts, [0.027, 0.031, 0.024, 0.012], n=10, name="moustache")
        L.jitter(m, 0.004, 30.0, 60 + sx)
        _painted(m, MOUSTACHE, var=0.2, ao=0.0, top=0.3, seed=60 + sx, hue_shift=BEARD_GREY)
        _tint(m, lambda co, nr: (1.0 - 0.14 * max(0.0, math.sin(co.x * 180.0 + co.z * 90.0)), None, 0.0))
        parts.append(W("head", m))


def _pipe(parts) -> None:
    """Bent pipe in the right corner of the mouth, the bowl hanging out of the beard."""
    h = HEAD_C
    stem = [h + Vector((-0.035, -0.185, -0.07)), h + Vector((-0.06, -0.225, -0.088)),
            h + Vector((-0.085, -0.255, -0.1)), h + Vector((-0.1, -0.268, -0.098))]
    parts.append(W("head", _painted(sweep(stem, [0.008, 0.0085, 0.0095, 0.011], n=8, name="stem"), PIPE_DARK,
                                    var=0.1, ao=0.0, top=0.3, seed=43)))
    b = h + Vector((-0.108, -0.272, -0.1))
    bowl = loft([(b.z - 0.018, 0.012, 0.012, b.x, b.y), (b.z - 0.012, 0.021, 0.021, b.x, b.y),
                 (b.z + 0.012, 0.026, 0.026, b.x, b.y), (b.z + 0.04, 0.027, 0.027, b.x, b.y),
                 (b.z + 0.045, 0.024, 0.024, b.x, b.y), (b.z + 0.043, 0.019, 0.019, b.x, b.y),
                 (b.z + 0.03, 0.017, 0.017, b.x, b.y)], n=14, name="bowl")
    _painted(bowl, PIPE, var=0.16, ao=0.3, top=0.3, seed=44)
    _tint(bowl, lambda co, nr: (1.0, ASH, 0.8 if co.z > b.z + 0.038 and nr.z > 0.3 else 0.0))
    parts.append(W("head", bowl))
    # a tiny ember glowing in the bowl (the only warm light on him)
    parts.append(W("head", L.part("cyl", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=b + Vector((0, 0, 0.036)),
                                  radius=0.012, depth=0.004, vertices=10)))


def _cap(parts) -> None:
    h = HEAD_C
    # band around the head
    band = loft([(h.z + 0.06, 0.162, 0.158, 0.0, h.y - 0.01), (h.z + 0.098, 0.168, 0.164, 0.0, h.y - 0.01)],
                n=24, caps=(False, False), name="band")
    parts.append(W("head", _painted(band, CAP, var=0.16, ao=0.0, top=0.2, seed=61, hue_shift=CAP_DARK)))
    # soft crown: a flat pillow pulled forward and down over the peak
    cc = h + Vector((0.0, -0.006, 0.145))
    crown = L.prim("sphere", loc=cc, radius=1.0, segments=24, ring_count=12, scale=(0.186, 0.188, 0.082))
    for v in crown.data.vertices:
        rel = v.co - cc
        if rel.z > 0.018:           # flat top with a soft rolled edge (not a dome)
            v.co.z = cc.z + 0.018 + (rel.z - 0.018) * 0.5
            rel = v.co - cc
        ln = math.hypot(rel.x / 0.184, rel.y / 0.186)
        if rel.z < 0.0 and ln > 1e-4:  # fuller sides down onto the band and peak
            k = 1.0 + (max(ln, 0.9) / ln - 1.0) * min(1.0, -rel.z / 0.07)
            v.co.x = cc.x + rel.x * k
            v.co.y = cc.y + rel.y * k
            rel = v.co - cc
        front = max(0.0, -rel.y / 0.186)
        v.co.z -= 0.034 * front ** 1.5 * (1.0 if rel.z > -0.03 else 0.5)
        v.co.y -= 0.008 * front ** 2
        if rel.z < -0.04:           # tucked into the band
            v.co.z = max(v.co.z, h.z + 0.072)
    L.jitter(crown, 0.006, 4.0, 62)
    patch_c = Vector((0.085, -0.045, 0.0))

    def cloth(co, nr):
        rel = co - cc
        f = 1.0
        # centre seam front to back on top, stitched patch on the left side of the crown
        if abs(rel.x) < 0.007 and nr.z > 0.5:
            f = 0.72
        pr = max(abs(rel.x - patch_c.x) / 0.05, abs(rel.y - patch_c.y) / 0.042)
        if pr < 1.0 and nr.z > 0.2:
            if pr > 0.8 and math.sin((rel.x + rel.y) * 300.0) > 0.0:
                return 0.9, STITCH, 0.85
            return f, CAP_PATCH, 0.9
        return f, None, 0.0
    _painted(crown, CAP, var=0.2, ao=0.12, top=0.22, seed=63, hue_shift=CAP_DARK)
    _tint(crown, cloth)
    parts.append(W("head", crown))
    # stiff peak, curving down at the front edge
    bm = bmesh.new()
    rows = []
    nt, nr_ = 14, 4
    for i in range(nt + 1):
        th = math.radians(-78 + 156 * i / nt)
        row = []
        for j in range(nr_ + 1):
            r = 0.156 + (0.05 * math.cos(th) ** 0.8 + 0.004) * j / nr_
            t = j / nr_
            x = r * math.sin(th)
            y = h.y - 0.01 - r * math.cos(th)
            z = h.z + 0.074 - 0.016 * t * t * math.cos(th) - 0.01 * (1.0 - math.cos(th))
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for i in range(nt):
        for j in range(nr_):
            bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
    peak = _obj(bm, "peak")
    _thicken(peak, 0.012)
    _painted(peak, CAP, var=0.16, ao=0.0, top=0.25, seed=64, hue_shift=CAP_DARK)
    tip_r = 0.156

    def peak_stitch(co, nr):
        rel = Vector((co.x, co.y - (h.y - 0.01), 0.0))
        d = rel.length - tip_r
        return (0.72 if 0.036 < d < 0.042 and nr.z > 0.3 else 1.0), None, 0.0
    _tint(peak, peak_stitch)
    parts.append(W("head", peak))
    # snap button where the crown meets the peak
    parts.append(W("head", L.part("sphere", CAP_DARK, loc=h + Vector((0.0, -0.196, 0.094)), radius=0.011,
                                  segments=8, ring_count=5, scale=(1.0, 0.7, 1.0), paint_kw={"top": 0.4})))


def _global_light(mesh) -> None:
    """Whole-figure painterly pass: cool ink-blue towards the boots, warm light on the shoulders."""
    ink = L.hexc("#1F2A3A")
    warm = L.hexc("#D8B98A")
    attr = mesh.data.color_attributes["Col"]
    for li, co, nr in _loops(mesh):
        c = attr.data[li].color
        low = max(0.0, 1.0 - co.z / 0.7) ** 2
        high = max(0.0, (co.z - 1.1) / 0.45) * max(0.0, nr.z)
        rgb = [x * (1.0 - 0.18 * low) for x in c[:3]]
        rgb = [x + (L._to_lin(k) - x) * 0.12 * low for x, k in zip(rgb, ink)]
        rgb = [x + (L._to_lin(k) - x) * 0.1 * high for x, k in zip(rgb, warm)]
        attr.data[li].color = (rgb[0], rgb[1], rgb[2], 1.0)


def build_mesh():
    """Returns the rigidly weighted carter mesh in model space."""
    L.reset(81)
    parts = []
    _boots_and_legs(parts)
    _torso(parts)
    _neckerchief(parts)
    _apron(parts)
    _arms(parts)
    _head(parts)
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh)
    L.smooth(mesh, 55)
    return mesh


def joints(dz: float) -> dict:
    """Bone head/tail from the carter's proportions (dz = grounding shift)."""
    def p(x, y, z):
        return (x, y, z - dz)
    j = {
        "root": (p(0, 0, dz), p(0, 0, dz + 0.3)),
        "hips": (p(0, 0.0, 0.66), p(0, 0.0, 0.86)),
        "spine": (p(0, 0.0, 0.86), p(0, -0.02, 1.33)),
        "head": (p(0, -0.03, 1.32), p(0, -0.03, 1.62)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (p(sx * 0.3, 0.0, 1.22), p(sx * 0.39, -0.07, 0.8))
        j[_side(sx, "leg")] = (p(sx * 0.12, 0, 0.68), p(sx * 0.125, 0, 0.1))
    return j


# --- actions (pose functions, see rig.py for the conventions) ---------------------

def idle(t: float) -> dict:
    """2.4 s: deep belly breathing, a slow weight shift, a puff on the pipe."""
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.5), {
        "hips": (0.0, 1.5 * s, 0.0, 0.004 * s, 0.0, 0.0),
        "spine": (0.0, -1.5 * s, 0.0),
        "head": (1.5 * math.sin(rig.TAU * t * 2.0), 0.0, 3.0 * s),
    })


def walk(t: float) -> dict:
    """18 frames = 0.6 s per cycle: sturdy, rolling, arms swinging wide."""
    g = rig.gait(t, leg=26.0, lift=0.05, arm=18.0, bob=0.015, roll=4.5, yaw=4.0, lean=2.0)
    return rig.add(g, {"arm_l": (0.0, -6.0, 0.0), "arm_r": (0.0, 6.0, 0.0)})


def push_cart(t: float) -> dict:
    """22 frames: leaning into the cart, both hands forward-low on the handles."""
    c2 = math.cos(2.0 * rig.TAU * t)
    g = rig.gait(t, leg=22.0, lift=0.04, arm=0.0, bob=0.012, roll=2.5, yaw=2.0, lean=0.0)
    return rig.add(g, {
        "hips": (6.0, 0.0, 0.0),
        "spine": (12.0, 0.0, 0.0),
        "head": (-14.0, 0.0, 0.0),
        "arm_l": (-46.0 + 2.0 * c2, 8.0, 0.0),   # hands drawn in onto the handles (~0.65 m apart)
        "arm_r": (-46.0 + 2.0 * c2, -8.0, 0.0),
    })


def talk(t: float) -> dict:
    """72 frames = 2.4 s: explains with the right hand, left thumb in the apron."""
    rest_l = {"arm_l": (-12.0, 12.0, 0.0)}
    a = {"arm_r": (-40.0, -4.0, 20.0), "head": (2.0, 0.0, 4.0), "spine": (-2.0, 0.0, -4.0)}
    b = {"arm_r": (-62.0, -14.0, 32.0), "head": (-4.0, -3.0, -2.0), "spine": (1.0, 0.0, -6.0)}
    c = {"arm_r": (-30.0, -18.0, 8.0), "head": (3.0, 3.0, 6.0), "spine": (-1.0, 0.0, -2.0)}
    d = {"arm_r": (-54.0, -6.0, 28.0), "head": (-2.0, 0.0, 0.0), "spine": (0.0, 0.0, -5.0)}
    keys = [(0.0, a), (0.25, b), (0.5, c), (0.75, d)]
    return rig.add(rig.breathe(t, 1.0, 2), rest_l, rig.keyed(t, keys))


ACTIONS = (  # (name, frames at 30 fps, pose function)
    ("idle-loop", 72, idle),
    ("walk-loop", 18, walk),
    ("push_cart-loop", 22, push_cart),
    ("talk-loop", 72, talk),
)


def build():
    mesh = build_mesh()
    dz = rig.ground(mesh)
    arm = rig.build_armature(joints(dz))
    rig.bind(mesh, arm)
    for name, frames, fn in ACTIONS:
        rig.add_action(arm, mesh, name, frames, fn)
    L.export_rigged(arm, NAME, "characters")


if __name__ == "__main__":
    build()
