extends TestCase
## P6: SaveMigration v1 → v2 (docs/PHASE3_DESIGN.md §5.2) on the three Phase-2 fixtures
## (tests/fixtures/saves_v1/), the version chain, the "newer version" rejection and the v2
## round trip through a file. Pure data – no world (loading into the real world:
## tests/integration/test_saves_v1_load.gd).

const TEST_DIR := "user://test_save_migration"
const SLOT := 3
const NEW_NODES: PackedStringArray = ["expansion", "cleanliness", "decorations", "ghosts"]
const V1_NODES: PackedStringArray = ["corpse_manager", "graveyard", "npc_carter", "res_stone", "res_wood", "hut_chest", "player"]


func before_each() -> void:
	_remove_test_dir()


func after_each() -> void:
	_remove_test_dir()


# --- helpers ----------------------------------------------------------------------------------

## {meta, state} of a v1 fixture, decoded but not migrated.
func _fixture(name: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase3Fixtures.save_v1_path(name)))
	return {"meta": doc.meta, "state": SaveFileIO.decode_state(doc.data)}


func _migrated(name: String) -> Dictionary:
	var f := _fixture(name)
	return SaveMigration.migrate(f.state, 1, f.meta)


func _game_state(state: Dictionary) -> Dictionary:
	return state.autoloads.GameState


func _graves(state: Dictionary) -> Dictionary:
	var out := {}
	for g: Dictionary in state.nodes.graveyard.graves:
		out[g.id] = g
	return out


## Reads slot SLOT through SaveFileIO.read_doc into {meta, state} (err in "err").
func _read_slot() -> Dictionary:
	var out := {}
	out["err"] = SaveFileIO.read_doc(TEST_DIR, SLOT, out)
	return out


func _write_doc(doc: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(SaveFileIO.slot_path(TEST_DIR, SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, "\t", true, true))
	file.close()


func _remove_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_DIR)


# --- reputation formula -----------------------------------------------------------------------

func test_reputation_table() -> void:
	var table := {0: 40, -1: 31, -2: 22, -3: 13, -4: 4, -5: 0, -9: 0, 1: 49, 6: 94, 7: 100, 20: 100}
	for old: int in table:
		assert_eq(SaveMigration.reputation_v1_to_v2(old), table[old], "v1 reputation %d" % old)


# --- version chain ----------------------------------------------------------------------------

func test_current_version_is_two() -> void:
	assert_eq(SaveMigration.CURRENT, 2)
	assert_eq(SaveFileIO.FORMAT_VERSION, SaveMigration.CURRENT)


func test_unknown_or_newer_versions_are_rejected() -> void:
	var f := _fixture("slot_day3")
	for version: int in [-1, 0, 3, 99]:
		assert_eq(SaveMigration.migrate(f.state, version, f.meta), {}, "version %d" % version)


func test_malformed_state_is_rejected() -> void:
	assert_eq(SaveMigration.migrate({}, 1, {"day": 1}), {})
	assert_eq(SaveMigration.migrate({"autoloads": {}}, 1, {"day": 1}), {})
	assert_eq(SaveMigration.migrate({"autoloads": [], "nodes": {}}, 1, {"day": 1}), {})


func test_current_version_passes_unchanged() -> void:
	var v2 := _migrated("slot_day7_complete")
	assert_eq(SaveMigration.migrate(v2, 2, {"day": 7}), v2, "v2 is not migrated again")


func test_migration_does_not_change_its_input() -> void:
	var f := _fixture("slot_day7_complete")
	var before: Dictionary = (f.state as Dictionary).duplicate(true)
	SaveMigration.migrate(f.state, 1, f.meta)
	assert_eq(f.state, before)


# --- the three fixtures -----------------------------------------------------------------------

