extends TestCase
## Change round 2 (docs/VERTICAL_SLICE_DESIGN.md §11): the bigger hut exterior, the interior models
## and the suggested furnishing data/world/hut_interior_layout.json.
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front).

const HUT := "res://assets/models/buildings/ph_bld_gravekeeper_hut.glb"
const INTERIOR_DIR := "res://assets/models/interior/"
const BLEND_DIR := "res://art_source/blender/interior/"
const LAYOUT := "res://data/world/hut_interior_layout.json"
const PAINTED := "res://assets/materials/mat_painted.tres"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const BUDGET_HUT := 10000
const BUDGET_ROOM := 8000
const BUDGET_BIG := 2000     # stove, bed, desk
const BUDGET_PIECE := 1500
const MIN_TRIS := 100
const GROUND_EPS := 0.01
const CENTRE_EPS := 0.06
## Inner floor of the room (half extents) and the wall height.
const ROOM_HALF := Vector2(2.3, 1.8)
const WALL_H := 2.5
const DOOR_X := -0.9
const DOOR_MIN_W := 0.9
const DOOR_MIN_H := 1.95
const GRID := 0.05

## name -> [min size, max size, triangle budget, footprint centred on the pivot]
const MODELS := {
	"ph_int_room": [Vector3(4.7, 2.5, 3.7), Vector3(5.05, 3.6, 4.05), BUDGET_ROOM, false],
	"ph_int_bed": [Vector3(1.9, 0.9, 0.95), Vector3(2.2, 1.2, 1.2), BUDGET_BIG, true],
	"ph_int_stove": [Vector3(0.8, 2.0, 0.75), Vector3(1.15, 2.5, 1.1), BUDGET_BIG, false],
	"ph_int_table": [Vector3(0.9, 0.74, 0.6), Vector3(1.15, 1.0, 0.85), BUDGET_PIECE, true],
	"ph_int_chair": [Vector3(0.38, 0.85, 0.4), Vector3(0.55, 1.0, 0.6), BUDGET_PIECE, true],
	"ph_int_desk": [Vector3(1.0, 1.0, 0.5), Vector3(1.25, 1.35, 0.75), BUDGET_BIG, true],
	"ph_int_chest": [Vector3(0.8, 0.5, 0.45), Vector3(1.05, 0.7, 0.7), BUDGET_PIECE, true],
	"ph_int_shelf": [Vector3(0.8, 0.6, 0.2), Vector3(1.2, 1.0, 0.35), BUDGET_PIECE, true],
	"ph_int_rug": [Vector3(1.5, 0.01, 0.9), Vector3(1.9, 0.05, 1.3), BUDGET_PIECE, true],
	"ph_int_herbs": [Vector3(0.8, 0.45, 0.1), Vector3(1.1, 0.75, 0.3), BUDGET_PIECE, true],
	"ph_int_coat_hook": [Vector3(0.6, 0.7, 0.15), Vector3(0.95, 1.1, 0.35), BUDGET_PIECE, true],
	"ph_int_candles": [Vector3(0.15, 0.15, 0.15), Vector3(0.3, 0.35, 0.3), BUDGET_PIECE, true],
	"ph_int_picture": [Vector3(0.35, 0.35, 0.02), Vector3(0.6, 0.6, 0.1), BUDGET_PIECE, true],
	"ph_int_broom": [Vector3(0.2, 1.2, 0.3), Vector3(0.4, 1.6, 0.6), BUDGET_PIECE, true],
	"ph_int_bucket": [Vector3(0.25, 0.35, 0.25), Vector3(0.45, 0.6, 0.45), BUDGET_PIECE, true],
	"ph_int_washbasin": [Vector3(0.5, 0.9, 0.35), Vector3(0.75, 1.2, 0.5), BUDGET_PIECE, true],
	"ph_int_cat": [Vector3(0.3, 0.12, 0.25), Vector3(0.55, 0.25, 0.45), BUDGET_PIECE, true],
}
## Markers each model must carry (glTF empties -> Node3D); every other model carries none.
const MARKERS := {
	"ph_int_room": ["door_inside", "spawn_inside", "light_window_1", "light_window_2", "light_ceiling"],
	"ph_int_stove": ["light_fire"],
	"ph_int_desk": ["book", "light_candle"],
	"ph_int_table": ["light_candle"],
	"ph_int_candles": ["light_candle"],
}
const HUT_MARKERS: Array[String] = ["door_outside", "light_lantern", "light_window_1", "light_window_2"]
## Models with a light source (panes, flames, fire); all others are plain painted.
const GLOWING: Array[String] = ["ph_int_room", "ph_int_stove", "ph_int_desk", "ph_int_table", "ph_int_candles"]
const INTERACTIVE: Array[String] = ["bed", "stove", "chest", "desk"]


