extends TestCase
## M1: Inventory – stacking, currency, all-or-nothing removal, signals, save/load, item data (§2.2, §3.4).

## Contract table §2.2: id -> [display_name, category, max_stack (ignored for CURRENCY)].
const ITEMS := {
	&"coin": ["Münze", ItemData.Category.CURRENCY, -1],
	&"wood": ["Holz", ItemData.Category.RESOURCE, 50],
	&"stone": ["Stein", ItemData.Category.RESOURCE, 50],
	&"linen": ["Leinen", ItemData.Category.RESOURCE, 20],
	&"shroud": ["Leichentuch", ItemData.Category.CRAFTED, 10],
	&"wooden_cross": ["Holzkreuz", ItemData.Category.CRAFTED, 5],
	&"gravestone_simple": ["Grabstein", ItemData.Category.CRAFTED, 5],
	&"rake": ["Rechen", ItemData.Category.TOOL, 1],
	# Phase 3 decor (P2, §2.2)
	&"decor_bench_wood": ["Holzbank", ItemData.Category.DECOR, 5],
	&"decor_bench_stone": ["Steinbank", ItemData.Category.DECOR, 5],
	&"decor_flowerbed": ["Blumenbeet", ItemData.Category.DECOR, 5],
	&"decor_grave_vase": ["Grabvase", ItemData.Category.DECOR, 10],
	&"decor_lantern": ["Grablaterne", ItemData.Category.DECOR, 6],
	&"decor_path_gravel": ["Kiesplatte", ItemData.Category.DECOR, 40],
	&"iron_fittings": ["Eisenbeschlag", ItemData.Category.RESOURCE, 20],   # Phase 3 (P6)
	&"seeds": ["Blumensamen", ItemData.Category.RESOURCE, 20],   # Phase 3 (P6)
	# Phase 4 (P2, §2.13)
	&"scrub_brush": ["Wurzelbürste", ItemData.Category.TOOL, 1],
	&"comb": ["Holzkamm", ItemData.Category.TOOL, 1],
	&"burial_gown": ["Totenhemd", ItemData.Category.CRAFTED, 5],
	&"juniper": ["Wacholderzweige", ItemData.Category.RESOURCE, 10],
	&"shears": ["Schere", ItemData.Category.TOOL, 1],
	&"pliers": ["Zange", ItemData.Category.TOOL, 1],
	&"hair_braid": ["Zopf", ItemData.Category.GOODS, 10],
	&"teeth_pouch": ["Zahnsäckchen", ItemData.Category.GOODS, 10],
	# Phase 5 (P3, §2.3): tier tools
	&"shovel_iron": ["Eisenschaufel", ItemData.Category.TOOL, 1],
	&"shovel_master": ["Meisterschaufel", ItemData.Category.TOOL, 1],
	&"axe_iron": ["Holzfälleraxt", ItemData.Category.TOOL, 1],
	&"axe_master": ["Meisteraxt", ItemData.Category.TOOL, 1],
	&"pickaxe_iron": ["Alte Spitzhacke", ItemData.Category.TOOL, 1],
	&"pickaxe_master": ["Meisterhacke", ItemData.Category.TOOL, 1],
}


## Records push_warning() messages so tests can assert on them (warnings never fail a test).
class WarningLog extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		messages.append(code + " " + rationale)
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count_containing(text: String) -> int:
		_mutex.lock()
		var n := 0
		for m: String in messages:
			if m.contains(text):
				n += 1
		_mutex.unlock()
		return n


var inv: Inventory
var changes: int = 0
var warnings: WarningLog


func before_each() -> void:
	warnings = WarningLog.new()
	OS.add_logger(warnings)
	inv = _make(16)


func after_each() -> void:
	OS.remove_logger(warnings)
	if is_instance_valid(inv):
		inv.free()


# --- helpers ---------------------------------------------------------------

func _make(slots: int) -> Inventory:
	var i := Inventory.new()
	i.slot_count = slots
	i.changed.connect(_on_changed)
	return i


func _on_changed() -> void:
	changes += 1


