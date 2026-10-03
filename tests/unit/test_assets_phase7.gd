extends TestCase
## Phase 7 assets (P5, docs/PHASE7_DESIGN.md §8): the eight villagers on the shared rig, the seated guests and
## students, the village buildings (§4.2), props and environment, the three interiors (§4.3), the anatomy
## furniture, the new items and the D1 poppy posy. The anatomy pieces are checked for the "no gore" rule.
## Sizes use Godot axes: x = width (east), y = height, z = depth (south = towards the camera).

const Chars := preload("res://tests/unit/test_assets_characters.gd")
const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const FOLIAGE := "res://assets/materials/mat_foliage.tres"
const MIN_TRIS := 40
const MAX_SINK := 0.5
const GROUND_EPS := 0.02
const GENERATORS: Array[String] = ["asset_villagers", "asset_village_buildings", "asset_village_props",
		"asset_village_interiors", "asset_anatomy", "asset_items"]
const ITEM_MIN := Vector3(0.1, 0.01, 0.1)
const ITEM_MAX := Vector3(0.45, 0.3, 0.45)

## name -> [category, min size, max size, triangle budget (§8)]
const MODELS := {
	# buildings (§4.2 footprint x × z, §8 heights and budgets)
	"ph_bld_v_church": ["buildings", Vector3(6.8, 15.5, 11.0), Vector3(8.0, 17.0, 12.5), 9000],
	"ph_bld_v_office": ["buildings", Vector3(8.0, 7.5, 6.0), Vector3(9.0, 8.5, 7.5), 6500],
	"ph_bld_v_inn": ["buildings", Vector3(9.0, 7.5, 6.0), Vector3(10.6, 8.5, 7.8), 7000],
	"ph_bld_v_smithy": ["buildings", Vector3(5.5, 5.0, 5.5), Vector3(6.8, 6.5, 6.8), 4500],
	"ph_bld_v_shop": ["buildings", Vector3(5.5, 5.0, 4.5), Vector3(7.2, 6.5, 5.6), 4500],
	"ph_bld_v_surgery": ["buildings", Vector3(6.0, 7.0, 7.4), Vector3(7.4, 8.6, 8.6), 6000],
	"ph_bld_v_remise": ["buildings", Vector3(6.5, 4.4, 4.5), Vector3(8.0, 5.0, 5.6), 3000],
	"ph_bld_v_cottage_a": ["buildings", Vector3(5.4, 4.0, 4.0), Vector3(6.6, 5.0, 5.6), 3000],
	"ph_bld_v_cottage_b": ["buildings", Vector3(5.4, 4.0, 4.0), Vector3(6.6, 5.1, 5.6), 3000],
	"ph_bld_v_house_a": ["buildings", Vector3(5.0, 6.0, 4.0), Vector3(7.6, 7.6, 6.6), 4500],
	"ph_bld_v_house_b": ["buildings", Vector3(5.0, 6.0, 4.0), Vector3(7.6, 7.6, 6.6), 4500],
	"ph_bld_v_house_c": ["buildings", Vector3(5.0, 6.0, 4.0), Vector3(7.6, 7.6, 6.8), 4500],
	"ph_bld_v_inn2": ["buildings", Vector3(5.0, 6.0, 4.0), Vector3(9.0, 7.6, 6.6), 4500],
	# props and environment
	"ph_prop_v_well": ["props", Vector3(1.2, 2.4, 1.2), Vector3(2.4, 3.0, 2.4), 1500],
	"ph_prop_v_bridge": ["props", Vector3(5.8, 0.6, 2.4), Vector3(6.8, 1.6, 3.0), 3000],
	"ph_prop_v_board": ["props", Vector3(1.0, 1.8, 0.1), Vector3(1.8, 2.4, 0.8), 800],
	"ph_prop_v_shrine": ["props", Vector3(0.3, 1.8, 0.3), Vector3(0.8, 2.6, 0.8), 600],
	"ph_prop_v_sign": ["props", Vector3(0.9, 1.5, 0.05), Vector3(1.6, 2.2, 0.4), 400],
	"ph_prop_v_ribbon": ["props", Vector3(0.1, 0.3, 0.005), Vector3(0.3, 0.6, 0.1), 150],
	"ph_prop_v_bench": ["props", Vector3(1.4, 0.4, 0.25), Vector3(1.8, 0.6, 0.5), 400],
	"ph_prop_v_wash_stones": ["props", Vector3(1.0, 0.1, 0.8), Vector3(2.4, 0.7, 2.0), 500],
	"ph_env_linden_old": ["environment", Vector3(6.0, 7.5, 6.0), Vector3(11.0, 9.4, 11.0), 6000],
	"ph_env_brook": ["environment", Vector3(2.4, 0.05, 40.0), Vector3(4.6, 0.6, 46.0), 2000],
	"ph_env_garden_fence": ["environment", Vector3(1.8, 0.8, 0.05), Vector3(2.2, 1.1, 0.3), 300],
	"ph_prop_milestone": ["props", Vector3(0.4, 0.6, 0.25), Vector3(0.9, 1.2, 0.7), 500],
	"ph_prop_corpse_poppy": ["props", Vector3(0.05, 0.01, 0.03), Vector3(0.25, 0.12, 0.2), 300],
	# interiors
	"ph_int_inn_room": ["interior", Vector3(8.0, 2.9, 6.0), Vector3(9.0, 3.6, 7.0), 9000],
	"ph_int_inn_bar": ["interior", Vector3(2.2, 1.4, 0.6), Vector3(2.7, 1.8, 1.4), 1500],
	"ph_int_inn_table": ["interior", Vector3(1.2, 0.7, 1.4), Vector3(1.6, 0.85, 1.9), 600],
	"ph_int_inn_stove": ["interior", Vector3(1.0, 1.8, 1.0), Vector3(1.7, 2.2, 1.7), 1200],
	"ph_int_inn_barrels": ["interior", Vector3(0.7, 0.8, 0.8), Vector3(1.2, 1.0, 1.4), 800],
	"ph_int_inn_stairs": ["interior", Vector3(0.8, 2.4, 2.4), Vector3(1.2, 3.6, 3.0), 600],
	"ph_int_surgery_room": ["interior", Vector3(6.0, 2.9, 5.0), Vector3(7.0, 3.6, 6.0), 7000],
	"ph_int_surgery_table": ["interior", Vector3(1.8, 0.75, 0.7), Vector3(2.2, 1.0, 1.0), 900],
	"ph_int_surgery_cabinet": ["interior", Vector3(1.0, 1.8, 0.35), Vector3(1.4, 2.1, 0.6), 1800],
	"ph_int_surgery_desk": ["interior", Vector3(1.0, 1.1, 0.5), Vector3(1.5, 1.5, 0.8), 1200],
	"ph_int_surgery_bag": ["interior", Vector3(0.3, 0.25, 0.1), Vector3(0.5, 0.4, 0.3), 400],
	"ph_int_surgery_lectern": ["interior", Vector3(0.5, 1.0, 0.4), Vector3(0.9, 1.3, 0.7), 800],
	"ph_int_surgery_bench": ["interior", Vector3(1.4, 0.4, 0.25), Vector3(1.8, 0.6, 0.5), 600],
	"ph_int_surgery_shutters": ["interior", Vector3(0.9, 1.2, 0.03), Vector3(1.1, 1.4, 0.15), 400],
	"ph_int_office_room": ["interior", Vector3(6.0, 2.9, 5.0), Vector3(7.0, 3.6, 6.0), 7000],
	"ph_int_office_desk": ["interior", Vector3(1.2, 0.95, 0.6), Vector3(1.6, 1.3, 0.9), 1000],
	"ph_int_office_shelf": ["interior", Vector3(1.3, 1.8, 0.35), Vector3(1.7, 2.1, 0.6), 1200],
	"ph_int_office_poor_box": ["interior", Vector3(0.6, 0.45, 0.4), Vector3(0.9, 0.7, 0.7), 600],
	"ph_int_office_lectern": ["interior", Vector3(0.5, 1.0, 0.4), Vector3(0.9, 1.4, 0.7), 700],
	# anatomy
	"ph_int_pult": ["interior", Vector3(1.2, 1.0, 0.6), Vector3(1.6, 1.4, 0.9), 2400],
	"ph_int_collection_shelf": ["interior", Vector3(1.4, 1.9, 0.35), Vector3(1.7, 2.1, 0.6), 2000],
	# seated figures without a rig
	"ph_chr_guest_a": ["characters", Vector3(0.4, 1.1, 0.5), Vector3(0.8, 1.5, 1.0), 2500],
	"ph_chr_guest_b": ["characters", Vector3(0.4, 1.1, 0.5), Vector3(0.8, 1.5, 1.0), 2500],
	"ph_chr_student_a": ["characters", Vector3(0.4, 1.1, 0.5), Vector3(0.8, 1.5, 1.0), 2500],
	"ph_chr_student_b": ["characters", Vector3(0.4, 1.1, 0.5), Vector3(0.8, 1.5, 1.0), 2500],
	"ph_chr_student_c": ["characters", Vector3(0.4, 1.1, 0.5), Vector3(0.8, 1.5, 1.0), 2500],
}
const ITEMS: Array[String] = ["prep_jar", "prep_jar_small", "spirits", "beeswax", "anatomy_case", "specimen_jar",
		"specimen_jar_eyes", "specimen_bundle", "display_specimen", "bone_specimen", "fever_tincture", "wound_salve",
		"corpse_balm", "antidote", "bitter_drops", "dropsy_powder", "honey_cake", "elder_wine"]
