extends TestCase
## Phase 6 assets (P5, docs/PHASE6_DESIGN.md §8): the building levels outside (Gruft, Kapelle,
## Lagerschuppen, Totenleuchter), the three interiors with their furniture, the mourners, the lifted
## old-grave pit and the new item models.
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front = south).

const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const GROUND_MAT := "res://assets/materials/mat_ground.tres"
const MIN_TRIS := 80
const MAX_SINK := 0.5
const GROUND_EPS := 0.02
const GENERATORS: Array[String] = ["asset_buildings_phase6", "asset_interiors_phase6", "asset_props_phase6", "asset_items"]
const ITEM_MIN := Vector3(0.1, 0.01, 0.1)
const ITEM_MAX := Vector3(0.45, 0.3, 0.45)

## name -> [category, min size, max size, triangle budget (§8)]
const MODELS := {
	"ph_bld_crypt_site": ["buildings", Vector3(2.4, 0.4, 2.2), Vector3(2.95, 1.2, 2.75), 1500],
	# G7 round 1: the stair goes 1 m down into the earth and starts 0.8 m in front of the footprint
	# (cheeks, treads, the deep portal) - taller, deeper and a little more geometry than in Phase 6.
	"ph_bld_crypt_l1": ["buildings", Vector3(2.4, 2.2, 2.2), Vector3(2.95, 3.9, 3.5), 4600],
	"ph_bld_crypt_l2": ["buildings", Vector3(2.4, 2.2, 2.2), Vector3(2.95, 3.9, 3.5), 4800],
	"ph_bld_crypt_l3": ["buildings", Vector3(2.4, 2.2, 2.2), Vector3(2.95, 3.9, 3.5), 5300],
	"ph_bld_chapel_ruin": ["buildings", Vector3(4.4, 2.5, 6.6), Vector3(5.35, 4.5, 7.8), 4000],
	"ph_bld_chapel_l1": ["buildings", Vector3(4.8, 6.0, 6.6), Vector3(5.35, 6.8, 7.4), 6000],
	"ph_bld_chapel_l2": ["buildings", Vector3(4.8, 7.5, 6.6), Vector3(5.35, 8.6, 7.4), 7000],
	"ph_bld_chapel_l3": ["buildings", Vector3(4.8, 7.5, 6.6), Vector3(5.35, 8.6, 7.4), 7500],
	"ph_prop_soul_lantern": ["props", Vector3(0.4, 2.2, 0.4), Vector3(0.9, 3.2, 0.9), 900],
	"ph_bld_shed_site": ["buildings", Vector3(2.6, 0.2, 3.0), Vector3(3.35, 0.8, 3.75), 800],
	"ph_bld_shed_l1": ["buildings", Vector3(3.0, 2.8, 3.3), Vector3(3.35, 3.4, 3.75), 3000],
	"ph_bld_shed_l2": ["buildings", Vector3(3.0, 2.8, 3.3), Vector3(3.35, 3.4, 3.75), 3400],
	"ph_bld_shed_l3": ["buildings", Vector3(3.0, 2.8, 3.3), Vector3(3.35, 3.4, 3.75), 3800],
	"ph_prop_grave_pit_foot": ["props", Vector3(1.3, 0.2, 2.6), Vector3(1.9, 0.7, 3.2), 900],
	"ph_int_crypt_room": ["interior", Vector3(8.0, 3.2, 7.4), Vector3(8.8, 4.2, 8.2), 9000],
	"ph_int_crypt_stair": ["interior", Vector3(1.4, 3.4, 2.9), Vector3(2.4, 4.4, 3.7), 2000],
	"ph_int_crypt_table": ["interior", Vector3(1.9, 0.75, 0.8), Vector3(2.3, 1.0, 1.2), 1200],
	"ph_int_crypt_niche": ["interior", Vector3(1.9, 1.4, 0.8), Vector3(2.2, 1.8, 1.0), 900],
	"ph_int_crypt_niche_sealed": ["interior", Vector3(1.9, 1.4, 0.08), Vector3(2.2, 1.8, 1.0), 500],
	"ph_int_crypt_lantern": ["interior", Vector3(0.12, 0.7, 0.12), Vector3(0.3, 1.2, 0.3), 600],
	"ph_int_candle_niche": ["interior", Vector3(0.5, 0.45, 0.2), Vector3(0.9, 0.8, 0.4), 400],
	"ph_int_ossuary_shelf": ["interior", Vector3(2.2, 1.8, 0.4), Vector3(2.8, 2.3, 0.8), 2500],
	"ph_int_bone_box": ["interior", Vector3(0.4, 0.2, 0.25), Vector3(0.65, 0.34, 0.4), 400],
	"ph_int_bone_rack": ["interior", Vector3(1.2, 1.4, 0.35), Vector3(1.6, 1.9, 0.6), 1500],
	"ph_int_name_board": ["interior", Vector3(0.8, 0.5, 0.04), Vector3(1.3, 1.0, 0.2), 500],
	"ph_int_sealed_passage": ["interior", Vector3(1.0, 1.8, 0.2), Vector3(1.4, 2.2, 0.6), 1200],
	"ph_int_sealed_passage_grille": ["interior", Vector3(1.0, 1.8, 0.4), Vector3(1.4, 2.2, 1.2), 1400],
	"ph_int_chapel_room": ["interior", Vector3(5.0, 3.8, 9.5), Vector3(6.0, 5.0, 10.4), 9000],
	"ph_int_altar": ["interior", Vector3(1.4, 1.4, 0.8), Vector3(2.0, 1.9, 1.2), 1800],
	"ph_int_catafalque": ["interior", Vector3(1.8, 0.5, 0.7), Vector3(2.2, 0.8, 1.0), 900],
	"ph_int_pew_rough": ["interior", Vector3(1.5, 0.4, 0.2), Vector3(2.1, 0.6, 0.45), 500],
	"ph_int_pew": ["interior", Vector3(1.8, 0.85, 0.5), Vector3(2.2, 1.15, 0.9), 900],
	"ph_int_bell_rope": ["interior", Vector3(0.05, 2.0, 0.05), Vector3(0.4, 2.8, 0.4), 300],
	"ph_int_candelabrum": ["interior", Vector3(0.3, 1.3, 0.3), Vector3(0.6, 1.8, 0.6), 800],
	"ph_int_stained_window": ["interior", Vector3(0.6, 1.1, 0.005), Vector3(0.8, 1.4, 0.1), 600],
	"ph_int_holy_water": ["interior", Vector3(0.3, 0.7, 0.3), Vector3(0.6, 1.1, 0.6), 400],
	"ph_int_shed_room": ["interior", Vector3(3.1, 2.9, 3.4), Vector3(3.6, 3.6, 3.9), 5000],
	"ph_int_shed_rack": ["interior", Vector3(1.5, 1.8, 0.4), Vector3(2.2, 2.2, 0.7), 1500],
	"ph_int_wood_rack": ["interior", Vector3(1.2, 1.0, 0.4), Vector3(1.6, 1.5, 0.7), 1200],
	"ph_int_stone_bin": ["interior", Vector3(0.8, 0.4, 0.5), Vector3(1.2, 0.7, 0.8), 800],
	"ph_chr_mourner_a": ["characters", Vector3(0.4, 1.1, 0.6), Vector3(0.7, 1.4, 1.0), 2500],
	"ph_chr_mourner_b": ["characters", Vector3(0.4, 1.1, 0.6), Vector3(0.7, 1.4, 1.0), 2500],
	"ph_chr_mourner_c": ["characters", Vector3(0.4, 1.1, 0.6), Vector3(0.7, 1.4, 1.0), 2500],
	"ph_chr_mourner_d": ["characters", Vector3(0.4, 1.1, 0.6), Vector3(0.7, 1.4, 1.0), 2500],
	"ph_item_altar_candle": ["items", ITEM_MIN, ITEM_MAX, 800],
	"ph_item_bone_box": ["items", ITEM_MIN, ITEM_MAX, 800],
	"ph_item_bone_box_full": ["items", ITEM_MIN, ITEM_MAX, 800],
}
const LEVEL_WINDOWS: Array[String] = ["light_window_1", "light_window_2", "light_window_3", "light_window_4"]
## Markers each model must carry (glTF empties -> Node3D leaves); every other model carries none.
const MARKERS := {
	"ph_bld_crypt_site": ["build"],
	"ph_bld_crypt_l1": ["door_outside", "build"],
	"ph_bld_crypt_l2": ["door_outside", "build"],
	"ph_bld_crypt_l3": ["door_outside", "build", "light_lantern", "inscription"],
	"ph_bld_chapel_ruin": ["build"],
	"ph_bld_chapel_l1": ["door_outside", "build", "light_window_1", "light_window_2", "light_window_3", "light_window_4"],
	"ph_bld_chapel_l2": ["door_outside", "build", "light_window_1", "light_window_2", "light_window_3", "light_window_4"],
	"ph_bld_chapel_l3": ["door_outside", "build", "light_window_1", "light_window_2", "light_window_3", "light_window_4",
			"light_choir"],
	"ph_prop_soul_lantern": ["light_soul"],
	"ph_bld_shed_site": ["build"],
	"ph_bld_shed_l1": ["door_outside", "build"],
	"ph_bld_shed_l2": ["door_outside", "build"],
	"ph_bld_shed_l3": ["door_outside", "build"],
	"ph_int_crypt_room": ["door_inside", "spawn_inside"],
	"ph_int_crypt_stair": ["light_window_1"],
	"ph_int_crypt_table": ["slot_corpse"],
	"ph_int_crypt_niche": ["slot_corpse", "chill"],
	"ph_int_crypt_lantern": ["light_ceiling"],
	"ph_int_candle_niche": ["light_candle"],
	"ph_int_ossuary_shelf": ["box_1", "box_2", "box_3", "box_4", "box_5", "box_6",
			"stone_1", "stone_2", "stone_3", "stone_4", "stone_5", "stone_6"],
	"ph_int_name_board": ["names"],
	"ph_int_sealed_passage_grille": ["light_below"],
	"ph_int_chapel_room": ["door_inside", "spawn_inside", "light_window_1", "light_window_2", "light_window_3", "light_window_4"],
	"ph_int_altar": ["light_candle_1", "light_candle_2"],
	"ph_int_catafalque": ["slot_corpse"],
	"ph_int_pew": ["pew_seat_1", "pew_seat_2", "pew_seat_3", "pew_seat_4"],
	"ph_int_candelabrum": ["light_candle"],
	"ph_int_stained_window": ["light_stain"],
	"ph_int_shed_room": ["door_inside", "spawn_inside", "light_window_1", "light_lantern"],
	"ph_int_shed_rack": ["book"],
}
## Models with a glowing lantern glass / candle flame (mat_emissive_warm, like the hut's lantern).
const MAY_GLOW: Array[String] = ["ph_bld_crypt_l3", "ph_prop_soul_lantern", "ph_int_crypt_lantern", "ph_int_candle_niche",
		"ph_int_altar", "ph_int_candelabrum", "ph_int_shed_room"]
