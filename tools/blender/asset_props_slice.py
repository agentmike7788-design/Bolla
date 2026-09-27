"""Vertical-slice props (Phase 2, contract section 8), 'Gemaltes Diorama' style.

Corpse (four plain looks + shrouded), handcart, morgue table, workbench, drop-off bier, grave plot
(empty / open pit), wood pile, stone rubble, wooden cross, signpost, fallen log
and a bush.  Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m.

Markers (glTF nodes, found by name in Godot):
  slot_corpse  table, bier, handcart - where a corpse lies; the marker's local +X
               is the corpse's long axis (the corpse models lie along X).
  label_board  signpost - front face of the arrow board (for a Label3D).

Run:  python -c "import sys; sys.path.insert(0, 'tools/blender'); import asset_props_slice as a; a.build()"
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
from asset_environment import _limb as limb  # same gnarled limbs as the approved oak

# --- palette (ART_DIRECTION.md section 3 + Phase 1 asset colours) ----------
WOOD = L.hexc("#6E5238")
WOOD_DARK = L.hexc("#4A3626")
WOOD_OLD = L.hexc("#6B5E50")      # weathered, grey
WOOD_FRESH = L.hexc("#9C7B55")    # freshly split / sawn
END_GRAIN = L.hexc("#B08C62")
IRON = L.hexc("#3A3C40")
RUST = L.hexc("#6A4A3A")
STEEL = L.hexc("#7C8187")
STONE = L.hexc("#7E8187")
STONE_OLD = L.hexc("#686B64")
STONE_BLUE = L.hexc("#8A8F94")
MOSS = L.hexc("#5E7148")
EARTH = L.hexc("#6B5A48")
EARTH_FRESH = L.hexc("#4E3B2C")
EARTH_DARK = L.hexc("#2A1F18")
PIT_BLACK = L.hexc("#120D0A")
GRASS = L.hexc("#5E7148")
GRASS_B = L.hexc("#667A48")
BARK = L.hexc("#5A4A3C")
BARK_DARK = L.hexc("#3E3229")
LEAF_A = L.hexc("#44573A")
LEAF_B = L.hexc("#5E7145")
LINEN = L.hexc("#D2C8AE")
LINEN_DIRTY = L.hexc("#B5AA8E")
ROPE = L.hexc("#8C7650")
STRING = L.hexc("#B9A77E")
SKIN = L.hexc("#76816F")          # pale grey-green (the painted shader lifts it to a pale ash)
BOOT = L.hexc("#2E2620")
LEATHER = L.hexc("#3B2E24")

CORPSE_ZR = (0.0, 0.27)           # shared AO range: the whole body shades as one form


# --- local helpers (built on lib_painted) ----------------------------------

def _link(bm, name: str):
    """bmesh -> new mesh object in the scene."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _finish_obj(obj, color, mat: str = L.MAT_PAINTED, **paint_kw):
    L.paint(obj, color, **paint_kw)
    L.set_mat(obj, mat)
    return obj


def _rbox(loc, half, color, bev: float = 0.03, seg: int = 2, jit: float = 0.006, seed: int = 0,
          rot=(0, 0, 0), **paint_kw):
    """Rounded, slightly wobbly box (bevelled cube)."""
    o = L.prim("cube", loc=loc, rot=rot, scale=half)
    L.bevel(o, bev, seg)
    if jit > 0:
        L.jitter(o, jit, 3.0, seed)
    return _finish_obj(o, color, seed=seed, **paint_kw)


def _plank(loc, half, color, seed: int = 0, rot=(0, 0, 0), jit: float = 0.005, cuts: int = 0, **paint_kw):
    """Hand-cut board: box with a little wobble and its own colour variation."""
    o = L.prim("cube", loc=loc, rot=rot, scale=half)
    if cuts:
        L.subdivide(o, cuts)
    if jit > 0:
        L.jitter(o, jit, 2.5, seed)
    col = L.scale_c(color, random.uniform(0.86, 1.12))
    return _finish_obj(o, col, seed=seed, **paint_kw)


def _stick(p0, p1, r0: float, color, r1=None, verts: int = 6, seed: int = 0, **paint_kw):
    """Tapered tube between two points, painted."""
    return _finish_obj(L.tube(p0, p1, r0, verts, r_end=r1), color, seed=seed, **paint_kw)


def _path_tube(points, radius: float, sides: int = 5, closed: bool = False, hint=(0, 0, 1), name: str = "tube"):
    """Tube along a polyline (ropes, strings). `hint` fixes the ring orientation."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    h = Vector(hint)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        b1 = (h - t * h.dot(t)).normalized()
        b2 = t.cross(b1).normalized()
        rings.append([bm.verts.new(p + (b1 * math.cos(a) + b2 * math.sin(a)) * radius)
                      for a in (j / sides * math.tau for j in range(sides))])
    for i in range(n if closed else n - 1):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for j in range(sides):
            bm.faces.new((r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]))
    if not closed:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return _link(bm, name)


def _paint_fn(obj, fn) -> None:
    """Vertex-paint with fn(co, vertex_index) -> sRGB colour (gradients L.paint cannot do)."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            c = fn(me.vertices[vi].co, vi)
            attr.data[li].color = (L._to_lin(c[0]), L._to_lin(c[1]), L._to_lin(c[2]), 1.0)


def _tint_up(obj, color, amount: float = 0.8, min_up: float = 0.3, freq: float = 2.2, seed: int = 0) -> None:
    """Blend already painted colours towards `color` on up-facing faces (moss on top, dust...)."""
    me = obj.data
    attr = me.color_attributes["Col"]
    lin = [L._to_lin(c) for c in color]
    off = Vector((seed * 2.3, seed * 4.1, seed * 1.7))
    for poly in me.polygons:
        up = (poly.normal.z - min_up) / max(1e-6, 1.0 - min_up)
        if up <= 0.0:
            continue
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            n = 0.5 + 0.5 * noise.noise(co * freq + off)
            t = max(0.0, min(1.0, up * amount * (0.35 + n)))
            c = attr.data[li].color
            attr.data[li].color = (c[0] + (lin[0] - c[0]) * t, c[1] + (lin[1] - c[1]) * t,
                                   c[2] + (lin[2] - c[2]) * t, 1.0)


def _modulate(obj, fn) -> None:
    """Multiply already painted colours by fn(co) (brightness patterns such as cloth bands)."""
    me = obj.data
    attr = me.color_attributes["Col"]
    for poly in me.polygons:
        for li in poly.loop_indices:
            f = fn(me.vertices[me.loops[li].vertex_index].co)
            c = attr.data[li].color
            attr.data[li].color = (c[0] * f, c[1] * f, c[2] * f, 1.0)


def _center_xy(obj) -> None:
    """Move the footprint centre (bounding box in XY) to the origin, children included."""
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for v in obj.data.vertices:
        v.co.x -= cx
        v.co.y -= cy
    for child in obj.children:
        child.location.x -= cx
        child.location.y -= cy


def _slot(parent, loc, yaw_deg: float = 0.0, name: str = "slot_corpse") -> None:
    """lib marker() plus a yaw: the marker's +X is the long axis of whatever lies there."""
    L.marker(parent, name, loc)
    e = next(c for c in parent.children if c.name == name)
    e.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))


def _clods(n: int, xr, yr, color, r=(0.03, 0.06), z: float = 0.02, seed: int = 0):
    """Scattered earth clods / pebbles (20-tri icospheres)."""
    out = []
    for i in range(n):
        out.append(L.part("ico", L.scale_c(color, random.uniform(0.85, 1.15)),
                          loc=(random.uniform(*xr), random.uniform(*yr), z),
                          radius=random.uniform(*r), subdivisions=1, jit=0.012, seed=seed + i,
                          paint_kw={"ao": 0.3}))
    return out


# --- corpses -------------------------------------------------------------------
# Four plain looks from one body kit (ph_prop_corpse = variant 0, _02 .. _04) plus the
# shrouded body. All lie on the back along X (head at +X, face up = +Z), ~1.72 m long and
# ~0.6 m wide with the footprint centred, so every look sits the same on the slot_corpse of
# table, bier and handcart. Peaceful, never gory: closed eyes, folded hands, tidy clothes.
# Same proportion family as the characters: big head, big hands, big boots.

SKIN_ASH = L.hexc("#6A6874")      # lilac-grey hollows (eye sockets)
SKIN_WARM = L.hexc("#858A74")     # ashen highlights (cheeks, nose, knuckles)
LIP = L.hexc("#76696A")
LASH = L.hexc("#3E3733")
BRASS = L.hexc("#8E7F55")         # dull, never shiny
CORPSE_SMOOTH = 80.0              # smooth-shading angle: soft limbs, only the soles stay crisp

HEAD_C = Vector((0.725, 0.0, 0.132))
HEAD_R = 0.135
HEAD_S = Vector((1.07, 0.93, 0.95))
# Ring angles of body lofts (degrees, 0 = +Y side, 90 = top): dense on the visible top.
ANG = (0, 22, 42, 60, 75, 90, 105, 120, 138, 158, 180, 270)
# Torso outline: x, y centre, z centre, half width, top, bottom (bottom = z centre: lies flat)
TORSO = [(-0.15, 0.0, 0.09, 0.150, 0.056, 0.09), (-0.07, 0.0, 0.10, 0.172, 0.078, 0.10),
         (0.03, 0.0, 0.10, 0.168, 0.086, 0.10), (0.13, 0.0, 0.10, 0.178, 0.097, 0.10),
         (0.24, 0.0, 0.105, 0.19, 0.106, 0.105), (0.35, 0.0, 0.105, 0.198, 0.112, 0.105),
         (0.44, 0.0, 0.105, 0.198, 0.103, 0.105), (0.5, 0.0, 0.1, 0.18, 0.085, 0.1),
         (0.545, 0.0, 0.1, 0.118, 0.062, 0.095), (0.575, 0.0, 0.1, 0.07, 0.048, 0.09)]
# Folded hands on the belly (the upper hand comes from the +Y wrist)
WRIST = {1: Vector((0.262, 0.078, 0.238)), -1: Vector((0.25, -0.082, 0.226))}
LEG_X = (-0.07, -0.25, -0.43, -0.685)


def _frame(normal, ref) -> Matrix:
    """4x4 rotation whose local z = normal and local x = ref (made orthogonal)."""
    z = Vector(normal).normalized()
    x = Vector(ref) - z * Vector(ref).dot(z)
    x.normalize()
    return Matrix((x, z.cross(x), z)).transposed().to_4x4()


def _shade(c, co, up: float = 0.5, var: float = 0.08, ao: float = 0.3, top: float = 0.1, freq: float = 3.0,
           seed: int = 0):
    """Painted-look colour at a vertex: noise, fake AO over the body height, top light
    (`up` = vertex normal z, so the light is as smooth as the shading)."""
    n = noise.noise(co * freq + Vector((seed * 3.7, seed * 1.9, seed * 5.3)))
    h = max(0.0, min(1.0, co.z / CORPSE_ZR[1]))
    return L.scale_c(c, (1.0 + n * var) * (1.0 - ao * (1.0 - h) ** 2) * (1.0 + top * max(0.0, up)))


def _paint_poly(obj, fn) -> None:
    """Vertex-paint every face corner with fn(co, poly, vertex_index) -> sRGB: colour zones follow
    the faces (crisp seams between clothes), soft variation inside."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            c = fn(me.vertices[vi].co, poly, vi)
            attr.data[li].color = (L._to_lin(c[0]), L._to_lin(c[1]), L._to_lin(c[2]), 1.0)


def _cloth(obj, fn, var: float = 0.12, ao: float = 0.3, top: float = 0.2, freq: float = 4.0, seed: int = 0):
    """Paint with a zone function fn(co, poly) -> base colour, shaded; shared painted material."""
    vn = obj.data.vertices
    _paint_poly(obj, lambda co, poly, vi: _shade(fn(co, poly), co, vn[vi].normal.z, var, ao, top, freq, seed))
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _flat(color):
    return lambda co, poly: color


def _blob(kind: str, half, pos, normal=(0, 0, 1), ref=(1, 0, 0), color=(1, 1, 1), fn=None, jit: float = 0.0,
          seed: int = 0, var: float = 0.08, ao: float = 0.3, top: float = 0.1, **kw):
    """Primitive scaled by `half` in a local frame (local z = normal, local x = ref), moved to pos.
    fn(local_co, poly) -> base colour paints in local coordinates (lash lines, lip seams ...)."""
    o = L.prim(kind, scale=half, **kw)
    if jit > 0:
        L.jitter(o, jit, 40.0, seed)
    local = [v.co.copy() for v in o.data.vertices]
    o.data.transform(Matrix.Translation(Vector(pos)) @ _frame(normal, ref))
    if fn is None:
        return _cloth(o, _flat(color), var=var, ao=ao, top=top, seed=seed)
    vn = o.data.vertices
    _paint_poly(o, lambda co, poly, vi: _shade(fn(local[vi], poly), co, vn[vi].normal.z, var, ao, top, 4.0, seed))
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _tube(points, radii, sides: int = 6, hint=(0, 0, 1), caps=(True, True), name: str = "tube"):
    """Tube along a polyline with a radius per point (limbs, sleeves, fingers).
    caps = (start, end): hidden ends (inside the torso, a boot ...) stay open."""
    pts = [Vector(p) for p in points]
    n = len(pts)
    h = Vector(hint)
    bm = bmesh.new()
    rings = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        b1 = (h - t * h.dot(t)).normalized()
        b2 = t.cross(b1).normalized()
        rings.append([bm.verts.new(p + (b1 * math.cos(a) + b2 * math.sin(a)) * radii[i])
                      for a in (j / sides * math.tau for j in range(sides))])
    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        for j in range(sides):
            bm.faces.new((r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])
    return _raw(bm, name)


def _raw(bm, name: str):
    """bmesh -> mesh object, keeping the winding as built (open sheets and tubes point outwards)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _sec(secs, x: float):
    """Loft section (y centre, z centre, half width, top, bottom) interpolated at x (clamped)."""
    if x <= secs[0][0]:
        return secs[0][1:]
    for a, b in zip(secs, secs[1:]):
        if x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in range(1, 6))
    return secs[-1][1:]


