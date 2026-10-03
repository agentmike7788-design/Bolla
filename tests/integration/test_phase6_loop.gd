extends TestCase
## W-Welt (docs/PHASE6_DESIGN.md §10 test_phase6_loop): the Phase-6 chain on the real world through
## SaveManager, from the Phase-5 end state (v4 fixture slot_p5_day30_reverent) to the chapter
## „Unter Dach und Erde" – entities and systems as a player uses them (instant timed actions, the
## real dialogue runner for Osric, the real site / door / room / table / niche / shelf / altar /
## grave entities, walking with the move actions where the contract asks for real movement):
## buildings_open → Osric p6_intro → crypt 1 (the old table goes) → bone box → old_04 lifted (EMPTY),
## walk through the portal to the ossuary → reinterred → next morning: delivery → carried into the
## crypt → table → examined / dressed / smoked → niche → chapel 1 + candle → procession with real
## movement (crypt → Kirchpforte → chapel) → catafalque → service (08:00–17:00) → grave old_04 →
## marker („Ausgesegnet") → shed 1 / 2 → fetch at the forge → crypt 2 (passage, clue) → chapel 2
## (mourners) → chapter. collect_state() identical after save_game / load_game at five moments:
## box lifted and not reinterred; the gravekeeper in the crypt carrying the corpse; the corpse in a
## niche with an open cold window and a juniper window; the corpse on the catafalque; after the chapter.

const TIMEOUT := 480.0
const SLOT := 94
const FIXTURE := "slot_p5_day30_reverent"
const ARRIVE := 0.35
## Walks (XZ): hut door → old_04 foot; old_04 → crypt access; crypt access → chapel door
## (the lane west of the old graves, the earth path, the Birkenhang passage, west of plot_10,
## north of the row, the Kirchpforte); chapel → old_04.
const TO_OLD_04: Array[Vector2] = [Vector2(-5.2, -3.4), Vector2(-2.2, -2.6), Vector2(0.6, -0.4), Vector2(2.9, 2.7)]
const TO_CRYPT: Array[Vector2] = [Vector2(1.0, 3.2), Vector2(0.8, 7.9), Vector2(-3.0, 8.35), Vector2(-7.0, 8.4), Vector2(-9.0, 8.9)]
const TO_CHAPEL: Array[Vector2] = [Vector2(-7.0, 8.4), Vector2(-3.0, 8.35), Vector2(0.8, 7.9), Vector2(-0.2, 2.5),
		Vector2(-1.2, -1.0), Vector2(1.2, -6.0), Vector2(4.5, -10.6), Vector2(4.5, -12.8), Vector2(1.2, -12.8), Vector2(0.6, -14.2),
		Vector2(0.6, -18.9), Vector2(4.5, -19.0), Vector2(4.5, -20.9)]
const CHAPEL_TO_OLD_04: Array[Vector2] = [Vector2(4.5, -19.0), Vector2(0.6, -18.9), Vector2(0.6, -14.2), Vector2(1.2, -12.8), Vector2(4.5, -12.8),
		Vector2(4.5, -10.6), Vector2(1.2, -6.0), Vector2(0.6, -0.4), Vector2(1.4, 1.0)]

