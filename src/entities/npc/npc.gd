class_name Npc
extends Node3D
## Schedule-driven NPC (positions itself from ScheduleResolver every frame).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

@export var save_id: String = ""
@export var save_order: int = 20
@export var npc_id: StringName
@export var model: PackedScene

func can_interact(player: Player) -> bool:
	push_warning("STUB Npc.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB Npc.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB Npc.interact")


func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	pass
