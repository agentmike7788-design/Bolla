extends TestCase
## Phase 7 (P3, docs/PHASE7_DESIGN.md §2.5, §3.4, §10): OrderRules + Orders – all six kinds; offers
## (flag, predecessors, tier, the stranger rule, teaching / standing), max_active 4, deadlines at 06:00,
## failing (relationship −4, fail_rel, reputation order_failed), burial conditions (wait / broken /
## done), unharvested fails on harvesting, stone match, tend mornings, the board (deterministic,
## cooldown, expiring), reward once, save / load. Fixture orders (tests/fixtures/phase7/orders) and
## doubles for relationships, reputation, corpses, graves.

const COIN := &"coin"


class RelDouble extends Relationships:
	var vals: Dictionary = {}
	var calls: Array = []

	func value(npc_id: StringName) -> int:
		return int(vals.get(npc_id, 0))

	func add(npc_id: StringName, delta: int, reason: String) -> int:
		calls.append([npc_id, delta, reason])
		vals[npc_id] = clampi(value(npc_id) + delta, 0, 100)
		return value(npc_id)


class RepDouble extends Reputation:
	var calls: Array = []

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


class CorpsesDouble extends Node:
	var recs: Array[CorpseRecord] = []
	var delivered := PackedStringArray()
	var last_day := 0

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return recs

	func get_record(id: String) -> CorpseRecord:
		for r: CorpseRecord in recs:
			if r.id == id:
				return r
		return null

	func story_delivered() -> PackedStringArray:
		return delivered

	func story_last_day() -> int:
		return last_day


class GravesDouble extends Node:
	var by_id: Dictionary = {}
	var sections: Dictionary = {}

	func _init() -> void:
		add_to_group(&"graveyard")

	func get_grave(id: String) -> GraveRecord:
		return by_id.get(id)

	func section_of(id: String) -> StringName:
		return sections.get(id, &"yard")

	func plots_in_section(section_id: StringName) -> PackedStringArray:
		var out := PackedStringArray()
		for id: String in sections:
			if sections[id] == section_id:
				out.append(id)
		return out

	func graves() -> Array[GraveRecord]:
		var out: Array[GraveRecord] = []
		for id: String in by_id:
			out.append(by_id[id])
		return out


var orders: Orders
var rel: RelDouble
var rep: RepDouble
var corpses: CorpsesDouble
var graves: GravesDouble
var inv: Inventory
var changes: Array = []
var _day: int
var _minute: int
var _stats: Dictionary


func before_each() -> void:
	_day = TimeManager.day
	_minute = TimeManager.minute_of_day
	_stats = GameState.stats.duplicate()
	TimeManager.day = 41
	TimeManager.minute_of_day = 600
	for flag: StringName in [&"village_open", &"linden_granted", &"linden_consecrated", &"anatomy_known"]:
		GameState.clear_flag(flag)
	GameState.set_flag(&"village_open", true)
	orders = Orders.new()
	orders.config = Phase7Fixtures.orders_config()
	orders.relationship_config = Phase7Fixtures.relationship_config()
	for o: OrderData in Phase7Fixtures.orders():
		orders.order_table[o.id] = o
	rel = RelDouble.new()
	rel.vals = {&"mayor": 30, &"innkeeper": 25, &"smith": 15, &"grocer": 20, &"priest": 25, &"surgeon": 20, &"washer": 10, &"oldwoman": 30}
	rep = RepDouble.new()
	corpses = CorpsesDouble.new()
	graves = GravesDouble.new()
	for n: Node in [orders, rel, rep, corpses, graves]:
		tree.root.add_child(n)
	inv = Phase7Fixtures.inv_with()
	changes.clear()
	EventBus.order_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.order_changed.disconnect(_on_changed)
	for n: Node in [orders, rel, rep, corpses, graves]:
		n.free()
	inv.free()
	TimeManager.day = _day
	TimeManager.minute_of_day = _minute
	GameState.stats.clear()
	GameState.stats.merge(_stats)
	for flag: StringName in [&"village_open", &"linden_granted", &"linden_consecrated", &"anatomy_known"]:
		GameState.clear_flag(flag)


