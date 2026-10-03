class_name CollectionRules
extends RefCounted
## STUB (P7) – pure rules of the specimen collection (docs/PHASE7_DESIGN.md §2.7, §3.4): one compartment
## per organ (AnatomyConfig.ORGANS order), jar / display / bone only (no bundle), the sets completed by
## the shelf's organs (each rewarded once), the price bonus of the university standing (≤ 2).
## W1 (P7) fills the bodies; the signatures are the contract.


## Compartment index 0…6 of `organ` (-1 = none).
static func slot_for(organ: StringName) -> int:
	return AnatomyConfig.ORGANS.find(organ)


static func accepts(_item_id: StringName, _spec: SpecimenRecord) -> bool:
	return false


## Set ids newly completed by shelf_organs ({organ: container}) that are not in `done`.
static func completed_sets(_shelf_organs: Dictionary, _sets: Array[CollectionSetData], _done: PackedStringArray) -> Array[StringName]:
	return []


## min(standing, 2).
static func price_bonus(_standing: int) -> int:
	return 0
