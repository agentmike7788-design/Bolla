extends TestCase
## P6: SaveMigration v1 → v2 (docs/PHASE3_DESIGN.md §5.2) on the three Phase-2 fixtures
## (tests/fixtures/saves_v1/), the version chain, the "newer version" rejection and the v2
## round trip through a file. Pure data – no world (loading into the real world:
## tests/integration/test_saves_v1_load.gd).
## Phase 4 (docs/PHASE4_DESIGN.md §5.2): v2 → v3 on the four Phase-3 fixtures
## (tests/fixtures/saves_v2/) and the chain 1 → 2 → 3 on the three v1 fixtures, with the
## expected piety, dress / examination / finds, the new node states and the v3 round trip.
## Phase 5 (docs/PHASE5_DESIGN.md §5.2): v3 → v4 on the six Phase-4 fixtures (tests/fixtures/saves_v3/,
## tool belt, design {}, empty Phase-5 nodes, stats), the chain from v1/v2, the v4 round trip,
## version 5 rejected and the runtime side in SaveManager (belt fallback, absent empty nodes).
## Phase 6 (docs/PHASE6_DESIGN.md §5.2): v4 → v5 on the seven Phase-5 fixtures (tests/fixtures/saves_v4/:
## interior_id from in_interior, the new record fields, the table corpse stays on the old table,
## empty Phase-6 nodes, new stats 0, nothing else changed), the chain from v1/v2/v3, the v5 round
## trip, version 6 rejected and the absent Phase-6 nodes dropped at runtime.

## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_DIR := TestCase.user_dir("test_save_migration")
const SLOT := 3
const NEW_NODES: PackedStringArray = ["expansion", "cleanliness", "decorations", "ghosts"]
const V1_NODES: PackedStringArray = ["corpse_manager", "graveyard", "npc_carter", "res_stone", "res_wood", "hut_chest", "player"]
const V3_NODES: PackedStringArray = ["journal", "night_trade", "npc_trader"]


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

func test_current_version_is_three() -> void:
	# Phase 5 W0: v4, Phase 6 W0: v5 (docs/PHASE6_DESIGN.md §5) – the name stays for the history of this test.
	assert_eq(SaveMigration.CURRENT, 6)  # Phase 7 W0: v6
	assert_eq(SaveFileIO.FORMAT_VERSION, SaveMigration.CURRENT)


func test_unknown_or_newer_versions_are_rejected() -> void:
	var f := _fixture("slot_day3")
	for version: int in [-1, 0, SaveMigration.CURRENT + 1, 99]:
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
	# Up to v3 (Phase 5 moves the tools onto the belt in 3 → 4, tested below).
	var s := SaveMigration.migrate_2_to_3(SaveMigration.migrate_1_to_2(f.state, f.meta), f.meta)
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
		for id: String in V3_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s (chain → v3)" % [name, id])
		for id: String in SaveMigration.V4_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s (chain → v4)" % [name, id])
		for id: String in SaveMigration.V5_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s (chain → v5)" % [name, id])
		for id: String in SaveMigration.V6_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s (chain → v6)" % [name, id])
		assert_eq(s.nodes.size(), V1_NODES.size() + NEW_NODES.size() + V3_NODES.size() + SaveMigration.V4_EMPTY_NODES.size()
				+ SaveMigration.V5_EMPTY_NODES.size() + SaveMigration.V6_EMPTY_NODES.size(), name)


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
	doc.format_version = SaveFileIO.FORMAT_VERSION + 1
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


# --- Phase 4: v2 → v3 (docs/PHASE4_DESIGN.md §5.2) -------------------------------------------

## Expected per fixture: meta.day, piety (−6 × taken + 3 × left), clues rebuilt quietly with the
## number of dead that carry them.
const EXPECT_V2 := {
	"slot_p3_day5_table": {"day": 5, "piety": 6, "clues": {&"c_mark": 1, &"c_warning_letter": 1, &"c_anchor_snake": 1}},
	"slot_p3_day9_night": {"day": 9, "piety": 3, "clues": {&"c_mark": 1, &"c_warning_letter": 1, &"c_anchor_snake": 2}},
	"slot_p3_day14_complete": {"day": 14, "piety": 0, "clues": {&"c_mark": 2, &"c_warning_letter": 2, &"c_anchor_snake": 3}},
	"slot_p3_interior": {"day": 3, "piety": 3, "clues": {}},
}
const EXPECT_V1 := {
	"slot_day3": {"day": 3, "piety": 3, "clues": {&"c_mark": 1}},
	"slot_day7_complete": {"day": 7, "piety": -9, "clues": {&"c_mark": 1, &"c_warning_letter": 1, &"c_anchor_snake": 1}},
	"slot_interior": {"day": 2, "piety": 0, "clues": {}},
}
const ALL_STEPS: Array[StringName] = [&"clothing", &"hands", &"wounds", &"pockets"]


## CorpseManager double for the journal (group corpse_manager, records()).
class FakeCorpses extends Node:
	var list: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return list


## {meta, state} of a v2 fixture, decoded but not migrated.
func _fixture_v2(name: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase4Fixtures.save_v2_path(name)))
	return {"meta": doc.meta, "state": SaveFileIO.decode_state(doc.data)}


func _migrated_v2(name: String) -> Dictionary:
	var f := _fixture_v2(name)
	return SaveMigration.migrate(f.state, 2, f.meta)


func _records_of(state: Dictionary) -> Dictionary:
	var out := {}
	for r: Dictionary in state.nodes.corpse_manager.corpses:
		out[r.id] = r
	return out


## A CorpseRecord of a migrated dictionary incl. the Phase-4 fields (CorpseRecord.from_dict reads
## them once P1 has extended it; until then they are copied here).
func _record(d: Dictionary) -> CorpseRecord:
	var r := CorpseRecord.from_dict(d)
	r.finds_revealed.assign(d.get("finds_revealed", []))
	r.exam_done.assign(d.get("exam_done", []))
	r.dress = StringName(str(d.get("dress", "")))
	return r


