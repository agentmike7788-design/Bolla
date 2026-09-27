extends Node
## Autoload GameState – flags & statistics.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var flags: Dictionary = {}
var stats: Dictionary = {}

func set_flag(flag: StringName, value: Variant = true) -> void:
	push_warning("STUB game_state.gd.set_flag")


func get_flag(flag: StringName, default: Variant = null) -> Variant:
	push_warning("STUB game_state.gd.get_flag")
	return null


func has_flag(flag: StringName) -> bool:
	push_warning("STUB game_state.gd.has_flag")
	return false


func clear_flag(flag: StringName) -> void:
	push_warning("STUB game_state.gd.clear_flag")


func clear_flags() -> void:
	push_warning("STUB game_state.gd.clear_flags")


func add_stat(stat: StringName, amount: int) -> void:
	push_warning("STUB game_state.gd.add_stat")


func get_stat(stat: StringName) -> int:
	push_warning("STUB game_state.gd.get_stat")
	return 0


func reputation_label() -> String:
	push_warning("STUB game_state.gd.reputation_label")
	return ""


func reset() -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
