"""Phase-5 workshop stations and workyard props (docs/PHASE5_DESIGN.md sections 2.1, 4.1, 8).

  ph_bld_mason_bench           stonemason's bench (footprint 2.6 x 1.6 m): a heavy timber trestle with a
                               half-worked block, mallet (Klupfel) and chisels; at the east end a rack
                               for three finished stones (markers stone_slot_1..3), marker `use`
  ph_bld_loom                  small treadle loom under a lean-to roof (2.2 x 1.8 m), half-woven cloth
  ph_bld_forge                 masonry forge with hood and chimney, anvil on a stump, quench trough,
                               bellows (2.6 x 2.0 m, worked from the west); markers light_ember, smoke
  ph_prop_charcoal_kiln        charcoal kiln (Meiler, 1.4 m): cold, sod-covered, marker smoke
  ph_prop_charcoal_kiln_burning the same kiln charring: blackened, glowing vents, marker smoke
  ph_prop_build_site           staked-out building plot (2.4 x 1.8 m, scaled to the footprint in X/Z):
                               pegs, string, a small board, an overgrown stone slab; pegs, string and
                               board are the child mesh `stakes`
  ph_prop_build_site_slab      the overgrown empty stone slab alone (Am Bruch, Lorenz' old workplace)

Markers (glTF empties): stone_slot_n = ground point under a finished stone, rotated so that the
stone leans back 6 degrees against the rack (local +Z = stone front); use = where the player stands;
light_ember = above the forge coals (1 omni, no shadow); smoke = chimney / kiln top.
The embers are vertex colour only (#E07A3A, mat_painted) - no emissive material, the light comes
from the omni at light_ember.
Front = -Y (Blender) = +Z (Godot), pivot bottom centre, 1 unit = 1 m, shared materials only.
Run:  python tools/blender/build_all.py asset_stations_phase5
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
import asset_env_phase3 as E
import asset_stones_phase5 as S
from asset_carter import _thicken

WOOD = P.WOOD
WOOD_DARK = P.WOOD_DARK
WOOD_OLD = P.WOOD_OLD
WOOD_FRESH = P.WOOD_FRESH
END_GRAIN = P.END_GRAIN
IRON = P.IRON
RUST = P.RUST
STEEL = P.STEEL
STONE = P.STONE
STONE_OLD = P.STONE_OLD
STONE_BLUE = P.STONE_BLUE
MOSS = P.MOSS
EARTH = P.EARTH
EARTH_DARK = P.EARTH_DARK
GRASS = P.GRASS
LINEN = P.LINEN
LINEN_DIRTY = P.LINEN_DIRTY
BARK = P.BARK
BARK_DARK = P.BARK_DARK
STONE_DARK = L.hexc("#62656A")
STONE_WARM = L.hexc("#857C72")
MORTAR = L.hexc("#4B4A47")
SOOT = L.hexc("#2A2624")
CLAY = L.hexc("#8A5A44")
EMBER = L.hexc("#E07A3A")          # section 8: the forge glow, vertex colour only
EMBER_DULL = L.hexc("#8C4A2E")
CHARCOAL = L.hexc("#221E1C")
ASH = L.hexc("#8A857C")
LEATHER = L.hexc("#4E3A2C")
WATER = L.hexc("#2C3438")          # dark, matt water (no mirror)
LINEN_RAW = L.hexc("#CBBE9C")      # unbleached linen, warm
WARP = L.hexc("#D8CCAC")
SOD = L.hexc("#5A6644")
ROOF = L.hexc("#5A4E48")
ROOF_LIGHT = L.hexc("#6E625A")


def _stones_on_face(parts, a0: float, a1: float, along: str, plane: float, out: int, z0: float, z1: float,
                    seed: int, course_h=(0.16, 0.22), depth=(0.05, 0.08), soot=None, moss_rows: int = 1,
                    ln=(0.22, 0.38)):
    """Rough rubble courses on one face of a masonry block (the hut foundation recipe, cheaper)."""
    z = z0
    row = 0
    while z < z1 - 0.05:
        h = min(random.uniform(*course_h), z1 - z)
        a = a0 - (random.uniform(0.04, 0.12) if row % 2 else 0.0)
        k = 0
        while a < a1 - 0.05:
            ll = min(random.uniform(*ln), a1 - a)
            c = a + ll / 2
            d = random.uniform(*depth)
            hh = h / 2 * random.uniform(0.84, 0.97)
            if along == "x":
                loc, half = (c, plane + out * d / 2, z + h / 2), (ll / 2 * 0.95, d, hh)
            else:
                loc, half = (plane + out * d / 2, c, z + h / 2), (d, ll / 2 * 0.95, hh)
            s = L.prim("cube", loc=loc, scale=half, rot=(random.uniform(-4, 4), random.uniform(-4, 4),
                                                         random.uniform(-3, 3)))
            L.jitter(s, 0.018, 5.0, seed + k)
            col = random.choice((STONE, STONE_DARK, STONE_DARK, STONE_WARM))
            f = random.uniform(0.8, 1.0)
            if soot is not None:
                f *= soot(z + h / 2)
            L.paint(s, L.scale_c(col, f), var=0.25, ao=0.15, top=0.12, seed=seed + k)
            if row < moss_rows:
                P._tint_up(s, MOSS, 0.9, 0.2, freq=3.0, seed=seed + k)
            L.set_mat(s, L.MAT_PAINTED)
            parts.append(s)
            a += ll
            k += 1
        z += h
        row += 1
        seed += 31


def _core(loc, half, seed: int, color=MORTAR, cuts: int = 0):
    o = L.prim("cube", loc=loc, scale=half)
    if cuts:
        L.subdivide(o, cuts)
    L.jitter(o, 0.01, 2.0, seed)
    L.paint(o, color, var=0.2, ao=0.3, seed=seed, hue_shift=MOSS)
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _chips(parts, n: int, xr, yr, color, seed: int, r=(0.015, 0.035)):
    rnd = random.Random(seed)
    for i in range(n):
        parts.append(L.part("ico", L.scale_c(color, rnd.uniform(0.85, 1.15)),
                            loc=(rnd.uniform(*xr), rnd.uniform(*yr), 0.008), radius=rnd.uniform(*r),
                            subdivisions=1, scale=(1.0, 0.8, 0.45), jit=0.004, seed=seed + i,
                            paint_kw={"ao": 0.1, "top": 0.3}))


def _ground_patch(sx: float, sy: float, core, edge, seed: int, n: int = 20):
    """Trodden patch under a station: ragged outline, earth in the middle, grass at the rim."""
    o = P._rings_mesh([(sx / 2, sy / 2, 0.004), (sx / 2 * 0.8, sy / 2 * 0.8, 0.009), (sx / 2 * 0.45, sy / 2 * 0.45, 0.012)],
                      n, lambda k, x, y: (1.0 + 0.08 * noise.noise(Vector((x * 2.0, y * 2.0, seed))), 0.0), p=3.0,
                      name="patch")
    ring = P._ring_of(o, n)
    P._paint_fn(o, lambda co, vi: L.scale_c(L.mix(edge, core, min(1.0, ring[vi] / 2.0)),
                                            1.0 + 0.12 * noise.noise(co * 4.0)))
    L.set_mat(o, L.MAT_PAINTED)
    return o


def _slot(obj, name: str, loc, lean_deg: float = 6.0) -> None:
    """Ground marker whose local +Z (Godot) is the front of the stone leaning back against the rack."""
    L.marker(obj, name, loc)
    e = next(c for c in obj.children if c.name == name)
    e.rotation_euler = (math.radians(-lean_deg), 0.0, 0.0)


# --- stonemason's bench ------------------------------------------------------------------------

MASON_SLOTS = ((0.3, -0.4), (0.6, 0.0), (0.88, 0.4))   # (x, y): staggered, the front stone lowest-left


def _klupfel(parts, loc, yaw: float) -> None:
    """Stonemason's round mallet (Klupfel): a bell-shaped wooden head on a short handle, lying."""
    head = L.prim("cyl", radius=0.07, depth=0.16, vertices=8)
    L.taper(head, -0.08, 0.08, 0.72)
    handle = L.tube((0, 0, 0.08), (0, 0, 0.3), 0.017, 6)
    m = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "Y")
    for o, c in ((head, L.hexc("#8A6A48")), (handle, WOOD)):
        o.data.transform(m)
        L.paint(o, c, var=0.2, ao=0.1, top=0.3, seed=3, hue_shift=WOOD_DARK)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)


