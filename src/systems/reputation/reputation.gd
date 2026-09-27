class_name Reputation
extends Node
## STUB (P3) – docs/PHASE3_DESIGN.md §2.6, §3.4. Systems/Reputation (group &"reputation"; the
## value lives in GameState.stats.reputation, flag rep_last_day). Events are called directly by
## the triggering system (change / event), never from signal listeners.


func _init() -> void:
	add_to_group(&"reputation", true)


func value() -> int:
	return 0


func tier() -> StringName:
	return &""


## Clamps, writes GameState.stats.reputation, reputation_changed.
func change(_delta: int, _reason: String) -> void:
	pass


## ReputationConfig.event_points[kind]
func event(_kind: StringName, _reason: String) -> void:
	pass


## Idempotent per day (flag rep_last_day): {drift, stipend}; on day_started.
func apply_daily(_day: int) -> Dictionary:
	return {}


## Drift the next day change would bring (HUD arrow).
func forecast() -> int:
	return 0


## For the day summary.
func last_daily() -> Dictionary:
	return {}
