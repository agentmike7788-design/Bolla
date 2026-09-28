class_name PietyRules
extends RefCounted
## Pure piety rules (docs/PHASE4_DESIGN.md §2.7, §3.4): tiers from PietyConfig.tier_thresholds
## (tier i + 1 from value ≥ threshold i), labels, the journal's self image, the daily recovery
## towards 0 and the Phase-13+ affinity hook. TIERS / LABELS are final (user decision §14.1).

const TIERS: Array[StringName] = [&"hardhearted", &"callous", &"matter_of_fact", &"considerate", &"devout"]
const LABELS := {"hardhearted": "Hartherzig", "callous": "Abgebrüht", "matter_of_fact": "Sachlich", "considerate": "Rücksichtsvoll", "devout": "Andächtig"}
## Journal page "Ich" (§2.7) – one sentence per tier, never a number.
const SELF_IMAGES := {
	"hardhearted": "Die Toten sind Ware. Du schläfst trotzdem.",
	"callous": "Man gewöhnt sich. Das ist ja das Schlimme.",
	"matter_of_fact": "Ein Handwerk wie jedes andere. Meistens.",
	"considerate": "Du sprichst mit ihnen, wenn keiner zuhört.",
	"devout": "Du gehst leise zwischen ihnen. Sie merken es.",
}
## Middle tier (index 2) – fallback for unknown ids.
const DEFAULT_TIER := &"matter_of_fact"
const AFFINITY_SOUL := &"soul"
const AFFINITY_BONE := &"bone"


static func tier(value: int, cfg: PietyConfig) -> StringName:
	var thresholds := _cfg(cfg).tier_thresholds
	if thresholds.size() != TIERS.size() - 1:
		push_warning("[PietyRules] tier_thresholds need %d values – using defaults" % (TIERS.size() - 1))
		thresholds = PietyConfig.new().tier_thresholds
	var index := 0
	for i: int in thresholds.size():
		if value >= thresholds[i]:
			index = i + 1
	return TIERS[index]


## 0 (hardhearted) … 4 (devout); unknown ids → the middle tier (2).
static func tier_index(t: StringName) -> int:
	var i := TIERS.find(t)
	return i if i >= 0 else TIERS.find(DEFAULT_TIER)


## "Hartherzig" … "Andächtig"; "" for unknown ids.
static func label(t: StringName) -> String:
	return String(LABELS.get(String(t), ""))


## Sentence for the journal page "Ich" (§2.7); "" for unknown ids.
static func self_image(t: StringName) -> String:
	return String(SELF_IMAGES.get(String(t), ""))


## +daily_recovery towards 0, only below 0 and without harvesting yesterday; never past 0.
static func recovery(value: int, used_yesterday: bool, cfg: PietyConfig) -> int:
	if value >= 0 or used_yesterday:
		return 0
	return mini(maxi(_cfg(cfg).daily_recovery, 0), -value)


## Hook for Phase 13+: &"soul" (≥ threshold) · &"bone" (≤ −threshold) · &"". No Phase-4 logic
## reads it.
static func affinity(value: int, cfg: PietyConfig) -> StringName:
	var threshold := absi(_cfg(cfg).affinity_threshold)
	if value >= threshold:
		return AFFINITY_SOUL
	if value <= -threshold:
		return AFFINITY_BONE
	return &""


## Per-tier value of a PietyConfig array (gift_by_tier, buyer_bonus_by_tier); 0 when missing.
static func per_tier(values: PackedInt32Array, t: StringName) -> int:
	var i := tier_index(t)
	return values[i] if i < values.size() else 0


static func _cfg(cfg: PietyConfig) -> PietyConfig:
	if cfg != null:
		return cfg
	var real := Database.config(&"piety_config") as PietyConfig
	return real if real != null else PietyConfig.new()
