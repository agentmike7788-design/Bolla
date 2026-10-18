extends SceneTree
## G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1): every walk of the data schedules (data/npc/*)
## measured on the real world – length of the waypoint polyline, game minutes, m per game minute, m/s real and the
## walk clip's speed_scale (Npc.walk_anim_speed / push_anim_speed). One TSV line per walk:
##   godot --headless --path . -s res://src/debug/walk_tempo_report.gd -- --out=/abs/file.tsv
## The runtime schedules (Visitors, Festivals, Apprentice, NightRobber, Friendship) take their minutes from
## ScheduleBuilder (NpcConfig.walk_m_per_minute) – the test test_walk_tempo checks them on the same world.

const WORLD := "res://src/world/graveyard/graveyard.tscn"
const NPC_DIR := "res://data/npc/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var world := (load(WORLD) as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	# Loaded at run time: the autoloads (Database) exist only after the SceneTree script compiled.
	var tempo: GDScript = load("res://src/systems/npc/walk_tempo.gd")
	var lines := PackedStringArray([tempo.call(&"header")])
	for row: Dictionary in tempo.call(&"data_walks", world):
		lines.append(tempo.call(&"line", row))
	var text := "\n".join(lines) + "\n"
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
		print("[walk_tempo_report] %d walks → %s" % [lines.size() - 1, out])
	else:
		print(text)
	world.queue_free()
	await process_frame
	quit(0)
