"""Phase-6 props and figures (docs/PHASE6_DESIGN.md section 8), 'Gemaltes Diorama'.

  ph_prop_grave_pit_foot   the open grave of a lifted old grave: the same pit as ph_prop_grave_pit, the
                           spoil heap at the foot end (+Z Godot) because the old graves stand closer
  ph_chr_mourner_a..d      the silent mourners of the chapel ("Leute aus Hollerbrück"): seated, static
                           (no rig), dark clothes, heads bowed, no faces in detail -
                           a  a man in a hooded cloak          b  a woman in a headscarf and shawl
                           c  an old man with a wide felt hat  d  a woman in a hooded cape over a bonnet
                           Pivot = the floor under the middle of the seat (a pew_seat_n marker), the figure
                           faces its front (-Y Blender = +Z Godot) like the pew; seat height 0.45 m.

Run:  python tools/blender/build_all.py asset_props_phase6
"""
import math
import random

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh  # noqa: F401
from mathutils import Matrix, Vector, noise

import lib_painted as L
import asset_props_slice as P
from asset_carter import loft, sweep, _tint

SEAT = 0.45
SKIN = L.hexc("#B8957E")           # muted, a little pale (the figures' family)
SKIN_SHADE = L.hexc("#8E7266")
BOOT = L.hexc("#2A2320")


# --- open grave with the spoil at the foot ----------------------------------------------------------

def grave_pit_foot():
    """ph_prop_grave_pit with the heap at the foot end (+Z Godot): a low, wide spoil bank and a few
    clods, no shovel (the old graves stand 1.8-1.9 m apart)."""
    L.reset(1900)
    parts = [P._pit_surface(28), P._heap(0.0, -1.45, 0.78, 0.34, 0.36, 7)]
    parts += P._clods(6, (-0.7, 0.7), (-1.25, -1.05), P.EARTH_FRESH, r=(0.03, 0.05), z=0.03, seed=20)
    obj = L.join(parts, "ph_prop_grave_pit_foot")
    L.finish(obj, "ph_prop_grave_pit_foot", "props", 50, shift=False)


# --- mourners -----------------------------------------------------------------------------------------

def _shade(obj, base, dark, zr=(0.0, 1.3), seed: float = 0.0, fold: float = 6.0):
    """Cloth: base colour with soft vertical folds, darker low down and in the hollows."""
    def fn(co, vi):
        h = max(0.0, min(1.0, (co.z - zr[0]) / (zr[1] - zr[0])))
        n = noise.noise(Vector((co.x * fold, co.y * fold, co.z * 1.5 + seed)))
        c = L.mix(dark, base, 0.55 + 0.35 * n)
        return L.scale_c(c, 0.78 + 0.28 * h)
    P._paint_fn(obj, fn)
    L.set_mat(obj, L.MAT_PAINTED)
    return obj


