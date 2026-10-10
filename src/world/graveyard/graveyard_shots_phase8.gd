extends "res://src/world/graveyard/graveyard_shots_phase7.gd"
## Phase-8 graveyard shots (docs/PHASE8_DESIGN.md §11 – W-Welt part: p8_02…p8_04, p8_06…p8_10, p8_12, p8_13, p8_16,
## p8_21…p8_27, p8_vis_visitors / _apprentice / _night). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase8.gd \
##       -- --out=/abs/dir [--shots=p8_03,p8_vis] [--jpg]
## From the Phase-7 end state (saves_v6/slot_p7_day53_neighbor, Lindenacker full, eight villagers „Vertraut")
## loaded through the real SaveManager, p8_open on day 53. The states go through the real systems in story order:
## the third row granted (overgrown) · cleared and buried (ExpansionManager.unlock, Graveyard dig / bury /
## place_marker) · grave flowers, bouquets, candles, the mortsafe, the disturbed grave and the coins on the stone
## (GraveCare / Visitors) · the Lichtgang candles (GraveCare.light) and the early ghosts (GhostManager). The
## figures of a moment stand at their real places (the baked visitor spots gv_*, the hut corner, the gate, the
## Lichtgang places, the robber's way) and play their real clips with the tool / bouquet / lantern meshes of
## that clip (Npc show_with); they stand still for the picture. Sight rays like test_graveyard_world
## (test_phase8_sight), seen from above. Per shot: <out>/<name>.png|jpg and a line in render_stats_p8_graveyard.txt.

