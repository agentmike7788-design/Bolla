"""Phase 8: the mourners - the kin who come up to the graves (docs/PHASE8_DESIGN.md §2.2.1, §8.1) - and
the shared Phase-8 figure helpers (export with child meshes, the visit / mourning / festival clips) used by
asset_apprentice, asset_wanderers and the villagers' / gravekeeper's re-export.

  ph_chr_mourner_w_a  Martha Kehr, 41 - a day labourer's widow: a dark woollen shawl over head and
                      shoulders, a faded apron, a floor-length skirt; the basket (child `basket`, arm_l)
                      and a bunch of winter heath (child `bouquet`, arm_r)
  ph_chr_mourner_w_b  Gesa Ott, 26 - a farmer's daughter: a light headscarf knotted at the nape, a black
                      skirt, a dark wrap crossed over the chest; everlastings (child `bouquet`)
  ph_chr_mourner_m_a  Hinrich Brandt, 34 - a carter's man: a knee-long smock, a neckerchief, the felt hat
                      (child `hat_head` on the head, `hat_hand` held in front of the belly), fir sprigs
                      (child `bouquet`)
  ph_chr_mourner_m_b  Johann Sieber, 71 - an old farmhand: a long coat, a slouch hat (`hat_head` /
                      `hat_hand`), his stick in the left hand (part of the body), bent; he brings nothing

Two builders (women / men), one parameter set each figure. Grief is shown in the posture only: the head
lowered, the hands folded low in front, kneeling (women, floor-length skirt) or standing with the hat
in the hands (men); no tears, nothing brought to the face.

Child meshes: separate mesh nodes on a bone (glTF node below the joint -> Godot BoneAttachment3D +
MeshInstance3D) with the glTF extras {"show_with": "<clip>,<clip>,..."} (Godot: node meta "extras") -
the clips in which the owner (Npc, P1) shows them; hidden in every other clip.
Markers: "face" on the head bone in front of the nose (every Phase-8 face is built by lib_faces._head:
the review / close-up cameras aim there).

Run:  python tools/blender/build_all.py asset_mourners
"""
import json
import math
import struct

import bpy  # must be imported before bmesh
import bmesh  # noqa: F401
from mathutils import Matrix, Vector, noise

import lib_painted as L
import rig
from asset_carter import loft, sweep, _tint, _thicken, _n
from asset_villagers import (Prof, _body, _sheet_on, _shoe, _leg_tube, _arm, _ell, _ring_band, _global_light, _joints,
                             _idle, _walk, _talk, _painted, _side, SKIN, SKIN_ROSY, SKIN_PALE, SKIN_OLD, BOOT, BOOT_WORN,
                             BLACK, BLACK_DARK, BLACK_SHEEN, LINEN_WHITE, LINEN_SHADE, WOOD, WOOD_DARK, IRON, LEATHER,
                             LEATHER_DARK)
from lib_faces import (IRIS_BROWN, IRIS_HAZEL, IRIS_BLUE, IRIS_GREY, IRIS_DARK, _s01, Face, _hair, _cloth_cover, _head,
                       _shell, _stable_glb)
import asset_props_phase8 as PR

W = rig.weight
CAT = "characters"


# ======================================================================================================
# shared Phase-8 figure helpers
# ======================================================================================================

