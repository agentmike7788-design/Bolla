extends TestCase
## Phase 9 „Größere Bitten" (docs/PHASE9_DESIGN.md §2.3, §3.4, §5.1, §10) without the world: the config, the pool in
## data/hill_requests/large (12 = 8 gate + 4 parish board, 2–4 parts, German texts), the places (gate / parish board
## from village_open), one accepted at a time, the refill (next morning / second morning), parts in any order or in
## order, every new part kind (craft over craft_finished, gather, ghosts in one night, visit, meet, devotion,
## flowers), half done (half the coins, no reputation), missed, the deterministic pick, save / load in the middle of a
## request, and the small requests unchanged by an offered large one.

const GATE := &"gate"
const VILLAGE := &"village"

var _time: Dictionary
var _flags: Dictionary
var _nodes: Array[Node] = []
var _payments: Array[Array] = []
var _parts_signal: Array[Array] = []


func before_each() -> void:
	_time = TimeManager.save_state()
	TimeManager.reset()
	_flags = GameState.flags.duplicate(true)
	_payments.clear()
	_parts_signal.clear()
	EventBus.payment_received.connect(_on_pay)
	EventBus.hill_request_part.connect(_on_part)
	TimeManager.running = false


func after_each() -> void:
	EventBus.payment_received.disconnect(_on_pay)
	EventBus.hill_request_part.disconnect(_on_part)
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await tree.process_frame
	GameState.flags = _flags
	TimeManager.load_state(_time)


func _on_pay(amount: int, reason: String) -> void:
	_payments.append([amount, reason])


func _on_part(id: StringName, part: int, done: bool) -> void:
	_parts_signal.append([id, part, done])


## A HillRequests with the data requests `ids` (large ones from data/hill_requests/large), the real config; in the
## tree when `in_tree` (then it hears the EventBus).
func _hill(ids: Array[StringName], in_tree: bool = false) -> HillRequests:
	var h := HillRequests.new()
	h.config = Database.config(&"hill_requests_config") as HillRequestsConfig
	var table: Dictionary[StringName, OrderData] = {}
	for id: StringName in ids:
		var r := Database.large_request(id) as OrderData
		if r == null:
			r = Database.hill_request(id) as OrderData
		table[id] = r
	h.request_table = table
	if in_tree:
		tree.root.add_child(h)
	_nodes.append(h)
	return h


func _accepted(h: HillRequests, id: StringName, day: int = 2) -> void:
	TimeManager.set_time(day, 470)
	if h.state(id) == &"":
		assert_true(h.pin_large(id), "pin %s" % id)
	assert_true(h.accept(id), "accept %s (%s)" % [id, h.accept_reason(id)])


# --- config and pool --------------------------------------------------------------------------------

func test_config_values() -> void:
	var cfg := Database.config(&"hill_requests_config") as HillRequestsConfig
	assert_eq([cfg.large_start_day, cfg.large_slots_gate, cfg.large_slots_village, cfg.large_max_active,
			cfg.large_refill_days_early, cfg.large_refill_days_village, cfg.large_offer_days, cfg.large_fail_rep,
			cfg.large_reward_rel], [2, 1, 1, 1, 1, 2, 2, -2, 3], "§2.3.2")
	assert_almost(cfg.half_ratio, 0.5)


