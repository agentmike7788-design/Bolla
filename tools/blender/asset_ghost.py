"""ph_chr_ghost (contract docs/PHASE3_DESIGN.md section 8): a hovering figure in a hooded burial
shirt with a fraying, tattered hem, holding a small soul light in both hands.

Rigid, no rig (movement by code, hem wave by the ghost shader): one body mesh plus a separate
mesh node `soul_orb` so the light can get its own (glowing) material, and the marker
`light_soul` in the orb.  Pivot = hem centre at the lowest tatter (z = 0); the robe trails
slightly backwards (+Y Blender = -Z Godot) so it reads as drifting.  Front = -Y (Godot +Z).

Shader-ready (assets/shaders/ghost.gdshader, P4):
  * vertex colour RGB: painted pale grey-green (fog #B7C2B0) with folds, dark hood opening;
  * vertex colour ALPHA: hem fade 0 at the tatter tips -> 1 from 0.55 m up (the painted
    materials ignore alpha, the ghost shader may use it instead of / with the height fade);
  * many rings in the lower robe so a TIME-based hem wave stays smooth;
  * shared material mat_painted on import (P4 overrides with mat_ghost).

Run:  python tools/blender/build_all.py asset_ghost
"""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P

SHIRT = L.hexc("#B7C2B0")        # fog colour of the palette
SHIRT_FOLD = L.hexc("#8C9A8E")
SHIRT_HEM = L.hexc("#9FB0AC")
HOOD_VOID = L.hexc("#1F2A3A")    # ink blue of the palette
SOUL = L.hexc("#6FE3D2")         # ghost turquoise - the only saturated cold colour
SOUL_CORE = L.hexc("#C8F6EE")
HAND = L.hexc("#C5CEC0")

N = 28                           # vertices around the robe
HEM_FADE = 0.55                  # alpha reaches 1 at this height above the tatter tips
TATTER = 0.09                    # how far the tatters hang below the hem line
SCALE = 0.92                     # final size: ~1.5 m from the tatter tips to the hood

# robe profile: (z, half width x, half depth y) from the hem up to the neck
ROBE = [(0.0, 0.35, 0.31), (0.06, 0.345, 0.305), (0.13, 0.335, 0.295), (0.21, 0.32, 0.28), (0.3, 0.3, 0.265),
        (0.4, 0.285, 0.25), (0.5, 0.272, 0.236), (0.61, 0.262, 0.222), (0.73, 0.255, 0.21), (0.85, 0.252, 0.2),
        (0.96, 0.25, 0.192), (1.05, 0.245, 0.182), (1.12, 0.228, 0.168), (1.18, 0.18, 0.14), (1.23, 0.12, 0.105)]


def _trail(z: float) -> float:
    """Backward drift (+Y) of the robe centre: the hem lags behind the shoulders."""
    return 0.1 * (1.0 - min(1.0, z / 1.2)) ** 2


