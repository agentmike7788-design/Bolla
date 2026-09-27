extends "res://src/world/graveyard/graveyard_shots.gd"
## Phase-3 screenshot series of the world (docs/PHASE3_DESIGN.md §9, §11 – W-Welt shots; the UI
## shots follow in the final pass). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase3.gd \
##       -- --out=/abs/dir [--shots=world_01,world_05] [--no-grass] [--jpg]
## Headless CPU probe (no images, §9 "Skripte < 1,5 ms"):
##   godot --headless --path . -s res://src/world/graveyard/graveyard_shots_phase3.gd -- --out=/abs/dir --cpu
## Starts a new game and walks the world through the real systems. Every shot names a STAGE
## that is applied once, in list order, before it (stages build on each other – a skipped
## shot still runs its stage, so --shots never changes what a shot shows). Add a shot: append
## {name, stage, minute, day, focus | player, distance} to SHOTS and, if it needs a new state,
## a stage function _stage_<id>(world). Per shot: <out>/<name>.png (.jpg with --jpg) and a line
## in render_stats.txt (triangles, draw calls, lights).
## Inherits the counters (_measure, _visible_grass_triangles) and the Phase-2 staging
## (_stage: corpse on the table, an open pit, two finished graves) from graveyard_shots.gd.

const P3_SHOTS: Array[Dictionary] = [
	{"name": "world_01_overview_day", "stage": "start", "day": 1, "minute": 660, "focus": Vector2(4.5, -4.5), "distance": 40.0},
	{"name": "world_02_east_uncleared", "stage": "", "day": 1, "minute": 660, "focus": Vector2(16.0, -2.0), "distance": 24.0},
	{"name": "world_03_east_cleared", "stage": "east_cleared", "day": 2, "minute": 660, "focus": Vector2(16.0, -2.0), "distance": 24.0},
	{"name": "world_04_birkenhang", "stage": "north_cleared", "day": 3, "minute": 630, "focus": Vector2(4.8, -15.5), "distance": 24.0},
	{"name": "world_05_decorated_day", "stage": "decorated", "day": 4, "minute": 690, "focus": Vector2(5.5, 0.5), "distance": 26.0},
	{"name": "world_06_night_ghosts", "stage": "", "day": 4, "minute": 1335, "focus": Vector2(6.0, -3.0), "distance": 30.0,
			"player": Vector2(7.0, -1.8)},
	{"name": "world_07_deep_night_ghosts", "stage": "", "day": 4, "minute": 30, "focus": Vector2(6.0, -3.0), "distance": 30.0,
			"player": Vector2(7.0, -1.8)},
	{"name": "world_08_neglected_day", "stage": "neglected", "day": 5, "minute": 690, "focus": Vector2(5.5, 0.5), "distance": 26.0},
	{"name": "world_09_overview_end", "stage": "", "day": 5, "minute": 660, "focus": Vector2(4.5, -4.5), "distance": 40.0},
	{"name": "world_10_notice_board", "stage": "", "day": 5, "minute": 700, "focus": Vector2(-1.2, 8.2), "distance": 12.0},
	# §9 budget at the gameplay zoom limit (CameraRig zoom_max 24): full cemetery, day and night.
	{"name": "perf_01_day_zoom_max", "stage": "", "day": 5, "minute": 690, "focus": Vector2(5.0, -3.0), "distance": 24.0},
	{"name": "perf_02_night_zoom_max", "stage": "", "day": 5, "minute": 1335, "focus": Vector2(5.0, -3.0), "distance": 24.0,
			"player": Vector2(6.0, -2.0)},
	{"name": "perf_03_east_night_zoom_max", "stage": "", "day": 5, "minute": 30, "focus": Vector2(15.0, -4.0), "distance": 24.0,
			"player": Vector2(16.0, -4.5)},
]
## Frames the CPU probe averages over (headless, --cpu).
const CPU_FRAMES := 600
const CPU_WARMUP := 300
## Decor for the "decorated" stage: [decor_id, world XZ wish, rot]. The nearest valid cell
## within SEARCH_RADIUS of the wish is used (the build mask / graves decide).
const DECOR_WISHES: Array = [
	[&"decor_bench_wood", Vector2(-3.8, 7.2), 0], [&"decor_bench_stone", Vector2(1.9, 2.6), 1],
	[&"decor_bench_wood", Vector2(14.0, -3.6), 0], [&"decor_bench_stone", Vector2(4.6, -13.6), 0],
	[&"decor_flowerbed", Vector2(-2.4, 2.6), 0], [&"decor_flowerbed", Vector2(9.8, 1.8), 0],
	[&"decor_flowerbed", Vector2(16.2, -3.2), 0], [&"decor_flowerbed", Vector2(1.2, -16.0), 0],
	[&"decor_lantern", Vector2(4.0, 3.6), 0], [&"decor_lantern", Vector2(8.8, 3.6), 0],
	[&"decor_lantern", Vector2(6.0, -9.9), 0], [&"decor_lantern", Vector2(16.2, -8.7), 0],
	[&"decor_lantern", Vector2(2.6, -17.9), 0], [&"decor_lantern", Vector2(7.4, -17.9), 0],
	[&"decor_grave_vase", Vector2(5.4, 3.7), 0], [&"decor_grave_vase", Vector2(3.1, -9.8), 0],
	[&"decor_grave_vase", Vector2(13.3, -8.6), 0], [&"decor_grave_vase", Vector2(18.1, -8.6), 0],
	[&"decor_grave_vase", Vector2(5.5, -17.8), 0],
]
const SEARCH_RADIUS := 2.0
## Gravel on the earth path (layout "path") from the gate up to GRAVEL_UNTIL_Z: every cell
## whose centre lies within GRAVEL_HALF_WIDTH of the path line, at most GRAVEL_MAX tiles.
const LAYOUT := "res://data/world/graveyard_layout.json"
const GRAVEL_HALF_WIDTH := 0.55
const GRAVEL_UNTIL_Z := -1.5
const GRAVEL_MAX := 40
## Graves of the "decorated" stage: plot → [marker, examined, shrouded] (moods vary at night).
const GRAVES := {
	"plot_01": [&"gravestone_simple", true, true], "plot_02": [&"wooden_cross", true, true],
	"plot_03": [&"wooden_cross", false, false], "plot_04": [&"gravestone_simple", true, true],
	"plot_07": [&"gravestone_simple", true, true], "plot_08": [&"wooden_cross", true, false],
	"plot_09": [&"wooden_cross", false, false], "plot_10": [&"gravestone_simple", true, true],
	"plot_11": [&"wooden_cross", true, true], "plot_12": [&"gravestone_simple", false, true],
}