def _chisel(parts, p0, p1, seed: int) -> None:
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0)
    parts.append(P._stick(p0, p0 + d * 0.62, 0.011, STEEL, r1=0.009, verts=5, seed=seed, ao=0.0, top=0.4,
                          hue_shift=RUST))
    parts.append(P._stick(p0 + d * 0.62, p1, 0.009, STEEL, r1=0.003, verts=4, seed=seed + 1, ao=0.0, top=0.4))


def mason_bench():
    """Heavy timber trestle (west) with a half-worked sandstone-grey block, mallet, chisels, chips;
    east of it a rack of sleepers and a diagonal rail where three finished stones lean."""
    L.reset(1700)
    parts = [_ground_patch(2.3, 1.36, L.mix(EARTH, STONE_OLD, 0.35), L.mix(GRASS, EARTH, 0.45), 1)]
    bx, top = -0.72, 0.5
    # trestle: two thick beams side by side on four stout legs, braces
    for sy in (-1, 1):
        parts.append(P._plank((bx, sy * 0.13, top - 0.07), (0.5, 0.12, 0.07), WOOD_OLD, seed=2 + sy, cuts=1,
                              zrange=(0, top)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(P._stick((bx + sx * 0.44, sy * 0.25, 0.0), (bx + sx * 0.38, sy * 0.17, top - 0.12), 0.055,
                                  WOOD_DARK, r1=0.05, verts=6, seed=5 + sx + 2 * sy, ao=0.3, zrange=(0, top)))
        parts.append(P._plank((bx + sx * 0.41, 0.0, 0.16), (0.04, 0.24, 0.035), WOOD_DARK, seed=9 + sx,
                              zrange=(0, top)))
    parts.append(P._plank((bx, 0.0, 0.16), (0.38, 0.035, 0.03), WOOD_DARK, seed=12, zrange=(0, top)))
    # the block: rough on the back, a dressed front face and top with a drafted margin
    blk = L.prim("cube", loc=(bx + 0.02, 0.02, top + 0.19), scale=(0.31, 0.21, 0.19))
    L.subdivide(blk, 2)
    for v in blk.data.vertices:          # the back half is still quarry-rough
        if v.co.y > 0.05:
            v.co += Vector((noise.noise(v.co * 9.0), noise.noise(v.co * 9.0 + Vector((3, 3, 3))),
                            noise.noise(v.co * 9.0 + Vector((6, 1, 2))))) * 0.025
    L.bevel(blk, 0.008, 1)
    L.paint(blk, S.STONE_DRESSED, var=0.18, ao=0.3, top=0.15, zrange=(top, top + 0.4), hue_shift=S.STONE_SHADE,
            seed=13)
    L.set_mat(blk, L.MAT_PAINTED)
    parts.append(blk)
    _klupfel(parts, (bx + 0.12, -0.12, top + 0.38 + 0.065), 20)
    _chisel(parts, (bx - 0.32, -0.2, top + 0.01), (bx - 0.12, -0.24, top + 0.01), 14)
    _chisel(parts, (bx - 0.36, -0.12, top + 0.01), (bx - 0.18, -0.1, top + 0.01), 16)
    _chisel(parts, (bx - 0.1, 0.19, top + 0.38 + 0.012), (bx + 0.1, 0.2, top + 0.39), 18)
    # a wooden bucket of water for the dust (south-west corner)
    bucket = L.prim("cyl", loc=(-1.12, -0.55, 0.14), radius=0.12, depth=0.28, vertices=10)
    L.taper(bucket, 0.0, 0.28, 1.15)
    parts.append(P._finish_obj(bucket, WOOD, var=0.2, ao=0.3, hue_shift=WOOD_DARK, seed=19))
    parts.append(L.part("cyl", S.STONE_SHADE, loc=(-1.12, -0.55, 0.25), radius=0.125, depth=0.01, vertices=10,
                        paint_kw={"ao": 0.0}))
    for z in (0.06, 0.22):
        parts.append(L.part("torus", IRON, loc=(-1.12, -0.55, z), major_radius=0.125 + z * 0.06, minor_radius=0.008,
                            major_segments=10, minor_segments=3))
    _chips(parts, 16, (-1.25, -0.2), (-0.7, 0.4), S.STONE_DRESSED, 30)
    # the rack: sleepers under each slot and one diagonal rail on three posts behind the stones
    for i, (x, y) in enumerate(MASON_SLOTS):
        for dy in (-0.09, 0.09):
            parts.append(P._plank((x, y + dy, 0.03), (0.42, 0.05, 0.03), WOOD_OLD, seed=40 + i * 2 + int(dy > 0),
                                  zrange=(0, 0.8)))
    rail0 = Vector((0.0, -0.08, 0.72))
    rail1 = Vector((1.14, 0.66, 0.8))
    for t in (0.0, 0.5, 1.0):
        p = rail0.lerp(rail1, t) + Vector((0.05, 0.06, 0.0))
        parts.append(P._stick((p.x, p.y, 0.0), (p.x, p.y, p.z + 0.1), 0.045, WOOD_DARK, r1=0.04, verts=6, seed=50,
                              ao=0.4, zrange=(0, 0.9)))
    parts.append(P._stick(rail0 + Vector((0.05, 0.06, 0.0)), rail1 + Vector((0.05, 0.06, 0.0)), 0.04, WOOD, verts=6,
                          seed=52, ao=0.1, zrange=(0, 0.9)))
    obj = L.join(parts, "ph_bld_mason_bench")
    for i, (x, y) in enumerate(MASON_SLOTS):
        _slot(obj, "stone_slot_%d" % (i + 1), (x, y, 0.06))
    L.marker(obj, "use", (bx, -1.25, 0.0))
    P._center_xy(obj)
    L.finish(obj, "ph_bld_mason_bench", "buildings", 35, shift=False)


# --- loom --------------------------------------------------------------------------------------

def _sheet_between(pts, width: float, name: str):
    """Flat strip through points (x centred), width along X: warp threads, cloth."""
    bm = bmesh.new()
    rows = []
    for p in pts:
        p = Vector(p)
        rows.append((bm.verts.new(p - Vector((width / 2, 0, 0))), bm.verts.new(p),
                     bm.verts.new(p + Vector((width / 2, 0, 0)))))
    for a, b in zip(rows, rows[1:]):
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[1], a[2], b[2], b[1]))
    return P._raw(bm, name)


