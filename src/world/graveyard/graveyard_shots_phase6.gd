extends "res://src/world/graveyard/graveyard_shots_phase5.gd"
## Phase-6 world shots (docs/PHASE6_DESIGN.md §9, §11 – W-Welt part) and the §9 budget meter.
## Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase6.gd \
##       -- --out=/abs/dir [--shots=world_p6_00,perf] [--jpg]
## Headless CPU probe (no images, §9 "Phase-6-Anteil ≤ +0,2 ms"):
##   godot --headless --path . -s res://src/world/graveyard/graveyard_shots_phase6.gd -- --out=/abs/dir --cpu
## Every shot starts from a Phase-5 save (tests/fixtures/saves_v4, loaded through the real
## SaveManager) and stages through the real systems: building levels (Buildings state + the
## refresh the upgrade would send), corpses laid down at the table / niches / catafalque
## (CorpseManager.put_down), old graves lifted (Graveyard.lift_old) and reinterred (Ossuary state),
## the gravekeeper in a room (Player.set_in_interior – the room's own camera profile and light).
## p6_00a (in front of the hut before, build c5bd76d) is rendered in that build with the same
## HOF6_CAMERA from the same fixture; p6_00b/c use it here.
## Per shot: <out>/<name>.png|jpg and a line in render_stats_p6.txt (camera triangles, draw calls,
## visible / shadowed lights, particles).

