"""Phase 9: the gentleman with the case (docs/PHASE9_DESIGN.md §2.5.1, §8.1), 'Gemaltes Diorama'.

  ph_chr_stranger  Cornelius Brenneisen, 52 - a 'Kommissionär' from the town: a dark ink-black frock coat with
                   a velvet collar, a plum waistcoat with a watch chain, a white stand-up collar and a black
                   stock; pale kid gloves, glossy town shoes that were not made for the hill; a narrow, clean-
                   shaven face, small watchful eyes behind small oval spectacles that hang on a fine chain; a
                   tall top hat with a dull band. The brown leather case with its brass lock rides on the
                   `tool` bone (9 bones): in the left fist it hangs plumb, in the waiting / writing / sitting
                   clips it stands on the ground beside him. The open notebook in the left hand and the pencil
                   in the right show while he writes.

Child meshes (glTF extras "show_with", as asset_mourners): hat_head (head) in every clip but sit_inn, hat_hand
(root: the hat set down on the bench beside him at the inn table), case (tool) in every clip, notebook (arm_l)
and pencil (arm_r) in write_notebook / sit_inn. Marker "face" (lib_faces._head) on the head bone.

Clips (§8.2): idle, walk, talk (the case in the left hand), write_notebook-loop (standing, the case set down),
tip_hat (one-shot: the right hand to the brim, a small bow), wait_gate-loop (outside the cemetery gate: the case
set down at his left foot, the hands behind his back, looking round), sit_inn-loop (at the inn table: seat
0.46 m, the notebook on the table top 0.8 m, writing; the case on the floor, the hat on the bench).

Run:  python tools/blender/build_all.py asset_stranger
"""
import math

import bpy  # must be imported before bmesh
from mathutils import Matrix, Vector

import lib_painted as L
import rig
from asset_carter import loft, sweep, _tint
from asset_villagers import (Prof, _body, _shoe, _leg_tube, _arm, _ell, _ring_band, _global_light, _joints, _idle, _talk,
                             _painted, _side, SKIN_PALE, BLACK_DARK, BLACK_SHEEN, LINEN_WHITE, LINEN_SHADE, LIP_PALE,
                             BRASS, BRASS_DARK)
from lib_faces import IRIS_GREY, Face, _hair, _head
import asset_mourners as M

W = rig.weight
TOOL = "tool"
NAME = "ph_chr_stranger"

COAT = L.hexc("#2A2C33")          # ink-black town cloth with a cold hint (muted, no saturated blue)
COAT_DARK = L.hexc("#1D1E23")
COAT_SHEEN = L.hexc("#3A3D48")
VELVET = L.hexc("#18171C")        # the velvet collar: deeper and softer than the cloth
VELVET_SHEEN = L.hexc("#34323C")
WAIST = L.hexc("#4E3A3A")         # plum-brown waistcoat
WAIST_DARK = L.hexc("#382828")
TROUSER = L.hexc("#3A393C")
TROUSER_DARK = L.hexc("#2A292C")
GLOVE = L.hexc("#B8A68C")         # pale kid gloves
GLOVE_SHADE = L.hexc("#8E7E68")
SHOE_GLOSS = L.hexc("#6A6670")
HAIR = L.hexc("#6E6458")          # salt and pepper
HAIR_DARK = L.hexc("#4A4038")
HAT = L.hexc("#1C1B1E")
HAT_SHEEN = L.hexc("#3A3942")
HAT_BAND = L.hexc("#3A3430")      # the dull band
CASE = L.hexc("#6A4A32")          # brown leather
CASE_DARK = L.hexc("#48321F")
CASE_EDGE = L.hexc("#3A281A")
STEEL = L.hexc("#6E7076")
PAPER = L.hexc("#D8D0BC")
PAPER_SHADE = L.hexc("#B4AA94")
INK = L.hexc("#2A2622")
NOTE_COVER = L.hexc("#2E2624")
PENCIL = L.hexc("#4A3E30")

HIP, WAIST_Z = 0.94, 1.0
SHOULDER_Z = 1.42
CASE_H, CASE_W, CASE_T = 0.3, 0.42, 0.11   # height, length (along the walk), thickness (m)
CASE_DROP = 0.05                           # handle top -> the case top
SEAT_Z = 0.46                              # the inn bench (ph_int_inn_table)


