extends TestCase
## W-Welt (docs/PHASE9_DESIGN.md §10 test_phase9_loop): the Phase-9 chain on the real world through SaveManager, from
## the Phase-8 end state (v7 fixture slot_p8_day63_kindly, day 63 07:00) – the systems of the world itself (Quests,
## WhoKnows, Letters, Stranger in Systems, HillRequests, CorpseManager, Expansion), the real clock (TimeManager.advance,
## nothing teleported), the real prompts where an entity has one (the hut's Desk and Stove, the GravePlots, the KnockDoor
## at the Siebers, the VisitSpot at the gate), the figures placing themselves from their plans (Brenneisen at the gate,
## Johann on his bench, on his way with Hanne or on Osric's cart). Where the contract has a dialogue or a panel (W-UI /
## P6) the call the dialogue action or the panel makes (witness:<entry>, mark_seen, quest_choose, letter_deliver, the
## large request's accept; set_part for the parts that are crafting and placing – the visit part runs at its spot).
## Stand-ins: ink bought at Theres' (inventory), Fenner's grant (his dialogue action set_flag:linden_row4_granted).
## Run 1 (ending A): p9_open → Kladde → register → five graves → three witnesses → row 4 cleared → large request with
## 2/3 parts → its visit at the gate → three deliveries into row 4 with L1–L3 (Rosine, the answer by post, the stove) →
## Brenneisen at the gate (bell) → Johann on the bench, the KnockDoor → Liesel → the post for the dead read at the grave →
## Gesa's errand → the second large request → the nameless letter at the Siebers' door → away → the departure (Hanne or
## Osric) → sieber_gone → chapter „Wer weiß, wann?". Run 2 (ending B): … stay → the death night 02:20 → D3 into the held
## plot of row 4. collect_state() identical after save → load at 7 moments: the Kladde read (timed action over),
## Brenneisen at the gate, Johann on the bench, the large request at 2/3, the departure, the death night 02:20, after the
## chapter.

const TIMEOUT := 1800.0
const SLOT := 95
const FIXTURE := "slot_p8_day63_kindly"
const ROW4: PackedStringArray = ["l_13", "l_14", "l_15", "l_16"]
const WITNESSES: Array[StringName] = [&"e_quendel", &"e_wernstein", &"e_hagedorn"]
const MAIN := &"q_who_knows"
const LETTERS_Q := &"q_letters"

