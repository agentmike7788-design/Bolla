"""Phase 7: the buildings of Hollerbrueck, outside (docs/PHASE7_DESIGN.md sections 4.2 and 8), 'Gemaltes Diorama'.

Every model stands in its real village orientation (placed with rotation 0 at its section-4.2 centre):
Blender +X = east, +Y = north, -Y = south = Godot +Z = towards the game camera. Pivot = footprint centre
on the ground, 1 unit = 1 m, shared materials only. Village colours: warm lime plaster, dark oak
half-timbering, muted clay tiles, slate on the church, thatch on the Hagedorn cottage.

  ph_bld_v_church     St. Gallus (8 x 12 m): nave with three round-headed windows a side, an oculus in the
                      south gable, the west-tower ... at the north end (spire top <= 17 m), slate, steps to the
                      Kirchplatz, a lantern beside the door
  ph_bld_v_office     Amtshaus (9 x 7, <= 8.5 m): stone ground floor, half-timbered upper floor, the parish
                      shield over the door (painted, no text), door south
  ph_bld_v_inn        Holderkrug (10 x 7, <= 8.5 m): half-timbered, gable to the south, the hanging sign with a
                      painted elder sprig (blank board edge for the Label3D "Holderkrug"), bench, lantern
  ph_bld_v_smithy     Schmiede (6 x 6, <= 5.5 m, chimney 6.4): open to the east under the eave, forge with
                      painted embers and hood, anvil on its stump, trough, tool rack
  ph_bld_v_shop       Kraemerladen (6 x 5, <= 6 m): shop window in the east wall with a folding shutter (the
                      lower leaf is the counter board, the upper one an awning), goods on shelves inside
  ph_bld_v_surgery    Wundarzthaus (7 x 8, <= 8 m): pale two-storey house, door west with a brass plate
  ph_bld_v_remise     Remise (7 x 5, <= 5 m): board barn, the double gate west (one leaf open)
  ph_bld_v_cottage_a  Hagedorn-Kate (6 x 5, eave 2.4, ridge 4.4): rubble and lime, thatch, door north
  ph_bld_v_cottage_b  Dorn-Kate (6 x 5, same heights): half-timbered, shingles, door north
  ph_bld_v_house_a/_b/_c  backdrop houses (<= 7 m, door to the camera): ochre / grey / gable-fronted
  ph_bld_v_inn2       "Zum Stumpf" (<= 7 m): the second inn, its sign with a painted tree stump

Markers (glTF empties, Godot attaches lights / prompts; Blender coordinates here, Godot = (x, z, -y)):
  door_outside     ground point in front of the door / gate / counter side (the section-4.2 door points)
  light_window_N   0.3 m outside a window pane (warm window light at night, no shadow)
  light_window     (cottages, houses, inn2) the same for the one lit window
  light_lantern    inn: below the lantern glass by the door (the shadow light)
  light_door       church: below the lantern glass beside the door (the shadow light)
  label_board        inn / inn2: centre of the blank sign board face, local +Z (Godot) = face normal
  ribbon           cottages, houses, inn2: where the mourning ribbon (ph_prop_v_ribbon) hangs (door frame)
  counter          smithy / shop: ground point of the ShopCounter (in front of the anvil / shop window)
  anvil            smithy: top of the anvil face
  light_ember      smithy: just above the forge coals (omni #E07A3A, no shadow; the coals are vertex colour)
  smoke            smithy: chimney top

Run:  python tools/blender/build_all.py asset_village_buildings
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_buildings_phase6 as B6
import asset_villagers as VIL

CAT = "buildings"

# --- palette ---------------------------------------------------------------------------------------
PLASTER = L.hexc("#A89F8F")
PLASTER_DIRTY = L.hexc("#8E8778")
PLASTER_OCHRE = L.hexc("#AE9C7C")
PLASTER_PALE = L.hexc("#B2AA9A")
PLASTER_ROSE = L.hexc("#A8968A")
PLASTER_GREY = L.hexc("#9A968C")
TIMBER = L.hexc("#4A3626")
TIMBER_DARK = L.hexc("#36281D")
WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
STONE = L.hexc("#7E8187")
STONE_DARK = L.hexc("#62656A")
STONE_OLD = L.hexc("#686B64")
STONE_PALE = L.hexc("#8C8A83")
SAND = L.hexc("#9A8E78")            # dressed sandstone: quoins, portals, steps
SAND_DARK = L.hexc("#7E745F")
MOSS = L.hexc("#5E7148")
MOSS_DARK = L.hexc("#44543A")
IRON = P.IRON
RUST = P.RUST
GLASS = L.hexc("#3E3A34")
GLASS_DEEP = L.hexc("#2A2724")
GAP = L.hexc("#15110E")
BRASS = L.hexc("#8C7648")
TILE = (L.hexc("#7A5444"), L.hexc("#5E4036"), L.hexc("#8C6650"))
TILE_OLD = (L.hexc("#6E5246"), L.hexc("#54403A"), L.hexc("#7E6454"))
SHINGLE = (L.hexc("#5A4E48"), L.hexc("#463D38"), L.hexc("#6B5E54"))
SLATE = (L.hexc("#5B6168"), L.hexc("#474C53"), L.hexc("#6C7179"))
THATCH = (L.hexc("#8A7A58"), L.hexc("#6A5C42"), L.hexc("#9C8C66"))
EMBER = L.hexc("#E07A3A")
COAL = L.hexc("#2A2422")
ELDER_LEAF = L.hexc("#4E6440")
ELDER_FLOWER = L.hexc("#D8CEAE")
ELDER_BERRY = L.hexc("#2E2630")

SIGN = {"S": -1, "N": 1, "E": 1, "W": -1}


# --- face helpers ------------------------------------------------------------------------------------

def _pt(face: str, plane: float, a: float, n: float, z: float) -> Vector:
    """Point on a wall face: a = along the wall (x for S/N, y for E/W), n = outward offset."""
    s = SIGN[face]
    if face in "SN":
        return Vector((a, plane + s * n, z))
    return Vector((plane + s * n, a, z))


def _half(face: str, ha: float, hn: float, hz: float) -> tuple:
    return (ha, hn, hz) if face in "SN" else (hn, ha, hz)


def _box(loc, half, color, rot=(0, 0, 0), jit: float = 0.0, seed: int = 0, cuts: int = 0, **pk):
    o = L.prim("cube", loc=loc, rot=rot, scale=half)
    if cuts:
        L.subdivide(o, cuts)
    if jit:
        L.jitter(o, jit, 3.0, seed)
    kw = {"var": 0.14, "ao": 0.15, "top": 0.15}
    kw.update(pk)
    L.paint(o, color, seed=seed, **kw)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _plaster_fn(base, z0: float, z1: float, seed: float, stones: float = 0.15, dirty: float = 1.0):
    def fn(co, vi):
        n = noise.noise(Vector((co.x * 1.3, co.y * 1.3, co.z * 1.3 + seed)))
        f = noise.noise(Vector((co.x * 3.1 + seed, co.y * 3.1, co.z * 3.1)))
        h = max(0.0, min(1.0, (co.z - z0) / max(1e-6, z1 - z0)))
        c = L.mix(base, L.scale_c(base, 0.84), 0.35 + 0.35 * n)
        c = L.mix(c, L.mix(L.scale_c(base, 0.82), MOSS_DARK, 0.3), dirty * max(0.0, 0.5 - h * 2.4))
        if f > 1.0 - stones:
            c = L.mix(c, STONE_OLD, min(1.0, (f - 1.0 + stones) * 6.0))
        return L.scale_c(c, 0.92 + 0.1 * h)
    return fn


def _wall(parts, face: str, plane: float, a0: float, a1: float, z0: float, z1: float, holes=(), base=PLASTER,
          thick: float = 0.3, top=None, seed: int = 0, stones: float = 0.15, dirty: float = 1.0, zr=None):
    """Wall slab with rectangular holes [(centre a, width, sill, head)]; top(a) gives a gable/slope.
    The outer face lies at `plane`."""
    s = SIGN[face]
    lo, hi = sorted((plane, plane - s * thick))
    axis = "y" if face in "SN" else "x"
    fn = _plaster_fn(base, *(zr or (z0, z1)), seed * 0.37, stones, dirty)

    def slab(b0, b1, zb, zt):
        if b1 - b0 < 0.02:
            return
        if callable(zt):
            n = max(1, int(math.ceil((b1 - b0) / 0.5)))
            tops = [(b1 - (b1 - b0) * k / n, zt(b1 - (b1 - b0) * k / n)) for k in range(n + 1)]
            mid = [a for a in (0.0,) if b0 < a < b1]
            for a in mid:
                tops.append((a, zt(a)))
            tops.sort(key=lambda q: -q[0])
        else:
            tops = [(b1, zt), (b0, zt)]
        if max(z for _, z in tops) - zb < 0.02:
            return
        poly = [(b0, zb), (b1, zb)] + [(a, max(zb + 0.01, z)) for a, z in tops]
        o = B6._prism(poly, axis, lo, hi, "wall")
        if b1 - b0 > 3.0 and (max(z for _, z in tops) - zb) > 2.0:
            L.subdivide(o, 1)
        L.jitter(o, 0.01, 2.0, seed + int(b0 * 10))
        P._paint_fn(o, fn)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)

    t = top if top is not None else z1
    # group holes into columns (holes stacked over each other share a column)
    cols = []
    for c, w, sill, head in sorted(holes):
        b0, b1 = c - w / 2, c + w / 2
        if cols and b0 < cols[-1][1] - 0.01:
            cols[-1][0] = min(cols[-1][0], b0)
            cols[-1][1] = max(cols[-1][1], b1)
            cols[-1][2].append((b0, b1, sill, head))
        else:
            cols.append([b0, b1, [(b0, b1, sill, head)]])
    cur = a0
    for b0, b1, hs in cols:
        slab(cur, b0, z0, t)
        zc = z0
        for h0, h1, sill, head in sorted(hs, key=lambda q: q[2]):
            if sill > zc + 0.02:
                slab(b0, b1, zc, sill)
            slab(b0, h0, sill, head)       # side fillers when the hole is narrower than the column
            slab(h1, b1, sill, head)
            zc = head
        slab(b0, b1, zc, t)
        cur = b1
    slab(cur, a1, z0, t)


def _gable_fn(half: float, eave: float, ridge: float, centre: float = 0.0):
    return lambda a: eave + (ridge - eave) * max(0.0, 1.0 - abs(a - centre) / half)


def _beam(p0, p1, hw: float, color=TIMBER, seed: int = 0, hd: float = None):
    """Square timber between two points (hw = half width, hd = half depth)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    o = L.prim("cube", scale=(hw, hd if hd else hw, d.length / 2))
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    o.data.transform(Matrix.Translation((p0 + p1) / 2) @ rot)
    L.jitter(o, 0.006, 3.0, seed)
    L.paint(o, L.scale_c(color, random.uniform(0.85, 1.1)), var=0.18, ao=0.1, top=0.2, seed=seed, hue_shift=TIMBER_DARK)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _timber(parts, face: str, plane: float, a0: float, a1: float, z0: float, z1: float, posts, braces=(),
            rails=(), seed: int = 0, out: float = 0.03, top=None):
    """Half-timbering on a wall face: sill and plate, posts at `posts`, rails at heights `rails`
    [(z, a_from, a_to)], braces [(a_low, z_low, a_high, z_high)]."""
    w = 0.075

    def P_(a, z):
        return _pt(face, plane, a, out, z)
    parts.append(_beam(P_(a0 - 0.05, z0 + w), P_(a1 + 0.05, z0 + w), w, seed=seed, hd=0.05))
    if top is None:
        parts.append(_beam(P_(a0 - 0.05, z1 - w), P_(a1 + 0.05, z1 - w), w, seed=seed + 1, hd=0.05))
    for k, a in enumerate(posts):
        zt = top(a) - w if top is not None else z1 - w
        parts.append(_beam(P_(a, z0 + w), P_(a, zt), w * 0.9, seed=seed + 2 + k, hd=0.05))
    for k, (z, af, at) in enumerate(rails):
        parts.append(_beam(P_(af, z), P_(at, z), w * 0.8, seed=seed + 20 + k, hd=0.05))
    for k, (al, zl, ah, zh) in enumerate(braces):
        parts.append(_beam(P_(al, zl), P_(ah, zh), w * 0.8, seed=seed + 40 + k, hd=0.05))
    if top is not None:   # rafters along a gable edge
        n = 8
        for k in range(n):
            a_ = a0 + (a1 - a0) * k / n
            b_ = a0 + (a1 - a0) * (k + 1) / n
            parts.append(_beam(P_(a_, top(a_) - w), P_(b_, top(b_) - w), w, seed=seed + 60 + k, hd=0.05))


