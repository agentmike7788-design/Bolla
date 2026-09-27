class_name SaveFileIO
extends RefCounted
## Save file IO and validation of the SaveManager autoload (docs/VERTICAL_SLICE_DESIGN.md §5):
## slot paths, the write-then-rename of a save document, reading a slot back into {meta, state}
## with format / meta / data checks, and listing the slots on disk. Stateless – no scene tree.

## Phase 3: v2 (docs/PHASE3_DESIGN.md §5). Versions MIN_FORMAT_VERSION…FORMAT_VERSION are read;
## older states are upgraded by SaveMigration after decode_state.
const FORMAT_VERSION := SaveMigration.CURRENT
const MIN_FORMAT_VERSION := 1


static func slot_path(save_dir: String, slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


## make_dir_recursive_absolute with a warning on failure.
static func ensure_dir(save_dir: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		push_warning("[SaveManager] cannot create '%s': %s" % [save_dir, error_string(err)])
	return err


## Save document {"format_version", "meta", "data": JSON.from_native(state)}.
static func make_doc(meta: Dictionary, state: Dictionary) -> Dictionary:
	return {"format_version": FORMAT_VERSION, "meta": meta, "data": JSON.from_native(state)}


## Meta block of a save written now for the world scene `scene_path`.
static func make_meta(scene_path: String) -> Dictionary:
	return {
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"day": TimeManager.day,
		"minute_of_day": TimeManager.minute_of_day,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"scene": scene_path,
	}


## Writes `doc` to the slot file of `slot` (warned on failure).
static func write_doc(save_dir: String, slot: int, doc: Dictionary) -> Error:
	var path := slot_path(save_dir, slot)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		push_warning("[SaveManager] cannot write '%s': %s" % [tmp_path, error_string(open_err)])
		return open_err
	var written := file.store_string(JSON.stringify(doc, "\t", true, true))
	file.close()
	# Write-then-rename: a crash while writing never destroys the previous save.
	var err := DirAccess.rename_absolute(tmp_path, path) if written else ERR_FILE_CANT_WRITE
	if err != OK:
		push_warning("[SaveManager] saving slot %d failed: %s" % [slot, error_string(err)])
		DirAccess.remove_absolute(tmp_path)
	return err


## Slot numbers of files named slot_<n>.json in save_dir.
static func slots_on_disk(save_dir: String) -> Array[int]:
	var out: Array[int] = []
	if not DirAccess.dir_exists_absolute(save_dir):
		return out
	for file_name: String in DirAccess.get_files_at(save_dir):
		if not (file_name.begins_with("slot_") and file_name.ends_with(".json")):
			continue
		var number := file_name.trim_prefix("slot_").trim_suffix(".json")
		if number.is_valid_int() and str(int(number)) == number and int(number) >= 0:
			out.append(int(number))
	return out


## Reads and validates a save file into out = {meta, state}. decode_data=false skips "data".
static func read_doc(save_dir: String, slot: int, out: Dictionary, decode_data: bool = true) -> Error:
	if slot < 0:
		return ERR_INVALID_PARAMETER
	var path := slot_path(save_dir, slot)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return ERR_PARSE_ERROR
	var doc: Dictionary = json.data
	var version: Variant = doc.get("format_version")
	if not (version is float or version is int) or float(version) != roundf(float(version)) \
			or int(version) < MIN_FORMAT_VERSION or int(version) > FORMAT_VERSION:
		return ERR_FILE_UNRECOGNIZED
	if not is_valid_meta(doc.get("meta")):
		return ERR_FILE_CORRUPT
	out["meta"] = doc.meta
	if decode_data:
		var state := decode_state(doc.get("data"))
		if not state.is_empty() and int(version) < FORMAT_VERSION:
			state = SaveMigration.migrate(state, int(version), doc.meta)
		if state.is_empty():
			return ERR_FILE_CORRUPT
		out["state"] = state
	return OK


## True when slot's file is readable JSON whose integral format_version is above
## FORMAT_VERSION (written by a newer build – read_doc rejects it with ERR_FILE_UNRECOGNIZED).
static func is_newer_version(save_dir: String, slot: int) -> bool:
	var path := slot_path(save_dir, slot)
	if slot < 0 or not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return false
	var version: Variant = (json.data as Dictionary).get("format_version")
	return (version is float or version is int) and float(version) == roundf(float(version)) \
			and int(version) > FORMAT_VERSION


static func is_valid_meta(meta: Variant) -> bool:
	if not meta is Dictionary:
		return false
	var m: Dictionary = meta
	for key: String in ["day", "minute_of_day", "saved_unix"]:
		if not (m.get(key) is float or m.get(key) is int):
			return false
	return m.get("scene") is String and m.get("game_version") is String


## Number of raw-number args of the JSON.from_native encoding of the math types (-1 = any count,
## packed arrays).
const NATIVE_MATH_ARGS := {
	"Vector2": 2, "Vector2i": 2, "Rect2": 4, "Rect2i": 4, "Vector3": 3, "Vector3i": 3,
	"Transform2D": 6, "Vector4": 4, "Vector4i": 4, "Plane": 4, "Quaternion": 4, "AABB": 6,
	"Basis": 9, "Transform3D": 12, "Projection": 16, "Color": 4,
	"PackedByteArray": -1, "PackedInt32Array": -1, "PackedInt64Array": -1,
	"PackedFloat32Array": -1, "PackedFloat64Array": -1, "PackedVector2Array": -1,
	"PackedVector3Array": -1, "PackedColorArray": -1, "PackedVector4Array": -1,
}
const NATIVE_PREFIXES := {"s:": "String", "sn:": "StringName", "np:": "NodePath", "i:": "int", "f:": "float"}
const NATIVE_MAX_DEPTH := 64


## True when `v` is a well-formed JSON.from_native encoding (full_objects = false) that
## JSON.to_native decodes without engine errors: tagged strings, bool / null, raw arrays,
## Dictionary / Array envelopes (typed containers only with matching element types) and the
## math / packed types with raw numbers.
static func is_native_json(v: Variant, depth: int = 0) -> bool:
	if depth > NATIVE_MAX_DEPTH:
		return false
	if v == null or v is bool:
		return true
	if v is String:
		return native_type_of(v) != ""
	if v is Array:
		for e: Variant in v:
			if not is_native_json(e, depth + 1):
				return false
		return true
	if not v is Dictionary:
		return false  # raw numbers are not JSON-compliant for to_native
	var d: Dictionary = v
	var type: Variant = d.get("type")
	var args: Variant = d.get("args")
	if not type is String or not args is Array:
		return false
	var list: Array = args
	for key: String in ["key_type", "value_type", "elem_type"]:
		if d.has(key) and not _is_type_name(d[key]):
			return false
	match type:
		"Dictionary":
			if list.size() % 2 != 0:
				return false
			for i: int in list.size():
				var want: Variant = d.get("key_type" if i % 2 == 0 else "value_type", "")
				if not _native_elem_ok(list[i], want, depth):
					return false
			return true
		"Array":
			for e: Variant in list:
				if not _native_elem_ok(e, d.get("elem_type", ""), depth):
					return false
			return true
	if not NATIVE_MATH_ARGS.has(type):
		return false
	var count: int = NATIVE_MATH_ARGS[type]
	if count >= 0 and list.size() != count:
		return false
	for e: Variant in list:
		if not (e is float or e is int):
			return false
	return true


## Variant type name an encoded value decodes to ("" = invalid string / not decodable).
static func native_type_of(v: Variant) -> String:
	if v == null:
		return "Nil"
	if v is bool:
		return "bool"
	if v is String:
		for prefix: String in NATIVE_PREFIXES:
			if (v as String).begins_with(prefix):
				return NATIVE_PREFIXES[prefix]
		return ""
	if v is Array:
		return "Array"
	if v is Dictionary and (v as Dictionary).get("type") is String:
		return (v as Dictionary).type
	return ""


## A builtin Variant type name ("int", "StringName" …) as used for typed containers.
static func _is_type_name(v: Variant) -> bool:
	if not v is String:
		return false
	for t: int in TYPE_MAX:
		if type_string(t) == v:
			return t != TYPE_OBJECT and t != TYPE_NIL
	return false


static func _native_elem_ok(e: Variant, want: Variant, depth: int) -> bool:
	if not is_native_json(e, depth + 1):
		return false
	if want == null or (want is String and want == ""):
		return true
	return want is String and native_type_of(e) == want


## JSON.to_native of the "data" part (never objects); {} unless it yields {autoloads, nodes}.
static func decode_state(data: Variant) -> Dictionary:
	# JSON.to_native logs engine errors on malformed input – check the envelope first.
	if not data is Dictionary:
		return {}
	var envelope: Dictionary = data
	if envelope.get("type") != "Dictionary" or not envelope.get("args") is Array or (envelope.args as Array).size() % 2 != 0:
		return {}
	# QA-07: a damaged value anywhere inside would make JSON.to_native log engine errors.
	if not is_native_json(envelope):
		return {}
	var state: Variant = JSON.to_native(envelope, false)
	if not state is Dictionary:
		return {}
	var d: Dictionary = state
	if not d.get("autoloads") is Dictionary or not d.get("nodes") is Dictionary:
		return {}
	return d