var saves_dir := TestCase.user_dir("test_saves_p9_loop")
var world: WorldRoot
var player: Player
var quests: Quests
var who: WhoKnows
var letters: Letters
var stranger: Stranger
var hill: HillRequests
var corpses: CorpseManager
var care: CorpseCare
var graveyard: Graveyard
var expansion: ExpansionManager
var orders: Orders
var rel: Relationships
var chapters: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	EventBus.chapter_completed.connect(_on_chapter)
	assert_eq(Phase9Fixtures.install_save_v7(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	if is_instance_valid(player):
		player.cancel_timed_action()
		if player.region_id != &"graveyard":
			player.set_region(&"graveyard")
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase9_loop_ending_a_to_the_chapter() -> void:
	if world == null:
		return
	await _h1_to_h3()
	await _row4()
	# --- a large request at the gate: two parts done, the round trip, the visit part at its spot (21:30–23:00) -------
	_take_large(&"hrl_lantern_path")
	assert_true(hill.set_part(&"hrl_lantern_path", 0) and hill.set_part(&"hrl_lantern_path", 1), "crafting and placing (stand-in)")
	assert_eq(hill.parts_done(&"hrl_lantern_path"), [true, true, false] as Array[bool])
	await _round_trip("a large request at 2/3")
	await _run_to(63, 21 * 60 + 40)
	var visit := world.get_node("Entities/visit_gate_outside") as VisitSpot
	await _stand_at(world.get_waypoint(&"gate_outside"))
	assert_eq(visit.request_here(), &"hrl_lantern_path", "the visit part waits at the gate")
	assert_true(visit.can_interact(player), "„%s“" % visit.get_interaction_prompt(player))
	visit.interact(player)
	await _settle()
	assert_false(hill.large_active().has(&"hrl_lantern_path"), "the visit part done – the request completed")
	assert_eq(int(quests.goal_progress().large), 1, "the first large request since p9_open")
	# --- three deliveries into row 4 carry L1–L3 --------------------------------------------------------------------
	var r1 := await _deliver(64)
	assert_not_null(r1, "delivery 1 into row 4")
	if r1 == null:
		return
	assert_eq(r1.letter_id, &"lp_l1_carter", "§2.4.2: forced L1")
	var l1 := _uid_of(r1)
	rel.meet(&"innkeeper")
	assert_true(letters.decide(l1, &"deliver", {"inventory": player.inventory, "npc": &"innkeeper"}), "L1 to Rosine")
	# The second large request (crafting and turning in: stand-in parts).
	_take_large(&"hrl_crosses")
	for i: int in hill.parts_done(&"hrl_crosses").size():
		hill.set_part(&"hrl_crosses", i)
	assert_eq(int(quests.goal_progress().large), 2, "the second large request since p9_open")
	var r2 := await _deliver(65)
	assert_not_null(r2, "delivery 2")
	if r2 == null:
		return
	assert_eq(r2.letter_id, &"lp_l2_sister")
	var l2 := _uid_of(r2)
	# The answer at the hut's desk (ink from Theres), then by Osric's post.
	player.inventory.add_item(&"ink", 2)
	var desk := _entity(Desk) as Desk
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_ANSWER % 20, "the desk offers the answer")
	desk.interact(player)
	await _settle()
	assert_eq(letters.state(l2), &"answered")
	var reply := player.inventory.uids(&"letter_reply")
	assert_eq(reply.size(), 1, "the answer in the bag")
	assert_true(letters.give_to_carrier(reply[0], &"carter", player.inventory), "Osric takes the answer")
	# --- Brenneisen at the gate (p9_open_day + 2, 14:10) -----------------------------------------------------------
	var bell := world.get_node("StrangerBell") as StrangerBell
	var rings := bell.rings
	await _run_to(65, 14 * 60 + 20)
	assert_true(stranger.present(&"graveyard"), "§2.5.1: he waits outside the gate")
	var brenneisen := world.get_node("Entities/npc_stranger_g") as Npc
	brenneisen.refresh()
	assert_true(brenneisen.is_present(), "his figure at the gate")
	assert_true(_flat(brenneisen.global_position).distance_to(_flat(world.get_waypoint(&"stranger_gate"))) < 0.3, "on stranger_gate")
	assert_true(bell.rings > rings, "the gate bell swung for him")
	await _round_trip("Brenneisen at the gate")
	var r3 := await _deliver(66)
	# Osric's post for the dead (p9_open_day + 3) – read at Marthe's grave before the stove takes a letter.
	await _read_post(66)
	assert_not_null(r3, "delivery 3")
	if r3 != null:
		assert_eq(r3.letter_id, &"lp_l3_burn")
		var stove := _entity(Stove) as Stove
		# W3 QA-Fix QA9-03: [E] opens the choice (warming first, then the letter); the chosen letter burns.
		assert_eq(stove.get_interaction_prompt(player), Stove.PROMPT_CHOICE)
		stove.interact(player)
		stove.request_action(StringName(LetterBurning.PREFIX + _uid_of(r3)))
		await _settle()
		assert_eq(letters.state(_uid_of(r3)), &"burned", "L3 burned unread at the stove")
	# --- H4: Johann shows the mark; on his bench in the village, the KnockDoor -----------------------------------------
	who.mark_seen()
	assert_eq(quests.current_step(MAIN), &"h5", "H4 done")
	await _run_to(66, 14 * 60 + 30)
	player.set_region(&"village")
	var johann := world.get_node("Regions/Village/Entities/npc_kin_sieber_v") as Npc
	johann.refresh()
	assert_true(johann.is_present(), "§2.2.5: Johann on his bench 14:00–16:00")
	var seat := (world.get_node("Regions/Village") as RegionRoot).get_waypoint(&"v_sieber_bench")
	assert_true(_flat(johann.global_position).distance_to(_flat(seat)) < 0.3, "on v_sieber_bench")
	assert_eq(johann.current_animation(), &"sit_bench")
	var door := world.get_node("Regions/Village/Entities/door_sieber") as KnockDoor
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_KNOCK)
	await _round_trip("Johann on the bench")
	door = world.get_node("Regions/Village/Entities/door_sieber") as KnockDoor
	player.set_region(&"graveyard")
	# --- H5 (Liesel) ----------------------------------------------------------------------------------------------
	assert_true(quests.choose(MAIN, &"h5", &"confide_washer"))
	if orders.state(&"oq_gesa_brother") == &"offered":
		orders.accept(&"oq_gesa_brother")
	assert_eq(orders.state(&"oq_gesa_brother"), &"accepted", "L3: Gesa's errand taken")
	var errand := letters.errand_letter(&"oq_gesa_brother", player.inventory)
	assert_true(letters.give_to_carrier(errand, &"carter", player.inventory), "E1 by Osric's post")
	# --- ending A: the nameless letter at the Siebers' door at night, the choice, the departure ------------------------
	desk = _entity(Desk) as Desk
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_NAMELESS % 20, "the nameless letter at the desk")
	desk.interact(player)
	await _settle()
	assert_true(player.inventory.has(&"nameless_letter"))
	await _run_to(66, 21 * 60 + 30)
	player.set_region(&"village")
	assert_eq(door.get_interaction_prompt(player), KnockDoor.PROMPT_LETTER, "at night with the letter")
	door.interact(player)
	assert_true(who.letter_posted(), "the letter in the Siebers' door")
	player.set_region(&"graveyard")
	assert_true(quests.choose(MAIN, &"h6", &"away"), "ending A")
	await _run_to(66, 21 * 60 + 31)
	var plan := who.depart_plan()
	assert_false(plan.is_empty(), "the departure planned")
	var minute := int(plan.get("minute", 600))
	await _run_to(int(plan.get("day", 67)), minute + 15)
	var walker := world.get_node("Entities/npc_kin_sieber_v_g") as Npc
	walker.refresh()
	if StringName(plan.get("with", &"")) == &"carter":
		var rider := world.get_node("Entities/CartRider") as CartRider
		await _settle()
		assert_true(rider.is_riding(), "§4.5: Johann on Osric's cart")
	else:
		assert_true(walker.is_present(), "§4.5: Johann with Hanne up the forest way")
		var hanne := world.get_node("Entities/npc_peddler_g") as Npc
		hanne.refresh()
		assert_true(_flat(walker.global_position).distance_to(_flat(hanne.global_position)) < 4.0, "close behind her")
	await _round_trip("the departure")
	await _run_to(int(plan.get("day", 67)), minute + 45)
	assert_true(GameState.flag_on(&"sieber_gone"), "gone after the walk")
	# The second post for the dead (p9_open_day + 6) – five letters decided.
	await _run_to(69, 8 * 60)
	await _read_post(69)
	assert_eq(quests.state(MAIN), &"settled", "ending A settled")
	quests.check_goal()
	var goal := quests.goal_progress()
	_log("goal %s, letters decided %d" % [goal, letters.decided_count()])
	assert_true(GameState.flag_on(&"who_knows_when_complete"), "§1.5: chapter „Wer weiß, wann?“ (%s)" % [goal])
	assert_has(chapters, &"who_knows_when")
	await _round_trip("after the chapter")


