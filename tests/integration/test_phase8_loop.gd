extends TestCase
## W-Welt (docs/PHASE8_DESIGN.md §10 test_phase8_loop): the Phase-8 chain on the real world through SaveManager,
## from the Phase-7 end state (v6 fixture slot_p7_day53_neighbor) to the chapter „Wer heraufkommt" – the systems
## as a player uses them: the real clock (TimeManager.advance, nothing teleported), the real DialogueRunner for
## Osric, the dialogue actions of the villagers' answers (step_accept, apprentice_hire, wish_offer / wish_accept,
## alms, dance, meet:<place>), the real portals, doors and rooms, the shops, the graves' care actions (plant,
## water, candle, close, coins), the care spots, the archive cabinet, the watch spot, the journal link. Where the
## contract has a panel (the chalk board, the shop) the system API the panel calls.
## Debug help only for time (the clock is advanced) and relationships (none needed with this fixture); goods the
## player buys come from the shops with his own coins.
## p8_open → Osric p8_intro → Martha Kehr kneels at l_04 (wish) → Sieber (wish) → the village: Fenner (row 3,
## story 1), Rosine (story 1, Jakob hired), Esch's rake and can, Theres (story 1) → Liesel's wish → row 3
## cleared → the Kathreintanz → the chalk board, Jakob's first day: rake and water taught → delivery into row 3 →
## Veit's alms, Hanne at the gate → Fenner 2 and Esch 1 taken → Fenner 2 at l_12 (the parish key) → Quast at
## Ott's (watched) → coins on the stone → Fenner 3 in the inn → Lenz at Ott's (watched) → the robber digs → the
## Lichtgang → D2 into row 3 → the parish archive (Lorenz' second notebook) → i_underlined → the wishes judged at
## the next visits → chapter who_comes_up. collect_state() identical after save_game / load_game at 7 moments: a
## visitor kneels; Jakob in the middle of a place; coins on the stone; the Lichtgang 17:20; the robber digs (02:30);
## the Kathreintanz 20:00 in the inn; after the chapter.

const TIMEOUT := 1800.0
const SLOT := 94
const FIXTURE := "slot_p7_day53_neighbor"
const MILESTONE_STAND := Vector2(9.0, 23.0)
const BIER_STAND := Vector2(1.75, 9.2)
## Graveyard Npc of a kin (households: their own figure; villagers: their graveyard figure).
const KIN_NPC := {&"kin_kehr": "npc_kin_kehr", &"kin_ott": "npc_kin_ott", &"kin_brandt": "npc_kin_brandt",
		&"kin_sieber": "npc_kin_sieber", &"kin_washer": "npc_washer_g", &"kin_smith": "npc_smith_g", &"kin_grocer": "npc_grocer_g"}
## Wish kinds the loop fulfils with the player's own care actions.
const KINDS: Array[StringName] = [&"flowers", &"tend", &"candle", &"line"]
const ROW3: PackedStringArray = ["l_09", "l_10", "l_11", "l_12"]