def loom():
    """A small treadle loom: two side frames with a raised castle carrying two heddle shafts, the
    beater, warp beam, breast and cloth beam; the cloth half woven. A bench in front, treadles on
    the ground, and over it all a lean-to roof on four posts (high at the front, open to the camera)."""
    L.reset(1800)
    rnd = random.Random(1801)
    parts = [_ground_patch(1.95, 1.6, L.mix(EARTH, WOOD_OLD, 0.3), L.mix(GRASS, EARTH, 0.45), 2)]
    hw = 0.62                         # half width of the loom frame (x)
    yf, yb = -0.42, 0.5               # front / back posts
    for sx in (-1, 1):
        x = sx * hw
        for y, h in ((yf, 1.02), (yb, 1.02)):
            parts.append(P._plank((x, y, h / 2), (0.04, 0.04, h / 2), WOOD_DARK, seed=3 + sx, cuts=1, zrange=(0, 1.8)))
        parts.append(P._plank((x, 0.02, 0.84), (0.035, 0.035, 0.84), WOOD_DARK, seed=5 + sx, cuts=1, zrange=(0, 1.8)))
        for z in (0.12, 0.98):
            parts.append(P._plank((x, (yf + yb) / 2, z), (0.035, (yb - yf) / 2 + 0.04, 0.035), WOOD_DARK, seed=7 + sx,
                                  zrange=(0, 1.8)))
        parts.append(P._stick((x, yf + 0.05, 0.98), (x, 0.0, 1.62), 0.025, WOOD_DARK, verts=4, seed=9, ao=0.1))
    parts.append(P._plank((0, 0.02, 1.7), (hw + 0.08, 0.045, 0.045), WOOD, seed=11, zrange=(0, 1.8)))   # castle
    # beams: breast (front top), cloth (front low), warp (back), with rolls of cloth / warp
    parts.append(P._stick((-hw - 0.04, yf, 0.98), (hw + 0.04, yf, 0.98), 0.045, WOOD, verts=8, seed=12, ao=0.0))
    for (y, z, r, col) in ((yf + 0.08, 0.5, 0.085, LINEN_RAW), (yb, 0.88, 0.1, WARP)):
        parts.append(P._stick((-hw - 0.06, y, z), (hw + 0.06, y, z), 0.04, WOOD_DARK, verts=8, seed=13, ao=0.0))
        roll = L.prim("cyl", loc=(0, y, z), rot=(0, 90, 0), radius=r, depth=hw * 1.7, vertices=12)
        L.subdivide(roll, 1)
        L.jitter(roll, 0.004, 12.0, 14)
        parts.append(P._finish_obj(roll, col, var=0.12, ao=0.2, top=0.2, hue_shift=LINEN_DIRTY, seed=15))
    cw = hw * 1.6
    # warp threads: from the warp roll over the heddles to the fell; cloth from the fell over the
    # breast beam down to the cloth roll
    fell = Vector((0, -0.2, 0.96))
    warp = _sheet_between([(0, yb - 0.02, 0.98), (0, 0.02, 0.97), (0, fell.y, fell.z)], cw, "warp")
    P._paint_fn(warp, lambda co, vi: L.scale_c(WARP, 0.9 + 0.12 * math.sin(co.x * 160.0)))
    L.set_mat(warp, L.MAT_PAINTED)
    parts.append(warp)
    cloth = _sheet_between([(0, fell.y, fell.z + 0.002), (0, yf, 1.03), (0, yf - 0.03, 0.9),
                            (0, yf + 0.0, 0.6), (0, yf + 0.08 - 0.08, 0.5)], cw, "cloth")
    _thicken(cloth, 0.004)
    parts.append(P._finish_obj(cloth, LINEN_RAW, var=0.1, ao=0.1, top=0.25, noise_freq=8.0, hue_shift=LINEN_DIRTY,
                               seed=16))
    # two heddle shafts hanging from the castle on cords
    for k, y in enumerate((-0.03, 0.07)):
        for z in (0.78, 1.14):
            parts.append(P._plank((0, y, z), (hw - 0.07, 0.012, 0.014), WOOD, seed=17 + k, zrange=(0, 1.8)))
        hed = L.prim("cube", loc=(0, y, 0.96), scale=(hw - 0.1, 0.004, 0.17))
        P._paint_fn(hed, lambda co, vi: L.scale_c(LINEN_DIRTY, 0.75))
        L.set_mat(hed, L.MAT_PAINTED)
        parts.append(hed)
        for sx in (-1, 1):
            parts.append(P._stick((sx * 0.3, y, 1.16), (sx * 0.3, 0.02, 1.66), 0.005, P.STRING, verts=3, seed=19,
                                  ao=0.0))
    # beater (Lade): swinging frame between fell and heddles
    by = -0.13
    for sx in (-1, 1):
        parts.append(P._stick((sx * (hw - 0.05), by + 0.05, 0.18), (sx * (hw - 0.05), by, 1.12), 0.022, WOOD, verts=5,
                              seed=20, ao=0.1))
    parts.append(P._plank((0, by, 1.12), (hw - 0.03, 0.03, 0.028), WOOD, seed=21, zrange=(0, 1.8)))
    parts.append(P._plank((0, by, 0.9), (hw - 0.05, 0.04, 0.025), WOOD_DARK, seed=22, zrange=(0, 1.8)))
    # a shuttle lying on the woven cloth
    sh = L.prim("cube", loc=(0.18, -0.34, 1.0), scale=(0.13, 0.025, 0.018))
    L.taper(sh, 0.982, 1.018, 1.0)
    for v in sh.data.vertices:
        v.co.y = -0.34 + (v.co.y + 0.34) * (1.0 - (abs(v.co.x - 0.18) / 0.13) ** 2 * 0.8)
    parts.append(P._finish_obj(sh, L.hexc("#8A6A48"), var=0.1, ao=0.0, top=0.3, seed=23))
    # treadles and the weaver's bench
    for sx in (-0.12, 0.12):
        parts.append(P._plank((sx, -0.05, 0.05), (0.035, 0.42, 0.018), WOOD_DARK, seed=24, rot=(-4, 0, 0),
                              zrange=(0, 1.8)))
    parts.append(P._plank((0, -0.72, 0.46), (0.42, 0.12, 0.03), WOOD, seed=25, cuts=1, zrange=(0, 1.8)))
    for sx in (-1, 1):
        parts.append(P._plank((sx * 0.34, -0.72, 0.22), (0.03, 0.1, 0.22), WOOD_DARK, seed=26, zrange=(0, 1.8)))
    # a basket of flax / yarn beside the loom
    basket = L.prim("cyl", loc=(0.88, -0.5, 0.12), radius=0.16, depth=0.24, vertices=10)
    L.taper(basket, -0.12, 0.12, 1.2)
    parts.append(P._finish_obj(basket, L.hexc("#8C7650"), var=0.3, ao=0.4, noise_freq=14.0, seed=28))
    for k in range(3):
        parts.append(L.part("sphere", WARP, loc=(0.84 + k * 0.05, -0.5 + (k - 1) * 0.06, 0.26), radius=0.06,
                            segments=8, ring_count=5, scale=(1.0, 1.0, 0.8), paint_kw={"ao": 0.2, "top": 0.3}))
    # the lean-to roof: posts, two beams, rafters and three rows of shingle boards
    zf, zb, px, py = 2.5, 2.05, 0.93, 0.78
    for sx in (-1, 1):
        for y, z in ((-py, zf), (py, zb)):
            parts.append(P._stick((sx * px, y, 0.0), (sx * px, y, z), 0.05, WOOD_DARK, r1=0.045, verts=6,
                                  seed=30 + sx, ao=0.3, zrange=(0, 2.6)))
        parts.append(P._stick((sx * px, -py + 0.25, zf - 0.08), (sx * px - sx * 0.02, -py, zf - 0.45), 0.025, WOOD_DARK,
                              verts=4, seed=31, ao=0.1))
    for y, z in ((-py, zf), (py, zb)):
        parts.append(P._stick((-px - 0.07, y, z), (px + 0.07, y, z), 0.055, WOOD_DARK, verts=6, seed=32, ao=0.1))
    slope = (zb - zf) / (2 * py)

    def roof_z(y: float) -> float:
        return zf + (y + py) * slope + 0.07

    rows = 4
    y0, y1 = -py - 0.12, py + 0.06
    for r in range(rows):
        ya, yb2 = y0 + (y1 - y0) * r / rows, y0 + (y1 - y0) * (r + 1) / rows + 0.08
        x = -px - 0.12
        k = 0
        while x < px + 0.06:
            w = rnd.uniform(0.18, 0.3)
            ym = (ya + yb2) / 2
            sh = L.prim("cube", loc=(x + w / 2, ym, roof_z(ym) + 0.02 - r * 0.004), scale=(w / 2 * 0.96, (yb2 - ya) / 2, 0.012))
            ang = math.atan(slope)
            sh.data.transform(Matrix.Translation((x + w / 2, ym, roof_z(ym) + 0.02)) @ Matrix.Rotation(ang, 4, "X")
                              @ Matrix.Rotation(math.radians(rnd.uniform(-2, 2)), 4, "Z")
                              @ Matrix.Translation((-(x + w / 2), -ym, -(roof_z(ym) + 0.02))))
            L.jitter(sh, 0.006, 5.0, 40 + r * 20 + k)
            col = L.mix(ROOF, ROOF_LIGHT, rnd.random())
            L.paint(sh, col, var=0.2, ao=0.1, top=0.15, seed=40 + k)
            P._tint_up(sh, MOSS, 0.7 if r == rows - 1 else 0.35, 0.3, freq=4.0, seed=41 + k)
            L.set_mat(sh, L.MAT_PAINTED)
            parts.append(sh)
            x += w
            k += 1
    obj = L.join(parts, "ph_bld_loom")
    P._center_xy(obj)
    L.finish(obj, "ph_bld_loom", "buildings", 35, shift=False)


