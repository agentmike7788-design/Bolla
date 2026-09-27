extends TestCase
## W1: the generated world graveyard.tscn (§4) – contract nodes, every layout id, waypoints,
## colliders, unique save ids, the carter walking data/npc/carter_schedule.tres, the
## time-driven atmosphere, flat ground under plots and the player's belt lantern.

const TIMEOUT := 60.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
const LAYOUT := "res://data/world/graveyard_layout.json"
const ENTITY_CLASSES := {
	"morgue_table": "MorgueTable", "workbench": "Workbench", "dropoff": "Dropoff",
	"resource_node": "ResourceNode", "hut_door": "HutDoor", "npc": "Npc",
}
## Height tolerance (m): flat ground under plots and stations (pit floor 3-4 cm above ground).
const FLAT_TOLERANCE := 0.01
const FOLIAGE_SHADER := "res://assets/shaders/painted_foliage.gdshader"
const FOLIAGE_MATERIAL := "res://assets/materials/mat_foliage.tres"
## Physics layer of the temporary foliage collision copies (UI-01 line-of-sight check).
const FOLIAGE_PROBE_LAYER := 1 << 19

var layout: Dictionary
var world: WorldRoot


func before_each() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame


func test_contract_nodes() -> void:
	assert_not_null(world, "root is a WorldRoot")
	for path: String in ["WorldEnvironment", "Sun", "Atmosphere", "Ground", "GroundCollision", "Colliders",
			"Systems/CorpseManager", "Systems/Graveyard", "Entities", "Decor", "Waypoints", "Corpses",
			"Player", "CameraRig", "CameraRig/Camera3D", "UI"]:
		assert_true(world.has_node(path), "node '%s'" % path)
	assert_true(world.is_world_ready, "world_ready announced")
	assert_eq(world.corpse_manager, world.get_node("Systems/CorpseManager"))
	assert_eq(world.graveyard, world.get_node("Systems/Graveyard"))
	assert_eq(world.get_player(), world.get_node("Player"))
	assert_eq(world.get_node("UI").scene_file_path, "res://src/ui/ui_root.tscn")
	assert_eq(world.get_node("Player").scene_file_path, "res://src/entities/player/player.tscn")
	assert_eq(world.corpse_manager.corpse_scene.resource_path, "res://src/entities/corpse/corpse.tscn")
	assert_eq(world.corpse_manager.get_node(world.corpse_manager.container_path), world.get_node("Corpses"))
	var start := _v2(layout.player_start.pos)
	assert_almost(world.get_player().global_position.x, start.x, 0.01)
	assert_almost(world.get_player().global_position.z, start.y, 0.01)


func test_world_ready_is_emitted_deferred() -> void:
	tree.root.remove_child(world)  # one world at a time (plot ids are global)
	world.free()
	var fresh := (load(WORLD) as PackedScene).instantiate() as WorldRoot
	var got: Array = []
	var on_ready := func(w: Node) -> void: got.append(w)
	EventBus.world_ready.connect(on_ready)
	tree.root.add_child(fresh)
	assert_false(fresh.is_world_ready, "not during _ready")
	assert_true(got.is_empty())
	await tree.process_frame
	EventBus.world_ready.disconnect(on_ready)
	assert_eq(got, [fresh])
	assert_true(fresh.is_world_ready)


