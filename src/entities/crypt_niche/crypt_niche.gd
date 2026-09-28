class_name CryptNiche
extends Node3D
## STUB (P2) – a cold niche inside the crypt (docs/PHASE6_DESIGN.md §2.2, §3.4, §4.8): slot_id
## niche_1…6, open from min_level (1/1/2/2/3/3). „[E] In die Kühlnische legen" (carrying, free,
## open) · „[E] Leiche aus der Nische nehmen" (hands free, occupied) · „Die Nische ist noch
## vermauert." The occupancy comes from the records (location &"niche", slot_id); the niche saves
## nothing. W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"crypt_niche"
const SLOT_NAME := "slot_corpse"
const CHILL_NAME := "chill"
const PROMPT_PUT := "[E] In die Kühlnische legen"
const PROMPT_TAKE := "[E] Leiche aus der Nische nehmen"
const TEXT_SEALED := "Die Nische ist noch vermauert."

@export var slot_id: String
@export var min_level: int = 1

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


## Buildings.level(&"crypt") ≥ min_level.
func is_open() -> bool:
	return false


## Corpse id in this niche ("" = free), from the records.
func occupant() -> String:
	return ""


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass
