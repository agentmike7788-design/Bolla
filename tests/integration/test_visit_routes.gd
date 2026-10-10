extends TestCase
## W-Welt (docs/PHASE8_DESIGN.md §4.2, §4.3, §4.5, §4.8 point 6, §10 test_visit_routes): the visitor spots
## gv_<plot> of every grave and old grave, the baked visitor routes (road_end → road_mid → gate_outside →
## gate_inside → vw_* → gv_<plot>), the Lichtgang and hut-corner routes and the walking net behind
## WorldRoot.route_between (Jakob between his places, the robber from the fence to the fresh graves).
## Every leg from the gate on is free: a sphere (r 0.25 m) swept at knee (0.3 m) and hip height (0.9 m) over
## the real colliders with every section open, every obstacle cleared, all buildings on level 3 and every grave
## with its mound and marker – no figure walks through a grave, a fence or a wall.

const TIMEOUT := 120.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
const LAYOUT := "res://data/world/graveyard_layout.json"
const ROUTE_IN: PackedStringArray = ["road_end", "road_mid", "gate_outside", "gate_inside"]
const SWEEP_RADIUS := 0.25
const HEIGHTS: Array[float] = [0.3, 0.9]
const LIGHTS: PackedStringArray = ["lights_lenz", "lights_crowd_1", "lights_crowd_2", "lights_crowd_3", "lights_crowd_4",
		"lights_crowd_5", "lights_crowd_6", "lights_crowd_7", "lights_crowd_8"]
const CORNER: PackedStringArray = ["apprentice_board", "apprentice_box", "apprentice_lunch", "apprentice_sweep", "rain_barrel"]
const ROW3: PackedStringArray = ["l_09", "l_10", "l_11", "l_12"]

var layout: Dictionary
var world: WorldRoot


func before_each() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame


func after_each() -> void:
	for f: StringName in [&"has_elder_key", &"bruch_license", &"buildings_open", &"linden_granted", &"linden_consecrated",
			&"linden_row3_granted"]:
		GameState.set_flag(f, false)


func _grave_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for g: Dictionary in layout.plots + layout.old_graves:
		out.append(String(g.id))
	return out


func test_every_grave_has_a_spot_and_a_route() -> void:
	var ids := _grave_ids()
	assert_eq(ids.size(), 38, "plot_01…12, h_01…06, l_01…12, old_01…08 (§4.2)")
	for id: String in ids:
		var marker := world.get_node_or_null("Waypoints/gv_" + id) as Marker3D
		assert_not_null(marker, "gv_" + id)
		if marker == null:
			continue
		assert_true(marker.has_meta(&"facing"), "gv_%s looks at the stone" % id)
		var spot: Array = layout.visitor_spots["gv_" + id]
		assert_true(Vector2(marker.position.x, marker.position.z).distance_to(Vector2(spot[0], spot[1])) < 0.01, "layout = scene: " + id)
		var route := world.visitor_route(id)
		assert_eq(route.slice(0, 4), ROUTE_IN, "%s: up the coach road and through the gate" % id)
		assert_eq(route[route.size() - 1], "gv_" + id, id + " ends at its spot")
		assert_eq(PackedStringArray(layout.visitor_routes[id]), route, "layout = scene: route " + id)
		for wp: String in route:
			assert_true(ScheduleBuilder.has_point(world, wp), "%s: waypoint %s exists" % [id, wp])
		# Facing the stone: the spot lies at the foot end (or beside the mound) and looks towards the head.
		var plot := world.get_node_by_layout_id(id) as Node3D
		var stone := plot.to_global(Vector3(0, 0, -1.02))
		var look := Vector2(sin(marker.rotation.y), cos(marker.rotation.y))
		var to_stone := Vector2(stone.x - marker.global_position.x, stone.z - marker.global_position.z).normalized()
		assert_true(look.dot(to_stone) > 0.95, id + " faces its stone")
	# §4.2: the foot end towards the camera – rows 1/2 0.9 m before the mound; row 3 at the south fence beside it.
	for id: String in ["plot_05", "l_01", "old_04"]:
		var p := world.get_node_by_layout_id(id) as Node3D
		var local := p.to_local(world.get_waypoint(StringName("gv_" + id)))
		assert_true(absf(local.x) < 0.75 and local.z > 1.5, "%s: the spot before the foot end (%s)" % [id, local])
	for id: String in ROW3:
		var p := world.get_node_by_layout_id(id) as Node3D
		var local := p.to_local(world.get_waypoint(StringName("gv_" + id)))
		assert_true(absf(local.x) > 0.9 and local.z < 1.0, "%s: beside the mound, the south fence is too close (%s)" % [id, local])