# ======================================================================================================
# props on the figure
# ======================================================================================================

def case(top: Vector, seed: int = 0, name: str = "case"):
    """The brown leather case standing upright (long side along Y), its handle top at `top`: rounded
    leather body, a darker welt round the edges, brass lock plate and two catches, brass corner caps, the
    leather handle on two brass loops. <= 420 tris."""
    c = top - Vector((0.0, 0.0, CASE_DROP + CASE_H * 0.5))
    parts = []
    body = L.prim("cube", loc=c, scale=(CASE_T * 0.5, CASE_W * 0.5, CASE_H * 0.5))
    L.bevel(body, 0.02, 1)
    L.jitter(body, 0.003, 7.0, seed)
    _painted(body, CASE, var=0.16, ao=0.2, top=0.35, seed=seed, hue_shift=CASE_DARK)
    _tint(body, lambda co, nr: (1.0, L.hexc("#8A6A4C"), 0.3 * max(0.0, nr.z) + 0.12 * max(0.0, -nr.y)))
    parts.append(body)
    # the welt along the lid seam (a little below the top)
    zs = c.z + CASE_H * 0.5 - 0.06
    seam = [Vector((sx * (CASE_T * 0.5 + 0.004), sy * (CASE_W * 0.5 + 0.004), zs)) for sx, sy in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
    seam = [Vector((p.x, p.y, p.z)) + Vector((c.x, c.y, 0.0)) for p in seam]
    parts.append(_painted(sweep(seam, 0.006, n=4, closed=True, name="welt"), CASE_EDGE, var=0.1, ao=0.0, top=0.2))
    # brass lock plate and two catches on the outer (+X / -X) faces, corner caps
    for sx in (-1, 1):
        parts.append(L.part("cube", BRASS, loc=c + Vector((sx * (CASE_T * 0.5 + 0.004), 0.0, CASE_H * 0.5 - 0.06)),
                            scale=(0.004, 0.035, 0.02), paint_kw={"ao": 0.0, "top": 0.5, "var": 0.1}))
        for sy in (-1, 1):
            parts.append(L.part("cube", BRASS_DARK, loc=c + Vector((sx * (CASE_T * 0.5 + 0.003), sy * 0.13, CASE_H * 0.5 - 0.06)),
                                scale=(0.003, 0.012, 0.016), paint_kw={"ao": 0.0, "top": 0.5, "var": 0.1}))
    for sy in (-1, 1):
        for sz in (-1, 1):
            parts.append(L.part("cube", BRASS_DARK, loc=c + Vector((0.0, sy * (CASE_W * 0.5 - 0.012), sz * (CASE_H * 0.5 - 0.012))),
                                scale=(CASE_T * 0.5 + 0.004, 0.016, 0.016), paint_kw={"ao": 0.0, "top": 0.4, "var": 0.1}))
    # the handle: an arch of leather on two brass loops, its top at `top`
    hz = c.z + CASE_H * 0.5
    arch = [Vector((c.x, c.y - 0.06, hz + 0.008)), Vector((c.x, c.y - 0.045, top.z - 0.004)), Vector((c.x, c.y, top.z + 0.002)),
            Vector((c.x, c.y + 0.045, top.z - 0.004)), Vector((c.x, c.y + 0.06, hz + 0.008))]
    parts.append(_painted(sweep(arch, 0.011, n=5, flat=0.6, name="handle", normals=[(1, 0, 0)] * 5), CASE_DARK, var=0.1, ao=0.0,
                          top=0.3))
    for sy in (-1, 1):
        parts.append(L.part("cube", BRASS, loc=(c.x, c.y + sy * 0.06, hz + 0.006), scale=(0.008, 0.008, 0.007),
                            paint_kw={"ao": 0.0, "top": 0.5}))
    return L.join(parts, name)


def notebook(seed: int = 0, name: str = "notebook"):
    """The small notebook, open: two pages (0.18 x 0.12 m) in a black cover, a few lines of writing,
    lying in the XY plane, the spine along Y, centred on the origin. ~120 tris."""
    parts = []
    cover = L.prim("cube", loc=(0, 0, -0.004), scale=(0.095, 0.064, 0.004))
    parts.append(_painted(cover, NOTE_COVER, var=0.1, ao=0.0, top=0.2, seed=seed))
    for sx in (-1, 1):
        pg = L.prim("cube", loc=(sx * 0.046, 0.0, 0.002 + 0.003 * (1 - abs(sx))), scale=(0.044, 0.06, 0.003))
        for v in pg.data.vertices:   # the pages rise a little towards the spine
            v.co.z += 0.006 * max(0.0, 1.0 - abs(v.co.x) / 0.09)
        _painted(pg, PAPER, var=0.06, ao=0.0, top=0.2, seed=seed + 1 + sx, hue_shift=PAPER_SHADE)
        _tint(pg, lambda co, nr: ((0.82 if (abs(co.x) > 0.012 and abs(co.x) < 0.08 and co.z > 0.004
                                            and (co.y * 140.0) % 1.0 < 0.3 and co.y < 0.04) else 1.0), INK, 0.0))
        parts.append(pg)
    return L.join(parts, name)


def pencil(length: float = 0.13, name: str = "pencil"):
    """A pencil along +Z from the origin (the writing tip at the far end). ~30 tris."""
    p = [L.tube(Vector((0, 0, 0)), Vector((0, 0, length * 0.86)), 0.005, 6), L.prim("cone", loc=(0, 0, length * 0.93), radius1=0.005,
                                                                                    radius2=0.0008, depth=length * 0.14, vertices=6)]
    _painted(p[0], PENCIL, var=0.1, ao=0.0, top=0.2)
    _painted(p[1], L.hexc("#8A7A60"), var=0.1, ao=0.0)
    return L.join(p, name)


def tophat(c: Vector, s: Vector, *, brim: float = 0.075, crown_h: float = 0.19, seed: int = 0, name: str = "hat",
           brim_verts: int = 18):
    """The tall top hat over a head (centre c, semi-axes s): the brim curled up at the sides and dipping a
    little at front and back, a tall crown that widens slightly to the top, a flat top, the dull band. ~300 tris.
    (Two hats of one figure need different brim_verts: the glTF exporter shares equal index arrays between
    meshes, and lib_faces._stable_glb would then reorder that shared array twice.)"""
    parts = []
    hz = c.z + s.z * 0.62
    b = L.prim("cyl", loc=(0, c.y + 0.004, hz), radius=1.0, depth=0.01, vertices=brim_verts,
               scale=(s.x + brim, s.y + brim + 0.01, 1.0))
    for v in b.data.vertices:
        u = abs(v.co.x) / (s.x + brim)
        w = abs(v.co.y - c.y) / (s.y + brim)
        v.co.z += 0.032 * u ** 3 - 0.008 * w ** 2
    L.jitter(b, 0.002, 9.0, seed)
    parts.append(_painted(b, HAT, var=0.08, ao=0.0, top=0.35, seed=seed, hue_shift=HAT_SHEEN))
    cr = loft([(hz, s.x + 0.008, s.y + 0.006, 0.0, c.y + 0.004), (hz + crown_h * 0.45, s.x + 0.004, s.y + 0.002, 0.0, c.y + 0.004),
               (hz + crown_h, s.x + 0.018, s.y + 0.016, 0.0, c.y + 0.004)], n=18, p=2.2, name="crown")
    L.jitter(cr, 0.002, 8.0, seed + 1)
    _painted(cr, HAT, var=0.08, ao=0.1, top=0.4, seed=seed + 1, hue_shift=HAT_SHEEN)
    # the silk's sheen: a soft vertical gleam on the front and the sides
    _tint(cr, lambda co, nr: (1.0, HAT_SHEEN, 0.5 * max(0.0, -nr.y) ** 3 + 0.25 * abs(nr.x) ** 4))
    parts.append(cr)
    parts.append(_ring_band(Prof(((hz + 0.022, s.x + 0.008, s.y + 0.006, c.y + 0.004),)), hz + 0.022, 0.016, HAT_BAND, out=0.003,
                            n=18, flat=0.6, seed=seed + 2, var=0.08))
    return L.join(parts, name)


# ======================================================================================================
# the figure
# ======================================================================================================

def _figure():
    """Body mesh (rest pose, before grounding), joints, fists, head points, the hat's head frame."""
    parts = []
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.088
        _shoe(parts, leg, x0, BLACK_DARK, length=0.145, width=0.056, height=0.05, toe=-0.082, pointed=0.1, seed=10 + sx)
        _tint(parts[-1], lambda co, nr: (1.0, SHOE_GLOSS, 0.55 * max(0.0, nr.z) ** 2 + 0.3 * max(0.0, -nr.y) ** 3))
        _leg_tube(parts, leg, [(x0, 0.0, 0.035), (sx * 0.09, -0.004, 0.5), (sx * 0.095, 0.0, HIP)], [0.05, 0.056, 0.07], TROUSER,
                  TROUSER_DARK, n=10, seed=12)
        _tint(parts[-1], lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(math.atan2(co.y, co.x - x0) * 9.0)), None, 0.0))
    # the plum waistcoat under the open front of the coat (only the chest V shows)
    wprof = Prof(((0.9, 0.172, 0.13, -0.006), (1.0, 0.168, 0.128, -0.01), (1.16, 0.18, 0.136, -0.01), (1.3, 0.186, 0.134, -0.006),
                  (1.38, 0.15, 0.115, 0.0), (1.43, 0.08, 0.07, -0.004)))
    wc = _body(wprof, WAIST, WAIST_DARK, n=18, seed=2, fold=0.0, var=0.1, name="waistcoat")
    parts.append(rig.weight_split_z(wc, WAIST_Z, "hips", "spine"))
    for k in range(4):
        p = wprof.surf(0.0, 1.03 + k * 0.07, -1, 0.003)
        parts.append(W("spine", _ell(BRASS_DARK, p, (0.008, 0.005, 0.008), seg=6, rings=4, ao=0.0, top=0.5)))
    # the watch chain from a buttonhole across to the left pocket
    ch = [wprof.surf(0.0, 1.1, -1, 0.006), wprof.surf(0.05, 1.07, -1, 0.007), wprof.surf(0.1, 1.06, -1, 0.006)]
    parts.append(W("spine", _painted(sweep(ch, 0.0028, n=3, name="chain"), BRASS, ao=0.0, var=0.05, top=0.5)))
    # the frock coat: fitted at the waist, the skirt to the knee, open over the waistcoat above the waist
    prof = Prof(((0.5, 0.25, 0.21, 0.03), (0.62, 0.232, 0.196, 0.022), (0.78, 0.206, 0.168, 0.012), (0.92, 0.188, 0.152, 0.006),
                 (1.0, 0.18, 0.144, 0.0), (1.1, 0.188, 0.148, -0.002), (1.22, 0.2, 0.152, 0.0), (1.34, 0.206, 0.148, 0.004),
                 (1.41, 0.176, 0.128, 0.004), (1.45, 0.1, 0.086, 0.002)))
    coat = _body(prof, COAT, COAT_DARK, n=26, seed=3, fold=0.01, fold_top=0.98, part_front=0.18, part_w=0.4, hem_wave=0.006)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(coat.data)
    kill = []
    for f in bm.faces:   # the coat stands open over the waistcoat: a V from the chest to the waist
        cc = f.calc_center_median()
        if cc.y < -0.06 and cc.z > WAIST_Z + 0.02 and cc.z < 1.4 and abs(cc.x) < 0.012 + 0.09 * (cc.z - WAIST_Z) / 0.4:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(coat.data)
    bm.free()
    _tint(coat, lambda co, nr: (1.0, COAT_SHEEN, 0.3 * max(0.0, nr.z) + 0.08 * max(0.0, -nr.y)))
    parts.append(rig.weight_split_z(coat, WAIST_Z, "hips", "spine"))
    parts.append(W("hips", _ring_band(prof, WAIST_Z, 0.01, COAT_DARK, out=0.004, flat=0.45, seed=4)))
    for sx in (-1, 1):
        # lapels: broad, turned back, the cloth's sheen
        lp = [prof.surf(sx * 0.02, WAIST_Z + 0.03, -1, 0.008), prof.surf(sx * 0.08, 1.2, -1, 0.01), prof.surf(sx * 0.12, 1.36, -1, 0.006)]
        parts.append(W("spine", _painted(sweep(lp, [0.016, 0.034, 0.026], n=5, flat=0.35, name="lapel",
                                               normals=[prof.normal(q.x, q.z) for q in lp]), COAT_SHEEN, ao=0.0, var=0.08, seed=5)))
        for k in range(3):   # double-breasted: two rows of cloth buttons at the waist and below the lapels
            z = WAIST_Z - 0.06 + k * 0.07
            p = prof.surf(sx * 0.064, z, -1, 0.012)
            parts.append(W("hips" if z < WAIST_Z else "spine", _ell(BLACK_SHEEN, p, (0.011, 0.006, 0.011), seg=6, rings=4, ao=0.0,
                                                                   top=0.4)))
        p = prof.surf(sx * 0.05, WAIST_Z + 0.004, 1, 0.006)   # the button at the back waist
        parts.append(W("spine", _ell(BLACK_SHEEN, p, (0.01, 0.006, 0.01), seg=6, rings=4, ao=0.0, top=0.4)))
    # the velvet collar: a soft roll round the back of the neck, its ends running into the lapels
    vc = []
    for k in range(13):   # from the front left round the back (+Y) to the front right
        a = -math.pi * 0.3 + math.pi * 1.6 * k / 12
        back = max(0.0, math.sin(a))
        vc.append(Vector((math.cos(a) * 0.112, -0.002 + math.sin(a) * (0.1 if back > 0.0 else 0.072), 1.425 + 0.028 * back)))
    col = _painted(sweep(vc, 0.026, n=6, name="velvet"), VELVET, var=0.06, ao=0.0, top=0.25, seed=6, hue_shift=VELVET_SHEEN)
    _tint(col, lambda co, nr: (1.0, VELVET_SHEEN, 0.35 * max(0.0, nr.z)))
    parts.append(W("spine", col))
    # shirt front, the stand-up collar points and the black stock
    parts.append(W("spine", _painted(L.prim("cone", loc=prof.surf(0.0, 1.3, -1, 0.0) + Vector((0, 0.012, 0.0)), radius1=0.05, radius2=0.0,
                                            depth=0.13, vertices=3, rot=(180, 0, 0), scale=(1.0, 0.25, 1.0)), LINEN_WHITE, ao=0.0, var=0.04)))
    stock = [Vector((math.cos(a) * 0.075, -0.004 + math.sin(a) * 0.068, 1.445)) for a in (math.tau * k / 12 for k in range(12))]
    parts.append(W("spine", _painted(sweep(stock, 0.022, n=5, closed=True, name="stock"), BLACK_DARK, ao=0.0, var=0.06, seed=7)))
    parts.append(W("spine", _ell(BLACK_DARK, (0.0, -0.078, 1.415), (0.032, 0.018, 0.026), seg=8, rings=5, seed=8)))
    for sx in (-1, 1):   # the collar points stand up beside the jaw
        cp = L.prim("cone", loc=(sx * 0.045, -0.06, 1.48), radius1=0.024, radius2=0.002, depth=0.06, vertices=4, rot=(8, -sx * 18, 0),
                    scale=(1.0, 0.25, 1.0))
        parts.append(W("spine", _painted(cp, LINEN_WHITE, ao=0.0, var=0.04)))
    # arms: narrow sleeves, a white shirt cuff, the gloved hands; the left arm a little out (the case clears the skirt)
    sh = {sx: Vector((sx * 0.2, 0.0, SHOULDER_Z)) for sx in (-1, 1)}
    el = {1: Vector((0.255, 0.0, 1.15)), -1: Vector((-0.245, 0.0, 1.15))}
    wr = {1: Vector((0.29, -0.05, 0.9)), -1: Vector((-0.258, -0.07, 0.9))}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], COAT, COAT_DARK, r=(0.052, 0.048, 0.044, 0.042), cuff=COAT_DARK,
                         cuff_r=0.054, skin=GLOVE, hand_shade=GLOVE_SHADE, seed=20 + sx * 3, hand_size=0.95, grip=True)
        ax = (wr[sx] - el[sx]).normalized()
        parts.append(W(_side(sx, "arm"), _painted(sweep([wr[sx] - ax * 0.002, wr[sx] + ax * 0.014], [0.042, 0.04], n=8, name="shirt_cuff"),
                                                  LINEN_WHITE, ao=0.0, var=0.04)))
    # the head: narrow, clean-shaven, small eyes behind the glasses, friendly and watchful
    c = Vector((0.0, -0.028, 1.625))
    s = Vector((0.118, 0.128, 0.148))
    pts = _head(parts, c, s, SKIN_PALE, seed=30, nose="straight", nose_s=1.08, brow=HAIR_DARK, brow_w=0.85, brow_tilt=0.15,
                brow_arch=1.05, eyes=0.82, lids=0.3, mouth="smile", smile=0.42, lip=LIP_PALE, cheeks=0.32, jaw=0.84, chin=0.05,
                age=0.45, iris=IRIS_GREY, muzzle=0.85, mouth_w=0.9, cull=lambda n: n.z > 0.66)
    face = pts["face"]
    _hair(parts, face, HAIR, HAIR_DARK, [(0.0, 0.5), (0.5, 0.44), (0.95, 0.2), (1.28, 0.02), (1.42, -0.3), (1.66, -0.32), (2.0, -0.2),
                                         (math.pi, -0.46)], out=0.006, crown=0.004, part_u=-0.4, tuft=0.003, comb="back", seed=31)
    # the small oval spectacles: thin steel rims, the bridge, the temples to the ears, the fine chain round the neck
    rim_c = {}
    for sx in (-1, 1):
        e = pts["eye"][0 if sx < 0 else 1]
        rimc = e + Vector((0.0, -0.016, -0.002))
        rim_c[sx] = rimc
        rim = L.prim("torus", loc=rimc, rot=(90, 0, 0), major_radius=0.019, minor_radius=0.0024, major_segments=12, minor_segments=3)
        rim.data.transform(Matrix.Translation(rimc) @ Matrix.Scale(0.8, 4, Vector((0, 0, 1))) @ Matrix.Translation(-rimc))
        parts.append(W("head", _painted(rim, STEEL, ao=0.0, top=0.5, var=0.05)))
        ear = face.world(Face.around(sx * 1.5, 0.02), 0.008)
        parts.append(W("head", _painted(sweep([rimc + Vector((sx * 0.019, 0, 0)), ear], 0.0022, n=3, name="temple"), STEEL, ao=0.0)))
    parts.append(W("head", _painted(sweep([rim_c[-1] + Vector((0.019, 0.0, 0.003)), face.pt(0.0, 0.16, 0.006),
                                           rim_c[1] + Vector((-0.019, 0.0, 0.003))], 0.0022, n=3, name="bridge"), STEEL, ao=0.0)))
    # the spectacles' chain: from the left temple behind the ear down the side of the neck to a buttonhole of the
    # left lapel (on the spine: its upper end stays by the ear when he nods - a few cm at most)
    ear = face.world(Face.around(1.52, -0.05), 0.012)
    chain = [ear, ear + Vector((0.018, 0.012, -0.08)), Vector((0.142, -0.03, 1.43)), prof.surf(0.12, 1.33, -1, 0.012)]
    parts.append(W("spine", _painted(sweep(chain, 0.0018, n=3, name="glasses_chain"), BRASS, ao=0.0, var=0.05, top=0.4)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.8)
    L.smooth(mesh, 55)
    joints = _joints(HIP, WAIST_Z, Vector((0, -0.01, 1.45)), Vector((0, -0.03, 1.79)), sh, wr, 0.092)
    return mesh, joints, hands, pts, (c, s)


# --- clips ---------------------------------------------------------------------------------------------

PLANT = M.PLANT
UPRIGHT = {"spine": (-1.5, 0.0, 0.0), "head": (-1.0, 0.0, 0.0)}   # a town man's bearing
CASE_ARM = {"arm_l": (-2.0, -4.0, 0.0)}                           # the case held a little out from the skirt


def idle(t: float) -> dict:
    """84 frames: standing very upright, the case in the left hand; he looks about him, interested."""
    s = math.sin(rig.TAU * t)
    return rig.add(_idle(0.7, 0.4, 0.4)(t), UPRIGHT, CASE_ARM, {"head": (0.0, 0.0, 5.0 * math.sin(rig.TAU * t + 0.6))},
                   {"arm_r": (-3.0 + 1.0 * s, -2.0, 0.0)})


def walk(t: float) -> dict:
    """20 frames: an upright town walk, short neat steps; the case arm swings only a little."""
    g = rig.gait(t, leg=22.0, lift=0.035, arm=11.0, bob=0.01, roll=1.5, yaw=2.5, lean=-1.5)
    g["arm_l"] = (2.5 * math.sin(rig.TAU * t), -4.0, 0.0)
    return g


TALK_KEYS = [
    (0.0, {"arm_r": (-26.0, -4.0, 10.0), "head": (2.0, 3.0, 2.0)}),
    (0.25, {"arm_r": (-40.0, -6.0, 20.0), "head": (4.0, -3.0, 0.0), "spine": (2.0, 0.0, -2.0)}),
    (0.5, {"arm_r": (-32.0, -12.0, 12.0), "head": (1.0, 4.0, 3.0)}),
    (0.75, {"arm_r": (-38.0, -4.0, 18.0), "head": (5.0, 0.0, -2.0), "spine": (1.0, 0.0, 0.0)}),
]


def talk(t: float) -> dict:
    """72 frames: polite and exact - the right hand makes small precise gestures, the head tilts to one side
    as he listens; the case stays in the left hand."""
    return rig.add(_talk(TALK_KEYS, 0.7)(t), UPRIGHT, CASE_ARM)


WRITE_ARMS = {"arm_l": (-66.0, 14.0, 0.0), "arm_r": (-66.0, -16.0, 0.0)}


def write_notebook(t: float) -> dict:
    """72 frames: standing, the notebook held in the left hand in front of the chest, the pencil in the
    right writes in short strokes; now and then he looks up over the glasses (the case set down)."""
    s = math.sin(rig.TAU * t * 4.0)
    look = max(0.0, math.sin(rig.TAU * t)) ** 4
    return rig.add(rig.breathe(t, 0.6), PLANT, WRITE_ARMS,
                   {"arm_r": (2.0 * s, 1.5 * math.cos(rig.TAU * t * 4.0), 0.0), "head": (20.0 - 16.0 * look, 0.0, 4.0 * look),
                    "spine": (3.0, 0.0, 0.0)})


def tip_hat(t: float) -> dict:
    """30 frames one-shot: the right hand comes up to the brim of the hat, a small bow, the hand down again."""
    up = {"arm_r": (-145.0, 20.0, 0.0), "head": (14.0, 0.0, 0.0), "spine": (8.0, 0.0, 0.0), "feet": PLANT["feet"]}
    bow = rig.add(up, {"head": (8.0, 0.0, 0.0), "spine": (6.0, 0.0, 0.0), "arm_r": (8.0, 0.0, 0.0)})
    rest = dict(PLANT)
    return rig.keyed(t, [(0.0, rest), (0.32, up), (0.5, bow), (0.68, up), (1.0, rest)], wrap=False)


def wait_gate(t: float) -> dict:
    """90 frames: outside the gate - the case set down at his left foot, the hands behind his back; the
    weight shifts, he looks round slowly (at the graves, the hut, the road)."""
    look = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 0.6), rig.weight_shift(t, 0.5), UPRIGHT, rig.behind_back(22.0, 17.0),
                   {"head": (2.0 + 2.0 * math.sin(rig.TAU * t * 2.0), 0.0, 14.0 * look), "spine": (0.0, 0.0, 3.0 * look)})


