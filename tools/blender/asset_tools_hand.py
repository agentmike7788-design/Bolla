"""G8 Runde 3 (user: "die leichen preperation annimation fehlen"): the gravekeeper's small hand tools for
the work at the morgue table and his rake - 'Gemaltes Diorama', painted vertex colours on mat_painted.

  ph_tool_scalpel     a slim bone-handled knife (organ removal; the depiction stays implied under the cloth)
  ph_tool_washcloth   a wrung-out wet linen cloth balled in the fist (washing, scrubbing a bone)
  ph_tool_comb        a pale horn comb (laying out: the hair combed)
  ph_tool_juniper     a bundle of juniper twigs, the tip charred (smoking the body)
  ph_tool_shears      plain iron shears (the braid)
  ph_tool_pliers      a small smith's pliers (the teeth)
  ph_tool_linen       the shroud linen, held along its top edge between both fists (spreading it)
  ph_tool_rake        a long ash rake with an iron-shod wooden head (leaves on the graves)

Tool space = the gravekeeper's tool bone (asset_character_tools): local +Y along the handle from its
butt (s = 0; the fist holds it at s_r, asset_character_work), local +Z = the working side (blade edge,
comb teeth, the jaws' bite, the rake's teeth). Not grounded: exported with the butt at the origin, the
figure hangs them at its marker `tool_hand` (rest frame of the tool bone) - Godot shows the one in use
(ToolAnimConfig.tool_scenes), hidden in the tool bag otherwise. Each <= 160 tris (the rake <= 200).
Run:  python tools/blender/build_all.py asset_tools_hand
"""
import math

import bpy  # noqa: F401  (must be imported before bmesh users)
from mathutils import Matrix, Vector

import lib_painted as L
from lib_faces import finish_stable

BONE = L.hexc("#D2C4A2")
BONE_DARK = L.hexc("#A8987A")
STEEL = L.hexc("#7C7F84")
STEEL_DARK = L.hexc("#55585D")
IRON = L.hexc("#3A3C40")
LINEN = L.hexc("#CFC6AE")          # the shroud linen (the family of SHROUD_LINEN #C2B89F, a little lighter)
LINEN_SHADE = L.hexc("#A99F86")
LINEN_WET = L.hexc("#B3AA93")
HORN = L.hexc("#B9A27A")
HORN_DARK = L.hexc("#7E6A4A")
JUNIPER = L.hexc("#465A40")
JUNIPER_DARK = L.hexc("#31402E")
CHAR = L.hexc("#3A3430")
TWINE = L.hexc("#8A7A5C")
ASH = L.hexc("#8A7258")
WOOD = L.hexc("#6E5640")

SCALPEL_LEN = 0.17
LINEN_EDGE = 0.62                  # the top edge from the right fist (s = 0) to the left one
LINEN_DROP = 0.62                  # how far the linen hangs from the edge (towards -Z)
RAKE_LEN = 1.5                     # butt -> the head
RAKE_WIDTH = 0.42


