"""Shared helpers for the 'Gemaltes Diorama' art-direction prototype.

Every asset script builds its geometry procedurally, paints vertex colours
(base colour + noise variation + fake ambient occlusion + top light), assigns
named materials (mapped to Godot materials on import) and writes:
  art_source/blender/<category>/<name>.blend
  assets/models/<category>/<name>.glb
Rigged characters use rig.py (shared 8-bone rig, rigid skinning, procedural
actions) and export_rigged() instead of finish()/export().

Run:  python tools/blender/build_all.py   (needs the `bpy` module, Blender 5.x)
"""
import json
import math
import os
import random

import bpy  # must be imported before bmesh
import bmesh
from mathutils import Matrix, Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Material names = Godot material files in res://assets/materials/<name>.tres
MAT_PAINTED = "mat_painted"
MAT_FOLIAGE = "mat_foliage"
MAT_GRASS = "mat_grass"
MAT_EMISSIVE = "mat_emissive_warm"
MAT_GROUND = "mat_ground"


def load_layout() -> dict:
    with open(os.path.join(ROOT, "data", "art_prototype", "layout.json"), encoding="utf-8") as f:
        return json.load(f)


# --- colour ---------------------------------------------------------------

def _to_lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h: str) -> tuple:
    """sRGB hex -> sRGB float tuple (painting happens in sRGB, converted on write)."""
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def scale_c(c, f):
    return tuple(max(0.0, min(1.0, x * f)) for x in c)


# --- scene ----------------------------------------------------------------

def reset(seed: int = 1) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    random.seed(seed)


def get_mat(name: str) -> bpy.types.Material:
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    return m


def _apply(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def prim(kind: str, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), **kw):
    """Create a primitive, apply its transform, return the object.
    Order: scale -> rotate -> translate (all about the primitive's own centre)."""
    ops = {
        "cube": bpy.ops.mesh.primitive_cube_add,
        "cyl": bpy.ops.mesh.primitive_cylinder_add,
        "cone": bpy.ops.mesh.primitive_cone_add,
        "sphere": bpy.ops.mesh.primitive_uv_sphere_add,
        "ico": bpy.ops.mesh.primitive_ico_sphere_add,
        "plane": bpy.ops.mesh.primitive_plane_add,
        "grid": bpy.ops.mesh.primitive_grid_add,
        "torus": bpy.ops.mesh.primitive_torus_add,
    }
    ops[kind](location=loc, rotation=[math.radians(r) for r in rot], **kw)
    obj = bpy.context.active_object
    obj.scale = scale
    _apply(obj)
    return obj


def subdivide(obj, cuts: int = 1) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bm.to_mesh(obj.data)
    bm.free()


def bevel(obj, width: float = 0.02, segments: int = 1) -> None:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=width, segments=segments,
                    affect="EDGES", profile=0.5)
    bm.to_mesh(obj.data)
    bm.free()


def jitter(obj, amount: float = 0.03, freq: float = 2.0, seed: int = 0) -> None:
    """Hand-made wobble: displace vertices with smooth 3D noise."""
    off = Vector((seed * 13.1, seed * 7.7, seed * 3.3))
    for v in obj.data.vertices:
        p = v.co * freq + off
        v.co += Vector((noise.noise(p), noise.noise(p + Vector((5.2, 1.3, 9.1))),
                        noise.noise(p + Vector((2.9, 8.4, 4.6))))) * amount


def taper(obj, axis_z0: float, axis_z1: float, top_scale: float) -> None:
    """Scale XY linearly along Z (z0 -> 1.0, z1 -> top_scale)."""
    for v in obj.data.vertices:
        t = (v.co.z - axis_z0) / max(1e-6, axis_z1 - axis_z0)
        t = min(1.0, max(0.0, t))
        s = 1.0 + (top_scale - 1.0) * t
        v.co.x *= s
        v.co.y *= s


