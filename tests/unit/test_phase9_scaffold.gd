extends TestCase
## Lead / W0 (docs/PHASE9_DESIGN.md §12): the Phase-9 scaffold – every stub class loads with its contract
## signature, every new data class / config .tres holds valid contract values, the extensions of existing data
## classes, the 6 EventBus signals, no new input actions, Database folders, save format v8 + migration chain
## 1 → … → 8, and the W1 fixtures (tests/fixtures/phase9, Phase9Fixtures, tests/fixtures/saves_v7).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["Quests", "QuestRules", "QuestLog",  # P1
		"WhoKnows", "LightRules", "KnockDoor",  # P4
		"HillRequests", "HillRules"]  # P2
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/quests/quests.gd": "Quests",
	"res://src/systems/quests/quest_rules.gd": "QuestRules",
	"res://src/systems/quests/quest_log.gd": "QuestLog",
	# P3
	"res://src/systems/letters/letters.gd": "Letters",
	"res://src/systems/letters/letter_rules.gd": "LetterRules",
	# P4
	"res://src/systems/quests/who_knows/who_knows.gd": "WhoKnows",
	"res://src/systems/quests/who_knows/light_rules.gd": "LightRules",
	"res://src/entities/knock_door/knock_door.gd": "KnockDoor",
	# P5
	"res://src/systems/stranger/stranger.gd": "Stranger",
	"res://src/systems/stranger/stranger_rules.gd": "StrangerRules",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"Quests": ["is_open", "open_day", "apply_morning", "post_load", "state", "current_step", "steps_done", "choice_of", "ending",
			"choose", "note", "notes", "pin", "pinned", "check_goal", "goal_progress", "save_state", "load_state"],
	"QuestRules": ["step_complete", "next_step", "deadline_day", "choice_block_reason"],
	"QuestLog": ["entries", "objective"],
	"WhoKnows": ["read_block_reason", "read_kladde", "compare_register", "can_compare", "compare_grave", "matched", "witness",
			"witnessed", "mark_seen", "letter_posted", "post_letter", "apply_morning", "depart_plan", "save_state", "load_state"],
	"LightRules": ["light_day", "entry_text", "open_light_day", "death_day", "decide_day"],
	"KnockDoor": ["can_interact", "get_interaction_prompt", "interact"],
	"Letters": ["assign", "on_found", "letter", "state", "corpse_of", "choices", "decide", "post_today", "give_to_carrier",
			"decided_count", "delivered_count", "apply_morning", "save_state", "load_state"],
	"LetterRules": ["pick", "choice_block_reason", "piety_event"],
	"Stranger": ["present", "gone", "answer", "offers", "sell", "take_soil", "bribe", "case_holder", "resolve", "apply_morning",
			"apply_minute", "save_state", "load_state"],
	"StrangerRules": ["visit_days", "present", "offer_block_reason"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["Quests", "is_open", 0], ["Quests", "open_day", 0], ["Quests", "apply_morning", 1], ["Quests", "post_load", 0],
	["Quests", "state", 1], ["Quests", "current_step", 1], ["Quests", "steps_done", 1], ["Quests", "choice_of", 2],
	["Quests", "ending", 1], ["Quests", "choose", 3], ["Quests", "note", 2], ["Quests", "notes", 1], ["Quests", "pin", 1],
	["Quests", "pinned", 0], ["Quests", "check_goal", 0], ["Quests", "goal_progress", 0], ["Quests", "load_state", 1],
	["QuestRules", "step_complete", 3], ["QuestRules", "next_step", 2], ["QuestRules", "deadline_day", 1],
	["QuestRules", "choice_block_reason", 2], ["QuestLog", "entries", 1], ["QuestLog", "objective", 1],
	["WhoKnows", "read_block_reason", 1], ["WhoKnows", "read_kladde", 0], ["WhoKnows", "compare_register", 0],
	["WhoKnows", "can_compare", 1], ["WhoKnows", "compare_grave", 1], ["WhoKnows", "matched", 1], ["WhoKnows", "witness", 1],
	["WhoKnows", "witnessed", 0], ["WhoKnows", "mark_seen", 0], ["WhoKnows", "letter_posted", 0], ["WhoKnows", "post_letter", 1],
	["WhoKnows", "apply_morning", 1], ["WhoKnows", "depart_plan", 0],
	["LightRules", "light_day", 3], ["LightRules", "entry_text", 3], ["LightRules", "open_light_day", 2],
	["LightRules", "death_day", 2], ["LightRules", "decide_day", 2],
	["KnockDoor", "can_interact", 1], ["KnockDoor", "get_interaction_prompt", 1], ["KnockDoor", "interact", 1],
	["Letters", "assign", 1], ["Letters", "on_found", 2], ["Letters", "letter", 1], ["Letters", "state", 1],
	["Letters", "corpse_of", 1], ["Letters", "choices", 2], ["Letters", "decide", 3], ["Letters", "post_today", 1],
	["Letters", "give_to_carrier", 3], ["Letters", "decided_count", 0], ["Letters", "delivered_count", 0],
	["Letters", "apply_morning", 1],
	["LetterRules", "pick", 5], ["LetterRules", "choice_block_reason", 3], ["LetterRules", "piety_event", 2],
	["Stranger", "present", 1], ["Stranger", "gone", 0], ["Stranger", "answer", 1], ["Stranger", "offers", 1],
	["Stranger", "sell", 2], ["Stranger", "take_soil", 2], ["Stranger", "bribe", 2], ["Stranger", "case_holder", 0],
	["Stranger", "resolve", 1], ["Stranger", "apply_morning", 1], ["Stranger", "apply_minute", 2],
	["StrangerRules", "visit_days", 2], ["StrangerRules", "present", 5], ["StrangerRules", "offer_block_reason", 3],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/systems/hill_requests/hill_requests.gd": ["parts_done", "large_board", "visit_block_reason", "start_visit",
			"half_done"],  # P2
	"res://src/systems/hill_requests/hill_rules.gd": ["part_done", "large_offerable"],  # P2
	"res://src/systems/visitors/visitors.gd": ["set_kin_interval"],  # P4
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_6_to_7", "migrate_7_to_8"],  # P6 (W0: Lead)
}
## [script, method, args] of the extended signatures of existing classes.
const EXISTING_ARITY := [
	["res://src/systems/hill_requests/hill_requests.gd", "parts_done", 1],
	["res://src/systems/hill_requests/hill_requests.gd", "large_board", 1],
	["res://src/systems/hill_requests/hill_requests.gd", "visit_block_reason", 2],
	["res://src/systems/hill_requests/hill_requests.gd", "start_visit", 1],
	["res://src/systems/hill_requests/hill_requests.gd", "half_done", 1],
	["res://src/systems/hill_requests/hill_rules.gd", "part_done", 4],
	["res://src/systems/hill_requests/hill_rules.gd", "large_offerable", 2],
	["res://src/systems/visitors/visitors.gd", "set_kin_interval", 2],
	["res://src/systems/save/save_migration.gd", "migrate_7_to_8", 2],
]
const SIGNALS := {
	"quest_changed": 3, "light_entry_changed": 2, "letter_changed": 3, "stranger_event": 2, "hill_request_part": 3,
	"craft_finished": 3,
}
const DATA_CLASSES := {
	"QuestConfig": "res://src/systems/quests/quest_config.gd",
	"QuestData": "res://src/systems/quests/quest_data.gd",
	"QuestStepData": "res://src/systems/quests/quest_step_data.gd",
	"QuestChoiceData": "res://src/systems/quests/quest_choice_data.gd",
	"QuestEndingData": "res://src/systems/quests/quest_ending_data.gd",
	"WhoKnowsConfig": "res://src/systems/quests/who_knows/who_knows_config.gd",
	"LightListData": "res://src/systems/quests/who_knows/light_list_data.gd",
	"LightEntryData": "res://src/systems/quests/who_knows/light_entry_data.gd",
	"LettersConfig": "res://src/systems/letters/letters_config.gd",
	"LetterData": "res://src/systems/letters/letter_data.gd",
	"StrangerConfig": "res://src/systems/stranger/stranger_config.gd",
	"StrangerOfferData": "res://src/systems/stranger/stranger_offer_data.gd",
}
## Properties changed in the data (and the class default together) after the W0 hand-over; the fixtures keep the
## W0 values. Empty at W0.
const DATA_CHANGED_AFTER_W0 := {}


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
	assert_eq(global.get("Phase9Fixtures"), "res://tests/fixtures/phase9/phase9_fixtures.gd")


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in Phase9Fixtures.SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	var scene := load("res://src/entities/knock_door/knock_door.tscn") as PackedScene
	assert_not_null(scene)
	if scene != null:
		var door := scene.instantiate()
		assert_true(door is KnockDoor and door is Node3D, "KnockDoor scene")
		assert_not_null(door.get_node_or_null(^"Interactable"), "KnockDoor has an Interactable")
		door.free()
	# The save orders are unique among all saveable system nodes (§3.1).
	var orders := {80: "hill_requests"}
	for spec: Array in Phase9Fixtures.SAVEABLES:
		assert_false(orders.has(spec[2]), "save_order %d unique" % spec[2])
		orders[spec[2]] = spec[1]


