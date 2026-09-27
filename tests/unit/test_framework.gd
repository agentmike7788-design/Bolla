extends TestCase
## Self-test of the test framework (Lead).


func test_deep_equality() -> void:
	assert_eq({"a": [1, &"x", {"b": 2.0}]}, {"a": [1.0, "x", {"b": 2}]})
	assert_ne({"a": 1}, {"a": 1, "b": 2})
	assert_ne([1, 2], [2, 1])


func test_expected_engine_error_is_allowed() -> void:
	expect_errors(1)
	push_error("deliberate error for the framework self-test")


func test_async_method() -> void:
	await wait_frames(2)
	assert_true(true)


func test_fixtures_load() -> void:
	for id: String in ["coin", "wood", "stone", "linen", "shroud", "wooden_cross", "gravestone_simple"]:
		var item := load("res://tests/fixtures/items/%s.tres" % id) as ItemData
		assert_not_null(item, id)
		assert_eq(item.id, StringName(id))
	var tables := load("res://tests/fixtures/corpse_tables_fixture.tres") as CorpseTables
	assert_eq(tables.causes.size(), 2)
	assert_eq(tables.get_cause(&"drowned").get("base_payment"), 4)
	assert_eq(tables.forced_traits_by_day[2], PackedStringArray(["valuables"]))
	var econ := load("res://tests/fixtures/economy_config_fixture.tres") as EconomyConfig
	assert_eq(econ.marker_quality[&"gravestone_simple"], 3)
	var inv: Inventory = load("res://tests/fixtures/fake_inventory.gd").new()
	inv.add_item(&"wood", 3)
	assert_true(inv.remove_item(&"wood", 2))
	assert_eq(inv.count(&"wood"), 1)
	inv.free()


func test_ui_state_stack() -> void:
	var ui := tree.root.get_node("UIState")
	var events: Array[bool] = []
	var cb := func(open: bool) -> void: events.append(open)
	EventBus.ui_modal_changed.connect(cb)
	ui.push_modal(&"a")
	ui.push_modal(&"b")
	ui.pop_modal(&"a")
	assert_true(ui.is_modal())
	assert_eq(ui.top(), &"b")
	ui.pop_modal(&"b")
	assert_false(ui.is_modal())
	EventBus.ui_modal_changed.disconnect(cb)
	assert_eq(events, [true, false])
