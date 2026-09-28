extends TestCase
## P3 (docs/PHASE5_DESIGN.md §2.3, §3.4, §10): tool tiers – ActionConfig.tool_minutes against the
## §2.3 table, ToolRules.tier / block_reason / tool_name / action_minutes on the real belt and the
## Phase-5 fixture belt, the six tier tool items and the five forge recipes (upgrades consume the
## lower tool, the new tool goes onto the belt).

const TOOL_IDS := {
	&"shovel": [&"", &"shovel_iron", &"shovel_master"],
	&"axe": [&"", &"axe_iron", &"axe_master"],
	&"pickaxe": [&"", &"pickaxe_iron", &"pickaxe_master"],
}
const RECIPES: Array[StringName] = [&"shovel_iron", &"axe_iron", &"shovel_master", &"axe_master", &"pickaxe_master"]

var inv: Inventory
var cfg: ToolConfig


func before_each() -> void:
	inv = Inventory.new()
	inv.slot_count = 20
	inv.tool_belt = true
	cfg = Database.config(&"tool_config") as ToolConfig


func after_each() -> void:
	if is_instance_valid(inv):
		inv.free()


# --- minutes (§1.3, §2.3) ---------------------------------------------------------------------

func test_tool_minutes_match_the_table_exactly() -> void:
	# base: [tier 0, tier 1, tier 2] – rows of §2.3 (dig, bury, alder, boulder/stump/hedge, rubble
	# heap, ore, workstone, rubble face, clay).
	var table := {60: [60, 50, 35], 30: [30, 25, 20], 40: [40, 30, 25], 45: [45, 35, 25], 20: [20, 15, 10], 10: [10, 10, 5]}
	var real := Database.config(&"action_config") as ActionConfig
	for actions: ActionConfig in [real, Phase5Fixtures.action_config()]:
		for base: int in table:
			for tier: int in 3:
				assert_eq(actions.tool_minutes(base, tier), table[base][tier], "%d min at tier %d" % [base, tier])


func test_real_action_config_has_the_phase5_values() -> void:
	var real := Database.config(&"action_config") as ActionConfig
	var fixture := Phase5Fixtures.action_config()
	assert_eq(Array(real.tool_tier_factors), Array(fixture.tool_tier_factors))
	assert_eq(real.action_tools, fixture.action_tools)
	assert_eq(real.tool_minute_step, fixture.tool_minute_step)
	assert_eq([real.dig_minutes, real.bury_minutes, real.gather_minutes], [60, 30, 10])


func test_action_minutes_follow_the_shovel() -> void:
	var actions := Database.config(&"action_config") as ActionConfig
	assert_eq([ToolRules.action_minutes(actions, &"dig", 60, inv), ToolRules.action_minutes(actions, &"bury", 30, inv)], [60, 30])
	inv.add_item(&"shovel_iron", 1)
	assert_eq([ToolRules.action_minutes(actions, &"dig", 60, inv), ToolRules.action_minutes(actions, &"bury", 30, inv)], [50, 25])
	inv.add_item(&"shovel_master", 1)
	assert_eq([ToolRules.action_minutes(actions, &"dig", 60, inv), ToolRules.action_minutes(actions, &"bury", 30, inv)], [35, 20])
	assert_eq(ToolRules.action_minutes(actions, &"gather", 10, inv), 10, "no tool for the wood/stone piles")
	assert_eq(ToolRules.action_minutes(actions, &"dig", 7, null), 7, "tier 0 keeps the base")
	assert_eq(ToolRules.action_minutes(null, &"dig", 60, inv), 60)


# --- ToolRules --------------------------------------------------------------------------------

