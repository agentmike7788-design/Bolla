extends TestCase
## P3 (docs/PHASE8_DESIGN.md §2.5, §3.3, §3.4, §5.1, §10): Apprentice – hiring only through hire() (Rosine
## step 1, the next day on), the working day 08:15–15:40 on the graveyard Npc (runtime schedule), the days off
## (day % 7 == 2, festivals, 3 unpaid days), the board (3 lines), the effects at the end of a place through
## tend_by / GraveCare (= the player's effect), the mistakes and their effects, teaching (only Ungelernt,
## ≤ 4 m) and Geübt after 12, praise / scolding, the wage of 3 from the tin at 15:30, unpaid days (Rosine −2,
## after 3 at home, back after paying), the limits (never at night, never a grave / corpse / station), save /
## load in the middle of a place. A small graveyard RegionRoot, the real CleanlinessManager and box, fakes for
## grave care / festivals / visitors.

const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const BOX_SCENE := "res://src/entities/apprentice_box/apprentice_box.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const ITEMS: Array[StringName] = [&"apprentice_rake", &"watering_can", &"grave_candle"]


class FakeGraveCare extends Node:
	var watered: Array = []
	var lit: Array = []
	var wilted: Array = []
	var torn: Array = []
	var refills := 0
	var flowers := {}

	func _init() -> void:
		add_to_group(&"grave_care")

	func flowers_state(grave_id: String) -> StringName:
		return flowers.get(grave_id, &"")

	func candle_lit(grave_id: String) -> bool:
		return lit.has(grave_id)

	func can_fill(_owner: StringName = &"player") -> int:
		return 6

	func water(grave_id: String, by_apprentice := false) -> bool:
		watered.append([grave_id, by_apprentice])
		return true

	func light(grave_id: String, inv: Inventory) -> bool:
		if inv == null or not inv.remove_item(&"grave_candle", 1):
			return false
		lit.append(grave_id)
		return true

	func refill(_owner: StringName = &"player") -> void:
		refills += 1

	func wilt_flowers(grave_id: String) -> void:
		wilted.append(grave_id)

	func tear_flowers(grave_id: String) -> void:
		torn.append(grave_id)

	func save_state() -> Dictionary:
		return {"flowers": {}}


class FakeFestivals extends Node:
	var days := {}

	func _init() -> void:
		add_to_group(&"festivals")

	func fest_day(id: StringName) -> int:
		return int(days.get(id, -1))

	func today() -> StringName:
		for id: StringName in days:
			if int(days[id]) == TimeManager.day:
				return id
		return &""


class FakeOrders extends Node:
	var tasks: Array = []

	func _init() -> void:
		add_to_group(&"orders")

	func note_task(action_id: StringName) -> void:
		tasks.append(action_id)


class FakeVisitors extends Node:
	var active: Array[Dictionary] = []

	func _init() -> void:
		add_to_group(&"visitors")

	func active_visits() -> Array[Dictionary]:
		return active


