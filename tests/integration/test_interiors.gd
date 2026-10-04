extends TestCase
## W-Welt (docs/PHASE6_DESIGN.md §4.7, §4.8, §10 test_interiors): the three building rooms in the
## generated world – instanced at their origins under Interiors/, InteriorRoom set up (Sun, Spawn,
## camera rig / outdoor sun paths, hide_when_inactive); frustum test (from each room's camera
## profile neither another room nor the world is in view); spawn_inside / door_inside walkable;
## level furniture (collision only while shown); light roles per room; ≤ 2 shadow lights;
## the crypt table (room crypt, requires_level 1) and its followers; niches 1–6 by level.

const TIMEOUT := 90.0
const WORLD := "res://src/world/graveyard/graveyard.tscn"
const ROOMS := {"crypt": ["CryptInterior", Vector3(60, 0, -200)], "chapel": ["ChapelInterior", Vector3(120, 0, -200)],
		"shed": ["ShedInterior", Vector3(180, 0, -200)]}
const NICHE_LEVELS := {"niche_1": 1, "niche_2": 1, "niche_3": 2, "niche_4": 2, "niche_5": 3, "niche_6": 3}

var world: WorldRoot
var buildings: Buildings


func before_each() -> void:
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	buildings = world.get_node("Systems/Buildings") as Buildings


func after_each() -> void:
	GameState.set_flag(&"buildings_open", false)


func test_rooms_are_instanced_at_their_origins() -> void:
	for id: String in ROOMS:
		var room := world.get_node_or_null("Interiors/" + String(ROOMS[id][0])) as InteriorRoom
		assert_not_null(room, id)
		if room == null:
			continue
		assert_eq(room.room_id, StringName(id))
		assert_eq(room.building_id, StringName(id))
		assert_true(room.hide_when_inactive, id + ": only the active room is drawn")
		assert_eq(room.global_position, ROOMS[id][1], id + " origin")
		assert_not_null(room.get_node_or_null("Sun"), id + " Sun")
		assert_not_null(room.get_node_or_null("Spawn"), id + " Spawn")
		assert_eq(room.camera_rig_path, NodePath("../../CameraRig"))
		assert_eq(room.outdoor_sun_path, NodePath("../../Sun"))
		assert_not_null(room.get_node_or_null(room.camera_rig_path), id + " rig path resolves")
		assert_not_null(room.get_node_or_null(room.outdoor_sun_path), id + " sun path resolves")
		assert_false(room.visible, id + " hidden outside")
		assert_eq(InteriorRoom.find(tree, StringName(id)), room)
		var exits := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)
		assert_eq(exits.size(), 1, id + ": one RoomExit")


func test_frustum_shows_only_the_own_room() -> void:
	var rig := world.get_node("CameraRig") as CameraRig
	var player := world.get_player()
	for id: String in ROOMS:
		var room := InteriorRoom.find(tree, StringName(id))
		player.global_transform = room.spawn_transform()
		player.set_in_interior(true, StringName(id))
		await tree.process_frame
		rig.snap()
		for zoom: float in [room.room_config().camera_zoom_min, room.room_config().camera_zoom_max]:
			rig.set_distance(zoom)
			rig.snap()
			var planes := rig.camera.get_frustum()
			for other: String in ROOMS:
				if other == id:
					continue
				var aabb := _aabb(InteriorRoom.find(tree, StringName(other)))
				assert_false(_in_frustum(aabb, planes), "%s (zoom %.0f): %s not in view" % [id, zoom, other])
			assert_false(_in_frustum(_aabb(world.get_node("Ground") as Node3D), planes), "%s: the world is not in view" % id)
			assert_false(_in_frustum(_aabb(world.get_node("HutInterior") as Node3D), planes), "%s: the hut is not in view" % id)
		assert_true(room.visible and room.active, id + " active")
		player.set_in_interior(false)
		await tree.process_frame
		assert_false(room.visible, id + " hidden again")


func test_spawn_and_exit_are_walkable() -> void:
	await tree.physics_frame
	for id: String in ROOMS:
		var room := InteriorRoom.find(tree, StringName(id))
		for p: Vector3 in [room.spawn_transform().origin, (room.find_children("*", "", true, false).filter(
				func(n: Node) -> bool: return n is RoomExit)[0] as Node3D).global_position + Vector3(0, 0, -0.4)]:
			assert_true(_capsule_free(p), "%s: the gravekeeper fits at %s" % [id, p])
			var hit := world.get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.DOWN, 1))
			assert_false(hit.is_empty(), "%s: floor under %s" % [id, p])


