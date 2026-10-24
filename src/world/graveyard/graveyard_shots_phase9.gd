extends "res://src/world/graveyard/graveyard_shots_phase8.gd"
## Phase-9 world shots (docs/PHASE9_DESIGN.md §11 – the W-Welt part: p9_00, p9_06…p9_11, p9_17, p9_19, p9_21, p9_23,
## p9_24, p9_vis_row4 / _gate / _sieber / _departure, perf_p9_01/02; the graveyard and the village in one run). Needs a
## real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/graveyard/graveyard_shots_phase9.gd \
##       -- --out=/abs/dir [--shots=p9_09,p9_vis] [--jpg] [--web]
## Web picture (§11: motif 09): the same with --rendering-method gl_compatibility --rendering-driver opengl3 before -s and
##   -- --shots=p9_09 --web (the file names get _web).
## From the Phase-8 end state (saves_v7/slot_p8_day63_kindly through the real SaveManager – Phase 9 opens on loading,
## day 63). The states go through the real systems: the fourth row granted (overgrown, stump and bramble) · opened and
## buried with stones (ExpansionManager.unlock, Graveyard dig / bury / place_marker) · the large sheet at both boards
## (HillRequests.pin_large) · the day flags of the plans (stranger_day on his first visit day, sieber_bench_day /
## sieber_evening_day, sieber_depart_peddler_day with peddler_day, sieber_depart_carter_day, sieber_watch_day on the
## night of the sick light q_light_day + 19) – with "schedule" the figures place themselves from their plans (Johann
## with Hanne up the forest way, Johann on Osric's cart through CartRider, the lantern at the Siebers' door, Brenneisen
## at his corner table in the inn); otherwise they stand at their real places playing their clips (still for the
## picture). KnockDoor: its own interact (the dialogue of the voice behind the door, W-UI's box). Sight rays like
## test_graveyard_world.test_phase9_sight / test_village_world.test_phase9_village_sight, seen from above (green free,
## red hidden). Per shot: <out>/<name>.png|jpg and a line in render_stats_p9.txt.

const FIXTURE_P9 := "slot_p8_day63_kindly"
const ROW4_MARKERS := {"l_13": &"gravestone_simple", "l_14": &"wooden_cross", "l_15": &"gravestone_simple", "l_16": &"wooden_cross"}
const VillageSight := preload("res://src/world/village/village_sight.gd")
## The contact sheet (p9_00): [Npc node, schedule id] beside the gravekeeper.
const SHEET9: Array = [["npc_stranger_g", &"stranger"], ["npc_kin_sieber_v_g", &"kin_sieber_v"], ["npc_beggar_g", &"beggar"],
		["npc_peddler_g", &"peddler"]]
