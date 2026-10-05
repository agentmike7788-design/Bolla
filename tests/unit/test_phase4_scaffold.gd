extends TestCase
## Lead / W0 (docs/PHASE4_DESIGN.md §12): the Phase-4 scaffold – every stub class loads with its
## contract signature, every new data class / config .tres holds valid contract values, EventBus
## signals, input actions, appended enum values, Database folders, save format v3 + migration
## chain 1 → 2 → 3, and the W1 fixtures (tests/fixtures/phase4, Phase4Fixtures).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["PietyRules", "Piety", "UtilizationRules", "NightTrade",  # P3
		"CorpseExam", "CorpsePrep", "CorpseCare",  # P2
		"StoryDirector",  # P1
		"JournalRules", "JournalManager",  # P6
		"CorpseDecayVisual"]  # P4
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/story/story_director.gd": "StoryDirector",
	# P2
	"res://src/systems/corpse/corpse_exam.gd": "CorpseExam",
	"res://src/systems/corpse/corpse_prep.gd": "CorpsePrep",
	"res://src/systems/corpse/corpse_care.gd": "CorpseCare",
	# P3
	"res://src/systems/piety/piety_rules.gd": "PietyRules",
	"res://src/systems/piety/piety.gd": "Piety",
	"res://src/systems/utilization/utilization_rules.gd": "UtilizationRules",
	"res://src/systems/utilization/night_trade.gd": "NightTrade",
	# P4
	"res://src/entities/corpse/corpse_decay_visual.gd": "CorpseDecayVisual",
	# P6
	"res://src/systems/journal/journal_rules.gd": "JournalRules",
	"res://src/systems/journal/journal_manager.gd": "JournalManager",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"StoryDirector": ["due_story", "pending_count", "make_record", "daily_checks"],
	"CorpseExam": ["candidates", "resolve", "block_reason", "open_steps", "minutes_for", "next_loss"],
	"CorpsePrep": ["block_reason", "minutes", "is_balm_active"],
	"CorpseCare": ["step_block_reason", "exam_step", "exam_all", "exam_all_instant", "prep_block_reason", "wash", "dress",
			"lay_out", "apply_balm", "harvest_block_reason", "harvest", "next_loss"],
	"PietyRules": ["tier", "tier_index", "label", "self_image", "recovery", "affinity"],
	"Piety": ["value", "tier", "change", "event", "apply_daily", "gift_coins", "buyer_bonus"],
	"UtilizationRules": ["block_reason", "sale_value"],
	"NightTrade": ["is_known", "is_present", "night_id", "sell", "quote", "buy", "stock_left", "give_tools", "note_talk",
			"apply_morning", "save_state", "load_state"],
	"CorpseDecayVisual": ["apply", "overlay_amount", "flies", "wisps", "smoke_on"],
	"JournalRules": ["match_insight", "open_questions", "ready_insights"],
	"JournalManager": ["has_clue", "add_clue", "clue_count", "clues", "try_link", "insights", "has_insight", "people",
			"unread", "mark_read", "sync_from_records", "save_state", "load_state", "post_load"],
}
## Argument counts of selected contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["StoryDirector", "due_story", 5], ["StoryDirector", "make_record", 2], ["StoryDirector", "daily_checks", 3],
	["CorpseExam", "candidates", 5], ["CorpseExam", "next_loss", 5], ["CorpsePrep", "block_reason", 5],
	["CorpseCare", "dress", 3], ["CorpseCare", "harvest", 3], ["CorpseCare", "prep_block_reason", 4],
	["UtilizationRules", "block_reason", 5], ["UtilizationRules", "sale_value", 3],
	["NightTrade", "sell", 3], ["NightTrade", "buy", 3], ["CorpseDecayVisual", "apply", 4],
	["JournalRules", "match_insight", 3], ["JournalManager", "add_clue", 3],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/systems/corpse/corpse_record.gd": ["is_step_done", "is_fully_examined", "is_dressed", "is_fully_prepared", "is_harvested"],  # P1
	"res://src/systems/corpse/corpse_decay.gd": ["effective_minutes", "freshness_at", "minutes_until"],  # P1
	"res://src/systems/corpse/corpse_manager.gd": ["notify_changed", "story_delivered", "story_last_day", "deliver_story_now"],  # P1
	"res://src/systems/corpse/corpse_delivery_rules.gd": ["is_cemetery_full"],  # P1
	"res://src/systems/graveyard/graveyard.gd": ["plots_counting_for_cemetery"],  # P1
	"res://src/entities/morgue_table/morgue_table.gd": ["request_exam_step", "request_exam_all", "request_wash", "request_dress",
			"request_lay_out", "request_balm", "request_harvest"],  # P2
	"res://src/systems/graveyard/cemetery_rating.gd": ["rating_gated", "venerable_missing"],  # P3
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_1_to_2", "migrate_2_to_3"],  # P6
}
## Saveable stubs: [class, save_id, save_order, identity group] (§3.1).
const SAVEABLES := [
	["JournalManager", "journal", 40, &"journal"],
	["NightTrade", "night_trade", 45, &"night_trade"],
]
const SIGNALS := {
	"exam_step_done": 4, "corpse_prepared": 2, "corpse_harvested": 3, "story_corpse_arrived": 2, "chapter_completed": 1,
	"piety_changed": 4, "clue_found": 2, "insight_unlocked": 1, "trader_trade": 3,
}
const DATA_CLASSES := {
	"ExamConfig": "res://src/systems/corpse/exam_config.gd", "FindData": "res://src/systems/corpse/find_data.gd",
	"PrepConfig": "res://src/systems/corpse/prep_config.gd", "StoryCorpseData": "res://src/systems/story/story_corpse_data.gd",
	"StoryConfig": "res://src/systems/story/story_config.gd", "PietyConfig": "res://src/systems/piety/piety_config.gd",
	"UtilizationConfig": "res://src/systems/utilization/utilization_config.gd",
	"TraderConfig": "res://src/systems/utilization/trader_config.gd", "ClueData": "res://src/systems/journal/clue_data.gd",
	"InsightData": "res://src/systems/journal/insight_data.gd", "DecayVisualConfig": "res://src/entities/corpse/decay_visual_config.gd",
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
		var script := load(_path_of(spec[0])) as GDScript
		var found := false
		for m: Dictionary in script.get_script_method_list():
			if String(m.name) == spec[1]:
				found = true
				assert_eq((m.args as Array).size(), spec[2], "%s.%s arguments" % [spec[0], spec[1]])
		assert_true(found, "%s.%s" % [spec[0], spec[1]])


func test_data_classes_are_registered() -> void:
	var global := _global_classes()
	for cls: String in DATA_CLASSES:
		assert_eq(global.get(cls), DATA_CLASSES[cls], cls)
		var res: Resource = (load(DATA_CLASSES[cls]) as GDScript).new()
		assert_true(res is Resource, cls)


func test_node_stubs_instantiate_with_groups() -> void:
	for spec: Array in SAVEABLES:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_eq(node.get(&"save_id"), spec[1], spec[0])
		assert_eq(node.get(&"save_order"), spec[2], spec[0])
		assert_true(node.is_in_group(&"saveable"), spec[0] + " saveable")
		assert_true(node.is_in_group(spec[3]), "%s in group %s" % [spec[0], spec[3]])
		if not IMPLEMENTED.has(spec[0]):
			assert_eq(node.call("save_state"), {}, spec[0] + " stub state")
		node.free()
	for spec: Array in [["CorpseCare", &"corpse_care"], ["Piety", &"piety"]]:
		var node: Node = (load(_path_of(spec[0])) as GDScript).new()
		assert_true(node.is_in_group(spec[1]), spec[0])
		assert_false(node.is_in_group(&"saveable"), spec[0] + " is not saved")
		node.free()
	var visual := CorpseDecayVisual.new()
	assert_true(visual is Node3D)
	visual.free()


func test_stub_methods_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	var npc: Node = (load("res://src/entities/npc/npc.gd") as GDScript).new()
	assert_eq([npc.get(&"requires_flag"), npc.get(&"lantern_marker")], [&"", &""], "Npc exports (P3)")
	npc.free()


func test_corpse_record_phase4_fields_and_helpers() -> void:
	assert_eq(CorpseRecord.STEPS, [&"clothing", &"hands", &"wounds", &"pockets"] as Array[StringName])
	assert_eq([CorpseRecord.STAGE_ROTTEN, CorpseRecord.DRESS_NONE, CorpseRecord.DRESS_SHROUD, CorpseRecord.DRESS_GOWN],
			[&"rotten", &"", &"shroud", &"gown"])
	assert_eq([CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH], [&"hair", &"teeth"])
	var r := CorpseRecord.new()
	assert_eq([r.story_id, r.dress, r.washed, r.laid_out, r.stench_noted], [&"", &"", false, false, false])
	assert_eq([r.exam_done.size(), r.finds_revealed.size(), r.finds_lost.size(), r.traits_revealed.size(),
			r.harvested.size(), r.balm_windows.size()], [0, 0, 0, 0, 0, 0])
	assert_false(r.is_fully_examined() or r.is_dressed() or r.is_fully_prepared() or r.is_harvested(&"hair"))
	r.exam_done.assign(CorpseRecord.STEPS)
	r.washed = true
	r.dress = CorpseRecord.DRESS_GOWN
	assert_true(r.is_step_done(&"hands") and r.is_fully_examined() and r.is_dressed())
	assert_false(r.is_fully_prepared(), "not laid out")
	r.laid_out = true
	r.harvested.append(CorpseRecord.HARVEST_TEETH)
	assert_true(r.is_fully_prepared() and r.is_harvested(&"teeth"))


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_true(EventBus.has_signal("corpse_updated"), "the collective signal stays")


func test_input_actions() -> void:
	var keys := {"journal": KEY_J, "journal_page_prev": KEY_BRACKETLEFT, "journal_page_next": KEY_BRACKETRIGHT}
	for action: String in keys:
		assert_true(InputMap.has_action(action), action)
		assert_eq(_keys_of(action), [keys[action]], action + " key")
	# J is free: no other action uses it.
	for action: StringName in InputMap.get_actions():
		if String(action) != "journal" and not String(action).begins_with("ui_"):
			assert_false(_keys_of(action).has(KEY_J), "%s does not use J" % action)


func test_appended_enum_values() -> void:
	assert_eq([ItemData.Category.RESOURCE, ItemData.Category.CRAFTED, ItemData.Category.CURRENCY,
			ItemData.Category.DECOR, ItemData.Category.TOOL, ItemData.Category.GOODS], [0, 1, 2, 3, 4, 5])
	# Phase 5 W0 appends MATERIAL (6) – see test_phase5_scaffold.gd.
	assert_eq(ItemData.Category.size(), 7)


func test_extended_data_classes() -> void:
	var s := SectionData.new()
	assert_eq([s.requires_flag, s.requires_flag_text, s.counts_for_cemetery, s.chapter], [&"", "", true, &""])
	for real: SectionData in Database.sections():
		# P1 (W1): the Holunderwinkel is the one section outside the Phase-3 goal (§2.10).
		# Phase 5 (P2, W0 note 6): the work areas bruch / quarry do not count either.
		# Phase 6 (W-Welt, §4.2): the churchyard has no graves and does not count either.
		# Phase 7 (P3, §2.9): the Lindenacker does not count either.
		assert_eq(real.counts_for_cemetery, not real.id in [&"elder", &"bruch", &"quarry", &"churchyard", &"linden"], "%s counts for the cemetery" % real.id)
	var e := EconomyConfig.new()
	assert_eq([e.quality_washed, e.quality_laid_out, e.rot_malus, e.venerable_min_decor, e.venerable_max_dirt], [1, 1, -2, 12, 6])
	assert_almost(e.rot_threshold, 0.1)
	assert_eq(e.dress_quality, {&"shroud": 2, &"gown": 3})
	# Phase 7 (P4, §2.11): the seven organs appended; hair / teeth unchanged.
	assert_eq([e.harvest_malus[&"hair"], e.harvest_malus[&"teeth"]], [-1, -2])
	assert_eq(e.dress_quality[&"shroud"], e.quality_shroud, "shroud keeps its points")
	assert_eq(GhostConfig.new().robbed_mood, -5)
	var lines := GhostLines.new()
	assert_eq([lines.by_story.size(), lines.by_piety.size()], [0, 0])
	var rep := ReputationConfig.new()
	assert_eq([rep.event_points[&"hair_taken"], rep.event_points[&"teeth_taken"], rep.event_points[&"stench"]], [-3, -5, -2])
	assert_eq(CleanlinessConfig.new().penalty_by_level, PackedInt32Array([0, 0, 1, 3]), "§2.14 (a)")


## Data that deviates from the W0 fixture after the G4 QA round (docs/reviews/phase4_wip/
## qa_playthrough.md, QA4-02: the decay effects did not show at the default camera distance;
## QA4-05: German closing quotes (‚…‘) in the key fallback note.
const QA_DATA_DEVIATIONS := {&"decay_visual_config": ["wisp_color", "smoke_color", "visibility_range"],
		&"story_config": ["key_fallback_text"],
		# Phase 5 (P6, docs/PHASE5_DESIGN.md §2.6): gold leaf in Ilse's shop – checked against
		# tests/fixtures/phase5/trader_config_fixture.tres in test_utilization / test_night_trade.
		&"trader_config": ["shop"],
		# Phase 6 (P4, docs/PHASE6_DESIGN.md §2.7): + service, devotion, reinterred – checked against
		# tests/fixtures/phase6/piety_config_fixture.tres in test_piety.
		&"piety_config": ["events"]}


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase4Fixtures.CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase4Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if QA_DATA_DEVIATIONS.get(name, []).has(String(prop.name)):
					continue
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])


