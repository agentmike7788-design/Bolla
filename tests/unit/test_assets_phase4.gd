extends TestCase
## Phase 4 assets (P5, docs/PHASE4_DESIGN.md §8): corpse looks, laying-out and care props, the
## Holunderwinkel (gate, sunken pits, elders), item models and the painted VFX textures.
## Ilse Kranich (ph_chr_kranich) is checked with the other rigged characters in test_assets_characters.gd.
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front).

const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const FOLIAGE := "res://assets/materials/mat_foliage.tres"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const VFX_DIR := "res://assets/vfx/"
const MIN_TRIS := 100
const MAX_SINK := 0.35
const GROUND_EPS := 0.01
const CENTRE_EPS := 0.06
const GENERATORS: Array[String] = ["asset_trader", "asset_corpses_phase4", "asset_props_phase4", "asset_env_phase4",
		"asset_items"]
const ITEM_MIN := Vector3(0.1, 0.01, 0.1)
const ITEM_MAX := Vector3(0.45, 0.3, 0.45)

## name -> [category, min size, max size, footprint centred on the pivot, triangle budget (§8)]
const MODELS := {
	"ph_prop_corpse_05": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, 4000],
	"ph_prop_corpse_06": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, 4000],
	"ph_prop_corpse_gown": ["props", Vector3(1.6, 0.2, 0.45), Vector3(1.8, 0.36, 0.7), true, 3000],
	"ph_prop_layout_sprig": ["props", Vector3(0.12, 0.02, 0.06), Vector3(0.3, 0.1, 0.2), true, 300],
	"ph_prop_wash_basin": ["props", Vector3(0.35, 0.7, 0.3), Vector3(0.7, 0.95, 0.7), true, 900],
	"ph_prop_smoke_bowl": ["props", Vector3(0.15, 0.05, 0.15), Vector3(0.3, 0.15, 0.3), true, 300],
	"ph_prop_wall_ledge": ["props", Vector3(0.4, 0.35, 0.25), Vector3(0.8, 0.7, 0.6), true, 300],
	"ph_prop_gate_small": ["props", Vector3(1.15, 1.2, 0.05), Vector3(1.25, 1.6, 0.35), true, 800],
	"ph_prop_gate_small_open": ["props", Vector3(1.15, 1.2, 0.8), Vector3(1.5, 1.6, 1.3), false, 800],
	"ph_prop_pit_sunken": ["props", Vector3(0.95, 0.02, 1.9), Vector3(1.3, 0.35, 2.3), true, 900],
	"ph_env_elder_thicket": ["environment", Vector3(1.7, 1.3, 1.7), Vector3(2.4, 1.8, 2.4), true, 2500],
	"ph_env_elder_bush": ["environment", Vector3(2.2, 2.2, 2.2), Vector3(3.6, 3.6, 3.6), true, 4000],
	"ph_item_scrub_brush": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_comb": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_burial_gown": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_juniper": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_shears": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_pliers": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_hair_braid": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_teeth_pouch": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_elder_key": ["items", ITEM_MIN, ITEM_MAX, true, 800],
}
## Markers each model must carry (glTF empties -> Node3D); every other model carries none.
const MARKERS := {
	"ph_prop_corpse_05": ["sprig"],
	"ph_prop_corpse_06": ["sprig"],
	"ph_prop_corpse_gown": ["sprig"],
	"ph_prop_smoke_bowl": ["smoke"],
}
const CORPSES: Array[String] = ["ph_prop_corpse_05", "ph_prop_corpse_06", "ph_prop_corpse_gown"]
const FOLIAGE_MODELS: Array[String] = ["ph_env_elder_thicket", "ph_env_elder_bush"]
## texture -> [width, height]
const VFX := {
	"ph_vfx_fly_atlas": [256, 64],
	"ph_vfx_stench_wisp": [128, 128],
	"ph_vfx_smoke_wisp": [128, 128],
}

var _to_free: Array[Node] = []


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()


# --- every model -------------------------------------------------------------------------

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
		var budget: int = MODELS[name][4]
		assert_true(tris <= budget, "%s: %d triangles > budget %d" % [name, tris, budget])
		assert_true(tris >= MIN_TRIS, "%s: only %d triangles" % [name, tris])


func test_bounding_box_sizes() -> void:
	for name: String in MODELS:
		var box := _aabb(_load_free(name))
		var lo: Vector3 = MODELS[name][1]
		var hi: Vector3 = MODELS[name][2]
		for axis: int in 3:
			assert_true(box.size[axis] >= lo[axis] and box.size[axis] <= hi[axis],
					"%s size %s outside %s..%s (axis %d)" % [name, box.size, lo, hi, axis])


