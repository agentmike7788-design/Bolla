extends "res://src/world/graveyard/graveyard_shots_phase9.gd"
## W3 QA (docs/PHASE9_DESIGN.md §9): the Phase-9 script share per frame, measured directly like Phase 8's --cpu-micro
## (the cloud host drifts several ms between frames; a frame-time difference cannot resolve 0.1 ms):
##   godot --headless --path . -s res://docs/reviews/phase9_wip/qa_p9_cpu.gd -- --out=/abs/dir
## From the Phase-8 end state (saves_v7/slot_p8_day63_kindly, Phase 9 opens on loading). The Phase-9 tick handlers
## (Quests, WhoKnows, Letters, Stranger – EventBus.time_tick → _on_time_tick) are taken off the bus and called by hand
## after every game minute; HillRequests (small + large requests in one handler) is measured the same way but listed
## apart; the _process of the Phase-9 figures (Brenneisen on the hill / in the village, Johann on his bench / on his
## way, the night watchman) is called by hand each frame while shown. Share per frame = tick time / 30 + process time.
## Scenes: the graveyard by day with a large request and Brenneisen at the gate · the village with Brenneisen (12:00) ·
## the village with Johann on his bench (15:00) · the Holderkrug with Brenneisen at his corner table (19:10) · the
## village at night with the watchman at the Siebers' door (ending C, light + 19, 23:00). Plus the save size / load time
## and QuestLog.entries (the Merkbuch „Vorhaben") timing. → <out>/cpu_micro_p9.txt

