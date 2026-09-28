class_name ShedStore
extends Chest
## STUB (P1) – the shelves with the store book inside the shed (docs/PHASE6_DESIGN.md §2.5, §3.4,
## §4.8): a Chest with its own Inventory (save_id "shed_store", save_order 61); [E] opens the
## &"chest" panel. Slots 24 / 32 / 40 by shed level, level 3 doubles the stacks of RESOURCE /
## MATERIAL; a level change never shrinks. W1 (P1) fills the bodies; the signatures are the contract.

const PROMPT_STORE := "[E] Lager öffnen"


func _init() -> void:
	save_id = "shed_store"
	save_order = 61


## slot_count and stack_multiplier of the level; never shrinks.
func apply_level(_level: int) -> void:
	pass


## The shed inventory (= storage).
func store() -> Inventory:
	return storage