func test_exam_config_values() -> void:
	for cfg: ExamConfig in [Phase4Fixtures.exam_config(), Database.config(&"exam_config")]:
		assert_eq(cfg.step_ids(), CorpseRecord.STEPS, "steps in contract order")
		var minutes: Array = []
		for id: StringName in cfg.step_ids():
			minutes.append(cfg.step_minutes(id))
			for key: String in ExamConfig.STEP_KEYS:
				assert_true(cfg.step(id).has(key), "%s.%s" % [id, key])
		assert_eq(minutes, [10, 10, 15, 10], "§2.1 (gründlich max 45)")
		assert_eq(cfg.locked_by_dress, [&"clothing", &"pockets"] as Array[StringName])
		assert_eq(cfg.nothing_text, "Nichts Auffälliges.")
		assert_eq(cfg.trait_steps, {&"valuables": &"pockets", &"letter": &"pockets", &"tattoo": &"hands", &"strange_wound": &"wounds"})
		assert_eq(cfg.step(&"nope"), {})
	assert_eq(ExamConfig.new().trait_steps.size(), 4)


func test_prep_config_values() -> void:
	for cfg: PrepConfig in [Phase4Fixtures.prep_config(), PrepConfig.new()]:
		assert_eq([cfg.wash_minutes, cfg.wash_tool, cfg.lay_out_minutes, cfg.lay_out_tool], [15, &"scrub_brush", 10, &"comb"])
		assert_eq([cfg.dress_item(&"shroud"), cfg.dress_minutes(&"shroud"), cfg.dress_item(&"gown"), cfg.dress_minutes(&"gown")],
				[&"shroud", 10, &"burial_gown", 15])
		assert_eq([cfg.dress_item(&"nope"), cfg.dress_minutes(&"nope")], [&"", 0])
		assert_eq([cfg.balm_item, cfg.balm_minutes, cfg.balm_window_minutes, cfg.balm_max_windows], [&"juniper", 10, 1080, 4])
		assert_almost(cfg.balm_factor, 0.25)
		# §1.2: full preparation 40 min (wash 15 + shroud 10 + lay out 10 … gown 15).
		assert_eq(cfg.wash_minutes + cfg.dress_minutes(&"gown") + cfg.lay_out_minutes, 40)