def _win(parts, face: str, plane: float, a: float, sill: float, w: float, h: float, seed: int = 0,
         shutters=None, frame=WOOD_DARK, stone=None, cross: bool = True, recess: float = 0.12) -> Vector:
    """Window: dark warm glass a little recessed, frame, cross muntins, sill board; optional open shutters
    or a stone surround. Returns the light point 0.3 m outside the pane."""
    zc = sill + h / 2
    g = _box(_pt(face, plane, a, -recess, zc), _half(face, w / 2, 0.01, h / 2), GLASS, var=0.25, ao=0.0, top=0.0, seed=seed)
    P._paint_fn(g, lambda co, vi: L.mix(GLASS, GLASS_DEEP, 0.5 + 0.5 * noise.noise(co * 3.0 + Vector((seed, 0, 0)))))
    parts.append(g)
    fw = 0.05
    for sa in (-1, 1):
        parts.append(_box(_pt(face, plane, a + sa * (w / 2 + fw / 2), -recess / 2, zc), _half(face, fw / 2, recess / 2 + 0.02, h / 2 + fw),
                          frame, seed=seed + 1 + sa, ao=0.0))
    parts.append(_box(_pt(face, plane, a, -recess / 2, sill + h + fw / 2), _half(face, w / 2 + fw, recess / 2 + 0.02, fw / 2),
                      frame, seed=seed + 4, ao=0.0))
    if cross:
        parts.append(_box(_pt(face, plane, a, -recess + 0.02, zc + h * 0.1), _half(face, w / 2, 0.015, 0.018), frame, ao=0.0))
        parts.append(_box(_pt(face, plane, a, -recess + 0.02, zc), _half(face, 0.018, 0.015, h / 2), frame, ao=0.0))
    parts.append(_box(_pt(face, plane, a, 0.05, sill - fw - 0.02), _half(face, w / 2 + fw + 0.05, 0.08, 0.025),
                      stone if stone else frame, seed=seed + 6, top=0.35))
    if stone is not None:
        for sa in (-1, 1):
            parts.append(_box(_pt(face, plane, a + sa * (w / 2 + fw + 0.07), 0.02, zc), _half(face, 0.08, 0.04, h / 2 + 0.1),
                              stone, jit=0.006, seed=seed + 7 + sa, top=0.2))
        parts.append(_box(_pt(face, plane, a, 0.02, sill + h + fw + 0.08), _half(face, w / 2 + fw + 0.15, 0.04, 0.08), stone,
                          jit=0.006, seed=seed + 9, top=0.3))
    if shutters is not None:
        for sa in (-1, 1):
            sc = a + sa * (w / 2 + fw + w / 4 + 0.02)
            parts.append(_box(_pt(face, plane, sc, 0.03, zc), _half(face, w / 4, 0.02, h / 2 + 0.02), shutters, jit=0.004,
                              seed=seed + 10 + sa, var=0.2, ao=0.1))
    return _pt(face, plane, a, 0.3, zc)


def _door(parts, face: str, plane: float, a: float, w: float, h: float, seed: int = 0, color=WOOD_DARK,
          frame=TIMBER, stone=None, step=None, arch: bool = False, recess: float = 0.1, leaves: int = 1) -> Vector:
    """Plank door (recessed), frame or stone surround, a step. Returns the ground point 0.5 m out."""
    s = SIGN[face]
    n_boards = max(3, int(w / 0.16))
    for k in range(n_boards):
        b0 = a - w / 2 + k * w / n_boards
        bc = b0 + w / n_boards / 2
        hh = h
        if arch:
            hh = h - w / 2 + math.sqrt(max(0.0, (w / 2) ** 2 - (bc - a) ** 2))
        parts.append(_box(_pt(face, plane, bc, -recess, hh / 2), _half(face, w / n_boards / 2 - 0.006, 0.025, hh / 2),
                          L.scale_c(color, random.uniform(0.85, 1.15)), seed=seed + k, var=0.15, ao=0.3, hue_shift=WOOD))
    for z in (h * 0.25, h * 0.7):
        parts.append(_box(_pt(face, plane, a, -recess + 0.03, z), _half(face, w / 2 - 0.04, 0.008, 0.03), IRON, ao=0.0,
                          hue_shift=RUST))
    parts.append(L.part("torus", IRON, loc=_pt(face, plane, a + w * 0.3, -recess + 0.05, h * 0.5),
                        rot=(90, 0, 0) if face in "SN" else (0, 90, 0), major_radius=0.04, minor_radius=0.008,
                        major_segments=8, minor_segments=3))
    if leaves == 2:
        parts.append(_box(_pt(face, plane, a, -recess + 0.02, h / 2), _half(face, 0.01, 0.01, h / 2), GAP, var=0.0, ao=0.0))
    fc = stone if stone is not None else frame
    fw = 0.12 if stone is not None else 0.08
    for sa in (-1, 1):
        parts.append(_box(_pt(face, plane, a + sa * (w / 2 + fw / 2), 0.0, h / 2 + 0.04), _half(face, fw / 2, 0.06 if stone else 0.05, h / 2 + 0.04),
                          fc, jit=0.004, seed=seed + 20 + sa, top=0.2))
    if not arch:
        parts.append(_box(_pt(face, plane, a, 0.0, h + 0.08 + fw / 2), _half(face, w / 2 + fw + 0.04, 0.06, fw / 2 + 0.02), fc,
                          jit=0.004, seed=seed + 23, top=0.3))
    else:
        r = w / 2
        for k in range(7):
            a0_, a1_ = math.pi * k / 7, math.pi * (k + 1) / 7
            am = (a0_ + a1_) / 2
            c = _pt(face, plane, a + (r + fw / 2) * math.cos(am), 0.0, h - r + (r + fw / 2) * math.sin(am))
            rotd = -math.degrees(am) + 90
            parts.append(_box(c, _half(face, fw / 2 * 1.3, 0.06, fw / 2 + 0.01), fc, jit=0.003, seed=seed + 30 + k,
                              rot=(0, rotd, 0) if face in "SN" else (rotd, 0, 0), top=0.3))
    for sa in (-1, 1):   # reveals (dark inside the opening)
        parts.append(_box(_pt(face, plane, a + sa * (w / 2 + 0.004), -recess / 2, h / 2), _half(face, 0.006, recess / 2, h / 2),
                          L.scale_c(PLASTER_DIRTY, 0.6), var=0.1, ao=0.0))
    if step is not None:
        parts.append(_box(_pt(face, plane, a, 0.2, 0.07), _half(face, w / 2 + 0.25, 0.22, 0.08), step, jit=0.01, seed=seed + 40,
                          top=0.3, ao=0.3))
    return _pt(face, plane, a, 0.5, 0.0)


def _roof(parts, ridge_axis: str, cx: float, cy: float, half_span: float, half_len: float, eave_z: float,
          ridge_z: float, pal, over: float = 0.35, row: float = 0.32, seg: float = 0.55, seed: int = 0,
          mossy: float = 0.2, lift: float = 0.035, thick: float = 0.06, end_over: float = 0.3, sides=(-1, 1),
          thatch: bool = False, ridge_cap: bool = True):
    """Gable roof: courses of tiles (one quad strip per course, crisp per-tile colours, a lifted lower edge
    and a butt face), a dark deck under them, ridge caps, verge boards. half_span = wall half depth
    across the ridge (eave at the wall line at eave_z), over = eave overhang."""
    pitch = math.atan2(ridge_z - eave_z, half_span)
    slope = (half_span + over) / math.cos(pitch)
    c_base, c_dark, c_light = pal
    rng = random.Random(seed)
    bm = bmesh.new()
    cols = []

    def W_(u, v, z):   # u across (perp to ridge), v along the ridge
        return Vector((cx + u, cy + v, z)) if ridge_axis == "y" else Vector((cx + v, cy + u, z))
    l0, l1 = -half_len - end_over, half_len + end_over
    for s in sides:
        rows = max(2, int(slope / row))
        step = slope / rows
        for r in range(rows + 1):
            t0 = max(0.0, r * step - (0.05 if r else 0.0))
            t1 = min(slope, (r + 1) * step + step * 0.45)
            if t0 >= slope:
                break
            nseg = max(1, int((l1 - l0) / seg))
            off = (seg * 0.5 if r % 2 else 0.0)
            vs = [l0] + [l0 + off + k * (l1 - l0) / nseg for k in range(1, nseg)] + [l1]
            vs = sorted(set(round(v, 4) for v in vs if l0 <= v <= l1))
            lr = rng.uniform(0.8, 1.2) * lift

            def P_(t, v, up):
                u = s * t * math.cos(pitch)
                z = ridge_z - t * math.sin(pitch) + up
                return W_(u, v, z)
            for k in range(len(vs) - 1):
                va, vb = vs[k], vs[k + 1]
                jt = rng.uniform(-0.02, 0.02) if thatch else 0.0
                q = [bm.verts.new(P_(t0, va, 0.0)), bm.verts.new(P_(t0, vb, 0.0)),
                     bm.verts.new(P_(t1 + jt, vb, lr)), bm.verts.new(P_(t1 + jt, va, lr))]
                f = bm.faces.new(q)
                f.normal_update()
                if f.normal.z < 0:
                    f.normal_flip()
                b = [bm.verts.new(P_(t1 + jt, va, lr - lift - thick)), bm.verts.new(P_(t1 + jt, vb, lr - lift - thick))]
                g = bm.faces.new((q[3], q[2], b[1], b[0]))
                g.normal_update()
                down = W_(s * math.cos(pitch), 0.0, 0.0) - W_(0.0, 0.0, 0.0)
                if g.normal.dot(down) < 0:
                    g.normal_flip()
                edge = max(0.0, (t1 / slope - 0.75) / 0.25)
                nn = 0.5 + 0.5 * noise.noise(Vector(((va + vb) * 0.6, t1 * 0.7, s * 3.0 + seed)))
                bc = L.mix(c_base, rng.choice((c_dark, c_light, c_base, c_dark)), rng.uniform(0.15, 0.55 if not thatch else 0.3))
                bc = L.scale_c(bc, rng.uniform(0.93, 1.07))
                m = mossy * (edge * 0.7 + max(0.0, nn - 0.7) * 2.5)
                c = L.mix(bc, L.mix(MOSS, L.hexc("#7A7E60"), rng.random()), min(0.7, m))
                cols.append(c)
                cols.append(L.scale_c(c, 0.6))
    me = bpy.data.meshes.new("tiles")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("tiles", me)
    bpy.context.collection.objects.link(o)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        c = cols[poly.index]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            cc = L.scale_c(c, 1.0 + noise.noise(co * 2.3) * (0.1 if thatch else 0.05))
            attr.data[li].color = (L._to_lin(cc[0]), L._to_lin(cc[1]), L._to_lin(cc[2]), 1.0)
    L.set_mat(o, L.MAT_PAINTED)
    parts.append(o)
    # deck under the courses (closes the gaps, dark)
    for s in sides:
        mid_t = slope / 2
        u = s * mid_t * math.cos(pitch)
        z = ridge_z - mid_t * math.sin(pitch) - 0.05
        hl = (l1 - l0) / 2
        d = L.prim("cube", scale=(slope / 2, hl, 0.03) if ridge_axis == "x" and False else (slope / 2, hl, 0.03))
        m = Matrix.Rotation(s * pitch, 4, "Y")
        d.data.transform(m)
        if ridge_axis == "x":
            d.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
        d.data.transform(Matrix.Translation(W_(u, (l0 + l1) / 2, z)))
        parts.append(_box_paint(d, c_dark))
    if ridge_cap and len(sides) == 2:
        v = l0 - 0.02
        k = 0
        while v < l1:
            w = min(0.45, l1 + 0.02 - v)
            hw = (0.12, w / 2 * 0.97) if ridge_axis == "y" else (w / 2 * 0.97, 0.12)
            parts.append(_box(W_(0.0, v + w / 2, ridge_z + 0.05), (hw[0], hw[1], 0.06 if not thatch else 0.1),
                              L.scale_c(c_dark, 0.9), jit=0.006, seed=seed + 300 + k, ao=0.0, top=0.3))
            v += w
            k += 1
    # verge boards at both gable ends
    if not thatch:
        ln = slope
        for vend in (l0 - 0.02, l1 + 0.02):
            for s in sides:
                u = s * slope / 2 * math.cos(pitch)
                z = ridge_z - slope / 2 * math.sin(pitch) + 0.02
                rot_deg = math.degrees(s * pitch)
                vb = L.prim("cube", scale=(ln / 2 + 0.04, 0.025, 0.07))
                vb.data.transform(Matrix.Rotation(math.radians(rot_deg), 4, "Y"))
                if ridge_axis == "x":
                    vb.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))
                vb.data.transform(Matrix.Translation(W_(u, vend, z)))
                parts.append(_box_paint(vb, WOOD_DARK))
    return pitch


