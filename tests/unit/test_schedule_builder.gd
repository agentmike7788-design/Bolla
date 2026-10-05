extends TestCase
## P1 (docs/PHASE8_DESIGN.md §3.4, §10): ScheduleBuilder and the Npc's runtime schedule – walking time
## from the polyline (3.2 m per game minute), gaps invisible, the runtime schedule replaces the data
## schedule and gives it back, save / load without plan data places the figure bit-identically (plan +
## clock), an Npc without a plan is hidden, and the show_with / hide_with / hide_after child meshes.

const NPC_SCENE := "res://src/entities/npc/npc.tscn"

var world: Node3D
var graveyard: RegionRoot
var holder: Node3D


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(TimeManager.day, 480)
	ScheduleBuilder.walk_speed_override = 0.0
	world = Node3D.new()
	world.name = "P8SchedWorld"
	tree.root.add_child(world)
	graveyard = Phase7Fixtures.region_at(&"graveyard")
	graveyard.name = "Graveyard"
	graveyard.config = graveyard.config.duplicate() as RegionConfig
	graveyard.config.managed_paths = PackedStringArray()
	world.add_child(graveyard)
	holder = Node3D.new()
	holder.name = "Waypoints"
	graveyard.add_child(holder)
	_wp("road_end", Vector3(0, 0, 0))
	_wp("gate", Vector3(16, 0, 0))
	_wp("grave", Vector3(16, 0, 16))
	_wp("home", Vector3(-5, 0, -5))
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


