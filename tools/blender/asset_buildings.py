"""Gravekeeper's hut, change round 2 (docs/VERTICAL_SLICE_DESIGN.md section 11).

~5.0 x 4.0 m footprint (x x y), front (door) faces -Y in Blender = +Z in Godot, pivot bottom
centre.  Same identity as the approved Phase 1 hut - stone foundation, vertical planks, a crooked
sagging shingle roof with moss, a leaning stone chimney, warm windows, a lantern by the door - but
lived-in: a little hood over the door with a horseshoe, iron strap hinges, shutters and a flower box
under the front window, a bench, a rain barrel, crossed gable boards and a crow on the ridge.

Where the openings are matches the interior (asset_interior.py, ph_int_room):
  door      front wall, centre x = DOOR_X, 1.0 x 2.0 m
  window 1  front wall, right of the door (inside it is cut away with the front wall)
  window 2  left gable wall (-X), above the bed
  window 3  back wall, above the desk (no light marker: the camera never sees it)
  chimney   back right, above the stove

Markers: door_outside (ground, 0.6 m in front of the door), light_lantern (below the lantern
glass: no self-shadowing), light_window_1, light_window_2 (inside, behind the panes; the window
lights cast no shadows there).
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
from asset_props_slice import _link, _plank, _rbox, _stick, _tint_up, _paint_fn

# --- palette (ART_DIRECTION.md section 3 + Phase 1 hut colours) ----------------
STONE = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_WARM = L.hexc("#857C72")
MORTAR = L.hexc("#4B4A47")
WOOD = L.hexc("#6E5238")
WOOD_DARK = L.hexc("#4A3626")
WOOD_OLD = L.hexc("#6B5E50")
WOOD_FRESH = L.hexc("#9C7B55")
ROOF = L.hexc("#5A4E48")
ROOF_DARK = L.hexc("#463D38")
ROOF_LIGHT = L.hexc("#6E625A")
MOSS = L.hexc("#5E7148")
MOSS_LIGHT = L.hexc("#71804F")
IRON = L.hexc("#3A3C40")
RUST = L.hexc("#6A4A3A")
SHUTTER = L.hexc("#56634A")        # faded moss-green paint
CLAY = L.hexc("#8A5A44")
EARTH = L.hexc("#4E3B2C")
WATER = L.hexc("#1F2A3A")          # ink blue (palette: shadow / night)
LEAF = L.hexc("#4E6440")
CROW = L.hexc("#23262E")
FLOWERS = (L.hexc("#B07A7A"), L.hexc("#CDBB78"), L.hexc("#8C7FA0"), L.hexc("#D8D2C0"))

# --- dimensions (m) ------------------------------------------------------------
WX, WY = 2.4, 1.9      # wall centre lines (planks 0.08 thick -> outer faces at 2.44 / 1.94)
F = 0.4                # foundation height = inner floor level
H = 2.5                # wall height above the foundation (eaves at F + H)
GH = 1.7               # gable height above the eaves
EAVE = F + H
RIDGE = EAVE + GH
PITCH = math.atan2(GH, WY)
ROOF_X = 2.82          # roof reaches this far along x (gable overhang)
OVERHANG = 0.36        # eave overhang (small: at 45 deg the eave must not hide door and window)
SAG = 0.12             # the ridge sags this much in the middle
DOOR_X, DOOR_W, DOOR_H = -0.9, 1.0, 2.0
WIN1_X = 1.25          # front window centre (x)
WIN2_Y = 0.6           # left window centre (y)
WIN3_X = 0.1           # back window centre (x)
WIN_W, WIN_Z0, WIN_Z1 = 0.8, F + 0.9, F + 1.68


def roof_z(y: float) -> float:
    """Height of the roof deck above wall line y (no sag)."""
    return RIDGE - abs(y) * math.tan(PITCH)


# --- walls ---------------------------------------------------------------------

def _plank_colour(seed: int):
    r = random.random()
    base = WOOD_OLD if r < 0.18 else (WOOD_DARK if r < 0.3 else WOOD)
    return L.scale_c(base, random.uniform(0.84, 1.12))


def _paint_plank(obj, color, z0: float, z1: float, seed: int, moss: float = 0.35) -> None:
    """Board colour: grain streaks, darker and mossy at the foot, sun-bleached at the top."""
    off = Vector((seed * 1.7, seed * 2.9, 0))

    def fn(co, vi):
        h = max(0.0, min(1.0, (co.z - z0) / max(1e-6, z1 - z0)))
        c = L.scale_c(color, (1.0 + noise.noise(Vector((co.x * 9, co.y * 9, co.z * 1.2)) + off) * 0.12)
                      * (1.0 - 0.38 * (1.0 - h) ** 3) * (1.0 + 0.08 * h))
        m = max(0.0, noise.noise(co * 2.2 + off) + 0.25) * moss * (1.0 - h) ** 4
        return L.mix(c, MOSS, min(0.8, m * 2.0))
    _paint_fn(obj, fn)
    L.set_mat(obj, L.MAT_PAINTED)


def _board(a0: float, a1: float, plane: float, z0: float, z1a: float, z1b: float, along: str, out: float,
           seed: int, thick: float = 0.08):
    """One vertical board between a0..a1 along the wall; top z1a at a0, z1b at a1 (gable slope).
    `out` = outward direction of the wall (+1/-1)."""
    lean = random.uniform(-0.012, 0.012)
    g = random.uniform(0.0, 0.012)  # a small gap to the neighbour
    a0, a1 = a0 + g, a1 - g
    zb = z0 - random.uniform(0.0, 0.03)
    pts = [(a0, zb), (a1, zb), (a1, z1b + random.uniform(-0.03, 0.02)), (a0, z1a + random.uniform(-0.03, 0.02))]
    t = thick * random.uniform(0.85, 1.1)
    if along == "x":  # front/back wall: extrude along y
        o = L.prism_x([(p[0], p[1]) for p in pts], 0.0, t)
        for v in o.data.vertices:  # prism_x builds in (y, z) around x: swap into (x, y)
            x, y, z = v.co.x, v.co.y, v.co.z
            v.co = Vector((y + lean * (z - z0), plane + x + out * random.uniform(0, 0.004), z))
    else:
        o = L.prism_x([(p[0], p[1]) for p in pts], plane, t)
        for v in o.data.vertices:
            v.co.y += lean * (v.co.z - z0)
    col = _plank_colour(seed)
    _paint_plank(o, col, z0, max(z1a, z1b), seed)
    return o


def _wall(parts, along: str, a0: float, a1: float, plane: float, out: float, top, openings, seed: int,
          width: float = 0.21) -> None:
    """Vertical-plank wall from a0 to a1 at `plane`; top(a) gives the board top height;
    openings = [(c0, c1, z0, z1)] leave holes (boards are split below/above)."""
    n = max(2, round((a1 - a0) / width))
    step = (a1 - a0) / n
    for i in range(n):
        b0, b1 = a0 + i * step, a0 + (i + 1) * step
        t0, t1 = top(b0), top(b1)
        cut = [op for op in openings if b1 > op[0] + 0.01 and b0 < op[1] - 0.01]
        if not cut:
            parts.append(_board(b0, b1, plane, F, t0, t1, along, out, seed + i))
            continue
        c0, c1, z0, z1 = cut[0]
        if z0 > F + 0.05:
            parts.append(_board(b0, b1, plane, F, z0, z0, along, out, seed + i))
        parts.append(_board(b0, b1, plane, z1, t0, t1, along, out, seed + 50 + i))


def _beam(p0, p1, half_w: float, half_h: float, color=WOOD_DARK, seed: int = 0):
    """Squared timber between two points (horizontal or vertical), hand-hewn wobble."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    c = (p0 + p1) / 2
    if abs(d.z) > max(abs(d.x), abs(d.y)):
        half = (half_w, half_w, d.length / 2)
    elif abs(d.x) >= abs(d.y):
        half = (d.length / 2, half_w, half_h)
    else:
        half = (half_w, d.length / 2, half_h)
    o = L.prim("cube", loc=c, scale=half)
    if max(half) > 0.6:
        L.subdivide(o, 1)
    L.jitter(o, 0.008, 2.5, seed)
    L.paint(o, L.scale_c(color, random.uniform(0.9, 1.08)), var=0.16, ao=0.35, zrange=(0, EAVE), seed=seed)
    L.set_mat(o, L.MAT_PAINTED)
    return o