## "day": an int or a token resolved at run time – visit1 (Brenneisen's first visit day), light19 (the night of the sick
## light, q_light_day + 19). "flags": day flags set to the shot's day before the clock is set. "schedule": the figures
## keep their plans (not hidden). "region": village → village_shots._shoot_village (room = an interior).
const G9_SHOTS: Array[Dictionary] = [
	# --- graveyard ---------------------------------------------------------------------------------------------
	{"name": "p9_24a_row4_before", "day": 64, "minute": 600, "focus": Vector2(17.0, 23.4), "distance": 14.0,
			"player": Vector2(16.9, 21.9), "facing": 0.0, "stage": "row4_granted"},
	{"name": "p9_00_contact_sheet", "day": 64, "minute": 620, "focus": Vector2(1.1, 4.6), "distance": 8.0, "pitch": 30.0,
			"player": Vector2(-0.9, 4.8), "facing": 0.0, "stage": "sheet9"},
	{"name": "p9_21_gate_board_sheet", "day": 64, "minute": 640, "focus": Vector2(-1.5, 8.9), "distance": 4.8, "pitch": 26.0,
			"player": Vector2(-0.2, 10.4), "facing": 200.0, "stage": "large_gate"},
	{"name": "p9_17_brenneisen_gate_veit", "day": "visit1", "minute": 880, "focus": Vector2(0.4, 11.0), "distance": 8.5, "pitch": 32.0,
			"player": Vector2(1.6, 8.4), "facing": 0.0, "flags": ["stranger_day"],
			"figures": [["npc_stranger_g", "stranger_gate", "wp", &"wait_gate", 0.6], ["npc_beggar_g", "veit_gate", "wp", &"sit_ground", 0.5]]},
	{"name": "perf_p9_01_gate_large_brenneisen", "day": "visit1", "minute": 885, "player": Vector2(1.6, 7.6), "facing": 0.0, "game": 22.0,
			"flags": ["stranger_day"], "schedule": true},
	# The gravekeeper walks beside them (the camera on him, as test_phase9_sight checks the way: eye on the walker).
	{"name": "p9_09_departure_hanne", "day": 67, "minute": 985, "game": 14.0, "follow": ["npc_kin_sieber_v_g", Vector2(0.9, 1.1)],
			"player": Vector2(-9.2, 12.5), "facing": 270.0, "flags": ["peddler_day", "sieber_depart_peddler_day"], "schedule": true},
	{"name": "p9_10_johann_on_the_cart", "day": 68, "minute": 612, "distance": 9.0, "pitch": 36.0, "focus_rider": true,
			"player": Vector2(1.0, 8.0), "facing": 0.0, "flags": ["sieber_depart_carter_day"], "schedule": true},
	{"name": "p9_vis_gate_z22", "day": 64, "minute": 640, "focus": Vector2(1.0, 11.0), "distance": 22.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "gate", "zoom": 22.0},
	{"name": "p9_vis_departure_z22", "day": 64, "minute": 640, "focus": Vector2(-5.5, 5.0), "distance": 36.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "departure", "zoom": 22.0},
	# Last in the graveyard: the four graves dug, buried and marked.
	{"name": "p9_24b_row4_stones", "day": 70, "minute": 600, "focus": Vector2(17.0, 23.4), "distance": 14.0,
			"player": Vector2(16.9, 21.9), "facing": 0.0, "stage": "row4_open"},
	# Row 4 cleared and occupied (as test_phase9_sight: the section open – no stump, no bramble).
	{"name": "p9_vis_row4_z12", "day": 70, "minute": 640, "focus": Vector2(17.0, 22.5), "distance": 30.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "row4", "zoom": 12.0},
	{"name": "p9_vis_row4_z22", "day": 70, "minute": 640, "focus": Vector2(17.0, 22.5), "distance": 30.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "row4", "zoom": 22.0},
	# --- village (region-local) --------------------------------------------------------------------------------
	{"name": "p9_06_veit_well_sieber_window", "region": "village", "day": 64, "minute": 600, "focus": Vector2(-10.0, 2.5),
			"distance": 36.0, "pitch": 24.0, "yaw": 113.0, "player": Vector2(4.4, -2.2), "facing": 250.0, "stage": "veit_bench"},
	{"name": "p9_07_knock_door_sieber", "region": "village", "day": 66, "minute": 900, "player": Vector2(-33.6, 15.6), "facing": 180.0,
			"game": 14.0, "ui": true, "stage": "knock"},
	{"name": "p9_08_johann_bench_evening", "region": "village", "day": 66, "minute": 1110, "player": Vector2(-30.4, 16.5), "facing": 285.0,
			"game": 13.0, "flags": ["sieber_evening_day"]},
	{"name": "p9_11_watchman_sick_light", "region": "village", "day": "light19", "minute": 1380, "player": Vector2(-32.1, 17.8),
			"facing": 200.0, "game": 20.0, "flags": ["sieber_watch_day"]},
	{"name": "p9_19_brenneisen_inn_corner", "region": "village", "day": "visit1", "minute": 1150, "room": "inn",
			"player": Vector2(1.0, 1.9), "flags": ["stranger_day"]},
	{"name": "p9_23_village_board_fenner", "region": "village", "day": 64, "minute": 700, "player": Vector2(-6.4, 7.1), "facing": 200.0,
			"game": 12.0, "stage": "large_village"},
	{"name": "perf_p9_02_village_brenneisen_johann", "region": "village", "day": "visit1", "minute": 720, "player": Vector2(0.6, -0.4),
			"game": 26.0, "flags": ["stranger_day"]},
	{"name": "p9_vis_sieber_z22", "region": "village", "day": 64, "minute": 640, "focus": Vector2(-31.0, 17.5), "distance": 30.0,
			"pitch": 85.0, "player": Vector2(-31.0, 16.9), "stage": "vis9_sieber", "zoom": 22.0},
	# --- W3 „Restbedarf“ (docs/reviews/phase9_round1/fixes/fixes.md; --shots=fix) ----------------------------------------
	# 1: at Marthe Quendel's grave (S1, plot_06) after the ledger, seedlings and straw flowers in the bag – the prompt.
	{"name": "fix1_grave_prompt_date_vorher", "day": 64, "minute": 640, "player": Vector2(9.6, 7.0), "facing": 200.0, "game": 12.0,
			"ui": true, "stage": "prompt_date_old"},
	{"name": "fix1_grave_prompt_date", "day": 64, "minute": 640, "player": Vector2(9.6, 7.0), "facing": 200.0, "game": 12.0,
			"ui": true, "stage": "prompt_date"},
	{"name": "fix1_grave_prompt_straw", "day": 64, "minute": 641, "player": Vector2(9.6, 7.0), "facing": 200.0, "game": 12.0,
			"ui": true, "stage": "prompt_straw"},
	# 5: the departure's sight rays without the player's cutout (radius 0).
	{"name": "fix5_vis_departure_nocut_z12", "day": 64, "minute": 640, "focus": Vector2(-5.5, 5.0), "distance": 36.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "departure", "zoom": 12.0, "no_cut": true},
	{"name": "fix5_vis_departure_nocut_z22", "day": 64, "minute": 640, "focus": Vector2(-5.5, 5.0), "distance": 36.0, "pitch": 85.0,
			"player": Vector2(-20.0, 0.0), "stage": "vis", "vis": "departure", "zoom": 22.0, "no_cut": true},
	# 2: Quast (light + 19, 22:30) and Lenz with his lantern (light + 20, 21:00) at the Siebers' door.
	{"name": "fix2_quast_sieber_night", "region": "village", "day": "light19", "minute": 1347, "player": Vector2(-28.8, 19.4),
			"facing": 250.0, "game": 13.0, "flags": ["night_np_sieber_surgeon_day"], "clear": ["sieber_watch_day"]},
	{"name": "fix2_lenz_sieber_night", "region": "village", "day": "light20", "minute": 1257, "player": Vector2(-28.8, 19.4),
			"facing": 250.0, "game": 13.0, "flags": ["night_np_sieber_priest_day"], "clear": ["sieber_watch_day"]},
	# 3: ending B – Lenz on the first, Liesel on the second evening beside Johann on the bench.
	{"name": "fix3_lenz_bench_evening", "region": "village", "day": 66, "minute": 1110, "player": Vector2(-28.9, 18.3),
			"facing": 285.0, "game": 13.0, "flags": ["sieber_evening_day", "sieber_evening_priest_day"]},
	{"name": "fix3_liesel_bench_evening", "region": "village", "day": 67, "minute": 1110, "player": Vector2(-28.9, 18.3),
			"facing": 285.0, "game": 13.0, "flags": ["sieber_evening_day", "sieber_evening_washer_day"], "clear": ["sieber_evening_priest_day"]},
	# 4: the watchman at the door on a watch night (ending C), close up.
	{"name": "fix4_watchman_close", "region": "village", "day": "light19", "minute": 1385, "player": Vector2(-29.9, 18.9),
			"facing": 200.0, "game": 12.0, "flags": ["sieber_watch_day"]},
	# --- W3 QA-Fix (docs/reviews/phase9_round1/qafix/qafix.md; --shots=qafix) --------------------------------------------
	# QA9-04: the same grave as fix1 – the prompt names the choice, [E] opens it (the date first, the care after).
	{"name": "qafix_qa9_04_grave_prompt", "day": 64, "minute": 640, "player": Vector2(9.6, 7.0), "facing": 200.0, "game": 12.0,
			"ui": true, "stage": "prompt_date"},
	{"name": "qafix_qa9_04_grave_choice", "day": 64, "minute": 640, "player": Vector2(9.6, 7.0), "facing": 200.0, "game": 12.0,
			"ui": true, "stage": "prompt_choice"},
]

