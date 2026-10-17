extends TestCase
## P4 (docs/PHASE9_DESIGN.md §2.2, §2.6, §3.4, §5.1, §10): WhoKnows with the real Quests chain q_who_knows – the light
## day p9_open_day − 12; H1 the ledger (inventory or chest); H2 register (death-register fallback) + five graves →
## c_q_three_weeks; H3 witnesses (clue, relationship +2, once); H4 Johann daily from H4, the mark; ending A only with the
## letter at the door at night, the departure with Hanne before the deadline else with Osric, sieber_gone after the walk,
## the note at the hut door; the deadline light + 17 → silent; the consequences of B / C (confidant) and the kept promise
## in the fourth row; the reserved plot; KnockDoor's prompts; save / load. Fixtures + doubles, no world.

const OPEN := 63


class CorpsesDouble extends Node:
	var recs: Array[CorpseRecord] = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func records() -> Array[CorpseRecord]:
		return recs


class JournalDouble extends Node:
	var clues: Array = []
	var insights: Array = []

	func _init() -> void:
		add_to_group(&"journal")

	func has_clue(id: StringName) -> bool:
		return clues.has(id)

	func has_insight(id: StringName) -> bool:
		return insights.has(id)

	func add_clue(id: StringName, _corpse_id: String = "", _silent: bool = false) -> bool:
		if clues.has(id):
			return false
		clues.append(id)
		return true


class RelDouble extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"relationships")

	func add(npc_id: StringName, delta: int, _reason: String) -> int:
		calls.append([npc_id, delta])
		return delta


class VisitorsDouble extends Node:
	var interval: Dictionary = {}
	var goodwill: Array = []

	func _init() -> void:
		add_to_group(&"visitors")

	func set_kin_interval(kin_id: StringName, days: int) -> void:
		interval[kin_id] = days

	func add_goodwill(kin_id: StringName, delta: int) -> void:
		goodwill.append([kin_id, delta])


class WanderersDouble extends Node:
	func _init() -> void:
		add_to_group(&"wanderers")

	func next_peddler_day(day: int) -> int:
		for d: int in range(day, day + 60):
			if posmod(d, 6) == 1:
				return d
		return -1


class EventsDouble extends Node:
	var calls: Array = []

	func event(kind: StringName, _reason: String) -> void:
		calls.append(kind)


class GraveyardDouble extends Node:
	var sections: Dictionary = {}

	func _init() -> void:
		add_to_group(&"graveyard")

	func section_of(grave_id: String) -> StringName:
		return sections.get(grave_id, &"linden")


class ChestDouble extends Node:
	var save_id: String = "chest_test"
	var storage: Inventory

	func _init() -> void:
		add_to_group(&"saveable")


var quests: Quests
var who: WhoKnows
var corpses: CorpsesDouble
var journal: JournalDouble
var rel: RelDouble
var visitors: VisitorsDouble
var wanderers: WanderersDouble
var piety: EventsDouble
var rep: EventsDouble
var graveyard: GraveyardDouble
var orders: Orders
var inv: Inventory
var lights: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": OPEN, "minute_of_day": 420})
	for flag: StringName in [&"village_open", &"p8_open", &"who_comes_up_complete", &"p9_open"]:
		GameState.set_flag(flag, true)
	GameState.set_flag(&"p9_open_day", OPEN)
	quests = Quests.new()
	quests.config = Phase9Fixtures.quest_config()
	for d: QuestData in Phase9Fixtures.quests():
		quests.quest_table[d.id] = d
	who = WhoKnows.new()
	who.config = Phase9Fixtures.who_knows_config()
	who.list_data = Phase9Fixtures.light_list()
	corpses = CorpsesDouble.new()
	corpses.recs = Phase9Fixtures.list_records()
	journal = JournalDouble.new()
	rel = RelDouble.new()
	visitors = VisitorsDouble.new()
	wanderers = WanderersDouble.new()
	piety = EventsDouble.new()
	piety.add_to_group(&"piety")
	rep = EventsDouble.new()
	rep.add_to_group(&"reputation")
	graveyard = GraveyardDouble.new()
	orders = Orders.new()
	orders.config = Phase9Fixtures.orders_config()
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		orders.order_table[id] = Phase9Fixtures.order(id)
	for n: Node in _nodes():
		tree.root.add_child(n)
	quests.open_now(OPEN)
	who.apply_morning(OPEN)
	inv = Inventory.new()
	# The Phase-9 items (nameless_letter) come with P3's data/items – until then the fixture items (test-only).
	Phase9Fixtures._inject_items()
	lights.clear()
	EventBus.light_entry_changed.connect(_on_light)


