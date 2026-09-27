extends TestCase
## W1: the vertical-slice loop on the real world (§9): new game through SaveManager, one
## corpse from delivery to a finished grave via direct interact() / panel calls (instant
## actions), exact quality / payment / cemetery rating from the record, save 98 → load 98 →
## identical state. Plus: day-2 delivery with valuables and the decision, a skipped delivery
## at an occupied bier, sleeping → autosave slot 0, resources refilled the next day.
## Deviation from the §9 order: the grave is dug before the corpse is picked up again –
## digging needs free hands (§3.4 "Tragen erlaubt: Tisch, offenes Grab, NPC, Q").

const TIMEOUT := 120.0
const TEST_SAVES := "user://test_saves"
const ROUNDTRIP_SLOT := 98
const SLOTS: Array[int] = [0, 1, ROUNDTRIP_SLOT]
## TimeManager start of a new game (data/config/time_config.tres): 06:30.
const START_MINUTE := 390

var world: WorldRoot
var player: Player
var manager: CorpseManager
var graveyard: Graveyard
var table: MorgueTable
var economy: EconomyConfig
var tables: CorpseTables
var panels: Array = []
var skipped: Array = []


func before_each() -> void:
	SaveManager.save_dir = TEST_SAVES
	_delete_saves()
	panels.clear()
	skipped.clear()
	EventBus.ui_panel_requested.connect(_on_panel)
	EventBus.delivery_skipped.connect(_on_skipped)
	await SaveManager.new_game()
	_bind_world()
	# Deterministic: from here on the clock only moves through actions and set_time().
	TimeManager.running = false
	economy = Database.config(&"economy_config") as EconomyConfig
	tables = Database.corpse_tables() as CorpseTables


func after_each() -> void:
	EventBus.ui_panel_requested.disconnect(_on_panel)
	EventBus.delivery_skipped.disconnect(_on_skipped)
	_delete_saves()


func test_full_loop_day_one_and_save_roundtrip() -> void:
	assert_not_null(world, "new_game loaded the graveyard world")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, START_MINUTE])
	var coins := player.inventory.count(&"coin")
	assert_eq(coins, 5, "start inventory")
	# The day-1 corpse: fixed seed, tutorial day without traits (so no valuables).
	var record := manager.try_daily_delivery(1)
	assert_not_null(record)
	assert_eq(record.seed, CorpseGenerator.seed_for(1, 0))
	assert_false(record.has_trait(CorpseRecord.TRAIT_VALUABLES))
	var dropoff := world.get_node_by_layout_id("dropoff") as Dropoff
	assert_false(dropoff.is_free())
	# pick up at the bier -> table
	manager.get_corpse_node(record.id).interact(player)
	assert_eq(player.carried_id, record.id)
	assert_true(dropoff.is_free())
	table.interact(player)
	assert_eq(record.location, CorpseRecord.LOCATION_TABLE)
	assert_eq(table.corpse_id, record.id)
	table.interact(player)
	assert_eq(panels.back()[0], &"corpse_exam")
	# examine + shroud through the panel API
	table.request_examine()
	assert_true(record.examined)
	player.inventory.add_item(&"shroud", 1)
	player.inventory.add_item(&"wooden_cross", 1)
	table.request_shroud()
	assert_true(record.shrouded)
	assert_eq(player.inventory.count(&"shroud"), 0)
	# dig (free hands), carry the corpse over, bury, place the cross
	var plot := world.get_node_by_layout_id("plot_01") as GravePlot
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, GraveRecord.State.DUG)
	table.request_pick_up()
	assert_eq(player.carried_id, record.id)
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_01").state, GraveRecord.State.FILLED)
	assert_eq(record.location, CorpseRecord.LOCATION_BURIED)
	assert_null(player.carried)
	plot.interact(player)
	var grave := graveyard.get_grave("plot_01")
	assert_eq(grave.state, GraveRecord.State.MARKED)
	assert_eq(grave.marker_id, &"wooden_cross")
	# quality = buried + shroud + cross + examined + freshness bonus, all from the record
	var fresh := _fresh_points(record)
	var expected := economy.quality_buried + economy.quality_shroud + economy.marker_quality[&"wooden_cross"] \
			+ economy.quality_examined + fresh
	assert_eq(expected, 2 + 2 + 1 + 1 + fresh, "§2.4 values")
	assert_eq(grave.quality, clampi(expected, economy.quality_min, economy.quality_max))
	var payment := int(tables.get_cause(record.cause_id).base_payment) + floori(grave.quality * economy.payment_per_quality)
	assert_eq(player.inventory.count(&"coin"), coins + payment, "start coins + payment")
	assert_eq(graveyard.total_quality(), grave.quality, "old graves count 0")
	assert_eq(graveyard.rating(), CemeteryRating.rating(grave.quality, economy))
	assert_eq(GameState.get_stat(&"burials"), 1)
	assert_eq(TimeManager.minute_of_day, START_MINUTE + 20 + 10 + 60 + 30 + 10, "every action cost its minutes")
	# save 98 -> load 98 -> identical state
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(ROUNDTRIP_SLOT), OK)
	var err: Error = await SaveManager.load_game(ROUNDTRIP_SLOT)
	assert_eq(err, OK)
	var after := SaveManager.collect_state()
	assert_eq(after, before, "collect_state round trip")
	_bind_world()
	assert_eq(graveyard.get_grave("plot_01").state, GraveRecord.State.MARKED)
	var loaded_plot := world.get_node_by_layout_id("plot_01") as GravePlot
	assert_eq(loaded_plot.state, GraveRecord.State.MARKED, "visual restored")
	assert_eq(loaded_plot.get_interaction_prompt(player), "Grab von %s – Qualität %d/10" % [record.display_name, grave.quality])


