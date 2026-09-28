class_name RoomExit
extends Node3D
## STUB (P6) – the way out of a building's room at the marker door_inside (docs/PHASE6_DESIGN.md
## §3.4, §4.7): „[E] Hinaufgehen" (crypt) / „[E] Hinausgehen"; travels to
## BuildingDoor.exit_transform() with inside false; with a corpse when BuildingData.allows_corpse.
## W1 (P6) fills the bodies; the signatures are the contract.

const PROMPT_OUT := "[E] Hinausgehen"

@export var building_id: StringName

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
