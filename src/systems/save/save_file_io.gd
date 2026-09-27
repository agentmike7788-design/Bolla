class_name SaveFileIO
extends RefCounted
## Save file IO and validation of the SaveManager autoload (docs/VERTICAL_SLICE_DESIGN.md §5):
## slot paths, the write-then-rename of a save document, reading a slot back into {meta, state}
## with format / meta / data checks, and listing the slots on disk. Stateless – no scene tree.

const FORMAT_VERSION := 1


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
	if not (version is float or version is int) or float(version) != FORMAT_VERSION:
		return ERR_FILE_UNRECOGNIZED
	if not is_valid_meta(doc.get("meta")):
		return ERR_FILE_CORRUPT
	out["meta"] = doc.meta
	if decode_data:
		var state := decode_state(doc.get("data"))
		if state.is_empty():
			return ERR_FILE_CORRUPT
		out["state"] = state
	return OK


static func is_valid_meta(meta: Variant) -> bool:
	if not meta is Dictionary:
		return false
	var m: Dictionary = meta
	for key: String in ["day", "minute_of_day", "saved_unix"]:
		if not (m.get(key) is float or m.get(key) is int):
			return false
	return m.get("scene") is String and m.get("game_version") is String


## JSON.to_native of the "data" part (never objects); {} unless it yields {autoloads, nodes}.
static func decode_state(data: Variant) -> Dictionary:
	# JSON.to_native logs engine errors on malformed input – check the envelope first.
	if not data is Dictionary:
		return {}
	var envelope: Dictionary = data
	if envelope.get("type") != "Dictionary" or not envelope.get("args") is Array or (envelope.args as Array).size() % 2 != 0:
		return {}
	var state: Variant = JSON.to_native(envelope, false)
	if not state is Dictionary:
		return {}
	var d: Dictionary = state
	if not d.get("autoloads") is Dictionary or not d.get("nodes") is Dictionary:
		return {}
	return d
