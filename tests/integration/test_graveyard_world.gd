extends TestCase
## W1: the generated world graveyard.tscn (§4) – contract nodes, every layout id, waypoints,
## colliders, unique save ids, the carter walking data/npc/carter_schedule.tres, the
## time-driven atmosphere, flat ground under plots and the player's belt lantern.
## Phase 3 (docs/PHASE3_DESIGN.md §4, §10, W-Welt): 12 plots in 3 sections, every obstacle /
## tending spot / system node, no obstacle on a station or the path, the build mask matches
## the layout, passages walkable once cleared, bounds + extra_walls, camera bounds.
## Phase 4 (docs/PHASE4_DESIGN.md §4, §10): 18 plots, the Holunderwinkel (gate, pits, thickets,
## elders), the Phase-4 system nodes, Ilse (npc_trader) with her waypoints and lantern, the
## props, the door note, build mask index 4, the gate walkable once opened.
## Phase 5 (docs/PHASE5_DESIGN.md §4, §10): the workyard next to the hut (build sites, stations,
## wood pile V1, forge glow), the layout diff against layout_p4.json, the route flood fill, the
## camera line of sight to every station, Am Bruch / Schlag / elder gather nodes, the build mask.

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
const BUILD_MASK := "res://src/world/graveyard/build_mask.res"
const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Phase3 := preload("res://src/world/graveyard/graveyard_build_phase3.gd")
## Systems/<name>: [class, identity group, save_id ("" = not saved), save_order] (§3.1).
const P3_SYSTEMS := {
	"Expansion": ["ExpansionManager", "expansion", "expansion", 5],
	"Cleanliness": ["CleanlinessManager", "cleanliness", "cleanliness", 12],
	"Decorations": ["DecorationManager", "decorations", "decorations", 15],
	"BuildMode": ["BuildMode", "build_mode", "", 0],
	"GrassClearMask": ["GrassClearMask", "", "", 0],
	"CemeteryScore": ["CemeteryScore", "cemetery_score", "", 0],
	"Reputation": ["Reputation", "reputation", "", 0],
	"Ghosts": ["GhostManager", "ghosts", "ghosts", 30],
}

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
			"Player", "CameraRig", "CameraRig/Camera3D", "UI",
			"Decor/Placed", "Decor/Ghosts", "Decor/Birches", "Entities/notice_board"]:
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
		assert_eq(plot.section_id, StringName(p.section), p.id + " section")
		var want := GraveRecord.State.EMPTY if p.section == "yard" else GraveRecord.State.LOCKED
		assert_eq(world.graveyard.get_grave(p.id).state, want, p.id + " state at the start")
		assert_true(_section_rect(p.section).has_point(_v2(p.pos)), p.id + " inside its section")
	assert_eq(layout.plots.size(), 18, "plot_01..plot_12 + h_01..h_06 (Phase 4)")
	for i: int in range(1, 7):
		assert_has(world.graveyard.plots_in_section(&"yard"), "plot_%02d" % i)
	assert_eq(world.graveyard.plots_in_section(&"east"), PackedStringArray(["plot_07", "plot_08", "plot_09"]))
	assert_eq(world.graveyard.plots_in_section(&"north"), PackedStringArray(["plot_10", "plot_11", "plot_12"]))
	assert_eq(world.graveyard.plots_in_section(&"elder"), PackedStringArray(["h_01", "h_02", "h_03", "h_04", "h_05", "h_06"]))
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
	var deep := load("res://data/atmosphere/deep_night.tres") as AtmospherePreset
	# Phase 3 §2.8: deep night 22:30–03:00 between the approved night keyframes.
	assert_eq(layout.atmosphere.blend_presets, ["deep_night", "deep_night", "night", "dawn", "day", "day", "dusk", "night", "deep_night"])
	assert_eq(layout.atmosphere.blend_minutes, [0, 180, 270, 330, 480, 1020, 1140, 1260, 1350])
	var sun := world.get_node("Sun") as DirectionalLight3D
	TimeManager.load_state({"day": 1, "minute_of_day": 720})
	await tree.process_frame
	assert_almost(sun.light_energy, day.sun_energy, 0.001, "noon = day preset (hold keyframes)")
	TimeManager.load_state({"day": 1, "minute_of_day": 1260})
	await tree.process_frame
	assert_almost(sun.light_energy, night.sun_energy, 0.001, "21:00 = night")
	var lantern := world.get_player().find_child("Lantern", true, false) as OmniLight3D
	assert_almost(lantern.get_meta("scale", 0.0), night.warm_light_scale, 0.001, "belt lantern scaled by the atmosphere")
	for minute: int in [1380, 30, 180]:
		TimeManager.load_state({"day": 1, "minute_of_day": minute})
		await tree.process_frame
		assert_almost(sun.light_energy, deep.sun_energy, 0.001, "%02d:%02d = deep night" % [minute / 60, minute % 60])
	TimeManager.load_state({"day": 1, "minute_of_day": 270})
	await tree.process_frame
	assert_almost(sun.light_energy, night.sun_energy, 0.001, "04:30 = night again")


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
	# Stations: the collider footprint is flat (Phase 3 re-export: the moved workbench too).
	for id: String in ["morgue_table", "workbench", "dropoff"]:
		var station := world.get_node_by_layout_id(id) as Node3D
		var box: Array = layout.colliders[{"morgue_table": "ph_prop_morgue_table", "workbench": "ph_prop_workbench",
				"dropoff": "ph_prop_dropoff_bier"}[id]][0].size
		var heights: Array[float] = []
		for sx: float in [-0.5, 0.0, 0.5]:
			for sz: float in [-0.5, 0.0, 0.5]:
				var w := station.global_transform * Vector3(sx * float(box[0]), 0, sz * float(box[2]))
				heights.append(world.ground_height(Vector2(w.x, w.z)))
		assert_true(heights.max() - heights.min() < FLAT_TOLERANCE, "%s on flat ground (%.4f m)" % [id, heights.max() - heights.min()])


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
	SaveManager.save_dir = TestCase.user_dir("test_saves")  # per process: parallel runs share user://
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
	TestCase.remove_user_dir(SaveManager.save_dir)


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
			"res_wood", "res_stone", "hut_door", "dropoff", "plot_07", "plot_08", "plot_09", "plot_10", "plot_11", "plot_12"]:
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


# --- Phase 3 (docs/PHASE3_DESIGN.md §3.1, §4, §10) -------------------------------------------

## §3.1: every system node with its class, groups and save_id / save_order; containers.
func test_phase3_system_nodes() -> void:
	for node_name: String in P3_SYSTEMS:
		var want: Array = P3_SYSTEMS[node_name]
		var node := world.get_node_or_null("Systems/" + node_name)
		assert_not_null(node, "Systems/" + node_name)
		if node == null:
			continue
		assert_eq(node.get_script().get_global_name(), want[0], node_name)
		if want[1] != "":
			assert_true(node.is_in_group(StringName(want[1])), "%s in group %s" % [node_name, want[1]])
		if want[2] != "":
			assert_true(node.is_in_group(&"saveable"), node_name + " saveable")
			assert_eq([node.get("save_id"), node.get("save_order")], [want[2], want[3]], node_name + " save id / order")
		else:
			assert_false(node.is_in_group(&"saveable"), node_name + " derived, not saved")
	assert_eq(world.get_node("Systems").get_child(0).name, "Expansion", "§3.1 order: Expansion first")
	var ids: Array = []
	for n: Node in SaveStateCollector.saveables(tree):
		if world.get_node("Systems").is_ancestor_of(n):
			ids.append(String(n.get("save_id")))
	assert_eq(ids, ["corpse_manager", "expansion", "graveyard", "cleanliness", "decorations", "gathering", "ghosts", "workshop",
			"stonemasonry", "journal", "night_trade"],
			"load order (Phase 4: + journal 40, night_trade 45; Phase 5: + gathering 25, workshop 30, stonemasonry 35)")
	var decorations := world.get_node("Systems/Decorations") as DecorationManager
	assert_eq(decorations.mask.resource_path, BUILD_MASK)
	assert_eq(decorations.get_node(decorations.container_path), world.get_node("Decor/Placed"))
	assert_eq((world.get_node("Systems/GrassClearMask") as GrassClearMask).mask, decorations.mask)
	var ghosts := world.get_node("Systems/Ghosts") as GhostManager
	assert_eq(ghosts.get_node(ghosts.container_path), world.get_node("Decor/Ghosts"))
	assert_eq(ghosts.ghost_scene.resource_path, "res://src/entities/ghost/ghost.tscn")
	# Sections: only the yard is open, the Ostwiese is workable, the Birkenhang waits for it.
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	assert_true(expansion.is_unlocked(&"yard"))
	assert_false(expansion.is_unlocked(&"east"))
	assert_false(expansion.is_unlocked(&"north"))
	assert_eq(expansion.block_reason(&"east"), "")
	assert_ne(expansion.block_reason(&"north"), "")


