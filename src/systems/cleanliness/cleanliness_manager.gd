class_name CleanlinessManager
extends Node
## STUB (P3) – docs/PHASE3_DESIGN.md §2.4, §3.4. Systems/Cleanliness (groups cleanliness,
## saveable; save_id "cleanliness", save_order 12). Growth from the difference of game minutes
## (hour_changed / time_skipped), never from ticks.

@export var save_id: String = "cleanliness"
@export var save_order: int = 12


func _init() -> void:
	add_to_group(&"cleanliness", true)
	add_to_group(&"saveable", true)


func spot_ids() -> PackedStringArray:
	return PackedStringArray()


func level(_spot_id: String) -> int:
	return 0


func progress(_spot_id: String) -> float:
	return 0.0


func is_growing(_spot_id: String) -> bool:
	return false


## 0 = not possible (level 0 / rake missing).
func tend_minutes(_spot_id: String, _inv: Inventory) -> int:
	return 0


## Progress 0; dirt_changed, cleanliness_changed.
func tend(_spot_id: String, _inv: Inventory) -> bool:
	return false


func penalty() -> int:
	return 0


func dirty_count(_min_level: int = 2) -> int:
	return 0


## Growth since last_total (hour_changed / time_skipped).
func update_to(_now_total: int) -> void:
	pass


## Only on new_game_started: start_progress from the layout.
func apply_start_state() -> void:
	pass


func save_state() -> Dictionary:
	return {}


## {} → everything 0, last_total = now.
func load_state(_data: Dictionary) -> void:
	pass
