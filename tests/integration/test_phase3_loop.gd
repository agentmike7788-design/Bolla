extends TestCase
## W-Welt (docs/PHASE3_DESIGN.md §10): the Phase-3 loop on the real world through SaveManager.
## New game (reputation 25, six weedy spots in the old yard) → instant actions → six graves by
## helper → clear / repair the whole Ostwiese through the obstacles' interact() → plots 07–09
## EMPTY, the next delivery → burial on plot_07 → rake, bench and flower bed at the workbench →
## placed in build mode → cemetery quality = graves + decor − dirt (from the systems) → 7 days
## later the penalty has grown → tending → 21:30 ghosts eligible / active with the expected
## mood → listening → the gift → Birkenhang and the last graves → cemetery_complete.
## collect_state() is identical after save_game / load_game at four moments: while clearing,
## in build mode, at night with ghosts and after the phase end.

const TIMEOUT := 240.0
const SLOT := 91
## Real minutes of the clearing work (§2.1): east 330.
const EAST_MINUTES := 330

var saves_dir := TestCase.user_dir("test_saves_p3_loop")
var world: WorldRoot
var player: Player
var graveyard: Graveyard
var manager: CorpseManager
var expansion: ExpansionManager
var clean: CleanlinessManager
var decorations: DecorationManager
var build: BuildMode
var score: CemeteryScore
var rep: Reputation
var ghosts: GhostManager
var completed: Array = []


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	completed.clear()
	EventBus.cemetery_completed.connect(_on_completed)
	await SaveManager.new_game()
	_bind()
	TimeManager.running = false


func after_each() -> void:
	EventBus.cemetery_completed.disconnect(_on_completed)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func test_new_game_start_state() -> void:
	assert_eq(rep.value(), 25, "§2.6 new game: reputation 25")
	assert_eq(rep.tier(), &"unremarkable")
	assert_eq(GameState.get_stat(&"reputation"), 25)
	var weedy: PackedStringArray = []
	for id: String in clean.spot_ids():
		var lvl := clean.level(id)
		if lvl > 0:
			weedy.append(id)
			assert_true(lvl == 1 or lvl == 2, "%s level %d" % [id, lvl])
			var spot := world.get_node("Entities/" + id) as DirtSpot
			assert_eq(spot.section_id, &"yard", id)
			assert_eq(spot.shown_level, lvl, id + " shows its level")
	assert_eq(weedy.size(), 6, "§1.3 day 1: six spots in the old yard (%s)" % [weedy])
	assert_eq(clean.penalty(), 2, "levels 1,1,1,1,2,2 → penalty 0+0+0+0+1+1")
	assert_eq(score.total(), 0, "no graves yet (never below 0)")
	for id: String in ["plot_07", "plot_08", "plot_09", "plot_10", "plot_11", "plot_12"]:
		assert_eq(graveyard.get_grave(id).state, GraveRecord.State.LOCKED, id)
	assert_eq(graveyard.free_plot_count(), 6)
	assert_eq(expansion.progress(&"east"), Vector2i(0, 10))
	var board := world.get_node("Entities/notice_board") as NoticeBoard
	assert_true(board.label.text.contains("Ruf: Unauffällig"), board.label.text)


