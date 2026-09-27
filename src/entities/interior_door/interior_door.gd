class_name InteriorDoor
extends Node3D
## The hut door seen from inside (docs §11), at the room's door_inside marker: "[E] Hinausgehen"
## fades and puts the gravekeeper in front of the outside door (HutDoor.exit_transform).

const PROMPT_EXIT := "[E] Hinausgehen"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(player: Player) -> bool:
	return player != null and not player.is_busy() and _outside_door() != null and not HutPortal.is_travelling(player)


func get_interaction_prompt(_player: Player) -> String:
	return PROMPT_EXIT if _outside_door() != null else ""


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	HutPortal.travel(player, _outside_door().exit_transform(), false, InteriorConfig.resolve(_config()).fade_seconds)


func _outside_door() -> HutDoor:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(HutDoor.GROUP) as HutDoor


func _config() -> InteriorConfig:
	var interior := get_tree().get_first_node_in_group(HutInterior.GROUP) as HutInterior if is_inside_tree() else null
	return interior.config if interior != null else null
