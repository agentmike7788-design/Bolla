extends TestCase
## M6b: vertical-slice props, bush and item models (contract §8, docs/ASSET_GUIDELINES.md).
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front).

const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const FOLIAGE := "res://assets/materials/mat_foliage.tres"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
## Triangle budgets from docs/ASSET_GUIDELINES.md.
const BUDGET_PROP := 1500   # "Kleines Prop / Grabstein"
const BUDGET_TREE := 6000   # "Baum" (the fallen trunk with its root plate)
const MIN_TRIS := 100
## A model may sink into the ground a little (roots, stones), but never float.
const MAX_SINK := 0.35
const GROUND_EPS := 0.01
const CENTRE_EPS := 0.06

## name -> [category, min size, max size, footprint centred on the pivot, triangle budget]
const MODELS := {
	"ph_prop_corpse": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, BUDGET_PROP],
	"ph_prop_corpse_02": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, BUDGET_PROP],
	"ph_prop_corpse_03": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, BUDGET_PROP],
	"ph_prop_corpse_04": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, BUDGET_PROP],
	"ph_prop_corpse_shrouded": ["props", Vector3(1.6, 0.18, 0.4), Vector3(1.8, 0.35, 0.7), true, BUDGET_PROP],
	"ph_prop_handcart": ["props", Vector3(1.0, 0.8, 2.0), Vector3(1.45, 1.05, 2.45), false, BUDGET_PROP],
	"ph_prop_morgue_table": ["props", Vector3(1.9, 0.83, 0.75), Vector3(2.15, 0.92, 0.9), true, BUDGET_PROP],
	"ph_prop_workbench": ["props", Vector3(1.75, 0.85, 0.65), Vector3(1.95, 1.05, 1.0), true, BUDGET_PROP],
	"ph_prop_dropoff_bier": ["props", Vector3(1.9, 0.45, 0.65), Vector3(2.15, 0.6, 0.85), true, BUDGET_PROP],
	"ph_prop_grave_plot_empty": ["props", Vector3(1.0, 0.28, 2.0), Vector3(1.45, 0.45, 2.5), true, BUDGET_PROP],
	"ph_prop_grave_pit": ["props", Vector3(1.9, 1.0, 2.1), Vector3(2.6, 1.7, 2.6), false, BUDGET_PROP],
	"ph_prop_wood_pile": ["props", Vector3(1.15, 0.75, 0.5), Vector3(1.45, 0.95, 1.0), false, BUDGET_PROP],
	"ph_prop_stone_rubble": ["props", Vector3(0.8, 0.35, 0.8), Vector3(1.6, 0.8, 1.4), true, BUDGET_PROP],
	"ph_prop_cross_wood": ["props", Vector3(0.4, 0.95, 0.1), Vector3(0.65, 1.12, 0.3), true, BUDGET_PROP],
	"ph_prop_signpost": ["props", Vector3(0.8, 1.8, 0.2), Vector3(1.15, 2.2, 0.5), false, BUDGET_PROP],
	"ph_prop_fallen_log": ["props", Vector3(5.5, 1.0, 1.4), Vector3(7.2, 2.2, 2.5), false, BUDGET_TREE],
	"ph_env_bush": ["environment", Vector3(1.0, 0.6, 0.8), Vector3(1.4, 1.0, 1.3), true, BUDGET_PROP],
	"ph_item_log": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, BUDGET_PROP],
	"ph_item_stone": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, BUDGET_PROP],
	"ph_item_linen": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, BUDGET_PROP],
	"ph_item_coin": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, BUDGET_PROP],
	"ph_item_shroud": ["items", Vector3(0.1, 0.04, 0.1), Vector3(0.45, 0.3, 0.45), true, BUDGET_PROP],
}
## Plain corpse looks (Corpse.plain_variants order); variant 0 keeps the original name.
const CORPSE_VARIANTS: Array[String] = ["ph_prop_corpse", "ph_prop_corpse_02", "ph_prop_corpse_03", "ph_prop_corpse_04"]
## Markers each model must carry (glTF empties -> Node3D); every other model carries none.
const MARKERS := {
	"ph_prop_morgue_table": ["slot_corpse"],
	"ph_prop_dropoff_bier": ["slot_corpse"],
	"ph_prop_handcart": ["slot_corpse"],
	"ph_prop_signpost": ["label_board"],
}