INN = rig.add(rig.seated(), {"spine": (6.0, 0.0, 0.0)})
INN_ARMS = {"arm_l": (-57.0, 14.0, 0.0), "arm_r": (-58.0, -16.0, 0.0)}


def sit_inn(t: float) -> dict:
    """90 frames: at the inn table (bench 0.46 m, the table top 0.8 m in front): the notebook on the table under
    the left hand, the right writes; he looks up at the room now and then (the case on the floor, the hat on
    the bench beside him)."""
    s = math.sin(rig.TAU * t * 5.0)
    look = max(0.0, math.sin(rig.TAU * t)) ** 4
    return rig.add(rig.breathe(t, 0.6), INN, INN_ARMS,
                   {"arm_r": (1.5 * s, 1.5 * math.cos(rig.TAU * t * 5.0), 0.0), "head": (18.0 - 18.0 * look, 0.0, -6.0 * look)})


# the case: held (hangs plumb from the left fist) or set down on the ground beside him (handle-top position,
# grounded armature space)
CASE_DOWN = {"write_notebook": Vector((0.26, -0.1, CASE_H + CASE_DROP)), "wait_gate": Vector((0.28, -0.12, CASE_H + CASE_DROP)),
             "sit_inn": Vector((-0.3, -0.2, CASE_H + CASE_DROP))}


