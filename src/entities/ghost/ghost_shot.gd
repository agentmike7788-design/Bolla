extends SceneTree
## P4 review shot (not part of the game): ghosts at night beside finished graves in the
## vertical-slice world, with the deep-night keyframes of §2.8. Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/entities/ghost/ghost_shot.gd \
##       -- --out=/abs/file.png [--minute=1410]
## Stages two graves through the real systems (plot_05 wooden cross, plot_06 gravestone),
## adds a GhostManager with its pool (until W-Welt builds Systems/Ghosts), sets plot_06 content
## and plot_05 restless, lets plot_06 speak and saves one frame.

const SETTLE_FRAMES := 90
const DEEP_KEYS := ["deep_night", "deep_night", "night", "dawn", "day", "day", "dusk", "night", "deep_night"]
const DEEP_MINUTES: Array[int] = [0, 180, 270, 330, 480, 1020, 1140, 1260, 1350]

var _out: String = ""
var _minute: int = 1410


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--minute="):
			_minute = arg.trim_prefix("--minute=").to_int()
	if _out == "":
		printerr("usage: -- --out=/abs/file.png")
		quit(2)
		return
	var saves := root.get_node(^"SaveManager")
	var bus := root.get_node(^"EventBus")
	saves.set("save_dir", "user://shot_saves")
	print("[GhostShot] new game")
	saves.call(&"new_game")
	await Signal(bus, &"new_game_started")
	await process_frame
	print("[GhostShot] world ready")
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	_stage(world)
	var atmo := world.get_node(^"Atmosphere")
	var keys: Array = atmo.get("blend_presets").duplicate()
	keys.clear()
	for id: String in DEEP_KEYS:
		keys.append(load("res://data/atmosphere/%s.tres" % id))
	atmo.set("blend_presets", keys)
	atmo.set("blend_minutes", PackedInt32Array(DEEP_MINUTES))
	clock.call(&"load_state", {"day": 1, "minute_of_day": _minute})
	var container := Node3D.new()
	container.name = "Ghosts"
	world.get_node(^"Decor").add_child(container)
	var manager: Node = load("res://src/systems/ghosts/ghost_manager.gd").new()
	manager.name = "Ghosts"
	manager.container_path = container.get_path()
	world.get_node(^"Systems").add_child(manager)
	var graveyard := world.get_node(^"Systems/Graveyard")
	graveyard.call(&"get_grave", "plot_06").set("quality", 9)
	graveyard.call(&"get_grave", "plot_05").set("quality", 2)
	manager.call(&"reselect")
	var player := world.get_node(^"Player") as Node3D
	var plot6 := world.get_node(^"Entities/plot_06") as Node3D
	player.global_position = plot6.global_position + Vector3(1.4, 0, 1.6)
	player.rotation.y = deg_to_rad(-140.0)
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = Vector3(7.6, 0.6, 5.0)
	rig.set("target", anchor)
	rig.call(&"set_distance", 10.0)
	rig.call(&"snap")
	print("[GhostShot] settling")
	for i: int in SETTLE_FRAMES:
		await process_frame
		if i % 10 == 0:
			print("[GhostShot] frame ", i)
	for g: Node in manager.call(&"active_ghosts"):
		if g.get("grave_id") == "plot_06":
			g.call(&"say", manager.call(&"listen", "plot_06", null), 30.0)
	for i: int in 10:
		await process_frame
	var img := root.get_texture().get_image()
	if _out.ends_with(".jpg"):
		img.save_jpg(_out, 0.9)
	else:
		img.save_png(_out)
	for g: Node in manager.call(&"active_ghosts"):
		print("[GhostShot] %s mood=%s fade=%.2f at %s" % [g.get("grave_id"), g.get("mood"), g.get("fade"), g.call(&"body_position")])
	quit()


## Real systems: plot_05 wooden cross, plot_06 gravestone.
func _stage(world: Node3D) -> void:
	var manager := world.get_node(^"Systems/CorpseManager")
	var graveyard := world.get_node(^"Systems/Graveyard")
	var inv: Node = world.get_node(^"Player/Inventory")
	for entry: Array in [["plot_05", &"wooden_cross"], ["plot_06", &"gravestone_simple"]]:
		graveyard.call(&"dig", entry[0])
		var plot := world.get_node(NodePath("Entities/" + String(entry[0]))) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		graveyard.call(&"bury", entry[0], record.get("id"))
		inv.call(&"add_item", entry[1], 1)
		graveyard.call(&"place_marker", entry[0], entry[1], inv)
