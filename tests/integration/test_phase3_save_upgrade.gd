extends TestCase
## P6 (docs/PHASE4_DESIGN.md §5.2, §10): Phase-3 saves (format v2, tests/fixtures/saves_v2/) and
## Phase-2 saves (v1, chain 1 → 2 → 3) in the Phase-4 world: they load through the real
## SaveManager without any warning, carry the migrated Phase-4 state (piety from the history,
## no trader yet, no second piety recovery / stench malus on the load day), keep their Phase-3
## state, and the next save is v3 and round-trips. slot_p3_day14_complete: the deliveries rest
## (cemetery full, Holunderwinkel still LOCKED) and the journal rebuilds the Phase-3 clues quietly.
## W-Welt (W2, the Phase-4 world): a stand loaded on day ≥ 4 after 06:00 finds Ilse's note at once
## (§5.2 step 5); the next day_started brings the key fallback (day ≥ 12), the Holunderwinkel is
## cleared by debug, the next delivery is S1 (catch-up) and S2 follows two days later.

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

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := messages.duplicate()
		messages.clear()
		_mutex.unlock()
		return out


const TIMEOUT := 180.0
const SLOT := 5
const RESAVE_SLOT := 6
## meta.day and piety (−6 × valuables taken + 3 × left) per fixture (§5.2 step 1).
const V2 := {"slot_p3_day5_table": [5, 6], "slot_p3_day9_night": [9, 3], "slot_p3_day14_complete": [14, 0], "slot_p3_interior": [3, 3]}
const V1 := {"slot_day3": [3, 3], "slot_day7_complete": [7, -9], "slot_interior": [2, 0]}
const ELDER_PLOTS: PackedStringArray = ["h_01", "h_02", "h_03", "h_04", "h_05", "h_06"]

var saves_dir := TestCase.user_dir("test_phase3_save_upgrade")
var warnings: WarningLog
var world: WorldRoot
var delivered: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	warnings = WarningLog.new()
	OS.add_logger(warnings)
	delivered.clear()
	EventBus.corpse_arrived.connect(_on_delivered)


func after_each() -> void:
	EventBus.corpse_arrived.disconnect(_on_delivered)
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_v2_fixtures_load_without_warnings_and_round_trip() -> void:
	for name: String in Phase4Fixtures.SAVES_V2:
		assert_eq(Phase4Fixtures.install_save_v2(name, saves_dir, SLOT), OK, name)
		await _load_and_check(name, V2[name])


func test_v1_fixtures_chain_to_v3_in_the_world() -> void:
	for name: String in Phase3Fixtures.SAVES_V1:
		assert_eq(Phase3Fixtures.install_save_v1(name, saves_dir, SLOT), OK, name)
		await _load_and_check(name, V1[name])


func test_day14_complete_rests_and_rebuilds_the_journal() -> void:
	assert_eq(Phase4Fixtures.install_save_v2("slot_p3_day14_complete", saves_dir, SLOT), OK)
	await _load_and_check("slot_p3_day14_complete", V2["slot_p3_day14_complete"])
	assert_true(GameState.has_flag(&"cemetery_complete"))
	assert_eq(world.graveyard.free_plot_count(), 0, "all twelve graves taken")
	for id: String in ELDER_PLOTS:
		var g := world.graveyard.get_grave(id)
		if g != null:
			assert_eq(g.state, GraveRecord.State.LOCKED, "%s LOCKED (§5.2 step 6)" % id)
	var journal := world.get_node("Systems/Journal") as JournalManager
	assert_true(GameState.has_flag(&"trader_known"), "loaded at 09:00 on day 14: the note at once")
	assert_true(journal.has_clue(&"c_trader_note"), "the note is in the journal")
	assert_false(GameState.has_flag(&"has_elder_key"), "no key yet")
	await _next_morning()
	assert_eq(delivered.size(), 0, "the deliveries rest (silently)")
	assert_eq(warnings.take(), PackedStringArray(), "a quiet morning")
	# §2.11 rule 4: day 15 ≥ key_fallback_day 12 → the key hangs at the bier.
	assert_true(GameState.has_flag(&"has_elder_key"), "key fallback on day_started")
	assert_true(journal.has_clue(&"c_elder_key"))
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	assert_eq(expansion.block_reason(&"elder"), "", "the gate can be unlocked")
	# Clear the Holunderwinkel (debug path: unlock) → six EMPTY plots, clue c_six_pits.
	assert_true(expansion.unlock(&"elder"))
	for id: String in ELDER_PLOTS:
		assert_eq(world.graveyard.get_grave(id).state, GraveRecord.State.EMPTY, id)
	assert_true(journal.has_clue(&"c_six_pits"))
	# The next delivery is S1 (catch-up), two days later S2.
	var stories: Array = []
	var on_story := func(story_id: StringName, _corpse: String) -> void: stories.append([TimeManager.day, story_id])
	EventBus.story_corpse_arrived.connect(on_story)
	await _next_morning()
	var first_day := TimeManager.day
	assert_eq(stories, [[first_day, &"s1_quendel"]], "S1 is the next delivery")
	# The bier must be free for the next delivery: bury what arrives (S1, then the random corpse).
	_bury_at_the_bier()
	await _next_morning()
	_bury_at_the_bier()
	await _next_morning()
	EventBus.story_corpse_arrived.disconnect(on_story)
	assert_eq(stories, [[first_day, &"s1_quendel"], [first_day + 2, &"s2_hemmerling"]], "S2 two days later")
	assert_eq(warnings.take(), PackedStringArray(), "the story mornings are quiet")
	# The journal was rebuilt from the records in post_load (migrated empty state).
	journal.load_state({})
	journal.post_load()
	if CorpseRecord.new().to_dict().has("finds_revealed"):
		# P1 reads the Phase-4 record fields: the migrated finds reach the records.
		assert_eq([journal.clue_count(&"c_mark"), journal.clue_count(&"c_warning_letter"), journal.clue_count(&"c_anchor_snake")],
				[2, 2, 3], "Phase-3 marks, letters and tattoos are in the journal")
		assert_true(GameState.has_flag(&"clue_c_mark"))
		assert_eq(journal.unread(), [] as Array[StringName], "quietly")
	var people := journal.people()
	assert_eq(people.size(), world.corpse_manager.records().size(), "a death note for every corpse")


