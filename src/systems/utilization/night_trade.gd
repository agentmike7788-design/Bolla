class_name NightTrade
extends Node
## STUB (P3) – docs/PHASE4_DESIGN.md §2.6, §2.11 (5), §3.4, §5.1. Systems/NightTrade (groups
## &"night_trade", &"saveable"): Ilse Kranich's trade at the west wall, the note at the hut door,
## her tools, talks and nightly stock. Coins are paid at once.

const GROUP := &"night_trade"

@export var save_id: String = "night_trade"
@export var save_order: int = 45


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Flag trader_known.
func is_known() -> bool:
	return false


## Ilse stands at trader_spot right now (via the Npc node npc_trader).
func is_present() -> bool:
	return false


## GhostManager.night_index logic: a night starts at 12:00 → stock / greeting per night.
func night_id() -> int:
	return 0


## Coins at once; only sell_prices items; only while present; stats.trader_sales;
## trader_trade; flag trader_rumor from rumor_after_sales on. Returns the coins paid.
func sell(_item_id: StringName, _amount: int, _inv: Inventory) -> int:
	return 0


## Price incl. the piety bonus.
func quote(_item_id: StringName, _amount: int) -> int:
	return 0


## Shop: coins off, item in, stock of the night; atomic.
func buy(_item_id: StringName, _amount: int, _inv: Inventory) -> bool:
	return false


func stock_left(_item_id: StringName) -> int:
	return 0


## Once (tools_given); called by the dialogue action trader_tools.
func give_tools(_inv: Inventory) -> bool:
	return false


## Once per night: talks +1 (for c_trader_lorenz).
func note_talk() -> void:
	pass


## Idempotent: the note at the door from intro_day on (trader_known, c_trader_note).
func apply_morning(_day: int) -> void:
	pass


## {"intro_done", "tools_given", "talks", "last_talk_night", "stock_night", "stock_left"} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
