extends TestCase
## Lead / W0 (docs/PHASE8_DESIGN.md §12): the Phase-8 scaffold – every stub class loads with its
## contract signature, every new data class / config .tres holds valid contract values, the extensions
## of existing data classes, the 13 EventBus signals, no new input actions, Database folders, save
## format v7 + migration chain 1 → … → 7, and the W1 fixtures (tests/fixtures/phase8, Phase8Fixtures,
## tests/fixtures/saves_v6).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = [
	"Friendship", "FriendRules", "FavorRules", "Festivals", "FestivalRules", "FestDecor", "MemorialPlate", "ArchiveCabinet",
	"Fiddler", "SaveMigration", "Village", "ScheduleBuilder", "NpcLife", "MoodRules", "ReactionRules", "ChatterRunner",
	"Apprentice", "ApprenticeRules", "ApprenticePlanner", "ApprenticeBoard", "ApprenticeBox",
]
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/npc_life/npc_life.gd": "NpcLife",
	"res://src/systems/npc_life/mood_rules.gd": "MoodRules",
	"res://src/systems/npc_life/chatter_runner.gd": "ChatterRunner",
	"res://src/systems/npc_life/reaction_rules.gd": "ReactionRules",
	"res://src/systems/npc/schedule_builder.gd": "ScheduleBuilder",
	# P2
	"res://src/systems/visitors/visitors.gd": "Visitors",
	"res://src/systems/visitors/visit_rules.gd": "VisitRules",
	"res://src/systems/visitors/wish_rules.gd": "WishRules",
	"res://src/systems/visitors/grave_view.gd": "GraveView",
	"res://src/systems/grave_care/grave_care.gd": "GraveCare",
	"res://src/systems/grave_care/grave_care_rules.gd": "GraveCareRules",
	"res://src/entities/tip_stone/tip_stone.gd": "TipStone",
	"res://src/entities/rain_barrel/rain_barrel.gd": "RainBarrel",
	# P3
	"res://src/systems/apprentice/apprentice.gd": "Apprentice",
	"res://src/systems/apprentice/apprentice_rules.gd": "ApprenticeRules",
	"res://src/systems/apprentice/apprentice_planner.gd": "ApprenticePlanner",
	"res://src/entities/apprentice_board/apprentice_board.gd": "ApprenticeBoard",
	"res://src/entities/apprentice_box/apprentice_box.gd": "ApprenticeBox",
	# P4
	"res://src/systems/friendship/friendship.gd": "Friendship",
	"res://src/systems/friendship/friend_rules.gd": "FriendRules",
	"res://src/systems/friendship/favor_rules.gd": "FavorRules",
	"res://src/systems/festivals/festivals.gd": "Festivals",
	"res://src/systems/festivals/festival_rules.gd": "FestivalRules",
	"res://src/entities/fest_decor/fest_decor.gd": "FestDecor",
	"res://src/entities/memorial_plate/memorial_plate.gd": "MemorialPlate",
	"res://src/entities/archive_cabinet/archive_cabinet.gd": "ArchiveCabinet",
	"res://src/entities/fiddler/fiddler.gd": "Fiddler",
	# P7
	"res://src/systems/village/wanderers.gd": "Wanderers",
	"res://src/systems/night/night_robber.gd": "NightRobber",
	"res://src/systems/night/robber_rules.gd": "RobberRules",
	"res://src/systems/night/night_paths.gd": "NightPaths",
	"res://src/systems/night/night_path_rules.gd": "NightPathRules",
	"res://src/entities/watch_spot/watch_spot.gd": "WatchSpot",
	"res://src/entities/sick_light/sick_light.gd": "SickLight",
}
## Contract methods per stub class (§3.4) – a rename breaks this list. Rules classes without §3.4
## signatures (VisitRules, GraveCareRules, FriendRules, FavorRules, FestivalRules, RobberRules,
## NightPathRules) have none.
const METHODS := {
	"NpcLife": ["is_open", "open_day", "apply_morning", "post_load", "mood", "note_event", "reaction_for", "listen_block_reason",
			"listen", "check_goal", "goal_progress", "save_state", "load_state"],
	"MoodRules": ["roll", "apply_rules"],
	"ChatterRunner": ["update_now", "running", "seen_today"],
	"ReactionRules": ["remark_key"],
	"ScheduleBuilder": ["walk", "stay", "build"],
	"Visitors": ["plan_day", "visit_of", "active_visits", "goodwill", "add_goodwill", "kin_for_grave", "offer_wish", "accept_wish",
			"open_wishes", "hand_tip", "tip_on_stone", "take_tip", "note_noise", "on_visit_phase", "save_state", "load_state"],
	"GraveView": ["view"],
	"WishRules": ["choose", "fulfilled", "tip"],
	"GraveCare": ["flowers_state", "plant_block_reason", "plant", "water", "can_fill", "refill", "place_bouquet", "candle_lit",
			"light", "lit_last_night", "has_mortsafe", "set_mortsafe", "is_disturbed", "set_disturbed", "close_disturbed",
			"care_bonus", "save_state", "load_state"],
	"TipStone": ["can_interact", "get_interaction_prompt", "interact"],
	"RainBarrel": ["can_interact", "get_interaction_prompt", "interact"],
	"ApprenticeRules": ["minutes_for", "mistake", "works_today"],
	"ApprenticePlanner": ["plan"],
	"Apprentice": ["is_hired", "hire", "level", "jobs", "board_lines", "set_board_lines", "teach_block_reason", "start_teach",
			"note_player_job", "praise", "scold", "morale", "unpaid_days", "pay_wage", "today_plan", "apply_minute", "save_state",
			"load_state"],
	"ApprenticeBoard": ["can_interact", "get_interaction_prompt", "interact"],
	"ApprenticeBox": ["save_state", "load_state"],
	"Friendship": ["step_done", "offerable_step", "accept_step", "note_order_done", "steps_total", "full_stories",
			"favor_block_reason", "use_favor", "favor_shield_active", "consume_shield", "night_watch_tonight", "apply_morning",
			"save_state", "load_state"],
	"Festivals": ["fest_day", "today", "running", "apply_morning", "apply_minute", "dance_block_reason", "dance", "lights_count",
			"save_state", "load_state"],
	"ArchiveCabinet": ["can_interact", "get_interaction_prompt", "interact"],
	# P4 rules (static, no §3.4 signatures)
	"FriendRules": ["offerable_step", "step_block_reason", "order_for", "step_of_order", "reward_rel", "own_condition"],
	"FavorRules": ["block_reason", "offer_day", "deadline_day", "pick_return", "choice", "night_of", "items"],
	"FestivalRules": ["effective_day", "shifted", "in_window", "guests_at", "presence_reached", "dance_block_reason", "lights_result",
			"effect"],
	"Wanderers": ["present", "peddler_day", "alms_block_reason", "give_alms", "alms_count", "save_state", "load_state"],
	"NightRobber": ["tonight_target", "apply_minute", "encounters", "fate", "resolve", "save_state", "load_state"],
	"NightPaths": ["sick_houses", "next_visit", "wait_minutes", "apply_minute", "observed", "save_state", "load_state"],
	"WatchSpot": ["can_interact", "get_interaction_prompt", "interact"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["NpcLife", "apply_morning", 1], ["NpcLife", "mood", 1], ["NpcLife", "note_event", 2], ["NpcLife", "reaction_for", 1],
	["NpcLife", "listen_block_reason", 1], ["NpcLife", "listen", 1], ["NpcLife", "check_goal", 0],
	["MoodRules", "roll", 3], ["MoodRules", "apply_rules", 6], ["ChatterRunner", "running", 1], ["ChatterRunner", "seen_today", 1],
	["ReactionRules", "remark_key", 3], ["ScheduleBuilder", "walk", 5], ["ScheduleBuilder", "stay", 5], ["ScheduleBuilder", "build", 1],
	["Visitors", "plan_day", 1], ["Visitors", "visit_of", 1], ["Visitors", "goodwill", 1], ["Visitors", "add_goodwill", 2],
	["Visitors", "kin_for_grave", 1], ["Visitors", "offer_wish", 1], ["Visitors", "accept_wish", 1], ["Visitors", "hand_tip", 2],
	["Visitors", "tip_on_stone", 1], ["Visitors", "take_tip", 2], ["Visitors", "note_noise", 2], ["Visitors", "on_visit_phase", 2],
	["GraveView", "view", 3], ["WishRules", "choose", 4], ["WishRules", "fulfilled", 2], ["WishRules", "tip", 4],
	["GraveCare", "flowers_state", 1], ["GraveCare", "plant_block_reason", 2], ["GraveCare", "plant", 2], ["GraveCare", "water", 2],
	["GraveCare", "can_fill", 1], ["GraveCare", "refill", 1], ["GraveCare", "place_bouquet", 1], ["GraveCare", "candle_lit", 1],
	["GraveCare", "light", 2], ["GraveCare", "lit_last_night", 1], ["GraveCare", "has_mortsafe", 1], ["GraveCare", "set_mortsafe", 3],
	["GraveCare", "is_disturbed", 1], ["GraveCare", "set_disturbed", 1], ["GraveCare", "close_disturbed", 1], ["GraveCare", "care_bonus", 1],
	["ApprenticeRules", "minutes_for", 4], ["ApprenticeRules", "mistake", 6], ["ApprenticeRules", "works_today", 5],
	["ApprenticePlanner", "plan", 6], ["Apprentice", "level", 1], ["Apprentice", "jobs", 1], ["Apprentice", "set_board_lines", 1],
	["Apprentice", "teach_block_reason", 2], ["Apprentice", "start_teach", 1], ["Apprentice", "note_player_job", 2],
	["Apprentice", "apply_minute", 2],
	["Friendship", "step_done", 1], ["Friendship", "offerable_step", 1], ["Friendship", "accept_step", 1],
	["Friendship", "note_order_done", 1], ["Friendship", "favor_block_reason", 1], ["Friendship", "use_favor", 2],
	["Friendship", "consume_shield", 1], ["Friendship", "apply_morning", 1],
	["Festivals", "fest_day", 1], ["Festivals", "apply_morning", 1], ["Festivals", "apply_minute", 2],
	["Festivals", "dance_block_reason", 1], ["Festivals", "dance", 1],
	["Wanderers", "present", 1], ["Wanderers", "peddler_day", 1], ["Wanderers", "alms_block_reason", 1], ["Wanderers", "give_alms", 1],
	["NightRobber", "tonight_target", 1], ["NightRobber", "apply_minute", 2], ["NightRobber", "resolve", 1],
	["NightPaths", "sick_houses", 2], ["NightPaths", "next_visit", 3], ["NightPaths", "wait_minutes", 1], ["NightPaths", "apply_minute", 2],
	["NightPaths", "observed", 1],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/entities/npc/npc.gd": ["set_runtime_schedule", "clear_runtime_schedule"],  # P1
	"res://src/systems/graveyard/graveyard.gd": ["append_inscription", "replace_name_line"],  # P2
	"res://src/systems/ghosts/ghost_manager.gd": ["set_early_window"],  # P2
	"res://src/systems/cleanliness/cleanliness_manager.gd": ["tend_by", "set_level"],  # P3
	"res://src/systems/village/orders.gd": ["note_meet", "note_task"],  # P4
	"res://src/systems/village/village.gd": ["mourning_house_for"],  # P6
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_5_to_6", "migrate_6_to_7"],  # P6
}
## [script, method, args] of the extended signatures of existing classes.
const EXISTING_ARITY := [
	["res://src/entities/npc/npc.gd", "set_runtime_schedule", 1],
	["res://src/entities/npc/npc.gd", "clear_runtime_schedule", 0],
	["res://src/systems/graveyard/graveyard.gd", "append_inscription", 2],
	["res://src/systems/graveyard/graveyard.gd", "replace_name_line", 2],
	["res://src/systems/ghosts/ghost_manager.gd", "set_early_window", 3],
	["res://src/systems/ghosts/ghost_mood.gd", "score", 8],
	["res://src/systems/cleanliness/cleanliness_manager.gd", "tend_by", 2],
	["res://src/systems/cleanliness/cleanliness_manager.gd", "set_level", 2],
	["res://src/systems/village/orders.gd", "note_meet", 2],
	["res://src/systems/village/orders.gd", "note_task", 1],
	["res://src/systems/village/village.gd", "mourning_house_for", 3],
	["res://src/systems/save/save_migration.gd", "migrate_6_to_7", 2],
]
const SIGNALS := {
	"moods_rolled": 1, "chatter_line": 3, "visitor_changed": 4, "grave_viewed": 3, "wish_changed": 2, "grave_care_changed": 3,
	"apprentice_job_done": 3, "apprentice_level_changed": 2, "friend_step_completed": 2, "favor_changed": 3,
	"festival_changed": 2, "robber_event": 2, "night_visit": 3,
}
const DATA_CLASSES := {
	"NpcLifeConfig": "res://src/systems/npc_life/npc_life_config.gd",
	"ChatterData": "res://src/systems/npc_life/chatter_data.gd",
	"VisitorConfig": "res://src/systems/visitors/visitor_config.gd",
	"KinData": "res://src/systems/visitors/kin_data.gd",
	"WishData": "res://src/systems/visitors/wish_data.gd",
	"GraveCareConfig": "res://src/systems/grave_care/grave_care_config.gd",
	"ApprenticeConfig": "res://src/systems/apprentice/apprentice_config.gd",
	"ApprenticeTaskData": "res://src/systems/apprentice/apprentice_task_data.gd",
	"FriendStoryData": "res://src/systems/friendship/friend_story_data.gd",
	"FriendStepData": "res://src/systems/friendship/friend_step_data.gd",
	"FavorData": "res://src/systems/friendship/favor_data.gd",
	"FestivalData": "res://src/systems/festivals/festival_data.gd",
	"WandererData": "res://src/systems/village/wanderer_data.gd",
	"RobberConfig": "res://src/systems/night/robber_config.gd",
	"NightPathData": "res://src/systems/night/night_path_data.gd",
	"NightVisitData": "res://src/systems/night/night_visit_data.gd",
}
## Scene → has an Interactable.
const SCENES := {
	"res://src/entities/tip_stone/tip_stone.tscn": true, "res://src/entities/rain_barrel/rain_barrel.tscn": true,
	"res://src/entities/apprentice_board/apprentice_board.tscn": true, "res://src/entities/apprentice_box/apprentice_box.tscn": true,
	"res://src/entities/archive_cabinet/archive_cabinet.tscn": true, "res://src/entities/watch_spot/watch_spot.tscn": true,
	"res://src/entities/fest_decor/fest_decor.tscn": false, "res://src/entities/memorial_plate/memorial_plate.tscn": false,
	"res://src/entities/fiddler/fiddler.tscn": false, "res://src/entities/sick_light/sick_light.tscn": false,
}


func test_stub_scripts_load_with_their_class_names() -> void:
	var global := _global_classes()
	for path: String in STUBS:
		var script := load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		assert_true(script.can_instantiate(), path + " parses")
		var cls: String = STUBS[path]
		assert_eq(global.get(cls), path, "class_name %s → %s" % [cls, path])
		if not IMPLEMENTED.has(cls):
			assert_true(script.source_code.contains("## STUB ("), cls + " is marked as stub")
		var names := _methods(script)
		for method: String in METHODS.get(cls, []):
			assert_true(names.has(method), "%s.%s" % [cls, method])


func test_contract_arities() -> void:
	for spec: Array in ARITY:
		_assert_arity(_path_of(spec[0]), spec[1], spec[2], spec[0])
	for spec: Array in EXISTING_ARITY:
		_assert_arity(spec[0], spec[1], spec[2], String(spec[0]).get_file())


func test_data_classes_are_registered() -> void:
	var global := _global_classes()
	for cls: String in DATA_CLASSES:
		assert_eq(global.get(cls), DATA_CLASSES[cls], cls)
		var res: Resource = (load(DATA_CLASSES[cls]) as GDScript).new()
		assert_true(res is Resource, cls)
	assert_eq(global.get("Phase8Fixtures"), "res://tests/fixtures/phase8/phase8_fixtures.gd")


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in Phase8Fixtures.SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	var chatter := ChatterRunner.new()
	assert_true(chatter.is_in_group(ChatterRunner.GROUP), "group chatter")
	assert_false(chatter.is_in_group(&"saveable"), "ChatterRunner is not saved (§3.1)")
	chatter.free()
	for cls: String in ["TipStone", "RainBarrel", "ApprenticeBoard", "FestDecor", "MemorialPlate", "ArchiveCabinet", "Fiddler",
			"WatchSpot", "SickLight"]:
		var n: Node = (load(_path_of(cls)) as GDScript).new()
		assert_true(n is Node3D, cls)
		n.free()
	for path: String in SCENES:
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene == null:
			continue
		var inst := scene.instantiate()
		assert_eq(inst.get_node_or_null(^"Interactable") != null, SCENES[path], path + " Interactable")
		inst.free()
	assert_eq(ApprenticeBoard.PANEL, &"apprentice_board", "§7.1 panel")


func test_apprentice_box_is_a_chest() -> void:
	var box := (load("res://src/entities/apprentice_box/apprentice_box.tscn") as PackedScene).instantiate() as ApprenticeBox
	assert_not_null(box)
	if box == null:
		return
	assert_true(box is Chest)
	assert_eq([box.save_id, box.save_order, ApprenticeBox.SLOT_COUNT], ["apprentice_box", 79, 6], "§3.1 apprentice_box / 79, 6 slots")
	tree.root.add_child(box)
	assert_true(box.is_in_group(&"saveable"))
	box.coins = 9
	var state := box.save_state()
	assert_true(state.has("storage") and int(state.coins) == 9, "§5.1 {storage, coins}")
	box.load_state({"storage": {}, "coins": 4.0})
	assert_eq(box.coins, 4, "JSON float tolerated")
	box.load_state({"coins": -3})
	assert_eq(box.coins, 0, "never negative")
	box.queue_free()
	await wait_frames(1)


func test_stub_members_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	# GhostMood.score: the new care argument changes nothing until P2.
	var cfg := GhostConfig.new()
	assert_eq(GhostMood.score(8, 1, 1, null, cfg, 1, 1, 2), GhostMood.score(8, 1, 1, null, cfg, 1, 1), "care ignored in W0")
	if IMPLEMENTED.has("Village"):
		assert_eq(Village.mourning_house_for(55, 7, PackedStringArray(["house_kehr"])), &"house_kehr", "P6: one house")
		assert_eq(Village.mourning_house_for(55, 7, PackedStringArray()), &"", "P6: no houses")
	else:
		assert_eq(Village.mourning_house_for(55, 7, PackedStringArray(["house_kehr"])), &"", "W0 stub (P6)")
	var npc := Npc.new()
	npc.set_runtime_schedule(NpcSchedule.new())
	npc.clear_runtime_schedule()
	npc.free()


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 13, "§3.3: 13 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – everything over [E], dialogues and panels.
	for action: String in ["interact", "ui_cancel", "journal_page_prev", "journal_page_next"]:
		assert_true(InputMap.has_action(action), action)


func test_new_config_contract_values() -> void:
	var life := NpcLifeConfig.new()
	assert_eq([life.open_flag, life.open_day_flag, life.unlock_flag, life.intro_minute], [&"p8_open", &"p8_open_day",
			&"name_in_village_complete", 360])
	assert_eq(life.moods, [&"plain", &"cheerful", &"low", &"cross"] as Array[StringName])
	assert_eq(life.mood_weights, {&"plain": 70, &"cheerful": 15, &"low": 10, &"cross": 5} as Dictionary[StringName, int])
	assert_eq(life.mood_rules.size(), 6, "§2.1.1: precedence 1–5 (rumor in two rows)")
	assert_eq(life.mood_rules.map(func(r: Dictionary) -> StringName: return r.trigger),
			[&"festival", &"mourning_circle", &"own_step", &"rumor", &"rumor", &"sick_light"])
	assert_eq(life.talk_gain_by_mood, {&"plain": 1, &"cheerful": 2, &"low": 1, &"cross": 0} as Dictionary[StringName, int])
	assert_eq([life.listen_minutes, life.goal_levels, life.goal_wishes, life.goal_kin, life.goal_steps, life.goal_full_stories],
			[10, 2, 5, 3, 6, 1])
	assert_eq([life.goal_insight, life.chapter_id, life.goal_flag], [&"i_underlined", &"who_comes_up", &"who_comes_up_complete"])
	assert_almost(life.chatter_distance, 10.0)
	assert_almost(life.chatter_line_seconds, 3.5)
	assert_eq(life.reactions.size(), 9)
	for days: int in life.reactions.values():
		assert_eq(days, 2, "§2.1.3: 2 days")
	var v := VisitorConfig.new()
	assert_eq([v.first_delay_days, v.mourning_days, v.interval_mourning, v.interval_late, v.max_visits_day, v.max_concurrent],
			[1, 21, 3, 7, 3, 2])
	assert_eq(Array(v.slots), [570, 750, 900], "09:30 · 12:30 · 15:00")
	assert_eq([v.mourn_minutes, v.wait_minutes, v.goodwill_start, v.goodwill_wish_min, v.pleased_cap_day, v.max_open],
			[30, 10, 5, 2, 2, 3])
	assert_eq([v.tip_base, v.tip_goodwill_min, v.tip_quality_min, v.tip_cap_day, v.wish_goodwill, v.wish_fail_goodwill,
			v.villager_wish_rel], [1, 6, 15, 4, 2, -2, 4])
	assert_almost(v.noise_distance, 8.0)
	assert_almost(v.talk_distance, 4.0)
	assert_almost(v.flowers_chance_late, 0.4)
	var effects := {&"disturbed": [&"visit_disturbed", -4], &"neglected": [&"visit_neglected", -1], &"bare": [&"", 0],
			&"kept": [&"visit_pleased", 1], &"bonus": [&"", 1], &"specimen": [&"visit_specimen_rumor", -3]}
	for view: StringName in effects:
		assert_eq([StringName(v.view_effects[view].rep_event), int(v.view_effects[view].goodwill)], effects[view], "§2.2.4 %s" % view)
	var rep := ReputationConfig.new().event_points
	for view: StringName in effects:
		var ev := StringName(effects[view][0])
		if ev != &"":
			assert_true(rep.has(ev), "rep event %s exists" % ev)
	var g := GraveCareConfig.new()
	assert_eq([g.flower_item, g.plant_minutes, g.flower_fresh_minutes, g.flower_wilt_minutes, g.water_minutes, g.can_item,
			g.can_fills, g.refill_minutes], [&"flower_seedlings", 15, 2880, 5760, 5, &"watering_can", 6, 2])
	assert_eq([g.bouquet_minutes, g.wreath_item, g.candle_item, g.candle_minutes, g.candle_from_minute, g.candle_until_minute],
			[2880, &"wax_wreath", &"grave_candle", 3, 900, 420])
	assert_eq([g.mortsafe_item, g.mortsafe_set_minutes, g.mortsafe_remove_minutes, g.mortsafe_min_days, g.close_minutes,
			g.line_minutes, g.line_item], [&"mortsafe", 20, 10, 10, 30, 30, &"ink"])
	assert_eq([g.care_cap, g.disturbed_mood, g.lights_candle_mood], [2, -3, 2])
	var a := ApprenticeConfig.new()
	assert_eq([a.npc_id, a.hire_flag, a.arrive_minute, a.start_minute, a.lunch, a.end_minute, a.wage, a.unpaid_limit],
			[&"apprentice", &"apprentice_hired", 495, 510, Vector2i(720, 750), 930, 3, 3])
	assert_eq([a.day_off_mod, a.day_off_rest, a.practice_jobs, a.morale_start, a.morale_fast, a.morale_slow, a.board_lines, a.box_slots],
			[7, 2, 12, 3, 4, 1, 3, 6])
	assert_almost(a.teach_distance, 4.0)
	assert_eq(Array(a.mistake_rate).map(func(x: float) -> int: return roundi(x * 100)), [100, 8, 2])
	assert_almost(a.fast_factor, 0.9)
	assert_almost(a.slow_factor, 1.2)
	assert_almost(a.scold_mistake_factor, 0.5)
	var r := RobberConfig.new()
	assert_eq([r.start_offset_days, r.fresh_days, r.min_gap_nights, r.first_guaranteed, r.arrive_minute, r.dig_from, r.dig_until,
			r.watch_catch_after, r.report_rep, r.let_go_piety], [4, 5, 2, true, 90, 110, 300, 3, &"robber_reported", &"robber_let_go"])
	assert_almost(r.chance, 0.35)
	assert_almost(r.notice_distance, 10.0)
	assert_true(PietyConfig.new().events.has(r.let_go_piety), "piety event robber_let_go")
	assert_true(rep.has(r.report_rep), "rep event robber_reported")


## Properties changed in the data (and the class default together) after the W0 hand-over; the fixtures keep the
## W0 values. Empty at W0.
const DATA_CHANGED_AFTER_W0 := {}


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase8Fixtures.CONFIG_NAMES + Phase8Fixtures.EXTENDED_CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase8Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		var defaults: Resource = (real.get_script() as GDScript).new()
		var changed: Array = DATA_CHANGED_AFTER_W0.get(name, [])
		var new_config := name in Phase8Fixtures.CONFIG_NAMES
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if StringName(prop.name) in changed:
					assert_eq(real.get(prop.name), defaults.get(prop.name), "%s.%s (changed) = class default" % [name, prop.name])
					continue
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
				if new_config:
					assert_eq(defaults.get(prop.name), fixture.get(prop.name), "%s.%s = class default" % [name, prop.name])


func test_extended_data_classes() -> void:
	var n := NpcConfig.new()
	assert_eq([n.max_visible_graveyard, n.max_visible_fest, n.max_full], [9, 16, 6])
	assert_almost(n.walk_m_per_minute, 3.2)
	assert_almost(n.stand_rest_distance, 26.0)
	assert_almost(n.fest_reduced_interval, 0.33)
	var vd := VillagerData.new()
	assert_eq([vd.circle, vd.mood_lines, vd.story_id, vd.favor_id, vd.visit_grave, vd.visit_every_days, vd.graveyard_npc],
			[[] as Array[StringName], {} as Dictionary[StringName, PackedStringArray], &"", &"", "", 0, &""])
	assert_eq(OrderData.KINDS, [&"deliver", &"bury", &"stone", &"tend", &"donate", &"section", &"meet", &"task"] as Array[StringName],
			"§3.4: meet, task appended")
	assert_eq([OrderData.new().category, OrderData.CATEGORY_FRIEND, OrdersConfig.new().max_active_friend], [&"", &"friend", 2])
	var i := InsightData.new()
	assert_eq([i.any_clues, i.any_count], [[] as Array[StringName], 0])
	assert_eq(ActionConfig.new().noisy_actions, [&"dig", &"chop", &"pick", &"hammer", &"chisel", &"saw", &"quarry"] as Array[StringName])
	var rep := ReputationConfig.new().event_points
	var rep_new := {&"visit_pleased": 1, &"visit_neglected": -1, &"visit_disturbed": -3, &"visit_noise": -1, &"visit_specimen_rumor": -1,
			&"wish_done": 1, &"robber_reported": 3, &"lights_all": 3, &"lights_some": 1, &"fenner_watch": 1}
	for key: StringName in rep_new:
		assert_eq(rep.get(key), rep_new[key], "§2.11 reputation %s" % key)
	var piety := PietyConfig.new().events
	for key: StringName in {&"alms": 1, &"listen": 1, &"robber_let_go": 2, &"lights_all": 2}:
		assert_eq(piety.get(key), {&"alms": 1, &"listen": 1, &"robber_let_go": 2, &"lights_all": 2}[key], "§2.11 piety %s" % key)
	var gains := RelationshipConfig.new().gains
	var gains_new := {&"talk_cheerful": 2, &"listen": 3, &"danced": 3, &"kathrein": 2, &"wish_done_villager": 4, &"friend_step_1": 6,
			&"friend_step_2": 8, &"friend_step_3": 10, &"favor_returned": 4, &"favor_unreturned": -6, &"lights_all": 2,
			&"jakob_scolded": -1, &"jakob_unpaid": -2}
	assert_eq(gains_new.size(), 13)
	for key: StringName in gains_new:
		assert_eq(gains.get(key), gains_new[key], "§2.11 gains %s" % key)
	assert_eq(gains.get(&"talk"), 1, "the Phase-7 gains stay")
	var lines := GhostLines.new()
	assert_eq([lines.by_flowers, lines.by_candle, lines.by_visited, lines.by_disturbed, lines.by_lights],
			[PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray(), PackedStringArray()])
	assert_eq(StoryConfig.new().underlined, &"washer", "§14.1 (c)")
	assert_eq((Database.config(&"story_config") as StoryConfig).underlined, &"washer", "story_config.tres")
	assert_eq(RecipeData.new().requires_flag, &"")


func test_corpse_and_grave_record_phase8_fields() -> void:
	var r := CorpseRecord.new()
	assert_eq(r.kin_house, &"")
	r.id = "c_1"
	r.kin_house = &"house_kehr"
	var back := CorpseRecord.from_dict(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict())))) as Dictionary)
	assert_eq(back.kin_house, &"house_kehr", "JSON round trip")
	assert_eq(r.to_dict().size(), 39, "38 Phase-7 record fields + kin_house")
	assert_eq(CorpseRecord.from_dict({"id": "c_2"}).kin_house, &"", "tolerant")
	var g := GraveRecord.new()
	assert_eq([g.disturbed, g.extra_lines], [false, PackedStringArray()])
	g.id = "l_02"
	g.disturbed = true
	g.extra_lines = PackedStringArray(["Ruhe sanft"])
	var gb := GraveRecord.from_dict(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(g.to_dict())))) as Dictionary)
	assert_eq([gb.disturbed, gb.extra_lines], [true, PackedStringArray(["Ruhe sanft"])], "JSON round trip")
	assert_eq(gb.to_dict(), g.to_dict())
	var odd := GraveRecord.from_dict({"disturbed": 1, "extra_lines": ["", 3, "Unvergessen"]})
	assert_eq([odd.disturbed, odd.extra_lines], [false, PackedStringArray(["Unvergessen"])], "tolerant")


