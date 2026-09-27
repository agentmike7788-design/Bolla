"""Ground (with painted path), old tree, grass tuft."""
import math
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Vector, noise

import lib_painted as L

GRASS_A = L.hexc("#55683F")
GRASS_B = L.hexc("#667A48")
GRASS_DRY = L.hexc("#7D7D4E")
DIRT = L.hexc("#6B5A48")
DIRT_DARK = L.hexc("#54463A")
BARK = L.hexc("#5A4A3C")
BARK_DARK = L.hexc("#3E3229")
LEAF_A = L.hexc("#44573A")
LEAF_B = L.hexc("#5E7145")
MOSS = L.hexc("#5E7148")


def _dist_to_polyline(p, pts):
    best = 1e9
    for a, b in zip(pts, pts[1:]):
        ab = (b[0] - a[0], b[1] - a[1])
        ap = (p[0] - a[0], p[1] - a[1])
        t = max(0.0, min(1.0, (ap[0] * ab[0] + ap[1] * ab[1]) / (ab[0] ** 2 + ab[1] ** 2)))
        dx, dy = ap[0] - ab[0] * t, ap[1] - ab[1] * t
        best = min(best, math.hypot(dx, dy))
    return best


def ground():
    """Ground tile. Layout is in Godot coords (x, z); Blender y = -z."""
    L.reset(30)
    lay = L.load_layout()
    size = lay["ground_size"]
    res = int(size / lay["ground_cell"])
    g = L.prim("grid", x_subdivisions=res, y_subdivisions=res, size=size)
    pts = lay["path"]["points"]
    half_w = lay["path"]["width"] * 0.5
    graves = [(gr["pos"][0], gr["pos"][1]) for gr in lay["graves"]]
    tree = lay["tree"]["pos"]
    hut = lay["hut"]["pos"]

    def path_mask(x, z):
        d = _dist_to_polyline((x, z), pts)
        edge = half_w + noise.noise(Vector((x * 1.3, z * 1.3, 0.5))) * 0.35
        return max(0.0, min(1.0, (edge - d) / 0.35 + 0.5))

    for v in g.data.vertices:
        x, z = v.co.x, -v.co.y
        h = noise.noise(Vector((x * 0.25, z * 0.25, 1.0))) * 0.06 + noise.noise(Vector((x, z, 3.0))) * 0.015
        h -= path_mask(x, z) * 0.035
        v.co.z = h

    me = g.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index]
            x, z = v.co.x, -v.co.y
            n1 = noise.noise(Vector((x * 0.35, z * 0.35, 7.0)))
            n2 = noise.noise(Vector((x * 1.7, z * 1.7, 9.0)))
            c = L.mix(GRASS_A, GRASS_B, 0.5 + 0.5 * n1)
            c = L.mix(c, GRASS_DRY, max(0.0, n2) * 0.35)
            # worn earth around graves, trunk and hut door
            wear = 0.0
            for gx, gz in graves:
                dx, dz = (x - gx) / 0.9, (z - gz) / 1.5
                wear = max(wear, 1.0 - math.sqrt(dx * dx + dz * dz))
            wear = max(wear, 1.0 - math.hypot(x - tree[0], z - tree[1]) / 2.0)
            wear = max(wear, 1.0 - math.hypot(x - hut[0], z - (hut[1] + 2.4)) / 2.2)
            c = L.mix(c, DIRT, max(0.0, min(1.0, wear * 1.4 + n2 * 0.3)) * 0.6)
            pm = path_mask(x, z)
            c = L.mix(c, L.mix(DIRT, DIRT_DARK, 0.5 + 0.5 * n2), pm)
            f = 1.0 + n2 * 0.06
            attr.data[li].color = (*[L._to_lin(min(1.0, ch * f)) for ch in c], 1.0)
    L.set_mat(g, L.MAT_GROUND)
    obj = g
    # no pivot shift for the ground: keep z = 0 as the reference plane
    L.smooth(obj, 80)
    L.export(obj, "ph_env_ground", "environment")


def _limb(start, direction, length, r0, r1, seed, segs=6, verts=8, droop=0.0):
    """Tapered, wobbly tube from start along direction (built directly with bmesh)."""
    d = Vector(direction).normalized()
    rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
    bm = bmesh.new()
    rings = []
    for k in range(segs + 1):
        t = k / segs
        r = r0 + (r1 - r0) * t
        cx = noise.noise(Vector((t * 3.0, seed, 0.0))) * length * 0.07
        cy = noise.noise(Vector((t * 3.0, 0.0, seed))) * length * 0.07
        ring = []
        for j in range(verts):
            a = j / verts * math.tau
            rr = r * (1.0 + noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, t * 4 + seed))) * 0.18)
            local = Vector((math.cos(a) * rr + cx, math.sin(a) * rr + cy, t * length))
            p = rot @ local + Vector(start) - Vector((0, 0, droop * t * t * length))
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for k in range(segs):
        for j in range(verts):
            a, b = rings[k][j], rings[k][(j + 1) % verts]
            c, e = rings[k + 1][(j + 1) % verts], rings[k + 1][j]
            bm.faces.new((a, b, c, e))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("limb")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("limb", me)
    bpy.context.collection.objects.link(obj)
    return obj