# --- foundation ------------------------------------------------------------------

def _foundation(parts) -> None:
    """Dark mortar core with two courses of rough stones on the front and the sides."""
    core = L.prim("cube", loc=(0, 0, F / 2 - 0.02), scale=(WX + 0.08, WY + 0.06, F / 2 + 0.02))
    L.subdivide(core, 2)
    L.jitter(core, 0.015, 2.0, 1)
    L.paint(core, MORTAR, var=0.2, ao=0.4, zrange=(0, F), seed=2, hue_shift=MOSS)
    L.set_mat(core, L.MAT_PAINTED)
    parts.append(core)

    def course(a0, a1, along, plane, out, seed):
        for row in range(2):
            z0, z1 = row * 0.2, row * 0.2 + 0.2
            a = a0 + (0.12 if row else 0.0)
            k = 0
            while a < a1 - 0.08:
                ln = min(random.uniform(0.3, 0.52), a1 - a)
                c = a + ln / 2
                depth = random.uniform(0.08, 0.12)
                h = (z1 - z0) / 2 * random.uniform(0.84, 0.98)
                if along == "x":
                    loc, half = (c, plane + out * depth / 2, (z0 + z1) / 2), (ln / 2 * 0.95, depth, h)
                else:
                    loc, half = (plane + out * depth / 2, c, (z0 + z1) / 2), (depth, ln / 2 * 0.95, h)
                s = L.prim("cube", loc=loc, scale=half, rot=(random.uniform(-3, 3), random.uniform(-3, 3), 0))
                L.jitter(s, 0.02, 4.0, seed + k)
                col = random.choice((STONE, STONE, STONE_DARK, STONE_WARM))
                L.paint(s, L.scale_c(col, random.uniform(0.82, 1.0)), var=0.22, ao=0.45, top=0.1,
                        zrange=(-0.05, F), seed=seed + k)
                _tint_up(s, MOSS, 0.9, 0.2, freq=3.0, seed=seed + k)
                L.set_mat(s, L.MAT_PAINTED)
                parts.append(s)
                a += ln
                k += 1
            seed += 40
    course(-WX - 0.1, WX + 0.1, "x", -WY - 0.02, -1, 100)
    course(-WY + 0.02, WY, "y", -WX - 0.06, -1, 300)
    course(-WY + 0.02, WY, "y", WX + 0.06, 1, 500)


# --- roof --------------------------------------------------------------------------

