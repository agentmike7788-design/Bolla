class_name TestCase
extends RefCounted
## Base class for all tests. Put test files in tests/unit/ or tests/integration/,
## name them test_*.gd, extend TestCase and write methods named test_*.
## Methods may be coroutines (use `await tree.process_frame`).
## Optional hooks: before_all(), before_each(), after_each(), after_all().

var tree: SceneTree
var _failures: PackedStringArray = []
var _current: String = ""
## Number of engine errors (push_error / script errors) this test expects.
var _expected_errors: int = 0


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _equal(actual, expected):
		_fail("expected %s, got %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _equal(actual, unexpected):
		_fail("did not expect %s. %s" % [var_to_str(unexpected), message])


func assert_almost(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f ± %f, got %f. %s" % [expected, tolerance, actual, message])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		_fail("expected null, got %s. %s" % [var_to_str(value), message])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_fail("expected a value, got null. " + message)


func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	if not (item in container):
		_fail("expected %s to contain %s. %s" % [var_to_str(container), var_to_str(item), message])


func fail(message: String) -> void:
	_fail(message)


## Declare that this test deliberately triggers `count` engine errors (negative tests).
func expect_errors(count: int) -> void:
	_expected_errors += count


## Waits until `signal_obj` fires or `timeout_sec` passes. Returns true if it fired.
func wait_for_signal(sig: Signal, timeout_sec: float = 5.0) -> bool:
	var fired := [false]
	var cb := func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void: fired[0] = true
	sig.connect(cb, CONNECT_ONE_SHOT)
	var t := 0.0
	while not fired[0] and t < timeout_sec:
		await tree.process_frame
		t += tree.root.get_process_delta_time() if tree.root.get_process_delta_time() > 0.0 else 0.016
	if sig.is_connected(cb):
		sig.disconnect(cb)
	return fired[0]


## Instantiates a scene under the test tree root and waits until it is ready.
func add_scene(path: String) -> Node:
	var node := (load(path) as PackedScene).instantiate()
	tree.root.add_child(node)
	await tree.process_frame
	return node


func wait_frames(count: int = 1) -> void:
	for i: int in count:
		await tree.process_frame


func _equal(a: Variant, b: Variant) -> bool:
	# int/float and String/StringName compare by value; containers compare recursively.
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if (a is String or a is StringName) and (b is String or b is StringName):
		return String(a) == String(b)
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i: int in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in a:
			if not b.has(k) or not _equal(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[%s] %s" % [_current, message])
