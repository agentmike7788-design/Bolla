extends TestCase
## M4: DialogueRunner – conditions/actions mini-language, node skipping, choices – and the
## carter's dialogue data (§1, §2.4, §2.5, §3.4). Phase 3 (P6, docs/PHASE3_DESIGN.md §1.3,
## §2.2, §2.6, §2.7): day conditions, Ostwiese introduction, iron/seed shop, reputation remarks
## on the 0…100 scale, odd-day deliveries at "Verrufen", migrated saves (vs_finished).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const CARTER_PATH := "res://data/dialogue/carter.tres"
const CARTER_SCHEDULE_PATH := "res://data/npc/carter_schedule.tres"
const LINEN_FIXTURE := "res://tests/fixtures/items/linen.tres"
const ITEM_FIXTURE_DIR := "res://tests/fixtures/items"
const MORNING := 465   # 07:45
const EVENING := 1140  # 19:00
## A new game starts "Unauffällig" (docs/PHASE3_DESIGN.md §2.6); reset() leaves the stat at 0.
const NEW_GAME_REPUTATION := 25

const CONDITION_GRAMMAR := ("^!?(has_item:[a-z_]+(:\\d+)?|flag:[a-z_0-9]+|stat_gte:[a-z_]+:-?\\d+|stat_lt:[a-z_]+:-?\\d+|time_between:\\d+:\\d+|flag_eq:[a-z_]+:.*|flag_today:[a-z_0-9]+|day_gte:\\d+|day_odd|day_even|piety_tier:(hardhearted|callous|matter_of_fact|considerate|devout)|trader_talks_gte:\\d+|clue_known:c_[a-z_0-9]+|flag_night:[a-z_]+"
		# Phase 7 (P6, docs/PHASE7_DESIGN.md §3.4)
		+ "|rel_gte:[a-z_]+:\\d+|rel_tier:[a-z_]+:(stranger|acquainted|trusted|friend)|met:[a-z_]+|rep_tier:(disreputable|unremarkable|respected|esteemed|renowned)"
		+ "|order:[a-z_0-9]+:(none|offered|accepted|completed|failed)|order_offerable:[a-z_0-9]+|order_ready:[a-z_0-9]+|shop_open:[a-z_]+|region:[a-z_]+"
		+ "|specimens_held_gte:\\d+|specimen_sold_any|alive:[a-z_]+|lecture_tonight|village_open_days_gte:\\d+|flag_days_gte:[a-z_0-9]+:\\d+"
		+ "|village_can:(round|donate|consecrate)|mourning_today"
		# Phase 8 (P6, docs/PHASE8_DESIGN.md §3.4 + W0-Notizen 10)
		+ "|p8_open|open_days_gte:\\d+|mood:[a-z_]+:(plain|cheerful|low|cross)|step_gte:[a-z_]+:\\d+|step_offerable:[a-z_]+"
		+ "|favor_ready:[a-z_]+|favor_owed:[a-z_]+|apprentice_hired|apprentice_level_gte:([a-z_]+:)?\\d+|apprentice_mistake_today"
		+ "|wish_offerable|visit_waiting|tip_due|fest_(today|day|running|eve|after):[a-z_]+|alms_gte:\\d+|robber_known"
		+ "|robber_fate:(none|reported|let_go|caught_watch)|sick_light(:[a-z_]+)?|observed:c_[a-z_0-9]+|underlined:(priest|surgeon|washer)"
		+ "|insight:i_[a-z_]+|ware_ready)$")
const ACTION_GRAMMAR := ("^(set_flag:[a-z_0-9]+(:.+)?|clear_flag:[a-z_0-9]+|take_item:[a-z_]+:\\d+(:[a-z_]+)?|give_item:[a-z_]+:\\d+|stat_add:[a-z_]+:-?\\d+|notify:.+|open_panel:[a-z_]+|open_trade|add_clue:c_[a-z_0-9]+|trader_tools|trader_talked|set_flag_night:[a-z_]+"
		# Phase 7 (P6)
		+ "|meet:[a-z_0-9]+|talked:[a-z_]+|open_shop:[a-z_]+|open_gifts:[a-z_]+|order_offer:[a-z_0-9]+|order_accept:[a-z_0-9]+|order_turn_in:[a-z_0-9]+"
		+ "|buy_round|donate|consecrate_pay|anatomy_case|open_anatomist|open_lecture|lecture_invite|rel_add:[a-z_]+:-?\\d+|set_flag_day:[a-z_0-9]+"
		# Phase 8 (P6)
		+ "|listen:[a-z_]+|step_accept:[a-z_]+|favor_use:[a-z_]+(:[a-z_]+)?|apprentice_hire|apprentice_teach:[a-z_]+|apprentice_praise"
		+ "|apprentice_scold|wish_offer|wish_accept|tip_hand|alms|dance:[a-z_]+|robber_resolve:(reported|let_go)|task:[a-z_]+"
		+ "|note_event:[a-z_]+|take_ware)$")
## Negations the data may use (flag-like conditions, docs/PHASE4_DESIGN.md §3.4).
const NEGATABLE: PackedStringArray = ["!flag:", "!piety_tier:", "!flag_night:", "!trader_talks_gte:", "!clue_known:", "!met:",
		"!rel_tier:", "!alive:", "!flag_today:", "!flag_days_gte:", "!step_gte:", "!apprentice_level_gte:"]


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
	GameState.stats[&"reputation"] = NEW_GAME_REPUTATION


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
	GameState.stats[&"reputation"] = -3
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


# --- conditions: day (Phase 3) ---

func test_day_gte() -> void:
	TimeManager.day = 2
	assert_true(_check("day_gte:1"))
	assert_true(_check("day_gte:2"), "inclusive")
	assert_false(_check("day_gte:3"))
	assert_true(_check("!day_gte:3"))


func test_day_odd_and_even() -> void:
	for day: int in [1, 2, 3, 14]:
		TimeManager.day = day
		assert_eq(_check("day_odd"), day % 2 == 1, "day %d odd" % day)
		assert_eq(_check("day_even"), day % 2 == 0, "day %d even" % day)
		assert_eq(_check("!day_odd"), day % 2 == 0, "day %d !odd" % day)


func test_day_conditions_malformed_are_false() -> void:
	for cond: String in ["day_gte", "day_gte:", "day_gte:x", "day_gte:1.5", "day_odd:1", "day_even:", "!day_gte:x"]:
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
	GameState.stats[&"reputation"] = 0
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
			assert_true(Array(NEGATABLE).any(func(prefix: String) -> bool: return cond.begins_with(prefix)), "negation '%s'" % cond)
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
					var shown := "(1 Münze)" if price == "1" else "(%s Münzen)" % price
					assert_true(c.text.contains(shown), "price shown in '%s'" % c.text)
					assert_has(c.conditions, "has_item:coin:" + price, "guarded by the price")
	assert_eq(offers, 15, "1 and 2 Leinen, 1 and 3 Eisenbeschläge, 1 and 4 Blumensamen, 1 and 5 Wacholder + Phase 5: license, pickaxe, steel rod, 2 and 4 Eisenbeschläge + Phase 6: 1 and 3 Altarkerzen")


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
	GameState.set_flag(&"p3_intro")
	GameState.set_flag(&"p4_intro")  # Phase 4 told already (test_carter_p4_*)
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
	GameState.stats[&"reputation"] = 15
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "15 is only 'Unauffällig'")
	GameState.stats[&"reputation"] = 14
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_rep", "14 = 'Verrufen'")
	assert_true(r.current_text().begins_with("Man redet im Dorf"))
	assert_eq(r.available_choices().size(), 3)
	_go(r, &"rep_odd_days")
	assert_true(r.current_text().contains("ungeraden"), "explains the odd-day deliveries")
	_go(r, &"p3_intro")
	assert_eq(_id(r), &"menu", "day 1: no Ostwiese yet")


func test_carter_skipped_day_and_bad_reputation_both_shown() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"delivery_skipped", TimeManager.day)
	GameState.stats[&"reputation"] = 5
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_skipped")
	_go(r, &"remark_rep")
	assert_eq(_id(r), &"remark_rep")
	_go(r, &"p3_intro")
	assert_eq(_id(r), &"menu")


func test_carter_after_migrated_slice() -> void:
	# A Phase-2 save that finished the slice arrives with vs_finished (SaveMigration §5.2).
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"vs_finished")
	TimeManager.day = 7
	var r := _start_carter(EVENING, _inv())
	assert_eq(_id(r), &"slice_done")
	assert_true(r.current_text().contains("Alte Hof jetzt voll"), "leads over to the new sections")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p3_intro", "then the Ostwiese")
	assert_true(GameState.has_flag(&"p3_intro"))
	_go(r, &"menu")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())
	assert_eq(_id(_start_carter(EVENING, _inv())), &"greet_evening", "the praise only once")


func test_carter_old_slice_flag_is_ignored() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"slice_complete")
	assert_eq(_id(_start_carter(EVENING, _inv())), &"greet_evening", "slice_done checks vs_finished")


# --- Phase 3 (docs/PHASE3_DESIGN.md §1.3, §2.2, §2.6, §2.7) ---

func test_carter_ostwiese_from_day_two() -> void:
	GameState.set_flag(&"met_carter")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "day 1: tutorial unchanged")
	assert_false(GameState.has_flag(&"p3_intro"))
	for c: DialogueChoice in r.available_choices():
		assert_ne(c.next, &"shop_p3", "no iron shop before the introduction")
	TimeManager.day = 2
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p3_intro")
	assert_true(r.current_text().contains("Ostwiese"))
	assert_true(r.current_text().contains("Gemeinde hätte nichts dagegen"))
	assert_true(r.current_text().contains("Birkenhang"))
	assert_true(GameState.has_flag(&"p3_intro"), "set on entry")
	_go(r, &"p3_intro_tools")
	for word: String in ["Eisenbeschläge", "Samen", "Rechen", "Werkbank"]:
		assert_true(r.current_text().contains(word), word)
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_intro", "introduction only once – Phase 4 follows in the next talk")
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "both introductions only once")
	_go(r, &"shop_p3")
	assert_eq(_id(r), &"shop_p3", "shop reachable from the menu afterwards")


func test_carter_ostwiese_after_first_meeting_later() -> void:
	TimeManager.day = 3
	var r := _start_carter(MORNING, _inv())
	assert_eq(_id(r), &"intro")
	_go(r, &"intro_linen")
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p3_intro", "a first meeting after day 1 also tells of the Ostwiese")


func test_carter_sells_iron_and_seeds() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.set_flag(&"p4_intro")  # Phase 4 told already (test_carter_p4_*)
	TimeManager.day = 2
	var inv := _inv({&"coin": 14})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"shop_p3")
	assert_true(r.current_text().contains("drei Münzen"))
	_go_action(r, "give_item:iron_fittings:3")
	assert_eq(_id(r), &"shop_p3_bought")
	assert_eq([inv.count(&"coin"), inv.count(&"iron_fittings")], [5, 3])
	assert_eq(notes, [["+3 Eisenbeschlag", &"reward"]], "Database name")
	_go(r, &"shop_p3")
	assert_false(_has_action_choice(r, "give_item:iron_fittings:3"), "5 coins left")
	_go_action(r, "give_item:seeds:4")
	assert_eq([inv.count(&"coin"), inv.count(&"seeds")], [1, 4])
	_go(r, &"shop_p3")
	assert_eq(r.available_choices().size(), 2, "1 coin: one seed packet or leave")
	_go_action(r, "give_item:seeds:1")
	assert_eq([inv.count(&"coin"), inv.count(&"seeds")], [0, 5])
	assert_eq(r.available_choices().size(), 1, "broke: only 'Danke.'")
	_go(r, &"menu")
	_go(r, &"shop_p3")
	assert_eq(r.available_choices().size(), 1, "only 'Heute nicht.'")
	_go(r, &"shop_p3_leave")
	_go(r, &"menu")
	assert_eq(_id(r), &"menu")


func test_carter_disreputable_even_day_explains_odd_deliveries() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.set_flag(&"p4_intro")  # Phase 4 told already (test_carter_p4_*)
	GameState.stats[&"reputation"] = 10
	TimeManager.day = 4
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_no_delivery", "'Verrufen' on an even day: no corpse today")
	assert_true(r.current_text().contains("ungeraden Tagen"))
	_go(r, &"rep_odd_days")
	_go(r, &"p3_intro")
	assert_eq(_id(r), &"menu", "no second reputation lecture")
	TimeManager.day = 5
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_rep", "odd day: the corpse came, the gossip stays")
	GameState.stats[&"reputation"] = 15
	TimeManager.day = 6
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "'Unauffällig': deliveries every day")


func test_carter_praise_once_per_tier() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.stats[&"reputation"] = 54
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "'Geachtet': nothing to say")
	GameState.stats[&"reputation"] = 55
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_esteemed", "'Geschätzt'")
	_go(r, &"p3_intro")
	assert_eq(_id(r), &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "said once")
	GameState.stats[&"reputation"] = 80
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_renowned", "'Gerühmt'")
	_go(r, &"p3_intro")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")


func test_carter_renowned_skips_the_lower_praise() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.stats[&"reputation"] = 90
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"remark_renowned")
	_go(r, &"p3_intro")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "no stale 'Geschätzt' praise afterwards")


func test_carter_cemetery_complete_once() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.set_flag(&"cemetery_complete")
	var r := _start_carter(MORNING, _inv())
	assert_eq(_id(r), &"cemetery_done")
	assert_true(r.current_text().begins_with("Zwölf Gräber"))
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	assert_eq(_id(_start_carter(MORNING, _inv())), &"greet_morning", "only once")


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


# --- Phase 4 (P6, docs/PHASE4_DESIGN.md §2.6, §2.7, §2.12, §3.4) ------------------------------

const TRADER_PATH := "res://data/dialogue/trader.tres"
const NIGHT := 1410        # 23:30
const AFTER_MIDNIGHT := 60  # 01:00 – still the same night


