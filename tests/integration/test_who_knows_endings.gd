extends TestCase
## P4 (docs/PHASE9_DESIGN.md §2.2, §2.2.7, §2.2.8, §10): the main chain on the real world of the v7 fixture
## slot_p8_day63_kindly – the real CorpseManager records, graves, NightPaths (np_sieber from data), Visitors,
## Relationships, Orders and JournalManager; Quests and WhoKnows are added to Systems here (W-Welt hangs them into the
## world in W2). H1–H5 through the system calls the prompts and dialogue actions make (Desk, GravePlot, witness:<entry>,
## mark_seen, quest_choose – P3 / P6 wire them), then the runs A with Hanne, A with Osric (late choice), B, C and still
## (deadline): flags, relationships, np_sieber on / off, sieber_dead, the departure, the note at the hut door, the
## node states' round trip at the departure / in the death night.
## W1 stand-ins (removed when the owners deliver): the Phase-9 clues / i_light_before / items come from the fixtures
## (P6 / P3 data), and H6 „away" is checked against the flag q_test_letter_posted instead of the P6 condition
## letter_posted (DialogueConditions) – the real data's condition is asserted to block without the letter.

var TEST_SAVES := TestCase.user_dir("test_who_knows_endings")
const SLOT := 7
const WITNESSES: Array[StringName] = [&"e_quendel", &"e_wernstein", &"e_hagedorn"]
const TEST_LETTER_FLAG := &"q_test_letter_posted"

