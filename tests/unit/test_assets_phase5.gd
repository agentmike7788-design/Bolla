extends TestCase
## Phase 5 assets (P5, docs/PHASE5_DESIGN.md §8): workshop stations and workyard props, the gather
## nodes of the Schlag and of Am Bruch, the quarry walls, the grave stone shapes with their ornament
## reliefs, the tool tiers and the new material items.
## Sizes use Godot axes: x = width, y = height, z = depth (Blender -Y = Godot +Z = model front).

const MODEL_DIR := "res://assets/models/"
const BLEND_DIR := "res://art_source/blender/"
const MATERIAL_DIR := "res://assets/materials/"
const FOLIAGE := "res://assets/materials/mat_foliage.tres"
const GRASS := "res://assets/materials/mat_grass.tres"
const EMISSIVE := "res://assets/materials/mat_emissive_warm.tres"
const MIN_TRIS := 100
const MAX_SINK := 0.35
const GROUND_EPS := 0.01
const CENTRE_EPS := 0.08
const GENERATORS: Array[String] = ["asset_stations_phase5", "asset_env_phase5", "asset_stones_phase5", "asset_items"]
const ITEM_MIN := Vector3(0.1, 0.01, 0.1)
const ITEM_MAX := Vector3(0.45, 0.3, 0.45)
const FOOTPRINT_SLACK := 0.15          # painted ground patch / roof edge may reach a little past the plot

