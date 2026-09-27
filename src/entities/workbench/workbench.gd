class_name Workbench
extends Node3D
## Crafting station.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var station: StringName = &"workbench"

func can_interact(player: Player) -> bool:
	push_warning("STUB Workbench.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB Workbench.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB Workbench.interact")


func request_craft(recipe_id: StringName) -> void:
	push_warning("STUB Workbench.request_craft")
