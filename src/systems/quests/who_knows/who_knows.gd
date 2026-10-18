class_name WhoKnows
extends Node
## Systems/WhoKnows (docs/PHASE9_DESIGN.md §2.2, §2.6, §3.1, §3.3, §3.4, §5.1), groups &"who_knows", &"saveable",
## save_id who_knows / 82: the main chain „Wer weiß, wann?" – Lorenz' ledger (H1), the register and the five graves
## (H2), the witnesses (H3 → i_light_before through the journal), Johann Sieber's mark (H4), the nameless letter at
## the Siebers' door (ending A), the deadline (light + 17 → silent, Quests' fallback), Johann's departure with Hanne or
## Osric, the consequences of the endings that depend on the confidant (§2.2.6–§2.2.8), the held-back plot of the
## fourth row.
##
## The chain's steps and choices live in Quests (q_who_knows); WhoKnows reports its events there (Quests.note
## kladde_read / date_grave:<entry>), adds the clues (c_q_dates, c_q_three_weeks, the witnesses' clues, c_q_sieber,
## c_q_hand_answers) and keeps its own state. Clock-driven (time_tick → apply_morning at 06:00, apply_minute): the
## light day q_light_day (p9_open_day − 12, set once), Johann daily from H4 (Visitors.set_kin_interval 1; −1 once he is
## gone or dead), the ending's consequences once (B: the confidant +3, Johann's two evenings offered; C: Lenz, Quast,
## Liesel −4 each except the confidant; A: the departure plan), Johann leaving (sieber_gone after the walk), the note at
## the hut door the morning after, B's kept promise when D3 lies in the fourth row (sieber_buried).
## Saved (§5.1): {light_day, matched, witnessed, marked_seen, letter_posted, depart, fallback_day} + applied,
## registered, hand_note, kept.
## Schedule (W1-Anschlüsse 14): the today_flags of P6's schedules (= the calendar day) – sieber_bench_day (from H4, not
## on the day he leaves), sieber_depart_peddler_day / sieber_depart_carter_day (depart_plan()), sieber_watch_day (ending
## C: every night until the morning after his death, 21:00–06:00). sieber_evening_day is Orders' meet flag of
## oq_johann_evening (conditions.schedule_flag).

const GROUP := &"who_knows"
const WITH_PEDDLER := &"peddler"
const WITH_CARTER := &"carter"
const STEP_CONFIDE := &"h5"
const STEP_DECIDE := &"h6"
const NOTE_KLADDE := &"kladde_read"
const NOTE_GRAVE := &"date_grave"
const ENDING_AWAY := &"away"
const ENDING_STAY := &"stay"
const ENDING_PUBLIC := &"public"
const ENDING_SILENT := &"silent"
const FLAG_KLADDE := &"kladde_read"
const FLAG_GONE := &"sieber_gone"
const FLAG_DEAD := &"sieber_dead"
const FLAG_BURIED := &"sieber_buried"
const FLAG_KEPT := &"kept_promise_sieber"
## P6's village schedule of Johann on the bench (today_flag = the calendar day, from H4 while he lives here).
const FLAG_BENCH_DAY := &"sieber_bench_day"
## P6's schedules of Johann leaving (ending A) and of the watchman's lantern (ending C) – today_flags (the calendar day).
const FLAG_DEPART_DAY := "sieber_depart_%s_day"
const FLAG_WATCH_DAY := &"sieber_watch_day"
## Orders' meet flag of oq_johann_evening (Johann on the bench 18:00–20:00) and the companion's flag of ending B
## (W3 „Restbedarf“ 3): sieber_evening_priest_day (Lenz, first evening) / sieber_evening_washer_day (Liesel, second).
const FLAG_EVENING_DAY := &"sieber_evening_day"
const FLAG_EVENING_WITH := "sieber_evening_%s_day"
## confidant → the evening (0 = the first) on which they sit with him (§2.2.6); Quast does not come (his drops).
const EVENING_COMPANIONS: Dictionary[StringName, int] = {&"priest": 0, &"washer": 1}
## The watch ends with the morning after his death (the lantern 21:00–06:00, data/npc/watchman_schedule.tres).
const WATCH_END_MINUTE := 360
const CLUE_DATES := &"c_q_dates"
const CLUE_WEEKS := &"c_q_three_weeks"
const CLUE_HAND := &"c_q_hand_answers"
const LEDGER_ITEM := &"lorenz_ledger_2"
const NAMELESS_ITEM := &"nameless_letter"
const EVENING_ORDER := &"oq_johann_evening"
const D3_STORY := &"d3_sieber"
const KIND_MATCHED := &"matched"
const KIND_WITNESSED := &"witnessed"
const KIND_MARKED := &"marked"
const KIND_DEPARTED := &"departed"
## The confidants of H5 (choice → npc) – C spares the confidant, B gives them +3.
const CONFIDANTS: Dictionary[StringName, StringName] = {&"confide_priest": &"priest", &"confide_surgeon": &"surgeon",
		&"confide_washer": &"washer"}