func test_pool_of_twelve() -> void:
	var gate := 0
	var village := 0
	var givers := {}
	for raw: Resource in Database.large_requests():
		var o := raw as OrderData
		assert_eq([o.category, o.size, o.kind], [OrderData.CATEGORY_HILL, OrderData.SIZE_LARGE, HillRules.KIND_LARGE], String(o.id))
		assert_true(o.parts.size() >= 2 and o.parts.size() <= 4, "%s: 2–4 parts" % o.id)
		assert_true(o.days_limit >= 2 and o.days_limit <= 3, "%s: deadline 2–3 days" % o.id)
		assert_true(o.reward_coins >= 2 and o.reward_coins <= 5, "%s: a few coins (%d)" % [o.id, o.reward_coins])
		assert_true(o.reward_rep >= 1 and o.reward_rep <= 2, "%s: reputation" % o.id)
		assert_true(o.cooldown_days >= 8 and o.cooldown_days <= 10, "%s: cooldown 8–10" % o.id)
		assert_true(o.title != "" and o.request_text != "" and o.thanks_text != "", "%s: texts" % o.id)
		assert_null(Database.hill_request(o.id), "%s is not a small request" % o.id)
		for p: OrderData in HillRules.parts_of(o):
			assert_true(p != null and p.kind in HillRules.part_kinds() and p.title != "", "%s: part" % o.id)
			if p.kind == HillRules.KIND_CRAFT:
				var recipe := Database.recipe(HillRules.recipe_of(p)) as RecipeData
				assert_true(recipe != null and recipe.station == &"workbench", "%s: workbench recipe" % o.id)
				assert_false(p.conditions.has("alt_recipe"), "%s: no cross fallback (gravestone_simple is a workbench recipe)" % o.id)
			if p.kind == HillRules.KIND_DELIVER:
				for item: StringName in p.items:
					assert_not_null(Database.item(item), "%s: item %s" % [o.id, item])
		if o.place == OrderData.PLACE_GATE:
			gate += 1
			assert_eq(o.requires_flag, &"", "%s: gate requests in every game" % o.id)
		else:
			village += 1
			assert_true(o.requires_flag in [&"village_open", &"p8_open", &"buildings_open"], "%s: village flag" % o.id)
		givers[o.id] = o.giver
	assert_eq([gate, village], [8, 4], "§2.3.3: 8 gate + 4 parish board")
	var candles := Database.large_request(&"hrv_church_candles") as OrderData
	assert_eq((candles.parts[0] as OrderData).kind, HillRules.KIND_DELIVER, "altar candles are bought and handed over")


# --- places, posting, accepting ----------------------------------------------------------------------

func test_gate_from_day_two_and_parish_board_from_village_open() -> void:
	GameState.set_flag(&"village_open", false)
	var h := _hill([&"hrl_crosses", &"hrv_church_candles", &"hr_osric_wood"] as Array[StringName])
	TimeManager.set_time(1, 470)
	h.post(1)
	assert_eq(h.large_board(GATE), [] as Array[StringName], "nothing on day 1")
	TimeManager.set_time(2, 470)
	h.post(2)
	assert_eq(h.large_board(GATE), [&"hrl_crosses"] as Array[StringName], "day 2: the large sheet at the gate")
	assert_eq(h.state(&"hrl_crosses"), HillRequests.STATE_OFFERED)
	assert_eq(h.large_board(VILLAGE), [] as Array[StringName], "the parish board only from village_open")
	assert_eq(HillRules.large_slots(h.config, VILLAGE, false), 0)
	assert_eq(HillRules.large_slots(h.config, VILLAGE, true), 1)
	assert_eq(HillRules.large_slots(h.config, GATE, true), 1)


func test_one_accepted_and_the_giver_rule() -> void:
	var h := _hill([&"hrl_crosses", &"hrl_lantern_path", &"hr_osric_wood"] as Array[StringName])
	_accepted(h, &"hrl_crosses")
	assert_eq(h.large_active(), [&"hrl_crosses"] as Array[StringName])
	assert_eq(h.parts_done(&"hrl_crosses"), [false, false] as Array[bool])
	assert_eq(h.accept_reason(&"hrl_crosses"), HillRules.TEXT_ACCEPTED)
	# A second large one (normally after a refill) cannot be accepted while one runs.
	h._large_board[GATE].append(&"hrl_lantern_path")
	assert_eq(h.accept_reason(&"hrl_lantern_path"), HillRules.TEXT_LARGE_ACTIVE, "only one accepted (§14: large_max_active 1)")
	# Osric's small request while his large one is accepted: never two of one giver at once.
	h.request_table[&"hrl_lantern_path"] = Database.large_request(&"hrl_lantern_path") as OrderData
	assert_true(h.pin(&"hr_osric_wood"))
	assert_eq(h.accept_reason(&"hr_osric_wood"), "", "Fenner's large request does not block Osric")


