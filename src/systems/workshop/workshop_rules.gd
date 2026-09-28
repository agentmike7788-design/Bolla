class_name WorkshopRules
extends RefCounted
## STUB (P1) – docs/PHASE5_DESIGN.md §2.1, §1.5, §3.4: pure rules of building a station and of
## the chapter "Namen in Stein". W1 (P1) fills the bodies; the signatures are the contract.

const TEXT_BUILT := "Schon gebaut."
const TEXT_MISSING := "Es fehlt: %s"
## Key of the coins in missing().
const COIN := &"coin"


## "" | "Schon gebaut." | "Es fehlt: 2 Stein, 5 Münzen" (hidden while not open).
static func build_block_reason(_station: StationData, _inv: Inventory, _built: bool, _open: bool) -> String:
	return ""


## {item_id_or_coin: missing amount}; {} = everything there.
static func missing(_station: StationData, _inv: Inventory) -> Dictionary:
	return {}


## {done: int, total: int, missing: PackedStringArray} of §1.5 (stations, tool tiers, master stones).
static func goal_progress(_built: Array[StringName], _tiers: Dictionary, _master_stones: int, cfg: WorkshopConfig) -> Dictionary:
	var total := 0
	if cfg != null:
		total = cfg.goal_stations.size() + cfg.goal_tiers.size() + 1
	return {"done": 0, "total": total, "missing": PackedStringArray()}
