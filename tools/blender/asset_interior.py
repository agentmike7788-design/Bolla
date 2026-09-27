"""Hut interior, change round 2 (docs/VERTICAL_SLICE_DESIGN.md section 11), 'Gemaltes Diorama'.

The gravekeeper's room (ph_int_room) matches the exterior (asset_buildings.py): inner floor
4.6 x 3.6 m, walls 2.5 m high, door on the front wall at x = DOOR_X, window 1 in the back wall
(above the desk), window 2 in the left wall (above the bed), stove at the back right under the
chimney.  For the fixed 45 deg top-down camera the front wall (towards the camera, -Y) is only a
low stub with the door posts and there is no ceiling: rafters stubs rise from the back wall, one
tie beam carries the hanging lantern.

Furniture and decoration are separate models (pivot bottom centre, front -Y = Godot +Z, 1 unit
= 1 m); data/world/hut_interior_layout.json arranges them.  Markers (glTF empties):
  ph_int_room    door_inside, spawn_inside (floor), light_window_1 (back), light_window_2 (left),
                 light_ceiling (the hanging lantern)
  ph_int_stove   light_fire (in front of the fire opening)
  ph_int_desk    book (on the open grave register), light_candle
  ph_int_table, ph_int_candles   light_candle
Only the shared materials mat_painted and mat_emissive_warm are used (fire, flames, panes).

Run:  python tools/blender/build_all.py asset_interior
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
from asset_props_slice import _center_xy, _path_tube, _raw, _stick, _tint_up
import asset_buildings as B

CAT = "interior"

# --- palette (ART_DIRECTION.md section 3; warm, lamp-lit wood inside) ----------
WOOD = L.hexc("#6E5238")
WOOD_DARK = L.hexc("#4A3626")
WOOD_WARM = L.hexc("#7C5B3D")
WOOD_OLD = L.hexc("#6B5E50")
WOOD_LIGHT = L.hexc("#8E6E4E")
FLOOR = L.hexc("#6A4E36")
GAP = L.hexc("#1E1712")
STONE = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_WARM = L.hexc("#857C72")
IRON = L.hexc("#3A3C40")
IRON_DARK = L.hexc("#2A2B2E")
RUST = L.hexc("#6A4A3A")
BRASS = L.hexc("#8E7F55")
WAX = L.hexc("#E6D8B8")
CLAY = L.hexc("#8A5A44")
CERAMIC = L.hexc("#CFC6B0")
GLAZE_BLUE = L.hexc("#6C7788")
LINEN = L.hexc("#D2C8AE")
LINEN_DARK = L.hexc("#B5AA8E")
TICKING = L.hexc("#BDB39A")
STRAW = L.hexc("#C8B071")
WOOL = L.hexc("#8A6A48")
ROSE = L.hexc("#9C6F6A")
MOSSC = L.hexc("#6E7A55")
OCHRE = L.hexc("#B08C4E")
DRIED_RED = L.hexc("#8C2F2B")     # palette accent, sparsam: the ledger ribbon only
PAPER = L.hexc("#DCCFAE")
INK = L.hexc("#2A2420")
LEATHER = L.hexc("#4A3428")
LEATHER_DARK = L.hexc("#33241C")
BREAD = L.hexc("#A77A48")
SOUP = L.hexc("#9A7A4A")
GLASS_GREEN = L.hexc("#5E7A62")
GLASS_BROWN = L.hexc("#6A4A30")
HERB_GREEN = L.hexc("#7A8150")
SAGE = L.hexc("#8A9270")
LAVENDER = L.hexc("#8C7FA0")
YARROW = L.hexc("#CFC3A0")
STRING = L.hexc("#B9A77E")
HAT = L.hexc("#3B3430")          # the gravekeeper's colours (asset_character.py)
HAT_BAND = L.hexc("#6A4A2F")
SCARF = L.hexc("#B08A3E")
SCARF_DARK = L.hexc("#8A6A2E")
CAT_FUR = L.hexc("#4A4A50")
CAT_LIGHT = L.hexc("#6E6E74")
CAT_PINK = L.hexc("#8A6E6E")
WATER = L.hexc("#1F2A3A")

# --- room dimensions (inner faces), shared with the exterior -----------------------
RX, RY = 2.3, 1.8              # inner half extents: floor 4.6 x 3.6
WALL_H = B.H                   # 2.5 m, as outside
STUB_H = 0.36                  # the front wall towards the camera is only a stub
T = 0.07                       # wall board thickness
DOOR_X, DOOR_W, DOOR_H = B.DOOR_X, B.DOOR_W, B.DOOR_H
WIN_Z0, WIN_Z1 = B.WIN_Z0 - B.F, B.WIN_Z1 - B.F     # 0.9 .. 1.68 above the inner floor
WIN_BACK_X = B.WIN3_X          # back window (light_window_1)
WIN_LEFT_Y = B.WIN2_Y          # left window (light_window_2)
TIE_Y, TIE_Z = 1.2, 2.42       # tie beam across the room (carries the lantern and the herbs)
LANTERN_X = -0.85


# --- generic helpers ------------------------------------------------------------------

def _set(obj, color=None, mat: str = L.MAT_PAINTED, **pk):
    if color is not None:
        L.paint(obj, color, **pk)
    L.set_mat(obj, mat)
    return obj


def _box(loc, half, color, rot=(0, 0, 0), jit: float = 0.004, cuts: int = 0, bev: float = 0.0, seed: int = 0,
         **pk):
    o = L.prim("cube", loc=loc, rot=rot, scale=half)
    if bev > 0:
        L.bevel(o, bev, 1)
    if cuts:
        L.subdivide(o, cuts)
    if jit > 0:
        L.jitter(o, jit, 3.0, seed)
    return _set(o, color, seed=seed, **pk)


def _board(loc, half, color, seed: int = 0, rot=(0, 0, 0), **pk):
    """Hand-cut board: own colour variation, slight wobble."""
    return _box(loc, half, L.scale_c(color, random.uniform(0.88, 1.1)), rot=rot, jit=0.004, seed=seed, **pk)


def _lathe(profile, n: int = 12, name: str = "lathe", cap_bottom: bool = True, cap_top: bool = False):
    """Surface of revolution around Z from profile [(r, z)] (r = 0 -> pole). Outer surfaces go up,
    inner ones down (open vessels): faces point to the visible side."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-5:
            rings.append(bm.verts.new((0, 0, z)))
        else:
            rings.append([bm.verts.new((math.cos(i / n * math.tau) * r, math.sin(i / n * math.tau) * r, z))
                          for i in range(n)])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            if not isinstance(a, list):
                bm.faces.new((a, b[j], b[i]))
            elif not isinstance(b, list):
                bm.faces.new((a[i], a[j], b))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom and isinstance(rings[0], list):
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and isinstance(rings[-1], list):
        bm.faces.new(rings[-1])
    return _raw(bm, name)