const GAIN_WITNESS := &"witness"
const GAIN_NAMED := &"named_publicly"
const PIETY_KEPT := &"kept_promise"
const REP_KEPT := &"kept_promise"
## Johann walks with Hanne up the forest path / sits on Osric's cart WhoKnowsConfig.gone_after_minutes before he is
## gone (sieber_gone hides his figures – the walk itself is P6's schedule); the confidant's +3 of ending B is
## WhoKnowsConfig.b_confidant_rel, the chain WhoKnowsConfig.quest_id (W1-Anschlüsse 16).
## The deadline (light + 17) is the last day Hanne may take him on: her day ≤ light + 18 (§2.2.7).
const PEDDLER_LAST_OFFSET := 1
const MINUTES_PER_DAY := 1440
const TEXT_NOT_OPEN := "Noch nicht."
const TEXT_NO_LEDGER := "Lorenz' Kladde ist nicht hier. Sie liegt nicht in der Truhe und nicht in der Tasche."
const TEXT_READ_FIRST := "Erst die Kladde lesen."
const TEXT_REGISTER_DONE := "Das Register ist schon verglichen."
const TEXT_NO_INK := "Dafür fehlt Tinte."
const TEXT_NO_NEED := "Dafür gibt es keinen Grund."
const TEXT_HAS_LETTER := "Der Brief ist schon geschrieben."
const TEXT_HAND_NOTE := "An der Hüttentür steckt ein Zettel."
const TEXT_LETTER_POSTED := "Der Brief steckt in der Tür der Siebers."
const REASON_WITNESS := "Das Licht"
const REASON_CONFIDED := "Ende: %s"
const LIST_PATH := "res://data/quests/who_knows/list.tres"

@export var save_id: String = "who_knows"
@export var save_order: int = 82

## Rules; null = data/config/who_knows_config.tres (resolved lazily).
var config: WhoKnowsConfig
## Tests: the list (null = data/quests/who_knows/list.tres).
var list_data: LightListData

var _light_day: int = 0
var _matched: Array[StringName] = []
var _witnessed: Array[StringName] = []
var _marked_seen: bool = false
var _letter_posted: bool = false
var _depart: Dictionary = {}
var _fallback_day: int = 0
var _applied: StringName = &""
var _registered: bool = false
var _hand_note: bool = false
var _kept: bool = false
var _morning_day: int = -1


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)


# --- the list -------------------------------------------------------------------------------------

func light_list() -> LightListData:
	if list_data == null:
		list_data = load(LIST_PATH) as LightListData
	return list_data


func entry(entry_id: StringName) -> LightEntryData:
	var list := light_list()
	if list == null:
		return null
	for e: LightEntryData in list.entries:
		if e != null and e.id == entry_id:
			return e
	return null


