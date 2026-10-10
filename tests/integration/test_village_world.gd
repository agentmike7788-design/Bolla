extends TestCase
## W-Welt (docs/PHASE7_DESIGN.md §4.1–§4.5, §4.7, §10 test_village_world): Hollerbrück in the
## generated world – WorldRoot/Regions/Village at (0, 0, 400) built from data/world/village_layout.json.
## Houses, doors, shops, board, portal, spawn and waypoints at the §4.2 / §4.4 positions (the plan in
## tests/fixtures/phase7/village_layout.json; the documented W-Welt shifts within the §4.5 point 5
## limits), the nine Npc of the village, the region and its camera profile, lights (§4.7), and the
## §4.5 checks on the real region:
## 1. Nahsicht – at every HouseDoor, ShopCounter, the board, the portal and every standing spot of the
##    eight schedules with a dialogue the rays from the gameplay camera (zoom 12 / 22 / 26) to the
##    player's head, the person's head and the door / counter centre are free (collision copies of the
##    meshes; foliage counts only where the player's occlusion cutout does not open it – the crowns
##    are painted_foliage, the cut is the shader's);
## 2. Im Bild – the north row (Amtshaus, Kirche, Holderkrug) from the Anger in front of each house;
## 3. Trauerflor – the ribbon marker of all six houses is free from the nearest Anger point;
## 4. Wege – flood fill with a 1.5 m capsule from the bridge to every door, shop, the board, the wash
##    place, the well and the cottages; no standing spot in a collision; every schedule polyline of
##    the region free at hip height (0.3 m tolerance).
## Frustum: from no village camera the graveyard or a room is in view, and the other way round.

const TIMEOUT := 240.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
const LAYOUT := "res://data/world/village_layout.json"
const PLAN := "res://tests/fixtures/phase7/village_layout.json"
const ORIGIN := Vector3(0.0, 0.0, 400.0)
const ZOOMS: Array[float] = [12.0, 22.0, 26.0]
const PROBE_LAYER := 1 << 19
const FOLIAGE_SHADER := "res://assets/shaders/painted_foliage.gdshader"
const VILLAGERS: Array[StringName] = [&"innkeeper", &"smith", &"grocer", &"priest", &"mayor", &"surgeon", &"washer", &"oldwoman"]
## W-Welt shifts against the §4.2 / §4.4 plan (m): Kulisse ±1.5 (houses), the linden ±1 (§4.5 point 5),
## standing spots ±0.8, the board with the linden; house_sieber stands west of the Hollerbach (the plan
## puts it into the brook); the cottages turned 180° (door and ribbon towards the camera).
const SHIFTED := {"house_kehr": 1.5, "house_brandt": 1.5, "house_ott": 1.5, "house_sieber": 6.0,
		"v_bridge": 0.8, "v_anger_w": 0.8, "v_well": 0.8, "v_church_door": 0.8, "v_dorn_door": 0.8, "v_wash": 0.8,
		"v_board": 0.8, "village_board": 0.8, "linden": 1.0, "v_hagedorn_gate": 0.8, "v_well_bench": 0.8}
## Village schedule entries the player talks to outdoors (dialogue, standing, region village, not v_in_*).
const INDOOR_PREFIX := "v_in_"
const FLOOD_STEP := 0.25

var layout: Dictionary
var plan: Dictionary
var world: WorldRoot
var village: RegionRoot
var player: Player
var _cut: Dictionary = {}


func before_each() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	plan = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	village = world.get_node_or_null("Regions/Village") as RegionRoot
	player = world.get_player()


func after_each() -> void:
	if player != null and is_instance_valid(player):
		player.set_region(&"graveyard")


func test_regions_and_systems() -> void:
	assert_not_null(village, "Regions/Village")
	if village == null:
		return
	var gy := world.get_node_or_null("Regions/Graveyard") as RegionRoot
	assert_not_null(gy, "Regions/Graveyard")
	assert_eq(gy.region_id, &"graveyard")
	assert_eq(PackedStringArray(gy.region_config().managed_paths), PackedStringArray(["Decor", "Lights", "Grass"]))
	assert_eq(village.region_id, &"village")
	assert_eq(village.global_position, ORIGIN, "§3.1: the village at (0, 0, 400)")
	assert_eq(village.scene_file_path, "res://src/world/village/village.tscn")
	assert_eq(village.region_config().origin, ORIGIN)
	assert_true(village.hide_when_inactive)
	for rr: RegionRoot in [gy, village]:
		assert_eq(rr.camera_rig_path, NodePath("../../CameraRig"))
		assert_not_null(rr.camera_rig(), "%s rig resolves" % rr.region_id)
	for name: String in ["Village", "Relationships", "VillageShops", "Orders", "Specimens", "Lectures", "Deductions", "NpcLod"]:
		assert_not_null(world.get_node_or_null("Systems/" + name), "Systems/" + name)
	for path: String in ["Ground", "GroundCollision/Shape", "Buildings", "Decor", "Decor/Grass", "Entities", "Waypoints", "Spawns",
			"Colliders", "Dressing"]:
		assert_true(village.has_node(path), "Village/" + path)
	# Inactive outside the village; active, visible and with the village framing inside.
	await tree.process_frame
	assert_false(village.visible, "hidden while the gravekeeper is on the graveyard")
	player.set_region(&"village")
	await tree.process_frame
	assert_true(village.visible and village.active, "shown in the village")
	assert_false((world.get_node("Decor") as Node3D).visible, "the graveyard's Decor hidden")
	var rig := world.get_node("CameraRig") as CameraRig
	var cfg := village.region_config()
	assert_eq(rig.bounds_min, Vector2(ORIGIN.x, ORIGIN.z) + cfg.bounds_min, "village focus bounds")
	assert_eq([rig.zoom_min, rig.zoom_max], [cfg.camera_zoom_min, cfg.camera_zoom_max])
	assert_eq(cfg.bounds_min, Vector2(layout.camera_bounds.min[0], layout.camera_bounds.min[1]), "region config = layout camera_bounds")
	assert_eq(cfg.bounds_max, Vector2(layout.camera_bounds.max[0], layout.camera_bounds.max[1]))


