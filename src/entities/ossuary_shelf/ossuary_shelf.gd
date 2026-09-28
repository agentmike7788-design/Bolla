class_name OssuaryShelf
extends Node3D
## STUB (P3) – the ossuary niche inside the crypt (docs/PHASE6_DESIGN.md §2.3, §3.4, §4.8):
## „[E] Gebeine beisetzen (20 Min)" → Ossuary.reinter; a row of boxes after used(), the old stones
## after reinterred() (markers box_1…6, stone_1…6), the name board from crypt level 3 (Label3D).
## W1 (P3) fills the bodies; the signatures are the contract.

const PROMPT_REINTER := "[E] Gebeine beisetzen (%d Min)"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Boxes, old stones, name board.
func refresh() -> void:
	pass


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