## §4 footprints (x × z) of the building sites and the building families.
const FOOTPRINTS := {"crypt": Vector2(2.8, 2.6), "chapel": Vector2(5.2, 7.0), "shed": Vector2(3.2, 3.6)}
const FOOTPRINT_SLACK := 0.2
## G7 round 1: the crypt stair (levels 1–3) reaches this far below the ground and in front of the footprint.
const CRYPT_STAIR_DEPTH := 1.4
const CRYPT_STAIR_FRONT := 0.4
const CRYPT_STAIR_LEVELS: Array[String] = ["ph_bld_crypt_l1", "ph_bld_crypt_l2", "ph_bld_crypt_l3"]
const LEVELS := {
	"crypt": ["ph_bld_crypt_site", "ph_bld_crypt_l1", "ph_bld_crypt_l2", "ph_bld_crypt_l3"],
	"chapel": ["ph_bld_chapel_ruin", "ph_bld_chapel_l1", "ph_bld_chapel_l2", "ph_bld_chapel_l3"],
	"shed": ["ph_bld_shed_site", "ph_bld_shed_l1", "ph_bld_shed_l2", "ph_bld_shed_l3"],
}
const CORPSE_LENGTH := 1.74        # ph_prop_corpse*: 1.71–1.74 m along X

var _to_free: Array[Node] = []


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()


