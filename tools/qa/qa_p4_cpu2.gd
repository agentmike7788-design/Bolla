extends "res://src/world/graveyard/graveyard_shots_phase3.gd"
## QA (W3, Phase 4) CPU attribution on the Phase-3 staging (the §9 Phase-3 CPU probe world,
## night with ghosts, clock running): process time with Phase-4 parts switched off one by one –
## the delta to the Phase-3 build on the same staging is pure Phase-4 code. Headless:
##   godot --headless --path . -s res://tools/qa/qa_p4_cpu2.gd -- --out=/abs/dir [--minute=1335]

const FRAMES := 1500
const WARMUP := 300


func _run() -> void:
	await process_frame
	var minute := 1335
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--minute="):
			minute = int(arg.trim_prefix("--minute="))
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	saves.set("save_dir", "user://qa_p4_cpu2_saves")
	saves.call(&"new_game")
	await Signal(root.get_node(^"EventBus"), &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	for stage: String in ["start", "east_cleared", "north_cleared", "decorated"]:
		await _apply_stage(world, stage)
	root.get_node(^"UIState").call(&"clear")
	clock.call(&"clear_pauses")
	clock.call(&"load_state", {"day": 4 if minute > 1200 else 2, "minute_of_day": minute})
	var player := world.get_node(^"Player") as Node3D
	player.global_position = Vector3(7.0, _ground(world, Vector2(7.0, -1.8)), -1.8)
	clock.set("running", true)
	var lines: PackedStringArray = []
	lines.append(await _measure_cpu("all on"))
	# Phase-4 nodes switched off and on again, alternating (the container is noisy).
	var p4: Array[Node] = []
	for path: String in ["Entities/npc_trader", "Systems/Journal", "Systems/NightTrade", "Systems/Piety",
			"Systems/CorpseCare", "Decor/DoorNote", "Decor/ElderBushes", "Decor/Phase4Props"]:
		var node := world.get_node_or_null(NodePath(path))
		if node != null:
			p4.append(node)
	for round: int in 3:
		for node: Node in p4:
			node.process_mode = Node.PROCESS_MODE_DISABLED
		lines.append(await _measure_cpu("Phase-4 nodes off (round %d)" % round))
		for node: Node in p4:
			node.process_mode = Node.PROCESS_MODE_INHERIT
		lines.append(await _measure_cpu("all on (round %d)" % round))
	for l: String in lines:
		print("[QACPU2] ", l)
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
	return "%s: mean %.3f / median %.3f / p90 %.3f ms" % [label, sum / FRAMES, samples[FRAMES / 2], samples[int(FRAMES * 0.9)]]
