"""Phase-6 buildings, outside (docs/PHASE6_DESIGN.md sections 4.1-4.3 and 8), 'Gemaltes Diorama'.

Every building has four level models (0 = site, 1-3 = built); a BuildingSite swaps them in place.
All share one footprint per building, the door faces south (Blender -Y = Godot +Z = the camera),
pivot = footprint centre on the ground, 1 unit = 1 m, shared materials only.

  ph_bld_crypt_site          Gruft level 0: the uncovered, filled-in crypt neck - the top of the old
                             pediment in an earth mound, boards over the stair neck, pegs + string
  ph_bld_crypt_l1 / _l2 / _l3  G8 round 2: a sunken crypt portal (pivot = front of the portal wall; the
                             stair runs to the front): pilasters, entablature, pediment (2.8 m, cross
                             3.3 m), an open stair 1.6 m wide and 1.3 m deep between retaining walls
                             with pillars and lanterns at the stair head; old and mossy, ivy, streaks and
                             lichen / + repaired: cross, corner balls, wreath, handrail, less ivy / + the
                             name tablet in the frieze, an open wrought-iron gate at the stair foot and a
                             caged lantern over the door
  ph_bld_chapel_ruin         Kapelle level 0: roofless lime-washed walls, a broken gable, brambles
  ph_bld_chapel_l1 / _l2 / _l3 the chapel (footprint 5.2 x 7.0 m): nave + lower choir, slate roof, arched
                             door and windows / + ridge turret with the bell (child mesh `bell`, its origin
                             is the swing axis) / + stained choir window (north, away from the camera)
  ph_bld_shed_site           Lagerschuppen level 0: pegs, a stack of beams, an old sill beam
  ph_bld_shed_l1 / _l2 / _l3 board shed (3.2 x 3.6 m) with a lean-to roof falling west and a woodpile at
                             the south wall / + the handcart at the door / + a stone stack and a second
                             window
  ph_prop_soul_lantern       Totenleuchter: a stone column with a small lantern house (marker light_soul)

Markers (glTF empties, Godot attaches lights / prompts):
  door_outside   ground point in front of the door (the portal's outside end)
  build          ground point beside the building where the upgrade prompt sits (not at the door)
  light_lantern  crypt l3: the caged lantern over the door (no shadow)
  light_lantern_1/_2  crypt l1+: the lanterns on the pillars at the stair head (no shadow)
  light_window_1..4  chapel l1+: 0.3 m outside the side windows (the pane is painted dark glass; the omni
                 lights pane and wall when the chapel is lit)
  bell           chapel l2+: child MESH (not an empty) - its origin is the yoke axis (swing about Godot X)
  light_choir    chapel l3: outside the stained choir window (north), lights the birches behind
  inscription    crypt l3: centre of the name tablet in the frieze, local +Z = face normal (Label3D
                 "Wir waren, was ihr seid." like the grave stone inscriptions)

Run:  python tools/blender/build_all.py asset_buildings_phase6
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P

CAT = "buildings"

# --- palette (ART_DIRECTION.md section 3; the hut / workyard families) ----------------------------
STONE = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_WARM = L.hexc("#857C72")
STONE_OLD = L.hexc("#686B64")
STONE_PALE = L.hexc("#8C8A83")
MORTAR = L.hexc("#4B4A47")
GAP = L.hexc("#15110E")
PLASTER = L.hexc("#A89F8F")        # lime wash, warm grey
PLASTER_DIRTY = L.hexc("#8E8778")
SLATE = L.hexc("#5B6168")
SLATE_DARK = L.hexc("#474C53")
SLATE_LIGHT = L.hexc("#6C7179")
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
WOOD_FRESH = P.WOOD_FRESH
END_GRAIN = P.END_GRAIN
IRON = P.IRON
RUST = P.RUST
MOSS = L.hexc("#5E7148")
MOSS_DARK = L.hexc("#44543A")
GRASS_A = L.hexc("#55683F")        # the ground's grass colours (asset_ground_graveyard.py)
GRASS_B = L.hexc("#667A48")
GRASS_DRY = L.hexc("#7D7D4E")
EARTH = P.EARTH
EARTH_FRESH = P.EARTH_FRESH
EARTH_DARK = P.EARTH_DARK
ROPE = P.ROPE
STRING = P.STRING
GLASS = L.hexc("#3E3A34")          # leaded glass by day: dark, faintly warm
GLASS_DEEP = L.hexc("#2A2724")
LEAD = L.hexc("#2A2B2E")
BRONZE = L.hexc("#6E5A3C")         # the bell: dark, dull bronze
LEAF_DARK = L.hexc("#3E4E34")
LEAF = L.hexc("#4E6440")
BRAMBLE = L.hexc("#5A4A3A")
VOID_DARK = L.hexc("#141516")      # G7 round 1: the dark inside the open crypt door
STAIN = (L.hexc("#8C3A2E"), L.hexc("#A8823E"), L.hexc("#6E7A48"), L.hexc("#7A4A3A"), L.hexc("#B89A5A"))


# --- generic helpers ------------------------------------------------------------------------------

def _paint(obj, color, mat: str = L.MAT_PAINTED, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, mat)
    return obj


def _box(loc, half, color, rot=(0, 0, 0), jit: float = 0.0, jfreq: float = 3.0, cuts: int = 0, seed: int = 0,
         mat: str = L.MAT_PAINTED, **pk):
    o = L.prim("cube", loc=loc, rot=rot, scale=half)
    if cuts:
        L.subdivide(o, cuts)
    if jit > 0:
        L.jitter(o, jit, jfreq, seed)
    return _paint(o, color, mat, seed=seed, **pk)


def _prism(poly, axis: str, lo: float, hi: float, name: str = "prism"):
    """Polygon (2D points in the plane across `axis`: 'x' -> (y, z), 'y' -> (x, z), 'z' -> (x, y))
    extruded from lo to hi along the axis."""
    def p3(a, b, t):
        if axis == "x":
            return (t, a, b)
        if axis == "y":
            return (a, t, b)
        return (a, b, t)
    bm = bmesh.new()
    va = [bm.verts.new(p3(a, b, lo)) for a, b in poly]
    vb = [bm.verts.new(p3(a, b, hi)) for a, b in poly]
    bm.faces.new(list(reversed(va)))
    bm.faces.new(vb)
    n = len(poly)
    for i in range(n):
        bm.faces.new((va[i], va[(i + 1) % n], vb[(i + 1) % n], vb[i]))
    return P._link(bm, name)


def _arch_poly(cx: float, w: float, z0: float, zs: float, n: int = 8):
    """Round-arched opening outline (x, z): straight jambs from z0 to the springing zs, semicircle on top."""
    r = w / 2
    pts = [(cx - r, z0), (cx + r, z0)]
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append((cx + r * math.cos(a), zs + r * math.sin(a)))
    return pts


def _xf(obj, loc=(0, 0, 0), rot=(0, 0, 0)):
    m = (Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rot[2]), 4, "Z")
         @ Matrix.Rotation(math.radians(rot[1]), 4, "Y") @ Matrix.Rotation(math.radians(rot[0]), 4, "X"))
    obj.data.transform(m)
    return obj


def _stone(loc, half, color, rot=(0, 0, 0), seed: int = 0, jit: float = 0.014, moss: float = 0.0, **pk):
    """One rough block: jittered cube (12 triangles), own shade, optional moss on top."""
    o = L.prim("cube", loc=loc, scale=half, rot=rot)
    L.jitter(o, jit, 5.0, seed)
    kw = {"var": 0.22, "ao": 0.25, "top": 0.14}
    kw.update(pk)
    L.paint(o, L.scale_c(color, random.uniform(0.84, 1.04)), seed=seed, **kw)
    if moss > 0:
        P._tint_up(o, MOSS, moss, 0.3, freq=3.0, seed=seed)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _courses(parts, a0: float, a1: float, z0: float, z1: float, plane: float, out: float, seed: int,
             along: str = "x", top=None, holes=(), course_h=(0.16, 0.24), ln=(0.26, 0.46), depth=(0.05, 0.08),
             colours=(STONE, STONE, STONE_DARK, STONE_WARM), moss_rows: int = 1, gap: float = 0.95, tz: float = 0.0,
             zr=None):
    """Courses of rough stones on one wall face (plane, outward sign `out`), skipping `holes`
    [(a0, a1, z0, z1)] and clipped under top(a) (gables).  tz tilts every stone a little."""
    z = z0
    row = 0
    while z < z1 - 0.04:
        h = min(random.uniform(*course_h), z1 - z)
        a = a0 - (random.uniform(0.05, 0.14) if row % 2 else 0.0)
        k = 0
        while a < a1 - 0.04:
            ll = min(random.uniform(*ln), a1 - a)
            s0, s1 = max(a, a0), min(a + ll, a1)
            c = (s0 + s1) / 2
            hh = h
            if top is not None:
                hh = min(h, top(c) - z)
            blocked = any(s1 > ho[0] + 0.02 and s0 < ho[1] - 0.02 and z + hh > ho[2] + 0.02 and z < ho[3] - 0.02
                          for ho in holes)
            if hh > 0.06 and s1 - s0 > 0.08 and not blocked:
                d = random.uniform(*depth)
                half_h = hh / 2 * random.uniform(0.86, 0.97)
                if along == "x":
                    loc, half = (c, plane + out * d / 2, z + hh / 2), ((s1 - s0) / 2 * gap, d, half_h)
                else:
                    loc, half = (plane + out * d / 2, c, z + hh / 2), (d, (s1 - s0) / 2 * gap, half_h)
                col = random.choice(colours)
                parts.append(_stone(loc, half, col, rot=(random.uniform(-3, 3) + tz, random.uniform(-3, 3), 0),
                                    seed=seed + k, moss=0.9 if row < moss_rows else 0.0,
                                    zrange=zr if zr else (z0 - 0.1, z1)))
            a += ll
            k += 1
        z += h
        row += 1
        seed += 37


def _voussoirs(parts, cx: float, plane: float, out: float, zs: float, r: float, n: int, depth: float, band: float,
               color=STONE_PALE, seed: int = 0, keystone: bool = True):
    """Wedge stones around a semicircular arch in the face y = plane."""
    for k in range(n):
        a0, a1 = math.pi * k / n, math.pi * (k + 1) / n
        poly = []
        for a in (a0, a1):
            poly.append((cx + r * math.cos(a), zs + r * math.sin(a)))
        for a in (a1, a0):
            rr = r + band * (1.25 if keystone and k == n // 2 else 1.0)
            poly.append((cx + rr * math.cos(a), zs + rr * math.sin(a)))
        o = _prism(poly, "y", plane, plane + out * depth, "vous")
        L.jitter(o, 0.006, 5.0, seed + k)
        parts.append(_paint(o, L.scale_c(color, random.uniform(0.9, 1.05)), var=0.15, ao=0.1, top=0.2, seed=seed + k))


def _grid_mound(x0, x1, y0, y1, nx: int, ny: int, hfn, name: str = "mound"):
    """Height field z = hfn(x, y) on a grid (sod, earth).  Faces up."""
    bm = bmesh.new()
    vs = [[bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny,
                         hfn(x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny)))
           for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _sod_colour(co, seed: float = 0.0):
    """Grass like the ground (two greens, dry patches), darker towards the foot."""
    n = noise.noise(Vector((co.x * 1.7, co.y * 1.7, seed)))
    m = noise.noise(Vector((co.x * 4.0 + 3, co.y * 4.0, seed + 2)))
    c = L.mix(GRASS_A, GRASS_B, 0.5 + 0.5 * n)
    c = L.mix(c, GRASS_DRY, max(0.0, m - 0.25) * 0.9)
    return L.scale_c(c, 0.9 + 0.12 * min(1.0, co.z / 0.8) + 0.06 * m)


def _wall_lantern(parts, pos: Vector, wall_y: float, seed: int = 0) -> Vector:
    """Wall lantern on an iron bracket (the hut's lantern): warm glass in an iron cage; returns the light point."""
    parts.append(_box((pos.x, wall_y - 0.02, pos.z + 0.27), (0.04, 0.02, 0.1), IRON, seed=seed))
    parts.append(P._stick((pos.x, wall_y - 0.02, pos.z + 0.34), (pos.x, pos.y, pos.z + 0.34), 0.012, IRON, verts=4))
    parts.append(P._stick((pos.x, wall_y - 0.02, pos.z + 0.2), (pos.x, pos.y + 0.1, pos.z + 0.34), 0.009, IRON, verts=4))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(pos.x, pos.y, pos.z + 0.08), scale=(0.058, 0.058, 0.085)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(pos.x + sx * 0.062, pos.y + sy * 0.062, pos.z + 0.08),
                                scale=(0.009, 0.009, 0.095)))
    parts.append(L.part("cube", IRON, loc=(pos.x, pos.y, pos.z - 0.012), scale=(0.075, 0.075, 0.014)))
    parts.append(L.part("cone", IRON, loc=(pos.x, pos.y, pos.z + 0.21), vertices=4, radius1=0.1, radius2=0.02,
                        depth=0.1, rot=(0, 0, 45)))
    return Vector((pos.x, pos.y, pos.z - 0.1))


def _pegs(parts, corners, h: float = 0.42, seed: int = 0, string: bool = True):
    """Surveyor's pegs at the corners, a string between them (the Phase-5 build-site vocabulary)."""
    tops = []
    for i, (x, y) in enumerate(corners):
        lean = Vector((random.uniform(-0.04, 0.04), random.uniform(-0.04, 0.04), 0))
        p0 = Vector((x, y, -0.03))
        p1 = p0 + Vector((0, 0, h)) + lean
        parts.append(P._stick(p0, p1, 0.028, WOOD_FRESH, r1=0.022, verts=5, seed=seed + i, ao=0.4))
        parts.append(L.part("cone", WOOD_FRESH, loc=p1 + Vector((0, 0, 0.015)), radius1=0.024, depth=0.03, vertices=5))
        tops.append(p1 - Vector((0, 0, 0.06)))
    if string:
        for i in range(len(tops)):
            a, b = tops[i], tops[(i + 1) % len(tops)]
            mid = (a + b) / 2 - Vector((0, 0, 0.04))
            parts.append(P._finish_obj(P._path_tube([a, mid, b], 0.005, 3), STRING, ao=0.0, var=0.05))


def _cross(parts, base: Vector, h: float, color=STONE_PALE, seed: int = 0) -> None:
    """Small stone / iron cross standing on `base` (height h)."""
    t = h * 0.13
    parts.append(_box(base + Vector((0, 0, h / 2)), (t, t, h / 2), color, seed=seed, var=0.1, ao=0.1, top=0.2))
    parts.append(_box(base + Vector((0, 0, h * 0.68)), (h * 0.3, t, t), color, seed=seed + 1, var=0.1, ao=0.1, top=0.2))


def _done(parts, name: str, markers=(), smooth_angle: float = 35.0, children=()):
    obj = L.join(parts, name)
    for m_name, loc in markers:
        L.marker(obj, m_name, loc)
    for child in children:
        child.parent = obj
    L.finish(obj, name, CAT, smooth_angle, shift=False)
    return obj