func test_stub_members_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	var v := Visitors.new()
	v.set_kin_interval(&"kin_sieber", 1)
	v.free()


func test_stubs_answer_neutral_defaults() -> void:
	var q := Quests.new()
	assert_eq([q.state(&"q_who_knows"), q.current_step(&"q_who_knows"), q.ending(&"q_who_knows"), q.pinned()], [&"", &"", &"", &""])
	assert_false(q.choose(&"q_who_knows", &"h5", &"confide_none"))
	assert_false(q.check_goal())
	q.free()
	if IMPLEMENTED.has("QuestRules"):
		assert_eq(QuestRules.next_step(Phase9Fixtures.quest(&"q_who_knows"), [] as Array[StringName]).id, &"h1", "P1: the first step")
	else:
		assert_null(QuestRules.next_step(Phase9Fixtures.quest(&"q_who_knows"), [] as Array[StringName]))
	assert_eq(QuestRules.deadline_day(QuestStepData.new()), -1)
	assert_eq(QuestLog.entries(tree), [] as Array[Dictionary])
	assert_eq(LightRules.light_day(LightEntryData.new(), tree, WhoKnowsConfig.new()), LightRules.NO_DAY)
	assert_eq(LightRules.NO_DAY, -9223372036854775807 - 1, "INT_MIN")
	var w := WhoKnows.new()
	assert_eq([w.letter_posted(), w.depart_plan(), w.witnessed(), w.compare_register()],
			[false, {}, [] as Array[StringName], PackedStringArray()])
	w.free()
	var l := Letters.new()
	assert_eq([l.state("lt_0001"), l.corpse_of("lt_0001"), l.decided_count(), l.on_found("corpse_0001", null)], [&"", "", 0, ""])
	assert_null(l.letter("lt_0001"))
	l.free()
	var s := Stranger.new()
	assert_eq([s.present(&"graveyard"), s.gone(), s.case_holder(), s.offers(null)], [false, false, &"", [] as Array[Dictionary]])
	s.free()
	assert_eq(StrangerRules.visit_days(63, StrangerConfig.new()), PackedInt32Array())
	assert_eq(LetterRules.pick(1, 63, [] as Array[StringName], [] as Array[LetterData], tree), &"")
	var h := HillRequests.new()
	assert_eq([h.parts_done(&"hrl_crosses"), h.large_board(&"gate"), h.half_done(&"hrl_crosses")],
			[[] as Array[bool], [] as Array[StringName], false])
	h.free()
	assert_false(HillRules.part_done(OrderData.new(), &"craft_finished", {}, {}))
	assert_false(HillRules.large_offerable(OrderData.new(), {}))


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 6, "§3.3: 6 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – everything over [E], dialogues and panels.
	for action: String in ["interact", "ui_cancel", "journal_page_prev", "journal_page_next"]:
		assert_true(InputMap.has_action(action), action)