func test_level_furniture_and_collision() -> void:
	for level: int in [0, 1, 2, 3]:
		buildings.load_state({"levels": {"crypt": level, "chapel": level, "shed": level}})
		buildings.apply_levels()
		for id: String in ROOMS:
			var room := InteriorRoom.find(tree, StringName(id))
			assert_eq(room.level, level, id)
			for node: Node in room.find_children("*", "Node3D", true, false):
				if not (node.has_meta(&"min_level") or node.has_meta(&"max_level")):
					continue
				var shown := InteriorRoom.is_shown_at(node, level)
				assert_eq((node as Node3D).visible, shown, "%s L%d %s visible" % [id, level, node.name])
				assert_eq(node.process_mode == Node.PROCESS_MODE_DISABLED, not shown, "%s L%d %s physics" % [id, level, node.name])
	# The chapel pews: rough ones on level 1 only, the four pews from level 2.
	var chapel := InteriorRoom.find(tree, &"chapel")
	var rough := chapel.get_node("Furniture").find_children("pew_rough_*", "", false, false)
	assert_eq(rough.size(), 2)
	for n: Node in rough:
		assert_eq([int(n.get_meta(&"min_level")), int(n.get_meta(&"max_level"))], [1, 1])
	assert_eq(chapel.get_node("Furniture").find_children("pew_?", "", false, false).size(), 4, "4 pews")


func test_crypt_table_niches_and_ossuary() -> void:
	var crypt := InteriorRoom.find(tree, &"crypt")
	var table := crypt.get_node("Entities/MorgueTable") as MorgueTable
	assert_eq([table.room, table.requires_level, table.retire_at_level], [&"crypt", 1, 0])
	var old := world.get_node_by_layout_id("morgue_table") as MorgueTable
	assert_eq([old.room, old.requires_level, old.retire_at_level], [&"", 0, 1], "§4.4: the old table retires at crypt 1")
	var followers := old.followers().map(func(n: Node) -> String: return String(n.name))
	for name: String in ["SmokeBowl", "WashBasin", "morgue_table"]:
		assert_true(name in followers, "old table follower " + name)
	var crypt_followers := table.followers().map(func(n: Node) -> String: return String(n.name))
	for name: String in ["SmokeBowl", "WashBasin"]:
		assert_true(name in crypt_followers, "crypt table follower " + name)
	for level: int in [0, 1]:
		buildings.load_state({"levels": {"crypt": level}})
		buildings.apply_levels()
		old.refresh_active()
		table.refresh_active()
		assert_eq([old.is_active(), table.is_active()], [level == 0, level == 1], "exactly one active table at crypt %d" % level)
		assert_eq(old.visible, level == 0)
		assert_eq((world.get_node("Decor/Phase4Props/WashBasin") as Node3D).visible, level == 0, "wash basin follows")
	var niches := crypt.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is CryptNiche)
	assert_eq(niches.size(), 6)
	for n: Node in niches:
		var niche := n as CryptNiche
		assert_eq(niche.min_level, NICHE_LEVELS[niche.slot_id], niche.slot_id)
		assert_not_null(niche.find_child("slot_corpse", true, false), niche.slot_id + " slot marker")
		assert_not_null(niche.find_child("chill", true, false), niche.slot_id + " chill marker")
		if niche.min_level > 1:
			var sealed := niche.get_node_or_null("Sealed") as Node3D
			assert_not_null(sealed, niche.slot_id + " sealed panel")
			assert_eq(int(sealed.get_meta(&"max_level")), niche.min_level - 1)
	assert_not_null(crypt.get_node_or_null("Entities/OssuaryShelf"), "ossuary shelf")
	assert_not_null(crypt.get_node_or_null("Entities/SealedPassage"), "sealed passage")
	var chapel := InteriorRoom.find(tree, &"chapel")
	for path: String in ["Entities/ChapelAltar", "Entities/Catafalque", "Entities/MournerSet"]:
		assert_not_null(chapel.get_node_or_null(path), "chapel " + path)
	assert_eq((chapel.get_node("Entities/MournerSet") as MournerSet).figures().size(), 4, "4 mourners")
	var shed := InteriorRoom.find(tree, &"shed")
	assert_true(shed.get_node_or_null("Entities/ShedStore") is ShedStore, "the shed store")


