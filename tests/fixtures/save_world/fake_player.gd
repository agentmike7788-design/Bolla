extends "res://tests/fixtures/save_world/saveable_probe.gd"
## Test double for Player (group "player"): is_busy() is controlled by the test.

var busy: bool = false


func is_busy() -> bool:
	return busy