var saves_dir := TestCase.user_dir("test_saves_p8_loop")
var world: WorldRoot
var player: Player
var manager: CorpseManager
var orders: Orders
var rel: Relationships
var visitors: Visitors
var care: GraveCare
var app: Apprentice
var friendship: Friendship
var life: NpcLife
var chapters: Array = []
var trips: int = 0
## Visits already talked to; the first tip stays on the stone for the round trip, then is taken.
var served: Dictionary = {}
## Care actions refused once (logged once).
var refused: Dictionary = {}
var stone_kept: bool = false
var stone_round_trip: bool = false
var stone_taken: bool = false
## The grave with flowers set on day 54 for showing Jakob how to water.
var _teach_flowers: String = ""


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	served.clear()
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase8_loop_to_who_comes_up_with_round_trips() -> void:
	assert_eq(Phase8Fixtures.install_save_v6(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world == null:
		return
	# --- B1 (day 53): p8_open at once, Osric p8_intro, the first visitor -----------------------------------
	assert_true(GameState.flag_on(&"p8_open"), "§1.2: p8_open right after loading the Phase-7 end state")
	assert_eq(int(GameState.get_flag(&"p8_open_day", 0)), 53, "p8_open_day")
	_osric(&"p8_intro")
	assert_true(GameState.flag_on(&"p8_intro"), "Osric told who comes up")
	_log("start: coins %d, %s" % [player.inventory.count(&"coin"), _inv()])
	# Martha Kehr walks up the coach road to l_04 / l_08, kneels, lays her bouquet.
	var kehr := await _until_phase(&"kin_kehr", [&"mourning"])
	assert_false(kehr.is_empty(), "§2.2: Martha Kehr visits on day 53")
	var kehr_npc := world.get_node_by_layout_id(KIN_NPC[&"kin_kehr"]) as Npc
	assert_not_null(kehr_npc, "npc_kin_kehr in the world")
	if kehr_npc != null and not kehr.is_empty():
		kehr_npc.refresh()
		assert_true(kehr_npc.is_present(), "§2.2: Martha Kehr on the graveyard")
		var grave := world.get_node_by_layout_id(str(visitors.visit_state(str(kehr.visit_id)).grave_id)) as Node3D
		assert_true(_flat(kehr_npc.global_position, grave.global_position) < 2.6, "at the grave, not at the gate (%.2f m)" % _flat(kehr_npc.global_position, grave.global_position))
		_log("Martha Kehr: %s, anim %s" % [visitors.visit_state(str(kehr.visit_id)), kehr_npc.current_animation()])
	await _round_trip("a visitor kneels")
	await _pass(53, 13 * 60 + 30)
	# --- the village: Fenner (row 3, story 1), Rosine (story 1, Jakob), Esch's tools, Theres (story 1) ------
	await _travel_to_village()
	await _enter(&"door_office")
	_say(&"mayor", ["set_flag:linden_row3_granted", "talked:mayor", "step_accept:mayor"])
	assert_true(GameState.flag_on(&"linden_row3_granted"), "§2.8: the third row granted")
	assert_true(orders.turn_in(&"of_fenner_1", player.inventory), "Fenner 1: juniper and linen (%s)" % orders.state(&"of_fenner_1"))
	assert_eq(friendship.step_done(&"mayor"), 1, "Fenner step 1")
	await _exit_room(&"office")
	await _enter(&"door_inn")
	_say(&"innkeeper", ["step_accept:innkeeper", "apprentice_hire"])
	assert_true(app.is_hired(), "§2.5: Jakob is the apprentice from tomorrow")
	assert_eq(orders.state(&"of_rosine_1"), &"accepted", "Rosine 1 „Der Junge\" taken")
	await _exit_room(&"inn")
	var shops := world.get_node("Systems/VillageShops") as VillageShops
	await _buy(shops, &"smith", &"apprentice_rake", 1)
	await _buy(shops, &"smith", &"watering_can", 1)
	_say(&"grocer", ["step_accept:grocer"])
	assert_eq(orders.state(&"of_mangold_1"), &"accepted", "Theres 1 „Mutters Grab\" taken (%s)" % friendship.step_block_reason(&"grocer"))
	await _buy(shops, &"grocer", &"flower_seedlings", 4)
	await _buy(shops, &"grocer", &"grave_candle", 4)
	await _travel_to_graveyard()
	# Jakob's box: his tools and the wage tin.
	var box := world.get_node("Entities/apprentice_box") as ApprenticeBox
	assert_not_null(box, "§4.3: Jakob's box at the hut corner")
	# His rake now (the board starts with raking and weeding); the gravekeeper keeps the one can of the smithy.
	assert_true(player.inventory.remove_item(&"apprentice_rake", 1), "the rake for Jakob")
	box.storage.add_item(&"apprentice_rake", 1)
	assert_true(box.deposit(player.inventory, 9), "coins into the tin")
	await _pass(53, 18 * 60 + 30)
	_log("day 53 end: wishes %s, coins %d" % [_wish_list(), player.inventory.count(&"coin")])
	# --- B2 (day 54): flowers to show Jakob, row 3 cleared, the Kathreintanz -------------------------------
	await _pass(54, 8 * 60)
	_teach_flowers = _plant_free_grave()
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	for id: String in expansion.obstacle_ids(&"linden_row3"):
		assert_true(expansion.clear(id, player.inventory), "row 3: %s cleared (%s %s)" % [id, expansion.missing_cost(id, player.inventory), expansion.tool_block_reason(id, player.inventory)])
	assert_true(expansion.is_unlocked(&"linden_row3"), "§2.8: row 3 open (%s)" % expansion.block_reason(&"linden_row3"))
	await _pass(54, 19 * 60)
	await _travel_to_village()
	await _pass(54, 20 * 60)
	await _enter(&"door_inn")
	TimeManager.advance(1)
	var fest := world.get_node("Systems/Festivals") as Festivals
	assert_eq(fest.running(), &"fest_kathrein", "§2.7.1: the Kathreintanz runs")
	await _round_trip("the Kathreintanz 20:00 in the inn")
	fest = world.get_node("Systems/Festivals") as Festivals
	_say(&"innkeeper", ["dance:innkeeper"])
	assert_true(fest.danced().has(&"innkeeper"), "danced with Rosine (%s)" % fest.dance_block_reason(&"innkeeper"))
	await _exit_room(&"inn")
	await _travel_to_graveyard()
	# --- B3 (day 55): the chalk board, Jakob's first day, the delivery into row 3, Veit, Hanne --------------
	await _pass(55, 7 * 60)
	app.set_board_lines([{"task": "rake", "area": "yard"}, {"task": "weed", "area": "linden"}] as Array[Dictionary])
	await _pass(55, 540)
	await _teach(&"rake")
	await _teach(&"water")
	assert_eq([app.level(&"rake"), app.level(&"water")], [1, 1], "§2.5.4: rake and water taught")
	await _until_mid_place(55)
	await _round_trip("Jakob in the middle of a place")
	await _pass(55, 830)
	await _alms()
	await _pass(55, 945)
	await _buy(world.get_node("Systems/VillageShops") as VillageShops, &"peddler", &"grave_candle", 4)
	await _pass(55, 950)
	assert_eq(orders.state(&"of_rosine_1"), &"completed", "Rosine 1 done after Jakob's first day")
	assert_eq(orders.state(&"of_mangold_1"), &"completed", "Theres 1: the Christrosen fresh at her visit")
	# Down to Fenner (story 2) and Esch (story 1) – two friend orders at a time (§2.4).
	await _travel_to_village()
	_near_villager(&"mayor")
	_say(&"mayor", ["step_accept:mayor"])
	assert_eq(orders.state(&"of_fenner_2"), &"accepted", "Fenner 2 taken (%s)" % friendship.step_block_reason(&"mayor"))
	_near_villager(&"smith")
	_say(&"smith", ["step_accept:smith"])
	assert_eq(orders.state(&"of_esch_1"), &"accepted", "Esch 1 „Meister Gratz\" taken (%s)" % friendship.step_block_reason(&"smith"))
	await _travel_to_graveyard()
	await _pass(55, 18 * 60 + 30)
	# --- B4 (day 56): Veit at the church, Fenner 2 at l_12 (the parish key), Quast at Ott's ----------------
	await _pass(56, 7 * 60 + 30)
	await _travel_to_village()
	await _pass(56, 500)
	await _alms_in_village()
	await _buy(world.get_node("Systems/VillageShops") as VillageShops, &"grocer", &"grave_candle", 4)
	await _travel_to_graveyard()
	await _pass(56, 965)
	# W2 finding (P6): no schedule brings Fenner up to l_12 for of_fenner_2 yet – the meeting runs with his
	# graveyard figure (npc_mayor_g) as the speaker of „[Geschichte] Hier, die zwölfte Stelle."
	await _meet_at(&"npc_mayor_g", &"gv_l_12")
	assert_eq(orders.state(&"of_fenner_2"), &"completed", "Fenner 2 „Ein Platz mit Blick\"")
	assert_true(GameState.flag_on(&"archive_key"), "Fenner's parish key")
	await _pass(56, 21 * 60)
	await _travel_to_village()
	await _watch(&"watch_ott", &"c_n_quast_visit")
	# --- B5 (day 57): coins on the stone, Veit at the gate, Fenner 3 in the inn, Lenz at Ott's -------------
	await _travel_to_graveyard()
	await _pass(57, 820)
	await _alms()
	assert_true(_journal().has_clue(&"c_n_veit"), "§2.6.1: Veit after three alms")
	await _pass(57, 1050)
	await _travel_to_village()
	await _pass(57, 1100)
	await _enter(&"door_inn")
	_say(&"mayor", ["step_accept:mayor"])
	assert_eq(orders.state(&"of_fenner_3"), &"accepted", "Fenner 3 taken (%s)" % friendship.step_block_reason(&"mayor"))
	await _meet_at(&"npc_mayor", &"v_in_inn_table")
	assert_eq(orders.state(&"of_fenner_3"), &"completed", "Fenner 3 „Eine Runde von mir\"")
	assert_eq(friendship.full_stories(), 1, "Fenner's story complete")
	await _exit_room(&"inn")
	await _watch(&"watch_ott", &"c_n_lenz_visit")
	await _travel_to_graveyard()
	# --- the night: the robber digs at the fresh grave in row 3 ------------------------------------------
	var robber := world.get_node("Systems/NightRobber") as NightRobber
	if await _robber_night(robber):
		await _round_trip("the robber digs (02:30)")
	await _pass(58, 6 * 60 + 10)
	await _close_disturbed()
	# --- B6 (day 58): the Lichtgang ----------------------------------------------------------------------
	assert_true(GameState.flag_on(&"ott_dead"), "§1.6: Gerhard Ott died in the night")
	await _pass(58, 15 * 60)
	fest = world.get_node("Systems/Festivals") as Festivals
	assert_eq(fest.today(), &"fest_lights", "§2.7.2: the Lichtgang today")
	await _light_graves()
	await _pass(58, 17 * 60 + 20)
	assert_eq(fest.running(), &"fest_lights", "the procession on the hill")
	await _round_trip("the Lichtgang 17:20")
	await _pass(58, 18 * 60 + 40)
	assert_true(GameState.flag_on(&"lights_held"), "the Lichtgang held (%s)" % (world.get_node("Systems/Festivals") as Festivals).lights_result())
	# --- B7 (day 59): D2 into row 3, the parish archive with Fenner's key, the insight -------------------
	await _pass(59, 10 * 60)
	assert_true(_buried_story(&"d2_ott") != "", "§1.6: D2 Gerhard Ott buried (%s)" % _buried_story(&"d2_ott"))
	await _travel_to_village()
	await _enter(&"door_church")
	var cabinet := InteriorRoom.find(tree, &"church").get_node("Entities/ArchiveCabinet") as ArchiveCabinet
	player.global_transform = Transform3D(Basis.IDENTITY, cabinet.to_global(Vector3(0, 0, 0.82)))
	assert_eq(cabinet.access(), "key", "the archive with Fenner's key")
	assert_true(cabinet.can_interact(player), "[E] Im Archiv helfen")
	cabinet.interact(player)
	await _settle()
	assert_true(player.inventory.has(&"lorenz_ledger_2"), "Lorenz' second notebook")
	assert_true(_journal().has_clue(&"c_n_kladde"), "the clue c_n_kladde")
	await _exit_room(&"church")
	await _buy(world.get_node("Systems/VillageShops") as VillageShops, &"grocer", &"grave_candle", 4)
	var linked: Array[StringName] = [&"c_n_veit", &"c_n_kladde", &"c_n_quast_visit", &"c_n_lenz_visit"]
	assert_eq(_journal().try_link(linked), &"i_underlined", "§1.6: „Der unterstrichene Name\"")
	await _travel_to_graveyard()
	# --- B8…: the visits come back, the wishes are judged ------------------------------------------------
	for day: int in range(59, 66):
		if not chapters.is_empty():
			break
		await _pass(day, 20 * 60)
		_log("day %d: %s steps %d full %d wishes %s" % [day, life.goal_progress(), friendship.steps_total(), friendship.full_stories(), _wish_list()])
	assert_eq(chapters, [&"who_comes_up"], "§1.5: chapter „Wer heraufkommt\" (%s)" % life.goal_progress())
	assert_true(GameState.flag_on(&"who_comes_up_complete"))
	await _round_trip("after the chapter")


# --- the day ------------------------------------------------------------------------------------------

## The clock forward to (day, minute) in steps of ≤ 20 minutes (5 while visitors are up); on the graveyard the
## gravekeeper serves: talks to a waiting visitor (tip, wish), cares for the wishes, buries a delivery.
func _pass(day: int, minute: int) -> void:
	var target := (day - 1) * 1440 + minute
	while TimeManager.total_minutes() < target:
		var step := 5 if not visitors.active_visits().is_empty() else 20
		TimeManager.advance(mini(step, target - TimeManager.total_minutes()))
		await _serve()
	UIState.clear()


func _serve() -> void:
	if player.region_id != &"graveyard" or player.interior_id != &"" or HutPortal.is_travelling(player):
		return
	await tree.process_frame
	for v: Dictionary in visitors.active_visits():
		if StringName(str(v.phase)) == &"waiting" and not served.has(str(v.visit_id)):
			served[str(v.visit_id)] = true
			await _talk(v)
	# The gravekeeper sleeps 22:00–06:00 (and stays where he is).
	var m := TimeManager.minute_of_day
	if m % 60 < 20 and m >= 360 and m < 1320:
		await _keep_wishes()
		await _bury_waiting()


## Minute by minute until the visit of `kin` is in one of `phases`; {} = no visit today / over.
func _until_phase(kin: StringName, phases: Array) -> Dictionary:
	for i: int in 900:
		var v := visitors.visit_of(kin)
		if v.is_empty():
			return {}
		var phase := StringName(str(v.get("phase", "")))
		if phase in phases:
			return v
		if phase == &"gone" or bool(v.get("ended", false)):
			return {}
		TimeManager.advance(1)
		if i % 30 == 0:
			await tree.process_frame
	return {}


## The talk with a waiting visitor: the tip in the hand, a wish the loop can fulfil.
func _talk(v: Dictionary) -> void:
	var kin := StringName(str(v.kin_id))
	var npc := world.get_node_by_layout_id(KIN_NPC.get(kin, "")) as Npc
	if npc == null:
		_log("no figure for %s" % kin)
		return
	npc.refresh()
	player.global_position = npc.global_position + Vector3(1.2, 0, 0)
	var context := {"inventory": player.inventory, "speaker": npc, "player": player}
	if visitors.tip_of(str(v.visit_id)) > 0 and not stone_kept:
		# The first tip stays on the stone (the round trip „coins on the stone").
		stone_kept = true
	elif visitors.tip_of(str(v.visit_id)) > 0:
		DialogueActions.run_all(["tip_hand"] as Array[String], context)
	DialogueActions.run_all(["wish_offer"] as Array[String], context)
	var offer: Dictionary = context.get(DialogueActions.CONTEXT_WISH, {})
	if not offer.is_empty() and StringName(str(offer.kind)) in KINDS:
		DialogueActions.run_all(["wish_accept"] as Array[String], context)
		_log("%s wishes %s at %s" % [kin, offer.kind, offer.grave_id])
	elif not offer.is_empty():
		_log("%s wish %s left" % [kin, offer.kind])
	UIState.clear()
	await _keep_wishes()


## The player's care for the accepted wishes and Theres' Christrosen: flowers set and watered, the care spots
## tended, a candle in the evening; Meister Gratz' grave clean for Esch; coins on a stone taken (after the round
## trip).
func _keep_wishes() -> void:
	var targets: Array = []
	for w: Dictionary in visitors.open_wishes():
		if str(w.state) == "accepted":
			targets.append([StringName(str(w.kind)), str(w.grave_id)])
	if orders.state(&"of_mangold_1") == &"accepted":
		targets.append([&"flowers", "old_08"])
	if orders.state(&"of_esch_1") == &"accepted":
		targets.append([&"tend", "old_01"])
	for t: Array in targets:
		var plot := world.get_node_by_layout_id(t[1]) as GravePlot
		if plot == null:
			continue
		match t[0]:
			&"flowers":
				var state := care.flowers_state(t[1])
				if state == &"":
					await _care(plot, GravePlot.CARE_PLANT)
				elif state == GraveCare.FLOWERS_WILTED or (state == GraveCare.FLOWERS_FRESH and care.fresh_minutes_left(t[1]) <= 720):
					await _care(plot, GravePlot.CARE_WATER)
			&"tend":
				for spot: DirtSpot in _spots_of(t[1]):
					await _tend(spot)
			&"candle":
				if TimeManager.minute_of_day >= 1080 and not care.candle_lit(t[1]):
					await _care(plot, GravePlot.CARE_CANDLE)
	if stone_taken or not stone_kept:
		return
	for g: String in visitors.stones():
		if not stone_round_trip:
			stone_round_trip = true
			await _round_trip("coins on the stone")
		var tip := world.get_node_by_layout_id(g).get_node_or_null("TipStone") as TipStone
		assert_not_null(tip, "§4.3: the TipStone at " + g)
		var coins := player.inventory.count(&"coin")
		if tip != null:
			_stand_at(world.get_node_by_layout_id(g) as Node3D)
			assert_true(tip.can_interact(player), "[E] coins on the stone (%s)" % tip.get_interaction_prompt(player))
			tip.interact(player)
		assert_true(player.inventory.count(&"coin") > coins, "§2.2.6: the coins taken from " + g)
		stone_taken = true


## The grave's care action `action` (the [E] choice of the plot's care menu; instant timed action).
func _care(plot: GravePlot, action: StringName) -> void:
	_stand_at(plot)
	if action == GravePlot.CARE_WATER and care.can_fill() <= 0:
		await _refill()
		_stand_at(plot)
	var state := plot._care_state(action, player)
	if state != 1:
		var key := "%s/%s" % [plot.grave_id, action]
		if not refused.has(key):
			refused[key] = true
			_log("%s: %s not possible (%s)" % [plot.grave_id, action, plot.care_prompt(action, player)])
		return
	plot._start_care(action, player)
	await _settle()


## The can at the rain barrel by the hut.
func _refill() -> void:
	var barrel := world.get_node_or_null("Entities/rain_barrel") as Node3D
	assert_not_null(barrel, "§4.3: the rain barrel")
	if barrel == null:
		return
	player.global_position = barrel.global_position + barrel.global_basis.z * 0.9
	assert_true(barrel.call(&"can_interact", player), "[E] at the rain barrel (%s)" % barrel.call(&"get_interaction_prompt", player))
	barrel.call(&"interact", player)
	await _settle()


func _stand_at(plot: Node3D) -> void:
	var p := plot.global_position + Vector3(0, 0, 1.6)
	player.global_position = Vector3(p.x, world.ground_height(Vector2(p.x, p.z)), p.z)


func _spots_of(grave_id: String) -> Array[DirtSpot]:
	var out: Array[DirtSpot] = []
	for n: Node in tree.get_nodes_in_group(&"dirt_spot"):
		if n is DirtSpot and (n as DirtSpot).grave_id == grave_id:
			out.append(n)
	return out


func _tend(spot: DirtSpot) -> void:
	var clean := tree.get_first_node_in_group(&"cleanliness") as CleanlinessManager
	if clean.level(spot.spot_id) <= 0:
		return
	player.global_position = spot.global_position + Vector3(0.6, 0, 0)
	if not spot.can_interact(player):
		_log("%s: cannot tend (%s)" % [spot.spot_id, spot.get_interaction_prompt(player)])
		return
	spot.interact(player)
	await _settle()


## Flowers set yesterday morning on a grave nobody visits: on Jakob's first day they want water.
func _plant_free_grave() -> String:
	for g: GraveRecord in world.graveyard.graves():
		if not g.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED] or visitors.kin_for_grave(g.id) != &"":
			continue
		var plot := world.get_node_by_layout_id(g.id) as GravePlot
		if plot == null or plot._care_state(GravePlot.CARE_PLANT, player) != 1:
			continue
		_stand_at(plot)
		plot._start_care(GravePlot.CARE_PLANT, player)
		UIState.clear()
		if care.flowers_state(g.id) == GraveCare.FLOWERS_FRESH:
			return g.id
	return ""


## Jakob watches (the dialogue action apprentice_teach), the gravekeeper shows it at a place near him.
func _teach(task: StringName) -> void:
	assert_eq(app.teach_block_reason(task, player), "", "teach %s" % task)
	var spot: Node3D = null
	if task == &"water":
		spot = world.get_node_by_layout_id(_teach_flowers) as Node3D if _teach_flowers != "" else null
	else:
		var clean := tree.get_first_node_in_group(&"cleanliness") as CleanlinessManager
		var best := 1e9
		for n: Node in tree.get_nodes_in_group(&"dirt_spot"):
			var d := n as DirtSpot
			if d != null and d.kind == &"leaves" and clean.level(d.spot_id) > 0:
				var dist := _flat(d.global_position, app.position_now())
				if dist < best:
					best = dist
					spot = d
	assert_not_null(spot, "a place to show %s" % task)
	if spot == null:
		return
	if spot is GravePlot:
		_stand_at(spot)
	else:
		player.global_position = spot.global_position + Vector3(0.6, 0, 0)
	_say_graveyard(&"npc_apprentice", ["apprentice_teach:" + String(task)])
	assert_eq(app.teaching(), task, "Jakob watches")
	for i: int in 30:
		if _flat(app.position_now(), player.global_position) <= 2.5:
			break
		TimeManager.advance(1)
		await tree.process_frame
	_log("Jakob %.2f m from the gravekeeper (%s)" % [_flat(app.position_now(), player.global_position), task])
	if spot is DirtSpot:
		await _tend(spot as DirtSpot)
	else:
		await _care(spot as GravePlot, GravePlot.CARE_WATER)
	assert_eq(app.level(task), 1, "%s Angelernt" % task)


## Minute by minute until a place of Jakob's plan is running (his tool in the hand).
func _until_mid_place(day: int) -> void:
	for i: int in 300:
		var now := TimeManager.minute_of_day
		for e: Dictionary in app.today_plan():
			if StringName(str(e.task)) in Apprentice.TASKS and int(e.start) < now and int(e.end) > now + 2:
				var jakob := world.get_node("Entities/npc_apprentice") as Npc
				jakob.refresh()
				assert_true(jakob.is_present(), "Jakob on the graveyard")
				_log("Jakob at %s (%s) at %02d:%02d, anim %s" % [e.spot_id, e.task, now / 60, now % 60, jakob.current_animation()])
				return
		TimeManager.advance(1)
		if i % 20 == 0:
			await tree.process_frame
	assert_true(false, "Jakob works a place on day %d" % day)


## A corpse on the bier goes into the next free grave of row 3 (dig, bury, a wooden cross).
func _bury_waiting() -> void:
	for c: Dictionary in manager.save_state().get("corpses", []):
		if StringName(c.get("location", &"")) != CorpseRecord.LOCATION_DROPOFF:
			continue
		var id := String(c.get("id"))
		var grave := ""
		for g: String in ROW3:
			if world.graveyard.get_grave(g) != null and world.graveyard.get_grave(g).state == GraveRecord.State.EMPTY:
				grave = g
				break
		assert_ne(grave, "", "a free grave in row 3 for " + id)
		if grave == "":
			return
		player.global_position = Vector3(BIER_STAND.x, world.ground_height(BIER_STAND), BIER_STAND.y)
		manager.get_corpse_node(id).interact(player)
		assert_eq(player.carried_id, id, "carried from the bier")
		await _bury(id, grave)
		_log("day %d: %s (%s) buried in %s" % [TimeManager.day, id, manager.get_record(id).story_id, grave])


func _bury(corpse_id: String, grave_id: String) -> void:
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	var stand := Vector3(plot.global_position.x, plot.global_position.y, plot.global_position.z + 1.6)
	manager.put_down(corpse_id, CorpseRecord.LOCATION_GROUND, Transform3D(Basis.IDENTITY, stand + Vector3(0.8, 0, 0)))
	player.global_position = stand
	plot.interact(player)
	assert_eq(world.graveyard.get_grave(grave_id).state, GraveRecord.State.DUG, grave_id + " dug")
	manager.get_corpse_node(corpse_id).interact(player)
	plot.interact(player)
	assert_eq(world.graveyard.get_grave(grave_id).state, GraveRecord.State.FILLED, grave_id + " filled")
	if player.inventory.has(&"wooden_cross"):
		plot.request_marker(&"wooden_cross")
	UIState.clear()
	await tree.physics_frame


## Veit at the graveyard gate (odd days 13:40–16:00): alms through the dialogue action.
func _alms() -> void:
	var wanderers := world.get_node("Systems/Wanderers") as Wanderers
	var before := wanderers.alms_count()
	var veit := world.get_node_by_layout_id("npc_beggar_g") as Npc
	assert_true(wanderers.present(&"beggar"), "Veit is there (day %d %02d:%02d, %s)" % [TimeManager.day, TimeManager.minute_of_day / 60, TimeManager.minute_of_day % 60, wanderers.place(&"beggar", TimeManager.day, TimeManager.minute_of_day)])
	if veit != null:
		veit.refresh()
		player.global_position = veit.global_position + Vector3(1.0, 0, 0)
	DialogueActions.run_all(["alms"] as Array[String], {"inventory": player.inventory, "speaker": veit, "player": player})
	assert_eq(wanderers.alms_count(), before + 1, "alms for Veit (%s)" % wanderers.alms_block_reason(player.inventory))


## Even days: Veit on the church step in the morning (the gravekeeper is in the village).
func _alms_in_village() -> void:
	var wanderers := world.get_node("Systems/Wanderers") as Wanderers
	var veit := world.get_node("Regions/Village/Entities/npc_beggar") as Npc
	var before := wanderers.alms_count()
	assert_eq(wanderers.place(&"beggar", TimeManager.day, TimeManager.minute_of_day), Wanderers.PLACE_CHURCH, "Veit on the church step")
	if veit != null:
		veit.refresh()
		assert_true(veit.is_present(), "Veit visible at the church")
		player.global_position = veit.global_position + Vector3(1.0, 0, 0)
	DialogueActions.run_all(["alms"] as Array[String], {"inventory": player.inventory, "speaker": veit, "player": player})
	assert_eq(wanderers.alms_count(), before + 1, "alms for Veit at the church (%s)" % wanderers.alms_block_reason(player.inventory))


## A meeting of a meet order with the Npc `npc_name` at `place` (the dialogue action meet:<place>).
func _meet_at(npc_name: StringName, place: StringName) -> void:
	var npc := world.find_child(String(npc_name), true, false) as Npc
	assert_not_null(npc, String(npc_name))
	if npc == null:
		return
	npc.refresh()
	var wp := _waypoint(place)
	_log("%s present %s, %.2f m from %s" % [npc_name, npc.is_present(), _flat(npc.global_position, wp) if wp != Vector3.INF else -1.0, place])
	player.global_position = (npc.global_position if npc.is_present() else wp) + Vector3(1.0, 0, 0)
	DialogueActions.run_all(["meet:" + String(place)] as Array[String], {"inventory": player.inventory, "speaker": npc, "player": player})
	UIState.clear()


func _waypoint(id: StringName) -> Vector3:
	var n := world.find_child(String(id), true, false) as Node3D
	return n.global_position if n != null else Vector3.INF


## The night in the village: at the watch spot until the visitor leaves the sick house – observed (≤ 12 m,
## minute by minute, nothing skipped).
func _watch(spot_id: StringName, clue: StringName) -> void:
	var paths := world.get_node("Systems/NightPaths") as NightPaths
	var spot: WatchSpot = null
	for n: Node in world.find_children("*", "WatchSpot", true, false):
		if (n as WatchSpot).spot_id == spot_id:
			spot = n
	assert_not_null(spot, "§4.6 D2: the watch spot " + String(spot_id))
	if spot == null:
		return
	var path_id := &"np_ott" if spot_id == &"watch_ott" else &"np_kehr"
	var visit := paths.next_visit(path_id, TimeManager.day, TimeManager.minute_of_day)
	assert_false(visit.is_empty(), "a night visit at %s" % path_id)
	if visit.is_empty():
		return
	var enter := int(visit.enter)
	while TimeManager.total_minutes() < enter - 30:
		TimeManager.advance(mini(20, enter - 30 - TimeManager.total_minutes()))
	player.global_position = spot.global_position
	assert_true(spot.can_interact(player), "[E] Im Schatten warten (%s)" % spot.get_interaction_prompt(player))
	spot.interact(player)
	await _settle()
	var visitor := world.get_node("Regions/Village/Entities/npc_" + String(visit.npc_id)) as Npc
	var seen := false
	while TimeManager.total_minutes() < int(visit.leave):
		TimeManager.advance(1)
		if visitor != null and TimeManager.total_minutes() > enter - 15:
			visitor.refresh()
			seen = seen or (visitor.is_present() and _flat(visitor.global_position, _waypoint(&"v_ott_door")) < 3.0)
	await tree.process_frame
	assert_true(seen, "§1.6: %s seen at the Otts' door" % visit.npc_id)
	assert_true(paths.observed(clue), "§1.6: %s observed (%.2f m from the door)" % [clue, _flat(player.global_position, _waypoint(&"v_ott_door"))])
	assert_true(_journal().has_clue(clue), "the clue " + String(clue))


## The night after day 57: 02:30 he digs at the fresh grave in row 3 (the gravekeeper at the gate, far away).
func _robber_night(robber: NightRobber) -> bool:
	player.global_position = Vector3(1.2, world.ground_height(Vector2(1.2, 8.3)), 8.3)
	await _pass(58, 60)
	var target := robber.tonight_target(57)
	_log("night 57: robber target %s" % target)
	assert_ne(target, "", "§2.6.3: the robber comes for a fresh grave")
	if target == "":
		return false
	await _pass(58, 150)
	assert_eq(robber.phase(), &"digging", "§2.6.3: he digs at " + target)
	var npc := world.get_node_by_layout_id("npc_robber") as Npc
	npc.refresh()
	assert_true(npc.is_present(), "Lambert Grell visible")
	var plot := world.get_node_by_layout_id(target) as Node3D
	assert_true(_flat(npc.global_position, plot.global_position) < 3.0, "at the grave (%.2f m)" % _flat(npc.global_position, plot.global_position))
	return true


func _close_disturbed() -> void:
	for g: GraveRecord in world.graveyard.graves():
		if care.is_disturbed(g.id):
			await _care(world.get_node_by_layout_id(g.id) as GravePlot, GravePlot.CARE_CLOSE)
			assert_false(care.is_disturbed(g.id), g.id + " closed again")


## Candles (Osric's twelve, Theres' and Hanne's) on the graves no family lights.
func _light_graves() -> void:
	var fest := world.get_node("Systems/Festivals") as Festivals
	var family := {}
	for e: Dictionary in fest.procession_plan():
		for gid: String in e.graves:
			family[gid] = true
	for g: GraveRecord in world.graveyard.graves():
		if player.inventory.count(&"grave_candle") <= 0:
			break
		if (g.state == GraveRecord.State.FILLED or g.state == GraveRecord.State.MARKED) and not family.has(g.id) and not care.candle_lit(g.id):
			await _care(world.get_node_by_layout_id(g.id) as GravePlot, GravePlot.CARE_CANDLE)
	_log("lights %s" % fest.lights_count())


func _buried_story(story: StringName) -> String:
	for g: GraveRecord in world.graveyard.graves():
		var r := manager.get_record(g.corpse_id) if g.corpse_id != "" else null
		if r != null and r.story_id == story:
			return g.id
	return ""


# --- helpers ------------------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	manager = world.corpse_manager
	orders = world.get_node("Systems/Orders") as Orders
	rel = world.get_node("Systems/Relationships") as Relationships
	visitors = world.get_node("Systems/Visitors") as Visitors
	care = world.get_node("Systems/GraveCare") as GraveCare
	app = world.get_node("Systems/Apprentice") as Apprentice
	friendship = world.get_node("Systems/Friendship") as Friendship
	life = world.get_node("Systems/NpcLife") as NpcLife
	TimeManager.running = false


func _journal() -> JournalManager:
	return tree.get_first_node_in_group(&"journal") as JournalManager


func _osric(node: StringName) -> void:
	var r := DialogueRunner.new()
	var speaker := world.get_node_by_layout_id("npc_carter")
	r.start(Database.dialogue(&"carter") as DialogueData, {"inventory": player.inventory, "speaker": speaker})
	r._enter(node)


func _say(npc_id: StringName, actions: Array) -> void:
	var speaker := world.get_node("Regions/Village/Entities/npc_" + String(npc_id))
	var typed: Array[String] = []
	typed.assign(actions)
	DialogueActions.run_all(typed, {"inventory": player.inventory, "speaker": speaker, "player": player})
	UIState.clear()


## The gravekeeper walks up to the villager where his schedule has him now (the talk needs him there).
func _near_villager(npc_id: StringName) -> void:
	var npc := world.get_node("Regions/Village/Entities/npc_" + String(npc_id)) as Npc
	npc.refresh()
	assert_true(npc.is_present(), "%s is about (%02d:%02d)" % [npc_id, TimeManager.minute_of_day / 60, TimeManager.minute_of_day % 60])
	player.global_position = npc.global_position + Vector3(1.0, 0, 0)


func _say_graveyard(npc_name: StringName, actions: Array) -> void:
	var speaker := world.get_node("Entities/" + String(npc_name))
	var typed: Array[String] = []
	typed.assign(actions)
	DialogueActions.run_all(typed, {"inventory": player.inventory, "speaker": speaker, "player": player})
	UIState.clear()


## A purchase with the player's own coins (the shop panel's call).
func _buy(shops: VillageShops, shop: StringName, item: StringName, n: int) -> void:
	var reason := shops.buy_block_reason(shop, item, n, player.inventory)
	if reason != "":
		_sell_goods(shops, shop)
		reason = shops.buy_block_reason(shop, item, n, player.inventory)
	assert_eq(reason, "", "buy %d %s at %s" % [n, item, shop])
	if reason == "":
		assert_true(shops.buy(shop, item, n, player.inventory), "bought %s" % item)
	await tree.process_frame


## Goods the shop wants, sold for coins (the honey cakes, berries, ore …).
func _sell_goods(shops: VillageShops, shop: StringName) -> void:
	for w: Dictionary in shops.wants(shop):
		var item := StringName(str(w.get("item", w.get("id", ""))))
		var have := player.inventory.count(item)
		if have > 0 and shops.sell_block_reason(shop, item, have, player.inventory) == "":
			shops.sell(shop, item, have, player.inventory)


func _travel_to_village() -> void:
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	assert_true(portal.can_interact(player), "the milestone takes the gravekeeper down (%s)" % portal.get_interaction_prompt(player))
	portal.interact(player)
	await _until_arrived()
	assert_eq(player.region_id, &"village", "in Hollerbrück")
	trips += 1


func _travel_to_graveyard() -> void:
	var road := world.get_node("Regions/Village/Entities/road_out") as RegionPortal
	player.global_transform = Transform3D(Basis.IDENTITY, road.global_position + Vector3(1.0, 0.0, 0.0))
	assert_true(road.can_interact(player), "the bridge leads back (%s)" % road.get_interaction_prompt(player))
	road.interact(player)
	await _until_arrived()
	assert_eq(player.region_id, &"graveyard", "back on the graveyard")


func _enter(door_id: StringName) -> void:
	var door := HouseDoor.find(tree, door_id)
	player.global_transform = door.exit_transform()
	assert_true(door.can_interact(player), "%s open (%s)" % [door_id, door.get_interaction_prompt(player)])
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, door.room_id, "inside " + String(door.room_id))


