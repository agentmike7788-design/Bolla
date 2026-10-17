extends TestCase
## P6 (docs/PHASE9_DESIGN.md §1.2, §5.2, §10): Phase-8 saves (format v7, tests/fixtures/saves_v7/) in the Phase-9 build,
## through the real SaveManager into the real world – what the dialogues, the journal and the story see.
## - slot_p8_mid: in the middle of Phase 8 – Phase 9 stays closed (no p9_open, no Phase-9 line in the dialogues, no D3,
##   no list in the journal); the small request on the board stays (the large ones come from the next morning, P2).
## - slot_p8_day2_hill / slot_p8_day30_village_hill: the small requests of G8 Runde 6 unchanged by the load.
## - slot_p8_day63_kindly: the reference start – once p9_open is set (Quests.post_load, P1) Osric's p9_intro and Fenner's
##   fourth row are there; D3 waits for an ending; nothing of Phase 9 is decided yet.
## All resave as the current format and round-trip identically, without warnings.

class WarningLog extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		messages.append(code + " " + rationale)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


const TIMEOUT := 300.0
const SLOT := 5
const RESAVE_SLOT := 6
## Phase-9 start nodes that must stay hidden while Phase 9 is closed (dialogue, node).
const P9_STARTS := [["carter", &"p9_intro"], ["v_mayor", &"p9_row4"], ["peddler", &"p9_aschau"], ["stranger", &"leaving"],
		["v_washer", &"p9_public_confidant"], ["kin_sieber", &"p9_away_wait"], ["beggar", &"p9_gone"], ["trader", &"p9_case_ilse"]]

var saves_dir := TestCase.user_dir("test_phase8_save_upgrade")
var warnings: WarningLog


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	warnings = WarningLog.new()
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_mid_phase9_stays_closed() -> void:
	await _load("slot_p8_mid")
	assert_true(GameState.flag_on(&"p8_open"))
	assert_false(GameState.has_flag(&"who_comes_up_complete"), "the Phase-8 chapter is open")
	assert_false(GameState.flag_on(&"p9_open"), "§1.2: Phase 9 stays closed")
	assert_false(DialogueConditions.check("p9_open", {}), "the dialogues see it closed")
	for spec: Array in P9_STARTS:
		var n := _node(spec[0], spec[1])
		assert_not_null(n, "%s.%s" % spec)
		if n != null:
			assert_false(DialogueConditions.all_met(n.conditions, _ctx()), "%s: %s hidden" % spec)
	# No [Die Liste] line anywhere: the list is unknown.
	for id: String in ["carter", "beggar", "v_washer", "v_innkeeper", "v_grocer", "kin_ott", "trader"]:
		for c: DialogueChoice in _node(id, &"menu").choices:
			if c.text.begins_with("[Die Liste]"):
				assert_false(DialogueConditions.all_met(c.conditions, _ctx()), "%s: %s hidden" % [id, c.text])
	var journal := tree.get_first_node_in_group(&"journal") as JournalManager
	assert_false(journal.list_known(), "no list in the journal")
	assert_false(journal.list_page().known)
	assert_eq(journal.letter_pages(), [] as Array[Dictionary], "no letters yet")
	# D3 cannot come; nothing is reserved for it.
	var d3 := Database.story_corpse(&"d3_sieber") as StoryCorpseData
	assert_false(StoryDirector.can_come(d3, TimeManager.day + 10), "no D3 without an ending")
	assert_eq(StoryDirector.apply_settled(tree), [] as Array[StringName], "nothing to settle")
	assert_eq(_hill().board(), [&"hr_osric_wood"] as Array[StringName], "the small request on the board stays")
	await _check_and_resave()


func test_day2_hill_small_requests_unchanged() -> void:
	await _load("slot_p8_day2_hill")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 600])
	assert_eq(_hill().board(), [&"hr_lenz_stone", &"hr_esch_stone"] as Array[StringName], "two small requests pinned")
	assert_eq(_hill().active(), [&"hr_lenz_stone"] as Array[StringName], "one accepted")
	assert_false(DialogueConditions.check("p9_open", {}))
	assert_false(DialogueConditions.check("large_ready:carter", _ctx()), "no large request accepted yet")
	await _check_and_resave()


func test_day30_village_hill_small_request_unchanged() -> void:
	await _load("slot_p8_day30_village_hill")
	assert_true(GameState.flag_on(&"village_open"))
	assert_eq(_hill().active(), [&"hr_liesel_paths"] as Array[StringName], "W0: the village rule – one place, Liesel's request")
	assert_false(DialogueConditions.check("p9_open", {}))
	await _check_and_resave()


func test_kindly_end_state_is_ready_for_phase9() -> void:
	await _load("slot_p8_day63_kindly")
	assert_true(GameState.has_flag(&"who_comes_up_complete"), "the chapter that opens Phase 9")
	if not GameState.flag_on(&"p9_open"):
		# W1: no Quests node in the world yet – what Quests.post_load does for a v7 state (§1.2).
		GameState.set_flag(&"p9_open", true)
		GameState.set_flag(&"p9_open_day", TimeManager.day)
		warnings.messages.clear()
	assert_true(DialogueConditions.check("p9_open", {}))
	assert_true(DialogueConditions.all_met(_node("carter", &"p9_intro").conditions, _ctx()), "Osric's p9_intro is next")
	assert_true(DialogueConditions.all_met(_node("v_mayor", &"p9_row4").conditions, _ctx()), "Fenner gives the fourth row")
	for spec: Array in [["v_washer", &"p9_public_confidant"], ["kin_sieber", &"p9_away_wait"], ["kin_sieber", &"p9_silent"],
			["v_mayor", &"p9_public_book"], ["trader", &"p9_case_ilse"]]:
		assert_false(DialogueConditions.all_met(_node(spec[0], spec[1]).conditions, _ctx()), "%s: %s – no ending yet" % spec)
	var d3 := Database.story_corpse(&"d3_sieber") as StoryCorpseData
	assert_false(StoryDirector.can_come(d3, 80), "D3 waits for B, C or silent")
	var journal := tree.get_first_node_in_group(&"journal") as JournalManager
	assert_false(journal.list_known(), "H1 is still to do")
	# Phase-8 saves know nothing of Phase 9: no witness, no letter, no stranger.
	for flag: StringName in [&"q_sieber_marked", &"sieber_gone", &"sieber_dead", &"sieber_buried", &"linden_row4_granted"]:
		assert_false(GameState.has_flag(flag), String(flag))
	GameState.clear_flag(&"p9_open")
	GameState.clear_flag(&"p9_open_day")
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase9Fixtures.install_save_v7(name, saves_dir, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _hill() -> HillRequests:
	return _world().get_node("Systems/HillRequests") as HillRequests


func _ctx() -> Dictionary:
	return {"inventory": _world().get_player().inventory, "speaker": null}


func _node(dialogue: String, id: StringName) -> DialogueNode:
	var d := load("res://data/dialogue/%s.tres" % dialogue) as DialogueData
	return d.get_node_by_id(id) if d != null else null


## No warning while loading, the next save writes the current format and round-trips.
func _check_and_resave() -> void:
	assert_eq(warnings.messages, PackedStringArray(), "no warnings while loading")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "next save writes the current format (v8)")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "round trip identical")
	assert_eq(warnings.messages, PackedStringArray(), "no warnings after the round trip")
