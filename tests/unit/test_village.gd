extends TestCase
## Phase 7 (P3, docs/PHASE7_DESIGN.md §1.2, §1.5, §2.4, §2.5, §2.9, §10): Village – the unlock (morning,
## v5 load at once, v6 load waits, idempotent), the consecration (price by tier, tomorrow, 10:30,
## ExpansionManager.try_unlock), round and poor box once / twice per day, the mourning ribbon
## (deterministic, D1), the chapter exactly once (all four conditions, any order), save / load; the
## entities VillageBoard / PoorBox / RegisterCopy / MourningRibbon; the new stone on old_01 / old_08
## only with a stone order (state stays OLD).

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


class ExpansionDouble extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"expansion")

	func try_unlock(section_id: StringName) -> bool:
		calls.append(section_id)
		return true


class JournalDouble extends Node:
	var insights: Array = []
	var clues: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_insight(id: StringName) -> bool:
		return insights.has(id)

	func has_clue(id: StringName) -> bool:
		return clues.has(id)

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		clues.append(id)
		return true


class CorpsesDouble extends Node:
	var recs: Array[CorpseRecord] = []

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
		return PackedStringArray()


class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false
	var section_id: StringName = &"yard"


const FLAGS: Array[StringName] = [&"roof_and_earth_complete", &"village_open", &"village_open_day", &"linden_granted",
		&"linden_consecration_day", &"linden_consecrated", &"hagedorn_dead", &"name_in_village_complete"]

var village: Village
var rel: RelDouble
var rep: RepDouble
var nodes: Array[Node] = []
var inv: Inventory
var events: Array = []
var _day: int
var _minute: int
var _stats: Dictionary


func before_each() -> void:
	_day = TimeManager.day
	_minute = TimeManager.minute_of_day
	_stats = GameState.stats.duplicate()
	for flag: StringName in FLAGS:
		GameState.clear_flag(flag)
	_set_time(40, 420)
	village = Village.new()
	village.config = Phase7Fixtures.village_config()
	village.relationship_config = Phase7Fixtures.relationship_config()
	village.villager_ids = Phase7Fixtures.VILLAGER_IDS.duplicate()
	rel = RelDouble.new()
	rep = RepDouble.new()
	nodes = [village, rel, rep]
	for n: Node in nodes:
		tree.root.add_child(n)
	inv = Phase7Fixtures.inv_with({COIN: 40})
	events.clear()
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.ground_consecrated.connect(_on_consecrated)


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.ground_consecrated.disconnect(_on_consecrated)
	for n: Node in nodes:
		if is_instance_valid(n):
			n.free()
	inv.free()
	_set_time(_day, _minute)
	GameState.stats.clear()
	GameState.stats.merge(_stats)
	for flag: StringName in FLAGS:
		GameState.clear_flag(flag)


func _set_time(day: int, minute: int) -> void:
	TimeManager.day = day
	TimeManager.minute_of_day = minute


func _add(n: Node) -> Node:
	nodes.append(n)
	tree.root.add_child(n)
	return n


func _on_chapter(id: StringName) -> void:
	events.append(["chapter", id])


func _on_consecrated(id: StringName) -> void:
	events.append(["consecrated", id])


# --- unlock ---------------------------------------------------------------------------------------

func test_opens_on_the_first_morning_after_the_chapter() -> void:
	_set_time(37, 23 * 60 + 5)
	GameState.set_flag(&"roof_and_earth_complete", true)
	village.apply_morning(37)
	assert_false(village.is_open(), "the evening of the chapter")
	_set_time(38, 300)
	village.apply_morning(38)
	assert_false(village.is_open(), "05:00")
	_set_time(38, 360)
	village.apply_morning(38)
	assert_true(village.is_open(), "06:00 the next morning")
	assert_eq(GameState.get_flag(&"village_open_day"), 38)
	village.apply_morning(38)
	assert_eq(village.save_state().open_day, 38, "idempotent")