def _box_paint(o, color, **kw):
    pk = {"var": 0.12, "ao": 0.0, "top": 0.15}
    pk.update(kw)
    L.paint(o, color, **pk)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _plinth(parts, x0, x1, y0, y1, h: float = 0.4, seed: int = 0, color=STONE_OLD, skip=()):
    """Rubble socle around the footprint (skip faces in `skip`)."""
    for face, (cx, cy, hx, hy) in (("S", ((x0 + x1) / 2, y0, (x1 - x0) / 2 + 0.05, 0.06)),
                                   ("N", ((x0 + x1) / 2, y1, (x1 - x0) / 2 + 0.05, 0.06)),
                                   ("W", (x0, (y0 + y1) / 2, 0.06, (y1 - y0) / 2)),
                                   ("E", (x1, (y0 + y1) / 2, 0.06, (y1 - y0) / 2))):
        if face in skip:
            continue
        o = _box((cx, cy, h / 2 - 0.04), (hx, hy, h / 2), color, jit=0.012, cuts=1, seed=seed, var=0.3, ao=0.4,
                 hue_shift=STONE_DARK)
        P._tint_up(o, MOSS, 0.5, 0.4, seed=seed)
        parts.append(o)
        seed += 1


def _quoins(parts, x: float, y: float, sx: int, sy: int, z0: float, z1: float, seed: int, color=SAND):
    z = z0
    k = 0
    while z < z1 - 0.1:
        h = min(0.32, z1 - z)
        lf, ls = (0.42, 0.22) if k % 2 == 0 else (0.22, 0.42)
        parts.append(_box((x - sx * lf / 2, y + sy * 0.03, z + h / 2), (lf / 2, 0.04, h / 2 * 0.93), color, jit=0.006,
                          seed=seed + k, top=0.2))
        parts.append(_box((x + sx * 0.03, y - sy * ls / 2, z + h / 2), (0.04, ls / 2, h / 2 * 0.93), color, jit=0.006,
                          seed=seed + 50 + k, top=0.2))
        z += h
        k += 1


def _chimney(parts, x: float, y: float, z0: float, z1: float, hw: float = 0.28, seed: int = 0, color=STONE_OLD):
    parts.append(_box((x, y, (z0 + z1) / 2), (hw, hw, (z1 - z0) / 2), color, jit=0.01, cuts=1, seed=seed, var=0.3, ao=0.2,
                      hue_shift=STONE_DARK))
    parts.append(_box((x, y, z1 + 0.05), (hw + 0.06, hw + 0.06, 0.05), STONE_DARK, seed=seed + 1, ao=0.0, top=0.3))
    parts.append(_box((x, y, z1 + 0.105), (hw - 0.07, hw - 0.07, 0.01), GAP, var=0.0, ao=0.0, top=0.0))
    return Vector((x, y, z1 + 0.2))


def _floor_line(parts, face: str, plane: float, a0: float, a1: float, z: float, color=TIMBER, seed: int = 0):
    parts.append(_beam(_pt(face, plane, a0 - 0.08, 0.06, z), _pt(face, plane, a1 + 0.08, 0.06, z), 0.09, color, seed=seed,
                       hd=0.08))


def _done(parts, name: str, markers=()):
    obj = L.join(parts, name)
    for m_name, loc in markers:
        L.marker(obj, m_name, tuple(loc))
    VIL.finish_stable(obj, name, CAT, 35.0, shift=False)
    return obj


def _lantern(parts, face: str, plane: float, a: float, z: float, seed: int = 0) -> Vector:
    """Wall lantern on a bracket (Phase-6 lantern) on any face; returns the light point below the glass."""
    sub = []
    lp = B6._wall_lantern(sub, Vector((0.0, -0.3, z)), 0.0, seed)
    m = Matrix.Translation(_pt(face, plane, a, 0.0, 0.0))
    rotz = {"S": 0.0, "E": 90.0, "N": 180.0, "W": -90.0}[face]
    m = m @ Matrix.Rotation(math.radians(rotz), 4, "Z")
    for o in sub:
        o.data.transform(m)
    parts += sub
    return m @ Vector((lp.x, lp.y, lp.z))


def _sign(parts, face: str, plane: float, a: float, z: float, out: float, motif: str, seed: int = 0):
    """Hanging inn sign on an iron bracket that sticks out of the wall; a painted motif on the board, a
    blank upper band for the Label3D. Returns the board-centre (label_board) point."""
    s = SIGN[face]
    p_wall = _pt(face, plane, a, 0.0, z)
    p_tip = _pt(face, plane, a, out, z)
    parts.append(_beam(p_wall, p_tip, 0.022, IRON, seed=seed))
    parts.append(_beam(_pt(face, plane, a, 0.0, z - 0.45), _pt(face, plane, a, out * 0.6, z - 0.01), 0.016, IRON, seed=seed + 1))
    bc = _pt(face, plane, a, out * 0.62, z - 0.42)
    bw, bh = 0.34, 0.3
    # board hangs across the bracket: its faces look along the wall (visible from both sides of the street)
    half = (0.025, bw, bh) if face in "EW" else (bw, 0.025, bh)
    half = (bw, 0.025, bh) if face in "EW" else (0.025, bw, bh)
    board = _box(bc, half, WOOD, jit=0.004, seed=seed + 2, var=0.15, ao=0.0, top=0.2)
    parts.append(board)
    for k in (-1, 1):
        parts.append(_beam(_pt(face, plane, a, out * 0.62 + k * bw * 0.8, z), bc + (Vector((0, k * bw * 0.8, bh)) if face in "SN"
                           else Vector((k * bw * 0.8, 0, bh))), 0.005, IRON, seed=seed + 3))
    # painted motif on both faces of the board
    nrm = Vector((0, 1, 0)) if face in "EW" else Vector((1, 0, 0))
    side = Vector((1, 0, 0)) if face in "EW" else Vector((0, 1, 0))
    for fs in (-1, 1):
        f0 = bc + nrm * fs * 0.028
        if motif == "elder":
            parts.append(_box(f0 + Vector((0, 0, -0.05)), tuple(abs(x) for x in (side * 0.006 + nrm * 0.004 + Vector((0, 0, 0.17)))),
                              L.hexc("#5A4A36"), ao=0.0))
            for k, (u, v) in enumerate(((-0.1, 0.02), (0.08, 0.06), (-0.02, 0.12), (0.12, -0.06), (-0.13, -0.08))):
                c = f0 + side * u + Vector((0, 0, v - 0.02))
                parts.append(_box(c, tuple(abs(x) for x in (side * 0.05 + nrm * 0.004 + Vector((0, 0, 0.03)))),
                                  ELDER_LEAF, ao=0.0, rot=(0, 0, 0)))
            for k in range(7):
                c = f0 + side * (-0.04 + 0.07 * math.cos(k * 0.9)) + Vector((0, 0, 0.06 + 0.05 * math.sin(k * 0.9)))
                parts.append(_box(c, tuple(abs(x) for x in (side * 0.022 + nrm * 0.005 + Vector((0, 0, 0.022)))),
                                  ELDER_FLOWER if k % 3 else ELDER_BERRY, ao=0.0, top=0.0))
        else:   # tree stump with an axe
            parts.append(_box(f0 + Vector((0, 0, -0.08)), tuple(abs(x) for x in (side * 0.12 + nrm * 0.004 + Vector((0, 0, 0.1)))),
                              L.hexc("#6E5640"), ao=0.0))
            parts.append(_box(f0 + Vector((0, 0, 0.03)), tuple(abs(x) for x in (side * 0.12 + nrm * 0.005 + Vector((0, 0, 0.02)))),
                              L.hexc("#B08C62"), ao=0.0))
            parts.append(_beam(f0 + side * 0.04 + Vector((0, 0, 0.04)), f0 + side * 0.16 + Vector((0, 0, 0.18)), 0.008,
                               L.hexc("#8A6A48"), seed=seed + 9))
        # blank band (lighter paint) at the top for the name
        parts.append(_box(f0 + Vector((0, 0, bh * 0.68)), tuple(abs(x) for x in (side * (bw - 0.03) + nrm * 0.003 + Vector((0, 0, 0.06)))),
                          L.hexc("#A89A7A"), ao=0.0, top=0.0))
    return bc + Vector((0, 0, bh * 0.68))


# ===================================================================================================
# St. Gallus
# ===================================================================================================

