"""Shared humanoid rig for the player and human NPCs (docs/VERTICAL_SLICE_DESIGN.md §8).

Armature object "Armature" with 8 bones:
    root > hips > spine > head, arm_l, arm_r        hips > leg_l, leg_r
(_l = the character's left = +X; the model faces -Y in Blender = +Z in Godot).

Rigid skinning: every vertex belongs 100 % to exactly one bone (one vertex group
per body part, see weight() / weight_split_z()). Parts are joined into one mesh
that is parented to the armature with an Armature modifier.

Actions are keyframed procedurally at 30 fps from pose functions pose(t), t in
[0, 1]. A pose maps bone -> (rx, ry, rz, lx, ly, lz): a rotation in degrees about
the ARMATURE axes (X = right->left, Y = front->back, Z = up; pivot = bone head)
and an offset in metres along the armature axes, both relative to the rest pose.
Handy signs: +rx leans an upward bone (spine, head) forward; -rx swings a
hanging bone (arm, leg) forward.
The optional pose key "feet" = {"leg_l": h, "leg_r": h} asks for ground contact:
each leg is slid along its own axis (hidden inside coat/trousers, reads as a knee
bend) until its lowest vertex sits h metres above its rest height (h = 0: planted).
Action names ending in "-loop" are looped by the Godot importer, which strips the
suffix (idle-loop -> "idle"); loop pose functions must satisfy pose(0) == pose(1).
Root motion is off: the root bone never moves (movement comes from code).
Additive extra bones (G7 Runde 2, the gravekeeper's shovel): build_armature(joints, extra=...)
adds non-deforming bones such as "tool" (child of "spine") that carry a bone-parented prop.
Figures without extras are built exactly as before. An action's optional post(arm, t) hook
runs after the pose (and the feet) are applied and may set pose matrices directly (e.g. the
tool bone and hands aimed onto a held shaft) before every bone is keyframed.
"""
import math

import bpy
from mathutils import Euler, Matrix, Vector

BONES = ("root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r")
PARENTS = {"root": None, "hips": "root", "spine": "hips", "head": "spine",
           "arm_l": "spine", "arm_r": "spine", "leg_l": "hips", "leg_r": "hips"}
LEGS = ("leg_l", "leg_r")
MESH = "Body"   # skinned mesh node: <glb>/Armature/Skeleton3D/Body
FPS = 30
TAU = 2.0 * math.pi
ZERO = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)


# --- skinning -------------------------------------------------------------

def weight(bone: str, obj):
    """Assign every vertex of one body part 100 % to `bone`. Returns obj."""
    assert bone in BONES, bone
    vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def weight_split_z(obj, z: float, below: str, above: str):
    """Rigid split of one part at height z (e.g. a coat: skirt on hips, top on
    spine). Still 100 % per vertex – the seam hides under a belt. Returns obj."""
    lo = obj.vertex_groups.new(name=below)
    hi = obj.vertex_groups.new(name=above)
    lo.add([v.index for v in obj.data.vertices if v.co.z < z], 1.0, "REPLACE")
    hi.add([v.index for v in obj.data.vertices if v.co.z >= z], 1.0, "REPLACE")
    return obj


def check_rigid(mesh) -> None:
    """Every vertex: exactly one bone group with weight 1.0."""
    names = {g.index: g.name for g in mesh.vertex_groups}
    for v in mesh.data.vertices:
        gs = [g for g in v.groups if g.weight > 0.0]
        if len(gs) != 1 or abs(gs[0].weight - 1.0) > 1e-6 or names[gs[0].group] not in BONES:
            raise ValueError(f"{mesh.name}: vertex {v.index} is not rigidly skinned ({len(gs)} groups)")


def ground(mesh) -> float:
    """Pivot between the feet: shift the mesh so its lowest vertex is at z = 0.
    Returns the applied shift (subtract it from positions modelled before)."""
    zmin = min(v.co.z for v in mesh.data.vertices)
    for v in mesh.data.vertices:
        v.co.z -= zmin
    return zmin