## The journal a migrated state gets in post_load (sync_from_records over its records).
func _journal_after_load(state: Dictionary) -> JournalManager:
	var corpses := FakeCorpses.new()
	for d: Dictionary in state.nodes.corpse_manager.corpses:
		corpses.list.append(_record(d))
	tree.root.add_child(corpses)
	var j := JournalManager.new()
	j.clue_data = Phase4Fixtures.clues()
	j.insight_data = Phase4Fixtures.insights()
	j.find_data = Phase4Fixtures.finds()
	tree.root.add_child(j)
	j.load_state(state.nodes.journal)
	j.post_load()
	return j


func _check_v3(name: String, s: Dictionary, expect: Dictionary) -> void:
	var gs: Dictionary = s.autoloads.GameState
	assert_eq(gs.stats[&"piety"], expect.piety, name + ": piety from the valuables history")
	for stat: StringName in [&"utilized", &"prepared", &"trader_sales"]:
		assert_eq(gs.stats[stat], 0, "%s: %s" % [name, stat])
	assert_eq(gs.flags[&"piety_last_day"], expect.day, name + ": no recovery on the load day")
	assert_false(gs.flags.has(&"trader_known"), name + ": the note comes at the next 06:00")
	var cm: Dictionary = s.nodes.corpse_manager
	assert_eq([cm.story_delivered, cm.story_last_day, cm.stench_day], [[], 0, expect.day], name + ": corpse manager")
	for id: String in V3_NODES:
		assert_eq(s.nodes[id], {}, "%s: empty %s" % [name, id])
	for r: Dictionary in cm.corpses:
		var label := "%s/%s" % [name, r.id]
		assert_eq(r.dress, &"shroud" if r.shrouded else &"", label + " dress")
		assert_eq(r.story_id, &"", label)
		assert_eq([r.washed, r.laid_out, r.stench_noted], [false, false, false], label)
		assert_eq([r.finds_lost, r.harvested], [[], []], label)
		assert_eq(r.balm_windows, PackedInt32Array(), label)
		if r.examined:
			assert_eq(r.exam_done, ALL_STEPS, label + ": all four steps")
			assert_eq(r.traits_revealed, r.traits, label + ": every trait revealed")
			assert_eq(r.finds_revealed, SaveMigration.generic_finds(r.traits, r.cause_id), label + ": generic finds")
			assert_has(r.finds_revealed, StringName("f_cause_" + String(r.cause_id)), label + ": + cause detail")
		else:
			assert_eq([r.exam_done, r.traits_revealed, r.finds_revealed], [[], [], []], label + ": not examined")
	# The journal is rebuilt quietly from the records.
	var j := _journal_after_load(s)
	var clues := {}
	for id: StringName in j.clues():
		clues[id] = j.clue_count(id)
		assert_true(GameState.has_flag(StringName("clue_" + String(id))), "%s: flag clue_%s" % [name, id])
	assert_eq(clues, expect.clues, name + ": journal")
	assert_eq(j.unread(), [] as Array[StringName], name + ": quiet (no unread marks)")
	assert_eq(j.insights(), [] as Array[StringName], name + ": no insight linked automatically")
	j.get_parent().remove_child(j)
	j.free()
	for n: Node in tree.get_nodes_in_group(&"corpse_manager"):
		n.get_parent().remove_child(n)
		n.free()
	GameState.reset()


func test_v2_fixtures_migrate_to_v3() -> void:
	for name: String in Phase4Fixtures.SAVES_V2:
		_check_v3(name, _migrated_v2(name), EXPECT_V2[name])


func test_v1_fixtures_chain_to_v3() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		_check_v3(name, _migrated(name), EXPECT_V1[name])


func test_v2_to_v3_keeps_everything_else() -> void:
	for name: String in Phase4Fixtures.SAVES_V2:
		var f := _fixture_v2(name)
		var s := SaveMigration.migrate_2_to_3(f.state, f.meta)  # the v2 → v3 step alone
		for id: String in f.state.nodes:
			if id != "corpse_manager":
				assert_eq(s.nodes[id], f.state.nodes[id], "%s: %s unchanged (§5.2 steps 6–7)" % [name, id])
		assert_eq(s.autoloads.TimeManager, f.state.autoloads.TimeManager, name + ": clock")
		for key: Variant in f.state.autoloads.GameState.flags:
			assert_eq(s.autoloads.GameState.flags[key], f.state.autoloads.GameState.flags[key], "%s: flag %s" % [name, key])
		for key: Variant in f.state.autoloads.GameState.stats:
			assert_eq(s.autoloads.GameState.stats[key], f.state.autoloads.GameState.stats[key], "%s: stat %s" % [name, key])
		for g: Dictionary in s.nodes.graveyard.graves:
			assert_false(String(g.id).begins_with("h_"), "%s: h_01…06 stay absent → LOCKED" % name)
		var old := _records_of(f.state)
		var new := _records_of(s)
		assert_eq(new.keys(), old.keys(), name)
		for id: String in old:
			for key: Variant in old[id]:
				assert_eq(new[id][key], old[id][key], "%s/%s.%s kept" % [name, id, key])


func test_v2_fixture_details() -> void:
	var table := _records_of(_migrated_v2("slot_p3_day5_table"))
	assert_eq(table.corpse_0005.location, CorpseRecord.LOCATION_TABLE)
	assert_eq(table.corpse_0005.finds_revealed, [&"f_tattoo", &"f_cause_fever", &"f_valuables"] as Array[StringName], "step order")
	assert_eq(table.corpse_0005.dress, &"", "on the table, not dressed")
	assert_eq(table.corpse_0004.finds_revealed, [&"f_cause_fever", &"f_valuables", &"f_letter"] as Array[StringName])
	var complete := _records_of(_migrated_v2("slot_p3_day14_complete"))
	assert_eq(complete.corpse_0010.finds_revealed,
			[&"f_tattoo", &"f_mark", &"f_cause_drowned_millpond", &"f_valuables"] as Array[StringName])
	var night := _records_of(_migrated_v2("slot_p3_day9_night"))
	assert_eq(night.corpse_0009.exam_done, [] as Array[StringName], "untouched corpse on the bier")
	var interior := _records_of(_migrated_v2("slot_p3_interior"))
	assert_eq(interior.corpse_0003.location, CorpseRecord.LOCATION_GROUND)
	assert_eq(interior.corpse_0003.finds_revealed, [] as Array[StringName], "not examined yet – everything still to find")