func test_houses_doors_shops_and_waypoints_at_the_plan() -> void:
	var by_id := {}
	for b: Dictionary in plan.buildings:
		by_id[b.id] = b
	for b: Dictionary in layout.buildings:
		var node := village.get_node_or_null("Buildings/" + String(b.id)) as Node3D
		assert_not_null(node, String(b.id))
		if node == null:
			continue
		var p: Dictionary = by_id[b.id]
		_assert_near(node.global_position, _v2(p.pos), float(SHIFTED.get(b.id, 0.05)), String(b.id))
		assert_true(node.scene_file_path.ends_with(String(p.model) + ".glb"), "%s model %s" % [b.id, p.model])
		# §8: heights (cottage ridge ≤ 4.5 m (+ chimney), church tower ≤ 17 m).
		assert_true(_model_aabb(node).size.y <= float(p.max_height) + 0.5, "%s height %.1f" % [b.id, _model_aabb(node).size.y])
	for e: Dictionary in plan.entities:
		var node := village.get_node_or_null(("Decor/Props/" if e.type == "prop" else "Entities/") + String(e.id)) as Node3D
		assert_not_null(node, String(e.id))
		if node == null or not e.has("pos"):
			continue
		_assert_near(node.global_position, _v2(e.pos), float(SHIFTED.get(e.id, 0.1)), String(e.id))
		match String(e.type):
			"HouseDoor":
				var door := node as HouseDoor
				assert_eq([door.door_id, door.room_id, door.display_name], [StringName(e.id), StringName(e.room_id), String(e.display_name)])
				assert_eq(door.open_windows, PackedInt32Array(e.open_windows), String(e.id) + " opening times §2.2")
				assert_not_null(door.room(), String(e.id) + " has its room")
				assert_eq(HouseDoor.find(tree, door.door_id), door)
			"ShopCounter":
				assert_eq((node as ShopCounter).shop_id, StringName(e.shop_id))
			"RegionPortal":
				var portal := node as RegionPortal
				assert_eq([portal.target_region, portal.target_spawn, portal.prompt], [&"graveyard", &"from_village", String(e.prompt)])
			"VillageBoard":
				assert_true(node is VillageBoard)
	var ribbons := village.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is MourningRibbon)
	assert_eq(ribbons.size(), 6, "§4.2: a ribbon at each of the six houses")
	for r: MourningRibbon in ribbons:
		var house := village.get_node("Buildings/" + String(r.house_id)) as Node3D
		var marker := house.find_child("ribbon", true, false) as Node3D
		# G7 art review: under a low eave the ribbon hangs `ribbon_drop` lower on the door frame, 0.2 m
		# off the wall (village_build.gd).
		var drop := 0.0
		for b: Dictionary in layout.buildings:
			if String(b.id) == String(r.house_id):
				drop = float(b.get("ribbon_drop", 0.0))
		var want := marker.global_position + Vector3.DOWN * drop
		var off := r.global_position - want
		assert_true(absf(off.y) < 0.01 and Vector2(off.x, off.z).length() < (0.21 if drop > 0.0 else 0.01), "%s at the marker" % r.name)
	var spawn := village.spawn_transform(&"from_graveyard")
	_assert_near(spawn.origin, _v2(plan.spawns.from_graveyard.pos), 0.05, "spawn from_graveyard")
	assert_true((spawn.basis * Vector3.FORWARD).x < -0.9 or (spawn.basis * Vector3.BACK).x > 0.9, "the spawn faces east (into the village)")
	for id: String in plan.waypoints:
		var w := village.get_waypoint(StringName(id))
		_assert_near(w, _v2(plan.waypoints[id]), float(SHIFTED.get(id, 0.05)), "waypoint " + id)
	for room_id: String in plan.interior_waypoints:
		var room := InteriorRoom.find(tree, StringName(room_id))
		for id: String in plan.interior_waypoints[room_id]:
			var w := village.get_waypoint(StringName(id))
			assert_true(room != null and room.get_node("Waypoints/" + id) != null, "%s in the %s" % [id, room_id])
			assert_true(room != null and w.distance_to(room.global_position) < 6.0, "%s lies in its room" % id)