func test_tier_is_the_best_tool_of_a_kind_on_the_belt() -> void:
	assert_eq(ToolRules.tier(null, &"shovel"), 0)
	assert_eq(ToolRules.tier(inv, &"shovel"), 0, "old shovel = tier 0, no item")
	inv.add_item(&"rake", 1)
	inv.add_item(&"axe_master", 1)
	assert_eq([ToolRules.tier(inv, &"shovel"), ToolRules.tier(inv, &"axe"), ToolRules.tier(inv, &"pickaxe")], [0, 2, 0])
	inv.add_item(&"axe_iron", 1)
	assert_eq(ToolRules.tier(inv, &"axe"), 2, "the highest tier counts, no equipping")
	inv.add_item(&"pickaxe_iron", 1)
	assert_eq(ToolRules.tier(inv, &"pickaxe"), 1)
	assert_true(inv.remove_item(&"axe_master", 1))
	assert_eq(ToolRules.tier(inv, &"axe"), 1)
	assert_eq(ToolRules.tier(inv, &""), 0, "no kind")


func test_tier_on_the_fixture_belt() -> void:
	var fake := Phase5Fixtures.inv_with_tools({&"shovel": 1, &"axe": 0, &"pickaxe": 2})
	assert_eq([ToolRules.tier(fake, &"shovel"), ToolRules.tier(fake, &"axe"), ToolRules.tier(fake, &"pickaxe")], [1, 0, 2])
	fake.free()


func test_tools_in_slots_do_not_count() -> void:
	var chest := Inventory.new()   # no belt: a tool is an ordinary slot item there
	chest.add_item(&"shovel_master", 1)
	assert_eq(chest.count(&"shovel_master"), 1)
	assert_eq(ToolRules.tier(chest, &"shovel"), 0, "only the belt counts")
	chest.free()


func test_block_reason_texts() -> void:
	assert_eq(ToolRules.block_reason(inv, &"axe", 1, cfg), "Holzfälleraxt nötig – Esse")
	assert_eq(ToolRules.block_reason(inv, &"pickaxe", 1, cfg), "Alte Spitzhacke nötig – Osric")
	assert_eq(ToolRules.block_reason(inv, &"pickaxe", 2, cfg), "Meisterhacke nötig")
	assert_eq(ToolRules.block_reason(inv, &"shovel", 0, cfg), "", "tier 0 is always there")
	assert_eq(ToolRules.block_reason(inv, &"", 1, cfg), "", "no tool needed")
	inv.add_item(&"pickaxe_iron", 1)
	assert_eq(ToolRules.block_reason(inv, &"pickaxe", 1, cfg), "")
	assert_eq(ToolRules.block_reason(inv, &"pickaxe", 2, cfg), "Meisterhacke nötig")
	inv.add_item(&"pickaxe_master", 1)
	assert_eq(ToolRules.block_reason(inv, &"pickaxe", 2, cfg), "")
	assert_eq(ToolRules.block_reason(null, &"axe", 1, cfg), "Holzfälleraxt nötig – Esse", "no inventory = no tool")


func test_tool_names() -> void:
	assert_eq(ToolRules.tool_name(&"shovel", 0, cfg), "Alte Schaufel")
	assert_eq(ToolRules.tool_name(&"axe", 0, cfg), "Altes Beil")
	assert_eq(ToolRules.tool_name(&"pickaxe", 0, cfg), "", "no tier-0 pickaxe")
	assert_eq(ToolRules.tool_name(&"shovel", 1, cfg), "Eisenschaufel")
	assert_eq(ToolRules.tool_name(&"axe", 1, cfg), "Holzfälleraxt")
	assert_eq(ToolRules.tool_name(&"pickaxe", 1, cfg), "Alte Spitzhacke")
	assert_eq(ToolRules.tool_name(&"shovel", 2, cfg), "Meisterschaufel")
	assert_eq(ToolRules.tool_name(&"axe", 2, cfg), "Meisteraxt")
	assert_eq(ToolRules.tool_name(&"pickaxe", 2, cfg), "Meisterhacke")
	assert_eq(ToolRules.tool_name(&"pickaxe", 3, cfg), "")


func test_tool_config_data_matches_fixture_and_defaults() -> void:
	var fixture := Phase5Fixtures.tool_config()
	var defaults := ToolConfig.new()
	for c: ToolConfig in [fixture, defaults]:
		assert_eq(cfg.kinds, c.kinds)
		assert_eq(cfg.labels, c.labels)
		assert_eq(cfg.base_names, c.base_names)
		assert_eq(cfg.source_hint, c.source_hint)


# --- items & recipes (§2.3, §2.4) -------------------------------------------------------------

