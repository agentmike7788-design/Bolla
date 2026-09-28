class_name GatherRules
extends RefCounted
## STUB (P2) – docs/PHASE5_DESIGN.md §2.2, §3.4: pure rules of the regrowing gather nodes.
## A state is {charges, last_taken_day, last_refresh_day}; regrowth is derived from the day
## number only (never from ticks), idempotent. W1 (P2) fills the bodies.

const STAGE_FULL := &"full"
const STAGE_PARTIAL := &"partial"
const STAGE_EMPTY := &"empty"
const STAGE_REGROWING := &"regrowing"


## {charges, last_taken_day, last_refresh_day} after the regrowth rule of `day`.
static func refreshed(state: Dictionary, _day: int, _data: GatherNodeData) -> Dictionary:
	return state.duplicate()


## &"full" | &"partial" | &"empty" | &"regrowing"
static func stage(_state: Dictionary, _day: int, _data: GatherNodeData) -> StringName:
	return STAGE_FULL


## Days until the node is full again (0 = full).
static func days_left(_state: Dictionary, _day: int, _data: GatherNodeData) -> int:
	return 0


## "" | empty / tool / section / flag / inventory reason (§2.2).
static func block_reason(_state: Dictionary, _data: GatherNodeData, _inv: Inventory, _tier: int, _section_open: bool, _flag_ok: bool) -> String:
	return ""


## yield_amount (+ tier2_bonus with tier 2).
static func yield_for(data: GatherNodeData, _tier: int) -> int:
	return data.yield_amount if data != null else 0
