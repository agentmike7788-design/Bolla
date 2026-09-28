extends SceneTree
## Generates the Phase-5 (format v4) save fixtures of docs/PHASE6_DESIGN.md §5.2 by driving the
## real systems of the approved Phase 5 (build c5bd76d / cd1620e – run BEFORE any Phase-6 change)
## through Phase5Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v4/make_v4_saves.gd -- --out=/abs/dir [--only=day30r,…]
## Keys: day30r, day35h, day30m, day16t, day16c, day20c, interior. Writes slot_p5_day30_reverent,
## slot_p5_day35_harvester, slot_p5_day30_mender, slot_p5_day16_table, slot_p5_day16_carry,
## slot_p5_day20_crafter and slot_p5_interior (.json) into --out (then copied to
## tests/fixtures/saves_v4/).
## Historical tool: on a Phase-6 build it would write v5 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v4/make_v4_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