func test_offered_large_request_leaves_the_small_pick_alone() -> void:
	var h := _hill([&"hrl_crosses", &"hr_osric_wood", &"hr_esch_stone"] as Array[StringName])
	var before: Variant = h.offer_context(2).get("givers")
	assert_true(h.pin_large(&"hrl_crosses"))
	assert_eq(h.offer_context(2).get("givers"), before, "an offered large request changes nothing for the small ones")
	assert_true(h.accept(&"hrl_crosses"))
	assert_has(h.offer_context(2).get("givers"), &"mayor", "an accepted one blocks its giver")


func test_refill_next_morning_and_withdraw_after_two_days() -> void:
	var h := _hill([&"hrl_crosses"] as Array[StringName])
	TimeManager.set_time(2, 470)
	h.post(2)
	assert_eq(h.large_board(GATE), [&"hrl_crosses"] as Array[StringName])
	TimeManager.set_time(4, 360)
	h.apply_morning(4)
	assert_eq(h.large_board(GATE), [] as Array[StringName], "taken down after large_offer_days 2")
	assert_eq(h.history(), [] as Array[Dictionary], "an unanswered one leaves no log entry")
	h._large_ended.clear()
	TimeManager.set_time(4, 470)
	h.post(4)
	assert_eq(h.large_board(GATE), [&"hrl_crosses"] as Array[StringName], "the free place is filled again")
	assert_true(h.accept(&"hrl_crosses"))
	h.fail(&"hrl_crosses", 4)
	assert_eq(h._large_refill.get(GATE), [5], "before village_open: next morning")
	GameState.set_flag(&"village_open", true)
	assert_eq(HillRules.large_refill_days(h.config, true), 2, "from village_open: the second morning")


# --- parts --------------------------------------------------------------------------------------------

func test_craft_parts_in_order_and_the_hand_over() -> void:
	var h := _hill([&"hrl_crosses"] as Array[StringName], true)
	_accepted(h, &"hrl_crosses")
	assert_eq(h.open_parts(&"hrl_crosses"), [0] as Array[int], "parts_in_order: the deliver part waits")
	EventBus.craft_finished.emit(&"workbench", &"wooden_cross", 1)
	EventBus.craft_finished.emit(&"workbench", &"gravestone_simple", 1)
	assert_eq(h.part_progress(&"hrl_crosses", 0), 1, "only the recipe of the part counts")
	EventBus.craft_finished.emit(&"workbench", &"wooden_cross", 2)
	assert_eq(h.parts_done(&"hrl_crosses"), [true, false] as Array[bool], "3 crosses")
	assert_eq(_parts_signal, [[&"hrl_crosses", 0, true]], "hill_request_part")
	assert_eq(h.large_line(&"hrl_crosses"), "Bitte: Drei Kreuze für den Hohlweg – Bei Osric abgeben")
	var inv := Inventory.new()
	inv.add_item(&"wooden_cross", 3)
	assert_eq(h.ready_for(&"carter", inv), [&"hrl_crosses"] as Array[StringName], "Osric's cart takes it")
	assert_eq(h.turn_in(&"carter", inv), 1)
	assert_eq(inv.count(&"wooden_cross"), 0)
	assert_eq(inv.count(&"coin"), (Database.large_request(&"hrl_crosses") as OrderData).reward_coins, "the coins")
	assert_eq(h.large_active(), [] as Array[StringName], "completed")
	assert_eq(h.history().back().state, HillRequests.STATE_COMPLETED)
	inv.free()