## NightTrade double (group night_trade): tools once, talks per call, state like §5.1.
class FakeNightTrade extends Node:
	var tools_given: bool = false
	var room: bool = true
	var talks: int = 0
	var talk_calls: int = 0

	func _init() -> void:
		add_to_group(&"night_trade")

	func give_tools(inv: Inventory) -> bool:
		if tools_given or not room or inv == null:
			return false
		inv.add_item(&"shears", 1)
		inv.add_item(&"pliers", 1)
		tools_given = true
		return true

	func note_talk() -> void:
		talk_calls += 1

	func save_state() -> Dictionary:
		return {"tools_given": tools_given, "talks": talks}


func _trade() -> FakeNightTrade:
	var t := FakeNightTrade.new()
	tree.root.add_child(t)
	return t


func _journal() -> JournalManager:
	var j := JournalManager.new()
	j.clue_data = Phase4Fixtures.clues()
	j.insight_data = Phase4Fixtures.insights()
	j.find_data = Phase4Fixtures.finds()
	tree.root.add_child(j)
	return j


func _trader() -> DialogueData:
	return load(TRADER_PATH) as DialogueData


func _start_trader(minute: int, inv: Inventory, speaker: Node = null) -> DialogueRunner:
	TimeManager.minute_of_day = minute
	var r := DialogueRunner.new()
	r.start(_trader(), {"inventory": inv, "speaker": speaker})
	return r


func _choices_to(r: DialogueRunner, next: StringName) -> int:
	var n := 0
	for c: DialogueChoice in r.available_choices():
		if c.next == next:
			n += 1
	return n


# conditions

func test_stat_conditions_take_negative_numbers() -> void:
	GameState.stats[&"piety"] = -20
	assert_true(_check("stat_lt:piety:-19"))
	assert_true(_check("stat_gte:piety:-20"))
	assert_false(_check("stat_gte:piety:-19"))
	assert_false(_check("stat_lt:piety:-20"))
	GameState.stats[&"piety"] = -100
	assert_true(_check("stat_lt:piety:-59"), "hardhearted range")


func test_piety_tier_condition_follows_the_thresholds() -> void:
	var table := {-100: &"hardhearted", -60: &"hardhearted", -59: &"callous", -20: &"callous", -19: &"matter_of_fact",
			0: &"matter_of_fact", 19: &"matter_of_fact", 20: &"considerate", 59: &"considerate", 60: &"devout", 100: &"devout"}
	for value: int in table:
		GameState.stats[&"piety"] = value
		for tier: StringName in JournalRules.PIETY_TIERS:
			assert_eq(_check("piety_tier:" + String(tier)), tier == table[value], "piety %d → %s?" % [value, tier])
			assert_eq(_check("!piety_tier:" + String(tier)), tier != table[value], "negated")
	assert_eq(JournalRules.piety_tier(0), &"matter_of_fact", "no config → §2.7 defaults")


func test_piety_tier_malformed_is_false() -> void:
	GameState.stats[&"piety"] = 0
	for cond: String in ["piety_tier", "piety_tier:", "piety_tier:gnadenlos", "piety_tier:Sachlich"]:
		assert_false(_check(cond), cond)


func test_clue_known_reads_the_clue_flag() -> void:
	assert_false(_check("clue_known:c_mark"))
	GameState.set_flag(&"clue_c_mark")
	assert_true(_check("clue_known:c_mark"))
	assert_true(_check("!clue_known:c_page_1"))
	assert_false(_check("clue_known:"), "malformed")


func test_flag_night_spans_midnight_and_ends_at_noon() -> void:
	TimeManager.day = 5
	TimeManager.minute_of_day = NIGHT
	_apply("set_flag_night:trader_greeted")
	assert_eq(GameState.get_flag(&"trader_greeted"), 5, "night of day 5")
	assert_true(_check("flag_night:trader_greeted"))
	TimeManager.day = 6
	TimeManager.minute_of_day = AFTER_MIDNIGHT
	assert_true(_check("flag_night:trader_greeted"), "01:00 is still the same night")
	TimeManager.minute_of_day = 719
	assert_true(_check("flag_night:trader_greeted"), "until noon")
	TimeManager.minute_of_day = 720
	assert_false(_check("flag_night:trader_greeted"), "a new night starts at 12:00")
	assert_false(_check("flag_night:nothing"))
	assert_false(_check("flag_night:"), "malformed")


func test_trader_talks_gte_reads_the_night_trade() -> void:
	assert_false(_check("trader_talks_gte:1"), "no night trade → 0 talks")
	assert_true(_check("trader_talks_gte:0"))
	var t := _trade()
	t.talks = 3
	assert_true(_check("trader_talks_gte:3"))
	assert_false(_check("trader_talks_gte:4"))
	assert_true(_check("!trader_talks_gte:4"))
	assert_false(_check("trader_talks_gte:x"), "malformed")


# actions

func test_open_panel_action_requests_the_panel_with_speaker() -> void:
	var got: Array = []
	var cb := func(panel: StringName, ctx: Dictionary) -> void: got.append([panel, ctx])
	EventBus.ui_panel_requested.connect(cb)
	var speaker := Node.new()
	tree.root.add_child(speaker)
	var inv := _inv()
	_apply("open_panel:trader", {"inventory": inv, "speaker": speaker})
	_apply("open_trade", {"speaker": speaker})
	_apply("open_panel:", {"speaker": speaker})
	EventBus.ui_panel_requested.disconnect(cb)
	assert_eq(got.size(), 2, "malformed id ignored")
	assert_eq(got[0][0], &"trader")
	assert_eq((got[0][1] as Dictionary).speaker, speaker)
	assert_eq((got[0][1] as Dictionary).inventory, inv)
	assert_eq(got[1][0], &"trader", "open_trade = open_panel:trader")


func test_add_clue_action_uses_the_journal() -> void:
	_apply("add_clue:c_trader_lorenz")  # no journal: warning only
	assert_false(GameState.has_flag(&"clue_c_trader_lorenz"))
	var j := _journal()
	_apply("add_clue:c_trader_lorenz")
	assert_true(j.has_clue(&"c_trader_lorenz"))
	assert_true(GameState.has_flag(&"clue_c_trader_lorenz"), "flag for dialogue conditions")
	assert_eq(j.unread(), [&"c_trader_lorenz"] as Array[StringName])
	_apply("add_clue:c_nope")
	assert_eq(j.clues().size(), 1, "unknown clue ignored")


func test_trader_tools_action_sets_the_flag_only_when_handed_over() -> void:
	var inv := _inv()
	_apply("trader_tools", _ctx(inv))
	assert_false(GameState.has_flag(&"trader_tools_given"), "no night trade")
	var t := _trade()
	t.room = false
	_apply("trader_tools", _ctx(inv))
	assert_false(GameState.has_flag(&"trader_tools_given"), "full inventory")
	t.room = true
	_apply("trader_tools", _ctx(inv))
	assert_true(GameState.has_flag(&"trader_tools_given"))
	assert_eq([inv.count(&"shears"), inv.count(&"pliers")], [1, 1])
	GameState.clear_flag(&"trader_tools_given")
	_apply("trader_tools", _ctx(inv))
	assert_true(GameState.has_flag(&"trader_tools_given"), "given earlier (state tools_given)")
	assert_eq(inv.count(&"shears"), 1, "only once")


func test_trader_talked_action_notes_the_talk() -> void:
	var t := _trade()
	_apply("trader_talked")
	_apply("trader_talked")
	assert_eq(t.talk_calls, 2, "NightTrade.note_talk counts once per night itself")


# carter (Osric), Phase 4

func _carter_p4_ready() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	GameState.set_flag(&"p4_intro")
	TimeManager.day = 5


func test_carter_p4_intro_on_day_two_and_juniper() -> void:
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"p3_intro")
	var inv := _inv({&"coin": 13})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "day 1: no Phase-4 introduction")
	assert_eq(_choices_to(r, &"shop_juniper"), 0, "no juniper before the introduction")
	TimeManager.day = 2
	r = _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_intro")
	for word: String in ["Kleider, Hände, Wunden, Taschen", "Wacholder"]:
		assert_true(r.current_text().contains(word), word)
	assert_true(GameState.has_flag(&"p4_intro"))
	_go(r, &"p4_intro_prep")
	for word: String in ["Wurzelbürste", "Holzkamm", "Totenhemd", "Werkbank"]:
		assert_true(r.current_text().contains(word), word)
	_go(r, &"shop_juniper")
	_go_action(r, "give_item:juniper:5")
	assert_eq([inv.count(&"coin"), inv.count(&"juniper")], [3, 5])
	_go(r, &"shop_juniper")
	assert_false(_has_action_choice(r, "give_item:juniper:5"), "3 coins left")
	_go_action(r, "give_item:juniper:1")
	assert_eq([inv.count(&"coin"), inv.count(&"juniper")], [1, 6])
	assert_eq(r.available_choices().size(), 1, "1 coin: only 'Danke.'")
	_go(r, &"menu")
	_go(r, &"shop_juniper")
	_go(r, &"shop_juniper_leave")
	_go(r, &"menu")
	r = _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "introduction only once")


func test_carter_piety_remarks_once_per_tier() -> void:
	_carter_p4_ready()
	var expected := {-80: &"p4_piety_hardhearted", -30: &"p4_piety_callous", 30: &"p4_piety_considerate", 70: &"p4_piety_devout"}
	GameState.stats[&"piety"] = 0
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "'Sachlich': as before")
	for value: int in expected:
		GameState.stats[&"piety"] = value
		r = _start_carter(MORNING, _inv())
		_go(r, &"remark_skipped")
		assert_eq(_id(r), expected[value], "piety %d" % value)
		var tier := String(expected[value]).trim_prefix("p4_piety_")
		assert_true(GameState.has_flag(StringName("remark_piety_" + tier)), "flag remark_piety_%s (§5.1)" % tier)
		r = _start_carter(MORNING, _inv())
		_go(r, &"remark_skipped")
		assert_ne(_id(r), expected[value], "only once per tier")


func test_carter_devout_remark_tells_of_lorenz() -> void:
	_carter_p4_ready()
	GameState.stats[&"piety"] = 60
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_piety_devout")
	assert_true(r.current_text().contains("Lorenz") and r.current_text().contains("Danke"))


func test_carter_hardhearted_menu_is_curt() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"remark_piety_hardhearted")
	GameState.stats[&"piety"] = -60
	var inv := _inv({&"coin": 3})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu_cold", "'Hartherzig': kühl, knapp")
	assert_eq(r.current_text(), "Was brauchst du.")
	_go(r, &"shop")
	_go_action(r, "give_item:linen:1")
	assert_eq(inv.count(&"linen"), 1, "he still sells")
	_go(r, &"menu")
	assert_eq(_id(r), &"menu_cold", "every way back to the menu stays curt")
	_go(r, &"goodbye_morning")
	_go(r, &"")
	assert_true(r.is_finished())
	GameState.stats[&"piety"] = -59
	r = _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_piety_callous", "callous is not curt, only pointed")


func test_carter_rumor_once() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"trader_rumor")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_rumor")
	assert_true(r.current_text().begins_with("Man sagt, nachts steht eine Frau mit einer Kiepe an deiner Mauer. Ich hab nichts gesagt."))
	_go(r, &"p4_rumor_more")
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "once")


func test_carter_elder_key_moment_then_six_pits() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"has_elder_key")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_elder_key")
	for word: String in ["Holunder", "Pförtchen", "Lorenz"]:
		assert_true(r.current_text().contains(word), word)
	_go(r, &"p4_elder_key_more")
	_go(r, &"menu")
	_go(r, &"hint_alive")
	assert_eq(_id(r), &"hint_elder", "hint: unlock the gate")
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "key moment once")
	GameState.set_flag(&"clue_c_six_pits")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_six_pits")
	assert_true(r.current_text().contains("Sechs"))
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "six pits once")


func test_carter_elder_key_skipped_when_the_pits_are_known() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"has_elder_key")
	GameState.set_flag(&"clue_c_six_pits")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_six_pits", "no key moment after the section was opened")


func test_carter_insight_reactions_in_order_once_each() -> void:
	_carter_p4_ready()
	for flag: StringName in [&"insight_warnings", &"insight_ferry", &"insight_not_lorenz", &"six_pits_complete"]:
		GameState.set_flag(flag)
	var order: Array[StringName] = []
	for i: int in 5:
		var r := _start_carter(MORNING, _inv())
		_go(r, &"remark_skipped")
		order.append(_id(r))
	assert_eq(order, [&"p4_warnings", &"p4_ferry", &"p4_not_lorenz", &"p4_chapter", &"menu"] as Array[StringName])


func test_carter_not_lorenz_reaction() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"insight_not_lorenz")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p4_not_lorenz")
	assert_true(r.current_text().contains("Kaspar Dorn"))
	_go(r, &"p4_not_lorenz_more")
	_go(r, &"menu")
	_go(r, &"hint_alive")
	assert_eq(_id(r), &"hint_alive")
	assert_true(r.current_text().contains("Birkenhang"), "points to Phase 12, reveals nothing")


func test_carter_story_hints_follow_the_journal() -> void:
	_carter_p4_ready()
	var expect := [[&"", &"hint_default"], [&"clue_c_mark", &"hint_mark"], [&"clue_c_anchor_snake", &"hint_ferry"],
			[&"clue_c_page_list", &"hint_list"]]
	for step: Array in expect:
		if step[0] != &"":
			GameState.set_flag(step[0])
		var r := _start_carter(MORNING, _inv())
		_go(r, &"remark_skipped")
		_go(r, &"hint_alive")
		assert_eq(_id(r), step[1], "after %s" % step[0])
		_go(r, &"menu")
		assert_eq(_id(r), &"menu")


# trader (Ilse Kranich)

func test_trader_identity() -> void:
	var d := _trader()
	assert_not_null(d, TRADER_PATH)
	assert_eq(d.id, &"trader")
	assert_eq(d.speaker_name, "Ilse Kranich")
	assert_eq(Database.dialogue(&"trader"), d, "registered in Database by id")
	var spot := ScheduleResolver.entry_at(Phase4Fixtures.trader_schedule(), NIGHT)
	assert_eq(spot.dialogue_id, d.id, "the schedule entry at the wall opens this dialogue")