func _on_changed(id: StringName, state: StringName) -> void:
	changes.append([id, state])


func _o(id: StringName) -> OrderData:
	return Phase7Fixtures.order(id)


# --- OrderRules -----------------------------------------------------------------------------------

func test_offer_rules_flag_predecessor_tier_and_limit() -> void:
	var cfg := Phase7Fixtures.orders_config()
	var none := {"state": &"", "completed": [], "board": []}
	assert_eq(OrderRules.offer_block_reason(_o(&"o_rosine_berries"), none, &"acquainted", 0, cfg), "")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_rosine_tincture"), none, &"acquainted", 0, cfg), "Erst: Holunder für den Wein")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_rosine_tincture"), {"completed": [&"o_rosine_berries"]}, &"acquainted", 0, cfg), "")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_mangold_stone"), none, &"stranger", 0, cfg), "Erst „Bekannt“")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_mangold_stone"), none, &"acquainted", 0, cfg), "")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_lenz_poor"), none, &"acquainted", 0, cfg), "Erst „Vertraut“")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_rosine_berries"), none, &"acquainted", 4, cfg), OrderRules.TEXT_MAX_ACTIVE)
	assert_eq(OrderRules.offer_block_reason(_o(&"o_lenz_service"), {"flags": {}}, &"friend", 0, cfg), OrderRules.TEXT_NOT_YET, "after the consecration")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_lenz_service"), {"flags": {"linden_consecrated": true}}, &"stranger", 0, cfg), "")
	for s: StringName in [&"accepted", &"completed", &"failed"]:
		assert_ne(OrderRules.offer_block_reason(_o(&"o_rosine_berries"), {"state": s}, &"friend", 0, cfg), "", String(s))


func test_offer_rules_stranger_teaching_standing_board() -> void:
	var cfg := Phase7Fixtures.orders_config()
	var flags := {"village_open": true, "anatomy_known": true}
	# §2.4 Fremd: only the giver's first order.
	assert_eq(OrderRules.offer_block_reason(_o(&"o_esch_charcoal"), {"giver_started": 0, "flags": flags}, &"stranger", 0, cfg), "")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_quast_tincture"), {"giver_started": 1, "flags": flags}, &"stranger", 0, cfg), OrderRules.TEXT_STRANGER)
	# W0-Notizen 12: teaching / standing.
	assert_eq(OrderRules.offer_block_reason(_o(&"o_quast_antidote"), {"flags": flags}, &"acquainted", 0, cfg), OrderRules.TEXT_NEEDS_TEACHING)
	assert_eq(OrderRules.offer_block_reason(_o(&"o_quast_antidote"), {"flags": flags, "teachings": ["l_stomach"]}, &"acquainted", 0, cfg), "")
	assert_eq(OrderRules.offer_block_reason(_o(&"o_quast_cabinet"), {"flags": flags, "standing": 1}, &"acquainted", 0, cfg), OrderRules.TEXT_NEEDS_STANDING)
	assert_eq(OrderRules.offer_block_reason(_o(&"o_quast_cabinet"), {"flags": flags, "standing": 2}, &"acquainted", 0, cfg), "")
	# Board orders only while on today's board; a completed board order may come again.
	assert_eq(OrderRules.offer_block_reason(_o(&"ob_wood"), {"flags": flags, "board": []}, &"stranger", 0, cfg), OrderRules.TEXT_NOT_ON_BOARD)
	assert_eq(OrderRules.offer_block_reason(_o(&"ob_wood"), {"flags": flags, "board": [&"ob_wood"], "state": &"completed"}, &"stranger", 0, cfg), "")


func test_deliver_ready_with_substitutes() -> void:
	var tincture := _o(&"o_rosine_tincture")
	var a := Phase7Fixtures.inv_with({&"fever_tincture": 1})
	assert_false(OrderRules.deliver_ready(tincture, a))
	a.add_item(&"bitter_drops", 1)
	assert_true(OrderRules.deliver_ready(tincture, a), "§2.7: bitter drops replace the tincture")
	a.free()
	var poor := _o(&"o_lenz_poor")
	var b := Phase7Fixtures.inv_with({&"honey_cake": 4, COIN: 11})
	assert_false(OrderRules.deliver_ready(poor, b), "12 coins")
	b.add_item(COIN, 1)
	assert_true(OrderRules.deliver_ready(poor, b))
	b.free()