# --- exterior -------------------------------------------------------------------------

func test_hut_loads_with_shared_materials_and_budget() -> void:
	var inst := _load_path(HUT)
	assert_not_null(inst, "hut loads")
	for path: String in _material_paths(inst):
		assert_true(path == PAINTED or path == EMISSIVE, "hut uses shared materials (got '%s')" % path)
	assert_has(_material_paths(inst), EMISSIVE, "warm windows and lantern glow")
	var tris := _triangles(inst)
	assert_true(tris <= BUDGET_HUT and tris >= 3000, "hut: %d triangles (budget %d)" % [tris, BUDGET_HUT])
	inst.free()


func test_hut_is_bigger_about_5_by_4() -> void:
	var inst := _load_path(HUT)
	var box := _aabb(inst)
	assert_true(box.position.y <= GROUND_EPS and box.position.y >= -0.1, "rests on the ground (%f)" % box.position.y)
	assert_true(box.size.x >= 5.0 and box.size.x <= 6.4, "width incl. roof overhang (%f)" % box.size.x)
	assert_true(box.size.z >= 4.0 and box.size.z <= 5.6, "depth incl. eaves, bench, barrel (%f)" % box.size.z)
	assert_true(box.size.y >= 4.5 and box.size.y <= 6.2, "height incl. chimney (%f)" % box.size.y)
	var walls := _wall_band(inst)
	assert_true(walls.size.x >= 4.8 and walls.size.x <= 5.3, "wall footprint x ~5 m (%f)" % walls.size.x)
	assert_true(walls.size.z >= 3.8 and walls.size.z <= 4.3, "wall footprint z ~4 m (%f)" % walls.size.z)
	assert_almost(walls.get_center().x, 0.0, 0.12, "walls centred on the pivot (x)")
	assert_almost(walls.get_center().z, 0.0, 0.12, "walls centred on the pivot (z)")
	inst.free()


func test_hut_markers_door_lantern_windows() -> void:
	var inst := _load_path(HUT)
	for m: String in HUT_MARKERS:
		assert_not_null(inst.find_child(m, true, false), "hut marker " + m)
	var walls := _wall_band(inst)
	var front := walls.end.z - 0.1  # outer face of the front wall (the band includes frames and shutters)
	var door := _marker(inst, "door_outside").origin
	assert_almost(door.y, 0.0, 0.02, "door_outside on the ground")
	assert_true(door.z > front + 0.35 and door.z < front + 0.95, "door_outside ~0.6 m in front of the door (%s)" % door)
	assert_almost(door.x, DOOR_X, 0.05, "door_outside in front of the door centre")
	var lantern := _marker(inst, "light_lantern").origin
	assert_true(lantern.z > front and lantern.y > 1.2 and lantern.y < 2.6, "lantern outside by the door (%s)" % lantern)
	for m: String in ["light_window_1", "light_window_2"]:
		var p := _marker(inst, m).origin
		assert_true(absf(p.x) < walls.end.x - 0.15 and absf(p.z) < walls.end.z - 0.15, m + " inside the hut")
		assert_true(p.y > 1.0 and p.y < 2.3, m + " at window height")
	inst.free()


func test_hut_door_is_tall_enough() -> void:
	# the closed door leaf (in front of the wall planks) spans the whole opening
	var inst := _load_path(HUT)
	var lo := 9.0
	var hi := -9.0
	for p: Vector3 in _vertices(inst):
		if absf(p.x - DOOR_X) < 0.35 and p.z > 1.955 and p.z < 2.06 and p.y < 2.4:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
	assert_true(hi - lo >= DOOR_MIN_H, "door leaf %f .. %f (>= %f m)" % [lo, hi, DOOR_MIN_H])
	inst.free()


