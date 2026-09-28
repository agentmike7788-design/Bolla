class_name GraveQuality
extends RefCounted
## Grave quality and payment rules (docs §2.4). All points come from EconomyConfig.

const LABEL_BURIED := "Bestattet"
const LABEL_SHROUD := "Leichentuch"
const LABEL_GOWN := "Totenhemd"
const LABEL_WASHED := "Gewaschen"
const LABEL_LAID_OUT := "Aufgebahrt"
const LABEL_FRESH := "Frisch"
const LABEL_DECAYING := "Verwesend"
const LABEL_ROTTEN := "Verfallen"
## Phase 4 §2.4: dress kind → line label; harvest kind → line label.
const DRESS_LABELS: Dictionary[StringName, String] = {&"shroud": "Leichentuch", &"gown": "Totenhemd"}
const HARVEST_LABELS: Dictionary[StringName, String] = {&"hair": "Haar genommen", &"teeth": "Zähne genommen"}
const LABEL_EXAMINED := "Untersucht"
const LABEL_VALUABLES_LEFT := "Wertsachen liegen gelassen"
const LABEL_VALUABLES_TAKEN := "Wertsachen genommen"
## Marker labels when the item database does not know the marker.
const MARKER_LABELS: Dictionary[StringName, String] = {&"wooden_cross": "Holzkreuz", &"gravestone_simple": "Grabstein"}
const LABEL_MARKER_FALLBACK := "Grabzeichen"


## [{label: String, points: int}] in display order (Phase 4 §2.4): Bestattet · Gewaschen ·
## Leichentuch / Totenhemd · Aufgebahrt · marker · Frisch / Verwesend / Verfallen · Untersucht ·
## Wertsachen · Haar / Zähne genommen. Unknown marker ids add no marker line.
## Freshness uses freshness_at_burial once set (>= 0), else the current freshness; below
## rot_threshold the rotten malus replaces the decaying one. A record without dress but
## shrouded (older saves) counts as shroud.
## Phase 5 §2.5, §3.4: a non-empty `design` (StoneDesign.to_dict of the grave) replaces the marker
## line by the stone lines (StoneDesignRules.breakdown_lines: "Meisterstein +5", "Inschrift +1", …).
static func breakdown(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig, design: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if corpse == null:
		push_warning("[GraveQuality] breakdown without corpse")
		return out
	var cfg := _config(config)
	out.append(_line(LABEL_BURIED, cfg.quality_buried))
	if corpse.washed:
		out.append(_line(LABEL_WASHED, cfg.quality_washed))
	if corpse.dress != CorpseRecord.DRESS_NONE and cfg.dress_quality.has(corpse.dress):
		out.append(_line(DRESS_LABELS.get(corpse.dress, LABEL_SHROUD), cfg.dress_quality[corpse.dress]))
	elif corpse.shrouded:
		out.append(_line(LABEL_SHROUD, cfg.quality_shroud))
	if corpse.laid_out:
		out.append(_line(LABEL_LAID_OUT, cfg.quality_laid_out))
	var stone := StoneDesign.from_dict(design) if not design.is_empty() else null
	if stone != null and not stone.is_empty():
		out.append_array(StoneDesignRules.breakdown_lines(stone, corpse, cfg, null))
	elif cfg.marker_quality.has(marker_id):
		out.append(_line(_marker_label(marker_id), cfg.marker_quality[marker_id]))
	var fresh := corpse.freshness_at_burial if corpse.freshness_at_burial >= 0.0 else corpse.freshness
	var stage := CorpseRecord.stage_for(fresh, cfg)
	if fresh < cfg.rot_threshold:
		out.append(_line(LABEL_ROTTEN, cfg.rot_malus))
	elif stage == CorpseRecord.STAGE_FRESH:
		out.append(_line(LABEL_FRESH, cfg.fresh_good_bonus))
	elif stage == CorpseRecord.STAGE_DECAYING:
		out.append(_line(LABEL_DECAYING, cfg.fresh_bad_malus))
	if corpse.examined:
		out.append(_line(LABEL_EXAMINED, cfg.quality_examined))
	if corpse.valuables_decision == CorpseRecord.DECISION_LEFT:
		out.append(_line(LABEL_VALUABLES_LEFT, cfg.valuables_left_bonus))
	elif corpse.valuables_decision == CorpseRecord.DECISION_TAKEN:
		out.append(_line(LABEL_VALUABLES_TAKEN, cfg.valuables_taken_malus))
	for kind: StringName in cfg.harvest_malus:
		if corpse.is_harvested(kind):
			out.append(_line(HARVEST_LABELS.get(kind, String(kind)), cfg.harvest_malus[kind]))
	return out


## Sum of the breakdown, clamped to [quality_min, quality_max].
static func compute(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig, design: Dictionary = {}) -> int:
	var cfg := _config(config)
	var total := 0
	for entry: Dictionary in breakdown(corpse, marker_id, cfg, design):
		total += int(entry.points)
	return clampi(total, mini(cfg.quality_min, cfg.quality_max), maxi(cfg.quality_min, cfg.quality_max))


## base_payment(cause) + floor(quality * payment_per_quality), never negative.
static func payment(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig) -> int:
	return int(payment_parts(corpse, quality, tables, config, &"", null).total)


## Phase 3 §2.6: {base, quality, reputation, total} – base_payment(cause), floor(quality ×
## payment_per_quality), ReputationRules.pay_bonus of `rep_tier` (0 without tier or config);
## total = their sum, never < 0.
static func payment_parts(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig, rep_tier: StringName, rep: ReputationConfig) -> Dictionary:
	var cfg := _config(config)
	var base := 0
	if corpse != null and tables != null:
		base = int(tables.get_cause(corpse.cause_id).get("base_payment", 0))
	elif tables == null:
		push_warning("[GraveQuality] payment without CorpseTables – no base payment")
	var from_quality := floori(quality * cfg.payment_per_quality)
	var bonus := 0
	if rep != null and rep_tier != &"":
		bonus = ReputationRules.pay_bonus(rep_tier, rep)
	return {"base": base, "quality": from_quality, "reputation": bonus, "total": maxi(0, base + from_quality + bonus)}


## Display name of a grave marker item ("Holzkreuz", "Grabstein").
static func _marker_label(marker_id: StringName) -> String:
	if Database.has_item(marker_id):
		var item := Database.item(marker_id) as ItemData
		if item != null and item.display_name != "":
			return item.display_name
	var shape := Database.stone_shape(marker_id) as StoneShapeData
	if shape != null and shape.display_name != "":
		return shape.display_name
	return MARKER_LABELS.get(marker_id, LABEL_MARKER_FALLBACK)


static func _line(label: String, points: int) -> Dictionary:
	return {"label": label, "points": points}


static func _config(config: EconomyConfig) -> EconomyConfig:
	if config == null:
		push_warning("[GraveQuality] no EconomyConfig – using defaults")
		return EconomyConfig.new()
	return config
