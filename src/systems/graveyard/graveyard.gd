class_name Graveyard
extends Node
## Owns all GraveRecords (WorldRoot/Systems/Graveyard).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var save_id: String = "graveyard"
@export var save_order: int = 10

func _ready() -> void:
	pass


func graves() -> Array[GraveRecord]:
	push_warning("STUB Graveyard.graves")
	return []


func get_grave(id: String) -> GraveRecord:
	push_warning("STUB Graveyard.get_grave")
	return null


func free_plot_count() -> int:
	push_warning("STUB Graveyard.free_plot_count")
	return 0


func dig(id: String) -> bool:
	push_warning("STUB Graveyard.dig")
	return false


func bury(grave_id: String, corpse_id: String) -> bool:
	push_warning("STUB Graveyard.bury")
	return false


func place_marker(grave_id: String, marker_id: StringName, inv: Inventory) -> int:
	push_warning("STUB Graveyard.place_marker")
	return 0


func total_quality() -> int:
	push_warning("STUB Graveyard.total_quality")
	return 0


func rating() -> StringName:
	push_warning("STUB Graveyard.rating")
	return &""


func broadcast_state() -> void:
	push_warning("STUB Graveyard.broadcast_state")


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
