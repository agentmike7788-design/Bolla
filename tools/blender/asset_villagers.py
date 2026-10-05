"""Phase 7: the people of Hollerbrueck (docs/PHASE7_DESIGN.md sections 2.1 and 8), 'Gemaltes Diorama'.

Eight villagers on the shared 8-bone rig (rig.py: rigid skinning, root motion off, `-loop` actions are
looped by the Godot importer which strips the suffix), same painted style and figure palette as the
gravekeeper, Osric and Ilse, each with an own silhouette readable from the 22 m game camera:

  ph_chr_v_innkeeper  Rosine Wackernagel, 46 - broad and upright, rust-brown apron over a grey dress,
                      white headscarf knotted at the nape, sleeves rolled up, key bunch at the belt
  ph_chr_v_smith      Ulrich Esch, 52 - the tallest (1.9 m), bald, a grey full beard, leather apron,
                      painted old burn marks on the bare forearms, the hammer in his right fist, tongs at
                      the belt
  ph_chr_v_grocer     Theres Mangold, 38 - slim and quick, a frilled bonnet, sleeve protectors, a striped
                      skirt, an eyeglass on a cord, a pencil behind the ear
  ph_chr_v_priest     Pfarrer Ambrosius Lenz, 61 - round, black cassock with a row of buttons, white
                      preaching bands, a soft black biretta, the breviary held to the belly
  ph_chr_v_mayor      Schultheiss Gottlieb Fenner, 57 - gaunt, an old-fashioned dark-green coat with brass
                      buttons, breeches, buckle shoes, grey queue with a black bow, the staff of office
  ph_chr_v_surgeon    Severin Quast, 41 - slim, dark frock coat, white neckcloth, waxed-cloth over-sleeves,
                      a low top hat, trimmed side whiskers, small round spectacles, the leather case
  ph_chr_v_washer     Liesel Dorn, 44 - a grey woollen shawl over head and shoulders, black dress, white
                      apron, a spindle at the belt, reddened hands
  ph_chr_v_oldwoman   Wiebke Hagedorn, 81 - small and bent, a white cap, a black fringed shoulder shawl,
                      a walking stick, a posy of dried poppy at the bodice

Seated, unrigged figures (static, like the Phase-6 mourners): ph_chr_guest_a / _b (guests of the
Gaststube with a mug) and ph_chr_student_a / _b / _c (Quast's night lecture: coat, cap, notebook, seen
from behind or in half profile). Pivot = floor under the middle of the seat (seat height 0.45 m), the
figure faces -Y Blender = +Z Godot.

Actions (Godot names): every villager idle, walk, talk; work (smith: hammer strikes, grocer: weighing
and counting over the counter, washer: hand-spinning) and sit (Hagedorn: on the well bench, seat
0.45 m). No markers on the villagers.

Front faces -Y (Blender) = +Z (Godot); pivot between the feet on the ground.

G7 Änderungsrunde 1 (faces): every head is built by _head() on a sculpted skull (class Face) with awake
eyes (white, iris, pupil, gleam, arched upper lid + lash line), a soft nose growing out of the face, a
shaped mouth, brows, warm painted skin with blush, and painted age lines where the figure is old;
hair (_hair) and head cloths (_cloth_cover, _frill) are shells over that skull cut along hairline /
hem curves. The seated figures use the same head, coarser (detail=False).

Run:  python tools/blender/build_all.py asset_villagers
"""
import math

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import rig
from asset_carter import loft, sweep, _tint, _thicken, _loops, _n
import asset_props_slice as P
import asset_props_phase6 as M6
from lib_faces import (IRIS_BROWN, IRIS_HAZEL, IRIS_BLUE, IRIS_GREY, IRIS_DARK, _s01, Face, _oell, _shell, _hair,
                       _cloth_cover, _frill, _head, _stable_glb, finish_stable)

W = rig.weight
CAT = "characters"

# --- shared figure palette (gravekeeper / Osric / Ilse family) --------------------------------------
# G7 Änderungsrunde 1: warmer skin (the gravekeeper / Osric family), no grey-lilac shading
SKIN = L.hexc("#CE9E7F")
SKIN_ROSY = L.hexc("#CC8570")
SKIN_PALE = L.hexc("#D0A78C")          # fair, but warm
SKIN_SHADE = L.hexc("#A0705F")
SKIN_OLD = L.hexc("#CBA08A")
SKIN_RED = L.hexc("#C47F6A")          # Liesel's washing hands, the smith's burns (healed, brownish)
BURN = L.hexc("#8E5C4C")
EYE = L.hexc("#1B1715")
GLEAM = L.hexc("#E9E2D2")
LIP = L.hexc("#A86A5C")
LIP_PALE = L.hexc("#9A7268")
SOLE = L.hexc("#1C1816")
BOOT = L.hexc("#2E251F")
BOOT_WORN = L.hexc("#4E3E31")
IRON = L.hexc("#3A3C40")
IRON_LIGHT = L.hexc("#5E6166")
BRASS = L.hexc("#8C7648")
BRASS_DARK = L.hexc("#6E5C3A")
LEATHER = L.hexc("#5E4433")
LEATHER_DARK = L.hexc("#3F2E24")
LINEN_WHITE = L.hexc("#D3CBB8")
LINEN_SHADE = L.hexc("#B3AA95")
BLACK = L.hexc("#2A2726")
BLACK_DARK = L.hexc("#1E1C1C")
BLACK_SHEEN = L.hexc("#3E3A3A")
WOOD = L.hexc("#6E5640")
WOOD_DARK = L.hexc("#4A3A2C")


# --- helpers -----------------------------------------------------------------------------------------

def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


def _xf(obj, m: Matrix):
    obj.data.transform(m)
    return obj