const FIXTURES_V6 := "res://tests/fixtures/saves_v6/%s.json"
const FIXTURE_P8 := "slot_p7_day53_neighbor"
const OPEN_DAY := 53
const ROW3_MARKERS := {"l_09": &"gravestone_simple", "l_10": &"wooden_cross", "l_11": &"gravestone_simple", "l_12": &"wooden_cross"}
const LIGHT_SECTIONS: Array[String] = ["yard", "north", "elder", "linden", "linden_row3", "east"]
## figure: [Npc node, place (waypoint id or Vector2), heading (deg; "wp" = the place's facing; Vector2 = look at), clip, t]
const G8_SHOTS: Array[Dictionary] = [
	{"name": "p8_27a_row3_before", "day": 54, "minute": 600, "focus": Vector2(16.5, 19.5), "distance": 16.0,
			"player": Vector2(16.4, 18.6), "facing": 0.0, "stage": "row3_granted"},
	{"name": "p8_27b_row3_stones", "day": 55, "minute": 610, "focus": Vector2(16.5, 19.5), "distance": 16.0,
			"player": Vector2(12.4, 19.2), "facing": 90.0, "stage": "row3_open"},
	{"name": "p8_02_martha_coach_road", "day": 56, "minute": 500, "focus": Vector2(4.0, 18.0), "distance": 13.0,
			"player": Vector2(-3.0, 12.0), "facing": 120.0, "stage": "visits",
			"figures": [["npc_kin_kehr", Vector2(3.6, 18.4), Vector2(1.2, 12.2), &"walk", 0.3]]},
	{"name": "p8_03_martha_kneels", "day": 56, "minute": 520, "player": Vector2(17.8, 15.4), "facing": 60.0, "game": 22.0,
			"figures": [["npc_kin_kehr", "gv_l_04", "wp", &"kneel", 1.2]]},
	{"name": "p8_04_hinrich_hat", "day": 56, "minute": 930, "focus": Vector2(15.9, 19.4), "distance": 11.0,
			"player": Vector2(13.0, 18.6), "facing": 90.0,
			"figures": [["npc_kin_brandt", "gv_l_10", "wp", &"mourn_stand", 0.8]]},
	{"name": "p8_06_coins_on_stone", "day": 56, "minute": 980, "player": Vector2(12.8, 20.4), "facing": 90.0, "game": 9.0, "ui": true,
			"stage": "tip"},
	{"name": "p8_07a_flowers_fresh_wilted_wreath", "day": 56, "minute": 485, "focus": Vector2(15.9, 13.8), "distance": 10.0,
			"player": Vector2(21.2, 15.0), "facing": 270.0, "stage": "flowers"},
	{"name": "p8_07b_rain_barrel", "day": 56, "minute": 610, "focus": Vector2(-6.6, -4.3), "distance": 7.5, "pitch": 64.0,
			"player": Vector2(-8.05, -3.55), "facing": 60.0, "player_clip": &"water"},
	{"name": "p8_08_jakob_rakes", "day": 56, "minute": 560, "focus": Vector2(-5.0, 3.2), "distance": 10.5,
			"player": Vector2(-1.5, 3.5), "facing": 250.0,
			"figures": [["npc_apprentice", Vector2(-6.1, 3.4), 295.0, &"rake", 0.4]]},
	{"name": "p8_09_jakob_watches", "day": 56, "minute": 600, "focus": Vector2(-8.6, 2.6), "distance": 9.0,
			"player": Vector2(-8.9, 2.6), "facing": 180.0, "player_clip": &"interact",
			"figures": [["npc_apprentice", Vector2(-9.45, 3.95), Vector2(-8.9, 2.4), &"watch", 0.6]]},
	{"name": "p8_10a_jakob_waters", "day": 56, "minute": 700, "focus": Vector2(4.8, 2.4), "distance": 9.0,
			"player": Vector2(9.0, 3.4), "facing": 270.0, "stage": "flowers_old_05",
			"figures": [["npc_apprentice", Vector2(5.8, 1.55), Vector2(4.8, 1.0), &"water", 0.5]]},
	{"name": "p8_10b_jakob_candle_dusk", "day": 56, "minute": 1068, "focus": Vector2(6.9, 2.4), "distance": 8.0,
			"player": Vector2(10.0, 3.8), "facing": 270.0, "stage": "candle_old_06",
			"figures": [["npc_apprentice", Vector2(7.65, 1.0), Vector2(6.7, 0.75), &"candle", 0.7]]},
	{"name": "p8_12_jakob_lunch", "day": 56, "minute": 735, "focus": Vector2(-3.4, -4.8), "distance": 8.0,
			"player": Vector2(-1.0, -2.6), "facing": 300.0,
			"figures": [["npc_apprentice", "apprentice_lunch", "wp", &"sit_eat", 0.5]]},
	{"name": "p8_13_esch_theres_old_graves", "day": 56, "minute": 880, "focus": Vector2(-1.6, 3.6), "distance": 17.0,
			"player": Vector2(1.6, 7.0), "facing": 200.0, "stage": "flowers_old_08",
			"figures": [["npc_smith_g", "gv_old_01", "wp", &"mourn_stand", 0.6], ["npc_grocer_g", "gv_old_08", "wp", &"kneel", 1.4]]},
	{"name": "p8_16_veit_hanne_gate", "day": 55, "minute": 950, "focus": Vector2(1.2, 10.8), "distance": 10.0,
			"player": Vector2(1.2, 8.0), "facing": 0.0,
			"figures": [["npc_beggar_g", "veit_gate", "wp", &"sit_ground", 0.5], ["npc_peddler_g", "peddler_gate", "wp", &"offer", 0.5]]},
	{"name": "p8_24_lambert_digs", "day": 57, "minute": 150, "focus": Vector2(14.8, 21.4), "distance": 11.0,
			"player": Vector2(9.0, 16.0), "facing": 90.0,
			"figures": [["npc_robber", "gv_l_10", "wp", &"dig_night", 0.4]]},
	{"name": "p8_25a_lambert_flees", "day": 57, "minute": 160, "focus": Vector2(16.0, 21.4), "distance": 11.0,
			"player": Vector2(14.8, 19.2), "facing": 120.0,
			"figures": [["npc_robber", Vector2(17.0, 22.6), Vector2(17.0, 23.6), &"climb", 0.9]]},
	{"name": "p8_25b_lambert_caught", "day": 58, "minute": 170, "focus": Vector2(14.8, 21.4), "distance": 8.0,
			"player": Vector2(15.4, 19.4), "facing": 200.0,
			"figures": [["npc_robber", "gv_l_10", "wp", &"sit_ground", 0.5]]},
	{"name": "p8_26_disturbed_and_mortsafe", "day": 58, "minute": 450, "focus": Vector2(17.0, 20.6), "distance": 11.0,
			"player": Vector2(16.9, 22.2), "facing": 180.0, "stage": "disturbed"},
	{"name": "p8_21_lights_procession", "day": 58, "minute": 1092, "focus": Vector2(5.5, 18.0), "distance": 18.0,
			"player": Vector2(0.2, 8.4), "facing": 160.0, "stage": "lights",
			# 18:12 the procession goes down the coach road in the dusk, Lenz in front, Jakob with the lantern last.
			"figures": [["npc_priest", Vector2(7.6, 24.4), Vector2(12.0, 28.6), &"lantern_walk", 0.1],
				["npc_kin_kehr", Vector2(5.8, 22.2), Vector2(12.0, 28.6), &"lantern_walk", 0.4],
				["npc_kin_ott", Vector2(4.0, 19.8), Vector2(12.0, 28.6), &"lantern_walk", 0.7],
				["npc_smith_g", Vector2(2.7, 16.9), Vector2(12.0, 28.6), &"lantern_walk", 0.2],
				["npc_grocer_g", Vector2(1.8, 14.0), Vector2(12.0, 28.6), &"lantern_walk", 0.5],
				["npc_apprentice", Vector2(1.3, 11.4), Vector2(12.0, 28.6), &"lantern_walk", 0.8]]},
	{"name": "p8_22_lights_overview", "day": 58, "minute": 1075, "focus": Vector2(3.5, -9.5), "distance": 31.0,
			"player": Vector2(4.5, -18.0), "facing": 180.0,
			"figures": [["npc_priest", "lights_lenz", "wp", &"idle", 0.2], ["npc_apprentice", "lights_crowd_4", "wp", &"idle", 0.3],
				["npc_smith_g", "gv_old_01", "wp", &"mourn_stand", 0.6], ["npc_grocer_g", "gv_old_08", "wp", &"mourn_stand", 0.6]]},
	{"name": "p8_23_lights_ghosts", "day": 58, "minute": 1078, "focus": Vector2(3.0, 1.0), "distance": 14.0,
			"player": Vector2(0.6, 6.6), "facing": 200.0, "stage": "ghosts"},
	# W3 (§9 budget pictures, game zoom 22): the Lichtgang overview with every figure of the procession on the hill.
	{"name": "perf_p8_03_lights_overview", "day": 58, "minute": 1075, "player": Vector2(3.5, -9.5), "facing": 180.0, "game": 22.0,
			"figures": [["npc_priest", "lights_lenz", "wp", &"idle", 0.2], ["npc_apprentice", "lights_crowd_4", "wp", &"idle", 0.3],
				["npc_smith_g", "gv_old_01", "wp", &"mourn_stand", 0.6], ["npc_grocer_g", "gv_old_08", "wp", &"mourn_stand", 0.6],
				["npc_innkeeper_g", "lights_crowd_1", "wp", &"idle", 0.1], ["npc_mayor_g", "lights_crowd_2", "wp", &"idle", 0.5],
				["npc_washer_g", "lights_crowd_3", "wp", &"idle", 0.7], ["npc_kin_kehr", "gv_l_04", "wp", &"mourn_stand", 0.4],
				["npc_kin_ott", "gv_l_03", "wp", &"mourn_stand", 0.3], ["npc_kin_brandt", "gv_l_10", "wp", &"mourn_stand", 0.2],
				["npc_kin_sieber", "gv_l_02", "wp", &"mourn_stand", 0.5], ["npc_beggar_g", "lights_gate", "wp", &"idle", 0.4],
				["npc_peddler_g", "lights_crowd_5", "wp", &"idle", 0.6]]},
	{"name": "perf_p8_01_day_jakob_visitors", "day": 59, "minute": 600, "player": Vector2(14.0, 15.0), "facing": 200.0, "game": 22.0,
			"figures": [["npc_apprentice", Vector2(10.4, 13.6), 295.0, &"rake", 0.4], ["npc_kin_kehr", "gv_l_04", "wp", &"kneel", 1.2],
				["npc_kin_brandt", "gv_l_10", "wp", &"mourn_stand", 0.8]]},
	{"name": "perf_p8_02_night_robber_candles", "day": 59, "minute": 150, "player": Vector2(12.0, 17.0), "facing": 120.0, "game": 22.0,
			"figures": [["npc_robber", "gv_l_10", "wp", &"dig_night", 0.4]]},
	{"name": "p8_vis_visitors_z12", "day": 56, "minute": 640, "focus": Vector2(4.0, 0.0), "distance": 62.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "visitors", "zoom": 12.0},
	{"name": "p8_vis_visitors_z22", "day": 56, "minute": 640, "focus": Vector2(4.0, 0.0), "distance": 62.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "visitors", "zoom": 22.0},
	{"name": "p8_vis_visitors_z24", "day": 56, "minute": 640, "focus": Vector2(4.0, 0.0), "distance": 62.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "visitors", "zoom": 24.0},
	{"name": "p8_vis_apprentice_z22", "day": 56, "minute": 640, "focus": Vector2(4.0, -2.0), "distance": 62.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "apprentice", "zoom": 22.0},
	{"name": "p8_vis_night_z22", "day": 56, "minute": 640, "focus": Vector2(16.5, 18.0), "distance": 30.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "night", "zoom": 22.0},
]

