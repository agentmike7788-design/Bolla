extends "res://src/world/village/village_shots.gd"
## Phase-7 graveyard shots (docs/PHASE7_DESIGN.md §9, §11 – W-Welt part: p7_00, p7_13, p7_14, p7_16,
## p7_26, the Lindenacker half of p7_vis and perf_p7_04/05). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase7.gd \
##       -- --out=/abs/dir [--shots=p7_13,perf] [--jpg]
## From the Phase-6 end state (saves_v5/slot_p6_day40_reverent, the village open) through the real
## systems, in story order: the milestone at the end of the coach road · the Lindenacker before
## (granted, overgrown) · cleared (ExpansionManager.clear with the costs and tools in a shot bag) · the
## consecration day (the priest's schedule entry at linden_spot, today_flag) · consecrated and opened
## (ExpansionManager.unlock), six graves dug, filled and marked (Graveyard API) · the pult in the crypt
## (Workshop state + refresh_built, as the build would) · Dorothee Mahn's new stone on old_08
## (o_mangold_stone accepted, Stonemasonry.carve, set at the grave like [E]). Sight rays as
## village_sight.gd (the check of test_graveyard_world §4.6), seen from above.
## Per shot: <out>/<name>.png|jpg and a line in render_stats_p7_graveyard.txt.

const GRAVEYARD := &"graveyard"
const LINDEN_GRAVES: Array[String] = ["l_01", "l_02", "l_03", "l_04", "l_05", "l_06", "l_07", "l_08"]
## Graves of the "linden_open" stage: grave → marker.
const LINDEN_MARKERS := {"l_01": &"gravestone_simple", "l_02": &"gravestone_simple", "l_03": &"wooden_cross",
		"l_05": &"gravestone_simple", "l_06": &"wooden_cross", "l_07": &"gravestone_simple"}
const TOOLS: Array[StringName] = [&"axe", &"shovel", &"pickaxe", &"sickle", &"crowbar", &"saw", &"hammer"]
const G7_SHOTS: Array[Dictionary] = [
	{"name": "p7_00_wegstein_day", "day": 41, "minute": 600, "player": Vector2(8.2, 23.3), "facing": -80.0, "game": 18.0, "ui": true},
	{"name": "p7_13a_linden_before", "day": 41, "minute": 640, "focus": Vector2(16.5, 14.0), "distance": 22.0,
			"player": Vector2(15.2, 8.2), "stage": "granted"},
	{"name": "p7_13b_linden_cleared", "day": 41, "minute": 640, "focus": Vector2(16.5, 14.0), "distance": 22.0,
			"player": Vector2(15.2, 8.2), "stage": "cleared"},
	{"name": "p7_14_consecration_day", "day": 42, "minute": 600, "focus": Vector2(16.2, 10.4), "distance": 14.0,
			"player": Vector2(17.3, 10.7), "facing": 100.0, "stage": "consecration"},
	{"name": "p7_13c_linden_graves", "day": 43, "minute": 640, "focus": Vector2(16.5, 14.0), "distance": 22.0,
			"player": Vector2(15.2, 8.2), "stage": "linden_open"},
	{"name": "p7_vis_linden_z12", "day": 43, "minute": 640, "focus": Vector2(17.0, 12.5), "distance": 44.0, "pitch": 85.0,
			"player": Vector2(9.0, 0.0), "stage": "vis", "zoom": 12.0},
	{"name": "p7_vis_linden_z22", "day": 43, "minute": 640, "focus": Vector2(17.0, 12.5), "distance": 44.0, "pitch": 85.0,
			"player": Vector2(9.0, 0.0), "stage": "vis", "zoom": 22.0},
	{"name": "p7_vis_linden_z24", "day": 43, "minute": 640, "focus": Vector2(17.0, 12.5), "distance": 44.0, "pitch": 85.0,
			"player": Vector2(9.0, 0.0), "stage": "vis", "zoom": 24.0},
	{"name": "p7_16_crypt_pult", "day": 43, "minute": 660, "room": "crypt", "player": Vector2(-0.4, 1.0), "levels": [2, 2, 2],
			"stage": "pult"},
	{"name": "p7_26_new_stone_old_08", "day": 43, "minute": 660, "focus": Vector2(-6.4, 6.6), "distance": 12.0,
			"player": Vector2(-4.0, 7.6), "facing": 120.0, "stage": "new_stone"},
	{"name": "perf_p7_04_linden_occupied_day", "day": 43, "minute": 690, "focus": Vector2(15.0, 10.0), "distance": 24.0,
			"player": Vector2(14.0, 8.4)},
	{"name": "perf_p7_05_crypt_pult_full_niches", "day": 43, "minute": 1390, "room": "crypt", "player": Vector2(-0.4, 1.0),
			"corpses": [["table", ""], ["niche", "niche_1"], ["niche", "niche_2"], ["niche", "niche_3"], ["niche", "niche_4"],
				["niche", "niche_5"], ["niche", "niche_6"]]},
]

