extends TestCase
## P6 (docs/PHASE6_DESIGN.md §3.4, §4.7, §4.8, §10): the interior core without the world –
## InteriorRoom.apply_room (only the matching room is active; profile, own sun, outdoor sun,
## hide_when_inactive, the InteriorLighting of hidden rooms paused), apply_level (min_level /
## max_level incl. collision), per-room configs (Database.interior_config), HutInterior as the
## bit-identical subclass, BuildingDoor / RoomExit with and without a corpse (allows_corpse),
## Player.interior_id + interior_room_changed and its save / load.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const DOOR_SCENE := "res://src/entities/building_door/building_door.tscn"
const EXIT_SCENE := "res://src/world/interiors/room_exit.tscn"

var _nodes: Array[Node] = []
var _rooms_changed: Array = []


func before_each() -> void:
	_rooms_changed.clear()
	EventBus.interior_room_changed.connect(_on_room_changed)


func after_each() -> void:
	EventBus.interior_room_changed.disconnect(_on_room_changed)
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _on_room_changed(room: StringName) -> void:
	_rooms_changed.append(room)


func _keep(n: Node) -> Node:
	_nodes.append(n)
	return n


## A world stand-in: Root with CameraRig (+ Camera3D), outdoor Sun and a target.
func _world() -> Node3D:
	var root := _keep(Node3D.new()) as Node3D
	root.name = "P6World"
	var rig := CameraRig.new()
	rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	rig.distance = 22.0
	rig.zoom_min = 12.0
	rig.zoom_max = 24.0
	root.add_child(rig)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	root.add_child(sun)
	var target := Node3D.new()
	target.name = "Target"
	root.add_child(target)
	rig.target = target
	tree.root.add_child(root)
	return root


## A room below `world` at `origin` (Sun, Spawn, optional InteriorLighting), room config `cfg`.
func _room(world: Node3D, id: StringName, origin: Vector3, hide: bool, cfg: InteriorConfig = null,
		building: StringName = &"", lighting: bool = false) -> InteriorRoom:
	var room := InteriorRoom.new()
	room.name = "Room_" + String(id)
	room.room_id = id
	room.hide_when_inactive = hide
	room.building_id = building
	room.config = cfg
	room.environment = Environment.new()
	room.position = origin
	room.bounds_min = Vector2(-2, -1.5)
	room.bounds_max = Vector2(2, 1.5)
	room.camera_rig_path = NodePath("../CameraRig")
	room.outdoor_sun_path = NodePath("../Sun")
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	room.add_child(sun)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.position = Vector3(0.5, 0.0, 1.0)
	room.add_child(spawn)
	if lighting:
		var l := InteriorLighting.new()
		l.name = "InteriorLighting"
		room.add_child(l)
	world.add_child(room)
	return room


func _rig(world: Node3D) -> CameraRig:
	return world.get_node("CameraRig") as CameraRig


func _outdoor_sun(world: Node3D) -> Light3D:
	return world.get_node("Sun") as Light3D


func _player() -> Player:
	var p := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	tree.root.add_child(p)
	_keep(p)
	return p


# --- apply_room ---------------------------------------------------------------------------

func test_only_the_matching_room_is_active() -> void:
	var world := _world()
	var hut := _room(world, &"hut", Vector3(0, 0, -200), false, Phase6Fixtures.room_config(&"hut"))
	var crypt := _room(world, &"crypt", Vector3(60, 0, -200), true, Phase6Fixtures.room_config(&"crypt"), &"crypt")
	var chapel := _room(world, &"chapel", Vector3(120, 0, -200), true, Phase6Fixtures.room_config(&"chapel"), &"chapel")
	assert_eq([crypt.visible, chapel.visible, hut.visible], [false, false, true], "new rooms hidden, the hut as before")
	EventBus.interior_room_changed.emit(&"crypt")
	assert_eq([hut.active, crypt.active, chapel.active], [false, true, false])
	assert_eq([crypt.visible, chapel.visible], [true, false], "§4.7: only the active room is visible")
	assert_true(crypt.sun.visible)
	assert_false(hut.sun.visible or chapel.sun.visible)
	assert_false(_outdoor_sun(world).visible, "outdoor sun off inside")
	var rig := _rig(world)
	assert_not_null(rig.profile, "crypt profile")
	assert_almost(rig.distance, 10.0, 0.001, "§4.7: crypt 10 / 8–12")
	assert_eq([rig.zoom_min, rig.zoom_max], [8.0, 12.0])
	assert_eq(rig.profile.bounds_min, Vector2(58, -201.5), "bounds around the crypt origin")
	assert_eq(rig.camera.environment, crypt.environment, "the room's own environment")
	# Straight from one room into another (never happens in play, but order must not matter).
	EventBus.interior_room_changed.emit(&"chapel")
	assert_eq([crypt.active, chapel.active, crypt.visible, chapel.visible], [false, true, false, true])
	assert_almost(rig.distance, 11.0, 0.001, "chapel 11 / 9–13")
	assert_false(_outdoor_sun(world).visible)
	EventBus.interior_room_changed.emit(&"hut")
	assert_eq([hut.active, chapel.visible], [true, false])
	assert_almost(rig.distance, 9.0, 0.001, "hut 9 / 7–11 unchanged")
	assert_true(hut.visible)
	EventBus.interior_room_changed.emit(&"")
	assert_eq([hut.active, crypt.active, chapel.active], [false, false, false])
	assert_null(rig.profile, "outside: outdoor profile back")
	assert_almost(rig.distance, 22.0, 0.001)
	assert_true(_outdoor_sun(world).visible)
	assert_false(hut.sun.visible or crypt.sun.visible or chapel.sun.visible)
	assert_eq([hut.visible, crypt.visible, chapel.visible], [true, false, false], "the hut never hides")


