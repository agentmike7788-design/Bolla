"""Osric Faulhaber, the corpse carter (NPC). Same painted style and palette as
the gravekeeper, but the opposite silhouette: short (~1.65 m), stout and broad,
upright. Flat cap, leather apron over a muted linen shirt with rolled sleeves,
dark trousers, big boots, bushy grey-brown beard, a pipe.
Front faces -Y (Blender) = +Z (Godot). Shared rig (rig.py); actions
idle-loop, walk-loop, push_cart-loop, talk-loop."""
import math

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Vector

import lib_painted as L
import rig

NAME = "ph_chr_carter"

SHIRT = L.hexc("#968D78")
SHIRT_DARK = L.hexc("#79725F")
APRON = L.hexc("#5C4332")
APRON_DARK = L.hexc("#3E2E24")
TROUSER = L.hexc("#38332E")
BOOT = L.hexc("#2B231E")
SKIN = L.hexc("#C79A7C")
NOSE = L.hexc("#B97F68")
BEARD = L.hexc("#7B6B5A")
BEARD_GREY = L.hexc("#958D80")
CAP = L.hexc("#4D4840")
CAP_DARK = L.hexc("#3A3530")
PIPE = L.hexc("#3B2B21")
STRAP = L.hexc("#2A2420")
EYE = L.hexc("#1B1715")

WAIST_Z = 0.86   # shirt and apron below -> hips, above -> spine (under the apron tie)
HEAD_C = Vector((0.0, -0.035, 1.435))
W = rig.weight

# torso profile: (height, x radius, y radius, forward belly offset)
TORSO = ((0.60, 0.24, 0.20, -0.01), (0.78, 0.30, 0.25, -0.045), (0.96, 0.315, 0.265, -0.045),
         (1.14, 0.30, 0.25, 0.0), (1.30, 0.20, 0.17, 0.01))


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _thicken(obj, thickness: float) -> None:
    """Give a sheet (the apron) a closed back side and rim."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
    bm.to_mesh(obj.data)
    bm.free()


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


def _profile(z: float) -> tuple:
    """Torso radii/offset at height z (linear between the TORSO rings)."""
    if z <= TORSO[0][0]:
        return TORSO[0][1:]
    for (z0, *a), (z1, *b) in zip(TORSO, TORSO[1:]):
        if z <= z1:
            w = (z - z0) / (z1 - z0)
            return tuple(x + (y - x) * w for x, y in zip(a, b))
    return TORSO[-1][1:]


def _front_y(x: float, z: float) -> float:
    """y of the torso's front surface at (x, z)."""
    rx, ry, off = _profile(z)
    k = min(0.98, abs(x) / rx)
    return off - ry * math.sqrt(1.0 - k * k)