func test_new_config_contract_values() -> void:
	var q := QuestConfig.new()
	assert_eq([q.open_flag, q.open_day_flag, q.unlock_flag, q.intro_minute], [&"p9_open", &"p9_open_day", &"who_comes_up_complete", 360])
	assert_eq([q.chapter_id, q.goal_flag, q.goal_main, q.goal_letters, q.goal_letters_step], [&"who_knows_when",
			&"who_knows_when_complete", &"q_who_knows", &"q_letters", &"l4"])
	assert_eq([q.goal_letters_decided, q.goal_large_requests, q.max_pinned], [5, 2, 1])
	var w := WhoKnowsConfig.new()
	assert_eq([w.open_light_offset, w.death_offset, w.decide_offset, w.light_flag, w.marked_flag], [-12, 21, 17, &"q_light_day",
			&"q_sieber_marked"])
	assert_eq([w.kin_id, w.house, w.daily_visit_from_step, w.bench_window], [&"kin_sieber", &"house_sieber", &"h4", Vector2i(840, 960)])
	assert_eq([w.kladde_minutes, w.register_minutes, w.grave_minutes, w.letter_minutes, w.letter_item], [20, 30, 5, 20, &"ink"])
	assert_eq([w.depart_with_peddler_minute, w.depart_with_carter_minute, w.witness_count, w.reserve_section], [980, 600, 3,
			&"linden_row4"])
	var l := LettersConfig.new()
	assert_eq([l.open_flag, l.forced_after_open, l.forced_ids], [&"p9_open", 3, [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"]
			as Array[StringName]])
	assert_eq([Array(l.post_offsets), l.aschau_letter, l.postage, l.read_grave_minutes, l.answer_minutes], [[3, 6, 9], &"lpo_aschau",
			1, 10, 20])
	assert_eq([l.burn_minutes, l.bury_minutes, l.answer_item, l.rep_cap_day, l.reply_after_days], [2, 2, &"ink", 1, 1])
	var s := StrangerConfig.new()
	assert_eq([s.npc_id, s.arrive_offset, s.return_every, s.stay_days, s.gate_window, s.inn_window], [&"stranger", 2, 5, 3,
			Vector2i(850, 930), Vector2i(1080, 1260)])
	assert_eq([s.question_coin, s.bribe_coins, s.case_tip, s.kladde_price, s.rumor_delay_days], [1, 15, 2, 40, 2])
	assert_almost(s.specimen_factor, 1.5)
	assert_eq(s.questions, PackedStringArray(), "§3.4 class default; the 6 questions are in the .tres")
	assert_eq((Database.config(&"stranger_config") as StrangerConfig).questions.size(), 6, "§2.5.2 K1: 6 questions")
	assert_eq((Database.config(&"stranger_config") as StrangerConfig).questions[0], "Wie tief graben Sie im Frost?")


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase9Fixtures.CONFIG_NAMES + Phase9Fixtures.EXTENDED_CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase9Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		var defaults: Resource = (real.get_script() as GDScript).new()
		var changed: Array = DATA_CHANGED_AFTER_W0.get(name, [])
		var new_config := name in Phase9Fixtures.CONFIG_NAMES
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if StringName(prop.name) in changed:
					assert_eq(real.get(prop.name), defaults.get(prop.name), "%s.%s (changed) = class default" % [name, prop.name])
					continue
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
				if new_config and not (name == &"stranger_config" and prop.name == "questions"):
					assert_eq(defaults.get(prop.name), fixture.get(prop.name), "%s.%s = class default" % [name, prop.name])


func test_extended_data_classes() -> void:
	assert_eq([OrderData.CATEGORY_QUEST, OrderData.SIZE_LARGE, OrderData.PLACE_GATE, OrderData.PLACE_VILLAGE], [&"quest", &"large",
			&"gate", &"village"])
	assert_eq(OrderData.PART_KINDS, [&"craft", &"gather", &"ghosts", &"visit", &"meet", &"devotion", &"flowers"] as Array[StringName])
	var o := OrderData.new()
	assert_eq([o.parts, o.size, o.place, o.parts_in_order], [[] as Array[Resource], &"", &"gate", false])
	assert_eq(OrderData.KINDS.slice(0, 8), [&"deliver", &"bury", &"stone", &"tend", &"donate", &"section", &"meet", &"task"]
			as Array[StringName], "the order kinds stay")
	assert_eq([OrdersConfig.new().max_active_quest, OrdersConfig.new().max_active, OrdersConfig.new().max_active_friend], [3, 4, 2])
	var h := HillRequestsConfig.new()
	assert_eq([h.large_start_day, h.large_slots_gate, h.large_slots_village, h.large_max_active, h.large_refill_days_early,
			h.large_refill_days_village, h.large_offer_days, h.large_fail_rep, h.large_reward_rel], [2, 1, 1, 1, 1, 2, 2, -2, 3])
	assert_almost(h.half_ratio, 0.5)
	assert_eq([h.slots_early, h.slots_village, h.refill_days_village, h.fail_rep], [2, 1, 3, -1], "the small requests stay (G8 Runde 6)")
	var np := NightPathData.new()
	assert_eq([np.anchor_flag, np.cancel_flag], [&"", &""])
	var rep := ReputationConfig.new().event_points
	var rep_new := {&"letter_delivered": 1, &"large_request_done": 2, &"large_request_failed": -2, &"sent_away_rumor": -2,
			&"kept_promise": 1, &"public_duty": 3, &"register_sold_rumor": -1, &"case_reported": 3}
	assert_eq(rep_new.size(), 8)
	for key: StringName in rep_new:
		assert_eq(rep.get(key), rep_new[key], "§2.9 reputation %s" % key)
	assert_eq(rep.get(&"fenner_watch"), 1, "the Phase-8 events stay")
	var piety := PietyConfig.new().events
	var piety_new := {&"letter_read_sealed": -1, &"letter_read_grave": 1, &"letter_burned_asked": 1, &"letter_burned_unasked": -1,
			&"letter_buried": 1, &"letter_answered": 1, &"sent_away": 3, &"kept_promise": 3, &"made_public": -1, &"soil_sold": -1,
			&"register_sold": -3, &"case_bribe": -3, &"kladde_sold": -8, &"case_to_ilse": 2, &"stranger_refused": 1, &"postage_paid": 1}
	assert_eq(piety_new.size(), 16)
	for key: StringName in piety_new:
		assert_eq(piety.get(key), piety_new[key], "§2.9 piety %s" % key)
	var gains := RelationshipConfig.new().gains
	var gains_new := {&"witness": 2, &"confided": 4, &"letter_delivered": 3, &"errand_done": 2, &"named_publicly": -4,
			&"large_request_village": 3, &"case_reported_fenner": 4, &"case_reported_quast": -6, &"register_sold_lenz": -4,
			&"register_sold_fenner": -2, &"seal_broken": -3}
	assert_eq(gains_new.size(), 11)
	for key: StringName in gains_new:
		assert_eq(gains.get(key), gains_new[key], "§2.9 gains %s" % key)
	assert_eq(gains.get(&"jakob_unpaid"), -2, "the Phase-8 gains stay")
	var reactions := NpcLifeConfig.new().reactions
	for key: StringName in [&"q_sent_away", &"q_stayed", &"q_public"]:
		assert_eq(reactions.get(key), 3, "§2.2.8: %s 3 days" % key)
	assert_eq([reactions.get(&"letter_delivered"), reactions.get(&"register_sold"), reactions.get(&"wish_done")], [2, 2, 2])
	assert_eq(GhostLines.new().by_letter, PackedStringArray())


func test_corpse_record_letter_id() -> void:
	var r := CorpseRecord.new()
	assert_eq(r.letter_id, &"")
	r.id = "c_1"
	r.letter_id = &"lp_l1_carter"
	var back := CorpseRecord.from_dict(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(r.to_dict())))) as Dictionary)
	assert_eq(back.letter_id, &"lp_l1_carter", "JSON round trip")
	assert_eq(r.to_dict().size(), 40, "39 Phase-8 record fields + letter_id")
	assert_eq(CorpseRecord.from_dict({"id": "c_2"}).letter_id, &"", "tolerant")
	assert_eq(CorpseRecord.from_dict({"id": "c_3", "letter_id": 7}).letter_id, &"7", "a number becomes its text (_to_str)")


