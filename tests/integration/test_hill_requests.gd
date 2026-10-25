extends TestCase
## G8 Runde 6 „Bitten vom Hügel" (docs/PHASE8_DESIGN.md G8 Runde 6) on the real world from a new game: Osric pins two
## requests at 07:44 of day 2 (nothing on day 1), the notice board at the gate shows slips and opens the docked panel
## (mouse and keyboard), two can be accepted before the village (one after village_open, with the longer refill), the
## accepted ones are the HUD objective and stand in the Merkbuch; every kind completes through the real systems / the
## EventBus and pays its small reward (Osric's cart for deliveries via carter.tres), a missed deadline costs −1, an
## unanswered one is taken down without consequence, a request comes back only after its cooldown; the Phase-7 chapter
## count („6 Aufträge von 4 Gebern") never sees them; the state survives save → load, and saves from before this round
## (v6 fixture) load without a warning and get their request on the next morning – no new save format.

const TIMEOUT := 400.0
const SLOT := 61

var saves_dir := TestCase.user_dir("test_saves_hill")
var world: WorldRoot
var hill: HillRequests
var player: Player
var notes: Array[String] = []
## Reputation changes / payments of the requests („Bitte: …“, „Bitte versäumt: …“) – the daily drift and the stipend
## run beside them when days pass.
var rep_hill: Array[int] = []
var pay_hill: Array[int] = []
var warnings := WarningLog.new()


class WarningLog extends Logger:
	var lines: PackedStringArray = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			return
		mutex.lock()
		lines.append("%s %s (%s:%d %s)" % [code, rationale, file.get_file(), line, function])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func before_each() -> void:
	SaveManager.save_dir = saves_dir
	notes.clear()
	rep_hill.clear()
	pay_hill.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.reputation_changed.connect(_on_rep)
	EventBus.payment_received.connect(_on_pay)
	OS.add_logger(warnings)
	warnings.lines.clear()
	await SaveManager.new_game()
	_bind()


func after_each() -> void:
	OS.remove_logger(warnings)
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.reputation_changed.disconnect(_on_rep)
	EventBus.payment_received.disconnect(_on_pay)
	UIState.clear()
	TestCase.remove_user_dir(saves_dir)


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


func _on_rep(_value: int, _tier: StringName, delta: int, reason: String) -> void:
	if reason.begins_with("Bitte"):
		rep_hill.append(delta)


func _on_pay(amount: int, reason: String) -> void:
	if reason.begins_with("Bitte"):
		pay_hill.append(amount)


func _bind() -> void:
	world = tree.current_scene as WorldRoot
	hill = world.get_node("Systems/HillRequests") as HillRequests
	player = world.get_player()
	TimeManager.running = false


func _ui() -> UIRoot:
	return world.get_node("UI") as UIRoot


func _board_node() -> NoticeBoard:
	return world.get_node("Entities/notice_board") as NoticeBoard


## Pins `id` on day 2 at 08:00 (no natural posting that day) and accepts it.
func _accepted(id: StringName, grave_id: String = "") -> void:
	if TimeManager.day < 2:
		TimeManager.set_time(2, 360)
	for other: StringName in hill.board():
		if hill.state(other) == HillRequests.STATE_OFFERED:
			hill.withdraw(other)
	assert_true(hill.pin(id, grave_id), "pin %s" % id)
	assert_true(hill.accept(id), "accept %s (%s)" % [id, hill.accept_reason(id)])


func _rep() -> int:
	return (world.get_node("Systems/Reputation") as Reputation).value()


func _coins() -> int:
	return player.inventory.count(&"coin")


func _complete_grave(grave_id: String, marker: StringName) -> CorpseRecord:
	var plot := world.get_node_by_layout_id(grave_id) as Node3D
	var record := world.corpse_manager.spawn_corpse(null, plot.global_transform, &"ground")
	record.examined = true
	record.shrouded = true
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(world.graveyard.dig(grave_id), grave_id + " dug")
	assert_true(world.graveyard.bury(grave_id, record.id), grave_id + " buried")
	player.inventory.add_item(marker, 1)
	assert_true(world.graveyard.place_marker(grave_id, marker, player.inventory) >= 0)
	return record


# --- posting, the board, the panel --------------------------------------------------------------

