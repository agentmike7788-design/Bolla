extends SceneTree
## Generates the Phase-2 (format v1) save fixtures of docs/PHASE3_DESIGN.md §5.2 by driving the
## real systems of the approved Vertical Slice (build 481cb25 – run BEFORE any Phase-3 change):
##   godot --headless --path . -s res://tests/fixtures/saves_v1/make_v1_saves.gd -- --out=/abs/dir
## Writes slot_day3.json, slot_day7_complete.json, slot_interior.json into --out (then copied to
## tests/fixtures/saves_v1/). Historical tool: on a Phase-3 build it would write v2 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v1/make_v1_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
