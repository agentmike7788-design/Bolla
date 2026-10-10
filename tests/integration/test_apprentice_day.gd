extends TestCase
## P3 (docs/PHASE8_DESIGN.md §2.5, §10 Integration): Jakob's whole working day on the real graveyard – the
## v6 fixture slot_p7_day53_neighbor (Lindenacker full) through the real SaveManager; the Phase-8 pieces W-Welt
## places in W2 (Apprentice under Systems, npc_apprentice, his box, the hut-corner waypoints) are added here.
## Board „Laub Alter Hof · Unkraut Lindenacker": he walks (never more than 3.2 m per game minute, no jump
## after he appeared at the road end), the rake shows only while raking (show_with meta), the care spots are
## clean afterwards, the planned mistakes happen, the wage comes out of the tin at 15:30. Roundtrip at 10:17 in
## the middle of a place (collect_state → JSON → apply_state): the rest of the day is bit-identical.

const TIMEOUT := 300.0
const SLOT := 5
## The working day of the test (fixed seed: on day 57 the rake place dirt_y10 goes wrong).
const WORK_DAY := 57
const ROUND_DAY := 55
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const BOX_SCENE := "res://src/entities/apprentice_box/apprentice_box.tscn"
## Jakob's rake (the child mesh of ph_chr_apprentice).
const RAKE := "rake"
const ITEMS: Array[StringName] = [&"apprentice_rake", &"watering_can", &"grave_candle"]
## The hut corner (hut at (-5.6 | -7.2), door towards the camera) – W-Welt §4.3 places the real ones.
const CORNER := {"apprentice_board": Vector3(-3.4, 0, -4.6), "apprentice_box": Vector3(-2.6, 0, -4.4),
		"apprentice_lunch": Vector3(-4.4, 0, -4.2), "apprentice_sweep": Vector3(-3.6, 0, -3.2), "rain_barrel": Vector3(-7.6, 0, -5.2),
		"gate_inside": Vector3(1.6, 0, 10.2)}

var saves_dir := TestCase.user_dir("test_apprentice_day")
var world: WorldRoot
var app: Apprentice
var npc: Npc
var box: ApprenticeBox
var injected: Array[StringName] = []
var jobs: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	for id: StringName in ITEMS:
		if not Database.has_item(id):
			Database._items[id] = load("res://tests/fixtures/items/%s.tres" % id)
			injected.append(id)
	jobs.clear()
	EventBus.apprentice_job_done.connect(_on_job)


func after_each() -> void:
	EventBus.apprentice_job_done.disconnect(_on_job)
	for id: StringName in injected:
		Database._items.erase(id)
	injected.clear()
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _on_job(task: StringName, spot: String, mistake: bool) -> void:
	jobs.append([task, spot, mistake])