func test_osric_pins_two_requests_on_day_two() -> void:
	var board := _board_node()
	assert_eq(hill.board().size(), 0, "nothing on day 1")
	assert_false(board.can_interact(player), "day 1: the board shows only the rating")
	assert_eq(board.get_interaction_prompt(player), "")
	TimeManager.set_time(1, 600)
	assert_eq(hill.board().size(), 0, "day 1 stays empty")
	TimeManager.set_time(2, 463)
	assert_eq(hill.board().size(), 0, "not before 07:44")
	TimeManager.set_time(2, 464)
	assert_eq(hill.board().size(), 2, "two places before the village (%s)" % str(hill.board()))
	assert_has(notes, "Osric hat zwei Bitten ans Tor geheftet.")
	assert_eq(hill.offered().size(), 2)
	var givers := {}
	for id: StringName in hill.board():
		givers[hill.request_data(id).giver] = true
	assert_eq(givers.size(), 2, "two different givers")
	assert_eq(board.slip_count(), 2, "two slips on the board")
	assert_true(board.can_interact(player))
	assert_eq(board.get_interaction_prompt(player), "[E] Bitten am Tor lesen")
	TimeManager.set_time(2, 900)
	assert_eq(hill.board().size(), 2, "nothing more the same day")
	assert_eq(warnings.lines, PackedStringArray(), "no warnings")


func test_board_opens_the_docked_panel_mouse_and_keyboard() -> void:
	TimeManager.set_time(2, 470)
	var ui := _ui()
	await wait_frames(2)
	_board_node().interact(player)
	await wait_frames(3)
	assert_eq(ui.top(), &"hill_requests", "the board opens the request panel")
	var panel := ui.get_panel(&"hill_requests") as HillRequestsPanel
	assert_not_null(panel)
	var view := ui.get_viewport().get_visible_rect()
	var rect := panel.get_global_rect()
	var hud := ui.hud.resource_panel.get_global_rect()
	assert_true(panel.dock_right and panel.get_parent() is MarginContainer, "docked at the right edge")
	assert_almost(rect.end.x, view.end.x - UIRoot.DOCK_MARGIN, 1.0, "at the right edge")
	assert_true(rect.position.y >= hud.end.y + UIRoot.DOCK_GAP - 1.0, "below the HUD bar (%s / %s)" % [rect, hud])
	assert_false(rect.has_point(view.get_center()), "the middle of the screen stays free")
	assert_false(ui.dim.visible, "no dim")
	assert_eq(panel.cards.size(), 2, "one card per request")
	var first: StringName = hill.board()[0]
	var second: StringName = hill.board()[1]
	var focused := ui.get_viewport().gui_get_focus_owner()
	# W-UI Phase 9 (docs/PHASE9_DESIGN.md §2.3.4): from day 2 the large sheet is the first card – the keyboard starts there.
	for large: StringName in panel.large_ids():
		assert_eq(focused, panel.accept_button(large), "keyboard: the large sheet's „Annehmen“ first")
		panel.accept_button(first).grab_focus()
		focused = ui.get_viewport().gui_get_focus_owner()
		break
	assert_eq(focused, panel.accept_button(first), "keyboard: the first „Annehmen“ has the focus")
	_press(&"ui_accept")
	await wait_frames(2)
	assert_eq(hill.state(first), HillRequests.STATE_ACCEPTED, "Enter accepts the focused request")
	assert_has(notes, "Angenommen: %s" % hill.title_of(first))
	assert_eq(ui.get_viewport().gui_get_focus_owner(), panel.accept_button(second), "the focus moves on to the next")
	# mouse: a click on the second card's button
	var b := panel.accept_button(second)
	_click(b.get_global_rect().get_center())
	await wait_frames(2)
	assert_eq(hill.state(second), HillRequests.STATE_ACCEPTED, "a click accepts")
	assert_true(panel.count_label.text.begins_with("Angenommen: 2 von 2"), panel.count_label.text)
	_press(&"pause")
	await wait_frames(2)
	assert_ne(ui.top(), &"hill_requests", "Esc closes")
	# the HUD names the accepted request once the day's corpse work is done (the corpse chain comes first)
	var world_state := CemeteryStatus.objective_state(tree, player.inventory)
	var line := ObjectiveResolver.current([], world.graveyard.graves(), player.inventory, 720, GameState.flags, world_state)
	assert_eq(line, HillTexts.objective((world_state.hill.active as Array)[0]), "HUD objective (%s)" % line)
	assert_true(line.begins_with("Bitte: "), line)
	ui.hud.refresh_objective()
	assert_ne(ui.hud.objective_label.text, "", "the HUD line is set")
	ui.open_panel(&"journal", {"page": "requests"})
	await wait_frames(2)
	var journal := ui.get_panel(&"journal") as JournalPanel
	assert_true(&"requests" in journal.pages(), "the Merkbuch tab „Bitten“")
	assert_eq(journal.current_page, &"requests")
	var page := JournalPagesHill.page(tree)
	assert_eq((page.active as Array).size(), 2, "both accepted ones in the journal")


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		_ui().get_viewport().push_input(ev)


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		_ui().get_viewport().push_input(ev, true)