func test_piety_is_clamped_and_reads_string_keys() -> void:
	var state := {"autoloads": {"GameState": {"stats": {"valuables_taken": 30}, "flags": {}}}, "nodes": {}}
	var gs: Dictionary = SaveMigration.migrate_2_to_3(state, {"day": 9}).autoloads.GameState
	assert_eq(gs.stats[&"piety"], -100, "clamped")
	var many: Array = []
	for i: int in 50:
		many.append({"id": "c%d" % i, "valuables_decision": "left"})
	state = {"autoloads": {"GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {"corpses": many}}}
	assert_eq(SaveMigration.migrate_2_to_3(state, {"day": 9}).autoloads.GameState.stats[&"piety"], 100)


func test_v2_to_v3_keeps_existing_phase4_fields_and_is_stable() -> void:
	var s := _migrated_v2("slot_p3_day9_night")
	assert_eq(SaveMigration.migrate_2_to_3(s, {"day": 9}), s, "a second pass changes nothing")
	var state := {"autoloads": {"GameState": {"stats": {}, "flags": {&"piety_last_day": 3}}}, "nodes": {
		"corpse_manager": {"corpses": [{"id": "x", "shrouded": true, "dress": &"gown", "examined": true, "traits": [],
				"cause_id": &"fever", "finds_revealed": [&"f_s1_page"]}]},
		"journal": {"clues": {"c_mark": {"day": 3, "corpse": "x", "count": 1}}}}}
	var out := SaveMigration.migrate_2_to_3(state, {"day": 9})
	var r: Dictionary = out.nodes.corpse_manager.corpses[0]
	assert_eq(r.dress, &"gown", "an existing dress stays")
	assert_eq(r.finds_revealed, [&"f_s1_page"], "existing finds stay")
	assert_eq(out.nodes.journal, state.nodes.journal, "an existing journal state stays")
	assert_eq(out.autoloads.GameState.flags[&"piety_last_day"], 3)


func test_damaged_v2_values_do_not_break_the_migration() -> void:
	var state := {"autoloads": {"GameState": {"stats": {"valuables_taken": "viele"}, "flags": []}, "TimeManager": 7},
		"nodes": {"corpse_manager": {"corpses": [7, "x", {"id": "y", "examined": "true", "shrouded": 1.0, "traits": {"a": 1},
				"cause_id": 3}]}}}
	var out := SaveMigration.migrate_2_to_3(state, {})
	var r: Dictionary = out.nodes.corpse_manager.corpses[2]
	assert_eq([r.dress, r.exam_done, r.finds_revealed], [&"", [], []], "only real bools count")
	assert_eq(out.autoloads.GameState.stats[&"piety"], 0)
	assert_eq(out.nodes.corpse_manager.stench_day, 1, "no day anywhere → 1")


func test_read_doc_migrates_every_v2_fixture() -> void:
	for name: String in Phase4Fixtures.SAVES_V2:
		assert_eq(Phase4Fixtures.install_save_v2(name, TEST_DIR, SLOT), OK)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, _migrated_v2(name), "%s: read_doc applies 2 → 3" % name)


func test_v3_round_trip_is_identical() -> void:
	var cases: Array = []
	for name: String in Phase4Fixtures.SAVES_V2:
		cases.append([name, _fixture_v2(name).meta, _migrated_v2(name)])
	for name: String in Phase3Fixtures.SAVES_V1:
		cases.append([name, _fixture(name).meta, _migrated(name)])
	for c: Array in cases:
		_write_doc(SaveFileIO.make_doc(c[1], c[2]))
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
		assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, c[0])
		var read := _read_slot()
		assert_eq(read.err, OK, c[0])
		assert_eq(read.state, c[2], "%s: v3 file round trip" % c[0])
		_write_doc(SaveFileIO.make_doc(read.meta, read.state))
		assert_eq(_read_slot().state, c[2], "%s: stable" % c[0])


func test_version_four_is_rejected() -> void:
	assert_eq(Phase4Fixtures.install_save_v2("slot_p3_day5_table", TEST_DIR, SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	# Phase 5 W0: "four" = the version after the current one (v5 since format v4).
	doc.format_version = SaveMigration.CURRENT + 1
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_UNRECOGNIZED)
	assert_true(SaveFileIO.is_newer_version(TEST_DIR, SLOT))
	assert_eq(SaveMigration.migrate(_fixture_v2("slot_p3_day5_table").state, SaveMigration.CURRENT + 1), {})


# --- Phase 5 (P6): v3 → v4 (docs/PHASE5_DESIGN.md §5.2) on the six Phase-4 fixtures ------------

## Per v3 fixture: tool → slot index before the migration, coins, piety, prepared, chest tools.
const EXPECT_V4 := {
	"slot_p4_day7_table": {"tools": {"shears": 2, "scrub_brush": 3, "comb": 4, "rake": 5, "pliers": 7}, "coins": 11, "piety": 10, "prepared": 3, "chest": {}},
	"slot_p4_day13_complete": {"tools": {"scrub_brush": 3, "comb": 4, "rake": 5, "shears": 6, "pliers": 7}, "coins": 55, "piety": 48, "prepared": 11, "chest": {}},
	"slot_p4_day20_reverent": {"tools": {"scrub_brush": 3, "comb": 4, "rake": 5, "shears": 6, "pliers": 7}, "coins": 125, "piety": 69, "prepared": 17, "chest": {}},
	"slot_p4_day20_mixed": {"tools": {"shears": 2, "scrub_brush": 3, "comb": 4, "rake": 5, "pliers": 7}, "coins": 123, "piety": 10, "prepared": 8, "chest": {}},
	"slot_p4_day25_harvester": {"tools": {"rake": 3, "shears": 5, "pliers": 6}, "coins": 178, "piety": -100, "prepared": 0, "chest": {}},
	"slot_p4_interior_chest_tools": {"tools": {"scrub_brush": 3, "shears": 6, "pliers": 7}, "coins": 14, "piety": 33, "prepared": 7, "chest": {"rake": 0, "comb": 1}},
}
const V4_STATS: Array[StringName] = [&"crafted", &"stones_set", &"coins_spent", &"trees_felled",
		&"coins_spent_license", &"coins_spent_build", &"coins_spent_osric", &"coins_spent_ilse"]


func _fixture_v3(name: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase5Fixtures.save_v3_path(name)))
	return {"meta": doc.meta, "state": SaveFileIO.decode_state(doc.data)}


