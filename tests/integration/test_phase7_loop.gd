extends TestCase
## W-Welt (docs/PHASE7_DESIGN.md §10 test_phase7_loop): the Phase-7 chain on the real world through
## SaveManager, from the Phase-6 end state (v5 fixture slot_p6_day40_reverent) to the chapter
## „Ein Name im Dorf" – entities and systems as a player uses them (instant timed actions, the real
## DialogueRunner for Osric, the real portals, doors, rooms, table, graves and the pult; where the
## contract has a panel (orders, shop, anatomist, pult, deduction, lecture) the system API the panel
## calls, like test_phase6_loop):
## village_open → Osric p7_intro → Wegstein → Fenner (Lindenacker, Brunnen) → Lindenacker cleared
## (real obstacles) → consecration paid → next day 10:30 consecrated, section open → delivery → crypt
## table → specimens in jars → grave in the Lindenacker → Quast: sell / expertise → pult: built,
## inspect, medicine, collection → deduction (wrong and right) → lecture night with the real trip →
## second corpse: a specimen returned to its grave (the ghost's mood back) → orders delivered, a stone
## for old_08 → D1 due (debug: open day 8 days ago) → burial order → clues → i_deathbook → three
## trusted (debug help: relationship values) → chapter. collect_state() identical after save_game /
## load_game at six moments: in the village with a specimen; in the inn at 23:00; a bundle in the cold
## drawer with an open window; on the consecration day 10:00 (the priest on the graveyard); an order
## accepted with a deadline; after the chapter.

const TIMEOUT := 600.0
const SLOT := 95
const FIXTURE := "slot_p6_day40_reverent"
const BIER_STAND := Vector2(1.75, 9.2)
## G8 round 2: the stair head of the turned crypt (layout buildings.sites[crypt].access).
const CRYPT_ACCESS := Vector2(-6.89, 7.36)
const MILESTONE_STAND := Vector2(9.0, 23.0)

