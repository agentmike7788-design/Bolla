"""Phase 8: the new people at the edges (docs/PHASE8_DESIGN.md §2.6, §2.7.1, §8.1), 'Gemaltes Diorama'.

  ph_chr_beggar    Veit Ammer, 58 - once a ferryman: a long patched jacket (Joppe), a knitted fisherman's cap,
                   a grey stubble beard, light watchful eyes; the stiff right leg (stretched in the rest pose),
                   the stick in the left hand (part of the body); the tin cup (child `tin_cup`, arm_r)
  ph_chr_peddler   Hanne Vogelsang, 39 - a weather-tanned laughing face, a headscarf, a coarse woollen skirt,
                   the walking staff in the left hand (body); the tall kiepe on her back (child `kiepe` on
                   spine: wicker, tinware, little bells, ribbons - the one red: a small band); for selling it
                   stands beside her (ph_prop_peddler_kiepe, the switch via show_with)
  ph_chr_robber    Lambert Grell, 33 - gaunt, a dark hooded jacket, an empty sack over the shoulder; the
                   neckerchief pulled up over mouth and nose (`scarf_up`) or down round the neck when he is
                   caught (`scarf_down`: the face is then readable - tired, young, not evil); the borrowed
                   spade on the `tool` bone (9 bones), the hooded lantern (`lantern_blind`, arm_l: a lit slit,
                   no light)
  ph_chr_fiddler   the fiddler from the "Stumpf" - seated, no rig (<= 2 500 tris): the bow arm is its own
                   child mesh `bow` whose origin is the shoulder joint (GDScript rocks it in the festival window)

Child-mesh extras as in asset_mourners ("show_with", for the tools also "carry_with").
Run:  python tools/blender/build_all.py asset_wanderers
"""
import math

import bpy  # must be imported before bmesh
from mathutils import Matrix, Vector

import lib_painted as L
import rig
from asset_carter import loft, sweep, _tint, _n
from asset_villagers import (Prof, _body, _sheet_on, _shoe, _leg_tube, _arm, _ell, _ring_band, _global_light, _joints,
                             _idle, _walk, _talk, _painted, _side, SKIN, SKIN_OLD, BOOT, BOOT_WORN, BLACK, BLACK_SHEEN,
                             LINEN_SHADE, WOOD, WOOD_DARK, LEATHER_DARK)
import asset_villagers as V
from lib_faces import IRIS_BLUE, IRIS_GREY, IRIS_BROWN, IRIS_HAZEL, _s01, Face, _hair, _cloth_cover, _head, _shell, finish_stable
import asset_mourners as M
import asset_apprentice as A
import asset_props_phase8 as PR

W = rig.weight
PLANT = M.PLANT
TOOL = "tool"


def _stubble(parts, face, color, skin, seed: int = 0, top=None):
    beard, _, _ = _shell(face, [(0.0, -0.99)], top=top or [(0.0, -0.7), (0.4, -0.6), (0.8, -0.4), (1.3, -0.14), (1.62, -0.04)],
                         phi=(-1.62, 1.62), out=0.0045, crown=0.0, n=20, m=5, tuck=0.002, seed=seed, name="stubble")
    _painted(beard, color, var=0.2, ao=0.0, top=0.2, seed=seed + 1, hue_shift=skin)
    _tint(beard, lambda co, nr: (1.0, skin, 0.62 + 0.25 * max(0.0, _n(co, 60.0, 3.0))))
    parts.append(W("head", beard))


# ======================================================================================================
# Veit Ammer - the beggar
# ======================================================================================================

VE_COAT = L.hexc("#4E4A40")
VE_COAT_DARK = L.hexc("#36332C")
VE_PATCH = [L.hexc("#5E5444"), L.hexc("#44463E"), L.hexc("#5A4E40")]
VE_TROUSER = L.hexc("#3A3834")
VE_CAP = L.hexc("#3E4448")
VE_CAP_DARK = L.hexc("#2C3034")
VE_HAIR = L.hexc("#8E8a82")
VE_SKIN = L.hexc("#C49478")


