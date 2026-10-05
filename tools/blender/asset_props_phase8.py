"""Phase 8 props, tools and interior pieces (docs/PHASE8_DESIGN.md §8.4), 'Gemaltes Diorama'.

Grave care (on the mound, the stone, the foot end):
  ph_prop_grave_flowers / _wilted   winter heath and Christmas roses planted on the mound (wilted = the same
                                    shapes, brown-grey, the blossoms hanging)
  ph_prop_wax_wreath                a wax wreath: pale, too smooth blossoms
  ph_prop_bouquet_heath/_fir/_straw/_rose   the visitors' bunches as laid on the mound (the same geometry
                                    rides in the visitors' hands as the child mesh `bouquet`)
  ph_prop_grave_candle              a grave candle in its glass (MultiMesh-ready: one mesh, flame on
                                    mat_emissive_warm)
  ph_prop_mortsafe                  an iron grave cage, bars as flat straps, <= 1.1 m
  ph_prop_grave_disturbed           earth thrown up at the foot end, spade marks (mat_ground, no hole)
  ph_prop_tip_coins                 two or three coins and a folded note on the stone
The apprentice's corner: ph_prop_chalkboard ("Jakob" chalked on the frame, strokes, no other text),
  ph_prop_apprentice_box (his chest with the wage tin), ph_prop_apprentice_bench, ph_prop_rain_barrel.
Tools (meshes that ride on the `tool` bone, also exported alone): ph_tool_rake_small, _watering_can,
  _broom, _lantern_hand, _spade_robber, _lantern_blind (the hooded lantern: a lit slit, no light).
Wanderers: ph_prop_peddler_kiepe (the basket set down beside Hanne), ph_prop_tin_cup (Veit's cup).
Interior: ph_int_church_archive (the parish archive cupboard), ph_int_memorial_plate (a small name plate,
  no legible text), ph_int_inn_fest_decor (fir garlands and ribbons for the Kathreintanz).

Tool space (the figures' tool meshes): the grip at the origin, a long tool's shaft along +Z (the head
up: the way a boy carries a rake that is too big for him), a hanging tool (can, lanterns) below the
origin; the figure scripts move them to the fist.
Run:  python tools/blender/build_all.py asset_props_phase8
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
from asset_carter import loft, sweep, _tint
from lib_faces import finish_stable

WOOD = L.hexc("#6E5640")
WOOD_DARK = L.hexc("#4A3A2C")
WOOD_PALE = L.hexc("#8A7258")
IRON = L.hexc("#3A3C40")
IRON_LIGHT = L.hexc("#5E6166")
TIN = L.hexc("#8C8A84")
TIN_DARK = L.hexc("#66645E")
BRASS = L.hexc("#8C7648")
GLASS = L.hexc("#C9B58A")          # glass panes / candle glass: lit warm (mat_emissive_warm)
WAX = L.hexc("#D8CFB8")
STRAW = L.hexc("#A08A58")
TWINE = L.hexc("#8A7A5C")
STEM = L.hexc("#4E5A3A")
STEM_DARK = L.hexc("#3A4630")
HEATH = L.hexc("#9A6A86")          # winter heath: muted mauve-pink (no saturated red)
HEATH_DARK = L.hexc("#6E4A62")
FIR = L.hexc("#3E5238")
FIR_DARK = L.hexc("#2C3A2A")
STRAWFLOWER = L.hexc("#B8984A")    # everlasting: ochre and a little rust
STRAWFLOWER_2 = L.hexc("#A8744A")
ROSE = L.hexc("#D9D2C0")           # Christmas rose: white with a greenish heart
ROSE_HEART = L.hexc("#B8A85A")
WILT = L.hexc("#7A6A58")
WILT_DARK = L.hexc("#5A4E44")
EARTH = L.hexc("#5A4838")
EARTH_DARK = L.hexc("#3E3228")
PAPER = L.hexc("#D3C9B0")
COIN = L.hexc("#8C7A52")
SLATE = L.hexc("#2E3230")
CHALK = L.hexc("#C8C4B8")
RIBBON = L.hexc("#8A3A30")         # the one red: the little band on Hanne's kiepe (§8.4)


def _p(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _ell(color, loc, scale, seg: int = 6, rings: int = 4, rot=(0, 0, 0), seed: int = 0, **kw):
    o = L.prim("sphere", loc=loc, radius=1.0, scale=scale, rot=rot, segments=seg, ring_count=rings)
    return _p(o, color, seed=seed, **kw)


def _xf(obj, m: Matrix):
    obj.data.transform(m)
    return obj


def _rot_to(d: Vector) -> Matrix:
    return Vector((0, 0, 1)).rotation_difference(Vector(d).normalized()).to_matrix().to_4x4()


def _join(parts, name):
    return L.join(parts, name)


# --- bouquets (tool space: the stems' grip at the origin, blossoms up +Z) ----------------------------

def _stems(parts, tips, color=STEM, r: float = 0.0045, seed: int = 0):
    for k, tip in enumerate(tips):
        parts.append(_p(L.tube((0, 0, -0.07), tip, r, 4, r_end=r * 0.7), color, var=0.12, ao=0.0, seed=seed + k))


def _twine(parts, z: float = 0.0, r: float = 0.016):
    parts.append(L.part("torus", TWINE, loc=(0, 0, z), major_radius=r, minor_radius=0.004, major_segments=8,
                        minor_segments=3, paint_kw={"ao": 0.0, "var": 0.1}))


def _fan(n: int, spread: float, length: float, seed: int):
    rnd = random.Random(seed)
    out = []
    for k in range(n):
        a = math.tau * k / n + rnd.uniform(-0.3, 0.3)
        r = spread * (0.4 + 0.6 * ((k * 7) % n) / max(1, n - 1))
        out.append(Vector((math.cos(a) * r, math.sin(a) * r * 0.7, length * rnd.uniform(0.85, 1.05))))
    return out


def bouquet_heath(seed: int = 0):
    """Winter heath: five stems with mauve flower spikes, tied with twine. <= 250 tris."""
    parts = []
    tips = _fan(5, 0.05, 0.2, 11 + seed)
    _stems(parts, tips, seed=seed)
    for k, tip in enumerate(tips):
        d = tip.normalized()
        sp = _ell(HEATH, (0, 0, 0), (0.016, 0.016, 0.05), seg=5, rings=4, seed=seed + 20 + k, var=0.2, ao=0.2,
                  hue_shift=HEATH_DARK)
        _xf(sp, Matrix.Translation(tip - d * 0.035) @ _rot_to(d))
        parts.append(sp)
    _twine(parts, 0.0)
    return _join(parts, "bouquet_heath")


def bouquet_fir(seed: int = 0):
    """Fir sprigs (Tannengrün): three flat dark sprays on short twigs. <= 250 tris."""
    parts = []
    tips = _fan(3, 0.06, 0.22, 21 + seed)
    _stems(parts, tips, color=WOOD_DARK, r=0.005, seed=seed)
    for k, tip in enumerate(tips):
        d = tip.normalized()
        for j, (f, w) in enumerate(((0.55, 0.05), (1.0, 0.04))):
            sp = _ell(FIR, (0, 0, 0), (w, 0.012, 0.075), seg=6, rings=4, seed=seed + 30 + k * 2 + j, var=0.2, ao=0.25,
                      hue_shift=FIR_DARK)
            _xf(sp, Matrix.Translation(tip * f) @ _rot_to(d) @ Matrix.Rotation(k * 1.1, 4, "Z"))
            parts.append(sp)
    _twine(parts, 0.0, 0.018)
    return _join(parts, "bouquet_fir")


def bouquet_straw(seed: int = 0):
    """Everlastings (Strohblumen): six round ochre and rust heads. <= 250 tris."""
    parts = []
    tips = _fan(6, 0.05, 0.19, 31 + seed)
    _stems(parts, tips, seed=seed)
    for k, tip in enumerate(tips):
        parts.append(_ell(STRAWFLOWER if k % 2 == 0 else STRAWFLOWER_2, tip, (0.02, 0.02, 0.014), seg=6, rings=3,
                          seed=seed + 40 + k, var=0.18, ao=0.15, top=0.3))
    _twine(parts, 0.0)
    return _join(parts, "bouquet_straw")


def bouquet_rose(seed: int = 0):
    """Christmas roses (Christrosen): five white open blossoms with a greenish heart. <= 250 tris."""
    parts = []
    tips = _fan(5, 0.05, 0.18, 41 + seed)
    _stems(parts, tips, seed=seed)
    for k, tip in enumerate(tips):
        b = _ell(ROSE, (0, 0, 0), (0.026, 0.026, 0.008), seg=5, rings=3, seed=seed + 50 + k, var=0.08, ao=0.0, top=0.3)
        _xf(b, Matrix.Translation(tip) @ _rot_to(tip.normalized() + Vector((0, -0.6, 0))))
        parts.append(b)
        parts.append(_ell(ROSE_HEART, tip + Vector((0, -0.006, 0.003)), (0.008, 0.008, 0.005), seg=4, rings=3,
                          seed=seed + 60 + k, var=0.1, ao=0.0))
    _twine(parts, 0.0)
    return _join(parts, "bouquet_rose")


BOUQUETS = {"heath": bouquet_heath, "fir": bouquet_fir, "straw": bouquet_straw, "rose": bouquet_rose}


# --- tools (tool space) -------------------------------------------------------------------------------

def lantern_hand(scale: float = 1.0, name: str = "lantern"):
    """A small hand lantern hanging from its ring: iron cage, four warm glass panes (mat_emissive_warm),
    a cap. The ring at the origin, the lantern below. <= 160 tris."""
    s = scale
    parts = []
    parts.append(L.part("torus", IRON, loc=(0, 0, -0.012 * s), rot=(90, 0, 0), major_radius=0.016 * s, minor_radius=0.003 * s,
                        major_segments=8, minor_segments=3, paint_kw={"ao": 0.0, "top": 0.4}))
    cap = L.prim("cone", loc=(0, 0, -0.05 * s), radius1=0.045 * s, radius2=0.012 * s, depth=0.035 * s, vertices=6)
    parts.append(_p(cap, IRON, var=0.15, ao=0.0, top=0.4))
    glass = L.prim("cyl", loc=(0, 0, -0.115 * s), radius=0.036 * s, depth=0.1 * s, vertices=6)
    L.paint(glass, GLASS, var=0.05, ao=0.0, top=0.0)
    L.set_mat(glass, L.MAT_EMISSIVE)
    parts.append(glass)
    for k in range(6):
        a = math.tau * (k + 0.5) / 6
        x, y = math.cos(a) * 0.039 * s, math.sin(a) * 0.039 * s
        parts.append(_p(L.tube((x, y, -0.068 * s), (x, y, -0.165 * s), 0.0035 * s, 3), IRON, var=0.1, ao=0.0))
    base = L.prim("cyl", loc=(0, 0, -0.17 * s), radius=0.042 * s, depth=0.014 * s, vertices=6)
    parts.append(_p(base, IRON, var=0.15, ao=0.0, top=0.3))
    return _join(parts, name)


def lantern_blind(name: str = "lantern_blind"):
    """A hooded (dark) lantern: a tin box with a slid-shut door, one lit slit (mat_emissive_warm), a bail
    handle. The handle at the origin. <= 120 tris."""
    parts = []
    parts.append(_p(sweep([Vector((-0.03, 0, -0.04)), Vector((0, 0, 0.0)), Vector((0.03, 0, -0.04))], 0.003, n=3,
                          name="bail"), IRON, ao=0.0))
    box = L.prim("cyl", loc=(0, 0, -0.12), radius=0.045, depth=0.14, vertices=8)
    parts.append(_p(box, TIN_DARK, var=0.18, ao=0.2, top=0.3, hue_shift=IRON))
    top = L.prim("cone", loc=(0, 0, -0.035), radius1=0.048, radius2=0.015, depth=0.03, vertices=8)
    parts.append(_p(top, TIN_DARK, var=0.15, ao=0.0, top=0.4))
    slit = L.prim("cube", loc=(0, -0.046, -0.12), scale=(0.006, 0.004, 0.035))
    L.paint(slit, GLASS, var=0.05, ao=0.0, top=0.0)
    L.set_mat(slit, L.MAT_EMISSIVE)
    parts.append(slit)
    return _join(parts, name)


def rake_small(name: str = "rake"):
    """The children's rake (Kinderrechen) - still too long for a boy: a 1.25 m ash handle, a short
    wooden head with nine teeth. Grip at the origin, 0.3 m above the butt; the head up (+Z), the teeth
    facing forward (-Y). <= 300 tris."""
    parts = [_p(L.tube((0, 0, -0.3), (0, 0, 0.95), 0.014, 5, r_end=0.012), WOOD_PALE, var=0.18, ao=0.0, top=0.2,
                hue_shift=WOOD)]
    head = L.prim("cube", loc=(0, 0, 0.97), scale=(0.17, 0.018, 0.02))
    L.bevel(head, 0.006, 1)
    parts.append(_p(head, WOOD, var=0.2, ao=0.1, top=0.3, hue_shift=WOOD_DARK))
    for k in range(9):
        x = -0.15 + k * 0.0375
        parts.append(_p(L.tube((x, -0.01, 0.97), (x, -0.075, 0.985), 0.0045, 3), WOOD_DARK, var=0.1, ao=0.0))
    return _join(parts, name)


def watering_can(name: str = "watering_can"):
    """A tin watering can hanging from its bow handle: the handle at the origin, the round body below, the
    long spout forward (-Y) with a rose. <= 300 tris."""
    parts = []
    body = loft([(-0.32, 0.075, 0.075, 0, 0), (-0.2, 0.082, 0.082, 0, 0), (-0.12, 0.072, 0.072, 0, 0),
                 (-0.1, 0.03, 0.03, 0, 0)], n=10, name="can")
    parts.append(_p(body, TIN, var=0.15, ao=0.25, top=0.35, hue_shift=TIN_DARK))
    bow = [Vector((0, 0.07, -0.13)), Vector((0, 0.05, -0.03)), Vector((0, 0.0, 0.0)), Vector((0, -0.05, -0.03)),
           Vector((0, -0.07, -0.13))]
    parts.append(_p(sweep(bow, 0.008, n=4, name="bow"), TIN_DARK, var=0.1, ao=0.0, top=0.4))
    sp0, sp1 = Vector((0, -0.06, -0.29)), Vector((0, -0.28, -0.13))
    parts.append(_p(L.tube(sp0, sp1, 0.014, 5, r_end=0.009), TIN, var=0.12, ao=0.0, top=0.3))
    rose = L.prim("cone", radius1=0.012, radius2=0.026, depth=0.035, vertices=8)
    _xf(rose, Matrix.Translation(sp1 + (sp1 - sp0).normalized() * 0.015) @ _rot_to(sp1 - sp0))
    parts.append(_p(rose, TIN_DARK, var=0.1, ao=0.0, top=0.3))
    return _join(parts, name)


def broom(name: str = "broom"):
    """A birch broom (Reisigbesen): a 1.1 m handle, the twig bundle bound with withies; grip at the
    origin, the bundle up (+Z). <= 300 tris."""
    parts = [_p(L.tube((0, 0, -0.25), (0, 0, 0.75), 0.014, 5), WOOD_PALE, var=0.18, ao=0.0, top=0.2, hue_shift=WOOD)]
    bundle = loft([(0.72, 0.03, 0.03, 0, 0), (0.85, 0.05, 0.045, 0, 0), (1.05, 0.085, 0.06, 0, 0),
                   (1.12, 0.07, 0.05, 0, 0)], n=8, name="twigs")
    L.jitter(bundle, 0.008, 9.0, 3)
    _p(bundle, L.hexc("#6A5A44"), var=0.25, ao=0.2, top=0.2, hue_shift=WOOD_DARK)
    _tint(bundle, lambda co, nr: (1.0 - 0.25 * max(0.0, math.sin(math.atan2(co.y, co.x) * 9.0)), None, 0.0))
    parts.append(bundle)
    for z in (0.76, 0.84):
        parts.append(L.part("torus", WOOD_DARK, loc=(0, 0, z), major_radius=0.042 if z > 0.8 else 0.032,
                            minor_radius=0.006, major_segments=8, minor_segments=3, paint_kw={"ao": 0.0}))
    return _join(parts, name)


def spade_robber(name: str = "spade"):
    """Lambert's borrowed spade: a straight ash shaft with a T-grip, a flat worn blade with a step; the grip
    hand at the origin, 0.15 m below the T; the blade up (+Z) in tool space. <= 300 tris."""
    parts = [_p(L.tube((0, 0, -0.15), (0, 0, 0.8), 0.016, 5), WOOD, var=0.2, ao=0.0, top=0.2, hue_shift=WOOD_DARK)]
    parts.append(_p(L.tube((-0.07, 0, -0.16), (0.07, 0, -0.16), 0.015, 5), WOOD_DARK, var=0.15, ao=0.0))
    blade = L.prim("cube", loc=(0, 0, 0.95), scale=(0.095, 0.008, 0.16))
    for v in blade.data.vertices:
        if v.co.z > 1.0:
            v.co.x *= 0.82
    L.bevel(blade, 0.004, 1)
    _p(blade, IRON, var=0.25, ao=0.1, top=0.3, hue_shift=IRON_LIGHT)
    _tint(blade, lambda co, nr: (1.0, IRON_LIGHT, 0.6 if co.z > 1.06 else 0.0))
    parts.append(blade)
    parts.append(_p(L.tube((0, 0, 0.76), (0, 0, 0.82), 0.022, 6), IRON, var=0.1, ao=0.0))
    return _join(parts, name)


def tin_cup(name: str = "tin_cup"):
    """Veit's tin cup: dented, a wire handle; the bottom at the origin. <= 100 tris."""
    cup = loft([(0.0, 0.034, 0.034, 0, 0), (0.07, 0.038, 0.038, 0, 0), (0.075, 0.04, 0.04, 0, 0)], n=10,
               caps=(True, False), name="cup")
    L.jitter(cup, 0.003, 30.0, 5)
    parts = [_p(cup, TIN, var=0.2, ao=0.3, top=0.3, hue_shift=TIN_DARK)]
    parts.append(_p(sweep([Vector((0.038, 0, 0.06)), Vector((0.06, 0, 0.04)), Vector((0.038, 0, 0.015))], 0.003, n=3,
                          name="handle"), TIN_DARK, ao=0.0))
    return _join(parts, name)