def build_mesh():
    """Returns the rigidly weighted carter mesh in model space."""
    L.reset(81)
    parts = []
    # big boots and sturdy legs in dark trousers
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        parts.append(W(leg, L.part("sphere", BOOT, loc=(sx * 0.13, -0.06, 0.085), scale=(0.105, 0.19, 0.09),
                                   segments=10, ring_count=6, jit=0.01, seed=21 + sx)))
        parts.append(W(leg, L.part("torus", STRAP, loc=(sx * 0.13, -0.02, 0.15), major_radius=0.075,
                                   minor_radius=0.02, major_segments=10, minor_segments=4, scale=(1, 1.1, 1))))
        parts.append(W(leg, _painted(L.tube((sx * 0.125, 0, 0.13), (sx * 0.12, 0.0, 0.72), 0.07, 8, r_end=0.088),
                                     TROUSER, var=0.14, ao=0.25, seed=23)))
    # seat of the trousers
    parts.append(W("hips", L.part("sphere", TROUSER, loc=(0, 0.02, 0.68), scale=(0.25, 0.2, 0.13), segments=12,
                                  ring_count=6, jit=0.01, seed=24)))
    # barrel torso in a linen shirt: round belly, broad shoulders
    torso = L.prim("cyl", loc=(0, 0, 0.95), radius=1.0, depth=0.7, vertices=16)
    L.subdivide(torso, 5)
    for v in torso.data.vertices:
        rx, ry, off = _profile(v.co.z)
        v.co.x *= rx
        v.co.y = v.co.y * ry + off
    L.jitter(torso, 0.012, 3.0, 25)
    parts.append(rig.weight_split_z(_painted(torso, SHIRT, var=0.14, ao=0.3, top=0.12, zrange=(0.6, 1.3), seed=26,
                                             hue_shift=SHIRT_DARK), WAIST_Z, "hips", "spine"))
    parts.append(W("spine", L.part("sphere", SHIRT, loc=(0, 0.02, 1.2), scale=(0.25, 0.21, 0.14), segments=14,
                                   ring_count=8, jit=0.008, seed=45, paint_kw={"ao": 0.2})))  # rounded upper back
    for sx in (-1, 1):  # shoulders
        parts.append(W("spine", L.part("sphere", SHIRT, loc=(sx * 0.26, 0.0, 1.22), radius=0.11, segments=10,
                                       ring_count=6, scale=(1.0, 0.95, 0.85), jit=0.008, seed=27)))
    # leather apron: bib + skirt following the belly, hangs to the knees
    apron = L.prim("grid", loc=(0, 0, 0), x_subdivisions=6, y_subdivisions=10, size=1.0)
    for v in apron.data.vertices:
        u, w = v.co.x + 0.5, v.co.y + 0.5          # u: 0..1 across, w: 0..1 bottom -> top
        z = 0.44 + w * (1.2 - 0.44)
        half = 0.28 - 0.11 * max(0.0, (z - 0.95) / 0.25)  # the bib is narrower than the skirt
        x = (u - 0.5) * 2.0 * half
        zs = max(z, 0.7)                           # below the belly the leather hangs straight down
        y = _front_y(x, zs) - 0.018 - (0.02 * (0.7 - z) / 0.26 if z < 0.7 else 0.0)
        v.co = Vector((x, y, z))
    L.jitter(apron, 0.006, 4.0, 28)
    _thicken(apron, 0.014)
    L.paint(apron, APRON, var=0.2, ao=0.25, top=0.15, hue_shift=APRON_DARK, seed=29)
    L.set_mat(apron, L.MAT_PAINTED)
    parts.append(rig.weight_split_z(apron, WAIST_Z, "hips", "spine"))
    # apron tie at the waist and neck straps
    parts.append(W("hips", L.part("torus", STRAP, loc=(0, -0.045, WAIST_Z), major_radius=1.0, minor_radius=0.022,
                                  major_segments=16, minor_segments=4, scale=(0.325, 0.29, 1.0))))
    for sx in (-1, 1):
        bib = Vector((sx * 0.15, _front_y(sx * 0.15, 1.19) - 0.022, 1.19))
        over = Vector((sx * 0.13, -0.178, 1.275))
        for a, b in ((bib, over), (over, Vector((sx * 0.1, -0.05, 1.345)))):  # over the shoulders
            parts.append(W("spine", _painted(L.tube(a, b, 0.014, 5), APRON_DARK, seed=30)))
    # arms: linen upper arm, rolled sleeve, bare forearm, big hands
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        sh = Vector((sx * 0.3, 0.0, 1.22))
        elbow = Vector((sx * 0.37, -0.02, 1.0))
        wrist = Vector((sx * 0.39, -0.07, 0.8))
        parts.append(W(bone, _painted(L.tube(sh, elbow, 0.078, 8, r_end=0.07), SHIRT, var=0.14, ao=0.15, seed=31)))
        parts.append(W(bone, L.part("torus", SHIRT_DARK, loc=elbow, major_radius=0.07, minor_radius=0.03,
                                    major_segments=10, minor_segments=5, rot=(-10, sx * -5, 0), jit=0.006,
                                    seed=32)))
        parts.append(W(bone, _painted(L.tube(elbow, wrist, 0.058, 8, r_end=0.05), SKIN, var=0.08, ao=0.15, seed=33)))
        parts.append(W(bone, L.part("sphere", SKIN, loc=wrist - Vector((0, 0.01, 0.06)), radius=0.064, segments=10,
                                    ring_count=6, scale=(0.85, 1, 1.1), paint_kw={"ao": 0.2})))
    # head: round, ruddy bulb nose, bushy brows, big grey-brown beard
    parts.append(W("head", L.part("sphere", SKIN, loc=HEAD_C, radius=0.15, segments=14, ring_count=10,
                                  scale=(1.05, 1.0, 0.98), paint_kw={"ao": 0.15, "var": 0.06})))
    parts.append(W("head", L.part("sphere", NOSE, loc=HEAD_C + Vector((0, -0.15, -0.005)), radius=0.045, segments=10,
                                  ring_count=6, scale=(1.0, 0.9, 0.9))))
    for sx in (-1, 1):
        parts.append(W("head", L.part("sphere", EYE, loc=HEAD_C + Vector((sx * 0.058, -0.128, 0.035)),
                                      radius=0.018, segments=6, ring_count=4)))
        parts.append(W("head", L.part("sphere", BEARD, loc=HEAD_C + Vector((sx * 0.062, -0.128, 0.068)), radius=0.04,
                                      segments=8, ring_count=4, scale=(1.1, 0.5, 0.45), jit=0.006, seed=34 + sx)))
        parts.append(W("head", L.part("sphere", BEARD, loc=HEAD_C + Vector((sx * 0.105, -0.06, -0.05)), radius=0.075,
                                      segments=10, ring_count=6, scale=(0.8, 0.9, 1.1), jit=0.014, seed=36 + sx,
                                      paint_kw={"hue_shift": BEARD_GREY, "var": 0.2})))
    parts.append(W("head", L.part("sphere", BEARD, loc=HEAD_C + Vector((0, -0.1, -0.115)), radius=0.14, segments=12,
                                  ring_count=8, scale=(0.95, 0.62, 0.85), jit=0.02, seed=38,
                                  paint_kw={"hue_shift": BEARD_GREY, "var": 0.22})))
    parts.append(W("head", L.part("sphere", BEARD, loc=HEAD_C + Vector((0, -0.158, -0.05)), radius=0.05, segments=10,
                                  ring_count=6, scale=(1.7, 0.6, 0.6), jit=0.006, seed=39)))  # moustache
    # flat cap: soft crown pulled forward, short peak
    crown = L.prim("cyl", loc=HEAD_C + Vector((0, -0.015, 0.13)), radius=0.172, depth=0.075, vertices=16)
    L.subdivide(crown, 1)
    L.taper(crown, HEAD_C.z + 0.095, HEAD_C.z + 0.17, 1.08)
    for v in crown.data.vertices:  # sloping to the front, rounded top edge
        rel = v.co.y - HEAD_C.y
        v.co.z -= 0.05 * max(0.0, -rel) / 0.17 * (1.0 if v.co.z > HEAD_C.z + 0.12 else 0.4)
    L.jitter(crown, 0.01, 3.0, 40)
    peak = L.prim("cyl", loc=HEAD_C + Vector((0, -0.15, 0.095)), radius=0.14, depth=0.02, vertices=14,
                  scale=(1.0, 0.55, 1.0), rot=(-10, 0, 0))
    L.jitter(peak, 0.006, 4.0, 41)
    band = L.prim("cyl", loc=HEAD_C + Vector((0, -0.01, 0.1)), radius=0.162, depth=0.03, vertices=16)
    for o, c in ((crown, CAP), (peak, CAP_DARK), (band, CAP_DARK)):
        parts.append(W("head", _painted(o, c, var=0.18, ao=0.1, top=0.22, seed=42)))
    parts.append(W("head", L.part("sphere", CAP_DARK, loc=HEAD_C + Vector((0, 0.0, 0.2)), radius=0.022, segments=6,
                                  ring_count=4)))
    # pipe in the right corner of the mouth, bowl hanging out of the beard
    stem0 = HEAD_C + Vector((-0.045, -0.16, -0.075))
    bowl = HEAD_C + Vector((-0.1, -0.27, -0.1))
    parts.append(W("head", _painted(L.tube(stem0, bowl + Vector((0, 0, -0.01)), 0.009, 6), PIPE, seed=43)))
    parts.append(W("head", L.part("cyl", PIPE, loc=bowl + Vector((0, 0, 0.012)), radius=0.024, depth=0.055,
                                  vertices=8, jit=0.002, seed=44)))
    mesh = L.join(parts, rig.MESH)
    L.smooth(mesh, 55)
    return mesh


