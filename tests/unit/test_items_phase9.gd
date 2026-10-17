extends TestCase
## P3 (docs/PHASE9_DESIGN.md §2.9, §10): the seven Phase-9 items in data/items – names, categories, stacks, unique
## letters (the uid is the letter), the case that takes one slot, and the mirror of tests/fixtures/items.

const SPEC := {
	&"letter": ["Brief", ItemData.Category.GOODS, 1, true],
	&"letter_reply": ["Antwort", ItemData.Category.GOODS, 1, true],
	&"nameless_letter": ["Brief ohne Namen", ItemData.Category.GOODS, 1, false],
	&"stranger_case": ["Ein Lederkoffer", ItemData.Category.GOODS, 1, false],
	&"case_card": ["Visitenkarte „C. Brenneisen, Commissionär“", ItemData.Category.GOODS, 1, false],
	&"soil_pouch": ["Eine Handvoll Grabeserde", ItemData.Category.GOODS, 3, false],
	&"straw_bouquet": ["Strohblumen-Strauß", ItemData.Category.MATERIAL, 3, false],
}


func test_items_exist_with_the_contract_values() -> void:
	assert_eq(SPEC.keys(), Phase9Fixtures.ITEM_IDS as Array, "the 7 items of §2.9")
	for id: StringName in SPEC:
		var item := Database.item(id) as ItemData
		assert_not_null(item, String(id))
		if item == null:
			continue
		var spec: Array = SPEC[id]
		assert_eq([item.display_name, item.category, item.max_stack, item.unique], spec, String(id))
		assert_eq(item.resource_path, "res://data/items/%s.tres" % id)
		assert_true(item.description.length() >= 20, "%s: a description" % id)
		var fixture := Phase9Fixtures.item(id)
		assert_eq([fixture.display_name, fixture.category, fixture.max_stack, fixture.unique], spec, "%s mirrors the fixture" % id)


func test_letters_are_unique_pieces() -> void:
	var inv := Inventory.new()
	assert_true(inv.add_unique(&"letter", "lt_0001"))
	assert_true(inv.add_unique(&"letter", "lt_0002"))
	assert_false(inv.add_unique(&"letter", "lt_0001"), "a uid only once")
	assert_eq(inv.uids(&"letter"), PackedStringArray(["lt_0001", "lt_0002"]))
	assert_eq(inv.count(&"letter"), 2)
	assert_true(inv.add_unique(&"letter_reply", "lt_0003"))
	assert_eq(inv.uid_item("lt_0003"), &"letter_reply")
	assert_true(inv.remove_uid("lt_0001"))
	assert_false(inv.has_uid("lt_0001"))
	var saved := inv.save_state()
	var other := Inventory.new()
	other.load_state(saved)
	assert_eq(other.uids(&"letter"), PackedStringArray(["lt_0002"]), "the uid survives a load")
	assert_eq(inv.add_item(&"soil_pouch", 4), 0, "3 to a slot, a second slot")
	assert_eq(inv.add_item(&"stranger_case", 1), 0)
	assert_eq(inv.count(&"stranger_case"), 1)
	inv.free()
	other.free()
