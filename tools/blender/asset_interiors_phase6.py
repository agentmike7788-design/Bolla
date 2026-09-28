"""Phase-6 interiors (docs/PHASE6_DESIGN.md sections 4.7, 4.8 and 8), 'Gemaltes Diorama'.

Like the hut interior (asset_interior.py) every room is a diorama for the fixed 45 deg camera: the
wall towards the camera (south, Blender -Y = Godot +Z) is only a low stub, there is no ceiling, the
cut edges sit on a band of rough stones / earth.  Furniture are separate models (pivot bottom
centre, front -Y = Godot +Z, 1 unit = 1 m); data/world/interiors/<room>_layout.json (W-Welt) places
them.  Only the shared materials are used.

GRUFT (crypt, under the oak - cold, no windows)
  ph_int_crypt_room      vaulted room 8 x 6 m: flag floor, rubble socle, brick walls, the haunches of a
                         segmental barrel vault (cut open), the lunette of the north wall with the round
                         arched opening of the ossuary niche (3 x 1.6 m, raised one step), the south
                         stub with the opening of the stair shaft.  Markers door_inside (on the lowest
                         stair step), spawn_inside (foot of the stair)
  ph_int_crypt_stair     shaft 1.4 x 3 m, 8 steps rising south towards the camera, ending in daylight
                         (the door frame at the top).  Marker light_window_1 (the shaft light, role window)
  ph_int_crypt_table     stone slab on two masonry trestles; marker slot_corpse (+X = long axis)
  ph_int_crypt_niche     cold niche: brick arcosolium unit (2.0 x 0.85 m) with a slate bench; slot_corpse,
                         chill (three fit each 6 m side wall)
  ph_int_crypt_niche_sealed  the same unit, bricked up
  ph_int_crypt_lantern   hanging lantern on a chain; marker light_ceiling (role lantern)
  ph_int_candle_niche    small wall recess with candles; marker light_candle (role candle)
  ph_int_ossuary_shelf   the ossuary shelf: 6 box places (markers box_1..6 = bottom centre of a box)
                         and 6 places for old grave stones leaning at its foot (stone_1..6, local +Z =
                         the stone front, leaning back 6 deg)
  ph_int_bone_box        a reinterred box of bones on the shelf (lid, rope handles, a painted cross)
  ph_int_bone_rack       rack of long bones in calm, ordered bundles (no skulls)
  ph_int_name_board      board for the names (marker names = centre of the writing face, +Z = normal)
  ph_int_sealed_passage  a bricked-up door in a stone frame, cold air through the joints
  ph_int_sealed_passage_grille  one part of the bricking replaced by an iron grille; behind it steps go
                         down into the dark, a faint blue-grey shimmer (marker light_below)
KAPELLE (chapel)
  ph_int_chapel_room     nave 5 x 7.5 m + raised choir 3 x 2 m behind a round chancel arch, lime-washed
                         walls, flag floor, four side windows (light_window_1..4, inside the panes),
                         a plain choir window, rafter stubs.  door_inside, spawn_inside
  ph_int_altar           stone altar with linen cloth, two candlesticks, a plain cross, a book;
                         markers light_candle_1/_2; the flames are child meshes flame_1/_2 (shown only
                         during a rite and from level 3)
  ph_int_catafalque      bier with a dark pall; marker slot_corpse
  ph_int_pew_rough       rough bench (level 1)
  ph_int_pew             pew with back and kneeler; markers pew_seat_1..4 (floor under each seat, the
                         sitter faces the model front -Y / Godot +Z like the pew)
  ph_int_bell_rope       bell rope with a woollen sally, from 3.4 m down to a loop at 0.9 m
  ph_int_candelabrum     tall iron candle stand (the ever-burning light of level 3); marker light_candle
  ph_int_stained_window  coloured choir window panel (fits the choir window); marker light_stain
  ph_int_holy_water      small stone font on a short pillar (Weihwasserbecken, §4.8)
SCHUPPEN (shed)
  ph_int_shed_room       plank floor, board walls under the lean-to rafters, a west window
                         (light_window_1), a lantern post at the door (light_lantern, role lantern)
  ph_int_shed_rack       shelves with fixed painted stock (sacks, boards, bars, pots) and the ledger
  ph_int_wood_rack       firewood rack
  ph_int_stone_bin       wooden bin with stones and clay

Run:  python tools/blender/build_all.py asset_interiors_phase6
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_buildings_phase6 as B
from asset_interior import _candle, _flame, _lathe

CAT = "interior"

STONE = B.STONE
STONE_DARK = B.STONE_DARK
STONE_OLD = B.STONE_OLD
STONE_WARM = B.STONE_WARM
STONE_PALE = B.STONE_PALE
MORTAR = B.MORTAR
GAP = B.GAP
BRICK = L.hexc("#8A6F5C")          # section 8: brick family of the vault
BRICK_DARK = L.hexc("#6E5646")
BRICK_PALE = L.hexc("#9C8472")
SLATE = B.SLATE
SLATE_COOL = L.hexc("#5E656C")
FLAG = L.hexc("#6E7072")           # floor flags, cool
FLAG_WARM = L.hexc("#77716A")
PLASTER = B.PLASTER
PLASTER_DIRTY = B.PLASTER_DIRTY
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
WOOD_FRESH = P.WOOD_FRESH
WOOD_WARM = L.hexc("#7C5B3D")
FLOOR_BOARD = L.hexc("#6A4E36")
IRON = P.IRON
RUST = P.RUST
BRASS = L.hexc("#8E7F55")
WAX = L.hexc("#E6D8B8")
LINEN = P.LINEN
LINEN_DIRTY = P.LINEN_DIRTY
PALL = L.hexc("#2E2A2E")           # the black pall, a breath of violet
PALL_EDGE = L.hexc("#6A5A3A")
ACCENT_RED = L.hexc("#8C2F2B")     # palette accent, sparingly
BONE = L.hexc("#BDB39C")           # quiet, matt ivory-grey
BONE_DARK = L.hexc("#958B76")
EARTH = P.EARTH
EARTH_DARK = P.EARTH_DARK
ROPE = P.ROPE
SACK = L.hexc("#A08C68")
CLAY = L.hexc("#8A5A44")
MOSS = B.MOSS
DAYLIGHT = L.hexc("#C4CAD0")       # the bright door at the top of the stair (pale, not saturated)
SHIMMER = L.hexc("#6F7E8E")        # the cold glimmer below the grille: blue-grey, low saturation
VOID = L.hexc("#0E1012")


# --- generic helpers ------------------------------------------------------------------------------

def _done(parts, name: str, markers=(), smooth_angle: float = 40.0, shift: bool = False, children=(),
          centre: bool = False):
    obj = L.join(parts, name)
    for m_name, loc in markers:
        L.marker(obj, m_name, loc)
    for child in children:
        child.parent = obj
    if centre:
        P._center_xy(obj)
    L.finish(obj, name, CAT, smooth_angle, shift=shift)
    return obj


def _rot_marker(obj, name: str, rot_deg) -> None:
    e = next(c for c in obj.children if c.name == name)
    e.rotation_euler = tuple(math.radians(a) for a in rot_deg)


def _tiled(fn, u0: float, u1: float, v0: float, v1: float, tu: float, tv: float, colour, skip=None,
           gap: float = 0.012, relief: float = 0.012, stagger: bool = True, backing=MORTAR, name: str = "tiles",
           tilt: float = 0.0):
    """Bricks / stones / flags as separate quads on a parametric surface fn(u, v) -> Vector: each tile
    a little inset (the joint shows the backing), pushed out by a random relief along the surface
    normal and painted on its own (colour(u, v, rnd) -> sRGB).  skip(u, v) leaves a tile out."""
    bm = bmesh.new()
    cols = []

    def nrm(u, v):
        e = 1e-3
        n = (fn(u + e, v) - fn(u - e, v)).cross(fn(u, v + e) - fn(u, v - e))
        return n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
    rows = max(1, round((v1 - v0) / tv))
    dv = (v1 - v0) / rows
    for r in range(rows):
        va, vb = v0 + r * dv, v0 + (r + 1) * dv
        u = u0 - (random.uniform(0.3, 0.6) * tu if (stagger and r % 2) else 0.0)
        while u < u1 - 1e-4:
            w = tu * random.uniform(0.8, 1.2)
            ua, ub = max(u, u0), min(u + w, u1)
            u += w
            if ub - ua < tu * 0.25:
                continue
            uc, vc = (ua + ub) / 2, (va + vb) / 2
            if skip is not None and skip(uc, vc):
                continue
            g = gap / 2
            off = nrm(uc, vc) * random.uniform(0.0, relief)
            corners = [(ua + g, va + g), (ub - g, va + g), (ub - g, vb - g), (ua + g, vb - g)]
            t = random.uniform(-tilt, tilt)
            vs = [bm.verts.new(fn(a, b) + off * (1.0 + t * (k - 1.5))) for k, (a, b) in enumerate(corners)]
            bm.faces.new(vs)
            cols.append(colour(uc, vc, random.random()))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        c = cols[poly.index]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            cc = L.scale_c(c, 1.0 + noise.noise(co * 3.0) * 0.07)
            attr.data[li].color = (L._to_lin(cc[0]), L._to_lin(cc[1]), L._to_lin(cc[2]), 1.0)
    L.set_mat(o, L.MAT_PAINTED)
    out = [o]
    if backing is not None:   # the joints: one dark sheet behind (coarse grid, same skip)
        bk = bmesh.new()
        cell = 0.5 if skip is None else 0.22
        nu = max(1, round((u1 - u0) / cell))
        nv = max(1, round((v1 - v0) / cell))
        for i in range(nu):
            for j in range(nv):
                a0, a1 = u0 + (u1 - u0) * i / nu, u0 + (u1 - u0) * (i + 1) / nu
                b0, b1 = v0 + (v1 - v0) * j / nv, v0 + (v1 - v0) * (j + 1) / nv
                if skip is not None and skip((a0 + a1) / 2, (b0 + b1) / 2):
                    continue
                n = nrm((a0 + a1) / 2, (b0 + b1) / 2) * -0.004
                bk.faces.new([bk.verts.new(fn(a, b) + n) for a, b in ((a0, b0), (a1, b0), (a1, b1), (a0, b1))])
        me2 = bpy.data.meshes.new(name + "_bk")
        bk.to_mesh(me2)
        bk.free()
        o2 = bpy.data.objects.new(name + "_bk", me2)
        bpy.context.collection.objects.link(o2)
        L.paint(o2, backing, var=0.15, ao=0.0, top=0.0)
        L.set_mat(o2, L.MAT_PAINTED)
        out.append(o2)
    return out


def _plane_x(y0: float, z0: float, x: float, sgn: float):
    """Wall at x (normal sgn * X): u = y, v = z."""
    return lambda u, v: Vector((x, u, v)) if sgn > 0 else Vector((x, u, v))


def _brick_col(base=BRICK, dark=BRICK_DARK, pale=BRICK_PALE, soot: float = 0.0):
    def fn(u, v, r):
        c = base if r < 0.55 else (dark if r < 0.8 else pale)
        c = L.scale_c(c, 0.9 + 0.2 * random.random())
        return c
    return fn


def _stone_col(cols=(STONE, STONE_DARK, STONE_OLD, STONE_WARM), f=(0.8, 1.0)):
    def fn(u, v, r):
        return L.scale_c(cols[int(r * len(cols)) % len(cols)], random.uniform(*f))
    return fn


def _face(parts, axis: str, plane: float, out: float, a0, a1, z0, z1, tw, th, colour, skip=None, relief=0.012,
          backing=MORTAR, gap=0.012, top=None):
    """Tiled wall face (axis 'y' = wall across x at y = plane, 'x' = wall along y at x = plane).  The
    face points to `out`; top(a) clips the tiles (vault lunettes)."""
    if axis == "y":
        fn = (lambda u, v: Vector((u, plane, v))) if out < 0 else (lambda u, v: Vector((-u, plane, v)))
        uu0, uu1 = (a0, a1) if out < 0 else (-a1, -a0)
        mapa = (lambda u: u) if out < 0 else (lambda u: -u)
    else:
        fn = (lambda u, v: Vector((plane, -u, v))) if out < 0 else (lambda u, v: Vector((plane, u, v)))
        uu0, uu1 = (-a1, -a0) if out < 0 else (a0, a1)
        mapa = (lambda u: -u) if out < 0 else (lambda u: u)

    def sk(u, v):
        a = mapa(u)
        if top is not None and v > top(a) - th * 0.3:
            return True
        return skip(a, v) if skip is not None else False
    parts += _tiled(fn, uu0, uu1, z0, z1, tw, th, colour, skip=sk, relief=relief, backing=backing, gap=gap)


def _slab(loc, half, colour, rot=(0, 0, 0), jit: float = 0.006, cuts: int = 0, seed: int = 0, mat=L.MAT_PAINTED, **pk):
    return B._box(loc, half, colour, rot=rot, jit=jit, cuts=cuts, seed=seed, mat=mat, **pk)


def _cut_band(parts, x0, x1, y0, y1, seed: int, depth: float = 0.45, sides=("s", "e", "w")):
    """The diorama cut under the floor: rough dark stones and earth (like the hut's plinth)."""
    def course(a0, a1, along, plane, out, s):
        a = a0
        k = 0
        while a < a1 - 0.05:
            ln = min(random.uniform(0.3, 0.55), a1 - a)
            c = a + ln / 2
            d = random.uniform(0.05, 0.07)
            hh = depth / 2 * random.uniform(0.8, 1.0)
            if along == "x":
                loc, half = (c, plane + out * d, -depth / 2 + (depth / 2 - hh)), (ln / 2 * 0.95, d, hh)
            else:
                loc, half = (plane + out * d, c, -depth / 2 + (depth / 2 - hh)), (d, ln / 2 * 0.95, hh)
            o = L.prim("cube", loc=loc, scale=half, rot=(random.uniform(-3, 3), random.uniform(-3, 3), 0))
            L.jitter(o, 0.018, 4.0, s + k)
            col = random.choice((STONE, STONE_DARK, STONE_DARK, STONE_WARM))
            L.paint(o, L.scale_c(L.mix(col, L.hexc("#4A3E34"), 0.45), random.uniform(0.4, 0.55)), var=0.25, ao=0.55,
                    top=0.0, zrange=(-depth, 0.0), seed=s + k)
            L.set_mat(o, L.MAT_PAINTED)
            parts.append(o)
            a += ln
            k += 1
    if "s" in sides:
        course(x0 - 0.12, x1 + 0.12, "x", y0, -1, seed)
    if "w" in sides:
        course(y0, y1, "y", x0, -1, seed + 40)
    if "e" in sides:
        course(y0, y1, "y", x1, 1, seed + 80)


def _flags(parts, x0, x1, y0, y1, z: float, tw: float = 0.56, th: float = 0.46, cols=(FLAG, FLAG_WARM, SLATE_COOL),
           skip=None, worn=None):
    """Floor of stone flags (separate quads over a dark bed)."""
    def colour(u, v, r):
        c = L.scale_c(cols[int(r * len(cols)) % len(cols)], random.uniform(0.82, 1.05))
        if worn is not None:
            c = L.mix(c, L.hexc("#8C8A84"), worn(u, v) * 0.35)
        return c
    parts += _tiled(lambda u, v: Vector((u, v, z)), x0, x1, y0, y1, tw, th, colour, skip=skip, gap=0.02, relief=0.006,
                    backing=L.hexc("#1C1A18"))


# ==================================================================================================
# GRUFT (crypt)
# ==================================================================================================

CX, CY = 4.0, 3.0            # inner half extents: 8 x 6 m
SPRING = 1.9                 # the vault springs here
CROWN = 3.4                  # crown of the segmental vault (only the haunches are built)
VR = (CX ** 2 + (CROWN - SPRING) ** 2) / (2 * (CROWN - SPRING))   # vault radius
VZ = CROWN - VR              # vault centre height
HAUNCH_X = 2.95              # the vault is cut open inside |x| < HAUNCH_X
SOCLE = 0.85                 # rubble socle height, bricks above
OSS_W, OSS_D = 3.0, 1.6      # ossuary niche (north)
OSS_SPRING, OSS_STEP = 1.75, 0.15
STAIR_W, STAIR_L = 1.4, 3.0
STAIR_RISE = 2.6             # the stair climbs this high over its 3 m (8 steps)
STUB = 0.45


def _vault_z(x: float) -> float:
    return VZ + math.sqrt(max(0.0, VR * VR - x * x))


def crypt_room():
    """The vaulted crypt: see the module doc.  Front stub, no ceiling, vault haunches cut open."""
    L.reset(1400)
    parts = []
    # floor + the raised floor of the ossuary niche
    worn = lambda u, v: math.exp(-((u / 0.8) ** 2)) * max(0.0, 1.0 - abs(v + 0.5) / 3.0)  # noqa: E731
    _flags(parts, -CX, CX, -CY, CY, 0.0, worn=worn)
    _flags(parts, -OSS_W / 2, OSS_W / 2, CY + 0.25, CY + OSS_D, OSS_STEP)
    parts.append(_slab((0.0, CY + 0.12, OSS_STEP / 2), (OSS_W / 2, 0.14, OSS_STEP / 2), STONE_PALE, seed=3, var=0.15,
                       ao=0.2, top=0.3))
    # north wall: socle + brick lunette following the vault, the round-arched niche opening
    oss_top = OSS_SPRING + OSS_W / 2 * 0.5      # a segmental arch (rise = half the half-width)
    oss_r = ((OSS_W / 2) ** 2 + (oss_top - OSS_SPRING) ** 2) / (2 * (oss_top - OSS_SPRING))
    oss_cz = oss_top - oss_r

    def in_oss(a, z):
        if abs(a) > OSS_W / 2 + 0.02:
            return False
        return z < OSS_SPRING or (a * a + (z - oss_cz) ** 2) < (oss_r + 0.02) ** 2
    _face(parts, "y", CY, -1, -CX, CX, 0.0, SOCLE, 0.46, 0.28, _stone_col(), skip=in_oss, relief=0.02)
    _face(parts, "y", CY, -1, -CX, CX, SOCLE, CROWN, 0.3, 0.14, _brick_col(), skip=in_oss, top=_vault_z)
    # arch of the niche: voussoirs of pale stone
    n = 11
    ang0 = math.atan2(OSS_SPRING - oss_cz, OSS_W / 2)
    for k in range(n):
        a0 = ang0 + (math.pi - 2 * ang0) * k / n
        a1 = ang0 + (math.pi - 2 * ang0) * (k + 1) / n
        poly = [(oss_r * math.cos(a0), oss_cz + oss_r * math.sin(a0)), (oss_r * math.cos(a1), oss_cz + oss_r * math.sin(a1)),
                ((oss_r + 0.2) * math.cos(a1), oss_cz + (oss_r + 0.2) * math.sin(a1)),
                ((oss_r + 0.2) * math.cos(a0), oss_cz + (oss_r + 0.2) * math.sin(a0))]
        o = B._prism(poly, "y", CY - 0.05, CY + 0.12, "vous")
        L.jitter(o, 0.006, 5.0, 20 + k)
        parts.append(B._paint(o, L.scale_c(STONE_PALE, random.uniform(0.9, 1.05)), var=0.14, ao=0.0, top=0.2, seed=20 + k))
    for sx in (-1, 1):  # jambs of the niche opening
        parts.append(_slab((sx * (OSS_W / 2 + 0.1), CY + 0.03, OSS_SPRING / 2), (0.1, 0.09, OSS_SPRING / 2), STONE_PALE,
                           seed=40 + sx, var=0.14, ao=0.25))
    # the lunette's edge: a stone band along the vault line (the wall arch)
    for k in range(14):
        x0 = -CX + 2 * CX * k / 14
        x1 = -CX + 2 * CX * (k + 1) / 14
        if abs((x0 + x1) / 2) < HAUNCH_X - 0.1:
            z0, z1 = _vault_z(x0), _vault_z(x1)
            poly = [(x0, z0 - 0.02), (x1, z1 - 0.02), (x1, z1 + 0.14), (x0, z0 + 0.14)]
            o = B._prism(poly, "y", CY - 0.04, CY + 0.08, "band")
            parts.append(B._paint(o, STONE_OLD, var=0.18, ao=0.0, top=0.25, seed=50 + k))
    # side walls: socle + brick up to the springing line
    for sx in (-1, 1):
        _face(parts, "x", sx * CX, -sx, -CY, CY, 0.0, SOCLE, 0.46, 0.28, _stone_col(), relief=0.02)
        _face(parts, "x", sx * CX, -sx, -CY, CY, SOCLE, SPRING, 0.3, 0.14, _brick_col())
        # the haunch of the vault: brick courses along the arc from the springing to the cut
        a_s = math.atan2(SPRING - VZ, CX)
        a_c = math.atan2(_vault_z(HAUNCH_X) - VZ, HAUNCH_X)

        def vault(u, v, sx=sx, a_s=a_s, a_c=a_c):   # u = y along the room, v = 0..1 along the arc
            a = a_s + (a_c - a_s) * v
            return Vector((sx * VR * math.cos(a), u, VZ + VR * math.sin(a)))
        arc = VR * (a_c - a_s)
        parts += _tiled(vault if sx < 0 else (lambda u, v, f=vault: f(-u, v)), -CY, CY, 0.0, 1.0, 0.3,
                        0.14 / arc, _brick_col(soot=0.2), relief=0.01, backing=MORTAR)
        # the cut edge of the vault: a dark stone band (reads as the section of the vault shell)
        zc = _vault_z(HAUNCH_X)
        parts.append(_slab((sx * (HAUNCH_X - 0.02), 0.0, zc + 0.12), (0.08, CY + 0.02, 0.16), STONE_DARK, cuts=2,
                           jit=0.015, seed=60 + sx, var=0.25, ao=0.1, top=0.2))
        # impost blocks where the vault springs (the three niches of each side wall stand below)
        for k, y in enumerate((-CY + 0.12, -1.0, 1.0, CY - 0.12)):
            parts.append(_slab((sx * (CX - 0.1), y, SPRING + 0.04), (0.1, 0.12, 0.06), STONE_PALE, seed=75 + k + sx,
                               var=0.12, ao=0.0, top=0.3))
    # ossuary niche: side walls, back wall, a small cut barrel vault
    for sx in (-1, 1):
        _face(parts, "x", sx * OSS_W / 2, -sx, CY, CY + OSS_D, OSS_STEP, 2.3, 0.3, 0.14, _brick_col(dark=L.hexc("#5E4A3E")))
    _face(parts, "y", CY + OSS_D, -1, -OSS_W / 2, OSS_W / 2, OSS_STEP, 2.35, 0.34, 0.2, _stone_col(), relief=0.02)
    # south stub with the stair opening, and the corner piers
    def stair_gap(a, z):
        return abs(a) < STAIR_W / 2 + 0.05
    _face(parts, "y", -CY, -1, -CX, CX, 0.0, STUB, 0.46, 0.22, _stone_col(), skip=stair_gap, relief=0.02)
    for sx in (-1, 1):
        parts.append(_slab((sx * (CX / 2 + STAIR_W / 4 + 0.03), -CY - 0.08, STUB + 0.04),
                           (CX / 2 - STAIR_W / 4 + 0.05, 0.14, 0.05), STONE_OLD, seed=90 + sx, var=0.2, ao=0.0, top=0.3,
                           cuts=1))
        parts.append(_slab((sx * (STAIR_W / 2 + 0.12), -CY - 0.08, 0.5), (0.12, 0.14, 0.5), STONE_PALE, seed=92 + sx,
                           var=0.15, ao=0.3))
        parts.append(_slab((sx * (CX + 0.1), -CY - 0.06, (STUB + 0.6) / 2), (0.14, 0.14, (STUB + 0.6) / 2), STONE_DARK,
                           seed=94 + sx, var=0.2, ao=0.3))
    _cut_band(parts, -CX - 0.12, CX + 0.12, -CY - 0.15, CY + 0.1, 100)
    markers = [("door_inside", (0.0, -CY - 0.35, 0.0)), ("spawn_inside", (0.0, -CY + 0.75, 0.0))]
    _done(parts, "ph_int_crypt_room", markers, 30)


def crypt_stair():
    """The stair shaft south of the room: 8 steps rising towards the camera between rough walls,
    ending at the door in daylight.  Origin = where the shaft meets the room (the room's south face),
    the shaft runs to -Y."""
    L.reset(1410)
    parts = []
    n = 8
    run = STAIR_L / n
    rise = STAIR_RISE / n
    for k in range(n):
        y0 = -k * run
        z = (k + 1) * rise
        d = 1.0 - 0.06 * (n - k)
        parts.append(_slab((0.0, y0 - run / 2, z / 2), (STAIR_W / 2 - 0.02, run / 2 + 0.01, z / 2), L.scale_c(STONE_DARK, d),
                           jit=0.01, seed=k, var=0.2, ao=0.25, top=0.35))
        parts.append(_slab((0.0, y0 - 0.04, z - 0.015), (STAIR_W / 2 - 0.05, 0.05, 0.02),
                           L.scale_c(STONE_PALE, 0.8 + 0.03 * k), seed=20 + k, var=0.12, ao=0.0, top=0.35))   # worn nosing
    # side walls of the shaft: rough stone up above the steps, the top follows the stair
    for sx in (-1, 1):
        top = lambda a: STAIR_RISE * min(1.0, -a / STAIR_L) + 0.9  # noqa: E731
        _face(parts, "x", sx * (STAIR_W / 2), -sx, -STAIR_L - 0.05, 0.0, 0.0, STAIR_RISE + 0.95, 0.42, 0.26, _stone_col(),
              relief=0.02, top=top)
        core = B._prism([(-STAIR_L - 0.05, 0.0), (0.0, 0.0), (0.0, top(0.0)), (-STAIR_L - 0.05, top(-STAIR_L - 0.05))], "x",
                        sx * (STAIR_W / 2) + (0.0 if sx > 0 else -0.28), sx * (STAIR_W / 2) + (0.28 if sx > 0 else 0.0), "core")
        parts.append(B._paint(core, L.scale_c(STONE_DARK, 0.6), var=0.25, ao=0.3, hue_shift=MORTAR))
        for k in range(4):     # capping slabs along the sloped wall top
            a0 = -k * STAIR_L / 4
            a1 = -(k + 1) * STAIR_L / 4
            zc = (top(a0) + top(a1)) / 2
            tilt = math.degrees(math.atan2(STAIR_RISE, STAIR_L))
            parts.append(_slab((sx * (STAIR_W / 2 + 0.12), (a0 + a1) / 2, zc), (0.15, STAIR_L / 8 + 0.02, 0.05), STONE_OLD,
                               rot=(-tilt, 0, 0), seed=40 + k + sx * 5, var=0.2, ao=0.0, top=0.3))
    # the door at the top: stone frame, the doorway full of pale daylight
    zt = STAIR_RISE
    y = -STAIR_L - 0.05
    parts.append(_slab((0.0, y - 0.02, zt + 1.0), (STAIR_W / 2 - 0.02, 0.02, 1.0), DAYLIGHT, seed=60, var=0.08, ao=0.0,
                       top=0.0))
    for sx in (-1, 1):
        parts.append(_slab((sx * (STAIR_W / 2 + 0.05), y, zt + 1.0), (0.1, 0.1, 1.0), STONE_PALE, seed=61 + sx, var=0.15,
                           ao=0.1))
    parts.append(_slab((0.0, y, zt + 2.05), (STAIR_W / 2 + 0.2, 0.12, 0.1), STONE_PALE, seed=64, var=0.15, ao=0.0))
    # a little cold dust on the lowest steps, a forgotten broom
    parts.append(P._stick((0.52, -0.3, rise), (0.45, -0.1, rise + 1.05), 0.014, WOOD_OLD, verts=4))
    _cut_band(parts, -STAIR_W / 2 - 0.25, STAIR_W / 2 + 0.25, -STAIR_L - 0.2, 0.0, 70, sides=("e", "w"))
    obj = _done(parts, "ph_int_crypt_stair", [("light_window_1", (0.0, -STAIR_L + 0.6, zt + 1.4))], 30)
    del obj


def crypt_table():
    """Gruft-Tisch: a thick stone slab (2.1 x 0.85 m) on two masonry trestles, a groove round the
    edge and a drain notch at the foot, a folded linen at the head."""
    L.reset(1420)
    parts = []
    top = 0.84
    slab = L.prim("cube", loc=(0, 0, top - 0.06), scale=(1.05, 0.43, 0.06))
    L.bevel(slab, 0.015, 1)
    L.jitter(slab, 0.006, 3.0, 1)
    parts.append(B._paint(slab, L.mix(STONE, SLATE_COOL, 0.4), var=0.14, ao=0.2, top=0.2, seed=1, hue_shift=STONE_PALE))
    for sy in (-1, 1):   # the groove (a dark line) along the long edges
        parts.append(_slab((0.0, sy * 0.36, top + 0.001), (0.95, 0.012, 0.002), L.hexc("#3E4144"), jit=0.0, var=0.05, ao=0.0))
    for sx in (-1, 1):
        parts.append(_slab((sx * 0.95, 0.0, top + 0.001), (0.012, 0.36, 0.002), L.hexc("#3E4144"), jit=0.0, var=0.05, ao=0.0))
    parts.append(_slab((-1.06, 0.0, top - 0.05), (0.03, 0.05, 0.03), L.hexc("#2E3032"), jit=0.0, var=0.05, ao=0.0))
    for sx in (-1, 1):   # masonry trestles: a block with a chamfered foot
        x = sx * 0.66
        parts.append(_slab((x, 0.0, (top - 0.12) / 2 + 0.06), (0.14, 0.34, (top - 0.12) / 2), STONE_OLD, cuts=1, jit=0.012,
                           seed=5 + sx, var=0.22, ao=0.4))
        parts.append(_slab((x, 0.0, 0.05), (0.2, 0.4, 0.05), STONE_DARK, jit=0.01, seed=8 + sx, var=0.2, ao=0.2))
    cloth = L.prim("cube", loc=(0.82, 0.24, top + 0.025), scale=(0.16, 0.12, 0.025), rot=(0, 0, 8))
    L.bevel(cloth, 0.012, 1)
    parts.append(B._paint(cloth, LINEN_DIRTY, var=0.1, ao=0.1, top=0.2))
    parts.append(L.part("cyl", L.hexc("#6C6A66"), loc=(-0.95, -0.52, 0.12), radius=0.14, depth=0.24, vertices=10,
                        paint_kw={"ao": 0.4}))   # a tin bucket under the foot end
    obj = L.join(parts, "ph_int_crypt_table")
    P._slot(obj, (0.0, 0.0, top))
    L.finish(obj, "ph_int_crypt_table", CAT, 35, shift=False)


def _niche_frame(parts, sealed: bool, seed: int):
    """Brick arcosolium unit, 2.0 x 0.85 x 1.55 m, open to -Y; returns the slate top height."""
    W, D, H = 1.0, 0.85, 1.55
    spring, rise = 1.0, 0.34
    r = (W - 0.1) ** 2 / (2 * rise) + rise / 2
    cz = spring + rise - r
    iw = W - 0.1                        # inner half width of the opening (1.8 m: a 1.74 m body fits)

    def in_open(a, z):
        return abs(a) < iw and (z < spring or (a * a + (z - cz) ** 2) < r * r)
    y = -D / 2
    # front face: brick piers and spandrel over the arch
    _face(parts, "y", y, -1, -W, W, 0.0, H, 0.28, 0.13, _brick_col(), skip=None if sealed else in_open, relief=0.01)
    for k in range(9):   # the arch: pale stone voussoirs
        a0 = math.atan2(spring - cz, iw) + (math.pi - 2 * math.atan2(spring - cz, iw)) * k / 9
        a1 = math.atan2(spring - cz, iw) + (math.pi - 2 * math.atan2(spring - cz, iw)) * (k + 1) / 9
        poly = [(r * math.cos(a0), cz + r * math.sin(a0)), (r * math.cos(a1), cz + r * math.sin(a1)),
                ((r + 0.13) * math.cos(a1), cz + (r + 0.13) * math.sin(a1)), ((r + 0.13) * math.cos(a0), cz + (r + 0.13) * math.sin(a0))]
        o = B._prism(poly, "y", y - 0.03, y + 0.05, "vous")
        parts.append(B._paint(o, L.scale_c(STONE_PALE, random.uniform(0.9, 1.05)), var=0.14, ao=0.0, top=0.2, seed=seed + k))
    parts.append(_slab((0.0, y - 0.01, H + 0.04), (W + 0.04, 0.08, 0.05), STONE_OLD, seed=seed + 20, var=0.2, ao=0.0, top=0.3))
    if sealed:
        # the infill is bricked flush a little behind the arch; a cross scratched into the plaster
        parts.append(_slab((0.0, y - 0.005, 0.62), (0.012, 0.004, 0.16), L.hexc("#3A2E26"), jit=0.0, var=0.0, ao=0.0))
        parts.append(_slab((0.0, y - 0.005, 0.68), (0.08, 0.004, 0.012), L.hexc("#3A2E26"), jit=0.0, var=0.0, ao=0.0))
        return None
    # inside: back wall, cheeks, the arched ceiling, the slate bench on a brick base
    _face(parts, "y", D / 2, -1, -iw, iw, 0.0, spring + rise, 0.3, 0.14, _brick_col(dark=L.hexc("#5A463A")),
          top=lambda a: cz + math.sqrt(max(0.0, r * r - a * a)), relief=0.008)
    for sx in (-1, 1):
        _face(parts, "x", sx * iw, -sx, y, D / 2, 0.0, spring, 0.28, 0.14, _brick_col(dark=L.hexc("#5A463A")), relief=0.008)
    a_s = math.atan2(spring - cz, iw)

    def ceil(u, v):
        a = a_s + (math.pi - 2 * a_s) * v
        return Vector((r * math.cos(a), u, cz + r * math.sin(a)))
    parts += _tiled(lambda u, v: ceil(-u, v), -D / 2, D / 2, 0.0, 1.0, 0.28, 0.12, _brick_col(base=L.hexc("#7A6252")),
                    relief=0.006)
    bench = 0.5
    parts.append(_slab((0.0, 0.02, bench / 2), (iw, D / 2 - 0.02, bench / 2), BRICK_DARK, cuts=1, jit=0.01, seed=seed + 30,
                       var=0.25, ao=0.4))
    sl = L.prim("cube", loc=(0.0, -0.02, bench + 0.03), scale=(iw + 0.02, D / 2 - 0.02, 0.03))
    L.subdivide(sl, 1)
    L.jitter(sl, 0.005, 3.0, seed + 31)
    parts.append(B._paint(sl, SLATE_COOL, var=0.18, ao=0.1, top=0.3, seed=seed + 31, hue_shift=L.hexc("#6C737A")))
    return bench + 0.06


def crypt_niche():
    """Kühlnische: an open arcosolium with a cold slate bench (body along X)."""
    L.reset(1430)
    parts = []
    top = _niche_frame(parts, False, 1430)
    obj = L.join(parts, "ph_int_crypt_niche")
    P._slot(obj, (0.0, 0.0, top))
    L.marker(obj, "chill", (0.0, 0.05, top + 0.35))
    L.finish(obj, "ph_int_crypt_niche", CAT, 30, shift=False)


def crypt_niche_sealed():
    """The same niche, still bricked up (levels below its min_level)."""
    L.reset(1440)
    parts = []
    _niche_frame(parts, True, 1440)
    _done(parts, "ph_int_crypt_niche_sealed", [], 30)


def crypt_lantern():
    """Hanging iron lantern on a chain (0.9 m) from a ceiling hook; warm glass."""
    L.reset(1450)
    parts = []
    z_top = 1.0
    parts.append(L.part("torus", IRON, loc=(0, 0, z_top), rot=(90, 0, 0), major_radius=0.03, minor_radius=0.007,
                        major_segments=6, minor_segments=3))
    for k in range(5):
        parts.append(L.part("torus", IRON, loc=(0, 0, z_top - 0.07 - k * 0.075), rot=(90, 0, 90 * (k % 2)),
                            major_radius=0.02, minor_radius=0.005, major_segments=6, minor_segments=3))
    zc = 0.28
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(0, 0, zc), scale=(0.07, 0.07, 0.1)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(sx * 0.075, sy * 0.075, zc), scale=(0.01, 0.01, 0.12)))
    parts.append(L.part("cube", IRON, loc=(0, 0, zc - 0.12), scale=(0.09, 0.09, 0.015)))
    parts.append(L.part("cone", IRON, loc=(0, 0, zc + 0.17), vertices=4, radius1=0.12, radius2=0.025, depth=0.12,
                        rot=(0, 0, 45)))
    parts.append(L.part("cone", IRON, loc=(0, 0, zc - 0.17), vertices=4, radius1=0.02, radius2=0.07, depth=0.08,
                        rot=(0, 0, 45)))
    parts.append(L.part("torus", IRON, loc=(0, 0, zc + 0.25), rot=(90, 0, 0), major_radius=0.025, minor_radius=0.006,
                        major_segments=6, minor_segments=3))
    _done(parts, "ph_int_crypt_lantern", [("light_ceiling", (0.0, 0.0, zc - 0.25))], 40, shift=True)   # below the glass


