class_name GhostManager
extends Node
## STUB (P4) – docs/PHASE3_DESIGN.md §2.8, §3.4. Systems/Ghosts (groups ghosts, saveable;
## save_id "ghosts", save_order 30). Pool of max_active Ghost nodes under container_path; the
## nearest eligible graves, re-selected every reselect_seconds with hysteresis.

@export var ghost_scene: PackedScene
## Decor/Ghosts
@export var container_path: NodePath
@export var save_id: String = "ghosts"
@export var save_order: int = 30


func _init() -> void:
	add_to_group(&"ghosts", true)
	add_to_group(&"saveable", true)


## appear_minute … vanish_minute (wraps over midnight).
func is_ghost_time(_minute_of_day: int) -> bool:
	return false


## 0..1
func fade_at(_minute_f: float) -> float:
	return 0.0


func eligible_graves() -> PackedStringArray:
	return PackedStringArray()


func mood_of(_grave_id: String) -> StringName:
	return &""


func active_ghosts() -> Array[Ghost]:
	return []


## Text; gift once per grave; ghost_spoke; flag ghosts_seen.
func listen(_grave_id: String, _player: Player) -> String:
	return ""


## {gifts: {grave_id: day}, heard: {grave_id: day}}
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