func _migrated_v3(name: String) -> Dictionary:
	var f := _fixture_v3(name)
	return SaveMigration.migrate(f.state, 3, f.meta)


func _inv_of(state: Dictionary) -> Dictionary:
	return state.nodes.player.inventory


func _belt(state: Dictionary) -> Dictionary:
	var out := {}
	var tools: Variant = _inv_of(state).get("tools")
	if tools is Dictionary:
		for key: Variant in tools:
			out[str(key)] = tools[key]
	return out


func _slot_ids(slots: Array) -> Dictionary:
	var out := {}
	for i: int in slots.size():
		if slots[i] is Dictionary and not (slots[i] as Dictionary).is_empty():
			out[i] = str((slots[i] as Dictionary).id)
	return out


func test_v3_fixtures_migrate_to_v4_with_expected_values() -> void:
	assert_eq(EXPECT_V4.size(), Phase5Fixtures.SAVES_V3.size())
	for name: String in Phase5Fixtures.SAVES_V3:
		var before: Dictionary = _fixture_v3(name).state
		# Phase 6: the step 3 → 4 alone (the chain continues with 4 → 5, tested below).
		var f3 := _fixture_v3(name)
		var s := SaveMigration.migrate_3_to_4(f3.state, f3.meta)
		var e: Dictionary = EXPECT_V4[name]
		# 1. tools on the belt (1 each), their slots empty, all other slots at their index.
		var belt := _belt(s)
		assert_eq(belt.size(), (e.tools as Dictionary).size(), "%s: belt size" % name)
		var old_slots: Array = _inv_of(before).slots
		var new_slots: Array = _inv_of(s).slots
		assert_eq(new_slots.size(), old_slots.size(), "%s: slot count unchanged in the file (grows on load)" % name)
		for id: String in e.tools:
			assert_eq(int(belt.get(id, 0)), 1, "%s: %s on the belt" % [name, id])
			var index: int = e.tools[id]
			assert_eq(str((old_slots[index] as Dictionary).get("id")), id, "%s: %s was in slot %d" % [name, id, index])
			assert_eq(new_slots[index], {}, "%s: slot %d emptied" % [name, index])
		for i: int in old_slots.size():
			if not (e.tools as Dictionary).values().has(i):
				assert_eq(new_slots[i], old_slots[i], "%s: slot %d kept" % [name, i])
		assert_eq(_inv_of(s).currency, _inv_of(before).currency, name + ": coins")
		assert_eq(int(_inv_of(s).currency.coin), e.coins, name + ": coin value")
		# The chest has no belt.
		assert_eq(s.nodes.hut_chest, before.nodes.hut_chest, name + ": chest unchanged")
		var chest := _slot_ids(s.nodes.hut_chest.storage.slots)
		for id: String in e.chest:
			assert_eq(chest.get(e.chest[id]), id, "%s: %s stays in the chest" % [name, id])
		assert_false((s.nodes.hut_chest.storage as Dictionary).has("tools"), name + ": no chest belt")
		# 2. graves: design {}, everything else unchanged.
		var old_graves: Array = before.nodes.graveyard.graves
		var new_graves: Array = s.nodes.graveyard.graves
		assert_eq(new_graves.size(), old_graves.size(), name)
		for i: int in new_graves.size():
			var g: Dictionary = (new_graves[i] as Dictionary).duplicate()
			assert_eq(g.get("design"), {}, "%s: %s design" % [name, g.get("id")])
			g.erase("design")
			assert_eq(g, old_graves[i], "%s: grave %s unchanged" % [name, g.get("id")])
		# 3. empty Phase-5 nodes; 4. expansion as it was (bruch / quarry absent → LOCKED).
		for id: String in SaveMigration.V4_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: empty %s" % [name, id])
		assert_eq(s.nodes.expansion, before.nodes.expansion, name + ": expansion unchanged")
		# 6. stats 0, flags unchanged; 7. piety & co. unchanged.
		var stats: Dictionary = _game_state(s).stats
		for key: StringName in V4_STATS:
			assert_eq(stats.get(key), 0, "%s: stat %s" % [name, key])
		for key: Variant in _game_state(before).stats:
			assert_eq(stats[key], _game_state(before).stats[key], "%s: stat %s kept" % [name, key])
		assert_eq(int(stats.piety), e.piety, name + ": piety unchanged")
		assert_eq(int(stats.prepared), e.prepared, name + ": prepared unchanged")
		assert_eq(_game_state(s).flags, _game_state(before).flags, name + ": no new flags")
		assert_eq(s.autoloads.TimeManager, before.autoloads.TimeManager, name + ": time")
		for id: Variant in before.nodes:
			if not str(id) in ["player", "graveyard"]:
				assert_eq(s.nodes[id], before.nodes[id], "%s: %s unchanged" % [name, id])
		var player: Dictionary = (s.nodes.player as Dictionary).duplicate()
		var old_player: Dictionary = (before.nodes.player as Dictionary).duplicate()
		player.erase("inventory")
		old_player.erase("inventory")
		assert_eq(player, old_player, name + ": position, rotation, interior kept")


func test_v3_to_v4_does_not_change_its_input_and_is_stable() -> void:
	var f := _fixture_v3("slot_p4_day7_table")
	var copy: Dictionary = f.state.duplicate(true)
	var once := SaveMigration.migrate_3_to_4(f.state, f.meta)
	assert_eq(f.state, copy, "input unchanged")
	assert_eq(SaveMigration.migrate_3_to_4(once, f.meta), once, "a second run changes nothing")