func test_day_two_delivery_with_valuables_and_decision() -> void:
	TimeManager.set_time(1, tables.delivery_minute)
	var first := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert_not_null(first, "day-1 delivery at 07:40")
	# clear the bier: the first corpse goes to the ground by the table
	manager.get_corpse_node(first.id).interact(player)
	manager.put_down(first.id, CorpseRecord.LOCATION_GROUND, _ground_xform(Vector2(-3.5, -2.0)))
	TimeManager.set_time(2, tables.delivery_minute)
	var second := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert_not_null(second, "day-2 delivery")
	assert_ne(second.id, first.id)
	assert_true(second.has_trait(CorpseRecord.TRAIT_VALUABLES), "day 2 forces valuables")
	assert_true(second.valuables_coins >= tables.valuables_coins_min and second.valuables_coins <= tables.valuables_coins_max)
	manager.get_corpse_node(second.id).interact(player)
	table.interact(player)
	table.request_examine()
	assert_true(second.needs_valuables_decision())
	player.inventory.add_item(&"shroud", 1)
	table.request_shroud()
	assert_false(second.shrouded, "shroud locked until the decision")
	var coins := player.inventory.count(&"coin")
	table.decide_valuables(true)
	assert_eq(second.valuables_decision, CorpseRecord.DECISION_TAKEN)
	assert_eq(player.inventory.count(&"coin"), coins + second.valuables_coins)
	assert_eq(GameState.get_stat(&"valuables_taken"), 1)
	assert_eq(GameState.get_stat(&"reputation"), economy.valuables_reputation)
	table.request_shroud()
	assert_true(second.shrouded)
	var plot := world.get_node_by_layout_id("plot_02") as GravePlot
	plot.interact(player)
	table.request_pick_up()
	plot.interact(player)
	player.inventory.add_item(&"gravestone_simple", 1)
	coins = player.inventory.count(&"coin")
	plot.interact(player)
	var grave := graveyard.get_grave("plot_02")
	var expected := economy.quality_buried + economy.quality_shroud + economy.marker_quality[&"gravestone_simple"] \
			+ economy.quality_examined + _fresh_points(second) + economy.valuables_taken_malus
	assert_eq(grave.quality, clampi(expected, economy.quality_min, economy.quality_max))
	var payment := int(tables.get_cause(second.cause_id).base_payment) + floori(grave.quality * economy.payment_per_quality)
	assert_eq(player.inventory.count(&"coin"), coins + payment)
	assert_eq(GameState.reputation_label(), ReputationRules.label(ReputationRules.tier(economy.valuables_reputation, null)))