func _setup() -> void:
	assert_eq(Phase8Fixtures.install_save_v6("slot_p7_day53_neighbor", saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, "v6 fixture loads")
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	# W-Welt (W2) builds the hut corner, npc_apprentice (Jakob's model, the tools as show_with extras), his box and
	# Systems/Apprentice into the world – the test uses them; the stand-ins only for a world without them.
	var wps := world.get_node("Waypoints")
	for id: String in CORNER:
		if wps.get_node_or_null(id) != null:
			continue
		var m := Marker3D.new()
		m.name = id
		m.position = CORNER[id]
		wps.add_child(m)
	npc = world.get_node_or_null("Entities/npc_apprentice") as Npc
	if npc == null:
		# A stand-in figure with the tool meshes on show_with (P5 delivers Jakob's model with the same metas).
		var model := Node3D.new()
		model.name = "Model"
		for spec: Array in [[RAKE, ["rake"]], ["watering_can", ["water", "carry_can_walk"]], ["broom", ["sweep"]]]:
			var mesh := MeshInstance3D.new()
			mesh.name = spec[0]
			mesh.set_meta(&"show_with", PackedStringArray(spec[1]))
			model.add_child(mesh)
		npc = (load(NPC_SCENE) as PackedScene).instantiate() as Npc
		npc.name = "npc_apprentice"
		npc.npc_id = &"apprentice"
		npc.region_id = &"graveyard"
		npc.add_child(model)
		world.get_node("Entities").add_child(npc)
	box = world.get_node_or_null("Entities/apprentice_box") as ApprenticeBox
	if box == null:
		box = (load(BOX_SCENE) as PackedScene).instantiate() as ApprenticeBox
		box.name = "apprentice_box"
		box.position = CORNER.apprentice_box
		world.get_node("Entities").add_child(box)
	app = world.get_node_or_null("Systems/Apprentice") as Apprentice
	if app == null:
		app = Apprentice.new()
		app.name = "Apprentice"
		world.get_node("Systems").add_child(app)
	await wait_frames(1)
	box.storage.add_item(&"apprentice_rake", 1)
	box.coins = 9
	app.hire()
	app.load_state({"hired": true, "hire_day": 53, "levels": {"rake": 1, "weed": 1}, "jobs": {},
			"board": [{"task": "rake", "area": "yard"}, {"task": "weed", "area": "linden"}], "morale": 3})
	assert_true(app.is_hired())


## Minute by minute from (day, from) to (day, to): positions per minute.
func _run(day: int, from: int, to: int, trace: Array) -> void:
	TimeManager.set_time(day, from)
	for minute: int in range(from, to + 1):
		if TimeManager.minute_of_day != minute:
			TimeManager.advance(1)
		npc.refresh()
		trace.append([minute, npc.is_present(), npc.global_position, npc.current_animation(), npc.prop_shown(RAKE),
				npc.is_walking()])


func test_a_whole_working_day() -> void:
	await _setup()
	var clean := tree.get_first_node_in_group(&"cleanliness")
	var trace: Array = []
	await wait_frames(1)
	_run(WORK_DAY, 470, 1000, trace)
	var plan := app.today_plan()
	var work: Array = plan.filter(func(e: Dictionary) -> bool: return StringName(str(e.task)) in Apprentice.TASKS)
	assert_true(work.size() >= 6, "a day's work (%d places)" % work.size())
	assert_true(work.any(func(e: Dictionary) -> bool: return e.task == &"rake"), "leaves in the Alter Hof")
	assert_true(work.any(func(e: Dictionary) -> bool: return e.task == &"weed"), "weeds in the Lindenacker")
	for e: Dictionary in work:
		var spot := world.find_child(str(e.spot_id), true, false) as DirtSpot
		if e.task == &"rake":
			assert_true(spot != null and spot.section_id == &"yard" and spot.kind == &"leaves", str(e.spot_id))
		else:
			assert_true(spot != null and spot.section_id == &"linden" and spot.kind == &"weeds", str(e.spot_id))
	# Real walking: from the road end on never more than 3.2 m per game minute.
	var appeared := -1
	for i: int in range(1, trace.size()):
		var a: Array = trace[i - 1]
		var b: Array = trace[i]
		if not b[1]:
			continue
		if appeared < 0:
			appeared = b[0]
			assert_true(Vector2(b[2].x - 15.8, b[2].z - 32.6).length() < 3.5, "he appears at the road end")
			continue
		if a[1]:
			var step := Vector2(b[2].x - a[2].x, b[2].z - a[2].z).length()
			assert_true(step <= 3.2 * 1.05 + 0.01, "minute %d: %.2f m – no teleport" % [b[0], step])
	assert_eq(appeared, 495, "08:15 at the road end")
	# The rake in his hands only while raking.
	var raking := trace.filter(func(t: Array) -> bool: return t[3] == &"rake")
	assert_false(raking.is_empty(), "he rakes")
	for t: Array in trace:
		if t[1]:
			assert_eq(t[4], t[3] == &"rake", "minute %d: rake shown = raking (%s)" % [t[0], t[3]])
	# Effects at the care spots, the planned mistakes, the job counts.
	var mistakes := 0
	for e: Dictionary in work:
		if bool(e.mistake):
			mistakes += 1
	var done_mistakes := jobs.filter(func(j: Array) -> bool: return j[2]).size()
	assert_eq(jobs.size(), work.size(), "every place done")
	for e: Dictionary in work:
		if not bool(e.mistake) and e.task == &"weed":
			assert_eq(int(clean.call(&"level", str(e.spot_id))), 0, "%s clean" % e.spot_id)
	assert_true(done_mistakes <= mistakes, "mistakes as planned (%d / %d)" % [done_mistakes, mistakes])
	assert_eq([done_mistakes, mistakes], [1, 1], "the fixed seed: one mistake (dirt_y10)")
	assert_eq(jobs.filter(func(j: Array) -> bool: return j[2])[0], [&"rake", "dirt_y10", true])
	assert_eq(app.mistakes_today(), done_mistakes)
	# The wage at 15:30 and home.
	assert_eq([box.coins, app.unpaid_days()], [6, 0], "3 coins out of the tin")
	assert_eq(GameState.get_stat(&"coins_spent_apprentice"), 3)
	assert_false(trace[trace.size() - 1][1], "gone home by 16:40")


func test_roundtrip_in_the_middle_of_a_place() -> void:
	await _setup()
	await wait_frames(1)
	var trace: Array = []
	# Day 55: with Systems/Festivals in the world, day 54 is the Kathreintanz – Jakob's free day (§2.5.1).
	_run(ROUND_DAY, 470, 617, trace)
	var plan := app.today_plan()
	var running: Array = plan.filter(func(e: Dictionary) -> bool: return int(e.start) <= 617 and int(e.end) > 617 and StringName(str(e.task)) in Apprentice.TASKS)
	assert_eq(running.size(), 1, "10:17 is in the middle of a place")
	var saved := SaveManager.collect_state()
	var json := JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved)))) as Dictionary
	var pos := npc.global_position
	var first: Array = []
	_run(ROUND_DAY, 618, 960, first)
	var end_a := SaveManager.collect_state()
	var jobs_a := jobs.duplicate()
	# Back to 10:17 through the save state: the rest of the day again, bit-identical.
	SaveManager.apply_state(json)
	npc.refresh()
	assert_eq(SaveManager.collect_state(), saved, "roundtrip at 10:17 identical")
	assert_eq(npc.global_position, pos, "the same spot from plan + clock")
	jobs.clear()
	var second: Array = []
	_run(ROUND_DAY, 618, 960, second)
	assert_eq(second, first, "every minute after the load as before")
	assert_eq(SaveManager.collect_state(), end_a, "the evening state bit-identical")
	assert_eq(jobs, jobs_a.slice(jobs_a.size() - jobs.size()), "the same places afterwards")