func test_piety_config_values() -> void:
	for cfg: PietyConfig in [Phase4Fixtures.piety_config(), PietyConfig.new()]:
		assert_eq([cfg.min_value, cfg.max_value, cfg.start_value], [-100, 100, 0])
		assert_eq(cfg.tier_thresholds, PackedInt32Array([-59, -19, 20, 60]))
		assert_eq(cfg.tier_thresholds.size(), PietyRules.TIERS.size() - 1)
		for arr: PackedInt32Array in [cfg.gift_by_tier, cfg.buyer_bonus_by_tier]:
			assert_eq(arr.size(), PietyRules.TIERS.size(), "one value per tier")
		assert_eq(cfg.gift_by_tier, PackedInt32Array([0, 2, 2, 2, 3]))
		assert_eq(cfg.buyer_bonus_by_tier, PackedInt32Array([1, 1, 0, 0, 0]))
		# Phase 6 (§2.7) appends service / devotion / reinterred to the class default.
		var phase4_events := {&"valuables_left": 3, &"valuables_taken": -6, &"hair_taken": -4, &"teeth_taken": -6,
				&"full_prep": 3, &"bare_burial": -2, &"rotten_burial": -2}
		for key: StringName in phase4_events:
			assert_eq(cfg.events.get(key), phase4_events[key], String(key))
		assert_eq([cfg.daily_recovery, cfg.affinity_threshold], [1, 20])
	var labels: Array = []
	for t: StringName in PietyRules.TIERS:
		labels.append(PietyRules.LABELS[String(t)])
	assert_eq(labels, ["Hartherzig", "Abgebrüht", "Sachlich", "Rücksichtsvoll", "Andächtig"], "§14.1 names")