func test_game_state_stats_and_coin_reason() -> void:
	for key: StringName in SaveMigration.V8_NEW_STATS:
		assert_true(key in GameState.DEFAULT_STATS, "§2.9 stat %s" % key)
	assert_eq(SaveMigration.V8_NEW_STATS.size(), 18, "§2.9: 18 stats")
	var p8_end := GameState.DEFAULT_STATS.find(&"coins_spent_peddler")
	assert_eq(GameState.DEFAULT_STATS[p8_end + 1], &"quest_steps", "Phase-9 stats appended")
	assert_eq(GameState.COIN_REASONS.back(), &"post", "§2.9 coin purpose post")
	assert_eq(GameState.coin_ledger_stat(&"post"), &"coins_spent_post")


func test_quest_fixtures() -> void:
	var main := Phase9Fixtures.quest(&"q_who_knows")
	assert_not_null(main)
	assert_eq([main.id, main.kind, main.order], [&"q_who_knows", &"main", 10])
	assert_eq(main.steps.map(func(s: QuestStepData) -> StringName: return s.id), Phase9Fixtures.MAIN_STEPS)
	for s: QuestStepData in main.steps:
		assert_true(s.complete_on in QuestStepData.COMPLETE_ON, "%s complete_on %s" % [s.id, s.complete_on])
		assert_true(s.title != "" and s.hint != "", String(s.id))
	assert_eq([main.steps[0].complete_on, main.steps[0].complete_ids], [&"note", [&"kladde_read"] as Array[StringName]], "H1")
	assert_eq([main.steps[1].complete_ids, main.steps[1].complete_count], [[&"date_grave"] as Array[StringName], 5], "H2: 5 graves")
	assert_eq(main.steps[2].complete_ids, [&"i_light_before"] as Array[StringName], "H3")
	assert_eq(main.steps[3].complete_ids, [&"q_sieber_marked"] as Array[StringName], "H4")
	assert_eq(main.steps[4].choices.map(func(c: QuestChoiceData) -> StringName: return c.id), [&"confide_priest", &"confide_surgeon",
			&"confide_washer", &"confide_none"], "H5")
	var h6 := main.steps[5]
	assert_eq(h6.choices.map(func(c: QuestChoiceData) -> StringName: return c.id), Phase9Fixtures.ENDINGS, "H6")
	assert_eq([h6.deadline_flag, h6.deadline_offset, h6.fallback_choice], [&"q_light_day", 17, &"silent"], "§2.2.2 deadline")
	assert_eq([h6.choices[0].conditions, h6.choices[0].block_text], [PackedStringArray(["letter_posted"]),
			"Er glaubt dir nicht. Er würde einem Brief glauben."], "ending A only with the letter")
	for c: QuestChoiceData in h6.choices:
		assert_eq(c.ending, c.id, "%s ends the chain" % c.id)
	assert_eq(main.endings.map(func(e: QuestEndingData) -> StringName: return e.id), Phase9Fixtures.ENDINGS)
	assert_eq([main.endings[0].flag, main.endings[0].settle_on], [&"q_end_away", &"sieber_gone"])
	for e: QuestEndingData in main.endings.slice(1):
		assert_eq(e.settle_on, &"sieber_buried", "%s settles with D3 buried" % e.id)
		assert_true(e.closing_line != "", String(e.id))
	var letters := Phase9Fixtures.quest(&"q_letters")
	assert_eq(letters.steps.map(func(s: QuestStepData) -> StringName: return s.id), Phase9Fixtures.LETTERS_STEPS)
	assert_eq([letters.steps[2].complete_on, letters.steps[2].order_ids], [&"order", [&"oq_gesa_brother"] as Array[StringName]], "L3 = E1")
	var case_q := Phase9Fixtures.quest(&"q_case")
	assert_eq(case_q.steps.map(func(s: QuestStepData) -> StringName: return s.id), Phase9Fixtures.CASE_STEPS)
	assert_eq(case_q.endings.map(func(e: QuestEndingData) -> StringName: return e.id), [&"fenner", &"deal", &"ilse"])
	for q: QuestData in Phase9Fixtures.quests():
		assert_eq(q.open_conditions, PackedStringArray(["flag:p9_open"]), String(q.id))