def _smooth01(e0: float, e1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def _moss(x: float, t: float, side: int, slope: float) -> float:
    """Moss amount 0..1 on the roof: a few coherent patches, a mossy band along the eaves
    and the gable edges, more on the (shady) back."""
    n = 0.5 + 0.7 * noise.noise(Vector((x * 0.5, t * 0.75 + side * 5.0, 0.7)))
    patch = _smooth01(0.58, 0.85, n)
    eave = _smooth01(0.72, 1.0, t / slope) * (0.35 + 0.5 * _smooth01(0.3, 0.7, n))
    edge = _smooth01(0.86, 1.0, abs(x) / ROOF_X) * 0.35
    return max(0.0, min(1.0, patch + eave + edge + (0.25 if side > 0 else 0.0)))


def _shingle_colour(x: float, y: float, t: float, side: int, row: int, rows: int):
    """Per-shingle colour: weathered grey-brown with a soft spread, moss from _moss(), now
    and then a newer, lighter replacement (never loud)."""
    base = L.mix(ROOF, random.choice((ROOF_DARK, ROOF_LIGHT, ROOF_DARK, ROOF_DARK)), random.uniform(0.1, 0.5))
    base = L.scale_c(base, random.uniform(0.96, 1.04))
    if random.random() < 0.025:
        return L.mix(ROOF_LIGHT, WOOD_OLD, 0.5)  # patched
    slope = (WY + OVERHANG) / math.cos(PITCH)
    m = _moss(x, t, side, slope)
    return L.mix(base, L.mix(MOSS, L.hexc("#44543A"), random.uniform(0.3, 0.8)), min(0.75, m * random.uniform(0.85, 1.0)))


def _roof(parts) -> list:
    """Deck, staggered shingle rows (each shingle its own slightly tilted board), ridge log,
    crossed gable boards, fascia.  Returns the roof parts (sagged by the caller)."""
    roof = []
    slope = (WY + OVERHANG) / math.cos(PITCH)
    nrm = {s: Vector((0, s * math.sin(PITCH), math.cos(PITCH))) for s in (-1, 1)}
    down = {s: Vector((0, s * math.cos(PITCH), -math.sin(PITCH))) for s in (-1, 1)}
    top = Vector((0, 0, RIDGE))
    for s in (-1, 1):  # deck under the shingles (dark, hides every gap)
        c = top + down[s] * (slope / 2) + nrm[s] * 0.01
        deck = L.prim("cube", loc=c, scale=(ROOF_X - 0.05, slope / 2, 0.02),
                      rot=(math.degrees(-s * PITCH), 0, 0))
        L.subdivide(deck, 2)
        L.paint(deck, ROOF_DARK, var=0.15, ao=0.0, top=0.0, seed=3)
        L.set_mat(deck, L.MAT_PAINTED)
        roof.append(deck)
    rows = 11
    step = slope / (rows - 0.3)
    sw = 0.34
    bm = bmesh.new()
    shade = []     # per vertex: brightness factor (upper edge in the shadow of the row above)
    cols = []      # per shingle colour
    for s in (-1, 1):
        for r in range(rows):
            t = 0.1 + r * step           # distance of the shingle centre from the ridge (along the slope)
            ln = step * 1.6
            x = -ROOF_X - (sw * 0.5 if r % 2 else 0.0) * random.uniform(0.8, 1.0)
            while x < ROOF_X - 0.03:
                w = min(sw * random.uniform(0.7, 1.25), ROOF_X - x)
                if w < 0.08:
                    break
                x0, x1 = max(x, -ROOF_X), x + w
                cx = (x0 + x1) / 2
                a = random.uniform(-0.03, 0.03)                    # a little skew
                tt = t + random.uniform(-0.025, 0.035)
                lift = random.uniform(0.028, 0.06)                 # the butt rests on the row below
                u = Vector((1, 0, 0))
                base = top + down[s] * tt + nrm[s] * 0.05
                hw = (x1 - x0) / 2 * 0.995
                up_l = base + u * (cx - hw) - down[s] * (ln / 2) + Vector((0, 0, 0))
                up_r = base + u * (cx + hw) - down[s] * (ln / 2)
                lo_r = base + u * (cx + hw + a) + down[s] * (ln / 2 + random.uniform(-0.02, 0.02)) + nrm[s] * lift
                lo_l = base + u * (cx - hw + a) + down[s] * (ln / 2 + random.uniform(-0.02, 0.02)) + nrm[s] * lift
                vs = [bm.verts.new(p) for p in (up_l, up_r, lo_r, lo_l)]
                bl = bm.verts.new(lo_l - nrm[s] * (lift + 0.04))
                br = bm.verts.new(lo_r - nrm[s] * (lift + 0.04))
                shade += [0.56, 0.56, 1.0, 1.0, 0.3, 0.3]
                f = bm.faces.new(vs)
                f.normal_update()
                if f.normal.dot(nrm[s]) < 0:
                    f.normal_flip()
                g = bm.faces.new((vs[3], vs[2], br, bl))
                g.normal_update()
                if g.normal.dot(down[s]) < 0:
                    g.normal_flip()
                cols.append(_shingle_colour(cx, base.y, tt, s, r, rows))
                x = x1
    me = bpy.data.meshes.new("shingles")
    bm.to_mesh(me)
    bm.free()
    sh = bpy.data.objects.new("shingles", me)
    bpy.context.collection.objects.link(sh)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        c = cols[poly.index // 2]
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            k = shade[vi] * (1.0 + noise.noise(co * 3.1) * 0.05 + noise.noise(co * 0.6 + Vector((4, 2, 0))) * 0.12)
            cc = L.scale_c(c, k)
            attr.data[li].color = (L._to_lin(cc[0]), L._to_lin(cc[1]), L._to_lin(cc[2]), 1.0)
    L.set_mat(sh, L.MAT_PAINTED)
    roof.append(sh)
    # moss cushions where the patches are thickest
    placed = 0
    for i in range(400):
        if placed >= 3:
            break
        s = 1
        t = random.uniform(0.4, slope - 0.15)
        x = random.uniform(-ROOF_X + 0.25, ROOF_X - 0.25)
        if _moss(x, t, s, slope) < 0.75:
            continue
        c = top + down[s] * t + nrm[s] * 0.1
        c.x = x
        c = top + down[s] * t + nrm[s] * 0.06
        c.x = x
        m = L.prim("ico", loc=c, radius=random.uniform(0.1, 0.15), subdivisions=2, scale=(1.5, 1.15, 0.75))
        L.jitter(m, 0.04, 6.0, 60 + i)
        L.paint(m, L.mix(MOSS, L.hexc("#4B5E3A"), random.uniform(0.2, 0.7)), var=0.3, ao=0.45, top=0.15, seed=60 + i,
                hue_shift=MOSS_LIGHT)
        L.set_mat(m, L.MAT_PAINTED)
        roof.append(m)
        placed += 1
    # ridge: a slightly crooked log with a moss line
    ridge = L.tube((-ROOF_X - 0.12, 0, RIDGE + 0.1), (ROOF_X + 0.12, 0, RIDGE + 0.1), 0.085, 8)
    L.subdivide(ridge, 2)
    L.jitter(ridge, 0.02, 1.5, 7)
    L.paint(ridge, WOOD_DARK, var=0.2, ao=0.1, top=0.2, seed=8, hue_shift=WOOD_OLD)
    _tint_up(ridge, MOSS, 0.7, 0.5, freq=2.0, seed=9)
    L.set_mat(ridge, L.MAT_PAINTED)
    roof.append(ridge)
    # crossed gable boards (bargeboards) on both gables, tips crossing over the ridge
    for sx in (-1, 1):
        x = sx * (ROOF_X + 0.02)
        for s in (-1, 1):
            a = top + down[s] * (slope + 0.04) + nrm[s] * 0.08
            b = top - down[s] * 0.1 + nrm[s] * 0.08
            bb = L.prim("cube", loc=(a + b) / 2, scale=(0.06, (a - b).length / 2, 0.1),
                        rot=(math.degrees(-s * PITCH), 0, 0))
            bb.data.transform(Matrix.Translation((x, 0, 0)))
            L.subdivide(bb, 1)
            L.jitter(bb, 0.01, 2.0, 70 + s + sx)
            L.paint(bb, WOOD_DARK, var=0.18, ao=0.1, seed=71 + s)
            L.set_mat(bb, L.MAT_PAINTED)
            roof.append(bb)
    # fascia along both eaves
    for s in (-1, 1):
        e = top + down[s] * (slope - 0.02) + nrm[s] * 0.0
        fa = L.prim("cube", loc=(0, e.y, e.z - 0.03), scale=(ROOF_X, 0.025, 0.07))
        L.subdivide(fa, 2)
        L.jitter(fa, 0.01, 2.0, 80 + s)
        L.paint(fa, WOOD_DARK, var=0.2, ao=0.1, seed=81)
        L.set_mat(fa, L.MAT_PAINTED)
        roof.append(fa)
    return roof


def _sag(objs) -> None:
    """The old roof sags: the middle of the ridge most, the eaves a little."""
    for o in objs:
        for v in o.data.vertices:
            k = max(0.0, 1.0 - (v.co.x / (ROOF_X + 0.2)) ** 2)
            h = max(0.0, min(1.0, (v.co.z - EAVE + 0.4) / (RIDGE - EAVE + 0.4)))
            v.co.z -= SAG * k * (0.3 + 0.7 * h)


# --- chimney ---------------------------------------------------------------------------

def _chimney(parts) -> None:
    """Leaning stack of rough stones (back right) with a cap, a clay pot and a sooty smoke hole."""
    cx, cy = 1.55, 0.95
    z0, z1 = roof_z(cy) - 0.25, RIDGE + 0.7
    hw = 0.3
    lean = Vector((0.1, 0.04, 0))
    core = L.prim("cube", loc=(cx, cy, (z0 + z1) / 2), scale=(hw - 0.03, hw - 0.03, (z1 - z0) / 2))
    L.subdivide(core, 1)
    for v in core.data.vertices:
        v.co += lean * ((v.co.z - z0) / (z1 - z0)) ** 1.5
    L.paint(core, MORTAR, var=0.2, ao=0.2, seed=3)
    L.set_mat(core, L.MAT_PAINTED)
    parts.append(core)
    z = z0
    row = 0
    while z < z1 - 0.08:
        h = random.uniform(0.13, 0.22)
        f = ((z + h / 2 - z0) / (z1 - z0)) ** 1.5
        off = lean * f
        for face in (0, 1, 3):
            a = -hw - (0.06 if row % 2 else 0.0)
            while a < hw - 0.04:
                ln = min(random.uniform(0.17, 0.34), hw + 0.03 - a)
                c = a + ln / 2
                d = random.uniform(0.04, 0.065)
                hh = h / 2 * random.uniform(0.82, 0.98)
                if face == 0:
                    loc, half = (cx + c, cy - hw, z + h / 2), (ln / 2 * 0.94, d, hh)
                elif face == 1:
                    loc, half = (cx + hw, cy + c, z + h / 2), (d, ln / 2 * 0.94, hh)
                else:
                    loc, half = (cx - hw, cy + c, z + h / 2), (d, ln / 2 * 0.94, hh)
                st = L.prim("cube", loc=Vector(loc) + off, scale=half,
                            rot=(random.uniform(-5, 5), random.uniform(-5, 5), random.uniform(-4, 4)))
                L.jitter(st, 0.02, 6.0, row * 17 + face * 5 + int(a * 10))
                col = random.choice((STONE_DARK, STONE_DARK, STONE_WARM, L.hexc("#5A5650")))
                soot = 0.75 + 0.25 * (1.0 - f)  # darker towards the smoky top
                L.paint(st, L.scale_c(col, random.uniform(0.8, 1.0) * soot), var=0.25, ao=0.15, top=0.1,
                        seed=row * 9 + face)
                if row < 2 or random.random() < 0.2:
                    _tint_up(st, MOSS, 1.0, 0.1, freq=3.0, seed=row + face)
                L.set_mat(st, L.MAT_PAINTED)
                parts.append(st)
                a += ln
        z += h
        row += 1
    top = Vector((cx, cy, z1)) + lean
    # cap: four slabs around a sooty hole
    for i, (dx, dy, sx, sy) in enumerate(((0, -1, 1, 0.3), (0, 1, 1, 0.3), (-1, 0, 0.3, 0.55), (1, 0, 0.3, 0.55))):
        slab = L.prim("cube", loc=top + Vector((dx * (hw - 0.02), dy * (hw - 0.02), 0.035)),
                      scale=((hw + 0.07) * sx, (hw + 0.07) * sy, 0.035))
        L.jitter(slab, 0.012, 4.0, 90 + i)
        L.paint(slab, STONE_DARK, var=0.2, ao=0.1, seed=90 + i, hue_shift=MOSS)
        L.set_mat(slab, L.MAT_PAINTED)
        parts.append(slab)
    parts.append(L.part("cube", L.hexc("#15110E"), loc=top + Vector((0, 0, 0.02)), scale=(hw - 0.08, hw - 0.08, 0.03)))
    # leaning clay pot with a black mouth
    pot = L.prim("cyl", radius=0.13, depth=0.3, vertices=10)
    L.taper(pot, -0.15, 0.15, 0.78)
    for v in pot.data.vertices:
        v.co += Vector((0.035, 0.0, 0.0)) * (v.co.z + 0.15) / 0.3
    pot.data.transform(Matrix.Translation(top + Vector((0.05, 0.02, 0.2))))
    L.jitter(pot, 0.006, 5.0, 95)
    L.paint(pot, CLAY, var=0.18, ao=0.3, top=0.05, seed=95, hue_shift=L.hexc("#3A2E28"))
    L.set_mat(pot, L.MAT_PAINTED)
    parts.append(pot)
    parts.append(L.part("cyl", L.hexc("#120E0C"), loc=top + Vector((0.095, 0.02, 0.355)), radius=0.085, depth=0.02,
                        vertices=10))


# --- openings ----------------------------------------------------------------------------

def _window(parts, c: Vector, axis: str, out: float, w: float = WIN_W, shutters: bool = False, box: bool = False,
            seed: int = 0) -> None:
    """Window at centre c on a wall (axis = wall direction 'x' or 'y', out = outward sign):
    warm pane, frame, cross muntins, sill; optional open shutters and a flower box."""
    hz = (WIN_Z1 - WIN_Z0) / 2

    def at(a, n, z):  # along-wall offset a, outward offset n, height z -> world
        return Vector((c.x + a, c.y + out * n, z)) if axis == "x" else Vector((c.x + out * n, c.y + a, z))

    def half(a, n, z):
        return (a, n, z) if axis == "x" else (n, a, z)
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=at(0, -0.02, c.z), scale=half(w / 2, 0.01, hz)))
    fw = 0.055
    for sa in (-1, 1):  # frame posts
        parts.append(_plank(at(sa * (w / 2 + fw / 2), 0.035, c.z), half(fw / 2 + 0.01, 0.04, hz + fw), WOOD_DARK,
                            seed=seed + sa))
    parts.append(_plank(at(0, 0.055, WIN_Z1 + fw / 2), half(w / 2 + fw + 0.04, 0.04, fw / 2 + 0.01), WOOD_DARK,
                        seed=seed + 3, rot=(0, random.uniform(-2, 2), 0) if axis == "x" else (random.uniform(-2, 2), 0, 0)))
    parts.append(_plank(at(0, 0.075, WIN_Z0 - 0.03), half(w / 2 + fw + 0.07, 0.07, 0.03), WOOD_DARK, seed=seed + 4))
    parts.append(L.part("cube", WOOD_DARK, loc=at(0, 0.02, c.z), scale=half(w / 2, 0.02, 0.022)))
    parts.append(L.part("cube", WOOD_DARK, loc=at(0, 0.02, c.z), scale=half(0.022, 0.02, hz)))
    if shutters:
        for sa in (-1, 1):  # open shutters, flat against the wall beside the frame
            sc = sa * (w / 2 + fw + 0.22)
            for b in range(3):
                parts.append(_plank(at(sc + (b - 1) * 0.135, 0.07, c.z), half(0.066, 0.018, hz + 0.02),
                                    SHUTTER, seed=seed + 10 + b + sa * 5, jit=0.004, ao=0.15, var=0.2,
                                    hue_shift=L.hexc("#6D7760")))
            for z in (c.z - hz * 0.6, c.z + hz * 0.6):
                parts.append(_plank(at(sc, 0.092, z), half(0.21, 0.012, 0.03), L.scale_c(SHUTTER, 0.8),
                                    seed=seed + 20 + sa))
                parts.append(L.part("cube", IRON, loc=at(sa * (w / 2 + fw + 0.02), 0.1, z),
                                    scale=half(0.05, 0.008, 0.014)))
            # a crescent moon cut into each shutter: a dark sliver
            parts.append(L.part("cube", L.hexc("#1A1512"), loc=at(sc, 0.09, c.z + 0.1), scale=half(0.035, 0.004, 0.07)))
    if box:
        _flower_box(parts, at, half, w, seed + 40)


