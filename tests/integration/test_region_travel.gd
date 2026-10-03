extends TestCase
## P1 (docs/PHASE7_DESIGN.md §3.4, §4.1, §10 test_region_travel): the real graveyard world (new game via
## SaveManager) with the Phase-7 region parts installed the way W-Welt will build them (Regions/Graveyard
## managing Decor / Lights / Grass, Regions/Village at (0, 0, 400) with spawn, house door and the bridge
## portal, the inn room at (240, 0, −200) with a RoomExit door_id, the milestone portal road_exit).
## Chain: milestone → village → inn → village → graveyard through the real RegionPortal / HouseDoor /
## RoomExit / RegionTravel / HutPortal; the clock +60 min in all; the camera profile per place. Save /
## load in each of the five states (graveyard, village, inn, crypt, chapel) → the identical view and an
## identical collect_state(). The parts are installed again into every new world (node_added hook)
## before SaveManager applies the saved nodes.

const TIMEOUT := 240.0
const SLOT := 7
const INN_ORIGIN := Vector3(240, 0, -200)
const VILLAGE_ORIGIN := Vector3(0, 0, 400)

var saves_dir := TestCase.user_dir("test_region_travel")
var world: WorldRoot


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	tree.node_added.connect(_on_node_added)
	await SaveManager.new_game()
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	await wait_frames(2)


func after_each() -> void:
	tree.node_added.disconnect(_on_node_added)
	UIState.clear()
	GameState.reset()
	TestCase.remove_user_dir(saves_dir)


func _on_node_added(node: Node) -> void:
	if node is WorldRoot:
		node.ready.connect(_install.bind(node), CONNECT_ONE_SHOT)


## The Phase-7 region parts of the contract (§3.1, §4.1–§4.4, §4.6 R1), as W-Welt will generate them.
func _install(w: WorldRoot) -> void:
	var regions := Node3D.new()
	regions.name = "Regions"
	w.add_child(regions)
	var graveyard := RegionRoot.new()
	graveyard.name = "Graveyard"
	graveyard.region_id = RegionRoot.GRAVEYARD
	graveyard.camera_rig_path = NodePath("../../CameraRig")
	_marker(graveyard, "Spawns", "from_village", Vector3(8.0, w.ground_height(Vector2(8.0, 23.4)), 23.4), -0.8)
	regions.add_child(graveyard)
	var village := RegionRoot.new()
	village.name = "Village"
	village.region_id = RegionRoot.VILLAGE
	village.position = VILLAGE_ORIGIN
	village.camera_rig_path = NodePath("../../CameraRig")
	_marker(village, "Spawns", "from_graveyard", Vector3(-24.6, 0, 1.5), PI * 0.5)
	village.add_child(_floor())
	var entities := Node3D.new()
	entities.name = "Entities"
	village.add_child(entities)
	var door := (load("res://src/entities/house_door/house_door.tscn") as PackedScene).instantiate() as HouseDoor
	door.name = "door_inn"
	door.door_id = &"door_inn"
	door.room_id = &"inn"
	door.display_name = "Holderkrug"
	door.open_windows = PackedInt32Array(Phase7Fixtures.OPEN_WINDOWS[&"door_inn"])
	door.position = Vector3(15, 0, -10.4)
	entities.add_child(door)
	var road_out := (load("res://src/entities/region_portal/region_portal.tscn") as PackedScene).instantiate() as RegionPortal
	road_out.name = "road_out"
	road_out.target_region = RegionRoot.GRAVEYARD
	road_out.target_spawn = &"from_village"
	road_out.prompt = "[E] Zum Friedhof (30 Min)"
	road_out.position = Vector3(-28.4, 0, 1.5)
	entities.add_child(road_out)
	regions.add_child(village)
	var road_exit := (load("res://src/entities/region_portal/region_portal.tscn") as PackedScene).instantiate() as RegionPortal
	road_exit.name = "road_exit"
	road_exit.target_region = RegionRoot.VILLAGE
	road_exit.target_spawn = &"from_graveyard"
	road_exit.position = Vector3(8.4, 0, 24.4)
	w.get_node("Entities").add_child(road_exit)
	var inn := InteriorRoom.new()
	inn.name = "InnInterior"
	inn.room_id = &"inn"
	inn.region_id = RegionRoot.VILLAGE
	inn.hide_when_inactive = true
	inn.config = Phase7Fixtures.room_config(&"inn")
	inn.environment = Environment.new()
	inn.bounds_min = Vector2(-3, -2)
	inn.bounds_max = Vector2(3, 2)
	inn.position = INN_ORIGIN
	inn.camera_rig_path = NodePath("../../CameraRig")
	inn.outdoor_sun_path = NodePath("../../Sun")
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	inn.add_child(sun)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0, 0, 2)
	inn.add_child(spawn)
	inn.add_child(_floor())
	var exit := (load("res://src/world/interiors/room_exit.tscn") as PackedScene).instantiate() as RoomExit
	exit.door_id = &"door_inn"
	exit.position = Vector3(0, 0, 2.6)
	inn.add_child(exit)
	w.get_node("Interiors").add_child(inn)