def joints(dz: float) -> dict:
    """Bone head/tail from the carter's proportions (dz = grounding shift)."""
    def p(x, y, z):
        return (x, y, z - dz)
    j = {
        "root": (p(0, 0, dz), p(0, 0, dz + 0.3)),
        "hips": (p(0, 0.0, 0.66), p(0, 0.0, 0.86)),
        "spine": (p(0, 0.0, 0.86), p(0, -0.02, 1.33)),
        "head": (p(0, -0.03, 1.32), p(0, -0.03, 1.62)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (p(sx * 0.3, 0.0, 1.22), p(sx * 0.39, -0.07, 0.8))
        j[_side(sx, "leg")] = (p(sx * 0.12, 0, 0.68), p(sx * 0.125, 0, 0.1))
    return j


# --- actions (pose functions, see rig.py for the conventions) ---------------------

def idle(t: float) -> dict:
    """2.4 s: deep belly breathing, a slow weight shift, a puff on the pipe."""
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 1.5), {
        "hips": (0.0, 1.5 * s, 0.0, 0.004 * s, 0.0, 0.0),
        "spine": (0.0, -1.5 * s, 0.0),
        "head": (1.5 * math.sin(rig.TAU * t * 2.0), 0.0, 3.0 * s),
    })


def walk(t: float) -> dict:
    """18 frames = 0.6 s per cycle: sturdy, rolling, arms swinging wide."""
    g = rig.gait(t, leg=26.0, lift=0.05, arm=18.0, bob=0.015, roll=4.5, yaw=4.0, lean=2.0)
    return rig.add(g, {"arm_l": (0.0, -6.0, 0.0), "arm_r": (0.0, 6.0, 0.0)})