var _web := false
var _sight_v: RefCounted
var _hill_pinned: Array[StringName] = []
var _row4_probed := false


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--jpg":
			_jpg = true
		elif arg == "--web":
			_web = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=p9_09,p9_vis] [--jpg] [--web]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v7(FIXTURE_P9)
	_bag = load(INVENTORY).new()
	_bag.name = "ShotBag"
	_bag.set(&"slot_count", 80)
	world.add_child(_bag)
	var report: PackedStringArray = []
	for template: Dictionary in G9_SHOTS:
		var shot := template.duplicate()
		shot["day"] = _resolve_day(world, shot.day)
		if _web:
			shot["name"] = String(shot.name) + "_web"
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		_stage9(world, shot)
		if not wanted:
			continue
		if String(shot.get("region", "")) == "village":
			await _shoot_village(world, shot, report)
		else:
			await _shoot9(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p9%s.txt" % ("_web" if _web else "")), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _load_v7(fixture: String) -> Node3D:
	var saves := root.get_node(^"SaveManager")
	var dir := String(saves.get("save_dir"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slot_%d.json" % SHOT_SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/saves_v7/%s.json" % fixture))
	f.close()
	await saves.call(&"load_game", SHOT_SLOT)
	for i: int in 3:
		await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	if not bool(_system(world, "Quests").call(&"is_open")):
		push_warning("[ShotsP9] Phase 9 not open after loading %s" % fixture)
	return world


func _resolve_day(world: Node3D, day: Variant) -> int:
	if day is int:
		return day
	match String(day):
		"visit1":
			var days: PackedInt32Array = _system(world, "Stranger").call(&"visit_days")
			return days[0] if not days.is_empty() else 65
		"light19":
			return int(_gs().call(&"get_flag", &"q_light_day", 51)) + 19
		"light20":
			return int(_gs().call(&"get_flag", &"q_light_day", 51)) + 20
	return 64


# --- the states (applied whether the shot is wanted or not) -------------------------------------------------

func _stage9(world: Node3D, shot: Dictionary) -> void:
	for flag: String in shot.get("clear", []):
		_gs().call(&"clear_flag", StringName(flag))
	for flag: String in shot.get("flags", []):
		_gs().call(&"set_flag", StringName(flag), int(shot.day))
	root.get_node(^"TimeManager").call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
	var hill := _system(world, "HillRequests")
	match String(shot.get("stage", "")):
		"row4_granted":
			_gs().call(&"set_flag", &"linden_row4_granted", true)
		"row4_open":
			_system(world, "Expansion").call(&"unlock", &"linden_row4")
			_bury_row4(world)
		"large_gate":
			if bool(hill.call(&"pin_large", &"hrl_ferry_graves")):
				_hill_pinned.append(&"hrl_ferry_graves")
			var board := world.get_node_or_null(^"Entities/notice_board")
			if board != null:
				board.call(&"refresh")
		"large_village":
			if bool(hill.call(&"pin_large", &"hrv_bridge_stones")):
				_hill_pinned.append(&"hrv_bridge_stones")
			var vboard := _village(world).get_node_or_null(^"Entities/village_board")
			if vboard != null:
				vboard.call(&"refresh")


func _bury_row4(world: Node3D) -> void:
	var manager := _system(world, "CorpseManager")
	var graveyard := _system(world, "Graveyard")
	for id: String in ROW4_MARKERS:
		var grave: RefCounted = graveyard.call(&"get_grave", id)
		if grave == null:
			push_warning("[ShotsP9] no grave %s" % id)
			continue
		if int(grave.get("state")) == 0:
			graveyard.call(&"dig", id)
		var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		record.set("examined", true)
		record.set("shrouded", true)
		graveyard.call(&"bury", id, record.get("id"))
		_bag.call(&"add_item", ROW4_MARKERS[id], 1)
		graveyard.call(&"place_marker", id, ROW4_MARKERS[id], _bag)


# --- one graveyard picture -----------------------------------------------------------------------------------

func _shoot9(world: Node3D, shot: Dictionary, report: PackedStringArray) -> void:
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
	elif String(shot.get("stage", "")) != "vis" and shot.has("focus"):
		rig.call(&"clear_profile")
		var focus: Vector2 = shot.focus
		_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	for i: int in 3:
		await process_frame
	var bus := root.get_node(^"EventBus")
	bus.emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	rig.call(&"snap")
	_refresh_npcs(world)
	_refresh_corpses(world)
	_system(world, "Ghosts").call(&"reselect")
	if not bool(shot.get("schedule", false)):
		for node: Node in world.get_tree().get_nodes_in_group(&"npc"):
			(node as Node3D).visible = false
			node.call(&"_set_state", false, false, false)
	for fig: Array in shot.get("figures", []):
		_figure8(world, fig)
	for i: int in 2:
		await process_frame
	# CartRider looks once a game minute (after the plans placed Osric and Johann).
	bus.emit_signal(&"time_tick", int(shot.day), int(shot.minute))
	for i: int in 2:
		await process_frame
	match String(shot.get("stage", "")):
		"sheet9":
			_stage_sheet9(world)
		"vis":
			await _stage_vis9(world, shot)
		"prompt_date", "prompt_straw", "prompt_date_old", "prompt_choice":
			_stage_prompt(world, String(shot.stage))
	if shot.has("follow"):
		var lead := world.get_node_or_null(NodePath("Entities/" + String(shot.follow[0]))) as Node3D
		if lead != null and lead.visible:
			var off: Vector2 = shot.follow[1]
			var at := Vector2(lead.global_position.x + off.x, lead.global_position.z + off.y)
			player.global_position = Vector3(at.x, _ground(world, at), at.y)
		else:
			push_warning("[ShotsP9] %s is not out" % shot.follow[0])
	if bool(shot.get("focus_rider", false)):
		var rider := world.get_node_or_null(^"Entities/CartRider")
		var fig: Node3D = rider.call(&"figure") as Node3D if rider != null and bool(rider.call(&"is_riding")) else null
		if fig == null:
			push_warning("[ShotsP9] Johann is not on the cart at %d" % int(shot.minute))
		else:
			_free_camera(world, fig.global_position, float(shot.distance))
	if shot.has("player_clip"):
		var anim := (player.find_children("*", "AnimationPlayer", true, false)[0]) as AnimationPlayer
		if anim.has_animation(StringName(shot.player_clip)):
			anim.play(StringName(shot.player_clip))
			anim.seek(0.5, true)
	if shot.has("pitch"):
		rig.set(&"pitch_deg", float(shot.pitch))
	rig.set(&"yaw_deg", float(shot.get("yaw", 0.0)))
	rig.call(&"snap")
	(world.get_node(^"UI") as CanvasLayer).visible = bool(shot.get("ui", false))
	for i: int in SETTLE_FRAMES:
		await process_frame
	await _save_frame(world, String(shot.name), report)
	if String(shot.get("stage", "")) == "prompt_choice":
		world.get_node(^"UI").call(&"close_all")
		root.get_node(^"UIState").call(&"clear")
	for npc: Node3D in _staged8:
		npc.process_mode = Node.PROCESS_MODE_INHERIT
		if npc.has_meta(&"shot_ungrouped"):
			npc.remove_meta(&"shot_ungrouped")
			npc.add_to_group(&"npc")
	_staged8.clear()
	_unstage(world)
	rig.set(&"pitch_deg", 45.0)
	rig.set(&"yaw_deg", 0.0)
	(world.get_node(^"UI") as CanvasLayer).visible = false


## W3 „Restbedarf“ 1: the prompt of Marthe Quendel's grave (plot_06, S1 of the list) with seedlings, a wax wreath and
## straw flowers in the bag – after the ledger (kladde_read) the date first; without the ledger the straw flowers once the
## seedlings and the wreath are gone. The HUD shows what the grave's [E] would do (GravePlot.get_interaction_prompt).
func _stage_prompt(world: Node3D, stage: String) -> void:
	var player := world.get_node(^"Player") as Node3D
	var inv: Object = player.get(&"inventory")
	for item: StringName in [&"flower_seedlings", &"wax_wreath", &"straw_bouquet"]:
		var n := int(inv.call(&"count", item))
		if n > 0:
			inv.call(&"remove_item", item, n)
	inv.call(&"add_item", &"straw_bouquet", 1)
	if stage == "prompt_date" or stage == "prompt_date_old" or stage == "prompt_choice":
		inv.call(&"add_item", &"flower_seedlings", 1)
		inv.call(&"add_item", &"wax_wreath", 1)
		_gs().call(&"set_flag", &"kladde_read", true)
	else:
		_gs().call(&"clear_flag", &"kladde_read")
	var plot: Node = world.call(&"get_node_by_layout_id", "plot_06")
	var prompt := String(plot.call(&"get_interaction_prompt", player))
	if stage == "prompt_date_old":
		# „vorher": the order before W3 – an enabled care action came before the date (W2: the seedlings first).
		prompt = String(plot.call(&"care_prompt", plot.call(&"_care_action", player, true), player))
	print("[ShotsP9 prompt] %s: %s" % [stage, prompt])
	root.get_node(^"EventBus").emit_signal(&"interaction_focus_changed", prompt, true)
	if stage == "prompt_choice":
		# W3 QA-Fix QA9-04: the grave's [E] – the choice of everything it offers (ActionChoicePanel).
		plot.call(&"interact", player)


## p9_00: Brenneisen beside the gravekeeper, then Johann, Veit and Hanne – in a row, idle, facing the camera, names below.
func _stage_sheet9(world: Node3D) -> void:
	var stage := _stage_root(world)
	var db := root.get_node(^"Database")
	var player := world.get_node(^"Player") as Node3D
	var anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.2, true)
	var names: Array[String] = ["Totengräber"]
	var spots: Array[Vector3] = [player.global_position]
	for i: int in SHEET9.size():
		var p := Vector2(0.1 + i * 1.0, 4.8)
		_figure8(world, [SHEET9[i][0], p, 0.0, &"idle", 0.3 + i * 0.21])
		var sched: Resource = db.call(&"schedule", SHEET9[i][1])
		names.append(String(sched.get(&"display_name")) if sched != null else String(SHEET9[i][1]))
		spots.append(Vector3(p.x, _ground(world, p), p.y))
	for i: int in names.size():
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 40
		label.pixel_size = 0.0036
		label.outline_size = 10
		label.modulate = Color(0.96, 0.92, 0.82)
		label.outline_modulate = Color(0.12, 0.09, 0.07)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		stage.add_child(label)
		label.global_position = spots[i] + Vector3(0.0, 0.05, 0.75 if i % 2 == 0 else 1.05)


