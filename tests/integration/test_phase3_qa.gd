extends TestCase
## W3 QA regressions of the Phase-3 review (docs/reviews/phase3_wip/qa_playthrough.md,
## "Befunde"): each test failed before its fix. Runs on the real graveyard world.

const TIMEOUT := 120.0
const SLOT := 93

var saves_dir := TestCase.user_dir("test_saves_p3_qa")
var bot: Phase3Bot


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	await SaveManager.new_game()
	bot = Phase3Bot.new(&"diligent", tree)
	bot.bind()


func after_each() -> void:
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


# --- QA-01: day summary / register show the cemetery quality (not graves only) ------------

func test_bed_day_summary_reports_cemetery_quality() -> void:
	_complete("plot_01", &"gravestone_simple")
	bot.expansion.unlock(&"east")
	bot.decorations.free_build = true
	assert_ne(bot.decorations.place(&"decor_bench_wood", _free_cell(&"decor_bench_wood", Vector2(16.0, 2.0)), 0, null), "")
	assert_ne(bot.score.total(), bot.graveyard.total_quality(), "setup: decor and dirt change the quality")
	var bed := tree.get_first_node_in_group(HutInterior.HUT_GROUP).get_node("Entities/bed") as Bed
	var summary := bed.day_summary(bot.player)
	assert_eq(summary.total, bot.score.total(), "day summary = CemeteryScore (graves + decor − dirt)")
	assert_eq(summary.rating, bot.score.rating())


func test_desk_register_reports_cemetery_quality() -> void:
	_complete("plot_01", &"gravestone_simple")
	var desk := tree.get_first_node_in_group(HutInterior.HUT_GROUP).get_node("Entities/desk") as Desk
	var ctx := desk.register_context()
	assert_eq(ctx.total, bot.score.total(), "register footer = CemeteryScore")


# --- QA-02: register column „Stimmung“ (only after listening, §7) --------------------------

func test_register_mood_after_listening() -> void:
	_complete("plot_01", &"gravestone_simple")
	var desk := tree.get_first_node_in_group(HutInterior.HUT_GROUP).get_node("Entities/desk") as Desk
	var entry: Dictionary = desk.register_context().entries[0]
	assert_eq(str(entry.get("mood", "")), "", "not heard yet")
	TimeManager.set_time(TimeManager.day + 1, 1305)
	bot.ghosts.listen("plot_01", bot.player)
	entry = desk.register_context().entries[0]
	assert_eq(entry.mood, GhostMood.label(bot.ghosts.mood_of("plot_01")))
	var cells := GraveRegisterPanel.cells(entry)
	assert_eq(cells.size(), GraveRegisterPanel.COLUMNS.size())
	assert_eq(cells[cells.size() - 1], entry.mood)


# --- QA-03: debug tp east|north uses the layout waypoints ---------------------------------

func test_debug_tp_uses_section_waypoints() -> void:
	for id: String in ["east", "north"]:
		var r: Dictionary = Debug.execute("tp " + id)
		assert_true(r.ok, r.text)
		var want := bot.world.get_waypoint(StringName("tp_" + id))
		var p := bot.player.global_position
		assert_true(Vector2(p.x - want.x, p.z - want.z).length() < 0.05, "%s: %s vs waypoint %s" % [id, p, want])


# --- QA-04: a grave finished after 21:00 walks only the next night – also after a load ------