func test_room_fits_the_exterior_footprint() -> void:
	var hut := _load_path(HUT)
	var walls := _wall_band(hut)
	hut.free()
	var room := _load_name("ph_int_room")
	var box := _aabb(room)
	assert_true(box.size.x <= walls.size.x + 0.05 and box.size.z <= walls.size.z + 0.05,
			"room %s fits inside the hut walls %s" % [box.size, walls.size])
	var floor_box := _floor_extent(room)
	assert_true(floor_box.size.x >= 2 * ROOM_HALF.x - 0.1 and floor_box.size.z >= 2 * ROOM_HALF.y - 0.1,
			"inner floor ~4.6 x 3.6 m (%s)" % floor_box.size)
	assert_true(floor_box.size.x < walls.size.x and floor_box.size.z < walls.size.z, "floor inside the walls")
	room.free()


# --- interior models -----------------------------------------------------------------

func test_every_interior_model_exists_and_loads() -> void:
	for name: String in MODELS:
		var path := _path(name)
		assert_true(ResourceLoader.exists(path), "missing " + path)
		var inst := _load_name(name)
		assert_not_null(inst, "loads " + name)
		if inst == null:
			continue
		assert_true(_meshes(inst).size() >= 1, name + " has a mesh")
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])
		inst.free()


func test_interior_uses_shared_materials_only() -> void:
	for name: String in MODELS:
		var inst := _load_name(name)
		var paths := _material_paths(inst)
		for path: String in paths:
			assert_true(path == PAINTED or path == EMISSIVE, "%s uses shared materials (got '%s')" % [name, path])
		assert_has(paths, PAINTED, name + " is vertex painted")
		if name in GLOWING:
			assert_has(paths, EMISSIVE, name + " glows (panes / fire / flame)")
		else:
			assert_false(EMISSIVE in paths, name + " has no emissive surface")
		inst.free()


func test_interior_triangle_budgets() -> void:
	for name: String in MODELS:
		var inst := _load_name(name)
		var tris := _triangles(inst)
		var budget: int = MODELS[name][2]
		assert_true(tris <= budget, "%s: %d triangles > budget %d" % [name, tris, budget])
		assert_true(tris >= MIN_TRIS, "%s: only %d triangles" % [name, tris])
		inst.free()


func test_interior_bounding_sizes_and_pivots() -> void:
	for name: String in MODELS:
		var inst := _load_name(name)
		var box := _aabb(inst)
		var lo: Vector3 = MODELS[name][0]
		var hi: Vector3 = MODELS[name][1]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis],
					"%s size %s outside %s..%s (axis %d)" % [name, box.size, lo, hi, axis])
		if name != "ph_int_room":
			assert_almost(box.position.y, 0.0, GROUND_EPS, name + " pivot at the bottom")
		if MODELS[name][3]:
			var c := box.get_center()
			assert_true(absf(c.x) <= CENTRE_EPS and absf(c.z) <= CENTRE_EPS, "%s footprint centred (%s)" % [name, c])
		inst.free()


func test_interior_markers_present_and_only_where_expected() -> void:
	for name: String in MODELS:
		var inst := _load_name(name)
		var found: Array[String] = []
		for n: Node in inst.find_children("*", "Node3D", true, false):
			if not n is MeshInstance3D and n.get_child_count() == 0:
				found.append(String(n.name))
		var expected: Array = MARKERS.get(name, [])
		for m: String in expected:
			assert_has(found, m, "%s has marker %s" % [name, m])
		assert_eq(found.size(), expected.size(), "%s markers %s" % [name, found])
		inst.free()


func test_room_floor_pivot_door_and_spawn() -> void:
	var room := _load_name("ph_int_room")
	var floor_box := _floor_extent(room)
	assert_almost(floor_box.get_center().x, 0.0, 0.05, "floor centred (x)")
	assert_almost(floor_box.get_center().z, 0.0, 0.05, "floor centred (z)")
	var door := _marker(room, "door_inside").origin
	var spawn := _marker(room, "spawn_inside").origin
	for p: Vector3 in [door, spawn]:
		assert_almost(p.y, 0.0, 0.02, "door/spawn marker on the floor")
		assert_almost(p.x, DOOR_X, 0.05, "door/spawn marker in line with the door")
	assert_true(door.z > ROOM_HALF.y - 0.6 and door.z < ROOM_HALF.y, "door_inside just inside the door (%s)" % door)
	assert_almost(ROOM_HALF.y - spawn.z, 0.8, 0.1, "spawn_inside 0.8 m inside")
	var lamp := _marker(room, "light_ceiling").origin
	assert_true(lamp.y > 1.4 and lamp.y < WALL_H, "hanging lantern point (%s)" % lamp)
	for m: String in ["light_window_1", "light_window_2"]:
		var p := _marker(room, m).origin
		assert_true(absf(p.x) < ROOM_HALF.x and absf(p.z) < ROOM_HALF.y and p.y > 0.9 and p.y < 1.8, m + " inside, at the window")
	room.free()