# --- forge -------------------------------------------------------------------------------------

HEARTH = {"x0": -0.05, "x1": 1.05, "y0": -0.5, "y1": 0.5, "h": 0.8}
FIRE = Vector((0.36, -0.04, 0.8))
CHIMNEY = {"c": Vector((0.72, 0.12)), "hw": 0.26, "z0": 1.9, "z1": 3.75, "lean": Vector((0.05, 0.03, 0.0))}


def _anvil(parts, loc) -> None:
    """Anvil (0.5 m) on an elm stump: foot, waist, face with a horn towards -X, a hammer on it."""
    x, y, z = loc
    stump = L.prim("cyl", loc=(x, y, z / 2), radius=0.2, depth=z, vertices=10)
    L.subdivide(stump, 1)
    L.jitter(stump, 0.012, 6.0, 1)
    L.paint(stump, BARK, var=0.25, ao=0.4, zrange=(0, z), hue_shift=BARK_DARK, seed=2)
    L.set_mat(stump, L.MAT_PAINTED)
    parts.append(stump)
    parts.append(L.part("cyl", L.mix(END_GRAIN, WOOD_OLD, 0.5), loc=(x, y, z + 0.004), radius=0.19, depth=0.01,
                        vertices=10, paint_kw={"ao": 0.0}))
    ir = []
    ir.append(L.prim("cube", loc=(x, y, z + 0.05), scale=(0.16, 0.12, 0.05)))
    w = L.prim("cube", loc=(x, y, z + 0.14), scale=(0.1, 0.06, 0.05))
    L.taper(w, z + 0.09, z + 0.19, 1.3)
    ir.append(w)
    ir.append(L.prim("cube", loc=(x + 0.04, y, z + 0.24), scale=(0.2, 0.075, 0.05)))
    horn = L.prim("cone", radius1=0.07, radius2=0.0, depth=0.2, vertices=6)
    horn.data.transform(Matrix.Translation((x - 0.26, y, z + 0.25)) @ Matrix.Rotation(math.radians(-100), 4, "Y"))
    ir.append(horn)
    for o in ir:
        L.paint(o, IRON, var=0.2, ao=0.25, top=0.5, zrange=(z, z + 0.3), hue_shift=L.hexc("#4A4C50"), seed=3)
        L.set_mat(o, L.MAT_PAINTED)
        parts.append(o)
    P._tint_up(ir[2], L.hexc("#6E7176"), 0.8, 0.7, freq=8.0, seed=4)      # the worn, shiny face
    # hammer lying on the face
    parts.append(P._stick((x + 0.06, y - 0.04, z + 0.31), (x + 0.02, y - 0.3, z + 0.3), 0.014, WOOD, verts=5, seed=5,
                          ao=0.0))
    parts.append(L.part("cube", IRON, loc=(x + 0.07, y - 0.02, z + 0.315), scale=(0.022, 0.06, 0.022),
                        paint_kw={"ao": 0.0, "top": 0.4}))