func test_every_layout_id_exists() -> void:
	for p: Dictionary in layout.plots:
		var plot := world.get_node_by_layout_id(p.id) as GravePlot
		assert_not_null(plot, p.id)
		assert_eq(plot.get_parent().name, "Entities")
		assert_eq(plot.grave_id, p.id)
		assert_false(plot.is_old)
		_assert_at(plot, _v2(p.pos), p.id)
		assert_eq(world.graveyard.get_grave(p.id).state, GraveRecord.State.EMPTY)
	assert_eq(layout.plots.size(), 6, "plot_01..plot_06")
	for g: Dictionary in layout.old_graves:
		var old := world.get_node_by_layout_id(g.id) as GravePlot
		assert_not_null(old, g.id)
		assert_true(old.is_old)
		assert_eq(old.get_parent().get_path(), world.get_node("Decor/OldGraves").get_path())
		assert_eq([old.old_stone, old.old_mound], [g.stone, g.mound])
		assert_eq(world.graveyard.get_grave(g.id).state, GraveRecord.State.OLD)
	for e: Dictionary in layout.entities:
		var node := world.get_node_by_layout_id(e.id)
		assert_not_null(node, e.id)
		assert_eq(node.get_parent().name, "Entities")
		assert_true(node.get_script() != null and node.get_script().get_global_name() == ENTITY_CLASSES[e.type],
				"%s is a %s" % [e.id, ENTITY_CLASSES[e.type]])
		if e.type != "npc":
			_assert_at(node as Node3D, _v2(e.pos), e.id)
	for id: String in ["plot_01", "plot_06", "old_01", "res_wood", "res_stone", "npc_carter", "morgue_table",
			"workbench", "dropoff", "hut_door"]:
		assert_not_null(world.get_node_by_layout_id(id), id)
	assert_null(world.get_node_by_layout_id("no_such_id"))
	var wood := world.get_node_by_layout_id("res_wood") as ResourceNode
	assert_eq([wood.item_id, wood.daily_amount], [&"wood", 6])
	var stone := world.get_node_by_layout_id("res_stone") as ResourceNode
	assert_eq([stone.item_id, stone.daily_amount], [&"stone", 4])
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	assert_eq(npc.npc_id, &"carter")
	assert_eq(npc.get_node("Model").scene_file_path, "res://assets/models/characters/ph_chr_carter.glb")


func test_waypoints() -> void:
	for id: String in ["road_end", "road_mid", "gate_outside", "dropoff", "evening_spot"]:
		assert_true(layout.waypoints.has(id), "layout waypoint " + id)
		assert_true(world.has_node("Waypoints/" + id), "Waypoints/" + id)
		assert_true(world.get_node("Waypoints/" + id) is Marker3D)
		var p := world.get_waypoint(StringName(id))
		var want := _v2(layout.waypoints[id])
		assert_almost(p.x, want.x, 0.001, id)
		assert_almost(p.z, want.y, 0.001, id)
		assert_almost(p.y, world.ground_height(want), 0.02, id + " on the ground")
	# The route of the carter's schedule only uses known waypoints.
	var sched := Database.schedule(&"carter") as NpcSchedule
	for e: ScheduleEntry in sched.entries:
		for id: String in e.path:
			assert_true(world.has_node("Waypoints/" + id), "schedule waypoint " + id)


func test_colliders() -> void:
	var colliders := world.get_node("Colliders")
	for name: String in ["Hut", "Tree", "morgue_table", "workbench", "dropoff", "res_wood", "res_stone",
			"FallenLog", "Signpost", "GatePost_1", "GatePost_2", "Fence_01", "Tree_01", "Bounds"]:
		assert_true(colliders.has_node(name), "collider " + name)
	var bodies := 0
	for body: Node in colliders.get_children():
		assert_true(body is StaticBody3D, body.name)
		assert_eq((body as StaticBody3D).collision_layer, 1, "world layer: " + body.name)
		assert_true(body.get_child_count() > 0 and body.get_child(0) is CollisionShape3D, "shape: " + body.name)
		bodies += 1
	assert_true(bodies > 50, "all placed assets collide (%d)" % bodies)
	for side: String in ["West", "East", "North", "South"]:
		assert_true(colliders.has_node("Bounds/" + side), "bounds wall " + side)
	for p: Dictionary in layout.plots:
		var shapes := world.get_node_by_layout_id(p.id).get_node("Collision").get_children()
		var roles: Array = []
		for s: Node in shapes:
			roles.append(s.get_meta(&"role"))
			assert_true((s as CollisionShape3D).disabled, "empty plot is walkable")
		for role: String in ["pit", "mound", "marker:wooden_cross", "marker:gravestone_simple"]:
			assert_has(roles, role, p.id)
	await tree.process_frame
	var old := world.get_node_by_layout_id("old_01").get_node("Collision")
	for s: Node in old.get_children():
		assert_false((s as CollisionShape3D).disabled, "old graves block")


func test_interactables_have_shapes_and_priorities() -> void:
	var want := {"npc_carter": 30, "plot_01": 10, "morgue_table": 5, "workbench": 5, "res_wood": 5, "hut_door": 5}
	for id: String in want:
		var area := world.get_node_by_layout_id(id).get_node("Interactable") as Interactable
		assert_eq(area.priority, want[id], id)
		assert_true(area.get_child(0) is CollisionShape3D, id)
		assert_eq(area.collision_layer, 8, id)