def set_extras(path: str, extras: dict) -> None:
    """Write glTF node extras (node name -> dict) into an exported .glb (the JSON chunk may grow)."""
    with open(path, "rb") as f:
        data = f.read()
    jlen = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + jlen]))
    found = set()
    for node in doc.get("nodes", []):
        if node.get("name") in extras:
            node.setdefault("extras", {}).update(extras[node["name"]])
            found.add(node["name"])
    missing = set(extras) - found
    assert not missing, f"{path}: no glTF node {sorted(missing)}"
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = data[20 + jlen:]
    out = struct.pack("<III", 0x46546C67, 2, 20 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
    with open(path, "wb") as f:
        f.write(out)


def child(name: str, bone: str, obj, show) -> tuple:
    """A child mesh for export_figure: (node name, bone, object, clips it is shown with)."""
    L.smooth(obj, 55)
    return (name, bone, obj, tuple(show))


def export_figure(name: str, mesh, joints: dict, actions, *, extra=None, children=(), markers=(), extras_more=None) -> None:
    """Ground the body, build the shared rig (+ extra bones), bind, hang the child meshes and markers on
    their bones, key the actions (name, frames, pose fn[, post hook]) and export deterministically."""
    dz = rig.ground(mesh)
    shift = Vector((0.0, 0.0, dz))
    j = {b: (tuple(Vector(h) - shift), tuple(Vector(t) - shift)) for b, (h, t) in joints.items()}
    arm = rig.build_armature(j, extra=extra)
    rig.bind(mesh, arm)
    extras = {}
    names = {e[0][:-5] if e[0].endswith("-loop") else e[0] for e in actions}
    for cname, bone, obj, show in children:
        obj.data.transform(Matrix.Translation(-shift))
        obj.name = cname
        obj.data.name = cname
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = Matrix.Identity(4)
        extras[cname] = {"show_with": ",".join(c for c in show if c in names)}
    for cname, more in (extras_more or {}).items():
        extras.setdefault(cname, {}).update(more)
    for mname, bone, loc in markers:
        rig.bone_marker(arm, bone, mname, Vector(loc) - shift)
    for entry in actions:
        rig.add_action(arm, mesh, entry[0], entry[1], entry[2], entry[3] if len(entry) > 3 else None)
    L.export_rigged(arm, name, CAT)
    path = L.os.path.join(L.ROOT, "assets", "models", CAT, name + ".glb")
    if extras:
        set_extras(path, extras)
    _stable_glb(path)


def place(obj, at: Vector, rot: Matrix = None):
    """Move a tool-space object (grip at the origin) to `at`, optionally turned about the grip first."""
    m = Matrix.Translation(Vector(at))
    if rot is not None:
        m = m @ rot
    obj.data.transform(m)
    return obj


def lantern_child(fist: Vector, swing: float = 30.0, sx: int = 1, scale: float = 0.9):
    """The procession lantern (Lichtgang) in a fist: hangs plumb while the arm is swung `swing` degrees
    forward (lantern_walk), i.e. it is modelled turned back by that much about the fist."""
    lan = PR.lantern_hand(scale, "lantern_prop")
    place(lan, fist + Vector((0.0, -0.005, -0.02)), Matrix.Rotation(math.radians(swing), 4, "X"))
    return lan


def face_marker(pts) -> tuple:
    """('face', 'head', point in front of the nose)."""
    return ("face", "head", tuple(pts["nose"] + Vector((0.0, -0.04, 0.0))))


# --- the Phase-8 clips (§8.2) ---------------------------------------------------------------------------

PLANT = {"feet": {"leg_l": 0.0, "leg_r": 0.0}}


def idle_low(amount: float = 1.0, head: float = 14.0):
    """90 frames: low spirits - the head lowered 14 deg, the shoulders forward, slow breathing, the weight
    shifts once."""
    def fn(t: float) -> dict:
        return rig.add(rig.breathe(t, 0.8 * amount), rig.bowed(head, 4.0), rig.weight_shift(t, 0.6), PLANT)
    return fn


def _kneel_keys(k: dict) -> list:
    """Going down: the upper body leans first, the hips follow; the feet stay planted."""
    half = rig.blend(PLANT, k, 0.45)
    half["spine"] = (k["spine"][0] + 10.0,) + tuple(k["spine"][1:])
    half["feet"] = {"leg_l": 0.0, "leg_r": 0.0}
    return [(0.0, dict(PLANT)), (0.45, half), (1.0, k)]


def kneel_in(k: dict):
    """24 frames one-shot: from standing down onto the knees (ends in the first kneel frame)."""
    return rig.once(_kneel_keys(k))


def kneel_out(k: dict):
    """24 frames one-shot: back up (starts in the kneel pose, ends at rest)."""
    keys = _kneel_keys(k)
    return rig.once([(1.0 - t, p) for t, p in reversed(keys)])


def kneel_loop(k: dict):
    """90 frames: kneeling - breathing, the head bowed, a very slow small nod."""
    def fn(t: float) -> dict:
        s = math.sin(rig.TAU * t)
        return rig.add(k, rig.breathe(t, 0.8), {"head": (1.5 * s, 0.0, 0.0)}, {"feet": k["feet"]})
    return fn


def lay_flowers(bend: float = 50.0, drop: float = 0.25, reach: float = 80.0):
    """45 frames one-shot: bends forward (spine ~35-40 deg, the hips a little down and back), the right
    arm reaches forward and down to the mound, lays the bunch down at frame 30 (t = 0.667) and comes back
    up. (Arms hang from the spine: a forward bend swings them back, so the arm turns further forward.)"""
    down = rig.add({"hips": (4.0, 0.0, 0.0, 0.0, 0.05, -drop), "spine": (bend, 0.0, -4.0), "head": (-6.0, 0.0, 2.0),
                    "arm_r": (-reach, -4.0, 6.0), "arm_l": (-bend * 0.7, 6.0, 0.0)}, PLANT)
    laid = rig.add(down, {"arm_r": (8.0, 0.0, 0.0), "spine": (2.0, 0.0, 0.0)})
    return rig.once([(0.0, dict(PLANT)), (0.42, down), (0.667, laid), (0.78, laid), (1.0, dict(PLANT))])


LAY_RELEASE = 30.0 / 45.0


def mourn_stand(amount: float = 1.0, head: float = 16.0, hands=(28.0, 24.0)):
    """90 frames: standing at the grave, the hands (with the hat) folded low in front, the head lowered,
    the weight going slowly from one leg to the other."""
    def fn(t: float) -> dict:
        return rig.add(rig.breathe(t, 0.7 * amount), rig.bowed(head, 5.0), rig.folded(*hands),
                       rig.weight_shift(t, 1.0))
    return fn


def knock(side: int = -1):
    """20 frames one-shot: the hand comes up to a door and knocks twice."""
    arm = "arm_r" if side < 0 else "arm_l"
    sy = -1.0 if side < 0 else 1.0
    up = rig.add({arm: (-84.0, sy * 4.0, -sy * 8.0), "spine": (2.0, 0.0, 0.0), "head": (2.0, 0.0, 0.0)}, PLANT)
    hit = rig.add(up, {arm: (8.0, 0.0, 0.0)})
    return rig.once([(0.0, dict(PLANT)), (0.3, up), (0.42, hit), (0.54, up), (0.66, hit), (0.78, up), (1.0, dict(PLANT))])


def lantern_walk(walk_fn, side: int = 1, swing: float = 30.0):
    """22 frames: the figure's own walk, the lantern arm held `swing` deg forward and calm."""
    arm = "arm_l" if side > 0 else "arm_r"

    def fn(t: float) -> dict:
        p = walk_fn(t)
        p[arm] = (-swing + 2.0 * math.sin(rig.TAU * t * 2.0), 0.0, 0.0)
        return p
    return fn


def dance(lift: float = 0.035, sway: float = 4.0, arms: float = 72.0):
    """48 frames: swaying and stepping on the spot, the arms on the partner's shoulders (the turn round the
    couple's middle is done slowly by the Npc code)."""
    def fn(t: float) -> dict:
        s = math.sin(rig.TAU * t * 2.0)
        return rig.add(rig.step_in_place(t, lift, sway, 2),
                       {"arm_l": (-arms + 3.0 * s, 4.0, 0.0), "arm_r": (-arms - 3.0 * s, -4.0, 0.0),
                        "head": (-2.0, 0.0, 4.0 * math.sin(rig.TAU * t)), "spine": (-2.0, 0.0, 0.0)})
    return fn


def clap(amount: float = 1.0):
    """24 frames: an onlooker clapping in time - the hands meet in front of the chest twice."""
    def fn(t: float) -> dict:
        c = 0.5 + 0.5 * math.cos(rig.TAU * t * 2.0)   # 1 = hands apart, 0 = together
        return rig.add({"arm_l": (-42.0 * amount, 14.0 + 12.0 * (1.0 - c), 0.0),
                        "arm_r": (-42.0 * amount, -14.0 - 12.0 * (1.0 - c), 0.0),
                        "head": (-3.0, 0.0, 3.0 * math.sin(rig.TAU * t)), "spine": (-1.0, 0.0, 0.0)},
                       rig.step_in_place(t, 0.0, 1.5, 2))
    return fn


def p8_actions(sets, walk_fn, *, kneel_pose=None, lantern_side: int = 1, lay=None, mourn=None, low=None,
               dance_kw=None, knock_side: int = -1):
    """The Phase-8 clips of one figure. sets: any of low, kneel, lay, mourn, knock, lantern, dance, clap."""
    k = kneel_pose or rig.kneel()
    out = []
    if "low" in sets:
        out.append(("idle_low-loop", 90, idle_low(**(low or {}))))
    if "kneel" in sets:
        out += [("kneel_in", 24, kneel_in(k)), ("kneel-loop", 90, kneel_loop(k)), ("kneel_out", 24, kneel_out(k))]
    if "lay" in sets:
        out.append(("lay_flowers", 45, lay_flowers(**(lay or {}))))
    if "mourn" in sets:
        out.append(("mourn_stand-loop", 90, mourn_stand(**(mourn or {}))))
    if "knock" in sets:
        out.append(("knock", 20, knock(knock_side)))
    if "lantern" in sets:
        out.append(("lantern_walk-loop", 22, lantern_walk(walk_fn, lantern_side)))
    if "dance" in sets:
        out.append(("dance-loop", 48, dance(**(dance_kw or {}))))
    if "clap" in sets:
        out.append(("clap-loop", 24, clap()))
    return out


def clip_names(actions) -> list:
    return [a[0][:-5] if a[0].endswith("-loop") else a[0] for a in actions]


# ======================================================================================================
# the women: Martha Kehr, Gesa Ott
# ======================================================================================================

WICKER = L.hexc("#8A7048")
WICKER_DARK = L.hexc("#5E4A32")


def _basket(fist: Vector, seed: int = 0):
    """A wicker basket hanging from the left fist by its bow handle, a few heath sprigs in it. ~250 tris."""
    c = fist + Vector((0.02, -0.02, -0.25))
    parts = []
    body = loft([(c.z - 0.07, 0.11, 0.075, c.x, c.y), (c.z, 0.13, 0.09, c.x, c.y), (c.z + 0.05, 0.14, 0.095, c.x, c.y)],
                n=12, caps=(True, False), name="basket")
    _painted(body, WICKER, var=0.2, ao=0.25, top=0.3, seed=seed, hue_shift=WICKER_DARK)
    _tint(body, lambda co, nr: (1.0 - 0.22 * max(0.0, math.sin(co.z * 160.0 + math.sin(math.atan2(co.y - c.y, co.x - c.x)
                                                                                                    * 14.0) * 1.4)), None, 0.0))
    parts.append(body)
    bow = [Vector((c.x - 0.12, c.y, c.z + 0.05)), Vector((c.x - 0.09, c.y, c.z + 0.17)), fist + Vector((0, 0, -0.01)),
           Vector((c.x + 0.09, c.y, c.z + 0.17)), Vector((c.x + 0.12, c.y, c.z + 0.05))]
    parts.append(_painted(sweep(bow, 0.008, n=4, name="bow"), WICKER_DARK, var=0.15, ao=0.0))
    for k, (dx, dy) in enumerate(((-0.05, 0.0), (0.0, 0.02), (0.05, -0.01), (0.02, -0.03))):
        parts.append(_ell(PR.HEATH, c + Vector((dx, dy, 0.075)), (0.03, 0.03, 0.035), seg=5, rings=4, jit=0.005,
                          seed=seed + 3 + k, ao=0.1, var=0.2, hue_shift=PR.HEATH_DARK))
    return L.join(parts, "basket")


WOMEN = {
    "ph_chr_mourner_w_a": dict(
        seed=8101, scale=1.0, skin=SKIN_OLD, hair=L.hexc("#4E3A2A"), hair_dark=L.hexc("#7A6E62"),
        dress=L.hexc("#36302C"), dress_dark=L.hexc("#24201E"), bodice=None,
        apron=L.hexc("#6A6458"), shawl=L.hexc("#4E463C"), shawl_dark=L.hexc("#36302A"), head="hood", kerchief=None,
        bouquet="heath", basket=True, slim=1.0,
        face=dict(nose="straight", nose_s=1.0, brow_w=1.0, brow_tilt=0.55, brow_arch=0.9, mouth="kind", smile=0.3,
                  cheeks=0.5, jaw=0.95, chin=0.02, age=0.25, lids=0.27, iris=IRIS_HAZEL)),
    "ph_chr_mourner_w_b": dict(
        seed=8201, scale=0.98, skin=SKIN, hair=L.hexc("#7A5A3A"), hair_dark=L.hexc("#5A4028"),
        dress=L.hexc("#262322"), dress_dark=L.hexc("#1A1818"), bodice=L.hexc("#2E2A28"),
        apron=None, shawl=L.hexc("#4E5244"), shawl_dark=L.hexc("#363A30"), head="kerchief", kerchief=L.hexc("#CDBFA0"),
        bouquet="straw", basket=False, slim=0.93,
        face=dict(nose="round", nose_s=0.9, brow_w=0.85, brow_tilt=0.4, brow_arch=1.2, mouth="kind", smile=0.45,
                  cheeks=0.75, jaw=0.9, chin=0.04, age=0.0, lids=0.2, iris=IRIS_BLUE, eyes=1.08)),
}


def _woman(name: str, cfg: dict):
    L.reset(cfg["seed"])
    parts = []
    sl = cfg["slim"]
    rings = ((0.015, 0.295, 0.275, 0.018), (0.2, 0.278, 0.258, 0.014), (0.5, 0.245, 0.222, 0.006),
             (0.75, 0.214, 0.186, 0.0), (0.9, 0.19, 0.16, 0.0), (0.97, 0.172, 0.144, -0.004),
             (1.05, 0.174, 0.148, -0.01), (1.15, 0.188, 0.158, -0.012), (1.22, 0.188, 0.15, -0.008),
             (1.27, 0.172, 0.132, -0.004), (1.31, 0.13, 0.105, -0.004), (1.34, 0.07, 0.065, -0.008))
    prof = Prof(tuple((z, rx * sl, ry * sl, cy) for z, rx, ry, cy in rings))
    waist = 0.97
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.09, BOOT, length=0.125, width=0.06, height=0.052, toe=-0.075, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.09, 0.0, 0.04), (sx * 0.094, 0.0, 0.5), (sx * 0.095, 0.0, 0.86)],
                  [0.046, 0.05, 0.062], BLACK, seed=12)
    dress = _body(prof, cfg["dress"], cfg["dress_dark"], n=26, seed=1, fold=0.014, fold_k=6.0)
    _tint(dress, lambda co, nr: (1.0, BLACK_SHEEN, 0.2 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(dress, waist, "hips", "spine"))
    if cfg["bodice"] is not None:
        bod = _sheet_on(prof, [0] * 5, [0.99, 1.06, 1.13, 1.2, 1.25], 0.004, cfg["bodice"], seed=2, thick=0.006,
                        xfn=lambda z: (-0.14 * sl, 0.14 * sl))
        parts.append(W("spine", bod))
    if cfg["apron"] is not None:
        ap = _sheet_on(prof, [0] * 7, [0.12, 0.3, 0.5, 0.7, 0.86, 0.96], 0.01, cfg["apron"], L.scale_c(cfg["apron"], 0.8),
                       seed=3, xfn=lambda z: ((-0.16 - 0.06 * (0.96 - z)) * sl, (0.16 + 0.06 * (0.96 - z)) * sl))
        _tint(ap, lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(co.x * 46.0)) * max(0.0, (0.9 - co.z) / 0.8), None, 0.0))
        parts.append(W("hips", ap))
        parts.append(W("hips", _ring_band(prof, waist, 0.012, L.scale_c(cfg["apron"], 0.75), out=0.012, flat=0.45, seed=4)))
    else:
        parts.append(W("hips", _ring_band(prof, waist, 0.012, cfg["dress_dark"], out=0.006, flat=0.45, seed=4)))
    # arms: woollen sleeves, the hands at the sides
    sh = {sx: Vector((sx * 0.19 * sl, -0.004, 1.27)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.235 * sl, 0.0, 1.04)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.245 * sl, -0.08, 0.84)) for sx in (-1, 1)}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], cfg["dress"], cfg["dress_dark"],
                         r=(0.052 * sl, 0.05 * sl, 0.046 * sl, 0.044 * sl), skin=cfg["skin"], seed=20 + sx * 3,
                         hand_size=1.0, grip=True)
    c = Vector((0.0, -0.03, 1.45))
    s = Vector((0.13, 0.132, 0.142)) * (1.0 if sl > 0.95 else 0.97)
    f = cfg["face"]
    pts = _head(parts, c, s, cfg["skin"], seed=30, brow=cfg["hair"], ears=False, seg=24, rings=16,
                cull=lambda n: n.z > 0.62 or (n.y > 0.3 and n.z > 0.2), **f)
    face = pts["face"]
    _hair(parts, face, cfg["hair"], cfg["hair_dark"], [(0.0, 0.42), (0.6, 0.34), (1.0, 0.08), (1.3, -0.16), (math.pi, -0.5)],
          out=0.005, crown=0.003, part_u=0.0, seed=31)
    if cfg["head"] == "hood":
        # the dark woollen shawl pulled over the head, crossed on the chest, a point down the back (Liesel's way)
        hood, _ = _cloth_cover(parts, face, cfg["shawl"], cfg["shawl_dark"],
                               [(0.0, 0.62), (0.5, 0.56), (0.9, 0.24), (1.12, -0.3), (1.3, -0.8), (1.6, -0.96),
                                (math.pi, -0.96)],
                               out=lambda ph, w: 0.024 + 0.012 * max(0.0, math.cos(ph)) + 0.02 * _s01((-w - 0.1) / 0.6)
                               + 0.014 * abs(math.sin(ph)),
                               crown=0.014, folds=6.0, rim=0.013 * face.k, rim_phi=1.35, lumps=0.008, seed=32,
                               name="shawl_hood")
        _tint(hood, lambda co, nr: (1.0 - 0.12 * max(0.0, math.sin(co.x * 50.0 + co.z * 20.0)), None, 0.0))
    else:
        # the light headscarf knotted at the nape, two short tails
        _cloth_cover(parts, face, cfg["kerchief"], LINEN_SHADE, [(0.0, 0.6), (0.6, 0.52), (1.05, 0.16), (1.4, -0.26),
                                                                (2.0, -0.55), (math.pi, -0.68)],
                     out=lambda ph, w: 0.015 + 0.006 * max(0.0, math.cos(ph)), crown=0.006, folds=7.0,
                     rim=0.009 * face.k, rim_phi=1.9, lumps=0.006, seed=32, name="kerchief")
        knot = c + Vector((0.0, s.y + 0.028, -0.075))
        parts.append(W("head", _ell(cfg["kerchief"], knot, (0.036, 0.03, 0.032), seg=8, rings=5, seed=34, jit=0.004)))
        for sx in (-1, 1):
            t0 = knot + Vector((sx * 0.012, 0.01, -0.01))
            parts.append(W("head", _painted(sweep([t0, t0 + Vector((sx * 0.03, 0.03, -0.07)),
                                                   t0 + Vector((sx * 0.04, 0.04, -0.12))], [0.022, 0.02, 0.007], n=6,
                                                  flat=0.35, name="tail"), cfg["kerchief"], var=0.1, ao=0.1, top=0.2,
                                          seed=35 + sx)))
    # the shawl / wrap round the shoulders: a soft drape with a point down the back, the ends crossed on the
    # chest and tucked into the waist
    drape = loft([(1.12, 0.218 * sl, 0.18 * sl, 0.0, -0.002), (1.2, 0.216 * sl, 0.174 * sl, 0.0, 0.0),
                  (1.27, 0.202 * sl, 0.154 * sl, 0.0, 0.0), (1.32, 0.162, 0.13, 0.0, 0.0), (1.36, 0.12, 0.112, 0.0, 0.0)],
                 n=22, caps=(False, False), name="drape")
    for v in drape.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        if v.co.z < 1.13:
            v.co.z -= 0.2 * max(0.0, math.sin(a)) ** 3
            v.co.z += 0.03 * max(0.0, -math.sin(a))
    L.jitter(drape, 0.005, 6.0, 33)
    _painted(drape, cfg["shawl"], var=0.18, ao=0.2, top=0.25, seed=33, hue_shift=cfg["shawl_dark"])
    _tint(drape, lambda co, nr: (1.0 - 0.12 * max(0.0, math.sin(math.atan2(co.y, co.x) * 6.0)), None, 0.0))
    parts.append(rig.weight_split_z(drape, 1.33, "spine", "head"))
    for sx in (-1, 1):
        q = [prof.surf(sx * 0.12 * sl, 1.25, -1, 0.02), prof.surf(sx * 0.02, 1.12, -1, 0.02),
             prof.surf(-sx * 0.07 * sl, 0.99, -1, 0.02)]
        parts.append(W("spine", _painted(sweep(q, [0.05, 0.05, 0.04], n=6, flat=0.25, name="cross",
                                               normals=[prof.normal(p.x, p.z) for p in q]), cfg["shawl"], var=0.15,
                                         ao=0.1, top=0.25, seed=34 + sx, hue_shift=cfg["shawl_dark"])))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.62)
    L.smooth(mesh, 55)
    joints = _joints(0.84, waist, Vector((0, -0.01, 1.33)), Vector((0, -0.03, 1.64)), sh, wr, 0.094)
    # child meshes
    kids = []
    bq = PR.BOUQUETS[cfg["bouquet"]](seed=cfg["seed"] % 7)
    place(bq, hands[-1] + Vector((0.0, -0.01, 0.0)), Matrix.Rotation(math.radians(30.0), 4, "X"))
    kids.append(child("bouquet", "arm_r", bq, ("idle", "walk", "talk", "idle_low", "lay_flowers")))
    if cfg["basket"]:
        kids.append(child("basket", "arm_l", _basket(hands[1], cfg["seed"]),
                          ("idle", "walk", "talk", "idle_low", "lay_flowers")))
    kids.append(child("lantern_prop", "arm_l", lantern_child(hands[1]), ("lantern_walk",)))
    sc = cfg["scale"]
    walk = _walk(21.0, 0.035, 12.0, 0.012, 2.5, 3.5, 3.0)
    talk_keys = [
        (0.0, {"arm_r": (-18.0, -4.0, 8.0), "arm_l": (-14.0, 4.0, -6.0), "head": (5.0, 0.0, 3.0)}),
        (0.3, {"arm_r": (-30.0, -8.0, 14.0), "arm_l": (-18.0, 6.0, -8.0), "head": (2.0, -3.0, -2.0)}),
        (0.6, {"arm_r": (-22.0, -6.0, 10.0), "arm_l": (-26.0, 8.0, -12.0), "head": (6.0, 2.0, 4.0)}),
    ]
    actions = [
        ("idle-loop", 72, _idle(0.9, 0.6, 0.8, lambda t: {"head": (5.0, 0, 0), "arm_l": (-5.0, 4.0, -4.0),
                                                           "arm_r": (-5.0, -4.0, 4.0)})),
        ("walk-loop", 20, walk),
        ("talk-loop", 72, _talk(talk_keys, 0.9)),
    ] + p8_actions({"low", "kneel", "lay", "lantern"}, walk, kneel_pose=rig.kneel(0.42, 12.0, 14.0, 18.0, hands=(18.0, 28.0)))
    if sc != 1.0:
        _scale(mesh, joints, kids, sc)
        pts["nose"] = pts["nose"] * sc
    export_figure(name, mesh, joints, actions, children=kids, markers=[face_marker(pts)])


