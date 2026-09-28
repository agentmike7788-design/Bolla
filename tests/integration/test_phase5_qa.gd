extends TestCase
## W3 QA regressions of the Phase-5 review (docs/reviews/phase5_wip/qa_playthrough.md, "Befunde"):
## each QA5-nn test failed before its fix (or pins a checked guarantee, marked "Prüfung"). Runs on
## the real graveyard world, loaded from the Phase-4 end state (v3 fixture slot_p4_day20_reverent:
## workshop_open at once).

const TIMEOUT := 300.0
const SLOT := 92
const FIXTURE := "slot_p4_day20_reverent"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


## Refuses to give up one item id (a removal failing midway).
class StubbornInventory extends "res://tests/fixtures/fake_inventory.gd":
	var stubborn: StringName = &""

	func remove_item(id: StringName, amount: int) -> bool:
		if id == stubborn:
			return false
		return super.remove_item(id, amount)


var saves_dir := TestCase.user_dir("test_saves_p5_qa")
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var expansion: ExpansionManager
var shop: Workshop
var masonry: Stonemasonry
var notes: Array[String] = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	assert_eq(Phase5Fixtures.install_save_v3(FIXTURE, saves_dir, SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK, FIXTURE + " loads")
	_bind()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


# --- QA5-01: building a station books its coins in the coin ledger ---------------------------
# Workshop.build raised stats.coins_spent and emitted coins_spent itself, past
# GameState.note_coins_spent – coin_ledger() never showed "build" (day summary / chapter panel).

func test_build_costs_go_into_the_coin_ledger() -> void:
	var before := GameState.coin_ledger()
	_stock({&"stone": 6, &"wood": 3})
	var site := world.get_node("Entities/site_mason") as BuildSite
	site.interact(player)
	site.request_build()
	UIState.clear()
	assert_true(shop.is_built(&"mason"), "built")
	var ledger := GameState.coin_ledger()
	assert_eq(int(ledger.get(&"build", 0)) - int(before.get(&"build", 0)), 15, "build 15 in the ledger (%s)" % str(ledger))
	var sum := 0
	for reason: StringName in ledger:
		sum += int(ledger[reason])
	assert_eq(GameState.get_stat(&"coins_spent"), sum, "stats.coins_spent = sum of the ledger")


# --- QA5-02: carving takes the material all or nothing ----------------------------------------
# Stonemasonry.carve removed item by item; a removal failing midway left the earlier items taken
# (and raised an engine error).

func test_carve_takes_the_material_atomically() -> void:
	var grave_id := _plain_grave()
	var inv := StubbornInventory.new()
	inv.add_item(&"stone", 4)
	inv.add_item(&"ink", 1)
	inv.stubborn = &"ink"
	var d := _design(&"stone_stele", &"i_rest")
	assert_eq(masonry.order_block_reason(grave_id, d, inv), "", "setup: enough material")
	assert_eq(masonry.carve(grave_id, d, inv), "", "refused")
	assert_eq([inv.count(&"stone"), inv.count(&"ink")], [4, 1], "nothing taken")
	assert_true(masonry.ready_stones().is_empty(), "no stone in the rack")
	inv.free()


# --- Prüfung: carving from the panel – the material only at the end, not cancellable, a load
# mid-carve leaves no stone behind, saving is refused while the chisel works ----------------------

func test_carve_from_the_panel_is_robust() -> void:
	var grave_id := _plain_grave()
	_stock({&"stone": 6, &"wood": 3})
	_build(&"mason")
	_stock({&"stone": 4, &"ink": 1})
	assert_eq(SaveManager.save_game(SLOT), OK)
	var panel := _open_panel(grave_id, _design(&"stone_stele", &"i_rest"))
	player.instant_actions = false
	panel.carve()
	assert_true(player.is_busy(), "the chisel works")
	assert_eq(player.inventory.count(&"stone"), 4, "material taken only at the end")
	assert_false(SaveManager.can_save(), "no save mid-carve")
	Input.action_press(&"move_right", 1.0)
	for i: int in 5:
		await tree.physics_frame
	Input.action_release(&"move_right")
	assert_true(player.is_busy(), "walking does not cancel the carving")
	UIState.clear()
	assert_eq(await SaveManager.load_game(SLOT), OK, "load mid-carve")
	_bind()
	for i: int in 5:
		await tree.process_frame
	assert_false(player.is_busy())
	assert_true(masonry.ready_stones().is_empty(), "no stone appears after the load")
	assert_eq(player.inventory.count(&"stone"), 4, "the saved material")
	# Carved to the end: the material once.
	player.instant_actions = true
	panel = _open_panel(grave_id, _design(&"stone_stele", &"i_rest"))
	panel.carve()
	UIState.clear()
	assert_eq(masonry.ready_stones().size(), 1, "one stone")
	assert_eq([player.inventory.count(&"stone"), player.inventory.count(&"ink")], [0, 0], "taken once")


# --- QA5-03: a stone set on a grave clamped at quality 0 is no failure -------------------------
# GravePlot judged the set by the quality difference: a robbed, rotten corpse stays at quality 0
# with the better stone – the stone was set, but „Der Stein passt hier nicht mehr." appeared.

func test_setting_a_stone_on_a_clamped_grave_reports_no_failure() -> void:
	var grave_id := _plain_grave()
	var grave := graveyard.get_grave(grave_id)
	var corpse := world.corpse_manager.get_record(grave.corpse_id)
	corpse.washed = false
	corpse.laid_out = false
	corpse.examined = false
	corpse.dress = CorpseRecord.DRESS_NONE
	corpse.shrouded = false
	corpse.freshness_at_burial = 0.05
	corpse.valuables_decision = CorpseRecord.DECISION_TAKEN
	corpse.harvested.assign([CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH])
	grave.marker_id = &"wooden_cross"
	grave.quality = GraveQuality.compute(corpse, &"wooden_cross", graveyard.economy)
	assert_eq(grave.quality, 0, "setup: clamped at 0")
	var inv := FakeInventory.new()
	inv.add_item(&"stone", 4)
	var order := masonry.carve(grave_id, _design(&"stone_stele", &""), inv)
	inv.free()
	assert_ne(order, "", "carved")
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	assert_true(plot.has_stone_to_set())
	notes.clear()
	plot.interact(player)
	assert_eq(StoneDesign.from_dict(graveyard.get_grave(grave_id).design).shape, &"stone_stele", "the stone stands")
	assert_false(GravePlot.TEXT_CANNOT_SET_STONE in notes, "no failure note (%s)" % str(notes))


# --- QA5-04: a lower tool next to a better one announces no tier -------------------------------

func test_lower_tool_announces_no_tier_change() -> void:
	_stock({&"stone": 10, &"clay": 6, &"iron_fittings": 2})
	_build(&"forge")
	player.inventory.add_item(&"shovel_master", 1)
	assert_eq(player.tool_tier(&"shovel"), 2)
	_stock({&"iron_fittings": 2, &"wood": 1})
	var tiers: Array = []
	var on_tier := func(kind: StringName, tier: int) -> void: tiers.append([kind, tier])
	EventBus.tool_tier_changed.connect(on_tier)
	notes.clear()
	var forge := world.get_node("Entities/station_forge") as Workbench
	forge.interact(player)
	UIState.clear()
	forge.request_craft(&"shovel_iron")
	EventBus.tool_tier_changed.disconnect(on_tier)
	assert_eq(player.inventory.count(&"shovel_iron"), 1, "crafted")
	assert_eq(player.tool_tier(&"shovel"), 2, "still the master shovel")
	assert_eq(tiers, [], "no tool_tier_changed")
	for n: String in notes:
		assert_false(n.contains("dauert jetzt"), "no 'faster' note: %s" % n)


# --- Prüfung: the master stone's reputation comes once per grave --------------------------------

func test_master_stone_reputation_once_per_grave() -> void:
	var grave_id := _plain_grave()
	(world.get_node("Systems/Reputation") as Reputation).change(-20, "QA setup")  # room below 100
	var events := {"n": 0}
	var on_rep := func(_v: int, _t: StringName, _d: int, reason: String) -> void:
		if reason == Graveyard.REASON_MASTER_STONE:
			events.n += 1
	EventBus.reputation_changed.connect(on_rep)
	var inv := FakeInventory.new()
	_fill(inv, {&"workstone": 6, &"stone": 4, &"iron_fittings": 4, &"clay": 2, &"ink": 1, &"gold_leaf": 1})
	var plot := world.get_node_by_layout_id(grave_id) as GravePlot
	assert_ne(masonry.carve(grave_id, _design(&"stone_master", &""), inv), "")
	plot.interact(player)
	var d := _design(&"stone_master", &"i_rest")
	d.gilded = true
	d.ornament = &"orn_ivy"
	assert_ne(masonry.carve(grave_id, d, inv), "", "a better master stone")
	plot.interact(player)
	EventBus.reputation_changed.disconnect(on_rep)
	inv.free()
	assert_eq(StoneDesign.from_dict(graveyard.get_grave(grave_id).design).gilded, true)
	assert_eq(events.n, 1, "master_stone once for the grave")


# --- Prüfung: kiln – save while ready, collect, load: no second batch ---------------------------

func test_kiln_collect_and_load_do_not_duplicate() -> void:
	_stock({&"stone": 10, &"clay": 6, &"iron_fittings": 2, &"wood": 4})
	_build(&"forge")
	var forge := world.get_node("Entities/station_forge") as Workbench
	forge.interact(player)
	UIState.clear()
	forge.request_craft(&"charcoal")
	assert_false(shop.job_of(&"forge").is_empty(), "the kiln burns")
	TimeManager.advance(481)
	assert_true(bool(shop.job_of(&"forge").ready))
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	forge.interact(player)
	assert_eq(player.inventory.count(&"charcoal"), 3, "collected")
	forge.interact(player)
	assert_eq(player.inventory.count(&"charcoal"), 3, "only once")
	UIState.clear()
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	assert_eq(player.inventory.count(&"charcoal"), 0, "the save before collecting")
	forge = world.get_node("Entities/station_forge") as Workbench
	forge.interact(player)
	assert_eq(player.inventory.count(&"charcoal"), 3, "the job is collected once from the save")
	assert_true(shop.job_of(&"forge").is_empty())


# --- Prüfung: regrowth over sleep and time skips – full once, never more -------------------------

func test_regrowth_over_sleep_and_skips_is_capped() -> void:
	var gathering := world.get_node("Systems/Gathering") as GatherManager
	GameState.set_flag(&"bruch_license", true)
	expansion.unlock(&"bruch")
	var clay := world.get_node("Entities/gather_clay_1") as GatherNode
	for i: int in 3:
		clay.interact(player)
	assert_eq(gathering.charges("gather_clay_1"), 0)
	assert_eq(player.inventory.count(&"clay"), 6)
	TimeManager.set_time(TimeManager.day + 3, 420)
	assert_eq(gathering.charges("gather_clay_1"), 3, "full after the skip, not 9")
	UIState.clear()
	assert_eq(SaveManager.save_game(SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	gathering = world.get_node("Systems/Gathering") as GatherManager
	assert_eq(gathering.charges("gather_clay_1"), 3, "a load on the same day adds nothing")


# --- Prüfung: Am Bruch and the quarry – nobody gets trapped --------------------------------------
# Flood fill with the gravekeeper's capsule from inside the Ostpforte: before the boulders are
# broken the Bruch nodes and tp_bruch are reachable; afterwards also every quarry node and tp_quarry.
# The fill is symmetric: every spot reached leads back to the Ostpforte.

func test_am_bruch_and_quarry_are_never_a_trap() -> void:
	GameState.set_flag(&"bruch_license", true)
	assert_true(expansion.clear("obs_b_gate", player.inventory))
	for i: int in 3:
		await tree.physics_frame
	var area := Rect2(21.0, -12.5, 11.0, 22.6)
	var reached := _flood(Vector2(22.4, 0.0), 0.25, area)
	for id: String in ["gather_clay_1", "gather_flax_1", "gather_flax_2", "gather_flax_3", "gather_herbs_1", "gather_herbs_2"]:
		assert_true(_near(reached, _pos(id), 1.6), "%s reachable" % id)
	assert_true(_near(reached, _v(world.get_waypoint(&"tp_bruch")), 0.5), "tp_bruch reachable")
	player.inventory.add_item(&"pickaxe_iron", 1)
	for k: int in [1, 2, 3]:
		assert_true(expansion.clear("obs_q_boulder_%d" % k, player.inventory), "boulder %d broken" % k)
	for i: int in 3:
		await tree.physics_frame
	reached = _flood(Vector2(22.4, 0.0), 0.25, area)
	for id: String in ["gather_ore_1", "gather_rubble_1", "gather_workstone_1", "gather_workstone_2"]:
		assert_true(_near(reached, _pos(id), 1.6), "%s reachable once the boulders are gone" % id)
	assert_true(_near(reached, _v(world.get_waypoint(&"tp_quarry")), 0.5), "tp_quarry reachable")


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	shop = world.get_node("Systems/Workshop") as Workshop
	masonry = world.get_node("Systems/Stonemasonry") as Stonemasonry
	TimeManager.running = false


func _stock(items: Dictionary) -> void:
	for id: StringName in items:
		var have := player.inventory.count(id)
		if have < int(items[id]):
			player.inventory.add_item(id, int(items[id]) - have)


func _fill(inv: Inventory, items: Dictionary) -> void:
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))


func _build(station: StringName) -> void:
	var site := world.get_node("Entities/site_" + String(station)) as BuildSite
	site.interact(player)
	site.request_build()
	UIState.clear()
	assert_true(shop.is_built(station), "%s built" % station)


func _design(shape: StringName, inscription: StringName) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = shape
	d.inscription = inscription
	return d


## A MARKED grave with a plain marker and a known corpse.
func _plain_grave() -> String:
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.MARKED and g.design.is_empty() and g.corpse_id != "":
			return g.id
	fail("no plain grave")
	return ""


func _open_panel(grave_id: String, d: StoneDesign) -> StoneDesignPanel:
	var bench := world.get_node("Entities/station_mason") as Workbench
	bench.interact(player)
	var panel := (world.get_node("UI") as UIRoot).get_panel(&"stone_design") as StoneDesignPanel
	panel.select_grave(grave_id, false)
	panel.select_shape(d.shape)
	panel.select_inscription(d.inscription)
	panel.select_ornament(d.ornament)
	panel.set_gilded(d.gilded)
	assert_eq(panel.block_reason(), "", "the panel allows the stone")
	return panel


func _capsule_free(p: Vector2) -> bool:
	var capsule := player.get_node("Collision") as CollisionShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule.shape
	q.collision_mask = Player.WORLD_MASK
	q.exclude = [player.get_rid(), world.get_node("GroundCollision").get_rid()]
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, world.ground_height(p) + 0.1, p.y)) * capsule.transform
	return world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _flood(start: Vector2, step: float, area: Rect2) -> Dictionary:
	var first := Vector2i(roundi(start.x / step), roundi(start.y / step))
	var seen := {first: true}
	var queue: Array[Vector2i] = [first]
	var reached := {}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		var p := Vector2(c) * step
		if not area.has_point(p) or not _capsule_free(p):
			continue
		reached[c] = p
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return reached


func _near(reached: Dictionary, t: Vector2, d: float) -> bool:
	for key: Vector2i in reached:
		if (reached[key] as Vector2).distance_to(t) <= d:
			return true
	return false


func _pos(id: String) -> Vector2:
	var node := world.get_node("Entities/" + id) as Node3D
	return Vector2(node.global_position.x, node.global_position.z)


static func _v(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)
