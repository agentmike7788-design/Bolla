extends TestCase
## P1 (docs/PHASE7_DESIGN.md §3.4, §9, §10): NpcLod and the Npc's Phase-7 rules – ranking by distance to
## the camera focus, at most max_full on level 0, levels 0/1/2 (reduced evaluation, resting animation),
## Npc of another region → resting and evaluated once per game minute, region filter of the schedule
## entries, hide_flag, the remark nearness once per person and day. Config: Phase7Fixtures.npc_config().

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"


class FakeRelationships extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"relationships")

	func remark(npc_id: StringName) -> String:
		calls.append(npc_id)
		return "…"


var world: Node3D
var village: RegionRoot
var graveyard: RegionRoot
var player: Player
var lod: NpcLod


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	TimeManager.set_time(TimeManager.day, 600)
	world = Node3D.new()
	world.name = "P7LodWorld"
	tree.root.add_child(world)
	village = Phase7Fixtures.region_at(&"village")
	village.name = "Village"
	village.hide_when_inactive = false
	world.add_child(village)
	graveyard = Phase7Fixtures.region_at(&"graveyard")
	graveyard.name = "Graveyard"
	graveyard.config = graveyard.config.duplicate() as RegionConfig
	graveyard.config.managed_paths = PackedStringArray()
	world.add_child(graveyard)
	var holder := Node3D.new()
	holder.name = "Waypoints"
	village.add_child(holder)
	var gholder := Node3D.new()
	gholder.name = "Waypoints"
	graveyard.add_child(gholder)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	player.set_region(&"village")
	lod = NpcLod.new()
	lod.config = Phase7Fixtures.npc_config()
	lod.focus_override = Vector3.ZERO
	world.add_child(lod)
	lod.set_process(false)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


## An Npc of `region` standing at `pos` all day (entry region = `entry_region`, default its own).
func _npc(id: String, pos: Vector3, region: RegionRoot, entry_region: Variant = null, animated: bool = false) -> Npc:
	var wp := Marker3D.new()
	wp.name = "wp_" + id
	wp.position = pos
	region.get_node("Waypoints").add_child(wp)
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_" + id
	npc.npc_id = StringName(id)
	npc.region_id = region.region_id
	var sched := NpcSchedule.new()
	sched.npc_id = npc.npc_id
	sched.display_name = id
	var e := ScheduleEntry.new()
	e.path = PackedStringArray([String(wp.name)])
	e.dialogue_id = &"test"
	e.region = (&"" if region.region_id == &"graveyard" else region.region_id) if entry_region == null else entry_region
	sched.entries = [e]
	npc.schedule = sched
	if animated:
		var model := Node3D.new()
		model.name = "Model"
		var anim := AnimationPlayer.new()
		var library := AnimationLibrary.new()
		var idle := Animation.new()
		idle.length = 1.0
		idle.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(&"idle", idle)
		anim.add_animation_library(&"", library)
		model.add_child(anim)
		npc.add_child(model)
	region.add_child(npc)
	return npc


func _anim(npc: Npc) -> AnimationPlayer:
	return npc.get_node("Model").find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func test_ranking_and_max_full() -> void:
	var npcs: Array[Npc] = []
	for i: int in 8:
		npcs.append(_npc("near_%d" % i, Vector3(2.0 + i * 2.0, 0, 0), village))
	var mid := _npc("mid", Vector3(0, 0, 30), village)
	var far := _npc("far", Vector3(-45, 0, 0), village)
	await wait_frames(1)
	lod.update_now()
	for i: int in 8:
		assert_eq(lod.lod_of(npcs[i]), 0 if i < 6 else 1, "near_%d" % i)
		assert_eq(npcs[i].lod(), lod.lod_of(npcs[i]))
	assert_eq(lod.full_count(), 6, "§9: at most 6 fully animated")
	assert_eq(lod.lod_of(mid), 1, "30 m: reduced")
	assert_eq(lod.lod_of(far), 2, "beyond 40 m: resting")
	# The focus moves: the ranking follows.
	lod.focus_override = Vector3(-45, 0, 0)
	lod.update_now()
	assert_eq(lod.lod_of(far), 0)
	assert_eq(lod.lod_of(npcs[7]), 2, "near_7 is 61 m away now")
	lod.config = lod.config.duplicate() as NpcConfig
	lod.config.max_full = 4
	lod.focus_override = Vector3.ZERO
	lod.update_now()
	assert_eq(lod.full_count(), 4, "max_full from the config")