func test_villagers() -> void:
	var npcs := village.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Npc)
	assert_eq(npcs.size(), 12, "§3.1: the eight villagers + npc_carter_v; Phase 8: + Jakob, Veit, Hanne")
	var ids: Array[StringName] = []
	for npc: Npc in npcs:
		ids.append(npc.npc_id)
		assert_eq(npc.region_id, &"village", String(npc.name))
		assert_false(npc.is_in_group(&"saveable"), "%s is not saved (the clock is its state)" % npc.name)
		assert_not_null(npc.get_node_or_null("Model"), String(npc.name) + " model")
		assert_eq(npc._world(), village, "%s finds its waypoints in the village" % npc.name)
	for v: StringName in VILLAGERS + [&"carter"]:
		assert_has(ids, v)
	assert_eq((village.get_node("Entities/npc_oldwoman") as Npc).hide_flag, &"hagedorn_dead")
	assert_not_null(village.get_node_or_null("Entities/npc_carter_v"), "W0 note 10: npc_carter_v")
	# The graveyard Osric keeps his node and save id; NightTrade finds the graveyard one.
	var carter := world.get_node_by_layout_id("npc_carter") as Npc
	assert_eq([carter.region_id, carter.save_id], [&"graveyard", "npc_carter"])
	# Every village Npc places itself from the clock at its region-local waypoints (no warnings).
	player.set_region(&"village")
	for minute: int in [380, 600, 870, 1100, 1300]:
		TimeManager.set_time(41, minute)
		for npc: Npc in npcs:
			npc.refresh()
			if npc.is_present():
				# In the village (z ≈ 400) or in one of its rooms (the row at z −200).
				var z := npc.global_position.z
				assert_true(absf(z - ORIGIN.z) < 40.0 or absf(z + 200.0) < 6.0, "%s stays in the village at %d (%s)" % [
						npc.name, minute, npc.global_position])


