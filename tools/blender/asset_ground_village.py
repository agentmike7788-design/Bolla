"""Ground of Hollerbrück (docs/PHASE7_DESIGN.md §4.2), 'Gemaltes Diorama' style.

Same painting as the graveyard ground (asset_ground_graveyard.py: moss-green noise, dry patches,
worn earth) on a 70 x 50 m grid around the village layout (data/world/village_layout.json,
region-local coords): the cobbled Anger and Kirchplatz (layout.paving, a warm grey-brown stone
tint with painted joints from noise – vertex colour only, no texture), the earth paths
(layout.paths), trodden earth in front of every door, the Hollerbach bed (flat under the water
mesh ph_env_brook, damp darker earth along the banks). Flat under the building footprints
(layout.footprints per model + ground.building_flat_margin) with a smooth falloff; each footprint
takes the unflattened height at its centre. The noise is a function of (x, z) only.

Grid vertices lie exactly on multiples of ground.cell (Godot coords), so the village builder looks
heights up by grid index.  Layout coords are Godot (x, z); Blender y = -z.

Run:  python tools/blender/asset_ground_village.py
      (or: python tools/blender/build_all.py asset_ground_village)
Out:  assets/models/environment/ph_env_ground_village.glb
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

import lib_painted as L  # noqa: E402

LAYOUT = os.path.join(L.ROOT, "data", "world", "village_layout.json")
NAME = "ph_env_ground_village"

# Palette of the graveyard ground (asset_ground_graveyard.py) + the village's stone and damp earth.
GRASS_A = L.hexc("#55683F")
GRASS_B = L.hexc("#667A48")
GRASS_DRY = L.hexc("#7D7D4E")
DIRT = L.hexc("#6B5A48")
DIRT_DARK = L.hexc("#54463A")
COBBLE = L.hexc("#80776A")
COBBLE_DARK = L.hexc("#61594F")
COBBLE_JOINT = L.hexc("#4A4339")
DAMP = L.hexc("#4E4A3A")

NOISE_LOW, NOISE_HIGH, PATH_DEPTH = 0.06, 0.015, 0.03
# The paving sits a little higher and smoother than the grass (painted stones, not modelled).
PAVING_SMOOTH = 0.6


def load_layout() -> dict:
    with open(LAYOUT, encoding="utf-8") as f:
        return json.load(f)


def _seg_dist(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1])
    ap = (p[0] - a[0], p[1] - a[1])
    den = ab[0] ** 2 + ab[1] ** 2
    t = 0.0 if den == 0 else max(0.0, min(1.0, (ap[0] * ab[0] + ap[1] * ab[1]) / den))
    return math.hypot(ap[0] - ab[0] * t, ap[1] - ab[1] * t)


def _dist_to_polyline(p, pts):
    return min(_seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def _to_local(x, z, pos, rot_deg):
    dx, dz = x - pos[0], z - pos[1]
    r = math.radians(rot_deg)
    return dx * math.cos(r) - dz * math.sin(r), dx * math.sin(r) + dz * math.cos(r)


def _smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _rect_outside(lx, lz, rect):
    dx = max(rect[0] - lx, 0.0, lx - rect[2])
    dz = max(rect[1] - lz, 0.0, lz - rect[3])
    return math.hypot(dx, dz)


class Ground:
    def __init__(self, lay: dict):
        g = lay["ground"]
        self.cell = g["cell"]
        self.nx = int(round(g["size"][0] / self.cell))
        self.nz = int(round(g["size"][1] / self.cell))
        self.ix0 = int(round((g["center"][0] - g["size"][0] / 2) / self.cell))
        self.iz0 = int(round((g["center"][1] - g["size"][1] / 2) / self.cell))
        self.falloff = g["flatten_falloff"]
        margin = g["building_flat_margin"]
        self.paving = lay["paving"]["rects"]
        self.paving_noise = lay["paving"]["edge_noise"]
        self.paths = lay["paths"]["lines"]
        self.path_half = lay["paths"]["width"] * 0.5
        brook = lay["brook"]
        self.brook_x = brook["pos"][0]
        self.brook_half = brook["half_width"]
        self.zones = []
        self.trodden = []
        fps = lay["footprints"]
        for b in lay["buildings"]:
            r = fps[b["model"]]
            self.zones.append([b["pos"], b["rot_y"], (r[0] - margin, r[1] - margin, r[2] + margin, r[3] + margin), None])
            if "door" in b:
                self.trodden.append(b["door"])
        for e in lay["entities"]:
            if "pos" in e and e["type"] in ("ShopCounter", "VillageBoard", "RegionPortal"):
                self.trodden.append(e["pos"])
        for wp in ("v_well", "v_wash", "v_remise", "v_hagedorn_gate", "v_dorn_door", "v_anvil"):
            self.trodden.append(lay["waypoints"][wp])
        for zone in self.zones:
            zone[3] = self.raw_height(*zone[0])

    def paving_mask(self, x, z):
        best = 0.0
        n = noise.noise(Vector((x * 0.9, z * 0.9, 4.5))) * self.paving_noise
        for r in self.paving:
            inside = min(x - r[0], r[2] - x, z - r[1], r[3] - z) + n
            best = max(best, max(0.0, min(1.0, inside / 0.45 + 0.5)))
        return best

    def path_mask(self, x, z):
        best = 0.0
        edge = self.path_half + noise.noise(Vector((x * 1.3, z * 1.3, 0.5))) * 0.35
        for line in self.paths:
            d = _dist_to_polyline((x, z), line)
            best = max(best, max(0.0, min(1.0, (edge - d) / 0.35 + 0.5)))
        return best

    def brook_dist(self, x):
        return abs(x - self.brook_x)

    def raw_height(self, x, z):
        h = noise.noise(Vector((x * 0.25, z * 0.25, 21.0))) * NOISE_LOW + noise.noise(Vector((x, z, 23.0))) * NOISE_HIGH
        pm = self.paving_mask(x, z)
        h = h * (1.0 - PAVING_SMOOTH * pm)
        h -= self.path_mask(x, z) * PATH_DEPTH * (1.0 - pm)
        return h

    def height(self, x, z):
        h = self.raw_height(x, z)
        # the brook bed: flat at 0 under the water mesh, soft banks
        bd = self.brook_dist(x)
        if bd < self.brook_half + 1.2:
            w = 1.0 - _smoothstep((bd - self.brook_half) / 1.2)
            h = h * (1.0 - w)
        best_w, best_h = 0.0, h
        for pos, rot, rect, h0 in self.zones:
            lx, lz = _to_local(x, z, pos, rot)
            out = _rect_outside(lx, lz, rect)
            if out >= self.falloff:
                continue
            w = 1.0 - _smoothstep(out / self.falloff)
            if w > best_w:
                best_w, best_h = w, h0
        return h + (best_h - h) * best_w

    def colour(self, x, z):
        n1 = noise.noise(Vector((x * 0.35, z * 0.35, 7.0)))
        n2 = noise.noise(Vector((x * 1.7, z * 1.7, 9.0)))
        c = L.mix(GRASS_A, GRASS_B, 0.5 + 0.5 * n1)
        c = L.mix(c, GRASS_DRY, max(0.0, n2) * 0.35)
        wear = 0.0
        for sx, sz in self.trodden:
            wear = max(wear, (1.0 - math.hypot(x - sx, z - sz) / 2.2) * 0.85)
        c = L.mix(c, DIRT, max(0.0, min(1.0, wear * 1.4 + n2 * 0.3)) * 0.6)
        pm = self.path_mask(x, z)
        c = L.mix(c, L.mix(DIRT, DIRT_DARK, 0.5 + 0.5 * n2), pm)
        # damp earth along the brook
        bd = self.brook_dist(x)
        if bd < self.brook_half + 1.6:
            c = L.mix(c, DAMP, (1.0 - _smoothstep((bd - self.brook_half + 0.4) / 2.0)) * 0.55)
        vm = self.paving_mask(x, z)
        if vm > 0.0:
            # painted cobbles: a soft cell pattern from two noise octaves, darker joints, worn centre
            cx = noise.noise(Vector((x * 2.6, z * 2.6, 13.0)))
            cz = noise.noise(Vector((x * 2.6 + 7.1, z * 2.6, 17.0)))
            stone = L.mix(COBBLE, COBBLE_DARK, 0.5 + 0.5 * cx)
            joint = max(0.0, 1.0 - abs(cx - cz) * 5.0) * 0.45
            stone = L.mix(stone, COBBLE_JOINT, joint)
            stone = L.mix(stone, DIRT, max(0.0, n1) * 0.25)
            c = L.mix(c, stone, vm * 0.92)
        f = 1.0 + n2 * 0.06
        return [L._to_lin(min(1.0, ch * f)) for ch in c]


def build():
    L.reset(31)
    lay = load_layout()
    gr = Ground(lay)
    cell, nx, nz = gr.cell, gr.nx, gr.nz
    verts, cols = [], []
    for j in range(nz + 1):
        z = (gr.iz0 + j) * cell
        for i in range(nx + 1):
            x = (gr.ix0 + i) * cell
            verts.append((x, -z, gr.height(x, z)))
            cols.append(gr.colour(x, z))
    w = nx + 1
    faces = []
    for j in range(nz):
        for i in range(nx):
            a = j * w + i
            faces.append((a, a + w, a + w + 1, a + 1))
    me = bpy.data.meshes.new(NAME)
    me.from_pydata(verts, [], faces)
    me.update()
    if me.polygons[0].normal.z < 0.0:
        me.flip_normals()
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    me.color_attributes.active_color = attr
    for li, loop in enumerate(me.loops):
        attr.data[li].color = (*cols[loop.vertex_index], 1.0)
    obj = bpy.data.objects.new(NAME, me)
    bpy.context.collection.objects.link(obj)
    L.set_mat(obj, L.MAT_GROUND)
    L.smooth(obj, 80)
    L.export(obj, NAME, "environment")


if __name__ == "__main__":
    build()
