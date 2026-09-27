extends SceneTree
## Generates the Phase-3 (format v2) save fixtures of docs/PHASE4_DESIGN.md §5.2 by driving the
## real systems of the approved Phase 3 (build febd2c7 / db93727 – run BEFORE any Phase-4 change)
## through Phase3Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v2/make_v2_saves.gd -- --out=/abs/dir
## Writes slot_p3_day5_table.json, slot_p3_day9_night.json, slot_p3_day14_complete.json and
## slot_p3_interior.json into --out (then copied to tests/fixtures/saves_v2/).
## Historical tool: on a Phase-4 build it would write v3 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v2/make_v2_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