func after_each() -> void:
	EventBus.light_entry_changed.disconnect(_on_light)
	for n: Node in _nodes():
		if is_instance_valid(n):
			n.free()
	inv.free()
	Phase9Fixtures.remove_injected_items()
	GameState.reset()


func _nodes() -> Array[Node]:
	return [quests, who, corpses, journal, rel, visitors, wanderers, piety, rep, graveyard, orders]


func _on_light(entry_id: StringName, kind: StringName) -> void:
	lights.append([entry_id, kind])


## q_who_knows at `step` (steps before done), choices / ending as given.
func _at(step: StringName, choices: Dictionary = {}, ending: StringName = &"") -> void:
	var done: Array = []
	for s: StringName in Phase9Fixtures.MAIN_STEPS:
		if s == step:
			break
		done.append(String(s))
	var data := {"open_day": OPEN, "open": ["q_who_knows"], "step": {"q_who_knows": String(step)}, "done": {"q_who_knows": done},
			"choices": {"q_who_knows": choices}}
	if ending != &"":
		(data.done.q_who_knows as Array).append("h6")
		data["ending"] = {"q_who_knows": String(ending)}
	quests.load_state(data)


func _five_graves() -> PackedStringArray:
	return PackedStringArray(["plot_06", "h_01", "h_06", "l_07", "l_12"])


# --- light day, H1, H2 ----------------------------------------------------------------------------

func test_light_day_is_set_once_at_the_opening() -> void:
	assert_eq([int(GameState.get_flag(&"q_light_day")), who.light_day()], [51, 51], "p9_open_day − 12")
	GameState.set_flag(&"p9_open_day", 70)
	who.apply_morning(OPEN + 1)
	assert_eq(who.light_day(), 51, "set once")


func test_h1_reads_the_ledger_from_the_inventory_or_a_chest() -> void:
	assert_eq(who.read_block_reason(inv), WhoKnows.TEXT_NO_LEDGER)
	var chest := ChestDouble.new()
	chest.storage = Inventory.new()
	chest.storage.add_item(&"lorenz_ledger_2", 1)
	tree.root.add_child(chest)
	assert_eq(who.read_block_reason(inv), "", "in a chest")
	chest.storage.free()
	chest.free()
	inv.add_item(&"lorenz_ledger_2", 1)
	assert_eq(who.read_block_reason(inv), "")
	GameState.clear_flag(&"p9_open")
	assert_eq(who.read_block_reason(inv), WhoKnows.TEXT_NOT_OPEN)
	GameState.set_flag(&"p9_open", true)
	who.read_kladde()
	assert_true(GameState.flag_on(&"kladde_read"))
	assert_has(journal.clues, &"c_q_dates")
	assert_eq(quests.current_step(&"q_who_knows"), &"h2", "note kladde_read")


