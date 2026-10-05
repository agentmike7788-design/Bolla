extends TestCase
## Phase 8 (P4, docs/PHASE8_DESIGN.md §2.4, §3.4, §10): FriendRules + Friendship – thresholds 40 / 55 / 70,
## the day between steps, „gereizt" offers nothing, step conditions (apprentice_level_gte, flag:), the order
## variants (Liesel with / without insight_not_lorenz), the friend orders through Orders (meet / task /
## deliver / tend, category friend apart, at most 2), rewards per step (relationship, reputation, flag,
## stats, friend_step_completed, NpcLife.check_goal), the substitute dates (no deadline: the task still
## counts after the event), save / load. Fixture stories / orders (tests/fixtures/phase8), doubles for
## relationships, reputation, mood, apprentice, the player.

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


class LifeDouble extends Node:
	var moods: Dictionary = {}
	var goal_checks: int = 0

	func _init() -> void:
		add_to_group(&"npc_life")

	func mood(npc_id: StringName) -> StringName:
		return moods.get(npc_id, &"plain")

	func check_goal() -> bool:
		goal_checks += 1
		return false


class ApprenticeDouble extends Node:
	var levels: Dictionary = {}
	var hired: bool = false

	func _init() -> void:
		add_to_group(&"apprentice")

	func level(task_id: StringName) -> int:
		return int(levels.get(task_id, 0))

	func is_hired() -> bool:
		return hired


class PlayerDouble extends Node:
	var inventory: Inventory

	func _init() -> void:
		add_to_group(&"player")


var friendship: Friendship
var orders: Orders
var rel: RelDouble
var rep: RepDouble
var life: LifeDouble
var apprentice: ApprenticeDouble
var player: PlayerDouble
var steps_done: Array = []
var _day: int
var _minute: int
var _flags: Dictionary
var _stats: Dictionary
var _injected: Array[StringName] = []


func before_each() -> void:
	_day = TimeManager.day
	_minute = TimeManager.minute_of_day
	_flags = GameState.flags.duplicate(true)
	_stats = GameState.stats.duplicate(true)
	for id: StringName in Phase8Fixtures.ITEM_IDS:
		if not Database.has_item(id):
			Database._items[id] = Phase8Fixtures.item(id)
			_injected.append(id)
	TimeManager.day = 53
	TimeManager.minute_of_day = 600
	for flag: StringName in [&"insight_not_lorenz", &"robber_known", &"archive_key", &"promise_liesel_book"]:
		GameState.clear_flag(flag)
	for npc: StringName in Phase8Fixtures.STORY_NPCS:
		for n: int in [1, 2, 3]:
			GameState.clear_flag(StringName("friend_%s_%d" % [npc, n]))
	Phase8Fixtures.p8_open(null, 53).free()
	orders = Orders.new()
	orders.config = Phase8Fixtures.orders_config()
	orders.relationship_config = Phase8Fixtures.relationship_config()
	for o: OrderData in Phase7Fixtures.orders():
		orders.order_table[o.id] = o
	for id: StringName in Phase8Fixtures.order_ids():
		orders.order_table[id] = Phase8Fixtures.order(id)
	friendship = Friendship.new()
	friendship.relationship_config = Phase8Fixtures.relationship_config()
	for s: FriendStoryData in Phase8Fixtures.friend_stories():
		friendship.story_table[s.npc_id] = s
	for f: FavorData in Phase8Fixtures.favors():
		friendship.favor_table[f.id] = f
	rel = RelDouble.new()
	rel.vals = {&"innkeeper": 40, &"smith": 40, &"grocer": 40, &"priest": 40, &"mayor": 40, &"surgeon": 40, &"washer": 40}
	rep = RepDouble.new()
	life = LifeDouble.new()
	apprentice = ApprenticeDouble.new()
	player = PlayerDouble.new()
	player.inventory = Phase7Fixtures.inv_with()
	player.add_child(player.inventory)
	for n: Node in [orders, friendship, rel, rep, life, apprentice, player]:
		tree.root.add_child(n)
	steps_done.clear()
	EventBus.friend_step_completed.connect(_on_step)


func after_each() -> void:
	EventBus.friend_step_completed.disconnect(_on_step)
	for n: Node in [orders, friendship, rel, rep, life, apprentice, player]:
		n.free()
	for id: StringName in _injected:
		Database._items.erase(id)
	_injected.clear()
	TimeManager.day = _day
	TimeManager.minute_of_day = _minute
	GameState.flags.clear()
	GameState.flags.merge(_flags)
	GameState.stats.clear()
	GameState.stats.merge(_stats)


