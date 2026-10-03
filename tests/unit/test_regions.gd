extends TestCase
## P1 (docs/PHASE7_DESIGN.md §3.4, §4.1, §10): regions without the real world – RegionRoot.apply_region
## (active / inactive, managed_paths hidden + PROCESS_MODE_DISABLED, Npc.refresh on activation, the
## camera rig's base profile, clear_profile → the region), the lookups (waypoints, spawns, rooms,
## WorldRoot fallback), RegionPortal / RegionTravel block reasons (corpse, action, fade, flag), the trip
## (+30 min exactly once, region_changed after interior_*, village_trips), CameraRig.set_base_profile
## (bit-identical without it) and Player.region_id save / tolerant load. Configs: Phase7Fixtures.

const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const NPC_SCENE := "res://src/entities/npc/npc.tscn"
const PORTAL_SCENE := "res://src/entities/region_portal/region_portal.tscn"


## The graveyard's WorldRoot stand-in: waypoints and ground height for the graveyard region.
class FakeWorld extends Node3D:
	var points: Dictionary = {}
	var facings: Dictionary = {}

	func get_waypoint(id: StringName) -> Vector3:
		return points.get(id, Vector3.ZERO)

	func get_waypoint_facing(id: StringName) -> float:
		return facings.get(id, NAN)

	func ground_height(_pos: Vector2) -> float:
		return 0.25


var world: FakeWorld
var rig: CameraRig
var graveyard: RegionRoot
var village: RegionRoot
var player: Player
var events: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	events.clear()
	world = FakeWorld.new()
	world.name = "P7World"
	world.points = {&"from_village": Vector3(8.0, 0.0, 23.4), &"road_end": Vector3(5, 0, 24)}
	world.facings = {&"from_village": -0.8}
	rig = CameraRig.new()
	rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	rig.zoom_min = 12.0
	rig.zoom_max = 24.0
	rig.bounds_enabled = true
	rig.bounds_min = Vector2(-11.5, -24)
	rig.bounds_max = Vector2(27, 23)
	world.add_child(rig)
	for n: String in ["Decor", "Lights", "Grass", "Entities"]:
		var node := Node3D.new()
		node.name = n
		world.add_child(node)
	var regions := Node3D.new()
	regions.name = "Regions"
	world.add_child(regions)
	graveyard = Phase7Fixtures.region_at(&"graveyard")
	graveyard.name = "Graveyard"
	graveyard.camera_rig_path = NodePath("../../CameraRig")
	regions.add_child(graveyard)
	village = Phase7Fixtures.region_at(&"village")
	village.name = "Village"
	village.position = Vector3(0, 0, 400)
	village.camera_rig_path = NodePath("../../CameraRig")
	_marker(village, "Waypoints/v_a", Vector3(-10, 0, 0), true, 1.0)
	_marker(village, "Waypoints/v_b", Vector3(10, 0, 0))
	_marker(village, "Spawns/from_graveyard", Vector3(-24.6, 0, 1.5), false, PI * 0.5)
	regions.add_child(village)
	tree.root.add_child(world)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.instant_actions = true
	world.add_child(player)
	rig.target = player
	EventBus.region_changed.connect(_on_region)
	EventBus.interior_changed.connect(_on_interior)
	EventBus.interior_room_changed.connect(_on_room)
	EventBus.screen_fade_requested.connect(_on_fade)
	await wait_frames(2)


func after_each() -> void:
	EventBus.region_changed.disconnect(_on_region)
	EventBus.interior_changed.disconnect(_on_interior)
	EventBus.interior_room_changed.disconnect(_on_room)
	EventBus.screen_fade_requested.disconnect(_on_fade)
	if is_instance_valid(world):
		world.free()
	GameState.reset()
	TimeManager.reset()


func _on_region(id: StringName) -> void:
	events.append(["region", id])


func _on_interior(inside: bool) -> void:
	events.append(["interior", inside])


func _on_room(room: StringName) -> void:
	events.append(["room", room])


func _on_fade(seconds: float) -> void:
	events.append(["fade", seconds])


func _marker(parent: Node3D, path: String, pos: Vector3, facing: bool = false, yaw: float = 0.0) -> Marker3D:
	var holder_name := path.get_slice("/", 0)
	var holder := parent.get_node_or_null(holder_name) as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = holder_name
		parent.add_child(holder)
	var m := Marker3D.new()
	m.name = path.get_slice("/", 1)
	m.position = pos
	m.rotation.y = yaw
	if facing:
		m.set_meta(&"facing", true)
	holder.add_child(m)
	return m