# --- limits, deadline, cooldown, village --------------------------------------------------------

func test_two_at_once_before_the_village_one_after() -> void:
	TimeManager.set_time(2, 470)
	var ids := hill.board()
	assert_true(hill.accept(ids[0]))
	assert_true(hill.accept(ids[1]), "two at once before the village")
	assert_eq(hill.active().size(), 2)
	GameState.set_flag(&"village_open", true)
	assert_eq(hill.max_active(), 1, "one after village_open")
	TimeManager.set_time(3, 470)
	assert_eq(hill.offered().size(), 0, "no free place: the two running ones fill it")
	hill.complete(ids[0])
	hill.complete(ids[1])
	assert_eq(hill.board().size(), 0)
	TimeManager.set_time(4, 470)
	assert_eq(hill.board().size(), 0, "after village_open the place waits three mornings (day 4)")
	TimeManager.set_time(5, 470)
	assert_eq(hill.board().size(), 0, "day 5")
	TimeManager.set_time(6, 470)
	assert_eq(hill.board().size(), 1, "day 6: one request (one place)")
	assert_has(notes, "Osric hat eine Bitte ans Tor geheftet.")


func test_deadline_costs_little_and_the_cooldown_holds() -> void:
	TimeManager.set_time(2, 470)
	var id: StringName = hill.board()[0]
	var other: StringName = hill.board()[1]
	var r := hill.request_data(id)
	assert_true(hill.accept(id))
	var due := hill.deadline_day(id)
	assert_eq(due, 2 + r.days_limit)
	TimeManager.set_time(due - 1, 1200)
	assert_eq(hill.state(id), HillRequests.STATE_ACCEPTED, "still running on its last day")
	TimeManager.set_time(due, 361)
	assert_eq(hill.state(id), &"", "missed at 06:00 of day %d" % due)
	assert_has(notes, HillTexts.FAILED % hill.title_of(id))
	assert_eq(rep_hill, [-1] as Array[int], "a missed request costs one reputation")
	assert_eq(pay_hill, [] as Array[int], "and no coins")
	assert_eq(hill.history().back().state, HillRequests.STATE_FAILED)
	# the unanswered one hung two days and went without consequence
	assert_ne(hill.state(other), HillRequests.STATE_OFFERED, "taken down after offer_days")
	# cooldown: neither comes back within its cooldown days
	for d: int in range(due, due + 4):
		TimeManager.set_time(d, 470)
		assert_false(hill.board().has(id), "day %d: %s cools down" % [d, id])
	assert_eq(warnings.lines, PackedStringArray(), "no warnings")


func test_offered_requests_are_taken_down_without_consequence() -> void:
	TimeManager.set_time(2, 470)
	var first := hill.board()
	TimeManager.set_time(4, 365)
	for id: StringName in first:
		assert_ne(hill.state(id), HillRequests.STATE_OFFERED, "%s taken down after two days" % id)
	assert_eq(rep_hill, [] as Array[int], "unanswered: no reputation lost")
	assert_eq(hill.history().size(), 0, "and no entry in the journal's log")
	TimeManager.set_time(4, 470)
	assert_eq(hill.board().size(), 2, "and two new ones the same morning")
	for id: StringName in hill.board():
		assert_false(id in first, "never the same again at once (%s)" % id)


# --- every kind ---------------------------------------------------------------------------------

