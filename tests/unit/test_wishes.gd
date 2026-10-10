extends TestCase
## P2 (docs/PHASE8_DESIGN.md §2.2.5, §3.4, §5.1, §10): wishes and tips – the choice (order, grave seed, one per
## grave, 3 open, line only on a designed stone with < 4 lines, tend only when neglected, goodwill ≥ 2),
## fulfilment by kind, the tip 1–3 with the cap of 4 a day, coins on the stone (they stay, taken once), handed
## in the talk, villagers +4 relationship instead of coins (Esch's fittings once), failure without a reputation
## minus, an offered wish lapsing, save / load. Graveyard.append_inscription for the line wish.

const Harness := preload("res://tests/unit/visitors_harness.gd")

var h: Harness
var cfg: VisitorConfig
var payments: Array = []
var states: Array = []


func before_each() -> void:
	GameState.reset()
	cfg = Phase8Fixtures.visitor_config()
	TimeManager.load_state({"day": 53, "minute_of_day": 300})
	h = Harness.new()
	h.setup(tree)
	h.households_only()
	payments.clear()
	states.clear()
	EventBus.payment_received.connect(_on_payment)
	EventBus.wish_changed.connect(_on_wish)


func after_each() -> void:
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.wish_changed.disconnect(_on_wish)
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _on_payment(amount: int, reason: String) -> void:
	payments.append([amount, reason])


func _on_wish(wish_id: String, state: StringName) -> void:
	states.append([wish_id, state])


## Satisfies a wish of `kind` at `grave` now.
func _fulfil(kind: StringName, grave: String) -> void:
	match kind:
		&"tend":
			h.clean.levels["dirt_" + grave] = 0
		&"flowers":
			h.inv.add_item(&"flower_seedlings", 1)
			assert_true(h.care.plant(grave, h.inv), "planted")
		&"candle":
			var keep := TimeManager.total_minutes()
			TimeManager.load_state({"day": TimeManager.day, "minute_of_day": 1000})
			assert_true(h.care.light_free(grave), "lit")
			TimeManager.load_state({"day": floori(keep / 1440.0) + 1, "minute_of_day": keep % 1440})
		&"line":
			var w := h.visitors.open_wishes()[0]
			assert_true(h.graveyard.append_inscription(grave, WishRules.line_of(w)), "chiselled")
		&"vase":
			h.vase(grave, Vector2(0.6, -1.2))


## Plans and runs `day` until 21:00.
func _day(day: int) -> void:
	h.plan(day)
	h.clock(1260)


# --- rules ---------------------------------------------------------------------------------------

func test_tip_rules() -> void:
	assert_eq(WishRules.tip(5, 9, 0, cfg), 1, "tip_base")
	assert_eq(WishRules.tip(6, 9, 0, cfg), 2, "goodwill ≥ 6")
	assert_eq(WishRules.tip(6, 15, 0, cfg), 3, "quality ≥ 15")
	assert_eq(WishRules.tip(6, 15, 3, cfg), 1, "cap 4 a day")
	assert_eq(WishRules.tip(6, 15, 4, cfg), 0, "beyond the cap only thanks")


func test_choice_order_and_applicability() -> void:
	TimeManager.load_state({"day": 55, "minute_of_day": 600})
	h.bury("l_01", &"house_kehr", 50)
	var first := WishRules.choose("l_01", &"kin_kehr", 55, tree)
	assert_ne(first, &"")
	assert_ne(first, &"w_tend", "tend only when neglected")
	assert_false(String(first).begins_with("w_line"), "line only on a designed stone")
	assert_eq(WishRules.choose("l_01", &"kin_kehr", 55, tree), first, "deterministic")
	# Fulfil kinds one after the other: the choice moves on and never returns a fulfilled one.
	var seen: Array = []
	for i: int in 3:
		var id := WishRules.choose("l_01", &"kin_kehr", 55, tree)
		assert_false(seen.has(id), "not again: %s" % id)
		seen.append(id)
		_fulfil((Database.wish(id) as WishData).kind, "l_01")
	assert_eq(WishRules.choose("l_01", &"kin_kehr", 55, tree), &"", "flowers, candle, vase done – nothing left")
	h.clean.levels["dirt_l_01"] = 2
	assert_eq(WishRules.choose("l_01", &"kin_kehr", 55, tree), &"w_tend", "neglected: tend")
	h.clean.levels["dirt_l_01"] = 0
	h.design_stone("l_01", 3)
	var line := WishRules.choose("l_01", &"kin_kehr", 55, tree)
	assert_true(String(line).begins_with("w_line_"), "a designed stone with 3 lines: line")
	h.design_stone("l_01", 4)
	assert_eq(WishRules.choose("l_01", &"kin_kehr", 55, tree), &"", "4 lines: no line")