# --- every model ---------------------------------------------------------------------------------

func test_every_model_exists_and_loads() -> void:
	for name: String in MODELS:
		var path := _path(name)
		assert_true(ResourceLoader.exists(path), "missing " + path)
		var scene := load(path) as PackedScene
		assert_not_null(scene, "not a PackedScene: " + path)
		if scene == null:
			continue
		var inst := scene.instantiate() as Node3D
		assert_not_null(inst, "root is not a Node3D: " + path)
		if inst == null:
			continue
		assert_true(_meshes(inst).size() >= 1, name + " has a mesh")
		inst.free()


func test_models_are_static() -> void:
	for name: String in MODELS:
		var inst := _load_free(name)
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])


func test_all_surfaces_use_shared_materials() -> void:
	for name: String in MODELS:
		for path: String in _material_paths(name):
			assert_true(path.begins_with(MATERIAL_DIR) and path.ends_with(".tres"),
					"%s uses a shared material (got '%s')" % [name, path])


func test_triangle_budgets() -> void:
	for name: String in MODELS:
		var tris := _triangles(name)
		assert_true(tris <= int(MODELS[name][3]), "%s: %d triangles > budget %d" % [name, tris, MODELS[name][3]])
		assert_true(tris >= MIN_TRIS, "%s: only %d triangles" % [name, tris])


