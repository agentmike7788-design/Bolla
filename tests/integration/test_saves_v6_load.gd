extends TestCase
## Lead / W0 (docs/PHASE8_DESIGN.md §5.2, §12): every Phase-7 save fixture (format v6,
## tests/fixtures/saves_v6/) loads through the real SaveManager into the real world without engine
## errors and without any warning, keeps its Phase-7 state, and the next save writes the current format
## (round trip identical). W0: migrate_6_to_7 is the identity; P6 adds the §5.2 assertions (kin_house,
## grave fields, empty Phase-8 nodes) in test_save_migration.gd and
## tests/integration/test_phase7_save_upgrade.gd. The checks here stay valid after W1/W2 (v6 saves with
## name_in_village_complete open Phase 8 at once – NpcLife.post_load, §1.2).

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
var TEST_SAVES := TestCase.user_dir("test_saves_v6")
const SLOT := 7
const RESAVE_SLOT := 8
const BUILDINGS_P7 := {&"crypt": 3, &"chapel": 3, &"shed": 2}
## W0 finding (W0-Notizen 12, Phase-7 bug), fixed by P4: Orders.turn_in hands a specimen over with
## Specimens.consume(uid, inv, &"lectured") (the cabinet); Orders.post_load repairs the fixture state
## (the heart jar sp_0001 stayed „held“ without a slot) – the load is warning-free.

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


func test_fixtures_are_format_v6() -> void:
	assert_eq(Phase8Fixtures.SAVES_V6.size(), 6, "§5.2: six v6 fixtures")
	for name: String in Phase8Fixtures.SAVES_V6:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase8Fixtures.save_v6_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 6, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v6() -> void:
	assert_eq(Phase8Fixtures.install_save_v6("slot_p7_day53_neighbor", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v6 slot listed")
	assert_eq([info.day, info.minute_of_day], [53, 420])


## §1.4 A / §2.10: the reference start of Phase 8 (neighbor7 end, 07:00 day 53).
func test_day53_neighbor_loads() -> void:
	await _load("slot_p7_day53_neighbor")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [53, 420])
	assert_true(GameState.has_flag(&"name_in_village_complete"), "Phase 8 opens from here")
	assert_eq(_levels(), BUILDINGS_P7 as Dictionary[StringName, int], "crypt 3 · chapel 3 · shed 2")
	assert_eq(_free_in(&"linden"), 0, "§1.4: the Lindenacker full")
	assert_eq(_count(GraveRecord.State.MARKED), 32)
	assert_eq(_trusted(), 8, "§1.4: all eight „Vertraut“ (Wiebke Hagedorn's value stays)")
	assert_eq(GameState.get_stat(&"reputation"), 100)
	assert_eq(_player().inventory.count(&"coin"), 48, "W0-Notizen: measured 48 (§1.4 says ≈ 60)")
	assert_eq(GameState.get_stat(&"specimens_taken"), 0)
	await _check_and_resave()


## §2.10 anatomist8: specimens sold – also of Lindenacker dead with a mourning house.
func test_day53_anatomist_loads() -> void:
	await _load("slot_p7_day53_anatomist")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [54, 420], "W0-Notizen: the bot days end on day 54")
	assert_true(GameState.has_flag(&"name_in_village_complete"))
	assert_true(GameState.flag_on(&"anatomy_known"), "the case accepted")
	assert_eq(_player().inventory.count(&"coin"), 60, "W0-Notizen: measured 60 (§2.10 says ≈ 71)")
	assert_true(GameState.get_stat(&"specimens_sold") >= 8, "specimens sold (%d)" % GameState.get_stat(&"specimens_sold"))
	assert_true(_linden_harvested() > 0, "harvested Lindenacker dead")
	assert_eq(_free_in(&"linden"), 0)
	assert_ne(_specimen_state("sp_0001"), &"held", "the heart jar of o_quast_specimen is in the cabinet")
	await _check_and_resave()


## The evening of the chapter day – Phase 8 opens the next morning (or at once for a migrated save, §1.2).
func test_day50_eve_loads() -> void:
	await _load("slot_p7_day50_eve")
	assert_eq(TimeManager.day, 50)
	assert_true(TimeManager.minute_of_day >= 1200, "evening of the chapter day (%d)" % TimeManager.minute_of_day)
	assert_true(GameState.has_flag(&"name_in_village_complete"), "name_in_village just reached")
	assert_eq(_player().region_id, &"graveyard")
	if _has_node_in(&"npc_life"):
		assert_true(GameState.flag_on(&"p8_open"), "§1.2: v6 → p8_open at once")
	await _check_and_resave()