def candle_niche():
    """A small arched recess set into the wall (0.5 x 0.6 m, 0.22 deep) with three candles."""
    L.reset(1460)
    parts = []
    w, h, d = 0.24, 0.5, 0.22
    back = B._prism(B._arch_poly(0.0, 2 * w, 0.0, h - w, 6), "y", d / 2 - 0.02, d / 2, "back")
    parts.append(B._paint(back, L.scale_c(BRICK_DARK, 0.6), var=0.2, ao=0.0))
    for sx in (-1, 1):
        parts.append(_slab((sx * (w + 0.08), -d / 2 + 0.06, h / 2), (0.08, 0.07, h / 2 + 0.05), STONE_PALE, seed=sx,
                           var=0.14, ao=0.2))
    B._voussoirs(parts, 0.0, -d / 2 + 0.13, -1, h - w, w, 5, 0.14, 0.1, seed=10)
    parts.append(_slab((0.0, 0.0, 0.02), (w + 0.12, d / 2 + 0.02, 0.025), STONE_OLD, seed=20, var=0.15, ao=0.0, top=0.3))
    for i, (x, y, hh) in enumerate(((0.0, 0.03, 0.2), (-0.1, -0.02, 0.13), (0.1, 0.0, 0.1))):
        fl = _candle(parts, x, y, 0.045, hh, 0.02, seed=i, drips=1)
        _flame(parts, fl, 0.04, 0.011)
    parts.append(L.part("cyl", WAX, loc=(0.0, 0.0, 0.05), radius=0.16, depth=0.012, vertices=8, jit=0.004, seed=5))
    _done(parts, "ph_int_candle_niche", [("light_candle", (0.0, -0.05, 0.3))], 40)


