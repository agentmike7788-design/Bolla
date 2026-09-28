class_name Catafalque
extends Node3D
## STUB (P4) – the catafalque before the altar inside the chapel (docs/PHASE6_DESIGN.md §2.4,
## §3.4): LOCATION_CATAFALQUE, room chapel; „[E] Auf den Katafalk legen" / „[E] Leiche aufnehmen".
## W1 (P4) fills the bodies; the signatures are the contract.

const GROUP := &"catafalque"
const SLOT_NAME := "slot_corpse"
const PROMPT_PUT := "[E] Auf den Katafalk legen"
const PROMPT_TAKE := "[E] Leiche aufnehmen"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Corpse id on the catafalque ("" = free), from the records.
func occupant() -> String:
	return ""


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