## 35 obstacles (Ostwiese 10, Birkenhang 11, Holunderwinkel 10; Phase 5: Ostpforte + 3 boulders) with model,
## collision and footprint in their
## section; none on a station, a plot of the old yard, the path or a waypoint.
func test_phase3_obstacles() -> void:
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	var all := Phase3.obstacles(layout)
	assert_eq(all.size(), 35)
	var kinds := {}
	for o: Dictionary in all:
		var node := world.get_node_or_null("Entities/" + String(o.id)) as ClearableObstacle
		assert_not_null(node, o.id)
		if node == null:
			continue
		assert_eq([node.obstacle_id, node.section_id, node.kind], [o.id, StringName(o.section), StringName(o.kind)], o.id)
		_assert_at(node, _v2(o.pos), o.id)
		assert_true(_section_rect(o.section).grow(0.05).has_point(_v2(o.pos)), o.id + " inside its section")
		assert_true(expansion.obstacle(o.id) == node, o.id + " known to the ExpansionManager")
		assert_false(node.cleared, o.id + " stands at the start")
		assert_true((node.get_node("Model") as Node3D).visible, o.id + " model")
		var body := node.get_node("Collision") as StaticBody3D
		assert_eq(body.collision_layer, 1, o.id)
		for shape: Node in body.get_children():
			assert_false((shape as CollisionShape3D).disabled, o.id + " blocks while standing")
		if o.kind == "fence_gap":
			assert_false((node.get_node("Repaired") as Node3D).visible, o.id + " repaired fence hidden")
			for shape: Node in node.get_node("RepairedCollision").get_children():
				assert_true((shape as CollisionShape3D).disabled, o.id + " repaired collision off")
		var key := "%s/%s" % [o.section, o.kind]
		kinds[key] = int(kinds.get(key, 0)) + 1
		var rect := node.world_rect()
		for ent: Dictionary in layout.entities:
			if ent.type != "npc":
				assert_false(rect.grow(0.6).has_point(_v2(ent.pos)), "%s clear of %s" % [o.id, ent.id])
		for p: Dictionary in layout.plots.filter(func(pl: Dictionary) -> bool: return pl.section == "yard") + layout.old_graves:
			assert_false(rect.grow(1.0).has_point(_v2(p.pos)), "%s clear of %s" % [o.id, p.id])
		for id: String in layout.waypoints:
			if not id.begins_with("_"):
				assert_false(rect.grow(0.5).has_point(_v2(layout.waypoints[id])), "%s clear of waypoint %s" % [o.id, id])
		for k: int in 60:
			assert_false(rect.has_point(_on_polyline(layout.path.points, k / 59.0)), o.id + " off the earth path")
	assert_eq(kinds, {"east/bramble": 4, "east/rubble": 3, "east/fence_gap": 3, "north/hedge": 1, "north/bramble": 3,
			"north/rubble": 2, "north/stump": 2, "north/fence_gap": 3,
			"elder/gate_small": 1, "elder/elder_thicket": 2, "elder/sunken_pit": 6, "elder/fence_gap": 1,
			"bruch/gate_east": 1, "quarry/boulder": 3})
	assert_eq(expansion.progress(&"east"), Vector2i(0, 10))
	assert_eq(expansion.progress(&"north"), Vector2i(0, 11))
	assert_eq(expansion.progress(&"elder"), Vector2i(0, 10))
	assert_true((world.get_node("Entities/obs_e_01") as ClearableObstacle).world_rect().grow(0.3).has_point(Vector2(11.5, -2.2)),
			"the bramble obs_e_01 blocks the passage")


## §2.4: 22 area spots (yard 12 with 4 leaves under the oak, east 5, north 5 with 2 leaves) +
## one weeds spot per plot on its mound = 34; Phase 4 §4.1: + 3 in the Holunderwinkel (2 leaves
## under the elders) + 6 graves = 43; a new game's start values only in the yard.
func test_phase3_tending_spots() -> void:
	var clean := world.get_node("Systems/Cleanliness") as CleanlinessManager
	assert_eq(clean.spot_ids().size(), 43)
	var counts := {}
	var started := 0
	for d: Dictionary in layout.dirt_spots:
		var spot := world.get_node_or_null("Entities/" + String(d.id)) as DirtSpot
		assert_not_null(spot, d.id)
		if spot == null:
			continue
		assert_eq([spot.spot_id, spot.section_id, spot.kind, spot.grave_id], [d.id, StringName(d.section), StringName(d.kind), ""], d.id)
		assert_almost(spot.start_progress, float(d.start), 0.0001, d.id)
		_assert_at(spot, _v2(d.pos), d.id)
		assert_almost(spot.global_position.y, world.ground_height(_v2(d.pos)), 0.01, d.id + " on the ground")
		assert_true(_section_rect(d.section).has_point(_v2(d.pos)), d.id + " inside its section")
		var key := "%s/%s" % [d.section, d.kind]
		counts[key] = int(counts.get(key, 0)) + 1
		if float(d.start) > 0.0:
			started += 1
			assert_eq(d.section, "yard", d.id)
			assert_eq(d.kind, "weeds", d.id + ": no rake on day 1")
			assert_true(float(d.start) >= 1.2 and float(d.start) <= 2.4, d.id + " level 1–2")
	assert_eq(counts, {"yard/weeds": 8, "yard/leaves": 4, "east/weeds": 5, "north/weeds": 3, "north/leaves": 2,
			"elder/weeds": 1, "elder/leaves": 2})
	assert_eq(started, 6, "§1.3 day 1: six spots in the old yard")
	for p: Dictionary in layout.plots:
		var spot := world.get_node_or_null("Entities/dirt_" + String(p.id)) as DirtSpot
		assert_not_null(spot, "dirt_" + p.id)
		if spot == null:
			continue
		assert_eq([spot.grave_id, spot.section_id, spot.kind], [p.id, StringName(p.section), &"weeds"], spot.name)
		assert_eq((spot.get_node("Interactable") as Interactable).priority, int(layout.grave_dirt.priority), spot.name + " wins over the grave info")
		var plot := world.get_node_by_layout_id(p.id) as GravePlot
		var local := plot.to_local(spot.global_position)
		assert_true(plot.footprint.has_point(Vector2(local.x, local.z)), spot.name + " on the plot")
		assert_true(local.y > 0.1 and local.y < 0.45, "%s on the mound (%.2f m)" % [spot.name, local.y])


## §4.3: the baked mask has the contract size and matches a fresh bake of the layout; spot
## checks for sections, blocked plots / stations / trees / fence, grave ring and routes.
func test_phase3_build_mask_matches_layout() -> void:
	var mask := load(BUILD_MASK) as BuildMask
	assert_eq([mask.origin, mask.size, mask.cell], [Vector2(-11.5, -20.0), Vector2i(66, 60), 0.5])
	assert_eq(mask.cells.size(), 66 * 60)
	var ctx := Ctx.new(tree)
	ctx.layout = layout
	var shapes := Phase3.mask_shapes(ctx)
	var diff := 0
	var per_section := {}
	for cz: int in mask.size.y:
		for cx: int in mask.size.x:
			var c := Vector2i(cx, cz)
			var p := mask.cell_to_world(c)
			if Phase3.mask_value(p, mask.cell * 0.5, shapes) != mask.flags_at(c):
				diff += 1
			var s := mask.section_at(c)
			per_section[s] = int(per_section.get(s, 0)) + 1
			if s != 0:
				assert_true(_section_rect(["", "yard", "east", "north", "elder"][s]).has_point(p), "cell %s in section %d" % [c, s])
	assert_eq(diff, 0, "build_mask.res is up to date with the layout (rebuild graveyard.tscn)")
	for s: int in [1, 2, 3]:
		assert_true(int(per_section.get(s, 0)) > 200, "section %d buildable cells: %d" % [s, per_section.get(s, 0)])
	assert_true(int(per_section.get(4, 0)) > 40, "Holunderwinkel (index 4) buildable cells: %d" % per_section.get(4, 0))
	for p: Dictionary in layout.plots + layout.old_graves:
		assert_eq(mask.flags_at(mask.world_to_cell(_v2(p.pos))), BuildMask.BLOCKED, p.id + " blocked")
	for p: Dictionary in layout.plots:
		var plot := world.get_node_by_layout_id(p.id) as GravePlot
		var ring_cells := 0
		var centre := mask.world_to_cell(_v2(p.pos))
		for dz: int in range(-5, 6):
			for dx: int in range(-4, 6):
				var c := centre + Vector2i(dx, dz)
				var local := plot.to_local(Vector3(mask.cell_to_world(c).x, 0, mask.cell_to_world(c).y))
				if mask.flags_at(c) & BuildMask.GRAVE_RING:
					ring_cells += 1
					assert_false(plot.footprint.has_point(Vector2(local.x, local.z)), "%s: ring cell %s not on the plot" % [p.id, c])
		assert_true(ring_cells >= 6, "%s grave ring (%d cells)" % [p.id, ring_cells])
		var foot := plot.global_transform * Vector3(0, 0, plot.footprint.end.y + 0.55)
		assert_true(mask.flags_at(mask.world_to_cell(Vector2(foot.x, foot.z))) & BuildMask.ROUTE, p.id + " foot-end strip")
	for p: Vector2 in [Vector2(0.0, 4.0), Vector2(-0.8, 0.5), Vector2(10.8, -2.2), Vector2(12.3, -2.2), Vector2(4.5, -12.2)]:
		assert_true(mask.flags_at(mask.world_to_cell(p)) & BuildMask.ROUTE, "route at %s" % p)
	for p: Vector2 in [_v2(layout.hut.pos), _v2(layout.tree.pos), Vector2(16.0, 9.5), Vector2(21.3, 2.0), Vector2(1.0, -11.9),
			_v2(layout.birches[1].pos), _v2(layout.notice_board.pos)]:
		assert_eq(mask.flags_at(mask.world_to_cell(p)), BuildMask.BLOCKED, "blocked at %s" % p)
	for ent: Dictionary in layout.entities:
		if ent.type != "npc":
			assert_eq(mask.flags_at(mask.world_to_cell(_v2(ent.pos))), BuildMask.BLOCKED, ent.id + " blocked")
	# Obstacles are not baked (runtime blockers): their centres keep their section.
	assert_eq(mask.section_at(mask.world_to_cell(Vector2(19.4, 2.4))), 2, "obs_e_03 not baked")
	assert_eq(mask.section_at(mask.world_to_cell(Vector2(9.6, -14.0))), 3, "obs_n_05 not baked")