func _on_step(npc_id: StringName, step: int) -> void:
	steps_done.append([npc_id, step])


func _inv() -> Inventory:
	return player.inventory


# --- FriendRules ------------------------------------------------------------------------------------

func test_rules_thresholds_gap_mood_conditions() -> void:
	var s := Phase8Fixtures.friend_story(&"innkeeper")
	var ctx := {"open": true, "done": 0, "value": 39, "day": 53, "step_day": 0, "mood": &"plain", "running": false}
	assert_eq(FriendRules.offerable_step(s, ctx), 0, "39 < 40")
	ctx.value = 40
	assert_eq(FriendRules.offerable_step(s, ctx), 1, "Vertraut → step 1")
	ctx.open = false
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_CLOSED, "not before p8_open")
	ctx.open = true
	ctx.mood = &"cross"
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_MOOD, "„gereizt“ offers nothing")
	ctx.mood = &"low"
	ctx.running = true
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_RUNNING)
	ctx.running = false
	ctx.merge({"done": 1, "value": 54, "step_day": 53}, true)
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_THRESHOLD, "step 2 from 55")
	ctx.value = 55
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_GAP, "at the earliest a day after step 1")
	ctx.day = 54
	assert_eq(FriendRules.offerable_step(s, ctx), 2)
	ctx.merge({"done": 2, "value": 70, "step_day": 54, "day": 55, "conditions": func(c: String) -> bool: return c != "apprentice_level_gte:2"}, true)
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_CONDITIONS, "Rosine 3 needs Jakob „Geübt“")
	ctx.conditions = func(_c: String) -> bool: return true
	assert_eq(FriendRules.offerable_step(s, ctx), 3)
	ctx.value = 69
	assert_eq(FriendRules.offerable_step(s, ctx), 0, "step 3 from 70")
	ctx.merge({"done": 3, "value": 100}, true)
	assert_eq(FriendRules.step_block_reason(s, ctx), FriendRules.TEXT_DONE)


func test_rules_variants_and_own_conditions() -> void:
	var liesel := Phase8Fixtures.friend_story(&"washer").steps[0]
	assert_eq(FriendRules.order_for(liesel, func(id: StringName) -> bool: return id != &"of_liesel_1"), &"of_liesel_1_alt")
	assert_eq(FriendRules.order_for(liesel, func(_id: StringName) -> bool: return true), &"of_liesel_1")
	assert_eq(FriendRules.order_for(liesel, func(_id: StringName) -> bool: return false), &"")
	assert_eq(FriendRules.step_of_order(Phase8Fixtures.friend_story(&"washer"), &"of_liesel_1_alt"), 1)
	assert_eq(FriendRules.step_of_order(Phase8Fixtures.friend_story(&"washer"), &"of_liesel_3"), 3)
	assert_eq(FriendRules.step_of_order(Phase8Fixtures.friend_story(&"washer"), &"of_esch_1"), 0)
	assert_eq(FriendRules.own_condition("apprentice_level_gte:2", {&"rake": 2}), 1)
	assert_eq(FriendRules.own_condition("apprentice_level_gte:2", {&"rake": 1, &"weed": 1}), 0)
	assert_eq(FriendRules.own_condition("!apprentice_level_gte:2", {}), 1)
	assert_eq(FriendRules.own_condition("flag:robber_known", {}), -1, "the dialogue syntax answers the rest")
	var gains := Phase8Fixtures.relationship_config().gains
	assert_eq([FriendRules.reward_rel(null, 1, gains), FriendRules.reward_rel(null, 2, gains), FriendRules.reward_rel(null, 3, gains)],
			[6, 8, 10], "§2.4 +6 / +8 / +10")


# --- Friendship ------------------------------------------------------------------------------------