func test_trader_node_ids_unique_targets_exist_all_reachable() -> void:
	var d := _trader()
	var ids: Dictionary[StringName, bool] = {}
	for n: DialogueNode in d.nodes:
		assert_false(ids.has(n.id), "duplicate %s" % n.id)
		ids[n.id] = true
	var seen: Dictionary[StringName, bool] = {d.start_node: true}
	var queue: Array[StringName] = [d.start_node]
	while not queue.is_empty():
		var n := d.get_node_by_id(queue.pop_front())
		var targets: Array[StringName] = [n.fallback_next]
		for c: DialogueChoice in n.choices:
			targets.append(c.next)
		for t: StringName in targets:
			if t == &"":
				continue
			assert_true(ids.has(t), "%s → %s" % [n.id, t])
			if not seen.has(t):
				seen[t] = true
				queue.append(t)
	for n: DialogueNode in d.nodes:
		assert_true(seen.has(n.id), "node %s unreachable" % n.id)


func test_trader_no_dead_ends() -> void:
	# Only the goodbye and the trade (open_panel) end the dialogue; every node offers a way on,
	# and the goodbye is reachable from everywhere along unconditional choices / fallbacks.
	var d := _trader()
	for n: DialogueNode in d.nodes:
		var unconditional := 0
		for c: DialogueChoice in n.choices:
			if c.conditions.is_empty():
				unconditional += 1
			if c.next == &"":
				assert_true(n.id == &"goodbye" or "open_panel:trader" in c.actions, "%s: '%s' ends the dialogue" % [n.id, c.text])
		assert_true(unconditional >= 1, "%s always offers a choice" % n.id)
		if not n.conditions.is_empty():
			assert_ne(n.fallback_next, &"", "conditional %s needs a fallback" % n.id)
		var found := false
		var seen: Dictionary[StringName, bool] = {n.id: true}
		var queue: Array[StringName] = [n.id]
		while not queue.is_empty() and not found:
			var m := d.get_node_by_id(queue.pop_front())
			if m.id == &"goodbye":
				found = true
				break
			var targets: Array[StringName] = [m.fallback_next]
			for c: DialogueChoice in m.choices:
				if c.conditions.is_empty():
					targets.append(c.next)
			for t: StringName in targets:
				if t != &"" and not seen.has(t):
					seen[t] = true
					queue.append(t)
		assert_true(found, "no way out from %s" % n.id)


func test_trader_conditions_actions_and_texts() -> void:
	var d := _trader()
	var cond_re := RegEx.create_from_string(CONDITION_GRAMMAR)
	var action_re := RegEx.create_from_string(ACTION_GRAMMAR)
	var all_text := ""
	for n: DialogueNode in d.nodes:
		assert_true(n.text.strip_edges().length() > 0, "text of %s" % n.id)
		all_text += n.text + " "
		var conditions: Array[String] = n.conditions.duplicate()
		var actions: Array[String] = n.actions.duplicate()
		for c: DialogueChoice in n.choices:
			assert_true(c.text.strip_edges().length() > 0, "choice text in %s" % n.id)
			conditions.append_array(c.conditions)
			actions.append_array(c.actions)
		for cond: String in conditions:
			assert_not_null(cond_re.search(cond), "condition '%s'" % cond)
		for action: String in actions:
			assert_not_null(action_re.search(action), "action '%s'" % action)
			if action.begins_with("add_clue:"):
				var clue := StringName(action.get_slice(":", 1))
				assert_true(Phase4Fixtures.CLUE_IDS.has(clue) or Phase7Fixtures.CLUE_IDS.has(clue), action)
	assert_true(all_text.contains("Stillen"), "she calls the dead 'die Stillen'")
	assert_true(all_text.contains("feilsche nicht"), "she never haggles")


func test_trader_first_meeting_gives_the_tools() -> void:
	var t := _trade()
	var inv := _inv()
	TimeManager.day = 4
	var r := _start_trader(NIGHT, inv)
	assert_eq(_id(r), &"first_meet")
	assert_true(r.current_text().contains("Ilse Kranich"))
	assert_true(GameState.has_flag(&"trader_met"))
	assert_eq(t.talk_calls, 1, "a talk counts")
	_go(r, &"first_note")
	assert_true(r.current_text().contains("Die Stillen"))
	_go(r, &"first_gift")
	assert_eq(_id(r), &"first_gift")
	assert_eq([inv.count(&"shears"), inv.count(&"pliers")], [1, 1], "Schere und Zange")
	assert_true(r.current_text().contains("Schere") and r.current_text().contains("Zange"))
	_go(r, &"menu")
	_go(r, &"goodbye")
	_go(r, &"")
	assert_true(r.is_finished())
	TimeManager.day = 5
	r = _start_trader(AFTER_MIDNIGHT, inv)
	assert_eq(_id(r), &"menu", "same night after midnight: no second greeting")
	r = _start_trader(NIGHT, inv)
	assert_eq(_id(r), &"greet_matter_of_fact", "next night: greeting again")
	assert_eq(inv.count(&"shears"), 1, "tools only once")


func test_trader_full_inventory_keeps_the_gift_for_later() -> void:
	var t := _trade()
	t.room = false
	var inv := _inv()
	var r := _start_trader(NIGHT, inv)
	_go(r, &"first_note")
	_go(r, &"first_gift")
	assert_eq(_id(r), &"first_gift_full")
	assert_true(r.current_text().contains("Komm wieder, wenn du Platz hast."))
	_go(r, &"menu")
	TimeManager.day += 1
	r = _start_trader(NIGHT, inv)
	assert_eq(_id(r), &"gift_retry")
	_go(r, &"menu")
	t.room = true
	r = _start_trader(NIGHT, inv)
	assert_eq(_id(r), &"gift_retry", "offered until handed over")
	_go(r, &"first_gift")
	assert_eq(_id(r), &"first_gift")
	assert_eq(inv.count(&"pliers"), 1)
	r = _start_trader(NIGHT, inv)
	assert_eq(_id(r), &"menu", "greeted tonight already")


func test_trader_greeting_per_piety_tier() -> void:
	_trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	var lines := {
		-80: [&"greet_hardhearted", "Du hast gelernt, nicht hinzusehen. Ich hab's dir nicht beigebracht."],
		-30: [&"greet_callous", "Du bist schneller geworden. Das geht vielen so."],
		0: [&"greet_matter_of_fact", "Guten Abend, Totengräber. Was bringen die Stillen heute?"],
		30: [&"greet_considerate", "Nur zum Reden? Auch gut. Die Nacht ist lang."],
		80: [&"greet_devout", "Du kommst mit leeren Händen. Das steht dir."],
	}
	var day := 4
	for value: int in lines:
		day += 1
		TimeManager.day = day
		GameState.stats[&"piety"] = value
		var r := _start_trader(NIGHT, _inv())
		assert_eq(_id(r), lines[value][0], "piety %d" % value)
		assert_eq(r.current_text(), lines[value][1])
		assert_eq(GameState.get_flag(&"trader_greeted"), day, "once per night")


func test_trader_menu_questions_locked_and_free() -> void:
	var t := _trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	var r := _start_trader(NIGHT, _inv())
	var texts: Array[String] = []
	for c: DialogueChoice in r.available_choices():
		texts.append(c.text)
	assert_eq(texts, ["Handeln.", "Wer bist du, Ilse?", "Gute Nacht, Ilse."] as Array[String], "Lorenz / mark locked")
	t.talks = 3
	r = _start_trader(NIGHT, _inv())
	assert_eq(_choices_to(r, &"ask_lorenz"), 1, "3 nights talked: the Lorenz question (once)")
	t.talks = 2
	GameState.stats[&"trader_sales"] = 4
	r = _start_trader(NIGHT, _inv())
	assert_eq(_choices_to(r, &"ask_lorenz"), 1, "or 4 sales (once)")
	GameState.stats[&"trader_sales"] = 3
	r = _start_trader(NIGHT, _inv())
	assert_eq(_choices_to(r, &"ask_lorenz"), 0, "2 talks + 3 sales: not yet")
	GameState.set_flag(&"clue_c_mark")
	r = _start_trader(NIGHT, _inv())
	assert_eq(_choices_to(r, &"ask_marked"), 1, "with c_mark")


func test_trader_lorenz_and_mark_answers_add_clues() -> void:
	var t := _trade()
	var j := _journal()
	t.talks = 3
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	GameState.set_flag(&"clue_c_mark")
	var r := _start_trader(NIGHT, _inv())
	_go(r, &"ask_lorenz")
	assert_eq(r.current_text(), Phase4Fixtures.clue(&"c_trader_lorenz").text, "answer = clue text (§2.6)")
	assert_true(j.has_clue(&"c_trader_lorenz"))
	assert_eq(_choices_to(r, &"lorenz_alive"), 0, "not before Nicht Lorenz")
	_go(r, &"ask_lorenz_more")
	_go(r, &"menu")
	_go(r, &"ask_marked")
	assert_eq(r.current_text(), Phase4Fixtures.clue(&"c_trader_marked").text)
	assert_true(j.has_clue(&"c_trader_marked"))
	_go(r, &"ask_marked_more")
	_go(r, &"menu")
	GameState.set_flag(&"insight_not_lorenz")
	_go(r, &"ask_lorenz")
	_go(r, &"lorenz_alive")
	assert_true(r.current_text().contains("Wenn er lebt, dann weiß er, warum er nicht zurückkommt. Stör ihn nicht beim Graben."))
	assert_eq(j.clue_count(&"c_trader_lorenz"), 0, "a talk clue counts no dead")
	assert_eq(j.clues().size(), 2, "asking twice adds nothing")


func test_trader_trade_opens_the_panel_and_ends() -> void:
	_trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	var got: Array = []
	var cb := func(panel: StringName, ctx: Dictionary) -> void: got.append([panel, ctx])
	EventBus.ui_panel_requested.connect(cb)
	var speaker := Node.new()
	tree.root.add_child(speaker)
	var r := _start_trader(NIGHT, _inv(), speaker)
	_go_action(r, "open_panel:trader")
	EventBus.ui_panel_requested.disconnect(cb)
	assert_true(r.is_finished(), "the dialogue ends, the panel takes over")
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], &"trader")
	assert_eq((got[0][1] as Dictionary).speaker, speaker)


func test_trader_blossom_after_kranich_insight() -> void:
	_trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	var r := _start_trader(NIGHT, _inv())
	assert_eq(_choices_to(r, &"ask_blossom"), 0)
	GameState.set_flag(&"insight_kranich")
	r = _start_trader(NIGHT, _inv())
	_go(r, &"ask_blossom")
	assert_true(r.current_text().contains("Holunderblüte"))
	_go(r, &"ask_blossom_more")
	assert_false(r.current_text().contains("Lorenz"), "she names no names")
	_go(r, &"menu")
	_go(r, &"who")
	_go(r, &"who_goods")
	_go(r, &"menu")
	_go(r, &"who")
	_go(r, &"who_night")
	_go(r, &"menu")
	_go(r, &"goodbye")
	_go(r, &"")
	assert_true(r.is_finished())


# --- Phase 5 (P6): Osric's quarry license, pickaxe, steel · Ilse's gold leaf · coins_spent ------
# docs/PHASE5_DESIGN.md §2.6, §3.3, §3.4, §14.4.

## Speaker double with an npc_id (Npc has more setup than a dialogue test needs).
class SpeakerDouble extends Node:
	var npc_id: StringName = &""


var spent: Array = []


func _on_spent(amount: int, reason: StringName) -> void:
	spent.append([amount, reason])


func _watch_spent() -> void:
	spent.clear()
	if not EventBus.coins_spent.is_connected(_on_spent):
		EventBus.coins_spent.connect(_on_spent)


func _unwatch_spent() -> void:
	if EventBus.coins_spent.is_connected(_on_spent):
		EventBus.coins_spent.disconnect(_on_spent)


func _carter_p5_ready() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"workshop_open", true)


func _p5_nodes(data: DialogueData) -> Array[DialogueNode]:
	var out: Array[DialogueNode] = []
	for n: DialogueNode in data.nodes:
		if String(n.id).begins_with("p5_"):
			out.append(n)
	return out


func test_carter_p5_intro_once_from_workshop_open() -> void:
	_carter_p4_ready()
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "no Phase-5 introduction before workshop_open")
	assert_eq(_choices_to(r, &"p5_license") + _choices_to(r, &"p5_shop"), 0, "no Phase-5 goods before the introduction")
	GameState.set_flag(&"workshop_open", true)
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p5_intro")
	var text := r.current_text()
	for word: String in ["Bruch", "Ostwiese", "Lorenz' alter Werkplatz", "zwanzig Münzen", "Lehmkuhle"]:
		assert_true(text.contains(word), word)
	assert_eq(text.count("Lorenz"), 1, "§14.4: exactly one reference to Lorenz")
	assert_true(GameState.has_flag(&"p5_intro"))
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "introduction only once")
	assert_eq(_choices_to(r, &"p5_license"), 1, "the license stays in the menu")
	assert_eq(_choices_to(r, &"p5_shop"), 1)


func test_carter_p5_adds_no_clue_or_insight() -> void:
	# §14.4: the workplace is one sentence, no new hint in the journal.
	for n: DialogueNode in _p5_nodes(_carter()):
		for a: String in n.actions:
			assert_false(a.begins_with("add_clue"), "%s: %s" % [n.id, a])
		for c: DialogueChoice in n.choices:
			for a: String in c.actions:
				assert_false(a.begins_with("add_clue"), "%s: %s" % [n.id, a])
	assert_eq(_p5_nodes(_carter()).size(), 9)


