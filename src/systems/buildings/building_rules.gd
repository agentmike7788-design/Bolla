class_name BuildingRules
extends RefCounted
## STUB (P1) – pure rules of the building levels (docs/PHASE6_DESIGN.md §2.1, §1.5, §3.4).
## W1 (P1) fills the bodies; the signatures are the contract.

const TEXT_MAXED := "Voll ausgebaut."
const TEXT_MISSING := "Es fehlt: %s"
const COIN := &"coin"


## The level after `level`; null = fully built.
static func next_level(_data: BuildingData, _level: int) -> BuildingLevelData:
	return null


## "" | „Voll ausgebaut." | „Es fehlt: …" (and the closed / not-open reasons).
static func upgrade_block_reason(_data: BuildingData, _level: int, _inv: Inventory, _open: bool) -> String:
	return ""


## {item_or_coin: missing amount}.
static func missing(_level_data: BuildingLevelData, _inv: Inventory) -> Dictionary:
	return {}


## {done, total, missing: PackedStringArray} of the chapter §1.5.
static func goal_progress(_levels: Dictionary, _services: int, _reinterred: int, _cfg: BuildingsConfig) -> Dictionary:
	return {"done": 0, "total": 0, "missing": PackedStringArray()}
