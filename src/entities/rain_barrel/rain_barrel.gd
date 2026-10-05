class_name RainBarrel
extends Node3D
## STUB (P2) – the rain barrel at the hut corner (docs/PHASE8_DESIGN.md §2.3, §3.1, §3.4, §4.3 A4):
## „[E] Gießkanne füllen (2 Min)" → GraveCare.refill (the apprentice refills here too – a visible walk).
## W1 (P2) fills the bodies; the signatures are the contract.

const PROMPT := "[E] Gießkanne füllen (2 Min)"
const TEXT_NO_CAN := "Du hast keine Gießkanne."

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