func test_carter_license_once_for_twenty() -> void:
	_carter_p5_ready()
	_watch_spent()
	var inv := _inv({&"coin": 25})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"p5_license")
	assert_true(r.current_text().contains("Zwanzig Münzen"))
	_go_action(r, "take_item:coin:20:license")
	assert_eq(_id(r), &"p5_license_bought")
	assert_eq(inv.count(&"coin"), 5)
	assert_eq(GameState.get_flag(&"bruch_license"), true)
	assert_eq(spent, [[20, &"license"]])
	assert_eq([GameState.get_stat(&"coins_spent"), GameState.coin_ledger()[&"license"]], [20, 20])
	_go(r, &"menu")
	assert_eq(_choices_to(r, &"p5_license"), 0, "bought once")
	_go(r, &"p5_shop")
	assert_eq(_id(r), &"p5_shop")
	# A second visit to the license node (e.g. from the intro) only says it is sold.
	r = DialogueRunner.new()
	r.start(_carter(), _ctx(inv))
	r._enter(&"p5_license")
	assert_eq(_id(r), &"p5_license_owned")
	_unwatch_spent()


func test_carter_license_too_expensive() -> void:
	_carter_p5_ready()
	_watch_spent()
	var inv := _inv({&"coin": 19})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"p5_license")
	assert_false(_has_action_choice(r, "take_item:coin:20:license"), "19 coins")
	_go(r, &"p5_license_poor")
	_go(r, &"menu")
	assert_false(GameState.has_flag(&"bruch_license"))
	assert_eq([inv.count(&"coin"), spent], [19, []])
	_unwatch_spent()


func test_carter_pickaxe_once_steel_and_fittings() -> void:
	_carter_p5_ready()
	GameState.set_flag(&"p5_intro")
	_watch_spent()
	var inv := _inv({&"coin": 50})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu")
	_go(r, &"p5_shop")
	_go_action(r, "give_item:pickaxe_iron:1")
	assert_eq(_id(r), &"p5_shop_pickaxe")
	assert_true(r.current_text().contains("Die Spitze ist stumpf, aber ehrlich."))
	assert_eq([inv.count(&"coin"), inv.count(&"pickaxe_iron")], [36, 1])
	assert_eq(GameState.get_flag(&"bought_pickaxe"), true)
	_go(r, &"p5_shop")
	assert_false(_has_action_choice(r, "give_item:pickaxe_iron:1"), "the pickaxe only once")
	_go_action(r, "give_item:steel_rod:1")
	assert_eq(_id(r), &"p5_shop_steel")
	assert_true(r.current_text().contains("Frag nicht, was der Schmied in Hollerbrück dafür nimmt."))
	_go(r, &"p5_shop")
	_go_action(r, "give_item:steel_rod:1")
	_go(r, &"p5_shop")
	_go_action(r, "give_item:iron_fittings:4")
	assert_eq([inv.count(&"coin"), inv.count(&"steel_rod"), inv.count(&"iron_fittings")], [12, 2, 4])
	_go(r, &"p5_shop")
	_go_action(r, "give_item:iron_fittings:2")
	assert_eq([inv.count(&"coin"), inv.count(&"iron_fittings")], [6, 6])
	assert_eq(spent, [[14, &"osric"], [6, &"osric"], [6, &"osric"], [12, &"osric"], [6, &"osric"]])
	assert_eq(GameState.coin_ledger(), {&"license": 0, &"build": 0, &"osric": 44, &"ilse": 0, &"building": 0, &"village": 0, &"donation": 0, &"round": 0, &"consecration": 0, &"apprentice": 0, &"alms": 0, &"peddler": 0} as Dictionary[StringName, int])
	_go(r, &"p5_shop")
	assert_true(_has_action_choice(r, "give_item:steel_rod:1"), "6 coins: steel is repeatable")
	assert_false(_has_action_choice(r, "give_item:iron_fittings:4"))
	_unwatch_spent()


func test_carter_p5_prices_match_the_contract() -> void:
	# §2.6: license 20, pickaxe 14, steel rod 6, iron fittings 3 each.
	var prices := {"pickaxe_iron": [14, 1], "steel_rod": [6, 1], "iron_fittings": [3, 1]}
	for n: DialogueNode in _p5_nodes(_carter()):
		for c: DialogueChoice in n.choices:
			var coins := -1
			var item := ""
			var amount := 0
			for a: String in c.actions:
				var p := a.split(":")
				if p[0] == "take_item" and p[1] == "coin":
					coins = int(p[2])
				elif p[0] == "give_item":
					item = p[1]
					amount = int(p[2])
			if coins < 0:
				continue
			if "take_item:coin:20:license" in c.actions:
				assert_eq(coins, 20, "license")
				continue
			assert_true(prices.has(item), "%s sells a contract item (%s)" % [n.id, item])
			if prices.has(item):
				assert_eq(coins, prices[item][0] * amount, "%s × %d" % [item, amount])
			assert_true(c.text.contains("(%d Münzen)" % coins), c.text)
			assert_true(c.conditions.has("has_item:coin:%d" % coins), "%s: affordable only" % c.text)


func test_coin_reason_from_speaker_and_argument() -> void:
	_watch_spent()
	var inv := _inv({&"coin": 30})
	var ilse := SpeakerDouble.new()
	ilse.npc_id = &"trader"
	var osric := SpeakerDouble.new()
	osric.npc_id = &"carter"
	_apply("take_item:coin:2", {"inventory": inv, "speaker": ilse})
	_apply("take_item:coin:3", {"inventory": inv, "speaker": osric})
	_apply("take_item:coin:4", _ctx(inv))
	_apply("take_item:coin:5:build", {"inventory": inv, "speaker": osric})
	_apply("take_item:coin:99", _ctx(inv))
	inv.add_item(&"linen", 2)
	_apply("take_item:linen:1", _ctx(inv))
	assert_eq(spent, [[2, &"ilse"], [3, &"osric"], [4, &"osric"], [5, &"build"]], "refused and non-coin takes are no payment")
	assert_eq([inv.count(&"coin"), inv.count(&"linen"), GameState.get_stat(&"coins_spent")], [16, 1, 14])
	assert_eq(DialogueActions.coin_reason({}), &"osric")
	ilse.free()
	osric.free()
	_unwatch_spent()


func test_carter_linen_purchase_counts_as_osric() -> void:
	_carter_p4_ready()
	_watch_spent()
	var inv := _inv({&"coin": 10})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"shop")
	_go_action(r, "give_item:linen:2")
	assert_eq(spent, [[6, &"osric"]])
	_unwatch_spent()


func test_trader_gold_leaf_remark_once() -> void:
	_trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"trader_tools_given")
	var r := _start_trader(NIGHT, _inv())
	assert_ne(_id(r), &"p5_gold", "not before workshop_open")
	GameState.set_flag(&"workshop_open", true)
	TimeManager.day += 1
	r = _start_trader(NIGHT, _inv())
	assert_eq(_id(r), &"p5_gold")
	assert_true(r.current_text().contains("Aus dem Nachlass eines Vergolders. Er hätte gewollt, dass es glänzt."))
	assert_eq(GameState.get_flag(&"remark_gold"), true)
	assert_eq(GameState.get_flag(&"trader_greeted"), TimeManager.day, "counts as tonight's greeting")
	assert_true(_has_action_choice(r, "open_panel:trader"))
	_go(r, &"p5_gold_price")
	assert_true(r.current_text().contains("Sechs Münzen") and r.current_text().contains("zwei in jeder Nacht"))
	_go(r, &"menu")
	TimeManager.day += 1
	r = _start_trader(NIGHT, _inv())
	assert_ne(_id(r), &"p5_gold", "only once")
	assert_eq(String(_id(r)).begins_with("greet_"), true)


func test_trader_gold_leaf_waits_for_the_tools() -> void:
	_trade()
	GameState.set_flag(&"trader_met")
	GameState.set_flag(&"workshop_open", true)
	var r := _start_trader(NIGHT, _inv())
	assert_eq(_id(r), &"gift_retry", "the tools first")
	assert_false(GameState.has_flag(&"remark_gold"))


# --- Phase 6 (P6): Osric – p6_intro, altar candles, the buildings (docs/PHASE6_DESIGN.md §1.2, §2.6) ---

func _carter_p6_ready() -> void:
	_carter_p5_ready()
	GameState.set_flag(&"p5_intro")
	GameState.set_flag(&"names_in_stone_complete")


func _p6_nodes(data: DialogueData) -> Array[DialogueNode]:
	var out: Array[DialogueNode] = []
	for n: DialogueNode in data.nodes:
		if String(n.id).begins_with("p6_"):
			out.append(n)
	return out


func test_carter_p6_intro_once_from_buildings_open() -> void:
	_carter_p6_ready()
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "no Phase-6 introduction before buildings_open (names_in_stone alone is not enough)")
	assert_eq(_choices_to(r, &"p6_candles") + _choices_to(r, &"p6_buildings"), 0, "§1.2: no candles, no hint before buildings_open")
	GameState.set_flag(&"buildings_open")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p6_intro")
	var text := r.current_text()
	# 04.10.2026 (Gruft von Beginn an): the council lets the gravekeeper extend his crypt under the oak.
	for word: String in ["Gemeinderat", "Gruft unter der Eiche", "Ausbauen", "Gruft", "Kapelle", "Beinhaus", "Vier Münzen"]:
		assert_true(text.contains(word), word)
	assert_true(GameState.has_flag(&"p6_intro"))
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu", "introduction only once")
	assert_eq(_choices_to(r, &"p6_candles"), 1, "candles in the menu")
	assert_eq(_choices_to(r, &"p6_buildings"), 1, "the building hint in the menu")


func test_carter_p6_intro_comes_after_p5_intro() -> void:
	# A migrated Phase-5 end state: both remarks pending → one per conversation, p5 first.
	_carter_p4_ready()
	GameState.set_flag(&"workshop_open", true)
	GameState.set_flag(&"buildings_open")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p5_intro")
	_go(r, &"menu")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p6_intro", "the next conversation")
	assert_eq(_carter().get_node_by_id(&"p6_intro").fallback_next, &"p7_intro", "Phase 7: p7_intro next")
	# Phase 8 (P6): p7_intro → p8_intro → p8_robber_seen → p8_robber_seen_b → p8_lights → p4_rumor.
	var next := _carter().get_node_by_id(&"p7_intro").fallback_next
	var chain: Array[StringName] = []
	while String(next).begins_with("p8_"):
		chain.append(next)
		next = _carter().get_node_by_id(next).fallback_next
	assert_eq(chain, [&"p8_intro", &"p8_robber_seen", &"p8_robber_seen_b", &"p8_lights"] as Array[StringName], "Phase 8 in between")
	assert_eq(next, &"p4_rumor", "the chain continues as before")


func test_carter_altar_candles_two_coins_each() -> void:
	_carter_p6_ready()
	GameState.set_flag(&"buildings_open")
	GameState.set_flag(&"p6_intro")
	_watch_spent()
	var inv := _inv({&"coin": 9})
	var r := _start_carter(MORNING, inv)
	_go(r, &"remark_skipped")
	_go(r, &"p6_candles")
	assert_true(r.current_text().contains("zwei Münzen das Stück"), "§2.6 text")
	assert_true(r.current_text().contains("so lange wie ein Gebet"))
	_go_action(r, "give_item:altar_candle:1")
	assert_eq(_id(r), &"p6_candles_bought")
	assert_eq([inv.count(&"coin"), inv.count(&"altar_candle")], [7, 1])
	_go(r, &"p6_candles")
	_go_action(r, "give_item:altar_candle:3")
	assert_eq([inv.count(&"coin"), inv.count(&"altar_candle")], [1, 4])
	assert_eq(spent, [[2, &"osric"], [6, &"osric"]], "§2.6: candles run under osric")
	assert_eq(GameState.coin_ledger()[&"osric"], 8)
	assert_eq(_choices_to(r, &"p6_candles"), 0, "1 coin left: no more candles")
	_go(r, &"menu")
	_go(r, &"p6_candles")
	assert_false(_has_action_choice(r, "give_item:altar_candle:1"), "affordable only")
	_unwatch_spent()


func test_carter_p6_buildings_hint_and_old_graves() -> void:
	_carter_p6_ready()
	GameState.set_flag(&"buildings_open")
	GameState.set_flag(&"p6_intro")
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	_go(r, &"p6_buildings")
	var text := r.current_text()
	for word: String in ["Gruft", "Kapelle", "Schuppen", "Hollerbrück"]:
		assert_true(text.contains(word), word)
	_go(r, &"p6_old_graves")
	assert_true(r.current_text().contains("Beinhaus"))
	assert_true(r.current_text().contains("zwei frischen Hügel"), "§2.3: the rest period of old_01 / old_08")
	_go(r, &"menu")
	assert_eq(_id(r), &"menu")


func test_carter_p6_in_the_cold_menu_too() -> void:
	_carter_p6_ready()
	GameState.set_flag(&"buildings_open")
	GameState.set_flag(&"p6_intro")
	GameState.stats[&"piety"] = -100
	GameState.set_flag(&"remark_piety_hardhearted")
	var r := _start_carter(MORNING, _inv({&"coin": 2}))
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"menu_cold")
	assert_eq(_choices_to(r, &"p6_candles"), 1)
	assert_eq(_choices_to(r, &"p6_buildings"), 1)


func test_carter_p6_nodes_add_no_clue_and_prices_match() -> void:
	var nodes := _p6_nodes(_carter())
	assert_eq(nodes.size(), 5, "p6_intro, p6_buildings, p6_old_graves, p6_candles, p6_candles_bought")
	var offers := 0
	for n: DialogueNode in nodes:
		for a: String in n.actions:
			assert_false(a.begins_with("add_clue"), "%s: %s" % [n.id, a])
		for c: DialogueChoice in n.choices:
			for a: String in c.actions:
				assert_false(a.begins_with("add_clue"), "%s: %s" % [n.id, a])
				if a.begins_with("take_item:coin:"):
					offers += 1
					var coins := int(a.get_slice(":", 2))
					var candles := 0
					for b: String in c.actions:
						if b.begins_with("give_item:altar_candle:"):
							candles = int(b.get_slice(":", 2))
					assert_eq(coins, 2 * candles, "§2.6: 2 coins per candle (%s)" % c.text)
					assert_eq(a.get_slice(":", 3), "osric", "coins_spent(osric)")
	assert_eq(offers, 2)


