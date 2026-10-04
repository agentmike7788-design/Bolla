extends TestCase
## W-Welt (docs/PHASE4_DESIGN.md §10): the Phase-4 loop on the real world through SaveManager
## (instant actions, the morgue table / corpse / obstacle entities, the real systems).
## Day 1: corpse → clothing + pockets → shroud → burial. Day 3: the mark waits too long and is
## lost (no c_mark). Day 4: the note at the door; the hair button is dimmed until Ilse's tools;
## 23:30 Ilse at the west wall → dialogue action trader_tools. Day 5: braid cut → sold at night
## (coins at once), linen and juniper bought. Day 6: S1 examined in full → c_page_1 → link with
## c_warning_letter → i_warnings; juniper window; washed, gown, laid out, buried. S2 (debug) →
## the key in her pockets → the Holunderwinkel cleared through its obstacles (300 minutes).
## S5 (debug) → i_not_lorenz → renamed "Kaspar Dorn" → six plots MARKED → chapter six_pits.
## collect_state() is identical after save_game / load_game at four moments: mid-examination
## (2 of 4 steps), during a juniper window, at night with Ilse at her spot and half her stock
## sold, after the chapter end.

const TIMEOUT := 300.0
const SLOT := 92
const DELIVERY := 460
const ELDER_MINUTES := 300

