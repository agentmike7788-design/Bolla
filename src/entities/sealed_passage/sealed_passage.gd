class_name SealedPassage
extends Node3D
## STUB (P3) – the walled-up door behind the ossuary shelf (docs/PHASE6_DESIGN.md §2.3, §3.4):
## visible from passage_level („[E] Die vermauerte Tür ansehen" → Ossuary.look_at_passage), grille
## and the cold light from grille_level („[E] Durch das Gitter sehen"). No way through (Phase 12).
## W1 (P3) fills the bodies; the signatures are the contract.

const PROMPT_LOOK := "[E] Die vermauerte Tür ansehen"
const PROMPT_GRILLE := "[E] Durch das Gitter sehen"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Visibility of the walled door / the grille and its light from Ossuary.passage_state().
func refresh() -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