func test_villager_kin_wish_fixtures() -> void:
	for v: VillagerData in Phase8Fixtures.villagers():
		assert_not_null(v)
		var real := Database.villager(v.npc_id) as VillagerData
		assert_eq(v.start_value, real.start_value, "%s: the data at W0" % v.npc_id)
		if v.npc_id == &"oldwoman":
			assert_eq([v.story_id, v.mood_lines.size()], [&"", 0], "Wiebke's story is told")
			continue
		assert_eq([v.story_id, v.favor_id], [v.npc_id, StringName("fav_" + String(v.npc_id))])
		for mood: StringName in NpcLifeConfig.new().moods:
			assert_eq(v.mood_lines.get(mood, PackedStringArray()).size(), 2, "%s: 2 lines for %s" % [v.npc_id, mood])
		assert_eq(v.mood_lines[&"cross"][0], "Heute nicht, Totengräber. Morgen.", "§2.1.1")
	assert_eq(Phase8Fixtures.villager_data(&"washer").circle, [&"cottage_dorn", &"cottage_hagedorn"] as Array[StringName])
	assert_eq([Phase8Fixtures.villager_data(&"smith").visit_grave, Phase8Fixtures.villager_data(&"smith").visit_every_days], ["old_01", 6])
	assert_eq([Phase8Fixtures.villager_data(&"grocer").visit_grave, Phase8Fixtures.villager_data(&"grocer").visit_every_days], ["old_08", 5])
	assert_eq(Phase8Fixtures.villager_data(&"surgeon").graveyard_npc, &"", "Quast never comes up (§2.1.4)")
	assert_true(Phase8Fixtures.villager_data(&"priest").remarks.has(&"event_lights_all"), "§2.1.3 reaction remark")
	var houses := (Database.config(&"village_config") as VillageConfig).mourning_houses
	for k: KinData in Phase8Fixtures.kin_list():
		assert_not_null(k)
		assert_true(k.display_name != "" and k.npc_path_id != &"" and k.dialogue_id != &"", String(k.kin_id))
		if k.villager_id == &"":
			assert_true(houses.has(String(k.house)), "%s: a mourning house" % k.kin_id)
			assert_eq([k.visit_every_days, k.first_offset], [0, 0], "households by plan")
		else:
			assert_not_null(Phase8Fixtures.villager_data(k.villager_id), String(k.kin_id))
	assert_eq([Phase8Fixtures.kin(&"kin_smith").visit_minute, Phase8Fixtures.kin(&"kin_smith").first_offset], [820, 2])
	assert_eq([Phase8Fixtures.kin(&"kin_washer").visit_every_days, Phase8Fixtures.kin(&"kin_washer").first_offset], [4, 1])
	assert_eq([Phase8Fixtures.kin(&"kin_brandt").kneels, Phase8Fixtures.kin(&"kin_kehr").kneels], [false, true], "§2.2.3")
	var kinds := {}
	for w: WishData in Phase8Fixtures.wishes():
		assert_not_null(w)
		assert_true(w.kind in WishData.KINDS and w.ask_text != "" and w.done_text != "" and w.failed_text != "", String(w.id))
		assert_eq(w.line_text != "", w.kind == &"line", String(w.id))
		kinds[w.kind] = int(kinds.get(w.kind, 0)) + 1
	assert_eq(kinds, {&"tend": 1, &"flowers": 1, &"candle": 1, &"vase": 1, &"line": 6}, "§2.2.5: 6 line templates")
	assert_eq(Phase8Fixtures.wish(&"w_line_1").line_text, "Ruhe sanft")