func test_light_roles_and_shadow_budget() -> void:
	var expect := {"crypt": [&"window", &"lantern", &"candle"], "chapel": [&"window", &"rite", &"eternal", &"stain"],
			"shed": [&"window", &"lantern"]}
	for id: String in ROOMS:
		var room := InteriorRoom.find(tree, StringName(id))
		var roles := {}
		var shadows := 0
		for node: Node in room.find_children("*", "Light3D", true, false):
			var l := node as Light3D
			if l is DirectionalLight3D:
				continue
			roles[StringName(l.get_meta(&"interior_role", &""))] = true
			if l.shadow_enabled or l.get_meta(&"interior_role", &"") == &"lantern":
				shadows += 1
		if room.get_node("Sun").get("shadow_enabled"):
			shadows += 1
		for r: StringName in expect[id]:
			assert_true(roles.has(r), "%s has a %s light" % [id, r])
		assert_true(shadows <= 2, "%s: ≤ 2 shadow lights (%d)" % [id, shadows])
	var crypt_cfg := InteriorRoom.find(tree, &"crypt").room_config()
	assert_true(crypt_cfg.fog_enabled, "the crypt's cold air")
	assert_eq(crypt_cfg.sun_day_energy, 0.0, "no sun below ground")


func test_chapel_rite_lights_follow_the_altar() -> void:
	var chapel := InteriorRoom.find(tree, &"chapel")
	var rite := chapel.get_node("RiteLights")
	var altar := chapel.get_node("Entities/ChapelAltar") as ChapelAltar
	buildings.load_state({"levels": {"chapel": 1}})
	altar.rite_active = false
	rite.call(&"apply")
	var candles := chapel.find_children("*", "Light3D", true, false).filter(
			func(n: Node) -> bool: return n.get_meta(&"interior_role", &"") == &"rite")
	assert_eq(candles.size(), 2, "two altar candles")
	for l: Light3D in candles:
		assert_false(l.visible, "candles out without a rite")
	altar.rite_active = true
	rite.call(&"apply")
	for l: Light3D in candles:
		assert_true(l.visible, "candles burn during the rite")
	altar.rite_active = false
	buildings.load_state({"levels": {"chapel": 3}})
	rite.call(&"apply")
	for l: Light3D in candles:
		assert_true(l.visible, "level 3: eternal light, candles always")


# --- Phase 7 (docs/PHASE7_DESIGN.md §4.3, §4.6 P1, §4.7, §10 test_interiors +) -----------------

const VILLAGE_ROOMS := {"inn": ["InnInterior", Vector3(240, 0, -200), "door_inn", ["v_in_inn_bar", "v_in_inn_table", "v_in_inn_corner"]],
		"surgery": ["SurgeryInterior", Vector3(300, 0, -200), "door_surgery", ["v_in_surgery_desk"]],
		"office": ["OfficeInterior", Vector3(360, 0, -200), "door_office", ["v_in_office_desk"]],
		# G7 round 1: the village church walk-in.
		"church": ["ChurchInterior", Vector3(420, 0, -200), "door_church", ["v_in_church_altar"]]}


func test_village_rooms_at_their_origins_with_door_exits() -> void:
	for id: String in VILLAGE_ROOMS:
		var spec: Array = VILLAGE_ROOMS[id]
		var room := world.get_node_or_null("Interiors/" + String(spec[0])) as InteriorRoom
		assert_not_null(room, id)
		if room == null:
			continue
		assert_eq([room.room_id, room.region_id, room.building_id], [StringName(id), &"village", &""])
		assert_true(room.hide_when_inactive)
		assert_eq(room.global_position, spec[1], id + " origin §4.3")
		assert_eq(room.camera_rig_path, NodePath("../../CameraRig"))
		assert_eq(room.outdoor_sun_path, NodePath("../../Sun"))
		var cfg := room.room_config()
		assert_eq(cfg, load("res://data/config/interiors/%s.tres" % id), id + " config")
		var exits := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)
		assert_eq(exits.size(), 1)
		var exit := exits[0] as RoomExit
		assert_eq(exit.door_id, StringName(spec[2]), id + ": the exit leads to its HouseDoor")
		var door := HouseDoor.find(tree, StringName(spec[2]))
		assert_not_null(door, String(spec[2]))
		if door == null:
			continue
		assert_eq(door.room(), room)
		assert_true(exit.exit_transform().origin.distance_to(door.exit_transform().origin) < 0.001, id + " exit = door outside")
		for wp: String in spec[3]:
			assert_not_null(room.get_node_or_null("Waypoints/" + wp), "%s %s" % [id, wp])
	var surgery := InteriorRoom.find(tree, &"surgery")
	var lecture := surgery.get_node_or_null("Entities/LectureSet") as LectureSet
	assert_not_null(lecture, "§4.3: the LectureSet in the surgery")
	if lecture != null:
		assert_eq(lecture.students().size(), 3, "three students")
		assert_not_null(lecture.jar(), "the sealed jar")
		for n: Node3D in lecture.students() + [lecture.jar()]:
			assert_false(n.visible, "hidden until a lecture")
	var office := InteriorRoom.find(tree, &"office")
	assert_true(office.get_node_or_null("Entities/PoorBox") is PoorBox, "the poor box")
	assert_true(office.get_node_or_null("Entities/RegisterCopy") is RegisterCopy, "the register copy")