def forge():
    """Masonry forge (hearth block 1.1 x 1.0 x 0.8 m) with a soot-blackened hood and a rubble
    chimney to 3.9 m; the fire bed glows (#E07A3A vertex colour) and opens to the west, where the
    anvil on its stump and the quench trough stand; leather bellows on a trestle to the north."""
    L.reset(1900)
    rnd = random.Random(1901)
    h = HEARTH
    parts = [_ground_patch(2.3, 1.75, L.mix(SOOT, EARTH, 0.55), L.mix(GRASS, EARTH, 0.5), 3)]
    cx, cy = (h["x0"] + h["x1"]) / 2, (h["y0"] + h["y1"]) / 2
    hx, hy = (h["x1"] - h["x0"]) / 2, (h["y1"] - h["y0"]) / 2
    parts.append(_core((cx, cy, h["h"] / 2), (hx - 0.04, hy - 0.04, h["h"] / 2), 1, cuts=1))
    _stones_on_face(parts, h["x0"], h["x1"], "x", h["y0"] + 0.03, -1, 0.0, h["h"], 100)
    _stones_on_face(parts, h["y0"], h["y1"], "y", h["x0"] + 0.03, -1, 0.0, h["h"], 200)
    _stones_on_face(parts, h["y0"], h["y1"], "y", h["x1"] - 0.03, 1, 0.0, h["h"], 300)
    _stones_on_face(parts, h["x0"], h["x1"], "x", h["y1"] - 0.03, 1, 0.0, h["h"], 350)
    # the hearth top: flat slabs round a sunken fire bed
    for i, (x, y, sx, sy) in enumerate(((cx, h["y0"] + 0.1, hx, 0.1), (cx, h["y1"] - 0.1, hx, 0.1),
                                        (h["x0"] + 0.08, cy, 0.08, hy - 0.2), (0.85, cy, 0.2, hy - 0.2))):
        slab = L.prim("cube", loc=(x, y, h["h"] + 0.025), scale=(sx + 0.02, sy + 0.02, 0.03))
        L.jitter(slab, 0.01, 4.0, 400 + i)
        L.paint(slab, L.mix(STONE_DARK, SOOT, 0.35), var=0.25, ao=0.1, top=0.1, seed=400 + i)
        L.set_mat(slab, L.MAT_PAINTED)
        parts.append(slab)
    bed = P._rings_mesh([(0.3, 0.3, h["h"] + 0.035), (0.22, 0.22, h["h"] + 0.05), (0.12, 0.12, h["h"] + 0.06)], 16,
                        lambda k, x, y: (1.0 + 0.1 * noise.noise(Vector((x * 9, y * 9, k))), 0.02 * noise.noise(
                            Vector((x * 14, y * 14, 3)))), p=2.2, name="coals")
    bed.data.transform(Matrix.Translation((FIRE.x, FIRE.y, 0.0)))
    P._paint_fn(bed, lambda co, vi: L.mix(CHARCOAL, EMBER, max(0.0, min(1.0, 1.1 - Vector((co.x - FIRE.x, co.y - FIRE.y)).length
                                                                          / 0.3 + 1.2 * noise.noise(co * 14.0)))))
    L.set_mat(bed, L.MAT_PAINTED)
    parts.append(bed)
    for i in range(6):               # lumps of charcoal on the glowing bed
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.08, 0.22)
        c = EMBER if rr < 0.14 else CHARCOAL
        parts.append(L.part("ico", c, loc=(FIRE.x + math.cos(a) * rr, FIRE.y + math.sin(a) * rr, h["h"] + 0.09),
                            radius=0.035, subdivisions=1, jit=0.01, seed=410 + i,
                            paint_kw={"ao": 0.0, "var": 0.1, "top": 0.0}))
    # back walls (east + north) carrying the hood
    bw = [((0.97, cy, 1.1), (0.08, hy, 0.3)), ((cx + 0.1, h["y1"] - 0.08, 1.1), (hx - 0.1, 0.08, 0.3))]
    soot = lambda z: 0.55 + 0.45 * max(0.0, 1.0 - (z - 0.8) / 1.2)
    for i, (loc, half) in enumerate(bw):
        parts.append(_core(loc, half, 420 + i, color=L.mix(MORTAR, SOOT, 0.4)))
    _stones_on_face(parts, h["y0"] + 0.05, h["y1"], "y", 0.89, -1, 0.8, 1.4, 430, soot=soot, moss_rows=0)
    _stones_on_face(parts, h["x0"] + 0.1, 0.9, "x", h["y1"] - 0.16, -1, 0.8, 1.4, 440, soot=soot, moss_rows=0)
    # hood: a soot-black frustum over the fire, plastered, with an iron edge band
    hood = L.prim("cube", scale=(1, 1, 1))
    for v in hood.data.vertices:
        if v.co.z > 0:
            v.co = Vector((CHIMNEY["c"].x + v.co.x * 0.3, CHIMNEY["c"].y + v.co.y * 0.3, CHIMNEY["z0"] + 0.02))
        else:
            v.co = Vector((cx - 0.05 + v.co.x * (hx + 0.02), cy + 0.02 + v.co.y * (hy + 0.02), 1.4))
    L.subdivide(hood, 2)
    L.jitter(hood, 0.012, 4.0, 450)
    P._paint_fn(hood, lambda co, vi: L.scale_c(L.mix(L.hexc("#8A8278"), SOOT, 0.25 + 0.55 * max(0.0, min(1.0, (co.z - 1.35) / 0.5))
                                                     + 0.2 * noise.noise(co * 5.0)), 1.0))
    L.set_mat(hood, L.MAT_PAINTED)
    parts.append(hood)
    band = [(cx - 0.05 + sx * (hx + 0.03), cy + 0.02 + sy * (hy + 0.03), 1.42) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    parts.append(P._finish_obj(P._path_tube(band, 0.018, 4, closed=True, name="band"), IRON, var=0.3, ao=0.0,
                               hue_shift=RUST, seed=451))
    # the chimney: rubble courses on a mortar core, leaning a little, cap slabs and a sooty mouth
    ch = CHIMNEY
    c0 = Vector((ch["c"].x, ch["c"].y, 0.0))
    core = _core((c0.x, c0.y, (ch["z0"] + ch["z1"]) / 2), (ch["hw"] - 0.03, ch["hw"] - 0.03, (ch["z1"] - ch["z0"]) / 2),
                 460, color=L.mix(MORTAR, SOOT, 0.3), cuts=1)
    for v in core.data.vertices:
        v.co += ch["lean"] * ((v.co.z - ch["z0"]) / (ch["z1"] - ch["z0"]))
    parts.append(core)
    first = len(parts)
    hwc = ch["hw"]
    _stones_on_face(parts, c0.x - hwc, c0.x + hwc, "x", c0.y - hwc + 0.02, -1, ch["z0"], ch["z1"], 500,
                    course_h=(0.17, 0.24), ln=(0.2, 0.3), soot=lambda z: 0.7 + 0.3 * (1 - (z - 2) / 2), moss_rows=0)
    _stones_on_face(parts, c0.y - hwc, c0.y + hwc, "y", c0.x - hwc + 0.02, -1, ch["z0"], ch["z1"], 600,
                    course_h=(0.17, 0.24), ln=(0.2, 0.3), soot=lambda z: 0.7 + 0.3 * (1 - (z - 2) / 2), moss_rows=0)
    _stones_on_face(parts, c0.y - hwc, c0.y + hwc, "y", c0.x + hwc - 0.02, 1, ch["z0"], ch["z1"], 700,
                    course_h=(0.17, 0.24), ln=(0.2, 0.3), soot=lambda z: 0.7 + 0.3 * (1 - (z - 2) / 2), moss_rows=0)
    _stones_on_face(parts, c0.x - hwc, c0.x + hwc, "x", c0.y + hwc - 0.02, 1, ch["z0"], ch["z1"], 750,
                    course_h=(0.17, 0.24), ln=(0.2, 0.3), soot=lambda z: 0.7 + 0.3 * (1 - (z - 2) / 2), moss_rows=0)
    for o in parts[first:]:
        zc = sum(v.co.z for v in o.data.vertices) / len(o.data.vertices)
        o.data.transform(Matrix.Translation(ch["lean"] * ((zc - ch["z0"]) / (ch["z1"] - ch["z0"]))))
    top = Vector((c0.x, c0.y, ch["z1"])) + ch["lean"]
    for i, (dx, dy, sx, sy) in enumerate(((0, -1, 1, 0.3), (0, 1, 1, 0.3), (-1, 0, 0.3, 0.55), (1, 0, 0.3, 0.55))):
        slab = L.prim("cube", loc=top + Vector((dx * (hwc - 0.03), dy * (hwc - 0.03), 0.03)),
                      scale=((hwc + 0.06) * sx, (hwc + 0.06) * sy, 0.03))
        L.jitter(slab, 0.01, 4.0, 770 + i)
        L.paint(slab, L.mix(STONE_DARK, SOOT, 0.5), var=0.2, ao=0.1, seed=770 + i)
        L.set_mat(slab, L.MAT_PAINTED)
        parts.append(slab)
    parts.append(L.part("cube", L.hexc("#120E0C"), loc=top + Vector((0, 0, 0.035)), scale=(hwc - 0.1, hwc - 0.1, 0.03)))
    # anvil on its stump west of the fire, quench trough south-west, tongs and bars
    _anvil(parts, (-0.62, -0.02, 0.48))
    tx, ty = -0.55, -0.72
    trough = P._rbox((tx, ty, 0.17), (0.36, 0.16, 0.17), WOOD_OLD, bev=0.02, seg=1, seed=800, ao=0.4, zrange=(0, 0.4))
    parts.append(trough)
    parts.append(L.part("cube", WATER, loc=(tx, ty, 0.335), scale=(0.33, 0.13, 0.004), paint_kw={"ao": 0.0, "var": 0.1}))
    for sx in (-1, 1):
        parts.append(L.part("cube", IRON, loc=(tx + sx * 0.25, ty, 0.2), scale=(0.018, 0.17, 0.16),
                            paint_kw={"hue_shift": RUST}))
    parts.append(P._stick((tx + 0.3, ty + 0.05, 0.33), (tx + 0.02, ty + 0.25, 0.9), 0.009, IRON, verts=4, seed=801, ao=0.0))
    parts.append(P._stick((tx + 0.32, ty + 0.02, 0.33), (tx + 0.04, ty + 0.21, 0.9), 0.009, IRON, verts=4, seed=802, ao=0.0))
    for i in range(3):   # a few iron bars leaning on the hearth front
        x = 0.62 + i * 0.07
        parts.append(P._stick((x, h["y0"] - 0.2, 0.0), (x + 0.03, h["y0"] - 0.02, 0.62 + i * 0.03), 0.012,
                              L.mix(IRON, RUST, 0.4), verts=4, seed=810 + i, ao=0.2))
    # charcoal basket by the hearth (south-east)
    bk = L.prim("cyl", loc=(1.07, -0.66, 0.13), radius=0.13, depth=0.26, vertices=10)
    L.taper(bk, -0.13, 0.13, 1.25)
    parts.append(P._finish_obj(bk, L.hexc("#6E5A3E"), var=0.3, ao=0.4, noise_freq=14.0, seed=820))
    parts.append(L.part("ico", CHARCOAL, loc=(1.07, -0.66, 0.26), radius=0.14, subdivisions=2, scale=(1.0, 1.0, 0.35),
                        jit=0.02, seed=821, paint_kw={"ao": 0.0, "var": 0.35}))
    # bellows on a low trestle north of the hearth, nozzle into the fire bed
    by, bz = 0.78, 0.55
    for sx in (-1, 1):
        parts.append(P._stick((0.1 + sx * 0.3, by - 0.12, 0.0), (0.1 + sx * 0.3, by, bz - 0.04), 0.03, WOOD_DARK, verts=5,
                              seed=830, ao=0.3))
        parts.append(P._stick((0.1 + sx * 0.3, by + 0.12, 0.0), (0.1 + sx * 0.3, by, bz - 0.04), 0.03, WOOD_DARK, verts=5,
                              seed=831, ao=0.3))
    board = [(-0.35, -0.14), (0.25, -0.2), (0.4, -0.06), (0.4, 0.06), (0.25, 0.2), (-0.35, 0.14)]
    for z, col in ((bz, WOOD), (bz + 0.2, WOOD)):
        bm = bmesh.new()
        lo = [bm.verts.new((0.1 + px, by + py, z)) for px, py in board]
        hi = [bm.verts.new((0.1 + px, by + py, z + 0.03)) for px, py in board]
        bm.faces.new(list(reversed(lo)))
        bm.faces.new(hi)
        for i in range(len(board)):
            bm.faces.new((lo[i], lo[(i + 1) % len(board)], hi[(i + 1) % len(board)], hi[i]))
        parts.append(P._finish_obj(P._link(bm, "board"), col, var=0.2, ao=0.1, top=0.2, seed=832))
    bm = bmesh.new()   # the leather between the boards, pleated
    lo = [bm.verts.new((0.1 + px, by + py, bz + 0.03)) for px, py in board]
    mid = [bm.verts.new((0.1 + px * 0.9 - 0.02, by + py * 0.85, bz + 0.115)) for px, py in board]
    hi = [bm.verts.new((0.1 + px, by + py, bz + 0.2)) for px, py in board]
    for a, b in ((lo, mid), (mid, hi)):
        for i in range(len(board)):
            bm.faces.new((a[i], a[(i + 1) % len(board)], b[(i + 1) % len(board)], b[i]))
    parts.append(P._finish_obj(P._link(bm, "leather"), LEATHER, var=0.25, ao=0.2, top=0.3, seed=833))
    parts.append(P._stick((0.5, by, bz + 0.1), (FIRE.x + 0.12, FIRE.y + 0.3, h["h"] + 0.06), 0.03, IRON, r1=0.02, verts=6,
                          seed=834, ao=0.0))
    parts.append(P._stick((-0.25, by, bz + 0.23), (-0.55, by + 0.05, bz + 0.45), 0.018, WOOD, verts=5, seed=835, ao=0.0))
    obj = L.join(parts, "ph_bld_forge")
    L.marker(obj, "light_ember", (FIRE.x, FIRE.y, h["h"] + 0.3))
    L.marker(obj, "smoke", (top.x, top.y, top.z + 0.1))
    P._center_xy(obj)
    L.finish(obj, "ph_bld_forge", "buildings", 35, shift=False)


# --- charcoal kiln -------------------------------------------------------------------------------

def _kiln(name: str, burning: bool) -> None:
    """Meiler, 1.4 m across, 0.85 m high: a dome of stacked billets covered with sod and earth,
    the log ends showing round the foot, a smoke hole at the top. Burning: blackened cover, glowing
    vents, ash round the foot."""
    L.reset(2000)
    rnd = random.Random(2001)
    n, rings = 16, 7
    bm = bmesh.new()
    rr = []
    for k in range(rings + 1):
        t = k / rings
        a = t * math.pi / 2
        r = 0.66 * math.cos(a) + 0.06
        z = 0.82 * math.sin(a) ** 0.9
        ring = []
        for j in range(n):
            b = j / n * math.tau
            f = 1.0 + 0.05 * noise.noise(Vector((math.cos(b) * 2, math.sin(b) * 2, t * 3)))
            ring.append(bm.verts.new((math.cos(b) * r * f, math.sin(b) * r * f, z)))
        rr.append(ring)
    for k in range(rings):
        for j in range(n):
            bm.faces.new((rr[k][j], rr[k][(j + 1) % n], rr[k + 1][(j + 1) % n], rr[k + 1][j]))
    hole = bm.verts.new((0, 0, 0.78))
    for j in range(n):
        bm.faces.new((rr[-1][j], rr[-1][(j + 1) % n], hole))
    dome = P._link(bm, "dome")
    vents = [(rnd.uniform(0, math.tau), rnd.uniform(0.3, 0.6)) for _ in range(6)]

    def col(co, vi):
        up = co.z / 0.82
        if burning:
            c = L.mix(L.mix(SOOT, EARTH_DARK, 0.5), L.hexc("#4A4038"), 0.4 + 0.4 * noise.noise(co * 5.0))
            c = L.mix(c, ASH, max(0.0, noise.noise(co * 3.0 + Vector((4, 4, 4)))) * 0.6)
            for a, zt in vents:
                p = Vector((math.cos(a) * 0.66 * math.cos(zt * 1.5), math.sin(a) * 0.66 * math.cos(zt * 1.5), zt * 0.82))
                d = (co - p).length
                if d < 0.12:
                    c = L.mix(c, EMBER_DULL if d > 0.05 else EMBER, 1.0 - d / 0.12)
            if vi == len(rr) * n:
                c = CHARCOAL
            return c
        c = L.mix(EARTH, SOD, max(0.0, min(1.0, 0.4 + noise.noise(co * 4.0))))
        c = L.mix(c, L.hexc("#6E7A4C"), max(0.0, noise.noise(co * 7.0 + Vector((1, 2, 3))) * up))
        return L.scale_c(c, 0.8 + 0.3 * up) if vi != len(rr) * n else L.scale_c(EARTH_DARK, 0.6)
    P._paint_fn(dome, col)
    L.set_mat(dome, L.MAT_PAINTED)
    parts = [dome]
    for i in range(12):        # billet ends round the foot
        a = i / 12 * math.tau + rnd.uniform(-0.1, 0.1)
        p0 = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.07))
        p1 = Vector((math.cos(a) * 0.74, math.sin(a) * 0.74, 0.05))
        parts.append(P._stick(p0, p1, rnd.uniform(0.04, 0.055), L.mix(BARK, SOOT, 0.6) if burning else BARK, verts=5,
                              seed=10 + i, ao=0.1))
        parts.append(L.part("cyl", L.mix(END_GRAIN, SOOT, 0.7 if burning else 0.15),
                            loc=p1 + (p1 - p0).normalized() * 0.003, rot=(90, 0, 90 + math.degrees(a)), radius=0.042,
                            depth=0.006, vertices=5, paint_kw={"ao": 0.0}))
    base = P._rings_mesh([(0.85, 0.85, 0.004), (0.74, 0.74, 0.01)], 16,
                         lambda k, x, y: (1.0 + 0.08 * noise.noise(Vector((x * 3, y * 3, k))), 0.0), p=2.0, name="ring")
    ring_c = L.mix(ASH, SOOT, 0.3) if burning else L.mix(EARTH, GRASS, 0.3)
    parts.append(P._finish_obj(base, ring_c, var=0.3, ao=0.0, noise_freq=4.0, seed=40))
    if not burning:           # a rake and a few sods ready to patch the cover
        parts.append(P._stick((0.7, -0.5, 0.02), (0.1, -0.95, 0.03), 0.014, WOOD, verts=4, seed=41, ao=0.0))
        for i in range(3):
            parts.append(L.part("cube", SOD, loc=(-0.72 + i * 0.1, -0.62 - i * 0.05, 0.04), scale=(0.1, 0.07, 0.035),
                                rot=(0, 0, rnd.uniform(0, 60)), jit=0.01, seed=42 + i, paint_kw={"top": 0.3}))
    obj = L.join(parts, name)
    L.marker(obj, "smoke", (0.0, 0.0, 0.86))
    P._center_xy(obj)
    L.finish(obj, name, "props", 40)


