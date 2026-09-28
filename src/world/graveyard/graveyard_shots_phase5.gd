extends "res://src/world/graveyard/graveyard_shots_phase4.gd"
## Phase-5 world shots (docs/PHASE5_DESIGN.md §9, §11 – W-Welt part) and the §9 budget meter.
## Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase5.gd \
##       -- --out=/abs/dir [--shots=world_p5_00,perf] [--no-grass] [--jpg]
## Headless CPU probe (no images, §9 "Phase-5-Anteil ≤ +0,2 ms"):
##   godot --headless --path . -s res://src/world/graveyard/graveyard_shots_phase5.gd -- --out=/abs/dir --cpu
## Starts a new game and stages through the real systems (Expansion, Graveyard, CorpseManager,
## Workshop, GatherManager, Stonemasonry). Stages build on each other in list order: the whole
## cemetery filled (18 graves) and workshop_open → build sites → the workyard built with two
## stones in the rack and the kiln burning → designed stones set on the graves → the Ostpforte
## open → alders / flax gathered → the quarry freed. p5_00a (the Alter Hof before, build 69f8d49)
## comes from HOF_CAMERA rendered in that build – p5_00b/c use the same camera here.
## Per shot: <out>/<name>.png|jpg and a line in render_stats.txt (camera triangles, draw calls,
## visible / shadowed omni lights, particles, Label3D).

