extends TestCase
## P1 (docs/PHASE9_DESIGN.md §2.1, §3.4, §10): QuestRules – every complete_on kind (flag, clue, insight, order, note,
## choice, ending) with complete_count, the next visible step in order, the deadline day (GameState flag + offset),
## why a choice is dimmed (conditions, block_text), the progress of a step. Pure – fixtures + state dictionaries.


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _step(on: StringName, ids: Array[StringName], count: int = 0) -> QuestStepData:
	var s := QuestStepData.new()
	s.id = &"s"
	s.complete_on = on
	s.complete_ids = ids
	s.complete_count = count
	return s


func test_flag_steps_all_or_count() -> void:
	var s := _step(QuestStepData.ON_FLAG, [&"a", &"b"] as Array[StringName])
	assert_false(QuestRules.step_complete(s, {"flags": {&"a": true}}, tree), "0 = all")
	assert_true(QuestRules.step_complete(s, {"flags": {&"a": true, "b": 1}}, tree))
	s.complete_count = 1
	assert_true(QuestRules.step_complete(s, {"flags": {&"b": true}}, tree), "≥ 1")
	assert_false(QuestRules.step_complete(s, {"flags": {&"a": false}}, tree))
	# Without a flags override GameState answers (H4 q_sieber_marked).
	var main := Phase9Fixtures.quest(&"q_who_knows")
	assert_false(QuestRules.step_complete(main.steps[3], {}, tree))
	GameState.set_flag(&"q_sieber_marked", true)
	assert_true(QuestRules.step_complete(main.steps[3], {}, tree), "H4")
	assert_false(QuestRules.step_complete(_step(QuestStepData.ON_FLAG, [] as Array[StringName]), {}, tree), "no ids = never")


func test_clue_insight_and_order_steps() -> void:
	var k3 := Phase9Fixtures.quest(&"q_case").steps[2]
	assert_false(QuestRules.step_complete(k3, {"clues": []}, tree))
	assert_true(QuestRules.step_complete(k3, {"clues": [&"c_q_case_lorenz"]}, tree), "K3 clue")
	GameState.set_flag(&"clue_c_q_case_lorenz", true)
	assert_true(QuestRules.step_complete(k3, {}, tree), "no journal: the clue flag clue_<id>")
	var h3 := Phase9Fixtures.quest(&"q_who_knows").steps[2]
	assert_false(QuestRules.step_complete(h3, {"insights": []}, tree))
	assert_true(QuestRules.step_complete(h3, {"insights": ["i_light_before"]}, tree), "H3 insight")
	assert_false(QuestRules.step_complete(h3, {}, tree), "no journal in the tree: not unlocked")
	var l3 := Phase9Fixtures.quest(&"q_letters").steps[2]
	assert_false(QuestRules.step_complete(l3, {"orders": {&"oq_gesa_brother": &"accepted"}}, tree))
	assert_true(QuestRules.step_complete(l3, {"orders": {"oq_gesa_brother": "completed"}}, tree), "L3 order completed")
	assert_false(QuestRules.step_complete(l3, {}, tree), "no Orders in the tree")


func test_note_steps_count_distinct_arguments() -> void:
	var main := Phase9Fixtures.quest(&"q_who_knows")
	var h1 := main.steps[0]
	var h2 := main.steps[1]
	assert_false(QuestRules.step_complete(h1, {"notes": {}}, tree))
	assert_true(QuestRules.step_complete(h1, {"notes": {&"kladde_read": PackedStringArray([""])}}, tree), "H1: one note")
	var four := {&"date_grave": PackedStringArray(["e_dorn", "e_quendel", "e_wernstein", "e_ott"])}
	assert_false(QuestRules.step_complete(h2, {"notes": four}, tree), "H2: 4 of 5")
	assert_eq(QuestRules.step_progress(h2, {"notes": four}, tree), Vector2i(4, 5), "„4/5 Gräber verglichen“")
	var five := {"date_grave": ["e_dorn", "e_quendel", "e_wernstein", "e_ott", "e_hagedorn"]}
	assert_true(QuestRules.step_complete(h2, {"notes": five}, tree), "H2: 5 (plain Array, String keys)")
	var two_keys := _step(QuestStepData.ON_NOTE, [&"x", &"y"] as Array[StringName])
	assert_false(QuestRules.step_complete(two_keys, {"notes": {&"x": PackedStringArray(["1", "2"])}}, tree), "0 = every key")
	assert_true(QuestRules.step_complete(two_keys, {"notes": {&"x": PackedStringArray(["1"]), &"y": PackedStringArray(["1"])}}, tree))