func test_connection_order_does_not_matter() -> void:
	# The room entered last in the group must still win against the one left.
	var world := _world()
	var shed := _room(world, &"shed", Vector3(180, 0, -200), true, Phase6Fixtures.room_config(&"shed"), &"shed")
	var hut := _room(world, &"hut", Vector3(0, 0, -200), false, Phase6Fixtures.room_config(&"hut"))
	EventBus.interior_room_changed.emit(&"shed")
	assert_true(shed.active)
	assert_almost(_rig(world).distance, 8.0, 0.001, "shed 8 / 7–10")
	assert_false(_outdoor_sun(world).visible)
	assert_false(hut.active)


func test_find_and_spawn() -> void:
	var world := _world()
	var crypt := _room(world, &"crypt", Vector3(60, 0, -200), true, Phase6Fixtures.room_config(&"crypt"), &"crypt")
	assert_eq(InteriorRoom.find(tree, &"crypt"), crypt)
	assert_null(InteriorRoom.find(tree, &"chapel"))
	assert_null(InteriorRoom.find(null, &"crypt"))
	assert_true(crypt.spawn_transform().origin.is_equal_approx(Vector3(60.5, 0, -199)), "spawn in world space")
	var bare := InteriorRoom.new()
	assert_eq(bare.spawn_transform(), Transform3D.IDENTITY, "no spawn: own transform")
	bare.free()


func test_room_configs_from_the_database() -> void:
	# §3.5 / §4.8: data/config/interiors/<room_id>.tres; missing → interior_config (the hut).
	for id: StringName in Phase6Fixtures.ROOM_IDS:
		var cfg := Database.interior_config(id) as InteriorConfig
		assert_not_null(cfg, String(id))
		assert_ne(cfg, Database.config(&"interior_config"), "%s has its own config" % id)
		var spec: Dictionary = Phase6Fixtures.ROOMS[id]
		assert_almost(cfg.camera_distance, float(spec.distance), 0.001, "%s distance" % id)
		assert_eq(Vector2(cfg.camera_zoom_min, cfg.camera_zoom_max), spec.zoom, "%s zoom" % id)
		assert_eq(InteriorConfig.for_room(id), cfg)
		var fixture := Phase6Fixtures.room_config(id)
		for prop: String in ["fade_seconds", "window_day_energy", "lantern_night_energy", "candle_night_energy", "sun_day_energy",
				"fog_enabled", "fog_density", "shaft_role_as_window", "stove_night_energy"]:
			assert_eq(cfg.get(prop), fixture.get(prop), "%s.%s = fixture" % [id, prop])
	var crypt := Database.interior_config(&"crypt") as InteriorConfig
	assert_true(crypt.fog_enabled and crypt.shaft_role_as_window, "§4.8: cold air, the stair shaft as window")
	assert_eq(crypt.sun_day_energy, 0.0, "no sun in the crypt")
	assert_eq((Database.interior_config(&"chapel") as InteriorConfig).lantern_night_energy, 0.0, "no hanging lantern")
	assert_eq(InteriorConfig.for_room(&"hut"), Database.config(&"interior_config"), "the hut keeps interior_config")
	# A room without its own config resolves by room_id.
	var world := _world()
	var room := _room(world, &"crypt", Vector3(60, 0, -200), true, null, &"crypt")
	assert_eq(room.config, crypt, "config resolved from Database.interior_config(room_id)")
	assert_eq(room.camera_profile().distance, 10.0)


