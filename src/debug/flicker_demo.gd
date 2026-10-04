extends SceneTree
## G7 round 1: a short frame series of the fire flicker (FlickerLight, flame glow, embers) – one room
## standalone at night, the camera close on a fire. Needs a real renderer:
##   tools/godot_run.sh --resolution 960x540 -s res://src/debug/flicker_demo.gd -- --out=/abs/dir \
##       [--room=inn] [--frames=6] [--step=0.12]
## Writes <out>/flicker_<room>_<k>.jpg and prints the stove / candle light energy per frame.

const SHOTS := {
	"inn": {"eye": Vector3(1.6, 1.7, 0.6), "at": Vector3(3.2, 0.7, -1.8)},
	"office": {"eye": Vector3(-1.3, 1.5, -0.4), "at": Vector3(-1.1, 0.85, -1.3)},
	"church": {"eye": Vector3(0.9, 1.6, -1.4), "at": Vector3(0.0, 1.2, -3.8)},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out := ""
	var room_id := "inn"
	var frames := 6
	var step := 0.12
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--room="):
			room_id = arg.trim_prefix("--room=")
		elif arg.begins_with("--frames="):
			frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--step="):
			step = float(arg.trim_prefix("--step="))
	if out == "" or not SHOTS.has(room_id):
		printerr("usage: -- --out=/abs/dir [--room=inn|office|church] [--frames=6] [--step=0.12]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var room := (load("res://src/world/interiors/%s_interior.tscn" % room_id) as PackedScene).instantiate() as Node3D
	root.add_child(room)
	await process_frame
	room.call(&"apply_room", StringName(room_id))
	var lighting := room.get_node(^"Lighting")
	lighting.set_process(false)
	lighting.call(&"apply_daylight", 0.0)
	var cam := Camera3D.new()
	cam.environment = room.get(&"environment")
	cam.fov = 40.0
	root.add_child(cam)
	cam.global_position = room.global_transform * (SHOTS[room_id].eye as Vector3)
	cam.look_at(room.global_transform * (SHOTS[room_id].at as Vector3), Vector3.UP)
	cam.current = true
	for i: int in 30:
		await process_frame
	var fires := room.find_children("*", "Light3D", true, false).filter(func(n: Node) -> bool: return n is FlickerLight)
	for k: int in frames:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(step * 1000.0):
			await process_frame
		var img := root.get_texture().get_image()
		img.save_jpg(out.path_join("flicker_%s_%d.jpg" % [room_id, k + 1]), 0.88)
		var energies: PackedStringArray = []
		for l: Light3D in fires:
			energies.append("%s %.2f" % [l.name, l.light_energy])
		print("[flicker] %s frame %d: %s" % [room_id, k + 1, ", ".join(energies)])
	quit()