func test_nothing_opens_without_the_phase6_chapter() -> void:
	village.apply_morning(40)
	_set_time(41, 400)
	village.apply_morning(41)
	assert_false(village.is_open())
	village.load_state({})
	village.post_load()
	assert_false(village.is_open())


func test_a_v5_load_opens_at_once_a_v6_load_waits() -> void:
	GameState.set_flag(&"roof_and_earth_complete", true)
	_set_time(37, 23 * 60 + 10)
	village.load_state({})
	village.post_load()
	assert_true(village.is_open(), "§1.2: a migrated v5 save opens at once, even after 06:00")
	assert_eq(GameState.get_flag(&"village_open_day"), 37)
	GameState.clear_flag(&"village_open")
	GameState.clear_flag(&"village_open_day")
	var v6 := Village.new()
	v6.config = Phase7Fixtures.village_config()
	_add(v6)
	v6.load_state({"open_day": 0, "goal_done": false})
	v6.post_load()
	assert_false(v6.is_open(), "a v6 save keeps the morning rule")


# --- consecration ---------------------------------------------------------------------------------

func test_consecration_price_by_the_priests_tier() -> void:
	for spec: Array in [[0, 10], [25, 10], [40, 5], [69, 5], [70, 0], [100, 0]]:
		rel.vals[&"priest"] = spec[0]
		assert_eq(village.consecration_price(), spec[1], "relationship %d" % spec[0])


func test_pay_consecration_tomorrow_then_10_30() -> void:
	var expansion := _add(ExpansionDouble.new()) as ExpansionDouble
	rel.vals[&"priest"] = 25
	var spent := GameState.get_stat(&"coins_spent_consecration")
	assert_true(village.pay_consecration(inv))
	assert_eq(inv.count(COIN), 30)
	assert_eq(GameState.get_stat(&"coins_spent_consecration"), spent + 10)
	assert_eq(GameState.get_flag(&"linden_consecration_day"), 41, "tomorrow")
	assert_false(village.pay_consecration(inv), "once")
	village.apply_minute(40, 700)
	village.apply_minute(41, 629)
	assert_false(GameState.flag_on(&"linden_consecrated"), "before 10:30")
	village.apply_minute(41, 630)
	assert_true(GameState.flag_on(&"linden_consecrated"))
	assert_has(events, ["consecrated", &"linden"])
	assert_eq(expansion.calls, [&"linden"], "ExpansionManager.try_unlock")
	village.apply_minute(41, 700)
	assert_eq(expansion.calls.size(), 1, "once")


func test_consecration_free_for_a_friend_and_after_a_skipped_day() -> void:
	rel.vals[&"priest"] = 80
	var spent := GameState.get_stat(&"coins_spent_consecration")
	assert_true(village.pay_consecration(inv))
	assert_eq([inv.count(COIN), GameState.get_stat(&"coins_spent_consecration")], [40, spent], "free")
	village.apply_minute(43, 100)
	assert_true(GameState.flag_on(&"linden_consecrated"), "slept through the day")
	var poor := Phase7Fixtures.inv_with({COIN: 3})
	GameState.clear_flag(&"linden_consecration_day")
	GameState.clear_flag(&"linden_consecrated")
	rel.vals[&"priest"] = 10
	var fresh := Village.new()
	fresh.config = Phase7Fixtures.village_config()
	_add(fresh)
	assert_eq(fresh.consecration_block_reason(poor), Village.TEXT_NO_COINS)
	assert_false(fresh.pay_consecration(poor))
	poor.free()


# --- round & poor box -----------------------------------------------------------------------------

