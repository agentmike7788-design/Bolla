extends TestCase
## P1 (docs/PHASE9_DESIGN.md §1.2, §1.5, §2.1, §3.3, §3.4, §5.1, §10): Quests – the opening p9_open on the first morning
## after the Phase-8 chapter (idempotent) and at once after loading a v7 state; strict step order with every
## complete_on kind (events before a step is visible count); a choice once, its actions run; deadline → fallback_choice
## (also while an earlier step is current); an ending settled by settle_on; the chapter (all three conditions, exactly
## once); pinning (max 1); the step's quest orders offered; save / load (tolerant, round trip). Fixture chains, doubles
## for the journal, relationships, letters and the hill requests.

const OPEN := 63


class JournalDouble extends Node:
	var clues: Array = []
	var insights: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_clue(id: StringName) -> bool:
		return clues.has(id)

	func has_insight(id: StringName) -> bool:
		return insights.has(id)

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		return true


class RelDouble extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"relationships")

	func add(npc_id: StringName, delta: int, reason: String) -> int:
		calls.append([npc_id, delta, reason])
		return delta


class LettersDouble extends Node:
	var decided: int = 0

	func _init() -> void:
		add_to_group(&"letters")

	func decided_count() -> int:
		return decided


class HillDouble extends Node:
	func _init() -> void:
		add_to_group(&"hill_requests")

	func request_data(id: StringName) -> OrderData:
		var o := OrderData.new()
		o.id = id
		o.size = OrderData.SIZE_LARGE if String(id).begins_with("hrl_") else &""
		return o


var quests: Quests
var journal: JournalDouble
var rel: RelDouble
var letters: LettersDouble
var hill: HillDouble
var changes: Array = []
var chapters: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": OPEN, "minute_of_day": 420})
	quests = _new_quests()
	journal = JournalDouble.new()
	rel = RelDouble.new()
	letters = LettersDouble.new()
	hill = HillDouble.new()
	for n: Node in [quests, journal, rel, letters, hill]:
		tree.root.add_child(n)
	changes.clear()
	chapters.clear()
	EventBus.quest_changed.connect(_on_quest)
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.quest_changed.disconnect(_on_quest)
	EventBus.chapter_completed.disconnect(_on_chapter)
	for n: Node in [quests, journal, rel, letters, hill]:
		if is_instance_valid(n):
			n.free()
	GameState.reset()


func _new_quests() -> Quests:
	var q := Quests.new()
	q.config = Phase9Fixtures.quest_config()
	for d: QuestData in Phase9Fixtures.quests():
		q.quest_table[d.id] = d
	return q


func _on_quest(quest_id: StringName, step_id: StringName, state: StringName) -> void:
	changes.append([quest_id, step_id, state])


func _on_chapter(chapter_id: StringName) -> void:
	chapters.append(chapter_id)


## Phase 9 open on OPEN (flags as Phase9Fixtures.p9_open), chains opened.
func _open() -> void:
	GameState.set_flag(&"who_comes_up_complete", true)
	GameState.set_flag(&"q_light_day", OPEN - 12)
	quests.open_now(OPEN)


## q_who_knows at `step` (the steps before done) – a loaded state.
func _main_at(step: StringName) -> void:
	_open()
	var done: Array = []
	for s: StringName in Phase9Fixtures.MAIN_STEPS:
		if s == step:
			break
		done.append(String(s))
	quests.load_state({"open_day": OPEN, "open": ["q_who_knows", "q_letters", "q_case"], "step": {"q_who_knows": String(step)},
			"done": {"q_who_knows": done}})


# --- opening --------------------------------------------------------------------------------------