func test_any_order_and_tend_targets() -> void:
	var h := _hill([&"hrl_ferry_graves"] as Array[StringName], true)
	_accepted(h, &"hrl_ferry_graves")
	assert_eq(h.part_targets(&"hrl_ferry_graves", 0).size(), 8, "the care spots of the Alter Hof")
	# Without a Cleanliness node every spot reads clean: a tend part whose spots are clean is done at once.
	assert_eq(h.parts_done(&"hrl_ferry_graves"), [true, false, false] as Array[bool], "clean spots: done at once")
	assert_eq(h.open_parts(&"hrl_ferry_graves"), [1, 2] as Array[int], "any order: decor and ghost both open")
	EventBus.ghost_spoke.emit("plot_01", &"calm", "…")
	assert_eq(h.parts_done(&"hrl_ferry_graves")[2], false, "the ghost has to be in the Alter Hof (no graveyard: no section)")
	assert_false(h.half_done(&"hrl_ferry_graves"), "1 of 3 is not half")
	h.set_part(&"hrl_ferry_graves", 2)
	assert_eq(h.parts_done(&"hrl_ferry_graves"), [true, false, true] as Array[bool])
	assert_true(h.half_done(&"hrl_ferry_graves"), "2 of 3 would be half done")
	h.set_part(&"hrl_ferry_graves", 2, false)
	assert_eq(_parts_signal.back(), [&"hrl_ferry_graves", 2, false])


func test_ghosts_in_one_night() -> void:
	var h := _hill([&"hrl_restless"] as Array[StringName], true)
	_accepted(h, &"hrl_restless", 4)
	TimeManager.set_time(4, 1335)
	EventBus.ghost_spoke.emit("plot_01", &"calm", "a")
	EventBus.ghost_spoke.emit("plot_01", &"calm", "a again")
	EventBus.ghost_spoke.emit("plot_02", &"calm", "b")
	TimeManager.set_time(5, 120)
	EventBus.ghost_spoke.emit("plot_03", &"calm", "c – after midnight, the same night")
	assert_has(_parts_signal, [&"hrl_restless", 0, true], "three distinct ghosts in one night")
	var h2 := _hill([&"hrl_restless"] as Array[StringName], true)
	var d := TimeManager.day + 1
	_accepted(h2, &"hrl_restless", d)
	TimeManager.set_time(d, 1335)
	EventBus.ghost_spoke.emit("plot_01", &"calm", "a")
	EventBus.ghost_spoke.emit("plot_02", &"calm", "b")
	TimeManager.set_time(d + 1, 1335)
	EventBus.ghost_spoke.emit("plot_03", &"calm", "c – the next night")
	assert_eq(h2.parts_done(&"hrl_restless")[0], false, "two nights do not add up")


func test_half_done_pays_half_and_missed_costs() -> void:
	var h := _hill([&"hrl_crosses", &"hrl_lantern_path"] as Array[StringName])
	_accepted(h, &"hrl_lantern_path")
	h.set_part(&"hrl_lantern_path", 0)
	h.set_part(&"hrl_lantern_path", 1)
	var deadline := h.deadline_day(&"hrl_lantern_path")
	assert_eq(deadline, 2 + 3, "accepted on day 2 with 3 days → the morning of day 5")
	TimeManager.set_time(deadline, 360)
	h.apply_morning(deadline)
	var r := Database.large_request(&"hrl_lantern_path") as OrderData
	assert_eq(h.history().back().state, HillRequests.STATE_HALF, "2 of 3 at the deadline: half done")
	assert_true(h.half_done(&"hrl_lantern_path"))
	assert_eq(_payments.back(), [floori(r.reward_coins / 2.0), HillRules.REASON_HALF % r.title], "half the coins, rounded down")
	var g := _hill([&"hrl_crosses"] as Array[StringName])
	g._accepted_day[&"hrl_crosses"] = 2
	_accepted(g, &"hrl_crosses", TimeManager.day)
	g._accepted_day[&"hrl_crosses"] = 2
	TimeManager.set_time(maxi(5, TimeManager.day), 470)
	g.apply_morning(5)
	assert_eq(g.history().back().state, HillRequests.STATE_FAILED, "nothing done: missed")
	assert_eq(HillRules.half_reached([true, false, false] as Array[bool], 0.5), false, "1 of 3 is not half")
	assert_eq(HillRules.half_reached([true, false] as Array[bool], 0.5), true, "1 of 2 is half")
	assert_eq(HillRules.half_reached([true, true] as Array[bool], 0.5), false, "all done is completed, not half")