def _on_loft(secs, x: float, a_deg: float, lift: float = 0.0, fold=None) -> Vector:
    """Point on a loft surface at x and ring angle a (degrees), pushed out by lift."""
    yc, zc, hw, top, bot = _sec(secs, x)
    a = math.radians(a_deg)
    c, s = math.cos(a), math.sin(a)
    f = fold(x, a) if fold else 1.0
    rz = (top * f if s >= 0 else bot) + lift
    return Vector((x, yc + (hw * f + lift) * c, zc + rz * s))


def _loft_angle(secs, co) -> float:
    """Ring angle (degrees 0..360) of a point relative to the loft section at its x."""
    yc, zc, hw, top, bot = _sec(secs, co.x)
    dz = co.z - zc
    return math.degrees(math.atan2(dz / (top if dz >= 0 else bot), (co.y - yc) / hw)) % 360.0


def _loft(secs, angles=ANG, fold=None, caps=(True, True), name: str = "loft"):
    """Loft along X through the sections, rings at the given angles; faces point outwards."""
    bm = bmesh.new()
    rings = [[bm.verts.new(_on_loft(secs, s[0], a, 0.0, fold)) for a in angles] for s in secs]
    n = len(angles)
    for k in range(len(rings) - 1):
        for j in range(n):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % n], rings[k + 1][(j + 1) % n], rings[k + 1][j]))
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])
    return _raw(bm, name)


def _patch(secs, xs, angs, lift: float, fold=None, keep=None, x_of=None, name: str = "patch"):
    """A cloth layer on a loft (belt, lapel, waistcoat, shawl): grid over the x values and ring
    angles (a list, or angs(x) -> list of the same length), `lift` above the surface.
    keep(x, a) -> False leaves a cell out; x_of(x, a) -> x shapes a hem. Faces point outwards."""
    bm = bmesh.new()
    rows = [angs(x) if callable(angs) else angs for x in xs]
    grid = [[bm.verts.new(_on_loft(secs, x_of(x, a) if x_of else x, a, lift, fold)) for a in row]
            for x, row in zip(xs, rows)]
    for i in range(len(xs) - 1):
        for j in range(len(rows[i]) - 1):
            if keep is None or keep((xs[i] + xs[i + 1]) / 2, (rows[i][j] + rows[i][j + 1]) / 2):
                bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    return _raw(bm, name)


def _sheet(xs, ys, height, name: str = "sheet"):
    """Cloth sheet over a grid (x rows, y columns) at height(x, y) (aprons over the legs)."""
    bm = bmesh.new()
    grid = [[bm.verts.new((x, y, height(x, y))) for y in ys] for x in xs]
    step = 1 if xs[-1] > xs[0] else -1
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            q = (grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])
            bm.faces.new(q if step > 0 else tuple(reversed(q)))
    return _raw(bm, name)


# --- head ----------------------------------------------------------------------

def _face_pt(u: float, v: float, lift: float = 0.0) -> Vector:
    """Point on the head: u = degrees from the nose towards the crown (+X), v = towards +Y."""
    ur, vr = math.radians(u), math.radians(v)
    d = Vector((math.sin(ur) * math.cos(vr), math.sin(vr), math.cos(ur) * math.cos(vr)))
    return HEAD_C + Vector((d.x * HEAD_S.x, d.y * HEAD_S.y, d.z * HEAD_S.z)) * (HEAD_R * _head_shape(d) + lift)


def _face_n(u: float, v: float) -> Vector:
    p = _face_pt(u, v) - HEAD_C
    return Vector((p.x / HEAD_S.x ** 2, p.y / HEAD_S.y ** 2, p.z / HEAD_S.z ** 2)).normalized()


def _head_dir(p) -> Vector:
    d = Vector(p) - HEAD_C
    return Vector((d.x / HEAD_S.x, d.y / HEAD_S.y, d.z / HEAD_S.z)).normalized()


def _uv(d) -> tuple:
    """Unit direction (head space) -> (u, v) in degrees."""
    return math.degrees(math.atan2(d.x, d.z)), math.degrees(math.asin(max(-1.0, min(1.0, d.y))))


def _head_shape(d: Vector) -> float:
    """Radius factor of the sculpted head: soft chin, narrower jaw, brow, flat resting back."""
    u, v = _uv(d)
    r = 1.0 + 0.08 * math.exp(-((u + 50.0) / 13.0) ** 2) * max(0.0, 1.0 - abs(d.y) * 2.2)
    r -= 0.06 * max(0.0, -d.x) * abs(d.y)
    r += 0.03 * math.exp(-((u - 24.0) / 9.0) ** 2) * max(0.0, 1.0 - abs(d.y) * 1.5)
    r -= 0.07 * max(0.0, -d.z - 0.55)
    return r


def _skin_at(co):
    """Base skin colour: pale grey-green with ashen highlights and lilac-grey eye hollows."""
    c = L.mix(SKIN, SKIN_WARM, max(0.0, noise.noise(co * 9.0 + Vector((3, 1, 7)))) * 0.9)
    for sy in (-1, 1):
        k = math.exp(-((co - _face_pt(15, 25 * sy, -0.01)).length / 0.034) ** 2)
        c = L.mix(c, SKIN_ASH, 0.65 * k)
        k = math.exp(-((co - _face_pt(-10, 38 * sy)).length / 0.04) ** 2)
        c = L.mix(c, SKIN_WARM, 0.6 * k)
    return c


def _skin_fn(co, poly):
    return _skin_at(co)


def _zone_head(parts, zones, segs: int = 14, rings: int = 9, seed: int = 1) -> None:
    """Sculpted head sphere (pole = nose, crown = +X). zones = [(keep(u, v), colour, lift, locks,
    streak)]: hair, beard or a headscarf painted onto the faces where keep() and pushed out
    (vertices whose faces all belong to a zone), with painted strands; later zones win."""
    o = L.prim("sphere", radius=1.0, segments=segs, ring_count=rings)
    me = o.data
    for v in me.vertices:
        d = v.co.normalized()
        v.co = HEAD_C + Vector((d.x * HEAD_S.x, d.y * HEAD_S.y, d.z * HEAD_S.z)) * HEAD_R * _head_shape(d)
    fz = []
    for poly in me.polygons:
        u, v = _uv(_head_dir(poly.center))
        z = -1
        for i, zone in enumerate(zones):
            if zone[0](u, v):
                z = i
        fz.append(z)
    around = {}
    for poly in me.polygons:
        for vi in poly.vertices:
            around.setdefault(vi, []).append(fz[poly.index])
    off = Vector((seed * 1.3, seed * 2.1, 0.0))
    for v in me.vertices:
        zs = around[v.index]
        if min(zs) >= 0:
            lift = min(zones[z][2] for z in zs)
            locks = zones[zs[0]][3]
            n = (v.co - HEAD_C).normalized()
            v.co += n * (lift + locks * noise.noise(n * 4.0 + off))

    def zone_fn(co, poly):
        z = fz[poly.index]
        if z < 0:
            return _skin_at(co)
        d = co - HEAD_C
        s = math.sin(math.atan2(d.y, d.z) * 9.0 + d.x * 14.0)
        return L.scale_c(zones[z][1], 1.0 - zones[z][4] * max(0.0, s) ** 3)
    parts.append(_cloth(o, zone_fn, var=0.08, ao=0.25, top=0.1, freq=7.0, seed=seed))


def _face(parts, brow_color, brow_r: float = 0.0075, ears: bool = True) -> None:
    """A gentle face: closed lids with lash lines, soft nose, closed lips, ears, relaxed brows."""
    for sy in (-1, 1):
        # closed lid: a soft bulge in the socket, a calm curved lash line below it
        parts.append(_blob("sphere", (0.017, 0.031, 0.012), _face_pt(15, 25 * sy, -0.003), _face_n(15, 25 * sy),
                           (1, 0, 0), color=L.mix(SKIN, SKIN_ASH, 0.12), segments=6, ring_count=4, ao=0.1, top=0.05))
        lash = [_face_pt(u, v * sy, 0.006) for u, v in ((12, 13), (8.5, 25), (12, 37))]
        parts.append(_cloth(_tube(lash, (0.0035, 0.0045, 0.0035), 3, hint=(0, 0, 1), caps=(False, False)),
                            _flat(LASH), var=0.05, ao=0.0, top=0.0))
        pts = [_face_pt(u, v * sy, 0.002) for u, v in ((29, 11), (32, 24), (29, 38))]
        parts.append(_cloth(_tube(pts, (brow_r * 0.8, brow_r, brow_r * 0.7), 4, hint=(1, 0, 0), caps=(False, False)),
                            _flat(brow_color), var=0.15, ao=0.1))
        if ears:
            parts.append(_blob("ico", (0.038, 0.026, 0.012), _face_pt(2, 82 * sy, -0.006), _face_n(2, 88 * sy),
                               (1, 0, 0), color=L.mix(SKIN, SKIN_ASH, 0.2), subdivisions=1, ao=0.2))
    # nose: soft and a little big, like the living characters'
    parts.append(_blob("sphere", (0.038, 0.022, 0.021), _face_pt(-4, 0, 0.004), _face_n(-4, 0), (1, 0, 0),
                       fn=lambda lc, poly: L.mix(SKIN, SKIN_ASH, 0.3) if lc.x < -0.03 else L.mix(SKIN, SKIN_WARM, 0.6),
                       segments=8, ring_count=4, ao=0.08))
    # lips: closed, muted mauve with a darker seam
    parts.append(_blob("sphere", (0.01, 0.028, 0.008), _face_pt(-27, 0, -0.002), _face_n(-27, 0), (1, 0, 0),
                       fn=lambda lc, poly: L.scale_c(LIP, 0.75) if abs(lc.x) < 0.004 else L.mix(LIP, SKIN, 0.3),
                       segments=6,
                       ring_count=3, ao=0.08))


# --- body ----------------------------------------------------------------------

def _torso(parts, zone, fold=None, seed: int = 3, var: float = 0.12) -> None:
    """zone(x, ring angle, co) -> colour, decided per face (crisp seams between clothes)."""
    body = _loft(TORSO, ANG, fold=fold, caps=(False, False), name="torso")
    parts.append(_cloth(body, lambda co, poly: zone(poly.center.x, _loft_angle(TORSO, poly.center), co), var=var,
                        seed=seed))


def _torso_fold(x: float, a: float) -> float:
    """Soft cloth folds: creases from the armpits, a pinch at the waist."""
    s = math.sin(a)
    f = 1.0 + 0.016 * math.sin(a * 5.0 + x * 21.0) * max(0.0, s)
    f -= 0.03 * math.exp(-((x - 0.04) / 0.04) ** 2)
    return f


def _crease(co, x0: float, x1: float, freq: float, depth: float) -> float:
    """Brightness of painted crease bands between x0 and x1."""
    if co.x < x0 or co.x > x1:
        return 1.0
    return 1.0 - depth * max(0.0, math.sin(co.x * freq + co.y * 9.0)) ** 6


def _arm_pts(sy: int):
    sh = Vector((0.475, sy * 0.19, 0.125))
    el = Vector((0.215, sy * 0.238, 0.088))
    mid_f = Vector((0.232, sy * 0.172, 0.182))
    return sh, sh.lerp(el, 0.5) + Vector((0, sy * 0.012, 0)), el, mid_f, WRIST[sy]


def _arms(parts, sleeve, cuff=None, rolled: bool = False, patch=None, seed: int = 10) -> None:
    """Upper arms along the sides, forearms folded onto the belly. rolled = bare forearms."""
    for sy in (-1, 1):
        sh, mid, el, mid_f, w = _arm_pts(sy)
        if rolled:  # sleeve rolled up above the elbow, skin below
            parts.append(_cloth(_tube((sh, mid, el), (0.062, 0.058, 0.064), 6, caps=(False, True)),
                                lambda co, poly, el=el: L.scale_c(sleeve, 0.85 if (co - el).length < 0.04 else 1.0),
                                seed=seed))
            parts.append(_cloth(_tube((el, mid_f, w), (0.045, 0.042, 0.037), 6, caps=(False, False)), _skin_fn,
                                var=0.05, ao=0.22, seed=seed + 1))
        else:
            def sleeve_fn(co, poly, w=w, el=el):
                if cuff is not None and (co - w).length < 0.032:
                    return cuff
                return L.scale_c(sleeve, _crease(co, el.x - 0.05, el.x + 0.05, 90.0, 0.2))
            parts.append(_cloth(_tube((sh, mid, el, mid_f, w), (0.062, 0.058, 0.054, 0.05, 0.047), 6,
                                      caps=(False, True)), sleeve_fn, seed=seed))
        if patch is not None and sy > 0:  # a darned patch on the elbow
            parts.append(_blob("ico", (0.04, 0.034, 0.012), el + Vector((0.0, 0.035, 0.024)), (0, 0.8, 0.6),
                               (1, 0, 0), color=patch, subdivisions=1, jit=0.002, seed=seed + 3))


