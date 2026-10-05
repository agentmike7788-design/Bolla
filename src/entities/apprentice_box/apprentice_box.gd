class_name ApprenticeBox
extends Chest
## STUB (P3) – Jakob's box with the coin tin (docs/PHASE8_DESIGN.md §2.5.5, §3.1, §3.4, §4.3 A2, §5.1):
## a Chest with 6 slots (save_id "apprentice_box", save_order 79) + the coin tin `coins` (the player puts
## coins in; the wage comes out at 15:30); [E] opens the &"chest" panel with the coin compartment.
## Saved as {storage, coins}.
## W0: coins round-trips through save_state / load_state; the rest is the Chest's.
## W1 (P3) fills the bodies; the signatures are the contract.

const PROMPT_BOX := "[E] Jakobs Kiste"
const SLOT_COUNT := 6

## Coins in the tin.
var coins: int = 0


func _init() -> void:
	save_id = "apprentice_box"
	save_order = 79


## {storage: Inventory.save_state(), coins}.
func save_state() -> Dictionary:
	var out := super.save_state()
	out["coins"] = coins
	return out


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	var c: Variant = data.get("coins", 0)
	coins = maxi(0, int(c)) if c is int or c is float else 0