func test_utilization_and_trader_config_values() -> void:
	var util := Phase4Fixtures.utilization_config()
	assert_eq(util.kinds.keys(), [&"hair", &"teeth"])
	for kind: StringName in util.kinds:
		for key: String in UtilizationConfig.KIND_KEYS:
			assert_true(util.kind(kind).has(key), "%s.%s" % [kind, key])
	var hair := util.kind(&"hair")
	var teeth := util.kind(&"teeth")
	assert_eq([hair.minutes, hair.tool, hair.item, hair.reputation_event, hair.piety_event], [10, &"shears", &"hair_braid", &"hair_taken", &"hair_taken"])
	assert_eq([teeth.minutes, teeth.tool, teeth.item, teeth.reputation_event, teeth.piety_event], [15, &"pliers", &"teeth_pouch", &"teeth_taken", &"teeth_taken"])
	assert_almost(float(hair.min_freshness), 0.3)
	assert_almost(float(teeth.min_freshness), 0.0)
	assert_eq(util.sell_prices, {&"hair_braid": 4, &"teeth_pouch": 5})
	assert_eq(util.tool_items, [&"shears", &"pliers"] as Array[StringName])
	assert_eq(util.kind(&"nope"), {})
	var piety := PietyConfig.new()
	var reps := ReputationConfig.new()
	for kind: StringName in util.kinds:
		assert_true(piety.events.has(util.kind(kind).piety_event), "piety event of %s" % kind)
		assert_true(reps.event_points.has(util.kind(kind).reputation_event), "reputation event of %s" % kind)
	for cfg: TraderConfig in [Phase4Fixtures.trader_config(), TraderConfig.new()]:
		assert_eq([cfg.intro_day, cfg.intro_minute, cfg.notice_minute], [4, 360, 1365], "day 4, 06:00, 22:45")
		assert_eq([cfg.price(&"linen"), cfg.per_night(&"linen"), cfg.price(&"juniper"), cfg.per_night(&"juniper")], [2, 3, 1, 4])
		assert_eq([cfg.price(&"nope"), cfg.per_night(&"nope")], [0, 0])
		assert_eq([cfg.lorenz_after_talks, cfg.lorenz_after_sales, cfg.rumor_after_sales], [3, 4, 3])
	var trader := Phase4Fixtures.trader_config()
	assert_true(trader.intro_note.ends_with("– I. K."))
	for t: StringName in PietyRules.TIERS:
		assert_true(trader.greetings.get(t, "") != "", "greeting %s" % t)


