extends SceneTree
## Headless test runner.
## Usage: godot --headless --path . -s res://tests/run_tests.gd   (exit code 0 = PASS)

const PROTO := "res://src/world/art_prototype/art_prototype.tscn"

var _failures: int = 0


func _initialize() -> void:
	_test_project_setup()
	_test_art_prototype()
	print("RESULT: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _test_project_setup() -> void:
	print("-- project setup")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/boot/main.tscn", "main scene configured")
	_check(load("res://src/boot/main.tscn") is PackedScene, "main scene loads")
	for action: String in ["move_up", "move_down", "move_left", "move_right", "interact", "debug_toggle",
			"camera_zoom_in", "camera_zoom_out", "proto_toggle_camera", "proto_toggle_time"]:
		_check(InputMap.has_action(action), "input action '%s' exists" % action)
	_check(root.has_node("EventBus"), "EventBus autoload present")
	_check(root.has_node("GameConfig"), "GameConfig autoload present")


func _test_art_prototype() -> void:
	print("-- art prototype")
	var ps := load(PROTO) as PackedScene
	_check(ps != null, "prototype scene loads")
	if ps == null:
		return
	var scene := ps.instantiate()
	for path: String in ["WorldEnvironment", "Sun", "Atmosphere", "Ground", "Graves", "Fence", "Hut", "Tree",
			"LanternPost", "Props", "Grass", "Player", "CameraRig/Camera3D", "HUD/Hint"]:
		_check(scene.has_node(path), "node '%s' present" % path)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_prototype/layout.json"))
	_check(scene.get_node("Graves").get_child_count() == layout.graves.size(), "grave count matches layout")
	var stones := {}
	for g: Dictionary in layout.graves:
		stones[g.stone] = true
	_check(stones.size() >= 4, "at least 4 different gravestone types")
	var atmo := scene.get_node("Atmosphere")
	_check((atmo.get("presets") as Array).size() == 2, "day + night presets assigned")
	_check(atmo.get("world_environment") != null and atmo.get("sun") != null, "atmosphere references resolved")
	var lights := scene.find_children("Light_*", "OmniLight3D", true, false)
	_check(lights.size() >= 5, "warm lights attached to markers (%d)" % lights.size())
	var grouped := 0
	for l: Node in lights:
		if l.is_in_group("warm_lights") and l.has_meta("base_energy"):
			grouped += 1
	_check(grouped == lights.size(), "all warm lights grouped with base energy")
	var shadowed := 0
	for l: Node in lights:
		if (l as Light3D).shadow_enabled:
			shadowed += 1
	_check(shadowed <= 4, "shadow-casting omni lights within budget (%d <= 4)" % shadowed)
	var mm := (scene.get_node("Grass") as MultiMeshInstance3D).multimesh
	_check(mm != null and mm.instance_count == int(layout.grass.count), "grass multimesh has %d tufts" % int(layout.grass.count))
	_check((scene.get_node("CameraRig") as Node).get("target") != null, "camera follows player")
	_check_materials(scene)
	scene.free()


## Every mesh surface must use one of the shared project materials (import mapping works).
func _check_materials(scene: Node) -> void:
	var bad: PackedStringArray = []
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat == null or not mat.resource_path.begins_with("res://assets/materials/"):
				bad.append(n.name)
	_check(bad.is_empty(), "all surfaces use shared materials %s" % ("" if bad.is_empty() else str(bad)))


func _check(condition: bool, label: String) -> void:
	print("  [%s] %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		_failures += 1