# ==================================================================================================
# GRUFT (crypt) – G8 round 2: a sunken portal facing the path. Pivot = the portal's front wall on the
# ground (x 0), the stair runs towards the front (Blender -Y = Godot +Z). Footprint (Godot local)
# x -1.5..1.5, z -0.6..2.75: the portal wall (z -0.6..0) with the pilasters, entablature and pediment
# (2.8 m, cross 3.3 m), the open stair shaft (1.6 m wide, 1.3 m deep, six steps) between two
# retaining walls ending in pillars with lanterns at the stair head. Old, mossy, ivy on the flank
# the camera sees (-X), dark streaks under every ledge, lichen spots.
# ==================================================================================================

CR_D = 1.3               # the stair foot (door sill) this far below the ground
CR_WALL_Y = 0.0          # front plane of the portal wall (Blender y)
CR_BACK_Y = 0.6          # back plane of the portal wall
CR_HW = 1.5              # half width of the portal wall (the wings)
CR_CW = 1.2              # half width of the centre part (entablature, pediment)
CR_DOOR_HW = 0.52        # half width of the door opening
CR_SPRING = 0.45         # the door's round head springs here (crown 0.97)
CR_PIL = (0.58, 0.9)     # pilasters (|x|), front 0.13 before the wall
CR_PIL_OUT = 0.17
CR_CAP = 1.58            # capitals 1.58..1.75
CR_ARCH = 1.75           # architrave 1.75..1.91, frieze ..2.17, cornice ..2.31
CR_FRIEZE = (1.91, 2.17)
CR_CORNICE = 2.31
CR_APEX = 3.02           # apex of the pediment (under the coping)
CR_SHAFT = 0.8           # inner face of the shaft walls (|x|)
CR_SHAFT_OUT = 1.38      # outer face of the shaft walls
CR_PARAPET = 0.42        # top of the far shaft wall (+X, coping above)
CR_CURB = 0.12           # the near shaft wall (-X, the camera's side) ends in a low curb with a railing
CR_STEPS = 6             # treads between the foot landing and the top landing (ground)
CR_FOOT = 0.35           # depth of the foot landing in front of the door (Blender -y)
CR_RUN = 0.3             # tread depth
CR_TOP = CR_FOOT + CR_STEPS * CR_RUN          # 2.15: the top landing starts here (ground level)
CR_END = 2.75            # end of the shaft walls / the pillars
CR_BUILD = (-1.95, -1.5, 0.0)                  # the upgrade prompt: beside the south shaft wall
CR_DOOR = (0.0, -0.05, -CR_D)                  # BuildingDoor: at the stair foot (Godot z 0.05)

CR_ST = L.hexc("#5B5D55")       # weathered grey-green ashlar (darker than the grave stones)
CR_ST_D = L.hexc("#4B4F48")
CR_ST_W = L.hexc("#645E55")
CR_ST_P = L.hexc("#7C7A70")     # dressed stone: columns, cornice, voussoirs, copings – lighter, they draw the portal
CR_ST_NEW = L.hexc("#7F7C71")   # level 2: the repaired stones
CR_STAIR = L.hexc("#6A6A61")
CR_LICHEN = L.hexc("#A29F7C")
CR_STREAK = L.hexc("#3D413A")
CR_DAMP = L.hexc("#4B5742")
IVY = (L.hexc("#3E5131"), L.hexc("#4B5F37"), L.hexc("#35442B"), L.hexc("#5B6B3D"), L.hexc("#46593A"))
IVY_STEM = L.hexc("#4A4031")
CR_COURSE = dict(course_h=(0.24, 0.32), ln=(0.42, 0.64), depth=(0.05, 0.07))


def _weather(objs, seed: int = 0, streak: float = 1.0, lichen: float = 1.0, damp_z: float = -0.2, moss: float = 0.0) -> None:
    """Patina on already painted stone: dark streaks running down under the ledges (noise stretched
    in z), pale lichen spots, a damp green foot below damp_z (the shaft)."""
    off = Vector((seed * 1.7, seed * 2.9, seed * 0.7))
    s_lin = [L._to_lin(c) for c in CR_STREAK]
    l_lin = [L._to_lin(c) for c in CR_LICHEN]
    d_lin = [L._to_lin(c) for c in CR_DAMP]
    m_lin = [L._to_lin(c) for c in L.mix(MOSS, MOSS_DARK, 0.35)]
    for obj in objs:
        me = obj.data
        attr = me.color_attributes.get("Col")
        if attr is None:
            continue
        for poly in me.polygons:
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                c = list(attr.data[li].color)
                st = noise.noise(Vector((co.x * 7.0, co.y * 7.0, co.z * 0.6)) + off)
                t = max(0.0, st - 0.15) * 0.75 * streak
                ln = noise.noise(co * 9.0 + off + Vector((3.1, 1.7, 5.3)))
                u = max(0.0, ln - 0.42) * 2.2 * lichen
                d = max(0.0, min(1.0, (damp_z - co.z) / 0.9)) * 0.55
                mo = 0.0
                if moss > 0.0 and poly.normal.z > 0.55:
                    mo = max(0.0, noise.noise(co * 4.0 + off + Vector((7.7, 2.2, 0.4))) + 0.25) * moss
                for k in range(3):
                    v = c[k] + (s_lin[k] - c[k]) * min(0.7, t)
                    v = v + (l_lin[k] - v) * min(0.6, u)
                    v = v + (d_lin[k] - v) * d
                    c[k] = v + (m_lin[k] - v) * min(0.75, mo)
                attr.data[li].color = (c[0], c[1], c[2], 1.0)


def _moss(parts, loc, r: float, seed: int = 0, flat: float = 0.4) -> None:
    """A moss cushion (20 triangles)."""
    m = L.prim("ico", loc=loc, radius=r, subdivisions=1, scale=(1.4, 1.1, flat))
    L.jitter(m, r * 0.25, 6.0, seed)
    parts.append(_paint(m, L.mix(MOSS, MOSS_DARK, random.uniform(0.1, 0.7)), var=0.25, ao=0.3, top=0.2, seed=seed))


def _ivy(parts, pts, nrm, seed: int = 0, every: float = 0.06, leaf: float = 0.09, spread: float = 0.07) -> None:
    """Ivy along a polyline on a wall (points already just in front of it, outward normal nrm):
    a thin stem, diamond leaves (2 triangles each) facing out and a little up."""
    random.seed(seed)
    pts = [Vector(p) for p in pts]
    n = Vector(nrm).normalized()
    stem = P._path_tube(pts, 0.011, 3, hint=n)
    parts.append(_paint(stem, IVY_STEM, var=0.2, ao=0.0, seed=seed))
    bm = bmesh.new()
    cols = []
    up = Vector((0, 0, 1))
    for a, b in zip(pts, pts[1:]):
        seg = b - a
        ln = seg.length
        if ln < 1e-4:
            continue
        t = seg / ln
        side = t.cross(n).normalized()
        k = 0.0
        while k < ln:
            for _ in range(random.choice((1, 1, 2))):
                c = a + t * k + side * random.uniform(-spread, spread) + n * random.uniform(0.01, 0.035)
                nl = (n + up * random.uniform(0.2, 0.8) + Vector((random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4),
                                                                  random.uniform(-0.2, 0.2)))).normalized()
                u = nl.cross(Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-1, 1)))).normalized()
                v = nl.cross(u)
                s = leaf * random.uniform(0.75, 1.25)
                quad = [c + u * s, c + v * s * 0.62, c - u * s * 0.7, c - v * s * 0.62]
                bm.faces.new([bm.verts.new(q) for q in quad])
                col = L.scale_c(random.choice(IVY), random.uniform(0.85, 1.12))
                cols.extend([col, L.scale_c(col, 1.08), col, L.scale_c(col, 0.9)])
            k += every * random.uniform(0.7, 1.3)
    me = bpy.data.meshes.new("ivy")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("ivy", me)
    bpy.context.collection.objects.link(obj)
    P._paint_fn(obj, lambda co, vi: cols[vi])
    L.set_mat(obj, L.MAT_PAINTED)
    parts.append(obj)


def _post_lantern(parts, base: Vector, seed: int = 0) -> Vector:
    """An iron lantern standing on a pillar cap: base plate, four corner bars round warm glass, a
    pyramid roof with a ring. Returns the light point (centre of the glass)."""
    parts.append(_box(base + Vector((0, 0, 0.02)), (0.1, 0.1, 0.02), IRON, seed=seed, var=0.2, hue_shift=RUST, ao=0.0))
    parts.append(P._stick(base + Vector((0, 0, 0.04)), base + Vector((0, 0, 0.1)), 0.03, IRON, verts=5, hue_shift=RUST, ao=0.0))
    g = base + Vector((0, 0, 0.21))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=g, scale=(0.065, 0.065, 0.1)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=g + Vector((sx * 0.072, sy * 0.072, 0.0)), scale=(0.011, 0.011, 0.115),
                                paint_kw={"hue_shift": RUST}))
    parts.append(L.part("cube", IRON, loc=g - Vector((0, 0, 0.115)), scale=(0.085, 0.085, 0.012)))
    parts.append(L.part("cone", IRON, loc=g + Vector((0, 0, 0.17)), vertices=4, radius1=0.12, radius2=0.015, depth=0.11,
                        rot=(0, 0, 45), paint_kw={"hue_shift": RUST}))
    parts.append(L.part("torus", IRON, loc=g + Vector((0, 0, 0.25)), rot=(90, 0, 0), major_radius=0.025, minor_radius=0.006,
                        major_segments=6, minor_segments=3))
    return g


def _cage_lantern(parts, wall_y: float, top: Vector, seed: int = 0) -> Vector:
    """Level 3: a lantern in a wrought-iron cage hanging from a bracket over the stair foot.
    Returns the light point."""
    arm0 = Vector((top.x, wall_y - 0.02, top.z))
    arm1 = Vector((top.x, top.y, top.z))
    parts.append(_box(arm0 + Vector((0, -0.01, 0.0)), (0.06, 0.02, 0.12), IRON, seed=seed, var=0.2, hue_shift=RUST))
    parts.append(P._stick(arm0, arm1, 0.016, IRON, verts=4, hue_shift=RUST, ao=0.0))
    parts.append(P._stick(arm0 - Vector((0, 0, 0.18)), arm1 - Vector((0, 0.12, -0.01)), 0.011, IRON, verts=4, ao=0.0))
    for k in range(3):     # a small scroll under the arm
        a = math.pi * k / 3
        p = arm0 + (arm1 - arm0) * 0.45 + Vector((0, 0.06 * math.cos(a), -0.06 - 0.06 * math.sin(a)))
        parts.append(L.part("cube", IRON, loc=p, scale=(0.008, 0.02, 0.008)))
    hook = arm1 - Vector((0, 0, 0.06))
    parts.append(P._stick(arm1, hook, 0.007, IRON, verts=4, ao=0.0))
    g = hook - Vector((0, 0, 0.24))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=g, scale=(0.075, 0.075, 0.12)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=g + Vector((sx * 0.085, sy * 0.085, 0.0)), scale=(0.011, 0.011, 0.14),
                                paint_kw={"hue_shift": RUST}))
    for dz in (-0.05, 0.05):    # the cage: two rings of bars round the glass
        for sx in (-1, 1):
            parts.append(L.part("cube", IRON, loc=g + Vector((sx * 0.087, 0, dz)), scale=(0.006, 0.085, 0.006)))
            parts.append(L.part("cube", IRON, loc=g + Vector((0, sx * 0.087, dz)), scale=(0.085, 0.006, 0.006)))
    parts.append(L.part("cube", IRON, loc=g - Vector((0, 0, 0.14)), scale=(0.1, 0.1, 0.014)))
    parts.append(L.part("cone", IRON, loc=g + Vector((0, 0, 0.19)), vertices=4, radius1=0.14, radius2=0.02, depth=0.12,
                        rot=(0, 0, 45), paint_kw={"hue_shift": RUST}))
    return g