def _at(obj, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Transform mesh data: scale, rotate (degrees XYZ), then translate."""
    m = (Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
         @ Matrix.Rotation(math.radians(rot[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot[0]), 4, "X")
         @ Matrix.Diagonal((*scale, 1)))
    obj.data.transform(m)
    return obj


def _sheet(nu: int, nv: int, fn, name: str = "sheet", flip: bool = False):
    """Parametric sheet: fn(u, v) -> Vector for u, v in 0..1 (cloth, pages, rugs)."""
    bm = bmesh.new()
    g = [[bm.verts.new(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            q = (g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1])
            bm.faces.new(tuple(reversed(q)) if flip else q)
    return _raw(bm, name)


def _slab(nu: int, nv: int, fn, th: float, name: str = "slab", normal_sign: float = 0.0):
    """Sheet with thickness and closed edges: quilts, rugs, pages.  The underside lies `th` below
    the surface along -Z, or - for draped cloth falling over an edge - along the surface normal
    normal_sign * (d/du x d/dv) (the sign picks the outer side)."""
    bm = bmesh.new()

    def under(u, v):
        p = fn(u, v)
        if normal_sign == 0.0:
            return p - Vector((0, 0, th))
        e = 1e-3
        n = (fn(min(1, u + e), v) - fn(max(0, u - e), v)).cross(fn(u, min(1, v + e)) - fn(u, max(0, v - e)))
        if n.length < 1e-9:
            return p - Vector((0, 0, th))
        return p - n.normalized() * (th * normal_sign)
    top = [[bm.verts.new(fn(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    bot = [[bm.verts.new(under(i / nu, j / nv)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((top[i][j], top[i + 1][j], top[i + 1][j + 1], top[i][j + 1]))
            bm.faces.new((bot[i][j], bot[i][j + 1], bot[i + 1][j + 1], bot[i + 1][j]))
    edge = [(i, 0) for i in range(nu)] + [(nu, j) for j in range(nv)] + \
           [(i, nv) for i in range(nu, 0, -1)] + [(0, j) for j in range(nv, 0, -1)]
    for k, (i, j) in enumerate(edge):
        i2, j2 = edge[(k + 1) % len(edge)]
        bm.faces.new((top[i][j], bot[i][j], bot[i2][j2], top[i2][j2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _raw(bm, name)


def _paint_poly(obj, fn, var: float = 0.08, ao: float = 0.0, top: float = 0.1, zr=None, freq: float = 4.0,
                seed: int = 0) -> None:
    """Vertex-paint every face corner with base colour fn(poly, co) (crisp patches, stripes),
    then noise, fake AO over zr and top light."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    zs = [v.co.z for v in me.vertices]
    z0, z1 = zr if zr else (min(zs), max(zs))
    off = Vector((seed * 3.7, seed * 1.9, seed * 5.3))
    for poly in me.polygons:
        up = max(0.0, poly.normal.z)
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            h = max(0.0, min(1.0, (co.z - z0) / max(1e-6, z1 - z0)))
            f = (1.0 + noise.noise(co * freq + off) * var) * (1.0 - ao * (1.0 - h) ** 2) * (1.0 + top * up)
            c = L.scale_c(fn(poly, co), f)
            attr.data[li].color = (L._to_lin(c[0]), L._to_lin(c[1]), L._to_lin(c[2]), 1.0)
    L.set_mat(obj, L.MAT_PAINTED)


def _flame(parts, pos, h: float = 0.05, r: float = 0.013) -> None:
    parts.append(L.part("cone", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(pos[0], pos[1], pos[2] + h / 2), radius1=r,
                        depth=h, vertices=6))


def _candle(parts, x: float, y: float, z: float, h: float, r: float = 0.022, seed: int = 0, drips: int = 2) -> Vector:
    """Wax candle with a melted top and a few drips; returns the flame base."""
    c = L.prim("cyl", loc=(x, y, z + h / 2), radius=r, depth=h, vertices=8)
    for v in c.data.vertices:
        if v.co.z > z + h * 0.6:
            v.co.z -= random.uniform(0.0, 0.012)
    _set(c, L.scale_c(WAX, random.uniform(0.94, 1.03)), var=0.08, ao=0.25, seed=seed)
    parts.append(c)
    for k in range(drips):
        a = random.uniform(0, math.tau)
        parts.append(_set(L.prim("sphere", loc=(x + math.cos(a) * r, y + math.sin(a) * r, z + h * random.uniform(0.45, 0.85)),
                                 radius=0.008, segments=5, ring_count=3, scale=(0.8, 0.8, 2.2)), WAX, ao=0.0))
    parts.append(L.part("cyl", INK, loc=(x, y, z + h + 0.004), radius=0.0025, depth=0.012, vertices=4))
    return Vector((x, y, z + h + 0.008))


def _done(parts, name: str, markers=(), smooth_angle: float = 40.0, center: bool = True, shift: bool = True) -> None:
    obj = L.join(parts, name)
    for m_name, loc in markers:
        L.marker(obj, m_name, loc)
    if center:
        _center_xy(obj)
    L.finish(obj, name, CAT, smooth_angle, shift=shift)


# --- room ---------------------------------------------------------------------------

def _paint_wall_board(obj, color, z0: float, z1: float, seed: int) -> None:
    """Inner wall board: vertical grain, darker at the floor (dust, shadow) and under the eaves."""
    off = Vector((seed * 1.3, seed * 2.1, 0))

    def fn(co, vi):
        h = max(0.0, min(1.0, (co.z - z0) / max(1e-6, z1 - z0)))
        g = noise.noise(Vector((co.x * 11, co.y * 11, co.z * 1.4)) + off) * 0.12
        return L.scale_c(color, (1.0 + g) * (0.62 + 0.38 * min(1.0, h * 3.0)) * (1.0 - 0.12 * max(0.0, h - 0.75) * 4))
    from asset_props_slice import _paint_fn
    _paint_fn(obj, fn)
    L.set_mat(obj, L.MAT_PAINTED)


def _wall_boards(parts, along: str, a0: float, a1: float, plane: float, inward: float, z_top: float, openings,
                 seed: int, width: float = 0.22) -> None:
    """Vertical boards of an inner wall face at `plane` (inner face), `inward` = direction into
    the room; openings = [(c0, c1, z0, z1)]."""
    n = max(2, round((a1 - a0) / width))
    step = (a1 - a0) / n
    for i in range(n):
        b0, b1 = a0 + i * step + 0.006, a0 + (i + 1) * step - 0.006
        c = (b0 + b1) / 2
        spans = [(0.0, z_top)]
        for op in openings:
            if b1 > op[0] and b0 < op[1]:
                spans = [(0.0, op[2]), (op[3], z_top)]
        col = L.scale_c(random.choice((WOOD_WARM, WOOD_WARM, WOOD, WOOD_LIGHT)), random.uniform(0.9, 1.08))
        for k, (z0, z1) in enumerate(spans):
            if z1 - z0 < 0.02:
                continue
            zt = z1 + (random.uniform(-0.02, 0.0) if z1 >= z_top - 0.01 else 0.0)
            if along == "x":
                o = L.prim("cube", loc=(c, plane - inward * T / 2, (z0 + zt) / 2), scale=((b1 - b0) / 2, T / 2, (zt - z0) / 2))
            else:
                o = L.prim("cube", loc=(plane - inward * T / 2, c, (z0 + zt) / 2), scale=(T / 2, (b1 - b0) / 2, (zt - z0) / 2))
            L.jitter(o, 0.003, 3.0, seed + i)
            _paint_wall_board(o, col, 0.0, WALL_H, seed + i + k * 50)
            parts.append(o)


def _floor(parts) -> None:
    """Worn wide planks along X over a dark subfloor (the gaps), a trodden path from the door."""
    parts.append(_box((0, 0, -0.03), (RX + 0.02, RY + 0.02, 0.02), GAP, jit=0.0, var=0.05, ao=0.0, top=0.0))
    rows = 12
    w = (2 * RY) / rows
    path = [Vector((DOOR_X, -RY, 0)), Vector((-0.4, -0.3, 0)), Vector((0.5, 0.55, 0)), Vector((1.6, 0.7, 0))]

    def worn(p):
        d = 9.0
        for a, b in zip(path, path[1:]):
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            d = min(d, (p - (a + ab * t)).length)
        return math.exp(-(d / 0.55) ** 2)
    for r in range(rows):
        y0, y1 = -RY + r * w + 0.006, -RY + (r + 1) * w - 0.006
        cut = random.uniform(-1.2, 1.2)
        for k, (x0, x1) in enumerate(((-RX, cut - 0.004), (cut + 0.004, RX))):
            base = L.scale_c(random.choice((FLOOR, FLOOR, WOOD, WOOD_OLD)), random.uniform(0.88, 1.1))
            seed = r * 5 + k
            off = Vector((seed * 1.7, seed * 0.3, 0))
            nx = max(2, int((x1 - x0) / 0.3))
            bm = bmesh.new()
            vs = [[bm.verts.new((x0 + (x1 - x0) * i / nx, y, random.uniform(-0.004, 0.0))) for y in (y0, y1)]
                  for i in range(nx + 1)]
            for i in range(nx):
                bm.faces.new((vs[i][0], vs[i + 1][0], vs[i + 1][1], vs[i][1]))
            # the cut end of each board: a thin dark edge face (reads as the joint)
            b = _raw(bm, "board")

            def col(co, vi, base=base, off=off):
                p = Vector((co.x, co.y, 0))
                dw = min(RX - abs(co.x), RY - abs(co.y))
                aof = 0.66 + 0.34 * min(1.0, dw / 0.7)
                g = noise.noise(Vector((co.x * 1.6, co.y * 14.0, 0.5)) + off) * 0.1
                c = L.scale_c(base, (1.0 + g) * aof * (1.0 + 0.16 * worn(p)))
                return L.mix(c, L.hexc("#8C7458"), 0.25 * worn(p))
            from asset_props_slice import _paint_fn
            _paint_fn(b, col)
            L.set_mat(b, L.MAT_PAINTED)
            parts.append(b)
            # a few nail heads at the joists
            for x in (x0 + 0.1, x1 - 0.1):
                if random.random() < 0.5:
                    parts.append(L.part("cube", IRON_DARK, loc=(x, (y0 + y1) / 2 + random.uniform(-0.06, 0.06), 0.001),
                                        scale=(0.008, 0.008, 0.002)))


def _plinth(parts) -> None:
    """The diorama cut: rough foundation stones around the floor (front and sides visible)."""
    def course(a0, a1, along, plane, out, seed):
        a = a0
        k = 0
        while a < a1 - 0.05:
            ln = min(random.uniform(0.28, 0.5), a1 - a)
            c = a + ln / 2
            d = random.uniform(0.05, 0.065)
            hh = 0.18 * random.uniform(0.8, 1.0)
            if along == "x":
                loc, half = (c, plane + out * d, -0.2 + (0.18 - hh)), (ln / 2 * 0.95, d, hh)
            else:
                loc, half = (plane + out * d, c, -0.2 + (0.18 - hh)), (d, ln / 2 * 0.95, hh)
            s = L.prim("cube", loc=loc, scale=half, rot=(random.uniform(-3, 3), random.uniform(-3, 3), 0))
            L.jitter(s, 0.018, 4.0, seed + k)
            col = random.choice((STONE, STONE_DARK, STONE_DARK, STONE_WARM))
            L.paint(s, L.scale_c(L.mix(col, L.hexc("#4A3E34"), 0.4), random.uniform(0.42, 0.56)), var=0.25, ao=0.55,
                    top=0.0, zrange=(-0.4, 0.0), seed=seed + k)
            L.set_mat(s, L.MAT_PAINTED)
            parts.append(s)
            a += ln
            k += 1
    course(-RX - T - 0.1, RX + T + 0.1, "x", -RY - T, -1, 10)
    course(-RY - T, RY + T, "y", -RX - T, -1, 40)
    course(-RY - T, RY + T, "y", RX + T, 1, 70)
    parts.append(_box((0, RY + T + 0.06, -0.19), (RX + T + 0.1, 0.06, 0.19), STONE_DARK, jit=0.01, seed=90, ao=0.4))


def _window_in(parts, c: Vector, axis: str, inward: float, w: float, seed: int, curtains: bool = True) -> None:
    """Inside of a window: warm pane, deep sill, frame, muntins and two tied-back curtains."""
    hz = (WIN_Z1 - WIN_Z0) / 2
    cz = (WIN_Z0 + WIN_Z1) / 2

    def at(a, n, z):  # along-wall a, into the room n, height z
        return Vector((c.x + a, c.y + inward * n, z)) if axis == "x" else Vector((c.x + inward * n, c.y + a, z))

    def half(a, n, z):
        return (a, n, z) if axis == "x" else (n, a, z)
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=at(0, -T * 0.6, cz), scale=half(w / 2, 0.01, hz)))
    for sa in (-1, 1):
        parts.append(_board(at(sa * (w / 2 + 0.03), 0.01, cz), half(0.035, 0.03, hz + 0.05), WOOD_DARK, seed=seed + sa))
    parts.append(_board(at(0, 0.01, WIN_Z1 + 0.03), half(w / 2 + 0.07, 0.03, 0.035), WOOD_DARK, seed=seed + 2))
    parts.append(_board(at(0, 0.06, WIN_Z0 - 0.02), half(w / 2 + 0.1, 0.1, 0.022), WOOD_WARM, seed=seed + 3))
    parts.append(_board(at(0, 0.02, WIN_Z0 - 0.09), half(w / 2 + 0.02, 0.02, 0.05), WOOD_DARK, seed=seed + 4))
    parts.append(L.part("cube", WOOD_DARK, loc=at(0, -T * 0.4, cz), scale=half(w / 2, 0.015, 0.018)))
    parts.append(L.part("cube", WOOD_DARK, loc=at(0, -T * 0.4, cz), scale=half(0.018, 0.015, hz)))
    if not curtains:
        return
    # rod + two gathered curtain panels, checked linen, tied back at the sill
    parts.append(_stick(at(-w / 2 - 0.16, 0.06, WIN_Z1 + 0.1), at(w / 2 + 0.16, 0.06, WIN_Z1 + 0.1), 0.012, WOOD_DARK,
                        verts=5))
    for sa in (-1, 1):
        a0 = sa * (w / 2 + 0.12)
        def fn(u, v, a0=a0, sa=sa):
            z = WIN_Z1 + 0.09 - u * (WIN_Z1 - WIN_Z0 + 0.12)
            tie = math.exp(-((u - 0.72) / 0.12) ** 2)
            width = 0.2 * (1.0 - 0.55 * tie) + 0.04 * u
            a = a0 - sa * 0.02 + (v - 0.5) * width * 2 * sa * -1 + sa * 0.03 * tie
            n = 0.06 + 0.025 * math.sin(v * math.tau * 2.5) + 0.02 * tie
            return at(a, n, z)
        cur = _sheet(6, 5, fn, "curtain", flip=(sa > 0) != (axis == "y"))
        cur2 = _sheet(6, 5, fn, "curtain_b", flip=(sa < 0) != (axis == "y"))
        for o in (cur, cur2):
            _paint_poly(o, lambda poly, co, sa=sa: LINEN if (int((co.z) * 18) + int((co.x + co.y) * 18)) % 2 else
                        L.mix(LINEN, ROSE, 0.55), var=0.06, ao=0.0, top=0.05, seed=seed)
            parts.append(o)
        parts.append(L.part("torus", ROSE, loc=at(a0 + sa * 0.01, 0.075, WIN_Z1 + 0.09 - 0.72 * (WIN_Z1 - WIN_Z0 + 0.12)),
                            rot=(0, 0, 0) if axis == "x" else (0, 0, 90), major_radius=0.05, minor_radius=0.012,
                            major_segments=6, minor_segments=3))


def _hanging_lantern(parts, x: float, y: float, z_top: float) -> Vector:
    """Iron lantern on a short chain under the tie beam; returns the light position."""
    parts.append(_stick((x, y, z_top), (x, y, z_top - 0.42), 0.008, IRON, verts=4))
    for k in range(4):
        parts.append(L.part("torus", IRON, loc=(x, y, z_top - 0.06 - k * 0.09), rot=(90, 0, 90 * (k % 2)),
                            major_radius=0.022, minor_radius=0.005, major_segments=6, minor_segments=3))
    zc = z_top - 0.6
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(x, y, zc), scale=(0.06, 0.06, 0.09)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(x + sx * 0.064, y + sy * 0.064, zc), scale=(0.009, 0.009, 0.1)))
    parts.append(L.part("cube", IRON, loc=(x, y, zc - 0.1), scale=(0.078, 0.078, 0.014)))
    parts.append(L.part("cone", IRON, loc=(x, y, zc + 0.14), vertices=4, radius1=0.1, radius2=0.02, depth=0.1,
                        rot=(0, 0, 45)))
    parts.append(L.part("torus", IRON, loc=(x, y, zc + 0.2), rot=(90, 0, 0), major_radius=0.025, minor_radius=0.006,
                        major_segments=6, minor_segments=3))
    return Vector((x, y, zc - 0.13))