func test_story_and_decay_config_values() -> void:
	for cfg: StoryConfig in [Phase4Fixtures.story_config(), StoryConfig.new()]:
		assert_eq([cfg.min_gap_days, cfg.key_fallback_day, cfg.key_flag, cfg.key_clue, cfg.chapter_section, cfg.finale_story],
				[2, 12, &"has_elder_key", &"c_elder_key", &"elder", &"s5_moor"])
		assert_eq(cfg.reserve_note, "Heute nichts. Aber halt eine Grube frei.")
	assert_true(Phase4Fixtures.story_config().key_fallback_text.contains("Fährstelle"))
	for cfg: DecayVisualConfig in [Phase4Fixtures.decay_visual_config(), DecayVisualConfig.new()]:
		var stages := [&"fresh", &"wilted", &"decaying", &"rotten"]
		for d: Dictionary in [cfg.overlay_by_stage, cfg.flies_by_stage, cfg.wisps_by_stage]:
			assert_eq(d.keys(), stages, "one value per stage")
		assert_eq(cfg.overlay_by_stage.values(), [0.0, 0.35, 0.7, 1.0])
		assert_eq(cfg.flies_by_stage.values(), [0, 4, 8, 10])
		assert_eq(cfg.wisps_by_stage.values(), [0, 0, 3, 5])
		assert_eq([cfg.smoke_particles, cfg.max_emitting], [3, 3])
		assert_almost(cfg.visibility_range, 22.0)
		assert_true(cfg.stain_color.is_equal_approx(Color("8E9A7E")), "stain colour")
		# §9: ≤ 3 corpses × (10 flies + 5 wisps + 3 smoke) ≤ 60 particles.
		assert_true(cfg.max_emitting * (int(cfg.flies_by_stage[&"rotten"]) + int(cfg.wisps_by_stage[&"rotten"]) + cfg.smoke_particles) <= 60)
		assert_true(cfg.wisp_color.a <= 0.35 and cfg.smoke_color.a <= 0.35, "§9 alpha")


