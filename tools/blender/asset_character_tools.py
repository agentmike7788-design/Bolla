"""G7 Runde 2 (Werkzeuge): the gravekeeper's belt tools - axe, pickaxe, hammer, saw (each its own
mesh on the "tool" bone, like the shovel) and the mason's chisel (its own mesh on "arm_l").
They live "in the tool bag" (hidden in Godot) until a work clip draws one: the right hand reaches
to the bag at the right hip, the tool appears in the fist (ToolAnimConfig.draw_show_at) and is
brought into the first pose of its work clip; stowing is the way back (hidden at stow_hide_at).
While a belt tool is out, Godot keeps the shovel on the back (PlayerAnimator re-parents it onto
the spine), so the tool bone is free for the tool in the hands.

Tool space (all tools): local Y along the handle from its butt (= the tool bone's head, s = 0),
local +Z = the striking side (axe edge, pick point, hammer face, saw teeth), modelled in the tool
bone's rest frame REST (the shovel's place on the back), so a tool on a posed bone B shows at B.

Work clips key the tool like the shovel clips (rig.add_action post hook _wield):
  "w_fist": (x, y, z)        - armature-space target of the right fist (the rigid arm points there)
  "w_dir":  (elev, az)       - handle direction butt -> head (asset_character._up convention)
  "w_axis": (x, y, z)        - swing-plane normal n: the striking side is n x dir (it leads the swing)
  "w_grip": (s_r, s_l, w_r, w_l) - where along the handle each fist holds it (m from the butt) and
                               how firmly (0 = the free arm pose, 1 = fist on the handle)
The tool follows the right fist where it actually arrives; the left fist slides along the handle
to the reachable point nearest s_l (two-handed tools), else keeps its keyed pose."""
import math

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Euler, Matrix, Vector

import lib_painted as L
import asset_character as C
import rig

REST = C._frame(C.SHOVEL_G0, C._D0, C.SHOVEL_NORMAL)   # the tool bone's rest frame
WOOD_DARK = L.hexc("#5A4230")
EDGE = L.hexc("#6A6C70")                                # worn bright edge on the dark iron

# tool -> (handle length, head centre along the handle, mesh name, marker at the striking point)
AXE_LEN, AXE_HEAD = 0.70, 0.655
PICK_LEN, PICK_HEAD = 0.76, 0.735
HAMMER_LEN, HAMMER_HEAD = 0.34, 0.315
SAW_GRIP, SAW_LEN = 0.1, 0.5
CHISEL_LEN = 0.2
MESHES = {"axe": "Axe", "pickaxe": "Pickaxe", "hammer": "Hammer", "saw": "Saw", "chisel": "Chisel"}
MARKERS = {"axe": ("axe_edge", (0.0, AXE_HEAD + 0.03, 0.15)),
           "pickaxe": ("pick_tip", (0.0, PICK_HEAD - 0.06, 0.25)),
           "hammer": ("hammer_face", (0.0, HAMMER_HEAD, 0.07)),
           "saw": ("saw_teeth", (0.0, 0.36, 0.08))}
# the chisel in the left fist: the fist holds it 0.07 m below its butt; rest direction (butt -> edge)
# chosen so it points steeply down onto the stone in the chisel clip (left arm ~ -55 deg forward)
CHISEL_HOLD = 0.07


def _local(obj, m: Matrix = None):
    obj.data.transform(REST if m is None else m)
    return obj