var saves_dir := TestCase.user_dir("test_saves_p4_loop")
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var manager: CorpseManager
var expansion: ExpansionManager
var care: CorpseCare
var journal: JournalManager
var trade: NightTrade
var table: MorgueTable
var chapters: Array = []
var stories: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	stories.clear()
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.story_corpse_arrived.connect(_on_story)
	await SaveManager.new_game()
	_bind()
	TimeManager.running = false


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.story_corpse_arrived.disconnect(_on_story)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase4_loop_with_round_trips() -> void:
	# More plots than the old yard (debug unlock of the Ostwiese), so the story can arrive.
	assert_true(expansion.unlock(&"east"))
	# --- day 1: clothing + pockets, round trip mid-examination, shroud, burial ----------------
	var r1 := await _deliver_to_table(1)
	assert_not_null(r1, "day 1 delivery")
	if r1 == null:
		return
	table.request_exam_step(&"clothing")
	table.request_exam_step(&"pockets")
	assert_eq(r1.exam_done.size(), 2, "2 of 4 steps")
	await _round_trip("mid-examination")
	r1 = manager.get_record(r1.id)
	assert_eq(r1.exam_done, [&"clothing", &"pockets"] as Array[StringName], "steps survive the load")
	assert_true(r1.examined)
	_decide(false)
	player.inventory.add_item(&"shroud", 1)
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	assert_eq(r1.dress, CorpseRecord.DRESS_SHROUD)
	_bury_table_corpse("plot_01")
	# --- day 2: a plain day ------------------------------------------------------------------
	var r2 := await _deliver_to_table(2)
	table.request_exam_all()
	_decide(false)
	_bury_table_corpse("plot_02")
	assert_eq(r2.location, CorpseRecord.LOCATION_BURIED)
	# --- day 3: the mark (min freshness 0.3) is lost when the corpse waits until the next dawn --
	var r3 := await _deliver_to_table(3)
	assert_has(r3.traits, &"strange_wound")
	_until(4, 330)  # 05:30 of day 4
	assert_true(r3.freshness < 0.3, "the corpse waited (%.2f)" % r3.freshness)
	table.request_exam_all()
	assert_false(journal.has_clue(&"c_mark"), "the mark is lost – no c_mark")
	assert_true(r3.finds_lost.size() > 0, "a lost find on the death note")
	_decide(false)
	_bury_table_corpse("plot_03")
	# --- day 4: the note at the door; hair dimmed without tools; Ilse at 23:30 -----------------
	_until(4, 370)
	assert_true(GameState.has_flag(&"trader_known"), "after 06:00: the note at the door")
	assert_true(journal.has_clue(&"c_trader_note"))
	assert_true((world.get_node("Decor/DoorNote") as Node3D).visible, "the note shows on the door")
	var r4 := await _deliver_to_table(4)
	var reason := care.harvest_block_reason(r4.id, CorpseRecord.HARVEST_HAIR, player.inventory)
	assert_ne(reason, "", "no shears yet")
	assert_ne(reason, UtilizationRules.HIDDEN, "the button shows (dimmed)")
	table.request_exam_all()
	assert_true(journal.has_clue(&"c_warning_letter"), "the letter in her pockets")
	_decide(false)
	player.inventory.add_item(&"shroud", 1)
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	_bury_table_corpse("plot_04")
	_until(4, 1410)
	await wait_frames(2)
	var ilse := world.get_node_by_layout_id("npc_trader") as Npc
	assert_true(trade.is_present(), "23:30 Ilse at the west wall")
	_assert_xz(ilse.global_position, world.get_waypoint(&"trader_spot"), "at trader_spot")
	DialogueActions.apply("trader_tools", {"inventory": player.inventory, "speaker": ilse})
	assert_eq([player.inventory.count(&"shears"), player.inventory.count(&"pliers")], [1, 1], "her gift")
	assert_true(trade.tools_given())
	TimeManager.advance(1)
	assert_false((world.get_node("Decor/DoorNote") as Node3D).visible, "the note is gone once met")
	# --- day 5: braid cut, sold at night; linen and juniper bought -----------------------------
	var r5 := await _deliver_to_table(5)
	assert_eq(care.harvest_block_reason(r5.id, CorpseRecord.HARVEST_HAIR, player.inventory), "", "shears in hand")
	var piety_before := GameState.get_stat(&"piety")
	table.request_harvest(CorpseRecord.HARVEST_HAIR)
	assert_eq(player.inventory.count(&"hair_braid"), 1, "the braid")
	assert_eq(GameState.get_stat(&"piety"), piety_before - 4, "§2.7 hair_taken −4")
	table.request_exam_all()
	_decide(false)
	player.inventory.add_item(&"shroud", 1)
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	_bury_table_corpse("plot_05")
	_until(5, 1410)
	await wait_frames(2)
	assert_true(trade.is_present())
	player.inventory.add_item(&"coin", 10)
	var coins := player.inventory.count(&"coin")
	var price := trade.quote(&"hair_braid", 1)
	assert_true(price >= 4, "§2.6: 4 coins (+ bonus) – %d" % price)
	assert_eq(trade.sell(&"hair_braid", 1, player.inventory), price, "sold")
	assert_eq(player.inventory.count(&"coin"), coins + price, "coins at once")
	assert_eq(player.inventory.count(&"hair_braid"), 0)
	assert_true(trade.buy(&"linen", 1, player.inventory), "linen bought")
	assert_true(trade.buy(&"juniper", 2, player.inventory), "juniper bought")
	assert_eq([trade.stock_left(&"linen"), trade.stock_left(&"juniper")], [2, 2], "half her juniper left")
	await _round_trip("at night with Ilse at her spot")
	assert_true(trade.is_present(), "Ilse still at the wall after the load")
	assert_eq([trade.stock_left(&"linen"), trade.stock_left(&"juniper")], [2, 2], "stock survives the load")
	assert_eq(GameState.get_stat(&"trader_sales"), 1)
	# --- day 6: S1 – full examination, the link, juniper window, full preparation --------------
	var s1 := await _deliver_to_table(6)
	assert_eq(stories, [&"s1_quendel"], "S1 on day 6")
	assert_eq(s1.story_id, &"s1_quendel")
	table.request_exam_all()
	assert_true(s1.is_fully_examined())
	assert_true(journal.has_clue(&"c_page_1"), "the page from her pockets")
	assert_eq(journal.try_link([&"c_warning_letter", &"c_page_1"] as Array[StringName]), &"i_warnings")
	assert_true(GameState.has_flag(&"insight_warnings"))
	table.request_balm()
	assert_eq(player.inventory.count(&"juniper"), 1, "one juniper burnt")
	assert_true(s1.balm_windows.size() > 0, "a juniper window runs")
	var corpse_node := manager.get_corpse_node(s1.id)
	corpse_node.refresh_decay()
	assert_true(corpse_node.decay_visual.smoke_on(), "juniper smoke on the table")
	await _round_trip("during a juniper window")
	s1 = manager.get_record(s1.id)
	assert_true(manager.get_corpse_node(s1.id).decay_visual.smoke_on(), "the window survives the load")
	for item: StringName in [&"scrub_brush", &"comb", &"burial_gown"]:
		player.inventory.add_item(item, 1)
	var piety_prep := GameState.get_stat(&"piety")
	table.request_wash()
	table.request_dress(CorpseRecord.DRESS_GOWN)
	table.request_lay_out()
	assert_true(s1.is_fully_prepared(), "washed, gown, laid out")
	assert_eq(GameState.get_stat(&"piety"), piety_prep + 3, "§2.7 full_prep +3")
	_bury_table_corpse("plot_06")
	# --- S2 (debug): the key in his pockets → the Holunderwinkel ------------------------------
	var s2 := manager.deliver_story_now(&"s2_hemmerling")
	assert_not_null(s2, "S2 delivered (debug)")
	if s2 == null:
		return
	_carry_to_table(s2)
	table.request_exam_all()
	assert_true(GameState.has_flag(&"has_elder_key"), "the key to the Holunderwinkel")
	_decide(false)
	player.inventory.add_item(&"shroud", 1)
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	_bury_table_corpse("plot_07")
	player.inventory.add_item(&"wood", 2)
	player.inventory.add_item(&"iron_fittings", 1)
	var start := TimeManager.total_minutes()
	for id: String in expansion.obstacle_ids(&"elder"):
		var node := expansion.obstacle(id)
		assert_true(node.can_interact(player), "%s: %s" % [id, node.get_interaction_prompt(player)])
		node.interact(player)
		assert_true(expansion.is_cleared(id), id + " cleared")
	assert_eq(TimeManager.total_minutes() - start, ELDER_MINUTES, "§2.10: 300 minutes")
	assert_true(expansion.is_unlocked(&"elder"))
	assert_true(journal.has_clue(&"c_six_pits"))
	# --- S5 (debug): not Lorenz → Kaspar Dorn → six pits → chapter end ---------------------------
	var s5 := manager.deliver_story_now(&"s5_moor")
	assert_not_null(s5, "S5 delivered (debug)")
	if s5 == null:
		return
	_carry_to_table(s5)
	table.request_exam_all()
	for clue: StringName in [&"c_soft_hands", &"c_buckle", &"c_page_list"]:
		assert_true(journal.has_clue(clue), clue)
	assert_eq(journal.try_link([&"c_page_list", &"c_soft_hands", &"c_buckle"] as Array[StringName]), &"i_not_lorenz")
	assert_true(GameState.has_flag(&"insight_not_lorenz"))
	var named := ""
	for p: Dictionary in journal.people():
		if String(p.corpse_id) == s5.id:
			named = String(p.name)
	assert_eq(named, "Kaspar Dorn", "the journal renames S5")
	_decide(false)
	player.inventory.add_item(&"shroud", 1)
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	_bury_table_corpse("h_01")
	assert_eq(chapters.size(), 0, "five pits still open")
	for i: int in range(2, 7):
		_complete_grave("h_%02d" % i)
	assert_eq(chapters, [&"six_pits"], "chapter_completed(six_pits) once")
	assert_true(GameState.has_flag(&"six_pits_complete"))
	UIState.clear()
	await _round_trip("after the chapter end")
	assert_true(GameState.has_flag(&"six_pits_complete"))
	assert_true(journal.has_insight(&"i_not_lorenz"))


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	manager = world.corpse_manager
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	care = world.get_node("Systems/CorpseCare") as CorpseCare
	journal = world.get_node("Systems/Journal") as JournalManager
	trade = world.get_node("Systems/NightTrade") as NightTrade
	table = MorgueTable.active(tree)  # 04.10.2026: the crypt table from day 1