# --- ossuary ------------------------------------------------------------------------------------

OSS_BOX = [(-0.72, 0.9), (0.0, 0.9), (0.72, 0.9), (-0.72, 1.42), (0.0, 1.42), (0.72, 1.42)]
OSS_STONE = [(-0.8, -0.34), (0.0, -0.34), (0.8, -0.34), (-0.4, -0.62), (0.4, -0.62), (1.05, -0.6)]


def ossuary_shelf():
    """Beinhaus: a dark oak shelf (2.4 x 0.5 m) on a stone footing - two boards with three places each
    for the bone boxes; at its foot room for six old grave stones leaning in two rows."""
    L.reset(1470)
    parts = []
    W, D = 1.2, 0.25
    parts.append(_slab((0.0, 0.0, 0.2), (W + 0.05, D + 0.05, 0.2), STONE_OLD, cuts=1, jit=0.012, seed=1, var=0.22, ao=0.45))
    parts.append(_slab((0.0, 0.0, 0.42), (W + 0.1, D + 0.08, 0.03), STONE_PALE, seed=2, var=0.15, ao=0.0, top=0.3))
    for sx in (-1, -0.34, 0.34, 1):   # posts
        parts.append(P._plank((sx * (W - 0.03), -D + 0.04, 1.2), (0.045, 0.045, 0.78), WOOD_DARK, seed=3 + int(sx * 3), ao=0.3))
        parts.append(P._plank((sx * (W - 0.03), D - 0.04, 1.2), (0.045, 0.045, 0.78), WOOD_DARK, seed=5 + int(sx * 3), ao=0.3))
    for z in (0.86, 1.38, 1.96):     # boards
        parts.append(P._plank((0.0, 0.0, z), (W + 0.04, D, 0.025), WOOD, seed=int(z * 10), cuts=1, ao=0.2))
    for k in range(4):               # back boards
        parts.append(P._plank((-W + (k + 0.5) * W / 2, D - 0.01, 1.2), (W / 4 - 0.01, 0.012, 0.76), L.scale_c(WOOD_DARK, 0.8),
                              seed=20 + k, ao=0.2))
    # a crown board with a small carved cross, a linen runner and a candle stub on the top
    parts.append(P._plank((0.0, -D + 0.02, 2.06), (W + 0.06, 0.03, 0.08), WOOD_DARK, seed=30))
    parts.append(_slab((0.0, -D - 0.015, 2.06), (0.012, 0.005, 0.055), L.hexc("#2A2018"), jit=0.0, var=0.0, ao=0.0))
    parts.append(_slab((0.0, -D - 0.015, 2.075), (0.035, 0.005, 0.01), L.hexc("#2A2018"), jit=0.0, var=0.0, ao=0.0))
    parts.append(_slab((0.0, 0.0, 0.46), (0.5, 0.18, 0.006), LINEN, jit=0.002, var=0.08, ao=0.0))
    fl = _candle(parts, 0.9, -0.1, 0.45, 0.1, 0.025, seed=40, drips=2)
    del fl
    for i, (x, y) in enumerate(((-1.0, 0.05), (1.02, 0.12))):   # dried flowers in a crock
        parts.append(L.part("cyl", L.hexc("#7A6A58"), loc=(x, y, 0.53), radius=0.05, depth=0.12, vertices=7))
        for k in range(4):
            a = k * 1.6 + i
            parts.append(P._stick((x, y, 0.58), (x + math.cos(a) * 0.08, y + math.sin(a) * 0.06, 0.78), 0.005,
                                  L.hexc("#8A7A58"), verts=3))
            parts.append(L.part("ico", L.hexc("#A08878"), loc=(x + math.cos(a) * 0.08, y + math.sin(a) * 0.06, 0.79),
                                radius=0.02, subdivisions=1))
    markers = [("box_%d" % (i + 1), (x, 0.0, z)) for i, (x, z) in enumerate(OSS_BOX)]
    markers += [("stone_%d" % (i + 1), (x, y, 0.0)) for i, (x, y) in enumerate(OSS_STONE)]
    obj = L.join(parts, "ph_int_ossuary_shelf")
    for m_name, loc in markers:
        L.marker(obj, m_name, loc)
    for i in range(6):      # the stones lean back 6 deg against the footing (+Z Godot = front)
        _rot_marker(obj, "stone_%d" % (i + 1), (-6.0, 0.0, 0.0))
    L.finish(obj, "ph_int_ossuary_shelf", CAT, 35, shift=False)