func _use_slots(slots: int) -> void:
	inv.slot_count = slots
	changes = 0


## Sets an exact slot layout (entries are {} or [id, amount]) and resets the change counter.
func _set_layout(layout: Array, coins: int = 0) -> void:
	var slots: Array = []
	for e: Variant in layout:
		slots.append({} if (e as Array).is_empty() else {"id": StringName(e[0]), "amount": int(e[1])})
	inv.slot_count = layout.size()
	inv.load_state({"slots": slots, "currency": {&"coin": coins} if coins > 0 else {}})
	changes = 0


## Current layout in the same short form as _set_layout: [] or [id, amount] per slot.
func _layout() -> Array:
	var out: Array = []
	for slot: Dictionary in inv.get_slots():
		out.append([] if slot.is_empty() else [slot.id, slot.amount])
	return out


func _json_round_trip(state: Dictionary) -> Dictionary:
	var text := JSON.stringify(JSON.from_native(state))
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "save text parses")
	return JSON.to_native(json.data)


# --- empty state & layout ----------------------------------------------------

func test_new_inventory_has_slot_count_empty_slots() -> void:
	assert_eq(inv.slot_count, 16, "contract default")
	var fresh := Inventory.new()
	assert_eq(fresh.get_slots().size(), 16, "default slots exist before any setter call")
	fresh.free()
	var slots := inv.get_slots()
	assert_eq(slots.size(), 16)
	for slot: Dictionary in slots:
		assert_eq(slot, {})
	assert_eq(inv.count(&"wood"), 0)
	assert_false(inv.has(&"wood"))
	assert_true(inv.has(&"wood", 0), "having zero of something is always true")


func test_get_slots_entries_are_typed() -> void:
	inv.add_item(&"wood", 7)
	var slot: Dictionary = inv.get_slots()[0]
	assert_eq(slot.keys().size(), 2)
	assert_eq(typeof(slot.id), TYPE_STRING_NAME)
	assert_eq(typeof(slot.amount), TYPE_INT)
	assert_eq(slot, {"id": &"wood", "amount": 7})


func test_get_slots_returns_copies() -> void:
	inv.add_item(&"wood", 3)
	var slots := inv.get_slots()
	slots[0]["amount"] = 99
	slots[1] = {"id": &"stone", "amount": 1}
	slots.clear()
	assert_eq(inv.get_slots()[0], {"id": &"wood", "amount": 3})
	assert_eq(inv.get_slots()[1], {})
	assert_eq(inv.count(&"stone"), 0)


# --- adding & stacking -------------------------------------------------------

func test_stacking_across_slots() -> void:
	_use_slots(4)
	assert_eq(inv.add_item(&"wood", 120), 0)
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 50], [&"wood", 20], []])
	assert_eq(inv.add_item(&"wood", 35), 0)
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 50], [&"wood", 50], [&"wood", 5]])
	assert_eq(inv.count(&"wood"), 155)
	assert_eq(changes, 2)


func test_existing_stacks_are_filled_before_empty_slots() -> void:
	_set_layout([[], [&"wood", 40], [&"stone", 3], [&"wood", 45]])
	assert_eq(inv.add_item(&"wood", 20), 0)
	assert_eq(_layout(), [[&"wood", 5], [&"wood", 50], [&"stone", 3], [&"wood", 50]],
			"stacks at 1 and 3 topped up first, the rest goes to the first empty slot")
	assert_eq(changes, 1)


func test_new_items_take_empty_slots_in_index_order() -> void:
	_set_layout([[&"wood", 1], [], [&"stone", 1], [], []])
	inv.add_item(&"linen", 3)
	inv.add_item(&"shroud", 1)
	assert_eq(_layout(), [[&"wood", 1], [&"linen", 3], [&"stone", 1], [&"shroud", 1], []])


func test_max_stack_comes_from_item_data() -> void:
	_use_slots(4)
	assert_eq(inv.add_item(&"shroud", 12), 0)
	assert_eq(inv.add_item(&"wooden_cross", 11), 1, "4 slots: shroud 10+2, cross 5+5 → 1 left")
	assert_eq(_layout(), [[&"shroud", 10], [&"shroud", 2], [&"wooden_cross", 5], [&"wooden_cross", 5]])