func test_phase4_economy_fixture_reaches_13() -> void:
	var e := Phase4Fixtures.economy_config()
	assert_eq(e.quality_max, 13)
	# §2.4: 2 + 1 + 3 + 1 + 3 + 1 + 1 + 1 = 13 (buried, washed, gown, laid out, stone, fresh, examined, valuables left).
	var top := e.quality_buried + e.quality_washed + e.dress_quality[&"gown"] + e.quality_laid_out \
			+ e.marker_quality[&"gravestone_simple"] + e.fresh_good_bonus + e.quality_examined + e.valuables_left_bonus
	assert_eq(top, e.quality_max)
	assert_eq(Phase4Fixtures.cleanliness_config().penalty_by_level, PackedInt32Array([0, 0, 1, 3]))
	assert_eq(Phase4Fixtures.reputation_config().event_points.size(), 8)


func test_find_fixtures() -> void:
	var all := Phase4Fixtures.finds()
	assert_eq(all.size(), 28)
	var ids := {}
	for f: FindData in all:
		assert_not_null(f)
		if f == null:
			continue
		assert_false(ids.has(f.id), "unique %s" % f.id)
		ids[f.id] = true
		assert_true(f.step in CorpseRecord.STEPS, "%s step" % f.id)
		assert_true(f.min_freshness in [0.0, 0.3, 0.6], "%s freshness class" % f.id)
		if f.min_freshness > 0.0:
			assert_true(f.lost_text != "", "%s lost text" % f.id)
		if f.clue_id != &"":
			assert_true(Phase4Fixtures.CLUE_IDS.has(f.clue_id), "%s clue %s" % [f.id, f.clue_id])
		assert_eq(f.story_only, Phase4Fixtures.STORY_FIND_IDS.has(f.id), "%s story_only" % f.id)
	var exam := Phase4Fixtures.exam_config()
	for id: StringName in [&"f_valuables", &"f_letter", &"f_tattoo", &"f_mark"]:
		var f := Phase4Fixtures.find(id)
		assert_eq(f.step, exam.trait_steps[f.trait_id], "%s on the step of its trait" % id)
	assert_eq(Phase4Fixtures.find(&"f_s3_mark").trait_id, &"strange_wound", "replaces f_mark")
	assert_eq(Phase4Fixtures.find(&"f_s3_letter").trait_id, &"letter", "replaces f_letter")
	assert_eq(Phase4Fixtures.find(&"f_s2_key").sets_flag, &"has_elder_key")
	assert_true(Phase4Fixtures.find(&"f_tattoo").is_lost_at(0.29) and not Phase4Fixtures.find(&"f_tattoo").is_lost_at(0.3), "exactly at min_freshness")
	assert_eq(Phase4Fixtures.find(&"f_cause_moor_cold").cause_id, &"moor_cold")