def _flower_box(parts, at, half, w: float, seed: int) -> None:
    """Planter under the window on two brackets: herbs and a few muted flowers."""
    z = WIN_Z0 - 0.17
    parts.append(_plank(at(0, 0.2, z), half(w / 2 + 0.08, 0.1, 0.09), WOOD, seed=seed, cuts=1))
    parts.append(L.part("cube", EARTH, loc=at(0, 0.2, z + 0.085), scale=half(w / 2 + 0.05, 0.08, 0.01)))
    for sa in (-1, 1):
        parts.append(_stick(at(sa * w * 0.35, 0.03, z - 0.25), at(sa * w * 0.35, 0.25, z - 0.08), 0.02, WOOD_DARK,
                            verts=4, seed=seed + sa))
    for i in range(9):  # leafy clumps
        a = -w / 2 + 0.03 + i * (w / 8) + random.uniform(-0.03, 0.03)
        s = L.prim("ico", loc=at(a, 0.2 + random.uniform(-0.04, 0.04), z + 0.13 + random.uniform(0, 0.05)),
                   radius=random.uniform(0.07, 0.1), subdivisions=1, scale=(1.0, 1.0, 1.25))
        L.jitter(s, 0.025, 6.0, seed + i)
        L.paint(s, L.mix(LEAF, MOSS_LIGHT, random.random() * 0.7), var=0.3, ao=0.5, top=0.35, seed=seed + i)
        L.set_mat(s, L.MAT_PAINTED)
        parts.append(s)
    for i in range(11):  # flower heads
        a = random.uniform(-w / 2, w / 2)
        col = FLOWERS[i % len(FLOWERS)]
        parts.append(L.part("ico", col, loc=at(a, 0.2 + random.uniform(-0.07, 0.07), z + 0.2 + random.uniform(0, 0.08)),
                            radius=random.uniform(0.025, 0.035), subdivisions=1, paint_kw={"ao": 0.1, "var": 0.15}))