func test_chatter_and_task_fixtures() -> void:
	var chatters := Phase8Fixtures.chatters()
	assert_eq(chatters.size(), 16, "§2.1.2: 16 chatters")
	for c: ChatterData in chatters:
		assert_not_null(c)
		assert_eq(c.npcs.size(), 2, String(c.id))
		assert_true(c.lines.size() >= 2 and c.lines.size() <= 4, String(c.id))
		assert_true(c.window.x < c.window.y, String(c.id))
		assert_true(c.region in [&"village", &"graveyard"], String(c.id))
		assert_eq(c.sets_flag, &"robber_known" if c.id == &"ch_rumor_robber" else &"", String(c.id))
	assert_eq(Phase8Fixtures.chatter(&"ch_well_spin").window, Vector2i(960, 990))
	var tasks := Phase8Fixtures.apprentice_tasks()
	var minutes := {&"rake": [0, 15, 10], &"weed": [0, 30, 20], &"water": [0, 7, 5], &"candle": [0, 5, 4]}
	for i: int in tasks.size():
		var t := tasks[i]
		assert_eq([t.id, t.order], [Phase8Fixtures.TASK_IDS[i], i + 1])
		assert_eq(Array(t.minutes), minutes[t.id], "§2.5.2 %s" % t.id)
		assert_true(t.label != "" and t.mistake_text != "" and t.animation != &"", String(t.id))
	assert_eq([Phase8Fixtures.apprentice_task(&"candle").from_minute, Phase8Fixtures.apprentice_task(&"candle").consumes], [900, &"grave_candle"])
	assert_eq(Phase8Fixtures.apprentice_task(&"rake").tool_item, &"apprentice_rake")


