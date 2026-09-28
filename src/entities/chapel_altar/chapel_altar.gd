class_name ChapelAltar
extends Node3D
## STUB (P4) – the altar inside the chapel (docs/PHASE6_DESIGN.md §2.4, §3.4): „[E] Aussegnung
## halten (45 Min)" while the catafalque is occupied → panel &"chapel"; otherwise „[E] Andacht
## halten" → panel &"devotion". request_service / request_devotion run the TimedAction
## (not cancellable) → ChapelRites.hold_service / hold_devotion.
## W1 (P4) fills the bodies; the signatures are the contract.

const PANEL_SERVICE := &"chapel"
const PANEL_DEVOTION := &"devotion"
const PROMPT_SERVICE := "[E] Aussegnung halten (%d Min)"
const PROMPT_DEVOTION := "[E] Andacht halten"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Panel &"chapel": the service for the corpse on the catafalque.
func request_service() -> void:
	pass


## Panel &"devotion": a devotion for `grave_id`.
func request_devotion(_grave_id: String) -> void:
	pass
