extends SceneTree
## QA screenshot series of the vertical-slice world (W1 visual review). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd \
##       -- --out=/abs/dir [--shots=01,03]
## Starts a new game (saves go to user://shot_saves), stages the world through the real
## systems (corpse on the table, open pit, finished graves), then per shot sets the clock
## silently, frames the camera and writes <out>/<name>.png plus render_stats.txt.
## Autoloads are looked up by node path (they are no globals while this script compiles).

const SETTLE_FRAMES := 40
const SHOT_SAVE_DIR := "user://shot_saves"
const ZOOM_MAX := 40.0

## name, minute of day, camera focus (x, z), camera distance.
const SHOTS: Array[Dictionary] = [
	{"name": "01_day_overview", "minute": 660, "focus": Vector2(0.5, 0.5), "distance": 30.0},
	{"name": "02_day_kutschweg", "minute": 660, "focus": Vector2(3.5, 20.5), "distance": 26.0},
	{"name": "03_carter_arrival", "minute": 455, "focus": Vector2(1.6, 11.0), "distance": 16.0},
	{"name": "04_morgue_table", "minute": 570, "focus": Vector2(-1.6, -5.4), "distance": 11.0},
	{"name": "05_open_pit", "minute": 600, "focus": Vector2(4.2, 5.0), "distance": 11.0},
	{"name": "06_grave_cross", "minute": 640, "focus": Vector2(6.6, 5.1), "distance": 11.0},
	{"name": "07_night_hut", "minute": 1350, "focus": Vector2(-2.5, -4.0), "distance": 22.0},
	{"name": "08_night_gate", "minute": 1240, "focus": Vector2(-0.5, 9.8), "distance": 16.0},
]

var _out: String = ""
var _only: PackedStringArray = []
## --no-grass: hides the grass; --distance=<m>: overrides every camera distance (budget checks).
var _no_grass: bool = false
var _distance: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--no-grass":
			_no_grass = true
		elif arg.begins_with("--distance="):
			_distance = arg.trim_prefix("--distance=").to_float()
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=01,02]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	var bus := root.get_node(^"EventBus")
	saves.set("save_dir", SHOT_SAVE_DIR)
	saves.call(&"new_game")
	await Signal(bus, &"new_game_started")
	await process_frame  # new_game() starts the clock right after new_game_started
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	(world.get_node(^"Decor/Grass") as Node3D).visible = not _no_grass
	_stage(world)
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ShotAnchor"
	world.add_child(anchor)
	rig.set("target", anchor)
	rig.set("zoom_max", ZOOM_MAX)
	var report: PackedStringArray = []
	for shot: Dictionary in SHOTS:
		if not _only.is_empty() and not String(shot.name).left(2) in _only:
			continue
		clock.call(&"load_state", {"day": 1, "minute_of_day": shot.minute})
		var focus: Vector2 = shot.focus
		anchor.global_position = Vector3(focus.x, 0.0, focus.y)
		rig.call(&"set_distance", _distance if _distance > 0.0 else float(shot.distance))
		rig.call(&"snap")
		for i: int in SETTLE_FRAMES:
			await process_frame
		var path := _out.path_join("%s.png" % shot.name)
		root.get_texture().get_image().save_png(path)
		var npc := world.get_node(^"Entities/npc_carter") as Node3D
		var primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var grass := _visible_grass_triangles(world)
		var info := "%s  draw_calls=%d  objects=%d  primitives=%d  grass_tris=%d  total≈%d  carter=%s visible=%s" % [
			shot.name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			primitives, grass, primitives + grass, npc.global_position, npc.visible]
		print("[Shots] ", info)
		report.append(info)
	var f := FileAccess.open(_out.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


## The primitive counter counts one tuft per MultiMesh draw: add the instances of every grass
## chunk inside the camera frustum (tuft triangles × instances).
func _visible_grass_triangles(world: Node3D) -> int:
	var grass := world.get_node(^"Decor/Grass") as Node3D
	if not grass.visible:
		return 0
	var planes := root.get_camera_3d().get_frustum()
	var total := 0
	for chunk: Node in grass.get_children():
		var mmi := chunk as MultiMeshInstance3D
		var aabb := mmi.global_transform * mmi.multimesh.get_aabb()
		if _in_frustum(aabb, planes):
			total += mmi.multimesh.instance_count * (mmi.multimesh.mesh.get_faces().size() / 3)
	return total


func _in_frustum(aabb: AABB, planes: Array[Plane]) -> bool:
	for plane: Plane in planes:
		var inside := false
		for i: int in 8:
			if not plane.is_point_over(aabb.get_endpoint(i)):
				inside = true
				break
		if not inside:
			return false
	return true


## Real systems only: a corpse on the table, an open pit, a grave with cross and one with stone.
func _stage(world: Node3D) -> void:
	var manager := world.get_node(^"Systems/CorpseManager")
	var graveyard := world.get_node(^"Systems/Graveyard")
	var table := world.get_node(^"Entities/morgue_table")
	var player := world.get_node(^"Player") as Node3D
	var inv: Node = player.get_node(^"Inventory")
	manager.call(&"spawn_corpse", null, table.call(&"slot_transform"), &"table")
	graveyard.call(&"dig", "plot_04")
	for entry: Array in [["plot_05", &"wooden_cross"], ["plot_06", &"gravestone_simple"]]:
		graveyard.call(&"dig", entry[0])
		var plot := world.get_node(NodePath("Entities/" + String(entry[0]))) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		graveyard.call(&"bury", entry[0], record.get("id"))
		inv.call(&"add_item", entry[1], 1)
		graveyard.call(&"place_marker", entry[0], entry[1], inv)
	# The gravekeeper at the table, facing it (−Z = away from the camera).
	player.global_position = table.global_position + Vector3(0.3, 0.0, 1.1)
	player.rotation.y = PI