func test_h2_register_and_five_graves() -> void:
	assert_eq(who.register_block_reason(), WhoKnows.TEXT_READ_FIRST)
	assert_false(who.can_compare("plot_06"), "before the ledger")
	who.read_kladde()
	assert_eq(who.register_block_reason(), "")
	var matched := who.compare_register()
	assert_eq(matched, PackedStringArray(["e_dorn", "e_quendel", "e_wernstein", "e_hagedorn", "e_ott"]))
	assert_eq(lights.filter(func(l: Array) -> bool: return l[1] == &"matched").size(), 5)
	assert_true(who.matched(&"e_ott") and not who.matched(&"e_open"))
	assert_eq(who.register_block_reason(), WhoKnows.TEXT_REGISTER_DONE)
	assert_false(who.can_compare("l_01"), "no dead of the list")
	assert_eq(who.entry_for_grave("h_06"), &"e_dorn")
	for g: String in _five_graves().slice(0, 4):
		assert_true(who.compare_grave(g), g)
	assert_false(who.can_compare("plot_06"), "compared once")
	assert_false(journal.clues.has(&"c_q_three_weeks"), "4 of 5")
	assert_eq(quests.progress(&"q_who_knows"), Vector2i(4, 5))
	assert_true(who.compare_grave("l_12"))
	assert_has(journal.clues, &"c_q_three_weeks")
	assert_eq(quests.current_step(&"q_who_knows"), &"h3")


func test_h2_a_missing_dead_counts_through_the_death_register() -> void:
	corpses.recs = corpses.recs.filter(func(r: CorpseRecord) -> bool: return r.story_id != &"s1_quendel")
	who.read_kladde()
	for g: String in ["h_01", "h_06", "l_07", "l_12"]:
		assert_true(who.compare_grave(g), g)
	assert_eq(quests.current_step(&"q_who_knows"), &"h2", "S1 is not on the hill")
	who.compare_register()
	assert_eq(quests.notes(&"date_grave").size(), 5, "Lenz' death register")
	assert_eq(quests.current_step(&"q_who_knows"), &"h3")
	assert_has(journal.clues, &"c_q_three_weeks")


# --- H3, H4 ---------------------------------------------------------------------------------------

func test_h3_witnesses_once_with_clue_and_relationship() -> void:
	assert_true(who.witness(&"e_quendel"))
	assert_has(journal.clues, &"c_q_light_quendel")
	assert_eq(rel.calls, [[&"carter", 2]], "gains.witness")
	assert_has(lights, [&"e_quendel", &"witnessed"])
	assert_false(who.witness(&"e_quendel"), "once")
	assert_false(who.witness(&"e_nope"))
	assert_true(who.witness(&"e_ott"))
	assert_eq(who.witnessed(), [&"e_quendel", &"e_ott"] as Array[StringName])
	_at(&"h3")
	journal.insights.append(&"i_light_before")
	EventBus.insight_unlocked.emit(&"i_light_before")
	assert_eq(quests.current_step(&"q_who_knows"), &"h4", "the journal's insight (3 of 5) ends H3")


func test_h4_johann_daily_and_the_mark() -> void:
	_at(&"h3")
	who.apply_morning(OPEN + 1)
	assert_false(visitors.interval.has(&"kin_sieber"), "not before H4")
	_at(&"h4")
	who.apply_morning(OPEN + 2)
	assert_eq(visitors.interval.get(&"kin_sieber"), 1, "§2.2.5: daily from H4")
	assert_eq(GameState.get_flag(&"sieber_bench_day"), OPEN + 2, "the bench schedule's day")
	who.mark_seen()
	assert_true(GameState.flag_on(&"q_sieber_marked") and who.marked_seen())
	assert_has(journal.clues, &"c_q_sieber")
	assert_eq(visitors.goodwill, [[&"kin_sieber", 1]])
	assert_has(lights, [&"e_open", &"marked"])
	TimeManager.advance(1)
	assert_eq(quests.current_step(&"q_who_knows"), &"h5")
	who.mark_seen()
	assert_eq(visitors.goodwill.size(), 1, "once")


# --- ending A -------------------------------------------------------------------------------------