func test_saveables_have_unique_ids() -> void:
	var ids: Array = []
	for node: Node in tree.get_nodes_in_group(&"saveable"):
		if not world.is_ancestor_of(node):
			continue
		var id := String(node.get("save_id"))
		assert_ne(id, "", "save_id of " + node.name)
		assert_false(id in ids, "duplicate save_id " + id)
		ids.append(id)
	for id: String in ["corpse_manager", "graveyard", "player", "res_wood", "res_stone", "npc_carter"]:
		assert_has(ids, id)
	var state := SaveManager.collect_state()
	assert_eq(JSON.to_native(JSON.from_native(state)), state, "state survives the JSON round trip")


func test_carter_walks_the_schedule() -> void:
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	var road_end := world.get_waypoint(&"road_end")
	# 06:00 at home (hidden, no dialogue, no collision)
	await _at(npc, 360)
	assert_false(npc.visible, "06:00 away")
	assert_false(npc.interactable.enabled)
	assert_true(npc.body_shape.disabled)
	_assert_xz(npc.global_position, road_end, "06:00 at road_end")
	# 07:20 half way along road_end -> road_mid -> gate_outside -> dropoff (by arc length)
	await _at(npc, 440)
	assert_true(npc.visible, "07:20 on the way")
	assert_true(npc.is_walking())
	assert_true(npc.cart.visible, "07:20 with the cart")
	assert_true(npc.cargo.visible, "07:20 brings a corpse")
	assert_false(npc.interactable.enabled, "07:20 no dialogue")
	_assert_xz(npc.global_position, _along(["road_end", "road_mid", "gate_outside", "dropoff"], 0.5), "07:20")
	assert_almost(npc.global_position.y, world.ground_height(Vector2(npc.global_position.x, npc.global_position.z)), 0.001)
	# 08:00 standing at the bier, talkable
	await _at(npc, 480)
	assert_true(npc.visible)
	assert_false(npc.is_walking())
	assert_true(npc.interactable.enabled, "08:00 dialogue")
	assert_false(npc.body_shape.disabled)
	_assert_xz(npc.global_position, world.get_waypoint(&"dropoff"), "08:00 at dropoff")
	assert_eq(npc.get_interaction_prompt(world.get_player()), "[E] Mit Osric reden")
	# 12:00 away
	await _at(npc, 720)
	assert_false(npc.visible, "12:00 away")
	assert_false(npc.interactable.enabled)
	# 19:00 at the evening spot outside the gate, no cart
	await _at(npc, 1140)
	assert_true(npc.visible, "19:00 at the gate")
	assert_false(npc.cart.visible)
	assert_true(npc.interactable.enabled)
	_assert_xz(npc.global_position, world.get_waypoint(&"evening_spot"), "19:00 evening_spot")
	assert_almost(npc.rotation.y, deg_to_rad(float(layout.waypoint_facing.evening_spot)), 0.001, "faces the road")
	assert_true(is_nan(world.get_waypoint_facing(&"dropoff")), "keeps the arrival heading at the bier")
	# 23:00 away
	await _at(npc, 1380)
	assert_false(npc.visible, "23:00 away")
	assert_true(npc.body_shape.disabled)


func test_atmosphere_is_time_driven() -> void:
	var atmo := world.get_node("Atmosphere") as AtmosphereController
	assert_true(atmo.time_driven)
	assert_eq(atmo.blend_minutes, PackedInt32Array(layout.atmosphere.blend_minutes))
	assert_eq(atmo.blend_presets.size(), atmo.blend_minutes.size())
	for i: int in atmo.blend_presets.size():
		assert_eq(atmo.blend_presets[i].resource_path, "res://data/atmosphere/%s.tres" % layout.atmosphere.blend_presets[i])
	var day := load("res://data/atmosphere/day.tres") as AtmospherePreset
	var night := load("res://data/atmosphere/night.tres") as AtmospherePreset
	var sun := world.get_node("Sun") as DirectionalLight3D
	TimeManager.load_state({"day": 1, "minute_of_day": 720})
	await tree.process_frame
	assert_almost(sun.light_energy, day.sun_energy, 0.001, "noon = day preset (hold keyframes)")
	TimeManager.load_state({"day": 1, "minute_of_day": 1380})
	await tree.process_frame
	assert_almost(sun.light_energy, night.sun_energy, 0.001, "23:00 = night")
	var lantern := world.get_player().find_child("Lantern", true, false) as OmniLight3D
	assert_almost(lantern.get_meta("scale", 0.0), night.warm_light_scale, 0.001, "belt lantern scaled by the atmosphere")


