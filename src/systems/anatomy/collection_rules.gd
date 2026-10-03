class_name CollectionRules
extends RefCounted
## Pure rules of the specimen collection (docs/PHASE7_DESIGN.md §2.7, §3.4): one compartment per organ
## (AnatomyConfig.ORGANS order), jar / display / bone only (no bundle), the sets completed by the
## shelf's organs (each rewarded once – `done`), the price bonus of the university standing (≤ 2).

const MAX_STANDING := 4
const MAX_PRICE_BONUS := 2
## Item id of each container on the shelf (Specimens.ITEM_*); a bundle is never accepted.
const ITEM_OF_CONTAINER: Dictionary[StringName, StringName] = {
	&"jar": &"specimen_jar", &"display": &"display_specimen", &"bone": &"bone_specimen",
}


## Compartment index 0…6 of `organ` (-1 = none).
static func slot_for(organ: StringName) -> int:
	return AnatomyConfig.ORGANS.find(organ)


## A held jar, display or bone specimen whose item id matches its container (no bundle).
static func accepts(item_id: StringName, spec: SpecimenRecord) -> bool:
	if spec == null or spec.state != SpecimenRecord.STATE_HELD or slot_for(spec.organ) < 0:
		return false
	return ITEM_OF_CONTAINER.get(spec.container, &"") == item_id and item_id != &""


## Set ids newly completed by shelf_organs ({organ: SpecimenRecord} of the filled compartments) that are
## not in `done`: all the set's organs present at once; needs_display → at least one of them a display
## specimen. Set order.
static func completed_sets(shelf_organs: Dictionary, sets: Array[CollectionSetData], done: PackedStringArray) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: CollectionSetData in sets:
		if s == null or s.organs.is_empty() or done.has(String(s.id)):
			continue
		var all := true
		var display := false
		for organ: StringName in s.organs:
			var spec: Variant = shelf_organs.get(organ)
			if not spec is SpecimenRecord:
				all = false
				break
			if (spec as SpecimenRecord).container == SpecimenRecord.CONTAINER_DISPLAY:
				display = true
		if all and (display or not s.needs_display):
			out.append(s.id)
	return out


## min(standing, 2).
static func price_bonus(standing: int) -> int:
	return clampi(standing, 0, MAX_PRICE_BONUS)


## The standing after a set worth `gain` (never above 4, never falling).
static func add_standing(standing: int, gain: int) -> int:
	return clampi(standing + maxi(gain, 0), 0, MAX_STANDING)