func test_phase9_loop_ending_b_death_night() -> void:
	if world == null:
		return
	await _h1_to_h3()
	await _row4()
	for day: int in [64, 65, 66]:
		assert_not_null(await _deliver(day), "delivery %d into row 4" % day)
	who.mark_seen()
	assert_true(quests.choose(MAIN, &"h5", &"confide_priest"))
	assert_true(quests.choose(MAIN, &"h6", &"stay"), "ending B")
	var light := who.light_day()
	await _run_to(light + 21, 2 * 60 + 20)
	assert_true(GameState.flag_on(&"sieber_dead"), "§2.2.2: Johann died 02:10 (light + 21)")
	await _round_trip("the death night 02:20")
	await _run_to(light + 22, 8 * 60)
	var d3: CorpseRecord = null
	for r: CorpseRecord in corpses.records():
		if r.story_id == &"d3_sieber":
			d3 = r
	assert_not_null(d3, "§2.7: D3 Johann Sieber delivered the morning after")
	if d3 == null:
		return
	# The held plot of row 4 is the one left – Johann lies there, as near to Grete as it goes.
	var free: Array[String] = []
	for id: String in ROW4:
		if graveyard.get_grave(id).state == GraveRecord.State.EMPTY:
			free.append(id)
	assert_eq(free.size(), 1, "§2.6: the held plot waited for him (%s)" % [free])
	if free.size() == 1:
		care.exam_step(d3.id, &"pockets")
		graveyard.dig(free[0])
		assert_true(graveyard.bury(free[0], d3.id), "D3 buried in row 4 (%s)" % free[0])
		assert_eq(graveyard.section_of(free[0]), &"linden_row4")


# --- the chain -----------------------------------------------------------------------------------------------------

