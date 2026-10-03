extends "res://src/world/graveyard/graveyard_shots_phase6.gd"
## Phase-7 village shots (docs/PHASE7_DESIGN.md §9, §11 – W-Welt part: p7_01…p7_12, p7_15, p7_30, the
## village half of p7_vis and perf_p7_01…03). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots.gd \
##       -- --out=/abs/dir [--shots=p7_02,perf] [--jpg]
## Every shot starts from the Phase-6 end state (tests/fixtures/saves_v5/slot_p6_day40_reverent,
## loaded through the real SaveManager: Village.post_load opens the village) and stages through the
## real systems: the gravekeeper arrives in Hollerbrück like RegionTravel does (Player.set_region, the
## region's own camera profile), the clock is set and every Npc places itself from its schedule; rooms
## through Player.set_in_interior (the room's own profile and light). The gameplay shots use the
## village camera as the player gets it ("game": zoom), overview shots a free focus ("focus" +
## "distance"). Staged ("stage"): the contact sheet (the eight figures in a row, idle, names below),
## Osric on his way into the Holderkrug, the lecture (LectureSet.show_lecture, Quast at the lectern),
## the mourning ribbon at the Hagedorn cottage with Liesel in front, the sight rays (p7_vis_*:
## village_sight.gd – the check of test_village_world, seen from above). "ui": the HUD is shown
## (the prompt). Staged figures stand still (process off) and are given back to their schedule after.
## Per shot: <out>/<name>.png|jpg and a line in render_stats_p7_village.txt.

const Sight := preload("res://src/world/village/village_sight.gd")
const FIXTURES_V5 := "res://tests/fixtures/saves_v5/%s.json"
const FIXTURE := "slot_p6_day40_reverent"
const VILLAGE := &"village"
const ORIGIN := Vector3(0.0, 0.0, 400.0)
const INDOOR_PREFIX := "v_in_"
## The eight villagers of the contact sheet (p7_06) in the order of §2.1.
const VILLAGERS: Array[String] = ["innkeeper", "smith", "grocer", "priest", "mayor", "surgeon", "washer", "oldwoman"]
const P7_SHOTS: Array[Dictionary] = [
	{"name": "p7_01_arrival_bridge_morning", "day": 41, "minute": 470, "player": Vector2(-24.6, 1.5), "game": 22.0},
	{"name": "p7_02_anger_overview_day", "day": 41, "minute": 600, "player": Vector2(0.6, -0.4), "game": 26.0},
	{"name": "p7_02b_anger_overview_far", "day": 41, "minute": 600, "focus": Vector2(-2.0, -6.0), "distance": 46.0, "player": Vector2(0.6, -0.4)},
	{"name": "p7_03_anger_afternoon", "day": 41, "minute": 870, "player": Vector2(-1.5, 2.6), "game": 24.0},
	{"name": "p7_04_anger_dusk", "day": 41, "minute": 1100, "player": Vector2(-3.0, 1.0), "game": 24.0},
	{"name": "p7_05_village_night", "day": 41, "minute": 1318, "player": Vector2(6.0, -4.6), "game": 24.0, "stage": "osric_walk"},
	{"name": "p7_06_contact_sheet", "day": 41, "minute": 600, "focus": Vector2(1.4, 0.0), "distance": 14.0, "player": Vector2(0.0, 20.0),
			"stage": "sheet"},
	{"name": "p7_07_smithy_esch", "day": 41, "minute": 1000, "player": Vector2(-14.6, -0.9), "facing": 95.0, "game": 14.0, "ui": true},
	{"name": "p7_08_shop_theres", "day": 41, "minute": 600, "player": Vector2(-11.9, 7.7), "facing": 90.0, "game": 16.0, "ui": true},
	{"name": "p7_09_church_lenz", "day": 41, "minute": 600, "player": Vector2(1.6, -8.0), "facing": 20.0, "game": 22.0},
	{"name": "p7_10_inn_day", "day": 41, "minute": 750, "room": "inn", "player": Vector2(0.9, 1.3)},
	{"name": "p7_10b_inn_night", "day": 41, "minute": 1150, "room": "inn", "player": Vector2(0.9, 1.3)},
	{"name": "p7_11_surgery", "day": 41, "minute": 600, "room": "surgery", "player": Vector2(-0.9, 1.2)},
	{"name": "p7_12_office", "day": 41, "minute": 600, "room": "office", "player": Vector2(0.9, 0.6)},
	{"name": "p7_30_lecture_night", "day": 41, "minute": 1350, "room": "surgery", "player": Vector2(-2.3, 1.9), "stage": "lecture"},
	{"name": "p7_vis_village_z12", "day": 41, "minute": 600, "focus": Vector2(-2.5, -1.0), "distance": 74.0, "pitch": 85.0,
			"player": Vector2(0.0, 30.0), "stage": "vis", "zoom": 12.0},
	{"name": "p7_vis_village_z22", "day": 41, "minute": 600, "focus": Vector2(-2.5, -1.0), "distance": 74.0, "pitch": 85.0,
			"player": Vector2(0.0, 30.0), "stage": "vis", "zoom": 22.0},
	{"name": "p7_vis_village_z26", "day": 41, "minute": 600, "focus": Vector2(-2.5, -1.0), "distance": 74.0, "pitch": 85.0,
			"player": Vector2(0.0, 30.0), "stage": "vis", "zoom": 26.0},
	# §9 / §11 performance motifs.
	{"name": "perf_p7_01_anger_day_zoom_max", "day": 41, "minute": 690, "player": Vector2(0.6, -0.4), "game": 26.0},
	{"name": "perf_p7_02_village_night", "day": 41, "minute": 1330, "player": Vector2(0.6, -0.4), "game": 26.0},
	{"name": "perf_p7_03_inn_evening_full", "day": 41, "minute": 1150, "room": "inn", "player": Vector2(0.9, 1.3)},
	# Last: the ribbon is forced on for the shot.
	{"name": "p7_15_mourning_hagedorn", "day": 41, "minute": 780, "player": Vector2(-3.2, 11.3), "facing": 200.0, "focus": Vector2(-5.6, 15.4), "distance": 11.0,
			"stage": "mourning"},
]