const P9_TICK_SYSTEMS: Array[String] = ["Quests", "WhoKnows", "Letters", "Stranger"]
const P9_FIGURES: Array[String] = ["npc_stranger_g", "npc_stranger", "npc_kin_sieber_v", "npc_kin_sieber_v_g", "npc_watchman"]
const MINUTES := 60
const FRAMES_PER_MIN_SAMPLE := 5


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	if _out == "":
		printerr("usage: -- --out=/abs/dir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v7(FIXTURE_P9)
	var visit1 := _resolve_day(world, "visit1")
	var light19 := _resolve_day(world, "light19")
	var lines: PackedStringArray = []
	var bus := root.get_node(^"EventBus")
	var ticks: Array[Node] = []
	for nm: String in P9_TICK_SYSTEMS + ["HillRequests"]:
		var sys := _system(world, nm)
		if sys != null and sys.has_method(&"_on_time_tick"):
			ticks.append(sys)
			var cb := Callable(sys, &"_on_time_tick")
			if bus.is_connected(&"time_tick", cb):
				bus.disconnect(&"time_tick", cb)
	# A large request at the gate, accepted (its parts listen to the events).
	var hill := _system(world, "HillRequests")
	hill.call(&"pin_large", &"hrl_lantern_path")
	hill.call(&"accept", &"hrl_lantern_path")
	var scenes: Array = [
		["graveyard day: large request + Brenneisen at the gate", visit1, 870, &"graveyard", "", ["stranger_day"]],
		["village 12:00: Brenneisen", visit1, 720, &"village", "", ["stranger_day"]],
		["village 15:00: Johann on his bench", 66, 900, &"village", "", ["sieber_bench_day"]],
		["Holderkrug 19:10: Brenneisen at the corner table", visit1, 1150, &"village", "inn", ["stranger_day"]],
		["village 23:00: the watchman at the Siebers' door", light19, 1380, &"village", "", ["sieber_watch_day"]],
	]
	var clock := root.get_node(^"TimeManager")
	for probe: Array in scenes:
		for flag: String in probe[5]:
			_gs().call(&"set_flag", StringName(flag), int(probe[1]))
		clock.call(&"load_state", {"day": int(probe[1]), "minute_of_day": int(probe[2])})
		_dbg("region %s" % probe[3])
		if String(probe[4]) != "":
			_dbg("room %s" % probe[4])
		for i: int in 5:
			await process_frame
		bus.emit_signal(&"time_tick", int(probe[1]), int(probe[2]))
		var figures: Array[Node] = []
		for nm: String in P9_FIGURES:
			for n: Node in world.find_children(nm, "", true, false):
				if n.has_method(&"_process"):
					figures.append(n)
		var tick_us := {}
		var proc_us := 0
		var frames := 0
		var shown_max := 0
		var shown_names := {}
		var frame_ms: Array[float] = []
		clock.set("running", false)
		for minute: int in MINUTES:
			clock.call(&"advance", 1)
			for sys: Node in ticks:
				var t0 := Time.get_ticks_usec()
				sys.call(&"_on_time_tick", int(clock.get("day")), int(clock.get("minute_of_day")))
				tick_us[sys.name] = int(tick_us.get(sys.name, 0)) + Time.get_ticks_usec() - t0
			for f: int in FRAMES_PER_MIN_SAMPLE:
				await process_frame
				frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				var t1 := Time.get_ticks_usec()
				var shown := 0
				for n: Node in figures:
					if _shown(n):
						n.call(&"_process", 1.0 / 60.0)
						shown += 1
						shown_names[n.name] = true
				proc_us += Time.get_ticks_usec() - t1
				shown_max = maxi(shown_max, shown)
				frames += 1
		var p9_ticks := 0
		var parts := PackedStringArray()
		for k: Variant in tick_us:
			parts.append("%s %.3f" % [k, int(tick_us[k]) / float(MINUTES) / 1000.0])
			if String(k) != "HillRequests":
				p9_ticks += int(tick_us[k])
		var per_minute := p9_ticks / float(MINUTES) / 1000.0
		var hill_minute := int(tick_us.get(&"HillRequests", 0)) / float(MINUTES) / 1000.0
		var per_frame_proc := proc_us / float(frames) / 1000.0
		var share := per_minute / FRAMES_PER_MINUTE + per_frame_proc
		frame_ms.sort()
		var line := "%s: Phase-9 ticks %.3f ms per game minute (%s; → %.3f ms per frame) · HillRequests %.3f ms per minute (→ %.3f per frame) · Phase-9 figures _process %.3f ms per frame (up to %d shown: %s) · share ≈ %.3f ms per frame (+ HillRequests %.3f) · whole frame (process, headless) median %.2f ms" % [
				probe[0], per_minute, ", ".join(parts), per_minute / FRAMES_PER_MINUTE, hill_minute, hill_minute / FRAMES_PER_MINUTE,
				per_frame_proc, shown_max, ", ".join(shown_names.keys()), share, share + hill_minute / FRAMES_PER_MINUTE, frame_ms[frame_ms.size() / 2]]
		print("[CPU9] ", line)
		lines.append(line)
		_dbg("region graveyard")
	# QuestLog.entries – the Merkbuch „Vorhaben" (§9: ≤ 4 ms at 30 entries).
	var best := 1e9
	var worst := 0.0
	var count := 0
	for i: int in 20:
		var t0 := Time.get_ticks_usec()
		var e := QuestLog.entries(world.get_tree())
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		best = minf(best, ms)
		worst = maxf(worst, ms)
		count = e.size()
	lines.append("QuestLog.entries: %d entries, best of 20 %.3f ms, worst %.3f ms" % [count, best, worst])
	print("[CPU9] ", lines[lines.size() - 1])
	# Save size / load time (§9: < 420 kB / < 1 s).
	var saves := root.get_node(^"SaveManager")
	saves.call(&"save_game", SHOT_SLOT)
	var path := String(saves.get("save_dir")).path_join("slot_%d.json" % SHOT_SLOT)
	var size := FileAccess.get_file_as_bytes(path).size() if FileAccess.file_exists(path) else -1
	var t2 := Time.get_ticks_usec()
	await saves.call(&"load_game", SHOT_SLOT)
	lines.append("save slot %d: %d bytes · load %.0f ms (incl. world change)" % [SHOT_SLOT, size, (Time.get_ticks_usec() - t2) / 1000.0])
	print("[CPU9] ", lines[lines.size() - 1])
	var f := FileAccess.open(_out.path_join("cpu_micro_p9.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	quit()
