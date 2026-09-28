class_name BuildingDoor
extends Node3D
## STUB (P6) – Entities/door_<id> at the marker door_outside of the outdoor model (from level 1)
## (docs/PHASE6_DESIGN.md §3.4, §4.7): prompt BuildingData.prompt_enter; with a corpse only when
## allows_corpse (else HutDoor.TEXT_CORPSE_OUTSIDE); level 0: no prompt. Travels (0.5 s fade) to
## the room's spawn with Player.set_in_interior(true, room_id).
## W1 (P6) fills the bodies; the signatures are the contract.

@export var building_id: StringName

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Level ≥ 1.
func is_open() -> bool:
	return false


## Where the gravekeeper stands after leaving the room (in front of the door).
func exit_transform() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
