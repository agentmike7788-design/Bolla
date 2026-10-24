extends SceneTree
## Ist-Messung of the old tariff (docs/PHASE10_DESIGN.md §12.1 W0, §2.3): a new game to day 91 through the founder chain of
## EconomyCurveBot (tests/integration/economy_curve_bot.gd), the table of docs/reviews/phase10_wip/ist_kurve.md:
##   godot --headless --path . -s res://tools/economy/ist_kurve.gd -- --out=/abs/file.md [--days=91]
## On a W1+ build it measures the new tariff (P1: curve10).

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads are ready after the first frame
	var out := ""
	var days := 91
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--days="):
			days = int(arg.trim_prefix("--days="))
	if out == "":
		printerr("usage: -- --out=/abs/file.md [--days=91]")
		quit(2)
		return
	# Autoloads are no identifiers while a -s script compiles (make_v8_saves.gd uses a driver for that).
	root.get_node(^"SaveManager").set(&"save_dir", out.get_base_dir().path_join("ist_kurve_saves"))
	var script := load("res://tests/integration/economy_curve_bot.gd") as GDScript
	var bot: RefCounted = script.new(self, days)
	await bot.call("run")
	var head := "Ist-Kurve (alter Tarif) – neues Spiel bis Tag %d, Kette %s" % [days, str(bot.get("stage_days"))]
	var text: String = bot.call("report", head)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	print("RESULT: OK")
	quit(0)