func test_every_visitor_route_is_free() -> void:
	await _open_everything()
	var failures := PackedStringArray()
	for id: String in _grave_ids():
		_check_route(world.visitor_route(id), id, failures)
	assert_eq(failures, PackedStringArray(), "§4.8 (6): every visitor route free from the gate on")


func test_lights_corner_and_night_routes_are_free() -> void:
	await _open_everything()
	var failures := PackedStringArray()
	for id: String in LIGHTS + CORNER + PackedStringArray(["robber_fence_in", "linden_spot"]):
		var route := world.visitor_route(id)
		assert_false(route.is_empty(), "baked route to " + id)
		_check_route(route, id, failures)
	# Jakob at the hut: door ↔ board ↔ barrel ↔ box, and out into the yards.
	for pair: Array in [["apprentice_sweep", "apprentice_board"], ["apprentice_board", "rain_barrel"], ["rain_barrel", "apprentice_box"],
			["apprentice_box", "apprentice_lunch"], ["rain_barrel", "gv_old_08"], ["apprentice_board", "gv_l_06"],
			["apprentice_board", "gv_plot_11"], ["rain_barrel", "gv_h_03"], ["gv_l_10", "linden_spot"], ["gv_l_12", "gv_plot_08"]]:
		_check_route(world.route_between(pair[0], pair[1]), "%s → %s" % pair, failures, true)
	# The robber: from inside the south fence to every grave of rows 2–3 and back.
	for id: String in ["l_05", "l_06", "l_07", "l_08"] + Array(ROW3):
		_check_route(world.route_between("robber_fence_in", "gv_" + id), "robber → " + id, failures, true)
	# Arbitrary points (Jakob's care spots as "@x,y,z" literals) are joined to the net as well.
	for d: Dictionary in layout.dirt_spots:
		var at := Vector2(float(d.pos[0]), float(d.pos[1]))
		# W3 (QA8-11): ApprenticePlanner.spot_stand – also dirt_y01 (south fence) and dirt_h03 (0.15 m beyond the
		# Holunderwinkel fence) get a free side now.
		var stand := ApprenticePlanner.spot_stand(Vector3(at.x, 0.0, at.y), tree)
		stand.y = world.ground_height(Vector2(stand.x, stand.z))
		assert_true(world.nav.clearance_at(Vector2(stand.x, stand.z)) >= ApprenticePlanner.STAND_CLEARANCE,
				"QA8-11: %s – Jakob stands free (%s)" % [d.id, stand])
		var lit := ScheduleBuilder.point_id(stand)
		_check_route(world.route_between("apprentice_board", lit), "board → " + String(d.id), failures, true)
	assert_eq(failures, PackedStringArray(), "§4.8 (6): Lichtgang, hut corner, robber and care-spot ways free")


func test_spots_are_not_in_a_collision() -> void:
	await _open_everything()
	var space := world.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.28
	shape.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	q.exclude = _excluded()
	var failures := PackedStringArray()
	var ids := PackedStringArray()
	for id: String in _grave_ids():
		ids.append("gv_" + id)
	# apprentice_lunch is the seat on the bench.
	for id: String in ids + LIGHTS + PackedStringArray(["apprentice_board", "apprentice_box", "apprentice_sweep", "rain_barrel", "gate_inside", "veit_gate", "peddler_gate", "lights_gate",
			"robber_fence_in"]):
		var p := world.get_waypoint(StringName(id))
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.75, 0))
		var hits := space.intersect_shape(q, 4)
		if not hits.is_empty():
			failures.append("%s in %s" % [id, world.get_path_to(hits[0].collider)])
	assert_eq(failures, PackedStringArray(), "§4.8 (6): no place in a collision")