func test_room_door_opening_is_wide_enough() -> void:
	# stub boards left and right of the door: the free gap around DOOR_X in the stub band
	var room := _load_name("ph_int_room")
	var left := -9.0
	var right := 9.0
	for p: Vector3 in _vertices(room):
		if p.z > ROOM_HALF.y - 0.02 and p.y > 0.1 and p.y < 0.3:
			if p.x < DOOR_X:
				left = maxf(left, p.x)
			else:
				right = minf(right, p.x)
	assert_true(right - left >= DOOR_MIN_W, "door opening %f .. %f (>= %f m)" % [left, right, DOOR_MIN_W])
	room.free()


func test_room_is_open_to_the_45_degree_camera() -> void:
	# the front wall is only a stub (door posts and corners excepted), no ceiling over the room
	var room := _load_name("ph_int_room")
	var stub := 0.0
	var ceiling := 0
	for p: Vector3 in _vertices(room):
		if p.z > ROOM_HALF.y - 0.1 and absf(p.x - DOOR_X) > 0.7 and absf(p.x) < ROOM_HALF.x - 0.15:
			stub = maxf(stub, p.y)
		if p.y > 2.2 and absf(p.x) < ROOM_HALF.x - 0.2 and p.z > -0.9:
			ceiling += 1
	assert_true(stub <= 0.45, "front wall only a low stub (%f m)" % stub)
	assert_eq(ceiling, 0, "no ceiling / beams over the front two thirds of the room")
	room.free()


func test_stove_fire_and_desk_register() -> void:
	var stove := _load_name("ph_int_stove")
	var fire := _marker(stove, "light_fire").origin
	assert_true(fire.z > 0.2 and fire.y > 0.25 and fire.y < 0.8, "light_fire in front of the fire opening (%s)" % fire)
	stove.free()
	var desk := _load_name("ph_int_desk")
	var book := _marker(desk, "book").origin
	assert_true(book.y > 0.76 and book.y < 0.95, "book marker on the desk top (%s)" % book)
	assert_true(absf(book.x) < 0.3 and absf(book.z) < 0.2, "grave register lies in front of the rack")
	desk.free()


func test_interior_generator_and_sources() -> void:
	var script := "res://tools/blender/asset_interior.py"
	assert_true(FileAccess.file_exists(script), script)
	assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), "asset_interior.py exposes build()")
	assert_true(FileAccess.get_file_as_string("res://tools/blender/build_all.py").contains("\"asset_interior\""),
			"build_all.py builds the interior")
	for name: String in MODELS:
		assert_true(FileAccess.file_exists(BLEND_DIR + name + ".blend"), "source %s.blend" % name)


# --- layout -------------------------------------------------------------------------------

func test_layout_parses_and_references_interior_models() -> void:
	var lay := _layout()
	assert_eq(String(lay.room), "ph_int_room", "layout room")
	var ids: Array[String] = []
	for item: Dictionary in lay.items:
		assert_true(MODELS.has(String(item.asset)) and String(item.asset) != "ph_int_room", "known piece " + String(item.asset))
		assert_eq((item.pos as Array).size(), 2, "pos = [x, z]")
		assert_has(["floor", "flat", "wall", "on", "hang"], String(item.get("mount", "floor")), "mount of " + String(item.asset))
		if item.has("interact"):
			ids.append(String(item.interact))
	for id: String in INTERACTIVE:
		assert_has(ids, id, "interactive piece " + id)
	var room := _load_name("ph_int_room")
	assert_true(_v2(lay.door_inside).distance_to(_xz(_marker(room, "door_inside").origin)) < 0.05, "door_inside matches the room")
	assert_true(_v2(lay.spawn_inside).distance_to(_xz(_marker(room, "spawn_inside").origin)) < 0.05, "spawn_inside matches")
	room.free()