## The entries with a dead on the hill (H2 – all but the open one).
func dead_entries() -> Array[LightEntryData]:
	var out: Array[LightEntryData] = []
	var list := light_list()
	if list != null:
		for e: LightEntryData in list.entries:
			if e != null and not e.open and e.story_id != &"":
				out.append(e)
	return out


## The entry whose dead lies in `grave_id` (&"" = none).
func entry_for_grave(grave_id: String) -> StringName:
	if grave_id == "":
		return &""
	for e: LightEntryData in dead_entries():
		if LightRules.grave_of(e, get_tree() if is_inside_tree() else null) == grave_id:
			return e.id
	return &""


## The day of the open light (q_light_day; 0 = Phase 9 not open).
func light_day() -> int:
	var d := LightRules.flag_day(_cfg().light_flag)
	return d if d != LightRules.NO_DAY else _light_day


# --- H1: the ledger -------------------------------------------------------------------------------

## H1 (Desk): why the ledger cannot be read now ("" = it can; TimedAction kladde_minutes afterwards).
func read_block_reason(inv: Inventory) -> String:
	if not _open():
		return TEXT_NOT_OPEN
	if not _ledger_here(inv):
		return TEXT_NO_LEDGER
	return ""


## After the TimedAction: flag + note kladde_read (H1), clue c_q_dates; the list opens in the journal.
func read_kladde() -> void:
	if not _open():
		return
	_ensure_light_day()
	GameState.set_flag(FLAG_KLADDE, true)
	_add_clue(CLUE_DATES)
	_quests_note(NOTE_KLADDE, "")


# --- H2: the register and the graves --------------------------------------------------------------

## Why the register cannot be compared now ("" = it can; TimedAction register_minutes afterwards).
func register_block_reason() -> String:
	if not _open():
		return TEXT_NOT_OPEN
	if not GameState.flag_on(FLAG_KLADDE):
		return TEXT_READ_FIRST
	if _registered:
		return TEXT_REGISTER_DONE
	return ""


## H2 (a): every entry with a dead gets its name (matched); a dead not on the hill counts through Lenz' death register
## (date_grave noted at once). Returns the matched entry ids (once; later calls return them again without changes).
func compare_register() -> PackedStringArray:
	var out := PackedStringArray()
	if not _open() or not GameState.flag_on(FLAG_KLADDE):
		return out
	var tree := get_tree() if is_inside_tree() else null
	_registered = true
	for e: LightEntryData in dead_entries():
		_match(e.id)
		out.append(String(e.id))
		if LightRules.grave_of(e, tree) == "":
			_quests_note(NOTE_GRAVE, String(e.id))
	_check_weeks()
	return out


## H2 (b): the grave holds a dead of the list whose date is not compared yet (after the ledger, before H2 is done).
func can_compare(grave_id: String) -> bool:
	if not _open() or not GameState.flag_on(FLAG_KLADDE):
		return false
	var id := entry_for_grave(grave_id)
	return id != &"" and not _compared(id)


## After the TimedAction at the grave (grave_minutes): note date_grave:<entry>, matched; c_q_three_weeks with all five.
func compare_grave(grave_id: String) -> bool:
	if not can_compare(grave_id):
		return false
	var id := entry_for_grave(grave_id)
	_match(id)
	_quests_note(NOTE_GRAVE, String(id))
	_check_weeks()
	return true


func matched(entry_id: StringName) -> bool:
	return _matched.has(entry_id)


# --- H3: the witnesses ----------------------------------------------------------------------------