func test_full_inventory_returns_remainder() -> void:
	_use_slots(2)
	assert_eq(inv.add_item(&"wood", 120), 20, "only 2 × 50 fit")
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 50]])
	assert_eq(changes, 1, "a partial add is a mutation")
	assert_eq(inv.add_item(&"stone", 5), 5, "no slot left")
	assert_eq(inv.add_item(&"wood", 1), 1, "stacks are full")
	assert_eq(inv.count(&"stone"), 0)
	assert_eq(changes, 1, "refused adds do not emit")


func test_partial_fit_into_last_stack() -> void:
	_use_slots(1)
	assert_eq(inv.add_item(&"linen", 15), 0)
	assert_eq(inv.add_item(&"linen", 10), 5)
	assert_eq(_layout(), [[&"linen", 20]])


func test_zero_slots_hold_nothing_but_currency() -> void:
	_use_slots(0)
	assert_eq(inv.get_slots().size(), 0)
	assert_eq(inv.add_item(&"wood", 3), 3)
	assert_false(inv.can_add(&"wood", 1))
	assert_eq(inv.add_item(&"coin", 3), 0)
	assert_eq(inv.count(&"coin"), 3)


# --- currency ------------------------------------------------------------------

func test_currency_has_no_slot() -> void:
	assert_eq(inv.add_item(&"coin", 5), 0)
	assert_eq(inv.count(&"coin"), 5)
	assert_true(inv.has(&"coin", 5))
	assert_false(inv.has(&"coin", 6))
	var slots := inv.get_slots()
	assert_eq(slots.size(), 16)
	for slot: Dictionary in slots:
		assert_eq(slot, {}, "coins never occupy a slot")
	assert_eq(changes, 1)


func test_currency_ignores_full_slots_and_stack_limit() -> void:
	_use_slots(1)
	inv.add_item(&"wood", 50)
	assert_true(inv.can_add(&"coin", 1_000_000))
	assert_eq(inv.add_item(&"coin", 20000), 0, "no stack limit (above the ignored max_stack)")
	assert_eq(inv.add_item(&"coin", 1), 0)
	assert_eq(inv.count(&"coin"), 20001)
	assert_eq(_layout(), [[&"wood", 50]])


func test_remove_currency() -> void:
	inv.add_item(&"coin", 9)
	changes = 0
	assert_false(inv.remove_item(&"coin", 10))
	assert_eq(inv.count(&"coin"), 9)
	assert_true(inv.remove_item(&"coin", 4))
	assert_eq(inv.count(&"coin"), 5)
	assert_true(inv.remove_item(&"coin", 5))
	assert_eq(inv.count(&"coin"), 0)
	assert_eq(inv.save_state().currency, {}, "empty purse entries are erased")
	assert_eq(changes, 2)


# --- unknown ids & non-positive amounts -------------------------------------------

func test_unknown_id_warns_and_returns_amount() -> void:
	inv.add_item(&"wood", 2)
	changes = 0
	assert_eq(inv.add_item(&"banana", 3), 3)
	assert_eq(warnings.count_containing("banana"), 1, "exactly one warning names the id")
	assert_eq(changes, 0)
	assert_eq(inv.count(&"banana"), 0)
	assert_false(inv.has(&"banana"))
	assert_false(inv.can_add(&"banana", 1))
	assert_false(inv.remove_item(&"banana", 1))
	assert_eq(_layout()[0], [&"wood", 2])
	assert_eq(_layout()[1], [])