func test_round_once_a_day_for_everyone_in_the_inn() -> void:
	_set_time(40, 19 * 60)
	var inside := village.in_inn(19 * 60)
	assert_true(inside.has(&"innkeeper") and inside.has(&"priest") and inside.has(&"mayor"), str(inside))
	assert_false(inside.has(&"washer"), "Liesel spins at her cottage")
	var rounds := GameState.get_stat(&"rounds_bought")
	assert_true(village.buy_round(inv))
	assert_eq(inv.count(COIN), 35)
	assert_eq(GameState.get_stat(&"rounds_bought"), rounds + 1)
	for npc: StringName in inside:
		assert_has(rel.calls, [npc, 2, "Eine Runde im Holderkrug"])
	assert_eq(TimeManager.minute_of_day, 19 * 60 + 15, "15 minutes")
	assert_eq(village.round_block_reason(inv), Village.TEXT_ROUND_DONE)
	assert_false(village.buy_round(inv))
	_set_time(41, 19 * 60)
	assert_true(village.buy_round(inv), "the next day")


func test_poor_box_two_steps_a_day() -> void:
	var donations := GameState.get_stat(&"donations")
	assert_true(village.donate(inv))
	assert_true(village.donate(inv))
	assert_false(village.donate(inv), "two steps per day")
	assert_eq(village.donation_block_reason(inv), Village.TEXT_DONATION_DONE)
	assert_eq([inv.count(COIN), GameState.get_stat(&"donations") - donations, village.donations_today()], [30, 2, 2])
	assert_eq(rel.calls, [[&"mayor", 1, "Spende in die Armenkasse"], [&"mayor", 1, "Spende in die Armenkasse"]])
	assert_eq(rep.calls.size(), 2, "reputation +1 per step")
	assert_true(rep.calls[0] == ["event", &"donation", "Spende in die Armenkasse"] or rep.calls[0] == ["change", 1, "Spende in die Armenkasse"])
	_set_time(41, 420)
	assert_eq(village.donations_today(), 0)
	assert_true(village.donate(inv))


# --- mourning ribbon ------------------------------------------------------------------------------

func test_mourning_ribbon_is_deterministic_and_ends_with_the_burial() -> void:
	GameState.set_flag(&"village_open", true)
	GameState.set_flag(&"village_open_day", 40)
	var corpses := _add(CorpsesDouble.new()) as CorpsesDouble
	assert_eq(village.mourning_house(42), &"")
	var r := Phase5Fixtures.corpse(50, &"fever", &"", 41 * 1440 + 460)
	r.id = "c_1"
	r.seed = 1234
	corpses.recs.append(r)
	var house := village.mourning_house(42)
	assert_true(house in [&"house_kehr", &"house_brandt", &"house_ott", &"house_sieber", &"cottage_dorn"], String(house))
	assert_eq(village.mourning_house(42), house, "deterministic")
	assert_eq(village.mourning_house(41), &"", "not before the delivery day")
	_set_time(42, 600)
	var ribbon := MourningRibbon.new()
	ribbon.house_id = house
	_add(ribbon)
	assert_true(ribbon.visible)
	r.location = CorpseRecord.LOCATION_BURIED
	assert_eq(village.mourning_house(42), &"", "until buried")
	ribbon.refresh()
	assert_false(ribbon.visible)
	GameState.set_flag(&"hagedorn_dead", true)
	assert_eq(village.mourning_house(48), &"cottage_hagedorn", "D1 from 00:00 of her day")


# --- chapter --------------------------------------------------------------------------------------

func _goal_world() -> JournalDouble:
	var orders := Orders.new()
	orders.config = Phase7Fixtures.orders_config()
	for o: OrderData in Phase7Fixtures.orders():
		orders.order_table[o.id] = o
	_add(orders)
	var journal := JournalDouble.new()
	_add(journal)
	GameState.set_flag(&"village_open", true)
	return journal


