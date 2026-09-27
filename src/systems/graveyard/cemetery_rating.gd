class_name CemeteryRating
extends RefCounted
## Cemetery rating tiers (docs/PHASE3_DESIGN.md §2.5): thresholds from EconomyConfig.rating_thresholds.

const NEGLECTED := &"neglected"
const ORDERLY := &"orderly"
const TENDED := &"tended"
const DIGNIFIED := &"dignified"
## Phase 3: new top tier (appended), from 100.
const VENERABLE := &"venerable"
## Ascending tiers; tier i + 1 starts at rating_thresholds[i].
const TIERS: Array[StringName] = [NEGLECTED, ORDERLY, TENDED, DIGNIFIED, VENERABLE]
const LABELS: Dictionary[StringName, String] = {
	NEGLECTED: "Verwahrlost",
	ORDERLY: "Ordentlich",
	TENDED: "Gepflegt",
	DIGNIFIED: "Würdevoll",
	VENERABLE: "Ehrwürdig",
}


static func rating(total: int, config: EconomyConfig) -> StringName:
	var thresholds := config.rating_thresholds if config != null else PackedInt32Array()
	if thresholds.size() != TIERS.size() - 1:
		if config != null:
			push_warning("[CemeteryRating] rating_thresholds need %d values – using defaults" % (TIERS.size() - 1))
		thresholds = EconomyConfig.new().rating_thresholds
	var tier := 0
	for i: int in thresholds.size():
		if total >= thresholds[i]:
			tier = i + 1
	return TIERS[tier]


## STUB (P3) – Phase 4 §2.14: rating(total) but venerable only with decor ≥ venerable_min_decor
## and dirt_penalty ≤ venerable_max_dirt, otherwise at most dignified (W0: = rating).
static func rating_gated(total: int, _decor: int, _dirt_penalty: int, config: EconomyConfig) -> StringName:
	return rating(total, config)


## STUB (P3) – what venerable still lacks ("Zier 8/12", "Pflegeabzug 9 (höchstens 6)").
static func venerable_missing(_decor: int, _dirt_penalty: int, _config: EconomyConfig) -> PackedStringArray:
	return PackedStringArray()


## German label ("Verwahrlost" … "Ehrwürdig"); "" for unknown ids.
static func label(rating_id: StringName) -> String:
	if not LABELS.has(rating_id):
		if rating_id != &"":
			push_warning("[CemeteryRating] unknown rating '%s'" % rating_id)
		return ""
	return LABELS[rating_id]