def _door(parts) -> None:
    """Plank door with a Z brace, strap hinges with curled ends, ring handle and a horseshoe
    for luck; frame, threshold, two stone steps.  The eave above is its overhang."""
    y = -WY - 0.02
    x0, x1 = DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2
    for i in range(5):  # door boards
        bx = x0 + (i + 0.5) * DOOR_W / 5
        parts.append(_plank((bx, y - 0.03, F + DOOR_H / 2), (DOOR_W / 10 * 0.96, 0.03, DOOR_H / 2 - 0.01),
                            L.scale_c(WOOD, random.uniform(0.72, 0.95)), seed=200 + i, cuts=1, ao=0.3,
                            zrange=(F, F + DOOR_H)))
    for z in (F + 0.35, F + DOOR_H - 0.35):  # ledges
        parts.append(_plank((DOOR_X, y - 0.075, z), (DOOR_W / 2 - 0.06, 0.018, 0.06), WOOD_DARK, seed=210))
    d = math.degrees(math.atan2(DOOR_H - 0.7, DOOR_W - 0.16))
    parts.append(_plank((DOOR_X, y - 0.075, F + DOOR_H / 2), (math.hypot(DOOR_H - 0.7, DOOR_W - 0.16) / 2, 0.016, 0.05),
                        WOOD_DARK, seed=211, rot=(0, -d, 0)))
    for z in (F + 0.35, F + DOOR_H - 0.35):  # strap hinges from the left edge, curled tips
        parts.append(L.part("cube", IRON, loc=(x0 + 0.3, y - 0.1, z), scale=(0.3, 0.008, 0.025),
                            paint_kw={"hue_shift": RUST, "var": 0.3}))
        parts.append(L.part("torus", IRON, loc=(x0 + 0.62, y - 0.1, z), rot=(90, 0, 0), major_radius=0.03,
                            minor_radius=0.009, major_segments=6, minor_segments=3))
        for k in range(3):
            parts.append(L.part("cube", IRON, loc=(x0 + 0.08 + k * 0.18, y - 0.108, z), scale=(0.011, 0.005, 0.011)))
    parts.append(L.part("torus", IRON, loc=(x1 - 0.14, y - 0.12, F + 1.0), rot=(90, 0, 0), major_radius=0.05,
                        minor_radius=0.01, major_segments=8, minor_segments=3))
    parts.append(L.part("cube", IRON, loc=(x1 - 0.14, y - 0.1, F + 1.06), scale=(0.035, 0.008, 0.05)))
    parts.append(L.part("cube", L.hexc("#15110E"), loc=(x1 - 0.14, y - 0.105, F + 0.9), scale=(0.008, 0.004, 0.018)))
    # frame + threshold
    for sx in (-1, 1):
        parts.append(_beam((DOOR_X + sx * (DOOR_W / 2 + 0.06), y - 0.04, F), (DOOR_X + sx * (DOOR_W / 2 + 0.06), y - 0.04,
                           F + DOOR_H + 0.1), 0.065, 0.065, seed=220 + sx))
    parts.append(_beam((x0 - 0.2, y - 0.05, F + DOOR_H + 0.1), (x1 + 0.2, y - 0.05, F + DOOR_H + 0.1), 0.07, 0.075,
                       seed=223))
    parts.append(_plank((DOOR_X, y - 0.05, F + 0.02), (DOOR_W / 2 + 0.1, 0.09, 0.025), WOOD_OLD, seed=224))
    # horseshoe above the door (luck), points up
    hs = L.prim("torus", major_radius=0.07, minor_radius=0.013, major_segments=10, minor_segments=3)
    bm = bmesh.new()
    bm.from_mesh(hs.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.045], context="VERTS")
    bm.to_mesh(hs.data)
    bm.free()
    hs.rotation_euler = (math.radians(90), 0, 0)
    L._apply(hs)
    hs.data.transform(Matrix.Translation((DOOR_X + 0.05, y - 0.1, F + 1.45)))
    L.paint(hs, IRON, var=0.3, hue_shift=RUST, seed=225)
    L.set_mat(hs, L.MAT_PAINTED)
    parts.append(hs)
    # two rough stone steps up to the threshold
    for i, (dy, z, w) in enumerate(((0.17, 0.27, 0.62), (0.4, 0.13, 0.72))):
        st = L.prim("cube", loc=(DOOR_X + random.uniform(-0.03, 0.03), y - dy, z / 2 + 0.01),
                    scale=(w, 0.13, z / 2 + 0.01), rot=(0, 0, random.uniform(-3, 3)))
        L.subdivide(st, 2)
        L.jitter(st, 0.02, 3.0, 250 + i)
        L.paint(st, STONE_DARK, var=0.25, ao=0.4, zrange=(0, F), seed=250 + i, hue_shift=STONE_WARM)
        _tint_up(st, MOSS, 0.5, 0.6, freq=3.0, seed=252 + i)
        L.set_mat(st, L.MAT_PAINTED)
        parts.append(st)


