"""Phase 8: Jakob Wackernagel, the apprentice (docs/PHASE8_DESIGN.md §2.5, §8.1, §8.2), 'Gemaltes Diorama'.

  ph_chr_apprentice   Jakob, 14, Rosine's son: about 1.45 m (4.5 heads), a round face with big eyes and
                      freckles (painted), no lines; tousled sandy hair; a linen smock to the knee (it hides
                      the rigid legs when he bends), a cord belt, dark trousers, boots a size too big.

Rig: the shared rig with the extra bone `tool` (9 bones, like the gravekeeper since G7 Runde 2; child of
spine). Its rest frame sits in the right fist (bone axis = up, roll = forward). The tool meshes ride on it
(glTF children of the joint -> BoneAttachment3D): `rake` (the children's rake, too long for him),
`watering_can`, `broom`, `lantern` (the Lichtgang). Tool space = asset_props_phase8 (grip at the origin,
a long tool's head up). Every clip keys the tool bone in a post hook: it follows the right fist; a clip
may aim the shaft (pose keys "tdir" / "tface": armature directions of the shaft and of the tool's front)
or put the tool's head on the ground ("tgnd": horizontal direction, the head length along the shaft),
and the left fist may take the shaft ("aim": (s along the shaft, weight)).

Child-mesh extras (Npc / Apprentice show them, P1 / P3): "show_with" = the clips the tool belongs to;
"carry_with" = the clips in which it may be carried in the hand while it is the tool of the current job
(walking from spot to spot with the rake in the hand, §1 "Werkzeug in der Hand").

Clips (Godot names): idle, walk, talk, rake, weed, water, candle, watch, read_board, sit_eat, sweep,
carry_can_walk, oops, whistle (Lehrling) + idle_low, lantern_walk, dance, clap (Lichtgang, Kathreintanz).

Run:  python tools/blender/build_all.py asset_apprentice
"""
import math

import bpy  # must be imported before bmesh
from mathutils import Matrix, Quaternion, Vector, noise

import lib_painted as L
import rig
from asset_carter import loft, sweep, _tint, _n
from asset_villagers import (Prof, _body, _sheet_on, _shoe, _leg_tube, _arm, _ell, _ring_band, _global_light, _joints,
                             _idle, _walk, _talk, _painted, _side, SKIN, BOOT, BOOT_WORN, LINEN_WHITE, LINEN_SHADE)
from lib_faces import IRIS_HAZEL, _s01, _hair, _head, _oell
import asset_mourners as M
import asset_props_phase8 as PR

W = rig.weight
NAME = "ph_chr_apprentice"
TOOL = "tool"
SMOCK = L.hexc("#7C705C")
SMOCK_DARK = L.hexc("#5C5444")
TROUSER = L.hexc("#3E3A34")
SHIRT = L.hexc("#C9C0AA")
HAIR = L.hexc("#8E6C44")
HAIR_DARK = L.hexc("#6A4E30")
CORD = L.hexc("#6A5A40")
FRECKLE = L.hexc("#A8705A")
KID_SKIN = L.hexc("#D2A488")
PLANT = M.PLANT
RAKE_HEAD = 0.97      # tool space: the rake's head along the shaft (asset_props_phase8.rake_small)
BROOM_HEAD = 0.95


def _freckles(obj, c: Vector, s: Vector) -> None:
    """Painted freckles over the nose and the cheeks (vertex colour dots)."""
    def fn(co, nr):
        d = co - c
        n = Vector((d.x / s.x, d.y / s.y, d.z / s.z))
        if n.y > -0.55 or n.z < -0.45 or n.z > 0.2 or abs(n.x) > 0.75:
            return 1.0, None, 0.0
        dot = noise.noise(co * 260.0 + Vector((3.0, 1.0, 7.0)))
        return 1.0, FRECKLE, (0.8 if dot > 0.3 else 0.0)
    _tint(obj, fn)