func test_chapter_needs_all_four_conditions_once() -> void:
	var journal := _goal_world()
	var orders := get_tree_orders()
	village.check_goal()
	assert_eq(village.goal_progress().done, 0)
	GameState.set_flag(&"linden_consecrated", true)
	orders.load_state({"states": {"o_fenner_linden": "completed", "o_fenner_well": "completed", "o_rosine_berries": "completed",
			"o_esch_charcoal": "completed", "o_quast_tincture": "completed"}})
	rel.vals = {&"mayor": 45, &"innkeeper": 40, &"smith": 70}
	journal.insights = [&"i_deathbook"]
	village.check_goal()
	assert_false(GameState.flag_on(&"name_in_village_complete"), "5 orders")
	assert_eq(village.goal_progress().done, 3)
	orders.load_state({"states": {"o_fenner_linden": "completed", "o_fenner_well": "completed", "o_fenner_bridge": "completed",
			"o_fenner_dropsy": "completed", "o_rosine_berries": "completed", "o_rosine_tincture": "completed"}})
	village.check_goal()
	assert_false(GameState.flag_on(&"name_in_village_complete"), "6 orders but only 2 givers")
	orders.load_state({"states": {"o_fenner_linden": "completed", "o_fenner_well": "completed", "o_rosine_berries": "completed",
			"o_esch_charcoal": "completed", "o_quast_tincture": "completed", "ob_wood": "completed"}})
	rel.vals[&"smith"] = 39
	village.check_goal()
	assert_false(GameState.flag_on(&"name_in_village_complete"), "only two trusted")
	rel.vals[&"smith"] = 40
	village.check_goal()
	assert_true(GameState.flag_on(&"name_in_village_complete"))
	assert_eq(events.filter(func(e: Array) -> bool: return e[0] == "chapter"), [["chapter", &"name_in_village"]])
	village.check_goal()
	assert_eq(events.filter(func(e: Array) -> bool: return e[0] == "chapter").size(), 1, "exactly once")
	var ctx := village.chapter_context()
	assert_eq([ctx.variant, ctx.orders_done, ctx.relationships[&"smith"]], [&"name_in_village", 6, "Vertraut"])
	assert_true(String(ctx.final_line).begins_with("Unten im Dorf kennen sie jetzt deinen Namen."))


func test_chapter_in_any_order_the_insight_last() -> void:
	var journal := _goal_world()
	var orders := get_tree_orders()
	GameState.set_flag(&"linden_consecrated", true)
	orders.load_state({"states": {"o_fenner_linden": "completed", "o_fenner_well": "completed", "o_rosine_berries": "completed",
			"o_esch_charcoal": "completed", "o_quast_tincture": "completed", "ob_wood": "completed"}})
	rel.vals = {&"mayor": 45, &"innkeeper": 40, &"smith": 70}
	village.check_goal()
	assert_false(GameState.flag_on(&"name_in_village_complete"))
	journal.insights = [&"i_deathbook"]
	EventBus.insight_unlocked.emit(&"i_deathbook")
	assert_true(GameState.flag_on(&"name_in_village_complete"), "insight_unlocked checks the goal")


func get_tree_orders() -> Orders:
	return tree.get_first_node_in_group(&"orders") as Orders


func test_save_load_round_trip() -> void:
	GameState.set_flag(&"roof_and_earth_complete", true)
	village.open()
	village.donate(inv)
	rel.vals[&"priest"] = 25
	village.pay_consecration(inv)
	var state := village.save_state()
	assert_eq([state.open_day, state.donation_day, state.donation_steps, state.consecration_paid_day], [40, 40, 1, 40])
	var back := Village.new()
	back.config = Phase7Fixtures.village_config()
	_add(back)
	back.load_state(JSON.parse_string(JSON.stringify(state)) as Dictionary)
	assert_eq(JSON.stringify(back.save_state()), JSON.stringify(state))
	back.load_state({"donation_steps": 9, "open_day": "x", "goal_done": 1})
	assert_eq([back.save_state().donation_steps, back.save_state().open_day, back.save_state().goal_done], [2, 0, false], "tolerant")


# --- entities -------------------------------------------------------------------------------------

