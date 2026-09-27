extends Node
## Autoload TimeManager – game clock.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var config: TimeConfig
var day: int = 1
var minute_of_day: int = 0
var running: bool = false
var paused: bool:
	get:
		return false

func push_pause(reason: StringName) -> void:
	push_warning("STUB time_manager.gd.push_pause")


func pop_pause(reason: StringName) -> void:
	push_warning("STUB time_manager.gd.pop_pause")


func clear_pauses() -> void:
	push_warning("STUB time_manager.gd.clear_pauses")


func advance(minutes: int) -> void:
	push_warning("STUB time_manager.gd.advance")


func set_time(new_day: int, new_minute_of_day: int) -> void:
	push_warning("STUB time_manager.gd.set_time")


func minutes_until(target_minute_of_day: int) -> int:
	push_warning("STUB time_manager.gd.minutes_until")
	return 0


func get_minute_f() -> float:
	push_warning("STUB time_manager.gd.get_minute_f")
	return 0.0


func total_minutes() -> int:
	push_warning("STUB time_manager.gd.total_minutes")
	return 0


func is_night() -> bool:
	push_warning("STUB time_manager.gd.is_night")
	return false


func format_clock() -> String:
	push_warning("STUB time_manager.gd.format_clock")
	return ""


func emit_refresh() -> void:
	push_warning("STUB time_manager.gd.emit_refresh")


func reset() -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
