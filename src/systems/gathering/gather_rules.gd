class_name GatherRules
extends RefCounted
## Pure rules of the regrowing gather nodes (docs/PHASE5_DESIGN.md §2.2, §3.4).
## A state is {charges, last_taken_day, last_refresh_day}; regrowth is derived from the day
## number only (never from ticks) and is idempotent: a node with charges < charges_max is full
## again once day − last_taken_day ≥ regrow_days.
## Stages: full · partial (some charges left) · empty · regrowing (only with regrow_stage_days:
## the alder is a stump < [0] days, a sapling < [1] days, a tree again when full).

const STAGE_FULL := &"full"
const STAGE_PARTIAL := &"partial"
const STAGE_EMPTY := &"empty"
const STAGE_REGROWING := &"regrowing"

const TEXT_NOT_OPEN := "Noch nicht zugänglich."
const TEXT_SECTION := "Der Weg ist versperrt."
const TEXT_EMPTY_TOMORROW := "Abgeerntet – morgen wieder"
const TEXT_EMPTY_DAYS := "Abgeerntet – in %d Tagen wieder"
## Fallback while ToolRules has no text: "Axt (Stufe 1) nötig".
const TEXT_TOOL := "%s (Stufe %d) nötig"
const TEXT_NO_ROOM := "Kein Platz im Inventar"
const NO_DAY := -1


## A full state for `data` on `day`.
static func full_state(data: GatherNodeData, day: int) -> Dictionary:
	return {"charges": _max(data), "last_taken_day": NO_DAY, "last_refresh_day": day}


## {charges, last_taken_day, last_refresh_day} after the regrowth rule of `day`. Tolerant: missing
## or broken values count as a full node; charges are clamped to 0…charges_max.
static func refreshed(state: Dictionary, day: int, data: GatherNodeData) -> Dictionary:
	var cap := _max(data)
	var charges := clampi(_int(state.get("charges"), cap), 0, cap)
	var taken := _int(state.get("last_taken_day"), NO_DAY)
	var last_refresh := _int(state.get("last_refresh_day"), NO_DAY)
	if charges < cap and (taken < 0 or day - taken >= _regrow(data)):
		charges = cap
	return {"charges": charges, "last_taken_day": taken, "last_refresh_day": maxi(last_refresh, day)}


## &"full" | &"partial" | &"empty" | &"regrowing"
static func stage(state: Dictionary, day: int, data: GatherNodeData) -> StringName:
	var cap := _max(data)
	var charges := clampi(_int(state.get("charges"), cap), 0, cap)
	if charges >= cap:
		return STAGE_FULL
	if charges > 0:
		return STAGE_PARTIAL
	var taken := _int(state.get("last_taken_day"), NO_DAY)
	if data != null and not data.regrow_stage_days.is_empty() and taken >= 0 \
			and day - taken >= data.regrow_stage_days[0]:
		return STAGE_REGROWING
	return STAGE_EMPTY


## Days until the node is full again (0 = full).
static func days_left(state: Dictionary, day: int, data: GatherNodeData) -> int:
	var now := refreshed(state, day, data)
	if int(now.charges) >= _max(data):
		return 0
	return maxi(1, _regrow(data) - (day - int(now.last_taken_day)))


## "" | flag / section / empty / tool / inventory reason (§2.2), in this order.
static func block_reason(state: Dictionary, data: GatherNodeData, inv: Inventory, tier: int, section_open: bool, flag_ok: bool) -> String:
	if data == null or not flag_ok:
		return TEXT_NOT_OPEN
	if not section_open:
		return TEXT_SECTION
	var charges := clampi(_int(state.get("charges"), _max(data)), 0, _max(data))
	if charges <= 0:
		var left := days_left(state, _int(state.get("last_refresh_day"), 0), data)
		return TEXT_EMPTY_TOMORROW if left <= 1 else TEXT_EMPTY_DAYS % left
	if data.tool_kind != &"" and tier < data.min_tier:
		return tool_text(data.tool_kind, data.min_tier, inv)
	if inv == null or not inv.can_add(data.item_id, yield_for(data, tier)):
		return TEXT_NO_ROOM
	return ""


## yield_amount (+ tier2_bonus with tier 2).
static func yield_for(data: GatherNodeData, tier: int) -> int:
	if data == null:
		return 0
	return data.yield_amount + (data.tier2_bonus if tier >= 2 else 0)


## Minutes of one action: ActionConfig.tool_minutes when a tool sets the pace.
static func minutes_for(data: GatherNodeData, tier: int, actions: ActionConfig) -> int:
	if data == null:
		return 0
	if data.tool_kind == &"" or actions == null:
		return data.minutes
	return actions.tool_minutes(data.minutes, tier)


## "Holzfälleraxt nötig – Esse" from ToolRules; a plain fallback while it has no text.
static func tool_text(kind: StringName, min_tier: int, inv: Inventory) -> String:
	var cfg := Database.config(&"tool_config") as ToolConfig
	if cfg == null:
		cfg = ToolConfig.new()
	var text := ToolRules.block_reason(inv, kind, min_tier, cfg)
	if text != "":
		return text
	return TEXT_TOOL % [cfg.labels.get(kind, String(kind)), min_tier]


static func _max(data: GatherNodeData) -> int:
	return maxi(data.charges_max, 1) if data != null else 1


static func _regrow(data: GatherNodeData) -> int:
	return maxi(data.regrow_days, 1) if data != null else 1


static func _int(v: Variant, fallback: int) -> int:
	if v is int:
		return v
	if v is float:
		return roundi(v)
	return fallback
