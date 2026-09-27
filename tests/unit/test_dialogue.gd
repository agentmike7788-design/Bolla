extends TestCase
## M4: DialogueRunner – conditions/actions mini-language, node skipping, choices – and the
## carter's dialogue data (§1, §2.4, §2.5, §3.4).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const CARTER_PATH := "res://data/dialogue/carter.tres"
const CARTER_SCHEDULE_PATH := "res://data/npc/carter_schedule.tres"
const LINEN_FIXTURE := "res://tests/fixtures/items/linen.tres"
const ITEM_FIXTURE_DIR := "res://tests/fixtures/items"
const MORNING := 465   # 07:45
const EVENING := 1140  # 19:00

const CONDITION_GRAMMAR := "^!?(has_item:[a-z_]+(:\\d+)?|flag:[a-z_]+|stat_gte:[a-z_]+:-?\\d+|stat_lt:[a-z_]+:-?\\d+|time_between:\\d+:\\d+|flag_eq:[a-z_]+:.*|flag_today:[a-z_]+)$"
const ACTION_GRAMMAR := "^(set_flag:[a-z_]+(:.+)?|clear_flag:[a-z_]+|take_item:[a-z_]+:\\d+|give_item:[a-z_]+:\\d+|stat_add:[a-z_]+:-?\\d+|notify:.+)$"


## Inventory double with limited room: add_item keeps at most `room` items.
class TightInventory extends "res://tests/fixtures/fake_inventory.gd":
	var room: int = 0

	func add_item(id: StringName, amount: int) -> int:
		var fit := clampi(room, 0, maxi(amount, 0))
		room -= fit
		super.add_item(id, fit)
		return maxi(amount, 0) - fit


## Duck-typed inventory that is not an Inventory at all.
class DuckInventory extends RefCounted:
	var items: Dictionary = {}

	func has(id: StringName, amount: int = 1) -> bool:
		return int(items.get(id, 0)) >= amount

	func add_item(id: StringName, amount: int) -> int:
		items[id] = int(items.get(id, 0)) + amount
		return 0

	func remove_item(id: StringName, amount: int) -> bool:
		if int(items.get(id, 0)) < amount:
			return false
		items[id] = int(items[id]) - amount
		return true


var notes: Array = []
var ended: Array = []
var _injected_linen: bool = false


func before_each() -> void:
	notes.clear()
	ended.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.dialogue_ended.connect(_on_ended)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.dialogue_ended.disconnect(_on_ended)
	if _injected_linen:
		Database._items.erase(&"linen")
		_injected_linen = false


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_ended(dialogue_id: StringName) -> void:
	ended.append(dialogue_id)


# --- helpers ---

func _inv(items: Dictionary = {}) -> Inventory:
	var inv: Inventory = FakeInventory.new()
	tree.root.add_child(inv)
	for id: StringName in items:
		inv.add_item(id, int(items[id]))
	return inv


func _ctx(inv: Object = null) -> Dictionary:
	return {"inventory": inv, "speaker": null}


func _check(cond: String, context: Dictionary = {}) -> bool:
	return DialogueRunner.check_condition(cond, context)


func _apply(action: String, context: Dictionary = {}) -> void:
	DialogueRunner.apply_action(action, context)


func _choice(text: String, next: StringName, conditions: Array[String] = [], actions: Array[String] = []) -> DialogueChoice:
	var c := DialogueChoice.new()
	c.text = text
	c.next = next
	c.conditions = conditions
	c.actions = actions
	return c


func _node(id: StringName, choices: Array[DialogueChoice] = [], conditions: Array[String] = [], fallback: StringName = &"", actions: Array[String] = []) -> DialogueNode:
	var n := DialogueNode.new()
	n.id = id
	n.text = "Text " + String(id)
	n.choices = choices
	n.conditions = conditions
	n.fallback_next = fallback
	n.actions = actions
	return n


func _dialogue(start: StringName, nodes: Array[DialogueNode]) -> DialogueData:
	var d := DialogueData.new()
	d.id = &"test_dialogue"
	d.start_node = start
	d.nodes = nodes
	return d


func _id(r: DialogueRunner) -> StringName:
	return r.current_node().id if r.current_node() != null else &""


## Chooses the available choice that leads to `next`.
func _go(r: DialogueRunner, next: StringName) -> void:
	var choices := r.available_choices()
	for i: int in choices.size():
		if choices[i].next == next:
			r.choose(i)
			return
	fail("no available choice to '%s' at node '%s'" % [next, _id(r)])


## Chooses the available choice whose actions contain `action`.
func _go_action(r: DialogueRunner, action: String) -> void:
	var choices := r.available_choices()
	for i: int in choices.size():
		if action in choices[i].actions:
			r.choose(i)
			return
	fail("no available choice with '%s' at node '%s'" % [action, _id(r)])


func _has_action_choice(r: DialogueRunner, action: String) -> bool:
	for c: DialogueChoice in r.available_choices():
		if action in c.actions:
			return true
	return false


func _carter() -> DialogueData:
	return load(CARTER_PATH) as DialogueData


func _start_carter(minute: int, inv: Inventory) -> DialogueRunner:
	TimeManager.minute_of_day = minute
	var r := DialogueRunner.new()
	r.start(_carter(), _ctx(inv))
	return r


func _linen_name() -> String:
	if not Database.has_item(&"linen"):
		Database._items[&"linen"] = load(LINEN_FIXTURE)
		_injected_linen = true
	return (Database.item(&"linen") as ItemData).display_name