func test_opens_on_the_first_morning_after_the_chapter() -> void:
	TimeManager.load_state({"day": 62, "minute_of_day": 840})
	quests.apply_morning(62)
	assert_false(quests.is_open(), "no chapter yet")
	GameState.set_flag(&"who_comes_up_complete", true)
	EventBus.chapter_completed.emit(&"who_comes_up")
	quests.apply_morning(62)
	assert_false(quests.is_open(), "the chapter's day: not yet")
	assert_eq(quests.state(&"q_who_knows"), &"", "no chains before p9_open")
	TimeManager.load_state({"day": 63, "minute_of_day": 359})
	quests.apply_morning(63)
	assert_false(quests.is_open(), "05:59")
	TimeManager.load_state({"day": 63, "minute_of_day": 360})
	quests.apply_morning(63)
	assert_true(quests.is_open(), "06:00 of the next morning")
	assert_eq([quests.open_day(), int(GameState.get_flag(&"p9_open_day"))], [63, 63])
	assert_eq([quests.state(&"q_who_knows"), quests.current_step(&"q_who_knows")], [&"open", &"h1"])
	assert_eq([quests.state(&"q_letters"), quests.state(&"q_case")], [&"open", &"open"], "open_conditions flag:p9_open")
	var opened := changes.filter(func(c: Array) -> bool: return c[2] == &"opened")
	assert_eq(opened.size(), 3)
	assert_eq(opened[0], [&"q_who_knows", &"h1", &"opened"])
	quests.apply_morning(63)
	TimeManager.load_state({"day": 64, "minute_of_day": 360})
	quests.apply_morning(64)
	assert_eq([quests.open_day(), changes.filter(func(c: Array) -> bool: return c[2] == &"opened").size()], [63, 3], "idempotent")


func test_ticks_open_at_six_with_the_seen_chapter() -> void:
	TimeManager.load_state({"day": 62, "minute_of_day": 1300})
	GameState.set_flag(&"who_comes_up_complete", true)
	EventBus.chapter_completed.emit(&"who_comes_up")
	TimeManager.advance(60 * 7)
	assert_false(quests.is_open(), "the night after the chapter")
	TimeManager.advance(60 * 2)
	assert_true(quests.is_open(), "06:00 tick")
	assert_eq(quests.open_day(), 63)


func test_post_load_opens_a_v7_state_at_once() -> void:
	GameState.set_flag(&"who_comes_up_complete", true)
	TimeManager.load_state({"day": 63, "minute_of_day": 420})
	quests.load_state({})
	quests.post_load()
	assert_true(quests.is_open(), "§1.2: migrated v7 (empty node) with the chapter → p9_open at 07:00")
	assert_eq([quests.open_day(), quests.current_step(&"q_who_knows")], [63, &"h1"])
	# A v8 state keeps the morning rule.
	GameState.reset()
	GameState.set_flag(&"who_comes_up_complete", true)
	var q := _new_quests()
	tree.root.add_child(q)
	q.load_state({"open_day": 0, "open": [], "goal_done": false})
	q.post_load()
	assert_false(q.is_open(), "v8 before p9_open: the morning rule")
	q.free()
	# Without the chapter nothing opens.
	GameState.reset()
	var q2 := _new_quests()
	tree.root.add_child(q2)
	q2.load_state({})
	q2.post_load()
	assert_false(q2.is_open(), "slot_p8_mid: Phase 9 stays closed")
	q2.free()


# --- steps ----------------------------------------------------------------------------------------

func test_steps_in_order_with_notes() -> void:
	_open()
	var steps_before := GameState.get_stat(&"quest_steps")
	quests.note(&"date_grave", "e_ott")
	assert_eq(quests.current_step(&"q_who_knows"), &"h1", "H2's notes before H1 do not skip H1")
	quests.note(&"kladde_read", "")
	assert_eq([quests.current_step(&"q_who_knows"), quests.steps_done(&"q_who_knows")], [&"h2", [&"h1"] as Array[StringName]])
	assert_has(changes, [&"q_who_knows", &"h1", &"step"])
	assert_eq(quests.progress(&"q_who_knows"), Vector2i(1, 5), "the note before counts: 1/5")
	quests.note(&"date_grave", "e_ott")
	assert_eq(quests.notes(&"date_grave"), PackedStringArray(["e_ott"]), "once per argument")
	for e: String in ["e_dorn", "e_quendel", "e_wernstein"]:
		quests.note(&"date_grave", e)
	assert_eq(quests.current_step(&"q_who_knows"), &"h2", "4 of 5")
	quests.note(&"date_grave", "e_hagedorn")
	assert_eq(quests.current_step(&"q_who_knows"), &"h3")
	assert_eq(GameState.get_stat(&"quest_steps") - steps_before, 2, "stats.quest_steps")


