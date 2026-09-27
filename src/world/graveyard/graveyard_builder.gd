extends SceneTree
## Generates the vertical-slice world graveyard.tscn (+ grass.scn) from
## data/world/graveyard_layout.json (docs/VERTICAL_SLICE_DESIGN.md §4). Needs a real renderer
## (headless drops MultiMesh data):
##   tools/godot_run.sh -s res://src/world/graveyard/graveyard_builder.gd
## Re-running overwrites graveyard.tscn, grass.scn and ground_shape.res. Tune the layout
## (shared with Blender), not the scene.
## Patterns of the frozen art_prototype_builder.gd: ground height lookup from the painted
## ground mesh, OmniLights at light_* markers (layout "lights"), persistent groups.
## This script assembles the world tree; the parts live in preloaded helpers next to it
## (graveyard_build_*.gd): context (layout, ground heights, placing), colliders, entities,
## decor, grass and the Phase-3 parts (systems, obstacles, tending spots, notice board, birches,
## build mask – docs/PHASE3_DESIGN.md §4).

## Helper scripts are preloaded (no class_name) – see the autoload note below.
const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const Entities := preload("res://src/world/graveyard/graveyard_build_entities.gd")
const Decor := preload("res://src/world/graveyard/graveyard_build_decor.gd")
const Grass := preload("res://src/world/graveyard/graveyard_build_grass.gd")
const Phase3 := preload("res://src/world/graveyard/graveyard_build_phase3.gd")
const InteriorBuild := preload("res://src/world/hut_interior/hut_interior_build.gd")
const InteriorBuilder := preload("res://src/world/hut_interior/hut_interior_builder.gd")
const LAYOUT_PATH := "res://data/world/graveyard_layout.json"
const OUT_SCENE := "res://src/world/graveyard/graveyard.tscn"
const OUT_GRASS := Grass.OUT_GRASS
const OUT_GROUND_SHAPE := Colliders.OUT_GROUND_SHAPE
const GROUND_ASSET := Ctx.GROUND_ASSET
const WORLD_SCRIPT := "res://src/world/graveyard/world_root.gd"
## Scripts are loaded by path: while this -s script compiles the autoloads (EventBus, …) are
## no globals yet, so classes that use them must not be referenced by class_name here.
const CORPSE_MANAGER_SCRIPT := "res://src/systems/corpse/corpse_manager.gd"
const GRAVEYARD_SCRIPT := "res://src/systems/graveyard/graveyard.gd"
const ATMOSPHERE_SCRIPT := "res://src/world/atmosphere/atmosphere_controller.gd"
const CAMERA_SCRIPT := "res://src/world/camera/camera_rig.gd"
const SHADOW_GOVERNOR_SCRIPT := "res://src/world/graveyard/warm_shadow_governor.gd"
const CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const UI_SCENE := "res://src/ui/ui_root.tscn"
const PRESET_PATH := "res://data/atmosphere/%s.tres"

## Build state shared with the helpers (layout, scene root, ground heights, colliders).
var _ctx := Ctx.new(self)
var layout: Dictionary:
	get:
		return _ctx.layout
	set(value):
		_ctx.layout = value
var scene_root: Node3D:
	get:
		return _ctx.scene_root
	set(value):
		_ctx.scene_root = value


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads (Database) are ready after the first frame
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_ctx.cell = float(layout.ground.cell)
	_ctx.build_height_lookup()
	Phase3.bake_mask(_ctx)
	Grass.save(Grass.build(_ctx))
	InteriorBuilder.save_scene(InteriorBuild.build(InteriorBuild.load_layout()))
	_save(_build_world(), OUT_SCENE)
	print("BUILD OK")
	quit()


func ground_height(p: Vector2) -> float:
	return _ctx.ground_height(p)