## The passage into the Ostwiese and the hedge gap into the Birkenhang let the gravekeeper
## through once cleared; repaired fence gaps stay closed; the tp waypoints are free.
func test_phase3_passages_walkable_once_cleared() -> void:
	await tree.physics_frame
	await tree.physics_frame
	var passage := [Vector2(10.4, -2.2), Vector2(11.5, -2.2), Vector2(12.6, -2.2)]
	var hedge := [Vector2(4.5, -11.2), Vector2(4.5, -12.4), Vector2(4.5, -13.6)]
	assert_false(_capsule_free(passage[2]), "bramble obs_e_01 blocks the passage")
	assert_false(_capsule_free(hedge[1]), "the thorn hedge blocks the Birkenhang")
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	assert_true(expansion.unlock(&"east"))
	assert_true(expansion.unlock(&"north"))
	for i: int in 3:
		await tree.physics_frame
	for p: Vector2 in passage + hedge:
		assert_true(_capsule_free(p), "walkable at %s once cleared" % p)
	for r: Dictionary in layout.fence.ruins:
		assert_false(_capsule_free(_v2(r.pos)), "%s repaired: the fence is closed" % r.obstacle)
	for id: String in ["tp_east", "tp_north"]:
		assert_true(_capsule_free(_v2(layout.waypoints[id])), id + " free")
	for id: String in ["plot_07", "plot_10"]:
		assert_eq(world.graveyard.get_grave(id).state, GraveRecord.State.EMPTY, id + " unlocked")


## §4.1: walkable bounds + the extra wall (Phase 4: the one behind the hut is the Holunderwinkel's
## fence now), camera bounds, trees moved out of the sections. Phase 5 §4.5: bounds, camera and
## ground reach Am Bruch (x 31,2 / 27 / 40), two more walls (hedge south, quarry north).
func test_phase3_bounds_and_camera() -> void:
	var wb: Dictionary = layout.walkable_bounds
	assert_eq([wb.min, wb.max], [[-11.2, -20.3], [31.2, 25.2]])
	var bounds := world.get_node("Colliders/Bounds")
	var t := float(wb.wall_thickness)
	assert_almost((bounds.get_node("East") as Node3D).position.x, 31.2 + t * 0.5, 0.001)
	assert_almost((bounds.get_node("North") as Node3D).position.z, -20.3 - t * 0.5, 0.001)
	assert_true(bounds.has_node("Extra_1"), "extra wall east of the road")
	assert_true(bounds.has_node("Extra_2") and bounds.has_node("Extra_3"), "Phase 5: hedge south / quarry north of Am Bruch")
	assert_false(bounds.has_node("Extra_4"), "Phase 4: no invisible wall behind the hut")
	for k: int in [2, 3]:
		assert_true((bounds.get_node("Extra_%d" % k) as Node3D).position.x > 21.5, "Extra_%d lies at Am Bruch" % k)
	await tree.physics_frame
	await tree.physics_frame
	var space := world.get_world_3d().direct_space_state
	for ray: Array in [[Vector3(-6.0, 1.0, -11.0), Vector3(-6.0, 1.0, -14.0)], [Vector3(9.5, 1.0, 16.0), Vector3(13.0, 1.0, 16.0)]]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[1], 1))
		assert_false(hit.is_empty(), "wall / fence between %s and %s" % ray)
	var rig := world.get_node("CameraRig") as CameraRig
	assert_eq([rig.bounds_min, rig.bounds_max], [Vector2(-10.0, -17.5), Vector2(27.0, 23.0)],
			"Phase 4 §4.1: min → (−10, −17.5); Phase 5 §4.5: max x → 27")
	assert_eq([rig.zoom_min, rig.zoom_max], [12.0, 24.0])
	for tr: Dictionary in layout.background_trees + layout.forest.trees:
		for s: Dictionary in layout.sections:
			assert_false(_section_rect(s.id).grow(0.5).has_point(_v2(tr.pos)), "tree %s outside section %s" % [tr.pos, s.id])
	var inside := 0
	for b: Dictionary in layout.birches:
		if _section_rect("north").has_point(_v2(b.pos)):
			inside += 1
	assert_eq([layout.birches.size(), inside], [6, 2], "6 birches, 2 in the Birkenhang")
	assert_eq(world.get_node("Decor/Birches").get_child_count(), 6)
	assert_true(world.has_node("Colliders/Birch_01"))
	# The ground covers the camera's view: 64 × 64 m (Phase 5 §4.5), south / west / north edge unchanged.
	assert_eq([layout.ground.size, layout.ground.center], [[64.0, 64.0], [8.0, 2.5]])
	var shape := world.get_node("GroundCollision/Shape") as CollisionShape3D
	var hm := shape.shape as HeightMapShape3D
	var cell := float(layout.ground.cell)
	var lo := Vector2(shape.position.x, shape.position.z) - Vector2(hm.map_width - 1, hm.map_depth - 1) * cell * 0.5
	var hi := lo + Vector2(hm.map_width - 1, hm.map_depth - 1) * cell
	assert_almost(lo.x, -24.0, 0.2, "west edge")
	assert_almost(hi.x, 40.0, 0.2, "east edge")
	assert_almost(lo.y, -29.5, 0.2, "north edge")
	assert_almost(hi.y, 34.5, 0.2, "south edge")