func _village_npc() -> Npc:
	var npc := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	npc.name = "npc_v"
	npc.npc_id = &"p7_test"
	npc.region_id = &"village"
	var sched := NpcSchedule.new()
	sched.npc_id = &"p7_test"
	sched.display_name = "Probe"
	var a := ScheduleEntry.new()
	a.start_minute = 0
	a.path = PackedStringArray(["v_a"])
	a.region = &"village"
	var b := ScheduleEntry.new()
	b.start_minute = 700
	b.path = PackedStringArray(["v_b"])
	b.region = &"village"
	sched.entries = [a, b]
	npc.schedule = sched
	village.add_child(npc)
	return npc


# --- RegionRoot ------------------------------------------------------------------------------

func test_initial_state_graveyard_active() -> void:
	assert_eq(RegionRoot.current(tree), &"graveyard")
	assert_true(graveyard.active and not village.active)
	for n: String in ["Decor", "Lights", "Grass"]:
		var node := world.get_node(n) as Node3D
		assert_true(node.visible and node.process_mode == Node.PROCESS_MODE_INHERIT, n + " shown")
	assert_false(village.visible, "the village hides while the graveyard is active")
	assert_eq(village.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_true((world.get_node("Entities") as Node3D).process_mode == Node.PROCESS_MODE_INHERIT, "unmanaged nodes untouched")
	assert_eq(graveyard.managed_nodes().size(), 3, "Decor, Lights, Grass from the WorldRoot (parent of Regions)")
	assert_eq(village.managed_nodes(), [village] as Array[Node], "'.' = the village scene itself")
	# On start the active region hands the rig its base profile (here the fixture bounds).
	assert_eq([rig.bounds_min, rig.bounds_max, rig.distance], [Vector2(-22, -20), Vector2(22, 23), 22.0], "fixture bounds applied")


func test_apply_region_village() -> void:
	player.set_region(&"village")
	assert_true(village.active and not graveyard.active)
	assert_true(village.visible and village.process_mode == Node.PROCESS_MODE_INHERIT)
	for n: String in ["Decor", "Lights", "Grass"]:
		var node := world.get_node(n) as Node3D
		assert_false(node.visible, n + " hidden")
		assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, n + " disabled")
	assert_eq([rig.bounds_enabled, rig.bounds_min, rig.bounds_max], [true, Vector2(-22, 392), Vector2(20, 408)], "bounds = origin + config")
	assert_eq([rig.zoom_min, rig.zoom_max, rig.distance], [12.0, 24.0, 22.0])
	player.set_region(&"graveyard")
	assert_true(graveyard.active and not village.active)
	assert_true((world.get_node("Decor") as Node3D).visible)
	assert_false(village.visible)


func test_hide_when_inactive_false_only_disables() -> void:
	village.hide_when_inactive = false
	village.visible = true
	village.apply_region(&"graveyard")
	assert_true(village.visible)
	assert_eq(village.process_mode, Node.PROCESS_MODE_DISABLED)


func test_npc_refresh_on_activation() -> void:
	var npc := _village_npc()
	await wait_frames(1)
	TimeManager.set_time(TimeManager.day, 600)
	npc.refresh()
	assert_almost(npc.global_position.x, -10.0, 0.01, "at v_a")
	assert_almost(npc.global_position.z, 400.0, 0.01)
	TimeManager.set_time(TimeManager.day, 720)
	await wait_frames(2)
	assert_almost(npc.global_position.x, -10.0, 0.01, "the inactive (disabled) village does not evaluate")
	player.set_region(&"village")
	assert_almost(npc.global_position.x, 10.0, 0.01, "refreshed from the clock on activation")


func test_camera_profile_and_clear_profile_returns_to_region() -> void:
	var room := CameraProfile.new()
	room.distance = 9.0
	room.zoom_min = 7.0
	room.zoom_max = 11.0
	room.bounds_enabled = true
	room.bounds_min = Vector2(298, -202)
	room.bounds_max = Vector2(302, -198)
	player.set_region(&"village")
	rig.set_distance(16.0)
	rig.set_profile(room)
	assert_eq(rig.distance, 9.0)
	rig.clear_profile()
	assert_eq([rig.bounds_min, rig.distance], [Vector2(-22, 392), 16.0], "same region: back with the zoom it had")
	rig.set_profile(room)
	player.set_region(&"graveyard")   # a load in a graveyard room after the village
	assert_eq(rig.distance, 9.0, "the room profile stays on while inside")
	rig.clear_profile()
	assert_eq([rig.bounds_min, rig.bounds_max, rig.distance], [Vector2(-22, -20), Vector2(22, 23), 22.0], "the new region's base")
	var p := village.camera_profile()
	assert_eq([p.distance, p.zoom_min, p.zoom_max, p.bounds_enabled, p.environment, p.attributes], [22.0, 12.0, 24.0, true, null, null],
			"shared WorldEnvironment (no own environment)")


