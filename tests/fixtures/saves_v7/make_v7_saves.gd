extends SceneTree
## Generates the Phase-8 (format v7) save fixtures of docs/PHASE9_DESIGN.md §5.3 by driving the real
## systems of the approved Phase 8 (G8 incl. Runde 6, build 10e310e – run BEFORE any Phase-9 change)
## through Phase8Bot / HillBot / Phase7Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v7/make_v7_saves.gd -- --out=/abs/dir [--only=kindly,…]
## Keys: kindly, anatomist, letgo, founder, mid, day2, village. Writes slot_p8_day63_kindly,
## slot_p8_day63_anatomist, slot_p8_day63_letgo, slot_p8_founder, slot_p8_mid, slot_p8_day2_hill and
## slot_p8_day30_village_hill (.json) into --out (then copied to tests/fixtures/saves_v7/).
## Historical tool: on a Phase-9 build it would write v8 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v7/make_v7_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