def _figure(parts, coat, coat_dark, lean: float = 0.26, skirt: bool = False, stout: float = 1.0, seed: int = 0):
    """Seated body: torso (bowed), arms folded in the lap, thighs + shins, boots; returns the head
    centre and the shoulder height."""
    hip = SEAT + 0.04
    rings = []
    prof = ((0.0, 0.2, 0.17), (0.12, 0.2, 0.16), (0.24, 0.19, 0.145), (0.36, 0.2, 0.14), (0.46, 0.2, 0.13),
            (0.53, 0.16, 0.11), (0.57, 0.08, 0.07))
    for dz, rx, ry in prof:
        z = hip + dz
        rings.append((z, rx * stout, ry * stout, 0.0, 0.03 - dz * lean))
    torso = loft(rings, n=16, p=2.3, name="torso")
    parts.append(_shade(torso, coat, coat_dark, (hip, hip + 0.6), seed))
    sh_z = hip + 0.5
    sh_y = 0.03 - 0.5 * lean
    # lap: the coat (or the skirt) over both thighs down to the shins
    if skirt:
        path = [Vector((0, 0.02, hip)), Vector((0, -0.2, hip + 0.02)), Vector((0, -0.4, hip - 0.02)),
                Vector((0, -0.46, hip - 0.2)), Vector((0, -0.48, 0.12))]
        lap = sweep(path, [0.2 * stout, 0.21 * stout, 0.2, 0.19, 0.2], n=10, flat=0.45,
                    normals=[(0, 0, 1), (0, 0, 1), (0, -0.6, 1), (0, -1, 0.2), (0, -1, 0)], name="lap")
        parts.append(_shade(lap, coat, coat_dark, (0.0, hip), seed + 1, fold=9.0))
    else:
        for sx in (-1, 1):
            path = [Vector((sx * 0.1, 0.02, hip)), Vector((sx * 0.11, -0.4, hip - 0.01)), Vector((sx * 0.1, -0.44, hip - 0.12)),
                    Vector((sx * 0.1, -0.46, 0.1))]
            leg = sweep(path, [0.095, 0.085, 0.075, 0.06], n=7, name="leg")
            parts.append(_shade(leg, L.scale_c(coat_dark, 0.9), L.scale_c(coat_dark, 0.7), (0.0, hip), seed + 2))
        # the coat hangs over the front of the thighs
        flap = sweep([Vector((0, 0.0, hip + 0.02)), Vector((0, -0.24, hip + 0.03)), Vector((0, -0.34, hip - 0.08))],
                     [0.19 * stout, 0.2 * stout, 0.2 * stout], n=8, flat=0.35,
                     normals=[(0, 0, 1), (0, 0, 1), (0, -0.6, 1)], name="flap")
        parts.append(_shade(flap, coat, coat_dark, (0.0, hip), seed + 3))
    for sx in (-1, 1):   # boots
        b = L.prim("cube", loc=(sx * 0.1, -0.52, 0.045), scale=(0.055, 0.12, 0.045))
        L.bevel(b, 0.02, 1)
        parts.append(P._finish_obj(b, BOOT, var=0.1, ao=0.2, top=0.3))
    # arms: sleeves down to the hands folded in the lap
    for sx in (-1, 1):
        s = Vector((sx * 0.19 * stout, sh_y + 0.01, sh_z))
        e = Vector((sx * 0.22 * stout, sh_y - 0.12, sh_z - 0.26))
        w = Vector((sx * 0.07, -0.3, hip + 0.1))
        arm = sweep([s, e, w], [0.07, 0.062, 0.055], n=7, name="arm")
        parts.append(_shade(arm, coat, coat_dark, (hip, sh_z), seed + 4))
    hands = L.prim("sphere", loc=(0.0, -0.33, hip + 0.1), radius=0.07, segments=8, ring_count=5, scale=(1.3, 0.9, 0.7))
    parts.append(P._finish_obj(hands, SKIN, var=0.1, ao=0.3, top=0.2, hue_shift=SKIN_SHADE))
    head = Vector((0.0, sh_y - 0.12, sh_z + 0.13))
    return head, sh_z, sh_y


def _head(parts, c: Vector, seed: int = 0):
    """Bowed head: only the lower face and nose catch the light under the headgear."""
    h = L.prim("sphere", loc=c, radius=0.1, segments=10, ring_count=7, scale=(0.95, 1.05, 1.1))
    h.data.transform(Matrix.Translation(c) @ Matrix.Rotation(math.radians(28), 4, "X") @ Matrix.Translation(-c))
    parts.append(P._finish_obj(h, SKIN, var=0.12, ao=0.45, top=0.1, hue_shift=SKIN_SHADE, seed=seed))
    nose = L.prim("cone", loc=c + Vector((0, -0.105, -0.02)), radius1=0.02, depth=0.05, vertices=4, rot=(110, 0, 0))
    parts.append(P._finish_obj(nose, L.scale_c(SKIN, 0.9), var=0.05, ao=0.0))