def church():
    random.seed(7000)
    L.reset(7000)
    parts = []
    x0, x1, y0, y1 = -3.4, 3.4, -5.4, 2.6     # nave (front wall y0)
    eave, ridge = 5.2, 8.8
    t0, t1, tx = 2.5, 5.9, 1.75               # tower (north end)
    t_top = 12.2
    win_y = (-3.6, -1.2, 1.2)
    sill, head = 2.4, 4.3
    # south front with door, oculus, gable
    gfn = _gable_fn(3.4, eave, ridge)
    _wall(parts, "S", y0, x0, x1, 0.0, ridge, [(0.0, 1.4, 0.0, 3.0)], top=gfn, seed=1, base=PLASTER, zr=(0.0, 6.0))
    for face, plane in (("E", x1), ("W", x0)):
        holes = [(y, 0.9, sill, head + 0.45) for y in win_y]
        _wall(parts, face, plane, y0 + 0.001, y1, 0.0, eave, holes, seed=2 if face == "E" else 3, base=PLASTER)
    for sx in (-1, 1):   # north wall beside the tower
        a0, a1 = (tx, x1) if sx > 0 else (x0, -tx)
        _wall(parts, "N", y1, a0, a1, 0.0, eave, seed=4 + sx, base=PLASTER)
    _plinth(parts, x0, x1, y0, y1, 0.45, seed=10, color=SAND_DARK)
    for sx in (-1, 1):
        _quoins(parts, sx * (x1 + 0.005), y0 - 0.005, sx, -1, 0.45, eave, 20 + sx * 30)
    # round-headed windows: arch stones over a square-cut opening + a round pane head
    markers = []
    k = 1
    for face, plane in (("E", x1), ("W", x0)):
        for i, y in enumerate(win_y):
            lp = _win(parts, face, plane, y, sill, 0.9, head + 0.3 - sill, seed=100 + k * 10, frame=L.hexc("#2A2B2E"),
                      stone=SAND, cross=True, recess=0.16)
            if i < 2:
                markers.append(("light_window_%d" % k, lp))
                k += 1
    # door: round-headed double door, sandstone surround, steps
    door = _door(parts, "S", y0, 0.0, 1.4, 3.0, seed=200, color=L.hexc("#3E2E22"), stone=SAND, arch=True, leaves=2)
    for i, (dy, hw, hz) in enumerate(((0.32, 1.4, 0.16), (0.62, 1.8, 0.08))):
        parts.append(_box((0.0, y0 - dy + 0.12, hz / 2 + (0.08 if i == 0 else 0.0)), (hw, 0.18, hz / 2 + (0.08 if i == 0 else 0.0)),
                          SAND_DARK, jit=0.01, seed=210 + i, top=0.3, ao=0.3))
    markers.append(("door_outside", Vector((0.0, -6.1, 0.0))))
    del door
    # oculus in the front gable
    ring = L.prim("torus", loc=(0.0, y0 - 0.04, 6.4), rot=(90, 0, 0), major_radius=0.55, minor_radius=0.09, major_segments=14,
                  minor_segments=4)
    parts.append(_box_paint(ring, SAND, ao=0.0, top=0.25))
    disc = L.prim("cyl", loc=(0.0, y0 + 0.02, 6.4), rot=(90, 0, 0), radius=0.5, depth=0.04, vertices=14)
    parts.append(_box_paint(disc, GLASS, var=0.2))
    for kk in range(2):
        parts.append(_box((0.0, y0 - 0.01, 6.4), (0.5, 0.01, 0.012), L.hexc("#2A2B2E"), rot=(0, 45 + 90 * kk, 0), ao=0.0))
    # lantern beside the door (the shadow light)
    lp = _lantern(parts, "S", y0, 1.25, 2.55, seed=220)
    markers.append(("light_door", lp))
    # nave roof (slate)
    _roof(parts, "y", 0.0, (y0 + y1) / 2 + 0.1, 3.4, (y1 - y0) / 2 + 0.1, eave, ridge, SLATE, over=0.32, row=0.36, seg=0.8,
          seed=300, mossy=0.25, end_over=0.25)
    # tower: walls, belfry openings, cornice, spire, ball and cross
    for face, plane, a0, a1 in (("S", t0, -tx, tx), ("N", t1, -tx, tx), ("E", tx, t0, t1), ("W", -tx, t0, t1)):
        holes = [((t0 + t1) / 2 if face in "EW" else 0.0, 0.7, 9.9, 11.3)]
        _wall(parts, face, plane, a0, a1, 0.0 if face != "S" else ridge - 0.6, t_top, holes, seed=40 + len(parts) % 7,
              base=PLASTER, zr=(0.0, t_top))
        c = (t0 + t1) / 2 if face in "EW" else 0.0
        for kk in range(4):   # louvres
            parts.append(_box(_pt(face, plane, c, -0.1, 10.1 + kk * 0.32), _half(face, 0.33, 0.02, 0.1), WOOD_OLD, ao=0.0,
                              rot=(30, 0, 0) if face in "SN" else (0, 30, 0)))
        parts.append(_box(_pt(face, plane, c, 0.02, 11.42), _half(face, 0.45, 0.05, 0.1), SAND, top=0.3))
        parts.append(_box(_pt(face, plane, c, 0.02, 9.78), _half(face, 0.45, 0.06, 0.06), SAND, top=0.3))
        # a small slit window low on the tower (south face shows above the nave roof only from far)
        if face in "EW":
            _win(parts, face, plane, c, 6.6, 0.3, 0.7, seed=60 + len(parts) % 9, frame=L.hexc("#2A2B2E"), stone=SAND, cross=False)
    for sx in (-1, 1):
        for sy in (t0, t1):
            _quoins(parts, sx * (tx + 0.005), sy + (-0.005 if sy == t0 else 0.005), sx, -1 if sy == t0 else 1,
                    0.3 if sy == t1 else ridge - 0.4, t_top, 400 + int(sy * 10) + sx)
    parts.append(_box((0.0, (t0 + t1) / 2, t_top + 0.12), (tx + 0.15, (t1 - t0) / 2 + 0.15, 0.12), SAND, top=0.3))
    spire = L.prim("cone", loc=(0.0, (t0 + t1) / 2, t_top + 0.24 + 1.925), vertices=8, radius1=tx + 0.08, radius2=0.03,
                   depth=3.85, rot=(0, 0, 22.5))
    L.subdivide(spire, 1)
    for v in spire.data.vertices:   # flare at the foot
        tt = (v.co.z - (t_top + 0.24)) / 4.0
        if tt < 0.25:
            s_ = 1.0 + 0.12 * (0.25 - tt) / 0.25
            v.co.x *= s_
            v.co.y = (t0 + t1) / 2 + (v.co.y - (t0 + t1) / 2) * s_
    P._paint_fn(spire, lambda co, vi: L.scale_c(L.mix(SLATE[0], SLATE[1], 0.5 + 0.5 * math.sin(co.z * 14.0)),
                                                0.95 + 0.08 * noise.noise(co * 2.0)))
    L.set_mat(spire, L.MAT_PAINTED)
    parts.append(spire)
    tip = t_top + 0.24 + 3.85
    parts.append(L.part("ico", BRASS, loc=(0.0, (t0 + t1) / 2, tip + 0.02), radius=0.1, subdivisions=1))
    B6._cross(parts, Vector((0.0, (t0 + t1) / 2, tip + 0.08)), 0.5, color=IRON, seed=450)
    _done(parts, "ph_bld_v_church", markers)


# ===================================================================================================
# Amtshaus
# ===================================================================================================

def office():
    random.seed(7010)
    L.reset(7010)
    parts = []
    x0, x1, y0, y1 = -4.25, 4.25, -3.2, 3.2
    g1, eave, ridge = 3.0, 5.7, 8.0
    jet = 0.18   # upper floor jetty over the south front
    win_x = (-3.3, -1.7, 1.7, 3.3)
    up_x = (-3.3, -1.7, 0.0, 1.7, 3.3)
    _wall(parts, "S", y0, x0, x1, 0.0, g1, [(0.0, 1.2, 0.0, 2.3)] + [(x, 0.75, 0.95, 2.15) for x in win_x], base=PLASTER_GREY,
          seed=1, stones=0.3)
    _wall(parts, "N", y1, x0, x1, 0.0, g1, [(x, 0.75, 0.95, 2.15) for x in (-1.7, 1.7)], base=PLASTER_GREY, seed=2, stones=0.3)
    for face, plane in (("E", x1), ("W", x0)):
        _wall(parts, face, plane, y0, y1, 0.0, g1, [(0.0, 0.75, 0.95, 2.15)], base=PLASTER_GREY, seed=3, stones=0.3)
    _plinth(parts, x0, x1, y0, y1, 0.5, seed=10)
    for sx in (-1, 1):
        for sy, yy in ((-1, y0), (1, y1)):
            _quoins(parts, sx * (x1 + 0.005), yy + sy * 0.005, sx, sy, 0.5, g1, 20 + sx * 7 + sy * 3)
    markers = []
    for i, x in enumerate(win_x):
        lp = _win(parts, "S", y0, x, 0.95, 0.75, 1.2, seed=100 + i * 10, stone=SAND, shutters=L.hexc("#4E5A48"))
        if x == 1.7:
            markers.append(("light_window_2", lp))
    for x in (-1.7, 1.7):
        _win(parts, "N", y1, x, 0.95, 0.75, 1.2, seed=150 + int(x * 10), stone=SAND)
    for face, plane in (("E", x1), ("W", x0)):
        _win(parts, face, plane, 0.0, 0.95, 0.75, 1.2, seed=170 + (1 if face == "E" else 2), stone=SAND)
    markers.append(("door_outside", _door(parts, "S", y0, 0.0, 1.2, 2.3, seed=200, color=L.hexc("#4A3424"), stone=SAND,
                                          step=SAND_DARK)))
    markers[-1] = ("door_outside", Vector((0.0, -3.6, 0.0)))
    # the parish shield over the door (painted, no text): a pale shield with a dark linden leaf
    sh = L.prim("cube", loc=(0.0, y0 - jet - 0.05, g1 + 0.55), scale=(0.28, 0.03, 0.34))
    for v in sh.data.vertices:
        if v.co.z < g1 + 0.4:
            v.co.x *= 0.45
    parts.append(_box_paint(sh, L.hexc("#B8AE94"), top=0.3))
    leaf = L.prim("sphere", loc=(0.0, y0 - jet - 0.09, g1 + 0.56), radius=1.0, scale=(0.11, 0.01, 0.15), segments=8, ring_count=5)
    parts.append(_box_paint(leaf, L.hexc("#4E6440")))
    # upper floor: half-timbered, jettied south
    ys = y0 - jet
    up_holes = [(x, 0.7, g1 + 0.75, g1 + 1.95) for x in up_x]
    _wall(parts, "S", ys, x0, x1, g1, eave, up_holes, base=PLASTER_PALE, seed=4, stones=0.0, dirty=0.0)
    _wall(parts, "N", y1, x0, x1, g1, eave, [(x, 0.7, g1 + 0.75, g1 + 1.95) for x in (-1.7, 1.7)], base=PLASTER_PALE, seed=5,
          stones=0.0, dirty=0.0)
    gf = _gable_fn(3.2 + jet / 2, eave, ridge - 0.1, -jet / 2)
    for face, plane in (("E", x1), ("W", x0)):
        _wall(parts, face, plane, ys, y1, g1, ridge, [(-jet / 2, 0.6, g1 + 0.8, g1 + 1.9), (-jet / 2, 0.5, eave + 0.5, eave + 1.3)],
              base=PLASTER_PALE, top=gf, seed=6, stones=0.0, dirty=0.0, zr=(g1, ridge))
        _timber(parts, face, plane, ys, y1, g1, eave, posts=(ys + 0.05, -1.4, 1.2, y1 - 0.05), seed=60 + SIGN[face],
                braces=((ys + 0.05, g1 + 0.1, -1.4, eave - 0.1), (y1 - 0.05, g1 + 0.1, 1.2, eave - 0.1)), top=None)
        _timber(parts, face, plane, ys, y1, eave, ridge, posts=(-jet / 2 - 0.45, -jet / 2 + 0.45), top=gf, seed=70)
    _floor_line(parts, "S", ys, x0, x1, g1 + 0.06, seed=80)
    posts = [x0 + 0.05] + [x + sa * 0.45 for x in up_x for sa in (-1, 1)] + [x1 - 0.05]
    _timber(parts, "S", ys, x0, x1, g1, eave, posts=posts, rails=[(g1 + 0.7, x0, x1)],
            braces=[(x0 + 0.05, g1 + 0.1, -3.75, g1 + 0.7), (x1 - 0.05, g1 + 0.1, 3.75, g1 + 0.7)], seed=90)
    _timber(parts, "N", y1, x0, x1, g1, eave, posts=[x0 + 0.05, -2.15, -1.25, 1.25, 2.15, x1 - 0.05], seed=95)
    for i, x in enumerate(up_x):
        lp = _win(parts, "S", ys, x, g1 + 0.75, 0.7, 1.2, seed=300 + i * 10, frame=WOOD_DARK)
        if x == 1.7:
            markers.append(("light_window_1", lp))
    for face, plane in (("E", x1), ("W", x0)):
        _win(parts, face, plane, -jet / 2, g1 + 0.8, 0.6, 1.1, seed=360 + SIGN[face])
    _roof(parts, "x", 0.0, -jet / 2, 3.2 + jet / 2, 4.25, eave, ridge, TILE, over=0.33, row=0.36, seg=0.8, seed=400, mossy=0.2, end_over=0.18)
    _chimney(parts, 2.6, 0.9, ridge - 1.8, ridge + 0.28, seed=410)
    _done(parts, "ph_bld_v_office", markers)