## §4.1: the notice board at the gate shows the cemetery rating and the reputation.
func test_phase3_notice_board() -> void:
	var board := world.get_node("Entities/notice_board") as NoticeBoard
	_assert_at(board, _v2(layout.notice_board.pos), "notice board")
	assert_eq(board.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_notice_board.glb")
	assert_true(world.has_node("Colliders/notice_board"))
	assert_not_null(board.label)
	var score := world.get_node("Systems/CemeteryScore") as CemeteryScore
	var rep := world.get_node("Systems/Reputation") as Reputation
	assert_eq(board.label.text, NoticeBoard.board_text(score.rating(), rep.tier()))
	rep.change(60 - rep.value(), "test")
	assert_true(board.label.text.contains("Ruf: Geschätzt"), board.label.text)
	assert_true(board.label.text.contains("„Verwahrlost“"), board.label.text)


# --- Phase 4 (docs/PHASE4_DESIGN.md §3.1, §4, §10 test_graveyard_world) ----------------------

## §3.1: CorpseCare, Piety (derived), Journal (journal / 40), NightTrade (night_trade / 45).
func test_phase4_system_nodes() -> void:
	var want := {
		"CorpseCare": ["CorpseCare", "corpse_care", "", 0],
		"Piety": ["Piety", "piety", "", 0],
		"Journal": ["JournalManager", "journal", "journal", 40],
		"NightTrade": ["NightTrade", "night_trade", "night_trade", 45],
	}
	for node_name: String in want:
		var w: Array = want[node_name]
		var node := world.get_node_or_null("Systems/" + node_name)
		assert_not_null(node, "Systems/" + node_name)
		if node == null:
			continue
		assert_eq(node.get_script().get_global_name(), w[0], node_name)
		assert_true(node.is_in_group(StringName(w[1])), "%s in group %s" % [node_name, w[1]])
		if w[2] != "":
			assert_true(node.is_in_group(&"saveable"), node_name + " saveable")
			assert_eq([node.get("save_id"), node.get("save_order")], [w[2], w[3]], node_name)
		else:
			assert_false(node.is_in_group(&"saveable"), node_name + " not saved")
	var npc := world.get_node_by_layout_id("npc_trader") as Npc
	assert_not_null(npc, "Entities/npc_trader")
	assert_eq([npc.save_id, npc.save_order, npc.npc_id], ["npc_trader", 20, &"trader"])
	assert_true(npc.is_in_group(&"saveable"))
	var state := SaveManager.collect_state()
	for id: String in SaveMigration.V3_EMPTY_NODES:
		assert_true((state.nodes as Dictionary).has(id), "saved state of " + id)


## §4.1: section elder (index 4, locked by the key), 6 LOCKED plots under 6 sunken pits, the gate
## in the fence behind the hut, two thickets, the gap in the north fence – 300 minutes of work.
func test_phase4_holunderwinkel_layout() -> void:
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	var elder := expansion.section(&"elder")
	assert_not_null(elder)
	assert_eq([elder.order, elder.counts_for_cemetery, elder.chapter], [4, false, &"six_pits"])
	assert_false(expansion.is_unlocked(&"elder"))
	assert_eq(expansion.block_reason(&"elder"), "Das Pförtchen ist verschlossen.")
	var ids := expansion.obstacle_ids(&"elder")
	assert_eq(ids.size(), 10, "1 gate, 2 thickets, 6 pits, 1 fence gap")
	var minutes := 0
	var cost := {}
	for id: String in ids:
		var data := expansion.data_of(id)
		minutes += data.minutes
		for item: StringName in data.cost:
			cost[item] = int(cost.get(item, 0)) + data.cost[item]
		var node := expansion.obstacle(id)
		assert_not_null(node.get_node_or_null("Model"), id + " model")
		assert_eq(node.get_node("Model").scene_file_path, data.model.resource_path, id + " model = ClearableData.model")
	assert_eq(minutes, 300, "§2.10: 300 minutes of clearing")
	assert_eq(cost, {&"wood": 2, &"iron_fittings": 1})
	for i: int in 6:
		var plot_id := "h_%02d" % (i + 1)
		assert_eq(world.graveyard.get_grave(plot_id).state, GraveRecord.State.LOCKED, plot_id)
		var pit := expansion.obstacle("obs_h_pit_%d" % (i + 1))
		var plot := world.get_node_by_layout_id(plot_id) as GravePlot
		assert_eq(pit.kind, &"sunken_pit")
		_assert_at(pit, Vector2(plot.global_position.x, plot.global_position.z), "pit over " + plot_id)
		assert_eq(pit.footprint, plot.footprint, plot_id + ": pit footprint = the plot")
	assert_eq(expansion.obstacle("obs_h_gate").kind, &"gate_small")
	assert_eq(world.get_node("Decor/ElderBushes").get_child_count(), 3, "three large elders")
	for k: int in [1, 2, 3]:
		assert_true(world.has_node("Colliders/ElderBush_%d" % k), "elder trunk %d collides" % k)
	var bush_over_gate := false
	for b: Node in world.get_node("Decor/ElderBushes").get_children():
		if _flat((b as Node3D).global_position - expansion.obstacle("obs_h_gate").global_position).length() < 2.5:
			bush_over_gate = true
	assert_true(bush_over_gate, "an elder over the gate")
	assert_true(world.has_node("Decor/Overgrowth/elder"), "overgrowth while locked")
	assert_eq(_waypoint_ids_missing(["tp_elder", "trader_far", "trader_mid", "trader_spot"]), [])


## §4.1: the closed gate blocks; with the key it opens (open model, no collision) and the
## gravekeeper walks through; the whole corner becomes walkable once cleared.
func test_phase4_gate_opens_with_the_key() -> void:
	await tree.physics_frame
	await tree.physics_frame
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	var inv := world.get_player().inventory
	var gate := expansion.obstacle("obs_h_gate")
	var through := [Vector2(-10.0, -12.0), Vector2(-10.0, -12.5), Vector2(-10.0, -13.0)]
	assert_false(_capsule_free(through[1]), "the closed gate blocks")
	assert_false(expansion.can_clear("obs_h_gate", inv), "locked without the key")
	assert_eq(gate.get_interaction_prompt(world.get_player()), "Das Pförtchen ist verschlossen.")
	GameState.set_flag(&"has_elder_key", true)
	assert_eq(expansion.block_reason(&"elder"), "")
	assert_true(expansion.clear("obs_h_gate", inv), "unlocked with the key")
	assert_false((gate.get_node("Model") as Node3D).visible, "closed gate hidden")
	assert_true((gate.get_node("Repaired") as Node3D).visible, "open gate shown")
	assert_eq(gate.get_node("Repaired").scene_file_path, "res://assets/models/props/ph_prop_gate_small_open.glb")
	for i: int in 3:
		await tree.physics_frame
	assert_true(_capsule_free(through[0]) and _capsule_free(through[1]), "walkable through the open gate")
	assert_false(_capsule_free(through[2]), "the thicket still blocks the way in")
	assert_true(expansion.unlock(&"elder"))
	for i: int in 3:
		await tree.physics_frame
	for p: Vector2 in through + [_v2(layout.waypoints.tp_elder), Vector2(-7.75, -16.6), Vector2(-7.75, -13.0)]:
		assert_true(_capsule_free(p), "walkable at %s once cleared" % p)
	assert_false(_capsule_free(Vector2(-7.0, -20.0)), "the repaired gap closes the north fence")
	for i: int in 6:
		assert_eq(world.graveyard.get_grave("h_%02d" % (i + 1)).state, GraveRecord.State.EMPTY)
	assert_false(world.get_node("Decor/Overgrowth/elder").visible, "overgrowth gone")


## §4.2: Ilse walks her schedule from the forest edge to the spot outside the west wall (only
## with trader_known), stands there 23:00–03:00 facing east with her lantern on the wall stone,
## and the gravekeeper can talk to her from inside the wall.
func test_phase4_trader_walks_and_waits_at_the_west_wall() -> void:
	var npc := world.get_node_by_layout_id("npc_trader") as Npc
	var trade := world.get_node("Systems/NightTrade") as NightTrade
	assert_eq(npc.get_node("Model").scene_file_path, "res://assets/models/characters/ph_chr_kranich.glb")
	assert_eq([npc.requires_flag, npc.lantern_marker], [&"trader_known", &"light_lantern"])
	assert_almost(npc.walk_anim_speed, 1.36, 0.001)
	await _at_day(npc, 4, 1410)
	assert_false(npc.visible, "unknown: invisible")
	assert_false(npc.interactable.enabled)
	GameState.set_flag(&"trader_known", true)
	await _at_day(npc, 4, 1370)
	assert_true(npc.visible and npc.is_walking(), "22:50 on her way")
	_assert_xz(npc.global_position, _along(["trader_far", "trader_mid", "trader_spot"], 0.5), "22:50 half way")
	await _at_day(npc, 4, 1410)
	assert_true(npc.visible and npc.is_talkable() and not npc.is_walking(), "23:30 at the wall")
	_assert_xz(npc.global_position, world.get_waypoint(&"trader_spot"), "23:30 trader_spot")
	assert_almost(npc.rotation.y, deg_to_rad(90.0), 0.001, "facing east")
	assert_true(trade.is_present())
	assert_eq(npc.get_interaction_prompt(world.get_player()), "[E] Mit Ilse reden")
	# Lantern: warm, dimmed, no shadow, resting on the wall stone next to her.
	var lantern := npc.lantern()
	assert_not_null(lantern)
	assert_eq(String(lantern.get_parent().name), "light_lantern")
	assert_false(lantern.shadow_enabled, "no shadow")
	assert_false(bool(lantern.get_meta(&"casts_shadow", false)))
	assert_true(lantern.is_in_group(&"warm_lights"))
	# §8 energy 0.4 / 3 m → QA W3 (G4): a warm pool on the ground that reads at night.
	assert_almost(float(lantern.get_meta(&"base_energy", 0.0)), Npc.LANTERN_ENERGY, 0.001, "base energy")
	assert_almost(lantern.omni_range, Npc.LANTERN_RANGE, 0.001)
	var ledge := world.get_node("Decor/Phase4Props/WallLedge") as Node3D
	assert_true(_flat(lantern.global_position - ledge.global_position).length() < 0.3,
			"the lantern rests on the wall stone (%.2f m off)" % _flat(lantern.global_position - ledge.global_position).length())
	var above := lantern.global_position.y - ledge.global_position.y
	assert_true(above > 0.5 and above < 0.8, "just above the stone (%.2f m)" % above)
	# Talk over the wall from inside (x ≈ −10.9), facing west.
	var player := world.get_player()
	var inside := Vector2(-10.85, -2.6)
	assert_true(_capsule_free(inside), "the spot inside the wall is free")
	player.global_position = Vector3(inside.x, world.ground_height(inside), inside.y)
	player.rotation.y = -PI * 0.5
	for i: int in 4:
		await tree.physics_frame
	assert_eq(player.detector.focused, npc.interactable, "Ilse is in reach over the wall")
	await _at_day(npc, 5, 240)
	assert_false(npc.visible, "04:00 gone")
	assert_false(trade.is_present())


## Her way outside the fence needs no collision and never enters the walkable area.
func test_phase4_trader_route_is_outside_and_free() -> void:
	await tree.physics_frame
	await tree.physics_frame
	var wb: Dictionary = layout.walkable_bounds
	var ids := ["trader_far", "trader_mid", "trader_spot"]
	for k: int in 41:
		var p := _along(ids, k / 40.0)
		assert_true(p.x < float(wb.min[0]) - 0.3, "route point %s outside the walkable area" % p)
		# (the last metres lie in the invisible west wall of walkable_bounds – she needs no collision)
		if p.x < float(wb.min[0]) - float(wb.wall_thickness) - 0.4:
			assert_true(_capsule_free(Vector2(p.x, p.z)), "route free at %s" % p)
	for id: String in ids:
		var w := world.get_waypoint(StringName(id))
		assert_almost(w.y, world.ground_height(Vector2(w.x, w.z)), 0.02, id + " on the ground")


## §4.2: wash basin next to the table, smoke bowl on its edge (= where the juniper smoke of a
## corpse on the table rises), the wall stone at Ilse's spot; the door note shows from the note
## until the first meeting.
func test_phase4_props_and_door_note() -> void:
	var table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	var basin := world.get_node("Decor/Phase4Props/WashBasin") as Node3D
	assert_eq(basin.scene_file_path, "res://assets/models/props/ph_prop_wash_basin.glb")
	var d := _flat(basin.global_position - table.global_position).length()
	assert_true(d > 1.1 and d < 1.6, "basin beside the table (%.2f m)" % d)
	assert_true(world.has_node("Colliders/WashBasin"))
	var bowl := table.get_node("SmokeBowl") as Node3D
	assert_eq(bowl.scene_file_path, "res://assets/models/props/ph_prop_smoke_bowl.glb")
	var marker := bowl.find_child("smoke", true, false) as Node3D
	var probe := CorpseDecayVisual.new()
	var smoke_at := table.slot_node().global_transform * probe.smoke_node.position
	probe.free()
	assert_true(_flat(marker.global_position - smoke_at).length() < 0.02, "the smoke rises from the bowl")
	assert_true(absf(marker.global_position.y - smoke_at.y) < 0.05, "at the bowl's rim (%.3f m)" % (marker.global_position.y - smoke_at.y))
	var ledge := world.get_node("Decor/Phase4Props/WallLedge") as Node3D
	_assert_at(ledge, _v2(layout.phase4_props[2].pos), "wall ledge")
	assert_true(ledge.global_position.x < -11.5, "outside the west wall")
	# Door note: on the door leaf, hidden until trader_known, gone after the first meeting.
	var note := world.get_node("Decor/DoorNote") as Node3D
	var door := world.get_node_by_layout_id("hut_door") as Node3D
	assert_true(_flat(note.global_position - door.global_position).length() < 0.8, "on the hut door")
	assert_false(note.visible, "no note before day 4")
	GameState.set_flag(&"trader_known", true)
	note.call(&"refresh")
	assert_true(note.visible, "the note at the door")
	(world.get_node("Systems/NightTrade") as NightTrade).load_state({"intro_done": true, "tools_given": true})
	note.call(&"refresh")
	assert_false(note.visible, "gone after meeting Ilse")


## §4.3: the Holunderwinkel is index 4 of the build mask, the gate and the strip inside the west
## wall at Ilse's spot are routes, the plots and the basin are blocked.
func test_phase4_build_mask() -> void:
	var mask := load(BUILD_MASK) as BuildMask
	assert_eq(mask.section_at(mask.world_to_cell(Vector2(-7.75, -16.6))), 4, "Holunderwinkel = 4")
	for p: Vector2 in [Vector2(-10.0, -13.2), Vector2(-10.75, -2.6)]:
		assert_true(mask.flags_at(mask.world_to_cell(p)) & BuildMask.ROUTE, "route at %s" % p)
	for i: int in 6:
		assert_eq(mask.flags_at(mask.world_to_cell(_v2(layout.plots[12 + i].pos))), BuildMask.BLOCKED, "h_%02d blocked" % (i + 1))
	assert_eq(mask.flags_at(mask.world_to_cell(_v2(layout.phase4_props[0].pos))), BuildMask.BLOCKED, "wash basin blocked")


# --- Phase 5 (docs/PHASE5_DESIGN.md §3.1, §4, §9, §10 test_graveyard_world) ------------------

## §3.1: Gathering (25), Workshop (30), Stonemasonry (35) under Systems; the Workshop knows the
## workyard rects of the layout (decor eviction, §5.2 step 5).
func test_phase5_system_nodes() -> void:
	var want := {
		"Gathering": ["GatherManager", "gathering", "gathering", 25],
		"Workshop": ["Workshop", "workshop", "workshop", 30],
		"Stonemasonry": ["Stonemasonry", "stonemasonry", "stonemasonry", 35],
	}
	for node_name: String in want:
		var w: Array = want[node_name]
		var node := world.get_node_or_null("Systems/" + node_name)
		assert_not_null(node, "Systems/" + node_name)
		if node == null:
			continue
		assert_eq(node.get_script().get_global_name(), w[0], node_name)
		assert_true(node.is_in_group(StringName(w[1])), "%s in group %s" % [node_name, w[1]])
		assert_true(node.is_in_group(&"saveable"), node_name + " saveable")
		assert_eq([node.get("save_id"), node.get("save_order")], [w[2], w[3]], node_name)
	var shop := world.get_node("Systems/Workshop") as Workshop
	var rects: Array[Rect2] = []
	for r: Array in layout.workyard.blocked_rects:
		rects.append(Rect2(r[0], r[1], r[2], r[3]))
	assert_eq(shop.workyard_rects, rects, "Workshop.workyard_rects = layout.workyard.blocked_rects")
	var state := SaveManager.collect_state()
	for id: String in SaveMigration.V4_EMPTY_NODES:
		assert_true((state.nodes as Dictionary).has(id), "saved state of " + id)


## §4.1: three build sites (staked plot stretched to the footprint, hidden before workshop_open)
## and at the same spot the stations (Workbench, requires_built, their model, hidden until built);
## the wood pile moved (V1); the footprints and margins cover the workyard rects.
func test_phase5_workyard_sites_and_stations() -> void:
	var shop := world.get_node("Systems/Workshop") as Workshop
	var sites: Array[BuildSite] = []
	var stations: Array[Workbench] = []
	for site: Dictionary in layout.workyard.build_sites:
		var node := world.get_node_or_null("Entities/" + String(site.id)) as BuildSite
		assert_not_null(node, site.id)
		if node == null:
			continue
		sites.append(node)
		_assert_at(node, _v2(site.pos), site.id)
		assert_true(node.global_basis.is_equal_approx(Basis(Vector3.UP, deg_to_rad(float(site.rot_y)))), site.id + " rotation")
		assert_eq(node.station_id, StringName(site.station), site.id)
		assert_eq((Database.station(StringName(site.station)) as StationData).site_id, String(site.id), site.id + " = StationData.site_id")
		var model := node.get_node("Model") as Node3D
		assert_eq(model.scene_file_path, "res://assets/models/props/ph_prop_build_site.glb", site.id)
		assert_not_null(model.find_child("stakes", true, false), site.id + " stakes")
		var fp: Array = site.footprint
		assert_almost(model.scale.x * 2.35, float(fp[2]), 0.02, site.id + " stretched to the footprint (x)")
		assert_almost(model.scale.z * 1.8, float(fp[3]), 0.02, site.id + " stretched to the footprint (z)")
		assert_false(node.is_active() or node.visible, site.id + " hidden before workshop_open")
		var station := world.get_node_or_null("Entities/station_" + String(site.station)) as Workbench
		assert_not_null(station, "station_" + String(site.station))
		if station == null:
			continue
		stations.append(station)
		assert_true(station.requires_built, station.name)
		assert_eq(station.station, StringName(site.station), station.name)
		assert_true(station.global_transform.is_equal_approx(node.global_transform), station.name + " on its build site")
		assert_false(station.visible, station.name + " hidden until built")
		assert_eq(station.process_mode, Node.PROCESS_MODE_DISABLED, station.name + " without collision until built")
		var want_model := "res://assets/models/buildings/ph_bld_%s.glb" % ("mason_bench" if site.station == "mason" else String(site.station))
		assert_eq(station.get_node("Model").scene_file_path, want_model, station.name)
		# The workyard rect of the site covers footprint + margin (decor there is cleared on load).
		var world_fp := _world_rect(node, Rect2(fp[0], fp[1], fp[2], fp[3]).grow(float(layout.build.station_margin)))
		assert_true(shop.workyard_rects.any(func(r: Rect2) -> bool: return r.grow(0.01).encloses(world_fp)),
				site.id + " footprint + margin inside a workyard rect")
	_assert_at(world.get_node_by_layout_id("res_wood") as Node3D, Vector2(0.3, -7.8), "V1: the wood pile moved")
	GameState.set_flag(&"workshop_open", true)
	for node: BuildSite in sites:
		node.refresh()
		assert_true(node.visible and node.is_active(), node.name + " shows from workshop_open")
	shop.load_state({"built": ["mason", "loom", "forge"]})
	for station: Workbench in stations:
		station.refresh_built()
		assert_true(station.visible, station.name + " built")
		assert_eq(station.process_mode, Node.PROCESS_MODE_INHERIT)
		assert_ne(station.get_interaction_prompt(world.get_player()), "", station.name + " prompt")
	for node: BuildSite in sites:
		node.refresh()
		assert_false(node.visible, node.name + " replaced by its station")
	var rack := world.get_node("Entities/station_mason/StoneRack")
	assert_not_null(rack, "the mason's stone rack")
	for k: int in [1, 2, 3]:
		assert_not_null(world.get_node("Entities/station_mason/Model").find_child("stone_slot_%d" % k, true, false), "stone_slot_%d" % k)


## §4.1 / §9: the forge glow – one OmniLight #E07A3A, 0.5, 3.5 m, no shadow, warm_lights, only
## when built, out of reach of the Holunderwinkel graves; chimney and kiln smoke 3 particles each.
func test_phase5_forge_light_and_smoke() -> void:
	var forge := world.get_node("Entities/station_forge") as Workbench
	var lights := forge.find_children("*", "OmniLight3D", true, false)
	assert_eq(lights.size(), 1, "one glow light")
	var light := lights[0] as OmniLight3D
	assert_false(light.shadow_enabled, "no shadow")
	assert_false(bool(light.get_meta(&"casts_shadow", false)))
	assert_almost(light.omni_range, 3.5, 0.001)
	assert_almost(float(light.get_meta(&"base_energy", 0.0)), 0.5, 0.001)
	assert_true(light.light_color.is_equal_approx(Color("e07a3a")), "ember colour")
	assert_true(light.is_in_group(&"warm_lights"))
	var marker := forge.get_node("Model").find_child("light_ember", true, false) as Node3D
	assert_not_null(marker, "light_ember marker")
	if marker != null:
		assert_true(light.global_position.distance_to(marker.global_position) < 0.01, "at the ember marker")
	assert_false(light.is_visible_in_tree(), "dark until the forge is built")
	for p: Dictionary in layout.plots:
		if String(p.section) == "elder":
			var d := _flat(light.global_position - (world.get_node_by_layout_id(p.id) as Node3D).global_position).length()
			assert_true(d > light.omni_range, "the glow stays out of %s (%.2f m)" % [p.id, d])
	var smokes := forge.find_children("*", "CPUParticles3D", true, false)
	assert_eq(smokes.size(), 2, "chimney + kiln")
	for s: Node in smokes:
		var p := s as CPUParticles3D
		assert_eq(p.amount, 3, p.name)
		assert_almost(p.visibility_range_end, 40.0, 0.001, p.name)
		assert_eq(p.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, p.name)
	var kiln := forge.get_node("Kiln") as Node3D
	_assert_at(kiln, _v2(layout.workyard.meiler.pos), "the kiln")
	(world.get_node("Systems/Workshop") as Workshop).load_state({"built": ["forge"]})
	forge.refresh_built()
	assert_true(light.is_visible_in_tree(), "glows once built")
	# Shadow budget (§9): at most 4 omni lights with an authored shadow.
	var shadowed := 0
	for node: Node in world.find_children("*", "OmniLight3D", true, false):
		if (node as OmniLight3D).shadow_enabled or bool(node.get_meta(&"casts_shadow", false)):
			shadowed += 1
	assert_true(shadowed <= 4, "%d shadowed omni lights" % shadowed)


## §10: layout diff against the approved Phase-4 layout (tests/fixtures/phase5/layout_p4.json,
## 69f8d49). In sections I–IV only the listed changes (wood pile V1, the Ostpforte fence pieces, the
## crate moved for the loom), everything else of the old layout identical; the rest are additions.
## Hut, table, workbench, gate and every tending spot stay bit for bit.
func test_phase5_layout_diff_against_phase4() -> void:
	var old := Phase5Fixtures.layout_p4()
	assert_false(old.is_empty(), "layout_p4.json")
	var changes: PackedStringArray = []
	_layout_diff(old, layout, "", changes)
	var allowed := [
		# additions (new keys / entries)
		"+_workyard", "+workyard", "+_stations", "+stations", "+_gather_nodes", "+gather_nodes", "+_bruch_decor",
		"+quarry_edges", "+_elder_gather", "+ground._phase5", "+ground.gather_flat_kinds", "+ground.quarry_tint",
		"+sections[bruch]", "+sections[quarry]", "+clearables[obs_b_gate]", "+clearables[obs_q_boulder_1]",
		"+clearables[obs_q_boulder_2]", "+clearables[obs_q_boulder_3]", "+entities[res_wood]._comment",
		"+props[3]._comment", "+background_trees[2]._comment", "+background_trees[6]._comment",
		"+elder_bushes[0].gather", "+elder_bushes[1].gather", "+elder_bushes[2].gather",
		"+waypoints.tp_bruch", "+waypoints.tp_quarry", "+waypoints.tp_schlag", "+waypoints.tp_workyard",
		"+lights.ph_bld_forge/light_ember", "+colliders._phase5", "+colliders.ph_bld_mason_bench", "+colliders.ph_bld_loom",
		"+colliders.ph_bld_forge", "+colliders.ph_prop_charcoal_kiln", "+colliders.ph_prop_build_site",
		"+colliders.ph_env_alder_coppice", "+colliders.ph_env_ore_vein", "+colliders.ph_env_workstone_ledge",
		"+colliders.ph_env_rubble_face", "+colliders.ph_env_boulder", "+colliders.ph_env_quarry_face",
		"+colliders.ph_env_quarry_edge", "+walkable_bounds._phase5",
		"+grass._phase5", "+grass.bruch_density_scale", "+grass.gather_keep_out",
		"+fence.segments[[21.5, 3.0], [21.5, 0.8]]", "+fence.segments[[21.5, -0.8], [21.5, -3.0]]",
		# changes
		"~_comment", "~ground._size", "~ground.size", "~ground.center",
		"~entities[res_wood].pos",                                      # V1
		"-fence.segments[[21.5, 3.0], [21.5, -3.0]]",                   # the Ostpforte
		"~props[3].pos",                                                # the crate (loom at the hut's SW corner)
		"~background_trees[2].pos", "~background_trees[6].pos",         # §4.2: out of Am Bruch
		"~walkable_bounds.max", "~camera_bounds.max", "~extra_walls",   # §4.5 (+ hedge / quarry walls)
	]
	var unexpected: PackedStringArray = []
	for c: String in changes:
		if not c in allowed:
			unexpected.append(c)
	assert_eq(unexpected, PackedStringArray(), "only the listed changes to the approved layout")
	for c: String in allowed:
		assert_true(c in changes, "listed change present: " + c)
	# Frozen: hut, table, workbench, gate, tending spots, plots, old graves.
	assert_eq(layout.hut, old.hut, "hut")
	assert_eq(layout.tree, old.tree, "old oak")
	for id: String in ["morgue_table", "workbench", "hut_door", "res_stone", "npc_trader"]:
		assert_eq(_by_id(layout.entities, id), _by_id(old.entities, id), id)
	assert_eq(_by_id(layout.clearables, "obs_h_gate"), _by_id(old.clearables, "obs_h_gate"), "Pförtchen")
	assert_eq(layout.dirt_spots, old.dirt_spots, "tending spots")
	assert_eq(layout.plots, old.plots, "plots")
	assert_eq(layout.old_graves, old.old_graves, "old graves")


## §10: route flood fill with a 1.5 m wide capsule over the built workyard (stations collide, all
## sections open, Ostpforte open): hut door ↔ Pförtchen, ↔ Birkenhang passage, ↔ gate, ↔ Ostpforte and
## ↔ every station's access. The Phase-4 bottleneck west of the stone heap (1.0 m, unchanged,
## §4.1 "so schmal wie in Phase 4") is passed with the gravekeeper's own capsule.
func test_phase5_routes_flood_fill() -> void:
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	GameState.set_flag(&"has_elder_key", true)
	GameState.set_flag(&"bruch_license", true)
	for s: StringName in [&"east", &"north", &"elder", &"bruch"]:
		expansion.unlock(s)
	var shop := world.get_node("Systems/Workshop") as Workshop
	shop.load_state({"built": ["mason", "loom", "forge"]})
	for id: String in ["station_mason", "station_loom", "station_forge"]:
		(world.get_node("Entities/" + id) as Workbench).refresh_built()
	for i: int in 4:
		await tree.physics_frame
	var step := 0.125
	var start := Vector2(-5.67, -3.7)
	var reached := _flood(start, step, Rect2(-11.5, -20.5, 35.0, 31.5))
	var targets := {
		"Pförtchen": [Vector2(-10.0, -11.6), 0.5], "Birkenhang passage": [Vector2(4.5, -12.4), 0.5],
		"gate (Tor)": [Vector2(1.1, 10.4), 0.5], "Ostpforte": [Vector2(22.4, 0.0), 0.5], "Ostwiese": [_v2(layout.waypoints.tp_east), 0.5],
	}
	for site: Dictionary in layout.workyard.build_sites:
		targets["access " + String(site.id)] = [_v2(site.access), 1.0]
	for name: String in targets:
		var t: Vector2 = targets[name][0]
		var near := float(targets[name][1])
		var ok := false
		for key: Vector2i in reached:
			if (Vector2(key) * step).distance_to(t) <= near:
				ok = true
				break
		assert_true(ok, "route door → %s (1.5 m capsule)" % name)


## §10: from the default gameplay camera (45°, 22 m, following the player at each station's
## access) the line of sight to the player's head (1.7 m) does not hit the hut; the station itself
## is clearly visible past the hut and the tree crowns: ≥ 90 % of its upper outline points from
## its access, ≥ 65 % from the workyard (tp_workyard, in front of the hut door) – there the forge's
## west end lies behind the roof edge, its ember and chimney stay in view.
func test_phase5_stations_visible_from_the_gameplay_camera() -> void:
	var probe := _occluder_probe(["Decor/Hut", "Decor/Tree", "Decor/Trees", "Decor/ElderBushes"])
	(world.get_node("Systems/Workshop") as Workshop).load_state({"built": ["mason", "loom", "forge"]})
	for i: int in 3:
		await tree.physics_frame
	var rig := world.get_node("CameraRig") as CameraRig
	var anchor := Node3D.new()
	world.add_child(anchor)
	rig.target = anchor
	rig.set_distance(22.0)
	var space := world.get_world_3d().direct_space_state
	for site: Dictionary in layout.workyard.build_sites:
		var station := world.get_node("Entities/station_" + String(site.station)) as Workbench
		station.refresh_built()
		var access := _v2(site.access)
		var head := Vector3(access.x, world.ground_height(access) + 1.7, access.y)
		var points := _outline_points(station)
		for cam: Vector2 in [access, _v2(layout.waypoints.tp_workyard)]:
			anchor.global_position = Vector3(cam.x, world.ground_height(cam), cam.y)
			rig.snap()
			var eye := rig.camera.global_position
			if cam == access:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, probe))
				assert_true(hit.is_empty() or not String(hit.collider.name).begins_with("Hut"),
						"%s: the player's head is seen past the hut (%s)" % [site.id, hit.get("position", "")])
			var seen := 0
			for p: Vector3 in points:
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, p + (eye - p).normalized() * 0.05, probe)).is_empty():
					seen += 1
			var need := 0.9 if cam == access else 0.65
			assert_true(seen >= need * points.size(), "%s visible from the camera at %s: %d / %d outline points" % [
					station.name, cam, seen, points.size()])
			if station.station == &"forge":
				var model := station.get_node("Model")
				for marker_name: String in ["light_ember", "smoke"]:
					var m := (model.find_child(marker_name, true, false) as Node3D).global_position
					assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, m + (eye - m).normalized() * 0.05, probe)).is_empty(),
							"forge %s seen from %s" % [marker_name, cam])


