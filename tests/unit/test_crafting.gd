extends TestCase
## M1: CraftingSystem – missing inputs, output fit after removal, atomic craft, recipe data (§2.3, §3.4).

const FAKE_INVENTORY := "res://tests/fixtures/fake_inventory.gd"


## Claims every output fits but refuses to store `refused` – forces a failure mid-craft.
class RefusingInventory extends Inventory:
	var refused: StringName = &""

	func can_add(_id: StringName, _amount: int) -> bool:
		return true

	func add_item(id: StringName, amount: int) -> int:
		if id == refused and amount > 0:
			return amount
		return super(id, amount)


var inv: Inventory
var changes: int = 0


func before_each() -> void:
	inv = _make(16)


func after_each() -> void:
	if is_instance_valid(inv):
		inv.free()


func _make(slots: int) -> Inventory:
	var i := Inventory.new()
	i.slot_count = slots
	i.changed.connect(_on_changed)
	return i


func _on_changed() -> void:
	changes += 1


func _recipe(id: StringName) -> RecipeData:
	var r := Database.recipe(id) as RecipeData
	assert_not_null(r, "recipe %s" % id)
	return r


## Exact slot layout ({} or [id, amount] per entry); resets the change counter.
func _set_layout(layout: Array) -> void:
	var slots: Array = []
	for e: Variant in layout:
		slots.append({} if (e as Array).is_empty() else {"id": StringName(e[0]), "amount": int(e[1])})
	inv.slot_count = layout.size()
	inv.load_state({"slots": slots, "currency": {}})
	changes = 0


func _layout() -> Array:
	var out: Array = []
	for slot: Dictionary in inv.get_slots():
		out.append([] if slot.is_empty() else [slot.id, slot.amount])
	return out


func _custom(inputs: Dictionary[StringName, int], output_id: StringName, output_amount: int = 1) -> RecipeData:
	var r := RecipeData.new()
	r.id = &"test_recipe"
	r.inputs = inputs
	r.output_id = output_id
	r.output_amount = output_amount
	return r


# --- data ----------------------------------------------------------------------------

func test_database_finds_all_recipes() -> void:
	Database.reload()
	var expected := {
		&"shroud": ["Leichentuch", {&"linen": 2}, 20],
		&"wooden_cross": ["Holzkreuz", {&"wood": 3}, 30],
		&"gravestone_simple": ["Grabstein", {&"stone": 4, &"wood": 1}, 60],
	}
	var workbench := Database.recipes(&"workbench")
	assert_eq(workbench.size(), 3)
	assert_eq(Database.recipes().size(), 3)
	for id: StringName in expected:
		var spec: Array = expected[id]
		var r := _recipe(id)
		if r == null:
			continue
		assert_eq(r.id, id)
		assert_eq(r.display_name, spec[0], "%s display_name" % id)
		assert_eq(r.inputs, spec[1], "%s inputs" % id)
		assert_eq(r.output_id, id, "%s output" % id)
		assert_eq(r.output_amount, 1)
		assert_eq(r.craft_minutes, spec[2], "%s minutes" % id)
		assert_eq(r.station, &"workbench")
		assert_true(r in workbench)
		assert_eq(r.resource_path, "res://data/recipes/%s.tres" % id, "file name = id")
		for input: StringName in r.inputs:
			assert_eq(typeof(input), TYPE_STRING_NAME)
			assert_true(Database.has_item(input), "%s input %s is a known item" % [id, input])
		assert_true(Database.has_item(r.output_id), "%s output is a known item" % id)
	assert_eq(Database.recipes(&"anvil"), [], "no recipes for other stations")


# --- missing ---------------------------------------------------------------------------