def _p(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _box(c, half, color, **kw):
    return _p(L.prim("cube", loc=c, scale=half), color, **kw)


def _y_tube(s0: float, s1: float, r: float, n: int, color, r_end=None, **kw):
    return _p(L.tube((0, s0, 0), (0, s1, 0), r, n, r_end=r_end), color, **kw)


def scalpel(name: str = "scalpel"):
    """Bone handle (s 0 .. 0.11, flattened four-sided), a slim steel blade, the edge (+Z) curving to the
    point at s = SCALPEL_LEN. ~24 tris."""
    handle = _y_tube(0.0, 0.11, 0.008, 4, BONE, r_end=0.007, var=0.12, ao=0.0, top=0.25, hue_shift=BONE_DARK)
    for v in handle.data.vertices:
        v.co.x *= 0.65
    blade = _box((0, 0.14, 0.002), (0.0015, 0.03, 0.008), STEEL, var=0.1, ao=0.0, top=0.3, hue_shift=STEEL_DARK)
    for v in blade.data.vertices:   # the back straight, the edge sweeping up into the point
        if v.co.y > 0.15:
            v.co.z = 0.004 if v.co.z > 0.0 else -0.002
    obj = L.join([handle, blade], name)
    return obj


def washcloth(name: str = "washcloth"):
    """A wet cloth wrung into a ball round the fist (centre at s 0.03), one corner hanging out towards the
    working side. ~60 tris."""
    ball = _p(L.prim("sphere", loc=(0, 0.035, 0.0), radius=1.0, scale=(0.045, 0.055, 0.04), segments=7, ring_count=4),
              LINEN_WET, var=0.18, ao=0.25, top=0.2, hue_shift=LINEN_SHADE, seed=3)
    L.jitter(ball, 0.008, 18.0, 4)
    flap = _box((0.0, 0.085, 0.03), (0.004, 0.03, 0.035), LINEN_WET, var=0.15, ao=0.15, top=0.2, seed=4)
    for v in flap.data.vertices:
        if v.co.z > 0.05:
            v.co.y += 0.025
            v.co.x += 0.01
    return L.join([ball, flap], name)


def comb(name: str = "comb"):
    """A flat horn comb: the spine at s 0.02 .. 0.13, the teeth edge (+Z) darker. ~12 tris."""
    obj = _box((0, 0.075, 0.012), (0.003, 0.055, 0.02), HORN, var=0.12, ao=0.0, top=0.25, hue_shift=HORN_DARK)
    from asset_carter import _tint
    _tint(obj, lambda co, nr: (1.0, HORN_DARK, 0.5 if co.z > 0.02 else 0.0))
    obj.name = name
    obj.data.name = name
    return obj


def juniper(name: str = "juniper"):
    """A bundle of juniper twigs tied with twine: the stems in the fist (s 0 .. 0.07), the green sprigs fanning
    out to s 0.24, the tip charred where it smoulders. ~70 tris."""
    stems = _y_tube(-0.01, 0.08, 0.012, 5, WOOD, r_end=0.015, var=0.15, ao=0.0, top=0.2)
    bush = _p(L.prim("cone", loc=(0, 0.16, 0), radius1=0.018, radius2=0.045, depth=0.16, vertices=7,
                     rot=(-90, 0, 0)), JUNIPER, var=0.25, ao=0.2, top=0.25, hue_shift=JUNIPER_DARK, seed=5)
    L.jitter(bush, 0.012, 22.0, 6)
    from asset_carter import _tint
    _tint(bush, lambda co, nr: (1.0, CHAR, min(1.0, max(0.0, (co.y - 0.2) / 0.04))))
    tie = L.part("torus", TWINE, loc=(0, 0.075, 0), rot=(90, 0, 0), major_radius=0.016, minor_radius=0.004,
                 major_segments=6, minor_segments=3, paint_kw={"ao": 0.0})
    return L.join([stems, bush, tie], name)


def shears(name: str = "shears"):
    """Plain iron shears, closed: two bows (s 0 .. 0.06, the fist), the pivot, two blades to s 0.2, the cutting
    edges towards +Z. ~44 tris."""
    parts = []
    for sx in (-1, 1):
        parts.append(_box((sx * 0.012, 0.03, 0.0), (0.004, 0.03, 0.008), IRON, var=0.15, ao=0.0, top=0.3, seed=7 + sx))
        blade = _box((sx * 0.002, 0.135, 0.004), (0.0018, 0.065, 0.007), STEEL, var=0.1, ao=0.0, top=0.3,
                     hue_shift=STEEL_DARK, seed=9 + sx)
        for v in blade.data.vertices:
            if v.co.y > 0.17:
                v.co.z *= 0.35
        parts.append(blade)
    parts.append(_box((0, 0.068, 0.0), (0.008, 0.008, 0.008), IRON, var=0.1, ao=0.0))
    return L.join(parts, name)


def pliers(name: str = "pliers"):
    """A small smith's pliers: two handles (s 0 .. 0.13) converging to the joint and the short jaws (s 0.17,
    the bite towards +Y / +Z). ~30 tris."""
    parts = []
    for sx in (-1, 1):
        h = _p(L.tube((sx * 0.016, 0.0, 0.0), (sx * 0.005, 0.13, 0.0), 0.006, 4), IRON, var=0.15, ao=0.0, top=0.3,
               seed=11 + sx)
        parts.append(h)
        parts.append(_box((sx * 0.004, 0.155, 0.003), (0.003, 0.022, 0.006), IRON, var=0.12, ao=0.0, top=0.35,
                          hue_shift=STEEL_DARK, seed=13 + sx))
    parts.append(_box((0, 0.133, 0.0), (0.009, 0.006, 0.007), STEEL_DARK, var=0.1, ao=0.0))
    return L.join(parts, name)


def linen(name: str = "linen"):
    """The shroud linen held along its top edge (+Y, from the right fist at s = 0 to the left one at
    LINEN_EDGE): it hangs LINEN_DROP towards -Z, the edge sagging a little between the fists, two soft folds
    down its length; a thin closed sheet (both sides show). ~110 tris."""
    nu, nv = 6, 4
    bm_verts = []
    import bmesh
    bm = bmesh.new()
    rows = []
    for side in (1, -1):
        row = []
        for j in range(nv + 1):
            line = []
            for i in range(nu + 1):
                u = i / nu
                v = j / nv
                y = -0.02 + u * (LINEN_EDGE + 0.04)
                sag = 0.03 * math.sin(math.pi * u) * (1.0 - 0.5 * v)
                fold = 0.022 * math.sin(u * math.pi * 3.0 + v * 1.3) * v
                x = fold + side * 0.003 + 0.04 * v * v
                z = -sag - v * LINEN_DROP
                line.append(bm.verts.new((x, y, z)))
            row.append(line)
        rows.append(row)
    for k, row in enumerate(rows):
        for j in range(nv):
            for i in range(nu):
                q = (row[j][i], row[j][i + 1], row[j + 1][i + 1], row[j + 1][i])
                bm.faces.new(q if k == 0 else tuple(reversed(q)))
    a, b = rows
    for j in range(nv):   # the side hems
        for i in (0, nu):
            bm.faces.new((a[j][i], a[j + 1][i], b[j + 1][i], b[j][i]))
    for i in range(nu):   # top and bottom hems
        for j in (0, nv):
            bm.faces.new((a[j][i], b[j][i], b[j][i + 1], a[j][i + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    _p(obj, LINEN, var=0.1, ao=0.0, top=0.15, hue_shift=LINEN_SHADE, seed=17)
    from asset_carter import _tint
    _tint(obj, lambda co, nr: (1.0, LINEN_SHADE, 0.45 * max(0.0, math.sin(co.y * math.pi * 3.0 / LINEN_EDGE))))
    return obj


def rake(name: str = "rake"):
    """A long ash rake: the handle from the butt (s = 0) to the head at RAKE_LEN, the wooden head across (X)
    with iron-shod teeth towards +Z. ~150 tris."""
    parts = [_y_tube(0.0, RAKE_LEN, 0.016, 5, ASH, r_end=0.014, var=0.18, ao=0.0, top=0.2, hue_shift=WOOD)]
    head = _box((0, RAKE_LEN, 0.0), (RAKE_WIDTH * 0.5, 0.022, 0.024), WOOD, var=0.2, ao=0.1, top=0.3)
    L.bevel(head, 0.006, 1)
    parts.append(head)
    for k in range(10):
        x = -RAKE_WIDTH * 0.45 + k * RAKE_WIDTH * 0.1
        parts.append(_p(L.tube((x, RAKE_LEN, 0.015), (x, RAKE_LEN - 0.012, 0.085), 0.005, 3), IRON, var=0.1, ao=0.0))
    for sx in (-1, 1):   # the two braces from the handle to the head
        parts.append(_p(L.tube((0, RAKE_LEN - 0.22, 0.0), (sx * 0.12, RAKE_LEN - 0.01, 0.0), 0.006, 3), WOOD,
                        var=0.15, ao=0.0))
    return L.join(parts, name)


TOOLS = {"ph_tool_scalpel": scalpel, "ph_tool_washcloth": washcloth, "ph_tool_comb": comb,
         "ph_tool_juniper": juniper, "ph_tool_shears": shears, "ph_tool_pliers": pliers,
         "ph_tool_linen": linen, "ph_tool_rake": rake}


def build():
    for name, fn in TOOLS.items():
        L.reset(9100 + len(name))
        obj = fn(name=name)
        finish_stable(obj, name, "props", 40, shift=False)


if __name__ == "__main__":
    build()
