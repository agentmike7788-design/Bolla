class_name TipStone
extends Node3D
## STUB (P2) – the coins a visitor left on the stone (docs/PHASE8_DESIGN.md §2.2.3, §3.1, §3.4): child of
## a GravePlot, not saved itself (the state is in Visitors.tips_on_stone); child mesh coins at the marker
## inscription; „[E] %d Münzen auf dem Stein (%s)" → Visitors.take_tip(grave_id, inv). Ghosts and the
## robber take nothing.
## W1 (P2) fills the bodies; the signatures are the contract.

const PROMPT_FORMAT := "[E] %d Münzen auf dem Stein (%s)"

## The grave of the parent GravePlot.
@export var grave_id: String = ""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## Shows / hides the coins from Visitors.tip_on_stone.
func refresh() -> void:
	pass