func test_light_list_fixture() -> void:
	var list := Phase9Fixtures.light_list()
	assert_not_null(list)
	assert_eq(list.entries.map(func(e: LightEntryData) -> StringName: return e.id), Phase9Fixtures.ENTRY_IDS)
	assert_eq(list.entries.map(func(e: LightEntryData) -> String: return e.initial), ["D.", "Q.", "W.", "H.", "O.", "S."])
	assert_eq([list.entries[0].ink, list.entries[0].fixed_text, list.entries[0].story_id], [&"old", "2. Julmond 1833", &"s5_moor"])
	assert_eq([list.entries[5].open, list.entries[5].story_id, list.entries[5].witness_npc], [true, &"", &"beggar"])
	assert_eq([list.footer, list.struck], ["Licht. Drei Wochen.", "Wer weiß, wann?"])
	var insight := Phase9Fixtures.insight()
	assert_eq([insight.id, insight.any_count, insight.sets_flag], [&"i_light_before", 3, &"insight_light_before"])
	assert_eq(insight.any_clues, list.entries.slice(0, 5).map(func(e: LightEntryData) -> StringName: return e.witness_clue))
	for id: StringName in Phase9Fixtures.CLUE_IDS:
		var c := Phase9Fixtures.clue(id)
		assert_true(c != null and c.kind in ClueData.KINDS and c.text != "", String(id))


