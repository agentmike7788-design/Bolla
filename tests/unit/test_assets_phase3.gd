extends TestCase
## Phase 3 assets (P5, docs/PHASE3_DESIGN.md §8): decor, obstacles, tending spots, birch, ghost,
## notice board, item models. Files exist, triangle budgets, sizes, pivots, markers, shared materials.
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front).

const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const PAINTED := "res://assets/materials/mat_painted.tres"
const FOLIAGE := "res://assets/materials/mat_foliage.tres"
const GRASS := "res://assets/materials/mat_grass.tres"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const MIN_TRIS := 100
const MAX_SINK := 0.35
const GROUND_EPS := 0.01
const CENTRE_EPS := 0.06
const GENERATORS: Array[String] = ["asset_props_phase3", "asset_env_phase3", "asset_ghost", "asset_items"]

## name -> [category, min size, max size, footprint centred on the pivot, triangle budget (§8)]
const MODELS := {
	"ph_deco_bench_wood": ["decor", Vector3(1.3, 0.4, 0.38), Vector3(1.5, 0.52, 0.5), true, 1200],
	"ph_deco_bench_stone": ["decor", Vector3(1.3, 0.4, 0.38), Vector3(1.5, 0.52, 0.5), true, 1200],
	"ph_deco_flowerbed": ["decor", Vector3(0.95, 0.15, 0.95), Vector3(1.1, 0.4, 1.1), true, 1500],
	"ph_deco_grave_vase": ["decor", Vector3(0.12, 0.25, 0.12), Vector3(0.3, 0.5, 0.3), true, 500],
	"ph_deco_lantern_small": ["decor", Vector3(0.12, 0.85, 0.12), Vector3(0.3, 1.0, 0.3), true, 600],
	"ph_deco_path_gravel": ["decor", Vector3(0.45, 0.005, 0.45), Vector3(0.5, 0.02, 0.5), true, 150],
	"ph_deco_path_gravel_02": ["decor", Vector3(0.45, 0.005, 0.45), Vector3(0.5, 0.02, 0.5), true, 150],
	"ph_prop_fence_iron_broken": ["props", Vector3(1.95, 1.0, 0.3), Vector3(2.1, 1.3, 1.3), false, 1200],
	"ph_prop_fence_passage": ["props", Vector3(2.3, 1.8, 0.3), Vector3(2.6, 2.3, 0.6), false, 800],
	"ph_prop_rubble_large": ["props", Vector3(1.3, 0.5, 1.2), Vector3(2.0, 1.0, 1.8), true, 1200],
	"ph_prop_notice_board": ["props", Vector3(1.2, 1.8, 0.3), Vector3(1.7, 2.2, 0.7), true, 800],
	"ph_env_bramble": ["environment", Vector3(1.7, 1.0, 1.7), Vector3(2.2, 1.4, 2.2), true, 2500],
	"ph_env_stump": ["environment", Vector3(0.7, 0.4, 0.7), Vector3(1.7, 0.9, 1.7), true, 1200],
	"ph_env_hedge_thorn": ["environment", Vector3(3.8, 1.4, 0.8), Vector3(4.25, 1.7, 1.2), true, 3000],
	"ph_env_weeds_1": ["environment", Vector3(0.4, 0.05, 0.4), Vector3(1.0, 0.15, 1.0), true, 300],
	"ph_env_weeds_2": ["environment", Vector3(0.6, 0.15, 0.6), Vector3(1.1, 0.35, 1.1), true, 500],
	"ph_env_weeds_3": ["environment", Vector3(0.6, 0.45, 0.6), Vector3(1.2, 0.9, 1.2), true, 800],
	"ph_env_leaves_1": ["environment", Vector3(0.6, 0.0, 0.6), Vector3(1.6, 0.12, 1.6), true, 200],
	"ph_env_leaves_2": ["environment", Vector3(0.6, 0.0, 0.6), Vector3(1.6, 0.12, 1.6), true, 350],
	"ph_env_leaves_3": ["environment", Vector3(0.6, 0.0, 0.6), Vector3(1.6, 0.12, 1.6), true, 500],
	"ph_env_birch": ["environment", Vector3(1.5, 6.5, 1.5), Vector3(3.5, 8.5, 3.5), false, 5000],
	"ph_chr_ghost": ["characters", Vector3(0.5, 1.4, 0.5), Vector3(0.9, 1.8, 0.95), false, 3000],
	"ph_item_rake": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, 800],
	"ph_item_seeds": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, 800],
	"ph_item_iron_fittings": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, 800],
}
## Markers each model must carry (glTF empties -> Node3D); every other model carries none.
const MARKERS := {
	"ph_deco_lantern_small": ["light_lantern"],
	"ph_prop_notice_board": ["label_board"],
	"ph_chr_ghost": ["light_soul"],
}
## Wind-swayed leaf masses (§8 "Laub-Shader") and grass-lit weeds.
const FOLIAGE_MODELS: Array[String] = ["ph_env_bramble", "ph_env_hedge_thorn", "ph_env_birch"]
const WEEDS: Array[String] = ["ph_env_weeds_1", "ph_env_weeds_2", "ph_env_weeds_3"]
const LEAVES: Array[String] = ["ph_env_leaves_1", "ph_env_leaves_2", "ph_env_leaves_3"]

