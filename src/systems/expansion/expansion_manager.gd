class_name ExpansionManager
extends Node
## STUB (P1) – docs/PHASE3_DESIGN.md §3.4 "Ausbau". Systems/Expansion (groups expansion,
## saveable; save_id "expansion", save_order 5). Collects all nodes of group &"clearable" in
## _ready. Obstacle state lives here only (ClearableObstacle is not saved).

@export var save_id: String = "expansion"
@export var save_order: int = 5


func _init() -> void:
	add_to_group(&"expansion", true)
	add_to_group(&"saveable", true)


## All sections, sorted by SectionData.order.
func sections() -> Array[SectionData]:
	return []


func is_unlocked(_section_id: StringName) -> bool:
	return false


## SectionData.order of the unlocked sections (for BuildGrid).
func unlocked_indices() -> PackedInt32Array:
	return PackedInt32Array()


## "" = workable; otherwise the display text of the missing prerequisite.
func block_reason(_section_id: StringName) -> String:
	return ""


func is_cleared(_obstacle_id: String) -> bool:
	return false


func obstacle_ids(_section_id: StringName) -> PackedStringArray:
	return PackedStringArray()


## (done, total)
func progress(_section_id: StringName) -> Vector2i:
	return Vector2i.ZERO


## {item_id: amount} still missing to clear `obstacle_id`.
func missing_cost(_obstacle_id: String, _inv: Inventory) -> Dictionary:
	return {}


## Prerequisite met, cost available, yield fits.
func can_clear(_obstacle_id: String, _inv: Inventory) -> bool:
	return false


## Atomic: cost off, yield in, obstacle_cleared, section_progress_changed; the last one unlocks.
func clear(_obstacle_id: String, _inv: Inventory) -> bool:
	return false


## Graveyard.unlock_section, reputation +4, section_unlocked, notification (also via debug).
func unlock(_section_id: StringName) -> bool:
	return false


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass


## Unlocked sections without free plots → repair (warning).
func post_load() -> void:
	pass