def charcoal_kiln():
    _kiln("ph_prop_charcoal_kiln", False)


def charcoal_kiln_burning():
    _kiln("ph_prop_charcoal_kiln_burning", True)


# --- build site ---------------------------------------------------------------------------------

SITE_W, SITE_D = 2.4, 1.8


def _slab(parts, seed: int) -> None:
    """An old, sunken, overgrown stone slab with grass creeping over its edges."""
    s = L.prim("cube", loc=(0.05, 0.05, 0.02), scale=(0.5, 0.36, 0.04), rot=(0, 0, 6))
    L.subdivide(s, 1)
    L.jitter(s, 0.015, 3.0, seed)
    L.paint(s, STONE_OLD, var=0.25, ao=0.3, top=0.2, hue_shift=MOSS, seed=seed)
    P._tint_up(s, MOSS, 0.9, 0.5, freq=4.0, seed=seed)
    L.set_mat(s, L.MAT_PAINTED)
    parts.append(s)
    tufts = []
    for i in range(10):
        a = i / 10 * math.tau
        tufts.append(((0.05 + math.cos(a) * 0.52, 0.05 + math.sin(a) * 0.38), 4, (0.06, 0.16), 0.012, 0.06))
    parts.append(E._blades(tufts, E.GRASS_TINT, seed + 1))


