extends Node
## G7 Runde 2 (Performance): runs the slice through fixed scenarios and logs the wall time of every
## frame – the largest spike and the number of frames > 50 ms per scenario (docs/reviews/phase7_round2/
## perf_audio.md). Debug tool only, nothing of it ships into the game loop.
##   godot --headless --path . -s res://src/debug/perf_probe_run.gd -- [--out=/abs/result.json] [--only=map]
## In an exported build (browser): start it with the user argument --perf-probe (src/boot/main.gd).
## With a renderer (tools/godot_run.sh) the spikes include shader compiles and texture uploads.
## Phase 8 (W3, docs/PHASE8_DESIGN.md §9 "Web ohne Frame > 50 ms beim Beginn eines Besuchs, des Lichtgangs und
## des Kathreintanzes"): --only=p8 runs only these scenarios (Phase 8 opened by debug command, Jakob hired, two
## visits started, the Lichtgang with all candles, the Kathreintanz in the Holderkrug).

const SPIKE_MS := 50.0

var _out: String = ""
var _only: String = ""
var _last_usec: int = 0
var _nodes: int = 0
var _label: String = "boot"
var _frames: Dictionary = {}
var _order: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=")
	get_tree().process_frame.connect(_on_frame)
	_run.call_deferred()


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		var ms := (now - _last_usec) / 1000.0
		if not _frames.has(_label):
			_frames[_label] = []
			_order.append(_label)
		(_frames[_label] as Array).append(ms)
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if ms > SPIKE_MS:
			# Where the spike went: script/process time, physics, new nodes, resources.
			print("[Perf] spike %s %.0f ms · process %.0f ms · physics %.0f ms · nodes %+d · resources %d" % [_label, ms,
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, nodes - _nodes,
					int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
		_nodes = nodes
	_last_usec = now


func _mark(label: String) -> void:
	_label = label
	print("[Perf] mark %s" % label)
	_last_usec = Time.get_ticks_usec()


func _frames_wait(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _cmd(line: String) -> void:
	var dbg: Node = get_tree().root.get_node_or_null(^"Debug")
	if dbg != null and dbg.has_method(&"execute"):
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = dbg.call(&"execute", line)
		print("[Perf] command %s took %.1f ms" % [line, (Time.get_ticks_usec() - t0) / 1000.0])
		print("[Perf] > %s → %s %s" % [line, r.get("ok"), str(r.get("text", "")).left(80).replace("\n", " ")])


## The UIRoot (untyped – a -s script compiles before the autoloads exist).
func _ui() -> Node:
	for n: Node in get_tree().root.find_children("*", "", true, false):
		var sc: Script = n.get_script() as Script
		if sc != null and sc.get_global_name() == &"UIRoot":
			return n
	return null


func _want(name: String) -> bool:
	return _only == "" or name.contains(_only)


func _run() -> void:
	_mark("boot")
	await _secs(2.0)
	_mark("new_game")
	var save: Node = get_tree().root.get_node(^"SaveManager")
	save.call(&"new_game")
	await _secs(12.0)
	_mark("idle_graveyard")
	await _secs(4.0)
	var ui := _ui()
	if ui != null and _want("map"):
		for i: int in 3:
			_mark("map_open_%d" % (i + 1))
			ui.call(&"open_map")
			await _secs(1.5)
			_mark("map_close_%d" % (i + 1))
			ui.call(&"close_top_panel")
			await _secs(1.0)
		_mark("map_tab")
		ui.call(&"open_map")
		await _secs(0.5)
		var panel: Node = ui.call(&"get_panel", &"map")
		if panel != null:
			_cmd("village open")
			panel.call(&"refresh")
			panel.call(&"show_region", &"village")
			await _secs(1.0)
			panel.call(&"show_region", &"graveyard")
			await _secs(1.0)
		ui.call(&"close_top_panel")
		await _secs(0.5)
	if _want("walk"):
		_mark("walk_graveyard")
		await _walk([&"move_up", &"move_right", &"move_down", &"move_left"], 1.5)
	if _want("time"):
		_mark("time_dusk")
		_cmd("time 19:00")
		await _secs(3.0)
		_mark("time_night")
		_cmd("time 21:30")
		await _secs(3.0)
		_mark("time_day")
		_cmd("time 09:00")
		await _secs(3.0)
	if _want("room"):
		_mark("room_hut")
		_cmd("tp hut")
		await _secs(1.0)
		_cmd("room hut")
		await _secs(3.0)
		_mark("room_crypt")
		_cmd("buildings open")
		_cmd("build crypt 1")
		_cmd("tp crypt")
		await _secs(3.0)
	if _want("village"):
		_mark("region_village")
		_cmd("village open")
		_cmd("region village")
		await _secs(6.0)
		_mark("walk_village")
		await _walk([&"move_right", &"move_up", &"move_left", &"move_down", &"move_right"], 2.0)
		_mark("room_inn")
		_cmd("room inn")
		await _secs(3.0)
		_mark("region_back")
		_cmd("region graveyard")
		await _secs(5.0)
		if ui != null:
			_mark("map_open_village_after")
			ui.call(&"open_map")
			await _secs(1.5)
			ui.call(&"close_top_panel")
			await _secs(0.5)
	if _want("p8"):
		await _phase8()
	_mark("end")
	_report()
	get_tree().quit(0)


func _phase8() -> void:
	_cmd("village open")
	_cmd("region graveyard")
	_cmd("p8 open")
	_cmd("apprentice hire")
	_cmd("day +1")
	_cmd("time 10:00")
	_mark("p8_day")
	await _secs(4.0)
	_mark("p8_visit_start")
	_cmd("visit kehr old_01")
	_cmd("visit brandt old_02")
	await _secs(6.0)
	_mark("p8_lights_start")
	_cmd("fest lights now")
	await _secs(6.0)
	_mark("p8_lights_candles")
	_cmd("lights all")
	_cmd("time 17:00")
	await _secs(4.0)
	# The clock jumps (a day, then 19:00) cost what a sleep costs – not part of the dance's start.
	_mark("p8_next_day")
	_cmd("day +1")
	await _secs(1.0)
	_cmd("fest kathrein now")
	await _secs(2.0)
	_mark("p8_kathrein_village")
	_cmd("region village")
	await _secs(3.0)
	_mark("p8_kathrein_inn")
	_cmd("room inn")
	await _secs(6.0)
	_mark("p8_back")
	_cmd("region graveyard")
	await _secs(4.0)


func _walk(actions: Array[StringName], each: float) -> void:
	for a: StringName in actions:
		Input.action_press(a)
		await _secs(each)
		Input.action_release(a)


func _report() -> void:
	var rows: Array[Dictionary] = []
	print("[Perf] scenario                 frames   max ms  >50ms   mean ms")
	for label: String in _order:
		var f: Array = _frames[label]
		var mx := 0.0
		var sum := 0.0
		var spikes := 0
		for ms: float in f:
			mx = maxf(mx, ms)
			sum += ms
			if ms > SPIKE_MS:
				spikes += 1
		var mean := sum / maxf(f.size(), 1)
		print("[Perf] %-24s %6d %8.1f %6d %9.1f" % [label, f.size(), mx, spikes, mean])
		rows.append({"scenario": label, "frames": f.size(), "max_ms": mx, "spikes": spikes, "mean_ms": mean})
	if _out != "":
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(rows, "  "))