func test_non_positive_amounts_are_no_ops() -> void:
	inv.add_item(&"wood", 4)
	changes = 0
	var before := inv.save_state()
	assert_eq(inv.add_item(&"wood", 0), 0)
	assert_eq(inv.add_item(&"wood", -4), 0)
	assert_eq(inv.add_item(&"coin", -1), 0)
	assert_eq(inv.add_item(&"banana", 0), 0, "amount <= 0 → 0, even for unknown ids")
	assert_true(inv.remove_item(&"wood", 0))
	assert_true(inv.remove_item(&"wood", -3))
	assert_true(inv.remove_item(&"banana", 0))
	assert_true(inv.can_add(&"wood", 0))
	assert_true(inv.can_add(&"wood", -2))
	assert_eq(inv.save_state(), before)
	assert_eq(changes, 0)
	assert_eq(warnings.count_containing("banana"), 0)


# --- removing --------------------------------------------------------------------

func test_remove_is_all_or_nothing() -> void:
	_use_slots(4)
	inv.add_item(&"wood", 60)
	changes = 0
	var before := inv.save_state()
	assert_false(inv.remove_item(&"wood", 61))
	assert_eq(inv.save_state(), before, "a failed removal changes nothing")
	assert_eq(changes, 0)
	assert_true(inv.remove_item(&"wood", 60))
	assert_eq(inv.count(&"wood"), 0)
	assert_eq(_layout(), [[], [], [], []])
	assert_eq(changes, 1)


func test_remove_takes_from_last_stacks_first() -> void:
	_set_layout([[&"wood", 50], [&"wood", 50], [&"wood", 20], []])
	assert_true(inv.remove_item(&"wood", 30))
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 40], [], []])
	_set_layout([[&"wood", 50], [&"stone", 3], [&"wood", 10]])
	assert_true(inv.remove_item(&"wood", 15))
	assert_eq(_layout(), [[&"wood", 45], [&"stone", 3], []])
	assert_eq(changes, 1, "one emit for a removal spanning several stacks")


func test_freed_slot_is_reused() -> void:
	_set_layout([[&"wood", 50], [&"stone", 50]])
	assert_false(inv.can_add(&"linen", 1))
	assert_true(inv.remove_item(&"stone", 50))
	assert_true(inv.can_add(&"linen", 1))
	assert_eq(inv.add_item(&"linen", 1), 0)
	assert_eq(_layout(), [[&"wood", 50], [&"linen", 1]])


# --- queries -----------------------------------------------------------------------

func test_count_and_has_across_stacks() -> void:
	_set_layout([[&"stone", 50], [&"wood", 5], [&"stone", 7]], 3)
	assert_eq(inv.count(&"stone"), 57)
	assert_eq(inv.count(&"wood"), 5)
	assert_eq(inv.count(&"coin"), 3)
	assert_eq(inv.count(&"linen"), 0)
	assert_true(inv.has(&"stone"))
	assert_true(inv.has(&"stone", 57))
	assert_false(inv.has(&"stone", 58))
	assert_false(inv.has(&"linen"))


func test_can_add_matches_add_item_and_does_not_mutate() -> void:
	_set_layout([[&"wood", 45], [&"stone", 50]])
	var before := inv.save_state()
	assert_true(inv.can_add(&"wood", 5), "exact fit into the open stack")
	assert_false(inv.can_add(&"wood", 6))
	assert_false(inv.can_add(&"linen", 1), "no empty slot")
	assert_true(inv.can_add(&"coin", 99), "currency always fits")
	assert_eq(inv.save_state(), before)
	assert_eq(changes, 0)
	_set_layout([[], [&"wood", 30], []])
	for n: int in [1, 50, 119, 120, 121, 200]:
		var probe := _make(3)
		probe.load_state(inv.save_state())
		assert_eq(inv.can_add(&"wood", n), probe.add_item(&"wood", n) == 0, "can_add(wood, %d)" % n)
		probe.free()


# --- clear & signals ------------------------------------------------------------------

func test_clear_empties_slots_and_currency() -> void:
	inv.add_item(&"wood", 60)
	inv.add_item(&"coin", 5)
	changes = 0
	inv.clear()
	assert_eq(changes, 1)
	assert_eq(inv.count(&"wood"), 0)
	assert_eq(inv.count(&"coin"), 0)
	assert_eq(inv.get_slots().size(), 16)
	for slot: Dictionary in inv.get_slots():
		assert_eq(slot, {})
	inv.clear()
	assert_eq(changes, 1, "clearing an empty inventory is not a mutation")