func test_meet_devotion_flowers_visit_rules() -> void:
	var candles := Database.large_request(&"hrv_church_candles") as OrderData
	var devotion := candles.parts[1] as OrderData
	var meet := candles.parts[2] as OrderData
	assert_true(HillRules.part_done(devotion, HillRules.EV_DEVOTION, {"grave": "plot_01"}, {}))
	assert_false(HillRules.part_done(devotion, HillRules.EV_CRAFT, {}, {}))
	assert_true(HillRules.part_done(meet, HillRules.EV_MEET, {"npc": &"priest", "place": &"church", "minute": 1000}, {}))
	assert_false(HillRules.part_done(meet, HillRules.EV_MEET, {"npc": &"priest", "place": &"church", "minute": 700}, {}), "window")
	assert_false(HillRules.part_done(meet, HillRules.EV_MEET, {"npc": &"mayor", "place": &"church", "minute": 1000}, {}), "npc")
	var paul := Database.large_request(&"hrv_paul_day") as OrderData
	var flowers := paul.parts[1] as OrderData
	var st := {"targets": PackedStringArray(["l_01", "l_02"])}
	assert_eq(HillRules.part_gain(flowers, HillRules.EV_FLOWERS, {"grave": "l_01"}, st), 1)
	assert_false(HillRules.part_done(flowers, HillRules.EV_FLOWERS, {"grave": "l_01"}, st), "one of two graves")
	assert_true(HillRules.part_done(flowers, HillRules.EV_FLOWERS, {"grave": "l_02"}, {"targets": PackedStringArray(["l_02"])}))
	assert_eq(HillRules.flowers_kin(flowers, paul), &"kin_kehr")
	var lantern := Database.large_request(&"hrl_lantern_path") as OrderData
	var visit := lantern.parts[2] as OrderData
	assert_true(HillRules.part_done(visit, HillRules.EV_VISIT, {"place": &"gate_outside"}, {}))
	assert_false(HillRules.part_done(visit, HillRules.EV_VISIT, {"place": &"dropoff"}, {}))
	assert_eq(HillRules.visit_window(visit), Vector2i(1290, 1380), "21:30–23:00")
	assert_eq(HillRules.visit_minutes(visit), 20)
	assert_eq(HillRules.visit_action_label(visit), "Am Tor warten, bis Osric vorbeifährt")
	var h := _hill([&"hrl_lantern_path"] as Array[StringName])
	assert_eq(h.visit_block_reason(&"hrl_lantern_path", null), HillRules.TEXT_VISIT_NOT_RUNNING)
	_accepted(h, &"hrl_lantern_path")
	assert_eq(h.visit_block_reason(&"hrl_lantern_path", null), HillRules.TEXT_VISIT_BUSY, "no player")
	assert_eq(h.visit_prompt(&"hrl_lantern_path"), "[E] Am Tor warten, bis Osric vorbeifährt (20 Min)")


func test_gather_tend_chain_and_counting_rules() -> void:
	var widow := Database.large_request(&"hrl_widow_wood") as OrderData
	var gather := widow.parts[0] as OrderData
	assert_eq(HillRules.part_gain(gather, HillRules.EV_GATHER, {"item": &"wood", "amount": 4}, {"progress": 0}), 4)
	assert_eq(HillRules.part_gain(gather, HillRules.EV_GATHER, {"item": &"stone", "amount": 4}, {"progress": 0}), 0)
	assert_false(HillRules.part_done(gather, HillRules.EV_GATHER, {"item": &"wood", "amount": 4}, {"progress": 4}))
	assert_true(HillRules.part_done(gather, HillRules.EV_GATHER, {"item": &"wood", "amount": 2}, {"progress": 8}))
	var grave := Database.large_request(&"hrl_proper_grave") as OrderData
	var prep := grave.parts[1] as OrderData
	var marker := grave.parts[2] as OrderData
	var tend := grave.parts[3] as OrderData
	var rec := CorpseRecord.new()
	rec.id = "corpse_9"
	assert_false(HillRules.part_done(prep, HillRules.EV_BURIED, {"corpse": "corpse_9", "record": rec}, {"corpse": "corpse_9"}),
			"not washed")
	var g := GraveRecord.new()
	g.id = "plot_02"
	g.state = GraveRecord.State.MARKED
	g.marker_id = &"wooden_cross"
	assert_false(HillRules.part_done(marker, HillRules.EV_MARKER, {"record": g}, {}), "a cross is no gravestone")
	g.marker_id = &"gravestone_simple"
	assert_false(HillRules.part_done(marker, HillRules.EV_MARKER, {"record": g}, {"grave": "plot_03"}), "the dead's own grave")
	assert_true(HillRules.part_done(marker, HillRules.EV_MARKER, {"record": g}, {"grave": "plot_02"}))
	assert_false(HillRules.part_done(tend, HillRules.EV_CHECK, {}, {"assigned": false, "targets": PackedStringArray()}),
			"neighbours not known yet")
	assert_true(HillRules.part_done(tend, HillRules.EV_CHECK, {}, {"assigned": true, "targets": PackedStringArray()}),
			"no neighbour to tend")
	assert_false(HillRules.part_done(tend, HillRules.EV_CHECK, {}, {"assigned": true, "targets": PackedStringArray(["dirt_plot_01"]),
			"levels": {"dirt_plot_01": 1}}))
	assert_true(HillRules.part_done(tend, HillRules.EV_CHECK, {}, {"assigned": true, "targets": PackedStringArray(["dirt_plot_01"]),
			"levels": {"dirt_plot_01": 0}}))