func test_day3_values() -> void:
	var s := _migrated("slot_day3")
	var gs := _game_state(s)
	assert_eq(gs.stats[&"reputation"], 40, "0 → 40 'Geachtet'")
	assert_eq(gs.stats[&"burials"], 2, "other stats unchanged")
	assert_false(gs.flags.has(&"vs_finished"), "slice not finished")
	assert_false(gs.flags.has(&"slice_complete"))
	assert_eq(gs.flags[&"rep_last_day"], 3, "rep_last_day = meta.day")
	var graves := _graves(s)
	assert_eq(graves.plot_01.state, GraveRecord.State.MARKED)
	assert_eq(graves.plot_03.state, GraveRecord.State.DUG, "open grave stays open")
	for id: String in graves:
		assert_eq(graves[id].completed_day, 0, id)
	assert_eq(s.nodes.corpse_manager.last_delivery_ids, ["corpse_0003"])
	assert_eq(s.nodes.corpse_manager.last_delivery_id, "corpse_0003", "v1 field kept as fallback")


func test_day7_complete_values() -> void:
	var s := _migrated("slot_day7_complete")
	var gs := _game_state(s)
	assert_eq(gs.stats[&"reputation"], 22, "−2 → 22 'Unauffällig'")
	assert_eq(gs.stats[&"valuables_taken"], 2)
	assert_false(gs.flags.has(&"slice_complete"), "slice_complete removed – deliveries resume")
	assert_false(gs.flags.has("slice_complete"))
	assert_eq(gs.flags[&"vs_finished"], true)
	assert_eq(gs.flags[&"rep_last_day"], 7)
	var marked := 0
	for g: Dictionary in s.nodes.graveyard.graves:
		if g.state == GraveRecord.State.MARKED:
			marked += 1
			assert_eq(g.completed_day, 0, "%s: ghost from the first night on" % g.id)
	assert_eq(marked, 6)
	assert_eq(s.nodes.corpse_manager.last_delivery_ids, [], "empty v1 id → empty list")


func test_interior_values() -> void:
	var f := _fixture("slot_interior")
	var s := _migrated("slot_interior")
	assert_eq(_game_state(s).stats[&"reputation"], 40)
	assert_eq(_game_state(s).flags[&"rep_last_day"], 2)
	assert_eq(s.nodes.corpse_manager.last_delivery_ids, ["corpse_0002"], "corpse on the bier")
	for id: String in ["player", "hut_chest", "res_wood", "res_stone", "npc_carter"]:
		assert_eq(s.nodes[id], f.state.nodes[id], "%s unchanged (§5.2 step 7)" % id)
	assert_eq(s.autoloads.TimeManager, f.state.autoloads.TimeManager, "clock unchanged")
	assert_eq(s.nodes.player.in_interior, true)


func test_new_nodes_get_empty_states() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		var s := _migrated(name)
		for id: String in NEW_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s" % [name, id])
		for id: String in V1_NODES:
			assert_true(s.nodes.has(id), "%s keeps %s" % [name, id])
		assert_eq(s.nodes.size(), V1_NODES.size() + NEW_NODES.size(), name)


func test_new_plots_stay_absent() -> void:
	# §5.2 step 5: plot_07…12 are not written – Graveyard.load_state creates them LOCKED.
	for name: String in Phase3Fixtures.SAVES_V1:
		var graves := _graves(_migrated(name))
		for i: int in range(7, 13):
			assert_false(graves.has("plot_%02d" % i), "%s: plot_%02d" % [name, i])
		assert_eq(graves.size(), _graves(_fixture(name).state).size(), name)


func test_existing_node_states_are_kept() -> void:
	var f := _fixture("slot_day3")
	var state: Dictionary = (f.state as Dictionary).duplicate(true)
	state.nodes["ghosts"] = {"gifts": {"plot_01": 2}, "heard": {}}
	var flags: Dictionary = state.autoloads.GameState.flags
	flags[&"rep_last_day"] = 1
	var s := SaveMigration.migrate(state, 1, f.meta)
	assert_eq(s.nodes.ghosts, {"gifts": {"plot_01": 2}, "heard": {}}, "an existing state is not replaced")
	assert_eq(s.autoloads.GameState.flags[&"rep_last_day"], 1)