def tree():
    """Old gnarled oak: thick leaning trunk, roots diving into the ground,
    many small dark leaf clumps (reads as painted foliage, not cotton balls)."""
    L.reset(40)
    parts = []
    trunk = _limb((0, 0, -0.3), (0.22, 0.08, 1), 4.4, 0.52, 0.22, 1, segs=10, verts=12)
    parts.append(trunk)
    for i in range(6):  # root flares: short, diving into the ground
        a = i / 6 * math.tau + 0.4
        parts.append(_limb((math.cos(a) * 0.25, math.sin(a) * 0.25, 0.45), (math.cos(a), math.sin(a), -0.9),
                           random.uniform(0.8, 1.1), 0.22, 0.07, 10 + i, segs=3, verts=6))
    top = Vector((0.75, 0.25, 3.8))
    branches = [((1.0, 0.3, 0.45), 2.6), ((-0.9, 0.25, 0.55), 2.4), ((0.2, -1.0, 0.5), 2.1),
                ((-0.3, 0.95, 0.6), 2.2), ((0.3, 0.1, 1.0), 1.7), ((0.8, -0.6, 0.35), 1.9)]
    tips = []
    for i, (d, ln) in enumerate(branches):
        start = top - Vector((0, 0, 0.35 * (i % 3)))
        parts.append(_limb(start, d, ln, 0.17, 0.05, 20 + i, segs=4, verts=7, droop=0.18))
        tips.append(start + Vector(d).normalized() * ln)
    for p in parts:
        L.paint(p, BARK, var=0.22, ao=0.55, zrange=(0, 5.5), seed=3, hue_shift=MOSS if p is trunk else BARK_DARK)
        L.set_mat(p, L.MAT_PAINTED)
    leaves = []
    centres = tips + [top + Vector((0, 0, 0.9)), top + Vector((0.6, 0.4, 0.5)), top + Vector((-0.5, -0.3, 0.6))]
    for i, t in enumerate(centres):
        for j in range(5):
            r = random.uniform(0.5, 0.85)
            off = Vector((random.uniform(-0.8, 0.8), random.uniform(-0.8, 0.8), random.uniform(-0.35, 0.45)))
            s_ = L.prim("ico", loc=t + off, radius=r, subdivisions=2, scale=(1, 1, 0.7))
            L.jitter(s_, 0.22, 1.8, i * 5 + j)
            shade = random.random()
            L.paint(s_, L.mix(LEAF_A, LEAF_B, shade * 0.8), var=0.35, ao=0.65, top=0.35,
                    zrange=(2.8, 6.4), seed=i * 5 + j, hue_shift=L.hexc("#6E7A45") if shade > 0.6 else None)
            L.set_mat(s_, L.MAT_FOLIAGE)
            leaves.append(s_)
    obj = L.join(parts + leaves, "ph_env_tree_old_oak")
    L.finish(obj, "ph_env_tree_old_oak", "environment", 50, shift=False)


def grass_tuft():
    L.reset(50)
    bm = bmesh.new()
    blades = 9
    for i in range(blades):
        a = i / blades * math.tau + random.uniform(-0.3, 0.3)
        h = random.uniform(0.16, 0.34)
        lean = random.uniform(0.08, 0.2)
        w = 0.028
        base = Vector((math.cos(a) * 0.04, math.sin(a) * 0.04, 0))
        out = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        rows = []
        for k in range(4):
            t = k / 3
            c = base + out * (lean * t * t) + Vector((0, 0, h * t))
            ww = w * (1 - t) + 0.002
            rows.append((bm.verts.new(c - side * ww), bm.verts.new(c + side * ww)))
        for k in range(3):
            bm.faces.new((rows[k][0], rows[k][1], rows[k + 1][1], rows[k + 1][0]))
    me = bpy.data.meshes.new("ph_env_grass_tuft")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("ph_env_grass_tuft", me)
    bpy.context.collection.objects.link(obj)
    L.paint(obj, L.hexc("#849355"), var=0.15, ao=0.38, top=0.0, zrange=(0, 0.34), hue_shift=GRASS_DRY, seed=5)
    L.set_mat(obj, L.MAT_GRASS)
    L.finish(obj, "ph_env_grass_tuft", "environment", 80)


def build():
    ground()
    tree()
    grass_tuft()


if __name__ == "__main__":
    build()
