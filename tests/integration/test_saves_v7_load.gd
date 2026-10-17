extends TestCase
## Lead / W0 (docs/PHASE9_DESIGN.md §5.2, §5.3, §12): every Phase-8 save fixture (format v7,
## tests/fixtures/saves_v7/) loads through the real SaveManager into the real world without engine errors and
## without any warning, keeps its Phase-8 state (incl. the G8 Runde 6 hill requests), gets letter_id "" on every
## record and the Phase-9 stats at 0 (migrate_7_to_8), and the next save writes the current format (round trip
## identical). The checks stay valid after W1/W2 (v7 saves with who_comes_up_complete open Phase 9 at once –
## Quests.post_load, §1.2; the plots l_13…l_16 come LOCKED from the layout once W-Welt adds them).

## Records push_warning() messages (warnings never fail a test on their own).
class WarningLog extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		messages.append("%s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


const TIMEOUT := 300.0
## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_SAVES := TestCase.user_dir("test_saves_v7")
const SLOT := 7
const RESAVE_SLOT := 8

var warnings: WarningLog


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	_delete_saves()
	warnings = WarningLog.new()
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	_delete_saves()
	TestCase.remove_user_dir(TEST_SAVES)


func test_fixtures_are_format_v7() -> void:
	assert_eq(Phase9Fixtures.SAVES_V7.size(), 7, "§5.3: seven v7 fixtures")
	for name: String in Phase9Fixtures.SAVES_V7:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase9Fixtures.save_v7_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 7, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v7() -> void:
	assert_eq(Phase9Fixtures.install_save_v7("slot_p8_day63_kindly", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v7 slot listed")
	assert_eq([info.day, info.minute_of_day], [63, 420])


## §1.4 A / §2.8: the reference start of Phase 9 (kindly8 end, 07:00 day 63, chapter B10 on day 62).
func test_day63_kindly_loads() -> void:
	await _load("slot_p8_day63_kindly")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [63, 420])
	assert_true(GameState.has_flag(&"who_comes_up_complete"), "Phase 9 opens from here")
	assert_eq(int(GameState.get_flag(&"p8_open_day")), 53)
	assert_eq(_free_in(&"linden") + _free_in(&"linden_row3"), 0, "§1.4: the Lindenacker full")
	assert_eq(_count(GraveRecord.State.MARKED), 36)
	assert_eq(_coins(), 68, "W0-Notizen: measured 68 = purse 59 + tin 9 (§1.4 says ≈ 70)")
	assert_eq([GameState.get_stat(&"reputation"), GameState.get_stat(&"piety")], [100, 100])
	_assert_migrated()
	await _check_and_resave()


## trader9's start: anatomist8 end – specimens, anatomy_known.
func test_day63_anatomist_loads() -> void:
	await _load("slot_p8_day63_anatomist")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [64, 420], "W0-Notizen: the v6 start is day 54 – day 64")
	assert_true(GameState.has_flag(&"who_comes_up_complete"))
	assert_true(GameState.flag_on(&"anatomy_known"))
	assert_true(GameState.get_stat(&"specimens_taken") >= 10, "specimens (%d)" % GameState.get_stat(&"specimens_taken"))
	assert_eq(_coins(), 103)
	assert_eq(GameState.get_stat(&"piety"), -45)
	_assert_migrated()
	await _check_and_resave()


## K3 over Lambert: night8b end – Lambert let go, c_n_robber asked.
func test_day63_letgo_loads() -> void:
	await _load("slot_p8_day63_letgo")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [63, 420])
	assert_true(GameState.has_flag(&"who_comes_up_complete"))
	var robber := tree.get_first_node_in_group(&"night_robber") as NightRobber
	assert_eq(robber.fate() if robber != null else &"?", &"let_go", "Lambert let go")
	var journal := tree.get_first_node_in_group(&"journal") as JournalManager
	assert_true(journal != null and journal.has_clue(&"c_n_robber"), "c_n_robber (W0: asked who pays him)")
	_assert_migrated()
	await _check_and_resave()


## founder9's start: founder8 end (new game after Phase 8) – the chapter on day 60.
func test_founder_loads() -> void:
	await _load("slot_p8_founder")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [61, 420])
	for flag: StringName in [&"six_pits_complete", &"names_in_stone_complete", &"roof_and_earth_complete", &"name_in_village_complete",
			&"who_comes_up_complete"]:
		assert_true(GameState.has_flag(flag), String(flag))
	assert_eq(int(GameState.get_flag(&"p8_open_day")), 48)
	assert_eq(_coins(), 57)
	_assert_migrated()
	await _check_and_resave()