func test_changed_emitted_once_per_successful_mutation() -> void:
	_use_slots(2)
	var steps: Array = [
		[func() -> void: inv.add_item(&"wood", 70), 1],          # spans two slots
		[func() -> void: inv.add_item(&"wood", 40), 1],          # partial (30 fit)
		[func() -> void: inv.add_item(&"wood", 1), 0],           # full
		[func() -> void: inv.add_item(&"stone", 1), 0],          # no slot
		[func() -> void: inv.add_item(&"coin", 3), 1],           # currency
		[func() -> void: inv.add_item(&"nothing", 3), 0],        # unknown
		[func() -> void: inv.remove_item(&"wood", 60), 1],       # spans two slots
		[func() -> void: inv.remove_item(&"wood", 999), 0],      # not enough
		[func() -> void: inv.remove_item(&"wood", 0), 0],        # no-op
		[func() -> void: inv.count(&"wood"), 0],
		[func() -> void: inv.has(&"wood", 1), 0],
		[func() -> void: inv.can_add(&"wood", 1), 0],
		[func() -> void: inv.get_slots(), 0],
		[func() -> void: inv.save_state(), 0],
		[func() -> void: inv.load_state(inv.save_state()), 1],  # replacement always refreshes
		[func() -> void: inv.clear(), 1],
		[func() -> void: inv.clear(), 0],
	]
	for i: int in steps.size():
		changes = 0
		(steps[i][0] as Callable).call()
		assert_eq(changes, steps[i][1], "step %d" % i)


# --- save / load ------------------------------------------------------------------------