# --- Phase 7 (P6, docs/PHASE7_DESIGN.md §1.2, §2.1, §2.4, §2.12, §3.4, §10) -------------------------

const V_DIALOGUES: PackedStringArray = ["v_innkeeper", "v_smith", "v_grocer", "v_priest", "v_mayor", "v_surgeon", "v_washer",
		"v_oldwoman", "carter_village", "priest_linden"]
const P7_FLAGS: Array[StringName] = [&"village_open", &"p7_intro", &"anatomy_known", &"anatomy_declined", &"anatomy_asked_again",
		&"quast_recipes", &"lecture_invited", &"hagedorn_dead", &"linden_granted", &"linden_consecration_day",
		&"linden_consecrated", &"remark_ilse_specimen", &"liesel_hagedorn_told", &"clue_c_v_three_visitors",
		&"clue_c_v_deathbook", &"village_open_day"]


class P7Rel extends Relationships:
	var vals: Dictionary = {}
	var fake_met: Array = []
	var calls: Array = []

	func value(npc_id: StringName) -> int:
		return int(vals.get(npc_id, 0))

	func met(npc_id: StringName) -> bool:
		return fake_met.has(npc_id)

	func meet(npc_id: StringName) -> void:
		calls.append(["meet", npc_id])
		if not fake_met.has(npc_id):
			fake_met.append(npc_id)

	func note_talk(npc_id: StringName) -> void:
		calls.append(["talk", npc_id])

	func add(npc_id: StringName, delta: int, reason: String) -> int:
		calls.append(["add", npc_id, delta, reason])
		vals[npc_id] = value(npc_id) + delta
		return value(npc_id)


class P7Journal extends Node:
	var clues: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		clues.append(id)
		GameState.set_flag(StringName("clue_" + String(id)), true)
		return true


func _p7_clear() -> void:
	for f: StringName in P7_FLAGS:
		GameState.clear_flag(f)


func _v(id: String) -> DialogueData:
	return load("res://data/dialogue/%s.tres" % id) as DialogueData


func _p7_world(rel_values: Dictionary = {}, met: Array = []) -> P7Rel:
	_p7_clear()
	var rel := P7Rel.new()
	rel.vals = rel_values.duplicate()
	rel.fake_met = met.duplicate()
	tree.root.add_child(rel)
	return rel


func test_phase7_dialogues_are_well_formed() -> void:
	var cond_re := RegEx.create_from_string(CONDITION_GRAMMAR)
	var action_re := RegEx.create_from_string(ACTION_GRAMMAR)
	for id: String in V_DIALOGUES:
		var d := _v(id)
		assert_not_null(d, id)
		if d == null:
			continue
		assert_eq(String(d.id), id)
		var ids := {}
		for n: DialogueNode in d.nodes:
			assert_false(ids.has(n.id), "%s: unique %s" % [id, n.id])
			ids[n.id] = true
		assert_true(ids.has(d.start_node), id + " start")
		for n: DialogueNode in d.nodes:
			assert_true(n.text.strip_edges().length() > 0, "%s.%s text" % [id, n.id])
			assert_true(n.fallback_next == &"" or ids.has(n.fallback_next), "%s.%s fallback" % [id, n.id])
			var conds: Array[String] = n.conditions.duplicate()
			var acts: Array[String] = n.actions.duplicate()
			for c: DialogueChoice in n.choices:
				assert_true(c.next == &"" or ids.has(c.next), "%s.%s → %s" % [id, n.id, c.next])
				conds.append_array(c.conditions)
				acts.append_array(c.actions)
			for c: String in conds:
				assert_not_null(cond_re.search(c), "%s: condition '%s'" % [id, c])
			for a: String in acts:
				assert_not_null(action_re.search(a), "%s: action '%s'" % [id, a])
	# Every villager offers each of their personal orders, and every recipient takes its deliveries.
	for o: OrderData in Phase7Fixtures.orders():
		if o.board and o.kind != &"deliver":
			continue
		if not o.board:
			assert_true(_dialogue_has(_v("v_" + String(o.giver)), "order_offerable:" + String(o.id)), "%s offered by %s" % [o.id, o.giver])
		if o.kind == &"deliver" or o.kind == &"donate":
			var who := o.recipient if o.recipient != &"" else o.giver
			assert_true(_dialogue_has(_v("v_" + String(who)), "order_turn_in:" + String(o.id)), "%s handed to %s" % [o.id, who])


func _dialogue_has(d: DialogueData, entry: String) -> bool:
	for n: DialogueNode in d.nodes:
		for c: DialogueChoice in n.choices:
			if entry in c.conditions or entry in c.actions:
				return true
	return false


func test_phase7_voices_have_their_marks() -> void:
	var text := {}
	for id: String in V_DIALOGUES:
		var all := ""
		for n: DialogueNode in _v(id).nodes:
			all += n.text + " "
		text[id] = all
	assert_true(String(text.v_innkeeper).contains("Wackernagel"), "Rosine calls herself by her surname")
	assert_true(String(text.v_grocer).contains("Buntes"), "Theres: Buntes")
	assert_true(String(text.v_surgeon).contains("Die Toten lehren die Lebenden."), "Quast's saying")
	assert_true(String(text.v_priest).contains("nach Süden"), "Lenz evades: nach Süden")
	assert_true(String(text.v_mayor).contains("Ich zähle"), "Fenner counts aloud")
	assert_true(String(text.v_oldwoman).contains("Linde"), "Wiebke wants the linden")
	assert_true(String(text.priest_linden).contains("Ich segne die Erde, nicht die Arbeit."), "§2.9 leading line")
	for id: String in ["v_innkeeper", "v_smith", "v_grocer", "v_priest", "v_mayor", "v_surgeon", "v_washer", "v_oldwoman"]:
		var greets := 0
		for n: DialogueNode in _v(id).nodes:
			if String(n.id).begins_with("greet_") and not String(n.id).begins_with("greet_p_"):
				greets += 1
		assert_eq(greets, 5, "%s: five greetings by reputation tier (§2.4)" % id)
	for id: String in ["v_priest", "v_washer", "v_surgeon"]:
		assert_true(_v(id).get_node_by_id(&"greet_p_devout") != null and _v(id).get_node_by_id(&"greet_p_hardhearted") != null,
				id + ": piety greetings")


func test_phase7_conditions() -> void:
	var rel := _p7_world({&"priest": 45, &"washer": 10}, [&"priest"])
	assert_true(_check("rel_gte:priest:45"))
	assert_false(_check("rel_gte:priest:46"))
	assert_true(_check("rel_tier:priest:trusted"))
	assert_true(_check("rel_tier:priest:acquainted"), "at least")
	assert_false(_check("rel_tier:priest:friend"))
	assert_true(_check("met:priest"))
	assert_false(_check("met:washer"))
	GameState.stats[&"reputation"] = 50
	assert_true(_check("rep_tier:respected") or _check("rep_tier:unremarkable") or _check("rep_tier:esteemed"))
	assert_eq(int(_check("rep_tier:disreputable")) + int(_check("rep_tier:unremarkable")) + int(_check("rep_tier:respected"))
			+ int(_check("rep_tier:esteemed")) + int(_check("rep_tier:renowned")), 1, "exactly one tier")
	assert_true(_check("alive:oldwoman"))
	GameState.set_flag(&"hagedorn_dead", 48)
	assert_false(_check("alive:oldwoman"), "D1: hagedorn_dead")
	assert_true(_check("alive:smith"))
	assert_true(_check("region:graveyard"), "no player → graveyard")
	assert_false(_check("specimen_sold_any"))
	TimeManager.day = 45
	GameState.set_flag(&"anatomy_declined", 42)
	assert_true(_check("flag_days_gte:anatomy_declined:3"))
	assert_false(_check("flag_days_gte:anatomy_declined:4"))
	assert_false(_check("order:o_rosine_berries:accepted"), "no orders system")
	assert_true(_check("order:o_rosine_berries:none"))
	expect_errors(0)
	rel.free()
	_p7_clear()


func test_phase7_order_conditions_and_actions() -> void:
	var rel := _p7_world({&"innkeeper": 25}, [&"innkeeper"])
	var orders := Orders.new()
	orders.config = Phase7Fixtures.orders_config()
	for o: OrderData in Phase7Fixtures.orders():
		orders.order_table[o.id] = o
	tree.root.add_child(orders)
	var inv := _inv({&"elderberries": 8})
	assert_true(_check("order_offerable:o_rosine_berries"))
	assert_false(_check("order_offerable:o_rosine_tincture"))
	_apply("order_accept:o_rosine_berries", _ctx(inv))
	assert_true(_check("order:o_rosine_berries:accepted"))
	assert_true(_check("order_ready:o_rosine_berries", _ctx(inv)))
	_apply("order_turn_in:o_rosine_berries", _ctx(inv))
	assert_true(_check("order:o_rosine_berries:completed"))
	assert_eq(inv.count(&"elderberries"), 0)
	assert_has(rel.calls, ["add", &"innkeeper", 8, "Auftrag: Holunder für den Wein"])
	orders.free()
	rel.free()
	inv.free()
	_p7_clear()


func test_phase7_relationship_and_village_actions() -> void:
	var rel := _p7_world({&"priest": 25})
	var village := Village.new()
	village.config = Phase7Fixtures.village_config()
	tree.root.add_child(village)
	var inv := _inv({&"coin": 30})
	_apply("meet:smith")
	_apply("talked:smith")
	_apply("rel_add:smith:3")
	assert_eq(rel.calls, [["meet", &"smith"], ["talk", &"smith"], ["add", &"smith", 3, "Gespräch"]])
	assert_true(_check("village_can:consecrate", _ctx(inv)))
	_apply("consecrate_pay", _ctx(inv))
	assert_eq(inv.count(&"coin"), 20, "10 for the consecration")
	assert_eq(GameState.get_flag(&"linden_consecration_day"), TimeManager.day + 1)
	assert_false(_check("village_can:consecrate", _ctx(inv)), "paid")
	_apply("donate", _ctx(inv))
	assert_eq(inv.count(&"coin"), 15)
	var speaker := Npc.new()
	speaker.npc_id = &"innkeeper"
	var spent := GameState.get_stat(&"coins_spent_village")
	_apply("take_item:coin:2", {"inventory": inv, "speaker": speaker})
	assert_eq(GameState.get_stat(&"coins_spent_village"), spent + 2, "a villager's coins run under village")
	speaker.free()
	village.free()
	rel.free()
	inv.free()
	_p7_clear()


func test_phase7_quast_offers_the_case_and_asks_again() -> void:
	var rel := _p7_world({&"surgeon": 20})
	var inv := _inv()
	TimeManager.day = 42
	var r := DialogueRunner.new()
	r.start(_v("v_surgeon"), _ctx(inv))
	assert_eq(_id(r), &"start", "first meeting: the offer")
	assert_true(r.current_text().contains("Zeit mit den Toten, bevor die Erde sie nimmt"))
	_go(r, &"menu")
	_go(r, &"case_no")
	assert_eq(GameState.get_flag(&"anatomy_declined"), 42)
	assert_false(GameState.flag_on(&"anatomy_known"))
	TimeManager.day = 44
	r.start(_v("v_surgeon"), _ctx(inv))
	assert_ne(_id(r), &"ask_again", "not before 3 days")
	TimeManager.day = 45
	r.start(_v("v_surgeon"), _ctx(inv))
	assert_eq(_id(r), &"ask_again", "he asks once more after 3 days")
	_go(r, &"case_yes")
	assert_true(GameState.flag_on(&"anatomy_known"))
	assert_true(GameState.flag_on(&"quast_recipes"))
	assert_true(inv.has(&"anatomy_case"), "the case")
	r.start(_v("v_surgeon"), _ctx(inv))
	assert_ne(_id(r), &"ask_again", "never again")
	rel.free()
	inv.free()
	_p7_clear()


func test_phase7_osric_intro_once_after_the_village_opened() -> void:
	_carter_p4_ready()
	GameState.set_flag(&"workshop_open", true)
	GameState.set_flag(&"buildings_open", true)
	GameState.set_flag(&"p5_intro", true)
	GameState.set_flag(&"p6_intro", true)
	_p7_clear()
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_ne(_id(r), &"p7_intro", "village not open yet")
	GameState.set_flag(&"village_open", true)
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p7_intro")
	assert_true(r.current_text().contains("Der Schultheiß lässt fragen, ob du mal runterkommst"))
	assert_true(GameState.flag_on(&"p7_intro"))
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_ne(_id(r), &"p7_intro", "once")
	_p7_clear()


func test_phase7_ilse_names_the_three_visitors() -> void:
	var rel := _p7_world({}, [&"surgeon"])
	GameState.set_flag(&"village_open", true)
	var journal := P7Journal.new()
	tree.root.add_child(journal)
	var d := _trader()
	var r := DialogueRunner.new()
	var menu := d.get_node_by_id(&"menu")
	var found := false
	for c: DialogueChoice in menu.choices:
		if c.next == &"p7_visitors":
			found = DialogueConditions.all_met(c.conditions, {})
	assert_true(found, "after meeting Quast")
	r.start(d, {})
	r._enter(&"p7_visitors")
	assert_eq(journal.clues, [&"c_v_three_visitors"])
	assert_true(r.current_text().contains("den Pfarrer, den Wundarzt und die Seelfrau"))
	journal.free()
	rel.free()
	_p7_clear()


