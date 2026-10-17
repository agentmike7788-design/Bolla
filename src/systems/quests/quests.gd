class_name Quests
extends Node
## Systems/Quests (docs/PHASE9_DESIGN.md §2.1, §1.2, §1.5, §3.1, §3.3, §3.4, §5.1), groups &"quests", &"saveable",
## save_id quests / 81: the slim chain core over the existing systems – the chains q_who_knows, q_letters, q_case
## (QuestData), their steps (done by existing events: flags, clues, insights, orders of category quest, notes,
## choices, endings), choices with DialogueActions, deadlines (06:00, fallback_choice), the pinned entry of
## „Vorhaben", the opening p9_open and the chapter „Wer weiß, wann?".
##
## Opening (§1.2): the first minute ≥ intro_minute (06:00) after the Phase-8 chapter (unlock_flag) sets p9_open and
## p9_open_day (apply_morning, idempotent); a migrated v7 state (load_state got {}) with the chapter opens at once in
## post_load. Chains open when their open_conditions hold (DialogueConditions); their steps run strictly in order – a
## step becomes current when the previous one is done and is checked at once (events before that count: notes are
## kept, flags / clues / insights / orders are read). quest_changed: (quest, first step, opened) · (quest, step,
## step) when a step is done · (quest, step, chosen) · (quest, step, ended) when the choice ends the chain ·
## (quest, &"", ended) when the ending is settled (settle_on flag). Deadlines (QuestRules.deadline_day) are checked at
## 06:00: a deadline step not chosen by then takes its fallback_choice – even while an earlier step is still current
## (the village has its own course: the chain ends, the earlier steps stay undone).
## Listens (own state only, then QuestRules): time_tick, order_changed, clue_found, insight_unlocked, letter_changed,
## light_entry_changed, hill_request_changed (a large request completed since p9_open counts for the chapter),
## chapter_completed (the Phase-8 chapter: the unlock moment). Choices run their actions through DialogueActions.
## Saved (§5.1): {open_day, open, step, done, step_day, choices, ending, settled, notes, pinned, goal_done} + large_done
## (the large requests completed since p9_open).

const GROUP := &"quests"
const STATE_NONE := &""
const STATE_OPEN := &"open"
const STATE_ENDED := &"ended"
const STATE_SETTLED := &"settled"
const OPEN_FLAG := &"p9_open"
const OPEN_DAY_FLAG := &"p9_open_day"
## quest_changed states (§3.3).
const CHANGE_OPENED := &"opened"
const CHANGE_STEP := &"step"
const CHANGE_CHOSEN := &"chosen"
const CHANGE_ENDED := &"ended"
## The ending of a chain whose last step is done without a choice ending and with no single ending of its own.
const ENDING_DONE := &"done"
const STAT_STEPS := &"quest_steps"
const STAT_CHOICES := &"quest_choices"
const SUMMARY_PANEL := &"slice_summary"
const MINUTES_PER_DAY := 1440
const ORDERS_GROUP := &"orders"
const LETTERS_GROUP := &"letters"
const HILL_GROUP := &"hill_requests"
const PLAYER_GROUP := &"player"
const SIZE_LARGE := &"large"
const HILL_COMPLETED := &"completed"

@export var save_id: String = "quests"
@export var save_order: int = 81

## Rules; null = data/config/quest_config.tres (resolved lazily).
var config: QuestConfig
## Tests: the chains by id (empty = Database.quests()).
var quest_table: Dictionary[StringName, QuestData] = {}