## name -> [category, min size, max size, footprint centred on the pivot, triangle budget (§8)]
const MODELS := {
	"ph_bld_mason_bench": ["buildings", Vector3(2.2, 0.8, 1.3), Vector3(2.6 + FOOTPRINT_SLACK, 1.3, 1.6 + FOOTPRINT_SLACK), true, 3500],
	"ph_bld_loom": ["buildings", Vector3(1.9, 2.2, 1.5), Vector3(2.2 + FOOTPRINT_SLACK, 2.8, 1.8 + FOOTPRINT_SLACK), true, 4000],
	"ph_bld_forge": ["buildings", Vector3(2.2, 3.4, 1.7), Vector3(2.6 + FOOTPRINT_SLACK, 4.2, 2.0 + FOOTPRINT_SLACK), true, 4500],
	"ph_prop_charcoal_kiln": ["props", Vector3(1.4, 0.7, 1.4), Vector3(1.9, 1.0, 1.9), true, 900],
	"ph_prop_charcoal_kiln_burning": ["props", Vector3(1.4, 0.7, 1.4), Vector3(1.9, 1.0, 1.9), true, 900],
	"ph_prop_build_site": ["props", Vector3(2.3, 0.3, 1.7), Vector3(2.5, 0.8, 1.9), true, 600],
	"ph_prop_build_site_slab": ["props", Vector3(0.9, 0.05, 0.6), Vector3(1.4, 0.3, 1.1), true, 600],
	"ph_env_alder_coppice": ["environment", Vector3(2.2, 4.5, 2.2), Vector3(4.2, 7.0, 4.2), true, 4500],
	"ph_env_alder_stump": ["environment", Vector3(0.6, 0.3, 0.6), Vector3(1.5, 0.7, 1.5), true, 400],
	"ph_env_alder_sapling": ["environment", Vector3(0.9, 1.3, 0.9), Vector3(2.2, 2.4, 2.2), true, 900],
	"ph_env_flax_bed": ["environment", Vector3(1.3, 0.5, 0.9), Vector3(1.7, 1.0, 1.3), true, 1500],
	"ph_env_flax_bed_empty": ["environment", Vector3(1.3, 0.05, 0.9), Vector3(1.7, 0.6, 1.3), true, 400],
	"ph_env_clay_pit": ["environment", Vector3(1.6, 0.15, 1.2), Vector3(2.6, 1.3, 2.0), true, 1200],
	"ph_env_quarry_face": ["environment", Vector3(8.8, 3.3, 1.5), Vector3(9.2, 4.6, 3.5), true, 6000],
	"ph_env_quarry_edge": ["environment", Vector3(2.8, 2.4, 1.2), Vector3(3.3, 4.0, 3.2), true, 1500],
	"ph_env_ore_vein": ["environment", Vector3(0.9, 0.6, 0.6), Vector3(1.6, 1.2, 1.4), true, 700],
	"ph_env_ore_vein_empty": ["environment", Vector3(0.9, 0.6, 0.6), Vector3(1.6, 1.2, 1.4), true, 700],
	"ph_env_workstone_ledge": ["environment", Vector3(1.3, 0.5, 0.8), Vector3(1.9, 1.0, 1.5), true, 900],
	"ph_env_workstone_ledge_empty": ["environment", Vector3(1.3, 0.4, 0.8), Vector3(1.9, 1.0, 1.5), true, 900],
	"ph_env_rubble_face": ["environment", Vector3(1.5, 1.0, 0.8), Vector3(2.2, 1.6, 1.5), true, 900],
	"ph_env_boulder": ["environment", Vector3(1.8, 1.4, 1.5), Vector3(2.3, 2.0, 2.1), true, 1200],
	"ph_env_boulder_broken": ["environment", Vector3(1.3, 0.4, 1.0), Vector3(2.1, 1.0, 1.8), true, 600],
	"ph_env_herb_patch": ["environment", Vector3(0.6, 0.6, 0.5), Vector3(1.3, 1.1, 1.1), true, 800],
	"ph_env_herb_patch_cut": ["environment", Vector3(0.4, 0.05, 0.3), Vector3(1.0, 0.3, 0.8), true, 300],
	"ph_prop_gravestone_stele": ["props", Vector3(0.56, 0.95, 0.12), Vector3(0.8, 1.15, 0.35), true, 600],
	"ph_prop_gravestone_arch": ["props", Vector3(0.62, 0.95, 0.13), Vector3(0.85, 1.15, 0.35), true, 800],
	"ph_prop_gravestone_master": ["props", Vector3(0.95, 1.3, 0.3), Vector3(1.2, 1.7, 0.5), true, 1600],
	"ph_item_shovel_iron": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_shovel_master": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_axe_iron": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_axe_master": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_pickaxe_iron": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_pickaxe_master": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_flax": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_yarn": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_clay": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_iron_ore": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_iron_bar": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_charcoal": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_workstone": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_elderberries": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_herbs": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_ink": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_herb_bundle": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_gold_leaf": ["items", ITEM_MIN, ITEM_MAX, true, 800],
	"ph_item_steel_rod": ["items", ITEM_MIN, ITEM_MAX, true, 800],
}
## Ornament reliefs: origin = centre of the back plane, 0.02 m deep towards +Z (checked separately).
const RELIEFS: Array[String] = ["ph_prop_orn_ivy", "ph_prop_orn_poppy", "ph_prop_orn_elder", "ph_prop_orn_torch"]
const RELIEF_BUDGET := 400
const RELIEF_MAX := Vector2(0.3, 0.27)
## Markers each model must carry (glTF empties -> Node3D); every other model carries none.
const MARKERS := {
	"ph_bld_mason_bench": ["stone_slot_1", "stone_slot_2", "stone_slot_3", "use"],
	"ph_bld_forge": ["light_ember", "smoke"],
	"ph_prop_charcoal_kiln": ["smoke"],
	"ph_prop_charcoal_kiln_burning": ["smoke"],
	"ph_prop_gravestone_stele": ["inscription", "ornament"],
	"ph_prop_gravestone_arch": ["inscription", "ornament"],
	"ph_prop_gravestone_master": ["inscription", "ornament"],
}
## §2.1 footprints (x × z) of the three stations
const FOOTPRINTS := {"ph_bld_mason_bench": Vector2(2.6, 1.6), "ph_bld_loom": Vector2(2.2, 1.8),
		"ph_bld_forge": Vector2(2.6, 2.0)}
## shape -> StoneShapeData.label_width (W0: 0.5 / 0.55 / 0.7 m)
const STONES := {"ph_prop_gravestone_stele": 0.5, "ph_prop_gravestone_arch": 0.55, "ph_prop_gravestone_master": 0.7}
const FOLIAGE_MODELS: Array[String] = ["ph_env_alder_coppice", "ph_env_alder_sapling", "ph_env_herb_patch"]
const TOOLS: Array[String] = ["shovel", "axe", "pickaxe"]
const EMBER := Color("#E07A3A")

var _to_free: Array[Node] = []


