extends SceneTree
## Generates the Phase-4 (format v3) save fixtures of docs/PHASE5_DESIGN.md §5.2 by driving the
## real systems of the approved Phase 4 (build 69f8d49 / 30343c5 – run BEFORE any Phase-5 change)
## through Phase4Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v3/make_v3_saves.gd -- --out=/abs/dir [--only=day7,…]
## Writes slot_p4_day7_table.json, slot_p4_day13_complete.json, slot_p4_day20_reverent.json,
## slot_p4_day20_mixed.json, slot_p4_day25_harvester.json and slot_p4_interior_chest_tools.json
## into --out (then copied to tests/fixtures/saves_v3/).
## Historical tool: on a Phase-5 build it would write v4 saves.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads are ready after the first frame
	var out_dir := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir == "":
		printerr("usage: -- --out=/abs/dir")
		quit(2)
		return
	var driver: RefCounted = load("res://tests/fixtures/saves_v3/make_v3_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