# --- tests -----------------------------------------------------------------------

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


func test_models_are_static_props() -> void:
	for name: String in MODELS:
		var inst := _load(name)
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])
		inst.free()


func test_all_surfaces_use_shared_materials() -> void:
	for name: String in MODELS:
		var inst := _load(name)
		for mi: MeshInstance3D in _meshes(inst):
			assert_true(mi.mesh.get_surface_count() >= 1, name + " has surfaces")
			for i: int in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(i)
				assert_not_null(mat, "%s surface %d has a material" % [name, i])
				if mat != null:
					assert_true(mat.resource_path.begins_with(MATERIAL_DIR) and mat.resource_path.ends_with(".tres"),
							"%s surface %d uses shared material (got '%s')" % [name, i, mat.resource_path])
		inst.free()


func test_bush_uses_foliage_and_nothing_glows() -> void:
	assert_has(_material_paths("ph_env_bush"), FOLIAGE, "bush leaves use mat_foliage")
	for name: String in MODELS:
		# none of the slice props is a light source; the coins are dull gold, not emissive
		assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")


func test_triangle_budgets() -> void:
	for name: String in MODELS:
		var tris := _triangles(_load_and_free_meshes(name))
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


func test_slot_corpse_on_morgue_table() -> void:
	var inst := _load("ph_prop_morgue_table")
	var slot := _marker(inst, "slot_corpse")
	assert_almost(slot.origin.x, 0.0, 0.05, "slot centred (x)")
	assert_almost(slot.origin.z, 0.0, 0.05, "slot centred (z)")
	assert_almost(slot.origin.y, 0.85, 0.03, "slot on the table top (0.85 m)")
	assert_true(slot.origin.y >= _aabb(inst).end.y - 0.03, "slot is on top, not inside the table")
	assert_true(slot.basis.x.normalized().is_equal_approx(Vector3.RIGHT), "corpse lies along the table (X)")
	inst.free()


func test_slot_corpse_on_dropoff_bier() -> void:
	var inst := _load("ph_prop_dropoff_bier")
	var slot := _marker(inst, "slot_corpse")
	assert_almost(slot.origin.x, 0.0, 0.05, "slot centred (x)")
	assert_almost(slot.origin.z, 0.0, 0.05, "slot centred (z)")
	assert_almost(slot.origin.y, 0.5, 0.05, "slot on the bier (0.5 m)")
	assert_true(slot.origin.y >= _aabb(inst).end.y - 0.03, "slot is on top of the slats")
	assert_true(slot.basis.x.normalized().is_equal_approx(Vector3.RIGHT), "corpse lies along the bier (X)")
	inst.free()


func test_slot_corpse_on_handcart_follows_the_bed() -> void:
	var inst := _load("ph_prop_handcart")
	var slot := _marker(inst, "slot_corpse")
	var box := _aabb(inst)
	assert_almost(slot.origin.x, 0.0, 0.05, "slot centred across the bed")
	assert_true(slot.origin.y > 0.5 and slot.origin.y < 0.8, "slot on the bed (%f)" % slot.origin.y)
	assert_true(slot.origin.z > box.position.z and slot.origin.z < box.end.z, "slot within the cart")
	assert_almost(absf(slot.basis.x.normalized().z), 1.0, 0.01, "corpse lies along the cart (Z)")
	inst.free()


func test_handcart_handles_point_to_the_front() -> void:
	# Blender -Y = Godot +Z: the handles stick out further on the +Z side, at hand height.
	var inst := _load("ph_prop_handcart")
	var box := _aabb(inst)
	assert_true(box.end.z > -box.position.z + 0.15, "handles on +Z (%s)" % box)
	var grips := 0
	for p: Vector3 in _vertices(inst):
		if p.z > box.end.z - 0.2 and p.y > 0.7 and p.y < 1.0:
			grips += 1
	assert_true(grips > 0, "grip ends at ~0.85 m")
	inst.free()