const FIXTURES := "res://tests/fixtures/saves_v4/%s.json"
const SHOT_SLOT := 5
## p6_00a/b/c: in front of the hut from the south, the table (−1,6 | −5,4) and the crypt corner in view.
const HOF6_CAMERA := {"focus": Vector2(-4.8, 1.4), "distance": 28.0, "day": 16, "minute": 600, "player": Vector2(-3.4, -4.2)}
const P6_SHOTS: Array[Dictionary] = [
	{"name": "world_p6_00b_hof_sites", "fixture": "slot_p5_day16_table", "open": true, "levels": [0, 0, 0],
			"day": 16, "minute": 600, "focus": Vector2(-4.8, 1.4), "distance": 28.0, "player": Vector2(-3.4, -4.2)},
	{"name": "world_p6_00c_hof_crypt1", "levels": [1, 0, 0], "day": 16, "minute": 600, "focus": Vector2(-4.8, 1.4), "distance": 28.0,
			"player": Vector2(-3.4, -4.2)},
	# Each building by day at its access (gameplay camera 22 m) for levels 0–3, and at night.
	{"name": "world_p6_02_crypt_l0_day", "fixture": "slot_p5_day30_reverent", "levels": [0, 0, 0], "day": 30, "minute": 660,
			"focus": Vector2(-7.6, 6.9), "distance": 22.0, "player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_02_crypt_l1_day", "levels": [1, 1, 1], "day": 30, "minute": 660, "focus": Vector2(-7.6, 6.9), "distance": 22.0,
			"player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_02_crypt_l2_day", "levels": [2, 2, 2], "day": 30, "minute": 660, "focus": Vector2(-7.6, 6.9), "distance": 22.0,
			"player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_02_crypt_l3_day", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(-7.6, 6.9), "distance": 22.0,
			"player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_02_crypt_l3_zoom12", "day": 30, "minute": 660, "focus": Vector2(-7.6, 6.9), "distance": 12.0,
			"player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_02_crypt_l3_night", "day": 30, "minute": 1350, "focus": Vector2(-7.6, 6.9), "distance": 22.0,
			"player": Vector2(-6.7, 7.6)},
	{"name": "world_p6_03_chapel_l0_day", "levels": [0, 0, 0], "day": 30, "minute": 660, "focus": Vector2(4.5, -21.0), "distance": 22.0,
			"player": Vector2(4.5, -20.9)},
	{"name": "world_p6_03_chapel_l1_day", "levels": [1, 1, 1], "day": 30, "minute": 660, "focus": Vector2(4.5, -21.0), "distance": 22.0,
			"player": Vector2(4.5, -20.9)},
	{"name": "world_p6_03_chapel_l2_day", "levels": [2, 2, 2], "day": 30, "minute": 660, "focus": Vector2(4.5, -21.0), "distance": 22.0,
			"player": Vector2(4.5, -20.9)},
	{"name": "world_p6_03_chapel_l3_day", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(4.5, -21.0), "distance": 22.0,
			"player": Vector2(4.5, -20.9)},
	{"name": "world_p6_05_chapel_l3_night", "day": 30, "minute": 1350, "focus": Vector2(4.5, -19.0), "distance": 24.0,
			"player": Vector2(4.5, -18.8)},
	{"name": "world_p6_04_shed_l0_day", "levels": [0, 0, 0], "day": 30, "minute": 660, "focus": Vector2(-12.9, -6.4), "distance": 22.0,
			"player": Vector2(-12.6, -6.1)},
	{"name": "world_p6_04_shed_l1_day", "levels": [1, 1, 1], "day": 30, "minute": 660, "focus": Vector2(-12.9, -6.4), "distance": 22.0,
			"player": Vector2(-12.6, -6.1)},
	{"name": "world_p6_04_shed_l2_day", "levels": [2, 2, 2], "day": 30, "minute": 660, "focus": Vector2(-12.9, -6.4), "distance": 22.0,
			"player": Vector2(-12.6, -6.1)},
	{"name": "world_p6_04_shed_l3_day", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(-12.9, -6.4), "distance": 22.0,
			"player": Vector2(-12.6, -6.1)},
	{"name": "world_p6_04_shed_l3_night", "day": 30, "minute": 1350, "focus": Vector2(-12.9, -6.4), "distance": 22.0,
			"player": Vector2(-12.6, -6.1)},
	# G7 round 1: the crypt stair going down into the earth – from the Alter Hof, on the way down, at its
	# foot in the crypt room.
	{"name": "g7_crypt_stairs_outside_day", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(-8.2, 6.5), "distance": 11.0,
			"player": Vector2(-5.9, 8.4)},
	{"name": "g7_crypt_stairs_descending", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(-8.2, 6.5), "distance": 11.0,
			"player": Vector2(-8.3, 6.3)},
	{"name": "g7_crypt_stairs_bottom", "levels": [3, 3, 3], "room": "crypt", "day": 30, "minute": 660, "player": Vector2(0.0, 2.35)},
	{"name": "world_p6_01_overview_day", "levels": [3, 3, 3], "day": 30, "minute": 660, "focus": Vector2(-1.5, -8.0), "distance": 52.0},
	{"name": "world_p6_01b_overview_zoom24", "day": 30, "minute": 660, "focus": Vector2(-4.0, -3.0), "distance": 24.0, "player": Vector2(-4.4, -3.6)},
	# Interiors with the gravekeeper, from the room's own camera profile.
	{"name": "world_p6_06_crypt_int_l1_day", "levels": [1, 1, 1], "room": "crypt", "day": 30, "minute": 660, "player": Vector2(0.9, 0.9),
			"corpses": [["table", ""]]},
	{"name": "world_p6_07_crypt_int_l3_night", "levels": [3, 3, 3], "room": "crypt", "day": 30, "minute": 1350, "player": Vector2(-0.9, 1.0),
			"corpses": [["table", ""], ["niche", "niche_1"], ["niche", "niche_4"], ["niche", "niche_5"]], "ossuary": 4},
	{"name": "world_p6_08_ossuary_l2", "levels": [2, 2, 2], "room": "crypt", "day": 30, "minute": 660, "player": Vector2(-1.3, -2.5),
			"ossuary": 3, "zoom": 8.0},
	{"name": "world_p6_08b_ossuary_l3_grille", "levels": [3, 3, 3], "room": "crypt", "day": 30, "minute": 1350, "player": Vector2(-1.3, -2.5),
			"ossuary": 6, "zoom": 8.0},
	{"name": "world_p6_09_chapel_int_l2_service", "levels": [2, 2, 2], "room": "chapel", "day": 30, "minute": 660, "player": Vector2(0.95, -3.9),
			"corpses": [["catafalque", ""]], "rite": true},
	{"name": "world_p6_10_chapel_int_l3_service", "levels": [3, 3, 3], "room": "chapel", "day": 30, "minute": 660, "player": Vector2(0.95, -3.9),
			"corpses": [["catafalque", ""]], "rite": true},
	{"name": "world_p6_11_chapel_int_l2_night_devotion", "levels": [2, 2, 2], "room": "chapel", "day": 30, "minute": 1350, "player": Vector2(0.0, -4.1),
			"rite": true, "mourners": false},
	{"name": "world_p6_12_shed_int_l3", "levels": [3, 3, 3], "room": "shed", "day": 30, "minute": 660, "player": Vector2(0.1, 0.4)},
	{"name": "world_p6_13_procession_gate", "levels": [2, 2, 2], "day": 30, "minute": 700, "focus": Vector2(4.5, -18.0), "distance": 22.0,
			"player": Vector2(4.5, -19.6), "carry": true, "gate_open": true},
	{"name": "world_p6_14_old_grave_lifted", "levels": [1, 1, 1], "day": 30, "minute": 690, "focus": Vector2(3.6, 0.6), "distance": 14.0,
			"player": Vector2(2.2, 3.0), "lift": ["old_04", "old_05"], "dig": ["old_05"]},
	# §9 / §11 performance motifs.
	{"name": "perf_p6_01_overview_day_zoom_max", "levels": [3, 3, 3], "day": 30, "minute": 690, "focus": Vector2(-3.0, -4.0), "distance": 24.0,
			"player": Vector2(-4.4, -3.6)},
	{"name": "perf_p6_02_ridge_night_chapel_l3", "day": 30, "minute": 1390, "focus": Vector2(4.5, -19.0), "distance": 24.0,
			"player": Vector2(4.5, -18.8), "rite": true},
	{"name": "perf_p6_03_crypt_int_full_night", "room": "crypt", "day": 30, "minute": 1390, "player": Vector2(-0.9, 1.0),
			"corpses": [["table", ""], ["niche", "niche_1"], ["niche", "niche_2"], ["niche", "niche_3"], ["niche", "niche_4"],
				["niche", "niche_5"], ["niche", "niche_6"]], "ossuary": 6},
	{"name": "perf_p6_04_chapel_int_service_l3", "room": "chapel", "day": 30, "minute": 690, "player": Vector2(0.0, -4.1),
			"corpses": [["catafalque", ""]], "rite": true},
	{"name": "perf_p6_05_hof_decay_crypt_lantern", "day": 30, "minute": 1390, "focus": Vector2(-5.0, 2.0), "distance": 24.0,
			"player": Vector2(-3.0, 3.0), "ground_corpses": 3},
]
const LEVEL_IDS: Array[StringName] = [&"crypt", &"chapel", &"shed"]

