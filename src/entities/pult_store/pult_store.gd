class_name PultStore
extends Chest
## STUB (P7) – the cold box (slate drawer) of the preparation desk in the crypt (docs/PHASE7_DESIGN.md
## §2.6, §2.7, §3.4): a Chest with 8 slots (save_id "pult_store", save_order 62), [E] opens the
## &"chest" panel; takes everything the chest takes. Inventory.changed → Specimens.note_cold for
## bundles going in / out (bundles spoil × AnatomyConfig.pult_cold_factor in here).
## W1 (P7) fills the bodies; the signatures are the contract.

const PROMPT_COLD := "[E] Kühlfach öffnen"
const SLOT_COUNT := 8


func _init() -> void:
	save_id = "pult_store"
	save_order = 62


## The cold box inventory (= storage).
func store() -> Inventory:
	return storage