def build_site():
    """Staked-out plot: four pegs, a taut string round them, a little board on a stake (front
    left), the old slab in the middle. Pegs, string and board: child mesh `stakes`."""
    L.reset(2100)
    parts = [_ground_patch(SITE_W * 0.9, SITE_D * 0.9, L.mix(EARTH, GRASS, 0.4), L.mix(GRASS, EARTH, 0.2), 4, n=16)]
    _slab(parts, 5)
    base = L.join(parts, "ph_prop_build_site")
    st = []
    hx, hy = SITE_W / 2 - 0.05, SITE_D / 2 - 0.05
    corners = [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
    for i, (x, y) in enumerate(corners):
        peg = L.prim("cyl", loc=(x, y, 0.19), radius=0.025, depth=0.38, vertices=5)
        for v in peg.data.vertices:
            if v.co.z < 0.02:
                v.co.x = x + (v.co.x - x) * 0.3
                v.co.y = y + (v.co.y - y) * 0.3
        st.append(P._finish_obj(peg, WOOD_FRESH, var=0.15, ao=0.3, top=0.3, seed=10 + i))
    ring = [(x, y, 0.3) for x, y in corners]
    st.append(P._finish_obj(P._path_tube(ring, 0.004, 3, closed=True, name="string"), P.STRING, var=0.1, ao=0.0, seed=20))
    sx, sy = -hx + 0.35, -hy - 0.02
    st.append(P._stick((sx, sy, 0.0), (sx, sy, 0.62), 0.02, WOOD_FRESH, verts=4, seed=21, ao=0.2))
    board = L.prim("cube", loc=(sx, sy - 0.03, 0.55), scale=(0.16, 0.012, 0.1), rot=(-8, 0, 0))
    L.jitter(board, 0.004, 5.0, 22)
    st.append(P._finish_obj(board, L.mix(WOOD_FRESH, LINEN, 0.3), var=0.12, ao=0.1, top=0.2, seed=22))
    for k in range(3):     # scratched lines on the board (charcoal marks)
        st.append(L.part("cube", CHARCOAL, loc=(sx - 0.04 + k * 0.03, sy - 0.044, 0.56 + (k % 2) * 0.03),
                         scale=(0.05, 0.002, 0.004), rot=(-8, 0, 0), paint_kw={"ao": 0.0}))
    stakes = L.join(st, "stakes")
    L.smooth(stakes, 35)
    stakes.parent = base
    L.finish(base, "ph_prop_build_site", "props", 35, shift=False)


def build_site_slab():
    """The empty, overgrown stone slab alone (Am Bruch, 24.0 | -2.8): no pegs, no string."""
    L.reset(2110)
    parts = []
    _slab(parts, 5)
    for i in range(3):      # a few weeds pushing up through the joints
        parts.append(E._rosette(-0.25 + i * 0.25, -0.15 + (i % 2) * 0.3, 5, 0.1, 0.025, E.WEED_DARK, 30 + i, lift=0.07))
    obj = L.join(parts, "ph_prop_build_site_slab")
    P._center_xy(obj)
    L.finish(obj, "ph_prop_build_site_slab", "props", 35, shift=False)


ASSETS = (mason_bench, loom, forge, charcoal_kiln, charcoal_kiln_burning, build_site, build_site_slab)


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