func test_the_nameless_letter_only_at_night_and_while_deciding() -> void:
	inv.add_item(&"ink", 1)
	assert_eq(who.write_block_reason(inv), WhoKnows.TEXT_NO_NEED, "not before H5")
	_at(&"h6")
	var empty := Inventory.new()
	assert_eq(who.write_block_reason(empty), WhoKnows.TEXT_NO_INK)
	empty.free()
	assert_eq(who.write_block_reason(inv), "")
	assert_true(who.write_letter(inv))
	assert_eq([inv.count(&"ink"), inv.count(&"nameless_letter")], [0, 1])
	assert_eq(who.write_block_reason(inv), WhoKnows.TEXT_HAS_LETTER)
	TimeManager.load_state({"day": 67, "minute_of_day": 900})
	assert_false(who.post_letter(inv), "by day")
	TimeManager.load_state({"day": 67, "minute_of_day": 1290})
	assert_true(who.post_letter(inv), "21:30")
	assert_true(who.letter_posted())
	assert_eq(inv.count(&"nameless_letter"), 0)
	assert_eq(QuestRules.choice_block_reason(QuestRules.choice(Phase9Fixtures.quest(&"q_who_knows").steps[5], &"away"),
			{"conditions": {"letter_posted": who.letter_posted()}}), "", "ending A can be chosen now")


func test_departure_with_hanne_before_the_deadline() -> void:
	TimeManager.load_state({"day": 66, "minute_of_day": 700})
	_at(&"h6", {"h5": "confide_washer", "h6": "away"}, &"away")
	assert_eq(who.reserved_plot_count(), 0, "A frees the held-back plot")
	who.apply_minute(66, 700)
	assert_eq(who.depart_plan(), {"day": 67, "minute": 980, "with": &"peddler"}, "Hanne's day 67 ≤ light + 18")
	who.apply_minute(67, 1000)
	assert_false(GameState.flag_on(&"sieber_gone"), "still on the forest path")
	who.apply_minute(67, 1020)
	assert_true(GameState.flag_on(&"sieber_gone"), "16:20 + 40")
	assert_eq(visitors.interval.get(&"kin_sieber"), -1, "Grete's grave has no visitor any more")
	assert_has(lights, [&"e_open", &"departed"])
	TimeManager.advance(1)
	assert_eq(quests.state(&"q_who_knows"), &"settled", "ending A settles with sieber_gone")
	who.apply_morning(68)
	assert_has(journal.clues, &"c_q_hand_answers", "the note at the hut door the morning after")
	assert_true(rel.calls.is_empty(), "A: no confidant consequences")


func test_departure_with_osric_after_hannes_day() -> void:
	TimeManager.load_state({"day": 68, "minute_of_day": 600})
	_at(&"h6", {"h6": "away"}, &"away")
	who.apply_minute(68, 600)
	assert_eq(who.depart_plan(), {"day": 69, "minute": 600, "with": &"carter"}, "Hanne's next day 73 > light + 18")


func test_departure_on_hannes_day_after_she_left_goes_with_osric() -> void:
	TimeManager.load_state({"day": 67, "minute_of_day": 1020})
	_at(&"h6", {"h6": "away"}, &"away")
	who.apply_minute(67, 1020)
	assert_eq(who.depart_plan(), {"day": 68, "minute": 600, "with": &"carter"}, "she left the gate at 16:20")


# --- deadline, B, C, silent ---------------------------------------------------------------------

func test_deadline_light_plus_17_ends_silent() -> void:
	_at(&"h4")
	TimeManager.load_state({"day": 68, "minute_of_day": 360})
	who.apply_morning(68)
	assert_eq(quests.ending(&"q_who_knows"), &"", "B6 is the last day")
	TimeManager.load_state({"day": 69, "minute_of_day": 360})
	who.apply_morning(69)
	assert_eq(quests.ending(&"q_who_knows"), &"silent")
	assert_eq(who.save_state().fallback_day, 69)
	assert_true(GameState.flag_on(&"q_sieber_dies") and not GameState.flag_on(&"sieber_gone"))
	assert_true(rel.calls.is_empty(), "silent: no relationship change")