const BUILDING_WINDOWS: Array[String] = ["light_window_1", "light_window_2"]
## Markers each model must carry (glTF empties -> Node3D leaves); every other model carries none.
const MARKERS := {
	"ph_bld_v_church": ["door_outside", "light_door", "light_window_1", "light_window_2", "light_window_3", "light_window_4"],
	"ph_bld_v_office": ["door_outside", "light_window_1", "light_window_2"],
	"ph_bld_v_inn": ["door_outside", "light_window_1", "light_window_2", "light_lantern", "label_board"],
	"ph_bld_v_smithy": ["door_outside", "counter", "anvil", "light_ember", "smoke"],
	"ph_bld_v_shop": ["door_outside", "counter", "light_window_1"],
	"ph_bld_v_surgery": ["door_outside", "light_window_1", "light_window_2"],
	"ph_bld_v_remise": ["door_outside"],
	"ph_bld_v_cottage_a": ["door_outside", "light_window", "ribbon"],
	"ph_bld_v_cottage_b": ["door_outside", "light_window", "ribbon"],
	"ph_bld_v_house_a": ["door_outside", "light_window", "ribbon"],
	"ph_bld_v_house_b": ["door_outside", "light_window", "ribbon"],
	"ph_bld_v_house_c": ["door_outside", "light_window", "ribbon"],
	"ph_bld_v_inn2": ["door_outside", "light_window", "ribbon", "label_board"],
	"ph_prop_v_sign": ["label_board"],
	"ph_prop_milestone": ["label_board"],
	"ph_int_inn_room": ["door_inside", "spawn_inside", "light_window_1", "light_window_2", "light_window_3", "light_lantern"],
	"ph_int_inn_bar": ["bar"],
	"ph_int_inn_table": ["seat_1", "seat_2"],
	"ph_int_inn_stove": ["light_stove"],
	"ph_int_surgery_room": ["door_inside", "spawn_inside", "light_window_1", "light_lamp"],
	"ph_int_surgery_lectern": ["jar_spot"],
	"ph_int_surgery_bench": ["seat_1", "seat_2", "seat_3"],
	"ph_int_office_room": ["door_inside", "spawn_inside", "light_window_1"],
	"ph_int_office_desk": ["light_candle"],
	"ph_int_pult": ["use", "cold"],
	"ph_int_collection_shelf": ["slot_1", "slot_2", "slot_3", "slot_4", "slot_5", "slot_6", "slot_7", "use"],
}
## Lantern glass / candle flame / lamp chimney (mat_emissive_warm, like the hut's lantern).
const MAY_GLOW: Array[String] = ["ph_bld_v_church", "ph_bld_v_inn", "ph_int_inn_room", "ph_int_surgery_room",
		"ph_int_office_desk"]
