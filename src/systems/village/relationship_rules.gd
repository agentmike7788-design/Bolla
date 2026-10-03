class_name RelationshipRules
extends RefCounted
## Pure relationship rules (docs/PHASE7_DESIGN.md §2.1, §2.4, §3.4): the tier of a value (0…14 Fremd,
## 15…39 Bekannt, 40…69 Vertraut, 70…100 Befreundet – RelationshipConfig.tier_thresholds), the start
## value at the first meeting (VillagerData.start_value + rep_start_bonus by reputation tier; for
## piety_sensitive villagers + piety_start_bonus by piety tier; clamped 0…100) and the tier word.

const TIERS: Array[StringName] = [&"stranger", &"acquainted", &"trusted", &"friend"]
const WORDS: Array[String] = ["Fremd", "Bekannt", "Vertraut", "Befreundet"]
const MIN_VALUE := 0
const MAX_VALUE := 100
const DEFAULT_THRESHOLDS: PackedInt32Array = [15, 40, 70]


static func tier(value: int, cfg: RelationshipConfig) -> StringName:
	var thresholds := _cfg(cfg).tier_thresholds
	if thresholds.size() != TIERS.size() - 1:
		thresholds = DEFAULT_THRESHOLDS
	var index := 0
	for i: int in thresholds.size():
		if value >= thresholds[i]:
			index = i + 1
	return TIERS[index]


## Index in TIERS (-1 = unknown tier).
static func tier_index(t: StringName) -> int:
	return TIERS.find(t)


## `t` is `at_least` or higher (an unknown `at_least` → false).
static func at_least(t: StringName, at_least_tier: StringName) -> bool:
	var need := tier_index(at_least_tier)
	return need >= 0 and tier_index(t) >= need


static func start_value(data: VillagerData, rep_tier: StringName, piety_tier: StringName, cfg: RelationshipConfig) -> int:
	if data == null:
		return 0
	var c := _cfg(cfg)
	var v := data.start_value + _bonus(c.rep_start_bonus, ReputationRules.TIERS.find(rep_tier))
	if data.piety_sensitive:
		v += _bonus(c.piety_start_bonus, PietyRules.TIERS.find(piety_tier))
	return clampi(v, MIN_VALUE, MAX_VALUE)


## „Fremd" | „Bekannt" | „Vertraut" | „Befreundet" ("" for an unknown tier).
static func word(t: StringName) -> String:
	var i := tier_index(t)
	return WORDS[i] if i >= 0 else ""


static func clamp_value(v: int) -> int:
	return clampi(v, MIN_VALUE, MAX_VALUE)


static func _bonus(values: PackedInt32Array, index: int) -> int:
	return values[index] if index >= 0 and index < values.size() else 0


static func _cfg(cfg: RelationshipConfig) -> RelationshipConfig:
	if cfg != null:
		return cfg
	var loaded := Database.config(&"relationship_config") as RelationshipConfig
	return loaded if loaded != null else RelationshipConfig.new()