def _frame(origin, fwd, up) -> Matrix:
    y = Vector(fwd).normalized()
    x = y.cross(Vector(up)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def _ell(color, loc, scale, seg: int = 10, rings: int = 6, rot=(0, 0, 0), jit: float = 0.0, seed: int = 0, **pk):
    """Painted ellipsoid (radius 1 scaled)."""
    o = L.prim("sphere", loc=loc, radius=1.0, scale=scale, rot=rot, segments=seg, ring_count=rings)
    if jit:
        L.jitter(o, jit, 6.0, seed)
    return _painted(o, color, seed=seed, **pk)


class Prof:
    """Body profile: rings (z, rx, ry, cy) bottom -> top, linear in between."""

    def __init__(self, rings):
        self.rings = rings

    def at(self, z: float) -> tuple:
        r = self.rings
        if z <= r[0][0]:
            return r[0][1:]
        for a, b in zip(r, r[1:]):
            if z <= b[0]:
                t = (z - a[0]) / max(1e-6, b[0] - a[0])
                return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
        return r[-1][1:]

    def surf(self, x: float, z: float, side: int = -1, out: float = 0.0) -> Vector:
        """Point on the surface (side -1 = front, +1 = back) at x, z."""
        rx, ry, cy = self.at(z)
        rx += out
        ry += out
        k = min(0.98, abs(x) / rx)
        return Vector((x, cy + side * ry * math.sqrt(1.0 - k * k), z))

    def normal(self, x: float, z: float, side: int = -1) -> Vector:
        rx, ry, cy = self.at(z)
        p = self.surf(x, z, side)
        return Vector((x / (rx * rx), (p.y - cy) / (ry * ry), 0.0)).normalized()


def _body(prof: Prof, base, dark, *, n: int = 24, seed: int = 0, fold: float = 0.012, fold_k: float = 7.0,
          fold_top: float = 0.9, part_front: float = 0.0, part_w: float = 0.42, cap: bool = True,
          hem_wave: float = 0.008, var: float = 0.16, name: str = "body"):
    """Lofted garment (dress, cassock, coat, shirt): soft folds in the skirt, an uneven hem,
    optionally parted at the front (hem rises in an inverted V by part_front)."""
    front = -math.pi / 2
    bm = bmesh.new()
    rows = []
    for i, (z, rx, ry, cy) in enumerate(prof.rings):
        row = []
        skirt = max(0.0, (fold_top - z) / max(0.1, fold_top))
        for k in range(n):
            a = math.tau * k / n
            d = abs((a - front + math.pi) % math.tau - math.pi)
            f = fold * math.sin(a * fold_k + 0.8 + seed) * skirt + fold * 0.45 * math.sin(a * 12.0 + 2.0) * skirt
            zz = z
            if i == 0:
                zz += hem_wave * math.sin(a * 9.0 + seed)
                if part_front > 0.0:
                    zz += part_front * max(0.0, 1.0 - d / part_w) ** 1.4
            elif i == 1 and part_front > 0.0:
                zz += 0.45 * part_front * max(0.0, 1.0 - d / (part_w * 0.7)) ** 1.4
            row.append(bm.verts.new((math.cos(a) * (rx + f), cy + math.sin(a) * (ry + f), zz)))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    if cap:
        z, rx, ry, cy = prof.rings[-1]
        c = bm.verts.new((0.0, cy, z + 0.004))
        for k in range(n):
            bm.faces.new((c, rows[-1][k], rows[-1][(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    L.jitter(obj, 0.005, 3.0, seed + 5)
    z0, z1 = prof.rings[0][0], prof.rings[-1][0]
    _painted(obj, base, var=var, ao=0.3, top=0.14, zrange=(z0, z1), seed=seed + 6, hue_shift=dark)

    def shade(co, nr):
        a = math.atan2(co.y, co.x)
        s = max(0.0, (fold_top - co.z) / max(0.1, fold_top))
        f = 1.0 - 0.1 * max(0.0, math.sin(a * fold_k + 0.8 + seed)) * s
        f *= 1.0 - 0.1 * max(0.0, (0.5 - co.z) / 0.45)
        return f, None, 0.0
    _tint(obj, shade)
    return obj


def _ring_band(prof: Prof, z: float, r: float, color, out: float = 0.004, n: int = 18, seed: int = 0, flat: float = 1.0,
               var: float = 0.15):
    """Belt / waistband round the body at height z."""
    rx, ry, cy = prof.at(z)
    pts = [Vector((math.cos(a) * (rx + out), cy + math.sin(a) * (ry + out), z)) for a in (math.tau * k / n for k in range(n))]
    nrm = [Vector((math.cos(a), math.sin(a), 0.0)) for a in (math.tau * k / n for k in range(n))]
    return _painted(sweep(pts, r, n=5, closed=True, normals=nrm, flat=flat, name="band"), color, var=var, ao=0.0,
                    top=0.3, seed=seed)


def _sheet_on(prof: Prof, xs, zs, out: float, color, dark=None, seed: int = 0, thick: float = 0.008, side: int = -1,
              xfn=None, var: float = 0.14, name: str = "sheet"):
    """Cloth sheet lying on the profile surface (apron, bib, bands): grid over x in xs (per row:
    xfn(z) -> (x0, x1) overrides), z in zs; pushed out by `out`."""
    bm = bmesh.new()
    rows = []
    nx = len(xs)
    for z in zs:
        x0, x1 = xfn(z) if xfn else (xs[0], xs[-1])
        row = []
        for i in range(nx):
            t = i / (nx - 1)
            x = x0 + (x1 - x0) * t
            row.append(bm.verts.new(prof.surf(x, z, side, out)))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(nx - 1):
            f = (r0[i], r0[i + 1], r1[i + 1], r1[i]) if side < 0 else (r0[i], r1[i], r1[i + 1], r0[i + 1])
            bm.faces.new(f)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if thick:
        _thicken(obj, thick)
    return _painted(obj, color, var=var, ao=0.2, top=0.2, seed=seed, hue_shift=dark)


def _shoe(parts, leg: str, x0: float, color, *, length: float = 0.15, width: float = 0.068, height: float = 0.062,
          toe: float = -0.075, pointed: float = 0.0, buckle=None, shaft: float = 0.0, shaft_r: float = 0.058,
          seed: int = 0):
    """Shoe or boot: sole, rounded foot, optional boot shaft and buckle."""
    sole = loft([(-0.004, width * 1.08, length * 1.04, x0, toe + 0.005), (0.016, width * 1.12, length * 1.06, x0, toe + 0.005),
                 (0.026, width * 1.05, length, x0, toe + 0.005)], n=14, p=2.4, name="sole")
    parts.append(W(leg, _painted(sole, SOLE, var=0.1, ao=0.0, top=0.05, seed=seed)))
    foot = L.prim("sphere", loc=(x0, toe, height), radius=1.0, scale=(width, length, height), segments=12,
                  ring_count=7)
    for v in foot.data.vertices:
        v.co.z = max(v.co.z, 0.024)
        if v.co.y < toe - length * 0.6:
            v.co.z += pointed * (toe - length * 0.6 - v.co.y)
    L.jitter(foot, 0.004, 8.0, seed + 1)
    _painted(foot, color, var=0.14, ao=0.1, top=0.3, seed=seed + 1)
    parts.append(W(leg, foot))
    if shaft > 0.0:
        sh = loft([(0.04, shaft_r, shaft_r * 1.05, x0, 0.0), (shaft * 0.6, shaft_r * 0.92, shaft_r, x0, 0.0),
                   (shaft, shaft_r * 1.0, shaft_r * 1.04, x0, 0.0)], n=12, name="shaft")
        parts.append(W(leg, _painted(sh, color, var=0.16, ao=0.25, top=0.1, seed=seed + 2, hue_shift=BOOT_WORN)))
    if buckle is not None:
        parts.append(W(leg, L.part("cube", buckle, loc=(x0, toe - length * 0.45, height + 0.03), scale=(0.03, 0.006, 0.02),
                                   rot=(-35, 0, 0), paint_kw={"ao": 0.0, "top": 0.5, "var": 0.1})))


def _leg_tube(parts, leg: str, pts, radii, color, dark=None, n: int = 10, seed: int = 0):
    t = sweep([Vector(p) for p in pts], radii, n=n, name="legtube")
    parts.append(W(leg, _painted(t, color, var=0.14, ao=0.25, top=0.1, seed=seed, hue_shift=dark)))
    return t


def _hand(parts, bone: str, wr: Vector, axis: Vector, sx: int, skin, size: float = 1.0, grip: bool = False,
          seed: int = 0, shade=None):
    """Mitten hand below the wrist (Osric style): palm, curled finger block, thumb in front."""
    c = wr + axis * 0.05 * size
    shade = shade or SKIN_ROSY
    parts.append(W(bone, _ell(skin, c, (0.036 * size, 0.05 * size, 0.052 * size), seg=10, rings=6, jit=0.002,
                              seed=seed, ao=0.15, var=0.08)))
    fc = c + axis * 0.04 * size + Vector((0.0, -0.012 if grip else 0.0, 0.0))
    parts.append(W(bone, _ell(skin, fc, (0.034 * size, (0.05 if grip else 0.042) * size, 0.036 * size), seg=10,
                              rings=6, rot=(0, sx * -12, 0), jit=0.002, seed=seed + 1, ao=0.25, var=0.1,
                              hue_shift=shade)))
    th = sweep([c + Vector((-sx * 0.01, -0.024, 0.016)) * size, c + Vector((-sx * 0.017, -0.043, -0.01)) * size,
                c + Vector((-sx * 0.015, -0.047, -0.034)) * size], [0.015 * size, 0.014 * size, 0.011 * size], n=6,
               name="thumb")
    parts.append(W(bone, _painted(th, skin, var=0.08, ao=0.1, seed=seed + 2, hue_shift=shade)))
    return fc


def _arm(parts, sx: int, sh: Vector, el: Vector, wr: Vector, color, dark=None, *, r=(0.06, 0.058, 0.052, 0.056),
         n: int = 10, seed: int = 0, rolled: bool = False, skin=SKIN, cuff=None, cuff_r: float = 0.064,
         hand: bool = True, hand_size: float = 1.0, grip: bool = False, shoulder: bool = True, hand_shade=None):
    """Sleeve from the shoulder over the elbow to the wrist (or rolled up to the elbow over a bare
    forearm), a cuff, the hand. Returns the hand centre."""
    bone = _side(sx, "arm")
    if rolled:
        sl = sweep([sh, sh.lerp(el, 0.5), el], [r[0], r[1], r[1] * 1.02], n=n, name="sleeve")
        parts.append(W(bone, _painted(sl, color, var=0.14, ao=0.15, seed=seed, hue_shift=dark)))
        ax = (el - sh).normalized()
        for off, mr, mn, sd in ((0.0, r[1] * 0.92, r[1] * 0.42, 1), (0.03, r[1] * 0.98, r[1] * 0.3, 2)):
            roll = L.prim("torus", major_radius=mr, minor_radius=mn, major_segments=10, minor_segments=5)
            _xf(roll, Matrix.Translation(el - ax * off) @ Vector((0, 0, 1)).rotation_difference(ax).to_matrix().to_4x4())
            L.jitter(roll, 0.005, 5.0, seed + sd)
            parts.append(W(bone, _painted(roll, color, var=0.16, ao=0.1, seed=seed + sd, hue_shift=dark)))
        fore = sweep([el, el.lerp(wr, 0.35), el.lerp(wr, 0.75), wr], [r[2] * 0.95, r[2], r[2] * 0.9, r[2] * 0.76],
                     n=n, name="forearm")
        parts.append(W(bone, _painted(fore, skin, var=0.08, ao=0.15, seed=seed + 3, hue_shift=hand_shade or SKIN_ROSY)))
    else:
        sl = sweep([sh, sh.lerp(el, 0.5), el, el.lerp(wr, 0.55), wr], list(r[:2]) + [r[2], r[2] * 1.02, r[3]], n=n,
                   name="sleeve")
        _painted(sl, color, var=0.14, ao=0.15, seed=seed, hue_shift=dark)
        axis = (wr - sh).normalized()
        _tint(sl, lambda co, nr, sh=sh, axis=axis: (
            1.0 - 0.12 * max(0.0, math.sin((co - sh).dot(axis) * 40.0 + co.x * 30.0)), None, 0.0))
        parts.append(W(bone, sl))
        if cuff is not None:
            ax = (wr - el).normalized()
            c = sweep([wr - ax * 0.03, wr + ax * 0.008], [cuff_r, cuff_r * 1.05], n=n, name="cuff")
            parts.append(W(bone, _painted(c, cuff, var=0.12, ao=0.0, top=0.3, seed=seed + 4)))
    if shoulder:
        parts.append(W(bone, _ell(color, sh + Vector((sx * 0.004, 0.0, -0.01)), (r[0] * 1.02, r[0] * 0.98, r[0] * 0.9),
                                  seg=10, rings=6, top=0.2, seed=seed + 5, hue_shift=dark)))
    if not hand:
        return wr
    ax = (wr - el).normalized()
    return _hand(parts, bone, wr, ax, sx, skin, hand_size, grip, seed + 6, shade=hand_shade)


# --- heads: lib_faces.py (shared with the gravekeeper, Osric, Ilse, the ghost and the corpses) ---

def _global_light(mesh, top: float) -> None:
    """Whole-figure painterly pass (as Osric/Ilse): ink-blue towards the ground, warm on the shoulders."""
    ink = L.hexc("#1F2A3A")
    warm = L.hexc("#D8B98A")
    attr = mesh.data.color_attributes["Col"]
    for li, co, nr in _loops(mesh):
        c = attr.data[li].color
        low = max(0.0, 1.0 - co.z / 0.7) ** 2
        high = max(0.0, (co.z - (top - 0.5)) / 0.5) * max(0.0, nr.z)
        rgb = [x * (1.0 - 0.16 * low) for x in c[:3]]
        rgb = [x + (L._to_lin(k) - x) * 0.12 * low for x, k in zip(rgb, ink)]
        rgb = [x + (L._to_lin(k) - x) * 0.1 * high for x, k in zip(rgb, warm)]
        attr.data[li].color = (rgb[0], rgb[1], rgb[2], 1.0)


# --- deterministic export: lib_faces._stable_glb / finish_stable ----------------------------------

def _export(arm, name: str) -> None:
    L.export_rigged(arm, name, CAT)
    _stable_glb(L.os.path.join(L.ROOT, "assets", "models", CAT, name + ".glb"))


# Phase 8 (docs/PHASE8_DESIGN.md §8.2): additional clips per villager, re-exported with the Phase-7 geometry,
# faces, materials and clips unchanged (test_assets_phase8 compares the mesh hash and the old clips). Sets:
# low = idle_low, lantern = lantern_walk (+ child mesh `lantern_prop`), kneel = kneel_in / kneel / kneel_out,
# lay = lay_flowers, mourn = mourn_stand, knock, dance, clap. keep_r: the right arm holds a tool that is part
# of the body (Esch's hammer, Fenner's staff) and stays where it is in dance / mourn_stand.
P8_CLIPS = {
    "ph_chr_v_innkeeper": {"sets": ("low", "lantern", "kneel", "lay", "dance", "clap")},
    "ph_chr_v_smith": {"sets": ("low", "lantern", "mourn", "dance"), "keep_r": True},
    "ph_chr_v_grocer": {"sets": ("low", "lantern", "kneel", "lay", "dance", "clap")},
    "ph_chr_v_priest": {"sets": ("low", "lantern", "mourn", "knock", "clap")},
    "ph_chr_v_mayor": {"sets": ("low", "lantern", "mourn", "dance"), "keep_r": True},
    "ph_chr_v_surgeon": {"sets": ("low", "lantern", "knock"), "lantern_side": -1},
    "ph_chr_v_washer": {"sets": ("low", "lantern", "kneel", "lay", "knock", "dance", "clap")},
    "ph_chr_v_oldwoman": {"sets": ("low", "lantern")},
}


def _fist(mesh, bone: str) -> Vector:
    """The hand of a rigid arm: the centre of its lowest 8 cm (as test_assets_characters.Rig.hand)."""
    gi = mesh.vertex_groups[bone].index
    vs = [v.co.copy() for v in mesh.data.vertices if any(g.group == gi and g.weight > 0.5 for g in v.groups)]
    z0 = min(v.z for v in vs)
    sel = [v for v in vs if v.z < z0 + 0.08]
    return sum(sel, Vector()) / len(sel)


def _p8(name: str, mesh, actions):
    """(extra actions, child meshes) of a villager for Phase 8."""
    cfg = P8_CLIPS.get(name)
    if cfg is None:
        return [], []
    import asset_mourners as M   # Phase 8 helpers (imports this module)
    walk = dict((a[0], a[2]) for a in actions)["walk-loop"]
    side = cfg.get("lantern_side", 1)
    extra = M.p8_actions(set(cfg["sets"]), walk, lantern_side=side, kneel_pose=rig.kneel(0.42, 12.0, 14.0, 18.0, hands=(18.0, 28.0)),
                         mourn={"hands": (16.0, 27.0)})
    if cfg.get("keep_r"):
        def keep(fn):
            def g(t):
                p = dict(fn(t))
                p["arm_r"] = (-2.0, 0.0, 0.0)
                return p
            return g
        extra = [(n, f, keep(fn) if n.startswith(("dance", "mourn")) else fn) for n, f, fn in extra]
    kids = []
    if "lantern" in cfg["sets"]:
        bone = "arm_l" if side > 0 else "arm_r"
        kids.append(M.child("lantern_prop", bone, M.lantern_child(_fist(mesh, bone)), ("lantern_walk",)))
    return extra, kids


def _rigged(name: str, mesh, joints: dict, actions) -> None:
    extra, kids = _p8(name, mesh, actions)
    dz = rig.ground(mesh)
    j = {b: (tuple(Vector(h) - Vector((0, 0, dz))), tuple(Vector(t) - Vector((0, 0, dz)))) for b, (h, t) in joints.items()}
    arm = rig.build_armature(j)
    rig.bind(mesh, arm)
    for an, frames, fn in tuple(actions) + tuple(extra):
        rig.add_action(arm, mesh, an, frames, fn)
    if not kids:
        _export(arm, name)
        return
    import asset_mourners as M
    extras = {}
    for cname, bone, obj, show in kids:
        obj.data.transform(Matrix.Translation(Vector((0, 0, -dz))))
        obj.name = cname
        obj.data.name = cname
        obj.parent = arm
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = Matrix.Identity(4)
        extras[cname] = {"show_with": ",".join(show)}
    L.export_rigged(arm, name, CAT)
    path = L.os.path.join(L.ROOT, "assets", "models", CAT, name + ".glb")
    M.set_extras(path, extras)
    _stable_glb(path)


def _joints(hip_z: float, waist_z: float, neck: Vector, head_top: Vector, shoulders: dict, wrists: dict,
            leg_x: float, hips_y: float = 0.0, waist_y: float = 0.0) -> dict:
    j = {
        "root": ((0, 0, 0), (0, 0, 0.3)),
        "hips": ((0, hips_y, hip_z), (0, waist_y, waist_z)),
        "spine": ((0, waist_y, waist_z), tuple(neck)),
        "head": (tuple(neck + Vector((0, 0, -0.01))), tuple(head_top)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (tuple(shoulders[sx]), tuple(wrists[sx]))
        j[_side(sx, "leg")] = ((sx * leg_x, hips_y, hip_z + 0.04), (sx * leg_x, 0.0, 0.1))
    return j


# --- poses -------------------------------------------------------------------------------------------

def _idle(amount: float = 1.0, sway: float = 1.0, head: float = 1.0, extra=None):
    def fn(t: float) -> dict:
        s = math.sin(rig.TAU * t)
        p = rig.add(rig.breathe(t, amount), {
            "hips": (0.0, 1.2 * sway * s, 0.0, 0.003 * sway * s, 0.0, 0.0),
            "spine": (0.0, -1.2 * sway * s, 0.0),
            "head": (1.2 * head * math.sin(rig.TAU * t * 2.0), 0.0, 2.5 * head * s),
        })
        return rig.add(p, extra(t)) if extra else p
    return fn


def _walk(leg, lift, arm, bob, roll, yaw, lean, extra=None):
    def fn(t: float) -> dict:
        g = rig.gait(t, leg=leg, lift=lift, arm=arm, bob=bob, roll=roll, yaw=yaw, lean=lean)
        return rig.add(g, extra(t)) if extra else g
    return fn


def _talk(keys, amount: float = 1.0, base=None):
    def fn(t: float) -> dict:
        p = rig.add(rig.breathe(t, amount, 2), rig.keyed(t, keys))
        return rig.add(p, base) if base else p
    return fn


# ======================================================================================================
# Rosine Wackernagel - the innkeeper
# ======================================================================================================

ROS_DRESS = L.hexc("#6F6A62")
ROS_DRESS_DARK = L.hexc("#55514B")
ROS_APRON = L.hexc("#7A4A32")
ROS_APRON_DARK = L.hexc("#5A3626")
ROS_BODICE = L.hexc("#4E4640")
ROS_SCARF = L.hexc("#CFC6B3")
ROS_HAIR = L.hexc("#5E4430")
ROS_HAIR_DARK = L.hexc("#3E2C20")


def innkeeper():
    L.reset(7101)
    parts = []
    prof = Prof(((0.06, 0.29, 0.26, 0.012), (0.22, 0.282, 0.252, 0.01), (0.45, 0.268, 0.236, 0.006),
                 (0.7, 0.252, 0.218, 0.0), (0.9, 0.232, 0.196, 0.0), (0.98, 0.212, 0.172, -0.004),
                 (1.06, 0.214, 0.18, -0.014), (1.15, 0.226, 0.196, -0.022), (1.22, 0.224, 0.188, -0.016),
                 (1.27, 0.206, 0.16, -0.006), (1.31, 0.165, 0.13, -0.004), (1.345, 0.09, 0.08, -0.008)))
    waist = 0.98
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.095, BOOT, length=0.13, width=0.064, height=0.056, toe=-0.08, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.095, 0.0, 0.04), (sx * 0.1, 0.0, 0.5), (sx * 0.1, 0.0, 0.9)],
                  [0.05, 0.056, 0.07], BLACK, seed=12)
    dress = _body(prof, ROS_DRESS, ROS_DRESS_DARK, n=26, seed=1, fold=0.013)
    parts.append(rig.weight_split_z(dress, waist, "hips", "spine"))
    # laced dark bodice over the chest
    bod = _sheet_on(prof, [0] * 5, [0.99, 1.06, 1.13, 1.2, 1.25], 0.004, ROS_BODICE, seed=2, thick=0.006,
                    xfn=lambda z: (-0.15 + 0.2 * max(0.0, z - 1.2), 0.15 - 0.2 * max(0.0, z - 1.2)))
    parts.append(W("spine", bod))
    for k in range(4):
        z = 1.01 + k * 0.055
        for d in (-1, 1):
            p0 = prof.surf(-0.03, z, -1, 0.012)
            p1 = prof.surf(0.03, z + d * 0.02, -1, 0.012)
            parts.append(W("spine", _painted(sweep([p0, p1], 0.0035, n=4, name="lace"), LINEN_SHADE, ao=0.0, var=0.05)))
    # the big rust-brown apron from the waist to below the knee, and its bib
    ap = _sheet_on(prof, [0] * 7, [0.32, 0.45, 0.6, 0.75, 0.88, 0.97], 0.01, ROS_APRON, ROS_APRON_DARK, seed=3,
                   xfn=lambda z: (-0.205 - 0.04 * (0.97 - z), 0.205 + 0.04 * (0.97 - z)))
    _tint(ap, lambda co, nr: (1.0 - 0.12 * max(0.0, math.sin(co.x * 40.0)) * max(0.0, (0.9 - co.z) / 0.6), None, 0.0))
    parts.append(W("hips", ap))
    parts.append(W("hips", _ring_band(prof, waist, 0.018, ROS_APRON_DARK, out=0.012, flat=0.45, seed=4)))
    # apron strings tied in a bow at the back
    bk = prof.surf(0.0, waist, 1, 0.02)
    parts.append(W("hips", _ell(ROS_APRON_DARK, bk, (0.04, 0.02, 0.025), seg=8, rings=5, seed=5)))
    for sx in (-1, 1):
        parts.append(W("hips", _painted(sweep([bk, bk + Vector((sx * 0.03, 0.02, -0.14))], [0.014, 0.01], n=4,
                                              flat=0.4, name="tie"), ROS_APRON_DARK, ao=0.0, seed=6)))
    # key bunch on her left hip: a ring and four iron keys
    kc = prof.surf(0.19, waist - 0.05, -1, 0.025)
    parts.append(W("hips", L.part("torus", IRON, loc=kc, rot=(90, 0, 20), major_radius=0.028, minor_radius=0.005,
                                  major_segments=10, minor_segments=4, paint_kw={"ao": 0.0, "top": 0.4})))
    for k, a in enumerate((-30, -10, 12, 30)):
        d = Vector((math.sin(math.radians(a)), -0.2, -1.0)).normalized()
        p0 = kc + Vector((0, 0, -0.026))
        p1 = p0 + d * 0.085
        parts.append(W("hips", _painted(sweep([p0, p1], 0.005, n=4, name="key"), IRON_LIGHT, ao=0.0, var=0.2, seed=7 + k)))
        parts.append(W("hips", L.part("cube", IRON_LIGHT, loc=p1, scale=(0.008, 0.004, 0.012), paint_kw={"ao": 0.0})))
    # arms: rolled sleeves, sturdy bare forearms, hands at her sides
    sh = {sx: Vector((sx * 0.215, -0.005, 1.275)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.27, -0.0, 1.03)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.29, -0.07, 0.82)) for sx in (-1, 1)}
    for sx in (-1, 1):
        _arm(parts, sx, sh[sx], el[sx], wr[sx], ROS_DRESS, ROS_DRESS_DARK, r=(0.066, 0.064, 0.05, 0.05), rolled=True,
             skin=SKIN, seed=20 + sx * 3, hand_size=1.1)
    # head: broad, warm, a hearty smile; brown hair parted in the middle under the white headscarf
    c = Vector((0.0, -0.03, 1.47))
    s = Vector((0.142, 0.138, 0.15))
    pts = _head(parts, c, s, SKIN, seed=30, nose="round", nose_s=1.0, brow=ROS_HAIR, brow_w=1.05, brow_tilt=0.5,
                mouth="laugh", cheeks=0.9, jaw=1.0, chin=0.03, iris=IRIS_BROWN, lids=0.12, ears=False)
    face = pts["face"]
    _hair(parts, face, ROS_HAIR, ROS_HAIR_DARK, [(0.0, 0.46), (0.5, 0.4), (0.95, 0.18), (1.3, -0.12), (1.7, -0.3),
                                                 (math.pi, -0.55)], out=0.006, crown=0.004, part_u=0.0, seed=31)
    _cloth_cover(parts, face, ROS_SCARF, LINEN_SHADE, [(0.0, 0.66), (0.6, 0.58), (1.05, 0.2), (1.4, -0.22),
                                                      (2.0, -0.55), (math.pi, -0.7)],
                 out=lambda ph, w: 0.016 + 0.006 * max(0.0, math.cos(ph)), crown=0.006, folds=7.0, rim=0.0095 * face.k,
                 rim_phi=1.9, lumps=0.006, seed=32, name="scarf")
    knot = c + Vector((0.0, s.y + 0.03, -0.07))
    parts.append(W("head", _ell(ROS_SCARF, knot, (0.04, 0.032, 0.035), seg=8, rings=5, seed=34, jit=0.004)))
    for sx in (-1, 1):
        t0 = knot + Vector((sx * 0.012, 0.012, -0.01))
        parts.append(W("head", _painted(sweep([t0, t0 + Vector((sx * 0.04, 0.03, -0.09)), t0 + Vector((sx * 0.05, 0.04, -0.16))],
                                              [0.026, 0.024, 0.008], n=6, flat=0.35, name="tail"), ROS_SCARF, var=0.1,
                                        ao=0.1, top=0.2, seed=35 + sx)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.62)
    L.smooth(mesh, 55)
    joints = _joints(0.86, waist, Vector((0, -0.01, 1.34)), Vector((0, -0.03, 1.66)), sh, wr, 0.1)
    talk_keys = [
        (0.0, {"arm_r": (-26.0, -6.0, 14.0), "arm_l": (-6.0, 6.0, 0.0), "head": (2.0, 0.0, 6.0)}),
        (0.25, {"arm_r": (-58.0, -16.0, 28.0), "arm_l": (-14.0, 10.0, -6.0), "head": (-3.0, -4.0, -4.0),
                "spine": (-2.0, 0.0, -4.0)}),
        (0.5, {"arm_r": (-34.0, -4.0, 10.0), "arm_l": (-30.0, 14.0, -12.0), "head": (3.0, 3.0, 8.0)}),
        (0.75, {"arm_r": (-62.0, -10.0, 32.0), "arm_l": (-8.0, 6.0, 0.0), "head": (-2.0, 2.0, -6.0),
                "spine": (-1.0, 0.0, 3.0)}),
    ]
    actions = (
        ("idle-loop", 72, _idle(1.3, 1.2, 1.2)),
        ("walk-loop", 20, _walk(22.0, 0.04, 16.0, 0.014, 4.0, 4.0, 0.5)),
        ("talk-loop", 72, _talk(talk_keys, 1.2)),
    )
    _rigged("ph_chr_v_innkeeper", mesh, joints, actions)


# ======================================================================================================
# Ulrich Esch - the smith
# ======================================================================================================

SM_SHIRT = L.hexc("#A69C86")
SM_SHIRT_DARK = L.hexc("#857C68")
SM_APRON = L.hexc("#4E3A2C")
SM_APRON_DARK = L.hexc("#36281F")
SM_APRON_WORN = L.hexc("#6E5440")
SM_TROUSER = L.hexc("#3C3530")
SM_TROUSER_DARK = L.hexc("#2C2724")
SM_SKIN = L.hexc("#C29276")
SM_BEARD = L.hexc("#8E8A82")
SM_BEARD_DARK = L.hexc("#6E6A63")
SM_BEARD_LIGHT = L.hexc("#AAA69C")


def smith():
    L.reset(7201)
    parts = []
    hip = 0.96
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.13
        _shoe(parts, leg, x0, BOOT, length=0.17, width=0.08, height=0.07, toe=-0.08, shaft=0.24, shaft_r=0.075,
              seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.2), (sx * 0.135, -0.008, 0.45), (sx * 0.13, -0.004, 0.72),
                               (sx * 0.125, 0.0, hip)], [0.085, 0.086, 0.094, 0.1], SM_TROUSER, SM_TROUSER_DARK, n=12,
                  seed=12)
    parts.append(W("hips", _ell(SM_TROUSER, (0, 0.0, hip - 0.1), (0.25, 0.17, 0.13), seg=14, rings=8, seed=13,
                                hue_shift=SM_TROUSER_DARK)))
    prof = Prof(((0.82, 0.25, 0.19, 0.0), (0.95, 0.27, 0.205, -0.01), (1.05, 0.28, 0.212, -0.018),
                 (1.18, 0.3, 0.226, -0.02), (1.3, 0.322, 0.236, -0.016), (1.4, 0.33, 0.236, -0.006),
                 (1.47, 0.31, 0.21, 0.0), (1.53, 0.24, 0.17, 0.004), (1.57, 0.12, 0.1, 0.0)))
    waist = 1.02
    shirt = _body(prof, SM_SHIRT, SM_SHIRT_DARK, n=24, seed=2, fold=0.006, fold_top=1.1, cap=True)
    parts.append(rig.weight_split_z(shirt, waist, "hips", "spine"))
    # open collar showing the throat
    parts.append(W("spine", _ell(SM_SKIN, (0, -0.1, 1.53), (0.07, 0.04, 0.05), seg=8, rings=5, seed=14)))
    # heavy leather apron from the chest to below the knees, worn lighter where the work rubs
    ap_prof = Prof([(z, rx, ry, cy) for z, rx, ry, cy in prof.rings] )

    def apron_x(z):
        if z > 1.2:
            return (-0.16, 0.16)
        return (-0.24, 0.24)
    zs = [0.42, 0.55, 0.7, 0.84, 0.96, 1.08, 1.2, 1.3, 1.4]
    leg_prof = Prof(((0.3, 0.26, 0.17, -0.02), (0.82, 0.27, 0.19, -0.01)) + prof.rings[1:])
    ap = _sheet_on(leg_prof, [0] * 7, zs, 0.016, SM_APRON, SM_APRON_DARK, seed=3, thick=0.012, xfn=apron_x)
    _tint(ap, lambda co, nr: (1.0, SM_APRON_WORN, 0.5 * max(0.0, 1.0 - abs(co.z - 1.0) / 0.14) * (0.5 + 0.5 * _n(co, 9.0))
                                   + 0.25 * max(0.0, _n(co, 4.0, 3.0))))
    # rigid apron: lower part to the hips, bib to the spine
    parts.append(rig.weight_split_z(ap, waist, "hips", "spine"))
    del ap_prof
    parts.append(W("hips", _ring_band(prof, waist, 0.02, LEATHER_DARK, out=0.024, flat=0.45, seed=4)))
    for sx in (-1, 1):   # neck straps of the apron
        p0 = prof.surf(sx * 0.15, 1.4, -1, 0.02)
        p1 = Vector((sx * 0.1, -0.05, 1.56))
        p2 = Vector((sx * 0.07, 0.08, 1.55))
        parts.append(W("spine", _painted(sweep([p0, p1, p2], 0.018, n=5, flat=0.35, name="strap"), LEATHER_DARK,
                                         ao=0.0, seed=5)))
    # tongs hanging on the belt at his left hip
    tc = prof.surf(0.27, waist, -1, 0.03)
    for d in (-1, 1):
        parts.append(W("hips", _painted(sweep([tc + Vector((0.0, 0, 0.04)), tc + Vector((d * 0.012, -0.01, -0.12)),
                                               tc + Vector((d * 0.02, -0.012, -0.3))], [0.009, 0.008, 0.007], n=5,
                                              name="tong"), IRON, ao=0.0, var=0.2, top=0.4, seed=6)))
    # arms: sleeves rolled to the elbow, big bare forearms with old burn marks
    sh = {sx: Vector((sx * 0.285, 0.0, 1.46)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.39, 0.0, 1.2)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.42, -0.08, 0.96)) for sx in (-1, 1)}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], SM_SHIRT, SM_SHIRT_DARK, r=(0.098, 0.094, 0.068, 0.07),
                         rolled=True, skin=SM_SKIN, seed=20 + sx * 3, hand_size=1.28, grip=(sx < 0), n=12)
    # burns: tint the forearm parts just made (weighted to the arms, below the elbow)
    for o in parts[-30:]:
        if o.name.startswith("forearm"):
            if True:
                _tint(o, lambda co, nr: (1.0, BURN, 0.7 if noise.noise(co * 22.0 + Vector((4, 1, 2))) > 0.22 else 0.0))
    # the hammer in his right fist, head down by the leg
    hc = hands[-1]
    ax = (wr[-1] - el[-1]).normalized()
    top = hc + Vector((0.0, -0.005, 0.07))
    bot = hc + Vector((0.0, -0.01, -0.3))
    parts.append(W("arm_r", _painted(L.tube(top, bot, 0.016, 6), WOOD, var=0.2, ao=0.0, seed=7)))
    hh = L.prim("cube", loc=bot + Vector((0.0, -0.0, -0.02)), scale=(0.035, 0.085, 0.035))
    L.bevel(hh, 0.006, 1)
    parts.append(W("arm_r", _painted(hh, IRON, var=0.2, ao=0.0, top=0.5, seed=8)))
    del ax
    # head: bald, sun-browned pate, heavy grey brows, a full grey beard, a gruff but kind look
    c = Vector((0.0, -0.05, 1.71))
    s = Vector((0.142, 0.15, 0.158))
    pts = _head(parts, c, s, SM_SKIN, seed=30, nose="round", nose_s=1.15, brow=SM_BEARD_DARK, brow_w=1.65,
                brow_tilt=-0.3, brow_arch=0.6, mouth="thin", cheeks=0.75, jaw=1.06, chin=0.0, iris=IRIS_BLUE,
                lids=0.2, age=0.35, muzzle=1.15)
    face = pts["face"]
    # a fringe of short grey hair round the back of the head (the pate stays bare)
    _hair(parts, face, SM_BEARD, SM_BEARD_DARK, [(1.0, -0.02), (1.6, -0.2), (math.pi, -0.45)],
          top=[(1.0, 0.08), (1.6, 0.24), (math.pi, 0.32)], phi=(1.0, math.tau - 1.0), out=0.006, crown=0.0, tuft=0.004,
          seed=31)
    beard, _, _ = _shell(face, [(0.0, -0.99)], top=[(0.0, -0.62), (0.3, -0.5), (0.55, -0.3), (0.9, -0.08), (1.3, 0.0),
                                                   (1.62, 0.04)],
                         phi=(-1.62, 1.62), out=lambda ph, w: 0.006 + 0.062 * _s01((-w - 0.45) / 0.5) *
                         (0.35 + 0.65 * max(0.0, math.cos(ph))), crown=0.0, n=26, m=9, tuck=0.003, lumps=0.006,
                         seed=32, name="beard")
    L.jitter(beard, 0.006, 9.0, 32)
    _painted(beard, SM_BEARD, var=0.14, ao=0.0, top=0.25, seed=33, hue_shift=SM_BEARD_DARK)
    _tint(beard, lambda co, nr: (1.0 - 0.15 * max(0.0, math.sin(co.x * 160.0 + _n(co, 9.0) * 3.0)), SM_BEARD_LIGHT,
                                 0.35 * max(0.0, nr.z) + 0.2 * max(0.0, _n(co, 14.0, 2.0))))
    parts.append(W("head", beard))
    for sx in (-1, 1):   # moustache: two soft lobes from under the nose
        mp = [face.pt(sx * 0.02, -0.31, 0.012), face.pt(sx * 0.15, -0.36, 0.016), face.pt(sx * 0.28, -0.47, 0.012)]
        mo = sweep(mp, [0.013, 0.017, 0.01], n=8, flat=0.75, name="moustache",
                   normals=[face.nrm(sx * 0.02, -0.31), face.nrm(sx * 0.15, -0.36), face.nrm(sx * 0.28, -0.47)])
        L.jitter(mo, 0.002, 30.0, 34 + sx)
        parts.append(W("head", _painted(mo, SM_BEARD_LIGHT, var=0.16, ao=0.0, top=0.3, seed=34 + sx, hue_shift=SM_BEARD)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.86)
    L.smooth(mesh, 55)
    joints = _joints(hip, waist, Vector((0, -0.01, 1.57)), Vector((0, -0.04, 1.9)), sh, wr, 0.13)

    def work(t: float) -> dict:
        """48 frames = 1.6 s: two hammer strikes on the anvil in front of him."""
        up = {"arm_r": (-120.0, -6.0, 10.0), "spine": (2.0, 0.0, 6.0), "head": (6.0, 0.0, 0.0),
              "arm_l": (-40.0, 10.0, -10.0), "hips": (0, 0, 0)}
        hit = {"arm_r": (-46.0, -4.0, 4.0), "spine": (14.0, 0.0, -2.0), "head": (10.0, 0.0, 0.0),
               "arm_l": (-46.0, 10.0, -10.0), "hips": (2.0, 0, 0, 0, 0, -0.01)}
        keys = [(0.0, up), (0.18, hit), (0.3, up), (0.5, up), (0.68, hit), (0.8, up)]
        return rig.add(rig.keyed(t, keys), {"leg_l": (-8.0, 0, 0), "leg_r": (6.0, 0, 0), "feet": {"leg_l": 0.0, "leg_r": 0.0}})
    talk_keys = [
        (0.0, {"arm_l": (-24.0, 6.0, -10.0), "head": (2.0, 0.0, 2.0)}),
        (0.3, {"arm_l": (-44.0, 10.0, -20.0), "head": (-2.0, 0.0, -2.0), "spine": (1.0, 0.0, 2.0)}),
        (0.6, {"arm_l": (-20.0, 4.0, -6.0), "head": (3.0, 0.0, 3.0)}),
    ]
    actions = (
        ("idle-loop", 84, _idle(1.6, 0.8, 0.7)),
        ("walk-loop", 22, _walk(24.0, 0.05, 14.0, 0.016, 3.5, 3.0, 2.0, lambda t: {"arm_r": (0.0, 4.0, 0.0)})),
        ("talk-loop", 72, _talk(talk_keys, 1.4)),
        ("work-loop", 48, work),
    )
    _rigged("ph_chr_v_smith", mesh, joints, actions)


# ======================================================================================================
# Theres Mangold - the grocer
# ======================================================================================================

GR_BODICE = L.hexc("#4E4A3C")
GR_SKIRT = L.hexc("#7A6A48")
GR_SKIRT_DARK = L.hexc("#5C5038")
GR_STRIPE = L.hexc("#5A4A34")
GR_PROTECT = L.hexc("#6B6A62")
GR_BONNET = L.hexc("#D3CBB8")
GR_HAIR = L.hexc("#6E5236")
GR_HAIR_DARK = L.hexc("#4A3624")
GR_APRON = L.hexc("#9A9078")


def grocer():
    L.reset(7301)
    parts = []
    prof = Prof(((0.05, 0.25, 0.23, 0.012), (0.25, 0.24, 0.22, 0.01), (0.5, 0.222, 0.2, 0.004), (0.75, 0.2, 0.17, 0.0),
                 (0.9, 0.17, 0.142, 0.0), (0.97, 0.152, 0.126, -0.004), (1.05, 0.156, 0.13, -0.01),
                 (1.15, 0.17, 0.142, -0.014), (1.23, 0.172, 0.138, -0.01), (1.28, 0.16, 0.122, -0.004),
                 (1.32, 0.12, 0.1, -0.004), (1.35, 0.065, 0.06, -0.008)))
    waist = 0.97
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.085, BOOT, length=0.12, width=0.056, height=0.05, toe=-0.075, pointed=0.12, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.085, 0.0, 0.04), (sx * 0.088, 0.0, 0.5), (sx * 0.09, 0.0, 0.88)],
                  [0.044, 0.048, 0.06], BLACK, seed=12)
    skirt = _body(Prof(prof.rings[:6]), GR_SKIRT, GR_SKIRT_DARK, n=48, seed=1, fold=0.011, cap=False)

    def stripes(co, nr):
        a = math.atan2(co.y, co.x)
        on = math.sin(a * 12.0) > 0.3
        return (0.8 if on else 1.0), GR_STRIPE, (0.55 if on else 0.0)
    _tint(skirt, stripes)
    parts.append(W("hips", skirt))
    top = _body(Prof(prof.rings[5:]), GR_BODICE, BLACK, n=20, seed=2, fold=0.0, var=0.12)
    parts.append(W("spine", top))
    # half apron, plain linen-brown, with a pocket for the pencil stubs
    ap = _sheet_on(prof, [0] * 6, [0.38, 0.55, 0.72, 0.86, 0.96], 0.01, GR_APRON, LINEN_SHADE, seed=3,
                   xfn=lambda z: (-0.15 - 0.05 * (0.96 - z), 0.15 + 0.05 * (0.96 - z)))
    parts.append(W("hips", ap))
    pk = prof.surf(0.08, 0.7, -1, 0.022)
    parts.append(W("hips", L.part("cube", L.scale_c(GR_APRON, 0.85), loc=pk, scale=(0.05, 0.006, 0.045), rot=(-8, 0, 0),
                                  paint_kw={"ao": 0.1})))
    parts.append(W("hips", _ring_band(prof, waist, 0.012, GR_STRIPE, out=0.01, flat=0.5, seed=4)))
    # a little white fichu over the shoulders, crossed on the chest
    for sx in (-1, 1):
        pts = [prof.surf(sx * 0.06, 1.33, 1, 0.01), Vector((sx * 0.15, -0.02, 1.31)), prof.surf(sx * 0.1, 1.24, -1, 0.012),
               prof.surf(-sx * 0.03, 1.12, -1, 0.012)]
        parts.append(W("spine", _painted(sweep(pts, [0.03, 0.035, 0.032, 0.02], n=6, flat=0.3, name="fichu"),
                                         GR_BONNET, var=0.08, ao=0.1, top=0.3, seed=5 + sx)))
    # the eyeglass on its cord, hanging at her chest
    gc = prof.surf(0.05, 1.08, -1, 0.02)
    parts.append(W("spine", L.part("torus", BRASS, loc=gc, rot=(90, 0, 0), major_radius=0.02, minor_radius=0.0035,
                                   major_segments=10, minor_segments=4, paint_kw={"ao": 0.0, "top": 0.4})))
    parts.append(W("spine", L.part("cyl", L.hexc("#4A4E4C"), loc=gc + Vector((0, -0.001, 0)), rot=(90, 0, 0), radius=0.017,
                                   depth=0.003, vertices=10, paint_kw={"ao": 0.0})))
    parts.append(W("spine", _painted(sweep([gc + Vector((0, 0, 0.02)), prof.surf(0.07, 1.2, -1, 0.012),
                                            Vector((0.08, -0.04, 1.34))], 0.0025, n=4, name="cord"), BLACK, ao=0.0)))
    # arms with grey sleeve protectors over the forearms
    sh = {sx: Vector((sx * 0.18, -0.005, 1.29)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.225, 0.0, 1.06)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.24, -0.08, 0.86)) for sx in (-1, 1)}
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        _arm(parts, sx, sh[sx], el[sx], wr[sx], GR_BODICE, BLACK, r=(0.05, 0.048, 0.044, 0.04), skin=SKIN_PALE, seed=20 + sx * 3,
             hand_size=0.95)
        pr = sweep([el[sx] + (el[sx] - sh[sx]).normalized() * 0.01, el[sx].lerp(wr[sx], 0.5), wr[sx]],
                   [0.056, 0.056, 0.05], n=10, name="protector")
        _painted(pr, GR_PROTECT, var=0.12, ao=0.1, top=0.2, seed=24 + sx)
        _tint(pr, lambda co, nr: (0.8 if abs(co.z - 0.87) < 0.01 or abs(co.z - 1.05) < 0.01 else 1.0, None, 0.0))
        parts.append(W(bone, pr))
    # head: slim, bright and quick, a frilled bonnet tied under the chin, the hair parted under it
    c = Vector((0.0, -0.03, 1.47))
    s = Vector((0.128, 0.132, 0.142))
    pts = _head(parts, c, s, SKIN_PALE, seed=30, nose="straight", nose_s=0.95, brow=GR_HAIR, brow_w=0.85, brow_tilt=0.25,
                brow_arch=1.3, mouth="smile", smile=0.85, cheeks=0.6, jaw=0.88, chin=0.04, iris=IRIS_HAZEL, lids=0.12,
                ears=False)
    face = pts["face"]
    _hair(parts, face, GR_HAIR, GR_HAIR_DARK, [(0.0, 0.44), (0.6, 0.36), (1.0, 0.12), (1.3, -0.12), (math.pi, -0.45)],
          out=0.005, crown=0.003, part_u=0.0, seed=31)
    bk = [(0.0, 0.64), (0.55, 0.56), (0.95, 0.18), (1.2, -0.38), (1.45, -0.62), (2.0, -0.62), (math.pi, -0.5)]
    _, edge = _cloth_cover(parts, face, GR_BONNET, LINEN_SHADE, bk,
                           out=lambda ph, w: 0.014 + 0.035 * max(0.0, -math.cos(ph)) * _s01((w + 0.1) / 0.8),
                           crown=0.01, folds=9.0, seed=32, name="bonnet")
    # frill round the face: a pleated ruffle standing round the bonnet's edge
    _frill(parts, face, edge, GR_BONNET, 0.019 * face.k, 1.5, seed=33)
    bow = face.world(Face.around(0.0, -0.97), 0.02)
    for sx in (-1, 1):  # ribbons tied under the chin
        p0 = face.world(Face.around(sx * 1.38, -0.55), 0.016)
        p1 = face.world(Face.around(sx * 1.0, -0.86), 0.012)
        parts.append(W("head", _painted(sweep([p0, p1, bow + Vector((sx * 0.01, 0, 0))], 0.0095, n=4, flat=0.3,
                                              name="ribbon"), GR_BONNET, ao=0.0, seed=34)))
        parts.append(W("head", _ell(GR_BONNET, bow + Vector((sx * 0.02, -0.004, -0.004)), (0.02, 0.008, 0.013),
                                    rot=(0, sx * 25, 0), seg=8, rings=5, seed=35)))
    parts.append(W("head", _ell(GR_BONNET, bow, (0.01, 0.009, 0.01), seg=6, rings=4, seed=35)))
    # pencil behind the right ear (over the bonnet)
    pe = face.world(Face.around(-1.62, 0.02), 0.024)
    parts.append(W("head", _painted(L.tube(pe + Vector((0, -0.065, 0.028)), pe + Vector((0, 0.06, -0.022)), 0.006, 6),
                                    L.hexc("#8A7448"), ao=0.0, var=0.1, seed=36)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.62)
    L.smooth(mesh, 55)
    joints = _joints(0.84, waist, Vector((0, -0.01, 1.34)), Vector((0, -0.03, 1.66)), sh, wr, 0.09)

    def work(t: float) -> dict:
        """60 frames = 2 s: weighs and counts over the counter - reaches forward, taps, nods."""
        a = {"arm_r": (-58.0, -6.0, 8.0), "arm_l": (-40.0, 8.0, -6.0), "spine": (10.0, 0.0, 2.0), "head": (8.0, 0.0, 0.0)}
        b = {"arm_r": (-46.0, -10.0, 16.0), "arm_l": (-52.0, 6.0, -10.0), "spine": (12.0, 0.0, -3.0), "head": (14.0, 0.0, -4.0)}
        c_ = {"arm_r": (-62.0, -2.0, 4.0), "arm_l": (-38.0, 10.0, -4.0), "spine": (9.0, 0.0, 3.0), "head": (6.0, 0.0, 6.0)}
        return rig.add(rig.keyed(t, [(0.0, a), (0.3, b), (0.6, c_)]), {"feet": {"leg_l": 0.0, "leg_r": 0.0}})
    talk_keys = [
        (0.0, {"arm_r": (-38.0, -10.0, 18.0), "arm_l": (-30.0, 10.0, -14.0), "head": (2.0, 3.0, 4.0)}),
        (0.2, {"arm_r": (-50.0, -16.0, 30.0), "arm_l": (-34.0, 12.0, -18.0), "head": (-2.0, -3.0, -3.0)}),
        (0.45, {"arm_r": (-36.0, -12.0, 22.0), "arm_l": (-44.0, 14.0, -24.0), "head": (3.0, 2.0, 6.0)}),
        (0.7, {"arm_r": (-54.0, -6.0, 12.0), "arm_l": (-30.0, 8.0, -12.0), "head": (-1.0, -4.0, -5.0)}),
    ]
    actions = (
        ("idle-loop", 60, _idle(1.0, 1.0, 1.6)),
        ("walk-loop", 16, _walk(26.0, 0.045, 18.0, 0.016, 3.0, 5.0, 3.0)),
        ("talk-loop", 60, _talk(talk_keys, 1.0)),
        ("work-loop", 60, work),
    )
    _rigged("ph_chr_v_grocer", mesh, joints, actions)


# ======================================================================================================
# Pfarrer Ambrosius Lenz - the priest
# ======================================================================================================

PR_CASSOCK = L.hexc("#2A282C")
PR_CASSOCK_DARK = L.hexc("#1C1B1E")
PR_CASSOCK_SHEEN = L.hexc("#45424A")
PR_BAND = L.hexc("#DCD5C6")
PR_BOOK = L.hexc("#4E3A2C")
PR_HAIR = L.hexc("#D2CCC0")
PR_HAIR_DARK = L.hexc("#A8A296")


def priest():
    L.reset(7401)
    parts = []
    prof = Prof(((0.05, 0.27, 0.25, 0.0), (0.25, 0.27, 0.252, -0.006), (0.5, 0.275, 0.262, -0.02),
                 (0.72, 0.29, 0.28, -0.04), (0.88, 0.3, 0.292, -0.05), (1.0, 0.296, 0.288, -0.05),
                 (1.1, 0.282, 0.27, -0.04), (1.2, 0.26, 0.236, -0.024), (1.27, 0.232, 0.198, -0.01),
                 (1.32, 0.18, 0.152, -0.004), (1.36, 0.1, 0.09, -0.006)))
    waist = 0.98
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.1, BLACK_DARK, length=0.13, width=0.064, height=0.054, toe=-0.08, buckle=BRASS,
              seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.1, 0.0, 0.04), (sx * 0.105, 0.0, 0.5), (sx * 0.105, 0.0, 0.88)],
                  [0.05, 0.055, 0.07], BLACK, seed=12)
    cas = _body(prof, PR_CASSOCK, PR_CASSOCK_DARK, n=26, seed=1, fold=0.01, fold_k=6.0)
    _tint(cas, lambda co, nr: (1.0, PR_CASSOCK_SHEEN, 0.35 * max(0.0, nr.z) + 0.2 * max(0.0, -nr.y) *
                               max(0.0, 1.0 - abs(co.z - 0.95) / 0.2)))
    parts.append(rig.weight_split_z(cas, waist, "hips", "spine"))
    # row of small cloth buttons down the front
    for k in range(16):
        z = 0.32 + k * 0.064
        if z > 1.33:
            break
        p = prof.surf(0.0, z, -1, 0.004)
        parts.append(W("hips" if z < waist else "spine", _ell(PR_CASSOCK_SHEEN, p, (0.011, 0.006, 0.011), seg=6,
                                                              rings=4, ao=0.0, top=0.4)))
    # the cincture (sash) with hanging ends
    parts.append(W("hips", _ring_band(prof, waist, 0.026, PR_CASSOCK_DARK, out=0.008, flat=0.4, seed=4)))
    for dx in (-0.03, 0.02):
        p0 = prof.surf(0.14, waist - 0.02, -1, 0.012) + Vector((dx, 0, 0))
        parts.append(W("hips", _painted(sweep([p0, p0 + Vector((0.01, -0.02, -0.22)), p0 + Vector((0.016, -0.03, -0.42))],
                                              [0.026, 0.026, 0.024], n=5, flat=0.3, name="sash"), PR_CASSOCK_DARK,
                                        ao=0.0, var=0.1, seed=5)))
    # white preaching bands under the chin
    for sx in (-1, 1):
        b0 = prof.surf(sx * 0.018, 1.33, -1, 0.006)
        parts.append(W("spine", _painted(sweep([b0, b0 + Vector((sx * 0.008, -0.022, -0.1))], [0.022, 0.026], n=4,
                                               flat=0.25, name="band"), PR_BAND, ao=0.0, var=0.04, top=0.3, seed=6)))
    parts.append(W("spine", _painted(sweep([Vector((math.cos(a) * 0.1, -0.008 + math.sin(a) * 0.09, 1.355))
                                            for a in (math.tau * k / 12 for k in range(12))], 0.014, n=5, closed=True,
                                           name="collar"), PR_BAND, ao=0.0, var=0.04, seed=7)))
    # arms: right hangs, left holds the breviary against the belly
    sh = {sx: Vector((sx * 0.24, -0.01, 1.28)) for sx in (-1, 1)}
    el = {1: Vector((0.31, -0.04, 1.04)), -1: Vector((-0.3, -0.02, 1.04))}
    wr = {1: Vector((0.14, -0.3, 1.02)), -1: Vector((-0.31, -0.08, 0.82))}
    for sx in (-1, 1):
        _arm(parts, sx, sh[sx], el[sx], wr[sx], PR_CASSOCK, PR_CASSOCK_DARK, r=(0.075, 0.07, 0.068, 0.078),
             cuff=PR_CASSOCK_DARK, cuff_r=0.08, skin=SKIN, seed=20 + sx * 3, hand_size=1.05, grip=(sx > 0))
    # the breviary: a thick little book with a ribbon, pressed upright to his belly
    bc = Vector((0.08, -0.31, 1.0))
    book = L.prim("cube", loc=bc, scale=(0.08, 0.03, 0.105), rot=(0, 0, 10))
    L.bevel(book, 0.006, 1)
    parts.append(W("arm_l", _painted(book, PR_BOOK, var=0.16, ao=0.1, top=0.3, seed=8)))
    pages = L.prim("cube", loc=bc + Vector((0.004, 0.0, 0.0)), scale=(0.074, 0.024, 0.1), rot=(0, 0, 10))
    parts.append(W("arm_l", _painted(pages, L.hexc("#CFC3A3"), var=0.06, ao=0.0, seed=9)))
    parts.append(W("arm_l", _painted(sweep([bc + Vector((0.0, -0.01, -0.1)), bc + Vector((0.004, -0.03, -0.17))], 0.004,
                                           n=4, flat=0.3, name="ribbon"), L.hexc("#7A5A3A"), ao=0.0)))
    # head: round, rosy and jovial, a fringe of white hair, a soft black biretta
    c = Vector((0.0, -0.04, 1.49))
    s = Vector((0.15, 0.142, 0.15))
    pts = _head(parts, c, s, SKIN, seed=30, nose="round", nose_s=1.1, brow=PR_HAIR, brow_w=1.25, brow_tilt=0.6,
                brow_arch=1.2, mouth="smile", smile=1.1, cheeks=1.0, jaw=1.1, chin=0.0, muzzle=1.2, iris=IRIS_BLUE,
                lids=0.2, age=0.45)
    face = pts["face"]
    _hair(parts, face, PR_HAIR, PR_HAIR_DARK, [(0.0, 0.5), (0.6, 0.44), (1.1, 0.16), (1.42, -0.02), (1.8, -0.24),
                                               (math.pi, -0.45)], out=0.006, crown=0.0, tuft=0.005, seed=31)
    bz = c.z + s.z * 0.6
    bir = loft([(bz, s.x + 0.012, s.y + 0.01, 0.0, c.y), (bz + 0.035, s.x + 0.024, s.y + 0.02, 0.0, c.y),
                (bz + 0.07, s.x + 0.016, s.y + 0.014, 0.0, c.y), (bz + 0.085, s.x - 0.02, s.y - 0.022, 0.0, c.y)],
               n=18, p=3.0, name="biretta")
    L.jitter(bir, 0.004, 8.0, 32)
    _painted(bir, PR_CASSOCK, var=0.12, ao=0.2, top=0.3, seed=32, hue_shift=PR_CASSOCK_SHEEN)
    parts.append(W("head", bir))
    parts.append(W("head", _ell(PR_CASSOCK_DARK, Vector((0, c.y, bz + 0.095)), (0.025, 0.025, 0.018), seg=8, rings=5,
                                seed=33)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.66)
    L.smooth(mesh, 55)
    joints = _joints(0.86, waist, Vector((0, -0.02, 1.36)), Vector((0, -0.04, 1.66)), sh, wr, 0.1)
    talk_keys = [
        (0.0, {"arm_r": (-34.0, -6.0, 16.0), "head": (2.0, 0.0, 4.0), "spine": (-2.0, 0.0, 0.0)}),
        (0.25, {"arm_r": (-70.0, -14.0, 34.0), "head": (-5.0, -3.0, -2.0), "spine": (-4.0, 0.0, -4.0)}),
        (0.5, {"arm_r": (-46.0, -24.0, 20.0), "head": (2.0, 4.0, 6.0), "spine": (-2.0, 0.0, 2.0)}),
        (0.75, {"arm_r": (-64.0, -8.0, 30.0), "head": (-4.0, 0.0, -4.0), "spine": (-3.0, 0.0, -2.0)}),
    ]
    actions = (
        ("idle-loop", 84, _idle(1.5, 0.6, 1.0, lambda t: {"head": (0.0, 2.0 * math.sin(rig.TAU * t), 0.0)})),
        ("walk-loop", 22, _walk(18.0, 0.035, 10.0, 0.012, 4.0, 3.0, -1.0, lambda t: {"arm_l": (2.0 * math.sin(rig.TAU * t), 0, 0)})),
        ("talk-loop", 72, _talk(talk_keys, 1.4)),
    )
    _rigged("ph_chr_v_priest", mesh, joints, actions)


# ======================================================================================================
# Schultheiss Gottlieb Fenner - the mayor
# ======================================================================================================

MY_COAT = L.hexc("#3E4A3A")
MY_COAT_DARK = L.hexc("#2C352A")
MY_COAT_LIGHT = L.hexc("#55624E")
MY_WAIST = L.hexc("#8C7E5E")
MY_BREECH = L.hexc("#3A3630")
MY_STOCK = L.hexc("#8A877E")
MY_HAIR = L.hexc("#9E9890")
MY_HAIR_DARK = L.hexc("#7A756E")
MY_STAFF = L.hexc("#4A3A2C")


def mayor():
    L.reset(7501)
    parts = []
    hip = 0.92
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.09
        _shoe(parts, leg, x0, BLACK_DARK, length=0.14, width=0.058, height=0.05, toe=-0.08, pointed=0.08,
              buckle=BRASS, seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.04), (sx * 0.092, -0.004, 0.3), (sx * 0.094, 0.0, 0.52)],
                  [0.042, 0.05, 0.05], MY_STOCK, seed=12)
        _leg_tube(parts, leg, [(sx * 0.094, 0.0, 0.48), (sx * 0.098, -0.006, 0.66), (sx * 0.1, 0.0, hip)],
                  [0.058, 0.064, 0.074], MY_BREECH, n=10, seed=13)
        parts.append(W(leg, L.part("torus", MY_BREECH, loc=(sx * 0.094, 0.0, 0.5), major_radius=0.056, minor_radius=0.012,
                                   major_segments=10, minor_segments=4, paint_kw={"ao": 0.0})))
        parts.append(W(leg, L.part("cube", BRASS, loc=(sx * 0.14, -0.01, 0.5), scale=(0.008, 0.012, 0.012),
                                   paint_kw={"ao": 0.0, "top": 0.5})))
    # buff waistcoat under the coat
    wprof = Prof(((0.74, 0.17, 0.13, -0.004), (0.9, 0.175, 0.135, -0.01), (1.02, 0.17, 0.13, -0.012),
                  (1.16, 0.18, 0.138, -0.012), (1.3, 0.186, 0.135, -0.006), (1.38, 0.15, 0.115, 0.0),
                  (1.43, 0.08, 0.07, -0.004)))
    wc = _body(wprof, MY_WAIST, L.scale_c(MY_WAIST, 0.8), n=18, seed=2, fold=0.0, var=0.1)
    parts.append(rig.weight_split_z(wc, 0.98, "hips", "spine"))
    for k in range(6):
        p = wprof.surf(0.0, 0.84 + k * 0.08, -1, 0.004)
        parts.append(W("hips" if p.z < 0.98 else "spine", _ell(BRASS, p, (0.009, 0.005, 0.009), seg=6, rings=4, ao=0.0, top=0.5)))
    # the old-fashioned skirted coat (Rock), open in front from the chest down, to the knee
    prof = Prof(((0.48, 0.26, 0.22, 0.03), (0.6, 0.24, 0.2, 0.025), (0.75, 0.215, 0.172, 0.016), (0.9, 0.198, 0.156, 0.008),
                 (1.0, 0.19, 0.15, 0.0), (1.12, 0.196, 0.152, 0.0), (1.25, 0.204, 0.15, 0.004), (1.35, 0.2, 0.14, 0.006),
                 (1.41, 0.17, 0.124, 0.006), (1.45, 0.1, 0.085, 0.004)))
    coat = _body(prof, MY_COAT, MY_COAT_DARK, n=26, seed=3, fold=0.012, fold_top=1.0, part_front=0.0)
    bm = bmesh.new()
    bm.from_mesh(coat.data)
    kill = []
    for f in bm.faces:   # the coat stands open over the waistcoat: front gap below the chest
        cc = f.calc_center_median()
        if cc.y < -0.06 and abs(cc.x) < 0.06 + 0.12 * max(0.0, (1.24 - cc.z) / 0.76) and cc.z < 1.26:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(coat.data)
    bm.free()
    _thicken(coat, 0.012)
    _tint(coat, lambda co, nr: (1.0, MY_COAT_LIGHT, 0.3 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(coat, 0.98, "hips", "spine"))
    for sx in (-1, 1):   # brass buttons on both front edges, pocket flaps
        for k in range(5):
            z = 0.86 + k * 0.085
            x = sx * (0.07 + 0.12 * max(0.0, (1.24 - z) / 0.76))
            p = prof.surf(x, z, -1, 0.012)
            parts.append(W("hips" if z < 0.98 else "spine", _ell(BRASS, p, (0.013, 0.007, 0.013), seg=8, rings=4, ao=0.0,
                                                               top=0.5)))
        fl = prof.surf(sx * 0.15, 0.82, -1, 0.012)
        parts.append(W("hips", L.part("cube", MY_COAT_DARK, loc=fl, scale=(0.07, 0.008, 0.03), rot=(0, 0, sx * -30),
                                      paint_kw={"ao": 0.1})))
    # white neckcloth (stock)
    parts.append(W("spine", _painted(sweep([Vector((math.cos(a) * 0.085, -0.004 + math.sin(a) * 0.075, 1.44))
                                            for a in (math.tau * k / 12 for k in range(12))], 0.026, n=5, closed=True,
                                           name="stock"), LINEN_WHITE, ao=0.0, var=0.05, seed=4)))
    parts.append(W("spine", _ell(LINEN_WHITE, (0.0, -0.09, 1.4), (0.035, 0.02, 0.045), seg=8, rings=5, seed=5)))
    # arms: long narrow sleeves with turned-back cuffs; right hand grips the staff
    sh = {sx: Vector((sx * 0.205, 0.0, 1.41)) for sx in (-1, 1)}
    el = {1: Vector((0.25, 0.01, 1.14)), -1: Vector((-0.25, -0.02, 1.14))}
    wr = {1: Vector((0.26, -0.05, 0.9)), -1: Vector((-0.27, -0.14, 0.94))}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], MY_COAT, MY_COAT_DARK, r=(0.054, 0.05, 0.046, 0.046),
                         cuff=MY_COAT_LIGHT, cuff_r=0.066, skin=SKIN_PALE, seed=20 + sx * 3, hand_size=0.98, grip=(sx < 0))
    # signet ring on the left hand
    parts.append(W("arm_l", _ell(L.hexc("#A08240"), hands[1] + Vector((-0.02, -0.03, -0.012)), (0.008, 0.008, 0.008), seg=6,
                                 rings=4, ao=0.0, top=0.5)))
    # the staff of office: dark wood, brass knob, iron ferrule on the ground
    h = hands[-1]
    st_top = Vector((h.x - 0.005, h.y - 0.01, 1.32))
    st_bot = Vector((h.x - 0.02, h.y - 0.03, 0.0))
    parts.append(W("arm_r", _painted(L.tube(st_bot + Vector((0, 0, 0.05)), st_top, 0.016, 7, r_end=0.019), MY_STAFF,
                                     var=0.2, ao=0.0, top=0.3, seed=6)))
    parts.append(W("arm_r", L.part("sphere", BRASS, loc=st_top + Vector((0, 0, 0.03)), radius=0.035, segments=10, ring_count=6,
                                   paint_kw={"ao": 0.0, "top": 0.5})))
    parts.append(W("arm_r", L.part("cyl", IRON, loc=st_bot + Vector((0, 0, 0.03)), radius=0.016, depth=0.06, vertices=7,
                                   paint_kw={"ao": 0.0})))
    # head: long, gaunt, dignified and a little severe; grey hair combed back into a queue with a black bow
    c = Vector((0.0, -0.03, 1.63))
    s = Vector((0.118, 0.13, 0.155))
    pts = _head(parts, c, s, SKIN_PALE, seed=30, nose="hook", nose_s=1.0, brow=MY_HAIR_DARK, brow_w=1.0, brow_tilt=-0.25,
                brow_arch=0.8, mouth="kind", smile=0.35, lip=LIP_PALE, cheeks=0.3, jaw=0.84, chin=0.06, age=0.75,
                lids=0.22, iris=IRIS_GREY, muzzle=0.8)
    face = pts["face"]
    _hair(parts, face, MY_HAIR, MY_HAIR_DARK, [(0.0, 0.62), (0.35, 0.56), (0.7, 0.36), (1.1, 0.14), (1.45, 0.04),
                                               (1.8, -0.3), (math.pi, -0.5)], out=0.007, crown=0.008, comb="back",
          tuft=0.0, seed=31)
    for sx in (-1, 1):   # side rolls (old fashion) over the ears
        rp = [face.world(Face.around(sx * a, w), 0.012) for a, w in ((2.1, 0.0), (1.85, -0.04), (1.6, -0.1))]
        parts.append(W("head", _painted(sweep(rp, [0.014, 0.018, 0.015], n=8, name="roll"), MY_HAIR, var=0.12, ao=0.1,
                                        seed=32, hue_shift=MY_HAIR_DARK)))
    q0 = face.world(Face.around(math.pi, -0.35), 0.008)
    parts.append(W("head", _painted(sweep([q0, q0 + Vector((0, 0.03, -0.08)), q0 + Vector((0, 0.03, -0.2))], [0.022, 0.018, 0.01],
                                          n=7, name="queue"), MY_HAIR, var=0.15, ao=0.0, top=0.2, seed=33)))
    bw = q0 + Vector((0, 0.02, -0.04))
    for sx in (-1, 1):
        parts.append(W("head", _ell(BLACK, bw + Vector((sx * 0.025, 0.005, 0.0)), (0.026, 0.01, 0.018), seg=8, rings=5,
                                    rot=(0, sx * 20, 0), seed=34)))
    parts.append(W("head", _ell(BLACK, bw, (0.012, 0.012, 0.014), seg=6, rings=4, seed=35)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.8)
    L.smooth(mesh, 55)
    joints = _joints(hip, 0.98, Vector((0, -0.01, 1.45)), Vector((0, -0.03, 1.82)), sh, wr, 0.095)
    talk_keys = [
        (0.0, {"arm_l": (-30.0, 8.0, -14.0), "head": (3.0, 0.0, -2.0), "spine": (-2.0, 0.0, 0.0)}),
        (0.3, {"arm_l": (-50.0, 12.0, -26.0), "head": (-2.0, 3.0, -4.0), "spine": (-3.0, 0.0, 2.0)}),
        (0.6, {"arm_l": (-36.0, 18.0, -10.0), "head": (2.0, -2.0, 2.0), "spine": (-1.0, 0.0, -2.0)}),
        (0.82, {"arm_l": (-46.0, 8.0, -24.0), "head": (0.0, 0.0, 0.0), "spine": (-2.0, 0.0, 0.0)}),
    ]
    actions = (
        ("idle-loop", 84, _idle(0.9, 0.5, 0.6, lambda t: {"spine": (-1.5, 0, 0)})),
        ("walk-loop", 22, _walk(22.0, 0.04, 6.0, 0.012, 1.5, 2.0, -1.5, lambda t: {"arm_r": (-4.0, 0.0, 0.0)})),
        ("talk-loop", 72, _talk(talk_keys, 0.9)),
    )
    _rigged("ph_chr_v_mayor", mesh, joints, actions)


# ======================================================================================================
# Severin Quast - the surgeon
# ======================================================================================================

SU_COAT = L.hexc("#33302E")
SU_COAT_DARK = L.hexc("#232120")
SU_COAT_SHEEN = L.hexc("#4A4642")
SU_TROUSER = L.hexc("#4A4740")
SU_WAX = L.hexc("#57523E")         # waxed cloth: dull olive-ochre with a sheen
SU_WAX_SHEEN = L.hexc("#77725A")
SU_HAIR = L.hexc("#4A3828")
SU_HAIR_DARK = L.hexc("#2E231A")
SU_BAG = L.hexc("#5A3E2C")
SU_BAG_DARK = L.hexc("#3E2A1E")


def surgeon():
    L.reset(7601)
    parts = []
    hip = 0.9
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.09
        _shoe(parts, leg, x0, BLACK_DARK, length=0.14, width=0.058, height=0.052, toe=-0.08, pointed=0.06, shaft=0.14,
              shaft_r=0.052, seed=10 + sx)
        _leg_tube(parts, leg, [(x0, 0.0, 0.1), (sx * 0.092, -0.004, 0.45), (sx * 0.096, 0.0, hip)],
                  [0.055, 0.058, 0.072], SU_TROUSER, n=10, seed=12)
    prof = Prof(((0.5, 0.235, 0.2, 0.028), (0.62, 0.22, 0.185, 0.02), (0.78, 0.2, 0.16, 0.012), (0.92, 0.186, 0.148, 0.006),
                 (0.98, 0.178, 0.142, 0.0), (1.08, 0.184, 0.146, -0.002), (1.2, 0.196, 0.15, 0.0), (1.32, 0.2, 0.144, 0.004),
                 (1.38, 0.17, 0.124, 0.004), (1.42, 0.1, 0.085, 0.002)))
    waist = 0.98
    coat = _body(prof, SU_COAT, SU_COAT_DARK, n=26, seed=3, fold=0.01, fold_top=0.98, part_front=0.32, part_w=0.5)
    _tint(coat, lambda co, nr: (1.0, SU_COAT_SHEEN, 0.3 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(coat, waist, "hips", "spine"))
    # lapels and the front edge
    for sx in (-1, 1):
        lp = [prof.surf(sx * 0.02, 1.0, -1, 0.008), prof.surf(sx * 0.07, 1.18, -1, 0.01), prof.surf(sx * 0.11, 1.33, -1, 0.006)]
        parts.append(W("spine", _painted(sweep(lp, [0.016, 0.03, 0.022], n=5, flat=0.35, name="lapel",
                                               normals=[prof.normal(q.x, q.z) for q in lp]), SU_COAT_SHEEN, ao=0.0,
                                         var=0.1, seed=4)))
        for k in range(3):
            p = prof.surf(sx * 0.055, 1.0 + k * 0.07, -1, 0.012)
            parts.append(W("spine", _ell(BLACK_SHEEN, p, (0.01, 0.006, 0.01), seg=6, rings=4, ao=0.0, top=0.4)))
    # dark waistcoat V with a white shirt front and a white neckcloth
    parts.append(W("spine", _painted(L.prim("cone", loc=prof.surf(0.0, 1.27, -1, 0.002) + Vector((0, 0.01, 0.0)), radius1=0.06,
                                            radius2=0.0, depth=0.16, vertices=3, rot=(180, 0, 0), scale=(1.0, 0.25, 1.0)),
                                     LINEN_WHITE, ao=0.0, var=0.05)))
    parts.append(W("spine", _painted(sweep([Vector((math.cos(a) * 0.082, -0.004 + math.sin(a) * 0.072, 1.415))
                                            for a in (math.tau * k / 12 for k in range(12))], 0.028, n=5, closed=True,
                                           name="neckcloth"), LINEN_WHITE, ao=0.0, var=0.05, seed=5)))
    parts.append(W("spine", _ell(LINEN_WHITE, (0.0, -0.085, 1.38), (0.04, 0.02, 0.035), seg=8, rings=5, seed=6)))
    for sx in (-1, 1):
        parts.append(W("spine", _painted(sweep([Vector((sx * 0.012, -0.09, 1.37)), Vector((sx * 0.03, -0.1, 1.3))], [0.018, 0.012],
                                               n=4, flat=0.3, name="tie_end"), LINEN_WHITE, ao=0.0)))
    # arms: frock-coat sleeves, waxed-cloth over-sleeves from elbow to wrist; the case in the left hand
    sh = {sx: Vector((sx * 0.2, 0.0, 1.38)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.245, 0.0, 1.12)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.26, -0.07, 0.89)) for sx in (-1, 1)}
    hands = {}
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], SU_COAT, SU_COAT_DARK, r=(0.054, 0.05, 0.046, 0.044),
                         skin=SKIN_PALE, seed=20 + sx * 3, hand_size=0.95, grip=(sx > 0))
        ov = sweep([el[sx] + (sh[sx] - el[sx]).normalized() * 0.02, el[sx].lerp(wr[sx], 0.5), wr[sx] + (wr[sx] - el[sx]).normalized() * 0.005],
                   [0.058, 0.06, 0.054], n=10, name="oversleeve")
        _painted(ov, SU_WAX, var=0.1, ao=0.1, top=0.3, seed=24 + sx)
        _tint(ov, lambda co, nr: (1.0, SU_WAX_SHEEN, 0.45 * max(0.0, nr.z) + 0.2 * max(0.0, -nr.y)))
        parts.append(W(bone, ov))
    # leather case (Arzttasche) hanging from the left fist: a rounded bag with a brass clasp
    h = hands[1]
    bc = h + Vector((0.01, -0.0, -0.2))
    bag = L.prim("cube", loc=bc, scale=(0.05, 0.16, 0.11))
    L.bevel(bag, 0.035, 2)
    for v in bag.data.vertices:
        if v.co.z > bc.z + 0.05:
            v.co.x = bc.x + (v.co.x - bc.x) * 0.55
    L.jitter(bag, 0.004, 6.0, 7)
    parts.append(W("arm_l", _painted(bag, SU_BAG, var=0.15, ao=0.25, top=0.3, seed=7, hue_shift=SU_BAG_DARK)))
    parts.append(W("arm_l", L.part("cube", BRASS, loc=bc + Vector((0, 0, 0.112)), scale=(0.03, 0.12, 0.008),
                                   paint_kw={"ao": 0.0, "top": 0.5})))
    parts.append(W("arm_l", L.part("torus", SU_BAG_DARK, loc=bc + Vector((0, 0, 0.15)), rot=(0, 90, 0), major_radius=0.05,
                                   minor_radius=0.009, major_segments=10, minor_segments=4, paint_kw={"ao": 0.0})))
    # head: narrow, calm and attentive, side-parted dark hair, trimmed side whiskers, small round spectacles,
    # a low top hat
    c = Vector((0.0, -0.03, 1.56))
    s = Vector((0.124, 0.13, 0.146))
    pts = _head(parts, c, s, SKIN_PALE, seed=30, nose="straight", nose_s=1.05, brow=SU_HAIR, brow_w=0.95, brow_tilt=0.1,
                brow_arch=0.7, mouth="kind", smile=0.7, lip=LIP_PALE, cheeks=0.35, jaw=0.9, chin=0.03, lids=0.18,
                iris=IRIS_DARK)
    face = pts["face"]
    _hair(parts, face, SU_HAIR, SU_HAIR_DARK, [(0.0, 0.46), (0.5, 0.42), (0.95, 0.2), (1.3, 0.04), (1.42, -0.4),
                                               (1.62, -0.42), (1.9, -0.2), (math.pi, -0.5)], out=0.007, crown=0.006,
          part_u=0.38, tuft=0.004, seed=31)
    for sx in (-1, 1):
        d = Face.around(sx * 1.36, -0.42)
        parts.append(W("head", _oell(SU_HAIR, face.world(d, 0.004), face.normal(d), (0.016, 0.006, 0.04), seg=8, rings=5,
                                     var=0.2, ao=0.0, top=0.2, seed=32 + sx, hue_shift=SU_HAIR_DARK)))
        e = pts["eye"][0 if sx < 0 else 1]
        rimc = e + Vector((0, -0.017, -0.001))
        parts.append(W("head", L.part("torus", IRON, loc=rimc, rot=(90, 0, 0), major_radius=0.024, minor_radius=0.0028,
                                      major_segments=12, minor_segments=3, paint_kw={"ao": 0.0, "top": 0.4})))
        ear = face.world(Face.around(sx * 1.5, 0.02), 0.01)
        parts.append(W("head", _painted(sweep([rimc + Vector((sx * 0.024, 0, 0)), ear], 0.0025, n=3, name="temple"), IRON,
                                        ao=0.0)))
    parts.append(W("head", _painted(sweep([pts["eye"][0] + Vector((0.024, -0.017, 0.002)),
                                           face.pt(0.0, 0.17, 0.006),
                                           pts["eye"][1] + Vector((-0.024, -0.017, 0.002))],
                                          0.0025, n=3, name="bridge"), IRON, ao=0.0)))
    hz = c.z + s.z * 0.7
    brim = L.prim("cyl", loc=(0, c.y + 0.005, hz), radius=1.0, depth=0.012, vertices=18, scale=(s.x + 0.08, s.y + 0.085, 1.0))
    for v in brim.data.vertices:  # the brim curls up at the sides
        v.co.z += 0.03 * (abs(v.co.x) / (s.x + 0.08)) ** 3
    parts.append(W("head", _painted(brim, SU_COAT_DARK, var=0.1, ao=0.0, top=0.3, seed=33)))
    crown = loft([(hz, s.x + 0.012, s.y + 0.012, 0.0, c.y + 0.005), (hz + 0.08, s.x + 0.0, s.y, 0.0, c.y + 0.005),
                  (hz + 0.15, s.x + 0.012, s.y + 0.012, 0.0, c.y + 0.005)], n=16, p=2.0, name="crown")
    _painted(crown, SU_COAT_DARK, var=0.1, ao=0.1, top=0.35, seed=34, hue_shift=SU_COAT_SHEEN)
    parts.append(W("head", crown))
    parts.append(W("head", _ring_band(Prof(((hz + 0.02, s.x + 0.01, s.y + 0.01, c.y + 0.005),)), hz + 0.02, 0.012,
                                      L.hexc("#4A3A2C"), out=0.004, n=16, flat=0.6)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.85)
    L.smooth(mesh, 55)
    joints = _joints(hip, waist, Vector((0, -0.01, 1.43)), Vector((0, -0.03, 1.74)), sh, wr, 0.095)
    talk_keys = [
        (0.0, {"arm_r": (-30.0, -4.0, 12.0), "head": (3.0, 0.0, 2.0)}),
        (0.3, {"arm_r": (-46.0, -8.0, 22.0), "head": (5.0, -2.0, 0.0), "spine": (2.0, 0.0, -2.0)}),
        (0.55, {"arm_r": (-36.0, -16.0, 14.0), "head": (2.0, 2.0, 3.0)}),
        (0.8, {"arm_r": (-42.0, -6.0, 20.0), "head": (4.0, 0.0, -2.0), "spine": (1.0, 0.0, 0.0)}),
    ]
    actions = (
        ("idle-loop", 90, _idle(0.7, 0.4, 0.5)),
        ("walk-loop", 20, _walk(22.0, 0.04, 12.0, 0.012, 2.0, 3.0, 1.0, lambda t: {"arm_l": (6.0 * math.sin(rig.TAU * t), 0, 0)})),
        ("talk-loop", 90, _talk(talk_keys, 0.7)),
    )
    _rigged("ph_chr_v_surgeon", mesh, joints, actions)


# ======================================================================================================
# Liesel Dorn - the washer of the dead
# ======================================================================================================

WA_SHAWL = L.hexc("#77736A")
WA_SHAWL_DARK = L.hexc("#5A574F")
WA_DRESS = L.hexc("#2C2928")
WA_DRESS_DARK = L.hexc("#1E1C1C")
WA_APRON = L.hexc("#CFC7B4")
WA_HAIR = L.hexc("#54402F")
WA_HAIR_GREY = L.hexc("#8A8278")


def washer():
    L.reset(7701)
    parts = []
    prof = Prof(((0.05, 0.26, 0.24, 0.012), (0.25, 0.25, 0.23, 0.01), (0.5, 0.232, 0.208, 0.004), (0.75, 0.212, 0.182, 0.0),
                 (0.9, 0.188, 0.158, 0.0), (0.97, 0.17, 0.142, -0.004), (1.05, 0.172, 0.146, -0.01),
                 (1.15, 0.186, 0.156, -0.012), (1.22, 0.186, 0.148, -0.008), (1.27, 0.17, 0.13, -0.004),
                 (1.31, 0.13, 0.105, -0.004), (1.34, 0.07, 0.065, -0.008)))
    waist = 0.97
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.09, BOOT, length=0.125, width=0.06, height=0.052, toe=-0.075, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.09, 0.0, 0.04), (sx * 0.094, 0.0, 0.5), (sx * 0.095, 0.0, 0.86)],
                  [0.046, 0.05, 0.062], BLACK, seed=12)
    dress = _body(prof, WA_DRESS, WA_DRESS_DARK, n=24, seed=1, fold=0.012)
    _tint(dress, lambda co, nr: (1.0, BLACK_SHEEN, 0.3 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(dress, waist, "hips", "spine"))
    # the long white apron
    ap = _sheet_on(prof, [0] * 7, [0.14, 0.3, 0.5, 0.7, 0.86, 0.96], 0.01, WA_APRON, LINEN_SHADE, seed=3,
                   xfn=lambda z: (-0.17 - 0.06 * (0.96 - z), 0.17 + 0.06 * (0.96 - z)))
    _tint(ap, lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(co.x * 46.0)) * max(0.0, (0.9 - co.z) / 0.8), None, 0.0))
    parts.append(W("hips", ap))
    parts.append(W("hips", _ring_band(prof, waist, 0.013, LINEN_SHADE, out=0.012, flat=0.45, seed=4)))
    # the drop spindle tucked into the apron string on her right hip, a twist of grey wool
    sc = prof.surf(-0.17, waist - 0.02, -1, 0.03)
    parts.append(W("hips", _painted(L.tube(sc + Vector((0, 0, 0.08)), sc + Vector((0.01, -0.01, -0.2)), 0.007, 5), WOOD,
                                    ao=0.0, var=0.15, seed=5)))
    parts.append(W("hips", L.part("cyl", WOOD_DARK, loc=sc + Vector((0.008, -0.008, -0.16)), radius=0.035, depth=0.014,
                                  vertices=10, paint_kw={"ao": 0.0})))
    parts.append(W("hips", _ell(L.hexc("#9A958A"), sc + Vector((0.002, -0.002, -0.02)), (0.026, 0.026, 0.05), seg=8,
                                rings=5, seed=6, jit=0.004)))
    # arms: black sleeves pushed up a little, reddened hands
    sh = {sx: Vector((sx * 0.19, -0.004, 1.27)) for sx in (-1, 1)}
    el = {sx: Vector((sx * 0.235, 0.0, 1.04)) for sx in (-1, 1)}
    wr = {sx: Vector((sx * 0.245, -0.08, 0.84)) for sx in (-1, 1)}
    for sx in (-1, 1):
        _arm(parts, sx, sh[sx], el[sx], wr[sx], WA_DRESS, WA_DRESS_DARK, r=(0.052, 0.05, 0.046, 0.044),
             skin=SKIN_RED, seed=20 + sx * 3, hand_size=1.05, hand_shade=L.hexc("#B86A5C"))
    # head: warm, a little careworn; dark hair with grey threads under the grey woollen shawl pulled over the
    # head, crossed on the chest, a point down the back
    c = Vector((0.0, -0.03, 1.45))
    s = Vector((0.13, 0.132, 0.142))
    pts = _head(parts, c, s, SKIN_OLD, seed=30, nose="straight", nose_s=1.0, brow=WA_HAIR, brow_w=1.0, brow_tilt=0.45,
                brow_arch=0.9, mouth="kind", smile=0.75, cheeks=0.65, cheek_col=L.hexc("#D47462"), jaw=0.95, chin=0.02,
                age=0.2, lids=0.2, iris=IRIS_BLUE, ears=False)
    face = pts["face"]
    _hair(parts, face, WA_HAIR, WA_HAIR_GREY, [(0.0, 0.42), (0.6, 0.34), (1.0, 0.08), (1.3, -0.16), (math.pi, -0.5)],
          out=0.005, crown=0.003, part_u=0.0, seed=31)
    hood, _ = _cloth_cover(parts, face, WA_SHAWL, WA_SHAWL_DARK, [(0.0, 0.58), (0.5, 0.52), (0.9, 0.22), (1.12, -0.3),
                                                               (1.3, -0.78), (1.6, -0.96), (math.pi, -0.96)],
                           out=lambda ph, w: 0.022 + 0.012 * max(0.0, math.cos(ph)) + 0.02 * _s01((-w - 0.1) / 0.6)
                           + 0.014 * abs(math.sin(ph)),
                           crown=0.012, folds=6.0, rim=0.012 * face.k, rim_phi=1.35, lumps=0.008, seed=32,
                           name="shawl_hood")
    _tint(hood, lambda co, nr: (1.0 - 0.1 * max(0.0, math.sin(co.x * 50.0 + co.z * 20.0)), None, 0.0))
    drape = loft([(1.12, 0.215, 0.178, 0.0, -0.002), (1.2, 0.214, 0.172, 0.0, 0.0), (1.27, 0.2, 0.152, 0.0, 0.0),
                  (1.32, 0.16, 0.128, 0.0, 0.0), (1.36, 0.12, 0.112, 0.0, 0.0)], n=22, caps=(False, False), name="drape")
    for v in drape.data.vertices:  # a point hangs down the back
        a = math.atan2(v.co.y, v.co.x)
        if v.co.z < 1.13:
            v.co.z -= 0.16 * max(0.0, math.sin(a)) ** 3
            v.co.z += 0.03 * max(0.0, -math.sin(a))
    L.jitter(drape, 0.005, 6.0, 33)
    _painted(drape, WA_SHAWL, var=0.18, ao=0.2, top=0.25, seed=33, hue_shift=WA_SHAWL_DARK)
    _tint(drape, lambda co, nr: (1.0 - 0.12 * max(0.0, math.sin(math.atan2(co.y, co.x) * 6.0)), None, 0.0))
    parts.append(rig.weight_split_z(drape, 1.33, "spine", "head"))
    for sx in (-1, 1):   # the shawl ends crossed over the chest and tucked into the apron string
        pts = [prof.surf(sx * 0.12, 1.25, -1, 0.02), prof.surf(sx * 0.02, 1.12, -1, 0.02), prof.surf(-sx * 0.07, 0.99, -1, 0.02)]
        parts.append(W("spine", _painted(sweep(pts, [0.05, 0.05, 0.04], n=6, flat=0.25, name="cross",
                                               normals=[prof.normal(q.x, q.z) for q in pts]), WA_SHAWL, var=0.15, ao=0.1,
                                         top=0.25, seed=34 + sx, hue_shift=WA_SHAWL_DARK)))
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.62)
    L.smooth(mesh, 55)
    joints = _joints(0.84, waist, Vector((0, -0.01, 1.33)), Vector((0, -0.03, 1.64)), sh, wr, 0.094)

    def work(t: float) -> dict:
        """60 frames = 2 s: hand-spinning - the left hand high draws the wool, the right twirls low."""
        s1 = math.sin(rig.TAU * t)
        s3 = math.sin(rig.TAU * t * 3.0)
        return rig.add(rig.breathe(t, 0.8), {
            "arm_l": (-64.0 + 4.0 * s1, 10.0, -14.0),
            "arm_r": (-34.0 + 9.0 * s3, -10.0, 16.0 + 10.0 * s3),
            "spine": (6.0, 0.0, 2.0),
            "head": (12.0 + 2.0 * s1, 0.0, -4.0),
            "feet": {"leg_l": 0.0, "leg_r": 0.0},
        })
    talk_keys = [
        (0.0, {"arm_r": (-20.0, -4.0, 8.0), "arm_l": (-18.0, 4.0, -8.0), "head": (6.0, 0.0, 3.0)}),
        (0.3, {"arm_r": (-34.0, -8.0, 16.0), "arm_l": (-22.0, 6.0, -10.0), "head": (2.0, -3.0, -2.0)}),
        (0.6, {"arm_r": (-24.0, -6.0, 10.0), "arm_l": (-30.0, 8.0, -14.0), "head": (7.0, 2.0, 4.0)}),
    ]
    actions = (
        ("idle-loop", 72, _idle(0.9, 0.6, 0.8, lambda t: {"head": (4.0, 0, 0), "arm_l": (-6.0, 4.0, -4.0), "arm_r": (-6.0, -4.0, 4.0)})),
        ("walk-loop", 18, _walk(22.0, 0.04, 14.0, 0.014, 2.5, 4.0, 3.0)),
        ("talk-loop", 72, _talk(talk_keys, 0.9)),
        ("work-loop", 60, work),
    )
    _rigged("ph_chr_v_washer", mesh, joints, actions)