func test_bury_result_wait_broken_done() -> void:
	var h := _o(&"o_hagedorn_place")
	graves.sections = {"l_01": &"linden", "plot_01": &"yard"}
	var r := Phase5Fixtures.corpse(81, &"old_age", &"d1_hagedorn")
	assert_eq(OrderRules.bury_result(h, r, null), &"wait", "not buried yet")
	var g := GraveRecord.new()
	g.id = "l_01"
	g.state = GraveRecord.State.FILLED
	r.dress = &"shroud"
	assert_eq(OrderRules.bury_result(h, r, g), &"broken", "buried in a shroud, not the gown")
	r.dress = &"gown"
	assert_eq(OrderRules.bury_result(h, r, g), &"wait", "no marker yet")
	g.state = GraveRecord.State.MARKED
	g.marker_id = &"wooden_cross"
	assert_eq(OrderRules.bury_result(h, r, g), &"wait", "a stone with poppy can still come")
	var d := StoneDesign.new()
	d.shape = &"stone_stele"
	d.ornament = &"orn_poppy"
	g.design = d.to_dict()
	assert_eq(OrderRules.bury_result(h, r, g), &"done")
	var wrong := GraveRecord.new()
	wrong.id = "plot_01"
	wrong.state = GraveRecord.State.MARKED
	wrong.design = d.to_dict()
	assert_eq(OrderRules.bury_result(h, r, wrong), &"broken", "wrong section")
	r.harvested = [&"hair"] as Array[StringName]
	assert_eq(OrderRules.bury_result(h, r, null), &"broken", "unharvested broken at once")
	var service := _o(&"o_lenz_service")
	var s := Phase5Fixtures.corpse()
	assert_eq(OrderRules.bury_result(service, s, g), &"broken", "buried without a service")
	s.service_held = true
	assert_eq(OrderRules.bury_result(service, s, g), &"done")
	assert_true(OrderRules.dress_matches(&"gown", &"shroud"), "a gown is more than a shroud")
	assert_false(OrderRules.dress_matches(&"shroud", &"gown"))


func test_stone_matches_the_conditions() -> void:
	var o := _o(&"o_mangold_stone")
	var g := GraveRecord.new()
	g.id = "old_08"
	g.state = GraveRecord.State.OLD
	assert_false(OrderRules.stone_matches(o, g), "no stone")
	var d := StoneDesign.new()
	d.shape = &"stone_stele"
	d.ornament = &"orn_poppy"
	g.design = d.to_dict()
	assert_false(OrderRules.stone_matches(o, g), "inscription missing")
	d.inscription = &"ins_rest"
	g.design = d.to_dict()
	assert_true(OrderRules.stone_matches(o, g))
	g.id = "old_01"
	assert_false(OrderRules.stone_matches(o, g), "another grave")


func test_board_pick_is_deterministic_without_doubles_and_with_cooldown() -> void:
	var pool := Phase7Fixtures.orders(true)
	var a := OrderRules.board_pick(pool, 45, {}, 2)
	assert_eq(a.size(), 2)
	assert_ne(a[0], a[1])
	assert_eq(OrderRules.board_pick(pool, 45, {}, 2), a, "same day, same picks")
	var days := {}
	for day: int in range(40, 60):
		days[OrderRules.board_pick(pool, day, {}, 2)] = true
	assert_true(days.size() > 3, "the board changes over the days")
	var history := {a[0]: 44}
	assert_false(OrderRules.board_pick(pool, 45, history, 6).has(a[0]), "cooldown 3 days")
	assert_true(OrderRules.board_pick(pool, 47, history, 6).has(a[0]), "back after the cooldown")
	assert_eq(OrderRules.rel_tier(14, Phase7Fixtures.relationship_config()), &"stranger")
	assert_eq([OrderRules.rel_tier(15, null), OrderRules.rel_tier(40, null), OrderRules.rel_tier(70, null)], [&"acquainted", &"trusted", &"friend"])