## Dialogue action witness:<entry>: the witness told of the light – their clue (the journal unlocks i_light_before with
## 3 of 5), relationship +2 (gains.witness). Once per entry; false when unknown / already told / Phase 9 closed.
func witness(entry_id: StringName) -> bool:
	var e := entry(entry_id)
	if e == null or not _open() or _witnessed.has(entry_id):
		return false
	_witnessed.append(entry_id)
	if e.witness_clue != &"":
		_add_clue(e.witness_clue)
	if e.witness_npc != &"":
		_rel_add(e.witness_npc, int(_rel_cfg().gains.get(GAIN_WITNESS, 2)), REASON_WITNESS)
	EventBus.light_entry_changed.emit(entry_id, KIND_WITNESSED)
	return true


func witnessed() -> Array[StringName]:
	return _witnessed.duplicate()


# --- H4: Johann's mark ----------------------------------------------------------------------------

## H4 (Johann shows it): flag q_sieber_marked (the step), the open entry's clue c_q_sieber, Johann's household
## goodwill +1. Once.
func mark_seen() -> void:
	if _marked_seen or not _open():
		return
	_marked_seen = true
	var cfg := _cfg()
	GameState.set_flag(cfg.marked_flag, true)
	for e: LightEntryData in (light_list().entries if light_list() != null else []):
		if e != null and e.open and e.witness_clue != &"":
			_add_clue(e.witness_clue)
			EventBus.light_entry_changed.emit(e.id, KIND_MARKED)
	_goodwill(cfg.kin_id, 1)


func marked_seen() -> bool:
	return _marked_seen


# --- ending A: the nameless letter ----------------------------------------------------------------

## Why the nameless letter cannot be written at the Desk ("" = it can; TimedAction letter_minutes, 1 ink).
func write_block_reason(inv: Inventory) -> String:
	if not _open() or not _chain_deciding():
		return TEXT_NO_NEED
	if _letter_posted or (inv != null and inv.has(NAMELESS_ITEM)):
		return TEXT_HAS_LETTER
	if inv == null or not inv.has(_cfg().letter_item):
		return TEXT_NO_INK
	return ""


## After the TimedAction: 1 ink → the nameless letter.
func write_letter(inv: Inventory) -> bool:
	if write_block_reason(inv) != "":
		return false
	if not inv.remove_item(_cfg().letter_item, 1):
		return false
	if inv.add_item(NAMELESS_ITEM, 1) > 0:
		inv.add_item(_cfg().letter_item, 1)
		return false
	return true


func letter_posted() -> bool:
	return _letter_posted


## Ending A: the nameless letter at the Siebers' door (KnockDoor, at night) – the condition letter_posted of H6 „away".
func post_letter(inv: Inventory) -> bool:
	if _letter_posted or not _open() or not _chain_deciding() or inv == null or not inv.has(NAMELESS_ITEM):
		return false
	if not TimeManager.is_night():
		return false
	if not inv.remove_item(NAMELESS_ITEM, 1):
		return false
	_letter_posted = true
	EventBus.notification_requested.emit(TEXT_LETTER_POSTED, &"info")
	return true


# --- the clock ------------------------------------------------------------------------------------

## 06:00: the light day; the deadline (→ Quests' fallback silent); Johann daily from H4 and on the bench; the ending's
## consequences; the note at the hut door the morning after he left; B's kept promise.
func apply_morning(day: int) -> void:
	if not _open():
		return
	_ensure_light_day()
	_morning_day = maxi(_morning_day, day)
	var quests := _quests()
	var cfg := _cfg()
	if quests != null and quests.ending(_main()) == &"" and day > LightRules.decide_day(light_day(), cfg):
		quests.apply_morning(day)
		if quests.ending(_main()) != &"":
			_fallback_day = day
	_daily_visits(day)
	_apply_consequences()
	if GameState.flag_on(FLAG_GONE) and not _hand_note and not _depart.is_empty() and day > int(_depart.get("day", day)):
		_hand_note = true
		_add_clue(CLUE_HAND)
		EventBus.notification_requested.emit(TEXT_HAND_NOTE, &"info")
	_check_kept()