## §4.2: centre (x, z) and the door / counter points of the village plan (region-local).
const PLAN := {
	"ph_bld_v_church": [Vector2(0, -18), Vector2(0, -11.9)],
	"ph_bld_v_office": [Vector2(-15, -14), Vector2(-15, -10.4)],
	"ph_bld_v_inn": [Vector2(15, -14), Vector2(15, -10.4)],
	"ph_bld_v_surgery": [Vector2(19, -2), Vector2(15.4, -2)],
	"ph_bld_v_cottage_a": [Vector2(-6, 13.5), Vector2(-6, 11)],
	"ph_bld_v_cottage_b": [Vector2(6, 13.5), Vector2(6, 11)],
}
const COUNTERS := {"ph_bld_v_smithy": [Vector2(-20, -2), Vector2(-16.8, -2)], "ph_bld_v_shop": [Vector2(-18, 7), Vector2(-14.3, 7)]}
const HEIGHT_LIMIT := {"ph_bld_v_church": 17.0, "ph_bld_v_office": 8.5, "ph_bld_v_inn": 8.5, "ph_bld_v_smithy": 6.5,
		"ph_bld_v_shop": 6.0, "ph_bld_v_surgery": 8.0, "ph_bld_v_remise": 5.0, "ph_bld_v_cottage_a": 5.0,
		"ph_bld_v_cottage_b": 5.0, "ph_bld_v_house_a": 7.0, "ph_bld_v_house_b": 7.0, "ph_bld_v_house_c": 7.0,
		"ph_bld_v_inn2": 7.0}

## The eight villagers on the shared rig: height range (m), animations.
const VILLAGERS := {
	"ph_chr_v_innkeeper": {"height": [1.6, 1.72], "animations": ["idle", "walk", "talk"]},
	"ph_chr_v_smith": {"height": [1.82, 1.95], "animations": ["idle", "walk", "talk", "work"]},
	"ph_chr_v_grocer": {"height": [1.58, 1.72], "animations": ["idle", "walk", "talk", "work"]},
	"ph_chr_v_priest": {"height": [1.62, 1.76], "animations": ["idle", "walk", "talk"]},
	"ph_chr_v_mayor": {"height": [1.76, 1.9], "animations": ["idle", "walk", "talk"]},
	"ph_chr_v_surgeon": {"height": [1.76, 1.95], "animations": ["idle", "walk", "talk"]},
	"ph_chr_v_washer": {"height": [1.56, 1.7], "animations": ["idle", "walk", "talk", "work"]},
	"ph_chr_v_oldwoman": {"height": [1.36, 1.5], "animations": ["idle", "walk", "talk", "sit"]},
}
const VILLAGER_TRI_MAX := 9000
const BONES: PackedStringArray = ["root", "hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r"]
const SEAT := 0.45