func test_deliver_at_osrics_cart() -> void:
	_accepted(&"hr_osric_wood")
	var inv := player.inventory
	var ctx := {"inventory": inv, "speaker": null}
	inv.remove_item(&"wood", inv.count(&"wood"))
	assert_false(DialogueConditions.hill_ready(&"carter", ctx), "no wood yet")
	inv.add_item(&"wood", 5)
	assert_true(DialogueConditions.hill_ready(&"carter", ctx), "carter.tres: hill_ready:carter")
	var data := Database.dialogue(&"carter") as DialogueData
	var found := false
	for n: DialogueNode in data.nodes:
		for c: DialogueChoice in n.choices:
			if "hill_ready:carter" in c.conditions and "hill_turn_in:carter" in c.actions:
				found = true
	assert_true(found, "Osric's menu has the hand-over choice")
	var coins := _coins()
	var rep := _rep()
	DialogueActions.apply("hill_turn_in:carter", ctx)
	assert_eq(inv.count(&"wood"), 2, "three pieces of wood handed over")
	assert_eq(_coins(), coins + 2, "two coins")
	assert_eq(_rep(), rep + 1, "reputation +1")
	assert_eq(hill.state(&"hr_osric_wood"), &"", "done")
	assert_has(notes, HillTexts.reward_note(hill.request_data(&"hr_osric_wood").title, PackedStringArray(["2 Münzen", "Ruf +1"])))
	assert_has(notes, HillTexts.CARTER_HANDED)


func test_tend_spots_and_a_graves_spot() -> void:
	var clean := world.get_node("Systems/Cleanliness") as CleanlinessManager
	clean.set_level("dirt_y01", 2)
	clean.set_level("dirt_y02", 1)
	_accepted(&"hr_kehr_gate")
	var coins := _coins()
	assert_true(clean.tend("dirt_y01", player.inventory), "weed y01")
	assert_eq(hill.state(&"hr_kehr_gate"), HillRequests.STATE_ACCEPTED, "one spot still dirty")
	assert_true(clean.tend("dirt_y02", player.inventory), "weed y02")
	assert_eq(hill.state(&"hr_kehr_gate"), &"", "both clean → done")
	assert_eq(_coins(), coins + 2)
	# a grave's own spot (marked_dirty): the dead's name in title and thanks
	var rec := _complete_grave("plot_02", &"wooden_cross")
	clean.set_level("dirt_plot_02", 2)
	_accepted(&"hr_brandt_grave", "plot_02")
	assert_eq(hill.target_grave(&"hr_brandt_grave"), "plot_02")
	assert_true(hill.title_of(&"hr_brandt_grave").contains(rec.display_name), hill.title_of(&"hr_brandt_grave"))
	assert_true(clean.tend("dirt_plot_02", player.inventory), "tend the grave")
	assert_eq(hill.state(&"hr_brandt_grave"), &"", "done")
	assert_true(notes.any(func(t: String) -> bool: return t.contains(rec.display_name) and t.begins_with("Brandt")), "thanks name the dead")


func test_exam_prep_and_marker_with_the_dead() -> void:
	# exam: a dead examined thoroughly after the acceptance – the finding in the thanks
	_accepted(&"hr_quast_exam")
	var care := world.get_node("Systems/CorpseCare") as CorpseCare
	var table := world.corpse_manager.spawn_corpse(null, Transform3D.IDENTITY, &"table")
	care.exam_all_instant(table.id)
	assert_eq(hill.state(&"hr_quast_exam"), &"", "a full examination completes it")
	assert_true(notes.any(func(t: String) -> bool: return t.contains(table.display_name) and t.contains(Phase7Texts.cause_label(table.cause_id))),
			"the finding in the note")
	# prep: washed and dressed at the burial
	_accepted(&"hr_liesel_wash")
	var plot := world.get_node_by_layout_id("plot_03") as Node3D
	var r := world.corpse_manager.spawn_corpse(null, plot.global_transform, &"ground")
	r.examined = true
	if r.needs_valuables_decision():
		r.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(world.graveyard.dig("plot_03"))
	var linen := player.inventory.count(&"linen")
	assert_true(world.graveyard.bury("plot_03", r.id), "unwashed burial")
	assert_eq(hill.state(&"hr_liesel_wash"), HillRequests.STATE_ACCEPTED, "unwashed does not count")
	var r2 := world.corpse_manager.spawn_corpse(null, (world.get_node_by_layout_id("plot_04") as Node3D).global_transform, &"ground")
	r2.examined = true
	r2.washed = true
	r2.dress = CorpseRecord.DRESS_SHROUD
	r2.shrouded = true
	if r2.needs_valuables_decision():
		r2.valuables_decision = CorpseRecord.DECISION_LEFT
	assert_true(world.graveyard.dig("plot_04"))
	assert_true(world.graveyard.bury("plot_04", r2.id))
	assert_eq(hill.state(&"hr_liesel_wash"), &"", "washed and shrouded → done")
	assert_eq(player.inventory.count(&"linen"), linen + 1, "a piece of linen as thanks")
	# marker: a gravestone, not a cross
	_accepted(&"hr_lenz_stone")
	_complete_grave("plot_05", &"wooden_cross")
	assert_eq(hill.state(&"hr_lenz_stone"), HillRequests.STATE_ACCEPTED, "a cross is not enough")
	_complete_grave("plot_06", &"gravestone_simple")
	assert_eq(hill.state(&"hr_lenz_stone"), &"", "a gravestone → done")