def _crypt_wall(parts, stones, level: int) -> dict:
    """The portal wall: ashlar courses on the front (centre part up to the architrave, the wings with
    a curved top), the door opening with jambs, voussoirs and keystone, pilasters with plinths and
    capitals, entablature, pediment with raking cornices, the side ends and the plain back with two
    buttresses."""
    y = CR_WALL_Y
    door_top = CR_SPRING + CR_DOOR_HW

    def wing_top(a):      # the wings: a quarter curve from the capitals down to 0.95 at the ends
        t = (abs(a) - CR_CW) / (CR_HW - CR_CW)
        if t <= 0.0:
            return CR_ARCH
        return 0.95 + (CR_ARCH - 0.95) * math.cos(min(1.0, t) * math.pi / 2) ** 0.7

    # mortar core (dark, mostly hidden): two halves, each with its half of the door opening cut out
    ro = CR_DOOR_HW + 0.14
    left = [(-CR_SHAFT, -CR_D - 0.15), (-ro, -CR_D - 0.15), (-ro, CR_SPRING)]
    for k in range(1, 6):
        a = math.pi - math.pi / 2 * k / 5
        left.append((ro * math.cos(a), CR_SPRING + ro * math.sin(a)))
    left += [(0.0, CR_APEX - 0.04), (-CR_CW + 0.02, CR_CORNICE), (-CR_CW + 0.02, CR_ARCH - 0.03)]
    for k in range(1, 7):
        a = -CR_CW - (CR_HW - CR_CW - 0.02) * k / 6
        left.append((a, wing_top(a) - 0.03))
    left += [(-CR_HW + 0.02, -0.15), (-CR_SHAFT, -0.15)]
    for sx in (-1, 1):
        poly = left if sx < 0 else [(-a, b) for a, b in reversed(left)]
        core = _prism(poly, "y", y + 0.05, CR_BACK_Y, "core")
        stones.append(_paint(core, MORTAR, var=0.25, ao=0.25, seed=1 + sx, hue_shift=MOSS_DARK))
    # front courses: below ground only inside the shaft, above ground the full width
    hole = (-CR_DOOR_HW - 0.14, CR_DOOR_HW + 0.14, -CR_D - 0.5, door_top + 0.18)
    pil = [(s * CR_PIL[0] - 0.02 if s > 0 else -CR_PIL[1] - 0.02, s * CR_PIL[1] + 0.02 if s > 0 else -CR_PIL[0] + 0.02,
            -CR_D - 0.5, CR_CAP + 0.2) for s in (-1, 1)]
    cols = (CR_ST, CR_ST, CR_ST_D, CR_ST_W)
    _courses(stones, -CR_SHAFT, CR_SHAFT, -CR_D - 0.05, 0.0, y + 0.04, -1, 100, holes=[hole] + pil,
             colours=cols, moss_rows=1, **CR_COURSE)
    _courses(stones, -CR_HW, CR_HW, -0.08, CR_ARCH, y + 0.04, -1, 140, top=lambda a: wing_top(a) - 0.01,
             holes=[hole] + pil, colours=cols, moss_rows=1, **CR_COURSE)
    # side ends (the -X end faces the camera's side)
    for sx in (-1, 1):
        _courses(stones, y + 0.02, CR_BACK_Y, -0.08, 0.95, sx * (CR_HW - 0.02), sx, 180 + sx * 10, along="y",
                 colours=(CR_ST_D, CR_ST, CR_ST_W), moss_rows=2, course_h=(0.22, 0.3), ln=(0.22, 0.32), depth=(0.04, 0.06))
    # door: jambs (alternating long and short blocks), voussoirs, keystone, threshold
    for sx in (-1, 1):
        z = -CR_D
        k = 0
        while z < CR_SPRING - 0.05:
            h = min(0.32 if k % 2 == 0 else 0.24, CR_SPRING - z)
            w = 0.16 if k % 2 == 0 else 0.11
            x = sx * (CR_DOOR_HW + w / 2 + 0.01)
            stones.append(_stone((x, y - 0.02, z + h / 2), (w / 2 + 0.01, 0.08, h / 2 * 0.95), CR_ST_P, seed=200 + k + sx * 20,
                                 jit=0.008, var=0.15, top=0.2))
            z += h
            k += 1
    vs = []
    _voussoirs(vs, 0.0, y + 0.07, -1, CR_SPRING, CR_DOOR_HW + 0.01, 9, 0.15, 0.17, color=CR_ST_P, seed=220)
    stones.extend(vs)
    stones.append(_stone((0.0, y - 0.11, door_top + 0.12), (0.09, 0.1, 0.15), CR_ST_P, seed=230, jit=0.006, top=0.15,
                         rot=(0, 0, 0)))     # keystone
    stones.append(_stone((0.0, y - 0.12, -CR_D + 0.03), (CR_DOOR_HW + 0.18, 0.14, 0.035), CR_ST_D, seed=232, jit=0.006))
    # the dark inside: back wall, reveals, two more steps going down into the vault
    parts.append(_box((0.0, y + 0.55, -CR_D + 1.1), (CR_DOOR_HW + 0.02, 0.02, 1.15), VOID_DARK, var=0.04, ao=0.0, top=0.0))
    for sx in (-1, 1):
        parts.append(_box((sx * (CR_DOOR_HW + 0.02), y + 0.28, -CR_D + 1.1), (0.02, 0.28, 1.15), L.scale_c(CR_ST_D, 0.33),
                          var=0.1, ao=0.0, top=0.0))
    parts.append(_box((0.0, y + 0.28, CR_SPRING + CR_DOOR_HW + 0.03), (CR_DOOR_HW + 0.02, 0.28, 0.02), L.scale_c(CR_ST_D, 0.3),
                      var=0.05, ao=0.0, top=0.0))
    for k in range(2):
        parts.append(_box((0.0, y + 0.14 + k * 0.17, -CR_D - 0.09 - k * 0.17), (CR_DOOR_HW, 0.09, 0.09),
                          L.scale_c(CR_ST_D, 0.42 - k * 0.12), var=0.1, ao=0.0, top=0.25))
    # engaged columns in front of pilaster strips: square plinth, round shaft (three drums, a little
    # entasis), capital blocks – the round shafts catch the light from the side the camera sees
    for sx in (-1, 1):
        x0, x1 = CR_PIL
        cx = sx * (x0 + x1) / 2
        hw = (x1 - x0) / 2
        stones.append(_stone((cx, y - 0.15, -CR_D + 0.14), (hw + 0.04, 0.2, 0.14), CR_ST_D,
                             seed=240 + sx, jit=0.006, var=0.15, moss=0.5))
        stones.append(_stone((cx, y + 0.01, (CR_CAP - CR_D + 0.28) / 2), (hw, 0.04, (CR_CAP + CR_D - 0.28) / 2), CR_ST_D,
                             seed=243 + sx, jit=0.005, var=0.12, top=0.1))
        z = -CR_D + 0.28
        k = 0
        for z1 in (-0.35, 0.6, CR_CAP):
            drum = L.prim("cyl", loc=(cx, y - CR_PIL_OUT + 0.02, (z + z1) / 2), radius=hw - 0.005, depth=z1 - z - 0.012, vertices=8)
            L.taper(drum, z, z1, 0.95 if k == 2 else 0.985)
            L.jitter(drum, 0.006, 4.0, 244 + k + sx * 5)
            stones.append(_paint(drum, L.scale_c(CR_ST_P, random.uniform(0.95, 1.05)), var=0.14, ao=0.15, top=0.1, seed=244 + k + sx * 5))
            z = z1
            k += 1
        stones.append(_stone((cx, y - 0.15, CR_CAP + 0.05), (hw + 0.035, 0.2, 0.05), CR_ST_P,
                             seed=250 + sx, jit=0.005, top=0.15, moss=0.5))
        stones.append(_stone((cx, y - 0.16, CR_CAP + 0.135), (hw + 0.06, 0.22, 0.035), CR_ST_P,
                             seed=252 + sx, jit=0.005, top=0.15))
    # entablature: architrave, frieze, cornice (three long blocks each, a little uneven)
    for k, (z0, z1, out, hw, col) in enumerate(((CR_ARCH, CR_FRIEZE[0], 0.1, CR_CW, CR_ST_P),
                                                 (CR_FRIEZE[0], CR_FRIEZE[1], 0.06, CR_CW - 0.03, CR_ST),
                                                 (CR_FRIEZE[1], CR_CORNICE, 0.22, CR_CW + 0.12, CR_ST_P))):
        for j in range(3):
            a0 = -hw + 2 * hw * j / 3
            a1 = a0 + 2 * hw / 3
            stones.append(_stone(((a0 + a1) / 2, y - out / 2 + 0.06, (z0 + z1) / 2), ((a1 - a0) / 2 - 0.006, out / 2 + 0.06,
                                  (z1 - z0) / 2), col, seed=260 + k * 5 + j, jit=0.006, var=0.14, top=0.15,
                                 moss=0.7 if k == 2 else 0.0))
    # pediment: tympanum (set back), raking cornices, the coping slabs
    tymp = _prism([(-CR_CW + 0.05, CR_CORNICE), (CR_CW - 0.05, CR_CORNICE), (0.0, CR_APEX - 0.05)], "y", y + 0.03, y + 0.3, "tymp")
    L.subdivide(tymp, 1)
    L.jitter(tymp, 0.008, 4.0, 270)
    stones.append(_paint(tymp, CR_ST, var=0.2, ao=0.2, top=0.1, seed=270, zrange=(CR_CORNICE, CR_APEX)))
    rake = math.atan2(CR_APEX - CR_CORNICE, CR_CW + 0.12)
    ln = math.hypot(CR_CW + 0.12, CR_APEX - CR_CORNICE)
    for sx in (-1, 1):
        for j in range(2):
            t = (j + 0.5) / 2
            c = Vector((sx * (CR_CW + 0.12) * (1 - t), y - 0.1, CR_CORNICE + (CR_APEX - CR_CORNICE) * t + 0.06))
            stones.append(_stone(c, (ln / 4 - 0.01, 0.11, 0.055), CR_ST_P, rot=(0, sx * math.degrees(rake), 0), seed=272 + j + sx * 3,
                                 jit=0.006, var=0.14, top=0.15, moss=0.85))
    # back: plain rubble face with two buttresses
    for sx in (-1, 1):
        b = _prism([(CR_BACK_Y - 0.02, 0.0), (CR_BACK_Y + 0.24, 0.0), (CR_BACK_Y + 0.24, 0.2), (CR_BACK_Y - 0.02, 1.3)], "x",
                   sx * 0.95 - 0.17, sx * 0.95 + 0.17, "buttress")
        L.jitter(b, 0.012, 3.0, 280 + sx)
        stones.append(_paint(b, CR_ST_D, var=0.25, ao=0.35, top=0.25, seed=280 + sx, hue_shift=MOSS_DARK))
    return {"door_top": door_top, "wing_top": wing_top}


def _crypt_shaft(parts, stones, level: int) -> list:
    """The stair: foot landing, six treads, the top landing at ground level; the two shaft walls with
    stone courses inside, copings, and the pillars at the stair head. Returns the pillar cap points."""
    caps = []
    for sx in (-1, 1):
        x = sx * (CR_SHAFT + CR_SHAFT_OUT) / 2
        hw = (CR_SHAFT_OUT - CR_SHAFT) / 2
        top = CR_PARAPET if sx > 0 else CR_CURB
        body = _box((x, -CR_END / 2, (top - CR_D - 0.3) / 2), (hw, CR_END / 2, (top + CR_D + 0.3) / 2), CR_ST_D,
                    seed=300 + sx, var=0.25, ao=0.35, hue_shift=MORTAR)
        stones.append(body)
        # inner face (the camera looks at the +X wall's inside – the near wall's inside faces away and
        # stays the plain rubble body), outer face above ground
        if sx > 0:
            _courses(stones, -CR_END + 0.58, -0.02, -CR_D - 0.1, top, sx * CR_SHAFT, -sx, 310 + sx * 30, along="y",
                     colours=(CR_ST, CR_ST_D, CR_ST_W), moss_rows=1, course_h=(0.22, 0.3), ln=(0.4, 0.6), depth=(0.035, 0.05))
            _courses(stones, -CR_END + 0.58, -0.02, -0.06, top, sx * CR_SHAFT_OUT, sx, 360 + sx * 30, along="y",
                     colours=(CR_ST, CR_ST_D, CR_ST_W), moss_rows=1, course_h=(0.2, 0.24), ln=(0.4, 0.6), depth=(0.035, 0.05))
        # coping slabs
        for j in range(4):
            y0 = -0.02 - j * (CR_END - 0.6) / 4
            y1 = y0 - (CR_END - 0.6) / 4
            col = CR_ST_NEW if level >= 2 and j % 2 == 0 else CR_ST_P
            stones.append(_stone((x, (y0 + y1) / 2, top + 0.045), (hw + 0.05, (y0 - y1) / 2 - 0.006, 0.045), col,
                                 seed=400 + j + sx * 7, jit=0.006, var=0.15, top=0.12, moss=1.0 if level < 2 else 0.6))
        if sx < 0:
            _crypt_railing(parts, x, -0.12, -CR_END + 0.62, top + 0.09, level)
        # the pillar at the stair head: base, shaft, cap
        py = -CR_END + 0.3
        stones.append(_stone((x, py, 0.06), (0.33, 0.33, 0.07), CR_ST_D, seed=420 + sx, jit=0.008, moss=0.6))
        stones.append(_stone((x, py, 0.55), (0.29, 0.29, 0.43), CR_ST, seed=422 + sx, jit=0.01, var=0.18, top=0.2))
        stones.append(_stone((x, py, 1.02), (0.34, 0.34, 0.05), CR_ST_P, seed=424 + sx, jit=0.006, top=0.15, moss=0.8))
        stones.append(_stone((x, py, 1.09), (0.27, 0.27, 0.025), CR_ST_P, seed=426 + sx, jit=0.005, top=0.15))
        caps.append(Vector((x, py, 1.115)))
    # foot landing, treads (full blocks down below the pit), top landing at ground level
    hw = CR_SHAFT - 0.01
    stones.append(_stone((0.0, -CR_FOOT / 2, -CR_D - 0.15), (hw, CR_FOOT / 2, 0.15), CR_ST_D, seed=450, jit=0.004, var=0.15, top=0.25))
    for k in range(1, CR_STEPS + 1):
        y0 = -CR_FOOT - (k - 1) * CR_RUN
        y1 = y0 - CR_RUN
        top_z = -CR_D + k * CR_D / (CR_STEPS + 1)
        dark = 0.82 + 0.03 * k
        for j, (a0, a1) in enumerate(((-hw, -0.1 + random.uniform(-0.15, 0.15)), (None, hw))):
            if a0 is None:
                a0 = prev_a1
            prev_a1 = a1
            t = _stone(((a0 + a1) / 2, (y0 + y1) / 2, (top_z - CR_D - 0.3) / 2), ((a1 - a0) / 2 - 0.005, CR_RUN / 2 + 0.004,
                       (top_z + CR_D + 0.3) / 2), L.scale_c(CR_STAIR, dark * random.uniform(0.92, 1.04)), seed=460 + k * 3 + j,
                       jit=0.004, var=0.16, ao=0.0, top=0.15)
            P._modulate(t, lambda co, yb=y0: 0.55 if co.y > yb - 0.06 and co.z < top_z - 0.02 else 1.0)
            stones.append(t)
        # the worn nosing (lit edge)
        stones.append(_box((0.0, y1 + 0.03, top_z + 0.012), (hw - 0.02, 0.03, 0.012), L.scale_c(CR_ST_P, 1.12 * dark),
                           seed=480 + k, var=0.1, ao=0.0, top=0.15))
    stones.append(_stone((0.0, -(CR_TOP + CR_END) / 2, -0.38), (hw, (CR_END - CR_TOP) / 2, 0.4), CR_STAIR, seed=490,
                         jit=0.004, var=0.16, top=0.15, moss=0.3))
    return caps


def _crypt_railing(parts, x: float, y0: float, y1: float, z: float, level: int) -> None:
    """The wrought-iron railing on the near curb: square bars with spear tips between two rails, a
    heavier post every metre (it keeps the stair open to the camera)."""
    h = 0.85
    n = 13
    for k in range(n + 1):
        y = y0 + (y1 - y0) * k / n
        post = k % 4 == 0
        parts.append(P._stick((x, y, z), (x, y, z + h + (0.06 if post else 0.0)), 0.016 if post else 0.009, IRON, verts=4,
                              hue_shift=RUST, var=0.3, ao=0.05))
        parts.append(L.part("cone", IRON, loc=(x, y, z + h + (0.1 if post else 0.03)), radius1=0.024 if post else 0.016,
                            depth=0.07, vertices=4))
    for zz in (0.08, h - 0.07):
        parts.append(P._stick((x, y0, z + zz), (x, y1, z + zz), 0.013, IRON, verts=4, hue_shift=RUST, var=0.3, ao=0.05))
    if level >= 2:   # repaired: a scroll in every other bay under the top rail
        for k in range(0, n, 2):
            y = y0 + (y1 - y0) * (k + 0.5) / n
            parts.append(L.part("torus", IRON, loc=(x, y, z + h - 0.16), rot=(0, 90, 0), major_radius=0.05, minor_radius=0.006,
                                major_segments=5, minor_segments=3))


