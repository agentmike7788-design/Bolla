extends TestCase
## P3 (docs/PHASE9_DESIGN.md §2.4, §7.5, §10): letters in the generated graveyard world – three deliveries after
## p9_open carry L1–L3 (CorpseManager → Letters.assign), the pockets step hands them (CorpseCare → Letters.on_found),
## every choice once with the real prompts (Desk: answer, Stove: burn, GravePlot: read at the grave / lay into the
## open grave) and the real Piety / Reputation / Relationships, the post for the dead read at the grave (the ghost
## bonus that night), answer + counter-letter, the errands E1 / E2 with both decisions each. The Phase-9 nodes are
## added here (W-Welt hangs them into the world in W2); P4's chain prompts at the desk and the grave run against a
## WhoKnows double.

const WORLD := "res://src/world/graveyard/graveyard.tscn"
const DESK := "res://src/entities/desk/desk.tscn"
const STOVE := "res://src/entities/stove/stove.tscn"
const OPEN_DAY := 3


## Duck-typed WhoKnows / Quests (P4 / P1 are built in parallel): what the desk and the grave ask.
class WhoKnowsDouble extends Node:
	var config := WhoKnowsConfig.new()
	var kladde_read: int = 0
	var compared: Array[String] = []
	var comparable: Array[String] = []

	func _init() -> void:
		add_to_group(&"who_knows")

	func read_block_reason(_inv: Inventory) -> String:
		return ""

	var registered: bool = false

	func read_kladde() -> void:
		kladde_read += 1
		GameState.set_flag(&"kladde_read", true)

	func register_block_reason() -> String:
		return "" if GameState.flag_on(&"kladde_read") and not registered and step_h2 else "nein"

	var step_h2: bool = false

	func compare_register() -> PackedStringArray:
		registered = true
		return PackedStringArray(["e_quendel"])

	var deciding: bool = false

	func write_block_reason(inv: Inventory) -> String:
		if not deciding or inv.has(&"nameless_letter"):
			return "nein"
		return "" if inv.has(&"ink") else "keine Tinte"

	func write_letter(inv: Inventory) -> bool:
		inv.remove_item(&"ink", 1)
		inv.add_item(&"nameless_letter", 1)
		return true

	func can_compare(grave_id: String) -> bool:
		return comparable.has(grave_id) and not compared.has(grave_id)

	func compare_grave(grave_id: String) -> bool:
		compared.append(grave_id)
		return true

	func letter_posted() -> bool:
		return false

	var held: int = 0

	func reserved_plot_count() -> int:
		return held


class QuestsDouble extends Node:
	var step: StringName = &""
	var notes_by: Dictionary = {}

	func _init() -> void:
		add_to_group(&"quests")

	func current_step(_q: StringName) -> StringName:
		return step

	func ending(_q: StringName) -> StringName:
		return &""

	func notes(key: StringName) -> PackedStringArray:
		return notes_by.get(key, PackedStringArray())

	func note(key: StringName, arg: String) -> void:
		var list: PackedStringArray = notes_by.get(key, PackedStringArray())
		list.append(arg)
		notes_by[key] = list

	func choose(_q: StringName, _s: StringName, _c: StringName) -> bool:
		return false


var world: WorldRoot
var player: Player
var letters: Letters
var corpses: CorpseManager
var care: CorpseCare
var graveyard: Graveyard
var piety: Piety
var rel: Relationships
var orders: Orders
var desk: Desk
var stove: Stove
var quests: QuestsDouble
var notes: Array = []


