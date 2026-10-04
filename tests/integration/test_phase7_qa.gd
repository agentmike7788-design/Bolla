extends TestCase
## W3 QA of Phase 7 (docs/PHASE7_DESIGN.md §10; findings in docs/reviews/phase7_wip/qa_playthrough.md):
## regression tests on the real world (v5 fixtures through the real SaveManager) – across sessions and
## at the package seams:
## QA7-07 the region and the room come back from a save made in the Holderkrug (the village active, the
## graveyard's managed parts off, identical state) · QA7-08 no trip while a timed action runs · QA7-09 a
## load during the fade of a trip – the trip does not land in the loaded game (no 30 min, no region) ·
## QA7-10 a load while a specimen is taken: veil off, cloth off, the table free · QA7-11 Quast stands
## at the lectern on a lecture night (his Npc, talkable, the lecture in his dialogue) · QA7-12 the
## Lindenacker's east graves keep their open pit inside the fence (pit_variant foot).

const TIMEOUT := 400.0
const SLOT := 92
const FIXTURE := "slot_p6_day40_reverent"
const MILESTONE_STAND := Vector2(9.0, 23.0)

var saves_dir := TestCase.user_dir("test_saves_p7_qa")
var world: WorldRoot
var player: Player


func before_each() -> void:
	SaveManager.save_dir = saves_dir


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _load_fixture(name: String = FIXTURE) -> bool:
	assert_eq(Phase7Fixtures.install_save_v5(name, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, name + " loads")
	_bind()
	return world != null


func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player() if world != null else null
	if player != null:
		player.instant_actions = true
	TimeManager.running = false


func _until_arrived() -> void:
	var budget := 240
	while HutPortal.is_travelling(player) and budget > 0:
		await tree.process_frame
		budget -= 1
	await tree.physics_frame
	UIState.clear()


func _to_village() -> void:
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	assert_true(portal.can_interact(player), "the milestone (%s)" % portal.get_interaction_prompt(player))
	portal.interact(player)
	await _until_arrived()
	assert_eq(player.region_id, &"village")


func _round_trip_state(moment: String) -> void:
	UIState.clear()
	for i: int in 6:
		await tree.physics_frame
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	await wait_frames(1)
	var after := SaveManager.collect_state()
	var diffs: PackedStringArray = []
	_state_diff(before, after, "", diffs)
	assert_eq(diffs, PackedStringArray(), moment + ": collect_state identical")


func _state_diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if out.size() > 20:
		return
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not (b as Dictionary).has(key):
				out.append("-%s.%s" % [path, key])
			else:
				_state_diff(a[key], b[key], "%s.%s" % [path, key], out)
		for key: Variant in b:
			if not (a as Dictionary).has(key):
				out.append("+%s.%s" % [path, key])
		return
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("#%s (%d → %d)" % [path, (a as Array).size(), (b as Array).size()])
			return
		for i: int in (a as Array).size():
			_state_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		return
	if a is Vector3 and b is Vector3:
		if (a as Vector3).distance_to(b) > 1e-5:
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if (a is float or b is float) and (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 1e-9 * maxf(1.0, absf(float(a))):
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("~%s (%s → %s)" % [path, str(a).left(80), str(b).left(80)])


# --- QA7-07 -----------------------------------------------------------------------------------------

func test_qa7_07_load_in_the_holderkrug_restores_region_and_room() -> void:
	if not await _load_fixture():
		return
	await _to_village()
	TimeManager.set_time(TimeManager.day, 900)
	var door := HouseDoor.find(tree, &"door_inn")
	player.global_transform = door.exit_transform()
	assert_true(door.can_interact(player), "the Holderkrug is open (%s)" % door.get_interaction_prompt(player))
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, &"inn")
	await _round_trip_state("in the Holderkrug")
	door = HouseDoor.find(tree, &"door_inn")  # the world was rebuilt by the load
	assert_eq([player.region_id, player.interior_id], [&"village", &"inn"], "region and room back")
	assert_eq(RegionRoot.current(tree), &"village")
	var graveyard := RegionRoot.find(tree, &"graveyard")
	for node: Node in graveyard.managed_nodes():
		if node is Node3D:
			assert_false((node as Node3D).visible, "graveyard part %s hidden while in the village" % node.name)
	assert_true(InteriorRoom.find(tree, &"inn").active, "the inn room is the active room")
	# Out again: the village, not the graveyard.
	var room := InteriorRoom.find(tree, &"inn")
	var exit := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)[0] as RoomExit
	exit.interact(player)
	await _until_arrived()
	assert_eq([player.region_id, player.interior_id], [&"village", &""], "out into Hollerbrück")
	assert_true(player.global_position.distance_to(door.exit_transform().origin) < 2.0, "in front of the Holderkrug's door")


