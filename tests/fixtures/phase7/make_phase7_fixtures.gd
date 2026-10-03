extends SceneTree
## Writes the Phase-7 W1 fixtures (docs/PHASE7_DESIGN.md §12 W0) – see make_phase7_fixtures_driver.gd:
##   godot --headless --path . -s res://tests/fixtures/phase7/make_phase7_fixtures.gd
## Historical tool of W0 (Lead); the fixtures are the contract snapshot.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads are ready after the first frame
	var driver: RefCounted = load("res://tests/fixtures/phase7/make_phase7_fixtures_driver.gd").new()
	var ok: bool = driver.call("run")
	print("RESULT: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