# --- conditions: has_item ---

func test_has_item_counts() -> void:
	var ctx := _ctx(_inv({&"coin": 3}))
	assert_true(_check("has_item:coin:3", ctx), "exact amount")
	assert_true(_check("has_item:coin:1", ctx))
	assert_false(_check("has_item:coin:4", ctx))
	assert_false(_check("has_item:linen:1", ctx))
	assert_true(_check("has_item:coin", ctx), "n defaults to 1")
	assert_false(_check("has_item:linen", ctx))
	assert_true(_check("has_item:linen:0", ctx), "zero is always there")
	assert_true(_check("!has_item:coin:4", ctx), "negation")
	assert_true(_check("  has_item : coin : 3  ", ctx), "whitespace is ignored")


func test_has_item_malformed_is_false() -> void:
	var ctx := _ctx(_inv({&"coin": 3}))
	for cond: String in ["has_item:coin:drei", "has_item", "has_item:", "has_item::3", "has_item:coin:3:4", "!has_item:coin:x"]:
		assert_false(_check(cond, ctx), cond)


func test_has_item_without_usable_inventory_is_false() -> void:
	assert_false(_check("has_item:coin:1", {}))
	assert_false(_check("has_item:coin:1", {"inventory": "Beutel"}))
	assert_true(_check("!has_item:coin:1", {}), "no inventory holds nothing")
	var gone: Inventory = FakeInventory.new()
	gone.free()
	assert_false(_check("has_item:coin:1", {"inventory": gone}), "freed inventory")


func test_has_item_duck_typed_inventory() -> void:
	var duck := DuckInventory.new()
	duck.items[&"coin"] = 4
	assert_true(_check("has_item:coin:4", _ctx(duck)))
	assert_false(_check("has_item:coin:5", _ctx(duck)))


# --- conditions: flags ---

func test_flag_and_negated_flag() -> void:
	assert_false(_check("flag:met_carter"))
	assert_true(_check("!flag:met_carter"))
	GameState.set_flag(&"met_carter")
	assert_true(_check("flag:met_carter"))
	assert_false(_check("!flag:met_carter"))
	assert_true(_check("!!flag:met_carter"), "double negation")
	assert_false(_check("! flag:met_carter"), "space after ! is fine")


func test_flag_uses_value_truthiness() -> void:
	GameState.set_flag(&"off", false)
	GameState.set_flag(&"zero", 0)
	GameState.set_flag(&"empty", "")
	GameState.set_flag(&"day", 3)
	GameState.set_flag(&"word", "ja")
	assert_false(_check("flag:off"), "false flag")
	assert_true(_check("!flag:off"))
	assert_false(_check("flag:zero"))
	assert_false(_check("flag:empty"))
	assert_true(_check("flag:day"), "day number")
	assert_true(_check("flag:word"))


func test_flag_malformed_is_false() -> void:
	GameState.set_flag(&"met_carter")
	for cond: String in ["flag:", "flag", "!flag:", "!flag", "flag:met_carter:extra"]:
		assert_false(_check(cond), cond)


func test_flag_eq() -> void:
	GameState.set_flag(&"n", 3)
	GameState.set_flag(&"yes", true)
	GameState.set_flag(&"no", false)
	GameState.set_flag(&"place", "Tor")
	GameState.set_flag(&"ratio", 1.5)
	GameState.set_flag(&"pair", "a:b")
	assert_true(_check("flag_eq:n:3"))
	assert_true(_check("flag_eq:n:3.0"), "int flag vs decimal text")
	assert_false(_check("flag_eq:n:4"))
	assert_false(_check("flag_eq:n:drei"))
	assert_true(_check("flag_eq:yes:true"))
	assert_true(_check("flag_eq:yes:TRUE"))
	assert_false(_check("flag_eq:yes:false"))
	assert_true(_check("flag_eq:no:false"))
	assert_false(_check("flag_eq:no:true"))
	assert_true(_check("flag_eq:place:Tor"))
	assert_false(_check("flag_eq:place:tor"), "strings are case-sensitive")
	assert_true(_check("flag_eq:ratio:1.5"))
	assert_false(_check("flag_eq:ratio:2"))
	assert_true(_check("flag_eq:pair:a:b"), "value keeps its colons")
	assert_false(_check("flag_eq:missing:3"), "missing flag")
	assert_true(_check("!flag_eq:missing:3"))


func test_flag_eq_malformed_is_false() -> void:
	GameState.set_flag(&"n", 3)
	for cond: String in ["flag_eq:n", "flag_eq::3", "flag_eq", "!flag_eq:n"]:
		assert_false(_check(cond), cond)


func test_flag_today() -> void:
	TimeManager.day = 3
	assert_false(_check("flag_today:delivery_skipped"), "missing")
	assert_true(_check("!flag_today:delivery_skipped"))
	GameState.set_flag(&"delivery_skipped", 3)
	assert_true(_check("flag_today:delivery_skipped"))
	assert_false(_check("!flag_today:delivery_skipped"))
	TimeManager.day = 4
	assert_false(_check("flag_today:delivery_skipped"), "set yesterday")
	GameState.set_flag(&"delivery_skipped", 4.0)
	assert_true(_check("flag_today:delivery_skipped"), "float day value")
	GameState.set_flag(&"delivery_skipped", 4.5)
	assert_false(_check("flag_today:delivery_skipped"), "not a whole day")
	GameState.set_flag(&"delivery_skipped", "4")
	assert_false(_check("flag_today:delivery_skipped"), "text is not a day")
	GameState.set_flag(&"delivery_skipped", true)
	assert_false(_check("flag_today:delivery_skipped"), "bool is not a day")