func before_each() -> void:
	notes.clear()
	EventBus.notification_requested.connect(_on_note)
	world = (load(WORLD) as PackedScene).instantiate() as WorldRoot
	tree.root.add_child(world)
	await tree.process_frame
	await tree.process_frame
	player = world.get_player()
	player.set_physics_process(false)
	player.instant_actions = true
	corpses = tree.get_first_node_in_group(&"corpse_manager") as CorpseManager
	care = tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	graveyard = tree.get_first_node_in_group(&"graveyard") as Graveyard
	piety = tree.get_first_node_in_group(&"piety") as Piety
	rel = tree.get_first_node_in_group(&"relationships") as Relationships
	orders = tree.get_first_node_in_group(&"orders") as Orders
	_without_world_phase9(world.get_node("Systems"))
	letters = Letters.new()
	letters.name = "Letters"
	world.add_child(letters)
	quests = QuestsDouble.new()
	world.add_child(quests)
	desk = (load(DESK) as PackedScene).instantiate() as Desk
	stove = (load(STOVE) as PackedScene).instantiate() as Stove
	world.add_child(desk)
	world.add_child(stove)
	GameState.set_flag(&"p9_open", true)
	GameState.set_flag(&"p9_open_day", OPEN_DAY)
	GameState.stats[&"piety"] = 0
	# A daily delivery (reputation tier above „Unbekannt“: no every-other-day rule).
	GameState.stats[&"reputation"] = 70


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	if is_instance_valid(player):
		player.cancel_timed_action()
	Audio.reset()
	if is_instance_valid(world):
		tree.root.remove_child(world)
		world.free()
	world = null
	player = null


## The delivery of `day`, its pockets examined, buried in the next free plot. Returns the record.
func _deliver_and_examine(day: int, bury: bool = true) -> CorpseRecord:
	TimeManager.set_time(day, 470)
	var r := corpses.try_daily_delivery(day)
	assert_not_null(r, "a delivery on day %d" % day)
	if r == null:
		return null
	care.exam_step(r.id, &"pockets")
	if bury:
		_bury(r)
	return r


func _bury(r: CorpseRecord) -> String:
	var plot := _free_plot()
	graveyard.dig(plot)
	assert_true(graveyard.bury(plot, r.id), "buried in %s" % plot)
	return plot


func _free_plot() -> String:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.EMPTY:
			return g.id
	return ""


func _plot(grave_id: String) -> GravePlot:
	for n: Node in tree.get_nodes_in_group(&"grave_plot"):
		if (n as GravePlot).grave_id == grave_id:
			return n as GravePlot
	return null


func _uid_of(r: CorpseRecord) -> String:
	for uid: String in letters.uids():
		if letters.corpse_of(uid) == r.id and letters.kind_of(uid) == LetterData.KIND_POCKET:
			return uid
	return ""


func test_three_deliveries_carry_l1_to_l3_and_every_choice() -> void:
	var inv := player.inventory
	var r1 := _deliver_and_examine(OPEN_DAY)
	var r2 := _deliver_and_examine(OPEN_DAY + 1)
	var r3 := _deliver_and_examine(OPEN_DAY + 2)
	assert_eq([r1.letter_id, r2.letter_id, r3.letter_id], [&"lp_l1_carter", &"lp_l2_sister", &"lp_l3_burn"], "forced L1–L3")
	var l1 := _uid_of(r1)
	var l2 := _uid_of(r2)
	var l3 := _uid_of(r3)
	assert_true(inv.has_uid(l1) and inv.has_uid(l2) and inv.has_uid(l3), "the pockets step hands the letters")
	assert_has(notes, Letters.TEXT_FOUND % "An Rosine Wackernagel, Holderkrug")
	assert_eq(GameState.get_stat(&"letters_found"), 3)
	# L1: delivered to Rosine (dialogue action letter_deliver → Letters.decide).
	rel.meet(&"innkeeper")
	var rosine := rel.value(&"innkeeper")
	assert_true(letters.decide(l1, &"deliver", {"inventory": inv, "npc": &"innkeeper"}))
	assert_eq(rel.value(&"innkeeper") - rosine, 3)
	# L2 to the town by post, L3 burned unread at the hut's stove as it asks (the stove takes the first letter by uid).
	inv.add_item(&"coin", 1)
	assert_true(letters.decide(l2, &"deliver", {"inventory": inv, "carrier": &"peddler"}))
	assert_eq(letters.state(l2), &"posted")
	var p0 := piety.value()
	assert_eq(stove.get_interaction_prompt(player), Stove.PROMPT_CHOICE)
	stove.interact(player)
	stove.request_action(StringName(LetterBurning.PREFIX + l3))
	assert_eq(letters.state(l3), &"burned")
	assert_eq(piety.value() - p0, 1, "„Ungelesen verbrennen“: +1")
	assert_eq([letters.decided_count(), letters.delivered_count(), GameState.get_stat(&"letters_decided")], [3, 2, 3])


