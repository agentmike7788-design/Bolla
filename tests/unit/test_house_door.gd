extends TestCase
## P1 (docs/PHASE7_DESIGN.md §2.2, §3.4, §4.3, §10): HouseDoor – opening windows (§2.2 fixture values),
## „Geschlossen. Öffnet um …", the lecture-night door (Lectures.door_open), never with a corpse, the
## trip into the room (HutPortal, region stays village) and RoomExit.door_id back to the house door
## (no opening time on the way out).

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const DOOR_SCENE := "res://src/entities/house_door/house_door.tscn"
const EXIT_SCENE := "res://src/world/interiors/room_exit.tscn"


class FakeLectures extends Node:
	var open_door: StringName = &""

	func _init() -> void:
		add_to_group(&"lectures")

	func door_open(door_id: StringName) -> bool:
		return door_id == open_door


var world: Node3D
var player: Player
var room: InteriorRoom
var door: HouseDoor


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	world = Node3D.new()
	world.name = "P7DoorWorld"
	tree.root.add_child(world)
	room = InteriorRoom.new()
	room.name = "SurgeryInterior"
	room.room_id = &"surgery"
	room.region_id = &"village"
	room.hide_when_inactive = true
	room.config = Phase7Fixtures.room_config(&"surgery")
	room.position = Phase7Fixtures.ROOMS[&"surgery"].origin
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0, 1.5)
	room.add_child(spawn)
	world.add_child(room)
	door = (load(DOOR_SCENE) as PackedScene).instantiate() as HouseDoor
	door.door_id = &"door_surgery"
	door.room_id = &"surgery"
	door.display_name = "Wundarztstube"
	door.open_windows = PackedInt32Array(Phase7Fixtures.OPEN_WINDOWS[&"door_surgery"])
	door.position = Vector3(15.4, 0, 398)
	door.rotation.y = -PI * 0.5
	world.add_child(door)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.instant_actions = true
	world.add_child(player)
	player.set_region(&"village")
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


## XZ only: the player falls between the teleport and the check (no floor in the test).
static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _at(minute: int) -> void:
	TimeManager.minute_of_day = minute


func test_open_windows() -> void:
	# Wundarztstube 07:55–12:00 and 14:00–18:00 (§2.2).
	for spec: Array in [[474, false], [475, true], [719, true], [720, false], [800, false], [840, true], [1079, true],
			[1080, false], [0, false]]:
		_at(spec[0])
		assert_eq(door.is_open_now(), spec[1], "minute %d" % spec[0])
	door.open_windows = PackedInt32Array()
	_at(3)
	assert_true(door.is_open_now(), "no windows = always open")
	assert_eq(door.next_opening(), -1)


func test_window_over_midnight() -> void:
	door.open_windows = PackedInt32Array([1380, 30])
	for spec: Array in [[1379, false], [1380, true], [10, true], [30, false]]:
		assert_eq(door.is_open_at(spec[0]), spec[1], "minute %d" % spec[0])


func test_next_opening_and_closed_prompt() -> void:
	_at(13 * 60)
	assert_eq(door.next_opening(), 840)
	assert_eq(door.get_interaction_prompt(player), "Geschlossen. Öffnet um 14:00.")
	assert_false(door.can_interact(player))
	_at(19 * 60)
	assert_eq(door.next_opening(), 475, "tomorrow morning")
	assert_eq(door.get_interaction_prompt(player), "Geschlossen. Öffnet um 07:55.")
	_at(8 * 60)
	assert_eq(door.next_opening(), 840, "while open: the next window")
	assert_eq(door.get_interaction_prompt(player), "[E] Wundarztstube betreten")
	assert_true(door.can_interact(player))


func test_lecture_night_opens_the_surgery() -> void:
	_at(23 * 60)
	assert_false(door.is_open_now())
	var lectures := FakeLectures.new()
	world.add_child(lectures)
	assert_false(door.is_open_now(), "another door")
	lectures.open_door = &"door_surgery"
	assert_true(door.is_open_now(), "Lectures.door_open")
	assert_true(door.can_interact(player))


func test_never_with_a_corpse_or_busy() -> void:
	_at(9 * 60)
	var corpse := Node3D.new()
	player.attach_carried(corpse, "corpse_0001")
	assert_false(door.can_interact(player))
	assert_eq(door.get_interaction_prompt(player), HutDoor.TEXT_CORPSE_OUTSIDE)
	player.detach_carried()
	corpse.free()
	player.set_meta(HutPortal.META_TRAVELLING, true)
	assert_false(door.can_interact(player), "not during a fade")
	player.remove_meta(HutPortal.META_TRAVELLING)
	assert_false(door.can_interact(null))
	door.room_id = &"cellar"
	assert_eq(door.get_interaction_prompt(player), "", "no room in the world → no prompt")
	assert_false(door.can_interact(player))


func test_enter_and_leave_by_the_house_door() -> void:
	_at(9 * 60)
	var start := TimeManager.total_minutes()
	door.interact(player)
	await wait_for_signal(EventBus.interior_room_changed, 3.0)
	assert_eq([player.in_interior, player.interior_id, player.region_id], [true, &"surgery", &"village"], "region stays village")
	assert_true(_flat(player.global_position).is_equal_approx(_flat(room.spawn_transform().origin)), "at the room's spawn")
	assert_true(room.active)
	assert_eq(TimeManager.total_minutes(), start, "a door costs no time")
	var exit := (load(EXIT_SCENE) as PackedScene).instantiate() as RoomExit
	exit.door_id = &"door_surgery"
	room.add_child(exit)
	_at(19 * 60)   # closed meanwhile: leaving is always allowed
	assert_true(exit.can_interact(player))
	assert_eq(exit.get_interaction_prompt(player), RoomExit.PROMPT_OUT)
	assert_true(exit.exit_transform().is_equal_approx(door.exit_transform()))
	exit.interact(player)
	await wait_for_signal(EventBus.interior_room_changed, 3.0)
	assert_eq([player.in_interior, player.interior_id, player.region_id], [false, &"", &"village"])
	var out := door.exit_transform()
	assert_true(_flat(player.global_position).is_equal_approx(_flat(out.origin)), "in front of the house door")
	assert_true(out.origin.is_equal_approx(Vector3(15.4 - 0.3, 0, 398)), "exit_offset in front of the door (door faces west)")


func test_room_exit_without_house_door() -> void:
	var exit := (load(EXIT_SCENE) as PackedScene).instantiate() as RoomExit
	exit.door_id = &"door_missing"
	room.add_child(exit)
	assert_false(exit.can_interact(player))
	assert_eq(exit.get_interaction_prompt(player), "")
	assert_eq(exit.exit_transform(), Transform3D())


func test_find() -> void:
	assert_eq(HouseDoor.find(tree, &"door_surgery"), door)
	assert_null(HouseDoor.find(tree, &"door_inn"))
	assert_null(HouseDoor.find(null, &"door_surgery"))
