extends "res://src/world/graveyard/graveyard_shots_phase3.gd"
## Phase-4 world shots (docs/PHASE4_DESIGN.md §9, §11 – W-Welt part) and the §9 budget meter.
## Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase4.gd \
##       -- --out=/abs/dir [--shots=world_01,perf] [--no-grass] [--jpg]
## Headless CPU probe (no images, §9 "Skripte < 1,5 ms"):
##   godot --headless --path . -s res://src/world/graveyard/graveyard_shots_phase4.gd -- --out=/abs/dir --cpu
## Starts a new game and stages through the real systems (Expansion, Graveyard, CorpseManager,
## CorpseCare, NightTrade). Stages build on each other in list order (as in Phase 3). Per shot:
## <out>/<name>.png|jpg and a line in render_stats.txt: camera triangles, draw calls, visible /
## shadowed omni lights, live decay particles, ghosts, Ilse present.
## Decay is staged by setting the record's freshness (presentation refresh only – the clock stands
## still while shooting, so the manager does not recompute it).

const P4_SHOTS: Array[Dictionary] = [
	{"name": "world_p4_01_overview_day", "stage": "start", "day": 4, "minute": 660, "focus": Vector2(-1.0, -7.0), "distance": 40.0},
	{"name": "world_p4_02_holunderwinkel_locked", "stage": "", "day": 4, "minute": 640, "focus": Vector2(-7.0, -15.6), "distance": 20.0,
			"player": Vector2(-9.9, -11.2)},
	{"name": "world_p4_03_story_corpse_table", "stage": "story_table", "day": 6, "minute": 530, "focus": Vector2(-1.9, -5.3), "distance": 9.0,
			"player": Vector2(-1.2, -4.2)},
	{"name": "world_p4_04_smoke_bowl", "stage": "balm", "day": 6, "minute": 560, "focus": Vector2(-1.2, -5.7), "distance": 4.5,
			"player": Vector2(0.2, -4.2)},
	{"name": "world_p4_05_decay_vfx_night", "stage": "decay", "day": 6, "minute": 1350, "focus": Vector2(-2.2, -5.0), "distance": 10.0,
			"player": Vector2(-0.6, -3.6)},
	{"name": "world_p4_05b_decay_vfx_close", "stage": "", "day": 6, "minute": 1290, "focus": Vector2(-1.7, -5.2), "distance": 5.0,
			"player": Vector2(0.4, -4.0)},
	# W3 (G4): the decay stages by day at the gameplay zoom minimum (table: decaying, ground: wilted-decaying / rotten).
	{"name": "world_p4_05c_decay_day", "stage": "", "day": 6, "minute": 700, "focus": Vector2(-1.8, -4.4), "distance": 12.0,
			"player": Vector2(1.2, -2.8)},
	{"name": "world_p4_06_holunderwinkel_open", "stage": "elder_open", "day": 7, "minute": 650, "focus": Vector2(-7.0, -15.6), "distance": 20.0,
			"player": Vector2(-7.7, -16.6)},
	{"name": "world_p4_07_ilse_west_wall_night", "stage": "trader", "day": 8, "minute": 1410, "focus": Vector2(-12.2, -3.2), "distance": 8.0,
			"player": Vector2(-10.85, -2.3), "hide": ["Decor/Tree"]},
	{"name": "world_p4_08_holunderwinkel_night", "stage": "", "day": 8, "minute": 1400, "focus": Vector2(-7.0, -15.6), "distance": 22.0,
			"player": Vector2(-7.7, -12.9)},
	{"name": "world_p4_09_overview_end", "stage": "", "day": 8, "minute": 660, "focus": Vector2(-1.0, -7.0), "distance": 40.0},
	# §9 budget at the gameplay zoom limit (24 m): day, and night with Ilse, ghosts and 3 decaying corpses.
	{"name": "perf_p4_01_day_zoom_max", "stage": "", "day": 8, "minute": 690, "focus": Vector2(-4.0, -6.0), "distance": 24.0},
	{"name": "perf_p4_02_night_ilse_decay_zoom_max", "stage": "", "day": 8, "minute": 1410, "focus": Vector2(-5.0, -6.0), "distance": 24.0,
			"player": Vector2(-3.0, -4.0)},
	{"name": "perf_p4_03_night_elder_ghosts_zoom_max", "stage": "", "day": 8, "minute": 1410, "focus": Vector2(-6.0, -12.0), "distance": 24.0,
			"player": Vector2(-7.7, -12.9)},
]
const DECAY_PLAIN_SCRIPT := "res://src/entities/corpse/corpse_decay_visual.gd"
## Ground spots (world XZ, yaw) next to the table for the extra decaying corpses.
const DECAY_GROUND: Array = [[Vector2(-3.3, -3.9), 108.0, 0.2], [Vector2(-0.2, -3.2), 20.0, 0.05]]
const ELDER_GRAVES := {"h_01": &"gravestone_simple", "h_02": &"wooden_cross", "h_04": &"wooden_cross", "h_05": &"gravestone_simple"}