var _staged_npcs: Array[Node3D] = []
var _sight: RefCounted
var _sight_probed := false


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
		elif String(shot.get("stage", "")) != "vis":
			_free_camera(world, _vpos(world, shot.focus), float(shot.distance))
	for i: int in 3:
		await process_frame
	root.get_node(^"EventBus").emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	rig.call(&"snap")
	_refresh_npcs(world)
	await _stage_village(world, shot)
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


## The camera on a free anchor (no bounds, any distance) at `at`.
func _free_camera(world: Node3D, at: Vector3, distance: float) -> void:
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := world.get_node_or_null(^"ShotAnchor") as Node3D
	if anchor == null:
		anchor = Node3D.new()
		anchor.name = "ShotAnchor"
		world.add_child(anchor)
	anchor.global_position = at
	rig.set(&"target", anchor)
	rig.set(&"zoom_max", ZOOM_MAX + 60.0)
	rig.set(&"zoom_min", 3.0)
	rig.set(&"bounds_enabled", false)
	rig.call(&"set_distance", distance)


func _save_frame(world: Node3D, shot_name: String, report: PackedStringArray) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join("%s.%s" % [shot_name, "jpg" if _jpg else "png"])
	if _jpg:
		image.save_jpg(path, 0.88)
	else:
		image.save_png(path)
	var lights := _all_lights(world)
	var m: Dictionary = await _measure(world)
	var info := "%s  camera_tris=%d (primitives %d + grass %d)  draw_calls=%d (camera %d)  objects=%d  omni_visible=%d  shadowed=%d  particles=%d" % [
		shot_name, m.camera + m.grass, m.camera, m.grass, m.draws, m.camera_draws, m.objects, lights.visible, lights.shadowed, _particles(world)]
	print("[ShotsP7] ", info)
	report.append(info)


# --- staging ----------------------------------------------------------------------------------------

func _stage_village(world: Node3D, shot: Dictionary) -> void:
	match String(shot.get("stage", "")):
		"sheet":
			_stage_sheet(world)
		"osric_walk":
			# On his way from the bridge into the Holderkrug (the schedule jumps there at 22:00).
			_stage_npc(world, "npc_carter_v", _vpos(world, Vector2(9.6, -6.4)), rad_to_deg(atan2(5.4, -3.2)), &"walk", 0.35)
		"lecture":
			var room := _room(&"surgery")
			for node: Node in room.find_children("*", "LectureSet", true, false):
				node.call(&"show_lecture", &"heart")
			_stage_npc(world, "npc_surgeon", room.global_transform * Vector3(0.25, 0.0, -1.15), 0.0, &"talk", 0.6)
		"mourning":
			var ribbon := _village(world).find_child("ribbon_cottage_hagedorn", true, false) as Node3D
			if ribbon != null:
				ribbon.visible = true
				ribbon.set_meta(&"shot_forced", true)
			_stage_npc(world, "npc_washer", _vpos(world, Vector2(-4.7, 16.9)), 200.0, &"idle", 0.4)
			# Wiebke Hagedorn is the dead of this house: not in the village.
			var wiebke := world.find_child("npc_oldwoman", true, false) as Node3D
			if wiebke != null:
				wiebke.call(&"_set_state", false, false, false)
				wiebke.process_mode = Node.PROCESS_MODE_DISABLED
				_staged_npcs.append(wiebke)
		"vis":
			await _stage_vis_village(world, float(shot.zoom), shot)