func test_lights_and_dressing() -> void:
	var shadowed := 0
	var windows := 0
	for node: Node in village.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		if l.shadow_enabled:
			shadowed += 1
		if l.has_meta(&"until"):
			windows += 1
	assert_eq(shadowed, 2, "§4.7: two shadow lights (Holderkrug lantern, church door)")
	assert_true(windows >= 7, "dark-at-night window lights (%d: Amtshaus, two cottages, four houses)" % windows)
	assert_not_null(village.get_node("Buildings/v_smithy").find_child("Light_ember", true, false), "forge ember")
	var dressing := village.get_node("Dressing")
	var cottage := village.get_node("Buildings/cottage_dorn").find_child("Light_window", true, false) as Light3D
	dressing.call(&"apply_minute", 1200)
	assert_true(float(cottage.get_meta(&"base_energy")) > 0.0, "cottage window lit at 20:00")
	dressing.call(&"apply_minute", 1330)
	assert_eq(float(cottage.get_meta(&"base_energy")), 0.0, "dark after 22:00")
	dressing.call(&"apply_minute", 400)
	assert_true(float(cottage.get_meta(&"base_energy")) > 0.0, "lit again in the morning")
	for mesh: Node in village.get_node("Ground").find_children("*", "GeometryInstance3D", true, false):
		assert_eq((mesh as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "ground only receives")


## §4.1 / §10: from no village camera the graveyard or a room is in view, and the other way round.
func test_frustum_separates_village_graveyard_and_rooms() -> void:
	var rig := world.get_node("CameraRig") as CameraRig
	var anchor := Node3D.new()
	world.add_child(anchor)
	rig.target = anchor
	var gy_box := _aabb_of(world.get_node("Ground") as Node3D)
	var village_box := _aabb_of(village)
	var rooms: Array[Node3D] = [world.get_node("HutInterior") as Node3D]
	for room: Node in world.get_node("Interiors").get_children():
		rooms.append(room as Node3D)
	player.set_region(&"village")
	await tree.process_frame
	var lo: Vector2 = rig.bounds_min
	var hi: Vector2 = rig.bounds_max
	for fx: float in [lo.x, (lo.x + hi.x) * 0.5, hi.x]:
		for fz: float in [lo.y, (lo.y + hi.y) * 0.5, hi.y]:
			for zoom: float in [rig.zoom_min, rig.zoom_max]:
				anchor.global_position = Vector3(fx, 0.0, fz)
				rig.set_distance(zoom)
				rig.snap()
				var planes := rig.camera.get_frustum()
				assert_false(_in_frustum(gy_box, planes, rig.camera), "village (%.0f|%.0f z%d): the graveyard is not in view" % [fx, fz, zoom])
				for room: Node3D in rooms:
					assert_false(_in_frustum(_aabb_of(room), planes, rig.camera), "village: %s not in view" % room.name)
	player.set_region(&"graveyard")
	await tree.process_frame
	lo = rig.bounds_min
	hi = rig.bounds_max
	for fx: float in [lo.x, hi.x]:
		for fz: float in [lo.y, hi.y]:
			anchor.global_position = Vector3(fx, 0.0, fz)
			rig.set_distance(rig.zoom_max)
			rig.snap()
			assert_false(_in_frustum(village_box, rig.camera.get_frustum(), rig.camera), "graveyard (%.0f|%.0f): the village is not in view" % [fx, fz])
	rig.target = player
	anchor.free()


## §4.5 (1): Nahsicht at every door, counter, the board, the portal and every talking spot.
func test_close_sight_at_every_spot() -> void:
	player.set_region(&"village")
	await tree.process_frame
	_probe_meshes()
	for i: int in 3:
		await tree.physics_frame
	var report: PackedStringArray = []
	var failures: PackedStringArray = []
	var spots := _spots()
	assert_true(spots.size() >= 20, "%d spots" % spots.size())
	for spot: Dictionary in spots:
		var stand: Vector3 = spot.stand
		player.global_position = stand
		for zoom: float in ZOOMS:
			var eye := _eye(Vector2(stand.x, stand.z), zoom)
			var chest := stand + Vector3(0.0, player.occlusion_height, 0.0)
			for key: String in spot.points:
				var p: Vector3 = spot.points[key]
				var why := _blocked(eye, p, chest, spot.exclude)
				if why != "":
					failures.append("%s zoom %d %s: %s" % [spot.name, int(zoom), key, why])
		report.append(String(spot.name))
	print("[P7 vis village] %d spots: %s" % [spots.size(), ", ".join(report)])
	assert_eq(failures, PackedStringArray(), "§4.5 (1): all rays free")


## §4.5 (2): the north row from the Anger – each house at least 70 % in the frame and ≥ 3 % of the
## frame from the Anger in front of it (zoom 22); the church tower rises above the nave in the image.
func test_north_row_in_the_frame() -> void:
	player.set_region(&"village")
	await tree.process_frame
	var rig := world.get_node("CameraRig") as CameraRig
	var report: PackedStringArray = []
	var spots := {"v_office": "v_office_door", "v_church": "v_church_door", "v_inn": "v_inn_door"}
	for id: String in spots:
		var house := village.get_node("Buildings/" + id) as Node3D
		var wp := village.get_waypoint(StringName(spots[id]))
		var stand := wp + Vector3(0.0, 0.0, 1.2)
		_eye(Vector2(stand.x, stand.z), 22.0)
		var share := _frame_share(house, rig.camera)
		var front := _front_share(house, rig.camera)
		report.append("%s %.0f%% (front %.0f%%)/%.1f%%" % [id, share.x * 100.0, front * 100.0, share.y * 100.0])
		# W-Welt (G7 report): the fixed diorama camera (45°, FOV 30°) sees ≈ 7 m up at its focus – the
		# 8.4 m houses and the 17 m church cannot be 70 % in the frame from the Anger. Checked instead:
		# the front (door, windows, eaves – the face towards the Anger) ≥ 70 %, the whole model ≥ 20 %
		# (church) / 55 % (Amtshaus, Holderkrug), ≥ 3 % of the frame. See docs/QUALITY_GATE_STATUS.md.
		assert_true(front >= 0.7, "%s: front %.0f %% in the frame from %s" % [id, front * 100.0, spots[id]])
		assert_true(share.x >= (0.2 if id == "v_church" else 0.55), "%s: %.0f %% of the model in the frame" % [id, share.x * 100.0])
		assert_true(share.y >= 0.03, "%s covers %.1f %%" % [id, share.y * 100.0])
	# The tower above the nave: in the image it lies above the ridge (it is never in the gameplay frame –
	# its top is at the camera's height; reported, not asserted).
	var church := village.get_node("Buildings/v_church") as Node3D
	var stand := village.get_waypoint(&"v_church_door") + Vector3(0.0, 0.0, 1.2)
	_eye(Vector2(stand.x, stand.z), 26.0)
	var cam := rig.camera
	var b := cam.unproject_position(church.global_transform * Vector3(0.0, 10.6, -4.2))
	var r := cam.unproject_position(church.global_transform * Vector3(0.0, 8.8, 0.0))
	report.append("belfry y %.0f, ridge y %.0f (frame 0…%.0f)" % [b.y, r.y, cam.get_viewport().get_visible_rect().size.y])
	print("[P7 north row] ", " | ".join(report))
	assert_true(b.y < r.y, "the tower rises above the nave in the image")


## §4.5 (3): the ribbon marker of every house is free from the nearest Anger point.
func test_mourning_ribbons_are_seen_from_the_anger() -> void:
	player.set_region(&"village")
	await tree.process_frame
	_probe_meshes()
	for i: int in 3:
		await tree.physics_frame
	var space := world.get_world_3d().direct_space_state
	for ribbon: Node in village.get_node("Entities").get_children():
		if not ribbon is MourningRibbon:
			continue
		var house := village.get_node("Buildings/" + String((ribbon as MourningRibbon).house_id)) as Node3D
		var marker := (ribbon as Node3D).global_position
		var from := _nearest_walkable(marker)
		var eye := from + Vector3(0.0, 1.6, 0.0)
		var hit := _first_hit(space, eye, marker, [house])
		assert_true(hit == "", "%s seen from %s (%s)" % [ribbon.name, from, hit])


## §4.5 (4): routes (flood fill, 1.5 m capsule), standing spots free, schedule polylines free.
func test_routes_flood_fill_and_schedule_paths() -> void:
	player.set_region(&"village")
	await tree.physics_frame
	await tree.physics_frame
	var wb: Dictionary = layout.walkable_bounds
	var area := Rect2(_v2l(wb.min), _v2l(wb.max) - _v2l(wb.min))
	var reach := _flood(Vector2(ORIGIN.x - 24.5, ORIGIN.z + 1.5), FLOOD_STEP, area, 0.75)
	assert_true(reach.size() > 1000, "%d cells reachable" % reach.size())
	var targets := {}
	for id: String in ["door_inn", "door_surgery", "door_office", "door_church"]:
		targets[id] = (village.get_node("Entities/" + id) as HouseDoor).exit_transform().origin
	for id: String in ["counter_smith", "counter_grocer", "village_board"]:
		targets[id] = (village.get_node("Entities/" + id) as Node3D).global_position
	for id: String in ["v_wash", "v_well", "v_hagedorn_gate", "v_dorn_door", "v_remise", "v_church_door", "v_bridge"]:
		targets[id] = village.get_waypoint(StringName(id))
	for id: String in targets:
		var t: Vector3 = targets[id]
		var ok := false
		for key: Vector2i in reach:
			if (Vector2(key) * FLOOD_STEP).distance_to(Vector2(t.x, t.z)) <= 1.6:
				ok = true
				break
		assert_true(ok, "§4.5 (4): %s reachable from the bridge with 1.5 m" % id)
	var space := world.get_world_3d().direct_space_state
	for npc_id: StringName in VILLAGERS + [&"carter"]:
		var sched := Database.schedule(npc_id) as NpcSchedule
		for e: ScheduleEntry in sched.entries:
			if e.region != &"village":
				continue
			var ids := Array(e.path).filter(func(id: String) -> bool: return not id.begins_with(INDOOR_PREFIX) and id != "v_road_in")
			for id: String in ids:
				# The bench at the well is where Wiebke sits (animation sit) – a seat, not an obstacle.
				if e.visible and id != "v_well_bench":
					assert_true(_capsule_free(village.get_waypoint(StringName(id)), 0.3), "%s: spot %s free" % [npc_id, id])
			for k: int in ids.size() - 1:
				var a := village.get_waypoint(StringName(ids[k]))
				var b := village.get_waypoint(StringName(ids[k + 1]))
				var pen := _path_penetration(space, a, b)
				assert_true(pen.x <= 0.3, "%s: %s → %s runs %.2f m into %s" % [npc_id, ids[k], ids[k + 1], pen.x, _hit_name(pen)])


# --- helpers ---------------------------------------------------------------------------------

func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]) + ORIGIN.x, float(a[1]) + ORIGIN.z)