def _hood(parts, c: Vector, color, dark, deep: float = 1.0, seed: int = 0):
    """Deep hood: an ellipsoid shell around the head, pulled forward over the bowed face, falling into
    the collar behind."""
    rings = []
    for k in range(8):
        t = k / 7
        z = c.z - 0.2 + t * 0.34
        r = math.sin(math.pi * (0.15 + 0.85 * t)) * 0.15 + 0.02
        rings.append((z, r * 1.02, r * 1.12 * deep, 0.0, c.y + 0.025 - 0.05 * (1 - t)))
    hood = loft(rings, n=14, p=2.2, name="hood")
    # the face opening: the front of the lower half is pushed back a little and shaded (a dark hollow)
    for v in hood.data.vertices:
        if v.co.y < c.y - 0.1 and c.z - 0.13 < v.co.z < c.z + 0.07 and abs(v.co.x) < 0.07:
            v.co.y += 0.25 * (c.y - 0.1 - v.co.y)
    _shade(hood, color, dark, (c.z - 0.2, c.z + 0.15), seed)
    _tint(hood, lambda co, n: (0.45, None, 0.0) if (co.y < c.y - 0.06 and co.z < c.z + 0.05 and abs(co.x) < 0.1) else (1.0, None, 0.0))
    parts.append(hood)
    # the cloak over the shoulders
    cape = loft([(c.z - 0.3, 0.29, 0.22, 0.0, c.y + 0.12), (c.z - 0.22, 0.25, 0.2, 0.0, c.y + 0.1), (c.z - 0.14, 0.16, 0.15, 0.0, c.y + 0.08)],
                n=14, p=2.0, name="cape")
    parts.append(_shade(cape, color, dark, (c.z - 0.4, c.z), seed + 1))


def mourner_a():
    """A man in a long hooded cloak, charcoal-brown, head bowed deep into the hood."""
    L.reset(1910)
    parts = []
    coat, dark = L.hexc("#3E3934"), L.hexc("#2A2622")
    head, sh_z, sh_y = _figure(parts, coat, dark, lean=0.3, seed=1)
    _head(parts, head, 1)
    _hood(parts, head, L.hexc("#3A3530"), dark, seed=2)
    _mourner_done(parts, "ph_chr_mourner_a")


def mourner_b():
    """A woman in a dark skirt and jacket, a headscarf knotted under the chin and a fringed shawl."""
    L.reset(1920)
    parts = []
    coat, dark = L.hexc("#34383C"), L.hexc("#23262A")
    head, sh_z, sh_y = _figure(parts, coat, dark, lean=0.24, skirt=True, stout=0.95, seed=3)
    _head(parts, head, 3)
    scarf = L.prim("sphere", loc=head + Vector((0, 0.015, 0.02)), radius=0.118, segments=10, ring_count=6,
                   scale=(1.0, 1.06, 1.08))
    for v in scarf.data.vertices:     # open at the face
        if v.co.y < head.y - 0.07 and v.co.z < head.z + 0.06:
            v.co.y = head.y - 0.07
    _shade(scarf, L.hexc("#4A3E38"), L.hexc("#30282A"), (head.z - 0.12, head.z + 0.12), 4)
    parts.append(scarf)
    tail = L.prim("cone", loc=head + Vector((0, 0.12, -0.12)), radius1=0.09, depth=0.16, vertices=4, rot=(200, 0, 45))
    parts.append(_shade(tail, L.hexc("#4A3E38"), L.hexc("#30282A"), (head.z - 0.3, head.z), 5))
    shawl = loft([(sh_z - 0.16, 0.27, 0.21, 0.0, sh_y + 0.02), (sh_z - 0.04, 0.24, 0.19, 0.0, sh_y + 0.01),
                  (sh_z + 0.04, 0.16, 0.14, 0.0, sh_y)], n=16, p=2.0, name="shawl")
    parts.append(_shade(shawl, L.hexc("#5A4E44"), L.hexc("#3E342E"), (sh_z - 0.2, sh_z + 0.05), 6))
    _mourner_done(parts, "ph_chr_mourner_b")


