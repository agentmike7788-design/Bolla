extends TestCase
## P7 (docs/PHASE8_DESIGN.md §2.6.3, §3.4, §5.1, §10, §14.4): NightRobber – from the night after p8_open_day + 4,
## the target (fresh ≤ 5 days, no mortsafe, no candle, no night watch, not the night of the lights), the first
## night for sure, then 35 % with a pause of 2, deterministic; noticing ≤ 10 m (flees, the grave only dug at),
## the second encounter (sits → report / let go / ask, with their consequences), 05:00 disturbed + the morning
## note, the watchman after the third; never a corpse gone, nothing taken; save / load mid-dig.

const Harness := preload("res://tests/unit/visitors_harness.gd")
const OPEN := 53


class PlayerDouble extends Node3D:
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false

	func _init() -> void:
		add_to_group(&"player")


class PietyDouble extends Node:
	var events: Array = []

	func _init() -> void:
		add_to_group(&"piety")

	func event(kind: StringName, _reason: String) -> void:
		events.append(kind)


class JournalDouble extends Node:
	var clues: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		clues.append(id)
		return true


class WatchDouble extends Node:
	var watch: bool = false

	func _init() -> void:
		add_to_group(&"friendship")

	func night_watch_tonight() -> bool:
		return watch


var h: Harness
var cfg: RobberConfig
var robber: NightRobber
var player: PlayerDouble
var piety: PietyDouble
var journal: JournalDouble
var watch: WatchDouble
var events: Array = []
var notes: Array = []


func before_each() -> void:
	GameState.reset()
	cfg = Phase8Fixtures.robber_config()
	TimeManager.load_state({"day": 57, "minute_of_day": 600})
	h = Harness.new()
	h.setup(tree, OPEN)
	h.households_only()
	robber = NightRobber.new()
	robber.config = cfg
	player = PlayerDouble.new()
	piety = PietyDouble.new()
	journal = JournalDouble.new()
	watch = WatchDouble.new()
	for n: Node in [robber, player, piety, journal, watch]:
		h.root.add_child(n)
	player.global_position = Vector3(0, 0, 60)
	events.clear()
	notes.clear()
	EventBus.robber_event.connect(_on_event)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.robber_event.disconnect(_on_event)
	EventBus.notification_requested.disconnect(_on_note)
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _on_event(kind: StringName, grave_id: String) -> void:
	events.append([kind, grave_id])


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