func test_ending_b_confidant_evenings_and_the_kept_promise() -> void:
	_at(&"h6", {"h5": "confide_priest", "h6": "stay"}, &"stay")
	who.apply_minute(68, 700)
	assert_eq(rel.calls, [[&"priest", 3]], "the confidant +3")
	assert_eq(orders.state(&"oq_johann_evening"), &"offered", "two evenings on the bench")
	who.apply_minute(68, 701)
	assert_eq(rel.calls.size(), 1, "once")
	var d3 := CorpseRecord.new()
	d3.id = "corpse_0050"
	d3.story_id = &"d3_sieber"
	d3.grave_id = "l_16"
	d3.location = CorpseRecord.LOCATION_BURIED
	corpses.recs.append(d3)
	graveyard.sections["l_16"] = &"linden_row4"
	GameState.set_flag(&"sieber_buried", true)
	who.apply_minute(73, 900)
	assert_true(GameState.flag_on(&"kept_promise_sieber"))
	assert_eq([piety.calls, rep.calls], [[&"kept_promise"], [&"kept_promise"]], "Pietät +3 / Ruf +1 (kept_promise)")


func test_ending_b_outside_the_fourth_row_keeps_no_promise() -> void:
	_at(&"h6", {"h5": "confide_none", "h6": "stay"}, &"stay")
	who.apply_minute(68, 700)
	assert_true(rel.calls.is_empty(), "nobody confided")
	var d3 := CorpseRecord.new()
	d3.story_id = &"d3_sieber"
	d3.grave_id = "l_01"
	d3.location = CorpseRecord.LOCATION_BURIED
	corpses.recs.append(d3)
	GameState.set_flag(&"sieber_buried", true)
	who.apply_minute(73, 900)
	assert_false(GameState.flag_on(&"kept_promise_sieber"))
	assert_eq(piety.calls, [])


func test_ending_c_names_the_three_except_the_confidant() -> void:
	_at(&"h6", {"h5": "confide_washer", "h6": "public"}, &"public")
	who.apply_minute(68, 700)
	assert_eq(rel.calls, [[&"priest", -4], [&"surgeon", -4]], "§2.2.7 C: named_publicly, Liesel spared")
	_at(&"h6", {"h5": "confide_none", "h6": "public"}, &"public")
	var fresh := who.save_state()
	fresh.applied = ""
	who.load_state(fresh)
	rel.calls.clear()
	who.apply_minute(68, 702)
	assert_eq(rel.calls.size(), 3, "nobody confided: all three −4")


func test_reserved_plot_until_the_ending() -> void:
	assert_eq(who.reserved_plot_count(), 1, "§2.6: one plot of the fourth row held back from p9_open")
	_at(&"h6", {"h6": "silent"}, &"silent")
	assert_eq(who.reserved_plot_count(), 0, "the pending D3 (q_sieber_dies) reserves it from now on")
	GameState.clear_flag(&"p9_open")
	assert_eq(who.reserved_plot_count(), 0)


# --- KnockDoor, save ------------------------------------------------------------------------------

func test_knock_door_prompts() -> void:
	var door := (load("res://src/entities/knock_door/knock_door.tscn") as PackedScene).instantiate() as KnockDoor
	tree.root.add_child(door)
	var player := Player.new()
	player.inventory = Inventory.new()
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_KNOCK)
	_at(&"h6")
	player.inventory.add_item(&"nameless_letter", 1)
	TimeManager.load_state({"day": 67, "minute_of_day": 900})
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_KNOCK, "by day: knock")
	TimeManager.load_state({"day": 67, "minute_of_day": 1300})
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_LETTER, "at night with the letter")
	door.interact(player)
	assert_true(who.letter_posted())
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_KNOCK)
	GameState.clear_flag(&"p9_open")
	assert_eq(door.get_interaction_prompt(player), "", "Phase 9 only")
	player.inventory.free()
	player.free()
	door.free()