func test_skipped_delivery_at_an_occupied_bier() -> void:
	TimeManager.set_time(1, tables.delivery_minute)
	var first := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert_not_null(first)
	TimeManager.set_time(2, tables.delivery_minute)
	assert_eq(manager.records().size(), 1, "no second corpse (no queue)")
	assert_eq(GameState.get_stat(&"missed_deliveries"), 1)
	assert_eq(GameState.get_flag(&"delivery_skipped"), 2)
	assert_eq(skipped.size(), 1)
	assert_eq(skipped[0][0], 2)
	var npc := world.get_node_by_layout_id("npc_carter") as Npc
	npc.refresh()
	assert_true(npc.visible and npc.cargo.visible, "the carter keeps the corpse on his cart")


func test_sleep_autosaves_and_resources_refill() -> void:
	var wood := world.get_node_by_layout_id("res_wood") as ResourceNode
	assert_eq(wood.remaining, 6, "full on new_game_started")
	var start_wood := player.inventory.count(&"wood")
	wood.interact(player)
	wood.interact(player)
	assert_eq(wood.remaining, 4)
	assert_eq(player.inventory.count(&"wood"), start_wood + 2)
	var bed := world.get_node("HutInterior/Entities/bed") as Bed
	assert_eq(bed.get_interaction_prompt(player), "[E] Ausruhen bis 18:00")
	TimeManager.set_time(1, 19 * 60)
	assert_eq(bed.get_interaction_prompt(player), "[E] Schlafen bis 06:00")
	assert_false(SaveManager.has_save(0))
	bed.interact(player)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(GameState.get_stat(&"days_played"), 1)
	assert_eq(panels.back()[0], &"day_summary")
	assert_eq((panels.back()[1] as Dictionary).day, 1)
	assert_true(SaveManager.has_save(0), "autosave slot 0")
	var info := SaveManager.get_slot_info(0)
	assert_eq([info.day, info.minute_of_day], [2, 360])
	assert_eq(wood.remaining, 6, "refilled on the new day")
	assert_eq(wood.last_reset_day, 2)
	var err: Error = await SaveManager.load_game(0)
	assert_eq(err, OK)
	_bind_world()
	var loaded := world.get_node_by_layout_id("res_wood") as ResourceNode
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [2, 360])
	assert_eq(loaded.remaining, 6)
	assert_eq(player.inventory.count(&"wood"), start_wood + 2)


# --- helpers ----------------------------------------------------------------------------------

func _bind_world() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	manager = world.corpse_manager
	graveyard = world.graveyard
	table = world.get_node_by_layout_id("morgue_table") as MorgueTable


func _fresh_points(record: CorpseRecord) -> int:
	var f := record.freshness_at_burial
	if f >= economy.fresh_good_threshold:
		return economy.fresh_good_bonus
	if f < economy.fresh_bad_threshold:
		return economy.fresh_bad_malus
	return 0


func _record_at(location: StringName) -> CorpseRecord:
	for r: CorpseRecord in manager.records():
		if r.location == location:
			return r
	return null


func _ground_xform(p: Vector2) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(p.x, world.ground_height(p), p.y))


func _delete_saves() -> void:
	if SaveManager.save_dir != TEST_SAVES:
		return
	for slot: int in SLOTS:
		SaveManager.delete_save(slot)


func _on_panel(panel: StringName, context: Dictionary) -> void:
	panels.append([panel, context])


func _on_skipped(day: int, reason: String) -> void:
	skipped.append([day, reason])
