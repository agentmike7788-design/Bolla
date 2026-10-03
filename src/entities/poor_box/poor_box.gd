class_name PoorBox
extends Node3D
## STUB (P3) – the poor box in the office (docs/PHASE7_DESIGN.md §2.4, §3.4, §4.3):
## „[E] In die Armenkasse geben (5 Münzen)" → Village.donate (at most 2 steps per day).
## W1 (P3) fills the bodies; the signatures are the contract.

const PROMPT := "[E] In die Armenkasse geben (5 Münzen)"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