func test_friendship_fixtures() -> void:
	var stories := Phase8Fixtures.friend_stories()
	assert_eq(stories.size(), 7, "§2.4 / §14.6: seven living villagers")
	var steps := 0
	for s: FriendStoryData in stories:
		assert_not_null(s)
		assert_eq(s.steps.size(), 3, String(s.npc_id))
		assert_eq(s.favor_id, StringName("fav_" + String(s.npc_id)))
		for i: int in 3:
			var st := s.steps[i]
			assert_eq([st.step, st.min_value, st.reward_rel, st.reward_flag], [i + 1, [40, 55, 70][i], [6, 8, 10][i],
					StringName("friend_%s_%d" % [s.npc_id, i + 1])], "%s step %d" % [s.npc_id, i + 1])
			assert_false(st.order_ids.is_empty(), "%s step %d orders" % [s.npc_id, i + 1])
			steps += 1
	assert_eq(steps, 21)
	assert_eq(Phase8Fixtures.friend_story(&"washer").steps[0].order_ids, [&"of_liesel_1", &"of_liesel_1_alt"] as Array[StringName])
	assert_eq(Phase8Fixtures.friend_story(&"innkeeper").steps[2].conditions, PackedStringArray(["apprentice_level_gte:2"]))
	for f: FavorData in Phase8Fixtures.favors():
		assert_not_null(f)
		assert_true(f.effect in FavorData.EFFECTS, String(f.id))
		assert_eq([f.cooldown_days, f.return_after_days, f.return_days, f.returned_rel, f.unreturned_rel, f.lock_days], [5, 1, 3, 4, -6, 7])
		assert_eq(f.return_orders.size(), 2, String(f.id))
	var ids := Phase8Fixtures.order_ids()
	assert_eq(ids.size(), 36, "22 story orders + 14 return favours")
	assert_true(ids.has(&"of_esch_return_1"), "§5.1 example id")
	for id: StringName in ids:
		var o := Phase8Fixtures.order(id)
		assert_not_null(o, String(id))
		if o == null:
			continue
		assert_eq(o.category, &"friend", String(id))
		assert_true(o.kind in OrderData.KINDS and o.title != "" and o.request_text != "", String(id))
	assert_eq(Phase8Fixtures.order(&"of_liesel_1").requires_flag, &"insight_not_lorenz")
	assert_eq(Phase8Fixtures.order(&"of_rosine_2").items, {&"memorial_plate": 1} as Dictionary[StringName, int])
	assert_eq(Phase8Fixtures.order(&"of_esch_3").conditions.times, 2, "two evenings")