def _robe():
    bm = bmesh.new()
    rings = []
    rnd = random.Random(7)
    tat = [rnd.uniform(0.35, 1.0) for _ in range(N)]
    for k, (z, rx, ry) in enumerate(ROBE):
        ring = []
        low = max(0.0, 1.0 - z / 0.9)                                # folds grow towards the hem
        for j in range(N):
            a = j / N * math.tau
            fold = 1.0 + 0.06 * low * math.sin(a * 7.0 + 0.6) + 0.025 * math.sin(a * 13.0 + 1.3) * low
            f = fold * (1.0 + noise.noise(Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, z * 2.2))) * 0.05)
            x, y = math.cos(a) * rx * f, math.sin(a) * ry * f + _trail(z)
            zz = z
            if k == 0:                                               # ragged, fraying hem: tatters hang down
                zz = -TATTER * tat[j] * (1.0 if j % 2 == 0 else 0.35)
            elif k == 1:
                zz = z - TATTER * 0.3 * tat[j] * (1.0 if j % 2 == 0 else 0.2)
            ring.append(bm.verts.new((x, y, zz)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for j in range(N):
            bm.faces.new((rings[k][j], rings[k][(j + 1) % N], rings[k + 1][(j + 1) % N], rings[k + 1][j]))
    # the inside of the hem (seen from low angles): a short inner skirt, darker
    inner = [bm.verts.new((v.co.x * 0.9, v.co.y * 0.9 + _trail(0) * 0.1, v.co.z + 0.12)) for v in rings[0]]
    for j in range(N):
        bm.faces.new((rings[0][(j + 1) % N], rings[0][j], inner[j], inner[(j + 1) % N]))
    return P._link(bm, "robe")


def _hood(parts):
    """Hood: a soft bulb with its point drooping back, a deep dark opening at the front."""
    h = L.prim("ico", loc=(0, 0.0, 1.36), radius=0.19, subdivisions=3, scale=(0.92, 1.0, 1.08))
    for v in h.data.vertices:
        back = max(0.0, v.co.y) / 0.19
        up = max(0.0, v.co.z - 1.36) / 0.2
        v.co.y += 0.09 * back * up                                  # hood point, drooping backwards
        v.co.z -= 0.03 * back * up
        if v.co.y < -0.1:                                           # flatten the face side a little
            v.co.y = -0.1 + (v.co.y + 0.1) * 0.6
    L.jitter(h, 0.008, 5.0, 3)
    parts.append(h)
    void = L.prim("sphere", loc=(0, -0.118, 1.33), radius=0.1, segments=12, ring_count=7, scale=(0.95, 0.42, 1.2))
    parts.append(void)
    rim = L.prim("torus", loc=(0, -0.13, 1.335), rot=(90, 0, 0), major_radius=0.105, minor_radius=0.024,
                 major_segments=14, minor_segments=5, scale=(0.95, 1.0, 1.25))
    parts.append(rim)
    for sx in (-1, 1):                                              # two faint glints deep in the hood
        parts.append(L.prim("ico", loc=(sx * 0.035, -0.152, 1.35), radius=0.011, subdivisions=1,
                            scale=(1.0, 0.6, 0.8)))
    return h, void, rim


def _sleeves(parts):
    """Bell sleeves from the shoulders down to the hands in front of the chest."""
    out = []
    for sx in (-1, 1):
        pts = [Vector((sx * 0.2, 0.01, 1.1)), Vector((sx * 0.25, -0.05, 1.0)), Vector((sx * 0.21, -0.15, 0.9)),
               Vector((sx * 0.13, -0.24, 0.86)), Vector((sx * 0.085, -0.28, 0.86))]
        radii = [0.075, 0.08, 0.085, 0.095, 0.105]
        s = P._tube(pts, radii, sides=9, hint=(0, 0, 1), caps=(False, False))
        me = s.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.to_mesh(me)
        bm.free()
        parts.append(s)
        out.append(s)
        cuff = P._tube([pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.005, pts[-2] * 0.3 + pts[-1] * 0.7],
                       [0.1, 0.075], sides=9, hint=(0, 0, 1), caps=(False, False))
        parts.append(cuff)                                          # inside of the sleeve opening (dark)
        out.append(cuff)
    return out


def _paint_part(obj, role: str, zmin: float):
    """RGB: pale shirt with darker folds and hem, dark ink hood opening, pale hands;
    ALPHA: hem fade (0 at the tatter tips -> 1 at HEM_FADE)."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        up = max(0.0, poly.normal.z)
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            h = co.z - zmin
            if role == "void":
                c = L.scale_c(HOOD_VOID, 0.75 + 0.5 * max(0.0, min(1.0, (co.y + 0.16) / 0.06)))
            elif role == "glint":
                c = L.mix(SOUL, SOUL_CORE, 0.3)
            elif role == "cuff":
                c = L.mix(SHIRT_FOLD, HOOD_VOID, 0.55)
            elif role == "hand":
                c = L.scale_c(HAND, 0.9 + 0.2 * up)
            else:
                a = math.atan2(co.y - _trail(h), co.x)
                low = max(0.0, 1.0 - h / 0.9)
                fold = 0.5 + 0.5 * math.sin(a * 7.0 + 0.6)
                c = L.mix(SHIRT, SHIRT_FOLD, (1.0 - fold) * 0.55 * low + 0.12)
                c = L.mix(c, SHIRT_HEM, max(0.0, 1.0 - h / 0.35) * 0.6)
                c = L.scale_c(c, (1.0 + noise.noise(co * 3.0) * 0.06) * (1.0 + 0.1 * up))
            alpha = max(0.0, min(1.0, h / (HEM_FADE / SCALE)))
            alpha = alpha * alpha * (3.0 - 2.0 * alpha)
            attr.data[li].color = (L._to_lin(c[0]), L._to_lin(c[1]), L._to_lin(c[2]), alpha)
    L.set_mat(obj, L.MAT_PAINTED)


def ghost():
    L.reset(700)
    robe = _robe()
    zmin = min(v.co.z for v in robe.data.vertices)
    parts = [robe]
    hood, void, rim = _hood(parts)
    glints = parts[-2:]
    sleeves = _sleeves(parts)
    hands = []
    for sx in (-1, 1):                                              # hands cupping the light
        hnd = L.prim("ico", loc=(sx * 0.055, -0.33, 0.855), radius=0.05, subdivisions=2, scale=(0.9, 1.1, 0.6),
                     rot=(0, sx * 25, 0))
        L.jitter(hnd, 0.006, 20.0, 10 + sx)
        parts.append(hnd)
        hands.append(hnd)
    for o in parts:
        role = ("void" if o is void else "glint" if o in glints else "cuff" if o in sleeves[1::2]
                else "hand" if o in hands else "shirt")
        _paint_part(o, role, zmin)
    body = L.join(parts, "ph_chr_ghost")
    # the soul light: its own mesh node so it can get a glowing material
    orb_c = Vector((0.0, -0.34, 0.915))
    orb = L.prim("ico", loc=orb_c, radius=0.062, subdivisions=2)
    L.jitter(orb, 0.004, 30.0, 5)
    P._paint_fn(orb, lambda co, vi: L.mix(SOUL, SOUL_CORE, max(0.0, min(1.0, (co.z - orb_c.z) / 0.06 + 0.5))))
    L.set_mat(orb, L.MAT_PAINTED)
    orb.name = "soul_orb"
    orb.data.name = "soul_orb"
    orb.parent = body
    L.marker(body, "light_soul", orb_c)
    # pivot: hem centre at the lowest tatter; a little smaller than the gravekeeper (~1.5 m)
    shift = Vector((0.0, -_trail(0.0), -zmin))
    xf = Matrix.Scale(SCALE, 4) @ Matrix.Translation(shift)
    body.data.transform(xf)
    orb.data.transform(xf)
    for child in body.children:
        if child.type == "EMPTY":
            child.location = xf @ child.location
    L.smooth(body, 60)
    L.smooth(orb, 80)
    L.export(body, "ph_chr_ghost", "characters")
    print(f"[asset]   soul_orb tris={sum(len(p.vertices) - 2 for p in orb.data.polygons)}")


def build(names=None):
    if names is None or "ghost" in names:
        ghost()


if __name__ == "__main__":
    build()