def bone_box():
    """A plain box of bones for the shelf (0.5 x 0.3 x 0.28 m): planks, a lid, rope handles and a
    small painted cross - nothing inside is visible."""
    L.reset(1480)
    parts = []
    hx, hy, h = 0.25, 0.15, 0.24
    for sy in (-1, 1):
        parts.append(P._plank((0.0, sy * (hy - 0.01), h / 2), (hx, 0.012, h / 2), WOOD_WARM, seed=1 + sy, ao=0.25))
    for sx in (-1, 1):
        parts.append(P._plank((sx * (hx - 0.012), 0.0, h / 2), (0.012, hy - 0.02, h / 2), WOOD, seed=3 + sx, ao=0.25))
        rope = P._path_tube([(sx * hx, -0.05, h * 0.6), (sx * (hx + 0.04), 0.0, h * 0.5), (sx * hx, 0.05, h * 0.6)], 0.008, 4)
        parts.append(P._finish_obj(rope, ROPE, ao=0.0, var=0.1))
    parts.append(P._plank((0.0, 0.0, 0.01), (hx, hy - 0.01, 0.01), WOOD_DARK, seed=6))
    lid = L.prim("cube", loc=(0.0, 0.0, h + 0.018), scale=(hx + 0.02, hy + 0.02, 0.018))
    L.bevel(lid, 0.008, 1)
    parts.append(B._paint(lid, L.scale_c(WOOD, 0.95), var=0.15, ao=0.0, top=0.25))
    parts.append(_slab((0.0, -hy - 0.001, h * 0.55), (0.01, 0.002, 0.06), L.hexc("#E0D6BE"), jit=0.0, var=0.0, ao=0.0))
    parts.append(_slab((0.0, -hy - 0.001, h * 0.6), (0.04, 0.002, 0.01), L.hexc("#E0D6BE"), jit=0.0, var=0.0, ao=0.0))
    _done(parts, "ph_int_bone_box", [], 35, shift=True, centre=True)


