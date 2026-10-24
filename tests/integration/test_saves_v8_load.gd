extends TestCase
## Lead / W0 (docs/PHASE10_DESIGN.md §5.2, §5.3, §12): every Phase-9 save fixture (format v8,
## tests/fixtures/saves_v8/) loads through the real SaveManager into the real world without engine errors and without
## any warning, keeps its Phase-9 state, gets the Phase-10 stats at 0 (migrate_8_to_9) with coins, inventories, chests
## and the wage tin unchanged (§5.2 step 3), and the next save writes the current format (round trip identical). The
## checks stay valid after W1/W2 (v8 saves with who_knows_when_complete open Phase 10 at once – Treasury.post_load,
## §1.2; the cash book begins on the load day).

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
var TEST_SAVES := TestCase.user_dir("test_saves_v8")
const SLOT := 7
const RESAVE_SLOT := 8
const OLD_CHAPTERS: Array[StringName] = [&"cemetery_complete", &"names_in_stone_complete", &"roof_and_earth_complete",
		&"name_in_village_complete", &"who_comes_up_complete", &"who_knows_when_complete"]

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


func test_fixtures_are_format_v8() -> void:
	assert_eq(Phase10Fixtures.SAVES_V8.size(), 7, "§5.3: six new v8 fixtures + slot_p9_mid_h4")
	for name: String in Phase10Fixtures.SAVES_V8:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase10Fixtures.save_v8_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 8, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v8() -> void:
	assert_eq(Phase10Fixtures.install_save_v8("slot_p9_day75_kindly", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v8 slot listed")
	assert_eq([info.day, info.minute_of_day], [75, 420])


## §1.4 A / §2.9: the reference start of Phase 10 (kindly9 end, 07:00 day 75 = Tuesday, 16. Julmond 1834).
func test_day75_kindly_loads() -> void:
	await _load("slot_p9_day75_kindly")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [75, 420])
	assert_eq(CalendarRules.weekday_name(TimeManager.day), "Dienstag")
	_assert_chapters(6)
	assert_eq(int(GameState.get_flag(&"p9_open_day")), 63)
	assert_true(GameState.flag_on(&"q_end_away") and GameState.flag_on(&"sieber_gone"), "ending A")
	assert_eq(_count(GraveRecord.State.MARKED), 40)
	assert_eq(_free(), 0, "W0-Notizen: the hill is full – row 4 too (§1.4 expected one free place)")
	assert_eq(_coins(), 129, "W0-Notizen: measured 129 = purse 120 + tin 9 (§1.4 says ≈ 132)")
	assert_eq([GameState.get_stat(&"reputation"), GameState.get_stat(&"piety")], [100, 100])
	assert_true(GameState.flag_on(&"bruch_license"), "the lease letter (§2.5.5) is the quarry letter")
	_assert_migrated()
	await _check_and_resave()


## trader10's start: trader9 end (anatomist) – the chapter on day 72. W0-Notizen: the v7 start is day 64 – day 76.
func test_day75_trader_loads() -> void:
	await _load("slot_p9_day75_trader")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [76, 420], "W0-Notizen: file name of the contract kept")
	_assert_chapters(6)
	assert_eq(int(GameState.get_flag(&"p9_open_day")), 64)
	assert_true(GameState.flag_on(&"anatomy_known"))
	assert_eq(_coins(), 120)
	assert_eq(GameState.get_stat(&"piety"), -60)
	_assert_migrated()
	await _check_and_resave()


## stay10's start: stay9 end – ending B, D3 buried in row 4, no free grave.
func test_day75_stay_loads() -> void:
	await _load("slot_p9_day75_stay")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [75, 420])
	_assert_chapters(6)
	assert_true(GameState.flag_on(&"q_end_stay"), "ending B")
	assert_eq(int(GameState.get_flag(&"sieber_dead")), 72)
	assert_eq(_free(), 0, "§5.3: row 4 full – no free grave")
	assert_eq(_coins(), 133)
	_assert_migrated()
	await _check_and_resave()


## founder10's start: founder9 end (new game after Phase 9) – the chapter on day 67.
func test_founder_loads() -> void:
	await _load("slot_p9_founder")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [68, 420])
	_assert_chapters(6)
	assert_eq(int(GameState.get_flag(&"p9_open_day")), 61)
	assert_eq(_coins(), 129)
	_assert_migrated()
	await _check_and_resave()


## §5.3: the village open (+ one founder7 day), no Phase 8/9 – the market without p10_open.
func test_day38_village_loads() -> void:
	await _load("slot_p9_day38_village")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [38, 420])
	assert_eq(CalendarRules.weekday_name(TimeManager.day), "Sonntag")
	assert_true(GameState.flag_on(&"village_open"))
	assert_eq(int(GameState.get_flag(&"village_open_day")), 37)
	assert_false(GameState.flag_on(&"p8_open"))
	assert_false(GameState.has_flag(&"who_knows_when_complete"), "no Phase-9 chapter")
	assert_eq(_coins(), 31)
	_assert_migrated()
	await _check_and_resave()


## §5.3: a new game, the evening of day 29 (W0-Notizen: 23:05 – crafter's evening ran past 23:00); the next morning is
## the first month's first (day 30 = 1. Nebelung) – only the rent (lease letter, village closed).
func test_day29_new_loads() -> void:
	await _load("slot_p9_day29_new")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [29, 1385])
	assert_true(CalendarRules.is_first_of_month(TimeManager.day + 1), "day 30 = 1. Nebelung")
	assert_true(GameState.flag_on(&"bruch_license"), "rent from the lease letter")
	assert_false(GameState.flag_on(&"village_open"), "no tithe / estimate before village_open")
	assert_true(GameState.has_flag(&"names_in_stone_complete"))
	assert_eq(_player().inventory.count(&"coin"), 43)
	_assert_migrated()
	await _check_and_resave()


## The W3 fixture of Phase 9 (taken over in the G9 QA-Fix): mid H4, Phase 9 open, the chapter open.
func test_mid_h4_loads() -> void:
	await _load("slot_p9_mid_h4")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [66, 870])
	assert_true(GameState.flag_on(&"p9_open"))
	assert_false(GameState.has_flag(&"who_knows_when_complete"), "chapter open – Phase 10 stays closed")
	_assert_migrated()
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase10Fixtures.install_save_v8(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _player() -> Player:
	return _world().get_player()


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


func _free() -> int:
	return _count(GraveRecord.State.EMPTY) + _count(GraveRecord.State.DUG)


func _assert_chapters(n: int) -> void:
	for i: int in n:
		assert_true(GameState.has_flag(OLD_CHAPTERS[i]), String(OLD_CHAPTERS[i]))


## §5.2 step 2 after the load: the Phase-10 stats at 0; no Phase-10 flag while the world has no Treasury (W0).
func _assert_migrated() -> void:
	for key: StringName in SaveMigration.V9_NEW_STATS:
		assert_eq(GameState.get_stat(key), 0, "§5.2 step 2: %s" % key)
	if tree.get_nodes_in_group(&"treasury").is_empty():
		assert_false(GameState.has_flag(&"p10_open"), "W0: no Treasury node – p10_open comes with Treasury.post_load")


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
