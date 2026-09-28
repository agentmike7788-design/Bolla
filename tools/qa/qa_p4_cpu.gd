extends "res://src/world/graveyard/graveyard_shots_phase4.gd"
## QA (W3, Phase 4) CPU attribution probe, headless: the staging of the §9 CPU probe (night,
## Ilse at the wall, ghosts, three decaying corpses, clock running), then the process time per
## frame with parts switched off one after the other, and micro timings of the per-game-minute
## HUD work (objective line incl. CemeteryStatus.phase4_state). Prints [QACPU] lines.
##   godot --headless --path . -s res://tools/qa/qa_p4_cpu.gd -- --out=/abs/dir

const STATUS := "res://src/ui/cemetery_status.gd"
const FRAMES := 600
const WARMUP := 200


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	saves.set("save_dir", "user://qa_p4_cpu_saves")
	saves.call(&"new_game")
	await Signal(root.get_node(^"EventBus"), &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	for stage: String in ["start", "story_table", "balm", "decay", "elder_open", "trader"]:
		await _apply_p4_stage(world, stage)
	var lines: PackedStringArray = []
	var ui_state := root.get_node(^"UIState")
	ui_state.call(&"clear")
	clock.call(&"clear_pauses")
	clock.call(&"load_state", {"day": 8, "minute_of_day": 1385})
	_refresh_npcs(world)
	_refresh_corpses(world)
	var player := world.get_node(^"Player") as Node3D
	player.global_position = Vector3(-3.0, _ground(world, Vector2(-3.0, -4.0)), -4.0)
	var rig := world.get_node(^"CameraRig")
	rig.call(&"set_distance", 12.0)
	rig.call(&"snap")
	clock.set("running", true)
	lines.append(await _measure_cpu("all on (night, Ilse, ghosts, 3 decaying corpses)"))
	# Micro timings of the per-game-minute HUD objective (runs on every time_tick).
	var inv: Node = world.get_node(^"Player/Inventory")
	var status: GDScript = load(STATUS)
	var t0 := Time.get_ticks_usec()
	for i: int in 200:
		status.call(&"objective_state", world.get_tree(), inv)
	var objective_us := float(Time.get_ticks_usec() - t0) / 200.0
	t0 = Time.get_ticks_usec()
	for i: int in 200:
		status.call(&"phase4_state", world.get_tree())
	var p4_us := float(Time.get_ticks_usec() - t0) / 200.0
	lines.append("objective_state %.1f µs per call (phase4_state %.1f µs) – once per game minute" % [objective_us, p4_us])
	# Decay effects off (freshness 1 → no emitters, no overlay).
	var manager := _system(world, "CorpseManager")
	for id: String in _ground_corpses + [_table_corpse]:
		var rec: RefCounted = manager.call(&"get_record", id)
		rec.set("freshness", 1.0)
		rec.set("balm_windows", PackedInt32Array())
	_refresh_corpses(world)
	lines.append(await _measure_cpu("decay effects off"))
	var ilse := world.get_node(^"Entities/npc_trader")
	ilse.process_mode = Node.PROCESS_MODE_DISABLED
	lines.append(await _measure_cpu("+ Ilse (Npc) not processed"))
	for id: String in _ground_corpses + [_table_corpse]:
		var node := manager.call(&"get_corpse_node", id) as Node
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := world.get_node_or_null(^"UI")
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	lines.append(await _measure_cpu("+ corpse nodes and UI not processed"))
	for l: String in lines:
		print("[QACPU] ", l)
	var f := FileAccess.open(_out.path_join("qa_cpu.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	quit()


func _measure_cpu(label: String) -> String:
	for i: int in WARMUP:
		await process_frame
	var samples: Array[float] = []
	for i: int in FRAMES:
		await process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var sum := 0.0
	for v: float in samples:
		sum += v
	samples.sort()
	return "%s: process mean %.3f / median %.3f / p95 %.3f ms · particles %d" % [label, sum / FRAMES,
			samples[FRAMES / 2], samples[int(FRAMES * 0.95)], int(load(DECAY_PLAIN_SCRIPT).call(&"total_live_particles"))]