func test_pivot_bottom_centre() -> void:
	for name: String in MODELS:
		var box := _aabb(_load_free(name))
		assert_true(box.position.y <= GROUND_EPS, "%s rests on the ground (bottom %f)" % [name, box.position.y])
		assert_true(box.position.y >= -MAX_SINK, "%s sinks too deep (bottom %f)" % [name, box.position.y])
		if MODELS[name][3]:
			var c := box.get_center()
			assert_true(absf(c.x) <= CENTRE_EPS and absf(c.z) <= CENTRE_EPS,
					"%s footprint centred on the pivot (centre %s)" % [name, c])


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


func test_nothing_glows() -> void:
	# §8: the candle stub of the laid-out sprig has no light; Ilse's lantern is the only new glow
	for name: String in MODELS:
		assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")


func test_no_cold_saturated_colour() -> void:
	# ART_DIRECTION §3: saturated cold colour belongs to the supernatural only (elderberries
	# ink-violet, never a cold saturated blue)
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
	assert_true(FileAccess.file_exists(BLEND_DIR + "characters/ph_chr_kranich.blend"), "source of Ilse Kranich")
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")
	var vfx_tool := FileAccess.get_file_as_string("res://tools/textures/paint_vfx.py")
	for tex: String in VFX:
		assert_true(vfx_tool.contains(tex + ".png"), "paint_vfx.py writes " + tex)


# --- corpses ---------------------------------------------------------------------------------

func test_corpse_looks_share_the_footprint_of_variant_0() -> void:
	var base := _aabb(_load_free_at("props", "ph_prop_corpse")).size
	for name: String in CORPSES:
		var s := _aabb(_load_free(name)).size
		assert_almost(s.x, base.x, 0.05, name + " has the length of ph_prop_corpse")
		assert_almost(s.z, base.z, 0.06, name + " has the width of ph_prop_corpse")


func test_corpse_looks_lie_head_at_plus_x() -> void:
	# the head is the highest-reaching part at the +X end (as ph_prop_corpse, slot_corpse +X)
	for name: String in CORPSES:
		var head_end := 0.0
		for p: Vector3 in _vertices_of(name):
			if p.x > 0.6:
				head_end = maxf(head_end, p.y)
		assert_true(head_end > 0.2, "%s: head at +X (%.2f m high)" % [name, head_end])


func test_sprig_marker_rests_on_the_chest() -> void:
	for name: String in CORPSES:
		var inst := _load_free(name)
		var m := _marker(inst, "sprig").origin
		assert_true(m.x > 0.15 and m.x < 0.5, "%s: sprig on the chest, between hands and throat (x %.2f)" % [name, m.x])
		assert_true(absf(m.z) < 0.05, "%s: sprig on the body's centre line (z %.2f)" % [name, m.z])
		assert_true(m.y > 0.17 and m.y < 0.3, "%s: sprig on top of the chest (y %.2f)" % [name, m.y])


func test_burial_gown_is_lighter_and_warmer_than_the_shroud() -> void:
	# §8: "Leinen heller und wärmer als das Leichentuch"
	var gown := _cloth_tone(_colours("ph_prop_corpse_gown"))
	var shroud := _cloth_tone(_colours_at("props", "ph_prop_corpse_shrouded"))
	assert_true(gown.x > shroud.x, "gown linen lighter (%.3f vs %.3f)" % [gown.x, shroud.x])
	assert_true(gown.y > shroud.y, "gown linen warmer (%.3f vs %.3f)" % [gown.y, shroud.y])


func test_corpse_looks_differ_from_each_other() -> void:
	var means := {}
	for name: String in CORPSES:
		var c := Color(0, 0, 0)
		var cols := _colours(name)
		for col: Color in cols:
			c += col
		means[name] = c / maxf(1.0, cols.size())
	for a: String in CORPSES:
		for b: String in CORPSES:
			if a < b:
				var d := Vector3(means[a].r - means[b].r, means[a].g - means[b].g, means[a].b - means[b].b).length()
				assert_true(d > 0.01, "%s and %s read differently (%.3f)" % [a, b, d])


# --- care props --------------------------------------------------------------------------------

func test_smoke_marker_sits_above_the_embers() -> void:
	var inst := _load_free("ph_prop_smoke_bowl")
	var box := _aabb(inst)
	var m := _marker(inst, "smoke").origin
	assert_true(absf(m.x) < 0.03 and absf(m.z) < 0.03, "smoke rises from the bowl centre %s" % m)
	assert_true(m.y > box.size.y * 0.6 and m.y < box.end.y + 0.05, "smoke starts at the rim (y %.3f)" % m.y)


