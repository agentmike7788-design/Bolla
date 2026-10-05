class_name ApprenticeBox
extends Chest
## Jakob's box with the coin tin (docs/PHASE8_DESIGN.md §2.5.5, §3.1, §3.4, §4.3 A2, §5.1): a Chest with 6
## slots (ApprenticeConfig.box_slots; save_id "apprentice_box", save_order 79, group apprentice_box) + the coin
## tin `coins` (the gravekeeper puts coins in, the wage comes out at 15:30). [E] opens the &"chest" panel with
## the coin compartment ({storage, inventory, chest, coins_box}). Saved as {storage, coins}; coins never
## negative. His rake, watering can and candles lie here (the planner reads the storage).

const GROUP := &"apprentice_box"
const PROMPT_BOX := "[E] Jakobs Kiste"
const SLOT_COUNT := 6
const COIN_ITEM := &"coin"

## Coins in the tin.
var coins: int = 0


func _init() -> void:
	save_id = "apprentice_box"
	save_order = 79
	add_to_group(GROUP, true)


func _ready() -> void:
	var cfg := Database.config(&"apprentice_config") as ApprenticeConfig
	storage.slot_count = cfg.box_slots if cfg != null else SLOT_COUNT


func get_interaction_prompt(player: Player) -> String:
	if player != null and is_instance_valid(player.carried):
		return Player.TEXT_HANDS_FULL
	return PROMPT_BOX


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	EventBus.ui_panel_requested.emit(PANEL, {"storage": storage, "inventory": player.inventory, "chest": self, "coins_box": self})


## Moves `amount` coins from `inv` into the tin (all or nothing).
func deposit(inv: Inventory, amount: int) -> bool:
	if inv == null or amount <= 0 or not inv.remove_item(COIN_ITEM, amount):
		return false
	coins += amount
	return true


## Takes `amount` coins out of the tin into `inv` (all or nothing).
func withdraw(inv: Inventory, amount: int) -> bool:
	if inv == null or amount <= 0 or amount > coins:
		return false
	var left := inv.add_item(COIN_ITEM, amount)
	coins -= amount - left
	return left == 0


## {storage: Inventory.save_state(), coins}.
func save_state() -> Dictionary:
	var out := super.save_state()
	out["coins"] = coins
	return out


func load_state(data: Dictionary) -> void:
	super.load_state(data)
	var c: Variant = data.get("coins", 0)
	coins = maxi(0, int(c)) if c is int or c is float else 0