## Sight rays from above (test_phase9_sight at the shot's zoom): row 4 (stone, mound, the visitor kneeling and standing
## at each grave) · the gate (Brenneisen, Veit, Hanne, Johann – the camera on each) · the departure with Hanne
## (sieber_gate → gate_outside → peddler_west → trader_spot, 13 points).
func _stage_vis9(world: Node3D, shot: Dictionary) -> void:
	if _sight == null:
		_sight = Sight.new(world)
	# Row 4 is drawn after it was cleared: the probe of the earlier rays still holds the stump and the bramble.
	var reprobe := String(shot.vis) == "row4" and not _row4_probed
	if reprobe and _sight_probed:
		_sight.call(&"unprobe", world)
		_sight_probed = false
	if not _sight_probed:
		_sight.call(&"probe", world, PackedStringArray(["Ground", "Player", "Interiors", "HutInterior", "Regions", "Corpses", "ShotStage",
				"Entities/npc_"]))
		_sight_probed = true
		_row4_probed = _row4_probed or reprobe
		for i: int in 3:
			await physics_frame
	var stage := _stage_root(world)
	var zoom := float(shot.zoom)
	var rays: Array = []   # [name, target point, chest point, eye]
	match String(shot.vis):
		"row4":
			for id: String in ROW4_MARKERS:
				var plot := world.get_node(NodePath("Entities/" + id)) as Node3D
				var at := _wp(world, "gv_" + id)
				var feet := Vector3(at.x, _ground(world, at), at.y)
				var eye := _gameplay_eye(world, feet, zoom)
				var chest := feet + Vector3(0.0, 1.1, 0.0)
				rays.append([id + "_kneel", feet + Vector3(0.0, 0.95, 0.0), feet + Vector3(0.0, 0.95, 0.0), eye])
				rays.append([id + "_stand", feet + Vector3(0.0, 1.6, 0.0), chest, eye])
				# The stone and the mound are the grave's own meshes (not blockers of their own ray).
				rays.append([id + "_stone", plot.to_global(Vector3(0.0, 0.55, -1.02)), chest, eye, [plot]])
				rays.append([id + "_mound", plot.to_global(Vector3(0.0, 0.25, 0.3)), chest, eye, [plot]])
		"gate":
			var people := {"stranger_gate": 1.6, "veit_gate": 0.95, "peddler_gate": 1.6, "sieber_gate": 1.55}
			for focus: String in people:
				var f := _wp(world, focus)
				var eye := _gameplay_eye(world, Vector3(f.x, _ground(world, f), f.y), zoom)
				for who: String in people:
					var at := _wp(world, who)
					var g := _ground(world, at)
					rays.append(["%s@%s" % [who, focus], Vector3(at.x, g + float(people[who]), at.y), Vector3(at.x, g + 0.9, at.y), eye])
		"departure":
			var way: Array[Vector2] = []
			for id: String in ["sieber_gate", "gate_outside", "peddler_west", "trader_spot"]:
				way.append(_wp(world, id))
			for k: int in 13:
				var p := _along(way, k / 12.0)
				var feet := Vector3(p.x, _ground(world, p), p.y)
				rays.append(["departure_%02d" % k, feet + Vector3(0.0, 1.55, 0.0), feet + Vector3(0.0, 1.1, 0.0), _gameplay_eye(world, feet, zoom)])
	var hidden := 0
	# W3 „Restbedarf“ 5: "no_cut" – the rays without the player's cutout (radius 0: every leaf in the way hides).
	var cut: Dictionary = _sight.get(&"_cut")
	var cut_radius := float(cut.radius)
	if bool(shot.get("no_cut", false)):
		cut["radius"] = 0.0
	for r: Array in rays:
		var why := String(_sight.call(&"blocked", r[3], r[1], r[2], r[4] if r.size() > 4 else []))
		_sight.call(&"draw_ray", stage, r[1], r[3], why == "")
		var pt: Vector3 = r[1]
		var ch: Vector3 = r[2]
		_sight.call(&"draw_dot", stage, Vector3(pt.x, ch.y - 0.9, pt.z), why == "", 0.2)
		if why != "":
			hidden += 1
			print("[ShotsP9 vis] %s zoom %d hidden by %s" % [r[0], int(zoom), why])
	cut["radius"] = cut_radius
	print("[ShotsP9 vis] %s zoom %d: %d rays, %d hidden%s" % [shot.vis, int(zoom), rays.size(), hidden,
			" (no cutout)" if bool(shot.get("no_cut", false)) else ""])
	var focus: Vector2 = shot.focus
	_free_camera(world, Vector3(focus.x, _ground(world, focus), focus.y), float(shot.distance))
	(world.get_node(^"Player") as Node3D).visible = false


