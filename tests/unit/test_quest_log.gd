extends TestCase
## P1 (docs/PHASE9_DESIGN.md §2.1, §7.1, §10): QuestLog – „Vorhaben" collects the chains (main / side; done steps,
## the current one with its hint, future ones hidden as „…", choices as labels, endings), the running large requests
## with their parts, the accepted small requests, the orders (Phase 7 + errands), friendship steps and return favours;
## the pinned entry and its HUD line; empty without the systems; nothing before p9_open but the requests.

const OPEN := 63


class HillDouble extends Node:
	var board_ids: Dictionary = {}
	var parts: Dictionary = {}
	var small: Array[StringName] = []

	func _init() -> void:
		add_to_group(&"hill_requests")

	func large_board(place: StringName) -> Array[StringName]:
		var out: Array[StringName] = []
		out.assign(board_ids.get(place, []))
		return out

	func parts_done(id: StringName) -> Array[bool]:
		var out: Array[bool] = []
		out.assign(parts.get(id, []))
		return out

	func active() -> Array[StringName]:
		return small

	func request_data(id: StringName) -> OrderData:
		if Phase9Fixtures.LARGE_IDS.has(id):
			return Phase9Fixtures.large_request(id)
		var o := OrderData.new()
		o.id = id
		o.giver = &"carter"
		return o

	func title_of(id: StringName) -> String:
		return "Bitte %s" % id

	func days_left(id: StringName) -> int:
		return 2 if parts.has(id) or small.has(id) else -1


var quests: Quests
var hill: HillDouble
var orders: Orders


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": OPEN, "minute_of_day": 420})


func after_each() -> void:
	for n: Node in [quests, hill, orders]:
		if is_instance_valid(n):
			n.free()
	quests = null
	hill = null
	orders = null
	GameState.reset()


func _quests() -> void:
	quests = Quests.new()
	quests.config = Phase9Fixtures.quest_config()
	for d: QuestData in Phase9Fixtures.quests():
		quests.quest_table[d.id] = d
	tree.root.add_child(quests)


func _group(list: Array[Dictionary], group: StringName) -> Array:
	return list.filter(func(e: Dictionary) -> bool: return e.group == group)


func test_empty_without_systems() -> void:
	assert_eq(QuestLog.entries(tree), [] as Array[Dictionary])
	assert_eq(QuestLog.objective(tree), {})
	assert_eq(QuestLog.entries(null), [] as Array[Dictionary])


func test_chains_with_done_current_and_hidden_steps() -> void:
	_quests()
	GameState.set_flag(&"who_comes_up_complete", true)
	GameState.set_flag(&"q_light_day", OPEN - 12)
	quests.open_now(OPEN)
	quests.load_state({"open_day": OPEN, "open": ["q_who_knows", "q_letters"], "step": {"q_who_knows": "h6"},
			"done": {"q_who_knows": ["h1", "h2", "h3", "h4", "h5"]}, "choices": {"q_who_knows": {"h5": "confide_washer"}},
			"notes": {"pocket_decided": []}})
	var list := QuestLog.entries(tree)
	var main := _group(list, QuestLog.GROUP_MAIN)
	var side := _group(list, QuestLog.GROUP_SIDE)
	assert_eq([main.size(), side.size()], [1, 1], "q_case not open in this state")
	var e: Dictionary = main[0]
	assert_eq([e.id, e.title, e.giver, e.line, e.state], [&"q_who_knows", "Wer weiß, wann?", &"priest", "Was wird aus Johann?", &"open"])
	assert_eq(e.days_left, 6, "deadline light + 17 = day 68: 63…68")
	var steps: Array = e.steps
	assert_eq(steps.map(func(s: Dictionary) -> StringName: return s.state), [&"done", &"done", &"done", &"done", &"done", &"current"])
	assert_eq([steps[4].choice, steps[4].choice_label], [&"confide_washer", "Liesel Dorn"], "a choice as its label")
	assert_eq(steps[5].hint, "Johann sitzt an Gretes Grab oder auf der Bank vor dem Haus.")
	var letters_steps: Array = side[0].steps
	assert_eq(letters_steps.map(func(s: Dictionary) -> String: return s.title), ["Ein Brief in der Tasche", "…", "…", "…", "…"],
			"future steps stay hidden")
	assert_eq(list.map(func(x: Dictionary) -> StringName: return x.group), [&"main", &"side"], "group order")