func test_village_rooms_frustum_lights_and_walkable() -> void:
	var rig := world.get_node("CameraRig") as CameraRig
	var player := world.get_player()
	player.set_region(&"village")
	await tree.process_frame
	var others: Array[Node3D] = [world.get_node("Ground") as Node3D, world.get_node("Regions/Village/Ground") as Node3D,
			world.get_node("HutInterior") as Node3D]
	for node: Node in world.get_node("Interiors").get_children():
		others.append(node as Node3D)
	for id: String in VILLAGE_ROOMS:
		var room := InteriorRoom.find(tree, StringName(id))
		player.global_transform = room.spawn_transform()
		player.set_in_interior(true, StringName(id))
		await tree.process_frame
		for zoom: float in [room.room_config().camera_zoom_min, room.room_config().camera_zoom_max]:
			rig.set_distance(zoom)
			rig.snap()
			var planes := rig.camera.get_frustum()
			for other: Node3D in others:
				if other == room:
					continue
				assert_false(_in_frustum(_aabb(other), planes), "%s (zoom %.0f): %s not in view" % [id, zoom, other.name])
		var shadows := 0
		for node: Node in room.find_children("*", "Light3D", true, false):
			var l := node as Light3D
			if not l is DirectionalLight3D and (l.shadow_enabled or l.get_meta(&"interior_role", &"") == &"lantern"):
				shadows += 1
		if room.get_node("Sun").get("shadow_enabled"):
			shadows += 1
		assert_true(shadows <= 2, "%s: ≤ 2 shadow lights (%d)" % [id, shadows])
		await tree.physics_frame
		for p: Vector3 in [room.spawn_transform().origin]:
			assert_true(_capsule_free(p), "%s: the gravekeeper fits at the spawn" % id)
		player.set_in_interior(false)
	player.set_region(&"graveyard")
	var inn := InteriorRoom.find(tree, &"inn")
	var roles := {}
	for node: Node in inn.find_children("*", "Light3D", true, false):
		roles[StringName(node.get_meta(&"interior_role", &""))] = true
	for r: StringName in [&"window", &"lantern", &"stove"]:
		assert_true(roles.has(r), "inn: %s light (§4.7)" % r)


func test_crypt_pult_place() -> void:
	var crypt := InteriorRoom.find(tree, &"crypt")
	var place := crypt.get_node_or_null("Entities/PultPlace") as Node3D
	assert_not_null(place, "§4.6 P1: the pult place in the crypt")
	if place == null:
		return
	assert_eq(int(place.get_meta(&"min_level")), 1, "from crypt level 1")
	var site := place.get_node("site_pult") as BuildSite
	assert_eq([site.station_id, site.requires_flag], [&"pult", &"village_open"])
	var station := place.get_node("station_pult") as Workbench
	assert_eq([station.station, station.requires_built], [&"pult", true])
	assert_true(station.get_node_or_null("PultStore") is PultStore, "the cold drawer")
	assert_true(station.get_node_or_null("CollectionShelf") is CollectionShelf, "the collection shelf")
	assert_not_null(station.get_node_or_null("Collision"), "the pult collides once built")
	# Before village_open the site is not shown (W1 P2 note), afterwards with workshop_open.
	GameState.set_flag(&"village_open", false)
	site.refresh()
	assert_false(site.is_active(), "no site before village_open")
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"workshop_open", true)
	site.refresh()
	assert_eq(site.is_active(), not (world.get_node("Systems/Workshop") as Workshop).is_built(&"pult"), "site while the pult is not built")
	GameState.set_flag(&"village_open", false)
	GameState.set_flag(&"workshop_open", false)


# --- helpers ----------------------------------------------------------------------------------

func _aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _in_frustum(aabb: AABB, planes: Array[Plane]) -> bool:
	for plane: Plane in planes:
		var all_out := true
		for i: int in 8:
			if not plane.is_point_over(aabb.get_endpoint(i)):
				all_out = false
				break
		if all_out:
			return false
	return true


func _capsule_free(p: Vector3) -> bool:
	var capsule := world.get_player().get_node("Collision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.collision_mask = 1
	query.exclude = [world.get_player().get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.1, 0)) * capsule.transform
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
