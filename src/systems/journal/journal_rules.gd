class_name JournalRules
extends RefCounted
## Pure journal rules (docs/PHASE4_DESIGN.md §2.12, §3.4): linking clues to insights, the open
## questions and the insights that are ready to be linked. `found` / `unlocked` are
## dictionaries keyed by clue / insight id (the values do not matter). Stateless.
## Also the piety tier of a value (§2.7 thresholds) for the page "Ich" and the dialogue
## condition piety_tier – the same rule as PietyRules.tier ("tier i+1 from value ≥ threshold i").

## Tier ids, lowest first (= PietyRules.TIERS, user decision §14.1).
const PIETY_TIERS: Array[StringName] = [&"hardhearted", &"callous", &"matter_of_fact", &"considerate", &"devout"]
## §2.7 default thresholds when no PietyConfig is at hand.
const DEFAULT_THRESHOLDS: PackedInt32Array = [-59, -19, 20, 60]


## The insight whose `requires` equals `selected` exactly (order irrelevant, a superset or a
## subset does not match), not yet in `unlocked`; &"" = no match.
static func match_insight(selected: Array[StringName], insights: Array[InsightData], unlocked: Dictionary) -> StringName:
	var chosen := _as_set(selected)
	if chosen.size() != selected.size() or chosen.is_empty():
		return &""
	for insight: InsightData in insights:
		if insight == null or _has(unlocked, insight.id):
			continue
		var needed := _as_set(insight.requires)
		if needed.size() != chosen.size():
			continue
		var same := true
		for id: StringName in chosen:
			if not needed.has(id):
				same = false
				break
		if same:
			return insight.id
	return &""


## Insights with at least one found clue, not unlocked (column "Offene Fragen"), in the order
## of `insights`.
static func open_questions(found: Dictionary, insights: Array[InsightData], unlocked: Dictionary) -> Array[InsightData]:
	var out: Array[InsightData] = []
	for insight: InsightData in insights:
		if insight == null or _has(unlocked, insight.id):
			continue
		for id: StringName in insight.requires:
			if _has(found, id):
				out.append(insight)
				break
	return out


## All required clues found, not linked yet (objective line "Merkbuch: Hinweise passen zusammen").
static func ready_insights(found: Dictionary, insights: Array[InsightData], unlocked: Dictionary) -> Array[InsightData]:
	var out: Array[InsightData] = []
	for insight: InsightData in insights:
		if insight == null or _has(unlocked, insight.id) or insight.requires.is_empty():
			continue
		var all := true
		for id: StringName in insight.requires:
			if not _has(found, id):
				all = false
				break
		if all:
			out.append(insight)
	return out


## Piety tier id of `value` (§2.7): tier i+1 from value ≥ thresholds[i]. cfg null → defaults.
static func piety_tier(value: int, cfg: PietyConfig = null) -> StringName:
	var thresholds: PackedInt32Array = cfg.tier_thresholds if cfg != null and cfg.tier_thresholds.size() == PIETY_TIERS.size() - 1 else DEFAULT_THRESHOLDS
	var index := 0
	for t: int in thresholds:
		if value >= t:
			index += 1
	return PIETY_TIERS[clampi(index, 0, PIETY_TIERS.size() - 1)]


# --- helpers ----------------------------------------------------------------------------------

static func _as_set(ids: Array[StringName]) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	for id: StringName in ids:
		out[id] = true
	return out


## StringName and String keys both count (saves may give Strings).
static func _has(d: Dictionary, id: StringName) -> bool:
	return d.has(id) or d.has(String(id))