## Runs minute by minute from now to (day, minute).
func _run_until(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		TimeManager.advance(1)


func _plot_pos(grave: String) -> Vector3:
	return (h.root.get_node(grave) as Node3D).global_position


# --- rules ---------------------------------------------------------------------------------------

func test_rules() -> void:
	assert_false(RobberRules.night_open(56, OPEN, -1, false, &"", cfg), "before p8_open_day + 4")
	assert_true(RobberRules.night_open(57, OPEN, -1, false, &"", cfg))
	assert_false(RobberRules.night_open(58, OPEN, 58, false, &"", cfg), "not the night of the lights")
	assert_false(RobberRules.night_open(58, OPEN, -1, true, &"", cfg), "Fenner's night watch")
	assert_false(RobberRules.night_open(58, OPEN, -1, false, &"reported", cfg), "his story is over")
	assert_true(RobberRules.comes(57, -1, OPEN, cfg), "the first night for sure")
	assert_false(RobberRules.comes(59, 57, OPEN, cfg), "a pause of 2 nights")
	var n := 0
	for night: int in range(60, 1060):
		if RobberRules.comes(night, 0, OPEN, cfg):
			n += 1
	assert_true(n > 280 and n < 420, "≈ 35 %% (%d of 1000)" % n)
	assert_eq(RobberRules.comes(70, 60, OPEN, cfg), RobberRules.comes(70, 60, OPEN, cfg), "deterministic")
	assert_true(RobberRules.is_target(55, 57, true, false, false, false, cfg), "3 days")
	assert_false(RobberRules.is_target(52, 57, true, false, false, false, cfg), "6 days")
	assert_false(RobberRules.is_target(56, 57, true, true, false, false, cfg), "mortsafe")
	assert_false(RobberRules.is_target(56, 57, true, false, true, false, cfg), "candle")
	assert_eq(RobberRules.freshest([{"grave_id": "l_09", "buried_day": 55}, {"grave_id": "l_10", "buried_day": 56}]), "l_10")


# --- the night -----------------------------------------------------------------------------------

func test_first_night_target_and_undisturbed_dawn() -> void:
	h.bury("l_09", &"house_kehr", 55)
	h.bury("l_10", &"house_brandt", 56)
	h.bury("l_01", &"house_ott", 40)
	_run_until(58, 1)
	assert_eq(robber.tonight_target(57), "l_10", "the freshest grave, decided at 00:00")
	_run_until(58, 91)
	assert_has(events, [&"arrived", "l_10"])
	assert_eq(robber.phase(), &"coming")
	_run_until(58, 120)
	assert_eq(robber.phase(), &"digging")
	_run_until(58, 301)
	assert_has(events, [&"disturbed", "l_10"])
	assert_true(h.care.is_disturbed("l_10"))
	assert_eq(h.clean.levels.get("dirt_l_10"), 3, "care spot 3")
	assert_eq(h.graveyard.get_grave("l_10").state, GraveRecord.State.MARKED, "the dead stays in the grave")
	assert_ne(h.graveyard.get_grave("l_10").corpse_id, "")
	assert_eq(h.life.events.back()[0], &"grave_disturbed")
	assert_eq(robber.disturbed_count(), 1)
	_run_until(58, 361)
	assert_true(notes.any(func(t: String) -> bool: return t.begins_with("Am Grab von Hedwig Lamprecht ist die Erde aufgeworfen.")))
	assert_eq(robber.fate(), &"")


func test_protected_graves() -> void:
	h.bury("l_09", &"house_kehr", 56)
	h.inv.add_item(&"mortsafe", 1)
	h.care.set_mortsafe("l_09", true, h.inv)
	_run_until(58, 1)
	assert_eq(robber.tonight_target(57), "", "a mortsafe")
	h.bury("l_10", &"house_brandt", 57)
	TimeManager.load_state({"day": 58, "minute_of_day": 1000})
	h.care.light_free("l_10")
	_run_until(59, 1)
	assert_eq(robber.tonight_target(58), "", "a candle burns at midnight")
	h.care.set_mortsafe("l_09", false, h.inv)


func test_candle_after_midnight_keeps_him_away() -> void:
	h.bury("l_09", &"house_kehr", 56)
	_run_until(58, 1)
	assert_eq(robber.tonight_target(57), "l_09")
	h.care.light_free("l_09")
	_run_until(58, 320)
	assert_eq(events, [], "he does not come to a lit grave")
	assert_false(h.care.is_disturbed("l_09"))


func test_no_robber_before_open_on_the_lights_or_in_a_watch_night() -> void:
	h.bury("l_09", &"house_kehr", 56)
	GameState.set_flag(&"fest_lights_day", 57)
	_run_until(58, 1)
	assert_eq(robber.tonight_target(57), "", "the night of the lights")
	GameState.clear_flag(&"fest_lights_day")
	watch.watch = true
	_run_until(59, 1)
	assert_eq(robber.tonight_target(58), "", "Fenner's watchman")


func test_first_encounter_flees() -> void:
	h.bury("l_09", &"house_kehr", 56)
	_run_until(58, 115)
	player.global_position = _plot_pos("l_09") + Vector3(9.5, 0, 0)
	_run_until(58, 117)
	assert_has(events, [&"fled", "l_09"])
	assert_eq(robber.encounters(), 1)
	assert_eq(GameState.get_stat(&"robber_encounters"), 1)
	assert_true(GameState.flag_on(&"robber_known"))
	assert_eq(h.clean.levels.get("dirt_l_09"), 1, "dug at: care spot +1")
	_run_until(58, 320)
	assert_false(h.care.is_disturbed("l_09"), "only dug at")
	assert_eq(robber.phase(), &"")


func test_far_away_or_inside_he_digs_on() -> void:
	h.bury("l_09", &"house_kehr", 56)
	_run_until(58, 115)
	player.global_position = _plot_pos("l_09") + Vector3(10.5, 0, 0)
	_run_until(58, 130)
	player.global_position = _plot_pos("l_09")
	player.in_interior = true
	_run_until(58, 140)
	player.in_interior = false
	player.region_id = &"village"
	_run_until(58, 301)
	assert_eq(robber.encounters(), 0)
	assert_true(h.care.is_disturbed("l_09"))


func _second_encounter() -> void:
	h.bury("l_09", &"house_kehr", 56)
	var state := robber.save_state()
	state.encounters = 1
	state.last_night = 50
	robber.load_state(state)
	_run_until(58, 115)
	player.global_position = _plot_pos("l_09")
	_run_until(58, 116)
	assert_has(events, [&"seen", "l_09"])
	assert_eq(robber.phase(), &"sitting")
	assert_eq(robber.encounters(), 2)


func test_second_encounter_report() -> void:
	_second_encounter()
	robber.resolve(&"ask")
	assert_eq(journal.clues, [&"c_n_robber"], "„Wer zahlt dich?\"")
	assert_eq(robber.phase(), &"sitting", "still sitting")
	robber.resolve(&"report")
	assert_eq(robber.fate(), &"reported")
	assert_eq(h.rep.count(&"robber_reported"), 1, "reputation +3 (config)")
	assert_has(h.rel.adds, [&"mayor", 4])
	assert_has(events, [&"gone", "l_09"])
	assert_eq(h.life.events.back()[0], &"robber_reported")
	_run_until(58, 320)
	assert_false(h.care.is_disturbed("l_09"))
	h.bury("l_10", &"house_brandt", 60)
	_run_until(62, 1)
	assert_eq(robber.tonight_target(61), "", "gone for good")


func test_second_encounter_let_go() -> void:
	_second_encounter()
	robber.resolve(&"let_go")
	assert_eq(robber.fate(), &"let_go")
	assert_eq(piety.events, [&"robber_let_go"])
	assert_has(h.rel.adds, [&"washer", 2])
	assert_has(h.rel.adds, [&"mayor", -2])
	assert_eq(h.rep.count(&"robber_reported"), 0)
	robber.resolve(&"report")
	assert_eq(robber.fate(), &"let_go", "decided once")


func test_watchman_after_the_third_disturbed_night() -> void:
	h.bury("l_09", &"house_kehr", 56)
	var state := robber.save_state()
	state.disturbed = 2
	state.last_night = 50
	robber.load_state(state)
	_run_until(58, 301)
	assert_eq(robber.fate(), &"caught_watch")
	assert_has(events, [&"caught", "l_09"])
	assert_eq(h.rep.events.filter(func(e: StringName) -> bool: return e == &"robber_reported").size(), 0, "no reputation")


func test_he_takes_nothing() -> void:
	h.bury("l_09", &"house_kehr", 56)
	var vstate := h.visitors.save_state()
	vstate.tips_on_stone = {"l_09": [2, "kin_kehr"]}
	h.visitors.load_state(vstate)
	_run_until(58, 301)
	assert_eq(h.visitors.tip_on_stone("l_09").x, 2, "the coins stay on the stone")
	assert_eq(h.graveyard.get_grave("l_09").corpse_id, h.corpses.recs.keys()[0], "the corpse never leaves")


func test_time_skip_through_the_night() -> void:
	h.bury("l_09", &"house_kehr", 56)
	TimeManager.load_state({"day": 57, "minute_of_day": 1380})
	TimeManager.advance(1)
	TimeManager.advance(8 * 60)
	assert_true(h.care.is_disturbed("l_09"), "asleep: decided, came, dug")
	assert_eq(robber.tonight_target(57), "l_09")


func test_save_load_mid_dig() -> void:
	h.bury("l_09", &"house_kehr", 56)
	_run_until(58, 150)
	var state := robber.save_state()
	var other := NightRobber.new()
	other.config = cfg
	h.root.add_child(other)
	robber.queue_free()
	await wait_frames(1)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state, "identical after JSON")
	assert_eq(other.phase(), &"digging")
	events.clear()
	_run_until(58, 301)
	assert_eq(events, [[&"disturbed", "l_09"]], "nothing replayed, the dawn once")
	robber = other


func test_fixture_robber_night() -> void:
	var r := Phase8Fixtures.robber_night("l_10", tree, 57, 1)
	assert_eq(r.tonight_target(57), "l_10")
	assert_eq(r.encounters(), 1)
	r.queue_free()
	await wait_frames(1)


func test_stub_free() -> void:
	for p: String in ["res://src/systems/night/night_robber.gd", "res://src/systems/night/robber_rules.gd"]:
		assert_false(FileAccess.get_file_as_string(p).contains("## STUB ("), p)