def bend(obj, amount: float, z0: float, z1: float, axis: str = "x") -> None:
    """Quadratic bend along Z (for crooked shapes)."""
    for v in obj.data.vertices:
        t = (v.co.z - z0) / max(1e-6, z1 - z0)
        t = min(1.0, max(0.0, t))
        d = amount * t * t
        if axis == "x":
            v.co.x += d
        else:
            v.co.y += d


def paint(obj, base, var: float = 0.10, ao: float = 0.35, top: float = 0.12,
          zrange=None, noise_freq: float = 1.6, hue_shift=None, seed: int = 0) -> None:
    """Vertex-paint an object: base colour, noise brightness/hue variation,
    darker towards the ground (fake AO), brighter on up-facing faces."""
    me = obj.data
    attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    zs = [v.co.z for v in me.vertices]
    z0, z1 = zrange if zrange else (min(zs), max(zs))
    off = Vector((seed * 3.7, seed * 1.9, seed * 5.3))
    for poly in me.polygons:
        up = max(0.0, poly.normal.z)
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index]
            p = v.co * noise_freq + off
            n = noise.noise(p)
            h = (v.co.z - z0) / max(1e-6, z1 - z0)
            h = min(1.0, max(0.0, h))
            f = (1.0 + n * var) * (1.0 - ao * (1.0 - h) ** 2) * (1.0 + top * up)
            c = scale_c(base, f)
            if hue_shift is not None:
                c = mix(c, hue_shift, max(0.0, noise.noise(p * 0.7 + Vector((9, 9, 9)))) * 0.8)
            attr.data[li].color = (_to_lin(c[0]), _to_lin(c[1]), _to_lin(c[2]), 1.0)


def set_mat(obj, name: str) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(get_mat(name))


def part(kind: str, color, mat: str = MAT_PAINTED, jit: float = 0.0, jfreq: float = 2.0,
         seed: int = 0, paint_kw=None, **kw):
    """Primitive + optional wobble + paint + material in one call."""
    obj = prim(kind, **kw)
    if jit > 0:
        jitter(obj, jit, jfreq, seed)
    paint(obj, color, seed=seed, **(paint_kw or {}))
    set_mat(obj, mat)
    return obj


def join(objs, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    return obj


def smooth(obj, angle: float = 35.0) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))


def finish(obj, name: str, category: str, smooth_angle: float = 35.0, shift: bool = True) -> None:
    """Pivot = bottom centre (ground contact at z=0), save .blend, export .glb.
    shift=False keeps z as modelled (e.g. tree roots that reach below ground)."""
    smooth(obj, smooth_angle)
    zs = [v.co.z for v in obj.data.vertices]
    zmin = min(zs) if shift else 0.0
    for v in obj.data.vertices:
        v.co.z -= zmin
    for child in obj.children:
        child.location.z -= zmin
    export(obj, name, category)


def _quantize_uvs(objs) -> None:
    """Deterministic exports: some bmesh ops (bevel, joins) interpolate UVs with a 1-ulp jitter that
    differs from run to run, so the .glb bytes changed on every export (Phase-5 finding,
    ph_env_workstone_ledge).  Snapping every UV to a 1/4096 grid makes repeated builds byte-identical;
    the painted shaders never sample UVs."""
    for o in objs:
        if o.type != "MESH":
            continue
        for layer in o.data.uv_layers:
            for d in layer.data:
                d.uv = (round(d.uv[0] * 4096.0) / 4096.0, round(d.uv[1] * 4096.0) / 4096.0)


def _canonical_glb(path: str) -> None:
    """Deterministic exports, part 2: for some meshes (sweeps / lofts of the figures) the glTF exporter
    wrote the same triangles in a different order on every run.  Sort the triangles of every indexed
    primitive in place - the draw order inside one opaque surface does not matter."""
    import struct
    with open(path, "rb") as f:
        data = bytearray(f.read())
    jlen = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + jlen]))
    bin0 = 20 + jlen + 8
    fmt = {5121: "B", 5123: "H", 5125: "I"}
    for mesh in doc.get("meshes", []):
        for prim in mesh.get("primitives", []):
            if "indices" not in prim or prim.get("mode", 4) != 4:
                continue
            acc = doc["accessors"][prim["indices"]]
            view = doc["bufferViews"][acc["bufferView"]]
            ch = fmt[acc["componentType"]]
            off = bin0 + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
            n = acc["count"]
            idx = struct.unpack_from("<%d%s" % (n, ch), data, off)
            tris = sorted(tuple(idx[i:i + 3]) for i in range(0, n - n % 3, 3))
            flat = [v for t in tris for v in t] + list(idx[n - n % 3:])
            struct.pack_into("<%d%s" % (n, ch), data, off, *flat)
    with open(path, "wb") as f:
        f.write(data)


