extends TestCase
## G8 Runde 3 QA (user after the browser test: „er kam ohne karren und hat die leiche abgelegt"): Godot 4.7.2 emptied
## every Packed*Array when the export converted text resources to binary (editor/export/convert_text_resources_to_binary,
## default true). In the browser build Osric's schedule had no waypoints – he and his cart stayed at road_end while the
## unloading pose carried the corpse from there to the bier –, the corpse names, the chatter lines, the atmosphere's
## blend minutes (bright nights) were gone. Guard: the setting stays off, and a real export of the Web preset into a
## temporary pck keeps every Packed*Array of every resource / scene that stores one (fingerprints compared with the
## sources in a second Godot process, tests/fixtures/export_packed_probe.gd).

const SETTING := "editor/export/convert_text_resources_to_binary"
const PROBE := "res://tests/fixtures/export_packed_probe.gd"
const PRESET := "Web"
const ROOTS: PackedStringArray = ["res://data", "res://src"]
const MARKER := "Packed"
var TEMP := TestCase.user_dir("test_export_packed_arrays")


func after_each() -> void:
	TestCase.remove_user_dir(TEMP)


func test_text_resources_are_not_converted_on_export() -> void:
	assert_true(ProjectSettings.has_setting(SETTING), "%s is set in project.godot" % SETTING)
	assert_false(bool(ProjectSettings.get_setting(SETTING, true)), "the export keeps text resources (Packed*Array bug)")


func test_carter_schedule_has_waypoints() -> void:
	var sched := Database.schedule(&"carter") as NpcSchedule
	assert_not_null(sched)
	for e: ScheduleEntry in sched.entries:
		assert_false(e.path.is_empty(), "%s %d has a path" % [e.activity, e.start_minute])


func test_exported_pck_keeps_every_packed_array() -> void:
	var files := _files_with_packed_arrays()
	assert_true(files.size() > 50, "resources with Packed*Arrays found (%d)" % files.size())
	var probe: GDScript = load(PROBE)
	var expected: Dictionary = probe.call(&"fingerprints", files)
	assert_true(expected.size() > 100, "fingerprints of the sources (%d)" % expected.size())
	DirAccess.make_dir_recursive_absolute(TEMP)
	var dir := ProjectSettings.globalize_path(TEMP)
	var pck := dir.path_join("probe.pck")
	var list := dir.path_join("files.txt")
	var out := dir.path_join("exported.json")
	var lf := FileAccess.open(list, FileAccess.WRITE)
	lf.store_string("\n".join(files))
	lf.close()
	var exe := OS.get_executable_path()
	var output: Array = []
	var code := OS.execute(exe, PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--export-pack", PRESET, pck]), output, true)
	var text := "\n".join(PackedStringArray(output))
	if code != 0 and text.to_lower().contains("template"):
		print("  [skip] no export templates for '%s' on this machine – only the setting is checked" % PRESET)
		return
	assert_eq(code, 0, "export of the %s preset into a temporary pck" % PRESET)
	assert_true(FileAccess.file_exists(pck), "pck written")
	output.clear()
	code = OS.execute(exe, PackedStringArray(["--headless", "--main-pack", pck, "-s", ProjectSettings.globalize_path(PROBE),
			"--", "--list=" + list, "--out=" + out]), output, true)
	assert_eq(code, 0, "probe on the exported pck")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out))
	assert_true(parsed is Dictionary, "probe result")
	if not parsed is Dictionary:
		return
	var got := parsed as Dictionary
	var wrong: PackedStringArray = []
	for key: String in expected:
		if str(got.get(key, "absent")) != str(expected[key]):
			wrong.append("%s: %s → %s" % [key, expected[key], got.get(key, "absent")])
	assert_true(wrong.is_empty(), "%d Packed*Arrays changed in the export, e.g. %s" % [wrong.size(), ", ".join(wrong.slice(0, 5))])
	DirAccess.remove_absolute(pck)


## Every .tres / .tscn under ROOTS whose text stores a Packed*Array.
func _files_with_packed_arrays() -> PackedStringArray:
	var out: PackedStringArray = []
	var stack: PackedStringArray = ROOTS.duplicate()
	while not stack.is_empty():
		var dir: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		for sub: String in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f: String in DirAccess.get_files_at(dir):
			if not (f.ends_with(".tres") or f.ends_with(".tscn")):
				continue
			var path := dir.path_join(f)
			var text := FileAccess.get_file_as_string(path)
			if text.contains(MARKER) and text.contains("Array("):
				out.append(path)
	out.sort()
	return out
