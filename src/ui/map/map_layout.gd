class_name MapLayout
extends RefCounted
## The static part of the map of one region, read from its layout file (MapConfig.layouts) – so the
## map follows every layout change. All positions are region-local Vector2(x, z) in metres (x = east,
## z = south, north up). Built once per region and cached (MapLayout.of).
## Graveyard: sections, fence, path / coach road, hut, building sites, graves (plots + old graves),
## trees, quarry edges, gates, the milestone. Village: paving (Anger), lanes, the brook, every building
## (footprints of their models), the landmark props, the house doors with their opening windows.

const GRAVEYARD := &"graveyard"
const VILLAGE := &"village"

var region_id: StringName
## Region origin in the world (layout "origin"; the graveyard has none = 0).
var origin: Vector3 = Vector3.ZERO
var view: Rect2
## The walkable area (layout walkable_bounds; empty without).
var bounds: Rect2 = Rect2()
## [{id, rect: Rect2}] – graveyard sections.
var sections: Array[Dictionary] = []
## Fence lines (each a PackedVector2Array of two points).
var fences: Array[PackedVector2Array] = []
## [{points: PackedVector2Array, width: float, kind: &"road" | &"path" | &"lane" | &"paving"}]
var ways: Array[Dictionary] = []
## Paved plazas: [{center: Vector2, radius: float}] and rects.
var plazas: Array[Dictionary] = []
var plaza_rects: Array[Rect2] = []
## [{points: PackedVector2Array, half_width: float}]
var waters: Array[Dictionary] = []
## [{id, label, poly: PackedVector2Array, center: Vector2, glyph: StringName, site: bool, door: Vector2}]
var buildings: Array[Dictionary] = []
## [{id, pos: Vector2, section: StringName, old: bool}]
var graves: Array[Dictionary] = []
## [{pos: Vector2, size: float, kind: &"tree" | &"birch" | &"bush" | &"elder" | &"linden"}]
var trees: Array[Dictionary] = []
## Rock edges: [{pos, rot}]
var cliffs: Array[Dictionary] = []
## [{id, label, pos: Vector2, glyph: StringName}] – gates, milestone, well, board …
var landmarks: Array[Dictionary] = []
## [{key, text, pos: Vector2, angle: float}] – area names (Kutschweg, Wald, Werkhof, Anger, Hollerbach).
var area_labels: Array[Dictionary] = []
## Every id that has a place on the map (buildings, landmarks, sections, waypoints) → its position.
var places: Dictionary[String, Vector2] = {}
## Room id → world origin of that interior (to map a person inside it to its building).
var interiors: Dictionary[StringName, Vector3] = {}
## Building id → open windows of its house door ([from, to, …] minutes; village HouseDoors).
var door_windows: Dictionary[String, PackedInt32Array] = {}

static var _cache: Dictionary[StringName, MapLayout] = {}


## The cached layout of `region` (null when the config has no layout for it).
static func of(region: StringName, cfg: MapConfig) -> MapLayout:
	if _cache.has(region):
		return _cache[region]
	var path: String = cfg.layouts.get(region, "")
	if path == "":
		return null
	var data := read_json(path)
	if data.is_empty():
		return null
	var layout := MapLayout.new()
	layout.build(region, data, cfg)
	_cache[region] = layout
	return layout


static func clear_cache() -> void:
	_cache.clear()


## The layout file as a Dictionary ({} when missing / broken).
static func read_json(path: String) -> Dictionary:
	var text := ""
	if ResourceLoader.exists(path):
		var res := load(path) as JSON
		if res != null and res.data is Dictionary:
			return res.data as Dictionary
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed as Dictionary if parsed is Dictionary else {}


func build(region: StringName, d: Dictionary, cfg: MapConfig) -> void:
	region_id = region
	view = cfg.views.get(region, Rect2(-30.0, -30.0, 60.0, 60.0))
	var o: Variant = d.get("origin")
	if o is Array and (o as Array).size() >= 3:
		origin = Vector3(float(o[0]), float(o[1]), float(o[2]))
	var wb: Dictionary = d.get("walkable_bounds", {})
	if wb.has("min") and wb.has("max"):
		bounds = Rect2(v2(wb.min), v2(wb.max) - v2(wb.min))
	if region == VILLAGE:
		_build_village(d, cfg)
	else:
		_build_graveyard(d, cfg)
	var wp: Variant = d.get("waypoints", {})
	if wp is Dictionary:
		for id: Variant in wp:
			if not str(id).begins_with("_") and not places.has(str(id)):
				places[str(id)] = v2(wp[id])