func test_founder_loads() -> void:
	await _load("slot_p7_founder")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [48, 420])
	for flag: StringName in [&"six_pits_complete", &"names_in_stone_complete", &"roof_and_earth_complete", &"name_in_village_complete"]:
		assert_true(GameState.has_flag(flag), String(flag))
	assert_eq(_player().inventory.count(&"coin"), 52)
	await _check_and_resave()


## §5.2: in the Holderkrug in the middle of Phase 7 – Phase 8 stays closed, the chatters may run.
func test_mid_inn_loads() -> void:
	await _load("slot_p7_mid_inn")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [44, 857])
	assert_eq([_player().region_id, _player().interior_id], [&"village", &"inn"], "in the Holderkrug")
	assert_true(GameState.flag_on(&"village_open"))
	assert_false(GameState.has_flag(&"name_in_village_complete"), "chapter open")
	assert_false(GameState.flag_on(&"p8_open"), "Phase 8 stays closed")
	await _check_and_resave()


## §5.2: a corpse unwashed on the crypt table, the gravekeeper in the crypt (crypt from the start).
func test_crypt_corpse_loads() -> void:
	await _load("slot_p7_crypt_corpse")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [42, 484])
	assert_eq(_player().interior_id, &"crypt", "in the crypt")
	var on_table := _records_at(CorpseRecord.LOCATION_TABLE)
	assert_eq(on_table.size(), 1, "corpse on the crypt table")
	if on_table.size() == 1:
		var r: CorpseRecord = on_table[0]
		assert_eq([r.room, r.washed, r.is_dressed()], [&"crypt", false, false], "not yet washed / dressed (Totenwäsche possible)")
		assert_eq(r.kin_house, &"", "W0: migrate_6_to_7 is the identity (P6 derives kin_house)")
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase8Fixtures.install_save_v6(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _player() -> Player:
	return _world().get_player()


func _specimen_state(uid: String) -> StringName:
	var specimens := tree.get_first_node_in_group(&"specimens") as Specimens
	var spec := specimens.get_record(uid) if specimens != null else null
	return spec.state if spec != null else &""


func _levels() -> Dictionary[StringName, int]:
	return (_world().get_node("Systems/Buildings") as Buildings).levels()


func _has_node_in(group: StringName) -> bool:
	return not tree.get_nodes_in_group(group).is_empty()


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


func _linden_harvested() -> int:
	var n := 0
	for g: GraveRecord in _world().graveyard.graves():
		if _world().graveyard.section_of(g.id) != &"linden" or g.corpse_id == "":
			continue
		var r := _world().corpse_manager.get_record(g.corpse_id)
		if r != null and not r.harvested.is_empty():
			n += 1
	return n


func _trusted() -> int:
	var rel := _world().get_node("Systems/Relationships") as Relationships
	var n := 0
	for id: StringName in Phase8Fixtures.VILLAGER_IDS:
		if RelationshipRules.tier_index(rel.tier(id)) >= RelationshipRules.tier_index(&"trusted"):
			n += 1
	return n


func _records_at(location: StringName) -> Array[CorpseRecord]:
	var out: Array[CorpseRecord] = []
	for r: CorpseRecord in _world().corpse_manager.records():
		if r.location == location:
			out.append(r)
	return out


## No warning at all while loading (except the `known` findings, each at most once per load); the next
## save is the current format and round-trips.
func _check_and_resave(known: PackedStringArray = []) -> void:
	_drop_known(known)
	assert_eq(warnings.messages, PackedStringArray(), "no warnings while loading")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(TEST_SAVES, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "next save writes the current format")
	assert_eq(SaveFileIO.FORMAT_VERSION, 7)
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "round trip")
	_drop_known(known)
	assert_eq(warnings.messages, PackedStringArray(), "no warnings after the round trip")


## Removes the known findings from the log (each must appear – a fixed finding fails here, so the
## exception is removed with the fix).
func _drop_known(known: PackedStringArray) -> void:
	for text: String in known:
		var kept := PackedStringArray()
		var seen := false
		for m: String in warnings.messages:
			if m.begins_with(text):
				seen = true
			else:
				kept.append(m)
		assert_true(seen, "known finding still present: %s" % text)
		warnings.messages = kept


func _delete_saves() -> void:
	if SaveManager.save_dir != TEST_SAVES:
		return
	for slot: int in [SLOT, RESAVE_SLOT]:
		SaveManager.delete_save(slot)