# --- armature -------------------------------------------------------------

def build_armature(joints: dict, extra: dict = None):
    """joints: bone -> (head, tail) in model space. Returns the armature object.
    extra (optional): bone -> (parent, z_axis or None) for additional non-deforming bones (their
    head/tail also in joints); z_axis aligns the bone roll (Z axis) to that vector."""
    extra = extra or {}
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1.0
    data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name in BONES:
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = Vector(joints[name][0]), Vector(joints[name][1])
        eb.roll = 0.0
        eb.use_deform = True
    for name in BONES:
        if PARENTS[name]:
            data.edit_bones[name].parent = data.edit_bones[PARENTS[name]]
            data.edit_bones[name].use_connect = False
    for name in sorted(extra):
        parent, z_axis = extra[name]
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = Vector(joints[name][0]), Vector(joints[name][1])
        eb.roll = 0.0
        if z_axis is not None:
            eb.align_roll(Vector(z_axis))
        eb.use_deform = False
        eb.parent = data.edit_bones[parent]
        eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def bind(mesh, arm) -> None:
    """Parent the (rigidly weighted) mesh to the armature + Armature modifier."""
    check_rigid(mesh)
    mesh.parent = arm
    mesh.matrix_parent_inverse = Matrix.Identity(4)
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True


def bone_marker(arm, bone: str, name: str, loc) -> None:
    """Empty that follows `bone` (glTF node below the joint -> Godot BoneAttachment3D)."""
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(Vector(loc))


# --- pose helpers ---------------------------------------------------------

def add(*poses) -> dict:
    """Component-wise sum of poses (small-angle layering, e.g. gait + breathing).
    "feet" targets are not summed: the last pose that has them wins."""
    out = {}
    for p in poses:
        for bone, v in p.items():
            if bone == "feet":
                out["feet"] = dict(v)
                continue
            base = out.get(bone, ZERO)
            out[bone] = tuple(a + b for a, b in zip(base, tuple(v) + ZERO[len(v):]))
    return out


def ease(x: float) -> float:
    """Smooth 0..1 step (cosine)."""
    return 0.5 - 0.5 * math.cos(math.pi * min(1.0, max(0.0, x)))


def keyed(t: float, keys: list, wrap: bool = True) -> dict:
    """Interpolate key poses [(time, pose), ...] (times ascending in [0, 1]) with
    ease in/out. wrap=True closes the loop from the last key back to the first."""
    keys = list(keys)
    if wrap:
        keys.append((keys[0][0] + 1.0, keys[0][1]))
        if t < keys[0][0]:
            t += 1.0
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t <= t1:
            w = ease((t - t0) / max(1e-6, t1 - t0))
            return blend(p0, p1, w)
    return dict(keys[-1][1])


def blend(a: dict, b: dict, w: float) -> dict:
    out = {}
    for bone in set(a) | set(b):
        if bone == "feet":
            fa, fb = a.get("feet", {}), b.get("feet", {})
            out["feet"] = {k: fa.get(k, 0.0) + (fb.get(k, 0.0) - fa.get(k, 0.0)) * w for k in set(fa) | set(fb)}
            continue
        va = tuple(a.get(bone, ZERO)) + ZERO[len(a.get(bone, ZERO)):]
        vb = tuple(b.get(bone, ZERO)) + ZERO[len(b.get(bone, ZERO)):]
        out[bone] = tuple(x + (y - x) * w for x, y in zip(va, vb))
    return out