func test_wash_basin_stands_at_table_height() -> void:
	var box := _aabb(_load_free("ph_prop_wash_basin"))
	assert_true(box.size.y > 0.75 and box.size.y < 0.9, "basin rim at working height (%.2f m)" % box.size.y)


func test_wall_ledge_is_a_flat_shelf() -> void:
	var inst := _load_free("ph_prop_wall_ledge")
	var box := _aabb(inst)
	var top := 0
	for p: Vector3 in _vertices(inst):
		if p.y > box.end.y - 0.06:
			top += 1
	assert_true(box.size.x > box.size.z, "ledge longer than deep")
	assert_true(top >= 8, "a flat top to set the lantern on (%d vertices near the top)" % top)


# --- Holunderwinkel ---------------------------------------------------------------------------

func test_gates_share_the_posts_and_width() -> void:
	var closed := _aabb(_load_free("ph_prop_gate_small"))
	var opened := _aabb(_load_free("ph_prop_gate_small_open"))
	assert_almost(closed.size.x, 1.2, 0.05, "closed gate 1.2 m wide")
	assert_almost(closed.size.y, opened.size.y, 0.01, "same posts: same height")
	assert_almost(closed.end.x, opened.end.x, 0.02, "the latch post (+X) stays where it is")
	assert_true(closed.size.z < 0.35, "closed: the leaf lies in the fence line")
	assert_true(opened.position.z < -0.8, "open: the leaf swings back into the Holunderwinkel (-Z), %f" % opened.position.z)


func test_sunken_pit_covers_a_grave_plot() -> void:
	var pit := _aabb(_load_free("ph_prop_pit_sunken"))
	var plot := _aabb(_load_free_at("props", "ph_prop_grave_plot_empty"))
	assert_true(pit.size.z > pit.size.x * 1.6, "pit lies along Z like the 1 x 2 m plot")
	assert_almost(pit.size.x, plot.size.x, 0.3, "same width as a plot")
	assert_almost(pit.size.z, plot.size.z, 0.35, "same length as a plot")
	assert_true(pit.size.y < 0.3, "flat: sunken, not heaped (%.2f m)" % pit.size.y)


func test_elder_leaves_use_the_foliage_shader() -> void:
	for name: String in FOLIAGE_MODELS:
		assert_has(_material_paths(name), FOLIAGE, name + " leaves use mat_foliage (wind)")


func test_elder_bush_has_white_umbels_and_dark_berries() -> void:
	var umbels := 0
	var berries := 0
	for c: Color in _colours("ph_env_elder_bush"):
		var s := c.linear_to_srgb()
		if s.v > 0.72 and s.s < 0.25:
			umbels += 1
		if s.v < 0.32 and (s.h > 0.72 or s.h < 0.02) and s.s > 0.15:
			berries += 1
	assert_true(umbels > 50, "cream-white umbels (%d vertices)" % umbels)
	assert_true(berries > 50, "ink-violet berries (%d vertices)" % berries)
	var bush := _aabb(_load_free("ph_env_elder_bush")).size
	var thicket := _aabb(_load_free("ph_env_elder_thicket")).size
	assert_true(bush.y > thicket.y + 0.6, "the old elder towers over the thicket")


# --- VFX textures -----------------------------------------------------------------------------

func test_vfx_textures_have_the_contract_size_and_soft_alpha() -> void:
	for tex: String in VFX:
		var img := _image(tex)
		assert_not_null(img, tex + " loads")
		if img == null:
			continue
		assert_eq(img.get_width(), int(VFX[tex][0]), tex + " width")
		assert_eq(img.get_height(), int(VFX[tex][1]), tex + " height")
		assert_true(img.detect_alpha() == Image.ALPHA_BLEND, tex + " has soft alpha")
		var border := 0.0
		var opaque := 0
		for x: int in img.get_width():
			for y: int in img.get_height():
				var a := img.get_pixel(x, y).a
				if x == 0 or y == 0 or x == img.get_width() - 1 or y == img.get_height() - 1:
					border = maxf(border, a)
				if a > 0.5:
					opaque += 1
		assert_almost(border, 0.0, 0.01, tex + ": transparent border (no billboard edge)")
		assert_true(opaque > 100, tex + ": a visible painted shape (%d pixels)" % opaque)