# --- helpers ----------------------------------------------------------------------------------

## Loads slot SLOT (a v1 or v2 file), checks the Phase-4 state, resaves (v3) and reloads.
func _load_and_check(name: String, expect: Array) -> void:
	var migrated := {}
	assert_eq(SaveFileIO.read_doc(saves_dir, SLOT, migrated), OK, name + " reads")
	warnings.take()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	world = tree.current_scene as WorldRoot
	assert_not_null(world, name + " world")
	if world == null:
		return
	TimeManager.running = false
	assert_eq(warnings.take(), PackedStringArray(), name + ": loads without warnings")
	var day: int = expect[0]
	assert_eq(GameState.get_stat(&"piety"), expect[1], name + ": piety from the history")
	for stat: StringName in [&"utilized", &"prepared", &"trader_sales"]:
		assert_eq(GameState.get_stat(stat), 0, "%s: %s" % [name, stat])
	assert_eq(GameState.get_flag(&"piety_last_day"), day, name + ": piety_last_day = meta.day")
	# §5.2 step 5: trader_known is not migrated; from day 4 the note comes at the next 06:00 – at
	# once when the stand was saved after 06:00 (NightTrade.apply_morning on game_loaded).
	var note_now := day >= 4 and TimeManager.minute_of_day >= 360
	assert_eq(GameState.has_flag(&"trader_known"), note_now, name + ": the door note (day %d)" % day)
	var cm: Dictionary = migrated.state.nodes.corpse_manager
	assert_eq(cm.stench_day, day, name + ": no stench malus on the load day")
	for r: Dictionary in cm.corpses:
		assert_eq(r.dress, &"shroud" if r.shrouded else &"", "%s/%s dress" % [name, r.id])
	assert_eq(world.corpse_manager.records().size(), cm.corpses.size(), name + ": every corpse")
	# The next save writes v3 and round-trips.
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK, name + " saves")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, name + ": current format (v3; Phase 5: v4)")
	err = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, name + ": v3 round trip")
	assert_eq(warnings.take(), PackedStringArray(), name + ": the v3 file loads quietly too")


func _next_morning() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	TimeManager.set_time(TimeManager.day + 1, tables.delivery_minute)
	await tree.process_frame


## Every corpse on the bier into the next EMPTY plot with a wooden cross (real Graveyard API).
func _bury_at_the_bier() -> void:
	var inv := world.get_player().inventory
	for r: CorpseRecord in world.corpse_manager.records():
		if r.location != CorpseRecord.LOCATION_DROPOFF:
			continue
		var plot := ""
		for g: GraveRecord in world.graveyard.graves():
			if g.state == GraveRecord.State.EMPTY:
				plot = g.id
				break
		assert_ne(plot, "", "a free plot for " + r.id)
		if r.needs_valuables_decision():
			r.valuables_decision = CorpseRecord.DECISION_LEFT
		assert_true(world.graveyard.dig(plot) and world.graveyard.bury(plot, r.id), "%s buried in %s" % [r.id, plot])
		inv.add_item(&"wooden_cross", 1)
		world.graveyard.place_marker(plot, &"wooden_cross", inv)


func _on_delivered(_corpse_id: String) -> void:
	delivered.append(true)