func test_bounding_box_sizes() -> void:
	for name: String in MODELS:
		var box := _aabb(_load_free(name))
		var lo: Vector3 = MODELS[name][1]
		var hi: Vector3 = MODELS[name][2]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis],
					"%s size %s outside %s..%s (axis %d)" % [name, box.size, lo, hi, axis])


func test_pivot_on_the_ground() -> void:
	for name: String in MODELS:
		if name in ["ph_int_bell_rope", "ph_int_stained_window"]:
			continue    # hung from the ceiling / set into the wall: pivot = floor of the room, they start higher
		var box := _aabb(_load_free(name))
		assert_true(box.position.y <= GROUND_EPS, "%s rests on the ground (bottom %f)" % [name, box.position.y])
		var sink := CRYPT_STAIR_DEPTH if name in CRYPT_STAIR_LEVELS else MAX_SINK
		assert_true(box.position.y >= -sink, "%s sinks too deep (bottom %f)" % [name, box.position.y])


func test_markers_present_and_only_where_expected() -> void:
	for name: String in MODELS:
		var inst := _load_free(name)
		var found: Array[String] = []
		for n: Node in inst.find_children("*", "Node3D", true, false):
			if not n is MeshInstance3D and n.get_child_count() == 0 and _meshes(n).is_empty():
				found.append(String(n.name))
		var expected: Array = MARKERS.get(name, [])
		for m: String in expected:
			assert_has(found, m, "%s has marker %s" % [name, m])
		assert_eq(found.size(), expected.size(), "%s markers %s" % [name, found])


func test_only_lanterns_and_candles_glow() -> void:
	for name: String in MODELS:
		if name in MAY_GLOW:
			continue
		assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")


func test_no_cold_saturated_colour() -> void:
	# ART_DIRECTION §3: saturated cold colour is for the supernatural only – even the shimmer behind
	# the grille is a blue-grey; the colour comes from its light (#7FA0C8)
	for name: String in MODELS:
		var worst := 0.0
		for c: Color in _colours(name):
			var s := c.linear_to_srgb()
			if s.h > 0.45 and s.h < 0.72 and s.v > 0.25:
				worst = maxf(worst, s.s)
		assert_true(worst < 0.35, "%s has a saturated cold colour (saturation %f)" % [name, worst])


func test_blender_sources_and_generators_exist() -> void:
	for name: String in MODELS:
		var src := BLEND_DIR + String(MODELS[name][0]) + "/" + name + ".blend"
		assert_true(FileAccess.file_exists(src), "source " + src)
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")


func test_exports_are_deterministic() -> void:
	# Phase-5 finding: UVs jittered by 1 ulp between runs; lib_painted snaps them before every export
	var lib := FileAccess.get_file_as_string("res://tools/blender/lib_painted.py")
	assert_true(lib.contains("def _quantize_uvs("), "lib_painted quantizes UVs")
	assert_true(lib.count("_quantize_uvs(") >= 3, "export() and export_rigged() both call it")
	assert_true(lib.count("_canonical_glb(") >= 3, "triangle order canonicalised after both exports")


# --- buildings outside ---------------------------------------------------------------------------