func test_route_between_falls_back_and_caches() -> void:
	# A free straight leg stays two points; the answer is cached (no work on the next call).
	assert_eq(world.route_between("gate_inside", "gate_outside"), PackedStringArray(["gate_inside", "gate_outside"]))
	var a := world.route_between("gate_inside", "gv_l_07")
	assert_true(a.size() > 2, "around the fences to the Lindenacker (%s)" % [a])
	assert_eq(world.route_between("gate_inside", "gv_l_07"), a, "cached")
	assert_true(world._route_cache.has("gate_inside|gv_l_07"))
	assert_eq(world.visitor_route("nothing_here"), PackedStringArray(), "unknown target")


# --- helpers ------------------------------------------------------------------------------------

func _open_everything() -> void:
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	for f: StringName in [&"has_elder_key", &"bruch_license", &"buildings_open", &"linden_granted", &"linden_consecrated",
			&"linden_row3_granted"]:
		GameState.set_flag(f, true)
	for s: StringName in [&"east", &"north", &"elder", &"bruch", &"quarry", &"churchyard", &"linden", &"linden_row3"]:
		expansion.unlock(s)
	var buildings := world.get_node("Systems/Buildings") as Buildings
	buildings.load_state({"levels": {"crypt": 3, "chapel": 3, "shed": 3}})
	buildings.apply_levels()
	# Every grave as a filled, marked one: mound and marker shapes on (the pits stay off).
	for n: Node in world.find_children("*", "CollisionShape3D", true, false):
		var role := String(n.get_meta(&"role", ""))
		if role == "mound" or role.begins_with("marker:"):
			(n as CollisionShape3D).disabled = false
	for i: int in 4:
		await tree.physics_frame


func _excluded() -> Array[RID]:
	var out: Array[RID] = [world.get_player().get_rid(), (world.get_node("GroundCollision") as CollisionObject3D).get_rid(),
			(world.get_node("Colliders/apprentice_bench") as CollisionObject3D).get_rid()]  # the seat at the lunch place
	for n: Node in tree.get_nodes_in_group(&"npc"):
		var body := n.get_node_or_null(^"Body") as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out


## Sweeps every leg of `route` from gate_inside on (or all legs with `all`); a leg ending at a visitor spot may
## come as close as the spot itself allows.
func _check_route(route: PackedStringArray, label: String, failures: PackedStringArray, all := false) -> void:
	var from := 0 if all else maxi(0, route.find("gate_inside"))
	for k: int in range(from + 1, route.size()):
		var a := ScheduleBuilder.point(world, route[k - 1])
		var b := ScheduleBuilder.point(world, route[k])
		if route[k].begins_with("@") and a.distance_to(b) > 0.5:
			b = b + (a - b).normalized() * 0.35  # a care spot at a fence: §4.8 tolerance at the place itself
		if route[k] == "apprentice_lunch":
			continue  # the seat on the bench under the eaves
		var why := _sweep_block(a, b, 0.15 if route[k].begins_with("@") else SWEEP_RADIUS)
		if why != "":
			failures.append("%s: %s → %s hits %s" % [label, route[k - 1], route[k], why])


## (The last leg to a care stand at a fence is swept slimmer: Jakob turns his shoulder to the pales.)
func _sweep_block(a: Vector3, b: Vector3, radius: float = SWEEP_RADIUS) -> String:
	var space := world.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.collision_mask = 1
	q.exclude = _excluded()
	for h: float in HEIGHTS:
		var start := Vector3(a.x, world.ground_height(Vector2(a.x, a.z)) + h, a.z)
		var end := Vector3(b.x, world.ground_height(Vector2(b.x, b.z)) + h, b.z)
		q.transform = Transform3D(Basis.IDENTITY, start)
		q.motion = end - start
		var frac := space.cast_motion(q)
		if frac.size() == 2 and frac[0] < 1.0:
			var hit_at := start + (end - start) * frac[1]
			q.transform = Transform3D(Basis.IDENTITY, hit_at)
			q.motion = Vector3.ZERO
			var hits := space.intersect_shape(q, 1)
			return "%s at %.1f m (h %.1f)" % [world.get_path_to(hits[0].collider) if not hits.is_empty() else "?", (end - start).length() * frac[1], h]
	return ""