def room():
    """The gravekeeper's room: floor, three plank walls + front stub, timber frame, windows,
    door posts, rafters stubs at the back, tie beam with the hanging lantern, a door mat."""
    L.reset(400)
    parts = []
    _floor(parts)
    _plinth(parts)
    hb = 0.8
    hl = 0.7
    back_open = [(WIN_BACK_X - hb / 2 - 0.02, WIN_BACK_X + hb / 2 + 0.02, WIN_Z0, WIN_Z1)]
    left_open = [(WIN_LEFT_Y - hl / 2 - 0.02, WIN_LEFT_Y + hl / 2 + 0.02, WIN_Z0, WIN_Z1)]
    door_open = [(DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2, 0.0, STUB_H + 1.0)]
    _wall_boards(parts, "x", -RX - T, RX + T, RY, -1, WALL_H, back_open, 100)
    _wall_boards(parts, "y", -RY, RY, -RX, 1, WALL_H, left_open, 200)
    _wall_boards(parts, "y", -RY, RY, RX, -1, WALL_H, [], 300)
    _wall_boards(parts, "x", -RX - T, RX + T, -RY, 1, STUB_H, door_open, 400)
    # timber frame
    for sx in (-1, 1):
        parts.append(B._beam((sx * (RX - 0.02), RY - 0.02, 0), (sx * (RX - 0.02), RY - 0.02, WALL_H + 0.04), 0.075, 0.075,
                             color=WOOD_DARK, seed=5 + sx))
        parts.append(B._beam((sx * (RX - 0.02), -RY + 0.02, 0), (sx * (RX - 0.02), -RY + 0.02, STUB_H + 0.3), 0.075,
                             0.075, color=WOOD_DARK, seed=7 + sx))  # front corner posts, cut like the stub
        parts.append(B._beam((sx * (RX - 0.04), -RY, WALL_H - 0.02), (sx * (RX - 0.04), RY, WALL_H - 0.02), 0.05, 0.06,
                             color=WOOD_DARK, seed=9 + sx))
        parts.append(B._beam((sx * (RX - 0.035), -RY, 0.06), (sx * (RX - 0.035), RY, 0.06), 0.035, 0.06,
                             color=WOOD_DARK, seed=11 + sx))
    parts.append(B._beam((-RX, RY - 0.04, WALL_H - 0.02), (RX, RY - 0.04, WALL_H - 0.02), 0.05, 0.06, color=WOOD_DARK,
                         seed=13))
    parts.append(B._beam((-RX, RY - 0.035, 0.06), (RX, RY - 0.035, 0.06), 0.035, 0.06, color=WOOD_DARK, seed=14))
    parts.append(B._beam((-1.3, RY - 0.03, 0), (-1.3, RY - 0.03, WALL_H), 0.06, 0.06, color=WOOD_DARK, seed=15))
    for sx in (-1, 1):  # mid posts on the side walls
        parts.append(B._beam((sx * (RX - 0.03), -0.35, 0), (sx * (RX - 0.03), -0.35, WALL_H), 0.055, 0.055,
                             color=WOOD_DARK, seed=17 + sx))
    # front stub: cap board, door posts, threshold, door mat
    for a0, a1 in ((-RX - T, DOOR_X - DOOR_W / 2 - 0.07), (DOOR_X + DOOR_W / 2 + 0.07, RX + T)):
        parts.append(_board(((a0 + a1) / 2, -RY - T / 2, STUB_H + 0.02), ((a1 - a0) / 2, T / 2 + 0.03, 0.025), WOOD_DARK,
                            seed=20))
    for sx in (-1, 1):
        x = DOOR_X + sx * (DOOR_W / 2 + 0.06)
        parts.append(B._beam((x, -RY - T / 2, 0), (x, -RY - T / 2, 0.95), 0.06, 0.06, color=WOOD_DARK, seed=22 + sx))
        parts.append(_set(L.prim("cone", loc=(x, -RY - T / 2, 0.98), rot=(0, 0, 45), vertices=4, radius1=0.085,
                                 depth=0.06), WOOD_DARK, var=0.1, ao=0.0))  # cut top of the (cut away) door post
    parts.append(_board((DOOR_X, -RY - T / 2, 0.012), (DOOR_W / 2 + 0.04, T / 2 + 0.03, 0.014), WOOD_OLD, seed=25))

    def mat_fn(u, v):
        return Vector((DOOR_X + (u - 0.5) * 0.78, -RY + 0.24 + (v - 0.5) * 0.44, 0.012 + 0.003 * math.sin(u * 13 + v * 7)))
    mat = _slab(8, 4, mat_fn, 0.01, "doormat")
    _paint_poly(mat, lambda poly, co: L.hexc("#7E6848") if int((co.x - DOOR_X + 1) * 12) % 3 else L.hexc("#5E4C36"),
                var=0.1,
                ao=0.0, top=0.0, seed=26)
    parts.append(mat)
    # windows (inside)
    _window_in(parts, Vector((WIN_BACK_X, RY, 0)), "x", -1, 0.8, 30)
    _window_in(parts, Vector((-RX, WIN_LEFT_Y, 0)), "y", 1, 0.7, 40)
    # rafter stubs rising from the back wall towards the (cut away) ridge
    pitch = B.PITCH
    for i, x in enumerate((-RX + 0.1, -1.15, 0.0, 1.15, RX - 0.1)):
        p0 = Vector((x, RY + 0.02, WALL_H - 0.02))
        p1 = p0 + Vector((0, -math.cos(pitch), math.sin(pitch))) * 0.85
        r = L.prim("cube", loc=(p0 + p1) / 2, scale=(0.045, 0.43, 0.06), rot=(-math.degrees(pitch), 0, 0))
        L.jitter(r, 0.006, 3.0, 50 + i)
        parts.append(_set(r, WOOD_DARK, var=0.16, ao=0.2, seed=50 + i))
    # tie beam across the room (rests on the side top plates) with the hanging lantern
    parts.append(B._beam((-RX, TIE_Y, TIE_Z), (RX, TIE_Y, TIE_Z), 0.065, 0.075, color=WOOD_DARK, seed=70))
    light = _hanging_lantern(parts, LANTERN_X, TIE_Y, TIE_Z - 0.075)
    # small lived-in details on the walls: pegs, a pinned note near the desk, a calendar board
    for i, (x, z) in enumerate(((0.85, 1.4), (0.95, 1.22), (-0.72, 1.28))):
        n = L.prim("cube", loc=(x, RY - 0.002, z), scale=(0.07, 0.003, 0.09), rot=(0, random.uniform(-8, 8), 0))
        parts.append(_set(n, L.scale_c(PAPER, random.uniform(0.9, 1.0)), var=0.05, ao=0.0, top=0.0))
        parts.append(L.part("cube", IRON_DARK, loc=(x, RY - 0.006, z + 0.075), scale=(0.006, 0.003, 0.006)))
    for i, y in enumerate((1.0, 1.25)):
        parts.append(_stick((RX, y, 1.6), (RX - 0.1, y, 1.64), 0.014, WOOD_DARK, verts=5))
    obj_markers = [
        ("door_inside", (DOOR_X, -RY + 0.4, 0.0)),
        ("spawn_inside", (DOOR_X, -RY + 0.8, 0.0)),
        ("light_window_1", (WIN_BACK_X, RY - 0.45, (WIN_Z0 + WIN_Z1) / 2)),
        ("light_window_2", (-RX + 0.45, WIN_LEFT_Y, (WIN_Z0 + WIN_Z1) / 2)),
        ("light_ceiling", tuple(light)),
    ]
    _done(parts, "ph_int_room", obj_markers, 35, center=False, shift=False)


# --- bed --------------------------------------------------------------------------------