func test_events_before_the_step_count_when_it_becomes_visible() -> void:
	_open()
	journal.insights.append(&"i_light_before")
	GameState.set_flag(&"q_sieber_marked", true)
	for e: String in ["e_dorn", "e_quendel", "e_wernstein", "e_ott", "e_hagedorn"]:
		quests.note(&"date_grave", e)
	assert_eq(quests.current_step(&"q_who_knows"), &"h1")
	quests.note(&"kladde_read", "")
	assert_eq(quests.current_step(&"q_who_knows"), &"h5", "H2 (notes), H3 (insight), H4 (flag) done at once")
	assert_eq(quests.steps_done(&"q_who_knows"), [&"h1", &"h2", &"h3", &"h4"] as Array[StringName])


func test_flag_clue_and_insight_steps_by_events() -> void:
	_main_at(&"h3")
	journal.insights.append(&"i_light_before")
	EventBus.insight_unlocked.emit(&"i_light_before")
	assert_eq(quests.current_step(&"q_who_knows"), &"h4", "insight_unlocked")
	GameState.set_flag(&"q_sieber_marked", true)
	TimeManager.advance(1)
	assert_eq(quests.current_step(&"q_who_knows"), &"h5", "a flag: the next minute")
	quests.load_state({"open_day": OPEN, "open": ["q_case"], "step": {"q_case": "k3"}, "done": {"q_case": ["k1", "k2"]}})
	journal.clues.append(&"c_q_case_lorenz")
	EventBus.clue_found.emit(&"c_q_case_lorenz", "")
	assert_eq(quests.current_step(&"q_case"), &"k4", "clue_found")


func test_order_step_offers_its_order_and_completes_with_it() -> void:
	var orders := Orders.new()
	orders.config = Phase9Fixtures.orders_config()
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		orders.order_table[id] = Phase9Fixtures.order(id)
	tree.root.add_child(orders)
	_open()
	quests.load_state({"open_day": OPEN, "open": ["q_letters"], "step": {"q_letters": "l2"}, "done": {"q_letters": ["l1"]}})
	quests.note(&"post_decided", "lt_0002")
	assert_eq(quests.current_step(&"q_letters"), &"l3")
	assert_eq(orders.state(&"oq_gesa_brother"), &"offered", "L3 offers E1 (order_ids)")
	assert_true(orders.accept(&"oq_gesa_brother"))
	assert_eq(quests.current_step(&"q_letters"), &"l3")
	orders.complete(&"oq_gesa_brother")
	assert_eq(quests.current_step(&"q_letters"), &"l4", "order_changed completed")
	orders.free()


# --- choices --------------------------------------------------------------------------------------

func test_choice_once_with_its_actions() -> void:
	_main_at(&"h5")
	var choices_before := GameState.get_stat(&"quest_choices")
	assert_false(quests.choose(&"q_who_knows", &"h6", &"stay"), "not the current step")
	assert_false(quests.choose(&"q_who_knows", &"h5", &"nope"), "unknown choice")
	assert_true(quests.choose(&"q_who_knows", &"h5", &"confide_washer"))
	assert_eq(quests.choice_of(&"q_who_knows", &"h5"), &"confide_washer")
	assert_true(GameState.flag_on(&"q_confide_washer"), "set_flag action")
	assert_eq(rel.calls, [[&"washer", 4, DialogueActions.REASON_TALK]], "rel_add:washer:4")
	assert_has(changes, [&"q_who_knows", &"h5", &"chosen"])
	assert_eq(quests.current_step(&"q_who_knows"), &"h6")
	assert_false(quests.choose(&"q_who_knows", &"h5", &"confide_priest"), "chosen is chosen")
	assert_eq(GameState.get_stat(&"quest_choices") - choices_before, 1)


