"""Ilse Kranich, "die Kranichfrau" - the night trader (NPC, docs/PHASE4_DESIGN.md section 2.6 / 8).
Same painted style and palette family as the gravekeeper and Osric, but her own silhouette:
tall (~1.82 m) and gaunt, a straight narrow column instead of his hunch or Osric's barrel.
A grey travelling coat down to the ankles, a deep pointed hood with a single crane feather,
a wicker back-basket (Kiepe) with a pressed elder blossom and two bought braids tied to it,
a lantern with sooty glass in her left hand. A long pale face, heavy calm lids, a thin mouth:
polite, melancholic, a little eerie - never threatening.
Front faces -Y (Blender) = +Z (Godot). Shared 8-bone rig (rig.py, rigid skinning, root motion
off); actions idle-loop, walk-loop, talk-loop, offer (one-shot: she hands over coins).
Markers: light_lantern (sooty glass, follows arm_l), coins (right palm, follows arm_r).

Run:  python tools/blender/build_all.py asset_trader
"""
import math

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import lib_faces as F
import rig
from asset_carter import loft, sweep, _tint, _thicken, _loops, _n

NAME = "ph_chr_kranich"

COAT = L.hexc("#6E6F69")          # travelling grey, a breath warmer than stone
COAT_DARK = L.hexc("#4D4F4A")
COAT_DUST = L.hexc("#8A887C")     # dust of the moor roads on the hem and shoulders
LINING = L.hexc("#3A3633")
DRESS = L.hexc("#3E3631")
BOOT = L.hexc("#2A2421")
SOLE = L.hexc("#1C1816")
STOCKING = L.hexc("#2F2B29")
SKIN = L.hexc("#C8AE99")          # pale, a little sallow
SKIN_HOLLOW = L.hexc("#9C8A82")   # hollow cheeks, eye sockets (lilac-grey, like the moor dusk)
SKIN_WARM = L.hexc("#C49A86")
LIP = L.hexc("#8A6A66")
HAIR = L.hexc("#8F8A81")          # iron-grey
EYE = L.hexc("#1B1715")
GLEAM = L.hexc("#E4DDCF")
FEATHER = L.hexc("#C2C0B7")       # crane grey
FEATHER_TIP = L.hexc("#2C2C2A")
WICKER = L.hexc("#8E7650")
WICKER_DARK = L.hexc("#624E34")
WICKER_LIGHT = L.hexc("#A88E62")
STRAP = L.hexc("#35291F")
CORD = L.hexc("#6E5E48")
LINEN = L.hexc("#CFC4A8")
BLOSSOM = L.hexc("#D8CEAE")       # pressed elder blossom: dry cream
BLOSSOM_STEM = L.hexc("#7C7456")
BRAID_A = L.hexc("#6E5438")       # bought braids: muted brown and ash blond
BRAID_B = L.hexc("#A08A62")
IRON = L.hexc("#3A3C40")
SOOT = L.hexc("#1F1C1A")
BRASS = L.hexc("#7A6A4C")

WAIST_Z = 1.02                    # coat below -> hips, above -> spine (under the cord belt)
HEAD_C = Vector((0.0, -0.045, 1.615))
HEAD_S = Vector((0.098, 0.112, 0.132))   # long narrow head
HOOD_C = HEAD_C + Vector((0.0, 0.018, 0.02))
HOOD_R = Vector((0.152, 0.165, 0.168))
OPEN_W, OPEN_H, OPEN_Z = 0.104, 0.15, HEAD_C.z - 0.012   # face opening of the hood
SHOULDER = {1: Vector((0.185, 0.0, 1.385)), -1: Vector((-0.185, 0.0, 1.385))}
WRIST = {1: Vector((0.275, -0.085, 0.87)), -1: Vector((-0.245, -0.03, 0.87))}
BASKET_Y = 0.245
LANTERN = Vector((0.3, -0.105, 0.64))    # sooty glass centre, below the left fist
W = rig.weight

# coat profile (z, rx, ry, centre y): narrow, straight and tall; the hem flares a little
COAT_PROF = ((0.075, 0.285, 0.265, 0.025), (0.2, 0.262, 0.24, 0.018), (0.4, 0.236, 0.206, 0.008),
             (0.62, 0.212, 0.176, 0.0), (0.82, 0.19, 0.155, 0.0), (0.96, 0.172, 0.14, 0.0),
             (1.04, 0.17, 0.138, 0.0), (1.14, 0.178, 0.142, 0.004), (1.25, 0.186, 0.146, 0.006),
             (1.33, 0.188, 0.147, 0.006), (1.39, 0.168, 0.136, 0.004), (1.44, 0.128, 0.11, -0.004),
             (1.48, 0.075, 0.07, -0.012))


def _painted(obj, color, **kw):
    L.paint(obj, color, **kw)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _side(sx: int, bone: str) -> str:
    return bone + ("_l" if sx > 0 else "_r")  # +X = the character's left


def _xf(obj, m: Matrix):
    obj.data.transform(m)
    return obj