## §5.3: in the middle of Phase 8 – Phase 9 stays closed, the large requests run (from the next morning).
func test_mid_loads() -> void:
	await _load("slot_p8_mid")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [58, 420])
	assert_true(GameState.flag_on(&"p8_open"))
	assert_false(GameState.has_flag(&"who_comes_up_complete"), "chapter open")
	assert_false(GameState.flag_on(&"p9_open"), "Phase 9 stays closed")
	assert_eq(_hill().board(), [&"hr_osric_wood"] as Array[StringName], "the small request on the board stays")
	_assert_migrated()
	await _check_and_resave()


## §5.3: a new game on day 2, 10:00 – two small requests pinned, one accepted (G8 Runde 6).
func test_day2_hill_loads() -> void:
	await _load("slot_p8_day2_hill")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 600])
	assert_eq(_hill().board(), [&"hr_lenz_stone", &"hr_esch_stone"] as Array[StringName], "two small requests pinned")
	assert_eq(_hill().active(), [&"hr_lenz_stone"] as Array[StringName], "one accepted")
	assert_eq(_hill().accepted_day(&"hr_lenz_stone"), 2)
	_assert_migrated()
	await _check_and_resave()


## §5.3: the village open, one small request accepted. W0-Notizen: the village opens on day 37 at the
## earliest (v5 founder) – the state is day 38 (file name of the contract kept).
func test_day30_village_hill_loads() -> void:
	await _load("slot_p8_day30_village_hill")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [38, 600])
	assert_true(GameState.flag_on(&"village_open"))
	assert_false(GameState.flag_on(&"p8_open"))
	assert_eq(_hill().active(), [&"hr_liesel_paths"] as Array[StringName], "one accepted (village rules: one place)")
	_assert_migrated()
	await _check_and_resave()


## §5.2 step 2: the plots l_13…l_16 do not exist before W-Welt adds them to the layout – then they come LOCKED.
func test_row4_plots_follow_the_layout() -> void:
	await _load("slot_p8_day63_kindly")
	for plot: String in Phase9Fixtures.ROW4_PLOTS:
		var g := _world().graveyard.get_grave(plot)
		if g != null:
			assert_eq(g.state, GraveRecord.State.LOCKED, "%s LOCKED until cleared" % plot)
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase9Fixtures.install_save_v7(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _player() -> Player:
	return _world().get_player()


func _hill() -> HillRequests:
	return _world().get_node("Systems/HillRequests") as HillRequests


## Purse + Jakob's wage tin (Phase8Bot.coins_total).
func _coins() -> int:
	var box := _world().get_node_or_null("Entities/apprentice_box") as ApprenticeBox
	return _player().inventory.count(&"coin") + (box.coins if box != null else 0)


func _count(state: GraveRecord.State) -> int:
	var n := 0
	for g: GraveRecord in _world().graveyard.graves():
		if g.state == state:
			n += 1
	return n


func _free_in(section: StringName) -> int:
	var n := 0
	for g: GraveRecord in _world().graveyard.graves():
		if _world().graveyard.section_of(g.id) == section and (g.state == GraveRecord.State.EMPTY or g.state == GraveRecord.State.DUG):
			n += 1
	return n


## §5.2 steps 1 and 5 after the load: letter_id "" on every record, the Phase-9 stats at 0, no Phase-9 flag.
func _assert_migrated() -> void:
	for r: CorpseRecord in _world().corpse_manager.records():
		assert_eq(r.letter_id, &"", "%s: letter_id \"\"" % r.id)
	for key: StringName in SaveMigration.V8_NEW_STATS:
		assert_eq(GameState.get_stat(key), 0, "§5.2 step 5: %s" % key)
	if tree.get_nodes_in_group(&"quests").is_empty():
		assert_false(GameState.has_flag(&"p9_open"), "W0: no Quests node – p9_open comes with Quests.post_load")


## No warning at all while loading; the next save is the current format and round-trips.
func _check_and_resave() -> void:
	assert_eq(warnings.messages, PackedStringArray(), "no warnings while loading")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "next save writes the current format")
	assert_eq(SaveFileIO.FORMAT_VERSION, SaveMigration.CURRENT)
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "round trip")
	assert_eq(warnings.messages, PackedStringArray(), "no warnings after the round trip")


func _delete_saves() -> void:
	if SaveManager.save_dir != TEST_SAVES:
		return
	for slot: int in [SLOT, RESAVE_SLOT]:
		SaveManager.delete_save(slot)