# --- Orders ---------------------------------------------------------------------------------------

func test_accept_turn_in_reward_once() -> void:
	assert_true(orders.offers(&"innkeeper").has(&"o_rosine_berries"))
	assert_false(orders.offers(&"innkeeper").has(&"o_rosine_tincture"), "needs the berries first")
	assert_true(orders.accept(&"o_rosine_berries"))
	assert_eq([orders.state(&"o_rosine_berries"), orders.accepted_day(&"o_rosine_berries")], [&"accepted", 41])
	assert_false(orders.turn_in(&"o_rosine_berries", inv), "nothing to hand over")
	inv.add_item(&"elderberries", 9)
	var coins := inv.count(COIN)
	var done := GameState.get_stat(&"orders_done")
	assert_true(orders.turn_in(&"o_rosine_berries", inv))
	assert_eq([inv.count(&"elderberries"), inv.count(COIN) - coins], [1, 6], "8 berries off, 6 coins in")
	assert_eq(orders.state(&"o_rosine_berries"), &"completed")
	assert_has(rel.calls, [&"innkeeper", 8, "Auftrag: Holunder für den Wein"])
	assert_eq(GameState.get_stat(&"orders_done"), done + 1)
	assert_has(changes, [&"o_rosine_berries", &"completed"])
	assert_false(orders.turn_in(&"o_rosine_berries", inv), "once")
	orders.complete(&"o_rosine_berries")
	assert_eq(GameState.get_stat(&"orders_done"), done + 1, "the reward comes once")
	assert_true(orders.offers(&"innkeeper").has(&"o_rosine_tincture"), "now the tincture")
	assert_eq([orders.done_count(), orders.done_givers()], [1, PackedStringArray(["innkeeper"])])


func test_accept_flag_extra_rel_and_rep() -> void:
	assert_true(orders.accept(&"o_fenner_linden"))
	assert_true(GameState.flag_on(&"linden_granted"), "accept_flag")
	assert_true(orders.accept(&"o_fenner_well"))
	inv.add_item(&"workstone", 4)
	assert_true(orders.turn_in(&"o_fenner_well", inv))
	assert_has(rel.calls, [&"mayor", 6, "Auftrag: Die Brunnenfassung"])
	assert_has(rel.calls, [&"smith", 4, "Auftrag: Die Brunnenfassung"])
	assert_has(rep.calls, ["change", 1, "Auftrag: Die Brunnenfassung"])


func test_four_active_at_most() -> void:
	rel.vals[&"smith"] = 20
	for id: StringName in [&"o_rosine_berries", &"o_esch_charcoal", &"o_fenner_well", &"o_quast_tincture"]:
		assert_true(orders.accept(id), String(id))
	assert_eq(orders.active().size(), 4)
	assert_eq(orders.block_reason(&"o_fenner_linden"), OrderRules.TEXT_MAX_ACTIVE)
	assert_false(orders.accept(&"o_fenner_linden"))
	assert_true(orders.offers(&"mayor").has(&"o_fenner_linden"), "still shown as an offer")


func test_donate_order_notes_the_coins() -> void:
	rel.vals[&"priest"] = 45
	assert_true(orders.accept(&"o_lenz_poor"))
	inv.add_item(&"honey_cake", 4)
	inv.add_item(COIN, 12)
	var spent := GameState.get_stat(&"coins_spent_donation")
	assert_true(orders.turn_in(&"o_lenz_poor", inv))
	assert_eq(GameState.get_stat(&"coins_spent_donation"), spent + 12)
	assert_eq(inv.count(&"honey_cake"), 0)


func test_turn_in_with_a_substitute() -> void:
	orders.load_state({"states": {"o_rosine_berries": "completed", "o_rosine_tincture": "accepted"}, "accepted_day": {"o_rosine_tincture": 41}})
	inv.add_item(&"fever_tincture", 1)
	inv.add_item(&"bitter_drops", 3)
	assert_true(orders.turn_in(&"o_rosine_tincture", inv))
	assert_eq([inv.count(&"fever_tincture"), inv.count(&"bitter_drops")], [0, 2])


