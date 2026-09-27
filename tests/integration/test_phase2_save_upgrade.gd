extends TestCase
## Phase-2 saves in the Phase-3 world (docs/PHASE3_DESIGN.md §5.2, §10; assigned to W-Welt):
## every v1 fixture (tests/fixtures/saves_v1/) loads through SaveManager into the real world
## without any warning, plots 07–12 are LOCKED, the reputation is mapped to the new scale and
## the deliveries resume. slot_day7_complete: no delivery while the old yard is full → the
## Ostwiese unlocked (debug path, like "unlock east") → a delivery the next morning → Osric
## plays p3_intro.

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


const TIMEOUT := 120.0
const SLOT := 7
const NEW_PLOTS: PackedStringArray = ["plot_07", "plot_08", "plot_09", "plot_10", "plot_11", "plot_12"]
## ReputationRules.migrate_v1 of the fixtures' Phase-2 reputation (0, −2, 0).
const REPUTATION := {"slot_day3": 40, "slot_day7_complete": 22, "slot_interior": 40}

var saves_dir := TestCase.user_dir("test_saves_p2_upgrade")
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


func test_day3_upgrades_and_the_next_delivery_comes() -> void:
	await _load("slot_day3")
	_check_upgraded("slot_day3")
	assert_true(world.graveyard.free_plot_count() > 0, "free plots in the old yard")
	await _next_morning()
	assert_eq(delivered.size(), 1, "a delivery the next morning")


func test_interior_upgrades_and_the_bier_is_cleared_first() -> void:
	await _load("slot_interior")
	_check_upgraded("slot_interior")
	assert_true(world.get_player().in_interior)
	# The day's corpse still lies on the bier: move it to the ground, then Osric delivers again.
	var manager := world.corpse_manager
	for r: CorpseRecord in manager.records():
		if r.location == CorpseRecord.LOCATION_DROPOFF:
			var p := Vector2(-3.5, -2.0)
			manager.put_down(r.id, CorpseRecord.LOCATION_GROUND, Transform3D(Basis.IDENTITY, Vector3(p.x, world.ground_height(p), p.y)))
	await _next_morning()
	assert_eq(delivered.size(), 1, "a delivery the next morning")


func test_day7_complete_waits_for_the_ostwiese() -> void:
	await _load("slot_day7_complete")
	_check_upgraded("slot_day7_complete")
	assert_true(GameState.get_flag(&"vs_finished"))
	assert_eq(world.graveyard.free_plot_count(), 0, "old yard full")
	await _next_morning()
	assert_eq(delivered.size(), 0, "no free plot → the deliveries rest (silently)")
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	var rep_before := GameState.get_stat(&"reputation")
	assert_true(expansion.unlock(&"east"), "debug unlock of the Ostwiese")
	for id: String in ["plot_07", "plot_08", "plot_09"]:
		assert_eq(world.graveyard.get_grave(id).state, GraveRecord.State.EMPTY, id)
	assert_eq(GameState.get_stat(&"reputation"), rep_before + 4, "section unlocked: reputation +4")
	await _next_morning()
	assert_eq(delivered.size(), 1, "the deliveries resume")
	# Osric at the bier: the Phase-3 introduction.
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	TimeManager.set_time(TimeManager.day, 480)
	npc.refresh()
	var requested: Array = []
	var on_request := func(id: StringName, speaker: Node) -> void: requested.append([id, speaker])
	EventBus.dialogue_requested.connect(on_request)
	npc.interact(world.get_player())
	EventBus.dialogue_requested.disconnect(on_request)
	assert_eq(requested.size(), 1, "Osric talks")
	if requested.is_empty():
		return
	UIState.clear()
	var runner := DialogueRunner.new()
	runner.start(Database.dialogue(requested[0][0]) as DialogueData, {"inventory": world.get_player().inventory, "speaker": npc})
	var seen: Array = []
	for step: int in 12:
		if runner.is_finished():
			break
		seen.append(runner.current_node().id)
		if runner.current_node().id == &"p3_intro":
			break
		var choices := runner.available_choices()
		if choices.is_empty():
			break
		runner.choose(0)
	assert_has(seen, &"p3_intro", "Osric plays p3_intro (%s)" % [seen])
	assert_true(GameState.has_flag(&"p3_intro"))


# --- helpers ----------------------------------------------------------------------------------

func _load(name: String) -> void:
	assert_eq(Phase3Fixtures.install_save_v1(name, saves_dir, SLOT), OK, name + " installed")
	warnings.take()
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	world = tree.current_scene as WorldRoot
	assert_not_null(world, name + " world")
	TimeManager.running = false


## No warning at all, new plots LOCKED, reputation on the new scale, empty Phase-3 states.
func _check_upgraded(name: String) -> void:
	assert_eq(warnings.take(), PackedStringArray(), name + ": loads without warnings")
	for id: String in NEW_PLOTS:
		assert_eq(world.graveyard.get_grave(id).state, GraveRecord.State.LOCKED, "%s: %s locked" % [name, id])
	assert_eq(GameState.get_stat(&"reputation"), REPUTATION[name], name + ": reputation mapped")
	assert_eq((world.get_node("Systems/Reputation") as Reputation).value(), REPUTATION[name])
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	assert_false(expansion.is_unlocked(&"east"), name + ": Ostwiese still overgrown")
	assert_eq(expansion.progress(&"east"), Vector2i(0, 10))
	assert_true(world.get_node("Decor/Overgrowth/east").visible)
	var clean := world.get_node("Systems/Cleanliness") as CleanlinessManager
	assert_eq(clean.penalty(), 0, name + ": migrated spots start freshly tended")
	assert_eq((world.get_node("Systems/Decorations") as DecorationManager).placements().size(), 0)
	assert_false(GameState.has_flag(&"slice_complete"), name + ": slice_complete no longer stops deliveries")


## The next day's delivery minute (CorpseTables.delivery_minute).
func _next_morning() -> void:
	var tables := Database.corpse_tables() as CorpseTables
	TimeManager.set_time(TimeManager.day + 1, tables.delivery_minute)
	await tree.process_frame


func _on_delivered(_corpse_id: String) -> void:
	delivered.append(true)