var _ground_corpses: Array[String] = []
var _table_corpse: String = ""


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--no-grass":
			_no_grass = true
		elif arg == "--jpg":
			_jpg = true
		elif arg == "--cpu":
			_cpu = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=world_p4_01,perf] [--jpg] [--cpu]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	var bus := root.get_node(^"EventBus")
	saves.set("save_dir", SHOT_SAVE_DIR)
	saves.call(&"new_game")
	await Signal(bus, &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	(world.get_node(^"Decor/Grass") as Node3D).visible = not _no_grass
	if _cpu:
		await _cpu_probe_p4(world)
		quit()
		return
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ShotAnchor"
	world.add_child(anchor)
	rig.set("target", anchor)
	rig.set("zoom_max", ZOOM_MAX + 10.0)
	rig.set("zoom_min", 3.0)  # close-ups below the gameplay zoom (12 m) for the props / VFX
	var report: PackedStringArray = []
	for shot: Dictionary in P4_SHOTS:
		clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
		if String(shot.stage) != "":
			await _apply_p4_stage(world, String(shot.stage))
		if not _only.is_empty() and not Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p)):
			continue
		clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
		_refresh_npcs(world)
		_refresh_corpses(world)
		var focus: Vector2 = shot.focus
		var stand: Vector2 = shot.get("player", focus + Vector2(1.5, 2.5))
		player.global_position = Vector3(stand.x, _ground(world, stand), stand.y)
		player.rotation.y = PI
		anchor.global_position = Vector3(focus.x, 0.0, focus.y)
		rig.call(&"set_distance", float(shot.distance))
		rig.call(&"snap")
		# "hide": close-ups from inside a tree crown (the old oak stands between the camera and the
		# west wall; in play the foliage cutout frees the gravekeeper) – shown again afterwards.
		var hidden: Array[Node3D] = []
		for path: String in shot.get("hide", []):
			var node := world.get_node(NodePath(path)) as Node3D
			node.visible = false
			hidden.append(node)
		for i: int in 5:
			await process_frame
		_system(world, "Ghosts").call(&"reselect")
		for i: int in SETTLE_FRAMES:
			await process_frame
		var image := root.get_texture().get_image()
		var path := _out.path_join("%s.%s" % [shot.name, "jpg" if _jpg else "png"])
		if _jpg:
			image.save_jpg(path, 0.88)
		else:
			image.save_png(path)
		var lights := _light_counts(world)
		var particles := int(load(DECAY_PLAIN_SCRIPT).call(&"total_live_particles"))
		var m: Dictionary = await _measure(world)
		for node: Node3D in hidden:
			node.visible = true
		var trade := _system(world, "NightTrade")
		var info := ("%s  camera_tris=%d (primitives %d + grass %d)  frame_total≈%d  draw_calls=%d (camera %d)  objects=%d"
				+ "  omni_visible=%d  omni_shadowed=%d  particles=%d  ghosts=%d  ilse=%s") % [
			shot.name, m.camera + m.grass, m.camera, m.grass, m.live + m.grass, m.draws, m.camera_draws, m.objects,
			lights.omni, lights.shadowed, particles, lights.ghosts, trade.call(&"is_present")]
		print("[ShotsP4] ", info)
		report.append(info)
	var f := FileAccess.open(_out.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _apply_p4_stage(world: Node3D, stage: String) -> void:
	var manager := _system(world, "CorpseManager")
	var inv: Node = world.get_node(^"Player/Inventory")
	match stage:
		"start":
			_system(world, "Expansion").call(&"unlock", &"east")
			_stage_graves(world)
		"story_table":
			# S1 onto the morgue table (debug delivery, then the table's slot).
			var record: RefCounted = manager.call(&"deliver_story_now", &"s1_quendel")
			if record == null:
				push_warning("[ShotsP4] S1 not delivered")
				return
			var table := world.get_node(^"Entities/morgue_table")
			_table_corpse = String(record.get("id"))
			manager.call(&"put_down", _table_corpse, &"table", table.call(&"slot_transform"), table.call(&"slot_node"))
			_system(world, "CorpseCare").call(&"exam_all_instant", _table_corpse)
		"balm":
			inv.call(&"add_item", &"juniper", 1)
			if not bool(_system(world, "CorpseCare").call(&"apply_balm", _table_corpse, inv)):
				push_warning("[ShotsP4] juniper refused")
		"decay":
			# The table corpse decaying (its juniper window over), two more on the ground: rotten / decaying.
			var rec: RefCounted = manager.call(&"get_record", _table_corpse)
			rec.set("balm_windows", PackedInt32Array())
			rec.set("freshness", 0.16)
			for g: Array in DECAY_GROUND:
				var p: Vector2 = g[0]
				var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(g[1]))), Vector3(p.x, _ground(world, p), p.y))
				var r: RefCounted = manager.call(&"spawn_corpse", null, xf, &"ground")
				r.set("freshness", float(g[2]))
				_ground_corpses.append(String(r.get("id")))
		"elder_open":
			var state := root.get_node(^"GameState")
			state.call(&"set_flag", &"has_elder_key", true)
			_system(world, "Expansion").call(&"clear", "obs_h_gate", inv)
			_system(world, "Expansion").call(&"unlock", &"elder")
			var graveyard := _system(world, "Graveyard")
			for id: String in ELDER_GRAVES:
				graveyard.call(&"dig", id)
				var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
				var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
				record.set("examined", true)
				record.set("dress", &"shroud")
				record.set("shrouded", true)
				graveyard.call(&"bury", id, record.get("id"))
				inv.call(&"add_item", ELDER_GRAVES[id], 1)
				graveyard.call(&"place_marker", id, ELDER_GRAVES[id], inv)
			graveyard.call(&"dig", "h_06")
		"trader":
			root.get_node(^"GameState").call(&"set_flag", &"trader_known", true)
		_:
			push_warning("[ShotsP4] unknown stage '%s'" % stage)
	for i: int in 3:
		await process_frame