def mourner_c():
    """An old man in a buttoned coat with a wide-brimmed felt hat, shoulders rounded."""
    L.reset(1930)
    parts = []
    coat, dark = L.hexc("#433A32"), L.hexc("#2C2621")
    head, sh_z, sh_y = _figure(parts, coat, dark, lean=0.34, stout=1.05, seed=7)
    _head(parts, head, 7)
    hair = L.prim("sphere", loc=head + Vector((0, 0.03, 0.0)), radius=0.105, segments=8, ring_count=5, scale=(1.0, 1.0, 0.9))
    parts.append(P._finish_obj(hair, L.hexc("#8A857C"), var=0.15, ao=0.3))
    tilt = Matrix.Translation(head) @ Matrix.Rotation(math.radians(24), 4, "X") @ Matrix.Translation(-head)
    crown = L.prim("cyl", loc=head + Vector((0, 0.0, 0.1)), radius=0.1, depth=0.12, vertices=10)
    L.taper(crown, head.z + 0.04, head.z + 0.16, 0.85)
    brim = L.prim("cyl", loc=head + Vector((0, 0.0, 0.045)), radius=0.21, depth=0.015, vertices=14)
    for v in brim.data.vertices:      # the brim droops a little at the sides
        v.co.z -= 0.02 * (abs(v.co.x - head.x) / 0.21) ** 2
    for o in (crown, brim):
        o.data.transform(tilt)
        parts.append(P._finish_obj(o, L.hexc("#2E2A26"), var=0.12, ao=0.2, top=0.25))
    band = L.prim("cyl", loc=head + Vector((0, 0.0, 0.07)), radius=0.103, depth=0.025, vertices=10)
    band.data.transform(tilt)
    parts.append(P._finish_obj(band, L.hexc("#4A3A2C"), var=0.05, ao=0.0))
    collar = loft([(sh_z - 0.02, 0.17, 0.13, 0.0, sh_y + 0.005), (sh_z + 0.06, 0.12, 0.1, 0.0, sh_y - 0.01)], n=12, p=2.0,
                  name="collar")
    parts.append(_shade(collar, dark, dark, (sh_z - 0.1, sh_z + 0.1), 8))
    _mourner_done(parts, "ph_chr_mourner_c")


def mourner_d():
    """A woman in a long hooded cape over her dress, a pale bonnet rim showing under the hood."""
    L.reset(1940)
    parts = []
    coat, dark = L.hexc("#3A3238"), L.hexc("#262126")
    head, sh_z, sh_y = _figure(parts, coat, dark, lean=0.22, skirt=True, stout=0.92, seed=9)
    _head(parts, head, 9)
    rim = L.prim("torus", loc=head + Vector((0, -0.05, 0.02)), rot=(70, 0, 0), major_radius=0.1, minor_radius=0.018,
                 major_segments=10, minor_segments=3)
    parts.append(P._finish_obj(rim, L.hexc("#CFC6B0"), var=0.08, ao=0.1))
    _hood(parts, head, L.hexc("#3E363C"), dark, deep=1.05, seed=10)
    _mourner_done(parts, "ph_chr_mourner_d")


def _mourner_done(parts, name: str) -> None:
    obj = L.join(parts, name)
    L.finish(obj, name, "characters", 50, shift=False)


ASSETS = [grave_pit_foot, mourner_a, mourner_b, mourner_c, mourner_d]


def build(names=None):
    """Build all assets, or only those whose function name is in `names`."""
    for fn in ASSETS:
        if names is None or fn.__name__ in names:
            fn()


if __name__ == "__main__":
    build()