class CaseHook:
    """rig.add_action post hook: the tool bone (the case) hangs plumb from the left fist - only translated with
    it - or, in the clips of CASE_DOWN, stands on the ground."""

    def __init__(self, fist_l: Vector, down=None):
        self.fist = fist_l
        self.down = down

    def __call__(self, arm, t: float) -> None:
        pb = arm.pose.bones[TOOL]
        rest = arm.data.bones[TOOL].matrix_local
        if self.down is not None:
            off = self.down - self.fist
        else:
            pl = arm.pose.bones["arm_l"]
            now = pl.matrix @ arm.data.bones["arm_l"].matrix_local.inverted() @ self.fist
            off = now - self.fist
        pb.matrix = Matrix.Translation(off) @ rest
        bpy.context.view_layer.update()


def _posed_prop(obj, joints, pose: dict, bone: str):
    """Bring a prop modelled where it sits in `pose` into the rest pose of `bone`."""
    obj.data.transform(rig.deform(joints, pose, bone).inverted())
    return obj


def stranger():
    L.reset(9101)
    mesh, joints, hands, pts, (c, s) = _figure()
    dz = min(v.co.z for v in mesh.data.vertices)
    fist_l, fist_r = hands[1].copy(), hands[-1].copy()
    joints[TOOL] = (tuple(fist_l), tuple(fist_l + Vector((0.0, 0.0, 0.3))))
    kids = []
    hat = tophat(c, s, seed=40, name="hat_head")
    hat2 = tophat(c, s, seed=40, name="hat_hand", brim_verts=16)
    # set down on the bench beside him (root space: the seat 0.46 m, 0.4 m to his left)
    hz = c.z + s.z * 0.62
    hat2.data.transform(Matrix.Translation(Vector((0.4, 0.04, SEAT_Z + 0.014 + dz)) - Vector((0.0, c.y, hz))))   # (the brim dips 1.4 cm)
    plain = ("idle", "walk", "talk", "write_notebook", "tip_hat", "wait_gate")
    kids.append(M.child("hat_head", "head", hat, plain))
    kids.append(M.child("hat_hand", "root", hat2, ("sit_inn",)))
    kids.append(M.child("case", TOOL, case(fist_l + Vector((0.0, 0.0, 0.004)), seed=50), plain + ("sit_inn",)))
    # the notebook: modelled lying on the inn table under the left fist (tilted 12 deg towards him), the pencil
    # in the right fist pointing down to the page; both brought back into the rest pose of their arm
    write_pose = rig.add(INN, INN_ARMS)
    fl = rig.deform(joints, write_pose, "arm_l") @ fist_l
    fr = rig.deform(joints, write_pose, "arm_r") @ fist_r
    nb = notebook(seed=60)
    nb.data.transform(Matrix.Translation(Vector((fl.x - 0.07, fl.y - 0.02, fl.z - 0.035))) @ Matrix.Rotation(math.radians(-12.0), 4, "X"))
    kids.append(M.child("notebook", "arm_l", _posed_prop(nb, joints, write_pose, "arm_l"), ("write_notebook", "sit_inn")))
    pc = pencil()
    tip = Vector((fr.x + 0.05, fr.y - 0.06, fl.z - 0.02))
    butt = fr + Vector((-0.02, 0.03, 0.05))
    d = (tip - butt).normalized()
    pc.data.transform(Matrix.Translation(butt) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4())
    kids.append(M.child("pencil", "arm_r", _posed_prop(pc, joints, write_pose, "arm_r"), ("write_notebook", "sit_inn")))
    fist_g = fist_l - Vector((0.0, 0.0, dz))
    acts = [("idle-loop", 84, idle), ("walk-loop", 20, walk), ("talk-loop", 72, talk),
            ("write_notebook-loop", 72, write_notebook), ("tip_hat", 30, tip_hat), ("wait_gate-loop", 90, wait_gate),
            ("sit_inn-loop", 90, sit_inn)]
    acts = [(n, f, fn, CaseHook(fist_g, CASE_DOWN.get(n[:-5] if n.endswith("-loop") else n))) for n, f, fn in acts]
    M.export_figure(NAME, mesh, joints, acts, extra={TOOL: ("spine", (0.0, -1.0, 0.0))}, children=kids,
                    markers=[M.face_marker(pts)])


FIGURES = (stranger,)


def build(names=None):
    """Build the stranger (names: function names, as the other figure modules)."""
    for fn in FIGURES:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