var _bag: Inventory


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--jpg":
			_jpg = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=p7_13,perf] [--jpg]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v5(FIXTURE)
	_bag = Inventory.new()
	_bag.name = "ShotBag"
	_bag.slot_count = 80
	world.add_child(_bag)
	var report: PackedStringArray = []
	for shot: Dictionary in G7_SHOTS:
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		# The stages build on each other (story order) – applied whether the shot is wanted or not.
		_stage_grave(world, shot)
		if wanted:
			await _shoot_grave(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p7_graveyard.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _gs() -> Node:
	return root.get_node(^"GameState")


## The persistent stages (flags, cleared obstacles, graves, the pult, the stone).
func _stage_grave(world: Node3D, shot: Dictionary) -> void:
	var clock := root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
	var expansion := _system(world, "Expansion")
	match String(shot.get("stage", "")):
		"granted":
			_gs().call(&"set_flag", &"linden_granted", true)
		"cleared":
			for id: String in expansion.call(&"obstacle_ids", &"linden"):
				if bool(expansion.call(&"is_cleared", id)):
					continue
				var data: Resource = expansion.call(&"data_of", id)
				if data != null:
					_give(_bag, data.get(&"cost"))
				for tool: StringName in TOOLS:
					if root.get_node(^"Database").call(&"has_item", tool) and _bag.count(tool) == 0:
						_bag.add_item(tool, 1)
				if not bool(expansion.call(&"clear", id, _bag)):
					push_warning("[ShotsP7G] %s refused: %s" % [id, expansion.call(&"tool_block_reason", id, _bag)])
		"consecration":
			_gs().call(&"set_flag", &"linden_consecration_day", int(shot.day))
		"linden_open":
			_gs().call(&"set_flag", &"linden_consecrated", true)
			_gs().call(&"set_flag", &"linden_consecration_day", 0)
			expansion.call(&"unlock", &"linden")
			_stage_linden_graves(world)
		"pult":
			if shot.has("levels"):
				_set_levels(world, shot.levels)
			var workshop := _system(world, "Workshop")
			var state: Dictionary = workshop.call(&"save_state")
			var built: Array = state.get("built", [])
			if not "pult" in built:
				built.append("pult")
			state["built"] = built
			workshop.call(&"load_state", state)
			for node: Node in world.find_children("*", "", true, false):
				if node.name == &"station_pult" and node.has_method(&"refresh_built"):
					node.call(&"refresh_built")
				elif node.name == &"site_pult" and node.has_method(&"refresh"):
					node.call(&"refresh")
		"new_stone":
			_stage_new_stone(world)


## Six Lindenacker graves dug, filled and marked through the real Graveyard API.
func _stage_linden_graves(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	var graveyard := _system(world, "Graveyard")
	for id: String in LINDEN_MARKERS:
		var grave: RefCounted = graveyard.call(&"get_grave", id)
		if grave == null:
			push_warning("[ShotsP7G] no grave %s" % id)
			continue
		if int(grave.get("state")) == 0:
			graveyard.call(&"dig", id)
		var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		record.set("examined", true)
		record.set("shrouded", true)
		graveyard.call(&"bury", id, record.get("id"))
		_bag.add_item(LINDEN_MARKERS[id], 1)
		graveyard.call(&"place_marker", id, LINDEN_MARKERS[id], _bag)


## Dorothee Mahn's new stone (o_mangold_stone) carved and set on old_08.
func _stage_new_stone(world: Node3D) -> void:
	var orders := _system(world, "Orders")
	_system(world, "Relationships").call(&"add", &"grocer", 25, "Shot: Bekannt")
	orders.call(&"offer", &"o_mangold_stone")
	orders.call(&"accept", &"o_mangold_stone")
	var masonry := _system(world, "Stonemasonry")
	var design := StoneDesign.from_dict({"shape": &"stele", "ornament": &"poppy", "inscription": "Dorothee Mahn"})
	var order_data: Resource = orders.call(&"order_data", &"o_mangold_stone")
	if order_data != null and (order_data.get(&"conditions") as Dictionary).has("stone_shape"):
		design.shape = StringName((order_data.get(&"conditions") as Dictionary).stone_shape)
	_give(_bag, (masonry.call(&"preview", "old_08", design) as Dictionary).get("inputs", {}))
	_bag.add_item(&"coin", 40)
	var carved := String(masonry.call(&"carve", "old_08", design, _bag))
	if carved == "":
		push_warning("[ShotsP7G] old_08 refused: %s" % masonry.call(&"order_block_reason", "old_08", design, _bag))
		return
	var plot := world.get_node(^"Entities/old_08") as Node3D
	var player := world.get_node(^"Player") as Node3D
	player.global_position = plot.global_position + Vector3(0.0, 0.0, 1.8)
	plot.call(&"interact", player)
	root.get_node(^"UIState").call(&"clear")


func _shoot_grave(world: Node3D, shot: Dictionary, report: PackedStringArray) -> void:
	_clear_staged(world)
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	if bool(player.get(&"in_interior")):
		player.call(&"set_in_interior", false)
	if player.get(&"region_id") != GRAVEYARD:
		player.call(&"set_region", GRAVEYARD)
	for c: Array in shot.get("corpses", []):
		_stage_corpse(world, String(c[0]), String(c[1]))
	var room_id := StringName(shot.get("room", ""))
	var stand: Vector2 = shot.get("player", Vector2.ZERO)
	if room_id != &"":
		var room := _room(room_id)
		player.global_transform = Transform3D(Basis(Vector3.UP, PI), room.global_transform * Vector3(stand.x, 0.0, stand.y))
		player.call(&"set_in_interior", true, room_id)
		rig.set(&"target", player)
		rig.call(&"set_distance", float(shot.get("zoom", room.call(&"room_config").get(&"camera_distance"))))
	else:
		player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(shot.get("facing", 180.0)))),
				Vector3(stand.x, _ground(world, stand), stand.y))
		if shot.has("game"):
			rig.call(&"clear_profile")
			rig.set(&"bounds_enabled", true)
			rig.set(&"zoom_max", 24.0)
			rig.set(&"zoom_min", 12.0)
			rig.set(&"target", player)
			rig.call(&"set_distance", float(shot.game))
		elif String(shot.get("stage", "")) != "vis":
			rig.call(&"clear_profile")
			var focus: Vector2 = shot.focus
			_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	for i: int in 3:
		await process_frame
	for ext: Node in world.find_children("Exterior", "", true, false):
		if ext.has_method(&"refresh"):
			ext.call(&"refresh")
	root.get_node(^"EventBus").emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	rig.call(&"snap")
	_refresh_npcs(world)
	_refresh_corpses(world)
	_system(world, "Ghosts").call(&"reselect")
	if String(shot.get("stage", "")) == "vis":
		await _stage_vis_linden(world, float(shot.zoom), shot)
	if shot.has("pitch"):
		rig.set(&"pitch_deg", float(shot.pitch))
	rig.call(&"snap")
	(world.get_node(^"UI") as CanvasLayer).visible = bool(shot.get("ui", false))
	for i: int in SETTLE_FRAMES:
		await process_frame
	await _save_frame(world, String(shot.name), report)
	_unstage(world)
	rig.set(&"pitch_deg", 45.0)
	(world.get_node(^"UI") as CanvasLayer).visible = false