## §4.2: Am Bruch – sections bruch / quarry (work areas: no plots, no reputation), the Ostpforte
## (closed blocks, open walkable, stretched to 1.6 m), three boulders (pickaxe 1) in front of the
## quarry, 10 gather nodes Am Bruch + 7 in the Schlag + 3 at the elders, the rock edge and hedge.
func test_phase5_am_bruch_and_schlag() -> void:
	await tree.physics_frame
	await tree.physics_frame
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	for id: StringName in [&"bruch", &"quarry"]:
		var s := expansion.section(id)
		assert_not_null(s, String(id))
		assert_false(s.is_burial or s.counts_for_cemetery, String(id) + " is a work area")
		assert_false(expansion.is_unlocked(id), String(id) + " locked")
	assert_eq(expansion.block_reason(&"bruch"), "Die Pforte ist zu. Osric weiß, wer den Schlüssel hat.")
	assert_eq(Array(expansion.obstacle_ids(&"bruch")), ["obs_b_gate"])
	assert_eq(Array(expansion.obstacle_ids(&"quarry")), ["obs_q_boulder_1", "obs_q_boulder_2", "obs_q_boulder_3"])
	var gate := expansion.obstacle("obs_b_gate")
	assert_almost((gate.get_node("Model") as Node3D).scale.x * 1.19, 1.6, 0.01, "Ostpforte 1.6 m wide")
	assert_eq(gate.get_node("Model").scene_file_path, "res://assets/models/props/ph_prop_gate_small.glb")
	var through := [Vector2(21.0, 0.0), Vector2(21.5, 0.0), Vector2(22.0, 0.0)]
	assert_false(_capsule_free(through[1]), "the closed Ostpforte blocks")
	for p: Vector2 in [Vector2(21.5, 2.0), Vector2(21.5, -2.0)]:
		assert_false(_capsule_free(p), "the east fence stays closed at %s" % p)
	GameState.set_flag(&"bruch_license", true)
	assert_eq(expansion.block_reason(&"bruch"), "")
	assert_true(expansion.clear("obs_b_gate", world.get_player().inventory), "unlocked with the licence")
	assert_true(expansion.is_unlocked(&"bruch"), "Am Bruch open")
	for i: int in 3:
		await tree.physics_frame
	for p: Vector2 in through + [_v2(layout.waypoints.tp_bruch), _v2(layout.waypoints.tp_quarry)]:
		assert_true(_capsule_free(p), "walkable at %s" % p)
	assert_eq(expansion.block_reason(&"quarry"), "", "the quarry can be worked on")
	assert_false(expansion.can_clear("obs_q_boulder_1", world.get_player().inventory), "a boulder needs the pickaxe")
	for k: int in [1, 2, 3]:
		assert_eq(expansion.obstacle("obs_q_boulder_%d" % k).get_node("Model").scene_file_path,
				"res://assets/models/environment/ph_env_boulder.glb")
	# Walls: east edge, hedge in the south, rock face in the north.
	for ray: Array in [[Vector3(30.5, 1.0, 0.0), Vector3(32.5, 1.0, 0.0)], [Vector3(26.0, 1.0, 8.8), Vector3(26.0, 1.0, 10.6)],
			[Vector3(26.0, 1.0, -10.5), Vector3(26.0, 1.0, -12.5)]]:
		assert_false(world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[1], 1)).is_empty(),
				"wall between %s and %s" % ray)
	# Gather nodes (§2.2): 10 Am Bruch, 7 in the Schlag, 3 at the elders.
	var gathering := world.get_node("Systems/Gathering") as GatherManager
	var counts := {}
	for g: Dictionary in layout.gather_nodes:
		var node := world.get_node_or_null("Entities/" + String(g.id)) as GatherNode
		assert_not_null(node, g.id)
		if node == null:
			continue
		_assert_at(node, _v2(g.pos), g.id)
		assert_eq([node.node_id, node.kind, node.section_id], [String(g.id), StringName(g.kind), StringName(g.get("section", ""))], g.id)
		assert_true(gathering.is_registered(g.id), g.id + " registered")
		assert_true((node.get_node("Full") as Node3D).visible, g.id + " full model")
		var sec := String(g.get("section", ""))
		if sec != "":
			assert_true(_section_rect(sec).grow(0.05).has_point(_v2(g.pos)), g.id + " inside " + sec)
		var key := "schlag" if sec == "" else "bruch"
		counts[key] = int(counts.get(key, 0)) + 1
	assert_eq(counts, {"bruch": 10, "schlag": 7})
	var kinds := {}
	for g: Dictionary in layout.gather_nodes:
		kinds[g.kind] = int(kinds.get(g.kind, 0)) + 1
	assert_eq(kinds, {"ore_vein": 1, "workstone_ledge": 2, "rubble_face": 1, "flax_bed": 3, "clay_pit": 1, "herb_patch": 4, "alder": 5})
	# Before workshop_open the Schlag's alders are scenery (no prompt); the quarry waits for the boulders.
	var player := world.get_player()
	var alder := world.get_node("Entities/gather_alder_1") as GatherNode
	assert_eq(alder.get_interaction_prompt(player), "", "no prompt before workshop_open")
	GameState.set_flag(&"workshop_open", true)
	assert_eq((world.get_node("Entities/gather_ore_1") as GatherNode).get_interaction_prompt(player), "Findlinge versperren den Weg.")
	assert_ne((world.get_node("Entities/gather_clay_1") as GatherNode).get_interaction_prompt(player), "", "clay pit open")
	for w: String in ["tp_schlag", "tp_workyard"]:
		assert_true(_capsule_free(_v2(layout.waypoints[w])), w + " free")
	# The old slab (Lorenz' workplace) is scenery without function.
	assert_true(world.has_node("Decor/Bruch"), "rock edges, hedge, slab")
	var slabs := world.get_node("Decor/Bruch").find_children("*", "", false, false).filter(
			func(n: Node) -> bool: return (n as Node).scene_file_path.ends_with("ph_prop_build_site_slab.glb"))
	assert_eq(slabs.size(), 1, "one overgrown slab")


