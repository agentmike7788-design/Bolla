class_name BuildMode
extends Node
## STUB (P2) – docs/PHASE3_DESIGN.md §3.4, §3.6. Systems/BuildMode (group build_mode, not
## saved; loading / scene change ends it). Mouse picks the cell (user decision §14.3): left
## click / [E] place, right click / [X] remove, R / wheel rotate, 1–8 select, Esc / B leave.

var active: bool = false
var selected: StringName = &""
var rotation_step: int = 0


func _init() -> void:
	add_to_group(&"build_mode", true)


## Only outdoors, hands free, not busy, no modal; build_mode_changed(true).
func enter() -> bool:
	return false


func exit() -> void:
	pass


func toggle() -> void:
	pass


## DECOR items in the inventory (order = build bar).
func available() -> Array[StringName]:
	return []


func select(_decor_id: StringName) -> void:
	pass


func rotate() -> void:
	pass


## Cell under the mouse (ray camera → ground plane y = 0), clamped to DecorConfig.cursor_reach
## around the gravekeeper; without mouse motion since entering / out of reach: the cell in
## front of the gravekeeper (keyboard fallback).
func cursor_cell() -> Vector2i:
	return Vector2i.ZERO


## can_place at the cursor.
func cursor_reason() -> StringName:
	return &"blocked"


## Decor under the cursor (for removing).
func focused_placement() -> DecorPlacement:
	return null


## Timed action 5 min, not cancelled by rotating.
func confirm_place() -> bool:
	return false


func confirm_remove() -> bool:
	return false
