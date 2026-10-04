"""Shared painted faces (G7 Änderungsrunde 1): the sculpted head of every figure - the villagers
(asset_villagers), the gravekeeper (asset_character), Osric (asset_carter), Ilse Kranich
(asset_trader), the ghost (asset_ghost) and the laid-out corpses (asset_props_slice /
asset_corpses_phase4) - and the deterministic glb canonicalisation (_stable_glb, finish_stable).

The code came verbatim from asset_villagers.py (the villagers' exports stay byte-identical); the
additions are opt-in parameters of _head() whose defaults reproduce the villagers exactly:
  closed=True    closed eyes (a calm lid over the whole eye, the lash line curving down) - the dead
  res=<f>        resolution factor of the face parts (detail=True 1.0, detail=False 0.55)
  cull=fn(n)     skull faces whose direction n (head space) is hidden (under a hat, a beard, on the
                 table) are left out - budget
  eye_col=...    sclera / pupil / gleam colours (the ghost)
"""
import json
import math
import struct

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import rig
import asset_carter as _C

W = rig.weight
GLEAM = L.hexc("#E9E2D2")
LINEN_SHADE = L.hexc("#B3AA95")


def sweep(*a, **k):
    return _C.sweep(*a, **k)


def _tint(*a, **k):
    return _C._tint(*a, **k)


def _n(*a, **k):
    return _C._n(*a, **k)


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _xf(obj, m: Matrix):
    obj.data.transform(m)
    return obj


