extends SceneTree
## Generates the Phase-6 (format v5) save fixtures of docs/PHASE7_DESIGN.md §5.2 by driving the
## real systems of the approved Phase 6 (build 705bd5a / f7d5cc5 – run BEFORE any Phase-7 change)
## through Phase6Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v5/make_v5_saves.gd -- --out=/abs/dir [--only=day40r,…]
## Keys: day40r, day45h, day41m, day37f, day37eve, crypt, chapel. Writes slot_p6_day40_reverent,
## slot_p6_day45_harvester, slot_p6_day41_mender, slot_p6_day37_founder, slot_p6_day37_eve,
## slot_p6_crypt_table and slot_p6_chapel_carry (.json) into --out (then copied to
## tests/fixtures/saves_v5/).
## Historical tool: on a Phase-7 build it would write v6 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v5/make_v5_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
