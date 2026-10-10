extends TestCase
## P1 (docs/PHASE8_DESIGN.md §2.1.2, §3.4, §10): ChatterRunner – a chatter starts only when both speakers
## stand at the place and the gravekeeper is ≤ 10 m away in the same region (and in no dialogue), one at a
## time per region, once per day (NpcLife's list), its conditions (dialogue syntax + mood / p8_open /
## open_days_gte / sick_light …), the lines every 3.5 s alternating, the speakers turn to each other,
## ch_rumor_robber sets robber_known, and from village_open on (a Phase-7 state) it runs without changing
## any game value. Chatters from tests/fixtures/phase8 (Phase8Fixtures).

const NPC_SCENE := "res://src/entities/npc/npc.tscn"

var world: Node3D
var village: RegionRoot
var holder: Node3D
var runner: ChatterRunner
var life: NpcLife
var lines: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.day = 55
	TimeManager.minute_of_day = 965
	GameState.set_flag(&"village_open", true)
	world = Node3D.new()
	world.name = "P8ChatterWorld"
	tree.root.add_child(world)
	village = Phase7Fixtures.region_at(&"village")
	village.name = "Village"
	village.hide_when_inactive = false
	world.add_child(village)
	holder = Node3D.new()
	holder.name = "Waypoints"
	village.add_child(holder)
	for spec: Array in [["v_well", Vector3(0, 0, 0)], ["v_well_b", Vector3(1.5, 0, 0)], ["v_inn", Vector3(30, 0, 0)],
			["v_inn_b", Vector3(31, 0, 0)], ["v_far", Vector3(60, 0, 0)]]:
		var m := Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		holder.add_child(m)
	life = NpcLife.new()
	life.config = Phase8Fixtures.npc_life_config()
	world.add_child(life)
	runner = ChatterRunner.new()
	runner.config = Phase8Fixtures.npc_life_config()
	runner.region_override = &"village"
	runner.player_override = Vector3(5, 0, 0)
	world.add_child(runner)
	runner.set_process(false)
	lines.clear()
	EventBus.chatter_line.connect(_on_line)
	await wait_frames(1)


func after_each() -> void:
	EventBus.chatter_line.disconnect(_on_line)
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


func _on_line(id: StringName, npc_id: StringName, text: String) -> void:
	lines.append([id, npc_id, text])


func _npc(id: String, wp: String) -> Npc:
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	npc.region_id = &"village"
	var sched := NpcSchedule.new()
	sched.npc_id = npc.npc_id
	var e := ScheduleEntry.new()
	e.path = PackedStringArray([wp])
	e.region = &"village"
	e.dialogue_id = StringName("v_" + id)
	sched.entries = [e]
	npc.schedule = sched
	village.add_child(npc)
	return npc


## ch_well_spin (Theres · Liesel, v_well 16:00–16:30) moved to the test waypoint.
func _spin() -> ChatterData:
	var c := Phase8Fixtures.chatter(&"ch_well_spin").duplicate() as ChatterData
	c.place = &"v_well"
	return c


func test_starts_only_with_both_present_and_the_player_near() -> void:
	runner.chatters = [_spin()] as Array[ChatterData]
	var theres := _npc("grocer", "v_well")
	await wait_frames(1)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "Liesel is missing")
	var liesel := _npc("washer", "v_inn")
	await wait_frames(1)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "Liesel is not at the place")
	liesel.free()
	liesel = _npc("washer", "v_well_b")
	await wait_frames(1)
	runner.player_override = Vector3(10.5, 0, 0)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "10.5 m: too far")
	runner.player_override = Vector3(0, 0, 9.5)
	runner.region_override = &"graveyard"
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "the gravekeeper in another region")
	runner.region_override = &"village"
	EventBus.ui_modal_changed.emit(true)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "in a dialogue")
	EventBus.ui_modal_changed.emit(false)
	TimeManager.minute_of_day = 990
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "outside the window (16:00–16:30)")
	TimeManager.minute_of_day = 965
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_well_spin")
	assert_eq(lines.size(), 1)
	assert_eq(lines[0], [&"ch_well_spin", &"grocer", "Du spinnst zu dünn, Dorn. Das reißt."])
	assert_eq(theres.chatter_target(), liesel, "they turn to each other")
	assert_eq(liesel.chatter_target(), theres)
	assert_eq(theres.current_animation(), &"talk")


func test_lines_every_three_and_a_half_seconds_once_per_day() -> void:
	runner.chatters = [_spin()] as Array[ChatterData]
	var theres := _npc("grocer", "v_well")
	var liesel := _npc("washer", "v_well_b")
	await wait_frames(1)
	runner.update_now()
	runner.advance(3.4)
	assert_eq(lines.size(), 1)
	runner.advance(0.2)
	assert_eq(lines.size(), 2)
	assert_eq(lines[1], [&"ch_well_spin", &"washer", "Für die Toten reicht's. Die ziehen nicht dran."], "alternating a / b")
	var total := runner.chatters[0].lines.size()
	runner.advance(3.5 * total)
	assert_eq(lines.size(), total, "every line once")
	assert_eq(runner.running(&"village"), &"", "ended")
	assert_null(theres.chatter_target(), "they turn back")
	assert_null(liesel.chatter_target())
	assert_true(runner.seen_today(&"ch_well_spin"))
	assert_true(life.chatter_seen_today(&"ch_well_spin"), "the list lives in NpcLife")
	runner.update_now()
	assert_eq(lines.size(), total, "once per day")
	TimeManager.day = 56
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_well_spin", "the next day again")


