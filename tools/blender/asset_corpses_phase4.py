"""Phase-4 corpses (docs/PHASE4_DESIGN.md section 8), from the approved body kit of
asset_props_slice (same proportions, head at +X, face up, footprint centred, so every look
sits the same on the slot_corpse of table, bier and handcart). Peaceful, never gory.

  ph_prop_corpse_05     S5 "the dead man from the moor": a man in a long, patched
                        gravekeeper's coat that is too wide for him, a buckle that does not
                        match it, skin darkened and leathery from the moor water
  ph_prop_corpse_06     S3 Ida Wernstein: a young woman in a buttoned-up travelling coat,
                        chestnut braid over her shoulder, ink on thumb and forefinger
  ph_prop_corpse_gown   a body dressed in the burial gown (Totenhemd), hands folded, bare feet;
                        linen lighter and warmer than the shroud

Each carries the marker `sprig` on the chest, where the laid-out sprig (ph_prop_layout_sprig)
rests. The older looks share the torso, so the same point fits them too.

Run:  python tools/blender/build_all.py asset_corpses_phase4
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh users)
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P

GOWN = L.hexc("#D9CCAE")          # burial gown: lighter and warmer than SHROUD_LINEN #C2B89F
GOWN_SHADE = L.hexc("#BBA987")
GOWN_TIE = L.hexc("#9C8766")
COAT5 = L.hexc("#4E4337")         # a gravekeeper's coat (the family of the player's #4B4038)
COAT5_DARK = L.hexc("#3B332B")
PATCH_A = L.hexc("#5F5747")
PATCH_B = L.hexc("#433D35")
STITCH = L.hexc("#8A7E68")
MOOR = L.hexc("#5C5746")          # moor-darkened, leathery skin (still calm, no wounds)
TRAVEL = L.hexc("#5E4A3E")        # Ida's travelling coat: dark rust-brown wool
TRAVEL_DARK = L.hexc("#47382F")
CHESTNUT = L.hexc("#553B2B")
INK = L.hexc("#2A2A33")
SPRIG_X = 0.40                    # chest point of the kit, Blender x (head at +X)


def _sprig_point() -> Vector:
    return P._on_loft(P.TORSO, SPRIG_X, 90.0, 0.012, P._torso_fold)


def _done(parts, name: str) -> None:
    """Join, add the chest marker, centre the footprint, pivot bottom centre, export."""
    obj = L.join(parts, name)
    L.marker(obj, "sprig", _sprig_point())
    P._center_xy(obj)
    L.finish(obj, name, "props", P.CORPSE_SMOOTH)


def _darken(objs, color, amount: float) -> None:
    """Blend already painted parts towards `color` (moor-darkened skin)."""
    lin = [L._to_lin(c) for c in color]
    for o in objs:
        attr = o.data.color_attributes["Col"]
        for li in range(len(attr.data)):
            c = attr.data[li].color
            attr.data[li].color = (c[0] + (lin[0] - c[0]) * amount, c[1] + (lin[1] - c[1]) * amount,
                                   c[2] + (lin[2] - c[2]) * amount, 1.0)


def _over_legs_loft(color_fn, x_end: float, seed: int, width: float = 0.2, hem: float = 0.02, name: str = "skirt"):
    """Long cloth over both legs (coat skirt, gown): sags between the knees, folds along the length."""
    secs = [(-0.1, 0.0, 0.1, 0.182, 0.078, 0.1), (-0.3, 0.0, 0.097, width, 0.072, 0.097),
            (-0.5, 0.0, 0.092, width - 0.002, 0.064, 0.092), (x_end, 0.0, 0.086, width - 0.004, 0.058, 0.086)]

    def fold(x, a):
        s = math.sin(a)
        dip = 0.22 * math.exp(-(math.cos(a) / 0.28) ** 2) * max(0.0, -x - 0.2) / 0.55
        return 1.0 + 0.035 * math.sin(a * 11.0 + x * 5.0 + seed) * s - dip * s
    sk = P._loft(secs, (0, 16, 34, 52, 70, 90, 110, 128, 146, 164, 180, 270), fold=fold, caps=(False, True),
                 name=name)
    for v in sk.data.vertices:
        if v.co.x < x_end + 0.015:
            v.co.x += hem * math.sin(v.co.y * 60.0 + seed)
    return P._cloth(sk, color_fn, seed=seed)


def _patch(parts, x: float, a: float, secs, lift: float, half, color, seed: int) -> None:
    """A sewn-on patch with painted stitches round its border."""
    pos = P._on_loft(secs, x, a, lift)
    n = (pos - Vector((x, 0.0, P._sec(secs, x)[1]))).normalized()

    def fn(lc, poly, hx=half[0], hy=half[1]):
        edge = max(abs(lc.x) / hx, abs(lc.y) / hy)
        if edge > 0.72 and math.sin((lc.x + lc.y) * 400.0) > 0.0:
            return STITCH
        return color
    parts.append(P._blob("cube", (half[0], half[1], 0.005), pos, n, (1, 0, 0), fn=fn, jit=0.002, seed=seed,
                         ao=0.0, top=0.2))


# --- S5: the man from the moor ----------------------------------------------------------

def corpse_05():
    """A man in a long gravekeeper's coat, patched at elbow, chest and skirt, too wide for him
    (it gapes at the collar); a round brass buckle that does not belong to it; dark trousers,
    old boots. Short dark hair, a few days' stubble, skin darkened by the moor."""
    L.reset(205)
    trouser = L.hexc("#3A3834")
    hair = L.hexc("#3E3228")
    stubble = L.hexc("#5A5446")
    parts = []
    skin_parts = []
    n0 = len(parts)
    P._zone_head(parts, [(lambda u, v: u > 44 or (abs(v) > 64 and u > 16) or abs(u) > 128, hair, 0.01, 0.008, 0.14),
                         (lambda u, v: -118 < u < -20 and abs(v) < 84 and not (u > -42 and abs(v) < 20), stubble,
                          0.003, 0.002, 0.3)], seed=51)
    P._face(parts, L.scale_c(hair, 1.1))
    P._neck(parts)
    skin_parts += parts[n0:]

    def zone(x, a, co):
        if abs(a - 90.0) < 4.0 + max(0.0, x - 0.4) * 120.0 and x > 0.4:
            return L.hexc("#57524A")                                  # a grey shirt where the coat gapes
        return L.scale_c(COAT5, P._crease(co, 0.1, 0.46, 60.0, 0.14))
    P._torso(parts, zone, P._torso_fold, seed=52)
    for sy in (-1, 1):  # wide lapels of a coat that is too big for him
        def lapel(x, sy=sy):
            a = 90.0 - sy * (6.0 + max(0.0, x - 0.4) * 120.0)
            return (a - 22.0, a + 1.0) if sy > 0 else (a - 1.0, a + 22.0)
        parts.append(P._cloth(P._patch(P.TORSO, (0.28, 0.36, 0.44, 0.53), lapel, 0.012, P._torso_fold, name="lapel"),
                              P._flat(COAT5_DARK), seed=53))
    _patch(parts, 0.2, 60.0, P.TORSO, 0.012, (0.045, 0.04), PATCH_A, 54)
    P._buttons(parts, (0.1, 0.19, 0.28), L.hexc("#2E2A25"), lift=0.012)
    parts.append(P._cloth(P._patch(P.TORSO, (0.015, 0.06), (66, 78, 90, 102, 114), 0.012, P._torso_fold, name="belt"),
                          P._flat(P.LEATHER), seed=55))
    # the buckle that does not match: round, brass, too fine for a gravekeeper's belt
    bpos = P._on_loft(P.TORSO, 0.038, 90.0, 0.02, P._torso_fold)
    parts.append(P._blob("cyl", (0.03, 0.03, 0.006), bpos, (0, 0, 1), (1, 0, 0),
                         fn=lambda lc, poly: P.BRASS if Vector((lc.x, lc.y)).length > 0.016 else L.scale_c(P.BRASS, 0.7),
                         vertices=10, ao=0.0, top=0.35))
    P._arms(parts, COAT5, cuff=COAT5_DARK, patch=PATCH_B, seed=56)
    n0 = len(parts)
    P._hands(parts, lift=0.012)
    skin_parts += parts[n0:]
    # the coat skirt over the legs, open at the front below the knees, patched
    def skirt_fn(co, poly):
        c = COAT5 if abs(co.y) > 0.03 or co.x > -0.36 else L.scale_c(COAT5_DARK, 0.8)
        return L.scale_c(c, 1.0 - 0.12 * max(0.0, math.sin(co.y * 70.0 + co.x * 6.0)) ** 4)
    parts.append(_over_legs_loft(skirt_fn, -0.56, 57, width=0.21))
    secs = [(-0.1, 0.0, 0.1, 0.182, 0.078, 0.1), (-0.3, 0.0, 0.097, 0.21, 0.072, 0.097),
            (-0.5, 0.0, 0.092, 0.208, 0.064, 0.092)]
    _patch(parts, -0.28, 55.0, secs, 0.016, (0.05, 0.04), PATCH_B, 58)
    for sy in (-1, 1):  # shins between hem and boots
        parts.append(P._cloth(P._tube(((-0.55, sy * 0.105, 0.08), (-0.68, sy * 0.108, 0.078)), (0.058, 0.056), 6,
                                      caps=(False, False)), P._flat(trouser), seed=59))
    P._boots(parts, L.hexc("#30281F"))
    _darken(skin_parts, MOOR, 0.42)
    _done(parts, "ph_prop_corpse_05")