def beggar():
    L.reset(8701)
    parts = []
    hip, waist = 0.9, 0.98
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.1
        _shoe(parts, leg, x0, BOOT_WORN, length=0.15, width=0.066, height=0.06, toe=-0.08, shaft=0.14, shaft_r=0.06, seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.14), (sx * 0.103, -0.004, 0.45), (sx * 0.105, 0.0, hip)], [0.06, 0.064, 0.076],
                  VE_TROUSER, n=10, seed=12)
    prof = Prof(((0.56, 0.255, 0.21, 0.02), (0.68, 0.24, 0.198, 0.012), (0.82, 0.222, 0.18, 0.004), (0.95, 0.21, 0.168, 0.0),
                 (1.05, 0.212, 0.17, -0.008), (1.18, 0.222, 0.172, -0.014), (1.3, 0.226, 0.168, -0.012),
                 (1.37, 0.2, 0.15, -0.006), (1.41, 0.15, 0.115, -0.004), (1.44, 0.09, 0.08, -0.008)))
    coat = _body(prof, VE_COAT, VE_COAT_DARK, n=26, seed=3, fold=0.012, fold_top=1.0, part_front=0.2, part_w=0.4, hem_wave=0.014)
    parts.append(rig.weight_split_z(coat, waist, "hips", "spine"))
    for k, (x, z, side) in enumerate(((0.12, 0.7, -1), (-0.1, 1.15, -1), (0.08, 1.05, 1), (-0.14, 0.78, 1))):   # patches
        pp = prof.surf(x, z, side, 0.004)
        parts.append(W("hips" if z < waist else "spine", L.part("cube", VE_PATCH[k % 3], loc=pp, scale=(0.05, 0.004, 0.045),
                                                               rot=(0, 0, 10 * k), paint_kw={"ao": 0.1, "var": 0.18})))
    parts.append(W("hips", _ring_band(prof, waist, 0.012, LEATHER_DARK, out=0.008, seed=4)))
    sh = {sx: Vector((sx * 0.215, -0.006, 1.37)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.265, -0.004, 1.1)) for sx in (-1, 1)}
    wr = {-1: Vector((-0.28, -0.07, 0.87)), 1: Vector((0.27, -0.16, 0.9))}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], VE_COAT, VE_COAT_DARK, r=(0.062, 0.058, 0.052, 0.052),
                         cuff=VE_COAT_DARK, cuff_r=0.062, skin=VE_SKIN, seed=20 + sx * 3, hand_size=1.1, grip=True)
    h = hands[1]
    parts.append(W("arm_l", _painted(L.tube(Vector((h.x + 0.02, h.y - 0.03, 0.0)), h + Vector((0, 0, 0.06)), 0.016, 6, r_end=0.017),
                                     WOOD_DARK, var=0.2, ao=0.0, top=0.3, seed=8)))
    # a wool scarf wound round the neck
    ring = [Vector((math.cos(a) * 0.095, -0.006 + math.sin(a) * 0.085, 1.45 - 0.01 * math.sin(a))) for a in (math.tau * k / 14 for k in range(14))]
    parts.append(W("spine", _painted(sweep(ring, 0.03, n=6, closed=True, name="scarf"), L.hexc("#5A5448"), var=0.2, ao=0.1, seed=5)))
    c = Vector((0.0, -0.04, 1.6))
    s = Vector((0.134, 0.14, 0.15))
    pts = _head(parts, c, s, VE_SKIN, seed=30, nose="hook", nose_s=1.1, brow=VE_HAIR, brow_w=1.2, brow_tilt=0.1, brow_arch=0.6,
                mouth="thin", smile=0.2, cheeks=0.35, jaw=0.94, chin=0.03, age=0.6, lids=0.12, iris=IRIS_BLUE, eyes=1.05,
                muzzle=0.95)
    face = pts["face"]
    _hair(parts, face, VE_HAIR, L.hexc("#6E6A62"), [(0.0, 0.42), (0.6, 0.3), (1.1, 0.04), (1.4, -0.22), (math.pi, -0.42)],
          out=0.005, crown=0.002, tuft=0.008, seed=31)
    _stubble(parts, face, L.hexc("#9A968E"), VE_SKIN, seed=32)
    # the knitted fisherman's cap: a close shell with a rolled brim
    cap, edge = _cloth_cover(parts, face, VE_CAP, VE_CAP_DARK, [(0.0, 0.5), (0.8, 0.42), (1.4, 0.18), (math.pi, 0.02)],
                             out=lambda ph, w: 0.018 + 0.012 * _s01((w - 0.5) / 0.5), crown=0.03, folds=16.0, rim=0.016 * face.k,
                             rim_phi=math.pi, seed=33, name="cap")
    _tint(cap, lambda co, nr: (1.0 - 0.14 * max(0.0, math.sin(math.atan2(co.x - c.x, co.y - c.y) * 30.0)), None, 0.0))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.78)
    L.smooth(mesh, 55)
    joints = _joints(hip, waist, Vector((0, -0.01, 1.45)), Vector((0, -0.04, 1.78)), sh, wr, 0.1)
    cup = PR.tin_cup("tin_cup")
    M.place(cup, hands[-1] + Vector((0.0, -0.035, -0.01)))
    kids = [M.child("tin_cup", "arm_r", cup, ("sit_beg", "idle", "talk", "stand_up", "idle_low"))]

    def stiff(t: float) -> dict:
        """24 frames: the left leg swings, the stiff right leg is brought round from the hip (the hip hikes),
        the stick goes forward with it."""
        g = rig.gait(t, leg=24.0, lift=0.04, arm=10.0, bob=0.022, roll=6.0, yaw=6.0, lean=3.0)
        s = math.sin(rig.TAU * t)
        g["leg_r"] = (14.0 * s, 0.0, -6.0 * max(0.0, -math.cos(rig.TAU * t)))
        g["arm_l"] = (16.0 * s, 0.0, 0.0)
        return g

    idle = _idle(1.0, 0.6, 1.2, lambda t: {"leg_r": (-8.0, 0.0, 2.0), "arm_l": (-6.0, 0, 0)})
    sit = {"hips": (-8.0, 0.0, 0.0, 0.0, 0.05, -0.34), "spine": (-4.0, 0.0, 0.0), "head": (8.0, 0.0, 0.0),
           "leg_r": (-84.0, 0.0, 6.0), "leg_l": (-58.0, 0.0, -6.0), "arm_r": (-44.0, -6.0, 6.0), "arm_l": (-14.0, 6.0, 0.0),
           "feet": {"leg_l": 0.0, "leg_r": 0.0}}

    def sit_beg(t: float) -> dict:
        """90 frames: sitting at the wall / on a step (seat ~0.42 m), the stiff right leg stretched out, the cup
        held out over the knee; he watches the passers-by."""
        s = math.sin(rig.TAU * t)
        return rig.add(rig.breathe(t, 0.7), sit, {"head": (0.0, 0.0, 10.0 * s), "arm_r": (2.0 * math.sin(rig.TAU * t * 2.0), 0, 0)})

    def stand_up(t: float) -> dict:
        """30 frames one-shot: from sitting up onto the good leg and the stick (ends at rest)."""
        mid = rig.blend(sit, PLANT, 0.55)
        mid["spine"] = (24.0, 0.0, 0.0)
        mid["feet"] = {"leg_l": 0.0, "leg_r": 0.0}
        return rig.keyed(t, [(0.0, dict(sit)), (0.5, mid), (1.0, dict(PLANT))], wrap=False)

    talk_keys = [(0.0, {"arm_r": (-18.0, -4.0, 8.0), "head": (4.0, 0.0, 2.0), "leg_r": (-8.0, 0, 0)}),
                 (0.4, {"arm_r": (-30.0, -8.0, 14.0), "head": (2.0, -3.0, -2.0), "leg_r": (-8.0, 0, 0)}),
                 (0.7, {"arm_r": (-22.0, -6.0, 10.0), "head": (5.0, 2.0, 3.0), "leg_r": (-8.0, 0, 0)})]
    actions = [("idle-loop", 84, idle), ("walk-loop", 24, stiff), ("walk_stiff-loop", 24, stiff),
               ("talk-loop", 72, _talk(talk_keys, 0.8)), ("sit_beg-loop", 90, sit_beg), ("stand_up", 30, stand_up)]
    actions += M.p8_actions({"low"}, stiff)
    M.export_figure("ph_chr_beggar", mesh, joints, actions, children=kids, markers=[M.face_marker(pts)])


