extends TestCase
## P7 (docs/PHASE8_DESIGN.md §1.6, §1.3, §3.4, §5.1, §10): NightPaths – np_ott / np_kehr relative to p8_open_day,
## the sick-light windows, the visits (Quast 22:30–23:10, Lenz 21:00–21:40, Liesel 02:40–05:30 after the death at
## 02:10 → ott_dead), observing on the way out (≤ 12 m, region village, not inside) → clue + stats, waiting in the
## shadow until 10 minutes before (≤ 120), the visit flags for the village schedules, save / load without replay.

const OPEN := 53


class PlayerDouble extends Node3D:
	var region_id: StringName = &"village"
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


var paths: NightPaths
var journal: JournalDouble
var player: PlayerDouble
var visits: Array = []


func before_each() -> void:
	GameState.reset()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", OPEN)
	TimeManager.load_state({"day": 55, "minute_of_day": 600})
	paths = NightPaths.new()
	paths.path_data = Phase8Fixtures.night_paths()
	paths.door_positions = {&"house_ott": Vector3(23.4, 0, 3.0), &"house_kehr": Vector3(-24.6, 0, -10.2)}
	journal = JournalDouble.new()
	player = PlayerDouble.new()
	for n: Node in [paths, journal, player]:
		tree.root.add_child(n)
	player.global_position = Vector3(19.5, 0, 5.4)
	visits.clear()
	EventBus.night_visit.connect(_on_visit)


func after_each() -> void:
	EventBus.night_visit.disconnect(_on_visit)
	for n: Node in [paths, journal, player]:
		n.queue_free()
	await wait_frames(1)
	GameState.reset()


func _on_visit(path_id: StringName, npc_id: StringName, phase: StringName) -> void:
	visits.append([path_id, npc_id, phase])