def _export_tool(fn, name: str, cat: str = "props"):
    L.reset(8400 + len(name))
    obj = fn(name=name)
    finish_stable(obj, name, cat, 50)


# --- build ---------------------------------------------------------------------------------------------

def tool_rake_small():
    _export_tool(rake_small, "ph_tool_rake_small")


def tool_watering_can():
    _export_tool(watering_can, "ph_tool_watering_can")


def tool_broom():
    _export_tool(broom, "ph_tool_broom")


def tool_lantern_hand():
    _export_tool(lambda name: lantern_hand(1.0, name), "ph_tool_lantern_hand")


def tool_spade_robber():
    _export_tool(spade_robber, "ph_tool_spade_robber")


def tool_lantern_blind():
    _export_tool(lantern_blind, "ph_tool_lantern_blind")


def prop_tin_cup():
    _export_tool(tin_cup, "ph_prop_tin_cup")


def _bouquet_prop(kind: str):
    """The bunch as laid on the mound: lying on its side, the stems towards the foot end."""
    L.reset(8500 + len(kind))
    obj = BOUQUETS[kind]()
    _xf(obj, Matrix.Rotation(math.radians(-80), 4, "X"))
    finish_stable(obj, "ph_prop_bouquet_" + kind, "props", 50)


def prop_bouquet_heath():
    _bouquet_prop("heath")


def prop_bouquet_fir():
    _bouquet_prop("fir")


def prop_bouquet_straw():
    _bouquet_prop("straw")


def prop_bouquet_rose():
    _bouquet_prop("rose")


PROPS = (tool_rake_small, tool_watering_can, tool_broom, tool_lantern_hand, tool_spade_robber, tool_lantern_blind,
         prop_tin_cup, prop_bouquet_heath, prop_bouquet_fir, prop_bouquet_straw, prop_bouquet_rose)


def build(names=None):
    """Build all Phase-8 props, or only those whose function name is in `names`."""
    for fn in PROPS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