## W3 QA-Fix QA9-03: [E] at the stove never burns at once – it opens the choice (warming first, then one row per letter
## that may burn here); only the chosen letter burns, warming stays possible.
func test_stove_burns_only_the_chosen_letter_and_still_warms() -> void:
	var inv := player.inventory
	var r1 := _deliver_and_examine(OPEN_DAY)
	var r2 := _deliver_and_examine(OPEN_DAY + 1)
	var first := _uid_of(r1)
	var second := _uid_of(r2)
	assert_true(inv.has_uid(first) and inv.has_uid(second))
	var panels: Array = []
	var on_panel := func(id: StringName, ctx: Dictionary) -> void: panels.append([id, ctx])
	EventBus.ui_panel_requested.connect(on_panel)
	assert_eq(stove.get_interaction_prompt(player), Stove.PROMPT_CHOICE, "the prompt names both")
	stove.interact(player)
	EventBus.ui_panel_requested.disconnect(on_panel)
	assert_eq(letters.state(first), &"found", "[E] alone burns nothing")
	assert_eq(panels.size(), 1, "the choice opens")
	if panels.size() == 1:
		assert_eq(panels[0][0], LetterBurning.PANEL)
		var ids: Array = (panels[0][1].options as Array).map(func(o: Dictionary) -> StringName: return o.id)
		assert_eq(ids, [Stove.OPTION_WARM, StringName(LetterBurning.PREFIX + first), StringName(LetterBurning.PREFIX + second)],
				"warming first, then each letter")
	stove.request_action(Stove.OPTION_WARM)
	assert_has(notes, Stove.TEXT_WARM, "warming is still there")
	assert_eq(letters.state(first), &"found")
	var p0 := piety.value()
	stove.interact(player)
	stove.request_action(StringName(LetterBurning.PREFIX + second))
	assert_eq([letters.state(first), letters.state(second)], [&"found", &"burned"], "the chosen one, not the first")
	assert_eq(piety.value() - p0, -1, "L2 did not ask for it")
	assert_true(inv.has_uid(first))
	stove.interact(player)
	stove.request_action(StringName(LetterBurning.PREFIX + first))
	assert_eq(stove.get_interaction_prompt(player), Stove.PROMPT_WARM, "nothing left to burn")
	assert_has(notes, Letters.TEXT_BURNED)


func test_answer_at_the_desk_post_and_counter_letter() -> void:
	var inv := player.inventory
	_deliver_and_examine(OPEN_DAY)
	var r2 := _deliver_and_examine(OPEN_DAY + 1)
	var l2 := _uid_of(r2)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "no ink: the register as before")
	inv.add_item(&"ink", 1)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_ANSWER % 20)
	desk.interact(player)
	assert_eq(letters.state(l2), &"answered")
	var reply := inv.uids(&"letter_reply")
	assert_eq(reply.size(), 1, "Antwort im Inventar")
	inv.add_item(&"coin", 1)
	var coins := inv.count(&"coin")
	var p0 := piety.value()
	assert_true(letters.give_to_carrier(reply[0], &"carter", inv))
	assert_eq([inv.count(&"coin"), piety.value() - p0, GameState.get_stat(&"coins_spent_post")], [coins - 1, 1, 1])
	assert_eq(quests.notes(&"answer_posted"), PackedStringArray([l2]), "L4")
	letters.apply_morning(OPEN_DAY + 2)
	assert_has(notes, (Database.letter(&"lp_l2_sister") as LetterData).reply_text)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ)


func test_post_read_at_the_grave_and_the_ghost_that_night() -> void:
	var inv := player.inventory
	var marthe := corpses.spawn_corpse(StoryDirector.make_record(Database.story_corpse(&"s1_quendel") as StoryCorpseData, 11))
	var grave := _bury(marthe)
	letters.apply_morning(OPEN_DAY + 3)
	var post := letters.post_today(OPEN_DAY + 3)
	assert_eq(post.size(), 1, "Osric's post on p9_open_day + 3")
	assert_true(inv.has_uid(post[0]))
	assert_eq(letters.letter(post[0]).id, &"lpo_quendel")
	var plot := _plot(grave)
	assert_not_null(plot)
	TimeManager.set_time(OPEN_DAY + 3, 1100)
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_READ_LETTER % 10)
	assert_true(plot.can_interact(player))
	var p0 := piety.value()
	plot.interact(player)
	assert_eq(letters.state(post[0]), &"read_grave")
	assert_eq([piety.value() - p0, letters.ghost_bonus(grave)], [1, 1], "Pietät +1, Geist +1 tonight")
	TimeManager.set_time(OPEN_DAY + 4, 60)
	assert_true(letters.letter_tonight(grave), "the same night after midnight")
	TimeManager.set_time(OPEN_DAY + 4, 700)
	assert_false(letters.letter_tonight(grave))
	assert_ne(plot.get_interaction_prompt(player), GravePlot.PROMPT_READ_LETTER % 10, "decided")