var _to_free: Array[Node] = []
var _rigs: Dictionary = {}


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()
	for r: Variant in _rigs.values():
		r.free_scene()
	_rigs.clear()


# --- every static model ----------------------------------------------------------------------------

func test_every_model_exists_and_loads() -> void:
	for name: String in _static_names():
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


func test_static_models_have_no_rig() -> void:
	for name: String in _static_names():
		var inst := _load_free(name)
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])


func test_all_surfaces_use_shared_materials() -> void:
	for name: String in _static_names() + VILLAGERS.keys():
		for path: String in _material_paths(name):
			assert_true(path.begins_with(MATERIAL_DIR) and path.ends_with(".tres"),
					"%s uses a shared material (got '%s')" % [name, path])


func test_triangle_budgets() -> void:
	for name: String in MODELS:
		var tris := _triangles(name)
		assert_true(tris <= int(MODELS[name][3]), "%s: %d triangles > budget %d" % [name, tris, MODELS[name][3]])
		assert_true(tris >= MIN_TRIS, "%s: only %d triangles" % [name, tris])
	for it: String in ITEMS:
		var tris := _triangles("ph_item_" + it)
		assert_true(tris <= 800 and tris >= MIN_TRIS, "ph_item_%s: %d triangles (budget 800)" % [it, tris])


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
		if name in ["ph_prop_v_ribbon", "ph_prop_corpse_poppy"]:
			continue    # hung at its marker / lies on the corpse: checked below
		var box := _aabb(_load_free(name))
		assert_true(box.position.y <= GROUND_EPS, "%s rests on the ground (bottom %f)" % [name, box.position.y])
		assert_true(box.position.y >= -MAX_SINK, "%s sinks too deep (bottom %f)" % [name, box.position.y])
	for it: String in ITEMS:
		var box := _aabb(_load_free("ph_item_" + it))
		assert_true(absf(box.position.y) <= GROUND_EPS, "ph_item_%s bottom at 0 (%f)" % [it, box.position.y])


func test_markers_present_and_only_where_expected() -> void:
	for name: String in _static_names():
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
	for name: String in _static_names() + VILLAGERS.keys():
		if name in MAY_GLOW:
			continue
		assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")
	for name: String in MAY_GLOW:
		assert_true(EMISSIVE in _material_paths(name), name + " has its lantern / candle glass")


func test_no_cold_saturated_colour() -> void:
	# ART_DIRECTION §3: saturated cold colour is for the supernatural only - the brook, the slate and the
	# surgery's north light stay blue-grey
	for name: String in _static_names() + VILLAGERS.keys():
		var worst := 0.0
		for c: Color in _colours(name):
			var s := c.linear_to_srgb()
			if s.h > 0.45 and s.h < 0.72 and s.v > 0.25:
				worst = maxf(worst, s.s)
		assert_true(worst < 0.35, "%s has a saturated cold colour (saturation %f)" % [name, worst])


func test_blender_sources_and_generators_exist() -> void:
	for name: String in _static_names() + VILLAGERS.keys():
		var src := BLEND_DIR + _category(name) + "/" + name + ".blend"
		assert_true(FileAccess.file_exists(src), "source " + src)
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")


func test_exports_are_deterministic() -> void:
	var lib := FileAccess.get_file_as_string("res://tools/blender/lib_painted.py")
	assert_true(lib.contains("def _quantize_uvs(") and lib.count("_canonical_glb(") >= 3, "lib_painted canonicalises exports")
	# rigged exports: the villagers additionally snap and sort their vertices (export jitter of the skinned mesh)
	var vil := FileAccess.get_file_as_string("res://tools/blender/asset_villagers.py")
	assert_true(vil.contains("def _stable_glb(") and vil.contains("_stable_glb(L.os.path.join"), "villagers stabilise their .glb")


# --- buildings -----------------------------------------------------------------------------------

func test_buildings_respect_the_plan_heights() -> void:
	for name: String in HEIGHT_LIMIT:
		var box := _aabb(_load_free(name))
		assert_true(box.end.y <= float(HEIGHT_LIMIT[name]) + 0.02, "%s top %.2f <= %.1f m" % [name, box.end.y, HEIGHT_LIMIT[name]])


func test_cottages_stay_low() -> void:
	# §4.2: south row only low cottages (eave <= 2.6 m, ridge <= 4.5 m) so they never hide the Anger
	for name: String in ["ph_bld_v_cottage_a", "ph_bld_v_cottage_b"]:
		var inst := _load_free(name)
		var ridge := 0.0
		for v: Vector3 in _vertices(inst):
			if absf(v.x) < 0.8:
				ridge = maxf(ridge, v.y)
		assert_true(ridge <= 4.5, "%s ridge %.2f <= 4.5 m (only the chimney stands higher)" % [name, ridge])
		var walls := 0.0
		for v: Vector3 in _vertices(inst):
			if absf(v.z) > 2.2 and absf(v.z) < 2.9 and absf(v.x) < 2.5:   # eave line front / back
				walls = maxf(walls, v.y)
		assert_true(walls <= 2.6 + 0.6, "%s eave zone stays low (%.2f)" % [name, walls])