func _run_until(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		TimeManager.advance(1)


func test_rules_nights_and_windows() -> void:
	var ott := Phase8Fixtures.night_path(&"np_ott")
	assert_eq(NightPathRules.calendar_day(OPEN, 4, 160), 58, "02:40 of night 4 is day open + 5")
	assert_eq(NightPathRules.calendar_day(OPEN, 3, 1350), 56)
	assert_eq(NightPathRules.light_window(ott, OPEN), Vector2i(55 * 1440 + 960, 57 * 1440 + 360))
	assert_eq(NightPathRules.death_total(ott, OPEN), 57 * 1440 + 130, "02:10 on day 58")
	var v := NightPathRules.visits(ott, OPEN)
	assert_eq(v.map(func(x: Dictionary) -> StringName: return x.npc_id), [&"surgeon", &"priest", &"washer"])
	assert_eq(NightPathRules.door_waypoint(&"house_ott"), &"v_ott_door")
	assert_eq(NightPathRules.visit_flag(&"surgeon"), &"night_visit_surgeon_day")
	var sl := Phase8Fixtures.sick_light(&"np_ott", 4)
	assert_eq(sl.day, 57)
	assert_true(sl.burning)


func test_sick_houses_by_the_clock() -> void:
	assert_eq(paths.sick_houses(56, 900), PackedStringArray(), "before 16:00 of the first night")
	assert_eq(paths.sick_houses(56, 960), PackedStringArray(["house_ott"]))
	assert_eq(paths.sick_houses(57, 600), PackedStringArray(["house_ott"]), "the day between the nights")
	assert_eq(paths.sick_houses(58, 359), PackedStringArray(["house_ott"]), "still burns after the death")
	assert_eq(paths.sick_houses(58, 360), PackedStringArray(), "06:00 after the last night")
	assert_eq(paths.sick_houses(60, 1000), PackedStringArray(["house_kehr"]), "np_kehr nights 7 and 8")
	assert_eq(paths.sick_houses(62, 360), PackedStringArray(), "Paul is well again")
	GameState.set_flag(&"p8_open", false)
	assert_eq(paths.sick_houses(56, 1000), PackedStringArray(), "before p8_open nothing")


func test_next_visit_and_waiting() -> void:
	var n := paths.next_visit(&"np_ott", 56, 1000)
	assert_eq([n.npc_id, n.enter_minute, n.leave_minute], [&"surgeon", 1350, 1390])
	TimeManager.load_state({"day": 56, "minute_of_day": 1000})
	assert_eq(paths.wait_minutes(&"watch_ott"), 120, "at most 120")
	TimeManager.load_state({"day": 56, "minute_of_day": 1300})
	assert_eq(paths.wait_minutes(&"watch_ott"), 40, "until 22:20")
	TimeManager.load_state({"day": 56, "minute_of_day": 1360})
	assert_eq(paths.wait_minutes(&"watch_ott"), 20, "Quast inside: until 10 minutes before he comes out")
	TimeManager.load_state({"day": 56, "minute_of_day": 600})
	assert_eq(paths.wait_minutes(&"watch_ott"), 0, "no sick light at 10:00")
	assert_eq(paths.wait_minutes(&"watch_kehr"), 0)
	assert_eq(paths.next_visit(&"np_ott", 58, 400), {}, "all over")


func test_observing_on_the_way_out() -> void:
	TimeManager.load_state({"day": 56, "minute_of_day": 1340})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	_run_until(56, 1391)
	assert_eq(journal.clues, [&"c_n_quast_visit"], "≤ 12 m at 23:10")
	assert_true(paths.observed(&"c_n_quast_visit"))
	assert_eq(GameState.get_stat(&"night_visits_observed"), 1)
	assert_true(visits.has([&"np_ott", &"surgeon", &"enter"]))
	assert_true(visits.has([&"np_ott", &"surgeon", &"observed"]))
	assert_eq(GameState.get_flag(&"night_visit_surgeon_day"), 56, "the village schedule's today_flag")


func test_not_observed_far_away_inside_or_on_the_graveyard() -> void:
	TimeManager.load_state({"day": 56, "minute_of_day": 1340})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	player.global_position = Vector3(5, 0, 5)
	_run_until(56, 1391)
	assert_eq(journal.clues, [], "18 m away")
	TimeManager.load_state({"day": 57, "minute_of_day": 1250})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	player.global_position = Vector3(22, 0, 3)
	player.in_interior = true
	_run_until(57, 1301)
	assert_eq(journal.clues, [], "inside a room")
	TimeManager.load_state({"day": 57, "minute_of_day": 1250})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	player.in_interior = false
	player.region_id = &"graveyard"
	_run_until(57, 1301)
	assert_eq(journal.clues, [], "on the graveyard")


func test_death_and_liesels_watch() -> void:
	TimeManager.load_state({"day": 58, "minute_of_day": 100})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	player.global_position = Vector3(22, 0, 4)
	_run_until(58, 131)
	assert_eq(GameState.get_flag(&"ott_dead"), 58, "02:10 → ott_dead = the day")
	assert_eq(paths.death_day(&"np_ott"), 58)
	_run_until(58, 331)
	assert_eq(journal.clues, [&"c_n_liesel_watch"], "Liesel comes out at 05:30")


func test_time_skip_is_not_an_observation_but_the_death_counts() -> void:
	TimeManager.load_state({"day": 57, "minute_of_day": 1200})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	player.global_position = Vector3(22, 0, 4)
	TimeManager.advance(900)
	assert_eq(journal.clues, [], "asleep through the night")
	assert_eq(GameState.get_flag(&"ott_dead"), 58, "Gerhard Ott died anyway")


func test_save_load_without_replay() -> void:
	TimeManager.load_state({"day": 56, "minute_of_day": 1340})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	_run_until(56, 1391)
	var state := paths.save_state()
	var other := NightPaths.new()
	other.path_data = paths.path_data
	tree.root.add_child(other)
	paths.queue_free()
	await wait_frames(1)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state, "identical after JSON")
	visits.clear()
	TimeManager.advance(1)
	assert_eq(visits, [], "nothing replayed")
	assert_true(other.observed(&"c_n_quast_visit"))
	paths = other


func test_watch_spot_and_sick_light() -> void:
	var spot := (load("res://src/entities/watch_spot/watch_spot.tscn") as PackedScene).instantiate() as WatchSpot
	spot.spot_id = &"watch_ott"
	tree.root.add_child(spot)
	var light := (load("res://src/entities/sick_light/sick_light.tscn") as PackedScene).instantiate() as SickLight
	light.house = &"house_ott"
	tree.root.add_child(light)
	var p := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	p.instant_actions = true
	p.position = Vector3(0, 0, 50)
	tree.root.add_child(p)
	await wait_frames(2)
	TimeManager.load_state({"day": 56, "minute_of_day": 600})
	TimeManager.advance(1)
	assert_false(spot.can_interact(p), "no prompt by day")
	assert_eq(spot.get_interaction_prompt(p), "")
	assert_false(light.burning())
	TimeManager.load_state({"day": 56, "minute_of_day": 1299})
	TimeManager.advance(1)
	assert_true(light.burning(), "the sick light in the window")
	assert_true(light.get_node(^"Candle").visible)
	assert_true(spot.can_interact(p))
	assert_eq(spot.get_interaction_prompt(p), "[E] Im Schatten warten (bis ≈ 22:20)")
	spot.interact(p)
	await wait_frames(2)
	assert_eq(TimeManager.minute_of_day, 1340, "waited until 22:20")
	TimeManager.load_state({"day": 58, "minute_of_day": 400})
	TimeManager.advance(1)
	assert_false(light.get_node(^"Candle").visible, "out in the morning")
	for n: Node in [spot, light, p]:
		n.queue_free()
	await wait_frames(1)


