extends TestCase
## P4 (docs/PHASE4_DESIGN.md §2.5, §8, §9, §10): CorpseDecayVisual – overlay continuous over the
## freshness (+ washed reduction), particle counts per stage, juniper smoke replaces the wisps,
## at most max_emitting corpses emit (≤ 60 particles), overlay material on every model mesh;
## decay_overlay.gdshader / VFX materials (no TIME, blend_mul, no shadows); Corpse: DecayVisual in
## corpse.tscn, dress (shroud / gown) and lay-out models, rotten stage, hourly refresh.

const SHADER := "res://assets/shaders/decay_overlay.gdshader"
const OVERLAY := "res://assets/materials/mat_decay_overlay.tres"
const VFX := ["res://assets/materials/mat_vfx_fly.tres", "res://assets/materials/mat_vfx_wisp.tres",
		"res://assets/materials/mat_vfx_smoke.tres"]
const CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
const SHROUDED := "res://assets/models/props/ph_prop_corpse_shrouded.glb"
const STAGES: Array[StringName] = [&"fresh", &"wilted", &"decaying", &"rotten"]


## CorpseManager read through get_record / economy only.
class CorpsesDouble extends CorpseManager:
	var recs: Dictionary = {}

	func _ready() -> void:
		pass

	func get_record(id: String) -> CorpseRecord:
		return recs.get(id) as CorpseRecord


var cfg: DecayVisualConfig
var economy: EconomyConfig
var made: Array[Node] = []


func before_each() -> void:
	cfg = Phase4Fixtures.decay_visual_config()
	economy = Phase4Fixtures.economy_config()
	made.clear()


func after_each() -> void:
	for n: Node in made:
		if is_instance_valid(n):
			n.free()
	made.clear()


# --- overlay -------------------------------------------------------------------------------

func test_overlay_is_continuous_and_monotone_over_freshness() -> void:
	var last := -1.0
	var prev := CorpseDecayVisual.overlay_for(1.0, cfg, economy)
	for i: int in range(1000, -1, -1):
		var f := float(i) / 1000.0
		var a := CorpseDecayVisual.overlay_for(f, cfg, economy)
		assert_true(a >= prev - 0.000001, "monotone at %.3f (%f < %f)" % [f, a, prev])
		assert_true(absf(a - prev) <= 0.02, "no jump at %.3f (%f → %f)" % [f, prev, a])
		assert_true(a >= 0.0 and a <= 1.0)
		prev = a
		last = a
	assert_almost(last, 1.0, 0.0001, "freshness 0 → full overlay")
	for f: float in [1.0, 0.8, 0.6]:
		assert_almost(CorpseDecayVisual.overlay_for(f, cfg, economy), 0.0, 0.0001, "fresh %.2f: nothing visible" % f)
	# Each stage's value in the middle of its freshness range.
	assert_almost(CorpseDecayVisual.overlay_for(0.45, cfg, economy), 0.35, 0.0001, "wilted")
	assert_almost(CorpseDecayVisual.overlay_for(0.2, cfg, economy), 0.7, 0.0001, "decaying")
	assert_almost(CorpseDecayVisual.overlay_for(0.05, cfg, economy), 1.0, 0.0001, "rotten")
	assert_almost(CorpseDecayVisual.overlay_for(-0.5, cfg, economy), 1.0, 0.0001, "clamped below")


func test_apply_overlay_amount_and_washed_reduction() -> void:
	var v := _visual()
	v.apply(1.0, &"fresh", false, false)
	assert_almost(v.overlay_amount(), 0.0)
	v.apply(0.45, &"wilted", false, false)
	assert_almost(v.overlay_amount(), 0.35, 0.0001)
	v.apply(0.45, &"wilted", false, true)
	assert_almost(v.overlay_amount(), 0.35 - cfg.washed_reduction, 0.0001, "washed: − washed_reduction")
	v.apply(0.9, &"fresh", false, true)
	assert_almost(v.overlay_amount(), 0.0, 0.0001, "never below 0")
	v.apply(0.0, &"rotten", false, true)
	assert_almost(v.overlay_amount(), 1.0 - cfg.washed_reduction, 0.0001)


