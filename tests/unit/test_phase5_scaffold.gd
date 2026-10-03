extends TestCase
## Lead / W0 (docs/PHASE5_DESIGN.md §12): the Phase-5 scaffold – every stub class loads with its
## contract signature, every new data class / config .tres holds valid contract values, the
## extensions of existing data classes, EventBus signals, no new input actions, the appended enum
## value MATERIAL, Database folders, save format v4 + migration chain 1 → 2 → 3 → 4, and the W1
## fixtures (tests/fixtures/phase5, Phase5Fixtures).

## Stubs whose owners have filled them in (W1) – no longer marked "## STUB (".
const IMPLEMENTED: PackedStringArray = ["ToolRules", "GatherRules", "GatherManager", "GatherNode", "SaveMigration", "WorkshopRules", "Workshop", "BuildSite", "StoneDesignRules", "StoneCalendar", "Stonemasonry"]
## Stub scripts by W1 package (path → class_name). Owners replace the bodies, never the names.
const STUBS := {
	# P1
	"res://src/systems/workshop/workshop_rules.gd": "WorkshopRules",
	"res://src/systems/workshop/workshop.gd": "Workshop",
	"res://src/entities/build_site/build_site.gd": "BuildSite",
	# P2
	"res://src/systems/gathering/gather_rules.gd": "GatherRules",
	"res://src/systems/gathering/gather_manager.gd": "GatherManager",
	"res://src/entities/gather_node/gather_node.gd": "GatherNode",
	# P3
	"res://src/systems/tools/tool_rules.gd": "ToolRules",
	# P4
	"res://src/systems/stone/stone_design_rules.gd": "StoneDesignRules",
	"res://src/systems/stone/stone_calendar.gd": "StoneCalendar",
	"res://src/systems/stone/stonemasonry.gd": "Stonemasonry",
}
## Contract methods per stub class (§3.4) – a rename breaks this list.
const METHODS := {
	"WorkshopRules": ["build_block_reason", "missing", "goal_progress"],
	"Workshop": ["is_open", "is_built", "built", "build", "start_job", "job_of", "collect", "goal_progress", "check_goal",
			"apply_morning", "save_state", "load_state", "post_load"],
	"BuildSite": ["request_build", "can_interact", "get_interaction_prompt", "interact"],
	"GatherRules": ["refreshed", "stage", "days_left", "block_reason", "yield_for"],
	"GatherManager": ["register", "state_of", "charges", "stage", "gather", "refresh", "save_state", "load_state", "post_load"],
	"GatherNode": ["can_interact", "get_interaction_prompt", "interact"],
	"ToolRules": ["tier", "block_reason", "tool_name"],
	"StoneDesignRules": ["fits", "render_text", "marker_points", "breakdown_lines", "inputs", "minutes", "current_marker_points"],
	"StoneCalendar": ["date_text", "year_of"],
	"Stonemasonry": ["eligible_graves", "preview", "order_block_reason", "carve", "ready_stones", "ready_for", "discard",
			"set_stone", "save_state", "load_state"],
}
## Argument counts of the contract signatures (§3.4) – [class, method, args].
const ARITY := [
	["WorkshopRules", "build_block_reason", 4], ["WorkshopRules", "missing", 2], ["WorkshopRules", "goal_progress", 4],
	["Workshop", "build", 2], ["Workshop", "start_job", 3], ["Workshop", "job_of", 1], ["Workshop", "collect", 2],
	["Workshop", "apply_morning", 1],
	["GatherRules", "refreshed", 3], ["GatherRules", "stage", 3], ["GatherRules", "days_left", 3],
	["GatherRules", "block_reason", 6], ["GatherRules", "yield_for", 2],
	["GatherManager", "register", 2], ["GatherManager", "gather", 3], ["GatherManager", "refresh", 1],
	["ToolRules", "tier", 2], ["ToolRules", "block_reason", 4], ["ToolRules", "tool_name", 3],
	["StoneDesignRules", "fits", 2], ["StoneDesignRules", "render_text", 3], ["StoneDesignRules", "marker_points", 4],
	["StoneDesignRules", "breakdown_lines", 4], ["StoneDesignRules", "inputs", 2], ["StoneDesignRules", "minutes", 2],
	["StoneDesignRules", "current_marker_points", 4],
	["StoneCalendar", "date_text", 2], ["StoneCalendar", "year_of", 2],
	["Stonemasonry", "preview", 2], ["Stonemasonry", "order_block_reason", 3], ["Stonemasonry", "carve", 3],
	["Stonemasonry", "ready_for", 1], ["Stonemasonry", "discard", 1], ["Stonemasonry", "set_stone", 2],
]
## Stub / new methods added to existing classes (owner in the comment).
const EXISTING_STUBS := {
	"res://src/systems/decoration/decoration_manager.gd": ["evict_rects"],  # P1
	"res://src/systems/inventory/inventory.gd": ["tools"],  # P3
	"res://src/entities/player/player.gd": ["tool_tier"],  # P3
	"res://src/systems/graveyard/graveyard.gd": ["set_designed_stone"],  # P4
	"res://src/systems/graveyard/grave_quality.gd": ["breakdown", "compute"],  # P4 (+ design)
	"res://src/systems/save/save_migration.gd": ["migrate", "migrate_1_to_2", "migrate_2_to_3", "migrate_3_to_4"],  # P6
	"res://src/entities/player/action_config.gd": ["tool_minutes"],  # W0 (data class)
}
## [script, method, args] of the extended signatures of existing classes.
const EXISTING_ARITY := [
	["res://src/systems/decoration/decoration_manager.gd", "evict_rects", 1],
	["res://src/entities/player/player.gd", "tool_tier", 1],
	["res://src/systems/graveyard/graveyard.gd", "set_designed_stone", 3],
	["res://src/systems/graveyard/grave_quality.gd", "breakdown", 4],
	["res://src/systems/graveyard/grave_quality.gd", "compute", 4],
	["res://src/systems/save/save_migration.gd", "migrate_3_to_4", 2],
	["res://src/entities/player/action_config.gd", "tool_minutes", 2],
]
## Saveable stubs: [class, save_id, save_order, identity group] (§3.1).
const SAVEABLES := [
	["Workshop", "workshop", 30, &"workshop"],
	["GatherManager", "gathering", 25, &"gathering"],
	["Stonemasonry", "stonemasonry", 35, &"stonemasonry"],
]
const SIGNALS := {
	"station_built": 1, "workshop_job_changed": 3, "resource_gathered": 3, "gather_node_changed": 3,
	"tool_tier_changed": 2, "stone_order_changed": 3, "grave_stone_set": 3, "coins_spent": 2,
}
const DATA_CLASSES := {
	"StationData": "res://src/systems/workshop/station_data.gd", "WorkshopConfig": "res://src/systems/workshop/workshop_config.gd",
	"GatherNodeData": "res://src/systems/gathering/gather_node_data.gd", "ToolConfig": "res://src/systems/tools/tool_config.gd",
	"StoneShapeData": "res://src/systems/stone/stone_shape_data.gd", "InscriptionData": "res://src/systems/stone/inscription_data.gd",
	"OrnamentData": "res://src/systems/stone/ornament_data.gd", "StoneConfig": "res://src/systems/stone/stone_config.gd",
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
	assert_eq(global.get("StoneDesign"), "res://src/systems/stone/stone_design.gd")


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
	var workshop := Workshop.new()
	assert_eq(workshop.workyard_rects, [] as Array[Rect2], "Workshop.workyard_rects export")
	workshop.free()
	for cls: String in ["BuildSite", "GatherNode"]:
		var n: Node = (load(_path_of(cls)) as GDScript).new()
		assert_true(n is Node3D, cls)
		n.free()
	for path: String in ["res://src/entities/build_site/build_site.tscn", "res://src/entities/gather_node/gather_node.tscn"]:
		var scene := load(path) as PackedScene
		assert_not_null(scene, path)
		if scene != null:
			var inst := scene.instantiate()
			assert_not_null(inst.get_node_or_null(^"Interactable"), path + " Interactable")
			inst.free()


func test_stub_members_on_existing_classes() -> void:
	for path: String in EXISTING_STUBS:
		var names := _methods(load(path) as GDScript)
		for method: String in EXISTING_STUBS[path]:
			assert_true(names.has(method), "%s.%s" % [path.get_file(), method])
	var bench: Node = (load("res://src/entities/workbench/workbench.gd") as GDScript).new()
	assert_eq(bench.get(&"requires_built"), false, "Workbench.requires_built (P1)")
	bench.free()
	var inv := Inventory.new()
	assert_eq(inv.tool_belt, false, "Inventory.tool_belt (P3)")
	assert_eq(inv.tools(), {} as Dictionary[StringName, int])
	inv.free()
	assert_eq(GraveRecord.new().design, {}, "GraveRecord.design (P4)")
	assert_eq(ToolRules.tier(null, &"shovel"), 0, "stub tier 0 until P3 (§12)")


func test_event_bus_signals() -> void:
	for sig: String in SIGNALS:
		assert_true(EventBus.has_signal(sig), sig)
	var found := 0
	for s: Dictionary in EventBus.get_signal_list():
		if SIGNALS.has(String(s.name)):
			found += 1
			assert_eq((s.args as Array).size(), SIGNALS[String(s.name)], String(s.name) + " args")
	assert_eq(found, 8, "§3.3: 8 new signals")


func test_no_new_input_actions() -> void:
	# §3.6: no new keys – the stone panel pages with the Phase-4 actions [ / ].
	for action: String in ["journal_page_prev", "journal_page_next", "interact", "ui_cancel"]:
		assert_true(InputMap.has_action(action), action)


func test_appended_enum_values() -> void:
	assert_eq([ItemData.Category.RESOURCE, ItemData.Category.CRAFTED, ItemData.Category.CURRENCY,
			ItemData.Category.DECOR, ItemData.Category.TOOL, ItemData.Category.GOODS, ItemData.Category.MATERIAL],
			[0, 1, 2, 3, 4, 5, 6])
	assert_eq(ItemData.Category.size(), 7)


func test_extended_data_classes() -> void:
	var item := ItemData.new()
	assert_eq([item.tool_kind, item.tool_tier], [&"", 0])
	assert_false(RecipeData.new().background)
	var c := ClearableData.new()
	assert_eq([c.tool_kind, c.min_tier], [&"", 0])
	assert_true(SectionData.new().is_burial)
	# P2 (W0 note 6): only the approved sections I–IV; bruch / quarry are work areas.
	for real: SectionData in Database.sections():
		if real.id in [&"yard", &"east", &"north", &"elder", &"linden"]:  # Phase 7 (P3): + the Lindenacker
			assert_true(real.is_burial, "%s: the approved sections are burial sections" % real.id)
		else:
			assert_false(real.is_burial, "%s: a work area" % real.id)
	var a := ActionConfig.new()
	assert_eq(Array(a.tool_tier_factors), [1.0, 0.8, 0.6])
	assert_eq(a.action_tools, {&"dig": &"shovel", &"bury": &"shovel"})
	assert_eq(a.tool_minute_step, 5)
	assert_eq(PlayerConfig.new().inventory_slots, 20)
	# EconomyConfig: quality_max 19 and the stone shapes only in the fixture until P4 (W0-Notizen 4).
	var e := Phase5Fixtures.economy_config()
	assert_eq(e.quality_max, 19)
	assert_eq([e.marker_quality[&"wooden_cross"], e.marker_quality[&"gravestone_simple"], e.marker_quality[&"stone_stele"],
			e.marker_quality[&"stone_arch"], e.marker_quality[&"stone_master"]], [1, 3, 3, 4, 5])
	assert_eq(GhostLines.new().by_design, {} as Dictionary[StringName, PackedStringArray])
	assert_eq(ReputationConfig.new().event_points[&"master_stone"], 3)
	assert_true(PietyConfig.new().full_prep_requires_unharvested)
	var prep := PrepConfig.new()
	# Phase 7 (P7, W0-Notizen 4): + corpse_balm as third entry (class default and data together).
	assert_eq(prep.balm_items, [&"juniper", &"herb_bundle", &"corpse_balm"] as Array[StringName])
	assert_eq(prep.balm_items[0], prep.balm_item, "balm_item stays the first element")
	var t := TraderConfig.new()
	assert_eq([t.price(&"gold_leaf"), t.per_night(&"gold_leaf"), t.price(&"linen"), t.price(&"juniper")], [6, 2, 2, 1])


func test_tool_minutes_table() -> void:
	# §2.3 table (base → tier 0 / 1 / 2), rounded to 5 minutes (§1.3).
	var table := {60: [60, 50, 35], 30: [30, 25, 20], 40: [40, 30, 25], 45: [45, 35, 25], 20: [20, 15, 10], 10: [10, 10, 5]}
	for cfg: ActionConfig in [ActionConfig.new(), Phase5Fixtures.action_config()]:
		for base: int in table:
			for tier: int in 3:
				assert_eq(cfg.tool_minutes(base, tier), table[base][tier], "%d min at tier %d" % [base, tier])
		assert_eq(cfg.tool_minutes(60, 7), 35, "tier above the table clamps")
		assert_eq(cfg.tool_minutes(2, 2), 5, "never below one step")


func test_stone_design_value_object() -> void:
	var empty := StoneDesign.new()
	assert_true(empty.is_empty())
	assert_eq(empty.to_dict(), {})
	assert_true(StoneDesign.from_dict({}).is_empty())
	var d := Phase5Fixtures.design(&"stone_master", &"i_garden", &"orn_elder", true,
			PackedStringArray(["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."]))
	var dict := d.to_dict()
	assert_eq(dict, {"shape": "stone_master", "inscription": "i_garden", "ornament": "orn_elder", "gilded": true,
			"text": ["Marthe Quendel", "* 1771 – † 8. Nebelung 1834", "Was du gesät hast, blüht noch."]}, "§5.1 format")
	var back := StoneDesign.from_dict(JSON.parse_string(JSON.stringify(dict)) as Dictionary)
	assert_eq([back.shape, back.inscription, back.ornament, back.gilded, back.text], [d.shape, d.inscription, d.ornament, d.gilded, d.text])
	var odd := StoneDesign.from_dict({"shape": 5, "gilded": "yes", "text": "nope"})
	assert_true(odd.is_empty() and not odd.gilded and odd.text.is_empty(), "tolerant")


func test_config_files_in_data_match_the_fixtures() -> void:
	for name: StringName in Phase5Fixtures.CONFIG_NAMES:
		var real := Database.config(name)
		var fixture := Phase5Fixtures.config(name)
		assert_not_null(real, "data/config/%s.tres" % name)
		assert_not_null(fixture, "%s fixture" % name)
		if real == null or fixture == null:
			continue
		assert_eq((real.get_script() as Script).get_global_name(), (fixture.get_script() as Script).get_global_name(), String(name))
		var defaults: Resource = (real.get_script() as GDScript).new()
		for prop: Dictionary in real.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert_eq(real.get(prop.name), fixture.get(prop.name), "%s.%s" % [name, prop.name])
				assert_eq(defaults.get(prop.name), fixture.get(prop.name), "%s.%s = class default" % [name, prop.name])


func test_workshop_and_tool_config_values() -> void:
	var w := Phase5Fixtures.workshop_config()
	assert_eq([w.unlock_flag, w.open_flag, w.license_flag, w.intro_minute], [&"cemetery_complete", &"workshop_open", &"bruch_license", 360])
	assert_eq(w.goal_stations, [&"mason", &"loom", &"forge"] as Array[StringName])
	assert_eq(w.goal_tiers, {&"shovel": 1, &"axe": 1, &"pickaxe": 2})
	assert_eq([w.goal_master_stones, w.chapter_id, w.goal_flag, w.ready_slots], [1, &"names_in_stone", &"names_in_stone_complete", 3])
	var t := Phase5Fixtures.tool_config()
	assert_eq(t.kinds, [&"shovel", &"axe", &"pickaxe"] as Array[StringName])
	for kind: StringName in t.kinds:
		assert_true(t.labels.has(kind) and t.base_names.has(kind) and t.source_hint.has(kind), String(kind))
	assert_eq(t.base_names[&"pickaxe"], "", "no tier-0 pickaxe")
	assert_eq(Phase5Fixtures.player_config().inventory_slots, 20)


func test_stone_config_values() -> void:
	var s := Phase5Fixtures.stone_config()
	assert_eq([s.inscription_points, s.fitting_points, s.gilded_points, s.ink_item, s.ink_amount, s.inscription_minutes,
			s.gold_item, s.gilding_minutes, s.set_minutes], [1, 1, 1, &"ink", 1, 20, &"gold_leaf", 10, 20])
	assert_eq([int(s.calendar.start_year), int(s.calendar.start_month), int(s.calendar.start_day)], [1834, 10, 3], "§14.3")
	var names: Array = s.calendar.month_names
	var days: Array = s.calendar.month_days
	assert_eq([names.size(), days.size(), names[9], names[10]], [12, 12, "Gilbhart", "Nebelung"])
	var total := 0
	for d: Variant in days:
		total += int(d)
	assert_eq(total, 365, "real month lengths (1834 is no leap year)")
	assert_true(s.ink_color.is_equal_approx(Color("2A1F18")) and s.gold_color.is_equal_approx(Color("C9A24A")))


func test_station_fixtures() -> void:
	var expected := {&"workbench": ["", {}, 0, &"crafting", true],
			&"mason": ["site_mason", {&"stone": 6, &"wood": 3}, 15, &"stone_design", false],
			&"loom": ["site_loom", {&"wood": 8, &"iron_fittings": 2}, 10, &"crafting", false],
			&"forge": ["site_forge", {&"stone": 10, &"clay": 6, &"iron_fittings": 2}, 25, &"crafting", false]}
	var coins := 0
	for s: StationData in Phase5Fixtures.stations():
		assert_not_null(s)
		var e: Array = expected[s.id]
		assert_eq([s.site_id, s.build_inputs, s.build_coins, s.panel, s.prebuilt], e, String(s.id))
		coins += s.build_coins
		if not s.prebuilt:
			assert_true(s.display_name != "" and s.prompt_use.begins_with("[E] ") and s.build_text != "" and s.coin_part_label != "", String(s.id))
	assert_eq(coins, 50, "§2.8: 15 + 10 + 25")
	assert_eq([Phase5Fixtures.station(&"mason").build_minutes, Phase5Fixtures.station(&"loom").build_minutes,
			Phase5Fixtures.station(&"forge").build_minutes], [90, 90, 120], "§1.3")
	assert_eq(Phase5Fixtures.station(&"mason").coin_part_label, "Meißelsatz aus Hollerbrück")


func test_gather_fixtures() -> void:
	# §2.2: item, yield, charges, regrow days, tool, min tier, base minutes, tier-2 bonus.
	var expected := {&"alder": [&"wood", 4, 1, 5, &"axe", 1, 60, 1], &"flax_bed": [&"flax", 3, 1, 3, &"", 0, 20, 0],
			&"clay_pit": [&"clay", 2, 3, 1, &"shovel", 0, 30, 1], &"rubble_face": [&"stone", 2, 4, 1, &"pickaxe", 1, 30, 1],
			&"ore_vein": [&"iron_ore", 1, 3, 1, &"pickaxe", 1, 40, 0], &"workstone_ledge": [&"workstone", 1, 2, 1, &"pickaxe", 2, 45, 0],
			&"elder_bush": [&"elderberries", 2, 1, 2, &"", 0, 10, 0], &"herb_patch": [&"herbs", 1, 2, 2, &"", 0, 10, 0]}
	for g: GatherNodeData in Phase5Fixtures.gather_kinds():
		assert_not_null(g)
		assert_eq([g.item_id, g.yield_amount, g.charges_max, g.regrow_days, g.tool_kind, g.min_tier, g.minutes, g.tier2_bonus],
				expected[g.id], String(g.id))
		assert_eq(g.requires_flag, &"workshop_open", String(g.id))
		assert_true(g.verb != "" and g.display_name != "", String(g.id))
		assert_true(Phase5Fixtures.item(g.item_id) != null or [&"wood", &"stone"].has(g.item_id), "%s item" % g.id)
	assert_eq(Phase5Fixtures.gather_kind(&"alder").regrow_stage_days, PackedInt32Array([2, 5]))


func test_clearable_and_section_fixtures() -> void:
	var boulder := Phase5Fixtures.clearable(&"boulder")
	assert_eq([boulder.minutes, boulder.tool_kind, boulder.min_tier, boulder.yield_items], [60, &"pickaxe", 1, {&"stone": 3}])
	var gate := Phase5Fixtures.clearable(&"gate_east")
	assert_eq([gate.minutes, gate.tool_kind, gate.cost], [10, &"", {}])
	var bruch := Phase5Fixtures.section(&"bruch")
	var quarry := Phase5Fixtures.section(&"quarry")
	for s: SectionData in [bruch, quarry]:
		assert_eq([s.is_burial, s.counts_for_cemetery, s.decor_cap], [false, false, 0], String(s.id))
	assert_eq([bruch.requires_flag, bruch.requires_flag_text], [&"bruch_license", "Die Pforte ist zu. Osric weiß, wer den Schlüssel hat."])
	assert_eq(quarry.requires_section, &"bruch")
	for real: SectionData in Database.sections():
		if real.id in [&"bruch", &"quarry", &"churchyard", &"linden"]:
			continue  # P2 (W1): the real work areas themselves; Phase 6 (W-Welt): the churchyard (order 7) comes after them; Phase 7 (P3): the Lindenacker (order 8)
		assert_true(bruch.order > real.order and quarry.order > real.order, "orders after %s" % real.id)


func test_item_fixtures() -> void:
	for id: StringName in Phase5Fixtures.MATERIAL_IDS:
		var item := Phase5Fixtures.item(id)
		assert_not_null(item, String(id))
		if item != null:
			assert_eq([item.id, item.category], [id, ItemData.Category.MATERIAL], String(id))
			assert_true(item.display_name != "", String(id))
	var stacks := {&"workstone": 10, &"steel_rod": 5, &"iron_ore": 20, &"flax": 30}
	for id: StringName in stacks:
		assert_eq(Phase5Fixtures.item(id).max_stack, stacks[id], String(id))
	for kind: StringName in Phase5Fixtures.TOOL_ITEMS:
		var ids: Array = Phase5Fixtures.TOOL_ITEMS[kind]
		for tier: int in [1, 2]:
			var tool := Phase5Fixtures.item(ids[tier])
			assert_eq([tool.category, tool.max_stack, tool.tool_kind, tool.tool_tier], [ItemData.Category.TOOL, 1, kind, tier], String(ids[tier]))
	for id: StringName in [&"rake", &"shears", &"pliers", &"comb", &"scrub_brush"]:
		assert_eq(Phase5Fixtures.item(id).tool_kind, &"", "%s has no tiers" % id)


func test_recipe_fixtures() -> void:
	var per_station := {}
	for r: RecipeData in Phase5Fixtures.recipes():
		assert_not_null(r)
		per_station[r.station] = int(per_station.get(r.station, 0)) + 1
		assert_true(r.category in [&"material", &"tool", &"grave"], "%s category" % r.id)
		assert_eq(r.background, r.id == &"charcoal", "%s background" % r.id)
		for input: StringName in r.inputs:
			assert_true(Phase5Fixtures.item(input) != null, "%s input %s" % [r.id, input])
		assert_true(Phase5Fixtures.item(r.output_id) != null, "%s output" % r.id)
	assert_eq(Phase5Fixtures.recipes().size(), 13, "§2.4: 13 new recipes")
	assert_eq(per_station, {&"forge": 8, &"loom": 3, &"workbench": 2})
	# Upgrades consume the lower tool (§2.3).
	for spec: Array in [[&"shovel_master", &"shovel_iron"], [&"axe_master", &"axe_iron"], [&"pickaxe_master", &"pickaxe_iron"]]:
		assert_eq(Phase5Fixtures.recipe(spec[0]).inputs.get(spec[1], 0), 1, String(spec[0]))
	var kiln := Phase5Fixtures.recipe(&"charcoal")
	assert_eq([kiln.inputs, kiln.output_amount, kiln.craft_minutes], [{&"wood": 4}, 3, 10])


func test_stone_fixtures() -> void:
	var points := []
	for s: StoneShapeData in Phase5Fixtures.stone_shapes():
		points.append(Phase5Fixtures.economy_config().marker_quality[s.id])
		assert_eq(s.max_lines, 4)
	assert_eq(points, [3, 4, 5])
	assert_eq(Phase5Fixtures.stone_shape(&"stone_master").inputs, {&"workstone": 3, &"stone": 2, &"iron_fittings": 2, &"clay": 1})
	assert_eq([Phase5Fixtures.stone_shape(&"stone_stele").minutes, Phase5Fixtures.stone_shape(&"stone_arch").minutes,
			Phase5Fixtures.stone_shape(&"stone_master").minutes], [50, 70, 150])
	var orders := []
	for i: InscriptionData in Phase5Fixtures.inscriptions():
		orders.append(i.order)
		assert_true(i.lines.size() >= 2 and i.lines.size() <= 4, String(i.id))
		assert_true(" ".join(i.lines).contains("{name}"), "%s has the name" % i.id)
	assert_eq(orders, [1, 2, 3, 4, 5, 6, 7])
	var rest := Phase5Fixtures.inscription(&"i_rest")
	assert_eq([rest.fits_causes.size(), rest.fits_min_age, rest.fits_max_age, rest.fits_story.size()], [0, -1, -1, 0], "i_rest never fits")
	assert_eq(Phase5Fixtures.inscription(&"i_long_road").fits_min_age, 60)
	assert_eq(Phase5Fixtures.inscription(&"i_too_soon").fits_max_age, 35)
	assert_eq(Phase5Fixtures.inscription(&"i_water").fits_causes, [&"drowned_millpond", &"moor_cold"] as Array[StringName])
	assert_eq(Phase5Fixtures.inscription(&"i_garden").fits_story, [&"s1_quendel"] as Array[StringName])
	var total := 0
	for o: OrnamentData in Phase5Fixtures.ornaments():
		assert_eq([o.points, o.minutes], [1, 25], String(o.id))
		assert_true(o.tooltip != "" and o.display_name != "", String(o.id))
		total += 1
	assert_eq(total, 4)
	# §2.5: maximum 19 = buried 2 + washed 1 + gown 3 + laid out 1 + master stone 9 + fresh 1 + examined 1 + valuables 1.
	var e := Phase5Fixtures.economy_config()
	var s := Phase5Fixtures.stone_config()
	var master := e.marker_quality[&"stone_master"] + s.inscription_points + s.fitting_points + s.gilded_points + 1
	assert_eq(master, 9)
	assert_eq(e.quality_buried + e.quality_washed + e.dress_quality[&"gown"] + e.quality_laid_out + master + e.fresh_good_bonus
			+ e.quality_examined + e.valuables_left_bonus, e.quality_max)
	assert_eq(e.quality_max, 19)
	assert_eq(Phase5Fixtures.reputation_config().event_points[&"master_stone"], 3)


func test_other_config_fixtures() -> void:
	assert_true(Phase5Fixtures.piety_config().full_prep_requires_unharvested)
	assert_eq(Phase5Fixtures.prep_config().balm_items, [&"juniper", &"herb_bundle"] as Array[StringName])
	var t := Phase5Fixtures.trader_config()
	assert_eq([t.price(&"gold_leaf"), t.per_night(&"gold_leaf")], [6, 2])
	var lines := Phase5Fixtures.ghost_lines()
	assert_eq(lines.by_reason[&"nameless"].size(), 3)
	assert_eq(lines.by_design.keys(), [&"default", &"gilded", &"master", &"s5_lorenz"])
	for kind: StringName in Phase5Fixtures.EXTENDED_CONFIG_NAMES:
		assert_not_null(Phase5Fixtures.config(kind), String(kind))


func test_fixture_helpers() -> void:
	var inv := Phase5Fixtures.inv_with_tools({&"shovel": 1, &"pickaxe": 2, &"axe": 0}, {&"stone": 4})
	assert_eq(inv.tools(), {&"shovel_iron": 1, &"pickaxe_master": 1} as Dictionary[StringName, int])
	assert_true(inv.tool_belt)
	assert_eq([inv.count(&"stone"), inv.count(&"shovel_iron"), inv.count(&"axe_iron")], [4, 1, 0])
	assert_true(inv.remove_item(&"shovel_iron", 1))
	assert_eq(inv.tools(), {&"pickaxe_master": 1} as Dictionary[StringName, int])
	inv.free()
	var corpse := Phase5Fixtures.corpse(72, &"drowned_millpond", &"s1_quendel")
	assert_eq([corpse.age, corpse.cause_id, corpse.story_id], [72, &"drowned_millpond", &"s1_quendel"])
	var filled := Phase5Fixtures.grave_with(corpse)
	assert_eq([filled.state, filled.marker_id, filled.design], [GraveRecord.State.FILLED, &"", {}])
	var cross := Phase5Fixtures.grave_with(corpse, &"wooden_cross")
	assert_eq([cross.state, cross.marker_id], [GraveRecord.State.MARKED, &"wooden_cross"])
	assert_eq(cross.quality, filled.quality + 1, "cross +1")
	var stone := Phase5Fixtures.grave_with(corpse, &"", Phase5Fixtures.design(&"stone_arch", &"i_water"))
	assert_eq([stone.state, stone.marker_id, stone.design.shape], [GraveRecord.State.MARKED, &"stone_arch", "stone_arch"])
	assert_eq(Phase5Fixtures.layout_p4().get("sections", []).size() > 0, true, "layout_p4.json readable")


func test_database_phase5_folders() -> void:
	# The real data folders are the owners' (P1 stations, P2 gather, P4 stone) – empty until W1.
	for list: Array in [Database.stations(), Database.gather_kinds(), Database.stone_shapes(), Database.inscriptions(), Database.ornaments()]:
		for res: Resource in list:
			assert_true(res.get("id") != &"", "keyed by id")
	assert_null(Database.station(&"nope"))
	assert_null(Database.gather_kind(&"nope"))
	assert_null(Database.stone_shape(&"nope"))
	assert_null(Database.inscription(&"nope"))
	assert_null(Database.ornament(&"nope"))
	for name: StringName in Phase5Fixtures.CONFIG_NAMES:
		assert_not_null(Database.config(name), String(name))
	var orders: Array = []
	for s: Resource in Database.stone_shapes():
		orders.append(int(s.get("order")))
	var sorted := orders.duplicate()
	sorted.sort()
	assert_eq(orders, sorted, "shapes sorted by order")


func test_save_format_v4_and_migration_chain() -> void:
	assert_eq(SaveMigration.CURRENT, 6)  # Phase 6: v5, Phase 7: v6
	assert_eq(SaveFileIO.FORMAT_VERSION, 6)
	assert_eq(SaveManager.FORMAT_VERSION, 6)
	assert_eq(SaveMigration.V4_EMPTY_NODES, PackedStringArray(["workshop", "gathering", "stonemasonry"]))
	var state := {"autoloads": {"TimeManager": {"day": 5}, "GameState": {"stats": {}, "flags": {}}}, "nodes": {"corpse_manager": {}}}
	# Phase 6 (P6): migrate_4_to_5 implemented – only the Phase-6 nodes / stats are added.
	assert_eq((SaveMigration.migrate(state, 4).nodes as Dictionary).keys(), ["corpse_manager"] + Array(SaveMigration.V5_EMPTY_NODES) + Array(SaveMigration.V6_EMPTY_NODES), "v4 → v5 → v6 (Phase 7: + V6 nodes)")
	assert_eq(SaveMigration.migrate(state, SaveMigration.CURRENT + 1), {}, "newer → corrupt")
	var v4 := SaveMigration.migrate_3_to_4(state, {"day": 5})
	assert_eq((v4.nodes as Dictionary).keys(), ["corpse_manager", "workshop", "gathering", "stonemasonry"], "P6: empty Phase-5 nodes")
	assert_false(is_same(v4, state), "deep copy")
	assert_eq(state.nodes, {"corpse_manager": {}}, "input unchanged")
	var from_v3 := SaveMigration.migrate(state, 3, {"day": 5})
	assert_true(from_v3.get("autoloads") is Dictionary and from_v3.get("nodes") is Dictionary)
	var from_v1 := SaveMigration.migrate(state, 1, {"day": 5})
	assert_true((from_v1.nodes as Dictionary).has("expansion") and (from_v1.nodes as Dictionary).has("journal"), "v1 → v2 → v3 → v4 chain")


func test_save_v3_fixtures_exist() -> void:
	for name: String in Phase5Fixtures.SAVES_V3:
		var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(Phase5Fixtures.save_v3_path(name)))
		assert_true(doc is Dictionary, name)
		if doc is Dictionary:
			assert_eq(int(doc.format_version), 3, name)


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
