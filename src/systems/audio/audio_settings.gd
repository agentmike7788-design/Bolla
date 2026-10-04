class_name AudioSettings
extends RefCounted
## Bus volumes (linear 0..1) in the user settings file ([audio] of a ConfigFile, default
## user://settings.cfg) – never in the save game. Missing / broken files fall back to defaults.

const SECTION := "audio"
## Below this linear volume the bus is muted (avoids -inf dB).
const MUTE_BELOW := 0.001


static func load_volumes(path: String, defaults: Dictionary[StringName, float]) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = defaults.duplicate()
	if path == "" or not FileAccess.file_exists(path):
		return out
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		push_warning("[Audio] settings '%s' unreadable – defaults" % path)
		return out
	for bus: StringName in out:
		var v: Variant = cfg.get_value(SECTION, String(bus), out[bus])
		if v is float or v is int:
			out[bus] = clampf(float(v), 0.0, 1.0)
	return out


## Writes only the [audio] section; other sections of the file are kept.
static func save_volumes(path: String, volumes: Dictionary[StringName, float]) -> Error:
	if path == "":
		return ERR_FILE_BAD_PATH
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(path):
		cfg.load(path)
	for bus: StringName in volumes:
		cfg.set_value(SECTION, String(bus), snappedf(volumes[bus], 0.001))
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return cfg.save(path)


static func apply(volumes: Dictionary[StringName, float]) -> void:
	for bus: StringName in volumes:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var v := volumes[bus]
		AudioServer.set_bus_mute(idx, v < MUTE_BELOW)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, MUTE_BELOW)))