func test_flag_today_malformed_is_false() -> void:
	for cond: String in ["flag_today:", "flag_today", "!flag_today:"]:
		assert_false(_check(cond), cond)


# --- conditions: stats ---

func test_stat_gte_and_stat_lt() -> void:
	GameState.add_stat(&"reputation", -3)
	assert_true(_check("stat_lt:reputation:-2"))
	assert_false(_check("stat_gte:reputation:-2"))
	assert_true(_check("stat_gte:reputation:-3"), "gte is inclusive")
	assert_false(_check("stat_lt:reputation:-3"), "lt is exclusive")
	assert_true(_check("!stat_gte:reputation:0"))
	GameState.add_stat(&"burials", 6)
	assert_true(_check("stat_gte:burials:6"))
	assert_true(_check("stat_gte:burials:+6"), "explicit plus sign")
	assert_true(_check("stat_gte:unknown_stat:0"), "unknown stats read 0")
	assert_false(_check("stat_lt:unknown_stat:0"))


func test_stat_malformed_is_false() -> void:
	for cond: String in ["stat_gte:reputation", "stat_lt:reputation:x", "stat_gte::1", "stat_lt", "stat_gte:reputation:1.5", "!stat_lt:reputation:x"]:
		assert_false(_check(cond), cond)


# --- conditions: time_between ---

func test_time_between_window() -> void:
	TimeManager.minute_of_day = 460
	assert_true(_check("time_between:0:720"))
	assert_true(_check("time_between:460:600"), "start inclusive")
	assert_false(_check("time_between:400:460"), "end exclusive")
	assert_false(_check("time_between:461:600"))
	assert_false(_check("time_between:500:500"), "empty window")
	assert_true(_check("!time_between:720:1440"))
	TimeManager.minute_of_day = 1439
	assert_true(_check("time_between:720:1440"), "end of day")


func test_time_between_wraps_over_midnight() -> void:
	var cond := "time_between:1260:330"
	for t: int in [1260, 1300, 1439, 0, 100, 329]:
		TimeManager.minute_of_day = t
		assert_true(_check(cond), "t=%d" % t)
	for t: int in [330, 600, 1259]:
		TimeManager.minute_of_day = t
		assert_false(_check(cond), "t=%d" % t)


func test_time_between_malformed_is_false() -> void:
	for cond: String in ["time_between:0", "time_between:a:b", "time_between", "time_between:07:00:12:00"]:
		assert_false(_check(cond), cond)


# --- conditions: unknown ---

func test_unknown_or_empty_condition_is_false() -> void:
	for cond: String in ["", "   ", "!", "unknown:x", "!unknown:x", "flags:met_carter", "FLAG:met_carter"]:
		assert_false(_check(cond), "'%s'" % cond)


# --- actions: flags ---

func test_set_flag_action_values() -> void:
	_apply("set_flag:met_carter")
	_apply("set_flag:count:3")
	_apply("set_flag:neg:-2")
	_apply("set_flag:ratio:0.5")
	_apply("set_flag:off:false")
	_apply("set_flag:on:True")
	_apply("set_flag:mood:grimmig")
	_apply("set_flag:note:Tor: offen")
	assert_true(GameState.get_flag(&"met_carter") is bool and GameState.get_flag(&"met_carter"))
	assert_true(GameState.get_flag(&"count") is int)
	assert_eq(GameState.get_flag(&"count"), 3)
	assert_eq(GameState.get_flag(&"neg"), -2)
	assert_true(GameState.get_flag(&"ratio") is float)
	assert_almost(GameState.get_flag(&"ratio"), 0.5)
	assert_true(GameState.get_flag(&"off") is bool)
	assert_eq(GameState.get_flag(&"off"), false)
	assert_eq(GameState.get_flag(&"on"), true)
	assert_true(GameState.get_flag(&"mood") is String)
	assert_eq(GameState.get_flag(&"mood"), "grimmig")
	assert_eq(GameState.get_flag(&"note"), "Tor: offen", "value keeps its colons")


func test_set_flag_then_flag_today_roundtrip() -> void:
	TimeManager.day = 5
	_apply("set_flag:talked:5")
	assert_true(_check("flag_today:talked"))
	assert_true(_check("flag_eq:talked:5"))


func test_set_flag_malformed_is_ignored() -> void:
	_apply("set_flag:")
	_apply("set_flag")
	_apply("set_flag::3")
	assert_eq(GameState.flags, {})


func test_clear_flag_action() -> void:
	GameState.set_flag(&"a")
	GameState.set_flag(&"b", 2)
	_apply("clear_flag:a")
	assert_false(GameState.has_flag(&"a"))
	assert_true(GameState.has_flag(&"b"))
	_apply("clear_flag:missing")
	_apply("clear_flag:")
	_apply("clear_flag")
	_apply("clear_flag:b:extra")
	assert_eq(GameState.flags, {"b": 2}, "the whole rest is the name")


# --- actions: items ---