func test_lighting_follows_the_room_config_and_pauses_while_hidden() -> void:
	var world := _world()
	var crypt := _room(world, &"crypt", Vector3(60, 0, -200), true, null, &"crypt", true)
	var shaft := OmniLight3D.new()
	shaft.set_meta(InteriorLighting.META_ROLE, InteriorLighting.ROLE_WINDOW)
	crypt.add_child(shaft)
	var lighting := crypt.get_node("InteriorLighting") as InteriorLighting
	lighting.collect_lights(crypt)
	assert_eq(lighting.config, Database.interior_config(&"crypt"), "InteriorLighting reads the room's config")
	assert_false(lighting.is_processing(), "§9: hidden room – no lighting updates")
	lighting.apply_daylight(1.0)
	assert_almost(shaft.light_energy, 1.4, 0.001, "§4.8 (G7 round 1: brighter): shaft by day 1.4")
	assert_true(crypt.environment.fog_enabled, "cold air")
	assert_almost(crypt.environment.fog_density, 0.02, 0.0001)
	lighting.apply_daylight(0.0)
	assert_almost(shaft.light_energy, 0.05, 0.001, "shaft at night 0.05")
	EventBus.interior_room_changed.emit(&"crypt")
	assert_true(lighting.is_processing(), "active room lit")
	EventBus.interior_room_changed.emit(&"")
	assert_false(lighting.is_processing())


# --- apply_level ----------------------------------------------------------------------------