def _crypt_overgrowth(parts, level: int, wing_top) -> None:
    """Moss cushions on the ledges, ivy on the camera's flank (-X): up the wing and its end, over the
    south shaft wall; at level 1 also up the +X pilaster. Less with every level (trimmed)."""
    rnd = random.Random(900 + level)
    spots = [(-1.05, -0.05, CR_CORNICE + 0.02), (0.6, -0.05, CR_CORNICE + 0.02), (-1.42, 0.2, 0.97), (1.42, 0.35, 0.97),
             (-1.09, -2.45, 1.08), (1.09, -2.45, 1.08), (-1.1, -1.2, CR_CURB + 0.09), (1.1, -0.6, CR_PARAPET + 0.09),
             (0.4, -0.2, CR_APEX - 0.25), (-0.6, -0.15, CR_APEX - 0.3), (1.12, -1.9, CR_PARAPET + 0.09), (-0.74, 0.6, 0.02),
             (0.9, 0.62, 0.02), (-1.5, -0.3, 0.02), (1.45, -2.8, 0.02)]
    for i, p in enumerate(spots[: 15 - 3 * (level - 1)]):
        _moss(parts, p, rnd.uniform(0.07, 0.12), seed=910 + i)
    k = 3 if level == 1 else (2 if level == 2 else 1)
    # up the -X wing from the ground, over its curved top onto the cornice and the raking cornice
    path = [(-1.38, -0.03, 0.0), (-1.3, -0.05, 0.3), (-1.4, -0.05, 0.6), (-1.28, -0.05, 0.9), (-1.2, -0.08, 1.2),
            (-1.12, -0.12, 1.55)]
    if level <= 2:
        path += [(-1.18, -0.24, CR_CORNICE + 0.04), (-1.0, -0.26, CR_CORNICE + 0.16)]
    if level == 1:
        path += [(-0.75, -0.25, CR_CORNICE + 0.32), (-0.55, -0.25, CR_CORNICE + 0.42)]
    _ivy(parts, path, (0, -1, 0.15), seed=930)
    _ivy(parts, [(-1.42, -0.04, 0.2), (-1.47, -0.05, 0.55), (-1.47, -0.05, 0.85)], (0, -1, 0.1), seed=935)
    # round the -X end of the wall and down its back
    _ivy(parts, [(-1.535, 0.05, 0.0), (-1.535, 0.25, 0.35), (-1.535, 0.12, 0.65), (-1.535, 0.4, 0.92), (-1.4, 0.55, 1.0)],
         (-1, 0, 0.1), seed=931)
    if k >= 2:
        _ivy(parts, [(-1.535, 0.5, 0.0), (-1.535, 0.45, 0.45)], (-1, 0, 0.1), seed=936)
        # up the -X pilaster
        _ivy(parts, [(-0.62, -CR_PIL_OUT - 0.17, -0.05), (-0.66, -CR_PIL_OUT - 0.17, 0.4), (-0.6, -CR_PIL_OUT - 0.17, 0.85),
                     (-0.66, -CR_PIL_OUT - 0.17, 1.25)], (0, -1, 0.1), seed=937, every=0.07)
    if k >= 3:
        _ivy(parts, [(0.74, -CR_PIL_OUT - 0.17, -0.1), (0.7, -CR_PIL_OUT - 0.17, 0.4), (0.78, -CR_PIL_OUT - 0.17, 0.9),
                     (0.72, -CR_PIL_OUT - 0.17, 1.3)], (0, -1, 0.1), seed=933, every=0.08)
        _ivy(parts, [(1.53, 0.1, 0.0), (1.535, 0.3, 0.5), (1.535, 0.2, 0.85)], (1, 0, 0.1), seed=934, every=0.08)
        # trailing over the far shaft wall's coping into the shaft
        _ivy(parts, [(1.1, -0.4, CR_PARAPET + 0.1), (1.0, -0.8, CR_PARAPET + 0.1), (0.79, -1.0, CR_PARAPET - 0.1),
                     (0.79, -1.15, 0.0), (0.79, -1.1, -0.4)], (-1, 0, 0.4), seed=938, every=0.07)
    # grass and a fern on the cornice / at the wall feet (cheap cones)
    for i, p in enumerate(((-0.9, -0.08, CR_CORNICE + 0.02), (0.95, -0.1, CR_CORNICE + 0.02), (-1.45, -2.0, 0.0), (1.45, -1.2, 0.0))):
        if i >= 4 - (level - 1):
            continue
        for j in range(3):
            a = rnd.uniform(0, math.tau)
            parts.append(L.part("cone", L.mix(GRASS_B, GRASS_DRY, rnd.uniform(0, 0.6)), loc=(p[0] + 0.03 * math.cos(a),
                                p[1] + 0.03 * math.sin(a), p[2] + 0.07), vertices=3, radius1=0.02, depth=0.15,
                                rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), 0)))


def _crypt_door_leaf(parts) -> None:
    """The iron-clad double door standing open: two leaves swung in against the reveals (each half as
    wide as the opening, so they stay inside the wall)."""
    hw = CR_DOOR_HW - 0.02
    for sx in (-1, 1):
        leaf = []
        poly = [(0.0, -CR_D + 0.02), (hw, -CR_D + 0.02), (hw, CR_SPRING)]
        for k in range(1, 5):
            a = math.pi / 2 * k / 4
            poly.append((hw * math.cos(a), CR_SPRING + hw * math.sin(a)))
        if sx < 0:
            poly = [(-x, z) for x, z in reversed(poly)]
        plate = _prism(poly, "y", CR_WALL_Y + 0.08, CR_WALL_Y + 0.12, "door")
        L.subdivide(plate, 1)
        leaf.append(_paint(plate, L.hexc("#38393B"), var=0.2, ao=0.55, top=0.1, seed=500 + sx, hue_shift=L.mix(IRON, RUST, 0.55)))
        for z in (-0.95, -0.25, 0.35):
            leaf.append(_box((sx * hw / 2, CR_WALL_Y + 0.07, z), (hw / 2 - 0.03, 0.012, 0.035), IRON, seed=501, var=0.3, hue_shift=RUST,
                             ao=0.0, top=0.15))
        leaf.append(L.part("torus", IRON, loc=(sx * 0.1, CR_WALL_Y + 0.05, -0.35), rot=(90, 0, 0), major_radius=0.045,
                           minor_radius=0.01, major_segments=8, minor_segments=3, paint_kw={"hue_shift": RUST}))
        hinge = Vector((sx * hw, CR_WALL_Y + 0.1, 0.0))
        m = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-82 * sx), 4, "Z") @ Matrix.Translation(-hinge)
        for o in leaf:
            o.data.transform(m)
        parts += leaf


def _crypt_gate(parts) -> None:
    """Level 3: a wrought-iron gate of two leaves at the stair foot, both standing open against the
    shaft walls."""
    hgt = 1.25
    for sx in (-1, 1):
        x = sx * (CR_SHAFT - 0.035)
        y0, y1 = -0.08, -0.08 - 0.78
        base = -CR_D + 0.02
        for k in range(6):
            yy = y0 + (y1 - y0) * (k + 0.5) / 6
            top = hgt + 0.1 * math.sin(math.pi * (k + 0.5) / 6)
            parts.append(P._stick((x, yy, base), (x, yy, base + top), 0.011, IRON, verts=4, hue_shift=RUST, var=0.3, ao=0.1))
            parts.append(L.part("cone", IRON, loc=(x, yy, base + top + 0.035), radius1=0.02, depth=0.07, vertices=4))
        for z in (0.12, 0.62, hgt - 0.05):
            parts.append(P._stick((x, y0, base + z), (x, y1, base + z), 0.014, IRON, verts=4, hue_shift=RUST, var=0.3, ao=0.1))
        parts.append(P._stick((x, y0, base), (x, y0, base + hgt + 0.12), 0.02, IRON, verts=5, hue_shift=RUST, ao=0.1))


def _crypt_tablet(parts, stones) -> Vector:
    """Level 3: the name tablet in the frieze (pale dressed stone with a dark carved border); returns
    the face centre for the inscription label."""
    z = (CR_FRIEZE[0] + CR_FRIEZE[1]) / 2
    y = CR_WALL_Y - 0.083            # the frieze's front lies at -0.06
    stones.append(_box((0.0, y, z), (0.86, 0.025, 0.1), L.hexc("#9A978B"), jit=0.003, seed=520, var=0.08, ao=0.0, top=0.2))
    for sx in (-1, 1):
        parts.append(_box((sx * 0.82, y - 0.027, z), (0.006, 0.003, 0.075), L.scale_c(CR_ST_D, 0.7), var=0.0, ao=0.0))
    return Vector((0.0, y - 0.03, z))


def _crypt(level: int) -> None:
    L.reset(600 + level)
    parts = []
    stones = []
    pts = _crypt_wall(parts, stones, level)
    caps = _crypt_shaft(parts, stones, level)
    _crypt_door_leaf(parts)
    markers = [("door_outside", CR_DOOR), ("build", CR_BUILD)]
    for i, c in enumerate(caps):
        markers.append(("light_lantern_%d" % (i + 1), tuple(_post_lantern(parts, c, seed=530 + i))))
    if level == 1:
        # the acroterion broken off: a stump on the apex, the piece lying in the grass by the wing
        stones.append(_stone((0.0, -0.02, CR_APEX + 0.1), (0.11, 0.13, 0.08), CR_ST_P, seed=540, jit=0.01, moss=0.8))
        stones.append(_stone((-1.22, 0.7, 0.06), (0.16, 0.11, 0.07), CR_ST_P, rot=(8, -14, 37), seed=541, jit=0.012,
                             moss=0.9))
        stones.append(_stone((-1.42, 0.45, 0.04), (0.08, 0.1, 0.05), CR_ST, rot=(0, 10, 70), seed=542, jit=0.012, moss=0.9))
        # a crack running down the tympanum
        for k in range(4):
            parts.append(_box((0.18 - 0.07 * k, -0.026, CR_APEX - 0.18 - 0.11 * k), (0.008, 0.003, 0.06), GAP, rot=(0, 25 - 18 * k, 0),
                              var=0.0, ao=0.0))
        # an eroded boss in the tympanum
        boss = L.prim("ico", loc=(0.0, -0.03, CR_CORNICE + 0.22), radius=0.13, subdivisions=1, scale=(1.0, 0.35, 1.0))
        L.jitter(boss, 0.02, 5.0, 543)
        stones.append(_paint(boss, CR_ST, var=0.2, ao=0.2, seed=543))
    else:
        # repaired: the cross on the apex, balls on the pediment ends, a wreath in the tympanum
        cross_col = CR_ST_NEW if level == 2 else IRON
        _cross(parts, Vector((0.0, -0.02, CR_APEX + 0.06)), 0.5 if level == 2 else 0.55, color=cross_col, seed=550)
        stones.append(_stone((0.0, -0.02, CR_APEX + 0.06), (0.12, 0.14, 0.06), CR_ST_NEW, seed=551, jit=0.006, top=0.15))
        for sx in (-1, 1):
            stones.append(_stone((sx * (CR_CW + 0.02), -0.04, CR_CORNICE + 0.07), (0.1, 0.1, 0.05), CR_ST_NEW, seed=552 + sx, jit=0.005))
            ball = L.prim("ico", loc=(sx * (CR_CW + 0.02), -0.04, CR_CORNICE + 0.22), radius=0.1, subdivisions=1)
            L.jitter(ball, 0.008, 5.0, 556 + sx)
            stones.append(_paint(ball, CR_ST_NEW, var=0.15, ao=0.2, top=0.15, seed=556 + sx))
        wreath = L.prim("torus", loc=(0.0, -0.035, CR_CORNICE + 0.24), rot=(90, 0, 0), major_radius=0.15, minor_radius=0.035,
                        major_segments=10, minor_segments=4)
        L.jitter(wreath, 0.008, 6.0, 558)
        stones.append(_paint(wreath, CR_ST_P, var=0.2, ao=0.3, top=0.15, seed=558))
        # a handrail along the north shaft wall
        rail = [Vector((CR_SHAFT - 0.07, -CR_END + 0.6, 0.85)), Vector((CR_SHAFT - 0.07, -CR_FOOT - 0.15, -CR_D + 0.85))]
        parts.append(P._stick(rail[0], rail[1], 0.016, IRON, verts=5, hue_shift=RUST, ao=0.0))
        for t in (0.08, 0.5, 0.92):
            p = rail[0].lerp(rail[1], t)
            parts.append(P._stick(p, Vector((CR_SHAFT - 0.005, p.y, p.z)), 0.01, IRON, verts=4, ao=0.0))
    _crypt_overgrowth(parts, level, pts["wing_top"])
    if level >= 3:
        _crypt_gate(parts)
        face = _crypt_tablet(parts, stones)
        light = _cage_lantern(parts, CR_WALL_Y - 0.1, Vector((0.0, -0.62, CR_CAP - 0.05)), seed=560)
        markers.append(("light_lantern", tuple(light)))
    else:
        face = Vector((0.0, CR_WALL_Y - 0.061, (CR_FRIEZE[0] + CR_FRIEZE[1]) / 2))   # the old frieze face
    markers.append(("inscription", tuple(face)))
    _weather(stones, seed=level, moss=0.9 if level == 1 else (0.65 if level == 2 else 0.5))
    obj = _done(parts + stones, "ph_bld_crypt_l%d" % level, markers)
    e = next(c for c in obj.children if c.name == "inscription")
    e.rotation_euler = (0.0, 0.0, 0.0)


def crypt_l1():
    _crypt(1)


def crypt_l2():
    _crypt(2)


def crypt_l3():
    _crypt(3)


def crypt_site():
    """Level 0: the crypt neck uncovered and filled in again - an earth mound with the top of the old
    pediment showing, boards laid over the stair neck, pegs and string round the site."""
    L.reset(640)
    parts = []
    mound = _grid_mound(-1.4, 1.4, -0.9, 0.55, 12, 8,
                        lambda x, y: max(-0.03, 0.55 * max(0.0, 1.0 - (abs(x / 1.4) ** 2.2 + abs((y + 0.15) / 0.75) ** 2.2))
                                         ** 0.6 + 0.04 * noise.noise(Vector((x * 2.6, y * 2.6, 0.2)))), "mound")
    P._paint_fn(mound, lambda co, vi: L.mix(_sod_colour(co, 4.0), EARTH, max(0.0, min(1.0, 0.5 + co.y * 0.6 +
                                                                                     noise.noise(co * 3.0) * 0.4))))
    L.set_mat(mound, L.MAT_GROUND)
    parts.append(mound)
    y = -0.05
    for row, (z, w) in enumerate(((0.25, 0.9), (0.45, 0.62), (0.62, 0.34))):
        a = -w
        k = 0
        while a < w - 0.05:
            ln = min(random.uniform(0.24, 0.36), w - a)
            parts.append(_stone((a + ln / 2, y, z), (ln / 2 * 0.95, 0.08, 0.09), random.choice((CR_ST, CR_ST_D)),
                                seed=650 + row * 10 + k, moss=1.0, rot=(random.uniform(-6, 6), 0, 0)))
            a += ln
            k += 1
    hole = _grid_mound(-0.75, 0.75, -2.4, -0.6, 4, 6, lambda x, yy: 0.015, "hole")
    P._paint_fn(hole, lambda co, vi: L.scale_c(EARTH_DARK, 0.55 + 0.4 * min(1.0, (-0.6 - co.y) / 1.6)))
    L.set_mat(hole, L.MAT_PAINTED)
    parts.append(hole)
    for i in range(7):
        parts.append(P._plank((random.uniform(-0.05, 0.05), -0.85 - i * 0.24, 0.05), (0.62, 0.1, 0.022), WOOD_OLD, seed=680 + i,
                              rot=(random.uniform(-3, 3), 0, random.uniform(-5, 5)), cuts=1))
    parts.append(P._heap(-1.05, -1.6, 0.38, 0.5, 0.3, 5))
    parts.append(P._heap(1.05, -2.1, 0.3, 0.42, 0.22, 6))
    parts += P._clods(6, (-1.3, 1.3), (-2.6, -1.0), EARTH_FRESH, z=0.03, seed=690)
    _pegs(parts, ((-1.45, -2.7), (1.45, -2.7), (1.45, 0.55), (-1.45, 0.55)), seed=695)
    _done(parts, "ph_bld_crypt_site", [("build", CR_BUILD)])


