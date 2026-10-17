"""Phase 9 props (docs/PHASE9_DESIGN.md §8.4), 'Gemaltes Diorama' - painted vertex colours on the shared
materials; the builders are shared with the figures (asset_stranger, asset_mourners) and the item models
(asset_items PHASE9_ITEMS).

  ph_prop_letter          a letter folded in three, the address in an unpractised hand, a dark wax seal
  ph_prop_letter_open     the same letter opened flat: two creases, a few lines of writing, the broken seal
  ph_prop_case            Brenneisen's brown leather case with the brass lock, standing (<= 0.5 m)
  ph_prop_notebook        his small notebook lying open, the pencil beside it (his table at the inn)
  ph_prop_watch_lantern   the night watchman's lantern hung on his staff, the staff in an iron foot (set down at
                          the Siebers' door at night, ending C): warm panes (mat_lantern_glass), the flame
                          (mat_emissive_warm); marker light_lantern (an omni of the existing pool, no shadow)
  ph_prop_bundle          Johann's bundle: his things knotted in a blue-grey kerchief
  ph_prop_soil_pouch      a handful of grave earth knotted in a linen cloth (what the stranger buys)

Markers: "grip" where a hand takes the letter / the case / the bundle (the figures' child meshes are built from
the same functions). Lying props have their pivot at the bottom centre (z = 0); nothing is higher than 1.4 m.
Run:  python tools/blender/build_all.py asset_props_phase9
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh)
from mathutils import Matrix, Vector

import lib_painted as L
from asset_carter import sweep, _tint
from lib_faces import finish_stable
import asset_props_phase8 as PR

PAPER = L.hexc("#D6CDB4")
PAPER_SHADE = L.hexc("#B2A88E")
PAPER_OLD = L.hexc("#C8BA98")      # the letters from the pockets: older, yellower paper
INK = L.hexc("#3A322C")
SEAL = L.hexc("#5E3A30")           # dark wax, a brown red (muted)
SEAL_DARK = L.hexc("#432822")
KERCHIEF = L.hexc("#4E5660")       # Johann's bundle: a faded blue-grey cotton kerchief
KERCHIEF_DARK = L.hexc("#363C44")
LINEN = L.hexc("#B8AE94")
LINEN_SHADE = L.hexc("#948A72")
EARTH = L.hexc("#4E3E30")
EARTH_DARK = L.hexc("#342A22")
WOOD = L.hexc("#5E4A36")
WOOD_DARK = L.hexc("#463626")
IRON = L.hexc("#3A3C40")
IRON_LIGHT = L.hexc("#5E6166")

LETTER_W, LETTER_D = 0.16, 0.105   # folded (x, y)


def _p(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _lines(parts, x0: float, x1: float, ys, z: float, color=INK, w: float = 0.0018, seed: int = 0):
    """A few lines of writing: thin dark strips of slightly different lengths (nothing legible)."""
    for k, y in enumerate(ys):
        e = x0 + (x1 - x0) * (0.6 + 0.4 * ((k * 5 + seed) % 7) / 6.0)
        parts.append(_p(L.prim("cube", loc=((x0 + e) * 0.5, y, z), scale=((e - x0) * 0.5, w, 0.0006)), color, var=0.1, ao=0.0))


# --- letters -------------------------------------------------------------------------------------------

def letter(seed: int = 0, paper=PAPER_OLD, address: bool = True, sealed: bool = True, name: str = "letter"):
    """A letter folded in three: a flat packet (0.16 x 0.105 m) with a slight bulge along the folds, the flap's
    edge, the address in two or three lines, the wax seal on the flap. ~130 tris."""
    parts = []
    sheet = L.prim("grid", x_subdivisions=4, y_subdivisions=3, size=1.0, scale=(LETTER_W, LETTER_D, 1.0))
    for v in sheet.data.vertices:
        v.co.z = 0.0045 + 0.0025 * math.cos(v.co.x / LETTER_W * math.pi) * math.cos(v.co.y / LETTER_D * math.pi)
    L.jitter(sheet, 0.0008, 30.0, seed)
    from asset_carter import _thicken
    _thicken(sheet, 0.004)
    _p(sheet, paper, var=0.06, ao=0.0, top=0.25, seed=seed, hue_shift=PAPER_SHADE)
    parts.append(sheet)
    # the flap: a slightly lifted strip along the top third
    flap = L.prim("cube", loc=(0.0, LETTER_D * 0.27, 0.0085), scale=(LETTER_W * 0.49, LETTER_D * 0.2, 0.0007))
    parts.append(_p(flap, L.mix(paper, PAPER_SHADE, 0.35), var=0.05, ao=0.0, top=0.2))
    if address:
        _lines(parts, -0.045, 0.06, (-0.012, -0.024, -0.036), 0.0095, seed=seed)
    if sealed:
        seal = L.prim("cyl", loc=(0.0, LETTER_D * 0.1, 0.0105), radius=0.012, depth=0.005, vertices=8)
        L.jitter(seal, 0.0012, 60.0, seed + 3)
        parts.append(_p(seal, SEAL, var=0.12, ao=0.0, top=0.4, hue_shift=SEAL_DARK))
    return L.join(parts, name)


def letter_open(seed: int = 0, paper=PAPER_OLD, name: str = "letter_open"):
    """The letter unfolded: a sheet 0.16 x 0.24 m lying with its two creases (the thirds rise and fall a
    little), lines of writing on the middle and lower thirds, the broken seal at the top. ~160 tris."""
    parts = []
    w, d = LETTER_W, 0.24
    sheet = L.prim("grid", x_subdivisions=3, y_subdivisions=7, size=1.0, scale=(w, d, 1.0))
    for v in sheet.data.vertices:
        t = (v.co.y / d + 0.5) * 3.0           # 0..3 along the sheet: the creases at 1 and 2
        v.co.z = 0.004 + 0.006 * abs(math.sin(t * math.pi)) * (0.6 if t < 1.0 else 1.0)
    L.jitter(sheet, 0.0006, 30.0, seed)
    from asset_carter import _thicken
    _thicken(sheet, 0.0015)
    _p(sheet, paper, var=0.06, ao=0.0, top=0.3, seed=seed, hue_shift=PAPER_SHADE)
    _tint(sheet, lambda co, nr: (0.9 if abs(((co.y / d + 0.5) * 3.0) % 1.0 - 0.0) < 0.04 else 1.0, None, 0.0))
    parts.append(sheet)
    ys = [d * 0.5 - 0.035 - 0.014 * k for k in range(9)]
    _lines(parts, -0.06, 0.06, ys[1:], 0.0115, seed=seed)
    _lines(parts, -0.06, -0.01, ys[:1], 0.0115, seed=seed + 2)   # the salutation
    for k, (dx, dy) in enumerate(((-0.006, 0.0), (0.008, 0.004))):   # the broken seal
        sh = L.prim("cyl", loc=(dx, d * 0.42 + dy, 0.0125), radius=0.0075, depth=0.004, vertices=6)
        L.jitter(sh, 0.0012, 60.0, seed + 5 + k)
        parts.append(_p(sh, SEAL, var=0.12, ao=0.0, top=0.4, hue_shift=SEAL_DARK))
    return L.join(parts, name)


# --- the stranger's things -------------------------------------------------------------------------------

def notebook_with_pencil(seed: int = 0, name: str = "notebook"):
    """His notebook lying open on the table, the pencil beside it (the figure's own notebook and pencil)."""
    import asset_stranger as S
    nb = S.notebook(seed=seed)
    nb.data.transform(Matrix.Translation((0.0, 0.0, 0.008)))
    pc = S.pencil()
    pc.data.transform(Matrix.Translation((0.115, -0.02, 0.006)) @ Matrix.Rotation(math.radians(-80), 4, "X")
                      @ Matrix.Rotation(math.radians(8), 4, "Y"))
    return L.join([nb, pc], name)


def case_standing(seed: int = 0, name: str = "case"):
    import asset_stranger as S
    return S.case(Vector((0.0, 0.0, S.CASE_H + S.CASE_DROP)), seed=seed, name=name)


# --- Johann's bundle, the soil pouch -----------------------------------------------------------------------

def bundle(at: Vector = Vector((0.0, 0.0, 0.0)), seg: int = 8, seed: int = 0, name: str = "bundle"):
    """Johann's bundle: a soft round load (0.3 x 0.22 x 0.2 m) knotted in a blue-grey kerchief - the knot on
    top with two short ears, a fold running down the side. `at` = the knot's top (the grip). <= 160 tris
    at seg 8."""
    parts = []
    c = Vector(at) - Vector((0.0, 0.0, 0.13))
    body = L.prim("sphere", loc=c, radius=1.0, segments=seg, ring_count=max(4, seg // 2 + 1), scale=(0.15, 0.11, 0.1))
    for v in body.data.vertices:
        if v.co.z < c.z - 0.06:
            v.co.z = c.z - 0.06 - (c.z - 0.06 - v.co.z) * 0.4   # it sits flat on what it lies on
        if v.co.z > c.z + 0.05:   # gathered towards the knot
            k = (v.co.z - c.z - 0.05) / 0.05
            v.co.x = c.x + (v.co.x - c.x) * (1.0 - 0.55 * k)
            v.co.y = c.y + (v.co.y - c.y) * (1.0 - 0.55 * k)
    L.jitter(body, 0.008, 9.0, seed)
    _p(body, KERCHIEF, var=0.18, ao=0.25, top=0.3, seed=seed, hue_shift=KERCHIEF_DARK)
    _tint(body, lambda co, nr: (1.0 - 0.14 * max(0.0, math.sin((co.x - c.x) * 60.0 + (co.z - c.z) * 30.0)), None, 0.0))
    parts.append(body)
    knot = L.prim("sphere", loc=c + Vector((0.0, 0.0, 0.105)), radius=1.0, segments=6, ring_count=4, scale=(0.035, 0.03, 0.025))
    parts.append(_p(knot, KERCHIEF_DARK, var=0.15, ao=0.0, top=0.3))
    for sx in (-1, 1):
        ear = L.prim("cone", loc=c + Vector((sx * 0.04, 0.0, 0.115)), radius1=0.018, radius2=0.004, depth=0.05, vertices=4,
                     rot=(0, sx * 65, 0))
        parts.append(_p(ear, KERCHIEF, var=0.15, ao=0.0, top=0.3, hue_shift=KERCHIEF_DARK))
    return L.join(parts, name)


def soil_pouch(seed: int = 0, name: str = "soil_pouch"):
    """A handful of grave earth knotted in a linen cloth (0.12 m): the round full cloth, the twisted neck and
    the knot, a few crumbs of dark earth at the opening and beside it. ~150 tris."""
    parts = []
    body = L.prim("sphere", loc=(0, 0, 0.045), radius=1.0, segments=8, ring_count=5, scale=(0.06, 0.055, 0.045))
    for v in body.data.vertices:
        v.co.z = max(v.co.z, 0.004)
    L.jitter(body, 0.004, 14.0, seed)
    _p(body, LINEN, var=0.14, ao=0.25, top=0.3, seed=seed, hue_shift=LINEN_SHADE)
    # earth showing through the cloth near the ground (damp)
    _tint(body, lambda co, nr: (1.0, EARTH, 0.35 * max(0.0, 1.0 - co.z / 0.03)))
    parts.append(body)
    neck = L.prim("cone", loc=(0, 0, 0.1), radius1=0.022, radius2=0.012, depth=0.03, vertices=6)
    parts.append(_p(neck, LINEN_SHADE, var=0.12, ao=0.0, top=0.3))
    for k in range(3):   # the cloth's corners above the knot
        a = math.tau * k / 3 + 0.4
        tip = L.prim("cone", loc=(math.cos(a) * 0.014, math.sin(a) * 0.014, 0.123), radius1=0.01, radius2=0.002, depth=0.028,
                     vertices=4, rot=(math.degrees(math.sin(a)) * 0.5, math.degrees(math.cos(a)) * 0.5, 0))
        parts.append(_p(tip, LINEN, var=0.12, ao=0.0, top=0.3))
    for k, (x, y, r) in enumerate(((0.07, -0.02, 0.008), (0.062, 0.025, 0.006), (-0.065, -0.03, 0.007))):
        cr = L.prim("ico", loc=(x, y, r * 0.6), radius=r, subdivisions=1)
        parts.append(_p(cr, EARTH, var=0.2, ao=0.0, top=0.2, hue_shift=EARTH_DARK))
    return L.join(parts, name)


# --- the night watchman's lantern ------------------------------------------------------------------------

STAFF_H = 1.32


def watch_lantern(name: str = "watch_lantern"):
    """The night watchman's lantern hung on the hook of his staff; the staff stands in a small iron foot (he
    has set it down at the door). The lantern is PR.lantern_hand at 1.5 x (panes on mat_lantern_glass, the
    flame on mat_emissive_warm); <= 1.4 m. Returns (object, centre of the glass)."""
    parts = []
    foot = L.prim("cyl", loc=(0, 0, 0.018), radius=0.12, depth=0.036, vertices=8)
    L.bevel(foot, 0.008, 1)
    parts.append(_p(foot, IRON, var=0.15, ao=0.2, top=0.4, hue_shift=IRON_LIGHT))
    parts.append(_p(L.tube((0, 0, 0.03), (0, 0, STAFF_H), 0.017, 6, r_end=0.015), WOOD, var=0.18, ao=0.1, top=0.3, hue_shift=WOOD_DARK))
    parts.append(_p(L.prim("cone", loc=(0, 0, STAFF_H + 0.03), radius1=0.018, radius2=0.004, depth=0.06, vertices=6), IRON, var=0.1,
                    ao=0.0, top=0.5))
    # the iron arm with the hook near the top, towards the front (-Y)
    arm = [Vector((0, 0, STAFF_H - 0.06)), Vector((0, -0.12, STAFF_H - 0.04)), Vector((0, -0.17, STAFF_H - 0.06)),
           Vector((0, -0.17, STAFF_H - 0.1))]
    parts.append(_p(sweep(arm, 0.006, n=4, name="arm"), IRON, var=0.1, ao=0.0, top=0.4))
    lan = PR.lantern_hand(1.5, "lantern")
    grip = Vector((0, -0.17, STAFF_H - 0.1))
    lan.data.transform(Matrix.Translation(grip))
    parts.append(lan)
    glass_c = grip + Vector((0.0, 0.0, -0.175 * 1.5))
    return L.join(parts, name), glass_c


# --- exports -----------------------------------------------------------------------------------------------

def _export(obj, name: str, markers=(), cat: str = "props", smooth: float = 45.0) -> None:
    for mname, loc in markers:
        L.marker(obj, mname, loc)
    finish_stable(obj, name, cat, smooth)


def prop_letter():
    L.reset(9201)
    _export(letter(seed=1), "ph_prop_letter", [("grip", (LETTER_W * 0.45, 0.0, 0.006))])


def prop_letter_open():
    L.reset(9202)
    _export(letter_open(seed=2), "ph_prop_letter_open", [("grip", (LETTER_W * 0.45, -0.08, 0.006))])


def prop_case():
    import asset_stranger as S
    L.reset(9203)
    _export(case_standing(seed=50), "ph_prop_case", [("grip", (0.0, 0.0, S.CASE_H + S.CASE_DROP))])


def prop_notebook():
    L.reset(9204)
    _export(notebook_with_pencil(seed=60), "ph_prop_notebook")


def prop_watch_lantern():
    L.reset(9205)
    obj, light = watch_lantern("ph_prop_watch_lantern")
    _export(obj, "ph_prop_watch_lantern", [("light_lantern", tuple(light))], smooth=40.0)


def prop_bundle():
    L.reset(9206)
    _export(bundle(Vector((0.0, 0.0, 0.22)), seg=10, seed=3), "ph_prop_bundle", [("grip", (0.0, 0.0, 0.22))])


def prop_soil_pouch():
    L.reset(9207)
    _export(soil_pouch(seed=4), "ph_prop_soil_pouch", [("grip", (0.0, 0.0, 0.12))])


PROPS = (prop_letter, prop_letter_open, prop_case, prop_notebook, prop_watch_lantern, prop_bundle, prop_soil_pouch)


def build(names=None):
    """Build all Phase-9 props, or only those whose function name is in `names`."""
    for fn in PROPS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
