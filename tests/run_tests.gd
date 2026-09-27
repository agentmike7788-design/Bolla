extends SceneTree
## Headless smoke test runner.
## Usage: godot --headless --path . -s res://tests/run_tests.gd

var _failures: int = 0


func _initialize() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/boot/main.tscn", "main scene configured")
	_check(load("res://src/boot/main.tscn") is PackedScene, "main scene loads")
	for action: String in ["move_up", "move_down", "move_left", "move_right", "interact", "debug_toggle"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)
	_check(root.has_node("EventBus"), "EventBus autoload present")
	_check(root.has_node("GameConfig"), "GameConfig autoload present")
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	print("  [%s] %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		_failures += 1