func test_layout_items_inside_the_room() -> void:
	for item: Dictionary in _layout().items:
		var r := _footprint(item)
		var name := String(item.asset)
		assert_true(r.position.x >= -ROOM_HALF.x - 0.01 and r.end.x <= ROOM_HALF.x + 0.01
				and r.position.y >= -ROOM_HALF.y - 0.01 and r.end.y <= ROOM_HALF.y + 0.01,
				"%s inside the room (%s)" % [name, r])
		var top := float(item.get("y", 0.0)) + _size(name).y
		assert_true(top <= WALL_H, "%s below the wall top (%f)" % [name, top])
		match String(item.get("mount", "floor")):
			"wall":
				var gap := minf(minf(ROOM_HALF.x - r.end.x, r.position.x + ROOM_HALF.x),
						minf(ROOM_HALF.y - r.end.y, r.position.y + ROOM_HALF.y))
				assert_true(gap <= 0.05, "%s hangs on a wall (gap %f)" % [name, gap])
				assert_true(float(item.y) >= 0.8, "%s hangs above furniture height" % name)
			"hang":
				assert_true(top > 2.2 and top <= 2.45, "%s hangs from the tie beam (top %f)" % [name, top])
			"on":
				assert_true(float(item.y) > 0.3, "%s stands on something" % name)


func test_layout_floor_pieces_do_not_overlap() -> void:
	var floor_items: Array[Dictionary] = []
	for item: Dictionary in _layout().items:
		if String(item.get("mount", "floor")) == "floor":
			floor_items.append(item)
	for i: int in floor_items.size():
		for j: int in range(i + 1, floor_items.size()):
			var a := _footprint(floor_items[i]).grow(-0.005)
			var b := _footprint(floor_items[j]).grow(-0.005)
			assert_false(a.intersects(b), "%s overlaps %s" % [floor_items[i].asset, floor_items[j].asset])
	# a piece standing on another lies within the supporter's footprint
	for item: Dictionary in _layout().items:
		if String(item.get("mount", "")) == "on" and String(item.get("on", "")) != "ph_int_room":
			var base := _footprint(_find_item(String(item.on)))
			assert_true(base.encloses(_footprint(item)), "%s lies on %s" % [item.asset, item.on])


func test_layout_walkways_reach_every_interactive_piece() -> void:
	# grid search from spawn_inside; the gravekeeper needs a free corridor of `walkway` width
	var lay := _layout()
	var half := float(lay.get("walkway", DOOR_MIN_W)) / 2.0
	assert_true(half * 2.0 >= DOOR_MIN_W, "walkway at least 0.9 m")
	var obstacles: Array[Rect2] = []
	for item: Dictionary in lay.items:
		if String(item.get("mount", "floor")) == "floor":
			obstacles.append(_footprint(item))
	var nx := int(2 * ROOM_HALF.x / GRID)
	var nz := int(2 * ROOM_HALF.y / GRID)
	var free := PackedByteArray()
	free.resize(nx * nz)
	for iz: int in nz:
		for ix: int in nx:
			var p := Vector2(-ROOM_HALF.x + (ix + 0.5) * GRID, -ROOM_HALF.y + (iz + 0.5) * GRID)
			var ok := absf(p.x) <= ROOM_HALF.x - half and absf(p.y) <= ROOM_HALF.y - half
			for r: Rect2 in obstacles:
				if ok and _dist_to_rect(p, r) < half:
					ok = false
			free[iz * nx + ix] = 1 if ok else 0
	var start := _cell(_v2(lay.spawn_inside), nx, nz)
	assert_eq(free[start], 1, "spawn_inside has room to move")
	var seen := PackedByteArray()
	seen.resize(nx * nz)
	var queue: Array[int] = [start]
	seen[start] = 1
	while not queue.is_empty():
		var c: int = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x := c % nx + d.x
			var z := c / nx + d.y
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var k := z * nx + x
			if free[k] == 1 and seen[k] == 0:
				seen[k] = 1
				queue.append(k)
	for item: Dictionary in lay.items:
		if not item.has("interact"):
			continue
		var use := _v2(item.use_pos)
		var r := _footprint(item)
		assert_false(r.has_point(use), "%s: use_pos outside the piece" % item.interact)
		assert_true(_dist_to_rect(use, r) <= 0.8, "%s: use_pos next to the piece" % item.interact)
		var front := Vector2(sin(deg_to_rad(float(item.rot_y))), cos(deg_to_rad(float(item.rot_y))))
		assert_true((use - _v2(item.pos)).normalized().dot(front) > 0.6, "%s: used from its front" % item.interact)
		assert_eq(seen[_cell(use, nx, nz)], 1, "%s reachable with a %.2f m walkway" % [item.interact, half * 2.0])