# ===================================================================================================
# Holderkrug
# ===================================================================================================

def inn():
    random.seed(7020)
    L.reset(7020)
    parts = []
    x0, x1, y0, y1 = -4.8, 4.8, -3.2, 3.2
    g1, eave, ridge = 2.8, 4.9, 8.0
    gx = (-3.4, -1.7, 1.7, 3.4)
    markers = []
    # ground floor: plaster over a rubble socle
    _wall(parts, "S", y0, x0, x1, 0.0, g1, [(0.0, 1.1, 0.0, 2.2)] + [(x, 0.8, 0.85, 2.05) for x in gx], base=PLASTER_OCHRE,
          seed=1, stones=0.25)
    _wall(parts, "N", y1, x0, x1, 0.0, eave, [(x, 0.7, 0.9, 2.0) for x in (-2.0, 2.0)], base=PLASTER_OCHRE, seed=2)
    for face, plane in (("E", x1), ("W", x0)):
        _wall(parts, face, plane, y0, y1, 0.0, eave, [(y, 0.7, 0.9, 2.0) for y in (-1.6, 1.4)] +
              [(y, 0.7, g1 + 0.6, g1 + 1.7) for y in (-1.6, 1.4)], base=PLASTER_OCHRE, seed=3)
        _timber(parts, face, plane, y0, y1, g1, eave, posts=(y0 + 0.05, -0.6, 0.4, y1 - 0.05),
                braces=((y0 + 0.05, g1 + 0.1, -0.6, eave - 0.1),), seed=40 + SIGN[face])
        _floor_line(parts, face, plane, y0, y1, g1 + 0.05, seed=45)
    _plinth(parts, x0, x1, y0, y1, 0.45, seed=10)
    for i, x in enumerate(gx):
        lp = _win(parts, "S", y0, x, 0.85, 0.8, 1.2, seed=100 + i * 10, shutters=L.hexc("#5A4A36"))
        if x in (-1.7, 1.7):
            markers.append(("light_window_%d" % (1 if x < 0 else 2), lp))
    for face, plane in (("E", x1), ("W", x0)):
        for y in (-1.6, 1.4):
            _win(parts, face, plane, y, 0.9, 0.7, 1.1, seed=150 + int(y * 10) + SIGN[face])
            _win(parts, face, plane, y, g1 + 0.6, 0.7, 1.1, seed=160 + int(y * 10) + SIGN[face])
    for x in (-2.0, 2.0):
        _win(parts, "N", y1, x, 0.9, 0.7, 1.1, seed=170 + int(x))
    _door(parts, "S", y0, 0.0, 1.1, 2.2, seed=200, color=L.hexc("#4A3424"), frame=TIMBER, step=STONE_PALE)
    markers.append(("door_outside", Vector((0.0, -3.6, 0.0))))
    # upper floor + the big south gable, half-timbered
    gf = _gable_fn(4.8, eave, ridge - 0.12)
    _wall(parts, "S", y0, x0, x1, g1, ridge, [(x, 0.75, g1 + 0.55, g1 + 1.65) for x in gx] + [(0.0, 0.6, eave + 0.35, eave + 1.25)],
          base=PLASTER_PALE, top=gf, seed=4, stones=0.0, dirty=0.0, zr=(g1, ridge))
    _wall(parts, "N", y1, x0, x1, eave, ridge, top=gf, base=PLASTER_PALE, seed=5, stones=0.0, dirty=0.0, zr=(g1, ridge))
    _floor_line(parts, "S", y0, x0, x1, g1 + 0.05, seed=50)
    posts = [x0 + 0.05] + [x + sa * 0.5 for x in gx for sa in (-1, 1)] + [x1 - 0.05]
    _timber(parts, "S", y0, x0, x1, g1, eave, posts=posts, rails=[(g1 + 0.5, x0, x1)],
            braces=[(x0 + 0.05, g1 + 0.1, -4.0, g1 + 0.5), (x1 - 0.05, g1 + 0.1, 4.0, g1 + 0.5),
                    (-1.2, g1 + 0.1, -0.2, eave - 0.1), (1.2, g1 + 0.1, 0.2, eave - 0.1)], seed=60)
    _timber(parts, "S", y0, x0, x1, eave, ridge, posts=(-2.4, -0.45, 0.45, 2.4), top=gf, seed=70,
            braces=((-2.4, eave + 0.1, -1.2, eave + 1.6), (2.4, eave + 0.1, 1.2, eave + 1.6)))
    for i, x in enumerate(gx):
        _win(parts, "S", y0, x, g1 + 0.55, 0.75, 1.1, seed=300 + i * 10)
    _win(parts, "S", y0, 0.0, eave + 0.35, 0.6, 0.9, seed=350)
    _roof(parts, "y", 0.0, 0.0, 4.8, 3.2, eave, ridge, TILE_OLD, over=0.38, row=0.36, seg=0.8, seed=400, mossy=0.3, end_over=0.35)
    _chimney(parts, -1.6, 1.8, ridge - 2.2, ridge + 0.32, seed=410)
    # the sign on its bracket, east of the door, and the lantern west of it
    st = _sign(parts, "S", y0, 1.2, 3.25, 0.95, "elder", seed=500)
    markers.append(("label_board", st))
    markers.append(("light_lantern", _lantern(parts, "S", y0, -1.0, 2.3, seed=520)))
    # bench under the west windows, a barrel by the door
    for k, (z, hy) in enumerate(((0.45, 0.17),)):
        parts.append(_box((-2.55, y0 - 0.32, z), (1.0, hy, 0.035), WOOD, jit=0.004, seed=530, top=0.3))
    for xx in (-3.4, -1.7):
        parts.append(_box((xx, y0 - 0.32, 0.22), (0.05, 0.14, 0.22), WOOD_DARK, seed=531))
    barrel = L.prim("cyl", loc=(1.0, y0 - 0.45, 0.42), radius=0.3, depth=0.84, vertices=12)
    for v in barrel.data.vertices:
        t = (v.co.z - 0.42) / 0.42
        k = 1.0 + 0.1 * (1.0 - t * t)
        v.co.x = 1.0 + (v.co.x - 1.0) * k
        v.co.y = (y0 - 0.45) + (v.co.y - (y0 - 0.45)) * k
    parts.append(_box_paint(barrel, WOOD, ao=0.3, var=0.2))
    for z in (0.12, 0.72):
        parts.append(L.part("torus", IRON, loc=(1.0, y0 - 0.45, z), major_radius=0.31, minor_radius=0.015, major_segments=12,
                            minor_segments=3))
    _done(parts, "ph_bld_v_inn", markers)


# ===================================================================================================
# Schmiede
# ===================================================================================================