var _to_free: Array[Node] = []


# --- every model -------------------------------------------------------------------

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


func test_models_are_static_and_rigid() -> void:
	# The ghost too: no rig, it moves by code and shader (§8).
	for name: String in MODELS:
		var inst := _load(name)
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])
		inst.free()


func test_all_surfaces_use_shared_materials() -> void:
	for name: String in MODELS:
		for path: String in _material_paths(name):
			assert_true(path.begins_with(MATERIAL_DIR) and path.ends_with(".tres"),
					"%s uses a shared material (got '%s')" % [name, path])


func test_triangle_budgets() -> void:
	for name: String in MODELS:
		var tris := _triangles(name)
		var budget: int = MODELS[name][4]
		assert_true(tris <= budget, "%s: %d triangles > budget %d" % [name, tris, budget])
		assert_true(tris >= MIN_TRIS, "%s: only %d triangles" % [name, tris])


func test_bounding_box_sizes() -> void:
	for name: String in MODELS:
		var inst := _load(name)
		var box := _aabb(inst)
		var lo: Vector3 = MODELS[name][1]
		var hi: Vector3 = MODELS[name][2]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis],
					"%s size %s outside %s..%s (axis %d)" % [name, box.size, lo, hi, axis])
		inst.free()


func test_pivot_bottom_centre() -> void:
	for name: String in MODELS:
		var inst := _load(name)
		var box := _aabb(inst)
		assert_true(box.position.y <= GROUND_EPS, "%s rests on the ground (bottom %f)" % [name, box.position.y])
		assert_true(box.position.y >= -MAX_SINK, "%s sinks too deep (bottom %f)" % [name, box.position.y])
		if MODELS[name][3]:
			var c := box.get_center()
			assert_true(absf(c.x) <= CENTRE_EPS and absf(c.z) <= CENTRE_EPS,
					"%s footprint centred on the pivot (centre %s)" % [name, c])
		inst.free()


func test_markers_present_and_only_where_expected() -> void:
	for name: String in MODELS:
		var inst := _load(name)
		var found: Array[String] = []
		for n: Node in inst.find_children("*", "Node3D", true, false):
			if not n is MeshInstance3D and n.get_child_count() == 0 and _meshes(n).is_empty():
				found.append(String(n.name))
		var expected: Array = MARKERS.get(name, [])
		for m: String in expected:
			assert_has(found, m, "%s has marker %s" % [name, m])
		assert_eq(found.size(), expected.size(), "%s markers %s" % [name, found])
		inst.free()


func test_only_the_lantern_glows() -> void:
	assert_has(_material_paths("ph_deco_lantern_small"), EMISSIVE, "lantern glass uses mat_emissive_warm")
	for name: String in MODELS:
		if name != "ph_deco_lantern_small":
			assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")


func test_leaf_masses_use_the_foliage_shader_and_weeds_the_grass_shader() -> void:
	for name: String in FOLIAGE_MODELS:
		assert_has(_material_paths(name), FOLIAGE, name + " leaves use mat_foliage (wind)")
	for name: String in WEEDS:
		assert_has(_material_paths(name), GRASS, name + " blades use mat_grass")


func test_no_cold_saturated_colour_outside_the_ghost() -> void:
	# ART_DIRECTION §3: the supernatural is the only source of saturated cold colour
	# (§8 flower bed: amber / pale violet / white, no cold saturated blue).
	for name: String in MODELS:
		if name == "ph_chr_ghost":
			continue
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


# --- decor ---------------------------------------------------------------------------

