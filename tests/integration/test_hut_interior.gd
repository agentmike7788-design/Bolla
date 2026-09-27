extends TestCase
## Change round 2 (docs §11) on the real world: the hut interior scene instanced far from the
## graveyard, every interactive layout piece as an entity, the portal (HutDoor ↔ InteriorDoor:
## fade, teleport, camera profile, suns), in_interior through save / load, the chest storage
## round trip, the grave register entries and the interior lighting by night and by day.

## Per-process save folder (TestCase.user_dir): parallel runs share user:// (flaky slots).
var TEST_SAVES := TestCase.user_dir("test_saves")
const SLOT_INSIDE := 96
const SLOT_OUTSIDE := 95
const INTERIOR_LAYOUT := "res://data/world/hut_interior_layout.json"
const WORLD_LAYOUT := "res://data/world/graveyard_layout.json"
const ENTITY_CLASSES := {"bed": "Bed", "chest": "Chest", "desk": "Desk", "stove": "Stove"}
const NIGHT := 1380
const NOON := 720

var world: WorldRoot
var player: Player
var interior: HutInterior
var rig: CameraRig
var panels: Array = []
var fades: Array = []


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	panels.clear()
	fades.clear()
	EventBus.ui_panel_requested.connect(_on_panel)
	EventBus.screen_fade_requested.connect(_on_fade)
	await SaveManager.new_game()
	_bind_world()
	TimeManager.running = false


func after_each() -> void:
	EventBus.ui_panel_requested.disconnect(_on_panel)
	EventBus.screen_fade_requested.disconnect(_on_fade)
	for slot: int in [SLOT_INSIDE, SLOT_OUTSIDE, 0]:
		SaveManager.delete_save(slot)
	TestCase.remove_user_dir(TEST_SAVES)


# --- scene & layout -------------------------------------------------------------------------

func test_interior_is_instanced_far_from_the_graveyard() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD_LAYOUT))
	assert_not_null(interior, "HutInterior in the world")
	assert_eq(interior.scene_file_path, "res://src/world/hut_interior/hut_interior.tscn")
	assert_eq(interior.global_position, Vector3(layout.hut_interior.origin[0], layout.hut_interior.origin[1], layout.hut_interior.origin[2]))
	assert_eq(interior.get_node(interior.camera_rig_path), rig)
	assert_eq(interior.get_node(interior.outdoor_sun_path), world.get_node("Sun"))
	assert_false(interior.sun.visible, "interior sun hidden outdoors")
	assert_true((world.get_node("Sun") as Light3D).visible)
	assert_false(interior.active)
	for path: String in ["Room", "Furniture", "Entities", "Colliders", "Spawn", "Lighting", "Sun", "Entities/interior_door"]:
		assert_true(interior.has_node(path), "HutInterior/" + path)


func test_every_interactive_layout_piece_has_an_entity() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INTERIOR_LAYOUT))
	var found := 0
	for item: Dictionary in layout.items:
		if not item.has("interact"):
			continue
		found += 1
		var id := String(item.interact)
		var node := interior.get_node_or_null("Entities/" + id) as Node3D
		assert_not_null(node, "entity " + id)
		if node == null:
			continue
		assert_eq(node.get_script().get_global_name(), ENTITY_CLASSES[id], id)
		assert_eq(node.get_node("Model").scene_file_path, "res://assets/models/interior/%s.glb" % item.asset, id + " model")
		var local := node.global_position - interior.global_position
		assert_almost(local.x, float(item.pos[0]), 0.001, id + " x")
		assert_almost(local.z, float(item.pos[1]), 0.001, id + " z")
		var use := node.get_node("UsePos") as Node3D
		var use_local := use.global_position - interior.global_position
		assert_almost(use_local.x, float(item.use_pos[0]), 0.001, id + " use x")
		assert_almost(use_local.z, float(item.use_pos[1]), 0.001, id + " use z")
		var area := node.get_node("Interactable") as Interactable
		assert_true(area.get_child(0) is CollisionShape3D, id + " interactable shape")
		assert_ne(node.call(&"get_interaction_prompt", player), "", id + " offers something")
	assert_eq(found, ENTITY_CLASSES.size(), "bed, chest, desk, stove")
	var door := interior.get_node("Entities/interior_door") as InteriorDoor
	var door_local := door.global_position - interior.global_position
	assert_almost(door_local.x, float(layout.door_inside[0]), 0.001)
	assert_almost(door_local.z, float(layout.door_inside[1]), 0.001)
	var spawn_local := interior.spawn_transform().origin - interior.global_position
	assert_almost(spawn_local.x, float(layout.spawn_inside[0]), 0.001)
	assert_almost(spawn_local.z, float(layout.spawn_inside[1]), 0.001)