def export(obj, name: str, category: str) -> None:
    """Save .blend source and export .glb for one finished object."""
    obj.name = name
    _quantize_uvs([obj] + list(obj.children))
    blend_dir = os.path.join(ROOT, "art_source", "blender", category)
    glb_dir = os.path.join(ROOT, "assets", "models", category)
    os.makedirs(blend_dir, exist_ok=True)
    os.makedirs(glb_dir, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children:
        child.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(glb_dir, name + ".glb"), export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True,
        export_vertex_color="ACTIVE",
    )
    _canonical_glb(os.path.join(glb_dir, name + ".glb"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, name + ".blend"), compress=True)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[asset] {category}/{name}  tris={tris}")


def export_rigged(armature, name: str, category: str) -> None:
    """Save .blend source and export .glb for a rigged character (see rig.py).
    The armature is the glTF root; every action becomes its own NLA track and is
    exported as one animation (names ending in -loop are looped by Godot)."""
    blend_dir = os.path.join(ROOT, "art_source", "blender", category)
    glb_dir = os.path.join(ROOT, "assets", "models", category)
    os.makedirs(blend_dir, exist_ok=True)
    os.makedirs(glb_dir, exist_ok=True)
    _quantize_uvs(armature.children_recursive)
    ad = armature.animation_data or armature.animation_data_create()
    on_track = {s.action for t in ad.nla_tracks for s in t.strips}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        act.use_fake_user = True
        if act in on_track:
            continue
        ad.action = act  # assign (binds the action slot), then push down onto its own track
        track = ad.nla_tracks.new()
        track.name = act.name
        track.strips.new(act.name, int(act.frame_range[0]), act)
        track.mute = True  # the .blend opens in rest pose (unmuted strips would blend all actions)
        ad.action = None
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for child in armature.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(glb_dir, name + ".glb"), export_format="GLB",
        use_selection=True, export_apply=True, export_yup=True,
        export_vertex_color="ACTIVE", export_animation_mode="ACTIONS",
        export_force_sampling=True,
    )
    _canonical_glb(os.path.join(glb_dir, name + ".glb"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(blend_dir, name + ".blend"), compress=True)
    meshes = [c for c in armature.children_recursive if c.type == "MESH"]
    tris = sum(len(p.vertices) - 2 for m in meshes for p in m.data.polygons)
    print(f"[asset] {category}/{name}  tris={tris}  actions={sorted(a.name for a in bpy.data.actions)}")


def marker(parent, name: str, loc) -> None:
    """Empty exported as a glTF node; Godot attaches lights etc. to it by name."""
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    e.parent = parent


def prism_x(poly_yz, x: float, thickness: float, name: str = "prism"):
    """Extrude a 2D polygon given in the YZ plane along X (centred on x)."""
    bm = bmesh.new()
    a = [bm.verts.new((x - thickness / 2, y, z)) for y, z in poly_yz]
    b = [bm.verts.new((x + thickness / 2, y, z)) for y, z in poly_yz]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(poly_yz)
    for i in range(n):
        bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return obj


def tube(start, end, radius: float, verts: int = 8, r_end=None):
    """Cylinder from start to end (world space), optionally tapered."""
    start, end = Vector(start), Vector(end)
    d = end - start
    obj = prim("cyl", radius=radius, depth=d.length, vertices=verts)
    if r_end is not None:
        taper(obj, -d.length / 2, d.length / 2, r_end / radius)
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    obj.data.transform(Matrix.Translation((start + end) / 2) @ rot)
    return obj