def _scale(mesh, joints, kids, sc: float) -> None:
    """Uniform scale of a figure about its ground pivot (body, joints, children)."""
    m = Matrix.Scale(sc, 4)
    mesh.data.transform(m)
    for b in list(joints):
        h, t = joints[b]
        joints[b] = (tuple(Vector(h) * sc), tuple(Vector(t) * sc))
    for k in kids:
        k[2].data.transform(m)


def mourner_w_a():
    _woman("ph_chr_mourner_w_a", WOMEN["ph_chr_mourner_w_a"])


def mourner_w_b():
    _woman("ph_chr_mourner_w_b", WOMEN["ph_chr_mourner_w_b"])


# ======================================================================================================
# the men: Hinrich Brandt, Johann Sieber
# ======================================================================================================

def _hat(c: Vector, s: Vector, color, dark, *, brim: float, crown_h: float, slouch: float = 0.0, seed: int = 0,
         band=None):
    """A felt hat over a head (centre c, semi-axes s): the brim (slouch = how far it droops at front and
    back), a rounded crown, a band. One object."""
    parts = []
    hz = c.z + s.z * 0.4
    b = L.prim("cyl", loc=(0, c.y, hz), radius=1.0, depth=0.012, vertices=14, scale=(s.x + brim, s.y + brim, 1.0))
    for v in b.data.vertices:
        r = math.hypot(v.co.x / (s.x + brim), (v.co.y - c.y) / (s.y + brim))
        a = math.atan2(v.co.y - c.y, v.co.x)
        v.co.z -= slouch * max(0.0, r - 0.6) * (0.4 + 0.6 * abs(math.sin(a))) - 0.012 * max(0.0, r - 0.7) * abs(math.cos(a))
    L.jitter(b, 0.004, 9.0, seed)
    parts.append(_painted(b, color, var=0.12, ao=0.0, top=0.3, seed=seed, hue_shift=dark))
    cr = loft([(hz, s.x + 0.012, s.y + 0.012, 0.0, c.y), (hz + crown_h * 0.6, s.x + 0.006, s.y + 0.004, 0.0, c.y),
               (hz + crown_h, s.x - 0.03, s.y - 0.03, 0.0, c.y)], n=16, p=2.2, name="crown")
    L.jitter(cr, 0.004, 8.0, seed + 1)
    parts.append(_painted(cr, color, var=0.12, ao=0.15, top=0.3, seed=seed + 1, hue_shift=dark))
    if band is not None:
        parts.append(_ring_band(Prof(((hz + 0.016, s.x + 0.013, s.y + 0.013, c.y),)), hz + 0.016, 0.011, band, out=0.002,
                                n=16, flat=0.6, seed=seed + 2))
    return L.join(parts, "hat")


