class_name Inventory
extends Node
## Slot inventory (child "Inventory" of the player). CURRENCY items have no slot.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

signal changed

@export var slot_count: int = 16

func add_item(id: StringName, amount: int) -> int:
	push_warning("STUB Inventory.add_item")
	return 0


func remove_item(id: StringName, amount: int) -> bool:
	push_warning("STUB Inventory.remove_item")
	return false


func count(id: StringName) -> int:
	push_warning("STUB Inventory.count")
	return 0


func has(id: StringName, amount: int = 1) -> bool:
	push_warning("STUB Inventory.has")
	return false


func can_add(id: StringName, amount: int) -> bool:
	push_warning("STUB Inventory.can_add")
	return false


func get_slots() -> Array[Dictionary]:
	push_warning("STUB Inventory.get_slots")
	return []


func clear() -> void:
	pass


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