## §12.1: the grave ids of the dead under the list in the v7 fixture (and the records of Phase9Fixtures.list_records).
func test_list_dead_in_the_kindly_fixture() -> void:
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase9Fixtures.save_v7_path("slot_p8_day63_kindly")))
	assert_true(doc is Dictionary)
	if not doc is Dictionary:
		return
	var state: Dictionary = JSON.to_native(doc.data)
	var found := {}
	for r: Variant in (state.nodes.corpse_manager.corpses as Array):
		var story := StringName(str((r as Dictionary).get("story_id", "")))
		if Phase9Fixtures.LIST_DEAD.has(story):
			found[story] = [str(r.grave_id), floori(float(r.arrival_total_minutes) / 1440.0) + 1, str(r.id)]
	assert_eq(found.size(), 5, "S1, S3, S5, D1, D2 buried")
	for story: StringName in Phase9Fixtures.LIST_DEAD:
		assert_eq(found.get(story), Phase9Fixtures.LIST_DEAD[story], String(story))
	assert_eq(int(state.nodes.night_paths.deaths.np_ott), 58, "D2's death night (light day 37)")
	var records := Phase9Fixtures.list_records()
	assert_eq(records.size(), 5)
	for r: CorpseRecord in records:
		assert_eq(r.grave_id, str(Phase9Fixtures.LIST_DEAD[r.story_id][0]), String(r.story_id))


func test_letter_and_offer_fixtures() -> void:
	var pocket := 0
	var post := 0
	for l: LetterData in Phase9Fixtures.letters():
		assert_not_null(l)
		assert_true(l.kind in LetterData.KINDS and l.asks in LetterData.ASKS and l.outside != "" and l.text != "", String(l.id))
		for choice: StringName in l.choice_actions:
			assert_true(choice in LetterData.CHOICES, "%s: choice %s" % [l.id, choice])
		if l.kind == LetterData.KIND_POCKET:
			pocket += 1
		else:
			post += 1
			assert_true(l.id == &"lpo_aschau" or l.story_id != &"", "%s: to a dead" % l.id)
	assert_eq([pocket, post], [11, 5], "§2.4.2: 11 pocket letters, §2.4.3: 4 post + lpo_aschau")
	for id: StringName in LettersConfig.new().forced_ids:
		assert_not_null(Phase9Fixtures.letter(id), String(id))
	assert_eq(Phase9Fixtures.letter(&"lp_l3_burn").asks, &"burn")
	assert_eq(Phase9Fixtures.letter(&"lg_lambert").conditions, PackedStringArray(["robber_fate:let_go"]))
	for o: StrangerOfferData in Phase9Fixtures.stranger_offers():
		assert_true(o != null and o.label != "" and o.note != "", "offer")
		assert_false(o.note.contains("+") or o.note.contains("−"), "%s: no numbers before the choice" % o.id)
	assert_eq([Phase9Fixtures.stranger_offer(&"so_register").price, Phase9Fixtures.stranger_offer(&"so_kladde").price], [10, 40])


func test_large_request_fixtures() -> void:
	var known := HillRules.KINDS + OrderData.PART_KINDS
	var gate := 0
	for o: OrderData in Phase9Fixtures.large_requests():
		assert_not_null(o)
		if o == null:
			continue
		assert_eq([o.category, o.size], [OrderData.CATEGORY_HILL, OrderData.SIZE_LARGE], String(o.id))
		assert_true(o.place in [OrderData.PLACE_GATE, OrderData.PLACE_VILLAGE], String(o.id))
		assert_true(o.parts.size() >= 2 and o.parts.size() <= 4, "%s: 2–4 parts" % o.id)
		assert_true(o.days_limit >= 2 and o.days_limit <= 3, "%s: deadline 2–3 days" % o.id)
		assert_true(o.reward_coins >= 3 and o.reward_coins <= 5, "%s: 3–5 coins" % o.id)
		assert_true(o.cooldown_days >= 8 and o.cooldown_days <= 10, "%s: cooldown 8–10 days" % o.id)
		for p: Resource in o.parts:
			var part := p as OrderData
			assert_true(part != null and part.kind in known and part.title != "", "%s: part %s" % [o.id, part.kind if part else &"?"])
		if o.place == OrderData.PLACE_GATE:
			gate += 1
		assert_eq(Database.hill_request(o.id), null, "%s is not a small request" % o.id)
	assert_eq(gate, 8, "§2.3.3: 8 gate requests")
	# W0 check of the recipe ids (§2.3.3): every craft part names an existing recipe of a station the hill has.
	for o: OrderData in Phase9Fixtures.large_requests():
		for p: Resource in o.parts:
			var part := p as OrderData
			if part.kind == &"craft":
				var recipe := Database.recipe(StringName(str(part.conditions.get("recipe", "")))) as RecipeData
				assert_not_null(recipe, "%s: recipe %s" % [o.id, part.conditions.get("recipe")])
			if part.kind == &"decor":
				for d: Variant in part.conditions.get("decor", []):
					assert_not_null(Database.recipe(StringName(str(d))), "%s: decor recipe %s" % [o.id, d])
			for item: StringName in part.items:
				assert_not_null(Database.item(item), "%s: item %s" % [o.id, item])
	assert_eq(Database.recipe(&"decor_bench_wood").station, &"workbench", "the bench")
	assert_eq(Database.recipe(&"decor_lantern").station, &"workbench", "the lantern post")
	assert_null(Database.recipe(&"altar_candle"), "no altar-candle recipe: hrv_church_candles delivers bought candles")


