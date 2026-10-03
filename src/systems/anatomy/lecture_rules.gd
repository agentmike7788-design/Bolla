class_name LectureRules
extends RefCounted
## STUB (P8) – pure rules of Quast's night lecture (docs/PHASE7_DESIGN.md §2.6.4, §3.4): every third
## night (day % every_days == 0) from 23:00 to 00:30 (lecture.start, lecture.window); a jar / bone /
## display specimen with clarity ≥ 0.5, not spoiled, no bundle; one lecture per evening; the fee
## (4 + organ bonus + standing); the deterministic rumour (25 %, 10 % from „Geschätzt").
## W1 (P8) fills the bodies; the signatures are the contract.

const TEXT_BUNDLE := "Kein Bündel. Quast will ein Glas."


static func is_lecture_night(_day: int, _minute: int, _cfg: AnatomyConfig) -> bool:
	return false


static func block_reason(_spec: SpecimenRecord, _now_total: int, _invited: bool, _held_today: bool, _cfg: AnatomyConfig) -> String:
	return ""


static func fee(_organ: StringName, _standing: int, _cfg: AnatomyConfig) -> int:
	return 0


## Deterministic from day and seed.
static func rumor(_day: int, _seed: int, _rep_tier: StringName, _cfg: AnatomyConfig) -> bool:
	return false