func after_each() -> void:
	for n: Node in _to_free:
		if is_instance_valid(n):
			n.free()
	_to_free.clear()


# --- every model -------------------------------------------------------------------------

func test_every_model_exists_and_loads() -> void:
	for name: String in _all():
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
	for name: String in _all():
		var inst := _load_free(name)
		for cls: String in ["Skeleton3D", "AnimationPlayer", "Camera3D", "Light3D"]:
			assert_true(inst.find_children("*", cls, true, false).is_empty(), "%s has no %s" % [name, cls])


func test_all_surfaces_use_shared_materials() -> void:
	for name: String in _all():
		for path: String in _material_paths(name):
			assert_true(path.begins_with(MATERIAL_DIR) and path.ends_with(".tres"),
					"%s uses a shared material (got '%s')" % [name, path])


func test_triangle_budgets() -> void:
	for name: String in _all():
		var tris := _triangles(name)
		var budget: int = RELIEF_BUDGET if name in RELIEFS else int(MODELS[name][4])
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
	for name: String in _all():
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
	# §8: the forge embers are vertex colour + an omni light at light_ember, never an emissive surface
	for name: String in _all():
		assert_false(EMISSIVE in _material_paths(name), name + " has no emissive surface")


func test_no_cold_saturated_colour() -> void:
	# ART_DIRECTION §3: saturated cold colour belongs to the supernatural only (the blued master
	# blades stay a dusky, low-saturation blue-grey; no blue flax bloom)
	for name: String in _all():
		var worst := 0.0
		for c: Color in _colours(name):
			var s := c.linear_to_srgb()
			if s.h > 0.45 and s.h < 0.72 and s.v > 0.25:
				worst = maxf(worst, s.s)
		assert_true(worst < 0.35, "%s has a saturated cold colour (saturation %f)" % [name, worst])


func test_blender_sources_and_generators_exist() -> void:
	for name: String in _all():
		var src := BLEND_DIR + _category(name) + "/" + name + ".blend"
		assert_true(FileAccess.file_exists(src), "source " + src)
	var build_all := FileAccess.get_file_as_string("res://tools/blender/build_all.py")
	for module: String in GENERATORS:
		var script := "res://tools/blender/%s.py" % module
		assert_true(FileAccess.file_exists(script), script)
		assert_true(FileAccess.get_file_as_string(script).contains("\ndef build("), script + " exposes build()")
		assert_true(build_all.contains("\"%s\"" % module), module + " is registered in build_all.MODULES")


# --- stations ----------------------------------------------------------------------------------

func test_stations_fit_their_building_plots() -> void:
	for name: String in FOOTPRINTS:
		var box := _aabb(_load_free(name))
		var fp: Vector2 = FOOTPRINTS[name]
		assert_true(box.size.x <= fp.x + FOOTPRINT_SLACK, "%s width %.2f fits the %.1f m plot" % [name, box.size.x, fp.x])
		assert_true(box.size.z <= fp.y + FOOTPRINT_SLACK, "%s depth %.2f fits the %.1f m plot" % [name, box.size.z, fp.y])
		assert_true(box.size.x >= fp.x * 0.8 and box.size.z >= fp.y * 0.8, "%s fills its plot %s" % [name, box.size])


func test_mason_stone_slots_lean_at_the_east_end() -> void:
	var inst := _load_free("ph_bld_mason_bench")
	var box := _aabb(inst)
	var xs: Array[float] = []
	for i: int in 3:
		var t := _marker(inst, "stone_slot_%d" % (i + 1))
		assert_true(t.origin.x > 0.1, "slot %d at the east end (x %.2f)" % [i + 1, t.origin.x])
		assert_true(t.origin.y >= 0.0 and t.origin.y < 0.12, "slot %d on the rack sleepers (y %.2f)" % [i + 1, t.origin.y])
		assert_true(absf(t.origin.z) < 0.6, "slot %d inside the plot (z %.2f)" % [i + 1, t.origin.z])
		assert_true(t.basis.z.z > 0.98, "slot %d: stone front faces +Z" % (i + 1))
		assert_true(t.basis.y.z < -0.05 and t.basis.y.z > -0.2, "slot %d: the stone leans back a little (%.3f)" % [i + 1, t.basis.y.z])
		xs.append(t.origin.x)
	for i: int in 2:
		var a := _marker(inst, "stone_slot_%d" % (i + 1)).origin
		var b := _marker(inst, "stone_slot_%d" % (i + 2)).origin
		assert_true(a.distance_to(b) > 0.4, "slots %d/%d apart (%.2f m)" % [i + 1, i + 2, a.distance_to(b)])
	var use := _marker(inst, "use").origin
	assert_true(use.z > box.end.z - 0.1 and use.z < box.end.z + 0.8, "use: in the access strip south of the bench (z %.2f)" % use.z)
	assert_true(use.x < 0.0, "use: in front of the work block, west of the rack (x %.2f)" % use.x)
	assert_almost(use.y, 0.0, 0.01, "use on the ground")