func test_lantern_light_sits_in_the_glass() -> void:
	var inst := _load("ph_deco_lantern_small")
	var box := _aabb(inst)
	var light := _marker(inst, "light_lantern")
	assert_true(light.origin.y > 0.65 and light.origin.y < 0.85, "light at lantern height (%f)" % light.origin.y)
	assert_true(absf(light.origin.x) < 0.06 and absf(light.origin.z) < 0.06, "light above the stake %s" % light.origin)
	assert_true(light.origin.y < box.end.y - 0.1, "light below the roof")
	inst.free()


func test_benches_are_seat_high_and_long_along_x() -> void:
	for name: String in ["ph_deco_bench_wood", "ph_deco_bench_stone"]:
		var s := _size(name)
		assert_almost(s.y, 0.45, 0.04, name + " seat at ~0.45 m")
		assert_true(s.x > s.z * 2.5, name + " lies along X (3 x 1 cells)")


func test_gravel_tiles_are_flush_and_differ() -> void:
	for name: String in ["ph_deco_path_gravel", "ph_deco_path_gravel_02"]:
		var box := _aabb(_load_free(name))
		assert_true(box.end.y <= 0.02, "%s is flush (%f m high)" % [name, box.end.y])
	var a := _vertices_of("ph_deco_path_gravel")
	var b := _vertices_of("ph_deco_path_gravel_02")
	assert_true(a != b, "two different gravel variants")


# --- props ---------------------------------------------------------------------------

func test_broken_fence_matches_the_fence_segment() -> void:
	var fence := _aabb(_load_free_at("props", "ph_prop_fence_iron"))
	var broken := _aabb(_load_free("ph_prop_fence_iron_broken"))
	assert_almost(broken.position.x, fence.position.x, 0.03, "starts where the fence segment starts (x = 0)")
	assert_almost(broken.end.x, fence.end.x, 0.05, "same length as ph_prop_fence_iron")
	assert_almost(broken.size.y, fence.size.y, 0.1, "same height as ph_prop_fence_iron")
	assert_true(_triangles("ph_prop_fence_iron_broken") < _triangles_of_file("props", "ph_prop_fence_iron") * 3,
			"no heavier than needed")


func test_fence_passage_runs_along_x_from_zero() -> void:
	var box := _aabb(_load_free("ph_prop_fence_passage"))
	assert_true(box.position.x > -0.1 and box.position.x < 0.05, "starts at x = 0 like a fence piece (%f)" % box.position.x)
	assert_true(box.size.x > box.size.z * 4.0, "a passage in a fence line (along X)")
	assert_true(box.size.y > 1.8, "the arch is high enough to walk through (%f)" % box.size.y)


func test_notice_board_label_on_the_front_face() -> void:
	var inst := _load("ph_prop_notice_board")
	var label := _marker(inst, "label_board")
	assert_true(label.origin.y > 1.0 and label.origin.y < 1.6, "label at board height (%f)" % label.origin.y)
	assert_true(absf(label.origin.x) < 0.05, "label centred on the board")
	assert_true(label.origin.z > 0.0, "label on the front face (+Z)")
	inst.free()


# --- tending spots -------------------------------------------------------------------

func test_weed_stages_grow_and_stage_3_is_clearly_readable() -> void:
	var heights: Array[float] = []
	for name: String in WEEDS:
		heights.append(_size(name).y)
	assert_true(heights[0] < heights[1] and heights[1] < heights[2], "stages grow taller %s" % [heights])
	assert_true(heights[2] >= 0.5, "stage 3 thistles stand out (%f m)" % heights[2])
	assert_true(_triangles(WEEDS[2]) > _triangles(WEEDS[1]) * 2, "stage 3 is much denser")


func test_leaf_litter_amounts_grow_and_stay_flat() -> void:
	var tris: Array[int] = []
	for name: String in LEAVES:
		tris.append(_triangles(name))
		assert_true(_size(name).y <= 0.12, name + " lies flat")
	assert_true(tris[0] < tris[1] and tris[1] < tris[2], "more leaves per level %s" % [tris])


# --- ghost ---------------------------------------------------------------------------

func test_ghost_pivot_is_the_hem_centre() -> void:
	var inst := _load("ph_chr_ghost")
	var box := _aabb(inst)
	assert_true(absf(box.position.y) <= GROUND_EPS, "hem tips at y = 0 (%f)" % box.position.y)
	var hem := Vector3.ZERO
	var n := 0
	for p: Vector3 in _vertices(inst):
		if p.y < 0.12:
			hem += p
			n += 1
	assert_true(n > 10, "hem vertices found")
	hem /= maxf(1.0, float(n))
	assert_true(absf(hem.x) < 0.05 and absf(hem.z) < 0.05, "pivot at the hem centre (%s)" % hem)
	inst.free()


