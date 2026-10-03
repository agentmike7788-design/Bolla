extends SceneTree
## QA (W3, Phase 6, docs/PHASE6_DESIGN.md §9 "Skripte CPU/Frame"): script time per frame on the same
## staging in two builds, run back to back – the Phase-5 build c5bd76d and this one. Self-contained
## (only SaveManager / TimeManager / Performance), so the same file runs in both projects:
##   godot --headless --path <project> -s res://tools/qa/qa_p6_cpu.gd -- --fixture=/abs/slot_p5_day30_reverent.json --label=p6 [--rounds=3]
## Staging: the v4 fixture day30_reverent (Phase-5 end state; in Phase 6 buildings_open at once, the
## three sites at level 0), the gravekeeper in the Alter Hof, the clock running; day 11:00 and night
## 23:05. Prints "[QACPU6] <label> <probe>: process mean … / median … / p90 … ms (physics mean …)".

const FRAMES := 1500
const WARMUP := 300
const SLOT := 7


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var fixture := ""
	var label := "build"
	var rounds := 3
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			fixture = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=")
		elif arg.begins_with("--rounds="):
			rounds = int(arg.trim_prefix("--rounds="))
	var saves := root.get_node(^"SaveManager")
	saves.set("save_dir", "user://qa_p6_cpu_saves")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa_p6_cpu_saves"))
	var target := ProjectSettings.globalize_path("user://qa_p6_cpu_saves").path_join("slot_%d.json" % SLOT)
	var f := FileAccess.open(target, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(fixture))
	f.close()
	var err: int = await saves.call(&"load_game", SLOT)
	if err != OK:
		printerr("[QACPU6] load failed ", err)
		quit(1)
		return
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	var lines: PackedStringArray = []
	for r: int in rounds:
		for probe: Array in [["day", 660], ["night", 1385]]:
			root.get_node(^"UIState").call(&"clear")
			clock.call(&"clear_pauses")
			clock.call(&"load_state", {"day": 30, "minute_of_day": probe[1]})
			var player := world.get_node(^"Player") as Node3D
			player.global_position = Vector3(-3.0, player.global_position.y, -4.0)
			clock.set("running", true)
			lines.append("%s %s r%d: %s · nodes %d" % [label, probe[0], r, await _measure(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			clock.set("running", false)
	for l: String in lines:
		print("[QACPU6] ", l)
	quit()


func _measure() -> String:
	for i: int in WARMUP:
		await process_frame
	var samples: Array[float] = []
	var physics := 0.0
	for i: int in FRAMES:
		await process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var sum := 0.0
	for v: float in samples:
		sum += v
	samples.sort()
	return "process mean %.3f / median %.3f / p90 %.3f ms (physics mean %.3f)" % [sum / FRAMES, samples[FRAMES / 2],
			samples[int(FRAMES * 0.9)], physics / FRAMES]