var saves_dir := TestCase.user_dir("test_saves_p6_loop")
var world: WorldRoot
var player: Player
var buildings: Buildings
var ossuary: Ossuary
var rites: ChapelRites
var manager: CorpseManager
var chapters: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	chapters.clear()
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.chapter_completed.disconnect(_on_chapter)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_phase6_loop_to_roof_and_earth_with_round_trips() -> void:
	assert_eq(Phase6Fixtures.install_save_v4(FIXTURE, saves_dir, SLOT), OK)
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, FIXTURE + " loads")
	_bind()
	if world == null:
		return
	var inv := player.inventory
	# --- B1: buildings_open at once (v4 with names_in_stone_complete), Osric, the sites -------------
	assert_true(buildings.is_open(), "§1.2: buildings_open right after loading the Phase-5 end state")
	for id: String in ["site_crypt", "site_chapel", "site_shed"]:
		assert_true((world.get_node("Entities/" + id) as Node3D).visible, id + " visible")
	_osric([&"p6_intro"])
	assert_true(GameState.has_flag(&"p6_intro"), "Osric told about the council")
	var old_table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	assert_true(old_table.is_active(), "the old table works until crypt 1")
	_build(&"crypt")
	assert_eq(buildings.level(&"crypt"), 1)
	assert_false(old_table.is_active() or old_table.visible, "§4.4: the table in front of the hut is gone")
	assert_false((world.get_node("Decor/Phase4Props/WashBasin") as Node3D).visible, "the wash basin went with it")
	var door := BuildingDoor.find(tree, &"crypt")
	assert_true(door.is_open(), "the crypt door opens at level 1")
	# The bone box at the workbench, then old_04 lifted (real movement to the grave).
	_stock({&"wood": 3})
	_craft(&"bone_box")
	assert_eq(inv.count(&"bone_box"), 1, "a bone box")
	await _walk(TO_OLD_04)
	var plot := world.get_node_by_layout_id("old_04") as GravePlot
	assert_true(plot.can_interact(player), "old_04 can be lifted")
	assert_true(plot.get_interaction_prompt(player).begins_with("[E] Altes Grab heben: Barbe Lindt"), plot.get_interaction_prompt(player))
	plot.interact(player)
	assert_eq(world.graveyard.get_grave("old_04").state, GraveRecord.State.EMPTY, "§2.3: OLD → EMPTY")
	assert_eq(inv.count(&"bone_box_full"), 1)
	assert_eq(ossuary.pending(), PackedStringArray(["old_04"]))
	await _round_trip("box lifted, not reinterred")
	inv = player.inventory
	plot = world.get_node_by_layout_id("old_04") as GravePlot
	plot.interact(player)
	assert_eq(world.graveyard.get_grave("old_04").state, GraveRecord.State.DUG, "dug for the next dead")
	# Through the portal into the crypt, reinter at the ossuary shelf.
	await _walk(TO_CRYPT)
	await _enter(&"crypt")
	var coins := inv.count(&"coin")
	var shelf := _room(&"crypt").get_node("Entities/OssuaryShelf") as OssuaryShelf
	assert_true(shelf.can_interact(player), "the shelf takes the box")
	shelf.interact(player)
	assert_eq(ossuary.reinterred(), PackedStringArray(["old_04"]))
	assert_eq(inv.count(&"coin"), coins + 4, "§2.3: 4 coins from the parish")
	await _exit(&"crypt")
	# --- B2: the next morning's corpse, carried into the crypt -------------------------------------
	TimeManager.set_time(TimeManager.day + 1, 470)
	UIState.clear()
	var record := manager.try_daily_delivery(TimeManager.day)
	assert_not_null(record, "a delivery for the free place")
	if record == null:
		return
	var corpse_id := record.id
	player.global_position = world.get_waypoint(&"dropoff") + Vector3(0.6, 0, 0.4)
	manager.get_corpse_node(corpse_id).interact(player)
	assert_eq(player.carried_id, corpse_id, "carried from the bier")
	await _walk([Vector2(0.8, 7.9), Vector2(-3.0, 8.35), Vector2(-7.0, 8.4), Vector2(-9.0, 8.9)])
	await _enter(&"crypt")
	assert_true(is_instance_valid(player.carried), "the corpse came along into the crypt")
	await _round_trip("in the crypt, carrying the corpse")
	inv = player.inventory
	record = manager.get_record(corpse_id)
	assert_eq(player.interior_id, &"crypt")
	assert_true(is_instance_valid(player.carried), "still carried after the load")
	var table := _room(&"crypt").get_node("Entities/MorgueTable") as MorgueTable
	table.interact(player)
	assert_eq([record.location, record.room], [CorpseRecord.LOCATION_TABLE, &"crypt"], "on the crypt table")
	assert_eq(table.panel_title(), "Gruft-Tisch")
	var care := tree.get_first_node_in_group(&"corpse_care") as CorpseCare
	for step: StringName in care.open_steps(corpse_id):
		table.request_exam_step(step)
	UIState.clear()
	if record.needs_valuables_decision():
		table.decide_valuables(false)
	_stock({&"shroud": 1, &"juniper": 1})
	table.request_dress(CorpseRecord.DRESS_SHROUD)
	table.request_balm()
	UIState.clear()
	assert_true(record.shrouded, "dressed")
	assert_false(record.balm_windows.is_empty(), "juniper smoke")
	table.request_pick_up()
	var niche := CryptNiche.find(tree, "niche_1")
	assert_true(niche.can_interact(player), "niche 1 open at crypt 1")
	niche.interact(player)
	assert_eq([record.location, record.slot_id], [CorpseRecord.LOCATION_NICHE, "niche_1"], "in the niche")
	assert_false(record.cold_windows.is_empty(), "cold window open")
	assert_false(CryptNiche.find(tree, "niche_3").is_open(), "niche 3 sealed at crypt 1")
	await _round_trip("niche with cold and juniper windows")
	inv = player.inventory
	record = manager.get_record(corpse_id)
	# --- the chapel: level 1, a candle, the Kirchpforte -------------------------------------------
	await _exit(&"crypt")
	_build(&"chapel")
	_osric([&"p6_candles", "Eine Altarkerze"])
	assert_eq(inv.count(&"altar_candle"), 1, "an altar candle from Osric")
	await _enter(&"crypt")
	niche = CryptNiche.find(tree, "niche_1")
	niche.interact(player)
	assert_eq(player.carried_id, corpse_id, "out of the niche")
	await _exit(&"crypt")
	# The procession (real movement): the Kirchpforte is unlocked first with free hands – put down,
	# unlock, pick up again (§4.2: the gate opens with buildings_open).
	await _walk(TO_CHAPEL.slice(0, 11))
	manager.put_down(corpse_id, CorpseRecord.LOCATION_GROUND, player.global_transform)
	var gate := world.get_node("Entities/obs_c_gate") as ClearableObstacle
	assert_true(gate.can_interact(player), "the Kirchpforte can be unlocked")
	gate.interact(player)
	assert_true(gate.cleared, "Kirchpforte open")
	manager.get_corpse_node(corpse_id).interact(player)
	await _walk(TO_CHAPEL.slice(11))
	await _enter(&"chapel")
	var catafalque := _room(&"chapel").get_node("Entities/Catafalque") as Catafalque
	catafalque.interact(player)
	assert_eq([record.location, record.room], [CorpseRecord.LOCATION_CATAFALQUE, &"chapel"], "on the catafalque")
	await _round_trip("corpse on the catafalque")
	inv = player.inventory
	record = manager.get_record(corpse_id)
	if TimeManager.minute_of_day < 480 or TimeManager.minute_of_day > 1020:
		TimeManager.set_time(TimeManager.day, 600)
	var altar := _room(&"chapel").get_node("Entities/ChapelAltar") as ChapelAltar
	coins = inv.count(&"coin")
	assert_true(altar.get_interaction_prompt(player).begins_with("[E] Aussegnung halten"), altar.get_interaction_prompt(player))
	altar.interact(player)
	altar.request_service()
	UIState.clear()
	assert_true(record.service_held, "§2.4: the service is held")
	assert_eq(inv.count(&"coin"), coins + 3, "the family's fee at chapel 1")
	assert_eq(inv.count(&"altar_candle"), 0, "the candle burnt")
	catafalque = _room(&"chapel").get_node("Entities/Catafalque") as Catafalque
	catafalque.interact(player)
	await _exit(&"chapel")
	await _walk(CHAPEL_TO_OLD_04)
	plot = world.get_node_by_layout_id("old_04") as GravePlot
	plot.interact(player)
	assert_eq(world.graveyard.get_grave("old_04").state, GraveRecord.State.FILLED, "buried in the lifted old place")
	_stock({&"wooden_cross": 1})
	plot.interact(player)
	if world.graveyard.get_grave("old_04").state == GraveRecord.State.FILLED:
		plot.request_marker(&"wooden_cross")
	UIState.clear()
	var grave := world.graveyard.get_grave("old_04")
	assert_eq(grave.state, GraveRecord.State.MARKED, "marked")
	var lines := GraveQuality.breakdown(record, grave.marker_id, Database.config(&"economy_config") as EconomyConfig, grave.design)
	assert_true(lines.any(func(l: Dictionary) -> bool: return String(l.get("label", "")) == "Ausgesegnet"), "quality line „Ausgesegnet\"")
	assert_eq(rites.services_buried(), 1)
	# --- the shed 1 / 2, fetching at the forge -----------------------------------------------------
	_build(&"shed")
	_build(&"shed")
	var store := ShedStore.find(tree)
	assert_not_null(store, "the shed store")
	store.store().add_item(&"iron_ore", 4)
	store.store().add_item(&"charcoal", 2)
	for id: StringName in [&"iron_ore", &"charcoal"]:
		inv.remove_item(id, inv.count(id))
	var forge := world.get_node("Entities/station_forge") as Workbench
	var needs := (Database.recipe(&"iron_bar") as RecipeData).inputs
	forge.interact(player)
	forge.request_fetch(needs)
	UIState.clear()
	assert_eq([inv.count(&"iron_ore"), inv.count(&"charcoal")], [2, 1], "§2.5: the missing inputs fetched from the shed")
	assert_eq([store.store().count(&"iron_ore"), store.store().count(&"charcoal")], [2, 1])
	# --- crypt 2 (the walled door), chapel 2 → the chapter -----------------------------------------
	_build(&"crypt")
	assert_eq(ossuary.passage_state(), Ossuary.PASSAGE_SEALED, "the walled-up door appears")
	await _enter(&"crypt")
	var passage := _room(&"crypt").get_node("Entities/SealedPassage") as SealedPassage
	assert_true(passage.visible and passage.can_interact(player), "the passage can be looked at")
	passage.interact(player)
	assert_true(GameState.has_flag(&"c_crypt_draft_seen") or _has_clue(&"c_crypt_draft"), "clue „Der kalte Zug\"")
	await _exit(&"crypt")
	assert_eq(chapters, [], "no chapter before chapel 2")
	_build(&"chapel")
	var mourners := _room(&"chapel").get_node("Entities/MournerSet") as MournerSet
	assert_true(mourners.is_visible_in_tree() or mourners.get_meta(&"min_level", 0) == 2, "the mourners' set stands from chapel 2")
	assert_eq(mourners.figures().size(), 4)
	assert_eq(chapters, [&"roof_and_earth"], "§1.5: chapter „Unter Dach und Erde\"")
	assert_true(GameState.has_flag(&"roof_and_earth_complete"))
	await _round_trip("after the chapter")


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	assert_not_null(world, "world")
	if world == null:
		return
	player = world.get_player()
	player.instant_actions = true
	buildings = world.get_node("Systems/Buildings") as Buildings
	ossuary = world.get_node("Systems/Ossuary") as Ossuary
	rites = world.get_node("Systems/Chapel") as ChapelRites
	manager = world.corpse_manager
	TimeManager.running = false