var world: Node3D
var graveyard: RegionRoot
var holder: Node3D
var app: Apprentice
var box: ApprenticeBox
var npc: Npc
var clean: CleanlinessManager
var care: FakeGraveCare
var rel: Relationships
var life: NpcLife
var injected: Array[StringName] = []
var done_jobs: Array = []
var levels_changed: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(53, 600)
	for id: StringName in ITEMS:
		if not Database.has_item(id):
			Database._items[id] = load("res://tests/fixtures/items/%s.tres" % id)
			injected.append(id)
	world = Node3D.new()
	world.name = "P8AppWorld"
	tree.root.add_child(world)
	graveyard = Phase7Fixtures.region_at(&"graveyard")
	graveyard.name = "Graveyard"
	graveyard.config = graveyard.config.duplicate() as RegionConfig
	graveyard.config.managed_paths = PackedStringArray()
	world.add_child(graveyard)
	holder = Node3D.new()
	holder.name = "Waypoints"
	graveyard.add_child(holder)
	for spec: Array in [["road_end", Vector3(0, 0, 40)], ["road_mid", Vector3(0, 0, 24)], ["gate_outside", Vector3(0, 0, 12)],
			["gate_inside", Vector3(0, 0, 9)], ["apprentice_board", Vector3(2, 0, 0)], ["apprentice_box", Vector3(3.6, 0, 0)],
			["apprentice_lunch", Vector3(2, 0, -2)], ["apprentice_sweep", Vector3(2, 0, 1.5)], ["rain_barrel", Vector3(-2, 0, 0)]]:
		var m := Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		holder.add_child(m)
	for spec: Array in [["dirt_a", &"leaves", Vector3(5, 0, 0)], ["dirt_b", &"leaves", Vector3(8, 0, 0)],
			["dirt_c", &"leaves", Vector3(11, 0, 0)], ["dirt_w", &"weeds", Vector3(-5, 0, 0)]]:
		var s := DirtSpot.new()
		s.name = spec[0]
		s.spot_id = spec[0]
		s.kind = spec[1]
		s.section_id = &"yard"
		s.position = spec[2]
		graveyard.add_child(s)
	care = FakeGraveCare.new()
	world.add_child(care)
	rel = Relationships.new()
	rel.config = Phase8Fixtures.relationship_config()
	for v: VillagerData in Phase8Fixtures.villagers():
		rel.villagers[v.npc_id] = v
	world.add_child(rel)
	life = NpcLife.new()
	life.config = Phase8Fixtures.npc_life_config()
	world.add_child(life)
	npc = (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_apprentice"
	npc.npc_id = &"apprentice"
	npc.region_id = &"graveyard"
	graveyard.add_child(npc)
	box = (load(BOX_SCENE) as PackedScene).instantiate() as ApprenticeBox
	world.add_child(box)
	await wait_frames(1)
	clean = CleanlinessManager.new()
	world.add_child(clean)
	for id: String in ["dirt_a", "dirt_b", "dirt_c"]:
		clean.set_level(id, 1)
	clean.set_level("dirt_w", 2)
	app = Apprentice.new()
	app.config = Phase8Fixtures.apprentice_config()
	for t: ApprenticeTaskData in Phase8Fixtures.apprentice_tasks():
		app.tasks[t.id] = t
	world.add_child(app)
	box.storage.add_item(&"apprentice_rake", 1)
	box.storage.add_item(&"watering_can", 1)
	box.storage.add_item(&"grave_candle", 4)
	done_jobs.clear()
	levels_changed.clear()
	EventBus.apprentice_job_done.connect(_on_job)
	EventBus.apprentice_level_changed.connect(_on_level)


func after_each() -> void:
	EventBus.apprentice_job_done.disconnect(_on_job)
	EventBus.apprentice_level_changed.disconnect(_on_level)
	if is_instance_valid(world):
		world.free()
	for id: StringName in injected:
		Database._items.erase(id)
	injected.clear()
	GameState.reset()
	TimeManager.reset()


func _on_job(task: StringName, spot: String, mistake: bool) -> void:
	done_jobs.append([task, spot, mistake])


func _on_level(task: StringName, value: int) -> void:
	levels_changed.append([task, value])


func _hired(levels: Dictionary = {"rake": 1}, lines: Array = [{"task": "rake", "area": "yard"}], coins: int = 9) -> void:
	app.load_state({"hired": true, "hire_day": 53, "levels": levels, "board": lines, "morale": 3})
	box.coins = coins


func _at(day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	app.apply_minute(day, minute)
	npc.refresh()


func test_hire_only_through_hire_and_from_the_next_day() -> void:
	assert_false(app.is_hired())
	app.apply_minute(53, 600)
	assert_false(npc.is_present(), "not hired: never on the graveyard")
	app.hire()
	assert_true(app.is_hired())
	assert_true(GameState.flag_on(&"apprentice_hired"))
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 53)
	assert_eq(life.reaction_for(&"smith"), &"apprentice_hired", "event apprentice_hired")
	assert_false(app.works_today(53), "„ab morgen Lehrling“")
	assert_true(app.works_today(54))
	assert_eq(app.morale(), 3)
	app.hire()
	assert_eq(app.save_state().hire_day, 53, "idempotent")


func test_working_day_on_the_graveyard_npc() -> void:
	_hired()
	_at(54, 300)
	assert_false(npc.is_present(), "night / early morning: not there")
	_at(54, 500)
	assert_true(npc.is_present(), "08:20 on the way up")
	assert_true(npc.is_walking())
	assert_eq(app.board_minute(), 508, "08:25 at the earliest – here the walk up takes 13 min")
	_at(54, 509)
	assert_eq(npc.current_animation(), &"read_board", "reading the board")
	assert_eq(app.today_plan().size() > 0, true, "the plan is made when he reads the board")
	assert_eq(int(app.today_plan()[0].start), app.work_minute(), "work 5 min after the board")
	_at(54, 520)
	assert_true(npc.current_animation() in [&"rake", &"walk"], "at work (%s)" % npc.current_animation())
	_at(54, 945)
	assert_true(npc.is_present(), "15:45 leaving")
	_at(54, 1000)
	assert_false(npc.is_present(), "gone home")
	_at(54, 1300)
	assert_false(npc.is_present(), "never at night")
	assert_eq(GameState.get_stat(&"apprentice_days"), 1)


func test_days_off() -> void:
	_hired()
	_at(58, 600)
	assert_false(app.works_today(58), "58 % 7 == 2")
	assert_false(npc.is_present())
	var fest := FakeFestivals.new()
	world.add_child(fest)
	fest.days[&"fest_kathrein"] = 59
	_at(59, 600)
	assert_false(app.works_today(59), "festival day")
	assert_false(npc.is_present())
	_at(60, 600)
	assert_true(npc.is_present())


func test_board_three_lines_and_validation() -> void:
	_hired()
	app.set_board_lines([{"task": "rake", "area": "yard"}, {"task": "weed", "area": "nowhere"}, {"task": "dance", "area": "all"},
			{"task": "water", "area": "all"}, {"task": "candle", "area": "wished"}, {"task": "weed", "area": "linden"}] as Array[Dictionary])
	assert_eq(app.board_lines(), [{"task": "rake", "area": "yard"}, {"task": "water", "area": "all"}, {"task": "candle", "area": "wished"}],
			"known tasks and areas, at most 3")
	var lines := app.board_lines()
	lines[0].task = "weed"
	assert_eq(app.board_lines()[0].task, "rake", "a copy")


func test_effects_like_the_player_and_practice() -> void:
	_hired({"rake": 1, "weed": 1}, [{"task": "rake", "area": "yard"}])
	_at(54, 600)
	var plan := app.today_plan()
	var rakes := plan.filter(func(e: Dictionary) -> bool: return e.task == &"rake")
	assert_eq(rakes.map(func(e: Dictionary) -> String: return e.spot_id), ["dirt_a", "dirt_b", "dirt_c"], "nearest first")
	assert_eq(done_jobs.size(), 3, "all three done by 10:00")
	for e: Dictionary in rakes:
		var lvl := clean.level(e.spot_id)
		if not bool(e.mistake):
			assert_eq(lvl, 0, "%s tended like by the player" % e.spot_id)
	assert_eq(clean.level("dirt_w"), 2, "weeds not on the board")
	assert_eq(app.jobs(&"rake"), 3)
	assert_eq(GameState.get_stat(&"apprentice_jobs"), 3)
	# Practice: 12 own places → Geübt.
	app.load_state({"hired": true, "hire_day": 53, "levels": {"rake": 1}, "jobs": {"rake": 11},
			"board": [{"task": "rake", "area": "yard"}]})
	clean.set_level("dirt_a", 2)
	_at(55, 600)
	assert_eq(app.level(&"rake"), 2, "Geübt after 12")
	assert_has(levels_changed, [&"rake", 2])


func test_mistake_effects() -> void:
	# Find a day where the first rake place errs (deterministic).
	var cfg := Phase8Fixtures.apprentice_config()
	var day := 54
	while not ApprenticeRules.mistake(&"rake", "dirt_a", day, 1, false, cfg) or posmod(day, 7) == 2:
		day += 1
	_hired({"rake": 1}, [{"task": "rake", "area": "yard"}])
	TimeManager.set_time(day, 400)
	app.apply_minute(day, 400)
	clean.set_level("dirt_a", 1)
	clean.set_level("dirt_b", 0)
	clean.set_level("dirt_c", 0)
	var bubbles: Array = []
	var on_line := func(id: StringName, who: StringName, text: String) -> void: bubbles.append([id, who, text])
	EventBus.chatter_line.connect(on_line)
	_at(day, 540)
	EventBus.chatter_line.disconnect(on_line)
	assert_eq(done_jobs[0], [&"rake", "dirt_a", true], "day %d: the first place errs" % day)
	assert_eq(clean.level("dirt_a"), 0, "his place is clean")
	assert_eq(clean.level("dirt_b"), 1, "the leaves landed on the neighbour")
	assert_eq(app.mistakes_today(), 1)
	assert_eq(bubbles[0], [&"apprentice", &"apprentice", Phase8Fixtures.apprentice_task(&"rake").mistake_text], "a speech bubble")
	assert_eq(GameState.get_stat(&"apprentice_mistakes"), 1)
	# Scolding halves tomorrow's rate; only after a mistake.
	assert_true(app.scold())
	assert_false(app.praise(), "once per day")
	assert_true(app.scolded_yesterday(day + 1))
	assert_eq(app.morale(), 2)


func test_water_and_candle_through_grave_care() -> void:
	var cfg := Phase8Fixtures.apprentice_config()
	_hired({"water": 1, "candle": 1}, [{"task": "candle", "area": "all"}])
	for id: String in ["dirt_a", "dirt_b", "dirt_c", "dirt_w"]:
		clean.set_level(id, 0)
	# Direct effects (the planner of graves is covered in test_apprentice_planner).
	app._effect({"task": &"water", "spot_id": "old_01", "grave_id": "old_01", "mistake": false}, 54)
	assert_eq(care.watered, [["old_01", true]], "GraveCare.water(grave, by_apprentice)")
	app._effect({"task": &"water", "spot_id": "old_02", "grave_id": "old_02", "mistake": true}, 54)
	assert_eq(care.wilted, ["old_02"], "trodden: wilted at once")
	app._effect({"task": &"candle", "spot_id": "old_03", "grave_id": "old_03", "mistake": false}, 54)
	assert_eq([care.lit, box.storage.count(&"grave_candle")], [["old_03"], 3], "a candle from his box")
	app._effect({"task": &"candle", "spot_id": "old_04", "grave_id": "old_04", "mistake": true}, 54)
	assert_eq([care.lit, box.storage.count(&"grave_candle")], [["old_03", "old_04"], 1], "broken: one candle more, it burns anyway")
	care.flowers["old_05"] = &"fresh"
	app._effect({"task": &"weed", "spot_id": "dirt_w", "grave_id": "old_05", "mistake": true}, 54)
	assert_eq(care.torn, [], "nothing to weed: no effect at all")
	clean.set_level("dirt_w", 1)
	app._effect({"task": &"weed", "spot_id": "dirt_w", "grave_id": "old_05", "mistake": true}, 54)
	assert_eq(care.torn, ["old_05"], "weeding tears the fresh flowers")
	app._effect({"task": &"refill", "spot_id": "", "grave_id": "", "mistake": false}, 54)
	assert_eq(care.refills, 1)
	var visitors := FakeVisitors.new()
	world.add_child(visitors)
	visitors.active = [{"visit_id": "v1", "graves": ["old_06"]}] as Array[Dictionary]
	app._effect({"task": &"water", "spot_id": "old_06", "grave_id": "old_06", "mistake": false}, 54)
	assert_false(care.watered.has(["old_06", true]), "not where someone mourns")
	assert_eq(cfg.practice_jobs, 12)


func test_teaching_only_untrained_within_four_metres() -> void:
	_hired({"rake": 1}, [{"task": "rake", "area": "yard"}])
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	player.global_position = Vector3(2, 0, 2)
	_at(54, 515)
	assert_eq(app.teach_block_reason(&"rake", player), Apprentice.TEXT_KNOWS, "only Ungelernt")
	assert_eq(app.teach_block_reason(&"weed", player), "")
	player.global_position = Vector3(60, 0, 0)
	assert_eq(app.teach_block_reason(&"weed", player), Apprentice.TEXT_TOO_FAR, "≤ 30 m")
	player.global_position = Vector3(-5, 0, 1.5)
	app.start_teach(&"weed")
	assert_eq(app.teaching(), &"weed")
	assert_eq(app.teach_block_reason(&"weed", player), Apprentice.TEXT_WATCHING)
	_at(54, 530)
	assert_eq(npc.current_animation(), &"watch", "he comes and watches")
	assert_true(Vector2(npc.global_position.x - player.global_position.x, npc.global_position.z - player.global_position.z).length() <= 2.2,
			"within 2 m")
	app.note_player_job(&"leaves", player.global_position)
	assert_eq(app.level(&"weed"), 0, "a different job")
	app.note_player_job(&"weeds", Vector3(30, 0, 0))
	assert_eq(app.level(&"weed"), 0, "too far from him")
	clean.tend("dirt_w", player.inventory)
	assert_eq(app.level(&"weed"), 1, "the player's weeding next to him: Angelernt")
	assert_eq(levels_changed, [[&"weed", 1]])
	assert_eq(app.teaching(), &"")
	_at(54, 540)
	assert_ne(npc.current_animation(), &"watch", "back to the list")
	player.queue_free()


func test_wage_unpaid_days_and_return() -> void:
	_hired({"rake": 1}, [], 4)
	rel.meet(&"innkeeper")
	var rosine_before := rel.value(&"innkeeper")
	_at(54, 935)
	assert_eq([box.coins, app.unpaid_days()], [1, 0], "15:30: 3 from the tin")
	assert_eq(GameState.get_stat(&"coins_spent_apprentice"), 3)
	assert_eq(GameState.get_stat(&"apprentice_wage"), 3)
	_at(55, 935)
	assert_eq([box.coins, app.unpaid_days(), app.debt()], [1, 1, 3], "not enough: unpaid")
	assert_eq(rel.value(&"innkeeper"), rosine_before - 2, "Rosine −2")
	assert_eq(app.morale(), 1, "morale −2")
	_at(56, 935)
	_at(57, 935)
	assert_eq(app.unpaid_days(), 3)
	_at(59, 600)
	assert_false(app.works_today(59), "after 3 unpaid days at home")
	assert_false(npc.is_present())
	box.coins = 9
	_at(59, 900)
	assert_false(app.works_today(59), "comes only the next morning")
	_at(60, 400)
	assert_true(app.works_today(60), "the debt paid in the morning")
	assert_eq([box.coins, app.unpaid_days(), app.debt()], [0, 0, 0])
	_at(60, 935)
	assert_eq(app.unpaid_days(), 1, "and today unpaid again")


func test_praise_and_morale() -> void:
	_hired()
	assert_false(app.scold(), "no mistake: nothing to scold")
	assert_true(app.praise())
	assert_eq(app.morale(), 4)
	assert_false(app.praise(), "once per day")
	TimeManager.set_time(54, 600)
	app.praise()
	TimeManager.set_time(55, 600)
	app.praise()
	assert_eq(app.morale(), 5, "0…5")


func test_save_load_in_the_middle_of_a_place() -> void:
	_hired({"rake": 1}, [{"task": "rake", "area": "yard"}])
	_at(54, 517)
	var state := app.save_state()
	var pos := npc.global_position
	var anim := npc.current_animation()
	var back := JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(state)))) as Dictionary
	var other := Apprentice.new()
	other.config = Phase8Fixtures.apprentice_config()
	other.tasks = app.tasks
	app.free()
	world.add_child(other)
	other.load_state(back)
	other.post_load()
	npc.refresh()
	assert_eq(other.save_state(), state, "roundtrip identical")
	assert_eq(npc.global_position, pos, "the same spot from plan + clock")
	assert_eq(npc.current_animation(), anim)
	_at_other(other, 54, 700)
	assert_eq(other.jobs(&"rake"), 3, "works on after the load")