def _lantern(parts, pos: Vector) -> None:
    """Wall lantern on an iron bracket: four warm panes in an iron cage, cap and ring."""
    y = -WY - 0.04
    parts.append(L.part("cube", IRON, loc=(pos.x, y - 0.02, pos.z + 0.27), scale=(0.04, 0.02, 0.1)))
    parts.append(_stick((pos.x, y - 0.02, pos.z + 0.34), (pos.x, pos.y, pos.z + 0.34), 0.012, IRON, verts=4))
    parts.append(_stick((pos.x, y - 0.02, pos.z + 0.2), (pos.x, pos.y + 0.12, pos.z + 0.34), 0.009, IRON, verts=4))
    parts.append(L.part("torus", IRON, loc=(pos.x, pos.y, pos.z + 0.28), rot=(0, 90, 0), major_radius=0.03,
                        minor_radius=0.007, major_segments=6, minor_segments=3))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(pos.x, pos.y, pos.z + 0.08),
                        scale=(0.058, 0.058, 0.085)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(pos.x + sx * 0.062, pos.y + sy * 0.062, pos.z + 0.08),
                                scale=(0.009, 0.009, 0.095)))
    parts.append(L.part("cube", IRON, loc=(pos.x, pos.y, pos.z - 0.012), scale=(0.075, 0.075, 0.014)))
    parts.append(L.part("cone", IRON, loc=(pos.x, pos.y, pos.z + 0.21), vertices=4, radius1=0.1, radius2=0.02,
                        depth=0.1, rot=(0, 0, 45)))