func test_church_tower_rises_at_the_north_end() -> void:
	var inst := _load_free("ph_bld_v_church")
	var hi := Vector3(0, -INF, 0)
	for v: Vector3 in _vertices(inst):
		if v.y > hi.y:
			hi = v
	assert_true(hi.y > 15.5 and hi.y <= 17.0, "tower top %.2f" % hi.y)
	assert_true(hi.z < -2.5, "the tower stands at the north end (z %.2f)" % hi.z)


func test_doors_match_the_village_plan() -> void:
	for name: String in PLAN:
		var centre: Vector2 = PLAN[name][0]
		var door: Vector2 = PLAN[name][1]
		var m := _marker(_load_free(name), "door_outside").origin
		var world := Vector2(centre.x + m.x, centre.y + m.z)
		assert_true(world.distance_to(door) < 0.25, "%s door_outside %s at the plan door %s" % [name, world, door])
		assert_almost(m.y, 0.0, 0.01, name + " door point on the ground")


func test_counters_match_the_shop_counters() -> void:
	for name: String in COUNTERS:
		var centre: Vector2 = COUNTERS[name][0]
		var counter: Vector2 = COUNTERS[name][1]
		var m := _marker(_load_free(name), "counter").origin
		assert_true(Vector2(centre.x + m.x, centre.y + m.z).distance_to(counter) < 0.15, "%s counter at %s" % [name, counter])
	var smithy := _load_free("ph_bld_v_smithy")
	var anvil := _marker(smithy, "anvil").origin
	var counter := _marker(smithy, "counter").origin
	assert_true(anvil.distance_to(Vector3(counter.x, anvil.y, counter.z)) < 1.2 and anvil.y > 0.6, "the anvil beside the counter")
	var ember := _marker(smithy, "light_ember").origin
	var smoke := _marker(smithy, "smoke").origin
	assert_true(ember.y > 0.9 and ember.y < 1.4, "ember just above the forge coals (%.2f)" % ember.y)
	assert_true(smoke.y > 5.5 and Vector2(smoke.x, smoke.z).distance_to(Vector2(ember.x, ember.z)) < 0.4, "chimney over the forge")


func test_window_lights_sit_outside_the_panes() -> void:
	for name: String in MARKERS:
		if not name.begins_with("ph_bld_v_"):
			continue
		var inst := _load_free(name)
		var box := _aabb(inst)
		for m: String in MARKERS[name]:
			if not m.begins_with("light_window"):
				continue
			var p := _marker(inst, m).origin
			assert_true(p.y > 0.8 and p.y < box.end.y, "%s/%s at window height (%.2f)" % [name, m, p.y])


func test_ribbons_hang_at_the_houses() -> void:
	for name: String in MARKERS:
		if not "ribbon" in MARKERS[name]:
			continue
		var p := _marker(_load_free(name), "ribbon").origin
		assert_true(p.y > 1.8 and p.y < 2.6, "%s ribbon over the door (%.2f)" % [name, p.y])
	var rb := _aabb(_load_free("ph_prop_v_ribbon"))
	assert_true(rb.end.y <= 0.06 and rb.position.y < -0.3, "the ribbon hangs down from its knot (%s)" % rb)


func test_labels_face_the_reader() -> void:
	for name: String in ["ph_prop_v_sign", "ph_prop_milestone"]:
		var inst := _load_free(name)
		var p := _marker(inst, "label_board").origin
		assert_true(p.z > 0.0, "%s label on the front (+Z) face" % name)


# --- environment ---------------------------------------------------------------------------------

func test_linden_uses_the_foliage_shader() -> void:
	assert_true(FOLIAGE in _material_paths("ph_env_linden_old"), "linden crown on mat_foliage")
	var box := _aabb(_load_free("ph_env_linden_old"))
	assert_true(box.end.y <= 9.0, "linden top %.2f <= 9 m" % box.end.y)
	assert_true(box.size.x * 0.5 > 3.5 and box.size.x * 0.5 < 5.5, "crown radius ~4.5 m (%.2f)" % (box.size.x * 0.5))


func test_brook_is_flat_painted_water() -> void:
	var inst := _load_free("ph_env_brook")
	assert_eq(_material_paths("ph_env_brook"), ["res://assets/materials/mat_painted.tres"], "no new shader for the water")
	var box := _aabb(inst)
	assert_true(box.end.y < 0.5 and box.size.z > 40.0, "a long flat strip running north-south (%s)" % box)


