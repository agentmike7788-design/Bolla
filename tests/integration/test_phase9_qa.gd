extends TestCase
## W3 QA Phase 9 (docs/PHASE9_DESIGN.md §10, §12 W3; docs/reviews/phase9_wip/qa_g9.md): guards of the QA round.
## - The real mid-Phase-9 v8 save (tests/fixtures/saves_v8/slot_p9_mid_h4.json – taken over by the Lead in the W3 QA-Fix
##   from the candidate docs/reviews/phase9_wip/, written by test_save_fuzzer.gd with P9QA_FIXTURE_OUT): loads without warnings, keeps its Phase-9 state (chain at H4, a large
##   request at 2/3, Osric's post waiting, Brenneisen at the gate, Johann on his bench) and survives save → load.
## - QuestLog.entries (the Merkbuch „Vorhaben") within §9's 4 ms on that state (best of 10; the cloud host drifts).

const TIMEOUT := 300.0
const SLOT := 91
const CANDIDATE := "res://tests/fixtures/saves_v8/slot_p9_mid_h4.json"

var saves_dir := TestCase.user_dir("test_phase9_qa")


func before_each() -> void:
	SaveManager.save_dir = saves_dir


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _load_candidate() -> WorldRoot:
	var text := FileAccess.get_file_as_string(CANDIDATE)
	assert_ne(text, "", "the v8 fixture exists")
	if text == "":
		return null
	assert_eq(int((JSON.parse_string(text) as Dictionary).format_version), 8, "v8")
	SaveFileIO.ensure_dir(saves_dir)
	var f := FileAccess.open(SaveFileIO.slot_path(saves_dir, SLOT), FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, "the v8 fixture loads")
	TimeManager.running = false
	return tree.current_scene as WorldRoot if err == OK else null


func test_mid_phase9_save_keeps_its_state() -> void:
	var world := await _load_candidate()
	if world == null:
		return
	var quests := world.get_node("Systems/Quests") as Quests
	var hill := world.get_node("Systems/HillRequests") as HillRequests
	var letters := world.get_node("Systems/Letters") as Letters
	var stranger := world.get_node("Systems/Stranger") as Stranger
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [66, 870], "day 66 14:30")
	assert_eq(quests.current_step(&"q_who_knows"), &"h4", "the chain at H4")
	assert_eq(hill.parts_done(&"hrl_lantern_path"), [true, true, false] as Array[bool], "the large request at 2/3")
	assert_false(letters.open_uids().is_empty(), "letters open")
	assert_false(letters.post_today(66).is_empty(), "Osric's post waiting")
	assert_true(stranger.present(&"graveyard"), "Brenneisen at the gate")
	var johann := world.get_node("Regions/Village/Entities/npc_kin_sieber_v") as Npc
	johann.refresh()
	assert_true(johann.is_present(), "Johann on his bench")
	await wait_frames(4)
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT + 1), OK)
	assert_eq(await SaveManager.load_game(SLOT + 1), OK)
	TimeManager.running = false
	await wait_frames(1)
	assert_eq(SaveManager.collect_state(), before, "save → load identical")


func test_quest_log_entries_within_budget() -> void:
	var world := await _load_candidate()
	if world == null:
		return
	var best := 1e9
	var n := 0
	for i: int in 10:
		var t0 := Time.get_ticks_usec()
		n = QuestLog.entries(tree).size()
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	print("QA9 QuestLog.entries: %d entries, best %.3f ms" % [n, best])
	assert_true(n >= 4, "chains, the large request, orders in the log (%d)" % n)
	assert_true(best <= 4.0, "§9: QuestLog.entries ≤ 4 ms (%.3f)" % best)
