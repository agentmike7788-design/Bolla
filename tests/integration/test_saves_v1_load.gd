extends TestCase
## Lead / W0 + P6 (docs/PHASE3_DESIGN.md §5.2, §12): every Phase-2 save fixture (format v1,
## tests/fixtures/saves_v1/) loads through the real SaveManager into the real world without
## engine errors and without "no saved state" warnings, arrives migrated (reputation scale,
## flags, LOCKED new plots once the world has them) and the next save writes format v2.
## The migration table itself: tests/unit/test_save_migration.gd.

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
const TEST_SAVES := "user://test_saves_v1"
const SLOT := 7
const RESAVE_SLOT := 8
const NEW_PLOTS: PackedStringArray = ["plot_07", "plot_08", "plot_09", "plot_10", "plot_11", "plot_12"]

var warnings: WarningLog


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	_delete_saves()
	warnings = WarningLog.new()
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	_delete_saves()


func test_fixtures_are_format_v1() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase3Fixtures.save_v1_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 1, name)
			assert_eq(String(doc.meta.game_version), "0.2.0-phase2", name + " written by the Phase-2 build")


func test_slot_info_reads_v1() -> void:
	assert_eq(Phase3Fixtures.install_save_v1("slot_day3", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v1 slot listed")
	assert_eq([info.day, info.minute_of_day], [3, 560])


func test_day3_loads() -> void:
	await _load("slot_day3")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [3, 560])
	var graveyard := _graveyard()
	assert_eq(graveyard.get_grave("plot_01").state, GraveRecord.State.MARKED)
	assert_eq(graveyard.get_grave("plot_02").state, GraveRecord.State.MARKED)
	assert_eq(graveyard.get_grave("plot_03").state, GraveRecord.State.DUG, "open grave")
	var on_table := 0
	for r: CorpseRecord in (tree.current_scene as WorldRoot).corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			on_table += 1
	assert_eq(on_table, 1, "corpse on the table")
	assert_eq(GameState.get_stat(&"reputation"), 40, "v1 0 → 40 'Geachtet'")
	assert_false(GameState.has_flag(&"vs_finished"))
	assert_eq(GameState.get_flag(&"rep_last_day"), 3, "no second drift on the load day")
	_check_migrated_world()
	await _resave_is_v2()


func test_day7_complete_loads() -> void:
	await _load("slot_day7_complete")
	assert_eq(TimeManager.day, 7)
	var marked := 0
	for g: GraveRecord in _graveyard().graves():
		if g.state == GraveRecord.State.MARKED:
			marked += 1
	assert_eq(marked, 6)
	assert_eq(GameState.get_stat(&"burials"), 6)
	assert_false(GameState.has_flag(&"slice_complete"), "slice_complete no longer stops deliveries")
	assert_true(GameState.get_flag(&"vs_finished"), "migrated to vs_finished")
	assert_eq(GameState.get_stat(&"reputation"), 22, "v1 −2 → 22 'Unauffällig'")
	assert_eq(GameState.get_flag(&"rep_last_day"), 7)
	_check_migrated_world()
	await _resave_is_v2()


func test_interior_loads() -> void:
	await _load("slot_interior")
	var world := tree.current_scene as WorldRoot
	var player := world.get_player()
	assert_true(player.in_interior, "gravekeeper inside the hut")
	var chest := world.get_node("HutInterior/Entities/chest") as Chest
	assert_eq([chest.storage.count(&"wood"), chest.storage.count(&"stone"), chest.storage.count(&"linen")], [7, 3, 2])
	assert_eq(GameState.get_stat(&"reputation"), 40)
	_check_migrated_world()
	await _resave_is_v2()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase3Fixtures.install_save_v1(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


## After loading a v1 save: no system node fell back to its default with a warning, every new
## plot the world has is LOCKED (§5.2 step 5), and the migrated graves keep their states.
func _check_migrated_world() -> void:
	assert_eq(warnings.containing("no saved state"), PackedStringArray(), "every saveable got a state")
	var graveyard := _graveyard()
	for id: String in NEW_PLOTS:
		var grave := graveyard.get_grave(id)
		if grave != null:
			assert_eq(grave.state, GraveRecord.State.LOCKED, id + " locked after a v1 load")
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			assert_eq(g.completed_day, 0, g.id + ": ghost from the first night on")


func _graveyard() -> Graveyard:
	return (tree.current_scene as WorldRoot).graveyard


func _resave_is_v2() -> void:
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), 2, "next save writes v2")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v2 round trip")


func _delete_saves() -> void:
	if SaveManager.save_dir != TEST_SAVES:
		return
	for slot: int in [SLOT, RESAVE_SLOT]:
		SaveManager.delete_save(slot)