var _open_day: int = 0
var _open: Array[StringName] = []
var _step: Dictionary[StringName, StringName] = {}
var _done: Dictionary[StringName, Array] = {}
var _step_day: Dictionary[StringName, int] = {}
var _choices: Dictionary[StringName, Dictionary] = {}
var _ending: Dictionary[StringName, StringName] = {}
var _settled: Array[StringName] = []
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _pinned: StringName = &""
var _goal_done: bool = false
var _large_done: Array[StringName] = []
## Not saved: the total minute the unlock flag was first seen (opening = the next 06:00 after it), the day of the last
## morning check, load_state got a Phase-9 state (not the {} of a migrated v7 save).
var _unlock_seen_total: int = -1
var _morning_day: int = -1
var _loaded_v8: bool = false
var _refreshing: bool = false


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.order_changed.connect(_on_event_2)
	EventBus.clue_found.connect(_on_clue)
	EventBus.insight_unlocked.connect(_on_insight)
	EventBus.letter_changed.connect(_on_letter)
	EventBus.light_entry_changed.connect(_on_event_2)
	EventBus.hill_request_changed.connect(_on_hill)
	EventBus.chapter_completed.connect(_on_chapter)


# --- queries --------------------------------------------------------------------------------------

func is_open() -> bool:
	return GameState.flag_on(_cfg().open_flag)


func open_day() -> int:
	var v: Variant = GameState.get_flag(_cfg().open_day_flag, -1)
	return int(v) if (v is int or v is float) else -1


## &"" | &"open" | &"ended" | &"settled"
func state(quest_id: StringName) -> StringName:
	if _settled.has(quest_id):
		return STATE_SETTLED
	if _ending.has(quest_id) and _ending[quest_id] != &"":
		return STATE_ENDED
	if _open.has(quest_id):
		return STATE_OPEN
	return STATE_NONE


## The current (visible) step; &"" = none (not open / ended / all done).
func current_step(quest_id: StringName) -> StringName:
	return _step.get(quest_id, &"")


