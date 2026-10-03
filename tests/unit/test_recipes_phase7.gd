extends TestCase
## P7 (docs/PHASE7_DESIGN.md §2.7, §2.8, §3.4, §10): the herb recipes of the pult (fever tincture, wound
## salve, corpse balm – also without anatomy), crafted with the Phase-5 CraftingSystem; the corpse balm
## smokes like juniper (PrepConfig.balm_items third entry, × 0.25, 18 h window, juniper stays first);
## the 17 Phase-7 items in data == tests/fixtures/items.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")

var inv: Inventory


func before_each() -> void:
	inv = FakeInventory.new()


func after_each() -> void:
	inv.free()


func test_pult_recipes_match_the_contract() -> void:
	var expect := {  # §2.7: inputs, minutes, amount
		&"fever_tincture": [{&"herbs": 2, &"elderberries": 1, &"spirits": 1}, 30, 1],
		&"wound_salve": [{&"herb_bundle": 1, &"beeswax": 1}, 20, 2],
		&"corpse_balm": [{&"herbs": 2, &"beeswax": 1}, 20, 1],
	}
	var at_pult := Database.recipes(&"pult")
	assert_eq(at_pult.size(), 3, "only the herb recipes – the medicines run through the pult panel")
	for id: StringName in expect:
		var r := Database.recipe(id) as RecipeData
		assert_not_null(r, String(id))
		if r == null:
			continue
		var e: Array = expect[id]
		assert_eq([r.inputs, r.craft_minutes, r.output_amount, r.output_id, r.station, r.background], [e[0], e[1], e[2], id, &"pult", false],
				String(id))
		var f := Phase7Fixtures.recipe(id)
		assert_eq([r.display_name, r.category], [f.display_name, f.category], String(id))
		assert_eq(r.resource_path, "res://data/recipes/%s.tres" % id)


func test_craft_with_the_crafting_system() -> void:
	var tincture := Database.recipe(&"fever_tincture") as RecipeData
	inv.add_item(&"herbs", 2)
	inv.add_item(&"elderberries", 1)
	assert_false(CraftingSystem.can_craft(tincture, inv), "spirits missing")
	assert_eq(CraftingSystem.missing(tincture, inv), {&"spirits": 1})
	inv.add_item(&"spirits", 1)
	assert_true(CraftingSystem.craft(tincture, inv))
	assert_eq([inv.count(&"fever_tincture"), inv.count(&"herbs"), inv.count(&"spirits")], [1, 0, 0])
	var salve := Database.recipe(&"wound_salve") as RecipeData
	inv.add_item(&"herb_bundle", 1)
	inv.add_item(&"beeswax", 1)
	assert_true(CraftingSystem.craft(salve, inv))
	assert_eq(inv.count(&"wound_salve"), 2)
	var balm := Database.recipe(&"corpse_balm") as RecipeData
	inv.add_item(&"herbs", 2)
	inv.add_item(&"beeswax", 1)
	assert_true(CraftingSystem.craft(balm, inv))
	assert_eq(inv.count(&"corpse_balm"), 1)


func test_corpse_balm_smokes_like_juniper() -> void:
	var prep := Database.config(&"prep_config") as PrepConfig
	assert_eq(prep.balm_items, [&"juniper", &"herb_bundle", &"corpse_balm"] as Array[StringName], "data")
	assert_eq(PrepConfig.new().balm_items, prep.balm_items, "class default = data (W0-Notizen 4)")
	assert_eq(Phase7Fixtures.prep_config().balm_items, prep.balm_items, "= fixture")
	assert_eq([prep.balm_items[0], prep.balm_item], [&"juniper", &"juniper"], "juniper stays first")
	assert_almost(prep.balm_factor, 0.25)
	assert_eq(prep.balm_window_minutes, 1080, "18 h")
	var r := Phase4Fixtures.corpse([], &"fever", 1.0)
	r.location = CorpseRecord.LOCATION_TABLE
	assert_eq(CorpsePrep.balm_item_in(inv, prep), &"")
	inv.add_item(&"corpse_balm", 1)
	assert_eq(CorpsePrep.balm_item_in(inv, prep), &"corpse_balm")
	assert_eq(CorpsePrep.block_reason(r, &"balm", inv, prep), "")
	inv.add_item(&"juniper", 1)
	assert_eq(CorpsePrep.balm_item_in(inv, prep), &"juniper", "list order: juniper first")
	assert_eq(CorpsePrep.balm_item_in(inv, Phase5Fixtures.prep_config()), &"juniper", "Phase-5 fixture unchanged")
	inv.remove_item(&"juniper", 1)
	assert_eq(CorpsePrep.balm_item_in(inv, Phase5Fixtures.prep_config()), &"", "Phase 5 knows no corpse balm")


func test_phase7_items_in_data_match_the_fixtures() -> void:
	assert_eq(Phase7Fixtures.ITEM_IDS.size(), 17)
	for id: StringName in Phase7Fixtures.ITEM_IDS:
		var real := Database.item(id) as ItemData
		assert_not_null(real, String(id))
		if real == null:
			continue
		var f := Phase7Fixtures.item(id)
		assert_eq([real.display_name, real.category, real.max_stack, real.unique, real.tool_kind],
				[f.display_name, f.category, f.max_stack, f.unique, f.tool_kind], String(id))
		assert_true(real.description.length() >= 20, "%s description" % id)
		assert_eq(real.unique, Phase7Fixtures.UNIQUE_ITEMS.has(id), "%s unique" % id)
	for id: StringName in Phase7Fixtures.UNIQUE_ITEMS:
		assert_eq((Database.item(id) as ItemData).max_stack, 1, String(id))