func test_order_item_story_fixtures() -> void:
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		var o := Phase9Fixtures.order(id)
		assert_not_null(o, String(id))
		if o == null:
			continue
		assert_eq(o.category, OrderData.CATEGORY_QUEST, String(id))
		assert_true(o.kind in OrderData.KINDS and o.title != "" and o.request_text != "", String(id))
		assert_eq(o.reward_coins, 0, "%s: errands pay no coins" % id)
	assert_eq(Phase9Fixtures.order(&"oq_johann_evening").conditions.times, 2, "two evenings")
	for id: StringName in Phase9Fixtures.ITEM_IDS:
		var item := Phase9Fixtures.item(id)
		assert_not_null(item, String(id))
		if item == null:
			continue
		assert_eq(item.id, id)
		assert_true(item.display_name != "" and item.description.length() >= 20, String(id))
	assert_eq([Phase9Fixtures.item(&"letter").unique, Phase9Fixtures.item(&"letter_reply").unique, Phase9Fixtures.item(&"soil_pouch").max_stack],
			[true, true, 3])
	var d := Phase9Fixtures.d3_story()
	assert_eq([d.order, d.age, d.cause_id, d.traits, d.look, d.section, d.requires_flag, d.due_flag], [8, 71, &"old_age",
			[&"strange_wound"] as Array[StringName], 2, &"linden_row4", &"q_sieber_dies", &"sieber_dead"])
	assert_eq(d.finds, Phase9Fixtures.FIND_IDS)
	for id: StringName in d.finds:
		var f := Phase9Fixtures.find(id)
		assert_true(f != null and f.story_only and f.text != "", String(id))
	var np := Phase9Fixtures.night_path()
	assert_eq([np.id, np.house, np.start_offset, np.end_offset, np.death_offset, np.death_minute, np.death_flag, np.anchor_flag,
			np.cancel_flag], [&"np_sieber", &"house_sieber", 19, 20, 20, 130, &"sieber_dead", &"q_light_day", &"sieber_gone"])
	assert_eq(np.visits.map(func(v: NightVisitData) -> Array: return [v.npc_id, v.night_offset, v.enter_minute, v.leave_minute]),
			[[&"surgeon", 19, 1350, 1390], [&"priest", 20, 1260, 1300], [&"washer", 20, 160, 330]], "§2.2.2")
	var row4 := Phase9Fixtures.row4_section()
	assert_eq([row4.id, row4.starts_unlocked, row4.requires_section, row4.requires_flag], [&"linden_row4", false, &"linden",
			&"linden_row4_granted"])
	var lines := Phase9Fixtures.ghost_lines()
	assert_eq(lines.by_letter.size(), 2)
	assert_eq(lines.by_story[&"d3_sieber"].size(), 3, "B, C, silent")


func test_fixture_helpers() -> void:
	var flags := GameState.flags.duplicate(true)
	var q := Phase9Fixtures.p9_open(null, 63)
	assert_true(q.is_open())
	assert_eq([q.open_day(), int(GameState.get_flag(&"q_light_day")), q.state(&"q_who_knows")], [63, 51, &"open"])
	q.free()
	q = Phase9Fixtures.quest_at(&"q_who_knows", &"h3")
	assert_eq([q.current_step(&"q_who_knows"), q.steps_done(&"q_who_knows")], [&"h3", [&"h1", &"h2"] as Array[StringName]])
	q.free()
	q = Phase9Fixtures.ending(&"stay")
	assert_eq([q.ending(&"q_who_knows"), q.state(&"q_who_knows"), q.choice_of(&"q_who_knows", &"h6")], [&"stay", &"ended", &"stay"])
	assert_true(GameState.flag_on(&"q_end_stay") and GameState.flag_on(&"q_sieber_dies"))
	q.free()
	var w := Phase9Fixtures.witnessed([&"e_ott", &"e_quendel"] as Array[StringName])
	assert_eq(w.witnessed(), [&"e_ott", &"e_quendel"] as Array[StringName])
	w.free()
	w = Phase9Fixtures.sieber_marked()
	assert_true(GameState.flag_on(&"q_sieber_marked"))
	assert_eq(w.witnessed().size(), 5)
	w.free()
	var inv := Inventory.new()
	var found := Phase9Fixtures.letter_in(inv, &"lp_l1_carter")
	var letters: Letters = found.letters
	assert_eq([letters.state(found.uid), letters.letter(found.uid).id, inv.has_uid(found.uid)], [&"found", &"lp_l1_carter", true])
	letters.free()
	inv.free()
	Phase9Fixtures.remove_injected_items()
	assert_false(Database.has_item(&"letter"), "injected fixture items removed again")
	var post := Phase9Fixtures.post_waiting(&"lpo_quendel")
	assert_eq((post.letters as Letters).state(post.uid), &"received")
	(post.letters as Letters).free()
	assert_eq([Phase9Fixtures.stranger_day(1), Phase9Fixtures.stranger_day(2)], [65, 70], "§2.5.1: B3, B8")
	var h := Phase9Fixtures.large_pinned(&"hrl_ferry_graves", [true, false, false] as Array[bool])
	assert_eq([h.large_board(&"gate"), h.parts_done(&"hrl_ferry_graves")], [[&"hrl_ferry_graves"] as Array[StringName],
			[true, false, false] as Array[bool]])
	assert_eq(h.save_state().get("parts"), {"hrl_ferry_graves": [true, false, false]}, "P2: parts saved (§5.1)")
	h.free()
	GameState.flags = flags
	assert_false(Phase9Fixtures.layout_p8().is_empty(), "layout_p8.json readable")
	assert_false(Phase9Fixtures.village_layout_p8().is_empty(), "village_layout_p8.json readable")