## p7_vis_linden_z*: §4.6 – the head at every Lindenacker grave (stand 1.6 m south of it), at the gate
## and at linden_spot; rays to the gameplay eye at `zoom` from above.
func _stage_vis_linden(world: Node3D, zoom: float, shot: Dictionary) -> void:
	if _sight == null:
		_sight = Sight.new(world)
	if not _sight_probed:
		_sight.call(&"probe", world, PackedStringArray(["Ground", "Player", "Interiors", "HutInterior", "Regions", "Corpses", "ShotStage"]))
		_sight_probed = true
		for i: int in 3:
			await physics_frame
	var stage := _stage_root(world)
	var spots: Dictionary = {}
	for id: String in LINDEN_GRAVES:
		var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
		spots[id] = Vector2(plot.global_position.x, plot.global_position.z + 1.6)
	spots["gate"] = Vector2(15.8, 10.4)
	var spot_node := world.get_node_or_null(^"Waypoints/linden_spot") as Node3D
	if spot_node != null:
		spots["linden_spot"] = Vector2(spot_node.global_position.x, spot_node.global_position.z)
	var hidden := 0
	for spot_name: String in spots:
		var at: Vector2 = spots[spot_name]
		var feet := Vector3(at.x, _ground(world, at), at.y)
		var head := feet + Vector3(0.0, 1.7, 0.0)
		var eye := _gameplay_eye(world, feet, zoom)
		var why := String(_sight.call(&"blocked", eye, head, feet + Vector3(0.0, 1.1, 0.0)))
		_sight.call(&"draw_ray", stage, head, eye, why == "")
		_sight.call(&"draw_dot", stage, feet + Vector3(0, 0.2, 0), why == "")
		if why != "":
			hidden += 1
			print("[ShotsP7G vis] %s zoom %d hidden by %s" % [spot_name, int(zoom), why])
	print("[ShotsP7G vis] zoom %d: %d spots, %d hidden" % [int(zoom), spots.size(), hidden])
	var focus: Vector2 = shot.focus
	_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	(world.get_node(^"Player") as Node3D).visible = false