func test_save_load_round_trip_and_tolerance() -> void:
	who.read_kladde()
	who.compare_register()
	who.witness(&"e_dorn")
	_at(&"h6", {"h6": "away"}, &"away")
	who.apply_minute(66, 700)
	var saved := who.save_state()
	assert_eq([saved.light_day, saved.matched.size(), saved.witnessed, saved.depart.with, saved.applied], [51, 5, ["e_dorn"], &"peddler", "away"])
	var back := WhoKnows.new()
	back.config = Phase9Fixtures.who_knows_config()
	back.list_data = Phase9Fixtures.light_list()
	back.load_state(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved)))))
	assert_eq(back.save_state(), saved, "round trip")
	back.load_state({"light_day": "x", "matched": ["e_ott", "e_nope", 3], "witnessed": "e_dorn", "marked_seen": 1,
			"letter_posted": "yes", "depart": {"day": "69", "minute": 9999, "with": "cart"}, "fallback_day": -4, "applied": 7})
	assert_eq([back.matched(&"e_ott"), back.matched(&"e_nope"), back.witnessed(), back.letter_posted(), back.depart_plan()],
			[true, false, [] as Array[StringName], false, {}])
	assert_eq(back.save_state().light_day, 0)
	back.free()


## Visitors.set_kin_interval (P4, §2.2.5, §5.1): daily from H4, −1 = no more, 0 = the plan; saved only when set.
func test_visitors_kin_interval() -> void:
	var v := Visitors.new()
	assert_false(v.save_state().has("kin_interval"), "a Phase-8 state saves as before")
	v.set_kin_interval(&"kin_sieber", 1)
	assert_eq(v.kin_interval(&"kin_sieber"), 1)
	assert_eq(v.save_state().kin_interval, {"kin_sieber": 1})
	assert_eq(v._interval_due("l_10", 1, 66), 66, "never looked at: today")
	v._last_visit["l_10"] = 66
	assert_eq(v._interval_due("l_10", 1, 67), 67, "daily")
	v.set_kin_interval(&"kin_sieber", -5)
	assert_eq(v.kin_interval(&"kin_sieber"), -1, "comes no more")
	v.set_kin_interval(&"kin_sieber", 0)
	assert_false(v.save_state().has("kin_interval"), "back to the plan")
	v.load_state({"kin_interval": {"kin_sieber": "daily", "kin_atlantis": -3, "kin_kehr": 1.5, "kin_ott": 2, "kin_x": -1}})
	assert_eq(v.save_state().kin_interval, {"kin_ott": 2, "kin_x": -1}, "garbage dropped (fuzzer)")
	v.free()


# --- W2 Anschlüsse 14: the schedules' day flags --------------------------------------------------------

func test_w2_departure_flags_from_the_plan() -> void:
	TimeManager.load_state({"day": 66, "minute_of_day": 700})
	_at(&"h6", {"h6": "away"}, &"away")
	who.apply_minute(66, 700)
	assert_eq(GameState.get_flag(&"sieber_depart_peddler_day"), 67, "with Hanne on her day")
	assert_false(GameState.has_flag(&"sieber_depart_carter_day"))
	# No bench on the day he leaves (the bench walk would cross his walk with Hanne).
	TimeManager.load_state({"day": 67, "minute_of_day": 360})
	who.apply_morning(67)
	assert_false(ScheduleResolver.is_today(&"sieber_bench_day", 67), "not set on the departure day")
	GameState.set_flag(&"sieber_bench_day", 67)
	who.apply_minute(67, 400)
	assert_false(ScheduleResolver.is_today(&"sieber_bench_day", 67), "cleared when the plan falls on today")
	var jo := load("res://data/npc/kin_sieber_v_schedule.tres") as NpcSchedule
	assert_eq(ScheduleResolver.entry_at(jo, 960, 67).path[-1], "sieber_gate", "16:00 at the gate with Hanne, not the bench")