## p9_open on loading; H1 at the desk; H2 at the desk and at the five graves; H3 (three witnesses, the insight).
func _h1_to_h3() -> void:
	assert_true(quests.is_open(), "§1.2: the v7 end state with the chapter opens Phase 9 at once")
	assert_eq(quests.open_day(), 63)
	assert_eq(quests.current_step(MAIN), &"h1")
	var inv := player.inventory
	if who.read_block_reason(inv) != "":
		inv.add_item(&"lorenz_ledger_2", 1)  # Lenz gives it back (P6 dialogue)
	var desk := _entity(Desk) as Desk
	assert_not_null(desk, "the hut's desk")
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_KLADDE % 20, "H1 at the desk")
	desk.interact(player)
	await _settle()
	assert_eq(quests.current_step(MAIN), &"h2", "the Kladde read")
	await _round_trip("the Kladde read")
	desk = _entity(Desk) as Desk
	assert_eq(desk.get_interaction_prompt(player), Desk.PROMPT_REGISTER_LIST % 30, "H2: the register")
	desk.interact(player)
	await _settle()
	for story: StringName in Phase9Fixtures.LIST_DEAD:
		var plot := _plot(str(Phase9Fixtures.LIST_DEAD[story][0]))
		assert_not_null(plot, String(story))
		if plot == null:
			continue
		# The grave's own prompt (P3) – unless another care action of the bag comes first at that grave (seedlings in the
		# kindly bag: „Grabblumen setzen"); then the call the prompt makes.
		var prompt := plot.get_interaction_prompt(player)
		if prompt.contains("Datum vergleichen"):
			# W3 QA-Fix QA9-04: with the care of the bag beside it the grave offers a choice – „Datum vergleichen" in it.
			var several := plot.grave_actions(player).size() > 1
			plot.interact(player)
			if several:
				plot.request_action(GravePlot.P9_DATE)
			await _settle()
		else:
			_log("%s shows „%s“ first – WhoKnows.compare_grave" % [plot.grave_id, prompt])
			assert_true(who.compare_grave(plot.grave_id), plot.grave_id)
	assert_eq(quests.current_step(MAIN), &"h3", "„Immer drei Wochen.“")
	for e: StringName in WITNESSES:
		assert_true(who.witness(e), String(e))
	var picked: Array[StringName] = [&"c_q_dates", &"c_q_three_weeks", &"c_q_light_quendel", &"c_q_light_wernstein", &"c_q_light_hagedorn"]
	assert_eq((tree.get_first_node_in_group(&"journal") as JournalManager).try_link(picked), &"i_light_before")
	assert_eq(quests.current_step(MAIN), &"h4")


## Fenner gives the fourth row; the stump and the bramble cleared – the section opens.
func _row4() -> void:
	GameState.set_flag(&"linden_row4_granted", true)
	var inv := player.inventory
	for id: String in ["obs_l_stump_13", "obs_l_bramble_13"]:
		assert_true(expansion.can_clear(id, inv), "%s can be cleared (%s)" % [id, expansion.tool_block_reason(id, inv, -1)])
		assert_true(expansion.clear(id, inv), id)
	assert_true(expansion.is_unlocked(&"linden_row4"), "§2.6: row 4 open")
	var free := 0
	for id: String in ROW4:
		if graveyard.get_grave(id).state == GraveRecord.State.EMPTY:
			free += 1
	assert_eq(free, 4, "four plots in row 4")


func _take_large(id: StringName) -> void:
	assert_true(hill.pin_large(id), "%s pinned" % id)
	assert_true(hill.accept(id), "%s taken (%s)" % [id, hill.accept_reason(id)])


## The post for the dead of `day` read at the grave of its dead (the call the grave's prompt „Brief am Grab vorlesen"
## makes; the prompt itself is checked where it is the grave's first).
func _read_post(day: int) -> void:
	var post := letters.post_today(day)
	assert_false(post.is_empty(), "§2.4.3: Osric's post for the dead on day %d" % day)
	for uid: String in post:
		var grave := ""
		for g: GraveRecord in graveyard.graves():
			var rec := corpses.get_record(g.corpse_id) if g.corpse_id != "" and corpses.has_method(&"get_record") else null
			if rec != null and rec.story_id == letters.letter(uid).story_id:
				grave = g.id
		assert_ne(grave, "", "the grave of %s" % letters.letter(uid).id)
		var plot := _plot(grave)
		if plot != null and plot.get_interaction_prompt(player) == GravePlot.PROMPT_READ_LETTER % 10:
			plot.interact(player)
			await _settle()
		elif plot != null and plot.grave_actions(player).has(GravePlot.P9_READ):
			# W3 QA-Fix QA9-04: the grave's choice offers it beside the care of the bag.
			plot.interact(player)
			plot.request_action(GravePlot.P9_READ)
			await _settle()
		else:
			assert_true(letters.decide(uid, &"read_grave", {"inventory": player.inventory, "grave_id": grave}), "read at %s" % grave)
		assert_eq(letters.state(uid), &"read_grave", "%s read at the grave" % letters.letter(uid).id)