func test_tier_tool_items_in_data() -> void:
	for kind: StringName in TOOL_IDS:
		var ids: Array = TOOL_IDS[kind]
		for tier: int in [1, 2]:
			var item := Database.item(ids[tier]) as ItemData
			assert_not_null(item, String(ids[tier]))
			if item == null:
				continue
			assert_eq([item.category, item.max_stack, item.tool_kind, item.tool_tier], [ItemData.Category.TOOL, 1, kind, tier], String(ids[tier]))
			var fixture := Phase5Fixtures.item(ids[tier])
			assert_eq([item.display_name, item.tool_kind, item.tool_tier], [fixture.display_name, fixture.tool_kind, fixture.tool_tier])
	for id: StringName in [&"rake", &"scrub_brush", &"comb", &"shears", &"pliers"]:
		assert_eq((Database.item(id) as ItemData).tool_kind, &"", "%s has no tiers" % id)


func test_forge_tool_recipes_in_data() -> void:
	for id: StringName in RECIPES:
		var r := Database.recipe(id) as RecipeData
		var f := Phase5Fixtures.recipe(id)
		assert_not_null(r, String(id))
		if r == null:
			continue
		assert_eq(r.resource_path, "res://data/recipes/%s.tres" % id)
		assert_eq([r.display_name, r.inputs, r.output_id, r.output_amount, r.craft_minutes, r.station, r.category, r.background],
				[f.display_name, f.inputs, f.output_id, f.output_amount, f.craft_minutes, f.station, f.category, f.background], String(id))
		assert_eq([r.station, r.category, r.output_id], [&"forge", &"tool", id])
		assert_true(Database.has_item(r.output_id), "%s output is a data item" % id)
	# §2.3: upgrades consume the lower tool.
	assert_eq((Database.recipe(&"shovel_master") as RecipeData).inputs.get(&"shovel_iron"), 1)
	assert_eq((Database.recipe(&"axe_master") as RecipeData).inputs.get(&"axe_iron"), 1)
	assert_eq((Database.recipe(&"pickaxe_master") as RecipeData).inputs.get(&"pickaxe_iron"), 1)
	assert_true(Database.recipes(&"forge").size() >= RECIPES.size())


func test_crafted_tool_goes_onto_the_belt() -> void:
	inv.add_item(&"iron_fittings", 2)
	inv.add_item(&"wood", 1)
	var recipe := Database.recipe(&"shovel_iron") as RecipeData
	assert_true(CraftingSystem.can_craft(recipe, inv))
	assert_true(CraftingSystem.craft(recipe, inv))
	assert_eq(inv.tools(), {&"shovel_iron": 1} as Dictionary[StringName, int])
	assert_eq(_used_slots(), 0, "no slot used by the tool")
	assert_eq(ToolRules.tier(inv, &"shovel"), 1)
	inv.add_item(&"iron_fittings", 2)
	inv.add_item(&"wood", 1)
	assert_false(CraftingSystem.can_craft(recipe, inv), "a second copy does not fit on the belt")


func test_upgrade_consumes_the_lower_tool_from_the_belt() -> void:
	# Stand-in upgrade with data items only (iron_bar / charcoal / steel_rod are P2's items).
	var up := RecipeData.new()
	up.id = &"shovel_master"
	up.inputs = {&"shovel_iron": 1, &"wood": 2}
	up.output_id = &"shovel_master"
	up.output_amount = 1
	up.station = &"forge"
	up.category = &"tool"
	inv.add_item(&"shovel_iron", 1)
	inv.add_item(&"wood", 2)
	assert_eq(CraftingSystem.missing(up, inv), {}, "the belt tool counts as an input")
	assert_true(CraftingSystem.craft(up, inv))
	assert_eq(inv.tools(), {&"shovel_master": 1} as Dictionary[StringName, int], "one tool per kind stays on the belt")
	assert_eq(ToolRules.tier(inv, &"shovel"), 2)
	assert_eq(inv.count(&"wood"), 0)


func _used_slots() -> int:
	var n := 0
	for slot: Dictionary in inv.get_slots():
		if not slot.is_empty():
			n += 1
	return n