def smithy():
    random.seed(7030)
    L.reset(7030)
    parts = []
    x0, x1, y0, y1 = -3.0, 3.0, -2.9, 2.9
    eave, ridge = 2.6, 4.9
    gf = _gable_fn(2.9, eave, ridge - 0.12)
    # rubble walls west, north, south; the east side stands open between two posts
    _wall(parts, "W", x0, y0, y1, 0.0, eave, base=PLASTER_DIRTY, seed=1, stones=0.55)
    # QA7 (G7 art, p7_07): the forge stands behind an open hatch in the south wall (towards the camera) –
    # the coals and their glow are seen from the Anger; before, the forge was hidden under the roof.
    _wall(parts, "S", y0, x0, x1 - 1.6, 0.0, eave, [(-1.0, 1.2, 0.92, 1.95)], base=PLASTER_DIRTY, seed=2, stones=0.55)
    _wall(parts, "N", y1, x0, x1 - 1.6, 0.0, eave, base=PLASTER_DIRTY, seed=3, stones=0.55)
    for face, plane in (("W", x0), ("E", x1 - 0.1)):   # board gables over the eave line
        for k in range(14):
            a = y0 + 0.21 + k * 0.42
            zt = eave + (ridge - 0.15 - eave) * max(0.0, 1.0 - abs(a) / 2.9)
            if zt - eave > 0.05:
                parts.append(_box(_pt(face, plane, a, -0.05, (eave + zt) / 2), _half(face, 0.2, 0.025, (zt - eave) / 2), WOOD_OLD,
                                  jit=0.004, seed=10 + k, var=0.2, ao=0.2))
        parts.append(_beam(_pt(face, plane, y0, 0.0, eave), _pt(face, plane, y1, 0.0, eave), 0.09, seed=20))
    # the forge hatch: a heavy frame, a sooty stone sill, one shutter swung open to the west
    for sa in (-1, 1):
        parts.append(_box(_pt("S", y0, -1.0 + sa * 0.63, 0.02, 1.43), _half("S", 0.05, 0.17, 0.55), WOOD_OLD, seed=25 + sa, ao=0.1))
    parts.append(_box(_pt("S", y0, -1.0, 0.02, 2.0), _half("S", 0.7, 0.17, 0.06), WOOD_OLD, seed=27, ao=0.1))
    parts.append(_box(_pt("S", y0, -1.0, 0.04, 0.89), _half("S", 0.72, 0.2, 0.04), STONE_DARK, jit=0.004, seed=28, top=0.3))
    parts.append(_box(_pt("S", y0, -1.0 - 1.28, 0.06, 1.43), _half("S", 0.55, 0.025, 0.5), WOOD_OLD, jit=0.004, seed=29, var=0.2,
                      ao=0.1, rot=(0, 0, -12)))
    for y in (y0 + 0.1, y1 - 0.1):   # corner posts of the open east side + header beam
        parts.append(_beam((x1 - 0.1, y, 0.0), (x1 - 0.1, y, eave), 0.1, seed=30))
        parts.append(_beam((x1 - 1.6, y, 0.0), (x1 - 1.6, y, eave), 0.09, seed=31))
        parts.append(_box((x1 - 0.85, y, 1.0), (0.75, 0.04, 0.5), WOOD_OLD, jit=0.005, seed=32, var=0.2))   # low board rail
    parts.append(_beam((x1 - 0.1, y0, eave - 0.08), (x1 - 0.1, y1, eave - 0.08), 0.1, seed=33))
    parts.append(_beam((x1 - 0.1, y0 + 0.1, eave - 0.6), (x1 - 0.1, y0 + 0.7, eave - 0.1), 0.06, seed=34))
    parts.append(_beam((x1 - 0.1, y1 - 0.1, eave - 0.6), (x1 - 0.1, y1 - 0.7, eave - 0.1), 0.06, seed=35))
    _plinth(parts, x0, x1 - 1.6, y0, y1, 0.35, seed=40, skip=("E",))
    # floor: packed earth with soot, a threshold beam
    parts.append(_box((0.0, 0.0, 0.01), (2.9, 2.8, 0.015), L.hexc("#4A3E34"), var=0.25, ao=0.0, top=0.0, cuts=2))
    _roof(parts, "x", 0.0, 0.0, 2.9, 3.0, eave, ridge, SHINGLE, over=0.35, row=0.3, seg=0.5, seed=50, mossy=0.35)
    # forge against the south wall behind the hatch: a stone hearth, a bed of glowing coals, the hood high
    # enough to leave the hatch open, the chimney through the roof
    fx, fy = -1.0, -2.2
    parts.append(_box((fx, fy, 0.42), (0.55, 0.4, 0.42), STONE_OLD, jit=0.012, cuts=1, seed=60, var=0.3, ao=0.3, hue_shift=STONE_DARK))
    parts.append(_box((fx, fy, 0.86), (0.45, 0.32, 0.025), COAL, var=0.3, ao=0.0, top=0.0))
    for k in range(14):
        c = Vector((fx + random.uniform(-0.36, 0.36), fy + random.uniform(-0.26, 0.26), 0.885))
        e = L.part("ico", L.mix(EMBER, COAL, random.uniform(0.0, 0.35)), loc=c, radius=random.uniform(0.04, 0.075), subdivisions=1,
                   scale=(1, 1, 0.45), paint_kw={"var": 0.2, "ao": 0.0, "top": 0.5})
        parts.append(e)
    hood = L.prim("cone", loc=(fx, fy + 0.05, 2.28), vertices=4, radius1=0.5, radius2=0.28, depth=0.5, rot=(0, 0, 45))
    parts.append(_box_paint(hood, STONE_OLD, ao=0.3, var=0.25))
    smoke = _chimney(parts, fx, fy, 2.5, 6.25, hw=0.28, seed=62)
    ember = Vector((fx, fy, 1.15))
    # bellows beside the forge
    bl = L.prim("cube", loc=(fx + 0.95, fy + 0.15, 0.75), scale=(0.22, 0.35, 0.08), rot=(10, 0, 0))
    parts.append(_box_paint(bl, P.LEATHER, ao=0.2, var=0.2))
    parts.append(_beam((fx + 0.95, fy + 0.5, 0.8), (fx + 0.95, fy + 0.9, 0.95), 0.025, WOOD, seed=63))
    # the anvil on its stump at the east opening
    ax_, ay = 2.25, 0.0
    stump = L.prim("cyl", loc=(ax_, ay, 0.28), radius=0.28, depth=0.56, vertices=10)
    L.jitter(stump, 0.015, 3.0, 64)
    parts.append(_box_paint(stump, WOOD, ao=0.3, var=0.25))
    parts.append(_box((ax_, ay, 0.56 + 0.04), (0.14, 0.12, 0.04), IRON, top=0.3))
    parts.append(_box((ax_, ay, 0.56 + 0.12), (0.08, 0.08, 0.06), IRON, top=0.3))
    face_ = _box((ax_, ay, 0.56 + 0.22), (0.13, 0.3, 0.05), IRON, top=0.6, hue_shift=L.hexc("#5E6166"))
    parts.append(face_)
    horn = L.prim("cone", loc=(ax_, ay - 0.42, 0.56 + 0.23), radius1=0.06, radius2=0.01, depth=0.26, vertices=6, rot=(90, 0, 0))
    parts.append(_box_paint(horn, IRON, top=0.5))
    anvil_top = Vector((ax_, ay, 0.56 + 0.27))
    # water trough and a rack with tongs and horseshoes on the north wall
    parts.append(_box((-0.6, y1 - 0.45, 0.3), (0.55, 0.22, 0.3), WOOD_OLD, jit=0.006, seed=66, ao=0.3))
    parts.append(_box((-0.6, y1 - 0.45, 0.56), (0.48, 0.16, 0.01), L.hexc("#2E3236"), var=0.1, ao=0.0, top=0.6))
    parts.append(_box((0.6, y1 - 0.2, 1.6), (0.7, 0.03, 0.05), WOOD_DARK, seed=67))
    for k in range(5):
        xx = 0.05 + k * 0.28
        parts.append(_beam((xx, y1 - 0.24, 1.6), (xx + 0.02, y1 - 0.25, 1.05), 0.012, IRON, seed=68 + k))
    for k in range(3):
        parts.append(L.part("torus", IRON, loc=(1.0 + k * 0.22 - 0.9, y1 - 0.22, 2.0), rot=(90, 0, 0), major_radius=0.07,
                            minor_radius=0.015, major_segments=8, minor_segments=3))
    markers = [("anvil", anvil_top), ("counter", Vector((3.2, 0.0, 0.0))), ("light_ember", ember), ("smoke", smoke),
               ("door_outside", Vector((3.4, 0.0, 0.0)))]
    _done(parts, "ph_bld_v_smithy", markers)


# ===================================================================================================
# Kraemerladen
# ===================================================================================================

def shop():
    random.seed(7040)
    L.reset(7040)
    parts = []
    x0, x1, y0, y1 = -2.9, 2.9, -2.3, 2.3
    eave, ridge = 3.3, 5.5
    gf = _gable_fn(2.3, eave, ridge - 0.12)
    win = (0.0, 1.6, 0.95, 2.05)   # the shop window in the east wall
    _wall(parts, "E", x1, y0, y1, 0.0, ridge, [win], top=gf, base=PLASTER_ROSE, seed=1, zr=(0.0, ridge))
    _wall(parts, "W", x0, y0, y1, 0.0, ridge, [(0.0, 0.7, 1.0, 2.0)], top=gf, base=PLASTER_ROSE, seed=2, zr=(0.0, ridge))
    _wall(parts, "S", y0, x0, x1, 0.0, eave, [(-1.3, 0.95, 0.0, 2.1), (1.0, 0.75, 1.0, 2.1)], base=PLASTER_ROSE, seed=3)
    _wall(parts, "N", y1, x0, x1, 0.0, eave, [(0.0, 0.7, 1.0, 2.0)], base=PLASTER_ROSE, seed=4)
    for face, plane in (("E", x1), ("W", x0)):
        _timber(parts, face, plane, y0, y1, eave, ridge, posts=(-0.6, 0.6), top=gf, seed=10 + SIGN[face])
        _floor_line(parts, face, plane, y0, y1, eave, seed=12)
    _plinth(parts, x0, x1, y0, y1, 0.4, seed=15)
    for sx in (-1, 1):
        for sy, yy in ((-1, y0), (1, y1)):
            _quoins(parts, sx * (x1 + 0.005), yy + sy * 0.005, sx, sy, 0.4, eave, 20 + sx * 5 + sy, color=SAND_DARK)
    markers = []
    markers.append(("door_outside", _door(parts, "S", y0, -1.3, 0.95, 2.1, seed=30, color=L.hexc("#5A4030"), step=STONE_PALE)))
    _win(parts, "S", y0, 1.0, 1.0, 0.75, 1.1, seed=40, shutters=L.hexc("#6A5A3E"))
    _win(parts, "N", y1, 0.0, 1.0, 0.7, 1.0, seed=41)
    _win(parts, "W", x0, 0.0, 1.0, 0.7, 1.0, seed=42)
    _win(parts, "E", x1, 0.0, eave + 0.4, 0.6, 0.9, seed=43)
    lp = _win(parts, "S", y0, 1.0, 1.0, 0.75, 1.1, seed=44)
    markers.append(("light_window_1", lp))
    # the shop window: dark interior, a shelf of goods behind, the folding shutter
    wy0, wy1 = -0.8, 0.8
    parts.append(_box((x1 - 0.55, 0.0, 1.5), (0.02, 0.8, 0.55), L.hexc("#2A2420"), var=0.1, ao=0.0, top=0.0))
    for z in (1.15, 1.6):
        parts.append(_box((x1 - 0.45, 0.0, z), (0.12, 0.78, 0.015), WOOD_DARK, ao=0.0))
        for k in range(7):
            col = random.choice((L.hexc("#8A6A48"), L.hexc("#7A7A5A"), L.hexc("#9C8A62"), L.hexc("#6E5A7A"), L.hexc("#8C5A44"),
                                 L.hexc("#B8AE94")))
            y = wy0 + 0.12 + k * 0.22
            if random.random() < 0.5:
                o = L.prim("cyl", loc=(x1 - 0.45, y, z + 0.1), radius=0.06, depth=0.18, vertices=8)
            else:
                o = L.prim("cube", loc=(x1 - 0.45, y, z + 0.08), scale=(0.07, 0.08, 0.07))
            parts.append(_box_paint(o, col, ao=0.2, var=0.1, top=0.3))
    for sa in (-1, 1):    # window frame posts
        parts.append(_box((x1 + 0.02, sa * 0.82, 1.5), (0.05, 0.05, 0.58), WOOD_DARK, ao=0.0))
    parts.append(_box((x1 + 0.02, 0.0, 2.08), (0.06, 0.9, 0.05), WOOD_DARK, ao=0.0))
    # lower shutter leaf folded down = the counter board on two chains; upper leaf propped up as an awning
    parts.append(_box((x1 + 0.3, 0.0, 0.95), (0.3, 0.82, 0.03), L.hexc("#6A5A3E"), jit=0.004, seed=50, top=0.35))
    for sa in (-1, 1):
        parts.append(_beam((x1 + 0.58, sa * 0.78, 0.97), (x1 + 0.05, sa * 0.78, 1.55), 0.008, IRON, seed=51))
    aw = L.prim("cube", scale=(0.3, 0.84, 0.025))
    aw.data.transform(Matrix.Translation((x1 + 0.28, 0.0, 2.2)) @ Matrix.Rotation(math.radians(-20), 4, "Y"))
    parts.append(_box_paint(aw, L.hexc("#6A5A3E"), top=0.3, var=0.2))
    for sa in (-1, 1):
        parts.append(_beam((x1 + 0.55, sa * 0.78, 2.1), (x1 + 0.05, sa * 0.78, 1.7), 0.015, WOOD, seed=52))
    # a few goods on the counter board: a basket, a jar, a bundle of candles
    bk = L.prim("cyl", loc=(x1 + 0.3, -0.45, 1.05), radius=0.13, depth=0.14, vertices=10)
    parts.append(_box_paint(bk, L.hexc("#8E7650"), ao=0.3, var=0.25))
    parts.append(_box_paint(L.prim("cyl", loc=(x1 + 0.28, 0.2, 1.06), radius=0.06, depth=0.16, vertices=8), L.hexc("#7A7A5A"), top=0.4))
    for k in range(4):
        parts.append(_beam((x1 + 0.25 + k * 0.03, 0.55, 0.98), (x1 + 0.25 + k * 0.03, 0.55, 1.22), 0.012, L.hexc("#D8CCA8"), seed=53))
    # a small hanging sign over the window (painted scales, no text)
    sg = _box((x1 + 0.04, -1.15, 2.45), (0.03, 0.22, 0.16), WOOD, jit=0.003, seed=61, top=0.2)
    parts.append(sg)
    parts.append(_beam((x1 + 0.08, -1.27, 2.45), (x1 + 0.08, -1.03, 2.45), 0.01, BRASS, seed=62))
    parts.append(_beam((x1 + 0.08, -1.15, 2.55), (x1 + 0.08, -1.15, 2.37), 0.008, BRASS, seed=63))
    _roof(parts, "x", 0.0, 0.0, 2.3, 2.9, eave, ridge, TILE, over=0.35, row=0.34, seg=0.7, seed=70, mossy=0.25)
    _chimney(parts, -0.9, -0.3, ridge - 1.5, ridge + 0.36, hw=0.22, seed=80)
    markers.append(("counter", Vector((3.7, 0.0, 0.0))))
    _done(parts, "ph_bld_v_shop", markers)