func test_deadline_fails_at_six_in_the_morning() -> void:
	rel.vals[&"smith"] = 20
	assert_true(orders.accept(&"o_esch_charcoal"))
	orders.apply_morning(45)
	assert_eq(orders.state(&"o_esch_charcoal"), &"accepted", "day 45 < 41 + 5")
	orders.apply_morning(46)
	assert_eq(orders.state(&"o_esch_charcoal"), &"failed")
	assert_has(rel.calls, [&"smith", -4, "Auftrag versäumt: Kohle für die Esse"])
	assert_true(rep.calls.has(["event", &"order_failed", "Auftrag versäumt: Kohle für die Esse"])
			or rep.calls.has(["change", -1, "Auftrag versäumt: Kohle für die Esse"]))
	assert_false(orders.accept(&"o_esch_charcoal"), "personal orders do not come back")


func test_hagedorn_order_accepted_on_arrival_and_failed_by_harvest() -> void:
	var r := Phase5Fixtures.corpse(81, &"old_age", &"d1_hagedorn", 48 * 1440 - 1440 + 460)
	r.id = "c_d1"
	corpses.recs.append(r)
	corpses.delivered = PackedStringArray(["d1_hagedorn"])
	corpses.last_day = 48
	orders.apply_morning(48)
	assert_eq([orders.state(&"o_hagedorn_place"), orders.accepted_day(&"o_hagedorn_place")], [&"accepted", 48], "at the latest when she arrives")
	assert_eq(orders.deadline_day(&"o_hagedorn_place"), 51)
	r.harvested = [&"heart"] as Array[StringName]
	orders.note_harvest("c_d1")
	assert_eq(orders.state(&"o_hagedorn_place"), &"failed")
	assert_has(rel.calls, [&"washer", -10, "Auftrag versäumt: Wiebke Hagedorns letzter Wunsch"])
	assert_has(rel.calls, [&"priest", -5, "Auftrag versäumt: Wiebke Hagedorns letzter Wunsch"])


func test_hagedorn_order_deadline_counts_from_her_arrival() -> void:
	assert_true(orders.accept(&"o_hagedorn_place"), "first talk with her")
	assert_eq(orders.deadline_day(&"o_hagedorn_place"), 0, "no deadline while she lives")
	orders.apply_morning(47)
	assert_eq(orders.state(&"o_hagedorn_place"), &"accepted")
	var r := Phase5Fixtures.corpse(81, &"old_age", &"d1_hagedorn", 47 * 1440 + 460)
	r.id = "c_d1"
	corpses.recs.append(r)
	corpses.delivered = PackedStringArray(["d1_hagedorn"])
	orders.apply_morning(49)
	assert_eq(orders.deadline_day(&"o_hagedorn_place"), 51, "3 days from day 48")
	# Buried in the Lindenacker in the gown under a poppy stone → done.
	graves.sections["l_03"] = &"linden"
	var g := GraveRecord.new()
	g.id = "l_03"
	g.state = GraveRecord.State.MARKED
	g.corpse_id = "c_d1"
	var d := StoneDesign.new()
	d.shape = &"stone_cross"
	d.ornament = &"orn_poppy"
	g.design = d.to_dict()
	graves.by_id["l_03"] = g
	r.dress = &"gown"
	orders.note_grave_completed("l_03", "c_d1")
	assert_eq(orders.state(&"o_hagedorn_place"), &"completed")
	assert_has(rel.calls, [&"washer", 8, "Auftrag: Wiebke Hagedorns letzter Wunsch"])
	assert_eq(orders.done_givers(), PackedStringArray(["oldwoman"]))