func test_v3_to_v4_is_tolerant() -> void:
	var state := {"autoloads": {"GameState": {"stats": {"coins_spent": 7}, "flags": {}}}, "nodes": {
		"player": {"inventory": {"slots": [{"id": "rake", "amount": 2}, {"id": "mystery_tool", "amount": 1}, "junk", {}],
				"currency": {}, "tools": {"comb": 1}}},
		"graveyard": {"graves": [{"id": "plot_01", "design": {"shape": "stone_arch"}}, {"id": "plot_02", "design": "broken"}, 5]},
		"workshop": {"built": ["mason"]}}}
	var s := SaveMigration.migrate_3_to_4(state, {})
	var inv: Dictionary = s.nodes.player.inventory
	assert_eq(_belt(s), {"comb": 1, "rake": 1}, "existing belt kept and extended")
	assert_eq(inv.slots, [{"id": "rake", "amount": 1}, {"id": "mystery_tool", "amount": 1}, "junk", {}], "a second rake and unknown ids stay")
	assert_eq(s.nodes.graveyard.graves, [{"id": "plot_01", "design": {"shape": "stone_arch"}}, {"id": "plot_02", "design": {}}, 5])
	assert_eq(s.nodes.workshop, {"built": ["mason"]}, "an existing node state is kept")
	assert_eq([s.nodes.gathering, s.nodes.stonemasonry], [{}, {}])
	assert_eq(_game_state(s).stats.get("coins_spent"), 7, "an existing stat is kept")
	var bare := SaveMigration.migrate_3_to_4({"autoloads": {}, "nodes": {"player": {"inventory": {"slots": "x"}}}}, {})
	assert_eq(_belt(bare), {})
	assert_eq(SaveMigration.is_tool_item(&"rake"), true)
	assert_eq([SaveMigration.is_tool_item(&"linen"), SaveMigration.is_tool_item(&"nope"), SaveMigration.is_tool_item(&"")], [false, false, false])


func test_read_doc_migrates_every_v3_fixture() -> void:
	for name: String in Phase5Fixtures.SAVES_V3:
		assert_eq(Phase5Fixtures.install_save_v3(name, TEST_DIR, SLOT), OK)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, _migrated_v3(name), "%s: read_doc applies 3 → 4" % name)


func test_v2_and_v1_fixtures_chain_to_v4() -> void:
	var states: Array = []
	for name: String in Phase4Fixtures.SAVES_V2:
		states.append([name, _migrated_v2(name)])
	for name: String in Phase3Fixtures.SAVES_V1:
		states.append([name, _migrated(name)])
	assert_eq(states.size(), 7, "4 v2 + 3 v1 fixtures")
	for c: Array in states:
		var s: Dictionary = c[1]
		for id: String in SaveMigration.V4_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s" % [c[0], id])
		for key: StringName in V4_STATS:
			assert_eq(_game_state(s).stats.get(key), 0, "%s: %s" % [c[0], key])
		for g: Variant in s.nodes.graveyard.graves:
			assert_eq((g as Dictionary).get("design"), {}, "%s: design" % c[0])
		var player: Variant = s.nodes.get("player")
		if player is Dictionary and (player as Dictionary).get("inventory") is Dictionary:
			assert_true(_inv_of(s).get("tools") is Dictionary, c[0] + ": belt")


func test_v4_round_trip_is_identical() -> void:
	for name: String in Phase5Fixtures.SAVES_V3:
		var f := _fixture_v3(name)
		var migrated := _migrated_v3(name)
		_write_doc(SaveFileIO.make_doc(f.meta, migrated))
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
		assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, name)  # Phase 6: v5
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, migrated, "%s: v4 file round trip" % name)
		_write_doc(SaveFileIO.make_doc(read.meta, read.state))
		assert_eq(_read_slot().state, migrated, "%s: stable" % name)


func test_version_five_is_rejected() -> void:
	# Phase 6 W0: CURRENT 5, Phase 7 W0: 6 – the name stays; a version above CURRENT is rejected.
	assert_eq(SaveMigration.CURRENT, 6)
	assert_eq(Phase5Fixtures.install_save_v3("slot_p4_day7_table", TEST_DIR, SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	doc.format_version = SaveMigration.CURRENT + 1
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_UNRECOGNIZED)
	assert_true(SaveFileIO.is_newer_version(TEST_DIR, SLOT))


# --- runtime side of §5.2 (SaveManager) --------------------------------------------------------

func test_belt_fallback_puts_the_tools_back_into_slots() -> void:
	for name: String in Phase5Fixtures.SAVES_V3:
		var before: Dictionary = _fixture_v3(name).state
		var nodes: Dictionary = _migrated_v3(name).nodes
		var copy := nodes.duplicate(true)
		assert_true(is_same(SaveManager.with_belt_fallback(nodes, true), nodes), name + ": belt supported → unchanged")
		var back := SaveManager.with_belt_fallback(nodes, false)
		assert_eq(nodes, copy, name + ": input unchanged")
		var inv: Dictionary = back.player.inventory
		assert_false(inv.has("tools"), name + ": no belt without support")
		var tools: Dictionary = EXPECT_V4[name].tools
		var old_ids := _slot_ids(_inv_of(before).slots)
		var new_ids := _slot_ids(inv.slots)
		for id: String in tools:
			assert_eq(new_ids.values().count(id), 1, "%s: %s back in a slot" % [name, id])
		for i: Variant in old_ids:
			if not tools.has(old_ids[i]):
				assert_eq(inv.slots[i], _inv_of(before).slots[i], "%s: slot %d kept" % [name, i])
		assert_eq(new_ids.size(), old_ids.size(), name + ": nothing lost, nothing added")
	var odd := {"player": {"inventory": {"slots": [{"id": "linen", "amount": 1}], "currency": {}, "tools": {"rake": 1, "comb": 1}}}}
	var back := SaveManager.with_belt_fallback(odd, false)
	assert_eq(back.player.inventory.slots.size(), 3, "no free slot → appended (the Inventory repacks)")
	assert_eq(SaveManager.with_belt_fallback({"player": {}}, false), {"player": {}})
	assert_eq(typeof(SaveManager.belt_supported()), TYPE_BOOL)


func test_absent_phase5_nodes_are_dropped_only_when_empty() -> void:
	var nodes := {"workshop": {}, "gathering": {}, "stonemasonry": {"next_id": 2}, "journal": {}, "graveyard": {}}
	var out := SaveManager.without_absent_defaults(tree, nodes)
	assert_false(out.has("workshop") or out.has("gathering") or out.has("journal"), "empty, no such node → dropped")
	assert_eq(out.get("stonemasonry"), {"next_id": 2}, "non-empty states stay")
	assert_eq(out.get("graveyard"), {})


# --- Phase 6: v4 → v5 (docs/PHASE6_DESIGN.md §5.2) ----------------------------------------------

const V5_STATS: Array[StringName] = [&"services_held", &"devotions_held", &"bones_lifted", &"bones_reinterred", &"niche_waits"]
const V5_RECORD_KEYS: PackedStringArray = ["room", "slot_id", "cold_windows", "service_held", "service_day"]


func _fixture_v4(name: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase6Fixtures.save_v4_path(name)))
	return {"meta": doc.meta, "state": SaveFileIO.decode_state(doc.data)}