# --- outside details ----------------------------------------------------------------------

def _bench(parts) -> None:
    """Weathered bench under the front window: two slabs on stumpy legs, a clay mug on it."""
    y = -WY - 0.36
    z = 0.45
    for i in range(2):
        parts.append(_plank((WIN1_X, y + (i - 0.5) * 0.16, z - 0.025), (0.68, 0.078, 0.028), WOOD_OLD, seed=260 + i,
                            cuts=1, rot=(0, random.uniform(-1.5, 1.5), 0), hue_shift=L.hexc("#7A6E5E")))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_stick((WIN1_X + sx * 0.52, y + sy * 0.09, z - 0.05), (WIN1_X + sx * 0.58, y + sy * 0.12, 0.0),
                                0.035, WOOD_DARK, r1=0.03, verts=5, seed=262 + sx + sy, ao=0.5))
        parts.append(_plank((WIN1_X + sx * 0.54, y, 0.16), (0.02, 0.1, 0.02), WOOD_DARK, seed=266 + sx))
    mug = L.prim("cyl", loc=(WIN1_X + 0.42, y + 0.02, z + 0.06), radius=0.045, depth=0.11, vertices=8)
    L.paint(mug, CLAY, var=0.15, ao=0.3, seed=268)
    L.set_mat(mug, L.MAT_PAINTED)
    parts.append(mug)
    parts.append(L.part("torus", CLAY, loc=(WIN1_X + 0.475, y + 0.02, z + 0.065), rot=(90, 0, 0), major_radius=0.03,
                        minor_radius=0.009, major_segments=6, minor_segments=3))


def _rain_barrel(parts) -> None:
    """Stave barrel at the front-left corner (one bulging lathe, staves painted per face column),
    two iron hoops, dark water, a lid leaning against it."""
    cx, cy = -WX + 0.12, -WY - 0.42
    r, h, n = 0.3, 0.8, 14
    bm = bmesh.new()
    rings = []
    for k in range(5):
        z = h * k / 4
        rr = r + 0.035 * (1 - ((z - h / 2) / (h / 2)) ** 2)
        rings.append([bm.verts.new((cx + math.cos(i / n * math.tau) * rr, cy + math.sin(i / n * math.tau) * rr, z))
                      for i in range(n)])
    for k in range(4):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(rings[-1])
    bm.faces.new(list(reversed(rings[0])))
    barrel = _link(bm, "barrel")
    L.jitter(barrel, 0.006, 4.0, 270)
    L.paint(barrel, WOOD, var=0.14, ao=0.45, zrange=(0, h), seed=270, hue_shift=WOOD_OLD)
    stave = [random.uniform(0.74, 1.06) for _ in range(n)]
    attr = barrel.data.color_attributes["Col"]
    for poly in barrel.data.polygons:
        c = poly.center
        if abs(poly.normal.z) > 0.9:
            f = 0.55 if c.z > h / 2 else 1.0  # dark inside above the water
        else:
            a = math.atan2(c.y - cy, c.x - cx) % math.tau
            f = stave[int(a / math.tau * n) % n]
        for li in poly.loop_indices:
            col = attr.data[li].color
            attr.data[li].color = (col[0] * f, col[1] * f, col[2] * f, 1.0)
    L.set_mat(barrel, L.MAT_PAINTED)
    parts.append(barrel)
    for z in (0.15, h - 0.13):
        parts.append(L.part("cyl", IRON, loc=(cx, cy, z), radius=r + 0.03 if 0.2 < z < 0.6 else r + 0.027,
                            depth=0.04, vertices=n, paint_kw={"hue_shift": RUST, "var": 0.3}))
    parts.append(L.part("cyl", WATER, loc=(cx, cy, h - 0.05), radius=r - 0.004, depth=0.01, vertices=n,
                        paint_kw={"var": 0.05, "top": 0.35, "ao": 0.0}))
    lid = L.prim("cyl", loc=(cx + 0.36, cy - 0.1, 0.31), rot=(0, 72, 20), radius=r + 0.01, depth=0.03, vertices=10)
    L.paint(lid, WOOD_OLD, var=0.2, ao=0.3, seed=280, hue_shift=MOSS)
    L.set_mat(lid, L.MAT_PAINTED)
    parts.append(lid)