# ======================================================================================================
# Hanne Vogelsang - the peddler
# ======================================================================================================

HA_SKIRT = L.hexc("#5E5240")
HA_SKIRT_DARK = L.hexc("#433A2E")
HA_BODICE = L.hexc("#4A4438")
HA_BLOUSE = L.hexc("#BDB29A")
HA_SCARF = L.hexc("#9A7E52")
HA_SCARF_DARK = L.hexc("#76603E")
HA_SKIN = L.hexc("#C08A68")
HA_HAIR = L.hexc("#4E3A2A")


def kiepe(name: str = "kiepe"):
    """The tall back basket: a tapering wicker body (0.8 m), straps, a lid of sacking, tinware hung on the
    outside (a pot, two cups, a lantern), little bells, ribbons (one small red band). The back of the
    wearer at y = 0; the basket behind (+Y). <= 1 500 tris."""
    parts = []
    body = loft([(0.62, 0.17, 0.12, 0.0, 0.27), (0.9, 0.2, 0.14, 0.0, 0.29), (1.2, 0.23, 0.155, 0.0, 0.31),
                 (1.45, 0.25, 0.165, 0.0, 0.32), (1.48, 0.24, 0.16, 0.0, 0.32)], n=14, caps=(True, False), name="kiepe")
    L.jitter(body, 0.006, 6.0, 1)
    _painted(body, M.WICKER, var=0.2, ao=0.25, top=0.3, seed=1, hue_shift=M.WICKER_DARK)
    _tint(body, lambda co, nr: (1.0 - 0.24 * max(0.0, math.sin(co.z * 110.0 + math.sin(math.atan2(co.y - 0.31, co.x) * 16.0) * 1.2)),
                                None, 0.0))
    parts.append(body)
    lid = loft([(1.46, 0.245, 0.162, 0.0, 0.32), (1.55, 0.2, 0.13, 0.0, 0.32), (1.6, 0.06, 0.05, 0.0, 0.32)], n=12, name="lid")
    L.jitter(lid, 0.01, 7.0, 2)
    parts.append(_painted(lid, L.hexc("#7A6E58"), var=0.2, ao=0.1, top=0.3, seed=2, hue_shift=L.hexc("#5E5444")))
    for sx in (-1, 1):   # the shoulder straps over the shoulders (the wearer's shoulders at ~1.3 m)
        st = [Vector((sx * 0.13, 0.12, 1.3)), Vector((sx * 0.14, 0.0, 1.33)), Vector((sx * 0.15, -0.13, 1.25)),
              Vector((sx * 0.16, -0.13, 1.1)), Vector((sx * 0.17, 0.06, 0.95))]
        parts.append(_painted(sweep(st, 0.016, n=4, flat=0.35, name="strap"), L.hexc("#4A3A2C"), var=0.12, ao=0.0, seed=3))
    hang = [(-0.24, 1.25, "pot"), (0.24, 1.3, "cup"), (0.22, 1.05, "cup"), (-0.22, 0.98, "lantern")]
    for k, (x, z, kind) in enumerate(hang):
        at = Vector((x, 0.34, z))
        if kind == "pot":
            parts.append(L.part("cyl", PR.TIN, loc=at, radius=0.06, depth=0.08, vertices=8, paint_kw={"ao": 0.2, "top": 0.4, "var": 0.15}))
        elif kind == "cup":
            parts.append(L.part("cyl", PR.TIN_DARK, loc=at, radius=0.032, depth=0.05, vertices=7, paint_kw={"ao": 0.1, "top": 0.4}))
        else:
            parts.append(_xform(PR.lantern_hand(0.7, "kl"), at + Vector((0, 0, 0.06))))
    for k in range(5):   # little bells on a cord round the rim
        a = math.pi * (0.15 + 0.7 * k / 4)
        at = Vector((math.cos(a) * 0.255, 0.32 - math.sin(a) * 0.17, 1.4))
        parts.append(L.part("cone", L.hexc("#9A8650"), loc=at, radius1=0.016, radius2=0.004, depth=0.022, vertices=6,
                            paint_kw={"ao": 0.0, "top": 0.5, "var": 0.1}))
    for k, (x, col) in enumerate(((0.18, L.hexc("#6A6A5A")), (-0.1, PR.RIBBON), (0.05, L.hexc("#7A6A48")))):   # ribbons
        top = Vector((x, 0.49, 1.47))
        parts.append(_painted(sweep([top, top + Vector((0.01, 0.03, -0.12)), top + Vector((-0.01, 0.05, -0.24 + 0.08 * (k == 1)))],
                                    [0.012, 0.011, 0.008], n=4, flat=0.25, name="ribbon"), col, var=0.08, ao=0.0, seed=10 + k))
    return L.join(parts, name)