func test_save_state_uses_plain_types() -> void:
	_use_slots(3)
	inv.add_item(&"linen", 4)
	inv.add_item(&"coin", 12)
	var state := inv.save_state()
	assert_eq(state.keys().size(), 2)
	var slots: Array = state.slots
	assert_eq(slots.size(), 3, "one entry per slot, {} for empty")
	assert_eq(slots, [{"id": &"linen", "amount": 4}, {}, {}])
	assert_eq(typeof(slots[0].id), TYPE_STRING_NAME)
	assert_eq(typeof(slots[0].amount), TYPE_INT)
	assert_false(slots.is_typed(), "plain Array")
	var currency: Dictionary = state.currency
	assert_eq(currency, {&"coin": 12})
	assert_eq(typeof(currency.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(currency.values()[0]), TYPE_INT)
	assert_false(currency.is_typed(), "plain Dictionary")
	slots[0]["amount"] = 1
	assert_eq(inv.count(&"linen"), 4, "save_state returns copies")


func test_save_load_round_trip_through_json() -> void:
	_use_slots(5)
	inv.add_item(&"wood", 60)
	inv.add_item(&"stone", 3)
	inv.add_item(&"shroud", 2)
	inv.remove_item(&"stone", 3)          # leaves a hole at index 2
	inv.add_item(&"coin", 12)
	var saved := inv.save_state()
	var restored := _json_round_trip(saved)
	assert_eq(restored, saved, "JSON.from_native/to_native keeps the state")
	var other := _make(5)
	other.load_state(restored)
	assert_eq(other.get_slots(), inv.get_slots(), "layout incl. holes survives")
	assert_eq(other.count(&"coin"), 12)
	assert_eq(other.save_state(), saved)
	assert_eq(typeof((other.get_slots()[0] as Dictionary).id), TYPE_STRING_NAME)
	other.free()


func test_load_state_replaces_everything() -> void:
	inv.add_item(&"wood", 7)
	inv.add_item(&"coin", 4)
	var saved := inv.save_state()
	var other := _make(16)
	other.add_item(&"linen", 5)
	other.add_item(&"coin", 30)
	changes = 0
	other.load_state(saved)
	assert_eq(changes, 1, "load_state emits exactly once")
	assert_eq(other.count(&"linen"), 0, "old items are gone")
	assert_eq(other.count(&"coin"), 4, "purse replaced, not added")
	assert_eq(other.save_state(), saved)
	other.load_state(saved)
	assert_eq(other.save_state(), saved, "idempotent")
	other.load_state({})
	assert_eq(other.count(&"wood"), 0)
	assert_eq(other.count(&"coin"), 0)
	assert_eq(other.get_slots().size(), 16)
	other.free()


func test_load_state_repacks_and_drops_invalid_entries() -> void:
	_use_slots(4)
	inv.load_state({
		"slots": [
			{"id": &"wood", "amount": 70},           # above max_stack → 50 here, 20 repacked
			{"id": "stone", "amount": 2.0},          # String id / float amount (hand-edited JSON)
			{"id": &"banana", "amount": 1},          # unknown → dropped
			"garbage",                               # not an entry → dropped
			{"id": &"linen", "amount": 0},           # empty amount → ignored
			{"id": &"linen", "amount": 4},           # index beyond slot_count → repacked
			{"id": &"coin", "amount": 3},            # currency never takes a slot
		],
		"currency": {"coin": 2},
	})
	assert_eq(_layout(), [[&"wood", 50], [&"stone", 2], [&"wood", 20], [&"linen", 4]])
	assert_eq(inv.count(&"coin"), 5)
	assert_eq(typeof((inv.get_slots()[1] as Dictionary).id), TYPE_STRING_NAME)
	assert_eq(typeof((inv.get_slots()[1] as Dictionary).amount), TYPE_INT)
	assert_eq(warnings.count_containing("banana"), 1)
	assert_eq(warnings.count_containing("garbage"), 1)


func test_load_state_drops_what_does_not_fit() -> void:
	_use_slots(1)
	inv.load_state({"slots": [{"id": &"wood", "amount": 10}, {"id": &"stone", "amount": 4}], "currency": {}})
	assert_eq(_layout(), [[&"wood", 10]])
	assert_eq(warnings.count_containing("stone"), 1, "lost items are reported")


func test_load_state_tolerates_wrong_container_types() -> void:
	inv.add_item(&"wood", 3)
	inv.load_state({"slots": "nope", "currency": 5})
	assert_eq(inv.count(&"wood"), 0)
	assert_eq(inv.get_slots().size(), 16)


# --- slot_count changes ---------------------------------------------------------------

func test_slot_count_change_keeps_items() -> void:
	_set_layout([[&"wood", 50], [], [&"stone", 5], [&"wood", 30]])
	inv.slot_count = 3
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 30], [&"stone", 5]], "slot 3 repacked into the free slot")
	assert_eq(changes, 1)
	inv.slot_count = 3
	assert_eq(changes, 1, "same count is not a change")
	inv.slot_count = 5
	assert_eq(_layout(), [[&"wood", 50], [&"wood", 30], [&"stone", 5], [], []])
	inv.slot_count = 1
	assert_eq(_layout(), [[&"wood", 50]])
	assert_eq(warnings.count_containing("dropped"), 2, "wood 30 and stone 5 had no room")
	inv.slot_count = -3
	assert_eq(inv.slot_count, 0)
	assert_eq(inv.get_slots().size(), 0)


# --- data -------------------------------------------------------------------------------

func test_database_finds_all_items() -> void:
	Database.reload()
	assert_eq(Database.items().size(), ITEMS.size())
	for id: StringName in ITEMS:
		var spec: Array = ITEMS[id]
		assert_true(Database.has_item(id), String(id))
		var item := Database.item(id) as ItemData
		assert_not_null(item, "%s is ItemData" % id)
		if item == null:
			continue
		assert_eq(item.id, id)
		assert_eq(typeof(item.id), TYPE_STRING_NAME)
		assert_eq(item.display_name, spec[0], "%s display_name" % id)
		assert_eq(item.category, spec[1], "%s category" % id)
		if spec[2] > 0:
			assert_eq(item.max_stack, spec[2], "%s max_stack" % id)
		assert_true(item.description.length() >= 20, "%s has a description" % id)
		assert_eq(item.resource_path, "res://data/items/%s.tres" % id, "file name = id")