func test_forge_ember_and_smoke_markers() -> void:
	var inst := _load_free("ph_bld_forge")
	var box := _aabb(inst)
	var ember := _marker(inst, "light_ember").origin
	var smoke := _marker(inst, "smoke").origin
	assert_true(ember.y > 0.85 and ember.y < 1.4, "ember light just above the hearth (y %.2f)" % ember.y)
	assert_true(absf(ember.x) < 0.8 and absf(ember.z) < 0.6, "ember over the fire bed %s" % ember)
	assert_true(smoke.y > 3.4 and smoke.y >= box.end.y - 0.1, "smoke at the chimney top (y %.2f, top %.2f)" % [smoke.y, box.end.y])
	# §4.1: chimney, smoke and glow reach above the hut roof seen from behind (ridge 4.6 m at 3.9 m distance)
	assert_true(box.end.y > 3.4, "chimney rises to %.2f m" % box.end.y)


func test_forge_embers_are_painted_ember_orange() -> void:
	var glow := 0
	for c: Color in _colours("ph_bld_forge"):
		var s := c.linear_to_srgb()
		if absf(s.r - EMBER.r) < 0.08 and absf(s.g - EMBER.g) < 0.1 and absf(s.b - EMBER.b) < 0.1:
			glow += 1
	assert_true(glow >= 20, "coals painted #E07A3A (%d vertices)" % glow)


func test_forge_is_worked_from_the_west() -> void:
	# §2.1: access West – the anvil stands west of the fire, the chimney east of it
	var inst := _load_free("ph_bld_forge")
	var ember := _marker(inst, "light_ember").origin
	var west := 0
	for p: Vector3 in _vertices(inst):
		if p.x < ember.x - 0.7 and p.y > 0.6 and p.y < 0.95:
			west += 1                                     # the anvil face at working height
	assert_true(west > 20, "anvil at working height west of the fire (%d vertices)" % west)
	assert_true(_marker(inst, "smoke").origin.x > ember.x, "chimney east of the fire")


func test_loom_is_open_to_the_camera_under_its_lean_to() -> void:
	# a lean-to high at the front (+Z) and low at the back, the cloth visible under it
	var verts := _vertices_of("ph_bld_loom")
	var front := 0.0
	var back := 0.0
	for p: Vector3 in verts:
		if p.z > 0.6:
			front = maxf(front, p.y)
		if p.z < -0.6:
			back = maxf(back, p.y)
	assert_true(front > back + 0.25, "roof high at the front (%.2f) and low at the back (%.2f)" % [front, back])
	var linen := 0
	for c: Color in _colours("ph_bld_loom"):
		var s := c.linear_to_srgb()
		if s.v > 0.62 and s.s < 0.3 and s.r > s.b:
			linen += 1
	assert_true(linen > 40, "unbleached warm linen on the loom (%d vertices)" % linen)


func test_kiln_smoke_on_top_and_burning_is_darker() -> void:
	for name: String in ["ph_prop_charcoal_kiln", "ph_prop_charcoal_kiln_burning"]:
		var inst := _load_free(name)
		var box := _aabb(inst)
		var m := _marker(inst, "smoke").origin
		assert_true(absf(m.x) < 0.1 and absf(m.z) < 0.1, "%s smoke from the top centre %s" % [name, m])
		assert_true(m.y > box.end.y - 0.1, "%s smoke at the top (%.2f)" % [name, m.y])
	assert_true(_mean_value("ph_prop_charcoal_kiln_burning") < _mean_value("ph_prop_charcoal_kiln") - 0.04,
			"the charring kiln is blackened")