def gait(t: float, leg: float, lift: float, arm: float, bob: float = 0.015, roll: float = 3.0,
         yaw: float = 5.0, lean: float = 0.0) -> dict:
    """One walk cycle (t in [0, 1]): left leg forward at t = 0.25, right at 0.75.
    leg/arm: swing amplitude in degrees (arms counter-swing), lift: swing-foot
    clearance in m, bob: hips rise when a leg passes under the body, roll/yaw:
    hip waddle and twist (shoulders counter-twist), lean: extra forward hunch."""
    s, c, c2 = math.sin(TAU * t), math.cos(TAU * t), math.cos(2.0 * TAU * t)
    return {
        "hips": (0.0, -roll * c, -yaw * s, 0.0, 0.0, bob * c2),
        "spine": (lean + 1.2 * c2, roll * 0.7 * c, yaw * 2.0 * s),
        "head": (-lean * 0.6 - 1.0 * c2, 0.0, -yaw * 0.8 * s),
        "arm_l": (arm * s, 0.0, 0.0),
        "arm_r": (-arm * s, 0.0, 0.0),
        "leg_l": (-leg * s, 0.0, 0.0),
        "leg_r": (leg * s, 0.0, 0.0),
        "feet": {"leg_l": lift * max(0.0, c) ** 2, "leg_r": lift * max(0.0, -c) ** 2},
    }


def breathe(t: float, amount: float = 1.0, cycles: int = 1) -> dict:
    """Subtle idle breathing: chest rises, shoulders and head follow."""
    s = math.sin(TAU * t * cycles)
    return {
        "hips": (0.0, 0.0, 0.0, 0.0, 0.0, 0.003 * amount * s),
        "spine": (-1.2 * amount * s, 0.0, 0.0, 0.0, 0.0, 0.0),
        "head": (0.8 * amount * s, 0.0, 0.0),
        "arm_l": (0.8 * amount * s, 1.0 * amount * s, 0.0),
        "arm_r": (0.8 * amount * s, -1.0 * amount * s, 0.0),
        "feet": {"leg_l": 0.0, "leg_r": 0.0},
    }


# --- actions --------------------------------------------------------------

def _foot_verts(arm, mesh) -> dict:
    """Per leg: (rest positions of its lowest vertices, rest height of the lowest one)."""
    out = {}
    for leg in LEGS:
        gi = mesh.vertex_groups[leg].index
        vs = [v.co.copy() for v in mesh.data.vertices if any(g.group == gi for g in v.groups)]
        zmin = min(v.z for v in vs)
        out[leg] = ([v for v in vs if v.z < zmin + 0.25], zmin)
    return out


def _lowest(arm, leg: str, verts) -> float:
    m = arm.pose.bones[leg].matrix @ arm.data.bones[leg].matrix_local.inverted()
    return min((m @ v).z for v in verts)


def _apply(arm, rest: dict, bone: str, v) -> None:
    v = tuple(v) + ZERO[len(v):]
    pb = arm.pose.bones[bone]
    b = rest[bone]
    rot = Euler([math.radians(a) for a in v[:3]], "XYZ").to_matrix()
    pb.rotation_quaternion = (b.inverted() @ rot @ b).to_quaternion()
    pb.location = b.inverted() @ Vector(v[3:])


def reset_pose(arm) -> None:
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()


def bone_names(arm) -> list:
    """BONES followed by the armature's extra bones (sorted)."""
    return list(BONES) + sorted(b.name for b in arm.data.bones if b.name not in BONES)