func test_take_item_action() -> void:
	var inv := _inv({&"coin": 5})
	var ctx := _ctx(inv)
	_apply("take_item:coin:3", ctx)
	assert_eq(inv.count(&"coin"), 2)
	_apply("take_item:coin:3", ctx)
	assert_eq(inv.count(&"coin"), 2, "not enough: nothing taken")
	_apply("take_item:coin", ctx)
	assert_eq(inv.count(&"coin"), 1, "n defaults to 1")
	for bad: String in ["take_item:coin:0", "take_item:coin:-1", "take_item:coin:x", "take_item::1", "take_item"]:
		_apply(bad, ctx)
	assert_eq(inv.count(&"coin"), 1, "zero/invalid amounts change nothing")
	_apply("take_item:coin:1", {})
	assert_eq(notes, [], "taking never notifies")


func test_give_item_action_notifies_reward() -> void:
	var inv := _inv()
	_apply("give_item:test_relic:2", _ctx(inv))
	assert_eq(inv.count(&"test_relic"), 2)
	assert_eq(notes, [["+2 test_relic", &"reward"]], "raw id when the Database does not know the item")
	assert_true(notes[0][1] is StringName)


func test_give_item_uses_database_item_name() -> void:
	var item_name := _linen_name()
	assert_eq(item_name, "Leinen")
	var inv := _inv()
	_apply("give_item:linen:2", _ctx(inv))
	assert_eq(inv.count(&"linen"), 2)
	assert_eq(notes, [["+2 Leinen", &"reward"]])
	_apply("give_item:linen", _ctx(inv))
	assert_eq(inv.count(&"linen"), 3, "n defaults to 1")
	assert_eq(notes[1], ["+1 Leinen", &"reward"])


func test_give_item_zero_or_invalid_does_nothing() -> void:
	var inv := _inv()
	var ctx := _ctx(inv)
	for bad: String in ["give_item:linen:0", "give_item:linen:-2", "give_item:linen:x", "give_item::1", "give_item", "give_item:"]:
		_apply(bad, ctx)
	assert_eq(inv.count(&"linen"), 0)
	assert_eq(notes, [])


func test_give_item_without_room_warns() -> void:
	var item_name := _linen_name()
	var tight := TightInventory.new()
	tight.room = 1
	tree.root.add_child(tight)
	_apply("give_item:linen:3", _ctx(tight))
	assert_eq(tight.count(&"linen"), 1)
	assert_eq(notes, [["+1 " + item_name, &"reward"], ["Kein Platz für 2 " + item_name, &"warning"]])
	notes.clear()
	_apply("give_item:linen:2", _ctx(tight))
	assert_eq(notes, [["Kein Platz für 2 " + item_name, &"warning"]], "nothing fits: no reward")


func test_item_actions_without_inventory_do_nothing() -> void:
	_apply("give_item:linen:1", {})
	_apply("take_item:coin:1", {"inventory": 42})
	assert_eq(notes, [])


func test_item_actions_duck_typed_inventory() -> void:
	var duck := DuckInventory.new()
	duck.items[&"coin"] = 4
	_apply("take_item:coin:3", _ctx(duck))
	_apply("give_item:test_relic:1", _ctx(duck))
	assert_eq(duck.items[&"coin"], 1)
	assert_eq(duck.items[&"test_relic"], 1)
	assert_eq(notes, [["+1 test_relic", &"reward"]])


# --- actions: stats, notify, unknown ---

func test_stat_add_action() -> void:
	_apply("stat_add:reputation:-1")
	_apply("stat_add:reputation:-1")
	_apply("stat_add:burials:2")
	_apply("stat_add:custom:+5")
	assert_eq(GameState.get_stat(&"reputation"), -2)
	assert_eq(GameState.get_stat(&"burials"), 2)
	assert_eq(GameState.get_stat(&"custom"), 5, "new stat")


func test_stat_add_malformed_is_ignored() -> void:
	var before := GameState.stats.duplicate()
	for bad: String in ["stat_add:reputation", "stat_add:reputation:x", "stat_add:reputation:1.5", "stat_add::1", "stat_add"]:
		_apply(bad)
	assert_eq(GameState.stats, before)


func test_notify_action_keeps_colons() -> void:
	_apply("notify:Hallo")
	_apply("notify:Uhrzeit: 07:40 – Tor: offen")
	assert_eq(notes, [["Hallo", &"info"], ["Uhrzeit: 07:40 – Tor: offen", &"info"]])
	assert_true(notes[0][1] is StringName)


func test_notify_empty_does_nothing() -> void:
	_apply("notify:")
	_apply("notify:   ")
	_apply("notify")
	assert_eq(notes, [])


func test_unknown_action_is_ignored() -> void:
	var stats_before := GameState.stats.duplicate()
	for bad: String in ["", "  ", "explode:everything", "SET_FLAG:x", "setflag:x"]:
		_apply(bad)
	assert_eq(GameState.flags, {})
	assert_eq(GameState.stats, stats_before)
	assert_eq(notes, [])


# --- runner ---

func test_runner_before_start_is_finished() -> void:
	var r := DialogueRunner.new()
	assert_true(r.is_finished())
	assert_null(r.current_node())
	assert_eq(r.current_text(), "")
	assert_eq(r.available_choices().size(), 0)
	r.choose(0)
	assert_true(r.is_finished())


func test_start_without_data_finishes() -> void:
	var r := DialogueRunner.new()
	r.start(null, {})
	assert_true(r.is_finished())
	assert_eq(r.available_choices().size(), 0)