## A villager (Npc node `id`) at `at` facing `heading_deg` (0 = south) playing `anim`; process off.
func _stage_npc(world: Node3D, id: String, at: Vector3, heading_deg: float, anim: StringName, t: float) -> void:
	var npc := world.find_child(id, true, false) as Node3D
	if npc == null:
		push_warning("[ShotsP7] no %s" % id)
		return
	npc.call(&"_set_state", true, false, false)
	npc.visible = true
	npc.global_position = at
	npc.rotation.y = deg_to_rad(heading_deg)
	var model := npc.get(&"_model") as Node3D
	if model != null:
		model.rotation.y = 0.0
	var anim_player := npc.get(&"_anim") as AnimationPlayer
	if anim_player != null:
		var wanted := anim if anim_player.has_animation(anim) else &"idle"
		if anim_player.has_animation(wanted):
			anim_player.play(wanted)
			anim_player.seek(t, true)
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	_staged_npcs.append(npc)


## p7_06: the eight in a row on the Anger (1.6 m apart, idle, facing the camera), names below; the
## other figures and the gravekeeper out of the picture.
func _stage_sheet(world: Node3D) -> void:
	var stage := _stage_root(world)
	var db := root.get_node(^"Database")
	for node: Node in world.get_tree().get_nodes_in_group(&"npc"):
		(node as Node3D).visible = false
	for i: int in VILLAGERS.size():
		var at := _vpos(world, Vector2(-4.2 + i * 1.6, -0.4))
		_stage_npc(world, "npc_" + VILLAGERS[i], at, 0.0, &"idle", 0.3 + i * 0.17)
		var sched: Resource = db.call(&"schedule", StringName(VILLAGERS[i]))
		var label := Label3D.new()
		label.text = String(sched.get(&"display_name")) if sched != null else VILLAGERS[i]
		label.font_size = 40
		label.pixel_size = 0.0042
		label.outline_size = 10
		label.modulate = Color(0.96, 0.92, 0.82)
		label.outline_modulate = Color(0.12, 0.09, 0.07)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		stage.add_child(label)
		label.global_position = at + Vector3(0.0, 0.05, 0.85) if i % 2 == 0 else at + Vector3(0.0, 0.05, 1.25)
	(world.get_node(^"Player") as Node3D).visible = false


## p7_vis_village_z*: the §4.5 (1) spots of test_village_world, each ray from its point to the gameplay
## eye at `zoom` drawn from above (green free, red hidden), the stands as dots.
func _stage_vis_village(world: Node3D, zoom: float, shot: Dictionary) -> void:
	var village := _village(world)
	if _sight == null:
		_sight = Sight.new(world)
	if not _sight_probed:
		_sight.call(&"probe", village, PackedStringArray(["Ground", "Decor/Grass", "Entities/npc_"]))
		_sight_probed = true
		for i: int in 3:
			await physics_frame
	var stage := _stage_root(world)
	var spots := _vis_spots(world)
	var hidden := 0
	var rays := 0
	for spot: Dictionary in spots:
		var stand: Vector3 = spot.stand
		var eye := _gameplay_eye(world, stand, zoom)
		var chest := stand + Vector3(0.0, 1.1, 0.0)
		var all_free := true
		for key: String in spot.points:
			var p: Vector3 = spot.points[key]
			var why := String(_sight.call(&"blocked", eye, p, chest, spot.exclude))
			_sight.call(&"draw_ray", stage, p, eye, why == "")
			rays += 1
			if why != "":
				all_free = false
				hidden += 1
				print("[ShotsP7 vis] %s zoom %d %s hidden by %s" % [spot.name, int(zoom), key, why])
		_sight.call(&"draw_dot", stage, stand + Vector3(0, 0.2, 0), all_free)
	print("[ShotsP7 vis] zoom %d: %d spots, %d rays, %d hidden" % [int(zoom), spots.size(), rays, hidden])
	_free_camera(world, _vpos(world, shot.focus), float(shot.distance))
	(world.get_node(^"Player") as Node3D).visible = false


## The camera eye of the gameplay rig (village profile) with the gravekeeper at `stand`.
func _gameplay_eye(world: Node3D, stand: Vector3, zoom: float) -> Vector3:
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = stand
	var saved := [rig.get(&"zoom_max"), rig.get(&"zoom_min"), rig.get(&"bounds_enabled")]
	rig.set(&"pitch_deg", 45.0)
	rig.set(&"bounds_enabled", true)
	rig.set(&"target", anchor)
	rig.call(&"set_distance", zoom)
	rig.call(&"snap")
	var eye := (rig.get(&"camera") as Camera3D).global_position
	rig.set(&"target", world.get_node(^"Player"))
	anchor.free()
	rig.set(&"zoom_max", saved[0])
	rig.set(&"zoom_min", saved[1])
	rig.set(&"bounds_enabled", saved[2])
	return eye


