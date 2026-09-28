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
## venerable_missing() parts (HUD / tooltip: "Ehrwürdig: noch Zier 8/12").
const TEXT_MISSING_DECOR := "Zier %d/%d"
const TEXT_MISSING_DIRT := "Pflegeabzug %d (höchstens %d)"


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


## Phase 4 §2.14: rating(total), but venerable only with decor ≥ venerable_min_decor and
## dirt_penalty ≤ venerable_max_dirt – otherwise at most dignified.
static func rating_gated(total: int, decor: int, dirt_penalty: int, config: EconomyConfig) -> StringName:
	var plain := rating(total, config)
	if plain == VENERABLE and not venerable_missing(decor, dirt_penalty, config).is_empty():
		return DIGNIFIED
	return plain


## What venerable still lacks besides the quality: "Zier 8/12", "Pflegeabzug 9 (höchstens 6)";
## empty = both conditions hold.
static func venerable_missing(decor: int, dirt_penalty: int, config: EconomyConfig) -> PackedStringArray:
	var cfg := EconomyConfig.resolve(config)
	var out := PackedStringArray()
	if decor < cfg.venerable_min_decor:
		out.append(TEXT_MISSING_DECOR % [maxi(decor, 0), cfg.venerable_min_decor])
	if dirt_penalty > cfg.venerable_max_dirt:
		out.append(TEXT_MISSING_DIRT % [dirt_penalty, cfg.venerable_max_dirt])
	return out


## German label ("Verwahrlost" … "Ehrwürdig"); "" for unknown ids.
static func label(rating_id: StringName) -> String:
	if not LABELS.has(rating_id):
		if rating_id != &"":
			push_warning("[CemeteryRating] unknown rating '%s'" % rating_id)
		return ""
	return LABELS[rating_id]