# ======================================================================================================
# Wiebke Hagedorn - the old woman at the well
# ======================================================================================================

OW_DRESS = L.hexc("#2A2827")
OW_DRESS_DARK = L.hexc("#1D1B1B")
OW_SHAWL = L.hexc("#1F1E1F")
OW_FRINGE = L.hexc("#333032")
OW_CAP = L.hexc("#D8D1C2")
OW_HAIR = L.hexc("#C8C4BE")
OW_HAIR_DARK = L.hexc("#8E877C")
POPPY = L.hexc("#8A4A3C")          # dried poppy: dull, brownish red
POPPY_DARK = L.hexc("#5E3A32")
POPPY_STEM = L.hexc("#7C7456")
POPPY_POD = L.hexc("#8A8466")


def _posy(parts, base: Vector, out: Vector, bone: str, seed: int = 0, scale: float = 1.0) -> None:
    """A little posy of dried poppy: three crinkled heads, two seed pods, stems tied with a thread."""
    up = Vector((0.0, 0.0, 1.0))
    for k, (dx, dz, pod) in enumerate(((0.0, 0.07, False), (-0.025, 0.055, False), (0.024, 0.06, False),
                                       (-0.012, 0.085, True), (0.014, 0.08, True))):
        tip = base + Vector((dx, 0.0, dz)) * scale + out * 0.01 * scale
        parts.append(W(bone, _painted(sweep([base - up * 0.04 * scale, tip], 0.0028 * scale, n=4, name="stem"),
                                      POPPY_STEM, ao=0.0, var=0.1, seed=seed + k)))
        if pod:
            parts.append(W(bone, _ell(POPPY_POD, tip, (0.009 * scale, 0.009 * scale, 0.011 * scale), seg=6, rings=4,
                                      ao=0.0, seed=seed + k)))
        else:
            fl = L.prim("ico", loc=tip, radius=0.019 * scale, subdivisions=1)
            L.jitter(fl, 0.005 * scale, 60.0, seed + k)
            _painted(fl, POPPY, var=0.25, ao=0.0, top=0.3, seed=seed + k, hue_shift=POPPY_DARK)
            parts.append(W(bone, fl))
            parts.append(W(bone, _ell(BLACK_DARK, tip + out * 0.012 * scale, (0.005 * scale, 0.004 * scale, 0.005 * scale),
                                      seg=5, rings=3, ao=0.0)))
    parts.append(W(bone, L.part("torus", POPPY_DARK, loc=base, major_radius=0.01 * scale, minor_radius=0.0035 * scale,
                                major_segments=8, minor_segments=3, paint_kw={"ao": 0.0})))