func test_next_delivery_is_the_first_corpse_after_acceptance() -> void:
	GameState.set_flag(&"linden_consecrated", true)
	var before := Phase5Fixtures.corpse(50, &"fever", &"", 40 * 1440 + 460)
	before.id = "c_before"
	corpses.recs.append(before)
	TimeManager.day = 41
	TimeManager.minute_of_day = 900
	assert_true(orders.accept(&"o_lenz_service"))
	var first := Phase5Fixtures.corpse(60, &"fever", &"", 41 * 1440 + 460)
	first.id = "c_first"
	var second := Phase5Fixtures.corpse(61, &"fever", &"", 42 * 1440 + 460)
	second.id = "c_second"
	corpses.recs.append_array([first, second])
	var g := GraveRecord.new()
	g.id = "l_01"
	g.state = GraveRecord.State.MARKED
	g.corpse_id = "c_before"
	graves.by_id["l_01"] = g
	before.service_held = true
	orders.note_grave_completed("l_01", "c_before")
	assert_eq(orders.state(&"o_lenz_service"), &"accepted", "arrived before the acceptance")
	second.service_held = true
	orders.note_grave_completed("l_01", "c_second")
	assert_eq(orders.state(&"o_lenz_service"), &"accepted", "not the next delivery")
	orders.note_grave_completed("l_01", "c_first")
	assert_eq(orders.state(&"o_lenz_service"), &"failed", "the next delivery without a service")


func test_stone_order_completes_on_the_stone() -> void:
	rel.vals[&"grocer"] = 20
	assert_true(orders.accept(&"o_mangold_stone"))
	var g := GraveRecord.new()
	g.id = "old_08"
	g.state = GraveRecord.State.OLD
	graves.by_id["old_08"] = g
	orders.note_stone_set("old_08")
	assert_eq(orders.state(&"o_mangold_stone"), &"accepted")
	var d := StoneDesign.new()
	d.shape = &"stone_stele"
	d.ornament = &"orn_poppy"
	d.inscription = &"ins_rest"
	g.design = d.to_dict()
	orders.note_stone_set("old_08")
	assert_eq(orders.state(&"o_mangold_stone"), &"completed")
	assert_has(rel.calls, [&"grocer", 10, "Auftrag: Ein Stein für die Mutter"])


func test_tend_needs_mornings_in_a_row() -> void:
	GameState.set_flag(&"linden_consecrated", true)
	orders.load_state({"states": {"ob_tend": "accepted"}, "accepted_day": {"ob_tend": 41}, "board_day": 41})
	graves.sections = {"l_01": &"linden"}
	var g := GraveRecord.new()
	g.id = "l_01"
	g.state = GraveRecord.State.MARKED
	graves.by_id["l_01"] = g
	orders.apply_morning(42)
	assert_eq(orders.state(&"ob_tend"), &"accepted", "1/2")
	orders.apply_morning(43)
	assert_eq(orders.state(&"ob_tend"), &"completed", "two mornings")
	assert_eq(orders.done_givers(), PackedStringArray(["council"]))


func test_board_offers_each_morning_and_expire() -> void:
	orders.apply_morning(42)
	var first := orders.board()
	assert_eq(first.size(), 2)
	for id: StringName in first:
		assert_eq(orders.state(id), &"offered")
		assert_false(id in [&"ob_gown", &"ob_tend"], "need linden_consecrated")
	orders.apply_morning(42)
	assert_eq(orders.board(), first, "idempotent per day")
	assert_true(orders.accept(first[0]))
	orders.apply_morning(43)
	assert_eq(orders.state(first[1]), &"" if not orders.board().has(first[1]) else &"offered", "yesterday's offer expires")
	assert_eq(orders.state(first[0]), &"failed", "deadline 1 = until the next morning")
	assert_false(orders.board().has(first[0]), "cooldown")


func test_board_order_repeats_and_counts_each_time() -> void:
	orders.load_state({"states": {"ob_wood": "offered"}, "board": ["ob_wood"], "board_day": 41})
	assert_true(orders.accept(&"ob_wood"))
	inv.add_item(&"wood", 20)
	assert_true(orders.turn_in(&"ob_wood", inv))
	assert_has(rel.calls, [&"mayor", 3, "Auftrag: Holz für den Gemeindezaun"])
	orders.load_state(orders.save_state().merged({"states": {"ob_wood": "offered"}, "board": ["ob_wood"]}, true))
	assert_true(orders.accept(&"ob_wood"))
	assert_true(orders.turn_in(&"ob_wood", inv))
	assert_eq(orders.done_count(), 2, "a board order counts every time")