var saves_dir := TestCase.user_dir("test_saves_p7_loop")
var world: WorldRoot
var player: Player
var manager: CorpseManager
var village: Village
var orders: Orders
var rel: Relationships
var specimens: Specimens
var chapters: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase7_loop_to_name_in_village_with_round_trips() -> void:
	assert_eq(Phase7Fixtures.install_save_v5(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world == null:
		return
	var inv := player.inventory
	# --- B1: village_open at once (v5 with roof_and_earth_complete), Osric p7_intro -----------------
	assert_true(GameState.flag_on(&"village_open"), "§1.2: village_open right after loading the Phase-6 end state")
	_osric([&"p7_intro"])
	assert_true(GameState.flag_on(&"p7_intro"), "Osric told about the Schultheiß")
	# The way down: the milestone at the end of the coach road (real portal, 30 minutes).
	var before_total := TimeManager.total_minutes()
	await _travel_to_village()
	assert_eq(TimeManager.total_minutes() - before_total, 30, "§1.3: 30 minutes down")
	assert_eq(int(GameState.stats.get(&"village_trips", 0)), 1, "village_trips")
	# Fenner in the Amtsstube (open 07:55–12:00): Lindenacker and the well.
	_set_time(TimeManager.day, maxi(TimeManager.minute_of_day, 540))
	await _enter(&"door_office")
	_say(&"mayor", ["meet:mayor", "talked:mayor"])
	for id: StringName in [&"o_fenner_linden", &"o_fenner_well"]:
		orders.offer(id)
		assert_true(orders.accept(id), "accepted " + String(id))
	assert_true(GameState.flag_on(&"linden_granted"), "§2.9: the Lindenacker granted")
	await _exit_room(&"office")
	await _round_trip("in the village, an order accepted with a deadline")
	await _travel_to_graveyard()
	inv = player.inventory
	# --- B2: clear the Lindenacker (real obstacles), pay the consecration --------------------------
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	for id: String in expansion.obstacle_ids(&"linden"):
		_stock_for_clearing(expansion, id)
		assert_true(expansion.clear(id, inv), "cleared %s (%s)" % [id, expansion.tool_block_reason(id, inv)])
	assert_false(expansion.is_unlocked(&"linden"), "§2.9: cleared, still waiting for the consecration")
	await _travel_to_village()
	_set_time(TimeManager.day, 600)
	_say(&"priest", ["meet:priest"])
	inv.add_item(&"coin", 20)
	assert_true(village.pay_consecration(inv), "the consecration paid")
	assert_eq(int(GameState.get_flag(&"linden_consecration_day", -1)), TimeManager.day + 1, "consecration tomorrow")
	await _travel_to_graveyard()
	# --- B3: the consecration day ----------------------------------------------------------------
	var cday := TimeManager.day + 1
	_set_time(cday, 600)
	var priest := world.get_node_by_layout_id("npc_priest") as Npc
	priest.refresh()
	assert_true(priest.is_present(), "§2.9: the priest stands at the Lindenacker at 10:00")
	await _round_trip("consecration day 10:00, the priest on the graveyard")
	_bind()
	priest = world.get_node_by_layout_id("npc_priest") as Npc
	_set_time(cday, 630)
	village.apply_minute(cday, 630)
	assert_true(GameState.flag_on(&"linden_consecrated"), "consecrated at 10:30")
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	assert_true(expansion.is_unlocked(&"linden"), "the Lindenacker opens")
	# --- B4: the delivery, the crypt table, specimens -----------------------------------------------
	_set_time(cday + 1, 470)
	var record := manager.try_daily_delivery(TimeManager.day)
	assert_not_null(record, "a delivery for the new places")
	if record == null:
		return
	var corpse_id := record.id
	# Quast's case first (anatomy_known), through the dialogue action of „Zeigen Sie mir, wie."
	_say(&"surgeon", ["meet:surgeon", "anatomy_case"])
	inv = player.inventory
	assert_true(GameState.flag_on(&"anatomy_known"), "§2.12: the case accepted")
	await _carry_to_crypt_table(corpse_id)
	var table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	_stock({&"prep_jar": 3, &"spirits": 3, &"prep_jar_small": 1, &"linen": 2})
	var uids: PackedStringArray = []
	for organ: StringName in [&"heart", &"liver", &"lung"]:
		var n := specimens.of_corpse(corpse_id).size()
		table.request_organ(organ, SpecimenRecord.CONTAINER_JAR)
		UIState.clear()
		assert_eq(specimens.of_corpse(corpse_id).size(), n + 1, "§2.6: %s in a jar (%s)" % [organ,
				(world.get_node("Systems/CorpseCare") as CorpseCare).organ_block_reason(corpse_id, organ, SpecimenRecord.CONTAINER_JAR, inv)])
	uids = specimens.of_corpse(corpse_id)
	assert_eq(uids.size(), 3, "three specimens (the limit)")
	table.request_pick_up()
	await _exit_room(&"crypt")
	await _bury(corpse_id, "l_01")
	# --- Quast: sell one, an expertise -------------------------------------------------------------
	await _travel_to_village()
	await _round_trip("in the village with specimens in the inventory")
	_bind()
	inv = player.inventory
	_set_time(TimeManager.day, 600)
	await _enter(&"door_surgery")
	var coins := inv.count(&"coin")
	var heart := _uid_of(uids, &"heart")
	var why_not := "%s held=%s state=%s uids=%s" % [specimens.sell_block_reason(heart, inv), inv.has_uid(heart), specimens.get_record(heart).state if specimens.get_record(heart) else &"-", inv.uids()]
	assert_true(specimens.sell(heart, inv) > 0, "§2.6.1: sold to Quast (%s, price %d, uid %s)" % [why_not, specimens.sale_price(heart), heart])
	assert_true(inv.count(&"coin") > coins, "coins")
	var lung := _uid_of(uids, &"lung")
	var exp := specimens.expertise(lung, inv)
	assert_false(exp.is_empty(), "§2.6: an expertise")
	await _exit_room(&"surgery")
	await _travel_to_graveyard()
	inv = player.inventory
	# --- the pult: built, inspect, a medicine, the collection ----------------------------------------
	var workshop := world.get_node("Systems/Workshop") as Workshop
	var site := InteriorRoom.find(tree, &"crypt").get_node("Entities/PultPlace/site_pult") as BuildSite
	await _enter_crypt()
	site.refresh()
	assert_true(site.is_active(), "§2.7: the pult site in the crypt after village_open")
	var pult := Database.station(&"pult") as StationData
	_stock(pult.build_inputs)
	inv.add_item(&"coin", pult.build_coins)
	site.interact(player)
	site.request_build()
	UIState.clear()
	assert_true(workshop.is_built(&"pult"), "the pult stands")
	var station := InteriorRoom.find(tree, &"crypt").get_node("Entities/PultPlace/station_pult") as Workbench
	station.refresh_built()
	assert_true(station.visible, "the pult visible once built")
	var liver := _uid_of(uids, &"liver")
	var card := specimens.inspect(liver)
	assert_ne(card, &"", "§2.7: inspected – a finding card")
	var bitter := Database.medicine(&"bitter_drops") as MedicineData
	_stock(bitter.inputs)
	var shelf := station.get_node("CollectionShelf") as CollectionShelf
	assert_true(shelf.place(liver, inv) or PultRules.make_medicine(bitter, liver, inv, specimens, TimeManager.total_minutes(), specimens.get_config()),
			"the liver goes to the collection or into a medicine")
	await _exit_room(&"crypt")
	# --- the deduction (wrong, then right) ---------------------------------------------------------
	var deductions := world.get_node("Systems/Deductions") as Deductions
	var cards := deductions.cards(corpse_id)
	var wrong := deductions.deduce(corpse_id, cards, &"no_such_cause")
	assert_false(bool(wrong.get("ok", false)), "§2.6.5: a wrong deduction")
	var stat_before := int(GameState.stats.get(&"deductions", 0))
	assert_eq(int(GameState.stats.get(&"deductions", 0)), stat_before, "no counter for a wrong one")
	# --- the lecture night with the real trip ------------------------------------------------------
	var lectures := world.get_node("Systems/Lectures") as Lectures
	if not lectures.invited():
		lectures.invite()
	var night := TimeManager.day
	while not LectureRules.is_lecture_night(night, 23 * 60, lectures.config if lectures.config != null else specimens.get_config()):
		night += 1
	_set_time(night, 22 * 60 + 30)
	await _travel_to_village()
	var door := HouseDoor.find(tree, &"door_surgery")
	assert_true(door.is_open_now(), "§2.6.4: the surgery opens on the lecture night (%02d:%02d)" % [TimeManager.minute_of_day / 60, TimeManager.minute_of_day % 60])
	await _enter(&"door_surgery")
	var jar_uid := ""
	_stock({&"prep_jar": 1, &"spirits": 1})
	for u: String in specimens.held():
		if specimens.get_record(u).container == SpecimenRecord.CONTAINER_JAR and inv.has_uid(u):
			jar_uid = u
	if jar_uid != "":
		var held := lectures.hold(jar_uid, inv)
		assert_false(held.is_empty(), "§2.6.4: the lecture held (%s)" % lectures.hold_block_reason(jar_uid, inv))
	await _exit_room(&"surgery")
	# The inn at 23:00 (round trip there).
	_set_time(TimeManager.day, 23 * 60)
	await _enter(&"door_inn")
	await _round_trip("in the inn at 23:00")
	_bind()
	inv = player.inventory
	await _exit_room(&"inn")
	await _travel_to_graveyard()
	inv = player.inventory
	# --- the second corpse: a specimen returned to its grave --------------------------------------
	await _clear_bier("l_03")
	var second := _next_delivery()
	assert_not_null(second, "a second delivery")
	if second == null:
		return
	await _carry_to_crypt_table(second.id)
	table = InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	_stock({&"prep_jar": 1, &"spirits": 1, &"linen": 2})
	table.request_organ(&"stomach", SpecimenRecord.CONTAINER_BUNDLE)
	UIState.clear()
	var bundle := ""
	for u: String in specimens.of_corpse(second.id):
		bundle = u
	assert_ne(bundle, "", "a bundle taken (%s, freshness %.2f)" % [(world.get_node("Systems/CorpseCare") as CorpseCare).organ_block_reason(second.id, &"stomach", SpecimenRecord.CONTAINER_BUNDLE, inv), second.freshness])
	# The bundle into the cold drawer – the round trip with an open cold window.
	var store := InteriorRoom.find(tree, &"crypt").get_node("Entities/PultPlace/station_pult/PultStore") as PultStore
	var slot: int = inv.get_slots().find_custom(func(s: Variant) -> bool: return s is Dictionary and String((s as Dictionary).get("uid", "")) == bundle)
	if slot >= 0:
		ChestTransfer.move_slot(inv, store.store(), slot)
	await _round_trip("a bundle in the cold drawer")
	_bind()
	inv = player.inventory
	store = InteriorRoom.find(tree, &"crypt").get_node("Entities/PultPlace/station_pult/PultStore") as PultStore
	_set_time(TimeManager.day, TimeManager.minute_of_day + 15)  # the cold window lasts a while
	var back: int = store.store().get_slots().find_custom(func(s: Variant) -> bool: return s is Dictionary and String((s as Dictionary).get("uid", "")) == bundle)
	if back >= 0:
		ChestTransfer.move_slot(store.store(), inv, back)
	table = InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	table.request_pick_up()
	await _exit_room(&"crypt")
	await _bury(second.id, "l_02")
	var plot := world.get_node_by_layout_id("l_02") as GravePlot
	var returned_before := specimens.get_record(bundle).state if specimens.get_record(bundle) != null else &""
	assert_true(plot.return_prompt(inv).begins_with("[E] Präparat beisetzen"), "§2.6.2: the prompt (%s)" % plot.return_prompt(inv))
	plot.interact(player)
	assert_ne(specimens.get_record(bundle).state, returned_before, "the specimen went back into the grave")
	assert_true(manager.get_record(second.id).returned.size() == 1, "record.returned")
	# --- orders delivered, a stone for old_08 ------------------------------------------------------
	var esch_value := rel.value(&"smith")
	_stock({&"workstone": 4})
	await _travel_to_village()
	_set_time(TimeManager.day, 700)
	orders.offer(&"o_esch_charcoal")
	assert_true(orders.accept(&"o_esch_charcoal"), "Esch's charcoal accepted")
	_stock({&"charcoal": 6})
	assert_true(orders.turn_in(&"o_esch_charcoal", inv), "§2.5: the charcoal delivered (%s)" % orders.state(&"o_esch_charcoal"))
	assert_true(rel.value(&"smith") > esch_value or rel.value(&"mayor") > 30, "relationships grew")
	rel.add(&"grocer", 20, "Test: Bekannt")
	orders.offer(&"o_mangold_stone")
	assert_true(orders.accept(&"o_mangold_stone"), "the stone for Dorothee Mahn accepted")
	await _travel_to_graveyard()
	inv = player.inventory
	var masonry := world.get_node("Systems/Stonemasonry") as Stonemasonry
	var design := StoneDesign.from_dict({"shape": &"stele", "ornament": &"poppy", "inscription": "Dorothee Mahn"})
	var order_data := orders.order_data(&"o_mangold_stone")
	if order_data.conditions.has("stone_shape"):
		design.shape = StringName(order_data.conditions.stone_shape)
	_stock(masonry.preview("old_08", design).get("inputs", {}))
	inv.add_item(&"coin", 30)
	var carved := masonry.carve("old_08", design, inv)
	assert_ne(carved, "", "carved (%s)" % masonry.order_block_reason("old_08", design, inv))
	var old_plot := world.get_node_by_layout_id("old_08") as GravePlot
	player.global_position = old_plot.global_position + Vector3(0.0, 0.0, 1.8)
	assert_true(old_plot.has_old_stone_to_set(), "the stone waits in the rack")
	old_plot.interact(player)
	assert_eq(world.graveyard.get_grave("old_08").state, GraveRecord.State.OLD, "§2.5: the grave stays OLD")
	assert_false(world.graveyard.get_grave("old_08").design.is_empty(), "a new stone on old_08")
	assert_true(masonry.ready_for("old_08").is_empty(), "W1 note P4: the stone left the rack")
	# --- D1, clues, insight, three trusted → the chapter -------------------------------------------
	GameState.set_flag(&"village_open_day", TimeManager.day - 8)
	await _clear_bier("l_05")
	var d1 := _next_delivery()
	assert_not_null(d1, "D1 Wiebke Hagedorn is due (8 days after village_open, consecrated)")
	if d1 != null:
		assert_eq(d1.story_id, &"d1_hagedorn", "the story corpse D1")
		assert_true(GameState.flag_on(&"hagedorn_dead"), "hagedorn_dead")
	var journal := world.get_node("Systems/Journal") if world.has_node("Systems/Journal") else tree.get_first_node_in_group(&"journal")
	for clue: StringName in [&"c_v_three_visitors", &"c_v_deathbook", &"c_v_washing"]:
		journal.call(&"add_clue", clue)
	var linked: Array[StringName] = [&"c_v_deathbook", &"c_v_washing", &"c_v_three_visitors"]
	journal.call(&"try_link", linked)
	assert_true(bool(journal.call(&"has_insight", &"i_deathbook")) or GameState.flag_on(&"insight_deathbook"), "§1.6: „Vorher eingetragen\"")
	for npc: StringName in [&"mayor", &"innkeeper", &"priest"]:
		rel.add(npc, 60, "Test: Vertraut")
	for id: StringName in [&"o_rosine_berries", &"o_esch_charcoal", &"o_quast_tincture", &"ob_wood", &"ob_stone"]:
		if orders.state(id) != &"completed":
			orders.offer(id)
			orders.accept(id)
			orders.complete(id)
	village.check_goal()
	assert_eq(chapters, [&"name_in_village"], "§1.5: chapter „Ein Name im Dorf\" (%s)" % village.goal_progress())
	assert_true(GameState.flag_on(&"name_in_village_complete"))
	await _round_trip("after the chapter")


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	manager = world.corpse_manager
	village = world.get_node("Systems/Village") as Village
	orders = world.get_node("Systems/Orders") as Orders
	rel = world.get_node("Systems/Relationships") as Relationships
	specimens = world.get_node("Systems/Specimens") as Specimens
	TimeManager.running = false


## The next morning with a delivery (the carter's 07:40; not every day brings one, §2.9).
func _next_delivery() -> CorpseRecord:
	# A good reputation brings two on some mornings: the second still lies on the bier.
	for k: int in 6:
		_set_time(TimeManager.day + 1, 470)
		village.apply_morning(TimeManager.day)
		var r := manager.try_daily_delivery(TimeManager.day)
		if r != null:
			return r
		var drop := tree.get_first_node_in_group(&"dropoff")
		print("[P7 loop] no delivery on day %d: due %d, unburied %d, free %d, reason %s, records %s" % [TimeManager.day, manager.deliveries_due(TimeManager.day), manager.unburied_count(), world.graveyard.free_plot_count(), CorpseDeliveryRules.blocked_reason(drop, world.graveyard, manager.unburied_count(), &"dropoff"), manager.save_state().get("corpses", []).map(func(c: Dictionary) -> String: return "%s@%s" % [c.get("id"), c.get("location")])])
	return null


## A corpse left on the bier (a good reputation brings two on some mornings) goes into `grave_id`,
## unharvested, so the next delivery finds the bier free.
func _clear_bier(grave_id: String) -> void:
	for c: Dictionary in manager.save_state().get("corpses", []):
		if StringName(c.get("location", &"")) != CorpseRecord.LOCATION_DROPOFF:
			continue
		var id := String(c.get("id"))
		player.global_position = Vector3(BIER_STAND.x, world.ground_height(BIER_STAND), BIER_STAND.y)
		manager.get_corpse_node(id).interact(player)
		assert_eq(player.carried_id, id, "the second corpse of the morning carried")
		await _bury(id, grave_id)
		return


func _set_time(day: int, minute: int) -> void:
	TimeManager.set_time(day, minute)
	UIState.clear()


## Osric's dialogue through the real DialogueRunner from node `path[0]`.
func _osric(path: Array) -> void:
	var r := DialogueRunner.new()
	var speaker := world.get_node_by_layout_id("npc_carter")
	r.start(Database.dialogue(&"carter") as DialogueData, {"inventory": player.inventory, "speaker": speaker})
	r._enter(StringName(path[0]))


## The dialogue actions a villager's answers run (meet, talked, anatomy_case …).
func _say(npc_id: StringName, actions: Array) -> void:
	var speaker := world.get_node("Regions/Village/Entities/npc_" + String(npc_id))
	var typed: Array[String] = []
	for a: Variant in actions:
		typed.append(String(a))
	DialogueActions.run_all(typed, {"inventory": player.inventory, "speaker": speaker, "player": player})
	UIState.clear()


func _travel_to_village() -> void:
	player.global_position = Vector3(MILESTONE_STAND.x, world.ground_height(MILESTONE_STAND), MILESTONE_STAND.y)
	var portal := world.get_node("Entities/road_exit") as RegionPortal
	assert_true(portal.can_interact(player), "the milestone takes the gravekeeper down (%s)" % portal.get_interaction_prompt(player))
	portal.interact(player)
	await _until_arrived()
	assert_eq(player.region_id, &"village", "in Hollerbrück")


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


func _enter_crypt() -> void:
	player.global_position = Vector3(CRYPT_ACCESS.x, world.ground_height(CRYPT_ACCESS), CRYPT_ACCESS.y)
	var door := BuildingDoor.find(tree, &"crypt")
	assert_true(door.can_interact(player), "the crypt door")
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, &"crypt")


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


func _carry_to_crypt_table(corpse_id: String) -> void:
	player.global_position = Vector3(BIER_STAND.x, world.ground_height(BIER_STAND), BIER_STAND.y)
	manager.get_corpse_node(corpse_id).interact(player)
	assert_eq(player.carried_id, corpse_id, "carried from the bier")
	await _enter_crypt()
	var table := InteriorRoom.find(tree, &"crypt").get_node("Entities/MorgueTable") as MorgueTable
	table.interact(player)
	assert_eq(manager.get_record(corpse_id).location, CorpseRecord.LOCATION_TABLE, "on the crypt table")
	UIState.clear()


## Dig the Lindenacker grave, bury the carried corpse, a wooden cross.
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
	_stock({&"wooden_cross": 1})
	plot.request_marker(&"wooden_cross")  # the panel action – [E] would offer „Präparat beisetzen" first
	UIState.clear()
	assert_eq(world.graveyard.get_grave(grave_id).state, GraveRecord.State.MARKED, grave_id + " marked")
	await tree.physics_frame


func _stock_for_clearing(expansion: ExpansionManager, id: String) -> void:
	var data := expansion.data_of(id)
	if data == null:
		return
	_stock(data.cost)
	for tool: StringName in [&"axe", &"shovel", &"pickaxe", &"sickle", &"crowbar"]:
		if expansion.tool_block_reason(id, player.inventory) == "":
			break
		if Database.has_item(tool) and player.inventory.count(tool) == 0:
			player.inventory.add_item(tool, 1)


## The reverent fixture's bag is full: stacks of plain goods (no tools, coins, unique pieces or the
## items being stocked) go into the hut chest's place – simply removed – until `free` slots are empty.
func _make_room(free: int, keep: Dictionary = {}) -> void:
	var inv := player.inventory
	var empty := inv.get_slots().filter(func(s: Dictionary) -> bool: return s.is_empty() or String(s.get("id", "")) == "").size()
	for s: Dictionary in inv.get_slots():
		if empty >= free:
			return
		if s.is_empty() or String(s.get("uid", "")) != "":
			continue
		var id := StringName(String(s.get("id", "")))
		if id == &"" or id == &"coin" or keep.has(id) or keep.has(String(id)):
			continue
		var item := Database.item(id) as ItemData
		if item != null and item.category == ItemData.Category.TOOL:
			continue
		inv.remove_item(id, int(s.get("amount", 1)))
		empty += 1


func _stock(items: Dictionary) -> void:
	_make_room(items.size() + 3, items)
	for id: Variant in items:
		var key := StringName(str(id))
		var have := player.inventory.count(key)
		if have < int(items[id]):
			player.inventory.add_item(key, int(items[id]) - have)


func _uid_of(uids: PackedStringArray, organ: StringName) -> String:
	for u: String in uids:
		if specimens.get_record(u) != null and specimens.get_record(u).organ == organ:
			return u
	return ""


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