func test_w2_departure_flag_with_osric() -> void:
	TimeManager.load_state({"day": 68, "minute_of_day": 600})
	_at(&"h6", {"h6": "away"}, &"away")
	who.apply_minute(68, 600)
	assert_eq(GameState.get_flag(&"sieber_depart_carter_day"), 69)
	assert_false(GameState.has_flag(&"sieber_depart_peddler_day"))
	var jo := load("res://data/npc/kin_sieber_v_schedule.tres") as NpcSchedule
	assert_eq(ScheduleResolver.entry_at(jo, 610, 69).animation, &"sit_cart", "10:00 on the cart")


func test_w2_watch_flag_every_night_until_the_morning_after_the_death() -> void:
	var wa := load("res://data/npc/watchman_schedule.tres") as NpcSchedule
	_at(&"h6", {"h5": "confide_none", "h6": "public"}, &"public")
	who.apply_minute(68, 1300)
	assert_eq(GameState.get_flag(&"sieber_watch_day"), 68, "C: the watch begins the same night")
	assert_true(ScheduleResolver.entry_at(wa, 1300, 68).visible, "21:40 the lantern at the door")
	who.apply_minute(69, 0)
	assert_eq(GameState.get_flag(&"sieber_watch_day"), 69, "from midnight on")
	assert_true(ScheduleResolver.entry_at(wa, 120, 69).visible, "02:00")
	assert_false(ScheduleResolver.entry_at(wa, 700, 69).visible, "not by day")
	who.apply_minute(72, 0)
	GameState.set_flag(&"sieber_dead", true)
	who.apply_minute(72, 140)
	assert_true(ScheduleResolver.entry_at(wa, 140, 72).visible, "he dies at 02:10 – the watchman stays until morning")
	who.apply_minute(72, 360)
	assert_false(GameState.has_flag(&"sieber_watch_day"), "06:00: the watch is over")
	assert_false(ScheduleResolver.entry_at(wa, 1300, 72).visible, "no lantern the next night")
	who.apply_minute(73, 0)
	assert_false(GameState.has_flag(&"sieber_watch_day"))


func test_w2_watch_flag_only_for_ending_c() -> void:
	for e: StringName in [&"stay", &"silent"]:
		_at(&"h6", {"h6": String(e)}, e)
		who.apply_minute(68, 1300)
		assert_false(GameState.has_flag(&"sieber_watch_day"), String(e))


func test_w2_evening_flag_while_the_evening_order_runs() -> void:
	var real := load("res://data/orders/oq_johann_evening.tres") as OrderData
	assert_eq(real.conditions.get("schedule_flag"), "sieber_evening_day", "Orders' meet flag (QA8-03)")
	orders.order_table[&"oq_johann_evening"] = real
	_at(&"h6", {"h5": "confide_priest", "h6": "stay"}, &"stay")
	TimeManager.load_state({"day": 68, "minute_of_day": 700})
	who.apply_minute(68, 700)
	assert_eq(orders.state(&"oq_johann_evening"), &"offered")
	assert_false(GameState.has_flag(&"sieber_evening_day"), "offered only: no evening yet")
	assert_true(orders.accept(&"oq_johann_evening"))
	assert_eq(GameState.get_flag(&"sieber_evening_day"), 68, "accepted at 11:40: this evening")
	var jo := load("res://data/npc/kin_sieber_v_schedule.tres") as NpcSchedule
	assert_eq([ScheduleResolver.entry_at(jo, 1140, 68).path[-1], ScheduleResolver.entry_at(jo, 1140, 68).visible],
			["v_sieber_bench", true], "19:00 on the bench")
	orders.apply_morning(69)
	assert_eq(GameState.get_flag(&"sieber_evening_day"), 69, "every morning while it runs")