func test_choice_and_ending_steps() -> void:
	var h5 := Phase9Fixtures.quest(&"q_who_knows").steps[4]
	assert_false(QuestRules.step_complete(h5, {"choice": &""}, tree))
	assert_true(QuestRules.step_complete(h5, {"choice": &"confide_none"}, tree))
	var any_end := _step(QuestStepData.ON_ENDING, [&"q_who_knows"] as Array[StringName])
	var stay := _step(QuestStepData.ON_ENDING, [&"q_who_knows:stay"] as Array[StringName])
	assert_false(QuestRules.step_complete(any_end, {"endings": {}}, tree))
	assert_true(QuestRules.step_complete(any_end, {"endings": {&"q_who_knows": &"away"}}, tree), "any ending")
	assert_false(QuestRules.step_complete(stay, {"endings": {&"q_who_knows": &"away"}}, tree), "a named ending")
	assert_true(QuestRules.step_complete(stay, {"endings": {"q_who_knows": "stay"}}, tree))
	assert_false(QuestRules.step_complete(null, {}, tree))


func test_next_step_strictly_in_order() -> void:
	var main := Phase9Fixtures.quest(&"q_who_knows")
	assert_eq(QuestRules.next_step(main, [] as Array[StringName]).id, &"h1")
	assert_eq(QuestRules.next_step(main, [&"h1", &"h2"] as Array[StringName]).id, &"h3")
	assert_eq(QuestRules.next_step(main, [&"h2"] as Array[StringName]).id, &"h1", "the first one not done")
	assert_null(QuestRules.next_step(main, Phase9Fixtures.MAIN_STEPS))
	assert_null(QuestRules.next_step(null, [] as Array[StringName]))
	assert_eq(QuestRules.step(main, &"h4").title, "„S.“")
	assert_eq(QuestRules.choice(main.steps[5], &"public").ending, &"public")
	assert_eq(QuestRules.ending_data(main, &"away").settle_on, &"sieber_gone")
	assert_null(QuestRules.ending_data(main, &"nope"))


func test_deadline_day_from_flag_and_offset() -> void:
	var h6 := Phase9Fixtures.quest(&"q_who_knows").steps[5]
	assert_eq(QuestRules.deadline_day(h6), -1, "q_light_day not set yet")
	GameState.set_flag(&"q_light_day", 51)
	assert_eq(QuestRules.deadline_day(h6), 68, "§2.2.2: light + 17 = B6")
	GameState.set_flag(&"q_light_day", true)
	assert_eq(QuestRules.deadline_day(h6), -1, "a bool is no day")
	assert_eq(QuestRules.deadline_day(Phase9Fixtures.quest(&"q_who_knows").steps[0]), -1, "no deadline")
	assert_eq(QuestRules.deadline_day(null), -1)


func test_choice_block_reason() -> void:
	var h6 := Phase9Fixtures.quest(&"q_who_knows").steps[5]
	var away := QuestRules.choice(h6, &"away")
	assert_eq(QuestRules.choice_block_reason(away, {"conditions": {"letter_posted": false}}), "Er glaubt dir nicht. Er würde einem Brief glauben.",
			"ending A without the letter is dimmed with its reason")
	assert_eq(QuestRules.choice_block_reason(away, {"conditions": {"letter_posted": true}}), "")
	assert_eq(QuestRules.choice_block_reason(QuestRules.choice(h6, &"stay"), {}), "", "no conditions")
	var c := QuestChoiceData.new()
	c.conditions = PackedStringArray(["flag:test_p9_choice"])
	assert_eq(QuestRules.choice_block_reason(c, {}), QuestRules.TEXT_BLOCKED, "DialogueConditions; no own text")
	GameState.set_flag(&"test_p9_choice", true)
	assert_eq(QuestRules.choice_block_reason(c, {}), "")
	assert_eq(QuestRules.choice_block_reason(null, {}), QuestRules.TEXT_BLOCKED)
	assert_eq(QuestRules.step_progress(h6, {}, tree), Vector2i.ZERO, "a choice has no count")