func test_corpse_variants_match_and_fit_the_stations() -> void:
	var corpse := _size("ph_prop_corpse")
	var shrouded := _size("ph_prop_corpse_shrouded")
	assert_almost(shrouded.x, corpse.x, 0.1, "same length")
	assert_true(shrouded.x > shrouded.z * 2.0, "shrouded corpse lies along X")
	for name: String in CORPSE_VARIANTS:
		var v := _size(name)
		assert_almost(v.x, corpse.x, 0.05, name + " has the length of variant 0")
		assert_almost(v.z, corpse.z, 0.06, name + " has the width of variant 0")
		assert_true(v.x > v.z * 2.0, name + " lies along X")
		for station: String in ["ph_prop_morgue_table", "ph_prop_dropoff_bier"]:
			var s := _size(station)
			assert_true(v.x <= s.x and shrouded.x <= s.x, "%s fits the length of %s" % [name, station])
			assert_true(v.z <= s.z and shrouded.z <= s.z, "%s fits the width of %s" % [name, station])


func test_corpse_variants_lie_head_at_plus_x() -> void:
	# Head and folded arms at +X: the upper body is wider than the legs; the boots at -X.
	for name: String in CORPSE_VARIANTS + ["ph_prop_corpse_shrouded"]:
		var inst := _load(name)
		var head_half := 0.0
		var feet_half := 0.0
		for p: Vector3 in _vertices(inst):
			if p.x > 0.15:
				head_half = maxf(head_half, absf(p.z))
			elif p.x < -0.15:
				feet_half = maxf(feet_half, absf(p.z))
		assert_true(head_half > feet_half, "%s: shoulders (+X) wider than legs (%f vs %f)" % [name, head_half, feet_half])
		inst.free()


func test_corpse_variants_look_different() -> void:
	# Distinct clothes: the mean vertex colour of every pair of looks differs clearly.
	var means: Array[Color] = []
	for name: String in CORPSE_VARIANTS:
		means.append(_mean_colour(name))
	for i: int in means.size():
		for j: int in range(i + 1, means.size()):
			var a := means[i]
			var b := means[j]
			var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			assert_true(d > 0.02, "%s vs %s look alike (colour distance %f)" % [CORPSE_VARIANTS[i], CORPSE_VARIANTS[j], d])


func test_grave_plot_marks_a_1x2_plot() -> void:
	var inst := _load("ph_prop_grave_plot_empty")
	var tall: Array[Vector3] = []
	for p: Vector3 in _vertices(inst):
		if p.y > 0.315:  # peg tops (the string hangs lower)
			tall.append(p)
	assert_false(tall.is_empty(), "pegs stand up")
	for p: Vector3 in tall:
		assert_almost(absf(p.x), 0.5, 0.08, "pegs at x = ±0.5")
		assert_almost(absf(p.z), 1.0, 0.08, "pegs at z = ±1.0")
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var corner := false
			for p: Vector3 in tall:
				corner = corner or (signf(p.x) == float(sx) and signf(p.z) == float(sz))
			assert_true(corner, "peg at corner (%d, %d)" % [sx, sz])
	inst.free()


