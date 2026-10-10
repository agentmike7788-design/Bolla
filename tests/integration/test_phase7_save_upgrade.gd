extends TestCase
## P6 (docs/PHASE8_DESIGN.md §5.2, §10): Phase-7 saves (format v6, tests/fixtures/saves_v6/) in the Phase-8
## build, through the real SaveManager into the real world.
## - slot_p7_mid_inn: in the Holderkrug in the middle of Phase 7 – Phase 8 stays closed (no p8_open, no Phase-8
##   lines in the dialogues), the chatters of the Phase-7 villagers may run (they need only village_open,
##   §1.2), the Phase-8 ones not.
## - slot_p7_crypt_corpse: the unwashed corpse on the crypt table keeps its state – Liesel's Totenwäsche and the
##   Totenwache (§2.4) stay possible; it lies in no grave yet, so no kin_house.
## - slot_p7_day53_anatomist: Lindenacker dead with kin_house = the Phase-7 mourning ribbon, some of them with a
##   sold specimen – the visitors can hear of the jar (§2.2.4, the −3 goodwill itself is P2's GraveView).
## - slot_p7_day53_neighbor: the migrated v7 state (stats 0, grave fields, kin_house) and the chapter flag that
##   opens Phase 8 (NpcLife.post_load, P1).
## All resave as v7 and round-trip identically.

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


const TIMEOUT := 240.0
const SLOT := 5
const RESAVE_SLOT := 6
## W0-Notizen 12 (Phase-7 bug, fix owner P4): the anatomist state warns about its orphan heart jar.
const KNOWN_ORPHAN := "[Specimens] held specimen sp_0001 has no inventory slot"

var saves_dir := TestCase.user_dir("test_phase7_save_upgrade")
var warnings: WarningLog


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	warnings = WarningLog.new()
	OS.add_logger(warnings)


func after_each() -> void:
	OS.remove_logger(warnings)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_mid_inn_phase8_stays_closed_chatters_may_run() -> void:
	await _load("slot_p7_mid_inn")
	assert_eq([_world().get_player().region_id, _world().get_player().interior_id], [&"village", &"inn"])
	assert_false(GameState.has_flag(&"name_in_village_complete"), "chapter open")
	assert_false(GameState.flag_on(&"p8_open"), "§1.2: Phase 8 stays closed")
	assert_false(DialogueConditions.check("p8_open", {}), "the dialogues see it closed")
	# §1.2: the chatters run from village_open – those with the Phase-7 people and no Phase-8 condition.
	var p8_people := [&"apprentice", &"beggar", &"peddler", &"kin_kehr"]
	var may_run: Array[StringName] = []
	for res: Resource in _chatters():
		var c := res as ChatterData
		var conds: Array[String] = []
		for cond: String in c.conditions:
			conds.append(cond)
		var all := DialogueConditions.all_met(conds, {})
		var has_p8_person := c.npcs.any(func(n: StringName) -> bool: return n in p8_people)
		if all:
			may_run.append(c.id)
			assert_false(has_p8_person, "%s: no Phase-8 figure before p8_open" % c.id)
	for id: StringName in [&"ch_well_spin", &"ch_linden_bench", &"ch_inn_council", &"ch_inn_carter"]:
		assert_true(id in may_run, "%s runs in a Phase-7 game" % id)
	for id: StringName in [&"ch_rumor_robber", &"ch_bridge_water", &"ch_church_alms", &"ch_inn_jakob"]:
		assert_false(id in may_run, "%s waits for Phase 8" % id)
	# The Phase-8 lines of the villagers stay hidden: Rosine offers no story, Osric no p8_intro.
	var menu := (load("res://data/dialogue/v_innkeeper.tres") as DialogueData).get_node_by_id(&"menu")
	for c: DialogueChoice in menu.choices:
		if c.next in [&"story_1", &"story_2", &"story_3", &"story_cross", &"listen", &"favor"]:
			assert_false(DialogueConditions.all_met(c.conditions, {}), "Rosine: %s hidden" % c.next)
	var intro := (load("res://data/dialogue/carter.tres") as DialogueData).get_node_by_id(&"p8_intro")
	assert_false(DialogueConditions.all_met(intro.conditions, {}), "no p8_intro")
	_assert_v7_shape()
	await _check_and_resave()


func test_crypt_corpse_keeps_the_washing_open() -> void:
	await _load("slot_p7_crypt_corpse")
	assert_eq(_world().get_player().interior_id, &"crypt")
	var on_table: Array[CorpseRecord] = []
	for r: CorpseRecord in _world().corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			on_table.append(r)
	assert_eq(on_table.size(), 1, "the corpse on the crypt table")
	if on_table.size() == 1:
		var r := on_table[0]
		assert_eq([r.room, r.washed, r.is_dressed(), r.kin_house], [&"crypt", false, false, &""],
				"§2.4: Totenwäsche (wash + dress) still to do; in no grave yet → no kin_house")
	# Liesel's two crypt scenes exist in her dialogue (§2.4 Schritt 2 / Gefallen).
	var d := load("res://data/dialogue/v_washer.tres") as DialogueData
	assert_not_null(d.get_node_by_id(&"story_2_vigil"), "the wake in the crypt")
	assert_not_null(d.get_node_by_id(&"favor"), "the favour Totenwäsche")
	_assert_v7_shape()
	await _check_and_resave()