func steps_done(quest_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in _done.get(quest_id, []):
		out.append(StringName(str(s)))
	return out


func choice_of(quest_id: StringName, step_id: StringName) -> StringName:
	var c: Dictionary = _choices.get(quest_id, {})
	return StringName(str(c.get(step_id, c.get(String(step_id), ""))))


func ending(quest_id: StringName) -> StringName:
	return _ending.get(quest_id, &"")


func notes(key: StringName) -> PackedStringArray:
	return _notes.get(key, PackedStringArray())


func pinned() -> StringName:
	return _pinned


## The chain `quest_id` (quest_table / Database) or null.
func quest_data(quest_id: StringName) -> QuestData:
	if not quest_table.is_empty():
		return quest_table.get(quest_id)
	return Database.quest(quest_id) as QuestData


## All chains, sorted by order (then id).
func all_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	var list: Array = quest_table.values() if not quest_table.is_empty() else Database.quests()
	for q: Variant in list:
		if q is QuestData:
			out.append(q)
	out.sort_custom(func(a: QuestData, b: QuestData) -> bool:
		return a.order < b.order or (a.order == b.order and String(a.id) < String(b.id)))
	return out


## Day the current step of `quest_id` became visible (0 = unknown).
func step_day(quest_id: StringName) -> int:
	return int(_step_day.get(quest_id, 0))


## The rules' view of one chain (QuestRules.step_complete state) for `step_id`.
func view(quest_id: StringName, step_id: StringName) -> Dictionary:
	var endings := {}
	for q: StringName in _ending:
		if _ending[q] != &"":
			endings[q] = _ending[q]
	return {"notes": _notes, "choice": choice_of(quest_id, step_id), "endings": endings}


## [done, total] of the current step (QuestRules.step_progress) – the HUD line.
func progress(quest_id: StringName) -> Vector2i:
	var q := quest_data(quest_id)
	var s := QuestRules.step(q, current_step(quest_id))
	return QuestRules.step_progress(s, view(quest_id, current_step(quest_id)), _tree())


## The deadline day of the current step of `quest_id` (−1 = none).
func deadline(quest_id: StringName) -> int:
	return QuestRules.deadline_day(QuestRules.step(quest_data(quest_id), current_step(quest_id)))


## The choices of the current step: [{id, label, reason}] (reason "" = can be chosen; never a number).
func choices(quest_id: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := QuestRules.step(quest_data(quest_id), current_step(quest_id))
	if s == null or s.complete_on != QuestStepData.ON_CHOICE or state(quest_id) != STATE_OPEN:
		return out
	for c: QuestChoiceData in s.choices:
		if c != null:
			out.append({"id": c.id, "label": c.label, "reason": QuestRules.choice_block_reason(c, _context(context))})
	return out


## Large requests completed since p9_open.
func large_done() -> Array[StringName]:
	return _large_done.duplicate()


# --- changes --------------------------------------------------------------------------------------

## 06:00: p9_open (idempotent), deadlines, offer the orders of the steps.
func apply_morning(day: int) -> void:
	_try_open(day)
	if not is_open() or day <= _morning_day:
		return
	_morning_day = day
	_open_chains()
	_deadlines(day)
	_offer_orders()
	_refresh()


## v7 with who_comes_up_complete → p9_open at once.
func post_load() -> void:
	_morning_day = TimeManager.day if TimeManager.minute_of_day >= _cfg().intro_minute else TimeManager.day - 1
	if not is_open() and GameState.flag_on(_cfg().unlock_flag) and not _loaded_v8:
		open_now()


## Sets p9_open / p9_open_day now (post_load, the morning rule, debug „p9 open") and opens the chains. Idempotent.
func open_now(day: int = -1) -> void:
	var cfg := _cfg()
	if not is_open():
		GameState.set_flag(cfg.open_flag, true)
	if open_day() <= 0:
		GameState.set_flag(cfg.open_day_flag, day if day > 0 else TimeManager.day)
	_open_day = open_day()
	_open_chains()
	_offer_orders()
	_refresh()


## A choice of the current step (Dialogue quest_choose, the journal's „Niemandem sagen"). Chosen is chosen; false
## when the chain / step is not current, the choice unknown or dimmed (QuestRules.choice_block_reason).
func choose(quest_id: StringName, step_id: StringName, choice_id: StringName) -> bool:
	var q := quest_data(quest_id)
	if q == null or state(quest_id) != STATE_OPEN or current_step(quest_id) != step_id:
		return false
	var s := QuestRules.step(q, step_id)
	if s == null or s.complete_on != QuestStepData.ON_CHOICE or choice_of(quest_id, step_id) != &"":
		return false
	var c := QuestRules.choice(s, choice_id)
	var context := _context({})
	if c == null or QuestRules.choice_block_reason(c, context) != "":
		return false
	_apply_choice(q, s, c, context)
	_refresh()
	return true


## An event of a prompt / a system (kladde_read, date_grave:<entry>, pocket_decided, answer_posted, stranger_answered …):
## kept once per argument; the chains are checked.
func note(key: StringName, arg: String) -> void:
	if key == &"":
		return
	var list: PackedStringArray = _notes.get(key, PackedStringArray())
	if list.has(arg):
		return
	list.append(arg)
	_notes[key] = list
	_refresh()


## Pins `entry_id` (a chain, request or order of „Vorhaben") to the HUD line; &"" = unpin („Nicht mehr verfolgen").
## QuestConfig.max_pinned 1: a new pin replaces the old (max_pinned 0 = pinning off).
func pin(entry_id: StringName) -> void:
	_pinned = entry_id if _cfg().max_pinned > 0 else &""


## §1.5 – exactly once: who_knows_when_complete, chapter_completed(&"who_knows_when"), the summary panel.
func check_goal() -> bool:
	var cfg := _cfg()
	if _goal_done or GameState.flag_on(cfg.goal_flag):
		_goal_done = true
		return false
	if not is_open():
		return false
	var p := goal_progress()
	if not bool(p.main) or not bool(p.letters_step) or int(p.letters_decided) < cfg.goal_letters_decided \
			or int(p.large) < cfg.goal_large_requests:
		return false
	_goal_done = true
	GameState.set_flag(cfg.goal_flag, true)
	EventBus.chapter_completed.emit(cfg.chapter_id)
	EventBus.ui_panel_requested.emit(SUMMARY_PANEL, chapter_context())
	return true


## {main, letters_step, letters_decided, large} (+ main_ending, letters_goal, large_goal for the objective line).
func goal_progress() -> Dictionary:
	var cfg := _cfg()
	var letters := _first(LETTERS_GROUP)
	var decided := int(letters.call(&"decided_count")) if letters != null and letters.has_method(&"decided_count") else 0
	return {"main": state(cfg.goal_main) == STATE_SETTLED, "letters_step": steps_done(cfg.goal_letters).has(cfg.goal_letters_step),
			"letters_decided": decided, "large": _large_done.size(), "main_ending": ending(cfg.goal_main),
			"letters_goal": cfg.goal_letters_decided, "large_goal": cfg.goal_large_requests}


## The chapter panel (§1.5, variant who_knows_when): days since p9_open, the main ending with its closing line,
## whom you told, letters by decision, errands, larger requests, the stranger, the Phase-9 stats.
func chapter_context() -> Dictionary:
	var cfg := _cfg()
	var context := {}
	var graveyard := _first(&"graveyard")
	if graveyard != null and graveyard.has_method(&"summary_context"):
		context = graveyard.call(&"summary_context")
	context["variant"] = cfg.chapter_id
	context["chapter"] = cfg.chapter_id
	context["days_open"] = maxi(TimeManager.day - open_day(), 0) if open_day() > 0 else 0
	var main := quest_data(cfg.goal_main)
	var end := QuestRules.ending_data(main, ending(cfg.goal_main))
	context["main_ending"] = ending(cfg.goal_main)
	context["main_title"] = end.title if end != null else ""
	context["closing_line"] = end.closing_line if end != null else ""
	var confide := &""
	if main != null:
		for s: QuestStepData in main.steps:
			if s != null and s.complete_on == QuestStepData.ON_CHOICE and choice_of(main.id, s.id) != &"" \
					and QuestRules.choice(s, choice_of(main.id, s.id)) != null and QuestRules.choice(s, choice_of(main.id, s.id)).ending == &"":
				confide = choice_of(main.id, s.id)
	context["confided"] = confide
	context["large_done"] = _large_done.size()
	for stat: StringName in [&"quest_steps", &"quest_choices", &"letters_found", &"letters_decided", &"letters_delivered",
			&"letters_read", &"letters_burned", &"letters_buried", &"letters_answered", &"post_received", &"errands_done",
			&"large_requests_done", &"large_requests_half", &"large_requests_failed", &"large_request_parts", &"stranger_talks",
			&"stranger_coins"]:
		context[String(stat)] = GameState.get_stat(stat)
	var endings := {}
	for q: StringName in _ending:
		endings[String(q)] = String(_ending[q])
	context["endings"] = endings
	return context


## §5.1 {open_day, open, step, done, step_day, choices, ending, settled, notes, pinned, goal_done} + large_done.
func save_state() -> Dictionary:
	var step := {}
	for q: StringName in _step:
		step[String(q)] = String(_step[q])
	var done := {}
	for q: StringName in _done:
		done[String(q)] = (_done[q] as Array).map(func(s: Variant) -> String: return str(s))
	var days := {}
	for q: StringName in _step_day:
		days[String(q)] = _step_day[q]
	var choices_out := {}
	for q: StringName in _choices:
		var c := {}
		for s: Variant in _choices[q]:
			c[str(s)] = str(_choices[q][s])
		choices_out[String(q)] = c
	var ended := {}
	for q: StringName in _ending:
		ended[String(q)] = String(_ending[q])
	var notes_out := {}
	for k: StringName in _notes:
		notes_out[String(k)] = Array(_notes[k])
	return {"open_day": _open_day, "open": _strings(_open), "step": step, "done": done, "step_day": days,
			"choices": choices_out, "ending": ended, "settled": _strings(_settled), "notes": notes_out,
			"pinned": String(_pinned), "goal_done": _goal_done, "large_done": _strings(_large_done)}


## Tolerant: damaged entries are dropped (unknown chains / steps / choices, wrong types).
func load_state(data: Dictionary) -> void:
	_loaded_v8 = not data.is_empty()
	_unlock_seen_total = -1
	_morning_day = TimeManager.day if TimeManager.minute_of_day >= _cfg().intro_minute else TimeManager.day - 1
	_open_day = maxi(_int(data.get("open_day"), 0), 0)
	_open = _known_quests(_names(data.get("open", [])))
	_settled = _known_quests(_names(data.get("settled", [])))
	_large_done = _names(data.get("large_done", []))
	_step.clear()
	_done.clear()
	_step_day.clear()
	_choices.clear()
	_ending.clear()
	_notes.clear()
	var done: Variant = data.get("done", {})
	if done is Dictionary:
		for q: Variant in done:
			var qd := quest_data(StringName(str(q)))
			if qd == null:
				continue
			var list: Array = []
			for s: StringName in _names((done as Dictionary)[q]):
				if QuestRules.step(qd, s) != null and not list.has(s):
					list.append(s)
			_done[qd.id] = list
	var step: Variant = data.get("step", {})
	if step is Dictionary:
		for q: Variant in step:
			var qd := quest_data(StringName(str(q)))
			var s := StringName(str((step as Dictionary)[q]))
			if qd != null and (s == &"" or QuestRules.step(qd, s) != null):
				_step[qd.id] = s
	var days: Variant = data.get("step_day", {})
	if days is Dictionary:
		for q: Variant in days:
			if quest_data(StringName(str(q))) != null:
				_step_day[StringName(str(q))] = maxi(_int((days as Dictionary)[q], 0), 0)
	var choices_raw: Variant = data.get("choices", {})
	if choices_raw is Dictionary:
		for q: Variant in choices_raw:
			var qd := quest_data(StringName(str(q)))
			if qd == null or not (choices_raw as Dictionary)[q] is Dictionary:
				continue
			var c: Dictionary = {}
			var raw: Dictionary = (choices_raw as Dictionary)[q]
			for s: Variant in raw:
				var sd := QuestRules.step(qd, StringName(str(s)))
				var choice_id := StringName(str(raw[s]))
				if sd != null and QuestRules.choice(sd, choice_id) != null:
					c[sd.id] = choice_id
			_choices[qd.id] = c
	var ended: Variant = data.get("ending", {})
	if ended is Dictionary:
		for q: Variant in ended:
			var qd := quest_data(StringName(str(q)))
			var e := StringName(str((ended as Dictionary)[q]))
			if qd != null and e != &"" and (QuestRules.ending_data(qd, e) != null or e == ENDING_DONE):
				_ending[qd.id] = e
	var notes_raw: Variant = data.get("notes", {})
	if notes_raw is Dictionary:
		for k: Variant in notes_raw:
			var list := PackedStringArray()
			var raw: Variant = (notes_raw as Dictionary)[k]
			if raw is Array or raw is PackedStringArray:
				for a: Variant in raw:
					if not list.has(str(a)):
						list.append(str(a))
			_notes[StringName(str(k))] = list
	var pin_raw: Variant = data.get("pinned", "")
	_pinned = StringName(str(pin_raw)) if pin_raw is String or pin_raw is StringName else &""
	var goal: Variant = data.get("goal_done", false)
	_goal_done = goal is bool and bool(goal)
	# A settled chain has an ending; an ended chain has no current step.
	for q: StringName in _settled.duplicate():
		if not _ending.has(q):
			_settled.erase(q)
	for q: StringName in _ending:
		_step[q] = &""
	# An open chain without a saved current step (W1 fixtures, older states): the first step not done.
	for q: StringName in _open:
		if not _step.has(q):
			var nxt := QuestRules.next_step(quest_data(q), steps_done(q))
			_step[q] = nxt.id if nxt != null else &""


# --- internals ------------------------------------------------------------------------------------

## The morning rule: open at the first intro_minute after the unlock flag was first seen.
func _try_open(day: int) -> void:
	var cfg := _cfg()
	if is_open() or not GameState.flag_on(cfg.unlock_flag):
		return
	var now := TimeManager.total_minutes()
	if day > TimeManager.day:
		now = maxi(now, (day - 1) * MINUTES_PER_DAY + cfg.intro_minute)
	if _unlock_seen_total < 0:
		_unlock_seen_total = now
		return
	if now >= _open_at(_unlock_seen_total, cfg.intro_minute):
		open_now(floori(float(now) / MINUTES_PER_DAY) + 1)


## Opens every chain whose open_conditions hold (first step current, checked at once).
func _open_chains() -> void:
	if not is_open():
		return
	for q: QuestData in all_quests():
		if _open.has(q.id):
			continue
		var conditions: Array[String] = []
		for c: String in q.open_conditions:
			conditions.append(c)
		if not DialogueConditions.all_met(conditions, {}):
			continue
		_open.append(q.id)
		var first := QuestRules.next_step(q, steps_done(q.id))
		_step[q.id] = first.id if first != null else &""
		_step_day[q.id] = TimeManager.day
		EventBus.quest_changed.emit(q.id, _step[q.id], CHANGE_OPENED)


## 06:00: a deadline step not chosen yet takes its fallback choice once the day passed (deadline day + 1).
func _deadlines(day: int) -> void:
	for q: QuestData in all_quests():
		if state(q.id) != STATE_OPEN:
			continue
		for s: QuestStepData in q.steps:
			if s == null or s.fallback_choice == &"" or steps_done(q.id).has(s.id) or choice_of(q.id, s.id) != &"":
				continue
			var due := QuestRules.deadline_day(s)
			var c := QuestRules.choice(s, s.fallback_choice)
			if due < 0 or day <= due or c == null:
				continue
			_apply_choice(q, s, c, _context({}))
			break


## The quest orders of every current step are offered (Orders.offer; idempotent).
func _offer_orders() -> void:
	var orders := _first(ORDERS_GROUP)
	if orders == null or not orders.has_method(&"offer"):
		return
	for q: QuestData in all_quests():
		if state(q.id) != STATE_OPEN:
			continue
		var s := QuestRules.step(q, current_step(q.id))
		if s == null:
			continue
		for id: StringName in s.order_ids:
			if orders.has_method(&"state") and StringName(str(orders.call(&"state", id))) == &"":
				orders.call(&"offer", id)


## Records the choice, runs its actions, ends the chain or completes the step.
func _apply_choice(q: QuestData, s: QuestStepData, c: QuestChoiceData, context: Dictionary) -> void:
	var c_map: Dictionary = _choices.get(q.id, {})
	c_map[s.id] = c.id
	_choices[q.id] = c_map
	GameState.add_stat(STAT_CHOICES, 1)
	var actions: Array[String] = []
	for a: String in c.actions:
		actions.append(a)
	DialogueActions.run_all(actions, context)
	EventBus.quest_changed.emit(q.id, s.id, CHANGE_CHOSEN)
	if c.ending != &"":
		_mark_done(q, s)
		_end(q, c.ending, s.id)
	elif current_step(q.id) == s.id:
		_complete_step(q, s)


func _mark_done(q: QuestData, s: QuestStepData) -> void:
	var list: Array = _done.get(q.id, [])
	if list.has(s.id):
		return
	list.append(s.id)
	_done[q.id] = list
	GameState.add_stat(STAT_STEPS, 1)


## The step is done: the next one becomes current (and is checked by _refresh), its orders are offered.
func _complete_step(q: QuestData, s: QuestStepData) -> void:
	_mark_done(q, s)
	EventBus.quest_changed.emit(q.id, s.id, CHANGE_STEP)
	var nxt := QuestRules.next_step(q, steps_done(q.id))
	if nxt == null:
		_step[q.id] = &""
		if not _ending.has(q.id):
			_end(q, q.endings[0].id if q.endings.size() == 1 and q.endings[0] != null else ENDING_DONE, s.id)
		return
	_step[q.id] = nxt.id
	_step_day[q.id] = TimeManager.day
	_offer_orders()


func _end(q: QuestData, ending_id: StringName, step_id: StringName) -> void:
	_ending[q.id] = ending_id
	_step[q.id] = &""
	var e := QuestRules.ending_data(q, ending_id)
	if e != null and e.flag != &"" and not GameState.flag_on(e.flag):
		GameState.set_flag(e.flag, true)
	EventBus.quest_changed.emit(q.id, step_id, CHANGE_ENDED)


## Checks the current steps until nothing changes, settles ended chains, then the chapter.
func _refresh() -> void:
	if _refreshing or not is_open():
		return
	_refreshing = true
	var tree := _tree()
	var guard := 0
	var changed := true
	while changed and guard < 64:
		changed = false
		guard += 1
		for q: QuestData in all_quests():
			if state(q.id) != STATE_OPEN:
				continue
			var s := QuestRules.step(q, current_step(q.id))
			if s == null or s.complete_on == QuestStepData.ON_CHOICE:
				continue
			if QuestRules.step_complete(s, view(q.id, s.id), tree):
				_complete_step(q, s)
				changed = true
	for q: QuestData in all_quests():
		if state(q.id) != STATE_ENDED:
			continue
		var e := QuestRules.ending_data(q, ending(q.id))
		if e == null or e.settle_on == &"" or GameState.flag_on(e.settle_on):
			_settled.append(q.id)
			EventBus.quest_changed.emit(q.id, &"", CHANGE_ENDED)
	_refreshing = false
	check_goal()


func _context(extra: Dictionary) -> Dictionary:
	var context := extra.duplicate()
	if not context.has("inventory"):
		var player := _first(PLAYER_GROUP)
		var inv: Variant = player.get(&"inventory") if player != null else null
		if inv is Inventory:
			context["inventory"] = inv
	return context


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if not is_open() and not GameState.flag_on(_cfg().unlock_flag):
		return
	if minute >= _cfg().intro_minute and day > _morning_day:
		apply_morning(day)
		return
	_try_open(day)
	_refresh()


func _on_event_2(_a: Variant, _b: Variant) -> void:
	if not SaveManager.is_loading:
		_refresh()


func _on_clue(_clue_id: StringName, _corpse_id: String) -> void:
	if not SaveManager.is_loading:
		_refresh()


func _on_insight(_insight_id: StringName) -> void:
	if not SaveManager.is_loading:
		_refresh()


func _on_letter(_uid: String, _letter_id: StringName, _state: StringName) -> void:
	if not SaveManager.is_loading:
		_refresh()


## A large request completed since p9_open counts for the chapter (§1.5 (3)).
func _on_hill(request_id: StringName, hill_state: StringName) -> void:
	if SaveManager.is_loading:
		return
	if hill_state == HILL_COMPLETED and is_open() and not _large_done.has(request_id) and _is_large(request_id):
		_large_done.append(request_id)
	_refresh()


## The Phase-8 chapter: the unlock moment (the opening follows on the next morning).
func _on_chapter(chapter_id: StringName) -> void:
	if SaveManager.is_loading or chapter_id == _cfg().chapter_id:
		return
	if _unlock_seen_total < 0 and not is_open() and GameState.flag_on(_cfg().unlock_flag):
		_unlock_seen_total = TimeManager.total_minutes()


func _is_large(request_id: StringName) -> bool:
	if Database.large_request(request_id) != null:
		return true
	var hill := _first(HILL_GROUP)
	if hill != null and hill.has_method(&"request_data"):
		var r: Variant = hill.call(&"request_data", request_id)
		return r is OrderData and (r as OrderData).size == SIZE_LARGE
	return false


func _known_quests(ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if quest_data(id) != null and not out.has(id):
			out.append(id)
	return out


func _tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	return Engine.get_main_loop() as SceneTree


func _first(group: StringName) -> Node:
	var tree := _tree()
	return tree.get_first_node_in_group(group) if tree != null else null


func _cfg() -> QuestConfig:
	if config == null:
		config = Database.config(&"quest_config") as QuestConfig
		if config == null:
			config = QuestConfig.new()
	return config


static func _open_at(seen_total: int, intro_minute: int) -> int:
	var day_index := floori(float(seen_total - intro_minute) / MINUTES_PER_DAY) + 1
	return day_index * MINUTES_PER_DAY + intro_minute


static func _strings(ids: Array[StringName]) -> Array:
	return ids.map(func(id: StringName) -> String: return String(id))


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback


static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out