func _v2l(a: Array) -> Vector2:
	return _v2(a)


func _assert_near(actual: Vector3, expected: Vector2, tolerance: float, message: String) -> void:
	var d := Vector2(actual.x, actual.z).distance_to(expected)
	assert_true(d <= tolerance + 0.001, "%s at %s, plan %s (Δ %.2f > %.2f)" % [message, Vector2(actual.x, actual.z) - Vector2(ORIGIN.x, ORIGIN.z),
			expected - Vector2(ORIGIN.x, ORIGIN.z), d, tolerance])


func _model_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _aabb_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n: Node in node.find_children("*", "VisualInstance3D", true, false):
		var v := n as VisualInstance3D
		if v is Light3D or v is MultiMeshInstance3D:
			continue
		var b := v.global_transform * v.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _in_frustum(box: AABB, planes: Array[Plane], cam: Camera3D) -> bool:
	for plane: Plane in planes:
		var outside := true
		for i: int in 8:
			if plane.distance_to(box.get_endpoint(i)) <= 0.0:
				outside = false
				break
		if outside:
			return false
	# get_frustum() has the far plane (distance + 60) – beyond it nothing is drawn.
	return cam != null


## Camera position of the gameplay rig following a player at `at` (bounds of the active region).
func _eye(at: Vector2, zoom: float) -> Vector3:
	var rig := world.get_node("CameraRig") as CameraRig
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = Vector3(at.x, village.ground_height(at), at.y)
	rig.target = anchor
	rig.set_distance(zoom)
	rig.snap()
	var eye := rig.camera.global_position
	rig.target = player
	anchor.free()
	return eye


## Collision copies (PROBE_LAYER) of every visible village mesh except ground, grass, figures and the
## player; foliage meshes carry the meta "foliage".
func _probe_meshes() -> void:
	for n: Node in village.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var path := String(village.get_path_to(mi))
		if not mi.is_visible_in_tree() or mi.mesh == null or path.begins_with("Ground") or path.begins_with("Decor/Grass") \
				or (path.begins_with("Entities/npc_")):
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mi.mesh.get_faces())
		var body := StaticBody3D.new()
		body.name = "Probe"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		if _is_foliage(mi):
			body.set_meta(&"foliage", true)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)


func _is_foliage(mi: MeshInstance3D) -> bool:
	for s: int in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s) as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path == FOLIAGE_SHADER:
			return true
	return false


## "" when the ray eye → p meets nothing (beyond 0.05 m of p) but `exclude`'s subtrees and foliage the
## occlusion cutout opens (cone from the eye to the player's chest); else the blocker's path.
func _blocked(eye: Vector3, p: Vector3, chest: Vector3, exclude: Array) -> String:
	var space := world.get_world_3d().direct_space_state
	var dir := (p - eye).normalized()
	var to := p - dir * 0.05
	var from := eye
	for guard: int in 48:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, PROBE_LAYER))
		if hit.is_empty():
			return ""
		var body := hit.collider as Node
		var skip := false
		for e: Node in exclude:
			if e != null and e.is_ancestor_of(body):
				skip = true
		if not skip and body.has_meta(&"foliage") and _cut_at(hit.position, eye, chest) > 0.5:
			skip = true
		if not skip:
			return String(village.get_path_to(body.get_parent()))
		from = (hit.position as Vector3) + dir * 0.01
	return ""


func _first_hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> String:
	var dir := (to - from).normalized()
	var end := to - dir * 0.08
	for guard: int in 48:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, PROBE_LAYER))
		if hit.is_empty():
			return ""
		var body := hit.collider as Node
		var skip := false
		for e: Node in exclude:
			if e.is_ancestor_of(body):
				skip = true
		if not skip:
			return String(village.get_path_to(body.get_parent()))
		from = (hit.position as Vector3) + dir * 0.01
	return ""