## Every minute: the ending's consequences (a choice in a dialogue), Johann leaving (ending A), B's kept promise.
func apply_minute(day: int, minute: int) -> void:
	if not _open():
		return
	_apply_consequences()
	if not _depart.is_empty() and not GameState.flag_on(FLAG_GONE):
		var now := (day - 1) * MINUTES_PER_DAY + minute
		var at := (int(_depart.get("day", 0)) - 1) * MINUTES_PER_DAY + int(_depart.get("minute", 0))
		if now >= at + _cfg().gone_after_minutes:
			_leave()
	_check_kept()
	_schedule_flags(day, minute)


## {day, minute, with: &"peddler" | &"carter"} | {}
func depart_plan() -> Dictionary:
	return _depart.duplicate()


## §2.6: plots of the fourth row the delivery keeps free for D3 – 1 from p9_open until the main chain has an ending
## (then the Phase-4 rule of the pending D3 takes over for B / C / silent; A frees it). CorpseManager (P3) adds it.
func reserved_plot_count() -> int:
	if not _open() or GameState.flag_on(FLAG_GONE):
		return 0
	var quests := _quests()
	if quests != null and quests.ending(_main()) != &"":
		return 0
	return 1


## §5.1 {light_day, matched, witnessed, marked_seen, letter_posted, depart, fallback_day} + applied, registered,
## hand_note, kept.
func save_state() -> Dictionary:
	return {"light_day": _light_day, "matched": _strings(_matched), "witnessed": _strings(_witnessed), "marked_seen": _marked_seen,
			"letter_posted": _letter_posted, "depart": _depart.duplicate(), "fallback_day": _fallback_day, "applied": String(_applied),
			"registered": _registered, "hand_note": _hand_note, "kept": _kept}


## Tolerant: unknown entries and damaged values are dropped (a light day in the future stays – it is a day).
func load_state(data: Dictionary) -> void:
	_light_day = maxi(_int(data.get("light_day"), 0), 0)
	_matched = _known_entries(_names(data.get("matched", [])))
	_witnessed = _known_entries(_names(data.get("witnessed", [])))
	_marked_seen = _bool(data.get("marked_seen"))
	_letter_posted = _bool(data.get("letter_posted"))
	_fallback_day = maxi(_int(data.get("fallback_day"), 0), 0)
	var applied: Variant = data.get("applied", "")
	_applied = StringName(str(applied)) if applied is String or applied is StringName else &""
	_registered = _bool(data.get("registered"))
	_hand_note = _bool(data.get("hand_note"))
	_kept = _bool(data.get("kept"))
	_depart = {}
	var depart: Variant = data.get("depart", {})
	if depart is Dictionary and not (depart as Dictionary).is_empty():
		var d: Dictionary = depart
		var with := StringName(str(d.get("with", "")))
		var day := _int(d.get("day"), -1)
		var minute := _int(d.get("minute"), -1)
		if (with == WITH_PEDDLER or with == WITH_CARTER) and day > 0 and minute >= 0 and minute < MINUTES_PER_DAY:
			_depart = {"day": day, "minute": minute, "with": with}
	_morning_day = TimeManager.day if TimeManager.minute_of_day >= 360 else TimeManager.day - 1


# --- internals ------------------------------------------------------------------------------------

func _open() -> bool:
	return GameState.flag_on(&"p9_open")


## q_light_day = p9_open_day − 12, once (the list's dates and the whole chain count from it).
func _ensure_light_day() -> void:
	var cfg := _cfg()
	var d := LightRules.flag_day(cfg.light_flag)
	if d != LightRules.NO_DAY:
		_light_day = d
		return
	var light := LightRules.open_light_day(LightRules.flag_day(&"p9_open_day"), cfg)
	if light == LightRules.NO_DAY:
		return
	_light_day = light
	GameState.set_flag(cfg.light_flag, light)