func test_set_base_profile_without_room_and_repeat() -> void:
	var own := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	own.add_child(cam)
	world.add_child(own)
	own.set_distance(20.0)
	var base := CameraProfile.new()
	base.distance = 14.0
	base.zoom_min = 12.0
	base.zoom_max = 24.0
	own.set_base_profile(base)
	assert_eq(own.distance, 14.0, "applied at once")
	own.set_distance(18.0)
	own.set_base_profile(base)
	assert_eq(own.distance, 18.0, "the same base again keeps the zoom")
	own.set_base_profile(null)
	assert_null(own.base_profile)
	assert_eq(own.distance, 18.0)


func test_rig_without_base_profile_unchanged() -> void:
	var own := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	own.add_child(cam)
	own.zoom_min = 10.0
	own.zoom_max = 34.0
	world.add_child(own)
	own.set_distance(30.0)
	var room := CameraProfile.new()
	room.distance = 9.0
	own.set_profile(room)
	own.clear_profile()
	assert_eq([own.distance, own.zoom_min, own.zoom_max, own.bounds_enabled], [30.0, 10.0, 34.0, false], "Phase-6 behaviour")


func test_lookups() -> void:
	assert_eq(village.get_waypoint(&"v_a"), Vector3(-10, 0, 400))
	assert_almost(village.get_waypoint_facing(&"v_a"), 1.0)
	assert_true(is_nan(village.get_waypoint_facing(&"v_b")), "no facing meta → NAN")
	assert_eq(graveyard.get_waypoint(&"road_end"), Vector3(5, 0, 24), "graveyard delegates to the WorldRoot")
	assert_almost(graveyard.get_waypoint_facing(&"from_village"), -0.8)
	assert_almost(graveyard.ground_height(Vector2(1, 1)), 0.25, 0.0001, "graveyard ground from the WorldRoot")
	assert_almost(village.ground_height(Vector2(0, 400)), 0.0, 0.0001, "flat village without a heightmap")
	var spawn := village.spawn_transform(&"from_graveyard")
	assert_true(spawn.origin.is_equal_approx(Vector3(-24.6, 0, 401.5)))
	assert_true(spawn.basis.is_equal_approx(Basis(Vector3.UP, PI * 0.5)))
	var back := graveyard.spawn_transform(&"from_village")
	assert_true(back.origin.is_equal_approx(Vector3(8.0, 0.0, 23.4)), "graveyard spawn = waypoint")
	assert_true(back.basis.is_equal_approx(Basis(Vector3.UP, -0.8)))
	# Waypoints of a room of the region (v_in_*).
	var room := InteriorRoom.new()
	room.room_id = &"inn"
	room.region_id = &"village"
	room.position = Vector3(240, 0, -200)
	world.add_child(room)
	_marker(room, "Waypoints/v_in_inn_bar", Vector3(1, 0, -1), true, 0.5)
	assert_eq(village.get_waypoint(&"v_in_inn_bar"), Vector3(241, 0, -201), "room waypoint")
	assert_almost(village.get_waypoint_facing(&"v_in_inn_bar"), 0.5)
	assert_eq(RegionRoot.find(tree, &"village"), village)
	assert_null(RegionRoot.find(tree, &"forest"))


# --- portal & travel --------------------------------------------------------------------------

func _portal() -> RegionPortal:
	var portal := (load(PORTAL_SCENE) as PackedScene).instantiate() as RegionPortal
	portal.target_region = &"village"
	portal.target_spawn = &"from_graveyard"
	world.get_node("Entities").add_child(portal)
	return portal


