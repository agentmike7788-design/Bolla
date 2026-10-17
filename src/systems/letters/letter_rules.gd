class_name LetterRules
extends RefCounted
## STUB (P3) – pure letter rules (docs/PHASE9_DESIGN.md §2.4, §3.4): the pool pick (deterministic from the corpse's
## seed and the day, never twice, pool conditions), why a choice is dimmed, the piety event of a choice (asked for /
## sealed / at the grave).
## W1 (P3) fills the bodies; the signatures are the contract.


static func pick(_seed: int, _day: int, _used: Array[StringName], _pool: Array[LetterData], _tree: SceneTree) -> StringName:
	return &""


static func choice_block_reason(_letter: LetterData, _choice: StringName, _context: Dictionary) -> String:
	return ""


static func piety_event(_letter: LetterData, _choice: StringName) -> StringName:
	return &""