func _room(id: StringName) -> InteriorRoom:
	return InteriorRoom.find(tree, id)


## Through the building's door into its room (the real portal with its fade).
func _enter(id: StringName) -> void:
	var door := BuildingDoor.find(tree, id)
	assert_true(door.can_interact(player), "the %s door lets the gravekeeper in" % id)
	door.interact(player)
	await _until_arrived()
	assert_eq(player.interior_id, id, "inside the " + String(id))
	assert_true(_room(id).active, String(id) + " room active")


func _exit(id: StringName) -> void:
	var exit := _room(id).find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomExit)[0] as RoomExit
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


## Buildings via the site's panel action (materials and coins stocked first).
func _build(id: StringName) -> void:
	var site := world.get_node("Entities/site_" + String(id)) as BuildingSite
	var next := BuildingRules.next_level(site.building_data(), buildings.level(id))
	assert_not_null(next, "%s has a next level" % id)
	if next == null:
		return
	_stock(next.inputs)
	player.inventory.add_item(&"coin", next.coins)
	var before := buildings.level(id)
	assert_true(site.can_interact(player), "site of %s" % id)
	site.interact(player)
	assert_eq(site.block_reason(player.inventory), "", "%s buildable" % id)
	site.request_upgrade()
	UIState.clear()
	assert_eq(buildings.level(id), before + 1, "%s level %d" % [id, before + 1])