func test_one_chatter_per_region_and_a_speaker_leaving_ends_it() -> void:
	var second := _spin()
	second.id = &"ch_second"
	second.npcs = [&"smith", &"mayor"] as Array[StringName]
	runner.chatters = [_spin(), second] as Array[ChatterData]
	_npc("grocer", "v_well")
	var liesel := _npc("washer", "v_well_b")
	_npc("smith", "v_well")
	_npc("mayor", "v_well_b")
	await wait_frames(1)
	runner.update_now()
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_well_spin")
	assert_eq(lines.size(), 1, "one at a time per region")
	liesel.set_runtime_schedule(ScheduleBuilder.build([ScheduleBuilder.stay(&"v_well_b", 0, &"idle", &"", false)] as Array[ScheduleEntry]))
	runner.update_now()
	assert_ne(runner.running(&"village"), &"ch_well_spin", "Liesel gone: the chatter ends")
	assert_eq(runner.running(&"village"), &"ch_second", "the next one may start")


func test_conditions_and_rumor_sets_robber_known() -> void:
	var rumor := Phase8Fixtures.chatter(&"ch_rumor_robber").duplicate() as ChatterData
	rumor.place = &"v_inn"
	rumor.window = Vector2i(0, 1440)
	runner.chatters = [rumor] as Array[ChatterData]
	runner.player_override = Vector3(30, 0, 3)
	_npc("carter", "v_inn")
	_npc("innkeeper", "v_inn_b")
	await wait_frames(1)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "p8_open missing")
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", 54)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "open_days_gte:2 – only one day open")
	GameState.set_flag(&"p8_open_day", 53)
	assert_false(GameState.flag_on(&"robber_known"))
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_rumor_robber")
	assert_true(GameState.flag_on(&"robber_known"), "§2.6.3: sets robber_known")
	assert_eq(GameState.get_stat(&"chatters_seen"), 1, "counted from p8_open")
	var c := ChatterData.new()
	for spec: Array in [[["mood:grocer:low"], false], [["!mood:grocer:low"], true], [["p8_open"], true], [["flag:robber_known"], true],
			[["flag:nope"], false], [["apprentice_hired"], false], [["sick_light"], false], [["fest_eve:fest_lights"], false],
			[["open_days_gte:2", "!flag:nope"], true]]:
		c.conditions = PackedStringArray(spec[0])
		life.set_mood(&"grocer", &"plain")
		assert_eq(runner.conditions_met(c), spec[1], str(spec[0]))
	life.set_mood(&"grocer", &"low")
	c.conditions = PackedStringArray(["mood:grocer:low"])
	assert_true(runner.conditions_met(c))
	GameState.set_flag(&"apprentice_hired", true)
	c.conditions = PackedStringArray(["apprentice_hired"])
	assert_true(runner.conditions_met(c))


func test_phase7_state_runs_without_changing_game_values() -> void:
	runner.chatters = [_spin()] as Array[ChatterData]
	_npc("grocer", "v_well")
	_npc("washer", "v_well_b")
	await wait_frames(1)
	GameState.set_flag(&"village_open", false)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "not before village_open")
	GameState.set_flag(&"village_open", true)
	var stats := GameState.stats.duplicate(true)
	var flags := GameState.flags.duplicate(true)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_well_spin", "§1.2: chatters run from village_open")
	runner.advance(30.0)
	assert_eq(GameState.stats, stats, "no stat changes on a Phase-7 state")
	assert_eq(GameState.flags, flags, "no flags")
	assert_false(runner.is_in_group(&"saveable"), "not saved")


func test_place_less_chatter_at_the_grave() -> void:
	var kehr := Phase8Fixtures.chatter(&"ch_grave_kehr").duplicate() as ChatterData
	kehr.region = &"village"
	kehr.window = Vector2i(0, 1440)
	kehr.conditions = PackedStringArray()
	runner.chatters = [kehr] as Array[ChatterData]
	runner.player_override = Vector3(30, 0, 5)
	var jakob := _npc("apprentice", "v_inn")
	var martha := _npc("kin_kehr", "v_far")
	await wait_frames(1)
	runner.update_now()
	assert_eq(runner.running(&"village"), &"", "30 m apart")
	martha.set_runtime_schedule(ScheduleBuilder.build([ScheduleBuilder.stay(&"v_inn_b", 0, &"kneel")] as Array[ScheduleEntry]))
	runner.update_now()
	assert_eq(runner.running(&"village"), &"ch_grave_kehr", "place \"\": the two near each other")
	assert_eq(lines[0][1], &"apprentice")
	assert_eq(jakob.chatter_target(), martha)