func test_full_phase3_loop_with_round_trips() -> void:
	var inv := player.inventory
	# --- the old yard fills up (helper: real Graveyard API) --------------------------------
	for i: int in range(1, 7):
		_complete_grave("plot_%02d" % i, &"gravestone_simple")
	assert_eq(graveyard.free_plot_count(), 0, "old yard full")
	# --- Ostwiese: every obstacle through its interact() -----------------------------------
	inv.add_item(&"wood", 6)
	inv.add_item(&"iron_fittings", 3)
	var ids := expansion.obstacle_ids(&"east")
	assert_eq(ids.size(), 10)
	var start_total := TimeManager.total_minutes()
	var half := 0
	for id: String in ids:
		var node := expansion.obstacle(id)
		assert_true(node.can_interact(player), "%s: %s" % [id, node.get_interaction_prompt(player)])
		node.interact(player)
		assert_true(expansion.is_cleared(id), id + " cleared")
		half += 1
		if half == 5:
			# Round trip 1: in the middle of the clearing.
			await _round_trip("while clearing")
			inv = player.inventory
			assert_eq(expansion.progress(&"east"), Vector2i(5, 10))
			assert_true(world.get_node("Decor/Overgrowth/east").visible, "overgrowth until the section is free")
	assert_eq(TimeManager.total_minutes() - start_total, EAST_MINUTES, "§2.1: 330 minutes of work")
	assert_true(expansion.is_unlocked(&"east"), "the last obstacle unlocks the Ostwiese")
	assert_false(world.get_node("Decor/Overgrowth/east").visible, "overgrowth gone")
	for id: String in ["plot_07", "plot_08", "plot_09"]:
		assert_eq(graveyard.get_grave(id).state, GraveRecord.State.EMPTY, id)
	assert_eq(inv.count(&"iron_fittings"), 0)
	assert_eq(inv.count(&"stone"), 6, "§2.1 yield: 6 stone")
	# --- next morning: a delivery, buried on plot_07 through the real entities ------------
	var tables := Database.corpse_tables() as CorpseTables
	TimeManager.set_time(TimeManager.day + 1, tables.delivery_minute)
	var record := _record_at(CorpseRecord.LOCATION_DROPOFF)
	assert_not_null(record, "delivery once plots are free")
	if record == null:
		return
	var table := world.get_node_by_layout_id("morgue_table") as MorgueTable
	manager.get_corpse_node(record.id).interact(player)
	table.interact(player)
	table.request_examine()
	if record.needs_valuables_decision():
		table.decide_valuables(false)
	inv.add_item(&"shroud", 1)
	table.request_shroud()
	var plot := world.get_node_by_layout_id("plot_07") as GravePlot
	plot.interact(player)
	table.request_pick_up()
	plot.interact(player)
	inv.add_item(&"gravestone_simple", 1)
	plot.interact(player)
	assert_eq(graveyard.get_grave("plot_07").state, GraveRecord.State.MARKED, "burial on plot_07")
	# --- workbench: rake, bench, flower bed -------------------------------------------------
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	inv.add_item(&"wood", 3 + 4 + 1)
	inv.add_item(&"seeds", 2)
	for recipe: StringName in [&"rake", &"decor_bench_wood", &"decor_flowerbed"]:
		bench.request_craft(recipe)
	assert_eq([inv.count(&"rake"), inv.count(&"decor_bench_wood"), inv.count(&"decor_flowerbed")], [1, 1, 1])
	# --- build mode (keyboard fallback: the cell in front of the gravekeeper) ---------------
	player.global_position = _ground_point(Vector2(16.5, 1.0))
	player.rotation.y = 0.0
	assert_true(build.enter(), "build mode outdoors with free hands")
	build.select(&"decor_bench_wood")
	assert_eq(build.cursor_reason(), &"ok", "bench cell in front of the gravekeeper")
	assert_true(build.confirm_place())
	# Round trip 2: in build mode (not saved – loading ends it).
	await _round_trip("in build mode")
	inv = player.inventory
	assert_false(build.active, "loading ends build mode")
	player.global_position = _ground_point(Vector2(19.0, 6.0))
	player.rotation.y = 0.0
	assert_true(build.enter())
	build.select(&"decor_flowerbed")
	assert_eq(build.cursor_reason(), &"ok", "flower bed cell")
	assert_true(build.confirm_place())
	build.exit()
	assert_eq(decorations.placements().size(), 2)
	assert_eq(decorations.decor_score(), 3 + 2, "bench 3 + flower bed 2 (Ostwiese cap 9)")
	_assert_quality("after decorating")
	# --- a week without tending --------------------------------------------------------------
	var penalty_before := clean.penalty()
	TimeManager.advance(7 * 1440)
	assert_true(clean.penalty() > penalty_before, "penalty grew (%d → %d)" % [penalty_before, clean.penalty()])
	assert_true(clean.dirty_count() > 0)
	_assert_quality("after a week")
	for id: String in clean.spot_ids():
		if clean.level(id) > 0:
			var spot := world.get_node("Entities/" + id) as DirtSpot
			assert_true(spot.can_interact(player), id + " can be tended (rake for leaves)")
			spot.interact(player)
	assert_eq(clean.penalty(), 0, "everything tended")
	_assert_quality("after tending")
	# --- night: ghosts --------------------------------------------------------------------------
	TimeManager.set_time(TimeManager.day, 1305)  # 21:45
	await wait_frames(3)
	ghosts.reselect()
	var eligible := ghosts.eligible_graves()
	assert_eq(eligible.size(), 7, "every MARKED grave of an earlier day walks (%s)" % [eligible])
	assert_eq(ghosts.active_ghosts().size(), 6, "at most 6 at once")
	var content := ""
	for g: Ghost in ghosts.active_ghosts():
		var grave := graveyard.get_grave(g.grave_id)
		var dirt := clean.level("dirt_" + g.grave_id)
		var plot_node := world.get_node_by_layout_id(g.grave_id) as Node3D
		var bonus := decorations.ghost_bonus_at(Vector2(plot_node.global_position.x, plot_node.global_position.z))
		var want := GhostMood.mood(GhostMood.score(grave.quality, dirt, bonus, Database.config(&"cleanliness_config") as CleanlinessConfig,
				Database.config(&"ghost_config") as GhostConfig), Database.config(&"ghost_config") as GhostConfig)
		assert_eq(g.mood, want, g.grave_id + " mood from grave, dirt and decor")
		assert_eq(ghosts.mood_of(g.grave_id), want)
		if want == GhostMood.CONTENT and content == "":
			content = g.grave_id
	assert_ne(content, "", "a tended stone grave with shroud is content")
	var coins := inv.count(&"coin")
	var text := ghosts.listen(content, player)
	assert_ne(text, "", "the ghost speaks")
	assert_eq(inv.count(&"coin"), coins + 2, "§2.8 gift: two coins")
	ghosts.listen(content, player)
	assert_eq(inv.count(&"coin"), coins + 2, "the gift only once")
	assert_true(GameState.has_flag(&"ghosts_seen"))
	# Round trip 3: at night with ghosts.
	await _round_trip("at night with ghosts")
	inv = player.inventory
	assert_true(ghosts.gift_given(content), "gift survives the load")
	# --- Birkenhang and the last graves → phase end --------------------------------------------
	assert_true(score.total() >= 50, "7 good graves + decor reach „Würdevoll“ (%d)" % score.total())
	assert_eq(expansion.block_reason(&"north"), "", "Birkenhang workable")
	inv.add_item(&"wood", 6)
	inv.add_item(&"iron_fittings", 3)
	for id: String in expansion.obstacle_ids(&"north"):
		var node := expansion.obstacle(id)
		assert_true(node.can_interact(player), "%s: %s" % [id, node.get_interaction_prompt(player)])
		node.interact(player)
	assert_true(expansion.is_unlocked(&"north"), "the last obstacle unlocks the Birkenhang")
	assert_false(world.get_node("Decor/Overgrowth/north").visible)
	for g: GraveRecord in graveyard.graves():
		if g.state == GraveRecord.State.EMPTY:
			_complete_grave(g.id, &"gravestone_simple")
	assert_true(GameState.has_flag(&"cemetery_complete"), "all 12 graves marked")
	assert_eq(completed.size(), 1, "cemetery_completed once")
	_assert_quality("at the end")
	UIState.clear()
	# Round trip 4: after the phase end.
	await _round_trip("after the phase end")
	assert_true(GameState.has_flag(&"cemetery_complete"))
	assert_true(expansion.is_unlocked(&"east") and expansion.is_unlocked(&"north"))