def _hands(parts, lift: float = 0.0) -> None:
    """Big pale hands folded on the belly: the right over the left, fingers across."""
    up = Vector((0, 0, lift))
    m = Matrix.Translation(WRIST[1] + Vector((0.012, -0.052, 0.022)) + up) @ _frame((0.05, 0.12, 1.0),
                                                                                    (0.22, -1.0, 0.0))
    r = m.to_3x3()
    parts.append(_blob("sphere", (0.046, 0.037, 0.018), m @ Vector(), r @ Vector((0, 0, 1)), r @ Vector((1, 0, 0)),
                       color=SKIN, segments=6, ring_count=4, ao=0.18))
    for i, off in enumerate((-0.024, -0.008, 0.008, 0.023)):
        ln = 0.052 - abs(off) * 0.5
        pts = (m @ Vector((0.03, off, 0.004)), m @ Vector((0.03 + ln * 0.6, off * 1.05, 0.0)),
               m @ Vector((0.03 + ln, off * 1.1, -0.018)))
        parts.append(_cloth(_tube(pts, (0.0105, 0.0098, 0.0085), 4, hint=r @ Vector((0, 0, 1)), caps=(False, True)),
                            lambda co, poly: _skin_at(co), var=0.05, ao=0.18, seed=40 + i))
    thumb = (m @ Vector((-0.01, -0.036, 0.0)), m @ Vector((0.02, -0.05, 0.006)), m @ Vector((0.045, -0.052, 0.006)))
    parts.append(_cloth(_tube(thumb, (0.013, 0.012, 0.0105), 5, hint=r @ Vector((0, 0, 1)), caps=(False, True)),
                        _skin_fn, var=0.05, ao=0.18, seed=44))
    # lower hand (from the -Y wrist), its fingers peeking out under the upper wrist
    m2 = Matrix.Translation(WRIST[-1] + Vector((0.008, 0.055, 0.004)) + up) @ _frame((0.0, -0.1, 1.0),
                                                                                     (-0.1, 1.0, 0.0))
    r2 = m2.to_3x3()
    parts.append(_blob("sphere", (0.046, 0.036, 0.017), m2 @ Vector(), r2 @ Vector((0, 0, 1)),
                       r2 @ Vector((1, 0, 0)), color=SKIN, segments=6, ring_count=4, ao=0.18))
    parts.append(_blob("sphere", (0.03, 0.036, 0.012), m2 @ Vector((0.062, 0.0, -0.004)), r2 @ Vector((0, 0, 1)),
                       r2 @ Vector((1, 0, 0)),
                       fn=lambda lc, poly: L.scale_c(SKIN, 0.88 if abs(abs(lc.y) - 0.012) < 0.005 else 1.0),
                       segments=6, ring_count=3, ao=0.2))


def _leg_pts(sy: int):
    ys = (0.088, 0.094, 0.1, 0.108)
    zs = (0.1, 0.096, 0.094, 0.078)
    return [Vector((x, sy * y, z)) for x, y, z in zip(LEG_X, ys, zs)]


LEG_R = (0.086, 0.076, 0.068, 0.056)


def _legs(parts, trouser, patch=None, seed: int = 20) -> None:
    for sy in (-1, 1):
        def fn(co, poly):
            return L.scale_c(trouser, _crease(co, -0.48, -0.36, 80.0, 0.16) * _crease(co, -0.7, -0.6, 95.0, 0.18))
        parts.append(_cloth(_tube(_leg_pts(sy), LEG_R, 6, caps=(False, False)), fn, seed=seed + sy))
        if patch is not None and sy < 0:  # a sewn-on knee patch
            parts.append(_blob("ico", (0.05, 0.043, 0.012), _leg_pts(sy)[2] + Vector((0.0, 0.0, 0.064)),
                               (0, -0.15, 1), (1, 0, 0), color=patch, subdivisions=1, jit=0.002, seed=seed + 5))


def _boots(parts, color, small: bool = False, seed: int = 30) -> None:
    """Big boots, toes up and splayed a little; worn lighter at the toe cap. small = shoes."""
    for sy in (-1, 1):
        y = sy * (0.112 if not small else 0.1)
        if not small:
            parts.append(_cloth(_tube(((-0.66, y, 0.078), (-0.755, y, 0.084)), (0.06, 0.063), 7, caps=(False, False)),
                                _flat(color), var=0.12, seed=seed))
        c = Vector((-0.785 if not small else -0.765, y + sy * 0.012, 0.125 if not small else 0.1))
        half = (0.115, 0.06, 0.058) if not small else (0.085, 0.047, 0.045)
        toe_up = Vector((0.0, sy * 0.2, 1.0))

        def boot(lc, poly, h=half[0]):
            return L.scale_c(color, 1.0 + 0.5 * max(0.0, lc.x / h - 0.35))
        parts.append(_blob("sphere", half, c, (-1, 0, 0), toe_up, fn=boot, segments=7, ring_count=4, jit=0.002,
                           seed=seed + 1, ao=0.25))
        parts.append(_blob("sphere", (half[0] * 1.03, half[1] * 1.05, 0.012), c + Vector((-half[2] - 0.004, 0, 0)),
                           (-1, 0, 0), toe_up, color=L.scale_c(color, 0.6), segments=6, ring_count=2, ao=0.2))


def _neck(parts) -> None:
    parts.append(_cloth(_tube(((0.53, 0, 0.112), (0.6, 0, 0.12), (0.64, 0, 0.122)), (0.056, 0.054, 0.05), 6,
                              caps=(False, False)), _skin_fn, var=0.05, ao=0.25, seed=5))


def _buttons(parts, xs, color, lift: float = 0.004, r: float = 0.011) -> None:
    for x in xs:
        parts.append(_blob("cyl", (r, r, 0.004), _on_loft(TORSO, x, 90.0, lift, _torso_fold), (0, 0, 1), (1, 0, 0),
                           color=color, vertices=4 if x < 0.1 else 5, ao=0.0, top=0.3))


def _sprig(parts, base: Vector, direction: Vector, seed: int = 0, n: int = 3) -> None:
    """A small sprig of heather: a thin stem with tiny muted mauve blossoms and two leaves."""
    d = direction.normalized()
    side = d.cross(Vector((0, 0, 1))).normalized()
    stem = (base, base + d * 0.06 + side * 0.006, base + d * 0.12 - side * 0.004)
    parts.append(_cloth(_tube(stem, (0.004, 0.0035, 0.003), 4, caps=(False, False)), _flat(L.hexc("#5A5A40")),
                        ao=0.0, seed=seed))
    for i in range(n):
        t = 0.4 + 0.6 * i / max(1, n - 1)
        p = base + d * (0.12 * t) + side * (0.011 * (1 if i % 2 else -1)) + Vector((0, 0, 0.004))
        col = L.mix(L.hexc("#77627B"), L.hexc("#938093"), (i % 3) / 2.0)
        parts.append(_blob("ico", (0.012, 0.009, 0.008), p, (0, 0, 1), d, color=col, subdivisions=1, jit=0.002,
                           seed=seed + i, ao=0.0, top=0.2))
    for k in (-1, 1):
        parts.append(_blob("sphere", (0.02, 0.006, 0.003), base + d * 0.03 + side * k * 0.012, (0, 0, 1),
                           d + side * k * 0.6, color=L.hexc("#566444"), segments=4, ring_count=3, ao=0.0))


def _corpse_done(parts, name: str) -> None:
    obj = L.join(parts, name)
    _center_xy(obj)
    L.finish(obj, name, "props", CORPSE_SMOOTH)


# --- the four looks --------------------------------------------------------------

def corpse():
    """Variant 0 - farmhand: open brown work jacket with lapels and a darned elbow over an
    oatmeal shirt (buttons), leather belt with an iron buckle, dark trousers with a knee patch,
    muted rust neckerchief, tousled brown hair, big worn boots."""
    L.reset(200)
    jacket, jacket_d = L.hexc("#5C4B3B"), L.hexc("#47392D")
    shirt, trouser = L.hexc("#857F6B"), L.hexc("#45423A")
    hair = L.hexc("#54412F")
    parts = []
    _zone_head(parts, [(lambda u, v: u > 40 or (abs(v) > 60 and u > 14) or abs(u) > 125, hair, 0.013, 0.012, 0.16)])
    _face(parts, L.scale_c(hair, 0.9))
    _neck(parts)

    def half_open(x):
        return 14.0 if x < 0.36 else 14.0 + (x - 0.36) * 120.0

    def zone(x, a, co):
        if x < 0.02 and abs(a - 90.0) < 30.0:
            return trouser
        if abs(a - 90.0) < half_open(x) and x >= 0.02:
            return shirt if x > 0.075 else LEATHER
        return L.scale_c(jacket, _crease(co, 0.1, 0.46, 60.0, 0.12))
    _torso(parts, zone, _torso_fold)
    for sy in (-1, 1):  # lapels along the opening, widening to the shoulders
        def lapel(x, sy=sy):
            a = 90.0 - sy * half_open(x)
            return (a - 17.0, a + 1.0) if sy > 0 else (a - 1.0, a + 17.0)
        parts.append(_cloth(_patch(TORSO, (0.3, 0.38, 0.46, 0.54), lapel, 0.01, _torso_fold, name="lapel"),
                            _flat(jacket_d), seed=6))
    parts.append(_cloth(_patch(TORSO, (0.02, 0.075), (70, 90, 110), 0.006, _torso_fold, name="belt"),
                        _flat(LEATHER), seed=7))
    parts.append(_blob("cube", (0.02, 0.028, 0.006), _on_loft(TORSO, 0.047, 90.0, 0.012, _torso_fold), color=IRON,
                       top=0.3, ao=0.0))
    _buttons(parts, (0.13, 0.37, 0.45), L.hexc("#5A5346"))
    kerchief = L.hexc("#5E4334")
    parts.append(_cloth(_patch(TORSO, (0.52, 0.55, 0.578), (15, 50, 90, 130, 165), 0.012, name="kerchief"),
                        _flat(kerchief), seed=8))
    parts.append(_blob("ico", (0.03, 0.026, 0.012), _on_loft(TORSO, 0.515, 90.0, 0.014), (0, 0, 1), (1, 0, 0),
                       color=L.scale_c(kerchief, 0.9), subdivisions=1, jit=0.002, seed=9))
    _arms(parts, jacket, cuff=shirt, patch=L.hexc("#6C604C"))
    _hands(parts)
    _legs(parts, trouser, patch=L.hexc("#666050"))
    _boots(parts, BOOT)
    _corpse_done(parts, "ph_prop_corpse")


def corpse_02():
    """Variant 1 - old woman: long slate-plum dress, knitted shawl over the shoulders with a
    fringed hem, pale lace collar, faded headscarf knotted under the chin with grey hair at the
    brow, a sprig of heather in the folded hands, small black shoes."""
    L.reset(202)
    dress, shawl = L.hexc("#4A4452"), L.hexc("#5F4E40")
    scarf, grey = L.hexc("#7E6A4A"), L.hexc("#9A958B")
    parts = []
    _zone_head(parts, [(lambda u, v: u > 32 or abs(v) > 56 or u < -95, scarf, 0.026, 0.008, 0.1),
                       (lambda u, v: 32 < u < 46 and abs(v) < 44, grey, 0.01, 0.004, 0.2)])
    _face(parts, L.hexc("#857F75"), brow_r=0.006, ears=False)
    for sy in (-1, 1):  # scarf ends tied under the chin, lying on the collar
        parts.append(_blob("sphere", (0.04, 0.02, 0.007), (0.548, sy * 0.034, 0.2), (0, sy * 0.3, 1),
                           (-1, sy * 0.45, 0), color=L.scale_c(scarf, 0.92), segments=6, ring_count=3, jit=0.002,
                           seed=5 + sy))
    parts.append(_blob("ico", (0.026, 0.03, 0.02), (0.592, 0.0, 0.198), (0, 0, 1), (1, 0, 0), color=scarf,
                       subdivisions=1, jit=0.003, seed=7))
    _neck(parts)
    _torso(parts, lambda x, a, co: L.scale_c(dress, _crease(co, 0.1, 0.45, 55.0, 0.1)), _torso_fold)
    parts.append(_cloth(_patch(TORSO, (0.52, 0.548, 0.572), (20, 55, 90, 125, 160), 0.01, name="lace"),
                        _flat(L.hexc("#BDB5A0")), seed=8))

    def shawl_keep(x, a):
        d = abs(a - 90.0)
        return x > 0.31 - d * 0.0012 and not (x > 0.42 and d < (x - 0.42) * 300.0)
    xs = (0.2, 0.26, 0.33, 0.4, 0.46, 0.51, 0.545)
    angs = (-5, 20, 45, 68, 90, 112, 135, 160, 185)
    sh = _patch(TORSO, xs, angs, 0.014, _torso_fold, keep=shawl_keep, name="shawl")
    for v in sh.data.vertices:  # zig-zag fringe along the lower edge
        if v.co.x < 0.27:
            v.co.x -= 0.012 * (1.0 + math.sin(v.co.y * 90.0))
    parts.append(_cloth(sh, lambda co, poly: L.scale_c(shawl, 0.8 if co.x < 0.25 else
                                                        1.0 - 0.1 * max(0.0, math.sin(co.x * 160.0)) ** 4), seed=9))
    _arms(parts, dress, cuff=L.scale_c(dress, 0.8))
    _hands(parts, lift=0.012)
    _sprig(parts, Vector((0.245, 0.03, 0.285)), Vector((1.0, -0.35, 0.05)), seed=11)
    # long skirt over both legs: drapes between the knees, folds along the length, wavy hem
    skirt_secs = [(-0.1, 0.0, 0.1, 0.182, 0.075, 0.1), (-0.3, 0.0, 0.097, 0.2, 0.07, 0.097),
                  (-0.5, 0.0, 0.092, 0.198, 0.062, 0.092), (-0.7, 0.0, 0.086, 0.195, 0.058, 0.086),
                  (-0.735, 0.0, 0.085, 0.2, 0.05, 0.085)]

    def skirt_fold(x, a):
        s = math.sin(a)
        dip = 0.22 * math.exp(-(math.cos(a) / 0.28) ** 2) * max(0.0, -x - 0.2) / 0.55
        return 1.0 + 0.035 * math.sin(a * 11.0 + x * 5.0) * s - dip * s
    skirt = _loft(skirt_secs, (0, 16, 34, 52, 70, 90, 110, 128, 146, 164, 180, 270), fold=skirt_fold,
                  caps=(False, True), name="skirt")
    for v in skirt.data.vertices:
        if v.co.x < -0.72:
            v.co.x += 0.012 * math.sin(v.co.y * 60.0)
    parts.append(_cloth(skirt, lambda co, poly: L.scale_c(dress, 0.84 if poly.center.x < -0.72 else 1.0), seed=12))
    for sy in (-1, 1):  # dark stockings between hem and shoes
        parts.append(_cloth(_tube(((-0.7, sy * 0.1, 0.075), (-0.76, sy * 0.1, 0.075)), (0.04, 0.04), 6,
                                  caps=(False, False)), _flat(L.hexc("#2F2B2E")), seed=13))
    _boots(parts, L.hexc("#2A2422"), small=True)
    _corpse_done(parts, "ph_prop_corpse_02")