func test_interior_colliders_hold_the_player() -> void:
	await tree.physics_frame
	await tree.physics_frame
	var space := world.get_world_3d().direct_space_state
	var spawn := interior.spawn_transform().origin
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(spawn + Vector3.UP, spawn + Vector3.DOWN, 1))
	assert_false(down.is_empty(), "floor under the spawn")
	if not down.is_empty():
		assert_almost((down.position as Vector3).y, spawn.y, 0.01, "floor at y 0")
	for dir: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var from := interior.global_position + Vector3(0.0, 1.0, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 4.0, 1))
		assert_false(hit.is_empty(), "wall towards %s" % dir)
	var bodies := interior.get_node("Colliders").get_children()
	for id: String in ["Room", "bed", "chest", "desk", "stove"]:
		assert_true(interior.has_node("Colliders/" + id), "collider " + id)
	for body: Node in bodies:
		assert_eq((body as StaticBody3D).collision_layer, 1, "world layer " + body.name)
	# The player stands at the spawn and stays inside the room (no falling through).
	HutPortal.arrive(player, interior.spawn_transform(), true)
	for i: int in 20:
		await tree.physics_frame
	assert_true(player.global_position.distance_to(spawn) < 0.2, "stands at the spawn (%s)" % player.global_position)


# --- portal ---------------------------------------------------------------------------------

func test_enter_and_leave_through_the_doors() -> void:
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var cfg := interior.config
	assert_eq(door.get_interaction_prompt(player), "[E] Hütte betreten")
	var outdoor_distance := rig.distance
	var outdoor_env := rig.camera.environment
	door.interact(player)
	assert_eq(fades, [cfg.fade_seconds], "one short fade")
	assert_false(player.in_interior, "teleport only at the fade's midpoint")
	assert_true(HutPortal.is_travelling(player))
	door.interact(player)
	assert_eq(fades.size(), 1, "no second trip while travelling")
	assert_true(await wait_for_signal(EventBus.interior_changed, 3.0), "arrived")
	assert_true(player.in_interior)
	assert_false(HutPortal.is_travelling(player))
	assert_true(player.global_position.distance_to(interior.spawn_transform().origin) < 0.01, "at spawn_inside")
	_assert_inside_view()
	assert_almost(rig.distance, cfg.camera_distance, 0.001, "interior distance ~9 m")
	assert_almost(rig.pitch_deg, 45.0, 0.001, "same pitch")
	assert_almost(rig.fov_deg, 30.0, 0.001, "same FOV")
	# Leave again.
	var exit_door := interior.get_node("Entities/interior_door") as InteriorDoor
	assert_eq(exit_door.get_interaction_prompt(player), "[E] Hinausgehen")
	exit_door.interact(player)
	assert_true(await wait_for_signal(EventBus.interior_changed, 3.0), "left")
	assert_false(player.in_interior)
	assert_true(player.global_position.distance_to(door.exit_transform().origin) < 0.01, "in front of the hut door")
	assert_null(rig.profile, "outdoor framing")
	assert_almost(rig.distance, outdoor_distance, 0.001, "outdoor zoom restored")
	assert_eq(rig.camera.environment, outdoor_env)
	assert_true((world.get_node("Sun") as Light3D).visible)
	assert_false(interior.sun.visible)


func test_the_world_keeps_running_inside() -> void:
	TimeManager.running = true
	var before := TimeManager.total_minutes()
	HutPortal.arrive(player, interior.spawn_transform(), true)
	await wait_frames(3)
	assert_false(TimeManager.paused, "no pause inside")
	assert_false(get_tree_paused())
	TimeManager.advance(30)
	assert_eq(TimeManager.total_minutes(), before + 30)
	TimeManager.running = false