func test_anatomist_dead_have_their_kin_and_the_sold_jars() -> void:
	await _load("slot_p7_day53_anatomist")
	var specimens := _world().get_node("Systems/Specimens") as Specimens
	var with_kin := 0
	var sold_with_kin := 0
	for g: GraveRecord in _world().graveyard.graves():
		if _world().graveyard.section_of(g.id) != &"linden" or g.corpse_id == "":
			continue
		var r := _world().corpse_manager.get_record(g.corpse_id)
		if r == null:
			continue
		if r.story_id != &"":
			assert_eq(r.kin_house, &"", "%s (story corpse): no kin – Liesel visits D1 herself" % r.id)
			continue
		assert_ne(r.kin_house, &"", "%s in the Lindenacker after village_open: a household" % r.id)
		assert_true(String(r.kin_house) in SaveMigration.ribbon_houses(), "%s: %s is a ribbon house" % [r.id, r.kin_house])
		with_kin += 1
		for uid: String in specimens.of_corpse(r.id):
			if specimens.get_record(uid).state == &"sold":
				sold_with_kin += 1
				break
	assert_eq(with_kin, 7, "seven Lindenacker dead with kin (D1 is a story corpse)")
	assert_true(sold_with_kin >= 1, "a sold jar of a dead with kin – §2.2.4 „Beim Quast steht ein Glas“ (%d)" % sold_with_kin)
	for r: CorpseRecord in _world().corpse_manager.records():
		if not String(r.grave_id).begins_with("l_"):
			assert_eq(r.kin_house, &"", "%s outside the Lindenacker: no kin (§5.2 step 1)" % r.id)
	_assert_v7_shape()
	await _check_and_resave(PackedStringArray([KNOWN_ORPHAN]))


func test_neighbor_end_state_is_ready_for_phase8() -> void:
	await _load("slot_p7_day53_neighbor")
	assert_true(GameState.flag_on(&"name_in_village_complete"), "§1.2: the chapter that opens Phase 8")
	assert_eq(GameState.get_flag(&"village_open_day"), 40)
	var houses := {}
	for r: CorpseRecord in _world().corpse_manager.records():
		if r.kin_house != &"":
			houses[r.kin_house] = int(houses.get(r.kin_house, 0)) + 1
	var total := 0
	for h: StringName in houses:
		total += int(houses[h])
	assert_eq(total, 7, "kin for the seven Lindenacker dead")
	assert_true(houses.size() >= 2, "more than one household comes up (%s)" % str(houses))
	var l09 := _world().graveyard.get_grave("l_09")
	assert_true(l09 == null or l09.state == GraveRecord.State.LOCKED, "row 3 is not open yet (W-Welt adds it LOCKED)")
	_assert_v7_shape()
	await _check_and_resave()


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase8Fixtures.install_save_v6(name, saves_dir, SLOT), OK, name + " installed")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	assert_true(tree.current_scene is WorldRoot, name + " world")
	TimeManager.running = false


func _world() -> WorldRoot:
	return tree.current_scene as WorldRoot


func _chatters() -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at("res://data/npc_life/chatter"):
		if f.ends_with(".tres"):
			out.append(load("res://data/npc_life/chatter/" + f))
	assert_eq(out.size(), 16)
	return out


## §5.1 / §5.2: the 26 stats at 0, the grave fields at their defaults, every record with a kin_house name.
func _assert_v7_shape() -> void:
	for key: StringName in SaveMigration.V7_NEW_STATS:
		assert_eq(GameState.stats.get(key), 0, "stat %s = 0" % key)
	for g: GraveRecord in _world().graveyard.graves():
		assert_eq([g.disturbed, g.extra_lines], [false, PackedStringArray()], "%s: Phase-8 grave defaults" % g.id)
	var state := SaveManager.collect_state()
	for r: Variant in state.nodes.corpse_manager.corpses:
		assert_true((r as Dictionary).has("kin_house"), "record %s saves kin_house" % (r as Dictionary).get("id"))


## No warning while loading (except the known findings), the next save writes v7 and round-trips.
func _check_and_resave(known: PackedStringArray = []) -> void:
	_drop_known(known)
	assert_eq(warnings.messages, PackedStringArray(), "no warnings while loading")
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), 7, "next save writes v7")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v7 round trip identical")
	_drop_known(known)
	assert_eq(warnings.messages, PackedStringArray(), "no warnings after the round trip")


func _drop_known(known: PackedStringArray) -> void:
	for text: String in known:
		var kept := PackedStringArray()
		for m: String in warnings.messages:
			if not m.contains(text):
				kept.append(m)
		warnings.messages = kept