## §4.4: every elder bush carries a gather node without a model; the gravekeeper reaches each one
## from inside the walkable area (standing on a free spot, the node gets the focus).
func test_phase5_elder_bushes_gather() -> void:
	GameState.set_flag(&"workshop_open", true)
	await tree.physics_frame
	await tree.physics_frame
	var player := world.get_player()
	var bushes := world.get_node("Decor/ElderBushes")
	var reached := 0
	for k: int in [1, 2, 3]:
		var node := bushes.get_node_or_null("ElderBush_%d/gather_elder_%d" % [k, k]) as GatherNode
		assert_not_null(node, "gather_elder_%d" % k)
		if node == null:
			continue
		assert_eq(node.kind, &"elder_bush")
		assert_null(node.get_node_or_null("Full"), "no model of its own (the bush stays)")
		var p := Vector2(node.global_position.x, node.global_position.z)
		var focused := false
		for r: float in [0.0, 0.5, 0.9]:
			for a: int in 8:
				var spot := p + Vector2(r, 0.0).rotated(TAU * a / 8.0)
				var wb: Dictionary = layout.walkable_bounds
				if spot.x < float(wb.min[0]) + 0.3 or spot.y < float(wb.min[1]) + 0.3 or not _capsule_free(spot):
					continue
				player.global_position = Vector3(spot.x, world.ground_height(spot), spot.y)
				player.look_at(Vector3(p.x, player.global_position.y, p.y) + (Vector3(0, 0, 0.001) if r == 0.0 else Vector3.ZERO), Vector3.UP, true)
				for i: int in 3:
					await tree.physics_frame
				if player.detector.focused == node.interactable:
					focused = true
					break
			if focused:
				break
		assert_true(focused, "gather_elder_%d reachable from inside" % k)
		if focused:
			reached += 1
	assert_eq(reached, 3, "all three elder bushes can be picked")