func test_item_data_matches_test_fixtures() -> void:
	# Other modules test against tests/fixtures/items – they must mirror the real data.
	for id: StringName in ITEMS:
		var real := Database.item(id) as ItemData
		var fixture := load("res://tests/fixtures/items/%s.tres" % id) as ItemData
		assert_eq(real.category, fixture.category, String(id))
		assert_eq(real.display_name, fixture.display_name, String(id))
		if real.category != ItemData.Category.CURRENCY:
			assert_eq(real.max_stack, fixture.max_stack, String(id))


func test_start_items_fit_a_new_inventory() -> void:
	var start: Dictionary[StringName, int] = PlayerConfig.new().start_items
	for id: StringName in start:
		assert_eq(inv.add_item(id, start[id]), 0, String(id))
	assert_eq(inv.count(&"coin"), 5)
	assert_eq(_layout().slice(0, 3), [[&"wood", 2], [&"linen", 1], []], "coins take no slot")


# --- Phase 5: tool belt (P3, docs/PHASE5_DESIGN.md §2.3, §3.4, §5.1) -------------------------------

func _belt(slots: int = 20) -> Inventory:
	var i := _make(slots)
	i.tool_belt = true
	return i


func test_real_player_config_has_20_slots() -> void:
	var real := Database.config(&"player_config") as PlayerConfig
	assert_eq(real.inventory_slots, 20, "§2.3: 16 → 20")
	assert_eq(real.inventory_slots, Phase5Fixtures.player_config().inventory_slots)
	_use_slots(real.inventory_slots)
	assert_eq(inv.get_slots().size(), 20)


func test_belt_tools_take_no_slot() -> void:
	var b := _belt()
	changes = 0
	assert_eq(b.add_item(&"rake", 1), 0)
	assert_eq(b.add_item(&"shovel_iron", 1), 0)
	assert_eq(changes, 2, "changed once per call")
	assert_eq(b.tools(), {&"rake": 1, &"shovel_iron": 1} as Dictionary[StringName, int])
	for slot: Dictionary in b.get_slots():
		assert_true(slot.is_empty(), "get_slots never shows the belt")
	assert_eq(b.get_slots().size(), 20)
	assert_eq([b.count(&"rake"), b.count(&"shovel_iron")], [1, 1])
	assert_true(b.has(&"rake"))
	b.free()


func test_belt_holds_max_stack_per_id_and_returns_the_rest() -> void:
	var b := _belt()
	b.add_item(&"shears", 1)
	changes = 0
	assert_false(b.can_add(&"shears", 1), "one per id")
	assert_eq(b.add_item(&"shears", 1), 1, "the rest comes back")
	assert_eq(changes, 0, "refusal emits nothing")
	assert_eq(b.add_item(&"comb", 3), 2, "max_stack 1 → 2 back")
	assert_eq(b.count(&"comb"), 1)
	assert_true(b.can_add(&"pliers", 1))
	b.free()


func test_belt_is_not_blocked_by_full_slots() -> void:
	var b := _belt(1)
	b.add_item(&"wood", 50)
	assert_false(b.can_add(&"wood", 1))
	assert_true(b.can_add(&"axe_iron", 1), "the belt is outside the slots")
	assert_eq(b.add_item(&"axe_iron", 1), 0)
	b.free()


func test_remove_from_the_belt() -> void:
	var b := _belt()
	b.add_item(&"pickaxe_iron", 1)
	b.add_item(&"coin", 3)
	changes = 0
	assert_false(b.remove_item(&"pickaxe_iron", 2), "all or nothing")
	assert_eq(changes, 0)
	assert_true(b.remove_item(&"pickaxe_iron", 1))
	assert_eq(changes, 1)
	assert_eq(b.tools(), {} as Dictionary[StringName, int])
	assert_eq(b.count(&"pickaxe_iron"), 0)
	assert_eq(b.count(&"coin"), 3)
	b.free()