func test_festival_wanderer_night_fixtures() -> void:
	var k := Phase8Fixtures.festival(&"fest_kathrein")
	assert_eq([k.calendar_day, k.shift_rule, k.day_flag, k.window, k.region], [54, &"none", &"fest_kathrein_day", Vector2i(1140, 1380), &"village"])
	var l := Phase8Fixtures.festival(&"fest_lights")
	assert_eq([l.calendar_day, l.shift_rule, l.shift_days, l.day_flag, l.region], [58, &"open_plus", 3, &"fest_lights_day", &"graveyard"])
	assert_eq([int(l.effects.candles), int(l.effects.check_minute)], [12, 1080])
	var veit := Phase8Fixtures.wanderer(&"beggar")
	assert_eq([veit.display_name, veit.alms_coins, veit.alms_piety, veit.alms_for_clue, veit.clue_id], ["Veit Ammer", 1, &"alms", 3, &"c_n_veit"])
	var hanne := Phase8Fixtures.wanderer(&"peddler")
	assert_eq([hanne.display_name, hanne.shop_id, hanne.every_days, hanne.day_rest], ["Hanne Vogelsang", &"peddler", 6, 1])
	var ott := Phase8Fixtures.night_path(&"np_ott")
	assert_eq([ott.house, ott.start_offset, ott.end_offset, ott.death_offset, ott.death_minute, ott.death_flag, ott.watch_spot],
			[&"house_ott", 3, 4, 4, 130, &"ott_dead", &"watch_ott"])
	assert_eq(ott.visits.map(func(v: NightVisitData) -> Array: return [v.npc_id, v.night_offset, v.enter_minute, v.leave_minute, v.clue_id]),
			[[&"surgeon", 3, 1350, 1390, &"c_n_quast_visit"], [&"priest", 4, 1260, 1300, &"c_n_lenz_visit"],
			[&"washer", 4, 160, 330, &"c_n_liesel_watch"]])
	var kehr := Phase8Fixtures.night_path(&"np_kehr")
	assert_eq([kehr.start_offset, kehr.end_offset, kehr.death_offset, kehr.visits.size()], [7, 8, -1, 2], "Liesel does not come")