func test_rosine_story_three_steps_with_rewards() -> void:
	assert_eq(friendship.offerable_step(&"innkeeper"), 1)
	assert_true(friendship.accept_step(&"innkeeper"))
	assert_eq(orders.state(&"of_rosine_1"), Orders.STATE_ACCEPTED)
	assert_eq(friendship.offerable_step(&"innkeeper"), 0, "while the step runs")
	assert_false(friendship.accept_step(&"innkeeper"))
	# Jakob's first work day ends (the Apprentice reports it, or Orders sees it at 15:30).
	apprentice.hired = true
	TimeManager.day = 54
	TimeManager.minute_of_day = 931
	EventBus.time_tick.emit(54, 931)
	assert_eq(orders.state(&"of_rosine_1"), Orders.STATE_COMPLETED, "erledigt an seinem ersten Arbeitstag")
	assert_eq(friendship.step_done(&"innkeeper"), 1)
	assert_eq(steps_done, [[&"innkeeper", 1]])
	assert_true(GameState.flag_on(&"friend_innkeeper_1"))
	assert_eq(rel.value(&"innkeeper"), 46, "+6")
	assert_eq(GameState.get_stat(&"friend_steps"), 1)
	assert_eq(life.goal_checks, 1, "§1.5 checked on friend_step_completed")
	# Step 2 from 55, a day after step 1.
	rel.vals[&"innkeeper"] = 55
	assert_eq(friendship.offerable_step(&"innkeeper"), 0, "same day")
	assert_eq(friendship.step_block_reason(&"innkeeper"), FriendRules.TEXT_GAP)
	TimeManager.day = 55
	assert_eq(friendship.offerable_step(&"innkeeper"), 2)
	assert_true(friendship.accept_step(&"innkeeper"))
	_inv().add_item(&"memorial_plate", 1)
	assert_true(orders.turn_in(&"of_rosine_2", _inv()), "the plate to Lenz")
	assert_eq(friendship.step_done(&"innkeeper"), 2)
	assert_true(GameState.flag_on(&"friend_innkeeper_2"), "MemorialPlate shows from here")
	assert_has(rep.calls, ["change", 1, "Geschichte: Konrads Name"], "Ruf +1")
	assert_eq(rel.value(&"innkeeper"), 63, "+8")
	# Step 3 needs Jakob „Geübt“ in one task and 70.
	TimeManager.day = 56
	rel.vals[&"innkeeper"] = 70
	assert_eq(friendship.offerable_step(&"innkeeper"), 0, "no task at level 2")
	apprentice.levels[&"weed"] = 2
	assert_eq(friendship.offerable_step(&"innkeeper"), 3)
	assert_true(friendship.accept_step(&"innkeeper"))
	TimeManager.minute_of_day = 905
	orders.note_meet(&"innkeeper", &"apprentice_lunch")
	assert_eq(friendship.step_done(&"innkeeper"), 3)
	assert_eq(rel.value(&"innkeeper"), 80, "+10")
	assert_eq([friendship.steps_total(), friendship.full_stories()], [3, 1])
	assert_eq(friendship.offerable_step(&"innkeeper"), 0, "told")


func test_mood_cross_and_closed_phase() -> void:
	life.moods[&"smith"] = &"cross"
	assert_eq(friendship.offerable_step(&"smith"), 0)
	assert_eq(friendship.step_block_reason(&"smith"), FriendRules.TEXT_MOOD)
	life.moods[&"smith"] = &"low"
	assert_eq(friendship.offerable_step(&"smith"), 1)
	GameState.set_flag(&"p8_open", false)
	assert_eq(friendship.offerable_step(&"smith"), 0, "before p8_open")


func test_liesel_variants() -> void:
	assert_eq(friendship.step_order(&"washer"), &"of_liesel_1_alt", "without insight_not_lorenz: Wiebke")
	GameState.set_flag(&"insight_not_lorenz", true)
	assert_eq(friendship.step_order(&"washer"), &"of_liesel_1", "with it: Kaspar")
	assert_true(friendship.accept_step(&"washer"))
	TimeManager.minute_of_day = 700
	orders.note_task(&"name_line")
	assert_eq(friendship.step_done(&"washer"), 1)
	assert_true(GameState.flag_on(&"friend_washer_1"))


func test_step_conditions_from_the_dialogue_syntax() -> void:
	friendship.load_state({"steps": {"smith": 1}, "step_day": {"smith": 50}})
	rel.vals[&"smith"] = 60
	assert_eq(friendship.offerable_step(&"smith"), 0, "Esch 2 needs robber_known")
	GameState.set_flag(&"robber_known", true)
	assert_eq(friendship.offerable_step(&"smith"), 2)
	assert_true(friendship.accept_step(&"smith"))
	_inv().add_item(&"iron_bar", 4)
	_inv().add_item(&"charcoal", 2)
	assert_true(orders.turn_in(&"of_esch_2", _inv()))
	assert_eq(friendship.step_done(&"smith"), 2)
	assert_true(GameState.flag_on(&"friend_smith_2"), "the shop price 8 reads it")