func test_start_enters_start_node_and_runs_its_actions() -> void:
	var a := _node(&"a", [_choice("weiter", &"b")], [], &"", ["set_flag:entered_a", "notify:Hallo"])
	var b := _node(&"b", [_choice("Ende", &"")], [], &"", ["set_flag:entered_b"])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [b, a]), {})
	assert_false(r.is_finished())
	assert_eq(r.current_node(), a, "start_node, not the first array entry")
	assert_eq(r.current_text(), "Text a")
	assert_true(GameState.has_flag(&"entered_a"))
	assert_false(GameState.has_flag(&"entered_b"))
	assert_eq(notes, [["Hallo", &"info"]])


func test_failing_nodes_are_skipped_along_fallback_chain() -> void:
	var a := _node(&"a", [_choice("x", &"")], ["flag:x"], &"b", ["set_flag:ran_a"])
	var b := _node(&"b", [_choice("x", &"")], ["flag:y"], &"c", ["set_flag:ran_b"])
	var c := _node(&"c", [_choice("x", &"")], [], &"", ["set_flag:ran_c"])
	var d := _dialogue(&"a", [a, b, c])
	var r := DialogueRunner.new()
	r.start(d, {})
	assert_eq(_id(r), &"c")
	assert_false(GameState.has_flag(&"ran_a"), "skipped nodes run no actions")
	assert_false(GameState.has_flag(&"ran_b"))
	assert_true(GameState.has_flag(&"ran_c"))
	GameState.set_flag(&"y")
	r.start(d, {})
	assert_eq(_id(r), &"b")
	GameState.set_flag(&"x")
	r.start(d, {})
	assert_eq(_id(r), &"a")


func test_all_node_conditions_must_hold() -> void:
	var a := _node(&"a", [_choice("x", &"")], ["flag:x", "flag:y"], &"b")
	var b := _node(&"b", [_choice("x", &"")])
	var d := _dialogue(&"a", [a, b])
	GameState.set_flag(&"x")
	var r := DialogueRunner.new()
	r.start(d, {})
	assert_eq(_id(r), &"b")
	GameState.set_flag(&"y")
	r.start(d, {})
	assert_eq(_id(r), &"a")


func test_fallback_to_nothing_ends_dialogue() -> void:
	var a := _node(&"a", [_choice("x", &"")], ["flag:x"], &"")
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	assert_true(r.is_finished())
	assert_eq(r.current_text(), "")


func test_unknown_node_ends_dialogue() -> void:
	var a := _node(&"a", [_choice("x", &"")], ["flag:x"], &"missing")
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	assert_true(r.is_finished(), "unknown fallback")
	r.start(_dialogue(&"missing", [a]), {})
	assert_true(r.is_finished(), "unknown start node")
	r.start(_dialogue(&"", [a]), {})
	assert_true(r.is_finished(), "empty start node")


func test_fallback_cycle_is_guarded() -> void:
	var a := _node(&"a", [_choice("x", &"")], ["flag:x"], &"b")
	var b := _node(&"b", [_choice("x", &"")], ["flag:x"], &"a")
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a, b]), {})
	assert_true(r.is_finished(), "a → b → a ends")
	var selfish := _node(&"s", [_choice("x", &"")], ["flag:x"], &"s")
	r.start(_dialogue(&"s", [selfish]), {})
	assert_true(r.is_finished(), "self cycle ends")


func test_cycle_guard_only_blocks_revisits_within_one_chain() -> void:
	# a (fails) → b (fails) → c; later a choice may lead back to a legitimately.
	var a := _node(&"a", [_choice("x", &"")], ["flag:x"], &"b")
	var b := _node(&"b", [_choice("x", &"")], ["flag:y"], &"c")
	var c := _node(&"c", [_choice("zurück", &"a", [], ["set_flag:y"])])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a, b, c]), {})
	assert_eq(_id(r), &"c")
	r.choose(0)
	assert_eq(_id(r), &"b", "a is skipped again, b now holds")


func test_available_choices_filters_live() -> void:
	var c1 := _choice("immer", &"")
	var c2 := _choice("mit Flag", &"", ["flag:x"])
	var c3 := _choice("mit Münzen", &"", ["has_item:coin:2"])
	var inv := _inv()
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [_node(&"a", [c1, c2, c3])]), _ctx(inv))
	assert_eq(r.available_choices(), [c1])
	GameState.set_flag(&"x")
	assert_eq(r.available_choices(), [c1, c2], "re-evaluated on every call")
	inv.add_item(&"coin", 2)
	assert_eq(r.available_choices(), [c1, c2, c3], "order preserved")


func test_available_choices_ignores_null_entries() -> void:
	var c1 := _choice("ok", &"")
	var a := _node(&"a", [c1])
	a.choices.append(null)
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	assert_eq(r.available_choices(), [c1])


func test_choose_runs_actions_before_entering_next() -> void:
	var pay := _choice("zahlen", &"b", [], ["set_flag:paid", "stat_add:payments:1"])
	var a := _node(&"a", [pay])
	var b := _node(&"b", [_choice("x", &"")], ["flag:paid"], &"c")
	var c := _node(&"c", [_choice("x", &"")])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a, b, c]), {})
	r.choose(0)
	assert_eq(_id(r), &"b", "next node sees the choice's effect")
	assert_eq(GameState.get_stat(&"payments"), 1, "actions run exactly once")


func test_choose_index_refers_to_available_choices() -> void:
	var hidden := _choice("versteckt", &"b", ["flag:x"])
	var shown := _choice("sichtbar", &"c")
	var a := _node(&"a", [hidden, shown])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a, _node(&"b", [_choice("x", &"")]), _node(&"c", [_choice("x", &"")])]), {})
	r.choose(0)
	assert_eq(_id(r), &"c")