func test_rotation_by_grave_seed() -> void:
	var firsts := {}
	for plot: String in ["l_01", "l_02", "l_03", "l_04", "l_05", "l_09", "l_10"]:
		h.bury(plot, &"house_kehr", 50)
		firsts[WishRules.choose(plot, &"kin_kehr", 55, tree)] = true
	assert_true(firsts.size() >= 2, "the grave seed turns the order: %s" % str(firsts.keys()))


func test_fulfilled_by_kind() -> void:
	h.bury("l_01", &"house_kehr", 50)
	var w := {"kind": "flowers", "grave_id": "l_01", "day": 55, "candle_seen": false}
	assert_false(WishRules.fulfilled(w, tree))
	_fulfil(&"flowers", "l_01")
	assert_true(WishRules.fulfilled(w, tree), "fresh flowers")
	TimeManager.load_state({"day": 58, "minute_of_day": 600})
	assert_false(WishRules.fulfilled(w, tree), "wilted is not enough")
	h.care.remove_flowers("l_01")
	h.inv.add_item(&"wax_wreath", 1)
	h.care.lay_wreath("l_01", h.inv)
	assert_true(WishRules.fulfilled(w, tree), "a wax wreath counts")
	var c := {"kind": "candle", "grave_id": "l_01", "day": 58, "candle_seen": false}
	assert_false(WishRules.fulfilled(c, tree))
	TimeManager.load_state({"day": 57, "minute_of_day": 1000})
	h.care.light_free("l_01")
	TimeManager.load_state({"day": 59, "minute_of_day": 600})
	assert_false(WishRules.fulfilled(c, tree), "a candle before the wish does not count")
	TimeManager.load_state({"day": 59, "minute_of_day": 1000})
	TimeManager.advance(600)
	h.care.light_free("l_01")
	assert_true(WishRules.fulfilled(c, tree), "a night with a candle since the wish")
	var t := {"kind": "tend", "grave_id": "l_01", "day": 55}
	h.clean.levels["dirt_l_01"] = 2
	assert_false(WishRules.fulfilled(t, tree))
	h.clean.levels["dirt_l_01"] = 1
	assert_true(WishRules.fulfilled(t, tree), "care spot ≤ 1")
	var v := {"kind": "vase", "grave_id": "l_01", "day": 55}
	assert_false(WishRules.fulfilled(v, tree))
	h.vase("l_01", Vector2(0.9, 0.0))
	assert_true(WishRules.fulfilled(v, tree))
	h.design_stone("l_01", 2)
	var l := {"kind": "line", "grave_id": "l_01", "day": 55, "template": "w_line_1"}
	assert_false(WishRules.fulfilled(l, tree))
	assert_true(h.graveyard.append_inscription("l_01", "Ruhe sanft"))
	assert_true(WishRules.fulfilled(l, tree))


func test_append_inscription_rules() -> void:
	h.bury("l_01", &"house_kehr", 50)
	assert_false(h.graveyard.append_inscription("l_01", "Ruhe sanft"), "no designed stone")
	h.design_stone("l_01", 2)
	assert_true(h.graveyard.append_inscription("l_01", "Ruhe sanft"))
	assert_false(h.graveyard.append_inscription("l_01", "Ruhe sanft"), "the same line twice")
	assert_true(h.graveyard.append_inscription("l_01", "Unvergessen"))
	assert_false(h.graveyard.append_inscription("l_01", "Wir sehen uns wieder"), "4 lines")
	assert_eq(h.graveyard.get_grave("l_01").extra_lines, PackedStringArray(["Ruhe sanft", "Unvergessen"]))
	assert_eq(h.graveyard.stone_line_count("l_01"), 4)
	assert_true(h.graveyard.replace_name_line("l_01", "Kaspar Dorn"))
	assert_eq(StoneDesign.from_dict(h.graveyard.get_grave("l_01").design).text[0], "Kaspar Dorn", "the name line cut anew")
	assert_false(h.graveyard.replace_name_line("l_01", "Kaspar Dorn"))
	assert_false(h.graveyard.replace_name_line("l_05", "X"), "no stone")


# --- the flow ------------------------------------------------------------------------------------

func _offer_at_first_visit() -> Dictionary:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.clock(620)
	var visit := h.visit_id(&"kin_kehr")
	assert_eq(h.visitors.visit_state(visit).phase, &"waiting")
	assert_true(h.visitors.wish_offerable(visit))
	var card := h.visitors.offer_wish(visit)
	assert_false(card.is_empty())
	assert_eq(card.keys(), ["wish_id", "kind", "grave_id", "text"])
	assert_eq(card.grave_id, "l_01")
	assert_eq(h.visitors.offer_wish(visit), card, "the same wish again")
	return card