## §4.1 V2 / §4.3: the build mask blocks the workyard (footprint + margin, the kiln) and makes the
## accesses ROUTE; the Ostpforte's inner access is ROUTE; Am Bruch lies outside the mask.
func test_phase5_build_mask() -> void:
	var mask := load(BUILD_MASK) as BuildMask
	for site: Dictionary in layout.workyard.build_sites:
		assert_eq(mask.flags_at(mask.world_to_cell(_v2(site.pos))), BuildMask.BLOCKED, site.id + " blocked")
		var acc := mask.flags_at(mask.world_to_cell(_v2(site.access)))
		assert_true(acc == BuildMask.BLOCKED or acc & BuildMask.ROUTE, "%s access is route (%d)" % [site.id, acc])
	assert_eq(mask.flags_at(mask.world_to_cell(_v2(layout.workyard.meiler.pos))), BuildMask.BLOCKED, "kiln blocked")
	assert_true(mask.flags_at(mask.world_to_cell(Vector2(21.1, 0.0))) & BuildMask.ROUTE, "in front of the Ostpforte")
	assert_eq(mask.flags_at(mask.world_to_cell(Vector2(25.0, 0.0))), BuildMask.BLOCKED, "Am Bruch outside the mask")


# --- Phase 5 helpers ----------------------------------------------------------------------------

