extends SceneTree
## QA (W3) readability check of the tending spots from the gameplay camera: a new game, UI
## hidden, noon; one row of DirtSpot nodes (weeds 1–3, leaves 1–3) on the yard grass, framed
## by the CameraRig at its default gameplay distance. Needs a real renderer:
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://tools/qa/qa_weeds_shot.gd -- --out=/abs/file.png
##       [--distance=18] [--focus=x,z]

const ROW := [[&"weeds", 1], [&"weeds", 2], [&"weeds", 3], [&"leaves", 1], [&"leaves", 2], [&"leaves", 3]]
const SPACING := 1.7
const SETTLE_FRAMES := 40
## Layout spots of the right kind (weeds of the Ostwiese, leaves of the yard) used for the row.
const REAL_SPOTS: PackedStringArray = ["dirt_e01", "dirt_e02", "dirt_e03", "dirt_y09", "dirt_y10", "dirt_y11"]

var _out := ""
var _distance := 18.0
var _focus := Vector2(16.4, 2.6)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--distance="):
			_distance = float(arg.trim_prefix("--distance="))
		elif arg.begins_with("--focus="):
			var p := arg.trim_prefix("--focus=").split(",")
			_focus = Vector2(float(p[0]), float(p[1]))
	var saves := root.get_node(^"SaveManager")
	saves.set("save_dir", "user://qa_shot_saves")
	saves.call(&"new_game")
	await Signal(root.get_node(^"EventBus"), &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	root.get_node(^"TimeManager").call(&"load_state", {"day": 1, "minute_of_day": 720})
	(world.get_node(^"UI") as CanvasLayer).visible = false
	# Open lawn: the Ostwiese once it is cleared (no graves or paths behind the row).
	world.get_node(^"Systems/Expansion").call(&"unlock", &"east")
	var player := world.get_node(^"Player") as Node3D
	player.global_position = Vector3(_focus.x + 4.0, 0.0, _focus.y - 3.0)
	# Real tending spots of the layout moved into one row (so the CleanlinessManager levels, the
	# grass-clear mask and every other system see them as in the game).
	var spots := {}
	for i: int in ROW.size():
		var spot := world.get_node(NodePath("Entities/" + REAL_SPOTS[i])) as Node3D
		var x := _focus.x + (i - (ROW.size() - 1) * 0.5) * SPACING
		spot.global_position = Vector3(x, float(world.call(&"ground_height", Vector2(x, _focus.y))), _focus.y)
		spots[REAL_SPOTS[i]] = float(ROW[i][1]) + 0.5
	var clean := world.get_node(^"Systems/Cleanliness")
	clean.call(&"load_state", {"spots": spots})
	world.get_node(^"Systems/GrassClearMask").call(&"repaint")
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = Vector3(_focus.x, 0.0, _focus.y)
	rig.set("target", anchor)
	rig.call(&"set_distance", _distance)
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await process_frame
	root.get_texture().get_image().save_png(_out)
	print("[QaWeeds] saved ", _out)
	quit()
