"""Ground of the vertical-slice world (graveyard + "Kutschweg"), 'Gemaltes Diorama' style.

Same painting as the approved prototype ground (asset_environment.ground(): moss-green noise,
dry patches, worn earth at graves / tree / hut door, earth path) on a non-square grid that
covers data/world/graveyard_layout.json, plus the road to Hollerbrück with wheel ruts and
trodden earth at the stations. Under grave plots and stations the ground is flat (the pit
floor sits only 3-4 cm and the plot patch 0.4-1.8 cm above it): a flat core rect per zone,
then a smooth falloff back to the noise.

Phase 5 (docs/PHASE5_DESIGN.md §4.5): 64 × 64 m (x −24…40, Am Bruch in the east); flat under
the workyard build sites (footprint + station_flat_margin) and the flax beds / clay pit
(ground.gather_flat_kinds). A new zone that touches an existing one takes over that zone's
height, so the approved stations (workbench, table) keep their ground bit for bit. The quarry
floor gets a stone tint (vertex colour only, ground.quarry_tint) and the beds / pit trodden earth.

Phase 6 (docs/PHASE6_DESIGN.md §4.2 K6): 64 × 80 m (z −45,5…34,5, the churchyard on the ridge – no
ground edge behind the chapel); flat under the building footprints of layout.buildings.sites
(+ station_flat_margin), trodden earth at their doors. The noise is a function of (x, z) only, so
every approved vertex keeps its height outside the new zones.

Grid vertices lie exactly on multiples of ground.cell (Godot coords), so the world builder can
look heights up by grid index.  Layout coords are Godot (x, z); Blender y = -z.

Run:  python tools/blender/asset_ground_graveyard.py
      (or: python tools/blender/build_all.py asset_ground_graveyard)
Out:  assets/models/environment/ph_env_ground_graveyard.glb
      art_source/blender/environment/ph_env_ground_graveyard.blend
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402  (must be imported before bmesh / mathutils users)
from mathutils import Vector, noise  # noqa: E402

import lib_painted as L  # noqa: E402

LAYOUT = os.path.join(L.ROOT, "data", "world", "graveyard_layout.json")
NAME = "ph_env_ground_graveyard"

# Palette of the approved prototype ground (asset_environment.py).
GRASS_A = L.hexc("#55683F")
GRASS_B = L.hexc("#667A48")
GRASS_DRY = L.hexc("#7D7D4E")
DIRT = L.hexc("#6B5A48")
DIRT_DARK = L.hexc("#54463A")
# Phase 5: quarry floor (stone family #8A8F94, muted towards the painted ground).
STONE_FLOOR = L.hexc("#7A7C74")
STONE_FLOOR_DARK = L.hexc("#646660")

# Prototype height noise and path depression (m).
NOISE_LOW, NOISE_HIGH, PATH_DEPTH = 0.06, 0.015, 0.035
# Entity types whose collider footprint is flattened (and trodden) -> asset of that type.
STATION_ASSETS = {"morgue_table": "ph_prop_morgue_table", "dropoff": "ph_prop_dropoff_bier",
                  "workbench": "ph_prop_workbench"}
TRODDEN_TYPES = ("morgue_table", "dropoff", "workbench", "resource_node", "hut_door")


def load_layout() -> dict:
    with open(LAYOUT, encoding="utf-8") as f:
        return json.load(f)


def _seg_dist(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1])
    ap = (p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, (ap[0] * ab[0] + ap[1] * ab[1]) / (ab[0] ** 2 + ab[1] ** 2)))
    return math.hypot(ap[0] - ab[0] * t, ap[1] - ab[1] * t)


def _dist_to_polyline(p, pts):
    return min(_seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def _to_local(x, z, pos, rot_deg):
    """World (x, z) -> local coords of an object at pos rotated by rot_deg about +Y (Godot)."""
    dx, dz = x - pos[0], z - pos[1]
    r = math.radians(rot_deg)
    # inverse of R_y(r): local = R_y(-r) * d
    return dx * math.cos(r) - dz * math.sin(r), dx * math.sin(r) + dz * math.cos(r)


def _smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def _rect_outside(lx, lz, rect):
    """Distance of a local point outside rect (x0, z0, x1, z1); 0 inside."""
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
        self.path = lay["path"]["points"]
        self.path_half = lay["path"]["width"] * 0.5
        self.road = lay["road"]["points"]
        self.road_half = lay["road"]["width"] * 0.5
        self.rut = lay["road"]["rut_offset"]
        self.graves = [(gr["pos"], gr["rot_y"]) for gr in lay["old_graves"]] + \
                      [(pl["pos"], pl["rot_y"]) for pl in lay["plots"]]
        self.tree = lay["tree"]["pos"]
        self.hut = lay["hut"]["pos"]
        self.zones = []  # (pos, rot, rect, h0)
        plot_rect = g["plot_flat_rect"]
        margin = g["station_flat_margin"]
        for pl in lay["plots"]:
            self.zones.append([pl["pos"], pl["rot_y"], plot_rect, None])
        self.trodden = []
        for ent in lay["entities"]:
            if ent["type"] in STATION_ASSETS:
                box = lay["colliders"][STATION_ASSETS[ent["type"]]][0]["size"]
                hx, hz = box[0] / 2 + margin, box[2] / 2 + margin
                self.zones.append([ent["pos"], ent["rot_y"], (-hx, -hz, hx, hz), None])
            if ent["type"] in TRODDEN_TYPES:
                self.trodden.append(ent["pos"])
        for zone in self.zones:  # the flat height = the unflattened ground at the zone centre
            zone[3] = self.raw_height(*zone[0])
        self._merge_touching_zones()
        self._add_phase5_zones(lay, margin)
        tint = g.get("quarry_tint")
        self.quarry = tuple(tint) if tint else None

    def _merge_touching_zones(self):
        """Neighbouring plots (2.4 m apart) have overlapping cores: one common height per group
        of touching zones, so no step runs between two graves of a row."""
        n = len(self.zones)
        group = list(range(n))

        def find(i):
            while group[i] != i:
                i = group[i]
            return i

        def reach(zone):
            rect = zone[2]
            return math.hypot(max(abs(rect[0]), abs(rect[2])), max(abs(rect[1]), abs(rect[3])))

        for i in range(n):
            for j in range(i + 1, n):
                a, b = self.zones[i], self.zones[j]
                if math.hypot(a[0][0] - b[0][0], a[0][1] - b[0][1]) < reach(a) + reach(b) - self.falloff:
                    group[find(j)] = find(i)
        heights = {}
        for i in range(n):
            heights.setdefault(find(i), []).append(self.zones[i][3])
        for i in range(n):
            members = heights[find(i)]
            self.zones[i][3] = sum(members) / len(members)

    def _add_phase5_zones(self, lay, margin):
        """Workyard build sites and the flax beds / clay pit (Phase 5). A zone touching an older
        zone adopts its height (the approved ground stays unchanged); the others get their own."""
        new = []
        for site in lay.get("workyard", {}).get("build_sites", []):
            fx, fz, fw, fd = site["footprint"]
            new.append([site["pos"], site["rot_y"], (fx - margin, fz - margin, fx + fw + margin, fz + fd + margin), None])
            self.trodden.append(site["pos"])
        kinds = lay["ground"].get("gather_flat_kinds", {})
        for node in lay.get("gather_nodes", []):
            if node["kind"] in kinds:
                w, d = kinds[node["kind"]]
                new.append([node["pos"], node["rot_y"], (-w / 2, -d / 2, w / 2, d / 2), None])
                self.trodden.append(node["pos"])
        old = list(self.zones)

        def reach(zone):
            rect = zone[2]
            return math.hypot(max(abs(rect[0]), abs(rect[2])), max(abs(rect[1]), abs(rect[3])))

        done = []
        for zone in new:
            zone[3] = self.raw_height(*zone[0])
            for o in old + done:  # an approved zone first, then an earlier new one
                if math.hypot(zone[0][0] - o[0][0], zone[0][1] - o[0][1]) < reach(zone) + reach(o) - self.falloff:
                    zone[3] = o[3]
                    break
            done.append(zone)
        self.zones.extend(new)
        self._add_phase6_zones(lay, margin, reach)

    def _add_phase6_zones(self, lay, margin, reach):
        """Phase 6 (docs/PHASE6_DESIGN.md §4.2 K6): flat under the three building footprints
        (+ station_flat_margin), trodden earth in front of each door. Same rule as Phase 5: a zone
        touching an older one adopts its height."""
        old = list(self.zones)
        for site in lay.get("buildings", {}).get("sites", []):
            fx, fz, fw, fd = site["footprint"]
            zone = [site["pos"], site["rot_y"], (fx - margin, fz - margin, fx + fw + margin, fz + fd + margin), None]
            zone[3] = self.raw_height(*zone[0])
            for o in old:
                if math.hypot(zone[0][0] - o[0][0], zone[0][1] - o[0][1]) < reach(zone) + reach(o) - self.falloff:
                    zone[3] = o[3]
                    break
            self.zones.append(zone)
            old.append(zone)
            self.trodden.append(site["access"])

    # --- masks (same edge noise as the prototype path) ---
    def path_mask(self, x, z):
        d = _dist_to_polyline((x, z), self.path)
        edge = self.path_half + noise.noise(Vector((x * 1.3, z * 1.3, 0.5))) * 0.35
        return max(0.0, min(1.0, (edge - d) / 0.35 + 0.5))

    def road_mask(self, x, z):
        d = _dist_to_polyline((x, z), self.road)
        edge = self.road_half + noise.noise(Vector((x * 1.1, z * 1.1, 2.5))) * 0.4
        return max(0.0, min(1.0, (edge - d) / 0.4 + 0.5)), d

    def raw_height(self, x, z):
        h = noise.noise(Vector((x * 0.25, z * 0.25, 1.0))) * NOISE_LOW + noise.noise(Vector((x, z, 3.0))) * NOISE_HIGH
        h -= max(self.path_mask(x, z), self.road_mask(x, z)[0]) * PATH_DEPTH
        return h

    def height(self, x, z):
        h = self.raw_height(x, z)
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
        # worn earth around graves, trunk, hut door (prototype) and the stations
        wear = 0.0
        for (gx, gz), rot in self.graves:
            lx, lz = _to_local(x, z, (gx, gz), rot)
            wear = max(wear, 1.0 - math.sqrt((lx / 0.9) ** 2 + (lz / 1.5) ** 2))
        wear = max(wear, 1.0 - math.hypot(x - self.tree[0], z - self.tree[1]) / 2.0)
        wear = max(wear, 1.0 - math.hypot(x - self.hut[0], z - (self.hut[1] + 2.4)) / 2.2)
        for sx, sz in self.trodden:
            wear = max(wear, (1.0 - math.hypot(x - sx, z - sz) / 1.9) * 0.8)
        c = L.mix(c, DIRT, max(0.0, min(1.0, wear * 1.4 + n2 * 0.3)) * 0.6)
        pm = self.path_mask(x, z)
        c = L.mix(c, L.mix(DIRT, DIRT_DARK, 0.5 + 0.5 * n2), pm)
        rm, d = self.road_mask(x, z)
        if rm > 0.0:
            c = L.mix(c, L.mix(DIRT, DIRT_DARK, 0.45 + 0.4 * n2), rm)
            rut = max(0.0, 1.0 - abs(d - self.rut) / 0.16) * rm
            c = L.mix(c, L.scale_c(DIRT_DARK, 0.82), rut * (0.55 + 0.2 * n1))
        if self.quarry and self.quarry[0] - 1.0 < x < self.quarry[2] + 1.0 and self.quarry[1] - 1.0 < z < self.quarry[3] + 1.0:
            # stone floor of the quarry, softly blended at its edge (1 m)
            inside = min(x - self.quarry[0], self.quarry[2] - x, z - self.quarry[1], self.quarry[3] - z)
            q = _smoothstep((inside + 1.0) / 2.0)
            n3 = noise.noise(Vector((x * 0.9, z * 0.9, 11.0)))
            c = L.mix(c, L.mix(STONE_FLOOR, STONE_FLOOR_DARK, 0.5 + 0.5 * n3), q * 0.85)
        f = 1.0 + n2 * 0.06
        return [L._to_lin(min(1.0, ch * f)) for ch in c]


def build():
    L.reset(30)
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
    # no pivot shift for the ground: z = 0 stays the reference plane
    L.smooth(obj, 80)
    L.export(obj, NAME, "environment")


if __name__ == "__main__":
    build()