## Region-local map position of a world position; `room` (an interior id) puts it on its building.
func local_of(world: Vector3, cfg: MapConfig) -> Vector2:
	for room: StringName in interiors:
		var io: Vector3 = interiors[room]
		if absf(world.x - io.x) < cfg.room_radius and absf(world.z - io.z) < cfg.room_radius:
			var place: String = cfg.room_places.get(room, "")
			if places.has(place):
				return places[place]
	return Vector2(world.x - origin.x, world.z - origin.z)


## True when `world` lies in one of this region's interiors.
func in_room(world: Vector3, cfg: MapConfig) -> bool:
	for room: StringName in interiors:
		var io: Vector3 = interiors[room]
		if absf(world.x - io.x) < cfg.room_radius and absf(world.z - io.z) < cfg.room_radius:
			return true
	return false


func building(id: String) -> Dictionary:
	for b: Dictionary in buildings:
		if b.id == id:
			return b
	return {}


# --- graveyard ------------------------------------------------------------------------------

func _build_graveyard(d: Dictionary, cfg: MapConfig) -> void:
	for s: Variant in d.get("sections", []):
		var r: Array = (s as Dictionary).get("rect", [])
		if r.size() >= 4:
			var rect := Rect2(Vector2(r[0], r[1]), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1])))
			sections.append({"id": StringName(str(s.id)), "rect": rect})
			places[str(s.id)] = rect.get_center()
	var fence: Dictionary = d.get("fence", {})
	for seg: Variant in fence.get("segments", []):
		fences.append(PackedVector2Array([v2(seg[0]), v2(seg[1])]))
	_way(d.get("road", {}), &"road")
	_way(d.get("path", {}), &"path")
	var hut: Dictionary = d.get("hut", {})
	if not hut.is_empty():
		var size := _collider_size(d, "ph_bld_gravekeeper_hut", Vector2(5.0, 4.0))
		_add_building("hut", v2(hut.pos), float(hut.get("rot_y", 0.0)), Rect2(-size * 0.5, size), cfg, false)
	for site: Variant in (d.get("buildings", {}) as Dictionary).get("sites", []):
		var f: Array = site.get("footprint", [-1.0, -1.0, 2.0, 2.0])
		_add_building(str(site.id), v2(site.pos), float(site.get("rot_y", 0.0)),
				Rect2(float(f[0]), float(f[1]), float(f[2]), float(f[3])), cfg, true)
		if site.has("access"):
			buildings.back()["door"] = v2(site.access)
	var yard_tree: Dictionary = d.get("tree", {})
	if not yard_tree.is_empty():
		trees.append({"pos": v2(yard_tree.pos), "size": 2.4, "kind": &"tree"})
	for list_key: String in ["background_trees", "birches", "elder_bushes"]:
		var kind := &"birch" if list_key == "birches" else (&"elder" if list_key == "elder_bushes" else &"tree")
		for t: Variant in d.get(list_key, []):
			trees.append({"pos": v2(t.pos), "size": float(t.get("scale", 1.0)) * (1.3 if kind == &"elder" else 2.2), "kind": kind})
	var forest: Dictionary = d.get("forest", {})
	var forest_sum := Vector2.ZERO
	var forest_n := 0
	for t: Variant in forest.get("trees", []):
		trees.append({"pos": v2(t.pos), "size": float(t.get("scale", 1.0)) * 2.3, "kind": &"tree"})
		# The name sits in the larger, western stand (west of the coach road).
		if v2(t.pos).x < 0.0:
			forest_sum += v2(t.pos)
			forest_n += 1
	for t: Variant in forest.get("bushes", []):
		trees.append({"pos": v2(t.pos), "size": float(t.get("scale", 1.0)) * 1.1, "kind": &"bush"})
	for e: Variant in d.get("quarry_edges", []):
		cliffs.append({"pos": v2(e.pos), "rot": deg_to_rad(float(e.get("rot_y", 0.0))),
				"len": 9.0 if str(e.get("asset", "")).ends_with("face") else 3.0})
	for g: Variant in d.get("plots", []):
		graves.append({"id": str(g.id), "pos": v2(g.pos), "section": StringName(str(g.get("section", "yard"))), "old": false})
	for g: Variant in d.get("old_graves", []):
		graves.append({"id": str(g.id), "pos": v2(g.pos), "section": &"yard", "old": true})
	for g: Dictionary in graves:
		places[g.id] = g.pos
	for c: Variant in d.get("clearables", []):
		if str(c.get("kind", "")) == "gate_church":
			_landmark(str(c.id), v2(c.pos), &"gate", cfg)
	for p: Variant in d.get("region_portals", []):
		_landmark(str(p.id), v2(p.pos), &"milestone", cfg)
	var board: Dictionary = d.get("notice_board", {})
	if not board.is_empty():
		_landmark("notice_board", v2(board.pos), &"board", cfg)
	# Area names.
	var road: Array = (d.get("road", {}) as Dictionary).get("points", [])
	if road.size() >= 4:
		var a := v2(road[road.size() / 2])
		var b := v2(road[road.size() / 2 + 1])
		_area("road", (a + b) * 0.5 + Vector2(2.2, -1.2), (b - a).angle(), cfg)
	if forest_n > 0:
		_area("forest", forest_sum / float(forest_n), 0.0, cfg)
	var work: Array = (d.get("workyard", {}) as Dictionary).get("build_sites", [])
	if not work.is_empty():
		var sum := Vector2.ZERO
		for s: Variant in work:
			sum += v2(s.pos)
		_area("workyard", sum / float(work.size()) + Vector2(0.0, 1.6), 0.0, cfg)
		places["workyard"] = sum / float(work.size())
	var io: Dictionary = d.get("interiors", {})
	for room: Variant in io:
		var o: Variant = (io[room] as Dictionary).get("origin") if io[room] is Dictionary else null
		if o is Array:
			interiors[StringName(str(room))] = Vector3(o[0], o[1], o[2])
	var hi: Dictionary = d.get("hut_interior", {})
	if hi.get("origin") is Array:
		interiors[&"hut"] = Vector3(hi.origin[0], hi.origin[1], hi.origin[2])