func _wp(world: Node3D, id: String) -> Vector2:
	var p: Vector3 = world.call(&"get_waypoint", StringName(id))
	return Vector2(p.x, p.z)


static func _along(way: Array[Vector2], t: float) -> Vector2:
	var total := 0.0
	for i: int in way.size() - 1:
		total += way[i].distance_to(way[i + 1])
	var left := total * clampf(t, 0.0, 1.0)
	for i: int in way.size() - 1:
		var seg := way[i].distance_to(way[i + 1])
		if left <= seg or i == way.size() - 2:
			return way[i].lerp(way[i + 1], clampf(left / maxf(seg, 0.001), 0.0, 1.0))
		left -= seg
	return way.back()


# --- the village ---------------------------------------------------------------------------------------------

func _stage_village(world: Node3D, shot: Dictionary) -> void:
	var village := _village(world)
	var rig := world.get_node(^"CameraRig") as Node3D
	match String(shot.get("stage", "")):
		"veit_bench":
			# Veit on the well bench by day (his own place, v_well_bench), the Siebers' house far behind him (no light).
			var seat: Vector3 = village.call(&"get_waypoint", &"v_well_bench")
			_stage_npc(world, "npc_beggar", seat, 0.0, &"sit_beg", 0.4)
		"knock":
			var door := village.get_node_or_null(^"Entities/door_sieber")
			var player := world.get_node(^"Player")
			if door != null and bool(door.call(&"can_interact", player)):
				door.call(&"interact", player)
				for i: int in 4:
					await process_frame
			else:
				push_warning("[ShotsP9] the KnockDoor refuses")
		"large_village":
			var at: Vector3 = village.call(&"get_waypoint", &"v_board")
			_stage_npc(world, "npc_mayor", at + Vector3(1.3, 0.0, 0.4), 230.0, &"idle", 0.4)
		"vis9_sieber":
			await _stage_vis9_sieber(world, shot)
		_:
			await super(world, shot)
	rig.set(&"yaw_deg", float(shot.get("yaw", 0.0)))