func test_ending_a_is_dimmed_without_the_letter_and_endings_settle() -> void:
	_main_at(&"h6")
	var listed := quests.choices(&"q_who_knows", {"conditions": {"letter_posted": false}})
	assert_eq(listed.map(func(c: Dictionary) -> StringName: return c.id), Phase9Fixtures.ENDINGS)
	assert_eq(listed[0].reason, "Er glaubt dir nicht. Er würde einem Brief glauben.")
	assert_eq(listed[1].reason, "")
	assert_false(quests.choose(&"q_who_knows", &"h6", &"away"), "letter_posted is not met (no letter at the door)")
	assert_true(quests.choose(&"q_who_knows", &"h6", &"stay"))
	assert_eq([quests.ending(&"q_who_knows"), quests.state(&"q_who_knows"), quests.current_step(&"q_who_knows")], [&"stay", &"ended", &""])
	assert_true(GameState.flag_on(&"q_end_stay") and GameState.flag_on(&"q_sieber_dies"))
	assert_has(changes, [&"q_who_knows", &"h6", &"ended"])
	assert_true(quests.steps_done(&"q_who_knows").has(&"h6"))
	assert_false(quests.choose(&"q_who_knows", &"h6", &"public"), "ended")
	GameState.set_flag(&"sieber_buried", true)
	TimeManager.advance(1)
	assert_eq(quests.state(&"q_who_knows"), &"settled", "settle_on sieber_buried (D3's marker)")
	assert_has(changes, [&"q_who_knows", &"", &"ended"])


func test_ending_without_settle_flag_settles_at_once() -> void:
	var q := QuestData.new()
	q.id = &"q_test"
	q.open_conditions = PackedStringArray(["flag:p9_open"])
	var s := QuestStepData.new()
	s.id = &"t1"
	s.complete_on = QuestStepData.ON_CHOICE
	var c := QuestChoiceData.new()
	c.id = &"yes"
	c.conditions = PackedStringArray(["flag:test_p9_ok"])
	c.actions = PackedStringArray(["set_flag:test_p9_said_yes"])
	c.ending = &"fine"
	s.choices = [c] as Array[QuestChoiceData]
	var e := QuestEndingData.new()
	e.id = &"fine"
	e.flag = &"test_p9_fine"
	q.steps = [s] as Array[QuestStepData]
	q.endings = [e] as Array[QuestEndingData]
	quests.quest_table = {&"q_test": q}
	_open()
	assert_false(quests.choose(&"q_test", &"t1", &"yes"), "condition not met")
	GameState.set_flag(&"test_p9_ok", true)
	assert_true(quests.choose(&"q_test", &"t1", &"yes"))
	assert_eq(quests.state(&"q_test"), &"settled")
	assert_true(GameState.flag_on(&"test_p9_fine") and GameState.flag_on(&"test_p9_said_yes"), "ending flag + action")


# --- deadlines ------------------------------------------------------------------------------------

func test_deadline_takes_the_fallback_choice() -> void:
	_main_at(&"h6")
	TimeManager.load_state({"day": 68, "minute_of_day": 360})
	quests.apply_morning(68)
	assert_eq(quests.ending(&"q_who_knows"), &"", "light + 17 is the last day")
	TimeManager.load_state({"day": 69, "minute_of_day": 360})
	quests.apply_morning(69)
	assert_eq([quests.choice_of(&"q_who_knows", &"h6"), quests.ending(&"q_who_knows"), quests.state(&"q_who_knows")],
			[&"silent", &"silent", &"ended"], "§2.2.7 still")
	assert_true(GameState.flag_on(&"q_end_silent") and GameState.flag_on(&"q_sieber_dies"))


func test_deadline_ends_the_chain_while_an_earlier_step_is_current() -> void:
	_main_at(&"h3")
	TimeManager.load_state({"day": 69, "minute_of_day": 400})
	quests.apply_morning(69)
	assert_eq(quests.ending(&"q_who_knows"), &"silent", "the village has its own course")
	assert_eq(quests.steps_done(&"q_who_knows"), [&"h1", &"h2", &"h6"] as Array[StringName], "H3–H5 stay undone")
	assert_eq(quests.current_step(&"q_who_knows"), &"")


# --- chapter --------------------------------------------------------------------------------------