func test_wish_done_tip_on_the_stone_once() -> void:
	var card := _offer_at_first_visit()
	assert_true(h.visitors.accept_wish(card.wish_id))
	assert_false(h.visitors.accept_wish(card.wish_id), "once")
	h.clock(1260)
	assert_eq(h.visitors.open_wishes().size(), 1, "accepted stays open")
	_fulfil(card.kind, "l_01")
	var due := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	_day(due)
	assert_eq(h.visitors.open_wishes(), [])
	assert_eq(h.visitors.done_wishes().size(), 1)
	assert_eq(GameState.get_stat(&"wishes_done"), 1)
	assert_eq(h.rep.count(&"wish_done"), 1)
	assert_has(states, [card.wish_id, &"done"])
	var stone := h.visitors.tip_on_stone("l_01")
	assert_true(stone.x >= 1 and stone.x <= 3, "1–3 coins: %d" % stone.x)
	assert_eq(stone.y, Database.kin_list().map(func(k: Resource) -> StringName: return k.get(&"kin_id")).find(&"kin_kehr"))
	assert_eq(h.visitors.tip_giver("l_01"), "Martha Kehr")
	TimeManager.advance(3000)
	assert_eq(h.visitors.tip_on_stone("l_01").x, stone.x, "the coins stay")
	assert_eq(h.visitors.take_tip("l_01", h.inv), stone.x)
	assert_eq(h.inv.count(&"coin"), stone.x)
	assert_eq(payments, [[stone.x, "Trinkgeld"]])
	assert_eq(GameState.get_stat(&"tips_coins"), stone.x)
	assert_eq(h.visitors.take_tip("l_01", h.inv), 0, "once")
	assert_eq(h.life.goal_checks, 1, "NpcLife.check_goal")


func test_tip_handed_in_the_talk() -> void:
	var card := _offer_at_first_visit()
	h.visitors.accept_wish(card.wish_id)
	h.clock(1260)
	_fulfil(card.kind, "l_01")
	var due := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	h.plan(due)
	var visit := h.visit_id(&"kin_kehr")
	h.walk_clock(620)
	assert_eq(h.visitors.visit_state(visit).phase, &"waiting", "she waits with the coins")
	var coins := h.visitors.tip_of(visit)
	assert_true(coins >= 1)
	assert_eq(h.visitors.hand_tip(visit, h.inv), coins)
	assert_eq(h.visitors.hand_tip(visit, h.inv), 0, "once")
	h.clock(1260)
	assert_eq(h.visitors.tip_on_stone("l_01").x, 0, "nothing left on the stone")
	assert_eq(h.inv.count(&"coin"), coins)


func test_tip_cap_four_a_day() -> void:
	h.bury("l_01", &"house_kehr", 40, 15)
	h.bury("l_02", &"house_brandt", 40, 15)
	TimeManager.load_state({"day": 58, "minute_of_day": 400})
	_fulfil(&"flowers", "l_01")
	_fulfil(&"flowers", "l_02")
	var wishes: Array = []
	for spec: Array in [["l_01", "kin_kehr"], ["l_02", "kin_brandt"]]:
		wishes.append({"wish_id": "w_%s" % spec[0], "kind": "flowers", "grave_id": spec[0], "kin_id": spec[1], "state": "accepted",
				"day": 55, "candle_seen": false, "template": "w_flowers"})
	var plan: Array = []
	for spec: Array in [["l_01", "kin_kehr", 570], ["l_02", "kin_brandt", 750]]:
		plan.append({"visit_id": "v_58_%s" % spec[1], "kin_id": spec[1], "graves": [spec[0]], "slot": spec[2], "start": spec[2],
				"travel": 13, "day": 58, "flowers": false, "laid": 0, "viewed": 0, "waits": false, "tip": 0, "ended": false,
				"noise": false, "offered": ""})
	h.visitors.load_state({"plan_day": 58, "plan": plan, "goodwill": {"kin_kehr": 9, "kin_brandt": 9}, "wishes": wishes,
			"next_wish": 3})
	h.clock(1260)
	assert_eq(h.visitors.done_wishes().size(), 2)
	assert_eq(h.visitors.tip_on_stone("l_01").x, 3, "goodwill ≥ 6 and quality ≥ 15: 3")
	assert_eq(h.visitors.tip_on_stone("l_02").x, 1, "the cap of 4 a day: only 1 more")
	assert_eq(h.rep.count(&"wish_done"), 2, "the thanks and the reputation still count")


