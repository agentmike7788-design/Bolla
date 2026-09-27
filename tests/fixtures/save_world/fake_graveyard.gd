extends "res://tests/fixtures/save_world/saveable_probe.gd"
## Test double for Graveyard (group "graveyard"): logs broadcast_state().


func broadcast_state() -> void:
	_log("broadcast")