func test_corpse_must_stay_outside() -> void:
	var door := world.get_node_by_layout_id("hut_door") as HutDoor
	var dropoff := world.get_node_by_layout_id("dropoff") as Dropoff
	var record := world.corpse_manager.spawn_corpse(null, dropoff.slot_transform(), &"dropoff")
	assert_true(world.corpse_manager.pick_up(record.id, player))
	assert_eq(door.get_interaction_prompt(player), "Leiche draußen ablegen")
	assert_false(door.can_interact(player))
	door.interact(player)
	assert_true(fades.is_empty(), "no fade")
	assert_false(player.in_interior)


func test_camera_stays_in_the_room_bounds() -> void:
	HutPortal.arrive(player, interior.spawn_transform(), true)
	var origin := Vector2(interior.global_position.x, interior.global_position.z)
	for corner: Vector2 in [Vector2(-2.0, -1.5), Vector2(2.0, 1.5), Vector2(2.0, -1.5), Vector2(-2.0, 1.5)]:
		player.global_position = interior.global_position + Vector3(corner.x, 0.0, corner.y)
		rig.snap()
		var focus := rig.camera.global_position - Vector3.BACK.rotated(Vector3.RIGHT, -deg_to_rad(rig.pitch_deg)) * rig.distance - rig.look_offset
		var local := Vector2(focus.x, focus.z) - origin
		assert_true(local.x >= interior.bounds_min.x - 0.001 and local.x <= interior.bounds_max.x + 0.001
				and local.y >= interior.bounds_min.y - 0.001 and local.y <= interior.bounds_max.y + 0.001,
				"focus %s clamped for player at %s" % [local, corner])


# --- save / load ----------------------------------------------------------------------------

func test_in_interior_survives_save_and_load() -> void:
	HutPortal.arrive(player, interior.spawn_transform(), true)
	var inside_at := player.global_position
	assert_eq(player.save_state().in_interior, true)
	assert_eq(SaveManager.save_game(SLOT_INSIDE), OK)
	HutPortal.arrive(player, (world.get_node_by_layout_id("hut_door") as HutDoor).exit_transform(), false)
	assert_eq(SaveManager.save_game(SLOT_OUTSIDE), OK)
	var err: Error = await SaveManager.load_game(SLOT_INSIDE)
	assert_eq(err, OK)
	_bind_world()
	assert_true(player.in_interior, "in_interior loaded")
	assert_true(player.global_position.distance_to(inside_at) < 0.05, "inside the hut")
	_assert_inside_view()
	var at_load := rig.camera.global_position
	rig.snap()
	assert_true(rig.camera.global_position.distance_to(at_load) < 0.05, "camera already on the player")
	# Loading an outdoor save from inside switches the view back.
	err = await SaveManager.load_game(SLOT_OUTSIDE)
	assert_eq(err, OK)
	_bind_world()
	assert_false(player.in_interior)
	assert_null(rig.profile)
	assert_true((world.get_node("Sun") as Light3D).visible)
	# apply_state on the same world (no scene change) follows too.
	var state := SaveManager.collect_state()
	(state.nodes.player as Dictionary)["in_interior"] = true
	(state.nodes.player as Dictionary)["position"] = interior.spawn_transform().origin
	SaveManager.apply_state(state)
	_assert_inside_view()


func test_chest_storage_round_trip() -> void:
	var chest := interior.get_node("Entities/chest") as Chest
	assert_eq(chest.save_id, "hut_chest")
	assert_true(chest.is_in_group(&"saveable"))
	assert_eq(chest.storage.slot_count, 16)
	assert_eq(chest.get_interaction_prompt(player), "[E] Truhe öffnen")
	chest.interact(player)
	assert_eq(panels.back()[0], &"chest")
	var ctx: Dictionary = panels.back()[1]
	assert_eq(ctx.storage, chest.storage)
	assert_eq(ctx.inventory, player.inventory)
	assert_eq(ctx.chest, chest)
	assert_eq(chest.storage.add_item(&"wood", 7), 0)
	assert_eq(chest.storage.add_item(&"stone", 3), 0)
	var saved := chest.save_state()
	assert_eq(SaveManager.save_game(SLOT_INSIDE), OK)
	chest.storage.clear()
	var err: Error = await SaveManager.load_game(SLOT_INSIDE)
	assert_eq(err, OK)
	_bind_world()
	var loaded := interior.get_node("Entities/chest") as Chest
	assert_eq(loaded.storage.count(&"wood"), 7)
	assert_eq(loaded.storage.count(&"stone"), 3)
	assert_eq(loaded.save_state(), saved, "identical after save → load")
	assert_eq(SaveManager.collect_state().nodes.hut_chest, saved)