def build_mesh():
    L.reset(8601)
    parts = []
    hip, waist = 0.68, 0.76
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.085
        _shoe(parts, leg, x0, BOOT_WORN, length=0.14, width=0.064, height=0.058, toe=-0.075, shaft=0.12, shaft_r=0.056,
              seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.1), (sx * 0.088, -0.004, 0.36), (sx * 0.09, 0.0, hip)], [0.048, 0.052, 0.062],
                  TROUSER, n=10, seed=12)
    # the smock to the knee, wide, gathered at the yoke; a cord belt
    prof = Prof(((0.38, 0.215, 0.18, 0.016), (0.5, 0.205, 0.17, 0.01), (0.64, 0.19, 0.155, 0.004), (0.76, 0.176, 0.142, 0.0),
                 (0.86, 0.178, 0.142, -0.004), (0.96, 0.186, 0.142, -0.004), (1.04, 0.184, 0.134, 0.0),
                 (1.09, 0.15, 0.11, 0.0), (1.12, 0.09, 0.075, -0.004)))
    smock = _body(prof, SMOCK, SMOCK_DARK, n=24, seed=3, fold=0.012, fold_k=8.0, fold_top=0.86, hem_wave=0.012)
    _tint(smock, lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(math.atan2(co.y, co.x) * 20.0)) * _s01((co.z - 0.94) / 0.12),
                                 None, 0.0))
    parts.append(rig.weight_split_z(smock, waist, "hips", "spine"))
    parts.append(W("hips", _ring_band(prof, waist, 0.009, CORD, out=0.008, seed=4)))
    kn = prof.surf(-0.09, waist - 0.005, -1, 0.012)
    parts.append(W("hips", _ell(CORD, kn, (0.014, 0.01, 0.014), seg=6, rings=4, seed=5)))
    for dx in (-0.01, 0.012):
        parts.append(W("hips", _painted(sweep([kn, kn + Vector((dx, -0.008, -0.11))], 0.005, n=4, name="cord_end"), CORD,
                                        ao=0.0, seed=6)))
    # a patch on the smock, a shirt collar at the neck
    pp = prof.surf(0.09, 0.56, -1, 0.004)
    parts.append(W("hips", L.part("cube", L.scale_c(SMOCK, 0.85), loc=pp, scale=(0.045, 0.004, 0.04), rot=(-6, 0, 8),
                                  paint_kw={"ao": 0.1})))
    for sx in (-1, 1):
        parts.append(W("spine", _painted(sweep([Vector((sx * 0.012, -0.072, 1.13)), Vector((sx * 0.06, -0.06, 1.125)),
                                                Vector((sx * 0.075, -0.02, 1.13))], [0.016, 0.02, 0.012], n=4, flat=0.3,
                                               name="collar"), SHIRT, ao=0.0, var=0.06, seed=7)))
    # arms: sleeves pushed up, thin wrists, big hands
    sh = {sx: Vector((sx * 0.175, -0.004, 1.06)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.215, 0.0, 0.86)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.228, -0.06, 0.68)) for sx in (-1, 1)}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], SMOCK, SMOCK_DARK, r=(0.05, 0.047, 0.036, 0.034), rolled=True,
                         skin=KID_SKIN, seed=20 + sx * 3, hand_size=0.95, grip=True)
    # head: round, big awake eyes, a small round nose, freckles; tousled sandy hair with a fringe and a cowlick
    c = Vector((0.0, -0.025, 1.27))
    s = Vector((0.134, 0.13, 0.13))
    i0 = len(parts)
    pts = _head(parts, c, s, KID_SKIN, seed=30, nose="round", nose_s=0.82, brow=HAIR_DARK, brow_w=0.85, brow_tilt=0.2,
                brow_arch=1.15, eyes=1.18, mouth="smile", smile=0.8, cheeks=1.0, jaw=1.02, chin=0.0, age=0.0, lids=0.1,
                iris=IRIS_HAZEL, muzzle=0.9, mouth_w=0.9)
    _freckles(parts[i0], c, s)
    face = pts["face"]
    for k, (u, w) in enumerate(((-0.3, -0.08), (-0.22, -0.14), (-0.36, -0.18), (-0.27, -0.24), (-0.12, -0.05),
                                (0.3, -0.09), (0.21, -0.15), (0.35, -0.2), (0.26, -0.25), (0.12, -0.04))):
        parts.append(W("head", _oell(FRECKLE, face.pt(u, w, 0.0015), face.nrm(u, w), (0.0034, 0.001, 0.003), seg=5,
                                     rings=3, ao=0.0, var=0.1, top=0.0, seed=40 + k)))
    _hair(parts, face, HAIR, HAIR_DARK, [(0.0, 0.33), (0.3, 0.36), (0.7, 0.22), (1.05, 0.02), (1.4, -0.2), (1.9, -0.36),
                                         (math.pi, -0.5)], out=0.008, crown=0.006, tuft=0.03, seed=31)
    for k, (u, w) in enumerate(((0.1, 0.92), (-0.12, 0.85), (0.22, 0.8), (-0.3, 0.7), (0.4, 0.62), (0.0, 0.75),
                                 (-0.45, 0.5), (0.5, 0.45), (0.15, 0.6), (-0.2, 0.55), (0.3, 0.3), (-0.33, 0.33))):   # the cowlick and a few unruly tufts
        d = Vector((u, -0.5 + 0.12 * (k % 6) if k >= 6 else 0.25 + 0.1 * k, w)).normalized()
        p0 = face.world(d, 0.008)
        parts.append(W("head", _painted(sweep([p0, p0 + face.normal(d) * 0.028 + Vector((0.012 * (k % 3 - 1), 0.012, 0.012 - 0.004 * k))],
                                              [0.016, 0.003], n=4, name="tuft"), HAIR, var=0.15, ao=0.0, top=0.3,
                                        seed=32 + k, hue_shift=HAIR_DARK)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.42)
    L.smooth(mesh, 55)
    return mesh, sh, wr, hands, pts


# --- the tool bone ------------------------------------------------------------------------------------

def _frame(origin: Vector, d: Vector, f: Vector) -> Matrix:
    """Bone matrix: Y along d, Z towards f (orthogonalised)."""
    y = Vector(d).normalized()
    x = y.cross(Vector(f)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = origin
    return m


class ToolHook:
    """rig.add_action post hook: the tool bone in the right fist, aimed / grounded per pose (see above)."""

    def __init__(self, fists: dict, pose_fn):
        self.fists = fists           # rest fist centres (arm_r / arm_l), Blender armature space
        self.fn = pose_fn

    def fist(self, arm, bone: str) -> Vector:
        pb = arm.pose.bones[bone]
        return pb.matrix @ arm.data.bones[bone].matrix_local.inverted() @ self.fists[bone]

    def __call__(self, arm, t: float) -> None:
        pose = self.fn(t)
        pb = arm.pose.bones[TOOL]
        rest = arm.data.bones[TOOL].matrix_local
        dr = arm.pose.bones["arm_r"].matrix @ arm.data.bones["arm_r"].matrix_local.inverted()
        origin = self.fist(arm, "arm_r")
        if "tgnd" in pose:
            h = Vector(tuple(pose["tgnd"])[:2] + (0.0,))
            length = tuple(pose["tgnd"])[2]
            dz = -min(0.98, max(0.1, (origin.z - 0.03) / length))
            d = h.normalized() * math.sqrt(1.0 - dz * dz) + Vector((0, 0, dz))
            m = _frame(origin, d, (0.0, 0.0, -1.0) if abs(dz) < 0.95 else (0.0, -1.0, 0.0))
        elif "tdir" in pose:
            m = _frame(origin, Vector(tuple(pose["tdir"])[:3]), Vector(tuple(pose.get("tface", (0, -1, 0, 0, 0, 0)))[:3]))
        else:
            m = dr @ rest
        pb.matrix = m
        bpy.context.view_layer.update()
        if "aim" in pose:
            s, w = tuple(pose["aim"])[:2]
            if w > 0.001:
                target = m.translation + m.col[1].to_3d().normalized() * s
                pl = arm.pose.bones["arm_l"]
                head = pl.head.copy()
                q = Quaternion().slerp((self.fist(arm, "arm_l") - head).rotation_difference(target - head), w)
                pl.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pl.matrix
                bpy.context.view_layer.update()


# --- clips --------------------------------------------------------------------------------------------

def walk(t: float) -> dict:
    """18 frames: a boy's quick, slightly bouncy step."""
    return rig.gait(t, leg=26.0, lift=0.045, arm=18.0, bob=0.018, roll=3.0, yaw=5.0, lean=2.0)


def idle(t: float) -> dict:
    """72 frames: breathing, looking about a little."""
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.2), {"head": (1.5 * math.sin(rig.TAU * t * 2.0), 0.0, 6.0 * s),
                                         "hips": (0.0, 1.0 * s, 0.0)}, PLANT)