# ==================================================================================================
# KAPELLE (chapel) – footprint 5.2 x 7.0 m (x -2.6..2.6, y -3.5..3.5), door south
# ==================================================================================================

CH_W = 2.2               # nave: outer half width
CH_Y0 = -3.3             # nave front face (south)
CH_Y1 = 1.9              # nave north end
CH_T = 0.36              # wall thickness
CH_EAVE = 3.3
CH_PITCH = math.radians(50.0)
CH_ROOF_X = 2.5          # the eaves reach this far
CH_RIDGE = CH_EAVE - 0.1 + CH_ROOF_X * math.tan(CH_PITCH)      # 6.18 m
CC_W = 1.4               # choir: outer half width
CC_Y1 = 3.25             # choir north face
CC_EAVE = 2.85
CC_ROOF_X = 1.65
CC_RIDGE = CC_EAVE - 0.1 + CC_ROOF_X * math.tan(CH_PITCH)
DOOR_W, DOOR_SPRING = 1.1, 1.72
WIN_W, WIN_SILL, WIN_SPRING = 0.56, 1.45, 2.3
WIN_Y = (-1.85, 0.25)    # the two side windows of each long wall
CHOIR_WIN_W, CHOIR_WIN_SILL, CHOIR_WIN_SPRING = 0.64, 0.95, 1.85
OCULUS_Z, OCULUS_R = 4.25, 0.3
TURRET_Y = -2.2          # ridge turret (Dachreiter), towards the front: the camera sees it
BELL_Z = 7.08            # yoke axis of the bell


def _plaster_fn(z0: float, z1: float, seed: float, stones: float = 0.25, dirty: float = 1.0):
    """Lime wash: warm grey with soft blotches, a damp band at the foot, patches where the wash has
    fallen off and the rubble shows."""
    def fn(co, vi):
        n = noise.noise(Vector((co.x * 1.3, co.y * 1.3, co.z * 1.3 + seed)))
        f = noise.noise(Vector((co.x * 3.1 + seed, co.y * 3.1, co.z * 3.1)))
        h = max(0.0, min(1.0, (co.z - z0) / max(1e-6, z1 - z0)))
        c = L.mix(PLASTER, PLASTER_DIRTY, 0.35 + 0.35 * n)
        c = L.mix(c, L.mix(PLASTER_DIRTY, MOSS_DARK, 0.3), dirty * max(0.0, 0.55 - h * 2.2))
        if f > 1.0 - stones:
            c = L.mix(c, STONE_OLD, min(1.0, (f - 1.0 + stones) * 6.0))
        return L.scale_c(c, 0.9 + 0.12 * h)
    return fn


def _pwall(parts, axis: str, plane: float, out: float, a0: float, a1: float, z0: float, z1: float, holes=(),
           seed: int = 0, thick: float = CH_T, top=None, arch: bool = True, stones: float = 0.25):
    """Plastered wall slab between a0..a1 (along x for axis 'y' walls, along y for axis 'x' walls),
    outer face at `plane` (outward sign `out`), with round-headed holes [(centre, width, sill, spring)].
    top(a) optionally gives a sloped / broken top."""
    inner = plane - out * thick

    def slab(b0, b1, zb, ztop):
        """ztop: a height or a function of a (sampled every ~0.3 m: gables, broken tops)."""
        if b1 - b0 < 0.02:
            return
        if callable(ztop):
            n = max(1, int(math.ceil((b1 - b0) / 0.3)))
            tops = [(b1 - (b1 - b0) * k / n, ztop(b1 - (b1 - b0) * k / n)) for k in range(n + 1)]
            if b0 < 0.0 < b1 and top is not None and not any(abs(a) < 0.02 for a, _ in tops):
                tops.append((0.0, ztop(0.0)))
                tops.sort(key=lambda p: -p[0])
        else:
            tops = [(b1, ztop), (b0, ztop)]
        if max(z for _, z in tops) - zb < 0.02:
            return
        poly = [(b0, zb), (b1, zb)] + [(a, max(zb + 0.01, z)) for a, z in tops]
        o = _prism(poly, axis, min(plane, inner), max(plane, inner), "wall")
        if len(tops) <= 3 and (b1 - b0 > 1.2 or max(z for _, z in tops) - zb > 1.2):
            L.subdivide(o, 1)
        L.jitter(o, 0.008, 2.0, seed + int(b0 * 10))
        P._paint_fn(o, _plaster_fn(z0, z1, seed * 0.37, stones))
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)

    def t(a):
        return top(a) if top is not None else z1
    edges = [a0]
    spans = []
    for c, w, sill, spring in sorted(holes):
        spans.append((c - w / 2, c + w / 2, sill, spring, w / 2))
    cur = a0
    for b0, b1, sill, spring, r in spans:
        slab(cur, b0, z0, t)
        if sill > z0 + 0.02:
            slab(b0, b1, z0, sill)
        top_hole = spring + (r if arch else 0.0)
        slab(b0, b1, top_hole, t)
        if arch:  # spandrels between the round head and the square cut
            for side in (-1, 1):
                cx = (b0 + b1) / 2
                pts = [(cx + side * r, spring), (cx + side * r, top_hole)]
                for k in range(0, 4):
                    ang = math.pi / 2 * k / 4
                    pts.append((cx + side * r * math.sin(ang), spring + r * math.cos(ang)))
                o = _prism(pts, axis, min(plane, inner), max(plane, inner), "spandrel")
                P._paint_fn(o, _plaster_fn(z0, z1, seed * 0.37, stones))
                L.set_mat(o, L.MAT_PAINTED)
                parts.append(o)
        cur = b1
    slab(cur, a1, z0, t)
    del edges


def _quoins(parts, x: float, y: float, sx: int, sy: int, z0: float, z1: float, seed: int, color=STONE_PALE):
    """Dressed corner stones, alternately long on the front and on the side face."""
    z = z0
    k = 0
    while z < z1 - 0.1:
        h = min(0.3, z1 - z)
        lf, ls = (0.46, 0.24) if k % 2 == 0 else (0.24, 0.46)
        # front face (normal sy*Y) and side face (normal sx*X) share the corner block
        parts.append(_stone((x - sx * lf / 2, y + sy * 0.03, z + h / 2), (lf / 2, 0.05, h / 2 * 0.93), color,
                            seed=seed + k, jit=0.006, var=0.14, top=0.2))
        parts.append(_stone((x + sx * 0.03, y - sy * ls / 2, z + h / 2), (0.05, ls / 2, h / 2 * 0.93), color,
                            seed=seed + 50 + k, jit=0.006, var=0.14, top=0.2))
        z += h
        k += 1


def _plinth(parts, x0, x1, y0, y1, seed: int):
    """Rubble socle band (0.32 m) around a block, a little proud of the plaster."""
    for (cx, cy, hx, hy) in (((x0 + x1) / 2, y0, (x1 - x0) / 2 + 0.05, 0.05), ((x0 + x1) / 2, y1, (x1 - x0) / 2 + 0.05, 0.05),
                             (x0, (y0 + y1) / 2, 0.05, (y1 - y0) / 2), (x1, (y0 + y1) / 2, 0.05, (y1 - y0) / 2)):
        o = _box((cx, cy, 0.14), (hx, hy, 0.17), STONE_OLD, jit=0.012, jfreq=4.0, cuts=1, seed=seed, var=0.3, ao=0.4,
                 hue_shift=STONE_DARK)
        P._tint_up(o, MOSS, 0.6, 0.4, seed=seed)
        parts.append(o)
        seed += 1


def _slate_roof(parts, x_eave: float, z_eave: float, ridge: float, y0: float, y1: float, seed: int,
                sw=(0.34, 0.5), row: float = 0.3, mossy: float = 0.2, sides=(-1, 1), skip=None, palette=None,
                deck_col=None):
    """Two slate slopes from the ridge (x = 0) down to the eaves at +-x_eave, between y0..y1.
    Each slate is its own quad with a thin butt face (painted per slate); a dark deck hides gaps.
    skip(side, y0, y1, t) -> True leaves a slate out (openings for the turret)."""
    pitch = math.atan2(ridge - z_eave, x_eave)
    slope = math.hypot(x_eave, ridge - z_eave)
    c_base, c_dark, c_light = palette if palette is not None else (SLATE, SLATE_DARK, SLATE_LIGHT)
    bm = bmesh.new()
    cols = []
    for s in sides:
        nrm = Vector((s * math.sin(pitch), 0, math.cos(pitch)))
        down = Vector((s * math.cos(pitch), 0, -math.sin(pitch)))
        top = Vector((0, 0, ridge))
        deck = L.prim("cube", loc=top + down * (slope / 2) - nrm * 0.03, scale=(slope / 2, (y1 - y0) / 2, 0.02),
                      rot=(0, math.degrees(s * pitch), 0))
        deck.data.transform(Matrix.Translation((0, (y0 + y1) / 2, 0)))
        parts.append(_paint(deck, c_dark if deck_col is None else deck_col, var=0.1, ao=0.0, top=0.0))
        rows = max(2, int(slope / row))
        single = len(sides) == 1          # a lean-to: slates end flush with the high and the low edge
        step = slope / (rows + 0.55) if single else slope / (rows - 0.3)
        for r in range(rows):
            ln = step * 1.55
            t = (ln / 2 + r * step) if single else (0.08 + r * step)
            y = y0 - (random.uniform(0.1, 0.2) if r % 2 else 0.0)
            while y < y1 - 0.03:
                w = min(random.uniform(*sw), y1 - y)
                if w < 0.08:
                    break
                ya, yb = max(y, y0), y + w
                if skip is not None and skip(s, ya, yb, t):
                    y = yb
                    continue
                tt = t + random.uniform(-0.02, 0.02)
                lift = random.uniform(0.015, 0.03)
                base = top + down * tt + nrm * 0.01
                up_a = base - down * (ln / 2) + Vector((0, ya, 0))
                up_b = base - down * (ln / 2) + Vector((0, yb - 0.004, 0))
                lo_b = base + down * (ln / 2) + Vector((0, yb - 0.004, 0)) + nrm * lift
                lo_a = base + down * (ln / 2) + Vector((0, ya, 0)) + nrm * lift
                vs = [bm.verts.new(p) for p in (up_a, up_b, lo_b, lo_a)]
                f = bm.faces.new(vs)
                f.normal_update()
                if f.normal.dot(nrm) < 0:
                    f.normal_flip()
                bl = bm.verts.new(lo_a - nrm * (lift + 0.025))
                br = bm.verts.new(lo_b - nrm * (lift + 0.025))
                g = bm.faces.new((vs[3], vs[2], br, bl))
                g.normal_update()
                if g.normal.dot(down) < 0:
                    g.normal_flip()
                edge = max(0.0, (tt / slope - 0.7) / 0.3)
                n = 0.5 + 0.5 * noise.noise(Vector(((ya + yb) * 0.7, tt * 0.8, s * 3.0 + seed)))
                base_c = L.mix(c_base, random.choice((c_dark, c_light, c_base, c_dark)), random.uniform(0.2, 0.6))
                base_c = L.scale_c(base_c, random.uniform(0.94, 1.06))
                m = mossy * (edge * 0.8 + max(0.0, n - 0.72) * 2.5)
                cols.append(L.mix(base_c, L.mix(MOSS, L.hexc("#7A7E60"), random.random()), min(0.7, m)))
                cols.append(L.scale_c(cols[-1], 0.55))
                y = yb
    me = bpy.data.meshes.new("slates")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("slates", me)
    bpy.context.collection.objects.link(o)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        c = cols[poly.index]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            cc = L.scale_c(c, 1.0 + noise.noise(co * 2.3) * 0.06)
            attr.data[li].color = (L._to_lin(cc[0]), L._to_lin(cc[1]), L._to_lin(cc[2]), 1.0)
    L.set_mat(o, L.MAT_PAINTED)
    parts.append(o)
    # ridge: a row of dark capping pieces
    if len(sides) == 2:
        k = 0
        y = y0 - 0.02
        while y < y1:
            w = min(0.42, y1 + 0.02 - y)
            parts.append(_box((0.0, y + w / 2, ridge + 0.045), (0.09, w / 2 * 0.97, 0.05), SLATE_DARK, jit=0.006,
                              seed=seed + 300 + k, var=0.15, ao=0.0, top=0.3))
            y += w
            k += 1


def _window(parts, axis: str, plane: float, out: float, c: float, w: float, sill: float, spring: float,
            seed: int, stained: bool = False, glass: bool = True, simple: bool = False):
    """Round-headed window in a wall face: stone surround (jambs, arch, sill), recessed leaded pane."""
    r = w / 2
    depth = CH_T * 0.55

    def at(a, n, z):
        return Vector((a, plane + out * n, z)) if axis == "y" else Vector((plane + out * n, a, z))

    def half(a, n, z):
        return (a, n, z) if axis == "y" else (n, a, z)
    if glass:
        pane = _prism(_arch_poly(c, w, sill, spring, 6), axis, plane - out * depth, plane - out * (depth - 0.02), "pane")
        if stained:
            def fn(co, vi):
                a = co.x if axis == "y" else co.y
                u = int((a - c + r) / (w / 3))
                v = int((co.z - sill) / 0.22)
                return L.scale_c(STAIN[(u * 3 + v * 2) % len(STAIN)], 0.95 + 0.1 * noise.noise(co * 9.0))
            P._paint_fn(pane, fn)
        else:
            P._paint_fn(pane, lambda co, vi: L.mix(GLASS, GLASS_DEEP, 0.5 + 0.5 * noise.noise(co * 4.0)))
        L.set_mat(pane, L.MAT_PAINTED)
        parts.append(pane)
        # lead cames: two verticals, three horizontals (diamond panes would cost too much)
        for k in ((0,) if simple else (-1, 1)):
            parts.append(_box(at(c + k * r / 3, -depth + 0.03, (sill + spring) / 2 + 0.05), half(0.008, 0.008, (spring - sill) / 2 + 0.05),
                              LEAD, var=0.0, ao=0.0))
        for k in range(1 if simple else 3):
            parts.append(_box(at(c, -depth + 0.03, sill + (spring - sill) * (k + 1) / 3.3), half(r, 0.008, 0.008),
                              LEAD, var=0.0, ao=0.0))
    # reveal: dark jamb faces inside the opening (the wall slab has a square cut)
    for k in (-1, 1):
        parts.append(_box(at(c + k * (r + 0.005), -depth / 2, (sill + spring) / 2), half(0.006, depth / 2, (spring - sill) / 2),
                          L.scale_c(PLASTER_DIRTY, 0.7), var=0.1, ao=0.0))
    # surround
    for k in (-1, 1):
        z = sill
        i = 0
        while z < spring - 0.04:
            h = min((0.45 if simple else 0.28) if i % 2 == 0 else (0.4 if simple else 0.2), spring - z)
            ww = 0.14 if i % 2 == 0 else 0.1
            parts.append(_stone(at(c + k * (r + ww / 2), 0.02, z + h / 2), half(ww / 2, 0.05, h / 2 * 0.94), STONE_PALE,
                                seed=seed + i + k * 7, jit=0.005, var=0.14, top=0.2))
            z += h
            i += 1
    if axis == "y":
        _voussoirs(parts, c, plane - out * 0.03, out, spring, r, 5, 0.1, 0.13, seed=seed + 20)
    else:
        vs = []
        _voussoirs(vs, 0.0, 0.0, 1, spring, r, 3 if simple else 5, 0.1, 0.13, seed=seed + 20)
        for o in vs:   # built in the x-z plane at y = 0..0.1, turned onto the x wall
            o.data.transform(Matrix.Translation((plane + out * 0.07, c, 0)) @ Matrix.Rotation(math.radians(90 * out), 4, "Z")
                             @ Matrix.Translation((0, 0, 0)))
            parts.append(o)
    parts.append(_stone(at(c, 0.08, sill - 0.05), half(r + 0.12, 0.1, 0.05), STONE_PALE, seed=seed + 30, jit=0.005, top=0.3))


