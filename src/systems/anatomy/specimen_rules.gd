class_name SpecimenRules
extends RefCounted
## STUB (P4) – pure specimen rules (docs/PHASE7_DESIGN.md §2.6, §2.6.1, §2.6.3, §3.4): harvest block
## reasons ("-" = no card at all: anatomy unknown / not the crypt table), clarity (a jar keeps it; a
## bundle falls linearly to 0 over bundle_minutes of effective time – cold windows × pult_cold_factor),
## spoiled, the clarity word, Quast's price, the finding of a specimen.
## W1 (P4) fills the bodies; the signatures are the contract.

const REASON_NO_CARD := "-"
const TEXT_TOO_LATE := "Zu spät. Daran lässt sich nichts mehr zeigen."
const TEXT_NO_TOOL := "Werkzeug fehlt – Quast hat es."
const TEXT_DRESSED := "Nach dem Einkleiden nicht mehr zugänglich."
const TEXT_MAX := "Mehr nimmst du ihr nicht."
const CLARITY_WORDS: Array[String] = ["sehr gut", "gut", "trüb", "kaum lesbar"]


static func harvest_block_reason(_record: CorpseRecord, _organ: StringName, _container: StringName, _inv: Inventory,
		_room: StringName, _known: bool, _cfg: AnatomyConfig) -> String:
	return REASON_NO_CARD


static func clarity(spec: SpecimenRecord, _now_total: int, _cfg: AnatomyConfig) -> float:
	return spec.clarity_at_harvest if spec != null else 0.0


static func is_spoiled(_spec: SpecimenRecord, _now_total: int, _cfg: AnatomyConfig) -> bool:
	return false


static func clarity_word(_c: float, _cfg: AnatomyConfig) -> String:
	return ""


static func price(_spec: SpecimenRecord, _now_total: int, _friend: bool, _cfg: AnatomyConfig) -> int:
	return 0


## Priority first, then the order of §2.6.3; null = none.
static func finding_for(_spec: SpecimenRecord, _record: CorpseRecord, _findings: Array[SpecimenFindingData]) -> SpecimenFindingData:
	return null
