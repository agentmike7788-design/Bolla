extends TestCase
## P6 (docs/PHASE6_DESIGN.md §2.2, §5.2, §10): Phase-5 saves (format v4, tests/fixtures/saves_v4/)
## in the Phase-6 build, through the real SaveManager into the real world.
## - slot_p5_day16_table (changed 04.10.2026, „Gruft von Beginn an“): the load lifts the crypt to level 1
##   and carries the corpse from the old table down onto the crypt table with all its states (one note);
##   workable there (examination step 3); the resave carries interior_id and the new record fields.
## - slot_p5_day16_carry: the gravekeeper carries the day's corpse outside (interior_id ""); the
##   hut still refuses a corpse.
## - slot_p5_interior: the gravekeeper is in the hut (interior_id "hut", the hut room active).
## W2 (§10, once the world has the crypt and P1/P2 are merged): `build crypt 1` carries the table
## corpse down with all its states, the rest of the examination at the crypt table, the burial;
## tragend in die Gruft → Nische. Those steps run here as soon as the world has a crypt room and a
## non-stub Buildings (see _crypt_ready); until then they are skipped.

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

var saves_dir := TestCase.user_dir("test_phase5_save_upgrade")
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


## Changed 04.10.2026 (user's wish „Gruft von Beginn an“): the crypt stands at level 1 from the start,
## so the load (Buildings.post_load) carries the corpse from the old table down onto the crypt table
## with all its states (one note); it stays workable there (step 3, then the rest and the burial).
func test_day16_table_corpse_goes_down_to_the_crypt_table() -> void:
	var notes: PackedStringArray = []
	var on_note := func(text: String, _kind: StringName) -> void: notes.append(text)
	EventBus.notification_requested.connect(on_note)
	await _load("slot_p5_day16_table")
	EventBus.notification_requested.disconnect(on_note)
	if world == null:
		return
	var player := world.get_player()
	assert_eq([player.in_interior, player.interior_id], [false, &""], "outside")
	var record := _table_record()
	assert_not_null(record, "the corpse on the table")
	if record == null:
		return
	assert_eq([record.room, record.slot_id, record.service_held, record.service_day], [&"crypt", "", false, 0],
			"§5.2 step 2: Phase-6 defaults, room crypt after the repair")
	assert_eq(record.cold_windows.size(), 3, "the crypt's cold window opens at the load")
	assert_eq(notes.count(CorpseManager.NOTE_RELOCATED), 1, "one note")
	assert_eq(record.exam_done.size(), 2, "2 of 4 steps kept")
	assert_true(record.is_harvested(&"hair"), "the braid stays taken")
	assert_false(record.balm_windows.is_empty(), "the juniper window stays")
	var old := world.get_node_by_layout_id("morgue_table") as MorgueTable
	assert_false(old.is_active() or old.visible, "the old table is gone")
	var buildings := world.get_node("Systems/Buildings")
	assert_eq(int(buildings.call(&"level", &"crypt")), 1, "crypt level 1 after the load")
	var crypt_table := MorgueTable.active(tree)
	assert_eq(crypt_table.room, &"crypt")
	assert_eq(crypt_table.corpse_id, record.id, "on the crypt table")
	# Step 3 at the crypt table, down the stair.
	HutPortal.arrive(player, InteriorRoom.find(tree, &"crypt").spawn_transform(), true, &"crypt")
	player.instant_actions = true
	var care := tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	var step: StringName = care.open_steps(record.id)[0]
	crypt_table.interact(player)
	UIState.clear()
	crypt_table.request_exam_step(step)
	assert_eq(record.exam_done.size(), 3, "step 3 (%s) at the crypt table" % step)
	assert_eq(warnings.take(), PackedStringArray(), "no warnings at the crypt table")
	await _resave_round_trip()
	if _crypt_ready():
		await _crypt_takes_the_table_corpse(record.id)


func test_day16_carry_stays_carried_outside() -> void:
	await _load("slot_p5_day16_carry")
	if world == null:
		return
	var player := world.get_player()
	assert_eq([player.in_interior, player.interior_id], [false, &""])
	assert_true(is_instance_valid(player.carried), "the day's corpse in the gravekeeper's arms")
	var hut_door := world.get_node_by_layout_id("hut_door") as HutDoor
	assert_false(hut_door.can_interact(player), "the hut still refuses a corpse")
	assert_eq(hut_door.get_interaction_prompt(player), HutDoor.TEXT_CORPSE_OUTSIDE)
	var hut := InteriorRoom.find(tree, &"hut")
	assert_not_null(hut, "the hut is an InteriorRoom")
	assert_false(hut.active, "the hut view is off")
	await _resave_round_trip()
	if _crypt_ready():
		# The round trip loaded a new world: its player.
		await _carry_into_the_crypt_niche(world.get_player())


