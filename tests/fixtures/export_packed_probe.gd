extends SceneTree
## Fixture of test_export_packed_arrays.gd: every Packed*Array stored in a list of resources / scenes, as a fingerprint
## {"<file>|<property path>": "<type>:<size>:<hash>"}. Run in a second Godot process against an exported pck
## (--main-pack <pck> -s <this file> -- --list=<txt> --out=<json>) and called in the test process on the sources
## (fingerprints()); both must be equal. Self-contained (tests/ is not exported): no class names of the project.
## G8 Runde 3 QA: Godot's export conversion to binary (editor/export/convert_text_resources_to_binary) emptied them –
## Osric's schedule had no waypoints in the browser, he stayed at road_end with his cart.


func _initialize() -> void:
	var list := ""
	var out := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--list="):
			list = arg.trim_prefix("--list=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var paths := FileAccess.get_file_as_string(list).split("\n", false)
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(fingerprints(paths)))
		f.close()
	quit(0 if f != null else 1)


static func fingerprints(paths: PackedStringArray) -> Dictionary:
	var out := {}
	for path: String in paths:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			out[path + "|<load>"] = "missing"
			continue
		var seen := {}
		if res is PackedScene:
			var state := (res as PackedScene).get_state()
			for n: int in state.get_node_count():
				var node := String(state.get_node_path(n))
				for p: int in state.get_node_property_count(n):
					_value(out, seen, path, "%s:%s" % [node, state.get_node_property_name(n, p)], state.get_node_property_value(n, p))
		else:
			_resource(out, seen, path, "", res)
	return out


static func _resource(out: Dictionary, seen: Dictionary, file: String, at: String, res: Resource) -> void:
	if res == null or seen.has(res.get_instance_id()):
		return
	# Only the file's own (sub-)resources: ext resources are fingerprinted as files of their own.
	if res.resource_path != "" and res.resource_path != file and not res.resource_path.begins_with(file + "::"):
		return
	seen[res.get_instance_id()] = true
	for prop: Dictionary in res.get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var name := String(prop.name)
		if name == "script" or name.begins_with("resource_"):
			continue
		_value(out, seen, file, at + "/" + name, res.get(name))


static func _value(out: Dictionary, seen: Dictionary, file: String, at: String, v: Variant) -> void:
	var t := typeof(v)
	if t >= TYPE_PACKED_BYTE_ARRAY and t <= TYPE_PACKED_VECTOR4_ARRAY:
		out["%s|%s" % [file, at]] = "%s:%d:%d" % [type_string(t), v.size(), hash(v)]
	elif v is Resource:
		_resource(out, seen, file, at, v as Resource)
	elif v is Array:
		var a := v as Array
		for i: int in a.size():
			_value(out, seen, file, "%s[%d]" % [at, i], a[i])
	elif v is Dictionary:
		var d := v as Dictionary
		for k: Variant in d:
			_value(out, seen, file, "%s{%s}" % [at, str(k)], d[k])