func test_warm_light_shadows_follow_the_mood() -> void:
	var hut_lantern := world.get_node("Decor/Hut/Light_lantern") as OmniLight3D
	TimeManager.load_state({"day": 1, "minute_of_day": 720})
	await tree.process_frame
	await tree.process_frame
	assert_false(hut_lantern.shadow_enabled, "by day no lantern shadow maps (budget)")
	TimeManager.load_state({"day": 1, "minute_of_day": 1380})
	await tree.process_frame
	await tree.process_frame
	assert_true(hut_lantern.shadow_enabled, "at night the authored shadow is back")
	var post := world.get_node("Decor/LanternPosts/LanternPost_2/Light_lantern") as OmniLight3D
	assert_false(post.shadow_enabled, "second lantern authored without shadow")


func test_player_belt_lantern() -> void:
	var player := world.get_player()
	var lantern := player.find_child("Lantern", true, false) as OmniLight3D
	assert_not_null(lantern)
	assert_eq(String(lantern.get_parent().name), "light_lantern", "on the rig marker")
	assert_true(lantern.is_in_group(&"warm_lights"))
	var cfg: Dictionary = layout.lights["ph_chr_gravekeeper/light_lantern"]
	assert_almost(float(lantern.get_meta("base_energy")), float(cfg.energy), 0.001)
	assert_true(lantern.light_color.is_equal_approx(Color(cfg.color)))
	assert_almost(lantern.omni_range, float(cfg.range), 0.001)
	assert_eq(lantern.shadow_enabled, bool(cfg.shadow))
	var lights := 0
	for l: Node in player.find_children("*", "OmniLight3D", true, false):
		lights += 1
	assert_eq(lights, 1, "exactly one belt lantern")


func test_ground_is_flat_under_plots_and_stations() -> void:
	for p: Dictionary in layout.plots:
		var plot := world.get_node_by_layout_id(p.id) as GravePlot
		# pit + earth heap footprint, extended to the marker at the head end
		var area := plot.footprint.merge(Rect2(plot.marker_offset.x - 0.3, plot.marker_offset.z - 0.2, 0.6, 0.4))
		var lo := INF
		var hi := -INF
		for i: int in 9:
			for j: int in 9:
				var local := Vector3(lerpf(area.position.x, area.end.x, i / 8.0), 0.0, lerpf(area.position.y, area.end.y, j / 8.0))
				var w := plot.global_transform * local
				var h := world.ground_height(Vector2(w.x, w.z))
				lo = minf(lo, h)
				hi = maxf(hi, h)
		assert_true(hi - lo < FLAT_TOLERANCE, "%s flat (%.4f m)" % [p.id, hi - lo])
		assert_almost(plot.global_position.y, world.ground_height(Vector2(plot.global_position.x, plot.global_position.z)), 0.005, p.id)
	var table := world.get_node_by_layout_id("morgue_table") as Node3D
	var heights: Array[float] = []
	for corner: Vector3 in [Vector3(-1.0, 0, -0.4), Vector3(1.0, 0, -0.4), Vector3(-1.0, 0, 0.4), Vector3(1.0, 0, 0.4)]:
		var w := table.global_transform * corner
		heights.append(world.ground_height(Vector2(w.x, w.z)))
	assert_true(heights.max() - heights.min() < FLAT_TOLERANCE, "table legs on flat ground")


func test_ground_collision_matches_the_painted_ground() -> void:
	var shape := world.get_node("GroundCollision/Shape") as CollisionShape3D
	assert_true(shape.shape is HeightMapShape3D)
	await tree.physics_frame
	await tree.physics_frame
	var space := world.get_world_3d().direct_space_state
	# (off the grid lines: a vertical ray exactly on a heightmap cell edge can slip through)
	for p: Vector2 in [Vector2(4.07, 5.13), Vector2(1.23, 14.08), Vector2(-5.04, -3.11), Vector2(3.61, -8.17)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 3.0, p.y), Vector3(p.x, -3.0, p.y), 1)
		var hit := space.intersect_ray(query)
		assert_false(hit.is_empty(), "ground hit at %s" % p)
		if not hit.is_empty():
			assert_almost((hit.position as Vector3).y, world.ground_height(p), 0.02, "at %s" % p)