func test_choose_empty_next_finishes_without_signal() -> void:
	var a := _node(&"a", [_choice("Ende", &"", [], ["set_flag:bye"])])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	r.choose(0)
	assert_true(r.is_finished())
	assert_null(r.current_node())
	assert_eq(r.current_text(), "")
	assert_eq(r.available_choices().size(), 0)
	assert_true(GameState.has_flag(&"bye"), "ending choice still runs its actions")
	assert_eq(ended, [], "the runner never emits dialogue_ended")


func test_choose_out_of_range_is_ignored() -> void:
	var a := _node(&"a", [_choice("x", &"", [], ["set_flag:chosen"]), _choice("y", &"", ["flag:never"])])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	r.choose(1)
	r.choose(-1)
	r.choose(99)
	assert_eq(_id(r), &"a")
	assert_false(GameState.has_flag(&"chosen"))


func test_choose_after_finish_is_ignored() -> void:
	var a := _node(&"a", [_choice("Ende", &"", [], ["stat_add:ends:1"])])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), {})
	r.choose(0)
	r.choose(0)
	assert_eq(GameState.get_stat(&"ends"), 1)


func test_choice_conditions_rechecked_when_choosing() -> void:
	var buy := _choice("kaufen", &"", ["has_item:coin:3"], ["take_item:coin:3", "give_item:linen:1"])
	var inv := _inv({&"coin": 3})
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [_node(&"a", [buy])]), _ctx(inv))
	assert_eq(r.available_choices().size(), 1)
	inv.remove_item(&"coin", 1)
	r.choose(0)
	assert_eq(_id(r), &"a", "no longer available: ignored")
	assert_eq(inv.count(&"coin"), 2)
	assert_eq(inv.count(&"linen"), 0)


func test_reentering_node_via_choice_runs_actions_again() -> void:
	var hub := _node(&"hub", [_choice("nochmal", &"hub"), _choice("Ende", &"")], [], &"", ["stat_add:visits:1"])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"hub", [hub]), {})
	r.choose(0)
	r.choose(0)
	assert_eq(_id(r), &"hub")
	assert_eq(GameState.get_stat(&"visits"), 3)


func test_restart_after_finish() -> void:
	var d := _dialogue(&"a", [_node(&"a", [_choice("Ende", &"")])])
	var r := DialogueRunner.new()
	r.start(d, {})
	r.choose(0)
	assert_true(r.is_finished())
	r.start(d, {})
	assert_eq(_id(r), &"a")


func test_node_actions_use_the_context_inventory() -> void:
	var inv := _inv()
	var a := _node(&"a", [_choice("x", &"")], [], &"", ["give_item:test_relic:1"])
	var r := DialogueRunner.new()
	r.start(_dialogue(&"a", [a]), _ctx(inv))
	assert_eq(inv.count(&"test_relic"), 1)


# --- carter data: structure ---

func test_carter_identity() -> void:
	var d := _carter()
	assert_not_null(d, CARTER_PATH)
	assert_eq(d.id, &"carter")
	assert_eq(d.speaker_name, "Osric Faulhaber")
	assert_not_null(d.get_node_by_id(d.start_node), "start node exists")
	assert_eq(Database.dialogue(&"carter"), d, "registered in Database by id")


func test_carter_node_ids_unique_and_targets_exist() -> void:
	var d := _carter()
	var ids: Dictionary[StringName, bool] = {}
	for n: DialogueNode in d.nodes:
		assert_not_null(n)
		assert_false(ids.has(n.id), "duplicate node id %s" % n.id)
		ids[n.id] = true
	for n: DialogueNode in d.nodes:
		if n.fallback_next != &"":
			assert_true(ids.has(n.fallback_next), "%s fallback → %s" % [n.id, n.fallback_next])
		for c: DialogueChoice in n.choices:
			assert_not_null(c, "null choice in %s" % n.id)
			if c.next != &"":
				assert_true(ids.has(c.next), "%s → %s" % [n.id, c.next])


func test_carter_every_node_reachable() -> void:
	var d := _carter()
	var seen: Dictionary[StringName, bool] = {d.start_node: true}
	var queue: Array[StringName] = [d.start_node]
	while not queue.is_empty():
		var next_id: StringName = queue.pop_front()
		var n := d.get_node_by_id(next_id)
		var targets: Array[StringName] = [n.fallback_next]
		for c: DialogueChoice in n.choices:
			targets.append(c.next)
		for t: StringName in targets:
			if t != &"" and not seen.has(t):
				seen[t] = true
				queue.append(t)
	for n: DialogueNode in d.nodes:
		assert_true(seen.has(n.id), "node %s unreachable" % n.id)


func test_carter_no_dead_ends() -> void:
	for n: DialogueNode in _carter().nodes:
		var unconditional := 0
		var ending := 0
		for c: DialogueChoice in n.choices:
			if c.conditions.is_empty():
				unconditional += 1
			if c.next == &"":
				ending += 1
		assert_true(unconditional >= 1, "%s always offers a choice" % n.id)
		if String(n.id).begins_with("goodbye"):
			assert_eq(ending, n.choices.size(), "%s only ends" % n.id)
		else:
			assert_eq(ending, 0, "%s must not end the dialogue" % n.id)
		if not n.conditions.is_empty():
			assert_ne(n.fallback_next, &"", "conditional %s needs a fallback" % n.id)