def bed():
    """Wooden bed (2.0 x 1.0 m, head at +X): straw mattress, patched quilt draped over the front,
    a plump pillow, a folded wool blanket at the foot."""
    L.reset(410)
    parts = []
    lx, ly = 0.98, 0.48
    rail_z = 0.34
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 1.02 if sx > 0 else 0.68
            post = L.prim("cube", loc=(sx * lx, sy * ly, h / 2), scale=(0.05, 0.05, h / 2))
            L.subdivide(post, 1)
            L.jitter(post, 0.005, 3.0, 1 + sx + sy)
            parts.append(_set(post, WOOD_DARK, var=0.15, ao=0.45, zrange=(0, 1.0), seed=2))
            parts.append(_set(L.prim("sphere", loc=(sx * lx, sy * ly, h + 0.03), radius=0.06, segments=8, ring_count=5,
                                     scale=(1, 1, 0.8)), WOOD_DARK, var=0.1, ao=0.0, seed=3))
    for sy in (-1, 1):  # side rails
        parts.append(_board((0, sy * ly, rail_z), (lx - 0.04, 0.03, 0.08), WOOD, seed=10 + sy, zrange=(0, 1.0)))
    for sx in (-1, 1):  # end rails
        parts.append(_board((sx * lx, 0, rail_z), (0.03, ly - 0.04, 0.08), WOOD, seed=12 + sx, zrange=(0, 1.0)))
    # headboard (+X): three planks with a gently arched top rail; footboard lower
    for k in range(3):
        y = -0.3 + k * 0.3
        parts.append(_board((lx, y, 0.66), (0.022, 0.145, 0.22), WOOD_WARM, seed=20 + k, zrange=(0, 1.0)))
    top = L.tube((lx, -ly, 0.9), (lx, ly, 0.9), 0.04, 6)
    L.subdivide(top, 2)
    for v in top.data.vertices:
        v.co.z += 0.06 * (1 - (v.co.y / ly) ** 2)
    parts.append(_set(top, WOOD_DARK, var=0.12, ao=0.0, seed=23))
    parts.append(_board((-lx, 0, 0.53), (0.022, ly - 0.05, 0.1), WOOD_WARM, seed=24, zrange=(0, 1.0)))
    for k in range(5):  # slats (seen under the quilt edge)
        parts.append(_board((-0.8 + k * 0.4, 0, rail_z + 0.06), (0.05, ly - 0.03, 0.012), WOOD_OLD, seed=30 + k))
    # straw mattress: rounded ticking with straw poking out of the seam
    m = L.prim("cube", loc=(0, 0, rail_z + 0.16), scale=(lx - 0.05, ly - 0.05, 0.09))
    L.bevel(m, 0.06, 2)
    L.jitter(m, 0.015, 3.0, 40)
    _paint_poly(m, lambda poly, co: TICKING if int(co.y * 22) % 2 else L.scale_c(TICKING, 0.86), var=0.08, ao=0.2,
                top=0.1, zr=(rail_z, rail_z + 0.3), seed=40)
    parts.append(m)
    mz = rail_z + 0.25  # mattress top
    for i in range(12):
        sy = random.choice((-1, 1))
        x = random.uniform(-lx + 0.1, lx - 0.1) if sy > 0 else random.uniform(0.6, lx - 0.1)  # not under the quilt
        parts.append(L.part("cone", STRAW, loc=(x, sy * (ly - 0.03), mz - 0.08), radius1=0.012, depth=0.07, vertices=3,
                            rot=(sy * -70 + random.uniform(-20, 20), random.uniform(-30, 30), 0)))
    # quilt: patchwork, covers the foot two thirds and falls over the front (-Y) edge
    qx0, qx1 = -lx + 0.02, 0.5

    def qfn(u, v):
        x = qx0 + (qx1 - qx0) * u
        yy = ly + 0.02 - v * (2 * ly + 0.3)
        if yy > -ly + 0.02:
            fade = min(1.0, (yy + ly - 0.02) / 0.25)  # the wave dies out before the quilt tips over the edge
            z = mz + 0.03 + 0.03 * math.sin(u * 7.0 + v * 4.0) * (1 - abs(v - 0.4)) * fade
            y = yy
        else:  # over the edge: falls down
            d = (-ly + 0.02) - yy
            k = min(1.0, d / 0.12)
            y = -ly + 0.02 - 0.1 * (1.0 - math.exp(-d / 0.04)) - 0.012 * math.sin(u * 9.0) * k  # clear of the rail
            z = mz + 0.03 - d * 1.6
        return Vector((x + 0.02 * math.sin(v * 6.0), y, z))
    quilt = _slab(10, 9, qfn, 0.025, "quilt", normal_sign=-1.0)  # u = +X, v = back -> front: -(du x dv) = out
    patches = (ROSE, MOSSC, OCHRE, LINEN_DARK, GLAZE_BLUE, WOOL)
    pr = random.Random(7)
    grid = {(i, j): pr.choice(patches) for i in range(8) for j in range(6)}
    def qcol(poly, co):  # patches = 2 x 2 cells of the quilt grid (_slab faces: top/bottom pairs per cell)
        if poly.index >= 2 * 10 * 9:
            return L.scale_c(WOOL, 0.9)  # the bound edge
        cell = poly.index // 2
        return grid[((cell // 9) // 2 % 8, (cell % 9) // 2 % 6)]
    _paint_poly(quilt, qcol, var=0.1, ao=0.25, top=0.12, zr=(0.1, mz + 0.06), seed=41)
    parts.append(quilt)
    # turned-down sheet edge at the head side of the quilt
    parts.append(_box((qx1 + 0.02, 0, mz + 0.045), (0.05, ly - 0.02, 0.022), LINEN, bev=0.015, seed=42, ao=0.1))
    # pillow
    p = L.prim("sphere", loc=(lx - 0.24, 0.0, mz + 0.07), radius=1.0, segments=10, ring_count=6,
               scale=(0.17, 0.36, 0.085))
    L.jitter(p, 0.012, 5.0, 43)
    for v in p.data.vertices:  # a dent where the head was
        d = math.hypot(v.co.x - (lx - 0.24), v.co.y)
        if v.co.z > mz + 0.1:
            v.co.z -= 0.03 * math.exp(-(d / 0.12) ** 2)
    parts.append(_set(p, LINEN, var=0.06, ao=0.2, top=0.15, seed=43))
    # folded wool blanket at the foot: a soft stack with a rounded fold and a woven stripe
    fx0, fx1 = -lx + 0.1, -lx + 0.4

    def blanket(u, v):
        x = fx0 + (fx1 - fx0) * u
        y = -0.22 + 0.46 * v
        bulge = 0.018 * math.sin(math.pi * u) * math.sin(math.pi * v)
        return Vector((x, y + 0.015 * math.sin(u * 5), mz + 0.1 + bulge))
    bl = _slab(6, 8, blanket, 0.085, "blanket")
    L.jitter(bl, 0.006, 5.0, 44)
    check = L.mix(MOSSC, WOOL, 0.35)
    _paint_poly(bl, lambda poly, co: (OCHRE if (int((co.x + 2) * 20) + int((co.y + 2) * 20)) % 2 else check)
                if poly.normal.z > 0.5 else L.scale_c(check, 0.8), var=0.1, ao=0.0, top=0.15, seed=44)
    parts.append(bl)
    fold = L.prim("cyl", loc=(fx1, 0.01, mz + 0.058), rot=(90, 0, 0), radius=0.043, depth=0.45, vertices=8)
    parts.append(_set(fold, L.scale_c(L.mix(MOSSC, WOOL, 0.35), 0.9), var=0.1, ao=0.0, top=0.15, seed=45))
    _done(parts, "ph_int_bed", (), 40)


# --- stove -------------------------------------------------------------------------------

STOVE_BACK = 0.45   # the pipe elbow ends this far behind the hearth centre (against the wall)


def stove():
    """Small cast-iron stove on a stone hearth: curved legs, glowing fire opening with an open
    door and logs, hob with a kettle, pipe up and into the back wall, poker and a few logs."""
    L.reset(420)
    parts = []
    # hearth: flat stone slabs
    hx, hy = 0.5, 0.4
    for i in range(3):
        for j in range(2):
            x0 = -hx + i * (2 * hx / 3)
            y0 = -hy + j * hy
            s = L.prim("cube", loc=(x0 + hx / 3, y0 + hy / 2, 0.03), scale=(hx / 3 * 0.97, hy / 2 * 0.96, 0.03),
                       rot=(0, 0, random.uniform(-2, 2)))
            L.jitter(s, 0.008, 4.0, i * 2 + j)
            L.paint(s, L.scale_c(random.choice((STONE, STONE_DARK, STONE_WARM)), random.uniform(0.8, 0.95)), var=0.2,
                    ao=0.2, top=0.08, seed=i * 2 + j)
            L.set_mat(s, L.MAT_PAINTED)
            parts.append(s)
    # body
    bx, by, z0, z1 = 0.29, 0.23, 0.2, 0.74
    body = L.prim("cube", loc=(0, 0.02, (z0 + z1) / 2), scale=(bx, by, (z1 - z0) / 2))
    L.bevel(body, 0.03, 1)
    L.jitter(body, 0.004, 3.0, 10)
    parts.append(_set(body, IRON, var=0.18, ao=0.25, top=0.12, zrange=(0, 1.2), seed=10, hue_shift=RUST))
    parts.append(_box((0, 0.02, z1 + 0.02), (bx + 0.035, by + 0.035, 0.022), IRON_DARK, bev=0.01, seed=11))
    parts.append(_box((0, 0.02, z0 - 0.02), (bx + 0.025, by + 0.025, 0.02), IRON_DARK, bev=0.008, seed=12))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_stick((sx * (bx - 0.04), 0.02 + sy * (by - 0.04), z0 - 0.03),
                                (sx * (bx + 0.02), 0.02 + sy * (by + 0.02), 0.06), 0.022, IRON_DARK, r1=0.016, verts=5))
            parts.append(_set(L.prim("sphere", loc=(sx * (bx + 0.025), 0.02 + sy * (by + 0.025), 0.07), radius=0.024,
                                     segments=6, ring_count=4, scale=(1, 1, 0.6)), IRON_DARK, ao=0.0))
    # fire opening (front, -Y): warm glow, flames licking over two dark logs, an iron frame;
    # the little door stands wide open to the right
    fy = 0.02 - by - 0.004
    fz = 0.45
    ow, oh = 0.17, 0.12
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(0, fy + 0.02, fz), scale=(ow, 0.01, oh)))
    arch = L.prim("cyl", loc=(0, fy + 0.02, fz + oh), rot=(90, 0, 0), radius=ow, depth=0.02, vertices=12)
    for v in arch.data.vertices:
        v.co.z = max(fz + oh, fz + oh + (v.co.z - fz - oh) * 0.45)
    parts.append(_set(arch, (1, 1, 1), mat=L.MAT_EMISSIVE))
    for k, (x, h) in enumerate(((-0.08, 0.13), (0.0, 0.17), (0.08, 0.12), (-0.03, 0.1))):
        parts.append(L.part("cone", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(x, fy + 0.005, fz - oh + 0.05 + h / 2),
                            radius1=0.035, depth=h, vertices=5))
    for k, (x, r) in enumerate(((-0.06, 0.03), (0.06, 0.028))):
        lg = L.prim("cyl", loc=(x, fy - 0.002, fz - oh + 0.035), rot=(0, 90, 12 - 24 * k), radius=r, depth=0.2,
                    vertices=6)
        parts.append(_set(lg, L.hexc("#1E1410"), var=0.1, ao=0.0))
    frame = [(0, fz - oh - 0.02, ow + 0.03, 0.022), (-ow - 0.02, fz + 0.02, 0.022, oh + 0.03),
             (ow + 0.02, fz + 0.02, 0.022, oh + 0.03)]
    for (x, z, sx, sz) in frame:
        parts.append(_box((x, fy - 0.012, z), (sx, 0.014, sz), IRON_DARK, jit=0.0))
    rim = _path_tube([(-ow - 0.02, fy - 0.012, fz + oh + 0.03)] +
                     [(math.cos(math.pi * (1 - t / 6)) * (ow + 0.02), fy - 0.012,
                       fz + oh + 0.03 + math.sin(math.pi * t / 6) * (ow + 0.02) * 0.45) for t in range(1, 6)] +
                     [(ow + 0.02, fy - 0.012, fz + oh + 0.03)], 0.016, 4, hint=(0, 1, 0))
    parts.append(_set(rim, IRON_DARK, var=0.1, ao=0.0))
    door = L.prim("cube", loc=(0.0, 0.0, 0.0), scale=(0.17, 0.012, 0.15))
    L.bevel(door, 0.01, 1)
    _at(door, (ow + 0.035 + math.cos(math.radians(70)) * 0.17, fy - math.sin(math.radians(70)) * 0.17, fz + 0.02),
        (0, 0, 70))
    parts.append(_set(door, IRON, var=0.2, ao=0.0, top=0.15, seed=13, hue_shift=RUST))
    parts.append(_stick((ow + 0.12, fy - 0.33, fz + 0.02), (ow + 0.14, fy - 0.37, fz + 0.02), 0.011, BRASS, verts=4))
    parts.append(_stick((-bx + 0.02, fy - 0.03, z1 - 0.05), (bx - 0.02, fy - 0.03, z1 - 0.05), 0.01, BRASS, verts=5))
    # ash drawer below with a faint ember line and a draught slider
    parts.append(_box((0, fy - 0.005, 0.26), (0.17, 0.012, 0.03), IRON_DARK, jit=0.0))
    parts.append(_stick((-0.04, fy - 0.03, 0.26), (0.04, fy - 0.03, 0.26), 0.008, BRASS, verts=4))
    # hob rings on the top plate
    for x in (-0.12, 0.12):
        parts.append(L.part("torus", IRON_DARK, loc=(x, 0.02, z1 + 0.045), major_radius=0.085, minor_radius=0.01,
                            major_segments=10, minor_segments=3))
    # kettle on the left ring
    kx, kz = -0.12, z1 + 0.045
    k = _lathe([(0.06, 0.0), (0.095, 0.02), (0.11, 0.06), (0.1, 0.11), (0.06, 0.14), (0.028, 0.15), (0.0, 0.155)],
               12, "kettle")
    _at(k, (kx, 0.02, kz))
    parts.append(_set(k, L.hexc("#5A5048"), var=0.16, ao=0.35, top=0.2, seed=14, hue_shift=L.hexc("#6E5E4E")))
    parts.append(_set(L.prim("sphere", loc=(kx, 0.02, kz + 0.165), radius=0.018, segments=6, ring_count=4), BRASS))
    spout = L.tube((kx - 0.08, 0.02, kz + 0.07), (kx - 0.17, 0.02, kz + 0.14), 0.017, 6, r_end=0.009)
    parts.append(_set(spout, L.hexc("#5A5048"), var=0.1, ao=0.0))
    handle = _path_tube([(kx + 0.07, 0.02, kz + 0.12), (kx + 0.06, 0.02, kz + 0.22), (kx, 0.02, kz + 0.25),
                         (kx - 0.06, 0.02, kz + 0.22), (kx - 0.07, 0.02, kz + 0.12)], 0.008, 4, hint=(0, 1, 0))
    parts.append(_set(handle, IRON_DARK, ao=0.0))
    # a little steam puff above the spout? no - keep it quiet. Pipe: up, elbow, into the wall
    px, py = 0.12, 0.08
    pz1 = 2.2
    parts.append(_set(L.tube((px, py, z1 + 0.04), (px, py, pz1), 0.065, 10), IRON_DARK, var=0.2, ao=0.0, top=0.1,
                      hue_shift=RUST))
    for z in (z1 + 0.5, 1.5, 2.0):
        parts.append(L.part("cyl", IRON, loc=(px, py, z), radius=0.072, depth=0.03, vertices=10))
    parts.append(L.part("cyl", IRON, loc=(px, py, z1 + 0.34), rot=(0, 90, 0), radius=0.012, depth=0.18, vertices=4))
    parts.append(_set(L.prim("sphere", loc=(px, py, pz1), radius=0.07, segments=10, ring_count=6), IRON_DARK, var=0.15,
                      ao=0.0))
    parts.append(_set(L.tube((px, py, pz1), (px, STOVE_BACK - 0.03, pz1 + 0.04), 0.065, 10), IRON_DARK, var=0.2,
                      ao=0.0, hue_shift=RUST))
    parts.append(_box((px, STOVE_BACK - 0.015, pz1 + 0.04), (0.13, 0.015, 0.13), IRON, jit=0.0, var=0.2, ao=0.0))
    # poker and a small log basket on the hearth
    parts.append(_stick((0.43, -0.3, 0.06), (0.4, -0.12, 0.62), 0.009, IRON_DARK, verts=4))
    parts.append(L.part("torus", IRON_DARK, loc=(0.4, -0.12, 0.66), rot=(90, 0, 0), major_radius=0.03, minor_radius=0.007,
                        major_segments=6, minor_segments=3))
    for i, (x, y, z, r) in enumerate(((-0.41, -0.16, 0.1, 0.045), (-0.41, 0.0, 0.1, 0.042), (-0.41, -0.08, 0.18, 0.04))):
        lg = L.prim("cyl", loc=(x, y, z), rot=(90, 0, random.uniform(-8, 8)), radius=r, depth=0.3, vertices=7)
        L.jitter(lg, 0.005, 4.0, 60 + i)
        _paint_poly(lg, lambda poly, co: L.hexc("#B08C62") if abs(poly.normal.y) > 0.8 else L.hexc("#5A4A3C"),
                    var=0.15, ao=0.2, top=0.1, seed=60 + i)
        parts.append(lg)
    _done(parts, "ph_int_stove", [("light_fire", (0.0, fy - 0.32, fz + 0.05))], 40, center=False)


# --- table & chair ------------------------------------------------------------------------

