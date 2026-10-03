extends TestCase
## Lead / W0 (docs/PHASE6_DESIGN.md §5.2, §12): every Phase-5 save fixture (format v4,
## tests/fixtures/saves_v4/) loads through the real SaveManager into the real world without
## engine errors and without any warning, keeps its Phase-5 state, and the next save writes the
## current format (round trip identical). W0: migrate_4_to_5 is the identity; P6 adds the §5.2
## assertions (interior_id, record fields, empty Phase-6 nodes) in test_save_migration.gd and
## tests/integration/test_phase5_save_upgrade.gd. The checks here stay valid after W1/W2 (the
## decor on the crypt site is either still placed or cleared into the chest).

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
var TEST_SAVES := TestCase.user_dir("test_saves_v4")
const SLOT := 7
const RESAVE_SLOT := 8
## The later crypt site: footprint x −10.4…−7.6 · z 5.6…8.2 + margin 0.6 + access (§4.1 G2).
const CRYPT_SITE := Rect2(-11.0, 5.0, 4.0, 4.8)

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


func test_fixtures_are_format_v4() -> void:
	assert_eq(Phase6Fixtures.SAVES_V4.size(), 7, "§5.2: seven v4 fixtures")
	for name: String in Phase6Fixtures.SAVES_V4:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase6Fixtures.save_v4_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 4, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


func test_slot_info_reads_v4() -> void:
	assert_eq(Phase6Fixtures.install_save_v4("slot_p5_day30_reverent", TEST_SAVES, SLOT), OK)
	var info := SaveManager.get_slot_info(SLOT)
	assert_true(info.exists, "v4 slot listed")
	assert_eq([info.day, info.minute_of_day], [30, 420])


func test_day30_reverent_loads() -> void:
	await _load("slot_p5_day30_reverent")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [30, 420])
	assert_true(GameState.has_flag(&"names_in_stone_complete"), "Phase 6 opens from here")
	assert_eq(_marked(), 18)
	assert_eq(_old(), 8, "8 old graves OLD")
	assert_eq(GameState.get_stat(&"reputation"), 100)
	assert_eq(_player().inventory.count(&"coin"), 27, "§2.8 expects ≈ 31 (measured 27 at 07:00)")
	await _check_and_resave()


func test_day35_harvester_loads() -> void:
	await _load("slot_p5_day35_harvester")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [35, 420])
	assert_true(GameState.has_flag(&"names_in_stone_complete"))
	assert_eq(_marked(), 18)
	assert_eq(_player().inventory.count(&"coin"), 102, "≈ 102 of §2.8")
	assert_eq(_robbed(true), 14, "14 fully robbed souls, restless")
	await _check_and_resave()


func test_day30_mender_loads() -> void:
	await _load("slot_p5_day30_mender")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [30, 420])
	assert_true(GameState.has_flag(&"names_in_stone_complete"))
	assert_eq(_marked(), 18)
	assert_eq(_player().inventory.count(&"coin"), 41)
	# W0-Notizen: the mender set master stones for the robbed graves first – they are robbed, but
	# no longer restless (content / calm).
	assert_eq(_robbed(false), 8, "8 robbed graves")
	await _check_and_resave()


func test_day16_table_loads() -> void:
	await _load("slot_p5_day16_table")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [16, 600])
	assert_true(GameState.has_flag(&"workshop_open"))
	assert_false(GameState.has_flag(&"names_in_stone_complete"))
	var on_table := _records_at(CorpseRecord.LOCATION_TABLE)
	assert_eq(on_table.size(), 1, "corpse on the table in front of the hut")
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
		assert_eq([r.room, r.slot_id, r.cold_windows, r.service_held], [&"", "", PackedInt32Array(), false], "Phase-6 defaults")
	await _check_and_resave()


func test_day16_carry_loads() -> void:
	await _load("slot_p5_day16_carry")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [16, 490])
	var carried := _records_at(CorpseRecord.LOCATION_CARRIED)
	assert_eq(carried.size(), 1, "the day's corpse is carried")
	assert_true(is_instance_valid(_player().carried), "in the gravekeeper's arms")
	assert_false(_player().in_interior)
	assert_eq(_player().interior_id, &"", "outside")
	await _check_and_resave()


func test_day20_crafter_loads() -> void:
	await _load("slot_p5_day20_crafter")
	assert_eq(TimeManager.day, 20)
	assert_true(TimeManager.minute_of_day >= 1200, "evening of the chapter day")
	assert_true(GameState.has_flag(&"names_in_stone_complete"), "names_in_stone just reached")
	# §1.2 („Migrierte Stände (v4) … setzt Buildings.post_load buildings_open sofort (auch nach
	# 06:00)“): correct against the contract – the morning rule is for v5 saves and a new game only.
	# W0 note 1 („buildings_open noch nicht gesetzt“) dates from before W2, when the world had no
	# Buildings node; W3 checked it (QA6-09 in docs/reviews/phase6_wip/qa_playthrough.md).
	assert_true(GameState.has_flag(&"buildings_open"), "§1.2: v4 with names_in_stone_complete → buildings_open at once")
	await _check_and_resave()


func test_interior_loads() -> void:
	await _load("slot_p5_interior")
	var world := tree.current_scene as WorldRoot
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [12, 1320])
	assert_true(_player().in_interior, "gravekeeper inside the hut")
	assert_eq(_player().interior_id, &"hut", "§5.2 step 1: interior_id from in_interior")
	var chest := world.get_node("HutInterior/Entities/chest") as Chest
	var decor := world.get_node("Systems/Decorations") as DecorationManager
	var on_site := 0
	for p: DecorPlacement in decor.placements():
		if p.decor_id == &"decor_bench_wood" and CRYPT_SITE.has_point(decor.centre_of(p)):
			on_site += 1
	# W1/W2 (P1 + W-Welt): the bench on the crypt site is cleared into the hut chest on the first
	# load (§5.2 step 5, Buildings.site_rects) – either still placed or in the chest.
	assert_true(on_site == 1 or chest.storage.count(&"decor_bench_wood") > 0, "bench on the crypt site or in the chest")
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase6Fixtures.install_save_v4(name, TEST_SAVES, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _player() -> Player:
	return (tree.current_scene as WorldRoot).get_player()


func _marked() -> int:
	var n := 0
	for g: GraveRecord in (tree.current_scene as WorldRoot).graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			n += 1
	return n


func _old() -> int:
	var n := 0
	for g: GraveRecord in (tree.current_scene as WorldRoot).graveyard.graves():
		if g.state == GraveRecord.State.OLD:
			n += 1
	return n


## MARKED graves whose corpse was harvested; `fully_restless`: hair + teeth and a restless ghost.
func _robbed(fully_restless: bool) -> int:
	var world := tree.current_scene as WorldRoot
	var ghosts := world.get_node("Systems/Ghosts") as GhostManager
	var n := 0
	for g: GraveRecord in world.graveyard.graves():
		var r := world.corpse_manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if g.state != GraveRecord.State.MARKED or r == null or r.harvested.is_empty():
			continue
		if fully_restless and not (r.is_harvested(&"hair") and r.is_harvested(&"teeth")
				and StringName(str(ghosts.mood_info(g.id).get("mood", ""))) == GhostMood.RESTLESS):
			continue
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
	assert_eq(SaveFileIO.FORMAT_VERSION, 5)
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