func test_decor_and_grass() -> void:
	var decor := world.get_node("Decor")
	for path: String in ["Hut", "Tree", "Trees", "Bushes", "Fence", "Props", "LanternPosts", "Signpost", "FallenLog", "Grass"]:
		assert_true(decor.has_node(path), "Decor/" + path)
	var label := decor.get_node("Signpost").find_child("Label", true, false) as Label3D
	assert_not_null(label, "signpost label")
	assert_eq(label.text, "Hollerbrück")
	var tufts := 0
	for chunk: Node in decor.get_node("Grass").get_children():
		var mmi := chunk as MultiMeshInstance3D
		assert_eq(mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		tufts += mmi.multimesh.instance_count
	assert_true(tufts > 5000, "grass (%d tufts)" % tufts)
	var hut_lights := decor.get_node("Hut").find_children("Light_*", "OmniLight3D", true, false)
	assert_eq(hut_lights.size(), 3, "hut lantern + two windows (§11)")
	var interior := world.get_node("HutInterior")
	var shadowed := 0
	for l: Node in world.find_children("Light_*", "OmniLight3D", true, false):
		assert_true(l.has_meta("base_energy"), "light has a base energy: " + l.name)
		# Interior lights follow InteriorLighting (meta interior_role); the stove fire is warm.
		assert_true(l.is_in_group(&"warm_lights") or (interior.is_ancestor_of(l) and l.has_meta(&"interior_role")),
				"light grouped: " + l.name)
		if bool(l.get_meta("casts_shadow", (l as Light3D).shadow_enabled)):
			shadowed += 1
	assert_true(shadowed <= 4, "shadowed lights within budget (%d)" % shadowed)
	var rig := world.get_node("CameraRig") as CameraRig
	assert_true(rig.bounds_enabled)
	assert_eq(rig.target, world.get_player())
	assert_almost(rig.fov_deg, 30.0, 0.001)
	assert_almost(rig.pitch_deg, 45.0, 0.001)


# --- review fixes (Phase-2 slice, cluster B) --------------------------------------------------

## SL-1: straight after a load at 08:20 (no walk seen) the carter stands as if he had walked
## in – facing the way he came (gate_outside → dropoff), the cart inside the fence.
func test_carter_at_the_bier_after_a_load_faces_his_arrival() -> void:
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	TimeManager.load_state({"day": 1, "minute_of_day": 500})
	npc.load_state({})
	await tree.process_frame
	var dir := _flat(world.get_waypoint(&"dropoff") - world.get_waypoint(&"gate_outside"))
	assert_almost(npc.rotation.y, atan2(dir.x, dir.z), 0.001, "arrival heading")
	var fence_z := float(layout.fence.segments[0][0][1])
	assert_true(npc.cart.global_position.z < fence_z - 0.5, "cart inside the graveyard (z %.2f)" % npc.cart.global_position.z)


## SL-2 / C3: after loading a save made far from the start the camera is on the player at once.
func test_camera_is_on_the_player_right_after_a_load() -> void:
	tree.root.remove_child(world)  # one world at a time (plot ids are global)
	world.free()
	SaveManager.save_dir = "user://test_saves"
	SaveManager.new_game()
	assert_true(await wait_for_signal(EventBus.new_game_started, 20.0), "new game")
	var player := (tree.current_scene as WorldRoot).get_player()
	player.global_position = Vector3(8.8, 0.05, 7.2)
	assert_eq(SaveManager.save_game(97), OK)
	SaveManager.load_game(97)
	assert_true(await wait_for_signal(EventBus.game_loaded, 20.0), "loaded")
	var loaded := tree.current_scene as WorldRoot
	var rig := loaded.get_node("CameraRig") as CameraRig
	var at_load := rig.camera.global_position
	rig.snap()
	assert_true(rig.camera.global_position.distance_to(at_load) < 0.1,
			"no sweep: the camera already frames the player (%.2f m off)" % rig.camera.global_position.distance_to(at_load))
	SaveManager.delete_save(97)


## GP-05: 07:40-10:00 the carter stands west of the bier; a player at the bier's west end facing
## the corpse picks it up instead of talking to him – turning to him still talks.
func test_corpse_on_the_bier_wins_the_focus_over_the_carter() -> void:
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	TimeManager.load_state({"day": 1, "minute_of_day": 490})
	npc.refresh()
	var dropoff := world.get_node_by_layout_id("dropoff") as Dropoff
	var record := world.corpse_manager.spawn_corpse(null, dropoff.slot_transform(), &"dropoff")
	var corpse_area := world.corpse_manager.get_corpse_node(record.id).get_node("Interactable")
	var player := world.get_player()
	var slot := dropoff.slot_transform().origin
	for stand: Vector2 in [Vector2(3.0, 8.3), Vector2(3.1, 7.6)]:
		var at := Vector3(stand.x, world.ground_height(stand), stand.y)
		player.global_position = at
		var to := _flat(slot - at)
		player.rotation.y = atan2(to.x, to.z)
		for i: int in 4:
			await tree.physics_frame
		assert_eq(player.detector.focused, corpse_area, "at %s facing the corpse" % stand)
	var to_npc := _flat(npc.global_position - player.global_position)
	player.rotation.y = atan2(to_npc.x, to_npc.z)
	for i: int in 4:
		await tree.physics_frame
	assert_eq(player.detector.focused, npc.interactable, "facing the carter")


## C4: digging plot_01 between it and the finished plot_02 must not put the player into
## plot_02's mound (the +X exit lies inside it).
func test_dig_exit_next_to_a_finished_grave_is_free() -> void:
	var inv := world.get_player().inventory
	world.graveyard.dig("plot_02")
	var record := world.corpse_manager.spawn_corpse(null, (world.get_node_by_layout_id("plot_02") as Node3D).global_transform, &"ground")
	world.graveyard.bury("plot_02", record.id)
	inv.add_item(&"wooden_cross", 1)
	world.graveyard.place_marker("plot_02", &"wooden_cross", inv)
	for i: int in 3:
		await tree.physics_frame
	var plot := world.get_node_by_layout_id("plot_01") as GravePlot
	var player := world.get_player()
	player.instant_actions = true
	player.global_position = plot.to_global(Vector3(1.0, 0.0, 0.2))
	plot.interact(player)
	assert_eq(world.graveyard.get_grave("plot_01").state, GraveRecord.State.DUG)
	var placed := player.global_position
	for i: int in 20:
		await tree.physics_frame
	assert_true(_flat(player.global_position - placed).length() < 0.05, "not shoved (moved %.2f m)" % _flat(player.global_position - placed).length())
	assert_true(player.global_position.y - placed.y < 0.05, "not popped onto the mound (+%.2f m)" % (player.global_position.y - placed.y))


## PERF-01: only foliage and grass may use TIME (an animated material makes every shadow map
## in its range redraw each frame); the foliage is kept out of the lantern shadows.
func test_only_foliage_and_grass_materials_are_animated() -> void:
	for file: String in ResourceLoader.list_directory("res://assets/materials/"):
		if not file.ends_with(".tres"):
			continue
		var mat := load("res://assets/materials/" + file) as ShaderMaterial
		if mat == null:
			continue
		var animated := _shader_source(mat.shader.resource_path).contains("TIME")
		assert_eq(animated, file in ["mat_foliage.tres", "mat_grass.tres"], "%s uses TIME: %s" % [file, animated])
	assert_eq((load(FOLIAGE_MATERIAL) as ShaderMaterial).shader.resource_path, FOLIAGE_SHADER)
	var foliage_layer := 1 << 1
	var oak := world.get_node("Decor/Tree").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(oak.layers, foliage_layer, "tree (crown) on the foliage render layer")
	var bush := world.get_node("Decor/Bushes").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(bush.layers, foliage_layer, "bush on the foliage render layer")
	var hut := world.get_node("Decor/Hut").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert_eq(hut.layers, 1, "no foliage: default layer")
	for path: String in ["Decor/Hut/Light_lantern", "Decor/LanternPosts/LanternPost_1/Light_lantern"]:
		var lantern := world.get_node(path) as OmniLight3D
		assert_eq(lantern.shadow_caster_mask & foliage_layer, 0, path + " casts no foliage shadows")
		assert_ne(lantern.shadow_caster_mask & 1, 0, path + " still casts the rest")
	assert_ne((world.get_node("Sun") as DirectionalLight3D).shadow_caster_mask & foliage_layer, 0, "the sun keeps tree shadows")


## PERF-03: one sun cascade over the whole shadow distance – the nearest visible depth
## (~10 m at zoom_min) never reached the first of two splits, which wasted half the atlas.
func test_sun_shadow_uses_the_whole_atlas() -> void:
	var sun := world.get_node("Sun") as DirectionalLight3D
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_almost(sun.directional_shadow_max_distance, 55.0, 0.001, "same reach as approved")


# --- foliage occlusion cutout (UI-01) ---------------------------------------------------------

## From the gameplay camera (zoom min / default / max) the gravekeeper stays visible at every
## interaction spot: each foliage surface the camera looks through on its way to his body lies
## in the fully cut part of the cutout (reviewer's segment-vs-mesh check + the cutout geometry).
func test_foliage_never_hides_the_player_at_interaction_spots() -> void:
	var code := _shader_source(FOLIAGE_SHADER)
	assert_true(code.contains("global uniform vec3 occlusion_target"), "the foliage shader has the cutout")
	if not code.contains("global uniform vec3 occlusion_target"):
		return
	var cut := {"radius": float((ProjectSettings.get_setting("shader_globals/occlusion_radius") as Dictionary).value),
			"softness": _uniform_default(code, "occlusion_softness"), "rise": _uniform_default(code, "occlusion_rise")}
	# Chest height the player publishes as the cutout target (Player.occlusion_point()).
	var chest := float(world.get_player().get(&"occlusion_height"))
	var normals := _build_foliage_collision()
	await tree.physics_frame
	await tree.physics_frame
	var rig := world.get_node("CameraRig") as CameraRig
	var anchor := Node3D.new()
	world.add_child(anchor)
	rig.target = anchor
	var hidden: PackedStringArray = []
	var checked := 0
	var door_leaves := 0
	var spots := _interaction_spots()
	for spot_name: String in spots:
		for spot: Vector3 in _standing_spots(spots[spot_name]):
			for zoom: float in [rig.zoom_min, 22.0, rig.zoom_max]:
				anchor.global_position = spot
				rig.set_distance(zoom)
				rig.snap()
				var eye := rig.camera.global_position
				var target := spot + Vector3(0.0, chest, 0.0)
				for body: Vector3 in [Vector3(0, 0.3, 0), Vector3(0, 1.1, 0), Vector3(0, 1.75, 0), Vector3(0.3, 1.1, 0), Vector3(-0.3, 1.1, 0)]:
					checked += 1
					for hit: Vector3 in _front_hits(normals, eye, spot + body):
						if spot_name == "hut_door":
							door_leaves += 1
						var c := _occlusion_cut(hit, eye, target, cut)
						if c < 0.999:
							hidden.append("%s %s zoom %d body %s: leaf %s cut %.2f" % [spot_name, spot, zoom, body, hit, c])
	assert_true(checked > 500, "checked %d lines of sight" % checked)
	assert_true(door_leaves > 20, "the oak crown lies in front of the hut door (%d leaf hits)" % door_leaves)
	assert_true(hidden.is_empty(), "%d hidden:\n%s" % [hidden.size(), "\n".join(hidden.slice(0, 12))])


## Interaction spots (world XZ of the entity / waypoint) the player stands at.
func _interaction_spots() -> Dictionary:
	var out := {}
	for id: String in ["plot_01", "plot_02", "plot_03", "plot_04", "plot_05", "plot_06", "morgue_table", "workbench",
			"res_wood", "res_stone", "hut_door", "dropoff"]:
		out[id] = (world.get_node_by_layout_id(id) as Node3D).global_position
	for id: StringName in [&"dropoff", &"evening_spot"]:
		out["waypoint_" + String(id)] = world.get_waypoint(id)
	out["player_start"] = world.get_player().global_position
	return out


## The spot and 8 points 1.2 m around it where the player's capsule fits (no world body).
func _standing_spots(centre: Vector3) -> Array[Vector3]:
	var capsule := world.get_player().get_node("Collision") as CollisionShape3D
	var space := world.get_world_3d().direct_space_state
	var out: Array[Vector3] = []
	for k: int in 9:
		var p := centre if k == 0 else centre + Vector3(1.2, 0, 0).rotated(Vector3.UP, TAU * k / 8.0)
		p.y = world.ground_height(Vector2(p.x, p.z))
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule.shape
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.1, 0)) * capsule.transform
		if space.intersect_shape(query, 1).is_empty():
			out.append(p)
	return out