func test_offer_conditions_per_part() -> void:
	var ctx := {"day": 3, "village": false, "on_board": [], "givers": [], "large_on_board": [], "large_ended": {},
			"levels": {"dirt_y03": 1}, "free_plots": 1, "marked": 1, "marked_by_section": {&"yard": 1}, "items": [],
			"open_obstacles": {}, "stations": [&"workbench"], "gather_items": [&"wood", &"stone"], "node_items": [],
			"pile_daily": {&"wood": 4, &"stone": 4}, "clear_yields": {}, "places": [&"gate_outside"], "chapel": false,
			"kin_graves": {}, "decor_room": {&"": 40, &"decor_grave_vase": 10, &"decor_flowerbed": 10, &"decor_lantern": 6,
			&"decor_bench_wood": 4}}
	var ferry := Database.large_request(&"hrl_ferry_graves") as OrderData
	assert_eq(HillRules.large_offer_block(ferry, ctx), "")
	var crosses := Database.large_request(&"hrl_crosses") as OrderData
	assert_eq(HillRules.large_offer_block(crosses, ctx), "")
	var widow := Database.large_request(&"hrl_widow_wood") as OrderData
	assert_eq(HillRules.large_offer_block(widow, ctx), "part 1: not enough to gather", "10 wood: piles 4 + nothing to clear")
	ctx["clear_yields"] = {&"wood": 6}
	assert_eq(HillRules.large_offer_block(widow, ctx), "", "… with 6 wood from clearing")
	var restless := Database.large_request(&"hrl_restless") as OrderData
	ctx["day"] = 4
	assert_eq(HillRules.large_offer_block(restless, ctx), "part 1: too few ghosts", "three ghosts need three graves with a marker")
	ctx["marked"] = 3
	assert_eq(HillRules.large_offer_block(restless, ctx), "")
	var bench := Database.large_request(&"hrl_bench_path") as OrderData
	assert_eq(HillRules.large_offer_block(bench, ctx), "part 1: nothing to clear")
	var proper := Database.large_request(&"hrl_proper_grave") as OrderData
	ctx["free_plots"] = 0
	assert_eq(HillRules.large_offer_block(proper, ctx), "part 1: no plot")
	ctx["free_plots"] = 1
	ctx["givers"] = [&"carter"]
	assert_eq(HillRules.large_offer_block(proper, ctx), "giver on board", "never two of one giver")
	ctx["givers"] = []
	ctx["large_ended"] = {&"hrl_proper_grave": 2}
	assert_eq(HillRules.large_offer_block(proper, ctx), "cooldown")
	ctx["large_ended"] = {}
	ctx["decor_room"] = {&"": 40, &"decor_lantern": 1}
	var lantern := Database.large_request(&"hrl_lantern_path") as OrderData
	ctx["day"] = 5
	assert_eq(HillRules.large_offer_block(lantern, ctx), "part 2: no room for decor", "two lanterns, one place left")
	ctx["places"] = []
	ctx["decor_room"] = {&"": 40, &"decor_lantern": 6}
	assert_eq(HillRules.large_offer_block(lantern, ctx), "part 3: no place", "the waypoint must exist")
	var bridge := Database.large_request(&"hrv_bridge_stones") as OrderData
	assert_eq(HillRules.large_offer_block(bridge, ctx), "village only")
	var candles := Database.large_request(&"hrv_church_candles") as OrderData
	ctx["village"] = true
	GameState.set_flag(&"buildings_open", true)
	assert_eq(HillRules.large_offer_block(candles, ctx), "part 2: no chapel")
	assert_false(HillRules.large_offerable(OrderData.new(), ctx), "a small / empty request is no large one")