func test_lay_the_letter_into_the_open_grave_of_its_sender() -> void:
	var inv := player.inventory
	var r := _deliver_and_examine(OPEN_DAY, false)
	var uid := _uid_of(r)
	var grave := _free_plot()
	graveyard.dig(grave)
	var plot := _plot(grave)
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_FETCH, "empty hands: fetch the dead")
	assert_true(corpses.pick_up(r.id, player))
	# W3 QA-Fix QA9-02: „Bestatten" stays the main action; the letter goes with the dead only when chosen.
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_BURY_CHOICE % GravePlot._bury_minutes(player),
			"[E] Bestatten … (the choice)")
	var ctx := plot.bury_choice_context(player)
	assert_eq((ctx.options as Array).map(func(o: Dictionary) -> StringName: return o.id),
			[GravePlot.OPTION_BURY, GravePlot.P9_BURY_LETTER], "„Bestatten“ first")
	var p0 := piety.value()
	plot.interact(player)
	assert_eq(letters.state(uid), &"found", "[E] alone decides nothing")
	plot.request_action(GravePlot.P9_BURY_LETTER)
	assert_eq(letters.state(uid), &"buried")
	assert_false(inv.has_uid(uid))
	# the burial itself (no shroud …) counts as always – the letter adds its +1
	var delta := piety.value() - p0
	var burial := _plain_burial_piety(_deliver_and_examine(OPEN_DAY + 1, false))
	assert_eq([delta - burial, letters.ghost_bonus(grave)], [1, 1], "Pietät +1, Geist +1 for good")
	assert_eq(graveyard.get_grave(grave).state, GraveRecord.State.FILLED, "buried in the same work")
	assert_eq(graveyard.get_grave(grave).corpse_id, r.id)


## The piety a plain burial of `r` brings (its letter stays in the bag) – measured on the next free plot.
func _plain_burial_piety(r: CorpseRecord) -> int:
	var grave := _free_plot()
	graveyard.dig(grave)
	if player.carried_id != "":
		return 0
	var p0 := piety.value()
	if not corpses.pick_up(r.id, player):
		return 0
	var plot := _plot(grave)
	plot.interact(player)
	plot.request_action(GravePlot.OPTION_BURY)
	return piety.value() - p0


## QA9-02: „Bestatten" in the choice buries the dead and keeps the letter in the bag (to be handed over later).
func test_bury_without_the_letter_keeps_it() -> void:
	var inv := player.inventory
	var r := _deliver_and_examine(OPEN_DAY, false)
	var uid := _uid_of(r)
	var grave := _free_plot()
	graveyard.dig(grave)
	var plot := _plot(grave)
	assert_true(corpses.pick_up(r.id, player))
	plot.interact(player)
	plot.request_action(GravePlot.OPTION_BURY)
	assert_eq(graveyard.get_grave(grave).state, GraveRecord.State.FILLED, "buried")
	assert_eq(letters.state(uid), &"found", "the letter stays open")
	assert_true(inv.has_uid(uid), "and in the bag")