def _chapel_door(parts, leaf: bool, seed: int = 400) -> None:
    """Round-headed double door in the south front: plank leaves with iron straps and a ring,
    stone jambs and arch, a worn step."""
    y = CH_Y0
    r = DOOR_W / 2
    if leaf:
        for k in range(6):
            x0 = -r + k * DOOR_W / 6
            x1 = x0 + DOOR_W / 6 - 0.008
            pts = _arch_poly(0.0, DOOR_W, 0.0, DOOR_SPRING, 10)
            # clip the arched outline to this board's strip
            zt0 = DOOR_SPRING + math.sqrt(max(0.0, r * r - x0 * x0))
            zt1 = DOOR_SPRING + math.sqrt(max(0.0, r * r - x1 * x1))
            o = _prism([(x0, 0.0), (x1, 0.0), (x1, zt1 - 0.01), (x0, zt0 - 0.01)], "y", y + 0.1, y + 0.15, "board")
            del pts
            parts.append(_paint(o, L.scale_c(WOOD_DARK, random.uniform(0.85, 1.15)), var=0.15, ao=0.35, seed=seed + k,
                                hue_shift=WOOD))
        parts.append(_box((0.0, y + 0.09, DOOR_SPRING * 0.55), (0.012, 0.012, DOOR_SPRING * 0.55), GAP, var=0.0, ao=0.0))
        for z in (0.4, 1.35):
            for sx in (-1, 1):
                parts.append(_box((sx * r * 0.5, y + 0.085, z), (r * 0.45, 0.008, 0.03), IRON, var=0.25, hue_shift=RUST,
                                  ao=0.0, top=0.2))
        for sx in (-1, 1):
            parts.append(L.part("torus", IRON, loc=(sx * 0.14, y + 0.075, 1.0), rot=(90, 0, 0), major_radius=0.05,
                                minor_radius=0.01, major_segments=8, minor_segments=3))
    for k in (-1, 1):
        parts.append(_box((k * (r + 0.004), y + CH_T / 2, DOOR_SPRING / 2), (0.006, CH_T / 2, DOOR_SPRING / 2),
                          L.scale_c(PLASTER_DIRTY, 0.6), var=0.1, ao=0.0))
        z = 0.0
        i = 0
        while z < DOOR_SPRING - 0.04:
            h = min(0.34 if i % 2 == 0 else 0.24, DOOR_SPRING - z)
            ww = 0.2 if i % 2 == 0 else 0.13
            parts.append(_stone((k * (r + ww / 2), y - 0.03, z + h / 2), (ww / 2, 0.06, h / 2 * 0.95), STONE_PALE,
                                seed=seed + 20 + i + k * 9, jit=0.006, var=0.14, top=0.2))
            z += h
            i += 1
    _voussoirs(parts, 0.0, y + 0.04, -1, DOOR_SPRING, r, 9, 0.13, 0.18, seed=seed + 40)
    parts.append(_stone((0.0, y - 0.19, 0.06), (r + 0.3, 0.17, 0.06), STONE_DARK, seed=seed + 60, jit=0.01, top=0.3))


def _gable_top(x: float, ridge: float, half: float, eave: float) -> float:
    return eave + (ridge - eave) * max(0.0, 1.0 - abs(x) / half)


def _chapel_body(parts, level: int, seed: int = 1) -> None:
    """Nave and choir walls with windows, door, quoins, socle, gables (roofed levels)."""
    ruin = level == 0
    g_ridge = CH_RIDGE - 0.12
    g_eave = CH_EAVE - 0.1 + (CH_ROOF_X - CH_W) * math.tan(CH_PITCH) - 0.12

    def front_top(a):
        if ruin:   # the broken gable: jagged, higher on the west
            return 2.7 + 0.55 * max(0.0, -a / CH_W) + 0.25 * noise.noise(Vector((a * 3.0, 0.3, 0.0))) + (
                0.9 * max(0.0, 1.0 - abs(a + 0.9) / 0.7))
        return _gable_top(a, g_ridge, CH_W, g_eave)

    def side_top(a):
        if ruin:
            return 2.35 + 0.45 * noise.noise(Vector((a * 1.1, 2.0, 0.5))) + 0.3 * max(0.0, (-a - 1.0) / 2.3)
        return CH_EAVE
    # south front (door + oculus in the gable)
    _pwall(parts, "y", CH_Y0, -1, -CH_W, CH_W, 0.0, g_ridge, [(0.0, DOOR_W, 0.0, DOOR_SPRING)], seed=seed,
           top=front_top, stones=0.45 if ruin else 0.22)
    # long walls with two windows each
    for sx in (-1, 1):
        holes = [(y, WIN_W, WIN_SILL, WIN_SPRING) for y in WIN_Y]
        _pwall(parts, "x", sx * CH_W, sx, CH_Y0 + 0.001, CH_Y1, 0.0, CH_EAVE, holes, seed=seed + 10 + sx,
               top=side_top, stones=0.45 if ruin else 0.22)
    # north wall of the nave beside the choir (and its gable over the choir roof)
    for sx in (-1, 1):
        a0, a1 = (CC_W, CH_W) if sx > 0 else (-CH_W, -CC_W)
        _pwall(parts, "y", CH_Y1, 1, a0, a1, 0.0, CH_EAVE, seed=seed + 20 + sx, top=(lambda a: side_top(3.0)) if ruin else None)
    if not ruin:
        gab = _prism([(-CH_W, CH_EAVE), (CH_W, CH_EAVE), (0.0, g_ridge)], "y", CH_Y1 - CH_T, CH_Y1, "gable_n")
        P._paint_fn(gab, _plaster_fn(0.0, g_ridge, 3.0))
        L.set_mat(gab, L.MAT_PAINTED)
        parts.append(gab)
    # choir
    ch_top = (lambda a: 2.1 + 0.3 * noise.noise(Vector((a * 2.0, 5.0, 0.0))) + 0.4) if ruin else None
    for sx in (-1, 1):
        _pwall(parts, "x", sx * CC_W, sx, CH_Y1 - CH_T, CC_Y1, 0.0, CC_EAVE, seed=seed + 30 + sx, top=ch_top)
    _pwall(parts, "y", CC_Y1, 1, -CC_W, CC_W, 0.0, CC_EAVE,
           [(0.0, CHOIR_WIN_W, CHOIR_WIN_SILL, CHOIR_WIN_SPRING)], seed=seed + 40, top=ch_top)
    if not ruin:
        cg = _prism([(-CC_W, CC_EAVE), (CC_W, CC_EAVE), (0.0, CC_RIDGE - 0.12)], "y", CC_Y1 - CH_T, CC_Y1, "gable_c")
        P._paint_fn(cg, _plaster_fn(0.0, CC_RIDGE, 5.0))
        L.set_mat(cg, L.MAT_PAINTED)
        parts.append(cg)
    # socle, quoins, openings
    _plinth(parts, -CH_W, CH_W, CH_Y0, CH_Y1, seed + 50)
    _plinth(parts, -CC_W, CC_W, CH_Y1, CC_Y1, seed + 60)
    for sx in (-1, 1):
        _quoins(parts, sx * (CH_W + 0.005), CH_Y0 - 0.005, sx, -1, 0.3, (2.4 if ruin else CH_EAVE), seed + 70 + sx * 20)
    _chapel_door(parts, leaf=not ruin)
    for sx in (-1, 1):
        for i, y in enumerate(WIN_Y):
            _window(parts, "x", sx * CH_W, sx, y, WIN_W, WIN_SILL, WIN_SPRING, seed + 100 + i * 40 + sx * 10,
                    glass=not ruin, simple=True)
    _window(parts, "y", CC_Y1, 1, 0.0, CHOIR_WIN_W, CHOIR_WIN_SILL, CHOIR_WIN_SPRING, seed + 200,
            stained=level >= 3, glass=not ruin)
    if not ruin:
        # oculus in the front gable: a stone ring round a dark round pane
        ring = L.prim("torus", loc=(0.0, CH_Y0 - 0.03, OCULUS_Z), rot=(90, 0, 0), major_radius=OCULUS_R + 0.05,
                      minor_radius=0.07, major_segments=12, minor_segments=4)
        parts.append(_paint(ring, STONE_PALE, var=0.12, ao=0.0, top=0.25))
        disc = L.prim("cyl", loc=(0.0, CH_Y0 + 0.02, OCULUS_Z), rot=(90, 0, 0), radius=OCULUS_R, depth=0.04, vertices=12)
        parts.append(_paint(disc, GLASS, var=0.2, ao=0.0))
        for k in range(2):
            parts.append(_box((0.0, CH_Y0 - 0.0, OCULUS_Z), (OCULUS_R, 0.008, 0.008), LEAD, rot=(0, 45 + 90 * k, 0),
                              var=0.0, ao=0.0))
        # gable coping on the front, cross on the apex
        rake = math.degrees(math.atan2(g_ridge - g_eave, CH_W))
        ln = math.hypot(CH_W + 0.3, g_ridge - g_eave)
        for sx in (-1, 1):
            parts.append(_stone((sx * (CH_W + 0.3) / 2, CH_Y0 + 0.02, (g_eave + g_ridge) / 2 + 0.02),
                                (ln / 2, 0.14, 0.06), STONE_PALE, rot=(0, sx * rake, 0), seed=seed + 250 + sx, jit=0.006,
                                top=0.3))
        _cross(parts, Vector((0.0, CH_Y0 + 0.02, g_ridge + 0.1)), 0.6, seed=seed + 260)


def _turret_skip(s, ya, yb, t):
    """Slates left out where the turret stands on the ridge."""
    return yb > TURRET_Y - 0.5 and ya < TURRET_Y + 0.5 and t < 0.75


def _turret(parts, seed: int = 500):
    """Dachreiter: a slated box on the ridge, an open belfry with four posts and louvres, a slate
    spire, ball and iron cross (top <= 8.6 m).  Returns the bell pivot."""
    y = TURRET_Y
    hw = 0.46
    zb = CH_RIDGE - hw * math.tan(CH_PITCH) - 0.05
    z1 = CH_RIDGE + 0.32
    base = _box((0.0, y, (zb + z1) / 2), (hw, hw, (z1 - zb) / 2), SLATE, jit=0.006, cuts=1, seed=seed, var=0.2, ao=0.2,
                hue_shift=SLATE_DARK)
    parts.append(base)
    parts.append(_box((0.0, y, z1 + 0.03), (hw + 0.06, hw + 0.06, 0.03), WOOD_DARK, seed=seed + 1, var=0.15, ao=0.0))
    z2 = BELL_Z + 0.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box((sx * (hw - 0.05), y + sy * (hw - 0.05), (z1 + z2) / 2), (0.05, 0.05, (z2 - z1) / 2),
                              WOOD_DARK, seed=seed + 2, var=0.15, ao=0.2))
    for sx in (-1, 1):   # louvre boards on the east and west (the south / north stay open for the bell)
        for k in range(3):
            z = z1 + 0.18 + k * 0.2
            parts.append(_box((sx * (hw - 0.04), y, z), (0.02, hw - 0.1, 0.07), WOOD_OLD, rot=(0, sx * 30, 0),
                              seed=seed + 10 + k, var=0.15, ao=0.0))
    parts.append(_box((0.0, y, z2 + 0.03), (hw + 0.05, hw + 0.05, 0.03), WOOD_DARK, seed=seed + 20, var=0.15, ao=0.0))
    spire = L.prim("cone", loc=(0.0, y, z2 + 0.06 + 0.4), vertices=4, radius1=(hw + 0.12) * math.sqrt(2),
                   radius2=0.02, depth=0.8, rot=(0, 0, 45))
    L.subdivide(spire, 1)
    for v in spire.data.vertices:   # a little flare at the foot
        t = (v.co.z - (z2 + 0.06)) / 0.8
        if t < 0.3:
            s = 1.0 + 0.08 * (0.3 - t) / 0.3
            v.co.x *= s
            v.co.y = y + (v.co.y - y) * s
    P._paint_fn(spire, lambda co, vi: L.scale_c(L.mix(SLATE, SLATE_DARK, 0.5 + 0.5 * math.sin(co.z * 40.0)), 1.0))
    L.set_mat(spire, L.MAT_PAINTED)
    parts.append(spire)
    parts.append(L.part("ico", BRONZE, loc=(0.0, y, z2 + 0.88), radius=0.05, subdivisions=1))
    _cross(parts, Vector((0.0, y, z2 + 0.91)), 0.36, color=IRON, seed=seed + 30)
    return Vector((0.0, y, BELL_Z))


def _bell(pivot: Vector):
    """The bell as its own object (glTF node 'bell'): origin = the yoke axis, so an AnimationPlayer can
    swing it about Godot X."""
    prof = [(0.0, -0.36), (0.19, -0.36), (0.2, -0.33), (0.16, -0.24), (0.12, -0.14), (0.11, -0.07), (0.075, -0.035),
            (0.0, -0.03)]
    bm = bmesh.new()
    n = 10
    rings = []
    for r, z in prof:
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
                bm.faces.new((a[j], a[i], b[i], b[j]))
    bell = P._link(bm, "bell_body")
    _paint(bell, BRONZE, var=0.2, ao=0.35, top=0.2, hue_shift=L.hexc("#5E6A58"), seed=520)
    yoke = _box((0.0, 0.0, 0.0), (0.26, 0.05, 0.05), WOOD_DARK, seed=521, var=0.15, ao=0.0)
    clap = P._stick((0, 0, -0.06), (0, 0, -0.3), 0.012, IRON, verts=4)
    ball = L.part("ico", IRON, loc=(0, 0, -0.31), radius=0.03, subdivisions=1)
    obj = L.join([bell, yoke, clap, ball], "bell")
    obj.name = "bell"
    obj.data.name = "bell"
    obj.location = pivot
    return obj