func test_fly_atlas_has_four_ink_blue_frames_with_an_amber_glint() -> void:
	var img := _image("ph_vfx_fly_atlas")
	if img == null:
		fail("fly atlas missing")
		return
	for f: int in 4:
		var body := 0
		var glint := 0
		for x: int in range(f * 64, f * 64 + 64):
			for y: int in 64:
				var c := img.get_pixel(x, y)
				if c.a < 0.8:
					continue
				if absf(c.r - 0x1F / 255.0) < 0.08 and absf(c.g - 0x2A / 255.0) < 0.08 and absf(c.b - 0x3A / 255.0) < 0.08:
					body += 1
				if c.r > 0.6 and c.g > 0.35 and c.r - c.b > 0.3:
					glint += 1
		assert_true(body > 60, "frame %d: ink-blue body (%d px)" % [f, body])
		assert_true(glint >= 1, "frame %d: amber glint (%d px)" % [f, glint])
	# the wings beat: the frames differ
	var a := img.get_region(Rect2i(0, 0, 64, 64))
	var b := img.get_region(Rect2i(128, 0, 64, 64))
	assert_ne(a.get_data(), b.get_data(), "wing positions differ between frames")


func test_wisps_are_olive_and_warm_grey_never_turquoise() -> void:
	var stench := _mean_colour(_image("ph_vfx_stench_wisp"))
	var smoke := _mean_colour(_image("ph_vfx_smoke_wisp"))
	assert_true(stench.h > 0.1 and stench.h < 0.25, "stench is olive (hue %.3f)" % stench.h)
	assert_true(stench.s > 0.15 and stench.s < 0.5, "stench is pale, not vivid (sat %.3f)" % stench.s)
	assert_true(smoke.s < 0.15, "juniper smoke is grey (sat %.3f)" % smoke.s)
	assert_true(smoke.r >= smoke.b, "juniper smoke is warm grey")
	for tex: String in ["ph_vfx_stench_wisp", "ph_vfx_smoke_wisp"]:
		var img := _image(tex)
		var cold := 0
		for x: int in img.get_width():
			for y: int in img.get_height():
				var c := img.get_pixel(x, y)
				if c.a > 0.1 and c.h > 0.4 and c.h < 0.55 and c.s > 0.2:
					cold += 1
		assert_eq(cold, 0, tex + " has no green-turquoise pixels")


# --- helpers -----------------------------------------------------------------------------------

func _path(name: String) -> String:
	return MODEL_DIR + String(MODELS[name][0]) + "/" + name + ".glb"


func _load(name: String) -> Node3D:
	return (load(_path(name)) as PackedScene).instantiate() as Node3D


func _load_free(name: String) -> Node3D:
	var inst := _load(name)
	_to_free.append(inst)
	return inst


func _load_free_at(category: String, name: String) -> Node3D:
	var inst := (load(MODEL_DIR + category + "/" + name + ".glb") as PackedScene).instantiate() as Node3D
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


func _vertices_of(name: String) -> PackedVector3Array:
	return _vertices(_load_free(name))


func _colours_of(inst: Node3D) -> PackedColorArray:
	var out := PackedColorArray()
	for mi: MeshInstance3D in _meshes(inst):
		for i: int in mi.mesh.get_surface_count():
			out.append_array(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] as PackedColorArray)
	return out


func _colours(name: String) -> PackedColorArray:
	return _colours_of(_load_free(name))


func _colours_at(category: String, name: String) -> PackedColorArray:
	return _colours_of(_load_free_at(category, name))


## (mean brightness, mean warmth r - b) of the light cloth-coloured vertices (sRGB)
func _cloth_tone(cols: PackedColorArray) -> Vector2:
	var v := 0.0
	var w := 0.0
	var n := 0
	for c: Color in cols:
		var s := c.linear_to_srgb()
		if s.v > 0.55 and s.s < 0.3:
			v += s.v
			w += s.r - s.b
			n += 1
	return Vector2(v, w) / maxf(1.0, n)


func _image(tex: String) -> Image:
	var path := ProjectSettings.globalize_path(VFX_DIR + tex + ".png")
	if not FileAccess.file_exists(VFX_DIR + tex + ".png"):
		return null
	return Image.load_from_file(path)


## Alpha-weighted mean colour of an image.
func _mean_colour(img: Image) -> Color:
	var sum := Color(0, 0, 0, 0)
	var wsum := 0.0
	if img == null:
		return sum
	for x: int in img.get_width():
		for y: int in img.get_height():
			var c := img.get_pixel(x, y)
			sum += Color(c.r * c.a, c.g * c.a, c.b * c.a, 0)
			wsum += c.a
	return Color(sum.r / wsum, sum.g / wsum, sum.b / wsum, 1.0)