func test_friend_orders_count_apart() -> void:
	# Four Phase-7 orders running do not block a friend order …
	GameState.set_flag(&"village_open", true)
	var p7 := 0
	for o: OrderData in Phase7Fixtures.orders():
		if p7 < 4 and not o.board and o.requires_flag == &"" and o.requires_orders.is_empty() and o.requires_tier == &"":
			orders._accept(o, 53)
			p7 += 1
	assert_eq(orders.active_count(&""), p7)
	assert_true(friendship.accept_step(&"smith"))
	assert_true(friendship.accept_step(&"priest"))
	assert_eq(orders.active_count(OrderData.CATEGORY_FRIEND), 2)
	# … but at most two friend orders run.
	assert_eq(orders.block_reason(&"of_quast_1"), OrderRules.TEXT_MAX_FRIEND)
	assert_false(friendship.accept_step(&"surgeon"))
	assert_eq(orders.state(&"of_quast_1"), &"")
	# Friend orders are no Phase-7 offers / counters.
	for id: StringName in orders.offers():
		assert_false(String(id).begins_with("of_"), "%s is offered by the Friendship only" % id)
	orders.note_task(&"archive_help")
	assert_eq(orders.state(&"of_lenz_2"), &"", "not accepted – nothing happens")


func test_meet_two_evenings_and_window() -> void:
	friendship.load_state({"steps": {"smith": 2}, "step_day": {"smith": 50}})
	rel.vals[&"smith"] = 70
	assert_true(friendship.accept_step(&"smith"))
	TimeManager.minute_of_day = 1000
	orders.note_meet(&"smith", &"v_linden")
	assert_eq(orders._progress.get("of_esch_3", 0), 0, "before 17:34")
	TimeManager.minute_of_day = 1060
	orders.note_meet(&"surgeon", &"v_linden")
	orders.note_meet(&"smith", &"v_bridge")
	assert_eq(orders._progress.get("of_esch_3", 0), 0, "wrong person / place")
	orders.note_meet(&"smith", &"v_linden")
	orders.note_meet(&"smith", &"v_linden")
	assert_eq(orders._progress.get("of_esch_3", 0), 1, "once per evening")
	assert_eq(orders.state(&"of_esch_3"), Orders.STATE_ACCEPTED)
	TimeManager.day = 54
	orders.note_meet(&"smith", &"v_linden")
	assert_eq(orders.state(&"of_esch_3"), Orders.STATE_COMPLETED, "two different evenings")
	assert_eq(friendship.full_stories(), 1)


func test_task_windows_flags_and_substitute_dates() -> void:
	# Lenz 2: the archive 16:00–18:00 only.
	friendship.load_state({"steps": {"priest": 1, "mayor": 1}, "step_day": {"priest": 50, "mayor": 50}})
	rel.vals[&"priest"] = 55
	rel.vals[&"mayor"] = 55
	assert_true(friendship.accept_step(&"priest"))
	TimeManager.minute_of_day = 900
	orders.note_task(&"archive_help")
	assert_eq(orders.state(&"of_lenz_2"), Orders.STATE_ACCEPTED, "outside the window")
	assert_eq(orders.task_open(&"archive_help"), &"of_lenz_2")
	TimeManager.minute_of_day = 1000
	orders.note_task(&"archive_help")
	assert_eq(friendship.step_done(&"priest"), 2)
	# Fenner 2: the meeting hands over the parish key (second way to the ledger).
	assert_true(friendship.accept_step(&"mayor"))
	TimeManager.minute_of_day = 970
	orders.note_meet(&"mayor", &"gv_l_12")
	assert_eq(friendship.step_done(&"mayor"), 2)
	assert_true(GameState.flag_on(&"archive_key"))
	# Lenz 3 at the Lichtgang has no deadline: missed, it still counts the evening after (Ersatz).
	TimeManager.day = 54
	rel.vals[&"priest"] = 70
	assert_true(friendship.accept_step(&"priest"))
	TimeManager.day = 59
	TimeManager.minute_of_day = 1150
	orders.apply_morning(59)
	assert_eq(orders.state(&"of_lenz_3"), Orders.STATE_ACCEPTED, "no deadline – the substitute date stays open")
	orders.note_task(&"lights_names")
	assert_eq(friendship.step_done(&"priest"), 3, "„Dann lesen wir sie eben drinnen.“")


