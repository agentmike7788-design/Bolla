class_name OrderRules
extends RefCounted
## STUB (P3) – pure order rules (docs/PHASE7_DESIGN.md §2.5, §3.4): offer conditions, the burial result
## (&"done" | &"wait" | &"broken"), the stone match, a delivery ready, the deterministic board pick.
## W1 (P3) fills the bodies; the signatures are the contract.

const RESULT_DONE := &"done"
const RESULT_WAIT := &"wait"
const RESULT_BROKEN := &"broken"
const TEXT_MAX_ACTIVE := "Vier Aufträge laufen schon."


static func offer_block_reason(_order: OrderData, _state: Dictionary, _rel_tier: StringName, _active: int, _cfg: OrdersConfig) -> String:
	return ""


static func bury_result(_order: OrderData, _record: CorpseRecord, _grave: GraveRecord) -> StringName:
	return RESULT_WAIT


static func stone_matches(_order: OrderData, _grave: GraveRecord) -> bool:
	return false


static func deliver_ready(_order: OrderData, _inv: Inventory) -> bool:
	return false


## Deterministic from the day (and the history's cooldowns): n board order ids.
static func board_pick(_pool: Array[OrderData], _day: int, _history: Dictionary, _n: int) -> Array[StringName]:
	return []
