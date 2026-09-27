extends SceneTree
## Test runner (docs/VERTICAL_SLICE_DESIGN.md §9).
##   godot --headless --path . -s res://tests/run_tests.gd [-- --filter=<text>]
## Discovers tests/unit/test_*.gd and tests/integration/test_*.gd; every test_* method
## runs on a fresh instance. Before each method the autoloads are reset; afterwards new
## root children and the current scene are freed. Engine errors during a test fail it.
## Exit codes: 0 = all passed, 1 = test failures, 2 = runner error / timeout / no tests.

const DIRS: PackedStringArray = ["res://tests/unit", "res://tests/integration"]
const DEFAULT_TIMEOUT := 20.0
const RESET_AUTOLOADS: PackedStringArray = ["TimeManager", "GameState", "SaveManager", "UIState"]


class ErrorCapture extends Logger:
	var errors: PackedStringArray = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		errors.append("%s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		mutex.unlock()
		return out


var _passed: int = 0
var _failed: PackedStringArray = []
var _capture := ErrorCapture.new()
var _deadline_ms: int = 0
var _running_label: String = ""


func _initialize() -> void:
	OS.add_logger(_capture)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if _deadline_ms > 0 and Time.get_ticks_msec() > _deadline_ms:
		printerr("TIMEOUT in ", _running_label)
		print("RESULT: TIMEOUT (%s)" % _running_label)
		quit(2)
	return false


func _run() -> void:
	await process_frame  # autoload _ready() has run after the first frame
	var filter := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
	var files := _discover()
	var ran := 0
	for path: String in files:
		if filter != "" and not path.contains(filter):
			continue
		ran += 1
		await _run_file(path)
	print("")
	for f: String in _failed:
		print("  FAILED: ", f)
	if ran == 0 or _passed + _failed.size() == 0:
		print("RESULT: NO TESTS")
		quit(2)
		return
	print("RESULT: %s (%d passed, %d failed)" % ["PASS" if _failed.is_empty() else "FAIL", _passed, _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _discover() -> PackedStringArray:
	var files: PackedStringArray = []
	for dir: String in DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f: String in DirAccess.get_files_at(dir):
			if f.begins_with("test_") and f.ends_with(".gd"):
				files.append(dir.path_join(f))
	files.sort()
	return files


func _run_file(path: String) -> void:
	_capture.take()
	var script := load(path) as GDScript
	var load_errors := _capture.take()
	if script == null or not script.can_instantiate() or not load_errors.is_empty():
		_failed.append("%s (script failed to load) %s" % [path, str(load_errors)])
		return
	var probe: Variant = script.new()
	if not probe is TestCase:
		_failed.append("%s (does not extend TestCase)" % path)
		return
	var timeout: float = DEFAULT_TIMEOUT
	if script.get_script_constant_map().has("TIMEOUT"):
		timeout = float(script.get_script_constant_map()["TIMEOUT"])
	print("-- ", path.get_file())
	var methods: PackedStringArray = []
	for m: Dictionary in script.get_script_method_list():
		var mname: String = m.name
		if mname.begins_with("test_") and not mname in methods:
			methods.append(mname)
	var shared: TestCase = probe
	shared.tree = self
	if shared.has_method("before_all"):
		await shared.call("before_all")
	for mname: String in methods:
		await _run_method(script, path, mname, timeout)
	if shared.has_method("after_all"):
		await shared.call("after_all")
	_capture.take()


func _run_method(script: GDScript, path: String, mname: String, timeout: float) -> void:
	_reset_autoloads()
	var before := root.get_children()
	var t: TestCase = script.new()
	t.tree = self
	t._current = "%s::%s" % [path.get_file(), mname]
	_running_label = t._current
	_deadline_ms = Time.get_ticks_msec() + int(timeout * 1000.0)
	_capture.take()
	if t.has_method("before_each"):
		await t.call("before_each")
	await Callable(t, mname).call()
	if t.has_method("after_each"):
		await t.call("after_each")
	_deadline_ms = 0
	await _cleanup(before)
	var errors := _capture.take()
	if errors.size() > t._expected_errors:
		for e: String in errors:
			t._failures.append("engine error: " + e)
	elif errors.size() < t._expected_errors:
		t._failures.append("expected %d engine error(s), got %d" % [t._expected_errors, errors.size()])
	if t._failures.is_empty():
		_passed += 1
		print("  [OK] ", mname)
	else:
		for msg: String in t._failures:
			_failed.append("%s: %s" % [t._current, msg])
		print("  [FAIL] ", mname, " — ", t._failures[0])


func _reset_autoloads() -> void:
	paused = false
	for n: String in RESET_AUTOLOADS:
		var node := root.get_node_or_null(n)
		if node and node.has_method("reset"):
			node.call("reset")


func _cleanup(before: Array[Node]) -> void:
	if current_scene:
		unload_current_scene()
	for child: Node in root.get_children():
		if not child in before:
			child.queue_free()
	await process_frame
	await process_frame