func test_missing_parts_get_defaults() -> void:
	var s := SaveMigration.migrate({"autoloads": {}, "nodes": {}}, 1, {"day": 4})
	assert_eq(s.autoloads.GameState.stats[&"reputation"], 40, "missing v1 reputation = 0 → 40")
	assert_eq(s.autoloads.GameState.flags[&"rep_last_day"], 4)
	for id: String in NEW_NODES:
		assert_eq(s.nodes[id], {})
	var no_meta := SaveMigration.migrate({"autoloads": {"TimeManager": {"day": 5}}, "nodes": {}}, 1)
	assert_eq(no_meta.autoloads.GameState.flags[&"rep_last_day"], 5, "falls back to the saved clock")


func test_string_keys_from_foreign_files() -> void:
	var state := {"autoloads": {"GameState": {"flags": {"slice_complete": true}, "stats": {"reputation": -3}}}, "nodes": {}}
	var gs: Dictionary = SaveMigration.migrate(state, 1, {"day": 2}).autoloads.GameState
	assert_eq(gs.stats[&"reputation"], 13, "−3 → 13 'Verrufen'")
	assert_false(gs.flags.has("slice_complete") or gs.flags.has(&"slice_complete"))
	assert_eq(gs.flags[&"vs_finished"], true)


func test_false_slice_flag_does_not_finish() -> void:
	var state := {"autoloads": {"GameState": {"flags": {&"slice_complete": false}, "stats": {}}}, "nodes": {}}
	var gs: Dictionary = SaveMigration.migrate(state, 1, {"day": 2}).autoloads.GameState
	assert_false(gs.flags.has(&"slice_complete"))
	assert_false(gs.flags.has(&"vs_finished"))


# --- through SaveFileIO -----------------------------------------------------------------------

func test_read_doc_migrates_every_fixture() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		assert_eq(Phase3Fixtures.install_save_v1(name, TEST_DIR, SLOT), OK)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, _migrated(name), "%s: read_doc applies the migration" % name)


func test_v2_round_trip_is_identical() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		var f := _fixture(name)
		var migrated := _migrated(name)
		_write_doc(SaveFileIO.make_doc(f.meta, migrated))
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, migrated, "%s: v2 file round trip" % name)
		assert_eq(read.meta, f.meta, name)
		# A second pass through the file changes nothing either.
		_write_doc(SaveFileIO.make_doc(read.meta, read.state))
		assert_eq(_read_slot().state, migrated, "%s: stable" % name)


func test_newer_version_file_is_rejected() -> void:
	assert_eq(Phase3Fixtures.install_save_v1("slot_day3", TEST_DIR, SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	doc.format_version = 3
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_UNRECOGNIZED)
	assert_true(SaveFileIO.is_newer_version(TEST_DIR, SLOT))
	SaveManager.save_dir = TEST_DIR
	assert_false(SaveManager.get_slot_info(SLOT).exists, "not offered as a slot")


func test_unknown_versions_are_not_newer() -> void:
	assert_false(SaveFileIO.is_newer_version(TEST_DIR, SLOT), "no file")
	assert_eq(Phase3Fixtures.install_save_v1("slot_day3", TEST_DIR, SLOT), OK)
	assert_false(SaveFileIO.is_newer_version(TEST_DIR, SLOT), "v1")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	for version: Variant in [0, 2.5, "3", null]:
		doc.format_version = version
		_write_doc(doc)
		assert_eq(_read_slot().err, ERR_FILE_UNRECOGNIZED, str(version))
		assert_false(SaveFileIO.is_newer_version(TEST_DIR, SLOT), str(version))


func test_corrupt_v1_data_is_rejected() -> void:
	assert_eq(Phase3Fixtures.install_save_v1("slot_day3", TEST_DIR, SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	doc.data = {"type": "Dictionary", "args": ["s:autoloads"]}
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_CORRUPT)
	doc.data = JSON.from_native({"autoloads": {}})
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_CORRUPT, "no nodes part")
	_write_doc({"format_version": 1, "meta": doc.meta})
	assert_eq(_read_slot().err, ERR_FILE_CORRUPT, "no data at all")