func test_build_site_stakes_are_a_separate_mesh() -> void:
	var inst := _load_free("ph_prop_build_site")
	var stakes := inst.find_child("stakes", true, false)
	assert_true(stakes is MeshInstance3D, "pegs, string and board: child mesh 'stakes' (hidden for Am Bruch)")
	var slab := _load_free("ph_prop_build_site_slab")
	assert_null(slab.find_child("stakes", true, false), "the Bruch slab has no pegs")


# --- grave stones & reliefs ----------------------------------------------------------------------

func test_stone_markers_sit_on_the_front_face() -> void:
	for name: String in STONES:
		var inst := _load_free(name)
		var ins := _marker(inst, "inscription")
		var orn := _marker(inst, "ornament")
		for t: Transform3D in [ins, orn]:
			assert_true(t.basis.is_equal_approx(Basis.IDENTITY), "%s marker: local +Z is the face normal" % name)
			assert_true(absf(t.origin.x) < 0.02, "%s marker centred (x %.3f)" % [name, t.origin.x])
			assert_true(_width_at(_front_tris(inst, t.origin.z), t.origin.y) > 0.1,
					"%s marker on a front-facing surface at %s" % [name, t.origin])
		assert_true(orn.origin.y > ins.origin.y + 0.25, "%s ornament field above the text" % name)


func test_stone_text_fields_hold_the_label_width() -> void:
	for name: String in STONES:
		var inst := _load_free(name)
		var ins := _marker(inst, "inscription").origin
		var tris := _front_tris(inst, ins.z)
		for dy: float in [-0.12, 0.0, 0.12]:          # four lines of text (section 2.5) around the marker
			var w := _width_at(tris, ins.y + dy)
			assert_true(w >= float(STONES[name]) + 0.03,
					"%s: face %.2f m wide at y %.2f for a %.2f m label" % [name, w, ins.y + dy, STONES[name]])


func test_stone_shapes_grow_with_their_rank() -> void:
	var stele := _aabb(_load_free("ph_prop_gravestone_stele")).size
	var arch := _aabb(_load_free("ph_prop_gravestone_arch")).size
	var master := _aabb(_load_free("ph_prop_gravestone_master")).size
	assert_true(master.x > arch.x + 0.15 and master.y > arch.y + 0.25, "the Meisterstein is wide and tall")
	assert_true(_triangles("ph_prop_gravestone_master") > _triangles("ph_prop_gravestone_arch"), "master has more detail")
	var dark := 0
	for c: Color in _colours("ph_prop_gravestone_master"):
		var s := c.linear_to_srgb()
		if s.v < 0.32:
			dark += 1
	assert_true(dark >= 16, "two dark iron clamps on the Meisterstein (%d vertices)" % dark)
	assert_true(stele.y > 0.9 and arch.y > 0.9, "stele and arch at gravestone height")


func test_reliefs_are_flat_centred_stone() -> void:
	var stone_mat := _material_paths("ph_prop_gravestone_stele")
	for name: String in RELIEFS:
		var box := _aabb(_load_free(name))
		assert_almost(box.size.z, 0.02, 0.003, name + " relief 0.02 m deep")
		assert_almost(box.position.z, 0.0, 0.002, name + " back plane at the marker")
		assert_true(absf(box.get_center().x) < 0.01 and absf(box.get_center().y) < 0.01, name + " centred on its origin")
		assert_true(box.size.x <= RELIEF_MAX.x and box.size.y <= RELIEF_MAX.y, "%s fits the ornament field %s" % [name, box.size])
		assert_true(box.size.x >= 0.08 and box.size.y >= 0.15, "%s readable size %s" % [name, box.size])
		for p: String in _material_paths(name):
			assert_has(stone_mat, p, name + " uses the shared stone material")


func test_reliefs_fit_on_every_stone() -> void:
	for stone: String in STONES:
		var inst := _load_free(stone)
		var o := _marker(inst, "ornament").origin
		var tris := _front_tris(inst, o.z)
		var top := _aabb(inst).end.y
		for name: String in RELIEFS:
			var r := _aabb(_load_free(name))
			assert_true(o.y + r.end.y <= top, "%s stays on %s (top %.2f > %.2f)" % [name, stone, o.y + r.end.y, top])
			var w := minf(_width_at(tris, o.y), _width_at(tris, o.y - r.size.y * 0.3))
			assert_true(r.size.x <= w, "%s narrower than the %s field (%.2f / %.2f)" % [name, stone, r.size.x, w])