func test_ghost_holds_the_soul_light_in_front() -> void:
	var inst := _load("ph_chr_ghost")
	var light := _marker(inst, "light_soul")
	assert_true(light.origin.z > 0.25, "soul light in front of the body (+Z, %s)" % light.origin)
	assert_true(light.origin.y > 0.8 and light.origin.y < 1.2, "held at chest height (%f)" % light.origin.y)
	var orb := inst.find_child("soul_orb", true, false) as MeshInstance3D
	assert_not_null(orb, "soul_orb is its own mesh node (own material possible)")
	if orb != null:
		var c := _xf(orb, inst) * orb.get_aabb().get_center()
		assert_true(c.distance_to(light.origin) < 0.03, "light_soul inside the orb")
		var mean := Vector3.ZERO
		var cols: PackedColorArray = orb.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		for col: Color in cols:
			mean += Vector3(col.r, col.g, col.b)
		mean /= maxf(1.0, float(cols.size()))
		assert_true(mean.y > mean.x * 1.5 and mean.z > mean.x * 1.5, "orb is ghost turquoise (%s)" % mean)
	inst.free()


func test_ghost_is_shader_ready_hem_fades_in_vertex_alpha() -> void:
	var inst := _load("ph_chr_ghost")
	var body := inst.find_child("ph_chr_ghost", true, false) as MeshInstance3D
	if body == null:
		body = _meshes(inst)[0]
	var arrays := body.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(cols.size(), verts.size(), "vertex colours present")
	var xf := _xf(body, inst)
	var low := 1.0
	var high := 1.0
	for i: int in verts.size():
		var y := (xf * verts[i]).y
		if y < 0.02:
			low = minf(low, cols[i].a)
		elif y > 0.7:
			high = minf(high, cols[i].a)
	assert_true(low < 0.1, "hem tips fade out (alpha %f)" % low)
	assert_almost(high, 1.0, 0.01, "body above 0.7 m is opaque")
	inst.free()


# --- helpers -------------------------------------------------------------------------

func _path(name: String) -> String:
	return MODEL_DIR + String(MODELS[name][0]) + "/" + name + ".glb"


func _load(name: String) -> Node3D:
	return (load(_path(name)) as PackedScene).instantiate() as Node3D


## Instance that after_each() frees (for one-line measurements such as _aabb(_load_free(name))).
func _load_free(name: String) -> Node3D:
	var inst := _load(name)
	_to_free.append(inst)
	return inst


func _load_free_at(category: String, name: String) -> Node3D:
	var inst := (load(MODEL_DIR + category + "/" + name + ".glb") as PackedScene).instantiate() as Node3D
	_to_free.append(inst)
	return inst


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()


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


func _size(name: String) -> Vector3:
	var inst := _load(name)
	var s := _aabb(inst).size
	inst.free()
	return s


func _marker(inst: Node3D, marker_name: String) -> Transform3D:
	var n := inst.find_child(marker_name, true, false) as Node3D
	assert_not_null(n, "marker " + marker_name)
	return _xf(n, inst) if n != null else Transform3D.IDENTITY


func _material_paths(name: String) -> Array[String]:
	var out: Array[String] = []
	var inst := _load(name)
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			out.append(mat.resource_path if mat != null else "")
	inst.free()
	return out


func _triangles(name: String) -> int:
	return _triangles_of_file(String(MODELS[name][0]), name)


func _triangles_of_file(category: String, name: String) -> int:
	var inst := (load(MODEL_DIR + category + "/" + name + ".glb") as PackedScene).instantiate() as Node3D
	var tris := 0
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += idx.size() / 3 if idx.size() > 0 else verts.size() / 3
	inst.free()
	return tris


func _vertices(inst: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for i: int in mi.mesh.get_surface_count():
			for p: Vector3 in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(xf * p)
	return out


func _vertices_of(name: String) -> PackedVector3Array:
	var inst := _load(name)
	var out := _vertices(inst)
	inst.free()
	return out


func _colours(name: String) -> PackedColorArray:
	var out := PackedColorArray()
	var inst := _load(name)
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			out.append_array(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] as PackedColorArray)
	inst.free()
	return out
