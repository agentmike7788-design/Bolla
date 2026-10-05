class_name ApprenticeBoard
extends Node3D
## STUB (P3) – the chalk board at the hut wall (docs/PHASE8_DESIGN.md §2.5.3, §3.1, §3.4, §4.3 A1, §7.1):
## „[E] Arbeitsliste für Jakob" → panel &"apprentice_board"; before hire: „Eine leere Kreidetafel."
## W1 (P3) fills the bodies; the signatures are the contract.

const PANEL := &"apprentice_board"
const PROMPT := "[E] Arbeitsliste für Jakob"
const TEXT_EMPTY := "Eine leere Kreidetafel."

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