func test_carter_goodbye_reachable_from_every_node() -> void:
	# Along unconditional choices and fallbacks – the player can always leave.
	var d := _carter()
	for start: DialogueNode in d.nodes:
		var seen: Dictionary[StringName, bool] = {start.id: true}
		var queue: Array[StringName] = [start.id]
		var found := false
		while not queue.is_empty() and not found:
			var next_id: StringName = queue.pop_front()
			var n := d.get_node_by_id(next_id)
			if String(n.id).begins_with("goodbye"):
				found = true
				break
			var targets: Array[StringName] = [n.fallback_next]
			for c: DialogueChoice in n.choices:
				if c.conditions.is_empty():
					targets.append(c.next)
			for t: StringName in targets:
				if t != &"" and not seen.has(t):
					seen[t] = true
					queue.append(t)
		assert_true(found, "no way out from %s" % start.id)


func test_carter_conditions_and_actions_follow_grammar() -> void:
	var cond_re := RegEx.create_from_string(CONDITION_GRAMMAR)
	var action_re := RegEx.create_from_string(ACTION_GRAMMAR)
	var conditions: Array[String] = []
	var actions: Array[String] = []
	for n: DialogueNode in _carter().nodes:
		conditions.append_array(n.conditions)
		actions.append_array(n.actions)
		for c: DialogueChoice in n.choices:
			conditions.append_array(c.conditions)
			actions.append_array(c.actions)
	assert_false(conditions.is_empty())
	for cond: String in conditions:
		assert_not_null(cond_re.search(cond), "condition '%s'" % cond)
		if cond.begins_with("!"):
			assert_true(cond.begins_with("!flag:"), "only !flag negation as in §3.4: '%s'" % cond)
	for action: String in actions:
		assert_not_null(action_re.search(action), "action '%s'" % action)
		if action.begins_with("take_item:") or action.begins_with("give_item:"):
			var id := action.get_slice(":", 1)
			assert_true(ResourceLoader.exists(ITEM_FIXTURE_DIR.path_join(id + ".tres")), "item %s exists (§2.2)" % id)


func test_carter_texts_are_filled() -> void:
	for n: DialogueNode in _carter().nodes:
		assert_true(n.text.strip_edges().length() > 0, "text of %s" % n.id)
		for c: DialogueChoice in n.choices:
			assert_true(c.text.strip_edges().length() > 0, "choice text in %s" % n.id)


func test_carter_price_texts_match_actions() -> void:
	var offers := 0
	for n: DialogueNode in _carter().nodes:
		for c: DialogueChoice in n.choices:
			for action: String in c.actions:
				if action.begins_with("take_item:coin:"):
					var price := action.get_slice(":", 2)
					offers += 1
					assert_true(c.text.contains("(%s Münzen)" % price), "price shown in '%s'" % c.text)
					assert_has(c.conditions, "has_item:coin:" + price, "guarded by the price")
	assert_eq(offers, 2, "1 and 2 Leinen")


func test_carter_intro_mentions_schedule_times() -> void:
	var schedule := load(CARTER_SCHEDULE_PATH) as NpcSchedule
	var arrival := ScheduleResolver.arrival_minute(ScheduleResolver.entry_at(schedule, 420))
	var clock := "%02d:%02d" % [floori(arrival / 60.0), arrival % 60]
	var text := _carter().get_node_by_id(&"intro_linen").text
	assert_true(text.contains(clock), "intro names the arrival %s" % clock)
	assert_true(text.contains("Leinen"))
	assert_true(text.contains("Leichentuch"))


# --- carter data: walkthroughs ---

func test_carter_first_meeting() -> void:
	var inv := _inv({&"coin": 5, &"linen": 1})
	var r := _start_carter(MORNING, inv)
	assert_eq(_id(r), &"intro")
	assert_true(GameState.has_flag(&"met_carter"), "intro sets met_carter on entry")
	assert_true(r.current_text().contains("Osric Faulhaber"))
	_go(r, &"intro_linen")
	_go(r, &"intro_absent")
	assert_true(r.current_text().contains("Bahre"), "explains the skipped delivery rule")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "no remarks apply → menu")
	_go(r, &"shop")
	_go_action(r, "give_item:linen:1")
	assert_eq(_id(r), &"shop_bought")
	assert_eq(inv.count(&"coin"), 2)
	assert_eq(inv.count(&"linen"), 2)
	assert_eq(notes.size(), 1)
	assert_eq(notes[0][1], &"reward")
	assert_true(String(notes[0][0]).begins_with("+1 "))
	assert_eq(r.available_choices().size(), 1, "2 coins left: no 'more' offer")
	_go(r, &"menu")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())
	assert_eq(ended, [])
	r.start(_carter(), _ctx(inv))
	assert_eq(_id(r), &"greet_morning", "intro only once")


func test_carter_first_meeting_short_path() -> void:
	var r := _start_carter(EVENING, _inv())
	assert_eq(_id(r), &"intro", "first meeting also in the evening")
	_go(r, &"intro_linen")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	_go(r, &"goodbye_morning")
	assert_eq(_id(r), &"goodbye", "evening goodbye")
	_go(r, &"")
	assert_true(r.is_finished())