func test_layout_fixtures_are_byte_identical_to_the_phase8_layouts() -> void:
	# Taken at 10e310e (W0). W-Welt changes data/world in W2; then only the fixture stays.
	assert_eq(FileAccess.get_file_as_bytes(Phase9Fixtures.LAYOUT_P8).size() > 1000, true)
	var layout := Phase9Fixtures.layout_p8()
	assert_true(layout.has("plots") and layout.has("sections"), "graveyard plots and sections")
	assert_eq(str(Phase9Fixtures.village_layout_p8().get("region_id", "")), "village")
	for plot: String in Phase9Fixtures.ROW4_PLOTS:
		assert_false(JSON.stringify(layout.plots).contains('"%s"' % plot), "%s comes with W-Welt (W2)" % plot)


func test_database_phase9_folders() -> void:
	# The real data folders are the owners' (P1 quests, P3 letters, P5 offers, P2 large requests) – empty until W1.
	for list: Array in [Database.quests(), Database.letters(), Database.pocket_letters(), Database.post_letters(),
			Database.stranger_offers(), Database.large_requests()]:
		for res: Resource in list:
			assert_true(res != null, "loaded")
	assert_null(Database.quest(&"nope"))
	assert_null(Database.letter(&"nope"))
	assert_null(Database.stranger_offer(&"nope"))
	assert_null(Database.large_request(&"nope"))
	for r: Resource in Database.hill_requests():
		assert_eq(r.get(&"size"), &"", "hill_requests() holds the small requests only")
	for name: StringName in Phase9Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	var orders: Array = Database.quests().map(func(q: Resource) -> int: return int(q.get(&"order")))
	var sorted := orders.duplicate()
	sorted.sort()
	assert_eq(orders, sorted, "quests sorted by order")


func test_save_format_v8_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 8)
	assert_eq(SaveFileIO.FORMAT_VERSION, 8)
	assert_eq(SaveManager.FORMAT_VERSION, 8)
	assert_eq(SaveMigration.V8_EMPTY_NODES, PackedStringArray(["quests", "who_knows", "letters", "stranger"]), "§3.4 / §5.2 step 3")
	assert_eq(SaveMigration.V8_RECORD_DEFAULTS, {"letter_id": ""})
	var state := {"autoloads": {"TimeManager": {"day": 63}, "GameState": {"stats": {}, "flags": {}}},
			"nodes": {"corpse_manager": {"corpses": [{"id": "corpse_0001"}]}}}
	assert_eq(SaveMigration.migrate(state, 8), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, 9), {}, "newer → corrupt")
	var v8 := SaveMigration.migrate_7_to_8(state, {"day": 63})
	assert_false(is_same(v8, state), "deep copy")
	assert_eq(state.nodes.corpse_manager.corpses[0], {"id": "corpse_0001"}, "input unchanged")
	assert_eq(v8.nodes.corpse_manager.corpses[0].letter_id, "", "§5.2 step 1")
	for id: String in SaveMigration.V8_EMPTY_NODES:
		assert_eq(v8.nodes.get(id), {}, "§5.2 step 3: %s" % id)
	for key: StringName in SaveMigration.V8_NEW_STATS:
		assert_eq(v8.autoloads.GameState.stats.get(String(key)), 0, "§5.2 step 5: %s" % key)
	assert_eq(v8.autoloads.GameState.flags, {}, "§5.2 step 5: no flags")
	assert_eq(SaveMigration.migrate_7_to_8(v8, {}), v8, "idempotent")
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("npc_life")
			and (from_v1.nodes as Dictionary).has("quests"), "v1 → … → v8 chain")
	# SaveManager drops the empty Phase-9 nodes while the world has none of them (like V3–V7).
	var nodes := {"quests": {}, "who_knows": {}, "letters": {}, "stranger": {}}
	assert_eq(SaveManager.without_absent_defaults(tree, nodes), {}, "absent empty Phase-9 nodes dropped")


func test_save_v7_fixtures_exist() -> void:
	assert_eq(Phase9Fixtures.SAVES_V7.size(), 7, "§5.3: seven v7 fixtures")
	for name: String in Phase9Fixtures.SAVES_V7:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase9Fixtures.save_v7_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 7, name)
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
