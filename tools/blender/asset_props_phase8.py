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
    parts.append(L.part("torus", TWINE, loc=(0, 0, z), major_radius=r, minor_radius=0.004, major_segments=6,
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
            sp = _ell(FIR, (0, 0, 0), (w, 0.012, 0.075), seg=5, rings=3, seed=seed + 30 + k * 2 + j, var=0.2, ao=0.25,
                      hue_shift=FIR_DARK)
            _xf(sp, Matrix.Translation(tip * f) @ _rot_to(d) @ Matrix.Rotation(k * 1.1, 4, "Z"))
            parts.append(sp)
    _twine(parts, 0.0, 0.018)
    return _join(parts, "bouquet_fir")


def bouquet_straw(seed: int = 0):
    """Everlastings (Strohblumen): five round ochre and rust heads. <= 250 tris."""
    parts = []
    tips = _fan(5, 0.05, 0.19, 31 + seed)
    _stems(parts, tips, seed=seed)
    for k, tip in enumerate(tips):
        parts.append(_ell(STRAWFLOWER if k % 2 == 0 else STRAWFLOWER_2, tip, (0.02, 0.02, 0.014), seg=6, rings=3,
                          seed=seed + 40 + k, var=0.18, ao=0.15, top=0.3))
    _twine(parts, 0.0)
    return _join(parts, "bouquet_straw")


def bouquet_rose(seed: int = 0):
    """Christmas roses (Christrosen): four white open blossoms with a greenish heart. <= 250 tris."""
    parts = []
    tips = _fan(4, 0.05, 0.18, 41 + seed)
    _stems(parts, tips, seed=seed)
    for k, tip in enumerate(tips):
        b = _ell(ROSE, (0, 0, 0), (0.026, 0.026, 0.008), seg=5, rings=3, seed=seed + 50 + k, var=0.08, ao=0.0, top=0.3)
        _xf(b, Matrix.Translation(tip) @ _rot_to(tip.normalized() + Vector((0, -0.6, 0))))
        parts.append(b)
        parts.append(_ell(ROSE_HEART, tip + Vector((0, -0.006, 0.003)), (0.008, 0.008, 0.005), seg=3, rings=3,
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


# --- grave care --------------------------------------------------------------------------------------

def _flower_bed(wilted: bool, seed: int):
    """Winter heath cushions and Christmas roses over ~0.6 x 0.9 m of the mound (+Y = towards the head)."""
    rnd = random.Random(seed)
    parts = []
    heath, heath_d = (WILT, WILT_DARK) if wilted else (HEATH, HEATH_DARK)
    leaf = L.scale_c(WILT_DARK, 0.9) if wilted else FIR
    for k in range(6):   # heath cushions: low lumpy domes with a flowering top
        x, y = rnd.uniform(-0.24, 0.24), -0.38 + k * 0.15 + rnd.uniform(-0.03, 0.03)
        r = rnd.uniform(0.07, 0.1)
        o = L.prim("sphere", loc=(x, y, 0.0), radius=1.0, scale=(r, r * 0.9, r * (0.55 if wilted else 0.8)), segments=6,
                   ring_count=4)
        for v in o.data.vertices:
            v.co.z = max(v.co.z, -0.005)
        L.jitter(o, 0.012, 14.0, seed + k)
        _p(o, leaf, var=0.25, ao=0.35, top=0.0, seed=seed + k, hue_shift=STEM_DARK)
        _tint(o, lambda co, nr, h=heath, hd=heath_d: (1.0, h if noise.noise(co * 40.0) > -0.1 else hd,
                                                     0.85 * max(0.0, nr.z) ** 0.7))
        parts.append(o)
    for k in range(4):   # Christmas roses: a leaf rosette and white blossoms (wilted: hanging, brown-grey)
        x, y = (-0.17 if k % 2 else 0.17), -0.3 + k * 0.2
        for j in range(2):
            a = j * math.pi + k
            parts.append(_ell(STEM if not wilted else WILT_DARK, (x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, 0.02),
                              (0.05, 0.022, 0.008), seg=4, rings=3, rot=(0, 0, math.degrees(a)), seed=seed + 20 + j, var=0.2,
                              ao=0.1))
        for j in range(1):
            bx, by = x, y
            hz = 0.11 if not wilted else 0.07
            parts.append(_p(L.tube((bx, by, 0.0), (bx, by - (0.03 if wilted else 0.0), hz), 0.004, 3),
                            STEM if not wilted else WILT_DARK, var=0.1, ao=0.0))
            parts.append(_ell(ROSE if not wilted else WILT, (bx, by - (0.04 if wilted else 0.0), hz - (0.02 if wilted else 0.0)),
                              (0.028, 0.028, 0.009), seg=5, rings=3, rot=(70 if wilted else 0, 0, 0), seed=seed + 30 + j,
                              var=0.1, ao=0.0, top=0.3))
    return parts


def prop_grave_flowers():
    L.reset(8601)
    finish_stable(_join(_flower_bed(False, 7), "ph_prop_grave_flowers"), "ph_prop_grave_flowers", "props", 50)


def prop_grave_flowers_wilted():
    L.reset(8601)
    finish_stable(_join(_flower_bed(True, 7), "ph_prop_grave_flowers_wilted"), "ph_prop_grave_flowers_wilted", "props", 50)


def prop_wax_wreath():
    """A wax wreath (Wachskranz): a pale ring of too smooth, too even blossoms and leaves, a bow. <= 600."""
    L.reset(8603)
    parts = [L.part("torus", L.hexc("#BDB59E"), loc=(0, 0, 0.03), major_radius=0.17, minor_radius=0.03, major_segments=14,
                    minor_segments=4, paint_kw={"ao": 0.15, "var": 0.04, "top": 0.4})]
    for k in range(12):
        a = math.tau * k / 12
        c = Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0.055))
        parts.append(_ell(L.hexc("#DCD6C6") if k % 3 else L.hexc("#C9C2CC"), c, (0.026, 0.026, 0.014), seg=5, rings=3,
                          seed=k, var=0.03, ao=0.0, top=0.4))
        parts.append(_ell(L.hexc("#8E9A84"), c + Vector((math.cos(a + 0.3) * 0.03, math.sin(a + 0.3) * 0.03, -0.01)),
                          (0.03, 0.012, 0.006), seg=4, rings=3, rot=(0, 0, math.degrees(a) + 60), seed=40 + k, var=0.03, ao=0.0,
                          top=0.3))
    for sx in (-1, 1):
        parts.append(_ell(L.hexc("#B8B0A0"), (sx * 0.035, -0.18, 0.05), (0.035, 0.012, 0.022), seg=6, rings=3, seed=60, var=0.05))
    finish_stable(_join(parts, "ph_prop_wax_wreath"), "ph_prop_wax_wreath", "props", 50)


def grave_candle(name: str = "ph_prop_grave_candle"):
    """A grave candle in its glass (Grablicht): a squat glass cup with a tin rim, the wax inside, the flame
    (mat_emissive_warm). One mesh, MultiMesh-ready. <= 120 tris."""
    parts = []
    parts.append(_p(L.prim("cyl", loc=(0, 0, 0.055), radius=0.032, depth=0.11, vertices=7), L.hexc("#8A7A5E"), var=0.05,
                    ao=0.3, top=0.2))
    parts.append(_p(L.prim("cyl", loc=(0, 0, 0.112), radius=0.034, depth=0.008, vertices=7), TIN_DARK, var=0.1, ao=0.0,
                    top=0.4))
    parts.append(_p(L.prim("cyl", loc=(0, 0, 0.09), radius=0.027, depth=0.012, vertices=7), WAX, var=0.05, ao=0.0, top=0.3))
    flame = L.prim("cone", loc=(0, 0, 0.125), radius1=0.009, radius2=0.0, depth=0.04, vertices=5)
    L.paint(flame, GLASS, var=0.0, ao=0.0, top=0.0)
    L.set_mat(flame, L.MAT_EMISSIVE)
    parts.append(flame)
    return _join(parts, name)


def prop_grave_candle():
    L.reset(8604)
    finish_stable(grave_candle(), "ph_prop_grave_candle", "props", 40)


def _strap(parts, a, b, wd: float = 0.022, th: float = 0.008, col=None):
    a, b = Vector(a), Vector(b)
    o = L.prim("cube", scale=(wd / 2, th / 2, (b - a).length / 2))
    o.data.transform(Matrix.Translation((a + b) / 2) @ _rot_to(b - a))
    parts.append(_p(o, col or IRON, var=0.2, ao=0.1, top=0.3, hue_shift=IRON_LIGHT))


def prop_mortsafe():
    """An iron grave cage (Grabgitter) over a 1 x 2 m plot, 1.05 m high: flat-strap bars, a top frame with
    cross straps, little spear tips at the corners. <= 1 200 tris."""
    L.reset(8605)
    parts = []
    w, d, h = 0.5, 1.02, 1.0
    for sy in (-1, 1):   # long sides
        for k in range(11):
            y = -d + k * (2 * d / 10)
            _strap(parts, (sy * w, y, 0.0), (sy * w, y, h))
        _strap(parts, (sy * w, -d, 0.15), (sy * w, d, 0.15), 0.03)
        _strap(parts, (sy * w, -d, h), (sy * w, d, h), 0.03)
    for sx in (-1, 1):   # head and foot ends
        for k in range(1, 5):
            x = -w + k * (2 * w / 5)
            _strap(parts, (x, sx * d, 0.0), (x, sx * d, h))
        _strap(parts, (-w, sx * d, 0.15), (w, sx * d, 0.15), 0.03)
        _strap(parts, (-w, sx * d, h), (w, sx * d, h), 0.03)
    for k in range(5):   # cross straps over the top
        y = -d + k * (2 * d / 4)
        _strap(parts, (-w, y, h + 0.01), (w, y, h + 0.01), 0.026)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_p(L.prim("cone", loc=(sx * w, sy * d, h + 0.05), radius1=0.022, radius2=0.0, depth=0.08, vertices=4),
                            IRON, var=0.1, ao=0.0, top=0.4))
    finish_stable(_join(parts, "ph_prop_mortsafe"), "ph_prop_mortsafe", "props", 30)


def _ground(obj, color, seed: int, **kw):
    L.paint(obj, color, seed=seed, **kw)
    L.set_mat(obj, L.MAT_GROUND)
    return obj


def prop_grave_disturbed():
    """Earth thrown up at the foot end of a grave: a loose heap beside a dug-over patch with spade cuts; only
    earth (mat_ground), never a hole down to the dead. <= 800 tris."""
    L.reset(8606)
    rnd = random.Random(8)
    parts = []
    heap = L.prim("sphere", radius=1.0, scale=(0.42, 0.3, 0.2), segments=14, ring_count=7)
    for v in heap.data.vertices:
        v.co.z = max(v.co.z, -0.01)
    L.jitter(heap, 0.04, 5.0, 3)
    L.jitter(heap, 0.015, 14.0, 4)
    parts.append(_ground(heap, EARTH, 5, var=0.3, ao=0.3, top=0.1, noise_freq=3.0, hue_shift=EARTH_DARK))
    dug = L.prim("grid", x_subdivisions=6, y_subdivisions=4, size=1.0, scale=(0.8, 0.45, 1.0), loc=(0.0, 0.42, 0.012))
    L.jitter(dug, 0.02, 9.0, 6)
    parts.append(_ground(dug, EARTH_DARK, 7, var=0.3, ao=0.0, hue_shift=EARTH))
    for k in range(3):   # spade cuts: straight dark edges in the dug patch
        c = L.prim("cube", loc=(-0.2 + k * 0.2, 0.42 + rnd.uniform(-0.05, 0.05), 0.02), scale=(0.1, 0.012, 0.012),
                   rot=(0, 0, rnd.uniform(-15, 15)))
        parts.append(_ground(c, L.scale_c(EARTH_DARK, 0.7), k, var=0.1, ao=0.0))
    for k in range(10):
        cl = L.prim("ico", loc=(rnd.uniform(-0.55, 0.55), rnd.uniform(-0.35, 0.6), 0.025), radius=rnd.uniform(0.025, 0.05),
                    subdivisions=1)
        L.jitter(cl, 0.01, 20.0, k)
        parts.append(_ground(cl, EARTH, k, var=0.25, ao=0.2))
    finish_stable(_join(parts, "ph_prop_grave_disturbed"), "ph_prop_grave_disturbed", "props", 50)


def _coin(at, seed: int = 0, radius: float = 0.016, color=None):
    return L.part("cyl", color or COIN, loc=at, radius=radius, depth=0.004 if radius < 0.02 else 0.007, vertices=8, seed=seed,
                  paint_kw={"ao": 0.0, "top": 0.5, "var": 0.12})


def prop_tip_coins():
    """Two coins and a third under a folded note, lying on the stone. <= 150 tris.
    W3 (G8 p8_06): read at the play zoom - coins of 6 cm and a paler brass, the note 13 cm (the diorama scale of
    the small props, like the grave candle)."""
    L.reset(8607)
    brass = L.hexc("#B39557")
    parts = [_coin((-0.045, 0.0, 0.004), 0, 0.03, brass), _coin((0.01, 0.034, 0.004), 1, 0.03, brass),
             _coin((0.05, -0.02, 0.011), 2, 0.03, brass)]
    note = L.prim("grid", x_subdivisions=2, y_subdivisions=1, size=1.0, scale=(0.12, 0.08, 1.0))
    for v in note.data.vertices:
        v.co.z = 0.01 * (1.0 - abs(v.co.x) / 0.06)   # folded once, the crease up
    note.data.transform(Matrix.Translation((0.045, -0.01, 0.016)) @ Matrix.Rotation(math.radians(18), 4, "Z"))
    parts.append(_p(note, PAPER, var=0.05, ao=0.0, top=0.3))
    finish_stable(_join(parts, "ph_prop_tip_coins"), "ph_prop_tip_coins", "props", 40)


# --- the apprentice's corner ----------------------------------------------------------------------------

_LETTERS = {   # chalk letters J a k o b as polylines in a 1 x 1 cell (u right, v up)
    "J": [[(0.2, 1.0), (0.8, 1.0)], [(0.55, 1.0), (0.55, 0.2), (0.35, 0.0), (0.15, 0.2)]],
    "a": [[(0.8, 0.6), (0.3, 0.6), (0.15, 0.3), (0.35, 0.0), (0.8, 0.2)], [(0.8, 0.6), (0.8, 0.0)]],
    "k": [[(0.2, 1.0), (0.2, 0.0)], [(0.75, 0.65), (0.2, 0.3), (0.8, 0.0)]],
    "o": [[(0.5, 0.65), (0.15, 0.35), (0.5, 0.0), (0.85, 0.35), (0.5, 0.65)]],
    "b": [[(0.2, 1.0), (0.2, 0.0), (0.7, 0.05), (0.8, 0.35), (0.5, 0.6), (0.2, 0.45)]],
}


def _chalk(parts, pts, r: float = 0.0035):
    parts.append(_p(sweep([Vector(p) for p in pts], r, n=3, name="chalk"), CHALK, var=0.12, ao=0.0, top=0.0))


def prop_chalkboard():
    """The slate on two legs at the hut (0.9 x 0.56 m board, top 1.37 m): a wooden frame with "Jakob" chalked on
    the top rail, three lines of chalk strokes with tally marks (no other text), a chalk stub on the ledge.
    Front = -Y. <= 600 tris."""
    L.reset(8608)
    parts = []
    bz0, bz1, hw = 0.76, 1.32, 0.45
    parts.append(_p(L.prim("cube", loc=(0, 0, (bz0 + bz1) / 2), scale=(hw, 0.012, (bz1 - bz0) / 2)), SLATE, var=0.1, ao=0.0,
                    top=0.0, hue_shift=L.hexc("#3A3E3A")))
    for (x, z, sx, sz) in ((0, bz1 + 0.025, hw + 0.04, 0.03), (0, bz0 - 0.025, hw + 0.04, 0.03),
                           (-hw - 0.02, (bz0 + bz1) / 2, 0.03, 0.33), (hw + 0.02, (bz0 + bz1) / 2, 0.03, 0.33)):
        parts.append(_p(L.prim("cube", loc=(x, 0, z), scale=(sx, 0.02, sz)), WOOD, var=0.2, ao=0.1, top=0.3, hue_shift=WOOD_DARK))
    for sx in (-1, 1):   # the legs, splayed backwards
        parts.append(_p(L.tube((sx * 0.4, 0.08, 0.0), (sx * 0.42, 0.0, bz1), 0.022, 4), WOOD_DARK, var=0.2, ao=0.1))
    parts.append(_p(L.prim("cube", loc=(0, -0.035, bz0 - 0.01), scale=(hw, 0.025, 0.008)), WOOD, var=0.2, ao=0.0))
    parts.append(_p(L.prim("cube", loc=(0.25, -0.04, bz0 + 0.006), scale=(0.02, 0.006, 0.006)), CHALK, var=0.05, ao=0.0))
    cell, x0, zb = 0.03, -0.09, bz1 + 0.01   # "Jakob" on the top rail (the only text)
    for i, ch in enumerate("Jakob"):
        for stroke in _LETTERS[ch]:
            _chalk(parts, [(x0 + i * cell * 1.15 + u * cell * 0.9, -0.022, zb + v * cell * 1.1) for u, v in stroke], 0.0022)
    for row in range(3):   # three lines: a short scrawl, then tally marks (the levels)
        z = bz1 - 0.12 - row * 0.15
        _chalk(parts, [(-0.38, -0.014, z), (-0.3, -0.014, z + 0.03), (-0.22, -0.014, z - 0.01), (-0.12, -0.014, z + 0.02),
                       (-0.04, -0.014, z)])
        for k in range(row % 3 + 1):
            _chalk(parts, [(0.12 + k * 0.035, -0.014, z - 0.04), (0.12 + k * 0.035, -0.014, z + 0.04)])
    finish_stable(_join(parts, "ph_prop_chalkboard"), "ph_prop_chalkboard", "props", 30)


def prop_apprentice_box():
    """Jakob's chest (0.6 x 0.36 m, 0.36 high): planks, iron bands, a hasp; on the lid the wage tin (Lohndose).
    <= 500 tris."""
    L.reset(8609)
    parts = []
    body = L.prim("cube", loc=(0, 0, 0.16), scale=(0.3, 0.18, 0.16))
    L.bevel(body, 0.01, 1)
    _p(body, WOOD, var=0.22, ao=0.3, top=0.2, hue_shift=WOOD_DARK)
    _tint(body, lambda co, nr: (1.0 - 0.18 * max(0.0, math.sin(co.z * 60.0)), None, 0.0))
    parts.append(body)
    lid = L.prim("cube", loc=(0, 0, 0.34), scale=(0.31, 0.19, 0.025))
    L.bevel(lid, 0.01, 1)
    parts.append(_p(lid, WOOD_PALE, var=0.2, ao=0.0, top=0.3, hue_shift=WOOD))
    for sx in (-1, 1):
        parts.append(_p(L.prim("cube", loc=(sx * 0.22, 0, 0.18), scale=(0.018, 0.186, 0.17)), IRON, var=0.2, ao=0.1, top=0.3))
    parts.append(_p(L.prim("cube", loc=(0, -0.19, 0.29), scale=(0.022, 0.006, 0.04)), IRON, var=0.1, ao=0.0))
    parts.append(_p(L.prim("cyl", loc=(0.12, 0.02, 0.39), radius=0.045, depth=0.05, vertices=10), TIN, var=0.15, ao=0.1, top=0.4,
                    hue_shift=TIN_DARK))
    parts.append(_p(L.prim("cyl", loc=(0.12, 0.02, 0.418), radius=0.047, depth=0.008, vertices=10), TIN_DARK, var=0.1, ao=0.0,
                    top=0.5))
    finish_stable(_join(parts, "ph_prop_apprentice_box"), "ph_prop_apprentice_box", "props", 30)


def prop_apprentice_bench():
    """A low plank bench at the hut (1.1 m, seat 0.38 m - Jakob's sit_eat), pegged legs. <= 400 tris."""
    L.reset(8610)
    parts = []
    seat = L.prim("cube", loc=(0, 0, 0.36), scale=(0.55, 0.13, 0.025))
    L.bevel(seat, 0.008, 1)
    L.jitter(seat, 0.004, 5.0, 1)
    parts.append(_p(seat, WOOD_PALE, var=0.22, ao=0.0, top=0.3, hue_shift=WOOD))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(_p(L.tube((sx * 0.45, sy * 0.1, 0.0), (sx * 0.42, sy * 0.06, 0.345), 0.022, 5), WOOD_DARK, var=0.2, ao=0.2))
    finish_stable(_join(parts, "ph_prop_apprentice_bench"), "ph_prop_apprentice_bench", "props", 30)


def prop_rain_barrel():
    """The rain barrel under the hut's eaves: staves, three iron hoops, dark water inside, a board lid half
    across. 0.6 m wide, 0.87 m high. <= 600 tris."""
    L.reset(8611)
    parts = []
    body = loft([(0.0, 0.26, 0.26, 0, 0), (0.42, 0.3, 0.3, 0, 0), (0.85, 0.26, 0.26, 0, 0)], n=14, caps=(True, False), name="barrel")
    _p(body, WOOD, var=0.2, ao=0.3, top=0.2, hue_shift=WOOD_DARK)
    _tint(body, lambda co, nr: (1.0 - 0.22 * max(0.0, math.sin(math.atan2(co.y, co.x) * 7.0)) ** 8, None, 0.0))
    parts.append(body)
    for z in (0.1, 0.42, 0.76):
        r = 0.3 - 0.04 * ((z - 0.42) / 0.42) ** 2 + 0.006
        parts.append(L.part("torus", IRON, loc=(0, 0, z), major_radius=r, minor_radius=0.01, major_segments=14, minor_segments=3,
                            paint_kw={"ao": 0.0, "top": 0.4, "var": 0.15}))
    parts.append(_p(L.prim("cyl", loc=(0, 0, 0.78), radius=0.25, depth=0.005, vertices=12), L.hexc("#2E3634"), var=0.08, ao=0.0,
                    top=0.4))
    parts.append(_p(L.prim("cube", loc=(0.1, 0.0, 0.86), scale=(0.16, 0.28, 0.012)), WOOD_PALE, var=0.2, ao=0.0, top=0.3))
    finish_stable(_join(parts, "ph_prop_rain_barrel"), "ph_prop_rain_barrel", "props", 30)


def prop_peddler_kiepe():
    """Hanne's kiepe set down beside her: the same basket as on her back, standing on the ground."""
    import asset_wanderers as WA
    L.reset(8612)
    finish_stable(WA.kiepe("ph_prop_peddler_kiepe"), "ph_prop_peddler_kiepe", "props", 50)


# --- interior pieces ----------------------------------------------------------------------------------

def int_church_archive():
    """The parish archive: a tall oak cupboard (1.2 x 2.06 m, 0.5 deep) with two panelled doors, iron hinges
    and a lock plate, two drawers below, a cornice; marker `use` in front. Front = -Y. <= 1 200 tris."""
    L.reset(8613)
    parts = []
    body = L.prim("cube", loc=(0, 0, 1.0), scale=(0.6, 0.25, 1.0))
    L.bevel(body, 0.012, 1)
    parts.append(_p(body, WOOD_DARK, var=0.18, ao=0.3, top=0.2, hue_shift=WOOD))
    parts.append(_p(L.prim("cube", loc=(0, -0.01, 2.02), scale=(0.66, 0.29, 0.04)), WOOD_DARK, var=0.15, ao=0.0, top=0.3))
    for sx in (-1, 1):   # doors with two raised panels each
        parts.append(_p(L.prim("cube", loc=(sx * 0.29, -0.255, 1.25), scale=(0.27, 0.01, 0.68)), WOOD, var=0.2, ao=0.1, top=0.2,
                        hue_shift=WOOD_DARK))
        for z in (0.95, 1.55):
            pn = L.prim("cube", loc=(sx * 0.29, -0.27, z), scale=(0.2, 0.008, 0.24))
            L.bevel(pn, 0.012, 1)
            parts.append(_p(pn, WOOD_PALE, var=0.18, ao=0.2, top=0.3, hue_shift=WOOD))
        for z in (0.7, 1.8):
            parts.append(_p(L.prim("cube", loc=(sx * 0.5, -0.27, z), scale=(0.07, 0.006, 0.015)), IRON, var=0.15, ao=0.0, top=0.4))
        parts.append(_p(L.prim("cube", loc=(sx * 0.29, -0.255, 0.3), scale=(0.27, 0.01, 0.2)), WOOD, var=0.2, ao=0.2, top=0.2))
        parts.append(_p(L.prim("cube", loc=(sx * 0.29, -0.27, 0.33), scale=(0.05, 0.008, 0.012)), IRON, var=0.1, ao=0.0))
    parts.append(_p(L.prim("cube", loc=(0, -0.272, 1.22), scale=(0.035, 0.006, 0.05)), IRON, var=0.1, ao=0.0, top=0.4))
    obj = _join(parts, "ph_int_church_archive")
    L.marker(obj, "use", (0.0, -0.85, 0.0))
    finish_stable(obj, "ph_int_church_archive", "interior", 30)


def int_memorial_plate():
    """A small name plate for the memorial board: a dark wooden plate with a bevelled edge and two carved
    lines (no legible text), two nail heads. The back at y = 0, front = -Y. <= 200 tris."""
    L.reset(8614)
    parts = []
    pl = L.prim("cube", loc=(0, -0.01, 0.09), scale=(0.15, 0.01, 0.09))
    L.bevel(pl, 0.01, 1)
    parts.append(_p(pl, WOOD_DARK, var=0.15, ao=0.0, top=0.3, hue_shift=WOOD))
    for w, z in ((0.1, 0.115), (0.07, 0.07)):
        parts.append(_p(L.prim("cube", loc=(0, -0.021, z), scale=(w, 0.002, 0.006)), L.hexc("#C8B88A"), var=0.1, ao=0.0))
    for sx in (-1, 1):
        parts.append(_p(L.prim("cyl", loc=(sx * 0.125, -0.022, 0.09), rot=(90, 0, 0), radius=0.006, depth=0.004, vertices=6),
                        IRON, ao=0.0))
    finish_stable(_join(parts, "ph_int_memorial_plate"), "ph_int_memorial_plate", "interior", 30)


def int_inn_fest_decor():
    """Kathrein decoration for one beam of the Gaststube: a 3 m fir garland sagging between two nails, three
    hanging ribbon pairs (ochre, straw, grey-blue; no red) and a fir bunch at each nail. The nails at z = 0,
    everything hangs below. <= 800 tris."""
    L.reset(8615)
    parts = []
    pts = [Vector((x, 0.0, -0.22 * (1.0 - (x / 1.5) ** 2))) for x in [-1.5 + k * 0.25 for k in range(13)]]
    g = sweep(pts, 0.05, n=6, name="garland")
    L.jitter(g, 0.03, 9.0, 3)
    parts.append(_p(g, FIR, var=0.3, ao=0.3, top=0.2, hue_shift=FIR_DARK))
    cols = (L.hexc("#A8884A"), STRAW, L.hexc("#6A7480"))
    for k, x in enumerate((-0.9, 0.0, 0.9)):
        top = Vector((x, -0.03, -0.22 * (1.0 - (x / 1.5) ** 2)))
        for j in (-1, 1):
            parts.append(_p(sweep([top, top + Vector((j * 0.03, -0.01, -0.18)), top + Vector((j * 0.02, -0.02, -0.36))],
                                  [0.015, 0.014, 0.01], n=4, flat=0.25, name="ribbon"), cols[k], var=0.08, ao=0.0))
    for sx in (-1, 1):
        b = bouquet_fir(seed=sx + 2)
        b.data.transform(Matrix.Translation((sx * 1.5, -0.02, 0.0)) @ Matrix.Rotation(math.radians(180), 4, "X"))
        parts.append(b)
    finish_stable(_join(parts, "ph_int_inn_fest_decor"), "ph_int_inn_fest_decor", "interior", 50, shift=False)


BRONZE = L.hexc("#7C6844")
BRONZE_DARK = L.hexc("#5A4A34")
ROPE = L.hexc("#8A7656")


def prop_gate_bell():
    """G8 Runde 1 (B8-1): the little bell at the graveyard gate - a wrought-iron arm with a curl, screwed to the
    front face of the east gate post (the post face at y = 0, the post behind at +Y, the arm reaching out to -Y), a
    small bronze bell on a yoke and a pull cord with a wooden toggle. The bell, its clapper and the cord are the
    child mesh `bell` (pivot at the yoke) - GateBell swings it when a visitor comes up. The origin is on the ground
    below the mount, the top at 1.78 m (the post is 1.85 m). <= 500 tris."""
    L.reset(8616)
    parts = []
    plate = L.prim("cube", loc=(0, -0.008, 1.66), scale=(0.035, 0.008, 0.12))
    L.bevel(plate, 0.004, 1)
    parts.append(_p(plate, IRON, var=0.15, ao=0.2, top=0.3))
    for z in (1.58, 1.74):
        parts.append(_p(L.prim("cyl", loc=(0, -0.018, z), rot=(90, 0, 0), radius=0.009, depth=0.006, vertices=6), IRON_LIGHT,
                        ao=0.0))
    top = [Vector((0, -0.012, 1.765)), Vector((0, -0.2, 1.768)), Vector((0, -0.37, 1.76))]
    parts.append(_p(sweep(top, 0.008, n=5, name="arm"), IRON, var=0.12, ao=0.0, top=0.4))
    brace = [Vector((0, -0.012, 1.6)), Vector((0, -0.09, 1.64)), Vector((0, -0.18, 1.7)), Vector((0, -0.28, 1.75)),
             Vector((0, -0.33, 1.762))]
    parts.append(_p(sweep(brace, 0.006, n=5, name="brace"), IRON, var=0.12, ao=0.0, top=0.4))
    curl = [Vector((0, -0.37, 1.76)) + Vector((0, -0.035 * math.sin(a), -0.035 * (1.0 - math.cos(a)))) * (1.0 - a / 9.0)
            for a in [k * 0.75 for k in range(8)]]
    parts.append(_p(sweep(curl, 0.005, n=4, name="curl"), IRON, var=0.12, ao=0.0, top=0.4))
    obj = _join(parts, "ph_prop_gate_bell")
    pivot = Vector((0.0, -0.3, 1.752))
    bell_parts = []
    body = loft([(-0.006, 0.014, 0.014, 0, 0), (-0.03, 0.036, 0.036, 0, 0), (-0.075, 0.046, 0.046, 0, 0),
                 (-0.112, 0.068, 0.068, 0, 0), (-0.122, 0.074, 0.074, 0, 0), (-0.118, 0.064, 0.064, 0, 0),
                 (-0.04, 0.026, 0.026, 0, 0)], n=12, caps=(True, False), name="bell_body")
    L.jitter(body, 0.0015, 25.0, 3)
    bell_parts.append(_p(body, BRONZE, var=0.18, ao=0.35, top=0.35, hue_shift=BRONZE_DARK))
    bell_parts.append(_p(L.prim("torus", loc=(0, 0, 0.0), rot=(0, 90, 0), major_radius=0.014, minor_radius=0.004,
                                major_segments=8, minor_segments=3), IRON, ao=0.0, top=0.3))
    bell_parts.append(_p(sweep([Vector((0, 0, -0.03)), Vector((0, 0, -0.1))], 0.003, n=4, name="clapper_rod"), IRON, ao=0.0))
    bell_parts.append(_ell(IRON, (0, 0, -0.106), (0.012, 0.012, 0.014), seg=6, rings=4))
    cord = [Vector((0, 0, -0.11)), Vector((0.004, 0.006, -0.3)), Vector((0.0, 0.01, -0.5)), Vector((-0.003, 0.012, -0.62))]
    bell_parts.append(_p(sweep(cord, 0.005, n=4, name="cord"), ROPE, var=0.2, ao=0.0))
    toggle = L.prim("cyl", loc=(0, 0.012, -0.64), rot=(0, 90, 0), radius=0.013, depth=0.08, vertices=6)
    bell_parts.append(_p(toggle, WOOD, var=0.2, ao=0.1, top=0.3, hue_shift=WOOD_DARK))
    bell = _join(bell_parts, "bell")
    bell.data.transform(Matrix.Scale(1.35, 4))   # readable at play zoom: a 20 cm bell, the toggle at 0.9 m
    bell.location = pivot
    bell.parent = obj
    finish_stable(obj, "ph_prop_gate_bell", "props", 40, shift=False)


PROPS = (prop_grave_flowers, prop_grave_flowers_wilted, prop_wax_wreath, prop_grave_candle, prop_mortsafe,
         prop_grave_disturbed, prop_tip_coins, prop_chalkboard, prop_apprentice_box, prop_apprentice_bench,
         prop_rain_barrel, prop_peddler_kiepe, int_church_archive, int_memorial_plate, int_inn_fest_decor,
         tool_rake_small, tool_watering_can, tool_broom, tool_lantern_hand, tool_spade_robber, tool_lantern_blind,
         prop_tin_cup, prop_bouquet_heath, prop_bouquet_fir, prop_bouquet_straw, prop_bouquet_rose, prop_gate_bell)


def build(names=None):
    """Build all Phase-8 props, or only those whose function name is in `names`."""
    for fn in PROPS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