func test_ended_chain_shows_its_ending() -> void:
	_quests()
	GameState.set_flag(&"p9_open", true)
	quests.load_state({"open_day": OPEN, "open": ["q_who_knows"], "done": {"q_who_knows": ["h1"]}, "choices": {"q_who_knows": {"h6": "silent"}},
			"ending": {"q_who_knows": "silent"}})
	var e: Dictionary = QuestLog.entries(tree)[0]
	assert_eq([e.state, e.line, e.ending, e.days_left], [&"ended", "Geschwiegen", &"silent", -1])
	assert_eq(e.closing_line, "Du hast die Liste gelesen und zugeklappt. Das Dorf hat sie nie gesehen. Das Licht schon.")


func test_requests_orders_friendship_and_owed() -> void:
	hill = HillDouble.new()
	hill.board_ids = {&"gate": [&"hrl_ferry_graves"]}
	hill.parts = {&"hrl_ferry_graves": [true, false, false]}
	hill.small = [&"hr_lenz_stone"] as Array[StringName]
	tree.root.add_child(hill)
	orders = Orders.new()
	orders.config = Phase9Fixtures.orders_config()
	for o: OrderData in Phase7Fixtures.orders():
		orders.order_table[o.id] = o
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		orders.order_table[id] = Phase9Fixtures.order(id)
	tree.root.add_child(orders)
	var phase7: OrderData = Phase7Fixtures.orders()[0]
	for o: OrderData in [phase7, Phase8Fixtures.order(&"of_lenz_2"), Phase8Fixtures.order(&"of_quast_return_1"),
			Phase9Fixtures.order(&"oq_fenner_seal")]:
		orders._accept(o, OPEN)
	var list := QuestLog.entries(tree)
	assert_eq(list.map(func(x: Dictionary) -> StringName: return x.group),
			[&"large", &"hill", &"orders", &"orders", &"friend", &"owed"], "no chains without Quests (before p9_open)")
	var large: Dictionary = list[0]
	var ferry := Phase9Fixtures.large_request(&"hrl_ferry_graves")
	assert_eq([large.id, large.title, large.progress, large.days_left], [&"hrl_ferry_graves", ferry.title, Vector2i(1, 3), 2])
	assert_eq(large.line, (ferry.parts[1] as OrderData).title, "the first open part")
	assert_eq((large.steps as Array).map(func(s: Dictionary) -> StringName: return s.state), [&"done", &"open", &"open"])
	assert_eq([list[1].id, list[1].title], [&"hr_lenz_stone", "Bitte hr_lenz_stone"])
	var errand: Dictionary = list.filter(func(x: Dictionary) -> bool: return x.id == &"oq_fenner_seal")[0]
	assert_eq([errand.group, errand.errand, errand.days_left], [&"orders", true, 2], "days_limit 2 from today")


func test_pinned_entry_is_the_objective() -> void:
	_quests()
	GameState.set_flag(&"q_light_day", OPEN - 12)
	quests.open_now(OPEN)
	quests.note(&"kladde_read", "")
	quests.note(&"date_grave", "e_ott")
	assert_eq(QuestLog.objective(tree), {}, "nothing pinned")
	quests.pin(&"q_who_knows")
	var o := QuestLog.objective(tree)
	assert_eq([o.id, o.group, o.line, o.progress], [&"q_who_knows", &"main", "Wer liegt unter dem Datum?", Vector2i(1, 5)])
	var pinned := QuestLog.entries(tree).filter(func(e: Dictionary) -> bool: return e.pinned)
	assert_eq(pinned.size(), 1, "exactly one")
	quests.pin(&"gone_entry")
	assert_eq(QuestLog.objective(tree), {}, "a pinned entry that is gone shows nothing")