# ===================================================================================================
# Wundarzthaus
# ===================================================================================================

def surgery():
    random.seed(7050)
    L.reset(7050)
    parts = []
    x0, x1, y0, y1 = -3.2, 3.2, -3.8, 3.8
    g1, eave, ridge = 2.9, 5.3, 7.5
    gf = _gable_fn(3.2, eave, ridge - 0.12)
    wy = (-2.2, 2.2)
    uy = (-2.4, 0.0, 2.4)
    _wall(parts, "W", x0, y0, y1, 0.0, eave, [(0.0, 1.05, 0.0, 2.25)] + [(y, 0.75, 0.95, 2.1) for y in wy] +
          [(y, 0.7, g1 + 0.6, g1 + 1.75) for y in uy], base=PLASTER_PALE, seed=1)
    _wall(parts, "E", x1, y0, y1, 0.0, eave, [(y, 0.75, 0.95, 2.1) for y in wy] + [(y, 0.7, g1 + 0.6, g1 + 1.75) for y in uy],
          base=PLASTER_PALE, seed=2)
    _wall(parts, "S", y0, x0, x1, 0.0, ridge, [(x, 0.75, 0.95, 2.1) for x in (-1.3, 1.3)] +
          [(x, 0.7, g1 + 0.6, g1 + 1.75) for x in (-1.3, 1.3)] + [(0.0, 0.6, eave + 0.4, eave + 1.3)], top=gf, base=PLASTER_PALE,
          seed=3, zr=(0.0, ridge))
    _wall(parts, "N", y1, x0, x1, 0.0, ridge, [(x, 0.75, 0.95, 2.1) for x in (-1.3, 1.3)], top=gf, base=PLASTER_PALE, seed=4,
          zr=(0.0, ridge))
    _plinth(parts, x0, x1, y0, y1, 0.45, seed=10, color=SAND_DARK)
    for sx in (-1, 1):
        for sy, yy in ((-1, y0), (1, y1)):
            _quoins(parts, sx * (x1 + 0.005), yy + sy * 0.005, sx, sy, 0.45, eave, 20 + sx * 5 + sy)
    # a stone band between the floors
    for face, plane, a0, a1 in (("W", x0, y0, y1), ("E", x1, y0, y1), ("S", y0, x0, x1), ("N", y1, x0, x1)):
        parts.append(_box(_pt(face, plane, (a0 + a1) / 2, 0.03, g1), _half(face, (a1 - a0) / 2 + 0.06, 0.05, 0.07), SAND, top=0.3))
    markers = []
    for y in wy:
        _win(parts, "W", x0, y, 0.95, 0.75, 1.15, seed=100 + int(y * 10), stone=SAND, shutters=L.hexc("#5A5E58"))
        _win(parts, "E", x1, y, 0.95, 0.75, 1.15, seed=120 + int(y * 10), stone=SAND)
    for i, y in enumerate(uy):
        lp = _win(parts, "W", x0, y, g1 + 0.6, 0.7, 1.15, seed=140 + i)
        if y == 2.4:
            markers.append(("light_window_1", lp))
        _win(parts, "E", x1, y, g1 + 0.6, 0.7, 1.15, seed=150 + i)
    for x in (-1.3, 1.3):
        lp = _win(parts, "S", y0, x, 0.95, 0.75, 1.15, seed=160 + int(x * 10), stone=SAND, shutters=L.hexc("#5A5E58"))
        if x > 0:
            markers.append(("light_window_2", lp))
        _win(parts, "S", y0, x, g1 + 0.6, 0.7, 1.15, seed=170 + int(x * 10))
        _win(parts, "N", y1, x, 0.95, 0.75, 1.15, seed=180 + int(x * 10), stone=SAND)
    _win(parts, "S", y0, 0.0, eave + 0.4, 0.6, 0.9, seed=190)
    _door(parts, "W", x0, 0.0, 1.05, 2.25, seed=200, color=L.hexc("#3A3430"), stone=SAND, step=SAND_DARK)
    markers.append(("door_outside", Vector((-3.6, 0.0, 0.0))))
    # brass plate beside the door (blank, polished)
    parts.append(_box((x0 - 0.04, -0.85, 1.45), (0.012, 0.18, 0.12), BRASS, top=0.6, var=0.08, ao=0.0))
    parts.append(_box((x0 - 0.03, -0.85, 1.45), (0.008, 0.2, 0.14), L.hexc("#4A3A2C"), ao=0.0))
    # bell pull
    parts.append(_beam((x0 - 0.06, 0.75, 2.0), (x0 - 0.06, 0.75, 1.35), 0.008, IRON, seed=210))
    parts.append(L.part("torus", BRASS, loc=(x0 - 0.06, 0.75, 1.3), rot=(0, 90, 0), major_radius=0.04, minor_radius=0.01,
                        major_segments=8, minor_segments=3))
    _roof(parts, "y", 0.0, 0.0, 3.2, 3.8, eave, ridge, SLATE, over=0.35, row=0.35, seg=0.75, seed=300, mossy=0.15)
    _chimney(parts, 1.2, 1.6, ridge - 1.4, ridge + 0.36, hw=0.24, seed=310, color=SAND_DARK)
    _done(parts, "ph_bld_v_surgery", markers)


# ===================================================================================================
# Remise (coach house)
# ===================================================================================================

def _board_wall(parts, face: str, plane: float, a0: float, a1: float, z0: float, top, seed: int, holes=(), color=WOOD_OLD):
    w = 0.3
    a = a0
    k = 0
    while a < a1 - 0.02:
        b = min(a + w, a1)
        c = (a + b) / 2
        if not any(h0 - 0.01 < c < h1 + 0.01 for h0, h1 in holes):
            zt = top(c) if callable(top) else top
            parts.append(_box(_pt(face, plane, c, -0.03, (z0 + zt) / 2), _half(face, (b - a) / 2 - 0.006, 0.025, (zt - z0) / 2),
                              L.scale_c(color, random.uniform(0.82, 1.12)), jit=0.004, seed=seed + k, var=0.2, ao=0.25,
                              hue_shift=WOOD_DARK))
        a = b
        k += 1


def remise():
    random.seed(7060)
    L.reset(7060)
    parts = []
    x0, x1, y0, y1 = -3.4, 3.4, -2.3, 2.3
    eave, ridge = 2.8, 4.75
    gf = _gable_fn(2.3, eave, ridge - 0.12)
    _plinth(parts, x0, x1, y0, y1, 0.35, seed=1, skip=())
    gate = (-1.3, 1.3)
    _board_wall(parts, "S", y0, x0, x1, 0.3, eave, 10)
    _board_wall(parts, "N", y1, x0, x1, 0.3, eave, 40)
    _board_wall(parts, "E", x1, y0, y1, 0.3, gf, 70)
    _board_wall(parts, "W", x0, y0, y1, 0.3, gf, 100, holes=[gate])
    for face, plane, a0, a1 in (("S", y0, x0, x1), ("N", y1, x0, x1), ("E", x1, y0, y1), ("W", x0, y0, y1)):
        for z in (0.35, eave - 0.06):
            parts.append(_beam(_pt(face, plane, a0, 0.03, z), _pt(face, plane, a1, 0.03, z), 0.07, seed=130))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_beam((sx * (x1 - 0.02), sy * (y1 - 0.02), 0.3), (sx * (x1 - 0.02), sy * (y1 - 0.02), eave), 0.09, seed=131))
    # the double gate west: one leaf shut, one standing open (swung out to the south-west)
    for leaf in (0, 1):
        for k in range(5):
            a = -1.3 + 0.13 + k * 0.26 if leaf == 0 else 0.13 + k * 0.26
            if leaf == 0:
                parts.append(_box((x0 - 0.06, a, 1.3), (0.03, 0.125, 1.2), L.scale_c(WOOD, random.uniform(0.85, 1.1)), jit=0.004,
                                  seed=150 + k, var=0.2, ao=0.3))
            else:
                ang = math.radians(-30)
                hinge = Vector((x0 - 0.06, 1.3, 0.0))
                off = Vector((math.sin(ang) * (1.3 - a), -math.cos(ang) * (1.3 - a), 0.0))
                o = L.prim("cube", scale=(0.03, 0.125, 1.2))
                o.data.transform(Matrix.Translation(hinge + Vector((-(1.3 - a) * math.sin(-ang), -(1.3 - a) * math.cos(ang), 1.3)))
                                 @ Matrix.Rotation(ang, 4, "Z"))
                del off
                parts.append(_box_paint(o, L.scale_c(WOOD, random.uniform(0.85, 1.1)), ao=0.3, var=0.2))
        if leaf == 0:
            parts.append(_beam((x0 - 0.1, -1.25, 0.5), (x0 - 0.1, -0.05, 2.2), 0.04, WOOD_DARK, seed=160))
    parts.append(_beam((x0 - 0.04, gate[0], 2.55), (x0 - 0.04, gate[1], 2.55), 0.08, seed=161))
    # dark interior seen through the open gate, straw on the floor
    parts.append(_box((0.0, 0.0, 0.02), (3.3, 2.2, 0.02), L.hexc("#6E6248"), var=0.3, ao=0.0, top=0.0, cuts=1))
    parts.append(_box((x1 - 0.1, 0.0, 1.5), (0.02, 2.2, 1.2), L.hexc("#2A2420"), var=0.1, ao=0.0, top=0.0))
    _roof(parts, "x", 0.0, 0.0, 2.3, 3.4, eave, ridge, SHINGLE, over=0.35, row=0.3, seg=0.5, seed=200, mossy=0.4)
    markers = [("door_outside", Vector((-3.9, 0.0, 0.0)))]
    _done(parts, "ph_bld_v_remise", markers)


# ===================================================================================================
# Cottages (door north) and backdrop houses (door south)
# ===================================================================================================