var _staged_corpses: Array[String] = []


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--jpg":
			_jpg = true
		elif arg == "--cpu":
			_cpu = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=world_p6_00,perf] [--jpg] [--cpu]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	saves.set("save_dir", SHOT_SAVE_DIR)
	if _cpu:
		await _cpu_probe_p6()
		quit()
		return
	var world: Node3D = null
	var report: PackedStringArray = []
	for shot: Dictionary in P6_SHOTS:
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		if shot.has("fixture"):
			world = await _load_fixture(String(shot.fixture))
			_staged_corpses.clear()
			if bool(shot.get("open", false)):
				root.get_node(^"GameState").call(&"set_flag", &"buildings_open", true)
		if world == null:
			continue
		if not wanted:
			if shot.has("levels"):
				_set_levels(world, shot.levels)
			continue
		await _shoot(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p6.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


## Loads tests/fixtures/saves_v4/<name>.json through the real SaveManager; the new world.
func _load_fixture(fixture: String) -> Node3D:
	var saves := root.get_node(^"SaveManager")
	var dir := String(saves.get("save_dir"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slot_%d.json" % SHOT_SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURES % fixture))
	f.close()
	await saves.call(&"load_game", SHOT_SLOT)
	for i: int in 3:
		await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	return world


func _shoot(world: Node3D, shot: Dictionary, report: PackedStringArray) -> void:
	var clock := root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
	if shot.has("levels"):
		_set_levels(world, shot.levels)
	_clear_staged(world)
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	if bool(player.get(&"in_interior")):
		player.call(&"set_in_interior", false)
	var room_id := StringName(shot.get("room", ""))
	var room := _room(room_id) if room_id != &"" else null
	var inv: Object = player.get(&"inventory")
	if shot.get("lift", []).size() > 0:
		var graveyard := _system(world, "Graveyard")
		for id: String in shot.lift:
			graveyard.call(&"lift_old", id)
		for id: String in shot.get("dig", []):
			graveyard.call(&"dig", id)
	if bool(shot.get("gate_open", false)):
		var expansion := _system(world, "Expansion")
		if not bool(expansion.call(&"is_cleared", "obs_c_gate")):
			expansion.call(&"clear", "obs_c_gate", inv)
	if shot.has("ossuary"):
		_stage_ossuary(world, int(shot.ossuary))
	for c: Array in shot.get("corpses", []):
		_stage_corpse(world, String(c[0]), String(c[1]))
	for i: int in int(shot.get("ground_corpses", 0)):
		_stage_ground_corpse(world, Vector2(-4.0 + i * 1.6, 2.4 + (i % 2) * 0.9))
	if bool(shot.get("carry", false)):
		var rec: Object = _system(world, "CorpseManager").call(&"spawn_corpse", null, player.global_transform, &"ground")
		rec.set(&"dress", &"shroud")
		rec.set(&"shrouded", true)
		_staged_corpses.append(String(rec.get(&"id")))
	_set_rite(world, bool(shot.get("rite", false)), int(shot.levels[1]) if shot.has("levels") else _level(world, &"chapel"),
			bool(shot.get("mourners", true)))
	if room != null:
		var stand: Vector2 = shot.player
		var local := Vector3(stand.x, 0.0, stand.y)
		player.global_transform = Transform3D(Basis(Vector3.UP, PI), room.global_transform * local)
		player.call(&"set_in_interior", true, room_id)
		rig.set(&"target", player)
		var cfg: Object = room.call(&"room_config")
		rig.call(&"set_distance", float(shot.get("zoom", cfg.get(&"camera_distance"))))
	else:
		var focus: Vector2 = shot.focus
		var stand: Vector2 = shot.get("player", focus + Vector2(1.5, 2.5))
		player.global_position = Vector3(stand.x, _ground(world, stand), stand.y)
		player.rotation.y = PI
		var anchor := world.get_node_or_null(^"ShotAnchor") as Node3D
		if anchor == null:
			anchor = Node3D.new()
			anchor.name = "ShotAnchor"
			world.add_child(anchor)
		anchor.global_position = Vector3(focus.x, _ground(world, focus), focus.y)
		rig.set(&"target", anchor)
		rig.call(&"clear_profile")
		rig.set(&"zoom_max", ZOOM_MAX + 30.0)
		rig.set(&"zoom_min", 3.0)
		rig.set(&"bounds_enabled", false)
		rig.call(&"set_distance", float(shot.distance))
	if bool(shot.get("carry", false)) and not _staged_corpses.is_empty():
		_system(world, "CorpseManager").call(&"pick_up", _staged_corpses.back(), player)
	for i: int in 3:
		await process_frame
	# The clock was set without a tick: the outdoor dressing follows the time of the shot.
	for ext: Node in world.find_children("Exterior", "", true, false):
		if ext.has_method(&"refresh"):
			ext.call(&"refresh")
	rig.call(&"snap")
	_refresh_npcs(world)
	_refresh_corpses(world)
	_system(world, "Ghosts").call(&"reselect")
	for i: int in SETTLE_FRAMES:
		await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join("%s.%s" % [shot.name, "jpg" if _jpg else "png"])
	if _jpg:
		image.save_jpg(path, 0.88)
	else:
		image.save_png(path)
	var lights := _all_lights(world)
	var particles := _particles(world)
	var m: Dictionary = await _measure(world)
	var info := ("%s  camera_tris=%d (primitives %d + grass %d)  draw_calls=%d (camera %d)  objects=%d  omni_visible=%d"
			+ "  shadowed=%d  particles=%d  levels=%s") % [
		shot.name, m.camera + m.grass, m.camera, m.grass, m.draws, m.camera_draws, m.objects, lights.visible, lights.shadowed,
		particles, str(_levels_of(world))]
	print("[ShotsP6] ", info)
	report.append(info)


## The InteriorRoom with `id` (group interior_room), null if none.
func _room(id: StringName) -> Node3D:
	for node: Node in get_nodes_in_group(&"interior_room"):
		if node.get(&"room_id") == id:
			return node as Node3D
	return null


## Buildings to [crypt, chapel, shed] through its state (as a load would) and the refreshes an
## upgrade sends (building_upgraded, the ossuary passage, InteriorRoom.apply_level).
func _set_levels(world: Node3D, levels: Array) -> void:
	var buildings := _system(world, "Buildings")
	var crypt_before := _level(world, &"crypt")
	var state: Dictionary = buildings.call(&"save_state")
	var saved := {}
	for i: int in LEVEL_IDS.size():
		saved[String(LEVEL_IDS[i])] = int(levels[i])
	state["levels"] = saved
	buildings.call(&"load_state", state)
	root.get_node(^"GameState").call(&"set_flag", &"buildings_open", true)
	_system(world, "Ossuary").call(&"on_crypt_level", int(levels[0]))
	buildings.call(&"apply_levels")
	if crypt_before <= 0 and int(levels[0]) >= 1:
		# As Buildings.upgrade does at crypt 1: the corpse on the old table goes down (§2.2).
		var table := world.get_node(^"Interiors/CryptInterior/Entities/MorgueTable")
		_system(world, "CorpseManager").call(&"relocate_table_corpse", table.call(&"slot_transform"), table.call(&"slot_node"), &"crypt")
	for i: int in LEVEL_IDS.size():
		root.get_node(^"EventBus").emit_signal(&"building_upgraded", LEVEL_IDS[i], int(levels[i]))


func _level(world: Node3D, id: StringName) -> int:
	return int(_system(world, "Buildings").call(&"level", id))


func _levels_of(world: Node3D) -> Array:
	return LEVEL_IDS.map(func(id: StringName) -> int: return _level(world, id))


## Removes the corpses staged by the previous shot (records + nodes).
func _clear_staged(world: Node3D) -> void:
	if _staged_corpses.is_empty():
		return
	var manager := _system(world, "CorpseManager")
	# load_state frees every corpse node (and releases a carried one) and recreates the rest.
	manager.call(&"load_state", _without(manager.call(&"save_state"), _staged_corpses))
	_staged_corpses.clear()


## W3: the records live under "corpses" (CorpseSaveCodec) – filtering "records" kept every staged
## corpse, so a later shot showed the previous one's (the devotion shot had a corpse on the catafalque).
static func _without(state: Dictionary, ids: Array[String]) -> Dictionary:
	var out := state.duplicate(true)
	for key: String in ["corpses", "records"]:
		if not out.has(key):
			continue
		var kept: Array = []
		for r: Dictionary in out[key]:
			if not String(r.get("id", "")) in ids:
				kept.append(r)
		out[key] = kept
	return out


## A dressed corpse laid down at the crypt table / a niche / the catafalque (real put_down).
func _stage_corpse(world: Node3D, where: String, slot: String) -> void:
	var manager := _system(world, "CorpseManager")
	var rec: Object = manager.call(&"spawn_corpse", null, Transform3D.IDENTITY, &"ground")
	rec.set(&"dress", &"shroud")
	rec.set(&"shrouded", true)
	rec.set(&"examined", true)
	var id := String(rec.get(&"id"))
	_staged_corpses.append(id)
	match where:
		"table":
			var table := world.get_node(^"Interiors/CryptInterior/Entities/MorgueTable")
			manager.call(&"put_down", id, &"table", table.call(&"slot_transform"), table.call(&"slot_node"), &"crypt")
		"niche":
			var niche := world.get_node(NodePath("Interiors/CryptInterior/Entities/" + slot))
			var s: Node3D = niche.call(&"slot_node")
			manager.call(&"put_down", id, &"niche", s.global_transform, s, &"crypt", slot)
		"catafalque":
			var cat := world.get_node(^"Interiors/ChapelInterior/Entities/Catafalque")
			var s: Node3D = cat.call(&"slot_node")
			manager.call(&"put_down", id, &"catafalque", s.global_transform, null, &"chapel")


func _stage_ground_corpse(world: Node3D, at: Vector2) -> void:
	var manager := _system(world, "CorpseManager")
	var xf := Transform3D(Basis(Vector3.UP, 0.4), Vector3(at.x, _ground(world, at), at.y))
	var rec: Object = manager.call(&"spawn_corpse", null, xf, &"ground")
	rec.set(&"freshness", 0.2)
	_staged_corpses.append(String(rec.get(&"id")))
	manager.call(&"refresh_decay", String(rec.get(&"id")))


## `n` old graves reinterred (Ossuary state + the shelf refresh), in the lifting order.
func _stage_ossuary(world: Node3D, n: int) -> void:
	var ossuary := _system(world, "Ossuary")
	var ids: Array = ["old_04", "old_06", "old_07", "old_02", "old_05", "old_03"].slice(0, n)
	# The graves are lifted first (Ossuary.load_state drops lifted graves that are still OLD, QA6-08).
	var graveyard := _system(world, "Graveyard")
	for id: String in ids:
		graveyard.call(&"lift_old", id)
	var state: Dictionary = ossuary.call(&"save_state")
	state["lifted"] = ids
	state["reinterred"] = ids
	ossuary.call(&"load_state", state)
	ossuary.call(&"on_crypt_level", _level(world, &"crypt"))
	for node: Node in world.find_children("OssuaryShelf", "", true, false):
		node.call(&"refresh")


## The chapel rite (altar candles, bell, mourners of the level) on / off for the shot.
func _set_rite(world: Node3D, on: bool, chapel_level: int, with_mourners: bool = true) -> void:
	var altar := world.get_node_or_null(^"Interiors/ChapelInterior/Entities/ChapelAltar")
	if altar == null:
		return
	altar.set(&"rite_active", on)
	var mourners := world.get_node_or_null(^"Interiors/ChapelInterior/Entities/MournerSet")
	if mourners != null:
		var cfg: Resource = root.get_node(^"Database").call(&"config", &"chapel_config")
		var by_level: PackedInt32Array = cfg.get(&"mourners_by_level")
		var n := by_level[clampi(chapel_level, 0, by_level.size() - 1)] if on and with_mourners else 0
		if n > 0:
			mourners.call(&"show_mourners", n)
		else:
			mourners.call(&"hide_mourners")


## Lights (omni / spot) that are drawn: visible, lit, their range sphere inside the camera frustum,
## and not in a room that is not shown (the hut is never hidden – its lights count only inside).
func _all_lights(world: Node3D) -> Dictionary:
	var vis := 0
	var shadowed := 0
	var cam := (world.get_node(^"CameraRig/Camera3D") as Camera3D)
	var planes := cam.get_frustum()
	var player := world.get_node(^"Player")
	var in_hut: bool = player.get(&"interior_id") == &"hut"
	var hut := world.get_node_or_null(^"HutInterior")
	for node: Node in world.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.01:
			continue
		if hut != null and hut.is_ancestor_of(l) and not in_hut:
			continue
		var r := float(l.get(&"omni_range")) if l is OmniLight3D else float(l.get(&"spot_range"))
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(l.global_position) > r:
				inside = false
				break
		if not inside:
			continue
		vis += 1
		if l.shadow_enabled:
			shadowed += 1
	return {"visible": vis, "shadowed": shadowed}


func _particles(world: Node3D) -> int:
	var n := 0
	for node: Node in world.find_children("*", "", true, false):
		if node is CPUParticles3D and (node as CPUParticles3D).is_visible_in_tree() and (node as CPUParticles3D).emitting:
			n += (node as CPUParticles3D).amount
		elif node is GPUParticles3D and (node as GPUParticles3D).is_visible_in_tree() and (node as GPUParticles3D).emitting:
			n += (node as GPUParticles3D).amount
	return n


## Headless: the day-30 world with all three buildings on level 3, two corpses in niches, one on
## the catafalque, the chapel rite on and the clock running – process time per frame; then the same
## with the Phase-6 parts switched off (sites, doors and rooms hidden and disabled) for the §9 share.
func _cpu_probe_p6() -> void:
	var world := await _load_fixture("slot_p5_day30_reverent")
	_set_levels(world, [3, 3, 3])
	_stage_corpse(world, "niche", "niche_1")
	_stage_corpse(world, "niche", "niche_2")
	_stage_corpse(world, "catafalque", "")
	var clock := root.get_node(^"TimeManager")
	var lines: PackedStringArray = []
	for probe: Array in [["day", 660, true], ["night", 1385, true], ["day_p6_off", 660, false], ["night_p6_off", 1385, false]]:
		_phase6_parts(world, bool(probe[2]))
		root.get_node(^"UIState").call(&"clear")
		clock.call(&"clear_pauses")
		clock.call(&"load_state", {"day": 31, "minute_of_day": probe[1]})
		var player := world.get_node(^"Player") as Node3D
		player.global_position = Vector3(-3.0, _ground(world, Vector2(-3.0, -4.0)), -4.0)
		clock.set("running", true)
		for i: int in CPU_WARMUP:
			await process_frame
		var samples: Array[float] = []
		for i: int in CPU_FRAMES:
			await process_frame
			samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		clock.set("running", false)
		var sum := 0.0
		for v: float in samples:
			sum += v
		samples.sort()
		var line := "%s: process mean %.3f / median %.3f / worst %.3f ms per frame · nodes %d" % [
			probe[0], sum / CPU_FRAMES, samples[CPU_FRAMES / 2], samples.back(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
		print("[CPU6] ", line)
		lines.append(line)
	_phase6_parts(world, true)
	var saves := root.get_node(^"SaveManager")
	saves.call(&"save_game", 7)
	var path := String(saves.get("save_dir")).path_join("slot_7.json")
	var size := FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else -1
	var t0 := Time.get_ticks_usec()
	await saves.call(&"load_game", 7)
	var load_line := "save slot 7: %d bytes · load %.0f ms (incl. world change)" % [size, (Time.get_ticks_usec() - t0) / 1000.0]
	print("[CPU6] ", load_line)
	lines.append(load_line)
	var f := FileAccess.open(_out.path_join("cpu_stats_p6.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _phase6_parts(world: Node3D, on: bool) -> void:
	var nodes: Array[Node] = []
	for node: Node in world.get_node(^"Entities").get_children():
		var n := String(node.name)
		if n.begins_with("site_crypt") or n.begins_with("site_chapel") or n.begins_with("site_shed") or n.begins_with("door_"):
			nodes.append(node)
	nodes.append_array(world.get_node(^"Interiors").get_children())
	for node: Node in nodes:
		(node as Node3D).visible = on
		node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
