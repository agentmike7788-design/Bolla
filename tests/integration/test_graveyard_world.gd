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
	assert_eq(hut_lights.size(), 2, "hut lantern + window")
	var shadowed := 0
	for l: Node in world.find_children("Light_*", "OmniLight3D", true, false):
		assert_true(l.is_in_group(&"warm_lights") and l.has_meta("base_energy"), "light grouped: " + l.name)
		if bool(l.get_meta("casts_shadow", (l as Light3D).shadow_enabled)):
			shadowed += 1
	assert_true(shadowed <= 4, "shadowed lights within budget (%d)" % shadowed)
	var rig := world.get_node("CameraRig") as CameraRig
	assert_true(rig.bounds_enabled)
	assert_eq(rig.target, world.get_player())
	assert_almost(rig.fov_deg, 30.0, 0.001)
	assert_almost(rig.pitch_deg, 45.0, 0.001)


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