HAG_POSY = Vector((0.07, -0.252, 1.0))   # her posy at the bodice (Blender, before grounding)


def oldwoman():
    L.reset(7801)
    parts = []
    # bent: the profile leans forward with height (cy), a rounded upper back
    prof = Prof(((0.05, 0.235, 0.215, 0.012), (0.22, 0.228, 0.206, 0.008), (0.45, 0.212, 0.19, 0.0), (0.66, 0.196, 0.17, -0.01),
                 (0.78, 0.178, 0.152, -0.02), (0.84, 0.164, 0.142, -0.03), (0.92, 0.17, 0.155, -0.05),
                 (1.0, 0.178, 0.17, -0.075), (1.06, 0.178, 0.172, -0.1), (1.1, 0.165, 0.16, -0.125),
                 (1.13, 0.13, 0.125, -0.145), (1.155, 0.07, 0.07, -0.165)))
    waist = 0.84
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        _shoe(parts, leg, sx * 0.085, BOOT, length=0.12, width=0.056, height=0.05, toe=-0.08, seed=10 + sx)
        _leg_tube(parts, leg, [(sx * 0.085, 0.0, 0.04), (sx * 0.088, 0.0, 0.4), (sx * 0.09, 0.0, 0.74)],
                  [0.042, 0.046, 0.058], BLACK, seed=12)
    dress = _body(prof, OW_DRESS, OW_DRESS_DARK, n=24, seed=1, fold=0.011, fold_top=0.78)
    _tint(dress, lambda co, nr: (1.0, BLACK_SHEEN, 0.25 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(dress, waist, "hips", "spine"))
    parts.append(W("hips", _ring_band(prof, waist, 0.012, OW_DRESS_DARK, out=0.006, flat=0.5)))
    # black fringed shawl over the shoulders, a point down the back, tied in front
    sh_rings = [(0.9, 0.2, 0.19, -0.05), (0.98, 0.205, 0.198, -0.072), (1.05, 0.205, 0.198, -0.098),
                (1.1, 0.19, 0.182, -0.125), (1.135, 0.145, 0.138, -0.145), (1.165, 0.09, 0.09, -0.165)]
    shawl = loft([(z, rx, ry, 0.0, cy) for z, rx, ry, cy in sh_rings], n=22, caps=(False, False), name="shawl")
    for v in shawl.data.vertices:
        a = math.atan2(v.co.y - (-0.06), v.co.x)
        if v.co.z < 0.91:
            v.co.z -= 0.2 * max(0.0, math.sin(a)) ** 2      # point at the back
            v.co.z += 0.06 * max(0.0, -math.sin(a))          # higher in front
    L.jitter(shawl, 0.005, 6.0, 3)
    _painted(shawl, OW_SHAWL, var=0.14, ao=0.2, top=0.25, seed=3, hue_shift=BLACK_SHEEN)
    parts.append(W("spine", shawl))
    fringe = []
    for k in range(22):
        a = math.tau * k / 22
        r = (0.205, 0.192)
        z = 0.9 - 0.2 * max(0.0, math.sin(a)) ** 2 + 0.06 * max(0.0, -math.sin(a))
        p = Vector((math.cos(a) * r[0], -0.046 + math.sin(a) * r[1], z))
        fringe.append(_painted(sweep([p, p + Vector((0, 0, -0.045))], 0.006, n=3, name="fringe"), OW_FRINGE, ao=0.0, var=0.1))
    parts += [W("spine", f) for f in fringe]
    # arms: bent forward; the right hand on the stick, the left hangs near the posy
    sh = {sx: Vector((sx * 0.165, -0.1, 1.07)) for sx in (-1, 1)}
    el = {1: Vector((0.21, -0.11, 0.9)), -1: Vector((-0.22, -0.14, 0.9))}
    wr = {1: Vector((0.2, -0.2, 0.74)), -1: Vector((-0.23, -0.27, 0.74))}
    hands = {}
    for sx in (-1, 1):
        hands[sx] = _arm(parts, sx, sh[sx], el[sx], wr[sx], OW_DRESS, OW_DRESS_DARK, r=(0.048, 0.046, 0.042, 0.04),
                         skin=SKIN_OLD, seed=20 + sx * 3, hand_size=1.0, grip=(sx < 0))
    # the walking stick: a crooked hazel stick with a bent handle under her right palm
    h = hands[-1]
    top = h + Vector((0.0, -0.005, 0.04))
    bot = Vector((h.x - 0.03, h.y - 0.08, 0.0))
    stick = sweep([bot + Vector((0, 0, 0.02)), bot.lerp(top, 0.5) + Vector((0.012, 0.01, 0.0)), top,
                   top + Vector((0.0, 0.06, 0.03))], [0.014, 0.015, 0.015, 0.013], n=6, name="stick")
    L.jitter(stick, 0.003, 10.0, 4)
    parts.append(W("arm_r", _painted(stick, L.hexc("#5E4A36"), var=0.25, ao=0.0, top=0.3, seed=4)))
    # the posy of dried poppy at the bodice
    _posy(parts, HAG_POSY, Vector((0.2, -1.0, 0.1)).normalized(), "spine", seed=40)
    # head: small, wrinkled and kindly, bright (if a little tired) eyes, white hair under a white cap with a
    # frill, the bun under its puffed back
    c = Vector((0.0, -0.21, 1.24))
    s = Vector((0.12, 0.124, 0.13))
    pts = _head(parts, c, s, SKIN_OLD, seed=30, nose="hook", nose_s=0.9, brow=OW_HAIR_DARK, brow_w=0.9, brow_tilt=0.8,
                brow_arch=1.0, mouth="kind", smile=1.0, lip=LIP_PALE, cheeks=0.6, jaw=0.88, chin=0.08, age=1.0,
                eyes=0.96, lids=0.26, iris=IRIS_GREY, muzzle=0.9, ears=False)
    face = pts["face"]
    _hair(parts, face, OW_HAIR, OW_HAIR_DARK, [(0.0, 0.52), (0.7, 0.44), (1.2, 0.05), (1.5, -0.22), (math.pi, -0.38)],
          out=0.006, crown=0.004, part_u=0.0, tuft=0.004, seed=31)
    _, edge = _cloth_cover(parts, face, OW_CAP, LINEN_SHADE, [(0.0, 0.76), (0.7, 0.64), (1.2, 0.1), (1.5, -0.3),
                                                             (2.2, -0.42), (math.pi, -0.4)],
                           out=lambda ph, w: 0.014 + 0.045 * max(0.0, -math.cos(ph)) ** 2 * _s01((w + 0.35) / 0.6),
                           crown=0.006, folds=10.0, seed=33, name="cap")
    _frill(parts, face, edge, OW_CAP, 0.014 * face.k, 1.55, seed=34)
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh, 1.42)
    L.smooth(mesh, 55)
    joints = _joints(0.74, waist, Vector((0, -0.16, 1.15)), Vector((0, -0.22, 1.4)), sh, wr, 0.088,
                     hips_y=0.0, waist_y=-0.028)

    def sit(t: float) -> dict:
        """72 frames = 2.4 s, seated on the well bench (seat 0.45 m): hips lowered, legs forward to the
        ground, hands in the lap, the stick leaning; slow breathing and a nod now and then."""
        s = math.sin(rig.TAU * t)
        base = {"hips": (-6.0, 0.0, 0.0, 0.0, 0.04, -0.27), "spine": (-8.0, 0.0, 0.0), "head": (6.0 + 2.0 * s, 0.0, 3.0 * s),
                "leg_l": (-50.0, 0.0, -4.0), "leg_r": (-50.0, 0.0, 4.0),
                "arm_l": (-26.0, -4.0, 10.0), "arm_r": (-18.0, 6.0, -6.0)}
        return rig.add(rig.breathe(t, 0.7), base, {"feet": {"leg_l": 0.0, "leg_r": 0.0}})
    talk_keys = [
        (0.0, {"arm_l": (-24.0, 6.0, -10.0), "head": (-4.0, 0.0, 4.0)}),
        (0.3, {"arm_l": (-44.0, 12.0, -20.0), "head": (-8.0, -4.0, -2.0)}),
        (0.6, {"arm_l": (-30.0, 6.0, -12.0), "head": (-3.0, 3.0, 6.0)}),
    ]
    actions = (
        ("idle-loop", 72, _idle(1.1, 0.5, 1.4)),
        ("walk-loop", 26, _walk(13.0, 0.025, 6.0, 0.008, 2.5, 2.0, 1.0, lambda t: {"arm_r": (-4.0, 0.0, 0.0)})),
        ("talk-loop", 72, _talk(talk_keys, 1.0)),
        ("sit-loop", 72, sit),
    )
    _rigged("ph_chr_v_oldwoman", mesh, joints, actions)


