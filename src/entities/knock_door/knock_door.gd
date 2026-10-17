class_name KnockDoor
extends Node3D
## STUB (P4) – a house door to knock at, without an interior (docs/PHASE9_DESIGN.md §2.2.3 H4, §3.1, §3.4, §4.3, §4.6 D8):
## door_sieber at the Siebers' house door. „[E] Bei den Siebers anklopfen" → dialogue sieber_door (Anna answers as a
## voice behind the door); at night with the nameless_letter: „[E] Brief an die Tür stecken" → WhoKnows.post_letter.
## W1 (P4) fills the bodies; the signatures are the contract.

const PROMPT_KNOCK := "[E] Bei den Siebers anklopfen"
const PROMPT_LETTER := "[E] Brief an die Tür stecken"

@export var door_id: StringName = &""
## Dialogue of the voice behind the door.
@export var dialogue_id: StringName = &"sieber_door"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