def _coat_at(z: float) -> tuple:
    """(rx, ry, cy) of the coat at height z (linear between the profile rings)."""
    if z <= COAT_PROF[0][0]:
        return COAT_PROF[0][1:]
    for a, b in zip(COAT_PROF, COAT_PROF[1:]):
        if z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in (1, 2, 3))
    return COAT_PROF[-1][1:]


def _on_coat(x: float, z: float, side: int = -1, out: float = 0.0) -> Vector:
    """Point on the coat surface (side -1 = front, +1 = back) at x, z."""
    rx, ry, cy = _coat_at(z)
    rx += out
    ry += out
    k = min(0.98, abs(x) / rx)
    return Vector((x, cy + side * ry * math.sqrt(1.0 - k * k), z))


# --- body -------------------------------------------------------------------------------

def _legs(parts) -> None:
    for sx in (-1, 1):
        leg = _side(sx, "leg")
        x0 = sx * 0.085
        # narrow pointed boots: only the toes peek out under the coat
        foot = L.part("sphere", BOOT, loc=(x0, -0.07, 0.06), scale=(0.07, 0.15, 0.058), segments=12, ring_count=7,
                      jit=0.004, seed=1 + sx, paint_kw={"var": 0.14, "ao": 0.1, "top": 0.3})
        for v in foot.data.vertices:
            v.co.z = max(v.co.z, 0.022)
            if v.co.y < -0.13:
                v.co.z += 0.2 * (-0.13 - v.co.y)
        parts.append(W(leg, foot))
        sole = L.part("sphere", SOLE, loc=(x0, -0.068, 0.02), scale=(0.075, 0.155, 0.022), segments=12, ring_count=4,
                      paint_kw={"var": 0.1, "ao": 0.0})
        for v in sole.data.vertices:
            v.co.z = min(max(0.0, v.co.z), 0.028)
        parts.append(W(leg, sole))
        shaft = loft([(0.04, 0.055, 0.06, x0, 0.0), (0.2, 0.05, 0.054, x0, 0.0), (0.3, 0.052, 0.056, x0, 0.0)],
                     n=10, name="shaft")
        parts.append(W(leg, _painted(shaft, BOOT, var=0.15, ao=0.2, seed=3)))
        # thin stockinged shin up into the coat (never seen above the knee)
        shin = sweep([Vector((x0, 0.0, 0.28)), Vector((sx * 0.088, 0.0, 0.6)), Vector((sx * 0.09, 0.0, 0.92))],
                     [0.047, 0.05, 0.06], n=8, name="shin")
        parts.append(W(leg, _painted(shin, STOCKING, var=0.1, ao=0.2, seed=4)))