# ======================================================================================================
# Seated figures without a rig: guests of the Gaststube, the lecture students
# ======================================================================================================

SEAT = M6.SEAT
M6_SKIN = L.hexc("#C99A7E")       # the seated figures: the villagers' warm skin


def _seated(parts, coat, dark, *, lean: float, skirt: bool = False, stout: float = 1.0, seed: int = 0,
            hands: str = "table"):
    """Seated body from the mourner kit, but upright with the forearms on a table edge (hands at
    0.76 m in front, around a mug) or holding a notebook in the lap (hands='book')."""
    head, sh_z, sh_y = M6._figure(parts, coat, dark, lean=lean, skirt=skirt, stout=stout, seed=seed)
    # replace the lap hands of the kit: drop the last two parts (hands sphere) and the arms
    hands_obj = parts.pop()
    bpy.data.objects.remove(hands_obj)
    for _ in range(2):
        a = parts.pop(-1)
        bpy.data.objects.remove(a)
    del a
    if hands == "table":
        hp = Vector((0.0, -0.44, 0.78))
    else:
        hp = Vector((0.0, -0.32, SEAT + 0.16))
    for sx in (-1, 1):
        s = Vector((sx * 0.19 * stout, sh_y + 0.01, sh_z))
        e = Vector((sx * 0.21 * stout, sh_y - 0.1, sh_z - 0.24))
        w = Vector((sx * 0.08, hp.y + 0.03, hp.z + 0.01))
        arm = sweep([s, e, w], [0.07, 0.062, 0.055], n=7, name="arm")
        parts.append(M6._shade(arm, coat, dark, (SEAT, sh_z), seed + 4))
        parts.append(P._finish_obj(L.prim("sphere", loc=w + Vector((0, -0.04, -0.005)), radius=0.045, segments=8, ring_count=5,
                                          scale=(1.0, 1.2, 0.8)), M6_SKIN, var=0.1, ao=0.2, top=0.2, hue_shift=SKIN_ROSY))
    return head, sh_z, sh_y, hp