def push_cart(t: float) -> dict:
    """22 frames: leaning into the cart, both hands forward-low on the handles."""
    c2 = math.cos(2.0 * rig.TAU * t)
    g = rig.gait(t, leg=22.0, lift=0.04, arm=0.0, bob=0.012, roll=2.5, yaw=2.0, lean=0.0)
    return rig.add(g, {
        "hips": (6.0, 0.0, 0.0),
        "spine": (12.0, 0.0, 0.0),
        "head": (-14.0, 0.0, 0.0),
        "arm_l": (-46.0 + 2.0 * c2, 8.0, 0.0),   # hands drawn in onto the handles (~0.65 m apart)
        "arm_r": (-46.0 + 2.0 * c2, -8.0, 0.0),
    })


def talk(t: float) -> dict:
    """72 frames = 2.4 s: explains with the right hand, left thumb in the apron."""
    rest_l = {"arm_l": (-12.0, 12.0, 0.0)}
    a = {"arm_r": (-40.0, -4.0, 20.0), "head": (2.0, 0.0, 4.0), "spine": (-2.0, 0.0, -4.0)}
    b = {"arm_r": (-62.0, -14.0, 32.0), "head": (-4.0, -3.0, -2.0), "spine": (1.0, 0.0, -6.0)}
    c = {"arm_r": (-30.0, -18.0, 8.0), "head": (3.0, 3.0, 6.0), "spine": (-1.0, 0.0, -2.0)}
    d = {"arm_r": (-54.0, -6.0, 28.0), "head": (-2.0, 0.0, 0.0), "spine": (0.0, 0.0, -5.0)}
    keys = [(0.0, a), (0.25, b), (0.5, c), (0.75, d)]
    return rig.add(rig.breathe(t, 1.0, 2), rest_l, rig.keyed(t, keys))


ACTIONS = (  # (name, frames at 30 fps, pose function)
    ("idle-loop", 72, idle),
    ("walk-loop", 18, walk),
    ("push_cart-loop", 22, push_cart),
    ("talk-loop", 72, talk),
)


def build():
    mesh = build_mesh()
    dz = rig.ground(mesh)
    arm = rig.build_armature(joints(dz))
    rig.bind(mesh, arm)
    for name, frames, fn in ACTIONS:
        rig.add_action(arm, mesh, name, frames, fn)
    L.export_rigged(arm, NAME, "characters")


if __name__ == "__main__":
    build()