def table():
    """Rustic table (1.0 x 0.7 m, top 0.76 m): bowl of soup with a spoon, a loaf with a cut
    slice and a knife, a clay mug and a candle stub on a tin dish."""
    L.reset(430)
    parts = []
    top = 0.76
    for i in range(3):
        parts.append(_board((0, -0.235 + i * 0.235, top - 0.025), (0.5, 0.115, 0.025), WOOD_WARM, seed=i, cuts=0,
                            zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = L.prim("cube", loc=(0, 0, (top - 0.05) / 2), scale=(0.04, 0.04, (top - 0.05) / 2))
            L.taper(leg, 0.0, top - 0.05, 1.2)
            _at(leg, (sx * 0.41, sy * 0.26, 0), (sy * 2.5, -sx * 2.5, 0))
            L.jitter(leg, 0.004, 3.0, 5 + sx + sy)
            parts.append(_set(leg, WOOD_DARK, var=0.14, ao=0.45, zrange=(0, top), seed=5))
    for sy in (-1, 1):
        parts.append(_board((0, sy * 0.27, top - 0.09), (0.37, 0.02, 0.04), WOOD, seed=10 + sy, zrange=(0, top)))
    for sx in (-1, 1):
        parts.append(_board((sx * 0.41, 0, top - 0.09), (0.02, 0.22, 0.04), WOOD, seed=12 + sx, zrange=(0, top)))
        parts.append(_board((sx * 0.43, 0, 0.14), (0.022, 0.24, 0.022), WOOD_DARK, seed=14 + sx, zrange=(0, top)))
    parts.append(_board((0, 0, 0.14), (0.42, 0.022, 0.022), WOOD_DARK, seed=16, zrange=(0, top)))
    # bowl with soup and a spoon
    bw = _lathe([(0.05, 0.0), (0.09, 0.02), (0.115, 0.06), (0.105, 0.062), (0.085, 0.03), (0.0, 0.02)], 14, "bowl")
    _at(bw, (-0.18, -0.08, top))
    parts.append(_set(bw, CERAMIC, var=0.08, ao=0.3, top=0.1, seed=20, hue_shift=GLAZE_BLUE))
    parts.append(L.part("cyl", SOUP, loc=(-0.18, -0.08, top + 0.045), radius=0.098, depth=0.006, vertices=14,
                        paint_kw={"var": 0.12, "ao": 0.0}))
    parts.append(_stick((-0.13, -0.12, top + 0.05), (-0.02, -0.2, top + 0.075), 0.007, WOOD_LIGHT, verts=4))
    parts.append(_set(L.prim("sphere", loc=(-0.15, -0.105, top + 0.047), radius=0.022, segments=6, ring_count=3,
                             scale=(1.3, 0.8, 0.35)), WOOD_LIGHT, ao=0.0))
    # bread board, loaf with a cut face, a slice and a knife
    parts.append(_board((0.2, 0.08, top + 0.012), (0.17, 0.11, 0.012), WOOD_LIGHT, seed=22))
    loaf = L.prim("sphere", loc=(0.21, 0.1, top + 0.06), radius=1.0, segments=10, ring_count=6, scale=(0.12, 0.08, 0.06))
    for v in loaf.data.vertices:
        v.co.z = max(v.co.z, top + 0.028)
        v.co.x = min(v.co.x, 0.29)
    L.jitter(loaf, 0.006, 6.0, 23)
    _paint_poly(loaf, lambda poly, co: L.hexc("#D8C49A") if poly.normal.x > 0.8 else
                (L.hexc("#8A5E34") if poly.normal.z > 0.5 else BREAD), var=0.1, ao=0.2, top=0.1, seed=23)
    parts.append(loaf)
    parts.append(_box((0.33, 0.04, top + 0.03), (0.012, 0.055, 0.035), L.hexc("#D8C49A"), rot=(0, 25, 0), seed=24,
                      bev=0.006))
    parts.append(_box((0.18, -0.03, top + 0.027), (0.07, 0.009, 0.002), L.hexc("#8A9096"), jit=0.0, rot=(0, 0, -12)))
    parts.append(_stick((0.1, -0.013, top + 0.03), (0.04, 0.0, top + 0.03), 0.009, WOOD_DARK, verts=5))
    # mug
    mug = _lathe([(0.04, 0.0), (0.045, 0.01), (0.047, 0.1), (0.041, 0.1), (0.039, 0.02), (0.0, 0.015)], 10, "mug")
    _at(mug, (-0.33, 0.17, top))
    parts.append(_set(mug, CLAY, var=0.15, ao=0.3, top=0.1, seed=25))
    parts.append(L.part("torus", CLAY, loc=(-0.28, 0.17, top + 0.055), rot=(90, 0, 0), major_radius=0.028,
                        minor_radius=0.008, major_segments=6, minor_segments=3))
    parts.append(L.part("cyl", L.hexc("#3E2A1E"), loc=(-0.33, 0.17, top + 0.085), radius=0.039, depth=0.004, vertices=10))
    # candle stub on a tin dish
    parts.append(L.part("cyl", L.hexc("#7C8187"), loc=(0.05, 0.2, top + 0.006), radius=0.05, depth=0.012, vertices=10))
    flame = _candle(parts, 0.05, 0.2, top + 0.012, 0.06, 0.02, seed=26)
    _flame(parts, flame, 0.04, 0.011)
    _done(parts, "ph_int_table", [("light_candle", (0.05, 0.2, top + 0.14))], 40)


def chair():
    """Rustic chair (seat 0.45 m): plank seat, splayed legs, a back with a curved top rail and
    three spindles, a faded cushion."""
    L.reset(440)
    parts = []
    sz = 0.45
    parts.append(_box((0, 0, sz - 0.02), (0.21, 0.2, 0.022), WOOD_WARM, bev=0.01, seed=1, zrange=(0, 0.9)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_stick((sx * 0.16, sy * 0.15, sz - 0.04), (sx * 0.19, sy * 0.18, 0.0), 0.02, WOOD_DARK,
                                r1=0.017, verts=6, ao=0.4, zrange=(0, 0.9), seed=2))
        parts.append(_stick((sx * 0.18, -0.15, 0.16), (sx * 0.18, 0.16, 0.16), 0.011, WOOD_DARK, verts=5))
    parts.append(_stick((-0.17, 0.0, 0.2), (0.17, 0.0, 0.2), 0.011, WOOD_DARK, verts=5))
    for sx in (-1, 1):  # back posts (continue the back legs)
        parts.append(_stick((sx * 0.17, 0.17, sz - 0.02), (sx * 0.18, 0.22, 0.9), 0.02, WOOD_DARK, r1=0.017, verts=6))
    rail = L.tube((-0.19, 0.22, 0.86), (0.19, 0.22, 0.86), 0.028, 6)
    L.subdivide(rail, 2)
    for v in rail.data.vertices:
        v.co.y += 0.03 * (1 - (v.co.x / 0.19) ** 2)
        v.co.z *= 1.0
    parts.append(_set(rail, WOOD, var=0.1, ao=0.0, seed=3))
    for k in (-1, 0, 1):
        parts.append(_stick((k * 0.08, 0.18, sz), (k * 0.08, 0.235, 0.84), 0.011, WOOD, verts=5))
    cush = L.prim("cube", loc=(0, -0.01, sz + 0.02), scale=(0.18, 0.17, 0.025))
    L.bevel(cush, 0.02, 2)
    L.jitter(cush, 0.006, 4.0, 4)
    _paint_poly(cush, lambda poly, co: L.mix(ROSE, WOOL, 0.3) if (int(co.x * 25) + int(co.y * 25)) % 2 else ROSE,
                var=0.08, ao=0.1, top=0.12, seed=4)
    parts.append(cush)
    _done(parts, "ph_int_chair", (), 45)


# --- desk with the grave register ------------------------------------------------------------

def desk():
    """Writing desk (1.1 x 0.6 m, top 0.78 m) with a letter rack; the grave register lies open on
    it: a thick ledger with entries and a ribbon, ink pot with a quill, a candle, loose papers."""
    L.reset(450)
    parts = []
    top = 0.78
    for i in range(2):
        parts.append(_board((0, -0.15 + i * 0.3, top - 0.025), (0.55, 0.15, 0.025), WOOD_WARM, seed=i, zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_board((sx * 0.49, sy * 0.24, (top - 0.05) / 2), (0.035, 0.035, (top - 0.05) / 2), WOOD_DARK,
                                seed=3 + sx + sy, ao=0.45, zrange=(0, top)))
        parts.append(_board((sx * 0.49, 0, 0.12), (0.02, 0.21, 0.02), WOOD_DARK, seed=8 + sx, zrange=(0, top)))
    # apron with a drawer (knob) in front, back apron
    parts.append(_board((0, -0.25, top - 0.1), (0.46, 0.02, 0.07), WOOD, seed=10, zrange=(0, top)))
    parts.append(_board((0, -0.265, top - 0.1), (0.2, 0.012, 0.05), WOOD_LIGHT, seed=11, zrange=(0, top)))
    parts.append(_set(L.prim("sphere", loc=(0, -0.285, top - 0.1), radius=0.016, segments=6, ring_count=4), BRASS))
    parts.append(_board((0, 0.25, top - 0.1), (0.46, 0.02, 0.07), WOOD, seed=12, zrange=(0, top)))
    # letter rack along the back edge: two shelves with pigeonholes, letters, a few books
    ry = 0.22
    parts.append(_board((0, ry + 0.045, top + 0.2), (0.5, 0.012, 0.2), WOOD, seed=13))
    for sx in (-1, 1):
        parts.append(_board((sx * 0.49, ry - 0.02, top + 0.2), (0.012, 0.07, 0.2), WOOD_DARK, seed=14 + sx))
    for z in (top + 0.14, top + 0.4):
        parts.append(_board((0, ry - 0.02, z), (0.5, 0.07, 0.012), WOOD_DARK, seed=16))
    for x in (-0.2, 0.15):
        parts.append(_board((x, ry - 0.02, top + 0.07), (0.01, 0.07, 0.07), WOOD_DARK, seed=17))
    for i, x in enumerate((-0.34, -0.29, -0.05, 0.02, 0.28)):  # letters standing in the pigeonholes
        parts.append(_box((x, ry - 0.03, top + 0.06), (0.008, 0.055, 0.05), L.scale_c(PAPER, random.uniform(0.85, 1.0)),
                          rot=(0, random.uniform(-12, 12), 0), jit=0.0, var=0.05, ao=0.0))
    for i, (x, h, col) in enumerate(((0.26, 0.2, LEATHER), (0.3, 0.18, L.hexc("#5A4E6A")), (0.34, 0.21, MOSSC),
                                     (0.38, 0.17, L.hexc("#7A5040")))):
        parts.append(_box((x, ry - 0.02, top + 0.16 + h / 2), (0.018, 0.06, h / 2), col, bev=0.004, rot=(0, 6 if i == 3 else 0, 0),
                          seed=20 + i, ao=0.2))
    parts.append(_set(L.prim("sphere", loc=(-0.3, ry - 0.02, top + 0.19), radius=0.04, segments=8, ring_count=5,
                             scale=(1, 1, 0.8)), L.hexc("#6A7488"), var=0.1, ao=0.3))  # a round inkwell spare / stone
    # the grave register: thick ledger, open, pages curving up, lines of entries, ribbon
    bx, by = -0.05, -0.05
    cover = L.prim("cube", loc=(bx, by, top + 0.012), scale=(0.3, 0.2, 0.012))
    L.bevel(cover, 0.006, 1)
    parts.append(_set(cover, LEATHER_DARK, var=0.15, ao=0.0, top=0.1, seed=30, hue_shift=LEATHER))

    def page(side):
        def fn(u, v):
            x = bx + side * (0.012 + u * 0.27)
            y = by - 0.18 + v * 0.36
            z = top + 0.025 + 0.055 * math.sin(math.pi * (0.12 + 0.88 * u)) ** 0.6 * (1.0 - u * 0.35) + 0.002 * math.sin(v * 9)
            return Vector((x, y, z))
        return fn
    for side in (-1, 1):
        blk = _slab(6, 2, page(side), 0.03, "pages")
        _paint_poly(blk, lambda poly, co: PAPER if poly.normal.z > 0.3 else L.scale_c(PAPER, 0.78), var=0.05, ao=0.0,
                    top=0.1, seed=31)
        parts.append(blk)
        for r in range(9):  # handwritten entries: short dark strokes on the curved page
            v = 0.14 + r * 0.085
            for seg in range(2):
                u0 = 0.12 + seg * 0.42
                u1 = u0 + random.uniform(0.2, 0.36)
                p0, p1 = page(side)(u0, v), page(side)(u1, v)
                mid = (p0 + p1) / 2 + Vector((0, 0, 0.0025))
                d = p1 - p0
                ln = L.prim("cube", loc=mid, scale=(d.length / 2, 0.0035, 0.0006))
                ln.data.transform(Matrix.Translation(mid) @ Vector((1, 0, 0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
                                  @ Matrix.Translation(-mid))
                parts.append(_set(ln, INK, var=0.1, ao=0.0, top=0.0))
            if r % 3 == 0:  # a small cross at the start of an entry
                p = page(side)(0.07, v) + Vector((0, 0, 0.003))
                parts.append(_set(L.prim("cube", loc=p, scale=(0.006, 0.0015, 0.001)), INK, ao=0.0))
                parts.append(_set(L.prim("cube", loc=p + Vector((0.0, 0, 0)), scale=(0.0015, 0.008, 0.001)), INK, ao=0.0))
    # spine valley shadow and the ribbon falling out of the book
    parts.append(_box((bx, by, top + 0.03), (0.01, 0.18, 0.006), L.scale_c(PAPER, 0.55), jit=0.0, ao=0.0))
    rib = _path_tube([(bx, by - 0.05, top + 0.034), (bx + 0.01, by - 0.19, top + 0.03), (bx + 0.03, by - 0.215, top + 0.02),
                      (bx + 0.05, by - 0.22, top - 0.02), (bx + 0.055, by - 0.215, top - 0.08)], 0.005, 4, hint=(1, 0, 0))
    parts.append(_set(rib, DRIED_RED, var=0.1, ao=0.0))
    # ink pot + quill
    ip = _lathe([(0.03, 0.0), (0.036, 0.01), (0.034, 0.045), (0.014, 0.055), (0.015, 0.068), (0.0, 0.066)], 10, "inkpot")
    _at(ip, (0.34, -0.02, top))
    parts.append(_set(ip, L.hexc("#2E3440"), var=0.1, ao=0.2, top=0.35, seed=33))
    q0, q1 = Vector((0.34, -0.02, top + 0.05)), Vector((0.27, 0.07, top + 0.3))

    def quill(u, v):
        p = q0 + (q1 - q0) * u
        w = 0.028 * math.sin(math.pi * min(1.0, max(0.0, (u - 0.25) / 0.75))) ** 0.7
        side = Vector((0.7, 0.55, 0)).normalized().cross(Vector((0, 0, 1)))
        return p + side * (v - 0.4) * 2 * w + Vector((0, 0, 0.01 * math.sin(u * 3)))
    for flip in (False, True):
        qo = _sheet(6, 2, quill, "quill", flip=flip)
        _paint_poly(qo, lambda poly, co: L.hexc("#E4DDCC") if co.z > top + 0.15 else L.hexc("#B9B2A2"), var=0.06, ao=0.0,
                    top=0.1, seed=34)
        parts.append(qo)
    parts.append(_stick(q0, q1, 0.003, L.hexc("#D8D0BC"), verts=4))
    # candle in a brass holder with a drip tray
    cxp, cyp = -0.42, 0.06
    parts.append(L.part("cyl", BRASS, loc=(cxp, cyp, top + 0.008), radius=0.055, depth=0.016, vertices=10))
    parts.append(L.part("torus", BRASS, loc=(cxp + 0.06, cyp, top + 0.02), rot=(90, 0, 0), major_radius=0.02,
                        minor_radius=0.005, major_segments=6, minor_segments=3))
    parts.append(L.part("cyl", BRASS, loc=(cxp, cyp, top + 0.03), radius=0.022, depth=0.03, vertices=8))
    flame = _candle(parts, cxp, cyp, top + 0.045, 0.13, 0.019, seed=35, drips=3)
    _flame(parts, flame, 0.045, 0.012)
    # loose papers, one with a wax seal
    for i, (x, y, a) in enumerate(((0.36, -0.2, 14), (0.4, -0.16, -9))):
        parts.append(_box((x, y, top + 0.002 + i * 0.0015), (0.09, 0.065, 0.0012), L.scale_c(PAPER, 0.93 + i * 0.05),
                          rot=(0, 0, a), jit=0.0, var=0.05, ao=0.0))
    parts.append(_set(L.prim("cyl", loc=(0.42, -0.14, top + 0.006), radius=0.012, depth=0.004, vertices=8),
                      L.hexc("#7A3A30"), ao=0.0))
    _done(parts, "ph_int_desk", [("book", (bx, by, top + 0.06)), ("light_candle", (cxp, cyp, top + 0.3))], 40)


# --- chest ------------------------------------------------------------------------------------

def chest():
    """Iron-banded wooden storage chest (0.9 x 0.5 x 0.56 m): plank body, gently domed lid,
    three iron bands, corner caps, hasp with a padlock, ring handles at the sides."""
    L.reset(460)
    parts = []
    hx, hy, bz = 0.43, 0.23, 0.38
    for i in range(3):  # front and back planks
        for sy in (-1, 1):
            parts.append(_board((0, sy * hy, 0.03 + i * 0.12 + 0.06), (hx, 0.02, 0.058), WOOD, seed=i + sy * 5,
                                zrange=(0, 0.56)))
    for sx in (-1, 1):
        parts.append(_board((sx * hx, 0, bz / 2 + 0.02), (0.022, hy - 0.01, bz / 2), WOOD_WARM, seed=10 + sx,
                            zrange=(0, 0.56)))
    parts.append(_box((0, 0, 0.03), (hx - 0.01, hy - 0.01, 0.02), WOOD_DARK, jit=0.0))
    for sx in (-1, 1):  # feet
        parts.append(_board((sx * (hx - 0.05), 0, 0.015), (0.05, hy + 0.01, 0.018), WOOD_DARK, seed=12 + sx))
    # domed lid: half-round staves (every other one a shade lighter), end caps
    n = 6
    bm = bmesh.new()
    ring = []
    for sx in (-1, 1):
        ring.append([bm.verts.new((sx * (hx + 0.015), -math.cos(math.pi * k / n) * (hy + 0.015),
                                   bz + 0.02 + math.sin(math.pi * k / n) * (hy + 0.015) * 0.56)) for k in range(n + 1)])
    for k in range(n):
        bm.faces.new((ring[0][k], ring[0][k + 1], ring[1][k + 1], ring[1][k]))
    bm.faces.new(list(reversed(ring[0])))
    bm.faces.new(ring[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    lid = _raw(bm, "lid")
    L.jitter(lid, 0.004, 3.0, 25)
    _paint_poly(lid, lambda poly, co: WOOD_DARK if abs(poly.normal.x) > 0.9 else
                (WOOD_WARM if int((math.atan2(co.z - bz, -co.y) / math.pi) * n) % 2 else WOOD), var=0.14, ao=0.0,
                top=0.12, seed=26)
    parts.append(lid)
    # iron bands over lid and body
    for x in (-0.3, 0.0, 0.3):
        pts = [(x, -hy - 0.025, 0.04)] + [(x, -math.cos(math.pi * t / 6) * (hy + 0.04),
                                           bz + 0.02 + math.sin(math.pi * t / 6) * (hy + 0.04) * 0.56) for t in range(7)] + \
              [(x, hy + 0.025, 0.04)]
        band = _path_tube(pts, 0.012, 4, hint=(1, 0, 0))
        for v in band.data.vertices:  # flat strap: wider along X
            v.co.x = x + (v.co.x - x) * 1.8
        parts.append(_set(band, IRON, var=0.25, ao=0.0, top=0.15, hue_shift=RUST, seed=30))
        for z in (0.1, 0.25):
            for sy in (-1, 1):
                parts.append(_set(L.prim("sphere", loc=(x, sy * (hy + 0.035), z), radius=0.009, segments=5, ring_count=3),
                                  IRON_DARK, ao=0.0))
    for sx in (-1, 1):  # corner caps
        for sy in (-1, 1):
            parts.append(_box((sx * (hx - 0.005), sy * (hy + 0.005), 0.05), (0.035, 0.035, 0.05), IRON, jit=0.0,
                              var=0.2, hue_shift=RUST))
    # hasp and padlock
    parts.append(_box((0, -hy - 0.03, bz + 0.03), (0.035, 0.008, 0.07), IRON, jit=0.0, var=0.2))
    lock = L.prim("cube", loc=(0, -hy - 0.05, bz - 0.06), scale=(0.035, 0.014, 0.035))
    L.bevel(lock, 0.01, 1)
    parts.append(_set(lock, BRASS, var=0.2, ao=0.0, top=0.15))
    parts.append(L.part("torus", IRON_DARK, loc=(0, -hy - 0.05, bz - 0.02), rot=(90, 0, 0), major_radius=0.022,
                        minor_radius=0.005, major_segments=8, minor_segments=3))
    parts.append(L.part("cube", INK, loc=(0, -hy - 0.066, bz - 0.065), scale=(0.004, 0.002, 0.01)))
    for sx in (-1, 1):  # side handles
        parts.append(L.part("torus", IRON_DARK, loc=(sx * (hx + 0.04), 0, bz - 0.06), rot=(0, 90, 0), major_radius=0.045,
                            minor_radius=0.008, major_segments=8, minor_segments=3))
    _done(parts, "ph_int_chest", (), 35)


# --- shelf ------------------------------------------------------------------------------------

def _jar(parts, x, y, z, r, h, color, cloth=None, seed=0):
    j = _lathe([(r * 0.8, 0.0), (r, h * 0.12), (r * 1.02, h * 0.7), (r * 0.8, h * 0.9), (r * 0.72, h), (0.0, h)], 10, "jar")
    _at(j, (x, y, z))
    parts.append(_set(j, color, var=0.12, ao=0.3, top=0.12, seed=seed))
    if cloth is not None:  # cloth cover tied with string
        c = L.prim("sphere", loc=(x, y, z + h), radius=r * 1.05, segments=8, ring_count=4, scale=(1, 1, 0.45))
        for v in c.data.vertices:
            if v.co.z < z + h:
                v.co.z = z + h - (z + h - v.co.z) * 0.9
                v.co.x = x + (v.co.x - x) * 1.12
                v.co.y = y + (v.co.y - y) * 1.12
        parts.append(_set(c, cloth, var=0.1, ao=0.0, top=0.2, seed=seed + 1))
        parts.append(L.part("torus", STRING, loc=(x, y, z + h - 0.012), major_radius=r * 0.8, minor_radius=0.004,
                            major_segments=8, minor_segments=3))


def _bottle(parts, x, y, z, r, h, color, seed=0):
    b = _lathe([(r, 0.0), (r, h * 0.6), (r * 0.4, h * 0.78), (r * 0.3, h * 0.95), (0.0, h)], 7, "bottle")
    _at(b, (x, y, z))
    parts.append(_set(b, color, var=0.1, ao=0.25, top=0.3, seed=seed))
    parts.append(L.part("cyl", L.hexc("#9C7B55"), loc=(x, y, z + h), radius=r * 0.3, depth=0.02, vertices=6))


def shelf():
    """Wall shelf (1.0 m, two boards on brackets): jars with cloth covers, bottles, books, a
    mortar and pestle, a little potted plant."""
    L.reset(470)
    parts = []
    w, d = 0.5, 0.13
    for z in (0.12, 0.5):
        parts.append(_board((0, 0, z), (w, d, 0.016), WOOD_WARM, seed=int(z * 10)))
    for sx in (-1, 1):  # brackets (triangular) and back strips
        for z in (0.12, 0.5):
            br = L.prism_x([(d, z - 0.016), (d, z - 0.16), (-d + 0.05, z - 0.016)], sx * (w - 0.1), 0.03)
            parts.append(_set(br, WOOD_DARK, var=0.12, ao=0.0, seed=3))
        parts.append(_board((sx * (w - 0.1), d - 0.01, 0.3), (0.025, 0.01, 0.28), WOOD_DARK, seed=4))
    # lower board
    z = 0.136
    _jar(parts, -0.38, -0.01, z, 0.055, 0.14, CLAY, cloth=LINEN, seed=10)
    _jar(parts, -0.25, 0.02, z, 0.045, 0.11, CERAMIC, cloth=L.mix(ROSE, LINEN, 0.3), seed=12)
    _bottle(parts, -0.13, 0.03, z, 0.03, 0.2, GLASS_GREEN, seed=14)
    _bottle(parts, -0.06, -0.02, z, 0.026, 0.16, GLASS_BROWN, seed=15)
    mortar = _lathe([(0.045, 0.0), (0.06, 0.02), (0.065, 0.07), (0.052, 0.072), (0.04, 0.03), (0.0, 0.025)], 10, "mortar")
    _at(mortar, (0.08, 0.0, z))
    parts.append(_set(mortar, STONE, var=0.15, ao=0.3, seed=16))
    parts.append(_stick((0.07, 0.0, z + 0.04), (0.12, -0.02, z + 0.13), 0.011, WOOD_LIGHT, r1=0.016, verts=5))
    pot = _lathe([(0.04, 0.0), (0.05, 0.08), (0.055, 0.085), (0.0, 0.075)], 10, "pot")
    _at(pot, (0.35, 0.0, z))
    parts.append(_set(pot, CLAY, var=0.15, ao=0.3, seed=17))
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        leaf = L.prim("sphere", loc=(0.35 + math.cos(a) * 0.03, math.sin(a) * 0.03, z + 0.11), radius=0.03, segments=6,
                      ring_count=3, scale=(1.6, 0.7, 0.4))
        leaf.data.transform(Matrix.Translation((0.35, 0, z + 0.11)) @ Matrix.Rotation(a, 4, "Z") @
                            Matrix.Rotation(math.radians(-25), 4, "Y") @ Matrix.Translation((-0.35, 0, -z - 0.11)))
        parts.append(_set(leaf, L.mix(HERB_GREEN, L.hexc("#5E7145"), random.random()), var=0.15, ao=0.2, top=0.3))
    # upper board: books (upright + leaning), a jar, a small box, a candle stub
    z = 0.516
    x = -0.42
    for i, (col, h, t) in enumerate(((LEATHER, 0.22, 0.04), (L.hexc("#5A4E6A"), 0.2, 0.035), (MOSSC, 0.24, 0.045),
                                     (L.hexc("#7A5040"), 0.19, 0.03), (OCHRE, 0.21, 0.038))):
        parts.append(_box((x + t / 2, 0.0, z + h / 2), (t / 2, 0.08, h / 2), col, bev=0.004, seed=30 + i, ao=0.2,
                          hue_shift=L.scale_c(col, 0.8)))
        parts.append(_box((x + t / 2, -0.081, z + h * 0.7), (t / 2 * 0.8, 0.002, 0.008), OCHRE, jit=0.0, ao=0.0))
        x += t + 0.004
    parts.append(_box((x + 0.07, 0.0, z + 0.1), (0.02, 0.08, 0.1), L.hexc("#4E5A6A"), bev=0.004, rot=(0, 28, 0), seed=36))
    _jar(parts, 0.08, 0.0, z, 0.05, 0.13, GLAZE_BLUE, seed=40)
    parts.append(_box((0.24, 0.0, z + 0.04), (0.07, 0.05, 0.04), WOOD_LIGHT, bev=0.006, seed=41))
    parts.append(_box((0.24, 0.0, z + 0.085), (0.075, 0.055, 0.008), WOOD, bev=0.004, seed=42))
    parts.append(L.part("cyl", BRASS, loc=(0.4, 0.0, z + 0.006), radius=0.035, depth=0.012, vertices=8))
    _candle(parts, 0.4, 0.0, z + 0.012, 0.05, 0.016, seed=43, drips=1)
    _done(parts, "ph_int_shelf", (), 40)


# --- rug --------------------------------------------------------------------------------------

def rug():
    """Woven rag rug (1.7 x 1.1 m): colour bands across, a darker border, fringes at both ends."""
    L.reset(480)
    parts = []
    hx, hy = 0.8, 0.55

    def fn(u, v):
        x = -hx + 2 * hx * u
        y = -hy + 2 * hy * v
        return Vector((x, y, 0.014 + 0.004 * noise.noise(Vector((x * 2.0, y * 2.0, 0.3)))))
    r = _slab(16, 10, fn, 0.012, "rug")
    bands = (L.mix(ROSE, WOOL, 0.3), OCHRE, MOSSC, L.mix(LINEN_DARK, OCHRE, 0.2), ROSE, WOOL, GLAZE_BLUE,
             L.mix(OCHRE, ROSE, 0.5))
    pr = random.Random(3)
    order = [pr.choice(bands) for _ in range(16)]

    def col(poly, co):
        c = poly.center
        if abs(c.x) > hx - 0.1 or abs(c.y) > hy - 0.1:
            return L.scale_c(WOOL, 0.8)
        k = int((c.x + hx) / (2 * hx) * 16) % 16
        return L.mix(order[k], LINEN, 0.15 * (1 + math.sin(c.y * 40)) * 0.5)
    _paint_poly(r, col, var=0.12, ao=0.0, top=0.05, freq=9.0, seed=5)
    parts.append(r)
    for sx in (-1, 1):  # fringes
        for i in range(14):
            y = -hy + 0.05 + i * (2 * hy - 0.1) / 13
            parts.append(_box((sx * (hx + 0.035), y, 0.006), (0.035, 0.008, 0.003), LINEN_DARK, jit=0.0,
                              rot=(0, 0, random.uniform(-10, 10)), var=0.1, ao=0.0))
    _done(parts, "ph_int_rug", (), 30)


# --- decoration -------------------------------------------------------------------------------

def herbs():
    """Hanging herb bundles: a rod on two cords (hangs from the tie beam), five bundles of
    dried herbs head down - stems fanning out of a string tie, leaves and flower heads."""
    L.reset(490)
    parts = []
    h = 0.62
    rod_z = h - 0.2
    parts.append(_stick((-0.5, 0, rod_z), (0.5, 0, rod_z), 0.013, WOOD_DARK, verts=5))
    for sx in (-1, 1):
        parts.append(_stick((sx * 0.42, 0, rod_z), (sx * 0.4, 0, h), 0.004, STRING, verts=3))
    kinds = ((HERB_GREEN, L.hexc("#5E6A3E"), None), (SAGE, L.hexc("#6E7A5A"), LAVENDER),
             (L.hexc("#8A8A58"), L.hexc("#6A6A40"), YARROW), (SAGE, HERB_GREEN, None),
             (L.hexc("#7A6A48"), L.hexc("#5A4A34"), L.hexc("#9A6A4A")))
    for i, (leaf_a, leaf_b, bloom) in enumerate(kinds):
        x = -0.36 + i * 0.18
        tie = Vector((x, 0, rod_z - 0.07))
        parts.append(_stick((x, 0, rod_z), tie, 0.003, STRING, verts=3))
        parts.append(L.part("cyl", STRING, loc=tie + Vector((0, 0, -0.01)), radius=0.013, depth=0.03, vertices=6))
        ln = random.uniform(0.22, 0.3)
        ends = []
        for k in range(8):  # stems fan out downwards
            a = k / 8 * math.tau + random.uniform(-0.3, 0.3)
            spread = random.uniform(0.03, 0.07)
            e = tie + Vector((math.cos(a) * spread, math.sin(a) * spread * 0.8, -ln * random.uniform(0.8, 1.05)))
            parts.append(_stick(tie + Vector((0, 0, 0.01)), e, 0.004, L.hexc("#6E6440"), r1=0.003, verts=3))
            ends.append(e)
        for k in range(7):  # leaves along the lower part of the stems
            e = ends[k % len(ends)]
            t = random.uniform(0.45, 1.0)
            p = tie + (e - tie) * t
            lf = L.prim("ico", loc=p, radius=random.uniform(0.022, 0.034), subdivisions=1, scale=(1.0, 0.6, 1.6))
            L.jitter(lf, 0.005, 20.0, i * 20 + k)
            L.paint(lf, L.mix(leaf_a, leaf_b, random.random()), var=0.2, ao=0.0, top=0.1, seed=i * 20 + k)
            L.set_mat(lf, L.MAT_PAINTED)
            parts.append(lf)
        if bloom is not None:
            for e in ends[::2]:
                parts.append(L.part("ico", bloom, loc=e, radius=0.016, subdivisions=1, scale=(1, 1, 1.8),
                                    paint_kw={"ao": 0.0, "var": 0.15}))
    _done(parts, "ph_int_herbs", (), 40)


def coat_hook():
    """Peg rail on the wall with the gravekeeper's spare hat and his ochre scarf."""
    L.reset(500)
    parts = []
    bz = 0.95
    parts.append(_board((0, 0.02, bz), (0.36, 0.018, 0.05), WOOD_DARK, seed=1))
    for x in (-0.24, 0.0, 0.24):
        parts.append(_stick((x, 0.0, bz), (x, -0.13, bz + 0.05), 0.014, WOOD, r1=0.011, verts=6))
    # spare hat on the left peg: floppy brim, pinched crown, band
    hx, hz = -0.24, bz - 0.02
    brim = _lathe([(0.02, 0.0), (0.2, 0.0), (0.21, -0.012), (0.0, -0.01)], 16, "brim")
    for v in brim.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        rr = math.hypot(v.co.x, v.co.y)
        v.co.z += 0.03 * math.sin(a * 2 + 0.6) * (rr / 0.2) ** 2
    _at(brim, (hx, -0.1, hz + 0.02), (80, 0, 6))
    parts.append(_set(brim, HAT, var=0.15, ao=0.0, top=0.15, seed=2, hue_shift=L.hexc("#5A524A")))
    crown = _lathe([(0.1, 0.0), (0.095, 0.08), (0.075, 0.13), (0.03, 0.14), (0.0, 0.12)], 12, "crown")
    for v in crown.data.vertices:
        if v.co.z > 0.1:
            v.co.x *= 0.85
    _at(crown, (hx, -0.1, hz + 0.02), (80, 0, 6))
    parts.append(_set(crown, HAT, var=0.15, ao=0.2, top=0.1, seed=3))
    band = _lathe([(0.1, 0.0), (0.098, 0.028)], 12, "band", cap_bottom=False)
    for v in band.data.vertices:
        v.co.x *= 1.03
        v.co.y *= 1.03
    _at(band, (hx, -0.1, hz + 0.02), (80, 0, 6))
    parts.append(_set(band, HAT_BAND, var=0.1, ao=0.0))
    # scarf hanging over the middle peg: two long tails with fringes, folded over the peg
    sx0 = 0.02

    def tail(side):
        def fn(u, v):
            z = bz + 0.05 - u * 0.7
            x = sx0 + side * 0.06 + (v - 0.5) * 0.13 + 0.02 * math.sin(u * 5 + side)
            y = -0.1 - 0.04 * math.sin(u * math.pi * 0.8) - side * 0.015 + 0.01 * math.sin(v * 9)
            return Vector((x, y, z))
        return fn
    for side in (-1, 1):
        for flip in (False, True):
            t = _sheet(6, 3, tail(side), "scarf", flip=flip)
            _paint_poly(t, lambda poly, co: SCARF_DARK if int((bz - co.z) * 14) % 4 == 3 else SCARF, var=0.1, ao=0.2,
                        top=0.1, zr=(bz - 0.7, bz), seed=4)
            parts.append(t)
        for k in range(5):
            x = sx0 + side * 0.06 - 0.055 + k * 0.028
            parts.append(_stick((x, -0.1 - side * 0.015, bz - 0.65), (x, -0.1 - side * 0.015, bz - 0.7), 0.004, SCARF_DARK,
                                verts=3))
    fold = L.prim("cyl", loc=(sx0, -0.08, bz + 0.05), rot=(0, 90, 0), radius=0.035, depth=0.18, vertices=8)
    parts.append(_set(fold, SCARF, var=0.1, ao=0.0, top=0.2))
    # a small leather satchel on the right peg
    bag = L.prim("cube", loc=(0.26, -0.08, bz - 0.2), scale=(0.1, 0.035, 0.09))
    L.bevel(bag, 0.025, 2)
    parts.append(_set(bag, LEATHER, var=0.15, ao=0.2, top=0.1, seed=6))
    parts.append(_box((0.26, -0.118, bz - 0.15), (0.1, 0.006, 0.05), LEATHER_DARK, jit=0.0))
    parts.append(_stick((0.18, -0.08, bz - 0.15), (0.24, -0.1, bz + 0.05), 0.008, LEATHER_DARK, verts=4))
    parts.append(_stick((0.34, -0.08, bz - 0.15), (0.25, -0.1, bz + 0.05), 0.008, LEATHER_DARK, verts=4))
    _done(parts, "ph_int_coat_hook", (), 45)


def candles():
    """Cluster of four candles on a tin plate, wax pooled around them."""
    L.reset(510)
    parts = [L.part("cyl", L.hexc("#7C8187"), loc=(0, 0, 0.006), radius=0.11, depth=0.012, vertices=12)]
    parts.append(L.part("cyl", WAX, loc=(0.01, 0.0, 0.014), radius=0.08, depth=0.006, vertices=10, jit=0.004, seed=3))
    flames = []
    for i, (x, y, h) in enumerate(((0.0, 0.01, 0.2), (0.06, 0.04, 0.13), (-0.05, 0.05, 0.1), (0.04, -0.05, 0.075))):
        fl = _candle(parts, x, y, 0.014, h, 0.022 if i else 0.026, seed=i, drips=2)
        _flame(parts, fl, 0.045, 0.012)
        flames.append(fl)
    _done(parts, "ph_int_candles", [("light_candle", (0.0, 0.0, 0.3))], 45)


def picture():
    """Small framed picture: a painted evening landscape (hill, old tree, a tiny warm window)."""
    L.reset(520)
    parts = []
    w, h = 0.2, 0.15
    zc = 0.2
    for (x, z, sx, sz) in ((0, zc + h + 0.02, w + 0.04, 0.022), (0, zc - h - 0.02, w + 0.04, 0.022),
                           (-w - 0.02, zc, 0.022, h + 0.04), (w + 0.02, zc, 0.022, h + 0.04)):
        parts.append(_board((x, 0, z), (sx, 0.018, sz), WOOD_DARK, seed=int(x * 10 + z * 10)))

    def img(u, v):
        return Vector((-w + 2 * w * u, -0.004, zc - h + 2 * h * v))
    canvas = _sheet(10, 8, img, "canvas", flip=False)

    def col(poly, co):
        u = (co.x + w) / (2 * w)
        v = (co.z - zc + h) / (2 * h)
        hill = 0.35 + 0.12 * math.sin(u * 3.2 + 0.5)
        if v < hill:
            return L.mix(L.hexc("#4E5E3C"), L.hexc("#3A4630"), v / hill)
        sky = L.mix(L.hexc("#D9B27A"), L.hexc("#7A869A"), (v - hill) / (1 - hill))
        return sky
    _paint_poly(canvas, col, var=0.06, ao=0.0, top=0.0, seed=4)
    parts.append(canvas)
    parts.append(_stick((0.07, -0.006, zc - 0.03), (0.08, -0.006, zc + 0.07), 0.008, L.hexc("#2E2620"), verts=4))
    parts.append(_set(L.prim("sphere", loc=(0.085, -0.008, zc + 0.08), radius=0.035, segments=6, ring_count=4,
                             scale=(1, 0.2, 0.8)), L.hexc("#2F3A28"), ao=0.0))
    parts.append(_box((-0.09, -0.006, zc - 0.035), (0.03, 0.002, 0.025), L.hexc("#2E2620"), jit=0.0, ao=0.0))
    parts.append(_box((-0.09, -0.008, zc - 0.035), (0.008, 0.002, 0.008), OCHRE, jit=0.0, ao=0.0))
    parts.append(_stick((-0.12, 0.012, zc + h + 0.03), (0.0, 0.012, zc + h + 0.14), 0.003, STRING, verts=3))
    parts.append(_stick((0.12, 0.012, zc + h + 0.03), (0.0, 0.012, zc + h + 0.14), 0.003, STRING, verts=3))
    parts.append(L.part("cube", IRON_DARK, loc=(0, 0.0, zc + h + 0.14), scale=(0.006, 0.012, 0.006)))
    _done(parts, "ph_int_picture", (), 30)


def broom():
    """Besom broom leaning against a wall (towards +Y): crooked handle, twig bundle tied twice."""
    L.reset(530)
    parts = []
    lean = math.radians(14)
    d = Vector((0, math.sin(lean), math.cos(lean)))
    base = Vector((0, 0, 0.0))
    parts.append(_stick(base + d * 0.3, base + d * 1.42, 0.02, WOOD_OLD, r1=0.016, verts=6, seed=1))
    twigs = L.prim("cone", loc=(0, 0, 0.24), radius1=0.16, radius2=0.04, depth=0.48, vertices=10)
    L.jitter(twigs, 0.015, 8.0, 2)
    for v in twigs.data.vertices:
        v.co.y *= 0.7
    twigs.data.transform(Matrix.Rotation(lean, 4, "X"))
    L.paint(twigs, L.hexc("#8A7050"), var=0.25, ao=0.3, top=0.1, seed=2, hue_shift=L.hexc("#6A5238"))
    L.set_mat(twigs, L.MAT_PAINTED)
    parts.append(twigs)
    for z in (0.33, 0.41):
        t = L.prim("cyl", loc=(0, 0, z), radius=0.068 - (z - 0.33) * 0.3, depth=0.022, vertices=8)
        t.data.transform(Matrix.Rotation(lean, 4, "X"))
        parts.append(_set(t, STRING, ao=0.0))
    for i in range(6):
        a = i / 6 * math.tau
        p = Vector((math.cos(a) * 0.14, math.sin(a) * 0.09, 0.01))
        parts.append(_stick(p, p + Vector((math.cos(a) * 0.03, math.sin(a) * 0.02, 0.12)), 0.005, L.hexc("#7A6040"),
                            verts=3))
    _done(parts, "ph_int_broom", (), 40)


def bucket():
    """Wooden bucket with two iron hoops, a rope handle and water."""
    L.reset(540)
    parts = []
    b = _lathe([(0.13, 0.0), (0.15, 0.3), (0.138, 0.3), (0.12, 0.03), (0.0, 0.03)], 14, "bucket")
    L.jitter(b, 0.003, 5.0, 1)
    L.paint(b, WOOD, var=0.14, ao=0.35, zrange=(0, 0.3), seed=1, hue_shift=WOOD_OLD)
    attr = b.data.color_attributes["Col"]
    st = [random.uniform(0.78, 1.05) for _ in range(14)]
    for poly in b.data.polygons:
        k = st[int((math.atan2(poly.center.y, poly.center.x) % math.tau) / math.tau * 14) % 14]
        for li in poly.loop_indices:
            c = attr.data[li].color
            attr.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)
    L.set_mat(b, L.MAT_PAINTED)
    parts.append(b)
    for z, r in ((0.06, 0.137), (0.24, 0.148)):
        parts.append(L.part("cyl", IRON, loc=(0, 0, z), radius=r, depth=0.025, vertices=14,
                            paint_kw={"hue_shift": RUST, "var": 0.3}))
    parts.append(L.part("cyl", WATER, loc=(0, 0, 0.22), radius=0.137, depth=0.006, vertices=14,
                        paint_kw={"var": 0.05, "top": 0.4, "ao": 0.0}))
    rope = _path_tube([(-0.15, 0, 0.27), (-0.12, -0.02, 0.4), (0.0, -0.03, 0.46), (0.12, -0.02, 0.4), (0.15, 0, 0.27)],
                      0.009, 4, hint=(0, 1, 0))
    parts.append(_set(rope, L.hexc("#8C7650"), var=0.15, ao=0.0))
    parts.append(_stick((0.05, 0.04, 0.23), (0.2, 0.1, 0.38), 0.008, WOOD_LIGHT, verts=4))  # ladle
    parts.append(_set(L.prim("sphere", loc=(0.03, 0.03, 0.23), radius=0.035, segments=6, ring_count=4,
                             scale=(1, 1, 0.45)), WOOD_LIGHT, ao=0.0))
    _done(parts, "ph_int_bucket", (), 40)


def washbasin():
    """Wash stand (0.55 x 0.42 m, 0.8 m high): ceramic basin set into the top, a jug, a folded
    towel on the side rail, soap on a saucer, a small mirror board at the back."""
    L.reset(550)
    parts = []
    top = 0.78
    hx, hy = 0.26, 0.19
    parts.append(_board((0, 0, top - 0.02), (hx, hy, 0.02), WOOD_WARM, seed=1, zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_board((sx * (hx - 0.03), sy * (hy - 0.03), (top - 0.04) / 2), (0.022, 0.022, (top - 0.04) / 2),
                                WOOD_DARK, seed=2 + sx + sy, ao=0.45, zrange=(0, top)))
    parts.append(_board((0, 0, 0.18), (hx - 0.03, hy - 0.03, 0.012), WOOD, seed=6, zrange=(0, top)))
    parts.append(_board((0, hy - 0.01, top + 0.14), (hx, 0.012, 0.14), WOOD, seed=7))
    parts.append(_box((0, hy - 0.02, top + 0.16), (0.1, 0.004, 0.08), L.hexc("#8A96A0"), jit=0.0, var=0.1, ao=0.0,
                      top=0.3))
    for sx in (-1, 1):  # towel rails at the sides
        parts.append(_stick((sx * (hx + 0.04), -hy + 0.04, top - 0.08), (sx * (hx + 0.04), hy - 0.04, top - 0.08), 0.009,
                            WOOD_DARK, verts=5))
    basin = _lathe([(0.1, 0.0), (0.16, 0.06), (0.175, 0.075), (0.16, 0.078), (0.14, 0.06), (0.0, 0.015)], 16, "basin")
    _at(basin, (-0.03, -0.02, top - 0.02))
    parts.append(_set(basin, CERAMIC, var=0.06, ao=0.3, top=0.15, seed=8, hue_shift=GLAZE_BLUE))
    parts.append(L.part("cyl", WATER, loc=(-0.03, -0.02, top + 0.03), radius=0.13, depth=0.004, vertices=16,
                        paint_kw={"var": 0.05, "top": 0.5, "ao": 0.0}))
    jug = _lathe([(0.055, 0.0), (0.07, 0.05), (0.068, 0.12), (0.045, 0.17), (0.055, 0.22), (0.05, 0.225), (0.0, 0.2)], 12, "jug")
    _at(jug, (0.17, 0.08, top))
    _paint_poly(jug, lambda poly, co: GLAZE_BLUE if 0.07 < co.z - top < 0.1 else CERAMIC, var=0.06, ao=0.3, top=0.15,
                zr=(top, top + 0.23), seed=9)
    parts.append(jug)
    parts.append(_set(L.prim("cone", loc=(0.12, 0.08, top + 0.21), rot=(0, -60, 0), radius1=0.025, depth=0.05, vertices=4),
                      CERAMIC, ao=0.0))
    parts.append(_set(_path_tube([(0.23, 0.08, top + 0.19), (0.26, 0.08, top + 0.15), (0.23, 0.08, top + 0.08)], 0.01, 4,
                                 hint=(0, 1, 0)), CERAMIC, ao=0.0))
    # towel over the left rail
    tx = -(hx + 0.04)

    for flip in (False, True):
        tw = _sheet(4, 3, lambda u, v: Vector((tx + (-0.014 if u < 0.5 else 0.014), -hy + 0.07 + v * (2 * hy - 0.14),
                                               top - 0.07 - abs(u - 0.5) * (0.6 if u < 0.5 else 0.4))), "towel", flip=flip)
        _paint_poly(tw, lambda poly, co: LINEN if int((co.z) * 30) % 5 else L.mix(LINEN, ROSE, 0.6), var=0.06, ao=0.0,
                    top=0.05, seed=10)
        parts.append(tw)
    parts.append(L.part("cyl", CERAMIC, loc=(-0.17, 0.11, top + 0.006), radius=0.04, depth=0.01, vertices=10))
    parts.append(_box((-0.17, 0.11, top + 0.022), (0.03, 0.02, 0.012), L.hexc("#D8CDA0"), bev=0.006, jit=0.0))
    _done(parts, "ph_int_washbasin", (), 40)


def cat():
    """A sleeping, curled-up cat (dark grey): round body, head tucked on the paws, ears, tail
    wrapped around the front, closed eyes, lighter muzzle."""
    L.reset(560)
    parts = []
    body = L.prim("sphere", loc=(0, 0, 0.075), radius=1.0, segments=12, ring_count=8, scale=(0.19, 0.15, 0.085))
    for v in body.data.vertices:
        v.co.z = max(0.0, v.co.z)
        if v.co.x > 0.08:  # the hip bulge at the back (+X)
            v.co.z += 0.02 * (v.co.x - 0.08) / 0.11
    L.jitter(body, 0.006, 8.0, 1)
    _paint_poly(body, lambda poly, co: L.scale_c(CAT_FUR, 0.82) if int((co.x + 1) * 28) % 4 == 0 else CAT_FUR,
                var=0.1, ao=0.35, top=0.18,
                zr=(0, 0.17), freq=10.0, seed=1)
    parts.append(body)
    # head tucked at the front-left, chin on the paws
    hc = Vector((-0.14, -0.07, 0.1))
    head = L.prim("sphere", loc=hc, radius=1.0, segments=10, ring_count=7, scale=(0.075, 0.07, 0.06))
    L.jitter(head, 0.004, 10.0, 2)
    _paint_poly(head, lambda poly, co: CAT_LIGHT if (co.y < hc.y - 0.03 and co.z < hc.z) else CAT_FUR, var=0.08, ao=0.1,
                top=0.15, zr=(0, 0.17), seed=2)
    parts.append(head)
    for sx in (-1, 1):  # ears
        e = L.prim("cone", loc=(hc.x + sx * 0.04, hc.y + 0.015, hc.z + 0.055), rot=(10, sx * -20, 0), radius1=0.025,
                   depth=0.045, vertices=4)
        _paint_poly(e, lambda poly, co: CAT_PINK if poly.normal.y < -0.4 else CAT_FUR, var=0.05, ao=0.0, seed=3)
        parts.append(e)
        # closed eyes: two little dark crescents
        parts.append(_set(L.prim("cube", loc=(hc.x + sx * 0.028, hc.y - 0.064, hc.z + 0.012), rot=(0, sx * 12, 0),
                                 scale=(0.012, 0.002, 0.0025)), L.hexc("#1E1C1C"), ao=0.0))
    parts.append(_set(L.prim("sphere", loc=(hc.x, hc.y - 0.07, hc.z - 0.008), radius=0.008, segments=5, ring_count=3),
                      CAT_PINK, ao=0.0))
    for k in range(2):  # front paws under the chin
        parts.append(_set(L.prim("sphere", loc=(hc.x + 0.03 - k * 0.05, hc.y - 0.035, 0.03), radius=1.0, segments=6,
                                 ring_count=4, scale=(0.035, 0.028, 0.022)), CAT_LIGHT, ao=0.0, top=0.1))
    # tail wraps around the front
    pts = []
    for i in range(9):
        a = math.radians(-10 - i * 22)
        pts.append((0.19 * math.cos(a) * 1.1, 0.15 * math.sin(a) * 1.18, 0.028 + 0.004 * i))
    tail = _path_tube(pts, 0.03, 6, hint=(0, 0, 1))
    for v in tail.data.vertices:
        v.co.z = max(0.004, v.co.z)
    _paint_poly(tail, lambda poly, co: CAT_LIGHT if co.x < -0.12 and co.y < 0.0 else
                (L.scale_c(CAT_FUR, 0.8) if int(math.atan2(co.y, co.x) * 6) % 2 else CAT_FUR),
                var=0.08, ao=0.0, top=0.2, seed=4)
    parts.append(tail)
    _done(parts, "ph_int_cat", (), 60)


ASSETS = (room, bed, stove, table, chair, desk, chest, shelf, rug, herbs, coat_hook, candles, picture, broom, bucket,
          washbasin, cat)


def build(names=None):
    """Build all interior assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