# --- nature ------------------------------------------------------------------------------------

func test_alder_stages() -> void:
	var tree := _aabb(_load_free("ph_env_alder_coppice")).size
	var stump := _aabb(_load_free("ph_env_alder_stump")).size
	var sap := _aabb(_load_free("ph_env_alder_sapling")).size
	assert_true(tree.y > sap.y + 2.0 and sap.y > stump.y + 0.8, "tree %.1f > sapling %.1f > stump %.1f" % [tree.y, sap.y, stump.y])
	var cut := 0
	for c: Color in _colours("ph_env_alder_stump"):
		var s := c.linear_to_srgb()
		if s.v > 0.68 and s.r > s.b + 0.2:
			cut += 1
	assert_true(cut >= 12, "fresh, light cut faces on the stump (%d vertices)" % cut)


func test_foliage_uses_the_leaf_shader() -> void:
	for name: String in FOLIAGE_MODELS:
		assert_has(_material_paths(name), FOLIAGE, name + " leaves use mat_foliage (wind)")
	assert_has(_material_paths("ph_env_flax_bed"), GRASS, "flax stalks sway (mat_grass)")


func test_flax_bed_is_ripe_straw_not_blue() -> void:
	var straw := 0
	for c: Color in _colours("ph_env_flax_bed"):
		var s := c.linear_to_srgb()
		if s.h > 0.08 and s.h < 0.17 and s.s > 0.3 and s.v > 0.45:
			straw += 1
	assert_true(straw > 200, "straw-yellow ripe stalks (%d vertices)" % straw)
	assert_true(_aabb(_load_free("ph_env_flax_bed_empty")).size.y < 0.6, "the pulled bed is low")


func test_herb_patch_has_tansy_buttons() -> void:
	var yellow := 0
	for c: Color in _colours("ph_env_herb_patch"):
		var s := c.linear_to_srgb()
		if s.h > 0.1 and s.h < 0.16 and s.s > 0.6 and s.v > 0.7:
			yellow += 1
	assert_true(yellow >= 40, "golden tansy buttons (%d vertices)" % yellow)


func test_ore_vein_is_rust_brown_and_mined_out_less_so() -> void:
	assert_true(_rust_share("ph_env_ore_vein") > 0.08, "rust-brown veins (%.2f)" % _rust_share("ph_env_ore_vein"))
	assert_true(_rust_share("ph_env_ore_vein_empty") < _rust_share("ph_env_ore_vein"), "the veins are hacked out")


func test_empty_nodes_keep_the_footprint() -> void:
	for pair: Array in [["ph_env_ore_vein", "ph_env_ore_vein_empty"], ["ph_env_workstone_ledge", "ph_env_workstone_ledge_empty"],
			["ph_env_flax_bed", "ph_env_flax_bed_empty"]]:
		var a := _aabb(_load_free(pair[0])).size
		var b := _aabb(_load_free(pair[1])).size
		assert_almost(a.x, b.x, 0.15, "%s / %s same width" % pair)
		assert_almost(a.z, b.z, 0.15, "%s / %s same depth" % pair)


func test_boulder_is_mossy_and_needs_a_2m_cell() -> void:
	var box := _aabb(_load_free("ph_env_boulder")).size
	assert_true(box.x <= 2.3 and box.z <= 2.3, "fits the 2 x 2 m footprint %s" % box)
	var moss := 0
	var cols := _colours("ph_env_boulder")
	for c: Color in cols:
		var s := c.linear_to_srgb()
		if s.h > 0.17 and s.h < 0.33 and s.s > 0.2:
			moss += 1
	assert_true(moss > cols.size() / 5, "moss on the erratic (%d of %d)" % [moss, cols.size()])


func test_quarry_face_spans_the_north_edge() -> void:
	var box := _aabb(_load_free("ph_env_quarry_face")).size
	assert_almost(box.x, 9.0, 0.2, "9 m face")
	assert_true(box.y > 3.3, "a real cliff (%.1f m)" % box.y)


# --- items ---------------------------------------------------------------------------------------