## A flat floor (layer 1) at y 0 – the generated village ground / room floor stand-in.
func _floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	return body


func _marker(parent: Node3D, holder_name: String, id: String, pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.name = holder_name
	parent.add_child(holder)
	var m := Marker3D.new()
	m.name = id
	m.position = pos
	m.rotation.y = yaw
	holder.add_child(m)


func _player() -> Player:
	return world.get_player()


func _rig() -> CameraRig:
	return world.get_node("CameraRig") as CameraRig


func _region(id: StringName) -> RegionRoot:
	return RegionRoot.find(tree, id)


## What the gravekeeper sees: place, room, region states, the rig's framing, the outdoor sun.
func _view() -> Dictionary:
	var p := _player()
	var rig := _rig()
	var rooms := {}
	for node: Node in tree.get_nodes_in_group(InteriorRoom.GROUP):
		var room := node as InteriorRoom
		rooms[String(room.room_id)] = room.active
	return {
		"region": p.region_id, "interior": p.interior_id, "in_interior": p.in_interior,
		"pos": Vector2(snappedf(p.global_position.x, 0.01), snappedf(p.global_position.z, 0.01)),
		"graveyard": _region(&"graveyard").active, "village": _region(&"village").active,
		"village_visible": _region(&"village").visible, "decor_visible": (world.get_node("Decor") as Node3D).visible,
		"profile": rig.profile != null, "distance": rig.distance, "bounds": [rig.bounds_min, rig.bounds_max],
		"sun": (world.get_node("Sun") as Light3D).visible, "rooms": rooms,
	}


func _round_trip(label: String) -> void:
	UIState.clear()
	var view := _view()
	var before := SaveManager.collect_state()
	assert_eq((before.nodes.player as Dictionary).get("region_id"), String(view.region), label + ": region_id saved")
	assert_eq(SaveManager.save_game(SLOT), OK, label + " saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, label + " loaded")
	world = tree.current_scene as WorldRoot
	TimeManager.running = false
	# Right after the load (the capsule settles by fractions of a millimetre in the next physics frames).
	assert_eq(SaveManager.collect_state(), before, label + ": identical state")
	await wait_frames(2)
	assert_eq(_view(), view, label + ": identical view after the load")


func _walk_through(portal_path: String) -> void:
	var portal := world.get_node(portal_path) as RegionPortal
	var player := _player()
	assert_true(portal.can_interact(player), portal_path + " usable")
	portal.interact(player)
	assert_true(await wait_for_signal(EventBus.region_changed, 3.0), portal_path + " arrived")
	await wait_frames(1)


func test_milestone_village_inn_and_back() -> void:
	var player := _player()
	var road_exit := world.get_node("Entities/road_exit") as RegionPortal
	assert_eq(road_exit.get_interaction_prompt(player), "", "scenery before village_open")
	GameState.set_flag(&"village_open", true)
	TimeManager.set_time(TimeManager.day + 1, 14 * 60)
	var start := TimeManager.total_minutes()
	assert_eq(road_exit.get_interaction_prompt(player), "[E] Nach Hollerbrück (30 Min)")
	await _walk_through("Entities/road_exit")
	assert_eq([player.region_id, player.in_interior], [&"village", false])
	assert_eq(TimeManager.total_minutes() - start, 30)
	assert_eq(GameState.get_stat(&"village_trips"), 1)
	var rig := _rig()
	assert_eq([rig.profile, rig.bounds_min, rig.bounds_max, rig.distance], [null, Vector2(-22, 392), Vector2(20, 408), 22.0],
			"village base profile")
	assert_true(_region(&"village").visible and not (world.get_node("Decor") as Node3D).visible)
	assert_true((world.get_node("Sun") as Light3D).visible, "the same sun outside")
	# Into the Holderkrug and out again.
	var door := HouseDoor.find(tree, &"door_inn")
	assert_eq(door.get_interaction_prompt(player), "[E] Holderkrug betreten")
	door.interact(player)
	assert_true(await wait_for_signal(EventBus.interior_room_changed, 3.0))
	await wait_frames(1)
	assert_eq([player.region_id, player.interior_id], [&"village", &"inn"])
	assert_not_null(rig.profile, "inn profile")
	assert_eq(rig.distance, 10.0, "§4.3: inn distance 10")
	assert_eq(TimeManager.total_minutes() - start, 30, "a door costs no time")
	var exit := InteriorRoom.find(tree, &"inn").find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)[0] as RoomExit
	exit.interact(player)
	assert_true(await wait_for_signal(EventBus.interior_room_changed, 3.0))
	await wait_frames(1)
	assert_eq([player.region_id, player.interior_id, rig.profile], [&"village", &"", null])
	assert_eq([rig.bounds_min, rig.distance], [Vector2(-22, 392), 22.0], "clear_profile → the village")
	# Back over the bridge.
	await _walk_through("Regions/Village/Entities/road_out")
	assert_eq(player.region_id, &"graveyard")
	assert_eq(TimeManager.total_minutes() - start, 60, "§1.3: 30 min each way, 60 in all")
	assert_eq(GameState.get_stat(&"village_trips"), 1)
	assert_eq([rig.bounds_min, rig.bounds_max], [Vector2(-11.5, -24), Vector2(27, 23)], "graveyard base = the layout's camera bounds")
	assert_true((world.get_node("Decor") as Node3D).visible and not _region(&"village").visible)


func test_save_and_load_in_five_places() -> void:
	GameState.set_flag(&"village_open", true)
	TimeManager.set_time(TimeManager.day + 1, 15 * 60)
	await _round_trip("graveyard")
	await _walk_through("Entities/road_exit")
	await _round_trip("village")
	var door := HouseDoor.find(tree, &"door_inn")
	door.interact(_player())
	assert_true(await wait_for_signal(EventBus.interior_room_changed, 3.0))
	await wait_frames(1)
	assert_eq(_player().interior_id, &"inn")
	await _round_trip("inn")
	assert_eq(_rig().distance, 10.0, "still the inn's framing")
	# Graveyard rooms (built rooms of Phase 6 lie in the graveyard region).
	for room_id: StringName in [&"crypt", &"chapel"]:
		var room := InteriorRoom.find(tree, room_id)
		assert_not_null(room, String(room_id))
		RegionTravel.arrive(_player(), RegionRoot.GRAVEYARD,
				(world.get_node("Regions/Graveyard") as RegionRoot).spawn_transform(&"from_village"), 0)
		HutPortal.arrive(_player(), room.spawn_transform(), true, room_id)
		await wait_frames(1)
		assert_eq([_player().region_id, _player().interior_id], [&"graveyard", room_id])
		await _round_trip(String(room_id))
