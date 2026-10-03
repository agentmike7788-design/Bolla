extends "res://src/world/graveyard/graveyard_shots_phase6.gd"
## Phase-7 village shots (docs/PHASE7_DESIGN.md §9, §11 – W-Welt part: p7_01…p7_12, p7_15, the
## village half of p7_vis and perf_p7_01…03). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots.gd \
##       -- --out=/abs/dir [--shots=p7_02,perf] [--jpg]
## Every shot starts from the Phase-6 end state (tests/fixtures/saves_v5/slot_p6_day40_reverent,
## loaded through the real SaveManager: Village.post_load opens the village) and stages through the
## real systems: the gravekeeper arrives in Hollerbrück like RegionTravel does (HutPortal.arrive +
## Player.set_region, the region's own camera profile), the clock is set and every Npc places itself
## from its schedule; rooms through Player.set_in_interior (the room's own profile and light). The
## gameplay shots use the village camera as the player gets it ("game": zoom), overview shots a free
## focus ("focus" + "distance").
## Per shot: <out>/<name>.png|jpg and a line in render_stats_p7_village.txt.

const FIXTURES_V5 := "res://tests/fixtures/saves_v5/%s.json"
const FIXTURE := "slot_p6_day40_reverent"
const VILLAGE := &"village"
const ORIGIN := Vector3(0.0, 0.0, 400.0)
## The eight villagers of the contact sheet (p7_06) in the order of §2.1.
const VILLAGERS: Array[String] = ["innkeeper", "smith", "grocer", "priest", "mayor", "surgeon", "washer", "oldwoman"]
const P7_SHOTS: Array[Dictionary] = [
	{"name": "p7_01_arrival_bridge_morning", "day": 41, "minute": 470, "player": Vector2(-24.6, 1.5), "game": 22.0},
	{"name": "p7_02_anger_overview_day", "day": 41, "minute": 600, "player": Vector2(0.6, -0.4), "game": 26.0},
	{"name": "p7_02b_anger_overview_far", "day": 41, "minute": 600, "focus": Vector2(-2.0, -6.0), "distance": 46.0, "player": Vector2(0.6, -0.4)},
	{"name": "p7_03_anger_afternoon", "day": 41, "minute": 870, "player": Vector2(-1.5, 2.6), "game": 24.0},
	{"name": "p7_04_anger_dusk", "day": 41, "minute": 1100, "player": Vector2(-3.0, 1.0), "game": 24.0},
	{"name": "p7_05_village_night", "day": 41, "minute": 1318, "player": Vector2(8.0, -6.0), "game": 24.0},
	{"name": "x_pitch40_well", "day": 41, "minute": 600, "player": Vector2(0.6, -0.4), "game": 24.0, "pitch": 40.0},
	{"name": "x_pitch45_well", "day": 41, "minute": 600, "player": Vector2(0.6, -0.4), "game": 24.0, "pitch": 45.0},
	{"name": "x_pitch45_church", "day": 41, "minute": 600, "player": Vector2(-1.2, -9.4), "game": 24.0, "pitch": 45.0},
	{"name": "x_pitch40_church", "day": 41, "minute": 600, "player": Vector2(-1.2, -9.4), "game": 24.0, "pitch": 40.0},
	{"name": "x_pitch45_inn", "day": 41, "minute": 600, "player": Vector2(15.0, -8.6), "game": 22.0, "pitch": 45.0},
	{"name": "x_cottages", "day": 41, "minute": 900, "player": Vector2(0.0, 9.0), "game": 22.0, "pitch": 45.0},
]


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
		printerr("usage: -- --out=/abs/dir [--shots=p7_02,perf] [--jpg]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v5(FIXTURE)
	var report: PackedStringArray = []
	for shot: Dictionary in P7_SHOTS:
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		if wanted:
			await _shoot_village(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p7_village.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


## tests/fixtures/saves_v5/<name>.json through the real SaveManager; the new world.
func _load_v5(fixture: String) -> Node3D:
	var saves := root.get_node(^"SaveManager")
	var dir := String(saves.get("save_dir"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slot_%d.json" % SHOT_SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURES_V5 % fixture))
	f.close()
	await saves.call(&"load_game", SHOT_SLOT)
	for i: int in 3:
		await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	return world


## The village RegionRoot.
func _village(world: Node3D) -> Node3D:
	return world.get_node(^"Regions/Village") as Node3D


## Region-local (x, z) → world position on the village ground.
func _vpos(world: Node3D, p: Vector2) -> Vector3:
	var v := _village(world)
	var w := Vector2(p.x + ORIGIN.x, p.y + ORIGIN.z)
	return Vector3(w.x, float(v.call(&"ground_height", w)), w.y)


func _shoot_village(world: Node3D, shot: Dictionary, report: PackedStringArray) -> void:
	var clock := root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var room_id := StringName(shot.get("room", ""))
	var stand: Vector2 = shot.get("player", Vector2.ZERO)
	if room_id != &"":
		var room := _room(room_id)
		var local := Vector3(stand.x, 0.0, stand.y)
		player.global_transform = Transform3D(Basis(Vector3.UP, PI), room.global_transform * local)
		player.call(&"set_region", VILLAGE)
		player.call(&"set_in_interior", true, room_id)
		rig.set(&"target", player)
		rig.call(&"set_distance", float(shot.get("zoom", room.call(&"room_config").get(&"camera_distance"))))
	else:
		if bool(player.get(&"in_interior")):
			player.call(&"set_in_interior", false)
		player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(shot.get("facing", 180.0)))), _vpos(world, stand))
		if player.get(&"region_id") != VILLAGE:
			player.call(&"set_region", VILLAGE)
		if shot.has("game"):
			rig.set(&"target", player)
			rig.call(&"set_distance", float(shot.game))
		else:
			var anchor := world.get_node_or_null(^"ShotAnchor") as Node3D
			if anchor == null:
				anchor = Node3D.new()
				anchor.name = "ShotAnchor"
				world.add_child(anchor)
			anchor.global_position = _vpos(world, shot.focus)
			rig.set(&"target", anchor)
			rig.set(&"zoom_max", ZOOM_MAX + 30.0)
			rig.set(&"zoom_min", 3.0)
			rig.set(&"bounds_enabled", false)
			rig.call(&"set_distance", float(shot.distance))
	if shot.has("pitch"):
		rig.set(&"pitch_deg", float(shot.pitch))
	for i: int in 3:
		await process_frame
	root.get_node(^"EventBus").emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	rig.call(&"snap")
	_refresh_npcs(world)
	for i: int in SETTLE_FRAMES:
		await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join("%s.%s" % [shot.name, "jpg" if _jpg else "png"])
	if _jpg:
		image.save_jpg(path, 0.88)
	else:
		image.save_png(path)
	var lights := _all_lights(world)
	var m: Dictionary = await _measure(world)
	var info := "%s  camera_tris=%d (primitives %d + grass %d)  draw_calls=%d (camera %d)  objects=%d  omni_visible=%d  shadowed=%d  particles=%d" % [
		shot.name, m.camera + m.grass, m.camera, m.grass, m.draws, m.camera_draws, m.objects, lights.visible, lights.shadowed, _particles(world)]
	print("[ShotsP7] ", info)
	report.append(info)
