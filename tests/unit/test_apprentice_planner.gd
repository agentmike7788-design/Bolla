extends TestCase
## P3 (docs/PHASE8_DESIGN.md §2.5.2, §2.5.3, §3.4, §10): ApprenticePlanner – lines top to bottom, the nearest
## place first, only places that need it (level ≥ 1, wilting flowers, graves without a candle), skips mourned
## graves and locked sections, Ungelernt tasks and missing tools, candles from 15:00 (the lines below go on
## first), the walks to the rain barrel, no place into lunch or past 15:30, lunch on the bench, sweeping when
## time is left; deterministic mistakes. A small fake world (waypoints, DirtSpots + the real
## CleanlinessManager, fake plots / graveyard / grave care / expansion).


class FakePlot extends Node3D:
	var grave_id: String = ""
	var section_id: StringName = &"yard"

	func _init() -> void:
		add_to_group(&"grave_plot")


class FakeGraveyard extends Node:
	var states := {}

	func _init() -> void:
		add_to_group(&"graveyard")

	func get_grave(id: String) -> GraveRecord:
		if not states.has(id):
			return null
		var g := GraveRecord.new()
		g.id = id
		g.state = states[id]
		return g


class FakeGraveCare extends Node:
	var flowers := {}
	var candles := {}
	var fills := 6

	func _init() -> void:
		add_to_group(&"grave_care")

	func flowers_state(grave_id: String) -> StringName:
		if not flowers.has(grave_id):
			return &""
		var since := TimeManager.total_minutes() - int(flowers[grave_id].watered)
		return &"fresh" if since < 2880 else (&"wilted" if since < 5760 else &"")

	func candle_lit(grave_id: String) -> bool:
		return candles.has(grave_id)

	func can_fill(_owner: StringName = &"player") -> int:
		return fills

	func save_state() -> Dictionary:
		return {"flowers": flowers}


class FakeExpansion extends Node:
	var locked: Array = []

	func _init() -> void:
		add_to_group(&"expansion")

	func is_unlocked(section: StringName) -> bool:
		return not locked.has(section)


var world: Node3D
var clean: CleanlinessManager
var graveyard: FakeGraveyard
var care: FakeGraveCare
var expansion: FakeExpansion
var cfg: ApprenticeConfig
var tasks: Dictionary = {}


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(57, 505)
	ScheduleBuilder.walk_speed_override = 0.0
	cfg = Phase8Fixtures.apprentice_config()
	tasks.clear()
	for t: ApprenticeTaskData in Phase8Fixtures.apprentice_tasks():
		tasks[t.id] = t
	world = Node3D.new()
	world.name = "P8PlanWorld"
	tree.root.add_child(world)
	var wps := Node3D.new()
	wps.name = "Waypoints"
	world.add_child(wps)
	for spec: Array in [["apprentice_board", Vector3(0, 0, 0)], ["rain_barrel", Vector3(-3.2, 0, 0)],
			["apprentice_lunch", Vector3(0, 0, -3.2)], ["apprentice_sweep", Vector3(0, 0, 1.6)]]:
		var m := Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		wps.add_child(m)
	graveyard = FakeGraveyard.new()
	care = FakeGraveCare.new()
	expansion = FakeExpansion.new()
	for n: Node in [graveyard, care, expansion]:
		world.add_child(n)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


## A care spot; level set after the manager collected the spots (_finish_spots).
func _spot(id: String, kind: StringName, pos: Vector3, section: StringName = &"yard", grave: String = "") -> DirtSpot:
	var s := DirtSpot.new()
	s.name = id
	s.spot_id = id
	s.kind = kind
	s.section_id = section
	s.grave_id = grave
	s.position = pos
	world.add_child(s)
	return s


func _finish_spots(levels: Dictionary) -> void:
	clean = CleanlinessManager.new()
	world.add_child(clean)
	for id: String in levels:
		clean.set_level(id, int(levels[id]))


func _plot(id: String, pos: Vector3, section: StringName = &"yard", state: int = GraveRecord.State.MARKED) -> FakePlot:
	var p := FakePlot.new()
	p.name = id
	p.grave_id = id
	p.section_id = section
	p.position = pos
	world.add_child(p)
	graveyard.states[id] = state
	return p


