extends TestCase
## W3 QA regressions of the Phase-6 review (docs/reviews/phase6_wip/qa_playthrough.md, "Befunde"):
## each QA6-nn test failed before its fix (or pins a checked guarantee, marked "Prüfung"). Runs on
## the real graveyard world, loaded from the Phase-5 end state (v4 fixture slot_p5_day30_reverent:
## buildings_open at once, §1.2).

const TIMEOUT := 400.0
const SLOT := 95
const FIXTURE := "slot_p5_day30_reverent"

var saves_dir := TestCase.user_dir("test_saves_p6_qa")
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var buildings: Buildings
var ossuary: Ossuary
var rites: ChapelRites
var manager: CorpseManager
var ui: UIRoot
var notes: Array[String] = []
var chapters: Array[StringName] = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	chapters.clear()
	assert_eq(Phase6Fixtures.install_save_v4(FIXTURE, saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK, FIXTURE + " loads")
	_bind()
	EventBus.notification_requested.connect(_on_note)
	EventBus.chapter_completed.connect(_on_chapter)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.chapter_completed.disconnect(_on_chapter)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


# --- QA6-01: the chapter also completes when the serviced grave's marker comes last -------------
# §1.5 / §3.3: Buildings.check_goal runs from Graveyard.place_marker / set_designed_stone when the
# corpse has service_held. Graveyard never called it: with all levels and a reinterment done first,
# marking the serviced grave did not complete „Unter Dach und Erde" (stuck for good once all six
# boxes were reinterred and every building at level 3).

func test_chapter_completes_when_the_serviced_grave_is_marked_last() -> void:
	var id := _goal_but_the_marker()
	assert_eq(chapters, [] as Array[StringName], "not yet: the serviced corpse has no marker")
	_stock({&"wooden_cross": 1})
	assert_true(graveyard.place_marker("old_04", &"wooden_cross", player.inventory) > 0, "marked")
	assert_eq(chapters, [&"roof_and_earth"] as Array[StringName], "§1.5: the chapter with the marker (%s)" % id)
	assert_true(GameState.has_flag(&"roof_and_earth_complete"))


func test_chapter_completes_when_a_designed_stone_is_set_last() -> void:
	_goal_but_the_marker()
	var d := StoneDesign.new()
	d.shape = &"stone_stele"
	assert_true(graveyard.set_designed_stone("old_04", d, player.inventory) > 0, "stele set")
	assert_eq(chapters, [&"roof_and_earth"] as Array[StringName], "§1.5: the chapter with the designed stone")


# --- QA6-02: the chapter panel shows „davon mit Trauergästen" -----------------------------------
# §1.5: „Aussegnungen (davon mit Trauergästen)". Buildings.chapter_context had no
# services_mourners – the panel only printed the plain number.

func test_chapter_context_counts_services_with_mourners() -> void:
	_levels({&"crypt": 1, &"chapel": 2})
	assert_ne(_serviced("old_04"), "")
	assert_eq(int(buildings.chapter_context().get("services_mourners", -1)), 1, "a service at chapel 2 had 2 mourners")
	var values := Phase6Texts.chapter_values(buildings.chapter_context())
	assert_true(values[2].contains("1"), "the panel line shows „davon mit Trauergästen\": %s" % values[2])
	assert_ne(values[2], "1", "not the plain number")
	# Save → load keeps the count.
	assert_eq(SaveManager.save_game(SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	assert_eq(int(buildings.chapter_context().get("services_mourners", -1)), 1, "kept over save → load")


# --- QA6-03: Buildings.open() is public -----------------------------------------------------------
# The debug console („buildings open", „build …") and the UI screenshot director called the private
# Buildings._open() by name.

func test_buildings_open_is_public_and_idempotent() -> void:
	assert_true(buildings.has_method(&"open"), "Buildings.open()")
	await SaveManager.new_game()
	_bind()
	assert_false(buildings.is_open())
	GameState.set_flag(&"names_in_stone_complete", true)
	buildings.open()
	buildings.open()
	assert_true(buildings.is_open())
	assert_eq(int(buildings.save_state().open_day), TimeManager.day, "open day once")
	for path: String in ["res://src/debug/debug_commands_phase6.gd", "res://src/ui/tools/ui_screenshot_director_phase6.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("&\"_open\""), path + " uses Buildings.open()")


# --- QA6-04: „Überschuss einlagern" keeps bone boxes and altar candles with the gravekeeper --------
# §2.5: „keine Werkzeuge, keine Münzen, keine Gebeinkisten". excluded_items listed only
# bone_box_full: the empty boxes (and the candles) vanished into the shed, and the old grave then
# said „Keine Gebeinkiste – an der Werkbank zimmern." / the altar „Keine Altarkerze" – there is no
# fetch at an old grave or at the altar.

func test_store_surplus_keeps_bone_boxes_and_candles() -> void:
	_levels({&"shed": 3})
	var store := ShedStore.find(tree)
	_stock({&"bone_box": 2, &"bone_box_full": 1, &"altar_candle": 3, &"wood": 5})
	var moved := ShedSupply.run_store(tree, player)
	assert_true(int(moved.get(&"wood", 0)) >= 5, "the wood goes in (%s)" % str(moved))
	for id: StringName in [&"bone_box", &"bone_box_full", &"altar_candle"]:
		assert_false(moved.has(id), "%s stays with the gravekeeper" % id)
		assert_eq(store.store().count(id), 0, "%s not in the shed" % id)


# --- QA6-05: the building / chapel / devotion panels drive the real loop (Prüfung, W1/W2 point 1) --

func test_phase6_panels_are_registered_and_drive_the_loop() -> void:
	for id: StringName in [&"building", &"chapel", &"devotion"]:
		assert_not_null(ui.get_panel(id), "panel %s in UIRoot" % id)
	# The building panel builds crypt 1.
	var site := world.get_node("Entities/site_crypt") as BuildingSite
	var next := BuildingRules.next_level(site.building_data(), 0)
	_stock(next.inputs)
	_stock({&"coin": next.coins})
	site.interact(player)
	var panel := ui.get_panel(&"building") as BuildingPanel
	assert_true(panel.is_open, "building panel open")
	assert_false(panel.build_button.disabled, "„Stufe 1 bauen\" enabled: %s" % panel.block_reason())
	panel.build_button.pressed.emit()
	UIState.clear()
	assert_eq(buildings.level(&"crypt"), 1, "crypt 1 through the panel")
	_levels({&"chapel": 1})
	# The chapel panel holds the service.
	var id := _corpse_on_catafalque()
	var altar := InteriorRoom.find(tree, &"chapel").get_node("Entities/ChapelAltar") as ChapelAltar
	_stock({&"altar_candle": 2})
	TimeManager.set_time(TimeManager.day, 600)
	altar.interact(player)
	var chapel := ui.get_panel(&"chapel") as ChapelPanel
	assert_true(chapel.is_open, "chapel panel open")
	assert_eq(chapel.block_reason(), "")
	chapel.service_button.pressed.emit()
	UIState.clear()
	assert_true(manager.get_record(id).service_held, "service through the chapel panel")
	# The devotion panel (catafalque empty: the corpse picked up again).
	manager.pick_up(id, player)
	manager.put_down(id, CorpseRecord.LOCATION_GROUND, player.global_transform)
	var grave_id := _marked_grave()
	altar.interact(player)
	var devotion := ui.get_panel(&"devotion") as DevotionPanel
	assert_true(devotion.is_open, "devotion panel open")
	devotion.select(grave_id)
	assert_eq(devotion.block_reason(), "")
	devotion.devotion_button.pressed.emit()
	UIState.clear()
	assert_eq(rites.devotion_level(grave_id), 1, "devotion through the panel")


# --- QA6-07: a service that began fresh enough ends with its fee ------------------------------
# ChapelRites.hold_service re-checked the freshness at the end of the 45 minutes: a corpse at 0.31
# when the service began fell below 0.3 during it – no service, the candle kept, the time lost,
# „Gerade nicht möglich." and a push_warning in normal play (found by the mortician bot).

func test_service_begun_fresh_enough_ends_with_its_fee() -> void:
	_levels({&"crypt": 1, &"chapel": 1})
	var id := _corpse_on_catafalque()
	var record := manager.get_record(id)
	TimeManager.set_time(TimeManager.day, 600)
	# Freshness 0.31 now: arrival moved back so that the formula gives just above the minimum.
	var rate := CorpseDecay.decay_per_hour(record, Database.corpse_tables() as CorpseTables)
	record.arrival_total_minutes = TimeManager.total_minutes() - int(ceil((1.0 - 0.31) / rate * 60.0))
	record.last_decay_total = record.arrival_total_minutes
	manager._decay_record(record, TimeManager.total_minutes())
	assert_true(record.freshness >= 0.3 and record.freshness < 0.33, "just fresh enough: %.3f" % record.freshness)
	_stock({&"altar_candle": 1})
	var coins := player.inventory.count(&"coin")
	var altar := InteriorRoom.find(tree, &"chapel").get_node("Entities/ChapelAltar") as ChapelAltar
	altar.interact(player)
	UIState.clear()
	altar.request_service()
	assert_true(record.service_held, "the service is held (freshness at the end %.3f)" % record.freshness)
	assert_eq(player.inventory.count(&"coin"), coins + 3, "the fee")
	assert_eq(player.inventory.count(&"altar_candle"), 0, "the candle burnt")
	assert_false(notes.has(ChapelAltar.TEXT_BUSY), "no „Gerade nicht möglich.\"")


# --- QA6-06: an upgrade shows the crypt's new state at once ---------------------------------------
# Buildings.upgrade refreshed the rooms before Ossuary.on_crypt_level changed the passage, and the
# SealedPassage / OssuaryShelf were in no group: the walled-up door appeared only one frame later
# (deferred signal); apply_levels never refreshed them.

func test_crypt_upgrade_shows_the_walled_door_at_once() -> void:
	_levels({&"crypt": 2})
	var passage := InteriorRoom.find(tree, &"crypt").get_node("Entities/SealedPassage") as SealedPassage
	assert_true(passage.is_in_group(&"sealed_passage"), "refreshed by Buildings.apply_levels")
	assert_true(passage.visible, "the walled-up door right after the upgrade (same frame)")
	var shelf := InteriorRoom.find(tree, &"crypt").get_node("Entities/OssuaryShelf") as OssuaryShelf
	assert_true(shelf.is_in_group(&"ossuary_shelf"))


# --- QA6-10: a number in a goal flag is no script error -------------------------------------------
# The HUD's objective / chapter lines compared GameState.get_flag(goal) == true: a damaged save with
# a float or int in names_in_stone_complete / roof_and_earth_complete / bruch_license … raised
# „Invalid operands 'float' and 'bool'“ on load (save fuzzer, real mid-Phase-6 save).

func test_number_in_a_goal_flag_is_no_script_error() -> void:
	for flag: StringName in [&"names_in_stone_complete", &"roof_and_earth_complete", &"bruch_license", &"p6_intro",
			&"c_crypt_draft_seen", &"trader_known"]:
		GameState.set_flag(flag, 2.5)
	ui.hud.refresh_all()
	var state := CemeteryStatus.phase6_state(tree, player.inventory)
	assert_true(bool(state.get("goal_done", false)), "2.5 counts as set")
	GameState.set_flag(&"roof_and_earth_complete", 0)
	assert_false(GameState.flag_on(&"roof_and_earth_complete"), "0 counts as not set")
	ui.hud.refresh_all()


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	manager = world.corpse_manager
	buildings = world.get_node("Systems/Buildings") as Buildings
	ossuary = world.get_node("Systems/Ossuary") as Ossuary
	rites = world.get_node("Systems/Chapel") as ChapelRites
	ui = world.get_node_or_null("UI") as UIRoot
	TimeManager.running = false


func _stock(items: Dictionary) -> void:
	for id: Variant in items:
		var key := StringName(str(id))
		var have := player.inventory.count(key)
		if have < int(items[id]):
			player.inventory.add_item(key, int(items[id]) - have)


## Builds up to the given levels through Buildings.upgrade (materials and coins stocked).
func _levels(goal: Dictionary) -> void:
	for id: StringName in goal:
		while buildings.level(id) < int(goal[id]):
			var next := BuildingRules.next_level(buildings.building(id), buildings.level(id))
			_stock(next.inputs)
			player.inventory.add_item(&"coin", next.coins)
			assert_true(buildings.upgrade(id, player.inventory), "%s → %d" % [id, next.level])


## Lifts `grave_id` and reinters its box.
func _lift_and_reinter(grave_id: String) -> void:
	_stock({&"bone_box": 1})
	assert_true(ossuary.lift(grave_id, player.inventory), "lifted " + grave_id)
	assert_eq(ossuary.reinter(player.inventory), grave_id, "reinterred")


## A delivered, dressed corpse on the catafalque (old_04 lifted and dug for it); its id.
func _corpse_on_catafalque() -> String:
	if graveyard.get_grave("old_04").state == GraveRecord.State.OLD:
		_stock({&"bone_box": 1})
		assert_true(ossuary.lift("old_04", player.inventory))
	if graveyard.get_grave("old_04").state == GraveRecord.State.EMPTY:
		graveyard.dig("old_04")
	TimeManager.set_time(TimeManager.day + 1, 470)
	var record := manager.try_daily_delivery(TimeManager.day)
	assert_not_null(record, "a delivery for the lifted place")
	if record == null:
		return ""
	record.dress = CorpseRecord.DRESS_GOWN
	var cat := InteriorRoom.find(tree, &"chapel").get_node("Entities/Catafalque") as Catafalque
	assert_true(manager.put_down(record.id, CorpseRecord.LOCATION_CATAFALQUE, cat.slot_node().global_transform, null, &"chapel"))
	return record.id


## A serviced corpse buried in `grave_id` (FILLED, no marker yet); its id.
func _serviced(grave_id: String) -> String:
	var id := _corpse_on_catafalque()
	if id == "":
		return ""
	TimeManager.set_time(TimeManager.day, 600)
	_stock({&"altar_candle": 1})
	assert_true(rites.hold_service(id, player.inventory) >= 0, "service held")
	assert_true(manager.pick_up(id, player))
	assert_true(graveyard.bury(grave_id, id), "buried in " + grave_id)
	return id


## Everything of §1.5 but the serviced grave's marker: levels 2/2/2, one box reinterred, the
## serviced corpse buried in old_04 (FILLED).
func _goal_but_the_marker() -> String:
	_levels({&"crypt": 2, &"chapel": 2, &"shed": 2})
	_lift_and_reinter("old_06")
	var id := _serviced("old_04")
	assert_eq(graveyard.get_grave("old_04").state, GraveRecord.State.FILLED)
	return id


func _marked_grave() -> String:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED:
			return g.id
	return ""


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _on_chapter(id: StringName) -> void:
	chapters.append(id)
