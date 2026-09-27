class_name CorpsePrep
extends RefCounted
## STUB (P2) – docs/PHASE4_DESIGN.md §2.3, §2.5, §3.4. Pure preparation rules.

const ACTION_WASH := &"wash"
const ACTION_DRESS := &"dress"
const ACTION_LAY_OUT := &"lay_out"
const ACTION_BALM := &"balm"
const ACTIONS: Array[StringName] = [ACTION_WASH, ACTION_DRESS, ACTION_LAY_OUT, ACTION_BALM]


## "" = possible. wash (tool, not dressed, not washed) · dress (kind shroud/gown, item,
## valuables decided, not dressed) · lay_out (tool, not laid out) · balm (item, no running
## window, < balm_max_windows).
static func block_reason(_record: CorpseRecord, _action: StringName, _inv: Inventory, _cfg: PrepConfig, _kind: StringName = &"") -> String:
	return ""


static func minutes(_action: StringName, _cfg: PrepConfig, _kind: StringName = &"") -> int:
	return 0


static func is_balm_active(_record: CorpseRecord, _now_total: int) -> bool:
	return false