TALK_KEYS = [
    (0.0, {"arm_l": (-22.0, 6.0, -10.0), "head": (-2.0, 0.0, 4.0)}),
    (0.25, {"arm_l": (-44.0, 12.0, -22.0), "head": (2.0, -4.0, -3.0), "spine": (-1.0, 0.0, 2.0)}),
    (0.5, {"arm_l": (-28.0, 4.0, -8.0), "head": (-3.0, 3.0, 5.0)}),
    (0.75, {"arm_l": (-50.0, 10.0, -18.0), "head": (1.0, -2.0, -4.0)}),
]


def rake(t: float) -> dict:
    """40 frames: both hands on the shaft, the head on the ground in front; reach out, draw the leaves in
    towards the feet, lift the rake a little and reach out again."""
    s = math.sin(rig.TAU * t)
    out = {"spine": (16.0, 0.0, 3.0), "head": (-4.0, 0.0, 0.0), "hips": (0, 0, 0, 0, 0.02, -0.02),
           "arm_r": (-82.0, -6.0, 4.0), "arm_l": (-76.0, 10.0, 0.0), "tgnd": (0.05, -1.0, RAKE_HEAD), "aim": (0.32, 1.0)}
    pull = {"spine": (10.0, 0.0, -2.0), "head": (2.0, 0.0, 0.0), "hips": (0, 0, 0, 0, 0.0, -0.01),
            "arm_r": (-44.0, -4.0, 0.0), "arm_l": (-48.0, 10.0, 0.0), "tgnd": (0.0, -1.0, RAKE_HEAD), "aim": (0.3, 1.0)}
    keys = [(0.0, out), (0.55, pull), (0.8, rig.blend(pull, out, 0.5))]
    return rig.add(rig.keyed(t, keys), {"leg_l": (-10.0, 0, 0), "leg_r": (8.0, 0, 0), "head": (0.0, 0.0, 2.0 * s)}, PLANT)


