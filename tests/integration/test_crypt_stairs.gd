extends TestCase
## G7 round 1 (user: „Die Gruft soll nur betretbar von meinem Friedhof aus sein, da sollen Treppen in
## die Gruft hinuntergehen"): the crypt stair on the real world through SaveManager (v5 fixture, the
## Phase-6 end state, crypt level 3). Outside: the ground has the ramp pit in front of the portal, the
## site collision leaves the passage open from level 1 (cheeks beside it), the sod cover lies over the
## pit until level 1; the door stands at the foot of the stair with its StairPortal. The gravekeeper
## walks down (real input, real physics – seen below the ground before the fade) and arrives at the
## foot of the stair in the crypt room; walks up the stair there (seen high up the stair) and comes
## out at the foot of the stair outside, walks up onto the graveyard. Save → load on the stair
## outside and on the stair inside are round-trip equal; a corpse from the bier goes down the stair
## onto the crypt table.

const TIMEOUT := 400.0
const SLOT := 97
const FIXTURE := "slot_p6_day40_reverent"
const STAIR_TOP := Vector2(-9.0, 8.85)
const BIER_STAND := Vector2(1.75, 9.2)
## The crypt site's flat height minus this = the stair foot at least (layout stair depth 1.0).
const MIN_DEPTH := 0.7

var saves_dir := TestCase.user_dir("test_saves_crypt_stairs")
var world: WorldRoot
var player: Player


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	assert_eq(Phase7Fixtures.install_save_v5(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world != null:
		TimeManager.set_time(TimeManager.day, 600)


func after_each() -> void:
	_release()
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_the_stair_outside_by_level() -> void:
	if world == null:
		return
	var site := world.get_node("Entities/site_crypt") as Node3D
	var door := BuildingDoor.find(tree, &"crypt")
	var cover := world.get_node_or_null("Entities/site_crypt_cover") as SiteCover
	assert_not_null(cover, "the sod cover over the pit")
	assert_not_null(door.get_node_or_null("StairPortal"), "the walk-through portal at the foot of the stair")
	var model := site.get_node("Model") as Node3D
	var marker := model.find_child("door_outside", true, false) as Node3D
	assert_true(door.global_position.distance_to(marker.global_position) < 0.05, "the door at the model's door_outside")
	assert_true(site.global_position.y - door.global_position.y > MIN_DEPTH, "the door lies down at the stair foot (%.2f)" %
			(site.global_position.y - door.global_position.y))
	assert_true(site.global_position.y - world.ground_height(Vector2(-9.0, 7.6)) > MIN_DEPTH, "the ground has the pit")
	assert_almost(world.ground_height(STAIR_TOP), site.global_position.y, 0.06, "the stair starts at the ground")
	var plug := site.get_node("Collision/PassagePlug") as CollisionShape3D
	var cheek := site.get_node("Collision/Cheek1") as CollisionShape3D
	assert_false(cover.visible, "level 3: the pit is open")
	assert_true(plug.disabled and not cheek.disabled, "level 3: passage open, cheeks solid")
	var buildings := world.get_node("Systems/Buildings") as Buildings
	buildings.load_state({"levels": {"crypt": 0, "chapel": 3, "shed": 3}})
	EventBus.building_upgraded.emit(&"crypt", 0)
	await tree.process_frame
	assert_true(cover.visible and not (cover.get_node("Collision/Slab") as CollisionShape3D).disabled, "level 0: covered, walkable")
	assert_true(not plug.disabled and cheek.disabled, "level 0: the footprint closed, no cheeks")
	assert_false(door.can_interact(player), "level 0: no way in")


func test_walk_down_and_up_the_stair() -> void:
	if world == null:
		return
	_place(STAIR_TOP, PI)
	var site_y := (world.get_node("Entities/site_crypt") as Node3D).global_position.y
	var lowest := INF
	var budget := 400
	_press(&"move_up", 1.0)
	while player.interior_id == &"" and budget > 0:
		await tree.physics_frame
		lowest = minf(lowest, player.global_position.y)
		budget -= 1
	_release()
	assert_eq(player.interior_id, &"crypt", "walked down into the crypt")
	assert_true(site_y - lowest > MIN_DEPTH - 0.1, "seen going down the stair before the fade (%.2f m)" % (site_y - lowest))
	var room := InteriorRoom.find(tree, &"crypt")
	await _until_arrived()
	assert_true(player.global_position.distance_to(room.spawn_transform().origin) < 0.6, "at the foot of the stair inside")
	assert_true(room.active, "the crypt room shown")
	# Up the stair inside and out.
	var highest := -INF
	budget = 600
	_press(&"move_down", 1.0)
	while player.interior_id == &"crypt" and budget > 0:
		await tree.physics_frame
		highest = maxf(highest, player.global_position.y - room.global_position.y)
		budget -= 1
	_release()
	assert_eq(player.interior_id, &"", "walked up and out")
	assert_true(highest > 1.0, "seen climbing the stair inside (%.2f m)" % highest)
	await _until_arrived()
	var door := BuildingDoor.find(tree, &"crypt")
	assert_true(player.global_position.distance_to(door.exit_transform().origin) < 0.6, "at the foot of the stair outside")
	assert_eq(player.region_id, &"graveyard")
	_press(&"move_down", 1.0)
	for i: int in 90:
		await tree.physics_frame
	_release()
	assert_true(player.global_position.z > 8.6 and player.global_position.y > site_y - 0.15, "walked up onto the graveyard %s" %
			player.global_position)
	assert_eq(player.interior_id, &"", "the stair does not pull back in going up")


func test_save_load_on_the_stairs() -> void:
	if world == null:
		return
	_place(Vector2(-9.0, 8.1), PI)
	await _settle()
	var y_out := player.global_position.y
	await _round_trip("on the stair outside")
	assert_almost(player.global_position.y, y_out, 0.05, "still on the stair outside")
	assert_eq(player.interior_id, &"")
	var room := InteriorRoom.find(tree, &"crypt")
	HutPortal.arrive(player, room.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 1.0, 3.9)), true, &"crypt")
	await _settle()
	var y_in := player.global_position.y - room.global_position.y
	assert_true(y_in > 0.6, "standing on the stair inside (%.2f)" % y_in)
	await _round_trip("on the stair inside")
	room = InteriorRoom.find(tree, &"crypt")
	assert_eq(player.interior_id, &"crypt")
	assert_almost(player.global_position.y - room.global_position.y, y_in, 0.05, "still on the stair inside")


