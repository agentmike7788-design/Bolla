extends TestCase
## G7 round 1 (user critique „in die Kirche im Dorf kann man auch nicht reingehen"): the village
## church St. Gallus is walk-in like the three village rooms – on the real world through SaveManager
## from the Phase-6 end state (v5 fixture): the HouseDoor door_church at the church's door_outside,
## open 06:00–20:00 (data), closed with the next opening in the prompt; entering through the door,
## the ChurchInterior with pews, altar, pulpit, font, poor box and memorial; Pfarrer Lenz before the
## chancel in the afternoon (his schedule's 16:00 entry, v_in_church_altar) and talkable there;
## collect_state() identical after save → load inside the church; the RoomExit leads back to the door.

const TIMEOUT := 300.0
const SLOT := 96
const FIXTURE := "slot_p6_day40_reverent"
const MILESTONE_STAND := Vector2(9.0, 23.0)
const FURNITURE := ["Altar", "Pulpit", "Font", "PoorBox", "Memorial"]

var saves_dir := TestCase.user_dir("test_saves_church")
var world: WorldRoot
var player: Player


func before_each() -> void:
	SaveManager.save_dir = saves_dir


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_church_door_room_priest_and_round_trip() -> void:
	assert_eq(Phase7Fixtures.install_save_v5(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world == null:
		return
	await _travel_to_village()
	var door := HouseDoor.find(tree, &"door_church")
	assert_not_null(door, "the church door")
	if door == null:
		return
	assert_eq(door.room_id, &"church")
	assert_eq(door.open_windows, PackedInt32Array([360, 1200]), "open 06:00–20:00 (data)")
	var church := world.get_node_or_null("Regions/Village/Buildings/v_church") as Node3D
	var marker := church.find_child("door_outside", true, false) as Node3D if church != null else null
	assert_not_null(marker, "the church model's door_outside")
	if marker != null:
		# The church door lies up its steps beyond the walkable bounds: the HouseDoor at their foot.
		var d := Vector2(door.global_position.x - marker.global_position.x, door.global_position.z - marker.global_position.z)
		assert_true(absf(d.x) < 0.05 and d.y > 0.0 and d.y < 1.6, "the door at the foot of the church steps (%s)" % d)
	# Closed at night, with the next opening.
	_set_time(TimeManager.day, 21 * 60)
	player.global_transform = door.exit_transform()
	assert_false(door.can_interact(player), "closed at 21:00")
	assert_eq(door.get_interaction_prompt(player), "Geschlossen. Öffnet um 06:00.")
	# Open in the afternoon: in through the door.
	_set_time(TimeManager.day + 1, 990)
	assert_eq(door.get_interaction_prompt(player), "[E] die Kirche betreten")
	await _enter(&"door_church")
	var room := InteriorRoom.find(tree, &"church")
	assert_not_null(room, "the ChurchInterior")
	if room == null:
		return
	assert_eq([room.region_id, room.hide_when_inactive], [&"village", true])
	assert_true(room.visible, "the church is drawn while inside")
	for id: String in FURNITURE:
		assert_not_null(room.find_child(id, true, false), "church: " + id)
	var pews := room.get_node("Furniture").get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("pew"))
	assert_true(pews.size() >= 6, "pew rows (%d)" % pews.size())
	# Lenz before the chancel (16:00–18:00), talkable inside.
	var priest := world.get_node("Regions/Village/Entities/npc_priest") as Npc
	priest.refresh()
	assert_true(priest.is_present(), "Lenz in the church at 16:30")
	var spot := room.get_node("Waypoints/v_in_church_altar") as Node3D
	assert_true(priest.global_position.distance_to(spot.global_position) < 0.6, "at v_in_church_altar (%s)" % priest.global_position)
	assert_true(priest.is_talkable(), "his dialogue works inside as outside")
	# Save → load inside the church.
	await _round_trip("in the church at 16:30")
	assert_eq(player.interior_id, &"church", "still inside after loading")
	room = InteriorRoom.find(tree, &"church")
	assert_true(room.visible, "the church drawn again after loading")
	# Out again: in front of the church door.
	var exit := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)[0] as RoomExit
	assert_eq(exit.door_id, &"door_church")
	assert_true(exit.can_interact(player), "the way out")
	exit.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, &"", "outside again")
	door = HouseDoor.find(tree, &"door_church")
	assert_true(player.global_position.distance_to(door.exit_transform().origin) < 0.5, "in front of the church door")


# --- helpers (as test_phase7_loop) -------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	TimeManager.running = false


func _set_time(day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	UIState.clear()


func _travel_to_village() -> void:
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	assert_true(portal.can_interact(player), "the milestone (%s)" % portal.get_interaction_prompt(player))
	portal.interact(player)
	await _until_arrived()
	assert_eq(player.region_id, &"village", "in Hollerbrück")


func _enter(door_id: StringName) -> void:
	var door := HouseDoor.find(tree, door_id)
	player.global_transform = door.exit_transform()
	assert_true(door.can_interact(player), "%s open (%s)" % [door_id, door.get_interaction_prompt(player)])
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, door.room_id, "inside " + String(door.room_id))


func _until_arrived() -> void:
	var budget := 240
	while HutPortal.is_travelling(player) and budget > 0:
		await tree.process_frame
		budget -= 1
	await tree.physics_frame
	UIState.clear()


func _round_trip(moment: String) -> void:
	UIState.clear()
	for i: int in 8:
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