func test_story_fixtures() -> void:
	var days: Array = []
	var looks: Array = []
	for s: StoryCorpseData in Phase4Fixtures.stories():
		days.append(s.earliest_day)
		looks.append(s.look)
		assert_eq(s.valuables_coins, 0, String(s.id))
		assert_false(s.traits.has(&"valuables"), String(s.id))
		assert_true(s.arrival_note != "" and s.display_name != "", String(s.id))
		for fid: StringName in s.finds:
			var f := Phase4Fixtures.find(fid)
			assert_not_null(f, "%s find %s" % [s.id, fid])
			if f != null:
				assert_true(f.story_only, "%s: %s story_only" % [s.id, fid])
				assert_true(String(fid).begins_with("f_" + String(s.id).substr(0, 2)), "%s owns %s" % [s.id, fid])
		assert_eq(s.is_finale, s.id == Phase4Fixtures.story_config().finale_story)
	assert_eq(days, [6, 9, 13, 16, 19])
	assert_eq(looks, [1, 0, 5, 2, 4])
	assert_eq(Phase4Fixtures.story(&"s5_moor").cause_id, &"moor_cold")
	assert_eq(Phase4Fixtures.story(&"s3_wernstein").traits, [&"strange_wound", &"letter"] as Array[StringName])


func test_clue_and_insight_fixtures() -> void:
	var clues := Phase4Fixtures.clues()
	assert_eq(clues.size(), 18)
	var orders: Array = []
	for c: ClueData in clues:
		assert_true(c.title != "" and c.text != "", String(c.id))
		assert_true(c.kind in ClueData.KINDS, "%s kind %s" % [c.id, c.kind])
		orders.append(c.order)
	assert_eq(orders, range(1, 19))
	var insights := Phase4Fixtures.insights()
	assert_eq(insights.size(), 6)
	var optional := 0
	for i: InsightData in insights:
		assert_true(i.requires.size() >= 2 and i.requires.size() <= 3, "%s needs 2–3 clues" % i.id)
		for c: StringName in i.requires:
			assert_true(Phase4Fixtures.CLUE_IDS.has(c), "%s requires %s" % [i.id, c])
		assert_eq(i.sets_flag, StringName("insight_" + String(i.id).trim_prefix("i_")), String(i.id))
		assert_true(i.question.ends_with("?"), "%s open question" % i.id)
		if i.optional:
			optional += 1
	assert_eq(optional, 1, "i_kranich is optional")
	var nl := Phase4Fixtures.insight(&"i_not_lorenz")
	assert_eq([nl.rename_story, nl.rename_to], [&"s5_moor", "Kaspar Dorn"])


func test_elder_section_and_clearables() -> void:
	var elder := Phase4Fixtures.elder_section()
	assert_eq([elder.id, elder.display_name, elder.order, elder.decor_cap], [&"elder", "Holunderwinkel", 4, 6])
	assert_eq([elder.requires_flag, elder.counts_for_cemetery, elder.chapter], [&"has_elder_key", false, &"six_pits"])
	assert_eq(elder.requires_flag_text, "Das Pförtchen ist verschlossen.")
	# §2.10: 1 gate, 2 thickets, 6 pits, 1 fence gap = 300 min, cost 2 wood + 1 iron, yield 4 wood.
	var counts := {&"gate_small": 1, &"elder_thicket": 2, &"sunken_pit": 6}
	var minutes := Phase3Fixtures.clearable(&"fence_gap").minutes
	var wood := 0
	for id: StringName in counts:
		var c := Phase4Fixtures.clearable(id)
		assert_eq(c.id, id)
		minutes += c.minutes * int(counts[id])
		wood += int(c.yield_items.get(&"wood", 0)) * int(counts[id])
	assert_eq(minutes, 300)
	assert_eq(wood, 4)