def _long_bone(p0: Vector, p1: Vector, r: float):
    """A calm long-bone form: a slim shaft with swollen, rounded ends (no joint detail); 32 triangles."""
    d = p1 - p0
    from asset_carter import sweep
    return sweep([p0, p0 + d * 0.1, p1 - d * 0.1, p1], [r * 1.2, r * 1.3, r * 1.25, r * 1.1], n=4, name="bone")


def bone_rack():
    """Gebeinregal: an old rack (1.4 x 0.45 x 1.7 m) with long bones laid in neat, even bundles on
    three boards - a quiet, ordered form, no skulls."""
    L.reset(1490)
    parts = []
    W, D = 0.7, 0.22
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(P._plank((sx * W, sy * D, 0.85), (0.04, 0.04, 0.85), WOOD_DARK, seed=1 + sx + sy, ao=0.3))
    boards = (0.1, 0.62, 1.14)
    for z in boards + (1.66,):
        parts.append(P._plank((0.0, 0.0, z), (W + 0.03, D + 0.02, 0.02), WOOD_OLD, seed=int(z * 10), cuts=1, ao=0.2))
    for i, z in enumerate(boards):
        k = 0
        for row, n in enumerate((4, 2)):
            for j in range(n):
                y = -D + 0.07 + (j + row) * 0.075 + row * 0.0
                zz = z + 0.045 + row * 0.055
                ln = random.uniform(0.4, 0.48)
                for side in (-1, 1):     # two bundles per board, laid lengthwise
                    xc = side * 0.34 + random.uniform(-0.02, 0.02)
                    o = _long_bone(Vector((xc - ln / 2, y, zz)), Vector((xc + ln / 2, y + random.uniform(-0.01, 0.01), zz)),
                                   0.022)
                    col = L.mix(BONE, BONE_DARK, random.uniform(0.0, 0.6))
                    parts.append(B._paint(o, col, var=0.1, ao=0.25, top=0.3, seed=i * 50 + k, zrange=(z, z + 0.3)))
                    k += 1
        for side in (-1, 1):   # a linen band tied round each bundle
            parts.append(_slab((side * 0.34, -D + 0.18, z + 0.08), (0.025, 0.17, 0.07), LINEN_DIRTY, jit=0.004, var=0.1, ao=0.1))
    _done(parts, "ph_int_bone_rack", [], 45, shift=True, centre=True)


def name_board():
    """Namenstafel: an oak board (1.0 x 0.62 m) with a moulded frame and a little roof; the names are
    Label3D lines at marker `names` (centre of the writing face, +Z = face normal)."""
    L.reset(1500)
    parts = []
    w, h = 0.5, 0.31
    parts.append(P._plank((0.0, 0.0, h + 0.05), (w, 0.02, h), L.mix(WOOD, WOOD_DARK, 0.3), seed=1, cuts=1, ao=0.0))
    for (x, z, sx, sz) in ((0, 0.05, w + 0.04, 0.03), (0, 2 * h + 0.05, w + 0.04, 0.03), (-w - 0.01, h + 0.05, 0.03, h + 0.03),
                           (w + 0.01, h + 0.05, 0.03, h + 0.03)):
        parts.append(P._plank((x, -0.02, z), (sx, 0.03, sz), WOOD_DARK, seed=int(x * 10 + z * 10) + 5, ao=0.0))
    for sx in (-1, 1):   # a small gable roof over the board
        parts.append(P._plank((sx * 0.27, 0.0, 2 * h + 0.16), (0.3, 0.07, 0.015), WOOD_DARK, seed=20 + sx, rot=(0, sx * 18, 0)))
    parts.append(_slab((0.0, -0.022, 2 * h - 0.02), (0.1, 0.004, 0.012), L.hexc("#2A2018"), jit=0.0, var=0.0, ao=0.0))
    _done(parts, "ph_int_name_board", [("names", (0.0, -0.021, h + 0.02))], 35, shift=True, centre=True)


def _passage_frame(parts, seed: int):
    """Stone door frame (1.1 x 2.0 m, 0.3 deep) in front of a wall; returns (inner half width, top)."""
    iw, ht = 0.42, 1.78
    for sx in (-1, 1):
        z = 0.0
        k = 0
        while z < ht - 0.05:
            h = min(0.36 if k % 2 == 0 else 0.28, ht - z)
            ww = 0.16 if k % 2 == 0 else 0.12
            parts.append(B._stone((sx * (iw + ww / 2), -0.08, z + h / 2), (ww / 2, 0.14, h / 2 * 0.96), STONE_PALE,
                                  seed=seed + k + sx * 10, jit=0.008, var=0.16, top=0.2))
            z += h
            k += 1
    parts.append(B._stone((0.0, -0.08, ht + 0.12), (iw + 0.2, 0.15, 0.12), STONE_PALE, seed=seed + 30, jit=0.008, top=0.25))
    parts.append(B._stone((0.0, -0.1, 0.03), (iw + 0.12, 0.16, 0.03), STONE_DARK, seed=seed + 31, jit=0.006, top=0.3))
    return iw, ht


def _bricking(parts, iw: float, ht: float, y: float, seed: int, hole=None):
    """The rough, younger bricking of the doorway; dark cold joints; `hole` (x0, x1, z0, z1) left open."""
    def skip(a, z):
        return hole is not None and hole[0] < a < hole[1] and hole[2] < z < hole[3]
    _face(parts, "y", y, -1, -iw, iw, 0.05, ht, 0.26, 0.12,
          _brick_col(base=L.hexc("#7E6A5C"), dark=L.hexc("#5E4E44"), pale=L.hexc("#948070")), skip=skip, relief=0.018,
          backing=L.hexc("#141516"))
    # smeared mortar and two chipped bricks on the floor
    for i in range(2):
        parts.append(B._stone((random.uniform(-0.3, 0.3), y - 0.25 - i * 0.12, 0.04), (0.1, 0.05, 0.035), BRICK,
                              rot=(0, 0, random.uniform(0, 60)), seed=seed + i))


def sealed_passage():
    """Die vermauerte Tür: a stone frame bricked up, younger than the vault; the joints stay dark."""
    L.reset(1510)
    parts = []
    iw, ht = _passage_frame(parts, 1510)
    _bricking(parts, iw, ht, 0.02, 1520)
    _done(parts, "ph_int_sealed_passage", [], 30)


def sealed_passage_grille():
    """Level 3: one field of the bricking replaced by an iron grille; behind it steps lead down out of
    the lantern light, the lowest ones catch a faint, still, blue-grey shimmer (marker light_below)."""
    L.reset(1530)
    parts = []
    iw, ht = _passage_frame(parts, 1530)
    hole = (-0.28, 0.28, 0.6, 1.5)
    _bricking(parts, iw, ht, 0.02, 1540, hole=hole)
    # the dark stair beyond the hole: a box of darkness with three step edges falling away
    x0, x1, z0, z1 = hole
    back = 0.55
    parts.append(_slab((0.0, 0.02 + back, (z0 + z1) / 2), ((x1 - x0) / 2 + 0.05, 0.01, (z1 - z0) / 2 + 0.05), VOID, jit=0.0,
                       var=0.05, ao=0.0, top=0.0))
    for sx in (-1, 1):
        parts.append(_slab((sx * ((x1 - x0) / 2 + 0.04), 0.02 + back / 2, (z0 + z1) / 2), (0.01, back / 2, (z1 - z0) / 2 + 0.05),
                           L.scale_c(STONE_DARK, 0.3), jit=0.0, var=0.1, ao=0.0))
    for k in range(4):
        t = k / 3
        yy = 0.08 + t * (back - 0.12)
        zz = z0 + 0.02 - t * 0.0 - 0.0
        col = L.mix(L.scale_c(STONE_DARK, 0.45), SHIMMER, t * 0.9)
        parts.append(_slab((0.0, yy, zz + 0.3 * (1 - t)), ((x1 - x0) / 2, 0.07, 0.012), col, jit=0.0, var=0.1, ao=0.0, top=0.4))
    parts.append(_slab((0.0, 0.02 + back - 0.03, z0 + 0.05), ((x1 - x0) / 2, 0.05, 0.05), SHIMMER, jit=0.0, var=0.2, ao=0.0))
    # the grille: square bars leaded into the bricks
    for k in range(5):
        x = x0 + (k + 0.5) * (x1 - x0) / 5
        parts.append(_slab((x, -0.01, (z0 + z1) / 2), (0.012, 0.012, (z1 - z0) / 2 + 0.03), IRON, jit=0.0, var=0.25,
                           hue_shift=RUST, ao=0.0, top=0.3))
    for z in (z0 + 0.25, z1 - 0.25):
        parts.append(_slab((0.0, -0.025, z), ((x1 - x0) / 2 + 0.03, 0.01, 0.014), IRON, jit=0.0, var=0.25, hue_shift=RUST,
                           ao=0.0, top=0.3))
    _done(parts, "ph_int_sealed_passage_grille", [("light_below", (0.0, 0.02 + back - 0.15, z0 - 0.05))], 30)


# ==================================================================================================
# KAPELLE (chapel) – nave 5 x 7.5 m (x -2.5..2.5, y -3.75..3.75), choir 3 x 2 m (y 3.75..5.75)
# ==================================================================================================

NX, NY = 2.5, 3.75
CHX, CHY1 = 1.5, 5.75
N_WALL = 3.4
CH_STEP = 0.15
WIN_YS = (-1.7, 1.5)
WIN_SILL, WIN_SPRING, WIN_W = 1.5, 2.45, 0.6
ARCH_W, ARCH_SPRING = 2.5, 2.35
CHOIR_WIN = (0.64, 1.0, 1.9)         # width, sill (above the choir floor), spring
DOOR_W = 1.1


def _plaster_face(parts, axis: str, plane: float, out: float, a0, a1, z0, z1, holes=(), seed: int = 0, top=None,
                  arch: bool = True):
    """Lime-washed wall slab whose inner face lies at `plane` (facing `out`), 0.2 m thick outwards."""
    B._pwall(parts, axis, plane - out * 0.2, -out, a0, a1, z0, z1, holes, seed=seed, thick=0.2, top=top, stones=0.12,
             arch=arch)


def _inner_window(parts, axis: str, plane: float, out: float, c: float, w: float, sill: float, spring: float,
                  seed: int, stained: bool = False):
    """Inside view of a window: deep splayed reveal, pane (leaded), stone sill."""
    B._window(parts, axis, plane, out, c, w, sill, spring, seed, stained=stained, simple=False)