var quests: Quests
var who: WhoKnows


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	SaveManager.delete_save(SLOT)
	assert_eq(Phase9Fixtures.install_save_v7("slot_p8_day63_kindly", TEST_SAVES, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, "v7 kindly loads")
	TimeManager.running = false
	Phase9Fixtures._inject_items()
	_inject_journal()
	var systems := _world().get_node("Systems")
	quests = Quests.new()
	quests.name = "Quests"
	who = WhoKnows.new()
	who.name = "WhoKnows"
	systems.add_child(quests)
	systems.add_child(who)
	# The H6 choice „away" against a test flag (P6's letter_posted does not exist yet).
	var main := (Database.quest(&"q_who_knows") as QuestData).duplicate(true) as QuestData
	for s: QuestStepData in main.steps:
		for c: QuestChoiceData in s.choices:
			if c.id == &"away":
				c.conditions = PackedStringArray(["flag:%s" % TEST_LETTER_FLAG])
	for q: Resource in Database.quests():
		quests.quest_table[(q as QuestData).id] = q as QuestData
	quests.quest_table[&"q_who_knows"] = main
	quests.load_state({})
	quests.post_load()
	who.apply_morning(TimeManager.day)


func after_each() -> void:
	UIState.clear()
	Phase9Fixtures.remove_injected_items()
	SaveManager.delete_save(SLOT)
	TestCase.remove_user_dir(TEST_SAVES)


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _journal() -> JournalManager:
	return tree.get_first_node_in_group(&"journal") as JournalManager


func _rel() -> Relationships:
	return tree.get_first_node_in_group(&"relationships") as Relationships


func _visitors() -> Visitors:
	return tree.get_first_node_in_group(&"visitors") as Visitors


func _orders() -> Orders:
	return tree.get_first_node_in_group(&"orders") as Orders


## The Phase-9 clues and i_light_before of the fixtures while data/journal has none of them (P6).
func _inject_journal() -> void:
	var j := _journal()
	j.clue_by_id(&"c_n_kladde")
	j.insight_by_id(&"i_underlined")
	for id: StringName in Phase9Fixtures.CLUE_IDS:
		if j.clue_by_id(id) == null:
			j.clue_data.append(Phase9Fixtures.clue(id))
	if j.insight_by_id(&"i_light_before") == null:
		j.insight_data.append(Phase9Fixtures.insight())


func _run_to(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		var step := mini(target - TimeManager.total_minutes(), 60)
		TimeManager.advance(step)
		await tree.process_frame


## H1–H5 as the prompts / dialogues do it; the confidant `confide`.
func _h1_to_h5(confide: StringName) -> void:
	assert_true(quests.is_open(), "§1.2: v7 with the chapter opens at once")
	assert_eq([quests.open_day(), who.light_day()], [63, 51], "light 22. Nebelung")
	var inv := _world().get_player().inventory
	if who.read_block_reason(inv) != "":
		inv.add_item(&"lorenz_ledger_2", 1)  # Lenz gives it back (P6 dialogue)
	assert_eq(who.read_block_reason(inv), "")
	who.read_kladde()
	assert_eq(quests.current_step(&"q_who_knows"), &"h2")
	assert_eq(who.compare_register().size(), 5, "all five dead lie on the hill")
	for story: StringName in Phase9Fixtures.LIST_DEAD:
		var grave := str(Phase9Fixtures.LIST_DEAD[story][0])
		assert_true(who.compare_grave(grave), "date compared at %s" % grave)
	assert_eq(quests.current_step(&"q_who_knows"), &"h3", "„Immer drei Wochen.“")
	for e: StringName in WITNESSES:
		assert_true(who.witness(e), String(e))
	var picked: Array[StringName] = [&"c_q_dates", &"c_q_three_weeks", &"c_q_light_quendel", &"c_q_light_wernstein", &"c_q_light_hagedorn"]
	assert_eq(_journal().try_link(picked), &"i_light_before", "3 of 5 witnesses")
	assert_eq(quests.current_step(&"q_who_knows"), &"h4")
	await _run_to(64, 420)
	assert_eq(_visitors().kin_interval(&"kin_sieber"), 1, "Johann daily from H4")
	who.mark_seen()
	await _run_to(64, 600)
	assert_eq(quests.current_step(&"q_who_knows"), &"h5")
	assert_true(quests.choose(&"q_who_knows", &"h5", confide))
	assert_eq(quests.current_step(&"q_who_knows"), &"h6")


func _post_the_letter(day: int) -> void:
	var inv := _world().get_player().inventory
	inv.add_item(&"ink", 1)
	assert_true(who.write_letter(inv), "the nameless letter (Desk)")
	await _run_to(day, 1290)
	assert_true(who.post_letter(inv), "at the Siebers' door at night")
	GameState.set_flag(TEST_LETTER_FLAG, true)


func test_ending_a_with_hanne() -> void:
	await _h1_to_h5(&"confide_washer")
	var real_away := QuestRules.choice((Database.quest(&"q_who_knows") as QuestData).steps[5], &"away")
	assert_eq(real_away.conditions, PackedStringArray(["letter_posted"]), "the real condition (P6)")
	assert_false(quests.choose(&"q_who_knows", &"h6", &"away"), "no letter at the door yet")
	await _post_the_letter(64)
	await _run_to(65, 600)
	assert_true(quests.choose(&"q_who_knows", &"h6", &"away"))
	assert_true(GameState.flag_on(&"q_end_away"))
	await _run_to(65, 601)
	assert_eq(who.depart_plan(), {"day": 67, "minute": 980, "with": &"peddler"}, "Hanne's day 67 ≤ light + 18")
	await _run_to(67, 990)
	var saved := who.save_state()
	var copy := WhoKnows.new()
	copy.load_state(saved)
	assert_eq(copy.save_state(), saved, "round trip on the forest path")
	copy.free()
	assert_false(GameState.flag_on(&"sieber_gone"))
	await _run_to(67, 1030)
	assert_true(GameState.flag_on(&"sieber_gone"), "gone after the walk")
	await _run_to(67, 1031)
	assert_eq(quests.state(&"q_who_knows"), &"settled")
	await _run_to(68, 400)
	assert_true(_journal().has_clue(&"c_q_hand_answers"), "„Du schreibst wie er. Gut.“")
	assert_eq(_visitors().kin_interval(&"kin_sieber"), -1)
	await _run_to(72, 300)
	assert_false(GameState.has_flag(&"sieber_dead"), "np_sieber cancelled (cancel_flag)")
	assert_false(GameState.flag_on(&"q_sieber_dies"), "no D3")


func test_ending_a_with_osric_after_a_late_choice() -> void:
	await _h1_to_h5(&"confide_none")
	await _post_the_letter(67)
	await _run_to(68, 900)
	assert_true(quests.choose(&"q_who_knows", &"h6", &"away"))
	await _run_to(68, 901)
	assert_eq(who.depart_plan(), {"day": 69, "minute": 600, "with": &"carter"}, "Hanne comes only on day 73")
	await _run_to(69, 700)
	assert_true(GameState.flag_on(&"sieber_gone"))


func test_ending_b_stays_dies_in_the_night() -> void:
	await _h1_to_h5(&"confide_surgeon")
	var surgeon := _rel().value(&"surgeon")
	await _run_to(66, 600)
	assert_true(quests.choose(&"q_who_knows", &"h6", &"stay"))
	await _run_to(66, 601)
	assert_eq(_rel().value(&"surgeon") - surgeon, 3, "Quast +3 (confidant, ending B; kindly8: 61 + 4 + 3)")
	assert_eq(_orders().state(&"oq_johann_evening"), &"offered", "two evenings on the bench")
	assert_true(GameState.flag_on(&"q_sieber_dies"))
	await _run_to(70, 1360)
	var paths := tree.get_first_node_in_group(&"night_paths") as NightPaths
	assert_eq(paths.sick_houses(70, 1360), PackedStringArray(["house_sieber"]), "the sick light, light + 19")
	await _run_to(72, 140)
	assert_eq(GameState.get_flag(&"sieber_dead"), 72, "02:10 on light + 21")
	var saved := who.save_state()
	var copy := WhoKnows.new()
	copy.load_state(saved)
	assert_eq(copy.save_state(), saved, "round trip in the death night")
	copy.free()
	assert_eq(quests.state(&"q_who_knows"), &"ended", "until D3 is buried")
	GameState.set_flag(&"sieber_buried", true)
	await _run_to(73, 900)
	assert_eq(quests.state(&"q_who_knows"), &"settled")


func test_ending_c_public() -> void:
	await _h1_to_h5(&"confide_washer")
	var before := {}
	for npc: StringName in [&"priest", &"surgeon", &"washer", &"mayor"]:
		before[npc] = _rel().value(npc)
	assert_true(quests.choose(&"q_who_knows", &"h6", &"public"))
	await _run_to(64, 700)
	var delta := {}
	for npc: StringName in before:
		delta[npc] = _rel().value(npc) - int(before[npc])
	var expected := {}
	for npc: StringName in {&"priest": -4, &"surgeon": -4, &"washer": 0, &"mayor": 4}:
		var d: int = {&"priest": -4, &"surgeon": -4, &"washer": 0, &"mayor": 4}[npc]
		expected[npc] = clampi(int(before[npc]) + d, 0, 100) - int(before[npc])
	assert_eq(delta, expected, "§2.2.7 C: Fenner +4 (kindly8: already 100), the three −4 but Liesel")
	assert_true(GameState.flag_on(&"fenner_lightbook") and GameState.flag_on(&"q_sieber_dies"))
	await _run_to(72, 140)
	assert_eq(GameState.get_flag(&"sieber_dead"), 72, "Johann dies anyway")


func test_still_by_the_deadline() -> void:
	await _h1_to_h5(&"confide_surgeon")
	var surgeon := _rel().value(&"surgeon")
	await _run_to(68, 1430)
	assert_eq(quests.ending(&"q_who_knows"), &"", "B6 23:50: still open")
	await _run_to(69, 370)
	assert_eq(quests.ending(&"q_who_knows"), &"silent", "light + 17 passed → still")
	assert_true(GameState.flag_on(&"q_end_silent") and GameState.flag_on(&"q_sieber_dies"))
	assert_eq(_rel().value(&"surgeon"), surgeon, "still: no relationship change")
	await _run_to(72, 140)
	assert_eq(GameState.get_flag(&"sieber_dead"), 72)