func test_item_and_schedule_fixtures() -> void:
	var expected := {&"scrub_brush": [ItemData.Category.TOOL, 1], &"comb": [ItemData.Category.TOOL, 1],
			&"burial_gown": [ItemData.Category.CRAFTED, 5], &"juniper": [ItemData.Category.RESOURCE, 10],
			&"shears": [ItemData.Category.TOOL, 1], &"pliers": [ItemData.Category.TOOL, 1],
			&"hair_braid": [ItemData.Category.GOODS, 10], &"teeth_pouch": [ItemData.Category.GOODS, 10]}
	for id: StringName in Phase4Fixtures.NEW_ITEM_IDS:
		var item := Phase4Fixtures.item(id)
		assert_not_null(item, String(id))
		if item != null:
			assert_eq([item.id, item.category, item.max_stack], [id, expected[id][0], expected[id][1]], String(id))
	var sched := Phase4Fixtures.trader_schedule()
	assert_eq(sched.npc_id, &"trader")
	var spot := ScheduleResolver.entry_at(sched, 23 * 60 + 30)
	assert_eq([spot.dialogue_id, spot.visible, Array(spot.path)], [&"trader", true, ["trader_spot"]], "23:30 at the wall")
	assert_eq(ScheduleResolver.entry_at(sched, 2 * 60).dialogue_id, &"trader", "02:00 still there")
	assert_false(ScheduleResolver.entry_at(sched, 12 * 60).visible, "away by day")
	assert_eq(ScheduleResolver.arrival_minute(ScheduleResolver.entry_at(sched, 22 * 60 + 45)), 1380, "arrives 23:00")
	assert_eq(ScheduleResolver.arrival_minute(ScheduleResolver.entry_at(sched, 3 * 60 + 5)), 200, "gone 03:20")


func test_corpse_fixture_helper() -> void:
	var r := Phase4Fixtures.corpse([&"valuables", &"tattoo"] as Array[StringName], &"drowned_millpond", 0.5)
	assert_eq([r.cause_id, r.freshness, r.valuables_coins, r.location], [&"drowned_millpond", 0.5, 6, CorpseRecord.LOCATION_DROPOFF])
	assert_true(r.has_trait(&"tattoo"))


func test_database_phase4_folders() -> void:
	# The real data folders are the owners' (P1 story, P2 finds, P6 journal) – empty until W1.
	for list: Array in [Database.finds(), Database.story_corpses(), Database.clues(), Database.insights()]:
		for res: Resource in list:
			assert_true(res.get("id") != &"", "keyed by id")
	assert_null(Database.find(&"nope"))
	assert_null(Database.story_corpse(&"nope"))
	assert_null(Database.clue(&"nope"))
	assert_null(Database.insight(&"nope"))
	for name: StringName in Phase4Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	# Sorting by order (ties by id) – the helper the four lists use.
	var a := ClueData.new()
	a.id = &"b"
	a.order = 2
	var b := ClueData.new()
	b.id = &"a"
	b.order = 2
	var c := ClueData.new()
	c.id = &"z"
	c.order = 1
	var sorted: Array = Database._sorted([a, b, c], "order")
	assert_eq([sorted[0].id, sorted[1].id, sorted[2].id], [&"z", &"a", &"b"])


func test_save_format_v3_and_migration_chain() -> void:
	# Phase 5 W0: v4 (docs/PHASE5_DESIGN.md §5) – the v3 step of the chain stays.
	assert_eq(SaveMigration.CURRENT, 7)  # Phase 6: v5, Phase 7: v6, Phase 8: v7
	assert_eq(SaveFileIO.FORMAT_VERSION, 7)
	assert_eq(SaveManager.FORMAT_VERSION, 7)
	assert_eq(SaveMigration.V3_EMPTY_NODES, PackedStringArray(["journal", "night_trade", "npc_trader"]))
	var state := {"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {}}}
	assert_eq(SaveMigration.migrate(state, SaveMigration.CURRENT), state, "current version unchanged")
	assert_eq(SaveMigration.migrate(state, SaveMigration.CURRENT + 1), {}, "newer → corrupt")
	var v3 := SaveMigration.migrate_2_to_3(state, {"day": 5})
	# P6 filled §5.2 (tests/unit/test_save_migration.gd); the input stays untouched.
	assert_eq(state.nodes, {"corpse_manager": {}}, "input unchanged")
	assert_false(is_same(v3, state), "deep copy")
	assert_true((v3.nodes as Dictionary).has_all(Array(SaveMigration.V3_EMPTY_NODES)), "empty v3 node states")
	var from_v2 := SaveMigration.migrate(state, 2, {"day": 5})
	assert_true(from_v2.get("autoloads") is Dictionary and from_v2.get("nodes") is Dictionary)
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true(from_v1.get("nodes") is Dictionary and (from_v1.nodes as Dictionary).has("expansion"), "v1 → v2 → v3 chain")


# --- helpers ----------------------------------------------------------------------------------

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


func _keys_of(action: String) -> Array:
	var out: Array = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append((e as InputEventKey).physical_keycode)
	return out
