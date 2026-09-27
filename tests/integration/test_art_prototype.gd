extends TestCase
## Phase 1 regression: the approved art-direction prototype (ART STYLE LOCK reference).

const PROTO := "res://src/world/art_prototype/art_prototype.tscn"


func test_scene_structure() -> void:
	var scene := (load(PROTO) as PackedScene).instantiate()
	for path: String in ["WorldEnvironment", "Sun", "Atmosphere", "Ground", "Graves", "Fence", "Hut", "Tree",
			"LanternPost", "Props", "Grass", "Player", "CameraRig/Camera3D", "HUD/Hint"]:
		assert_true(scene.has_node(path), "node '%s'" % path)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_prototype/layout.json"))
	assert_eq(scene.get_node("Graves").get_child_count(), layout.graves.size(), "grave count")
	var atmo := scene.get_node("Atmosphere")
	assert_eq((atmo.get("presets") as Array).size(), 2, "day + night presets")
	assert_true(atmo.get("world_environment") != null and atmo.get("sun") != null, "atmosphere refs")
	var lights := scene.find_children("Light_*", "OmniLight3D", true, false)
	assert_true(lights.size() >= 5, "warm lights (%d)" % lights.size())
	var shadowed := 0
	for l: Node in lights:
		assert_true(l.is_in_group("warm_lights") and l.has_meta("base_energy"), "light grouped: " + l.name)
		if (l as Light3D).shadow_enabled:
			shadowed += 1
	assert_true(shadowed <= 4, "shadow lights within budget")
	var mm := (scene.get_node("Grass") as MultiMeshInstance3D).multimesh
	assert_eq(mm.instance_count, int(layout.grass.count), "grass tufts")
	scene.free()


func test_all_surfaces_use_shared_materials() -> void:
	var scene := (load(PROTO) as PackedScene).instantiate()
	var bad: PackedStringArray = []
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (n as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat == null or not mat.resource_path.begins_with("res://assets/materials/"):
				bad.append(n.name)
	assert_true(bad.is_empty(), "surfaces without shared material: %s" % str(bad))
	scene.free()