## H5 or H6 current (the letter is for ending A).
func _chain_deciding() -> bool:
	var quests := _quests()
	if quests == null:
		return false
	var step := quests.current_step(_main())
	return quests.ending(_main()) == &"" and (step == STEP_CONFIDE or step == STEP_DECIDE)


func _ledger_here(inv: Inventory) -> bool:
	if inv != null and inv.has(LEDGER_ITEM):
		return true
	if not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group(&"saveable"):
		var storage: Variant = node.get(&"storage")
		if storage is Inventory and (storage as Inventory).has(LEDGER_ITEM):
			return true
	return false


func _compared(entry_id: StringName) -> bool:
	var quests := _quests()
	return quests != null and quests.notes(NOTE_GRAVE).has(String(entry_id))


func _match(entry_id: StringName) -> void:
	if _matched.has(entry_id):
		return
	_matched.append(entry_id)
	EventBus.light_entry_changed.emit(entry_id, KIND_MATCHED)


## All dead entries compared (grave or death register) → c_q_three_weeks.
func _check_weeks() -> void:
	for e: LightEntryData in dead_entries():
		if not _compared(e.id):
			return
	_add_clue(CLUE_WEEKS)


## From H4 Johann comes daily and sits on the bench; gone or dead → no more visits.
func _daily_visits(day: int) -> void:
	var cfg := _cfg()
	var visitors := _first(&"visitors")
	if GameState.flag_on(FLAG_GONE) or GameState.flag_on(FLAG_DEAD):
		if visitors != null and visitors.has_method(&"set_kin_interval"):
			visitors.call(&"set_kin_interval", cfg.kin_id, -1)
		return
	var quests := _quests()
	if quests == null:
		return
	var q := quests.quest_data(_main())
	var reached := false
	for s: QuestStepData in (q.steps if q != null else []):
		if s == null:
			continue
		if s.id == cfg.daily_visit_from_step:
			reached = quests.current_step(_main()) == s.id or quests.steps_done(_main()).has(s.id) \
					or quests.ending(_main()) != &""
			break
	if not reached:
		return
	if visitors != null and visitors.has_method(&"set_kin_interval"):
		visitors.call(&"set_kin_interval", cfg.kin_id, -1 if _leaves_with_carter() else 1)
	if not _departs_on(day):
		GameState.set_flag(FLAG_BENCH_DAY, day)


## Ending A with Osric: he sits on the cart at 10:00 – no more visit at Grete's grave (10:00–11:00, W1-Anschlüsse 18).
func _leaves_with_carter() -> bool:
	return not _depart.is_empty() and StringName(str(_depart.get("with", ""))) == WITH_CARTER


## Ending A: Johann leaves on `day` (his bench schedule would cross the walk).
func _departs_on(day: int) -> bool:
	return not _depart.is_empty() and int(_depart.get("day", -1)) == day


## The today_flags of the schedules (idempotent): the departure day of the plan, no bench on that day, the
## watchman's nights of ending C (until WATCH_END_MINUTE of the morning after the death).
func _schedule_flags(day: int, minute: int) -> void:
	if not _depart.is_empty():
		var flag := StringName(FLAG_DEPART_DAY % String(_depart.get("with", "")))
		var d := int(_depart.get("day", -1))
		var value: Variant = GameState.get_flag(flag, null)
		if not ((value is int or value is float) and int(value) == d):
			GameState.set_flag(flag, d)
		if _departs_on(day) and ScheduleResolver.is_today(FLAG_BENCH_DAY, day):
			GameState.clear_flag(FLAG_BENCH_DAY)
	var quests := _quests()
	if quests != null and quests.ending(_main()) == ENDING_STAY:
		_evening_companion(quests, day)
	if quests == null or quests.ending(_main()) != ENDING_PUBLIC:
		return
	var watching := ScheduleResolver.is_today(FLAG_WATCH_DAY, day)
	if not GameState.flag_on(FLAG_DEAD):
		if not watching:
			GameState.set_flag(FLAG_WATCH_DAY, day)
	elif watching and minute >= WATCH_END_MINUTE:
		GameState.clear_flag(FLAG_WATCH_DAY)