## Flood fill (4-neighbours, `step` grid) of the cells where a 1.5 m wide upright cylinder fits
## (or – in the documented Phase-4 bottleneck – the player's capsule). Keys = grid indices.
func _flood(start: Vector2, step: float, area: Rect2) -> Dictionary:
	var wide := CylinderShape3D.new()
	wide.radius = 0.75
	wide.height = 1.2
	var bottleneck := Rect2(-11.25, -8.6, 1.95, 3.0)
	var space := world.get_world_3d().direct_space_state
	var free := func(p: Vector2) -> bool:
		if bottleneck.has_point(p):
			return _capsule_free(p)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = wide
		q.collision_mask = 1
		q.exclude = [world.get_player().get_rid(), world.get_node("GroundCollision").get_rid()]
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, world.ground_height(p) + 0.9, p.y))
		return space.intersect_shape(q, 1).is_empty()
	var first := Vector2i(roundi(start.x / step), roundi(start.y / step))
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	var reached := {}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var p := Vector2(c) * step
		if not area.has_point(p) or not free.call(p):
			continue
		reached[c] = true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return reached


## Collision copies (probe layer) of every mesh under the given paths: the hut and the crowns.
func _occluder_probe(paths: Array) -> int:
	var faces := PackedVector3Array()
	for path: String in paths:
		var root_node := world.get_node_or_null(path)
		if root_node == null:
			continue
		var meshes := root_node.find_children("*", "MeshInstance3D", true, false)
		if root_node is MeshInstance3D:
			meshes.append(root_node)
		for node: Node in meshes:
			var mi := node as MeshInstance3D
			var xf := mi.global_transform
			for v: Vector3 in mi.mesh.get_faces():
				faces.append(xf * v)
	var concave := ConcavePolygonShape3D.new()
	concave.backface_collision = true
	concave.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "HutAndCrownsProbe"
	body.collision_layer = FOLIAGE_PROBE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = concave
	body.add_child(shape)
	world.add_child(body)
	return FOLIAGE_PROBE_LAYER


## 5 × 5 points on the upper part of a station model's bounds (world space).
func _outline_points(station: Node3D) -> Array[Vector3]:
	var aabb := AABB()
	var first := true
	for node: Node in station.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	var out: Array[Vector3] = []
	for i: int in 5:
		for j: int in 5:
			out.append(Vector3(lerpf(aabb.position.x + 0.2, aabb.end.x - 0.2, i / 4.0), aabb.position.y + aabb.size.y * 0.75,
					lerpf(aabb.position.z + 0.2, aabb.end.z - 0.2, j / 4.0)))
	return out


## Axis-aligned world bounds of a node-local XZ rect.
func _world_rect(node: Node3D, local: Rect2) -> Rect2:
	var out := Rect2()
	var corners := [local.position, Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]
	for i: int in 4:
		var p := node.global_transform * Vector3(corners[i].x, 0.0, corners[i].y)
		out = Rect2(Vector2(p.x, p.z), Vector2.ZERO) if i == 0 else out.expand(Vector2(p.x, p.z))
	return out


## Recursive layout diff: "+path" added, "-path" removed, "~path" changed leaf. Lists of dicts with
## an "id" are matched by id, fence.segments as a set, other lists by index.
func _layout_diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		for key: Variant in b:
			var sub := String(key) if path == "" else path + "." + String(key)
			if not (a as Dictionary).has(key):
				out.append("+" + sub)
			else:
				_layout_diff(a[key], b[key], sub, out)
		for key: Variant in a:
			if not (b as Dictionary).has(key):
				out.append("-" + (String(key) if path == "" else path + "." + String(key)))
		return
	if a is Array and b is Array:
		if path == "fence.segments":
			for s: Variant in b:
				if not (a as Array).has(s):
					out.append("+%s%s" % [path, _seg_text(s)])
			for s: Variant in a:
				if not (b as Array).has(s):
					out.append("-%s%s" % [path, _seg_text(s)])
			return
		# Number lists (positions, rects, polylines) are compared as one value.
		if not (a as Array).any(func(e: Variant) -> bool: return e is Dictionary) and not (b as Array).any(func(e: Variant) -> bool: return e is Dictionary):
			if a != b:
				out.append("~" + path)
			return
		var keyed := not (a as Array).is_empty() and (a as Array).all(func(e: Variant) -> bool: return e is Dictionary and (e as Dictionary).has("id"))
		if keyed:
			for e: Dictionary in b:
				var old_e := _by_id(a, String(e.id))
				if old_e.is_empty():
					out.append("+%s[%s]" % [path, e.id])
				else:
					_layout_diff(old_e, e, "%s[%s]" % [path, e.id], out)
			for e: Dictionary in a:
				if _by_id(b, String(e.id)).is_empty():
					out.append("-%s[%s]" % [path, e.id])
			return
		for i: int in (b as Array).size():
			if i >= (a as Array).size():
				out.append("+%s[%d]" % [path, i])
			else:
				_layout_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		for i: int in range((b as Array).size(), (a as Array).size()):
			out.append("-%s[%d]" % [path, i])
		return
	if a != b:
		out.append("~" + path)


func _seg_text(s: Variant) -> String:
	var seg: Array = s
	return "[[%s, %s], [%s, %s]]" % [_num(seg[0][0]), _num(seg[0][1]), _num(seg[1][0]), _num(seg[1][1])]


func _num(v: Variant) -> String:
	var f := float(v)
	return ("%.1f" % f) if is_equal_approx(f * 10.0, roundf(f * 10.0)) else str(f)


func _by_id(list: Array, id: String) -> Dictionary:
	for e: Variant in list:
		if e is Dictionary and String((e as Dictionary).get("id", "")) == id:
			return e
	return {}


# --- helpers ----------------------------------------------------------------------------------

func _at(npc: Npc, minute: int) -> void:
	TimeManager.load_state({"day": 1, "minute_of_day": minute})
	npc.refresh()
	await tree.process_frame
	await tree.process_frame


func _at_day(npc: Npc, day: int, minute: int) -> void:
	TimeManager.load_state({"day": day, "minute_of_day": minute})
	npc.refresh()
	await tree.process_frame
	await tree.process_frame


func _waypoint_ids_missing(ids: Array) -> Array:
	return ids.filter(func(id: String) -> bool: return not world.has_node("Waypoints/" + id))


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


func _section_rect(id: String) -> Rect2:
	for s: Dictionary in layout.sections:
		if s.id == id:
			var r: Array = s.rect
			return Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
	return Rect2()


## Point at fraction t of the arc length of a layout polyline (XZ).
func _on_polyline(raw: Array, t: float) -> Vector2:
	var pts: Array[Vector2] = []
	for p: Array in raw:
		pts.append(_v2(p))
	var total := 0.0
	for k: int in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
	var s := t * total
	for k: int in range(1, pts.size()):
		var seg := pts[k].distance_to(pts[k - 1])
		if s <= seg:
			return pts[k - 1].lerp(pts[k], s / seg)
		s -= seg
	return pts.back()


## The player's capsule fits at world XZ `p` (on the ground) without touching a world body.
func _capsule_free(p: Vector2) -> bool:
	var capsule := world.get_player().get_node("Collision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.collision_mask = 1
	query.exclude = [world.get_player().get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, world.ground_height(p) + 0.1, p.y)) * capsule.transform
	return world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