func _migrated_v4(name: String) -> Dictionary:
	var f := _fixture_v4(name)
	# Phase 7: the v4 → v5 step alone (the chain goes on to v6, tested in test_v5_fixtures_migrate_to_v6).
	return SaveMigration.migrate_4_to_5(f.state, f.meta)


func _corpses(state: Dictionary) -> Array:
	var cm: Variant = state.nodes.get("corpse_manager")
	return (cm as Dictionary).get("corpses", []) if cm is Dictionary else []


func test_v4_fixtures_migrate_to_v5() -> void:
	assert_eq(Phase6Fixtures.SAVES_V4.size(), 7, "§5.2: seven v4 fixtures")
	for name: String in Phase6Fixtures.SAVES_V4:
		var before: Dictionary = _fixture_v4(name).state
		assert_false(before.is_empty(), name + " decodes")
		var s := _migrated_v4(name)
		# 1. interior_id from in_interior; the rest of the player unchanged.
		var player: Dictionary = (s.nodes.player as Dictionary).duplicate()
		var old_player: Dictionary = before.nodes.player
		assert_eq(player.get("interior_id"), "hut" if bool(old_player.in_interior) else "", name + ": interior_id")
		player.erase("interior_id")
		assert_eq(player, old_player, name + ": player otherwise unchanged")
		# 2. every record gets the five fields with defaults; nothing else changes (location stays).
		var old_records: Array = _corpses(before)
		var new_records: Array = _corpses(s)
		assert_eq(new_records.size(), old_records.size(), name + ": records")
		for i: int in new_records.size():
			var r: Dictionary = (new_records[i] as Dictionary).duplicate()
			assert_eq([r.room, r.slot_id, r.cold_windows, r.service_held, r.service_day], ["", "", [], false, 0],
					"%s: %s Phase-6 defaults" % [name, r.id])
			for key: String in V5_RECORD_KEYS:
				if not (old_records[i] as Dictionary).has(key):
					r.erase(key)
			assert_eq(r, old_records[i], "%s: record %s otherwise unchanged" % [name, r.id])
		# 3. graves unchanged (old graves stay OLD).
		assert_eq(s.nodes.graveyard, before.nodes.graveyard, name + ": graves unchanged")
		# 4. empty Phase-6 nodes.
		for id: String in SaveMigration.V5_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: empty %s" % [name, id])
		# 6. new stats 0, no new flags, everything else unchanged.
		var stats: Dictionary = _game_state(s).stats
		for key: StringName in V5_STATS:
			assert_eq(stats.get(key), 0, "%s: stat %s" % [name, key])
		for key: Variant in _game_state(before).stats:
			assert_eq(stats[key], _game_state(before).stats[key], "%s: stat %s kept" % [name, key])
		assert_eq(_game_state(s).flags, _game_state(before).flags, name + ": no new flags")
		assert_eq(s.autoloads.TimeManager, before.autoloads.TimeManager, name + ": time")
		for id: Variant in before.nodes:
			if not str(id) in ["player", "corpse_manager"]:
				assert_eq(s.nodes[id], before.nodes[id], "%s: %s unchanged" % [name, id])
		assert_eq(s.nodes.size(), before.nodes.size() + SaveMigration.V5_EMPTY_NODES.size(), name + ": only the new nodes added")


func test_v4_table_corpse_stays_on_the_old_table() -> void:
	# §5.2 step 2: the crypt is at level 0 after the load – the corpse stays workable outside.
	var s := _migrated_v4("slot_p5_day16_table")
	var on_table: Array = []
	for r: Variant in _corpses(s):
		if str((r as Dictionary).location) == String(CorpseRecord.LOCATION_TABLE):
			on_table.append(r)
	assert_eq(on_table.size(), 1, "one corpse on the table")
	if on_table.size() == 1:
		var d: Dictionary = on_table[0]
		assert_eq([d.room, d.slot_id, d.cold_windows], ["", "", []], "outside, no niche, no cold")
		var record := CorpseRecord.from_dict(d)
		assert_eq(record.location, CorpseRecord.LOCATION_TABLE)
		assert_eq(record.room, &"")
		assert_eq(record.exam_done.size(), 2, "2 of 4 steps kept")
		assert_true(record.is_harvested(&"hair"), "braid taken")
		assert_true(record.balm_windows.size() >= 2, "juniper window kept")
	var carry := _migrated_v4("slot_p5_day16_carry")
	var carried := 0
	for r: Variant in _corpses(carry):
		if str((r as Dictionary).location) == String(CorpseRecord.LOCATION_CARRIED):
			carried += 1
			assert_eq((r as Dictionary).room, "", "carried outside")
	assert_eq(carried, 1, "the carried corpse stays carried")
	assert_eq(carry.nodes.player.interior_id, "", "outside")
	assert_eq(_migrated_v4("slot_p5_interior").nodes.player.interior_id, "hut", "§5.2 step 1: in the hut")