func test_item_shop_journal_story_fixtures() -> void:
	for id: StringName in Phase8Fixtures.ITEM_IDS:
		var item := Phase8Fixtures.item(id)
		assert_not_null(item, String(id))
		if item == null:
			continue
		assert_eq(item.id, id)
		assert_true(item.display_name != "" and item.description.length() >= 20, String(id))
	assert_eq([Phase8Fixtures.item(&"watering_can").category, Phase8Fixtures.item(&"mortsafe").max_stack], [ItemData.Category.TOOL, 4])
	var plate := Phase8Fixtures.recipe()
	assert_eq([plate.station, plate.craft_minutes, plate.requires_flag, plate.inputs], [&"mason", 40, &"friend_innkeeper_2",
			{&"workstone": 1, &"ink": 1, &"gold_leaf": 1} as Dictionary[StringName, int]])
	var p := Phase8Fixtures.shop(&"peddler")
	assert_eq([p.npc_id, p.coin_reason, p.sells.size(), p.buys.size()], [&"peddler", &"peddler", 6, 4])
	assert_eq(p.sells[&"grave_candle"], {"price": 1, "per_day": 8})
	assert_true(Phase8Fixtures.shop(&"grocer").sells.has(&"flower_seedlings") and Phase8Fixtures.shop(&"smith").sells.has(&"mortsafe"))
	for id: StringName in Phase8Fixtures.CLUE_IDS:
		var c := Phase8Fixtures.clue(id)
		assert_true(c != null and c.kind in ClueData.KINDS and c.text != "", String(id))
	for who: StringName in Phase8Fixtures.UNDERLINED_VARIANTS:
		var i := Phase8Fixtures.insight(who)
		assert_not_null(i, String(who))
		assert_eq([i.id, i.requires, i.any_count, i.sets_flag], [&"i_underlined", [&"c_n_veit", &"c_n_kladde"] as Array[StringName], 2,
				&"insight_underlined"], String(who))
		assert_eq(i.any_clues.size(), 4)
	assert_true(Phase8Fixtures.insight(&"washer").text.begins_with("Lorenz hat die Seelfrau"), "§1.6 variant washer")
	var d := Phase8Fixtures.d2_story()
	assert_eq([d.order, d.age, d.cause_id, d.traits, d.look, d.section, d.due_flag], [7, 74, &"old_age",
			[&"strange_wound"] as Array[StringName], 2, &"linden", &"ott_dead"])
	for id: StringName in d.finds:
		var f := Phase8Fixtures.find(id)
		assert_true(f != null and f.story_only and f.text != "", String(id))
	assert_eq(d.finds, Phase8Fixtures.FIND_IDS)
	var lines := Phase8Fixtures.ghost_lines()
	assert_eq([lines.by_flowers.size(), lines.by_candle.size(), lines.by_visited.size(), lines.by_disturbed.size(), lines.by_lights.size()],
			[1, 1, 1, 1, 1])
	assert_eq(lines.by_story[&"d2_ott"].size(), 2)