func test_ghost_clear_and_decor() -> void:
	_complete_grave("plot_01", &"wooden_cross")
	_accepted(&"hr_ott_ghost")
	TimeManager.set_time(3, 1340)
	var ghosts := world.get_node("Systems/Ghosts") as GhostManager
	var text := ""
	for id: String in ghosts.eligible_graves():
		text = ghosts.listen(id, player)
		break
	assert_ne(text, "", "a ghost spoke")
	assert_eq(hill.state(&"hr_ott_ghost"), &"", "listening completes it")
	assert_true(notes.any(func(t: String) -> bool: return t.contains(text)), "its words in the note")
	# clear: an obstacle of the Ostwiese
	_accepted(&"hr_fenner_clear")
	var expansion := world.get_node("Systems/Expansion") as ExpansionManager
	player.inventory.add_item(&"wood", 6)
	player.inventory.add_item(&"iron_fittings", 2)
	var cleared := false
	for o: String in expansion.obstacle_ids(&"east"):
		if expansion.can_clear(o, player.inventory):
			cleared = expansion.clear(o, player.inventory)
			break
	assert_true(cleared, "an obstacle cleared")
	assert_eq(hill.state(&"hr_fenner_clear"), &"", "clearing completes it")
	# decor: the vase (DecorationManager's signal)
	_accepted(&"hr_esch_vase")
	EventBus.decor_changed.emit("d_test", &"decor_lantern", true)
	assert_eq(hill.state(&"hr_esch_vase"), HillRequests.STATE_ACCEPTED, "a lantern is no vase")
	EventBus.decor_changed.emit("d_test2", &"decor_grave_vase", false)
	assert_eq(hill.state(&"hr_esch_vase"), HillRequests.STATE_ACCEPTED, "a removed vase does not count")
	EventBus.decor_changed.emit("d_test3", &"decor_grave_vase", true)
	assert_eq(hill.state(&"hr_esch_vase"), &"", "a placed vase → done")


# --- the Phase-7 chapter, save / load ------------------------------------------------------------

func test_requests_never_count_for_the_village_chapter() -> void:
	GameState.set_flag(&"village_open", true)
	var orders := world.get_node("Systems/Orders") as Orders
	var done := orders.done_count()
	var givers := orders.done_givers().size()
	var stat := GameState.get_stat(&"orders_done")
	for id: StringName in [&"hr_osric_wood", &"hr_esch_stone", &"hr_rosine_wood", &"hr_fenner_stone"]:
		_accepted(id)
		hill.complete(id)
	assert_eq(hill.history().size(), 4, "four requests done")
	assert_eq(orders.done_count(), done, "„6 Aufträge von 4 Gebern“ does not see them")
	assert_eq(orders.done_givers().size(), givers)
	assert_eq(GameState.get_stat(&"orders_done"), stat, "stats.orders_done unchanged")
	assert_eq(orders.active_count(), 0, "no order limit used")
	for id: StringName in hill.history().map(func(e: Dictionary) -> StringName: return e.id):
		assert_null(orders.order_data(id), "%s is no order" % id)