## W3 („Restbedarf“ 3, §2.2.6 / §2.2.7 Ende B): the confidant of H5 sits with Johann on the bench – Lenz on the first
## evening, Liesel on the second (EVENING_COMPANIONS: the evening = Orders.meetings_before of oq_johann_evening, stable
## through the day); P6's schedules key it with FLAG_EVENING_WITH (the calendar day, idempotent). Quast leaves his drops.
func _evening_companion(quests: Quests, day: int) -> void:
	var confidant: StringName = CONFIDANTS.get(quests.choice_of(_main(), STEP_CONFIDE), &"")
	if not EVENING_COMPANIONS.has(confidant) or not ScheduleResolver.is_today(FLAG_EVENING_DAY, day):
		return
	var flag := StringName(FLAG_EVENING_WITH % String(confidant))
	if ScheduleResolver.is_today(flag, day):
		return
	var orders := _first(&"orders")
	if orders == null or not orders.has_method(&"meetings_before") \
			or StringName(orders.call(&"state", EVENING_ORDER)) != &"accepted":
		return
	if int(orders.call(&"meetings_before", EVENING_ORDER, day)) == int(EVENING_COMPANIONS[confidant]):
		GameState.set_flag(flag, day)


## The ending's consequences beyond the choice's own actions (§2.2.6–§2.2.8), once.
func _apply_consequences() -> void:
	var quests := _quests()
	if quests == null:
		return
	var end := quests.ending(_main())
	if end == &"" or _applied != &"":
		return
	_applied = end
	var confidant: StringName = CONFIDANTS.get(quests.choice_of(_main(), STEP_CONFIDE), &"")
	var reason := REASON_CONFIDED % end
	match end:
		ENDING_AWAY:
			_plan_departure()
		ENDING_STAY:
			if confidant != &"":
				_rel_add(confidant, _cfg().b_confidant_rel, reason)
			var orders := _first(&"orders")
			if orders != null and orders.has_method(&"offer"):
				orders.call(&"offer", EVENING_ORDER)
		ENDING_PUBLIC:
			var named := int(_rel_cfg().gains.get(GAIN_NAMED, -4))
			for npc: StringName in CONFIDANTS.values():
				if npc != confidant:
					_rel_add(npc, named, reason)


## Ending A: with Hanne on her next day if it lies between the choice and light + 18 and she has not left the gate yet
## (16:20), else the next morning with Osric (10:00).
func _plan_departure() -> void:
	if not _depart.is_empty():
		return
	var cfg := _cfg()
	var today := TimeManager.day
	var last := LightRules.decide_day(light_day(), cfg) + PEDDLER_LAST_OFFSET
	var hanne := -1
	var wanderers := _first(&"wanderers")
	if wanderers != null and wanderers.has_method(&"next_peddler_day"):
		hanne = int(wanderers.call(&"next_peddler_day", today))
		if hanne == today and TimeManager.minute_of_day >= cfg.depart_with_peddler_minute:
			hanne = int(wanderers.call(&"next_peddler_day", today + 1))
	if hanne > 0 and hanne <= last:
		_depart = {"day": hanne, "minute": cfg.depart_with_peddler_minute, "with": WITH_PEDDLER}
	else:
		_depart = {"day": today + 1, "minute": cfg.depart_with_carter_minute, "with": WITH_CARTER}
		var visitors := _first(&"visitors")
		if visitors != null and visitors.has_method(&"set_kin_interval"):
			visitors.call(&"set_kin_interval", cfg.kin_id, -1)  # tomorrow's plan (06:00): on the cart, not at the grave