## Camera of p5_00a/b/c (focus x/z, distance, day, minute) – the same in the 69f8d49 render.
const HOF_CAMERA := {"focus": Vector2(-4.0, -7.0), "distance": 22.0, "day": 2, "minute": 660, "player": Vector2(-4.4, -3.6)}
const P5_SHOTS: Array[Dictionary] = [
	{"name": "world_p5_00b_hof_sites", "stage": "p5_start", "day": 2, "minute": 660, "focus": Vector2(-4.0, -7.0), "distance": 22.0,
			"player": Vector2(-4.4, -3.6)},
	{"name": "world_p5_00c_hof_built", "stage": "p5_built", "day": 2, "minute": 660, "focus": Vector2(-4.0, -7.0), "distance": 22.0,
			"player": Vector2(-4.4, -3.6)},
	{"name": "world_p5_03_workyard_forge_day", "stage": "", "day": 2, "minute": 700, "focus": Vector2(-1.2, -9.4), "distance": 14.0,
			"player": Vector2(-1.45, -9.1)},
	{"name": "world_p5_03b_workyard_evening", "stage": "", "day": 2, "minute": 1150, "focus": Vector2(-3.4, -7.6), "distance": 18.0,
			"player": Vector2(-1.45, -9.1)},
	{"name": "world_p5_04_workyard_night", "stage": "", "day": 2, "minute": 1390, "focus": Vector2(-3.4, -8.4), "distance": 20.0,
			"player": Vector2(-5.2, -3.8)},
	{"name": "world_p5_04b_loom", "stage": "", "day": 2, "minute": 640, "focus": Vector2(-9.2, -4.2), "distance": 12.0,
			"player": Vector2(-10.2, -3.9)},
	{"name": "world_p5_15_graves_stones", "stage": "p5_stones", "day": 3, "minute": 650, "focus": Vector2(6.3, 4.4), "distance": 12.0,
			"player": Vector2(3.0, 7.4)},
	{"name": "world_p5_15b_elder_stones_night", "stage": "", "day": 3, "minute": 1380, "focus": Vector2(-6.5, -16.2), "distance": 16.0,
			"player": Vector2(-7.7, -12.9)},
	{"name": "world_p5_01_overview", "stage": "p5_bruch_open", "day": 3, "minute": 660, "focus": Vector2(9.0, -3.5), "distance": 46.0},
	{"name": "world_p5_02_am_bruch", "stage": "", "day": 3, "minute": 640, "focus": Vector2(26.4, -1.2), "distance": 22.0,
			"player": Vector2(24.2, 0.6)},
	{"name": "world_p5_07_flax_herbs", "stage": "p5_gathered", "day": 3, "minute": 700, "focus": Vector2(27.4, 3.6), "distance": 13.0,
			"player": Vector2(25.2, 3.2)},
	{"name": "world_p5_06_schlag_alders", "stage": "", "day": 3, "minute": 680, "focus": Vector2(-8.0, 19.4), "distance": 18.0,
			"player": Vector2(-6.0, 19.0)},
	{"name": "world_p5_05_quarry_open", "stage": "p5_quarry_open", "day": 3, "minute": 640, "focus": Vector2(27.0, -8.6), "distance": 18.0,
			"player": Vector2(26.2, -7.6)},
	# §9 / §11 performance motifs at the gameplay zoom limit (24 m).
	{"name": "perf_p5_01_bruch_day_zoom_max", "stage": "", "day": 3, "minute": 690, "focus": Vector2(26.0, -1.0), "distance": 24.0,
			"player": Vector2(24.2, 0.6)},
	{"name": "perf_p5_02_workyard_night_forge_decay", "stage": "p5_decay", "day": 3, "minute": 1390, "focus": Vector2(-3.0, -7.0), "distance": 24.0,
			"player": Vector2(-1.2, -4.2)},
	{"name": "perf_p5_03_graves_18_inscriptions", "stage": "", "day": 3, "minute": 690, "focus": Vector2(3.0, -6.0), "distance": 24.0,
			"player": Vector2(3.0, -2.2)},
	{"name": "perf_p5_04_workyard_day_zoom_max", "stage": "", "day": 3, "minute": 690, "focus": Vector2(-4.0, -7.0), "distance": 24.0,
			"player": Vector2(-4.4, -3.6)},
]
## Designed stones of the "p5_stones" stage: grave → [shape, inscription, ornament, gilded].
const STONES := {
	"plot_04": [&"stone_master", &"i_long_road", &"orn_elder", true], "plot_05": [&"stone_arch", &"i_rest", &"orn_ivy", false],
	"plot_06": [&"stone_stele", &"i_too_soon", &"orn_poppy", false], "plot_01": [&"stone_arch", &"i_fever", &"orn_torch", true],
	"plot_02": [&"stone_stele", &"i_rest", &"", false], "plot_03": [&"stone_master", &"i_road", &"orn_ivy", false],
	"plot_07": [&"stone_stele", &"i_rest", &"orn_elder", false], "plot_08": [&"stone_arch", &"i_long_road", &"", false],
	"plot_09": [&"stone_stele", &"i_water", &"orn_poppy", false], "plot_10": [&"stone_arch", &"i_rest", &"orn_ivy", false],
	"plot_11": [&"stone_stele", &"i_fever", &"", false], "plot_12": [&"stone_master", &"i_rest", &"orn_torch", true],
	"h_01": [&"stone_master", &"i_rest", &"orn_elder", true], "h_02": [&"stone_arch", &"i_too_soon", &"orn_poppy", false],
	"h_03": [&"stone_stele", &"i_rest", &"orn_ivy", false], "h_04": [&"stone_arch", &"i_road", &"", true],
	"h_05": [&"stone_stele", &"i_long_road", &"orn_torch", false], "h_06": [&"stone_master", &"i_fever", &"orn_ivy", false],
}
## Stones waiting in the rack of the built bench (p5_00c): grave → design.
const RACK := {"plot_05": [&"stone_arch", &"i_rest", &"orn_ivy", false], "h_02": [&"stone_stele", &"i_too_soon", &"", false]}
const STONE_DESIGN := "res://src/systems/stone/stone_design.gd"
const STONE_VISUAL := "res://src/entities/grave/stone_visual.gd"
## Material for every staged build / carving (added to the player's inventory just in time).
const MATERIAL := {&"stone": 12, &"wood": 8, &"clay": 6, &"iron_fittings": 4, &"workstone": 3, &"ink": 1, &"gold_leaf": 1}


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
		printerr("usage: -- --out=/abs/dir [--shots=world_p5_00,perf] [--jpg] [--cpu]")
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
		await _cpu_probe_p5(world)
		quit()
		return
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ShotAnchor"
	world.add_child(anchor)
	rig.set("target", anchor)
	rig.set("zoom_max", ZOOM_MAX + 10.0)
	rig.set("zoom_min", 3.0)
	rig.set("bounds_enabled", false)
	var report: PackedStringArray = []
	for shot: Dictionary in P5_SHOTS:
		clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
		if String(shot.stage) != "":
			await _apply_p5_stage(world, String(shot.stage))
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
		var particles := int(load(DECAY_PLAIN_SCRIPT).call(&"total_live_particles")) + _workyard_particles(world)
		var labels := _visible_labels(world)
		var m: Dictionary = await _measure(world)
		var info := ("%s  camera_tris=%d (primitives %d + grass %d)  frame_total≈%d  draw_calls=%d (camera %d)  objects=%d"
				+ "  omni_visible=%d  omni_shadowed=%d  particles=%d  label3d=%d  ghosts=%d") % [
			shot.name, m.camera + m.grass, m.camera, m.grass, m.live + m.grass, m.draws, m.camera_draws, m.objects,
			lights.omni, lights.shadowed, particles, labels, lights.ghosts]
		print("[ShotsP5] ", info)
		report.append(info)
	var f := FileAccess.open(_out.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _apply_p5_stage(world: Node3D, stage: String) -> void:
	var inv: Node = world.get_node(^"Player/Inventory")
	var state := root.get_node(^"GameState")
	match stage:
		"p5_start":
			# The Phase-4 end state in short: every section open, all 18 graves filled and marked.
			await _apply_p4_stage(world, "start")
			await _apply_p4_stage(world, "elder_open")
			_system(world, "Expansion").call(&"unlock", &"north")
			_fill_all_graves(world)
			for flag: StringName in [&"cemetery_complete", &"workshop_open", &"bruch_license"]:
				state.call(&"set_flag", flag, true)
			_refresh_workyard(world)
		"p5_built":
			var shop := _system(world, "Workshop")
			for id: StringName in [&"mason", &"loom", &"forge"]:
				_give(inv, (root.get_node(^"Database").call(&"station", id) as Resource).get("build_inputs"))
				inv.call(&"add_item", &"coin", 30)
				if not bool(shop.call(&"build", id, inv)):
					push_warning("[ShotsP5] building %s refused" % id)
			for grave_id: String in RACK:
				_carve(world, grave_id, RACK[grave_id])
			inv.call(&"add_item", &"wood", 4)
			var charcoal: Resource = root.get_node(^"Database").call(&"recipe", &"charcoal")
			if not bool(shop.call(&"start_job", &"forge", charcoal, inv)):
				push_warning("[ShotsP5] kiln refused")
			_refresh_workyard(world)
		"p5_stones":
			var masonry := _system(world, "Stonemasonry")
			for grave_id: String in STONES:
				if not (masonry.call(&"ready_for", grave_id) as Dictionary).is_empty():
					masonry.call(&"set_stone", grave_id, inv)
					continue
				if _carve(world, grave_id, STONES[grave_id]) != "":
					masonry.call(&"set_stone", grave_id, inv)
		"p5_bruch_open":
			if not bool(_system(world, "Expansion").call(&"clear", "obs_b_gate", inv)):
				push_warning("[ShotsP5] Ostpforte refused")
		"p5_gathered":
			# Alders in three stages (tree, stump, shoots) side by side; one flax bed and a herb patch cut.
			var gathering := _system(world, "Gathering")
			var day := int(root.get_node(^"TimeManager").get("day"))
			var states := {"gather_alder_1": {"charges": 0, "last_taken_day": day, "last_refresh_day": day},
					"gather_alder_3": {"charges": 0, "last_taken_day": day - 3, "last_refresh_day": day},
					"gather_flax_2": {"charges": 0, "last_taken_day": day, "last_refresh_day": day},
					"gather_herbs_2": {"charges": 0, "last_taken_day": day, "last_refresh_day": day}}
			var saved: Dictionary = gathering.call(&"save_state")
			saved.merge(states, true)
			gathering.call(&"load_state", saved)
			gathering.call(&"post_load")
		"p5_quarry_open":
			_system(world, "Expansion").call(&"unlock", &"quarry")
		"p5_decay":
			await _apply_p4_stage(world, "story_table")
			await _apply_p4_stage(world, "decay")
		_:
			push_warning("[ShotsP5] unknown stage '%s'" % stage)
	for i: int in 3:
		await process_frame


## Every plot of the layout dug, a corpse buried and a cross / simple stone on it (real API).
func _fill_all_graves(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	var graveyard := _system(world, "Graveyard")
	var inv: Node = world.get_node(^"Player/Inventory")
	var k := 0
	for grave: RefCounted in graveyard.call(&"graves"):
		var id := String(grave.get("id"))
		if id.begins_with("old_"):
			continue
		k += 1
		var s := int(grave.get("state"))
		if s == 0:  # EMPTY
			graveyard.call(&"dig", id)
			s = 1
		if s == 1:  # DUG
			var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
			var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
			record.set("examined", true)
			record.set("shrouded", true)
			graveyard.call(&"bury", id, record.get("id"))
			s = int(grave.get("state"))
		if s == 2:  # FILLED
			var marker := &"gravestone_simple" if k % 2 == 0 else &"wooden_cross"
			inv.call(&"add_item", marker, 1)
			graveyard.call(&"place_marker", id, marker, inv)


## Stonemasonry.carve through the real rules (material handed to the player first) → order id.
func _carve(world: Node3D, grave_id: String, spec: Array) -> String:
	var inv: Node = world.get_node(^"Player/Inventory")
	_give(inv, MATERIAL)
	var design: RefCounted = load(STONE_DESIGN).new()
	design.set("shape", spec[0])
	design.set("inscription", spec[1])
	design.set("ornament", spec[2])
	design.set("gilded", spec[3])
	var masonry := _system(world, "Stonemasonry")
	var reason := String(masonry.call(&"order_block_reason", grave_id, design, inv))
	if reason != "":
		push_warning("[ShotsP5] stone for %s refused: %s" % [grave_id, reason])
		return ""
	return String(masonry.call(&"carve", grave_id, design, inv))


func _give(inv: Node, items: Dictionary) -> void:
	for id: Variant in items:
		var have := int(inv.call(&"count", StringName(str(id))))
		if have < int(items[id]):
			inv.call(&"add_item", StringName(str(id)), int(items[id]) - have)


## Build sites / stations / kiln / rack pick up the new flags without a time tick.
func _refresh_workyard(world: Node3D) -> void:
	for node: Node in world.get_node(^"Entities").get_children():
		if node.has_method(&"refresh_built"):
			node.call(&"refresh_built")
		elif node.has_method(&"refresh") and String(node.name).begins_with("site_"):
			node.call(&"refresh")
	for path: String in ["Entities/station_forge/Kiln", "Entities/station_mason/StoneRack"]:
		var n := world.get_node_or_null(NodePath(path))
		if n != null:
			n.call(&"refresh")


## Live particles of the workyard smoke (chimney + kiln) that are drawn.
func _workyard_particles(world: Node3D) -> int:
	var n := 0
	for node: Node in world.get_node(^"Entities").find_children("*", "CPUParticles3D", true, false):
		var p := node as CPUParticles3D
		if p.is_visible_in_tree() and p.emitting:
			n += p.amount
	return n


func _visible_labels(world: Node3D) -> int:
	var n := 0
	for node: Node in world.find_children("*", "Label3D", true, false):
		if (node as Label3D).is_visible_in_tree():
			n += 1
	return n


## Headless: the Phase-4 probe scene (graves, Ilse, ghosts, decaying corpses at the table) plus the
## Phase-5 world (workyard built, kiln burning, 18 designed stones, gather nodes) with the clock
## running – mean / median / worst process time per frame (CPU_FRAMES after CPU_WARMUP), and the
## same measured with the Phase-5 parts switched off (stations / gather nodes / rack hidden and
## disabled) for the Phase-5 share (§9: ≤ +0,2 ms).
func _cpu_probe_p5(world: Node3D) -> void:
	for stage: String in ["p5_start", "p5_built", "p5_stones", "p5_bruch_open"]:
		await _apply_p5_stage(world, stage)
	for stage: String in ["story_table", "balm", "decay", "trader"]:
		await _apply_p4_stage(world, stage)
	var clock := root.get_node(^"TimeManager")
	var ui_state := root.get_node(^"UIState")
	var lines: PackedStringArray = []
	for probe: Array in [["day", 8, 660, true], ["night", 8, 1385, true], ["day_p5_off", 8, 660, false], ["night_p5_off", 8, 1385, false]]:
		_phase5_parts(world, bool(probe[3]))
		ui_state.call(&"clear")
		clock.call(&"clear_pauses")
		clock.call(&"load_state", {"day": probe[1], "minute_of_day": probe[2]})
		_refresh_npcs(world)
		_refresh_corpses(world)
		var player := world.get_node(^"Player") as Node3D
		player.global_position = Vector3(-3.0, _ground(world, Vector2(-3.0, -4.0)), -4.0)
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
		var line := "%s: process mean %.3f / median %.3f / worst %.3f ms per frame · nodes %d" % [
			probe[0], sum / CPU_FRAMES, samples[CPU_FRAMES / 2], samples.back(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
		print("[CPU] ", line)
		lines.append(line)
	_phase5_parts(world, true)
	# Save size and load time of this staged Phase-5 state (§9: < 300 kB, < 1 s).
	var saves := root.get_node(^"SaveManager")
	saves.call(&"save_game", 7)
	var path := String(root.get_node(^"SaveManager").get("save_dir")).path_join("slot_7.json")
	var size := FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else -1
	var t0 := Time.get_ticks_usec()
	await saves.call(&"load_game", 7)
	var load_line := "save slot 7: %d bytes · load %.0f ms (incl. world change)" % [size, (Time.get_ticks_usec() - t0) / 1000.0]
	print("[CPU] ", load_line)
	lines.append(load_line)
	var f := FileAccess.open(_out.path_join("cpu_stats_p5.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


## Switches the Phase-5 world parts (stations, sites, gather nodes, the stones' labels) on / off.
func _phase5_parts(world: Node3D, on: bool) -> void:
	for node: Node in world.get_node(^"Entities").get_children():
		var n := String(node.name)
		if n.begins_with("station_") or n.begins_with("site_") or n.begins_with("gather_"):
			(node as Node3D).visible = on
			node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_refresh_workyard(world)