func test_levels_share_footprint_and_markers() -> void:
	for b: String in LEVELS:
		var fp: Vector2 = FOOTPRINTS[b]
		var build0 := _marker(_load_free(LEVELS[b][0]), "build").origin
		var door := Vector3.INF
		for name: String in LEVELS[b]:
			var inst := _load_free(name)
			var box := _aabb(inst)
			var front := CRYPT_STAIR_FRONT if name in CRYPT_STAIR_LEVELS else 0.0
			assert_true(box.size.x <= fp.x + FOOTPRINT_SLACK and box.size.z <= fp.y + FOOTPRINT_SLACK + front,
					"%s fits the %s footprint (%s)" % [name, fp, box.size])
			var c := box.get_center()
			assert_true(absf(c.x) < 0.25 and absf(c.z - front / 2.0) < 0.4, "%s centred on the site (%s)" % [name, c])
			var bm := _marker(inst, "build").origin
			assert_true(bm.is_equal_approx(build0), "%s: build marker as on the site (%s)" % [name, bm])
			assert_almost(bm.y, 0.0, 0.01, name + " build on the ground")
			assert_true(absf(bm.x) > fp.x / 2 or absf(bm.z) > fp.y / 2, "%s: build marker beside the footprint" % name)
			if inst.find_child("door_outside", true, false) == null:
				continue
			var d := _marker(inst, "door_outside").origin
			if door == Vector3.INF:
				door = d
			assert_true(d.is_equal_approx(door), "%s: same door spot on every level" % name)
			# G7 round 1: the crypt door stands at the foot of its stair, in front of the portal (z 0.42).
			var door_min := 0.42 if b == "crypt" else fp.y / 2 - 0.05
			assert_true(d.z > door_min, "%s: door faces south, the camera (z %.2f)" % [name, d.z])
			assert_true(d.distance_to(bm) > 0.9, "%s: the upgrade prompt is not at the door" % name)


func test_crypt_is_low_with_a_door_and_stairs_to_the_south() -> void:
	for name: String in LEVELS.crypt:
		assert_true(_aabb(_load_free(name)).end.y <= 2.6, "%s ≤ 2.6 m" % name)
	var inst := _load_free("ph_bld_crypt_l1")
	# the hill: mat_ground grass behind the portal, not higher than 1 m
	var hill := 0.0
	for p: Vector3 in _vertices_with(inst, GROUND_MAT):
		if p.z < -0.3:
			hill = maxf(hill, p.y)
	assert_true(hill > 0.6 and hill <= 1.0, "a sod hill over the vault (%.2f m)" % hill)
	# G7 round 1: treads of the stair going down into the earth in front of the door
	var treads := 0
	for p: Vector3 in _vertices(inst):
		if absf(p.x) < 0.45 and p.z > 0.45 and p.z < 1.65 and p.y > -1.0 and p.y < 0.02:
			treads += 1
	assert_true(treads > 30, "the stair between the cheeks (%d vertices)" % treads)
	var door := _marker(inst, "door_outside").origin
	assert_true(door.y < -0.6 and door.z > 0.42 and door.z < 1.0, "the door at the foot of the stair %s" % door)
	var l3 := _load_free("ph_bld_crypt_l3")
	var lamp := _marker(l3, "light_lantern").origin
	assert_true(lamp.y > 1.5 and lamp.y < 2.4 and lamp.z > 0.4, "lantern on the portal front %s" % lamp)
	var ins := _marker(l3, "inscription")
	assert_true(ins.basis.is_equal_approx(Basis.IDENTITY) and ins.origin.z > 0.4, "lintel inscription faces south %s" % ins.origin)
	assert_true(_triangles("ph_bld_crypt_l2") > _triangles("ph_bld_crypt_l1") and _triangles("ph_bld_crypt_l3") > _triangles("ph_bld_crypt_l2"),
			"every level adds something")


func test_chapel_heights_bell_and_windows() -> void:
	assert_true(_aabb(_load_free("ph_bld_chapel_l1")).end.y <= 6.8, "ridge + gable cross ≤ 6.8 m")
	for name: String in ["ph_bld_chapel_l2", "ph_bld_chapel_l3"]:
		var inst := _load_free(name)
		assert_true(_aabb(inst).end.y <= 8.6, "%s turret cross ≤ 8.6 m" % name)
		var bell := inst.find_child("bell", true, false) as MeshInstance3D
		assert_not_null(bell, name + ": the bell is its own mesh node (swing)")
		if bell != null:
			assert_true(bell.position.y > 6.5 and bell.position.z > 1.0, "%s bell pivot in the turret above the ridge %s" % [name, bell.position])
			assert_true(bell.get_aabb().end.y <= 0.1, "bell hangs below its yoke axis")
	assert_null(_load_free("ph_bld_chapel_l1").find_child("bell", true, false), "no turret on level 1")
	assert_true(_aabb(_load_free("ph_bld_chapel_ruin")).end.y < 4.5, "the ruin is roofless and low")
	var l3 := _load_free("ph_bld_chapel_l3")
	assert_true(_marker(l3, "light_choir").origin.z < -3.4, "choir window light on the north side")
	for m: String in LEVEL_WINDOWS:
		var p := _marker(l3, m).origin
		assert_true(absf(p.x) > 2.3 and p.y > 1.4, "%s outside a side window %s" % [m, p])