func _craft(recipe: StringName) -> void:
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	assert_true(bench.can_interact(player), "the workbench")
	bench.interact(player)
	bench.request_craft(recipe)
	UIState.clear()


func _stock(items: Dictionary) -> void:
	for id: Variant in items:
		var key := StringName(str(id))
		var have := player.inventory.count(key)
		if have < int(items[id]):
			player.inventory.add_item(key, int(items[id]) - have)


func _has_clue(id: StringName) -> bool:
	var journal := tree.get_first_node_in_group(&"journal")
	return journal != null and journal.has_method(&"has_clue") and bool(journal.call(&"has_clue", id))


func _osric(path: Array) -> void:
	var r := DialogueRunner.new()
	var speaker := world.get_node_by_layout_id("npc_carter")
	r.start(Database.dialogue(&"carter") as DialogueData, {"inventory": player.inventory, "speaker": speaker})
	r._enter(StringName(path[0]))
	for step: Variant in path.slice(1):
		var choices := r.available_choices()
		var picked := -1
		for i: int in choices.size():
			if (step is StringName and choices[i].next == step) or (step is String and choices[i].text.contains(step)):
				picked = i
				break
		assert_true(picked >= 0, "Osric: a choice to %s" % step)
		if picked < 0:
			return
		r.choose(picked)