func test_board_poor_box_register_copy() -> void:
	var board := VillageBoard.new()
	_add(board)
	assert_eq(board.get_interaction_prompt(null), "", "village not open")
	GameState.set_flag(&"village_open", true)
	assert_eq(board.get_interaction_prompt(null), VillageBoard.PROMPT)
	assert_true(VillageBoard.header_text().begins_with("Totengräber auf dem Hügel – Ruf: "))
	var copy := RegisterCopy.new()
	_add(copy)
	var journal := _add(JournalDouble.new()) as JournalDouble
	rel.vals[&"mayor"] = 30
	assert_false(copy.allowed(), "Fenner only „Bekannt“, no donation today")
	village.donate(inv)
	assert_true(copy.allowed(), "after a donation today")
	copy.interact(null)
	assert_eq(journal.clues, [&"c_v_deathbook"])
	_set_time(41, 420)
	assert_false(copy.allowed())
	rel.vals[&"mayor"] = 40
	assert_true(copy.allowed(), "„Vertraut“")
	var box := PoorBox.new()
	assert_eq(box.get_interaction_prompt(null), "", "outside the tree")
	box.free()


func test_new_stone_on_an_old_grave_only_with_an_order() -> void:
	var graveyard := Graveyard.new()
	graveyard.economy = Phase5Fixtures.economy_config()
	graveyard.reputation_config = Phase3Fixtures.reputation_config()
	var world := Node3D.new()
	world.add_child(graveyard)
	for spec: Array in [["old_08", true], ["old_01", true], ["plot_01", false]]:
		var plot := PlotDouble.new()
		plot.grave_id = spec[0]
		plot.is_old = spec[1]
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	_add(world)
	assert_eq(graveyard.get_grave("old_08").state, GraveRecord.State.OLD)
	var design := Phase5Fixtures.design(&"stone_stele", &"i_rest", &"orn_poppy")
	assert_false(graveyard.replace_old_marker("old_08", design), "no order")
	var orders := Orders.new()
	orders.config = Phase7Fixtures.orders_config()
	orders.order_table[&"o_mangold_stone"] = Phase7Fixtures.order(&"o_mangold_stone")
	world.add_child(orders)
	orders.load_state({"states": {"o_mangold_stone": "accepted"}, "accepted_day": {"o_mangold_stone": 40}})
	var mason := Stonemasonry.new()
	world.add_child(mason)
	var eligible := mason.eligible_graves().map(func(e: Dictionary) -> Array: return [e.grave_id, e.name])
	assert_eq(eligible, [["old_08", "Dorothee Mahn"]], "the bench carves for old_08 only with the order")
	assert_eq(mason.order_block_reason("old_01", design, inv), Stonemasonry.TEXT_NO_GRAVE)
	assert_ne(mason.order_block_reason("old_08", design, inv), Stonemasonry.TEXT_NO_GRAVE)
	assert_false(graveyard.replace_old_marker("old_01", design), "the order is for old_08")
	assert_false(graveyard.replace_old_marker("plot_01", design), "no old grave")
	var stones := GameState.get_stat(&"stones_set")
	assert_true(graveyard.replace_old_marker("old_08", design))
	var g := graveyard.get_grave("old_08")
	assert_eq([g.state, g.marker_id, StoneDesign.from_dict(g.design).ornament], [GraveRecord.State.OLD, &"stone_stele", &"orn_poppy"],
			"stays OLD, not liftable")
	assert_eq(GameState.get_stat(&"stones_set"), stones + 1)
	assert_has(rep.calls, ["event", &"marker_upgrade", "Ein neuer Stein für Dorothee Mahn"])
	assert_eq(orders.state(&"o_mangold_stone"), &"completed", "Orders.note_stone_set")
	assert_false(graveyard.has_stone_order("old_08"))
	assert_false(graveyard.replace_old_marker("old_08", design), "no second stone without an order")
	assert_eq(mason.eligible_graves(), [] as Array[Dictionary], "order done – the old grave is closed again")