func test_overlay_material_on_every_model_mesh_and_removed_when_fresh() -> void:
	var v := _visual()
	var model := Node3D.new()
	made.append(model)
	for i: int in 3:
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		(model if i < 2 else model.get_child(0)).add_child(mesh)
	v.set_target(model)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 3)
	v.apply(1.0, &"fresh", false, false)
	for m: Node in meshes:
		assert_null((m as MeshInstance3D).material_overlay, "fresh: no overlay draw call")
	v.apply(0.2, &"decaying", false, false)
	for m: Node in meshes:
		var mesh := m as MeshInstance3D
		assert_eq(mesh.material_overlay.resource_path, OVERLAY, "shared overlay material")
		assert_almost(float(mesh.get_instance_shader_parameter(&"amount")), 0.7, 0.0001, "instance uniform amount")
	var other := Node3D.new()
	made.append(other)
	v.set_target(other)
	for m: Node in meshes:
		assert_null((m as MeshInstance3D).material_overlay, "old model loses the overlay")


# --- particles -----------------------------------------------------------------------------

func test_particle_counts_per_stage() -> void:
	var v := _visual()
	var expect := {&"fresh": [0, 0], &"wilted": [4, 0], &"decaying": [8, 3], &"rotten": [10, 5]}
	var fresh := {&"fresh": 0.9, &"wilted": 0.45, &"decaying": 0.2, &"rotten": 0.05}
	for stage: StringName in STAGES:
		v.apply(fresh[stage], stage, false, false)
		assert_eq([v.flies(), v.wisps(), v.smoke_on()], [expect[stage][0], expect[stage][1], false], String(stage))
		assert_eq(v.flies_node.emitting, expect[stage][0] > 0, "%s flies emitting" % stage)
		if expect[stage][0] > 0:
			assert_eq(v.flies_node.amount, expect[stage][0])
		assert_eq(v.wisps_node.emitting, expect[stage][1] > 0, "%s wisps emitting" % stage)
		if expect[stage][1] > 0:
			assert_eq(v.wisps_node.amount, expect[stage][1])
		assert_false(v.smoke_node.emitting)
	v.apply(1.0, &"fresh", false, false)
	assert_false(v.is_emitting(), "fresh: no emitter slot")
	assert_eq(v.live_particles(), 0)
	for p: CPUParticles3D in [v.flies_node, v.wisps_node, v.smoke_node]:
		assert_false(p.visible)
		assert_eq(p.process_mode, Node.PROCESS_MODE_DISABLED, "hidden emitters are not processed")


func test_balm_replaces_wisps_by_juniper_smoke() -> void:
	var v := _visual()
	v.apply(0.05, &"rotten", true, false)
	assert_eq(v.wisps(), 0, "no smell wisps during a balm window")
	assert_true(v.smoke_on())
	assert_eq(v.flies(), 10, "flies stay")
	assert_true(v.smoke_node.emitting)
	assert_eq(v.smoke_node.amount, cfg.smoke_particles)
	assert_false(v.wisps_node.emitting)
	v.apply(0.9, &"fresh", true, false)
	assert_true(v.smoke_on(), "smoke also over a fresh corpse")
	assert_true(v.is_emitting())
	assert_eq(v.live_particles(), 3)
	v.apply(0.05, &"rotten", false, false)
	assert_false(v.smoke_on())
	assert_false(v.smoke_node.emitting)
	assert_eq(v.wisps(), 5)


func test_at_most_three_corpses_emit_and_the_budget_holds() -> void:
	var list: Array[CorpseDecayVisual] = []
	for i: int in 5:
		var v := _visual()
		v.apply(0.05, &"rotten", false, false)
		list.append(v)
	var emitting := list.filter(func(v: CorpseDecayVisual) -> bool: return v.is_emitting())
	assert_eq(emitting.size(), cfg.max_emitting, "max_emitting")
	assert_eq(list[3].live_particles(), 0, "the fourth waits")
	assert_true(list[3].wants_to_emit())
	assert_true(CorpseDecayVisual.total_live_particles() <= 60, "§9 ≤ 60 particles")
	assert_eq(CorpseDecayVisual.total_live_particles(), 3 * 15)
	# One stops (fresh) → the first waiting one takes over; a freed one frees its slot too.
	list[0].apply(1.0, &"fresh", false, false)
	assert_true(list[3].is_emitting(), "waiting visual takes the free slot")
	assert_eq(list[3].live_particles(), 15)
	list[1].free()
	assert_true(list[4].is_emitting(), "freed visual releases its slot")
	for v: CorpseDecayVisual in [list[2], list[3], list[4]]:
		v.apply(0.05, &"rotten", true, false)
	assert_true(CorpseDecayVisual.total_live_particles() <= 60)


