class_name CorpseExam
extends RefCounted
## STUB (P2) – docs/PHASE4_DESIGN.md §2.1, §2.2, §3.4. Pure examination rules, testable
## without a scene tree.


## Finds `step` can reveal: generic by trait_id (trait present, step = trait_steps) and
## cause_id; story finds from story.finds; a story find with trait_id replaces the generic one.
static func candidates(_record: CorpseRecord, _step: StringName, _finds: Array[FindData], _story: StoryCorpseData, _cfg: ExamConfig) -> Array[FindData]:
	return []


## {revealed: Array[StringName], lost: Array[StringName]} by record.freshness.
static func resolve(_record: CorpseRecord, _candidates: Array[FindData]) -> Dictionary:
	return {"revealed": [] as Array[StringName], "lost": [] as Array[StringName]}


## "" | "Schon untersucht." | "Nach dem Einkleiden nicht mehr zugänglich."
static func block_reason(_record: CorpseRecord, _step: StringName, _cfg: ExamConfig) -> String:
	return ""


static func open_steps(_record: CorpseRecord, _cfg: ExamConfig) -> Array[StringName]:
	return []


static func minutes_for(_steps: Array[StringName], _cfg: ExamConfig) -> int:
	return 0


## {minutes, stage_label} of the next find that would be lost | {}.
static func next_loss(_record: CorpseRecord, _pending: Array[FindData], _now_total: int, _decay_per_hour: float, _balm_factor: float) -> Dictionary:
	return {}