def weed(t: float) -> dict:
    """36 frames: bent over 50 deg, the hips 0.2 m down, the right hand to the ground: grip, pull, toss
    aside."""
    base = {"hips": (6.0, 0.0, 0.0, 0.0, 0.06, -0.2), "spine": (48.0, 0.0, 0.0), "head": (-14.0, 0.0, 0.0),
            "arm_l": (-40.0, 10.0, 0.0), "leg_l": (-14.0, 0, 0), "leg_r": (6.0, 0, 0)}
    grip = rig.add(base, {"arm_r": (-46.0, -4.0, 4.0)})
    pull = rig.add(base, {"arm_r": (-20.0, -4.0, 4.0), "spine": (-4.0, 0.0, 0.0)})
    toss = rig.add(base, {"arm_r": (-36.0, -20.0, 30.0), "spine": (-6.0, 0.0, -8.0)})
    return rig.add(rig.keyed(t, [(0.0, grip), (0.35, pull), (0.6, toss), (0.85, grip)]), PLANT)


WATER_DIR = (0.0, -math.sin(math.radians(35.0)), math.cos(math.radians(35.0)))
WATER_FACE = (0.0, -math.cos(math.radians(35.0)), -math.sin(math.radians(35.0)))


def water(t: float) -> dict:
    """40 frames: the can in the right hand held out, tilted 35 deg, the water running from the rose; the
    can sways slowly along the bed."""
    s = math.sin(rig.TAU * t)
    tilt = math.radians(35.0 + 4.0 * s)
    return rig.add({"arm_r": (-38.0 + 3.0 * s, -4.0, 0.0), "arm_l": (-8.0, 4.0, 0.0), "spine": (10.0, 0.0, 4.0 * s),
                    "head": (8.0, 0.0, 4.0 * s), "hips": (0.0, 0.0, 3.0 * s),
                    "tdir": (0.0, -math.sin(tilt), math.cos(tilt)), "tface": (0.0, -math.cos(tilt), -math.sin(tilt))},
                   PLANT)


