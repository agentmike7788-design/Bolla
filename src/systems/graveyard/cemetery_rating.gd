class_name CemeteryRating
extends RefCounted
## Cemetery rating tiers (docs §2.4): thresholds from EconomyConfig.rating_thresholds.

const NEGLECTED := &"neglected"
const ORDERLY := &"orderly"
const TENDED := &"tended"
const DIGNIFIED := &"dignified"
## Ascending tiers; tier i + 1 starts at rating_thresholds[i].
const TIERS: Array[StringName] = [NEGLECTED, ORDERLY, TENDED, DIGNIFIED]
const LABELS: Dictionary[StringName, String] = {
	NEGLECTED: "Verwahrlost",
	ORDERLY: "Ordentlich",
	TENDED: "Gepflegt",
	DIGNIFIED: "Würdevoll",
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


## German label ("Verwahrlost" … "Würdevoll"); "" for unknown ids.
static func label(rating_id: StringName) -> String:
	if not LABELS.has(rating_id):
		if rating_id != &"":
			push_warning("[CemeteryRating] unknown rating '%s'" % rating_id)
		return ""
	return LABELS[rating_id]