func test_errands_both_decisions() -> void:
	var inv := player.inventory
	var table: Dictionary[StringName, OrderData] = {}
	for id: StringName in Phase9Fixtures.ORDER_IDS:
		table[id] = Phase9Fixtures.order(id)
	orders.order_table = table
	for id: StringName in [&"oq_gesa_brother", &"oq_fenner_seal"]:
		orders.offer(id)
		orders.accept(id)
	assert_eq(orders.state(&"oq_gesa_brother"), &"accepted")
	inv.add_item(&"coin", 3)
	var p0 := piety.value()
	# E1 a: paying the postage yourself.
	var e1 := letters.errand_letter(&"oq_gesa_brother", inv)
	assert_true(letters.give_to_carrier(e1, &"peddler", inv))
	assert_eq([piety.value() - p0, orders.state(&"oq_gesa_brother")], [1, &"completed"])
	# E1 b: asking Gesa – straw flowers instead of piety.
	var e1b := letters.errand_letter(&"oq_gesa_brother", inv)
	assert_true(letters.ask_postage(e1b, inv))
	assert_true(letters.give_to_carrier(e1b, &"carter", inv))
	assert_eq([piety.value() - p0, inv.count(&"straw_bouquet")], [1, 1])
	# E2 a: delivered sealed.
	rel.meet(&"mayor")
	var fenner := rel.value(&"mayor")
	var e2 := letters.errand_letter(&"oq_fenner_seal", inv)
	assert_true(letters.decide(e2, &"deliver", {"inventory": inv, "npc": &"priest"}))
	assert_eq([orders.state(&"oq_fenner_seal"), rel.value(&"mayor") - fenner], [&"completed", 0])
	# E2 b: looked inside – Fenner always sees it.
	var e2b := letters.errand_letter(&"oq_fenner_seal", inv)
	assert_true(letters.decide(e2b, &"read", {"inventory": inv}))
	assert_eq(rel.value(&"mayor") - fenner, -3)
	assert_true(letters.decide(e2b, &"deliver", {"inventory": inv, "npc": &"priest"}))


func test_chain_prompts_of_p4_at_the_desk_and_the_grave() -> void:
	var who := WhoKnowsDouble.new()
	world.add_child(who)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_KLADDE % 20)
	desk.interact(player)
	assert_eq(who.kladde_read, 1, "H1: WhoKnows.read_kladde after the timed action")
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "read once (kladde_read)")
	who.step_h2 = true
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_REGISTER_LIST % 30)
	desk.interact(player)
	assert_has(notes, Desk.TEXT_REGISTER)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "compared once")
	who.deciding = true
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ, "no ink: no nameless letter")
	player.inventory.add_item(&"ink", 1)
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_NAMELESS % 20)
	desk.interact(player)
	assert_eq([player.inventory.count(&"nameless_letter"), player.inventory.count(&"ink")], [1, 0])
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ)
	var r := corpses.spawn_corpse()
	var grave := _bury(r)
	var plot := _plot(grave)
	who.comparable.append(grave)
	assert_eq(plot.get_interaction_prompt(player), GravePlot.PROMPT_DATE % 5)
	plot.interact(player)
	assert_eq(who.compared, [grave] as Array[String])
	assert_ne(plot.get_interaction_prompt(player), GravePlot.PROMPT_DATE % 5)


func test_the_held_back_plot_of_the_fourth_row() -> void:
	var who := WhoKnowsDouble.new()
	world.add_child(who)
	who.held = graveyard.free_plot_count()
	TimeManager.set_time(OPEN_DAY, 470)
	assert_null(corpses.try_daily_delivery(OPEN_DAY), "every free plot held back: no delivery („halt eine Grube frei“)")
	assert_eq(corpses.records().size(), 0)
	who.held = 1
	TimeManager.set_time(OPEN_DAY + 1, 470)
	assert_not_null(corpses.try_daily_delivery(OPEN_DAY + 1), "one held back, the others take the day's dead")