def _chapel_roofs(parts, level: int) -> None:
    skip = _turret_skip if level >= 2 else None
    _slate_roof(parts, CH_ROOF_X, CH_EAVE - 0.1, CH_RIDGE, CH_Y0 - 0.25, CH_Y1 + 0.05, 10, skip=skip, sw=(0.42, 0.62),
                row=0.34)
    _slate_roof(parts, CC_ROOF_X, CC_EAVE - 0.1, CC_RIDGE, CH_Y1 - 0.2, CC_Y1 + 0.2, 20, sw=(0.42, 0.62), row=0.36)
    # verge boards along the front and the choir end
    for (ridge, xe, ze, y) in ((CH_RIDGE, CH_ROOF_X, CH_EAVE - 0.1, CH_Y0 - 0.26), (CC_RIDGE, CC_ROOF_X, CC_EAVE - 0.1, CC_Y1 + 0.21)):
        pitch = math.degrees(math.atan2(ridge - ze, xe))
        ln = math.hypot(xe, ridge - ze)
        for sx in (-1, 1):
            parts.append(_box((sx * xe / 2, y, (ridge + ze) / 2 + 0.02), (ln / 2 + 0.04, 0.03, 0.06), WOOD_DARK,
                              rot=(0, sx * pitch, 0), seed=30 + sx, var=0.15, ao=0.0))


def _chapel(level: int) -> None:
    L.reset(800 + level)
    parts = []
    _chapel_body(parts, level)
    _chapel_roofs(parts, level)
    children = []
    markers = [("door_outside", (0.0, CH_Y0 - 0.9, 0.0)), ("build", (2.95, -2.4, 0.0))]
    for i, (sx, y) in enumerate(((-1, WIN_Y[0]), (-1, WIN_Y[1]), (1, WIN_Y[0]), (1, WIN_Y[1]))):
        markers.append(("light_window_%d" % (i + 1), (sx * (CH_W + 0.3), y, (WIN_SILL + WIN_SPRING) / 2)))
    if level >= 2:
        pivot = _turret(parts)
        children.append(_bell(pivot))
    if level >= 3:
        markers.append(("light_choir", (0.0, CC_Y1 + 0.5, (CHOIR_WIN_SILL + CHOIR_WIN_SPRING) / 2)))
    _done(parts, "ph_bld_chapel_l%d" % level, markers, children=children)


def chapel_l1():
    _chapel(1)


def chapel_l2():
    _chapel(2)


def chapel_l3():
    _chapel(3)


def _bramble(parts, x: float, y: float, r: float, seed: int) -> None:
    """A low bramble / elder thicket: a few leafy lumps (mat_foliage, sways) and dry canes."""
    for k in range(3):
        a = k * 2.1 + seed
        c = Vector((x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, r * 0.35))
        o = L.prim("ico", loc=c, radius=r * random.uniform(0.5, 0.7), subdivisions=1, scale=(1.2, 1.0, 0.75))
        L.jitter(o, r * 0.18, 3.5, seed + k)
        L.paint(o, L.mix(LEAF_DARK, LEAF, random.random()), var=0.3, ao=0.5, top=0.3, seed=seed + k, hue_shift=GRASS_DRY)
        L.set_mat(o, L.MAT_FOLIAGE)
        parts.append(o)
    for k in range(3):
        a = random.uniform(0, math.tau)
        p0 = Vector((x, y, 0.0))
        p1 = p0 + Vector((math.cos(a) * r, math.sin(a) * r, r * 1.1))
        parts.append(P._stick(p0, p1, 0.012, BRAMBLE, verts=4, seed=seed + 10 + k, ao=0.2))


def chapel_ruin():
    """Level 0: the roofless chapel on the cleared ridge - lime-washed walls with broken tops, a
    collapsed gable, empty door and windows, rubble and brambles inside, a fallen rafter."""
    L.reset(800)
    parts = []
    _chapel_body(parts, 0)
    # floor inside: trodden earth and grass with rubble
    fl = _grid_mound(-CH_W + CH_T, CH_W - CH_T, CH_Y0 + CH_T, CC_Y1 - CH_T, 6, 10, lambda x, y: 0.02, "floor")
    P._paint_fn(fl, lambda co, vi: L.mix(_sod_colour(co, 7.0), EARTH, 0.4 + 0.3 * noise.noise(co * 2.0)))
    L.set_mat(fl, L.MAT_GROUND)
    parts.append(fl)
    for i in range(14):
        x = random.uniform(-CH_W + 0.5, CH_W - 0.5)
        y = random.uniform(CH_Y0 + 0.5, CH_Y1 - 0.3)
        s = random.uniform(0.08, 0.16)
        parts.append(_stone((x, y, s * 0.5), (s, s * 0.8, s * 0.6), random.choice((STONE_OLD, PLASTER_DIRTY, STONE)),
                            rot=(random.uniform(-20, 20), random.uniform(-20, 20), random.uniform(0, 90)), seed=850 + i,
                            moss=0.6))
    # rubble heaps under the broken gable (outside, both sides of the door) and inside
    for i, (x, y) in enumerate(((1.3, CH_Y0 - 0.12), (-1.55, CH_Y0 - 0.1), (1.2, CH_Y0 + 0.9), (-1.2, 0.9))):
        for k in range(4):
            s = random.uniform(0.09, 0.16)
            parts.append(_stone((x + random.uniform(-0.3, 0.3), y + random.uniform(-0.15, 0.15), s * 0.45 + k * 0.03),
                                (s, s * 0.75, s * 0.55), random.choice((STONE_OLD, PLASTER, STONE_DARK)),
                                rot=(random.uniform(-25, 25), random.uniform(-25, 25), random.uniform(0, 90)),
                                seed=870 + i * 5 + k, moss=0.4))
    # a fallen rafter across the nave, one still leaning on the north wall
    parts.append(P._plank((0.3, -0.6, 0.18), (1.7, 0.08, 0.08), WOOD_OLD, seed=890, rot=(0, 8, 28), cuts=2))
    parts.append(P._plank((-0.9, 1.25, 1.2), (0.07, 0.07, 1.3), WOOD_OLD, seed=891, rot=(-32, 0, 5), cuts=1))
    for i, (x, y, r) in enumerate(((-1.5, -2.4, 0.55), (1.5, -1.0, 0.5), (-0.3, 1.2, 0.6), (1.7, CH_Y0 - 0.08, 0.3),
                                   (-1.95, CH_Y0 - 0.06, 0.28), (0.6, CC_Y1 - 0.9, 0.45))):
        _bramble(parts, x, y, r, 900 + i * 13)
    _done(parts, "ph_bld_chapel_ruin", [("build", (2.95, -2.4, 0.0))])


# ==================================================================================================
# Totenleuchter (soul lantern) – level 3 of the chapel, in front of the door
# ==================================================================================================

def soul_lantern():
    """A slender stone column on a stepped base with a small open lantern house and a stone cap;
    the light sits inside (marker light_soul)."""
    L.reset(960)
    parts = []
    parts.append(_stone((0, 0, 0.08), (0.34, 0.34, 0.08), STONE_OLD, seed=1, moss=0.8, jit=0.01))
    parts.append(_stone((0, 0, 0.22), (0.24, 0.24, 0.07), STONE, seed=2, moss=0.5, jit=0.008))
    shaft = L.prim("cyl", loc=(0, 0, 1.05), radius=0.12, depth=1.6, vertices=8)
    L.taper(shaft, 0.25, 1.85, 0.8)
    L.subdivide(shaft, 1)
    L.jitter(shaft, 0.006, 3.0, 3)
    L.paint(shaft, STONE_PALE, var=0.16, ao=0.35, top=0.1, zrange=(0.0, 2.4), seed=3, hue_shift=STONE_OLD)
    P._tint_up(shaft, MOSS, 0.4, 0.0, seed=3)
    L.set_mat(shaft, L.MAT_PAINTED)
    parts.append(shaft)
    parts.append(_stone((0, 0, 1.9), (0.2, 0.2, 0.05), STONE_PALE, seed=4, jit=0.005, top=0.3))
    # lantern house: four little piers, a glowing core, a pyramid cap and a small cross
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_box((sx * 0.13, sy * 0.13, 2.13), (0.035, 0.035, 0.18), STONE_PALE, seed=5, var=0.12, ao=0.1))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(0, 0, 2.1), scale=(0.07, 0.07, 0.1)))
    parts.append(_box((0, 0, 2.34), (0.2, 0.2, 0.04), STONE_PALE, seed=6, var=0.12, ao=0.0, top=0.3))
    cap = L.prim("cone", loc=(0, 0, 2.52), vertices=4, radius1=0.24, radius2=0.02, depth=0.32, rot=(0, 0, 45))
    parts.append(_paint(cap, STONE_PALE, var=0.14, ao=0.0, top=0.25, hue_shift=MOSS))
    _cross(parts, Vector((0, 0, 2.66)), 0.22, color=IRON, seed=7)
    obj = L.join(parts, "ph_prop_soul_lantern")
    L.marker(obj, "light_soul", (0.0, 0.0, 2.1))
    L.finish(obj, "ph_prop_soul_lantern", "props", 35, shift=False)


# ==================================================================================================
# LAGERSCHUPPEN (shed) – footprint 3.2 x 3.6 m (x -1.6..1.6, y -1.8..1.8), door south,
# lean-to roof falling west (high side east <= 3.4 m)
# ==================================================================================================

SH_X0, SH_X1 = -1.2, 1.2        # board walls (outer faces)
SH_Y0, SH_Y1 = -1.25, 1.45
SH_RX0, SH_RX1 = -1.6, 1.6      # roof
SH_RY0, SH_RY1 = -1.8, 1.72
SH_LOW, SH_HIGH = 2.25, 3.2     # roof edge heights at the west / east eaves
SH_SILL = 0.22                  # boards start above the sill beam
SH_DOOR = (-0.32, 0.52, 1.95)   # x0, x1, top
SH_WIN = (-0.98, -0.52, 1.18, 1.58)
SH_WIN2 = (0.72, 1.06, 1.72, 2.08)   # level 3: the high shelf window east of the door


def _shed_roof_z(x: float) -> float:
    return SH_LOW + (x - SH_RX0) / (SH_RX1 - SH_RX0) * (SH_HIGH - SH_LOW)


def _board_wall(parts, axis: str, plane: float, out: float, a0: float, a1: float, top, holes, seed: int,
                width: float = 0.2, colour=WOOD):
    """Vertical boards between a0..a1 on a wall face; top(a) = board top; holes [(a0, a1, z0, z1)]."""
    n = max(2, round((a1 - a0) / width))
    step = (a1 - a0) / n
    for i in range(n):
        b0, b1 = a0 + i * step + 0.006, a0 + (i + 1) * step - 0.006
        spans = [(SH_SILL - 0.05, None)]
        for h in holes:
            if b1 > h[0] + 0.01 and b0 < h[1] - 0.01:
                spans = [(SH_SILL - 0.05, h[2]), (h[3], None)]
        col = L.scale_c(random.choice((colour, colour, WOOD_OLD, WOOD_DARK)), random.uniform(0.86, 1.1))
        for k, (z0, z1) in enumerate(spans):
            if z1 is None:
                pts = [(b0, z0), (b1, z0), (b1, top(b1) + random.uniform(-0.02, 0.01)), (b0, top(b0) + random.uniform(-0.02, 0.01))]
            else:
                if z1 - z0 < 0.03:
                    continue
                pts = [(b0, z0), (b1, z0), (b1, z1), (b0, z1)]
            lo, hi = (plane - out * 0.05, plane) if out > 0 else (plane, plane + 0.05)
            o = _prism(pts, axis, lo, hi, "board")
            L.jitter(o, 0.004, 3.0, seed + i * 3 + k)
            zt = max(p[1] for p in pts)
            off = Vector((seed * 1.3 + i, 0, 0))

            def fn(co, vi, col=col, off=off, zt=zt):
                h = max(0.0, min(1.0, (co.z - SH_SILL) / max(0.3, zt - SH_SILL)))
                c = L.scale_c(col, (1.0 + noise.noise(Vector((co.x * 8, co.y * 8, co.z * 1.1)) + off) * 0.12)
                              * (1.0 - 0.4 * (1.0 - h) ** 3) * (0.95 + 0.1 * h))
                m = max(0.0, noise.noise(co * 2.2 + off) + 0.2) * 0.5 * (1.0 - h) ** 4
                return L.mix(c, MOSS, min(0.7, m * 2.0))
            P._paint_fn(o, fn)
            L.set_mat(o, L.MAT_PAINTED)
            parts.append(o)


def _beam(p0, p1, hw: float, hh: float, color=WOOD_DARK, seed: int = 0):
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    c = (p0 + p1) / 2
    if abs(d.z) > max(abs(d.x), abs(d.y)):
        half = (hw, hw, d.length / 2)
    elif abs(d.x) >= abs(d.y):
        half = (d.length / 2, hw, hh)
    else:
        half = (hw, d.length / 2, hh)
    return _box(c, half, L.scale_c(color, random.uniform(0.9, 1.08)), jit=0.006, jfreq=2.5, seed=seed, var=0.16,
                ao=0.3, zrange=(0.0, SH_HIGH))


def _log_pile(parts, x0: float, x1: float, y0: float, y1: float, h: float, seed: int, rows: int = 4):
    """Split firewood stacked between two posts, end grain to the camera (south)."""
    r = h / rows / 2
    k = 0
    for row in range(rows):
        n = int((x1 - x0) / (2 * r))
        for i in range(n):
            x = x0 + r + i * 2 * r + (r if row % 2 else 0.0) * 0.5
            if x > x1 - r * 0.6:
                continue
            z = r + row * 2 * r * 0.92
            o = L.prim("cyl", loc=(x, (y0 + y1) / 2, z), rot=(90, 0, random.uniform(0, 60)),
                       radius=r * random.uniform(0.85, 1.0), depth=(y1 - y0) * random.uniform(0.9, 1.0), vertices=5)
            def fn(co, vi, x=x, z=z):
                end = abs(co.y - (y0 + y1) / 2) > (y1 - y0) * 0.44
                return L.scale_c(END_GRAIN if end else P.BARK, random.uniform(0.8, 1.05))
            P._paint_fn(o, fn)
            L.set_mat(o, L.MAT_PAINTED)
            parts.append(o)
            k += 1
    for sx in (x0 - 0.04, x1 + 0.04):
        parts.append(_beam((sx, (y0 + y1) / 2, 0.0), (sx, (y0 + y1) / 2, h + 0.1), 0.035, 0.035, seed=seed + 5))