func test_portal_block_reasons() -> void:
	var portal := _portal()
	assert_eq(portal.get_interaction_prompt(player), "", "scenery before village_open")
	assert_false(portal.can_interact(player))
	assert_eq(RegionTravel.block_reason(player, &"village"), RegionTravel.TEXT_CLOSED)
	assert_eq(RegionTravel.block_reason(player, &"graveyard"), "", "the way home needs no flag")
	GameState.set_flag(&"village_open", true)
	assert_eq(portal.get_interaction_prompt(player), "[E] Nach Hollerbrück (30 Min)")
	assert_true(portal.can_interact(player))
	var corpse := Node3D.new()
	player.attach_carried(corpse, "corpse_0001")
	assert_eq(portal.get_interaction_prompt(player), RegionTravel.TEXT_CORPSE, "dimmed with a corpse")
	assert_false(portal.can_interact(player))
	player.detach_carried()
	corpse.free()
	player.instant_actions = false
	assert_true(player.start_timed_action("test", 10, func() -> void: pass))
	assert_eq(RegionTravel.block_reason(player, &"village"), RegionTravel.TEXT_BUSY)
	player.cancel_timed_action()
	player.set_meta(HutPortal.META_TRAVELLING, true)
	assert_eq(RegionTravel.block_reason(player, &"village"), RegionTravel.TEXT_BUSY, "not during a fade")
	player.remove_meta(HutPortal.META_TRAVELLING)
	assert_eq(RegionTravel.block_reason(null, &"village"), "-")
	assert_false(RegionTravel.travel(null, &"village", Transform3D(), 30, 0.0))
	portal.target_region = &"forest"
	assert_eq(portal.get_interaction_prompt(player), "", "no target region in the world → no prompt")


func test_travel_immediate_advances_once_and_orders_signals() -> void:
	GameState.set_flag(&"village_open", true)
	TimeManager.set_time(TimeManager.day, 14 * 60)
	var start := TimeManager.total_minutes()
	events.clear()
	var spawn := village.spawn_transform(&"from_graveyard")
	assert_true(RegionTravel.travel(player, &"village", spawn, 30, 0.0))
	assert_eq(TimeManager.total_minutes() - start, 30, "+30 minutes exactly once")
	assert_eq(player.region_id, &"village")
	assert_true(player.global_position.is_equal_approx(spawn.origin))
	assert_eq(events, [["interior", false], ["room", &""], ["region", &"village"]], "region_changed after interior_*")
	assert_eq(GameState.get_stat(&"village_trips"), 1)
	assert_true(RegionTravel.travel(player, &"graveyard", graveyard.spawn_transform(&"from_village"), 30, 0.0))
	assert_eq(TimeManager.total_minutes() - start, 60)
	assert_eq(GameState.get_stat(&"village_trips"), 1, "only the way into the village counts")
	assert_eq(player.region_id, &"graveyard")


func test_portal_travel_with_fade() -> void:
	GameState.set_flag(&"village_open", true)
	var portal := _portal()
	var start := TimeManager.total_minutes()
	events.clear()
	portal.interact(player)
	assert_eq(events, [["fade", 0.8]], "the fade first")
	assert_true(HutPortal.is_travelling(player), "HutPortal.is_travelling holds during the trip")
	assert_eq(TimeManager.total_minutes(), start, "the clock jumps in the middle of the fade")
	assert_false(portal.can_interact(player), "no second trip")
	assert_eq(RegionTravel.block_reason(player, &"village"), RegionTravel.TEXT_BUSY)
	await wait_for_signal(EventBus.region_changed, 3.0)
	assert_false(HutPortal.is_travelling(player))
	assert_eq(TimeManager.total_minutes() - start, 30)
	assert_eq(player.region_id, &"village")
	assert_true(village.active)
	await wait_frames(3)
	assert_eq(TimeManager.total_minutes() - start, 30, "exactly once")


# --- Player ---------------------------------------------------------------------------------------

func test_player_save_and_tolerant_load() -> void:
	player.set_region(&"village")
	var state := player.save_state()
	assert_eq(state.get("region_id"), "village")
	player.set_region(&"graveyard")
	events.clear()
	player.load_state(state)
	assert_eq(player.region_id, &"village")
	assert_true(village.active)
	assert_eq(events[events.size() - 1], ["region", &"village"], "after interior_*")
	assert_eq(events[0], ["interior", false])
	var old := state.duplicate(true)
	old.erase("region_id")
	player.load_state(old)
	assert_eq(player.region_id, &"graveyard", "v5 save without region_id → graveyard")
	old["region_id"] = 7
	player.load_state(old)
	assert_eq(player.region_id, &"graveyard", "not a string → graveyard")
	old["region_id"] = "forest"
	player.load_state(old)
	assert_eq(player.region_id, &"graveyard", "unknown region → graveyard (warning)")
	old["region_id"] = "village"
	old["in_interior"] = true
	old["interior_id"] = "hut"
	player.load_state(old)
	assert_eq([player.region_id, player.interior_id], [&"village", &"hut"], "room and region both restored")