func test_bridge_deck_rises_over_the_brook() -> void:
	var inst := _load_free("ph_prop_v_bridge")
	var mid := -INF
	var ends := -INF
	for v: Vector3 in _vertices(inst):
		if absf(v.x) < 0.3:
			mid = maxf(mid, v.y)
		elif absf(v.x) > 2.4 and absf(v.x) < 2.8:
			ends = maxf(ends, v.y)
	assert_true(mid > 0.9 and mid < 1.4, "parapet over the hump of the deck (%.2f)" % mid)
	assert_true(ends < mid - 0.2, "the deck falls towards both ends (%.2f / %.2f)" % [ends, mid])


# --- interiors -----------------------------------------------------------------------------------

func test_room_entries_face_the_camera() -> void:
	for name: String in ["ph_int_inn_room", "ph_int_surgery_room", "ph_int_office_room"]:
		var inst := _load_free(name)
		var door := _marker(inst, "door_inside").origin
		var spawn := _marker(inst, "spawn_inside").origin
		assert_true(door.z > spawn.z and spawn.z > 0.5, "%s: entry at the south, spawn inside (%s / %s)" % [name, door, spawn])
		assert_almost(spawn.y, 0.0, 0.01, name + " spawn on the floor")


func test_rooms_have_the_plan_size() -> void:
	var sizes := {"ph_int_inn_room": Vector2(8, 6), "ph_int_surgery_room": Vector2(6, 5), "ph_int_office_room": Vector2(6, 5)}
	for name: String in sizes:
		var floor_box := AABB()
		var first := true
		for v: Vector3 in _vertices(_load_free(name)):
			if absf(v.y) < 0.02:
				floor_box = AABB(v, Vector3.ZERO) if first else floor_box.expand(v)
				first = false
		var s: Vector2 = sizes[name]
		# the floor plus the wall thickness and the diorama cut band around it
		assert_true(floor_box.size.x >= s.x and floor_box.size.x <= s.x + 1.0 and floor_box.size.z >= s.y and
				floor_box.size.z <= s.y + 1.0, "%s floor %s ~ %s" % [name, floor_box.size, s])


func test_seats_and_spots() -> void:
	var bench := _load_free("ph_int_surgery_bench")
	for k: int in 3:
		assert_almost(_marker(bench, "seat_%d" % (k + 1)).origin.y, 0.0, 0.01, "bench seat %d on the floor" % (k + 1))
	var lectern := _load_free("ph_int_surgery_lectern")
	var spot := _marker(lectern, "jar_spot").origin
	assert_true(absf(spot.y - _aabb(lectern).end.y) < 0.03, "jar_spot on the lectern top")
	var bar := _marker(_load_free("ph_int_inn_bar"), "bar").origin
	assert_true(bar.z < -0.2, "Rosine stands behind the counter")


# --- anatomy: tasteful ------------------------------------------------------------------------------

func test_anatomy_has_no_red_and_no_blood() -> void:
	# §8 "Kein Gore": no red at all on the specimens, the pult, the shelf, the cabinet or the medicines
	var names: Array[String] = ["ph_int_pult", "ph_int_collection_shelf", "ph_int_surgery_cabinet", "ph_int_surgery_table",
			"ph_int_surgery_lectern"]
	for it: String in ITEMS:
		names.append("ph_item_" + it)
	for name: String in names:
		var worst := 0.0
		for c: Color in _colours(name):
			var s := c.linear_to_srgb()
			if (s.h < 0.04 or s.h > 0.94) and s.v > 0.2:
				worst = maxf(worst, s.s)
		assert_true(worst < 0.45, "%s has no red (saturation %f)" % [name, worst])


func test_eye_glass_is_almost_black() -> void:
	var inst := _load_free("ph_item_specimen_jar_eyes")
	var dark := 0
	var total := 0
	for c: Color in _colours("ph_item_specimen_jar_eyes"):
		total += 1
		if c.linear_to_srgb().v < 0.25:
			dark += 1
	assert_true(total > 0 and float(dark) / total > 0.25, "the eye glass reads dark (%d / %d)" % [dark, total])
	assert_true(_aabb(inst).size.y < _aabb(_load_free("ph_item_specimen_jar")).size.y, "smaller than the specimen jar")


func test_pult_cold_drawer_and_place() -> void:
	var inst := _load_free("ph_int_pult")
	var cold := _marker(inst, "cold").origin
	var use := _marker(inst, "use").origin
	var box := _aabb(inst)
	assert_true(cold.z >= box.end.z - 0.06 and cold.y > 0.4 and cold.y < box.end.y, "the slate drawer at the front (%s)" % cold)
	assert_true(use.z > box.end.z + 0.3 and absf(use.y) < 0.01, "the gravekeeper stands in front (%s)" % use)


func test_collection_shelf_has_seven_places() -> void:
	var inst := _load_free("ph_int_collection_shelf")
	var box := _aabb(inst)
	var seen: Array[Vector3] = []
	for k: int in 7:
		var p := _marker(inst, "slot_%d" % (k + 1)).origin
		assert_true(box.has_point(p + Vector3(0, 0.01, 0)), "slot_%d inside the shelf %s" % [k + 1, p])
		for q: Vector3 in seen:
			assert_true(q.distance_to(p) > 0.2, "slot_%d apart from the others" % (k + 1))
		seen.append(p)


