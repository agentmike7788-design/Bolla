class_name MarketRules
extends RefCounted
## STUB (P4) – pure rules of the weekly market (docs/PHASE10_DESIGN.md §2.7, §3.4): market day (Saturday from
## village_open on), the next one, the state of a ware group (hash([week, group]) with the weights 25/50/25, then frost
## +1, mourning week +1, oversold −1, Hanne's day −1, clamped – deterministic, never a global random number), the offers
## of a stand (picks from the pool, price × state, integer, never < 1), the demand of a ware (⌊demand × state × tag ×
## reputation × piety⌉), the coins of a sale (round, ≥ 1), the customer of a tick (hash([day, tick, …])), the text of
## the market notice. context = {deaths_7, sold_last, peddler_days} (and what P4 adds).
## W1 (P4) fills the bodies; the signatures are the contract.


static func is_market_day(_day: int, _cfg: MarketConfig) -> bool:
	return false


static func next_market_day(_day: int, _cfg: MarketConfig) -> int:
	return -1


## context {deaths_7, sold_last, peddler_days}
static func group_state(_day: int, _group: StringName, _context: Dictionary, _cfg: MarketConfig) -> StringName:
	return &"normal"


## {item, price, base, stock, state}
static func offers(_stall: MarketStallData, _day: int, _context: Dictionary, _cfg: MarketConfig) -> Array[Dictionary]:
	return []


static func demand(_ware: MarketWareData, _day: int, _tag: StringName, _context: Dictionary, _cfg: MarketConfig) -> int:
	return 0


static func sale_coins(_ware: MarketWareData, _n: int, _state: StringName, _tag: StringName, _cfg: MarketConfig) -> int:
	return 0


## {npc, item, n}
static func buyer_for(_day: int, _tick: int, _wares: Array[StringName], _context: Dictionary) -> Dictionary:
	return {}


static func notice_text(_day: int, _context: Dictionary, _cfg: MarketConfig) -> String:
	return ""
