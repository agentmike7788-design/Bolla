extends SceneTree
## QA screenshot series of the vertical-slice world (W1 visual review). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots.gd \
##       -- --out=/abs/dir [--shots=01,03]
## Starts a new game (saves go to user://shot_saves), stages the world through the real
## systems (corpse on the table, open pit, finished graves), then per shot sets the clock
## silently, frames the camera and writes <out>/<name>.png plus render_stats.txt.
## Autoloads are looked up by node path (they are no globals while this script compiles).
##
## Budget meter (TECHNICAL_ARCHITECTURE §6, "Dreiecke sichtbar < 500 k"): per shot the frame is
## measured three times – as rendered ("live"), with every animation, the NPC and the player
## frozen ("static": only shadow maps that are really redrawn every frame still count), and with
## every shadow off ("camera": the camera passes only). camera_tris = camera primitives + the
## grass the camera draws; shadow_live / shadow_static = frame primitives − camera primitives.

const Round2 := preload("res://src/world/graveyard/graveyard_shots_round2.gd")
const Shovel := preload("res://src/world/graveyard/graveyard_shots_shovel.gd")
const Tools := preload("res://src/world/graveyard/graveyard_shots_tools.gd")
const SETTLE_FRAMES := 40
## Frames after a measurement switch (shadows off / freeze) before the counters are read.
const MEASURE_FRAMES := 4
const SHOT_SAVE_DIR := "user://shot_saves"
const ZOOM_MAX := 40.0
const PRIMITIVES := RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
const DRAW_CALLS := RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
const OBJECTS := RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME

## name, minute of day, camera focus (x, z) or "player" (the gravekeeper is moved to that
## layout spot and framed like in play: "hut_door" in front of the door, "start" = player_start),
## camera distance.
const SHOTS: Array[Dictionary] = [
	{"name": "01_day_overview", "minute": 660, "focus": Vector2(0.5, 0.5), "distance": 30.0},
	{"name": "02_day_kutschweg", "minute": 660, "focus": Vector2(3.5, 20.5), "distance": 26.0},
	{"name": "03_carter_arrival", "minute": 455, "focus": Vector2(1.6, 11.0), "distance": 16.0},
	{"name": "04_morgue_table", "minute": 570, "focus": Vector2(-1.6, -5.4), "distance": 11.0},
	{"name": "05_open_pit", "minute": 600, "focus": Vector2(4.2, 5.0), "distance": 11.0},
	{"name": "06_grave_cross", "minute": 640, "focus": Vector2(6.6, 5.1), "distance": 11.0},
	{"name": "07_night_hut", "minute": 1350, "focus": Vector2(-2.5, -4.0), "distance": 22.0},
	{"name": "08_night_gate", "minute": 1240, "focus": Vector2(-0.5, 9.8), "distance": 16.0},
	{"name": "09_night_hut_door", "minute": 1350, "player": "hut_door", "distance": 22.0},
	{"name": "10_day_start", "minute": 400, "player": "start", "distance": 22.0},
]
## Player spot in front of the hut door (door-local, the door faces +Z).
const DOOR_FRONT := Vector3(0.0, 0.0, 1.0)