func test_deliveries_or_items_gives_and_by_minute() -> void:
	# Fenner 1: one dropsy powder from Phase 7 counts too.
	assert_true(friendship.accept_step(&"mayor"))
	_inv().add_item(&"dropsy_powder", 1)
	assert_true(OrderRules.deliver_ready(orders.order_data(&"of_fenner_1"), _inv()))
	assert_true(orders.turn_in(&"of_fenner_1", _inv()))
	assert_eq(_inv().count(&"dropsy_powder"), 0)
	assert_eq(friendship.step_done(&"mayor"), 1)
	# Quast 2: the crate comes with the acceptance and goes to Osric by 07:40.
	friendship.load_state({"steps": {"surgeon": 1}, "step_day": {"surgeon": 50}})
	rel.vals[&"surgeon"] = 55
	var crate_data := Phase8Fixtures.order(&"of_quast_2").duplicate(true) as OrderData
	crate_data.conditions["gives"] = {&"quast_crate": 1}
	orders.order_table[&"of_quast_2"] = crate_data
	assert_true(friendship.accept_step(&"surgeon"))
	assert_eq(_inv().count(&"quast_crate"), 1, "the sealed crate")
	TimeManager.minute_of_day = 500
	assert_false(orders.turn_in(&"of_quast_2", _inv()), "too late for the cart")
	TimeManager.day = 54
	TimeManager.minute_of_day = 455
	assert_true(orders.turn_in(&"of_quast_2", _inv()))
	assert_eq(friendship.step_done(&"surgeon"), 2)


func test_data_matches_the_fixtures() -> void:
	# data/ = the W0 fixtures (+ Quast's crate handed over with the acceptance).
	for s: FriendStoryData in Phase8Fixtures.friend_stories():
		var d := Database.friend_story(s.npc_id) as FriendStoryData
		assert_not_null(d, String(s.npc_id))
		if d == null:
			continue
		assert_eq(d.steps.size(), 3)
		for i: int in 3:
			assert_eq([d.steps[i].min_value, d.steps[i].order_ids, d.steps[i].reward_rel, d.steps[i].reward_flag],
					[s.steps[i].min_value, s.steps[i].order_ids, s.steps[i].reward_rel, s.steps[i].reward_flag], "%s %d" % [s.npc_id, i + 1])
	for id: StringName in Phase8Fixtures.order_ids():
		var o := Database.order_data(id) as OrderData
		assert_not_null(o, String(id))
		if o != null:
			assert_eq([o.category, o.kind, o.giver], [&"friend", Phase8Fixtures.order(id).kind, Phase8Fixtures.order(id).giver], String(id))
	assert_eq(Database.order_data(&"of_quast_2").conditions.get("gives"), {&"quast_crate": 1})
	var plate := Database.recipe(&"memorial_plate") as RecipeData
	assert_not_null(plate)
	if plate != null:
		assert_eq([plate.station, plate.craft_minutes, plate.requires_flag], [&"mason", 40, &"friend_innkeeper_2"])


func test_save_load_round_trip() -> void:
	assert_true(friendship.accept_step(&"innkeeper"))
	friendship.load_state({"steps": {"innkeeper": 2, "smith": 3, "washer": 9}, "step_day": {"innkeeper": 54},
			"favor_day": {"smith": 55}, "owed": {"smith": "of_esch_return_1"}, "owed_day": {"smith": 56},
			"return_for": {"smith": 55}, "locked_until": {"grocer": 70}, "shield": 60, "watch_night": 57,
			"prayer": {"grave": "l_02", "from": 55, "until": 58}, "ware": {"item": "wax_wreath", "day": 56, "price": 5},
			"wash": {"day": 57, "minute": 580, "minutes": 60, "corpse": "corpse_0031"}, "loan_until": 65, "morning_day": 56})
	var saved := friendship.save_state()
	assert_eq(saved.steps, {"innkeeper": 2, "smith": 3, "washer": 3}, "steps clamped to 3")
	var other := Friendship.new()
	other.load_state(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(other.save_state(), saved, "JSON round trip")
	assert_eq([other.step_done(&"smith"), other.favor_owed(&"smith"), other.steps_total(), other.full_stories()],
			[3, &"of_esch_return_1", 8, 2])
	other.load_state({"steps": "x", "owed": {"a": 3}, "shield": -4, "prayer": "?", "wash": {"day": "x"}})
	assert_eq([other.steps_total(), other.favor_owed(&"a"), other.save_state().shield, other.save_state().prayer], [0, &"", 0, {}])
	other.free()
