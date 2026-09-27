extends TestCase
## Phase 0/1 regression: project configuration.


func test_main_scene_configured() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://src/boot/main.tscn")
	assert_true(load("res://src/boot/main.tscn") is PackedScene)


func test_input_actions_exist() -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right", "interact", "drop", "inventory",
			"pause", "quick_save", "quick_load", "debug_toggle", "camera_zoom_in", "camera_zoom_out",
			"proto_toggle_camera", "proto_toggle_time"]:
		assert_true(InputMap.has_action(action), "input action '%s'" % action)


func test_autoloads_present() -> void:
	for n: String in ["EventBus", "GameConfig", "Database", "TimeManager", "GameState", "SaveManager", "Debug"]:
		assert_true(tree.root.has_node(n), "autoload " + n)
