extends SceneTree
## QA tool: renders every model in res://assets/models/ from a 3/4 front view.
##   tools/godot_run.sh --resolution 512x512 -s res://src/debug/asset_preview.gd -- --out=<dir> [--filter=<text>]

var _out: String = ""
var _filter: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.52)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.66, 0.75)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	stage.add_child(cam)
	for path: String in _models():
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		stage.add_child(inst)
		var aabb := _aabb(inst)
		var center := aabb.get_center()
		var radius := aabb.size.length() * 0.5
		var dir := Vector3(0.55, 0.45, 1.0).normalized()
		cam.position = center + dir * radius / tan(deg_to_rad(15.0)) * 1.05
		cam.look_at(center)
		for i: int in 8:
			await process_frame
		var file := _out.path_join(path.get_file().get_basename() + ".png")
		root.get_viewport().get_texture().get_image().save_png(file)
		print("[Preview] ", file, "  size=", aabb.size)
		inst.queue_free()
		await process_frame
	quit()


func _models() -> PackedStringArray:
	var result: PackedStringArray = []
	for cat: String in DirAccess.get_directories_at("res://assets/models"):
		for f: String in DirAccess.get_files_at("res://assets/models/" + cat):
			if f.ends_with(".glb") and (_filter == "" or f.contains(_filter)):
				result.append("res://assets/models/%s/%s" % [cat, f])
	return result


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