func test_phase7_wiebke_alive_then_gone() -> void:
	var rel := _p7_world({&"oldwoman": 30, &"washer": 20}, [&"oldwoman", &"washer"])
	var r := DialogueRunner.new()
	r.start(_v("v_oldwoman"), _ctx(_inv()))
	assert_ne(_id(r), &"start")
	_go(r, &"menu")
	assert_true(r.available_choices().any(func(c: DialogueChoice) -> bool: return c.next == &"visitors"))
	_go(r, &"visitors")
	assert_true(r.current_text().contains("Der Pfarrer jeden Mittag"), "she names her visitors – the mystery, not its answer")
	GameState.set_flag(&"hagedorn_dead", 48)
	r.start(_v("v_washer"), _ctx(_inv()))
	assert_eq(_id(r), &"hagedorn_gate", "Liesel tells of her death once")
	r.start(_v("v_washer"), _ctx(_inv()))
	assert_ne(_id(r), &"hagedorn_gate")
	rel.free()
	_p7_clear()


# --- Phase 8 (P6, docs/PHASE8_DESIGN.md §1.2, §1.6, §2.1–§2.13, §3.4) -----------------------------------

const P8_NEW: PackedStringArray = ["v_apprentice", "beggar", "peddler", "robber", "kin_kehr", "kin_brandt", "kin_ott", "kin_sieber",
		"lights_lenz"]
const P8_ALL: PackedStringArray = ["carter", "carter_village", "trader", "v_innkeeper", "v_smith", "v_grocer", "v_priest", "v_mayor",
		"v_surgeon", "v_washer", "v_oldwoman", "priest_linden", "v_apprentice", "beggar", "peddler", "robber", "kin_kehr", "kin_brandt",
		"kin_ott", "kin_sieber", "lights_lenz"]
const P8_VILLAGERS := {"innkeeper": "rosine", "smith": "esch", "grocer": "mangold", "priest": "lenz", "mayor": "fenner",
		"surgeon": "quast", "washer": "liesel"}


class P8Life extends Node:
	var open := true
	var moods: Dictionary = {}
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"npc_life")

	func is_open() -> bool:
		return open

	func mood(npc_id: StringName) -> StringName:
		return moods.get(npc_id, &"plain")

	func listen(npc_id: StringName) -> bool:
		calls.append(["listen", npc_id])
		return true

	func note_event(event: StringName, npcs: Array[StringName] = []) -> void:
		calls.append(["event", event, npcs])


class P8Friend extends Node:
	var steps: Dictionary = {}
	var offerable: Dictionary = {}
	var blocked: Dictionary = {}
	var owed: Dictionary = {}
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"friendship")

	func step_done(npc_id: StringName) -> int:
		return int(steps.get(npc_id, 0))

	func offerable_step(npc_id: StringName) -> int:
		return int(offerable.get(npc_id, 0))

	func favor_block_reason(npc_id: StringName) -> String:
		return str(blocked.get(npc_id, ""))

	func accept_step(npc_id: StringName) -> bool:
		calls.append(["accept", npc_id])
		return true

	func use_favor(npc_id: StringName, choice: StringName = &"") -> bool:
		calls.append(["favor", npc_id, choice])
		return true

	func save_state() -> Dictionary:
		return {"owed": owed}

	var ware := {}

	func ware_ready() -> Dictionary:
		return ware

	func take_ware(inv: Inventory) -> bool:
		calls.append(["ware", inv != null])
		return true


class P8Apprentice extends Node:
	var hired := false
	var levels: Dictionary = {}
	var state: Dictionary = {}
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"apprentice")

	func is_hired() -> bool:
		return hired

	func level(task_id: StringName) -> int:
		return int(levels.get(task_id, 0))

	func save_state() -> Dictionary:
		return state

	func hire() -> void:
		calls.append(["hire"])
		hired = true

	func start_teach(task_id: StringName) -> void:
		calls.append(["teach", task_id])

	func praise() -> bool:
		calls.append(["praise"])
		return true

	func scold() -> bool:
		calls.append(["scold"])
		return true


class P8Visitors extends Node:
	var visits: Dictionary = {}
	var good: Dictionary = {}
	var wishes: Array = []
	var offer := {}
	var due := -1
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"visitors")

	func visit_of(kin_id: StringName) -> Dictionary:
		return visits.get(kin_id, {})

	func goodwill(kin_id: StringName) -> int:
		return int(good.get(kin_id, 5))

	func open_wishes() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		out.assign(wishes)
		return out

	func offer_wish(visit_id: String) -> Dictionary:
		calls.append(["offer", visit_id])
		return offer

	func accept_wish(wish_id: String) -> bool:
		calls.append(["accept", wish_id])
		return true

	func hand_tip(visit_id: String, inv: Inventory) -> int:
		calls.append(["tip", visit_id, inv != null])
		return 2


class P8DueVisitors extends P8Visitors:
	func tip_due(_visit_id: String) -> int:
		return due


class P8Fest extends Node:
	var today_id := &""
	var running_id := &""
	var days: Dictionary = {}
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"festivals")

	func today() -> StringName:
		return today_id

	func running() -> StringName:
		return running_id

	func fest_day(fest_id: StringName) -> int:
		return int(days.get(fest_id, -1))

	func dance(npc_id: StringName) -> bool:
		calls.append(["dance", npc_id])
		return true


class P8Night extends Node:
	var alms := 0
	var fate_id := &""
	var houses := PackedStringArray()
	var seen: Array = []
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"wanderers")
		add_to_group(&"night_robber")
		add_to_group(&"night_paths")
		add_to_group(&"orders")

	func alms_count() -> int:
		return alms

	func give_alms(inv: Inventory) -> bool:
		calls.append(["alms", inv != null])
		alms += 1
		return true

	func fate() -> StringName:
		return fate_id

	func resolve(choice: StringName) -> void:
		calls.append(["resolve", choice])
		fate_id = choice

	func sick_houses(_day: int, _minute: int) -> PackedStringArray:
		return houses

	func observed(clue_id: StringName) -> bool:
		return seen.has(clue_id)

	func note_meet(npc_id: StringName, place_id: StringName) -> void:
		calls.append(["meet", npc_id, place_id])

	func note_task(action_id: StringName) -> void:
		calls.append(["task", action_id])


class P8Journal extends Node:
	var clues: Array = []
	var insights: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		GameState.set_flag(StringName("clue_" + String(id)), true)
		return true

	func has_insight(id: StringName) -> bool:
		return insights.has(id)


func _p8_reachable(d: DialogueData) -> Dictionary:
	var seen := {}
	var todo: Array[StringName] = [d.start_node]
	while not todo.is_empty():
		var id: StringName = todo.pop_back()
		if id == &"" or seen.has(id):
			continue
		seen[id] = true
		var n := d.get_node_by_id(id)
		if n == null:
			continue
		todo.append(n.fallback_next)
		for c: DialogueChoice in n.choices:
			todo.append(c.next)
	return seen


func test_phase8_dialogues_are_well_formed() -> void:
	var cond_re := RegEx.create_from_string(CONDITION_GRAMMAR)
	var action_re := RegEx.create_from_string(ACTION_GRAMMAR)
	for id: String in P8_ALL:
		var d := _v(id)
		assert_not_null(d, id)
		if d == null:
			continue
		assert_eq(String(d.id), id)
		assert_ne(d.speaker_name, "", id + " speaker")
		var ids := {}
		for n: DialogueNode in d.nodes:
			assert_false(ids.has(n.id), "%s: unique %s" % [id, n.id])
			ids[n.id] = true
		assert_true(ids.has(d.start_node), id + " start")
		var reach := _p8_reachable(d)
		for n: DialogueNode in d.nodes:
			assert_true(n.text.strip_edges().length() > 0, "%s.%s text" % [id, n.id])
			assert_false(n.text.contains("TODO") or n.text.contains("<"), "%s.%s placeholder" % [id, n.id])
			assert_true(n.fallback_next == &"" or ids.has(n.fallback_next), "%s.%s fallback" % [id, n.id])
			assert_true(reach.has(n.id), "%s.%s reachable" % [id, n.id])
			var conds: Array[String] = n.conditions.duplicate()
			var acts: Array[String] = n.actions.duplicate()
			for c: DialogueChoice in n.choices:
				assert_true(c.next == &"" or ids.has(c.next), "%s.%s → %s" % [id, n.id, c.next])
				assert_true(c.text.strip_edges().length() > 0, "%s.%s choice text" % [id, n.id])
				conds.append_array(c.conditions)
				acts.append_array(c.actions)
			for c: String in conds:
				assert_not_null(cond_re.search(c), "%s: condition '%s'" % [id, c])
			for a: String in acts:
				assert_not_null(action_re.search(a), "%s: action '%s'" % [id, a])


func test_phase8_every_story_step_and_order_has_its_dialogue() -> void:
	for npc: String in P8_VILLAGERS:
		var d := _v("v_" + npc)
		var story := load("res://tests/fixtures/phase8/friendship/stories/%s.tres" % npc) as FriendStoryData
		for st: FriendStepData in story.steps:
			assert_not_null(d.get_node_by_id(st.start_node), "%s: %s" % [npc, st.start_node])
			assert_not_null(d.get_node_by_id(st.end_node), "%s: %s" % [npc, st.end_node])
		assert_true(_dialogue_has(d, "step_accept:" + npc) or _dialogue_has_node_action(d, "step_accept:" + npc), npc + " accepts a step")
		assert_true(_dialogue_has(d, "favor_ready:" + npc), npc + " offers the favour")
		assert_true(_dialogue_has(d, "mood:%s:low" % npc), npc + ": [Zuhören]")
		assert_true(_dialogue_has(d, "mood:%s:cross" % npc), npc + ": „Heute nicht“")
		var favor := load("res://tests/fixtures/phase8/friendship/favors/fav_%s.tres" % npc) as FavorData
		for oid: StringName in favor.return_orders:
			assert_true(_dialogue_has(d, "order_offerable:" + String(oid)), "%s offered" % oid)
			assert_true(_dialogue_has(d, "order_turn_in:" + String(oid)), "%s handed in" % oid)
	var all_dialogues := {}
	for id: String in P8_ALL:
		all_dialogues[id] = _v(id)
	for f: String in DirAccess.get_files_at("res://tests/fixtures/phase8/orders"):
		if not f.ends_with(".tres"):
			continue
		var o := load("res://tests/fixtures/phase8/orders/" + f) as OrderData
		if String(o.id).contains("_return_"):
			continue
		var who := String(o.recipient if o.recipient != &"" else o.giver)
		var d: DialogueData = all_dialogues.get("v_" + who, all_dialogues.get(who))
		assert_not_null(d, "%s: dialogue of %s" % [o.id, who])
		if o.kind == &"deliver":
			assert_true(_dialogue_has(d, "order_turn_in:" + String(o.id)), "%s handed to %s" % [o.id, who])
		elif o.kind == &"meet":
			var place := String(o.conditions.get("place", ""))
			assert_true(_dialogue_has(_v("v_" + String(o.giver)), "meet:" + place), "%s: meet:%s" % [o.id, place])


func _dialogue_has_node_action(d: DialogueData, entry: String) -> bool:
	for n: DialogueNode in d.nodes:
		if entry in n.actions:
			return true
	return false


func test_phase8_conditions() -> void:
	var life := P8Life.new()
	var friend := P8Friend.new()
	var app := P8Apprentice.new()
	var vis := P8Visitors.new()
	var fest := P8Fest.new()
	var night := P8Night.new()
	var journal := P8Journal.new()
	for n: Node in [life, friend, app, vis, fest, night, journal]:
		tree.root.add_child(n)
	TimeManager.day = 57
	TimeManager.minute_of_day = 600
	GameState.set_flag(&"p8_open_day", 53)
	assert_true(_check("p8_open"))
	life.open = false
	assert_false(_check("p8_open"), "NpcLife decides")
	assert_false(_check("open_days_gte:2"), "closed → never")
	life.open = true
	assert_true(_check("open_days_gte:4"))
	assert_false(_check("open_days_gte:5"))
	life.moods[&"washer"] = &"low"
	assert_true(_check("mood:washer:low"))
	assert_false(_check("mood:washer:cross"))
	assert_true(_check("mood:smith:plain"), "default plain")
	assert_false(_check("mood:smith:grumpy"), "unknown mood → invalid")
	friend.steps[&"innkeeper"] = 2
	friend.offerable[&"innkeeper"] = 3
	assert_true(_check("step_gte:innkeeper:2"))
	assert_false(_check("step_gte:innkeeper:3"))
	assert_true(_check("step_offerable:innkeeper"))
	assert_false(_check("step_offerable:smith"))
	friend.blocked[&"smith"] = "Noch nicht."
	assert_false(_check("favor_ready:smith"))
	assert_true(_check("favor_ready:grocer"))
	friend.owed["smith"] = "of_esch_return_1"
	assert_true(_check("favor_owed:smith"))
	assert_false(_check("favor_owed:grocer"))
	assert_false(_check("apprentice_hired"))
	app.hired = true
	assert_true(_check("apprentice_hired"))
	app.levels[&"rake"] = 2
	assert_true(_check("apprentice_level_gte:rake:2"))
	assert_false(_check("apprentice_level_gte:weed:1"))
	assert_true(_check("apprentice_level_gte:2"), "any task (FriendStepData)")
	assert_false(_check("apprentice_mistake_today"))
	app.state = {"plan_day": 57, "mistakes_today": 1}
	assert_true(_check("apprentice_mistake_today"))
	app.state = {"plan_day": 56, "mistakes_today": 1}
	assert_false(_check("apprentice_mistake_today"), "yesterday's plan")
	var kin := {"kin_id": &"kin_kehr"}
	assert_false(_check("wish_offerable", kin), "no visit today")
	vis.visits[&"kin_kehr"] = {"visit_id": "v_57_1", "kin_id": "kin_kehr", "graves": ["l_02"], "slot": 570, "phase": "waiting"}
	assert_true(_check("wish_offerable", kin))
	assert_true(_check("visit_waiting", kin))
	vis.wishes = [{"wish_id": "w_1", "grave_id": "l_02", "kin_id": "kin_kehr", "state": "accepted"}]
	assert_false(_check("wish_offerable", kin), "one open wish per grave")
	vis.wishes = [{"grave_id": "l_05", "state": "accepted"}, {"grave_id": "l_06", "state": "accepted"}, {"grave_id": "l_07", "state": "offered"}]
	assert_false(_check("wish_offerable", kin), "three open")
	vis.wishes = [{"grave_id": "l_05", "state": "done"}]
	vis.good[&"kin_kehr"] = 1
	assert_false(_check("wish_offerable", kin), "goodwill < 2")
	vis.good[&"kin_kehr"] = 2
	assert_true(_check("wish_offerable", kin))
	(vis.visits[&"kin_kehr"] as Dictionary)["phase"] = "mourning"
	assert_false(_check("visit_waiting", kin))
	assert_false(_check("tip_due", kin))
	(vis.visits[&"kin_kehr"] as Dictionary)["tip"] = 2
	assert_true(_check("tip_due", kin), "the plan entry's tip")
	fest.today_id = &"fest_lights"
	fest.running_id = &"fest_lights"
	fest.days = {&"fest_lights": 58, &"fest_kathrein": 54}
	assert_true(_check("fest_today:lights") and _check("fest_today:fest_lights") and _check("fest_day:lights"))
	assert_true(_check("fest_running:lights"))
	assert_false(_check("fest_running:kathrein"))
	assert_true(_check("fest_eve:lights"), "57 = 58 − 1")
	assert_false(_check("fest_after:lights"))
	TimeManager.day = 59
	assert_true(_check("fest_after:lights"))
	assert_false(_check("fest_after:kathrein"))
	night.alms = 3
	assert_true(_check("alms_gte:3"))
	assert_false(_check("alms_gte:4"))
	assert_false(_check("robber_known"))
	GameState.set_flag(&"robber_known", true)
	assert_true(_check("robber_known"))
	assert_true(_check("robber_fate:none"))
	night.fate_id = &"let_go"
	assert_true(_check("robber_fate:let_go"))
	assert_false(_check("robber_fate:reported"))
	assert_false(_check("robber_fate:hanged"), "unknown fate → invalid")
	assert_false(_check("sick_light"))
	night.houses = PackedStringArray(["house_ott"])
	assert_true(_check("sick_light") and _check("sick_light:house_ott"))
	assert_false(_check("sick_light:house_kehr"))
	night.seen = [&"c_n_quast_visit"]
	assert_true(_check("observed:c_n_quast_visit"))
	assert_false(_check("observed:c_n_lenz_visit"))
	assert_true(_check("underlined:washer"), "§14.1")
	assert_false(_check("underlined:priest"))
	assert_false(_check("underlined:osric"), "invalid")
	assert_false(_check("insight:i_underlined"))
	journal.insights = [&"i_underlined"]
	assert_true(_check("insight:i_underlined"))
	expect_errors(0)