## p9_vis_sieber: the camera rays at the Siebers' yard (test_phase9_village_sight) – the gravekeeper's head at the watch
## place, the door place and beside the bench, Johann on the bench, the KnockDoor; the watch place's own look at the door
## and the attic window (eye height). Seen from above.
func _stage_vis9_sieber(world: Node3D, shot: Dictionary) -> void:
	var village := _village(world)
	if _sight_v == null:
		_sight_v = VillageSight.new(world)
		_sight_v.call(&"probe", village, PackedStringArray(["Ground", "Decor/Grass", "Entities/npc_"]))
		for i: int in 3:
			await physics_frame
	var stage := _stage_root(world)
	var zoom := float(shot.zoom)
	var house := village.get_node(^"Buildings/house_sieber")
	var watch := village.get_node(^"Entities/watch_sieber") as Node3D
	var door: Vector3 = village.call(&"get_waypoint", &"v_sieber_door")
	var seat: Vector3 = village.call(&"get_waypoint", &"v_sieber_bench")
	var knock := (village.get_node(^"Entities/door_sieber") as Node3D).global_position + Vector3(0, 1.2, 0)
	var attic := (village.get_node(^"Entities/sick_light_sieber") as Node3D).global_position + Vector3(0.0, 0.2, 0.0)
	var rays: Array = []   # [name, point, chest, eye, exclude]
	var stands := {"watch": watch.global_position, "door": door, "bench": seat + Vector3(0.9, 0.0, 0.6)}
	for nm: String in stands:
		var stand: Vector3 = stands[nm]
		var eye := _gameplay_eye(world, stand, zoom)
		var chest := stand + Vector3(0.0, 1.1, 0.0)
		rays.append(["gravekeeper@" + nm, stand + Vector3(0, 1.6, 0), chest, eye, []])
		if nm == "bench":
			rays.append(["johann_bench", seat + Vector3(0, 1.1, 0), chest, eye, []])
		if nm == "door":
			rays.append(["knock_door", knock, chest, eye, [house]])
	var eye_h := watch.global_position + Vector3(0, 1.6, 0)
	rays.append(["watch→door", door + Vector3(0, 1.6, 0), eye_h, eye_h, [house]])
	rays.append(["watch→attic", attic + (attic - eye_h).normalized() * -0.25, eye_h, eye_h, [house]])  # the pane sits in the wall
	var hidden := 0
	for r: Array in rays:
		var why := String(_sight_v.call(&"blocked", r[3], r[1], r[2], r[4]))
		_sight_v.call(&"draw_ray", stage, r[1], r[3], why == "")
		var pt: Vector3 = r[1]
		_sight_v.call(&"draw_dot", stage, pt - Vector3(0.0, 1.0, 0.0), why == "", 0.2)
		if why != "":
			hidden += 1
			print("[ShotsP9 vis] %s zoom %d hidden by %s" % [r[0], int(zoom), why])
	print("[ShotsP9 vis] sieber zoom %d: %d rays, %d hidden" % [int(zoom), rays.size(), hidden])
	_free_camera(world, _vpos(world, shot.focus), float(shot.distance))
	(world.get_node(^"Player") as Node3D).visible = false


func _unstage(world: Node3D) -> void:
	for box: Node in world.get_node(^"UI").find_children("*", "", true, false):
		if box.has_method(&"end_dialogue") and box.has_method(&"is_active") and bool(box.call(&"is_active")):
			box.call(&"end_dialogue")
	root.get_node(^"UIState").call(&"clear")
	super(world)
	(world.get_node(^"CameraRig") as Node3D).set(&"yaw_deg", 0.0)