func test_emitters_are_billboard_unshaded_without_shadows() -> void:
	var v := _visual()
	# The injected config (colours, visibility range) applies with the first apply() – the
	# emitters are built in _init from data/config (QA W3: the data may deviate from the fixture).
	v.apply(0.05, &"rotten", false, false)
	for p: CPUParticles3D in [v.flies_node, v.wisps_node, v.smoke_node]:
		assert_eq(p.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, p.name)
		assert_almost(p.visibility_range_end, cfg.visibility_range, 0.001, p.name + " visibility range")
		assert_true(p.local_coords, p.name + " follows the corpse")
		var mat := (p.mesh as QuadMesh).material as StandardMaterial3D
		assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, p.name)
		assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES, p.name)
		assert_ne(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, p.name)
	for p: CPUParticles3D in [v.wisps_node, v.smoke_node]:
		var size := (p.mesh as QuadMesh).size
		assert_true(size.x <= 0.6 and size.y <= 0.6, "§9 wisp ≤ 0.6 × 0.6 m")
		for c: Color in p.color_ramp.colors:
			assert_true(c.a <= 0.35, "§9 alpha ≤ 0.35")
	var wisp_rgb := v.wisps_node.color_ramp.colors[1]
	assert_true(wisp_rgb.is_equal_approx(cfg.wisp_color), "wisp colour from the config")
	assert_true(v.smoke_node.color_ramp.colors[1].is_equal_approx(cfg.smoke_color), "smoke colour from the config")


# --- shader + materials --------------------------------------------------------------------

func test_overlay_shader_contract() -> void:
	var shader := load(SHADER) as Shader
	assert_not_null(shader)
	var code := shader.code
	for token: String in ["blend_mul", "unshaded", "painted_common.gdshaderinc", "instance uniform float amount",
			"uniform vec4 stain_color", "patch_noise", "brush_noise"]:
		assert_true(code.contains(token), token)
	for path: String in [SHADER]:
		for line: String in (load(path) as Shader).code.split("\n"):
			assert_false(line.get_slice("//", 0).contains("TIME"), "no TIME (PERF-01): " + line)
	var mat := load(OVERLAY) as ShaderMaterial
	assert_eq(mat.shader, shader)
	assert_not_null(mat.get_shader_parameter(&"brush_noise"))
	assert_not_null(mat.get_shader_parameter(&"patch_noise"))
	assert_true((mat.get_shader_parameter(&"stain_color") as Color).is_equal_approx(cfg.stain_color), "stain colour = config")
	for path: String in VFX:
		var m := load(path) as StandardMaterial3D
		assert_not_null(m, path)
		assert_eq(m.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, path)
		assert_true(m.vertex_color_use_as_albedo, path + " colour ramp")
		assert_not_null(m.albedo_texture, path)


func test_painted_shaders_untouched() -> void:
	# ART STYLE LOCK: the overlay only reads painted_common; the painted shader keeps no overlay code.
	var painted := (load("res://assets/shaders/painted.gdshader") as Shader).code
	assert_false(painted.contains("amount"), "painted.gdshader unchanged")
	assert_false(painted.contains("decay"))


# --- Corpse --------------------------------------------------------------------------------

func test_corpse_scene_has_decay_visual_and_rotten_stage() -> void:
	var packed := load(CORPSE_SCENE) as PackedScene
	var node := packed.instantiate() as Corpse
	made.append(node)
	assert_true(node.get_node_or_null(^"DecayVisual") is CorpseDecayVisual, "child DecayVisual")
	assert_eq(Corpse.stage_of(0.9, economy), &"fresh")
	assert_eq(Corpse.stage_of(0.45, economy), &"wilted")
	assert_eq(Corpse.stage_of(0.2, economy), &"decaying")
	assert_eq(Corpse.stage_of(0.1, economy), &"decaying", "rot_threshold itself is still decaying")
	assert_eq(Corpse.stage_of(0.09, economy), &"rotten")


func test_corpse_refresh_drives_the_decay_visual() -> void:
	var setup := await _corpse_world()
	var node: Corpse = setup[0]
	var rec: CorpseRecord = setup[1]
	var visual := node.decay_visual
	assert_eq(visual.flies(), 0, "fresh")
	assert_eq(visual.target, node.get_node(^"Model"), "overlay target = model")
	rec.freshness = 0.2
	EventBus.hour_changed.emit(3, 22)
	assert_eq([visual.flies(), visual.wisps()], [8, 3], "hour_changed → decaying")
	var meshes := node.get_node(^"Model").find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0)
	assert_eq((meshes[0] as MeshInstance3D).material_overlay.resource_path, OVERLAY)
	rec.freshness = 0.02
	EventBus.time_skipped.emit(0, 600)
	assert_eq([visual.flies(), visual.wisps()], [10, 5], "time_skipped → rotten")
	rec.washed = true
	EventBus.corpse_updated.emit(rec.id)
	assert_almost(visual.overlay_amount(), 1.0 - cfg.washed_reduction, 0.0001, "washed")