## He is gone: sieber_gone (his figures hidden, np_sieber cancelled, ending A settled), no more visits.
func _leave() -> void:
	GameState.set_flag(FLAG_GONE, true)
	var visitors := _first(&"visitors")
	if visitors != null and visitors.has_method(&"set_kin_interval"):
		visitors.call(&"set_kin_interval", _cfg().kin_id, -1)
	for e: LightEntryData in (light_list().entries if light_list() != null else []):
		if e != null and e.open:
			EventBus.light_entry_changed.emit(e.id, KIND_DEPARTED)


## B: the promise kept – D3 buried (sieber_buried) in the fourth row → piety / reputation kept_promise, flag.
func _check_kept() -> void:
	if _kept or not GameState.flag_on(FLAG_BURIED):
		return
	var quests := _quests()
	if quests == null or quests.ending(_main()) != ENDING_STAY:
		return
	_kept = true
	var tree := get_tree() if is_inside_tree() else null
	var r := LightRules.record_of(D3_STORY, tree)
	var graveyard := _first(&"graveyard")
	var section := StringName(str(graveyard.call(&"section_of", r.grave_id))) if r != null and graveyard != null \
			and graveyard.has_method(&"section_of") else &""
	if section != _cfg().reserve_section:
		return
	GameState.set_flag(FLAG_KEPT, true)
	var piety := _first(&"piety")
	if piety != null and piety.has_method(&"event"):
		piety.call(&"event", PIETY_KEPT, REASON_CONFIDED % ENDING_STAY)
	var rep := _first(&"reputation")
	if rep != null and rep.has_method(&"event"):
		rep.call(&"event", REP_KEPT, REASON_CONFIDED % ENDING_STAY)


func _on_time_tick(day: int, minute: int) -> void:
	if SaveManager.is_loading:
		return
	if minute >= 360 and day > _morning_day:
		apply_morning(day)
	apply_minute(day, minute)


## The chain (WhoKnowsConfig.quest_id).
func _main() -> StringName:
	return _cfg().quest_id


func _quests() -> Quests:
	return _first(&"quests") as Quests


func _quests_note(key: StringName, arg: String) -> void:
	var quests := _quests()
	if quests != null:
		quests.note(key, arg)


func _add_clue(clue: StringName) -> void:
	var journal := _first(&"journal")
	if journal != null and journal.has_method(&"add_clue"):
		journal.call(&"add_clue", clue, "", false)
	else:
		GameState.set_flag(StringName(JournalManager.CLUE_FLAG_PREFIX + String(clue)), true)


func _rel_add(npc: StringName, delta: int, reason: String) -> void:
	var rel := _first(&"relationships")
	if rel != null and rel.has_method(&"add"):
		rel.call(&"add", npc, delta, reason)


func _goodwill(kin: StringName, delta: int) -> void:
	var visitors := _first(&"visitors")
	if visitors != null and visitors.has_method(&"add_goodwill"):
		visitors.call(&"add_goodwill", kin, delta)


func _first(group: StringName) -> Node:
	if is_inside_tree():
		return get_tree().get_first_node_in_group(group)
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group(group) if tree != null else null


func _known_entries(ids: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids:
		if entry(id) != null and not out.has(id):
			out.append(id)
	return out


func _cfg() -> WhoKnowsConfig:
	if config == null:
		config = Database.config(&"who_knows_config") as WhoKnowsConfig
		if config == null:
			config = WhoKnowsConfig.new()
	return config


func _rel_cfg() -> RelationshipConfig:
	var c := Database.config(&"relationship_config") as RelationshipConfig
	return c if c != null else RelationshipConfig.new()


static func _strings(ids: Array[StringName]) -> Array:
	return ids.map(func(id: StringName) -> String: return String(id))


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback


static func _bool(value: Variant) -> bool:
	return value is bool and bool(value)


static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array or raw is PackedStringArray:
		for v: Variant in raw:
			out.append(StringName(str(v)))
	return out