def candle(t: float) -> dict:
    """45 frames one-shot: bends down, the right hand low in front sets the candle on the grave, back up."""
    down = {"hips": (6.0, 0.0, 0.0, 0.0, 0.06, -0.2), "spine": (44.0, 0.0, 0.0), "head": (-12.0, 0.0, 0.0),
            "arm_r": (-70.0, -4.0, 4.0), "arm_l": (-30.0, 8.0, 0.0), "leg_l": (-10.0, 0, 0), "leg_r": (6.0, 0, 0),
            "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    return rig.keyed(t, [(0.0, dict(PLANT)), (0.4, down), (0.62, down), (1.0, dict(PLANT))], wrap=False)


def watch(t: float) -> dict:
    """72 frames: watching the gravekeeper work - the arms a little back, the head follows to and fro."""
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.0), {"arm_l": (10.0, -4.0, 0.0), "arm_r": (10.0, 4.0, 0.0), "spine": (4.0, 0.0, 8.0 * s),
                                         "head": (6.0, 0.0, 14.0 * s), "hips": (0.0, 0.0, 4.0 * s)}, PLANT)


def read_board(t: float) -> dict:
    """40 frames one-shot: reads the chalk list - leans in, the head goes along the lines, a finger follows."""
    near = {"spine": (6.0, 0.0, 0.0), "head": (-6.0, 0.0, 8.0), "arm_r": (-50.0, -6.0, 8.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    far = {"spine": (6.0, 0.0, 0.0), "head": (2.0, 0.0, -8.0), "arm_r": (-46.0, 8.0, -8.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    return rig.keyed(t, [(0.0, dict(PLANT)), (0.25, near), (0.5, far), (0.65, rig.blend(near, far, 0.3)),
                         (0.8, far), (1.0, dict(PLANT))], wrap=False)


def sit_eat(t: float) -> dict:
    """72 frames: his midday bread on the bench at the hut (seat 0.4 m): the hands in the lap, now and then
    the right hand comes up (a bite), swinging a foot."""
    s = math.sin(rig.TAU * t)
    bite = max(0.0, math.sin(rig.TAU * t)) ** 3
    return rig.add(rig.breathe(t, 0.8), {
        "hips": (-6.0, 0.0, 0.0, 0.0, 0.04, -0.26), "spine": (6.0, 0.0, 0.0), "head": (6.0 - 6.0 * bite, 0.0, 3.0 * s),
        "leg_l": (-58.0 + 6.0 * math.sin(rig.TAU * t * 2.0), 0.0, -4.0), "leg_r": (-52.0, 0.0, 4.0),
        "arm_l": (-30.0, 10.0, 0.0), "arm_r": (-30.0 - 50.0 * bite, -12.0 - 6.0 * bite, 0.0),
        "feet": {"leg_l": 0.02 + 0.03 * max(0.0, math.sin(rig.TAU * t * 2.0)), "leg_r": 0.0}})


def sweep_(t: float) -> dict:
    """36 frames: the birch broom swept from side to side in front of him, the head of it on the ground."""
    s = math.sin(rig.TAU * t)
    return rig.add({"spine": (14.0, 0.0, -8.0 * s), "head": (-4.0, 0.0, 4.0 * s), "hips": (0.0, 0.0, -4.0 * s),
                    "arm_r": (-46.0, -4.0 + 10.0 * s, 0.0), "arm_l": (-44.0, 10.0 + 10.0 * s, 0.0),
                    "tgnd": (0.5 * s, -1.0, BROOM_HEAD), "aim": (0.28, 1.0), "leg_l": (-8.0, 0, 0), "leg_r": (6.0, 0, 0)},
                   PLANT)


def carry_can_walk(t: float) -> dict:
    """20 frames: walking with the full can in the right hand - shorter steps, leaning away from it."""
    g = rig.gait(t, leg=20.0, lift=0.035, arm=6.0, bob=0.016, roll=4.0, yaw=3.0, lean=1.0)
    return rig.add(g, {"arm_r": (-6.0, -8.0, 0.0), "spine": (0.0, 4.0, 0.0), "arm_l": (0.0, -10.0, 0.0)})


def oops(t: float) -> dict:
    """18 frames one-shot: a start after a mistake - the shoulders go up, the arms out a little, the head
    back, then he looks down at what he did."""
    up = {"spine": (-6.0, 0.0, 0.0), "head": (-10.0, 0.0, 0.0), "arm_l": (-22.0, -14.0, 0.0), "arm_r": (-22.0, 14.0, 0.0),
          "hips": (0, 0, 0, 0, 0, 0.012), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    look = {"spine": (8.0, 0.0, 0.0), "head": (16.0, 0.0, 0.0), "arm_l": (-8.0, -4.0, 0.0), "arm_r": (-8.0, 4.0, 0.0),
            "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    return rig.keyed(t, [(0.0, dict(PLANT)), (0.22, up), (0.6, look), (1.0, dict(PLANT))], wrap=False)


def whistle(t: float) -> dict:
    """72 frames: in good spirits - the head tilted, the hands behind his back, rocking on his heels."""
    s = math.sin(rig.TAU * t * 2.0)
    return rig.add(rig.breathe(t, 1.0), {"head": (-6.0, 10.0, 6.0 * math.sin(rig.TAU * t)), "arm_l": (18.0, -8.0, 0.0),
                                         "arm_r": (18.0, 8.0, 0.0), "spine": (-2.0 * s, 0.0, 0.0),
                                         "hips": (0.0, 0.0, 0.0, 0.0, 0.0, 0.006 * max(0.0, s))}, PLANT)


TOOLS = {   # child name -> (tool-space builder, show_with, carry_with)
    "rake": (PR.rake_small, ("rake",), ("idle", "walk", "talk", "watch", "read_board", "oops")),
    "watering_can": (PR.watering_can, ("water", "carry_can_walk"), ("idle", "walk", "talk", "watch", "oops")),
    "broom": (PR.broom, ("sweep",), ("idle", "walk", "talk", "watch", "oops")),
    "lantern": (lambda name: PR.lantern_hand(0.95, name), ("lantern_walk",), ("idle", "idle_low", "talk")),
}


def actions() -> list:
    out = [
        ("idle-loop", 72, idle),
        ("walk-loop", 18, walk),
        ("talk-loop", 60, _talk(TALK_KEYS, 1.1)),
        ("rake-loop", 40, rake),
        ("weed-loop", 36, weed),
        ("water-loop", 40, water),
        ("candle", 45, candle),
        ("watch-loop", 72, watch),
        ("read_board", 40, read_board),
        ("sit_eat-loop", 72, sit_eat),
        ("sweep-loop", 36, sweep_),
        ("carry_can_walk-loop", 20, carry_can_walk),
        ("oops", 18, oops),
        ("whistle-loop", 72, whistle),
    ]
    out += M.p8_actions({"low", "lantern", "dance", "clap"}, walk, lantern_side=-1, dance_kw={"lift": 0.04, "sway": 5.0})
    return out


def build():
    mesh, sh, wr, hands, pts = build_mesh()
    fist_r, fist_l = hands[-1].copy(), hands[1].copy()
    joints = _joints(0.68, 0.76, Vector((0, -0.01, 1.12)), Vector((0, -0.03, 1.42)), sh, wr, 0.085)
    joints[TOOL] = (tuple(fist_r), tuple(fist_r + Vector((0.0, 0.0, 0.3))))
    kids = []
    for cname, (fn, show, carry) in TOOLS.items():
        obj = fn(name=cname)
        M.place(obj, fist_r)
        kids.append(M.child(cname, TOOL, obj, show))
    dz = min(v.co.z for v in mesh.data.vertices)
    fists = {"arm_r": fist_r - Vector((0, 0, dz)), "arm_l": fist_l - Vector((0, 0, dz))}
    acts = [(n, f, fn, ToolHook(fists, fn)) for n, f, fn in actions()]
    M.export_figure(NAME, mesh, joints, acts, extra={TOOL: ("spine", (0.0, -1.0, 0.0))}, children=kids,
                    markers=[M.face_marker(pts)],
                    extras_more={c: {"carry_with": ",".join(v[2])} for c, v in TOOLS.items()})


if __name__ == "__main__":
    build()