def _mug(parts, at: Vector, seed: int = 0) -> None:
    body = L.prim("cyl", loc=at + Vector((0, 0, 0.06)), radius=0.04, depth=0.12, vertices=10)
    parts.append(P._finish_obj(body, L.hexc("#8A7A62"), var=0.12, ao=0.2, top=0.3, seed=seed))
    parts.append(P._finish_obj(L.prim("cyl", loc=at + Vector((0, 0, 0.119)), radius=0.034, depth=0.004, vertices=10),
                               L.hexc("#4A3A2A"), var=0.05, ao=0.0))
    parts.append(P._finish_obj(L.prim("torus", loc=at + Vector((0.048, 0, 0.06)), rot=(90, 0, 0), major_radius=0.025,
                                      minor_radius=0.008, major_segments=8, minor_segments=4), L.hexc("#8A7A62"), ao=0.0))


def _face_hint(parts, head: Vector, seed: int = 0, **kw) -> dict:
    """Upright head of a seated figure: the villagers' sculpted head (smaller, coarser), static (no bone)."""
    s = Vector((0.096, 0.1, 0.108))
    opts = dict(nose="round", nose_s=1.0, brow=L.hexc("#5A4634"), mouth="smile", smile=0.8, cheeks=0.7, iris=IRIS_BROWN,
                lids=0.16, seg=16, rings=10, detail=False)
    opts.update(kw)
    return _head(parts, head, s, M6_SKIN, seed=seed, add=parts.append, **opts)