func test_chest_has_no_belt() -> void:
	# inv (before_each) is a plain slot inventory like the chest.
	assert_false(inv.tool_belt)
	inv.add_item(&"rake", 1)
	inv.add_item(&"shovel_master", 1)
	assert_eq(inv.tools(), {} as Dictionary[StringName, int])
	assert_eq(_layout().slice(0, 3), [[&"rake", 1], [&"shovel_master", 1], []])
	assert_false(inv.save_state().has("tools"), "no belt entry for the chest")


func test_switching_the_belt_on_moves_slot_tools() -> void:
	inv.add_item(&"wood", 3)
	inv.add_item(&"rake", 1)
	inv.add_item(&"comb", 1)
	changes = 0
	inv.tool_belt = true
	assert_eq(changes, 1)
	assert_eq(inv.tools(), {&"rake": 1, &"comb": 1} as Dictionary[StringName, int])
	assert_eq(_layout().slice(0, 3), [[&"wood", 3], [], []])
	inv.tool_belt = false
	assert_eq(inv.tools(), {} as Dictionary[StringName, int])
	assert_eq(inv.count(&"rake") + inv.count(&"comb"), 2, "back into slots, nothing lost")


func test_belt_save_and_load_roundtrip() -> void:
	var b := _belt()
	b.add_item(&"wood", 4)
	b.add_item(&"coin", 9)
	b.add_item(&"scrub_brush", 1)
	b.add_item(&"axe_master", 1)
	var saved := b.save_state()
	assert_eq(saved["tools"], {&"scrub_brush": 1, &"axe_master": 1})
	assert_eq((saved["slots"] as Array).size(), 20)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var c := _belt()
	changes = 0
	c.load_state(restored)
	assert_eq(changes, 1)
	assert_eq(c.save_state(), saved, "save → JSON → load → save is identical")
	assert_eq(c.tools(), b.tools())
	b.free()
	c.free()


func test_loading_old_slots_moves_tools_to_the_belt() -> void:
	# Phase-4 save: 16 slots with tools inside (§5.2 1).
	var b := _belt()
	var slots: Array = []
	for i: int in 16:
		slots.append({})
	slots[0] = {"id": "wood", "amount": 5}
	slots[2] = {"id": "rake", "amount": 1}
	slots[5] = {"id": "pliers", "amount": 1}
	slots[7] = {"id": "stone", "amount": 2}
	b.load_state({"slots": slots, "currency": {"coin": 4}})
	assert_eq(b.tools(), {&"rake": 1, &"pliers": 1} as Dictionary[StringName, int])
	var layout := b.get_slots()
	assert_eq(layout.size(), 20)
	assert_eq([layout[0], layout[2], layout[5], layout[7]], [{"id": &"wood", "amount": 5}, {}, {}, {"id": &"stone", "amount": 2}],
			"other slots keep their index")
	assert_eq(b.count(&"coin"), 4)
	assert_eq(warnings.count_containing("[Inventory]"), 0, "no warnings")
	b.free()


func test_loading_a_duplicate_belt_tool_keeps_it() -> void:
	var b := _belt()
	b.load_state({"slots": [{"id": "rake", "amount": 1}], "tools": {"rake": 1}})
	assert_eq(b.count(&"rake"), 2, "nothing lost")
	assert_eq(b.tools(), {&"rake": 1} as Dictionary[StringName, int])
	b.free()


func test_tools_without_belt_are_repacked_into_slots() -> void:
	inv.load_state({"slots": [], "tools": {"rake": 1, "bogus": 1}})
	assert_eq(inv.count(&"rake"), 1)
	assert_eq(_layout()[0], [&"rake", 1])
	assert_eq(warnings.count_containing("bogus"), 1, "unknown id warned as before")


func test_clear_empties_the_belt() -> void:
	var b := _belt()
	b.add_item(&"rake", 1)
	changes = 0
	b.clear()
	assert_eq(changes, 1)
	assert_eq(b.tools(), {} as Dictionary[StringName, int])
	b.clear()
	assert_eq(changes, 1, "clearing an empty inventory is a no-op")
	b.free()