## W3 QA-Fix QA9-01: the forge's [E] stays the forge with a letter in the bag – ForgeLetter takes no focus; the
## crafting panel's „Brief verbrennen …" opens the choice and only the chosen letter burns there.
func test_forge_stays_the_forge_and_burns_only_the_chosen_letter() -> void:
	var inv := player.inventory
	var r1 := _deliver_and_examine(OPEN_DAY)
	var r2 := _deliver_and_examine(OPEN_DAY + 1)
	var first := _uid_of(r1)
	var second := _uid_of(r2)
	var station := world.get_node("Entities/station_forge") as Workbench
	var fl := station.get_node("ForgeLetter") as ForgeLetter
	var shop := tree.get_first_node_in_group(&"workshop") as Workshop
	shop._built.append(&"forge")
	station.refresh_built()
	assert_true(fl.forge_ready(), "the forge stands")
	assert_null(fl.get_node_or_null("Interactable"), "no prompt of its own")
	assert_eq(fl.get_interaction_prompt(player), "")
	var station_prompt := station.get_interaction_prompt(player)
	assert_false(station_prompt.contains("Brief"), "[E] at the forge stays the forge: %s" % station_prompt)
	var panels: Array = []
	var on_panel := func(id: StringName, ctx: Dictionary) -> void: panels.append([id, ctx])
	EventBus.ui_panel_requested.connect(on_panel)
	station.interact(player)
	assert_eq(panels.size(), 1)
	if panels.size() == 1:
		assert_eq(panels[0][0], &"crafting", "the forge's own panel")
	assert_eq([letters.state(first), letters.state(second)], [&"found", &"found"], "nothing burned by [E]")
	assert_true(fl.can_burn(player), "the crafting panel offers „Brief verbrennen …“")
	assert_true(fl.open_choice(player))
	EventBus.ui_panel_requested.disconnect(on_panel)
	assert_eq(panels.size(), 2)
	if panels.size() == 2:
		assert_eq(panels[1][0], LetterBurning.PANEL)
		var ids: Array = (panels[1][1].options as Array).map(func(o: Dictionary) -> StringName: return o.id)
		assert_eq(ids, [StringName(LetterBurning.PREFIX + first), StringName(LetterBurning.PREFIX + second)])
	UIState.clear()
	fl.request_action(StringName(LetterBurning.PREFIX + second))
	assert_eq([letters.state(first), letters.state(second)], [&"found", &"burned"], "the chosen letter only")
	assert_true(inv.has_uid(first))


## W3 QA-Fix QA9-04: at a grave with a letter to read aloud *and* seedlings / a candle in the bag every action is
## reachable – the choice lists the letter first, then the care; Phase-8 graves without Phase-9 work stay one press.
func test_grave_choice_reaches_the_letter_and_the_care() -> void:
	var inv := player.inventory
	var marthe := corpses.spawn_corpse(StoryDirector.make_record(Database.story_corpse(&"s1_quendel") as StoryCorpseData, 11))
	var grave := _bury(marthe)
	letters.apply_morning(OPEN_DAY + 3)
	var post := letters.post_today(OPEN_DAY + 3)
	assert_eq(post.size(), 1)
	var plot := _plot(grave)
	TimeManager.set_time(OPEN_DAY + 3, 17 * 60)
	inv.add_item(&"flower_seedlings", 1)
	inv.add_item(&"grave_candle", 1)
	var actions := plot.grave_actions(player)
	assert_eq(actions[0], GravePlot.P9_READ, "the letter first: %s" % [actions])
	assert_true(GravePlot.CARE_PLANT in actions, "the flowers reachable")
	var prompt := plot.get_interaction_prompt(player)
	assert_true(prompt.begins_with("[E] Am Grab: Brief am Grab vorlesen"), prompt)
	plot.interact(player)
	assert_eq(letters.state(post[0]), &"received", "[E] opens the choice")
	plot.request_action(GravePlot.CARE_PLANT)
	var care := tree.get_first_node_in_group(&"grave_care") as GraveCare
	assert_ne(care.flowers_state(grave), &"", "the flowers set")
	assert_eq(letters.state(post[0]), &"received", "the letter still there")
	plot.request_action(GravePlot.P9_READ)
	assert_eq(letters.state(post[0]), &"read_grave", "then read aloud")
	# no Phase-9 work left: the grave is one press as before (care order)
	assert_eq(plot.grave_actions(player), [] as Array[StringName])
	assert_false(plot.get_interaction_prompt(player).begins_with("[E] Am Grab:"))


func test_without_the_phase9_nodes_the_prompts_stay() -> void:
	letters.free()
	quests.free()
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_READ)
	assert_eq(stove.get_interaction_prompt(player), Stove.PROMPT_WARM)
	var r := corpses.spawn_corpse()
	var grave := _bury(r)
	assert_eq(_plot(grave).phase9_action(player), &"")


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


## W2 (W-Welt): the world carries the four Phase-9 systems now – this test brings its own (as in W1), so the world's are
## taken out first (the world as the test was written against).
static func _without_world_phase9(systems: Node) -> void:
	for n: String in ["Quests", "WhoKnows", "Letters", "Stranger"]:
		var node := systems.get_node_or_null(n)
		if node != null:
			systems.remove_child(node)
			node.free()
