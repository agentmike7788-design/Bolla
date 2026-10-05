extends SceneTree
## Writes the Phase-8 W1 fixtures (docs/PHASE8_DESIGN.md §12 W0) and the five new data/config files:
##   godot --headless --path . -s res://tests/fixtures/phase8/make_phase8_fixtures.gd
## Historical tool of W0 (Lead) – see make_phase8_fixtures_driver.gd.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads are ready after the first frame
	var driver: RefCounted = load("res://tests/fixtures/phase8/make_phase8_fixtures_driver.gd").new()
	var ok: bool = driver.call("run")
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