## Collision copies (layer 20) of every foliage surface in Decor. Returns the outward normal
## (from the vertex normals, world space) of each face by face index.
func _build_foliage_collision() -> PackedVector3Array:
	var faces := PackedVector3Array()
	var normals := PackedVector3Array()
	for node: Node in world.get_node("Decor").find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s: int in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null or mat.resource_path != FOLIAGE_MATERIAL:
				continue
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vnormals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var xf := mi.global_transform
			for i: int in range(0, index.size(), 3):
				var n := Vector3.ZERO
				for j: int in 3:
					faces.append(xf * verts[index[i + j]])
					n += vnormals[index[i + j]]
				normals.append((xf.basis * n).normalized())
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "FoliageProbe"
	body.collision_layer = FOLIAGE_PROBE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = concave
	body.add_child(shape)
	world.add_child(body)
	return normals


## Foliage faces the line of sight eye → point enters from their front (rendered) side.
func _front_hits(normals: PackedVector3Array, eye: Vector3, point: Vector3) -> Array[Vector3]:
	var space := world.get_world_3d().direct_space_state
	var dir := (point - eye).normalized()
	var out: Array[Vector3] = []
	var from := eye
	for guard: int in 64:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, FOLIAGE_PROBE_LAYER))
		if hit.is_empty():
			break
		var face := int(hit.face_index)
		if face < 0 or normals[face].dot(dir) < 0.0:
			out.append(hit.position)
		from = (hit.position as Vector3) + dir * 0.005
	return out