func test_missing_lists_every_shortfall() -> void:
	var stone := _recipe(&"gravestone_simple")
	assert_eq(CraftingSystem.missing(stone, inv), {&"stone": 4, &"wood": 1})
	inv.add_item(&"stone", 3)
	var m := CraftingSystem.missing(stone, inv)
	assert_eq(m, {&"stone": 1, &"wood": 1})
	assert_eq(typeof(m.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(m.values()[0]), TYPE_INT)
	inv.add_item(&"stone", 10)
	assert_eq(CraftingSystem.missing(stone, inv), {&"wood": 1}, "surplus is not listed")
	inv.add_item(&"wood", 1)
	assert_eq(CraftingSystem.missing(stone, inv), {})


func test_missing_with_start_inventory() -> void:
	inv.add_item(&"coin", 5)
	inv.add_item(&"wood", 2)
	inv.add_item(&"linen", 1)
	assert_eq(CraftingSystem.missing(_recipe(&"shroud"), inv), {&"linen": 1})
	assert_eq(CraftingSystem.missing(_recipe(&"wooden_cross"), inv), {&"wood": 1})
	assert_false(CraftingSystem.can_craft(_recipe(&"shroud"), inv))


# --- can_craft / craft success -------------------------------------------------------------

func test_can_craft_requires_all_inputs() -> void:
	var cross := _recipe(&"wooden_cross")
	inv.add_item(&"wood", 2)
	assert_false(CraftingSystem.can_craft(cross, inv))
	inv.add_item(&"wood", 1)
	assert_true(CraftingSystem.can_craft(cross, inv))


func test_craft_success() -> void:
	inv.add_item(&"wood", 5)
	changes = 0
	assert_true(CraftingSystem.craft(_recipe(&"wooden_cross"), inv))
	assert_eq(inv.count(&"wood"), 2)
	assert_eq(inv.count(&"wooden_cross"), 1)
	assert_true(changes > 0, "inventory reported the change")
	assert_false(CraftingSystem.craft(_recipe(&"wooden_cross"), inv), "only 2 wood left")
	assert_eq(inv.count(&"wood"), 2)


func test_craft_consumes_every_input() -> void:
	inv.add_item(&"stone", 4)
	inv.add_item(&"wood", 1)
	inv.add_item(&"coin", 3)
	assert_true(CraftingSystem.craft(_recipe(&"gravestone_simple"), inv))
	assert_eq(inv.count(&"stone"), 0)
	assert_eq(inv.count(&"wood"), 0)
	assert_eq(inv.count(&"coin"), 3, "unrelated items untouched")
	assert_eq(_layout()[0], [&"gravestone_simple", 1], "output takes the first freed slot")
	assert_eq(_layout()[1], [])


func test_craft_all_three_workbench_recipes() -> void:
	inv.add_item(&"linen", 2)
	inv.add_item(&"wood", 4)
	inv.add_item(&"stone", 4)
	for id: StringName in [&"shroud", &"wooden_cross", &"gravestone_simple"]:
		assert_true(CraftingSystem.craft(_recipe(id), inv), String(id))
		assert_eq(inv.count(id), 1, String(id))
	for id: StringName in [&"linen", &"wood", &"stone"]:
		assert_eq(inv.count(id), 0, String(id))


# --- failures change nothing -------------------------------------------------------------

func test_missing_inputs_change_nothing() -> void:
	inv.add_item(&"linen", 1)
	inv.add_item(&"wood", 7)
	changes = 0
	var before := inv.save_state()
	assert_false(CraftingSystem.craft(_recipe(&"shroud"), inv))
	assert_eq(inv.save_state(), before)
	assert_eq(changes, 0)


func test_output_does_not_fit_full_inventory() -> void:
	# Removing 4 stone + 1 wood frees no slot (49 wood, 46 stone remain).
	_set_layout([[&"wood", 50], [&"stone", 50]])
	var stone := _recipe(&"gravestone_simple")
	var before := inv.save_state()
	assert_eq(CraftingSystem.missing(stone, inv), {}, "all inputs are there")
	assert_false(CraftingSystem.can_craft(stone, inv), "but the output has no room")
	assert_false(CraftingSystem.craft(stone, inv))
	assert_eq(inv.save_state(), before)
	assert_eq(changes, 0)


func test_output_stack_full_does_not_fit() -> void:
	_set_layout([[&"shroud", 10], [&"linen", 20]])
	assert_false(CraftingSystem.can_craft(_recipe(&"shroud"), inv))
	assert_false(CraftingSystem.craft(_recipe(&"shroud"), inv))
	assert_eq(_layout(), [[&"shroud", 10], [&"linen", 20]])


# --- freed slots count -------------------------------------------------------------------

func test_slot_freed_by_inputs_counts_for_output() -> void:
	_set_layout([[&"linen", 2]])
	var shroud := _recipe(&"shroud")
	assert_false(inv.can_add(&"shroud", 1), "no room before the inputs are taken")
	assert_true(CraftingSystem.can_craft(shroud, inv))
	assert_true(CraftingSystem.craft(shroud, inv))
	assert_eq(_layout(), [[&"shroud", 1]])


func test_slot_freed_among_several_stacks() -> void:
	_set_layout([[&"stone", 50], [&"wood", 3]])
	assert_true(CraftingSystem.can_craft(_recipe(&"wooden_cross"), inv))
	assert_true(CraftingSystem.craft(_recipe(&"wooden_cross"), inv))
	assert_eq(_layout(), [[&"stone", 50], [&"wooden_cross", 1]])


func test_output_joins_existing_stack() -> void:
	_set_layout([[&"shroud", 9], [&"linen", 20]])
	assert_true(CraftingSystem.craft(_recipe(&"shroud"), inv))
	assert_eq(_layout(), [[&"shroud", 10], [&"linen", 18]])


func test_output_that_is_also_an_input() -> void:
	_set_layout([[&"wood", 50]])
	var whittle := _custom({&"wood": 50}, &"wood", 1)
	assert_false(inv.can_add(&"wood", 1))
	assert_true(CraftingSystem.can_craft(whittle, inv))
	assert_true(CraftingSystem.craft(whittle, inv))
	assert_eq(_layout(), [[&"wood", 1]])


func test_can_craft_never_touches_the_inventory() -> void:
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	# Both layouts force the simulated-removal path (no direct room for the output).
	for setup: Array in [[[[&"linen", 2]], &"shroud", true], [[[&"wood", 50], [&"stone", 50]], &"gravestone_simple", false]]:
		_set_layout(setup[0])
		var before := inv.save_state()
		assert_eq(CraftingSystem.can_craft(_recipe(setup[1]), inv), setup[2], String(setup[1]))
		assert_eq(inv.save_state(), before)
		assert_eq(changes, 0, "no changed signal from a query")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes_before, "simulation copy is freed")