# --- QA7-08 -----------------------------------------------------------------------------------------

func test_qa7_08_no_trip_while_a_timed_action_runs() -> void:
	if not await _load_fixture():
		return
	player.instant_actions = false
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	assert_true(portal.can_interact(player))
	var done := [false]
	assert_true(player.start_timed_action("QA", 30, func() -> void: done[0] = true, false))
	assert_false(portal.can_interact(player), "busy: the milestone refuses")
	assert_eq(RegionTravel.block_reason(player, &"village"), RegionTravel.TEXT_BUSY)
	var t := TimeManager.total_minutes()
	portal.interact(player)
	await wait_frames(3)
	assert_eq(player.region_id, &"graveyard", "no trip")
	assert_false(HutPortal.is_travelling(player))
	player.cancel_timed_action()
	assert_true(TimeManager.total_minutes() - t < 30, "no 30-minute jump")


# --- QA7-09 -----------------------------------------------------------------------------------------

func test_qa7_09_a_load_during_the_fade_drops_the_trip() -> void:
	if not await _load_fixture():
		return
	assert_eq(SaveManager.save_game(SLOT), OK)
	var saved_total := TimeManager.total_minutes()
	var trips := GameState.get_stat(&"village_trips")
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	portal.interact(player)
	assert_true(HutPortal.is_travelling(player), "the fade runs")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK)
	_bind()
	await tree.create_timer(1.2).timeout
	await wait_frames(2)
	assert_eq(TimeManager.total_minutes(), saved_total, "the clock of the save (no 30 minutes of the old trip)")
	assert_eq(player.region_id, &"graveyard", "the region of the save")
	assert_eq(RegionRoot.current(tree), &"graveyard")
	assert_eq(GameState.get_stat(&"village_trips"), trips, "no trip counted")
	assert_false(HutPortal.is_travelling(player))


# --- QA7-10 -----------------------------------------------------------------------------------------

func test_qa7_10_load_while_a_specimen_is_taken() -> void:
	if not await _load_fixture("slot_p6_crypt_table"):
		return
	# The case and the flags as Quast's dialogue gives them (Phase-7 world on a Phase-6 save).
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"anatomy_known", true)
	var inv := player.inventory
	for id: StringName in [&"anatomy_case", &"prep_jar", &"spirits"]:
		if inv.count(id) == 0:
			inv.add_item(id, 1)
	assert_eq(SaveManager.save_game(SLOT), OK)
	var table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	assert_ne(table.corpse_id, "", "a corpse on the crypt table")
	var veils: Array = []
	var on_veil := func(active: bool) -> void: veils.append(active)
	EventBus.screen_veil_changed.connect(on_veil)
	player.instant_actions = false
	table.request_organ(&"heart", SpecimenRecord.CONTAINER_JAR)
	assert_true(table.is_covering(), "the cloth is on (%s)" % (world.get_node("Systems/CorpseCare") as CorpseCare).organ_block_reason(
			table.corpse_id, &"heart", SpecimenRecord.CONTAINER_JAR, inv))
	assert_true(player.is_busy())
	var err: Error = await SaveManager.load_game(SLOT)
	EventBus.screen_veil_changed.disconnect(on_veil)
	assert_eq(err, OK)
	_bind()
	await wait_frames(3)
	var veil := tree.get_first_node_in_group(&"screen_veil")
	if veil != null:
		assert_false(bool(veil.get(&"active")), "the veil is off after the load")
	table = InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	assert_false(table.is_covering(), "the new table covers nothing")
	var node := world.corpse_manager.get_corpse_node(table.corpse_id)
	assert_true(node != null and not node.is_covered(), "the corpse lies uncovered")
	assert_false(player.is_busy(), "no action runs")
	var specimens := world.get_node("Systems/Specimens") as Specimens
	assert_eq(specimens.of_corpse(table.corpse_id).size(), 0, "nothing was taken (the load came first)")
	assert_true((TimeManager.get(&"_pauses") as Dictionary).is_empty(), "the clock is not held")


