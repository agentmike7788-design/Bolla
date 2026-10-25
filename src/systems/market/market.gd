class_name Market
extends Node
## STUB (P4) – Systems/Market (docs/PHASE10_DESIGN.md §1.2, §2.7, §3.1, §3.3, §3.4, §5.1), groups &"market", &"saveable",
## save_id market / 87: the weekly market on the Anger – Saturday 08:00–12:30 from village_open on (the notice at the
## village board from Thursday 07:44, Fenner's hand bell at 08:00, the end at 12:30); the market state of every ware
## group (deterministic, MarketRules.group_state – nothing changes by reloading); the three stands (ms_agathe,
## ms_kehr, ms_brandt) with their offers and stock per market (bought through the shop panel, atomic like
## VillageShops); the own stand (market_stall_granted from Fenner, stall fee 1, 6 slots with a price tag each, ticks of
## 30 minutes with a customer each, take-down: back into the inventory, the rest into the hut chest).
## Coins: income through EventBus.payment_received („Verkauf am Marktstand"), spending GameState.note_coins_spent(n,
## &"market" | &"stall"); EventBus.market_changed for every step.
## W0: stall_granted, stall_goods and sold_on answer from load_state (§5.1 {granted, stall, sold, bought,
## sold_groups_last}) and the flag market_stall_granted; everything else is inert. W1 (P4) fills the bodies; the
## signatures are the contract.

const GROUP := &"market"
## market_changed kinds (§3.3).
const KINDS: Array[StringName] = [&"notice", &"opened", &"closed", &"stall_set", &"sold", &"bought", &"stall_cleared"]
## The own stand's price tags (MarketConfig.tags).
const TAGS: Array[StringName] = [&"cheap", &"fair", &"dear"]
## Market states (MarketConfig.states).
const STATES: Array[StringName] = [&"scarce", &"normal", &"glut"]
const OWN_STALL := &"market_stall_own"

@export var save_id: String = "market"
@export var save_order: int = 87

## Rules; null = data/config/market_config.tres (resolved lazily).
var config: MarketConfig

## W0 stub store (P4 may rename it – the fixtures use load_state only).
var _granted: bool = false
var _stall: Dictionary = {}
var _sold: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## The market is open now (market day, inside the window).
func is_open() -> bool:
	return false


## Today's market day (-1 = no market today).
func market_day() -> int:
	return -1


## The next market day ≥ today (-1 = none, e.g. before village_open).
func next_market() -> int:
	return -1


## &"scarce" | &"normal" | &"glut" of a ware group on the coming / current market day.
func lage(_group: StringName) -> StringName:
	return &"normal"


## {group: state} of all groups.
func lage_all() -> Dictionary:
	return {}


## Fenner gives the place (market_stall_granted).
func grant_stall() -> void:
	pass


func stall_granted() -> bool:
	return _granted or GameState.flag_on(_cfg().stall_flag)


## {item, price, base, stock, state} of a stand today.
func stall_offers(_stall_id: StringName) -> Array[Dictionary]:
	return []


func buy(_stall_id: StringName, _item: StringName, _n: int, _inv: Inventory) -> bool:
	return false


func set_up_block_reason(_player: Player) -> String:
	return ""


## {item: n}, {item: &"cheap" | &"fair" | &"dear"}
func set_up(_goods: Dictionary, _tags: Dictionary, _inv: Inventory) -> bool:
	return false


## The sales of one tick {npc, item, n, coins, line}.
func sell_tick() -> Array[Dictionary]:
	return []


## Back into the inventory, the rest into the chest.
func take_down(_inv: Inventory) -> Dictionary:
	return {}


## {item: n} on the own stand ({} = not set up).
func stall_goods() -> Dictionary:
	var goods: Variant = _stall.get("goods")
	return (goods as Dictionary).duplicate(true) if goods is Dictionary else {}


## {item: n} sold at the own stand on `day`.
func sold_on(day: int) -> Dictionary:
	var s: Variant = _sold.get(str(day))
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


## The notice Thursday, the bell 08:00, the end 12:30.
func apply_minute(_day: int, _minute: int) -> void:
	pass


## §5.1 {granted, stall, sold, bought, sold_groups_last}.
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_granted = bool(data.get("granted", false)) if data.get("granted") is bool else false
	_stall = (data.get("stall") as Dictionary).duplicate(true) if data.get("stall") is Dictionary else {}
	_sold = (data.get("sold") as Dictionary).duplicate(true) if data.get("sold") is Dictionary else {}


func _cfg() -> MarketConfig:
	if config == null:
		config = Database.config(&"market_config") as MarketConfig
		if config == null:
			config = MarketConfig.new()
	return config