func test_v4_to_v5_does_not_change_its_input_and_is_stable() -> void:
	for name: String in Phase6Fixtures.SAVES_V4:
		var f := _fixture_v4(name)
		var copy: Dictionary = f.state.duplicate(true)
		var once := SaveMigration.migrate_4_to_5(f.state, f.meta)
		assert_eq(f.state, copy, name + ": input unchanged")
		assert_false(is_same(once, f.state), name + ": deep copy")
		assert_eq(SaveMigration.migrate_4_to_5(once, f.meta), once, name + ": a second run changes nothing")


func test_v4_to_v5_is_tolerant() -> void:
	var state := {"autoloads": {"GameState": {"stats": {"niche_waits": 3}, "flags": {}}}, "nodes": {
		"player": {"in_interior": "yes", "position": Vector3.ZERO},
		"corpse_manager": {"corpses": [{"id": "c1", "room": "crypt", "cold_windows": [10, -1, 500]}, "junk", 5]},
		"buildings": {"levels": {"crypt": 1}}}}
	var s := SaveMigration.migrate_4_to_5(state, {})
	assert_eq(s.nodes.player.interior_id, "", "only a real true counts as inside")
	var c1: Dictionary = s.nodes.corpse_manager.corpses[0]
	assert_eq([c1.room, c1.cold_windows, c1.slot_id, c1.service_held, c1.service_day], ["crypt", [10, -1, 500], "", false, 0],
			"existing fields kept, missing ones added")
	assert_eq((s.nodes.corpse_manager.corpses as Array).slice(1), ["junk", 5], "odd entries left alone")
	assert_eq(s.nodes.buildings, {"levels": {"crypt": 1}}, "an existing node state is kept")
	assert_eq([s.nodes.ossuary, s.nodes.chapel, s.nodes.shed_store], [{}, {}, {}])
	var stats: Dictionary = _game_state(s).stats
	assert_eq(stats.get("niche_waits", stats.get(&"niche_waits")), 3, "an existing stat is kept")
	var inside := SaveMigration.migrate_4_to_5({"autoloads": {}, "nodes": {"player": {"in_interior": true, "interior_id": "crypt"}}}, {})
	assert_eq(inside.nodes.player.interior_id, "crypt", "an existing interior_id is kept")
	var bare := SaveMigration.migrate_4_to_5({"autoloads": {}, "nodes": {}}, {})
	assert_eq((bare.nodes as Dictionary).size(), SaveMigration.V5_EMPTY_NODES.size())
	# Each record gets its own cold_windows array.
	var two := SaveMigration.migrate_4_to_5({"autoloads": {}, "nodes": {"corpse_manager": {"corpses": [{}, {}]}}}, {})
	var list: Array = two.nodes.corpse_manager.corpses
	((list[0] as Dictionary).cold_windows as Array).append(1)
	assert_eq((list[1] as Dictionary).cold_windows, [], "no shared default array")


func test_read_doc_migrates_every_v4_fixture() -> void:
	for name: String in Phase6Fixtures.SAVES_V4:
		assert_eq(Phase6Fixtures.install_save_v4(name, TEST_DIR, SLOT), OK)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		var f := _fixture_v4(name)
		assert_eq(read.state, SaveMigration.migrate(f.state, 4, f.meta), "%s: read_doc applies 4 → 5 → 6" % name)


func test_older_fixtures_chain_to_v5() -> void:
	var states: Array = []
	for name: String in Phase5Fixtures.SAVES_V3:
		states.append([name, _migrated_v3(name)])
	for name: String in Phase4Fixtures.SAVES_V2:
		states.append([name, _migrated_v2(name)])
	for name: String in Phase3Fixtures.SAVES_V1:
		states.append([name, _migrated(name)])
	assert_eq(states.size(), 13, "6 v3 + 4 v2 + 3 v1 fixtures")
	for c: Array in states:
		var s: Dictionary = c[1]
		for id: String in SaveMigration.V5_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: %s" % [c[0], id])
		for key: StringName in V5_STATS:
			assert_eq(_game_state(s).stats.get(key), 0, "%s: %s" % [c[0], key])
		var player: Dictionary = s.nodes.player
		assert_eq(player.interior_id, "hut" if player.get("in_interior") == true else "", c[0] + ": interior_id")
		for r: Variant in _corpses(s):
			for key: String in V5_RECORD_KEYS:
				assert_true((r as Dictionary).has(key), "%s: record %s" % [c[0], key])


func test_v5_round_trip_is_identical() -> void:
	for name: String in Phase6Fixtures.SAVES_V4:
		var f := _fixture_v4(name)
		var migrated := _migrated_v4(name)
		_write_doc(SaveFileIO.make_doc(f.meta, migrated))
		var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
		assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, name)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		assert_eq(read.state, migrated, "%s: v5 file round trip" % name)
		_write_doc(SaveFileIO.make_doc(read.meta, read.state))
		assert_eq(_read_slot().state, migrated, "%s: stable" % name)


func test_version_six_is_rejected() -> void:
	# Phase 7 W0: CURRENT 6 – the name stays; a version above CURRENT is rejected.
	assert_eq(SaveMigration.CURRENT, 6)
	assert_eq(Phase6Fixtures.install_save_v4("slot_p5_day30_reverent", TEST_DIR, SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_DIR, SLOT)))
	doc.format_version = SaveMigration.CURRENT + 1
	_write_doc(doc)
	assert_eq(_read_slot().err, ERR_FILE_UNRECOGNIZED)
	assert_true(SaveFileIO.is_newer_version(TEST_DIR, SLOT))


