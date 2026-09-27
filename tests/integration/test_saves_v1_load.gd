extends TestCase
## Lead / W0 (docs/PHASE3_DESIGN.md §5.2, §12): every Phase-2 save fixture (format v1,
## tests/fixtures/saves_v1/) loads through the real SaveManager into the real world without
## engine errors, and the next save writes format v2. The v1 → v2 content migration itself
## (reputation scale, flags, LOCKED plots, empty Phase-3 node states) is P6's
## (test_save_migration.gd / test_phase2_save_upgrade.gd); this only guards that loading works.

const TIMEOUT := 120.0
const TEST_SAVES := "user://test_saves_v1"
const SLOT := 7
const RESAVE_SLOT := 8


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	_delete_saves()


func after_each() -> void:
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
	# Until P6's migration: the Phase-2 values come through unchanged (fail-safe stub).
	assert_true(GameState.has_flag(&"slice_complete") or GameState.has_flag(&"vs_finished"), "slice flag or its migration")
	await _resave_is_v2()


func test_interior_loads() -> void:
	await _load("slot_interior")
	var world := tree.current_scene as WorldRoot
	var player := world.get_player()
	assert_true(player.in_interior, "gravekeeper inside the hut")
	var chest := world.get_node("HutInterior/Entities/chest") as Chest
	assert_eq([chest.storage.count(&"wood"), chest.storage.count(&"stone"), chest.storage.count(&"linen")], [7, 3, 2])
	await _resave_is_v2()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase3Fixtures.install_save_v1(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


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