var _staged8: Array[Node3D] = []


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--jpg":
			_jpg = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=p8_03,p8_vis] [--jpg]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v6(FIXTURE_P8)
	_gs().call(&"set_flag", &"p8_open", true)
	_gs().call(&"set_flag", &"p8_open_day", OPEN_DAY)
	_bag = load(INVENTORY).new()
	_bag.name = "ShotBag"
	_bag.set(&"slot_count", 80)
	world.add_child(_bag)
	var report: PackedStringArray = []
	for shot: Dictionary in G8_SHOTS:
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		_stage8(world, shot)
		if wanted:
			await _shoot8(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p8_graveyard.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _load_v6(fixture: String) -> Node3D:
	var saves := root.get_node(^"SaveManager")
	var dir := String(saves.get("save_dir"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slot_%d.json" % SHOT_SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURES_V6 % fixture))
	f.close()
	await saves.call(&"load_game", SHOT_SLOT)
	for i: int in 3:
		await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	return world


# --- the states (story order, applied whether the shot is wanted or not) ------------------------------------

func _stage8(world: Node3D, shot: Dictionary) -> void:
	root.get_node(^"TimeManager").call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
	var care := _system(world, "GraveCare")
	match String(shot.get("stage", "")):
		"row3_granted":
			_gs().call(&"set_flag", &"linden_row3_granted", true)
		"row3_open":
			_system(world, "Expansion").call(&"unlock", &"linden_row3")
			_bury_row3(world)
		"visits":
			care.call(&"place_bouquet", "l_09")
			care.call(&"place_bouquet", "l_04")
		"tip":
			var visitors := _system(world, "Visitors")
			var st: Dictionary = visitors.call(&"save_state")
			var stones: Dictionary = st.get("tips_on_stone", {})
			stones["l_09"] = [2, "kin_kehr"]
			st["tips_on_stone"] = stones
			visitors.call(&"load_state", st)
			root.get_node(^"EventBus").emit_signal(&"grave_care_changed", "l_09", &"tip", true)
		"flowers":
			var st: Dictionary = care.call(&"save_state")
			var cfg: Resource = care.call(&"get_config")
			# The shot's own clock (the shots are not in time order – the previous one may be later that day).
			var now := (int(shot.day) - 1) * 1440 + int(shot.minute)
			var fresh := int(cfg.get(&"flower_fresh_minutes"))
			var fl: Dictionary = st.get("flowers", {})
			fl["l_01"] = {"planted": now, "watered": now, "wreath": false}
			fl["l_02"] = {"planted": now - fresh - 60, "watered": now - fresh - 60, "wreath": false}
			fl["l_03"] = {"planted": now, "watered": now, "wreath": true}
			st["flowers"] = fl
			care.call(&"load_state", st)
			for g: String in ["l_01", "l_02", "l_03"]:
				root.get_node(^"EventBus").emit_signal(&"grave_care_changed", g, &"flowers", true)
		"flowers_old_05", "flowers_old_08":
			# Fresh grave flowers (old_05 for Jakob's watering, Theres' Christrosen on old_08).
			var grave := String(shot.stage).trim_prefix("flowers_")
			var st5: Dictionary = care.call(&"save_state")
			var now5 := (int(shot.day) - 1) * 1440 + int(shot.minute)
			var fl5: Dictionary = st5.get("flowers", {})
			fl5[grave] = {"planted": now5 - 600, "watered": now5 - 600, "wreath": false}
			st5["flowers"] = fl5
			care.call(&"load_state", st5)
			root.get_node(^"EventBus").emit_signal(&"grave_care_changed", grave, &"flowers", true)
		"candle_old_06":
			_bag.call(&"add_item", &"grave_candle", 1)
			care.call(&"light", "old_06", _bag)
		"disturbed":
			care.call(&"set_disturbed", "l_10")
			_bag.call(&"add_item", &"mortsafe", 1)
			care.call(&"set_mortsafe", "l_11", true, _bag)
		"lights":
			_light_all(world)
		"ghosts":
			var lit: PackedStringArray = care.call(&"lit_graves")
			_system(world, "Ghosts").call(&"set_early_window", 1020, 60, lit)


## The four graves of row 3 dug, buried and marked (the real Graveyard API, like the P7 Lindenacker).
func _bury_row3(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	var graveyard := _system(world, "Graveyard")
	for id: String in ROW3_MARKERS:
		var grave: RefCounted = graveyard.call(&"get_grave", id)
		if grave == null:
			continue
		if int(grave.get("state")) == 0:
			graveyard.call(&"dig", id)
		var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		record.set("examined", true)
		record.set("shrouded", true)
		graveyard.call(&"bury", id, record.get("id"))
		_bag.call(&"add_item", ROW3_MARKERS[id], 1)
		graveyard.call(&"place_marker", id, ROW3_MARKERS[id], _bag)


## The Lichtgang: a candle on every occupied grave (GraveCare.light), the families' own included.
func _light_all(world: Node3D) -> void:
	var care := _system(world, "GraveCare")
	var graveyard := _system(world, "Graveyard")
	_bag.call(&"add_item", &"grave_candle", 60)
	for g: RefCounted in graveyard.call(&"graves"):
		care.call(&"light", String(g.get("id")), _bag)  # refuses an empty or open grave


# --- one picture ---------------------------------------------------------------------------------------------

func _shoot8(world: Node3D, shot: Dictionary, report: PackedStringArray) -> void:
	_clear_staged(world)
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	if bool(player.get(&"in_interior")):
		player.call(&"set_in_interior", false)
	if player.get(&"region_id") != GRAVEYARD:
		player.call(&"set_region", GRAVEYARD)
	var stand: Vector2 = shot.get("player", Vector2.ZERO)
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(shot.get("facing", 180.0)))),
			Vector3(stand.x, _ground(world, stand), stand.y))
	if shot.has("game"):
		rig.call(&"clear_profile")
		rig.set(&"bounds_enabled", true)
		rig.set(&"zoom_max", 24.0)
		rig.set(&"zoom_min", 12.0)
		rig.set(&"target", player)
		rig.call(&"set_distance", float(shot.game))
	elif String(shot.get("stage", "")) != "vis":
		rig.call(&"clear_profile")
		var focus: Vector2 = shot.focus
		_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	for i: int in 3:
		await process_frame
	root.get_node(^"EventBus").emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	rig.call(&"snap")
	_refresh_npcs(world)
	_refresh_corpses(world)
	_system(world, "Ghosts").call(&"reselect")
	for node: Node in world.get_tree().get_nodes_in_group(&"npc"):
		(node as Node3D).visible = false
		node.call(&"_set_state", false, false, false)
	for fig: Array in shot.get("figures", []):
		_figure8(world, fig)
	if shot.has("player_clip"):
		var anim := (player.find_children("*", "AnimationPlayer", true, false)[0]) as AnimationPlayer
		if anim.has_animation(StringName(shot.player_clip)):
			anim.play(StringName(shot.player_clip))
			anim.seek(0.5, true)
	if String(shot.get("stage", "")) == "vis":
		await _stage_vis8(world, shot)
	if shot.has("pitch"):
		rig.set(&"pitch_deg", float(shot.pitch))
	rig.call(&"snap")
	(world.get_node(^"UI") as CanvasLayer).visible = bool(shot.get("ui", false))
	for i: int in SETTLE_FRAMES:
		await process_frame
	await _save_frame(world, String(shot.name), report)
	for npc: Node3D in _staged8:
		npc.process_mode = Node.PROCESS_MODE_INHERIT
		if npc.has_meta(&"shot_ungrouped"):
			npc.remove_meta(&"shot_ungrouped")
			npc.add_to_group(&"npc")
	_staged8.clear()
	_unstage(world)
	rig.set(&"pitch_deg", 45.0)
	(world.get_node(^"UI") as CanvasLayer).visible = false


## A figure at its place playing its clip, with the meshes of that clip (show_with) – still for the picture.
func _figure8(world: Node3D, fig: Array) -> void:
	var npc := world.get_node_or_null(NodePath("Entities/" + String(fig[0]))) as Node3D
	if npc == null:
		push_warning("[ShotsP8] no %s" % fig[0])
		return
	var at: Vector3
	var heading := 0.0
	if fig[1] is String:
		var marker := world.get_node(NodePath("Waypoints/" + String(fig[1]))) as Node3D
		at = marker.global_position
		heading = rad_to_deg(marker.rotation.y)
	else:
		var p: Vector2 = fig[1]
		at = Vector3(p.x, _ground(world, p), p.y)
	if fig[2] is Vector2:
		var look: Vector2 = fig[2]
		heading = rad_to_deg(atan2(look.x - at.x, look.y - at.z))
	elif not (fig[2] is String):
		heading = float(fig[2])
	_stage_npc(world, String(fig[0]), at, heading, StringName(fig[3]), float(fig[4]))
	npc.set(&"_current_anim", StringName(fig[3]))
	npc.call(&"_apply_props")
	# NpcLod would re-evaluate the staged figure (no schedule entry → no animation → the tools hidden): out of its
	# group for the shot.
	if npc.is_in_group(&"npc"):
		npc.remove_from_group(&"npc")
		npc.set_meta(&"shot_ungrouped", true)
	_staged8.append(npc)


## Sight rays (frei grün, verdeckt rot) from above: the visitor spots kneeling and standing / Jakob's places / the
## robber's places and the south fence – the check of test_phase8_sight at the shot's zoom.
func _stage_vis8(world: Node3D, shot: Dictionary) -> void:
	if _sight == null:
		_sight = Sight.new(world)
	if not _sight_probed:
		_sight.call(&"probe", world, PackedStringArray(["Ground", "Player", "Interiors", "HutInterior", "Regions", "Corpses", "ShotStage",
				"Entities/npc_"]))
		_sight_probed = true
		for i: int in 3:
			await physics_frame
	var stage := _stage_root(world)
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/graveyard_layout.json"))
	var spots: Array = []   # [name, Vector2, head]
	match String(shot.vis):
		"visitors":
			for id: String in layout.visitor_spots:
				var s: Array = layout.visitor_spots[id]
				spots.append([id + "_kneel", Vector2(s[0], s[1]), 0.95])
				spots.append([id + "_stand", Vector2(s[0], s[1]), 1.6])
		"apprentice":
			for d: Dictionary in layout.dirt_spots:
				spots.append([String(d.id), Vector2(d.pos[0], float(d.pos[1]) + 0.7), 1.4])
			for id: String in ["apprentice_board", "apprentice_box", "apprentice_sweep", "rain_barrel"]:
				spots.append([id, Vector2(layout.waypoints[id][0], layout.waypoints[id][1]), 1.4])
		"night":
			for id: String in ["l_05", "l_06", "l_07", "l_08", "l_09", "l_10", "l_11", "l_12"]:
				var s: Array = layout.visitor_spots["gv_" + id]
				spots.append([id, Vector2(s[0], s[1]), 1.2])
			for id: String in ["robber_fence_in", "robber_fence_out"]:
				spots.append([id, Vector2(layout.waypoints[id][0], layout.waypoints[id][1]), 0.6])
	var hidden := 0
	var zoom := float(shot.zoom)
	for s: Array in spots:
		var at: Vector2 = s[1]
		var feet := Vector3(at.x, _ground(world, at), at.y)
		var head := feet + Vector3(0.0, float(s[2]), 0.0)
		var eye := _gameplay_eye(world, feet, zoom)
		var why := String(_sight.call(&"blocked", eye, head, feet + Vector3(0.0, minf(float(s[2]), 1.1), 0.0)))
		_sight.call(&"draw_ray", stage, head, eye, why == "")
		_sight.call(&"draw_dot", stage, feet + Vector3(0, 0.2, 0), why == "")
		if why != "":
			hidden += 1
			print("[ShotsP8 vis] %s zoom %d hidden by %s" % [s[0], int(zoom), why])
	print("[ShotsP8 vis] %s zoom %d: %d rays, %d hidden" % [shot.vis, int(zoom), spots.size(), hidden])
	var focus: Vector2 = shot.focus
	_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	(world.get_node(^"Player") as Node3D).visible = false