def _static(parts, name: str) -> None:
    obj = L.join(parts, name)
    finish_stable(obj, name, CAT, 50, shift=False)


def guest_a():
    """A farmer with a felt hat and a brown jacket, both forearms on the table round his mug."""
    L.reset(7901)
    parts = []
    coat, dark = L.hexc("#5A4A3A"), L.hexc("#3E3328")
    head, sh_z, sh_y, hp = _seated(parts, coat, dark, lean=0.06, stout=1.08, seed=1)
    head = head + Vector((0, 0.07, 0.02))
    pts = _face_hint(parts, head, seed=2, mouth="laugh", brow=L.hexc("#6A5A48"), brow_w=1.3, brow_tilt=0.4, jaw=1.05,
                     cheeks=0.9, age=0.4)
    face = pts["face"]
    _hair(parts, face, L.hexc("#6A5A48"), L.hexc("#4A3E32"), [(0.0, 0.42), (1.0, 0.1), (1.5, -0.25), (math.pi, -0.5)],
          out=0.005, crown=0.0, seed=3, add=parts.append, n=18, m=4)
    for sx in (-1, 1):   # a short, round beard along the jaw
        bp = [face.world(Face.around(sx * 1.3, -0.2), 0.006), face.world(Face.around(sx * 0.7, -0.75), 0.012),
              face.world(Face.around(0.0, -0.9), 0.016)]
        parts.append(P._finish_obj(sweep(bp, [0.016, 0.022, 0.026], n=7, name="beard"), L.hexc("#7A6A58"), var=0.2, ao=0.0))
    crown = L.prim("cyl", loc=head + Vector((0, 0.0, 0.1)), radius=0.1, depth=0.1, vertices=12)
    L.taper(crown, head.z + 0.05, head.z + 0.15, 0.85)
    brim = L.prim("cyl", loc=head + Vector((0, 0.0, 0.055)), radius=0.19, depth=0.014, vertices=14)
    for o in (crown, brim):
        parts.append(P._finish_obj(o, L.hexc("#3A332C"), var=0.12, ao=0.2, top=0.25))
    _mug(parts, hp + Vector((0.0, -0.06, -0.02)), 3)
    _static(parts, "ph_chr_guest_a")


