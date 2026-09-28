extends TestCase
## Lead / W0 (docs/PHASE5_DESIGN.md §5.2, §12): every Phase-4 save fixture (format v3,
## tests/fixtures/saves_v3/) loads through the real SaveManager into the real world without
## engine errors and without any warning, keeps its Phase-4 state, and the next save writes the
## current format (round trip identical). W0: migrate_3_to_4 is the identity; P6 adds the §5.2
## assertions (tool belt, design {}, empty Phase-5 nodes) in test_save_migration.gd and
## tests/integration/test_phase4_save_upgrade.gd. Checks here stay valid after P3/P6 (tools are
## counted, not looked up in slots).

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


const TIMEOUT := 180.0
## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_SAVES := TestCase.user_dir("test_saves_v3")
const SLOT := 7
const RESAVE_SLOT := 8
## Phase-4 tools that were in inventory slots at save time.
const TOOLS: Array[StringName] = [&"scrub_brush", &"comb", &"rake", &"shears", &"pliers"]

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


func test_fixtures_are_format_v3() -> void:
	assert_eq(Phase5Fixtures.SAVES_V3.size(), 6, "§5.2: six v3 fixtures")
	for name: String in Phase5Fixtures.SAVES_V3:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase5Fixtures.save_v3_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 3, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v3() -> void:
	assert_eq(Phase5Fixtures.install_save_v3("slot_p4_day20_reverent", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v3 slot listed")
	assert_eq([info.day, info.minute_of_day], [20, 420])


func test_day7_table_loads() -> void:
	await _load("slot_p4_day7_table")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [7, 600])
	var on_table := _records_at(CorpseRecord.LOCATION_TABLE)
	assert_eq(on_table.size(), 1, "corpse on the table")
	if on_table.size() == 1:
		var r: CorpseRecord = on_table[0]
		var steps := 0
		for step: StringName in CorpseRecord.STEPS:
			if r.is_step_done(step):
				steps += 1
		assert_eq(steps, 2, "2 of 4 examination steps")
		assert_true(r.is_harvested(&"hair"), "braid taken")
		var now := TimeManager.total_minutes()
		assert_true(r.balm_windows.size() >= 2 and r.balm_windows[0] <= now and now < r.balm_windows[1], "juniper window running")
	var inv := _player().inventory
	for id: StringName in TOOLS:
		assert_eq(inv.count(id), 1, "%s kept" % id)
	await _check_and_resave()


func test_day13_complete_loads() -> void:
	await _load("slot_p4_day13_complete")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [13, 540])
	assert_true(GameState.has_flag(&"cemetery_complete"), "Phase 5 unlocks from here")
	assert_false(GameState.has_flag(&"six_pits_complete"))
	assert_true(_expansion().is_unlocked(&"elder"), "Holunderwinkel open")
	assert_eq(_marked(), 12, "deliveries still running")
	await _check_and_resave()


func test_day20_reverent_loads() -> void:
	await _load("slot_p4_day20_reverent")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [20, 420])
	assert_true(GameState.has_flag(&"six_pits_complete"))
	assert_eq(_marked(), 18)
	assert_eq(GameState.get_stat(&"reputation"), 100)
	assert_eq(_player().inventory.count(&"coin"), 125, "≈ 121 of §2.8 (measured 125 at 07:00)")
	await _check_and_resave()


func test_day20_mixed_loads() -> void:
	await _load("slot_p4_day20_mixed")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [20, 420])
	assert_true(GameState.has_flag(&"six_pits_complete"))
	assert_eq(_marked(), 18)
	var world := tree.current_scene as WorldRoot
	var ghosts := world.get_node("Systems/Ghosts") as GhostManager
	var robbed_restless := 0
	for g: GraveRecord in world.graveyard.graves():
		var r := world.corpse_manager.get_record(g.corpse_id)
		if g.state == GraveRecord.State.MARKED and r != null and not r.harvested.is_empty() \
				and StringName(str(ghosts.mood_info(g.id).get("mood", ""))) == GhostMood.RESTLESS:
			robbed_restless += 1
	assert_true(robbed_restless > 0, "robbed graves with restless ghosts (%d)" % robbed_restless)
	await _check_and_resave()


func test_day25_harvester_loads() -> void:
	await _load("slot_p4_day25_harvester")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [25, 420])
	assert_true(GameState.has_flag(&"six_pits_complete"))
	assert_eq(_player().inventory.count(&"coin"), 178, "≈ 179 of §2.8")
	await _check_and_resave()


func test_interior_chest_tools_loads() -> void:
	await _load("slot_p4_interior_chest_tools")
	var world := tree.current_scene as WorldRoot
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [9, 1200])
	assert_true(_player().in_interior, "gravekeeper inside the hut")
	var chest := world.get_node("HutInterior/Entities/chest") as Chest
	assert_eq([chest.storage.count(&"rake"), chest.storage.count(&"comb")], [1, 1], "tools in the chest")
	assert_eq([_player().inventory.count(&"pliers"), _player().inventory.count(&"rake")], [1, 0])
	var decor := world.get_node("Systems/Decorations") as DecorationManager
	var ids: Array[StringName] = []
	for p: DecorPlacement in decor.placements():
		var c := decor.centre_of(p)
		if c.distance_to(Vector2(-8.6, -1.3)) < 2.5 or c.distance_to(Vector2(-0.5, -10.6)) < 2.5:
			ids.append(p.decor_id)
	# W-Welt (W2): pieces on the built workyard are cleared into the hut chest on this first load
	# (§5.2 step 5, Workshop.workyard_rects) – each of the two is either still placed or in the chest.
	for id: StringName in [&"decor_bench_wood", &"decor_grave_vase"]:
		assert_true(ids.has(id) or chest.storage.count(id) > 0, "%s placed or in the chest (%s)" % [id, str(ids)])
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase5Fixtures.install_save_v3(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _player() -> Player:
	return (tree.current_scene as WorldRoot).get_player()


func _expansion() -> ExpansionManager:
	return (tree.current_scene as WorldRoot).get_node("Systems/Expansion") as ExpansionManager


func _marked() -> int:
	var n := 0
	for g: GraveRecord in (tree.current_scene as WorldRoot).graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			n += 1
	return n


func _records_at(location: StringName) -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for r: CorpseRecord in (tree.current_scene as WorldRoot).corpse_manager.records():
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