# --- village --------------------------------------------------------------------------------

func _build_village(d: Dictionary, cfg: MapConfig) -> void:
	var paving: Dictionary = d.get("paving", {})
	for c: Variant in paving.get("circles", []):
		plazas.append({"center": Vector2(c[0], c[1]), "radius": float(c[2])})
	for r: Variant in paving.get("rects", []):
		plaza_rects.append(Rect2(Vector2(r[0], r[1]), Vector2(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))))
	for l: Variant in paving.get("lines", []):
		ways.append({"points": _points(l.pts), "width": float(l.get("width", 2.0)), "kind": &"lane"})
	var paths: Dictionary = d.get("paths", {})
	for l: Variant in paths.get("lines", []):
		ways.append({"points": _points(l), "width": float(paths.get("width", 1.6)), "kind": &"path"})
	var brook: Dictionary = d.get("brook", {})
	if not brook.is_empty():
		var x := float(brook.pos[0])
		var z_min := view.position.y - 2.0
		var z_max := view.end.y + 2.0
		var pts := PackedVector2Array()
		var n := 24
		for i: int in n + 1:
			var z := lerpf(z_min, z_max, float(i) / n)
			pts.append(Vector2(x + sin(z * 0.23) * 0.7 + sin(z * 0.61) * 0.3, z))
		waters.append({"points": pts, "half_width": float(brook.get("half_width", 1.8))})
		_area("brook", Vector2(x - 1.0, 13.5), PI * 0.5, cfg)
	var footprints: Dictionary = d.get("footprints", {})
	for b: Variant in d.get("buildings", []):
		var f: Array = footprints.get(str(b.get("model", "")), [-3.0, -3.0, 3.0, 3.0])
		_add_building(str(b.id), v2(b.pos), float(b.get("rot_y", 0.0)),
				Rect2(float(f[0]), float(f[1]), float(f[2]) - float(f[0]), float(f[3]) - float(f[1])), cfg, false)
		if b.has("door"):
			buildings.back()["door"] = v2(b.door)
	for p: Variant in d.get("props", []):
		var pid := str(p.id)
		if cfg.village_landmarks.has(pid):
			_landmark(pid, v2(p.pos), cfg.village_landmarks[pid], cfg)
			if pid == "linden":
				trees.append({"pos": v2(p.pos), "size": 3.4, "kind": &"linden"})
	var decor: Dictionary = d.get("decor", {})
	for t: Variant in decor.get("trees", []):
		var kind := &"birch" if str(t.get("asset", "")).contains("birch") else &"tree"
		trees.append({"pos": v2(t.pos), "size": float(t.get("scale", 1.0)) * (2.0 if kind == &"birch" else 2.8), "kind": kind})
	for t: Variant in decor.get("bushes", []):
		trees.append({"pos": v2(t.pos), "size": float(t.get("scale", 1.0)) * 1.1, "kind": &"bush"})
	for seg: Variant in decor.get("garden_fences", []):
		fences.append(PackedVector2Array([v2(seg[0]), v2(seg[1])]))
	for e: Variant in d.get("entities", []):
		if str(e.get("type", "")) == "HouseDoor" and e.has("house"):
			door_windows[str(e.house)] = PackedInt32Array(e.get("open_windows", []))
		elif str(e.get("type", "")) == "RegionPortal":
			places[str(e.id)] = v2(e.pos)
	if not plazas.is_empty():
		_area("anger", plazas[0].center + Vector2(0.0, 6.0), 0.0, cfg)
		places["anger"] = plazas[0].center
	for e: Variant in d.get("entities", []):
		if str(e.get("type", "")) == "RegionPortal":
			_area("road_village", v2(e.pos) + Vector2(-0.5, -2.2), 0.0, cfg)
	var io: Dictionary = d.get("interiors", {})
	for room: Variant in io:
		var o: Variant = (io[room] as Dictionary).get("origin") if io[room] is Dictionary else null
		if o is Array:
			interiors[StringName(str(room))] = Vector3(o[0], o[1], o[2])