def chapel_room():
    """The chapel inside: see the module doc."""
    L.reset(1600)
    parts = []
    worn = lambda u, v: math.exp(-((u / 0.6) ** 2)) * 0.8  # noqa: E731
    _flags(parts, -NX, NX, -NY, NY, 0.0, tw=0.5, th=0.5, cols=(L.hexc("#8A857A"), L.hexc("#7C776C"), L.hexc("#908A7E")),
           worn=worn)
    _flags(parts, -CHX, CHX, NY + 0.3, CHY1, CH_STEP, tw=0.5, th=0.5, cols=(L.hexc("#8A857A"), L.hexc("#948E82")))
    parts.append(_slab((0.0, NY + 0.15, CH_STEP / 2), (ARCH_W / 2, 0.15, CH_STEP / 2), STONE_PALE, seed=1, var=0.12, ao=0.2,
                       top=0.3))
    # nave walls (inner faces) with the four windows, the chancel wall with its arch, the choir
    for sx in (-1, 1):
        holes = [(y, WIN_W, WIN_SILL, WIN_SPRING) for y in WIN_YS]
        _plaster_face(parts, "x", sx * NX, -sx, -NY, NY, 0.0, N_WALL, holes, seed=10 + sx)
        for i, y in enumerate(WIN_YS):
            _inner_window(parts, "x", sx * NX, -sx, y, WIN_W, WIN_SILL, WIN_SPRING, 1620 + i * 20 + sx * 7)
    ar = ARCH_W / 2
    _plaster_face(parts, "y", NY, -1, -NX, NX, 0.0, N_WALL + 0.9, [(0.0, ARCH_W, 0.0, ARCH_SPRING)], seed=30,
                  top=lambda a: N_WALL + 0.9 - 0.3 * (abs(a) / NX) ** 2)
    B._voussoirs(parts, 0.0, NY + 0.02, -1, ARCH_SPRING, ar, 13, 0.08, 0.2, seed=40)
    for sx in (-1, 1):
        parts.append(_slab((sx * (ar + 0.1), NY - 0.03, ARCH_SPRING / 2), (0.1, 0.06, ARCH_SPRING / 2), STONE_PALE, cuts=1,
                           seed=45 + sx, var=0.14, ao=0.3))
        parts.append(_slab((sx * (ar + 0.12), NY - 0.05, ARCH_SPRING + 0.04), (0.16, 0.08, 0.05), STONE_PALE, seed=47 + sx,
                           var=0.1, ao=0.0, top=0.3))
        _plaster_face(parts, "x", sx * CHX, -sx, NY + 0.2, CHY1, CH_STEP, 3.2, seed=50 + sx)
    cw, csill, cspring = CHOIR_WIN
    _plaster_face(parts, "y", CHY1, -1, -CHX, CHX, CH_STEP, 3.4, [(0.0, cw, CH_STEP + csill, CH_STEP + cspring)], seed=60)
    _inner_window(parts, "y", CHY1, -1, 0.0, cw, CH_STEP + csill, CH_STEP + cspring, 1680)
    # south stub (door opening in the middle) and a low wooden dado along the nave
    _plaster_face(parts, "y", -NY, 1, -NX, NX, 0.0, 0.45, [(0.0, DOOR_W, 0.0, 0.45)], seed=70, arch=False)
    for sx in (-1, 1):
        parts.append(_slab((sx * (DOOR_W / 2 + 0.1), -NY - 0.1, 0.55), (0.1, 0.12, 0.55), STONE_PALE, seed=72 + sx,
                           var=0.14, ao=0.3))
        parts.append(_slab((sx * (NX - 0.03), 0.0, 0.5), (0.03, NY - 0.05, 0.5), L.scale_c(WOOD_DARK, 0.9), cuts=1, seed=75 + sx,
                           var=0.18, ao=0.3))
        parts.append(_slab((sx * (NX - 0.06), 0.0, 1.02), (0.06, NY - 0.05, 0.03), WOOD_DARK, seed=77 + sx, var=0.15, ao=0.0,
                           top=0.3))
    # rafter stubs rising from the wall plates (the roof is cut away), wall plates
    for sx in (-1, 1):
        parts.append(_slab((sx * (NX - 0.1), 0.0, N_WALL + 0.06), (0.1, NY, 0.08), WOOD_DARK, cuts=1, seed=80 + sx,
                           var=0.15, ao=0.0))
        for k in range(6):
            y = -NY + 0.4 + k * (2 * NY - 0.8) / 5
            p0 = Vector((sx * (NX - 0.1), y, N_WALL + 0.1))
            p1 = p0 + Vector((-sx * math.cos(math.radians(50)), 0, math.sin(math.radians(50)))) * 0.7
            parts.append(P._stick(p0, p1, 0.05, WOOD_DARK, verts=4, seed=82 + k, ao=0.1))
    _cut_band(parts, -NX - 0.2, NX + 0.2, -NY - 0.2, NY, 90)
    markers = [("door_inside", (0.0, -NY + 0.3, 0.0)), ("spawn_inside", (0.0, -NY + 0.8, 0.0))]
    for i, (sx, y) in enumerate(((-1, WIN_YS[0]), (-1, WIN_YS[1]), (1, WIN_YS[0]), (1, WIN_YS[1]))):
        markers.append(("light_window_%d" % (i + 1), (sx * (NX - 0.45), y, (WIN_SILL + WIN_SPRING) / 2)))
    _done(parts, "ph_int_chapel_room", markers, 30)


def altar():
    """Stone altar (1.5 x 0.7 x 1.0 m) on a step: white linen cloth with a narrow red border hanging
    at the front, two brass candlesticks, a plain wooden cross, an open book."""
    L.reset(1700)
    parts = []
    parts.append(_slab((0.0, 0.05, 0.08), (0.95, 0.55, 0.08), STONE_PALE, cuts=1, seed=1, var=0.14, ao=0.2, top=0.3))
    parts.append(_slab((0.0, 0.1, 0.58), (0.72, 0.33, 0.42), STONE_OLD, cuts=1, jit=0.008, seed=2, var=0.18, ao=0.35))
    parts.append(_slab((0.0, 0.1, 1.02), (0.78, 0.38, 0.035), STONE_PALE, seed=3, var=0.12, ao=0.0, top=0.25))
    top = 1.056

    def cloth(u, v):     # the cloth over the top and hanging at the front (u across, v from back to front+down)
        x = (u - 0.5) * 1.5
        if v < 0.6:
            y = 0.44 - v / 0.6 * 0.72
            return Vector((x, y, top + 0.004))
        t = (v - 0.6) / 0.4
        return Vector((x, -0.29 - 0.02 * t, top - t * 0.42 + 0.01 * math.sin(u * 30.0) * t))
    from asset_interior import _slab as islab, _paint_poly
    c = islab(10, 8, cloth, 0.006, "cloth", normal_sign=1.0)
    _paint_poly(c, lambda poly, co: ACCENT_RED if (co.z < top - 0.3 and co.z > top - 0.36) else LINEN, var=0.06, ao=0.0, top=0.1)
    parts.append(c)
    flames = []
    for i, sx in enumerate((-1, 1)):
        x = sx * 0.52
        stick = _lathe([(0.07, 0.0), (0.07, 0.015), (0.025, 0.04), (0.018, 0.2), (0.04, 0.23), (0.045, 0.25), (0.0, 0.25)],
                       8, "stick")
        stick.data.transform(Matrix.Translation((x, 0.18, top)))
        parts.append(B._paint(stick, BRASS, var=0.2, ao=0.2, top=0.3, hue_shift=L.hexc("#6E5A3C")))
        fl = _candle(parts, x, 0.18, top + 0.25, 0.3, 0.022, seed=10 + i, drips=2)
        f = L.part("cone", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(fl.x, fl.y, fl.z + 0.025), radius1=0.013, depth=0.05, vertices=6)
        f.name = "flame_%d" % (i + 1)
        f.data.name = f.name
        flames.append((f, fl))
    # the cross: plain dark wood on a small stepped foot
    parts.append(_slab((0.0, 0.3, top + 0.03), (0.08, 0.06, 0.03), WOOD_DARK, seed=20, var=0.12, ao=0.0))
    parts.append(_slab((0.0, 0.3, top + 0.33), (0.018, 0.018, 0.3), WOOD_DARK, seed=21, var=0.12, ao=0.1))
    parts.append(_slab((0.0, 0.3, top + 0.48), (0.13, 0.018, 0.018), WOOD_DARK, seed=22, var=0.12, ao=0.1))
    # an open book on a small wooden rest
    parts.append(_slab((0.28, -0.08, top + 0.025), (0.15, 0.11, 0.02), WOOD, rot=(8, 0, -8), seed=25, var=0.12, ao=0.0))
    for sx in (-1, 1):
        parts.append(_slab((0.28 + sx * 0.075, -0.08, top + 0.055), (0.07, 0.1, 0.006), L.hexc("#DCCFAE"),
                           rot=(8, sx * -6, -8), seed=26, var=0.05, ao=0.0))
    obj = L.join(parts, "ph_int_altar")
    for f, fl in flames:
        f.data.transform(Matrix.Translation(-f.location))
        f.parent = obj
    L.marker(obj, "light_candle_1", (-0.52, 0.18, top + 0.72))
    L.marker(obj, "light_candle_2", (0.52, 0.18, top + 0.72))
    L.finish(obj, "ph_int_altar", CAT, 35, shift=False)


def catafalque():
    """Katafalk: a low bier (2.0 x 0.8 m, 0.62 m) on turned legs under a dark pall with a pale border."""
    L.reset(1710)
    parts = []
    top = 0.62
    parts.append(_slab((0.0, 0.0, top - 0.03), (1.0, 0.4, 0.03), WOOD_DARK, seed=1, var=0.12, ao=0.0))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = _lathe([(0.05, 0.0), (0.05, 0.05), (0.03, 0.1), (0.04, 0.3), (0.028, 0.5), (0.045, top - 0.05),
                          (0.0, top - 0.05)], 6, "leg")
            leg.data.transform(Matrix.Translation((sx * 0.88, sy * 0.3, 0.0)))
            parts.append(B._paint(leg, WOOD_DARK, var=0.15, ao=0.3))

    def pall(u, v):   # drapes over the long sides and falls to a hand above the floor
        x = (u - 0.5) * 2.1
        a = (v - 0.5) * math.pi
        side = math.sin(a)
        y = 0.43 * side if abs(side) < 0.999 else 0.43 * side
        z = top + 0.005 if abs(v - 0.5) < 0.38 else top + 0.005 - (abs(v - 0.5) - 0.38) / 0.12 * 0.38
        yy = (v - 0.5) / 0.38 * 0.42 if abs(v - 0.5) < 0.38 else math.copysign(0.43 + 0.01 * math.sin(u * 25.0), v - 0.5)
        del y
        return Vector((x, yy, z))
    from asset_interior import _slab as islab, _paint_poly
    p = islab(10, 8, pall, 0.008, "pall", normal_sign=1.0)
    _paint_poly(p, lambda poly, co: PALL_EDGE if co.z < top - 0.28 else PALL, var=0.08, ao=0.0, top=0.12)
    parts.append(p)
    obj = L.join(parts, "ph_int_catafalque")
    P._slot(obj, (0.0, 0.0, top + 0.01))
    L.finish(obj, "ph_int_catafalque", CAT, 40, shift=False)