# --- helpers ----------------------------------------------------------------------------------

func _bind() -> void:
	world = tree.current_scene as WorldRoot
	player = world.get_player()
	player.instant_actions = true
	graveyard = world.graveyard
	manager = world.corpse_manager
	expansion = world.get_node("Systems/Expansion") as ExpansionManager
	clean = world.get_node("Systems/Cleanliness") as CleanlinessManager
	decorations = world.get_node("Systems/Decorations") as DecorationManager
	build = world.get_node("Systems/BuildMode") as BuildMode
	score = world.get_node("Systems/CemeteryScore") as CemeteryScore
	rep = world.get_node("Systems/Reputation") as Reputation
	ghosts = world.get_node("Systems/Ghosts") as GhostManager


## Save → load → identical collect_state(); rebinds the new world.
func _round_trip(moment: String) -> void:
	UIState.clear()
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(SLOT), OK, moment + ": saved")
	var err: Error = await SaveManager.load_game(SLOT)
	assert_eq(err, OK, moment + ": loaded")
	_bind()
	TimeManager.running = false
	assert_eq(SaveManager.collect_state(), before, moment + ": collect_state identical after save → load")
	assert_eq(world.get_node("Decor/Overgrowth/east").visible, not expansion.is_unlocked(&"east"), moment + ": overgrowth")


## Cemetery quality exactly from the systems: max(0, graves + decor − dirt).
func _assert_quality(moment: String) -> void:
	var want := maxi(0, graveyard.total_quality() + decorations.decor_score() - clean.penalty())
	assert_eq(score.total(), want, moment + ": quality = graves + decor − dirt")
	var b := score.breakdown()
	assert_eq([b.graves, b.decor, b.dirt, b.total], [graveyard.total_quality(), decorations.decor_score(), clean.penalty(), want], moment)


## A fresh, examined, shrouded corpse buried in `grave_id` with `marker` (real Graveyard API).
func _complete_grave(grave_id: String, marker: StringName) -> void:
	var plot := world.get_node_by_layout_id(grave_id) as Node3D
	var record := manager.spawn_corpse(null, plot.global_transform, &"ground")
	record.examined = true
	record.shrouded = true
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(graveyard.dig(grave_id), grave_id + " dug")
	assert_true(graveyard.bury(grave_id, record.id), grave_id + " buried")
	player.inventory.add_item(marker, 1)
	assert_true(graveyard.place_marker(grave_id, marker, player.inventory) >= 0)
	assert_eq(graveyard.get_grave(grave_id).state, GraveRecord.State.MARKED, grave_id + " marked")


func _record_at(location: StringName) -> CorpseRecord:
	for r: CorpseRecord in manager.records():
		if r.location == location:
			return r
	return null


func _ground_point(p: Vector2) -> Vector3:
	return Vector3(p.x, world.ground_height(p), p.y)


func _on_completed() -> void:
	completed.append(true)
