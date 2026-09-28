"""Phase-5 grave stones and ornament reliefs (docs/PHASE5_DESIGN.md section 8), 'Gemaltes Diorama'.

  ph_prop_gravestone_stele    plain stele: a dressed slab with a low gabled top, a rough footing
  ph_prop_gravestone_arch     round-arched stone with a raised band along the arch
  ph_prop_gravestone_master   Meisterstein: wide, on a chamfered plinth, pilasters, a cornice and a
                              gable (pediment), two iron clamps (L-straps) holding body and plinth
  ph_prop_orn_ivy / _poppy / _elder / _torch
                              flat relief ornaments (0.02 m) in the same stone colour, only form

Markers (glTF empties -> Node3D in Godot, identity rotation = local +Z is the face normal):
  inscription   centre of the text field, on the front face (Label3D, StoneShapeData.label_width)
  ornament      centre of the relief field, on the front face (the relief models' origin)

Reliefs: origin = centre of the relief's back plane, the relief rises 0.02 m towards the model
front (Godot +Z), about 0.2 x 0.2 m - the same model fits the field of every stone shape.
Front = -Y (Blender) = +Z (Godot), stones: pivot bottom centre, shared materials only.
Run:  python tools/blender/build_all.py asset_stones_phase5
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector

import lib_painted as L
import asset_props_slice as P

STONE = L.hexc("#8A8F94")          # palette: stone / grave stones (cool blue-grey)
STONE_DRESSED = L.hexc("#959AA0")  # a freshly dressed face, a touch lighter
STONE_SHADE = L.hexc("#6E7379")
STONE_OLD = P.STONE_OLD
MOSS = P.MOSS
IRON = P.IRON
RUST = P.RUST
RELIEF_D = 0.02                    # relief depth (section 8)
RELIEF_SCALE = 1.25                # drawn at ~0.2 m, scaled to ~0.25 m across

# (inscription centre z, ornament centre z, front face y) per shape - shared with the tests via the markers
STELE = {"w": 0.58, "t": 0.13, "h": 0.94, "gable": 0.08, "ins_z": 0.5, "orn_z": 0.8}
ARCH = {"w": 0.64, "t": 0.14, "h": 0.68, "ins_z": 0.44, "orn_z": 0.78}
MASTER = {"w": 0.86, "t": 0.2, "plinth": (1.02, 0.38, 0.2), "body_top": 1.04, "gable": 0.36,
          "ins_z": 0.62, "orn_z": 1.24}


def _prism(poly_xz, thickness: float, y: float = 0.0, name: str = "prism"):
    """Polygon in the XZ plane extruded along Y, centred on y (front face at y - t/2)."""
    bm = bmesh.new()
    a = [bm.verts.new((x, y - thickness / 2, z)) for x, z in poly_xz]
    b = [bm.verts.new((x, y + thickness / 2, z)) for x, z in poly_xz]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(poly_xz)
    for i in range(n):
        bm.faces.new((a[(i + 1) % n], a[i], b[i], b[(i + 1) % n]))
    return P._link(bm, name)


def _chamfer_box(loc, half, ch: float, seed: int, color, jit: float = 0.004, **paint_kw):
    """Dressed block with chamfered edges (one bevel segment), a little hand-made wobble."""
    o = L.prim("cube", loc=loc, scale=half)
    L.bevel(o, ch, 1)
    if jit:
        L.jitter(o, jit, 3.0, seed)
    return P._finish_obj(o, color, seed=seed, **paint_kw)


def _stone_paint(obj, zr, seed: int, moss: float = 0.35, color=STONE) -> None:
    """New stone: cool blue-grey, lighter dressed faces, only a breath of moss at the foot."""
    L.paint(obj, color, var=0.14, ao=0.35, top=0.1, zrange=zr, noise_freq=3.0, hue_shift=STONE_SHADE, seed=seed)
    L.set_mat(obj, L.MAT_PAINTED)
    if moss > 0:
        me = obj.data
        attr = me.color_attributes["Col"]
        lin = [L._to_lin(c) for c in MOSS]
        for poly in me.polygons:
            for li in poly.loop_indices:
                z = me.vertices[me.loops[li].vertex_index].co.z
                t = moss * max(0.0, 1.0 - (z - zr[0]) / 0.12)
                c = attr.data[li].color
                attr.data[li].color = tuple(c[k] + (lin[k] - c[k]) * t for k in range(3)) + (1.0,)


def _footing(w: float, d: float, seed: int):
    """Rough, half-sunk footing stone under a stele or arch stone."""
    o = L.prim("cube", loc=(0, 0, 0.02), scale=(w / 2, d / 2, 0.05))
    L.subdivide(o, 1)
    L.jitter(o, 0.012, 4.0, seed)
    L.paint(o, STONE_OLD, var=0.22, ao=0.5, top=0.15, hue_shift=MOSS, seed=seed)
    P._tint_up(o, MOSS, 0.6, 0.5, freq=6.0, seed=seed)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _subdivided_slab(poly_xz, t: float, cuts: int, name: str):
    """Prism with its big faces subdivided (paint and wobble need inner vertices)."""
    o = _prism(poly_xz, t, name=name)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    big = [e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) < 1e-6]
    bmesh.ops.subdivide_edges(bm, edges=big, cuts=cuts, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(o.data)
    bm.free()
    return o


# --- the three shapes --------------------------------------------------------------------------

def gravestone_stele():
    """Schlichte Stele: 0.58 m wide, 1.0 m high, a low gable, chamfered edges, on a rough footing."""
    L.reset(1500)
    s = STELE
    w, t, h, g = s["w"], s["t"], s["h"], s["gable"]
    body = L.prim("cube", loc=(0, 0, 0.05 + (h - 0.05) / 2), scale=(w / 2, t / 2, (h - 0.05) / 2))
    L.bevel(body, 0.012, 1)
    top = _prism([(-w / 2 + 0.012, h), (w / 2 - 0.012, h), (0.0, h + g)], t - 0.01, name="gable")
    for o, sd in ((body, 1), (top, 2)):
        L.jitter(o, 0.003, 3.0, sd)
        _stone_paint(o, (0.0, h + g), sd)
    parts = [_footing(w + 0.14, t + 0.12, 3), body, top]
    obj = L.join(parts, "ph_prop_gravestone_stele")
    L.marker(obj, "inscription", (0.0, -t / 2, s["ins_z"]))
    L.marker(obj, "ornament", (0.0, -t / 2, s["orn_z"]))
    P._center_xy(obj)
    L.finish(obj, "ph_prop_gravestone_stele", "props", 30)


def gravestone_arch():
    """Rundbogenstein: 0.64 m wide, 1.0 m high; a raised band follows the semicircular top."""
    L.reset(1510)
    s = ARCH
    w, t, h = s["w"], s["t"], s["h"]
    r = w / 2
    n = 14
    poly = [(-r, 0.05), (r, 0.05)] + [(math.cos(math.pi * k / n) * r, h + math.sin(math.pi * k / n) * r)
                                      for k in range(n + 1)]
    body = _prism(poly, t, name="arch")
    L.jitter(body, 0.003, 3.0, 1)
    _stone_paint(body, (0.0, h + r), 2)
    band = [(math.cos(math.pi * k / n) * (r - 0.035), -t / 2 - 0.006, h + math.sin(math.pi * k / n) * (r - 0.035))
            for k in range(n + 1)]
    band = [(band[0][0], band[0][1], h - 0.06)] + band + [(band[-1][0], band[-1][1], h - 0.06)]
    rim = P._path_tube(band, 0.012, 4, hint=(0, 1, 0), name="band")
    _stone_paint(rim, (0.0, h + r), 3, moss=0.0, color=STONE_DRESSED)
    parts = [_footing(w + 0.14, t + 0.12, 4), body, rim]
    obj = L.join(parts, "ph_prop_gravestone_arch")
    L.marker(obj, "inscription", (0.0, -t / 2, s["ins_z"]))
    L.marker(obj, "ornament", (0.0, -t / 2, s["orn_z"]))
    P._center_xy(obj)
    L.finish(obj, "ph_prop_gravestone_arch", "props", 30)


def _clamp(x: float, body_y: float, plinth_top: float, plinth_y: float, seed: int):
    """Iron L-strap: down the body face, bent over onto the plinth, two rivet heads, rusty."""
    parts = [L.part("cube", IRON, loc=(x, body_y - 0.006, plinth_top + 0.07), scale=(0.022, 0.006, 0.07)),
             L.part("cube", IRON, loc=(x, (body_y + plinth_y) / 2 - 0.004, plinth_top + 0.006),
                    scale=(0.022, (body_y - plinth_y) / 2 + 0.004, 0.006))]
    for z in (plinth_top + 0.045, plinth_top + 0.11):
        parts.append(L.part("cyl", IRON, loc=(x, body_y - 0.013, z), rot=(90, 0, 0), radius=0.009, depth=0.006,
                            vertices=6))
    for o in parts:
        L.paint(o, IRON, var=0.3, ao=0.1, top=0.3, hue_shift=RUST, seed=seed)
        L.set_mat(o, L.MAT_PAINTED)
        P._tint_up(o, L.hexc("#7A4E34"), 0.6, 0.2, freq=12.0, seed=seed)
    return parts


def gravestone_master():
    """Meisterstein: chamfered plinth 1.02 m wide, body with two pilasters, a projecting cornice
    and a pediment (gable) with the ornament field, two iron clamps at the plinth joint; 1.4 m."""
    L.reset(1520)
    s = MASTER
    w, t = s["w"], s["t"]
    pw, pd, ph = s["plinth"]
    bt, g = s["body_top"], s["gable"]
    parts = []
    plinth = _chamfer_box((0, 0, ph / 2), (pw / 2, pd / 2, ph / 2), 0.025, 1, STONE, jit=0.003)
    _stone_paint(plinth, (0.0, 1.4), 1, moss=0.4)
    parts.append(plinth)
    step = _chamfer_box((0, 0, ph + 0.02), ((w + 0.06) / 2, (t + 0.05) / 2, 0.02), 0.008, 2, STONE)
    _stone_paint(step, (0.0, 1.4), 2, moss=0.0)
    parts.append(step)
    body_z0 = ph + 0.04
    body = L.prim("cube", loc=(0, 0, (body_z0 + bt) / 2), scale=(w / 2, t / 2, (bt - body_z0) / 2))
    L.bevel(body, 0.008, 1)
    L.jitter(body, 0.002, 3.0, 3)
    _stone_paint(body, (0.0, 1.4), 3, moss=0.0, color=STONE_DRESSED)
    parts.append(body)
    for sx in (-1, 1):  # pilasters framing the text field, with small capitals
        pil = L.prim("cube", loc=(sx * (w / 2 - 0.035), -t / 2 - 0.008, (body_z0 + bt) / 2 - 0.01),
                     scale=(0.032, 0.01, (bt - body_z0) / 2 - 0.01))
        _stone_paint(pil, (0.0, 1.4), 4 + sx, moss=0.0)
        parts.append(pil)
        cap = L.prim("cube", loc=(sx * (w / 2 - 0.035), -t / 2 - 0.013, bt - 0.04), scale=(0.042, 0.016, 0.018))
        _stone_paint(cap, (0.0, 1.4), 6 + sx, moss=0.0)
        parts.append(cap)
    cornice = _chamfer_box((0, 0, bt + 0.03), ((w + 0.08) / 2, (t + 0.06) / 2, 0.03), 0.012, 8, STONE)
    _stone_paint(cornice, (0.0, 1.4), 8, moss=0.0)
    parts.append(cornice)
    gz = bt + 0.06
    ped = _prism([(-w / 2, gz), (w / 2, gz), (0.0, gz + g)], t, name="pediment")
    _stone_paint(ped, (0.0, 1.4), 9, moss=0.0, color=STONE_DRESSED)
    parts.append(ped)
    # raking mouldings along the pediment's two slopes
    for sx in (-1, 1):
        a = Vector((sx * (w / 2 + 0.02), -t / 2 - 0.008, gz))
        b = Vector((0.0, -t / 2 - 0.008, gz + g + 0.02))
        rake = L.tube(a, b, 0.018, 4)
        _stone_paint(rake, (0.0, 1.4), 10 + sx, moss=0.0)
        parts.append(rake)
    parts.append(L.part("sphere", STONE, loc=(0.0, 0.0, gz + g + 0.035), radius=0.045, segments=8, ring_count=5,
                        paint_kw={"ao": 0.0, "top": 0.2, "hue_shift": STONE_SHADE}))
    for sx in (-1, 1):
        parts += _clamp(sx * (w / 2 - 0.13), -t / 2, ph, -pd / 2 + 0.03, 20 + sx)
    obj = L.join(parts, "ph_prop_gravestone_master")
    L.marker(obj, "inscription", (0.0, -t / 2, s["ins_z"]))
    L.marker(obj, "ornament", (0.0, -t / 2, s["orn_z"]))
    P._center_xy(obj)
    L.finish(obj, "ph_prop_gravestone_master", "props", 30)


# --- ornament reliefs --------------------------------------------------------------------------
# Built lying in the XZ plane (x right, z up) with the back at y = 0 and the relief towards -Y.

def _relief_blob(x: float, z: float, rx: float, rz: float, seed: int, yaw: float = 0.0, depth: float = RELIEF_D,
                 segs: int = 6, rings: int = 3):
    """Low half-dome (leaf, berry, capsule) standing out of the back plane."""
    o = L.prim("sphere", radius=1.0, segments=segs, ring_count=rings * 2)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    # dome axis z -> -y (towards the front), squash to the relief depth
    o.data.transform(Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Y")
                     @ Matrix.Diagonal((rx, depth, rz, 1.0)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    return o


def _relief_line(points_xz, r: float, depth: float = RELIEF_D * 0.7, sides: int = 4):
    """Stem / shaft: a flattened tube lying on the back plane."""
    pts = [(x, 0.0, z) for x, z in points_xz]
    # elliptic section: wide along the plane, shallow towards the front
    bm = bmesh.new()
    ring_prev = None
    first = None
    n = len(pts)
    for i, p in enumerate(pts):
        p = Vector(p)
        tvec = (Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        side = Vector((0, 1, 0)).cross(tvec).normalized()
        ring = []
        for j in range(sides):
            a = j / sides * math.tau
            q = Vector((p.x, 0.0, p.z)) + side * math.cos(a) * r + Vector((0, -1, 0)) * max(0.0, math.sin(a)) * depth
            ring.append(bm.verts.new(q))
        if ring_prev:
            for j in range(sides):
                bm.faces.new((ring_prev[j], ring_prev[(j + 1) % sides], ring[(j + 1) % sides], ring[j]))
        else:
            first = ring
        ring_prev = ring
    bm.faces.new(list(reversed(first)))
    bm.faces.new(ring_prev)
    return P._link(bm, "stem")


def _relief_poly(poly_xz, depth: float = RELIEF_D, inset: float = 0.004):
    """Flat shape (flame, capsule crown, ribbon): outline extruded towards the front, the front
    face shrunk by `inset` so the edges slope like a carved relief."""
    bm = bmesh.new()
    cx = sum(p[0] for p in poly_xz) / len(poly_xz)
    cz = sum(p[1] for p in poly_xz) / len(poly_xz)
    back = [bm.verts.new((x, 0.0, z)) for x, z in poly_xz]
    front = []
    for x, z in poly_xz:
        d = Vector((cx - x, 0, cz - z))
        k = min(1.0, inset / max(1e-6, d.length))
        front.append(bm.verts.new((x + d.x * k, -depth, z + d.z * k)))
    bm.faces.new(front)
    n = len(poly_xz)
    for i in range(n):
        bm.faces.new((back[i], back[(i + 1) % n], front[(i + 1) % n], front[i]))
    return P._link(bm, "relief")


def _finish_relief(parts, name: str) -> None:
    for i, o in enumerate(parts):
        L.paint(o, STONE_DRESSED, var=0.1, ao=0.0, top=0.25, noise_freq=6.0, hue_shift=STONE_SHADE, seed=i)
        L.set_mat(o, L.MAT_PAINTED)
    obj = L.join(parts, name)
    # centre the relief on its origin in x and height (z), back plane stays at y = 0
    xs = [v.co.x for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx, cz = (min(xs) + max(xs)) / 2, (min(zs) + max(zs)) / 2
    for v in obj.data.vertices:
        v.co.x = (v.co.x - cx) * RELIEF_SCALE
        v.co.z = (v.co.z - cz) * RELIEF_SCALE
        v.co.y = min(0.0, max(-RELIEF_D, v.co.y))
    L.smooth(obj, 40)
    L.export(obj, name, "props")


def _ivy_leaf(x: float, z: float, size: float, yaw: float):
    """Three-lobed ivy leaf outline (heart base, pointed middle lobe)."""
    pts = []
    for k in range(10):
        a = k / 10 * math.tau
        lobe = 0.62 + 0.38 * abs(math.cos(1.5 * a))         # three lobes
        rr = size * lobe * (0.75 if math.sin(a) < -0.5 else 1.0)
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    return _relief_poly([(x + px * ca - pz * sa, z + px * sa + pz * ca) for px, pz in pts], inset=size * 0.25)


def orn_ivy():
    """Efeuranke: a gently waving tendril across the field, five three-lobed leaves on short
    stalks, alternately above and below, their middle lobes pointing away from the stem."""
    L.reset(1600)
    stem = [(-0.11 + 0.022 * i, 0.022 * math.sin(i * 0.75)) for i in range(11)]
    parts = [_relief_line(stem, 0.0055)]
    for k, (i, side, sz) in enumerate(((1, 1, 0.036), (3, -1, 0.034), (5, 1, 0.04), (7, -1, 0.034), (9, 1, 0.032))):
        x, z = stem[i]
        tip = (x + 0.006 * side, z + side * 0.03)
        parts.append(_relief_line([(x, z), tip], 0.003, depth=RELIEF_D * 0.5))
        parts.append(_ivy_leaf(tip[0], tip[1] + side * sz * 0.8, sz, 90 * side + (12 if k % 2 else -12)))
    _finish_relief(parts, "ph_prop_orn_ivy")


def orn_poppy():
    """Mohnkapsel: two seed capsules on crossed stems, crowned with a star-shaped cap, one leaf."""
    L.reset(1610)
    parts = []
    for sx, lean in ((-1, -14), (1, 16)):
        base = (sx * -0.03, -0.1)
        top = (sx * 0.045, 0.03)
        parts.append(_relief_line([base, ((base[0] + top[0]) / 2 + sx * 0.01, -0.04), top], 0.0055))
        cx, cz = top[0], top[1] + 0.035
        parts.append(_relief_blob(cx, cz, 0.032, 0.04, 1, yaw=lean, segs=8))
        crown = []
        for k in range(12):                                  # star-shaped crown on the capsule
            a = k / 12 * math.pi
            rr = 0.03 if k % 2 == 0 else 0.018
            crown.append((cx + math.cos(a) * rr, cz + 0.036 + math.sin(a) * rr * 0.35))
        crown.append((cx - 0.03, cz + 0.03))
        parts.append(_relief_poly([(x, z) for x, z in crown], depth=RELIEF_D * 0.9, inset=0.003))
    leaf = [(-0.02, -0.07), (-0.06, -0.05), (-0.1, -0.055), (-0.085, -0.075), (-0.05, -0.085)]
    parts.append(_relief_poly(leaf, depth=RELIEF_D * 0.6, inset=0.006))
    _finish_relief(parts, "ph_prop_orn_poppy")


def orn_elder():
    """Holunderdolde: a flat-topped umbel of little florets on radiating stalks, two leaflets."""
    L.reset(1620)
    parts = [_relief_line([(0.0, -0.1), (0.0, -0.02)], 0.006)]
    for k in range(5):                                         # radiating stalks
        a = math.radians(30 + k * 30)
        parts.append(_relief_line([(0.0, -0.02), (math.cos(a) * 0.075, -0.02 + math.sin(a) * 0.06)], 0.0035,
                                  depth=RELIEF_D * 0.5))
    rnd = random.Random(1621)
    for k in range(11):                                        # florets along the flat top
        x = -0.1 + k * 0.02
        z = 0.045 + 0.018 * math.cos(x / 0.1 * 1.2) + rnd.uniform(-0.006, 0.006)
        parts.append(_relief_blob(x, z, 0.014, 0.014, k, segs=6, rings=2))
    for k in range(3):
        x = -0.05 + k * 0.05
        parts.append(_relief_blob(x, 0.075, 0.012, 0.012, 20 + k, segs=6, rings=2))
    for sx in (-1, 1):                                         # two leaflets at the stalk
        c = (sx * 0.04, -0.075)
        parts.append(_relief_blob(c[0], c[1], 0.034, 0.013, 30 + sx, yaw=sx * -25, depth=RELIEF_D * 0.7, segs=6))
    _finish_relief(parts, "ph_prop_orn_elder")


def orn_torch():
    """Gesenkte Fackel: a torch held head-down, bound with a spiral band, its flame licking down
    and dying; a ribbon bow at the grip with two tails (the old sign of a life gone out)."""
    L.reset(1630)
    parts = [_relief_line([(0.0, 0.11), (0.0, -0.03)], 0.013, depth=RELIEF_D * 0.8, sides=5)]
    for k in range(3):                                   # spiral binding on the shaft
        z = 0.06 - k * 0.03
        parts.append(_relief_line([(-0.015, z - 0.008), (0.015, z + 0.008)], 0.004, depth=RELIEF_D * 0.95))
    head = [(-0.03, -0.03), (0.03, -0.03), (0.022, -0.062), (-0.022, -0.062)]
    parts.append(_relief_poly(head, depth=RELIEF_D, inset=0.003))
    flame = [(-0.024, -0.064), (0.024, -0.064), (0.034, -0.08), (0.026, -0.1), (0.03, -0.118), (0.012, -0.108),
             (0.006, -0.135), (-0.008, -0.112), (-0.024, -0.125), (-0.022, -0.1), (-0.034, -0.082)]
    parts.append(_relief_poly(flame, depth=RELIEF_D * 0.7, inset=0.006))
    parts.append(_relief_blob(0.0, 0.09, 0.022, 0.012, 5, segs=6, rings=2))     # the bow's knot
    for sx in (-1, 1):
        loop = [(0.0, 0.09), (sx * 0.04, 0.108), (sx * 0.05, 0.09), (sx * 0.04, 0.074)]
        parts.append(_relief_poly(loop if sx > 0 else list(reversed(loop)), depth=RELIEF_D * 0.6, inset=0.004))
        parts.append(_relief_line([(sx * 0.008, 0.085), (sx * 0.03, 0.05), (sx * 0.026, 0.02)], 0.005,
                                  depth=RELIEF_D * 0.5))
    _finish_relief(parts, "ph_prop_orn_torch")


ASSETS = (gravestone_stele, gravestone_arch, gravestone_master, orn_ivy, orn_poppy, orn_elder, orn_torch)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