def pew_rough():
    """A rough bench (level 1): a split plank on four splayed legs."""
    L.reset(1720)
    parts = [P._plank((0.0, 0.0, 0.44), (0.9, 0.15, 0.03), WOOD_OLD, seed=1, cuts=1, ao=0.1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(P._stick((sx * 0.72, sy * 0.06, 0.42), (sx * 0.8, sy * 0.13, 0.0), 0.028, WOOD_DARK, r1=0.024,
                                  verts=5, seed=3 + sx + sy, ao=0.4))
    parts.append(P._plank((0.0, 0.0, 0.2), (0.7, 0.02, 0.025), WOOD_DARK, seed=6))
    _done(parts, "ph_int_pew_rough", [], 35, shift=True, centre=True)


PEW_SEATS = (-0.72, -0.24, 0.24, 0.72)


def pew():
    """Kirchenbank (2.0 m): seat, sloped back with a book rail, carved ends, a kneeler in front."""
    L.reset(1730)
    parts = []
    hx = 1.0
    parts.append(P._plank((0.0, 0.05, 0.45), (hx - 0.04, 0.19, 0.025), WOOD, seed=1, cuts=1, ao=0.1))
    back = P._plank((0.0, 0.26, 0.72), (hx - 0.04, 0.02, 0.26), WOOD, seed=2, cuts=1, ao=0.25, rot=(-10, 0, 0))
    parts.append(back)
    parts.append(P._plank((0.0, 0.33, 0.96), (hx - 0.02, 0.07, 0.018), WOOD_DARK, seed=3))
    for sx in (-1, 1):       # pew ends with a rounded top
        end = B._prism([(-0.16, 0.0), (0.32, 0.0), (0.34, 0.95), (0.26, 1.02), (0.18, 0.98), (0.2, 0.52), (-0.14, 0.5)],
                       "x", sx * hx - 0.03, sx * hx + 0.03, "end")
        parts.append(B._paint(end, WOOD_DARK, var=0.15, ao=0.3))
    parts.append(P._plank((0.0, -0.3, 0.1), (hx - 0.04, 0.07, 0.03), WOOD_DARK, seed=5))      # kneeler
    parts.append(P._plank((0.0, 0.05, 0.08), (hx - 0.05, 0.02, 0.05), WOOD_DARK, seed=6))
    markers = [("pew_seat_%d" % (i + 1), (x, 0.05, 0.0)) for i, x in enumerate(PEW_SEATS)]
    _done(parts, "ph_int_pew", markers, 35)


def bell_rope():
    """Bell rope from the ceiling (3.4 m) with a striped woollen sally and a loop at 0.9 m."""
    L.reset(1740)
    parts = []
    pts = [(0.0, 0.0, 3.4), (0.0, 0.0, 2.2), (0.01, 0.0, 1.4)]
    parts.append(P._finish_obj(P._path_tube(pts, 0.012, 5), ROPE, ao=0.0, var=0.12))
    sally = L.prim("cyl", loc=(0.01, 0.0, 1.62), radius=0.03, depth=0.36, vertices=6)
    P._paint_fn(sally, lambda co, vi: L.hexc("#7A4A3A") if int(co.z * 18) % 2 else L.hexc("#A89A78"))
    L.set_mat(sally, L.MAT_PAINTED)
    parts.append(sally)
    loop = [(0.01, 0.0, 1.4), (0.06, 0.0, 1.12), (0.02, 0.0, 0.92), (-0.04, 0.0, 1.05), (0.01, 0.0, 1.4)]
    parts.append(P._finish_obj(P._path_tube(loop, 0.011, 4), ROPE, ao=0.0, var=0.12))
    parts.append(_slab((0.0, 0.0, 3.43), (0.12, 0.12, 0.03), WOOD_DARK, seed=3, var=0.15, ao=0.0))
    _done(parts, "ph_int_bell_rope", [], 40)


def candelabrum():
    """Tall iron candle stand (1.45 m): three-footed, a drip pan with three candles (the ever-burning
    light of level 3, flames included)."""
    L.reset(1750)
    parts = []
    for k in range(3):
        a = k / 3 * math.tau
        parts.append(P._stick((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.0), (0.0, 0.0, 0.22), 0.014, IRON, verts=4,
                              hue_shift=RUST, ao=0.1))
    parts.append(P._stick((0.0, 0.0, 0.2), (0.0, 0.0, 1.3), 0.018, IRON, r1=0.013, verts=6, hue_shift=RUST, ao=0.1))
    parts.append(L.part("torus", IRON, loc=(0, 0, 0.8), major_radius=0.03, minor_radius=0.012, major_segments=6,
                        minor_segments=3))
    parts.append(L.part("cyl", IRON, loc=(0, 0, 1.31), radius=0.2, depth=0.02, vertices=10))
    parts.append(L.part("torus", IRON, loc=(0, 0, 1.33), major_radius=0.2, minor_radius=0.01, major_segments=10,
                        minor_segments=3))
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        fl = _candle(parts, math.cos(a) * 0.12, math.sin(a) * 0.12, 1.32, 0.12 + 0.05 * k, 0.02, seed=k, drips=1)
        _flame(parts, fl, 0.04, 0.011)
    _done(parts, "ph_int_candelabrum", [("light_candle", (0.0, 0.0, 1.62))], 40)


def stained_window():
    """Coloured choir window panel (fits the choir window, 0.66 x 0.9 m + round head): warm reds, golds
    and greens in a plain geometric pattern - a rosette in the head, no figures.  Glass pieces are
    separate quads over the dark lead."""
    L.reset(1760)
    parts = []
    cw, csill, cspring = CHOIR_WIN
    w = cw + 0.02
    r = w / 2
    zs = cspring - csill

    def outside(u, v):
        return v > zs and (u * u + (v - zs) ** 2) > (r - 0.02) ** 2

    def colour(u, v, rnd):
        if v > zs:
            d = math.hypot(u, v - zs)
            a = math.atan2(v - zs, u)
            c = B.STAIN[1] if d < r * 0.38 else B.STAIN[(int(a / math.pi * 6) % 2) * 3]
        else:
            c = B.STAIN[(int((u + r) / (w / 3)) + int(v / 0.2) * 2) % len(B.STAIN)]
        return L.scale_c(c, 0.92 + 0.14 * rnd)
    parts += _tiled(lambda u, v: Vector((u, 0.0, v)), -r, r, 0.0, zs + r, 0.11, 0.12, colour, skip=outside, gap=0.016,
                    relief=0.0, stagger=False, backing=B.LEAD)
    frame = B._prism(B._arch_poly(0.0, w + 0.06, -0.03, zs, 10), "y", 0.004, 0.02, "frame")
    parts.append(B._paint(frame, B.LEAD, var=0.1, ao=0.0))
    _done(parts, "ph_int_stained_window", [("light_stain", (0.0, -0.6, zs / 2))], 30)


def holy_water():
    """Weihwasserbecken: a small stone basin on a short octagonal pillar by the door."""
    L.reset(1770)
    parts = []
    p = _lathe([(0.14, 0.0), (0.14, 0.06), (0.08, 0.1), (0.07, 0.72), (0.2, 0.8), (0.22, 0.92), (0.17, 0.93), (0.15, 0.86),
                (0.0, 0.86)], 8, "font")
    parts.append(B._paint(p, STONE_PALE, var=0.15, ao=0.35, top=0.2, hue_shift=STONE_OLD))
    parts.append(L.part("cyl", L.hexc("#3A4046"), loc=(0, 0, 0.88), radius=0.155, depth=0.01, vertices=8,
                        paint_kw={"ao": 0.0, "var": 0.05, "top": 0.4}))
    _done(parts, "ph_int_holy_water", [], 40)


# ==================================================================================================
# SCHUPPEN (shed) – 3.2 x 3.6 m (x -1.6..1.6, y -1.8..1.8)
# ==================================================================================================

SX, SY = 1.5, 1.7              # inner half extents
S_LOW, S_HIGH = 2.05, 3.0      # wall tops west / east (the lean-to)
S_WIN = (-0.1, 0.55, 1.1, 1.55)   # west window: y0, y1, z0, z1
S_DOOR_X = 0.1


def _s_top(x: float) -> float:
    return S_LOW + (x + SX) / (2 * SX) * (S_HIGH - S_LOW)


def shed_room():
    """The shed inside: see the module doc."""
    L.reset(1800)
    parts = []
    # plank floor (along x) on a dark bed
    def fcol(u, v, r):
        return L.scale_c(random.choice((FLOOR_BOARD, WOOD, WOOD_OLD)), random.uniform(0.82, 1.08))
    parts += _tiled(lambda u, v: Vector((u, v, 0.0)), -SX, SX, -SY, SY, 1.1, 0.22, fcol, gap=0.012, relief=0.004,
                    backing=L.hexc("#1E1712"))
    # board walls: north (sloped top), west (low, window), east (high); south stub with the door gap
    def bcol(u, v, r):
        return L.scale_c(random.choice((WOOD_WARM, WOOD, WOOD, WOOD_OLD)), random.uniform(0.85, 1.08))

    def north(u, v):
        return Vector((u, SY, v))
    parts += _tiled(north, -SX, SX, 0.0, S_HIGH, 0.2, S_HIGH, bcol, relief=0.006, stagger=False, gap=0.01,
                    skip=lambda u, v: False, backing=L.hexc("#1A1410"))
    # cut the north boards to the roof line: move the top vertices down onto the slope
    o = parts[-2]
    for v in o.data.vertices:
        v.co.z = min(v.co.z, _s_top(v.co.x) - 0.02)
    ob = parts[-1]
    for v in ob.data.vertices:
        v.co.z = min(v.co.z, _s_top(v.co.x) - 0.02)
    win = lambda a, z: S_WIN[0] - 0.04 < a < S_WIN[1] + 0.04 and S_WIN[2] - 0.04 < z < S_WIN[3] + 0.04  # noqa: E731
    _face(parts, "x", -SX, 1, -SY, SY, 0.0, S_LOW, 0.2, S_LOW, bcol, skip=win, relief=0.006, backing=L.hexc("#1A1410"), gap=0.01)
    _face(parts, "x", SX, -1, -SY, SY, 0.0, S_HIGH, 0.2, S_HIGH, bcol, relief=0.006, backing=L.hexc("#1A1410"), gap=0.01)
    door = lambda a, z: abs(a - S_DOOR_X) < 0.46  # noqa: E731
    _face(parts, "y", -SY, -1, -SX, SX, 0.0, 0.42, 0.2, 0.42, bcol, skip=door, relief=0.006, backing=None, gap=0.01)
    # frame: posts, plates, rafters rising east (stubs, the roof is cut away), the west window
    for x in (-SX + 0.05, SX - 0.05):
        for y in (-SY + 0.05, SY - 0.05):
            h = _s_top(x) if y > 0 else 0.55
            parts.append(_slab((x, y, h / 2), (0.05, 0.05, h / 2), WOOD_DARK, seed=int(x * 10 + y), var=0.15, ao=0.3))
    for sx in (-1, 1):
        parts.append(_slab((S_DOOR_X + sx * 0.52, -SY + 0.05, 0.3), (0.05, 0.05, 0.3), WOOD_DARK, seed=10 + sx, var=0.15, ao=0.2))
    for x in (-SX + 0.06, SX - 0.06):
        parts.append(_slab((x, 0.0, _s_top(x) - 0.05), (0.05, SY, 0.06), WOOD_DARK, seed=12, var=0.15, ao=0.0))
    for k, y in enumerate((-0.6, 0.55, SY - 0.1)):
        p0 = Vector((-SX, y, _s_top(-SX) + 0.02))
        p1 = Vector((SX, y, _s_top(SX) + 0.02))
        if y < SY - 0.2:
            p1 = p0 + (p1 - p0) * 0.28          # rafter stubs, cut
        parts.append(P._stick(p0, p1, 0.045, WOOD_DARK, verts=4, seed=14 + k, ao=0.1))
    y0, y1, z0, z1 = S_WIN
    parts.append(_slab((-SX - 0.03, (y0 + y1) / 2, (z0 + z1) / 2), (0.01, (y1 - y0) / 2, (z1 - z0) / 2), B.GLASS, jit=0.0,
                       var=0.2, ao=0.0))
    for y in (y0 - 0.03, y1 + 0.03):
        parts.append(_slab((-SX + 0.02, y, (z0 + z1) / 2), (0.03, 0.03, (z1 - z0) / 2 + 0.05), WOOD_DARK, seed=20, var=0.12, ao=0.0))
    for z in (z0 - 0.03, z1 + 0.03):
        parts.append(_slab((-SX + 0.02, (y0 + y1) / 2, z), (0.03, (y1 - y0) / 2 + 0.06, 0.03), WOOD_DARK, seed=21, var=0.12,
                           ao=0.0))
    parts.append(_slab((-SX + 0.1, (y0 + y1) / 2, z0 - 0.06), (0.1, (y1 - y0) / 2 + 0.08, 0.02), WOOD_OLD, seed=22, var=0.12,
                       ao=0.0, top=0.3))
    # lantern on a post by the door (hook, lantern) + a coil of rope and a broom in the corner
    lx = S_DOOR_X - 0.75
    parts.append(_slab((lx, -SY + 0.06, 1.0), (0.05, 0.05, 1.0), WOOD_DARK, seed=30, var=0.15, ao=0.2))
    light = B._wall_lantern(parts, Vector((lx, -SY + 0.3, 1.55)), -SY + 0.11, seed=31)
    parts.append(L.part("torus", ROPE, loc=(SX - 0.35, SY - 0.3, 0.05), major_radius=0.16, minor_radius=0.035,
                        major_segments=10, minor_segments=4, jit=0.006, seed=32))
    _cut_band(parts, -SX - 0.08, SX + 0.08, -SY - 0.08, SY, 40, depth=0.35)
    markers = [("door_inside", (S_DOOR_X, -SY + 0.3, 0.0)), ("spawn_inside", (S_DOOR_X, -SY + 0.75, 0.0)),
               ("light_window_1", (-SX + 0.45, (y0 + y1) / 2, (z0 + z1) / 2)), ("light_lantern", tuple(light))]
    _done(parts, "ph_int_shed_room", markers, 30)


def shed_rack():
    """Lagerregal (1.6 x 0.5 x 2.0 m): four boards with fixed, painted stock - sacks, a crate, stacked
    boards, iron bars, a clay pot, a coil of rope - and the ledger on a small writing board."""
    L.reset(1810)
    parts = []
    W, D = 0.8, 0.25
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(P._plank((sx * W, sy * D, 1.0), (0.035, 0.035, 1.0), WOOD_DARK, seed=1 + sx + sy, ao=0.3))
    levels = (0.08, 0.6, 1.12, 1.64)
    for z in levels:
        parts.append(P._plank((0.0, 0.0, z), (W + 0.02, D + 0.02, 0.018), WOOD, seed=int(z * 10), cuts=1, ao=0.15))
    # level 0: two sacks and a crate
    for i, x in enumerate((-0.5, -0.1)):
        s = L.prim("sphere", loc=(x, 0.0, levels[0] + 0.19), radius=0.2, segments=8, ring_count=6, scale=(0.9, 0.85, 1.0))
        L.jitter(s, 0.02, 4.0, 10 + i)
        parts.append(B._paint(s, SACK, var=0.12, ao=0.35, top=0.2, seed=10 + i))
    parts.append(P._rbox((0.45, 0.0, levels[0] + 0.17), (0.25, 0.2, 0.15), WOOD_OLD, bev=0.01, seed=12))
    # level 1: stacked boards and iron bars
    for k in range(4):
        parts.append(P._plank((-0.3, 0.0, levels[1] + 0.03 + k * 0.035), (0.42, 0.12, 0.015), WOOD_FRESH, seed=20 + k))
    for k in range(4):
        parts.append(_slab((0.45 + (k % 2) * 0.03, -0.1 + k * 0.06, levels[1] + 0.03 + (k // 2) * 0.03), (0.25, 0.02, 0.015),
                           L.hexc("#4A4C50"), jit=0.002, var=0.2, ao=0.0, top=0.4))
    # level 2: clay pots and a rope coil
    for i, x in enumerate((-0.55, -0.25)):
        pot = _lathe([(0.06, 0.0), (0.11, 0.08), (0.1, 0.2), (0.06, 0.24), (0.07, 0.27), (0.0, 0.27)], 8, "pot")
        pot.data.transform(Matrix.Translation((x, 0.0, levels[2] + 0.02)))
        parts.append(B._paint(pot, CLAY, var=0.15, ao=0.3, top=0.2, seed=30 + i))
    parts.append(L.part("torus", ROPE, loc=(0.4, 0.0, levels[2] + 0.06), major_radius=0.16, minor_radius=0.04,
                        major_segments=10, minor_segments=4, jit=0.006, seed=33))
    # level 3: a folded linen bundle and a box of nails
    parts.append(P._rbox((-0.35, 0.0, levels[3] + 0.08), (0.3, 0.18, 0.07), LINEN_DIRTY, bev=0.03, seed=40))
    parts.append(P._rbox((0.35, 0.0, levels[3] + 0.07), (0.18, 0.14, 0.06), WOOD_DARK, bev=0.008, seed=41))
    # the ledger on a writing board at the side
    parts.append(P._plank((W + 0.2, -0.05, 1.05), (0.18, 0.2, 0.015), WOOD, seed=50, rot=(0, 0, 0)))
    parts.append(P._plank((W + 0.3, -0.05, 0.52), (0.03, 0.03, 0.52), WOOD_DARK, seed=51))
    book = P._rbox((W + 0.2, -0.05, 1.085), (0.14, 0.11, 0.025), L.hexc("#4A3428"), bev=0.006, seed=52)
    parts.append(book)
    parts.append(_slab((W + 0.2, -0.05, 1.112), (0.12, 0.1, 0.003), L.hexc("#DCCFAE"), jit=0.0, var=0.05, ao=0.0))
    parts.append(_slab((W + 0.22, -0.05, 1.116), (0.004, 0.09, 0.002), ACCENT_RED, jit=0.0, var=0.0, ao=0.0))
    _done(parts, "ph_int_shed_rack", [("book", (W + 0.2, -0.05, 1.12))], 35, shift=True)


def wood_rack():
    """Holzlege innen: split logs stacked between four posts (1.3 x 0.5 x 1.3 m)."""
    L.reset(1820)
    parts = []
    W, D, H = 0.62, 0.22, 1.25
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(P._plank((sx * W, sy * D, H / 2), (0.035, 0.035, H / 2), WOOD_DARK, seed=1 + sx + sy, ao=0.3))
    parts.append(P._plank((0.0, 0.0, 0.05), (W + 0.04, D + 0.04, 0.04), WOOD_OLD, seed=5))
    r = 0.07
    k = 0
    for row in range(7):
        n = 8
        for i in range(n):
            x = -W + 0.08 + i * (2 * W - 0.14) / (n - 1) + (0.04 if row % 2 else 0.0)
            if x > W - 0.06:
                continue
            z = 0.09 + r + row * r * 1.7
            o = L.prim("cyl", loc=(x, 0.0, z), rot=(90, 0, random.uniform(0, 60)), radius=r * random.uniform(0.85, 1.0),
                       depth=2 * D * random.uniform(0.9, 1.0), vertices=5)
            P._paint_fn(o, lambda co, vi: L.scale_c(P.END_GRAIN if abs(co.y) > D * 0.85 else P.BARK, random.uniform(0.8, 1.05)))
            L.set_mat(o, L.MAT_PAINTED)
            parts.append(o)
            k += 1
    _done(parts, "ph_int_wood_rack", [], 35, shift=True, centre=True)


def stone_bin():
    """Steinkiste: a low plank bin (1.0 x 0.6 x 0.45 m) with rough stones, two squared blocks and a lump
    of clay under a damp sack."""
    L.reset(1830)
    parts = []
    W, D, H = 0.5, 0.3, 0.42
    for sy in (-1, 1):
        parts.append(P._plank((0.0, sy * D, H / 2), (W, 0.02, H / 2), WOOD, seed=1 + sy, cuts=1, ao=0.3))
    for sx in (-1, 1):
        parts.append(P._plank((sx * W, 0.0, H / 2), (0.02, D, H / 2), WOOD_DARK, seed=3 + sx, ao=0.3))
        parts.append(P._plank((sx * (W - 0.02), -D - 0.02, H / 2), (0.03, 0.03, H / 2 + 0.03), WOOD_DARK, seed=5 + sx))
    for i in range(9):
        x = random.uniform(-W + 0.1, W - 0.12)
        y = random.uniform(-D + 0.08, D - 0.08)
        s = random.uniform(0.07, 0.11)
        parts.append(B._stone((x, y, H - 0.06 + random.uniform(-0.03, 0.03)), (s, s * 0.85, s * 0.7), random.choice((STONE, STONE_OLD, STONE_WARM)),
                              rot=(random.uniform(-20, 20), random.uniform(-20, 20), random.uniform(0, 90)), seed=10 + i))
    parts.append(B._stone((0.28, 0.05, H + 0.04), (0.14, 0.1, 0.08), STONE_PALE, seed=30, jit=0.006, top=0.25))
    clay = L.prim("ico", loc=(-0.3, 0.02, H + 0.02), radius=0.13, subdivisions=1, scale=(1.2, 1.0, 0.6))
    L.jitter(clay, 0.02, 5.0, 31)
    parts.append(B._paint(clay, CLAY, var=0.2, ao=0.3, top=0.2))
    parts.append(P._rbox((-0.33, 0.05, H + 0.08), (0.14, 0.12, 0.02), SACK, bev=0.015, seed=32, rot=(6, 4, 20)))
    _done(parts, "ph_int_stone_bin", [], 35, shift=True, centre=True)


ASSETS = [crypt_room, crypt_stair, crypt_table, crypt_niche, crypt_niche_sealed, crypt_lantern, candle_niche,
          ossuary_shelf, bone_box, bone_rack, name_board, sealed_passage, sealed_passage_grille,
          chapel_room, altar, catafalque, pew_rough, pew, bell_rope, candelabrum, stained_window, holy_water,
          shed_room, shed_rack, wood_rack, stone_bin]


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