var _out: String = ""
var _only: PackedStringArray = []
## --no-grass: hides the grass; --distance=<m>: overrides every camera distance (budget checks).
## --round2: the change-round-2 set instead (hut, interior, chest / register – graveyard_shots_round2.gd).
var _no_grass: bool = false
var _round2: bool = false
## --shovel: G7 Runde 2 – drawing, digging with and stowing the shovel (graveyard_shots_shovel.gd).
var _shovel: bool = false
## --tools: G7 Runde 2 Werkzeuge – axe, pickaxe, hammer / chisel / saw (graveyard_shots_tools.gd;
## --shots=axe,pick,hammer picks series).
var _tools: bool = false
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
		elif arg == "--round2":
			_round2 = true
		elif arg == "--shovel":
			_shovel = true
		elif arg == "--tools":
			_tools = true
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
	var player := world.get_node(^"Player") as Node3D
	var start := player.global_transform
	_stage(world)
	var table_spot := player.global_transform
	if _round2:
		await Round2.run(self, world, _out, _only)
		quit()
		return
	if _shovel:
		await Shovel.run(self, world, _out, _only)
		quit()
		return
	if _tools:
		await Tools.run(self, world, _out, _only)
		quit()
		return
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
		match String(shot.get("player", "")):
			"hut_door":
				var door := world.get_node(^"Entities/hut_door") as Node3D
				player.global_transform = Transform3D(door.global_basis.rotated(Vector3.UP, PI), door.global_transform * DOOR_FRONT)
			"start":
				player.global_transform = start
			_:
				player.global_transform = table_spot
		if shot.has("player"):
			anchor.global_position = player.global_position
		else:
			var focus: Vector2 = shot.focus
			anchor.global_position = Vector3(focus.x, 0.0, focus.y)
		rig.call(&"set_distance", _distance if _distance > 0.0 else float(shot.distance))
		rig.call(&"snap")
		for i: int in SETTLE_FRAMES:
			await process_frame
		var path := _out.path_join("%s.png" % shot.name)
		root.get_texture().get_image().save_png(path)
		var npc := world.get_node(^"Entities/npc_carter") as Node3D
		var m: Dictionary = await _measure(world)
		var info := ("%s  camera_tris=%d (primitives %d + grass %d)  shadow_live=%d  shadow_static=%d  frame_total≈%d"
				+ "  draw_calls=%d (camera %d)  objects=%d  carter=%s visible=%s") % [
			shot.name, m.camera + m.grass, m.camera, m.grass, m.live - m.camera, m.static - m.camera, m.live + m.grass,
			m.draws, m.camera_draws, m.objects, npc.global_position, npc.visible]
		print("[Shots] ", info)
		report.append(info)
	var f := FileAccess.open(_out.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


## Counters of the settled frame: live, static (frozen), camera only (no shadows) – see the header.
func _measure(world: Node3D) -> Dictionary:
	var out := {"live": RenderingServer.get_rendering_info(PRIMITIVES), "draws": RenderingServer.get_rendering_info(DRAW_CALLS),
			"objects": RenderingServer.get_rendering_info(OBJECTS), "grass": _visible_grass_triangles(world)}
	var frozen := _freeze(world, true)
	for i: int in MEASURE_FRAMES:
		await process_frame
	out.static = RenderingServer.get_rendering_info(PRIMITIVES)
	var governor := world.get_node_or_null(^"WarmShadows")
	if governor != null:
		governor.set_process(false)
	var shadowed: Array[Light3D] = []
	for node: Node in world.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.shadow_enabled:
			light.shadow_enabled = false
			shadowed.append(light)
	for i: int in MEASURE_FRAMES:
		await process_frame
	out.camera = RenderingServer.get_rendering_info(PRIMITIVES)
	out.camera_draws = RenderingServer.get_rendering_info(DRAW_CALLS)
	for light: Light3D in shadowed:
		light.shadow_enabled = true
	if governor != null:
		governor.set_process(true)
	_freeze(world, false, frozen)
	return out


## Pauses (on) or resumes (off) every playing AnimationPlayer, the NPCs and the player.
## Returns the players it paused (pass them back to resume).
func _freeze(world: Node3D, on: bool, paused: Array[AnimationPlayer] = []) -> Array[AnimationPlayer]:
	if on:
		for node: Node in world.find_children("*", "AnimationPlayer", true, false):
			var anim := node as AnimationPlayer
			if anim.is_playing():
				anim.pause()
				paused.append(anim)
	else:
		for anim: AnimationPlayer in paused:
			anim.play()
	for npc: Node in world.get_tree().get_nodes_in_group(&"npc"):
		npc.set_process(not on)
	world.get_node(^"Player").set_physics_process(not on)
	return paused


## The primitive counter counts one tuft per MultiMesh draw: add the instances of every grass
## chunk the camera draws (inside the frustum and its visibility range) – tuft triangles × instances.
func _visible_grass_triangles(world: Node3D) -> int:
	var grass := world.get_node(^"Decor/Grass") as Node3D
	if not grass.visible:
		return 0
	var camera := root.get_camera_3d()
	var planes := camera.get_frustum()
	var eye := camera.global_position
	var total := 0
	for chunk: Node in grass.get_children():
		var mmi := chunk as MultiMeshInstance3D
		var aabb := mmi.global_transform * mmi.multimesh.get_aabb()
		if mmi.visibility_range_end > 0.0 and eye.distance_to(aabb.get_center()) > mmi.visibility_range_end:
			continue
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