func test_save_and_load_keep_the_board() -> void:
	TimeManager.set_time(2, 470)
	var ids := hill.board()
	assert_true(hill.accept(ids[0]))
	var clean := world.get_node("Systems/Cleanliness") as CleanlinessManager
	clean.set_level("dirt_y01", 2)
	var before := hill.save_state()
	assert_eq(SaveManager.save_game(SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	assert_eq(hill.save_state(), before, "save → load keeps the requests")
	assert_eq(hill.state(ids[0]), HillRequests.STATE_ACCEPTED)
	assert_eq(hill.state(ids[1]), HillRequests.STATE_OFFERED)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves_dir.path_join("slot_%d.json" % SLOT)))
	if not doc.is_empty():
		assert_eq(int(doc.format_version), SaveMigration.CURRENT, "no new format")
	assert_eq(SaveMigration.CURRENT, 9, "format v7 stayed in G8 Runde 6 (Phase 9 W0: v8, Phase 10 W0: v9)")
	assert_eq(_board_node().slip_count(), 2, "the slips after loading")
	assert_eq(warnings.lines, PackedStringArray(), "no warnings")


func test_old_save_without_requests_loads_silently_and_gets_one() -> void:
	assert_eq(Phase8Fixtures.install_save_v6("slot_p7_day53_neighbor", saves_dir, SLOT), OK)
	warnings.lines.clear()
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	assert_eq(warnings.lines, PackedStringArray(), "a v6 save loads without a warning (no state for hill_requests)")
	assert_eq(hill.board().size(), 0, "the default state")
	assert_true(GameState.flag_on(&"village_open"), "the village is open")
	TimeManager.set_time(53, 470)
	assert_eq(hill.board().size(), 1, "one request on the next morning (village rules)")
	assert_eq(SaveManager.save_game(SLOT + 1), OK)
	assert_eq(await SaveManager.load_game(SLOT + 1), OK)
	_bind()
	assert_eq(hill.board().size(), 1, "kept after the next save")


# --- Phase 9: larger requests (docs/PHASE9_DESIGN.md §2.3, P2) -------------------------------------------------

## Pins the large request `id` (day 2, 08:00, no other large one) and accepts it.
func _large_accepted(id: StringName) -> void:
	if TimeManager.day < 2:
		TimeManager.set_time(2, 480)
	for other: StringName in hill.large_offered():
		hill.withdraw(other)
	assert_true(hill.pin_large(id), "pin %s" % id)
	assert_true(hill.accept(id), "accept %s (%s)" % [id, hill.accept_reason(id)])


func test_large_sheet_at_the_gate_from_day_two() -> void:
	var board := _board_node()
	assert_eq(hill.large_board(&"gate"), [] as Array[StringName], "nothing on day 1")
	assert_false(board.sheet_visible())
	TimeManager.set_time(2, 464)
	assert_eq(hill.large_board(&"gate").size(), 1, "Osric pins one large sheet with the small ones")
	var id := hill.large_board(&"gate")[0]
	assert_true(board.sheet_visible(), "the folded sheet hangs at the board")
	assert_true(notes.any(func(t: String) -> bool: return t.begins_with("… und einen großen Bogen")), "HUD note")
	var ctx := board.panel_context(player)
	assert_eq([ctx.place, ctx.large], [&"gate", [id] as Array[StringName]], "the panel gets the sheet")
	var card: Dictionary = (ctx.large_cards as Array)[0]
	assert_eq(card.id, id)
	assert_true((card.parts as Array).size() >= 2 and card.reward.begins_with("Die Gemeinde wird es dir danken."), "card with parts")
	assert_eq(card.accept_reason, "")
	assert_eq(hill.large_waiting(), [&"gate"] as Array[StringName], "HUD: a large request waits")
	assert_true(hill.accept(id))
	assert_eq(hill.objective_state(player.inventory).large.size(), 1, "the HUD line of the running one")
	assert_eq(hill.board().size(), 2, "the small ones hang beside it")
	assert_eq(warnings.lines, PackedStringArray(), "no warnings")