func test_save_load_round_trip() -> void:
	rel.vals[&"smith"] = 20
	assert_true(orders.accept(&"o_esch_charcoal"))
	assert_true(orders.accept(&"o_fenner_linden"))
	orders.apply_morning(42)
	var state := orders.save_state()
	var back := Orders.new()
	back.order_table = orders.order_table
	back.load_state(JSON.parse_string(JSON.stringify(state)) as Dictionary)
	assert_eq(JSON.stringify(back.save_state()), JSON.stringify(state), "JSON round trip")
	assert_eq([back.state(&"o_esch_charcoal"), back.accepted_day(&"o_esch_charcoal"), back.board()], [&"accepted", 41, orders.board()])
	back.load_state({"states": {"o_esch_charcoal": "eaten", "nope": "accepted"}, "board_day": "x"})
	assert_eq([back.state(&"o_esch_charcoal"), back.state(&"nope"), back.save_state().board_day], [&"", &"", 0], "tolerant")
	back.free()


# --- Phase 8 (P4, docs/PHASE8_DESIGN.md §3.4, W0-Notizen 12) -------------------------------------------

func _specimens_with(held_in_inv: bool) -> Specimens:
	var specimens := Specimens.new()
	tree.root.add_child(specimens)
	var spec := Phase7Fixtures.specimen(&"heart", SpecimenRecord.CONTAINER_JAR, 0.9, null, TimeManager.total_minutes())
	specimens.load_state({"next": 9999, "records": [spec.to_dict()]})
	if held_in_inv:
		assert_true(inv.add_unique(&"specimen_jar", spec.uid))
	return specimens


func test_specimen_handover_goes_to_the_cabinet() -> void:
	var specimens := _specimens_with(true)
	var uid: String = specimens.held()[0]
	orders._accept(orders.order_data(&"o_quast_specimen"), 41)
	assert_true(orders.turn_in(&"o_quast_specimen", inv))
	assert_false(inv.has_uid(uid))
	assert_eq(specimens.get_record(uid).state, &"lectured", "W0-Notizen 12: in Quast's cabinet, no „held“ record left")
	assert_eq(specimens.held(), PackedStringArray())
	specimens.free()


func test_post_load_repairs_the_orphaned_handover() -> void:
	var specimens := _specimens_with(false)
	var orphan: String = specimens.held()[0]
	var kept := Phase7Fixtures.specimen(&"lung", SpecimenRecord.CONTAINER_JAR, 0.9, null, TimeManager.total_minutes())
	var data := specimens.save_state()
	(data.records as Array).append(kept.to_dict())
	specimens.load_state(data)
	tree.root.add_child(inv)
	assert_true(inv.add_unique(&"specimen_jar", kept.uid))
	orders.post_load()
	assert_eq(specimens.get_record(orphan).state, &"held", "no completed specimen order – nothing to repair")
	orders.load_state({"states": {"o_quast_specimen": "completed"}, "progress": {"done:o_quast_specimen": 1}})
	orders.post_load()
	assert_eq(specimens.get_record(orphan).state, &"lectured", "the Phase-7 handover state repaired")
	assert_eq(specimens.get_record(kept.uid).state, &"held", "a piece in a pack stays")
	tree.root.remove_child(inv)
	specimens.free()


