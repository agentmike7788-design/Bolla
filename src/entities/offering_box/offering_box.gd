class_name OfferingBox
extends StaticBody3D
## STUB (P2) – the poor box „Für den Gottesacker" at the eastern gate pillar, inside (docs/PHASE10_DESIGN.md §2.5.8,
## §3.1, §4.3, §7.5; poor_box_gate, model ph_prop_offering_box). „[E] Opferstock: leeren oder etwas hineinlegen" opens
## a short choice (&"action_choice", Lehren aus G9): „Opferstock leeren (2 Min)" (focus; Treasury.empty_poor_box,
## clip count_coins) · „Etwas hineinlegen" (1 coin, Treasury.give_to_poor_box). Not to be confused with the Phase-7
## PoorBox (Fenner's Armenkasse in the office), which stays as it is.
## W1 (P2) fills the bodies; the signatures are the contract. W-Welt places it (W2).

const PROMPT := "[E] Opferstock: leeren oder etwas hineinlegen"
const TITLE_CHOICE := "Opferstock"
const OPTION_EMPTY := &"empty"
const OPTION_GIVE := &"give"
const LABEL_EMPTY := "Opferstock leeren (2 Min)"
const LABEL_GIVE := "Etwas hineinlegen"
const INSCRIPTION := "Für den Gottesacker"

@export var box_id: StringName = &"poor_box_gate"

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## The choice's answer: &"empty" | &"give".
func request_action(_id: StringName) -> void:
	pass