# --- S3: Ida Wernstein, the young woman in her travelling coat ------------------------------

def corpse_06():
    """A young woman in a buttoned-up travelling coat (dark rust wool, a stand collar, a row of
    horn buttons, a belt), a chestnut braid over her right shoulder, the dress hem and small
    laced boots below; ink on thumb and forefinger."""
    L.reset(206)
    parts = []
    P._zone_head(parts, [(lambda u, v: u > 30 or abs(v) > 58 or abs(u) > 120, CHESTNUT, 0.018, 0.006, 0.2)],
                 seed=61)
    P._face(parts, L.scale_c(CHESTNUT, 0.9), brow_r=0.006, ears=False)
    P._neck(parts)
    P._torso(parts, lambda x, a, co: L.scale_c(TRAVEL, P._crease(co, 0.08, 0.46, 58.0, 0.12)), P._torso_fold,
             seed=62)
    parts.append(P._cloth(P._patch(P.TORSO, (0.525, 0.555, 0.582), (15, 50, 90, 130, 165), 0.012, name="collar"),
                          P._flat(TRAVEL_DARK), seed=63))
    P._buttons(parts, (0.06, 0.14, 0.22, 0.3, 0.38, 0.46), L.hexc("#6A5A48"), lift=0.008, r=0.01)
    parts.append(P._cloth(P._patch(P.TORSO, (0.0, 0.04), (62, 76, 90, 104, 118), 0.01, P._torso_fold, name="belt"),
                          P._flat(TRAVEL_DARK), seed=64))
    # the braid: from behind her right ear over the shoulder onto the chest
    pts = [P._face_pt(10, -80, 0.01), Vector((0.56, -0.13, 0.19)), Vector((0.49, -0.12, 0.225)),
           Vector((0.41, -0.1, 0.235)), Vector((0.35, -0.085, 0.232))]
    braid = P._tube(pts, (0.026, 0.026, 0.024, 0.02, 0.014), 6, caps=(False, True), name="braid")
    parts.append(P._cloth(braid, lambda co, poly: L.scale_c(CHESTNUT, 1.0 - 0.28 * max(0.0, math.sin(co.x * 180.0))
                                                             ** 2), seed=65))
    parts.append(P._blob("sphere", (0.016, 0.02, 0.01), pts[-1] + Vector((-0.012, 0, 0.004)), (0, 0, 1), (1, 0, 0),
                         color=L.hexc("#4A3A30"), segments=6, ring_count=3, ao=0.0))   # a tie at the end
    P._arms(parts, TRAVEL, cuff=TRAVEL_DARK, seed=66)
    P._hands(parts, lift=0.012)
    # ink on thumb and forefinger of the upper hand
    m = Matrix.Translation(P.WRIST[1] + Vector((0.012, -0.052, 0.022 + 0.012))) @ P._frame((0.05, 0.12, 1.0),
                                                                                            (0.22, -1.0, 0.0))
    for loc in ((0.045, -0.052, 0.014), (0.08, -0.026, 0.008)):
        parts.append(P._blob("ico", (0.009, 0.009, 0.004), m @ Vector(loc), m.to_3x3() @ Vector((0, 0, 1)), (1, 0, 0),
                             color=INK, subdivisions=1, ao=0.0, top=0.0))
    parts.append(_over_legs_loft(lambda co, poly: L.scale_c(TRAVEL, 0.84 if poly.center.x < -0.6 else 1.0), -0.63, 67))
    for sy in (-1, 1):  # dress hem peeking out, dark stockings, small boots
        parts.append(P._cloth(P._tube(((-0.62, sy * 0.1, 0.082), (-0.68, sy * 0.1, 0.08)), (0.056, 0.054), 6,
                                      caps=(False, False)), P._flat(L.hexc("#4A4046")), seed=68))
        parts.append(P._cloth(P._tube(((-0.68, sy * 0.1, 0.075), (-0.76, sy * 0.1, 0.075)), (0.04, 0.04), 6,
                                      caps=(False, False)), P._flat(L.hexc("#2F2B2E")), seed=69))
    P._boots(parts, L.hexc("#3A2E26"), small=True)
    _done(parts, "ph_prop_corpse_06")