func test_friend_orders_kinds_and_category() -> void:
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	orders.config = Phase8Fixtures.orders_config()
	assert_false(orders.offers().has(&"of_esch_1"), "the Friendship offers friend orders")
	assert_eq(OrderRules.friend_block_reason(_p8(&"of_esch_1"), {"state": &"completed"}, 0, orders.config), "", "may run again")
	assert_eq(OrderRules.friend_block_reason(_p8(&"of_esch_1"), {"state": &"accepted"}, 0, orders.config), OrderRules.TEXT_ACCEPTED)
	assert_eq(OrderRules.friend_block_reason(_p8(&"of_esch_1"), {}, 2, orders.config), OrderRules.TEXT_MAX_FRIEND)
	assert_eq(OrderRules.friend_block_reason(_p8(&"of_liesel_1"), {"flags": {}}, 0, orders.config), OrderRules.TEXT_NOT_YET)
	assert_true(OrderRules.meet_matches(_p8(&"of_quast_3"), &"surgeon", &"v_bridge", 1100))
	assert_false(OrderRules.meet_matches(_p8(&"of_quast_3"), &"surgeon", &"v_bridge", 1200), "after 19:30")
	assert_true(OrderRules.task_matches(_p8(&"of_liesel_2"), &"vigil", 10), "no window – any time (the next corpse)")
	assert_false(OrderRules.task_matches(_p8(&"of_liesel_2"), &"archive_help", 1290))
	assert_eq(OrderRules.gives(_p8(&"of_mangold_3")), {&"flower_seedlings": 3} as Dictionary[StringName, int])
	assert_true(OrderRules.time_ok(_p8(&"of_quast_2"), 460))
	assert_false(OrderRules.time_ok(_p8(&"of_quast_2"), 461))
	# A finished friend order: no Phase-7 counters, no Phase-7 penalty on failing.
	var done_before := GameState.get_stat(&"orders_done")
	orders._accept(_p8(&"of_lenz_2"), 41)
	orders.complete(&"of_lenz_2")
	assert_eq([orders.done_count(), GameState.get_stat(&"orders_done")], [0, done_before])
	orders._accept(_p8(&"of_quast_return_1"), 41)
	orders.fail(&"of_quast_return_1")
	assert_eq([orders.state(&"of_quast_return_1"), rel.calls, rep.calls], [&"failed", [], []], "the Friendship applies −6")


func test_friend_tend_on_a_story_grave_with_candle_nights() -> void:
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	var r := Phase5Fixtures.corpse(81, &"old_age", &"d1_hagedorn")
	corpses.recs.append(r)
	var g := GraveRecord.new()
	g.id = "l_01"
	g.state = GraveRecord.State.MARKED
	g.corpse_id = r.id
	graves.by_id["l_01"] = g
	graves.sections["l_01"] = &"linden"
	var care := CandleCareDouble.new()
	tree.root.add_child(care)
	orders._accept(_p8(&"of_liesel_1_alt"), 41)
	for day: int in [42, 43, 44]:
		orders.apply_morning(day)
	assert_eq(orders.state(&"of_liesel_1_alt"), Orders.STATE_ACCEPTED, "three mornings, but no candle night yet")
	care.lit_nights = ["l_01"]
	orders.apply_morning(45)
	assert_eq(orders.state(&"of_liesel_1_alt"), Orders.STATE_COMPLETED, "Wiebke: tended + a night with a candle")
	care.free()


func test_flowers_fresh_three_kinless_graves_three_mornings() -> void:
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	var care := CandleCareDouble.new()
	tree.root.add_child(care)
	for i: int in 4:
		var g := GraveRecord.new()
		g.id = "old_%02d" % (i + 1)
		g.state = GraveRecord.State.MARKED
		graves.by_id[g.id] = g
	orders._accept(_p8(&"of_mangold_3"), 41)
	care.fresh = ["old_01", "old_02"]
	orders.apply_morning(42)
	assert_eq(orders._progress.get("of_mangold_3"), 0, "two of three")
	care.fresh = ["old_01", "old_02", "old_03"]
	orders.apply_morning(43)
	orders.apply_morning(44)
	assert_eq(orders.state(&"of_mangold_3"), Orders.STATE_ACCEPTED)
	orders.apply_morning(45)
	assert_eq(orders.state(&"of_mangold_3"), Orders.STATE_COMPLETED, "fresh until the third morning")
	care.free()


func _p8(id: StringName) -> OrderData:
	return Phase8Fixtures.order(id)


class CandleCareDouble extends Node:
	var lit_nights: Array = []
	var fresh: Array = []

	func _init() -> void:
		add_to_group(&"grave_care")

	func lit_last_night(grave_id: String) -> bool:
		return lit_nights.has(grave_id)

	func flowers_state(grave_id: String) -> StringName:
		return &"fresh" if fresh.has(grave_id) else &""