MEN = {
    "ph_chr_mourner_m_a": dict(
        seed=8301, kind="smock", hip=0.92, waist=0.98, tall=1.0, bent=0.0, skin=SKIN_ROSY,
        hair=L.hexc("#8A6E48"), hair_dark=L.hexc("#5E4A32"),
        coat=L.hexc("#5C605C"), coat_dark=L.hexc("#40443F"), trouser=L.hexc("#3C3833"), neck=L.hexc("#8A6E40"),
        hat=L.hexc("#3E3228"), hat_dark=L.hexc("#2A221C"), brim=0.06, crown_h=0.1, slouch=0.0, bouquet="fir",
        stick=False, beard=None,
        face=dict(nose="round", nose_s=1.05, brow_w=1.35, brow_tilt=0.35, brow_arch=0.7, mouth="thin", smile=0.3,
                  cheeks=0.6, jaw=1.04, chin=0.02, age=0.05, lids=0.22, iris=IRIS_BLUE, muzzle=1.05)),
    "ph_chr_mourner_m_b": dict(
        seed=8401, kind="coat", hip=0.86, waist=0.94, tall=0.95, bent=1.0, skin=SKIN_OLD,
        hair=L.hexc("#CFC9BE"), hair_dark=L.hexc("#9A948A"),
        coat=L.hexc("#4A443E"), coat_dark=L.hexc("#332F2B"), trouser=L.hexc("#3A3632"), neck=L.hexc("#6A6458"),
        hat=L.hexc("#3A342E"), hat_dark=L.hexc("#26221E"), brim=0.085, crown_h=0.085, slouch=0.05, bouquet=None,
        stick=True, beard=L.hexc("#BDB7AC"),
        face=dict(nose="hook", nose_s=1.1, brow_w=1.2, brow_tilt=0.45, brow_arch=0.8, mouth="kind", smile=0.25,
                  cheeks=0.35, jaw=0.88, chin=0.04, age=0.75, lids=0.3, iris=IRIS_GREY, muzzle=0.9)),
}


