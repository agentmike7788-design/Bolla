extends SceneTree
## Generates the Phase-9 (format v8) save fixtures of docs/PHASE10_DESIGN.md §5.3 by driving the real
## systems of the approved Phase 9 (G9, branch state f024103 = code of 6f0bd9c + contract only – run BEFORE any
## Phase-10 change) through Phase9Bot / Phase7Bot / Phase6Bot:
##   godot --headless --path . -s res://tests/fixtures/saves_v8/make_v8_saves.gd -- --out=/abs/dir [--only=kindly,…]
## Keys: kindly, trader, stay, founder, village, new. Writes slot_p9_day75_kindly, slot_p9_day75_trader,
## slot_p9_day75_stay, slot_p9_founder, slot_p9_day38_village and slot_p9_day29_new (.json) into --out (then copied
## to tests/fixtures/saves_v8/, next to slot_p9_mid_h4.json).
## Historical tool: on a Phase-10 build it would write v9 saves.

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
	var driver: RefCounted = load("res://tests/fixtures/saves_v8/make_v8_saves_driver.gd").new()
	var ok: bool = await driver.call("run", self, out_dir)
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