func test_stub_free() -> void:
	for p: String in ["res://src/systems/night/night_paths.gd", "res://src/systems/night/night_path_rules.gd"]:
		assert_false(FileAccess.get_file_as_string(p).contains("## STUB ("), p)


# --- Phase 9 (P4, docs/PHASE9_DESIGN.md §2.2.2, §3.4): np_sieber relative to q_light_day, cancelled by sieber_gone -----

func _with_sieber(light: Variant) -> NightPathData:
	var sieber := Phase9Fixtures.night_path()
	var list: Array[NightPathData] = Phase8Fixtures.night_paths()
	list.append(sieber)
	paths.path_data = list
	if light != null:
		GameState.set_flag(&"q_light_day", light)
	return sieber


func test_np_sieber_counts_from_q_light_day() -> void:
	var sieber := _with_sieber(51)
	assert_eq(paths.anchor_day(sieber), 51)
	assert_eq(paths.anchor_day(Phase8Fixtures.night_path(&"np_ott")), OPEN, "np_ott stays on p8_open_day")
	assert_eq(NightPathRules.light_window(sieber, 51), Vector2i(69 * 1440 + 960, 71 * 1440 + 360), "light + 19 16:00 … light + 21 06:00")
	assert_eq(paths.sick_houses(70, 1350), PackedStringArray(["house_sieber"]), "Quast's night (light + 19)")
	assert_eq(paths.sick_houses(69, 1350), PackedStringArray())
	var v := paths.next_visit(&"np_sieber", 70, 1300)
	assert_eq([v.npc_id, v.enter_minute], [&"surgeon", 1350], "Quast 22:30")
	TimeManager.load_state({"day": 72, "minute_of_day": 100})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	TimeManager.advance(40)
	assert_eq(GameState.get_flag(&"sieber_dead"), 72, "§2.2.2: light + 21, 02:10")
	assert_eq(paths.death_day(&"np_sieber"), 72)


func test_np_sieber_needs_its_anchor_and_stops_when_he_is_gone() -> void:
	var sieber := _with_sieber(null)
	assert_false(paths.path_runs(sieber), "no q_light_day (before Phase 9)")
	assert_eq(paths.sick_houses(70, 1350), PackedStringArray())
	assert_eq(paths.next_visit(&"np_sieber", 70, 1300), {})
	GameState.set_flag(&"q_light_day", 51)
	assert_true(paths.path_runs(sieber))
	GameState.set_flag(&"sieber_gone", true)
	assert_false(paths.path_runs(sieber), "ending A: cancel_flag")
	assert_eq(paths.sick_houses(70, 1350), PackedStringArray())
	assert_eq(paths.wait_minutes(&"watch_sieber"), 0)
	TimeManager.load_state({"day": 72, "minute_of_day": 100})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	TimeManager.advance(40)
	assert_false(GameState.has_flag(&"sieber_dead"), "no death when he left")
	assert_true(paths.path_runs(Phase8Fixtures.night_path(&"np_ott")), "np_ott unaffected")