def _mini_cart(parts, base: Vector, seed: int = 0):
    """The handcart parked at the door (the build of ph_prop_handcart, smaller and lighter): plank bed
    with low sides on two spoked wheels, handles pointing east and resting on the ground."""
    bz, hl, hw = 0.42, 0.42, 0.19        # bed height, half length (x), half width (y)
    tilt = math.radians(8.0)             # the handles rest on the ground: the bed tips a little
    local = []
    for i in range(3):
        local.append(_box((0.0, -hw + 0.075 + i * 0.145, bz), (hl, 0.068, 0.018), WOOD, seed=seed + i, jit=0.004,
                          var=0.15, ao=0.2))
    for sy in (-1, 1):
        local.append(_box((0.0, sy * (hw + 0.01), bz + 0.08), (hl, 0.016, 0.07), WOOD, seed=seed + 5 + sy, jit=0.004,
                          var=0.15, ao=0.2))
        local.append(P._stick((-hl, sy * 0.13, bz - 0.04), (hl + 0.22, sy * 0.13, bz - 0.04), 0.022, WOOD_DARK,
                              verts=4, seed=seed + 8))
    local.append(_box((-hl - 0.01, 0.0, bz + 0.08), (0.016, hw, 0.08), WOOD, seed=seed + 9, jit=0.004, var=0.15))
    wr = 0.3
    for sy in (-1, 1):
        w = L.prim("torus", loc=(-0.05, sy * (hw + 0.05), wr), rot=(90, 0, 0), major_radius=wr - 0.025,
                   minor_radius=0.025, major_segments=12, minor_segments=3)
        local.append(_paint(w, WOOD_DARK, var=0.15, ao=0.0, seed=seed + 10))
        local.append(L.part("cyl", IRON, loc=(-0.05, sy * (hw + 0.05), wr), rot=(90, 0, 0), radius=0.05, depth=0.08,
                            vertices=6))
        for k in range(3):
            a = k / 3 * math.pi
            d = Vector((math.cos(a), 0, math.sin(a))) * (wr - 0.035)
            c = Vector((-0.05, sy * (hw + 0.05), wr))
            local.append(P._stick(c - d, c + d, 0.011, WOOD, verts=4, seed=seed + 12 + k))
    local.append(P._stick((-0.05, -hw - 0.05, wr), (-0.05, hw + 0.05, wr), 0.018, IRON, verts=4))
    local.append(_box((-0.25, 0.05, bz + 0.05), (0.13, 0.1, 0.035), P.LINEN_DIRTY, rot=(0, 0, 14), seed=seed + 20,
                      jit=0.01, var=0.15))
    for o in local:   # pivot at the axle: the handle ends drop to the ground
        o.data.transform(Matrix.Translation(base + Vector((0.05, 0, 0))) @ Matrix.Translation((-0.05, 0, wr))
                         @ Matrix.Rotation(-tilt, 4, "Y") @ Matrix.Translation((0.05, 0, -wr)))
        parts.append(o)


def _shed_window(parts, x0, x1, z0, z1, seed: int):
    y = SH_Y0 - 0.03
    parts.append(_box(((x0 + x1) / 2, y + 0.04, (z0 + z1) / 2), ((x1 - x0) / 2, 0.01, (z1 - z0) / 2), GLASS,
                      var=0.25, ao=0.0, seed=seed))
    for sx in (x0 - 0.03, x1 + 0.03):
        parts.append(_box((sx, y, (z0 + z1) / 2), (0.035, 0.04, (z1 - z0) / 2 + 0.06), WOOD_DARK, seed=seed + 1, var=0.15, ao=0.1))
    for z in (z0 - 0.03, z1 + 0.03):
        parts.append(_box(((x0 + x1) / 2, y, z), ((x1 - x0) / 2 + 0.08, 0.04, 0.035), WOOD_DARK, seed=seed + 2, var=0.15, ao=0.1))
    parts.append(_box(((x0 + x1) / 2, y + 0.02, (z0 + z1) / 2), (0.014, 0.02, (z1 - z0) / 2), WOOD_DARK, var=0.1, ao=0.0))
    parts.append(_box(((x0 + x1) / 2, y + 0.02, (z0 + z1) / 2), ((x1 - x0) / 2, 0.02, 0.014), WOOD_DARK, var=0.1, ao=0.0))


def _shed_door(parts, seed: int = 60):
    x0, x1, zt = SH_DOOR
    y = SH_Y0 - 0.02
    n = 4
    for i in range(n):
        a = x0 + (i + 0.5) * (x1 - x0) / n
        parts.append(P._plank((a, y - 0.02, (SH_SILL + zt) / 2), ((x1 - x0) / n / 2 * 0.96, 0.025, (zt - SH_SILL) / 2),
                              L.scale_c(WOOD, random.uniform(0.75, 0.95)), seed=seed + i, cuts=1, ao=0.3))
    for z in (SH_SILL + 0.3, zt - 0.3):
        parts.append(P._plank(((x0 + x1) / 2, y - 0.06, z), ((x1 - x0) / 2 - 0.05, 0.016, 0.05), WOOD_DARK, seed=seed + 8))
        parts.append(_box((x0 + 0.22, y - 0.08, z), (0.22, 0.006, 0.02), IRON, var=0.3, hue_shift=RUST, ao=0.0))
    d = math.degrees(math.atan2(zt - SH_SILL - 0.6, x1 - x0 - 0.12))
    parts.append(P._plank(((x0 + x1) / 2, y - 0.06, (SH_SILL + zt) / 2), (math.hypot(zt - SH_SILL - 0.6, x1 - x0 - 0.12) / 2,
                                                                          0.014, 0.045), WOOD_DARK, seed=seed + 9, rot=(0, -d, 0)))
    parts.append(L.part("torus", IRON, loc=(x1 - 0.12, y - 0.08, 1.05), rot=(90, 0, 0), major_radius=0.045,
                        minor_radius=0.009, major_segments=6, minor_segments=3))
    for sx in (x0 - 0.05, x1 + 0.05):
        parts.append(_beam((sx, y, 0.12), (sx, y, zt + 0.06), 0.05, 0.05, seed=seed + 12))
    parts.append(_beam((x0 - 0.12, y, zt + 0.06), (x1 + 0.12, y, zt + 0.06), 0.05, 0.05, seed=seed + 14))
    parts.append(_stone(((x0 + x1) / 2, y - 0.22, 0.05), ((x1 - x0) / 2 + 0.1, 0.18, 0.05), STONE_DARK, seed=seed + 15,
                        moss=0.4))


def _shed(level: int) -> None:
    L.reset(1000 + level)
    parts = []
    top = lambda a: _shed_roof_z(a) - 0.14  # noqa: E731
    # stone pads and sill beams
    for sx in (SH_X0 + 0.08, SH_X1 - 0.08):
        for sy in (SH_Y0 + 0.08, SH_Y1 - 0.08):
            parts.append(_stone((sx, sy, 0.06), (0.16, 0.16, 0.08), STONE_OLD, seed=1000 + int(sx * 10 + sy), moss=0.7))
    for y in (SH_Y0 + 0.06, SH_Y1 - 0.06):
        parts.append(_beam((SH_X0 - 0.05, y, 0.17), (SH_X1 + 0.05, y, 0.17), 0.06, 0.06, seed=1010))
    for x in (SH_X0 + 0.06, SH_X1 - 0.06):
        parts.append(_beam((x, SH_Y0, 0.17), (x, SH_Y1, 0.17), 0.06, 0.06, seed=1011))
    # board walls
    holes_s = [(SH_DOOR[0] - 0.06, SH_DOOR[1] + 0.06, 0.0, SH_DOOR[2] + 0.1),
               (SH_WIN[0] - 0.06, SH_WIN[1] + 0.06, SH_WIN[2] - 0.06, SH_WIN[3] + 0.06)]
    if level >= 3:
        holes_s.append((SH_WIN2[0] - 0.06, SH_WIN2[1] + 0.06, SH_WIN2[2] - 0.06, SH_WIN2[3] + 0.06))
    _board_wall(parts, "y", SH_Y0, -1, SH_X0, SH_X1, top, holes_s, 1020)
    _board_wall(parts, "y", SH_Y1, 1, SH_X0, SH_X1, top, [], 1060)
    _board_wall(parts, "x", SH_X0, -1, SH_Y0, SH_Y1, lambda a: _shed_roof_z(SH_X0) - 0.14, [], 1100)
    _board_wall(parts, "x", SH_X1, 1, SH_Y0, SH_Y1, lambda a: _shed_roof_z(SH_X1) - 0.14, [], 1140)
    # corner posts, top plates, rafters under the roof
    for x in (SH_X0 + 0.02, SH_X1 - 0.02):
        for y in (SH_Y0 - 0.02, SH_Y1 + 0.02):
            parts.append(_beam((x, y, 0.1), (x, y, _shed_roof_z(x) - 0.1), 0.06, 0.06, seed=1180))
        parts.append(_beam((x, SH_Y0 - 0.2, _shed_roof_z(x) - 0.1), (x, SH_Y1 + 0.2, _shed_roof_z(x) - 0.1), 0.06, 0.07,
                           seed=1181))
    for i, y in enumerate((SH_RY0 + 0.1, -0.6, 0.35, SH_RY1 - 0.1)):   # rafter ends show at the eaves
        p0 = Vector((SH_RX1 - 0.04, y, _shed_roof_z(SH_RX1) - 0.1))
        p1 = Vector((SH_RX0 + 0.04, y, _shed_roof_z(SH_RX0) - 0.1))
        o = P._stick(p0, p1, 0.045, WOOD_DARK, verts=4, seed=1190 + i, ao=0.1)
        parts.append(o)
    # roof: weathered wooden shingles on a mono pitch (the chapel's slate routine, one side)
    roof = []
    _slate_roof(roof, SH_RX1 - SH_RX0, SH_LOW, SH_HIGH, SH_RY0, SH_RY1, 1200, sw=(0.22, 0.34), row=0.26, mossy=0.35,
                sides=(-1,), palette=(L.hexc("#5A4E48"), L.hexc("#463D38"), L.hexc("#6E625A")), deck_col=L.hexc("#3A322D"))
    for o in roof:
        o.data.transform(Matrix.Translation((SH_RX1, 0, 0)))
    parts += roof
    for y in (SH_RY0 - 0.02, SH_RY1 + 0.02):  # verge boards
        pitch = math.degrees(math.atan2(SH_HIGH - SH_LOW, SH_RX1 - SH_RX0))
        ln = math.hypot(SH_RX1 - SH_RX0, SH_HIGH - SH_LOW)
        parts.append(_box((0.0, y, (SH_LOW + SH_HIGH) / 2 + 0.03), (ln / 2, 0.025, 0.07), WOOD_DARK, rot=(0, -pitch, 0),
                          seed=1210, var=0.15, ao=0.0))
    # door, window, woodpile
    _shed_door(parts)
    _shed_window(parts, *SH_WIN, seed=1220)
    _log_pile(parts, SH_X0 + 0.06, SH_WIN[1] + 0.12, SH_Y0 - 0.42, SH_Y0 - 0.08, 0.92, 1230)
    parts.append(_box(((SH_X0 + SH_WIN[1]) / 2 + 0.1, SH_Y0 - 0.25, 0.02), ((SH_WIN[1] - SH_X0) / 2 + 0.12, 0.2, 0.02),
                      WOOD_OLD, seed=1240, var=0.2, ao=0.0))
    if level >= 2:
        _mini_cart(parts, Vector((0.98, SH_Y0 - 0.29, 0.0)), seed=1250)
    if level >= 3:
        _shed_window(parts, *SH_WIN2, seed=1270)
        # Steinlege: squared stones stacked on sleepers at the west side, under the eaves
        parts.append(_beam((SH_X0 - 0.22, SH_Y0 + 0.1, 0.05), (SH_X0 - 0.22, SH_Y1 - 0.3, 0.05), 0.05, 0.05, seed=1280))
        k = 0
        for row in range(3):
            y = SH_Y0 + 0.05 + (0.18 if row % 2 else 0.0)
            while y < SH_Y1 - 0.45 - row * 0.4:
                ln = random.uniform(0.34, 0.46)
                parts.append(_stone((SH_X0 - 0.2, y + ln / 2, 0.16 + row * 0.2), (0.15, ln / 2 * 0.94, 0.095),
                                    random.choice((STONE, STONE_OLD, STONE_WARM)), seed=1290 + k, jit=0.008, top=0.25))
                y += ln
                k += 1
    markers = [("door_outside", ((SH_DOOR[0] + SH_DOOR[1]) / 2, SH_RY0 - 0.35, 0.0)), ("build", (-1.05, -2.25, 0.0))]
    _done(parts, "ph_bld_shed_l%d" % level, markers)


def shed_l1():
    _shed(1)


def shed_l2():
    _shed(2)


def shed_l3():
    _shed(3)


def shed_site():
    """Level 0: pegs and string round the plot, a stack of squared beams on two sleepers, an old sill
    beam on stone pads where the shed will stand."""
    L.reset(1090)
    parts = []
    _pegs(parts, ((SH_RX0 + 0.1, SH_RY0 + 0.1), (SH_RX1 - 0.1, SH_RY0 + 0.1), (SH_RX1 - 0.1, SH_RY1 - 0.1),
                  (SH_RX0 + 0.1, SH_RY1 - 0.1)), seed=1091)
    for i, y in enumerate((-0.2, 0.9)):
        parts.append(_beam((-1.0, y, 0.05), (0.9, y, 0.05), 0.05, 0.05, color=WOOD_OLD, seed=1095 + i))
    for row in range(2):
        for i in range(3 - row):
            x = -0.55 + i * 0.22 + row * 0.11
            parts.append(_box((x, 0.35, 0.16 + row * 0.2), (0.1, 0.95, 0.1), WOOD_FRESH, jit=0.005, seed=1100 + row * 5 + i,
                              var=0.12, ao=0.2))
            parts.append(_box((x, 0.35 - 0.951, 0.16 + row * 0.2), (0.085, 0.003, 0.085), END_GRAIN, var=0.1, ao=0.0))
    for i, x in enumerate((0.8, 1.15)):
        parts.append(_stone((x, -1.05 + i * 1.2, 0.05), (0.13, 0.13, 0.06), STONE_OLD, seed=1110 + i, moss=0.8))
    parts.append(_beam((0.95, -1.2, 0.16), (0.95, 0.4, 0.16), 0.07, 0.06, color=WOOD_OLD, seed=1115))
    for i in range(4):
        parts.append(_stone((random.uniform(-1.2, 1.2), random.uniform(-1.4, -0.9), 0.03), (0.06, 0.05, 0.035),
                            STONE_OLD, seed=1120 + i))
    _done(parts, "ph_bld_shed_site", [("build", (-1.05, -2.25, 0.0))])


ASSETS = [crypt_site, crypt_l1, crypt_l2, crypt_l3, chapel_ruin, chapel_l1, chapel_l2, chapel_l3, soul_lantern, shed_site, shed_l1, shed_l2, shed_l3]


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