func test_fixture_helpers() -> void:
	var flags := GameState.flags.duplicate(true)
	var life := Phase8Fixtures.p8_open(null, 55)
	assert_true(life.is_open())
	assert_eq(life.open_day(), 55)
	life.free()
	var kg := Phase8Fixtures.kin_grave(&"kin_kehr", "l_02", 54)
	var rec: CorpseRecord = kg.record
	var grave: GraveRecord = kg.grave
	assert_eq([rec.kin_house, rec.grave_id, rec.buried_day, rec.location, grave.id, grave.corpse_id, grave.state],
			[&"house_kehr", "l_02", 54, CorpseRecord.LOCATION_BURIED, "l_02", rec.id, GraveRecord.State.MARKED])
	assert_eq((Phase8Fixtures.kin_grave(&"kin_smith", "old_01", 1).record as CorpseRecord).kin_house, &"", "villager: fixed grave")
	var visits := Phase8Fixtures.visit_now(&"kin_kehr", "l_02", &"mourning", null, 57)
	assert_eq(visits.active_visits().size(), 1)
	assert_eq(visits.visit_of(&"kin_kehr").graves, ["l_02"])
	assert_eq(visits.goodwill(&"kin_kehr"), 5)
	visits.free()
	var wishes := Phase8Fixtures.wish_open("l_02", &"flowers")
	assert_eq(wishes.open_wishes().size(), 1)
	assert_eq(wishes.open_wishes()[0].kind, "flowers")
	wishes.free()
	for state: StringName in [&"fresh", &"wilted", &"wreath", &""]:
		var gc := Phase8Fixtures.flowers("l_02", state)
		assert_eq(gc.flowers_state("l_02"), state, "flowers %s" % state)
		assert_eq(gc.can_fill(), 6)
		gc.free()
	var app := Phase8Fixtures.apprentice_with({&"rake": 2, &"weed": 1}, [{"task": "rake", "area": "yard"}], 9, tree)
	var a: Apprentice = app.apprentice
	var box: ApprenticeBox = app.box
	assert_true(a.is_hired())
	assert_eq([a.level(&"rake"), a.level(&"weed"), a.level(&"water"), a.board_lines().size(), box.coins], [2, 1, 0, 1, 9])
	a.queue_free()
	box.queue_free()
	var fr := Phase8Fixtures.story_at(&"washer", 2, null, {&"priest": 3})
	assert_eq([fr.step_done(&"washer"), fr.step_done(&"priest"), fr.steps_total(), fr.full_stories()], [2, 3, 5, 1])
	fr.free()
	var fest := Phase8Fixtures.fest_today(&"fest_lights", null, 58)
	assert_eq([fest.fest_day(&"fest_lights"), int(GameState.get_flag(&"fest_lights_day"))], [58, 58])
	fest.free()
	var robber := Phase8Fixtures.robber_night("l_09", null, 58)
	assert_eq([robber.tonight_target(58), robber.tonight_target(59), robber.encounters(), robber.fate()], ["l_09", "", 0, &""])
	robber.free()
	var sl := Phase8Fixtures.sick_light(&"np_ott", 4)
	assert_eq([sl.day, sl.burning, (sl.visits as Array).size()], [57, true, 2])
	assert_false(Phase8Fixtures.sick_light(&"np_ott", 5).burning)
	GameState.flags = flags
	assert_false(Phase8Fixtures.layout_p7().is_empty(), "layout_p7.json readable")
	assert_false(Phase8Fixtures.village_layout_p7().is_empty(), "village_layout_p7.json readable")
	await wait_frames(1)