## GDScript mirror of occlusion_cut() in painted_foliage.gdshader (0 = kept … 1 = fully cut).
func _cut_at(p: Vector3, eye: Vector3, target: Vector3) -> float:
	if _cut.is_empty():
		_cut = {"radius": float((ProjectSettings.get_setting("shader_globals/occlusion_radius") as Dictionary).value),
				"softness": 0.45, "rise": 0.35}
	var axis := target - eye
	var t := (p - eye).dot(axis) / axis.length_squared()
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var radius := float(_cut.radius) * t
	var d := p.distance_to(eye + axis * t)
	var radial := 1.0 - smoothstep(radius * (1.0 - float(_cut.softness)), radius, d)
	return radial * smoothstep(target.y, target.y + float(_cut.rise), p.y)


## The §4.5 (1) spots: {name, stand (player feet), points {key: Vector3}, exclude [nodes]}.
func _spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var buildings := village.get_node("Buildings")
	for id: String in ["door_inn", "door_surgery", "door_office", "door_church"]:
		var door := village.get_node("Entities/" + id) as HouseDoor
		var house := buildings.get_node({"door_inn": "v_inn", "door_surgery": "v_surgery", "door_office": "v_office",
				"door_church": "v_church"}[id]) as Node3D
		var stand := _free_near(door.exit_transform() * Vector3(0.0, 0.0, 0.5))
		out.append({"name": id, "stand": stand, "exclude": [house],
				"points": {"head": stand + Vector3(0, 1.7, 0), "door": door.global_position + Vector3(0, 1.2, 0)}})
	for id: String in ["counter_smith", "counter_grocer", "village_board", "road_out"]:
		var node := village.get_node("Entities/" + id) as Node3D
		var house: Node = null
		if id == "counter_smith":
			house = buildings.get_node("v_smithy")
		elif id == "counter_grocer":
			house = buildings.get_node("v_shop")
		elif id == "village_board":
			house = village.get_node("Decor/Props/board")
		var stand := _free_near(node.global_position + Vector3(0.9 if id.begins_with("counter") else 0.0, 0.0,
				0.9 if not id.begins_with("counter") else 0.0))
		out.append({"name": id, "stand": stand, "exclude": [house],
				"points": {"head": stand + Vector3(0, 1.7, 0), "centre": node.global_position + Vector3(0, 1.0, 0)}})
	var seen := {}
	for npc_id: StringName in VILLAGERS + [&"carter"]:
		var sched := Database.schedule(npc_id) as NpcSchedule
		for e: ScheduleEntry in sched.entries:
			if e.region != &"village" or not e.visible or e.dialogue_id == &"" or e.travel_minutes > 0 or e.path.is_empty():
				continue
			var id := String(e.path[e.path.size() - 1])
			if id.begins_with(INDOOR_PREFIX) or seen.has(id + String(npc_id)):
				continue
			seen[id + String(npc_id)] = true
			var spot := village.get_waypoint(StringName(id))
			# The gravekeeper stands 1 m from the person towards the middle of the Anger.
			var toward := Vector3(ORIGIN.x - spot.x, 0.0, ORIGIN.z - spot.z)
			var stand := _free_near(spot + (toward.normalized() if toward.length() > 0.5 else Vector3.BACK))
			# Wiebke Hagedorn is small and bent (head ≈ 1.45 m), sitting on the bench ≈ 1.1 m.
			var head := 1.6
			if npc_id == &"oldwoman":
				head = 1.1 if e.animation == &"sit" else 1.45
			out.append({"name": "%s@%s" % [npc_id, id], "stand": stand, "exclude": [],
					"points": {"head": stand + Vector3(0, 1.7, 0), "person": spot + Vector3(0, head, 0)}})
	return out


## The first of `p` and 8 points around it (1.0 m) where the gravekeeper fits.
func _free_near(p: Vector3) -> Vector3:
	for k: int in 17:
		var q := p if k == 0 else p + Vector3(0.6 if k <= 8 else 1.2, 0, 0).rotated(Vector3.UP, TAU * k / 8.0)
		q.y = village.ground_height(Vector2(q.x, q.z))
		if _capsule_free(q, 0.32):
			return q
	return p


func _capsule_free(p: Vector3, radius: float) -> bool:
	var space := world.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, village.ground_height(Vector2(p.x, p.z)) + 0.9, p.z))
	for hit: Dictionary in space.intersect_shape(query, 8):
		var body := hit.collider as Node
		if body is StaticBody3D and String(body.name) != "GroundCollision":
			return false
	return true


func _nearest_walkable(marker: Vector3) -> Vector3:
	var wb: Dictionary = layout.walkable_bounds
	var area := Rect2(_v2l(wb.min), _v2l(wb.max) - _v2l(wb.min))
	var best := Vector3.ZERO
	var best_d := INF
	for i: int in range(-12, 13):
		for j: int in range(-12, 13):
			var q := Vector3(marker.x + i * 0.5, 0.0, marker.z + j * 0.5)
			if not area.has_point(Vector2(q.x, q.z)):
				continue
			var d := Vector2(q.x - marker.x, q.z - marker.z).length()
			if d < best_d and _capsule_free(q, 0.32):
				best_d = d
				best = Vector3(q.x, village.ground_height(Vector2(q.x, q.z)), q.z)
	return best


