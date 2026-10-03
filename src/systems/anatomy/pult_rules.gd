class_name PultRules
extends RefCounted
## STUB (P7) – pure rules of the preparation desk (docs/PHASE7_DESIGN.md §2.7, §3.4): a medicine from a
## specimen in a jar (allowed organs, clarity ≥ min_clarity, ingredients), sealing a bundle, a display
## specimen, the bone specimen of the hand, inspecting. A medicine at the end of its TimedAction:
## Specimens.consume(uid, inv, &"used"), ingredients gone, the output into the inventory,
## stats.medicines_made. W1 (P7) fills the bodies; the signatures are the contract.


static func medicine_block_reason(_med: MedicineData, _spec: SpecimenRecord, _inv: Inventory, _now_total: int, _cfg: AnatomyConfig) -> String:
	return ""


static func seal_block_reason(_spec: SpecimenRecord, _inv: Inventory, _now_total: int, _cfg: AnatomyConfig) -> String:
	return ""


static func display_block_reason(_spec: SpecimenRecord, _inv: Inventory, _cfg: AnatomyConfig) -> String:
	return ""


static func bone_block_reason(_spec: SpecimenRecord, _inv: Inventory, _now_total: int, _cfg: AnatomyConfig) -> String:
	return ""


static func inspect_block_reason(_spec: SpecimenRecord, _now_total: int, _cfg: AnatomyConfig) -> String:
	return ""