func test_apply_level_shows_hides_with_collision() -> void:
	var world := _world()
	var chapel := _room(world, &"chapel", Vector3(120, 0, -200), true, null, &"chapel")
	var rough := StaticBody3D.new()
	rough.set_meta(InteriorRoom.META_MIN_LEVEL, 1)
	rough.set_meta(InteriorRoom.META_MAX_LEVEL, 1)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	rough.add_child(shape)
	chapel.add_child(rough)
	var pews := Node3D.new()
	pews.set_meta(InteriorRoom.META_MIN_LEVEL, 2)
	var area := Area3D.new()
	pews.add_child(area)
	chapel.add_child(pews)
	var always := Node3D.new()
	chapel.add_child(always)
	var levels: Array = []
	for level: int in [0, 1, 2, 3]:
		chapel.apply_level(level)
		levels.append([rough.visible, rough.can_process(), pews.visible, area.can_process()])
		assert_true(always.visible, "no meta: untouched")
	assert_eq(levels, [[false, false, false, false], [true, true, false, false], [false, false, true, true], [false, false, true, true]],
			"§4.8: rough benches only at 1, pews from 2")
	assert_eq(chapel.level, 3)
	chapel.apply_level(1)
	assert_eq(rough.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(pews.process_mode, Node.PROCESS_MODE_DISABLED, "hidden → out of physics")
	var n := Node3D.new()
	n.set_meta(InteriorRoom.META_MAX_LEVEL, 0)
	assert_true(InteriorRoom.is_shown_at(n, 3), "max_level 0 = no upper limit")
	n.free()


func test_room_applies_its_building_level_when_ready() -> void:
	var buildings := Phase6Fixtures.crypt_at(2, tree)
	_keep(buildings)
	var world := _world()
	var room := InteriorRoom.new()
	room.room_id = &"crypt"
	room.building_id = &"crypt"
	room.hide_when_inactive = true
	var passage := Node3D.new()
	passage.set_meta(InteriorRoom.META_MIN_LEVEL, 2)
	room.add_child(passage)
	var grille := Node3D.new()
	grille.set_meta(InteriorRoom.META_MIN_LEVEL, 3)
	room.add_child(grille)
	world.add_child(room)
	assert_eq(room.level, 2, "Buildings.level(crypt)")
	assert_eq([passage.visible, grille.visible], [true, false])


# --- HutInterior -----------------------------------------------------------------------------

func test_hut_interior_is_an_interior_room() -> void:
	var hut := HutInterior.new()
	assert_true(hut is InteriorRoom)
	assert_eq(hut.room_id, &"hut")
	assert_false(hut.hide_when_inactive, "the hut stays visible (bit-identical)")
	assert_eq(hut.building_id, &"")
	assert_true(hut.is_in_group(HutInterior.HUT_GROUP) and hut.is_in_group(InteriorRoom.GROUP))
	assert_eq(HutInterior.HUT_GROUP, &"hut_interior", "the hut group is unchanged")
	hut.free()
	var scene := load("res://src/world/hut_interior/hut_interior.tscn") as PackedScene
	var inst := scene.instantiate() as HutInterior
	assert_not_null(inst, "the hut scene is still a HutInterior")
	assert_eq(inst.room_id, &"hut")
	inst.free()


func test_hut_apply_view_is_apply_room() -> void:
	var world := _world()
	var hut := HutInterior.new()
	hut.name = "Hut"
	hut.position = Vector3(0, 0, -200)
	hut.camera_rig_path = NodePath("../CameraRig")
	hut.outdoor_sun_path = NodePath("../Sun")
	hut.config = Phase6Fixtures.room_config(&"hut")
	world.add_child(hut)
	hut.apply_view(true)
	assert_true(hut.active)
	assert_almost(_rig(world).distance, 9.0, 0.001)
	assert_false(_outdoor_sun(world).visible)
	hut.apply_view(false)
	assert_false(hut.active)
	assert_null(_rig(world).profile)
	assert_true(_outdoor_sun(world).visible)


# --- Player.interior_id ------------------------------------------------------------------------

func test_set_in_interior_emits_the_room_after_interior_changed() -> void:
	var p := _player()
	var order: Array = []
	var on_inside := func(inside: bool) -> void: order.append(["inside", inside])
	var on_room := func(room: StringName) -> void: order.append(["room", room])
	EventBus.interior_changed.connect(on_inside)
	EventBus.interior_room_changed.connect(on_room)
	p.set_in_interior(true, &"crypt")
	p.set_in_interior(true)
	p.set_in_interior(false, &"crypt")
	EventBus.interior_changed.disconnect(on_inside)
	EventBus.interior_room_changed.disconnect(on_room)
	assert_eq(order, [["inside", true], ["room", &"crypt"], ["inside", true], ["room", &"hut"], ["inside", false], ["room", &""]],
			"§3.3: interior_changed first, then interior_room_changed")
	assert_eq([p.in_interior, p.interior_id], [false, &""])


func test_interior_id_save_and_load() -> void:
	var p := _player()
	p.set_in_interior(true, &"chapel")
	var saved := p.save_state()
	assert_eq(saved.interior_id, "chapel", "§5.1: interior_id saved")
	assert_eq(saved.in_interior, true)
	p.set_in_interior(false)
	p.load_state(JSON.to_native(JSON.from_native(saved)))
	assert_eq([p.in_interior, p.interior_id], [true, &"chapel"], "JSON round trip")
	assert_eq(_rooms_changed.back(), &"chapel", "load announces the room")
	p.load_state({"in_interior": true})
	assert_eq(p.interior_id, &"hut", "missing interior_id + inside → the hut (v4)")
	p.load_state({"in_interior": true, "interior_id": ""})
	assert_eq(p.interior_id, &"hut")
	p.load_state({"in_interior": true, "interior_id": 7})
	assert_eq(p.interior_id, &"hut", "damaged value → the hut")
	p.load_state({"in_interior": false, "interior_id": "crypt"})
	assert_eq([p.in_interior, p.interior_id], [false, &""], "outside wins")
	p.load_state({})
	assert_eq(p.interior_id, &"")


func test_unknown_room_falls_back_to_the_hut_when_rooms_exist() -> void:
	var world := _world()
	_room(world, &"hut", Vector3(0, 0, -200), false, Phase6Fixtures.room_config(&"hut"))
	_room(world, &"crypt", Vector3(60, 0, -200), true, null, &"crypt")
	var p := _player()
	p.load_state({"in_interior": true, "interior_id": "crypt"})
	assert_eq(p.interior_id, &"crypt", "a room of this world")
	p.load_state({"in_interior": true, "interior_id": "cellar"})
	assert_eq(p.interior_id, &"hut", "no such room → the hut")


# --- BuildingDoor / RoomExit ---------------------------------------------------------------------

func _door_setup(building: StringName, level: int) -> Dictionary:
	var buildings := tree.get_first_node_in_group(&"buildings") as Buildings
	if buildings == null:
		buildings = Phase6Fixtures.buildings_at({building: level}, tree)
		_keep(buildings)
	else:
		var levels := buildings.levels()
		levels[building] = level
		buildings.load_state({"levels": levels})
	var world := _world()
	var spec: Dictionary = Phase6Fixtures.ROOMS[building]
	var room := _room(world, building, spec.origin, true, Phase6Fixtures.room_config(building), building)
	var door := (load(DOOR_SCENE) as PackedScene).instantiate() as BuildingDoor
	door.building_id = building
	door.data = Phase6Fixtures.building(building)
	door.position = Vector3(-9.0, 0.0, 8.2)
	world.add_child(door)
	var exit := (load(EXIT_SCENE) as PackedScene).instantiate() as RoomExit
	exit.building_id = building
	room.add_child(exit)
	return {"door": door, "exit": exit, "room": room, "buildings": buildings, "world": world}


func test_door_closed_at_level_zero() -> void:
	var s := _door_setup(&"crypt", 0)
	var door: BuildingDoor = s.door
	var p := _player()
	assert_false(door.is_open())
	assert_false(door.can_interact(p))
	assert_eq(door.get_interaction_prompt(p), "", "§3.4: level 0 – no prompt")
	(s.buildings as Buildings).load_state({"levels": {"crypt": 1}})
	assert_true(door.is_open())
	assert_eq(door.get_interaction_prompt(p), "[E] Gruft betreten")
	assert_true(door.can_interact(p))


func test_enter_and_leave_the_crypt() -> void:
	var s := _door_setup(&"crypt", 1)
	var door: BuildingDoor = s.door
	var exit: RoomExit = s.exit
	var room: InteriorRoom = s.room
	var p := _player()
	(room.room_config() as InteriorConfig).fade_seconds = 0.5
	assert_true(HutPortal.travel(p, room.spawn_transform(), true, 0.0, room.room_id), "instant travel works")
	assert_eq([p.in_interior, p.interior_id], [true, &"crypt"])
	assert_true(room.active and room.visible)
	assert_eq(exit.get_interaction_prompt(p), "[E] Hinaufgehen", "§4.7: the crypt's way out")
	assert_true(exit.can_interact(p))
	HutPortal.arrive(p, door.exit_transform(), false)
	assert_eq([p.in_interior, p.interior_id], [false, &""])
	assert_false(room.visible)
	assert_true(p.global_position.is_equal_approx(door.exit_transform().origin), "in front of the door")
	assert_true(door.exit_transform().origin.z > door.global_position.z, "outside the building (+Z)")
	# The door itself travels with the fade (midpoint = half the fade).
	door.interact(p)
	assert_true(HutPortal.is_travelling(p), "fading")
	assert_false(door.can_interact(p), "one trip at a time")
	await tree.create_timer(0.4).timeout
	assert_eq(p.interior_id, &"crypt", "arrived at the midpoint")
	var at := room.spawn_transform().origin
	assert_true(Vector2(p.global_position.x, p.global_position.z).is_equal_approx(Vector2(at.x, at.z)), "at the foot of the stairs")
	exit.interact(p)
	await tree.create_timer(0.4).timeout
	assert_eq(p.interior_id, &"", "back outside")


func test_corpse_allowed_in_crypt_not_in_shed() -> void:
	var crypt := _door_setup(&"crypt", 1)
	var p := _player()
	var corpse := Node3D.new()
	_keep(corpse)
	p.carried = corpse
	var door: BuildingDoor = crypt.door
	assert_true(door.can_interact(p), "§2.2: with a corpse into the crypt")
	assert_eq(door.get_interaction_prompt(p), "[E] Gruft betreten")
	assert_true((crypt.exit as RoomExit).can_interact(p), "and up again")
	var shed := _door_setup(&"shed", 1)
	var shed_door: BuildingDoor = shed.door
	assert_false(shed_door.can_interact(p), "§2.2: the shed refuses")
	assert_eq(shed_door.get_interaction_prompt(p), HutDoor.TEXT_CORPSE_OUTSIDE)
	assert_eq((shed.exit as RoomExit).get_interaction_prompt(p), HutDoor.TEXT_CORPSE_OUTSIDE)
	p.carried = null
	assert_true(shed_door.can_interact(p))
	assert_eq(shed_door.get_interaction_prompt(p), "[E] Schuppen betreten")
	assert_eq((shed.exit as RoomExit).get_interaction_prompt(p), "[E] Hinausgehen")


func test_door_and_exit_without_world() -> void:
	var door := (load(DOOR_SCENE) as PackedScene).instantiate() as BuildingDoor
	door.building_id = &"chapel"
	tree.root.add_child(door)
	_keep(door)
	var p := _player()
	assert_false(door.is_open(), "no Buildings node → closed")
	assert_eq(door.get_interaction_prompt(p), "")
	assert_null(door.room())
	assert_eq(BuildingDoor.find(tree, &"chapel"), door)
	assert_null(BuildingDoor.find(tree, &"crypt"))
	var exit := (load(EXIT_SCENE) as PackedScene).instantiate() as RoomExit
	exit.building_id = &"crypt"
	tree.root.add_child(exit)
	_keep(exit)
	assert_false(exit.can_interact(p), "no outside door")
	assert_eq(exit.get_interaction_prompt(p), "")
	assert_not_null(exit.interactable, "room_exit.tscn has an Interactable")
