extends Node
## Autoload GameState – story flags & statistics (docs/VERTICAL_SLICE_DESIGN.md §3.4).
## flags: StringName -> bool/int/float/String. stats: StringName -> int (default keys below).

const DEFAULT_STATS: Array[StringName] = [&"burials", &"valuables_taken", &"reputation", &"missed_deliveries", &"days_played"]
const LABEL_RESPECTED := "Geachtet"
const LABEL_UNREMARKABLE := "Unauffällig"
const LABEL_DISREPUTABLE := "Verrufen"

var flags: Dictionary = {}
var stats: Dictionary = {}
## Reputation thresholds source; null = data/config/economy_config.tres (resolved lazily).
var economy: EconomyConfig


func _ready() -> void:
	reset()


## Stores a flag. Allowed values: bool, int, float, String (StringName is stored as String).
func set_flag(flag: StringName, value: Variant = true) -> void:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			flags[flag] = value
		TYPE_STRING_NAME:
			flags[flag] = String(value)
		_:
			push_warning("[GameState] flag '%s': unsupported value type %s ignored" % [flag, type_string(typeof(value))])


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return flags.get(flag, default)


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


func clear_flag(flag: StringName) -> void:
	flags.erase(flag)


func clear_flags() -> void:
	flags.clear()


func add_stat(stat: StringName, amount: int) -> void:
	stats[stat] = get_stat(stat) + amount


## Unknown stats read as 0.
func get_stat(stat: StringName) -> int:
	return int(stats.get(stat, 0))


## "Geachtet" / "Unauffällig" / "Verrufen" from EconomyConfig.reputation_thresholds.
func reputation_label() -> String:
	var thresholds := _economy().reputation_thresholds
	if thresholds.size() < 2:
		thresholds = EconomyConfig.new().reputation_thresholds
	var rep := get_stat(&"reputation")
	if rep <= thresholds[1]:
		return LABEL_DISREPUTABLE
	if rep <= thresholds[0]:
		return LABEL_UNREMARKABLE
	return LABEL_RESPECTED


## No flags, all default stats 0. Dictionaries are cleared in place (references stay valid).
func reset() -> void:
	_clear_values()
	economy = null


func save_state() -> Dictionary:
	return {"flags": flags.duplicate(true), "stats": stats.duplicate(true)}


## Replaces flags and stats completely; missing default stats become 0.
func load_state(data: Dictionary) -> void:
	_clear_values()
	var saved_flags: Variant = data.get("flags", {})
	if saved_flags is Dictionary:
		for key: Variant in saved_flags:
			set_flag(StringName(str(key)), (saved_flags as Dictionary)[key])
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for key: Variant in saved_stats:
			var value: Variant = (saved_stats as Dictionary)[key]
			if value is int or value is float:
				stats[StringName(str(key))] = int(value)
			else:
				push_warning("[GameState] stat '%s': non-numeric value ignored" % key)


func _clear_values() -> void:
	flags.clear()
	stats.clear()
	for key: StringName in DEFAULT_STATS:
		stats[key] = 0


func _economy() -> EconomyConfig:
	if economy == null:
		economy = Database.config(&"economy_config") as EconomyConfig
		if economy == null:
			economy = EconomyConfig.new()
	return economy