def _cottage(name: str, thatch: bool, seed: int):
    random.seed(seed)
    L.reset(seed)
    parts = []
    x0, x1, y0, y1 = -2.7, 2.7, -2.05, 2.05
    eave, ridge = 2.35, 4.22 if thatch else 4.3
    gf = _gable_fn(2.05, eave, ridge - 0.15)
    base = PLASTER if thatch else PLASTER_PALE
    _wall(parts, "N", y1, x0, x1, 0.0, eave, [(0.0, 0.9, 0.0, 1.95), (1.6, 0.6, 0.9, 1.7)], base=base, seed=1, stones=0.35 if thatch else 0.1)
    _wall(parts, "S", y0, x0, x1, 0.0, eave, [(-1.3, 0.65, 0.85, 1.7), (1.3, 0.65, 0.85, 1.7)], base=base, seed=2,
          stones=0.35 if thatch else 0.1)
    for face, plane in (("E", x1), ("W", x0)):
        _wall(parts, face, plane, y0, y1, 0.0, ridge, [(0.0, 0.5, eave + 0.2, eave + 0.85)], top=gf, base=base, seed=3 + SIGN[face],
              zr=(0.0, ridge), stones=0.35 if thatch else 0.1)
    _plinth(parts, x0, x1, y0, y1, 0.35, seed=10)
    if not thatch:   # half-timbering on the Dorn cottage
        for face, plane, a0, a1 in (("S", y0, x0, x1), ("N", y1, x0, x1)):
            posts = (x0 + 0.05, -1.75, -0.85, 0.85, 1.75, x1 - 0.05) if face == "S" else (x0 + 0.05, -0.5, 0.5, x1 - 0.05)
            _timber(parts, face, plane, a0, a1, 0.3, eave, posts=posts, rails=[(0.75, x0, x1)] if face == "S" else [],
                    braces=[(x0 + 0.05, 0.4, -1.75, eave - 0.1), (x1 - 0.05, 0.4, 1.75, eave - 0.1)] if face == "S" else [],
                    seed=20 + SIGN[face])
        for face, plane in (("E", x1), ("W", x0)):
            _timber(parts, face, plane, y0, y1, 0.3, eave, posts=(y0 + 0.05, 0.0, y1 - 0.05), seed=30)
            _timber(parts, face, plane, y0, y1, eave, ridge, posts=(-0.35, 0.35), top=gf, seed=31)
    markers = []
    for x in (-1.3, 1.3):
        lp = _win(parts, "S", y0, x, 0.85, 0.65, 0.85, seed=40 + int(x * 10), shutters=L.hexc("#5A5E48") if thatch else L.hexc("#6A5A3E"))
        if x > 0:
            markers.append(("light_window", lp))
    _win(parts, "N", y1, 1.6, 0.9, 0.6, 0.8, seed=45)
    for face, plane in (("E", x1), ("W", x0)):
        _win(parts, face, plane, 0.0, eave + 0.2, 0.5, 0.65, seed=46 + SIGN[face], cross=False)
    _door(parts, "N", y1, 0.0, 0.9, 1.95, seed=50, color=L.hexc("#5A4434"), step=STONE_PALE)
    markers.append(("door_outside", Vector((0.0, 2.5, 0.0))))
    markers.append(("ribbon", Vector((0.0, y1 + 0.08, 2.08))))
    if thatch:
        _roof(parts, "x", 0.0, 0.0, 2.05, 2.7, eave, ridge, THATCH, over=0.45, row=0.4, seg=0.9, seed=60, mossy=0.45, lift=0.12,
              thick=0.16, thatch=True, end_over=0.3)
        # thatch gable edges: rounded rolls
        pitch = math.atan2(ridge - eave, 2.05)
        for xe in (-3.0, 3.0):
            for s in (-1, 1):
                p0 = Vector((xe, 0.0, ridge + 0.08))
                p1 = Vector((xe, s * (2.05 + 0.45), eave - 0.45 * math.tan(pitch) + 0.05))
                parts.append(_box_paint(L.tube(p0, p1, 0.11, 6), THATCH[1], var=0.2))
    else:
        _roof(parts, "x", 0.0, 0.0, 2.05, 2.7, eave, ridge, SHINGLE, over=0.35, row=0.3, seg=0.65, seed=60, mossy=0.35)
    _chimney(parts, -1.4, 0.4, ridge - 1.0, ridge + 0.5, hw=0.2, seed=70)
    _done(parts, name, markers)


def cottage_a():
    _cottage("ph_bld_v_cottage_a", True, 7070)


def cottage_b():
    _cottage("ph_bld_v_cottage_b", False, 7080)


def _house(name: str, seed: int, base, roof_pal, gable_front: bool, w: float, d: float, eave: float, ridge: float,
           upper_timber: bool = True, sign: str = ""):
    random.seed(seed)
    L.reset(seed)
    parts = []
    x0, x1, y0, y1 = -w / 2, w / 2, -d / 2, d / 2
    g1 = 2.6
    markers = []
    if gable_front:
        gf = _gable_fn(w / 2, eave, ridge - 0.12)
        wx = (-w / 4, w / 4)
        _wall(parts, "S", y0, x0, x1, 0.0, ridge, [(-w / 4, 0.95, 0.0, 2.05), (w / 4, 0.7, 0.85, 1.95)] +
              [(x, 0.65, g1 + 0.5, g1 + 1.5) for x in wx] + [(0.0, 0.5, eave + 0.3, eave + 1.0)], top=gf, base=base, seed=1,
              zr=(0.0, ridge))
        _wall(parts, "N", y1, x0, x1, 0.0, ridge, top=gf, base=base, seed=2, zr=(0.0, ridge))
        for face, plane in (("E", x1), ("W", x0)):
            _wall(parts, face, plane, y0, y1, 0.0, eave, [(0.0, 0.65, 0.9, 1.85)], base=base, seed=3)
        if upper_timber:
            _timber(parts, "S", y0, x0, x1, g1, eave, posts=[x0 + 0.05] + [x + sa * 0.42 for x in wx for sa in (-1, 1)] + [x1 - 0.05],
                    braces=[(x0 + 0.05, g1 + 0.1, wx[0] - 0.42, eave - 0.1), (x1 - 0.05, g1 + 0.1, wx[1] + 0.42, eave - 0.1)], seed=10)
            _timber(parts, "S", y0, x0, x1, eave, ridge, posts=(-0.35, 0.35), top=gf, seed=11)
            _floor_line(parts, "S", y0, x0, x1, g1, seed=12)
        lp = _win(parts, "S", y0, w / 4, 0.85, 0.7, 1.1, seed=20, shutters=L.hexc("#5A5E48"))
        markers.append(("light_window", lp))
        for x in wx:
            _win(parts, "S", y0, x, g1 + 0.5, 0.65, 1.0, seed=22 + int(x * 10))
        _win(parts, "S", y0, 0.0, eave + 0.3, 0.5, 0.7, seed=25)
        for face, plane in (("E", x1), ("W", x0)):
            _win(parts, face, plane, 0.0, 0.9, 0.65, 0.95, seed=26 + SIGN[face])
        _door(parts, "S", y0, -w / 4, 0.95, 2.05, seed=30, color=L.hexc("#5A4434"), step=STONE_PALE)
        markers.append(("door_outside", Vector((-w / 4, y0 - 0.5, 0.0))))
        markers.append(("ribbon", Vector((-w / 4, y0 - 0.08, 2.18))))
        _roof(parts, "y", 0.0, 0.0, w / 2, d / 2, eave, ridge, roof_pal, over=0.35, row=0.35, seg=0.75, seed=40, mossy=0.3)
        _chimney(parts, w / 4 - 0.2, d / 4, ridge - 1.2, ridge + 0.36, hw=0.22, seed=50)
    else:
        gf = _gable_fn(d / 2, eave, ridge - 0.12)
        wx = (-w / 3, w / 3)
        _wall(parts, "S", y0, x0, x1, 0.0, g1, [(0.0, 0.95, 0.0, 2.05)] + [(x, 0.7, 0.85, 1.95) for x in wx], base=base, seed=1)
        _wall(parts, "S", y0, x0, x1, g1, eave, [(x, 0.65, g1 + 0.45, g1 + 1.45) for x in (-w / 3, 0.0, w / 3)],
              base=PLASTER_PALE if upper_timber else base, seed=2, stones=0.0)
        _wall(parts, "N", y1, x0, x1, 0.0, eave, base=base, seed=3)
        for face, plane in (("E", x1), ("W", x0)):
            _wall(parts, face, plane, y0, y1, 0.0, ridge, [(0.0, 0.6, g1 + 0.5, g1 + 1.4)], top=gf, base=base, seed=4,
                  zr=(0.0, ridge))
        if upper_timber:
            _timber(parts, "S", y0, x0, x1, g1, eave,
                    posts=[x0 + 0.05] + [x + sa * 0.42 for x in (-w / 3, 0.0, w / 3) for sa in (-1, 1)] + [x1 - 0.05],
                    rails=[(g1 + 0.45, x0, x1)], seed=10)
            for face, plane in (("E", x1), ("W", x0)):
                _timber(parts, face, plane, y0, y1, g1, eave, posts=(y0 + 0.05, y1 - 0.05), seed=13)
                _timber(parts, face, plane, y0, y1, eave, ridge, posts=(-0.3, 0.3), top=gf, seed=14)
        _floor_line(parts, "S", y0, x0, x1, g1, seed=12)
        for i, x in enumerate(wx):
            lp = _win(parts, "S", y0, x, 0.85, 0.7, 1.1, seed=20 + i, shutters=L.hexc("#4E5A48"))
            if i == 1:
                markers.append(("light_window", lp))
        for x in (-w / 3, 0.0, w / 3):
            _win(parts, "S", y0, x, g1 + 0.45, 0.65, 1.0, seed=24 + int(x * 10))
        for face, plane in (("E", x1), ("W", x0)):
            _win(parts, face, plane, 0.0, g1 + 0.5, 0.6, 0.9, seed=28 + SIGN[face])
        _door(parts, "S", y0, 0.0, 0.95, 2.05, seed=30, color=L.hexc("#4A3828"), step=STONE_PALE)
        markers.append(("door_outside", Vector((0.0, y0 - 0.5, 0.0))))
        markers.append(("ribbon", Vector((0.0, y0 - 0.08, 2.18))))
        _roof(parts, "x", 0.0, 0.0, d / 2, w / 2, eave, ridge, roof_pal, over=0.35, row=0.35, seg=0.75, seed=40, mossy=0.3)
        _chimney(parts, -w / 4, 0.4, ridge - 1.2, ridge + 0.36, hw=0.22, seed=50)
    _plinth(parts, x0, x1, y0, y1, 0.4, seed=60)
    if sign:
        st = _sign(parts, "E", x1, y0 + 0.5, 3.2, 0.9, sign, seed=70)
        markers.append(("label_board", st))
    _done(parts, name, markers)


def house_a():
    _house("ph_bld_v_house_a", 7090, PLASTER_OCHRE, TILE, False, 6.6, 5.0, 4.5, 6.5)


def house_b():
    _house("ph_bld_v_house_b", 7100, PLASTER_GREY, SHINGLE, False, 6.0, 4.8, 4.4, 6.5)


def house_c():
    _house("ph_bld_v_house_c", 7110, PLASTER_ROSE, TILE_OLD, True, 5.2, 6.0, 4.3, 6.5)


def inn2():
    _house("ph_bld_v_inn2", 7120, PLASTER_DIRTY, SHINGLE, False, 7.0, 5.0, 4.0, 6.5, upper_timber=True, sign="stump")


ASSETS = [church, office, inn, smithy, shop, surgery, remise, cottage_a, cottage_b, house_a, house_b, house_c, inn2]


def build(names=None):
    """Build all buildings, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
