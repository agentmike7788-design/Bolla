extends TestCase
## P7 (docs/PHASE8_DESIGN.md §2.6.3, §1.6, §10): the night watch at systems level – real Graveyard, GraveCare,
## Visitors, NightRobber, NightPaths, Reputation and Piety (corpses, care spots, relationships, NpcLife and the
## journal as doubles). A fresh grave, the first robber night with the gravekeeper awake → he flees; a later night
## without a candle → he sits (run 1: to the mayor, run 2: let go); the third variant undisturbed → the grave is
## disturbed, the visit next morning sees it (reputation −3), the grave closed again. The sick light np_ott: the
## three observations at the house door (the walk to the village is RegionTravel's / W-Welt's – here the player
## stands at the watch spot), the death at 02:10 → ott_dead (D2 is StoryDirector's, P6).

const Harness := preload("res://tests/unit/visitors_harness.gd")
const OPEN := 53


class PlayerDouble extends Node3D:
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false

	func _init() -> void:
		add_to_group(&"player")


class JournalDouble extends Node:
	var clues: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		return true


var h: Harness
var robber: NightRobber
var paths: NightPaths
var rep: Reputation
var piety: Piety
var player: PlayerDouble
var journal: JournalDouble
var events: Array = []


func before_each() -> void:
	GameState.reset()
	GameState.stats[&"reputation"] = 80
	GameState.stats[&"piety"] = 40
	TimeManager.load_state({"day": 56, "minute_of_day": 600})
	h = Harness.new()
	h.setup(tree, OPEN)
	h.households_only()
	h.rep.free()
	rep = Reputation.new()
	rep.config = Phase8Fixtures.reputation_config()
	piety = Piety.new()
	piety.config = Phase8Fixtures.piety_config()
	robber = NightRobber.new()
	robber.config = Phase8Fixtures.robber_config()
	paths = NightPaths.new()
	paths.path_data = Phase8Fixtures.night_paths()
	player = PlayerDouble.new()
	journal = JournalDouble.new()
	for n: Node in [rep, piety, robber, paths, player, journal]:
		h.root.add_child(n)
	player.global_position = Vector3(0, 0, 80)
	GameState.set_flag(&"rep_last_day", 999)
	GameState.set_flag(&"piety_last_day", 999)
	events.clear()
	EventBus.robber_event.connect(_on_event)


func after_each() -> void:
	EventBus.robber_event.disconnect(_on_event)
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _on_event(kind: StringName, grave_id: String) -> void:
	events.append([kind, grave_id])


func _run_until(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		TimeManager.advance(1)


## Sleeps (one time skip) until (day, minute).
func _sleep_until(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	if target > TimeManager.total_minutes():
		TimeManager.advance(target - TimeManager.total_minutes())


func _at(grave: String) -> void:
	player.global_position = (h.root.get_node(grave) as Node3D).global_position + Vector3(3, 0, 0)


## The next night ≥ `from` the robber comes again after a visit on `last` (deterministic roll).
func _next_robber_night(from: int, last: int) -> int:
	for n: int in range(from, from + 60):
		if RobberRules.comes(n, last, OPEN, robber.config):
			return n
	return -1


func _first_night_flees() -> void:
	h.bury("l_09", &"house_kehr", 56)
	_run_until(58, 100)
	_at("l_09")
	_run_until(58, 112)
	assert_has(events, [&"fled", "l_09"], "the gravekeeper awake at the fresh grave")
	assert_true(GameState.flag_on(&"robber_known"))
	player.global_position = Vector3(0, 0, 80)
	_sleep_until(58, 420)
	assert_false(h.care.is_disturbed("l_09"), "only dug at")


func _second_night_sits() -> String:
	var night := _next_robber_night(60, 57)
	assert_true(night > 0)
	h.bury("l_10", &"house_brandt", night - 1)
	_sleep_until(night, 1300)
	_run_until(night + 1, 100)
	assert_eq(robber.tonight_target(night), "l_10", "a later night without a candle")
	_at("l_10")
	_run_until(night + 1, 115)
	assert_has(events, [&"seen", "l_10"], "he stumbles over the spoil and sits")
	assert_eq(robber.phase(), &"sitting")
	return "l_10"


func test_run_1_flees_then_to_the_mayor() -> void:
	_first_night_flees()
	_second_night_sits()
	var before := rep.value()
	robber.resolve(&"ask")
	robber.resolve(&"report")
	assert_eq(robber.fate(), &"reported")
	assert_eq(rep.value(), before + 3, "reputation +3")
	assert_has(h.rel.adds, [&"mayor", 4])
	assert_eq(journal.clues, [&"c_n_robber"])
	assert_eq(robber.encounters(), 2)


func test_run_2_flees_then_let_go() -> void:
	_first_night_flees()
	_second_night_sits()
	var before := piety.value()
	robber.resolve(&"let_go")
	assert_eq(robber.fate(), &"let_go")
	assert_eq(piety.value(), before + 2, "piety +2")
	assert_has(h.rel.adds, [&"washer", 2])
	assert_has(h.rel.adds, [&"mayor", -2])


func test_undisturbed_night_disturbed_grave_visit_and_closing() -> void:
	h.bury("l_09", &"house_kehr", 57)
	_sleep_until(58, 420)
	assert_true(h.care.is_disturbed("l_09"), "nobody watched")
	assert_eq(h.graveyard.get_grave("l_09").state, GraveRecord.State.MARKED, "the dead stays")
	h.plan(58)
	var before := rep.value()
	_run_until(58, 640)
	assert_eq(rep.value(), before - 3, "the visit sees it: reputation −3")
	assert_eq(h.visitors.goodwill(&"kin_kehr"), 1, "goodwill −4")
	assert_true(h.care.close_disturbed("l_09"), "closed again")
	assert_false(h.graveyard.get_grave("l_09").disturbed)


func test_sick_light_np_ott_three_observations_and_the_death() -> void:
	player.region_id = &"village"
	paths.door_positions = {&"house_ott": Vector3(23.4, 0, 3.0)}
	player.global_position = Vector3(19.5, 0, 5.4)
	_sleep_until(56, 1300)
	assert_eq(paths.sick_houses(56, 1300), PackedStringArray(["house_ott"]))
	_run_until(56, 1395)
	_sleep_until(57, 1250)
	_run_until(57, 1305)
	_sleep_until(58, 100)
	_run_until(58, 335)
	assert_eq(journal.clues, [&"c_n_quast_visit", &"c_n_lenz_visit", &"c_n_liesel_watch"], "Quast, Lenz, Liesel")
	assert_eq(GameState.get_stat(&"night_visits_observed"), 3)
	assert_eq(GameState.get_flag(&"ott_dead"), 58, "Gerhard Ott died at 02:10")
	_sleep_until(58, 420)
	assert_eq(paths.sick_houses(58, 420), PackedStringArray(), "the light is out in the morning")