def _man(name: str, cfg: dict):
    L.reset(cfg["seed"])
    parts = []
    hip, waist, tall, bent = cfg["hip"], cfg["waist"], cfg["tall"], cfg["bent"]
    smock = cfg["kind"] == "smock"
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.1
        _shoe(parts, leg, x0, BOOT, length=0.15, width=0.066, height=0.06, toe=-0.08, shaft=0.2 if smock else 0.12,
              shaft_r=0.062, seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.16), (sx * 0.104, -0.004, 0.45), (sx * 0.105, 0.0, hip)],
                  [0.064, 0.068, 0.08], cfg["trouser"], n=10, seed=12)
    top = 1.42 * tall
    sh_z = 1.38 * tall
    hb = -0.06 * bent   # the old man's forward stoop (the chest forward of the hips)
    if smock:
        # the knee-long smock (Kittel): wide, gathered at the yoke, a belt
        prof = Prof(((0.5, 0.27, 0.22, 0.02), (0.65, 0.26, 0.21, 0.014), (0.8, 0.245, 0.196, 0.008),
                     (0.95, 0.228, 0.18, 0.0), (1.05, 0.226, 0.178, -0.004), (1.18, 0.232, 0.18, -0.006),
                     (1.3, 0.236, 0.172, -0.004), (1.37, 0.21, 0.15, 0.0), (1.41, 0.16, 0.12, 0.0), (1.44, 0.09, 0.08, -0.004)))
        coat = _body(prof, cfg["coat"], cfg["coat_dark"], n=26, seed=3, fold=0.014, fold_k=9.0, fold_top=1.1)
        _tint(coat, lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(math.atan2(co.y, co.x) * 22.0)) *
                                    _s01((co.z - 1.18) / 0.2), None, 0.0))
        parts.append(rig.weight_split_z(coat, waist, "hips", "spine"))
        parts.append(W("hips", _ring_band(prof, waist, 0.016, LEATHER_DARK, out=0.01, flat=0.45, seed=4)))
    else:
        # the long coat (Mantel) to the calf, open a little at the front, a stooped back
        prof = Prof(((0.3, 0.27, 0.23, 0.03), (0.5, 0.25, 0.21, 0.02), (0.75, 0.222, 0.18, 0.008), (0.9, 0.206, 0.166, 0.0),
                     (0.98, 0.2, 0.162, -0.01 + hb * 0.3), (1.1, 0.206, 0.168, -0.01 + hb * 0.6),
                     (1.22, 0.214, 0.17, hb * 0.9), (1.3, 0.21, 0.162, hb), (1.35, 0.17, 0.13, hb * 1.05),
                     (1.38, 0.1, 0.085, hb * 1.1)))
        coat = _body(prof, cfg["coat"], cfg["coat_dark"], n=22, seed=3, fold=0.012, fold_top=0.95, part_front=0.3, part_w=0.45)
        _tint(coat, lambda co, nr: (1.0, L.scale_c(cfg["coat"], 1.2), 0.25 * max(0.0, nr.z)))
        parts.append(rig.weight_split_z(coat, waist, "hips", "spine"))
        for k in range(4):   # horn buttons
            p = prof.surf(0.05, 0.98 + k * 0.08, -1, 0.01)
            parts.append(W("spine" if p.z > waist else "hips", _ell(L.hexc("#5A4A3A"), p, (0.011, 0.006, 0.011), seg=6,
                                                                   rings=4, ao=0.0, top=0.4)))
        sh_z = 1.33
        top = 1.37
    # neckerchief (Halstuch) / scarf
    nz = top + 0.005
    ring = [Vector((math.cos(a) * 0.09, hb + math.sin(a) * 0.08, nz - 0.01 * math.sin(a))) for a in (math.tau * k / 14 for k in range(14))]
    parts.append(W("spine", _painted(sweep(ring, 0.026, n=6, closed=True, name="neck"), cfg["neck"], var=0.15, ao=0.1, top=0.2,
                                     seed=5)))
    kn = Vector((0.03, hb - 0.085, nz - 0.03))
    parts.append(W("spine", _ell(cfg["neck"], kn, (0.03, 0.022, 0.028), seg=8, rings=5, seed=6, jit=0.003)))
    parts.append(W("spine", _painted(sweep([kn, kn + Vector((0.01, -0.012, -0.08))], [0.022, 0.014], n=5, flat=0.35,
                                           name="tail"), cfg["neck"], var=0.12, ao=0.0, seed=7)))
    sh = {sx: Vector((sx * 0.215, hb * 0.9, sh_z)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.265, hb * 0.5, sh_z - 0.27)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.28, -0.07, sh_z - 0.5)) for sx in (-1, 1)}
    if cfg["stick"]:
        wr[1] = Vector((0.27, -0.16, sh_z - 0.47))
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], cfg["coat"], cfg["coat_dark"], r=(0.064, 0.06, 0.054, 0.054),
                         cuff=cfg["coat_dark"] if not smock else None, cuff_r=0.064, skin=cfg["skin"], seed=20 + sx * 3,
                         hand_size=1.1, grip=True)
    if cfg["stick"]:
        h = hands[1]
        parts.append(W("arm_l", _painted(L.tube(Vector((h.x + 0.01, h.y - 0.02, 0.0)), h + Vector((0, 0, 0.06)), 0.014, 6,
                                                r_end=0.016), WOOD_DARK, var=0.2, ao=0.0, top=0.3, seed=8)))
        parts.append(W("arm_l", _ell(WOOD_DARK, h + Vector((0, 0, 0.07)), (0.022, 0.022, 0.018), seg=6, rings=4, seed=9)))
    # head
    c = Vector((0.0, hb - 0.03, top + 0.16))
    s = Vector((0.136, 0.14, 0.152)) * (0.98 if bent else 1.0)
    f = cfg["face"]
    pts = _head(parts, c, s, cfg["skin"], seed=30, brow=cfg["hair_dark"] if not bent else cfg["hair"], seg=24, rings=16,
                cull=lambda n: n.z > 0.62, **f)
    face = pts["face"]
    _hair(parts, face, cfg["hair"], cfg["hair_dark"], [(0.0, 0.5), (0.5, 0.44), (1.0, 0.18), (1.3, -0.08), (1.7, -0.22),
                                                       (math.pi, -0.42)], out=0.006, crown=0.004, tuft=0.005, seed=31)
    if cfg["beard"] is not None:   # white stubble round the jaw
        beard, _, _ = _shell(face, [(0.0, -0.99)], top=[(0.0, -0.72), (0.4, -0.62), (0.8, -0.42), (1.3, -0.16), (1.62, -0.06)],
                             phi=(-1.62, 1.62), out=0.004, crown=0.0, n=16, m=4, tuck=0.002, seed=32, name="stubble")
        _painted(beard, cfg["beard"], var=0.2, ao=0.0, top=0.2, seed=33, hue_shift=cfg["skin"])
        _tint(beard, lambda co, nr: (1.0, cfg["skin"], 0.55 + 0.3 * max(0.0, _n(co, 60.0, 3.0))))
        parts.append(W("head", beard))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, top + 0.36)
    L.smooth(mesh, 55)
    joints = _joints(hip, waist, Vector((0, hb - 0.01, top)), Vector((0, hb - 0.04, top + 0.34)), sh, wr, 0.1)
    kids = []
    hat = _hat(c, s, cfg["hat"], cfg["hat_dark"], brim=cfg["brim"], crown_h=cfg["crown_h"], slouch=cfg["slouch"], seed=40,
               band=L.scale_c(cfg["hat"], 0.7))
    hat2 = hat.copy()
    hat2.data = hat.data.copy()
    bpy.context.collection.objects.link(hat2)
    kids.append(child("hat_head", "head", hat, ("idle", "walk", "talk", "idle_low", "lay_flowers", "lantern_walk")))
    # the hat in the hands: held by the brim in the right fist, the crown towards him, in front of the belly
    hz = c.z + s.z * 0.4
    m = (Matrix.Translation(hands[-1] + Vector((0.03, -0.04, -0.06))) @ Matrix.Rotation(math.radians(-80.0), 4, "X")
         @ Matrix.Translation(Vector(((s.x + cfg["brim"]) * 0.45, 0.0, 0.0)) - Vector((0.0, c.y, hz))))
    hat2.data.transform(m)
    kids.append(child("hat_hand", "arm_r", hat2, ("mourn_stand",)))
    if cfg["bouquet"]:
        bq = PR.BOUQUETS[cfg["bouquet"]](seed=cfg["seed"] % 7)
        place(bq, hands[-1] + Vector((0.0, -0.01, 0.0)), Matrix.Rotation(math.radians(30.0), 4, "X"))
        kids.append(child("bouquet", "arm_r", bq, ("idle", "walk", "talk", "idle_low", "lay_flowers")))
    lan_side = -1 if cfg["stick"] else 1
    kids.append(child("lantern_prop", "arm_r" if lan_side < 0 else "arm_l", lantern_child(hands[lan_side]), ("lantern_walk",)))
    if bent:
        walk = _walk(15.0, 0.025, 7.0, 0.008, 2.5, 2.0, 2.0, lambda t: {"arm_l": (-6.0, 0.0, 0.0)})
        idle = _idle(1.0, 0.5, 1.0, lambda t: {"head": (6.0, 0, 0)})
    else:
        walk = _walk(24.0, 0.045, 16.0, 0.016, 3.0, 4.0, 1.5)
        idle = _idle(1.2, 0.8, 0.8)
    talk_keys = [
        (0.0, {"arm_r": (-22.0, -4.0, 10.0), "head": (4.0, 0.0, 2.0)}),
        (0.3, {"arm_r": (-36.0, -8.0, 18.0), "head": (2.0, -3.0, -2.0), "spine": (1.0, 0.0, -2.0)}),
        (0.6, {"arm_r": (-26.0, -10.0, 12.0), "head": (6.0, 2.0, 3.0)}),
    ]
    actions = [("idle-loop", 84, idle), ("walk-loop", 26 if bent else 20, walk), ("talk-loop", 72, _talk(talk_keys, 1.0))]
    actions += p8_actions({"low", "mourn", "lantern"} | (set() if cfg["stick"] else {"lay"}), walk, lantern_side=lan_side,
                          mourn={"hands": (16.0, 27.0)})
    if cfg["stick"]:   # the stick stays planted: the left arm does not fold, it leans on the stick
        actions = [(n, fr, _keep_stick(fn) if n.startswith(("mourn", "idle_low", "lay")) else fn) for n, fr, fn in actions]
    export_figure(name, mesh, joints, actions, children=kids, markers=[face_marker(pts)])


def _keep_stick(fn):
    def g(t: float) -> dict:
        p = dict(fn(t))
        p["arm_l"] = (-2.0, 0.0, 0.0)
        return p
    return g


def mourner_m_a():
    _man("ph_chr_mourner_m_a", MEN["ph_chr_mourner_m_a"])


def mourner_m_b():
    _man("ph_chr_mourner_m_b", MEN["ph_chr_mourner_m_b"])


FIGURES = (mourner_w_a, mourner_w_b, mourner_m_a, mourner_m_b)


def build(names=None):
    """Build all mourners, or only those whose function name is in `names`."""
    for fn in FIGURES:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