func test_a_corpse_goes_down_the_stair_to_the_table() -> void:
	if world == null:
		return
	var manager := world.corpse_manager
	var bier := tree.get_first_node_in_group(&"dropoff") as Node3D
	var record := manager.spawn_corpse(null, bier.global_transform if bier != null else Transform3D.IDENTITY, &"dropoff")
	assert_not_null(record, "a corpse on the bier")
	if record == null:
		return
	_place(BIER_STAND, 0.0)
	manager.get_corpse_node(record.id).interact(player)
	assert_eq(player.carried_id, record.id, "carried from the bier")
	_place(STAIR_TOP, PI)
	_press(&"move_up", 1.0)
	var budget := 500
	while player.interior_id == &"" and budget > 0:
		await tree.physics_frame
		budget -= 1
	_release()
	assert_eq(player.interior_id, &"crypt", "down the stair with the corpse")
	await _until_arrived()
	assert_eq(player.carried_id, record.id, "the corpse came along")
	var table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	table.interact(player)
	assert_eq(manager.get_record(record.id).location, CorpseRecord.LOCATION_TABLE, "on the crypt table")


# --- helpers ---------------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	TimeManager.running = false


func _place(p: Vector2, facing: float) -> void:
	player.global_transform = Transform3D(Basis(Vector3.UP, facing), Vector3(p.x, world.ground_height(p) + 0.05, p.y))
	player.velocity = Vector3.ZERO


func _settle() -> void:
	for i: int in 20:
		await tree.physics_frame


func _press(action: StringName, strength: float) -> void:
	Input.action_press(action, strength)


func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _until_arrived() -> void:
	var budget := 240
	while HutPortal.is_travelling(player) and budget > 0:
		await tree.process_frame
		budget -= 1
	await tree.physics_frame
	UIState.clear()


func _round_trip(moment: String) -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	await wait_frames(1)
	var after := SaveManager.collect_state()
	var diffs: PackedStringArray = []
	_state_diff(before, after, "", diffs)
	assert_eq(diffs, PackedStringArray(), moment + ": collect_state identical after save → load")


func _state_diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
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
			out.append("#%s" % path)
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
			out.append("~%s" % path)
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("~%s (%s → %s)" % [path, a, b])