def guest_b():
    """A woman in a dark-green jacket and a cream bonnet, a mug between her hands."""
    L.reset(7911)
    parts = []
    coat, dark = L.hexc("#4A5040"), L.hexc("#32362C")
    head, sh_z, sh_y, hp = _seated(parts, coat, dark, lean=0.08, skirt=True, stout=0.95, seed=3)
    head = head + Vector((0, 0.07, 0.02))
    pts = _face_hint(parts, head, seed=4, nose="button", brow=L.hexc("#6E5236"), brow_tilt=0.4, mouth="smile",
                     iris=IRIS_HAZEL, jaw=0.92, ears=False)
    face = pts["face"]
    _hair(parts, face, L.hexc("#6E5236"), L.hexc("#4A3624"), [(0.0, 0.44), (1.0, 0.1), (1.3, -0.15), (math.pi, -0.45)],
          out=0.004, crown=0.0, part_u=0.0, seed=5, add=parts.append, n=18, m=4)
    _cloth_cover(parts, face, L.hexc("#CFC6B0"), LINEN_SHADE, [(0.0, 0.62), (0.9, 0.2), (1.3, -0.45), (math.pi, -0.5)],
                 out=lambda ph, w: 0.01 + 0.025 * max(0.0, -math.cos(ph)), crown=0.006, rim=0.007, rim_phi=1.5, seed=6,
                 name="bonnet", add=parts.append, n=18, m=4)
    shawl = loft([(sh_z - 0.14, 0.25, 0.2, 0.0, sh_y + 0.02), (sh_z - 0.03, 0.23, 0.18, 0.0, sh_y + 0.01),
                  (sh_z + 0.04, 0.15, 0.13, 0.0, sh_y)], n=16, p=2.0, name="shawl")
    parts.append(M6._shade(shawl, L.hexc("#6E5E48"), L.hexc("#4E4234"), (sh_z - 0.2, sh_z + 0.05), 5))
    _mug(parts, hp + Vector((0.0, -0.06, -0.02)), 6)
    _static(parts, "ph_chr_guest_b")


def _student(name: str, seed: int, coat, dark, cap_col, turn: float, cap: str) -> None:
    """A lecture student on a bench: a long coat, a cap, a notebook in the lap, writing. turn > 0
    turns the head (half profile)."""
    L.reset(seed)
    parts = []
    head, sh_z, sh_y, hp = _seated(parts, coat, dark, lean=0.16, stout=0.95, seed=seed % 97, hands="book")
    head = head + Vector((0, 0.04, 0.0))
    h0 = len(parts)
    hair_col = (L.hexc("#5A4634"), L.hexc("#7A5E3E"), L.hexc("#3E3028"))[seed % 3]
    pts = _face_hint(parts, head, seed=seed % 89, mouth=("kind", "smile", "thin")[seed % 3], brow=L.scale_c(hair_col, 0.8),
                     brow_tilt=0.2, iris=(IRIS_BROWN, IRIS_BLUE, IRIS_HAZEL)[seed % 3], jaw=0.92, nose=("straight", "round", "button")[seed % 3])
    _hair(parts, pts["face"], hair_col, L.scale_c(hair_col, 0.7), [(0.0, 0.4), (0.9, 0.2), (1.35, -0.05), (1.6, -0.3),
                                                                   (math.pi, -0.55)], out=0.005, crown=0.004, tuft=0.004,
          seed=seed % 7, add=parts.append, n=18, m=4)
    if cap == "peak":
        crown = L.prim("sphere", loc=head + Vector((0, 0.0, 0.07)), radius=1.0, segments=12, ring_count=6,
                       scale=(0.12, 0.125, 0.06))
        parts.append(P._finish_obj(crown, cap_col, var=0.12, ao=0.1, top=0.3))
        peak = L.prim("cyl", loc=head + Vector((0, -0.1, 0.04)), radius=0.07, depth=0.01, vertices=10, scale=(1.0, 0.6, 1.0))
        parts.append(P._finish_obj(peak, L.scale_c(cap_col, 0.8), var=0.1, ao=0.0))
    else:
        cr = L.prim("cyl", loc=head + Vector((0, 0.0, 0.08)), radius=0.108, depth=0.07, vertices=12)
        parts.append(P._finish_obj(cr, cap_col, var=0.12, ao=0.1, top=0.3))
        top = L.prim("cube", loc=head + Vector((0, 0.0, 0.12)), scale=(0.13, 0.13, 0.008), rot=(0, 0, 45))
        parts.append(P._finish_obj(top, cap_col, var=0.1, ao=0.0, top=0.3))
    if turn:
        m = Matrix.Translation(head) @ Matrix.Rotation(math.radians(turn), 4, "Z") @ Matrix.Translation(-head)
        for o in parts[h0:]:
            o.data.transform(m)
    # a scarf round the neck
    parts.append(M6._shade(loft([(sh_z - 0.02, 0.13, 0.11, 0.0, sh_y - 0.01), (sh_z + 0.06, 0.1, 0.09, 0.0, sh_y - 0.02)],
                                n=12, p=2.0, name="scarf"), L.scale_c(cap_col, 1.2), cap_col, (sh_z - 0.1, sh_z + 0.1), 7))
    nb = L.prim("cube", loc=hp + Vector((0.0, -0.02, 0.0)), scale=(0.1, 0.07, 0.008), rot=(28, 0, 0))
    parts.append(P._finish_obj(nb, L.hexc("#CFC3A3"), var=0.05, ao=0.0))
    cv = L.prim("cube", loc=hp + Vector((0.0, -0.016, -0.009)), scale=(0.104, 0.074, 0.004), rot=(28, 0, 0))
    parts.append(P._finish_obj(cv, L.hexc("#4A3A2C"), var=0.1, ao=0.0))
    parts.append(P._finish_obj(L.tube(hp + Vector((-0.06, -0.06, 0.02)), hp + Vector((-0.11, -0.12, 0.08)), 0.005, 5),
                               L.hexc("#B8B0A0"), ao=0.0))
    _static(parts, name)


def student_a():
    _student("ph_chr_student_a", 7921, L.hexc("#3E3A36"), L.hexc("#2A2724"), L.hexc("#4A3E34"), 0.0, "peak")


def student_b():
    _student("ph_chr_student_b", 7931, L.hexc("#44403A"), L.hexc("#2E2B27"), L.hexc("#2E2C2A"), 28.0, "flat")


def student_c():
    _student("ph_chr_student_c", 7941, L.hexc("#3A3E3A"), L.hexc("#272A27"), L.hexc("#5A4A3A"), -22.0, "peak")


VILLAGERS = (innkeeper, smith, grocer, priest, mayor, surgeon, washer, oldwoman)
SEATED = (guest_a, guest_b, student_a, student_b, student_c)


def build(names=None):
    """Build all figures, or only those whose function name is in `names`."""
    for fn in VILLAGERS + SEATED:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