## The §4.5 (1) spots (as test_village_world._spots): doors, counters, the board, the bridge portal and
## every place a villager talks from; {name, stand, points, exclude}.
func _vis_spots(world: Node3D) -> Array[Dictionary]:
	var village := _village(world)
	var out: Array[Dictionary] = []
	var buildings := village.get_node(^"Buildings")
	var houses := {"door_inn": "v_inn", "door_surgery": "v_surgery", "door_office": "v_office"}
	for id: String in houses:
		var door := village.get_node(NodePath("Entities/" + id)) as Node3D
		var stand: Vector3 = (door.call(&"exit_transform") as Transform3D) * Vector3(0.0, 0.0, 0.5)
		out.append({"name": id, "stand": stand, "exclude": [buildings.get_node(NodePath(houses[id]))],
				"points": {"head": stand + Vector3(0, 1.7, 0), "door": door.global_position + Vector3(0, 1.2, 0)}})
	var owners := {"counter_smith": "Buildings/v_smithy", "counter_grocer": "Buildings/v_shop", "village_board": "Decor/Props/board"}
	for id: String in ["counter_smith", "counter_grocer", "village_board", "road_out"]:
		var node := village.get_node(NodePath("Entities/" + id)) as Node3D
		var counter := id.begins_with("counter")
		var stand := node.global_position + Vector3(0.9 if counter else 0.0, 0.0, 0.0 if counter else 0.9)
		var owner_node: Node = village.get_node_or_null(NodePath(owners[id])) if owners.has(id) else null
		out.append({"name": id, "stand": stand, "exclude": [owner_node],
				"points": {"head": stand + Vector3(0, 1.7, 0), "centre": node.global_position + Vector3(0, 1.0, 0)}})
	var db := root.get_node(^"Database")
	var seen := {}
	for npc_id: String in VILLAGERS + ["carter"]:
		var sched: Resource = db.call(&"schedule", StringName(npc_id))
		if sched == null:
			continue
		for e: Resource in sched.get(&"entries"):
			var path: PackedStringArray = e.get(&"path")
			if e.get(&"region") != VILLAGE or not bool(e.get(&"visible")) or e.get(&"dialogue_id") == &"" \
					or int(e.get(&"travel_minutes")) > 0 or path.is_empty():
				continue
			var id := String(path[path.size() - 1])
			if id.begins_with(INDOOR_PREFIX) or seen.has(id + npc_id):
				continue
			seen[id + npc_id] = true
			var spot: Vector3 = village.call(&"get_waypoint", StringName(id))
			var toward := Vector3(ORIGIN.x - spot.x, 0.0, ORIGIN.z - spot.z)
			var stand := spot + (toward.normalized() if toward.length() > 0.5 else Vector3.BACK)
			var head := 1.6
			if npc_id == "oldwoman":
				head = 1.1 if e.get(&"animation") == &"sit" else 1.45
			out.append({"name": "%s@%s" % [npc_id, id], "stand": stand, "exclude": [],
					"points": {"head": stand + Vector3(0, 1.7, 0), "person": spot + Vector3(0, head, 0)}})
	return out


## The node that holds this shot's staged extras (labels, rays).
func _stage_root(world: Node3D) -> Node3D:
	var stage := world.get_node_or_null(^"ShotStage") as Node3D
	if stage == null:
		stage = Node3D.new()
		stage.name = "ShotStage"
		world.add_child(stage)
	return stage


## Gives the staged figures back to their schedule, removes the extras and the forced ribbon.
func _unstage(world: Node3D) -> void:
	for npc: Node3D in _staged_npcs:
		npc.process_mode = Node.PROCESS_MODE_INHERIT
	_staged_npcs.clear()
	for node: Node in world.get_tree().get_nodes_in_group(&"npc"):
		node.call(&"refresh")
		(node as Node3D).visible = bool(node.get(&"_present"))
	for node: Node in world.get_tree().get_nodes_in_group(&"mourning_ribbon"):
		if node.has_meta(&"shot_forced"):
			node.remove_meta(&"shot_forced")
			node.call(&"refresh")
	for node: Node in world.get_tree().get_nodes_in_group(&"lecture_set"):
		if bool(node.call(&"is_shown")):
			node.call(&"hide_lecture")
	var stage := world.get_node_or_null(^"ShotStage")
	if stage != null:
		stage.free()
	(world.get_node(^"Player") as Node3D).visible = true