func _exit_room(id: StringName) -> void:
	var room := InteriorRoom.find(tree, id)
	var exit := room.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)[0] as RoomExit
	assert_true(exit.can_interact(player), "the way out of the " + String(id))
	exit.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, &"", "outside again")


func _until_arrived() -> void:
	var budget := 240
	while HutPortal.is_travelling(player) and budget > 0:
		await tree.process_frame
		budget -= 1
	await tree.physics_frame
	UIState.clear()


func _settle() -> void:
	for i: int in 3:
		await tree.process_frame
	UIState.clear()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _inv() -> String:
	var parts: PackedStringArray = []
	for s: Dictionary in player.inventory.get_slots():
		if not s.is_empty():
			parts.append("%s×%s" % [s.get("id"), s.get("amount")])
	return ", ".join(parts)


func _wish_list() -> String:
	var save: Dictionary = visitors.save_state()
	var parts: PackedStringArray = []
	for w: Dictionary in save.get("wishes", []):
		parts.append("%s:%s@%s=%s" % [w.kin_id, w.kind, w.grave_id, w.state])
	return ", ".join(parts)


func _log(text: String) -> void:
	print("[P8 loop] day %d %02d:%02d – %s" % [TimeManager.day, TimeManager.minute_of_day / 60, TimeManager.minute_of_day % 60, text])


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