func test_phase8_conditions_without_systems() -> void:
	# A Phase-7 world (no Phase-8 nodes): everything false, nothing breaks; p8_open falls back to the flag.
	assert_false(_check("p8_open"))
	GameState.set_flag(&"p8_open", true)
	assert_true(_check("p8_open"))
	for c: String in ["step_gte:innkeeper:1", "step_offerable:innkeeper", "favor_ready:smith", "favor_owed:smith", "apprentice_hired",
			"apprentice_mistake_today", "wish_offerable", "visit_waiting", "tip_due", "fest_today:lights", "fest_eve:lights",
			"alms_gte:1", "robber_fate:let_go", "sick_light", "observed:c_n_veit", "insight:i_underlined"]:
		assert_false(_check(c), c)
	assert_true(_check("mood:priest:plain"), "no NpcLife → plain")
	assert_true(_check("robber_fate:none"))
	GameState.set_flag(&"apprentice_hired", true)
	assert_true(_check("apprentice_hired"), "flag fallback")
	GameState.set_flag(&"clue_c_n_veit", true)
	assert_true(_check("observed:c_n_veit"), "the journal flag counts")


func test_phase8_actions() -> void:
	var life := P8Life.new()
	var friend := P8Friend.new()
	var app := P8Apprentice.new()
	var vis := P8Visitors.new()
	var fest := P8Fest.new()
	var night := P8Night.new()
	for n: Node in [life, friend, app, vis, fest, night]:
		tree.root.add_child(n)
	var inv := _inv({&"coin": 5})
	var speaker := SpeakerDouble.new()
	speaker.npc_id = &"smith"
	tree.root.add_child(speaker)
	var ctx := {"inventory": inv, "speaker": speaker}
	_apply("listen:washer", ctx)
	_apply("note_event:lights_all", ctx)
	assert_eq(life.calls, [["listen", &"washer"], ["event", &"lights_all", [] as Array[StringName]]])
	_apply("step_accept:innkeeper", ctx)
	_apply("favor_use:smith:steel_rod", ctx)
	_apply("favor_use:grocer", ctx)
	assert_eq(friend.calls, [["accept", &"innkeeper"], ["favor", &"smith", &"steel_rod"], ["favor", &"grocer", &""]])
	assert_false(_check("ware_ready"))
	friend.ware = {"item": "grave_candle", "day": 57, "price": 1}
	assert_true(_check("ware_ready"), "Theres' order is in the shop (P4)")
	_apply("take_ware", ctx)
	assert_eq(friend.calls.back(), ["ware", true])
	_apply("apprentice_hire", ctx)
	_apply("apprentice_teach:weed", ctx)
	_apply("apprentice_praise", ctx)
	_apply("apprentice_scold", ctx)
	assert_eq(app.calls, [["hire"], ["teach", &"weed"], ["praise"], ["scold"]])
	_apply("dance:grocer", ctx)
	assert_eq(fest.calls, [["dance", &"grocer"]])
	_apply("alms", ctx)
	_apply("robber_resolve:let_go", ctx)
	_apply("meet:v_linden", ctx)
	_apply("task:lights_names", ctx)
	assert_eq(night.calls, [["alms", true], ["resolve", &"let_go"], ["meet", &"smith", &"v_linden"], ["task", &"lights_names"]])
	var rel := _p7_world()
	_apply("meet:smith", ctx)
	assert_eq(rel.calls, [["meet", &"smith"]], "meet:<villager> stays Phase 7")
	# Wishes and tips of the speaker's visit.
	var panels: Array = []
	var on_panel := func(panel: StringName, c: Dictionary) -> void: panels.append([panel, c.get("offer"), c.get("kin_id")])
	EventBus.ui_panel_requested.connect(on_panel)
	var kctx := {"inventory": inv, "speaker": null, "kin_id": &"kin_kehr"}
	_apply("wish_offer", kctx)
	assert_eq(vis.calls, [], "no visit – nothing offered")
	vis.visits[&"kin_kehr"] = {"visit_id": "v_57_1", "kin_id": "kin_kehr", "graves": ["l_02"]}
	_apply("wish_offer", kctx)
	assert_eq(panels, [], "an empty offer opens no card")
	vis.offer = {"wish_id": "w_0003", "kind": "flowers", "grave_id": "l_02", "text": "Ein paar Blumen."}
	_apply("wish_offer", kctx)
	assert_eq(panels, [[&"wish_card", vis.offer, &"kin_kehr"]], "the wish card")
	assert_eq(kctx.get("wish_offer"), vis.offer, "kept in the context")
	_apply("wish_accept", kctx)
	_apply("tip_hand", kctx)
	assert_eq(vis.calls, [["offer", "v_57_1"], ["offer", "v_57_1"], ["accept", "w_0003"], ["tip", "v_57_1", true]])
	vis.calls.clear()
	vis.wishes = [{"wish_id": "w_0009", "kin_id": "kin_kehr", "state": "offered"}]
	_apply("wish_accept", {"inventory": inv, "speaker": null, "kin_id": &"kin_kehr"})
	assert_eq(vis.calls, [["accept", "w_0009"]], "without the context: the speaker's offered wish")
	EventBus.ui_panel_requested.disconnect(on_panel)
	expect_errors(0)


func test_phase8_tip_due_asks_visitors_first() -> void:
	var vis := P8DueVisitors.new()
	tree.root.add_child(vis)
	vis.visits[&"kin_ott"] = {"visit_id": "v_60_2", "tip": 3}
	vis.due = 0
	assert_false(_check("tip_due", {"kin_id": &"kin_ott"}), "Visitors.tip_due wins over the plan entry")
	vis.due = 2
	assert_true(_check("tip_due", {"kin_id": &"kin_ott"}))


func _p8_carter_ready() -> void:
	_carter_p4_ready()
	for f: StringName in [&"workshop_open", &"buildings_open", &"p5_intro", &"p6_intro", &"village_open", &"p7_intro"]:
		GameState.set_flag(f, true)


func test_phase8_osric_intro_once_after_p8_open() -> void:
	_p8_carter_ready()
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_ne(_id(r), &"p8_intro", "Phase 8 not open yet")
	GameState.set_flag(&"p8_open", true)
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p8_intro")
	assert_true(r.current_text().begins_with("Unten reden sie über dich, Totengräber.") and r.current_text().ends_with("Ich fahr nur."),
			"§1.2 leading text")
	_go(r, &"p8_who")
	assert_true(r.current_text().contains("Heide"), "first: the visitors")
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_ne(_id(r), &"p8_intro", "once")
	var texts: Array = []
	for i: int in 4:
		r = DialogueRunner.new()
		r.start(_carter(), _ctx(_inv()))
		r._enter(&"p8_who")
		texts.append(_id(r))
	assert_eq(texts, [&"p8_who_2", &"p8_who_3", &"p8_who", &"p8_who_2"], "wechselnd: Besucher, Veit, Hanne")


func test_phase8_osric_robber_line_sets_robber_known() -> void:
	_p8_carter_ready()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_intro", true)
	GameState.stats[&"robber_encounters"] = 1
	var r := _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_eq(_id(r), &"p8_robber_seen")
	assert_true(r.current_text().contains("Ich halte nie an."), "§2.12")
	assert_true(GameState.flag_on(&"robber_known"))
	r = _start_carter(MORNING, _inv())
	_go(r, &"remark_skipped")
	assert_ne(_id(r), &"p8_robber_seen", "once")


func test_phase8_fenner_grants_the_third_row_once() -> void:
	var rel := _p7_world({&"mayor": 45}, [&"mayor"])
	var r := DialogueRunner.new()
	r.start(_v("v_mayor"), _ctx(_inv()))
	assert_ne(_id(r), &"p8_row3", "before p8_open")
	GameState.set_flag(&"p8_open", true)
	r.start(_v("v_mayor"), _ctx(_inv()))
	assert_eq(_id(r), &"p8_row3")
	assert_true(GameState.flag_on(&"linden_row3_granted"))
	assert_true(notes.any(func(n: Array) -> bool: return n[0] == "Die Gemeinde gibt dir die dritte Reihe am Lindenacker."), "§2.8 note")
	r.start(_v("v_mayor"), _ctx(_inv()))
	assert_ne(_id(r), &"p8_row3", "once")
	rel.free()


func test_phase8_rosine_hires_jakob_with_step_one() -> void:
	var rel := _p7_world({&"innkeeper": 45}, [&"innkeeper"])
	var friend := P8Friend.new()
	var app := P8Apprentice.new()
	var life := P8Life.new()
	for n: Node in [friend, app, life]:
		tree.root.add_child(n)
	friend.offerable[&"innkeeper"] = 1
	var r := DialogueRunner.new()
	r.start(_v("v_innkeeper"), _ctx(_inv()))
	_go(r, &"menu")
	_go(r, &"story_1")
	assert_true(r.current_text().contains("Er soll lernen, was die Leute brauchen, auch wenn sie es nicht wollen."), "§2.13 Rosine 1")
	_go(r, &"story_1_yes")
	assert_eq(friend.calls, [["accept", &"innkeeper"]])
	assert_eq(app.calls, [["hire"]], "§2.5.1: hired through Rosine 1")
	life.moods[&"innkeeper"] = &"cross"
	friend.offerable[&"innkeeper"] = 0
	r.start(_v("v_innkeeper"), _ctx(_inv()))
	_go(r, &"menu")
	_go(r, &"story_cross")
	assert_eq(r.current_text(), "Heute nicht, Totengräber. Morgen.", "§2.1.1")
	rel.free()


func test_phase8_veit_tells_of_the_three_after_the_alms() -> void:
	var night := P8Night.new()
	var journal := P8Journal.new()
	tree.root.add_child(night)
	tree.root.add_child(journal)
	var r := DialogueRunner.new()
	TimeManager.minute_of_day = 600
	r.start(_v("beggar"), _ctx(_inv({&"coin": 3})))
	assert_eq(_id(r), &"first")
	assert_true(r.current_text().contains("siebzehn"))
	_go(r, &"menu")
	_go(r, &"alms")
	assert_eq(_id(r), &"alms_plain", "first alms: a nod")
	assert_eq(night.calls, [["alms", true]])
	journal.add_clue(&"c_n_veit")  # Wanderers gives it with the third alms (§2.6.1)
	r.start(_v("beggar"), _ctx(_inv({&"coin": 3})))
	_go(r, &"menu")
	assert_false(r.available_choices().any(func(c: DialogueChoice) -> bool: return c.next == &"alms"), "once a day")
	TimeManager.day += 1
	r.start(_v("beggar"), _ctx(_inv({&"coin": 3})))
	_go(r, &"menu")
	_go(r, &"alms")
	assert_eq(_id(r), &"alms")
	assert_true(r.current_text().begins_with("Du gibst, ohne zu fragen, was ich damit mache."), "§2.13")
	_go(r, &"three")
	assert_true(r.current_text().contains("Der Pfarrer mit der Laterne, der Doktor mit dem Koffer, die Dorn mit dem Tuch."), "§1.6 item 1")
	TimeManager.minute_of_day = 1300
	night.houses = PackedStringArray(["house_ott"])
	r.start(_v("beggar"), _ctx(_inv()))
	assert_eq(_id(r), &"night_ott")
	assert_true(r.current_text().begins_with("Bei den Otts brennt Licht. Seit gestern."), "§2.13 at the well bench")