func _wp(id: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = id
	m.position = pos
	holder.add_child(m)


func _npc(id: String, data_entries: Array[ScheduleEntry] = [], model: Node3D = null) -> Npc:
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	npc.region_id = &"graveyard"
	var sched := NpcSchedule.new()
	sched.npc_id = npc.npc_id
	sched.display_name = "Martha Kehr"
	sched.entries = data_entries
	npc.schedule = sched
	if model != null:
		npc.add_child(model)
	graveyard.add_child(npc)
	return npc


func _visit() -> NpcSchedule:
	var entries: Array[ScheduleEntry] = [
		ScheduleBuilder.stay(&"grave", 600, &"kneel-loop", &"kin_kehr"),
		ScheduleBuilder.walk(&"road_end", PackedStringArray(["gate", "grave"]), 570, &"graveyard", graveyard),
		ScheduleBuilder.stay(&"grave", 590, &"lay_flowers"),
		ScheduleBuilder.walk(&"grave", PackedStringArray(["gate", "road_end"]), 630, &"graveyard", graveyard),
	]
	return ScheduleBuilder.build(entries)


func test_walk_minutes_from_the_polyline() -> void:
	var e := ScheduleBuilder.walk(&"road_end", PackedStringArray(["gate", "grave"]), 570, &"graveyard", graveyard)
	assert_eq(e.path, PackedStringArray(["road_end", "gate", "grave"]), "from_wp first")
	assert_eq(e.travel_minutes, 10, "32 m / 3.2 m per minute")
	assert_eq([e.start_minute, e.activity, e.region], [570, &"walk", &""], "graveyard = the empty region")
	var same := ScheduleBuilder.walk(&"road_end", PackedStringArray(["road_end", "gate"]), 0, &"village", graveyard)
	assert_eq(same.path, PackedStringArray(["road_end", "gate"]), "from_wp not doubled")
	assert_eq([same.travel_minutes, same.region], [5, &"village"])
	assert_eq(ScheduleBuilder.walk(&"gate", PackedStringArray(), 0, &"", graveyard).travel_minutes, 0, "no distance")
	assert_eq(ScheduleBuilder.travel_minutes(PackedStringArray(["road_end", "home"]), graveyard), 3, "7.07 m → at least, rounded up")
	assert_eq(ScheduleBuilder.travel_minutes(PackedStringArray(["road_end", "gate"]), null), 0, "no world")
	ScheduleBuilder.walk_speed_override = 1.6
	assert_eq(ScheduleBuilder.travel_minutes(PackedStringArray(["road_end", "gate"]), graveyard), 10, "NpcConfig speed")
	ScheduleBuilder.walk_speed_override = 0.0
	assert_almost((Database.config(&"npc_config") as NpcConfig).walk_m_per_minute, 3.2)
	var s := ScheduleBuilder.stay(&"grave", 1500, &"", &"kin_kehr", false)
	assert_eq([s.start_minute, s.animation, s.visible, s.dialogue_id, s.path], [60, &"idle", false, &"kin_kehr",
			PackedStringArray(["grave"])])


func test_build_sorts_and_gaps_are_invisible() -> void:
	var sched := _visit()
	var starts: Array = sched.entries.map(func(e: ScheduleEntry) -> int: return e.start_minute)
	assert_eq(starts, [0, 570, 590, 600, 630, 640], "sorted, a hidden start and a hidden end")
	assert_false(sched.entries[0].visible, "before the first entry: invisible")
	assert_eq(sched.entries[0].path, PackedStringArray(["road_end"]))
	assert_false(sched.entries[5].visible, "after the closing walk: gone")
	assert_eq(sched.entries[5].path, PackedStringArray(["road_end"]))
	assert_eq(ScheduleResolver.entry_at(sched, 300).visible, false)
	assert_eq(ScheduleResolver.entry_at(sched, 1400).visible, false, "late evening: gone")
	assert_eq(ScheduleResolver.entry_at(sched, 605).animation, &"kneel-loop")
	# Equal starts keep their order (the later wins in ScheduleResolver).
	var tie := ScheduleBuilder.build([ScheduleBuilder.stay(&"gate", 0, &"idle"), ScheduleBuilder.stay(&"gate", 0, &"talk")] as Array[ScheduleEntry])
	assert_eq(tie.entries.size(), 2, "no gap before an entry at 00:00")
	assert_eq(ScheduleResolver.entry_at(tie, 10).animation, &"talk")
	assert_eq(ScheduleBuilder.build([] as Array[ScheduleEntry]).entries.size(), 0)
	# Stays without a region follow the walk's region.
	var v := ScheduleBuilder.build([ScheduleBuilder.walk(&"road_end", PackedStringArray(["gate"]), 100, &"village", graveyard),
			ScheduleBuilder.stay(&"gate", 200, &"idle")] as Array[ScheduleEntry])
	for e: ScheduleEntry in v.entries:
		assert_eq(e.region, &"village")


func test_runtime_schedule_replaces_and_returns() -> void:
	var home := ScheduleEntry.new()
	home.path = PackedStringArray(["home"])
	home.dialogue_id = &"v_innkeeper"
	var npc := _npc("kehr", [home] as Array[ScheduleEntry])
	await wait_frames(1)
	TimeManager.set_time(TimeManager.day, 575)
	npc.refresh()
	assert_almost(npc.global_position.x, -5.0, 0.01, "the data schedule")
	assert_true(npc.is_present())
	npc.set_runtime_schedule(_visit())
	assert_not_null(npc.runtime_schedule())
	assert_true(npc.is_walking(), "05 min into the walk")
	assert_almost(npc.global_position.x, 16.0, 0.01, "16 m along at 3.2 m/min")
	assert_almost(npc.global_position.z, 0.0, 0.01)
	assert_false(npc.is_talkable(), "walking: no talk")
	TimeManager.set_time(TimeManager.day, 610)
	npc.refresh()
	assert_almost(npc.global_position.z, 16.0, 0.01, "kneels at the grave")
	assert_eq(npc.current_animation(), &"kneel-loop")
	assert_true(npc.is_talkable())
	assert_eq(npc.entry.dialogue_id, &"kin_kehr")
	assert_eq(npc.first_name(), "Martha", "display name from the data schedule")
	TimeManager.set_time(TimeManager.day, 700)
	npc.refresh()
	assert_false(npc.is_present(), "gone after the closing walk")
	npc.clear_runtime_schedule()
	assert_null(npc.runtime_schedule())
	assert_true(npc.is_present(), "back to the data schedule")
	assert_almost(npc.global_position.x, -5.0, 0.01)
	npc.set_runtime_schedule(null)
	assert_true(npc.is_present(), "null = clear")


func test_npc_without_a_plan_is_hidden() -> void:
	var npc := _npc("apprentice")
	await wait_frames(1)
	assert_false(npc.is_present(), "§3.1: without a plan invisible")
	assert_false(npc.is_talkable())
	npc.set_runtime_schedule(ScheduleBuilder.build([ScheduleBuilder.stay(&"gate", 0, &"idle", &"v_apprentice")] as Array[ScheduleEntry]))
	assert_true(npc.is_present())
	assert_almost(npc.global_position.x, 16.0, 0.01)
	npc.clear_runtime_schedule()
	assert_false(npc.is_present(), "plan cleared: hidden again")


func test_save_load_without_plan_data_is_bit_identical() -> void:
	var npc := _npc("kehr2")
	await wait_frames(1)
	TimeManager.set_time(TimeManager.day, 577)
	npc.set_runtime_schedule(_visit())
	var before := [npc.global_position, npc.rotation.y, npc.is_present(), npc.current_animation()]
	assert_eq(npc.save_state(), {}, "nothing saved")
	# A load: the Npc forgets, the owner rebuilds the plan from its saved state + the clock.
	npc.clear_runtime_schedule()
	npc.load_state({})
	npc.set_runtime_schedule(_visit())
	var after := [npc.global_position, npc.rotation.y, npc.is_present(), npc.current_animation()]
	assert_eq(after, before, "positions from plan + clock")


func test_show_with_child_meshes() -> void:
	var model := Node3D.new()
	model.name = "Model"
	var hat_hand := MeshInstance3D.new()
	hat_hand.name = "hat_hand"
	hat_hand.set_meta(&"show_with", PackedStringArray(["mourn_stand-loop", "kneel-loop"]))
	model.add_child(hat_hand)
	var hat_head := MeshInstance3D.new()
	hat_head.name = "hat_head"
	hat_head.set_meta(&"hide_with", "mourn_stand-loop, kneel-loop")
	model.add_child(hat_head)
	var bouquet := MeshInstance3D.new()
	bouquet.name = "bouquet"
	bouquet.set_meta(&"show_with", ["walk", "idle", "lay_flowers"])
	bouquet.set_meta(&"hide_after", "lay_flowers")
	model.add_child(bouquet)
	var plain := MeshInstance3D.new()
	plain.name = "body"
	model.add_child(plain)
	var npc := _npc("kehr3", [], model)
	await wait_frames(1)
	var count := model.get_child_count()
	TimeManager.set_time(TimeManager.day, 575)
	npc.set_runtime_schedule(_visit())
	assert_eq(npc.current_animation(), &"walk")
	assert_eq([npc.prop_shown("hat_hand"), npc.prop_shown("hat_head"), npc.prop_shown("bouquet")], [false, true, true], "walking up")
	TimeManager.set_time(TimeManager.day, 595)
	npc.refresh()
	assert_eq(npc.current_animation(), &"lay_flowers")
	assert_true(npc.prop_shown("bouquet"), "until the end of lay_flowers")
	TimeManager.set_time(TimeManager.day, 610)
	npc.refresh()
	assert_eq([npc.prop_shown("hat_hand"), npc.prop_shown("hat_head"), npc.prop_shown("bouquet")], [true, false, false], "kneeling")
	TimeManager.set_time(TimeManager.day, 633)
	npc.refresh()
	assert_eq(npc.current_animation(), &"walk")
	assert_eq([npc.prop_shown("hat_hand"), npc.prop_shown("hat_head"), npc.prop_shown("bouquet")], [false, true, false],
			"walking home: the bouquet stays on the grave")
	assert_true(plain.visible, "meshes without the meta are untouched")
	assert_eq(model.get_child_count(), count, "no new nodes at runtime")