## W2 „Anschlüsse“ 18 (§2.2.6, §2.2.7): Liesel's vigil at the Siebers is visible like at the Otts – NightPaths sets
## night_np_sieber_washer_day on light + 21, P6's washer schedule walks her to v_sieber_door (02:40–05:30).
func test_w2_liesel_vigil_at_the_siebers_is_visible() -> void:
	_with_sieber(51)
	TimeManager.load_state({"day": 72, "minute_of_day": 100})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	TimeManager.advance(60)
	assert_eq(GameState.get_flag(&"night_np_sieber_washer_day"), 72, "Liesel's night (light + 21)")
	var washer := load("res://data/npc/washer_schedule.tres") as NpcSchedule
	var e := ScheduleResolver.entry_at(washer, 150, 72)
	assert_eq([e.activity, e.path[0], e.path[-1], e.visible], [&"walk", "v_dorn_door", "v_sieber_door", true], "02:30 on her way")
	e = ScheduleResolver.entry_at(washer, 160, 72)
	assert_eq([e.animation, e.path[-1]], [&"knock", "v_sieber_door"], "02:40 she knocks")
	e = ScheduleResolver.entry_at(washer, 200, 72)
	assert_eq([e.visible, e.path[-1]], [false, "v_sieber_door"], "inside with him")
	e = ScheduleResolver.entry_at(washer, 331, 72)
	assert_eq([e.visible, e.path[-1], e.dialogue_id], [true, "v_sieber_door", &"v_washer"], "05:30 at the door")
	e = ScheduleResolver.entry_at(washer, 340, 72)
	assert_eq([e.activity, e.path[-1]], [&"walk", "v_dorn_door"], "home again")
	GameState.clear_flag(&"night_np_sieber_washer_day")
	for t: int in [150, 200, 331]:
		assert_false(Array(ScheduleResolver.entry_at(washer, t, 72).path).has("v_sieber_door"), "without the night: as before (%d)" % t)


## W3 „Restbedarf“ 2 (§2.2.7 „Quast und Lenz kommen wie immer“): NightPaths sets night_np_sieber_surgeon_day (light + 19)
## and night_np_sieber_priest_day (light + 20); the schedules walk Quast and Lenz over the bridge and the Siebers' lane to
## v_sieber_door like to the Otts – knock, inside, at the door with their dialogue at the leave minute, home again.
func test_w3_quast_and_lenz_walk_to_the_siebers() -> void:
	_with_sieber(51)
	TimeManager.load_state({"day": 70, "minute_of_day": 1200})
	paths.load_state({"last_total": TimeManager.total_minutes()})
	TimeManager.advance(60)
	assert_eq(GameState.get_flag(&"night_np_sieber_surgeon_day"), 70, "Quast's night (light + 19)")
	TimeManager.advance(1440)
	assert_eq(GameState.get_flag(&"night_np_sieber_priest_day"), 71, "Lenz's night (light + 20)")
	var lane := ["v_bridge", "v_road_in", "v_sieber_lane_n", "v_sieber_lane_e", "v_sieber_lane_s", "v_sieber_yard", "v_sieber_door"]
	for c: Array in [["surgeon", 70, 1350, 1390, "v_surgery_door", &"v_surgeon", &"walk"],
			["priest", 71, 1260, 1300, "v_church_door", &"v_priest", &"lantern_walk"]]:
		var sched := load("res://data/npc/%s_schedule.tres" % c[0]) as NpcSchedule
		var day: int = c[1]
		var enter: int = c[2]
		var leave: int = c[3]
		var e := ScheduleResolver.entry_at(sched, enter - 10, day)
		assert_eq([e.activity, e.animation, e.path[0], e.visible], [&"walk", c[6], c[4], true], "%s on the way" % c[0])
		assert_eq(Array(e.path).slice(-lane.size()), lane, "%s over the bridge and the Siebers' lane" % c[0])
		assert_eq(ScheduleResolver.arrival_minute(e), enter, "%s at the door when the visit begins" % c[0])
		assert_true(e.travel_minutes >= 30, "%s: %d min for the ~60 m (no rush through the village)" % [c[0], e.travel_minutes])
		e = ScheduleResolver.entry_at(sched, enter, day)
		assert_eq([e.animation, e.path[-1]], [&"knock", "v_sieber_door"], "%s knocks" % c[0])
		e = ScheduleResolver.entry_at(sched, enter + 20, day)
		assert_eq([e.visible, e.path[-1]], [false, "v_sieber_door"], "%s inside with him" % c[0])
		e = ScheduleResolver.entry_at(sched, leave + 1, day)
		assert_eq([e.visible, e.path[-1], e.dialogue_id], [true, "v_sieber_door", c[5]], "%s at the door" % c[0])
		e = ScheduleResolver.entry_at(sched, leave + 10, day)
		assert_eq([e.activity, e.path[-1]], [&"walk", c[4]], "%s home again" % c[0])
		e = ScheduleResolver.entry_at(sched, leave + 2 + e.travel_minutes, day)
		assert_eq([e.visible, e.path[-1]], [false, c[4]], "%s at home" % c[0])
		GameState.clear_flag(StringName("night_np_sieber_%s_day" % c[0]))
		for t: int in range(enter - 40, leave + 60, 5):
			assert_false(Array(ScheduleResolver.entry_at(sched, t, day).path).has("v_sieber_door"),
					"%s without the night: as before (%d)" % [c[0], t])