func test_late_grave_ghost_survives_load() -> void:
	TimeManager.set_time(1, 1270)
	_complete("plot_01", &"wooden_cross")
	TimeManager.set_time(1, 1300)
	assert_eq(bot.ghosts.eligible_graves(), PackedStringArray(), "finished 21:10 → not tonight")
	assert_eq(SaveManager.save_game(SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	bot.bind()
	assert_eq(bot.ghosts.eligible_graves(), PackedStringArray(), "still not tonight after loading")
	TimeManager.set_time(2, 1300)
	assert_eq(bot.ghosts.eligible_graves(), PackedStringArray(["plot_01"]), "next night it walks")


# --- QA-05: a section whose obstacles are all cleared cannot stay locked (post_load) --------

func test_all_cleared_section_unlocks_on_load() -> void:
	var state := SaveManager.collect_state()
	state.nodes.expansion = {"cleared": Array(bot.expansion.obstacle_ids(&"east")), "unlocked": []}
	SaveManager.apply_state(state)  # warns: repaired
	assert_true(bot.expansion.is_unlocked(&"east"), "no softlock: nothing left to clear")
	assert_eq(bot.graveyard.get_grave("plot_07").state, GraveRecord.State.EMPTY)


# --- QA-06: decor over weeds -----------------------------------------------------------------

func test_gravel_over_weeds_covers_them() -> void:
	var id := _weedy_spot()
	var spot := bot.world.get_node("Entities/" + id) as DirtSpot
	var cell := bot.decorations.mask.world_to_cell(Vector2(spot.global_position.x, spot.global_position.z))
	var penalty := bot.clean.penalty()
	var lvl := bot.clean.level(id)
	assert_true(lvl >= 2, "setup: %s level %d" % [id, lvl])
	bot.decorations.free_build = true
	var uid := bot.decorations.place(&"decor_path_gravel", cell, 0, null)
	assert_ne(uid, "")
	assert_eq(bot.clean.level(id), 0, "gravel covers the weeds (§2.3 unterdrückt Unkraut)")
	assert_eq(spot.shown_level, 0, "no weeds poking through the gravel")
	assert_eq(bot.clean.penalty(), penalty - 1, "no penalty for a covered spot")
	assert_eq(bot.score.total(), maxi(0, bot.graveyard.total_quality() + bot.decorations.decor_score() - bot.clean.penalty()))
	assert_true(bot.decorations.remove(uid, null))
	assert_eq(bot.clean.level(id), lvl, "the weeds were only covered")
	assert_eq(spot.shown_level, lvl)


func test_bench_refused_on_weeds() -> void:
	var id := _weedy_spot()
	var spot := bot.world.get_node("Entities/" + id) as DirtSpot
	var p := Vector2(spot.global_position.x, spot.global_position.z)
	var cell := bot.decorations.mask.world_to_cell(p)
	bot.decorations.free_build = true
	for rot: int in 2:
		var size := BuildGrid.rotated_size(Vector2i(3, 1), rot)
		for dz: int in size.y:
			for dx: int in size.x:
				var reason := bot.decorations.can_place(&"decor_bench_wood", cell - Vector2i(dx, dz), rot, null, null)
				assert_true(reason != BuildGrid.REASON_OK, "bench over %s (rot %d, %d/%d): %s" % [id, rot, dx, dz, reason])


# --- QA-11: weedy spots clear the grass under them (readability from the gameplay camera) ---

func test_weedy_spot_clears_the_grass_under_it() -> void:
	var grass := bot.world.get_node("Systems/GrassClearMask") as GrassClearMask
	var id := _weedy_spot()
	var spot := bot.world.get_node("Entities/" + id) as DirtSpot
	var p := Vector2(spot.global_position.x, spot.global_position.z)
	var mask := bot.decorations.mask
	var texel := mask.cell / GrassClearMask.TEXELS_PER_CELL
	var t := Vector2i(((p - mask.origin) / texel).floor())
	var w := mask.size.x * GrassClearMask.TEXELS_PER_CELL
	grass.repaint()
	assert_eq(grass.image.get_data()[t.y * w + t.x], 255, "level %d: no grass on the weeds" % bot.clean.level(id))
	bot.player.instant_actions = true
	spot.interact(bot.player)
	assert_eq(bot.clean.level(id), 0, "tended")
	assert_eq(grass.image.get_data()[t.y * w + t.x], 0, "the lawn grows back once tended (cleanliness_changed)")


# --- helpers ----------------------------------------------------------------------------------

func _weedy_spot() -> String:
	for id: String in bot.clean.spot_ids():
		if bot.clean.level(id) >= 2 and not id.begins_with("dirt_plot"):
			var spot := bot.world.get_node("Entities/" + id) as DirtSpot
			var c := bot.decorations.mask.world_to_cell(Vector2(spot.global_position.x, spot.global_position.z))
			if bot.decorations.mask.section_at(c) == 1:
				return id
	return ""


func _free_cell(decor_id: StringName, near: Vector2) -> Vector2i:
	var mask := bot.decorations.mask
	var c0 := mask.world_to_cell(near)
	for r: int in 12:
		for dz: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				var c := c0 + Vector2i(dx, dz)
				if bot.decorations.can_place(decor_id, c, 0, null, null) == BuildGrid.REASON_OK:
					return c
	return Vector2i(-1, -1)


## A fresh, examined, shrouded corpse buried in `grave_id` with `marker` (real Graveyard API).
func _complete(grave_id: String, marker: StringName) -> void:
	var plot := bot.world.get_node_by_layout_id(grave_id) as Node3D
	var record := bot.manager.spawn_corpse(null, plot.global_transform, &"ground")
	record.examined = true
	record.shrouded = true
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	bot.graveyard.dig(grave_id)
	bot.graveyard.bury(grave_id, record.id)
	bot.player.inventory.add_item(marker, 1)
	bot.graveyard.place_marker(grave_id, marker, bot.player.inventory)
