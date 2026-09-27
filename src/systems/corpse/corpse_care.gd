class_name CorpseCare
extends Node
## STUB (P2) – docs/PHASE4_DESIGN.md §2.1–§2.6, §3.4. Systems/CorpseCare (group
## &"corpse_care", not saved: the state lives in the CorpseRecord). Examination steps,
## preparation and harvesting at the morgue table. Calls JournalManager.add_clue,
## Piety.event, Reputation.event and CorpseManager.notify_changed directly (group API).
## Every successful preparation: corpse_prepared; the 3rd part → Piety.event(&"full_prep"),
## stats.prepared +1.

const GROUP := &"corpse_care"


func _init() -> void:
	add_to_group(GROUP, true)


func step_block_reason(_id: String, _step: StringName) -> String:
	return ""


## Resolves the step, sets examined, flags (sets_flag), clues (JournalManager.add_clue),
## exam_step_done, notify_changed.
func exam_step(_id: String, _step: StringName) -> Dictionary:
	return {}


## All open steps (called after the combined timed action).
func exam_all(_id: String) -> Dictionary:
	return {}


## Debug / Phase-2 API: like exam_all, without time.
func exam_all_instant(_id: String) -> Dictionary:
	return {}


func prep_block_reason(_id: String, _action: StringName, _inv: Inventory, _kind: StringName = &"") -> String:
	return ""


func wash(_id: String, _inv: Inventory) -> bool:
	return false


## Takes 1 item; sets shrouded.
func dress(_id: String, _kind: StringName, _inv: Inventory) -> bool:
	return false


func lay_out(_id: String, _inv: Inventory) -> bool:
	return false


## Window [now, now + balm_window_minutes].
func apply_balm(_id: String, _inv: Inventory) -> bool:
	return false


## Via UtilizationRules.block_reason.
func harvest_block_reason(_id: String, _kind: StringName, _inv: Inventory) -> String:
	return "-"


## Item into the inventory (full → refused), Piety.event, Reputation.event, stats.utilized,
## flag piety_used_day, corpse_harvested.
func harvest(_id: String, _kind: StringName, _inv: Inventory) -> bool:
	return false


## For the UI hint.
func next_loss(_id: String) -> Dictionary:
	return {}
