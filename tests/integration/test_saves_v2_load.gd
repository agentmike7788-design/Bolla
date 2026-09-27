extends TestCase
## Lead / W0 + P6 (docs/PHASE4_DESIGN.md §5.2, §12): every Phase-3 save fixture (format v2,
## tests/fixtures/saves_v2/) loads through the real SaveManager into the real world without
## engine errors and without "no saved state" warnings, keeps its Phase-3 state, and the next
## save writes format v3 (round trip identical). W0: migrate_2_to_3 is the identity; P6 adds the
## §5.2 assertions (piety from history, dress / exam_done / finds, journal) in
## tests/integration/test_phase3_save_upgrade.gd and test_save_migration.gd.

## Records push_warning() messages (warnings never fail a test on their own).
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

	func containing(text: String) -> PackedStringArray:
		_mutex.lock()
		var out: PackedStringArray = []
		for m: String in messages:
			if m.contains(text):
				out.append(m)
		_mutex.unlock()
		return out


const TIMEOUT := 120.0
## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_SAVES := TestCase.user_dir("test_saves_v2")
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
	_delete_saves()
	TestCase.remove_user_dir(TEST_SAVES)


func test_fixtures_are_format_v2() -> void:
	for name: String in Phase4Fixtures.SAVES_V2:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase4Fixtures.save_v2_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 2, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v2() -> void:
	assert_eq(Phase4Fixtures.install_save_v2("slot_p3_day9_night", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v2 slot listed")
	assert_eq([info.day, info.minute_of_day], [9, 1410])


func test_day5_table_loads() -> void:
	await _load("slot_p3_day5_table")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [5, 540])
	var world := tree.current_scene as WorldRoot
	var on_table := _records_at(CorpseRecord.LOCATION_TABLE)
	assert_eq(on_table.size(), 1, "corpse on the table")
	if on_table.size() == 1:
		var r: CorpseRecord = on_table[0]
		assert_true(r.examined and r.has_trait(&"tattoo") and r.has_trait(&"valuables"))
		assert_true(r.needs_valuables_decision(), "valuables decision still open")
		assert_false(r.shrouded)
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	assert_true(expansion.is_unlocked(&"east"), "Ostwiese cleared")
	assert_true((world.get_node("Systems/Decorations") as DecorationManager).placements().size() > 0, "decor placed")
	assert_true((world.get_node("Systems/Cleanliness") as CleanlinessManager).dirty_count() >= 0)
	assert_eq(GameState.get_stat(&"reputation"), 43)
	await _check_and_resave()


func test_day9_night_loads() -> void:
	await _load("slot_p3_day9_night")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [9, 1410])
	var bier := _records_at(CorpseRecord.LOCATION_DROPOFF)
	assert_eq(bier.size(), 1, "untouched corpse on the bier")
	if bier.size() == 1:
		assert_false((bier[0] as CorpseRecord).examined)
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)
	var ghosts := (tree.current_scene as WorldRoot).get_node("Systems/Ghosts") as GhostManager
	assert_true(ghosts.is_ghost_time(TimeManager.minute_of_day), "ghost night")
	assert_false(ghosts.eligible_graves().is_empty(), "ghosts walk")
	await _check_and_resave()


func test_day14_complete_loads() -> void:
	await _load("slot_p3_day14_complete")
	assert_eq(TimeManager.day, 14)
	assert_true(GameState.has_flag(&"cemetery_complete"))
	var marked := 0
	for g: GraveRecord in (tree.current_scene as WorldRoot).graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			marked += 1
	assert_eq(marked, 12)
	assert_eq(GameState.get_stat(&"valuables_taken"), 2)
	var buried := {}
	for r: CorpseRecord in _records_at(CorpseRecord.LOCATION_BURIED):
		for t: StringName in r.traits:
			buried[t] = true
	for t: StringName in [&"strange_wound", &"letter", &"tattoo"]:
		assert_true(buried.has(t), "%s buried" % t)
	await _check_and_resave()


func test_interior_loads() -> void:
	await _load("slot_p3_interior")
	var world := tree.current_scene as WorldRoot
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [3, 1170])
	assert_true(world.get_player().in_interior, "gravekeeper inside the hut")
	assert_eq(_records_at(CorpseRecord.LOCATION_GROUND).size(), 1, "corpse on the ground in front of the table")
	var chest := world.get_node("HutInterior/Entities/chest") as Chest
	assert_eq([chest.storage.count(&"wood"), chest.storage.count(&"stone"), chest.storage.count(&"linen")], [6, 4, 2])
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase4Fixtures.install_save_v2(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _records_at(location: StringName) -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for r: CorpseRecord in (tree.current_scene as WorldRoot).corpse_manager.records():
		if r.location == location:
			out.append(r)
	return out


## No saveable fell back to its default with a warning; the next save is v3 and round-trips.
func _check_and_resave() -> void:
	assert_eq(warnings.containing("no saved state"), PackedStringArray(), "every saveable got a state")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), 3, "next save writes v3")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v3 round trip")


func _delete_saves() -> void:
	if SaveManager.save_dir != TEST_SAVES:
		return
	for slot: int in [SLOT, RESAVE_SLOT]:
		SaveManager.delete_save(slot)