def _coat(parts) -> None:
    """Long coat from the shoulders to the ankles: soft vertical folds, a front edge that parts
    below the knees over a dark dress, dusty hem, a centre back seam."""
    n = 30
    front = -math.pi / 2
    bm = bmesh.new()
    rows = []
    for i, (z, rx, ry, cy) in enumerate(COAT_PROF):
        row = []
        skirt = max(0.0, (0.9 - z) / 0.8)
        for k in range(n):
            a = math.tau * k / n
            d = abs((a - front + math.pi) % math.tau - math.pi)
            fold = 0.014 * math.sin(a * 7.0 + 0.8) * skirt + 0.006 * math.sin(a * 12.0 + 2.0) * skirt
            zz = z
            if i == 0:  # the coat parts at the front (inverted V), uneven hem
                zz += 0.2 * max(0.0, 1.0 - d / 0.42) ** 1.4 + 0.008 * math.sin(a * 9.0)
            elif i == 1:
                zz += 0.09 * max(0.0, 1.0 - d / 0.3) ** 1.4
            if z < 0.9 and d < 0.22:   # the left panel overlaps the right a little
                fold += 0.008
            row.append(bm.verts.new((math.cos(a) * (rx + fold), cy + math.sin(a) * (ry + fold), zz)))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    c = bm.verts.new((0.0, COAT_PROF[-1][3], COAT_PROF[-1][0] + 0.004))
    for k in range(n):
        bm.faces.new((c, rows[-1][k], rows[-1][(k + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("coat")
    bm.to_mesh(me)
    bm.free()
    coat = bpy.data.objects.new("coat", me)
    bpy.context.collection.objects.link(coat)
    L.jitter(coat, 0.006, 3.0, 5)
    _painted(coat, COAT, var=0.16, ao=0.3, top=0.14, zrange=(0.05, 1.48), seed=6, hue_shift=COAT_DARK)

    def shade(co, nr):
        a = math.atan2(co.y, co.x)
        d = abs((a - front + math.pi) % math.tau - math.pi)
        db = abs((a - math.pi / 2 + math.pi) % math.tau - math.pi)
        f = 1.0 - 0.1 * max(0.0, math.sin(a * 7.0 + 0.8)) * max(0.0, (0.9 - co.z) / 0.8)   # fold shadows
        col, amt = None, 0.0
        if d < 0.07 and co.z < 1.36:
            f *= 0.55                                    # front edge
        if db < 0.04 and co.z > 0.3:
            f *= 0.8                                     # centre back seam
        f *= 1.0 - 0.12 * max(0.0, (0.8 - co.z) / 0.7)          # the skirt darkens towards the hem
        if abs(co.x + 0.1) < 0.05 and abs(co.z - 0.52) < 0.06 and co.y < 0.0:
            return f * 0.95, L.hexc("#5E5A50"), 0.85             # a mended patch on her right knee
        if co.z < 0.3:
            col, amt = COAT_DUST, 0.5 * (0.3 - co.z) / 0.23 * (0.6 + 0.4 * _n(co, 9.0, 2.0))
        elif co.z > 1.3 and nr.z > 0.2:
            col, amt = COAT_DUST, 0.35 * nr.z
        return f, col, amt
    _tint(coat, shade)
    parts.append(rig.weight_split_z(coat, WAIST_Z, "hips", "spine"))
    # the dark dress shows only where the coat parts
    dress = loft([(0.06, 0.25, 0.215, 0.0, 0.0), (0.3, 0.23, 0.19, 0.0, 0.0), (0.5, 0.215, 0.172, 0.0, 0.0)],
                 n=18, caps=(False, False), name="dress")
    for v in dress.data.vertices:
        v.co.z += 0.006 * math.sin(math.atan2(v.co.y, v.co.x) * 8.0)
    parts.append(W("hips", _painted(dress, DRESS, var=0.14, ao=0.3, seed=7)))
    # a plaited cord belt with a hanging leather pouch
    belt = [Vector((math.cos(a) * 0.182, math.sin(a) * 0.15, WAIST_Z + 0.004 * math.sin(a * 2.0)))
            for a in (math.tau * k / 18 for k in range(18))]
    parts.append(W("hips", _painted(sweep(belt, 0.014, n=5, closed=True, name="belt"), CORD, var=0.2, ao=0.0,
                                    top=0.3, seed=8)))
    knot = _on_coat(-0.06, WAIST_Z, -1, 0.018)
    parts.append(W("hips", L.part("ico", CORD, loc=knot, radius=0.02, subdivisions=1, jit=0.003, seed=9)))
    for dx, ln in ((-0.012, 0.16), (0.01, 0.12)):
        e = knot + Vector((dx, -0.012, -ln))
        parts.append(W("hips", _painted(sweep([knot, knot + Vector((dx * 0.5, -0.016, -ln * 0.5)), e],
                                              [0.008, 0.008, 0.006], n=4, name="cord_end"), CORD, var=0.2, ao=0.0,
                                        seed=10)))
    pouch_c = _on_coat(-0.15, 0.9, -1, 0.03)
    pouch = L.part("sphere", STRAP, loc=pouch_c, radius=1.0, scale=(0.05, 0.03, 0.06), segments=10, ring_count=6,
                   jit=0.004, seed=11, paint_kw={"var": 0.2, "ao": 0.25, "top": 0.3})
    parts.append(W("hips", pouch))
    parts.append(W("hips", L.part("cyl", STRAP, loc=pouch_c + Vector((0, 0, 0.065)), radius=0.03, depth=0.02,
                                  vertices=8, paint_kw={"ao": 0.0})))
    # coat buttons: a few dull horn toggles on the chest
    for z in (1.12, 1.2, 1.28):
        p = _on_coat(0.03, z, -1, 0.006)
        parts.append(W("spine", L.part("sphere", BRASS, loc=p, radius=0.012, segments=6, ring_count=4,
                                       scale=(1.3, 0.6, 0.8), paint_kw={"ao": 0.0, "top": 0.4})))


def _arms(parts) -> None:
    for sx in (-1, 1):
        bone = _side(sx, "arm")
        sh, wr = SHOULDER[sx], WRIST[sx]
        el = sh.lerp(wr, 0.5) + Vector((sx * 0.012, 0.02, 0.0))
        sleeve = sweep([sh, sh.lerp(el, 0.5), el, el.lerp(wr, 0.6), wr], [0.058, 0.056, 0.054, 0.06, 0.07], n=10,
                       name="sleeve")
        _painted(sleeve, COAT, var=0.15, ao=0.15, seed=12 + sx, hue_shift=COAT_DARK)
        axis = (wr - sh).normalized()
        _tint(sleeve, lambda co, nr, sh=sh, axis=axis: (
            1.0 - 0.14 * max(0.0, math.sin((co - sh).dot(axis) * 40.0 + co.x * 30.0)), None, 0.0))
        parts.append(W(bone, sleeve))
        # wide turned-back cuff (darker lining)
        cuff = sweep([wr - axis * 0.035, wr + axis * 0.012], [0.074, 0.08], n=10, name="cuff")
        parts.append(W(bone, _painted(cuff, LINING, var=0.15, ao=0.0, top=0.3, seed=14)))
        parts.append(W(bone, L.part("sphere", COAT, loc=sh + Vector((sx * 0.004, 0, -0.01)), radius=0.058,
                                    segments=10, ring_count=6, scale=(1.0, 0.95, 0.9), paint_kw={"top": 0.2})))
        # long bony hand
        hc = wr + axis * 0.06
        palm = L.part("sphere", SKIN, loc=hc, radius=1.0, scale=(0.022, 0.042, 0.05), segments=10, ring_count=6,
                      jit=0.002, seed=15, paint_kw={"ao": 0.2, "var": 0.08})
        parts.append(W(bone, palm))
        if sx > 0:  # left fist closed round the lantern bail
            parts.append(W(bone, L.part("sphere", L.mix(SKIN, SKIN_HOLLOW, 0.25), loc=hc + Vector((0.0, -0.022, -0.03)),
                                        radius=1.0, scale=(0.024, 0.03, 0.032), segments=8, ring_count=5,
                                        paint_kw={"ao": 0.2})))
        else:       # right hand hangs open, long fingers
            for k, dx in enumerate((-0.012, 0.0, 0.012)):
                f0 = hc + Vector((dx * 0.8, -0.012 + abs(dx), -0.035))
                f1 = f0 + Vector((dx * 0.4, -0.012, -0.055 + abs(dx) * 1.2))
                parts.append(W(bone, _painted(sweep([f0, f0.lerp(f1, 0.5) + Vector((0, -0.006, 0)), f1],
                                                    [0.0085, 0.008, 0.0065], n=5, name="finger"), SKIN, ao=0.1,
                                              var=0.06, seed=16 + k)))
        thumb = sweep([hc + Vector((-sx * 0.016, -0.025, 0.02)), hc + Vector((-sx * 0.02, -0.042, -0.012)),
                       hc + Vector((-sx * 0.018, -0.045, -0.035))], [0.011, 0.01, 0.008], n=5, name="thumb")
        parts.append(W(bone, _painted(thumb, SKIN, ao=0.1, var=0.06, seed=19)))


def _head(parts) -> None:
    """G7 Änderungsrunde 1: the shared sculpted head (lib_faces) - a long narrow face with a pointed
    chin and hollow cheeks, awake grey eyes under heavy calm lids, thin brows raised a little at the
    inner end (polite attention), a long straight nose, a thin kind mouth; iron-grey hair parted in the
    middle as a shell, two strands falling out of the hood. Pale, but warm (blush, not grey)."""
    h = HEAD_C
    s = Vector((0.1, 0.112, 0.134))
    skin = L.mix(SKIN, SKIN_WARM, 0.4)
    pts = F._head(parts, h, s, skin, seed=30, nose="long", nose_s=1.15, brow=L.scale_c(HAIR, 0.7), brow_w=0.95,
                  brow_tilt=0.35, brow_arch=0.8, mouth="kind", smile=0.5, lip=LIP, cheeks=0.4,
                  cheek_col=L.hexc("#C98C7E"), jaw=0.8, chin=0.07, age=0.5, lids=0.36, iris=F.IRIS_GREY, muzzle=0.85,
                  ears=False, seg=22, rings=16, res=0.8, shade_col=L.mix(F.FACE_SHADE, SKIN_HOLLOW, 0.4),
                  cull=lambda n: n.y > 0.25 or n.z > 0.6)
    face = pts["face"]
    F._hair(parts, face, HAIR, L.scale_c(HAIR, 0.72), [(0.0, 0.5), (0.5, 0.42), (1.0, 0.14), (1.4, -0.22),
                                                       (1.8, -0.4), (math.pi, -0.5)], out=0.005, crown=0.004,
            part_u=0.0, tuft=0.004, seed=34, n=20, m=5)
    for sx in (-1, 1):
        root = face.world(F.Face.around(sx * 1.05, 0.2), 0.006)
        pts_ = [root, root + Vector((sx * 0.012, -0.012, -0.07)), root + Vector((sx * 0.004, -0.018, -0.15))]
        strand = sweep(pts_, [0.012, 0.011, 0.004], n=5, name="strand")
        L.jitter(strand, 0.002, 30.0, 35 + sx)
        parts.append(W("head", _painted(strand, HAIR, var=0.2, ao=0.0, top=0.3, seed=35 + sx)))


def _hood_front_y(x: float, z: float, out: float = 0.0) -> float:
    kx = x / (HOOD_R.x + out)
    kz = (z - HOOD_C.z) / (HOOD_R.z + out)
    return HOOD_C.y - (HOOD_R.y + out) * math.sqrt(max(0.0, 1.0 - kx * kx - kz * kz))


def _hood(parts) -> None:
    """Deep hood over the head, pointed at the back, a rolled rim round the face opening,
    a cowl down onto the shoulders and the crane feather tucked in on her left."""
    hood = L.prim("sphere", loc=HOOD_C, radius=1.0, segments=22, ring_count=12, scale=tuple(HOOD_R))
    bm = bmesh.new()
    bm.from_mesh(hood.data)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        ex = c.x / OPEN_W
        ez = (c.z - OPEN_Z) / OPEN_H
        if (c.y < HOOD_C.y - 0.02 and ex * ex + ez * ez < 1.0) or c.z < HOOD_C.z - 0.13:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for v in bm.verts:  # pull the crown back into a soft point
        d = v.co - HOOD_C
        if d.y > 0.0 and d.z > 0.0:
            k = (d.y / HOOD_R.y) * (d.z / HOOD_R.z)
            v.co.y += 0.06 * k
            v.co.z += 0.02 * k
    bm.to_mesh(hood.data)
    bm.free()
    _thicken(hood, 0.014)
    L.jitter(hood, 0.004, 6.0, 40)
    _painted(hood, COAT, var=0.16, ao=0.12, top=0.18, seed=41, hue_shift=COAT_DARK,
             zrange=(HOOD_C.z - 0.15, HOOD_C.z + 0.17))

    def inner(co, nr):
        to_c = (HOOD_C - co)
        if nr.dot(to_c) > 0.0:   # inside of the hood: deep shadow round the face
            return 0.55, LINING, 0.8
        a = math.atan2(co.z - HOOD_C.z, co.x)
        return 1.0 - 0.1 * max(0.0, math.sin(a * 6.0 + co.y * 20.0)), COAT_DUST, 0.2 * max(0.0, nr.z)
    _tint(hood, inner)
    parts.append(W("head", hood))
    # rolled rim round the face opening
    rim = []
    for k in range(20):
        a = math.tau * k / 20
        x, z = OPEN_W * math.cos(a), OPEN_Z + OPEN_H * math.sin(a)
        rim.append(Vector((x, _hood_front_y(x, z, 0.008), z)))
    rim_o = sweep(rim, 0.016, n=6, closed=True, name="rim")
    L.jitter(rim_o, 0.003, 12.0, 43)
    parts.append(W("head", _painted(rim_o, COAT_DARK, var=0.18, ao=0.0, top=0.25, seed=43, hue_shift=COAT)))
    # cowl: the hood's drape over the neck and onto the shoulders
    cowl = loft([(1.4, 0.172, 0.142, 0.0, 0.004), (1.445, 0.148, 0.13, 0.0, 0.0), (1.5, 0.124, 0.12, 0.0, -0.012),
                 (1.545, 0.106, 0.114, 0.0, -0.02)], n=22, caps=(False, False), name="cowl")
    for v in cowl.data.vertices:
        a = math.atan2(v.co.y, v.co.x)
        f = 0.012 * math.sin(a * 5.0 + 0.4)
        v.co.x += math.cos(a) * f
        v.co.y += math.sin(a) * f
    _painted(cowl, COAT, var=0.16, ao=0.25, top=0.2, seed=44, hue_shift=COAT_DARK)
    _tint(cowl, lambda co, nr: (1.0 - 0.14 * max(0.0, math.sin(math.atan2(co.y, co.x) * 5.0 + 0.4)), COAT_DUST,
                                0.25 * max(0.0, nr.z)))
    parts.append(rig.weight_split_z(cowl, 1.47, "spine", "head"))
    # the crane feather: tucked into a stitch on her left, sweeping up and back
    fp = HOOD_C + Vector((0.125, 0.03, 0.06))
    fwd = Vector((0.2, 1.0, 0.72)).normalized()
    up = Vector((1.0, 0.0, -0.2))
    y = fwd
    x = y.cross(up).normalized()
    z = x.cross(y)
    fm = Matrix((x, y, z)).transposed().to_4x4()
    fm.translation = fp
    vane = L.prim("sphere", loc=(0, 0.12, 0), radius=1.0, segments=10, ring_count=8, scale=(0.027, 0.125, 0.004))
    for v in vane.data.vertices:  # asymmetric vane curving down at the tip
        v.co.x += 0.9 * (v.co.y - 0.12) ** 2
        v.co.z -= 1.2 * max(0.0, v.co.y - 0.1) ** 2
    _xf(vane, fm)
    _painted(vane, FEATHER, var=0.12, ao=0.0, top=0.3, seed=45)
    tip_y = 0.18
    _tint(vane, lambda co, nr: (1.0, FEATHER_TIP, 0.95 if (fm.inverted() @ co).y > tip_y else
                                (0.12 if int((fm.inverted() @ co).y * 90) % 3 == 0 else 0.0)))
    parts.append(W("head", vane))
    parts.append(W("head", _painted(_xf(sweep([Vector((0, -0.02, 0)), Vector((0, 0.24, -0.004))], [0.003, 0.0015],
                                              n=4, name="quill"), fm), L.hexc("#D8D4C6"), ao=0.0, var=0.05, seed=46)))
    parts.append(W("head", L.part("ico", CORD, loc=fp + Vector((0.004, 0, 0)), radius=0.012, subdivisions=1,
                                  paint_kw={"ao": 0.0})))


def _basket(parts) -> None:
    """Wicker back-basket: tapered, wider at the top, staves and woven bands, a linen bundle
    and a folded cloth on top, shoulder straps, the pressed elder blossom and two braids."""
    z0, z1 = 0.96, 1.5
    by = BASKET_Y
    n = 24
    rings = []
    for k in range(13):
        t = k / 12
        z = z0 + (z1 - z0) * t
        rx = 0.15 + 0.05 * t
        ry = 0.11 + 0.035 * t
        rings.append((z, rx, ry, 0.0, by + 0.02 * t))
    body = loft(rings, n=n, caps=(True, False), name="basket")
    for v in body.data.vertices:  # the straight back side rests against her
        if v.co.y < by - 0.06:
            v.co.y = by - 0.06 - (by - 0.06 - v.co.y) * 0.4
    _painted(body, WICKER, var=0.2, ao=0.3, top=0.1, zrange=(z0, z1), seed=50, hue_shift=WICKER_DARK)

    def weave(co, nr):
        a = math.atan2(co.y - by, co.x)
        k = int(round(a / (math.tau / n)))
        row = int(round((co.z - z0) / ((z1 - z0) / 12)))
        f = 0.72 + 0.42 * ((k + row) % 2)                      # over-and-under checker of the weave
        if k % 4 == 0:
            f *= 0.7                                           # staves
        return f, (WICKER_LIGHT if (k + row) % 2 else None), 0.35
    _tint(body, weave)
    parts.append(W("spine", body))
    # inner rim darkness
    inside = loft([(z1 - 0.1, 0.18, 0.13, 0.0, by + 0.018), (z1 - 0.005, 0.19, 0.138, 0.0, by + 0.02)], n=n,
                  caps=(True, False), name="basket_in")
    for f in inside.data.polygons:
        f.flip()
    parts.append(W("spine", _painted(inside, WICKER_DARK, var=0.1, ao=0.4, seed=51)))
    for z, r, rr in ((z0 + 0.01, 0.152, 0.018), (z1, 0.2, 0.02), (z0 + 0.27, 0.176, 0.012)):
        t = (z - z0) / (z1 - z0)
        ring = [Vector((math.cos(a) * (0.15 + 0.05 * t + 0.004), by + 0.02 * t + math.sin(a) * (0.11 + 0.035 * t + 0.004),
                        z)) for a in (math.tau * k / 16 for k in range(16))]
        for q in ring:
            if q.y < by - 0.06:
                q.y = by - 0.06 - (by - 0.06 - q.y) * 0.4
        parts.append(W("spine", _painted(sweep(ring, rr, n=5, closed=True, name="rim"), WICKER_DARK, var=0.2,
                                         ao=0.0, top=0.35, seed=52, hue_shift=WICKER)))
    # a rolled linen bundle and a folded grey cloth peeking out of the top
    parts.append(W("spine", L.part("cyl", LINEN, loc=(0.03, by + 0.03, z1 + 0.04), rot=(0, 78, 12), radius=0.055,
                                   depth=0.3, vertices=10, jit=0.006, seed=53,
                                   paint_kw={"ao": 0.2, "var": 0.12, "hue_shift": L.hexc("#B5AA8E")})))
    parts.append(W("spine", L.part("sphere", COAT_DARK, loc=(-0.06, by + 0.05, z1 + 0.015), radius=1.0,
                                   scale=(0.1, 0.09, 0.04), segments=10, ring_count=5, jit=0.01, seed=54,
                                   paint_kw={"ao": 0.2, "var": 0.18})))
    # shoulder straps: from the basket rim over the shoulders, down the chest, back under the arms
    for sx in (-1, 1):
        x = sx * 0.12
        pts = [Vector((sx * 0.13, by - 0.06, 1.44)), Vector((x, 0.1, 1.475)), Vector((x, -0.06, 1.46)),
               _on_coat(x, 1.36, -1, 0.012), _on_coat(sx * 0.15, 1.2, -1, 0.012),
               Vector((sx * 0.185, 0.02, 1.08)), Vector((sx * 0.14, by - 0.07, 1.02))]
        nrm = [(q - Vector((0.0, 0.0, 1.2))).normalized() for q in pts]
        nrm[0] = nrm[1] = Vector((0, 0, 1))
        strap = sweep(pts, 0.022, n=5, normals=nrm, flat=0.3, name="strap")
        parts.append(W("spine", _painted(strap, STRAP, var=0.2, ao=0.0, top=0.3, seed=55 + sx)))
    # the pressed elder blossom, tucked into the weave on her right side (the visible side of the
    # basket when she faces east at the wall): a flat cream umbel on a stem
    bc = Vector((-0.19, by + 0.05, 1.33))
    out = Vector((-1.0, 0.25, 0.0)).normalized()
    parts.append(W("spine", _painted(sweep([bc - Vector((0, 0, 0.1)), bc], 0.004, n=4, name="stem"),
                                     BLOSSOM_STEM, ao=0.0, var=0.1, seed=56)))
    for k in range(7):  # a flat umbel of dry florets
        ang = k / 7 * math.tau
        rr = 0.0 if k == 0 else 0.03
        side = Vector((0.0, math.cos(ang), math.sin(ang))) * rr
        fl = L.part("ico", L.scale_c(BLOSSOM, 0.92 + 0.06 * (k % 3)), loc=bc + out * 0.012 + side, radius=0.02,
                    subdivisions=1, scale=(0.45, 1.0, 1.0), jit=0.003, seed=57 + k, paint_kw={"ao": 0.0, "top": 0.25})
        _tint(fl, lambda co, nr: (1.0 - 0.3 * max(0.0, noise.noise(co * 120.0)), L.hexc("#BDB28E"), 0.3))
        parts.append(W("spine", fl))
    # two braids she bought, tied to the rim on her left, hanging down the side
    for k, (dx, col, ln) in enumerate(((0.0, BRAID_A, 0.2), (0.035, BRAID_B, 0.16))):
        top = Vector((0.2 + dx * 0.2, by + 0.01 + dx, z1 - 0.02))
        pts = [top, top + Vector((0.012, 0.0, -ln * 0.5)), top + Vector((0.008, 0.004, -ln))]
        br = sweep(pts, [0.016, 0.014, 0.008], n=6, name="braid")
        parts.append(W("spine", _painted(br, col, var=0.15, ao=0.1, top=0.2, seed=58 + k)))
        _tint(parts[-1], lambda co, nr: (1.0 - 0.3 * max(0.0, math.sin(co.z * 140.0 + co.x * 60.0)) ** 2, None, 0.0))
        parts.append(W("spine", L.part("sphere", CORD, loc=top + Vector((0.0, 0, -0.015)), radius=0.013,
                                       segments=6, ring_count=4, scale=(1, 1, 0.6), paint_kw={"ao": 0.0})))


def _lantern(parts) -> Vector:
    """Lantern with sooty glass hanging from the left fist: iron frame, roof, bail. The glass
    glows only through a clear band low down - the upper panes are blackened with soot."""
    lp = LANTERN
    bone = "arm_l"
    hw, hh = 0.042, 0.065
    for dz, sc in ((-hh - 0.006, (hw + 0.008, hw + 0.008, 0.008)), (hh + 0.004, (hw + 0.006, hw + 0.006, 0.007))):
        plate = L.prim("cube", loc=lp + Vector((0, 0, dz)), scale=sc)
        L.bevel(plate, 0.003, 1)
        parts.append(W(bone, _painted(plate, IRON, var=0.25, ao=0.0, top=0.35, seed=60)))
    parts.append(W(bone, L.part("cone", IRON, loc=lp + Vector((0, 0, hh + 0.03)), radius1=hw + 0.01, radius2=0.012,
                                depth=0.05, vertices=6, paint_kw={"ao": 0.0, "top": 0.4, "hue_shift": SOOT})))
    for cx, cy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        parts.append(W(bone, _painted(L.tube(lp + Vector((cx * hw, cy * hw, -hh)), lp + Vector((cx * hw, cy * hw, hh)),
                                             0.006, 5), IRON, var=0.2, ao=0.0, seed=61)))
    # glowing core (shared warm emissive), then soot panes over its upper part
    parts.append(W(bone, L.part("cyl", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=lp + Vector((0, 0, -0.012)),
                                radius=hw - 0.004, depth=hh * 1.5, vertices=8)))
    for k in range(4):
        a = k * math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0.0))
        s = Vector((-d.y, d.x, 0.0))
        pane = L.prim("cube", scale=(0.004, hw - 0.004, 0.034))
        _xf(pane, Matrix.Translation(lp + d * (hw - 0.001) + Vector((0, 0, hh - 0.036)))
            @ Matrix.Rotation(a, 4, "Z"))
        _painted(pane, SOOT, var=0.35, ao=0.0, top=0.0, seed=62 + k, hue_shift=L.hexc("#3A322A"))
        parts.append(W(bone, pane))
        del s
    # bail from the roof up into the fist
    fist = WRIST[1] + (WRIST[1] - SHOULDER[1]).normalized() * 0.075
    ring_top = lp + Vector((0, 0, hh + 0.06))
    parts.append(W(bone, L.part("torus", IRON, loc=ring_top, rot=(90, 0, 0), major_radius=0.014, minor_radius=0.0035,
                                major_segments=8, minor_segments=4, paint_kw={"ao": 0.0})))
    for sx in (-1, 1):
        parts.append(W(bone, _painted(sweep([lp + Vector((sx * (hw + 0.004), 0, hh + 0.004)),
                                             lp + Vector((sx * 0.03, 0, hh + 0.07)), fist + Vector((sx * 0.012, 0, -0.01))],
                                            0.0032, n=4, name="bail"), IRON, var=0.2, ao=0.0, seed=66)))
    return lp + Vector((0, 0, -0.012))


def _global_light(mesh) -> None:
    """Whole-figure painterly pass (as Osric): ink-blue towards the ground, warm on the shoulders."""
    ink = L.hexc("#1F2A3A")
    warm = L.hexc("#D8B98A")
    attr = mesh.data.color_attributes["Col"]
    for li, co, nr in _loops(mesh):
        c = attr.data[li].color
        low = max(0.0, 1.0 - co.z / 0.7) ** 2
        high = max(0.0, (co.z - 1.25) / 0.5) * max(0.0, nr.z)
        rgb = [x * (1.0 - 0.16 * low) for x in c[:3]]
        rgb = [x + (L._to_lin(k) - x) * 0.12 * low for x, k in zip(rgb, ink)]
        rgb = [x + (L._to_lin(k) - x) * 0.1 * high for x, k in zip(rgb, warm)]
        attr.data[li].color = (rgb[0], rgb[1], rgb[2], 1.0)


def build_mesh():
    """Returns (rigidly weighted mesh, lantern light position, coin position) in model space."""
    L.reset(91)
    parts = []
    _legs(parts)
    _coat(parts)
    _arms(parts)
    _head(parts)
    _hood(parts)
    _basket(parts)
    light = _lantern(parts)
    mesh = L.join(parts, rig.MESH)
    _global_light(mesh)
    L.smooth(mesh, 55)
    coins = WRIST[-1] + (WRIST[-1] - SHOULDER[-1]).normalized() * 0.06 + Vector((0.0, -0.03, 0.0))
    return mesh, light, coins


def joints(dz: float) -> dict:
    def p(x, y, z):
        return (x, y, z - dz)
    j = {
        "root": (p(0, 0, dz), p(0, 0, dz + 0.3)),
        "hips": (p(0, 0.0, 0.88), p(0, 0.0, WAIST_Z)),
        "spine": (p(0, 0.0, WAIST_Z), p(0, -0.02, 1.5)),
        "head": (p(0, -0.03, 1.49), p(0, -0.04, 1.84)),
    }
    for sx in (-1, 1):
        j[_side(sx, "arm")] = (p(*SHOULDER[sx]), p(*WRIST[sx]))
        j[_side(sx, "leg")] = (p(sx * 0.088, 0.0, 0.92), p(sx * 0.085, 0.0, 0.1))
    return j


# --- actions (pose functions, see rig.py for the conventions) ---------------------------

def idle(t: float) -> dict:
    """72 frames = 2.4 s: slow shallow breathing, the head tilts a little like a listening bird,
    the lantern hand stays still."""
    s = math.sin(rig.TAU * t)
    return rig.add(rig.breathe(t, 0.9), {
        "head": (1.0 * math.sin(rig.TAU * t * 2.0), 3.5 * s, 1.5 * s),
        "spine": (0.0, -0.8 * s, 0.0),
        "arm_l": (-0.6 * s, 0.0, 0.0),
    })


def walk(t: float) -> dict:
    """21 frames = 0.7 s per cycle: a calm, upright, gliding step (~1.3 m/s) that stays inside
    the long coat; the lantern arm barely swings, the free arm a little."""
    g = rig.gait(t, leg=16.0, lift=0.035, arm=10.0, bob=0.01, roll=2.0, yaw=3.0, lean=1.5)
    s = math.sin(rig.TAU * t)
    return rig.add(g, {"arm_l": (-7.0 * s, 0.0, 0.0), "head": (0.0, 0.0, 1.5 * s)})


def talk(t: float) -> dict:
    """72 frames = 2.4 s: speaks quietly, the right hand turns a little, palm up; the head
    inclines; the lantern hand stays low."""
    a = {"arm_r": (-20.0, 0.0, -3.0), "head": (3.0, -3.0, 2.0), "spine": (1.0, 0.0, 1.0)}
    b = {"arm_r": (-40.0, 6.0, -8.0), "head": (5.0, 4.0, -2.0), "spine": (2.0, 0.0, 2.0)}
    c = {"arm_r": (-28.0, 10.0, -4.0), "head": (1.0, 2.0, 3.0), "spine": (0.5, 0.0, 0.0)}
    d = {"arm_r": (-44.0, 2.0, -10.0), "head": (4.0, -4.0, 0.0), "spine": (1.5, 0.0, 1.5)}
    keys = [(0.0, a), (0.25, b), (0.5, c), (0.75, d)]
    return rig.add(rig.breathe(t, 0.8, 2), {"arm_l": (-2.0, 0.0, 0.0)}, rig.keyed(t, keys))


def offer(t: float) -> dict:
    """30 frames = 1.0 s one-shot: a slight bow, the right hand reaches forward palm up (coins),
    holds, draws back."""
    reach = {"spine": (8.0, 0.0, 3.0), "head": (6.0, 0.0, 0.0),
             "arm_r": (-62.0, 6.0, -8.0), "arm_l": (-3.0, 0.0, 0.0), "hips": (0, 0, 0, 0, -0.01, 0)}
    return rig.add(rig.keyed(t, [(0.0, {}), (0.4, reach), (0.62, reach), (1.0, {})], wrap=False),
                   {"feet": {"leg_l": 0.0, "leg_r": 0.0}})


ACTIONS = (  # (name, frames at 30 fps, pose function)
    ("idle-loop", 72, idle),
    ("walk-loop", 21, walk),
    ("talk-loop", 72, talk),
    ("offer", 30, offer),
)


def build():
    mesh, light, coins = build_mesh()
    dz = rig.ground(mesh)
    arm = rig.build_armature(joints(dz))
    rig.bind(mesh, arm)
    rig.bone_marker(arm, "arm_l", "light_lantern", light - Vector((0, 0, dz)))
    rig.bone_marker(arm, "arm_r", "coins", coins - Vector((0, 0, dz)))
    for name, frames, fn in ACTIONS:
        rig.add_action(arm, mesh, name, frames, fn)
    L.export_rigged(arm, NAME, "characters")
    F._stable_glb(L.os.path.join(L.ROOT, "assets", "models", "characters", NAME + ".glb"))


if __name__ == "__main__":
    build()
