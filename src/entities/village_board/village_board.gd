class_name VillageBoard
extends Node3D
## STUB (P3) – the parish board at the linden (docs/PHASE7_DESIGN.md §2.5, §3.4, §4.2):
## „[E] Gemeindetafel lesen" → panel &"orders" {board: true}. W1 (P3) fills the bodies; the
## signatures are the contract.

const PANEL := &"orders"
const PROMPT := "[E] Gemeindetafel lesen"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