func _state(levels: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var s := {"levels": levels, "morale": 3, "scolded": false, "position": "apprentice_board", "fills": care.fills,
			"items": {&"apprentice_rake": 1, &"watering_can": 1, &"grave_candle": 10}, "world": world, "tasks": tasks, "mourned": []}
	s.merge(extra, true)
	return s


func _lines(spec: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pair: Array in spec:
		out.append({"task": pair[0], "area": pair[1]})
	return out


func _work(plan: Array[Dictionary]) -> Array:
	return plan.filter(func(e: Dictionary) -> bool: return StringName(str(e.task)) in Apprentice.TASKS)


func test_nearest_place_first_with_walks_and_minutes() -> void:
	_spot("l_far", &"leaves", Vector3(16, 0, 0))
	_spot("l_near", &"leaves", Vector3(3.2, 0, -0.7))
	_spot("l_mid", &"leaves", Vector3(9.6, 0, -0.7))
	_spot("l_clean", &"leaves", Vector3(1.0, 0, -0.7))
	_spot("w_1", &"weeds", Vector3(2.0, 0, -0.7))
	await wait_frames(1)
	_finish_spots({"l_far": 2, "l_near": 1, "l_mid": 3, "l_clean": 0, "w_1": 2})
	var plan := ApprenticePlanner.plan(57, 510, _lines([["rake", "yard"]]), _state({"rake": 1}), tree, cfg)
	var work := _work(plan)
	assert_eq(work.map(func(e: Dictionary) -> String: return e.spot_id), ["l_near", "l_mid", "l_far"], "nearest first, only dirty leaves")
	var first: Dictionary = work[0]
	assert_eq([first.start, first.walk_minutes, first.work_start, first.work_minutes, first.end], [510, 1, 511, 15, 526],
			"3.2 m → 1 min, Angelernt 15")
	assert_eq(first.path, PackedStringArray(["apprentice_board", ScheduleBuilder.point_id(Vector3(3.2, 0, 0))]))
	assert_eq([work[1].start, work[1].walk_minutes, work[1].end], [526, 2, 543], "6.4 m → 2 min")
	assert_eq(work[1].path[0], first.path[1], "from where he stands")
	assert_eq(ApprenticePlanner.plan(57, 510, _lines([["rake", "yard"]]), _state({"rake": 2}), tree, cfg)[0].work_minutes, 10, "Geübt 10")
	var tail: Array = plan.slice(work.size()).map(func(e: Dictionary) -> Array: return [e.task, e.end])
	assert_eq(tail, [[&"sweep", cfg.lunch.x], [&"lunch", cfg.lunch.y], [&"sweep", cfg.end_minute]],
			"time left: sweeping until lunch, lunch on the bench, sweeping until 15:30")
	for e: Dictionary in plan:
		assert_eq(bool(e.mistake), ApprenticeRules.mistake(e.task, e.spot_id, 57, 1, false, cfg) if e.task == &"rake" else false,
				"deterministic mistake %s" % e.spot_id)


func test_lines_areas_locked_sections_and_mourned_graves() -> void:
	_spot("l_yard", &"leaves", Vector3(3, 0, 0), &"yard")
	_spot("l_east", &"leaves", Vector3(4, 0, 0), &"east")
	_spot("w_linden", &"weeds", Vector3(5, 0, 0), &"linden", "l_02")
	_spot("w_linden_2", &"weeds", Vector3(6, 0, 0), &"linden", "l_03")
	_spot("w_north", &"weeds", Vector3(2, 0, 0), &"north")
	await wait_frames(1)
	_finish_spots({"l_yard": 1, "l_east": 1, "w_linden": 2, "w_linden_2": 2, "w_north": 2})
	expansion.locked = [&"north"]
	var lines := _lines([["rake", "yard"], ["weed", "linden"]])
	var plan := ApprenticePlanner.plan(57, 510, lines, _state({"rake": 1, "weed": 1}, {"mourned": ["l_03"]}), tree, cfg)
	assert_eq(_work(plan).map(func(e: Dictionary) -> String: return e.spot_id), ["l_yard", "w_linden"],
			"line 1 first, only its area; the mourned grave and the locked section are skipped")
	var all := ApprenticePlanner.plan(57, 510, _lines([["rake", "all"]]), _state({"rake": 1}), tree, cfg)
	assert_eq(_work(all).map(func(e: Dictionary) -> String: return e.spot_id), ["l_yard", "l_east"], "area all")
	var untrained := ApprenticePlanner.plan(57, 510, lines, _state({"rake": 0, "weed": 1}), tree, cfg)
	assert_eq(_work(untrained).map(func(e: Dictionary) -> String: return e.task), [&"weed", &"weed"], "Ungelernt: the line is left out")
	var no_rake := ApprenticePlanner.plan(57, 510, lines, _state({"rake": 1, "weed": 1}, {"items": {}}), tree, cfg)
	assert_eq(_work(no_rake).map(func(e: Dictionary) -> String: return e.task), [&"weed", &"weed"], "no rake in his box")
	assert_eq(ApprenticePlanner.missing_items(_lines([["rake", "all"], ["candle", "all"]]), {}, {"tasks": tasks}),
			[&"apprentice_rake", &"grave_candle"] as Array[StringName])
	var done := ApprenticePlanner.plan(57, 510, lines, _state({"rake": 1, "weed": 1}, {"done": ["l_yard"]}), tree, cfg)
	assert_eq(_work(done)[0].spot_id, "w_linden", "a place twice: never")


func test_no_place_into_lunch_and_none_past_the_end() -> void:
	for i: int in 30:
		_spot("w_%02d" % i, &"weeds", Vector3(1 + i * 0.1, 0, 0))
	await wait_frames(1)
	var levels := {}
	for i: int in 30:
		levels["w_%02d" % i] = 1
	_finish_spots(levels)
	var plan := ApprenticePlanner.plan(57, 510, _lines([["weed", "all"]]), _state({"weed": 1}), tree, cfg)
	var lunch: Array = plan.filter(func(e: Dictionary) -> bool: return e.task == &"lunch")
	assert_eq(lunch.size(), 1)
	assert_eq([lunch[0].path[lunch[0].path.size() - 1], lunch[0].end], ["apprentice_lunch", 750], "lunch on the bench until 12:30")
	assert_true(int(lunch[0].work_start) <= 720 + 2, "from about 12:00")
	for e: Dictionary in _work(plan):
		assert_false(int(e.start) < 720 and int(e.end) > 720, "%s does not run into lunch" % e.spot_id)
		assert_true(int(e.end) <= cfg.end_minute, "%s ends by 15:30" % e.spot_id)
		assert_false(int(e.start) < 750 and int(e.start) >= 720, "nothing during lunch")
	var count := _work(plan).size()
	assert_true(count >= 11 and count <= 13, "≈ 12 weeding places of 30 min in 390 min (%d)" % count)
	var last: Dictionary = plan[plan.size() - 1]
	assert_true(int(last.end) <= cfg.end_minute)


func test_candles_from_three_and_the_lines_below_first() -> void:
	_plot("old_01", Vector3(3, 0, 0))
	_plot("old_02", Vector3(6, 0, 0))
	_plot("plot_09", Vector3(9, 0, 0), &"yard", GraveRecord.State.EMPTY)
	_plot("l_01", Vector3(12, 0, 0), &"linden")
	care.candles["old_02"] = 1
	_spot("l_a", &"leaves", Vector3(2, 0, 0))
	await wait_frames(1)
	_finish_spots({"l_a": 1})
	var plan := ApprenticePlanner.plan(57, 510, _lines([["candle", "yard"], ["rake", "yard"]]), _state({"candle": 1, "rake": 1}), tree, cfg)
	var work := _work(plan)
	assert_eq(work.map(func(e: Dictionary) -> String: return e.task), [&"rake", &"candle"], "the rake line goes on first")
	assert_eq(work[1].grave_id, "old_01", "only occupied graves of the area without a candle")
	assert_true(int(work[1].work_start) >= 900, "candles from 15:00")
	assert_eq(work[1].path[1], ScheduleBuilder.point_id(Vector3(3, 0, 0) + ApprenticePlanner.GRAVE_FOOT), "at the foot end")
	var wished := ApprenticePlanner.plan(57, 900, _lines([["candle", "wished"]]), _state({"candle": 1}, {"wished": ["l_01"]}), tree, cfg)
	assert_eq(_work(wished).map(func(e: Dictionary) -> String: return e.grave_id), ["l_01"], "only with a wish – in any section")
	var few := ApprenticePlanner.plan(57, 900, _lines([["candle", "all"]]), _state({"candle": 1}, {"items": {&"grave_candle": 1}}), tree, cfg)
	assert_eq(_work(few).size(), 1, "one candle in his box: one grave")


func test_watering_with_the_rain_barrel() -> void:
	TimeManager.set_time(57, 505)
	var now := TimeManager.total_minutes()
	for i: int in 3:
		_plot("old_0%d" % (i + 1), Vector3(3 + i, 0, 0))
	_plot("old_05", Vector3(8, 0, 0))
	care.flowers["old_01"] = {"planted": now - 2000, "watered": now - 2000}
	care.flowers["old_02"] = {"planted": now - 3000, "watered": now - 3000}
	care.flowers["old_03"] = {"planted": now - 100, "watered": now - 100}
	care.flowers["old_05"] = {"planted": now - 9000, "watered": now - 9000}
	care.fills = 1
	await wait_frames(1)
	var plan := ApprenticePlanner.plan(57, 510, _lines([["water", "all"]]), _state({"water": 1}), tree, cfg)
	var seq: Array = plan.filter(func(e: Dictionary) -> bool: return e.task != &"sweep" and e.task != &"lunch")
	assert_eq(seq.map(func(e: Dictionary) -> StringName: return e.task), [&"water", &"refill", &"water"],
			"fresh until tomorrow and gone flowers need nothing; one fill, then the barrel")
	assert_eq([seq[0].grave_id, seq[2].grave_id], ["old_01", "old_02"])
	assert_eq(seq[1].path[seq[1].path.size() - 1], "rain_barrel", "a visible walk to the barrel")
	assert_eq(seq[1].work_minutes, 2, "refill 2 min")
	assert_eq(seq[0].work_minutes, 7, "Angelernt 7")
	var no_can := ApprenticePlanner.plan(57, 510, _lines([["water", "all"]]), _state({"water": 1}, {"items": {}}), tree, cfg)
	assert_eq(_work(no_can).size(), 0, "no watering can")