func test_carter_later_morning() -> void:
	GameState.set_flag(&"met_carter")
	var r := _start_carter(480, _inv())
	assert_eq(_id(r), &"greet_morning")
	assert_true(r.current_text().begins_with("Morgen"))
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	_go(r, &"goodbye_morning")
	assert_eq(_id(r), &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())


func test_carter_evening() -> void:
	GameState.set_flag(&"met_carter")
	var r := _start_carter(EVENING, _inv())
	assert_eq(_id(r), &"greet_evening")
	assert_true(r.current_text().begins_with("Abend"))
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	_go(r, &"goodbye_morning")
	assert_eq(_id(r), &"goodbye", "evening variant")
	_go(r, &"")
	assert_true(r.is_finished())


func test_carter_greeting_switches_at_noon() -> void:
	GameState.set_flag(&"met_carter")
	assert_eq(_id(_start_carter(719, _inv())), &"greet_morning")
	assert_eq(_id(_start_carter(720, _inv())), &"greet_evening")
	assert_eq(_id(_start_carter(0, _inv())), &"greet_morning")
	assert_eq(_id(_start_carter(1439, _inv())), &"greet_evening")


func test_carter_poor_player_cannot_buy() -> void:
	GameState.set_flag(&"met_carter")
	var inv := _inv({&"coin": 2})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"shop")
	assert_eq(r.available_choices().size(), 1, "only 'Heute nicht.'")
	assert_false(_has_action_choice(r, "give_item:linen:1"))
	assert_false(_has_action_choice(r, "give_item:linen:2"))
	_go(r, &"shop_leave")
	assert_eq(_id(r), &"shop_poor", "he notices the empty purse")
	assert_eq(inv.count(&"coin"), 2)
	assert_eq(inv.count(&"linen"), 0)
	assert_eq(notes, [])
	_go(r, &"menu")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())


func test_carter_decline_with_money() -> void:
	GameState.set_flag(&"met_carter")
	var r := _start_carter(MORNING, _inv({&"coin": 5}))
	_go(r, &"remark_skipped")
	_go(r, &"shop")
	assert_true(_has_action_choice(r, "give_item:linen:1"))
	assert_false(_has_action_choice(r, "give_item:linen:2"), "5 coins: one Elle only")
	_go(r, &"shop_leave")
	assert_eq(_id(r), &"shop_leave")


func test_carter_buy_two_linen_then_more() -> void:
	GameState.set_flag(&"met_carter")
	var inv := _inv({&"coin": 9})
	var item_name := _linen_name()
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"shop")
	_go_action(r, "give_item:linen:2")
	assert_eq(inv.count(&"coin"), 3)
	assert_eq(inv.count(&"linen"), 2)
	assert_eq(notes, [["+2 " + item_name, &"reward"]])
	_go(r, &"shop")
	assert_false(_has_action_choice(r, "give_item:linen:2"), "3 coins left")
	_go_action(r, "give_item:linen:1")
	assert_eq(inv.count(&"coin"), 0)
	assert_eq(inv.count(&"linen"), 3)
	assert_eq(r.available_choices().size(), 1, "broke now")
	_go(r, &"menu")
	_go(r, &"shop")
	_go(r, &"shop_leave")
	assert_eq(_id(r), &"shop_poor")


func test_carter_skipped_delivery_day() -> void:
	GameState.set_flag(&"met_carter")
	TimeManager.day = 3
	GameState.set_flag(&"delivery_skipped", 3)
	var r := _start_carter(MORNING, _inv())
	assert_eq(_id(r), &"greet_morning")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_skipped")
	assert_true(r.current_text().begins_with("Die Bahre war noch belegt"))
	_go(r, &"remark_rep")
	assert_eq(_id(r), &"menu", "reputation fine → menu")
	r = _start_carter(EVENING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_skipped", "still today in the evening")
	TimeManager.day = 4
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "yesterday's skip is not mentioned")


func test_carter_bad_reputation() -> void:
	GameState.set_flag(&"met_carter")
	GameState.add_stat(&"reputation", -2)
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "-2 is only 'Unauffällig'")
	GameState.add_stat(&"reputation", -1)
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_rep", "-3 = 'Verrufen'")
	assert_true(r.current_text().begins_with("Man redet im Dorf"))
	assert_eq(r.available_choices().size(), 2)
	_go(r, &"menu")
	assert_eq(_id(r), &"menu")


func test_carter_skipped_day_and_bad_reputation_both_shown() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"delivery_skipped", TimeManager.day)
	GameState.add_stat(&"reputation", -4)
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_skipped")
	_go(r, &"remark_rep")
	assert_eq(_id(r), &"remark_rep")
	_go(r, &"menu")
	assert_eq(_id(r), &"menu")


func test_carter_after_slice_complete() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"slice_complete")
	var r := _start_carter(EVENING, _inv())
	assert_eq(_id(r), &"slice_done")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())


func test_carter_small_talk() -> void:
	GameState.set_flag(&"met_carter")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	_go(r, &"village")
	assert_true(r.current_text().contains("Hollerbrück"))
	_go(r, &"village_people")
	_go(r, &"village_vanished")
	_go(r, &"menu")
	_go(r, &"mystery")
	_go(r, &"mystery_more")
	assert_true(r.current_text().contains("Wunde"), "hints at the strange corpses")
	_go(r, &"menu")
	_go(r, &"village")
	_go(r, &"menu")
	_go(r, &"mystery")
	_go(r, &"menu")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())
	assert_eq(GameState.flags, {"met_carter": true}, "small talk changes no state")
	assert_eq(notes, [])
