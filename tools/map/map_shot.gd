extends SceneTree
## Screenshot of the map (both sheets) in the running slice – checks the baked sheet looks like the
## directly painted one (G7 Runde 2). Needs a renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://tools/map/map_shot.gd -- --out=/abs/dir


func _initialize() -> void:
	var out := "user://map_shots"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred(out)


func _wait(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _ui() -> Node:
	for n: Node in root.find_children("*", "", true, false):
		var sc: Script = n.get_script() as Script
		if sc != null and sc.get_global_name() == &"UIRoot":
			return n
	return null


func _shot(path: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_jpg(path, 0.9)
	print("[MapShot] ", path)


func _run(out: String) -> void:
	root.get_node(^"SaveManager").call(&"new_game")
	await _wait(14.0)
	root.get_node(^"Debug").call(&"execute", "village open")
	var ui := _ui()
	ui.call(&"open_map")
	await _wait(3.0)
	await _shot(out.path_join("map_friedhof.jpg"))
	var panel: Node = ui.call(&"get_panel", &"map")
	panel.call(&"show_region", &"village")
	await _wait(3.0)
	await _shot(out.path_join("map_dorf.jpg"))
	quit(0)
