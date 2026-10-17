class_name QuestRules
extends RefCounted
## Pure chain rules (docs/PHASE9_DESIGN.md §2.1, §3.4): is a step done (every complete_on kind, complete_count), the
## next visible step, the deadline day (GameState flag + offset), why a choice is dimmed.
##
## step_complete(step, state, tree) – `state` is the view Quests builds for one chain (all keys optional):
##   notes      Dictionary  note key → PackedStringArray of the distinct arguments noted (Quests.note)
##   choice     StringName  the choice made in this step (&"" = none)
##   endings    Dictionary  quest_id → ending id of every chain with an ending (complete_on ending)
##   flags      Dictionary  flags to test instead of GameState (tests)
##   clues      Array       known clue ids instead of the journal / clue_<id> flags (tests)
##   insights   Array       unlocked insight ids instead of the journal (tests)
##   orders     Dictionary  order id → state instead of Orders in the tree (tests)
## complete_on: flag (GameState flags) · clue (journal clue / flag clue_<id>) · insight (JournalManager.has_insight) ·
## order (Orders.state completed) · note (Quests.note: complete_count 0 = every key noted once, n = n distinct
## arguments over the keys) · choice (a choice made) · ending (complete_ids "<quest>" or "<quest>:<ending>").
## complete_count 0 = all ids, n = at least n of them (notes: distinct arguments).

const NONE := -1
const JOURNAL_GROUP := &"journal"
const ORDERS_GROUP := &"orders"
const ORDER_DONE := &"completed"
## A dimmed choice without its own block_text.
const TEXT_BLOCKED := "Das geht jetzt nicht."


static func step_complete(step: QuestStepData, state: Dictionary, tree: SceneTree) -> bool:
	if step == null:
		return false
	match step.complete_on:
		QuestStepData.ON_CHOICE:
			return StringName(str(state.get("choice", ""))) != &""
		QuestStepData.ON_NOTE:
			return _notes_done(step, state.get("notes", {}))
		QuestStepData.ON_FLAG:
			return _count_done(step, func(id: StringName) -> bool: return _flag(id, state))
		QuestStepData.ON_CLUE:
			return _count_done(step, func(id: StringName) -> bool: return _clue(id, state, tree))
		QuestStepData.ON_INSIGHT:
			return _count_done(step, func(id: StringName) -> bool: return _insight(id, state, tree))
		QuestStepData.ON_ORDER:
			return _count_done(step, func(id: StringName) -> bool: return _order_done(id, state, tree))
		QuestStepData.ON_ENDING:
			return _count_done(step, func(id: StringName) -> bool: return _ending_done(id, state))
	return false


## The first step of `quest` not in `done` (in order; null = all done / no quest).
static func next_step(quest: QuestData, done: Array[StringName]) -> QuestStepData:
	if quest == null:
		return null
	for s: QuestStepData in quest.steps:
		if s != null and not done.has(s.id):
			return s
	return null


## From the GameState flag + offset; −1 = none (no deadline or the flag holds no day yet).
static func deadline_day(step: QuestStepData) -> int:
	if step == null or step.deadline_flag == &"" or not GameState.has_flag(step.deadline_flag):
		return NONE
	var v: Variant = GameState.get_flag(step.deadline_flag)
	if not (v is int or v is float) or v is bool:
		return NONE
	return int(v) + step.deadline_offset


## "" = the choice can be made; else its block_text (or TEXT_BLOCKED). `context` is the dialogue context; its optional
## "conditions" Dictionary (condition text → bool) answers conditions instead of DialogueConditions (a caller that
## already knows them, tests).
static func choice_block_reason(choice: QuestChoiceData, context: Dictionary) -> String:
	if choice == null:
		return TEXT_BLOCKED
	var known: Variant = context.get("conditions", {})
	for cond: String in choice.conditions:
		var met := false
		if known is Dictionary and (known as Dictionary).has(cond):
			met = (known as Dictionary)[cond] == true
		else:
			met = DialogueConditions.check(cond, context)
		if not met:
			return choice.block_text if choice.block_text != "" else TEXT_BLOCKED
	return ""


## The choice `choice_id` of `step` (null = none).
static func choice(step: QuestStepData, choice_id: StringName) -> QuestChoiceData:
	if step == null:
		return null
	for c: QuestChoiceData in step.choices:
		if c != null and c.id == choice_id:
			return c
	return null


## The step `step_id` of `quest` (null = none).
static func step(quest: QuestData, step_id: StringName) -> QuestStepData:
	if quest == null:
		return null
	for s: QuestStepData in quest.steps:
		if s != null and s.id == step_id:
			return s
	return null


## The ending `ending_id` of `quest` (null = none).
static func ending_data(quest: QuestData, ending_id: StringName) -> QuestEndingData:
	if quest == null:
		return null
	for e: QuestEndingData in quest.endings:
		if e != null and e.id == ending_id:
			return e
	return null