def _wedge(points, thick, name):
    """Profile (y, z) extruded symmetrically in X, half-thickness thick(z) (tapered to an edge)."""
    bm = bmesh.new()
    a = [bm.verts.new((thick(z), y, z)) for y, z in points]
    b = [bm.verts.new((-thick(z), y, z)) for y, z in points]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(points)
    for k in range(n):
        bm.faces.new((a[k], b[k], b[(k + 1) % n], a[(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return C._obj(bm, name)


def _handle(length, radius, seed):
    return C._painted(L.tube((0, 0, 0), (0, length, 0), radius, 5, r_end=radius * 0.9), C.WOOD, var=0.2,
                      ao=0.0, top=0.25, seed=seed, hue_shift=WOOD_DARK)


def build_axe():
    """Felling axe: 0.70 m haft, a bearded iron head, the edge (+Z) worn bright. 36 tris."""
    prof = [(0.615, -0.045), (0.695, -0.045), (0.69, 0.05), (0.735, 0.155), (0.565, 0.155), (0.62, 0.05)]
    head = _wedge(prof, lambda z: 0.016 - 0.013 * max(0.0, z - 0.03) / 0.125, "axe_head")
    C._painted(head, C.IRON, var=0.25, ao=0.0, top=0.3, seed=61)
    _edge_tint(head, 0.12)
    obj = L.join([_handle(AXE_LEN, 0.016, 60), head], MESHES["axe"])
    L.smooth(obj, 40)
    return _local(obj)


def build_pickaxe():
    """Pickaxe: 0.76 m haft, a curved iron bar - the point (+Z) and a flat chisel end (-Z). 40 tris."""
    bm = bmesh.new()
    y0 = PICK_HEAD

    def ring(z, half, dy):
        return [bm.verts.new((sx * half, y0 + dy + sy * half, z)) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    mid = ring(0.0, 0.024, 0.0)
    out = []
    for sz in (1, -1):
        r1 = ring(sz * 0.12, 0.016, -0.02)
        tip = bm.verts.new((0.0, y0 - 0.065, sz * 0.25))
        for k in range(4):
            q = (mid[k], mid[(k + 1) % 4], r1[(k + 1) % 4], r1[k])
            bm.faces.new(q if sz > 0 else tuple(reversed(q)))
            tri = (r1[k], r1[(k + 1) % 4], tip)
            bm.faces.new(tri if sz > 0 else tuple(reversed(tri)))
        out.append(r1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    head = C._obj(bm, "pick_head")
    C._painted(head, C.IRON, var=0.25, ao=0.0, top=0.3, seed=63)
    _edge_tint(head, 0.2, both=True)
    obj = L.join([_handle(PICK_LEN, 0.017, 62), head], MESHES["pickaxe"])
    L.smooth(obj, 40)
    return _local(obj)


def build_hammer():
    """Claw-less joiner's hammer: 0.34 m handle, an iron head with the face at +Z. 28 tris."""
    head = L.prim("cube", loc=(0, HAMMER_HEAD, 0.005), scale=(0.021, 0.024, 0.065))
    C._painted(head, C.IRON, var=0.25, ao=0.0, top=0.3, seed=65)
    _edge_tint(head, 0.05)
    obj = L.join([_handle(HAMMER_LEN, 0.013, 64), head], MESHES["hammer"])
    L.smooth(obj, 40)
    return _local(obj)


def build_saw():
    """Hand saw: a wooden grip (the fist, s = 0..0.11) and a tapered blade, teeth down (+Z). 24 tris."""
    grip = L.prim("cube", loc=(0, SAW_GRIP * 0.5, 0.02), scale=(0.014, SAW_GRIP * 0.5, 0.04))
    C._painted(grip, C.WOOD, var=0.2, ao=0.0, top=0.25, seed=66, hue_shift=WOOD_DARK)
    blade = L.prim("cube", loc=(0, (SAW_GRIP + SAW_LEN) * 0.5, 0.045), scale=(0.0025, (SAW_LEN - SAW_GRIP) * 0.5, 0.05))
    for v in blade.data.vertices:   # tapers towards the tip, the teeth edge (+Z) stays straight
        if v.co.y > 0.3 and v.co.z < 0.04:
            v.co.z += 0.045 * (v.co.y - SAW_GRIP) / (SAW_LEN - SAW_GRIP)
    C._painted(blade, C.IRON, var=0.2, ao=0.0, top=0.3, seed=67)
    _edge_tint(blade, 0.085)
    obj = L.join([grip, blade], MESHES["saw"])
    L.smooth(obj, 30)
    return _local(obj)


def chisel_rest_dir() -> Vector:
    """Rest direction (butt -> edge) of the chisel in the left fist (rigid wrist): steeply down onto
    the stone in the chisel clip's strike pose (spine CHISEL_SPINE, left arm CHISEL_ARM)."""
    want = Vector((0.15, -0.45, -0.88)).normalized()
    rs = Euler([math.radians(a) for a in CHISEL_SPINE], "XYZ").to_matrix()
    ra = Euler([math.radians(a) for a in CHISEL_ARM], "XYZ").to_matrix()
    return ((rs @ ra).inverted() @ want).normalized()


def build_chisel():
    """Mason's chisel in the left fist (on arm_l): 0.2 m four-sided iron bar. 12 tris."""
    d = chisel_rest_dir()
    f = C.FIST[1]
    obj = L.tube(f - d * CHISEL_HOLD, f + d * (CHISEL_LEN - CHISEL_HOLD), 0.011, 4, r_end=0.006)
    C._painted(obj, C.IRON, var=0.25, ao=0.0, top=0.3, seed=68, hue_shift=EDGE)
    obj.name = MESHES["chisel"]
    obj.data.name = MESHES["chisel"]
    return obj


def _edge_tint(obj, z_from: float, both: bool = False) -> None:
    """The striking side (local +Z beyond z_from; both: also -Z) worn bright."""
    def fn(co, n):
        if co.z > z_from or (both and co.z < -z_from):
            return (EDGE, 0.55)
        return None
    C._tint(obj, fn)


def build_tools() -> dict:
    """kind -> mesh object (axe, pickaxe, hammer, saw on the tool bone; chisel on arm_l)."""
    return {"axe": build_axe(), "pickaxe": build_pickaxe(), "hammer": build_hammer(), "saw": build_saw(),
            "chisel": build_chisel()}


def attach(arm, tools: dict) -> None:
    for kind, obj in tools.items():
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = "arm_l" if kind == "chisel" else C.TOOL
        bpy.context.view_layer.update()
        obj.matrix_world = Matrix.Identity(4)
    for kind, (name, p) in MARKERS.items():
        rig.bone_marker(arm, C.TOOL, name, REST @ Vector(p))


# --- the hold -------------------------------------------------------------------------

_DEBUG = None


def _dir(elev: float, az: float) -> Vector:
    return C._up(elev, az)


def _wield(pose_fn, name: str = ""):
    last = {}

    def post(arm, t):
        if t <= 0.0:
            last.clear()
        pose = pose_fn(t)
        if "w_fist" not in pose:
            return
        target = Vector(pose["w_fist"][:3])
        d = _dir(*pose["w_dir"][:2]).normalized()
        n = Vector(pose["w_axis"][:3])
        s_r, s_l, w_r, w_l = tuple(pose["w_grip"])[:4]
        if pose.get("w_chisel", (0.0,))[0] > 0.0:   # hammer face onto the chisel butt (+ offset)
            target = target + _chisel_butt(arm) - d * (HAMMER_HEAD - s_r) - n.cross(d).normalized() * 0.075
        if w_r > 0.001:
            C._aim_arm(arm, "arm_r", target, w_r)
        fist = C._fist(arm, "arm_r")
        face = n.cross(d)
        origin = fist - d * s_r
        m = C._frame(origin, d, face)
        arm.pose.bones[C.TOOL].matrix = m
        bpy.context.view_layer.update()
        miss_l = 0.0
        if w_l > 0.001:
            radius = (C.FIST[1] - arm.data.bones["arm_l"].head_local).length
            s, miss_l = C._shaft_point(origin, d, arm.pose.bones["arm_l"].head, radius, s_l, last.get("arm_l"))
            last["arm_l"] = s
            C._aim_arm(arm, "arm_l", origin + d * s, w_l)
        else:
            last.pop("arm_l", None)
        if _DEBUG is not None:
            _DEBUG.append((name, round(t, 3), round((fist - target).length, 3), round(miss_l, 3)))
    return post


def _chisel_butt(arm) -> Vector:
    pb = arm.pose.bones["arm_l"]
    m = pb.matrix @ arm.data.bones["arm_l"].matrix_local.inverted()
    return m @ (C.FIST[1] - chisel_rest_dir() * CHISEL_HOLD)


def _w(fist, elev, az, axis, grip, **more) -> dict:
    out = {"w_fist": tuple(fist), "w_dir": (elev, az), "w_axis": tuple(axis), "w_grip": tuple(grip)}
    out.update(more)
    return out


def _pose(body: dict, wield: dict, arms: dict = None) -> dict:
    return rig.add(C._stance(), body, arms or {}, wield)


# --- axe: chop ------------------------------------------------------------------------------
# Right-handed diagonal chop: wound up over the right shoulder (the right hand slid up the haft),
# the strike in front at ~0.6 m (trunk, thicket), the right hand sliding back down to the left.

CHOP_BITE = 0.42
AXE_AXIS = (0.55, -0.2, 0.62)


def _chop_keys() -> list:
    ax = AXE_AXIS
    wind = _pose(C._body(4.0, -25.0, head=-2.0), _w((-0.25, -0.5, 1.22), 50.0, 40.0, ax, (0.14, 0.03, 1.0, 1.0)),
                 {"arm_r": (-90.0, 0.0, 0.0), "arm_l": (-90.0, 0.0, -30.0)})
    over = _pose(C._body(8.0, -14.0, head=-4.0), _w((-0.3, -0.52, 1.3), 70.0, 125.0, ax, (0.13, 0.03, 1.0, 1.0)),
                 {"arm_r": (-100.0, 0.0, 0.0), "arm_l": (-100.0, 0.0, -20.0)})
    strike = _pose(C._body(16.0, 6.0), _w((-0.05, -0.62, 1.02), -32.0, 182.0, ax, (0.12, 0.03, 1.0, 1.0)),
                   {"arm_r": (-85.0, 0.0, 0.0), "arm_l": (-85.0, 0.0, 0.0), "hips": (3.0, 0, 0, 0, -0.01, -0.02)})
    follow = _pose(C._body(20.0, 9.0), _w((-0.02, -0.6, 0.92), -42.0, 186.0, ax, (0.12, 0.03, 1.0, 1.0)),
                   {"arm_r": (-75.0, 0.0, 0.0), "arm_l": (-75.0, 0.0, 0.0), "hips": (3.0, 0, 0, 0, -0.01, -0.02)})
    lift = _pose(C._body(8.0, -14.0), _w((-0.22, -0.55, 1.2), 30.0, 110.0, ax, (0.13, 0.03, 1.0, 1.0)),
                 {"arm_r": (-95.0, 0.0, 0.0), "arm_l": (-95.0, 0.0, -20.0)})
    return [(0.0, wind), (0.24, wind), (0.34, over), (CHOP_BITE, strike), (0.56, follow), (0.8, lift)]


def chop(t: float) -> dict:
    """33 frames = 1.1 s loop: wind-up over the right shoulder, the chop at CHOP_BITE, lift back."""
    keys = _chop_keys()
    return rig.keyed(t, keys)


# --- pickaxe: pick --------------------------------------------------------------------------

PICK_BITE = 0.45
PICK_AXIS = (0.8, -0.1, 0.35)


def _pick_keys() -> list:
    ax = PICK_AXIS
    wind = _pose(C._body(2.0, -22.0, head=-4.0), _w((-0.24, -0.5, 1.26), 64.0, 30.0, ax, (0.14, 0.03, 1.0, 1.0)),
                 {"arm_r": (-95.0, 0.0, 0.0), "arm_l": (-95.0, 0.0, -30.0)})
    over = _pose(C._body(8.0, -12.0, head=-4.0), _w((-0.3, -0.52, 1.32), 74.0, 130.0, ax, (0.13, 0.03, 1.0, 1.0)),
                 {"arm_r": (-100.0, 0.0, 0.0), "arm_l": (-100.0, 0.0, -20.0)})
    strike = _pose(C._body(30.0, 4.0), _w((-0.04, -0.56, 0.84), -58.0, 182.0, ax, (0.12, 0.03, 1.0, 1.0)),
                   {"arm_r": (-60.0, 0.0, 0.0), "arm_l": (-60.0, 0.0, 0.0), "hips": (4.0, 0, 0, 0, -0.02, -0.02)})
    pry = _pose(C._body(28.0, 4.0), _w((-0.03, -0.5, 0.9), -48.0, 182.0, ax, (0.12, 0.03, 1.0, 1.0)),
                {"arm_r": (-60.0, 0.0, 0.0), "arm_l": (-60.0, 0.0, 0.0), "hips": (4.0, 0, 0, 0, -0.02, -0.02)})
    lift = _pose(C._body(10.0, -14.0), _w((-0.22, -0.52, 1.2), 40.0, 100.0, ax, (0.13, 0.03, 1.0, 1.0)),
                 {"arm_r": (-95.0, 0.0, 0.0), "arm_l": (-95.0, 0.0, -20.0)})
    return [(0.0, wind), (0.26, wind), (0.36, over), (PICK_BITE, strike), (0.6, pry), (0.8, lift)]


def pick(t: float) -> dict:
    """36 frames = 1.2 s loop: the pick high over the right shoulder, the blow at PICK_BITE, a short
    pry, up again."""
    return rig.keyed(t, _pick_keys())


# --- hammer (stations, building, grave markers) -------------------------------------------

HAMMER_BITE = 0.5
HAMMER_AXIS = (1.0, 0.0, 0.0)
_LEFT_ON_WORK = {"arm_l": (-62.0, -6.0, 0.0)}


def _hammer_keys() -> list:
    ax = HAMMER_AXIS
    up = _pose(C._body(14.0, 4.0), _w((-0.16, -0.36, 1.18), 52.0, 182.0, ax, (0.06, 0.0, 1.0, 0.0)),
               dict(_LEFT_ON_WORK, arm_r=(-100.0, 0.0, 0.0)))
    hit = _pose(C._body(18.0, 4.0), _w((-0.12, -0.48, 0.9), -8.0, 184.0, ax, (0.06, 0.0, 1.0, 0.0)),
                dict(_LEFT_ON_WORK, arm_r=(-64.0, 0.0, 0.0)))
    rebound = _pose(C._body(17.0, 4.0), _w((-0.13, -0.46, 0.98), 12.0, 183.0, ax, (0.06, 0.0, 1.0, 0.0)),
                    dict(_LEFT_ON_WORK, arm_r=(-72.0, 0.0, 0.0)))
    return [(0.0, up), (0.3, up), (HAMMER_BITE, hit), (0.66, rebound)]


def hammer(t: float) -> dict:
    """18 frames = 0.6 s loop: the hammer up, one short blow at HAMMER_BITE (bench height ~0.8 m)."""
    return rig.keyed(t, _hammer_keys())


# --- chisel (mason's bench): hammer on the chisel in the left fist ------------------------

CHISEL_ARM = (-55.0, 0.0, -8.0)    # left arm forward and in towards the middle (the stone)
CHISEL_SPINE = (18.0, 0.0, 10.0)     # bent over the stone, turned a little to the left
CHISEL_BITE = 0.5
CHISEL_AXIS = (0.0, 1.0, 0.0)        # the hammer swings sideways (head to his left) down onto the butt


def _chisel_keys() -> list:
    ax = CHISEL_AXIS
    left = {"arm_l": CHISEL_ARM}
    on = (1.0,)
    sp, tw = CHISEL_SPINE[0], CHISEL_SPINE[2]
    up = _pose(C._body(sp - 2.0, tw), _w((-0.04, 0.0, 0.12), 42.0, 280.0, ax, (0.06, 0.0, 1.0, 0.0), w_chisel=on),
               dict(left, arm_r=(-90.0, 0.0, 0.0)))
    hit = _pose(C._body(sp, tw), _w((0.0, 0.0, 0.0), 0.0, 282.0, ax, (0.06, 0.0, 1.0, 0.0), w_chisel=on),
                dict(left, arm_r=(-70.0, 0.0, 0.0)))
    return [(0.0, up), (0.25, up), (CHISEL_BITE, hit), (0.62, rig.blend(up, hit, 0.6))]


def chisel(t: float) -> dict:
    """16 frames = 0.53 s loop: short taps of the hammer on the chisel butt (at CHISEL_BITE)."""
    return rig.keyed(t, _chisel_keys())


# --- saw (workbench) -----------------------------------------------------------------------

SAW_BITE = 0.08
SAW_AXIS = (1.0, 0.0, 0.0)


def _saw_keys() -> list:
    ax = SAW_AXIS
    back = _pose(C._body(16.0, 6.0, hips=(0, 0, 0, 0, 0.02, 0.0)),
                 _w((-0.17, -0.5, 1.16), -18.0, 182.0, ax, (0.05, 0.0, 1.0, 0.0)),
                 dict(_LEFT_ON_WORK, arm_r=(-60.0, 0.0, 0.0)))
    fwd = _pose(C._body(24.0, 4.0, hips=(2.0, 0, 0, 0, -0.03, -0.01)),
                _w((-0.14, -0.8, 1.0), -26.0, 182.0, ax, (0.05, 0.0, 1.0, 0.0)),
                dict(_LEFT_ON_WORK, arm_r=(-80.0, 0.0, 0.0)))
    return [(0.0, back), (0.5, fwd)]


def saw(t: float) -> dict:
    """32 frames = 1.07 s loop: one push-and-pull stroke (the push starts at SAW_BITE)."""
    return rig.keyed(t, _saw_keys())


# --- drawing from / putting back into the tool bag at the right hip ------------------------

def _bag(first: dict, kind: str) -> list:
    """Key poses rest -> bag -> lift -> first work pose (two-handed: the left hand joins last)."""
    two = first["w_grip"][3] > 0.5
    ax = first["w_axis"]
    s_r = 0.04 if kind != "saw" else 0.05
    # in the bag the haft points up and out past the right arm (pulled out by its end)
    rest = _pose({"leg_l": (9.0, 0.0, 0.0), "leg_r": (-9.0, 0.0, 0.0)},
                 _w((-0.36, 0.0, 0.7), BAG_DIR[0], BAG_DIR[1], (1.0, 0.0, 0.0), (s_r, first["w_grip"][1], 0.0, 0.0)))
    bag = _pose(C._body(6.0, -6.0), _w((-0.4, 0.05, 0.76), BAG_DIR[0], BAG_DIR[1], (1.0, 0.0, 0.0),
                                       (s_r, first["w_grip"][1], 1.0, 0.0)),
                {"arm_r": (10.0, 0.0, -10.0)})
    lift_fist = Vector(first["w_fist"][:3]).lerp(Vector((-0.34, -0.3, 1.0)), 0.6)
    lift = _pose(C._body(8.0, -4.0), _w(tuple(lift_fist), 30.0, 170.0, ax,
                                        (first["w_grip"][0] * 0.6 + s_r * 0.4, first["w_grip"][1], 1.0, 0.0)),
                 {"arm_l": (-30.0, 0.0, 0.0) if two else first.get("arm_l", rig.ZERO)})
    return [rest, bag, lift, first]


def _first(keys_fn) -> dict:
    return dict(keys_fn()[0][1])


def make_draw(keys_fn, kind):
    def draw(t: float) -> dict:
        rest, bag, lift, first = _bag(_first(keys_fn), kind)
        return rig.keyed(t, [(0.0, rest), (DRAW_BAG, bag), (0.66, lift), (1.0, first)], wrap=False)
    return draw


def make_stow(keys_fn, kind):
    def stow(t: float) -> dict:
        rest, bag, lift, first = _bag(_first(keys_fn), kind)
        return rig.keyed(t, [(0.0, first), (0.34, lift), (STOW_BAG, bag), (1.0, rest)], wrap=False)
    return stow


def make_stow_walk(stow_fn):
    """One walk cycle: the stow over walking legs, the arms settling into the walk swing at the end."""
    def stow_walk(t: float) -> dict:
        g = C.walk(t)
        upper = stow_fn(min(1.0, t / 0.85))
        out = dict(g)
        fade = rig.ease((t - 0.7) / 0.3)
        for bone in ("arm_l", "arm_r", "spine", "head"):
            a = tuple(upper.get(bone, rig.ZERO)) + rig.ZERO[len(upper.get(bone, rig.ZERO)):]
            b = tuple(g.get(bone, rig.ZERO)) + rig.ZERO[len(g.get(bone, rig.ZERO)):]
            out[bone] = tuple(x + (y - x) * fade for x, y in zip(a, b))
        for k in ("w_fist", "w_dir", "w_axis"):
            out[k] = upper[k]
        out["w_grip"] = tuple(v * (1.0 - fade) if i in (2, 3) else v for i, v in enumerate(upper["w_grip"]))
        return out
    return stow_walk


BAG_DIR = (50.0, 115.0)   # (elev, az) of the haft at the bag
DRAW_BAG = 0.36    # the fist at the bag: the tool appears (ToolAnimConfig.draw_show_at)
STOW_BAG = 0.7     # back at the bag: the tool disappears (ToolAnimConfig.stow_hide_at)

# tool kind -> (work clip(s) with frames, the clip the draw ends in / the stow starts from)
_WORK = {
    "axe": [("chop-loop", 33, chop, _chop_keys)],
    "pickaxe": [("pick-loop", 36, pick, _pick_keys)],
    "hammer": [("hammer-loop", 18, hammer, _hammer_keys), ("chisel-loop", 16, chisel, _chisel_keys)],
    "saw": [("saw-loop", 32, saw, _saw_keys)],
}
_PREFIX = {"axe": "axe", "pickaxe": "pick", "hammer": "hammer", "saw": "saw"}


def actions() -> list:
    """(name, frames, pose fn, post hook) of every tool clip (rig.add_action)."""
    out = []
    for kind, clips in _WORK.items():
        for name, frames, fn, _keys in clips:
            out.append((name, frames, fn, _wield(fn, name)))
        keys_fn = clips[0][3]
        p = _PREFIX[kind]
        draw = make_draw(keys_fn, kind)
        stow = make_stow(keys_fn, kind)
        out.append((p + "_draw", 12, draw, _wield(draw, p + "_draw")))
        out.append((p + "_stow", 11, stow, _wield(stow, p + "_stow")))
        sw = make_stow_walk(stow)
        out.append((p + "_stow_walk", 16, sw, _wield(sw, p + "_stow_walk")))
    return out
