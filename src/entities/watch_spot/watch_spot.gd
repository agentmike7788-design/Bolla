class_name WatchSpot
extends Node3D
## STUB (P7) – a place in the shadow to watch a sick house (docs/PHASE8_DESIGN.md §1.3, §3.1, §3.4, §4.6 D2):
## watch_ott (under the Remise eaves), watch_kehr (west corner of the office); the prompt only in nights
## with a sick light: „[E] Im Schatten warten (bis ≈ 22:20)" → NightPaths.wait_minutes (≤ 120, abortable).
## W1 (P7) fills the bodies; the signatures are the contract.

const PROMPT_FORMAT := "[E] Im Schatten warten (bis ≈ %s)"

@export var spot_id: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