func _at_other(a: Apprentice, day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	a.apply_minute(day, minute)


func test_limits() -> void:
	_hired({"rake": 2, "weed": 2, "water": 2, "candle": 2}, [{"task": "rake", "area": "all"}, {"task": "weed", "area": "all"},
			{"task": "candle", "area": "all"}])
	_at(54, 600)
	for e: Dictionary in app.today_plan():
		assert_true(StringName(str(e.task)) in Apprentice.TASKS or StringName(str(e.task)) in [&"refill", &"lunch", &"sweep"],
				"only care work (%s)" % e.task)
	var source := (load("res://src/systems/apprentice/apprentice.gd") as GDScript).source_code
	for forbidden: String in ["corpse_manager", "&\"buildings\"", "&\"workshop\"", ".dig(", ".bury(", "place_marker", "&\"stations\""]:
		assert_false(source.contains(forbidden), "§2.5.6: no %s" % forbidden)
	var sched := app.graveyard_schedule(54)
	for e: ScheduleEntry in sched.entries:
		if e.visible:
			assert_true(e.start_minute >= 495 and e.start_minute <= 950, "only by day (%d)" % e.start_minute)


func test_orders_first_day_and_day_off() -> void:
	var orders := FakeOrders.new()
	world.add_child(orders)
	_hired({"rake": 1}, [], 9)
	_at(54, 900)
	assert_eq(orders.tasks, [], "not before 15:30")
	_at(54, 935)
	assert_eq(orders.tasks, [&"apprentice_first_day"], "P4 of_rosine_1: the first working day")
	_at(55, 935)
	assert_eq(orders.tasks, [&"apprentice_first_day"], "only once")
	_at(58, 600)
	assert_eq(orders.tasks.size(), 1)
	_at(58, 935)
	assert_eq(orders.tasks, [&"apprentice_first_day", &"jakob_day_off"], "P4 of_rosine_return_2: a day off")
	app.apply_minute(58, 940)
	assert_eq(orders.tasks.size(), 2, "once per day off")
	assert_true(app.save_state().first_day_done)