## Save → load → identical collect_state(); rebinds the new world.
func _round_trip(moment: String) -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	TimeManager.running = false
	await wait_frames(1)
	var after := SaveManager.collect_state()
	# Phase 6 (W-Welt): on the 64 × 80 m ground collision the gravekeeper settles by one float32 ulp
	# after a load; positions count as equal within 1e-5 m (everything else stays exact).
	var p_before: Variant = (before.nodes as Dictionary).get("player", {}).get("position")
	var p_after: Variant = (after.nodes as Dictionary).get("player", {}).get("position")
	if p_before is Vector3 and p_after is Vector3 and (p_before as Vector3).is_equal_approx(p_after) \
			and (p_before as Vector3).distance_to(p_after) < 1e-5:
		(after.nodes.player as Dictionary)["position"] = p_before
	assert_eq(after, before, moment + ": collect_state identical after save → load")


## Advances the clock to `minute` of `day` unless it is already later (instant actions take
## game minutes: a long burial may run past the next delivery).
func _until(day: int, minute: int) -> void:
	if TimeManager.total_minutes() < (day - 1) * 1440 + minute:
		TimeManager.set_time(day, minute)


## The morning of `day` (07:40 delivery) → the corpse from the bier onto the table.
func _deliver_to_table(day: int) -> CorpseRecord:
	_until(day, DELIVERY)
	await wait_frames(1)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert_not_null(record, "delivery on day %d" % day)
	if record != null:
		_carry_to_table(record)
	return record


