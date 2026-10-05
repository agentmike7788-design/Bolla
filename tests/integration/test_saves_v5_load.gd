extends TestCase
## Lead / W0 (docs/PHASE7_DESIGN.md §5.2, §12): every Phase-6 save fixture (format v5,
## tests/fixtures/saves_v5/) loads through the real SaveManager into the real world without engine
## errors and without any warning, keeps its Phase-6 state, and the next save writes the current format
## (round trip identical). W0: migrate_5_to_6 is the identity; P6 adds the §5.2 assertions (region_id,
## record fields, empty Phase-7 nodes) in test_save_migration.gd and
## tests/integration/test_phase6_save_upgrade.gd. The checks here stay valid after W1/W2 (v5 saves with
## roof_and_earth_complete open the village at once – Village.post_load, §1.2).

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


const TIMEOUT := 240.0
## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_SAVES := TestCase.user_dir("test_saves_v5")
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


func test_fixtures_are_format_v5() -> void:
	assert_eq(Phase7Fixtures.SAVES_V5.size(), 7, "§5.2: seven v5 fixtures")
	for name: String in Phase7Fixtures.SAVES_V5:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase7Fixtures.save_v5_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 5, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v5() -> void:
	assert_eq(Phase7Fixtures.install_save_v5("slot_p6_day40_reverent", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v5 slot listed")
	assert_eq([info.day, info.minute_of_day], [40, 420])


## §1.4 A / §2.10: the reference start of Phase 7 (reverent6 end, 07:00 day 40).
func test_day40_reverent_loads() -> void:
	await _load("slot_p6_day40_reverent")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [40, 420])
	assert_true(GameState.has_flag(&"roof_and_earth_complete"), "Phase 7 opens from here")
	assert_eq(_levels(), {&"crypt": 2, &"chapel": 2, &"shed": 2} as Dictionary[StringName, int], "all three buildings on level 2")
	assert_eq(_count(GraveRecord.State.MARKED), 23, "W0-Notizen: 23 graves marked (§1.4 says ≈ 24)")
	assert_eq(_count(GraveRecord.State.OLD), 3, "old_01, old_08 in their rest period + old_03 still liftable")
	assert_eq(_grave_state("old_03"), GraveRecord.State.OLD, "old_03 still liftable")
	assert_eq(_reinterred(), 5, "5 reinterred")
	assert_eq(GameState.get_stat(&"reputation"), 100)
	assert_eq(_player().inventory.count(&"coin"), 20, "§2.10: ≈ 20 at 07:00 (measured 20)")
	await _check_and_resave()


func test_day45_harvester_loads() -> void:
	await _load("slot_p6_day45_harvester")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [45, 420])
	assert_true(GameState.has_flag(&"roof_and_earth_complete"))
	assert_eq(_levels(), {&"crypt": 3, &"chapel": 2, &"shed": 2} as Dictionary[StringName, int], "crypt 3")
	assert_eq(_player().inventory.count(&"coin"), 63, "≈ 63 of §2.10")
	assert_eq(GameState.get_stat(&"reputation"), 96)
	assert_true(_robbed() >= 10, "many robbed souls (%d)" % _robbed())
	await _check_and_resave()


func test_day41_mender_loads() -> void:
	await _load("slot_p6_day41_mender")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [41, 420])
	assert_true(GameState.has_flag(&"roof_and_earth_complete"))
	assert_eq(_levels(), {&"crypt": 2, &"chapel": 2, &"shed": 2} as Dictionary[StringName, int])
	assert_eq(_player().inventory.count(&"coin"), 41, "≈ 41 of §2.10")
	await _check_and_resave()


func test_day37_founder_loads() -> void:
	await _load("slot_p6_day37_founder")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [37, 420])
	for flag: StringName in [&"six_pits_complete", &"names_in_stone_complete", &"roof_and_earth_complete"]:
		assert_true(GameState.has_flag(flag), String(flag))
	assert_eq(_player().inventory.count(&"coin"), 40, "≈ 40 of §2.10")
	await _check_and_resave()