func test_grave_pit_reads_as_a_hole() -> void:
	# Fake depth: the floor near the camera (+Z) is dark, the far wall (-Z) lighter, the rim lighter still.
	var inst := _load("ph_prop_grave_pit")
	var near := _mean_luma(inst, _is_pit_near_floor)
	var far := _mean_luma(inst, _is_pit_far_wall)
	var rim := _mean_luma(inst, _is_pit_rim)
	assert_true(near >= 0.0 and far >= 0.0 and rim >= 0.0, "regions found (%f, %f, %f)" % [near, far, rim])
	assert_true(near < far, "far wall lighter than the floor (%f < %f)" % [near, far])
	assert_true(near < rim * 0.35, "floor much darker than the rim (%f vs %f)" % [near, rim])
	var box := _aabb(inst)
	assert_almost(box.get_center().z, 0.0, CENTRE_EPS, "hole centred on the plot (z)")
	assert_true(box.position.x > -0.85 and box.position.x < -0.6, "rim around the 1 m wide hole (%f)" % box.position.x)
	assert_true(box.end.x > 1.2, "dirt pile on the +X side")
	inst.free()


func test_signpost_board_points_plus_x_with_label_marker() -> void:
	var inst := _load("ph_prop_signpost")
	var box := _aabb(inst)
	assert_true(box.end.x > -box.position.x * 2.0, "arrow board points to +X (%s)" % box)
	var label := _marker(inst, "label_board")
	assert_true(label.origin.x > 0.1 and label.origin.y > 1.3 and label.origin.y < 1.8, "label on the board")
	assert_true(label.origin.z > 0.0, "label on the front face (+Z)")
	inst.free()


func test_fallen_log_is_a_long_road_block() -> void:
	var s := _size("ph_prop_fallen_log")
	assert_true(s.x >= 5.5, "long enough to block a road (%f m)" % s.x)
	assert_true(s.x > s.z * 2.5, "lies along X")


func test_blender_sources_and_generators_exist() -> void:
	for name: String in MODELS:
		var src := BLEND_DIR + String(MODELS[name][0]) + "/" + name + ".blend"
		assert_true(FileAccess.file_exists(src), "source " + src)
	for script: String in ["res://tools/blender/asset_props_slice.py", "res://tools/blender/asset_items.py"]:
		assert_true(FileAccess.file_exists(script), script)
		assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), script + " exposes build()")


# --- helpers -----------------------------------------------------------------------

func _path(name: String) -> String:
	return MODEL_DIR + String(MODELS[name][0]) + "/" + name + ".glb"


func _load(name: String) -> Node3D:
	return (load(_path(name)) as PackedScene).instantiate() as Node3D


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


func _load_and_free_meshes(name: String) -> Array[Mesh]:
	var out: Array[Mesh] = []
	var inst := _load(name)
	for mi: MeshInstance3D in _meshes(inst):
		out.append(mi.mesh)
	inst.free()
	return out


func _triangles(meshes: Array[Mesh]) -> int:
	var tris := 0
	for mesh: Mesh in meshes:
		for i: int in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(i)
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


## Pit regions (Godot axes, +Z = towards the camera): floor behind the near lip, far wall, raised rim.
func _is_pit_near_floor(p: Vector3) -> bool:
	return absf(p.x) < 0.3 and p.z > 0.1 and p.z < 0.9 and p.y < 0.06


func _is_pit_far_wall(p: Vector3) -> bool:
	return absf(p.x) < 0.3 and p.z < -0.5 and p.z > -0.97 and p.y < 0.06


func _is_pit_rim(p: Vector3) -> bool:
	return p.y > 0.065 and p.y < 0.14 and absf(p.x) < 0.66 and absf(p.z) < 1.16


## Mean vertex colour of a model (all surfaces).
func _mean_colour(name: String) -> Color:
	var inst := _load(name)
	var sum := Vector3.ZERO
	var count := 0
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			for c: Color in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] as PackedColorArray:
				sum += Vector3(c.r, c.g, c.b)
				count += 1
	inst.free()
	var m := sum / maxf(1.0, float(count))
	return Color(m.x, m.y, m.z)


## Mean vertex-colour luminance of the vertices matching `pick`, -1 if none match.
func _mean_luma(inst: Node3D, pick: Callable) -> float:
	var total := 0.0
	var count := 0
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for i: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if cols.size() != verts.size():
				continue
			for v: int in verts.size():
				if pick.call(xf * verts[v]):
					total += cols[v].get_luminance()
					count += 1
	return total / count if count > 0 else -1.0
