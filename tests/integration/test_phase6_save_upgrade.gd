extends TestCase
## P6 (docs/PHASE7_DESIGN.md §5.2, §10): Phase-6 saves (format v5, tests/fixtures/saves_v5/) in the
## Phase-7 build, through the real SaveManager into the real world.
## - slot_p6_crypt_table: the corpse on the crypt table keeps its two steps, the braid stays taken,
##   the Phase-7 record fields are at their defaults; the specimen card stays hidden until
##   anatomy_known. (The heart on top of the braid – quality −1 −2 – runs once P4's CorpseCare is merged,
##   see _organs_ready.)
## - slot_p6_chapel_carry: the gravekeeper carries a corpse in the chapel, region graveyard; the service
##   is still possible.
## Both resave as v6 and round-trip.

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

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := messages.duplicate()
		messages.clear()
		_mutex.unlock()
		return out


const SLOT := 5
const RESAVE_SLOT := 6

var saves_dir := TestCase.user_dir("test_phase6_save_upgrade")
var warnings: WarningLog
var world: WorldRoot


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	warnings = WarningLog.new()
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)
	GameState.clear_flag(&"anatomy_known")


func test_crypt_table_corpse_keeps_its_state() -> void:
	await _load("slot_p6_crypt_table")
	if world == null:
		return
	var player := world.get_player()
	assert_eq([player.interior_id, player.region_id], [&"crypt", &"graveyard"], "in the crypt, graveyard region")
	var record: CorpseRecord = null
	for r: CorpseRecord in world.corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			record = r
	assert_not_null(record, "the corpse on the crypt table")
	if record == null:
		return
	assert_eq([record.room, record.exam_done.size()], [&"crypt", 2], "2 of 4 steps in the crypt")
	assert_true(record.is_harvested(&"hair"), "the braid stays taken")
	assert_eq([record.hidden_cause, record.returned, record.revealed_cause], [&"", [] as Array[StringName], &""], "§5.2 step 3")
	var care := world.get_node_or_null("Systems/CorpseCare")
	if care != null and care.has_method(&"organ_block_reason"):
		GameState.clear_flag(&"anatomy_known")
		var inv := player.inventory
		assert_eq(str(care.call(&"organ_block_reason", record.id, &"heart", &"jar", inv)), "-", "no specimen card before anatomy_known")
	await _resave_round_trip()


func test_chapel_carry_stays_in_the_chapel() -> void:
	await _load("slot_p6_chapel_carry")
	if world == null:
		return
	var player := world.get_player()
	assert_eq([player.interior_id, player.region_id], [&"chapel", &"graveyard"])
	var carried := 0
	for r: CorpseRecord in world.corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_CARRIED:
			carried += 1
			assert_eq([r.hidden_cause, r.returned], [&"", [] as Array[StringName]], r.id)
	assert_eq(carried, 1, "the corpse in his arms")
	assert_false(GameState.has_flag(&"village_open"), "Phase 6 not complete in this save – no village")
	await _resave_round_trip()


func _load(name: String) -> void:
	assert_eq(Phase7Fixtures.install_save_v5(name, saves_dir, SLOT), OK)
	warnings.take()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	TimeManager.running = false
	assert_eq(warnings.take(), PackedStringArray(), name + " loads without warnings")


## The next save is v6 with the Phase-7 stats and record fields, and round-trips.
func _resave_round_trip() -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	for key: StringName in SaveMigration.V6_NEW_STATS:
		assert_true((before.autoloads.GameState.stats as Dictionary).has(key), "stat %s" % key)
	for r: Variant in (before.nodes.corpse_manager as Dictionary).corpses:
		for key: String in ["hidden_cause", "returned", "revealed_cause"]:
			assert_true((r as Dictionary).has(key), "record saves %s" % key)
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "the current format (Phase 7: v6, Phase 8: v7)")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v6 round trip")
	assert_eq(warnings.take(), PackedStringArray(), "the v6 file loads quietly")