func test_large_craft_at_the_workbench_and_osric_takes_it() -> void:
	_large_accepted(&"hrl_crosses")
	var bench := world.get_node_by_layout_id("workbench") as Workbench
	player.instant_actions = true
	player.inventory.add_item(&"wood", 9)
	for i: int in 3:
		bench.interact(player)
		UIState.clear()
		bench.request_craft(&"wooden_cross")
	assert_eq(hill.parts_done(&"hrl_crosses"), [true, false] as Array[bool], "craft_finished from the workbench")
	assert_has(notes, "Drei Kreuze für den Hohlweg: 1 von 2")
	var ctx := {"inventory": player.inventory, "speaker": null}
	# W3 QA-Fix QA9-05: the large delivery is large_ready's („für die große Bitte"), not hill_ready's.
	assert_false(DialogueConditions.hill_ready(&"carter", ctx), "carter.tres: hill_ready:carter only the small ones")
	assert_eq(DialogueConditions.large_ready(&"carter", ctx), [&"hrl_crosses"] as Array[StringName], "large_ready:carter")
	var lines := {}
	var carter := load("res://data/dialogue/carter.tres") as DialogueData
	for n: DialogueNode in carter.nodes:
		for c: DialogueChoice in n.choices:
			if c.text.begins_with("[Bitte]"):
				lines[c.text] = DialogueConditions.all_met(c.conditions, ctx)
	assert_eq(lines, {"[Bitte] Das hier ist für die große Bitte.": true, "[Bitte] Das hier ist für die Leute unten.": false},
			"Osric's line for the large request shows, the small one not")
	var coins := _coins()
	var rep := _rep()
	DialogueActions.apply("hill_turn_in:carter", ctx)
	var r := hill.large_data(&"hrl_crosses")
	assert_eq(_coins(), coins + r.reward_coins)
	assert_eq(_rep(), rep + r.reward_rep)
	assert_eq(hill.history().back().state, HillRequests.STATE_COMPLETED)
	assert_eq(player.inventory.count(&"wooden_cross"), 0, "the crosses went with Osric")
	assert_eq(GameState.get_stat(&"large_requests_done"), 1)
	assert_eq(GameState.get_stat(&"large_request_parts"), 2)


func test_large_gather_from_the_pile_and_the_evening_visit() -> void:
	_large_accepted(&"hrl_lantern_path")
	player.instant_actions = true
	TimeManager.set_time(2, 600)
	player.global_position = world.get_waypoint(&"gate_outside")
	assert_eq(hill.visit_block_reason(&"hrl_lantern_path", player), HillRules.TEXT_VISIT_WINDOW % ["21:30", "23:00"])
	TimeManager.set_time(2, 1295)
	player.global_position = world.get_waypoint(&"gate_outside") + Vector3(6, 0, 0)
	assert_eq(hill.visit_block_reason(&"hrl_lantern_path", player), HillRules.TEXT_VISIT_HERE, "≤ 3 m from the waypoint")
	player.global_position = world.get_waypoint(&"gate_outside")
	assert_eq(hill.visit_here(player), &"hrl_lantern_path")
	var before := TimeManager.total_minutes()
	hill.start_visit(&"hrl_lantern_path")
	assert_eq(TimeManager.total_minutes() - before, 20, "a TimedAction of 20 minutes")
	assert_eq(hill.parts_done(&"hrl_lantern_path")[2], true, "the evening at the gate")
	# gather: the wood pile counts (it sends no resource_gathered).
	var w := _hill_widow()
	assert_true(w != null)


func _hill_widow() -> HillRequests:
	hill.fail(&"hrl_lantern_path")
	hill._large_ended.clear()
	TimeManager.set_time(TimeManager.day + 1, 480)
	_large_accepted(&"hrl_widow_wood")
	var pile := world.get_node_by_layout_id("res_wood") as ResourceNode
	player.instant_actions = true
	var n := 0
	while pile.can_interact(player) and n < 10:
		pile.interact(player)
		n += 1
	assert_eq(hill.part_progress(&"hrl_widow_wood", 0), pile.daily_amount, "the pile's wood counts for the gather part")
	return hill


func test_large_save_and_load_in_the_middle() -> void:
	_large_accepted(&"hrl_crosses")
	EventBus.craft_finished.emit(&"workbench", &"wooden_cross", 2)
	var before := hill.save_state()
	assert_eq(SaveManager.save_game(SLOT), OK)
	assert_eq(await SaveManager.load_game(SLOT), OK)
	_bind()
	assert_eq(hill.save_state(), before, "save → load keeps the large request with its counts")
	assert_eq([hill.state(&"hrl_crosses"), hill.part_progress(&"hrl_crosses", 0)], [HillRequests.STATE_ACCEPTED, 2])
	assert_true(_board_node().sheet_visible(), "the sheet after loading")
	EventBus.craft_finished.emit(&"workbench", &"wooden_cross", 1)
	assert_eq(hill.parts_done(&"hrl_crosses"), [true, false] as Array[bool], "goes on after the load")
	assert_eq(warnings.lines, PackedStringArray(), "no warnings")