func test_other_region_and_hidden_rest() -> void:
	var here := _npc("here", Vector3(1, 0, 0), village)
	var there := _npc("there", Vector3(1, 0, 0), graveyard)
	var wrong := _npc("wrong", Vector3(2, 0, 0), village, &"")
	var gone := _npc("gone", Vector3(3, 0, 0), village)
	gone.hide_flag = &"hagedorn_dead"
	await wait_frames(1)
	assert_true(here.is_present())
	assert_false(wrong.is_present(), "a graveyard entry hides the village Npc")
	assert_true(there.is_present(), "the graveyard Npc shows its own entries")
	assert_true(gone.is_present())
	GameState.set_flag(&"hagedorn_dead", true)
	gone.refresh()
	assert_false(gone.is_present(), "hide_flag")
	assert_false(gone.is_talkable())
	lod.update_now()
	assert_eq([lod.lod_of(here), lod.lod_of(there), lod.lod_of(wrong), lod.lod_of(gone)], [0, 2, 2, 2])
	assert_false(there.region_active())
	assert_true(here.region_active())


func test_inactive_region_evaluates_once_per_minute_and_rests() -> void:
	var osric := _npc("osric", Vector3(4, 0, 0), graveyard, null, true)
	await wait_frames(1)
	player.set_region(&"graveyard")
	await wait_frames(2)
	assert_true(_anim(osric).is_playing(), "active region: animated")
	osric.global_position = Vector3(50, 0, 50)
	await wait_frames(1)
	assert_almost(osric.global_position.x, 4.0, 0.01, "active: evaluated every frame")
	player.set_region(&"village")
	assert_false(_anim(osric).is_playing(), "inactive region: the animation rests")
	await wait_frames(1)
	osric.global_position = Vector3(50, 0, 50)
	await wait_frames(3)
	assert_almost(osric.global_position.x, 50.0, 0.01, "inactive: not evaluated within the same minute")
	TimeManager.advance(1)
	await wait_frames(1)
	assert_almost(osric.global_position.x, 4.0, 0.01, "once per game minute")
	assert_false(_anim(osric).is_playing(), "still resting")
	player.set_region(&"graveyard")
	await wait_frames(1)
	assert_true(_anim(osric).is_playing(), "back in the region: animated again")


func test_levels_reduce_evaluation_and_pause_animation() -> void:
	var npc := _npc("lena", Vector3(3, 0, 0), village, null, true)
	await wait_frames(2)
	assert_true(_anim(npc).is_playing())
	var cfg := NpcConfig.new()
	cfg.reduced_interval = 100.0
	npc.npc_config = cfg
	npc.set_lod(1)
	assert_true(_anim(npc).is_playing(), "level 1: the animation runs")
	npc.global_position = Vector3(50, 0, 50)
	await wait_frames(3)
	assert_almost(npc.global_position.x, 50.0, 0.01, "level 1: evaluated only every reduced_interval")
	npc.set_lod(2)
	assert_false(_anim(npc).is_playing(), "level 2: the animation rests")
	await wait_frames(2)
	assert_false(_anim(npc).is_playing())
	npc.set_lod(0)
	await wait_frames(1)
	assert_almost(npc.global_position.x, 3.0, 0.01, "level 0: every frame")
	assert_true(_anim(npc).is_playing(), "level 0: animated")
	cfg.reduced_interval = 0.0
	npc.set_lod(1)
	npc.global_position = Vector3(50, 0, 50)
	await wait_frames(2)
	assert_almost(npc.global_position.x, 3.0, 0.01, "level 1 evaluates after the interval")
	npc.set_lod(7)
	assert_eq(npc.lod(), 2, "clamped")


func test_remark_nearness_once_per_day() -> void:
	var rel := FakeRelationships.new()
	world.add_child(rel)
	var near := _npc("innkeeper", Vector3(2, 0, 0), village)
	var far := _npc("smith", Vector3(10, 0, 0), village)
	var other := _npc("carter", Vector3(1, 0, 0), graveyard)
	await wait_frames(1)
	player.global_position = Vector3.ZERO
	lod.update_now()
	assert_eq(rel.calls, [&"innkeeper"], "closer than remark_distance (4 m), active region only")
	lod.update_now()
	assert_eq(rel.calls.size(), 1, "once per person and day")
	TimeManager.advance(1440)
	near.refresh()
	far.refresh()
	other.refresh()
	player.global_position = Vector3.ZERO
	lod.update_now()
	assert_eq(rel.calls, [&"innkeeper", &"innkeeper"], "next day again")


func test_governor_and_not_saved() -> void:
	var npc := _npc("a", Vector3(60, 0, 0), village)
	await wait_frames(1)
	assert_eq(lod.lod_of(npc), 0, "not ranked yet")
	assert_false(lod.is_in_group(&"saveable"))
	lod.set_process(true)
	await wait_for_signal(tree.process_frame, 0.1)
	var t := 0.0
	while lod.lod_of(npc) != 2 and t < 2.0:
		await tree.process_frame
		t += 0.016
	assert_eq(lod.lod_of(npc), 2, "the governor ranks within 1 / governor_hz s")
	assert_eq(lod.lod_of(null), 0)