func test_shed_eave_and_lean_to() -> void:
	for name: String in ["ph_bld_shed_l1", "ph_bld_shed_l2", "ph_bld_shed_l3"]:
		var verts := _vertices_of(name)
		var east := 0.0
		var west := 0.0
		for p: Vector3 in verts:
			if p.x > 1.3:
				east = maxf(east, p.y)
			if p.x < -1.3:
				west = maxf(west, p.y)
		assert_true(east <= 3.4 and east > west + 0.6, "%s: lean-to falls west (east %.2f, west %.2f)" % [name, east, west])
	assert_true(_triangles("ph_bld_shed_l2") > _triangles("ph_bld_shed_l1") + 200, "level 2 adds the handcart")


func test_soul_lantern_light_in_its_house() -> void:
	var inst := _load_free("ph_prop_soul_lantern")
	var m := _marker(inst, "light_soul").origin
	assert_true(m.y > 1.8 and m.y < _aabb(inst).end.y - 0.3 and Vector2(m.x, m.z).length() < 0.05, "light in the lantern house %s" % m)


func test_pit_foot_heap_at_the_foot_end() -> void:
	var box := _aabb(_load_free("ph_prop_grave_pit_foot"))
	assert_true(box.end.z > 1.5 and box.position.z > -1.3, "heap at +Z (%s)" % box)
	assert_true(absf(box.get_center().x) < 0.1, "no heap at the side (%s)" % box)


# --- interiors -------------------------------------------------------------------------------------

func test_room_entries_face_the_camera() -> void:
	for name: String in ["ph_int_crypt_room", "ph_int_chapel_room", "ph_int_shed_room"]:
		var inst := _load_free(name)
		var door := _marker(inst, "door_inside").origin
		var spawn := _marker(inst, "spawn_inside").origin
		assert_true(door.z > spawn.z and spawn.z > 0.5, "%s: entry at the south, spawn inside (%s / %s)" % [name, door, spawn])
		assert_almost(spawn.y, 0.0, 0.01, name + " spawn on the floor")


func test_corpse_slots_fit_a_body() -> void:
	for name: String in ["ph_int_crypt_table", "ph_int_crypt_niche", "ph_int_catafalque"]:
		var inst := _load_free(name)
		var s := _marker(inst, "slot_corpse")
		var box := _aabb(inst)
		assert_true(s.basis.x.is_equal_approx(Vector3.RIGHT), "%s: body along X" % name)
		assert_true(s.origin.y > 0.45 and s.origin.y < 0.95, "%s slot height %.2f" % [name, s.origin.y])
		assert_true(box.size.x >= CORPSE_LENGTH + 0.05, "%s holds a %.2f m body (%.2f)" % [name, CORPSE_LENGTH, box.size.x])
	var niche := _load_free("ph_int_crypt_niche")
	var chill := _marker(niche, "chill").origin
	assert_true(chill.y > _marker(niche, "slot_corpse").origin.y, "cold breath above the bench")
	var sealed := _aabb(_load_free("ph_int_crypt_niche_sealed"))
	assert_almost(sealed.size.x, _aabb(niche).size.x, 0.05, "sealed and open niche share the width")
	assert_almost(sealed.end.z, _aabb(niche).end.z, 0.05, "and the front plane")


func test_ossuary_places() -> void:
	var inst := _load_free("ph_int_ossuary_shelf")
	var box := _aabb(_load_free("ph_int_bone_box")).size
	for i: int in 6:
		var a := _marker(inst, "box_%d" % (i + 1)).origin
		for j: int in range(i + 1, 6):
			var b := _marker(inst, "box_%d" % (j + 1)).origin
			assert_true(absf(a.x - b.x) >= box.x or absf(a.y - b.y) >= box.y + 0.1, "boxes %d/%d do not overlap" % [i + 1, j + 1])
		var s := _marker(inst, "stone_%d" % (i + 1))
		assert_almost(s.origin.y, 0.0, 0.01, "stone %d on the floor" % (i + 1))
		assert_true(s.origin.z > 0.25, "stone %d at the foot of the shelf" % (i + 1))
		assert_true(s.basis.y.z < -0.05 and s.basis.y.z > -0.2, "stone %d leans back" % (i + 1))