# --- QA7-11 -----------------------------------------------------------------------------------------

func test_qa7_11_quast_at_the_lectern_on_a_lecture_night() -> void:
	if not await _load_fixture():
		return
	var day := TimeManager.day
	while day % 3 != 0:
		day += 1
	TimeManager.set_time(day, 1385)
	GameState.set_flag(&"anatomy_known", true)
	var lectures := world.get_node("Systems/Lectures") as Lectures
	lectures.invite()
	await _to_village()
	assert_eq(TimeManager.day, day)
	var door := HouseDoor.find(tree, &"door_surgery")
	player.global_transform = door.exit_transform()
	assert_true(door.can_interact(player), "the surgery opens on a lecture night (%s)" % door.get_interaction_prompt(player))
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, &"surgery")
	var quast := world.find_child("npc_surgeon", true, false) as Npc
	quast.refresh()
	assert_true(quast.is_present() and quast.is_talkable(), "Quast is there at %s" % TimeManager.format_clock())
	var room := InteriorRoom.find(tree, &"surgery")
	var lectern := room.get_node("Waypoints/v_in_surgery_lectern") as Node3D
	assert_true(Vector2(quast.global_position.x, quast.global_position.z).distance_to(
			Vector2(lectern.global_position.x, lectern.global_position.z)) < 0.2, "at the lectern")
	# His dialogue offers the lecture (lecture_tonight → open_lecture).
	var runner := DialogueRunner.new()
	runner.start(Database.dialogue(&"v_surgeon") as DialogueData, {"inventory": player.inventory, "speaker": quast, "player": player})
	var found := false
	for step: int in 6:
		if runner.is_finished():
			break
		for c: DialogueChoice in runner.available_choices():
			if c.actions.has("open_lecture"):
				found = true
		if found or runner.available_choices().is_empty():
			break
		runner.choose(0)
	UIState.clear()
	assert_true(found, "„Ein Präparat für heute Abend“ in Quast’s dialogue")


# --- QA7-12 -----------------------------------------------------------------------------------------

func test_qa7_12_lindenacker_east_graves_keep_the_pit_inside_the_fence() -> void:
	if not await _load_fixture():
		return
	for id: String in ["l_01", "l_02", "l_03", "l_04", "l_05", "l_06", "l_07", "l_08"]:
		var plot := world.get_node_by_layout_id(id) as GravePlot
		var fp := plot.active_footprint()
		for corner: Vector2 in [fp.position, fp.end, Vector2(fp.position.x, fp.end.y), Vector2(fp.end.x, fp.position.y)]:
			var p := plot.global_transform * Vector3(corner.x, 0.0, corner.y)
			assert_true(p.x <= 21.45 and p.x >= 11.55 and p.z <= 19.55, "%s: the open pit at %s stays inside the Lindenacker" % [id, p])
	for id: String in ["l_04", "l_08"]:
		assert_eq((world.get_node_by_layout_id(id) as GravePlot).pit_variant, &"foot", id + ": spoil heap at the foot end")