func test_chapter_needs_all_three_and_comes_once() -> void:
	_open()
	quests.load_state({"open_day": OPEN, "open": ["q_who_knows", "q_letters", "q_case"], "step": {"q_letters": "l5"},
			"done": {"q_who_knows": Phase9Fixtures.MAIN_STEPS.map(func(s: StringName) -> String: return String(s)),
			"q_letters": ["l1", "l2", "l3", "l4"]}, "choices": {"q_who_knows": {"h6": "away"}}, "ending": {"q_who_knows": "away"}})
	assert_eq(quests.goal_progress().main, false, "away: not settled before Johann is gone")
	GameState.set_flag(&"sieber_gone", true)
	letters.decided = 5
	EventBus.hill_request_changed.emit(&"hrl_ferry_graves", &"completed")
	EventBus.hill_request_changed.emit(&"hr_lenz_stone", &"completed")
	assert_eq(chapters, [], "one large request")
	var p := quests.goal_progress()
	assert_eq([p.main, p.letters_step, p.letters_decided, p.large], [true, true, 5, 1], "a small one does not count")
	letters.decided = 4
	EventBus.hill_request_changed.emit(&"hrl_crosses", &"completed")
	assert_eq(chapters, [], "4 letters")
	letters.decided = 5
	EventBus.letter_changed.emit("lt_0005", &"lp_l3_burn", &"burned")
	assert_eq(chapters, [&"who_knows_when"], "§1.5")
	assert_true(GameState.flag_on(&"who_knows_when_complete"))
	EventBus.hill_request_changed.emit(&"hrl_restless", &"completed")
	assert_false(quests.check_goal())
	assert_eq(chapters, [&"who_knows_when"], "exactly once")
	assert_eq(quests.chapter_context().closing_line, Phase9Fixtures.quest(&"q_who_knows").endings[0].closing_line)


func test_large_requests_before_p9_open_do_not_count() -> void:
	EventBus.hill_request_changed.emit(&"hrl_ferry_graves", &"completed")
	_open()
	EventBus.hill_request_changed.emit(&"hrl_crosses", &"failed")
	assert_eq(quests.large_done(), [] as Array[StringName])
	EventBus.hill_request_changed.emit(&"hrl_crosses", &"completed")
	assert_eq(quests.large_done(), [&"hrl_crosses"] as Array[StringName])


# --- pin, save ------------------------------------------------------------------------------------

func test_pin_one_entry() -> void:
	quests.pin(&"q_who_knows")
	assert_eq(quests.pinned(), &"q_who_knows")
	quests.pin(&"hrl_ferry_graves")
	assert_eq(quests.pinned(), &"hrl_ferry_graves", "max_pinned 1: replaces")
	quests.pin(&"")
	assert_eq(quests.pinned(), &"")


func test_save_load_round_trip_and_tolerance() -> void:
	_main_at(&"h5")
	quests.note(&"date_grave", "e_ott")
	assert_true(quests.choose(&"q_who_knows", &"h5", &"confide_none"))
	quests.pin(&"q_who_knows")
	var saved := quests.save_state()
	assert_eq(saved.step, {"q_who_knows": "h6", "q_letters": "l1", "q_case": "k1"})
	assert_eq(saved.choices, {"q_who_knows": {"h5": "confide_none"}})
	assert_eq([saved.open_day, saved.pinned, saved.goal_done], [OPEN, "q_who_knows", false])
	var back := _new_quests()
	back.load_state(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved)))))
	assert_eq(back.save_state(), saved, "round trip")
	assert_eq([back.current_step(&"q_who_knows"), back.choice_of(&"q_who_knows", &"h5")], [&"h6", &"confide_none"])
	back.load_state({"open": ["q_who_knows", "q_nope", 7], "step": {"q_who_knows": "h9", "q_nope": "x"}, "done": {"q_who_knows": ["h1", "zz", 3]},
			"choices": {"q_who_knows": {"h5": "maybe", "h6": "stay"}, "q_case": "x"}, "ending": {"q_case": "nope"}, "settled": ["q_letters"],
			"notes": {"kladde_read": "x", "date_grave": ["e_ott", "e_ott"]}, "pinned": 5, "goal_done": "yes"})
	assert_eq(back.state(&"q_who_knows"), &"open")
	assert_eq(back.state(&"q_letters"), &"", "settled without an ending dropped")
	assert_eq(back.steps_done(&"q_who_knows"), [&"h1"] as Array[StringName])
	assert_eq(back.current_step(&"q_who_knows"), &"h2", "unknown step → the first one not done")
	assert_eq([back.choice_of(&"q_who_knows", &"h5"), back.choice_of(&"q_who_knows", &"h6")], [&"", &"stay"])
	assert_eq([back.ending(&"q_case"), back.pinned(), back.notes(&"date_grave"), back.notes(&"kladde_read")],
			[&"", &"", PackedStringArray(["e_ott"]), PackedStringArray()])
	back.free()