# --- atomicity & doubles ---------------------------------------------------------------------

func test_craft_is_atomic_when_output_is_refused() -> void:
	var refusing := RefusingInventory.new()
	refusing.refused = &"wooden_cross"
	refusing.add_item(&"wood", 3)
	refusing.add_item(&"coin", 2)
	var before := refusing.save_state()
	assert_true(CraftingSystem.can_craft(_recipe(&"wooden_cross"), refusing), "the double claims room")
	assert_false(CraftingSystem.craft(_recipe(&"wooden_cross"), refusing))
	assert_eq(refusing.save_state(), before, "inputs restored")
	assert_eq(refusing.count(&"wood"), 3)
	assert_eq(refusing.count(&"wooden_cross"), 0)
	refusing.free()


func test_craft_with_fake_inventory_double() -> void:
	var fake: Inventory = load(FAKE_INVENTORY).new()
	fake.add_item(&"stone", 9)
	fake.add_item(&"wood", 1)
	assert_true(CraftingSystem.can_craft(_recipe(&"gravestone_simple"), fake))
	assert_true(CraftingSystem.craft(_recipe(&"gravestone_simple"), fake))
	assert_eq(fake.count(&"stone"), 5)
	assert_eq(fake.count(&"wood"), 0)
	assert_eq(fake.count(&"gravestone_simple"), 1)
	assert_eq(CraftingSystem.missing(_recipe(&"gravestone_simple"), fake), {&"wood": 1})
	fake.free()


# --- custom & invalid recipes --------------------------------------------------------------------

func test_multi_output_and_zero_inputs() -> void:
	var split := _custom({&"wood": 0, &"stone": 1}, &"linen", 3)
	assert_eq(CraftingSystem.missing(split, inv), {&"stone": 1}, "zero-amount inputs are ignored")
	inv.add_item(&"stone", 1)
	assert_true(CraftingSystem.craft(split, inv))
	assert_eq(inv.count(&"linen"), 3)
	assert_eq(inv.count(&"stone"), 0)


func test_currency_output_always_fits() -> void:
	_set_layout([[&"stone", 50]])
	var sell := _custom({&"stone": 1}, &"coin", 2)
	assert_true(CraftingSystem.craft(sell, inv))
	assert_eq(inv.count(&"coin"), 2)
	assert_eq(_layout(), [[&"stone", 49]])


func test_unknown_output_is_not_craftable() -> void:
	inv.add_item(&"wood", 3)
	var bad := _custom({&"wood": 1}, &"banana")
	assert_false(CraftingSystem.can_craft(bad, inv))
	assert_false(CraftingSystem.craft(bad, inv))
	assert_eq(inv.count(&"wood"), 3)


func test_invalid_arguments_are_refused() -> void:
	inv.add_item(&"wood", 3)
	assert_eq(CraftingSystem.missing(null, inv), {})
	assert_false(CraftingSystem.can_craft(null, inv))
	assert_false(CraftingSystem.craft(null, inv))
	assert_eq(CraftingSystem.missing(_recipe(&"wooden_cross"), null), {})
	assert_false(CraftingSystem.can_craft(_recipe(&"wooden_cross"), null))
	assert_false(CraftingSystem.craft(_recipe(&"wooden_cross"), null))
	for bad: RecipeData in [_custom({&"wood": 1}, &""), _custom({&"wood": 1}, &"stone", 0)]:
		assert_false(CraftingSystem.can_craft(bad, inv))
		assert_false(CraftingSystem.craft(bad, inv))
	assert_eq(inv.count(&"wood"), 3)