func test_corpse_dress_and_lay_out_models() -> void:
	var setup := await _corpse_world()
	var node: Corpse = setup[0]
	var rec: CorpseRecord = setup[1]
	assert_eq(node.dress_visual(), &"")
	assert_false(node.is_laid_out_visual())
	rec.dress = &"gown"
	rec.shrouded = true
	rec.freshness = 0.2
	EventBus.corpse_updated.emit(rec.id)
	assert_eq(node.dress_visual(), &"gown")
	assert_true(node.is_shrouded_visual())
	var model := node.get_node(^"Model")
	var gown := ResourceLoader.exists(Corpse.GOWN_MODEL_PATH)
	assert_eq(model.scene_file_path, Corpse.GOWN_MODEL_PATH if gown else SHROUDED, "gown model (or shroud until P5)")
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	assert_eq((meshes[0] as MeshInstance3D).material_overlay.resource_path, OVERLAY, "overlay moves to the new model")
	rec.laid_out = true
	EventBus.corpse_updated.emit(rec.id)
	assert_true(node.is_laid_out_visual())
	var layout := node.get_node(^"LayOut") as Node3D
	assert_not_null(layout)
	if not ResourceLoader.exists(Corpse.SPRIG_MODEL_PATH):
		var ph := layout.get_node(NodePath(LayoutPlaceholderMesh.NAME)) as MeshInstance3D
		assert_not_null(ph, "placeholder sprig + candle stub")
		assert_true(ph.mesh.get_aabb().size.x < 0.4, "small, on the chest")
	assert_eq(layout.find_children("*", "Light3D", true, false).size(), 0, "candle stub without light")
	rec.dress = &"shroud"
	EventBus.corpse_updated.emit(rec.id)
	assert_eq(node.get_node(^"Model").scene_file_path, SHROUDED)
	assert_true(node.is_laid_out_visual(), "sprig stays")
	rec.laid_out = false
	EventBus.corpse_updated.emit(rec.id)
	await wait_frames(1)
	assert_false(node.is_laid_out_visual())
	assert_null(node.get_node_or_null(^"LayOut"))


func test_dress_of_phase2_records_and_story_look_fallback() -> void:
	var r := CorpseRecord.new()
	assert_eq(Corpse.dress_of(r), &"")
	r.shrouded = true
	assert_eq(Corpse.dress_of(r), &"shroud", "Phase-2/3 record: shrouded only")
	r.dress = &"gown"
	assert_eq(Corpse.dress_of(r), &"gown")
	assert_eq(Corpse.dress_of(null), &"")
	var node := (load(CORPSE_SCENE) as PackedScene).instantiate() as Corpse
	made.append(node)
	for look: int in Corpse.STORY_LOOK_PATHS:
		var scene: PackedScene = node._plain_scene(look)
		if ResourceLoader.exists(Corpse.STORY_LOOK_PATHS[look]):
			assert_eq(scene.resource_path, Corpse.STORY_LOOK_PATHS[look])
		else:
			assert_eq(scene, node.plain_variants[Corpse.STORY_LOOK_FALLBACK[look]], "look %d falls back until P5" % look)


# --- helpers -------------------------------------------------------------------------------

func _visual() -> CorpseDecayVisual:
	var v := CorpseDecayVisual.new()
	v.config = cfg
	v.economy = economy
	made.append(v)
	return v


## [Corpse, CorpseRecord] – a corpse node in a world with a CorpseManager double.
func _corpse_world() -> Array:
	var world := Node3D.new()
	made.append(world)
	var manager := CorpsesDouble.new()
	manager.economy = economy
	world.add_child(manager)
	var rec := CorpseRecord.new()
	rec.id = "corpse_t1"
	rec.display_name = "Ulrich Moor"
	rec.age = 30
	rec.freshness = 0.9
	rec.location = CorpseRecord.LOCATION_GROUND
	manager.recs[rec.id] = rec
	var node := (load(CORPSE_SCENE) as PackedScene).instantiate() as Corpse
	node.corpse_id = rec.id
	node.get_node(^"DecayVisual").set(&"config", cfg)
	world.add_child(node)
	tree.root.add_child(world)
	await wait_frames(1)
	return [node, rec]