func test_interior_save_in_the_hut() -> void:
	await _load("slot_p5_interior")
	if world == null:
		return
	var player := world.get_player()
	assert_eq([player.in_interior, player.interior_id], [true, &"hut"], "§5.2 step 1")
	var hut := world.get_node("HutInterior") as HutInterior
	assert_true(hut.active, "the hut room is active")
	var rig := world.get_node("CameraRig") as CameraRig
	assert_not_null(rig.profile, "the hut's camera profile")
	assert_almost(rig.distance, 9.0, 0.001, "hut distance 9 (unchanged)")
	assert_false((world.get_node("Sun") as Light3D).visible, "outdoor sun off")
	for node: Node in tree.get_nodes_in_group(InteriorRoom.GROUP):
		var room := node as InteriorRoom
		if room != hut:
			assert_false(room.active or room.visible, "%s inactive and hidden" % room.room_id)
	var saved := SaveManager.collect_state()
	assert_eq((saved.nodes.player as Dictionary).get("interior_id"), "hut", "§5.1: saved with the room")
	await _resave_round_trip()
	# The reload built a new world.
	player = world.get_player()
	hut = world.get_node("HutInterior") as HutInterior
	rig = world.get_node("CameraRig") as CameraRig
	assert_true(hut.active and player.interior_id == &"hut", "still in the hut after the reload")
	# Leaving through the real interior door.
	var door := hut.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is InteriorDoor)
	assert_false(door.is_empty(), "the hut's inside door")
	if not door.is_empty():
		HutPortal.arrive(player, (world.get_node_by_layout_id("hut_door") as HutDoor).exit_transform(), false)
		assert_eq([player.in_interior, player.interior_id], [false, &""])
		assert_false(hut.active)
		assert_null(rig.profile, "outdoor profile")


# --- W2 part (crypt in the world, P1 + P2 merged) -------------------------------------------------

## §10 (changed 04.10.2026: no build – the crypt stands from the start): the corpse lies on the crypt
## table with its steps, finds, braid and juniper window; the rest of the examination down there; then buried.
func _crypt_takes_the_table_corpse(corpse_id: String) -> void:
	var player := world.get_player()
	var record := world.corpse_manager.get_record(corpse_id)
	assert_eq([record.location, record.room], [CorpseRecord.LOCATION_TABLE, &"crypt"], "still on the crypt table after the resave")
	assert_true(record.is_harvested(&"hair"))
	var old_table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	assert_false(old_table.is_active(), "the old table never works")
	var crypt := InteriorRoom.find(tree, &"crypt")
	var tables := crypt.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is MorgueTable)
	assert_eq(tables.size(), 1, "the crypt table")
	if tables.is_empty():
		return
	var crypt_table := tables[0] as MorgueTable
	assert_true(crypt_table.is_active())
	HutPortal.arrive(player, crypt.spawn_transform(), true, &"crypt")
	player.instant_actions = true
	crypt_table.interact(player)
	UIState.clear()
	var care := tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	for step: StringName in care.open_steps(corpse_id):
		crypt_table.request_exam_step(step)
	assert_eq(record.exam_done.size(), 4, "the rest of the examination down in the crypt")
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	var plot := ""
	for g: GraveRecord in world.graveyard.graves():
		if g.state == GraveRecord.State.EMPTY:
			plot = g.id
			break
	assert_ne(plot, "", "a free plot")
	if plot != "":
		assert_true(world.graveyard.dig(plot) and world.graveyard.bury(plot, corpse_id), "buried")
	assert_eq(warnings.take(), PackedStringArray(), "no warnings in the crypt steps")


## §10: carried into the crypt (level 1) → into a niche.
func _carry_into_the_crypt_niche(player: Player) -> void:
	var buildings := world.get_node("Systems/Buildings")
	GameState.set_flag(&"buildings_open", true)
	buildings.call(&"load_state", {"levels": {"crypt": 1}})
	buildings.call(&"apply_levels")
	var door := BuildingDoor.find(tree, &"crypt")
	assert_not_null(door, "the crypt door")
	if door == null:
		return
	assert_true(door.can_interact(player), "§2.2: with the corpse into the crypt")
	var crypt := door.room()
	HutPortal.arrive(player, crypt.spawn_transform(), true, &"crypt")
	assert_eq(player.interior_id, &"crypt")
	assert_true(is_instance_valid(player.carried), "the corpse came along")
	var niches := crypt.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is CryptNiche)
	assert_false(niches.is_empty(), "niches in the crypt")
	for n: Node in niches:
		var niche := n as Node3D
		if niche.call(&"is_open") and niche.call(&"can_interact", player):
			niche.call(&"interact", player)
			break
	assert_false(is_instance_valid(player.carried), "laid into a niche")
	await _resave_round_trip()


## The world has the crypt room and P1's Buildings (not the W0 stub).
func _crypt_ready() -> bool:
	var buildings := world.get_node_or_null("Systems/Buildings")
	return buildings != null and not _is_stub(buildings) and InteriorRoom.find(tree, &"crypt") != null


func _is_stub(node: Node) -> bool:
	var script := node.get_script() as GDScript
	return script != null and script.source_code.contains("## STUB (")


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase6Fixtures.install_save_v4(name, saves_dir, SLOT), OK)
	warnings.take()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	TimeManager.running = false
	assert_eq(warnings.take(), PackedStringArray(), name + " loads without warnings")


func _table_record() -> CorpseRecord:
	for r: CorpseRecord in world.corpse_manager.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			return r
	return null


## The next save is v5 with interior_id and the record fields, and round-trips.
func _resave_round_trip() -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	assert_true((before.nodes.player as Dictionary).has("interior_id"), "player saves interior_id")
	for r: Variant in (before.nodes.corpse_manager as Dictionary).corpses:
		for key: String in ["room", "slot_id", "cold_windows", "service_held", "service_day"]:
			assert_true((r as Dictionary).has(key), "record saves %s" % key)
	assert_eq(SaveManager.save_game(RESAVE_SLOT), OK)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveFileIO.slot_path(saves_dir, RESAVE_SLOT)))
	assert_eq(int(doc.format_version), SaveFileIO.FORMAT_VERSION, "current format (Phase 6: v5, Phase 7: v6)")
	var err: Error = await SaveManager.load_game(RESAVE_SLOT)
	assert_eq(err, OK)
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, "v5 round trip")
	assert_eq(warnings.take(), PackedStringArray(), "the v5 file loads quietly")