# --- the burial gown ---------------------------------------------------------------------

def corpse_gown():
    """A body in the burial gown: long warm-white linen from the throat to the ankles, a
    drawstring neckline tied in a small bow, gathered cuffs, hands folded on the breast,
    bare pale feet; hair combed smooth (laid out)."""
    L.reset(207)
    hair = L.hexc("#6E6254")
    parts = []
    P._zone_head(parts, [(lambda u, v: u > 38 or (abs(v) > 62 and u > 14) or abs(u) > 126, hair, 0.011, 0.003, 0.22)],
                 seed=71)
    P._face(parts, L.scale_c(hair, 0.95))
    P._neck(parts)

    def gown(co, poly):
        return L.mix(GOWN, GOWN_SHADE, 0.55 * max(0.0, math.sin(co.y * 48.0 + co.x * 3.0)) ** 3)
    P._torso(parts, lambda x, a, co: gown(co, None), P._torso_fold, seed=72, var=0.08)
    # gathered neckline: a rolled edge, the drawstring and a small bow
    parts.append(P._cloth(P._patch(P.TORSO, (0.53, 0.556, 0.58), (15, 50, 90, 130, 165), 0.01, name="neckline"),
                          P._flat(GOWN_SHADE), seed=73))
    tie = P._on_loft(P.TORSO, 0.535, 90.0, 0.016)
    for sy in (-1, 1):
        parts.append(P._blob("sphere", (0.016, 0.012, 0.005), tie + Vector((0.0, sy * 0.013, 0.0)), (0, 0, 1),
                             (0, sy, 0), color=GOWN_TIE, segments=6, ring_count=3, ao=0.0, top=0.3))
        parts.append(P._cloth(P._tube((tie, tie + Vector((-0.03, sy * 0.012, 0.0)), tie + Vector((-0.055, sy * 0.02,
                                                                                               -0.004))),
                                      (0.003, 0.003, 0.0025), 3, caps=(False, False)), P._flat(GOWN_TIE), ao=0.0))
    # a seam down the front of the gown
    seam = [P._on_loft(P.TORSO, x, 90.0, 0.004, P._torso_fold) for x in (0.0, 0.15, 0.3, 0.45, 0.52)]
    parts.append(P._cloth(P._tube(seam, [0.004] * 5, 3, caps=(False, False)), P._flat(GOWN_SHADE), ao=0.0))
    P._arms(parts, GOWN, cuff=GOWN_SHADE, seed=74)
    P._hands(parts, lift=0.012)
    parts.append(_over_legs_loft(lambda co, poly: gown(co, poly) if poly.center.x > -0.7 else GOWN_SHADE, -0.74, 75,
                                 width=0.205, hem=0.012))
    P._boots(parts, P.SKIN, small=True)   # bare feet, toes up
    _done(parts, "ph_prop_corpse_gown")


ASSETS = (corpse_05, corpse_06, corpse_gown)


def build(names=None):
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