## GDScript mirror of occlusion_cut() in painted_foliage.gdshader (0 = kept … 1 = fully cut).
func _occlusion_cut(p: Vector3, eye: Vector3, target: Vector3, cut: Dictionary) -> float:
	var axis := target - eye
	var t := (p - eye).dot(axis) / axis.length_squared()
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var radius := float(cut.radius) * t
	var d := p.distance_to(eye + axis * t)
	var radial := 1.0 - smoothstep(radius * (1.0 - float(cut.softness)), radius, d)
	return radial * smoothstep(target.y, target.y + float(cut.rise), p.y)


## Shader code with its #include files inlined and // comments removed.
func _shader_source(path: String) -> String:
	var out: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("#include"):
			out.append(_shader_source(line.get_slice("\"", 1)))
		else:
			out.append(line.get_slice("//", 0))
	return "\n".join(out)


func _uniform_default(code: String, uniform_name: String) -> float:
	var re := RegEx.create_from_string("uniform\\s+float\\s+%s\\s*=\\s*([0-9.]+)" % uniform_name)
	var m := re.search(code)
	assert_not_null(m, "uniform %s has a default" % uniform_name)
	return m.get_string(1).to_float() if m != null else 0.0


# --- helpers ----------------------------------------------------------------------------------

func _at(npc: Npc, minute: int) -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": minute})
	npc.refresh()
	await tree.process_frame
	await tree.process_frame


## Point at fraction t of the arc length along the waypoint polyline (XZ).
func _along(ids: Array, t: float) -> Vector3:
	var pts: Array[Vector3] = []
	for id: String in ids:
		pts.append(world.get_waypoint(StringName(id)))
	var total := 0.0
	for k: int in range(1, pts.size()):
		total += _flat(pts[k] - pts[k - 1]).length()
	var s := t * total
	for k: int in range(1, pts.size()):
		var seg := _flat(pts[k] - pts[k - 1]).length()
		if s <= seg:
			return pts[k - 1].lerp(pts[k], s / seg)
		s -= seg
	return pts.back()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _assert_xz(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost(actual.x, expected.x, 0.01, message + " x")
	assert_almost(actual.z, expected.z, 0.01, message + " z")


func _assert_at(node: Node3D, pos: Vector2, message: String) -> void:
	assert_almost(node.global_position.x, pos.x, 0.001, message)
	assert_almost(node.global_position.z, pos.y, 0.001, message)


func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