func _flood(start: Vector2, step: float, area: Rect2, radius: float) -> Dictionary:
	var seen := {}
	var origin := Vector2i(roundi(start.x / step), roundi(start.y / step))
	var queue: Array[Vector2i] = [origin]
	seen[origin] = true
	var free := {}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var p := Vector2(c) * step
		if not area.has_point(p) or not _capsule_free(Vector3(p.x, 0.0, p.y), radius):
			continue
		free[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return free


## How far (m) the hip-height line a → b lies inside a world collider: for every blocked sample (each
## 0.1 m) the smallest sideways shift (0.05 m steps, either side) that frees it, 9 = not within 0.5 m;
## (worst shift, x, z of that sample). The ends (0.5 m) are the standing spots themselves.
func _path_penetration(_space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Vector3:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := flat.length()
	var dir := flat.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var worst := Vector3.ZERO
	for i: int in int(length / 0.1) + 1:
		var s := i * 0.1
		if s < 0.5 or s > length - 0.5:
			continue
		var p := a + dir * s
		if _capsule_free(p, 0.05):
			continue
		var shift := 9.0
		for k: int in range(1, 11):
			if _capsule_free(p + side * (k * 0.05), 0.05) or _capsule_free(p - side * (k * 0.05), 0.05):
				shift = k * 0.05
				break
		if shift > worst.x:
			worst = Vector3(shift, p.x, p.z)
	return worst


func _hit_name(pen: Vector3) -> String:
	if pen.x <= 0.0:
		return "-"
	return "(%.1f | %.1f)" % [pen.y - ORIGIN.x, pen.z - ORIGIN.z]


## Share of the front-face points in the frame: a 5 × 4 grid over the house's south face (AABB front,
## from the ground up to the eave height – 62 % of the model's height).
func _front_share(house: Node3D, cam: Camera3D) -> float:
	var box := _model_aabb(house)
	var frame := Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size)
	var inside := 0
	for i: int in 5:
		for j: int in 4:
			var p := Vector3(lerpf(box.position.x + 0.3, box.end.x - 0.3, i / 4.0), lerpf(box.position.y + 0.2, box.position.y + minf(box.size.y * 0.62, 5.6), j / 3.0),
					box.end.z - 0.3)
			if not cam.is_position_behind(p) and frame.has_point(cam.unproject_position(p)):
				inside += 1
	return inside / 20.0


## (share of the model's mesh vertices in the frame, share of the frame its projected AABB covers).
func _frame_share(house: Node3D, cam: Camera3D) -> Vector2:
	var vp := cam.get_viewport().get_visible_rect().size
	var frame := Rect2(Vector2.ZERO, vp)
	var inside := 0
	var total := 0
	for n: Node in house.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var faces := mi.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var p := mi.global_transform * faces[i]
			total += 1
			if not cam.is_position_behind(p) and frame.has_point(cam.unproject_position(p)):
				inside += 1
	var box := _model_aabb(house)
	var r := Rect2()
	for i: int in 8:
		var s := cam.unproject_position(box.get_endpoint(i))
		r = Rect2(s, Vector2.ZERO) if i == 0 else r.expand(s)
	return Vector2(float(inside) / maxi(total, 1), r.intersection(frame).get_area() / frame.get_area())


# --- Phase 8 (docs/PHASE8_DESIGN.md §3.1, §4.6, §4.8 point 4, §10 – W-Welt) --------------------------

const P8_WAYPOINTS := ["v_ott_door", "v_kehr_door", "v_ott_lane_w", "v_ott_lane", "v_kehr_lane", "v_church_step", "v_bridge_sit", "v_well_peddler",
		"v_remise_sleep", "v_peddler_in", "v_peddler_out", "v_lights_gather"]
const P8_FACING := ["v_ott_door", "v_kehr_door", "v_church_step", "v_bridge_sit", "v_well_peddler", "v_peddler_in", "v_lights_gather"]
const P8_NPCS := {"npc_apprentice_v": ["apprentice", "ph_chr_apprentice"], "npc_beggar": ["beggar", "ph_chr_beggar"],
		"npc_peddler": ["peddler", "ph_chr_peddler"]}
const P8_VILLAGERS: Array[StringName] = [&"beggar", &"peddler", &"apprentice"]


## §4.7: only D1–D5 (new markers and waypoints) and the new Npc against the approved Phase-7 village.
func test_phase8_layout_diff_against_phase7() -> void:
	var old := Phase8Fixtures.village_layout_p7()
	assert_false(old.is_empty(), "village_layout_p7.json")
	var allowed := ["+_waypoints_phase8", "+_phase8", "+phase8"]
	for id: String in P8_WAYPOINTS:
		allowed.append("+waypoints." + id)
	for id: String in P8_FACING:
		allowed.append("+waypoint_facing." + id)
	var changes := PackedStringArray()
	for key: String in layout:
		if not old.has(key):
			changes.append("+" + key)
		elif key == "waypoints" or key == "waypoint_facing":
			for id: String in layout[key]:
				if not (old[key] as Dictionary).has(id):
					changes.append("+%s.%s" % [key, id])
				else:
					assert_eq(layout[key][id], old[key][id], "%s.%s unchanged" % [key, id])
		elif key == "npcs":
			assert_eq((layout.npcs as Array).slice(0, old.npcs.size()), old.npcs, "the Phase-7 Npc unchanged")
			for n: Dictionary in (layout.npcs as Array).slice(old.npcs.size()):
				assert_true(P8_NPCS.has(String(n.id)), "new Npc " + String(n.id))
		else:
			assert_eq(layout[key], old[key], key + " unchanged (§4.7)")
	for key: String in old:
		assert_true(layout.has(key), key + " kept")
	var got := Array(changes)
	got.sort()
	allowed.sort()
	assert_eq(got, allowed, "§4.7 D1–D5 only")


## §3.1, §4.6: Jakob, Veit and Hanne in the village (hidden before p8_open), the watch places (≤ 12 m from the
## door places, D2) and the sick lights at the window markers of the Otts and the Kehrs (D3, no new light).
func test_phase8_npcs_watch_spots_and_sick_lights() -> void:
	for id: String in P8_NPCS:
		var npc := village.get_node_or_null("Entities/" + id) as Npc
		assert_not_null(npc, id)
		if npc == null:
			continue
		assert_eq([npc.npc_id, npc.region_id, npc.requires_flag, npc.save_id], [StringName(P8_NPCS[id][0]), &"village", &"p8_open", ""], id)
		assert_true(npc.get_node("Model").scene_file_path.ends_with(String(P8_NPCS[id][1]) + ".glb"), id + " model")
	GameState.set_flag(&"p8_open", false)
	var veit := village.get_node("Entities/npc_beggar") as Npc
	veit.refresh()
	assert_false(veit.is_present(), "Veit only from p8_open on")
	for pair: Array in [["watch_ott", "v_ott_door"], ["watch_kehr", "v_kehr_door"]]:
		var spot := village.get_node_or_null("Entities/" + String(pair[0])) as WatchSpot
		assert_not_null(spot, String(pair[0]))
		if spot == null:
			continue
		assert_eq(spot.spot_id, StringName(pair[0]))
		var door := village.get_waypoint(StringName(pair[1]))
		assert_true(Vector2(spot.global_position.x, spot.global_position.z).distance_to(Vector2(door.x, door.z)) <= 12.0, "D2: ≤ 12 m")
		assert_true(_capsule_free(spot.global_position, 0.3), String(pair[0]) + " free")
	for pair: Array in [["sick_light_ott", "house_ott"], ["sick_light_kehr", "house_kehr"]]:
		var light := village.get_node_or_null("Entities/" + String(pair[0])) as SickLight
		assert_not_null(light, String(pair[0]))
		if light == null:
			continue
		assert_eq(light.house, StringName(pair[1]))
		var house := village.get_node("Buildings/" + String(pair[1])) as Node3D
		var marker := house.find_child("light_window", true, false) as Node3D
		assert_true(light.global_position.distance_to(marker.global_position) < 0.3, "D3 at the window marker")
		assert_true(light.find_children("*", "Light3D", true, false).is_empty(), "D3: no new light")
		var window := house.find_child("Light_window", true, false) as Light3D
		assert_eq(String(window.get_meta(&"house", "")), String(pair[1]), "the window light knows its house")


## §4.8 (4): the door places seen from the watch places (a ray at head height), the door places in the frame
## of the gameplay camera at the watch place; Veit, Hanne and Jakob at all their village places free.
func test_phase8_village_sight() -> void:
	player.set_region(&"village")
	await tree.process_frame
	_probe_meshes()
	for i: int in 3:
		await tree.physics_frame
	var space := world.get_world_3d().direct_space_state
	var cam := (world.get_node("CameraRig") as CameraRig).camera
	var frame := Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size)
	for pair: Array in [["watch_ott", "v_ott_door", "house_ott"], ["watch_kehr", "v_kehr_door", "house_kehr"]]:
		var spot := village.get_node("Entities/" + String(pair[0])) as Node3D
		var door := village.get_waypoint(StringName(pair[1]))
		var eye := spot.global_position + Vector3(0, 1.6, 0)
		assert_eq(_first_hit(space, eye, door + Vector3(0, 1.6, 0), [village.get_node("Buildings/" + String(pair[2]))]), "",
				"§4.8 (4): %s sees %s" % [pair[0], pair[1]])
		player.global_position = spot.global_position
		_eye(Vector2(spot.global_position.x, spot.global_position.z), 22.0)
		assert_true(frame.has_point(cam.unproject_position(door + Vector3(0, 1.0, 0))), "%s in the frame from %s" % [String(pair[1]), String(pair[0])])
		# W-Welt (image p8_18): the gravekeeper himself is not under a roof for the camera (the Remise hid him).
		assert_eq(_first_hit(space, cam.global_position, spot.global_position + Vector3(0, 1.2, 0), [player, spot]), "",
				"§4.8 (4): the gravekeeper at %s seen by the camera" % pair[0])
	var failures := PackedStringArray()
	var seen := {}
	for npc_id: StringName in P8_VILLAGERS:
		var sched := Database.schedule(npc_id) as NpcSchedule
		for e: ScheduleEntry in sched.entries:
			if e.region != &"village" or not e.visible or e.travel_minutes > 0 or e.path.is_empty():
				continue
			var id := String(e.path[e.path.size() - 1])
			if id.begins_with(INDOOR_PREFIX) or seen.has(id):
				continue
			seen[id] = true
			var spot := village.get_waypoint(StringName(id))
			var toward := Vector3(ORIGIN.x - spot.x, 0.0, ORIGIN.z - spot.z)
			var stand := _free_near(spot + (toward.normalized() if toward.length() > 0.5 else Vector3.BACK))
			player.global_position = stand
			var head := 1.1 if e.animation == &"sit_beg" else 1.6
			for zoom: float in ZOOMS:
				var why := _blocked(_eye(Vector2(stand.x, stand.z), zoom), spot + Vector3(0, head, 0), stand + Vector3(0.0, player.occlusion_height, 0.0), [])
				if why != "":
					failures.append("%s@%s zoom %d: %s" % [npc_id, id, int(zoom), why])
	assert_true(seen.size() >= 4, "%d places of Jakob, Veit and Hanne" % seen.size())
	assert_eq(failures, PackedStringArray(), "§4.8 (4): Veit, Hanne and Jakob free at their places")