func _carry_to_table(record: CorpseRecord) -> void:
	manager.get_corpse_node(record.id).interact(player)
	assert_eq(player.carried_id, record.id, "carrying " + record.id)
	table.interact(player)
	assert_eq(record.location, CorpseRecord.LOCATION_TABLE, record.id + " on the table")
	table.interact(player)  # opens the panel: the table acts for this player


func _decide(take: bool) -> void:
	var record := manager.get_record(table.corpse_id)
	if record != null and record.needs_valuables_decision():
		table.decide_valuables(take)


## Table corpse → dig `grave_id` → bury → wooden cross, through the real plot entity.
func _bury_table_corpse(grave_id: String) -> void:
	var id := table.corpse_id
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	plot.interact(player)
	assert_eq(graveyard.get_grave(grave_id).state, GraveRecord.State.DUG, grave_id + " dug")
	table.request_pick_up()
	assert_eq(player.carried_id, id)
	plot.interact(player)
	assert_eq(graveyard.get_grave(grave_id).state, GraveRecord.State.FILLED, grave_id + " filled")
	player.inventory.add_item(&"wooden_cross", 1)
	plot.interact(player)
	assert_eq(graveyard.get_grave(grave_id).state, GraveRecord.State.MARKED, grave_id + " marked")
	UIState.clear()


## A fresh, examined, shrouded corpse buried in `grave_id` with a cross (real Graveyard API).
func _complete_grave(grave_id: String) -> void:
	var plot := world.get_node_by_layout_id(grave_id) as Node3D
	var record := manager.spawn_corpse(null, plot.global_transform, &"ground")
	record.examined = true
	record.shrouded = true
	record.dress = CorpseRecord.DRESS_SHROUD
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(graveyard.dig(grave_id), grave_id + " dug")
	assert_true(graveyard.bury(grave_id, record.id), grave_id + " buried")
	player.inventory.add_item(&"wooden_cross", 1)
	assert_true(graveyard.place_marker(grave_id, &"wooden_cross", player.inventory) >= 0)


func _record_at(location: StringName) -> CorpseRecord:
	for r: CorpseRecord in manager.records():
		if r.location == location:
			return r
	return null


func _assert_xz(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost(actual.x, expected.x, 0.01, message + " x")
	assert_almost(actual.z, expected.z, 0.01, message + " z")


func _on_chapter(chapter_id: StringName) -> void:
	chapters.append(chapter_id)


func _on_story(story_id: StringName, _corpse_id: String) -> void:
	stories.append(story_id)