func test_absent_phase6_nodes_are_dropped_only_when_empty() -> void:
	var nodes := {"buildings": {}, "ossuary": {}, "chapel": {"services": 1}, "shed_store": {}, "graveyard": {}}
	var out := SaveManager.without_absent_defaults(tree, nodes)
	assert_false(out.has("buildings") or out.has("ossuary") or out.has("shed_store"), "empty, no such node → dropped")
	assert_eq(out.get("chapel"), {"services": 1}, "non-empty states stay")
	assert_eq(out.get("graveyard"), {})
	var b := Buildings.new()
	tree.root.add_child(b)
	var kept := SaveManager.without_absent_defaults(tree, {"buildings": {}})
	assert_eq(kept.get("buildings"), {}, "the world has the node → its empty state is loaded")
	b.free()


# --- Phase 7: v5 → v6 (docs/PHASE7_DESIGN.md §5.2, P6) --------------------------------------------

const V6_RECORD_KEYS: PackedStringArray = ["hidden_cause", "returned", "revealed_cause"]


func _fixture_v5(name: String) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phase7Fixtures.save_v5_path(name)))
	return {"meta": doc.meta, "state": SaveFileIO.decode_state(doc.data)}


func test_v5_fixtures_migrate_to_v6() -> void:
	assert_eq(Phase7Fixtures.SAVES_V5.size(), 7, "§5.2: seven v5 fixtures")
	for name: String in Phase7Fixtures.SAVES_V5:
		var f := _fixture_v5(name)
		var before: Dictionary = f.state
		assert_false(before.is_empty(), name + " decodes")
		var s := SaveMigration.migrate_5_to_6(before, f.meta)
		assert_false(is_same(s, before), "deep copy")
		# 1. region_id graveyard; interior_id and the rest unchanged.
		var player: Dictionary = (s.nodes.player as Dictionary).duplicate()
		assert_eq(player.get("region_id"), "graveyard", name + ": region")
		assert_eq(player.get("interior_id"), before.nodes.player.get("interior_id"), name + ": interior_id kept")
		player.erase("region_id")
		assert_eq(player, before.nodes.player, name + ": player otherwise unchanged (inventory slots too)")
		# 3. the three record fields; nothing else changes (the crypt table corpse stays).
		var old_records: Array = _corpses(before)
		var new_records: Array = _corpses(s)
		assert_eq(new_records.size(), old_records.size(), name + ": records")
		for i: int in new_records.size():
			var r: Dictionary = (new_records[i] as Dictionary).duplicate()
			assert_eq([r.hidden_cause, r.returned, r.revealed_cause], ["", [], ""], "%s: %s Phase-7 defaults" % [name, r.id])
			for key: String in V6_RECORD_KEYS:
				if not (old_records[i] as Dictionary).has(key):
					r.erase(key)
			assert_eq(r, old_records[i], "%s: record %s otherwise unchanged" % [name, r.id])
		# 4. graves unchanged; 5. empty Phase-7 nodes; 6. stats 0, no flags.
		assert_eq(s.nodes.graveyard, before.nodes.graveyard, name + ": graves unchanged")
		for id: String in SaveMigration.V6_EMPTY_NODES:
			assert_eq(s.nodes.get(id), {}, "%s: empty %s" % [name, id])
		var stats: Dictionary = _game_state(s).stats
		for key: StringName in SaveMigration.V6_NEW_STATS:
			assert_eq(stats.get(key), 0, "%s: stat %s" % [name, key])
		for key: Variant in _game_state(before).stats:
			assert_eq(stats[key], _game_state(before).stats[key], "%s: stat %s kept" % [name, key])
		assert_eq(_game_state(s).flags, _game_state(before).flags, name + ": no new flags")
		assert_eq(s.autoloads.TimeManager, before.autoloads.TimeManager, name + ": time")
		for id: Variant in before.nodes:
			if not str(id) in ["player", "corpse_manager"]:
				assert_eq(s.nodes[id], before.nodes[id], "%s: %s unchanged" % [name, id])
		assert_eq(s.nodes.size(), before.nodes.size() + SaveMigration.V6_EMPTY_NODES.size(), name + ": only the new nodes added")
		assert_eq(SaveMigration.migrate_5_to_6(s, f.meta), s, name + ": idempotent on its own output")


func test_read_doc_migrates_every_v5_fixture() -> void:
	for name: String in Phase7Fixtures.SAVES_V5:
		assert_eq(Phase7Fixtures.install_save_v5(name, TEST_DIR, SLOT), OK)
		var read := _read_slot()
		assert_eq(read.err, OK, name)
		var f := _fixture_v5(name)
		assert_eq(read.state, SaveMigration.migrate_5_to_6(f.state, f.meta), "%s: read_doc applies 5 → 6" % name)


func test_v6_doc_round_trip() -> void:
	var f := _fixture_v5("slot_p6_day40_reverent")
	var v6 := SaveMigration.migrate_5_to_6(f.state, f.meta)
	(v6.nodes as Dictionary)["orders"] = {"states": {"o_fenner_linden": "accepted"}, "accepted_day": {"o_fenner_linden": 40},
			"board_day": 40, "board": ["ob_wood"], "history": {}, "progress": {}}
	(v6.nodes as Dictionary)["village"] = {"open_day": 40, "goal_done": false}
	SaveFileIO.ensure_dir(TEST_DIR)
	assert_eq(SaveFileIO.write_doc(TEST_DIR, SLOT, SaveFileIO.make_doc(f.meta, v6)), OK)
	var read := _read_slot()
	assert_eq(read.err, OK)
	assert_eq(read.state, v6, "v6 → file → v6 identical (no migration)")
	assert_eq(SaveMigration.migrate(v6, 6), v6)
	assert_eq(SaveMigration.migrate(v6, 7), {}, "version 7 → refused")
	var nodes := {"village": {}, "orders": {}, "lectures": {}, "player": {}}
	var out := SaveManager.without_absent_defaults(tree, nodes)
	for id: String in ["village", "orders", "lectures"]:
		assert_false(out.has(id), "%s: an empty migrated state of an absent node is dropped" % id)
	var kept := SaveManager.without_absent_defaults(tree, {"village": {"open_day": 3}})
	assert_true(kept.has("village"), "a real state is kept")