def corpse_03():
    """Variant 2 - old man: bald crown with a white fringe, full white beard resting on the
    chest, moustache, bushy brows, cream shirt, moss-green waistcoat with dull brass buttons
    and a watch chain, dark trousers, old boots."""
    L.reset(203)
    shirt, vest = L.hexc("#9C9582"), L.hexc("#45503E")
    trouser, beard = L.hexc("#3B3935"), L.hexc("#A09B8E")
    parts = []
    _zone_head(parts, [(lambda u, v: (abs(v) > 55 and 16 < u < 150) or abs(u) > 130, beard, 0.012, 0.012, 0.12),
                       (lambda u, v: -125 < u < -16 and not (u > -40 and abs(v) < 16) and abs(v) < 82, beard, 0.02,
                        0.01, 0.12)])
    _face(parts, beard, brow_r=0.011)
    # the beard flows from the chin over the throat onto the chest in wavy locks
    secs = [(0.47, 0.0, 0.186, 0.036, 0.012, 0.008), (0.5, 0.0, 0.192, 0.05, 0.017, 0.012),
            (0.535, 0.0, 0.198, 0.058, 0.02, 0.016), (0.572, 0.0, 0.205, 0.062, 0.022, 0.02),
            (0.61, 0.0, 0.203, 0.062, 0.022, 0.02)]
    fl = _loft(secs, (0, 30, 60, 90, 120, 150, 180), fold=lambda x, a: 1.0 + 0.28 * math.sin(a * 6.0 + x * 30.0) *
               max(0.0, math.sin(a)), caps=(True, False), name="beard")
    for v in fl.data.vertices:  # three soft wavy points at the tip
        if v.co.x < 0.48:
            v.co.x -= 0.018 * max(0.0, math.cos(v.co.y / 0.042 * math.pi * 1.5)) ** 2
    L.jitter(fl, 0.004, 25.0, 7)
    def locks(co, poly):
        return L.scale_c(beard, 1.0 - 0.24 * max(0.0, math.sin(co.y * 170.0 + co.x * 40.0)) ** 2)
    parts.append(_cloth(fl, locks, var=0.12, seed=8))
    for sy in (-1, 1):
        pts = (_face_pt(-15, 3 * sy, 0.008), _face_pt(-18, 18 * sy, 0.01), _face_pt(-29, 30 * sy, 0.008))
        parts.append(_cloth(_tube(pts, (0.014, 0.012, 0.007), 4, caps=(False, True)), _flat(beard), seed=9))
    _neck(parts)

    def zone(x, a, co):
        if x < 0.01 and abs(a - 90.0) < 40.0:
            return trouser
        return L.scale_c(shirt, _crease(co, 0.1, 0.46, 60.0, 0.1))
    _torso(parts, zone, _torso_fold)

    def neckline(x):  # half opening of the V (degrees) - closed below the chest
        return 2.0 + max(0.0, x - 0.24) * 170.0
    xs = (-0.02, 0.08, 0.2, 0.31, 0.42, 0.51)
    for sy in (-1, 1):  # two front panels meeting at the buttons, pointed hem at the front
        def angs(x, sy=sy):
            inner = 90.0 - sy * neckline(x)
            outer = -8.0 if sy > 0 else 188.0
            lo, hi = (outer, inner) if sy > 0 else (inner, outer)
            return [lo + (hi - lo) * k / 5.0 for k in range(6)]

        def hem(x, a):
            return x - 0.045 * max(0.0, 1.0 - abs(a - 90.0) / 60.0) if x < 0.0 else x
        parts.append(_cloth(_patch(TORSO, xs, angs, 0.01, _torso_fold, x_of=hem, name="waistcoat"),
                            lambda co, poly: L.scale_c(vest, 1.0 - 0.1 * max(0.0, math.sin(co.x * 55.0)) ** 6),
                            seed=10))
    _buttons(parts, (0.0, 0.07, 0.14), BRASS, lift=0.014, r=0.01)
    chain = [_on_loft(TORSO, 0.07 - 0.03 * math.sin(t * math.pi), 90.0 - 40.0 * t, 0.016, _torso_fold)
             for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
    parts.append(_cloth(_tube(chain, [0.0045] * 5, 4, caps=(False, False)), _flat(BRASS), top=0.3, seed=11))
    _arms(parts, shirt, cuff=L.scale_c(shirt, 1.08))
    _hands(parts)
    _legs(parts, trouser)
    _boots(parts, L.hexc("#352B24"))
    _corpse_done(parts, "ph_prop_corpse_03")


def corpse_04():
    """Variant 3 - young miller: blue-grey linen shirt with the sleeves rolled up, big
    flour-dusted apron from chest to knees, his flat cap resting under the folded hands,
    ginger-brown hair, light boots."""
    L.reset(204)
    shirt, apron = L.hexc("#687078"), L.hexc("#7F7661")
    trouser, cap = L.hexc("#54483B"), L.hexc("#4D4843")
    flour = L.hexc("#A9A393")
    parts = []
    _zone_head(parts, [(lambda u, v: u > 42 - 8 * math.sin(math.radians(v) * 3.0) or (abs(v) > 64 and u > 12)
                        or abs(u) > 125, L.hexc("#77553A"), 0.015, 0.016, 0.18)])
    _face(parts, L.hexc("#6A4C33"))
    _neck(parts)

    def zone(x, a, co):
        if x < 0.01 and abs(a - 90.0) < 40.0:
            return trouser
        return L.scale_c(shirt, _crease(co, 0.1, 0.46, 60.0, 0.1))
    _torso(parts, zone, _torso_fold)
    parts.append(_cloth(_patch(TORSO, (0.53, 0.56, 0.58), (20, 55, 90, 125, 160), 0.01, name="collar"),
                        _flat(L.scale_c(shirt, 1.1)), seed=13))
    _buttons(parts, (0.42, 0.49), L.hexc("#5E5E58"))

    def dusted(co, poly):
        return L.mix(apron, flour, 0.55 * max(0.0, noise.noise(co * 14.0)))
    parts.append(_cloth(_patch(TORSO, (0.0, 0.13, 0.26, 0.37), (42, 62, 78, 90, 102, 118, 138), 0.012, _torso_fold,
                               name="apron_bib"), dusted, var=0.1, seed=14))
    for sy in (-1, 1):  # neck straps
        pts = (_on_loft(TORSO, 0.36, 90 - sy * 44, 0.012), _on_loft(TORSO, 0.47, 90 - sy * 55, 0.012),
               _on_loft(TORSO, 0.555, 90 - sy * 70, 0.014))
        parts.append(_cloth(_tube(pts, (0.007, 0.007, 0.007), 4, caps=(False, False)), _flat(apron), seed=15))

    def over_legs(x, y):  # cloth over both thighs, sagging between them, falling soft at the sides
        t = min(1.0, max(0.0, -x / 0.42))
        r = LEG_R[0] + (LEG_R[2] - LEG_R[0]) * t
        top = 0.098 + r
        d = abs(y)
        if d < 0.095:
            z = top - 5.5 * (0.095 - d) ** 2
        else:
            z = top - 4.0 * (d - 0.095) ** 2 - 2.5 * max(0.0, d - 0.14) ** 1.4
        return z + 0.012 + 0.006 * math.sin(y * 60.0 + x * 7.0)
    xs = (0.03, -0.1, -0.22, -0.34, -0.44)
    ys = (-0.18, -0.14, -0.095, -0.05, 0.0, 0.05, 0.095, 0.14, 0.18)
    sk = _sheet(xs, ys, over_legs, name="apron")
    for v in sk.data.vertices:  # frayed, wavy hem
        if v.co.x < -0.43:
            v.co.x += 0.012 * math.sin(v.co.y * 80.0)
    parts.append(_cloth(sk, lambda co, poly: dusted(co, poly) if poly.center.x > -0.41 else L.scale_c(apron, 0.86),
                        var=0.1, seed=16))
    # flat cap on the chest, under the folded hands
    cp = Vector((0.262, 0.0, 0.222))
    top = L.prim("cyl", radius=0.078, depth=0.026, vertices=9)
    L.jitter(top, 0.005, 30.0, 17)
    top.data.transform(Matrix.Translation(cp) @ Matrix.Rotation(math.radians(-6), 4, "Y"))
    parts.append(_cloth(top, lambda co, poly: L.scale_c(cap, 1.0 - 0.1 * max(0.0, math.sin(co.x * 150.0)) ** 4),
                        var=0.15, seed=17))
    parts.append(_blob("sphere", (0.05, 0.078, 0.009), cp + Vector((0.085, 0.0, -0.008)), (0.1, 0, 1), (1, 0, 0),
                       color=L.scale_c(cap, 0.85), segments=7, ring_count=3))
    _arms(parts, shirt, rolled=True)
    _hands(parts, lift=0.012)
    _legs(parts, trouser)
    _boots(parts, L.hexc("#4A3C31"))
    for o in parts:  # a dusting of flour on everything facing up
        _tint_up(o, flour, amount=0.3, min_up=0.6, freq=9.0, seed=18)
    _corpse_done(parts, "ph_prop_corpse_04")


# --- shrouded ------------------------------------------------------------------

# Wrapped body outline (feet at -X, head at +X): x, half width, height. Lies flat on its back.
SHROUD = [(-0.866, 0.05, 0.11), (-0.84, 0.115, 0.19), (-0.79, 0.132, 0.215), (-0.735, 0.125, 0.165),
          (-0.67, 0.108, 0.12), (-0.58, 0.12, 0.128), (-0.47, 0.134, 0.14), (-0.37, 0.14, 0.145),
          (-0.25, 0.152, 0.152), (-0.13, 0.172, 0.162), (-0.02, 0.19, 0.175), (0.08, 0.19, 0.168),
          (0.18, 0.205, 0.198), (0.27, 0.218, 0.214), (0.36, 0.235, 0.212), (0.44, 0.24, 0.2),
          (0.5, 0.222, 0.182), (0.545, 0.145, 0.142), (0.585, 0.102, 0.122), (0.63, 0.11, 0.17),
          (0.7, 0.12, 0.222), (0.78, 0.115, 0.218), (0.84, 0.088, 0.172), (0.874, 0.042, 0.1)]
SHROUD_SECS = [(x, 0.0, h * 0.4, hw, h * 0.6, h * 0.4) for x, hw, h in SHROUD]
SHROUD_ANG = (0, 14, 28, 42, 55, 67, 79, 90, 101, 113, 125, 138, 152, 166, 180, 225, 270, 315)
SHROUD_LINEN = L.hexc("#C2B89F")   # a touch darker than the folded linen: reads as cloth, not glare
SHROUD_DIRTY = L.hexc("#A3987F")
ROPES = (-0.665, 0.075, 0.585)     # ankles, waist, neck
WRAP_K = 34.0                       # the linen strip winds round every ~18 cm


def _shroud_fold(x: float, a: float) -> float:
    """Wrapped linen: toes, folded hands and the face show through, the ropes cinch the
    cloth, the strip edges overlap (soft saw-tooth), small wrinkles everywhere."""
    c, s = math.cos(a), math.sin(a)
    up = max(0.0, s)
    f = 1.0
    if x < -0.72:  # two toe bumps
        k = min(1.0, (-0.72 - x) / 0.05) * (1.0 - max(0.0, (-0.83 - x) / 0.04))
        f += 0.42 * k * up * (math.exp(-((c - 0.42) / 0.26) ** 2) + math.exp(-((c + 0.42) / 0.26) ** 2) - 0.55)
    f += 0.28 * math.exp(-((x - 0.26) / 0.06) ** 2) * math.exp(-(c / 0.4) ** 2) * up          # folded hands
    f += 0.2 * math.exp(-((x - 0.7) / 0.03) ** 2) * math.exp(-(c / 0.18) ** 2) * up          # nose
    f += 0.1 * max(0.0, -s) * abs(c) * (1.0 if -0.72 < x < 0.54 else 0.3)                      # cloth pooling
    f += 0.05 * math.exp(-((x - 0.62) / 0.02) ** 2) * math.exp(-(c / 0.3) ** 2) * up          # chin
    for xr in ROPES:
        f -= 0.07 * math.exp(-((x - xr) / 0.018) ** 2)
    ph = (x * WRAP_K + a * 1.2) / math.tau
    f += 0.014 * math.sin(ph * math.tau) * up + 0.012 * math.sin(x * 61.0 + a * 3.0) * up
    return f


def _shroud_paint(co, poly):
    """Pale linen, dustier towards the feet and the ground, soft shade bands along the winding."""
    yc, zc, hw, top, bot = _sec(SHROUD_SECS, co.x)
    a = math.atan2((co.z - zc) / (top if co.z >= zc else bot), co.y / max(hw, 1e-3))
    ph = (co.x * WRAP_K + a * 1.2) / math.tau
    c = L.mix(SHROUD_LINEN, SHROUD_DIRTY, max(0.0, min(1.0, (-0.45 - co.x) / 0.4)) * 0.7)
    c = L.mix(c, SHROUD_DIRTY, max(0.0, noise.noise(co * 6.0 + Vector((4, 2, 9)))) * 0.8)
    return L.scale_c(c, 1.0 - 0.1 * max(0.0, math.sin(ph * math.tau)) ** 2)


def _wrap_edges(parts, seed: int = 70) -> None:
    """The overlapping edges of the wound linen strip: a slightly raised, frayed ribbon running
    diagonally over the body between the ropes, light on its top, shadowed where it steps down."""
    for i, x0 in enumerate((-0.52, -0.33, -0.14, 0.24, 0.42)):
        bm = bmesh.new()
        rows = []
        for k, a in enumerate(range(-10, 200, 21)):
            xc = x0 + 0.11 * (a - 90.0) / 100.0 + 0.004 * math.sin(k * 2.3 + i)
            fray = 0.004 * ((k % 2) * 2 - 1)
            rows.append((bm.verts.new(_on_loft(SHROUD_SECS, xc - 0.022, a, 0.013, _shroud_fold)),
                         bm.verts.new(_on_loft(SHROUD_SECS, xc + 0.014 + fray, a, 0.003, _shroud_fold))))
        for (a0, b0), (a1, b1) in zip(rows, rows[1:]):
            bm.faces.new((a0, a1, b1, b0))
        rib = _raw(bm, "wrap_edge")
        parts.append(_cloth(rib, lambda co, poly: L.scale_c(SHROUD_LINEN, 0.97) if poly.normal.x < 0.25 else
                            L.scale_c(SHROUD_DIRTY, 0.8), var=0.08, ao=0.3, top=0.15, seed=seed + i))


def corpse_shrouded():
    """A body wrapped in pale linen: the strip winds round in soft overlapping bands, the toes,
    folded hands and a hint of the face show through; tied with rope at ankles, waist and neck,
    knots with frayed loose ends, a sprig of heather tucked under the waist rope."""
    L.reset(201)
    body = _loft(SHROUD_SECS, SHROUD_ANG, fold=_shroud_fold, name="shroud")
    L.jitter(body, 0.004, 9.0, 4)
    parts = [_cloth(body, _shroud_paint, var=0.06, ao=0.4, top=0.12, freq=5.0, seed=5)]
    _wrap_edges(parts)
    # the linen gathered and twisted shut above the head, a few frayed threads
    parts.append(_blob("ico", (0.024, 0.036, 0.026), (0.868, 0.0, 0.052), (1, 0, 0.3), (0, 0, 1), color=SHROUD_DIRTY,
                       subdivisions=1, jit=0.004, seed=60, ao=0.2))
    for i, (dy, dz) in enumerate(((-0.022, 0.045), (0.02, 0.058), (0.004, 0.07))):
        parts.append(_blob("cone", (0.012, 0.01, 0.018), (0.882, dy, dz), (1, dy * 6.0, 0.2 + dz), (0, 0, 1),
                           color=L.mix(SHROUD_LINEN, SHROUD_DIRTY, 0.6), vertices=4, jit=0.002, seed=61 + i, ao=0.1))
    for i, xr in enumerate(ROPES):
        wob = (0.006, -0.005, 0.004)[i]
        angs = (-12, 10, 32, 55, 78, 100, 124, 148, 170, 192)
        pts = [_on_loft(SHROUD_SECS, xr + wob * math.sin(math.radians(a) * 2.0), a, 0.009, _shroud_fold)
               for a in angs]
        parts.append(_cloth(_tube(pts, [0.011] * len(pts), 4, hint=(1, 0, 0), caps=(False, False)),
                            lambda co, poly: L.scale_c(ROPE, 1.0 - 0.18 * max(0.0, math.sin(co.y * 140.0)) ** 2),
                            var=0.15, ao=0.15, top=0.25, seed=10 + i))
        knot = _on_loft(SHROUD_SECS, xr, 108.0, 0.016, _shroud_fold)
        parts.append(_blob("ico", (0.024, 0.02, 0.016), knot, (0, -0.3, 1), (1, 0, 0), color=L.scale_c(ROPE, 0.92),
                           subdivisions=1, jit=0.004, seed=20 + i, ao=0.1, top=0.25))
        for k in ((-1, 1) if i == 1 else (1,)):  # loose ends, frayed tips
            e1 = knot + Vector((k * 0.03, -0.045, -0.018))
            e2 = knot + Vector((k * 0.05, -0.075 - 0.01 * k, -0.07))
            parts.append(_cloth(_tube((knot, e1, e2), (0.009, 0.0085, 0.008), 4, caps=(False, False)), _flat(ROPE),
                                var=0.15, ao=0.15, top=0.25, seed=30 + i))
            parts.append(_blob("cone", (0.013, 0.013, 0.018), e2 + (e2 - e1).normalized() * 0.014, e2 - e1,
                               (0, 0, 1), color=L.mix(ROPE, STRING, 0.5), vertices=4, jit=0.002, seed=40 + i, ao=0.1))
    # a sprig of heather tucked under the waist rope, pointing to the heart
    _sprig(parts, _on_loft(SHROUD_SECS, 0.06, 92.0, 0.012, _shroud_fold), Vector((1.0, 0.2, 0.12)), seed=50, n=4)
    _corpse_done(parts, "ph_prop_corpse_shrouded")


# --- stations ----------------------------------------------------------------

def handcart():
    """The carter's two-wheeled cart: plank bed with low sides, spoked wheels,
    two handles pointing -Y (0.66 m apart, grips at ~0.85 m) and a rest leg at +Y."""
    L.reset(210)
    parts = []
    bed_z, y0, y1 = 0.63, -0.72, 1.02       # top of the floor boards, bed (fits a 1.7 m body) handle end -> front
    ym, hl = (y0 + y1) / 2, (y1 - y0) / 2
    for i in range(4):                       # floor boards along Y
        parts.append(_plank((-0.345 + i * 0.23, ym, bed_z - 0.02), (0.112, hl, 0.02), WOOD, seed=i, cuts=1,
                            ao=0.25))
    for sx in (-1, 1):
        for k in range(2):                   # low sides: two stacked boards
            parts.append(_plank((sx * 0.475, ym, bed_z + 0.055 + k * 0.1), (0.02, hl + 0.02, 0.045), WOOD,
                                seed=10 + k + sx, rot=(0, sx * 4, 0)))
        for y in (y0 + 0.06, ym, y1 - 0.06):  # stakes
            parts.append(L.part("cube", WOOD_DARK, loc=(sx * 0.5, y, bed_z + 0.07), scale=(0.022, 0.03, 0.15),
                                jit=0.004, seed=int(y * 10) + 5))
        # rails under the bed that become the handles, rising towards the grips
        parts.append(_plank((sx * 0.35, ym + 0.02, bed_z - 0.08), (0.04, hl + 0.04, 0.04), WOOD_DARK, seed=20 + sx))
        parts.append(_stick((sx * 0.35, y0 + 0.1, bed_z - 0.08), (sx * 0.33, -1.12, 0.8), 0.036, WOOD_DARK,
                            r1=0.03, verts=6, seed=22))
        parts.append(_stick((sx * 0.33, -1.1, 0.795), (sx * 0.33, -1.27, 0.84), 0.032, LEATHER, r1=0.028,
                            verts=6, seed=23))  # worn grips
        parts.append(_stick((sx * 0.35, y1 - 0.12, bed_z - 0.1), (sx * 0.36, y1 - 0.02, 0.0), 0.03, WOOD_DARK,
                            r1=0.026, verts=5, seed=24, ao=0.5))  # rest leg
    parts.append(_plank((0, y1 + 0.01, bed_z + 0.1), (0.5, 0.022, 0.1), WOOD, seed=30, cuts=1))  # front board
    parts.append(_plank((0, y0 - 0.02, bed_z + 0.03), (0.5, 0.02, 0.05), WOOD, seed=31))           # low back board
    # axle + two spoked wheels (iron tyre, hub, 8 spokes)
    wy, wr, wx = 0.15, 0.46, 0.585
    parts.append(_stick((-wx, wy, wr), (wx, wy, wr), 0.03, IRON, verts=6, seed=40))
    for sx in (-1, 1):
        x = sx * wx
        parts.append(L.part("torus", WOOD_DARK, loc=(x, wy, wr), rot=(0, 90, 0), major_radius=wr - 0.035,
                            minor_radius=0.035, major_segments=16, minor_segments=4, seed=41))
        parts.append(L.part("torus", IRON, loc=(x, wy, wr), rot=(0, 90, 0), major_radius=wr - 0.004,
                            minor_radius=0.016, major_segments=16, minor_segments=3,
                            paint_kw={"hue_shift": RUST, "var": 0.3}))
        parts.append(L.part("cyl", WOOD_DARK, loc=(x, wy, wr), rot=(0, 90, 0), radius=0.075, depth=0.13,
                            vertices=8, seed=42))
        for k in range(8):
            a = k / 8 * math.tau + 0.2
            d = Vector((0, math.cos(a), math.sin(a)))
            p0 = Vector((x, wy, wr)) + d * 0.06
            p1 = Vector((x, wy, wr)) + d * (wr - 0.05)
            parts.append(_stick(p0, p1, 0.018, WOOD, r1=0.014, verts=4, seed=43 + k))
    # a folded sack in the bed, a rope coil at the front board
    parts.append(_rbox((0.15, 0.8, bed_z + 0.04), (0.2, 0.14, 0.04), LINEN_DIRTY, bev=0.03, seed=50, jit=0.012,
                       rot=(0, 0, 12), hue_shift=EARTH))
    parts.append(L.part("torus", ROPE, loc=(-0.3, 0.86, bed_z + 0.025), major_radius=0.1, minor_radius=0.022,
                        major_segments=10, minor_segments=4, jit=0.006, seed=51))
    obj = L.join(parts, "ph_prop_handcart")
    _slot(obj, (0, ym, bed_z), 90.0)         # corpse lies along the cart (Y), head to the front board
    L.finish(obj, "ph_prop_handcart", "props", 35)


def morgue_table():
    """Sturdy examination table: stone slab (2.0 x 0.8 m, top at 0.85 m) on a heavy
    wooden frame, a shelf below with bucket and folded cloth."""
    L.reset(220)
    top = 0.85
    slab = L.prim("cube", loc=(0, 0, top - 0.05), scale=(0.95, 0.35, 0.05))
    L.bevel(slab, 0.012, 1)
    L.subdivide(slab, 2)
    L.jitter(slab, 0.007, 3.0, 1)
    L.paint(slab, STONE_OLD, var=0.3, ao=0.2, top=0.05, zrange=(0.0, top), noise_freq=3.5,
            hue_shift=L.hexc("#4E4B45"), seed=2)  # worn, stained
    L.set_mat(slab, L.MAT_PAINTED)
    parts = [slab]
    for sy in (-1, 1):  # the slab is set into a heavy wooden frame
        parts.append(_plank((0, sy * 0.385, top - 0.045), (1.0, 0.04, 0.055), WOOD_DARK, seed=40 + sy, cuts=1,
                            zrange=(0, top)))
    for sx in (-1, 1):
        parts.append(_plank((sx * 0.985, 0, top - 0.045), (0.04, 0.345, 0.055), WOOD_DARK, seed=43 + sx,
                            zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):  # heavy legs
            leg = L.prim("cube", loc=(0, 0, 0.37), scale=(0.065, 0.065, 0.37))
            L.subdivide(leg, 1)
            L.taper(leg, 0.0, 0.74, 1.12)  # taper scales about the origin: build centred, then move
            leg.data.transform(Matrix.Translation((sx * 0.84, sy * 0.3, 0)))
            L.jitter(leg, 0.006, 3.0, 3 + sx + sy)
            parts.append(_finish_obj(leg, WOOD_DARK, ao=0.5, zrange=(0, top), seed=4))
    for sy in (-1, 1):  # aprons and low stretchers along X
        parts.append(_plank((0, sy * 0.33, 0.68), (0.8, 0.03, 0.06), WOOD, seed=10 + sy, cuts=1, zrange=(0, top)))
        parts.append(_plank((0, sy * 0.3, 0.2), (0.8, 0.035, 0.035), WOOD_DARK, seed=12 + sy, zrange=(0, top)))
    for sx in (-1, 1):
        parts.append(_plank((sx * 0.84, 0, 0.68), (0.03, 0.27, 0.06), WOOD, seed=14 + sx, zrange=(0, top)))
        parts.append(_plank((sx * 0.84, 0, 0.2), (0.035, 0.27, 0.035), WOOD_DARK, seed=16 + sx, zrange=(0, top)))
    for i in range(3):  # shelf boards
        parts.append(_plank((-0.5 + i * 0.5, 0, 0.245), (0.24, 0.27, 0.012), WOOD, seed=20 + i, zrange=(0, top)))
    # bucket (staves + iron bands) and a folded cloth on the shelf
    bucket = L.prim("cyl", loc=(0, 0, 0.37), radius=0.12, depth=0.24, vertices=12)
    L.taper(bucket, 0.25, 0.49, 1.15)
    bucket.data.transform(Matrix.Translation((0.45, 0.02, 0)))
    parts.append(_finish_obj(bucket, WOOD, var=0.18, ao=0.4, zrange=(0.25, 0.5), seed=30))
    for z, r in ((0.3, 0.126), (0.45, 0.137)):
        parts.append(L.part("cyl", IRON, loc=(0.45, 0.02, z), radius=r, depth=0.02, vertices=12))
    parts.append(_rbox((-0.45, -0.02, 0.28), (0.22, 0.16, 0.025), LINEN_DIRTY, bev=0.015, jit=0.008, seed=31,
                       rot=(0, 0, -8)))
    parts.append(_rbox((-0.47, 0.0, 0.325), (0.2, 0.15, 0.02), LINEN, bev=0.015, jit=0.008, seed=32, rot=(0, 0, 5)))
    obj = L.join(parts, "ph_prop_morgue_table")
    _slot(obj, (0, 0, top))
    L.finish(obj, "ph_prop_morgue_table", "props", 35)


def workbench():
    """Carpenter's bench (1.8 x 0.7 m): thick top, front vice, planks, a saw and a mallet."""
    L.reset(230)
    top = 0.86
    parts = []
    for i in range(3):  # thick top boards along X
        parts.append(_plank((0, -0.233 + i * 0.233, top - 0.04), (0.9, 0.115, 0.04), WOOD, seed=i, cuts=2,
                            zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_plank((sx * 0.76, sy * 0.26, (top - 0.08) / 2), (0.05, 0.05, (top - 0.08) / 2), WOOD_DARK,
                                seed=5 + sx + sy, cuts=1, ao=0.5, zrange=(0, top)))
        parts.append(_plank((sx * 0.76, 0, 0.18), (0.035, 0.24, 0.035), WOOD_DARK, seed=9 + sx, zrange=(0, top)))
    for sy in (-1, 1):
        parts.append(_plank((0, sy * 0.26, 0.18), (0.72, 0.035, 0.035), WOOD_DARK, seed=11 + sy, zrange=(0, top)))
    for i in range(3):  # lower shelf with spare boards
        parts.append(_plank((-0.48 + i * 0.48, 0, 0.225), (0.23, 0.26, 0.012), WOOD, seed=13 + i, zrange=(0, top)))
    parts.append(_plank((0.05, 0.02, 0.26), (0.62, 0.1, 0.018), WOOD_FRESH, seed=16, rot=(0, 0, 3), zrange=(0, top)))
    parts.append(_plank((0.0, -0.05, 0.296), (0.58, 0.09, 0.018), WOOD_FRESH, seed=17, rot=(0, 0, -4),
                        zrange=(0, top)))
    # front vice (left): jaw, screw, T-handle
    vx = -0.6
    parts.append(_plank((vx, -0.385, top - 0.1), (0.15, 0.035, 0.1), WOOD_DARK, seed=20, zrange=(0, top)))
    parts.append(_stick((vx, -0.32, top - 0.09), (vx, -0.47, top - 0.09), 0.02, IRON, verts=6, seed=21))
    parts.append(_stick((vx - 0.15, -0.47, top - 0.09), (vx + 0.15, -0.47, top - 0.09), 0.013, WOOD, verts=6,
                        seed=22))
    for k in (-1, 1):
        parts.append(L.part("sphere", WOOD, loc=(vx + k * 0.155, -0.47, top - 0.09), radius=0.022, segments=6,
                            ring_count=4))
    # on the top: two boards, a saw and a mallet, some shavings
    parts.append(_plank((0.32, 0.12, top + 0.016), (0.55, 0.095, 0.016), WOOD_FRESH, seed=30, rot=(0, 0, 7)))
    parts.append(_plank((0.4, 0.14, top + 0.046), (0.5, 0.08, 0.014), L.scale_c(WOOD_FRESH, 1.1), seed=31,
                        rot=(0, 0, -3)))
    blade = L.prim("cube", loc=(-0.2, -0.16, top + 0.004), scale=(0.27, 0.065, 0.003))
    for v in blade.data.vertices:  # taper the blade towards the tip
        if v.co.x < -0.3:
            v.co.y = -0.16 + (v.co.y + 0.16) * 0.55
    parts.append(_finish_obj(blade, STEEL, var=0.12, ao=0.0, top=0.25, hue_shift=RUST, seed=32))
    parts.append(_rbox((0.12, -0.15, top + 0.018), (0.06, 0.07, 0.016), WOOD, bev=0.012, seg=1, seed=33))
    parts.append(L.part("cyl", WOOD_DARK, loc=(0.58, -0.2, top + 0.055), rot=(0, 90, 0), radius=0.055, depth=0.16,
                        vertices=8, jit=0.004, seed=34))
    parts.append(_stick((0.58, -0.2, top + 0.05), (0.52, -0.5, top + 0.02), 0.016, WOOD, verts=6, seed=35))
    for i in range(7):
        x, y = random.uniform(-0.8, 0.8), random.uniform(-0.4, 0.4)
        z = top + 0.006 if abs(y) < 0.33 and i % 2 == 0 else 0.008
        parts.append(L.part("cone", L.hexc("#B79B70"), loc=(x, y if z > 0.1 else y * 1.3, z),
                            rot=(90, 0, random.uniform(0, 180)), radius1=0.02, depth=0.03, vertices=4))
    obj = L.join(parts, "ph_prop_workbench")
    L.finish(obj, "ph_prop_workbench", "props", 35)


def dropoff_bier():
    """Low bier by the gate (2.0 x 0.7 m, top at ~0.5 m): two poles with slats on two trestles."""
    L.reset(240)
    parts = []
    top = 0.51
    for sx in (-1, 1):  # trestles
        x = sx * 0.62
        parts.append(_plank((x, 0, 0.415), (0.045, 0.37, 0.04), WOOD_OLD, seed=1 + sx, cuts=1, zrange=(0, top)))
        for sy in (-1, 1):
            for k in (-1, 1):
                parts.append(_stick((x + k * 0.025, sy * 0.3, 0.42), (x + k * 0.14, sy * 0.36, 0.0), 0.034, WOOD_OLD,
                                    r1=0.028, verts=5, seed=3 + k, ao=0.5, zrange=(0, top), hue_shift=MOSS))
    for sy in (-1, 1):  # carrying poles with rounded, worn handle ends
        parts.append(_stick((-1.0, sy * 0.29, 0.468), (1.0, sy * 0.29, 0.468), 0.03, WOOD, verts=8, seed=10 + sy,
                            zrange=(0, top)))
        for sx in (-1, 1):
            parts.append(L.part("sphere", WOOD, loc=(sx * 1.0, sy * 0.29, 0.468), radius=0.03, segments=8,
                                ring_count=4))
    for i in range(12):  # slats
        x = -0.85 + i * 0.1545
        parts.append(_plank((x, 0, top - 0.013), (0.064, 0.345, 0.013), WOOD_OLD, seed=20 + i,
                            rot=(0, 0, random.uniform(-2, 2)), zrange=(0, top), hue_shift=L.hexc("#7A6E5E")))
    obj = L.join(parts, "ph_prop_dropoff_bier")
    _slot(obj, (0, 0, top))
    L.finish(obj, "ph_prop_dropoff_bier", "props", 35)


# --- graves ------------------------------------------------------------------

def _superellipse(ax: float, ay: float, n: int, p: float = 5.0):
    """Points on a rounded rectangle |x/ax|^p + |y/ay|^p = 1."""
    out = []
    for i in range(n):
        a = i / n * math.tau
        c, s = math.cos(a), math.sin(a)
        out.append((ax * math.copysign(abs(c) ** (2 / p), c), ay * math.copysign(abs(s) ** (2 / p), s)))
    return out


def _rings_mesh(rings, n: int = 36, shape=None, p: float = 5.0, name: str = "rings"):
    """Concentric rounded-rectangle rings (outer first, [(ax, ay, z)]) closed by a centre
    fan - smooth ragged outlines without grid steps.  shape(k, x, y) -> (radial scale, dz)
    adds wobble.  Vertex i belongs to ring i // n (the centre vertex to ring len(rings))."""
    bm = bmesh.new()
    rr = []
    for k, (ax, ay, z) in enumerate(rings):
        ring = []
        for (x, y) in _superellipse(ax, ay, n, p):
            f, dz = shape(k, x, y) if shape else (1.0, 0.0)
            ring.append(bm.verts.new((x * f, y * f, z + dz)))
        rr.append(ring)
    for k in range(len(rr) - 1):
        for i in range(n):
            bm.faces.new((rr[k][i], rr[k][(i + 1) % n], rr[k + 1][(i + 1) % n], rr[k + 1][i]))
    centre = bm.verts.new((0, 0, rings[-1][2]))
    for i in range(n):
        bm.faces.new((rr[-1][i], rr[-1][(i + 1) % n], centre))
    return _link(bm, name)


def _ring_of(obj, n: int):
    """Ring index of every vertex of a _rings_mesh() object."""
    return [v.index // n for v in obj.data.vertices]


def _worn_patch(sx: float, sy: float, wear: float, seed: int):
    """Worn ground patch with a ragged outline: earth in the middle, grass-mixed
    towards the edge (no rectangular 'carpet' edge)."""
    hx, hy = sx / 2, sy / 2
    off = Vector((seed, seed * 0.5, 0))
    rings = [(hx * f, hy * f, z) for f, z in ((1.0, 0.004), (0.86, 0.01), (0.66, 0.015), (0.42, 0.018),
                                               (0.18, 0.018))]

    def ragged(k, x, y):  # same outline noise on every ring -> rings never cross
        d = Vector((x / hx, y / hy, 0)).normalized()
        return 1.0 + 0.14 * noise.noise(d * 1.8 + off) * (1.0 - 0.15 * k), 0.0
    g = _rings_mesh(rings, 40, ragged, p=4.0, name="patch")
    ring = _ring_of(g, 40)

    def col(co, vi):  # earth towards the middle rings, grass-mixed at the ragged edge
        t = min(1.0, ring[vi] / 3.0 + noise.noise(co * 2.5 + off) * 0.25) * wear
        c = L.mix(L.mix(GRASS, GRASS_B, 0.5 + 0.5 * noise.noise(co * 1.3 + off)), EARTH, 0.2 + 0.8 * max(0.0, t))
        return L.scale_c(c, 1.0 + noise.noise(co * 7.0 + off) * 0.08)
    _paint_fn(g, col)
    L.set_mat(g, L.MAT_PAINTED)
    return g


def grave_plot_empty():
    """1 x 2 m plot: four wooden pegs, a sagging string, a slightly worn ground patch."""
    L.reset(250)
    parts = [_worn_patch(1.25, 2.25, 0.85, 3)]
    tops = []
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        x, y = sx * 0.5, sy * 1.0
        lean = (random.uniform(-6, 6), random.uniform(-6, 6))
        peg = L.prim("cube", loc=(x, y, 0.17), rot=(lean[0], lean[1], random.uniform(0, 30)),
                     scale=(0.025, 0.025, 0.17))
        L.jitter(peg, 0.004, 4.0, i)
        parts.append(_finish_obj(peg, WOOD_FRESH, ao=0.55, seed=i, hue_shift=WOOD))
        lx, ly = math.radians(lean[0]), math.radians(lean[1])
        tip = Vector((x, y, 0.3)) + Vector((math.sin(ly), -math.sin(lx), 0)) * 0.13  # where the string is tied
        tops.append(tip)
    for i in range(4):  # the string sags between the pegs
        a, b = tops[i], tops[(i + 1) % 4]
        pts = [a.lerp(b, t / 8) - Vector((0, 0, 0.05 * math.sin(math.pi * t / 8))) for t in range(9)]
        parts.append(_finish_obj(_path_tube(pts, 0.005, 4, name="string"), STRING, ao=0.0, var=0.08, seed=10 + i))
    parts += _clods(7, (-0.45, 0.45), (-0.95, 0.95), EARTH, r=(0.02, 0.04), z=0.01, seed=20)
    obj = L.join(parts, "ph_prop_grave_plot_empty")
    L.finish(obj, "ph_prop_grave_plot_empty", "props", 40, shift=False)  # the patch stays at ground level


# Pit rings: (half x, half y, height) from the outer foot of the earth rim to the dark floor
PIT_RINGS = [(0.72, 1.22, 0.0), (0.63, 1.13, 0.05), (0.56, 1.06, 0.085), (0.52, 1.02, 0.08),
             (0.5, 1.0, 0.06), (0.47, 0.97, 0.04), (0.38, 0.82, 0.034), (0.2, 0.5, 0.032)]


def _pit_colour(co, k: int):
    """Fake depth: the far wall (+Y, facing the camera) fades from earth to black,
    the floor and the zone under the near lip (-Y) are darkest."""
    if k < 4:  # the trampled earth rim, grass-mixed at its foot
        c = L.mix(EARTH_FRESH, EARTH, 0.35 + 0.35 * noise.noise(co * 3.0))
        c = L.scale_c(c, 0.78 + 0.08 * k)
        return L.mix(c, GRASS, 0.55) if k == 0 else c
    v = max(-1.0, min(1.0, co.y / 1.0))          # -1 near lip ... +1 far lip
    u = min(1.0, abs(co.x) / 0.5)
    wall = max(0.0, min(1.0, (v + 0.15) / 1.1)) ** 1.6
    side = 0.35 * max(0.0, u - 0.55) / 0.45       # side walls catch a little light
    depth = max(0.0, min(1.0, (k - 3.5) / 1.2))
    t = max(wall, side) * (1.0 - 0.25 * depth * (1.0 - wall))
    c = L.mix(PIT_BLACK, L.mix(EARTH_DARK, EARTH_FRESH, 0.6), t)
    c = L.mix(c, L.mix(EARTH_FRESH, EARTH_DARK, 0.3), max(0.0, 1.0 - depth * 2.2) * 0.8)  # lip band
    return L.scale_c(c, 1.0 + noise.noise(co * 6.0) * 0.12)


def _pit_surface(n: int = 36):
    def lumpy(k, x, y):
        if not 0 < k < 4:
            return 1.0 + noise.noise(Vector((x * 2.5, y * 2.5, k))) * 0.008, 0.0
        dz = noise.noise(Vector((x * 4.0, y * 4.0, 3.0))) * 0.035
        f = 1.0 + noise.noise(Vector((x * 2.5, y * 2.5, k * 0.7))) * 0.05
        return f, (dz - 0.02 if y < 0 else dz)  # lower near rim: the camera looks over it
    obj = _rings_mesh(PIT_RINGS, n, lumpy, name="pit")
    ring = _ring_of(obj, n)
    _paint_fn(obj, lambda co, vi: _pit_colour(co, ring[vi]))
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _heap(cx: float, cy: float, rx: float, ry: float, h: float, seed: int):
    """Loose earth heap: lumpy dome of concentric rings (smooth outline, foot just below ground)."""
    rings = [(rx * f, ry * f, h * z) for f, z in ((1.0, -0.04), (0.86, 0.3), (0.68, 0.6), (0.48, 0.84),
                                                  (0.26, 0.97))]
    off = Vector((seed, 0, 0))

    def lumps(k, x, y):
        d = Vector((x / rx, y / ry, 0)).normalized()
        f = 1.0 + 0.1 * noise.noise(d * 1.6 + off)
        return f, (noise.noise(Vector((x, y, 0)) * 3.0 + off) * 0.09 * (1.0 if k else 0.0))
    g = _rings_mesh(rings, 32, lumps, p=2.4, name="heap")
    g.data.transform(Matrix.Translation((cx, cy, 0)))
    L.jitter(g, 0.03, 4.0, seed + 20)
    L.jitter(g, 0.018, 9.0, seed + 50)
    L.paint(g, EARTH_FRESH, var=0.3, ao=0.45, top=0.1, noise_freq=3.0, hue_shift=L.hexc("#3E2F24"), seed=seed)
    L.set_mat(g, L.MAT_PAINTED)
    return g


def grave_pit():
    """Open grave for a 1 x 2 m plot.  The ground is a continuous plane, so the hole
    is faked: a dark floor just above the ground inside a raised earth rim, painted
    so the far wall reads from a 45 degree camera.  Dirt pile and shovel on +X."""
    L.reset(260)
    parts = [_pit_surface(), _heap(1.12, 0.12, 0.46, 0.9, 0.52, 3), _heap(1.0, -0.62, 0.32, 0.42, 0.3, 4)]
    parts += _clods(5, (0.62, 1.5), (-1.1, 1.15), EARTH_FRESH, r=(0.03, 0.06), z=0.03, seed=10)
    for i in range(11):  # clods on top of the heap and along the trampled rim
        if i < 6:
            x, y = 1.12 + random.uniform(-0.3, 0.3), 0.12 + random.uniform(-0.7, 0.7)
            d = math.hypot((x - 1.12) / 0.46, (y - 0.12) / 0.9)
            z = 0.52 * max(0.0, 1.0 - d * d) ** 0.8
        else:
            a = random.uniform(0, math.tau)
            x, y, z = math.cos(a) * 0.58, math.sin(a) * 1.08, 0.07
            if x > 0.4:
                x = -x
        parts.append(L.part("ico", L.scale_c(EARTH_FRESH, random.uniform(0.85, 1.15)), loc=(x, y, z),
                            radius=random.uniform(0.03, 0.055), subdivisions=1, jit=0.012, seed=30 + i))
    # shovel stuck in the pile, leaning back towards the pit
    base, tip = Vector((1.0, 0.42, 0.4)), Vector((0.88, 0.58, 1.42))
    parts.append(_stick(base, tip, 0.021, WOOD, verts=6, seed=40))
    grip_d = Vector((0.08, 0, 0))
    parts.append(_stick(tip - grip_d, tip + grip_d, 0.018, WOOD, verts=6, seed=41))
    blade = L.prim("cube", loc=(0, 0, 0), scale=(0.12, 0.014, 0.16))
    L.jitter(blade, 0.008, 4.0, 42)
    blade.data.transform(Matrix.Translation(base + Vector((0.0, -0.01, 0.05))) @
                         Vector((0, 0, 1)).rotation_difference((tip - base).normalized()).to_matrix().to_4x4())
    parts.append(_finish_obj(blade, IRON, hue_shift=RUST, var=0.3, seed=43))
    obj = L.join(parts, "ph_prop_grave_pit")
    L.finish(obj, "ph_prop_grave_pit", "props", 50, shift=False)


# --- resources & markers -----------------------------------------------------

def _split_log(cx: float, cz: float, r: float, a0: float, a1: float, y0: float, y1: float, seed: int, segs: int = 4):
    """Firewood along Y: a round log (a1 - a0 = tau) or a split wedge of one.
    Returns (bark, core) objects: dark bark shell, pale split faces and end grain."""
    full = a1 - a0 >= math.tau - 1e-3
    if full:
        segs = 8
    arc = [(cx + math.cos(a0 + (a1 - a0) * i / segs) * r, cz + math.sin(a0 + (a1 - a0) * i / segs) * r)
           for i in range(segs if full else segs + 1)]
    wedge = arc + ([(cx, cz)] if (not full and a1 - a0 < math.pi * 0.99) else [])
    bm_bark, bm_core = bmesh.new(), bmesh.new()
    ab = [(bm_bark.verts.new((x, y0, z)), bm_bark.verts.new((x, y1, z))) for x, z in arc]
    na = len(arc)
    for i in range(na if full else segs):
        j = (i + 1) % na
        bm_bark.faces.new((ab[i][0], ab[j][0], ab[j][1], ab[i][1]))
    ac = [(bm_core.verts.new((x, y0, z)), bm_core.verts.new((x, y1, z))) for x, z in wedge]
    m = len(wedge)
    if not full:
        for i in range(segs, m):  # split faces (not the bark arc)
            j = (i + 1) % m
            bm_core.faces.new((ac[i][0], ac[j][0], ac[j][1], ac[i][1]))
    bm_core.faces.new([p[0] for p in ac])
    bm_core.faces.new([p[1] for p in reversed(ac)])
    bark, core = _link(bm_bark, "bark"), _link(bm_core, "core")
    for o in (bark, core):
        L.jitter(o, 0.005, 5.0, seed)
    L.paint(bark, L.mix(BARK, BARK_DARK, random.random() * 0.6), var=0.25, ao=0.3, zrange=(0, 0.85), seed=seed,
            hue_shift=MOSS if random.random() < 0.3 else None)
    L.paint(core, L.mix(END_GRAIN, WOOD_FRESH, random.random() * 0.6), var=0.14, ao=0.35, zrange=(0, 0.85),
            seed=seed)
    L.set_mat(bark, L.MAT_PAINTED)
    L.set_mat(core, L.MAT_PAINTED)
    return [bark, core]


def _firewood(x: float, z: float, r: float, y0: float, y1: float, seed: int):
    """One piece in a stack: round (45 %), half with the flat side up/down (40 %) or quarter.
    (x, z) is the centroid, so split pieces pack like round ones."""
    k = random.random()
    if k < 0.45:
        a0, span, off = random.uniform(0, 1), math.tau, 0.0
    elif k < 0.85:
        a0, span, off = random.choice((0.0, math.pi)) + random.uniform(-0.25, 0.25), math.pi, 0.42
    else:
        a0, span, off = random.randrange(4) * math.pi / 2 + random.uniform(-0.2, 0.2), math.pi / 2, 0.6
    mid = a0 + span / 2
    return _split_log(x - math.cos(mid) * r * off, z - math.sin(mid) * r * off, r * (1.15 if off else 1.0),
                      a0, a0 + span, y0, y1, seed)


def wood_pile():
    """Stacked firewood between two stakes (~1.2 m wide, 0.8 m high)."""
    L.reset(270)
    parts = []
    for y in (-0.14, 0.14):  # sleepers keep the stack off the ground
        parts.append(_stick((-0.62, y, 0.045), (0.62, y, 0.045), 0.045, BARK_DARK, verts=6, seed=1, ao=0.5))
    rows = 5
    for row in range(rows):
        z = 0.165 + row * 0.148
        n = 7 if row < rows - 1 else 5
        x0 = -0.5 if row < rows - 1 else -0.33
        for i in range(n):
            x = x0 + i * 0.167 + random.uniform(-0.01, 0.01) + (0.02 if row % 2 else -0.02)
            ly = random.uniform(-0.03, 0.03)
            parts += _firewood(x, z, random.uniform(0.074, 0.084), -0.24 + ly, 0.24 + ly, seed=row * 10 + i)
    for sx in (-1, 1):  # stakes
        parts.append(_stick((sx * 0.64, -0.05, 0.0), (sx * 0.66, -0.06, 0.88), 0.035, BARK, r1=0.028, verts=6,
                            seed=5 + sx, ao=0.4, hue_shift=MOSS))
    # two loose pieces in front, a few chips
    parts += _split_log(-0.2, 0.0, 0.09, 0.0, math.pi, -0.66, -0.34, seed=90)
    parts += _split_log(0.26, 0.075, 0.075, 0.0, math.tau, -0.6, -0.32, seed=91)
    for i in range(6):
        parts.append(L.part("cube", END_GRAIN, loc=(random.uniform(-0.5, 0.5), random.uniform(-0.62, -0.3), 0.006),
                            rot=(0, 0, random.uniform(0, 180)), scale=(0.03, 0.012, 0.005)))
    obj = L.join(parts, "ph_prop_wood_pile")
    L.finish(obj, "ph_prop_wood_pile", "props", 40)


def _stone(loc, size, rot, seed: int, color=STONE, flat: float = 1.0, cuts: int = 1):
    """Broken, angular stone: jittered subdivided box, mossy on top."""
    s = L.prim("cube", loc=(0, 0, 0), scale=(size[0], size[1], size[2] * flat))
    if cuts:
        L.subdivide(s, cuts)
    L.jitter(s, min(size) * 0.45, 1.1 / min(size), seed)          # noise scaled to the stone: real deformation
    L.jitter(s, min(size) * 0.12, 3.5 / min(size), seed + 100)
    s.data.transform(Matrix.Translation(loc) @ (Matrix.Rotation(math.radians(rot[2]), 4, "Z") @
                                                Matrix.Rotation(math.radians(rot[1]), 4, "Y") @
                                                Matrix.Rotation(math.radians(rot[0]), 4, "X")))
    L.paint(s, L.scale_c(color, random.uniform(0.78, 0.95)), var=0.25, ao=0.5, zrange=(0.0, 0.6),
            hue_shift=MOSS, seed=seed)
    _tint_up(s, MOSS, 0.6, 0.5, seed=seed)
    L.set_mat(s, L.MAT_PAINTED)
    return s


def stone_rubble():
    """Heap of broken stones and a cracked worked block (~1.1 m wide, 0.5 m high)."""
    L.reset(280)
    parts = []
    heap = [((0.0, 0.05, 0.14), (0.26, 0.2, 0.15)), ((-0.33, -0.05, 0.1), (0.2, 0.18, 0.11)),
            ((0.33, 0.12, 0.1), (0.2, 0.16, 0.1)), ((0.1, -0.25, 0.08), (0.16, 0.13, 0.08)),
            ((-0.15, 0.3, 0.09), (0.18, 0.14, 0.09)), ((-0.05, 0.0, 0.33), (0.17, 0.14, 0.11)),
            ((0.2, 0.05, 0.3), (0.13, 0.11, 0.09)), ((-0.25, 0.12, 0.27), (0.12, 0.1, 0.08)),
            ((0.05, 0.1, 0.46), (0.1, 0.09, 0.07)), ((0.45, -0.2, 0.05), (0.09, 0.08, 0.05)),
            ((-0.5, 0.2, 0.05), (0.08, 0.07, 0.05)), ((-0.35, -0.35, 0.04), (0.07, 0.06, 0.04))]
    for i, (loc, size) in enumerate(heap):
        rot = (random.uniform(-15, 15), random.uniform(-15, 15), random.uniform(0, 90))
        col = L.scale_c(L.mix(STONE if i % 3 else STONE_OLD, EARTH, 0.25), 0.82)
        parts.append(_stone(loc, size, rot, 10 + i, col))
    base = _rings_mesh([(0.72, 0.58, 0.003), (0.55, 0.45, 0.012), (0.3, 0.25, 0.016)], 28, p=2.2, name="grit")
    L.jitter(base, 0.004, 6.0, 70)
    L.paint(base, L.scale_c(L.mix(EARTH, STONE_OLD, 0.35), 0.8), var=0.3, ao=0.0, noise_freq=4.0, hue_shift=GRASS,
            seed=71)
    L.set_mat(base, L.MAT_PAINTED)
    parts.append(base)
    # a cracked, squared block leaning against the heap (worked stone reads as 'building material')
    block = L.prim("cube", loc=(0.28, -0.3, 0.16), rot=(0, -28, 12), scale=(0.2, 0.12, 0.12))
    L.bevel(block, 0.015, 1)
    L.jitter(block, 0.012, 3.0, 50)
    L.paint(block, L.scale_c(STONE_BLUE, 0.85), var=0.18, ao=0.4, zrange=(0, 0.6), hue_shift=MOSS, seed=51)
    L.set_mat(block, L.MAT_PAINTED)
    parts.append(block)
    parts += _clods(8, (-0.6, 0.6), (-0.5, 0.45), STONE_OLD, r=(0.025, 0.045), z=0.015, seed=60)
    obj = L.join(parts, "ph_prop_stone_rubble")
    L.finish(obj, "ph_prop_stone_rubble", "props", 30, shift=False)  # grit patch at ground level


def cross_wood():
    """Simple wooden grave cross (~1.0 m), weathered, lashed with twine, a little mossy at the foot."""
    L.reset(290)
    post = L.prim("cube", loc=(0, 0, 0.5), scale=(0.042, 0.03, 0.5))
    L.bevel(post, 0.006, 1)
    L.subdivide(post, 1)
    L.jitter(post, 0.006, 3.0, 1)
    bar = L.prim("cube", loc=(0, -0.012, 0.73), scale=(0.25, 0.024, 0.036))
    L.bevel(bar, 0.005, 1)
    L.subdivide(bar, 1)
    L.jitter(bar, 0.005, 3.0, 2)
    for i, o in enumerate((post, bar)):
        L.paint(o, WOOD_OLD, var=0.2, ao=0.5, zrange=(0, 1.0), noise_freq=3.0, hue_shift=MOSS if i == 0 else WOOD,
                seed=3 + i)
        L.set_mat(o, L.MAT_PAINTED)
    parts = [post, bar]
    for k in (-1, 1):  # twine lashing (crossed)
        parts.append(L.part("cube", ROPE, loc=(0, -0.04, 0.73), rot=(0, k * 45, 0), scale=(0.058, 0.006, 0.009)))
    parts.append(L.part("cube", L.scale_c(WOOD_OLD, 0.7), loc=(0, -0.034, 0.56), scale=(0.028, 0.004, 0.07)))
    for i in range(6):  # earth collar where it was driven in
        a = i / 6 * math.tau
        parts.append(L.part("ico", EARTH, loc=(math.cos(a) * 0.08, math.sin(a) * 0.07, 0.015),
                            radius=random.uniform(0.03, 0.045), subdivisions=1, jit=0.008, seed=10 + i,
                            scale=(1, 1, 0.6)))
    obj = L.join(parts, "ph_prop_cross_wood")
    obj.rotation_euler = (math.radians(-2.5), math.radians(3.5), 0)
    L.finish(obj, "ph_prop_cross_wood", "props", 40)


def _prism_y(poly_xz, y: float, thickness: float):
    """Extrude a polygon given in the XZ plane along Y (lib prism_x, turned 90 degrees)."""
    o = L.prism_x(poly_xz, -y, thickness)
    o.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z"))
    return o


def signpost():
    """Weathered post with one arrow board pointing +X (the text is added in Godot at label_board)."""
    L.reset(300)
    post = L.prim("cube", loc=(0, 0, 0.95), scale=(0.055, 0.055, 0.95))
    L.subdivide(post, 2)
    L.jitter(post, 0.008, 2.5, 1)
    L.bend(post, 0.05, 0.0, 1.9, "x")
    L.paint(post, WOOD_OLD, var=0.2, ao=0.5, zrange=(0, 1.95), hue_shift=MOSS, seed=2)
    L.set_mat(post, L.MAT_PAINTED)
    cap = L.part("cone", WOOD_DARK, loc=(0.05, 0, 1.94), rot=(0, 0, 45), vertices=4, radius1=0.085, depth=0.08)
    bz, by, h = 1.56, -0.075, 0.115
    arrow = [(-0.14, bz - h), (0.62, bz - h - 0.01), (0.8, bz + 0.005), (0.62, bz + h + 0.01), (-0.14, bz + h)]
    board = _prism_y(arrow, by, 0.032)
    L.subdivide(board, 1)
    L.jitter(board, 0.005, 3.0, 3)
    L.paint(board, L.hexc("#8A7254"), var=0.16, ao=0.25, zrange=(bz - h, bz + h), hue_shift=WOOD_OLD, seed=4)
    L.set_mat(board, L.MAT_PAINTED)
    parts = [post, cap, board]
    for x in (-0.05, 0.03):  # nails
        parts.append(L.part("cube", IRON, loc=(x, by - 0.017, bz), scale=(0.008, 0.004, 0.008)))
    for i in range(5):  # stones wedging the post
        a = i / 5 * math.tau + 0.4
        parts.append(_stone((math.cos(a) * 0.13, math.sin(a) * 0.12, 0.035), (0.065, 0.055, 0.045),
                            (0, 0, random.uniform(0, 90)), 20 + i, STONE_OLD))
    obj = L.join(parts, "ph_prop_signpost")
    L.marker(obj, "label_board", (0.31, by - 0.018, bz))
    L.finish(obj, "ph_prop_signpost", "props", 40)


def _trunk(x0: float, x1: float, r0: float, r1: float, rings: int = 12, verts: int = 12, sink: float = 0.07,
           seed: int = 0):
    """Straight-ish lying trunk along X: rings with bark bulges, resting on (slightly in) the ground."""
    bm = bmesh.new()
    rr = []
    for k in range(rings + 1):
        t = k / rings
        x = x0 + (x1 - x0) * t
        r = r0 + (r1 - r0) * t
        rf = r * (1.0 + 0.3 * max(0.0, 1.0 - t * 5.0) ** 2)   # root flare towards the root plate
        cy = noise.noise(Vector((t * 1.5, seed, 0.3))) * 0.06
        cz = r - sink - 0.04 * math.sin(math.pi * t)
        ring = []
        for j in range(verts):
            a = j / verts * math.tau
            f = 1.0 + noise.noise(Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, t * 7.0 + seed))) * 0.12
            f *= 1.06 if j % 2 else 0.95                           # bark ridges
            f *= rf / r
            ring.append(bm.verts.new((x, cy + math.cos(a) * r * f, cz + math.sin(a) * r * f)))
        rr.append(ring)
    for k in range(rings):
        for j in range(verts):
            bm.faces.new((rr[k][j], rr[k][(j + 1) % verts], rr[k + 1][(j + 1) % verts], rr[k + 1][j]))
    bm.faces.new(list(reversed(rr[0])))
    bm.faces.new(rr[-1])
    return _link(bm, "trunk")


def fallen_log():
    """Large fallen, mossy trunk (~6 m along X) with its upturned root plate at -X
    and a splintered break at +X.  Roots reach below ground (pivot kept at z = 0)."""
    L.reset(310)
    trunk = _trunk(-2.75, 2.85, 0.42, 0.28, rings=14, verts=14, seed=1)
    # root plate: upturned, lumpy root ball with soil, standing on its edge
    plate = L.prim("ico", loc=(-2.95, 0.0, 0.66), radius=0.95, subdivisions=3, scale=(0.38, 1.0, 0.8))
    L.jitter(plate, 0.16, 1.3, 2)
    L.jitter(plate, 0.05, 4.0, 3)
    L.paint(plate, L.hexc("#4E4134"), var=0.32, ao=0.45, zrange=(-0.2, 1.4), noise_freq=2.5, hue_shift=BARK_DARK,
            seed=4)
    _tint_up(plate, MOSS, 0.5, 0.55, seed=4)
    L.set_mat(plate, L.MAT_PAINTED)
    roots = []
    for i in range(9):  # thick roots torn out of the plate, drooping to the ground
        a = i / 9 * math.tau + 0.35
        start = (-3.05, math.cos(a) * 0.4, 0.66 + math.sin(a) * 0.34)
        d = (-0.55 - random.uniform(0.0, 0.3), math.cos(a), math.sin(a) * 0.7 + 0.1)
        roots.append(limb(start, d, random.uniform(0.5, 0.8), 0.13, 0.03, 30 + i, segs=3, verts=6,
                          droop=0.3))
    stubs = []  # broken branch stubs and one dead branch reaching up
    for i, (x, a, ln) in enumerate(((-1.5, 55, 0.3), (-0.4, -65, 0.28), (0.9, 110, 0.4), (1.9, -45, 0.26))):
        d = (0.4, math.cos(math.radians(a)), math.sin(math.radians(a)))
        stubs.append(limb((x, 0.0, 0.3), d, ln + 0.25, 0.09, 0.05, 50 + i, segs=2, verts=6))
    stubs.append(limb((0.4, 0.05, 0.45), (0.45, -0.3, 1.0), 1.1, 0.08, 0.02, 60, segs=4, verts=6))
    for o in [trunk] + roots + stubs:
        L.paint(o, BARK, var=0.24, ao=0.45, zrange=(-0.1, 1.2), seed=5, hue_shift=BARK_DARK)
        _tint_up(o, L.mix(MOSS, LEAF_B, 0.4), 1.0, 0.2, freq=1.3, seed=6)
        L.set_mat(o, L.MAT_PAINTED)
    parts = [trunk, plate] + roots + stubs
    # splintered break at +X: pale spikes around the broken end
    for i in range(7):
        a = i / 7 * math.tau
        base = Vector((2.82, math.cos(a) * 0.17, 0.2 + math.sin(a) * 0.17))
        tip = base + Vector((random.uniform(0.12, 0.32), math.cos(a) * 0.04, math.sin(a) * 0.04))
        parts.append(_stick(base, tip, 0.065, WOOD_FRESH, r1=0.006, verts=4, seed=70 + i, hue_shift=END_GRAIN))
    parts.append(L.part("cyl", END_GRAIN, loc=(2.86, 0.0, 0.2), rot=(0, 90, 0), radius=0.22, depth=0.03, vertices=10,
                        jit=0.02, seed=77))
    parts += _clods(9, (-3.4, -2.6), (-1.0, 1.0), L.hexc("#4E4134"), r=(0.05, 0.1), z=0.03, seed=90)
    for i in range(7):  # soil clinging to the root plate
        a = i / 7 * math.tau + 0.2
        lump = L.prim("ico", loc=(-2.84 - 0.24 * (i % 2), math.cos(a) * 0.86, 0.66 + math.sin(a) * 0.7),
                      radius=random.uniform(0.14, 0.22), subdivisions=2, scale=(0.7, 1.0, 1.0))
        L.jitter(lump, 0.05, 3.0, 95 + i)
        parts.append(_finish_obj(lump, L.hexc("#54463A"), var=0.3, ao=0.3, zrange=(-0.2, 1.4), hue_shift=BARK_DARK,
                                 seed=95 + i))
    obj = L.join(parts, "ph_prop_fallen_log")
    L.finish(obj, "ph_prop_fallen_log", "props", 45, shift=False)


def bush():
    """Low shrub (~1.2 m wide): a few leafy clumps with mat_foliage over dark twigs."""
    L.reset(320)
    parts = []
    for i in range(5):  # twigs
        a = i / 5 * math.tau
        parts.append(_stick((0, 0, 0), (math.cos(a) * 0.3, math.sin(a) * 0.25, 0.42), 0.028, BARK_DARK, r1=0.01,
                            verts=4, seed=i))
    clumps = [((0.0, 0.06, 0.44), 0.38), ((-0.28, -0.06, 0.3), 0.3), ((0.29, -0.04, 0.29), 0.29),
              ((0.03, -0.22, 0.26), 0.25)]
    for i, (c, r) in enumerate(clumps):
        s = L.prim("ico", loc=c, radius=r, subdivisions=3, scale=(1.05, 1.0, 0.8))
        L.jitter(s, 0.09, 2.4, 10 + i)
        L.jitter(s, 0.03, 7.0, 20 + i)
        shade = random.random()
        L.paint(s, L.mix(LEAF_A, LEAF_B, 0.05 + shade * 0.45), var=0.35, ao=0.65, top=0.35, zrange=(0.0, 0.8),
                seed=10 + i, hue_shift=L.hexc("#6E7A45") if shade > 0.55 else None)
        L.set_mat(s, L.MAT_FOLIAGE)
        parts.append(s)
    obj = L.join(parts, "ph_env_bush")
    _center_xy(obj)
    L.finish(obj, "ph_env_bush", "environment", 50)


ASSETS = (corpse, corpse_02, corpse_03, corpse_04, corpse_shrouded, handcart, morgue_table, workbench,
          dropoff_bier, grave_plot_empty, grave_pit, wood_pile, stone_rubble, cross_wood, signpost, fallen_log, bush)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