def _frame(origin, fwd, up) -> Matrix:
    y = Vector(fwd).normalized()
    x = y.cross(Vector(up)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


# --- heads -------------------------------------------------------------------------------------------
# G7 Änderungsrunde 1 ("das Gesicht von denen passt gar nicht"): sculpted heads instead of plain
# ellipsoids - a flatter face plane with brow ridge, cheeks, eye sockets, a soft muzzle and chin; awake
# eyes (white, iris, pupil, gleam, a real upper lid with a lash line); a soft nose that grows out of
# the face (bridge, tip, wings) instead of a ball or a spike; a shaped mouth; warm painted skin with
# blush and shading. Hair and head cloths are shells that follow the sculpted skull and are cut along
# a hairline / hem curve (no helmet look). Feature sizes scale with the head (k = s.x / 0.135).

SCLERA = L.hexc("#E3D9C8")
PUPIL = L.hexc("#15110F")
LASH = L.hexc("#2E211B")
FACE_SHADE = L.hexc("#A06A58")       # warm shading of the face (sockets, folds, under the jaw)
BLUSH = L.hexc("#D97F6C")
MOUTH = L.hexc("#7A3E36")
IRIS_BROWN = L.hexc("#5A3A26")
IRIS_HAZEL = L.hexc("#6A5530")
IRIS_BLUE = L.hexc("#5A6A7A")         # a muted grey-blue (no saturated cold colour, ART_DIRECTION §3)
IRIS_GREY = L.hexc("#5E6A6C")
IRIS_DARK = L.hexc("#3A2A20")


def _s01(x: float) -> float:
    x = min(1.0, max(0.0, x))
    return x * x * (3.0 - 2.0 * x)


def _g(n: Vector, centre, sigma: float) -> float:
    return math.exp(-((n - Vector(centre).normalized()).length_squared) / (sigma * sigma))


class Face:
    """The sculpted skull of a head (centre c, semi-axes s). Directions n are unit vectors in the
    head's normalised space (front = -Y)."""

    def __init__(self, c: Vector, s: Vector, *, jaw: float = 1.0, chin: float = 0.0, cheeks: float = 0.5,
                 age: float = 0.0, flat: float = 1.0, muzzle: float = 1.0, brow_ridge: float = 1.0):
        self.c, self.s = Vector(c), Vector(s)
        self.jaw, self.chin, self.cheeks, self.age = jaw, chin, cheeks, age
        self.flat, self.muzzle, self.brow_ridge = flat, muzzle, brow_ridge
        self.k = s.x / 0.135

    def sculpt(self, n: Vector) -> Vector:
        r = 1.0
        for sx in (-1, 1):
            r += self.cheeks * 0.075 * _g(n, (sx * 0.5, -0.8, -0.28), 0.32)
            r -= 0.045 * _g(n, (sx * 0.34, -0.92, 0.13), 0.15)                 # eye sockets
            r += 0.03 * self.brow_ridge * _g(n, (sx * 0.3, -0.9, 0.35), 0.2)
            r -= 0.08 * self.age * _g(n, (sx * 0.56, -0.74, -0.42), 0.24)      # hollow cheeks
            r -= 0.035 * self.age * _g(n, (sx * 0.74, -0.58, 0.3), 0.22)       # temples
        r += 0.035 * self.muzzle * _g(n, (0.0, -0.86, -0.5), 0.3)
        r += 0.035 * _g(n, (0.0, -0.98, 0.0), 0.13)                            # nose root
        p = n * r
        if p.y < 0.0:
            p.y *= 1.0 - 0.1 * self.flat * (-n.y) ** 2
        if n.z < -0.05:
            p.x *= 1.0 - (1.0 - self.jaw) * 1.5 * _s01((-n.z - 0.05) / 0.8)
        if n.z < -0.35 and n.y < 0.0:   # every face narrows a little towards the chin (no ball heads)
            p.x *= 1.0 - 0.1 * _s01((-n.z - 0.35) / 0.5) * _s01(-n.y / 0.6)
        if n.y < 0.0 and n.z < -0.4:
            p.y -= self.chin * _s01((-n.z - 0.4) / 0.45) * _s01((-n.y - 0.3) / 0.6)
        if n.y > 0.4 and n.z > -0.2:
            p.y -= 0.08 * (n.y - 0.4)
        return p

    def world(self, n: Vector, out: float = 0.0) -> Vector:
        p = self.sculpt(n)
        q = self.c + Vector((p.x * self.s.x, p.y * self.s.y, p.z * self.s.z))
        return q + self.normal(n) * out if out else q

    def normal(self, n: Vector) -> Vector:
        t1 = n.cross(Vector((0, 0, 1)))
        if t1.length < 1e-4:
            t1 = Vector((1, 0, 0))
        t1.normalize()
        t2 = n.cross(t1).normalized()
        e = 0.01
        a = self.world((n + t1 * e).normalized()) - self.world((n - t1 * e).normalized())
        b = self.world((n + t2 * e).normalized()) - self.world((n - t2 * e).normalized())
        m = a.cross(b).normalized()
        return m if m.dot(n) > 0.0 else -m

    @staticmethod
    def front(u: float, w: float) -> Vector:
        return Vector((u, -math.sqrt(max(0.0, 1.0 - u * u - w * w)), w)).normalized()

    def pt(self, u: float, w: float, out: float = 0.0) -> Vector:
        return self.world(self.front(u, w), out)

    def nrm(self, u: float, w: float) -> Vector:
        return self.normal(self.front(u, w))

    @staticmethod
    def around(phi: float, w: float) -> Vector:
        """Direction at azimuth phi (0 = front, + = the character's left) and height w."""
        r = math.sqrt(max(0.0, 1.0 - w * w))
        return Vector((math.sin(phi) * r, -math.cos(phi) * r, w))


_RES = [1.0]   # resolution factor of the face parts (the seated figures use a coarser head)


def _oell(color, at: Vector, nrm: Vector, scale, seg: int = 8, rings: int = 5, roll: float = 0.0, local=None, **pk):
    """Ellipsoid oriented to a surface: local -Y = out of the surface (nrm), X horizontal."""
    seg, rings = max(6, round(seg * _RES[0])), max(4, round(rings * _RES[0]))
    # poles along local Y: seen from the front the outline is the (finer) segment circle
    o = L.prim("sphere", radius=1.0, rot=(90, 0, 0), segments=seg, ring_count=rings)
    for v in o.data.vertices:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    if local:
        for v in o.data.vertices:
            local(v)
    m = _frame(at, -nrm, (0, 0, 1))
    if roll:
        m = m @ Matrix.Rotation(math.radians(roll), 4, "Y")
    _xf(o, m)
    return _painted(o, color, **pk)


def _knots(knots, theta: float) -> float:
    """Piecewise linear w(theta) through (theta, w) knots, theta = |azimuth| in [0, pi]."""
    if theta <= knots[0][0]:
        return knots[0][1]
    for a, b in zip(knots, knots[1:]):
        if theta <= b[0]:
            t = (theta - a[0]) / max(1e-6, b[0] - a[0])
            return a[1] + (b[1] - a[1]) * t
    return knots[-1][1]


def _shell(face: Face, knots, *, out=0.008, crown: float = 0.004, n: int = 30, m: int = 8, top=None,
           phi=(-math.pi, math.pi), tuck: float = 0.004, tuft: float = 0.0, tuft_k: float = 11.0, lumps: float = 0.0,
           seed: int = 0, name: str = "shell"):
    """A shell over the sculpted skull from the lower edge w = knots(|phi|) up to the crown (or up to
    the upper edge `top` knots): hair or a head cloth. out = offset (m) or fn(phi, w) -> offset;
    crown = extra volume towards the top. The edge is tucked in towards the skin (no gap, no visible
    inside); tuft > 0 frays the lower edge into locks. Returns (obj, edge points, edge directions)."""
    closed = (phi[1] - phi[0]) >= math.tau - 1e-6
    cols = n if closed else n + 1
    off = out if callable(out) else (lambda p, w, o=out: o)
    bm = bmesh.new()
    rows = []
    edge, edge_dirs = [], []
    lo_list = []
    for j in range(cols):
        ph = phi[0] + (phi[1] - phi[0]) * j / n
        th = abs(math.atan2(math.sin(ph), math.cos(ph)))
        lo = _knots(knots, th)
        hi = _knots(top, th) if top else 1.0
        if not closed:   # the open ends of a strip taper shut
            e = min(j, n - j) / (n * 0.12)
            if e < 1.0:
                mid = (lo + hi) * 0.5
                lo, hi = mid + (lo - mid) * _s01(e) ** 0.5, mid + (hi - mid) * _s01(e) ** 0.5
        if tuft > 0.0:
            lo -= tuft * (0.55 + 0.45 * math.sin(ph * tuft_k + seed) + 0.35 * noise.noise(Vector((ph * 3.0, seed, 0.0))))
        lo_list.append((ph, lo, hi))
    for j, (ph, lo, hi) in enumerate(lo_list):
        col = []
        # tucked inner rim at the lower edge
        d0 = Face.around(ph, lo).normalized()
        col.append(bm.verts.new(face.world(d0, -tuck)))
        for i in range(m + 1):
            t = i / m
            if top is None and i == m:
                break
            w = lo + (hi - lo) * (t ** 0.85)
            d = Face.around(ph, min(w, 0.995)).normalized()
            o = off(ph, w) + crown * _s01((w - lo) / max(0.05, 1.0 - lo))
            if lumps:
                o += lumps * (0.5 + 0.5 * noise.noise(d * 5.0 + Vector((seed, 0, 0))))
            col.append(bm.verts.new(face.world(d, o)))
        if top is not None:
            d1 = Face.around(ph, hi).normalized()
            col.append(bm.verts.new(face.world(d1, -tuck)))
        rows.append(col)
        edge.append(face.world(d0, off(ph, lo) + 0.002))
        edge_dirs.append(d0)
    nrow = len(rows[0])
    pairs = [(j, (j + 1) % cols) for j in range(cols if closed else cols - 1)]
    for a, b in pairs:
        for i in range(nrow - 1):
            bm.faces.new((rows[a][i], rows[b][i], rows[b][i + 1], rows[a][i + 1]))
    if top is None:
        pole = bm.verts.new(face.world(Vector((0, 0, 1)), off(0.0, 1.0) + crown))
        for a, b in pairs:
            bm.faces.new((rows[a][-1], rows[b][-1], pole))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # outward: majority of the faces against the head centre
    vote = sum(1 if f.normal.dot(f.calc_center_median() - face.c) > 0.0 else -1 for f in bm.faces)
    if vote < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj, edge, edge_dirs


def _hair(parts, face: Face, color, dark, knots, *, out=0.007, crown: float = 0.006, part_u=None, tuft: float = 0.006,
          comb: str = "down", top=None, phi=(-math.pi, math.pi), seed: int = 0, light=None, add=None, n: int = 30,
          m: int = 8):
    """Painted hair shell: strands combed from the crown (or back), a parting, darker roots at the
    edge, sheen on top."""
    add = add or (lambda o: parts.append(W("head", o)))
    obj, edge, _ = _shell(face, knots, out=out, crown=crown, top=top, phi=phi, tuft=tuft, lumps=0.003, seed=seed,
                          n=n, m=m, name="hair")
    L.jitter(obj, 0.0025, 14.0, seed)
    _painted(obj, color, var=0.16, ao=0.0, top=0.25, seed=seed, hue_shift=dark)
    c = face.c
    hl = light or L.mix(color, (1.0, 0.95, 0.85), 0.25)

    def strands(co, nr):
        d = co - c
        a = math.atan2(d.x, -d.y)
        if comb == "back":
            st = math.sin(d.x * 260.0 + _n(co, 20.0, seed) * 2.0)
        else:
            st = math.sin(a * 34.0 + _n(co, 18.0, seed) * 2.5)
        f = 1.0 - 0.2 * max(0.0, st) ** 2
        w = d.z / face.s.z
        f *= 0.86 + 0.14 * _s01((w + 0.6) / 0.9)
        amt = 0.3 * max(0.0, nr.z) * max(0.0, -st) ** 2
        if part_u is not None and d.y < 0.0 and w > 0.3 and abs(d.x - part_u * face.s.x) < 0.006 * face.k:
            return 0.62, dark, 0.5
        return f, hl, amt
    _tint(obj, strands)
    add(obj)
    return obj, edge


def _cloth_cover(parts, face: Face, color, shade, knots, *, out=0.016, crown: float = 0.008, folds: float = 7.0,
                 rim: float = 0.0, rim_phi: float = math.pi, seed: int = 0, lumps: float = 0.0, name: str = "cover",
                 add=None, n: int = 32, m: int = 8):
    """Head cloth (scarf, bonnet, cap, hood) over the sculpted skull, cut along a hem curve, soft folds
    painted from the crown; optional rolled hem along the face part of the edge (|phi| < rim_phi)."""
    add = add or (lambda o: parts.append(W("head", o)))
    obj, edge, dirs = _shell(face, knots, out=out, crown=crown, tuck=0.002, lumps=lumps, seed=seed, n=n, m=m, name=name)
    L.jitter(obj, 0.003, 7.0, seed)
    _painted(obj, color, var=0.08, ao=0.0, top=0.22, seed=seed, hue_shift=shade)
    c = face.c

    def cloth(co, nr):
        d = co - c
        a = math.atan2(d.x, -d.y)
        f = 1.0 - 0.17 * max(0.0, math.sin(a * folds + _n(co, 6.0, seed) * 2.0)) * _s01(1.0 - 0.6 * d.z / face.s.z)
        f *= 0.9 + 0.1 * _s01((d.z / face.s.z + 0.8) / 1.2)
        return f, None, 0.0
    _tint(obj, cloth)
    add(obj)
    if rim > 0.0:
        n = len(edge)
        pts = []
        for j in range(n):
            ph = -math.pi + math.tau * j / n
            if abs(ph) <= rim_phi:
                pts.append(edge[j])
        if len(pts) >= 3:
            add(_painted(sweep(pts, rim, n=6, name=name + "_rim"), color, var=0.08, ao=0.0, top=0.3, seed=seed + 1,
                         hue_shift=shade))
    return obj, edge


def _frill(parts, face: Face, edge, color, width: float, phi_max: float, pleats: float = 26.0, seed: int = 0,
           add=None) -> None:
    """Pleated linen ruffle round the face along the front of a cover's edge: a band facing forward,
    the pleats waved in depth and painted light/dark."""
    add = add or (lambda o: parts.append(W("head", o)))
    n = len(edge)
    idx = [j for j in range(n) if abs(-math.pi + math.tau * j / n) <= phi_max]
    fr = []
    for a, b in zip(idx, idx[1:]):
        for t in (0.0, 0.2, 0.4, 0.6, 0.8):
            fr.append(edge[a].lerp(edge[b], t) + Vector((0, -0.004, 0)))
    fr.append(edge[idx[-1]] + Vector((0, -0.004, 0)))
    frill = sweep(fr, width, n=6, flat=0.32, name="frill", normals=[Vector((0, -1, 0.0)) for _ in fr])
    c = face.c

    def beta(co):
        return math.atan2(co.z - c.z, co.x - c.x)
    for v in frill.data.vertices:
        d = v.co - c
        rad = Vector((d.x, 0.0, d.z)).normalized()
        v.co += rad * 0.003   # flare outwards a little
        v.co.y -= 0.006 * math.sin(beta(v.co) * pleats)
    _painted(frill, color, var=0.06, ao=0.0, top=0.25, seed=seed, hue_shift=LINEN_SHADE)
    _tint(frill, lambda co, nr: (1.0 - 0.24 * max(0.0, -math.sin(beta(co) * pleats)), LINEN_SHADE,
                                 0.3 * max(0.0, -math.sin(beta(co) * pleats))))
    add(frill)


def _head(parts, c: Vector, s: Vector, skin, *, seed: int, nose: str = "round", nose_s: float = 1.0,
          brow=None, brow_w: float = 1.0, brow_tilt: float = 0.0, brow_arch: float = 1.0, eyes: float = 1.0,
          lids: float = 0.15, mouth: str = "smile", smile: float = 1.0, lip=None, ears: bool = True,
          cheeks: float = 0.5, chin: float = 0.0, jaw: float = 1.0, age: float = 0.0, cheek_col=None,
          iris=IRIS_BROWN, muzzle: float = 1.0, eye_gap: float = 1.0, mouth_w: float = 1.0, add=None,
          seg: int = 28, rings: int = 18, detail: bool = True):
    """Painted, sculpted head (see the section note). brow_tilt > 0 raises the inner brow ends
    (kind / worried), < 0 lowers them (stern). lids: 0.1 wide awake .. 0.45 heavy. mouth: smile,
    laugh, thin, stern, kind. Front = -Y. Returns a dict of useful points and the Face."""
    add = add or (lambda o: parts.append(W("head", o)))
    _RES[0] = 1.0 if detail else 0.55
    face = Face(c, s, jaw=jaw, chin=chin, cheeks=cheeks, age=age, muzzle=muzzle)
    k = face.k
    head = L.prim("sphere", loc=(0, 0, 0), radius=1.0, segments=seg, ring_count=rings)
    for v in head.data.vertices:
        v.co = face.world(v.co.normalized())
    _painted(head, skin, ao=0.1, var=0.05, top=0.08, seed=seed, zrange=(c.z - s.z, c.z + s.z))
    cc = cheek_col or BLUSH
    ex, ez = 0.34 * eye_gap, 0.13
    mz = -0.5

    def shade(co, nr):
        d = co - c
        n = Vector((d.x / s.x, d.y / s.y, d.z / s.z))
        nn = n.normalized()
        f, col, amt = 1.0, None, 0.0
        b = max(_g(nn, (sx * 0.5, -0.8, -0.26), 0.3) for sx in (-1, 1))
        col, amt = cc, cheeks * 0.6 * b
        sock = max(_g(nn, (sx * ex, -0.92, ez + 0.03), 0.17) for sx in (-1, 1))
        if sock > 0.05:
            f *= 1.0 - 0.07 * sock
            if amt < 0.2 * sock:
                col, amt = FACE_SHADE, 0.2 * sock
        lipz = _g(nn, (0.0, -0.86, mz), 0.2)
        if lipz > amt:
            col, amt = cc, 0.35 * lipz
        if n.z < -0.55:          # under the jaw
            f *= 1.0 - 0.18 * _s01((-n.z - 0.55) / 0.35)
        if n.z > 0.4 and n.y < 0.0:   # forehead catches the light
            f *= 1.04
        if age > 0.0 and n.y < 0.0:
            for sx in (-1, 1):   # nose-to-mouth folds
                p0 = Vector((sx * 0.14, -0.2))
                p1 = Vector((sx * 0.3, mz - 0.06))
                q = Vector((n.x, n.z))
                t = max(0.0, min(1.0, (q - p0).dot(p1 - p0) / (p1 - p0).length_squared))
                dd = (q - (p0 + (p1 - p0) * t)).length
                if dd < 0.045:
                    f *= 1.0 - 0.12 * age * (1.0 - dd / 0.045)
            if 0.42 < n.z < 0.75 and abs(n.x) < 0.45:   # forehead lines
                f *= 1.0 - 0.07 * age * max(0.0, math.sin(n.z * 58.0)) ** 6
        return f, col, amt
    _tint(head, shade)
    add(head)
    pts = {"eye": [], "c": c, "s": s, "face": face}
    eye_k = eyes * k * 1.08
    for sx in (-1, 1):
        u = sx * ex
        nrm = face.nrm(u, ez)
        e = face.pt(u, ez, -0.0035 * k)
        pts["eye"].append(face.pt(u, ez))
        sw, sd, sh = 0.0235 * eye_k, 0.0115 * eye_k, 0.0165 * eye_k
        add(_oell(SCLERA, e, nrm, (sw, sd, sh), seg=14, rings=8, ao=0.0, var=0.03, top=0.0, seed=seed + 1))
        ic = e + nrm * (0.0082 * eye_k) + Vector((0, 0, -0.001 * k))
        add(_oell(iris, ic, nrm, (0.0128 * eye_k, 0.0042 * eye_k, 0.0136 * eye_k), seg=16, rings=6, ao=0.0, var=0.08,
                  top=0.0, seed=seed + 2))
        add(_oell(PUPIL, ic + nrm * (0.0036 * eye_k), nrm, (0.0062 * eye_k, 0.0016 * eye_k, 0.0068 * eye_k), seg=12,
                  rings=4, ao=0.0, var=0.0, top=0.0))
        if detail:
            add(_oell(GLEAM, ic + nrm * (0.0052 * eye_k) + Vector((0.0035 * k, 0.0, 0.0042 * k)), nrm,
                      (0.0027 * k, 0.0012 * k, 0.0027 * k), seg=6, rings=3, ao=0.0, var=0.0, top=0.0))
        # the upper lid: a skin cap over the top of the eye, its lower edge drawn by the lash line
        cover = max(0.05, min(0.6, lids))
        zc = sh * 1.1 * (1.0 - 2.0 * cover) - sh * 0.3 * 0.7
        lw, ld, lh = sw * 1.1, sd * 1.25, sh * 1.1

        arch = sh * 0.3   # the lid edge arches over the iris (awake, friendly), lowest at the corners

        def lidf(v, zc=zc, arch=arch, lw=lw):
            z0 = zc + arch * (1.0 - min(1.0, (v.co.x / lw) ** 2))
            if v.co.z < z0:
                v.co.z = z0
        lidc = L.mix(skin, FACE_SHADE, 0.25)
        add(_oell(lidc, e, nrm, (lw, ld, lh), seg=12, rings=7, local=lidf, ao=0.0, var=0.04, top=0.15, seed=seed + 3))
        xm = lw * math.sqrt(max(0.0, 1.0 - (zc / lh) ** 2))
        m_eye = _frame(e, -nrm, (0, 0, 1))
        lash = []
        for i in range(7):
            t = -1.0 + 2.0 * i / 6
            x = t * xm * 0.98
            za = zc + arch * (1.0 - (x / lw) ** 2)
            y = -ld * math.sqrt(max(0.0, 1.0 - (x / lw) ** 2 - (za / lh) ** 2)) * 1.02
            lash.append(m_eye @ Vector((x * sx, y, za + 0.0006 * k)))
        lr = 0.0021 * k
        add(_painted(sweep(lash, [lr * 0.5, lr, lr * 1.2, lr * 1.25, lr * 1.3, lr * 1.3, lr * 1.0], n=5 if detail else 4,
                           name="lash"), LASH, ao=0.0, var=0.05, top=0.0))
        if detail and age > 0.3:   # lower lid / bags
            bag = []
            for i in range(5):
                t = -1.0 + 2.0 * i / 4
                x = t * sw * 0.85
                z = -sh * 0.95 * math.sqrt(max(0.0, 1.0 - t * t * 0.8)) - 0.002 * k
                y = -sd * math.sqrt(max(0.0, 1.0 - (x / sw) ** 2 - (z / (sh * 1.15)) ** 2))
                bag.append(m_eye @ Vector((x, y, z)))
            add(_painted(sweep(bag, [0.0015 * k, 0.0026 * k, 0.003 * k, 0.0026 * k, 0.0015 * k], n=5, name="bag"),
                         L.mix(skin, FACE_SHADE, 0.35), ao=0.0, var=0.04, top=0.1))
        if brow is not None:
            us = [0.09, 0.17, 0.26, 0.36, 0.45, 0.53]
            arch = [0.0, 0.022, 0.034, 0.034, 0.02, -0.01]
            tilt = [0.12, 0.08, 0.04, 0.0, -0.02, -0.04]
            bw = [0.0052, 0.0068, 0.0072, 0.0064, 0.005, 0.0028]
            bp = [face.pt(sx * uu * eye_gap ** 0.5, 0.37 + arch[i] * brow_arch + brow_tilt * tilt[i] - (0.012 if i == 5 else 0.0),
                          0.0035 * k) for i, uu in enumerate(us)]
            br = sweep(bp, [r * brow_w * k for r in bw], n=6, flat=0.5, name="brow",
                       normals=[face.nrm(sx * uu, 0.36) for uu in us])
            L.jitter(br, 0.0018 * k * brow_w, 60.0, seed + 4 + sx)
            _painted(br, brow, ao=0.0, var=0.12, top=0.1, seed=seed + 4)
            _tint(br, lambda co, nr: (1.0 - 0.18 * max(0.0, math.sin(co.x * 900.0 + co.z * 400.0)), None, 0.0))
            add(br)
    # age: painted lines (thin strokes on the skin - too fine for the head's vertex colours)
    if age > 0.25:
        line_c = L.mix(skin, FACE_SHADE, 0.45)

        def stroke(uw, r):
            ps = [face.pt(u, w, 0.0006 * k) for u, w in uw]
            add(_painted(sweep(ps, [r * k * (0.5 + 0.5 * math.sin(math.pi * (i + 0.5) / len(ps))) for i in range(len(ps))],
                               n=4, flat=0.4, normals=[face.nrm(u, w) for u, w in uw], name="line"),
                         line_c, ao=0.0, var=0.04, top=0.0))
        for sx in (-1, 1):
            stroke([(sx * 0.15, -0.19), (sx * 0.21, -0.3), (sx * 0.25, mz + 0.03)], 0.0024 * min(1.0, age + 0.2))
            if age > 0.5:   # crow's feet, marionette lines
                for dz in (-0.06, 0.0, 0.06):
                    stroke([(sx * (ex + 0.21), ez + dz * 0.6), (sx * (ex + 0.3), ez + dz * 1.4)], 0.0018)
                stroke([(sx * 0.26, mz - 0.05), (sx * 0.27, mz - 0.15)], 0.0016 * age)
        if age > 0.5 and detail:   # forehead lines (hidden under a cap or hair where there is one)
            for wz in (0.52, 0.6):
                stroke([(-0.3, wz - 0.02), (-0.15, wz), (0.0, wz + 0.01), (0.15, wz), (0.3, wz - 0.02)], 0.0016 * age)
    # nose: a soft bridge growing out of the face, a rounded tip, the wings
    ns = nose_s * k
    tip_out = {"round": 0.0125, "button": 0.0095, "straight": 0.0115, "long": 0.013, "hook": 0.014}.get(nose, 0.016) * nose_s * k
    tip_w = {"round": -0.15, "button": -0.13, "straight": -0.16, "long": -0.17, "hook": -0.18}.get(nose, -0.18)
    tip_r = {"round": (0.024, 0.021, 0.021), "button": (0.019, 0.016, 0.016), "straight": (0.017, 0.017, 0.017),
             "long": (0.017, 0.018, 0.018), "hook": (0.018, 0.019, 0.019)}.get(nose, (0.02, 0.02, 0.02))
    nose_col = L.mix(skin, cc, 0.22)
    bump = 0.005 * ns if nose == "hook" else 0.0
    ridge = [face.pt(0.0, 0.06, -0.008 * k), face.pt(0.0, -0.02, 0.002 * ns + bump * 0.5),
             face.pt(0.0, -0.06, tip_out * 0.66 + bump), face.pt(0.0, tip_w + 0.02, tip_out * 0.95)]
    rr = {"round": 0.0115, "button": 0.009, "straight": 0.0085, "long": 0.009, "hook": 0.0095}.get(nose, 0.011) * ns
    add(_painted(sweep(ridge, [rr * 0.6, rr * 0.9, rr * 1.25, rr * 1.55], n=10 if detail else 6, flat=0.85, name="nose"), L.mix(skin, nose_col, 0.4), ao=0.0,
                 var=0.05, top=0.08, seed=seed + 5))
    tip = face.pt(0.0, tip_w, tip_out)
    tnrm = (face.nrm(0.0, tip_w) + Vector((0, 0, -0.15 if nose == "hook" else 0.0))).normalized()
    add(_oell(nose_col, tip, tnrm, tuple(r * nose_s * k for r in tip_r), seg=16, rings=9, ao=0.0, var=0.05, top=0.2,
              seed=seed + 6))
    wing = 1.0 if nose in ("round", "button") else 0.75
    for sx in ((-1, 1) if detail else ()):
        wp = face.pt(sx * 0.11 * wing * (nose_s ** 0.5), tip_w - 0.01, tip_out * 0.15)
        add(_oell(L.mix(nose_col, FACE_SHADE, 0.15), wp, face.nrm(sx * 0.12, tip_w), (0.0095 * ns * wing, 0.008 * ns * wing, 0.0085 * ns * wing),
                  seg=10, rings=6, roll=sx * 20, ao=0.0, var=0.05, seed=seed + 7))
    pts["nose"] = tip
    # mouth
    lipc = lip or L.mix(cc, MOUTH, 0.25)
    pts["mouth"] = face.pt(0.0, mz)
    mw = 0.22 * mouth_w
    curve = {"smile": 0.045, "laugh": 0.06, "kind": 0.035, "thin": 0.0, "stern": -0.025}.get(mouth, 0.03) * smile
    mpts, mrad = [], []
    for i in range(7):
        t = -1.0 + 2.0 * i / 6
        uu = t * mw
        ww = mz + curve * t * t - (0.008 if mouth in ("smile", "laugh", "kind") else 0.0) * (1.0 - t * t)
        mpts.append(face.pt(uu, ww, 0.0012 * k))
        thick = 0.0042 if mouth not in ("thin", "stern") else 0.0032
        mrad.append(thick * k * (0.55 + 0.45 * (1.0 - t * t)))
    add(_painted(sweep(mpts, mrad, n=6, flat=0.6, name="mouth", normals=[face.nrm(0.0, mz)] * 7), MOUTH, ao=0.0, var=0.05,
                 top=0.0, seed=seed + 8))
    if mouth == "laugh":
        add(_oell(L.scale_c(MOUTH, 0.55), face.pt(0.0, mz - 0.035, -0.002 * k), face.nrm(0.0, mz - 0.03),
                  (0.017 * k, 0.005 * k, 0.0085 * k), seg=10, rings=5, ao=0.0, var=0.03, top=0.0))
    if mouth not in ("thin", "stern"):
        lw = 0.014 if mouth != "kind" else 0.011
        add(_oell(lipc, face.pt(0.0, mz - 0.075 - (0.03 if mouth == "laugh" else 0.0), -0.0028 * k),
                  face.nrm(0.0, mz - 0.07), (lw * k * mouth_w, 0.0055 * k, 0.0058 * k), seg=10, rings=5, ao=0.0,
                  var=0.04, top=0.3, seed=seed + 9))
    else:
        add(_oell(L.mix(skin, lipc, 0.6), face.pt(0.0, mz - 0.065, -0.003 * k), face.nrm(0.0, mz - 0.065),
                  (0.012 * k * mouth_w, 0.004 * k, 0.0045 * k), seg=8, rings=4, ao=0.0, var=0.04, top=0.3, seed=seed + 9))
    if ears:
        for sx in (-1, 1):
            d = Vector((sx * 1.0, 0.1, -0.06)).normalized()
            base = face.world(d)
            en = face.normal(d)
            ec = base + en * 0.001 * k
            add(_oell(L.mix(skin, cc, 0.3), ec, en, (0.023 * k, 0.011 * k, 0.034 * k), seg=10, rings=6,
                      roll=0.0, ao=0.0, var=0.06, top=0.1, seed=seed + 10))
            if detail:
                add(_oell(L.mix(skin, FACE_SHADE, 0.3), ec + en * 0.0065 * k + Vector((0, -0.003 * k, 0)), en,
                          (0.014 * k, 0.004 * k, 0.022 * k), seg=8, rings=4, ao=0.0, var=0.04, top=0.0))
    _RES[0] = 1.0
    return pts


# --- deterministic rigged export ---------------------------------------------------------------------

def _stable_glb(path: str) -> None:
    """The glTF exporter evaluates the armature-modified mesh with ulp-level jitter (positions,
    normals, UVs) and writes the vertices in a varying order, so rigged exports differed between runs
    (lib_painted._canonical_glb only sorts triangles). Snap the float attributes of every primitive to a
    fine grid (positions 1/2^16 m, normals 1/512 - coarse enough that the jitter almost never crosses a step, UVs 1/4096), sort the vertices by their bytes,
    remap the indices and sort the triangles: repeated builds are byte-identical."""
    with open(path, "rb") as f:
        data = bytearray(f.read())
    jlen = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + jlen]))
    bin0 = 20 + jlen + 8
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    fmt = {5126: "f", 5121: "B", 5123: "H", 5125: "I"}
    grid = {"POSITION": 65536.0, "NORMAL": 512.0, "TEXCOORD_0": 4096.0}

    def acc_io(i):
        a = doc["accessors"][i]
        v = doc["bufferViews"][a["bufferView"]]
        k = ncomp[a["type"]]
        ch = fmt[a["componentType"]]
        size = struct.calcsize("<" + ch) * k
        stride = v.get("byteStride", size)
        off = bin0 + v.get("byteOffset", 0) + a.get("byteOffset", 0)
        return a, k, ch, size, stride, off

    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" not in prim or prim.get("mode", 4) != 4:
                continue
            attrs = sorted(prim["attributes"].items())
            count = doc["accessors"][attrs[0][1]]["count"]
            cols = {}
            for name, i in attrs:
                a, k, ch, size, stride, off = acc_io(i)
                vals = []
                for n in range(count):
                    t = list(struct.unpack_from("<%d%s" % (k, ch), data, off + n * stride))
                    if name in grid:
                        g = grid[name]
                        # (an off-centre rounding point: no value of the models sat close to it in the review builds)
                        t = [math.floor(x * g + 0.37) / g for x in t]
                    vals.append(t)
                cols[name] = vals
            keys = [tuple(tuple(cols[nm][n]) for nm, _ in attrs) for n in range(count)]
            order = sorted(range(count), key=lambda n: keys[n])
            remap = {old: new for new, old in enumerate(order)}
            for name, i in attrs:
                a, k, ch, size, stride, off = acc_io(i)
                for new, old in enumerate(order):
                    struct.pack_into("<%d%s" % (k, ch), data, off + new * stride, *cols[name][old])
                if name == "POSITION":
                    vs = [cols[name][o] for o in order]
                    a["min"] = [min(v[j] for v in vs) for j in range(3)]
                    a["max"] = [max(v[j] for v in vs) for j in range(3)]
            ai, k, ch, size, stride, off = acc_io(prim["indices"])
            n = ai["count"]
            idx = struct.unpack_from("<%d%s" % (n, ch), data, off)
            tris = []
            for t in range(0, n - n % 3, 3):
                tri = [remap[idx[t]], remap[idx[t + 1]], remap[idx[t + 2]]]
                r = tri.index(min(tri))          # rotate (keeps the winding) so the smallest index is first
                tris.append(tuple(tri[r:] + tri[:r]))
            tris.sort()
            flat = [v for tri in tris for v in tri]
            struct.pack_into("<%d%s" % (len(flat), ch), data, off, *flat)
    # rewrite the JSON chunk (min/max changed) keeping the chunk length (pad with spaces)
    js = json.dumps(doc, separators=(",", ":")).encode()
    if len(js) <= jlen:
        js = js + b" " * (jlen - len(js))
        data[20:20 + jlen] = js
    with open(path, "wb") as f:
        f.write(data)


def finish_stable(obj, name: str, cat: str, smooth: float = 35.0, shift: bool = True) -> None:
    """lib_painted.finish() + _stable_glb(): the Phase-7 static exports are canonicalised the same way."""
    L.finish(obj, name, cat, smooth, shift=shift)
    _stable_glb(L.os.path.join(L.ROOT, "assets", "models", cat, name + ".glb"))