func test_grille_has_a_cold_shimmer_and_bones_stay_calm() -> void:
	var cool := 0
	for c: Color in _colours("ph_int_sealed_passage_grille"):
		var s := c.linear_to_srgb()
		if s.h > 0.5 and s.h < 0.66 and s.s > 0.12 and s.v > 0.4:
			cool += 1
	assert_true(cool >= 8, "blue-grey shimmer below the steps (%d vertices)" % cool)
	var below := _marker(_load_free("ph_int_sealed_passage_grille"), "light_below").origin
	assert_true(below.z < 0.0, "the light sits behind the grille %s" % below)
	assert_true(_aabb(_load_free("ph_int_bone_rack")).size.y < 1.9, "the rack stays a quiet piece of furniture")


func test_chapel_furniture() -> void:
	var pew := _load_free("ph_int_pew")
	for i: int in 3:
		var a := _marker(pew, "pew_seat_%d" % (i + 1)).origin
		var b := _marker(pew, "pew_seat_%d" % (i + 2)).origin
		assert_true(b.x - a.x > 0.4, "seats %d/%d apart" % [i + 1, i + 2])
		assert_almost(a.y, 0.0, 0.01, "seat marker on the floor")
	var altar := _load_free("ph_int_altar")
	for k: int in 2:
		var flame := altar.find_child("flame_%d" % (k + 1), true, false) as MeshInstance3D
		assert_not_null(flame, "altar flame %d is its own mesh (lit only during a rite)" % (k + 1))
	var warm := 0
	for c: Color in _colours("ph_int_stained_window"):
		var s := c.linear_to_srgb()
		if (s.h < 0.17 or s.h > 0.95) and s.s > 0.35:
			warm += 1
	assert_true(warm > 60, "warm coloured glass (%d vertices)" % warm)


func test_mourners_sit_bowed() -> void:
	for n: String in ["a", "b", "c", "d"]:
		var name := "ph_chr_mourner_" + n
		var box := _aabb(_load_free(name))
		assert_true(box.end.y < 1.4, "%s seated (%.2f m)" % [name, box.end.y])
		assert_true(box.end.z > 0.5, "%s feet forward (+Z)" % name)
		var dark := 0
		var cols := _colours(name)
		for c: Color in cols:
			if c.linear_to_srgb().v < 0.35:
				dark += 1
		assert_true(dark > cols.size() / 2, "%s in dark clothes" % name)


func test_items_are_icon_sized() -> void:
	for name: String in ["ph_item_altar_candle", "ph_item_bone_box", "ph_item_bone_box_full"]:
		var box := _aabb(_load_free(name))
		assert_true(absf(box.get_center().x) < 0.03 and absf(box.get_center().z) < 0.03, name + " centred")


# --- helpers ---------------------------------------------------------------------------------------

func _path(name: String) -> String:
	return MODEL_DIR + String(MODELS[name][0]) + "/" + name + ".glb"


func _load_free(name: String) -> Node3D:
	var inst := (load(_path(name)) as PackedScene).instantiate() as Node3D
	_to_free.append(inst)
	return inst


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


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


func _material_paths(name: String) -> Array[String]:
	var out: Array[String] = []
	for mi: MeshInstance3D in _meshes(_load_free(name)):
		for i: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			out.append(mat.resource_path if mat != null else "")
	return out


func _triangles(name: String) -> int:
	var tris := 0
	for mi: MeshInstance3D in _meshes(_load_free(name)):
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


func _vertices_with(inst: Node3D, material: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for i: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null or mat.resource_path != material:
				continue
			for p: Vector3 in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * p)
	return out


func _vertices_of(name: String) -> PackedVector3Array:
	return _vertices(_load_free(name))


func _colours(name: String) -> PackedColorArray:
	var out := PackedColorArray()
	for mi: MeshInstance3D in _meshes(_load_free(name)):
		for i: int in mi.mesh.get_surface_count():
			out.append_array(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] as PackedColorArray)
	return out