func test_pick_is_deterministic() -> void:
	var pool: Array = Database.large_requests()
	var ctx := {"day": 3, "levels": {"dirt_y01": 2, "dirt_y03": 1}, "free_plots": 2, "marked": 1, "items": [],
			"marked_by_section": {&"yard": 1}, "stations": [&"workbench"], "pile_daily": {&"wood": 4, &"stone": 4},
			"places": [&"gate_outside"], "decor_room": {&"": 40, &"decor_grave_vase": 10, &"decor_flowerbed": 10,
			&"decor_lantern": 6, &"decor_bench_wood": 4}}
	var first := HillRules.large_pick(pool, ctx, GATE)
	assert_ne(first, &"", "something to pin on day 3")
	for i: int in 3:
		assert_eq(HillRules.large_pick(pool, ctx, GATE), first, "same day, same sheet")
	assert_eq(HillRules.large_pick(pool, ctx, VILLAGE), &"", "nothing for the parish board before the village")


func test_save_and_load_in_the_middle() -> void:
	var h := _hill([&"hrl_crosses", &"hrl_ferry_graves"] as Array[StringName])
	_accepted(h, &"hrl_crosses", 3)
	h._large_progress[&"hrl_crosses"][0] = 2
	h._ghost_night = {"night": 3, "count": 1, "graves": ["plot_01"]}
	var state := h.save_state()
	assert_eq(state.large_board, {"gate": ["hrl_crosses"], "village": []})
	assert_eq(state.parts, {"hrl_crosses": [false, false]})
	assert_eq(state.large_progress, {"hrl_crosses": [2, 0]})
	assert_eq(state.accepted_day.get("hrl_crosses"), 3)
	var h2 := _hill([&"hrl_crosses", &"hrl_ferry_graves"] as Array[StringName])
	h2.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(h2.save_state(), JSON.parse_string(JSON.stringify(state)), "round trip (JSON numbers)")
	assert_eq([h2.state(&"hrl_crosses"), h2.part_progress(&"hrl_crosses", 0), h2.accepted_day(&"hrl_crosses")],
			[HillRequests.STATE_ACCEPTED, 2, 3])
	# Tolerant: a shorter parts list, an unknown id, a large id at the wrong place, two accepted.
	var h3 := _hill([&"hrl_crosses", &"hrl_ferry_graves", &"hrv_bridge_stones"] as Array[StringName])
	h3.load_state({"large_board": {"gate": ["hrl_crosses", "nope", "hrv_bridge_stones"], "village": ["hrl_ferry_graves"]},
			"parts": {"hrl_crosses": [true], "hrl_ferry_graves": [true, true, true]}})
	assert_eq(h3.large_board(GATE), [&"hrl_crosses"] as Array[StringName], "one place, the request's own")
	assert_eq(h3.parts_done(&"hrl_crosses"), [true, false] as Array[bool], "filled up with false")
	assert_eq(h3.large_active().size(), 1, "at most one accepted")
	var h4 := _hill([&"hrl_crosses"] as Array[StringName])
	h4.load_state({})
	assert_eq([h4.large_board(GATE), h4.large_active()], [[] as Array[StringName], [] as Array[StringName]], "a save without large keys")
