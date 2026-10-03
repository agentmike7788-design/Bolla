class_name RegisterCopy
extends Node3D
## STUB (P3) – the copy of the death register on the lectern in the office (docs/PHASE7_DESIGN.md
## §1.6, §3.4, §4.3): „[E] Die Abschrift lesen" (Fenner present ∧ (trusted ∨ a donation today)) →
## JournalManager.add_clue(c_v_deathbook); else „Das ist Gemeindesache, Totengräber."
## W1 (P3) fills the bodies; the signatures are the contract.

const PROMPT := "[E] Die Abschrift lesen"
const TEXT_REFUSED := "Das ist Gemeindesache, Totengräber."
const CLUE := &"c_v_deathbook"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