func _save(node: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(node)
	assert(err == OK, "pack failed: %s" % path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed: %s" % path)
	print("  saved ", path)
	node.free()


# --- world -------------------------------------------------------------------

func _build_world() -> Node:
	scene_root = Node3D.new()
	scene_root.name = "Graveyard"
	scene_root.set_script(load(WORLD_SCRIPT))
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = _make_environment()
	_ctx.add(scene_root, env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 1.2
	# One cascade: the fixed 45° camera sees nothing nearer than ~10 m (zoom_min), so the first
	# of the prototype's two splits (0.5–6 m) stayed empty and wasted half the atlas (PERF-03).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 55.0
	_ctx.add(scene_root, sun)
	_ctx.add(scene_root, _build_atmosphere(env_node, sun))
	var governor: Node = load(SHADOW_GOVERNOR_SCRIPT).new()
	governor.name = "WarmShadows"
	governor.set("min_scale", float(layout.atmosphere.shadow_min_warm_scale))
	_ctx.add(scene_root, governor)

	# (WorldRoot switches the ground's shadow casting off at runtime – see world_root.gd.)
	_ctx.place(GROUND_ASSET, scene_root, Vector2.ZERO, 0.0, "Ground").transform = Transform3D.IDENTITY
	Colliders.build_ground_collision(_ctx)
	_ctx.colliders = _ctx.group(scene_root, "Colliders")

	var systems := _ctx.group(scene_root, "Systems")
	var manager: Node = load(CORPSE_MANAGER_SCRIPT).new()
	manager.name = "CorpseManager"
	manager.set("corpse_scene", load(CORPSE_SCENE))
	manager.set("container_path", NodePath("../../Corpses"))
	_ctx.add(systems, manager)
	var graveyard: Node = load(GRAVEYARD_SCRIPT).new()
	graveyard.name = "Graveyard"
	_ctx.add(systems, graveyard)

	var entities := _ctx.group(scene_root, "Entities")
	for plot: Dictionary in layout.plots:
		Entities.build_plot(_ctx, entities, plot, false)
	for ent: Dictionary in layout.entities:
		Entities.build_entity(_ctx, entities, ent)
	Phase3.build_obstacles(_ctx, entities)
	Phase3.build_dirt_spots(_ctx, entities)
	Phase3.build_notice_board(_ctx, entities)

	var decor := _ctx.group(scene_root, "Decor")
	var old := _ctx.group(decor, "OldGraves")
	for g: Dictionary in layout.old_graves:
		Entities.build_plot(_ctx, old, g, true)
	Decor.build_decor(_ctx, decor)
	Phase3.build_birches(_ctx, decor)
	Phase3.build_overgrowth(_ctx, decor)
	Phase3.build_passages(_ctx, decor.get_node("Fence"))
	Phase3.build_systems(_ctx, systems, decor)

	Entities.build_waypoints(_ctx, _ctx.group(scene_root, "Waypoints"))
	_ctx.group(scene_root, "Corpses")

	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	player.name = "Player"
	player.transform = _ctx.ground_xform(Ctx.v2(layout.player_start.pos), float(layout.player_start.rot_y))
	_ctx.add(scene_root, player)
	_build_camera(player)
	_build_interior()
	var ui := (load(UI_SCENE) as PackedScene).instantiate()
	ui.name = "UI"
	_ctx.add(scene_root, ui)
	Colliders.build_bounds(_ctx)
	print("  colliders: ", _ctx.collider_count)
	return scene_root


func _build_atmosphere(env_node: WorldEnvironment, sun: DirectionalLight3D) -> Node:
	var cfg: Dictionary = layout.atmosphere
	var atmo: Node = load(ATMOSPHERE_SCRIPT).new()
	atmo.name = "Atmosphere"
	var presets: Array[AtmospherePreset] = []
	for id: String in cfg.presets:
		presets.append(load(PRESET_PATH % id))
	var blend: Array[AtmospherePreset] = []
	for id: String in cfg.blend_presets:
		blend.append(load(PRESET_PATH % id))
	atmo.set("presets", presets)
	atmo.set("blend_presets", blend)
	atmo.set("blend_minutes", PackedInt32Array(cfg.blend_minutes))
	atmo.set("time_driven", true)
	atmo.set("world_environment", env_node)
	atmo.set("sun", sun)
	return atmo


func _build_camera(player: Node3D) -> void:
	var cfg: Dictionary = layout.camera_bounds
	var rig: Node3D = load(CAMERA_SCRIPT).new()
	rig.name = "CameraRig"
	rig.set("distance", float(cfg.distance))
	rig.set("zoom_min", float(cfg.zoom_min))
	rig.set("zoom_max", float(cfg.zoom_max))
	rig.set("bounds_enabled", true)
	rig.set("bounds_min", Ctx.v2(cfg.min))
	rig.set("bounds_max", Ctx.v2(cfg.max))
	_ctx.add(scene_root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	_ctx.add(rig, cam)
	rig.set("target", player)


## The hut interior scene (§11) far from the graveyard; it swaps the camera profile and suns.
func _build_interior() -> void:
	var interior := (load(InteriorBuilder.OUT_SCENE) as PackedScene).instantiate() as Node3D
	interior.name = "HutInterior"
	interior.position = Ctx.v3(layout.hut_interior.origin)
	interior.set("camera_rig_path", NodePath("../CameraRig"))
	interior.set("outdoor_sun_path", NodePath("../Sun"))
	_ctx.add(scene_root, interior)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.5
	env.fog_height = 0.4
	env.fog_height_density = 0.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_anisotropy = 0.3
	env.adjustment_enabled = true
	return env
