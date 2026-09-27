class_name GraveQuality
extends RefCounted
## Grave quality and payment rules (docs §2.4). All points come from EconomyConfig.

const LABEL_BURIED := "Bestattet"
const LABEL_SHROUD := "Leichentuch"
const LABEL_FRESH := "Frisch"
const LABEL_DECAYING := "Verwesend"
const LABEL_EXAMINED := "Untersucht"
const LABEL_VALUABLES_LEFT := "Wertsachen liegen gelassen"
const LABEL_VALUABLES_TAKEN := "Wertsachen genommen"
## Marker labels when the item database does not know the marker.
const MARKER_LABELS: Dictionary[StringName, String] = {&"wooden_cross": "Holzkreuz", &"gravestone_simple": "Grabstein"}
const LABEL_MARKER_FALLBACK := "Grabzeichen"


## [{label: String, points: int}] in display order. Unknown marker ids add no marker line.
## Freshness uses freshness_at_burial once set (>= 0), else the current freshness.
static func breakdown(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if corpse == null:
		push_warning("[GraveQuality] breakdown without corpse")
		return out
	var cfg := _config(config)
	out.append(_line(LABEL_BURIED, cfg.quality_buried))
	if corpse.shrouded:
		out.append(_line(LABEL_SHROUD, cfg.quality_shroud))
	if cfg.marker_quality.has(marker_id):
		out.append(_line(_marker_label(marker_id), cfg.marker_quality[marker_id]))
	var fresh := corpse.freshness_at_burial if corpse.freshness_at_burial >= 0.0 else corpse.freshness
	var stage := CorpseRecord.stage_for(fresh, cfg)
	if stage == CorpseRecord.STAGE_FRESH:
		out.append(_line(LABEL_FRESH, cfg.fresh_good_bonus))
	elif stage == CorpseRecord.STAGE_DECAYING:
		out.append(_line(LABEL_DECAYING, cfg.fresh_bad_malus))
	if corpse.examined:
		out.append(_line(LABEL_EXAMINED, cfg.quality_examined))
	if corpse.valuables_decision == CorpseRecord.DECISION_LEFT:
		out.append(_line(LABEL_VALUABLES_LEFT, cfg.valuables_left_bonus))
	elif corpse.valuables_decision == CorpseRecord.DECISION_TAKEN:
		out.append(_line(LABEL_VALUABLES_TAKEN, cfg.valuables_taken_malus))
	return out


## Sum of the breakdown, clamped to [quality_min, quality_max].
static func compute(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> int:
	var cfg := _config(config)
	var total := 0
	for entry: Dictionary in breakdown(corpse, marker_id, cfg):
		total += int(entry.points)
	return clampi(total, mini(cfg.quality_min, cfg.quality_max), maxi(cfg.quality_min, cfg.quality_max))


## base_payment(cause) + floor(quality * payment_per_quality), never negative.
static func payment(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig) -> int:
	var cfg := _config(config)
	var base := 0
	if corpse != null and tables != null:
		base = int(tables.get_cause(corpse.cause_id).get("base_payment", 0))
	elif tables == null:
		push_warning("[GraveQuality] payment without CorpseTables – no base payment")
	return maxi(0, base + floori(quality * cfg.payment_per_quality))


## Display name of a grave marker item ("Holzkreuz", "Grabstein").
static func _marker_label(marker_id: StringName) -> String:
	if Database.has_item(marker_id):
		var item := Database.item(marker_id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	return MARKER_LABELS.get(marker_id, LABEL_MARKER_FALLBACK)


static func _line(label: String, points: int) -> Dictionary:
	return {"label": label, "points": points}


static func _config(config: EconomyConfig) -> EconomyConfig:
	if config == null:
		push_warning("[GraveQuality] no EconomyConfig – using defaults")
		return EconomyConfig.new()
	return config