func test_phase8_lambert_two_ways_and_the_clue() -> void:
	var night := P8Night.new()
	var journal := P8Journal.new()
	tree.root.add_child(night)
	tree.root.add_child(journal)
	var r := DialogueRunner.new()
	r.start(_v("robber"), _ctx(_inv()))
	assert_true(r.current_text().contains("Ich nehm nichts."))
	_go(r, &"who")
	assert_eq(journal.clues, [&"c_n_robber"], "Wer zahlt dich? → c_n_robber")
	assert_true(r.current_text().begins_with("Ein Herr mit einem Koffer."))
	_go(r, &"reported")
	assert_eq(night.calls, [["resolve", &"reported"]])
	r.start(_v("robber"), _ctx(_inv()))
	_go(r, &"let_go")
	assert_eq(night.calls, [["resolve", &"reported"], ["resolve", &"let_go"]])


func test_phase8_liesel_promise_and_the_quiet_line() -> void:
	var rel := _p7_world({&"washer": 75}, [&"washer"])
	var journal := P8Journal.new()
	tree.root.add_child(journal)
	var d := _v("v_washer")
	var r := DialogueRunner.new()
	r.start(d, _ctx(_inv()))
	r._enter(&"story_3_meet")
	assert_true(r.current_text().ends_with("Versprich es."), "§2.13 Liesel 3")
	_go(r, &"story_3_promise")
	assert_true(GameState.flag_on(&"promise_liesel_book"))
	assert_eq(_id(r), &"story_3_promise_plain", "without i_underlined: no extra line")
	journal.insights = [&"i_underlined"]
	r.start(d, _ctx(_inv()))
	r._enter(&"story_3_meet")
	_go(r, &"story_3_promise")
	assert_true(r.current_text().begins_with("Sie schlägt die letzte Seite auf und wieder zu, bevor du lesen kannst."), "§2.4 Liesel 3")
	rel.free()


func test_phase8_jakob_is_taught_only_what_he_cannot() -> void:
	var app := P8Apprentice.new()
	tree.root.add_child(app)
	app.hired = true
	app.levels = {&"rake": 1}
	GameState.set_flag(&"p8_jakob_met", 50)
	TimeManager.day = 51
	var r := DialogueRunner.new()
	r.start(_v("v_apprentice"), _ctx(_inv()))
	assert_eq(_id(r), &"early", "„Herr Totengräber“ for three days")
	_go(r, &"menu")
	var teach: Array = []
	for c: DialogueChoice in r.available_choices():
		for a: String in c.actions:
			if a.begins_with("apprentice_teach:"):
				teach.append(a)
	assert_eq(teach, ["apprentice_teach:weed", "apprentice_teach:water", "apprentice_teach:candle"], "rake is learned")
	assert_false(r.available_choices().any(func(c: DialogueChoice) -> bool: return c.next == &"scolded"), "no mistake, no scolding")
	TimeManager.day = 54
	r.start(_v("v_apprentice"), _ctx(_inv()))
	assert_eq(_id(r), &"greet", "after three days he forgets the title")
	_go(r, &"menu")
	_go(r, &"dead")
	assert_eq(r.current_text(), "Die Toten fasst du an. Das hat Mutter gesagt. Ich mach das Laub.", "§2.5.6")


func test_phase8_kin_offer_a_wish_and_tip() -> void:
	for id: String in ["kin_kehr", "kin_brandt", "kin_ott", "kin_sieber"]:
		var d := _v(id)
		assert_true(_dialogue_has(d, "wish_offerable") and _dialogue_has(d, "wish_offer") and _dialogue_has(d, "tip_due"), id)
		var accept := false
		for n: DialogueNode in d.nodes:
			for c: DialogueChoice in n.choices:
				if "wish_accept" in c.actions:
					accept = c.text == "Das mache ich."
		assert_true(accept, id + ": „Das mache ich.“ (§2.2.5)")
	assert_true(_v("kin_ott").get_node_by_id(&"first").text.begins_with("War er schwer?"), "§2.13 Gesa Ott")
	assert_true(_v("kin_sieber").get_node_by_id(&"greet").text.contains("So, Grete. Der Totengräber hat gefegt."), "§2.13 Sieber")


func test_phase8_lenz_speech_at_the_lights() -> void:
	var fest := P8Fest.new()
	tree.root.add_child(fest)
	var r := DialogueRunner.new()
	r.start(_v("lights_lenz"), _ctx(_inv()))
	assert_eq(_id(r), &"after", "no Lichtgang running")
	fest.running_id = &"fest_lights"
	r.start(_v("lights_lenz"), _ctx(_inv()))
	assert_eq(_id(r), &"speech")
	assert_true(r.current_text().begins_with("Wir zünden kein Licht für Gott an. Der sieht auch so."), "§2.13 Lenz am Lichtgang")


# --- Phase 8 (P6): chatter texts (§2.1.2) and schedules (§2.1.4, §2.6, §2.7, §1.6) ------------------------

func test_phase8_chatter_texts() -> void:
	var cond_re := RegEx.create_from_string(CONDITION_GRAMMAR)
	var files := DirAccess.get_files_at("res://data/npc_life/chatter")
	var count := 0
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		count += 1
		var c := load("res://data/npc_life/chatter/" + f) as ChatterData
		var t := load("res://tests/fixtures/phase8/chatter/" + f) as ChatterData
		assert_not_null(c, f)
		assert_not_null(t, f + " template")
		if c == null or t == null:
			continue
		assert_eq([c.id, c.region, c.npcs, c.place, c.window, c.sets_flag], [t.id, t.region, t.npcs, t.place, t.window, t.sets_flag],
				String(c.id) + ": who / where / when as the template")
		assert_true(c.lines.size() >= 2 and c.lines.size() <= 4, "%s: 2–4 lines" % c.id)
		assert_eq([c.lines[0], c.lines[1]], [t.lines[0], t.lines[1]], "%s: the leading lines first (§2.1.2)" % c.id)
		for line: String in c.lines:
			assert_true(line.length() > 3 and not line.contains("TODO"), String(c.id))
		for cond: String in c.conditions:
			assert_not_null(cond_re.search(cond), "%s: condition '%s'" % [c.id, cond])
	assert_eq(count, 16, "§2.1.2: 16 chatters")
	assert_eq((load("res://data/npc_life/chatter/ch_rumor_robber.tres") as ChatterData).sets_flag, &"robber_known")


const P8_SCHEDULES: PackedStringArray = ["innkeeper", "smith", "grocer", "mayor", "priest", "surgeon", "washer", "carter"]
const P8_FLAGS: PackedStringArray = ["visit_smith_day", "visit_grocer_day", "visit_washer_day", "fest_kathrein_day", "fest_lights_day",
		"night_np_ott_priest_day", "night_np_kehr_priest_day", "night_np_ott_surgeon_day", "night_np_kehr_surgeon_day",
		"night_np_ott_washer_day", "beggar_gate_day", "peddler_day", "apprentice_off_day",
		# W3 (QA8-03): the meet orders of Fenner 2 and Rosine 3 bring them to their place.
		"meet_mayor_day", "meet_innkeeper_day"]


func _sched(npc: String) -> NpcSchedule:
	return load("res://data/npc/%s_schedule.tres" % npc) as NpcSchedule


func test_phase8_schedules_unchanged_without_their_flags() -> void:
	# Phase 7 bitgleich: without a Phase-8 flag every minute resolves to a Phase-7 entry.
	for npc: String in P8_SCHEDULES:
		var s := _sched(npc)
		assert_not_null(s, npc)
		for e: ScheduleEntry in s.entries:
			assert_true(e.today_flag == &"" or String(e.today_flag) in P8_FLAGS or e.today_flag in [&"linden_consecration_day",
					&"lecture_night_day", &"lecture_after_day"], "%s: flag %s" % [npc, e.today_flag])
		for t: int in range(0, 1440, 1):
			var e := ScheduleResolver.entry_at(s, t, 57)
			assert_true(e != null and not String(e.today_flag) in P8_FLAGS, "%s %d: a Phase-7 entry" % [npc, t])


func _at(npc: String, flag: StringName, minute: int, day := 57) -> ScheduleEntry:
	GameState.set_flag(flag, day)
	var e := ScheduleResolver.entry_at(_sched(npc), minute, day)
	GameState.clear_flag(flag)
	return e


func test_phase8_schedule_overlays() -> void:
	# §2.1.4 visits.
	var e := _at("smith", &"visit_smith_day", 830)
	assert_eq([e.region, e.path[-1], e.dialogue_id, e.visible], [&"", "gv_old_01", &"v_smith", true], "Esch at Gratz' grave 13:40–14:30")
	e = _at("smith", &"visit_smith_day", 800)
	assert_eq([e.region, e.visible], [&"village", false], "on the way up: hidden in the village")
	e = _at("smith", &"visit_smith_day", 1000)
	assert_eq([e.path[-1], e.dialogue_id], ["v_anvil", &"v_smith"], "back at the anvil")
	e = _at("grocer", &"visit_grocer_day", 890)
	assert_eq([e.region, e.path[-1], e.animation], [&"", "gv_old_08", &"kneel"], "Theres kneels at old_08")
	e = _at("washer", &"visit_washer_day", 600)
	assert_eq([e.region, e.dialogue_id], [&"", &"v_washer"], "Liesel on the hill 09:40–10:40")
	# §2.7.1 Kathrein, §2.7.2 Lichtgang.
	e = _at("smith", &"fest_kathrein_day", 1200)
	assert_eq([e.region, e.path[-1].begins_with("v_in_inn"), e.dialogue_id], [&"village", true, &"v_smith"], "Esch at the dance")
	e = _at("washer", &"fest_kathrein_day", 1230)
	assert_true(e.path[-1].begins_with("v_in_inn"), "Liesel 20:00–21:00")
	e = _at("washer", &"fest_kathrein_day", 1300)
	assert_false(e.visible, "and home after nine")
	e = _at("carter", &"fest_kathrein_day", 1200)
	assert_eq([e.region, e.path[-1]], [&"", "evening_spot"], "Osric keeps his Phase-7 evening (the W-Welt fixture)")
	for npc: String in ["innkeeper", "smith", "grocer", "mayor", "priest", "washer"]:
		e = _at(npc, &"fest_lights_day", 970)
		assert_eq(e.path[-1], "v_bridge", npc + ": gathering at the Holderbrücke 16:00")
		e = _at(npc, &"fest_lights_day", 1050)
		assert_false(e.visible, npc + ": up the hill (P4's procession)")
	e = _at("surgeon", &"fest_lights_day", 1050)
	assert_eq([e.path[-1], e.visible], ["v_bridge", true], "Quast stays at the bridge")
	# §1.6 night visits.
	e = _at("surgeon", &"night_np_ott_surgeon_day", 1350)
	assert_eq([e.path[-1], e.animation], ["v_ott_door", &"knock"], "Quast knocks at the Otts' 22:30")
	e = _at("surgeon", &"night_np_ott_surgeon_day", 1370)
	assert_false(e.visible, "inside")
	e = _at("surgeon", &"night_np_ott_surgeon_day", 1390)
	assert_eq([e.path[-1], e.visible], ["v_ott_door", true], "comes out 23:10 (observation)")
	e = _at("priest", &"night_np_kehr_priest_day", 1291)
	assert_eq([e.path[-1], e.visible], ["v_kehr_door", true], "Lenz leaves the Kehrs 21:30")
	e = _at("washer", &"night_np_ott_washer_day", 200)
	assert_false(e.visible, "Liesel at the wake 02:40–05:30")
	e = _at("washer", &"night_np_ott_washer_day", 331)
	assert_eq([e.path[-1], e.visible], ["v_ott_door", true])


func test_phase8_new_schedules() -> void:
	var veit := _sched("beggar")
	var hanne := _sched("peddler")
	var jakob := _sched("apprentice")
	for s: NpcSchedule in [veit, hanne, jakob]:
		assert_not_null(s)
	assert_eq([veit.npc_id, veit.display_name, hanne.npc_id, hanne.display_name, jakob.npc_id], [&"beggar", "Veit Ammer", &"peddler",
			"Hanne Vogelsang", &"apprentice"])
	var e := ScheduleResolver.entry_at(veit, 600, 56)
	assert_eq([e.path[-1], e.dialogue_id, e.animation], ["v_church_step", &"beggar", &"sit_beg"], "Kirchtür 08:00–11:30")
	e = ScheduleResolver.entry_at(veit, 900, 56)
	assert_eq([e.region, e.path[-1]], [&"village", "v_bridge_sit"], "even day: the bridge")
	e = _at("beggar", &"beggar_gate_day", 900, 55)
	assert_eq([e.region, e.path[-1], e.dialogue_id], [&"", "veit_gate", &"beggar"], "odd day: outside the cemetery gate")
	e = ScheduleResolver.entry_at(veit, 1300, 56)
	assert_eq(e.path[-1], "v_well_bench", "21:00–23:30 at the well bench, in the dark")
	e = _at("beggar", &"fest_lights_day", 1050, 58)
	assert_eq([e.region, e.path[-1]], [&"", "lights_gate"], "at the Lichtgang he stands at the gate")
	assert_false(ScheduleResolver.entry_at(hanne, 700, 56).visible, "Hanne only on her day")
	e = _at("peddler", &"peddler_day", 700, 55)
	assert_eq([e.path[-1], e.dialogue_id], ["v_well_peddler", &"peddler"], "10:00–14:00 at the well")
	e = _at("peddler", &"peddler_day", 960, 55)
	assert_eq([e.region, e.path[-1]], [&"", "peddler_gate"], "15:40–16:20 outside the cemetery gate")
	e = ScheduleResolver.entry_at(jakob, 460, 56)
	assert_eq(e.path[-1], "v_in_inn_jakob", "07:30 breakfast in the inn")
	assert_false(ScheduleResolver.entry_at(jakob, 600, 56).visible, "on the hill (P3's runtime schedule)")
	e = _at("apprentice", &"apprentice_off_day", 600, 58)
	assert_eq([e.path[-1], e.visible], ["v_in_inn_jakob", true], "the free day in the inn")