func test_desk_lists_the_burials() -> void:
	var desk := interior.get_node("Entities/desk") as Desk
	assert_eq(desk.get_interaction_prompt(player), "[E] Grabregister lesen")
	desk.interact(player)
	assert_eq(panels.back()[0], &"grave_register")
	assert_eq((panels.back()[1] as Dictionary).entries, [], "no burials yet")
	TimeManager.set_time(2, 600)
	var manager := world.corpse_manager
	var graveyard := world.graveyard
	var marked := manager.spawn_corpse(null, Transform3D.IDENTITY, &"ground")
	var filled := manager.spawn_corpse(null, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)), &"ground")
	graveyard.dig("plot_02")
	assert_true(graveyard.bury("plot_02", marked.id))
	player.inventory.add_item(&"wooden_cross", 1)
	graveyard.place_marker("plot_02", &"wooden_cross", player.inventory)
	assert_eq(graveyard.get_grave("plot_02").state, GraveRecord.State.MARKED)
	graveyard.dig("plot_05")
	assert_true(graveyard.bury("plot_05", filled.id))
	desk.interact(player)
	var ctx: Dictionary = panels.back()[1]
	# Phase 3 (QA-01): the register footer shows the cemetery quality (graves + decor − dirt).
	var score := world.get_node("Systems/CemeteryScore") as CemeteryScore
	assert_eq(ctx.total, score.total())
	assert_eq(ctx.rating, score.rating())
	var entries: Array = ctx.entries
	assert_eq(entries.size(), 2, "one line per grave with a corpse (old graves excluded)")
	var by_grave := {}
	for e: Dictionary in entries:
		for key: String in ["name", "age", "cause_label", "day_buried", "grave_id", "quality", "marker_label"]:
			assert_true(e.has(key), "entry has " + key)
		by_grave[e.grave_id] = e
	var cross: Dictionary = by_grave.get("plot_02", {})
	var tables := Database.corpse_tables() as CorpseTables
	assert_eq(cross.name, marked.display_name)
	assert_eq(cross.age, marked.age)
	assert_eq(cross.cause_label, str(tables.get_cause(marked.cause_id).label))
	assert_eq(cross.day_buried, 2)
	assert_eq(cross.quality, graveyard.get_grave("plot_02").quality)
	assert_eq(cross.marker_label, (Database.item(&"wooden_cross") as ItemData).display_name)
	var open: Dictionary = by_grave.get("plot_05", {})
	assert_eq(open.quality, 0, "no marker yet: no quality")
	assert_eq(open.marker_label, "")
	# The register panel accepts the context as it is.
	var ui := world.get_node("UI") as UIRoot
	ui.open_panel(&"grave_register", ctx)
	var page := ui.get_panel(&"grave_register") as GraveRegisterPanel
	assert_eq(page.shown_entries().size(), 2)
	ui.close_all()


func test_stove_is_a_flavour_warm_light() -> void:
	var stove := interior.get_node("Entities/stove") as Stove
	var fire := stove.fire_light()
	var cfg := interior.config
	assert_not_null(fire)
	assert_true(fire.is_in_group(&"warm_lights"))
	assert_true(fire.light_color.is_equal_approx(cfg.stove_color))
	assert_almost(fire.omni_range, cfg.stove_range, 0.001)
	assert_almost(float(fire.get_meta("base_energy")), cfg.stove_night_energy, 0.001)
	assert_true(bool(fire.get_meta("casts_shadow", fire.shadow_enabled)), "authored with shadow")
	TimeManager.load_state({"day": 1, "minute_of_day": NOON})
	await wait_frames(3)
	assert_almost(fire.light_energy, cfg.stove_day_energy, cfg.stove_day_energy * cfg.stove_flicker + 0.01, "by day ~1.6")
	assert_true(fire.visible)
	TimeManager.load_state({"day": 1, "minute_of_day": NIGHT})
	await wait_frames(3)
	assert_almost(fire.light_energy, cfg.stove_night_energy, cfg.stove_night_energy * cfg.stove_flicker + 0.01, "at night ~3.0")
	assert_true(fire.shadow_enabled, "fire shadow at night")
	stove.interact(player)
	assert_eq(stove.get_interaction_prompt(player), "[E] Am Ofen wärmen")


