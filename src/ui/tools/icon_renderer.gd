extends SceneTree
## Renders the item models to UI icons: res://assets/ui/icons/<id>.png (128×128, transparent,
## same 3/4 camera and lighting for all). Needs a real renderer:
##   GODOT=<godot> tools/godot_run.sh -s res://src/ui/tools/icon_renderer.gd [-- --filter=<id>]
## then: godot --headless --path . --import

const OUT_DIR := "res://assets/ui/icons"
const ICON_SIZE := 128
## Rendered larger, then downscaled (smooth edges).
const RENDER_SCALE := 3
const SETTLE_FRAMES := 12
const FOV := 24.0
## Share of the frame the model's projected bounds may fill.
const FILL := 0.92
const FIT_ITERATIONS := 4
## Camera direction (3/4 view from the front right, looking down ~32°).
const VIEW_DIR := Vector3(0.62, 0.62, 1.0)
const MODELS: Dictionary[StringName, String] = {
	&"coin": "res://assets/models/items/ph_item_coin.glb",
	&"wood": "res://assets/models/items/ph_item_log.glb",
	&"stone": "res://assets/models/items/ph_item_stone.glb",
	&"linen": "res://assets/models/items/ph_item_linen.glb",
	&"shroud": "res://assets/models/items/ph_item_shroud.glb",
	&"wooden_cross": "res://assets/models/props/ph_prop_cross_wood.glb",
	&"gravestone_simple": "res://assets/models/props/ph_prop_gravestone_round.glb",
	# Phase 3 (docs/PHASE3_DESIGN.md §8: decor icons from the models).
	&"iron_fittings": "res://assets/models/items/ph_item_iron_fittings.glb",
	&"seeds": "res://assets/models/items/ph_item_seeds.glb",
	&"rake": "res://assets/models/items/ph_item_rake.glb",
	&"decor_bench_wood": "res://assets/models/decor/ph_deco_bench_wood.glb",
	&"decor_bench_stone": "res://assets/models/decor/ph_deco_bench_stone.glb",
	&"decor_flowerbed": "res://assets/models/decor/ph_deco_flowerbed.glb",
	&"decor_grave_vase": "res://assets/models/decor/ph_deco_grave_vase.glb",
	&"decor_lantern": "res://assets/models/decor/ph_deco_lantern_small.glb",
	&"decor_path_gravel": "res://assets/models/decor/ph_deco_path_gravel.glb",
}

var _filter: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE) * RENDER_SCALE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_add_lighting(viewport)
	var cam := Camera3D.new()
	cam.fov = FOV
	viewport.add_child(cam)
	var failures := 0
	for id: StringName in MODELS:
		if _filter != "" and not String(id).contains(_filter):
			continue
		var scene := load(MODELS[id]) as PackedScene
		if scene == null:
			push_error("[IconRenderer] missing model for %s: %s" % [id, MODELS[id]])
			failures += 1
			continue
		var model := scene.instantiate() as Node3D
		viewport.add_child(model)
		_frame(cam, _aabb(model))
		for i: int in SETTLE_FRAMES:
			await process_frame
		var img := viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(OUT_DIR.path_join(String(id) + ".png"))
		var err := img.save_png(path)
		print("[IconRenderer] %s -> %s (%s)" % [id, path, error_string(err)])
		if err != OK:
			failures += 1
		model.queue_free()
		await process_frame
	quit(1 if failures > 0 else 0)


## Key (warm, upper left), fill (cool, right) and rim (behind) – readable on dark UI.
func _add_lighting(viewport: SubViewport) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.6
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 70.0, 0.0)
	fill.light_color = Color(0.7, 0.78, 0.9)
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 160.0, 0.0)
	rim.light_color = Color(1.0, 0.86, 0.62)
	rim.light_energy = 0.9
	viewport.add_child(rim)


## Places the camera along VIEW_DIR so the projected bounds fill FILL of the frame.
func _frame(cam: Camera3D, box: AABB) -> void:
	var center := box.get_center()
	var dir := VIEW_DIR.normalized()
	var distance := box.size.length() / tan(deg_to_rad(FOV * 0.5))
	for i: int in FIT_ITERATIONS:
		cam.look_at_from_position(center + dir * distance, center, Vector3.UP)
		var extent := 0.0
		var view := cam.global_transform.affine_inverse()
		for corner: int in 8:
			var p := view * box.get_endpoint(corner)
			var depth := maxf(-p.z, 0.001)
			extent = maxf(extent, maxf(absf(p.x), absf(p.y)) / depth)
		var wanted := tan(deg_to_rad(FOV * 0.5)) * FILL
		distance *= extent / wanted
	cam.look_at_from_position(center + dir * distance, center, Vector3.UP)
	cam.near = maxf(distance * 0.05, 0.01)
	cam.far = distance * 4.0 + box.size.length()


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var b := mesh.global_transform * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