# --- helpers --------------------------------------------------------------------------------

func _add_building(id: String, pos: Vector2, rot_deg: float, local: Rect2, cfg: MapConfig, site: bool) -> void:
	var poly := PackedVector2Array()
	var rot := deg_to_rad(rot_deg)
	for c: Vector2 in [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		var w := Vector3(c.x, 0.0, c.y).rotated(Vector3.UP, rot)
		poly.append(pos + Vector2(w.x, w.z))
	var label: String = cfg.labels.get(id, cfg.fallback_building_label)
	buildings.append({"id": id, "label": label, "poly": poly, "center": pos, "rot": rot, "site": site,
			"glyph": cfg.building_glyphs.get(id, &""), "size": local.size})
	places[id] = pos


func _landmark(id: String, pos: Vector2, glyph: StringName, cfg: MapConfig) -> void:
	landmarks.append({"id": id, "label": cfg.labels.get(id, ""), "pos": pos, "glyph": glyph})
	places[id] = pos


func _area(key: String, pos: Vector2, angle: float, cfg: MapConfig) -> void:
	var text: String = cfg.feature_labels.get(key, "")
	if text != "":
		area_labels.append({"key": key, "text": text, "pos": cfg.label_at.get(key, pos), "angle": angle})


func _way(w: Dictionary, kind: StringName) -> void:
	if w.has("points"):
		ways.append({"points": _points(w.points), "width": float(w.get("width", 1.6)), "kind": kind})


func _collider_size(d: Dictionary, asset: String, fallback: Vector2) -> Vector2:
	var list: Variant = (d.get("colliders", {}) as Dictionary).get(asset)
	if list is Array and not (list as Array).is_empty():
		var s: Variant = (list[0] as Dictionary).get("size")
		if s is Array and (s as Array).size() >= 3:
			return Vector2(s[0], s[2])
	return fallback


static func _points(raw: Variant) -> PackedVector2Array:
	var out := PackedVector2Array()
	if raw is Array:
		for p: Variant in raw:
			out.append(v2(p))
	return out


static func v2(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO
