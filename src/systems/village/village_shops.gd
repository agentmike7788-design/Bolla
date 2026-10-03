class_name VillageShops
extends Node
## STUB (P2) – Systems/VillageShops (docs/PHASE7_DESIGN.md §2.3, §3.1, §3.4, §5.1), groups
## &"village_shops", &"saveable": the six village shops after the pattern of Ilse's NightTrade (coins
## at once, stock per day, atomic). A shop is open while its villager stands at the shop spot. Buying
## never changes a relationship. W1 (P2) fills the bodies; the signatures are the contract.

const GROUP := &"village_shops"
const PAYMENT_REASON := "Verkauf im Dorf"

@export var save_id: String = "village_shops"
@export var save_order: int = 52


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func shop(shop_id: StringName) -> ShopData:
	return Database.shop(shop_id) as ShopData


## The Npc stands at the shop spot (ready to talk, not walking).
func is_open(_shop_id: StringName) -> bool:
	return false


## [{item, price, stock_left, block_reason}]
func offers(_shop_id: StringName) -> Array[Dictionary]:
	return []


## [{item, price, bought_left, held, block_reason}]
func wants(_shop_id: StringName) -> Array[Dictionary]:
	return []


## Atomic; note_coins_spent(cost, coin_reason); shop_trade.
func buy(_shop_id: StringName, _item: StringName, _n: int, _inv: Inventory) -> bool:
	return false


## Atomic; payment_received(…, PAYMENT_REASON); shop_trade; coins | 0.
func sell(_shop_id: StringName, _item: StringName, _n: int, _inv: Inventory) -> int:
	return 0


## {stock_day, stock_left, bought_left}; a new day → full (derived).
func save_state() -> Dictionary:
	return {}


func load_state(_data: Dictionary) -> void:
	pass