func test_tool_tiers_read_apart() -> void:
	for kind: String in TOOLS:
		var iron := "ph_item_%s_iron" % kind
		var master := "ph_item_%s_master" % kind
		assert_true(_count(master, _is_brass) >= 8, master + " has a warm brass ring")
		assert_eq(_count(iron, _is_brass), 0, iron + " has no brass")
		assert_true(_count(master, _is_blued) >= 8, master + " has a blued blade")
		assert_eq(_count(iron, _is_blued), 0, iron + " stays dark iron")
		var a := _aabb(_load_free(iron)).size
		var b := _aabb(_load_free(master)).size
		assert_almost(a.x, b.x, 0.03, kind + ": both tiers are the same tool")


func test_elderberries_are_ink_violet() -> void:
	var berries := 0
	for c: Color in _colours("ph_item_elderberries"):
		var s := c.linear_to_srgb()
		if s.v < 0.32 and (s.h > 0.72 or s.h < 0.02) and s.s > 0.15:
			berries += 1
	assert_true(berries > 60, "ink-violet berries (%d vertices)" % berries)


# --- helpers -----------------------------------------------------------------------------------

func _all() -> Array[String]:
	var out: Array[String] = []
	for n: String in MODELS:
		out.append(n)
	out.append_array(RELIEFS)
	return out


func _category(name: String) -> String:
	return "props" if name in RELIEFS else String(MODELS[name][0])


func _path(name: String) -> String:
	return MODEL_DIR + _category(name) + "/" + name + ".glb"


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


func _vertices_of(name: String) -> PackedVector3Array:
	return _vertices(_load_free(name))


func _colours(name: String) -> PackedColorArray:
	var out := PackedColorArray()
	for mi: MeshInstance3D in _meshes(_load_free(name)):
		for i: int in mi.mesh.get_surface_count():
			out.append_array(mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] as PackedColorArray)
	return out


## Triangles facing the model front (+Z) that lie in the plane z (+- 4 mm).
func _front_tris(inst: Node3D, z: float) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = []
	for mi: MeshInstance3D in _meshes(inst):
		var xf := _xf(mi, inst)
		for i: int in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for k: int in range(0, idx.size(), 3):
				var a := xf * verts[idx[k]]
				var b := xf * verts[idx[k + 1]]
				var c := xf * verts[idx[k + 2]]
				if absf(a.z - z) > 0.004 or absf(b.z - z) > 0.004 or absf(c.z - z) > 0.004:
					continue
				var n := (b - a).cross(c - a)
				if n.length() > 1e-9 and absf(n.normalized().z) > 0.95:
					out.append(PackedVector3Array([a, b, c]))
	return out


## Horizontal extent of those triangles along the line at height y (their union's outer bounds).
func _width_at(tris: Array[PackedVector3Array], y: float) -> float:
	var lo := INF
	var hi := -INF
	for t: PackedVector3Array in tris:
		for e: int in 3:
			var p := t[e]
			var q := t[(e + 1) % 3]
			if (p.y - y) * (q.y - y) > 0.0 or absf(q.y - p.y) < 1e-9:
				continue
			var x := p.x + (q.x - p.x) * (y - p.y) / (q.y - p.y)
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return hi - lo if hi > lo else 0.0


func _mean_value(name: String) -> float:
	var v := 0.0
	var cols := _colours(name)
	for c: Color in cols:
		v += c.linear_to_srgb().v
	return v / maxf(1.0, cols.size())


func _rust_share(name: String) -> float:
	var n := 0
	var cols := _colours(name)
	for c: Color in cols:
		var s := c.linear_to_srgb()
		if (s.h < 0.08 or s.h > 0.97) and s.s > 0.35 and s.v > 0.2:
			n += 1
	return float(n) / maxf(1.0, cols.size())


func _count(name: String, pred: Callable) -> int:
	var n := 0
	for c: Color in _colours(name):
		if pred.call(c.linear_to_srgb()):
			n += 1
	return n


func _is_brass(s: Color) -> bool:
	return s.h > 0.08 and s.h < 0.14 and s.s > 0.45 and s.v > 0.55


func _is_blued(s: Color) -> bool:
	return s.h > 0.55 and s.h < 0.7 and s.s > 0.15 and s.v > 0.25 and s.v < 0.55
