class_name QuestRules
extends RefCounted
## STUB (P1) – pure chain rules (docs/PHASE9_DESIGN.md §2.1, §3.4): is a step done (every complete_on kind,
## complete_count), the next visible step, the deadline day (GameState flag + offset), why a choice is dimmed.
## W1 (P1) fills the bodies; the signatures are the contract.


static func step_complete(_step: QuestStepData, _state: Dictionary, _tree: SceneTree) -> bool:
	return false


static func next_step(_quest: QuestData, _done: Array[StringName]) -> QuestStepData:
	return null


## From the GameState flag + offset; −1 = none.
static func deadline_day(_step: QuestStepData) -> int:
	return -1


static func choice_block_reason(_choice: QuestChoiceData, _context: Dictionary) -> String:
	return ""
