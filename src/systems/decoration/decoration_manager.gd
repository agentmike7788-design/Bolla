class_name DecorationManager
extends Node
## STUB (P2) – docs/PHASE3_DESIGN.md §3.4. Systems/Decorations (groups decorations, saveable;
## save_id "decorations", save_order 15). Owns the placements; load_state re-creates the
## PlacedDecor nodes under container_path (the world's _ready creates none).
## can_place reasons besides BuildGrid.check: &"no_item", &"limit" (place_max / max_placed),
## &"player" (capsule inside the footprint), &"corpse" (corpse on the ground).

@export var mask: BuildMask
## Decor/Placed
@export var container_path: NodePath
@export var save_id: String = "decorations"
@export var save_order: int = 15


func _init() -> void:
	add_to_group(&"decorations", true)
	add_to_group(&"saveable", true)


func placements() -> Array[DecorPlacement]:
	return []


func can_place(_decor_id: StringName, _cell: Vector2i, _rot: int, _inv: Inventory = null, _player: Player = null) -> StringName:
	return &"blocked"


## uid or ""; takes 1 item; decor_changed.
func place(_decor_id: StringName, _cell: Vector2i, _rot: int, _inv: Inventory) -> String:
	return ""


## Gives 1 item back; inventory full → false.
func remove(_uid: String, _inv: Inventory) -> bool:
	return false


func placement_at(_cell: Vector2i) -> DecorPlacement:
	return null


## Σ over sections min(decor_cap, Σ contributions) (§2.3).
func decor_score() -> int:
	return 0


## {order: {raw: int, capped: int, cap: int}}
func score_by_section() -> Dictionary:
	return {}


func suppresses_dirt_at(_p: Vector2) -> bool:
	return false


## 0..2 (§2.8)
func ghost_bonus_at(_p: Vector2) -> int:
	return 0


func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