func test_layout_interactive_pieces_visible_from_the_camera() -> void:
	# 45° camera looking north (-Z): a piece in front (larger z) hides what lies lower than
	# (its height - distance); every interactive piece keeps at least 0.3 m in view.
	var lay := _layout()
	for item: Dictionary in lay.items:
		if not item.has("interact"):
			continue
		var r := _footprint(item)
		var h := _size(String(item.asset)).y
		for other: Dictionary in lay.items:
			if other == item or String(other.get("mount", "floor")) != "floor":
				continue
			var o := _footprint(other)
			if o.position.y <= r.end.y or o.end.x <= r.position.x or o.position.x >= r.end.x:
				continue
			var hidden := _size(String(other.asset)).y - (o.position.y - r.end.y)
			assert_true(h - hidden >= 0.3, "%s hides %s from the camera" % [other.asset, item.interact])


# --- helpers ------------------------------------------------------------------------

func _path(name: String) -> String:
	return INTERIOR_DIR + name + ".glb"


func _load_path(path: String) -> Node3D:
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _load_name(name: String) -> Node3D:
	return _load_path(_path(name))


func _layout() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	assert_true(data is Dictionary, "layout parses")
	return data if data is Dictionary else {"items": [], "room": "", "door_inside": [0, 0], "spawn_inside": [0, 0]}


func _find_item(asset: String) -> Dictionary:
	for item: Dictionary in _layout().items:
		if String(item.asset) == asset:
			return item
	return {}


func _v2(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _cell(p: Vector2, nx: int, nz: int) -> int:
	var ix := clampi(int((p.x + ROOM_HALF.x) / GRID), 0, nx - 1)
	var iz := clampi(int((p.y + ROOM_HALF.y) / GRID), 0, nz - 1)
	return iz * nx + ix


func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()


var _box_cache: Dictionary = {}


## Model AABB (local), cached per asset.
func _local_box(name: String) -> AABB:
	if not _box_cache.has(name):
		var inst := _load_name(name)
		_box_cache[name] = _aabb(inst)
		inst.free()
	return _box_cache[name]


func _size(name: String) -> Vector3:
	return _local_box(name).size


## Axis-aligned footprint (x, z) of a placed layout item, rotation included.
func _footprint(item: Dictionary) -> Rect2:
	var box := _local_box(String(item.asset))
	var basis := Basis(Vector3.UP, deg_to_rad(float(item.get("rot_y", 0.0))))
	var pos := _v2(item.pos)
	var r := Rect2()
	var first := true
	for cx: float in [box.position.x, box.end.x]:
		for cz: float in [box.position.z, box.end.z]:
			var p := basis * Vector3(cx, 0.0, cz)
			var q := Vector2(p.x + pos.x, p.z + pos.y)
			r = Rect2(q, Vector2.ZERO) if first else r.expand(q)
			first = false
	return r


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Transform of `node` relative to the scene root (instances are not in the tree).
func _xf(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


func _aabb(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes(inst):
		var b := _xf(mi, inst) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _marker(inst: Node3D, marker_name: String) -> Transform3D:
	var n := inst.find_child(marker_name, true, false) as Node3D
	assert_not_null(n, "marker " + marker_name)
	return _xf(n, inst) if n != null else Transform3D.IDENTITY


func _material_paths(inst: Node3D) -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			out.append(mat.resource_path if mat != null else "")
	return out


func _triangles(inst: Node3D) -> int:
	var tris := 0
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += idx.size() / 3 if idx.size() > 0 else verts.size() / 3
	return tris


func _vertices(inst: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for i: int in mi.mesh.get_surface_count():
			for p: Vector3 in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * p)
	return out


## Hut walls: vertices between 0.5 and 2.3 m (corner posts, window frames, shutters, door) close to
## the walls - the roof overhang, the lantern arm, bench and barrel front lie outside |x| 2.7 / |z| 2.05.
func _wall_band(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for p: Vector3 in _vertices(inst):
		if p.y > 0.5 and p.y < 2.3 and absf(p.x) < 2.7 and absf(p.z) < 2.05:
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


## Room floor: the plank tops at y ~ 0 inside the walls.
func _floor_extent(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for p: Vector3 in _vertices(inst):
		if absf(p.y) < 0.006 and absf(p.x) < ROOM_HALF.x + 0.05 and absf(p.z) < ROOM_HALF.y + 0.05:
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box