## The morning's delivery into a free plot of row 4: the pockets step (the letter), buried.
func _deliver(day: int) -> CorpseRecord:
	await _run_to(day, 7 * 60)
	var r := corpses.try_daily_delivery(day)
	if r == null:
		await _run_to(day, 8 * 60)
		for rec: CorpseRecord in corpses.records():
			if rec.location != CorpseRecord.LOCATION_BURIED and int(rec.arrival_total_minutes / 1440.0) + 1 == day:
				r = rec
	if r == null:
		return null
	care.exam_step(r.id, &"pockets")
	for id: String in ROW4:
		if graveyard.get_grave(id).state == GraveRecord.State.EMPTY:
			graveyard.dig(id)
			if graveyard.bury(id, r.id):
				break
	return r


func _uid_of(r: CorpseRecord) -> String:
	for uid: String in letters.uids():
		if letters.corpse_of(uid) == r.id and letters.kind_of(uid) == LetterData.KIND_POCKET:
			return uid
	return ""


# --- helpers -------------------------------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	quests = world.get_node("Systems/Quests") as Quests
	who = world.get_node("Systems/WhoKnows") as WhoKnows
	letters = world.get_node("Systems/Letters") as Letters
	stranger = world.get_node("Systems/Stranger") as Stranger
	hill = world.get_node("Systems/HillRequests") as HillRequests
	corpses = world.corpse_manager
	graveyard = world.graveyard
	care = tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	orders = world.get_node("Systems/Orders") as Orders
	rel = world.get_node("Systems/Relationships") as Relationships
	TimeManager.running = false


## The first node of `script_class` in the world (the hut's desk, the stove).
func _entity(script_class: Variant) -> Node:
	for n: Node in world.find_children("*", "", true, false):
		if is_instance_of(n, script_class):
			return n
	return null


func _plot(grave_id: String) -> GravePlot:
	for n: Node in tree.get_nodes_in_group(&"grave_plot"):
		if (n as GravePlot).grave_id == grave_id:
			return n as GravePlot
	return null


func _stand_at(p: Vector3) -> void:
	player.global_position = p
	for i: int in 2:
		await tree.physics_frame


## The real clock up to day / minute (≤ 20 minutes a step).
func _run_to(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		TimeManager.advance(mini(20, target - TimeManager.total_minutes()))
		await tree.process_frame
	UIState.clear()


func _settle() -> void:
	for i: int in 3:
		await tree.process_frame
	UIState.clear()


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _log(text: String) -> void:
	print("[P9 loop] day %d %02d:%02d – %s" % [TimeManager.day, TimeManager.minute_of_day / 60, TimeManager.minute_of_day % 60, text])


## Save → load → identical collect_state(); rebinds the new world.
func _round_trip(moment: String) -> void:
	UIState.clear()
	for i: int in 8:
		await tree.physics_frame
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	await wait_frames(1)
	var after := SaveManager.collect_state()
	var diffs: PackedStringArray = []
	_state_diff(before, after, "", diffs)
	assert_eq(diffs, PackedStringArray(), moment + ": collect_state identical after save → load")
	_log("round trip: " + moment)


func _state_diff(a: Variant, b: Variant, path: String, out: PackedStringArray) -> void:
	if a is Dictionary and b is Dictionary:
		for key: Variant in a:
			if not (b as Dictionary).has(key):
				out.append("-%s.%s" % [path, key])
			else:
				_state_diff(a[key], b[key], "%s.%s" % [path, key], out)
		for key: Variant in b:
			if not (a as Dictionary).has(key):
				out.append("+%s.%s" % [path, key])
		return
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("#%s" % path)
			return
		for i: int in (a as Array).size():
			_state_diff(a[i], b[i], "%s[%d]" % [path, i], out)
		return
	if a is Vector3 and b is Vector3:
		if (a as Vector3).distance_to(b) > 1e-5:
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if (a is float or b is float) and (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 1e-9 * maxf(1.0, absf(float(a))):
			out.append("~%s" % path)
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("~%s (%s → %s)" % [path, a, b])


func _on_chapter(chapter_id: StringName) -> void:
	chapters.append(chapter_id)