## Progress of a step as [done, total] for the HUD („3/5 Gräber verglichen"); [0, 0] for choices.
static func step_progress(step: QuestStepData, state: Dictionary, tree: SceneTree) -> Vector2i:
	if step == null or step.complete_on == QuestStepData.ON_CHOICE:
		return Vector2i.ZERO
	if step.complete_on == QuestStepData.ON_NOTE:
		var args := _note_args(step, state.get("notes", {}))
		var need := step.complete_count if step.complete_count > 0 else step.complete_ids.size()
		return Vector2i(mini(args, need), need)
	var done := 0
	for id: StringName in step.complete_ids:
		var ok := false
		match step.complete_on:
			QuestStepData.ON_FLAG:
				ok = _flag(id, state)
			QuestStepData.ON_CLUE:
				ok = _clue(id, state, tree)
			QuestStepData.ON_INSIGHT:
				ok = _insight(id, state, tree)
			QuestStepData.ON_ORDER:
				ok = _order_done(id, state, tree)
			QuestStepData.ON_ENDING:
				ok = _ending_done(id, state)
		if ok:
			done += 1
	var total := step.complete_count if step.complete_count > 0 else step.complete_ids.size()
	return Vector2i(mini(done, total), total)


# --- internals ------------------------------------------------------------------------------------

static func _count_done(step: QuestStepData, met: Callable) -> bool:
	if step.complete_ids.is_empty():
		return false
	var n := 0
	for id: StringName in step.complete_ids:
		if bool(met.call(id)):
			n += 1
	return n >= (step.complete_count if step.complete_count > 0 else step.complete_ids.size())


static func _notes_done(step: QuestStepData, notes: Variant) -> bool:
	if step.complete_ids.is_empty():
		return false
	if step.complete_count > 0:
		return _note_args(step, notes) >= step.complete_count
	for key: StringName in step.complete_ids:
		if _note_list(notes, key).is_empty():
			return false
	return true


## Distinct arguments noted under the step's keys.
static func _note_args(step: QuestStepData, notes: Variant) -> int:
	var seen := {}
	for key: StringName in step.complete_ids:
		for a: String in _note_list(notes, key):
			seen["%s|%s" % [key, a]] = true
	return seen.size()


static func _note_list(notes: Variant, key: StringName) -> PackedStringArray:
	if not notes is Dictionary:
		return PackedStringArray()
	var raw: Variant = (notes as Dictionary).get(key, (notes as Dictionary).get(String(key)))
	if raw is PackedStringArray:
		return raw
	var out := PackedStringArray()
	if raw is Array:
		for a: Variant in raw:
			out.append(str(a))
	return out


static func _flag(id: StringName, state: Dictionary) -> bool:
	var flags: Variant = state.get("flags")
	if flags is Dictionary:
		var v: Variant = (flags as Dictionary).get(id, (flags as Dictionary).get(String(id)))
		return true if v else false
	return GameState.flag_on(id)


static func _clue(id: StringName, state: Dictionary, tree: SceneTree) -> bool:
	var clues: Variant = state.get("clues")
	if clues is Array:
		return (clues as Array).has(id) or (clues as Array).has(String(id))
	var journal := tree.get_first_node_in_group(JOURNAL_GROUP) if tree != null else null
	if journal != null and journal.has_method(&"has_clue"):
		return bool(journal.call(&"has_clue", id))
	return GameState.flag_on(StringName(JournalManager.CLUE_FLAG_PREFIX + String(id)))


static func _insight(id: StringName, state: Dictionary, tree: SceneTree) -> bool:
	var insights: Variant = state.get("insights")
	if insights is Array:
		return (insights as Array).has(id) or (insights as Array).has(String(id))
	var journal := tree.get_first_node_in_group(JOURNAL_GROUP) if tree != null else null
	if journal != null and journal.has_method(&"has_insight"):
		return bool(journal.call(&"has_insight", id))
	return false


static func _order_done(id: StringName, state: Dictionary, tree: SceneTree) -> bool:
	var orders: Variant = state.get("orders")
	if orders is Dictionary:
		return StringName(str((orders as Dictionary).get(id, (orders as Dictionary).get(String(id), "")))) == ORDER_DONE
	var node := tree.get_first_node_in_group(ORDERS_GROUP) if tree != null else null
	if node != null and node.has_method(&"state"):
		return StringName(str(node.call(&"state", id))) == ORDER_DONE
	return false


## "<quest>" (any ending) or "<quest>:<ending>".
static func _ending_done(id: StringName, state: Dictionary) -> bool:
	var endings: Variant = state.get("endings", {})
	if not endings is Dictionary:
		return false
	var parts := String(id).split(":")
	var got := StringName(str((endings as Dictionary).get(StringName(parts[0]), (endings as Dictionary).get(parts[0], ""))))
	if got == &"":
		return false
	return parts.size() < 2 or got == StringName(parts[1])
