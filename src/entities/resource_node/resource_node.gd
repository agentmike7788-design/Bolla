class_name ResourceNode
extends Node3D
## Gatherable pile (wood/stone) with a daily amount.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var save_id: String = ""
@export var save_order: int = 20
@export var item_id: StringName
@export var daily_amount: int = 4
@export var model: PackedScene

func can_interact(player: Player) -> bool:
	push_warning("STUB ResourceNode.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB ResourceNode.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB ResourceNode.interact")


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