func test_failed_wish_without_reputation_minus() -> void:
	var card := _offer_at_first_visit()
	h.visitors.accept_wish(card.wish_id)
	h.clock(1260)
	var gw := h.visitors.goodwill(&"kin_kehr")
	var due := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	if card.kind == &"tend":
		h.clean.levels["dirt_l_01"] = 3
	_day(due)
	assert_eq(GameState.get_stat(&"wishes_failed"), 1)
	assert_has(states, [card.wish_id, &"failed"])
	assert_eq(h.visitors.goodwill(&"kin_kehr"), gw - 2 + 1, "−2 (the look +1)")
	assert_eq(h.rep.count(&"wish_done"), 0)
	assert_eq(h.visitors.tip_on_stone("l_01").x, 0)


func test_offered_wish_lapses_with_the_visit() -> void:
	var card := _offer_at_first_visit()
	assert_eq(h.visitors.open_wishes().size(), 1)
	h.clock(1260)
	assert_eq(h.visitors.open_wishes(), [], "„Ich kann es nicht versprechen.\" – no consequences")
	assert_eq(GameState.get_stat(&"wishes_failed"), 0)
	assert_ne(card, {})


func test_limits_one_per_grave_three_open_goodwill() -> void:
	for spec: Array in [["l_01", &"house_kehr"], ["l_02", &"house_brandt"], ["l_03", &"house_ott"], ["l_04", &"house_sieber"]]:
		h.bury(spec[0], spec[1], 54)
	h.plan(55)
	var accepted := 0
	for minute: int in range(580, 1300, 5):
		h.clock(minute)
		for v: Dictionary in h.visitors.active_visits():
			if v.phase == &"waiting":
				var card := h.visitors.offer_wish(v.visit_id)
				if not card.is_empty() and h.visitors.accept_wish(card.wish_id):
					accepted += 1
	assert_eq(accepted, 3, "three visitors, three wishes")
	h.visitors.add_goodwill(&"kin_sieber", -10)
	assert_eq(h.visitors.goodwill(&"kin_sieber"), 0)
	var state := h.visitors.save_state()
	assert_eq((state.wishes as Array).size(), 3)
	# A fourth: no room (3 open) – and a second wish at the same grave never.
	var extra := {"plan_day": 56, "plan": [{"visit_id": "v_x", "kin_id": "kin_kehr", "graves": ["l_01"], "slot": 570, "phase": "waiting"}]}
	state.merge(extra, true)
	h.visitors.load_state(state)
	assert_eq(h.visitors.offer_wish("v_x"), {}, "3 open / one per grave")
	assert_false(h.visitors.wish_offerable("v_x"))


func test_villager_pays_with_relationship() -> void:
	h.all_kin()
	h.plan(55)
	h.clock(855)
	var visit := h.visit_id(&"kin_smith")
	assert_eq(h.visitors.visit_state(visit).phase, &"waiting", "Esch at old_01")
	var card := h.visitors.offer_wish(visit)
	assert_false(card.is_empty())
	h.visitors.accept_wish(card.wish_id)
	h.clock(1260)
	_fulfil(card.kind, "old_01")
	for day: int in range(56, 62):
		_day(day)
		if card.kind == &"flowers" and h.care.flowers_state("old_01") != &"fresh":
			h.care.refill()
			h.care.water("old_01")
	assert_eq(h.visitors.done_wishes().size(), 1, "Esch comes again on day 61")
	assert_has(h.rel.adds, [&"smith", 4], "relationship +4")
	assert_eq(h.visitors.tip_on_stone("old_01").x, 0, "no coins")
	assert_eq(h.inv.count(&"iron_fittings"), 0, "the player's inventory comes from the player node")
	assert_true(h.life.events.any(func(e: Array) -> bool: return e[0] == &"wish_done"), "NpcLife hears of it")


func test_save_load_wishes_and_stones() -> void:
	var card := _offer_at_first_visit()
	h.visitors.accept_wish(card.wish_id)
	h.clock(1260)
	var state := h.visitors.save_state()
	state.tips_on_stone = {"l_02": [2, "kin_brandt"]}
	h.visitors.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(h.visitors.open_wishes().size(), 1)
	assert_eq(h.visitors.tip_on_stone("l_02").x, 2)
	assert_eq(h.visitors.save_state().next_wish, int(state.next_wish))
	h.visitors.load_state({"wishes": [{"wish_id": "w_0009", "grave_id": "l_01", "state": "accepted"},
			{"wish_id": "w_0010", "grave_id": "l_01", "state": "accepted"}, "junk"], "tips_on_stone": {"x": [-1, "a"]}})
	assert_eq(h.visitors.open_wishes().size(), 1, "one wish per grave")
	assert_eq(h.visitors.stones(), PackedStringArray(), "negative coins dropped")
	assert_eq(h.visitors.save_state().next_wish, 10, "after the highest kept wish")