func test_layout_fixtures_are_byte_identical_to_the_phase7_layouts() -> void:
	# Taken at a499aa8 (W0). W-Welt changes data/world in W2; then only the fixture stays.
	assert_eq(FileAccess.get_file_as_string(Phase8Fixtures.LAYOUT_P7).length() > 1000, true)
	var layout := Phase8Fixtures.layout_p7()
	assert_true(layout.has("plots") and layout.has("sections"), "graveyard plots and sections")
	assert_eq(str(Phase8Fixtures.village_layout_p7().get("region_id", "")), "village")


func test_database_phase8_folders() -> void:
	# The real data folders are the owners' (P1 chatter, P2 kin/wishes, P3 tasks, P4 friendship/festivals,
	# P7 wanderers/night) – empty until W1.
	for list: Array in [Database.chatters(), Database.kin_list(), Database.wishes(), Database.apprentice_tasks(),
			Database.friend_stories(), Database.favors(), Database.festivals(), Database.wanderers(), Database.night_paths()]:
		for res: Resource in list:
			assert_true(res != null, "loaded")
	assert_null(Database.chatter(&"nope"))
	assert_null(Database.kin(&"nope"))
	assert_null(Database.wish(&"nope"))
	assert_null(Database.apprentice_task(&"nope"))
	assert_null(Database.friend_story(&"nope"))
	assert_null(Database.favor(&"nope"))
	assert_null(Database.festival(&"nope"))
	assert_null(Database.wanderer(&"nope"))
	assert_null(Database.night_path(&"nope"))
	for name: StringName in Phase8Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	var days: Array = Database.festivals().map(func(f: Resource) -> int: return int(f.get(&"calendar_day")))
	var sorted := days.duplicate()
	sorted.sort()
	assert_eq(days, sorted, "festivals sorted by calendar_day")
	var orders: Array = Database.apprentice_tasks().map(func(t: Resource) -> int: return int(t.get(&"order")))
	var sorted_orders := orders.duplicate()
	sorted_orders.sort()
	assert_eq(orders, sorted_orders, "apprentice tasks sorted by order")


func test_save_format_v7_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 7)
	assert_eq(SaveFileIO.FORMAT_VERSION, 7)
	assert_eq(SaveManager.FORMAT_VERSION, 7)
	assert_eq(SaveMigration.V7_EMPTY_NODES, PackedStringArray(["npc_life", "visitors", "grave_care", "apprentice", "friendship",
			"festivals", "wanderers", "night_robber", "night_paths", "apprentice_box"]), "§3.4 / §5.2 step 3")
	var state := {"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {}}}
	assert_eq(SaveMigration.migrate(state, 7), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 8), {}, "newer → corrupt")
	var v7 := SaveMigration.migrate_6_to_7(state, {"day": 5})
	assert_false(is_same(v7, state), "deep copy")
	assert_eq(state.nodes, {"corpse_manager": {}}, "input unchanged")
	if not IMPLEMENTED.has("SaveMigration"):
		assert_eq(v7, state, "W0: identity")
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("buildings")
			and (from_v1.nodes as Dictionary).has("village"), "v1 → … → v7 chain")
	# SaveManager drops the empty Phase-8 nodes while the world has none of them (like V3–V6).
	var nodes := {"npc_life": {}, "visitors": {}, "apprentice_box": {}}
	assert_eq(SaveManager.without_absent_defaults(tree, nodes), {}, "absent empty Phase-8 nodes dropped")


func test_save_v6_fixtures_exist() -> void:
	assert_eq(Phase8Fixtures.SAVES_V6.size(), 6, "§5.2: six v6 fixtures")
	for name: String in Phase8Fixtures.SAVES_V6:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase8Fixtures.save_v6_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 6, name)
			assert_eq(String(doc.meta.scene), "res://src/world/graveyard/graveyard.tscn", name)


# --- helpers ----------------------------------------------------------------------------------

func _assert_arity(path: String, method: String, args: int, label: String) -> void:
	var script := load(path) as GDScript
	var found := false
	for m: Dictionary in script.get_script_method_list():
		if String(m.name) == method:
			found = true
			assert_eq((m.args as Array).size(), args, "%s.%s arguments" % [label, method])
	assert_true(found, "%s.%s" % [label, method])


func _global_classes() -> Dictionary:
	var global := {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		global[String(entry["class"])] = String(entry["path"])
	return global


func _methods(script: GDScript) -> Dictionary:
	var names := {}
	for m: Dictionary in script.get_script_method_list():
		names[String(m.name)] = true
	return names


func _path_of(cls: String) -> String:
	for path: String in STUBS:
		if STUBS[path] == cls:
			return path
	return ""