var _jpg: bool = false
var _cpu: bool = false


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
		printerr("usage: -- --out=/abs/dir [--shots=world_01,world_02] [--jpg] [--cpu]")
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
		await _cpu_probe(world)
		quit()
		return
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ShotAnchor"
	world.add_child(anchor)
	rig.set("target", anchor)
	rig.set("zoom_max", ZOOM_MAX + 10.0)
	var report: PackedStringArray = []
	for shot: Dictionary in P3_SHOTS:
		if String(shot.stage) != "":
			await _apply_stage(world, String(shot.stage))
		if not _only.is_empty() and not Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p)):
			continue
		clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
		var focus: Vector2 = shot.focus
		var stand: Vector2 = shot.get("player", focus + Vector2(1.5, 2.5))
		player.global_position = Vector3(stand.x, _ground(world, stand), stand.y)
		player.rotation.y = PI
		anchor.global_position = Vector3(focus.x, 0.0, focus.y)
		rig.call(&"set_distance", float(shot.distance))
		rig.call(&"snap")
		for i: int in SETTLE_FRAMES:
			await process_frame
		var image := root.get_texture().get_image()
		var path := _out.path_join("%s.%s" % [shot.name, "jpg" if _jpg else "png"])
		if _jpg:
			image.save_jpg(path, 0.9)
		else:
			image.save_png(path)
		var lights := _light_counts(world)
		var m: Dictionary = await _measure(world)
		var info := ("%s  camera_tris=%d (primitives %d + grass %d)  frame_total≈%d  draw_calls=%d (camera %d)  objects=%d"
				+ "  omni_visible=%d  omni_shadowed=%d  ghosts=%d") % [
			shot.name, m.camera + m.grass, m.camera, m.grass, m.live + m.grass, m.draws, m.camera_draws, m.objects,
			lights.omni, lights.shadowed, lights.ghosts]
		print("[Shots] ", info)
		report.append(info)
	var f := FileAccess.open(_out.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _apply_stage(world: Node3D, stage: String) -> void:
	match stage:
		"start":
			_stage(world)  # Phase-2 staging: corpse on the table, open pit, two graves
		"east_cleared":
			_system(world, "Expansion").call(&"unlock", &"east")
		"north_cleared":
			_system(world, "Expansion").call(&"unlock", &"north")
		"decorated":
			_stage_graves(world)
			_stage_decor(world)
		"neglected":
			var clean := _system(world, "Cleanliness")
			var spots := {}
			var k := 0
			for id: String in clean.call(&"spot_ids"):
				k += 1
				spots[id] = [1.3, 2.4, 3.5][k % 3]
			clean.call(&"load_state", {"spots": spots})
		_:
			push_warning("[ShotsP3] unknown stage '%s'" % stage)
	for i: int in 3:
		await process_frame


## Finishes the GRAVES through the real Graveyard API (dig → bury → marker), moods vary.
func _stage_graves(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	var graveyard := _system(world, "Graveyard")
	var inv: Node = world.get_node(^"Player/Inventory")
	for id: String in GRAVES:
		var want: Array = GRAVES[id]
		var grave: RefCounted = graveyard.call(&"get_grave", id)
		if int(grave.get("state")) != 0:  # EMPTY only (plot_04 is the open pit, plot_05/06 done)
			if int(grave.get("state")) != 1:
				continue
		else:
			graveyard.call(&"dig", id)
		var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		record.set("examined", want[1])
		record.set("shrouded", want[2])
		graveyard.call(&"bury", id, record.get("id"))
		inv.call(&"add_item", want[0], 1)
		graveyard.call(&"place_marker", id, want[0], inv)


## Places DECOR_WISHES (nearest valid cell) and gravel along the path – free build, real checks.
func _stage_decor(world: Node3D) -> void:
	var decorations := _system(world, "Decorations")
	decorations.set("free_build", true)
	var player := world.get_node(^"Player") as Node3D
	player.global_position = Vector3(-20.0, 0.0, 30.0)  # out of every footprint
	var mask: Resource = decorations.get("mask")
	var placed := 0
	for wish: Array in DECOR_WISHES:
		var cell: Variant = _find_cell(decorations, mask, wish[0], wish[1], int(wish[2]))
		if cell == null:
			print("[ShotsP3] no valid cell for %s near %s" % [wish[0], wish[1]])
			continue
		if String(decorations.call(&"place", wish[0], cell, int(wish[2]), null)) != "":
			placed += 1
	var gravel := 0
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var pts: Array[Vector2] = []
	for p: Array in layout.path.points:
		pts.append(Vector2(p[0], p[1]))
	var size: Vector2i = mask.get("size")
	for cz: int in range(size.y - 1, -1, -1):
		for cx: int in size.x:
			var c := Vector2i(cx, cz)
			var w: Vector2 = mask.call(&"cell_to_world", c)
			if gravel >= GRAVEL_MAX or w.y < GRAVEL_UNTIL_Z:
				continue
			var d := INF
			for k: int in pts.size() - 1:
				d = minf(d, w.distance_to(Geometry2D.get_closest_point_to_segment(w, pts[k], pts[k + 1])))
			if d > GRAVEL_HALF_WIDTH:
				continue
			if StringName(decorations.call(&"can_place", &"decor_path_gravel", c, 0, null, null)) == &"ok":
				if String(decorations.call(&"place", &"decor_path_gravel", c, 0, null)) != "":
					gravel += 1
	print("[ShotsP3] decor placed: %d pieces + %d gravel" % [placed, gravel])


func _find_cell(decorations: Node, mask: Resource, id: StringName, wish: Vector2, rot: int) -> Variant:
	var centre: Vector2i = mask.call(&"world_to_cell", wish)
	var reach := ceili(SEARCH_RADIUS / float(mask.get("cell")))
	var best: Variant = null
	var best_d := INF
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var c := centre + Vector2i(dx, dz)
			var d := Vector2(dx, dz).length()
			if d < best_d and StringName(decorations.call(&"can_place", id, c, rot, null, null)) == &"ok":
				best = c
				best_d = d
	return best


## Omni lights that are visible in the tree (budget §9) and how many of them cast shadows.
func _light_counts(world: Node3D) -> Dictionary:
	var omni := 0
	var shadowed := 0
	for node: Node in world.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		if world.has_node(^"HutInterior") and (world.get_node(^"HutInterior") as Node).is_ancestor_of(light):
			continue
		omni += 1
		if light.shadow_enabled:
			shadowed += 1
	var ghosts: Array = _system(world, "Ghosts").call(&"active_ghosts")
	return {"omni": omni, "shadowed": shadowed, "ghosts": ghosts.size()}


## Headless: the full world (12 graves incl. the Phase-2 ones, decor, ghosts at night) with the
## clock running (UI modals from the staging closed, no pauses) – after CPU_WARMUP frames the
## mean / median / worst process + physics time per frame over CPU_FRAMES, plus the cost of one
## night's sleep (TimeManager.advance 18:00 → 06:00: growth, drift, decay in one go).
func _cpu_probe(world: Node3D) -> void:
	await _apply_stage(world, "start")
	await _apply_stage(world, "east_cleared")
	await _apply_stage(world, "north_cleared")
	await _apply_stage(world, "decorated")
	var clock := root.get_node(^"TimeManager")
	var ui_state := root.get_node(^"UIState")
	var lines: PackedStringArray = []
	for probe: Array in [["day", 2, 660], ["night_ghosts", 4, 1335]]:
		ui_state.call(&"clear")
		clock.call(&"clear_pauses")
		clock.call(&"load_state", {"day": probe[1], "minute_of_day": probe[2]})
		var player := world.get_node(^"Player") as Node3D
		player.global_position = Vector3(7.0, _ground(world, Vector2(7.0, -1.8)), -1.8)
		clock.set("running", true)
		for i: int in CPU_WARMUP:
			await process_frame
		var start_minute := int(clock.call(&"total_minutes"))
		var samples: Array[float] = []
		var physics := 0.0
		for i: int in CPU_FRAMES:
			await process_frame
			samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		clock.set("running", false)
		var sum := 0.0
		for v: float in samples:
			sum += v
		samples.sort()
		var ghosts: Array = _system(world, "Ghosts").call(&"active_ghosts")
		var line := ("%s: process mean %.3f / median %.3f / worst %.3f ms · physics %.3f ms per frame · %d game minutes"
				+ " passed · ghosts %d · decor %d · nodes %d") % [
			probe[0], sum / CPU_FRAMES, samples[CPU_FRAMES / 2], samples.back(), physics / CPU_FRAMES,
			int(clock.call(&"total_minutes")) - start_minute, ghosts.size(),
			(_system(world, "Decorations").call(&"placements") as Array).size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
		print("[CPU] ", line)
		lines.append(line)
	clock.call(&"load_state", {"day": 5, "minute_of_day": 1080})
	var t0 := Time.get_ticks_usec()
	clock.call(&"advance", 720)
	var sleep_line := "sleep 18:00 → 06:00 (advance 720): %.2f ms once" % ((Time.get_ticks_usec() - t0) / 1000.0)
	print("[CPU] ", sleep_line)
	lines.append(sleep_line)
	var f := FileAccess.open(_out.path_join("cpu_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _system(world: Node3D, node_name: String) -> Node:
	return world.get_node(NodePath("Systems/" + node_name))


func _ground(world: Node3D, p: Vector2) -> float:
	return float(world.call(&"ground_height", p))