func test_interior_lights_follow_the_clock() -> void:
	var lighting := interior.get_node("Lighting") as InteriorLighting
	var cfg := interior.config
	assert_eq(lighting.lights(&"window").size(), 2)
	assert_eq(lighting.lights(&"lantern").size(), 1)
	assert_eq(lighting.lights(&"candle").size(), 3, "desk, table, window sill")
	TimeManager.load_state({"day": 1, "minute_of_day": NIGHT})
	await wait_frames(2)
	assert_almost(lighting.daylight, 0.0, 0.001)
	for w: Light3D in lighting.lights(&"window"):
		assert_almost(w.light_energy, cfg.window_night_energy, 0.001)
		assert_true(w.light_color.is_equal_approx(cfg.window_night_color))
		assert_false(w.shadow_enabled)
	var lantern := lighting.lights(&"lantern")[0] as Light3D
	assert_true(lantern.shadow_enabled, "lantern shadow at night")
	assert_almost(float(lantern.get_meta("base_energy")), cfg.lantern_night_energy, 0.001)
	for c: Light3D in lighting.lights(&"candle"):
		assert_true(c.visible)
		assert_almost(float(c.get_meta("base_energy")), cfg.candle_night_energy, 0.001)
	assert_true(interior.environment.ambient_light_color.is_equal_approx(cfg.ambient_night_color))
	assert_almost(interior.sun.light_energy, cfg.sun_night_energy, 0.001)
	TimeManager.load_state({"day": 1, "minute_of_day": NOON})
	await wait_frames(2)
	assert_almost(lighting.daylight, 1.0, 0.001)
	for w: Light3D in lighting.lights(&"window"):
		assert_almost(w.light_energy, cfg.window_day_energy, 0.001)
		assert_true(w.light_color.is_equal_approx(cfg.window_day_color))
	assert_false(lantern.shadow_enabled, "no lantern shadow by day")
	assert_almost(float(lantern.get_meta("base_energy")), cfg.lantern_day_energy, 0.001)
	for c: Light3D in lighting.lights(&"candle"):
		assert_false(c.visible, "candles out by day")
	assert_true(interior.environment.ambient_light_color.is_equal_approx(cfg.ambient_day_color))
	assert_almost(interior.environment.ambient_light_energy, cfg.ambient_day_energy, 0.001)
	assert_almost(interior.sun.light_energy, cfg.sun_day_energy, 0.001, "soft sun 0.9")


func test_bed_in_the_hut_sleeps() -> void:
	var bed := interior.get_node("Entities/bed") as Bed
	TimeManager.set_time(1, 19 * 60)
	assert_eq(bed.get_interaction_prompt(player), "[E] Schlafen bis 06:00")
	HutPortal.arrive(player, interior.spawn_transform(), true)
	bed.interact(player)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(panels.back()[0], &"day_summary")
	assert_true(SaveManager.has_save(0), "autosave inside the hut")
	var err: Error = await SaveManager.load_game(0)
	assert_eq(err, OK)
	_bind_world()
	assert_true(player.in_interior, "wakes up inside")


# --- helpers --------------------------------------------------------------------------------

func _bind_world() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	interior = world.get_node_or_null("HutInterior") as HutInterior
	rig = world.get_node("CameraRig") as CameraRig


func _assert_inside_view() -> void:
	assert_true(interior.active, "interior view active")
	assert_not_null(rig.profile, "interior camera profile")
	if rig.profile == null:
		return
	assert_eq(rig.camera.environment, interior.environment, "own environment")
	assert_true(rig.bounds_enabled)
	assert_eq(rig.bounds_min, Vector2(interior.global_position.x, interior.global_position.z) + interior.bounds_min)
	assert_true(interior.sun.visible, "interior sun")
	assert_false((world.get_node("Sun") as Light3D).visible, "outdoor sun hidden")
	assert_true(rig.camera.global_position.distance_to(player.global_position) < 15.0, "camera at the hut")


func get_tree_paused() -> bool:
	return tree.paused


func _on_panel(panel: StringName, context: Dictionary) -> void:
	panels.append([panel, context])


func _on_fade(duration: float) -> void:
	fades.append(duration)