func test_day37_eve_loads() -> void:
	await _load("slot_p6_day37_eve")
	assert_eq(TimeManager.day, 37)
	assert_true(TimeManager.minute_of_day >= 1200, "evening of the chapter day (%d)" % TimeManager.minute_of_day)
	assert_true(GameState.has_flag(&"roof_and_earth_complete"), "roof_and_earth just reached")
	if _has_village_node():
		# §1.2: a migrated v5 save with roof_and_earth_complete opens the village at once (W1 P3 / W2).
		assert_true(GameState.has_flag(&"village_open"), "§1.2: v5 → village_open at once")
	await _check_and_resave()


## §5.2: the corpse on the crypt table with 2 of 4 steps, the braid taken, an open cold window, the
## gravekeeper in the crypt.
func test_crypt_table_loads() -> void:
	await _load("slot_p6_crypt_table")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [36, 510])
	assert_eq(_player().interior_id, &"crypt", "in the crypt")
	var on_table := _records_at(CorpseRecord.LOCATION_TABLE)
	assert_eq(on_table.size(), 1, "corpse on the crypt table")
	if on_table.size() == 1:
		var r: CorpseRecord = on_table[0]
		assert_eq(r.room, &"crypt")
		var steps := 0
		for step: StringName in CorpseRecord.STEPS:
			if r.is_step_done(step):
				steps += 1
		assert_eq(steps, 2, "2 of 4 examination steps")
		assert_true(r.is_harvested(&"hair"), "braid taken")
		assert_true(r.cold_windows.size() >= 3 and r.cold_windows[r.cold_windows.size() - 2] == -1, "cold window open")
		assert_eq([r.hidden_cause, r.returned, r.revealed_cause], [&"", [] as Array[StringName], &""], "Phase-7 record defaults")
	await _check_and_resave()


## §5.2: carrying a corpse inside the chapel (region graveyard).
func test_chapel_carry_loads() -> void:
	await _load("slot_p6_chapel_carry")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [33, 656])
	assert_eq(_player().interior_id, &"chapel", "in the chapel")
	assert_eq(_player().region_id, &"graveyard")
	var carried := _records_at(CorpseRecord.LOCATION_CARRIED)
	assert_eq(carried.size(), 1, "a corpse is carried")
	assert_true(is_instance_valid(_player().carried), "in the gravekeeper's arms")
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase7Fixtures.install_save_v5(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _player() -> Player:
	return _world().get_player()


func _levels() -> Dictionary[StringName, int]:
	return (_world().get_node("Systems/Buildings") as Buildings).levels()


func _reinterred() -> int:
	return (_world().get_node("Systems/Ossuary") as Ossuary).reinterred().size()


func _has_village_node() -> bool:
	return not tree.get_nodes_in_group(Village.GROUP).is_empty()


func _count(state: GraveRecord.State) -> int:
	var n := 0
	for g: GraveRecord in _world().graveyard.graves():
		if g.state == state:
			n += 1
	return n


func _grave_state(id: String) -> int:
	for g: GraveRecord in _world().graveyard.graves():
		if g.id == id:
			return g.state
	return -1


## MARKED graves whose corpse was harvested.
func _robbed() -> int:
	var n := 0
	for g: GraveRecord in _world().graveyard.graves():
		var r := _world().corpse_manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if g.state == GraveRecord.State.MARKED and r != null and not r.harvested.is_empty():
			n += 1
	return n


func _records_at(location: StringName) -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for r: CorpseRecord in _world().corpse_manager.records():
		if r.location == location:
			out.append(r)
	return out


## No warning at all while loading; the next save is the current format and round-trips.
func _check_and_resave() -> void:
	assert_eq(warnings.messages, PackedStringArray(), "no warnings while loading")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "next save writes the current format")
	assert_eq(SaveFileIO.FORMAT_VERSION, 7)  # Phase 8 W0: v7
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