def _crow(parts, pos: Vector, yaw: float) -> None:
    """A small crow sitting on the ridge (charming, not ominous: plump and round)."""
    from mathutils import Matrix
    bits = []
    body = L.prim("sphere", radius=0.1, segments=8, ring_count=6, scale=(1.35, 0.85, 0.85))
    bits.append((body, CROW))
    head = L.prim("sphere", loc=(0.13, 0, 0.09), radius=0.062, segments=8, ring_count=5)
    bits.append((head, CROW))
    beak = L.prim("cone", loc=(0.2, 0, 0.085), rot=(0, 90, 0), radius1=0.02, depth=0.06, vertices=4)
    bits.append((beak, L.hexc("#4A4640")))
    tail = L.prim("cube", loc=(-0.17, 0, 0.0), rot=(0, 18, 0), scale=(0.08, 0.04, 0.012))
    bits.append((tail, CROW))
    for sy in (-1, 1):
        wing = L.prim("sphere", loc=(-0.02, sy * 0.07, 0.02), radius=0.08, segments=6, ring_count=4,
                      scale=(1.3, 0.3, 0.6))
        bits.append((wing, L.scale_c(CROW, 1.2)))
        eye = L.prim("ico", loc=(0.165, sy * 0.042, 0.11), radius=0.01, subdivisions=1)
        bits.append((eye, L.hexc("#C8B07A")))
        leg = L.prim("cube", loc=(0.02, sy * 0.03, -0.09), scale=(0.006, 0.006, 0.04))
        bits.append((leg, L.hexc("#2E2A26")))
    m = Matrix.Translation(pos) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    for o, col in bits:
        o.data.transform(m)
        L.paint(o, col, var=0.12, ao=0.15, top=0.3, seed=290)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)


# --- build -----------------------------------------------------------------------------------

def build():
    L.reset(61)
    parts = []
    _foundation(parts)
    # walls: openings (c0, c1, z0, z1)
    door = (DOOR_X - DOOR_W / 2 - 0.02, DOOR_X + DOOR_W / 2 + 0.02, F, F + DOOR_H)
    win1 = (WIN1_X - WIN_W / 2 - 0.03, WIN1_X + WIN_W / 2 + 0.03, WIN_Z0, WIN_Z1)
    win2 = (WIN2_Y - WIN_W / 2 - 0.03, WIN2_Y + WIN_W / 2 + 0.03, WIN_Z0, WIN_Z1)
    win3 = (WIN3_X - WIN_W / 2 - 0.03, WIN3_X + WIN_W / 2 + 0.03, WIN_Z0, WIN_Z1)
    flat = lambda a: EAVE - 0.07  # noqa: E731
    gable = lambda a: roof_z(a) - 0.03  # noqa: E731
    _wall(parts, "x", -WX, WX, -WY, -1, flat, [door, win1], 10)
    _wall(parts, "x", -WX, WX, WY, 1, flat, [win3], 40)
    _wall(parts, "y", -WY, WY, -WX, -1, gable, [win2], 70)
    _wall(parts, "y", -WY, WY, WX, 1, gable, [], 100)
    # timber frame: corner posts, sill and top plates, a mid post on the long walls
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_beam((sx * (WX + 0.02), sy * (WY + 0.02), F - 0.02), (sx * (WX + 0.02), sy * (WY + 0.02),
                               EAVE - 0.08), 0.095, 0.095, seed=sx + sy * 3 + 5))
        parts.append(_beam((sx * (WX + 0.06), -WY, F + 0.05), (sx * (WX + 0.06), WY, F + 0.05), 0.05, 0.06,
                           seed=12 + sx))
        parts.append(_beam((sx * (WX + 0.06), -WY - 0.1, EAVE - 0.14), (sx * (WX + 0.06), WY + 0.1, EAVE - 0.14),
                           0.05, 0.07, seed=14 + sx))
    for sy in (-1, 1):
        parts.append(_beam((-WX - 0.12, sy * (WY + 0.06), EAVE - 0.16), (WX + 0.12, sy * (WY + 0.06), EAVE - 0.16),
                           0.06, 0.08, seed=16 + sy))
        spans = ((-WX, DOOR_X - DOOR_W / 2 - 0.13), (DOOR_X + DOOR_W / 2 + 0.13, WX)) if sy < 0 else ((-WX, WX),)
        for a0, a1 in spans:
            parts.append(_beam((a0, sy * (WY + 0.06), F + 0.05), (a1, sy * (WY + 0.06), F + 0.05), 0.05, 0.06,
                               seed=18 + sy))
    parts.append(_beam((0.3, -WY - 0.06, F), (0.3, -WY - 0.06, EAVE - 0.12), 0.06, 0.06, seed=20))
    parts.append(_beam((-1.25, WY + 0.06, F), (-1.25, WY + 0.06, EAVE - 0.12), 0.06, 0.06, seed=21))
    # openings
    _door(parts)
    _window(parts, Vector((WIN1_X, -WY - 0.04, (WIN_Z0 + WIN_Z1) / 2)), "x", -1, shutters=True, box=True, seed=300)
    _window(parts, Vector((-WX - 0.04, WIN2_Y, (WIN_Z0 + WIN_Z1) / 2)), "y", -1, w=0.7, shutters=True, seed=340)
    _window(parts, Vector((WIN3_X, WY + 0.04, (WIN_Z0 + WIN_Z1) / 2)), "x", 1, seed=380)
    lantern = Vector((DOOR_X + DOOR_W / 2 + 0.28, -WY - 0.3, F + 1.62))
    _lantern(parts, lantern)
    # roof, chimney, crow
    roof = _roof(parts)
    _sag(roof)
    parts += roof
    _chimney(parts)
    _crow(parts, Vector((-1.55, 0.0, RIDGE + 0.1 + 0.085 + 0.1 - SAG * (1 - (1.55 / (ROOF_X + 0.2)) ** 2))), -60)
    # outside
    _bench(parts)
    _rain_barrel(parts)
    obj = L.join(parts, "ph_bld_gravekeeper_hut")
    L.marker(obj, "door_outside", (DOOR_X, -WY - 0.04 - 0.6, 0.0))
    L.marker(obj, "light_lantern", (lantern.x, lantern.y, lantern.z - 0.12))  # below the glass
    L.marker(obj, "light_window_1", (WIN1_X, -WY + 0.45, (WIN_Z0 + WIN_Z1) / 2))
    L.marker(obj, "light_window_2", (-WX + 0.45, WIN2_Y, (WIN_Z0 + WIN_Z1) / 2))
    L.finish(obj, "ph_bld_gravekeeper_hut", "buildings", 30, shift=False)


if __name__ == "__main__":
    build()