def _xform(obj, at):
    obj.data.transform(Matrix.Translation(Vector(at)))
    return obj


def peddler():
    L.reset(8801)
    parts = []
    prof = Prof(((0.03, 0.29, 0.27, 0.016), (0.2, 0.276, 0.256, 0.012), (0.5, 0.244, 0.222, 0.006), (0.75, 0.214, 0.186, 0.0),
                 (0.9, 0.192, 0.162, 0.0), (0.97, 0.176, 0.148, -0.004), (1.05, 0.18, 0.152, -0.01), (1.15, 0.194, 0.162, -0.012),
                 (1.22, 0.194, 0.154, -0.008), (1.27, 0.176, 0.134, -0.004), (1.31, 0.132, 0.106, -0.004), (1.34, 0.07, 0.065, -0.008)))
    waist = 0.97
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.09, BOOT_WORN, length=0.135, width=0.064, height=0.056, toe=-0.075, shaft=0.1, shaft_r=0.054, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.09, 0.0, 0.04), (sx * 0.094, 0.0, 0.5), (sx * 0.095, 0.0, 0.86)], [0.048, 0.052, 0.064],
                  BLACK, seed=12)
    skirt = _body(Prof(prof.rings[:6]), HA_SKIRT, HA_SKIRT_DARK, n=30, seed=1, fold=0.016, fold_k=7.0, cap=False, hem_wave=0.014)
    parts.append(W("hips", skirt))
    top = _body(Prof(prof.rings[5:]), HA_BODICE, BLACK, n=20, seed=2, fold=0.0, var=0.12)
    parts.append(W("spine", top))
    ap = _sheet_on(prof, [0] * 6, [0.3, 0.5, 0.7, 0.86, 0.96], 0.01, L.hexc("#6E6656"), L.hexc("#52493C"), seed=3,
                   xfn=lambda z: (-0.15 - 0.05 * (0.96 - z), 0.15 + 0.05 * (0.96 - z)))
    parts.append(W("hips", ap))
    parts.append(W("hips", _ring_band(prof, waist, 0.012, L.hexc("#4A3A2C"), out=0.012, seed=4)))
    # a leather purse at the belt
    pc = prof.surf(-0.15, waist - 0.07, -1, 0.03)
    parts.append(W("hips", _ell(L.hexc("#5E4433"), pc, (0.04, 0.025, 0.05), seg=8, rings=5, seed=5)))
    sh = {sx: Vector((sx * 0.195, -0.004, 1.27)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.24, 0.0, 1.04)) for sx in (-1, 1)}
    wr = {-1: Vector((-0.25, -0.08, 0.84)), 1: Vector((0.26, -0.14, 0.88))}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], HA_BLOUSE, LINEN_SHADE, r=(0.054, 0.052, 0.042, 0.04), rolled=True,
                         skin=HA_SKIN, seed=20 + sx * 3, hand_size=1.05, grip=True)
    h = hands[1]   # the walking staff, taller than she is (a child mesh: she puts it aside to dance and clap)
    staff = _painted(L.tube(Vector((h.x + 0.01, h.y - 0.02, 0.0)), h + Vector((0, -0.01, 0.62)), 0.015, 6),
                     WOOD, var=0.2, ao=0.0, top=0.3, seed=8, hue_shift=WOOD_DARK)
    c = Vector((0.0, -0.03, 1.46))
    s = Vector((0.134, 0.134, 0.144))
    pts = _head(parts, c, s, HA_SKIN, seed=30, nose="round", nose_s=1.0, brow=HA_HAIR, brow_w=1.05, brow_tilt=0.2, brow_arch=1.2,
                mouth="laugh", smile=1.0, cheeks=1.0, cheek_col=L.hexc("#C8705C"), jaw=1.0, chin=0.02, age=0.2, lids=0.14,
                iris=IRIS_BROWN, ears=False)
    face = pts["face"]
    _hair(parts, face, HA_HAIR, L.hexc("#36281C"), [(0.0, 0.42), (0.6, 0.34), (1.0, 0.08), (1.3, -0.16), (math.pi, -0.5)],
          out=0.005, crown=0.003, part_u=0.0, seed=31)
    _cloth_cover(parts, face, HA_SCARF, HA_SCARF_DARK, [(0.0, 0.56), (0.6, 0.5), (1.05, 0.12), (1.4, -0.3), (2.0, -0.6),
                                                       (math.pi, -0.72)],
                 out=lambda ph, w: 0.016 + 0.008 * max(0.0, math.cos(ph)), crown=0.008, folds=7.0, rim=0.01 * face.k,
                 rim_phi=1.9, lumps=0.006, seed=32, name="scarf")
    knot = c + Vector((0.0, s.y + 0.026, -0.07))
    parts.append(W("head", _ell(HA_SCARF, knot, (0.04, 0.03, 0.032), seg=8, rings=5, seed=34, jit=0.004)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.62)
    L.smooth(mesh, 55)
    joints = _joints(0.84, waist, Vector((0, -0.01, 1.33)), Vector((0, -0.03, 1.64)), sh, wr, 0.094)
    kids = [M.child("kiepe", "spine", kiepe("kiepe"), ("idle", "walk", "talk", "kiepe_off", "kiepe_on", "idle_low")),
            M.child("lantern_prop", "arm_r", M.lantern_child(hands[-1]), ("lantern_walk",)),
            M.child("staff", "arm_l", staff, ("idle", "walk", "talk", "offer", "kiepe_off", "kiepe_on", "idle_low",
                                              "lantern_walk"))]
    walk = _walk(24.0, 0.04, 14.0, 0.016, 3.0, 4.0, 4.0, lambda t: {"arm_l": (8.0 * math.sin(rig.TAU * t), 0, 0)})
    talk_keys = [(0.0, {"arm_r": (-40.0, -10.0, 18.0), "head": (2.0, 3.0, 4.0)}),
                 (0.2, {"arm_r": (-56.0, -16.0, 30.0), "head": (-2.0, -3.0, -3.0)}),
                 (0.45, {"arm_r": (-36.0, -12.0, 22.0), "head": (3.0, 2.0, 6.0)}),
                 (0.7, {"arm_r": (-60.0, -6.0, 12.0), "head": (-1.0, -4.0, -5.0)})]

    def offer(t: float) -> dict:
        """60 frames: shows her wares - a slight bow, the right hand forward palm up (like Ilse's offer),
        weighing a candle, nodding."""
        s = math.sin(rig.TAU * t)
        return rig.add({"spine": (8.0, 0.0, 3.0), "head": (6.0 + 3.0 * math.sin(rig.TAU * t * 2.0), 0.0, 4.0 * s),
                        "arm_r": (-60.0 + 6.0 * s, 6.0, -8.0)}, rig.breathe(t, 1.0), PLANT)

    take_off = {"spine": (18.0, 0.0, 0.0), "head": (-6.0, 0.0, 0.0), "arm_r": (-10.0, -30.0, 0.0), "arm_l": (-10.0, 30.0, 0.0),
                "hips": (2.0, 0.0, 0.0, 0.0, 0.03, -0.06), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    set_down = {"spine": (26.0, 0.0, 14.0), "head": (-10.0, 0.0, 6.0), "arm_r": (-30.0, -20.0, 10.0), "arm_l": (-20.0, 14.0, 0.0),
                "hips": (4.0, 0.0, 6.0, 0.0, 0.04, -0.1), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    actions = [("idle-loop", 72, _idle(1.2, 1.0, 1.4)), ("walk-loop", 20, walk), ("talk-loop", 60, _talk(talk_keys, 1.1)),
               ("offer-loop", 60, offer),
               ("kiepe_off", 30, rig.once([(0.0, dict(PLANT)), (0.35, take_off), (0.75, set_down), (1.0, dict(PLANT))])),
               ("kiepe_on", 30, rig.once([(0.0, dict(PLANT)), (0.25, set_down), (0.65, take_off), (1.0, dict(PLANT))]))]
    actions += M.p8_actions({"low", "lantern", "dance", "clap"}, walk, lantern_side=-1)
    M.export_figure("ph_chr_peddler", mesh, joints, actions, children=kids, markers=[M.face_marker(pts)])


# ======================================================================================================
# Lambert Grell - the night digger
# ======================================================================================================

LA_COAT = L.hexc("#33342F")
LA_COAT_DARK = L.hexc("#232420")
LA_TROUSER = L.hexc("#2E2C28")
LA_SCARF = L.hexc("#4E4A40")
LA_SACK = L.hexc("#6A604C")
LA_SKIN = L.hexc("#C79C80")
LA_HAIR = L.hexc("#3E3024")
SPADE_HEAD = 0.95


def robber():
    L.reset(8901)
    parts = []
    hip, waist = 0.92, 0.99
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.095
        _shoe(parts, leg, x0, BOOT, length=0.15, width=0.064, height=0.058, toe=-0.08, shaft=0.22, shaft_r=0.058, seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.2), (sx * 0.098, -0.004, 0.5), (sx * 0.1, 0.0, hip)], [0.056, 0.06, 0.07],
                  LA_TROUSER, n=10, seed=12)
    prof = Prof(((0.68, 0.22, 0.18, 0.014), (0.8, 0.21, 0.17, 0.008), (0.95, 0.196, 0.158, 0.0), (1.05, 0.198, 0.158, -0.006),
                 (1.18, 0.208, 0.16, -0.01), (1.3, 0.214, 0.156, -0.008), (1.38, 0.19, 0.14, -0.004), (1.43, 0.13, 0.1, -0.004),
                 (1.46, 0.08, 0.072, -0.008)))
    coat = _body(prof, LA_COAT, LA_COAT_DARK, n=24, seed=3, fold=0.01, fold_top=1.0, part_front=0.12, part_w=0.35)
    parts.append(rig.weight_split_z(coat, waist, "hips", "spine"))
    parts.append(W("hips", _ring_band(prof, waist, 0.012, LEATHER_DARK, out=0.008, seed=4)))
    # the empty sack over the left shoulder, hanging down the back
    sk = [Vector((0.12, -0.06, 1.43)), Vector((0.14, 0.08, 1.4)), Vector((0.12, 0.17, 1.22)), Vector((0.08, 0.2, 1.02))]
    sack = sweep(sk, [0.05, 0.08, 0.1, 0.07], n=8, flat=0.5, name="sack", normals=[(0, 1, 0.2), (0, 1, 0), (0, 1, 0), (0, 1, 0)])
    L.jitter(sack, 0.01, 6.0, 5)
    parts.append(W("spine", _painted(sack, LA_SACK, var=0.2, ao=0.2, top=0.3, seed=5, hue_shift=L.hexc("#4E4636"))))
    sh = {sx: Vector((sx * 0.205, -0.004, 1.38)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.25, 0.0, 1.11)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.262, -0.07, 0.88)) for sx in (-1, 1)}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], LA_COAT, LA_COAT_DARK, r=(0.054, 0.05, 0.046, 0.046),
                         cuff=LA_COAT_DARK, cuff_r=0.056, skin=LA_SKIN, seed=20 + sx * 3, hand_size=1.0, grip=True)
    c = Vector((0.0, -0.035, 1.61))
    s = Vector((0.124, 0.134, 0.148))
    pts = _head(parts, c, s, LA_SKIN, seed=30, nose="straight", nose_s=1.05, brow=LA_HAIR, brow_w=1.0, brow_tilt=0.5, brow_arch=0.9,
                mouth="kind", smile=0.15, lip=V.LIP_PALE, cheeks=0.3, jaw=0.86, chin=0.04, age=0.3, lids=0.3, iris=IRIS_HAZEL,
                muzzle=0.9)
    face = pts["face"]
    _hair(parts, face, LA_HAIR, L.hexc("#2A2018"), [(0.0, 0.4), (0.6, 0.32), (1.1, 0.04), (1.4, -0.24), (math.pi, -0.45)],
          out=0.005, crown=0.002, tuft=0.01, seed=31)
    _stubble(parts, face, L.hexc("#5A4A3C"), LA_SKIN, seed=32)
    # the hood: a deep shell round the head, open at the face, falling onto the shoulders
    hood, _ = _cloth_cover(parts, face, LA_COAT, LA_COAT_DARK, [(0.0, 0.74), (0.55, 0.62), (0.95, 0.2), (1.15, -0.4), (1.35, -0.9),
                                                               (math.pi, -0.98)],
                           out=lambda ph, w: 0.034 + 0.014 * max(0.0, math.cos(ph)) + 0.02 * _s01((-w - 0.2) / 0.6),
                           crown=0.03, folds=5.0, rim=0.014 * face.k, rim_phi=1.4, lumps=0.01, seed=33, name="hood")
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.8)
    L.smooth(mesh, 55)
    joints = _joints(hip, waist, Vector((0, -0.01, 1.46)), Vector((0, -0.04, 1.8)), sh, wr, 0.098)
    fist_r, fist_l = hands[-1].copy(), hands[1].copy()
    joints[TOOL] = (tuple(fist_r), tuple(fist_r + Vector((0.0, 0.0, 0.3))))
    # the neckerchief up over mouth and nose / down round the neck
    up = []
    for k in range(12):
        ph = -1.75 + 3.5 * k / 11
        up.append(face.world(Face.around(ph, -0.12 - 0.12 * math.cos(ph * 0.5)), 0.012))
    scarf_up = sweep(up, 0.05, n=6, flat=0.32, name="scarf_up",
                     normals=[face.normal(Face.around(-1.75 + 3.5 * k / 11, -0.2)) for k in range(12)])
    L.jitter(scarf_up, 0.004, 9.0, 40)
    _painted(scarf_up, LA_SCARF, var=0.15, ao=0.1, top=0.2, seed=40, hue_shift=L.hexc("#3A3630"))
    ring = [Vector((math.cos(a) * 0.1, -0.008 + math.sin(a) * 0.09, 1.46 - 0.025 * math.sin(a))) for a in (math.tau * k / 14 for k in range(14))]
    scarf_down = sweep(ring, 0.032, n=6, closed=True, name="scarf_down")
    _painted(scarf_down, LA_SCARF, var=0.15, ao=0.1, top=0.2, seed=41, hue_shift=L.hexc("#3A3630"))
    spade = PR.spade_robber("spade")
    M.place(spade, fist_r)
    lan = PR.lantern_blind("lantern_blind")
    M.place(lan, fist_l + Vector((0.0, -0.01, -0.01)))
    caught = ("sit_ground", "talk")
    kids = [M.child("scarf_up", "head", scarf_up, ("idle", "walk", "dig_night", "startle", "run", "climb")),
            M.child("scarf_down", "spine", scarf_down, caught),
            M.child("spade", TOOL, spade, ("dig_night",)),
            M.child("lantern_blind", "arm_l", lan, ("idle", "walk", "startle", "talk", "sit_ground"))]

    def dig_night(t: float) -> dict:
        """39 frames: like the gravekeeper's dig but bent lower and quicker to stop: the blade jabs in, the
        foot treads, the earth is levered up and dropped beside the grave."""
        base = {"hips": (4.0, 0.0, 0.0, 0.0, 0.03, -0.05), "leg_l": (-12.0, 0, 0), "leg_r": (8.0, 0, 0)}
        jab = rig.add(base, {"spine": (30.0, 0.0, 4.0), "head": (-12.0, 0.0, 0.0), "arm_r": (-70.0, -4.0, 4.0),
                             "arm_l": (-62.0, 10.0, 0.0), "tgnd": (0.1, -1.0, SPADE_HEAD), "aim": (0.4, 1.0)})
        tread = rig.add(jab, {"leg_l": (-6.0, 0, 0), "spine": (-4.0, 0, 0)})
        tread["feet"] = {"leg_l": 0.08, "leg_r": 0.0}
        lift = rig.add(base, {"spine": (22.0, 0.0, -6.0), "head": (-8.0, 0.0, 0.0), "arm_r": (-46.0, -4.0, 4.0),
                              "arm_l": (-74.0, 10.0, 0.0), "tgnd": (0.3, -1.0, SPADE_HEAD * 1.8), "aim": (0.42, 1.0)})
        drop = rig.add(base, {"spine": (20.0, 0.0, 16.0), "head": (-6.0, 0.0, 6.0), "arm_r": (-50.0, -14.0, 10.0),
                              "arm_l": (-70.0, 4.0, 10.0), "tgnd": (0.9, -0.6, SPADE_HEAD * 1.6), "aim": (0.42, 1.0)})
        keys = [(0.0, jab), (0.2, tread), (0.4, jab), (0.62, lift), (0.8, drop)]
        p = rig.keyed(t, keys)
        p.setdefault("feet", {"leg_l": 0.0, "leg_r": 0.0})
        return p

    def startle(t: float) -> dict:
        """15 frames one-shot: he jerks up and round towards the noise."""
        up = {"spine": (-6.0, 0.0, -18.0), "head": (-8.0, 0.0, -22.0), "arm_r": (-20.0, 16.0, 0.0), "arm_l": (-30.0, -16.0, 0.0),
              "hips": (0.0, 0.0, -10.0, 0.0, 0.0, 0.01), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
        return rig.keyed(t, [(0.0, dict(PLANT)), (0.35, up), (0.7, up), (1.0, dict(PLANT))], wrap=False)

    def run(t: float) -> dict:
        """14 frames: running, bent forward."""
        return rig.gait(t, leg=40.0, lift=0.09, arm=34.0, bob=0.04, roll=3.0, yaw=7.0, lean=12.0)

    def climb(t: float) -> dict:
        """60 frames one-shot: over the fence / wall (~1 m): the hands up on the top, the body heaves up and
        over (the hips rise), the legs swing across, down on the far side (moved by code)."""
        reach = {"arm_l": (-130.0, 0, 0), "arm_r": (-130.0, 0, 0), "spine": (10.0, 0, 0), "head": (-10.0, 0, 0)}
        heave = {"arm_l": (-70.0, 10, 0), "arm_r": (-70.0, -10, 0), "spine": (40.0, 0, 0), "head": (-20.0, 0, 0),
                 "hips": (10.0, 0, 0, 0, 0.0, 0.45), "leg_l": (-60.0, 0, 0), "leg_r": (20.0, 0, 0)}
        over = {"arm_l": (-50.0, 20, 0), "arm_r": (-50.0, -20, 0), "spine": (30.0, 0, -10), "head": (-10.0, 0, 0),
                "hips": (0.0, 0, 20, 0, 0.0, 0.5), "leg_l": (-80.0, 0, -20), "leg_r": (-70.0, 0, 20)}
        return rig.keyed(t, [(0.0, {}), (0.25, reach), (0.5, heave), (0.72, over), (1.0, {})], wrap=False)

    sitp = {"hips": (-10.0, 0.0, 0.0, 0.0, 0.08, -0.72), "spine": (16.0, 0.0, 0.0), "head": (14.0, 0.0, 0.0),
            "leg_l": (-80.0, 0.0, -10.0), "leg_r": (-76.0, 0.0, 10.0), "arm_l": (-50.0, 18.0, 0.0), "arm_r": (-52.0, -18.0, 0.0),
            "feet": {"leg_l": 0.0, "leg_r": 0.0}}

    def sit_ground(t: float) -> dict:
        """72 frames: caught - sitting in the spoil, the arms over the knees, the head low; he breathes and
        once looks up."""
        look = max(0.0, math.sin(rig.TAU * t)) ** 2
        return rig.add(sitp, rig.breathe(t, 0.9), {"head": (-12.0 * look, 0.0, 0.0)})

    walk = _walk(22.0, 0.04, 10.0, 0.012, 2.5, 3.0, 5.0)
    talk_keys = [(0.0, {"arm_r": (-16.0, -4.0, 6.0), "head": (10.0, 0.0, 2.0)}),
                 (0.4, {"arm_r": (-26.0, -6.0, 10.0), "head": (6.0, -3.0, -2.0)}),
                 (0.7, {"arm_r": (-20.0, -6.0, 8.0), "head": (12.0, 2.0, 3.0)})]
    acts = [("idle-loop", 84, _idle(1.0, 0.6, 1.4, lambda t: {"spine": (4.0, 0, 0), "head": (4.0, 0, 0)})),
            ("walk-loop", 20, walk), ("talk-loop", 72, _talk(talk_keys, 0.8)), ("dig_night-loop", 39, dig_night),
            ("startle", 15, startle), ("run-loop", 14, run), ("climb", 60, climb), ("sit_ground-loop", 72, sit_ground)]
    dz = min(v.co.z for v in mesh.data.vertices)
    fists = {"arm_r": fist_r - Vector((0, 0, dz)), "arm_l": fist_l - Vector((0, 0, dz))}
    acts = [(n, f, fn, A.ToolHook(fists, fn)) for n, f, fn in acts]
    M.export_figure("ph_chr_robber", mesh, joints, acts, extra={TOOL: ("spine", (0.0, -1.0, 0.0))}, children=kids,
                    markers=[M.face_marker(pts)],
                    extras_more={"spade": {"carry_with": "idle,walk,startle,run"}})


# ======================================================================================================
# the fiddler (seated, no rig)
# ======================================================================================================

def fiddler():
    """Seated at the stove (pivot = the floor under the seat, 0.45 m), the fiddle under the chin on the left
    shoulder, the left arm up holding the neck; the bow arm (+ bow) is the child `bow` with its origin at the
    right shoulder (rocked by GDScript). <= 2 500 tris."""
    import asset_props_phase6 as M6
    L.reset(8951)
    parts = []
    coat, dark = L.hexc("#4E4436"), L.hexc("#352E26")
    head, sh_z, sh_y = M6._figure(parts, coat, dark, lean=0.04, stout=1.0, seed=1)
    hands_obj = parts.pop()
    bpy.data.objects.remove(hands_obj)
    for _ in range(2):
        bpy.data.objects.remove(parts.pop(-1))
    head = head + Vector((0.0, 0.07, 0.02))
    pts = V._face_hint(parts, head, seed=2, mouth="smile", smile=1.0, brow=L.hexc("#5A4A3A"), brow_w=1.2, cheeks=0.9, age=0.4,
                       lids=0.25)
    face = pts["face"]
    _hair(parts, face, L.hexc("#6A5A48"), L.hexc("#4A3E32"), [(0.0, 0.4), (1.0, 0.1), (1.5, -0.25), (math.pi, -0.5)], out=0.005,
          crown=0.0, seed=3, add=parts.append, n=18, m=4)
    # left arm up to the fiddle neck, the fiddle under the chin pointing forward-left
    sl = Vector((0.19, sh_y + 0.01, sh_z))
    hl = Vector((0.22, sh_y - 0.42, sh_z + 0.06))
    parts.append(M6._shade(sweep([sl, sl.lerp(hl, 0.5) + Vector((0.04, 0, -0.08)), hl], [0.07, 0.062, 0.05], n=7, name="arm"),
                           coat, dark, (0.4, sh_z), 4))
    parts.append(V._ell(V.M6_SKIN, hl, (0.04, 0.05, 0.04), seg=8, rings=5, seed=5))
    fb = Vector((0.08, sh_y - 0.12, sh_z + 0.02))
    body = L.prim("sphere", radius=1.0, segments=10, ring_count=6, scale=(0.1, 0.18, 0.03))
    body.data.transform(Matrix.Translation(fb) @ Matrix.Rotation(math.radians(-25), 4, "Z") @ Matrix.Rotation(math.radians(20), 4, "X"))
    parts.append(_painted(body, L.hexc("#7A4A2A"), var=0.15, ao=0.2, top=0.4, seed=6, hue_shift=L.hexc("#5A3420")))
    parts.append(_painted(L.tube(fb, hl, 0.012, 5), L.hexc("#2A2220"), ao=0.0, seed=7))
    obj = L.join(parts, "ph_chr_fiddler")
    # the bow arm: from the right shoulder (origin) out to the hand with the bow across the strings
    sr = Vector((-0.19, sh_y + 0.01, sh_z))
    hr = Vector((-0.12, sh_y - 0.34, sh_z - 0.06))
    bp = []
    bp.append(M6._shade(sweep([sr, sr.lerp(hr, 0.5) + Vector((-0.06, 0, -0.06)), hr], [0.07, 0.062, 0.05], n=7, name="barm"),
                        coat, dark, (0.4, sh_z), 8))
    bp.append(V._ell(V.M6_SKIN, hr, (0.04, 0.05, 0.04), seg=8, rings=5, seed=9))
    bp.append(_painted(L.tube(hr + Vector((-0.18, 0.06, 0.04)), hr + Vector((0.42, -0.1, 0.1)), 0.006, 4), L.hexc("#4A3A2A"), ao=0.0))
    bow = L.join(bp, "bow")
    bow.data.transform(Matrix.Translation(-sr))
    L.smooth(bow, 50)
    bow.parent = obj
    bow.location = sr
    finish_stable(obj, "ph_chr_fiddler", "characters", 50, shift=False)


FIGURES = (beggar, peddler, robber, fiddler)


def build(names=None):
    """Build all wanderers, or only those whose function name is in `names`."""
    for fn in FIGURES:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
