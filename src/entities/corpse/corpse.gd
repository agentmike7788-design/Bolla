class_name Corpse
extends Node3D
## Visual + interactable of one corpse; state lives in CorpseRecord.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var corpse_id: String = ""

func can_interact(player: Player) -> bool:
	push_warning("STUB Corpse.can_interact")
	return false


func get_interaction_prompt(player: Player) -> String:
	push_warning("STUB Corpse.get_interaction_prompt")
	return ""


func interact(player: Player) -> void:
	push_warning("STUB Corpse.interact")