func _refresh_npcs(world: Node3D) -> void:
	for npc: Node in world.get_tree().get_nodes_in_group(&"npc"):
		npc.call(&"refresh")


## Re-applies the staged freshness to the corpse visuals (the clock was just set).
func _refresh_corpses(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	for id: String in _ground_corpses + ([_table_corpse] if _table_corpse != "" else []):
		var node: Node = manager.call(&"get_corpse_node", id)
		if node != null:
			node.call(&"refresh_decay")


## Headless: day and night (Ilse at the wall, ghosts, three decaying corpses emitting) with the
## clock running – mean / median / worst process time over CPU_FRAMES after CPU_WARMUP.
func _cpu_probe_p4(world: Node3D) -> void:
	for stage: String in ["start", "story_table", "balm", "decay", "elder_open", "trader"]:
		await _apply_p4_stage(world, stage)
	var clock := root.get_node(^"TimeManager")
	var ui_state := root.get_node(^"UIState")
	var lines: PackedStringArray = []
	for probe: Array in [["day", 8, 660], ["night_ilse_ghosts_decay", 8, 1385]]:
		ui_state.call(&"clear")
		clock.call(&"clear_pauses")
		clock.call(&"load_state", {"day": probe[1], "minute_of_day": probe[2]})
		_refresh_npcs(world)
		_refresh_corpses(world)
		var player := world.get_node(^"Player") as Node3D
		player.global_position = Vector3(-3.0, _ground(world, Vector2(-3.0, -4.0)), -4.0)
		# Gameplay zoom minimum (12 m): the decaying corpses at the table are within the particles'
		# visibility range, so their emitters run and are counted.
		var rig := world.get_node(^"CameraRig")
		rig.call(&"set_distance", 12.0)
		rig.call(&"snap")
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
		var ghosts: Array = _system(world, "Ghosts").call(&"active_ghosts")
		var line := "%s: process mean %.3f / median %.3f / worst %.3f ms per frame · ghosts %d · particles %d · ilse %s" % [
			probe[0], sum / CPU_FRAMES, samples[CPU_FRAMES / 2], samples.back(), ghosts.size(),
			int(load(DECAY_PLAIN_SCRIPT).call(&"total_live_particles")), _system(world, "NightTrade").call(&"is_present")]
		print("[CPU] ", line)
		lines.append(line)
	var f := FileAccess.open(_out.path_join("cpu_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