func test_items_are_icon_sized() -> void:
	for it: String in ITEMS:
		var box := _aabb(_load_free("ph_item_" + it))
		for axis: int in 3:
			assert_true(box.size[axis] >= ITEM_MIN[axis] and box.size[axis] <= ITEM_MAX[axis],
					"ph_item_%s size %s (axis %d)" % [it, box.size, axis])


func test_poppy_rests_on_the_bodice_of_look_1() -> void:
	var corpse := _aabb(_load_free("ph_prop_corpse_02"))
	var posy := _aabb(_load_free("ph_prop_corpse_poppy"))
	assert_true(posy.position.y > 0.18 and posy.position.y < 0.3, "on the chest, not in the air (%.3f)" % posy.position.y)
	assert_true(posy.get_center().x > 0.1 and posy.get_center().x < corpse.end.x - 0.3, "on the upper body (head at +X)")
	assert_true(absf(posy.get_center().z) < 0.15, "on the middle of the body")


# --- villagers on the shared rig ------------------------------------------------------------------

func test_villagers_share_the_eight_bone_rig() -> void:
	for c: String in VILLAGERS:
		var r := _rig(c)
		assert_not_null(r.skeleton, c + ": skeleton")
		assert_not_null(r.player, c + ": AnimationPlayer")
		if r.skeleton == null:
			continue
		assert_eq(r.skeleton.get_bone_count(), BONES.size(), c + ": 8 bones")
		for b: String in BONES:
			assert_true(r.skeleton.find_bone(b) >= 0, "%s: bone %s" % [c, b])
		assert_true(r.rigid_ok, c + ": rigid skinning")


func test_villager_budget_height_and_front() -> void:
	for c: String in VILLAGERS:
		var r := _rig(c)
		var tris := 0
		var mesh := r.mesh_instance.mesh
		for s: int in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_true(tris <= VILLAGER_TRI_MAX and tris >= 2500, "%s: %d tris (<= %d)" % [c, tris, VILLAGER_TRI_MAX])
		var box := AABB(r.verts[0], Vector3.ZERO)
		for v: Vector3 in r.verts:
			box = box.expand(v)
		var lim: Array = VILLAGERS[c].height
		assert_true(box.end.y >= lim[0] and box.end.y <= lim[1], "%s: height %.2f in %s" % [c, box.end.y, lim])
		assert_true(absf(box.position.y) < 0.01, c + ": feet on the ground")
		for leg: String in ["leg_l", "leg_r"]:
			var front := -INF
			var back := INF
			for p: Vector3 in r.boot(null, leg, 0.0):
				front = maxf(front, p.z)
				back = minf(back, p.z)
			assert_true(front > -back + 0.03, "%s: %s toes point to +Z" % [c, leg])


func test_villager_silhouettes_differ() -> void:
	# §8: own silhouette per figure - compare height, width and the head-gear top
	var sig := {}
	for c: String in VILLAGERS:
		var r := _rig(c)
		var box := AABB(r.verts[0], Vector3.ZERO)
		for v: Vector3 in r.verts:
			box = box.expand(v)
		var head := r.posed(null, "head", 0.0)
		var hb := AABB(head[0], Vector3.ZERO)
		for p: Vector3 in head:
			hb = hb.expand(p)
		sig[c] = Vector3(box.size.y, box.size.x, hb.size.x)
	var keys: Array = sig.keys()
	for i: int in keys.size():
		for j: int in range(i + 1, keys.size()):
			var a: Vector3 = sig[keys[i]]
			var b: Vector3 = sig[keys[j]]
			assert_true(absf(a.x - b.x) > 0.025 or absf(a.y - b.y) > 0.05 or absf(a.z - b.z) > 0.03,
					"%s and %s differ in silhouette (%s / %s)" % [keys[i], keys[j], a, b])


func test_villager_animations() -> void:
	for c: String in VILLAGERS:
		var r := _rig(c)
		var names: Array = []
		for n: StringName in r.player.get_animation_list():
			names.append(String(n))
			assert_false(String(n).ends_with("loop"), "%s: -loop suffix stripped (%s)" % [c, n])
		names.sort()
		var expected: Array = (VILLAGERS[c].animations as Array).duplicate()
		expected.sort()
		assert_eq(names, expected, c + ": animation set")
		for a: String in expected:
			var anim := r.animation(a)
			if anim == null:
				continue
			assert_ne(anim.loop_mode, Animation.LOOP_NONE, "%s/%s loops" % [c, a])
			assert_true(anim.length > 0.4 and anim.length < 3.2, "%s/%s length %.2f" % [c, a, anim.length])
			var root := r.skeleton.find_bone("root")
			for k: int in 5:
				var t := anim.length * k / 4.0
				assert_true(r.local_pose(anim, root, t).is_equal_approx(r.skeleton.get_bone_rest(root)), "%s/%s root at rest" % [c, a])
			for b: String in BONES:
				var bi := r.skeleton.find_bone(b)
				var p0 := r.local_pose(anim, bi, 0.0)
				var p1 := r.local_pose(anim, bi, anim.length)
				assert_true(p0.origin.distance_to(p1.origin) < 0.002 and
						p0.basis.get_rotation_quaternion().angle_to(p1.basis.get_rotation_quaternion()) < 0.01,
						"%s/%s seamless (%s)" % [c, a, b])