func _walk(points: Array) -> void:
	for target: Vector2 in points:
		var budget := 60 + int(_flat_distance(player.global_position, Vector3(target.x, 0, target.y)) / 1.6 * 60.0 * 2.5)
		while _flat_distance(player.global_position, Vector3(target.x, 0, target.y)) > ARRIVE and budget > 0:
			var dir := Vector2(target.x - player.global_position.x, target.y - player.global_position.z).normalized()
			_press(&"move_right", maxf(dir.x, 0.0))
			_press(&"move_left", maxf(-dir.x, 0.0))
			_press(&"move_down", maxf(dir.y, 0.0))
			_press(&"move_up", maxf(-dir.y, 0.0))
			await tree.physics_frame
			budget -= 1
		assert_true(budget > 0, "walked to %s (stuck at %s)" % [target, player.global_position])
		if budget <= 0:
			break
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	await tree.physics_frame


func _press(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Save → load → identical collect_state(); rebinds the new world.
func _round_trip(moment: String) -> void:
	UIState.clear()
	# The gravekeeper settles on the ground after a portal trip before the state is taken.
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


## Paths where two states differ (floats within 1e-9 relative – the save's float encoding).
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
		# The gravekeeper may settle by a float32 ulp on the ground collision after a load.
		if (a as Vector3).distance_to(b) > 1e-5:
			out.append("~%s (%s → %s)" % [path, a, b])
		return
	if (a is float or b is float) and (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 1e-9 * maxf(1.0, absf(float(a))):
			out.append("~%s" % path)
		return
	if typeof(a) != typeof(b) or a != b:
		out.append("~%s (%s → %s)" % [path, a, b])


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_chapter(chapter_id: StringName) -> void:
	chapters.append(chapter_id)