def add_action(arm, mesh, name: str, frames: int, pose_fn, post=None):
    """Keyframe every bone (rotation + location) on every frame 0..frames.
    post(arm, t) (optional) runs after the pose and the feet are applied, before the keys."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    rest = {b.name: b.matrix_local.to_3x3() for b in arm.data.bones}
    feet = _foot_verts(arm, mesh)
    names = bone_names(arm)
    for f in range(frames + 1):
        pose = pose_fn(f / frames)
        for bone in names:
            _apply(arm, rest, bone, pose.get(bone, ZERO))
        targets = pose.get("feet")
        if targets:
            for _ in range(3):  # hips roll tilts the leg axis slightly -> refine
                bpy.context.view_layer.update()
                for leg in LEGS:
                    pb = arm.pose.bones[leg]
                    verts, rest_z = feet[leg]
                    err = rest_z + targets.get(leg, 0.0) - _lowest(arm, leg, verts)
                    # pose location lives in the bone's rest frame: local +Y = rest axis towards the foot
                    down = rest[leg] @ Vector((0.0, 1.0, 0.0))
                    pb.location = pb.location + Vector((0.0, err / min(-0.2, down.z), 0.0))
        if post is not None:
            bpy.context.view_layer.update()
            post(arm, f / frames)
        for bone in names:
            pb = arm.pose.bones[bone]
            pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
            pb.keyframe_insert("location", frame=f, group=bone)
    act.use_frame_range = True
    act.frame_start = 0
    act.frame_end = frames
    act.use_cyclic = name.endswith("-loop")
    ad.action = None
    reset_pose(arm)
    return act


# --- Phase 8 pose helpers (additive; docs/PHASE8_DESIGN.md §8.2) -------------------------------------
# Visits, mourning, the festivals. Rigid arms without elbows, legs without knees: every pose reads with
# whole arm and leg parts. Kneeling = the hips sink, the legs swing back and slide into the skirt or
# coat (feet rule), the upper body leans forward; "folded hands" = both arms slanted forward-inward so
# the hands meet in front of the belly; nothing is brought to the chest or the face.

def folded(fwd: float = 26.0, inward: float = 24.0) -> dict:
    """Both arms slanted forward and inward, the hands meet in front of the belly."""
    return {"arm_l": (-fwd, inward, 0.0), "arm_r": (-fwd, -inward, 0.0)}


def bowed(head: float = 14.0, shoulders: float = 4.0) -> dict:
    """Head lowered (+rx leans it forward), shoulders a little forward."""
    return {"spine": (shoulders, 0.0, 0.0), "head": (head, 0.0, 0.0),
            "arm_l": (-shoulders * 1.2, 2.0, 0.0), "arm_r": (-shoulders * 1.2, -2.0, 0.0)}


def kneel(drop: float = 0.4, legs: float = 12.0, lean: float = 14.0, head: float = 18.0, back: float = 0.03,
          hands: tuple = (30.0, 22.0)) -> dict:
    """Kneeling on the ground: the hips sink by `drop` (and slide `back` m backwards), both legs swing
    back by `legs` degrees and are pushed up into the skirt until the feet touch the ground (hidden under it), the upper
    body leans forward, the head is bowed, the hands are folded."""
    p = add({"hips": (0.0, 0.0, 0.0, 0.0, back, -drop), "spine": (lean, 0.0, 0.0), "head": (head, 0.0, 0.0),
             "leg_l": (legs, 0.0, -3.0), "leg_r": (legs, 0.0, 3.0)}, folded(*hands))
    p["feet"] = {"leg_l": 0.0, "leg_r": 0.0}
    return p


def weight_shift(t: float, amount: float = 1.0, cycles: int = 1) -> dict:
    """Slow shift of the weight from one leg to the other (standing still a long while)."""
    s = math.sin(TAU * t * cycles)
    return {"hips": (0.0, 1.6 * amount * s, 0.0, 0.006 * amount * s, 0.0, 0.0),
            "spine": (0.0, -1.4 * amount * s, 0.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}


def step_in_place(t: float, lift: float = 0.035, sway: float = 3.0, beats: int = 2) -> dict:
    """Swaying from foot to foot on the spot (the dance): the weight goes over, the free foot lifts."""
    s = math.sin(TAU * t * beats)
    return {"hips": (0.0, sway * s, 0.0, 0.012 * s, 0.0, 0.008 * abs(s)), "spine": (0.0, -sway * 0.8 * s, 0.0),
            "head": (0.0, -sway * 0.4 * s, 0.0),
            "feet": {"leg_l": lift * max(0.0, -s) ** 1.5, "leg_r": lift * max(0.0, s) ** 1.5}}


def once(keys: list):
    """One-shot pose function from key poses (ends exactly at the last key; wrap off)."""
    def fn(t: float) -> dict:
        return keyed(t, keys, wrap=False)
    return fn