func test_villagers_walk_and_talk() -> void:
	for c: String in VILLAGERS:
		var r := _rig(c)
		var walk := r.animation(&"walk")
		var a := r.centroid(r.boot(walk, "leg_l", walk.length * 0.25))
		var b := r.centroid(r.boot(walk, "leg_l", walk.length * 0.75))
		assert_true(absf(a.z - b.z) > 0.08, "%s: the left foot swings in the walk (%.3f)" % [c, absf(a.z - b.z)])
		var talk := r.animation(&"talk")
		var moved := 0.0
		for arm: String in ["arm_l", "arm_r"]:
			var h0 := r.hand(talk, arm, 0.0)
			for k: int in 4:
				moved = maxf(moved, r.hand(talk, arm, talk.length * (k + 1) / 5.0).distance_to(h0))
		assert_true(moved > 0.05, "%s: a hand gestures while talking (%.3f)" % [c, moved])


func test_hagedorn_sits_on_a_bench() -> void:
	var r := _rig("ph_chr_v_oldwoman")
	var sit := r.animation(&"sit")
	var hips := r.posed(sit, "hips", sit.length * 0.3)
	var rest := r.posed(null, "hips", 0.0)
	var drop := r.centroid(rest).y - r.centroid(hips).y
	assert_true(drop > 0.18 and drop < 0.4, "hips lowered onto the seat (%.2f m)" % drop)
	for leg: String in ["leg_l", "leg_r"]:
		var foot := r.lowest_y(r.boot(sit, leg, sit.length * 0.3))
		assert_true(foot > -0.05 and foot < 0.12, "%s planted in front of the bench (%.3f)" % [leg, foot])
		assert_true(r.centroid(r.boot(sit, leg, sit.length * 0.3)).z > 0.25, "%s stretched forward" % leg)


func test_work_animations_use_the_hands() -> void:
	for c: String in ["ph_chr_v_smith", "ph_chr_v_grocer", "ph_chr_v_washer"]:
		var r := _rig(c)
		var work := r.animation(&"work")
		var lo := INF
		var hi := -INF
		for k: int in 9:
			var h := r.hand(work, "arm_r", work.length * k / 8.0)
			lo = minf(lo, h.y)
			hi = maxf(hi, h.y)
		assert_true(hi - lo > 0.05, "%s: the right hand works (%.3f)" % [c, hi - lo])
	var smith := _rig("ph_chr_v_smith")
	var w := smith.animation(&"work")
	assert_true(smith.hand(w, "arm_r", 0.0).y > 1.6, "the hammer is raised over the head before the strike")


# --- helpers -------------------------------------------------------------------------------------

func _static_names() -> Array[String]:
	var out: Array[String] = []
	for n: String in MODELS:
		out.append(n)
	for it: String in ITEMS:
		out.append("ph_item_" + it)
	return out


func _category(name: String) -> String:
	if MODELS.has(name):
		return String(MODELS[name][0])
	if name.begins_with("ph_item_"):
		return "items"
	if name.begins_with("ph_chr_"):
		return "characters"
	return "props"


func _path(name: String) -> String:
	return MODEL_DIR + _category(name) + "/" + name + ".glb"


func _rig(char_name: String) -> Chars.Rig:
	if not _rigs.has(char_name):
		_rigs[char_name] = Chars.Rig.new(MODEL_DIR + "characters/" + char_name + ".glb")
	return _rigs[char_name]


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
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _aabb(inst: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in _meshes(inst):
		var b := _xf(mi, inst) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _marker(inst: Node3D, marker_name: String) -> Transform3D:
	var m := inst.find_child(marker_name, true, false) as Node3D
	assert_not_null(m, "marker " + marker_name)
	return _xf(m, inst) if m != null else Transform3D.IDENTITY


func _material_paths(name: String) -> Array[String]:
	var paths: Array[String] = []
	var inst := _load_free(name) if not VILLAGERS.has(name) else _rig(name).scene as Node3D
	for mi: MeshInstance3D in _meshes(inst):
		for s: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			var p := mat.resource_path if mat != null else "<none>"
			if not p in paths:
				paths.append(p)
	return paths


func _triangles(name: String) -> int:
	var tris := 0
	for mi: MeshInstance3D in _meshes(_load_free(name)):
		for s: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func _vertices(inst: Node3D) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * v)
	return out


func _colours(name: String) -> PackedColorArray:
	var out: PackedColorArray = []
	var inst := _load_free(name) if not VILLAGERS.has(name) else _rig(name).scene as Node3D
	for mi: MeshInstance3D in _meshes(inst):
		for s: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			if arrays[Mesh.ARRAY_COLOR] != null:
				out.append_array(arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
	return out
